#!/usr/bin/env bash
# Runs plugins/eng/hooks/eng-hook against the inputs in tests/hooks and checks what comes
# out: the session block, then the guards, which read the cases in
# tests/hooks/pre-tool and a scratch repo for the review reminder. The checks read
# the block's shape rather than a stored copy of it, so editing the contract
# or the writing rules does not mean editing a fixture.
# Needs bash, jq, git, and the usual POSIX tools. CI runs it.

set -uo pipefail

SELF="$(readlink -f "$0" 2>/dev/null || true)"
[ -n "$SELF" ] || { printf 'error: readlink -f cannot resolve %s\n' "$0" >&2; exit 1; }
cd "$(dirname "$SELF")/.." || exit 1

fail=0
bad() { printf 'FAIL  %s\n' "$1" >&2; fail=1; }

# Values left over from the calling shell would point the hook at another
# copy's files, so each run below gets only the ones it sets.
unset CLAUDE_PLUGIN_ROOT CLAUDE_PLUGIN_DATA

plugin=plugins/eng
hook="$plugin/hooks/eng-hook"
inputs=tests/hooks/session-start
contract="$plugin/standards/workflow.md"
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
    # A here-string, not a pipe: grep -q stops reading at its first match,
    # and with pipefail the writer's broken pipe would fail the check.
    grep -qxF -- "$line" <<< "$text" \
      || { bad "$name: the block is missing a line of $contract: $line"; return; }
  done < "$contract"
  grep -qx '## Punctuation' <<< "$text" || bad "$name: no Punctuation section"
  grep -qx '## Word choice' <<< "$text" || bad "$name: no Word choice section"
  grep -qx '## Sentences' <<< "$text" && bad "$name: the block runs past Word choice"
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
cp "$plugin/skills/plain-writing/SKILL.md" "$spaced/skills/plain-writing/"
run "$inputs/startup.json" CLAUDE_PLUGIN_ROOT="$spaced"
[ "$status" -eq 0 ] || bad "spaced root: exited $status"
check_block "spaced root" "$(jq -r '.hookSpecificOutput.additionalContext' "$scratch/out" 2>/dev/null)"
# The command line hooks.json gives Claude Code, run through sh as a hook runs,
# with the root left for the shell to expand and with it written in place. A
# lost quote around the root splits the path at the space.
mkdir -p "$spaced/hooks"
cp "$hook" "$spaced/hooks/"
command="$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$plugin/hooks/hooks.json")"
for form in expanded written; do
  line="$command"
  # Split around the placeholder rather than substitute, because bash 5.2
  # reads & in a replacement as the matched text, and bash 3.2 keeps quotes.
  [ "$form" = written ] &&
    line="${command%%"\${CLAUDE_PLUGIN_ROOT}"*}$spaced${command#*"\${CLAUDE_PLUGIN_ROOT}"}"
  env CLAUDE_PLUGIN_ROOT="$spaced" sh -c "$line" < "$inputs/startup.json" > "$scratch/out" 2> "$scratch/err"
  status=$?
  [ "$status" -eq 0 ] || bad "hooks.json command, root $form: exited $status"
  check_block "hooks.json command, root $form" "$(jq -r '.hookSpecificOutput.additionalContext' "$scratch/out" 2>/dev/null)"
done
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

# The guards. Each session below has its own state under $data, which the
# hook reads from ${CLAUDE_PLUGIN_DATA}/sessions/<session>/.
data="$scratch/data-gates"

# Runs mode $1 with the JSON $2 on stdin. The output goes to $scratch/out.
hook_run() {
  printf '%s' "$2" | env CLAUDE_PLUGIN_DATA="$data" "$hook" "$1" > "$scratch/out" 2> "$scratch/err"
  status=$?
  # A classifier that fails makes the hook ask, which a case expecting ask
  # would pass, so a failure fails the run whatever the case expects.
  ! grep -q 'the command parser failed' "$scratch/err" || bad "$1: the command parser failed on: $2"
}

# Prints the PreToolUse decision in $scratch/out: allow when the hook printed
# nothing.
verdict() {
  if [ ! -s "$scratch/out" ]; then printf 'allow'; return; fi
  jq -r '.hookSpecificOutput.permissionDecision // "unreadable"' "$scratch/out" 2>/dev/null || printf 'unreadable'
}

# Runs the pre-tool mode on a Bash command, $2, in session $1, with the JSON
# object $3, when given, merged into the input.
bash_call() {
  local extra="${3:-}"
  [ -n "$extra" ] || extra='{}'
  hook_run pre-tool "$(jq -cn --arg s "$1" --arg c "$2" --argjson x "$extra" \
    '{session_id: $s, cwd: "/tmp", hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}} + $x')"
}

