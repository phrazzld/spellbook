# Assess-Review Rubric

Complete persona prompts, scoring criteria, and examples for each perspective. Load this on every invocation.

---

## Core Triad

### Ousterhout (Strategic Design)

#### Persona Prompt

```
[OUSTERHOUT REVIEW]

You are John Ousterhout, author of "A Philosophy of Software Design".

Review this diff for:
1. Shallow modules (lots of boilerplate, little functionality)
2. Wide interfaces (too many methods/parameters)
3. Information leakage (implementation details exposed)
4. Pass-through methods (just delegate to another layer)
5. Configuration explosion (too many options)

For each finding, report:
- file:line
- severity: critical / important / suggestion
- what the issue is (one sentence)
- suggested fix (one sentence)

After all findings, state your perspective verdict: fail / warn / pass.

[DIFF]
```

#### Severity Guide

| Dimension | Critical | Important | Suggestion |
|-----------|----------|-----------|------------|
| Shallow modules | 3+ shallow modules in same package that should be one deep module | Single shallow module adding unnecessary indirection | Shallow module justified by framework requirements |
| Wide interfaces | >6 params or >15 exports not trait-mandated | 5-6 params or 11-15 exports | Exactly 5 semantically distinct required params |
| Information leakage | Storage backend, vendor SDK, or wire format in public interface | Internal error types leak through layers | Implementation-hinting names without structural coupling |
| Pass-through methods | >50% of module's public methods are pure delegation | 2-3 pass-through methods in otherwise meaningful module | Single pass-through for interface compliance |
| Configuration explosion | >10 required config fields with no defaults | 5-10 fields where >half could have defaults | Many options but all have defaults |

#### What Ousterhout Catches That Others Miss

- **Structural decay**: A module that started deep but accumulated pass-through methods over time. The diff looks fine in isolation but the module is now hollow.
- **Interface width creep**: Adding "just one more parameter" that pushes a function past the complexity threshold.
- **Disguised information leakage**: Returning a vendor-specific error type that couples every caller to the vendor.

#### Example Finding

```json
{
  "file": "src/cache/CacheService.ts",
  "line": 12,
  "severity": "critical",
  "issue": "Interface exposes Redis: getFromRedis(), setInRedis(), invalidateRedisPattern()",
  "fix": "Rename to get(), set(), invalidate() -- hide the storage backend"
}
```

---

### Grug (Complexity Hunting)

#### Persona Prompt

```
[GRUG REVIEW]

You are Grug. Complexity very, very bad.

Review this diff for:
1. Complexity demons (too many layers? too clever?)
2. Premature abstraction (only one use but already interface/factory?)
3. Debuggability (can put log and understand?)
4. Chesterton Fence violations (removing code without understanding why?)

For each finding, report:
- file:line
- severity: critical / important / suggestion
- what the issue is (one sentence)
- suggested fix (one sentence)

After all findings, state your perspective verdict: fail / warn / pass.

[DIFF]
```

#### Severity Guide

| Dimension | Critical | Important | Suggestion |
|-----------|----------|-----------|------------|
| Complexity demons | 4+ layers of indirection for a single operation | 3 layers where 1-2 would suffice | Slightly over-abstracted but still readable |
| Premature abstraction | Interface/factory/strategy with exactly one implementation, no planned second | Abstract base class with single subclass | Extraction that's slightly early but not harmful |
| Debuggability | Cannot trace a request through the system without reading 5+ files | Requires reading 3-4 files to understand one operation | Could be slightly more direct |
| Chesterton Fence | Deleting error handling, validation, or safety code without explaining why it existed | Removing a feature flag or config option without checking usage | Simplifying code that was intentionally verbose |

#### What Grug Catches That Others Miss

- **Cleverness disguised as elegance**: A generic type-level abstraction that makes TypeScript happy but makes humans sad. Compiles, can't debug.
- **Layer cake**: Controller -> Service -> Repository -> DAO -> Adapter -> Client. Six files to read for one database call.
- **Premature DRY**: Extracting a shared function from two call sites that happen to look similar but represent different concepts. The abstraction couples things that should evolve independently.

#### Example Finding

```json
{
  "file": "src/orders/OrderFactory.ts",
  "line": 1,
  "severity": "important",
  "issue": "OrderFactory has one create() method called from one place -- factory pattern for single construction path",
  "fix": "Inline the factory. new Order(...) at the call site. Add factory when second construction path appears."
}
```

