# CLAUDE.md

## What This Repo Is

**Spellbook** — 8 workflow skills, 7 agents, and harness infrastructure for
AI-assisted software development. One repo. All harnesses.

Not a prompt library. Codified engineering judgment.

## Philosophy

See `SPEC.md` for the full vision. See `harnesses/shared/principles.md` for
engineering doctrine shared across all harnesses.

Core: the harness is the product. Strip what's not load-bearing. Separate
generator from evaluator. Fix the system, not the instance.

## Structure

```
spellbook/
├── skills/           # 8 workflow skills (autopilot, code-review, debug,
│                     #   groom, harness, reflect, research, shape)
├── agents/           # 7 agents (planner, builder, critic,
│                     #   ousterhout, carmack, grug, beck)
├── harnesses/        # Per-harness configs (claude/, codex/, pi/, etc.)
│   ├── shared/       #   Common doctrine
│   └── claude/       #   settings.json, hooks/, CLAUDE.md
├── scripts/          # Shared tooling
├── registry.yaml     # Single source of truth
├── bootstrap.sh      # Installs globals to harness dirs
└── SPEC.md           # Full lifecycle vision
```

## The 8 Skills

| Skill | Purpose |
|-------|---------|
| `autopilot` | Full delivery: plan→build→review→ship |
| `code-review` | Parallel multi-agent review, auto-fix loop |
| `debug` | Investigate, triage, fix |
| `groom` | Backlog management, brainstorming, rethink, scaffold |
| `harness` | Skill engineering, primitive management, context lifecycle |
| `reflect` | Session retrospective, learning extraction, harness postmortem |
| `research` | Multi-source web research, delegation, think tank |
| `shape` | Spec/design → context packet output |

## The 7 Agents

**GAN triad:** planner (spec), builder (implement), critic (evaluate)
**Philosophy bench:** ousterhout (depth), carmack (ship), grug (simplicity), beck (TDD)

## Workflow

```
backlog.d/ → /groom → /shape (planner) → /autopilot (builder) → /code-review (critic + bench) → ship
```

## Backlog: backlog.d/

File-driven. One markdown file per item. Each has: goal, non-goals, oracle.

## Adding a Skill

1. Create `skills/{name}/SKILL.md` with frontmatter
2. Keep it < 200 lines. Encode judgment, not procedures.
3. Commit and push — pre-commit hook regenerates index.yaml

## Principles

- **Flat over nested** — every skill at `skills/{name}/`
- **8 skills, 7 agents** — resist expansion
- **Strip non-load-bearing complexity** — stress-test every component
- **File-driven** — backlog.d/, not GitHub Issues
- **Progressive disclosure** — description → SKILL.md → references
