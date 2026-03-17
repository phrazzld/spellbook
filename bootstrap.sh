#!/usr/bin/env bash
set -euo pipefail

# Spellbook Bootstrap
# Installs global process skills and agents for each detected agent harness.
#
# Global skills (13): autopilot, calibrate, context-engineering, debug, focus,
#   groom, harness-engineering, moonshot, pr, reflect, research, settle, skill
# Global agents (4): beck, carmack, grug, ousterhout
#
# These are process/methodology primitives useful in any context.
# Domain skills (stripe, next-patterns, etc.) are project-local via /focus.
#
# Run: curl -sL https://raw.githubusercontent.com/phrazzld/spellbook/master/bootstrap.sh | bash

REPO="phrazzld/spellbook"
RAW="https://raw.githubusercontent.com/$REPO/master"

info()  { printf '\033[0;34m%s\033[0m\n' "$*"; }
ok()    { printf '\033[0;32m%s\033[0m\n' "$*"; }
warn()  { printf '\033[0;33m%s\033[0m\n' "$*"; }
err()   { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }

# --- Skill Installers ---

install_focus() {
  local target="$1/focus"
  mkdir -p "$target/references/harnesses" "$target/scripts"

  curl -sfL "$RAW/skills/focus/SKILL.md" -o "$target/SKILL.md" || { err "Failed to download focus/SKILL.md"; return 1; }

  for ref in claude-code codex; do
    curl -sfL "$RAW/skills/focus/references/harnesses/$ref.md" -o "$target/references/harnesses/$ref.md" 2>/dev/null || true
  done
  for ref in init sync search improve; do
    curl -sfL "$RAW/skills/focus/references/$ref.md" -o "$target/references/$ref.md" 2>/dev/null || true
  done

  curl -sfL "$RAW/skills/focus/scripts/search.py" -o "$target/scripts/search.py" 2>/dev/null || true

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
  local skills_dir="$1"
  local name="$2"
  local target="$skills_dir/$name"
  mkdir -p "$target/references"

  curl -sfL "$RAW/skills/$name/SKILL.md" -o "$target/SKILL.md" || { err "Failed to download $name/SKILL.md"; return 1; }

  # Best-effort: download references via GitHub API
  refs=$(curl -sf "https://api.github.com/repos/$REPO/contents/skills/$name/references" 2>/dev/null | \
    python3 -c "import sys,json; [print(f['name']) for f in json.load(sys.stdin) if f['type']=='file']" 2>/dev/null) || true
  if [ -n "$refs" ]; then
    echo "$refs" | while read -r fname; do
      curl -sfL "$RAW/skills/$name/references/$fname" -o "$target/references/$fname" 2>/dev/null || true
    done
  fi

  # Best-effort: download nested reference directories (up to 2 levels deep)
  nested=$(curl -sf "https://api.github.com/repos/$REPO/contents/skills/$name/references" 2>/dev/null | \
    python3 -c "import sys,json; [print(f['name']) for f in json.load(sys.stdin) if f['type']=='dir']" 2>/dev/null) || true
  if [ -n "$nested" ]; then
    echo "$nested" | while read -r dname; do
      mkdir -p "$target/references/$dname"
      # Download files at this level
      nfiles=$(curl -sf "https://api.github.com/repos/$REPO/contents/skills/$name/references/$dname" 2>/dev/null | \
        python3 -c "import sys,json; [print(f['name']) for f in json.load(sys.stdin) if f['type']=='file']" 2>/dev/null) || true
      [ -n "$nfiles" ] && echo "$nfiles" | while read -r nfname; do
        curl -sfL "$RAW/skills/$name/references/$dname/$nfname" -o "$target/references/$dname/$nfname" 2>/dev/null || true
      done
      # Download subdirectories (second level — e.g. audit-checklists/growth/*.md)
      subdirs=$(curl -sf "https://api.github.com/repos/$REPO/contents/skills/$name/references/$dname" 2>/dev/null | \
        python3 -c "import sys,json; [print(f['name']) for f in json.load(sys.stdin) if f['type']=='dir']" 2>/dev/null) || true
      [ -n "$subdirs" ] && echo "$subdirs" | while read -r sdname; do
        mkdir -p "$target/references/$dname/$sdname"
        sdfiles=$(curl -sf "https://api.github.com/repos/$REPO/contents/skills/$name/references/$dname/$sdname" 2>/dev/null | \
          python3 -c "import sys,json; [print(f['name']) for f in json.load(sys.stdin) if f['type']=='file']" 2>/dev/null) || true
        [ -n "$sdfiles" ] && echo "$sdfiles" | while read -r sdfname; do
          curl -sfL "$RAW/skills/$name/references/$dname/$sdname/$sdfname" -o "$target/references/$dname/$sdname/$sdfname" 2>/dev/null || true
        done
      done
    done
  fi

  ok "  $name → $target"
}