# Checks that session $1's Bash command $3 gets decision $2, and when $4 is
# given, that the reason holds it.
expect_bash() {
  bash_call "$1" "$3"
  local got
  got="$(verdict)"
  [ "$status" -eq 0 ] || bad "pre-tool exited $status on: $3"
  [ "$got" = "$2" ] || { bad "pre-tool: got $got, want $2, for: $3"; return; }
  if [ -n "${4:-}" ]; then
    jq -r '.hookSpecificOutput.permissionDecisionReason' "$scratch/out" | grep -qF -- "$4" \
      || bad "pre-tool: the reason for '$3' does not say '$4'"
  fi
}

# The main session leaves a commit, push, pull request or issue write to
# Claude Code's own permissions, so the command cases, all run in session
# "all", read what the post guard and the confirmation prompt decide.

# commands.cases: "== <expect> <note>" starts a case, and the lines after it
# up to the next one are the command.
cases=tests/hooks/pre-tool/commands.cases
count=0
expect="" command="" started=no
run_case() {
  [ "$started" = yes ] || return 0
  expect_bash all "$expect" "$command"
  count=$((count + 1))
}
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    "== "*)
      run_case
      expect="${line#== }"
      expect="${expect%% *}"
      command="" started=yes ;;
    *)
      [ "$started" = yes ] || continue
      if [ -z "$command" ]; then command="$line"; else command="$command
$line"; fi ;;
  esac
done < "$cases"
run_case
want="$(grep -c '^== ' "$cases")"
[ "$count" -eq "$want" ] || bad "commands.cases: ran $count of $want cases"

# mcp.cases: one "<expect> <tool name> [<tool input>]" per line.
count=0
while IFS=' ' read -r expect tool tool_input; do
  case "$expect" in deny | ask | allow) ;; *) continue ;; esac
  [ -n "$tool_input" ] || tool_input='{}'
  if ! call="$(jq -cn --arg t "$tool" --argjson i "$tool_input" '{session_id: "all", cwd: "/tmp", tool_name: $t, tool_input: $i}' 2>/dev/null)"; then
    bad "mcp.cases: the input for $tool is not JSON: $tool_input"
    count=$((count + 1))
    continue
  fi
  hook_run pre-tool "$call"
  got="$(verdict)"
  [ "$got" = "$expect" ] || bad "pre-tool: got $got, want $expect, for $tool $tool_input"
  count=$((count + 1))
done < tests/hooks/pre-tool/mcp.cases
want="$(grep -Ec '^(deny|ask|allow) ' tests/hooks/pre-tool/mcp.cases)"
[ "$count" -eq "$want" ] || bad "mcp.cases: ran $count of $want cases"

# The terminal tool that runs a command is read as a shell command.
terminal() {
  hook_run pre-tool "$(jq -cn --arg s "$1" --arg c "$2" '{session_id: $s, cwd: "/tmp", tool_name: "mcp__terminal__run_in_terminal", tool_input: {command: $c}}')"
}
terminal all 'gh pr comment 5 -b x'
[ "$(verdict)" = deny ] || bad "pre-tool: a post through the terminal tool was not denied"
terminal all 'npm run dev'
[ "$(verdict)" = allow ] || bad "pre-tool: a dev server through the terminal tool was not allowed"

# A command parser that fails asks rather than allows, and what it found
# before it stopped still counts. A stand-in classifier in a scratch plugin
# root prints $1 and exits 2, as gawk 5.3 did with an internal error. The
# tool is $3, or Bash, and the JSON object $4, when given, is merged into the
# input.
broken="$scratch/broken"
mkdir -p "$broken/hooks"
parser_fails() {
  local extra="${4:-}"
  [ -n "$extra" ] || extra='{}'
  printf 'BEGIN { %s exit 2 }\n' "$1" > "$broken/hooks/classify-command.awk"
  rm -f "$scratch/data-broken/eng-hook.log"
  jq -cn --arg c "$2" --arg t "${3:-Bash}" --argjson x "$extra" \
    '{session_id: "all", cwd: "/tmp", tool_name: $t, tool_input: {command: $c}} + $x' |
    env CLAUDE_PLUGIN_ROOT="$broken" CLAUDE_PLUGIN_DATA="$scratch/data-broken" "$hook" pre-tool > "$scratch/out" 2> /dev/null
  status=$?
  [ "$status" -eq 0 ] || bad "parser failure: exited $status on: $2"
  grep -q 'the command parser failed with exit status 2' "$scratch/data-broken/eng-hook.log" 2>/dev/null \
    || bad "parser failure: the log does not give the exit status for: $2"
}
parser_fails '' 'ls'
[ "$(verdict)" = ask ] || bad "parser failure: a command with nothing found got $(verdict), want ask"
jq -r '.hookSpecificOutput.permissionDecisionReason' "$scratch/out" 2>/dev/null | grep -q 'parser failed' \
  || bad "parser failure: the reason does not name the parser"
