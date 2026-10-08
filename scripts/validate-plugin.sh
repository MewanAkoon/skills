#!/usr/bin/env bash
# Runs `claude plugin validate` over this repo and fails on any error, and on
# any warning but one.
#
# The one allowed warning is the root CLAUDE.md, which is there for work on
# this repo and is not part of the plugin. `--strict` would fail on it, as it
# does for mattpocock/skills, so this filters that line out instead and fails
# on everything else.
#
# CLAUDE_BIN names the claude binary to run, so CI can pin a version.

set -uo pipefail

SELF="$(readlink -f "$0" 2>/dev/null || true)"
[ -n "$SELF" ] || { printf 'error: readlink -f cannot resolve %s\n' "$0" >&2; exit 1; }
cd "$(dirname "$SELF")/.." || exit 1

# Unquoted on purpose, so CLAUDE_BIN can be a command with arguments, such as
# an npx call that pins a version.
# shellcheck disable=SC2086
out="$(${CLAUDE_BIN:-claude} plugin validate . 2>&1)"
status=$?
printf '%s\n' "$out"

if [ "$status" -ne 0 ]; then
  echo "validate: claude plugin validate exited $status" >&2
  exit 1
fi

# Each "Validating" line echoes a path, and a clone under a folder named
# "errors" would otherwise read as a finding. What is left is the findings and
# their summaries.
report="$(printf '%s\n' "$out" | grep -v '^Validating ' || true)"

# The summary line counts the findings ("Found 1 warning"). Read the count
# rather than a per-line marker, so a change to how lines are drawn cannot
# hide a new one. The only finding allowed is the root CLAUDE.md warning.
found="$(printf '%s\n' "$report" | sed -nE 's/.*Found ([0-9]+) (warning|error).*/\1 \2/p')"
allowed="$(printf '%s\n' "$report" | grep -cF 'CLAUDE.md at the plugin root is not loaded' || true)"
total=0
while read -r n _; do
  [ -n "$n" ] && total=$((total + n))
done <<< "$found"
# A warning or an error with no count parsed means the summary changed shape,
# and a count of zero would wave every finding through.
if [ -z "$found" ] && printf '%s\n' "$report" | grep -qiE 'warning|error'; then
  echo "validate: the output mentions findings but no count was read; check the summary format" >&2
  exit 1
fi
if [ "$total" -gt "$allowed" ]; then
  echo "validate: $total findings, and only the root CLAUDE.md warning is allowed" >&2
  exit 1
fi
echo "validate: ok"
