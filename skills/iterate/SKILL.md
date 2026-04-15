---
name: iterate
description: |
  Outer-loop orchestrator. Composes /shape, /autopilot, /code-review, /qa,
  /deploy, /reflect into a closed delivery cycle. Picks a backlog item,
  ships it, reflects, updates the bucket, picks the next. Writes a typed
  event log (daybook) per cycle.
  Use when: continuous delivery, "iterate", "run the loop", "next N items",
  "outer loop", "cycle", "overnight queue".
  Trigger: /iterate, /cycle.
argument-hint: "[--max-cycles N] [--budget $N] [--dry-run]"
---

# /iterate

Outer-loop orchestrator. `/autopilot` ships one item and exits. `/iterate`
composes existing skills into a closed cycle and runs N of them.

This is the outer loop (async delivery). `/autopilot` is the inner loop
(single-shot). Two skills, two stop conditions, one composition contract.

## Phase 1 Scope (current)

- Dry-run end-to-end walk of all 9 phases
- Typed daybook events (`scripts/lib/daybook.sh`)
- Single-instance lock (`scripts/lib/iterate_lock.sh`) with stale-pid steal
- Unattended-safety guard (`--budget` required for `--max-cycles > 1`)

**Not yet wired:** real handlers for `/shape`, `/autopilot`, `/code-review`,
`/qa`, `/deploy`, `/reflect`. Invoking without `--dry-run` writes a
`phase.failed` event and exits non-zero. That is intentional — Phase 1
proves the event/lock contract; Phase 2 wires the handlers.

## Execution Stance

You are the executive orchestrator.
- Keep work selection, stop judgment, and cycle close/abandon on the lead model.
- Delegate each phase to its named skill; never inline phase logic here.
- Treat the daybook as the source of truth — every phase boundary writes an event.

## Flags

| Flag | Purpose | Phase |
|------|---------|-------|
| `--max-cycles N` | Hard count of cycles (default 1) | 1 |
| `--budget $N` | Cumulative model cost ceiling | 1 (required for N>1) |
| `--dry-run` | Walk phases, write events, invoke nothing | 1 |
| `--until <pred>` | Stop predicate ("backlog empty", "P0 closed") | 2 |
| `--resume <ulid>` | Resume a paused cycle from last completed phase | 2 |
| `--abandon <ulid>` | Mark cycle abandoned and release its lock | 2 |

Without `--budget`, `/iterate` refuses `--max-cycles > 1` — this is the exact
failure mode unattended agents hit and it is cheap to prevent.

## Artifacts Per Cycle

```
backlog.d/_cycles/<ulid>/
├── cycle.jsonl        # append-only typed events (the daybook)
├── evidence/          # QA artifacts, review transcripts, diffs
└── manifest.json      # {item_id, branch, claim, started, closed, status}
```

## Daybook Event Schema

Every event is one JSON line with this envelope:

```json
{
  "schema_version": 1,
  "ts": "2026-04-14T12:00:00Z",
  "cycle_id": "01HQ...",
  "kind": "cycle.opened",
  "phase": "shape",
  "agent": "planner",
  "refs": ["path/to/artifact"],
  "findings": [],
  "note": "free text"
}
```

`kind` is a closed enum — writes with unknown kinds fail at the script level.
JSONL corruption breaks `/reflect`, so writes are `flock`'d and `fsync`'d.

Kinds: `cycle.opened`, `shape.done`, `build.done`, `review.iter`, `ci.done`,
`qa.done`, `deploy.done`, `reflect.done`, `harness.suggested`, `phase.failed`,
`budget.exhausted`, `cycle.closed`.

## Control Flow

```
/iterate [flags]
    │
    ▼
  acquire .spellbook/iterate.lock  (fails if a live /iterate holds it)
    │
    ▼
┌── CYCLE START ───────────────────────────────┐
│  1. pick        → bucket-scorer agent        │  cycle.opened
│  2. shape       → /shape  (+Council P0 only) │  shape.done
│  3. build       → /autopilot (build step)    │  build.done
│  4. review      → /code-review               │  review.iter (xN, max 3)
│     + CI        → dagger call check          │  ci.done
│  5. qa          → /qa (auto-scaffold)        │  qa.done
│  6. deploy      → /deploy (auto-scaffold)    │  deploy.done
│  7. reflect     → /reflect on daybook        │  reflect.done
│  8. update-bucket → WRAP emitter             │  writes backlog.d/NNN-*.md
│  9. update-harness → harness.suggested       │  writes to PR branch only
└── CYCLE CLOSED ──────────────────────────────┘
    │
    ▼
  stop? (predicate / max-cycles / budget / SIGINT) → next cycle or release lock
```

## Invocation

```bash
# Dry-run a single cycle — writes all 9 phase events, invokes nothing.
bash skills/iterate/scripts/iterate.sh --dry-run --max-cycles 1

# Real mode (Phase 2+; currently writes phase.failed and exits 1)
bash skills/iterate/scripts/iterate.sh --max-cycles 1

# Multi-cycle with cost ceiling
bash skills/iterate/scripts/iterate.sh --max-cycles 5 --budget 20
```

## Lock Semantics

`.spellbook/iterate.lock` holds `{pid, cycle_id, started_at}`. SIGINT, EXIT, and
TERM traps release the lock — scoped to the acquiring `cycle_id` so a late
trap from a prior cycle cannot wipe a successor's lock. Stale locks (owner
pid dead, or JSON corrupt) are stolen silently.

## Stop Conditions (Phase 1)

- `--max-cycles N` reached
- Any phase returns non-zero → `phase.failed` event, release lock, exit 1
- SIGINT → trap releases lock, exit 130
- Budget exhausted mid-cycle → finish current phase, emit `budget.exhausted`, stop

## Gotchas

- **Never run two /iterate in the same repo.** The lock enforces it; tests verify.
- **Dry-run invokes nothing.** It exists to prove the event contract, not to
  rehearse phases. Do not use it as a cheap "preview".
- **Real mode has no handlers in Phase 1.** It writes `phase.failed` and
  exits 1 by design. Wiring is Phase 2.
- **Auto-scaffold is Phase 3.** If `/qa` or `/deploy` is missing when real
  mode lands, the cycle fails loudly — no silent scaffolding.
- **`harness.suggested` writes to a branch only** (never main). Phase 2
  emits the event and wires the branch write; Phase 1 dry-run does not emit
  it (would train the wrong mental model of the contract).
- **Closed-enum kinds.** Adding a new kind requires updating `DAYBOOK_KINDS`
  in `daybook.sh` and every consumer — don't invent kinds inline.
