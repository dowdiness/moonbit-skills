#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

unlink_skills() {
  local skills_dir="$1"
  local raw_target=""
  local resolved_target=""

  [ -d "$skills_dir" ] || return 0

  for link in "$skills_dir"/*/; do
    [ -L "${link%/}" ] || continue
    raw_target="$(readlink "${link%/}")" || raw_target=""
    resolved_target="$(readlink -f "${link%/}" 2>/dev/null)" || resolved_target=""
    case "$raw_target" in
      "$REPO_DIR"/*)
        rm "${link%/}"
        echo "Removed: ${link%/}"
        continue
        ;;
    esac
    case "$resolved_target" in
      "$REPO_DIR"/*)
        rm "${link%/}"
        echo "Removed: ${link%/}"
        ;;
    esac
  done
}

unlink_base() {
  local config_dir="$1"
  local link="$config_dir/moonbit-base.md"

  [ -L "$link" ] || return 0
  target="$(readlink -f "$link")" || return 0
  case "$target" in
    "$REPO_DIR"/*)
      rm "$link"
      echo "Removed: $link"
      ;;
  esac
}

unlink_skills "$HOME/.claude/skills"
unlink_skills "$HOME/.agents/skills"
unlink_skills "$HOME/.codex/skills"
unlink_base "$HOME/.claude"
unlink_base "$HOME/.agents"
unlink_base "$HOME/.codex"
