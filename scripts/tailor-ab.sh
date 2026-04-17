#!/usr/bin/env bash
# tailor-ab.sh — Phase 5 A/B evaluator for /tailor.
#
# Creates two ephemeral git worktrees at HEAD, runs a canned task in each
# via tailor-ab-spike.sh, applies the 029 scoring rules, emits a verdict
# JSON on stdout. The /tailor skill uses this as the rollback gate before
# writing manifest.json.
#
# The two worktrees differ only in their project-level harness layer:
#   baseline — .claude/, AGENTS.md, CLAUDE.md removed (global-only agent)
#   tailored — same baseline strip, then the generated bundle overlaid
#
# This is the right comparison: does project-level tailoring beat the
# global agent on this repo? Shared codebase under test; only the
# harness layer differs.
#
# Usage:
#   scripts/tailor-ab.sh <task_prompt> <tailored_bundle_dir>
#
# Args:
#   task_prompt          — canned task (quoted). Derived from ci-inspector
#                          output in /tailor Phase 1. Example:
#                          "Run the test suite and report failing tests."
#   tailored_bundle_dir  — directory containing generated tailoring
#                          artifacts (.claude/, AGENTS.md, CLAUDE.md).
#                          Copied verbatim into the tailored worktree.
#
# Output (stdout, JSON):
#   {
#     "verdict": "ship" | "rollback",
#     "reason": "...one-line explanation...",
#     "baseline": {"tool_calls": N, "wall_s": F, "passed": BOOL},
#     "tailored": {"tool_calls": N, "wall_s": F, "passed": BOOL},
#     "deltas":  {"tool_calls": "B|A|T", "wall_s": "B|A|T", "passed": "B|A|T"}
#   }
#
# Exit codes:
#   0 — ship (tailored won the A/B per scoring rules)
#   1 — rollback (tailored did not win)
#   2 — usage error or infrastructure failure (bad args, not a git repo,
#       worktree creation failed, spike returned malformed JSON, …)
#
# Env:
#   TAILOR_AB_BUDGET_USD    — per-run cost cap, passed through to spike
#   TAILOR_AB_BASELINE_STUB — if set, skip baseline run and use this JSON
#   TAILOR_AB_TAILORED_STUB — if set, skip tailored run and use this JSON
#
# The STUB vars exist for tests. In production they are unset and both
# runs go through the spike against real worktrees.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPIKE="$SCRIPT_DIR/tailor-ab-spike.sh"

