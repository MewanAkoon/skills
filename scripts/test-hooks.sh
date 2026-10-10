#!/usr/bin/env bash
# Runs hooks/eng-hook against the inputs in tests/hooks and checks what comes
# out. The checks read the block's shape rather than a stored copy of it, so
# editing the contract or the writing rules does not mean editing a fixture.
# Needs bash, jq, and the usual POSIX tools. CI runs it.

set -uo pipefail

SELF="$(readlink -f "$0" 2>/dev/null || true)"
[ -n "$SELF" ] || { printf 'error: readlink -f cannot resolve %s\n' "$0" >&2; exit 1; }
cd "$(dirname "$SELF")/.." || exit 1

fail=0
bad() { printf 'FAIL  %s\n' "$1" >&2; fail=1; }

hook=hooks/eng-hook
inputs=tests/hooks/session-start
contract=standards/workflow.md
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# Runs the hook with $1 on stdin and any extra environment after it. The
# output goes to $scratch/out, the exit status to $status.
run() {
  local input="$1"; shift
  env "$@" "$hook" session-start < "$input" > "$scratch/out" 2> "$scratch/err"
  status=$?
}

# The block carries every line of the contract and the two writing sections,
# and stops before the next one.
check_block() {
  local name="$1" text="$2"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    printf '%s\n' "$text" | grep -qxF -- "$line" \
      || { bad "$name: the block is missing a line of $contract: $line"; return; }
  done < "$contract"
  printf '%s\n' "$text" | grep -qx '## Punctuation' || bad "$name: no Punctuation section"
  printf '%s\n' "$text" | grep -qx '## Word choice' || bad "$name: no Word choice section"
  printf '%s\n' "$text" | grep -qx '## Sentences' && bad "$name: the block runs past Word choice"
  local size
  size="$(printf '%s' "$text" | LC_ALL=C wc -c | tr -d ' ')"
  [ "$size" -le 5000 ] || bad "$name: the block is $size bytes, over the budget of 5000"
}

for source in startup resume clear compact; do
  run "$inputs/$source.json" CLAUDE_PLUGIN_DATA="$scratch/data-$source"
  [ "$status" -eq 0 ] || bad "$source: exited $status"
  if ! jq -e . "$scratch/out" >/dev/null 2>&1; then
    bad "$source: the output is not JSON"
    continue
  fi
  [ "$(jq -r '.hookSpecificOutput.hookEventName' "$scratch/out")" = SessionStart ] \
    || bad "$source: hookEventName is not SessionStart"
  reload="$(jq -r '.hookSpecificOutput.reloadSkills // false' "$scratch/out")"
  if [ "$source" = compact ]; then
    [ "$reload" = true ] || bad "compact: reloadSkills is not set"
  else
    [ "$reload" = false ] || bad "$source: reloadSkills is set outside a compaction"
  fi
  check_block "$source" "$(jq -r '.hookSpecificOutput.additionalContext' "$scratch/out")"
  [ ! -s "$scratch/data-$source/eng-hook.log" ] || bad "$source: wrote to the error log"
done

# Input that is not JSON still gets the block, without the reload.
run "$inputs/malformed.json"
[ "$status" -eq 0 ] || bad "malformed input: exited $status"
[ "$(jq -r '.hookSpecificOutput.reloadSkills // false' "$scratch/out" 2>/dev/null)" = false ] \
  || bad "malformed input: the output is not JSON, or asks for a reload"

# An unknown mode prints nothing, logs, and exits 0.
env CLAUDE_PLUGIN_DATA="$scratch/data-mode" "$hook" bogus < "$inputs/startup.json" > "$scratch/out" 2>/dev/null \
  || bad "unknown mode: exited non-zero"
[ ! -s "$scratch/out" ] || bad "unknown mode: printed output"
grep -q "unknown mode" "$scratch/data-mode/eng-hook.log" 2>/dev/null || bad "unknown mode: nothing in the log"

# A plugin root with a space in it, and a missing contract.
spaced="$scratch/plugin root"
mkdir -p "$spaced/standards" "$spaced/skills/plain-writing"
cp "$contract" "$spaced/standards/"
cp skills/plain-writing/SKILL.md "$spaced/skills/plain-writing/"
run "$inputs/startup.json" CLAUDE_PLUGIN_ROOT="$spaced"
[ "$status" -eq 0 ] && check_block "spaced root" "$(jq -r '.hookSpecificOutput.additionalContext' "$scratch/out" 2>/dev/null)"
# Without plain-writing the contract still goes out, and the log says why the
# writing rules did not.
mv "$spaced/skills/plain-writing/SKILL.md" "$scratch/SKILL.md"
run "$inputs/startup.json" CLAUDE_PLUGIN_ROOT="$spaced" CLAUDE_PLUGIN_DATA="$scratch/data-nowriting"
ctx="$(jq -r '.hookSpecificOutput.additionalContext' "$scratch/out" 2>/dev/null)"
printf '%s\n' "$ctx" | grep -qF "$(head -1 "$contract")" || bad "missing plain-writing: the contract did not go out"
printf '%s\n' "$ctx" | grep -qx '## Punctuation' && bad "missing plain-writing: sent writing rules anyway"
grep -q "plain-writing" "$scratch/data-nowriting/eng-hook.log" 2>/dev/null || bad "missing plain-writing: nothing in the log"
mv "$scratch/SKILL.md" "$spaced/skills/plain-writing/SKILL.md"

rm "$spaced/standards/workflow.md"
run "$inputs/startup.json" CLAUDE_PLUGIN_ROOT="$spaced" CLAUDE_PLUGIN_DATA="$scratch/data-missing"
[ "$status" -eq 0 ] || bad "missing contract: exited $status"
[ ! -s "$scratch/out" ] || bad "missing contract: printed output"
grep -q "cannot read" "$scratch/data-missing/eng-hook.log" 2>/dev/null || bad "missing contract: nothing in the log"

# Without jq the block goes out as plain text, and the log says so.
nojq="$scratch/bin"
mkdir -p "$nojq"
for tool in cat dirname awk date mkdir; do
  ln -s "$(command -v "$tool")" "$nojq/$tool"
done
run "$inputs/startup.json" PATH="$nojq" CLAUDE_PLUGIN_DATA="$scratch/data-nojq"
[ "$status" -eq 0 ] || bad "no jq: exited $status"
check_block "no jq" "$(cat "$scratch/out")"
grep -q "jq not found" "$scratch/data-nojq/eng-hook.log" 2>/dev/null || bad "no jq: nothing in the log"

[ "$fail" -eq 0 ] && printf 'hooks: ok\n'
exit "$fail"
