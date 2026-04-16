# Skill catalog tailoring — cross-harness tiers, bundles, per-project scope

Priority: P0
Status: pending
Estimate: L (MVP ~1 week; full rollout ~2-3 weeks)

Cross-session diagnosis landed concrete numbers: every Claude Code turn
injects a ~12.4K-token catalog of ~100 skills (~24 first-party + ~76
external) because `bootstrap.sh` symlinks every skill globally. Most of
those skills are irrelevant in any given project. That injection is the
single largest recurring context cost in the harness and it grows with
every skill we add.

This is the top-priority harness problem. Everything else — defrag,
primitives, health synthesizer — rides on top of a catalog we can shape.

**Cross-harness is non-negotiable.** Spellbook's entire premise is "one
repo, all harnesses." Any selectivity mechanism that works only on
Claude Code violates the design. The primary layer must work across
Claude, Codex, and Pi; harness-native runtime features are
optimizations on top, not the base.

## Goal

Per-project, per-task control over **which skills are in the injected
catalog**, functioning identically across Claude Code, Codex, and Pi.

Target state:

- Default global install contains a small "core" set (orchestrators +
  doctrine skills) that are universally useful.
- Additional skill bundles are togglable per-project.
- Converting the ~76-skill `.external/` tree into togglable bundles cuts
  baseline injection from ~12.4K → ~3K tokens on any project that
  doesn't opt in to specific bundles — identically on Claude and Codex.
- Adding a new external source does not change default injection cost
  for existing projects.

Ownership boundary: this ticket controls **which skills are visible to
a given Claude/Codex/Pi instance**. It does NOT generate per-project
artifacts (see 029 `/tailor` for that). Complementary, not overlapping.

## Why This Is the Right Fight

Research revised the architectural picture:

1. **SKILL.md + description is the cross-harness contract.** Claude
   Code, Codex CLI, Cursor, Continue, Windsurf, Gemini CLI — all 30+
   modern harnesses converge on the same discovery pattern: scan
   `~/.agents/skills/` (emerging shared location) and project-local
   `.agents/skills/`, parse frontmatter, inject name + description at
   startup, load full body on demand. This is the portable layer.

2. **Both Claude AND Codex have native plugin mechanisms.** Claude
   ships `.claude-plugin/plugin.json` + `enabledPlugins`. Codex ships
   `plugin.json` (with `skills` / `mcpServers` / `apps` fields) + a
   `/plugins` command. The *idea* (bundle skills into togglable group)
   is portable; the manifest *format* is per-harness. We can emit
   both from one source.

3. **Pi already has cross-harness-style filesystem selectivity.**
   `harnesses/pi/settings.json:skills[]` uses `+` include / `!` deny
   globs over filesystem paths — exactly the filesystem-level allowlist
   pattern we need. Prior art exists *in this repo*.

4. **`~/.agents/skills/` is an emerging shared directory convention.**
   Pi's config already globs it. If Claude and Codex can be pointed at
   it, we can have one physical tree symlinked from one place instead
   of parallel trees per harness. (Verify before planning around this.)

The correct primary mechanism is **filesystem-level selectivity at
install/sync time** — harness-agnostic by construction because every
harness just scans a directory. The plugin mechanisms in Claude and
Codex become runtime optimizations on top (fast toggle without
re-symlinking).

## Current State (for the diff)

**What's symlinked globally today:**

| Bundle                  | Skills | ~Tokens per Claude injection |
|-------------------------|-------:|-----------------------------:|
| primary (ours)          |     24 |                        3,459 |
| `.external/openai-*`    |     37 |                        2,827 |
| `.external/gstack-*`    |     15 |                        1,959 |
| `.external/anthropic-*` |     16 |                        1,698 |
| `.external/vercel-*`    |      7 |                          791 |
| `.external/julius-*`    |      1 |                          ~95 |
| **Total**               |**100** |                    **~12,829** |

(Codex injection cost is comparable magnitude; not separately measured.)

