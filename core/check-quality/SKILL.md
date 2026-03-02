---
name: check-quality
description: |
  Audit and enforce quality infrastructure: tests, CI/CD, hooks, coverage,
  linting, security. Outputs prioritized findings (P0-P3) and can fix gaps.
  Invoke for: "quality audit", "set up CI", "add hooks", "coverage gaps",
  "quality gates", "is this project production-ready?"
disable-model-invocation: true
---

# /check-quality

Audit quality infrastructure. Fix gaps. Verify everything works.

## What This Does

1. Audit testing infrastructure (Vitest, Jest, coverage)
2. Audit git hooks (Lefthook, Husky)
3. Audit CI/CD (GitHub Actions, branch protection)
4. Audit linting/formatting (ESLint, Prettier, Biome)
5. Security scan via `security-sentinel` agent
6. Fix identified gaps (install tools, create configs, set up CI)
7. Verify fixes work end-to-end

**This is both audit AND setup.** It checks what exists, fixes what's missing, and proves it works.

## Process

### 1. Audit

Run quick infrastructure assessment:

```bash
# Test runner
[ -f "vitest.config.ts" ] || [ -f "vitest.config.js" ] && echo "V Vitest" || echo "X Vitest"
[ -f "jest.config.ts" ] || [ -f "jest.config.js" ] && echo "V Jest (prefer Vitest)" || echo "- Jest"

# Coverage
grep -q "coverage" package.json 2>/dev/null && echo "V Coverage script" || echo "X Coverage script"
grep -q "@vitest/coverage" package.json 2>/dev/null && echo "V Coverage plugin" || echo "X Coverage plugin"

# Git hooks
[ -f "lefthook.yml" ] && echo "V Lefthook" || echo "X Lefthook (recommended)"
[ -f ".git/hooks/pre-commit" ] && echo "V pre-commit hook" || echo "X pre-commit hook"
[ -f ".git/hooks/pre-push" ] && echo "V pre-push hook" || echo "X pre-push hook"

# CI/CD
[ -f ".github/workflows/ci.yml" ] || [ -f ".github/workflows/test.yml" ] && echo "V CI workflow" || echo "X CI workflow"
grep -rq "vitest-coverage-report" .github/workflows/ 2>/dev/null && echo "V Coverage in PRs" || echo "X Coverage in PRs"

# Linting
[ -f "eslint.config.js" ] || [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] && echo "V ESLint" || echo "X ESLint"
[ -f "biome.json" ] && echo "V Biome" || echo "- Biome"
[ -f "tsconfig.json" ] && echo "V TypeScript" || echo "X TypeScript"
grep -q '"strict": true' tsconfig.json 2>/dev/null && echo "V Strict mode" || echo "X Strict mode"

# Commit standards
[ -f "commitlint.config.js" ] || [ -f "commitlint.config.cjs" ] && echo "V Commitlint" || echo "X Commitlint"

# Custom guardrails
[ -d "guardrails" ] && echo "V guardrails/" || echo "- No custom guardrails"
```

Spawn `security-sentinel` agent for vulnerability analysis.

### 2. Plan

Prioritize findings:

| Gap | Priority |
|-----|----------|
| No test runner | P0 |
| No CI workflow | P0 |
| Security vulnerabilities | P0 |
| No coverage | P1 |
| No git hooks | P1 |
| No linting | P1 |
| Not strict TypeScript | P1 |
| No commitlint | P2 |
| No coverage in PRs | P2 |
| No custom guardrails | P3 |
| Tool upgrades | P3 |

### 3. Fix

Fix every gap. Delegate to Codex where appropriate.

**Lefthook:** `pnpm add -D lefthook && pnpm lefthook install` + create `lefthook.yml` per `references/lefthook-config.md`

**Vitest:** `pnpm add -D vitest @vitest/coverage-v8` + config per `references/vitest-config.md`

**CI:** Create `.github/workflows/ci.yml` per `references/github-actions.md`

**Commitlint:** `pnpm add -D @commitlint/cli @commitlint/config-conventional` + add commit-msg hook

**Branch protection:** Guide user through GitHub settings or use `gh api`

### 4. Verify

Prove it works -- don't just check files exist:

```bash
pnpm lefthook run pre-commit          # Hooks work
pnpm test --run                        # Tests run
echo "bad message" | pnpm commitlint   # Should fail
echo "feat: valid" | pnpm commitlint   # Should pass
```

## Tool Choices

**Lefthook > Husky.** Go binary, faster, parallel, simpler YAML.
**Vitest > Jest.** Faster, native ESM, built-in coverage.
**vitest-coverage-report-action > Codecov.** Zero external service.

Don't churn working alternatives. Improve what exists.

## Coverage Philosophy

Coverage is diagnostic, not a goal. 60% meaningful > 95% testing implementation details. NEVER lower a coverage threshold to pass CI -- write more tests instead.

## Anti-Patterns

- NEVER lower quality gates to pass CI (coverage, lint, type strictness)
- Don't skip hooks routinely -- fix root cause
- Don't test implementation details -- test behavior
- Don't rely on heavy mocking -- prefer integration tests
- CI on every PR, not just main

## Output Format

```markdown
## Quality Gates Audit

### P0: Critical (Must Have)
- [findings]

### P1: Essential (Every Project)
- [findings]

### P2: Important (Production Apps)
- [findings]

### P3: Nice to Have
- [findings]

## Current Status
- Test runner: [status]
- Coverage: [status]
- Git hooks: [status]
- CI/CD: [status]
- Linting: [status]
- Security: [status]

## Summary
- P0: N | P1: N | P2: N | P3: N
```

## References

- `references/lefthook-config.md` -- Hook configurations
- `references/github-actions.md` -- CI workflows
- `references/vitest-config.md` -- Test configuration
- `references/branch-protection.md` -- GitHub settings
- `references/testing-standards.md` -- Testing standards
- `references/quality-gates-philosophy.md` -- Quality gate standards

## Related

- `/log-quality-issues` -- Create GitHub issues from findings
- `/fix-quality` -- Fix quality infrastructure
- `/test-coverage` -- Deep test audit with coverage analysis
