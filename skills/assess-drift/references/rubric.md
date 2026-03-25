# Drift Assessment Rubric

Concrete examples for each of the eight dimensions. Every section covers: how to read constraint sources, what the violation looks like, why it's bad, what the fix looks like, and severity guidance.

---

## Reading Constraint Sources

Architectural constraints live in project docs. Check these in order -- earlier sources override later ones:

### Declared Boundaries (explicit)

**CLAUDE.md** -- Often contains direct statements:
```markdown
## Architecture
- API handlers must not import from db/ directly
- Domain layer has zero external dependencies
- All external API calls go through src/clients/
```

**docs/architecture.md** -- Formal boundary declarations:
```markdown
## Module Boundaries
src/api/     -> src/services/  (allowed)
src/services -> src/repos/     (allowed)
src/repos/   -> src/db/        (allowed)
src/api/     -> src/db/        (FORBIDDEN)
```

**ADRs** -- Decisions that establish constraints:
```markdown
# ADR-003: Hexagonal Architecture
We adopt ports-and-adapters. Domain core must not import from adapters/.
```

**AGENTS.md** -- Agent-specific boundaries:
```markdown
Agents must not directly access the database. Use the provided tool interfaces.
```

### Implicit Boundaries (inferred)

When no explicit docs exist, infer from structure:

- **Directory depth implies layering.** If `src/api/`, `src/services/`, and `src/db/` exist as siblings, the naming implies a top-to-bottom dependency direction.
- **Existing import patterns.** If 95% of files in `src/api/` import from `src/services/` and zero import from `src/db/`, that's an implicit boundary.
- **Package/module naming.** `internal/`, `private/`, `_helpers/` signal intended encapsulation.

**Key rule:** Inferred boundaries cap at `warning` severity. Only explicit, documented boundaries produce `critical` findings.

---

## 1. Boundary Violations

A boundary violation occurs when code imports across a documented module boundary.

### What it looks like

**TypeScript**
```typescript
// src/api/handlers/order.ts
// VIOLATION: API handler importing directly from DB layer
import { orderQueries } from '../../db/queries/orders'

export async function getOrder(req: Request) {
  const order = await orderQueries.findById(req.params.id)
  return Response.json(order)
}
```

**Go**
```go
// cmd/api/handler.go
// VIOLATION: HTTP handler importing repository internals
import "myapp/internal/postgres"

func GetUser(w http.ResponseWriter, r *http.Request) {
    user, _ := postgres.QueryUser(r.Context(), id)
    json.NewEncoder(w).Encode(user)
}
```

**Rust**
```rust
// src/api/routes.rs
// VIOLATION: route handler reaching into storage layer
use crate::storage::postgres::queries;

async fn get_item(id: Uuid) -> impl Responder {
    let item = queries::find_item(id).await;
    HttpResponse::Ok().json(item)
}
```

### Why it's bad

The intermediate layer (service, repository) exists to decouple the API from storage. Bypassing it means:
- Changing the storage backend requires changing API handlers
- Business logic (validation, authorization) gets skipped or duplicated
- Two paths to the same data with different invariants

### What the fix looks like

```typescript
// src/api/handlers/order.ts
import { OrderRepository } from '../../repositories/order'

export async function getOrder(req: Request, repo: OrderRepository) {
  const order = await repo.findById(req.params.id)
  return Response.json(order)
}
```

### Severity

- **Critical**: Import crosses a boundary explicitly declared in project docs.
- **Warning**: Import crosses an inferred boundary (no docs, but existing code never does this).
- **Info**: Import crosses a conventional boundary that the project hasn't established (e.g., new project with no layering yet).

---

## 2. Dependency Direction

Lower layers must not depend on higher layers. Domain must not know about HTTP. Storage must not know about UI.

### What it looks like

**TypeScript**
```typescript
// src/domain/order.ts
// VIOLATION: Domain model importing from HTTP layer
import { RequestContext } from '../api/middleware/context'

export class Order {
  constructor(private ctx: RequestContext) {} // domain coupled to HTTP
}
```

**Go**
```go
// pkg/billing/invoice.go
// VIOLATION: billing package importing from HTTP handler
import "myapp/internal/api"

func FormatInvoice(inv Invoice) string {
    return api.RenderTemplate("invoice", inv) // billing depends on API
}
```

