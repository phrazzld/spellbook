#!/usr/bin/env bash
# Idempotent git-bug setup: install, configure identity, configure GitHub bridge.
# Safe to re-run — each step checks before acting.
set -euo pipefail

# --- Install ---
if ! command -v git-bug &>/dev/null; then
  echo "Installing git-bug via Homebrew..."
  brew install git-bug
else
  echo "git-bug already installed: $(git-bug version)"
fi

# --- Verify we're in a git repo ---
if ! git rev-parse --git-dir &>/dev/null; then
  echo "Error: not in a git repository" >&2
  exit 1
fi

# --- User identity ---
if git-bug user 2>/dev/null | grep -q '^'; then
  echo "git-bug user identity already configured"
else
  NAME="$(git config user.name)"
  EMAIL="$(git config user.email)"
  echo "Creating git-bug identity: $NAME <$EMAIL>"
  git-bug user new --name "$NAME" --email "$EMAIL" --non-interactive
fi

# --- GitHub bridge ---
if git-bug bridge 2>/dev/null | grep -q github; then
  echo "GitHub bridge already configured"
else
  # Derive owner/project from git remote
  REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
  if [ -z "$REMOTE_URL" ]; then
    echo "Warning: no origin remote — skipping bridge setup" >&2
    exit 0
  fi

  # Extract owner/project from SSH or HTTPS URL
  OWNER="$(echo "$REMOTE_URL" | sed -E 's#.*(github\.com[:/])([^/]+)/.*#\2#')"
  PROJECT="$(echo "$REMOTE_URL" | sed -E 's#.*(github\.com[:/])[^/]+/([^/.]+)(\.git)?$#\2#')"

  if [ -z "$OWNER" ] || [ -z "$PROJECT" ]; then
    echo "Warning: could not parse owner/project from remote URL: $REMOTE_URL" >&2
    exit 0
  fi

  # Get token from gh CLI
  TOKEN="$(gh auth token 2>/dev/null || true)"
  if [ -z "$TOKEN" ]; then
    echo "Warning: no GitHub token (run 'gh auth login' first) — skipping bridge" >&2
    exit 0
  fi

  echo "Configuring GitHub bridge: $OWNER/$PROJECT"
  git-bug bridge new \
    --name github \
    --target github \
    --owner "$OWNER" \
    --project "$PROJECT" \
    --token "$TOKEN" \
    --non-interactive
fi

echo "git-bug setup complete."
