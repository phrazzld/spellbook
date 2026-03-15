---
name: skill
description: |
  Create or update agent skills. Quality gates, classification, structure,
  frontmatter, progressive disclosure, packaging, absorption lifecycle.
  Use when: "create a skill", "make this a skill", "update skill",
  "capture this as a skill", "skill engineering".
disable-model-invocation: true
argument-hint: "[create|update|absorb] [skill-name]"
---

# /skill

Create, update, or absorb agent skills.

## Process

### 1. Load Skill Engineering References

Read both references from the agent pack:

```
packs/agent/skill-builder/SKILL.md      — quality gates, classification, when to create
packs/agent/skill-creator/SKILL.md      — structure, frontmatter, packaging, how to create
```

If the agent pack isn't loaded locally, read directly from the repo paths above.

### 2. Quality Gates (from skill-builder)

Before creating any skill, pass all 4 gates:

1. **Reusable** — will this be used more than once?
2. **Non-trivial** — is this more than a one-liner for CLAUDE.md?
3. **Specific** — is this concrete enough to be actionable?
4. **Verified** — has this pattern been tested in practice?

If any gate fails, don't create the skill. Suggest the right home instead
(CLAUDE.md rule, hook, agent, memory).

### 3. Classify

| Type | Characteristics | Mode |
|------|----------------|------|
| **Core workflow** | Universal, used across all projects | Default or DMI |
| **Pack skill** | Domain-specific, project-contextual | Default in pack |
| **Reference** | Auto-loaded ambient context | `user-invocable: false` |

Most new skills should be **pack skills**, not core.

### 4. Create / Update (from skill-creator)

Follow skill-creator's process:
1. **Understand** — what problem does this solve?
2. **Plan resources** — SKILL.md body vs references/ for progressive disclosure
3. **Init** — create directory, write SKILL.md with frontmatter
4. **Edit** — write the skill body with routing table if umbrella
5. **Package** — add to appropriate pack or core
6. **Iterate** — test invocation, refine triggers

### 5. Absorption (if consolidating)

When absorbing a standalone skill into an umbrella:
1. Extract SKILL.md body → `references/{name}.md`
2. Merge any existing `references/` with parent prefix
3. Add routing entry to parent's SKILL.md
4. Delete old skill directory
5. Run `sync.sh all` to distribute

### 6. Distribute

```bash
./scripts/sync.sh all          # Core skills
./scripts/sync.sh index        # Rebuild pack index
```

## Anti-Patterns

- Creating core skills for domain-specific knowledge (use packs)
- Skipping quality gates because "it seems useful"
- Creating a skill that duplicates an existing one (check `/forage` first)
- Shallow skills that are just a checklist (prefer CLAUDE.md or a hook)
