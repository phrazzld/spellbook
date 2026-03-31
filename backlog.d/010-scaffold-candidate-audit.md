# Identify scaffold candidates across all skills

Priority: low
Status: in-progress
Estimate: S

## Goal

Review all global skills for repo-specificity. Classify each as: stays global, becomes scaffold, or reads project config.

## Candidates to Evaluate

| Skill | Hypothesis | Question |
|-------|-----------|----------|
| debug | Partially repo-specific | Incident response (Sentry, log locations, service topology) varies. Generic debugging patterns are transferable. Config file vs scaffold? |
| agent-readiness | Partially repo-specific | Pillar checks are generic. Recommended fixes (which linter, test framework, CI) are repo-specific. Config file? |
| deps | Partially repo-specific | Package manager detection is generic. Reachability analysis patterns vary. Generic enough? |
| code-review | Generic | Reviewer bench works across repos. Live verification needs project context — config file? |
| settle | Generic | PR lifecycle is universal. |
| autopilot | Generic | Delivery pipeline is universal. |

## Oracle
- [ ] Classification table complete: each skill marked as global / scaffold / config-driven
- [ ] For each "scaffold" or "config" candidate: specific rationale for what's repo-specific
- [ ] Recommendations don't bloat the skill count — prefer config over scaffold where possible
