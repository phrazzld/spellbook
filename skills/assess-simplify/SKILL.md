---
name: assess-simplify
description: |
  Verify simplification: did complexity actually decrease, or just move?
  Compares before/after semantically. Strong agent tier -- requires genuine
  reasoning about complexity redistribution. Use in /settle Phase 3.
agent_tier: strong
temperature: 0
disable-model-invocation: true
---

# /assess-simplify

The hardest semantic judgment in code review: did a refactor genuinely simplify, or just reshuffle complexity? Score the net change.

## Purpose

Refactors claim simplification. Most don't deliver it. Complexity has conservation laws -- reducing it in one module often increases it in another, in callers, in configuration, or in implicit contracts. This skill detects the difference between genuine reduction and mere redistribution.

## Input

Two required inputs:

1. **Full diff** -- the PR or changeset claiming simplification
2. **Pre-image of changed files** -- obtained via `git show main:path/to/file` for each modified file

Both are required. The diff alone cannot reveal redistribution -- you need the before state to measure net change.

## Rubric

Five dimensions, evaluated against the before/after state.

### 1. Genuine Reduction

Did total conceptual complexity decrease? Fewer abstractions, fewer indirections, fewer concepts a reader must hold in working memory to understand the system.

**Measure:** Count abstractions (classes, interfaces, type aliases, wrapper functions, indirection layers) before and after. Count concepts a newcomer must learn to understand the changed code. Net decrease = genuine reduction.

**Signals of reduction:** Merged two classes into one. Inlined a trivial wrapper. Removed an abstraction layer. Deleted a configuration dimension.

**Signals of non-reduction:** Same number of abstractions, just renamed. Moved code between files without eliminating concepts. Replaced one pattern with another of equal weight.

### 2. Complexity Redistribution

Was complexity moved from one module to another without net reduction? A module gets simpler, but its callers get more complex. An abstraction is removed, but the call sites now contain the logic that was abstracted.

**Measure:** For each module that got simpler, check whether its callers, siblings, or dependents got more complex by the same amount. If the total across all touched files is neutral or negative, complexity was redistributed, not reduced.

**Signals of redistribution:** Module A lost 40 lines but Module B gained 35. A helper was deleted but its logic was copy-pasted into 4 call sites. An abstraction was removed but every caller now handles the edge case directly.

### 3. Interface Simplification

Did public API surfaces shrink? Fewer parameters, fewer exports, simpler types, fewer configuration options.

**Measure:** Count public exports, function parameters, type complexity (union width, generic depth), and configuration knobs before and after.

**Signals of simplification:** Function went from 6 params to 2. Module exports dropped from 12 to 7. A generic type was replaced with a concrete one. Configuration options eliminated by choosing sensible defaults.

**Signals of non-simplification:** Same number of exports, just renamed. Parameters moved from function args to a config object with the same fields. Types reshuffled but equally complex.

### 4. Deletion Test

Was code actually deleted, or just reorganized?

**Measure:** Net lines deleted across all files in the diff. Reorganization is net-zero. Genuine simplification almost always results in net deletion.

**Signals of genuine deletion:** Total lines across touched files decreased. Entire files removed. Functions eliminated. Dead code paths excised.

**Signals of reorganization:** Total lines roughly unchanged. Files renamed or split. Code moved between modules with minimal net change.

### 5. Read Test

Is the resulting code easier to read top-to-bottom for a newcomer? Could someone unfamiliar with the codebase understand the changed modules faster after this PR than before?

**Measure:** Trace the reading path a newcomer would follow. Count the number of jumps (file hops, indirection layers, "go read this other thing first" moments). Fewer jumps = easier to read.

**Signals of improvement:** Linear flow replaced callback chains. One file tells the whole story instead of three. Naming clarifies intent. Comments removed because the code now speaks for itself.

**Signals of non-improvement:** Reader must now understand a new pattern to follow the code. Indirection replaced with duplication (trades one complexity for another). Clever code replaced verbose-but-clear code with equally-clever-but-different code.

## Scoring

| Range | Meaning |
|-------|---------|
| 90-100 | Genuine simplification with measurable deletion. Every dimension improved. |
| 70-89 | Net simplification. Minor redistributions but clear overall improvement. |
| 50-69 | Neutral. Complexity moved but didn't shrink. Refactor has no net benefit. |
| 30-49 | Added complexity while claiming simplification. More concepts, not fewer. |
| 0-29 | Made things worse. More abstractions, wider interfaces, no deletion. |

Score = 100 minus weighted deductions. Each dimension contributes equally (20 points max).

## Output Contract

```json
{
  "score": 55,
  "grade": "50-69",
  "scope": "PR #203",
  "complexity_moved_not_removed": true,
  "net_lines_deleted": -3,
  "dimensions": {
    "genuine_reduction": {
      "score": 12,
      "evidence": "Removed PaymentHelper class but logic moved to 3 call sites"
    },
    "redistribution": {
      "score": 5,
      "evidence": "PaymentService lost 45 lines, but OrderService gained 38 and CheckoutService gained 12"
    },
    "interface_simplification": {
      "score": 15,
      "evidence": "processPayment() params reduced from 6 to 3 via PaymentRequest object"
    },
    "deletion": {
      "score": 8,
      "evidence": "Net 3 lines deleted across 7 files -- reorganization, not deletion"
    },
    "readability": {
      "score": 15,
      "evidence": "Payment flow now readable in 2 files instead of 4, but OrderService is harder to follow"
    }
  },
  "findings": [
    {
      "type": "redistribution",
      "severity": "warning",
      "from": "src/payments/PaymentService.ts",
      "to": ["src/orders/OrderService.ts", "src/checkout/CheckoutService.ts"],
      "evidence": "45 lines of payment validation logic moved, not eliminated"
    }
  ],
  "verdict": "Complexity was redistributed, not reduced. Interface improved but total conceptual load is unchanged."
}
```

All fields required. `complexity_moved_not_removed` is `true` when the agent determines complexity was relocated rather than eliminated -- this is the primary boolean signal for downstream workflows.

## Trigger

Only invoked on PRs labeled `refactor` or `simplify`, or when explicitly called. Not run on feature additions or bug fixes.

## Integration Points

| Workflow | How |
|----------|-----|
| `/settle` Phase 3 | Primary consumer. assess-simplify gates whether a refactor PR is accepted as genuine simplification. |
| `/rethink` | Feed simplification scores into architectural assessment to track whether refactors are delivering value. |
| `/settle` | Include simplification verdict in PR summary for refactor PRs. |

## Process

1. Collect the full diff and pre-images of all changed files (`git show main:path`).
2. For each changed file, analyze before/after state across all 5 dimensions.
3. Compute per-dimension scores.
4. Set `complexity_moved_not_removed` based on redistribution analysis.
5. Compute total score.
6. Emit JSON output with verdict.

## Anti-Patterns

- Rewarding deletion of dead code as "simplification" -- removing unused code is hygiene, not simplification of working systems
- Penalizing increased line count when it replaces cleverness with clarity -- more lines can be simpler
- Treating all abstractions as complexity -- a well-chosen abstraction reduces total complexity even though it adds a concept
- Scoring formatting/style changes -- this skill assesses structural complexity, not cosmetics
- Requiring net line deletion for a high score -- a refactor that replaces 50 lines of spaghetti with 60 lines of clean code can score 90+
