---
name: supabase
description: |
  Supabase integration patterns across all platforms: Next.js, Electron, Node.js, React Native.
  Client setup, auth (OAuth, email, magic link), RLS policies, Edge Functions, Realtime
  subscriptions, migrations, caching, idempotent mutations, schema design, testing.
  Use when: "supabase", "add a table", "RLS", "auth", "sign in", "session", "edge function",
  "realtime", "subscription", "migration", "upsert", "cache", "submit", "sync to server".
argument-hint: "<focus area> e.g. 'add invoices table', 'RLS policies', 'edge function', 'realtime'"
---

# /supabase

Supabase integration patterns for any platform. Client setup, auth, RLS, Edge Functions, Realtime, migrations, caching, idempotent mutations.

## 1. Client Setup

Single `SupabaseClient` per runtime. Never create multiple instances -- the client holds auth state and manages token refresh.

### Browser / Next.js (client component)

```ts
import { createBrowserSupabaseClient } from '@supabase/ssr';

// Create once, reuse. Framework helpers (createBrowserClient) handle cookie storage.
const supabase = createBrowserSupabaseClient();
```

### Next.js (server component / route handler)

```ts
import { createServerSupabaseClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

// Per-request client -- reads cookies for auth context
export async function createClient() {
  const cookieStore = await cookies();
  return createServerSupabaseClient({
    cookies: {
      getAll: () => cookieStore.getAll(),
      setAll: (cookies) => cookies.forEach(({ name, value, options }) =>
        cookieStore.set(name, value, options)),
    },
  });
}
```

### Node.js / Electron (no browser APIs)

```ts
let client: SupabaseClient | null = null;

export function getSupabaseClient(): SupabaseClient {
  if (!client) {
    client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: {
        storage: fileStorage,         // see below
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: false,    // no URL bar
      },
    });
  }
  return client;
}
```

**File-based storage adapter** (required when `localStorage` unavailable):

```ts
const fileStorage = {
  getItem: (key: string): string | null => { /* read JSON file */ },
  setItem: (key: string, value: string): void => { /* atomic write: .tmp + rename */ },
  removeItem: (key: string): void => { /* delete key, rewrite */ },
};
```

Invariant: always atomic write (write `.tmp`, then `fs.renameSync`) to survive process crashes.

### React Native

Use `@supabase/supabase-js` with `@react-native-async-storage/async-storage`:

```ts
const supabase = createClient(URL, ANON_KEY, {
  auth: { storage: AsyncStorage, autoRefreshToken: true, persistSession: true },
});
```

### Credentials

Anon key is public -- RLS gates access. Use `process.env` or platform-specific config. **Never embed the service role key in client-side code** (browser, Electron, mobile).

## 2. Auth

### OAuth (any provider: Google, GitHub, Azure AD, Apple, etc.)

**Browser / Next.js:**

```ts
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: 'google',           // or 'github', 'azure', 'apple', etc.
  options: { redirectTo: `${origin}/auth/callback` },
});
// Browser redirects automatically. Handle callback in /auth/callback route.
```

**Callback route (Next.js App Router):**

```ts
// app/auth/callback/route.ts
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const code = searchParams.get('code');
  if (code) {
    const supabase = await createClient();
    await supabase.auth.exchangeCodeForSession(code);
  }
  return NextResponse.redirect(new URL('/', request.url));
}
```

**Electron / desktop (BrowserWindow interception):**

1. Call `supabase.auth.signInWithOAuth({ skipBrowserRedirect: true })` to get the auth URL
2. Open a `BrowserWindow` pointed at that URL
3. Intercept the redirect via `will-redirect` / `will-navigate`
4. Extract code from query params (PKCE flow) or tokens from URL fragment (implicit flow)
5. Call `exchangeCodeForSession(code)` or `setSession(tokens)`
6. Close the window, call `startAutoRefresh()`

Key details:
- Filter out intermediate redirects (e.g., microsoftonline.com, accounts.google.com) -- only handle the final callback
- Use a `settled` guard to prevent double-handling
- Capture provider tokens **before** `setSession` if needed -- they're in the URL fragment
- Always `startAutoRefresh()` after successful auth

### Email / password