parser_fails 'print "post gh pr comment";' 'gh pr comment 5 -b x'
[ "$(verdict)" = deny ] || bad "parser failure: a post found before the failure got $(verdict), want deny"
parser_fails 'print "confirm a deploy";' './deploy.sh'
[ "$(verdict)" = ask ] || bad "parser failure: a deploy found before the failure got $(verdict), want ask"
reason="$(jq -r '.hookSpecificOutput.permissionDecisionReason' "$scratch/out" 2>/dev/null)"
case "$reason" in *"a deploy"*"parser failed"*) ;; *) bad "parser failure: the reason does not name both the deploy and the parser: $reason" ;; esac
parser_fails '' 'ls' mcp__terminal__run_in_terminal
[ "$(verdict)" = ask ] || bad "parser failure: a command through the terminal tool got $(verdict), want ask"
# A subagent's write found before the failure is still denied. One in the main
# session still asks, and says why.
parser_fails 'print "gate push";' 'git push origin x' Bash '{"agent_id": "a1"}'
[ "$(verdict)" = deny ] || bad "parser failure: a subagent's push found before the failure got $(verdict), want deny"
jq -r '.hookSpecificOutput.permissionDecisionReason' "$scratch/out" 2>/dev/null | grep -q 'A subagent does not' \
  || bad "parser failure: the deny for a subagent's push does not come from the subagent rule"
parser_fails 'print "gate push";' 'git push origin x'
[ "$(verdict)" = ask ] || bad "parser failure: a push in the main session got $(verdict), want ask"
jq -r '.hookSpecificOutput.permissionDecisionReason' "$scratch/out" 2>/dev/null | grep -q 'parser failed' \
  || bad "parser failure: the reason for a push in the main session does not name the parser"

# A parser still running at its time limit is stopped, and the hook asks
# rather than letting Claude Code stop the hook and run the command unread.
# A stand-in that prints $1 and then never ends stands for a slow parser,
# under a one-second limit. A timeout is not a fault, so nothing is logged.
parser_slow() {
  printf 'BEGIN { %s fflush(); while (1) n++ }\n' "$1" > "$broken/hooks/classify-command.awk"
  rm -f "$scratch/data-broken/eng-hook.log"
  local started ended
  started="$(date +%s)"
  jq -cn --arg c "$2" '{session_id: "all", cwd: "/tmp", tool_name: "Bash", tool_input: {command: $c}}' |
    env CLAUDE_PLUGIN_ROOT="$broken" CLAUDE_PLUGIN_DATA="$scratch/data-broken" ENG_HOOK_PARSE_SECONDS=1 \
      "$hook" pre-tool > "$scratch/out" 2> /dev/null
  status=$?
  ended="$(date +%s)"
  [ "$status" -eq 0 ] || bad "slow parser: exited $status on: $2"
  [ $((ended - started)) -le 4 ] || bad "slow parser: the hook took $((ended - started)) s under a 1 s limit"
  [ ! -s "$scratch/data-broken/eng-hook.log" ] || bad "slow parser: a timeout was logged as an error"
}
parser_slow '' 'ls'
[ "$(verdict)" = ask ] || bad "slow parser: a command with nothing found got $(verdict), want ask"
jq -r '.hookSpecificOutput.permissionDecisionReason' "$scratch/out" 2>/dev/null | grep -q 'time limit' \
  || bad "slow parser: the reason does not name the time limit"
parser_slow 'print "post gh pr comment";' 'gh pr comment 5 -b x'
[ "$(verdict)" = deny ] || bad "slow parser: a post found before the limit got $(verdict), want deny"

# A long command reads well inside the limit: a megabyte in one quoted
# string, and a megabyte of heredoc, each with a post at the end. jq reads
# the command from a file, because Linux refuses one argument over 128 KiB.
long="$scratch/long"
long_post() {
  hook_run pre-tool "$(jq -cn --rawfile c "$long" '{session_id: "all", cwd: "/tmp", tool_name: "Bash", tool_input: {command: $c}}')"
  [ "$(verdict)" = deny ] || bad "long command: $1 got $(verdict), want deny"
  jq -r '.hookSpecificOutput.permissionDecisionReason' "$scratch/out" 2>/dev/null | grep -q 'Posting' \
    || bad "long command: $1 was not denied as a post"
}
awk 'BEGIN { printf "printf \"%s\" > f; gh pr comment 1 -b x", sprintf("%1000000s", "") }' > "$long"
long_post "a megabyte quoted string"
{ printf 'cat > f <<EOF\n'; awk 'BEGIN { for (i = 0; i < 16000; i++) print "line " i " of a long heredoc body with some text in it" }'; printf 'EOF\ngh pr comment 1 -b x\n'; } > "$long"
long_post "a long heredoc"
awk 'BEGIN { printf "printf \""; for (i = 0; i < 200000; i++) printf "ab\\\"c"; printf "\" > f; gh pr comment 1 -b x" }' > "$long"
long_post "a quoted string cut up by escapes"

