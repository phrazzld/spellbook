# Shared skill primitives — design system for skills

Priority: P1
Status: pending
Estimate: M (~3-4 dev-days)

Inspired by Ramp's Glass: they built a shared component library + token
system so the agent references what exists instead of generating CSS
from scratch. "When the agent knows what components exist, it reuses
them instead of reinventing them."

Our skill library has the analogous problem. Every new skill reimplements
its own receipt writer, its own lock-file helper, its own event emitter,
its own backlog parser. The fragmentation surfaces when we try to defrag
(044) or lint (046) — there's no canonical form to normalize against.

## Goal

A shared `harnesses/shared/lib/` tree and canonical templates that:

1. Consolidate the handful of utility functions skills repeatedly
   reinvent (receipt writers, lock files, event emitters, backlog
   parsers, git-bug helpers).
2. Provide canonical templates for the structural parts of a SKILL.md
   (routing table, gotcha format, description trigger convention).
3. Are enforced by lint: new skills using local-reimplementations
   instead of shared primitives fail `/harness lint`.

## Scope

### Shared utilities (things skills today each reinvent)

Concrete candidates identified during reconnaissance:

- **Event emitter** (`scripts/lib/events.sh`). Currently lives under
  `/flywheel` but the pattern (atomic JSONL append + fsync + schema
  validation) should be available to any skill emitting structured
  events. Hoist.
- **Lock files** (`scripts/lib/flywheel_lock.sh`). Same pattern:
  worktree-scoped lock with stale-pid steal. Applicable beyond
  flywheel. Hoist, parameterize the lock name.
- **Receipt writer** (currently inline in /deliver, /deploy specs).
  Standard JSON receipt with status + timing + evidence refs.
- **Backlog parser** (read `backlog.d/NNN-*.md` frontmatter; extract
  Priority/Status/Estimate). Currently re-implemented in grooming/shape
  speculation; make it canonical.
- **git-bug helpers** (create / list / close; handle the `push origin`
  bridge). Multiple skills touch git-bug; encapsulate.

### Canonical templates (structural forms skills should share)

- **Routing table format** for multi-mode skills (see /harness SKILL.md
  lines 20-33 as the reference form).
- **Gotcha list format**: bulleted, imperative, one-line. No
  happy-path instructions.
- **Frontmatter schema**: description, argument-hint, trigger phrases.
  Enforced by lint (existing) + canonical example.
- **`## Oracle` checklist format**: bulleted, `- [ ]` checkboxes,
  each item independently verifiable.

### Lint rules (enforced reuse)

New or modified skills that:

- Implement their own event emission (inline `flock` + `echo >>`) → fail
  with "use `$SPELLBOOK/harnesses/shared/lib/events.sh`".
- Implement their own lock file (`mkdir "$LOCKDIR" 2>/dev/null`) → fail
  with hoisted-lib pointer.
- Define a routing table that doesn't match canonical shape → warn
  (harder to auto-detect; opt-in strict mode).

## Design

### Directory

```
harnesses/shared/
├── AGENTS.md              # existing, symlinked
└── lib/                   # new
    ├── events.sh          # hoisted from skills/flywheel/scripts/lib/
    ├── lock.sh            # hoisted from skills/flywheel/scripts/lib/
    ├── receipt.sh         # consolidated from inline usage
    ├── backlog.sh         # parser helpers
    ├── git_bug.sh         # wrapper functions
    └── templates/
        ├── SKILL.md.tmpl          # canonical structure
        ├── routing_table.md.tmpl  # copy-paste starter
        └── oracle.md.tmpl         # checklist format
```

### Sourcing convention (preserves self-containment)

Skills source via `$SPELLBOOK_LIB` resolved at runtime:

```bash
# Top of any script that needs shared utilities:
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
SPELLBOOK_LIB="$(cd "$SCRIPT_DIR/../../.." && pwd)/harnesses/shared/lib"
# shellcheck source=/dev/null
. "$SPELLBOOK_LIB/events.sh"
```

**Caveat from existing memory** (`feedback_scaffold_over_global.md` +
self-containment doctrine): skills must remain symlink-distributable.
The shared lib lives in the spellbook checkout too, so a symlinked
skill still resolves `$SPELLBOOK_LIB` to the invoking project's
checkout. Distribution test: symlink one skill into a foreign project,
invoke its script, verify it finds the shared lib.

This differs from external-skill scripts that hardcode
`~/.claude/skills/<bundle>/bin/...` — which breaks distribution. The
resolve-via-`readlink -f` pattern is the right shape.

### Templates as generators, not references

Rather than just documenting the canonical form, ship a generator:

```bash
/harness create skill mynewskill [--mode router|single] [--domain delivery|research|quality]
```

Generates the skeleton using the templates, pre-populated with the
canonical shapes. First-use motion for any new skill. Reduces the
per-skill entropy pressure at authoring time instead of cleaning it up
after.

## MVP Slice (~2 days)

1. Hoist `events.sh` and `flywheel_lock.sh` into
   `harnesses/shared/lib/` with the generic-name rename. Update
   `/flywheel` to source from the new location (breaks lock-step with
   028 Phase 2 — coordinate).
2. Write `SKILL.md.tmpl` based on harness's current canonical shape.
3. Add `/harness create skill <name>` subcommand that scaffolds from
   the template.
4. Lint rule: detect inline `flock` usage in new scripts and point to
   `shared/lib/lock.sh`.

Phase 2: `receipt.sh`, `backlog.sh`, `git_bug.sh`. Full lint coverage.

## Oracle

MVP:

- [ ] `harnesses/shared/lib/events.sh` exists and is sourced by
      `/flywheel` with no behavior change (existing tests pass).
- [ ] `/harness create skill newskill` produces a new skill skeleton
      under `skills/newskill/` matching the canonical shape.
- [ ] Symlink test: install a generated skill into a foreign project's
      `.claude/skills/`, invoke its script, confirm it resolves
      `harnesses/shared/lib/events.sh` correctly.
- [ ] `/harness lint` warns on a seeded skill with inline `flock`
      usage, pointing to `shared/lib/lock.sh`.

Phase 2:

- [ ] ≥3 existing skills migrate from inline implementations to
      shared lib, passing their existing tests.
- [ ] Fresh `/harness lint` pass shows no inline-reimplementation
      warnings remaining in first-party skills.

## Non-Goals

- **External skill migration.** `.external/*/scripts/` stays as-is.
  Those upstream repos own their own patterns; we don't rewrite them.
- **Python/TypeScript shared libs.** Bash only in MVP. If a future
  skill needs Python helpers, add `shared/lib/python/` then.
- **Cross-harness portability.** Shared lib is Claude/Codex/Pi-agnostic
  bash; harness-specific primitives stay in `harnesses/<name>/`.
- **Invoking shared lib from remote-mode installs.** Remote mode
  (bootstrap.sh fallback) already only downloads individual skills;
  shared lib requires a full checkout. Document limitation.

## Related

- Unblocks: 044 check 6 (script duplication → propose hoisting).
- Unblocks: 046 (sync gate can validate canonical-shape conformance).
- Coordinates with: 028 Phase 2 (events.sh / lock.sh rename).
- Prior art: Ramp's Glass shared design system + token library.
