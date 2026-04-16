# `/harness defrag` — audit-that-fixes, not flags

Priority: P1
Status: pending
Estimate: M (~3-4 dev-days)

Inspired by Ramp's Glass: their `defrag` skill scans their codebase for
fragmentation — duplicated components, inconsistent patterns, files that
should be consolidated — and *auto-fixes* instead of just flagging. They
run it regularly, and "every pass makes the codebase more coherent for
the next thing the agent builds."

Our equivalent target is the skill library itself. As the catalog grows
(especially after 043 establishes plugin bundles), entropy concentrates
at the seams: two skills with overlapping trigger phrases, three
skills each reimplementing their own receipt writer, router tables
drifting from reference files on disk.

`/harness audit` today flags. This upgrades it to fix.

## Goal

A single command that scans the skill library, identifies concrete
fragmentation, and either auto-consolidates (with git-diff confirm) or
opens a bounded cleanup task.

Run cadence: before every `/flywheel` cycle; opportunistically by
operator; automatically as part of 046 pre-commit once confidence is
established.

## Scope of "Fragmentation"

Eight concrete checks, all scriptable:

1. **Trigger-phrase overlap.** Two skills' description trigger lists
   share ≥N phrases → flag as likely-duplicate domain. Example:
   multiple skills claiming "debug this", "why is this broken".
2. **Router-drift.** Skills with `references/mode-*.md` files that
   aren't listed in the SKILL.md routing table (or vice versa).
3. **Mode-bloat violations.** Skills with >4 modes inline → extract
   candidate. Already a lint rule; defrag proposes the extraction diff.
4. **Token budget violations.** SKILL.md >3K target / >5K ceiling →
   flag with line budget suggestions.
5. **Description ghosts.** Trigger phrases in SKILL.md that never
   fire in recorded sessions (needs harness-health data from 047).
6. **Script duplication.** Two skills' `scripts/lib/*.sh` with
   near-identical functions → propose hoisting to
   `harnesses/shared/lib/` (needs 045 infrastructure).
7. **Orphaned references.** `references/*.md` files not referenced
   anywhere in the skill's SKILL.md → either link or delete.
8. **Dead cross-references.** Skill A mentions skill B; skill B
   doesn't exist (renamed, deleted, or typo).

Each check has: detector (read-only), fix proposal (unified diff), and
safety gate (what must be true to auto-apply vs. human-review).

## Design

### Control flow

```
/harness defrag [--check <name>] [--apply] [--plugin <name>]
    │
    ▼
┌─ Phase 1: Scan ─────────────────────────────────────┐
│  Run all enabled checks; collect findings.          │
│  Findings grouped by severity: blocking / cleanup.  │
└─────────────────────────────────────────────────────┘
    │
    ▼
┌─ Phase 2: Propose ──────────────────────────────────┐
│  For each finding, emit a unified diff + rationale. │
│  Diff grouped by file; operator approves per-file.  │
└─────────────────────────────────────────────────────┘
    │
    ▼
┌─ Phase 3: Apply (optional) ─────────────────────────┐
│  --apply flag: apply all auto-safe diffs.           │
│  Without --apply: write proposals to                │
│  .spellbook/defrag-report.md, exit 0.               │
│  Human-review diffs NEVER auto-apply regardless.    │
└─────────────────────────────────────────────────────┘
```

### Auto-safe vs. human-review categorization

Each check declares its own category:

| Check | Auto-safe | Reason |
|---|---|---|
| 1. Trigger overlap | ❌ human-review | Requires judgment: merge? split domain? rename? |
| 2. Router drift | ✅ auto-safe | Mechanical: add missing row OR delete orphan file |
| 3. Mode bloat | ❌ human-review | Extraction is a refactor with naming decisions |
| 4. Token budget | ❌ human-review | Trimming changes meaning |
| 5. Description ghosts | ❌ human-review | Removal is a product decision |
| 6. Script duplication | ❌ human-review | Requires 045's shared/lib/ to exist first |
| 7. Orphaned references | ✅ auto-safe | Delete if unlinked for ≥N days; else link |
| 8. Dead cross-references | ✅ auto-safe | Replace with `<!-- was: skillname -->` comment |

`--apply` applies only the auto-safe checks. Human-review items always
require explicit operator action.

## MVP Slice (~3 days)

Ship only checks 2, 7, 8 (auto-safe) and check 3 (human-review) as the
first pass. Reasoning:

- Checks 2/7/8 are pure filesystem walk + regex; no dependencies.
- Check 3 (mode bloat) is already partially implemented in
  `/harness lint`; defrag reuses that detector and adds the
  extraction-diff proposer.
- Checks 1/4/5/6 depend on data or infrastructure this ticket doesn't
  want to block on (harness-health signals, shared-lib extraction).
  Add them incrementally.

## Oracle

- [ ] `/harness defrag` on current spellbook produces zero auto-safe
      findings (because we ran it during authoring).
- [ ] Seeded fixture: insert an orphaned `references/mode-foo.md` file
      not listed in router table → defrag detects it, proposes
      deletion diff, `--apply` removes it.
- [ ] Seeded fixture: rename a skill; check 8 catches the dead
      cross-reference in another skill's gotcha list.
- [ ] Seeded fixture: add `references/mode-bar.md` in router table
      without creating the file; check 2 detects and proposes the row
      removal.
- [ ] `.spellbook/defrag-report.md` format is readable; each finding
      shows `path:line`, rationale, and proposed diff.
- [ ] Runs in <30s on current skill library (~100 skills).

## Non-Goals

- **Skill deletion.** Dead-weight detection is data (047), not fix.
  Defrag never removes a whole skill.
- **Cross-repo defrag.** Only operates on the local checkout.
- **Auto-apply without operator review for human-review checks.**
  Never. `--apply` is auto-safe-only by hard constraint.
- **Formatting-only cleanup.** Defrag is about structural fragmentation,
  not style. Style is lint's job.

## Related

- Depends on: 043 (plugins give us a bounded scope for defrag runs).
- Depends on (partial): 045 (shared primitives — unblocks check 6),
  047 (harness-health — unblocks check 5).
- Complements: 046 (pre-commit gate — defrag-safe checks eventually
  run at commit time).
- Prior art: Ramp's `defrag` skill (Glass engineering post, 2026-04).
