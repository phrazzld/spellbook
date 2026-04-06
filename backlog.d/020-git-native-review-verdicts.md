# Git-native review verdicts — replace PR approval state

Priority: high
Status: pending
Estimate: M

## Goal

Create a git-native mechanism for storing code review verdicts as Git objects,
replacing GitHub PR approval as the proof-of-review. This is the keystone
primitive that unlocks Dagger-only CI, default swarm review, and offline
development.

## Design

Store verdicts under `refs/verdicts/<branch>`:
```
refs/verdicts/feat-foo → blob containing:
  {
    "branch": "feat-foo",
    "base": "master",
    "verdict": "ship",
    "reviewers": ["critic", "ousterhout", "carmack", "grug", "beck"],
    "scores": {"correctness": 8, "depth": 7, "simplicity": 9, "craft": 8},
    "sha": "abc123",  // commit SHA at time of review
    "date": "2026-04-06T15:00:00Z"
  }
```

## Integration Points

- `/code-review` writes verdict ref after synthesizing reviewer scores
- `/land` (new) reads verdict ref to gate merge
- `git push origin refs/verdicts/*` syncs verdicts across machines
- Pre-merge hook validates verdict ref exists and SHA matches HEAD

## Oracle

- [ ] `/code-review` on a branch produces a `refs/verdicts/<branch>` ref
- [ ] Verdict is a valid JSON blob with all required fields
- [ ] `git log --all` shows verdict refs
- [ ] Verdict refs survive push/pull across remotes

## Non-Goals

- Human dispute resolution (separate item)
- Multi-repo federation
- Web UI for verdict browsing
