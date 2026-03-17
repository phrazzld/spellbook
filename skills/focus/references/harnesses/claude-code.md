# Claude Code Harness

## Directory Layout

```
project/
├── .claude/
│   ├── skills/          ← Spellbook installs skills here
│   │   ├── debug/       ← managed (.spellbook marker present)
│   │   ├── my-custom/   ← unmanaged (no marker, left alone)
│   │   └── focus/       ← globally installed, not project-managed
│   ├── agents/          ← Spellbook installs agents here
│   ├── settings.json
│   └── CLAUDE.md
└── .spellbook.yaml      ← Spellbook manifest
```

## Detection

Claude Code is the current harness when any of:
- `CLAUDE_CODE` environment variable is set
- `.claude/` directory exists in the project
- The agent identifies itself as Claude Code
- Default fallback when no other harness detected

## Paths

| Primitive | Local Path |
|-----------|-----------|
| Skills | `.claude/skills/` |
| Agents | `.claude/agents/` |

## Skill Loading Behavior

Claude Code uses progressive disclosure:
1. **Startup**: Reads `name` and `description` from every SKILL.md frontmatter
2. **Activation**: Loads full SKILL.md body when the skill is relevant
3. **References**: Loaded on-demand when the skill body references them

Budget impact: Each skill's `description` consumes from a ~16K char budget.
Keep descriptions concise. Use `disable-model-invocation: true` in frontmatter
for skills that should only be user-invoked (zero budget cost).

## DMI Support

Claude Code supports `disable-model-invocation: true` in SKILL.md frontmatter.
Skills with this flag:
- Can be invoked by the user via `/skill-name`
- Cannot be automatically activated by the model
- Cost zero description budget

When installing skills, preserve this frontmatter as-is from the Spellbook source.

## Post-Install

After installing skills, no additional configuration is needed for Claude Code.
Skills are detected automatically on next session start or when the context reloads.

If the user wants changes to take effect in the current session, they may need
to start a new conversation or use `/clear` to reload.
