#!/usr/bin/env bash
# Distribution smoke test: verifies flywheel.sh is self-contained when
# symlinked from a project's .claude/skills/flywheel/ (the bootstrap install).
#
# Invariant: invoking the symlinked script from a foreign git project must
# succeed without any path reaching back into the spellbook source tree.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPELLBOOK_FLYWHEEL="$(cd "$SCRIPT_DIR/.." && pwd)"  # skills/flywheel/
PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "  PASS  $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL  $desc (expected '$expected', got '$actual')"
  fi
}

# --- Test ---

test_symlinked_install_help_exits_0_and_mentions_flywheel() {
  local proj="$TMPDIR/flywheel-dist-test-$$"
  mkdir -p "$proj"

  # Minimal git repo so STATE_ROOT resolves to $proj.
  git -C "$proj" init -q
  git -C "$proj" commit --allow-empty -q -m "init" \
    --author="test <test@test>" 2>/dev/null || true

  # Symlink skills/flywheel into the fake project's .claude/skills/flywheel.
  mkdir -p "$proj/.claude/skills"
  ln -s "$SPELLBOOK_FLYWHEEL" "$proj/.claude/skills/flywheel"

  local symlinked_sh="$proj/.claude/skills/flywheel/scripts/flywheel.sh"
  local rc=0 output=""

  # Invoke --help from within the fake project.
  output="$(cd "$proj" && bash "$symlinked_sh" --help 2>&1)" || rc=$?

  # --help exits 0.
  assert_eq "symlinked --help exits 0" "0" "$rc"

  # Help text mentions /flywheel.
  if echo "$output" | grep -q '/flywheel'; then
    assert_eq "help text mentions /flywheel" "ok" "ok"
  else
    assert_eq "help text mentions /flywheel" "ok" "missing"
  fi

  # No cycle dirs were created under the fake project.
  assert_eq "no cycles dir created by --help" "no" \
    "$([ -d "$proj/backlog.d/_cycles" ] && echo yes || echo no)"

  # Cleanup.
  /usr/bin/trash "$proj" 2>/dev/null || true
}

# --- Runner ---
test_symlinked_install_help_exits_0_and_mentions_flywheel

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
