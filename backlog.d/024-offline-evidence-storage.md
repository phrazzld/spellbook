# Offline evidence and artifact storage in Git

Priority: medium
Status: pending
Estimate: S

## Goal

Replace GitHub releases/draft releases as the evidence storage mechanism with
a git-native approach. QA screenshots, demo GIFs, and review artifacts should
live in Git, not GitHub.

## Why

The `/demo` skill currently uploads evidence to GitHub draft releases. This
breaks offline-first and creates GitHub coupling. Evidence should be
inspectable with standard Git tools.

## Design Options

1. **Git notes**: Attach evidence metadata to commits via `git notes`
2. **Git LFS**: Store binary artifacts (screenshots, GIFs) in LFS, reference
   from commit messages or verdict refs
3. **`.evidence/` directory**: Simple directory with artifacts named by
   branch/date, gitignored binaries tracked via LFS

## Oracle

- [ ] `/demo` can store evidence without GitHub API calls
- [ ] Evidence is retrievable from a fresh clone
- [ ] Evidence is associated with the branch/commit that produced it
- [ ] Works fully offline

## Non-Goals

- Replacing all GitHub API usage (just evidence storage)
- Building a media server
