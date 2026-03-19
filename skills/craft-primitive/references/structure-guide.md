# Skill Structure Guide

## Filesystem Hierarchy

Progressive disclosure IS the architecture:

| Level | Token cost | Loaded when | Max size |
|-------|-----------|-------------|----------|
| Metadata (name + description) | ~100 tokens | Always in context | 1024 chars |
| SKILL.md body | Hundreds of tokens | On trigger | 500 lines (aim <150) |
| `references/` | Unlimited | On-demand | No limit |
| `scripts/` | Zero (executed) | Never loaded into context | No limit |

## Ideal Skill Anatomy

```
skill-name/
├── SKILL.md              # Required. Tight index (<150 lines ideal)
├── references/           # On-demand detailed docs
│   ├── spec.md
│   └── examples.md
├── scripts/              # Executable code (never loaded)
│   └── validate.py
└── templates/            # Reusable starting points
    └── template.md
```

## The Tight Index Principle

**SKILL.md, AGENTS.md, and all context-management docs should evolve toward being short punchy
indexes / tables of contents that point at references.**

Progressive disclosure is the default for all context management, not just skills.
If a context document exceeds ~150 lines, it's time to extract sections to references.

- SKILL.md body: 500 lines absolute max. Aim for <150.
- If approaching 150 lines, extract to references/
- Tables of contents, not walls of prose
- One level deep: references link directly from SKILL.md, never chain references → references

## SKILL.md Requirements

### Frontmatter (YAML)

```yaml
---
name: skill-name           # lowercase, hyphens, max 64 chars
description: |             # ~100 words, max 1024 chars
  What this skill does. When to use it.
  Include trigger terms users might say.
user-invocable: false                  # Optional: foundational/ambient skill
disable-model-invocation: true         # Optional: user-only slash command
argument-hint: "[optional examples]"   # Optional: intent router, not CLI help
allowed-tools: Read, Grep              # Optional: restrict/auto-approve tools
---
```

### Body Structure

1. **Purpose** (1-2 sentences)
2. **Routing table** (if umbrella, map intent → reference)
3. **Workflow** (numbered steps or decision table)
4. **Scripts** (table of available scripts)
5. **Anti-patterns** (common mistakes)

## Command-Surface Rule

- Keep the happy path intent-first (natural language or one simple argument)
- Use flags only for deterministic mechanics (`--all`, `--list`, `--fix`)
- Avoid flag matrices that require memorization
- Treat `argument-hint` as an intent router, not CLI help text

## When to Split into References

Move content to `references/` when:
- Section exceeds 50 lines
- Content is mutually exclusive with other sections
- Detail is only needed for specific subtasks
- Examples are extensive

## Script Requirements

- Must be executable (`chmod +x`)
- Accept clear arguments
- Return structured output (JSON preferred)
- Handle errors with clear messages
- Zero external dependencies when possible (stdlib only)
- Executed, not loaded into context

## Cross-Project vs Project-Specific

| Location | When |
|----------|------|
| Spellbook `skills/` | Reusable across projects |
| Project-local (e.g. `.agents/skills/`) | Team conventions, domain rules, project architecture |
