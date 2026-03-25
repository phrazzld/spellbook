---
name: health-check
description: |
  Compare working tree against last health snapshot. Run relevant assess-*
  checks on current changes and report delta. Use mid-session, before PR
  creation, or during /reflect.
agent_tier: weak
temperature: 0
disable-model-invocation: true
---

# /health-check

"Am I making this project healthier or sicker?" -- a quick pulse check any agent can invoke.

## How It Works

1. Read `.spellbook/health.json` (last snapshot). If missing, note "no baseline -- this run establishes one."
2. Determine what changed: `git diff HEAD` for uncommitted, `git diff main...HEAD` for branch delta.
3. Run relevant assess-* subset on the diff. Skip checks that don't apply (e.g., skip assess-intent if no linked issue, skip assess-tests if no test files touched).
4. Compare scores against snapshot.
5. Output delta per check and overall direction.

## Health Snapshot Schema

`.spellbook/health.json`:

```json
{
  "version": 1,
  "project": "project-name",
  "timestamp": "ISO-8601",
  "checks": {
    "depth": { "overall": "pass", "score": 78 },
    "tests": { "overall": "warn", "score": 65 },
    "drift": { "overall": "pass", "score": 90 }
  },
  "trend": {
    "depth": [75, 76, 78],
    "tests": [70, 68, 65]
  }
}
```

- `version`: Schema version. Always `1`.
- `checks`: Latest score per assess-* dimension. Keys match assess-* skill names sans prefix.
- `trend`: Rolling array of scores per dimension. Keep last 10 entries.

## Trend Tracking

Append current score to the dimension's trend array (cap at 10, FIFO). Three or more consecutive drops triggers a degradation warning for that dimension.

## Output Format

Human-readable, emitted to stdout:

```
Health Check -- project-name
  depth:  78 -> 82 (+4)  IMPROVING
  tests:  65 -> 63 (-2)  DEGRADING (3 consecutive drops)
  drift:  90 -> 90 (=0)  STABLE
  Overall: MIXED -- tests declining, investigate
```

Direction labels:
- **IMPROVING**: score increased
- **DEGRADING**: score decreased
- **STABLE**: score unchanged
- **NEW**: no prior score for this dimension

Overall summary:
- **HEALTHY**: all dimensions stable or improving
- **MIXED**: some improving, some degrading
- **DECLINING**: majority degrading

## Touchpoints

| When | What | Writes snapshot? |
|------|------|-----------------|
| **Session start** | Read cached snapshot, report current state. Zero-cost (no assess-* runs). | No |
| **/reflect Phase 2.5** | Run full health assessment against session changes. | No |
| **/focus --health** | Full-repo audit across all assess-* dimensions. | Yes |
| **On-demand** | Invoke anytime via `/health-check`. Runs assess-* on current diff. | No |

Only comprehensive runs (`/focus --health`, `/reflect` full retro) write the snapshot. Ad-hoc checks are read-only to avoid noisy snapshots from partial work.

## Check Selection

Select assess-* checks based on what the diff contains:

| Diff contains | Run |
|---------------|-----|
| Source files (.ts, .py, .rs, .go, .ex, etc.) | assess-depth |
| Test files (*test*, *spec*, *_test.*) | assess-tests |
| Linked issue in branch name or PR | assess-intent |
| Review comments on open PR | assess-review |

Never run all checks for a small change. A 3-line fix needs at most assess-depth.

## Integration

| Skill | How health-check fits |
|-------|----------------------|
| `/autopilot` | Before PR creation, run health-check on branch delta. Include delta in PR body. |
| `/reflect` | Phase 2.5: health assessment between evidence gathering and codification. |
| `/focus --health` | Full-repo audit mode. Runs all assess-* checks, writes snapshot. |
| `/groom` | Health audit phase: identify dimensions with sustained degradation for backlog. |

## Anti-Patterns

- **Over-checking**: Don't run all assess-* checks for a 3-line change. Select based on diff content.
- **Gating on health**: Health check is informational, not a merge gate. Report, don't block.
- **Frequent snapshot writes**: Don't overwrite `.spellbook/health.json` on every check. Only comprehensive runs write snapshots.
- **Ignoring trend**: A single score drop is noise. Three consecutive drops is signal. React to trends, not individual readings.
