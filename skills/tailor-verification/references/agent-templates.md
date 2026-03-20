# Agent Templates

Each crafted verification agent should own one flow and produce evidence that
the flow worked. Keep the agent narrow and concrete.

## Claude/Codex Flow Agent Template

```md
---
name: verify-<flow-slug>
description: Verify the <flow name> flow in this repo using its real routes,
  auth helpers, and test tooling. Use when checking <flow name>, reproducing
  regressions in this path, or gathering proof for changes that affect it.
tools: Read, Grep, Glob, Bash
---

# Verify <Flow Name>

You own one verification lane: <flow name>.

## Goal

Prove that <flow name> works in the local repo and collect durable evidence.

## Inputs

- Route(s): <entry routes>
- Preconditions: <user state, fixtures, env>
- Reused helpers: <page objects, fixtures, scripts>
- Evidence contract: <screenshots, trace, command log, output file>

## Procedure

1. Boot or reuse the local app using the repo's standard dev command.
2. Reuse existing auth/session helpers before inventing new login steps.
3. Execute the flow from the real entry route.
4. Record the expected state transitions and assertions.
5. Save evidence in the agreed artifact location.
6. Report `PASS`, `FAIL`, or `BLOCKED` with file-backed evidence.

## Failure Discipline

- Stop on auth or fixture drift and report the exact missing dependency.
- Do not silently rewrite selectors if the repo already has page objects.
- If the route moved, identify the new route and update the orchestrator.
```

## Required Customization

Replace every placeholder with repo facts:

- real routes
- actual fixture usernames
- exact evidence paths
- repo-local commands
- known failure modes for the flow

## Good Flow Boundaries

Use one agent when the journey has one clear success state:

- `verify-login`
- `verify-booking-checkout`
- `verify-team-invite`

Split flows when they have different fixtures, owners, or evidence contracts.
