#!/usr/bin/env bash
# Tests for .githooks/pre-merge-commit — verdict gate on non-FF merges.
# Runs in a temporary git repo with the hook installed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0

setup() {
  ORIG_DIR="$(pwd)"
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
  git init -q
  git commit --allow-empty -m "initial on master" -q

  # Install the hook
  mkdir -p .githooks
  cp "$REPO_ROOT/.githooks/pre-merge-commit" .githooks/pre-merge-commit
  chmod +x .githooks/pre-merge-commit
  git config core.hooksPath .githooks

  # Symlink verdicts.sh so the hook can source it
  mkdir -p scripts/lib
  ln -s "$REPO_ROOT/scripts/lib/verdicts.sh" scripts/lib/verdicts.sh

  # Create a divergent feature branch (so --no-ff produces a merge commit)
  git checkout -b feat-x -q
  git commit --allow-empty -m "feat work" -q
  git checkout master -q
  git commit --allow-empty -m "master diverges" -q
}

teardown() {
  cd "$ORIG_DIR"
  rm -rf "$TEST_DIR"
}

assert_exit() {
  local desc="$1" expected="$2"
  shift 2
  local actual
  if "$@" >/dev/null 2>&1; then actual=0; else actual=$?; fi
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "  PASS  $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL  $desc (expected exit $expected, got $actual)"
  fi
}

write_verdict() {
  local branch="$1" verdict_value="$2"
  local sha
  sha="$(git rev-parse "$branch")"
  source scripts/lib/verdicts.sh
  local json='{"branch":"'"$branch"'","base":"master","verdict":"'"$verdict_value"'","reviewers":["critic"],"scores":{"correctness":8},"sha":"'"$sha"'","date":"2026-04-06T15:00:00Z"}'
  verdict_write "$branch" "$json"
}

# --- Tests ---

test_merge_blocked_no_verdict() {
  assert_exit "merge blocked without verdict" 1 git merge --no-ff feat-x
}

test_merge_blocked_dont_ship() {
  write_verdict feat-x dont-ship
  assert_exit "merge blocked with dont-ship verdict" 1 git merge --no-ff feat-x
}

test_merge_allowed_ship() {
  write_verdict feat-x ship
  assert_exit "merge allowed with ship verdict" 0 git merge --no-ff feat-x
}

test_merge_bypass_env() {
  assert_exit "merge bypasses with SPELLBOOK_NO_REVIEW=1" 0 \
    env SPELLBOOK_NO_REVIEW=1 git merge --no-ff feat-x
}

# --- Runner ---

run_tests() {
  local funcs
  funcs="$(declare -F | awk '/test_merge_/{print $3}')"
  for t in $funcs; do
    setup
    "$t"
    teardown
  done

  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ]
}

run_tests
