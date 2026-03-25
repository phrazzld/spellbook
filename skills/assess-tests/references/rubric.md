# Test Quality Rubric -- Detailed Examples

Concrete examples for each anti-pattern. Every section shows:
bad code, why it fails the criterion, good code, and severity guidance.

Examples use TypeScript (vitest/jest), Rust (`#[test]`), Go (`testing.T`),
and Python (pytest). The principles are language-agnostic.

---

## 1. Implementation Coupling

Tests that break on refactor even when behavior is preserved.

### Bad -- TypeScript

```typescript
import { processOrder } from './order-service'
import * as pricing from './internal/pricing'

it('calls calculateDiscount during processing', () => {
  const spy = vi.spyOn(pricing, 'calculateDiscount')
  processOrder({ items: [{ id: 1, price: 100 }], coupon: 'SAVE10' })
  expect(spy).toHaveBeenCalledWith('SAVE10', 100)
})
```

**Why it's bad:** This test knows `processOrder` delegates to
`calculateDiscount`. Rename the internal function, inline it, or change its
signature and the test breaks -- even though order processing still works. You've
tested wiring, not behavior.

### Good -- TypeScript

```typescript
it('applies 10% coupon discount to order total', () => {
  const result = processOrder({ items: [{ id: 1, price: 100 }], coupon: 'SAVE10' })
  expect(result.total).toBe(90)
})
```

### Bad -- Rust

```rust
#[test]
fn test_internal_cache_hit() {
    let mut svc = Service::new();
    svc.fetch("key"); // prime cache
    svc.fetch("key"); // should hit cache
    assert_eq!(svc.cache_hits(), 1); // testing internal bookkeeping
}
```

### Good -- Rust

```rust
#[test]
fn fetch_returns_same_value_on_repeated_calls() {
    let mut svc = Service::new();
    let first = svc.fetch("key");
    let second = svc.fetch("key");
    assert_eq!(first, second);
}
```

### Bad -- Go

```go
func TestHandler_callsValidator(t *testing.T) {
    mock := &mockValidator{called: false}
    h := NewHandler(mock)
    h.Handle(Request{Name: "test"})
    if !mock.called {
        t.Fatal("expected validator to be called")
    }
}
```

### Good -- Go

```go
func TestHandler_rejectsInvalidName(t *testing.T) {
    h := NewHandler(validator.New())
    resp := h.Handle(Request{Name: ""})
    if resp.StatusCode != 400 {
        t.Fatalf("expected 400, got %d", resp.StatusCode)
    }
}
```

### Bad -- Python

```python
def test_sends_email(mocker):
    mock_send = mocker.patch('app.services.order._send_email')
    process_order(order)
    mock_send.assert_called_once_with(order.email, ANY)
```

### Good -- Python

```python
def test_order_confirmation_email_sent(mailbox):
    process_order(order)
    assert len(mailbox) == 1
    assert mailbox[0].to == order.email
```

**Severity:** FAIL. Implementation-coupled tests are actively harmful -- they
resist legitimate refactoring and give false confidence.

---

## 2. Mock Depth

More than 3 mocks per test = the test or the code needs restructuring.

### Bad -- TypeScript

```typescript
it('creates subscription', () => {
  const mockDb = vi.fn()
  const mockStripe = vi.fn()
  const mockEmail = vi.fn()
  const mockLogger = vi.fn()
  const mockCache = vi.fn()
  const mockMetrics = vi.fn()

  const svc = new SubscriptionService(mockDb, mockStripe, mockEmail, mockLogger, mockCache, mockMetrics)
  svc.create(user, plan)
  expect(mockStripe).toHaveBeenCalled()
})
```

**Why it's bad:** Six mocks means the test is either too broad (testing an
entire workflow as a "unit") or the code under test has too many dependencies
(violation of the dependency inversion principle). Each mock is a lie -- an
assumption about a collaborator's contract that may be wrong.

### Good -- TypeScript

```typescript
it('charges the correct amount for annual plan', () => {
  const payments = new FakePaymentGateway()
  const svc = new SubscriptionService(payments)

  svc.create(user, { plan: 'annual', price: 120 })

  expect(payments.lastCharge()).toEqual({ amount: 120, currency: 'usd' })
})
```

