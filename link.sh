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
SELF="$(readlink -f "$0" 2>/dev/null || true)"
# An empty SELF would make `dirname` return `.`, so the cd below would succeed
# into the wrong directory and every glob would quietly match nothing. Say what
# is wrong instead. `readlink -f` is GNU and BSD both today, and missing on
# macOS before Big Sur.
[ -n "$SELF" ] || { printf 'error: readlink -f cannot resolve %s\n' "$0" >&2; exit 1; }
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

linked=0
removed=0
skipped=0
# One destination. Claude Code reads ~/.claude/skills, and Cursor loads it too
# for compatibility alongside its own directories, so a second destination puts
# every skill in two directories Cursor scans and lists each one twice.
DESTS=(
  "$HOME/.claude/skills"   # Claude Code, and Cursor for compatibility
)

# Destinations this repo used to write to and no longer does. Links this repo
# made are pruned from them, so a machine set up before the move stops loading
# the same skill twice. Dropping a destination from DESTS alone would leave the
# old links working and updating on every `git pull`, with nothing saying so.
#
# Neither tool is dropped. Cursor reads ~/.claude/skills, and ~/.agents/skills
# is the vendor-neutral root both understand, so one destination already covers
# what these two used to.
SUPERSEDED=(
  "${HOME:-/nonexistent}/.agents/skills"
  "${HOME:-/nonexistent}/.cursor/skills"
)

# A link this repo made is named after a skill directory in it. Anything else
# pointing here was made by hand, so it is left alone. A dangling link is ours
# too: that is a skill renamed since it was linked.
ours() {
  [ -d "$REPO/skills/$(basename "$1")" ] && return 0
  [ -e "$1" ] || return 0
  return 1
}

for OLD in "${SUPERSEDED[@]}"; do
  [ -d "$OLD" ] || continue

  for link in "$OLD"/*; do
    [ -L "$link" ] || continue
    case "$(link_target "$link" || true)" in
      "$REPO"/skills/*)
        if ours "$link"; then
          rm "$link"
          echo "removed superseded $(basename "$link") from $OLD"
          removed=$((removed + 1))
        else
          echo "left $(basename "$link") in $OLD, this repo did not create it" >&2
        fi
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
      skipped=$((skipped + 1))
      continue
    fi

    # Report a takeover, so a second clone claiming these names says so rather
    # than looking like a first install.
    if [ -L "$target" ]; then
      case "$(link_target "$target" || true)" in
        "$REPO"/skills/*) ;;
        *) echo "repointed $name in $DEST, it pointed outside this clone" >&2 ;;
      esac
    fi

    ln -sfn "${src%/}" "$target"
    echo "linked $name -> $DEST"
    linked=$((linked + 1))
  done
done

echo
echo "Linked $linked, unlinked $removed, skipped $skipped."
echo "Restart your agent if it caches the skill list at startup."

# A skipped skill is not installed, which is the thing this script exists to
# do, so the run reports it rather than ending on a success anyone would read
# as complete.
[ "$skipped" -eq 0 ]
