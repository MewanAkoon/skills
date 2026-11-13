#!/usr/bin/env bash
# Runs `claude plugin validate` twice and fails on any finding: once over the
# repo root, which reads the marketplace, and once over plugins/eng with
# --strict, which reads the plugin. From 2.1.318 the second run also brings
# the plugin directory checks, which run on any plugin folder.
#
# --strict alone is not enough. On 2.1.318 it exits 0 with a plugin directory
# warning showing, so this reads the summary counts too.
#
# CLAUDE_BIN names the claude binary to run, so CI can pin a version.

set -uo pipefail

SELF="$(readlink -f "$0" 2>/dev/null || true)"
[ -n "$SELF" ] || { printf 'error: readlink -f cannot resolve %s\n' "$0" >&2; exit 1; }
cd "$(dirname "$SELF")/.." || exit 1

here="$(pwd)"
here_real="$(pwd -P)"

# validate <args...>: one run, its output printed, and a non-zero return on
# any finding or a failed run.
validate() {
  # Unquoted on purpose, so CLAUDE_BIN can be a command with arguments, such
  # as an npx call that pins a version.
  # shellcheck disable=SC2086
  out="$(${CLAUDE_BIN:-claude} plugin validate "$@" 2>&1)"
  status=$?
  printf '%s\n' "$out"

  if [ "$status" -ne 0 ]; then
    echo "validate: claude plugin validate $* exited $status" >&2
    return 1
  fi

  # The output echoes this clone's path in several places, and a clone under a
  # folder named "errors" would otherwise read as a finding. What is left is
  # the findings and their summaries.
  report="$(printf '%s\n' "$out" | grep -v '^Validating ' || true)"
  report="${report//"$here_real"/<repo>}"
  report="${report//"$here"/<repo>}"

  # A summary line counts the findings: "Found 1 warning", "Found 1 plugin
  # directory warning", "Found 1 problem the plugin directory refuses a
  # submission for". Read the count rather than a per-line marker, so a change
  # to how lines are drawn cannot hide a new one, and read every count on such
  # a line, whatever noun follows it, so "Found 1 error and 2 warnings" adds up
  # to 3.
  found="$(printf '%s\n' "$report" | grep -E 'Found [0-9]+ ' | grep -oE '[0-9]+ [a-z]+' || true)"
  total=0
  while read -r n _; do
    [ -n "$n" ] && total=$((total + n))
  done <<< "$found"

  # A finding with no count read means the summary changed shape, and a count
  # of zero would wave every finding through.
  if [ -z "$found" ] && printf '%s\n' "$report" | grep -qiE 'warning|error|problem'; then
    echo "validate: claude plugin validate $* mentions findings but no count was read; check the summary format" >&2
    return 1
  fi
  if [ "$total" -gt 0 ]; then
    echo "validate: claude plugin validate $* found $total, and none is allowed" >&2
    return 1
  fi
}

failed=0
validate . || failed=1
validate plugins/eng --strict || failed=1
[ "$failed" -eq 0 ] || exit 1
echo "validate: ok"
