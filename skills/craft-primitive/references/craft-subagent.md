# Craft Subagent

Focused workflow for creating or updating an agent definition.

## When Agent vs Skill

| Primitive | Best for |
|-----------|----------|
| **Agent** | Review personas, specialized perspectives, bounded analysis |
| **Skill** | Workflows, multi-step processes, tool integrations |

Agents are stateless reviewers. Skills are procedural workflows.

## Canonical Format

Spellbook uses **markdown + YAML frontmatter** (Claude Code native) as source of truth.

```yaml
---
name: agent-name
description: When to use this agent
tools: Read, Grep, Glob, Bash
---

[System prompt in markdown]
```

### Required Fields

- `name` — lowercase, hyphens, max 64 chars
- `description` — what this agent does and when to use it
- `tools` — comma-separated list of available tools

### Optional Fields

- `model` (sonnet/opus/haiku/inherit)
- `permissionMode` (default/acceptEdits/dontAsk/bypassPermissions/plan)
- `maxTurns`, `skills`, `mcpServers`, `hooks`, `memory`, `background`, `isolation`

Body = system prompt. Subagents can't nest.

## Cross-Harness Translation

`/focus` translates markdown → TOML for Codex during sync.

| Claude Code (markdown) | Codex (TOML) |
|------------------------|--------------|
| YAML frontmatter | TOML header |
| Body (markdown) | `developer_instructions` |
| `tools` | N/A (sandbox-based) |
| `permissionMode` | `sandbox_mode` |
| `model` | `model` + `model_reasoning_effort` |

Portable core (shared): `name`, `description`, prompt body, `model`, `skills`, `mcpServers`.

## Where Agents Live

| Destination | Location |
|------------|----------|
| **Spellbook** | `agents/{name}.md` in spellbook repo |
| **Project-local** | Project-local agents dir (e.g. `.claude/agents/`, `.codex/agents/`) |

Focus only manages agent files it installed (with matching `.spellbook` marker).
Project-local agents without a marker are left alone.

## Process

1. Determine if agent or skill is the right primitive type
2. Write frontmatter with name, description, tools
3. Write system prompt as markdown body
4. Test with real queries
5. For spellbook agents: commit to `agents/` and regenerate `index.yaml`
