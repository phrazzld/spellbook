# Strengthen skill instructions — zero-cost enforcement

Priority: high
Status: done
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
- [x] Reading each SKILL.md confirms the new language is present
- [x] No computational overhead (no hooks, no gates — just text)
- [x] Language is clear enough that an agent following it would enforce the behavior

## What Was Built
- `agents/builder.md` — TDD principle expanded from one sentence to full mandate with
  explicit exceptions (config, generated code, UI layout) and a "stop and write the test" trigger.
- `skills/autopilot/SKILL.md` — Two additions: (1) Step 4 now mandates TDD language in
  every builder dispatch prompt, (2) Step 9 adds an evidence gate before PR creation.
- `skills/settle/SKILL.md` — Phase 1 adds step 6: merge-readiness verification via
  `gh pr view --json reviews,statusCheckRollup` before proceeding to polish.
