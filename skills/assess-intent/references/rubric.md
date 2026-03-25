# Intent Assessment Rubric

Detailed guidance for each assessment dimension. Covers evidence standards, edge cases, and worked examples.

---

## Evidence Standards

What counts as evidence that an AC is met.

### Strong Evidence (supports `met`)

- **Test that exercises the behavior**: A test whose name or body directly corresponds to the AC. The test arranges the precondition, acts on the described trigger, and asserts the expected outcome.
- **Code that implements the described logic**: Functions, handlers, or modules whose behavior matches the AC's description. The implementation is traceable -- you can read the AC, then read the code, and see the correspondence.
- **Config that enables the feature**: Feature flags, environment variables, route registrations, or schema migrations that activate the described capability.
- **Documentation that matches**: If the AC specifies "user sees X in the UI," a corresponding component or template rendering X.

### Weak Evidence (supports `partially_met` at best)

- **PR description claims without diff support**: "I implemented rate limiting" in the PR body but no rate limiting code in the diff.
- **Tangential code changes**: The diff touches the right file but the specific behavior described in the AC isn't visibly implemented.
- **Tests that assert implementation, not behavior**: A test that mocks the rate limiter and asserts it was called, but never tests that a 4th request is actually rejected.
- **TODO/FIXME comments**: Code comments promising the behavior will be added later.

### No Evidence (supports `not_met`)

- No files in the diff relate to the AC's domain.
- The AC describes a user-facing behavior and the diff contains only backend/infra changes (or vice versa) with no connecting path.
- The AC is about a specific error case and no error handling for that case appears in the diff.

---

## Verdict Definitions

### `met`

The AC is fully addressed. Strong evidence exists in the diff. A reviewer reading the diff would conclude the described behavior is now implemented and tested.

**Example:**

> AC: "When a user submits an empty form, show validation errors for all required fields."

Diff contains:
- `src/components/Form.tsx`: validation logic that checks each required field
- `src/components/Form.tsx`: error message rendering per field
- `test/Form.test.tsx`: test titled "shows validation errors when form submitted empty" with assertions for each field

Verdict: **met**. All three evidence types present: logic, UI, test.

### `partially_met`

The AC is addressed in spirit but has gaps. The core behavior exists but edge cases, error paths, or verification are missing.

**Example:**

> AC: "Reset link expires after 24 hours."

Diff contains:
- `src/auth/reset.ts`: token generation with `expiresAt: Date.now() + 24 * 60 * 60 * 1000`
- No test for expiration. No test that an expired link is rejected.

Verdict: **partially_met**. The TTL is set (implementation exists) but there's no test proving the expiration is enforced. The behavior could silently break if the expiration check is missing or wrong.

### `not_met`

No meaningful evidence that the AC is addressed. The described behavior does not appear in the diff.

**Example:**

> AC: "Rate limit: max 3 password reset requests per hour per email."

Diff contains:
- Password reset endpoint implementation
- Token generation and email sending
- No rate limiting middleware, no counter, no time-window check

Verdict: **not_met**. The AC is specific and testable, and nothing in the diff addresses it.

### `untestable`

The AC is vague, subjective, or depends on context not available in the diff.

**Example:**

> AC: "The feature should feel intuitive."

No objective way to verify from a diff. Flag as `untestable` and recommend the issue author rewrite it as a testable behavior.

Other `untestable` triggers:
- ACs about performance without specific thresholds
- ACs about "security" without specifying the threat model
- ACs requiring manual user testing that can't be verified from code

---

## Scope Drift Classification

### Legitimate Scope (not drift)

Changes outside the feature's primary files that are necessary for the feature to work.

**Examples:**
- Updating a shared type definition to add a field the feature needs
- Adding a new route to the router file for the feature's endpoint
- Modifying a database migration to add a column the feature requires
- Updating a barrel export (`index.ts`) to expose the new module
- Fixing a pre-existing bug in a file the feature touches, when the bug would block the feature

**Test:** Can you draw a direct dependency line from the AC to this file change? If yes, it's legitimate scope.

### Drift

Changes that aren't traceable to any AC and don't enable the feature.

**Examples:**
- Reformatting files not touched by the feature
- Renaming variables in unrelated modules
- Adding logging to unrelated endpoints
- Refactoring code in a module the feature doesn't depend on
- Upgrading dependencies not required by the feature
- Adding a new feature not described in any AC

**Test:** If you removed this change from the diff, would the feature still work? If yes, it's probably drift.

### Gray Area

Some changes are judgment calls. Score as minor drift (low deduction) rather than major drift:

