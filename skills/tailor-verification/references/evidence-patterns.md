# Evidence Patterns

Verification primitives are only useful if they produce artifacts a maintainer
can inspect after the run. "It worked for me" is not evidence.

## Evidence Ladder

Prefer the lightest artifact that still proves the claim:

1. Command output with the assertion visible
2. Screenshot tied to a named success state
3. Browser trace or video for multi-step flows
4. Saved fixture or API response when backend state matters

## Minimum Evidence Contract Per Flow

Every flow should define:

- success state being proven
- artifact path or output location
- timestamp or run identifier
- one negative signal that would fail the flow

Example:

```md
Success state: booking confirmed with visible confirmation ID
Artifacts: /tmp/verify-booking/<timestamp>/confirmation.png
Negative signal: redirect back to login or empty confirmation state
```

## Result Schema

When a repo-local orchestrator, CI check, or follow-on agent needs structured
aggregation, each flow agent should emit a minimal `result.json`.

```json
{
  "flow": "auth-login",
  "status": "pass",
  "timestamp": "2026-03-20T10:30:00Z",
  "assertions": [
    {
      "name": "login redirect",
      "status": "pass",
      "evidence": "/tmp/verify-login/2026-03-20T10-30-00Z/success.png"
    }
  ]
}
```

Keep it small:

- `flow` matches the agent slug
- `status` is one of `pass`, `fail`, `error`, or `skip`
- `assertions` point to the artifact that proves each claim

## Good Practices

- Name artifacts after the flow and state they prove
- Keep scratch artifacts in `/tmp` unless the repo explicitly versions them
- Capture one artifact per key transition, not every click
- Tie screenshots to an assertion in the report
- Record which fixture or test user produced the evidence

## Common Failure Modes

- Screenshots with no explanation of what success looks like
- Evidence written into the repo without an explicit reason
- Passing runs that never exercised auth or seeded data
- Browser traces saved without noting which step failed

## Audit Questions

When reviewing an existing verification agent, ask:

- Can another engineer inspect the artifacts and agree the flow passed?
- Does the evidence reflect the current routes and UI?
- Is the artifact location stable enough to find but disposable enough to avoid repo churn?
