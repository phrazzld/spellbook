---
name: craft-primitive
description: |
  Create, update, or absorb agent primitives (skills and subagents).
  Quality gates, classification, structure, progressive disclosure,
  packaging, absorption lifecycle. Handles both skill and agent creation.
  Use when: "create a skill", "make this a skill", "update skill",
  "create an agent", "new subagent", "capture this as a skill",
  "skill engineering", "craft", "forge", "absorb skill".
argument-hint: "[create|update|absorb] [skill-name|agent-name]"
---

# /craft-primitive

Create, update, or absorb agent primitives (skills and subagents).

## Where Does This Primitive Live?

| Destination | When | Location | Marker |
|------------|------|----------|--------|
| **Spellbook** | Reusable across projects | `skills/{name}/` in spellbook repo | N/A (source) |
| **Project-local** | Specific to this project | Project-local skills dir (e.g. `.claude/skills/`, `.codex/skills/`) | **No `.spellbook` marker** |

**The `.spellbook` marker means "managed by focus, will be blown away on sync."**
Project-local skills must NOT have this marker.

- "Would another project ever use this?" → **Spellbook**
- "Is this specific to how THIS repo works?" → **Project-local**

## Quality Gates

Before creating any primitive, pass all 4:

1. **Reusable** — used more than once?
2. **Non-trivial** — more than a one-liner for AGENTS.md?
3. **Specific** — concrete enough to be actionable?
4. **Verified** — tested in practice?

If any gate fails → suggest the right home: AGENTS.md rule, hook, agent definition, or memory.

## Classify

| Type | Characteristics | Mode |
|------|----------------|------|
| **Global** | Meta-process, useful everywhere (focus, research, calibrate, reflect, craft-primitive) | Non-DMI (must be chainable) |
| **Distributable** | Domain or workflow skill, useful across projects | Default or DMI |
| **Project-local** | This-repo-only workflow | DMI typically |

## Routing

| Intent | Reference |
|--------|-----------|
| Create/update a skill | `references/craft-skill.md` |
| Create/update an agent/subagent | `references/craft-subagent.md` |
| Research before building | `references/research-phase.md` |
| Absorb skills into umbrella | `references/absorption.md` |
| Proactive skill creation (autonomous) | `references/autonomous-creation.md` |
| Writing good descriptions | `references/description-patterns.md` |
| Skill structure and anatomy | `references/structure-guide.md` |
| Common anti-patterns | `references/anti-patterns.md` |

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/validate_skill.py <dir>` | Validate skill structure, frontmatter, line counts |
| `scripts/init_skill.py <name> --path <dir>` | Scaffold a new skill directory from template |
| `scripts/package_skill.py <dir> [out]` | Validate + package into distributable `.skill` file |

## Anti-Patterns

- Creating spellbook skills for project-specific knowledge
- Adding `.spellbook` markers to project-local skills (focus will delete them)
- Skipping quality gates because "it seems useful"
- Creating a skill that duplicates an existing one (search embeddings first)
- Shallow skills that are just a checklist (prefer AGENTS.md or a hook)
- Skipping the research phase — skills without research are reformatted training data
- Writing generic advice the model already knows instead of specific, hard-won knowledge
- Building mini-CLIs into `argument-hint` instead of keeping one happy path
- Monolithic SKILL.md that restates what the model knows (see `references/anti-patterns.md`)
