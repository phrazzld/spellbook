# Code review evolution — live verification + persistent scoring

Priority: medium
Status: done
Estimate: M

## Goal

Two enhancements to /code-review that close quality gaps:

### A. Live verification mandate
The critic cannot emit "Ship" for user-facing changes without exercising affected routes. Already described in code-review SKILL.md section 4 — make it non-optional when the diff touches routes, components, or endpoints.

### B. Persistent scoring
Each review appends structured scores to `.groom/review-scores.ndjson`:
```json
{"date": "2026-03-30", "pr": 42, "correctness": 8, "depth": 7, "simplicity": 9, "craft": 8, "verdict": "ship"}
```
/groom's Velocity investigator reads this for quality trends. Turns review from a gate into a feedback loop.

## Non-Goals
- Don't change the reviewer bench composition (critic + ousterhout + carmack + grug + beck)
- Don't add external scoring tools — append-only NDJSON is sufficient

## Oracle
- [x] Code review on a PR touching a React component triggers live verification
- [x] Code review on a pure refactor skips live verification
- [x] After a review, `.groom/review-scores.ndjson` has a new entry
- [x] `/groom` Velocity investigator reads and reports on score trends

## What Was Built

Pure skill instruction changes across 4 files:
- **code-review SKILL.md**: Added Live Verification section (hard gate on user-facing diffs, skip for refactors) and Review Scoring section (NDJSON append after every review)
- **investigation-bench.md**: Velocity investigator now reads `.groom/review-scores.ndjson` for quality trend analysis
- **groom SKILL.md**: Context Loading step 5 reads review-scores.ndjson as baseline for investigators
