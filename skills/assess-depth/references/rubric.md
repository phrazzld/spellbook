# Depth Assessment Rubric

Concrete examples for each of the seven dimensions. Every section covers: what the anti-pattern looks like, why it's bad, what good looks like, and when to escalate severity.

---

## 1. Shallow Modules

A module whose interface is as complex as (or more complex than) its implementation. The caller gains nothing from the abstraction.

### What it looks like

**TypeScript**
```typescript
// UserNameFormatter.ts -- the entire module
export class UserNameFormatter {
  format(first: string, last: string): string {
    return `${first} ${last}`;
  }
}
```

**Go**
```go
// validate.go
package validate

func IsNonEmpty(s string) bool {
    return len(s) > 0
}

func IsPositive(n int) bool {
    return n > 0
}

func IsValidEmail(email string) bool {
    return strings.Contains(email, "@")
}
```

### Why it's bad

The caller must understand the same amount of detail with or without the abstraction. The module adds a name and a file but hides nothing. Every caller could inline the logic trivially. The module exists to satisfy organizational convention, not to manage complexity.

### What good looks like

**TypeScript**
```typescript
// UserIdentity.ts -- deep: hides normalization, deduplication, display rules
export class UserIdentity {
  constructor(private readonly raw: RawUserRecord) {}

  /** Display name with fallback chain: preferred > full > email prefix */
  get displayName(): string { /* 30+ lines of fallback logic */ }

  /** Stable identifier across auth provider migrations */
  get canonicalId(): string { /* hashing + normalization */ }
}
```

**Go**
```go
// ratelimit.go -- deep: hides token bucket, clock, persistence
package ratelimit

type Limiter struct { /* unexported fields */ }

func New(rps float64) *Limiter { ... }
func (l *Limiter) Allow() bool { ... }
```

### Severity

- **Critical**: 3+ shallow modules in the same package/directory that could be one deep module.
- **Warning**: Single shallow module that adds unnecessary indirection.
- **Info**: Shallow module justified by framework requirements (e.g., required middleware signature).

---

## 2. Pass-Through Methods

Methods whose only job is forwarding a call to another object. They exist because someone drew a layer diagram, not because the layer does anything.

### What it looks like

**TypeScript**
```typescript
class OrderService {
  constructor(private repo: OrderRepository) {}

  getOrder(id: string) { return this.repo.getOrder(id); }
  listOrders(userId: string) { return this.repo.listOrders(userId); }
  createOrder(data: OrderData) { return this.repo.createOrder(data); }
  deleteOrder(id: string) { return this.repo.deleteOrder(id); }
  updateOrder(id: string, data: Partial<OrderData>) {
    return this.repo.updateOrder(id, data);
  }
}
```

**Rust**
```rust
impl Gateway {
    pub fn send(&self, msg: Message) -> Result<()> {
        self.transport.send(msg)
    }
    pub fn recv(&self) -> Result<Message> {
        self.transport.recv()
    }
}
```

**Elixir**
```elixir
defmodule MyApp.Orders do
  alias MyApp.Repo
  alias MyApp.Orders.Order

  def get(id), do: Repo.get(Order, id)
  def list(user_id), do: Repo.all(from o in Order, where: o.user_id == ^user_id)
  def create(attrs), do: %Order{} |> Order.changeset(attrs) |> Repo.insert()
  def delete(id), do: Repo.get!(Order, id) |> Repo.delete()
end
```

### Why it's bad

Two interfaces for the price of one. Every change to the underlying layer forces a change in the pass-through layer. The "service" layer trains developers to add more pass-through methods instead of putting real logic somewhere. The system is harder to navigate: you read `OrderService.createOrder`, expect logic, find none, and must jump to `OrderRepository.createOrder`.

### What good looks like

Either delete the layer entirely, or give it real responsibility:

