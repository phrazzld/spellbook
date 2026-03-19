# Craft Skill

Focused workflow for creating or updating an agent skill.

## Process

### 1. Research First

**Mandatory for new skills.** A skill that restates what the model already knows is worthless.

Run `references/research-phase.md` before writing a single line of SKILL.md.

### 2. Init

```bash
scripts/init_skill.py <skill-name> --path <directory>
```

Scaffolds directory with SKILL.md template, example scripts/, references/, assets/.
Delete example files you don't need.

### 3. Write Frontmatter

The `description` field is for THE MODEL, not humans. It's the primary trigger signal.

- WHAT the skill does + WHEN to use it + keywords
- Third person, ~100 words, max 1024 characters
- Include explicit "Use when:" clauses
- See `references/description-patterns.md` for examples

### 4. Write Body

**SKILL.md is a tight index, NOT an encyclopedia.**

- 500 lines absolute max. Aim for <150 lines.
- Everything beyond routing logic goes to `references/` and `scripts/`
- If approaching 150 lines, extract to references
- Tables of contents, not walls of prose
- Same principle applies to AGENTS.md and all context-management docs

The filesystem hierarchy IS the architecture:

| Level | Token cost | Loaded when |
|-------|-----------|-------------|
| Metadata (name + description) | ~100 tokens | Always in context |
| SKILL.md body | <500 lines | On trigger |
| `references/` | Unlimited | On-demand |
| `scripts/` | Zero (executed) | Never loaded |

### 5. Validate

```bash
scripts/validate_skill.py <skill-directory>
```

Also verify manually:
- Metadata is concise and trigger-rich
- Body stays lean; detail pushed to `references/`
- No absolute paths unless runtime requires them
- Tool scope explicit when skill depends on special tools

### 6. Iterate from Real Usage

"Most skills started as a few lines and one gotcha." Ship minimal, observe
failures, add what's missing.

## Principles

1. **Don't state the obvious.** Only add what the model doesn't know. Challenge every paragraph: "Does this justify its token cost?"

2. **Build a gotchas section.** The most information-dense part of any skill. Accumulate from real failures.

3. **Use the filesystem.** Progressive disclosure IS the architecture: metadata → SKILL.md body → references/ → scripts/.

4. **Don't railroad the agent.** Match degrees of freedom to fragility. Open field = text instructions. Narrow bridge = exact scripts. Over-constraining kills reusability.

5. **Description field is for the model.** Primary trigger signal. Include "Use when:" clauses and keywords. Not a human-readable summary.

6. **Store scripts, don't generate code.** For deterministic operations, ship scripts in `scripts/`. They run without loading into context. Token-efficient and reliable.

7. **SKILL.md is a routing index.** Points at references for detail. Same principle applies to AGENTS.md and all context-management documents — they should evolve toward short punchy indexes.

8. **One level deep.** References link directly from SKILL.md. Never chain references → references.

9. **Avoid brevity bias in risky domains.** Compress aggressively for general doctrine, but high-failure domains need real mental models — don't compress into useless slogans.

10. **Iterate from real usage.** Ship minimal, observe failures, add what's missing.

## Command Surface Design

Default to concentrated, opinionated skills. Use arguments only when they
select between a few stable sub-capabilities inside one coherent domain.

Use arguments when ALL are true:
- The modes belong to one clear mental model
- The skill has one obvious no-arg happy path
- The modes share most artifacts, references, and scripts
- The selector list is short and stable

Split into separate skills when ANY are true:
- Modes have different trigger language
- Modes need different context packs or references
- Modes have different success criteria or outputs
- The core flow starts depending on flags, not intent words

Treat `argument-hint` as an intent router, not CLI help text.