```ts
// Sign up
await supabase.auth.signUp({ email, password });

// Sign in
await supabase.auth.signInWithPassword({ email, password });
```

### Magic link

```ts
await supabase.auth.signInWithOtp({
  email,
  options: { emailRedirectTo: `${origin}/auth/callback` },
});
```

### Auth state management

```ts
supabase.auth.onAuthStateChange((event, session) => {
  // event: SIGNED_IN, SIGNED_OUT, TOKEN_REFRESHED, USER_UPDATED, PASSWORD_RECOVERY
  if (event === 'SIGNED_OUT') clearAllCaches();
  if (event === 'TOKEN_REFRESHED') refreshCachedData();
});
```

**Sign-out** must clear: Supabase session, all application caches, any stored provider tokens.

### Pre-flight check

Every mutation must verify the session exists:

```ts
const { data: { session } } = await supabase.auth.getSession();
if (!session?.user) return { success: false, error: 'Not authenticated.' };
```

## 3. Data Access Patterns

### Typed queries

```ts
const { data, error } = await supabase
  .from('clients')
  .select('id, name, active')
  .eq('active', true)
  .order('name');
```

Always check `error` before using `data`. Supabase returns `{ data: null, error }` on failure -- never assume data exists.

### Generated types

```bash
npx supabase gen types typescript --project-id <ref> > src/types/database.ts
```

Then pass to `createClient<Database>(...)` for full type safety on `.from()`, `.select()`, `.insert()`, etc.

### Idempotent re-submission (delete + re-insert)

For data that represents a batch that gets re-submitted (daily work logs, form responses, sync payloads):

```ts
// 1. Delete existing entries for this scope
await supabase.from('entries').delete()
  .eq('user_id', userId).eq('date', date);

// 2. Insert fresh entries, return generated IDs
const { data: inserted } = await supabase.from('entries')
  .insert(rows).select('id, started_at');

// 3. Insert child records linked by returned IDs
// 4. Upsert summary record
await supabase.from('daily_summaries').upsert(
  { user_id: userId, date, total_minutes, status: 'submitted' },
  { onConflict: 'user_id,date' }
);
```

Why delete+re-insert instead of upsert for entries: entries may change in count, shape, and content between submissions. Upsert requires a stable natural key per entry -- delete+re-insert is simpler and idempotent.

### Linking parent-child after insert

Use `.select('id, <match_field>')` on the parent insert to get generated IDs back, then build a lookup map for child inserts. Match on stable fields (e.g., epoch milliseconds) to avoid ISO format mismatches (`Z` vs `+00:00`).

### `.maybeSingle()` for optional lookups

When querying something that may not exist, use `.maybeSingle()` instead of `.single()` to avoid throwing on zero rows.

### Pagination

```ts
const PAGE_SIZE = 50;
const { data, count } = await supabase
  .from('entries')
  .select('*', { count: 'exact' })
  .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)
  .order('created_at', { ascending: false });
```

For cursor-based pagination (better for large datasets): order by a unique column, filter with `.gt()` / `.lt()` on the cursor value.

## 4. Caching -- Sync Accessors for Hot Paths

When your app has a fast update loop (game loop, 1-second tick, animation frame, frequent re-renders), Supabase calls must not block the hot path.

Pattern: module-level cache + async refresh + sync getter.

```ts
let cachedClients: ClientRow[] | null = null;

// Async -- called on auth events, after mutations, at startup
export async function refreshClients(): Promise<void> {
  const { data, error } = await supabase.from('clients').select('*');
  if (!error) cachedClients = data;
}

// Sync -- safe to call from hot path
export function getCachedClients(): ClientRow[] | null {
  return cachedClients;
}

export function clearClientCache(): void {
  cachedClients = null;
}
```

**When to refresh**: auth events (sign-in, token refresh), after mutations, app startup/foreground. Never in the hot path.

**Per-key caches**: use `Map<string, T>` when caching by a key (date, ID, etc.) so fetching one key doesn't stomp another's cached value.

**Invariant**: any function called from a hot path must be **fully synchronous**. All Supabase data it reads must come from sync cache accessors.

## 5. RLS (Row Level Security)

### Principles

- **Every table with user data gets RLS enabled.** No exceptions.
- Anon key + RLS = users can only access their own rows.
- Service role key bypasses RLS -- use only in Edge Functions, cron jobs, server-side admin. Never ship in client code.

