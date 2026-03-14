# Backlog Doctrine

## What the backlog is for

Treat the backlog as the current plan, not as storage for every idea. A good backlog is ordered,
transparent, and actively maintained. It should make the next decisions obvious.

## Core rules

- Keep the backlog small enough to read end-to-end.
- Reduce before adding.
- Prefer one canonical issue per outcome.
- Split discovery from delivery.
- Order work by user value, risk reduction, learning, and enablement.
- Keep active work narrow. High WIP destroys prioritization.

## Healthy item shapes

### Epic

Use for a multi-issue initiative with a clear product outcome. The epic should explain why the
theme matters, what success looks like, and which child issues carry execution.

### Feature

Use for a user-visible capability or operator-facing behavior change. The feature should be
valuable on its own and not just a mechanical subtask.

### Bug

Use when the current behavior is wrong. State the failure, repro, expected behavior, and user or
business impact.

### Task / Refactor / Research

Use only when the work is not a feature or bug. Keep these issue types outcome-linked:
- `task`: enabling work with a clear downstream payoff
- `refactor`: complexity reduction with preserved behavior
- `research`: a decision-seeking investigation with a deliverable

## Ordering guidance

Move items up when they:
- unblock or de-risk other work
- fix trust, correctness, or safety failures
- improve a critical user path
- create leverage across multiple future issues

Move items down when they:
- are polish without evidence
- duplicate a broader surviving issue
- depend on undefined architecture
- represent “maybe someday” ideas with no current owner

## Cadence

- Triage new intake quickly into keep, merge, defer, or close.
- Re-read the active backlog regularly enough to remove stale assumptions.
- Run pruning passes, not just addition passes.
- Update the canonical issue body when the plan changes. Do not bury the truth in comments.

## Smells

- 5 tickets that all mean the same thing
- “Polish” issues that should be sub-points in a deeper issue
- implementation tasks with no user or system outcome
- giant omnibus tickets with unclear done criteria
- issues that require tribal knowledge to start
- “investigate” tickets with no decision target

## Definition of ready

Before an issue is execution-ready, verify:
- the problem is specific
- the outcome is explicit
- dependencies are visible
- scope boundaries are present
- verification is executable
- the issue can be completed in one coherent pass or should be split

## AI-agent adaptation

See `agent-issue-writing.md` for agent-specific issue shaping.

## Sources

- https://scrumguides.org/scrum-guide
- https://www.atlassian.com/agile/project-management/backlog-refinement-meeting
- https://www.atlassian.com/agile/project-management/product-backlog