**Elixir**
```elixir
# lib/my_app/accounts/user.ex
# VIOLATION: domain context importing from web layer
alias MyAppWeb.UserView

def display_name(%User{} = user) do
  UserView.render_name(user)  # domain coupled to presentation
end
```

### Why it's bad

Upward dependencies create cycles and prevent independent deployment/testing of lower layers. The domain becomes untestable without spinning up an HTTP server.

### What the fix looks like

Invert the dependency. The higher layer depends on the lower, never the reverse:

```typescript
// src/domain/order.ts -- no HTTP imports
export class Order {
  constructor(private data: OrderData) {}
}

// src/api/handlers/order.ts -- API depends on domain, not vice versa
import { Order } from '../../domain/order'
```

### Severity

- **Critical**: Domain/core layer imports from adapter/infrastructure/UI layer (explicit layering declared).
- **Warning**: Shared library imports from application code.
- **Info**: Ambiguous direction in a flat project structure.

---

## 3. New Global State

Mutable state at module scope is architectural poison. It creates hidden coupling, breaks test isolation, and makes concurrency bugs inevitable.

### What it looks like

**TypeScript**
```typescript
// VIOLATION: module-level mutable state
let connectionPool: Pool | null = null

export function getPool(): Pool {
  if (!connectionPool) {
    connectionPool = createPool(process.env.DATABASE_URL!)
  }
  return connectionPool
}
```

**Go**
```go
// VIOLATION: package-level mutable state
var (
    defaultClient *http.Client
    once          sync.Once
)

func GetClient() *http.Client {
    once.Do(func() {
        defaultClient = &http.Client{Timeout: 30 * time.Second}
    })
    return defaultClient
}
```

**Rust**
```rust
// VIOLATION: lazy_static global
lazy_static! {
    static ref CONFIG: RwLock<Config> = RwLock::new(Config::default());
}
```

**Python**
```python
# VIOLATION: module-level mutable state
_cache: dict[str, Any] = {}

def get_cached(key: str) -> Any:
    return _cache.get(key)
```

### Why it's bad

- Tests can't reset state between runs (isolation failure)
- Concurrent access requires synchronization (or produces races)
- Dependency injection becomes impossible (the module owns its own wiring)
- Startup order matters (temporal coupling)

### What the fix looks like

Pass state explicitly. Construct at the composition root, inject everywhere else:

```typescript
export class DatabasePool {
  private pool: Pool

  constructor(url: string) {
    this.pool = createPool(url)
  }

  query<T>(sql: string, params: unknown[]): Promise<T> { ... }
}
```

### Severity

- **Critical**: New singleton or global mutable state in a module that previously had none.
- **Warning**: New mutable state guarded by synchronization (sync.Once, lazy_static with Mutex).
- **Info**: Module-level constants (immutable) -- not a real violation but worth noting if the project convention is to avoid module-level declarations entirely.

---

## 4. Layer Bypass

An abstraction layer exists but new code goes around it.

### What it looks like

**TypeScript**
```typescript
// An API client exists: src/clients/stripe.ts
// But the new code ignores it:
export async function chargeCustomer(customerId: string, amount: number) {
  // VIOLATION: raw fetch instead of using the Stripe client
  const res = await fetch('https://api.stripe.com/v1/charges', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${process.env.STRIPE_KEY}` },
    body: new URLSearchParams({ customer: customerId, amount: String(amount) }),
  })
  return res.json()
}
```

**Go**
```go
// A repository exists: internal/repo/user.go
// But the handler does raw SQL:
func CreateUser(w http.ResponseWriter, r *http.Request) {
    // VIOLATION: bypassing the repository
    db.Exec("INSERT INTO users (name, email) VALUES ($1, $2)", name, email)
}
```

### Why it's bad

The bypassed layer likely handles: error normalization, retries, logging, authentication, caching, or business rules. Skipping it means those concerns are either missing or will be duplicated in the bypass path. Two paths to the same external dependency with different error handling is a bug factory.

### What the fix looks like

Use the existing abstraction:

```typescript
import { stripeClient } from '../clients/stripe'