### Bad -- Go

```go
func TestCreateUser(t *testing.T) {
    db := &mockDB{}
    auth := &mockAuth{}
    mailer := &mockMailer{}
    logger := &mockLogger{}
    cache := &mockCache{}
    metrics := &mockMetrics{}
    svc := NewUserService(db, auth, mailer, logger, cache, metrics)
    // ...
}
```

### Good -- Go

```go
func TestCreateUser_persistsAndReturnsID(t *testing.T) {
    db := newTestDB(t)
    svc := NewUserService(db)

    id, err := svc.Create(User{Email: "test@example.com"})

    require.NoError(t, err)
    require.NotEmpty(t, id)
    got, _ := db.GetUser(id)
    require.Equal(t, "test@example.com", got.Email)
}
```

**Severity:** WARN at 4 mocks, FAIL at 6+. The fix is usually splitting the
code under test, not removing mocks from the test.

---

## 3. AAA Structure

Arrange, Act, Assert -- in that order, once each, with visual separation.

### Bad -- TypeScript

```typescript
it('processes items', () => {
  const cart = new Cart()
  cart.add({ id: 1, price: 10 })
  expect(cart.total()).toBe(10)         // assert mid-test
  cart.add({ id: 2, price: 20 })       // more acting
  expect(cart.total()).toBe(30)         // another assert
  cart.applyCoupon('HALF')             // more acting
  expect(cart.total()).toBe(15)         // yet another assert
})
```

**Why it's bad:** Three interleaved act/assert cycles in one test. When this
fails, which behavior broke? You can't tell from the test name. This is really
three tests hiding in a trench coat.

### Good -- TypeScript

```typescript
it('sums item prices', () => {
  const cart = new Cart()
  cart.add({ id: 1, price: 10 })
  cart.add({ id: 2, price: 20 })

  const total = cart.total()

  expect(total).toBe(30)
})

it('halves total with HALF coupon', () => {
  const cart = new Cart()
  cart.add({ id: 1, price: 30 })

  cart.applyCoupon('HALF')

  expect(cart.total()).toBe(15)
})
```

### Bad -- Python

```python
def test_user_workflow():
    user = create_user("alice")
    assert user.id is not None
    activate(user)
    assert user.active is True
    deactivate(user)
    assert user.active is False
```

### Good -- Python

```python
def test_new_user_gets_id():
    user = create_user("alice")
    assert user.id is not None

def test_activated_user_is_active():
    user = create_user("alice")
    activate(user)
    assert user.active is True
```

### Bad -- Rust

```rust
#[test]
fn test_stack_operations() {
    let mut s = Stack::new();
    s.push(1);
    assert_eq!(s.len(), 1);
    s.push(2);
    assert_eq!(s.peek(), Some(&2));
    s.pop();
    assert_eq!(s.len(), 1);
}
```

### Good -- Rust

```rust
#[test]
fn push_increases_length() {
    let mut s = Stack::new();

    s.push(1);

    assert_eq!(s.len(), 1);
}

#[test]
fn peek_returns_last_pushed() {
    let mut s = Stack::new();
    s.push(1);
    s.push(2);

    let top = s.peek();

    assert_eq!(top, Some(&2));
}
```

**Severity:** WARN. Interleaved AAA is a readability and diagnosis problem. Not
as dangerous as implementation coupling but a reliable indicator of tests that
will be hard to maintain.

---

## 4. One Behavior Per Test

Each test verifies one thing. Multiple unrelated assertions = multiple tests.

### Bad -- TypeScript

```typescript
it('works', () => {
  const user = createUser({ name: 'Alice', email: 'alice@test.com' })
  expect(user.id).toBeDefined()
  expect(user.name).toBe('Alice')
  expect(user.email).toBe('alice@test.com')
  expect(user.createdAt).toBeInstanceOf(Date)
  expect(user.role).toBe('member')
  expect(user.active).toBe(true)
})
```

**Why it's bad:** When this test fails on `role`, you also lose visibility into
whether `active` is correct because most runners stop at first failure. Six
assertions testing six different default behaviors should be six tests (or at
minimum, logically grouped: identity, timestamps, authorization defaults).

