#!/usr/bin/env bash
set -euo pipefail

# Gather evidence for /reflect session retrospective.
# Usage: gather_evidence.sh [N]  (default: 10 commits)

N=${1:-10}

echo "## Recent Commits"
git log --oneline -"$N"

echo ""
echo "## Changed Files"
git diff --stat "HEAD~$N"

echo ""
echo "## Uncommitted"
git status --short
