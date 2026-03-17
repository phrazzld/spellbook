---
name: canary
disable-model-invocation: true
description: |
  Query errors, check health status, and manage monitoring targets on a self-hosted
  Canary observability instance. Use when: debugging errors across services, checking
  uptime/health, managing health check targets, configuring webhooks, or asking
  "is production ok?" / "what errors happened?" against Canary. Triggers: canary,
  error query, health check, uptime, monitoring targets, observability API.
argument-hint: "[query, e.g. 'errors in volume' or 'health status' or 'add target']"
---

# /canary

Query and manage a self-hosted Canary observability instance via its REST API.

## Config

Two env vars required:

- `CANARY_ENDPOINT` — base URL (e.g. `https://canary-obs.fly.dev`)
- `CANARY_API_KEY` — Bearer token

All requests use `Authorization: Bearer $CANARY_API_KEY`.
Requests with a JSON body also include `Content-Type: application/json`.

## Common Workflows

### "What errors happened in {service}?"

```bash
curl -fsS -H "Authorization: Bearer $CANARY_API_KEY" \
  "$CANARY_ENDPOINT/api/v1/query?service=<name>&window=1h"
```

Interpret the response: summarize error classes, counts, most recent timestamps.
For deeper investigation, fetch individual error details by ID.

### "Is everything healthy?"

```bash
curl -fsS -H "Authorization: Bearer $CANARY_API_KEY" \
  "$CANARY_ENDPOINT/api/v1/health-status"
```

Interpret: report each target's status. Flag any non-healthy targets with
their last check time and failure reason.

### "What's the error landscape?"

```bash
curl -fsS -H "Authorization: Bearer $CANARY_API_KEY" \
  "$CANARY_ENDPOINT/api/v1/query?group_by=error_class&window=24h"
```

Cross-service view of error classes. Useful for spotting systemic issues.

## API Reference

Full endpoint documentation with parameters, response shapes, and admin
operations: see [references/api.md](references/api.md).

## Deploy & Ops

Fly.io deployment commands, nuclear reset procedure, bootstrap key retrieval,
triage service management: see [references/ops.md](references/ops.md).

## Invariants

- SQLite single-writer — all writes through `Canary.Repo` (pool_size: 1)
- RFC 9457 Problem Details for all error responses
- No hardcoded service names — targets/webhooks configured at runtime via API
- Bearer token auth on all `/api/v1/*` endpoints
- Windows: `1h`, `6h`, `24h`, `7d`, `30d` (anything else → 422)
