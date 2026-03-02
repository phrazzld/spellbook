---
description: Execute a scoped change using planner -> worker -> reviewer flow
---
Task: $@

Preferred path:
- If `/pipeline` is available, run `/pipeline repo-delivery-v1 $@`.
- Otherwise execute the same flow manually using `.pi/agents/planner.md`, `.pi/agents/worker.md`, and `.pi/agents/reviewer.md`.

Keep the patch focused, verify with relevant repo checks, and report residual risk.