### Good -- TypeScript

```typescript
it('assigns member role by default', () => {
  const user = createUser({ name: 'Alice', email: 'alice@test.com' })
  expect(user.role).toBe('member')
})

it('starts as active', () => {
  const user = createUser({ name: 'Alice', email: 'alice@test.com' })
  expect(user.active).toBe(true)
})
```

**Note:** Multiple assertions testing *the same behavior* are fine:

```typescript
it('returns structured error for missing email', () => {
  const result = createUser({ name: 'Alice' })
  expect(result.ok).toBe(false)
  expect(result.error.field).toBe('email')
  expect(result.error.code).toBe('REQUIRED')
})
```

These three assertions verify one behavior: "validation produces a structured
error." They stand or fall together.

### Bad -- Go

```go
func TestNewConfig(t *testing.T) {
    cfg := NewConfig()
    if cfg.Port != 8080 { t.Fatal("wrong port") }
    if cfg.Host != "localhost" { t.Fatal("wrong host") }
    if cfg.Timeout != 30*time.Second { t.Fatal("wrong timeout") }
    if cfg.MaxRetries != 3 { t.Fatal("wrong retries") }
}
```

### Good -- Go

```go
func TestNewConfig_defaultPort(t *testing.T) {
    cfg := NewConfig()
    require.Equal(t, 8080, cfg.Port)
}

func TestNewConfig_defaultTimeout(t *testing.T) {
    cfg := NewConfig()
    require.Equal(t, 30*time.Second, cfg.Timeout)
}
```

**Severity:** WARN for 2-3 unrelated assertions, FAIL for 5+.

---

## 5. Test Name Clarity

Names describe the behavior under test, not the function name or test number.

### Bad Names

```
it('works')
it('test 1')
it('should work correctly')
it('handles edge case')
func TestProcess(t *testing.T)
def test_it():
#[test] fn test1()
```

### Good Names

```
it('returns 404 when user not found')
it('retries up to 3 times on network error')
it('strips HTML tags from user input')
func TestProcess_returnsErrOnEmptyInput(t *testing.T)
def test_expired_token_returns_401():
#[test] fn parse_rejects_negative_quantity()
```

**Heuristic:** Can you understand what behavior broke just by reading the test
name in CI output, without opening the file? If not, the name is too vague.

**Severity:** WARN. Bad names don't break code but they multiply debugging time
and make suites unreadable.

---

## 6. Edge Case Coverage

Happy-path-only suites miss the bugs that matter most.

### Bad -- TypeScript

```typescript
describe('divide', () => {
  it('divides two numbers', () => {
    expect(divide(10, 2)).toBe(5)
  })
})
```

### Good -- TypeScript

```typescript
describe('divide', () => {
  it('divides two positive numbers', () => {
    expect(divide(10, 2)).toBe(5)
  })

  it('throws on division by zero', () => {
    expect(() => divide(10, 0)).toThrow('Division by zero')
  })

  it('handles negative divisor', () => {
    expect(divide(10, -2)).toBe(-5)
  })

  it('returns zero when numerator is zero', () => {
    expect(divide(0, 5)).toBe(0)
  })
})
```

### Bad -- Rust

```rust
#[test]
fn parse_valid_json() {
    let result = parse(r#"{"name": "alice"}"#);
    assert!(result.is_ok());
}
```

### Good -- Rust

```rust
#[test]
fn parse_valid_json() {
    let result = parse(r#"{"name": "alice"}"#);
    assert!(result.is_ok());
}

#[test]
fn parse_empty_string_returns_error() {
    let result = parse("");
    assert!(result.is_err());
}

#[test]
fn parse_malformed_json_returns_error() {
    let result = parse(r#"{"name": }"#);
    assert!(result.is_err());
}

#[test]
fn parse_null_input_returns_error() {
    let result = parse("null");
    // Depends on contract: is JSON null valid input?
    assert!(result.is_err());
}
```

### Checklist