**TypeScript**
```typescript
class OrderService {
  constructor(
    private repo: OrderRepository,
    private inventory: InventoryService,
    private events: EventBus,
  ) {}

  async placeOrder(cart: Cart): Promise<Order> {
    const reserved = await this.inventory.reserve(cart.items);
    const order = await this.repo.create({ items: reserved, total: cart.total });
    this.events.emit('order.placed', order);
    return order;
  }
}
```

Now the service orchestrates across multiple concerns. It earns its existence.

### Severity

- **Critical**: >50% of a module's public methods are pure delegation.
- **Warning**: 2-3 pass-through methods in an otherwise meaningful module.
- **Info**: Single pass-through method that exists for interface compliance (trait impl, protocol conformance).

---

## 3. Information Leakage

Implementation details escape through the public interface. Callers become coupled to how a module works internally, not what it does.

### What it looks like

**TypeScript**
```typescript
// Leaks storage format into the interface
interface CacheService {
  getFromRedis(key: string): Promise<string | null>;
  setInRedis(key: string, value: string, ttlSeconds: number): Promise<void>;
  invalidateRedisPattern(pattern: string): Promise<void>;
}

// Leaks internal error structure
class PaymentProcessor {
  async charge(amount: number): Promise<{
    stripeChargeId: string;        // caller now knows it's Stripe
    stripeBalanceTransaction: string;
    rawStripeResponse: object;      // entire vendor response exposed
  }> { ... }
}
```

**Go**
```go
// Leaks SQL structure into return type
type UserStore struct {
    DB *sql.DB  // exported field: callers can bypass the store
}

func (s *UserStore) Find(id int) (*sql.Row, error) {
    return s.DB.QueryRow("SELECT * FROM users WHERE id = ?", id), nil
}
```

**Rust**
```rust
// Leaks serialization format
pub struct Config {
    pub toml_table: toml::Table,  // caller coupled to TOML
}
```

### Why it's bad

Changing the implementation (swap Redis for Memcached, Stripe for Braintree, TOML for YAML) forces changes in every caller. The module boundary exists on paper but provides no isolation in practice.

### What good looks like

**TypeScript**
```typescript
interface CacheService {
  get(key: string): Promise<string | null>;
  set(key: string, value: string, ttl: Duration): Promise<void>;
  invalidate(pattern: string): Promise<void>;
}

class PaymentProcessor {
  async charge(amount: Money): Promise<ChargeResult> { ... }
  // ChargeResult has: id, status, receiptUrl -- no vendor details
}
```

**Go**
```go
type UserStore struct {
    db *sql.DB  // unexported: callers can't touch it
}

func (s *UserStore) Find(id int) (*User, error) {
    // returns domain type, not sql.Row
}
```

### Severity

- **Critical**: Storage backend, vendor SDK, or wire format exposed in public interface.
- **Warning**: Internal error types or codes leak through (e.g., HTTP status codes in a domain layer).
- **Info**: Implementation-hinting parameter names (`redisKey` instead of `key`) without structural coupling.

---

## 4. Temporal Decomposition

Code organized by execution phase (init, validate, process, cleanup) rather than by the information each piece manages. Forces readers to mentally reconstruct the data flow across phases.

### What it looks like

**TypeScript**
```typescript
// Three files organized by WHEN, not WHAT
// 1-validate-input.ts
export function validateOrderInput(raw: unknown): OrderInput { ... }

// 2-process-order.ts
export function processOrder(input: OrderInput): OrderResult { ... }

// 3-send-confirmation.ts
export function sendConfirmation(result: OrderResult): void { ... }
```

**Go**
```go
// pipeline.go -- organized by execution order
func Init(cfg Config) (*State, error) { ... }
func Validate(s *State) error { ... }
func Transform(s *State) error { ... }
func Persist(s *State) error { ... }
func Cleanup(s *State) { ... }
```

### Why it's bad

Knowledge about a single concern (e.g., "order pricing") is spread across multiple phases. To understand pricing, you read validate (price format check), process (price calculation), and confirm (price display). Changing pricing means touching three files. The decomposition mirrors the execution timeline, which is the one thing that's obvious without any abstraction.

### What good looks like

Organize by information managed:

