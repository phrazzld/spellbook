---
name: tailor
description: |
  Tailor this repository's harness. Explore the repo, read prior
  session history, browse the spellbook catalog, and install a
  per-repo set of skills and agents in .claude/. Workflow skills get
  rewritten with this repo's commands and conventions embedded
  throughout — not a generic body with a repo-notes appendix.
  Use when: "tailor this repo", "configure the agent for this codebase",
  "set up a harness", "what skills apply here". Trigger: /tailor.
---

# /tailor

You're a tailor, not a wardrobe curator. Spellbook is a reference
library — fabric bolts, pattern drafts, technique books. For this
repo you *cut new garments* from that material, sized to fit in
every seam. Sewing an extra inch onto an off-the-rack jacket is not
tailoring; it's decoration.

## Shape of the work

1. **Explore.** Read enough of this repo to know what it is —
   language, frameworks, test/CI/deploy commands, size, domain.
   `package.json` / `Cargo.toml` / `pyproject.toml`, README, top-level
   structure.

2. **Prior art.** If your harness keeps session history for this repo
   (Claude Code: `~/.claude/projects/<path-hash>/`, Codex: analogous
   state path), read the session JSONL and memory files. What
   commands does the user actually run here? Where have they
   corrected you? Highest-signal input available.

3. **Browse.** Read the spellbook catalog — resolve via `readlink -f`
   on this SKILL.md, walk up to find `$SPELLBOOK/skills/` and
   `$SPELLBOOK/agents/`. Each primitive's frontmatter describes when
   to use it. That's your map.

