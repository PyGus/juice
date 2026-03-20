#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
RESERVED=("docs")

mkdir -p "$SKILLS_DIR"

linked=0
skipped=0

for skill_dir in "$REPO_DIR"/*/; do
  skill_name=$(basename "$skill_dir")

  # Skip dotfiles
  [[ "$skill_name" == .* ]] && continue

  # Skip non-directories
  [[ ! -d "$skill_dir" ]] && continue

  # Skip reserved folders
  skip=false
  for reserved in "${RESERVED[@]}"; do
    [[ "$skill_name" == "$reserved" ]] && skip=true && break
  done
  if $skip; then
    echo "Skipping reserved: $skill_name"
    ((++skipped))
    continue
  fi

  target="$SKILLS_DIR/$skill_name"

  if [[ -e "$target" || -L "$target" ]]; then
    echo "Skipping (already exists): $skill_name"
    ((++skipped))
  else
    ln -s "${skill_dir%/}" "$target"
    echo "Linked: $skill_name"
    ((++linked))
  fi
done

echo ""
echo "Done. Linked: $linked, Skipped: $skipped"