### Common policy patterns

```sql
-- 1. Users own their data (most common)
CREATE POLICY "users_own_data" ON entries
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 2. Read-only reference data (anyone authenticated)
CREATE POLICY "authenticated_read" ON products
  FOR SELECT TO authenticated USING (true);

-- 3. Public read, owner write
CREATE POLICY "public_read" ON posts
  FOR SELECT USING (true);
CREATE POLICY "owner_write" ON posts
  FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "owner_update" ON posts
  FOR UPDATE USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);
CREATE POLICY "owner_delete" ON posts
  FOR DELETE USING (auth.uid() = author_id);

-- 4. Team/org-based access (via join table)
CREATE POLICY "team_members" ON projects
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM team_members tm
      WHERE tm.project_id = projects.id
      AND tm.user_id = auth.uid()
    )
  );

-- 5. Role-based access
CREATE POLICY "admin_only" ON admin_settings
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = auth.uid()
      AND ur.role = 'admin'
    )
  );

-- 6. Row-level sharing (explicit grants)
CREATE POLICY "shared_access" ON documents
  FOR SELECT USING (
    auth.uid() = owner_id
    OR EXISTS (
      SELECT 1 FROM document_shares ds
      WHERE ds.document_id = documents.id
      AND ds.shared_with = auth.uid()
    )
  );
```

### RLS gotchas

- `FOR ALL` combines `USING` (read filter) and `WITH CHECK` (write validation). Specify both when they differ.
- Policies are **permissive by default** -- any matching policy grants access. Use `RESTRICTIVE` policies to add mandatory constraints (e.g., `account_active = true`).
- `USING` without `WITH CHECK` means the write check inherits from `USING`. Fine for simple ownership, dangerous for complex predicates.
- Foreign key cascades (`ON DELETE CASCADE`) work regardless of RLS -- a user deleting their parent row cascades to children even if the children belong to a different policy scope. Design cascades carefully.
- `auth.uid()` returns `NULL` for unauthenticated requests. Policies using `auth.uid() = user_id` correctly deny anon access since `NULL = anything` is false.

## 6. Edge Functions

Supabase Edge Functions are Deno-based serverless functions deployed to Supabase infrastructure.

### When to use

- Webhooks from external services (Stripe, GitHub, etc.)
- Server-side logic that needs service role access
- Scheduled tasks / cron jobs
- Custom auth hooks or validation
- Aggregations or transformations too complex for RLS + PostgREST

### Structure

```
supabase/
  functions/
    my-function/
      index.ts    # Entry point
  config.toml     # Function config (optional)
```

### Pattern

```ts
// supabase/functions/process-webhook/index.ts
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req: Request) => {
  // Verify webhook signature if applicable
  const payload = await req.json();

  // Service role client -- bypasses RLS
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // Or: user-scoped client from the Authorization header
  const authHeader = req.headers.get('Authorization');
  const supabaseUser = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader! } } },
  );

  const { data, error } = await supabase.from('events').insert(payload);

  return new Response(JSON.stringify({ success: !error }), {
    headers: { 'Content-Type': 'application/json' },
    status: error ? 500 : 200,
  });
});
```

### Deployment

```bash
supabase functions deploy my-function
supabase secrets set MY_SECRET=value    # Set env vars
```

### Edge Function gotchas

- Max execution time: 150s (wall clock). Design for fast completion.
- Cold starts: first invocation is slower. Keep imports minimal.
- `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are auto-injected -- don't set manually.
- CORS: must return appropriate headers. Add `Access-Control-Allow-Origin` for browser callers.
- Secrets set via `supabase secrets set` are available as `Deno.env.get()`.
- Local dev: `supabase functions serve` with `--env-file .env.local`.
- Deno runtime: use `https://esm.sh/` for npm packages, Deno std lib for utilities.

## 7. Realtime Subscriptions

### Channel-based subscriptions (Postgres Changes)

```ts
const channel = supabase
  .channel('entries-changes')
  .on('postgres_changes',
    { event: '*', schema: 'public', table: 'entries', filter: `user_id=eq.${userId}` },
    (payload) => {
      // payload.eventType: 'INSERT' | 'UPDATE' | 'DELETE'
      // payload.new: the new row (INSERT/UPDATE)
      // payload.old: the old row (UPDATE/DELETE) -- requires REPLICA IDENTITY FULL
      handleChange(payload);
    }
  )
  .subscribe();
```

