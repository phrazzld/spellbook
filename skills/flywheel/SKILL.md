---
name: flywheel
description: |
  Outer-loop shipping orchestrator. Composes cycles of /deliver → landing →
  /deploy → /monitor → /diagnose → /reflect, mutates the backlog, and emits
  harness suggestions to a branch. Inner loop is /deliver (one ticket →
  merge-ready, a black box here). Outer loop owns the final mile: get the
  branch clean and landed, deploy the landed sha, watch it, reflect, and apply
  the learnings before closing the cycle. Every run ends with a tight shipping
  brief plus a full /reflect session.
  Use when: continuous delivery, "flywheel", "run the outer loop",
  "next N items", "overnight queue", "outer loop", "cycle".
  Trigger: /flywheel.
argument-hint: "[--max-cycles N] [--budget $N] [--unattended] [--dry-run]"
---

# /flywheel

Outer-loop shipping orchestrator. `/deliver` takes one item to merge-ready
and exits (inner loop). `/flywheel` takes that merge-ready branch through the
final mile: landing, deployment, monitoring, reflection, and application of
the reflect outputs. It runs N of those cycles.

## Invariants

- Delegate each phase to its named skill; never inline phase logic here.
- Treat `/deliver` as an opaque merge-readiness step. `/flywheel` does not
  stop there; it owns the final mile after `/deliver` succeeds.
- Land the change on the default branch before deploy. Use `/land`
  (preferred), `/settle`, or explicit repo-native landing; never deploy from
  an unlanded feature branch.
- Treat the event log as the source of truth — every phase boundary writes an event via `flywheel.sh emit`.
- Apply the reflect outputs before closing the cycle. Backlog mutation and
  harness suggestions are part of the success path, not optional cleanup.
- Do not restate leaf-skill internals here. `/flywheel` orchestrates;
  `/deliver`, `/land`, `/deploy`, `/monitor`, and `/reflect` own their own loops.

## Real Mode — Cycle Orchestration

The MODEL drives the outer loop by invoking script subcommands. The script
provides state primitives; the model provides judgment.

```
1. Mint cycle:
   cycle_id=$(bash skills/flywheel/scripts/flywheel.sh new-cycle --budget $BUDGET)

2. Pick item:
   item=$(bash skills/flywheel/scripts/flywheel.sh pick $cycle_id)
   If EMPTY → close noop, exit 0.

3. Invoke /deliver $item --state-dir backlog.d/_cycles/$cycle_id/evidence/deliver/
   - On exit 0: read receipt.json and capture the merge-ready branch + head sha.
   - On non-zero: emit phase.failed, close aborted, STOP this cycle.

4. Invoke the landing phase (`/land` preferred; `/settle` or explicit
   repo-native landing if needed):
   - Treat landing as a black-box final-mile step that returns a landed sha.
   - Landing owns final-mile CI/review/refactor/QA loops and repo-policy merge strategy.
   - On success: emit deliver.done with cost_usd, branch, head_sha, landed_sha,
     and merge_strategy.
   - On non-zero: emit phase.failed, close aborted, STOP this cycle.
   bash skills/flywheel/scripts/flywheel.sh emit $cycle_id deliver.done \
     deliver builder '{"cost_usd":<x>,"branch":"<b>","head_sha":"<s>","landed_sha":"<l>","merge_strategy":"squash"}'

5. Invoke /deploy against the landed sha; parse receipt; emit:
   bash skills/flywheel/scripts/flywheel.sh emit $cycle_id deploy.done \
     deploy deployer '<receipt_json>'

6. Invoke /monitor; consume its one terminal event.
   - monitor.done → proceed to step 7.
   - monitor.alert → go to step 7.
   bash skills/flywheel/scripts/flywheel.sh emit $cycle_id monitor.done \
     monitor monitor '<payload>'

7. (If alert) Invoke /diagnose; emit:
   bash skills/flywheel/scripts/flywheel.sh emit $cycle_id triage.done \
     triage diagnostician '<payload>'

8. Invoke /reflect cycle $cycle_id; emit:
   bash skills/flywheel/scripts/flywheel.sh emit $cycle_id reflect.done \
     reflect reflector '<payload_with_new_items>'

9. Apply reflect outputs:
   - update bucket (shipped or failed)
   bash skills/flywheel/scripts/flywheel.sh update-bucket $cycle_id shipped

10. Suggest or apply harness changes:
   bash skills/flywheel/scripts/flywheel.sh update-harness $cycle_id

11. Close cycle:
    bash skills/flywheel/scripts/flywheel.sh close $cycle_id closed

12. If --max-cycles > 1 and budget remains and no stop predicate triggered:
    GOTO 1.
```

After cycle(s), emit operator-facing shipping brief + full /reflect session
(see Closeout Contract).

## Flags

| Flag | Purpose |
|------|---------|
| `--max-cycles N` | Hard count of cycles (default 1) |
| `--budget $N` | Cumulative model cost ceiling |
| `--unattended` | No-TTY mode; requires `--budget` |
| `--dry-run` | Walk phases, write 8-event trail, invoke nothing |
| `--until <pred>` | Stop predicate (exits 2 — not yet implemented) |
| `--resume <ulid>` | Resume paused cycle (exits 2 — not yet implemented) |
| `--abandon <ulid>` | Mark abandoned (exits 2 — not yet implemented) |

