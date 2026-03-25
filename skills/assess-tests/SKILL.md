---
name: assess-tests
description: |
  Assess test quality: behavioral vs implementation coupling, mock depth,
  AAA structure, one-behavior-per-test, edge case coverage. Use in code
  review (per-PR) or backlog grooming (test suite health audit).
agent_tier: weak
temperature: 0
disable-model-invocation: true
---

# /assess-tests

Score test behavioral quality. Find tests that break on refactor, not on bugs.

## Rubric

Evaluate every test file against these ten criteria. Load `references/rubric.md` for detailed examples.

### 1. Implementation Coupling

Tests that spy on internal/private methods, assert call order, or mock internal
dependencies. These break on refactor even when behavior is preserved.

**Signals:** `jest.spyOn(module, 'privateMethod')`, assertions on call count of
internal functions, mocking `@/lib/*` or `./utils/*`.

### 2. Mock Depth

More than 3 mocks per test is a smell. Either the test is too broad or the code
under test has too many dependencies. Each mock is a bet that the real
dependency's contract won't change.

**Signals:** Count `vi.fn()`, `jest.fn()`, `mock()`, `patch()` per test.

### 3. AAA Structure

Tests should follow Arrange/Act/Assert. Interleaving setup, action, and
assertion makes tests harder to read and impossible to skim.

**Signals:** Multiple `expect` calls separated by mutations or side effects.

### 4. One Behavior Per Test

Each test should verify one behavior. Multiple unrelated assertions hide which
behavior failed and make test names meaningless.

**Signals:** `it('works')`, `it('handles everything')`, test bodies >30 lines
with multiple unrelated assertions.

### 5. Test Name Clarity

Names should describe behavior, not implementation. "it('works')" or
"it('test 1')" are red flags.

**Good:** `it('returns 404 when user not found')`
**Bad:** `it('test 1')`, `it('works')`, `it('should work correctly')`

### 6. Edge Case Coverage

Are error paths, boundary conditions, and null/empty cases tested? Happy-path-only
suites give false confidence.

**Signals:** No tests for error responses, empty inputs, boundary values, or
null/undefined cases.

### 7. Logic in Tests

`if`/`for`/`while` inside test blocks means the test is too complex. Tests
should be linear. Conditional logic in tests means you don't know what the test
actually verifies.

**Signals:** Control flow in `it()` / `test()` / `#[test]` / `func Test*` bodies.

### 8. Assertion Presence

Every test must have at least one assertion. Tests that only call functions or
log output prove nothing.

**Signals:** Test bodies without `expect()`, `assert`, `require`, `should`.

### 9. Test Isolation

Tests should not share mutable state. Order-dependent tests are fragile and
produce non-reproducible failures.

**Signals:** Module-level `let` mutated in tests, missing `beforeEach` reset,
tests that fail when run individually but pass in suite (or vice versa).

### 10. Refactor Resilience

The meta-question: would these tests still pass after a legitimate internal
refactor that preserves external behavior? If the answer is "probably not," the
suite is testing implementation, not behavior.

## Scoring

| Range | Meaning |
|-------|---------|
| 90-100 | Behavioral tests, minimal mocks, clean AAA, good edge coverage |
| 70-89 | Mostly behavioral, minor mock overuse or missing edge cases |
| 50-69 | Significant implementation coupling or mock-heavy tests |
| 30-49 | Most tests are implementation-coupled or lack assertions |
| 0-29 | Tests provide no behavioral confidence |

## Output Contract

```markdown
## Test Quality Assessment

**Score: XX/100**
**Scope:** [file(s) or suite assessed]

### Findings

| # | Criterion | Rating | Evidence |
|---|-----------|--------|----------|
| 1 | Implementation coupling | pass/warn/fail | [specific file:line or pattern] |
| 2 | Mock depth | pass/warn/fail | ... |
| ... | ... | ... | ... |

### Critical Issues (fail)
[Ordered by severity. Each with file:line, what's wrong, and how to fix.]

### Warnings (warn)
[Minor issues. Each with file:line and suggestion.]

### Recommendations
[Top 3 highest-leverage improvements for this test suite.]
```

## Integration Points

### Code Review (per-PR)

Run against changed test files in a PR. Flag regressions in test quality before
merge. Pair with `/pr` polish phase.

### Backlog Grooming (suite health audit)

Run against an entire test directory. Produce a ranked list of test files by
score. Prioritize refactoring the lowest-scoring files that cover critical paths.

### Composition

| Skill | Relationship |
|-------|-------------|
| `/autopilot check-quality` | assess-tests deepens the test quality dimension |
| `/debug` | When tests fail to catch a bug, assess-tests diagnoses why |
| `/calibrate` | When bad tests caused a missed defect, calibrate fixes the harness |

## References

| Reference | When to load |
|-----------|-------------|
| `references/rubric.md` | Always on first invocation -- detailed examples per criterion |