# Every remote write the hook finds from a subagent is denied, with the one
# reason: a shell command's, a post through any MCP tool, an MCP write whose
# name asks, and the GitHub and git MCP writes it maps. Its reads still pass.
subagent='{"agent_id": "a1", "agent_type": "general-purpose"}'
for command in 'gh stack push' 'gh stack sync' 'gh stack submit --auto' 'gh stack merge 42 --yes' \
  'gh stack unstack' 'gh stack link 41 42' 'git commit -m x' 'git push origin x' 'gh pr create --fill' \
  'gh issue create -t x' 'gh release create v1' 'git push --force origin x' 'gh pr comment 5 -b x'; do
  bash_call all "$command" "$subagent"
  [ "$(verdict)" = deny ] || { bad "subagent: '$command' got $(verdict), want deny"; continue; }
  jq -r '.hookSpecificOutput.permissionDecisionReason' "$scratch/out" 2>/dev/null | grep -q 'A subagent does not' \
    || bad "subagent: the deny for '$command' does not give the subagent reason"
done
bash_call all "$(awk 'BEGIN { for (i = 0; i < 520; i++) printf "true; "; print "git push origin x" }')" "$subagent"
[ "$(verdict)" = deny ] || bad "subagent: a push past the segment cap got $(verdict), want deny"
for command in 'gh stack view --json' 'git status' 'gh pr view 5' 'git log --oneline'; do
  bash_call all "$command" "$subagent"
  [ "$(verdict)" = allow ] || bad "subagent: the read '$command' got $(verdict), want allow"
done

# Checks that session $1's MCP tool $3 with input $4 gets decision $2, with
# the JSON object $6, when given, merged into the call, and when $5 is given,
# that the reason holds it.
expect_mcp() {
  local extra="${6:-}"
  [ -n "$extra" ] || extra='{}'
  hook_run pre-tool "$(jq -cn --arg s "$1" --arg t "$3" --argjson i "$4" --argjson x "$extra" \
    '{session_id: $s, cwd: "/tmp", tool_name: $t, tool_input: $i} + $x')"
  local got
  got="$(verdict)"
  [ "$got" = "$2" ] || { bad "pre-tool: got $got, want $2, for $3 $4 in session $1"; return; }
  if [ -n "${5:-}" ]; then
    jq -r '.hookSpecificOutput.permissionDecisionReason' "$scratch/out" | grep -qF -- "$5" \
      || bad "pre-tool: the reason for $3 $4 in session $1 does not say '$5'"
  fi
}
linear_comment='mcp__1d477a67-502d-4fdf-bd14-122050c3d81e__save_comment'
for tool in mcp__github__push_files mcp__github__create_or_update_file mcp__github__reopen_issue \
  mcp__3f1c-id__push_files mcp__github__issue_write mcp__github__create_branch mcp__github__create_pull_request \
  mcp__github__merge_pull_request mcp__github__close_pull_request mcp__git__git_commit mcp__git__git_push "$linear_comment" \
  mcp__github__add_issue_comment mcp__github__update_pull_request_branch; do
  expect_mcp all deny "$tool" '{}' 'A subagent does not' "$subagent"
done
expect_mcp all allow mcp__github__get_issue '{}' '' "$subagent"
expect_mcp all allow mcp__1d477a67-502d-4fdf-bd14-122050c3d81e__list_comments '{}' '' "$subagent"
# Linear's issue writes have no mapping, so a subagent's passes.
expect_mcp all allow mcp__1d477a67-502d-4fdf-bd14-122050c3d81e__save_issue '{"team":"SKI","title":"x"}' '' "$subagent"
# A push option is not a tag or a force, and a force among short options is.
bash_call all 'git push -o tag origin main'
jq -r '.hookSpecificOutput.permissionDecisionReason' "$scratch/out" | grep -q 'push options' \
  || bad "push options: -o tag did not ask about push options"
jq -r '.hookSpecificOutput.permissionDecisionReason' "$scratch/out" | grep -q 'forces' \
  && bad "push options: -o tag was read as a tag push"
bash_call all 'git push --push-option tag origin main'
jq -r '.hookSpecificOutput.permissionDecisionReason' "$scratch/out" | grep -q 'forces' \
  && bad "push options: --push-option tag was read as a tag push"
