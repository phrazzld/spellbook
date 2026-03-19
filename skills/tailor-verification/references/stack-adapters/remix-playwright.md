# Remix + Playwright Adapter

Use this adapter when the repo shows a Remix app plus Playwright and Clerk-like
auth signals. This is the concrete starting point for full-stack web products
with server loaders, nested routes, and browser-driven verification.

## Detection Signals

- `playwright.config.*` exists
- `@playwright/test` is in dependencies
- Remix route files under `app/routes/`
- Clerk packages such as `@clerk/remix`, `@clerk/clerk-react`, or auth wrappers
- optional page objects under `e2e/`, `tests/e2e/`, or `pages/`

## What To Discover

| Area | Questions |
|------|-----------|
| Dev server | What command boots the app? Which port do Playwright tests expect? |
| Auth | Is there a seeded user, storage state file, test token helper, or Clerk bypass? |
| Routing | Which nested routes map to login, dashboard, and the highest-risk flows? |
| Fixtures | Are there seeded orgs, demo accounts, or db reset helpers? |
| Evidence | Does the repo already save traces, screenshots, or videos? |

## High-Value Flow Candidates

Start with flows that commonly fail in this stack:

- login -> redirect -> protected route render
- onboarding or wizard flows spanning multiple Remix routes
- CRUD flows that depend on loader/action round-trips
- invite/accept flows with auth state transitions
- checkout/booking flows that depend on server mutations and confirmation screens

## Remix-Specific Gotchas

- Loader redirects can mask auth failures; verify the final route, not just page load
- Nested route layouts can make a screenshot look correct while the child route failed
- Actions may succeed server-side while stale client UI hides the result; verify post-action state
- Route file names often encode flow boundaries better than nav labels do

## Playwright-Specific Gotchas

- Reuse existing storage state and fixtures before adding new login choreography
- Honor the repo's trace and screenshot config instead of inventing new output paths
- Prefer page objects when they exist; selector drift is a maintenance trap
- If the repo splits projects by browser or auth state, target the existing project first

## Clerk-Specific Gotchas

- Clerk boot can race page assertions; wait for the authenticated shell, not arbitrary timeouts
- Local dev may require seeded publishable keys or test env vars before auth works
- Protected routes can redirect through middleware and still end on a rendered page; confirm user identity in the UI

## Recommended First Pass Outputs

- `verify-login`
- `verify-primary-dashboard`
- one domain-critical multi-step flow such as checkout, booking, or invite acceptance

Each should define:

- route entry point
- auth strategy
- fixture strategy
- success state
- artifact contract
