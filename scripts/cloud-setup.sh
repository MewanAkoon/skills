#!/usr/bin/env bash
# The setup script for a personal Claude Code cloud environment. Paste it into
# the environment's Setup script box at claude.ai/code. It runs as root on the
# cloud VM before Claude Code starts, and the result is cached for about seven
# days.
#
# A cloud session reads nothing from ~/.claude on your machine, and a cloud
# thread in a project does not read the repo's .claude/settings.json either.
# So the skillOverrides and attribution entries the README's Setup adds never
# reach it. The first is there to keep the bare commit and pr skills, built
# in or a repo's own, from being invoked, and the second drops Claude's
# commit and PR lines and its session link. This writes both into the VM's
# own home instead, as rules and as settings, and adds the Setup's
# permission rules for gh stack to the settings:
#
# - ~/.claude/CLAUDE.md, which the cloud docs say a session loads as user
#   instructions. It carries both as rules, and the settings reference says a
#   CLAUDE.md rule on attribution takes precedence over Claude Code's own
#   commit and PR lines.
# - ~/.claude/settings.json, with the same keys and the permission rules. The
#   docs do not say a cloud session reads a file written this way, so this is
#   the second layer, not the one relied on.
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

# Replaces a file in one step: stage makes a temporary file beside the real
# one, the caller writes the new text into "$tmp", and finish moves it into
# place, or removes it when the write failed. mktemp picks a name nobody can
# guess ahead of time. The temporary file starts as a copy of the real one, so
# the new file keeps its mode and owner, and a file that does not exist yet
# gets the mode the umask gives, as a plain redirect would. A symlink is
# followed first, so the file it points at changes and the link stays. A hard
# link to the old file keeps the old text.
stage() {
  real="$1"
  if [ -L "$real" ]; then
    real="$(readlink -f "$real")" || return 1
  fi
  tmp="$(mktemp "$(dirname "$real")/.cloud-setup.XXXXXX")" && [ -n "$tmp" ] || return 1
  if [ -e "$real" ]; then
    cp -p "$real" "$tmp"
  else
    chmod "$(printf '%o' $((0666 & ~0$(umask))))" "$tmp"
  fi && return 0
  rm -f "$tmp"
  return 1
}

# $1 is the status of the write into "$tmp".
finish() {
  [ "$1" -eq 0 ] && mv "$tmp" "$real" && return 0
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
- Commit, and open or update pull requests, through the eng:commit and
  eng:pr skills, never a bare commit or pr skill, built in or one a repo
  carries. eng:commit and eng:pr read the commit or PR guidance a repo
  carries, its commit or pr skill included, as files and follow its format.
  Without eng, read that guidance yourself and use git and gh, and keep the
  attribution rule.'
source_file=/dev/null
[ -f "$rules" ] && source_file="$rules"
# Comparison ignores a trailing carriage return, so a file saved with CRLF
# endings still matches its markers. awk reads the file twice, and the first
# pass counts its line endings, so the lines this writes end in CRLF when most
# of the file's lines do. The exit status is set only in END, because awks
# differ on what an exit in the main rules leaves for it. The block comes in
# through ENVIRON, which every POSIX awk has, because -v would read its
# backslashes as escapes. awk writes straight into the temporary file, and a
# failed run leaves the real one as it was.
if ! stage "$rules"; then
  warn "cannot write $rules"
elif awk '
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
  }' "$source_file" "$source_file" > "$tmp"; then
  finish 0 || warn "cannot write $rules"
else
  finish 1
  warn "$rules has unpaired cloud-setup markers or more than one block, or could not be read, so it was left alone"
fi

# The three-key form of attribution rather than `false`, because Claude Code
# before 2.1.281 rejects `false` and skips the whole file. A missing file, or
# one holding only blank space, slurps to an empty list and gets the keys as
# they are. jq writes into the temporary file, so a failed merge leaves the old
# file as it was. A deep merge keeps every other key and every other
# skillOverrides entry. jq's deep merge replaces a list rather than joining
# it, so permissions.allow and permissions.ask are joined by hand: every rule
# already there stays, in its place, and a rule this adds goes on the end
# unless it is there already. A permissions that is not an object, or an
# allow or ask that is not a list, leaves the file alone.
settings="$dir/settings.json"
add='{
  "attribution": { "commit": "", "pr": "", "sessionUrl": false },
  "skillOverrides": { "commit": "off", "pr": "off" },
  "permissions": {
    "allow": ["Bash(gh stack:*)"],
    "ask": ["Bash(gh stack merge:*)", "Bash(gh stack unstack:*)"]
  }
}'
settings_source=/dev/null
[ -f "$settings" ] && settings_source="$settings"
if ! command -v jq >/dev/null 2>&1; then
  warn "jq not found, so $settings was left alone"
elif ! stage "$settings"; then
  warn "cannot write $settings"
elif jq -s --argjson add "$add" '
    def union(a; b): reduce b[] as $x (a; if any(.[]; . == $x) then . else . + [$x] end);
    if length == 0 then $add
    elif length == 1 and (.[0] | type) == "object" then
      .[0] as $f
      | ($f.permissions // {}) as $p
      | if ($p | type) != "object" then error("permissions is not an object")
        elif [$p.allow // [], $p.ask // []] | any(type != "array") then error("allow or ask is not a list")
        else ($f * ($add | del(.permissions)))
          | .permissions = ($p
              | .allow = union(.allow // []; $add.permissions.allow)
              | .ask = union(.ask // []; $add.permissions.ask))
        end
    else error("not one JSON object") end' "$settings_source" > "$tmp" 2>/dev/null; then
  finish 0 || warn "cannot write $settings"
else
  finish 1
  warn "$settings is not one JSON object, holds permissions that are not an object or lists, or could not be read, so it was left alone"
fi

exit 0
