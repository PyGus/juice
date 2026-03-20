#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  echo "Usage: $0 <skill-name> [--from <project-path>]"
  echo ""
  echo "  <skill-name>          Name of the skill to import"
  echo "  --from <path>         Import from <path>/.claude/skills/ instead of ~/.claude/skills/"
  exit 1
}

[[ $# -lt 1 ]] && usage

SKILL_NAME="$1"
FROM_PATH=""
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)
      [[ $# -lt 2 || -z "$2" ]] && { echo "Error: --from requires a non-empty path argument" >&2; exit 1; }
      FROM_PATH="$2"; shift 2 ;;
    *) usage ;;
  esac
done

if [[ -n "$FROM_PATH" ]]; then
  SOURCE="$FROM_PATH/.claude/skills/$SKILL_NAME"
else
  SOURCE="$HOME/.claude/skills/$SKILL_NAME"
fi

DEST="$REPO_DIR/$SKILL_NAME"

# Guard: already in repo
if [[ -d "$DEST" ]]; then
  echo "Error: '$SKILL_NAME' already exists in the repo at $DEST" >&2
  echo "If you want to update it, edit the file directly (it may already be symlinked)." >&2
  exit 1
fi

# Guard: source must not be a symlink (symlink means it's already managed by this repo)
# Note: -d follows symlinks, so we check -L first to distinguish real dirs from symlinked ones
if [[ -L "$SOURCE" ]]; then
  echo "Error: $SOURCE is already a symlink — this skill is likely already in the repo." >&2
  exit 1
fi

# Guard: source must be a real directory
if [[ ! -d "$SOURCE" ]]; then
  echo "Error: skill not found at $SOURCE" >&2
  exit 1
fi

# Copy into repo
cp -r "$SOURCE" "$DEST"
echo "Copied: $SOURCE → $DEST"

# Remove original
rm -rf "$SOURCE"
echo "Removed original: $SOURCE"

# Re-run install to symlink back
bash "$REPO_DIR/install.sh"