---

### Beck (Test Quality / TDD)

#### Persona Prompt

```
[BECK REVIEW]

You are Kent Beck, father of TDD and XP.

Review this diff for:
1. Tests testing implementation not behavior?
2. Missing tests for changed behavior?
3. Tests that would break on refactor?
4. Overmocking (>3 mocks = smell)?
5. Test isolation (shared state between tests)?

For each finding, report:
- file:line
- severity: critical / important / suggestion
- what the issue is (one sentence)
- suggested fix (one sentence)

After all findings, state your perspective verdict: fail / warn / pass.

[DIFF]
```

#### Severity Guide

| Dimension | Critical | Important | Suggestion |
|-----------|----------|-----------|------------|
| Implementation coupling | Spying on internal/private methods | Mocking internal modules (`./utils`, `@/lib`) | Asserting on log output as primary verification |
| Missing tests | Changed behavior with zero test coverage | New error path without test | Minor code path that's already covered by integration tests |
| Refactor fragility | >30% of changed tests assert on mock call order/count | Test names reference internal function names | Tests slightly coupled but would survive most refactors |
| Overmocking | 6+ mocks per test | 4-5 mocks per test | 3 mocks (threshold, worth noting) |
| Test isolation | Order-dependent tests (fail when run individually) | Shared mutable module-level state with proper reset | Shared immutable fixtures (acceptable) |

#### What Beck Catches That Others Miss

- **Behavior gaps**: The diff changes retry logic but no test verifies what happens when retries exhaust. The implementation looks fine, but nothing proves it works.
- **Mock-driven design**: Tests that construct elaborate mock graphs to test a simple function. The mocks are load-bearing -- remove one and the test is meaningless. This signals the production code has too many dependencies.
- **False confidence**: A test file with 20 tests, all passing, all testing the same happy path with minor variations. Coverage number looks good, behavioral coverage is near zero.

#### Example Finding

```json
{
  "file": "src/auth/__tests__/login.test.ts",
  "line": 45,
  "severity": "critical",
  "issue": "Tests spy on internal hashPassword() -- will break if hashing is inlined or renamed",
  "fix": "Test login behavior: correct password returns session, wrong password returns error"
}
```

---

## Optional Add-On Perspectives

### Fowler (Code Smells)

Activate for refactoring PRs or large structural changes.

#### Persona Prompt

```
[FOWLER REVIEW]

You are Martin Fowler, author of "Refactoring".

Review this diff for:
1. Code smells: Long Method, Feature Envy, Data Clumps
2. Duplication (Rule of Three violations)
3. Shotgun Surgery (change requires touching many files)
4. Primitive Obsession (should be value object?)
5. Message Chains (a.b.c.d.e)

For each finding, report:
- file:line
- severity: critical / important / suggestion
- what the issue is (one sentence)
- suggested fix (one sentence)

After all findings, state your perspective verdict: fail / warn / pass.

[DIFF]
```

#### Severity Guide

| Dimension | Critical | Important | Suggestion |
|-----------|----------|-----------|------------|
| Long Method | >80 lines with multiple responsibilities | 50-80 lines, single responsibility but hard to skim | 40-50 lines that could be cleaner |
| Feature Envy | Method accesses 5+ fields of another object, none of its own | Method accesses 3-4 fields of another object | Mild envy, borderline |
| Duplication | Same 10+ line block in 3+ places | Same logic in 2 places, >15 lines each | Similar (not identical) patterns in 2 places |
| Shotgun Surgery | Changing one concept requires editing 5+ files | 3-4 files for one concept change | 2 files that arguably should be 1 |
| Primitive Obsession | Passing `(lat: number, lng: number)` through 5+ functions | 3-4 functions passing same primitive group | 2 functions, early stage |
| Message Chains | 5+ levels of chaining accessing internal structure | 3-4 levels | 2 levels in a context where it's avoidable |

#### What Fowler Catches That Others Miss

- **Structural duplication**: Two methods in different files that do the same thing with slightly different types. Ousterhout sees them as independent modules; Fowler sees a missing abstraction.
- **Feature Envy across module boundaries**: A function in module A that primarily manipulates data from module B. The function is in the wrong module, but it passes Ousterhout's depth check because it has real logic.
- **Shotgun Surgery**: Adding a new payment method requires touching 7 files. No single file is badly designed, but the concept is scattered.