For any function under test, ask:
- What happens with empty/null/zero input?
- What happens at boundary values (0, 1, -1, MAX, MIN)?
- What happens when the external dependency fails?
- What happens with malformed/unexpected input?
- What happens under concurrent access (if applicable)?

**Severity:** WARN for missing 1-2 obvious edges, FAIL for happy-path-only
suites on critical code (auth, payments, data integrity).

---

## 7. Logic in Tests

Tests should be linear. Control flow means you don't know what the test verifies.

### Bad -- TypeScript

```typescript
it('handles all status codes', () => {
  const codes = [200, 201, 204, 301, 400, 404, 500]
  for (const code of codes) {
    const result = handleResponse({ status: code })
    if (code >= 400) {
      expect(result.ok).toBe(false)
    } else {
      expect(result.ok).toBe(true)
    }
  }
})
```

**Why it's bad:** This is a test generator disguised as a test. If status 204
fails, the test name says "handles all status codes" -- useless. The conditional
logic means the test itself could have bugs. Use parameterized tests instead.

### Good -- TypeScript

```typescript
it.each([200, 201, 204])('treats %i as success', (code) => {
  const result = handleResponse({ status: code })
  expect(result.ok).toBe(true)
})

it.each([400, 404, 500])('treats %i as failure', (code) => {
  const result = handleResponse({ status: code })
  expect(result.ok).toBe(false)
})
```

### Bad -- Python

```python
def test_permissions():
    for role in ['admin', 'editor', 'viewer']:
        user = create_user(role=role)
        if role == 'admin':
            assert can_delete(user)
        elif role == 'editor':
            assert can_edit(user) and not can_delete(user)
        else:
            assert not can_edit(user) and not can_delete(user)
```

### Good -- Python

```python
@pytest.mark.parametrize("role,expected", [
    ("admin", True),
    ("editor", False),
    ("viewer", False),
])
def test_only_admin_can_delete(role, expected):
    user = create_user(role=role)
    assert can_delete(user) == expected
```

### Bad -- Go

```go
func TestValidation(t *testing.T) {
    cases := []string{"", "  ", "a", strings.Repeat("a", 256)}
    for _, input := range cases {
        err := Validate(input)
        if len(input) == 0 || len(input) > 255 {
            if err == nil {
                t.Errorf("expected error for %q", input)
            }
        }
    }
}
```

### Good -- Go

```go
func TestValidate_rejectsEmptyString(t *testing.T) {
    err := Validate("")
    require.Error(t, err)
}

func TestValidate_rejectsOver255Chars(t *testing.T) {
    err := Validate(strings.Repeat("a", 256))
    require.Error(t, err)
}
```

**Exception:** Table-driven tests in Go and `it.each`/`@pytest.mark.parametrize`
are fine -- they are parameterization, not logic. The key distinction: the test
body should be linear with no branching. The parameterization framework handles
the iteration.

**Severity:** WARN for simple loops, FAIL for conditionals inside test bodies.

---

## 8. Assertion Presence

A test without an assertion proves nothing.

### Bad -- TypeScript

```typescript
it('processes the order', () => {
  const order = createOrder({ items: [{ id: 1 }] })
  processOrder(order) // no assertion -- what did we verify?
})

it('logs the result', () => {
  const result = calculate(42)
  console.log(result) // logging is not asserting
})
```

### Good -- TypeScript

```typescript
it('marks order as processed', () => {
  const order = createOrder({ items: [{ id: 1 }] })
  const result = processOrder(order)
  expect(result.status).toBe('processed')
})
```

### Bad -- Rust

```rust
#[test]
fn test_parse() {
    let _ = parse("hello world"); // result discarded
}
```

### Good -- Rust

```rust
#[test]
fn parse_extracts_greeting() {
    let result = parse("hello world").unwrap();
    assert_eq!(result.greeting, "hello");
}
```

### Bad -- Python

```python
def test_export():
    export_data(sample_data)  # no assertion
```

### Good -- Python

```python
def test_export_creates_file(tmp_path):
    output = tmp_path / "export.csv"
    export_data(sample_data, output)
    assert output.exists()
    assert output.read_text().startswith("id,name")
```

**Note:** `expect(...).toThrow()`, `assert_raises`, `#[should_panic]`, and
`require.Error()` count as assertions -- they verify behavior (that the code
raises/panics).

