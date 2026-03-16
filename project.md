# Project: agent-skills

## Vision
Portable skill library that makes AI coding agents reliably excellent across any harness.

**North Star:** Every recurring workflow pattern a senior engineer uses is captured as a tested,
composable skill — so any agent (Claude, Codex, Gemini, Pi) can execute it first-try.
**Target User:** Senior+ engineers running multi-agent workflows across multiple repos.
**Current Focus:** Sharpen existing skills — definitions, triggers, quality gates — over adding new ones.
**Key Differentiators:** Agent-agnostic (works across harnesses), budget-aware (O(umbrellas) not O(skills)),
research-backed (web + multi-model validation before codifying).

## Domain Glossary

| Term | Definition |
|------|-----------|
| Skill | A markdown-first module (SKILL.md + optional references/) that gives agents domain expertise |
| Core skill | Universal skill synced to all harness config dirs (11 total: 3 implicit + 8 DMI) |
| Pack | Domain-specific skill bundle loaded per-project (9 packs: web, design, agent, infra, quality, payments, growth, scaffold, finance) |
| Harness | An AI agent runtime (Claude Code, Codex, Gemini CLI, Factory, Pi) |
| Umbrella | A skill that absorbs related sub-skills as references, saving budget (autopilot, debug, reflect, research) |
| DMI | Disable-model-invocation — user-only skills that cost zero budget |
| Budget | ~16K char Claude Code description limit; ~1.4K used by 3 implicit skills |
| Delivery pipeline | groom → autopilot (shape → build → pr → settle → merge) |

## Active Focus

- **Milestone:** Skill Quality — sharpen definitions, triggers, and gate semantics
- **Key Issues:** #24 (description audit), #51 (sync-time validation), #31/#32 (pipeline codification)
- **Theme:** Make every skill precise enough that agents invoke it correctly first-try
- **Recent:** Core pruning from 50+ to 11 skills, 37 domain skills to 9 packs, 4 umbrella absorptions

## Quality Bar

- [ ] Every skill has clear trigger conditions (when to invoke, when NOT to)
- [ ] All descriptions ≤1024 chars with trigger phrases (enforced by sync.sh)
- [ ] Skills compose — orchestrators call primitives, never reimplement
- [ ] Agent-agnostic — no Claude-specific assumptions leak into skill bodies
- [ ] Budget stays within 16K limit with room for growth (~1.4K of ~16K used)
- [ ] Retro patterns flow back into skill definitions

## Patterns to Follow

### Progressive Disclosure
```
description (budget cost) → SKILL.md body → references/ (on-demand)
```

### Umbrella Absorption
```
core/{umbrella}/
├── SKILL.md          # Routing table (budget cost)
└── references/
    ├── sub-cap-1.md  # Former standalone, loaded on demand
    └── sub-cap-2.md  # Zero additional budget cost
```

### AC Tags for Machine Verification
```markdown
- [ ] [test] Given X, when Y, then Z
- [ ] [command] Given X, when `cmd`, then output matches
- [ ] [behavioral] Given X, when user does Y, then Z
```

## Lessons Learned

| Decision | Outcome | Lesson |
|----------|---------|--------|
| verify-ac as standalone | Worked but wasn't used | Skills become gates only when delivery workflows name exact stop conditions |
| Effort predictions | Accurate (retro confirms) | Effort/s and effort/m calibration is reliable for this repo |
| Umbrella pattern (research/) | 4→1 budget savings | Progressive disclosure works; add sub-caps at zero cost |
| Core pruning 50+ → 11 | Budget 10.2K → 1.4K | Aggressive pruning + pack architecture works; domain knowledge belongs in packs |
| Standalone pipeline skills | Fragmented, hard to compose | Absorb related skills into umbrellas; sub-capabilities as references cost zero budget |

---
*Last updated: 2026-03-15*
*Updated during: /groom session — post-restructuring backlog overhaul*
