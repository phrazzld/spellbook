# Pi Bootstrap Report

- Domain: agent-skills
- Repo: /Users/phaedrus/Development/agent-skills
- Generated: 2026-03-02T15:52:10.837Z
- Package manager: unknown
- Stack hints: none

## Notes
- Fallback plan used because synthesis was unavailable or invalid.

## Repository Context Digest
contextSnippets:
[CLAUDE.md]
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A unified skills monorepo (~74 skills) for multi-model AI agents (Claude, Codex, Gemini, Factory, Pi). Markdown-first (with helper scripts) — no application code, no tests, no CI. Skills are distributed to agent harnesses via symlinks.

## Repo Structure

```
agent-skills/
├── core/           # ~74 skills, synced to ~/.claude/skills/
│   ├── groom/
│   ├── autopilot/
│   ├── build/
│   └── ...
├── packs/          # Domain packs, loaded per-project on demand
├── scripts/
│   └── sync.sh
└── CLAUDE.md
```

## Key Commands

```bash
# Sync core skills to agent harnesses
./scripts/sync.sh claude            # → ~/.claude/skills/
./scripts/sync.sh codex             # → ~/.codex/skills/ (skips .system)
./scripts/sync.sh gemini            # → ~/.gemini/skills/
./scripts/sync.sh all               # All harnesses
./scripts/sync.sh claude --dry-run  # Preview without changes

# Prune stale symlinks (for deleted skills)
./scripts/sync.sh --prune claude
./scripts/sync.sh --prune all

# Load a domain pack into a project
./scripts/sync.sh pack marketing ~/Development/myproject
./scripts/sync.sh pack marketing --global
```

No build, lint, or test commands — this repo is documentation only.

## Skill Directory Convention

Every skill lives in `core/{skill-name}/` with a required `SKILL.md`:

