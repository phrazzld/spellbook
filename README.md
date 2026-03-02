# Agent Skills

74 deep skills for AI coding agents. Works with Claude Code, Codex, Gemini, Factory, and Pi.

Skills are Markdown-first with a handful of Python helper scripts. No application code, no dependencies. They teach agents *how to work*: debugging methodology, PR workflows, design systems, incident response, and dozens of domain-specific playbooks.

## Why

AI agents are only as good as their instructions. Generic prompts produce generic work. These skills encode opinionated, battle-tested workflows that turn agents into effective teammates.

**The budget problem:** Claude Code allocates ~16K chars for skill descriptions. Naive skill libraries overflow this budget and most skills get silently dropped. This repo solves it with three invocation modes:

| Mode | Triggered by | Budget cost |
|------|-------------|-------------|
| **Model+User** | Agent decides or user invokes | Consumes budget |
| **Reference** | Auto-loaded when relevant | Consumes budget |
| **DMI** | User only (`/command`) | **Free** |

Current split: 12 model-invocable + 14 references + 48 DMI = 74 total. Budget usage: 45%.

## Quick Start

```bash
git clone https://github.com/phrazzld/agent-skills.git
cd agent-skills

# Sync to your agent harness
./scripts/sync.sh claude    # → ~/.claude/skills/
./scripts/sync.sh codex     # → ~/.codex/skills/
./scripts/sync.sh all       # All harnesses

# Preview without changes
./scripts/sync.sh claude --dry-run

# Remove stale symlinks after updates
./scripts/sync.sh --prune all
```

Skills are symlinked, not copied. Edit once, every harness sees the change.

## Skills

### Delivery Pipeline

| Skill | Mode | Description |
|-------|------|-------------|
| `/groom` | DMI | Backlog grooming, health checks, hygiene |
| `/shape` | DMI | Product + technical planning (absorbs spec, architect, brainstorming) |
| `/autopilot` | Model+User | Autonomous delivery: shape → build → commit → PR |
| `/build` | Model+User | Implementation with TDD workflow |
| `/commit` | DMI | Semantic commits with quality gates |
| `/pr` | DMI | PR creation with mandatory sections |
| `/pr-fix` | Model+User | Unblock PRs: conflicts, CI, review feedback, refactoring |
| `/pr-polish` | Model+User | Hindsight review and quality elevation |

### Quality & Debugging

| Skill | Mode | Description |
|-------|------|-------------|
| `/check-quality` | DMI | Audit quality gates: tests, CI, hooks |
| `/debug` | Model+User | Four-phase systematic debugging |
| `/test-coverage` | DMI | TDD workflow, Vitest config, coverage audit |
| `/distill` | Model+User | Repo knowledge distillation and session codification |
| `/done` | DMI | Session retrospective and codification |
| `/triage` | Model+User | Incident response → postmortem → verification |

### Audit / Fix / Log

Three unified skills replace 36 domain-specific check/fix/log skills:

```bash
/audit stripe           # Audit any domain
/fix docs               # Fix issues (model-invocable for autonomous work)
/log-issues production  # Create GitHub issues from findings
```

Domains: bitcoin, btcpay, bun, docs, landing, lightning, observability, onboarding, payments, posthog, product-standards, production, stripe, virality.

### Design & Brand

| Skill | Mode | Description |
|-------|------|-------------|
| `/design` | Model+User | Full design system: tokens, exploration, Vercel patterns |
| `/brand` | DMI | Brand-as-code: discovery → tokens → assets → video |
| `/content` | DMI | Write, edit, explore, publish, humanize |
| `/growth` | DMI | Marketing, SEO, CRO, analytics, pricing |

### Payments & Infrastructure

| Skill | Mode | Description |
|-------|------|-------------|
| `/stripe` | DMI | Complete Stripe lifecycle management |
| `/changelog` | DMI | Changelog infrastructure and automation |
| `/security-scan` | DMI | Whole-codebase vulnerability analysis |
| `/sysadmin` | DMI | System health checks |
| `database` | Reference | Schema design, migrations, Convex patterns |

### AI & Media

| Skill | Mode | Description |
|-------|------|-------------|
| `/llm-infrastructure` | Model+User | LLM evaluation, gateway routing, prompt ops |
| `/ai-media` | DMI | Image/video generation (FLUX, Veo, Remotion, etc.) |

### Browser & QA

| Skill | Mode | Description |
|-------|------|-------------|
| `/agent-browser` | Model+User | Playwright CLI for AI agents |
| `/dogfood` | DMI | Exploratory QA with repro evidence |
| `/visual-qa` | Model+User | Pre-commit visual regression |
| `/flywheel-qa` | DMI | PR verification on preview deploys |
| `webapp-testing` | Reference | Playwright test patterns |

### References (auto-loaded)

`git-mastery` · `naming-conventions` · `external-integration-patterns` · `ui-skills` · `business-model-preferences` · `toolchain-preferences` · `next-patterns` · `database` · `delegate` · `cli-reference` · `ralph-patterns` · `skill-builder` · `agentic-ui-contract` · `webapp-testing`

### Domain Tools (DMI)

`bitcoin` · `lightning` · `posthog` · `bun` · `observability` · `stripe` · `crypto-gains` · `tax-check` · `finances-*` · `moneta-*` · `pencil-*` · `thinktank` · `tune-repo` · `guardrail` · `issue` · `og-hero-image` · `audit-website` · `visualize` · `agent-tools` · scaffolds (`mobile-migrate`, `monorepo-scaffold`, `slack-app-scaffold`, `github-app-scaffold`)

## Anatomy of a Skill

```
core/debug/
├── SKILL.md              # Frontmatter + skill definition
└── references/
    ├── investigation.md   # Absorbed from /investigate
    └── systematic.md      # Absorbed from /systematic-debugging
```

`SKILL.md` frontmatter:

```yaml
---
name: debug
description: |
  Investigate local development issues: test failures, type errors,
  runtime bugs, build problems. Use when something is broken and you
  need to find the root cause. Not for production incidents (use /triage).
---
```

## Adding a Skill

1. Create `core/{name}/SKILL.md` with frontmatter
2. Choose mode: default (model+user), `disable-model-invocation: true` (DMI), or `user-invocable: false` (reference)
3. Run `./scripts/sync.sh all`

## Principles

- **Deep modules** — hide complexity behind simple interfaces
- **Compose, don't duplicate** — orchestrators call primitives
- **Budget-aware** — use DMI for user-only workflows
- **Agent-agnostic** — works across Claude, Codex, Gemini, Pi

## License

MIT
