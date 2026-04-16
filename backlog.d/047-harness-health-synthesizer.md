# Harness-health synthesizer — cron'd /reflect mining transcripts

Priority: P2
Status: parked-until-signal
Estimate: M (~3-4 dev-days)

Inspired by Ramp's Glass memory system: "Every 24 hours, it mines the
user's previous sessions and connected integrations and synthesizes an
updated profile. Write-once-read-many. You know exactly what the agent
knows, because it's all in files you can inspect."

Our equivalent target: a background synthesis pipeline that mines
claude-doctor transcripts + `backlog.d/_cycles/*/cycle.jsonl` + session
logs, and emits a machine-authored `harness-health.md` that every new
session reads at startup. The synthesis identifies: which skills fire,
which don't, trigger-phrase drift between description and actual
invocation, and codification candidates for AGENTS.md / hooks.

Closes the claude-doctor → codification-hierarchy loop that today
requires manual triggering.

## Parked rationale

Same reason 031 (GEPA auto-tune) is parked: without sufficient signal,
synthesis infrastructure ahead of signal is the failure mode that ate
`/focus`. Unpark when:

- [ ] `/flywheel` has run ≥20 real cycles (same bar as 031).
- [ ] We've manually identified ≥3 concrete harness improvements by
      reading transcripts/cycle logs (proving the signal exists before
      automating the extraction).
- [ ] 043 (plugin bundles) has shipped, so the skills being measured
      are in a stable-enough shape to fire-rate-analyze.

If the above haven't happened yet, this ticket stays dormant.

## Goal (when unparked)

A scheduled `/reflect` run (via `/schedule` skill or cron) that:

1. Reads N days of session transcripts and cycle event logs.
2. For each installed skill, computes:
   - Fire count (how often its description matched a prompt).
   - Invocation count (how often it actually ran after matching).
   - Abandon count (invoked but aborted mid-execution).
   - Drift signal: phrases in session prompts that *should* have fired
     a skill but didn't — trigger-phrase gap.
3. Identifies codification candidates: repeated corrections from the
   user, recurring anti-patterns in assistant responses, near-misses
   where a skill *almost* fired.
4. Writes synthesis to `~/.<harness>/harness-health.md` (and/or
   `.claude/harness-health.md` in-project for per-repo signals).
5. Never modifies memory, skills, or settings directly. Write-once-
   read-many is non-negotiable.

Next session's startup hook reads `harness-health.md` and surfaces the
top-N findings for operator attention.

## Scope of synthesis output

```markdown
# Harness Health Report
Generated: 2026-04-16T12:00:00Z
Source: 87 sessions (2026-03-16..2026-04-16)

## Fire rates
- /deliver: 23 fires, 21 invocations, 2 abandons (92% completion)
- /harness: 45 fires, 45 invocations, 0 abandons (100%)
- /demo: 0 fires (declared in catalog; never matched)

## Drift signals
- User said "can you scope this down" 8 times without /groom firing.
  Trigger gap candidate: add "scope down" to /groom description.

## Dead-weight candidates (skills with 0 fires in N days)
- /demo: 0 fires in 30 days — candidate for demotion to optional tier.
- /deps: 0 fires in 30 days — same.

## Codification candidates
- User corrected "don't mock the database" 3 times across 3 sessions.
  Codify as: feedback memory or AGENTS.md testing section.
- Assistant used inline `flock` 5 times; pattern belongs in shared lib.
```

Emphasis on *candidates* — no automatic application. Operator reads and
acts (or runs `/harness` to convert specific findings into edits).

## Design

### Input sources

- `~/.claude/projects/*/memory/` — existing memory system.
- `~/.claude/projects/*/logs/` or equivalent — session transcripts.
- `backlog.d/_cycles/*/cycle.jsonl` — flywheel event logs (structured).
- `backlog.d/_cycles/*/evidence/` — evidence captures from /deliver.

Read-only. The synthesizer never writes to any of these.

### Synthesis mechanism

Invoke via `/schedule` daily (or ad-hoc via `/harness health`). The
synthesizer is itself a subagent (Explore type) with a focused prompt:

```
Input: transcript_window_dir, cycle_log_dir.
Output: harness-health.md with sections above.
Constraints: pure read. Aggregate, don't recommend actions beyond
"candidate for X" phrasing. Cite evidence by file:line.
```

### Write-once-read-many enforcement

- Synthesizer writes to `harness-health.md` atomically (temp + rename).
- No other skill/script edits the file during a session.
- Session-startup hook reads it to identify top findings but never
  modifies it.
- Prior version is preserved at `harness-health.md.prev` so diffs are
  visible session-over-session.

## MVP Slice (when unparked)

1. One-shot script: `scripts/harness-health-synth.sh <days>`. Reads
   cycle logs only (not session transcripts — those need transcript
   access we haven't scoped). Emits fire-rate section.
2. Validate the output manually for two weeks on real cycle data.
3. If operator agrees it's actionable: wire `/schedule` to run daily.
4. Phase 2: add session transcript mining (requires solving the
   transcript-access problem).

## Oracle (when unparked)

- [ ] `scripts/harness-health-synth.sh 30` runs in <60s against
      `backlog.d/_cycles/`.
- [ ] Output file has fire-rate, drift-signal, and dead-weight
      sections populated with real data.
- [ ] Running twice in the same day is a no-op (idempotent).
- [ ] Previous report is preserved at `.prev` after regeneration.
- [ ] Operator identifies ≥1 actionable codification candidate from the
      report that they actually applied, across 2 weeks of daily runs.
      (If not, re-scope or re-park.)

## Non-Goals

- **Automatic application of findings.** Write-once-read-many is the
  invariant.
- **Scoring skills on quality.** Fire rate ≠ quality; rare-but-critical
  skills (e.g. /settle) might fire 1x/month.
- **Fixing claude-doctor transcript access.** If transcripts aren't
  readable by scripts, phase 2 waits.
- **Replacing manual /reflect.** This augments the daily-digest cadence;
  session-end /reflect still handles in-session synthesis.
- **Cross-user aggregation.** Personal report; no team synthesis.

## Risks

1. **Low-signal output.** If fire-rate and drift-signal data is too
   sparse to be actionable, the report is noise. Mitigation: phased
   rollout; validate on real data before wiring to schedule.
2. **Transcript access.** Session transcripts may require a shim;
   scope separately if it becomes a blocker.
3. **Storage growth.** Daily reports + .prev retention could accumulate.
   Cap at N days of history; rotate.

## Related

- Depends on: 028 (`/flywheel` produces cycle.jsonl — the primary
  signal source). Sibling to 031 which also consumes cycle data.
- Complements: 044 (`/harness defrag` could consume fire-rate data for
  check 5 dead-weight detection once 047 lands).
- Prior art: Ramp's Glass memory system (write-once-read-many cron
  synthesis).
- Closes loop with: AGENTS.md "Continuous Learning" doctrine
  (codification hierarchy) — this is the observation layer feeding
  that loop.
