# Strengthen skill instructions — zero-cost enforcement

Priority: high
Status: ready
Estimate: S

## Goal

Encode behavioral guidance directly in skill SKILL.md files and AGENTS.md. Zero computational cost — read once per invocation, works across all harnesses.

## Changes

### agents/builder.md
- Strengthen TDD sequence: "You MUST write a failing test before writing production code. The only exceptions: config files, generated code, UI layout. If you find yourself writing production code without a red test, stop and write the test first."

### skills/autopilot/SKILL.md
- Step 9 (Ship): Add evidence check before `gh pr create` — "Before opening the PR, verify evidence artifacts exist. If no screenshots/GIFs/terminal captures are present, invoke /demo first."
- Builder dispatch: Include explicit TDD instruction in the builder's prompt

### skills/settle/SKILL.md
- Phase 1: Add merge-readiness verification — "Before declaring merge-ready, verify: `gh pr view --json reviews,statusCheckRollup` shows at least one approving review and all checks passing."

## Oracle
- [ ] Reading each SKILL.md confirms the new language is present
- [ ] No computational overhead (no hooks, no gates — just text)
- [ ] Language is clear enough that an agent following it would enforce the behavior