---

### Data Integrity Guardian (Migration Safety)

Activate when the diff contains `*.sql`, migration files, or DDL (`CREATE`/`ALTER`/`DROP`).

#### Persona Prompt

```
[DATA INTEGRITY REVIEW]

Review this diff for data integrity issues.

CRITICAL: This PR contains database migrations. Include a Migration Visibility Report:

1. For each new column, identify if it's used in WHERE/JOIN predicates
2. State what value existing rows will have (NULL, default, backfilled)
3. Prove visibility preservation: "Existing [entity] will [still be queryable / become invisible] because [reason]"
4. If visibility is NOT preserved, flag as CRITICAL with required backfill SQL

Output MUST include:
| Table.Column | Used in Predicate | Legacy Value | Query Result | Action Required |
|--------------|-------------------|--------------|--------------|-----------------|

For each finding, also report:
- file:line
- severity: critical / important / suggestion
- what the issue is (one sentence)
- suggested fix (one sentence)

After all findings, state your perspective verdict: fail / warn / pass.

[DIFF]
```

#### Severity Guide

| Dimension | Critical | Important | Suggestion |
|-----------|----------|-----------|------------|
| Invisible rows | New NOT NULL column without backfill makes existing rows invisible to queries | New nullable column used in WHERE without COALESCE | New column not yet used in predicates |
| Data loss | DROP COLUMN / DROP TABLE without verified zero usage | ALTER TYPE that silently truncates | Removing unused index |
| Migration ordering | Migration references table/column from a later migration | Migration assumes data from a seed that may not have run | Migration order correct but tightly coupled |
| Rollback safety | No down migration for destructive change | Down migration exists but is untested | Down migration exists and tested |

#### What Data Integrity Guardian Catches That Others Miss

- **Invisible rows**: A migration adds `status VARCHAR NOT NULL DEFAULT 'active'` and the app queries `WHERE status = 'active'`. Looks fine. But existing rows have `NULL` if the migration didn't backfill. Those rows vanish from every query.
- **Silent type truncation**: `ALTER COLUMN price TYPE INTEGER` on a column that currently holds `99.99`. The data silently becomes `99`.
- **Ordering hazards**: Migration 003 adds a foreign key to a table created in migration 005. Works in dev (run together), fails in production (run incrementally).

---

## Synthesis Protocol

After all perspectives produce findings:

### 1. Identify Consensus

Group findings by file and line range (within 10 lines). When 2+ perspectives flag the same area:
- Promote to consensus finding
- Use the highest severity from any perspective
- Note which perspectives agree

### 2. Resolve Conflicts

When perspectives disagree (e.g., Grug says "delete this abstraction" but Ousterhout says "this abstraction is deep and valuable"):
- State both positions
- Resolve by asking: "Does this make the code easier or harder to change?"
- Document the reasoning

### 3. Compute Verdict

Per-perspective verdicts:
- Any **critical** finding -> perspective says **fail**
- Any **important** finding (no criticals) -> perspective says **warn**
- Only **suggestion** findings -> perspective says **pass**

Overall verdict:
- 2+ perspectives say **fail** -> **fail**
- 1 perspective says **fail**, or 2+ say **warn** -> **warn**
- All other cases -> **pass**

### 4. Surface Positive Observations

Every review must include at least one positive observation. What did the diff do well? This prevents the review from being purely adversarial and acknowledges good work.

---

## Cross-Perspective Blind Spot Matrix

Understanding what each perspective misses is as important as knowing what it catches.

| Blind Spot | Ousterhout | Grug | Beck | Fowler | Data Integrity |
|------------|-----------|------|------|--------|---------------|
| Test quality | Misses | Misses | **Catches** | Misses | Misses |
| Over-engineering | Partial | **Catches** | Misses | Misses | Misses |
| Interface decay | **Catches** | Partial | Misses | Partial | Misses |
| Code duplication | Misses | Misses | Misses | **Catches** | Misses |
| Migration safety | Misses | Misses | Misses | Misses | **Catches** |
| Debuggability | Partial | **Catches** | Misses | Misses | Misses |
| Behavioral gaps | Misses | Misses | **Catches** | Misses | Misses |
| Shotgun surgery | Partial | Misses | Misses | **Catches** | Misses |

This is why the triad exists: Ousterhout + Grug + Beck covers the critical surface. Fowler and Data Integrity extend coverage for specific PR types.
