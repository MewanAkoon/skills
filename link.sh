#!/usr/bin/env bash
# Symlinks every skill in this repo into each agent's global skill directory.
# Symlinks, not copies, so editing a file here is live immediately and a
# `git pull` updates every agent at once.
#
# Re-run after adding or renaming a skill. Safe to run repeatedly.

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"

# Two destinations, not three. Cursor reads ~/.agents/skills as well as
# ~/.claude/skills, so adding ~/.cursor/skills would put every skill in three
# directories Cursor scans and list each one three times in its picker.
DESTS=(
  "$HOME/.claude/skills"   # Claude Code, and Cursor for compatibility
  "$HOME/.agents/skills"   # Codex, and Cursor
)

# ~/.cursor/skills was a destination until the duplicate-loading fix. Say so
# once if links from this repo are still sitting there, and leave them alone:
# removing files under $HOME is the user's call, not this script's.
STALE="$HOME/.cursor/skills"
if [ -d "$STALE" ] && ls "$STALE" 2>/dev/null | grep -q .; then
  echo "note: $STALE still holds skill links. Cursor also reads ~/.agents/skills," >&2
  echo "      so those are duplicates now. Remove them with: rm -rf $STALE" >&2
  echo >&2
fi

for DEST in "${DESTS[@]}"; do
  if [ -L "$DEST" ] && [[ "$(readlink -f "$DEST")" == "$REPO"* ]]; then
    echo "error: $DEST is a symlink back into this repo. Remove it and re-run." >&2
    exit 1
  fi

  mkdir -p "$DEST"

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
