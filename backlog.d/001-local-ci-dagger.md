# Local CI via Dagger — kill the push-wait-read loop

Priority: high
Status: done
Estimate: L

## Goal
Agent runs full CI locally in seconds before push. GitHub Actions becomes merge-gate only.

## Non-Goals
- Don't replace GitHub Actions entirely (keep as merge gate)
- Don't build a custom CI framework — use Dagger
- Don't change existing test suites

## Oracle
- [x] `dagger call check` runs all 7 quality gates locally and passes (11s)
- [x] `dagger call lint-shell` / `lint-yaml` / `lint-python` run linters individually
- [x] Skills updated to reference `dagger call check` as the local CI command

## What Was Built
- Dagger 0.20.3 Python module at `ci/` with 7 parallel gates:
  lint-yaml, lint-shell, lint-python, check-frontmatter, check-index-drift,
  check-vendored-copies, test-bun
- Gates discover files from filesystem (no hardcoded lists)
- Frontmatter validation extracted to `scripts/check-frontmatter.py`
- Fixed `scripts/generate-index.sh` — `LC_ALL=C` for portable cut across macOS/Linux
- Fixed `scripts/check-vendored-copies.sh` — skip missing files

## Workarounds
- Dagger requires Docker (Colima on macOS). First `dagger call` pulls images (~30s cold).
- Dagger `init` fails with `.env` resolution error through symlinks. Workaround: ensure
  `.env` exists at the path Dagger resolves (varies by Docker context). Once module is
  initialized, subsequent `dagger call` commands work fine.
- Vendored SDK at `ci/sdk/` uses version `0.0.0` — pyproject.toml must use `>=0.0.0`.

## Future Work (separate backlog items when ready)
- GitHub Actions merge-gate workflow (no GHA exists yet)
- Self-healing CI: failure triggers repair agent
- `/autopilot` and `/settle` integration (call `dagger call check` automatically)

## Notes
- Dagger v0.18+ has native LLM integration — agents discover and use Dagger Functions as tools
- Solomon Hykes (Docker creator) is building this. Pipelines are Go/Python/TS code, not YAML
- Nx reports self-healing CI saves more dev time than caching. 2/3 of broken PRs get auto-fixes
- Research: https://dagger.io/deep-dives/agentic-ci/
- Research: https://dagger.io/blog/automate-your-ci-fixes-self-healing-pipelines-with-ai-agents/
