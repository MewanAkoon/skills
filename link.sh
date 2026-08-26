#!/usr/bin/env bash
# Symlinks every skill in this repo into each agent's global skill directory.
# Symlinks, not copies, so editing a file here is live immediately and a
# `git pull` updates every agent at once.
#
# Re-run after adding or renaming a skill. Safe to run repeatedly.

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"

# Add or remove destinations as you confirm where each tool reads from.
DESTS=(
  "$HOME/.claude/skills"   # Claude Code
  "$HOME/.cursor/skills"   # Cursor
)

for DEST in "${DESTS[@]}"; do
  if [ -L "$DEST" ] && [[ "$(readlink -f "$DEST")" == "$REPO"* ]]; then
    echo "error: $DEST is a symlink back into this repo. Remove it and re-run." >&2
    exit 1
  fi

  mkdir -p "$DEST"

  # Drop links this repo made whose target is gone, so a renamed skill does
  # not leave the old name behind for every tool to keep listing.
  for link in "$DEST"/*; do
    [ -L "$link" ] || continue
    case "$(readlink "$link")" in
      "$REPO"/skills/*)
        if [ ! -e "$link" ]; then
          rm "$link"
          echo "removed stale $(basename "$link") from $DEST"
        fi
        ;;
    esac
  done

  for src in "$REPO"/skills/*/; do
    [ -f "${src}SKILL.md" ] || continue
    name="$(basename "$src")"
    target="$DEST/$name"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
      echo "skipping $name in $DEST, a real directory is already there" >&2
      continue
    fi

    ln -sfn "${src%/}" "$target"
    echo "linked $name -> $DEST"
  done
done

echo
echo "Done. Restart your agent if it caches the skill list at startup."