**TypeScript**
```typescript
// order-pricing.ts -- owns everything about pricing
export class OrderPricing {
  constructor(private catalog: Catalog, private discounts: DiscountPolicy) {}

  /** Validates, calculates, and formats price for an order */
  compute(items: LineItem[]): PriceSummary { ... }
}

// order-fulfillment.ts -- owns everything about fulfillment
export class OrderFulfillment {
  constructor(private inventory: Inventory, private shipping: ShippingCalculator) {}

  fulfill(order: Order): FulfillmentPlan { ... }
}
```

**Elixir**
```elixir
# Instead of init/validate/process/cleanup phases:
defmodule MyApp.Pricing do
  # All pricing knowledge in one place
  def quote(items, discounts), do: ...
  def apply_tax(quote, jurisdiction), do: ...
  def format(quote, currency), do: ...
end
```

### Severity

- **Critical**: 3+ files/modules whose names or structure reflect execution order, with shared mutable state threaded between them.
- **Warning**: Two-phase split (e.g., `validateX` + `processX`) where both need the same domain knowledge.
- **Info**: Pipeline stages that genuinely operate on independent concerns (e.g., HTTP middleware chain).

---

## 5. Wide Interfaces

Functions with many parameters, modules with many exports, or APIs with many endpoints per resource. Width is a direct measure of complexity imposed on callers.

### What it looks like

**TypeScript**
```typescript
export function createUser(
  name: string,
  email: string,
  password: string,
  role: Role,
  teamId: string,
  avatarUrl: string | null,
  timezone: string,
  locale: string,
  referralCode: string | null,
): Promise<User> { ... }
```

**Rust**
```rust
pub fn render_chart(
    data: &[f64],
    width: u32,
    height: u32,
    title: &str,
    x_label: &str,
    y_label: &str,
    color: Color,
    show_grid: bool,
    show_legend: bool,
    font_size: f32,
) -> Image { ... }
```

**Go -- wide module**
```go
package user

// 15+ exported functions: a grab-bag, not an abstraction
func Create(...) { ... }
func Update(...) { ... }
func Delete(...) { ... }
func Validate(...) { ... }
func Normalize(...) { ... }
func Hash(...) { ... }
func SendWelcome(...) { ... }
func Deactivate(...) { ... }
func Reactivate(...) { ... }
func MergeAccounts(...) { ... }
func ExportData(...) { ... }
func ImportData(...) { ... }
// ...
```

### Why it's bad

Every parameter is a decision the caller must make. Wide interfaces push complexity outward instead of absorbing it. Adding a parameter is easy; removing one is a breaking change. Width accumulates monotonically.

### What good looks like

**TypeScript**
```typescript
interface CreateUserRequest {
  name: string;
  email: string;
  password: string;
  team: string;
  // Optional fields have sensible defaults inside the module
  avatar?: string;
  locale?: string;
}

export function createUser(req: CreateUserRequest): Promise<User> { ... }
```

**Rust**
```rust
pub struct ChartConfig {
    pub title: String,
    pub size: (u32, u32),
    // Everything else has defaults via Default trait
}

impl Default for ChartConfig { ... }

pub fn render_chart(data: &[f64], config: ChartConfig) -> Image { ... }
```

### Severity

- **Critical**: Function with >6 parameters or module with >15 exports that aren't trait/interface-mandated.
- **Warning**: Function with 5-6 parameters or module with 11-15 exports.
- **Info**: Function with exactly 5 parameters where all are semantically distinct and required.

---

## 6. Configuration Explosion

Too many knobs, too few defaults. The module author pushes every decision onto the caller instead of making reasonable choices and letting the caller override the rare case.

### What it looks like

**TypeScript**
```typescript
const client = new HttpClient({
  baseUrl: 'https://api.example.com',
  timeout: 30000,
  retries: 3,
  retryDelay: 1000,
  retryBackoff: 'exponential',
  maxRetryDelay: 30000,
  followRedirects: true,
  maxRedirects: 5,
  validateStatus: (s) => s < 400,
  decompress: true,
  keepAlive: true,
  keepAliveMsecs: 1000,
  maxSockets: 50,
  headers: { 'User-Agent': 'my-app/1.0' },
  auth: { type: 'bearer', token: '...' },
  proxy: null,
  logger: console,
  logLevel: 'warn',
});
```