Unattended without `--budget` exits 2: `flywheel: unattended mode requires
--budget <usd>`. Default interactive cap is $5 USD.

## Subcommands

| Subcommand | Purpose |
|------------|---------|
| `new-cycle [--budget $X] [--unattended]` | Acquire lock, mint ULID, write manifest, emit cycle.opened. stdout: `<ulid>` |
| `pick <cycle_id>` | Deterministic eligibility filter + scoring, with stale-item screening for active backlog drift. stdout: `<item_id>` or `EMPTY` |
| `emit <cycle_id> <kind> <phase> <agent> <payload>` | Validated event write; sums cost_usd; triggers budget.exhausted at 95% |
| `close <cycle_id> <status> [<reason>]` | Emit cycle.closed, update manifest, release lock |
| `update-bucket <cycle_id> <ship_status>` | Backlog mutation (move on shipped, stamp on failed). Idempotent |
| `update-harness <cycle_id>` | Emit harness.suggested (branch mechanics not yet implemented) |
| `budget <cycle_id>` | stdout: manifest budget block as JSON |
| `status [<cycle_id>]` | Human-readable cycle state |
| `run [flags]` | Drive the outer loop (--dry-run or real). Accepts --max-cycles |

## Artifacts Per Cycle

```
backlog.d/_cycles/<ulid>/
├── cycle.jsonl        # append-only typed events (the event log)
├── evidence/          # QA artifacts, review transcripts, diffs
│   └── deliver/       # /deliver state dir when invoked by /flywheel
└── manifest.json      # full cycle state with budget accounting
```

## Event Schema

Closed enum — 12 kinds. Unknown kinds fail at emit time.

| Kind | When |
|------|------|
| `cycle.opened` | Cycle starts (new-cycle) |
| `deliver.done` | Merge-ready branch has been settled and landed |
| `deploy.done` | /deploy completes |
| `monitor.done` | /monitor: clean |
| `monitor.alert` | /monitor: regression detected |
| `triage.done` | /diagnose completes |
| `reflect.done` | /reflect cycle completes |
| `bucket.updated` | update-bucket mutates backlog |
| `harness.suggested` | update-harness emits suggestion |
| `phase.failed` | Any phase returns non-zero |
| `budget.exhausted` | spent_usd >= cap_usd * 0.95 |
| `cycle.closed` | Cycle ends (any status) |

Inner-pipeline events (`shape.done`, `build.done`, etc.) live inside
`/deliver` — `/flywheel` sees one `deliver.done` per cycle.

## Closeout Contract

Every `/flywheel` run ends with:
1. A tight shipping brief (what changed, why, value, verified, residual risk).
2. A full `/reflect` session.

For multi-cycle runs: one brief per cycle, then one aggregate summary.
`/reflect` is mandatory; do not collapse it into the brief.

## Lock Semantics

`.spellbook/flywheel.lock` holds `{pid, cycle_id, started_at}`. Stale locks
(owner pid dead) are stolen atomically. SIGINT → exit 130. SIGTERM → exit 143.

## Gotchas

- **Never run two /flywheel in the same worktree.** Lock enforces it.
- **Inner loop is a black box.** Consume exit code + receipt only.
- **emit validates kinds.** Do not invent kinds inline; update EVENT_KINDS
  in `scripts/lib/events.sh` and every consumer.
- **pick is drift-aware.** Items still sitting in `backlog.d/` but already
  carrying `## What Was Built` or closed by current-branch commit markers
  such as `Closes backlog:<item-id>` / `Ships backlog:<item-id>` are skipped.
  `/groom tidy` still owns archival; `pick` just refuses to burn the cycle.
- **budget.exhausted fires at 95%.** Finish current phase first. The 5%
  headroom absorbs metering lag.
- **update-bucket is idempotent.** Guards every mutation with cycle_id grep.
  Re-running is safe; it detects the marker and no-ops.
- **harness.suggested writes to a branch only** (never main). Branch mechanics not yet implemented; currently emits a placeholder event.
- **`/flywheel` is not `/deliver`.** Merge-ready is an intermediate state. A
  successful cycle lands the change before deploy.
- **`/land` is not a separate lane.** It is the preferred landing mode of
  `/settle`; use the shorter name when the task is specifically to land.
- **Landing is explicit, not implicit.** Use repo policy. Default to squash for
  one-ticket feature branches unless repo guidance overrides it.
- **Library repos still land.** If no deploy target exists, deploy/monitor may
  become explicit no-ops, but landing and reflect still happen.
- **Paths anchor to REPO_ROOT.** flywheel.sh cds to the repo root on startup.
  Override FLYWHEEL_LOCK_PATH with an absolute path.

## References

See `scripts/flywheel.sh --help` for:
- Full eligibility filter and scoring formula (`pick`)
- Manifest schema and budget accounting
- Resume & abandon semantics
- Durability guarantees (D1–D5)
- update-bucket mutation grammar
- update-harness branch mechanics
- Stopping predicates (`--until`)
- Worktree behavior
