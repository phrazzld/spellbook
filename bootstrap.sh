#!/usr/bin/env bash
set -euo pipefail

# Spellbook Bootstrap
#
# Two modes:
#   LOCAL:  Symlinks harness dirs to a local spellbook checkout (fast, editable)
#   REMOTE: Downloads from GitHub (works on any machine without a checkout)
#
# Local mode is preferred. Remote is the fallback for fresh machines.
#
# Run: curl -sL https://raw.githubusercontent.com/phrazzld/spellbook/master/bootstrap.sh | bash

REPO="phrazzld/spellbook"
RAW="https://raw.githubusercontent.com/$REPO/master"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { printf '\033[0;34m%s\033[0m\n' "$*"; }
ok()    { printf '\033[0;32m%s\033[0m\n' "$*"; }
warn()  { printf '\033[0;33m%s\033[0m\n' "$*"; }
err()   { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }

is_spellbook_checkout() {
  local dir="$1"
  [ -d "$dir/skills" ] && [ -d "$dir/agents" ] && [ -d "$dir/harnesses" ] && [ -f "$dir/registry.yaml" ]
}

resolve_spellbook_dir() {
  if [ -n "${SPELLBOOK_DIR:-}" ] && is_spellbook_checkout "$SPELLBOOK_DIR"; then
    printf '%s\n' "$SPELLBOOK_DIR"
    return 0
  fi

  if is_spellbook_checkout "$SCRIPT_DIR"; then
    printf '%s\n' "$SCRIPT_DIR"
    return 0
  fi

  local candidate
  for candidate in \
    "$HOME/Development/spellbook" \
    "$HOME/dev/spellbook" \
    "$HOME/src/spellbook" \
    "$HOME/code/spellbook"
  do
    if is_spellbook_checkout "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

cleanup_symlinks_under_prefix() {
  local dir="$1"
  local prefix="$2"
  shift 2
  local expected=("$@")

  mkdir -p "$dir"

  local entry base target
  for entry in "$dir"/*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    [ -L "$entry" ] || continue
    target="$(readlink "$entry" || true)"
    case "$target" in
      "$prefix"/*)
        base="$(basename "$entry")"
        if ! contains "$base" "${expected[@]}"; then
          rm -rf "$entry"
          ok "    removed stale $(basename "$dir")/$base"
        fi
        ;;
    esac
  done
}

remove_path_if_symlink_to_prefix() {
  local path="$1"
  local prefix="$2"
  local label="$3"

  [ -L "$path" ] || return 0

  local target
  target="$(readlink "$path" || true)"
  case "$target" in
    "$prefix"/*)
      rm -f "$path"
      ok "    removed stale $label"
      ;;
  esac
}

link_file_if_present() {
  local src="$1"
  local dest="$2"
  local label="$3"

  [ -e "$src" ] || return 0

  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
  ok "    $label"
}

link_dir_entries_if_present() {
  local src_dir="$1"
  local dest_dir="$2"
  local label="$3"

  [ -d "$src_dir" ] || return 0

  local expected=()
  local src
  for src in "$src_dir"/*; do
    [ -e "$src" ] || continue
    expected+=("$(basename "$src")")
  done

  cleanup_symlinks_under_prefix "$dest_dir" "$src_dir" "${expected[@]}"

  mkdir -p "$dest_dir"
  for src in "$src_dir"/*; do
    [ -e "$src" ] || continue
    ln -sfn "$src" "$dest_dir/$(basename "$src")"
  done

  ok "    $label"
}

sanitize_claude_settings_json() {
  local settings_file="$1"
  [ -f "$settings_file" ] || return 0

  python3 - "$settings_file" <<'PY'
import json
import os
import re
import sys
from pathlib import Path

settings_path = Path(sys.argv[1]).expanduser()
data = json.loads(settings_path.read_text())

hook_path_re = re.compile(r'~/.claude/hooks/[^ "\']+')
changed = False

hooks = data.get("hooks")
if isinstance(hooks, dict):
    cleaned = {}
    for event, groups in hooks.items():
        if not isinstance(groups, list):
            cleaned[event] = groups
            continue

        kept_groups = []
        for group in groups:
            if not isinstance(group, dict):
                kept_groups.append(group)
                continue

            entries = group.get("hooks")
            if not isinstance(entries, list):
                kept_groups.append(group)
                continue

            kept_entries = []
            for entry in entries:
                if not isinstance(entry, dict):
                    kept_entries.append(entry)
                    continue

                command = entry.get("command", "")
                match = hook_path_re.search(command)
                if match:
                    hook_file = Path(os.path.expanduser(match.group(0)))
                    if not hook_file.exists():
                        changed = True
                        continue
                kept_entries.append(entry)

            if kept_entries:
                if len(kept_entries) != len(entries):
                    changed = True
                group = dict(group)
                group["hooks"] = kept_entries
                kept_groups.append(group)
            else:
                changed = True

        cleaned[event] = kept_groups

    data["hooks"] = cleaned

if changed:
    settings_path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

copy_claude_settings_if_present() {
  local src="$1"
  local dest="$2"

  [ -f "$src" ] || return 0

  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  sanitize_claude_settings_json "$dest"
  ok "    settings.json (copied)"
}

verify_no_broken_spellbook_symlinks() {
  local dir="$1"
  local maxdepth="$2"
  local broken=0
  local link target

  while IFS= read -r link; do
    target="$(readlink "$link" || true)"
    case "$target" in
      "$SPELLBOOK"/*)
        if [ ! -e "$link" ]; then
          err "Broken symlink: $link -> $target"
          broken=1
        fi
        ;;
    esac
  done < <(find "$dir" -maxdepth "$maxdepth" -type l 2>/dev/null)

  return "$broken"
}

parse_registry_file() {
  local registry_file="$1"
  local output_file="$2"

  python3 - "$registry_file" > "$output_file" <<'PY'
import re
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text().splitlines()

def extract(lines, path):
    depth = 0
    target_indent = [None] * len(path)
    items = []
    capturing = False

    for line in lines:
        if not line.strip() or line.lstrip().startswith('#'):
            continue

        indent = len(line) - len(line.lstrip())
        stripped = line.strip()

        if depth < len(path):
            if stripped.startswith(path[depth] + ':'):
                target_indent[depth] = indent
                depth += 1
                if depth == len(path):
                    capturing = True
                    rest = stripped[len(path[-1]) + 1:].strip()
                    if rest.startswith('[') and rest.endswith(']'):
                        items = [value.strip() for value in rest[1:-1].split(',') if value.strip()]
                        break
                continue
        elif capturing:
            if indent <= target_indent[-1]:
                break
            if stripped.startswith('- '):
                items.append(stripped[2:].strip())

    return items

custom = extract(lines, ['global', 'skills', 'custom_install'])
standard = extract(lines, ['global', 'skills', 'standard'])
agents = extract(lines, ['global', 'agents'])

safe = re.compile(r'^[a-z0-9-]+$')
for name in custom + standard + agents:
    if not safe.match(name):
        print(f"INVALID: {name}", file=sys.stderr)
        sys.exit(1)

print('CUSTOM_INSTALL=(' + ' '.join(custom) + ')')
print('GLOBAL_SKILLS=(' + ' '.join(standard) + ')')
print('GLOBAL_AGENTS=(' + ' '.join(agents) + ')')
PY
}

SPELLBOOK="$(resolve_spellbook_dir || true)"
TEMP_REGISTRY=""
PARSED="$(mktemp)"
trap 'rm -f "$PARSED" ${TEMP_REGISTRY:+"$TEMP_REGISTRY"}' EXIT

if [ -n "$SPELLBOOK" ]; then
  REGISTRY_FILE="$SPELLBOOK/registry.yaml"
else
  TEMP_REGISTRY="$(mktemp)"
  curl -sfL "$RAW/registry.yaml" -o "$TEMP_REGISTRY" || { err "Failed to fetch registry.yaml"; exit 1; }
  REGISTRY_FILE="$TEMP_REGISTRY"
fi

parse_registry_file "$REGISTRY_FILE" "$PARSED" || { err "Failed to parse registry.yaml"; exit 1; }
source "$PARSED"

if [ ${#GLOBAL_SKILLS[@]} -eq 0 ] && [ ${#CUSTOM_INSTALL[@]} -eq 0 ]; then
  err "No global skills found in registry.yaml"
  exit 1
fi

if [ ${#GLOBAL_AGENTS[@]} -eq 0 ]; then
  err "No global agents found in registry.yaml"
  exit 1
fi

link_local() {
  local harness="$1"        # e.g. "claude"
  local harness_dir="$2"    # e.g. "$HOME/.claude"
  local skills_dir="$harness_dir/skills"
  local agents_dir="$harness_dir/agents"
  local skill_names=("${CUSTOM_INSTALL[@]}" "${GLOBAL_SKILLS[@]}")
  local agent_files=()
  local skill agent src

  for agent in "${GLOBAL_AGENTS[@]}"; do
    agent_files+=("$agent.md")
  done

  info "  Linking skills..."
  cleanup_symlinks_under_prefix "$skills_dir" "$SPELLBOOK/skills" "${skill_names[@]}"
  mkdir -p "$skills_dir"
  for skill in "${skill_names[@]}"; do
    src="$SPELLBOOK/skills/$skill"
    if [ ! -d "$src" ]; then
      warn "    missing local skill: $skill"
      continue
    fi
    ln -sfn "$src" "$skills_dir/$skill"
    ok "    $skill"
  done

  info "  Linking agents..."
  cleanup_symlinks_under_prefix "$agents_dir" "$SPELLBOOK/agents" "${agent_files[@]}"
  mkdir -p "$agents_dir"
  for agent in "${GLOBAL_AGENTS[@]}"; do
    src="$SPELLBOOK/agents/$agent.md"
    if [ ! -f "$src" ]; then
      warn "    missing local agent: $agent"
      continue
    fi
    ln -sfn "$src" "$agents_dir/$agent.md"
    ok "    $agent"
  done

  # Link harness-specific configs if they exist
  local harness_config="$SPELLBOOK/harnesses/$harness"
  if [ -d "$harness_config" ]; then
    info "  Linking harness config..."
    case "$harness" in
      claude)
        link_file_if_present "$harness_config/CLAUDE.md" "$harness_dir/CLAUDE.md" "CLAUDE.md"
        link_dir_entries_if_present "$harness_config/hooks" "$harness_dir/hooks" "hooks/"
        copy_claude_settings_if_present "$harness_config/settings.json" "$harness_dir/settings.json"
        remove_path_if_symlink_to_prefix "$harness_dir/.claude/settings.local.json" "$SPELLBOOK" ".claude/settings.local.json"
        ;;
      codex)
        cleanup_symlinks_under_prefix "$harness_dir/config" "$harness_config" "config.toml"
        link_file_if_present "$harness_config/config.toml" "$harness_dir/config/config.toml" "config.toml"
        remove_path_if_symlink_to_prefix "$harness_dir/AGENTS.md" "$SPELLBOOK" "AGENTS.md"
        ;;
      pi)
        link_dir_entries_if_present "$harness_config/context/global" "$harness_dir/agent" "context/global/*.md"
        link_file_if_present "$harness_config/settings.json" "$harness_dir/settings.json" "settings.json"
        cleanup_symlinks_under_prefix "$harness_dir/prompts" "$SPELLBOOK"
        remove_path_if_symlink_to_prefix "$harness_dir/persona.md" "$SPELLBOOK" "persona.md"
        ;;
    esac
  fi

  verify_no_broken_spellbook_symlinks "$harness_dir" 4
}

# --- Remote mode: download from GitHub ---

download_skill() {
  local skills_dir="$1"
  local name="$2"
  local target="$skills_dir/$name"
  mkdir -p "$target/references"

  curl -sfL "$RAW/skills/$name/SKILL.md" -o "$target/SKILL.md" || { err "Failed: $name/SKILL.md"; return 1; }

  # Best-effort: download references via GitHub API
  local refs
  refs=$(curl -sf "https://api.github.com/repos/$REPO/contents/skills/$name/references" 2>/dev/null | \
    python3 -c "import sys,json; [print(f['name']) for f in json.load(sys.stdin) if f['type']=='file']" 2>/dev/null) || true
  if [ -n "$refs" ]; then
    echo "$refs" | while read -r fname; do
      curl -sfL "$RAW/skills/$name/references/$fname" -o "$target/references/$fname" 2>/dev/null || true
    done
  fi

  ok "  $name → $target"
}

download_agent() {
  local agents_dir="$1"
  local name="$2"
  mkdir -p "$agents_dir"
  curl -sfL "$RAW/agents/$name.md" -o "$agents_dir/$name.md" || { err "Failed: agent $name"; return 1; }
  ok "  $name → $agents_dir/$name.md"
}

install_remote() {
  local skills_dir="$1"
  local agents_dir="$2"

  for skill in "${CUSTOM_INSTALL[@]}" "${GLOBAL_SKILLS[@]}"; do
    download_skill "$skills_dir" "$skill"
  done

  info "  Installing agents..."
  for agent in "${GLOBAL_AGENTS[@]}"; do
    download_agent "$agents_dir" "$agent"
  done
}

# --- Orchestration ---

info "Spellbook Bootstrap"
if [ -n "$SPELLBOOK" ]; then
  info "Local checkout detected: $SPELLBOOK"
  info "Mode: symlink"
else
  info "No local checkout found."
  info "Mode: download from GitHub"
fi
echo

installed=0

for harness in claude codex pi; do
  harness_dir="$HOME/.$harness"

  # Detect harness
  if [ ! -d "$harness_dir" ] && ! command -v "$harness" &>/dev/null; then
    continue
  fi

  info "Detected: $harness"
  mkdir -p "$harness_dir"

  if [ -n "$SPELLBOOK" ]; then
    link_local "$harness" "$harness_dir"
  else
    agents_dir="$harness_dir/agents"
    install_remote "$harness_dir/skills" "$agents_dir"
  fi

  installed=$((installed + 1))
  echo
done

if [ "$installed" -eq 0 ]; then
  warn "No agent harnesses detected."
  warn "Installing to ~/.claude/ as default."
  mkdir -p "$HOME/.claude"
  if [ -n "$SPELLBOOK" ]; then
    link_local "claude" "$HOME/.claude"
  else
    install_remote "$HOME/.claude/skills" "$HOME/.claude/agents"
  fi
  installed=1
fi

ok "Done. Installed to $installed harness(es)."
echo
info "Global skills (${#CUSTOM_INSTALL[@]} + ${#GLOBAL_SKILLS[@]}): ${CUSTOM_INSTALL[*]} ${GLOBAL_SKILLS[*]}"
info "Global agents (${#GLOBAL_AGENTS[@]}): ${GLOBAL_AGENTS[*]}"
echo
if [ -n "$SPELLBOOK" ]; then
  info "Mode: symlink (edits in $SPELLBOOK propagate instantly)"
else
  info "Mode: downloaded from GitHub"
  info "For symlink mode, clone spellbook and re-run."
fi
