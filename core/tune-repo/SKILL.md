---
name: tune-repo
disable-model-invocation: true
description: |
  Deeply specialize agents for a specific repository.
  Runs Glance (bottom-up directory summaries) + Cartographer (top-down architecture map),
  then synthesizes into CLAUDE.md, AGENTS.md, ADRs, and memory.
  Use when: onboarding to a new repo, improving agent effectiveness, repo setup, agent tuning.
---

# /tune-repo

Make agents deeply effective in this repository.

## Role

Staff engineer onboarding a new team member who happens to be an AI. Build the complete context an agent needs to work autonomously: what the project is, how it's built, what to watch out for, and how to ship.

## Objective

Transform a repository from "generic AI agent target" to "finely tuned agent workspace" where autonomous skills (/build, /autopilot, /pr-fix) operate with full project awareness.

## Philosophy

- CLAUDE.md is the constitution, not the encyclopedia. Keep it token-cheap.
- Policy in tracked files. State in memory. Procedures in skills.
- Granular summaries (Glance) feed system-level understanding (Cartographer).
- Document invariants, not obvious mechanics.
- Every gotcha captured now saves 10 agent iterations later.

## Preconditions

Verify the repo is ready:

```bash
git rev-parse --is-inside-work-tree  # Must be a git repo
git remote get-url origin            # Need remote context
```

Read what already exists — don't overwrite good work:

```bash
# Check for existing docs
ls CLAUDE.md AGENTS.md docs/CODEBASE_MAP.md docs/adr/ 2>/dev/null || true
```

## Workflow

### Phase 1: Glance Scan (Fast, Cheap)

Generate bottom-up per-directory summaries. This gives agents granular navigation context.

```bash
# Check if glance is available
which glance

# Run glance on the repo root
glance
```

Glance produces `.glance.md` in each directory. These are cheap to generate (uses Gemini Flash) and provide fine-grained "what's in this folder" context. Glance skips directories that already have a `.glance.md` by default — intelligent regeneration is built in, so never pass `-force`.

**If glance is not installed:** Skip this phase. Cartographer works without it — just slower and more expensive since Sonnet subagents read raw files.

### Phase 2: Cartographer (Comprehensive, Top-Down)

Invoke `/cartographer` to produce `docs/CODEBASE_MAP.md`.

Cartographer's Sonnet subagents will naturally discover and leverage the glance.md files from Phase 1, reducing the raw code they need to parse.

**If `docs/CODEBASE_MAP.md` exists and is recent:** Run Cartographer in update mode (it detects changes since `last_mapped` and only re-scans modified modules).

**Output:** System overview, architecture diagrams, module guide, data flow, conventions, gotchas, navigation guide.

### Phase 3: CLAUDE.md Audit + Update

Read the current CLAUDE.md (if any). Read the Cartographer output. Synthesize.

CLAUDE.md must cover — and ONLY cover — these sections:

1. **What This Is** — 2-3 sentences. Purpose, users, business context.
2. **Essential Commands** — dev, build, test, lint, deploy. Copy-pasteable.
3. **Architecture** — High-level module diagram or description. Link to CODEBASE_MAP.md for details.
4. **Tech Stack** — Languages, frameworks, databases, key dependencies with versions.
5. **Quality Gates** — What CI enforces: coverage thresholds, lint rules, type strictness. The exact commands.
6. **Gotchas** — Things that trip agents up. Earned-by-pain knowledge. Be specific.
7. **Environment** — Required env vars, secrets, external services.
8. **Deployment** — How code gets to production.

**Hard constraint: 200 lines max.** Every line must earn its place. Link to docs/ for details. If CLAUDE.md exceeds 200 lines, you're writing an encyclopedia, not a constitution.

**Preserve existing content** that's accurate. Don't rewrite good prose — merge new findings.

### Phase 4: AGENTS.md Scaffold

AGENTS.md is the operational playbook for AI agents. It covers what CLAUDE.md doesn't: how to work here.

Sections:

1. **Commit Conventions** — Message format, scope, conventional commits style.
2. **Testing Guidelines** — Framework, patterns, coverage targets, test location conventions.
3. **PR Guidelines** — Required sections, review expectations, merge strategy.
4. **Coding Style** — Beyond linting: naming patterns, module boundaries, abstraction philosophy.
5. **Issue Workflow** — Labels, status transitions, how to pick work.
6. **Definition of Done** — What "complete" means for an issue in this repo.
7. **Security Boundaries** — What agents must never touch without human approval.

