# Critic Checklist — /focus postmortem

The critic runs once in `/tailor` Phase 3 against every artifact the
planner proposes. One round. No loop. If the critic issues any
blocking objection, /tailor aborts before writing a single file.

This is **the** guardrail against repeating `/focus`. /focus shipped
71 commits over two months before being killed in March 2026. Its
failures are well-known and structural — this checklist encodes the
four that matter.

Apply each criterion in order. First rejection wins; stop evaluating.

---

## 1. Does this already exist globally?

**Reject if yes.** Global spellbook primitives (`groom`, `shape`,
`deliver`, `flywheel`, `code-review`, `settle`, `reflect`, `harness`,
`tailor`) and the philosophy bench (`beck`, `carmack`, `grug`,
`ousterhout`, `planner`, `critic`) are canonical. The user already
has them. Adding a project-local copy is either dead weight
(identical content) or silent divergence (subtly different content
that breaks the cross-harness contract).

**Reject examples:**
- `.claude/skills/code-review/` (global exists)
- `.claude/agents/planner.md` (global exists)
- A local `/shape` variant because "our team thinks about shaping differently"

**Allow examples:**
- `.claude/skills/rust-migrations/` (no global equivalent)
- Repo-specific AGENTS.md content pointing *to* the global skill

**Why it matters.** /focus installed 87 candidate skills per repo,
including near-duplicates of already-global ones. Users couldn't
tell which was authoritative. The tailor-lint.sh shadow check
enforces this structurally for MVP skill dirs; the critic extends
the same rule to agents, hooks, and AGENTS.md sections.

## 2. Would a scaffold-on-demand skill cover it?

**Reject if yes.** `/qa scaffold`, `/demo scaffold`, and similar
global skills already generate repo-specific scaffolding at invocation
time. If the proposed tailored artifact is something a scaffold skill
would produce, don't bake it in ahead of time — let the scaffold skill
run when the user asks.

**Reject examples:**
- A tailored `/qa` that hardcodes this repo's test golden paths
  (the global `/qa scaffold` does this on demand)
- A static demo script (the global `/demo` scaffold generates it)

**Allow examples:**
- An `AGENTS.md` pointer saying "run `/qa scaffold` to regenerate
  test paths after schema changes"
- A `settings.local.json` permissions entry that enables the
  scaffold skills to work without permission prompts

**Why it matters.** /focus pre-installed 87 skills, most unused in
any given repo. Scaffold-on-demand skills don't cost anything when
unused — they only run when invoked. Baking their output into
project-local files accumulates stale state that no one refreshes.

## 3. Is this 1-3 focused, or 41-auditor ceremony?

**Reject if the proposal grows past 2 tailored skills in MVP.**
tailor-lint.sh enforces the cap structurally, but the critic should
also reject *qualitative* ceremony — e.g., a single skill that tries
to do the work of 10, or a cluster of near-duplicate reviewers.

**Reject examples:**
- Four separate reviewer agents for slightly different Rust concerns
  (`unsafe-reviewer`, `lifetime-reviewer`, `trait-bound-reviewer`,
  `generic-reviewer`) when one `rust-reviewer` would do
- A monolithic `project-skill.md` that handles tests + migrations +
  deployment + review (too-big skill)

**Allow examples:**
- One focused `rust-unsafe-reviewer` agent if this repo has unusual
  `unsafe` patterns that justify a dedicated reviewer
- A `<repo>-migrations` skill with sharp scope: "generate and apply
  SQL migrations following our conventions"

**Why it matters.** /focus shipped 41 domain auditors. Users
couldn't remember what any of them did. Choice paralysis replaced
judgment. The MVP cap of 2 skills is deliberately low to force
the critic and planner to pick the highest-leverage specialization
rather than everything-everywhere.

## 4. Can this artifact's value be proven in Phase 5?

**Reject if the artifact wouldn't plausibly affect the A/B eval.**
Phase 5 runs a canned task in baseline vs. tailored worktrees and
measures `tool_calls`, `wall_s`, `passed`. Every generated artifact
must pass the question: "would removing this file measurably change
the outcome of the canned task?" If the honest answer is no, reject.

**Reject examples:**
- A detailed `ARCHITECTURE.md` about the repo's history (doesn't
  change agent tool-use patterns)
- A `CONTRIBUTING.md` for humans (the agent doesn't read it
  during tool execution)
- Nice-to-have documentation the agent would read but not act on

**Allow examples:**
- `AGENTS.md` "build/test commands" section — changes which Bash
  invocations the agent runs, measurable via tool_calls/wall_s
- `settings.local.json` permissions — eliminates permission prompts,
  measurably reduces wall time
- A hook that runs the linter after edits — adds/removes tool_calls

**Why it matters.** /focus had no killswitch. Artifacts were
installed on faith that they'd help. /tailor's entire differentiator
is that every artifact must pay rent in the A/B. The critic's job
is to reject artifacts that structurally *cannot* pay rent, before
they get written.

---

## Stopping condition

The critic emits a list of blocking objections (possibly empty).
/tailor Phase 3 proceeds iff the list is empty. **No round 2.**
That's where /focus rotted — every round loosened the bar until the
bar was gone.

If the critic blocks, the planner's proposal is returned with the
objections noted, and /tailor exits non-zero before Phase 4. The
user can re-run /tailor with different inputs or adjust the planner's
instructions; they cannot appeal the critic.