**Existing selectivity primitives across harnesses:**

| Harness | Mechanism | Status |
|---|---|---|
| Claude | `.claude-plugin/plugin.json` + `enabledPlugins` in settings.json | Native, unused by Spellbook |
| Codex  | `plugin.json` (skills/mcp/apps) + `/plugins` command | Native, unused by Spellbook |
| Pi     | `settings.json:skills[]` `+`/`!` globs | Native, **used today** in this repo |
| All    | Filesystem scan of `~/.agents/skills/` and similar | Native, the shared contract |

**What's missing:**

- No per-skill tier metadata (all 100 skills are equal).
- No bundle manifests (no way to group skills into togglable units).
- `bootstrap.sh` symlinks everything unconditionally — no tier or
  bundle awareness.
- Claude and Codex harnesses have no selectivity mechanism wired up
  (only Pi does).
- No per-project mechanism to declare "this repo wants bundles
  X and Y, not Z."

## Design

### Three-layer model (all harness-agnostic)

**Layer 1 — Skill tier metadata.** New frontmatter field `tier:` on
every skill. Three values: `core`, `optional`, `experimental`. Default
`optional`. Controls default install behavior.

**Layer 2 — Bundle manifests (source-of-truth in this repo).** A
bundle is a named group of skills authored as one YAML file:

```yaml
# bundles/anthropic.yaml
name: anthropic
description: Anthropic's agent-skills library (pdf, docx, xlsx, ...)
skills:
  - anthropic-pdf
  - anthropic-docx
  - anthropic-xlsx
  # ...
default_enabled: false
```

Each bundle renders into per-harness artifacts:

- `harnesses/claude/plugins/<name>/.claude-plugin/plugin.json`
- `harnesses/codex/plugins/<name>/plugin.json`
- Pi consumes the bundle list directly via glob rendering into
  `harnesses/pi/settings.json:skills[]`.

Single source, three outputs. Bundle additions/removals propagate to
all three harnesses in lockstep.

**Layer 3 — Per-project enablement.** A project declares which bundles
it wants in `.spellbook.yaml`:

```yaml
# .spellbook.yaml (committed to the target repo)
bundles:
  core: true         # always on
  delivery: true
  anthropic: true    # this project authors Claude-API skills
  openai: false      # explicitly off
  gstack: false
  vercel: false
```

`/harness sync` reads this and renders the appropriate per-harness
selectivity artifact into the project's `.claude/settings.json`,
`.codex/config.toml`, and/or `.pi/settings.json` as applicable.

### Default install behavior

`bootstrap.sh` changes:

- Reads `harnesses/<harness>/default-bundles.yaml` for the baseline
  bundle set (ships with `core` + `delivery` enabled; everything else
  off by default).
- Only symlinks skills belonging to enabled bundles. Disabled bundles
  stay on disk (for fast re-enable) but are not symlinked into the
  harness's skills directory.
- Additionally emits the runtime-toggle artifacts for Claude
  (enabledPlugins in `~/.claude/settings.json`) and Codex
  (`~/.codex/config.toml` plugins block) so users can flip bundles
  without re-running bootstrap.

### Bundle groupings

External (1:1 from `.external/`):
- `anthropic` (16 skills)
- `openai` (37 skills)
- `gstack` (15 skills)
- `vercel` (7 skills)
- `julius` (1 skill)

First-party split (domain-coherent):
- `core` — always enabled: harness, groom, shape, deliver, flywheel,
  reflect, settle, yeet, ceo-review, office-hours
- `delivery` — inner loop: implement, code-review, ci, refactor, qa,
  deploy, monitor, diagnose
- `research` — investigation: research, model-research
- `quality` — audits: a11y, agent-readiness, deps, demo

Exact split is a phase-1 design decision; the shape is illustrative.
Core is the conservative default (~10 skills, ~1.5K tokens injection).

### Shared-directory question (verify before planning)

