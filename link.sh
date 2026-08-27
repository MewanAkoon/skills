#!/usr/bin/env bash
# Symlinks every skill in this repo into each agent's global skill directory.
# Symlinks, not copies, so editing a file here is live immediately and a
# `git pull` updates every agent at once.
#
# Re-run after adding or renaming a skill. Safe to run repeatedly.

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
# The physical path too, because a comparison against a resolved symlink
# target has to be made in the same terms or it silently never matches.
REPO_REAL="$(cd -P "$(dirname "$0")" && pwd)"

# Two destinations, not three. Cursor reads ~/.agents/skills as well as
# ~/.claude/skills, so adding ~/.cursor/skills would put every skill in three
# directories Cursor scans and list each one three times in its picker.
DESTS=(
  "$HOME/.claude/skills"   # Claude Code, and Cursor for compatibility
  "$HOME/.agents/skills"   # Codex, and Cursor
)

# ~/.cursor/skills was a destination until the duplicate-loading fix. Name only
# the links this repo put there, and leave them in place: removing files under
# $HOME is the user's call, not this script's. Anything else in that directory
# came from somewhere else and is none of our business.
STALE="$HOME/.cursor/skills"
if [ -d "$STALE" ]; then
  stale_list=""
  for entry in "$STALE"/*; do
    [ -L "$entry" ] || continue
    entry_target="$(cd -P "$entry" 2>/dev/null && pwd)" || continue
    case "$entry_target" in
      "$REPO"/*|"$REPO_REAL"/*) stale_list="$stale_list$entry"$'\n' ;;
    esac
  done
  if [ -n "$stale_list" ]; then
    echo "note: these links in $STALE point into this repo. Cursor also reads" >&2
    echo "      ~/.agents/skills, so they are duplicates now. Remove them with:" >&2
    printf '%s' "$stale_list" | while IFS= read -r entry; do
      [ -n "$entry" ] && echo "        rm \"$entry\"" >&2
    done
    echo >&2
  fi
fi

for DEST in "${DESTS[@]}"; do
  # A destination symlinked back into this repo would link the skills into
  # themselves. Resolve it physically where that works, and fall back to the
  # literal target so a broken link still gets this message rather than a
  # mkdir failure further down.
  if [ -L "$DEST" ]; then
    dest_target="$(cd -P "$DEST" 2>/dev/null && pwd)" || dest_target=""
    [ -n "$dest_target" ] || dest_target="$(readlink "$DEST")"
    case "$dest_target" in
      "$REPO"|"$REPO"/*|"$REPO_REAL"|"$REPO_REAL"/*)
        echo "error: $DEST is a symlink back into this repo. Remove it and re-run." >&2
        exit 1
        ;;
    esac
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