bash_call all 'git push -fo ci.skip origin main'
jq -r '.hookSpecificOutput.permissionDecisionReason' "$scratch/out" | grep -q 'forces' \
  || bad "push options: -fo was not read as a forced push"
# A comment on a Linear issue is a post like any other, whoever asked for it.
expect_mcp all deny "$linear_comment" '{"issueId":"SKI-1","body":"Done in the PR."}' 'Posting a comment'
# With no state to read, a commit, a push or a Linear issue still gets no
# decision, as the main session's writes never do.
jq -cn '{session_id: "missing", tool_name: "Bash", tool_input: {command: "git commit -m x"}}' |
  "$hook" pre-tool > "$scratch/out" 2>/dev/null
[ "$(verdict)" = allow ] || bad "pre-tool: a commit with no state got $(verdict), want allow"
expect_bash nosuchsession allow 'git push -u origin feature/x'
expect_mcp nosuchsession allow mcp__1d477a67-502d-4fdf-bd14-122050c3d81e__save_issue '{"team":"SKI","title":"x"}'

# Input that is not JSON passes in every mode: exit 0, no output.
for m in prompt expansion pre-tool post-tool stop; do
  printf 'not json' | env CLAUDE_PLUGIN_DATA="$data" "$hook" "$m" > "$scratch/out" 2>/dev/null \
    || bad "$m: exited non-zero on malformed input"
  [ ! -s "$scratch/out" ] || bad "$m: printed output for malformed input"
done

# The guard on a code-review the model calls.
skill_call() {
  hook_run pre-tool "$(jq -cn --arg k "$1" --arg a "$2" \
    '{session_id: "review", cwd: "/tmp", tool_name: "Skill", tool_input: {skill: $k, args: $a}}')"
}
for args in 'medium --comment' 'medium --post' 'medium --comment=yes'; do
  skill_call code-review "$args"
  [ "$(verdict)" = deny ] || bad "code-review guard: '$args' was not denied"
done
skill_call code-review:code-review 'high --comment'
[ "$(verdict)" = deny ] || bad "code-review guard: a namespaced code-review was not guarded"
for args in 'ultra' 'medium --fix' 'ultra 123' 'ULTRA' 'medium --fix=true' 'medium --post=yes'; do
  skill_call code-review "$args"
  [ "$(verdict)" = deny ] || bad "code-review guard: '$args' was not denied"
done
skill_call review 'medium --comment'
[ "$(verdict)" = deny ] || bad "code-review guard: the review alias was not guarded"
skill_call code-review 'medium abc123..def456'
[ "$(verdict)" = allow ] || bad "code-review guard: a medium review was not allowed"
skill_call eng:commit ''
[ "$(verdict)" = allow ] || bad "code-review guard: another skill was not allowed"

# A typed /code-review is guarded the same way, except that ultra is yours.
expansion() {
  hook_run expansion "$(jq -cn --arg n "$1" --arg a "$2" \
    '{session_id: "typed-review", cwd: "/tmp", hook_event_name: "UserPromptExpansion", command_name: $n, command_args: $a}')"
}
expansion code-review 'medium --comment'
[ "$(jq -r '.decision // empty' "$scratch/out" 2>/dev/null)" = block ] || bad "expansion: /code-review --comment was not blocked"
expansion review '--post'
[ "$(jq -r '.decision // empty' "$scratch/out" 2>/dev/null)" = block ] || bad "expansion: /review --post was not blocked"
expansion code-review 'ultra'
[ ! -s "$scratch/out" ] || bad "expansion: a typed ultra was blocked"

# The hints are gone: a conflict in a command's output, and a message that is
# only a pull request link, add nothing.
hook_run post-tool '{"session_id": "s", "tool_name": "Bash", "tool_input": {"command": "git merge x"}, "tool_response": {"stdout": "Auto-merging a.ts\nCONFLICT (content): Merge conflict in a.ts\nAutomatic merge failed; fix conflicts and then commit the result.", "stderr": ""}}'
[ ! -s "$scratch/out" ] || bad "post-tool: a conflict in Bash output still got a hint"
hook_run prompt '{"session_id": "hints", "cwd": "/tmp", "hook_event_name": "UserPromptSubmit", "prompt": "https://github.com/o/r/pull/5"}'
[ ! -s "$scratch/out" ] || bad "prompt: a bare pull request link still got a hint"
hook_run prompt '{"session_id": "hints", "cwd": "/tmp", "hook_event_name": "UserPromptSubmit", "prompt": "https://github.com/o/r/pull/5#discussion_r123"}'
[ ! -s "$scratch/out" ] || bad "prompt: a review comment link still got a hint"

