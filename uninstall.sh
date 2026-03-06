#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

[ -d "$SKILLS_DIR" ] || exit 0

for link in "$SKILLS_DIR"/*/; do
  [ -L "${link%/}" ] || continue
  target="$(readlink -f "${link%/}")"
  case "$target" in
    "$REPO_DIR"/*)
      rm "$link"
      echo "Removed: $(basename "${link%/}")"
      ;;
  esac
done
