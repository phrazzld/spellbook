# Codex Harness

## Directory Layout

```
project/
├── .agents/
│   └── skills/          ← Spellbook installs skills here
│       ├── debug/       ← managed (.spellbook marker present)
│       └── my-custom/   ← unmanaged (no marker, left alone)
├── .codex/
│   ├── agents/          ← Spellbook installs agents here
│   │   └── reviewer.toml
│   └── config.toml      ← Codex configuration (enable/disable)
└── .spellbook.yaml      ← Spellbook manifest
```

## Detection

Codex is the current harness when any of:
- `CODEX` environment variable is set
- `.codex/` directory exists in the project
- The agent identifies itself as Codex

## Paths

| Primitive | Local Path |
|-----------|-----------|
| Skills | `.agents/skills/` |
| Agents | `.codex/agents/` |

## Skill Loading Behavior

Codex uses progressive disclosure matching the Agent Skills spec:
1. **Startup**: Reads `name` and `description` from every SKILL.md frontmatter
2. **Activation**: Loads full SKILL.md body when skill matches task
3. **Resources**: Files in scripts/, references/, assets/ loaded on demand

Codex scans `.agents/skills/` from CWD up to repo root.

## Enable/Disable Support

Codex supports declarative enable/disable via `config.toml`:

```toml
[[skills.config]]
path = ".agents/skills/moonshot/SKILL.md"
enabled = false
```

When focus installs skills, it can optionally generate config.toml entries
to disable skills that are installed but not currently needed. However,
the primary mechanism is nuke-and-rebuild: skills not in the manifest
are simply not installed.

## Implicit Invocation

Codex supports `allow_implicit_invocation` in `agents/openai.yaml` within
each skill directory. This is analogous to Claude Code's DMI:
- `allow_implicit_invocation: true` (default) — Codex can auto-activate
- `allow_implicit_invocation: false` — explicit `$skill-name` invocation only

When installing from Spellbook, check if the source skill has
`disable-model-invocation: true` in its frontmatter. If so, create an
`agents/openai.yaml` with `allow_implicit_invocation: false`.

## Agent Definitions

Codex agents use TOML format in `.codex/agents/`:

```toml
name = "code-reviewer"
description = "PR reviewer focused on correctness and security."
developer_instructions = """
Review code like an owner.
Prioritize correctness, security, behavior regressions, and missing test coverage.
"""
```

When installing Spellbook agents, translate from the Spellbook agent format
(Markdown) to Codex TOML format.

## Post-Install

After installing, Codex detects skill changes automatically. If changes
don't appear, the user should restart Codex.
