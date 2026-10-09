#!/usr/bin/env bash
# Removes the skill symlinks an older install of this repo made. The skills now
# ship as the Claude Code plugin `eng`, so nothing needs linking any more.
#
#   link.sh              print how to install the plugin, and exit 1
#   link.sh --unlink     remove the links this clone made, keeping the clone
#
# Run --unlink once, before installing the plugin. The old links are personal
# skills with bare names, and they would load beside the plugin's eng: copies.

set -euo pipefail

# Resolve through a symlink, so running this from a bin directory on PATH still
# finds the clone. Without it REPO names the symlink's directory, no link ever
# matches, and the script reports success having removed nothing.
SELF="$(readlink -f "$0" 2>/dev/null || true)"
# An empty SELF would make `dirname` return `.`, so the cd below would succeed
# into the wrong directory and every comparison would quietly fail. Say what is
# wrong instead. `readlink -f` is GNU and BSD both today, and missing on macOS
# before Big Sur.
[ -n "$SELF" ] || { printf 'error: readlink -f cannot resolve %s\n' "$0" >&2; exit 1; }
REPO="$(cd -P "$(dirname "$SELF")" && pwd)"

# LEGACY, legacy_name and link_target, shared with check.sh --doctor.
# shellcheck source=scripts/legacy.sh
. "$REPO/scripts/legacy.sh"

install_steps() {
  cat <<'STEPS'
Install the skills as the Claude Code plugin instead. In a Claude Code session:

  /plugin marketplace add MewanAkoon/skills
  /plugin install eng@mewanakoon

The README covers updates, removal, working from this clone, and the
skillOverrides entry that keeps bare copies of commit and pr out.
STEPS
}

UNLINK=0
for arg in "$@"; do
  case "$arg" in
    --unlink) UNLINK=1 ;;
    *) echo "usage: link.sh [--unlink]" >&2; exit 2 ;;
  esac
done

if [ "$UNLINK" -eq 0 ]; then
  echo "This repo no longer links skills into ~/.claude/skills."
  echo "If an older install linked them, run ./link.sh --unlink first."
  echo
  install_steps
  # Non-zero, so a setup script that still runs this to install the skills
  # stops here instead of reporting success having installed nothing.
  exit 1
fi

# A link this clone made carries a legacy name, or the name of a skill
# here now. Anything else pointing into the clone was made by hand, so it is
# left alone.
ours() {
  local name
  name="$(basename "$1")"
  [ -d "$REPO/skills/$name" ] || legacy_name "$name"
}

# The directories an older install wrote to: the default, the override it
# honoured, and two it used before settling on ~/.claude/skills. Every one of
# them stays, empty or not, because Claude Code, Cursor and other tools read
# them too.
HOME_DIR="${HOME:-/nonexistent}"
DIRS=(
  "$HOME_DIR/.claude/skills"
  "$HOME_DIR/.agents/skills"
  "$HOME_DIR/.cursor/skills"
)
[ -z "${SKILLS_DEST:-}" ] || DIRS+=("$SKILLS_DEST")
# Where Claude Code reads personal skills when this is set, and where
# check.sh --doctor looks.
[ -z "${CLAUDE_CONFIG_DIR:-}" ] || DIRS+=("$CLAUDE_CONFIG_DIR/skills")

removed=0
seen=""
for DIR in "${DIRS[@]}"; do
  [ -d "$DIR" ] || continue
  # SKILLS_DEST or CLAUDE_CONFIG_DIR can name a directory already listed, so
  # compare physical paths and scan each one once.
  real="$(cd -P "$DIR" && pwd)" || continue
  case "$seen" in *"|$real|"*) continue ;; esac
  seen="$seen|$real|"

  for link in "$DIR"/*; do
    [ -L "$link" ] || continue
    case "$(link_target "$link" || true)" in
      "$REPO"/skills/*)
        if ours "$link"; then
          rm "$link"
          echo "unlinked $(basename "$link") from $DIR"
          removed=$((removed + 1))
        else
          echo "left $(basename "$link") in $DIR, this clone did not create it" >&2
        fi
        ;;
    esac
  done
done

echo
echo "Unlinked $removed."
echo
install_steps
