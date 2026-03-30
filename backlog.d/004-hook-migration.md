# Migrate Claude hooks to harness-agnostic enforcement

Priority: high
Status: ready
Estimate: L

## Goal

Eliminate dependence on Claude Code hooks for quality enforcement. Migrate each hook to the highest-leverage harness-agnostic layer: Dagger gate, git hook, skill instruction, or drop.

## Non-Goals
- Don't remove all hooks in one PR — migrate incrementally
- Don't lose enforcement value — every migrated hook must have an equivalent
- Don't build custom linting infrastructure — use Dagger gates

## Why

Claude hooks are Claude-Code-specific, fire per tool use (expensive at agent velocity), and don't work in Codex, Pi, or human workflows. The codification hierarchy says: Dagger gate > git hook > skill instruction > Claude hook.

## Migration Table

| Hook | Current | Target | Notes |
|------|---------|--------|-------|
| block-master-push.py | PreToolUse/Bash | **git pre-push hook** | Branch protection at push time |
| check-todo-quality.py | PreToolUse/Edit | **skill instruction** | Torvalds Test guidance in CLAUDE.md |
| codex-post-feedback.py | PostToolUse/Edit | **drop** | Informational noise, no enforcement |
| codex-session-init.py | SessionStart | **drop** | Session state management, not enforcement |
| destructive-command-guard.py | PreToolUse/Bash | **keep temporarily** | Tied to Claude Code permission model |
| disk-space-guard.py | PreToolUse/Bash | **Dagger gate** | Resource check before CI run |
| env-var-newline-guard.py | PreToolUse/Bash | **Dagger gate** | Scan scripts for echo-pipe-to-env patterns |
| exa-research-reminder.py | PreToolUse/WebSearch | **skill instruction** | Research tool guidance in /research skill |
| exclusion-guard.py | PreToolUse/Edit | **Dagger gate** | Scan for @ts-ignore, .skip, coverage exclusions |
| fix-what-you-touch.py | PreToolUse/Bash | **skill instruction** | Principle in AGENTS.md (already there) |
| github-cli-guard.py | PreToolUse/Bash | **keep temporarily** | Workaround for GH API deprecation |
| permission-auto-approve.py | PreToolUse/any | **keep temporarily** | Core to Claude Code permission model |
| portable-code-guard.py | PreToolUse/Edit+Bash | **Dagger gate** | Scan for hardcoded paths, workspace node_modules |
| session-health-check.py | SessionStart | **drop** | Informational only |
| shaping-ripple.sh | PostToolUse/Edit | **skill instruction** | Shape doc process in /shape skill |
| stop-quality-gate.py | (unwired) | **Dagger gate** | Already covered by dagger call check |
| time-context.py | SessionStart | **keep temporarily** | Harness-specific context injection |

## Oracle
- [ ] All "Dagger gate" hooks have equivalent checks in `ci/src/spellbook_ci/main.py`
- [ ] All "git hook" hooks have equivalents in `git-hooks/`
- [ ] All "skill instruction" hooks have their guidance in the relevant SKILL.md or AGENTS.md
- [ ] All "drop" hooks are removed from settings.json
- [ ] `dagger call check` catches everything the old hooks caught
- [ ] No regressions: run full test suite before and after each migration batch

## Implementation Sequence
1. Drop: Remove codex-post-feedback, codex-session-init, session-health-check from settings.json
2. Skill instructions: Move exa-research-reminder, fix-what-you-touch, shaping-ripple, check-todo-quality guidance into skills/AGENTS.md
3. Git hooks: Move block-master-push to git-hooks/pre-push
4. Dagger gates: Add exclusion-guard, portable-code-guard, env-var-newline-guard, disk-space-guard, stop-quality-gate equivalents to Dagger
5. Keep: destructive-command-guard, github-cli-guard, permission-auto-approve, time-context stay until harness-agnostic alternatives exist
