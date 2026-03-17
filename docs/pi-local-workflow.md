# Pi Local Workflow

This repository is bootstrapped for Spellbook using repo-local Pi config under .pi/.

## Recommended run pattern

1. Use meta mode when evolving architecture/config primitives:
   - `pictl meta`
2. Use build mode for normal project delivery:
   - `pictl build`
3. Use local prompt workflows:
   - `/discover`
   - `/design`
   - `/deliver`
   - `/review`
4. Prime and use local-first memory:
   - `/memory-ingest --scope both --force` (first run, then periodic refresh)
   - `/memory-search --scope local <topic>`
   - `/memory-context --scope both <goal>`
5. If orchestration is enabled, run local pipelines:
   - `/pipeline repo-foundation-v1 <goal>`
   - `/pipeline repo-delivery-v1 <goal>`

## Local artifacts

- `.pi/settings.json`
- `.pi/persona.md`
- `.pi/agents/*.md`
- `.pi/agents/teams.yaml`
- `.pi/agents/pipelines.yaml`
- `.pi/prompts/*.md`
- `.pi/bootstrap-report.md`
