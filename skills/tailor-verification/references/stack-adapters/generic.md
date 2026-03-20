# Generic Adapter

Use this when the repo does not strongly match a known stack adapter yet.
The goal is not perfect coverage. The goal is to discover enough structure to
craft the first credible verification primitives without hallucinating details.

## Discovery Pass

1. Find the app entry points and dev command
2. Identify any automated test or browser tooling
3. Detect auth/session requirements
4. List the highest-risk user flows from routes, docs, and existing tests
5. Define the smallest evidence contract that proves each chosen flow

## Safe Defaults

- Prefer existing repo scripts over ad hoc shell commands
- Prefer read-only or low-risk flows first if auth/setup is unclear
- Keep output project-local and easy to delete
- Escalate uncertainty instead of faking stack-specific steps

## Candidate Signals

| Signal | Examples |
|--------|----------|
| Browser automation | Playwright, Cypress, Selenium, Puppeteer |
| Route structure | Next.js app router, Remix routes, Rails routes, Phoenix LiveView, custom SPA routers |
| Auth | Clerk, Auth0, NextAuth, Supabase Auth, custom sessions |
| Fixtures | seed scripts, factory helpers, demo accounts, snapshot data |
| Evidence | screenshots, trace zips, logs, API snapshots |

## First Crafted Outputs

If discovery is weak, still produce:

- one `P0` flow agent with the clearest route and success state
- one `verify-app` router with an explicit `audit` mode
- a gap list documenting what still needs repo-specific calibration

## When To Stop And Escalate

Stop instead of guessing when:

- the app cannot be booted from documented repo commands
- auth depends on missing secrets or undocumented external services
- multiple competing test harnesses exist and you cannot tell which is canonical
- no credible success signal can be defined for the chosen flow
