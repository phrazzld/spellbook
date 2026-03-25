---
name: review-settle
description: |
  Verify all automated reviews (CI checks, bot reviewers) have completed
  before declaring a PR settled. Polls check suites and comments until
  stable. Use in /settle Phase 1 before addressing findings.
agent_tier: weak
temperature: 0
disable-model-invocation: true
---

# /review-settle

Prevent premature "PR is done" while bots are still adding findings.
Polls CI checks and bot comments until quiescent, then emits a settlement verdict.

## Mechanism

### 1. Fetch check status

```bash
gh pr checks $PR --json name,state,conclusion
```

Parse each check into `{ name, state, conclusion }`.

### 2. Classify checks

- **Required**: checks marked required in branch protection, or CI workflows (GitHub Actions, CircleCI, etc.)
- **Optional**: informational/advisory checks (coverage reports, deploy previews, etc.)

Only required checks block settlement.

### 3. Wait for terminal state

Poll every 15 seconds. A check is terminal when state is `completed` regardless of
conclusion (`success`, `failure`, `skipped`, `neutral`).

Continue polling until all required checks reach a terminal state or timeout.

### 4. Capture comment baseline

After all checks are terminal:

```bash
gh pr view $PR --json comments --jq '.comments | length'
```

Record this count as `baseline_comments`.

### 5. Grace period

Wait 60 seconds, then re-fetch comment count.

### 6. Detect new bot activity

A comment is bot-originated if:
- The author is a GitHub App (`author.type == "Bot"`)
- The author login matches known bot patterns: `codecov`, `coderabbitai`, `github-actions`, `netlify`, `vercel`, `renovate`, `dependabot`, `sonarcloud`, `codeclimate`

If new bot comments appeared during the grace period, reset the grace period and re-enter step 5.

### 7. Emit verdict

Output JSON to stdout:

```json
{
  "status": "settled | blocked | timeout",
  "pending_checks": [],
  "failed_checks": [],
  "recent_bot_comments": 0,
  "elapsed_seconds": 0
}
```

- **settled**: all required checks terminal, no new bot activity for 60s
- **blocked**: required checks failed (list in `failed_checks`)
- **timeout**: 10-minute ceiling reached (list pending in `pending_checks`)

## Timeout

10 minutes max. If not settled by then, report `timeout` with everything still pending.

## Integration Points

| Caller | When |
|--------|------|
| `/settle` Phase 1 | Before declaring fix phase complete |
| `/autopilot` | After PR creation, before proceeding to next task |
| `/pr` | Optionally wait for initial bot pass |

## Anti-Patterns

- **No fast polling.** Minimum 15-second interval between check fetches.
- **No blocking on optional checks.** Informational checks are noise, not signal.
- **No waiting on humans.** Only automated reviewers (bots, CI). Human review is out of scope.
- **No retries on settled failures.** If checks failed, report `blocked` — don't re-trigger.
