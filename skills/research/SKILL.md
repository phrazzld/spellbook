---
name: research
description: |
  Web research, multi-AI delegation, and multi-perspective validation.
  /research [query], /research delegate [task], /research thinktank [topic].
  Triggers: "search for", "look up", "research", "delegate", "get perspectives",
  "web search", "find out", "investigate", "introspect", "session analysis",
  "check readwise", "saved articles", "reading list", "highlights",
  "what are people saying", "X search", "social sentiment", "trending".
argument-hint: "[query] or [web-search|web-deep|web-news|web-docs|delegate|thinktank|introspect|readwise|xai] [args]"
---

# Research

Retrieval-first research, multi-AI orchestration, and expert validation.

## Absorbed Skills

This skill consolidates: `web-search`, `delegate`, `thinktank`, `introspect`.

## Routing

### Explicit sub-capability (user names one)

If first argument matches a keyword, route directly to that reference:

| Keyword | Reference |
|---------|-----------|
| `web-search`, `web-deep`, `web-news`, `web-docs` | `references/web-search.md` |
| `delegate` | `references/delegate.md` |
| `thinktank` | `references/thinktank.md` |
| `introspect` | `references/introspect.md` |
| `readwise` | `references/readwise.md` |
| `xai` | `references/xai-search.md` |

### No sub-capability (default): MANDATORY PARALLEL FANOUT

**You MUST fan out to multiple sources. A single WebSearch is NOT research.**

Research means gathering signal from many vantage points simultaneously.
WebSearch alone is a lookup, not research. The whole point of this skill is
multi-source triangulation.

**REQUIRED: Launch ALL of these in a single message (parallel Agent/Bash calls):**

1. **Exa search** — Bash: `curl -s https://api.exa.ai/search -H "x-api-key: $EXA_API_KEY" ...`
   See `references/exa-tools.md` for request format. WebSearch is fallback ONLY if curl fails.
2. **Thinktank** — Write question to `/tmp/research-q.md`, create stub `/tmp/research-ctx.md`, then:
   Bash: `thinktank /tmp/research-q.md /tmp/research-ctx.md --synthesis --quiet --output-dir /tmp/thinktank-out`
   Note: thinktank requires a target path (use stub for pure questions). Always set `--output-dir /tmp/...` to avoid dumping in CWD.
3. **xAI / social pulse** — Bash: `curl -s https://api.x.ai/v1/responses -H "Authorization: Bearer $XAI_API_KEY" ...`
   Model MUST be `grok-4.20-beta-latest-non-reasoning` (only grok-4 supports tool use).
   See `references/xai-search.md` for request format. Skip ONLY for purely technical/code queries.
4. **Codebase** — Grep/Glob for what the project already does (skip only if query is unrelated to codebase)

**Then synthesize**: consensus, conflicts, citations, recommendations across ALL sources.

**Narrow to a single source ONLY when:**
- The user explicitly names one (e.g., "/research web-search [query]")
- It's a version/fact lookup (e.g., "what version is X?")

**If you catch yourself about to return results from only WebSearch — STOP.
That means you skipped the fanout. Go back and launch the other sources.**

## Use When

- Before implementing any system >200 LOC (reference architecture search)
- Before choosing a library, framework, or approach (current best practices)
- When training data may be stale (model releases, API changes, deprecations)
- When you need to verify a fact before asserting it
- When the user asks about something outside the codebase
- During `/groom` architecture critique (reference implementations)
- During `/shape` technical exploration (how others solve this)
- During `/build` understand step (existing patterns and examples)
- When another skill says "web search first" or "research before implementing"

## Decision Framework

**If you're about to assert something from training data that could be wrong,
invoke `/research web-search` first.** The cost of a search is negligible;
the cost of hallucination is high.

This applies especially to:
- Model names and versions (stale within months)
- Library APIs and best practices (change with major versions)
- Pricing, availability, feature comparisons
- Security advisories, CVEs, deprecation notices

## Provider Routing

| Query Type | Primary Provider | Why |
|------------|-----------------|-----|
| Code examples, reference implementations | Exa (code context) | Finds actual code, not blog posts |
| Academic papers, formal specs | Exa (search) | Strong academic indexing |
| Library/framework docs | Context7 | Semantic doc search |
| Current events, model releases | Exa (with recency filter) | Real-time indexing |
| Social sentiment, public discourse, trending | xAI X Search | Real-time X/Twitter data |
| Web pages with image/video analysis | xAI Web Search | Grounded web + multimodal |
| General knowledge fallback | WebSearch / Brave | Broad coverage |

**Exa-first** for code and technical content. **xAI for social/real-time pulse.**
Default to Exa unless the query is clearly better suited to another provider.
Use xAI X Search for "what are people saying about", sentiment, discourse,
trending topics. Use xAI Web Search when you need grounded web results with
optional image understanding. See `references/xai-search.md` for API details.

## Anti-Patterns

- Asserting model versions from training data without searching
- Using WebSearch for code examples (Exa code context is better)
- Skipping research because "I'm pretty sure" (you're not)
- Research without citations (every claim needs a URL)
