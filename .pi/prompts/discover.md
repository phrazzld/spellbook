---
description: Explore this repository and map high-leverage work options
---
Use `.pi/agents/planner.md` as your operating overlay.

Task: $@

Memory-first context warmup:
- If `memory_context` is available, run it early with scope `both` and a focused query for this task.
- Prioritize local hits; use global hits only as fallback context.

Goal:
- Investigate the codebase and workflow context deeply.
- Surface an adopt/bridge/ignore view for existing local machinery.
- Return only high-signal options and a recommended next move.
