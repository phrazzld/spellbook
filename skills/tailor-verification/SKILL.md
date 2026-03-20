---
name: tailor-verification
description: |
  Craft repo-specific verification agents and an orchestrator skill from the
  target repo's actual stack. Discover test runners, auth, routes, page
  objects, dev server, and browser/MCP tooling, then map them into
  project-local verification primitives. Use when bootstrapping product
  verification for a repo, calibrating a new codebase, adding one high-value
  flow, or auditing verification gaps. Keywords: product verification,
  verify-app, verification agents, Playwright, Clerk, Remix, E2E, page
  objects, flow audit.
argument-hint: "[init|add|audit] [flow]"
---

# /tailor-verification

Discover how a repo can be verified, then codify that knowledge into
project-local verification primitives instead of rediscovering it every run.

## Composition

This skill orchestrates; it does not reimplement adjacent primitives.

| Dependency | Used For |
|------------|----------|
| `/research` | Phase 1 research on stack docs, auth patterns, and known verification gotchas |
| `/craft-primitive` | Phase 4 creation of project-local flow agents and the `verify-app` router |
| Browser tooling (`agent-browser`, `browser-use`, repo-native E2E) | Validating that crafted browser-based flows can actually run |

Do not duplicate `/research` retrieval logic or `/craft-primitive` packaging
logic. Compose with them directly.

## Outputs

- One verification agent per flow, usually `verify-<flow>.md`
- One orchestrator skill, usually `verify-app/`
- Evidence expectations for each flow so future runs produce proof, not prose

## Routing

| Intent | Load |
|--------|------|
| `/tailor-verification` | `references/calibration.md` |
| `/tailor-verification init` | `references/calibration.md` |
| `/tailor-verification add <flow>` | `references/agent-templates.md` and `references/skill-templates.md` |
| `/tailor-verification audit` | `references/calibration.md` and `references/evidence-patterns.md` |
| Need output templates | `references/agent-templates.md`, `references/skill-templates.md` |
| Need evidence contract | `references/evidence-patterns.md` |
| Remix + Playwright + Clerk repo | `references/stack-adapters/remix-playwright.md` |
| Unknown stack or weak signals | `references/stack-adapters/generic.md` |

## Core Flow

1. Research the detected stack and verification patterns. Compose with `/research`.
2. Discover the repo's real verification infrastructure: runner, auth, routes,
   fixtures, page objects, dev command, and browser tooling.
3. Identify the highest-value flows and rank them `P0` to `P3`.
4. Craft project-local verification agents and one orchestrator skill with
   `/craft-primitive`. Do not ship the generated outputs back into spellbook.

## Detection Order

1. Existing E2E harness: Playwright, Cypress, or repo-local browser tooling
2. Auth shape: Clerk, Auth0, NextAuth, custom sessions, test users
3. Route and page structure: app routes, page objects, wizard steps, dashboards
4. Evidence surface: screenshots, traces, command logs, persisted artifacts

## Output Rules

- Default to project-local harness directories, not spellbook-managed paths.
- Mirror the repo's active harness. If it supports multiple harnesses, keep the
  verification contract aligned across them.
- Reuse existing helpers and fixtures before inventing new abstractions.
- Keep agents deeply specific to one flow. The orchestrator routes; it does not
  absorb all flow knowledge itself.

## Anti-Patterns

- Writing a generic `verify-app` skill with no repo discovery
- Emitting spellbook-managed `.spellbook` markers for repo-local outputs
- Treating "there is a Playwright config" as enough to skip route/auth discovery
- Capturing screenshots without recording the behavior they prove
- Stuffing all flows into one giant agent instead of one agent per flow
