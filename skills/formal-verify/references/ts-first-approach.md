# TS-First Formal Verification

The core insight: agents write correct TypeScript state machines more reliably than
raw TLA+. Start in TS, map to TLA+ for verification, keep both in sync.

## Why TS-First

TLA+ is a verification language, not an implementation language. Agents (and most
engineers) think in implementation terms. Writing the state machine in TypeScript
first produces a spec that:

1. **Is testable immediately** — run it, unit test it, catch obvious bugs
2. **Maps to TLA+ mechanically** — the translation is a mapping table, not creative work
3. **Stays in sync** — the TS version IS the implementation; the TLA+ version IS the proof
4. **Lowers the adoption barrier** — you don't need to learn TLA+ to benefit from formal verification

## TS → TLA+ Mapping Table

| TypeScript | TLA+ Equivalent | Notes |
|-----------|----------------|-------|
| `type State = 'idle' \| 'loading' \| 'error'` | `State == {"idle", "loading", "error"}` | Discriminated union → set of values |
| `interface MachineState { status: State; retries: number }` | `VARIABLES status, retries` | Interface fields → TLA+ variables |
| `function transition(s: MachineState, event: Event): MachineState` | `Next == \E e \in Events: Transition(e)` | Pure transition function → next-state relation |
| `if (state.status === 'idle' && event === 'FETCH')` | `status = "idle" /\ event = "FETCH"` | Guard conditions → conjunction |
| `return { ...state, status: 'loading' }` | `status' = "loading" /\ UNCHANGED retries` | Spread update → primed variables + UNCHANGED |
| `state.retries < MAX_RETRIES` | `retries < MAX_RETRIES` | Numeric guards map directly |
| `state.retries + 1` | `retries' = retries + 1` | Arithmetic maps directly |
| `switch (event.type) { ... }` | `\/ Case1 \/ Case2 \/ Case3` | Switch → disjunction of cases |
| `Set<string>` | `SUBSET STRING` | Set type → powerset |
| `Map<K, V>` | `[K -> V]` | Map → function |
| `Array<T>` | `Seq(T)` | Ordered collection → sequence |
| `Promise<T>` / async | Separate process in PlusCal | Concurrency → PlusCal processes |

## Where the Mapping Breaks Down

### 1. Concurrency

TS `async/await` is cooperative (single-threaded with yield points). TLA+ models
TRUE concurrency — any interleaving of any process at any step. The TLA+ model
is strictly MORE general, which is what you want (it finds bugs the TS version hides).

**Gotcha:** If your TS code uses `Promise.all` or event emitters, the TLA+ version
must model each promise/handler as a separate process. Don't model `Promise.all`
as atomic — the whole point is finding interleaving bugs.

### 2. Infinity

TLA+ can reason about infinite sets and unbounded execution. TypeScript can't.
For model checking, you must bound everything anyway (`CONSTANTS MAX_RETRIES = 3`),
so this rarely matters in practice.

**Gotcha:** Don't confuse "TLA+ can express infinity" with "TLC can check infinity."
TLC (the model checker) requires finite domains. Apalache can handle some unbounded
cases symbolically.

### 3. Fairness

TLA+ has weak and strong fairness constraints (WF, SF) — guarantees that enabled
actions eventually happen. TypeScript has no equivalent concept.

**Gotcha:** Liveness properties (`<>[] done` — "eventually always done") need
fairness constraints. Without them, TLC will find a "counterexample" where a
process simply never runs, which is vacuously true but useless.

### 4. Nondeterminism

TLA+ natively expresses `\E x \in S: ...` (there exists some value). TypeScript
must pick a specific value. The TLA+ model explores ALL possible values.

**Gotcha:** If your TS uses `Math.random()` or user input, model it as
`\E value \in Domain: ...` in TLA+. Don't hardcode a specific test value.

### 5. UNCHANGED

In TLA+, you must explicitly state which variables DON'T change in each action.
TypeScript's spread (`{ ...state, status: 'new' }`) implicitly preserves other
fields.

**Gotcha:** Forgetting `UNCHANGED` is the most common TLA+ bug. A missing
`UNCHANGED <<var>>` means the variable can take ANY value in that step — the
model checker will find spurious counterexamples.

## Proof Tiers

| Tier | When | Bounds | Runtime |
|------|------|--------|---------|
| **Quick** (PR check) | Every PR touching state machine code | Small domains: 2-3 actors, 2-3 items, 3-5 states | < 30 seconds |
| **Standard** (merge gate) | Before merge to main | Medium domains: 3-5 actors, 5-10 items | < 5 minutes |
| **Exhaustive** (nightly) | Scheduled CI | Full domain exploration | < 1 hour |

**Quick tier is the adoption gateway.** If it takes > 30s in a PR check, developers
will skip it. Start with the smallest bounds that still catch real bugs (usually
2 actors and 3 states are enough for most race conditions).

## Invariants to Always Check

1. **Type invariant** — all variables in their declared domains
2. **No deadlock** — some action is always enabled (or you've explicitly modeled termination)
3. **Mutual exclusion** — if applicable, no two processes in critical section
4. **Eventually done** — liveness: the system makes progress (requires fairness)

## Workflow

```text
TS state machine → unit tests pass → generate TLA+ → TLC model check
    ↑                                      ↓
    ← fix the DESIGN (not the spec) ← counterexample found
```

Key: when TLC finds a counterexample, fix the TypeScript state machine first,
then regenerate/update the TLA+ spec. The TS version is the source of truth for
the implementation; the TLA+ version is the source of truth for correctness.