```
core/{skill-name}/
├── SKILL.md          # Required. Frontmat

.claude inventory:
(none)

.codex inventory:
(none)

.pi inventory:
.pi/state/session-handoff.json, .pi/state/session-handoff.ndjson

scripts inventory:
scripts/sync.sh

## Single Highest-Leverage Addition
- Idea: Establish a minimal planner -> worker -> reviewer local workflow loop that compounds repo familiarity through memory-first context reuse.
- Source lane: ambition-pass
- Why now: This creates immediate throughput gains with low maintenance while preserving room for optional advanced overlays.
- 72h validation experiment: Run this bootstrap on two active tasks, then compare plan-to-merge latency and rework churn against the prior baseline.
- Kill criteria: If cycle time or defect/rework metrics worsen by more than 15%, roll back to prior local config and revisit assumptions.

## Lane Evidence
## repo-scout
- model: openai-codex/gpt-5.3-codex
- thinking: xhigh
- status: ok
- elapsed: 11s

(no output)

---

## context-bridge
- model: openrouter/anthropic/claude-sonnet-4.6
- thinking: high
- status: ok
- elapsed: 72s

Now I have a complete picture. Here's the analysis:

---

## Existing Context Signals

### CLAUDE.md (primary context file)
- Authoritative repo orientation: ~74 skills, Markdown-first, no code/tests/CI
- Documents 3 invocation modes + budget model (critical architecture constraint)
- Core delivery pipeline: `groom → shape → autopilot → pr-fix → pr-polish → merge`
- Skill directory convention (`SKILL.md` frontmatter, no `README.md`)
- Sync workflow: `./scripts/sync.sh {claude|codex|gemini|pi|all}`
- Principles: deep modules, compose-don't-duplicate, budget-aware, agent-agnostic

### `scripts/sync.sh`
- Pi target is **already wired**: `do_pi()` syncs 4 shared skills (`agent-browser`, `dogfood`, `skill-creator`, `design`) to `~/Development/pi-agent-config/skills`
- That Pi path (`pi-agent-config`) is a separate repo — this repo feeds into it, not directly into `~/.pi/`
- Prune logic for all harnesses (Pi not included in prune, only sync)

### `.pi/` state
- Only `state/session-handoff.json` + `.ndjson` — session just started, no notes/prior tools
- No `AGENTS.md`, no Pi-specific config, no commands, no extensions

### `core/` skill inventory
- 83 total skills, 48 DMI, 14 reference (auto-load), ~21 model+user
- Pi-native skills already live here: `agentic-bootstrap`, `organic-reflection`, `skill-builder`, `skill-creator`
- `thinktank`, `delegate`, `agent-browser`, `dogfood`, `llm-communication` — high Pi relevance
- `llm-semantic-match.md` at repo root — a reference doc/pattern, not a skill

### What's absent
- No `AGENTS.md` at repo root (contrast: CLAUDE.md exists)
- No `.pi/AGENTS.md` or `.pi/config`
- Pi harness path points to an external repo, not `~/.pi/agent/skills/`
- `packs/` is empty — documented feature with no current content

---

## Adopt / Bridge / Ignore Decisions

| Signal | Decision | Rationale |
|--------|----------|-----------|
| **CLAUDE.md content** | **Adopt → AGENTS.md** | The repo orientation, skill conventions, budget model, and pipeline are…

---

## docs-research
- model: openrouter/google/gemini-3.1-pro
- thinking: high
- status: ok
- elapsed: 130s

## High-Value References

- **Anthropic Prompt Engineering Guide**  
  **URL**: [https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview)  
  **Why it matters**: Claude is a primary harness for this monorepo. Anthropic emphasizes using XML tags and treating the model as a collaborator rather than using overly defensive, brittle negative constraints (e.g., "Do NOT do X").

- **Agent Skills Specification**  
  **URL**: [https://agentskills.io/specification](https://agentskills.io/specification)  
  **Why it matters**: Pi explicitly implements this standard. To ensure progressive disclosure works (where only the description sits in context and the file is `read` lazily), `SKILL.md` frontmatter must strictly adhere to naming (lowercase, ≤64 chars) and description limits (≤1024 chars).

- **Google Gemini Prompting Strategies**  
  **URL**: [https://ai.google.dev/gemini-api/docs/prompting-strategies](https://ai.google.dev/gemini-api/docs/prompting-strategies)  
  **Why it matters**: Because skills mirror across multi-model harnesses (Claude, Codex, Gemini, Pi), prompting must focus on objective-based output contracts over model-specific step-by-step scripting to gracefully degrade across underlying reasoning engines.

- **OpenAI Structured Outputs Guide**  
  **URL**: [https://developers.openai.com/api/docs/guides/structured-outputs](https://developers.openai.com/api/docs/guides/structured-outputs)  
  **Why it matters**: Instructs how to design deterministic format contracts that prevent "prompt drift" and eliminate the need for multi-pass retry logic on synthesis tasks.

## Practical Implications for Agentic Workflow

1. **Adopt "Role + Objective + Latitude" over Micromanagement**  
   Replace massive procedural checklists with a clear objective and explicit latitude. Instead of writing 50 steps of how to perform an audit, state: *"You're a senior SRE. Find root c…

---

## workflow-critic
- model: openrouter/anthropic/claude-sonnet-4.6
- thinking: high
- status: ok
- elapsed: 235s

---

## Critical Failure Modes

### 1. Budget cliff — silent skill drops at 96.5% capacity
**Evidence:** 77 skills currently synced to `~/.claude/skills` consume ~15,451 of 16,000 description chars (96.5%). The README claims 12 DEFAULT (budget-consuming) skills; actual count is **21**. The 8 skills not yet synced to Claude (`agentic-bootstrap`, `github-cli-hygiene`, etc.) are DEFAULT mode — adding them would almost certainly overflow the budget and cause Claude to silently drop skills with no warning. This is the exact failure the repo was designed to prevent, and the design has already drifted past its own safety margin.

### 2. Pi skills are copies, not symlinks — silent divergence in production
**Evidence:** 10 of 17 pi-agent-config skills are filesystem copies (`COPY: agentic-bootstrap`, `COPY: pr-polish`, `COPY: skill-builder`, etc.). `sync.sh do_pi()` only manages 4 of the 17. Three are already demonstrably diverged:
- `agentic-bootstrap`: pi copy still has the old `.pi/persona.md` pattern; core/ has the updated AGENTS.md-first architecture — the two emit **contradictory instructions** to operators.
- `pr-polish`: pi copy has a different description, different title, different framing.
- `skill-builder`: pi copy has `effort: high` frontmatter field and different invocation language.

Pi agents are running stale, partially-overwritten skill contracts. Fixes applied in this repo don't reach Pi.

### 3. `deploy` uses a non-standard frontmatter key — escapes DMI classification
**Evidence:** `core/deploy/SKILL.md` line 9: `model-invocable: false`. The valid key is `disable-model-invocation: true`. No harness recognizes `model-invocable: false` — it's silently ignored, making `deploy` a **DEFAULT (budget-consuming) skill** when the author intended DMI. This miscounts the budget and can cause Claude to autonomously invoke deploy workflows.

### 4. Stale sync is undetectable — no freshness enforcement
**Evidence:** `sync.sh` has no `--check` or `--diff` mode. The 8 s…

---

## ambition-pass
- model: openrouter/google/gemini-3-flash-preview
- thinking: high
- status: ok
- elapsed: 33s

## Foundation Workflow Pattern

The `agent-skills` repository is unique because its product is **agent capability itself**. The foundation must treat "Instructions as Code" with the same rigors as a software library: validation, optimization, and distribution.

1.  **Instruction-as-Code Audit:** Instead of manual counting, use a meta-skill to audit the "Instruction Budget" (Claude's 16k char limit).
2.  **Density Optimization:** Systematically move verbose, non-essential instructions from "Model+User" (always loaded) to "DMI" (user-invoked) to maximize the "intelligence density" of the active context.
3.  **Cross-Harness Validation:** Ensure a skill written for Claude doesn't break formatting or expectations for Gemini or Codex.

## Prompt + Pipeline Ideas

*   **The Skill Distiller Pipeline:** `Collect Execution Log` -> `Identify Redundancy` -> `Shrink SKILL.md`. Uses the `distill` philosophy to shorten skills while preserving their performance.
*   **The "Budget Sentry" Hook:** A pre-commit or post-sync check that calculates the total character count of all `user-invocable: true` and `reference` skills, failing if it exceeds 14k chars (leaving buffer).
*   **Skill Performance Heatmap:** A simple tracker of which skills are actually used during a session, suggesting the "archival" (DMI-ification) of unused skills to save budget.

## Minimal Viable Bootstrap vs Optional Upgrades

| Feature | Status | Description |
| :--- | :--- | :--- |
| **Repo Persona (`.pi/persona.md`)** | **Must-Have** | Defines the "Skill Architect" role: objective is max utility per character. |
| **Budget Auditor (`/audit-budget`)** | **Must-Have** | Quantifies the 16k char constraint. Essential for monorepo health. |
| **Sync Script (`scripts/sync.sh`)** | **Existing** | Handles distribution. Works well, keep as-is. |
| **Synthetic Test Lab** | Optional | Simulates agent runs with a skill to "verify" logic without real code. |
| **Multi-Agent Simulation** | Optional | Checks if Claude handl…

---

## implementation-critic
- model: openrouter/anthropic/claude-sonnet-4.6
- thinking: xhigh
- status: ok
- elapsed: 191s

Now I have enough signal. Here's the full pressure-test report:

---

## Durability Risks

### 1. Count/budget claims are stale and wrong
README and CLAUDE.md both state "12 model-invocable + 14 references + 48 DMI = 74 total. Budget usage: 45%." Actual counts: **21 model+user + 14 ref + 48 DMI = 83 total**. Budget-consuming descriptions total ~8,885 chars (~56% of 16K), not 45%. Both documents will become increasingly wrong as skills are added. There is no automated check to keep these numbers honest.

### 2. `observability` skill references a ghost dependency (`sentry-observability`)
Eight lines in `core/observability/SKILL.md` call `~/.claude/skills/sentry-observability/scripts/*.sh`. The skill `sentry-observability` does not exist in this repo, so those scripts are absent at any harness unless independently installed. An operator following the skill's instructions will get `No such file or directory` with no diagnostic. The `sentry.md` reference doc exists; the scripts do not.

### 3. `og-hero-image` depends on a non-existent skill (`gemini-imagegen`)
Two script invocations in `og-hero-image/SKILL.md` target `~/.claude/skills/gemini-imagegen/scripts/`. That skill is not in this monorepo. No fallback or warning is in the skill body. The skill will silently fail for any user who doesn't happen to have that skill from elsewhere.

### 4. Hardcoded `phrazzld` GitHub handle in three delivery skills
`build/SKILL.md`, `pr/SKILL.md`, and `autopilot/SKILL.md` all hardcode `--assignee phrazzld` in GitHub CLI commands. Any operator who isn't `phrazzld` will silently mis-assign or fail if the handle doesn't exist in their org.

### 5. `ousterhout` agent is invoked but undefined
`autopilot/SKILL.md` and `build/SKILL.md` both call `ousterhout agent for module depth review`. There is no `ousterhout` skill in `core/`, no `~/.codex/agents/` reference documented here, and no fallback. This will confuse operators or silently no-op.

### 6. `do_pi` sync is a hardcoded four-skill li…

## Quality Gate Scorecard
- Gate pass: yes
- Ambition score: 85/100 (pass)
  - novelty: 5/5
  - feasibility: 4/5
  - evidence: 5/5
  - rollbackability: 3/5
- Consensus score: 96/100 (pass)