### Presence (who's online)

```ts
const channel = supabase.channel('room-1');

channel.on('presence', { event: 'sync' }, () => {
  const state = channel.presenceState();
  // state: { [key: string]: { user_id, online_at, ... }[] }
});

channel.subscribe(async (status) => {
  if (status === 'SUBSCRIBED') {
    await channel.track({ user_id: currentUser.id, online_at: new Date().toISOString() });
  }
});
```

### Broadcast (ephemeral messages, no persistence)

```ts
const channel = supabase.channel('cursor-positions');

// Send
channel.send({ type: 'broadcast', event: 'cursor', payload: { x: 100, y: 200 } });

// Receive
channel.on('broadcast', { event: 'cursor' }, ({ payload }) => {
  updateCursor(payload.x, payload.y);
});
```

### Cleanup

Always unsubscribe when done:

```ts
supabase.removeChannel(channel);
// or
channel.unsubscribe();
```

In React, clean up in `useEffect` return. In long-lived processes, clean up on shutdown.

### Realtime gotchas

- **RLS applies** to Postgres Changes -- users only receive events for rows they can `SELECT`.
- **REPLICA IDENTITY**: by default, `DELETE` events only include the primary key in `old`. Set `ALTER TABLE entries REPLICA IDENTITY FULL` to get the full old row.
- **Filters**: only simple equality filters supported (`column=eq.value`). Complex filtering must be done client-side.
- **Reconnection**: the client auto-reconnects, but you may miss events during disconnection. Design for eventual consistency (periodic refresh as fallback).
- **Rate limits**: Realtime has connection and message limits per project. Don't subscribe to high-throughput tables without filtering.
- **Enable in dashboard**: Realtime must be enabled per-table in the Supabase dashboard (Database > Replication).

## 8. Migrations

### Local development

```bash
supabase init                        # Initialize project (creates supabase/ directory)
supabase start                       # Start local Supabase (Docker)
supabase db diff -f create_entries   # Generate migration from schema diff
supabase migration new add_indexes   # Create empty migration file
```

### Migration file

```sql
-- supabase/migrations/20240101000000_create_entries.sql

CREATE TABLE entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  label TEXT,
  duration_minutes INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX entries_user_date_idx ON entries(user_id, date, label);

ALTER TABLE entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_entries" ON entries
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

### Principles

- **Forward-only.** No down migrations. If you need to undo, write a new migration.
- **Backward compatible.** Add columns as nullable or with defaults. Drop columns in a later migration after code stops referencing them.
- **RLS in the same migration.** Every new table gets `ENABLE ROW LEVEL SECURITY` + policies in the same migration file. Never leave a table unprotected even briefly.
- **Idempotent when possible.** Use `IF NOT EXISTS` / `IF EXISTS` for indexes and constraints.
- **Small and focused.** One logical change per migration. Don't combine unrelated schema changes.

### Deployment

```bash
supabase db push                      # Apply pending migrations to remote
supabase db reset                     # Reset local DB and replay all migrations
supabase migration list               # Show migration status
```

### Type regeneration after migration

```bash
npx supabase gen types typescript --project-id <ref> > src/types/database.ts
```

Always regenerate types after schema changes. Commit the generated file.

## 9. Schema Design

### Conventions

- UUIDs for primary keys (`gen_random_uuid()`)
- `user_id UUID REFERENCES auth.users(id)` on every user-scoped table
- `TIMESTAMPTZ` for all timestamps (Supabase default)
- `UNIQUE` constraints on natural keys to enable upsert
- `ON DELETE CASCADE` on child FKs for clean parent deletion
- `created_at TIMESTAMPTZ DEFAULT now()` on every table

### Date columns

When storing a "calendar date" (not a point in time), use `DATE` type. Derive from **local time**, not UTC.

**Never** `new Date().toISOString().slice(0,10)` -- this gives the UTC date, which drifts from the user's local date after timezone offset. Use a local date formatter or `Intl.DateTimeFormat`.

### Table pattern

```
parent_table (id PK, user_id FK, date, ...)
  child_table (id PK, parent_id FK CASCADE, ...)
  summary_table (user_id, date, UNIQUE(user_id, date), ...)
