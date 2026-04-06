# /deps skill: semantic dependency management

Priority: medium
Status: done
Estimate: L

## Goal
Agent evaluates, tests, and upgrades dependencies autonomously. Human reviews one curated PR
with analysis, not 47 Dependabot version bumps.

## Non-Goals
- Don't build a package registry or vulnerability scanner
- Don't handle major framework migrations (Rails 6→7, Next 13→14)
- Don't replace lockfile resolution — wrap existing package managers

## Oracle
- [x] `/deps` skill exists with SKILL.md
- [x] Runs reachability analysis: which vulnerabilities actually affect our code paths
- [x] Generates behavioral diff: what changed in dependency behavior, not just version
- [x] Tests pass after upgrade (runs local CI)
- [x] Opens single PR with: changelog summary, reachability report, test results, risk assessment
- [ ] Dependabot/Renovate disabled after skill proves reliable

## What Was Built
- `skills/deps/SKILL.md` (198 lines) — The `/deps` skill with 4-mode routing (audit,
  security, upgrade, report), mode→phase matrix, 6-phase gated workflow (baseline →
  discover → analyze → upgrade → test → report), ecosystem detection table, PR output
  template, and 8 gotchas encoding operational judgment.
- `skills/deps/references/reachability-analysis.md` (137 lines) — Deep-dive on CVE
  reachability: the Endor Labs 92-97% insight, 4-level analysis framework, decision
  tree, ecosystem-specific patterns (esp. Go's `govulncheck` for native reachability).
- `skills/deps/references/behavioral-diff.md` (144 lines) — Socket-inspired behavioral
  analysis: install scripts, network calls, fs access, removed exports, native deps,
  permission escalation. Risk classification table and blocking criteria.

## Workarounds
- Dependabot/Renovate disable is deferred until `/deps` proves reliable in real use.
  Left as the one unchecked oracle item.

## Notes
- Endor Labs: function-level reachability analysis, 92-97% noise reduction
- Socket: behavioral analysis detecting malicious packages
- The gap in current tools: they bump versions. They don't understand if the bump is safe.
- Longer horizon — but high value. Current Dependabot noise is a real friction source.
