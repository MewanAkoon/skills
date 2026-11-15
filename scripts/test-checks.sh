#!/usr/bin/env bash
# Runs the finding count in scripts/validate-plugin.sh against a stand-in
# claude that prints canned output. The count fails quietly when it goes
# wrong, by reading no finding, so a passing run of the wrapper says nothing
# on its own.
# Needs bash and the usual POSIX tools. check.sh runs it.

set -uo pipefail

SELF="$(readlink -f "$0" 2>/dev/null || true)"
[ -n "$SELF" ] || { printf 'error: readlink -f cannot resolve %s\n' "$0" >&2; exit 1; }
cd "$(dirname "$SELF")/.." || exit 1

fail=0
bad() { printf 'FAIL  %s\n' "$1" >&2; fail=1; }

scratch="$(mktemp -d)" && [ -n "$scratch" ] || { bad "mktemp -d failed"; exit 1; }
trap 'rm -rf "$scratch"' EXIT

# The wrapper's count.
#
# The stand-in prints $STUB_OUT and exits $STUB_STATUS for both of the
# wrapper's runs, and writes the arguments of each run to $STUB_LOG.
stub="$scratch/claude"
cat > "$stub" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$STUB_LOG"
printf '%s\n' "$STUB_OUT"
exit "${STUB_STATUS:-0}"
STUB
chmod +x "$stub"

# wrapper <ok|fails> <case name> <output> [status]
wrapper() {
  if CLAUDE_BIN="$stub" STUB_OUT="$3" STUB_STATUS="${4:-0}" STUB_LOG="$scratch/calls" \
    ./scripts/validate-plugin.sh >/dev/null 2>&1; then
    [ "$1" = ok ] || bad "validate-plugin: $2: passed"
  else
    [ "$1" = fails ] || bad "validate-plugin: $2: failed"
  fi
}

passed='✔ Validation passed'
wrapper ok "a clean run" "$passed"
# Both targets run: the marketplace at the root, and the plugin with --strict.
printf 'plugin validate .\nplugin validate plugins/eng --strict\n' > "$scratch/want"
cmp -s "$scratch/want" "$scratch/calls" \
  || bad "validate-plugin: a clean run: did not validate . and then plugins/eng --strict"
wrapper ok "a clean run with the plugin directory checks" \
  "$(printf '✔ These checks found nothing to report\n\n%s' "$passed")"
wrapper fails "a warning" "$(printf '⚠ Found 1 warning:\n\n  ❯ CLAUDE.md: x\n\n%s' "$passed")"
# What 2.1.318 printed over the root of the old layout, which the wrapper
# before 0.15.0 passed: the root CLAUDE.md warning it allowed, and a plugin
# directory warning it did not count.
wrapper fails "the root CLAUDE.md warning and a plugin directory warning" "$(printf '%s\n' \
  '⚠ Found 1 warning:' '' \
  '  ❯ CLAUDE.md at the plugin root is not loaded as plugin context.' '' \
  '⚠ Found 1 plugin directory warning:' '' \
  '  ❯ .claude-plugin/plugin.json icon: No icon (ICON_MISSING).' '' "$passed")"
wrapper fails "a plugin directory warning" \
  "$(printf '⚠ Found 1 plugin directory warning:\n\n  ❯ icon: x\n\n%s' "$passed")"
wrapper fails "a problem the plugin directory refuses" \
  "$(printf '✘ Found 1 problem the plugin directory refuses a submission for:\n\n  ❯ x\n\n%s' "$passed")"
wrapper fails "an error and two warnings" "$(printf '✘ Found 1 error and 2 warnings:\n\n%s' "$passed")"
wrapper fails "a finding with no count" "$(printf '⚠ warning: x\n\n%s' "$passed")"
wrapper fails "a run that exits non-zero" "$passed" 1

# The validator echoes the clone's path, and a clone under a folder named
# "errors" must not read as a finding. The wrapper runs from a copy there,
# and the stand-in prints the folder it runs in, as the real one does.
errors="$scratch/errors"
mkdir -p "$errors/scripts"
cp scripts/validate-plugin.sh "$errors/scripts/"
cat > "$scratch/claude-pwd" <<'STUB'
#!/bin/sh
printf 'Plugin directory checks for %s.\n\n%s\n' "$(pwd)" '✔ Validation passed'
STUB
chmod +x "$scratch/claude-pwd"
CLAUDE_BIN="$scratch/claude-pwd" "$errors/scripts/validate-plugin.sh" >/dev/null 2>&1 \
  || bad "validate-plugin: a clone under a folder named errors: failed"

[ "$fail" -eq 0 ] && printf 'checks: ok\n'
exit "$fail"