Research surfaced `~/.agents/skills/` as an emerging cross-harness
convention. Pi already uses it. If Claude Code and Codex CLI both read
from it (alongside their own `~/.claude/skills/` and `~/.codex/skills/`
paths), we can simplify: one symlinked tree at `~/.agents/skills/`,
every harness reads from it, no per-harness skill directory.

**MVP does not assume this.** We keep per-harness skill directories
initially. Verify the shared-dir behavior empirically; if it works,
consolidate in a follow-up.

## MVP Slice (~1 week)

Ship only:

1. **Tier metadata convention.** Add `tier:` frontmatter field.
   `/harness lint` warns on missing tier (does not fail).
2. **Bundle source-of-truth.** Create `bundles/*.yaml` for the 5
   external sources + `core` + one first-party split (e.g. `delivery`).
   Other first-party skills stay implicitly `core` for now.
3. **Render script.** `scripts/render-bundles.sh` emits:
   - `harnesses/claude/plugins/<bundle>/.claude-plugin/plugin.json`
   - `harnesses/codex/plugins/<bundle>/plugin.json`
   - Updates to `harnesses/pi/settings.json:skills[]` glob list.
   Runs on pre-commit when `bundles/*` changes (like `index.yaml`).
4. **Bootstrap selectivity.** `bootstrap.sh --bundles` mode:
   - Reads `harnesses/<h>/default-bundles.yaml`.
   - Only symlinks skills from enabled bundles.
   - Emits runtime-toggle artifacts (Claude enabledPlugins, Codex
     plugins config) reflecting the same set.
   - Old flat-symlink behavior remains default as `--legacy`.
5. **Measurement gate.** Before/after token-injection snapshot on
   Claude Code AND Codex CLI, against spellbook repo + vulcan + one
   other real project. Target: ≥70% reduction on both harnesses
   without breaking any skill invocation that actually fires.

Validate premise: if the mechanism works on Claude but not Codex, or
the token reduction diverges significantly between harnesses, the
design has a harness-specific gap — **diagnose before widening.**

## Phase 2 (~1 week, after MVP validates)

- Split first-party skills into the full bundle set (core / delivery
  / research / quality).
- `.spellbook.yaml bundles:` block + `/harness sync` renderer that
  emits the per-harness per-project artifact.
- Flip bootstrap default to `--bundles` mode; `--legacy` becomes
  opt-in.
- Migration guide in README.
- `/harness bundle` subcommand: `list`, `enable <name>`,
  `disable <name>`, `why-enabled <name>`.

## Phase 3 (parked)

- Shared-dir consolidation (if `~/.agents/skills/` works on all three
  harnesses).
- Tier-based default install (`--tier core` CLI flag).
- Path-based auto-enablement via SKILL.md `paths: [...]` globs
  (Cursor-style), so bundles auto-enable when relevant files exist.
- File bugs with Claude Code + Codex on the underdocumented
  catalog-refresh trigger + request suppression knobs.

## Oracle

MVP:

- [ ] Every skill has a `tier:` frontmatter field (or `/harness lint`
      warns).
- [ ] `bundles/*.yaml` source-of-truth exists for the 5 external
      sources + `core` + at least one first-party bundle.
- [ ] `scripts/render-bundles.sh` emits Claude plugin manifests,
      Codex plugin manifests, and Pi settings.json glob — all three
      from the single bundle source.
- [ ] `bootstrap.sh --bundles` installs the default bundle set and
      only that set is symlinked into each harness's skills dir.
- [ ] **Cross-harness parity:** on the same project, Claude Code and
      Codex CLI see the same enabled skills (catalog content may
      differ in format, but skill identities match).
- [ ] Before/after token measurement on Claude AND Codex shows ≥70%
      reduction from baseline on the same project with externals
      defaulted off.
- [ ] Toggling a bundle's runtime artifact (Claude `enabledPlugins`
      or Codex plugins config) and restarting the harness makes those
      skills appear/disappear in the catalog, without re-running
      bootstrap.