# The review reminder, in a scratch repo.
repo="$scratch/repo"
mkdir -p "$repo"
git -C "$repo" init -q
printf 'one\n' > "$repo/a.txt"
git -C "$repo" add a.txt
git -C "$repo" -c user.name=t -c user.email=t@t commit -qm init
# Session start leaves the hash to the first prompt, before any edit.
start() {
  hook_run session-start "$(jq -cn --arg s "$1" --arg d "${2:-$repo}" '{session_id: $s, cwd: $d, source: "startup"}')"
  [ ! -f "$data/sessions/$1/review-hash" ] || bad "session start: hashed the tree before the first prompt"
  hook_run prompt "$(jq -cn --arg s "$1" --arg d "${2:-$repo}" '{session_id: $s, cwd: $d, prompt: "go"}')"
  [ -f "$data/sessions/$1/review-hash" ] || bad "session start: the first prompt left no review-hash for $1"
}
stop() {
  local extra="${2:-}"
  [ -n "$extra" ] || extra='{}'
  hook_run stop "$(jq -cn --arg s "$1" --arg d "${3:-$repo}" --argjson x "$extra" \
    '{session_id: $s, cwd: $d, hook_event_name: "Stop", stop_hook_active: false, background_tasks: []} + $x')"
}
reminded() { jq -r '.hookSpecificOutput.additionalContext // empty' "$scratch/out" 2>/dev/null | grep -q 'not been reviewed'; }
# Each edit writes a new line, so every one is a tree the reminder has not
# seen.
edits=0
edit() { edits=$((edits + 1)); printf 'edit %s\n' "$edits" > "$repo/a.txt"; }
review_post() {
  local extra="${2:-}"
  [ -n "$extra" ] || extra='{}'
  hook_run post-tool "$(jq -cn --arg d "$repo" --arg a "$1" --argjson x "$extra" \
    '{session_id: "gate", cwd: $d, tool_name: "Skill", tool_input: {skill: "code-review", args: $a}} + $x')"
}
start gate
stop gate
[ ! -s "$scratch/out" ] || bad "review gate: a clean tree got a reminder"
edit
stop gate
reminded || bad "review gate: an unreviewed change got no reminder"
[ "$(jq -r '.hookSpecificOutput.hookEventName' "$scratch/out")" = Stop ] || bad "review gate: the reminder is not Stop context"
stop gate
[ ! -s "$scratch/out" ] || bad "review gate: the same tree got a second reminder"
edit
stop gate '{"stop_hook_active": true}'
[ ! -s "$scratch/out" ] || bad "review gate: acted twice in one turn"
stop gate '{"background_tasks": [{"id": "t1", "type": "subagent", "status": "running", "description": "code-review medium a..b"}]}'
[ ! -s "$scratch/out" ] || bad "review gate: acted while a code-review ran"
stop gate '{"background_tasks": [{"id": "t1", "type": "subagent", "status": "completed", "description": "/code-review medium a..b"}]}'
reminded || bad "review gate: a finished code-review task silenced it"
edit
stop gate '{"background_tasks": [{"id": "t1", "type": "shell", "status": "running", "description": "npm test"}]}'
reminded || bad "review gate: an unrelated background task silenced it"
edit
hook_run pre-tool "$(jq -cn --arg d "$repo" '{session_id: "gate", cwd: $d, tool_name: "Skill", tool_input: {skill: "code-review", args: "medium a..b"}}')"
stop gate
reminded || bad "review gate: a review that was only asked for silenced it"
# A review a subagent runs is not the main session's.
edit
review_post "medium" '{"agent_id": "a1"}'
stop gate
reminded || bad "review gate: a subagent's review silenced it"
# Any review that runs counts, whatever it was pointed at.
for args in "medium" "medium 123" "medium HEAD~0..HEAD" "medium HEAD.." "medium main..." \
  "high https://github.com/o/r/pull/12" "medium feature/x" "medium #12" "m*m" "medium --max-findings 5" ""; do
  edit
  review_post "$args"
  stop gate
  [ ! -s "$scratch/out" ] || bad "review gate: a review of '$args' did not silence it"
