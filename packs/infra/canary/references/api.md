# Canary API Reference

Base: `$CANARY_ENDPOINT/api/v1`
Auth: `Authorization: Bearer $CANARY_API_KEY`
Errors: RFC 9457 Problem Details (`type`, `title`, `status`, `detail`)

## Query

### GET /query?service={name}

Errors for a service. Paginated.

| Param | Required | Default | Values |
|-------|----------|---------|--------|
| `service` | yes | — | service name string |
| `window` | no | `1h` | `1h`, `6h`, `24h`, `7d`, `30d` |
| `cursor` | no | — | cursor from previous response |

### GET /query?group_by=error_class

Error counts grouped by class across all services.

| Param | Required | Default | Values |
|-------|----------|---------|--------|
| `group_by` | yes | — | `error_class` |
| `window` | no | `24h` | `1h`, `6h`, `24h`, `7d`, `30d` |

### GET /errors/{id}

Single error detail by ID. Returns 404 if not found.

## Health

### GET /health-status

Overall health across all targets. No parameters. Returns aggregate status.

### GET /targets/{id}/checks?window={window}

Check history for a specific target.

| Param | Required | Default | Values |
|-------|----------|---------|--------|
| `window` | no | `24h` | `1h`, `6h`, `24h`, `7d`, `30d` |

Response fields per check: `checked_at`, `result`, `status_code`, `latency_ms`,
`tls_expires_at`, `error_detail`.

### GET /healthz (public, no auth)

Liveness probe. Returns `{"status": "ok"}`.

### GET /readyz (public, no auth)

Readiness probe. Checks database and supervisor. Returns 200 or 503.

## Targets

### GET /targets

List all monitoring targets.

Response fields: `id`, `name`, `url`, `method`, `interval_ms`, `timeout_ms`,
`expected_status`, `active`, `created_at`.

### POST /targets

Create a target. Body:

```json
{
  "name": "my-api",
  "url": "https://api.example.com/healthz",
  "method": "GET",
  "interval_ms": 30000,
  "timeout_ms": 5000,
  "expected_status": 200
}
```

Optional: `headers` (object), `allow_private` (boolean).
Returns 201 with target JSON. SSRF-guarded: private IPs rejected unless `allow_private`.

### POST /targets/{id}/pause

Pause health checking for a target.

### POST /targets/{id}/resume

Resume health checking for a paused target.

### DELETE /targets/{id}

Delete a target. Returns 204.

## Webhooks

### GET /webhooks

List all registered webhooks.

Response fields: `id`, `url`, `events`, `active`, `created_at`.

### POST /webhooks

Register a webhook. Body:

```json
{
  "url": "https://example.com/hook",
  "events": ["error.new_class", "health_check.down"]
}
```

Valid events:
- `health_check.degraded`
- `health_check.down`
- `health_check.recovered`
- `health_check.tls_expiring`
- `error.new_class`
- `error.regression`

Returns 201 with webhook JSON including `secret` (shown once — store it).

### POST /webhooks/{id}/test

Send a test delivery to a webhook endpoint.

### DELETE /webhooks/{id}

Delete a webhook. Returns 204.

## API Keys

### GET /keys

List all API keys (hashed, not plaintext).

### POST /keys

Create a new API key. Returns plaintext key (shown once).

### POST /keys/{id}/revoke

Revoke an API key. Returns 204.
