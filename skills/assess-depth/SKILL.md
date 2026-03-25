---
name: assess-depth
description: |
  Assess module quality using Ousterhout's strategic design principles.
  Detects shallow modules, pass-through methods, information leakage,
  temporal decomposition, and wide interfaces. Use in code review
  (per-PR diff) or backlog grooming (full-repo audit).
agent_tier: weak
temperature: 0
disable-model-invocation: true
---

# /assess-depth

Rate module quality on Ousterhout's strategic design dimensions. Produces a numeric score, per-module findings, and prioritized fix list.

## Rubric

Seven dimensions, each producing findings at severity `critical`, `warning`, or `info`.

1. **Shallow modules** -- High interface-to-implementation ratio. Many public methods/exports relative to total functionality. Lots of boilerplate, little real logic.
2. **Pass-through methods** -- Methods that delegate to another layer without adding value. `getUser()` just calls `this.repository.getUser()`.
3. **Information leakage** -- Implementation details exposed in public interfaces. Internal data structures, error formats, or storage mechanisms visible to callers.
4. **Temporal decomposition** -- Code organized by when things happen (init, process, cleanup) instead of by what information they manage.
5. **Wide interfaces** -- Functions with many parameters (>4), modules with many exports (>10), or APIs with many endpoints per resource.
6. **Configuration explosion** -- Too many options that could have sensible defaults. Pushing complexity onto the caller.
7. **Naming red flags** -- "Manager", "Helper", "Util", "Data", "Info", "Handler" -- names that describe the mechanism, not the abstraction.

See `references/rubric.md` for concrete examples, severity guidance, and fix patterns across TypeScript, Rust, Go, and Elixir.

## Scoring

| Range | Meaning |
|-------|---------|
| 90-100 | Deep modules, clean interfaces, strong information hiding |
| 70-89 | Generally good, minor interface width or naming issues |
| 50-69 | Multiple shallow modules or significant information leakage |
| 30-49 | Pervasive pass-through layers or temporal decomposition |
| 0-29 | No discernible module structure |

Score = 100 minus weighted deductions. Critical findings deduct 10-15 each, warnings 3-5, info 1. Floor at 0.

## Output Contract

```json
{
  "score": 72,
  "grade": "70-89",
  "scope": "src/payments/",
  "modules_assessed": 8,
  "findings": [
    {
      "dimension": "pass-through-methods",
      "severity": "critical",
      "module": "src/payments/PaymentService.ts",
      "evidence": "12 of 15 methods delegate directly to PaymentRepository with no transformation",
      "fix": "Collapse PaymentService into PaymentRepository or give Service real orchestration logic"
    },
    {
      "dimension": "wide-interfaces",
      "severity": "warning",
      "module": "src/payments/createPayment.ts",
      "evidence": "createPayment() accepts 7 parameters",
      "fix": "Introduce a PaymentRequest value object"
    }
  ],
  "top_fixes": [
    "Merge PaymentService into PaymentRepository (eliminates 12 pass-through methods)",
    "Extract PaymentRequest value object (reduces createPayment params from 7 to 1)"
  ]
}
```

All fields required. `findings` ordered by severity descending, then by module path. `top_fixes` limited to 3, ordered by impact.

## Modes

| Invocation | Scope | Behavior |
|------------|-------|----------|
| `/assess-depth src/payments/` | Directory | Assess all modules in directory |
| `/assess-depth` (during PR review) | PR diff | Assess only changed/added modules in the current diff |
| `/assess-depth --full` | Entire repo | Full-repo audit, one score per top-level module |

In PR review mode, only score modules touched by the diff. Report pre-existing issues in touched files but distinguish them from newly introduced issues.

## Integration Points

| Workflow | How |
|----------|-----|
| `/autopilot check-quality` | Run assess-depth on changed modules; fail if score < 50 or any critical finding |
| `/settle` | Include depth score in PR summary |
| `/groom` | Full-repo audit to identify worst modules for refactor backlog |
| `/rethink` | Feed depth scores into structural assessment |

## Process

1. Identify scope (directory, diff, or full repo).
2. For each module in scope, evaluate all 7 rubric dimensions.
3. Classify each finding by severity.
4. Compute score.
5. Rank fixes by impact (critical findings first, then by how many dimensions the fix addresses).
6. Emit JSON output.

## Anti-Patterns

- Scoring style preferences (formatting, naming conventions beyond red-flag names) -- this is structural assessment only
- Penalizing small modules that are genuinely deep (a 20-line module with 1 export and strong invariants scores high)
- Counting lines of code as a proxy for depth -- a 500-line module can be shallow
- Ignoring test files -- test structure mirrors and reveals production structure problems

## References

- `references/rubric.md` -- detailed rubric with examples per dimension and language
