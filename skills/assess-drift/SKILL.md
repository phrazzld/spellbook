---
name: assess-drift
description: |
  Detect architectural drift: boundary violations, dependency direction
  reversals, new global state, layer bypass, interface bloat, naming
  red flags. Use per-PR (weak tier) or full audit (strong tier).
agent_tier: weak
temperature: 0
disable-model-invocation: true
---

# /assess-drift

Catch architectural violations before they compound. Compares code against a project's declared constraints (CLAUDE.md, AGENTS.md, docs/architecture.md, ADRs) and flags deviations.

## Rubric

Eight dimensions, each producing findings at severity `critical`, `warning`, or `info`.

### 1. Boundary Violations

Imports that cross documented module boundaries. API layer importing directly from DB layer, skipping the repository. Feature module reaching into another feature's internals.

**Signals:** Import paths that skip a declared layer, direct references to another module's unexported-by-convention internals, `../../../` path depth suggesting wrong boundary.

### 2. Dependency Direction

New code creates upward dependencies: lower layer depending on higher. Domain layer importing from HTTP layer. Shared library depending on application code.

**Signals:** Import direction reversal relative to the declared dependency graph. Core/domain modules importing from adapters, infrastructure, or UI.

### 3. New Global State

Any new `static`, `global`, module-level mutable state, or singletons introduced by the change.

**Signals:** `static mut`, `static let`, module-level `let` (mutable), `var` at file scope, singleton patterns (`getInstance`, `shared`, `default`), new entries in a global registry.

### 4. Layer Bypass

Code skips an abstraction layer that exists for a reason. Controller calling the database directly instead of going through the service. UI component making raw fetch calls instead of using the API client.

**Signals:** A call that could go through an existing intermediate module but doesn't. Usually caught by finding two different call-paths to the same leaf dependency -- one through the layer, one around it.

### 5. Interface Bloat

A module's public API surface grew without justification. New exports, new public methods, new parameters added to existing functions.

**Signals:** Diff adds `export`, `pub`, `public`, or new function signatures to a module that didn't need them. Parameter lists grew. A module that had 5 exports now has 8.

### 6. Naming Drift

New "Manager", "Helper", "Util", "Data", "Info", "Base", "Common", "Misc" names. These signal unclear responsibility boundaries -- Ousterhout red flags.

**Signals:** New file, class, or module names containing red-flag suffixes. Existing well-named module gets a vaguely-named sibling.

### 7. Circular Dependencies

The PR introduced import cycles. Module A imports B, B imports C, C imports A.

**Signals:** New imports that close a cycle in the dependency graph. Often introduced when a "shared" module starts importing from a feature module.

### 8. Convention Drift

New code follows different patterns than existing code in the same module. Different error handling, different naming scheme, different abstraction level.

**Signals:** Mixed paradigms in one file (callbacks + async/await), inconsistent error handling (some throw, some return Result), naming scheme breaks (camelCase function in a snake_case module).

See `references/rubric.md` for concrete examples, severity guidance, and fix patterns.

## Scoring

| Range | Meaning |
|-------|---------|
| 90-100 | No drift. Changes align with declared architecture. |
| 70-89 | Minor drift (naming, small interface growth). No boundary violations. |
| 50-69 | Boundary violation or dependency direction issue. |
| 30-49 | Multiple boundary violations or circular dependency introduced. |
| 0-29 | Fundamental architectural misalignment. |

Score = 100 minus weighted deductions. Critical findings deduct 10-15 each, warnings 3-5, info 1. Floor at 0.

## Input

Two required inputs:

1. **Diff** -- the code change under review (PR diff, staged changes, or directory)
2. **Declared constraints** -- the project's architectural docs, checked in priority order:
   - `CLAUDE.md` (project-level)
   - `AGENTS.md`
   - `docs/architecture.md`
   - `docs/adr/` (Architecture Decision Records)
   - Module-level README files
   - Implicit constraints inferred from existing structure when no docs exist

If no explicit architectural docs exist, infer constraints from the existing codebase structure and flag the absence as a meta-finding.

## Output Contract

```json
{
  "score": 65,
  "grade": "50-69",
  "scope": "PR #142",
  "constraint_sources": ["CLAUDE.md", "docs/adr/003-hexagonal.md"],
  "findings": [
    {
      "dimension": "boundary-violation",
      "severity": "critical",
      "location": "src/api/handlers/order.ts:14",
      "evidence": "Direct import of src/db/queries/orders.ts, bypassing src/repositories/order.ts",
      "rule_source": "CLAUDE.md: 'API handlers must not import from db/ directly'",
      "drift_direction": "away",
      "fix": "Import from src/repositories/order.ts instead"
    },
    {
      "dimension": "naming-drift",
      "severity": "info",
      "location": "src/services/PaymentHelper.ts",
      "evidence": "New file named 'Helper' -- unclear responsibility boundary",
      "rule_source": "Implicit: no other *Helper files exist in src/services/",
      "drift_direction": "away",
      "fix": "Rename to PaymentReconciler or PaymentValidator based on actual responsibility"
    }
  ],
  "top_fixes": [
    "Route order handler through OrderRepository (fixes boundary violation, score +15)",
    "Rename PaymentHelper to describe its actual responsibility (fixes naming, score +1)"
  ]
}
```

All fields required. `findings` ordered by severity descending, then location. `top_fixes` limited to 3, ordered by score impact. `drift_direction`: `away` (diverging from architecture), `toward` (converging back), `neutral` (no directional change).

## Modes

| Invocation | Scope | Behavior |
|------------|-------|----------|
| `/assess-drift` (during PR review) | PR diff | Assess only changed/added code against declared constraints. Fast, ~10-20s. |
| `/assess-drift src/payments/` | Directory | Assess all modules in directory against constraints. |
| `/assess-drift --full` | Entire repo | Full architectural audit. Quarterly. Slower, deeper -- checks every module boundary. |

In PR review mode, only score violations introduced or worsened by the diff. Report pre-existing violations in touched files but distinguish them (`pre-existing: true`) from newly introduced ones.

## Integration Points

| Workflow | How |
|----------|-----|
| `/autopilot check-quality` | Run assess-drift on PR diff; fail if score < 50 or any critical finding |
| `/settle` | Include drift score in PR summary |
| `/groom` | Full audit to identify architectural debt for refactor backlog |
| `/rethink` | Feed drift findings into structural assessment |
| `agent-review.yml` | Per-PR automated gate |

## Process

1. Identify scope (diff, directory, or full repo).
2. Load declared constraints from architectural docs.
3. For each file in scope, evaluate all 8 rubric dimensions against declared constraints.
4. Classify each finding by severity.
5. Compute score.
6. Rank fixes by impact (critical findings first, then by how many dimensions the fix addresses).
7. Emit JSON output.

## Anti-Patterns

- Penalizing code that has no declared constraints to violate -- flag the missing docs instead
- Treating inferred boundaries as equally authoritative to explicit ones -- inferred findings cap at `warning`
- Flagging framework-mandated patterns (e.g., Next.js file-based routing is not "convention drift")
- Scoring style/formatting as architectural drift -- this skill assesses structure, not cosmetics
- Ignoring test files -- test directory structure reveals and reinforces production architecture

## References

| Reference | When to load |
|-----------|-------------|
| `references/rubric.md` | Always on first invocation -- detailed examples per dimension |
