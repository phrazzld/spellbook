# Walkthrough — ux-polish skill

## Merge Claim

`/ux-polish` now gives the repo a dedicated workflow for small, meaningful UX improvements, sitting between broad design work and large simplification work.

## Why Now

Before this branch, the closest fits were `/design`, `ui-skills`, and `/simplify`. Those covered system design, passive UI constraints, and large refactors, but there was no explicit lane for "find one narrow UX friction point and ship the fix."

## Before

```mermaid
graph TD
  A["User wants a small UX improvement"] --> B["Reach for /design"]
  A --> C["Reach for ui-skills"]
  A --> D["Reach for /simplify"]
  B --> E["Broader exploration than needed"]
  C --> F["Constraints, but no workflow"]
  D --> G["Too architecture-heavy for micro polish"]
```

Evidence:
- `rg -n "ux-polish|small UX|micro polish" README.md core` returned no existing workflow skill.
- `core/design/SKILL.md` focuses on exploration, audit, tokens, and system-level implementation.
- `core/ui-skills/SKILL.md` provides constraints, not a scoped polish workflow.
- `core/simplify/SKILL.md` targets one high-leverage architectural refactor per PR.

## What Changed

```mermaid
graph TD
  A["User wants a small UX improvement"] --> B["Run /ux-polish"]
  B --> C["Audit one route, flow, or component"]
  C --> D["Score candidates with polish rubric"]
  D --> E["Ship one coherent UX polish pass"]
  E --> F["Verify with expert-panel review and visual QA"]
```

```mermaid
graph TD
  A["/ux-polish SKILL.md"] --> B["Guardrails for narrow scope"]
  A --> C["Workflow tied to ui-skills and design"]
  C --> D["Use ui-skills for implementation constraints"]
  C --> E["Escalate to /design when polish becomes system design"]
  A --> F["references/polish-rubric.md"]
  F --> G["Rank impact, proof path, accessibility, and risk"]
  H["README skill index"] --> I["Expose the new command"]
```

## After

Evidence:
- `core/ux-polish/SKILL.md`
- `core/ux-polish/references/polish-rubric.md`
- `README.md`
- `python3 core/skill-builder/scripts/validate_skill.py core/ux-polish`
- `python3 core/skill-creator/scripts/package_skill.py core/ux-polish /tmp/spellbook-packages`
- `./scripts/sync.sh all`

## Persistent Verification

- `python3 core/skill-builder/scripts/validate_skill.py core/ux-polish`
- `python3 core/skill-creator/scripts/package_skill.py core/ux-polish /tmp/spellbook-packages`

## Residual Risk

This branch adds documentation-driven workflow guidance, not executable product code. The risk is mainly overlap with adjacent skills, which is mitigated by the explicit "out of scope" section and the handoff rules to `ui-skills`, `/design`, and `/simplify`.