# --- Agent Installer ---

install_agent() {
  local agents_dir="$1"
  local name="$2"
  mkdir -p "$agents_dir"

  curl -sfL "$RAW/agents/$name.md" -o "$agents_dir/$name.md" || { err "Failed to download agent $name"; return 1; }

  ok "  $name → $agents_dir/$name.md"
}

# --- Orchestration ---

# Bootstrap-installed primitives intentionally have NO .spellbook marker.
# Markers denote /focus-managed (project-local) primitives. Global skills
# are never nuked/rebuilt by /focus — they're managed by bootstrap alone.

# Global process skills — always available in every session
GLOBAL_SKILLS=(
  autopilot
  calibrate
  context-engineering
  debug
  groom
  harness-engineering
  moonshot
  pr
  reflect
  settle
  skill
)

# Global agents — design philosophy lenses
GLOBAL_AGENTS=(
  beck
  carmack
  grug
  ousterhout
)

install_globals() {
  local skills_dir="$1"
  local agents_dir="$2"

  # Skills with custom installers (complex directory structures)
  install_focus "$skills_dir"
  install_research "$skills_dir"

  # Skills with standard layout
  for skill in "${GLOBAL_SKILLS[@]}"; do
    install_simple_skill "$skills_dir" "$skill"
  done

  # Agents
  info "  Installing agents..."
  for agent in "${GLOBAL_AGENTS[@]}"; do
    install_agent "$agents_dir" "$agent"
  done
}

# Map harness to its agents directory
agents_dir_for() {
  local harness="$1"
  case "$harness" in
    claude)  echo "$HOME/.claude/agents" ;;
    codex)   echo "$HOME/.codex/agents" ;;
    agents)  echo "$HOME/.agents/agents" ;;
    pi)      echo "$HOME/.pi/agents" ;;
    *)       echo "$HOME/.claude/agents" ;;
  esac
}

info "Spellbook Bootstrap"
info "Installing global process skills + agents..."
echo

installed=0

# Claude Code
if [ -d "$HOME/.claude" ] || command -v claude &>/dev/null; then
  info "Detected: Claude Code"
  install_globals "$HOME/.claude/skills" "$(agents_dir_for claude)"
  installed=$((installed + 1))
fi

# Codex
if [ -d "$HOME/.codex" ] || command -v codex &>/dev/null; then
  info "Detected: Codex"
  install_globals "$HOME/.codex/skills" "$(agents_dir_for codex)"
  installed=$((installed + 1))
fi

# Agents (generic .agents convention) — skip if skills dir is a symlink to another repo
if [ -d "$HOME/.agents" ] && [ ! -L "$HOME/.agents/skills" ]; then
  info "Detected: .agents"
  install_globals "$HOME/.agents/skills" "$(agents_dir_for agents)"
  installed=$((installed + 1))
fi

# Pi
if [ -d "$HOME/.pi" ] || command -v pi &>/dev/null; then
  info "Detected: Pi"
  install_globals "$HOME/.pi/skills" "$(agents_dir_for pi)"
  installed=$((installed + 1))
fi

echo
if [ "$installed" -eq 0 ]; then
  warn "No agent harnesses detected."
  warn "Installing to ~/.claude/ as default."
  install_globals "$HOME/.claude/skills" "$(agents_dir_for claude)"
  installed=1
fi

ok "Done. Installed to $installed harness(es)."
echo
info "Global skills (13): autopilot, calibrate, context-engineering, debug,"
info "  focus, groom, harness-engineering, moonshot, pr, reflect, research,"
info "  settle, skill"
info "Global agents (4): beck, carmack, grug, ousterhout"
echo
info "Domain skills (stripe, next-patterns, etc.) are project-local via /focus."
echo
info "Next steps:"
info "  1. Open any project"
info "  2. Run /focus to initialize"
info "  3. Edit .spellbook.yaml to customize domain skills"