**Severity:** FAIL. A test without an assertion is dead weight. It runs, passes,
and proves nothing. Worse, it inflates test count and gives false confidence.

---

## 9. Test Isolation

Tests must not depend on execution order or shared mutable state.

### Bad -- TypeScript

```typescript
let counter = 0

it('increments counter', () => {
  counter++
  expect(counter).toBe(1)
})

it('increments again', () => {
  counter++
  expect(counter).toBe(2) // fails if first test doesn't run
})
```

### Good -- TypeScript

```typescript
it('increments from zero', () => {
  let counter = 0
  counter++
  expect(counter).toBe(1)
})

it('increments from any value', () => {
  let counter = 5
  counter++
  expect(counter).toBe(6)
})
```

### Bad -- Go

```go
var globalDB *TestDB

func TestMain(m *testing.M) {
    globalDB = setupDB()
    os.Exit(m.Run())
}

func TestCreateUser(t *testing.T) {
    globalDB.Insert(User{ID: "1", Name: "alice"})
    // leaves state for next test
}

func TestGetUser(t *testing.T) {
    user := globalDB.Get("1") // depends on TestCreateUser running first
    require.Equal(t, "alice", user.Name)
}
```

### Good -- Go

```go
func TestGetUser(t *testing.T) {
    db := newTestDB(t)
    db.Insert(User{ID: "1", Name: "alice"})

    user := db.Get("1")

    require.Equal(t, "alice", user.Name)
}
```

### Bad -- Python

```python
data = []

def test_append():
    data.append(1)
    assert len(data) == 1

def test_length():
    assert len(data) == 1  # depends on test_append
```

### Good -- Python

```python
def test_append():
    data = []
    data.append(1)
    assert len(data) == 1

def test_empty_list_has_zero_length():
    data = []
    assert len(data) == 0
```

**Diagnostic:** Run the suite in random order. If tests fail, isolation is
broken. Most runners support this: `vitest --sequence.shuffle`,
`pytest -p randomly`, `go test -shuffle=on`, `cargo test -- --shuffle`.

**Severity:** FAIL. Order-dependent tests cause phantom CI failures and erode
trust in the suite.

---

## 10. Refactor Resilience

The meta-criterion. Ask: if I renamed every private function, changed the
internal data structure, or swapped the algorithm -- would these tests still pass?

### Evaluation Heuristic

For each test, classify:

| Test Type | Refactor Impact | Verdict |
|-----------|----------------|---------|
| Asserts on public return value | None | Behavioral |
| Asserts on observable side effect (DB row, HTTP response, file) | None | Behavioral |
| Asserts on mock call count/order | Breaks | Implementation-coupled |
| Asserts on internal state (`obj._private`) | Breaks | Implementation-coupled |
| Asserts on log output as primary verification | Fragile | Smell |

A suite with >30% implementation-coupled tests is a refactoring hazard. The
tests don't protect behavior -- they freeze implementation.

### The Litmus Test

> "Can I delete the function body, write a completely different implementation
> that produces the same outputs for the same inputs, and have all tests pass?"

If yes: behavioral tests. If no: implementation tests.

**Severity:** This is the aggregate verdict. A suite that fails the litmus test
across most tests scores below 50 regardless of individual criterion scores.

---

## Severity Summary

| Criterion | FAIL threshold | WARN threshold |
|-----------|---------------|----------------|
| Implementation coupling | Any spy on internals | Mocking internal modules |
| Mock depth | 6+ mocks per test | 4-5 mocks per test |
| AAA structure | -- | Interleaved act/assert |
| One behavior per test | 5+ unrelated assertions | 2-3 unrelated assertions |
| Test name clarity | -- | Vague or numbered names |
| Edge case coverage | Happy-path-only on critical code | Missing 1-2 obvious edges |
| Logic in tests | Conditionals in test body | Simple loops (prefer parameterize) |
| Assertion presence | Any test without assertion | -- |
| Test isolation | Order-dependent tests | Shared mutable state with proper reset |
| Refactor resilience | >30% implementation-coupled | 10-30% implementation-coupled |
