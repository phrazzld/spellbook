---
name: assess-review
description: |
  Triad code review: three perspectives (Ousterhout, Grug, Beck) assess a
  diff in parallel, then synthesize a consensus verdict. Strong agent tier.
  Use at the end of /autopilot or /settle runs before merge.
agent_tier: strong
temperature: 0
disable-model-invocation: true
---

# /assess-review

Structured code review from three complementary perspectives that catch different classes of issues. Each perspective has a blind spot the others cover.

## Why Three Perspectives

A single reviewer optimizes for one axis. Ousterhout catches structural rot but won't flag missing tests. Beck catches test problems but won't notice a wide interface. Grug catches over-engineering but won't spot a subtle information leak. The triad covers the full surface.

| Perspective | Catches | Misses |
|-------------|---------|--------|
| Ousterhout | Structural decay, interface width, information leakage | Test quality, over-cleverness |
| Grug | Over-engineering, premature abstraction, debuggability | Subtle design violations, test gaps |
| Beck | Test quality, behavioral coverage, mock abuse | Module design, complexity at the architecture level |

## Perspectives

### Ousterhout (Strategic Design)

- Shallow modules (lots of boilerplate, little functionality)
- Wide interfaces (too many methods/parameters)
- Information leakage (implementation details exposed)
- Pass-through methods (just delegate to another layer)
- Configuration explosion (too many options)

### Grug (Complexity Hunting)

- Complexity demons (too many layers? too clever?)
- Premature abstraction (only one use but already interface/factory?)
- Debuggability (can put log and understand?)
- Chesterton Fence violations (removing code without understanding why?)

### Beck (Test Quality / TDD)

- Tests testing implementation not behavior?
- Missing tests for changed behavior?
- Tests that would break on refactor?
- Overmocking (>3 mocks = smell)?
- Test isolation (shared state between tests)?

## Process

1. **Gather diff.** `git diff $(git merge-base HEAD main)..HEAD` or the PR diff.
2. **Run three assessments.** Parallel via subagents when available, sequential otherwise. Each perspective produces findings with `file:line`, severity, and suggested fix.
3. **Synthesize.** Merge findings. Identify consensus (2+ perspectives flagged same area), conflicts (perspectives disagree), and unique catches (only one perspective spotted it).
4. **Verdict.** Apply gating rules. Emit structured output.

## Gating Rules

| Condition | Verdict |
|-----------|---------|
| 2+ perspectives say **fail** | **fail** |
| 1 perspective says **fail**, or 2+ say **warn** | **warn** |
| All other cases | **pass** |

Each perspective's per-finding severity maps to a perspective-level verdict:
- Any **critical** finding = perspective says **fail**
- Any **important** finding (no criticals) = perspective says **warn**
- Only **suggestion** findings = perspective says **pass**

## Output Contract

```json
{
  "verdict": "warn",
  "scope": "feature/payment-retry (12 files, 340 lines changed)",
  "perspectives": {
    "ousterhout": {
      "verdict": "warn",
      "findings": [
        {
          "file": "src/payments/RetryService.ts",
          "line": 42,
          "severity": "important",
          "issue": "Pass-through: 4 of 6 methods delegate to RetryQueue with no transformation",
          "fix": "Collapse RetryService into RetryQueue or give Service real orchestration"
        }
      ]
    },
    "grug": {
      "verdict": "pass",
      "findings": [
        {
          "file": "src/payments/RetryPolicy.ts",
          "line": 1,
          "severity": "suggestion",
          "issue": "RetryPolicy interface with single implementation -- premature abstraction?",
          "fix": "Inline until a second implementation exists"
        }
      ]
    },
    "beck": {
      "verdict": "fail",
      "findings": [
        {
          "file": "src/payments/__tests__/retry.test.ts",
          "line": 15,
          "severity": "critical",
          "issue": "No tests for retry exhaustion behavior (only happy path tested)",
          "fix": "Add test: retries exhaust after maxAttempts, order moves to dead-letter"
        }
      ]
    }
  },
  "consensus": [
    "RetryService adds a layer without earning it (Ousterhout: pass-through, Grug: complexity)"
  ],
  "positive": [
    "Exponential backoff implementation is clean and well-bounded"
  ]
}
```

All fields required. `findings` ordered by severity descending within each perspective. `consensus` lists issues flagged by 2+ perspectives.

## Optional Add-On Perspectives

Activate when the diff warrants it. Do not run by default.

| Perspective | Activate When | What It Catches |
|-------------|---------------|-----------------|
| **Fowler** (Code Smells) | Refactoring PRs, large structural changes | Long Method, Feature Envy, Shotgun Surgery, Duplication |
| **Data Integrity Guardian** | PRs touching `*.sql`, migrations, DDL | Missing backfills, invisible rows, broken predicates |

When activated, add-on perspectives contribute findings and participate in gating on equal footing with the core triad.

## Integration Points

| Workflow | How |
|----------|-----|
| `/autopilot` | Run assess-review after check-quality, before PR creation |
| `/pr-fix` | Run assess-review as self-review step after fixes, before signaling unblocked |
| `/settle` | Include verdict in merge-readiness summary |
| `/assess-depth` | Ousterhout perspective draws from the same rubric; assess-review is the diff-scoped version |
| `/assess-tests` | Beck perspective draws from the same rubric; assess-review is the multi-perspective wrapper |

## Anti-Patterns

- Running all five perspectives on every PR (core triad is sufficient; add-ons are conditional)
- Treating suggestions as blockers (suggestions are optional improvements, not merge gates)
- Skipping synthesis and just concatenating raw outputs (the consensus step is where the value is)
- Using assess-review for full-repo audits (use assess-depth and assess-tests for that; assess-review is diff-scoped)

## References

| Reference | When to load |
|-----------|-------------|
| `references/rubric.md` | Always on first invocation -- complete persona prompts and scoring criteria |
