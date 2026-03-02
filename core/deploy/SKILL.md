---
name: deploy
description: |
  Deploy cerberus targets: cloud (Fly.io), web (Vercel), oss (GitHub release).
  Pre-flight checks, deploy, health verify, rollback guidance.
  Use when: deploying, shipping to production, releasing.
  Trigger: /deploy cloud, /deploy web, /deploy oss, /deploy all.
argument-hint: <cloud|web|oss|all>
model-invocable: false
---

# /deploy

Deploy with confidence. Pre-flight → deploy → verify → report.

## Targets

| Target | Platform | Deploy From | Command | Verify |
|--------|----------|-------------|---------|--------|
| `cloud` | Fly.io | `cerberus-cloud/` | `fly deploy` | `curl -sf https://cerberus-cloud.fly.dev/api/health` |
| `web` | Vercel | `cerberus-web/` | `vercel --prod` | HTTP 200 on production URL |
| `oss` | GitHub Actions | `cerberus/` | `gh workflow run release.yml --ref master` | `gh release list --limit 1` |

Parse `$ARGUMENTS` to determine target(s). If `all`, deploy in order: `oss` → `cloud` → `web`.
If no argument, ask the user which target.

## Pre-flight (ALL targets)

1. **CLI tool exists** — `fly version` / `vercel --version` / `gh --version`
2. **Git status clean** — `git status --porcelain` must be empty (uncommitted changes = abort)

## Pre-flight: `cloud`

3. **Submodule initialized** — `git submodule status cerberus` must NOT show `-` prefix (uninitialized)
4. **No local submodule modifications** — `git submodule status cerberus` must NOT show `+` prefix
5. **Tests pass** — `bun test`
6. **Working directory** — must be `cerberus-cloud/` (or cd into it)

If submodule is uninitialized:
```
Submodule not initialized. Run:
  git submodule update --init cerberus
```

## Pre-flight: `web`

3. **Build succeeds** — `bun run build` from `cerberus-web/`

## Pre-flight: `oss`

3. **On master** — `git branch --show-current` must be `master`
4. **Confirm HEAD** — show `git log --oneline -3` and ask user to confirm this is the right commit

## Deploy

Run the deploy command. Stream output (don't suppress).

## Verify

After deploy completes, verify with retries (3 attempts, 5s apart):

- **cloud**: `curl -sf https://cerberus-cloud.fly.dev/api/health`
- **web**: `curl -sf <production-url>` (resolve from vercel output)
- **oss**: `gh release list --limit 1` (confirm new release appears)

## Report

On success:
```
✅ <target> deployed successfully
   Version: <commit-sha-short>
   URL: <url>
```

On failure:
```
❌ <target> deploy failed
   Error: <error-summary>

   Rollback (cloud): fly releases → fly deploy --image <previous-ref>
   Rollback (web):   vercel rollback
   Rollback (oss):   gh release delete <tag> --yes
```

## Fly.io Details

- **App**: `cerberus-cloud`
- **Region**: `iad`
- **Health**: `/api/health`
- **Required secrets**: `GITHUB_APP_ID`, `GITHUB_APP_PRIVATE_KEY`, `OPENROUTER_API_KEY`, `GITHUB_WEBHOOK_SECRET`, `GITHUB_MARKETPLACE_WEBHOOK_SECRET`
- **Volume**: `cerberus_data` mounted at `/app/data` (SQLite persistence)
- **Rollback**: `fly releases` → find previous image → `fly deploy --image <ref>`
