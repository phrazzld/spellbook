# Backlog — agent-skills

Ideas, deferred work, someday/maybes. Promoted to GitHub Issues when ready.

*Last updated: 2026-03-15*

## Deferred from GitHub Issues

### Compete skill — three-way agent competition
*Demoted from #8 (2026-03-15). Depends on #50 (risk tiers) and #34 (parallel subagent infra).*

Spawn 3 Agent Team workers implementing the same spec independently on separate git worktrees. Evaluation is deterministic where possible (test pass rate, coverage delta, lines changed). Thinktank synthesis as tiebreaker. DMI skill, effort/l.

**Why deferred:** Speculative, high effort, depends on risk tier infrastructure that doesn't exist yet. Re-evaluate after #50 and #34 ship — if parallel subagent infra works well for debug, competition is a natural extension.

## Ideas

### Cross-repo harness sync audit
After core restructuring, repos consuming skills via symlinks may reference old skill names or paths. Need an audit of all repos that depend on agent-skills to verify their CLAUDE.md, AGENTS.md, and .claude/skills/ symlinks are current.

**Signal:** First user report of a broken skill reference in a consuming repo.

### Pack discoverability improvements
`/forage` matches against `pack-index.md` using keyword search. Semantic matching (LLM-based) could improve discovery accuracy for ambiguous queries. The `llm-semantic-match` pack skill exists but isn't wired into forage.

**Signal:** User invokes `/forage` and doesn't find a skill that exists.

### Overlay testing after restructuring
Harness overlays (`overlays/<harness>/<skill>/`) may need updating after the core pruning. No automated test verifies overlays apply correctly to the new skill set.

**Signal:** Harness-specific behavior diverges unexpectedly.

### Skill composition documentation
Skills compose implicitly (e.g., `/calibrate` loads `/forage` and `/research`, `/settle` reads autopilot references). This composition graph isn't documented anywhere. A generated dependency map could help with impact analysis when modifying skills.

**Signal:** Modifying a skill unexpectedly breaks a downstream skill.

### TypeScript skill testing framework
`core/research/` has TypeScript tests. Other skills are untested. A lightweight test framework for skills could validate frontmatter, description constraints, reference file existence, and routing table coverage.

**Signal:** Shipping a skill with broken routing or missing references.

## Parked Themes

### Agent competition and verification depth
Risk tiers (#50) → escalation gates → compete skill → formal verification integration. This is the "pipeline safety" theme. Currently at step 1 (risk tiers). Each step should prove value before building the next.

### Language and platform packs
Go (#35), Convex (#36) are in GitHub Issues. Future candidates: Elixir (already has patterns in agent pack), Swift/iOS, Python. Add packs only when 3+ repos share identical conventions.
