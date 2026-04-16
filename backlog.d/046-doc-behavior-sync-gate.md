# Doc-behavior sync gate — enforce skill docs track skill behavior

Priority: P1
Status: pending
Estimate: S (~2 dev-days)

Inspired by Ramp's Glass: "If you add a feature, the docs need to
describe it. If you modify a skill, the skill's documentation needs to
be current. Annoying to set up, but it made the biggest difference."
Fragmentation caught *at the door* instead of accumulating.

Our equivalent: a pre-commit gate that enforces structural consistency
between skills and their documentation. Extends the existing
`index.yaml` regen hook; doesn't replace it.

## Goal

A pre-commit (and optionally CI) check that fails when:

1. A skill's body changed but its frontmatter description didn't (the
   description is the trigger; silent drift is the worst-case failure
   mode).
2. A new `references/mode-*.md` file was added but the SKILL.md router
   table has no row for it (or vice versa: route exists, file doesn't).
3. A skill's cross-reference points to a deleted or renamed skill.
4. A skill's SKILL.md exceeds the token budget (3K target warn / 5K
   ceiling fail).
5. A bundle manifest (after 043 lands) declares a skill that isn't
   on disk, OR the rendered per-harness plugin manifests drift from
   the `bundles/*.yaml` source-of-truth.

## Scope

### What this gate owns (new checks)

**Check A — description-behavior drift.** If the commit touches a
skill's SKILL.md body (anything below frontmatter) but leaves the
frontmatter `description:` unchanged, fail with:

```
skills/<name>/SKILL.md: body changed but description did not.
Description is the trigger — silent drift causes skill-miss.
If this is intentional (refactor-only), add a
`[skip-desc-check]` trailer to the commit message.
```

Escape hatch for pure refactors via commit trailer.

**Check B — router/reference consistency.** Parse the SKILL.md routing
table (markdown table after `## Routing` header); cross-check against
`ls references/mode-*.md`. Symmetric-difference is an error.

**Check C — dead cross-references.** Grep every SKILL.md for patterns
like `/skillname` or `skills/skillname/`; fail if the target skill
doesn't exist on disk.

**Check D — token budget.** Count approximate tokens (char-based
heuristic: chars/4) for each changed SKILL.md. Warn at 3K, fail at 5K.
(Existing lint rule; this gate enforces it at commit instead of
advisory.)

**Check E — bundle manifest drift** (after 043). Two sub-checks:
(1) compare `bundles/<name>.yaml skills:` list against actual skill
directories on disk — symmetric-difference is an error.
(2) compare the rendered per-harness artifacts
(`harnesses/claude/plugins/<name>/.claude-plugin/plugin.json`,
`harnesses/codex/plugins/<name>/plugin.json`,
`harnesses/pi/settings.json:skills[]`) against a fresh
`scripts/render-bundles.sh` dry-run — drift means someone edited the
rendered artifact instead of the source. Reject with pointer to
`bundles/<name>.yaml`.

### What this gate does NOT own

- `index.yaml` generation (existing hook owns; this gate runs after).
- Skill content quality (that's `/harness lint` / 044).
- Token budget advice / trimming (044 surfaces recommendations).

## Design

### Hook placement

Extend `.githooks/pre-commit` to run `scripts/sync-gate.sh` after the
existing `generate-index.sh`. Failure → non-zero exit → git blocks the
commit with a readable summary.

### CI integration

The same `sync-gate.sh` runs in Dagger (25 lands the merge gate) so PRs
can't bypass via `--no-verify` locally. Same script, two invocation
sites.

### Configurability

Minimal by design. Escape hatches only for checks A (commit trailer)
and D (skills opt out via `budget-exception: true` in frontmatter with
a mandatory rationale comment). Checks B/C/E have no escape hatch —
they're objective structural errors.

## MVP Slice (~1-2 days)

Ship checks B, C, D first. Reasoning:

- B/C are pure structural checks with no judgment required.
- D already has a lint rule; promoting it to a gate is small.
- Check A requires careful heuristics (what counts as a "body change"
  vs. typo-fix?) — add in phase 2 once the simpler checks prove the
  pattern.
- Check E depends on 043 landing.

## Oracle

MVP:

- [ ] `scripts/sync-gate.sh` runs as a pre-commit hook after index
      regeneration.
- [ ] Seeded commit: add `references/mode-foo.md` without a router
      table row → blocked with check B failure message.
- [ ] Seeded commit: delete skill `demo/`; another skill referencing
      `/demo scaffold` still commits → blocked with check C.
- [ ] Seeded commit: SKILL.md grows to 6K tokens → blocked with
      check D; commits under 3K pass; commits between 3K and 5K warn
      but pass.
- [ ] Runs in <5s on current skill library.

Phase 2:

- [ ] Check A detects body change without description change; escape
      via commit trailer works.
- [ ] Check E validates bundle manifest consistency across all three
      harness renderings (depends on 043).
- [ ] Dagger CI runs the same script.

## Non-Goals

- **Semantic description-correctness checking.** We enforce *that* the
  description changed, not *whether* the new description accurately
  reflects the new behavior. That's a 047 harness-health concern.
- **Full doc-completeness validation.** If a skill has no gotchas
  list, that's a style concern, not a sync concern.
- **Cross-repo references.** Skills reference other skills in this
  repo only. External references (registry.yaml sources) aren't
  scoped.
- **Commit-message linting.** Conventional Commits format is out of
  scope; this gate is about skill file consistency.

## Risks

1. **False positives on pure refactor.** Mitigated by commit trailer
   escape hatch for check A. If operators use the trailer routinely,
   the check is miscalibrated and we retune.
2. **Slow on large commits.** Pre-commit must stay under ~5s.
   Measured budget; if we exceed, narrow the gate to
   *changed-files-only* instead of full-library re-scan.
3. **Merge conflicts on router tables.** If two branches both edit the
   routing table and one's mode-file is renamed, the gate may false-
   fail post-merge. Acceptable: the operator re-runs the gate after
   resolving the conflict.

## Related

- Depends on: existing `.githooks/pre-commit` + `generate-index.sh`
  infrastructure.
- Depends on (partial): 043 (check E requires plugin manifests).
- Coordinates with: 025 (Dagger merge gate — same script runs in CI).
- Complements: 044 `/harness defrag` (defrag proposes; this gate
  enforces at commit). 045 shared primitives (canonical templates
  this gate can validate against).
- Prior art: Ramp's Glass document validation pipeline (Glass
  engineering post, 2026-04).
