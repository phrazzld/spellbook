# Expand git hooks — harness-agnostic enforcement

Priority: medium
Status: ready
Estimate: S

## Goal

Add git hooks that enforce quality at commit/push time, replacing Claude-specific hooks. Install via bootstrap.sh.

## Hooks to Add

### git-hooks/pre-commit
- Regenerate `index.yaml` (CLAUDE.md says pre-commit does this — verify and ensure it's actually installed)
- Stage the regenerated file so it's included in the commit

### git-hooks/pre-push (enhancement)
- Add branch protection: block pushes to main/master (replaces `block-master-push.py` Claude hook)
- Keep existing Dagger gate check

## Non-Goals
- Don't add hooks that slow down commits significantly (keep pre-commit < 2s)
- Don't duplicate what Dagger already checks

## Oracle
- [ ] `git commit` in spellbook repo regenerates index.yaml automatically
- [ ] `git push origin master` is blocked by pre-push hook with clear error message
- [ ] `git push origin feature-branch` succeeds (Dagger gates pass)
- [ ] bootstrap.sh installs both hooks