done
edit
stop gate
reminded || bad "review gate: a change after the review got no reminder"
# A typed review counts too, unless it was blocked.
edit
hook_run expansion "$(jq -cn --arg d "$repo" '{session_id: "gate", cwd: $d, command_name: "code-review", command_args: "medium --comment"}')"
stop gate
reminded || bad "review gate: a blocked typed review silenced it"
edit
hook_run expansion "$(jq -cn --arg d "$repo" '{session_id: "gate", cwd: $d, command_name: "code-review", command_args: "medium"}')"
stop gate
[ ! -s "$scratch/out" ] || bad "review gate: a typed review was not recorded"
# Handoffs, like plans, are not changes to review, and unusual names hash.
mkdir -p "$repo/.claude/handoffs"
printf 'h\n' > "$repo/.claude/handoffs/h.md"
stop gate
[ ! -s "$scratch/out" ] || bad "review gate: a handoff got a reminder"
rm -r "$repo/.claude"
printf 'x\n' > "$repo/caf$(printf '\303\251').txt"
stop gate
reminded || bad "review gate: a new file with an accented name got no reminder"
rm "$repo/caf$(printf '\303\251').txt"
printf 'x\n' > "$repo/a\"b.txt"
stop gate
reminded || bad "review gate: a new file with a quote in its name got no reminder"
rm "$repo/a\"b.txt"
# A link to a directory cannot be hashed, and must not hide the files after it.
mkdir -p "$repo/sub"
ln -s sub "$repo/alink"
printf 'z\n' > "$repo/zfile"
review_post "medium"
printf 'z2\n' > "$repo/zfile"
stop gate
reminded || bad "review gate: an edit after an unhashable untracked link got no reminder"
rm -r "$repo/sub" "$repo/alink" "$repo/zfile"
# Changes the session started with are not its own.
start inherited
stop inherited
[ ! -s "$scratch/out" ] || bad "review gate: changes from before the session got a reminder"
# Only plans changed, or not a repo at all.
git -C "$repo" checkout -q -- a.txt
mkdir -p "$repo/.claude/plans"
printf 'plan\n' > "$repo/.claude/plans/p.md"
start plans
printf 'plan two\n' > "$repo/.claude/plans/p.md"
stop plans
[ ! -s "$scratch/out" ] || bad "review gate: a change under .claude/plans got a reminder"
mkdir -p "$scratch/plain"
stop plain '' "$scratch/plain"
[ ! -s "$scratch/out" ] || bad "review gate: a directory outside git got a reminder"
[ "$status" -eq 0 ] || bad "review gate: exited $status outside git"

# Monitor and PowerShell commands are read like Bash ones.
for tool in Monitor PowerShell; do
  hook_run pre-tool "$(jq -cn --arg t "$tool" '{session_id: "all", cwd: "/tmp", tool_name: $t, tool_input: {command: "gh pr comment 5 -b x"}}')"
  [ "$(verdict)" = deny ] || bad "pre-tool: a post through $tool got $(verdict), want deny"
done

# A resume keeps the hash, a clear starts it again, and a session's state
# goes once it is 30 days old.
hook_run session-start "$(jq -cn --arg d "$repo" '{session_id: "gate", cwd: $d, source: "resume"}')"
[ -f "$data/sessions/gate/review-hash" ] || bad "session start: a resume dropped review-hash"
[ ! -f "$data/sessions/gate/start-pending" ] || bad "session start: a resume asked for a new hash"
hook_run session-start "$(jq -cn --arg d "$repo" '{session_id: "gate", cwd: $d, source: "clear"}')"
[ ! -f "$data/sessions/gate/review-hash" ] || bad "session start: a clear kept review-hash"
[ -f "$data/sessions/gate/start-pending" ] || bad "session start: a clear did not ask for a new hash"
# A session from before 0.16.0 keeps the hash it started with.
mkdir -p "$data/sessions/upgraded"
printf 'old\n' > "$data/sessions/upgraded/start-hash"
hook_run session-start "$(jq -cn --arg d "$repo" '{session_id: "upgraded", cwd: $d, source: "resume"}')"
[ "$(cat "$data/sessions/upgraded/review-hash" 2>/dev/null)" = old ] || bad "session start: a resume from before 0.16.0 dropped its start-hash"
[ ! -f "$data/sessions/upgraded/start-pending" ] || bad "session start: a resume from before 0.16.0 asked for a new hash"
mkdir -p "$data/sessions/stale"
touch -t 202001010000 "$data/sessions/stale"
hook_run session-start "$(jq -cn --arg d "$repo" '{session_id: "fresh", cwd: $d, source: "startup"}')"
[ ! -d "$data/sessions/stale" ] || bad "session start: a session 30 days old was kept"
[ -d "$data/sessions/gate" ] || bad "session start: a recent session was removed"


# The error log keeps its last 1000 lines once it passes 2000.
mkdir -p "$scratch/data-log"
awk 'BEGIN { for (i = 1; i <= 2100; i++) print "old " i }' > "$scratch/data-log/eng-hook.log"
env CLAUDE_PLUGIN_DATA="$scratch/data-log" "$hook" bogus < "$inputs/startup.json" > /dev/null 2>&1
lines="$(wc -l < "$scratch/data-log/eng-hook.log" | tr -d ' ')"
[ "$lines" -le 1001 ] || bad "log: the error log kept $lines lines past 2000"
tail -1 "$scratch/data-log/eng-hook.log" | grep -q 'bogus' || bad "log: trimming dropped the newest line"

