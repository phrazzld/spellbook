---
name: research
description: |
  Web research, multi-AI delegation, and multi-perspective validation.
  /research [query], /research delegate [task], /research thinktank [topic].
  Triggers: "search for", "look up", "research", "delegate", "get perspectives",
  "web search", "find out", "investigate", "introspect", "session analysis".
argument-hint: "[query] or [delegate|thinktank|introspect] [args]"
---

# Research

Retrieval-first research, multi-AI orchestration, and expert validation.

## Absorbed Skills

This skill consolidates: `web-search`, `delegate`, `thinktank`, `introspect`.

## Routing

| Intent | Sub-capability |
|--------|---------------|
| Search the web, find docs/info, `/web`, `/web-deep`, `/web-news`, `/web-docs` | `references/web-search.md` |
| Delegate work to Codex/Gemini/agents, orchestrate multi-AI | `references/delegate.md` |
| Multi-perspective expert validation, consensus | `references/thinktank.md` |
| Analyze session history, usage patterns, improvement opportunities | `references/introspect.md` |

If first argument matches a sub-capability name, read the corresponding reference.
If no argument, select based on user intent. If user specifies a sub-capability
by name (e.g., "delegate this to codex"), route directly.

Read the relevant reference and follow its instructions.
