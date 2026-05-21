#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
REPAIR=false
CONFLICTS=()
BACKUP_BASE="${HOME}/.local/share/dowdiness-skills-backup"
BACKUP_DIR=""

usage() {
  cat <<'EOF'
Usage: install.sh [--repair] [--help]

Default mode:
  - skip already-correct links
  - block non-link conflicts so nothing is removed

--repair:
  - moves conflicting existing paths to backup first
  - creates the canonical skill symlinks in-place

Examples:
  ./install.sh
  ./install.sh --repair
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repair)
      REPAIR=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

init_backup_dir() {
  if [ -n "$BACKUP_DIR" ]; then
    return
  fi

  if ! mkdir -p "$BACKUP_BASE" 2>/dev/null; then
    BACKUP_BASE="/tmp/dowdiness-skills-backup"
  fi

  if ! mkdir -p "$BACKUP_BASE" 2>/dev/null; then
    echo "ERROR: unable to create backup directory at $BACKUP_BASE" >&2
    exit 1
  fi

  BACKUP_DIR="$BACKUP_BASE/$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$BACKUP_DIR"
  echo "Repair mode enabled. Duplicate entries will be backed up to: $BACKUP_DIR"
}

backup_conflict() {
  local target="$1"
  local parent_dir=""
  local backup_parent=""
  local base_name=""

  parent_dir="$(dirname "$target")"
  base_name="$(basename "$target")"

  if [[ "$parent_dir" == "$HOME"/* ]]; then
    backup_parent="$BACKUP_DIR/${parent_dir#$HOME/}"
  else
    backup_parent="$BACKUP_DIR/extra$(printf '%s' "$parent_dir" | tr '/' '__')"
  fi

  if ! mkdir -p "$backup_parent"; then
    echo "ERROR: unable to create backup directory: $backup_parent" >&2
    return 1
  fi

  if ! mv "$target" "$backup_parent/$base_name"; then
    echo "ERROR: unable to move $target to backup directory" >&2
    return 1
  fi

  echo "Backed up duplicate: $target -> $backup_parent/$base_name"
  return 0
}

remove_repo_link() {
  local link="$1"
  local raw_target=""
  local resolved_target=""

  [ -L "$link" ] || return 0
  raw_target="$(readlink "$link")" || raw_target=""
  resolved_target="$(readlink -f "$link" 2>/dev/null)" || resolved_target=""

  case "$raw_target" in
    "$REPO_DIR"/*)
      rm "$link"
      echo "Removed stale link: $link"
      return 0
      ;;
  esac

  case "$resolved_target" in
    "$REPO_DIR"/*)
      rm "$link"
      echo "Removed stale link: $link"
      ;;
  esac
}

same_repo_link() {
  local link="$1"
  local source="$2"

  [ -L "$link" ] || return 1
  local resolved_target=""

  resolved_target="$(readlink -f "$link" 2>/dev/null)" || resolved_target=""

  [ "$resolved_target" = "$source" ] && return 0
  return 1
}

link_or_skip() {
  local skill_dir="$1"
  local skills_dir="$2"
  local name="${3:-$(basename "$skill_dir")}"

  local target="$skills_dir/$name"

  if same_repo_link "$target" "$skill_dir"; then
    echo "Already linked: $target"
    return 0
  fi

  remove_repo_link "$target"

  if [ -e "$target" ]; then
    if [ "$REPAIR" = true ]; then
      init_backup_dir
      if ! backup_conflict "$target"; then
        echo "ERROR: cannot repair blocked path: $target" >&2
        CONFLICTS+=("$target")
        return 0
      fi
      ln -sfn "$skill_dir" "$target"
      echo "Repaired link: $target"
      return 0
    fi

    echo "ERROR: existing path blocked installation: $target" >&2
    echo "  Expected repo link to: $skill_dir" >&2
    CONFLICTS+=("$target")
    return 0
  fi

  ln -sfn "$skill_dir" "$target"
  echo "Linked: $target"
}

link_skill() {
  local skill_dir="$1"
  local skills_dir="$2"
  local name="${3:-$(basename "$skill_dir")}"

  [ -f "$skill_dir/SKILL.md" ] || return 0
  link_or_skip "$skill_dir" "$skills_dir" "$name"
}

link_skills() {
  local skills_dir="$1"

  mkdir -p "$skills_dir"
  remove_repo_link "$skills_dir/moonbit-settings"

  for dir in "$REPO_DIR"/*/; do
    link_skill "$dir" "$skills_dir"
  done

  # Skills vendored from the moonbit-agent-guide submodule. The top-level
  # copies of these directories were removed; install directly from the
  # submodule so we don't carry stale duplicates. Local-only extensions
  # to these skills live in patches/ — see patches/README.md.
  link_skill "$REPO_DIR/moonbit-agent-guide/moonbit-agent-guide" "$skills_dir" "moonbit-agent-guide"
  link_skill "$REPO_DIR/moonbit-agent-guide/moonbit-c-binding" "$skills_dir" "moonbit-c-binding"
  link_skill "$REPO_DIR/moonbit-agent-guide/moonbit-refactoring" "$skills_dir" "moonbit-refactoring"
}

report_conflicts() {
  if [ "${#CONFLICTS[@]}" -eq 0 ]; then
    return 0
  fi

  echo "BLOCKED by ${#CONFLICTS[@]} path(s):" >&2
  printf '  - %s\n' "${CONFLICTS[@]}" >&2
  return 1
}

link_base() {
  local config_dir="$1"

  mkdir -p "$config_dir"
  ln -sf "$REPO_DIR/moonbit-base.md" "$config_dir/moonbit-base.md"
  echo "Linked: $config_dir/moonbit-base.md"
}

link_skills "$HOME/.claude/skills"
link_skills "$HOME/.agents/skills"
link_skills "$HOME/.codex/skills"
link_base "$HOME/.claude"
link_base "$HOME/.agents"
link_base "$HOME/.codex"
report_conflicts