```

## 10. Error Handling

### Error shape

Supabase errors: `{ message, details, hint, code }`. Log all four fields.

```ts
if (error) {
  console.error('Supabase error:', { message: error.message, details: error.details, hint: error.hint, code: error.code });
}
```

### Offline / network failure

The app should function without Supabase when possible. Auth defaults to `{ isAuthenticated: false }`, caches default to `null` (triggering local fallback), mutations return clear error messages.

```ts
try {
  await initSupabase();
} catch (err) {
  logger.warn('Supabase init failed (offline mode):', err);
}
```

### Partial failure

When a multi-step mutation partially succeeds (parent saved, children failed), return success with a warning -- don't roll back the successful part. The user can retry to complete the operation. Log what succeeded and what failed.

## 11. Testing

### Mocking the client

```ts
const mockSupabase = {
  from: vi.fn().mockReturnValue({
    select: vi.fn().mockReturnThis(),
    insert: vi.fn().mockReturnThis(),
    delete: vi.fn().mockReturnThis(),
    upsert: vi.fn().mockReturnThis(),
    eq: vi.fn().mockReturnThis(),
    order: vi.fn().mockResolvedValue({ data: [...], error: null }),
    maybeSingle: vi.fn().mockResolvedValue({ data: null, error: null }),
  }),
  auth: {
    getSession: vi.fn().mockResolvedValue({ data: { session: mockSession } }),
    signInWithOAuth: vi.fn(),
    setSession: vi.fn(),
    signOut: vi.fn(),
    onAuthStateChange: vi.fn().mockReturnValue({
      data: { subscription: { unsubscribe: vi.fn() } },
    }),
    startAutoRefresh: vi.fn(),
  },
};

vi.mock('./supabase', () => ({ getSupabaseClient: () => mockSupabase }));
```

### Local Supabase for integration tests

```bash
supabase start                  # Local instance (Docker)
supabase db reset               # Clean slate from migrations
```

Use a service role client for setup/teardown. Test with an anon client to verify RLS.

### What to test

- **Submission idempotency**: submit, re-submit, verify no duplicates
- **Cache coherence**: refresh after auth change, verify sync accessor returns fresh data
- **Offline fallback**: mock network failure, verify app still functions
- **RLS enforcement**: attempt cross-user access with a different auth context, verify denial
- **Date handling**: test around midnight UTC boundary -- local date must be correct
- **Realtime**: subscribe, mutate, verify callback fires (local Supabase supports Realtime)
- **Edge Functions**: `supabase functions serve` + HTTP requests in tests

## Anti-Patterns

| Anti-pattern | Why it's dangerous | Do instead |
|---|---|---|
| Multiple `createClient` calls | Duplicate auth state, race conditions on token refresh | Singleton per runtime context |
| `await` in hot path | Blocks render loop, causes jank or dropped frames | Sync cache accessors, async refresh on events |
| `toISOString().slice(0,10)` for dates | Returns UTC date, wrong after timezone offset | Local date formatter (`Intl.DateTimeFormat`, `toLocaleDateString`) |
| Swallowing errors silently | Hides auth expiry, RLS denials, network issues | Log `message`, `details`, `hint`, `code` |
| Service role key in client bundle | Bypasses all RLS, full DB access if leaked | Anon key in clients, service role only in Edge Functions / server |
| Stomping per-key caches | Fetching key A overwrites key B's cached value | `Map<string, T>` keyed by identifier |
| Skipping pre-flight auth check | Mutations fail with cryptic RLS errors | Verify `session?.user` before every mutation |
| Non-atomic file writes (Node.js) | Session file corrupted on crash | Write `.tmp` + `fs.renameSync` |
| Tables without RLS | Any authenticated user can read/write all rows | Enable RLS + add policies in the same migration |
| Down migrations | Fragile, rarely tested, false safety net | Forward-only migrations |
| Subscribing to unfiltered Realtime | Excessive events, hits rate limits | Always filter by user/scope |
| `single()` for optional lookups | Throws on zero rows | `.maybeSingle()` |
