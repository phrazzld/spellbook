# Autonomous Skill Creation

For agents that recognize skill-worthy knowledge and create skills proactively.

## Autonomy Model

**Create then inform**: When recognizing skill-worthy knowledge, create the skill
proactively, then inform the user what was created and why. Don't ask permission first.

## When to Invoke Proactively

1. **Successful novel solution** — Just solved something in a way worth repeating
2. **Repeated pattern** — Noticed doing the same thing multiple times
3. **Institutional knowledge** — Learning domain-specific rules that should persist
4. **User workflow** — User demonstrates a process they want automated
5. **Research findings** — Discovered best practices worth preserving

## Classify: Foundational vs Workflow

| Type | Characteristics | Frontmatter | Action |
|------|-----------------|-------------|--------|
| **Foundational** | Universal patterns, applies broadly, no explicit trigger | `user-invocable: false` | Add compressed summary to AGENTS.md |
| **Workflow** | Explicit trigger, action-oriented, user/model invokes | (default) | Skill only |

### If Foundational

1. Write skill as normal with `user-invocable: false`
2. Create 20-30 line compressed summary extracting core principles
3. Add summary to AGENTS.md "Passive Knowledge Index" section
4. Inform user: "Added to passive context — no invocation needed"

### If Workflow

1. Write skill as normal (default is invocable)
2. No AGENTS.md changes needed
3. Inform user of trigger terms

## AGENTS.md as Passive Knowledge Index

Foundational skills get compressed summaries in AGENTS.md so their principles
are always in context without requiring invocation. The full skill exists for
deep reference — AGENTS.md carries the compressed essence.

## After Creating

Tell the user:
- What skill was created and why
- What triggers will activate it
- How to test it works
