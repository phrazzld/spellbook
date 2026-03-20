# Skill Templates

The generated orchestrator should stay small. It routes to flow agents and
shared rules; it does not restate every selector or step.

## `verify-app` Skill Template

```md
---
name: verify-app
description: |
  Route product verification work in this repo to the right flow-specific
  verification agent. Use when verifying the app after changes, checking a
  named flow, or auditing which critical paths still lack coverage.
argument-hint: "[flow-name|audit]"
---

# /verify-app

Route verification work to the correct repo-local flow agent.

## Routing

| Intent | Route |
|--------|-------|
| `/verify-app` | Highest-priority default flow |
| `/verify-app audit` | Audit verification coverage gaps |
| `/verify-app <flow>` | Matching `verify-<flow>` agent. Flow keys must be lowercase hyphenated slugs. |

## Default Flow

If no flow is named, run the highest-priority `P0` flow that exists locally.

## Shared Rules

- Reuse repo-local fixtures and auth helpers
- Produce evidence, not just a narrative
- Fail loudly on environment drift
- Update this router when flows are added, renamed, or removed

## Known Flows

- Flow keys must stay lowercase hyphenated slugs and match the suffix in `verify-<flow>`.
- `login` -> `verify-login`
- `checkout` -> `verify-checkout`
- `team-invite` -> `verify-team-invite`
```

## Orchestrator Responsibilities

- route to the correct flow agent
- document the default flow
- state shared evidence and environment rules
- make gaps visible in `audit`

## Orchestrator Non-Goals

- encoding full step-by-step flow logic
- duplicating selectors from flow agents
- hiding missing verification coverage