- [ ] Pi's existing `skills[]` glob is re-rendered from the same
      `bundles/*.yaml` source; behavior unchanged for current Pi
      users.

Phase 2:

- [ ] First-party skills split into ≥3 bundles.
- [ ] `.spellbook.yaml bundles:` declaration renders to per-harness
      per-project artifacts via `/harness sync`.
- [ ] Three real repos use different bundle selections, all three
      harnesses respect them.

## Non-Goals

- **Generating per-repo skill content.** That's `/tailor` (029).
- **Inventing a new selectivity primitive.** Every harness has a
  native mechanism; we compose them.
- **Anchoring the design on any single harness's runtime features.**
  Filesystem-level selectivity is the base layer; harness plugin
  runtimes are optimizations.
- **Sensei-style role-based recommender.** Parked; no signal.
- **Deprecating `registry.yaml`.** Sync still pulls sources; bundle
  manifests sit alongside the synced skills.
- **Changing `/harness lint` token-budget math.** Per-skill; catalog
  injection is orthogonal.
- **Solving the undocumented catalog-refresh triggers.** File bugs
  upstream (phase 3); don't work around in-harness.

## Risks / Open Questions

1. **Does filesystem-level selectivity actually reduce catalog cost
   on every harness?** Every harness scans its skills dir and injects
   what it finds. If we only symlink the enabled set, the catalog
   shrinks. This is the design premise; confirm empirically as the
   first MVP measurement.

2. **Claude `enabledPlugins` / Codex plugins config — do they gate
   catalog injection or just /menu visibility?** Documented behavior
   says catalog-gating; verify on both harnesses before widening.

3. **`~/.agents/skills/` adoption.** Emerging convention; not
   universally implemented yet. MVP keeps per-harness paths; phase 3
   consolidates if verified.

4. **Bundle-name collisions.** If a user hand-enables `openai` in
   `.spellbook.yaml` and they have an unrelated `openai` plugin from
   another source, who wins? Namespace as `spellbook/openai` in
   rendered manifests; verify both harnesses honor qualified names.

5. **Pi glob semantics vs. bundle manifests.** Pi uses `+`/`!` globs
   over paths, not named bundles. The renderer must compile bundle
   membership into the correct glob sequence. Deterministic and
   testable, but the source-of-truth must be named bundles, not paths.

6. **`--legacy` sunset timeline.** How long do we run the old
   flat-symlink mode in parallel? Tentative: 30 days after `--bundles`
   validates on 3 real repos, then flip default + keep `--legacy` as
   emergency escape for another 30 days.

## Related

- Referenced diagnosis: cross-session capture (vulcan, 2026-04-16,
  quantifying ~12.4K token injection with per-bundle breakdown).
- Paired with: 029 `/tailor` (per-repo artifact generation —
  complementary, not overlapping).
- Prior art in this repo: `harnesses/pi/settings.json:skills[]` glob
  (the cross-harness-compatible pattern, already working).
- Prior art external:
  - Claude Code plugins: https://code.claude.com/docs/en/plugins-reference
  - Codex skills: https://developers.openai.com/codex/skills
  - Codex plugins: https://developers.openai.com/codex/plugins
  - Codex config reference: https://developers.openai.com/codex/config-reference
  - AGENTS.md spec (Agentic AI Foundation / Linux Foundation):
    https://github.com/agentsmd/agents.md
  - Agent Skills specification: https://agentskills.io/specification
  - Progressive disclosure (Anthropic engineering):
    https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
  - Cross-harness skill portability:
    https://github.com/VoltAgent/awesome-agent-skills
  - `skillsDirectories` feature request (Claude):
    https://github.com/anthropics/claude-code/issues/39403
  - Deferred skill loading (Claude):
    https://github.com/anthropics/claude-code/issues/19445
- Blocks: 044 `/harness defrag` (defrag operates within bundle scope),
  046 doc-behavior sync gate (needs bundle manifests to validate).