export async function chargeCustomer(customerId: string, amount: number) {
  return stripeClient.charges.create({ customer: customerId, amount })
}
```

### Severity

- **Critical**: Bypass of a layer that handles auth, authorization, or data validation.
- **Warning**: Bypass of a layer that handles logging, error normalization, or caching.
- **Info**: Bypass in test/script code where the full stack isn't needed.

---

## 5. Interface Bloat

A module's public surface area grew. More exports, more parameters, more methods.

### What it looks like

**Before (clean)**
```typescript
// src/payments/index.ts -- 3 exports
export { chargeCustomer } from './charge'
export { refundCharge } from './refund'
export { PaymentError } from './errors'
```

**After (bloated)**
```typescript
// src/payments/index.ts -- 8 exports, 5 new
export { chargeCustomer } from './charge'
export { refundCharge } from './refund'
export { PaymentError } from './errors'
export { validateCard } from './validation'       // new
export { formatAmount } from './formatting'        // new
export { retryPayment } from './retry'             // new
export { getPaymentStatus } from './status'        // new
export { PaymentWebhookHandler } from './webhooks' // new
```

**Parameter growth**
```typescript
// Before: 2 params
export function createUser(name: string, email: string): User

// After: 6 params
export function createUser(
  name: string,
  email: string,
  role: Role,
  teamId: string,
  avatar?: string,
  locale?: string,
): User
```

### Why it's bad

Every export is a promise to callers. Width grows monotonically -- removing an export is a breaking change. A module with 15 exports is 15 things callers must understand. Interface bloat is the slow death of deep modules.

### What the fix looks like

- Group related functionality into sub-modules with narrow re-exports
- Use configuration objects instead of parameter lists
- Keep internal helpers unexported

### Severity

- **Critical**: Module public API doubled or tripled in one PR without architectural justification.
- **Warning**: 2-3 new exports or a function gained 2+ parameters.
- **Info**: Single new export that extends an existing pattern (e.g., new CRUD method on a repository).

---

## 6. Naming Drift

Red-flag names that signal unclear responsibilities.

### Red-flag suffixes

| Suffix | Problem | Better alternative |
|--------|---------|-------------------|
| Manager | Manages what? Everything? | Name the specific responsibility: `Scheduler`, `Pool`, `Registry` |
| Helper | A bag of unrelated functions | Name the operation: `WordWrap`, `Sanitizer`, `Formatter` |
| Util/Utils | The junk drawer | Split into focused modules or inline |
| Data | How is `UserData` different from `User`? | Use the domain name: `User`, `UserProfile`, `UserCredentials` |
| Info | Same problem as Data | Be specific: `UserSummary`, `UserMetadata` |
| Base | Inheritance smell | Prefer composition; if needed: `Abstract` prefix in languages that support it |
| Common | Everything is common to something | Split by actual consumer |
| Misc | Literally "I don't know where this goes" | Find the right module or create one with a real name |

### What it looks like

```
PaymentManager.ts      -- manages what? Charging? Reconciliation? Refunds?
StringHelper.go        -- bag of unrelated string operations
DataProcessor.rs       -- processes what data, how?
CommonUtils.ex         -- junk drawer for the whole app
BaseService.ts         -- inheritance where composition would do
OrderInfo.ts           -- how is this different from Order.ts?
```

### When it's NOT a violation

- Framework-mandated names (`Handler` in Go HTTP, `Controller` in Rails)
- Test utilities (`testhelper_test.go` in Go is idiomatic)
- Language conventions (`__init__.py`, `mod.rs`)

### Severity

- **Critical**: New `Manager`, `Helper`, or `Util` with >10 methods spanning multiple concerns.
- **Warning**: Red-flag name on a focused module (name is wrong, code is fine).
- **Info**: Red-flag name in test/script code or framework-mandated context.

---

## 7. Circular Dependencies

Import cycles. A depends on B, B depends on C, C depends on A.

### What it looks like

**TypeScript**
```typescript
// src/auth/session.ts
import { User } from '../users/model'     // auth -> users

// src/users/model.ts
import { Session } from '../auth/session'  // users -> auth (CYCLE)
```

**Go**
```go
// package auth imports package users
import "myapp/users"

// package users imports package auth
import "myapp/auth"  // compile error in Go, but possible in TS/Python
```

**Python**
```python
# app/orders/service.py
from app.billing.invoice import create_invoice

