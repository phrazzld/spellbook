# /deps skill: semantic dependency management

Priority: medium
Status: in-progress
Estimate: L

## Goal
Agent evaluates, tests, and upgrades dependencies autonomously. Human reviews one curated PR
with analysis, not 47 Dependabot version bumps.

## Non-Goals
- Don't build a package registry or vulnerability scanner
- Don't handle major framework migrations (Rails 6→7, Next 13→14)
- Don't replace lockfile resolution — wrap existing package managers

## Oracle
- [ ] `/deps` skill exists with SKILL.md
- [ ] Runs reachability analysis: which vulnerabilities actually affect our code paths
- [ ] Generates behavioral diff: what changed in dependency behavior, not just version
- [ ] Tests pass after upgrade (runs local CI)
- [ ] Opens single PR with: changelog summary, reachability report, test results, risk assessment
- [ ] Dependabot/Renovate disabled after skill proves reliable

## Notes
- Endor Labs: function-level reachability analysis, 92-97% noise reduction
- Socket: behavioral analysis detecting malicious packages
- The gap in current tools: they bump versions. They don't understand if the bump is safe.
- Longer horizon — but high value. Current Dependabot noise is a real friction source.
