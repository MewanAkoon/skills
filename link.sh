#!/usr/bin/env bash
# Symlinks every skill in this repo into the global skill directory each agent
# reads. Symlinks, not copies, so editing a file here is live immediately and a
# `git pull` updates every agent at once.
#
# Re-run after adding, renaming, or removing a skill. Safe to run repeatedly.

set -euo pipefail

# Resolve through a symlink, so running this from a bin directory on PATH still
# finds the clone. Without it REPO names the symlink's directory, every glob
# below matches nothing, and the script reports success having linked nothing.
SELF="$(readlink -f "$0")"
REPO="$(cd -P "$(dirname "$SELF")" && pwd)"

# Where a symlink points, as a physical path comparable with $REPO. Reading the
# target with `readlink` alone is not enough: it returns whatever string was
# stored, which may be relative, and may spell a path through a symlink that
# $REPO spells directly, so the comparison silently never matches. Resolving the
# parent rather than the whole path keeps this working for a link left dangling
# by a renamed skill, which is the case the prune below exists to catch.
link_target() {
  local raw dir
  raw="$(readlink "$1")" || return 1
  case "$raw" in
    /*) ;;
    *) raw="$(dirname "$1")/$raw" ;;
  esac
  dir="$(cd -P "$(dirname "$raw")" 2>/dev/null && pwd)" || return 1
  printf '%s/%s\n' "$dir" "$(basename "$raw")"
}

# One destination. Claude Code reads ~/.claude/skills, and Cursor loads it too
# for compatibility alongside its own directories, so a second destination puts
# every skill in two directories Cursor scans and lists each one twice.
DESTS=(
  "$HOME/.claude/skills"   # Claude Code, and Cursor for compatibility
)

# Destinations this repo used to write to. Links into this repo are pruned from
# them, so a machine set up before a tool was dropped stops loading skills into
# it. Removing a destination from DESTS alone leaves the old links working and
# updating on every `git pull`, with nothing reporting them.
RETIRED=(
  "$HOME/.agents/skills"   # Codex, dropped
  "$HOME/.cursor/skills"   # Cursor, now covered by ~/.claude/skills
)

for OLD in "${RETIRED[@]}"; do
  [ -d "$OLD" ] || continue

  for link in "$OLD"/*; do
    [ -L "$link" ] || continue
    case "$(link_target "$link" || true)" in
      "$REPO"/skills/*)
        rm "$link"
        echo "removed retired $(basename "$link") from $OLD"
        ;;
    esac
  done

  # Only when the prune emptied it. A directory holding anything else is
  # someone else's, so rmdir fails and the run carries on.
  if rmdir "$OLD" 2>/dev/null; then
    echo "removed empty $OLD"
  fi
done

for DEST in "${DESTS[@]}"; do
  # A destination symlinked back into this repo would link the skills into
  # themselves.
  if [ -L "$DEST" ]; then
    case "$(link_target "$DEST" || true)" in
      "$REPO"|"$REPO"/*)
        echo "error: $DEST is a symlink back into this repo. Remove it and re-run." >&2
        exit 1
        ;;
    esac
  fi

  mkdir -p "$DEST"

  # Drop links this repo made whose skill is gone, so a renamed skill leaves no
  # dead entry behind for every tool to keep listing.
  for link in "$DEST"/*; do
    [ -L "$link" ] || continue
    case "$(link_target "$link" || true)" in
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