# app/billing/invoice.py
from app.orders.service import get_order  # CYCLE
```

### Why it's bad

- Can't understand either module in isolation
- Can't compile/load either module independently (language-dependent)
- Can't test either module without the other
- Changes to either module risk breaking both

### What the fix looks like

Extract the shared concept:

```typescript
// src/shared/types.ts -- shared types break the cycle
export interface UserRef { id: string; email: string }

// src/auth/session.ts
import { UserRef } from '../shared/types'

// src/users/model.ts -- no longer needs auth
```

Or invert with an interface:

```typescript
// src/auth/session.ts
export interface SessionUser { id: string; email: string }

// src/users/model.ts
import type { SessionUser } from '../auth/session' // type-only import (no runtime cycle)
```

### Severity

- **Critical**: Runtime circular dependency introduced (causes initialization errors or infinite loops).
- **Warning**: Type-only circular dependency (no runtime impact but indicates design coupling).
- **Info**: Circular dependency in test files (less impactful, still a smell).

---

## 8. Convention Drift

New code follows different patterns than existing code in the same module.

### What it looks like

**Mixed error handling in one module**
```typescript
// Existing pattern: functions return Result
export function parseConfig(raw: string): Result<Config, ParseError> { ... }
export function validateConfig(config: Config): Result<Config, ValidationError> { ... }

// New code: throws instead of returning Result
export function mergeConfigs(a: Config, b: Config): Config {
  if (a.version !== b.version) {
    throw new Error('Version mismatch')  // CONVENTION DRIFT
  }
  return { ...a, ...b }
}
```

**Mixed async patterns**
```typescript
// Existing: async/await
async function fetchUser(id: string): Promise<User> {
  const res = await api.get(`/users/${id}`)
  return res.data
}

// New: callback-based in the same module
function fetchOrders(userId: string, callback: (err: Error | null, orders: Order[]) => void) {
  api.get(`/users/${userId}/orders`).then(
    res => callback(null, res.data),
    err => callback(err, [])
  )
}
```

**Mixed naming in one module**
```go
// Existing: snake_case function names (idiomatic Go? No, but consistent)
func get_user(id string) (*User, error) { ... }
func update_user(id string, data UserData) error { ... }

// New: camelCase in the same file
func deleteUser(id string) error { ... }  // CONVENTION DRIFT
```

### Why it's bad

Inconsistency within a module forces readers to handle two mental models. Is the new pattern intentional (migration) or accidental (different author)? Without explicit documentation of a migration, assume accidental.

### What the fix looks like

Follow the existing pattern. If the existing pattern is bad, migrate the whole module -- don't create a mixed state.

### When it's NOT a violation

- Explicitly documented migration (ADR says "new code uses async/await, we're migrating from callbacks")
- Language/framework upgrade that changes idioms (new version of the framework uses different patterns)
- Test code following different conventions than production code (sometimes justified)

### Severity

- **Critical**: Mixed error handling strategies in one module (some throw, some return Result) with no migration plan.
- **Warning**: Mixed naming conventions or async patterns in one file.
- **Info**: Stylistic differences between files in the same directory (less impactful than within-file drift).

---

## Cross-Cutting Severity Escalation

Regardless of individual dimension severity, escalate to critical when:

- **Compound violations**: Same file triggers 3+ dimensions (e.g., boundary violation + layer bypass + naming drift = the code is in the wrong place entirely).
- **Viral pattern**: The violation is templated and will be copied (e.g., a new "base class" that every future module will extend).
- **Load-bearing boundary**: The violated boundary protects security, data integrity, or billing (auth bypass is always critical).
- **Regression**: A boundary that was previously respected is now broken (drift accelerating, not just present).

## Declared vs Inferred -- Decision Matrix

| Constraint type | Source | Max severity | Confidence |
|----------------|--------|-------------|------------|
| Explicit rule | CLAUDE.md, ADR, architecture.md | critical | high |
| Documented convention | README, style guide | warning | medium |
| Inferred from structure | Import patterns, directory names | warning | low |
| No constraint exists | -- | info (flag missing docs) | none |

When in doubt, flag the finding at `info` with a note recommending the project document the constraint explicitly.
