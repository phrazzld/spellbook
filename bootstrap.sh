#!/usr/bin/env bash
set -euo pipefail

# Spellbook Bootstrap
# Installs global skills for each detected agent harness.
# Global skills: focus, research, calibrate, reflect, skill
# These are meta-process skills useful in any context. Everything else is project-local via /focus.
# Run: curl -sL https://raw.githubusercontent.com/phrazzld/spellbook/main/bootstrap.sh | bash

REPO="phrazzld/spellbook"
RAW="https://raw.githubusercontent.com/$REPO/main"

info()  { printf '\033[0;34m%s\033[0m\n' "$*"; }
ok()    { printf '\033[0;32m%s\033[0m\n' "$*"; }
warn()  { printf '\033[0;33m%s\033[0m\n' "$*"; }
err()   { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }

install_focus() {
  local target="$1/focus"
  mkdir -p "$target/references/harnesses"

  curl -sfL "$RAW/skills/focus/SKILL.md" -o "$target/SKILL.md" || { err "Failed to download focus/SKILL.md"; return 1; }

  for ref in claude-code codex; do
    curl -sfL "$RAW/skills/focus/references/harnesses/$ref.md" -o "$target/references/harnesses/$ref.md" 2>/dev/null || true
  done
  for ref in init sync search improve; do
    curl -sfL "$RAW/skills/focus/references/$ref.md" -o "$target/references/$ref.md" 2>/dev/null || true
  done

  ok "  focus → $target"
}

install_research() {
  local target="$1/research"
  mkdir -p "$target/references"

  curl -sfL "$RAW/skills/research/SKILL.md" -o "$target/SKILL.md" || { err "Failed to download research/SKILL.md"; return 1; }

  for ref in web-search delegate thinktank introspect readwise exa-tools xai-search; do
    curl -sfL "$RAW/skills/research/references/$ref.md" -o "$target/references/$ref.md" 2>/dev/null || true
  done

  ok "  research → $target"
}

install_simple_skill() {
  # For skills with just SKILL.md + references/*.md (no nested dirs)
  local skills_dir="$1"
  local name="$2"
  local target="$skills_dir/$name"
  mkdir -p "$target/references"

  curl -sfL "$RAW/skills/$name/SKILL.md" -o "$target/SKILL.md" || { err "Failed to download $name/SKILL.md"; return 1; }

  # Best-effort download of references
  refs=$(curl -sf "https://api.github.com/repos/$REPO/contents/skills/$name/references" 2>/dev/null | \
    python3 -c "import sys,json; [print(f['name']) for f in json.load(sys.stdin) if f['type']=='file']" 2>/dev/null) || true
  if [ -n "$refs" ]; then
    echo "$refs" | while read fname; do
      curl -sfL "$RAW/skills/$name/references/$fname" -o "$target/references/$fname" 2>/dev/null || true
    done
  fi

  ok "  $name → $target"
}

install_globals() {
  local skills_dir="$1"
  install_focus "$skills_dir"
  install_research "$skills_dir"
  install_simple_skill "$skills_dir" "calibrate"
  install_simple_skill "$skills_dir" "reflect"
  install_simple_skill "$skills_dir" "skill"
}

info "Spellbook Bootstrap"
info "Installing global skills..."
echo

installed=0

# Claude Code
if [ -d "$HOME/.claude" ] || command -v claude &>/dev/null; then
  info "Detected: Claude Code"
  install_globals "$HOME/.claude/skills"
  installed=$((installed + 1))
fi

# Codex
if [ -d "$HOME/.codex" ] || command -v codex &>/dev/null; then
  info "Detected: Codex"
  install_globals "$HOME/.codex/skills"
  installed=$((installed + 1))
fi

# Agents (generic .agents convention)
if [ -d "$HOME/.agents" ]; then
  info "Detected: .agents"
  install_globals "$HOME/.agents/skills"
  installed=$((installed + 1))
fi

# Pi
if [ -d "$HOME/.pi" ] || command -v pi &>/dev/null; then
  info "Detected: Pi"
  install_globals "$HOME/.pi/skills"
  installed=$((installed + 1))
fi

echo
if [ "$installed" -eq 0 ]; then
  warn "No agent harnesses detected."
  warn "Installing to ~/.claude/skills/ as default."
  install_globals "$HOME/.claude/skills"
  installed=1
fi

ok "Done. Installed global skills to $installed harness(es)."
echo
info "Global skills: focus, research, calibrate, reflect, skill"
info "Everything else is project-local via /focus."
echo
info "Next steps:"
info "  1. Open any project"
info "  2. Run /focus to initialize"
info "  3. Edit .spellbook.yaml to customize"
