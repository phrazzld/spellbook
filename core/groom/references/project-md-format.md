# project.md Format Reference

`project.md` lives in the project root. It captures **product context** that
tune-repo artifacts don't cover: vision, users, priorities, domain language.

## Relationship to Tune-Repo Artifacts

| Artifact | Owner | Covers |
|----------|-------|--------|
| `CLAUDE.md` | `/tune-repo` | Commands, stack, gotchas (code context) |
| `AGENTS.md` | `/tune-repo` | Commit, test, PR, style conventions |
| `docs/CODEBASE_MAP.md` | `/cartographer` | Architecture, modules, data flow |
| `docs/context/INDEX.md` | `/tune-repo` | Cold-memory subsystem index |
| `docs/context/ROUTING.md` | `/tune-repo` | Trigger table for specialist routing |
| `docs/context/*.md` | `/tune-repo` | Subsystem specifications |
| `docs/adr/*.md` | `/tune-repo` | Architectural decision records |
| **`project.md`** | **`/groom`** | **Vision, users, domain, quality bar** |

`project.md` fills the product gap. Together with tune-repo outputs, agents get
everything they need: what the product is, who it's for, what matters, and how
the code is structured.

## Template

```markdown
# Project: [Name]

## Vision
[One-liner: what this product is and who it's for]

**North Star:** [Dream state — what success looks like in 2 years]
**Target User:** [Specific persona]
**Current Focus:** [Immediate priority this quarter]
**Key Differentiators:** [What makes this different]

## Domain Glossary

Terms agents must understand to work in this codebase.

| Term | Definition |
|------|-----------|
| | |

## Active Focus

Current milestone and key issues driving work right now.

- **Milestone:** [name] — [description]
- **Key Issues:** #N, #N, #N
- **Theme:** [what we're optimizing for right now]

## Quality Bar

What "done" means beyond "tests pass." Project-specific standards.

- [ ] [Product-level acceptance criterion]
- [ ] [User experience expectation]
- [ ] [Performance budget]

## Patterns to Follow

Concrete code patterns agents should replicate. Project-specific examples
that complement AGENTS.md coding style.

### [Pattern Name]
```[lang]
// example code from this repo
```

## Lessons Learned

Things we've tried that didn't work. Distilled from `.groom/retro.md`.

| Decision | Outcome | Lesson |
|----------|---------|--------|
| | | |

---
*Last updated: YYYY-MM-DD*
*Updated during: /groom session*
```

## When to Create

- `/groom` Phase 1 creates or updates `project.md`
- Replaces the old `vision.md` format (which had only 5 fields)
- If `vision.md` exists, migrate its content into project.md and delete it

## When to Read

- `/groom` Phase 1 — load for session context
- `/autopilot` — load before starting any issue
- `/shape` — load for product context
- `/issue enrich` — embed vision one-liner in Context section

## Update Frequency

Updated each `/groom` session. Between sessions, only "Active Focus" changes
(when milestones shift or key issues close).
