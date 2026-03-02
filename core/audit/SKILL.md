---
name: audit
description: |
  Audit any domain: stripe, bitcoin, lightning, btcpay, payments, docs, landing,
  observability, onboarding, posthog, production, product-standards, virality, bun.
  Run /audit <domain> for structured P0-P3 findings report. /audit --all for everything.
  Invoke for: domain audit, compliance check, launch readiness, gap analysis.
argument-hint: "<domain|--all>"
disable-model-invocation: true
---

# /audit

Structured domain audit. One skill, all domains.

## Usage

```
/audit stripe               # Audit Stripe integration
/audit bitcoin               # Audit Bitcoin setup
/audit production            # Audit production readiness
/audit docs                  # Audit documentation
/audit --all                 # Run all applicable domains
```

## Available Domains

| Domain | Checklist |
|--------|-----------|
| bitcoin | `references/bitcoin-checklist.md` |
| btcpay | `references/btcpay-checklist.md` |
| bun | `references/bun-checklist.md` |
| docs | `references/docs-checklist.md` |
| landing | `references/landing-checklist.md` |
| lightning | `references/lightning-checklist.md` |
| observability | `references/observability-checklist.md` |
| onboarding | `references/onboarding-checklist.md` |
| payments | `references/payments-checklist.md` |
| posthog | `references/posthog-checklist.md` |
| product-standards | `references/product-standards-checklist.md` |
| production | `references/production-checklist.md` |
| stripe | `references/stripe-checklist.md` |
| virality | `references/virality-checklist.md` |

## Process

### 1. Load Domain Checklist

Read `references/{domain}-checklist.md` for the requested domain.

If `--all`, load all checklist files. Auto-detect applicable domains from project
(check package.json deps, config files, directory structure) and skip N/A domains.

### 2. Execute Checks

For each check in the domain checklist:

1. Run the shell commands listed
2. Classify result as PASS/FAIL/WARN
3. Map failures to priority using the checklist's priority table

### 3. Output Report

```markdown
## {Domain} Audit

### P0: Critical
- [finding]: [detail]

### P1: Essential
- [finding]: [detail]

### P2: Important
- [finding]: [detail]

### P3: Nice to Have
- [finding]: [detail]

## Summary
- P0: N | P1: N | P2: N | P3: N
- Recommendation: [top action]
```

### 4. Parallel Execution (`--all`)

When `--all`, run all applicable domain checklists in parallel.
Merge results into a single report organized by domain.

## Related

- `/fix <domain>` -- Fix issues found by audit
- `/log-issues <domain>` -- Create GitHub issues from audit findings
- `/groom` -- Runs `/audit --all` as part of backlog hygiene
