---
name: flywheel-qa
description: |
  Agentic QA for flywheel PRs. Navigate preview deploy with Agent Browser,
  verify UI renders, check for error boundaries, test interactive flows.
  Use when: PR passes CI but needs runtime verification before merge.
disable-model-invocation: true
argument-hint: "<PR-number>"
---

# /flywheel-qa

Runtime QA that CI can't do. Navigate, click, verify.

## Role

QA engineer verifying a PR's preview deployment before merge. You test what
static analysis and unit tests cannot: actual page rendering, user flows,
error boundaries, and console errors.

## Objective

Verify PR `$ARGUMENTS` preview deployment works correctly for all critical
user paths. Report pass/fail with evidence.

## Prerequisites

- PR has a Vercel preview deployment URL
- Agent Browser MCP is available

## Workflow

### 1. Get Preview URL

```bash
PR=$ARGUMENTS
PREVIEW_URL=$(gh pr view "$PR" --repo misty-step/caesar-in-a-year \
  --json comments --jq '[.comments[] | select(.body | test("vercel.app")) | .body] | last' \
  | grep -oE 'https://[a-z0-9-]+\.vercel\.app' | head -1)

# Fallback: check deployments API
if [ -z "$PREVIEW_URL" ]; then
  BRANCH=$(gh pr view "$PR" --json headRefName --jq .headRefName)
  PREVIEW_URL="https://caesar-in-a-year-git-${BRANCH}-misty-step.vercel.app"
fi
```

### 2. Critical Path Tests

Every QA run MUST verify these paths. Failure on any = QA fail.

| # | Path | What to Check |
|---|------|---------------|
| 1 | Landing page (`/`) | Renders, no error boundary, CTA visible |
| 2 | Dashboard (`/dashboard`) | Auth redirect or content loads, no "Something went wrong" |
| 3 | Subscribe (`/subscribe`) | Page renders, pricing visible |
| 4 | Session page (`/session`) | Content loads or appropriate empty state |
| 5 | Any new route in PR diff | Renders without error |

For each path:

1. Navigate to the URL
2. Wait for page load (no loading spinner after 5s)
3. Check for error boundary text: "Something went wrong", "Error", "500"
4. Read console for errors (`read_console_messages`)
5. Verify key elements are visible (headers, content areas, CTAs)
6. Take screenshot as evidence

### 3. Interactive Flow Tests (if PR touches these)

| Flow | Steps |
|------|-------|
| Auth | Sign in → redirected to dashboard → user info visible |
| Navigation | Click nav items → pages load → no flash of error |
| Forms | Fill form → submit → success state (no silent failure) |

### 4. Regression Checks

- Check all routes touched by the PR's diff
- If PR modifies a component used in multiple routes, check ALL routes using it
- If PR touches data fetching, verify both loading and loaded states

### 5. Console Error Audit

```
read_console_messages with pattern: "(Error|TypeError|ReferenceError|Failed|Unhandled)"
```

Any unhandled runtime error = QA fail.

## Output

Post a comment on the PR with results:

```bash
gh pr comment $PR --repo misty-step/caesar-in-a-year --body "$(cat <<'EOF'
## QA Results

**Status**: PASS / FAIL

### Critical Paths
- [x] Landing page: renders, CTA visible
- [x] Dashboard: loads for authenticated user
- [x] Subscribe: pricing visible
- [x] Session: content loads
- [ ] Dashboard: "Something went wrong" error boundary triggered

### Console Errors
None / [list errors found]

### Screenshots
[attached or described]

### Recommendation
Ready to merge / Needs fix: [describe issue]
EOF
)"
```

## Failure Modes

If QA finds issues:
1. Post detailed comment with evidence (screenshot, console errors)
2. Return non-zero exit (agent reports failure)
3. Coordinator will NOT merge — spawns `/pr-fix` agent instead

## Anti-Patterns

- Checking only the happy path (always test error states too)
- Skipping console error check (runtime errors hide behind working UI)
- Testing against localhost (always use preview URL)
- Marking pass without actually navigating (screenshots are evidence)
