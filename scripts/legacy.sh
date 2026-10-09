# shellcheck shell=bash
# What link.sh --unlink and check.sh --doctor both need to know about the
# symlinks an older install of this repo made. Sourced, never run.

# Every skill an older install could have linked. Several of these stop
# existing as folders once the plugin reorganises them, and a link left behind
# for one of those dangles, so the names are carried here rather than read from
# skills/.
# shellcheck disable=SC2034
LEGACY=(
  api-boundaries architect blast-radius commit diagnose-bug grill-me handoff
  how merge-conflicts plain-writing pr review-diff tdd-node-api ts-types
  verify-app wayfinder why
)

# Is $1 one of those names?
legacy_name() {
  local name
  for name in "${LEGACY[@]}"; do
    [ "$name" = "$1" ] && return 0
  done
  return 1
}

# Where a symlink points, as a physical path comparable with the clone's own.
# Reading the target with `readlink` alone is not enough: it returns whatever
# string was stored, which may be relative, and may spell a path through a
# symlink that the clone's path spells directly, so the comparison silently
# never matches. Resolving the parent rather than the whole path keeps this
# working for a link left dangling by a skill that has since been removed,
# which is most of what this cleans up.
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
