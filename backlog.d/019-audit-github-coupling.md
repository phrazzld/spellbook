# Audit remaining GitHub coupling

Priority: high
Status: in-progress
Estimate: S

## Goal

Identify every remaining dependency on GitHub (API, Actions, PR state, releases,
`gh` CLI calls) across the entire Spellbook codebase and downstream skills.
Produce a concrete removal plan for each dependency.

## Why

Thinktank research revealed disagreement about how much GitHub coupling remains.
The `ci/` module may still reference `GITHUB_ACTIONS` and `GITHUB_STEP_SUMMARY`
env vars. Skills like `/settle` and `/demo` may still call `gh` for PR checks
and evidence upload. Until we know the full surface, we can't plan the removal.

## Audit Scope

- `ci/` Dagger module — env var assumptions, GitHub API calls
- All skills — `gh` CLI usage, GitHub URL construction, PR references
- `bootstrap.sh` — GitHub release download path
- Hooks — any GitHub-specific logic
- CLAUDE.md / AGENTS.md — GitHub-assuming instructions

## Oracle

- [ ] Grep report: every file referencing `github`, `gh `, `GITHUB_`, `pulls/`, `issues/`
- [ ] Each reference categorized: required (keep) vs removable (plan)
- [ ] Removal plan filed as backlog items or amendments to existing items

## Non-Goals

- Actually removing anything — this is audit only
- Removing GitHub as a git remote (keep as mirror)
