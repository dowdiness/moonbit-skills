#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

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

link_skill() {
  local skill_dir="$1"
  local skills_dir="$2"
  local name="${3:-$(basename "$skill_dir")}"

  [ -f "$skill_dir/SKILL.md" ] || return 0
  ln -sfn "$skill_dir" "$skills_dir/$name"
  echo "Linked: $skills_dir/$name"
}

link_skills() {
  local skills_dir="$1"

  mkdir -p "$skills_dir"
  remove_repo_link "$skills_dir/moonbit-settings"

  for dir in "$REPO_DIR"/*/; do
    link_skill "$dir" "$skills_dir"
  done

  link_skill "$REPO_DIR/moonbit-agent-guide/moonbit-agent-guide" "$skills_dir" "moonbit-agent-guide"
}

link_base() {
  local config_dir="$1"

  mkdir -p "$config_dir"
  ln -sf "$REPO_DIR/moonbit-base.md" "$config_dir/moonbit-base.md"
  echo "Linked: $config_dir/moonbit-base.md"
}

link_skills "$HOME/.claude/skills"
link_skills "$HOME/.agents/skills"
link_base "$HOME/.claude"
link_base "$HOME/.agents"
