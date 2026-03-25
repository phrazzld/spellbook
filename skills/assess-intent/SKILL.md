---
name: assess-intent
description: |
  Validate that a PR fulfills its linked issue's intent contract.
  Checks each acceptance criterion, detects scope drift and missing
  deliverables. Use in code review (per-PR).
agent_tier: weak
temperature: 0
disable-model-invocation: true
---

# /assess-intent

Verify a PR delivers what its linked issue specified. Produces per-AC verdicts, scope drift findings, and an overall alignment score.

## Inputs

Three artifacts, all required:

1. **Issue body** -- `gh issue view $N --json body`
2. **PR diff** -- `git diff main...HEAD` (or base branch)
3. **PR description** -- `gh pr view $N --json body`

If the issue number isn't obvious from the PR body or branch name, stop and ask.

## What It Checks

Six dimensions, evaluated in order.

### 1. Intent Contract Presence

Does the linked issue have a `## Product Spec` / `### Intent Contract` section? If missing, emit a warning and assess against whatever acceptance criteria exist (checklist items, Given/When/Then blocks, or prose requirements). See `references/rubric.md` for handling issues without formal contracts.

### 2. Acceptance Criteria Coverage

For each AC (Given/When/Then, checklist item, or numbered requirement):

- Is there evidence in the diff that it's implemented?
- Evidence means: code that implements the described logic, a test that exercises the behavior, or config that enables the feature.
- Each AC gets a verdict: `met`, `partially_met`, `not_met`, or `untestable`.

### 3. Verification Commands

Does the issue specify verification commands or manual QA steps? If so, are they plausibly satisfiable by the changes in the diff? Flag commands that reference files, endpoints, or behaviors not present in the diff.

### 4. Scope Drift

Does the PR change files or modules not mentioned in or implied by the intent? Legitimate scope includes touching shared utilities to enable the feature. Drift means refactoring unrelated code, adding unrelated features, or cleaning up files outside the intent's domain.

### 5. Completeness

Are there ACs that appear unaddressed by the diff? An unaddressed AC has no corresponding code change, test, config change, or documentation change.

### 6. Undeclared Additions

Does the PR add functionality beyond the intent contract? New exports, new endpoints, new CLI flags, new config options, or new behaviors not traceable to any AC.

## Scoring

| Range | Meaning |
|-------|---------|
| 90-100 | All ACs met with clear evidence, no drift |
| 70-89 | All ACs met but some evidence is weak, minor drift |
| 50-69 | Some ACs partially met or significant scope drift |
| 30-49 | Multiple ACs not met |
| 0-29 | PR bears little relation to stated intent |

Score = 100 minus weighted deductions. `not_met` AC deducts 15-20, `partially_met` deducts 5-10, scope drift deducts 3-5 per drifted file, undeclared additions deduct 2-5 each. Floor at 0.

## Output Contract

```json
{
  "score": 82,
  "grade": "70-89",
  "issue": "#42",
  "intent_contract_present": true,
  "acceptance_criteria": [
    {
      "id": "AC1",
      "description": "User can reset password via email link",
      "status": "met",
      "evidence": ["src/auth/reset.ts:45-78", "test/auth/reset.test.ts:12-34"]
    },
    {
      "id": "AC2",
      "description": "Reset link expires after 24 hours",
      "status": "partially_met",
      "evidence": ["src/auth/reset.ts:80 (TTL set to 24h)"],
      "gap": "No test for expiration behavior"
    },
    {
      "id": "AC3",
      "description": "Rate limit: max 3 reset requests per hour",
      "status": "not_met",
      "evidence": [],
      "gap": "No rate limiting code found in diff"
    }
  ],
  "scope_drift": [
    {
      "file": "src/utils/string-helpers.ts",
      "reason": "Reformatted file not related to password reset"
    }
  ],
  "undeclared_additions": [
    {
      "description": "New /api/auth/verify-token endpoint",
      "files": ["src/api/auth/verify-token.ts"]
    }
  ],
  "verification_commands": {
    "specified": 2,
    "plausibly_satisfied": 1,
    "issues": ["Command `curl /api/auth/rate-limit-status` references endpoint not in diff"]
  }
}
```

All fields required. `acceptance_criteria` ordered by AC number. `scope_drift` and `undeclared_additions` may be empty arrays.

## Process

1. Fetch issue body. Locate intent contract / acceptance criteria.
2. Fetch PR diff and PR description.
3. For each AC, search the diff for implementing code, tests, config. Assign verdict.
4. Scan diff for files outside the intent's domain. Classify as legitimate scope or drift.
5. Scan diff for new exports, endpoints, flags, behaviors not traceable to any AC.
6. Check verification commands against diff contents.
7. Compute score.
8. Emit JSON output.

## Integration Points

| Workflow | How |
|----------|-----|
| `/autopilot` (step 11a) | Run assess-intent before PR creation; block on score < 70 |
| `agent-review.yml` | Per-PR check; comment score and findings on the PR |
| `/pr` | Include intent alignment summary in PR body |
| `/settle` | Flag unaddressed ACs before merge |

## Anti-Patterns

- Failing a PR for touching a shared utility that the feature genuinely needs -- trace the dependency before calling it drift
- Treating prose descriptions as formal ACs when a structured intent contract exists -- prefer the structured version
- Penalizing PRs that fix bugs discovered during implementation -- incidental fixes within the intent's domain are legitimate
- Giving `met` status based on PR description claims alone -- evidence must come from the diff

## References

- `references/rubric.md` -- detailed guidance on evidence standards, drift classification, and handling missing intent contracts
