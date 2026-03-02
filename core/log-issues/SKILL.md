---
name: log-issues
description: |
  Audit a domain then create GitHub issues for all findings. Handles: stripe,
  bitcoin, lightning, btcpay, docs, landing, observability, onboarding, posthog,
  production, product-standards, bun, virality. Deduplicates against open issues.
  Invoke for: backlog creation from audit, issue triage, gap tracking.
argument-hint: "<domain|--all>"
disable-model-invocation: true
---

# /log-issues

Audit a domain, create GitHub issues for every finding.

## Usage

```
/log-issues stripe           # Audit Stripe, create issues
/log-issues production        # Audit production, create issues
/log-issues --all             # Audit everything, create issues for all findings
```

## Domains

bitcoin, btcpay, bun, docs, landing, lightning, observability, onboarding,
payments, posthog, product-standards, production, stripe, virality

## Process

### 1. Audit

Read `audit/references/{domain}-checklist.md` and run all checks.
If `--all`, run all applicable domain checklists.

### 2. Deduplicate

```bash
gh issue list --state open --label "domain/{domain}" --limit 50
```

Skip findings that match existing open issues (by title similarity).

### 3. Create Issues

For each new finding:

```bash
gh issue create \
  --title "[P{0-3}] {finding description}" \
  --body "$(cat <<'EOF'
## Problem
{What's wrong}

## Impact
{Business/security/user impact}

## Location
{File:line if applicable}

## Suggested Fix
{Code snippet or skill to run}

---
Created by `/log-issues`
EOF
)" \
  --label "priority/p{0-3},domain/{domain},type/{bug|enhancement|chore}"
```

### 4. Issue Format

**Title:** `[P{0-3}] {Domain} - {description}`

**Labels:**
- `priority/p0` | `priority/p1` | `priority/p2` | `priority/p3`
- `domain/{domain}`
- `type/bug` | `type/enhancement` | `type/chore`

**Body sections:** Problem, Impact, Location, Suggested Fix

### 5. Report

```
Created 7 issues for domain/stripe:
  - [P0] #123: Missing webhook signature verification
  - [P1] #124: No customer portal configured
  - [P1] #125: Subscription status not checked
  Skipped 2 (duplicates of existing open issues)
```

## Related

- `/audit <domain>` -- Audit without creating issues
- `/fix <domain>` -- Fix issues instead of logging them
- `/groom` -- Runs `/log-issues --all` as part of backlog hygiene
