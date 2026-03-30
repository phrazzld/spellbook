# Self-healing CI — auto-repair Dagger gate failures

Priority: low
Status: ready
Estimate: L

## Goal

When `dagger call check` fails, auto-spawn a builder sub-agent to diagnose and fix the failure. Dagger 0.18+ has native LLM integration.

## How It Works

1. `check()` captures failure output: gate name, error message, affected files
2. `heal()` receives failure context, spawns builder with focused prompt
3. Builder operates in a branch, commits fix, re-runs failing gate
4. Pass → squash-commit the fix. Fail after 2 attempts → escalate to human.
5. Optional: wire into pre-push hook (push fails → offer to auto-heal → re-push)

## Research Needed
- Explore Dagger 0.18+ LLM integration API
- Study Nx's self-healing CI patterns
- Understand how Dagger Functions invoke external agents
- Prototype: can a Dagger Function call `claude` CLI as a subprocess?

## Oracle
- [ ] `dagger call heal` after a lint failure automatically fixes the lint issue
- [ ] Fix is committed on a branch (not main)
- [ ] Re-running `dagger call check` after heal succeeds
- [ ] After 2 failed heal attempts, escalation message is clear

## Non-Goals
- Don't try to heal test failures (too complex for v1 — start with lint/format only)
- Don't auto-merge heal commits — human reviews