4. **Synthesize a repo brief.** Write a short prose document
   (1-2 pages) that every downstream subagent will read. It is
   the shared spine that keeps rewrites coherent — without it,
   `/ci` calls the enforcing layer one thing and `/deliver` calls
   it another. Required anchors:

   - **Vision & purpose** — what this repo is building, for whom.
   - **Stack & boundaries** — layers and what each owns.
   - **Load-bearing gate** — *the* single declaration of what must
     pass to ship (e.g. "`pnpm ci:prepush` IS the gate; the Dagger
     lanes are its components"). Every gate-adjacent skill cites
     this verbatim.
   - **Invariants** — repo-wide rules (don't touch X, base branch
     is Y, commits go through Z).
   - **Known debts** — active issues, hot files, recurring failure
     modes, incident IDs. Pull from backlog, session history, and
     recent git log.
   - **Terminology** — what this repo calls its things.
   - **Session signal** — 3-5 recurring user corrections from
     session JSONL + 3-5 validated patterns the user has ratified.

   Short, dense, concrete. This is the single source of truth for
   "what is this repo" that every rewriter anchors to.

5. **Pick.** Dispatch planner + critic subagents with the repo
   brief attached. Planner proposes a set following the picking
   defaults below; critic applies `references/focus-postmortem.md`.
   One round. Stop on critic-clear.

6. **Install.** Three categories, different rules:

   - **Universal skills** — `research`, `groom`, `office-hours`,
     `ceo-review`, `reflect`, and similar that carry no repo-specific
     judgment. Copy their directories verbatim. Tailoring them would
     be artificial.
   - **Workflow skills** — `deliver`, `shape`, `implement`,
     `code-review`, `ci`, `refactor`, `qa`, `flywheel`, `deploy`,
     `monitor`, `diagnose`, `settle`, `yeet`. **Rewrite each SKILL.md
     with this repo's commands, gates, conventions, and file paths
     embedded throughout.** Use the spellbook version as structural
     reference; fill every example, every command, every gotcha with
     repo-specific content. Preserve `references/` and `scripts/`
     from the source — they travel with the skill.

     **Dispatch one rewriter subagent per workflow skill, in
     parallel.** Monolithic rewriting of 10+ skills in one context
     causes attention decay — the model pattern-matches "just copy
     this one too" and ships byte-identical output. Each rewriter
     receives: (a) the repo brief from step 4 (shared spine —
     cite these anchors, don't invent parallel vocabulary),
     (b) the spellbook source, (c) a domain-specific reading
     assignment (`/ci` reads `.github/workflows/` + dagger config;
     `/diagnose` reads evidence logs + postmortems; `/deliver`
     reads `backlog.d/` + recent merged PRs), (d) the mandate
     above.

     **Critic reviews all rewrites together, not individually.**
     Three checks: (1) **depth** — subtractive test, would this
     rewrite be wrong if applied to another repo with the same
     stack? If no, it's shallow — reject; (2) **cohesion** — does
     every gate-adjacent skill cite the same load-bearing gate
     from the repo brief? Any contradiction against repo brief or
     sibling skills → reject; (3) **completeness** — byte-identical
     to spellbook source → reject. Critic sends specific rewriters
     back with specific objections. Iterate until coherent. Up to
     3 rounds; critic judges convergence.
   - **Domain skills (invented)** — greenfield additions like
     `/convex-migrate`, `/rust-unsafe-reviewer`. Only invent when you
     can name the concrete repo characteristic demanding it.

7. **Write `AGENTS.md`.** Project the repo brief + the coherent
   rewrite set into a router (not a manual). Suggested structure:
   - **Stack & boundaries** — stack names and what each layer owns.
   - **Ground-truth pointers** — files that ARE the API (e.g.
     `convex/_generated/api.d.ts`); stale training data lies.
   - **Invariants** — hard rules specific to this repo (functions,
     env vars, schema constraints, auth flows).
   - **Gate contract** — cite the load-bearing gate from the repo
     brief; enumerate pre-commit hooks, what humans do, what's
     enforced where.
   - **Known-debt map** — concrete file/line pointers. Every P0
     debt item gets a filed issue ID, not `(unfiled)`.
   - **Harness index** — table: installed skill → what it does
     *here* (not the generic description). Agents in a sibling
     table, not a prose sentence.

8. **Write `.claude/settings.local.json`.** Permissions allowlist
   derived from the tools actually in use.

## Invariants

- Never write outside the current repo. No `$SPELLBOOK` mutation,
  no `~/.claude` / `~/.codex` / `~/.pi` mutation.
- **Workflow skills default to include.** Only exclude if the repo
  genuinely lacks the infrastructure the skill operates on (no CI
  config → skip `/ci`; no deploy target → skip `/deploy`; no active
  backlog → skip `/groom`). A repo with real CI, tests, deploy, and
  backlog needs most of the workflow set — that's the inner/outer
  loop of shipping.
- **Domain skills default to exclude.** Invent only when you can
  name the concrete repo characteristic demanding it. "We might want
  X" is not a name.
- **No `references/<repo-name>.md` sidecar files.** If a skill has
  repo-specific content, it belongs in the SKILL.md body. A sidecar
  notes file is the sewn-on-sleeve anti-pattern — the generic jacket
  with an appendix. Forbidden.
- **Self-audit before declaring done.** For each workflow skill you
  installed, `diff` the rewritten SKILL.md against the spellbook
  source. Byte-identical means the rewriter dropped the ball — go
  back and redo that skill. For each workflow skill you *excluded*,
  name the concrete missing infrastructure (no `vercel.json`, no
  `fly.*.toml`, no `convex/`, no `Dockerfile`, no `.github/workflows/
  *deploy*` — concrete absence, not "didn't seem relevant"). Silent
  skip is the failure mode that ships B+ output when A is the bar.
- Preserve self-containment. When you copy or rewrite a skill, its
  `references/` and `scripts/` stay with it.

## What "tailored" means

At the SKILL.md level: every example is a repo-specific example.
Every command names the actual command the user runs here. Every
gotcha points to a real file in this repo. The skill reads like it
was written *for this codebase* — because it was.

**Bad** (generic + appended notes):

```
## Inner loop
Run your project's test command.

## Repo notes (this-repo)
Tests are run via `pnpm test --run <path>`.
```

**Good** (rewritten):

```
## Inner loop
Run `pnpm test --run <path>` (happy-dom, fast). For pre-push, use
`pnpm ci:prepush` — the Dagger pipeline runs Vitest + Playwright
+ gitleaks, same contract as the hosted CI gate.
```

The generic jacket + notes is fast. It's also wrong — the agent
reading the generic body first then reconciling with an appendix
runs a parallax failure. Write the skill for this repo in the first
place.

## References

- `references/focus-postmortem.md` — critic's rejection checklist.

See also: `/seed` for the dumb-copy variant when you want something
working fast and will curate by hand later.
