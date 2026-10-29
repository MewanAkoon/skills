#!/usr/bin/env bash
# Runs scripts/cloud-setup.sh against scratch homes and checks what it writes.
# The script runs only on a cloud VM, where nobody watches it, so this stands
# in for that run. Every run has to exit 0, since the docs say a setup script
# that does not stops the session from starting.
# Needs bash, jq, awk, and the usual POSIX tools. check.sh runs it.

set -uo pipefail

SELF="$(readlink -f "$0" 2>/dev/null || true)"
[ -n "$SELF" ] || { printf 'error: readlink -f cannot resolve %s\n' "$0" >&2; exit 1; }
cd "$(dirname "$SELF")/.." || exit 1

fail=0
bad() { printf 'FAIL  %s\n' "$1" >&2; fail=1; }

script=scripts/cloud-setup.sh
begin='<!-- eng cloud-setup: begin -->'
end='<!-- eng cloud-setup: end -->'
# An empty home would send the script at the real one, so nothing runs
# without a scratch directory.
scratch="$(mktemp -d)" && [ -n "$scratch" ] || { bad "mktemp -d failed"; exit 1; }
trap 'rm -rf "$scratch"' EXIT
home="$scratch/home"
rules="$home/.claude/CLAUDE.md"
settings="$home/.claude/settings.json"
mkdir -p "$home/.claude"

# Runs the script against the scratch home, and names the case on failure.
run() {
  CLOUD_SETUP_HOME="$home" "$script" 2>/dev/null || bad "$1: exited non-zero"
}

# A home that already holds a line and a key of the user's keeps both, and a
# rerun leaves one block.
printf 'my own rule\n' > "$rules"
printf '{"theme":"dark","skillOverrides":{"x":"off"}}\n' > "$settings"
chmod 600 "$settings"
run "first run"
run "rerun"
[ "$(grep -c "$begin" "$rules")" = 1 ] || bad "rerun: not exactly one rules block"
grep -qx 'my own rule' "$rules" || bad "rerun: CLAUDE.md lost a line it did not write"
# $( ) is empty for a final newline, and the cases below lean on it: without
# one, a line added later joins the end marker.
[ -z "$(tail -c 1 "$rules")" ] || bad "rerun: CLAUDE.md does not end in a newline"
jq -e '.theme == "dark" and .skillOverrides.x == "off"
  and .attribution == {commit: "", pr: "", sessionUrl: false}
  and .skillOverrides.commit == "off" and .skillOverrides.pr == "off"' \
  "$settings" >/dev/null 2>&1 \
  || bad "rerun: settings.json lacks its keys or lost one it did not write"
[ -n "$(find "$settings" -perm 600)" ] \
  || bad "rerun: settings.json lost its mode"

# A block from an older version of this script gets today's rules in its
# place.
printf '%s\n' 'top' "$begin" 'old rules' "$end" 'bottom' > "$rules"
run "older block"
grep -qx 'old rules' "$rules" && bad "older block: its text is still there"
grep -q 'eng:commit' "$rules" || bad "older block: today's rules are missing"
[ "$(grep -c "$begin" "$rules")" = 1 ] || bad "older block: not exactly one rules block"
[ "$(head -n 1 "$rules")" = top ] && [ "$(tail -n 1 "$rules")" = bottom ] \
  || bad "older block: the lines around it moved"

# Two whole blocks, as a hand copy leaves them, are left as they are, since
# the second may hold edits.
printf '%s\n' 'top' "$begin" 'x' "$end" 'middle' "$begin" 'y' "$end" 'bottom' > "$rules"
cp "$rules" "$scratch/before"
run "two blocks"
cmp -s "$scratch/before" "$rules" || bad "two blocks: CLAUDE.md changed"

# A file saved with CRLF endings keeps them on every line, the block's too,
# and a rerun leaves one block.
printf 'mine\r\n' > "$rules"
run "CRLF"
run "CRLF rerun"
[ "$(grep -c "$begin" "$rules")" = 1 ] || bad "CRLF: not exactly one rules block"
[ "$(grep -c "$(printf '\r')\$" "$rules")" = "$(wc -l < "$rules" | tr -d ' ')" ] \
  || bad "CRLF: some lines lost their carriage return"
# The cases below start from a plain LF file again.
rm -f "$rules"
run "fresh CLAUDE.md"

# A line and blank lines after the block stay where they are, so the block is
# replaced in place, not moved to the end.
printf 'a later rule\n\n\n' >> "$rules"
cp "$rules" "$scratch/before"
run "rerun after a later line"
cmp -s "$scratch/before" "$rules" || bad "rerun after a later line: CLAUDE.md changed"

# A symlinked CLAUDE.md keeps its link, and the file it points at keeps its
# own line and gains the block.
printf 'linked rule\n' > "$scratch/linked"
rm -f "$rules"
ln -s "$scratch/linked" "$rules"
run "symlinked CLAUDE.md"
[ -L "$rules" ] || bad "symlinked CLAUDE.md: the link was replaced"
grep -qx 'linked rule' "$scratch/linked" || bad "symlinked CLAUDE.md: the target lost its line"
grep -q "$begin" "$scratch/linked" || bad "symlinked CLAUDE.md: the target has no rules block"
rm -f "$rules"

# Markers that do not pair up, and settings that are not one JSON object,
# are left as they were.
for marker in "$begin" "$end"; do
  printf '%s\n' 'top' "$marker" 'keep me' > "$rules"
  cp "$rules" "$scratch/before"
  run "lone marker $marker"
  cmp -s "$scratch/before" "$rules" || bad "lone marker $marker: CLAUDE.md changed"
done
for text in '[1]' '{} {}' 'not json'; do
  printf '%s\n' "$text" > "$settings"
  cp "$settings" "$scratch/before"
  run "settings.json holding $text"
  cmp -s "$scratch/before" "$settings" || bad "settings.json holding $text: it changed"
done

# A missing file, and one holding only blank space, both get the keys.
for text in missing blank; do
  rm -f "$settings" "$rules"
  [ "$text" = blank ] && printf ' \n\n' > "$settings"
  run "$text settings.json"
  jq -e '.attribution.sessionUrl == false' "$settings" >/dev/null 2>&1 \
    || bad "$text settings.json: the keys were not written"
  [ "$(head -n 1 "$rules")" = "$begin" ] || bad "$text CLAUDE.md: it does not start with the block"
done

# Off a cloud VM, with CLOUD_SETUP_HOME unset or empty, it writes nothing to
# HOME. Root on Linux counts as a cloud VM, so there the case says it was
# skipped.
if [ "$(uname -s)" = Linux ] && [ "$(id -u)" = 0 ]; then
  printf 'test-cloud-setup: skip  not a cloud VM, since this runs as root on Linux\n' >&2
else
  mkdir -p "$scratch/real"
  env -u CLOUD_SETUP_HOME HOME="$scratch/real" "$script" 2>/dev/null \
    || bad "not a cloud VM: exited non-zero"
  CLOUD_SETUP_HOME='' HOME="$scratch/real" "$script" 2>/dev/null \
    || bad "not a cloud VM, empty CLOUD_SETUP_HOME: exited non-zero"
  [ -z "$(ls -A "$scratch/real")" ] || bad "not a cloud VM: it wrote to HOME"
fi

[ "$fail" -eq 0 ] && printf 'cloud-setup: ok\n'
exit "$fail"