**Go**
```go
srv := server.New(
    server.WithPort(8080),
    server.WithHost("0.0.0.0"),
    server.WithReadTimeout(30 * time.Second),
    server.WithWriteTimeout(30 * time.Second),
    server.WithIdleTimeout(120 * time.Second),
    server.WithMaxHeaderBytes(1 << 20),
    server.WithTLSConfig(tlsCfg),
    server.WithGracefulShutdown(true),
    server.WithShutdownTimeout(10 * time.Second),
    server.WithLogger(logger),
    server.WithMetrics(metrics),
    server.WithTracing(tracer),
    server.WithHealthCheck("/health"),
    server.WithReadiness("/ready"),
)
```

### Why it's bad

The module has no opinion. The caller must understand every option to use it correctly. Defaults are the module's most important design decision -- they encode domain knowledge. A module with 20 config fields is 20 decisions the author refused to make.

### What good looks like

**TypeScript**
```typescript
// Sensible defaults. Override only what's unusual.
const client = new HttpClient('https://api.example.com');
// Or at most:
const client = new HttpClient('https://api.example.com', {
  auth: bearerToken('...'),
});
```

**Go**
```go
srv := server.New(":8080")  // production-ready defaults
// Override only for non-standard deployments:
srv := server.New(":8080", server.WithTLS(tlsCfg))
```

### Severity

- **Critical**: >10 required configuration fields with no defaults, or constructor that fails unless most fields are specified.
- **Warning**: 5-10 configuration fields where >half could have sensible defaults.
- **Info**: Many options exist but all have defaults; only the base URL or equivalent is required.

---

## 7. Naming Red Flags

Names that describe mechanism rather than abstraction: "Manager", "Helper", "Util", "Data", "Info", "Handler", "Processor", "Wrapper". These names signal that the author couldn't identify what concept the module owns.

### What it looks like

```
UserManager.ts        -- manages what? CRUD? Auth? Lifecycle?
StringHelper.go       -- a bag of unrelated string functions
DataProcessor.rs      -- processes what data, how?
RequestHandler.ex     -- every HTTP module "handles requests"
PaymentUtils.ts       -- the junk drawer
OrderInfo.ts          -- how is Info different from Order?
```

### Why it's bad

Vague names attract vague responsibilities. `UserManager` becomes the dumping ground for anything user-related. Six months later it has 40 methods spanning authentication, profile management, notification preferences, and billing. The name gave no guidance about what belongs and what doesn't.

### What good looks like

Name by the abstraction or invariant the module owns:

```
Authenticator.ts      -- owns the auth flow (not "AuthManager")
WordWrap.go           -- does one thing (not "StringHelper")
InvoiceRenderer.rs    -- renders invoices (not "DataProcessor")
Router.ex             -- routes requests (not "RequestHandler")
PricingPolicy.ts      -- owns pricing rules (not "PaymentUtils")
LineItem.ts           -- a domain concept (not "OrderInfo")
```

### Severity

- **Critical**: Module named "Manager", "Helper", or "Util" with >10 methods spanning multiple concerns.
- **Warning**: Red-flag name on a module that's actually focused (renaming would clarify intent).
- **Info**: Red-flag name in a framework-mandated context (e.g., Express `handler` functions).

---

## Cross-Cutting Severity Escalation

Regardless of individual dimension severity, escalate to critical when:

- **Compound violations**: Same module triggers 3+ dimensions (e.g., shallow + wide + pass-through = the module should not exist).
- **Viral pattern**: The anti-pattern is templated and copied across the codebase (e.g., every entity has a matching Service + Repository + Controller pass-through stack).
- **Public API surface**: The module is part of the project's external API or SDK. Bad interfaces are permanent once shipped.
