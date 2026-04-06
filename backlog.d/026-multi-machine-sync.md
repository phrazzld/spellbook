# Multi-machine sync for claims and verdicts

Priority: low
Status: pending
Estimate: M

## Goal

Enable `refs/verdicts/*` and agent claim locks to sync across machines via
`git push`/`git fetch`. Currently claims are local-only (file locks in
`.git-bug-claims/`). Verdicts (from 020) will also be local refs.

## Design

- Push verdicts: `git push origin 'refs/verdicts/*'`
- Fetch verdicts: `git fetch origin 'refs/verdicts/*:refs/verdicts/*'`
- Push claims: Extend `source scripts/lib/claims.sh` to use git refs instead
  of local file locks
- Conflict resolution: last-writer-wins for claims (agent coordination is
  best-effort), verdict refs are immutable once written

## Oracle

- [ ] Verdict created on machine A is visible on machine B after fetch
- [ ] Claim acquired on machine A blocks same claim on machine B
- [ ] Works with any git remote (not GitHub-specific)

## Non-Goals

- Real-time sync (polling/push is sufficient)
- Distributed consensus protocol