# Session start sweeps up the tree hash's temp files once they are a day old.
mkdir -p "$scratch/tmp"
: > "$scratch/tmp/eng-hook-untracked.old"
touch -t 202001010000 "$scratch/tmp/eng-hook-untracked.old"
: > "$scratch/tmp/eng-hook-untracked.new"
jq -cn --arg d "$repo" '{session_id: "sweep", cwd: $d, source: "startup"}' |
  env TMPDIR="$scratch/tmp" CLAUDE_PLUGIN_DATA="$data" "$hook" session-start > /dev/null 2>&1
[ ! -f "$scratch/tmp/eng-hook-untracked.old" ] || bad "session start: a day-old temp file was kept"
[ -f "$scratch/tmp/eng-hook-untracked.new" ] || bad "session start: a new temp file was removed"
# The temp folder can be a link, as /tmp is on macOS.
ln -s "$scratch/tmp" "$scratch/tmplink"
: > "$scratch/tmp/eng-hook-untracked.old"
touch -t 202001010000 "$scratch/tmp/eng-hook-untracked.old"
jq -cn --arg d "$repo" '{session_id: "sweep2", cwd: $d, source: "startup"}' |
  env TMPDIR="$scratch/tmplink" CLAUDE_PLUGIN_DATA="$data" "$hook" session-start > /dev/null 2>&1
[ ! -f "$scratch/tmp/eng-hook-untracked.old" ] || bad "session start: a temp folder that is a link was not swept"

# Without jq the gates do nothing, exit 0, and log it.
run_nojq() {
  printf '%s' "$2" | env PATH="$nojq" CLAUDE_PLUGIN_DATA="$scratch/data-nojq-gates" "$hook" "$1" > "$scratch/out" 2>/dev/null
}
run_nojq pre-tool '{"session_id": "x", "tool_name": "Bash", "tool_input": {"command": "gh pr comment 5 -b x"}}' \
  || bad "no jq: pre-tool exited non-zero"
[ ! -s "$scratch/out" ] || bad "no jq: pre-tool printed output"
grep -q "jq not found" "$scratch/data-nojq-gates/eng-hook.log" 2>/dev/null || bad "no jq: pre-tool logged nothing"

# hooks.json runs each mode through the quoted root, as the session hook does.
# The root is matched as written, so it stays unexpanded.
# shellcheck disable=SC2016
quoted='"${CLAUDE_PLUGIN_ROOT}"/hooks/eng-hook '
for event in UserPromptSubmit UserPromptExpansion PreToolUse PostToolUse Stop; do
  command="$(jq -r --arg e "$event" '.hooks[$e][0].hooks[0].command // empty' "$plugin/hooks/hooks.json")"
  case "$command" in
    "$quoted"*) ;;
    *) bad "hooks.json: $event does not run the quoted eng-hook: $command" ;;
  esac
done
[ "$(jq -r '.hooks.PreToolUse[0].matcher' "$plugin/hooks/hooks.json")" = 'Bash|Monitor|PowerShell|Skill|mcp__.*' ] \
  || bad "hooks.json: PreToolUse does not match Bash, Monitor, PowerShell, Skill and MCP tools"
[ "$(jq -r '.hooks.PostToolUse[0].matcher' "$plugin/hooks/hooks.json")" = Skill ] \
  || bad "hooks.json: PostToolUse does not match the Skill tool alone"
jq -e '.hooks | has("PostToolUseFailure") | not' "$plugin/hooks/hooks.json" > /dev/null \
  || bad "hooks.json: PostToolUseFailure still runs the hook"

# A runner's later words are read only when they name a command in the
# classifier's known list, so every command a rule or a runner pattern names
# must be in it.
known="$(sed -nE 's/^  (wrappers|shells|known) = [a-z ]*"(.*)"$/\2/p' "$plugin/hooks/classify-command.awk" | tr '\n' ' ')"
[ -n "$known" ] || bad "classify-command.awk: no known list to check"
while IFS= read -r name; do
  case " $known " in *" $name "*) ;; *) bad "classify-command.awk: $name has a rule but is not in known" ;; esac
done < <(
  {
    grep -o 'cmd == "[a-z0-9._-]*"' "$plugin/hooks/classify-command.awk" | sed 's/^cmd == "//; s/"$//'
    # The runners, named in the runner patterns as cmd ~ /^(a|b)$/. This
    # comment holds no apostrophe, which bash 3.2 cannot parse inside <( ).
    grep -oE 'cmd ~ /\^\([a-z0-9|?-]*\)\$/' "$plugin/hooks/classify-command.awk" |
      sed -E 's/^cmd ~ \/\^\(//; s/\)\$\/$//; s/4\?//' | tr '|' '\n'
  } | sort -u
)

[ "$fail" -eq 0 ] && printf 'hooks: ok\n'
exit "$fail"
