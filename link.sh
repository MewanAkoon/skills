#!/usr/bin/env bash
# Symlinks this repo's skills into the global skill directory Claude Code and
# Cursor both read. Symlinks, not copies, so editing a file here is live
# immediately and a `git pull` updates both tools at once.
#
#   link.sh              link every skill, minus anything in .skillsignore
#   link.sh --unlink     remove the links this clone made, keeping the clone
#   SKILLS_DEST=<dir>    link somewhere other than ~/.claude/skills
#
# Re-run after adding, renaming, or removing a skill, after editing
# .skillsignore, and after moving the clone. Safe to run repeatedly.

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

UNLINK=0
linked=0
removed=0
skipped=0
for arg in "$@"; do
  case "$arg" in
    --unlink) UNLINK=1 ;;
    *) echo "usage: link.sh [--unlink]" >&2; exit 2 ;;
  esac
done

# One destination. Claude Code reads ~/.claude/skills, and Cursor loads it too
# for compatibility alongside its own directories, so a second destination puts
# every skill in two directories Cursor scans and lists each one twice.
#
# SKILLS_DEST overrides it, for someone who wants a different root. Cursor also
# reads ~/.agents/skills, which is the vendor-neutral one.
DESTS=(
  "${SKILLS_DEST:-$HOME/.claude/skills}"
)

# Skills named in .skillsignore at the clone root are not linked, and a link
# this repo previously made for one is removed. One name per line, `#` starts a
# comment. The file is optional and absent by default.
ignored() {
  [ -f "$REPO/.skillsignore" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -n "$line" ] || continue
    [ "$line" = "$1" ] && return 0
  done < "$REPO/.skillsignore"
  return 1
}

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

  # SKILLS_DEST can name one of these. Pruning the directory we are about to
  # fill would remove all 17 links and relink them on every run, and report
  # counters describing work that undid itself.
  for D in "${DESTS[@]}"; do
    [ "$OLD" = "$D" ] && continue 2
  done

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

# A name in .skillsignore that matches no skill does nothing, and a typo looks
# exactly like a skill that is correctly ignored. Say so once, before linking.
if [ -f "$REPO/.skillsignore" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -n "$line" ] || continue
    [ -d "$REPO/skills/$line" ] \
      || echo "warning: .skillsignore lists $line, which is not a skill here" >&2
  done < "$REPO/.skillsignore"
fi

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

  # A removal should not leave a directory behind that was never there.
  [ "$UNLINK" -eq 1 ] || mkdir -p "$DEST"
  [ -d "$DEST" ] || continue

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

    # --unlink and .skillsignore both mean "this one should not be linked".
    # Remove only a link pointing into this clone, so anything else with the
    # same name stays where it is.
    if [ "$UNLINK" -eq 1 ] || ignored "$name"; then
      if [ -L "$target" ]; then
        case "$(link_target "$target" || true)" in
          "$REPO"/skills/*)
            rm "$target"
            if [ "$UNLINK" -eq 1 ]; then
              echo "unlinked $name from $DEST"
            else
              echo "unlinked $name from $DEST, listed in .skillsignore"
            fi
            removed=$((removed + 1))
            ;;
        esac
      fi
      continue
    fi

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
if [ "$UNLINK" -eq 1 ]; then
  echo "Unlinked $removed. Delete the clone when you are done with it."
  exit 0
fi

echo "Linked $linked, unlinked $removed, skipped $skipped."
echo "Restart your agent if it caches the skill list at startup."

# A skipped skill is not installed, which is the thing this script exists to
# do, so the run reports it rather than ending on a success anyone would read
# as complete.
[ "$skipped" -eq 0 ]