- Fixing a lint warning in a file the feature touches (reasonable hygiene)
- Updating a comment in a file the feature modifies (incidental improvement)
- Adding a type annotation that TypeScript now requires because of the feature's changes

---

## Handling Issues Without Intent Contracts

When the linked issue has no `## Product Spec` or `### Intent Contract` section:

1. **Warn, don't fail.** Emit `"intent_contract_present": false` and a recommendation to add one.
2. **Extract implicit ACs.** Look for:
   - Checklist items (`- [ ] ...`)
   - Given/When/Then blocks
   - Numbered requirements
   - Prose descriptions of expected behavior (less reliable, flag as low-confidence)
3. **Score against extracted ACs.** Apply the same rubric but note in the output that ACs were inferred, not declared.
4. **Cap confidence.** Without a formal intent contract, cap the maximum score at 89 regardless of evidence quality. The ceiling penalty reflects the ambiguity of informal requirements.

### When there are truly no ACs

If the issue is a one-liner like "fix the bug" with no further description:

- Score the PR against the issue title as a single implicit AC.
- Flag that the issue lacks acceptance criteria.
- Recommend enriching the issue before merge.
- Do not assign `not_met` to phantom ACs you invented -- only assess what the issue actually states.

---

## Undeclared Additions

### What to flag

New capabilities in the diff that no AC requested:

- New API endpoints or routes
- New CLI flags or subcommands
- New exported functions or classes
- New configuration options
- New user-facing behaviors (UI elements, notifications, emails)
- New database tables or columns not implied by any AC

### What NOT to flag

- Internal helper functions extracted during implementation
- Private methods or unexported utilities
- Test helpers and fixtures
- Type definitions needed by the feature
- Error handling for the feature's own code paths

### Severity

- **High**: New user-facing endpoint or behavior not in any AC. Score deduction 5.
- **Medium**: New exported function that extends the module's public API. Score deduction 3.
- **Low**: New config option with a sensible default. Score deduction 2.

---

## Worked Examples

### Example 1: Clean Implementation (Score 95)

**Issue AC:** "Users can filter the dashboard by date range. Default is last 7 days. Custom range picker allows start and end date."

**Diff:**
- `src/components/DateRangePicker.tsx` -- new component with start/end date inputs
- `src/hooks/useDateRange.ts` -- state management, defaults to 7 days
- `src/api/dashboard.ts` -- accepts `startDate`/`endDate` query params
- `test/DateRangePicker.test.tsx` -- tests default range, custom selection, invalid ranges
- `test/api/dashboard.test.ts` -- tests filtered query results

**Assessment:**
- AC "filter by date range": **met** (component + API + tests)
- AC "default last 7 days": **met** (hook defaults + test)
- AC "custom range picker": **met** (component + test)
- Scope drift: none
- Undeclared additions: none

Score: 95. Deducted 5 because the API test doesn't cover the edge case of start > end.

### Example 2: Partial Delivery (Score 58)

**Issue ACs:**
1. "Email notifications for new comments"
2. "Notification preferences page"
3. "Unsubscribe link in every email"

**Diff:**
- `src/notifications/email.ts` -- sends email on new comment
- `test/notifications/email.test.ts` -- tests email sending
- `src/components/SettingsPage.tsx` -- unrelated settings refactor

**Assessment:**
- AC1 "email notifications": **met** (implementation + test)
- AC2 "preferences page": **not_met** (no preferences UI in diff)
- AC3 "unsubscribe link": **not_met** (no unsubscribe logic in diff)
- Scope drift: `SettingsPage.tsx` refactor unrelated to notifications
- Undeclared additions: none

Score: 58. Two ACs not met (-30), one drift file (-5), plus weak evidence margin (-7).

### Example 3: Scope Creep (Score 64)

**Issue AC:** "Add retry logic to the webhook sender. 3 attempts with exponential backoff."

**Diff:**
- `src/webhooks/sender.ts` -- retry logic added (3 attempts, exponential backoff)
- `test/webhooks/sender.test.ts` -- tests retry behavior
- `src/webhooks/sender.ts` -- also refactored to async/await from callbacks
- `src/webhooks/types.ts` -- added 4 new webhook event types
- `src/webhooks/router.ts` -- routes for new event types
- `src/logging/webhook-logger.ts` -- new structured logging for webhooks

**Assessment:**
- AC "retry logic, 3 attempts, exponential backoff": **met** (implementation + test)
- Scope drift: async/await refactor (minor, same file), new event types (major), new logger (moderate)
- Undeclared additions: 4 new webhook event types, new logging module

Score: 64. AC met but significant undeclared work. The retry logic is 20% of the diff; the other 80% isn't in the intent contract.