**If AGENTS.md already exists:** Audit it against current reality. Fill gaps, correct drift.

**If it doesn't exist:** Create it. Pull conventions from git history (commit messages, PR descriptions) and existing CI config.

### Phase 5: ADR Inventory

Scan for undocumented architectural decisions:

```bash
# Check existing ADRs
ls docs/adr/ 2>/dev/null || mkdir -p docs/adr

# Look for decision signals in git history
git log --oneline --all --grep="decision\|migrate\|replace\|switch\|deprecat" | head -20

# Look for decision signals in code
# (framework choices, database selection, auth strategy, API design)
```

For each significant decision found without an existing ADR:

```markdown
# docs/adr/NNN-title.md

# NNN. Decision Title

Date: YYYY-MM-DD

## Status
Accepted

## Context
[Why was this decision needed?]

## Decision
[What was decided?]

## Consequences
[What are the implications — good and bad?]
```

Focus on decisions that would confuse a new agent:
- Why this framework/library over alternatives?
- Why this data model shape?
- Why this deployment strategy?
- Why this testing approach?

**Limit: 5 ADRs max per tune-repo run.** Don't boil the ocean. Capture the most impactful decisions.

### Phase 6: Memory Seeding

Extract project-specific gotchas into the auto-memory file:

```
~/.claude/projects/<escaped-repo-path>/memory/MEMORY.md
```

Good memory entries:
- CLI quirks specific to this project's toolchain
- API/service gotchas discovered in git history or issue tracker
- Flaky tests and their root causes
- Environment setup footguns
- Things that look wrong but are intentional

Bad memory entries:
- Anything already in CLAUDE.md (don't duplicate)
- Generic language/framework knowledge
- Temporary state (current branch, active PR)

### Phase 7.5: Guardrail Discovery

Analyze Cartographer output and codebase for architectural invariants worth enforcing as lint rules. Look for:

- **Import boundaries** — Are there modules that should only be accessed through a facade? (e.g., DB through repository, API through client)
- **Auth patterns** — Do handlers/routes consistently call an auth check? Any that don't?
- **Data access layers** — Is there a clear separation (controller → service → repository)? Violations?
- **API conventions** — Consistent route prefixes, response shapes, error formats?
- **Deprecated patterns** — Old imports, legacy APIs, patterns being migrated away from?
- **Naming conventions** — Beyond basic linting: domain-specific naming rules?

For each pattern found, output a recommendation:

```
Guardrail candidates:
- /guardrail "all DB access must go through repository layer" (3 violations found)
- /guardrail "API routes must use /api/v1 prefix" (0 violations — already clean, protect it)
- /guardrail "no direct fetch() — use apiClient wrapper" (7 violations found)
```

**Do NOT generate rules here.** `/guardrail` owns rule generation. This phase only discovers and recommends.

### Phase 8: Skill Gap Analysis

Assess whether this repo needs project-specific skills:

- Does it have a unique build/deploy pipeline that `/build` doesn't cover?
- Does it use a CLI tool that agents invoke frequently? (e.g., Cerberus uses `opencode`)
- Are there repetitive multi-step workflows specific to this domain?

If yes: document the gap as a recommendation. Don't build the skill in this run — that's a separate task.

```bash
# Report recommendation
echo "Skill gap: This repo could benefit from a custom /deploy-$REPO skill for [reason]"
```

## Anti-Patterns

- Writing CLAUDE.md as a novel (>200 lines = too long)
- Overwriting accurate existing docs with generated prose
- Creating ADRs for obvious decisions ("we use TypeScript because the project is TypeScript")
- Seeding memory with speculative information (verify against actual code/tests)
- Running Cartographer on a repo that was just mapped with no changes
- Generating AGENTS.md conventions that contradict what git history shows

## Output

Report:
- Glance: directories scanned, summaries generated
- Cartographer: CODEBASE_MAP.md created/updated
- CLAUDE.md: sections added/updated, final line count
- AGENTS.md: created or audited, sections covered
- ADRs: new ADRs created (list titles)
- Memory: entries seeded (list topics)
- Guardrail candidates: patterns recommended for `/guardrail`
- Skill gaps: recommendations (if any)
