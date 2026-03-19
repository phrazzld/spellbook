# Calibration

`tailor-verification` is a four-phase runtime protocol. The skill does not
perform verification directly. It discovers how verification should work in the
current repo, then codifies that into project-local primitives.

## Phase 1: Research

Compose with `/research` before locking the output shape.

- Read the repo's `AGENTS.md`, `README`, `project.md`, and verification docs
- Research stack-specific verification practice when the stack is not obvious
- Prefer concrete repo patterns over generic testing advice

Questions to answer:
- Which user flows actually matter to this product?
- What makes verification in this stack flaky or expensive?
- What evidence would convince a maintainer that a flow really works?

## Phase 2: Discover

Scan the repo for the verification surface area.

| Signal | Look for | Why it matters |
|--------|----------|----------------|
| Test runner | `playwright.config.*`, `cypress.config.*`, `vitest.config.*` | Tells you how live verification can execute |
| Auth | `@clerk/`, `auth0`, `next-auth`, session helpers, test users | Determines login/setup strategy |
| Routes | `app/routes`, `src/app`, router config, page modules | Maps features to candidate flows |
| Page objects | `*.page.ts`, `pages/`, helpers under `e2e/` | Reuse existing abstractions |
| Specs | `*.spec.*`, `*.test.*`, `e2e/` | Shows current coverage and gaps |
| Dev server | `package.json` scripts, port config, env docs | Tells agents how to boot the app |
| Browser tools | MCP/browser tools, local screenshots, traces | Sets the evidence contract |

Capture concrete findings, not guesses:

```md
Runner: Playwright (`playwright.config.ts`, projects: chromium, setup)
Auth: Clerk (`@clerk/remix`, test session helper in `tests/config/users.ts`)
Routes: Remix nested routes under `app/routes/_app.*`
Gap: no durable verification agent for booking checkout
```

## Phase 3: Identify

Map discovered infrastructure to flows and rank them.

Use this rubric:

- `P0`: revenue, auth, checkout, data-loss, core dashboard entry
- `P1`: major user workflows with multiple steps or risky state transitions
- `P2`: secondary flows that still touch real integrations
- `P3`: low-risk polish or read-only views

For each candidate flow, record:

- Flow name and slug
- Why it matters
- Entry point(s)
- Preconditions / fixtures
- Existing helpers to reuse
- Evidence required to call it verified

## Phase 4: Craft

Compose with `/craft-primitive`.

Create:

- `verify-<flow>.md` for each approved flow
- `verify-app/` orchestrator skill that routes to those agents

Crafting rules:

- One flow agent per user journey
- One orchestrator for routing and shared guardrails
- Output lives in project-local harness directories
- Do not add `.spellbook` markers to generated outputs

## Recommended Session Output

At the end of `init`, report:

1. Detected stack and verification surface
2. Ranked flow candidates
3. Flows chosen for first pass
4. Files/paths where the generated primitives were written
5. Evidence expectations for each crafted flow

## Audit Mode

`/tailor-verification audit` compares existing verification primitives against
the current repo shape.

Flag:

- flows with no agent
- agents with stale routes/selectors
- evidence contracts that no longer match the tooling
- duplicated logic that belongs in shared fixtures instead
