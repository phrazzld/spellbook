# Expand Dagger CI gates — replace hook enforcement

Priority: medium
Status: ready
Estimate: M

## Goal

Add new Dagger gates to `ci/src/spellbook_ci/main.py` that replace Claude hook enforcement with harness-agnostic checks. Each gate fires once per `dagger call check`, works across all harnesses and human workflows.

## Non-Goals
- Don't make gates fail by default — warn first, repos escalate to hard failure
- Don't add external tool dependencies — use grep/AST heuristics

## New Gates

### check-no-hardcoded-paths
Replaces `portable-code-guard.py`. Scans shell scripts and config files for `/Users/<username>/` or `/home/<username>/` patterns. Excludes build artifacts.

### check-no-exclusion-shortcuts
Replaces `exclusion-guard.py`. Scans for `@ts-ignore`, `eslint-disable`, `.skip`, `.xit`, `istanbul ignore`, `coverage exclude` patterns. Reports count and locations.

### check-no-echo-pipe-env
Replaces `env-var-newline-guard.py`. Scans for `echo ... | ... env add/set` patterns that corrupt secrets with trailing newlines.

### check-complexity-budget (optional, repos opt in)
Reads `.spellbook.yaml` complexity thresholds. Measures LOC per file, nesting depth. Warns on overages.

## Oracle
- [ ] `dagger call check` runs all new gates alongside existing 7
- [ ] New gates discover files from filesystem (not hardcoded lists)
- [ ] Each gate warns (exit 0 with message) by default, doesn't fail
- [ ] Running `dagger call check` on spellbook repo catches at least one hardcoded path or exclusion pattern if present

## Depends On
- 004-hook-migration (for migration sequencing)
