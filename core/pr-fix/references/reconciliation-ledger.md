# Reconciliation Ledger

Use this reference during the review phase of `/pr-fix`.

## Purpose

The goal is not "counts are zero right now." The goal is:
- every actionable review item is inventoried
- every actionable item has a decision
- every actionable PR review comment has a direct reply
- every actionable review thread is resolved
- every actionable bot issue comment has an explicit response
- the inventory is still clean after review automation settles

## Deterministic Inventory

Use the inventory script first:

```bash
python3 scripts/review_inventory.py $PR > /tmp/pr-fix-review-inventory.json
```

The script gathers:
- review threads
- PR review comments
- issue comments
- current PR checks

It does **not** decide what is actionable. That part is semantic and belongs to the model.

## Working Ledger

Build a scratch ledger from the inventory with one row per actionable item:

| source | id | author | path | decision | reply | resolved | notes |
|--------|----|--------|------|----------|-------|----------|-------|
| thread | ... | ... | ... | fix now | yes | yes | ... |
| issue-comment | ... | ... | ... | defer | yes | n/a | issue #... |

Required states:
- `decision`: `fix now | defer | reject`
- `reply`: `yes`
- `resolved`: `yes` for review threads, `n/a` for issue comments

If any actionable row is incomplete, the PR is not unblocked.

## Actionable vs Non-Actionable

Usually actionable:
- bug reports
- security findings
- correctness concerns
- explicit suggestions tied to behavior or recovery
- requests for missing tests

Usually non-actionable:
- pure summaries
- "review in progress" status comments
- check-run dashboards with no concrete ask
- informational bot help text

When unsure, bias toward treating the item as actionable until you classify it explicitly.

## Direct Reply Rule

Do not replace direct replies with a summary comment.

For PR review comments:
- reply on the thread itself
- then resolve the thread

For bot issue comments:
- post a direct response comment that references the specific finding or comment id
- do not rely on a generic "addressed all bot comments" post

## Settlement Gate

After every push, `gh pr ready`, or explicit bot trigger:
1. wait for review automation to settle
2. rerun the inventory script
3. compare the new inventory against your ledger
4. reconcile any newly-added items

Do not post `PR Unblocked` until the post-settlement inventory is clean.

Review automation commonly includes:
- `CodeRabbit`
- `Greptile`
- `Cerberus`
- `Gemini`
- `Claude`
- `Codex`
- checks named `review / ...`

If the repo is known to emit comments after the checks finish, require one more quiet poll with no inventory changes.

## Final Verification Checklist

Before signaling success, confirm all of these:
- required CI is green
- no review-related checks are still pending
- actionable ledger rows are fully closed
- unresolved review thread count is zero
- no actionable bot issue comment is left without a response
- no new comments appeared in the final post-settlement inventory