if [ $# -lt 2 ]; then
  printf 'usage: %s <task_prompt> <tailored_bundle_dir>\n' "$0" >&2
  exit 2
fi

TASK="$1"
BUNDLE="$2"

if [ ! -d "$BUNDLE" ]; then
  printf 'tailor-ab: bundle dir does not exist: %s\n' "$BUNDLE" >&2
  exit 2
fi

# $BUNDLE must contain at least one of .claude/, AGENTS.md, CLAUDE.md,
# otherwise "tailored" is structurally identical to "baseline" and the
# A/B is meaningless.
has_artifact=0
for item in .claude AGENTS.md CLAUDE.md; do
  [ -e "$BUNDLE/$item" ] && has_artifact=1
done
if [ "$has_artifact" -eq 0 ]; then
  printf 'tailor-ab: bundle contains no tailoring artifacts (.claude/, AGENTS.md, CLAUDE.md)\n' >&2
  exit 2
fi

GIT_DIR="$(git rev-parse --git-common-dir 2>/dev/null)" || {
  printf 'tailor-ab: not a git repository\n' >&2
  exit 2
}

AB_ROOT="$GIT_DIR/tailor-ab-$$"
BASELINE_WT="$AB_ROOT/baseline"
TAILORED_WT="$AB_ROOT/tailored"

cleanup() {
  # --force handles the case where a run left the worktree in an odd
  # state. Silence stderr because we don't want cleanup noise on the
  # normal path; trust `git worktree prune` to reconcile the registry.
  git worktree remove --force "$BASELINE_WT" 2>/dev/null || true
  git worktree remove --force "$TAILORED_WT" 2>/dev/null || true
  rm -rf "$AB_ROOT"
  git worktree prune 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$AB_ROOT"

# --detach: both worktrees are anonymous (no branch), so this script
# does not interfere with the user's active branch set.
git worktree add --detach "$BASELINE_WT" HEAD >/dev/null 2>&1 || {
  printf 'tailor-ab: failed to create baseline worktree\n' >&2
  exit 2
}
git worktree add --detach "$TAILORED_WT" HEAD >/dev/null 2>&1 || {
  printf 'tailor-ab: failed to create tailored worktree\n' >&2
  exit 2
}

# Baseline: strip any project-local harness that was committed to HEAD.
# Global ~/.claude still loads — that's the "vanilla" agent we're
# comparing tailored against.
( cd "$BASELINE_WT" && rm -rf .claude AGENTS.md CLAUDE.md )

# Tailored: same strip, then overlay the bundle.
( cd "$TAILORED_WT" && rm -rf .claude AGENTS.md CLAUDE.md )
for item in .claude AGENTS.md CLAUDE.md; do
  if [ -e "$BUNDLE/$item" ]; then
    cp -R "$BUNDLE/$item" "$TAILORED_WT/"
  fi
done

# Run measurements (stubbable for tests).
if [ -n "${TAILOR_AB_BASELINE_STUB:-}" ]; then
  baseline_json="$TAILOR_AB_BASELINE_STUB"
else
  baseline_json=$(TAILOR_AB_CWD="$BASELINE_WT" "$SPIKE" "$TASK") || {
    printf 'tailor-ab: baseline run failed\n' >&2
    exit 2
  }
fi

if [ -n "${TAILOR_AB_TAILORED_STUB:-}" ]; then
  tailored_json="$TAILOR_AB_TAILORED_STUB"
else
  tailored_json=$(TAILOR_AB_CWD="$TAILORED_WT" "$SPIKE" "$TASK") || {
    printf 'tailor-ab: tailored run failed\n' >&2
    exit 2
  }
fi

# Score and emit verdict. Python gets the two metric JSONs via env
# (simpler than argv for strings that may contain shell metachars).
export BASELINE_JSON="$baseline_json"
export TAILORED_JSON="$tailored_json"

set +e
python3 -c '
import json, os, sys

try:
    baseline = json.loads(os.environ["BASELINE_JSON"])
    tailored = json.loads(os.environ["TAILORED_JSON"])
except (KeyError, json.JSONDecodeError) as e:
    print(f"tailor-ab: malformed metrics JSON: {e}", file=sys.stderr)
    sys.exit(2)

for side, d in (("baseline", baseline), ("tailored", tailored)):
    for key in ("tool_calls", "wall_s", "passed"):
        if key not in d:
            print(f"tailor-ab: {side} missing key: {key}", file=sys.stderr)
            sys.exit(2)

# Per-metric ternary verdicts: "B" (tailored wins), "A" (baseline
# wins), "T" (tie). Rationale for rules in 029 Implementation Notes
# → A/B scoring section.
def ternary_tool_calls(a, b):
    if b < a: return "B"
    if b > a: return "A"
    return "T"

def ternary_wall_s(a, b):
    if a <= 0:
        # Degenerate baseline; treat as tie rather than divide-by-zero.
        return "T"
    if b < a * 0.95: return "B"
    if b > a * 1.05: return "A"
    return "T"

def ternary_passed(a, b):
    if b and not a: return "B"
    if a and not b: return "A"
    return "T"

v_tool = ternary_tool_calls(baseline["tool_calls"], tailored["tool_calls"])
v_wall = ternary_wall_s(baseline["wall_s"], tailored["wall_s"])
v_pass = ternary_passed(baseline["passed"], tailored["passed"])

verdicts = [v_tool, v_wall, v_pass]
b_wins = verdicts.count("B")
a_wins = verdicts.count("A")

# Aggregate rule: tailored ships iff ≥2 B-wins AND no A-win.
# Stricter than "not-worse-than-A" to avoid shipping noise-equivalent
# tailoring. Cost of bad harness >> cost of rollback.
if b_wins >= 2 and a_wins == 0:
    verdict = "ship"
    reason = f"{b_wins}/3 metrics favor tailored, no regressions"
elif a_wins > 0:
    verdict = "rollback"
    regressed = [m for m, v in zip(("tool_calls", "wall_s", "passed"), verdicts) if v == "A"]
    reason = "tailored regressed on: " + ", ".join(regressed)
else:
    verdict = "rollback"
    reason = f"only {b_wins}/3 metrics favor tailored (need ≥2)"

out = {
    "verdict": verdict,
    "reason": reason,
    "baseline": baseline,
    "tailored": tailored,
    "deltas": {
        "tool_calls": v_tool,
        "wall_s": v_wall,
        "passed": v_pass,
    },
}
print(json.dumps(out, indent=2))
sys.exit(0 if verdict == "ship" else 1)
'
rc=$?
set -e
exit "$rc"
