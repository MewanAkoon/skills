#!/usr/bin/env bash
# The setup script for a personal Claude Code cloud environment. Paste it into
# the environment's Setup script box at claude.ai/code. It runs as root on the
# cloud VM before Claude Code starts, and the result is cached for about seven
# days.
#
# A cloud session reads nothing from ~/.claude on your machine, and a cloud
# thread in a project does not read the repo's .claude/settings.json either.
# So the skillOverrides entry the README's Setup adds, and the attribution
# settings that drop Claude's commit and PR lines, never reach it. This writes
# them into the VM's own home instead:
#
# - ~/.claude/CLAUDE.md, which the cloud docs say a session loads as user
#   instructions. It carries both as rules, and the settings reference says a
#   CLAUDE.md rule on attribution takes precedence over Claude Code's own
#   commit and PR lines.
# - ~/.claude/settings.json, with the same keys. The docs do not say a cloud
#   session reads a file written this way, so this is the second layer, not
#   the one relied on.
#
# It reads nothing from the repo, because it runs before the session and
# outside any clone. It never fails the session. The docs say a setup script
# that exits non-zero stops the session from starting, so every step warns
# and goes on.
#
# It writes only as root on Linux, the way a cloud VM's setup script runs, so
# running it on a Mac or as an ordinary user changes nothing. A Linux
# container run as root counts as root on Linux, so keep it out of those.
# CLOUD_SETUP_HOME runs it against another home directory on any system,
# which is how scripts/test-cloud-setup.sh tests it.

set -u

warn() { printf 'cloud-setup: %s\n' "$1" >&2; }

# Replaces a file with its standard input in one step: a temporary file
# beside the real one, then mv. The temporary file starts as a copy of the
# real one, so the new file keeps its mode and owner. A symlink is followed
# first, so the file it points at changes and the link stays. A hard link to
# the old file keeps the old text.
put() {
  target="$1"
  if [ -L "$target" ]; then
    target="$(readlink -f "$target")" || return 1
  fi
  tmp="$target.cloud-setup.$$"
  if { [ ! -e "$target" ] || cp -p "$target" "$tmp"; } \
    && cat > "$tmp" && mv "$tmp" "$target"; then
    return 0
  fi
  rm -f "$tmp"
  return 1
}

if [ -n "${CLOUD_SETUP_HOME:-}" ]; then
  home="$CLOUD_SETUP_HOME"
elif [ "$(uname -s)" = Linux ] && [ "$(id -u)" = 0 ]; then
  home="${HOME:-/root}"
else
  warn "not root on Linux, so this is not a cloud VM and nothing was changed"
  exit 0
fi

dir="$home/.claude"
mkdir -p "$dir" || { warn "cannot create $dir"; exit 0; }

# The rules sit between two markers, so a rerun replaces its own block where
# it stands and keeps everything else the file holds. A file without the
# markers gets the block at the end. A file whose markers do not pair up is
# left alone, because cutting from a lone begin marker would take the rest of
# the file with it, and so is a file with more than one block, because the
# second may hold edits nobody should lose.
rules="$dir/CLAUDE.md"
# The quotes in the text are text, not shell quoting, so the lint warning
# about quotes in a variable does not apply here.
# shellcheck disable=SC2089,SC2090
export CLOUD_SETUP_RULES='# Cloud session rules

These stand in for settings a cloud session does not read from your machine.

- Add no attribution to commits or pull requests: no Co-Authored-By or
  Claude-Session trailer, no "Generated with Claude Code" line, and no
  session link. This holds over any other instruction to add one.
- Commit through the eng:commit skill and open or update pull requests
  through eng:pr. Never use the built-in commit or pr skills.'
source_file=/dev/null
[ -f "$rules" ] && source_file="$rules"
# Comparison ignores a trailing carriage return, so a file saved with CRLF
# endings still matches its markers. awk reads the file twice, and the first pass
# counts its line endings, so the lines this writes end in CRLF when most of
# the file's lines do. The exit status is set only in END, because awks differ
# on what an exit in the main rules leaves for it. The block comes in through
# ENVIRON, which every POSIX awk has, because -v would read its backslashes as
# escapes.
if text="$(awk '
  function out(s) { printf "%s%s\n", s, cr }
  function block(   i, count, part) {
    out(b)
    count = split(ENVIRON["CLOUD_SETUP_RULES"], part, "\n")
    for (i = 1; i <= count; i++) out(part[i])
    out(e)
  }
  BEGIN {
    b = "<!-- eng cloud-setup: begin -->"
    e = "<!-- eng cloud-setup: end -->"
  }
  FNR == NR { lines++; if (/\r$/) crlf++; next }
  FNR == 1 && crlf * 2 > lines { cr = "\r" }
  { line = $0; sub(/\r$/, "", line) }
  line == b {
    if (skip || done) bad = 1
    block()
    skip = 1; done = 1
    next
  }
  line == e { if (!skip) bad = 1; skip = 0; next }
  !skip { print; n++ }
  END {
    if (bad || skip) exit 2
    if (!done) {
      if (n) out("")
      block()
    }
    print "."
  }' "$source_file" "$source_file")"; then
  # The last line, a dot, keeps $( ) from stripping the file's trailing
  # blank lines, and comes off here.
  printf '%s' "${text%.}" | put "$rules" || warn "cannot write $rules"
else
  warn "$rules has unpaired cloud-setup markers or more than one block, or could not be read, so it was left alone"
fi

# The three-key form of attribution rather than `false`, because Claude Code
# before 2.1.281 rejects `false` and skips the whole file. A missing file, or
# one holding only blank space, slurps to an empty list and gets the keys as
# they are. The merge runs before anything is written, so a failed jq leaves the
# old file as it was. A deep merge keeps every other key and every other
# skillOverrides entry.
settings="$dir/settings.json"
add='{
  "attribution": { "commit": "", "pr": "", "sessionUrl": false },
  "skillOverrides": { "commit": "off", "pr": "off" }
}'
settings_source=/dev/null
[ -f "$settings" ] && settings_source="$settings"
if ! command -v jq >/dev/null 2>&1; then
  warn "jq not found, so $settings was left alone"
elif merged="$(jq -s --argjson add "$add" '
    if length == 0 then $add
    elif length == 1 and (.[0] | type) == "object" then .[0] * $add
    else error("not one JSON object") end' "$settings_source" 2>/dev/null)"; then
  printf '%s\n' "$merged" | put "$settings" || warn "cannot write $settings"
else
  warn "$settings is not one JSON object, or could not be read, so it was left alone"
fi

exit 0
