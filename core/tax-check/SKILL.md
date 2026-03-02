---
name: tax-check
disable-model-invocation: true
description: |
  Validate tax calculations: bracket math, deduction eligibility, Form 8949 format, audit-risk flags.
user-invocable: true
---

# /tax-check

Validate tax calculations and surface risks.

## Steps

1. Rebuild reports to ensure fresh numbers.
2. Verify bracket math against configured year constants.
3. Recompute taxable income: wages + gains - deductions, confirm totals.
4. Validate Form 8949 CSV format and totals vs `normalized/capital-gains.json`.
5. Flag audit risks: large losses, missing basis, inconsistent dates, or missing source docs.

## Examples

```bash
# Regenerate tax outputs before validation
pnpm report
```

```bash
# Rebuild gains if source data changed
pnpm gains
```

## References

- `scripts/generate-report.ts`
- `normalized/capital-gains.json`
- `normalized/w2-data.json`
- `normalized/charitable-donations.json`
- `reports/2025-tax-summary.md`
- `reports/tax-ready/form-8949-c.csv`
- `reports/tax-ready/schedule-d-summary.md`
