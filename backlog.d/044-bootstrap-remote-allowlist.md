# Bootstrap remote-install path — honor `.spellbook.yaml` allowlist

Priority: P2
Status: pending
Estimate: XS

Follow-up to 043. The allowlist filter landed in 043 intersects
`GLOBAL_SKILLS[]` and `EXTERNAL_SKILLS[]` after `discover_local()` —
local-checkout path only. The remote-download path (`discover_remote()`
→ `install_remote()`) does not read `.spellbook.yaml` and always
installs the full catalog from GitHub.

## Shape

In `install_remote()` (around line 495-507 of `bootstrap.sh`), apply
the same `ALLOWLIST_ACTIVE` filter that local already uses. The
allowlist parsing already happens once globally before either path
runs (post-`discover_remote` as well as post-`discover_local`) — only
the filter application is local-only today. Confirm that in the diff
and widen it.

## Oracle

- [ ] On a machine without a spellbook checkout, running
      `curl -sL ...bootstrap.sh | bash` from a project directory with
      `.spellbook.yaml` installs only the allowlisted subset.
- [ ] Unknown names in allowlist warn and drop (same as local).
- [ ] `scripts/test-bootstrap-filter.sh` gains a case that exercises
      the remote path (or documents why the existing cases suffice
      because the filter is shared).

## Non-Goals

- Introducing per-harness runtime toggles — remains the filesystem
  layer only.
- Changes to what remote discovery sources (still GitHub API).

## Why P2

Remote install is the minority path; local-checkout is the primary
development flow. Every user currently dogfooding the allowlist is
on local-checkout. Worth closing before the doctrine becomes "most of
spellbook honors your allowlist, except one path."
