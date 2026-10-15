#!/usr/bin/env bash
# Runs hooks/eng-hook against the inputs in tests/hooks and checks what comes
# out: the session block, then the gates, which read the cases in
# tests/hooks/pre-tool and a scratch repo for the review gate. The checks read
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
[ "$status" -eq 0 ] || bad "spaced root: exited $status"
check_block "spaced root" "$(jq -r '.hookSpecificOutput.additionalContext' "$scratch/out" 2>/dev/null)"
# The command line hooks.json gives Claude Code, run through sh as a hook runs,
# with the root left for the shell to expand and with it written in place. A
# lost quote around the root splits the path at the space.
mkdir -p "$spaced/hooks"
cp "$hook" "$spaced/hooks/"
command="$(jq -r '.hooks.SessionStart[0].hooks[0].command' hooks/hooks.json)"
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

# The gates. Each session below has its own state under $data, which the hook
# reads from ${CLAUDE_PLUGIN_DATA}/sessions/<session>/.
data="$scratch/data-gates"

# Sets session $1's latest message to $2 and its loaded skills to the rest.
set_state() {
  local dir="$data/sessions/$1"
  mkdir -p "$dir"
  printf '%s\n' "$2" > "$dir/turn"
  shift 2
  : > "$dir/skills"
  local skill
  for skill in "$@"; do printf '%s\n' "$skill" >> "$dir/skills"; done
}

# Runs mode $1 with the JSON $2 on stdin. The output goes to $scratch/out.
hook_run() {
  printf '%s' "$2" | env CLAUDE_PLUGIN_DATA="$data" "$hook" "$1" > "$scratch/out" 2> "$scratch/err"
  status=$?
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

# Every skill loaded and every write asked for, so the command cases read what
# the post guard and the confirmation prompt decide.
set_state all "commit, push, open the PR and file the issue" commit pr issue

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

# mcp.cases: one "<expect> <tool name>" per line.
count=0
while IFS=' ' read -r expect tool; do
  case "$expect" in deny | ask | allow) ;; *) continue ;; esac
  hook_run pre-tool "$(jq -cn --arg t "$tool" '{session_id: "all", cwd: "/tmp", tool_name: $t, tool_input: {}}')"
  got="$(verdict)"
  [ "$got" = "$expect" ] || bad "pre-tool: got $got, want $expect, for $tool"
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

# The write gate. A subagent is denied whatever the state.
bash_call all 'git commit -m x' '{"agent_id": "a1", "agent_type": "general-purpose"}'
[ "$(verdict)" = deny ] || bad "write gate: a subagent's commit was not denied"
bash_call all 'gh pr comment 5 -b x' '{"agent_id": "a1"}'
jq -r '.hookSpecificOutput.permissionDecisionReason' "$scratch/out" 2>/dev/null | grep -q 'draft' \
  || bad "write gate: a subagent's post was not denied as a post"
# Skill not loaded since the latest message: deny, naming the skill.
set_state none "commit this"
expect_bash none deny 'git commit -m x' 'eng:commit'
expect_bash none deny 'git push origin feature/x' 'eng:pr'
expect_bash none deny 'git subtree push --prefix dist origin gh-pages' 'eng:commit'
expect_bash none deny 'gh pr create --title x --body-file b.md' 'eng:pr'
expect_bash none deny 'gh issue create --title x --body-file b.md' 'eng:issue'
expect_bash none deny 'gh pr create --web' 'eng:pr'
expect_bash none allow 'git commit -e --dry-run'
expect_bash none deny 'git commit -am -h' 'eng:commit'
expect_bash none deny 'git commit -am --help' 'eng:commit'
expect_bash none deny 'git push -onotify origin x' 'eng:'
# Your latest message. A write runs unless that message says not to, so these
# all pass, including messages from real sessions that once asked.
said_allows() { # message, skills, then command pairs: verdict command
  local msg="$1" skills="$2"; shift 2
  # shellcheck disable=SC2086
  set_state said "$msg" $skills
  while [ "$#" -gt 1 ]; do
    expect_bash said "$1" "$2"
    case "$1" in deny) jq -r '.hookSpecificOutput.permissionDecisionReason' "$scratch/out" | grep -q 'says not to' \
      || bad "write gate: the deny for '$2' after '$msg' does not say the message said not to" ;; esac
    shift 2
  done
}
said_allows "commit this" commit allow 'git commit -m x'
said_allows "tidy up the parser" "commit pr issue" allow 'git commit -m x' allow 'gh pr edit 5 --body-file b.md' allow 'gh label create bug'
said_allows "Let's review this PR. If anything needs fixing, we'll keep reviewing and fixing until everything is resolved. Then you have my permission to commit, push, and update the PR. After the update, run another code review." "commit pr" \
  allow 'git commit -m x' allow 'git push origin x' allow 'gh pr edit 5 --body-file b.md'
said_allows "This PR has conflicts; please resolve them." commit allow 'git commit --no-edit'
said_allows "Create a dummy env file and retry." commit allow 'git commit -m x'
said_allows "If everything looks good, commit, open a PR, and run a review on the new PR." "commit pr" allow 'git commit -m x' allow 'gh pr create -t x'
said_allows "rename the branch and open a PR" pr allow 'git push -u origin feature/x' allow 'gh pr create -t x'
said_allows "Can you commit this?" commit allow 'git commit -m x'
said_allows "commit and push when you're done" "commit pr" allow 'git commit -m x' allow 'git push origin x'
said_allows "Don't forget to push" commit allow 'git push origin x'
said_allows "commit this, but don't commit the .env file" commit allow 'git commit -m x'
said_allows "push it, but don't push to main" commit allow 'git push origin x'
said_allows "the PR is not merged, push the fix" commit allow 'git push origin x'
said_allows "commit, and don't touch the tests" commit allow 'git commit -m x'
said_allows "commit. Don't touch the tests" commit allow 'git commit -m x'
said_allows "Don't stage the lockfile, commit the rest" commit allow 'git commit -m x'
said_allows "Don't commit yet. Actually, go ahead and commit" commit allow 'git commit -m x'
said_allows "don't push. Actually, push it" commit allow 'git push origin x'
said_allows "skip the flaky test, then push" commit allow 'git push origin x'
said_allows "drop the debug log and push" commit allow 'git push origin x'
said_allows "commit and push. No rush" commit allow 'git push origin x'
said_allows "no issues found, commit it" "commit issue" allow 'git commit -m x' allow 'gh issue close 3'
said_allows "don't merge the PR, just update its description" pr allow 'gh pr edit 5 --body-file b.md'
said_allows "I'll review it, then push" commit allow 'git push origin x'
# Said not to: deny, naming that the message said so.
said_allows "don't commit" commit deny 'git commit -m x'
said_allows "Don't commit yet" commit deny 'git commit -m x'
said_allows "please do not commit or push" commit deny 'git commit -m x' deny 'git push origin x'
said_allows "Don't stage, commit, or push anything" commit deny 'git commit -m x' deny 'git push origin x'
said_allows "commit, but don't push" commit allow 'git commit -m x' deny 'git push origin x'
said_allows "Don't push yet, just commit" commit allow 'git commit -m x' deny 'git push origin x'
said_allows "commit and push. Actually, don't push" commit allow 'git commit -m x' deny 'git push origin x'
said_allows "commit it, push it later" commit allow 'git commit -m x' deny 'git push origin x'
said_allows "commit it, I'll push it myself" commit allow 'git commit -m x' deny 'git push origin x'
said_allows "commit, and leave the push to me" commit allow 'git commit -m x' deny 'git push origin x'
said_allows "just commit, hold off on pushing" commit allow 'git commit -m x' deny 'git push origin x'
said_allows "commit without pushing" commit allow 'git commit -m x' deny 'git push origin x'
said_allows "No need to commit, just push" commit deny 'git commit -m x' allow 'git push origin x'
said_allows "commit and push, no PR" "commit pr" allow 'git push origin x' deny 'gh pr create -t x'
said_allows "don't open a PR yet" pr deny 'gh pr create -t x'
said_allows "commit and push. Never mind the push" commit allow 'git commit -m x' deny 'git push origin x'
said_allows "commit, push, and open a PR. Scratch the PR" "commit pr" allow 'git push origin x' deny 'gh pr create -t x'
said_allows "don't close the issue" issue deny 'gh issue close 3'
said_allows "open the MR, don't push" pr allow 'glab mr create -tfix' deny 'glab mr create --fill' deny 'glab mr create -fy'
said_allows "open a PR, but don't push" pr deny 'git push origin x' deny 'gh pr create --web'
# A refusal earlier in the message stands when a later sentence does not name
# the write again.
said_allows "Don't push. Actually the CI is green, so commit." commit allow 'git commit -m x' deny 'git push origin x'
said_allows "Commit but don't push. Actually, also update the README first." commit allow 'git commit -m x' deny 'git push origin x'
# More ways to refuse, and ways that are not refusals.
said_allows "Don't ever push" commit deny 'git push origin x'
said_allows "Do not push under any circumstances" commit deny 'git push origin x'
said_allows "I don't want you to push" commit deny 'git push origin x'
said_allows "don't run git push" commit deny 'git push origin x'
said_allows "Don't push your changes" commit deny 'git push origin x'
said_allows "don't push before I review" commit deny 'git push origin x'
said_allows "Hold the push" commit deny 'git push origin x'
said_allows "Leave that, commit and push." commit allow 'git commit -m x' allow 'git push origin x'
said_allows "Leave it and push" commit allow 'git push origin x'
said_allows "Why is it not pushing? Push again." commit allow 'git push origin x'
said_allows "Can't push? Try again." commit allow 'git push origin x'
said_allows "no, go ahead and push" commit allow 'git push origin x'
said_allows "I didn't push it, can you push" commit allow 'git push origin x'
said_allows "I haven't committed; commit it" commit allow 'git commit -m x'
said_allows "Don't push. Actually, commit it." commit allow 'git commit -m x' deny 'git push origin x'
said_allows "Don't commit or push. The bug is actually in the parser, fix it" commit deny 'git commit -m x' deny 'git push origin x'
said_allows "don't push, I actually want to review it first" commit deny 'git push origin x'
said_allows "I'm not ready to push yet" commit deny 'git push origin x'
said_allows "push once I approve" commit deny 'git push origin x'
said_allows "wait before pushing" commit deny 'git push origin x'
said_allows "open a PR, but don't you dare push" pr deny 'git push origin x'
said_allows "I'll open the PR myself, just push" "commit pr" deny 'gh pr create -t x' allow 'git push origin x'
said_allows "no PR needed" pr deny 'gh pr create -t x'
said_allows "Don't commit your changes" commit deny 'git commit -m x'
said_allows "wait for CI, then push" commit allow 'git push origin x'
said_allows "don't push. Wait for CI, then commit" commit deny 'git push origin x' allow 'git commit -m x'
said_allows "commit, push and wait." commit allow 'git commit -m x' allow 'git push origin x'
said_allows "I want you to push" commit allow 'git push origin x'
said_allows "I want to commit and push" commit allow 'git commit -m x' allow 'git push origin x'
said_allows "I meant push" commit allow 'git push origin x'
said_allows "commit and push; wait" commit allow 'git push origin x'
said_allows "no you need to push" commit allow 'git push origin x'
said_allows "no, I want you to commit" commit allow 'git commit -m x'
said_allows "push, then let me know what failed first" commit allow 'git push origin x'
said_allows "don't push the commit" commit allow 'git commit -m x' deny 'git push origin x'
said_allows "Don't push yet, okay?" commit deny 'git push origin x'
said_allows "Don't push - CI is broken" commit deny 'git push origin x'
said_allows "Don't push, why did CI fail?" commit deny 'git push origin x'
said_allows "Don't push yet. I'll tell you when to push." commit deny 'git push origin x'
said_allows "No need for an issue" issue deny 'gh issue create -t x -F b.md'
said_allows "refrain from pushing" commit deny 'git push origin x'
said_allows "I'll handle the push" commit deny 'git push origin x'
# Asks with a negation or a question in them, and more plain refusals.
said_allows "Why don't you commit and push, then?" commit allow 'git commit -m x' allow 'git push origin x'
said_allows "Why not push it, then?" commit allow 'git push origin x'
said_allows "Commit this, but don't push --force" commit allow 'git push origin x'
said_allows "Don't ask, push" commit allow 'git push origin x'
said_allows "don't do anything else, push" commit allow 'git push origin x'
said_allows "There's no PR yet, open one" pr allow 'gh pr create -t x'
said_allows "Push it and wait, just in case CI is slow" commit allow 'git push origin x'
said_allows "Don't create or update the PR" pr deny 'gh pr create -t x'
said_allows "commit and push, then let me see the first CI run" commit allow 'git push origin x'
said_allows "We shouldnt push yet" commit deny 'git push origin x'
said_allows "I wont push it" commit deny 'git push origin x'
said_allows "Do not touch the PR" pr deny 'gh pr edit 5 --body-file b.md'
said_allows "Can you push this?" commit allow 'git push origin x'
said_allows "commit and push, no rush" commit allow 'git push origin x'
# Round 4 of the review: asks that once read as refusals, and plain no's.
said_allows "don't change anything and push" commit allow 'git push origin x'
said_allows "don't touch it and commit it" commit allow 'git commit -m x'
said_allows "don't ask and push" commit allow 'git push origin x'
said_allows "it didn't push, push again" commit allow 'git push origin x'
said_allows "You didn't push - push now" commit allow 'git push origin x'
said_allows "Not committed yet - commit it" commit allow 'git commit -m x'
said_allows "$(printf 'It is not pushed \342\200\224 push it')" commit allow 'git push origin x'
said_allows "the hook won't let me push, you push" commit allow 'git push origin x'
said_allows "there's no need to push" commit deny 'git push origin x'
said_allows "commit with no push" commit allow 'git commit -m x' deny 'git push origin x'
said_allows "don't push till CI passes" commit deny 'git push origin x'
said_allows "don't update the PR description" pr allow 'gh pr edit 5 --body-file b.md'
said_allows "skip the PR and push" "commit pr" allow 'git push origin x' deny 'gh pr create -t x'
said_allows "drop the commit and push" commit allow 'git push origin x'
said_allows "no PR, push it" "commit pr" allow 'git push origin x' deny 'gh pr create -t x'
said_allows "don't update the pr, push" "commit pr" allow 'git push origin x'
said_allows "without committing, push" commit allow 'git push origin x' deny 'git commit -m x'
said_allows "don't push. push it later" commit deny 'git push origin x'
said_allows "Don't push, push later" commit deny 'git push origin x'
said_allows "I don't want a PR" pr deny 'gh pr create -t x'
said_allows "Make sure not to push" commit deny 'git push origin x'
said_allows "do not create a PR for this" pr deny 'gh pr create -t x'
said_allows "don't push for now" commit deny 'git push origin x'
said_allows "commit it. staging is down, so don't use staging" commit allow 'git commit -m x'
said_allows "don't push these changes" commit deny 'git push origin x'
# A fact about a write is not a no, and an ask after one counts.
said_allows "The branch wasn't pushed, I need you to push it" commit allow 'git push origin x'
said_allows "It's not pushed. I want you to push it." commit allow 'git push origin x'
said_allows "it didn't push, retry the push" commit allow 'git push origin x'
said_allows "We never pushed this, please go ahead" commit allow 'git push origin x'
said_allows "I can't push, you push it" commit allow 'git push origin x'
said_allows "I didn't push it, can you push?" commit allow 'git push origin x'
said_allows "Push it if it's not pushed" commit allow 'git push origin x'
said_allows "commit whatever isn't committed yet" commit allow 'git commit -m x'
said_allows "We have no PR yet, open one" pr allow 'gh pr create -t x'
said_allows "Don't edit the PR title, update the PR description" pr allow 'gh pr edit 5 --body-file b.md'
said_allows "Scrap this PR and open a new PR" pr allow 'gh pr create -t x'
said_allows "Commit this; I don't need a PR yet" "commit pr" allow 'git commit -m x' deny 'gh pr create -t x'
said_allows "Push it, but I'll do the PR" "commit pr" allow 'git push origin x' deny 'gh pr create -t x'
said_allows "Don't file an issue for this" issue deny 'gh issue create -t x -F b.md'
said_allows "We won't push today" commit deny 'git push origin x'
said_allows "Don't open a PR; Sam will open the PR" pr deny 'gh pr create -t x'
said_allows "Don't push; CI will retry the push" commit deny 'git push origin x'
said_allows "don't push - every time you push CI breaks" commit deny 'git push origin x'
said_allows "don't commit and push" commit deny 'git commit -m x' deny 'git push origin x'
said_allows "you can't push this" commit deny 'git push origin x'
said_allows "still no push, please" commit deny 'git push origin x'
said_allows "it won't commit. fix the hook and commit" commit allow 'git commit -m x'
said_allows "it did not push" commit allow 'git push origin x'
said_allows "why don't you push it then" commit allow 'git push origin x'
said_allows "I'll leave it to you to push" commit allow 'git push origin x'
said_allows "whether or not you push it today, commit first. Actually push it too" commit allow 'git push origin x'
said_allows "I'll need you to push this" commit allow 'git push origin x'
said_allows "I'll want you to push it after the commit" commit allow 'git push origin x'
said_allows "it won't push, can you retry" commit allow 'git push origin x'
said_allows "it's not pushing, try again" commit allow 'git push origin x'
said_allows "Don't push yet. OK, now try to push" commit allow 'git push origin x'
said_allows "don't forget the PR" pr allow 'gh pr create -t x'
said_allows "you can't push this yet" commit deny 'git push origin x'
said_allows "this is not ready to commit" commit deny 'git commit -m x'
said_allows "this won't need a PR" pr deny 'gh pr create -t x'
said_allows "Commit the parser fix, don't stage anything else" commit allow 'git commit -m x'
said_allows "no PR and push it" "commit pr" allow 'git push origin x'
said_allows "commit without staging and push" commit allow 'git push origin x'
said_allows "Push it, and if you can't push, tell me why" commit allow 'git push origin x'
said_allows "Don't open a PR. Later open the PR" pr allow 'gh pr create -t x'
said_allows "ok, why not push it" commit allow 'git push origin x'
said_allows "Still no PR, open it" pr allow 'gh pr create -t x'
said_allows "Don't push yet. OK, go push" commit allow 'git push origin x'
said_allows "Don't push. Actually let's push" commit allow 'git push origin x'
said_allows "don't push until CI passes. It passed, you should push now" commit allow 'git push origin x'
said_allows "No PR yet - open one" pr allow 'gh pr create -t x'
said_allows "no issue yet; file it" issue allow 'gh issue create -t x -F b.md'
said_allows "Don't open a new PR, update the existing PR" pr allow 'gh pr edit 5 --body-file b.md'
said_allows "leave the PR alone" pr deny 'gh pr edit 5 --body-file b.md'
said_allows "it did not even push, try again" commit allow 'git push origin x'
said_allows "Don't open a PR. The PR template is broken." pr deny 'gh pr create -t x'
said_allows "Don't file an issue. I already filed the issue." issue deny 'gh issue create -t x -F b.md'
said_allows "Don't push yet. The branch protection blocks pushes." commit deny 'git push origin x'
said_allows "Thanks. Don't open the PR, the PR title is wrong" pr deny 'gh pr create -t x'
said_allows "Don't open a PR. I'll tell you when to open the PR" pr deny 'gh pr create -t x'
said_allows "you can't commit and push yet" commit deny 'git push origin x'
said_allows "don't push until I say you should push" commit deny 'git push origin x'
said_allows "No PR, never open one" pr deny 'gh pr create -t x'
said_allows "Don't push now; later pushes will handle it" commit deny 'git push origin x'
said_allows "No PR yet. Let's open one" pr allow 'gh pr create -t x'
said_allows "no issue yet for this, file one" issue allow 'gh issue create -t x -F b.md'
said_allows "Don't open the PR. I want to review the PR first." pr deny 'gh pr create -t x'
said_allows "Don't push. We push on Fridays." commit deny 'git push origin x'
said_allows "don't push. I push after review." commit deny 'git push origin x'
said_allows "Don't push. The push hook is broken." commit deny 'git push origin x'
said_allows "don't push yet. ok we can push now" commit allow 'git push origin x'
said_allows "don't push yet! jk push it" commit allow 'git push origin x'
said_allows "Don't push. Wait, actually push" commit allow 'git push origin x'
said_allows "don't push. on second thought push it" commit allow 'git push origin x'
said_allows "don't commit. Ok actually commit" commit allow 'git commit -m x'
said_allows "don't push. I want to push it myself" commit deny 'git push origin x'
# A takeback, a wait or a condition is left to the skills, which read meaning:
# the hook lets these run, and eng:commit and eng:pr hold back what was taken
# back.
said_allows "commit and push. Scratch that" commit allow 'git commit -m x' allow 'git push origin x'
said_allows "commit and push. Actually, just commit" commit allow 'git commit -m x' allow 'git push origin x'
said_allows "commit and push. Never mind, just commit" commit allow 'git commit -m x' allow 'git push origin x'
said_allows "commit and push, no wait, just commit" commit allow 'git commit -m x' allow 'git push origin x'
said_allows "commit and push. Wait, only commit" commit allow 'git commit -m x' allow 'git push origin x'
said_allows "commit and push. Actually, don't" commit allow 'git commit -m x' allow 'git push origin x'
said_allows "commit and push, but let me review first" commit allow 'git push origin x'
said_allows "commit and push. Not yet" commit allow 'git push origin x'
said_allows "push it, but not until CI passes" commit allow 'git push origin x'
said_allows "commit and push. Wait, don't" commit allow 'git push origin x' allow 'git commit -m x'
said_allows "Commit and push. Actually, hold off." commit allow 'git push origin x'
said_allows "Commit and push. Never mind, I'll do it myself." commit allow 'git push origin x'
said_allows "Commit and push. Hold on." commit allow 'git push origin x'
said_allows "Commit and push, but let me take a look first" commit allow 'git push origin x'
said_allows "commit and push, but let me look at the diff, first" commit allow 'git push origin x'
said_allows "Commit and push. Wait." commit allow 'git push origin x'
said_allows "Push it. Hmm, wait." commit allow 'git push origin x'
said_allows "Wait for CI before you push" commit allow 'git push origin x'
said_allows "Wait until I review before pushing" commit allow 'git push origin x'
said_allows "Push? No, just commit." commit allow 'git push origin x' allow 'git commit -m x'
said_allows "Could you not push yet?" commit allow 'git push origin x'
said_allows "Can you hold off on the push?" commit allow 'git push origin x'
set_state all "commit, push, open the PR and file the issue" commit pr issue
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
expect_bash none allow 'git commit -h'
expect_bash none deny 'gh pr new --title x' 'eng:pr'
expect_bash none deny 'gh issue new --title x' 'eng:issue'
expect_bash none deny 'gt submit' 'eng:'
hook_run pre-tool '{"session_id": "none", "tool_name": "mcp__github__create_issue", "tool_input": {}}'
[ "$(verdict)" = deny ] || bad "write gate: a GitHub MCP issue write without eng:issue was not denied"
expect_bash none deny 'glab mr create --fill --push' 'eng:'
expect_bash none deny 'glab label create bug' 'eng:issue'
expect_bash none deny 'glab -R a/b mr create --fill' 'eng:pr'
expect_bash none deny 'glab -Ra/b mr create' 'eng:pr'
expect_bash none deny 'glab mr -R a/b create --fill' 'eng:pr'
expect_bash none deny 'glab --repo=a/b mr create' 'eng:pr'
expect_bash none deny 'glab mr create --fill' 'eng:pr'
set_state pushed "open a PR for this" pr
expect_bash pushed allow 'git push -u origin feature/x'
expect_bash pushed allow 'gh pr create --title x --body-file b.md'
# A push the gate allows still asks when it forces.
expect_bash pushed ask 'git push --force-with-lease origin feature/x' 'forces'
# A typed /eng:commit is both the skill and the request.
set_state typed "/eng:commit" commit
expect_bash typed allow 'git commit -m x'
# No state to read: the gate fails open, like the rest of the hook.
jq -cn '{session_id: "missing", tool_name: "Bash", tool_input: {command: "git commit -m x"}}' |
  "$hook" pre-tool > "$scratch/out" 2>/dev/null
[ "$(verdict)" = allow ] || bad "write gate: a commit with no state was not allowed"
bash_call nosuchsession 'git commit -m x'
[ "$(verdict)" = allow ] || bad "write gate: a commit in a session with no message was not allowed"
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
# A typed skill is recorded.
set_state typed-skill "do it"
hook_run expansion '{"session_id": "typed-skill", "command_name": "eng:pr", "command_args": ""}'
grep -qx pr "$data/sessions/typed-skill/skills" || bad "expansion: a typed eng:pr was not recorded"

# A skill that loads is recorded, under its name without eng:.
set_state loads "commit it"
hook_run post-tool '{"session_id": "loads", "tool_name": "Skill", "tool_input": {"skill": "eng:commit"}}'
grep -qx commit "$data/sessions/loads/skills" || bad "post-tool: a loaded eng:commit was not recorded"
expect_bash loads allow 'git commit -m x'

# A skill a subagent loads does not open the main session's gate.
set_state subskill "commit it"
hook_run post-tool '{"session_id": "subskill", "agent_id": "a1", "tool_name": "Skill", "tool_input": {"skill": "eng:commit"}}'
expect_bash subskill deny 'git commit -m x' 'eng:commit'
for tool in mcp__github__push_files mcp__github__create_or_update_file mcp__github__reopen_issue mcp__3f1c-id__push_files mcp__github__issue_write mcp__github__create_branch mcp__git__git_commit mcp__git__git_push; do
  hook_run pre-tool "$(jq -cn --arg t "$tool" '{session_id: "none", tool_name: $t, tool_input: {}}')"
  [ "$(verdict)" = deny ] || bad "write gate: $tool without its skill loaded was not denied"
done

# The conflict hint.
hook_run post-tool '{"session_id": "s", "tool_name": "Bash", "tool_input": {"command": "git merge x"}, "tool_response": {"stdout": "Auto-merging a.ts\nCONFLICT (content): Merge conflict in a.ts\nAutomatic merge failed; fix conflicts and then commit the result.", "stderr": ""}}'
jq -r '.hookSpecificOutput.additionalContext' "$scratch/out" 2>/dev/null | grep -q 'eng:merge-conflicts' \
  || bad "post-tool: a conflict got no hint"
hook_run post-tool '{"session_id": "s", "hook_event_name": "PostToolUseFailure", "tool_name": "Bash", "tool_input": {"command": "git merge x"}, "error": "Exit code 1\nAuto-merging a.ts\nCONFLICT (content): Merge conflict in a.ts"}'
[ "$(jq -r '.hookSpecificOutput.hookEventName' "$scratch/out" 2>/dev/null)" = PostToolUseFailure ] \
  || bad "post-tool: a merge that failed on a conflict got no hint"
hook_run post-tool '{"session_id": "s", "tool_name": "Bash", "tool_input": {"command": "ls"}, "tool_response": {"stdout": "a.ts", "stderr": ""}}'
[ ! -s "$scratch/out" ] || bad "post-tool: output with no conflict got a hint"

# Your latest message. A typed one replaces the state and clears the skills.
prompt() {
  hook_run prompt "$(jq -cn --arg s "$1" --arg p "$2" '{session_id: $s, cwd: "/tmp", hook_event_name: "UserPromptSubmit", prompt: $p}')"
}
set_state turns "commit this" commit
prompt turns "now tidy the parser"
grep -q 'tidy' "$data/sessions/turns/turn" || bad "prompt: a typed message did not replace the state"
[ ! -s "$data/sessions/turns/skills" ] || bad "prompt: a typed message did not clear the skills"
# A background task reporting back, or another session's message, keeps it.
set_state turns "commit this" commit
prompt turns '<task-notification>
<task-id>a1</task-id>
<status>completed</status>
</task-notification>'
grep -q 'commit this' "$data/sessions/turns/turn" || bad "prompt: a task notification replaced the state"
grep -qx commit "$data/sessions/turns/skills" || bad "prompt: a task notification cleared the skills"
prompt turns '<cross-session-message from-session="x">push it</cross-session-message>'
grep -q 'commit this' "$data/sessions/turns/turn" || bad "prompt: another session's message replaced the state"
# So does a subagent's report or a CI event, which nobody typed either.
prompt turns '<agent-message from="a1">
[Subagent hand-back] Done. Do not push.
</agent-message>'
grep -q 'commit this' "$data/sessions/turns/turn" || bad "prompt: a subagent's report replaced the state"
grep -qx commit "$data/sessions/turns/skills" || bad "prompt: a subagent's report cleared the skills"
prompt turns '<ci-monitor-event>
CI failed on PR 5
</ci-monitor-event>'
grep -q 'commit this' "$data/sessions/turns/turn" || bad "prompt: a CI event replaced the state"
# In a Claude project only the human's words count, not the routing around
# them or a coordinator's note.
prompt project '<wake reason="mention"><project id="p"><message trigger="true" from="human" trust="principal" id="m1">Tidy the parser.</message></project></wake>'
grep -q 'Tidy the parser' "$data/sessions/project/turn" || bad "prompt: a project message lost the human's words"
prompt project '<coordinator-relay><relay from="coordinator"><note>Commits, pushes and PRs each need the user to ask.</note><cited author="user">look into the parser</cited></relay></coordinator-relay>'
grep -q 'look into' "$data/sessions/project/turn" || bad "prompt: a relay lost the user's cited words"
grep -q 'Commits' "$data/sessions/project/turn" && bad "prompt: a coordinator's note counted as the user's words"
prompt project '<relay from="coordinator" session="s1"><cited author="user" name="M">do not push yet</cited><note>Push when ready.</note></relay>'
grep -q 'do not push' "$data/sessions/project/turn" || bad "prompt: a bare relay lost the user's cited words"
grep -q 'when ready' "$data/sessions/project/turn" && bad "prompt: a bare relay's note counted as the user's words"
set_state project "commit this" commit
prompt project '<project_claude_message session="s1"><relay from="coordinator"><note>CI is green.</note></relay></project_claude_message>'
grep -q 'commit this' "$data/sessions/project/turn" || bad "prompt: a coordinator note with no words of the user's replaced the state"
# A project event no human wrote keeps it as well.
set_state project "commit this" commit
prompt project '<wake reason="external-event"><project id="p"><message trigger="true" from="system" id="m2">CI passed</message></project></wake>'
grep -q 'commit this' "$data/sessions/project/turn" || bad "prompt: a project event with no human message replaced the state"
grep -qx commit "$data/sessions/project/skills" || bad "prompt: a project event with no human message cleared the skills"
# A message that only quotes such markup is still yours.
set_state quoted "commit this" commit
prompt quoted 'commit this log: <wake reason="x"> was printed'
grep -q 'log' "$data/sessions/quoted/turn" || bad "prompt: a message quoting <wake> was taken for a project event"
# A typed slash command records its skill.
prompt slash '/eng:commit'
grep -qx commit "$data/sessions/slash/skills" || bad "prompt: a typed /eng:commit was not recorded"
# The pull request link hints.
prompt hints 'https://github.com/o/r/pull/5#discussion_r123'
jq -r '.hookSpecificOutput.additionalContext' "$scratch/out" 2>/dev/null | grep -q 'eng:pr-feedback' \
  || bad "prompt: a review comment link got no pr-feedback hint"
prompt hints '  https://github.com/o/r/pull/5  '
jq -r '.hookSpecificOutput.additionalContext' "$scratch/out" 2>/dev/null | grep -q 'Ask what to do' \
  || bad "prompt: a bare pull request link got no hint"
prompt hints 'Review https://github.com/o/r/pull/5 for bugs'
[ ! -s "$scratch/out" ] || bad "prompt: a pull request link with a request got a hint"

# The review gate, in a scratch repo.
repo="$scratch/repo"
mkdir -p "$repo"
git -C "$repo" init -q
printf 'one\n' > "$repo/a.txt"
git -C "$repo" add a.txt
git -C "$repo" -c user.name=t -c user.email=t@t commit -qm init
# Session start leaves the hash to the first prompt, before any edit.
start() {
  hook_run session-start "$(jq -cn --arg s "$1" --arg d "${2:-$repo}" '{session_id: $s, cwd: $d, source: "startup"}')"
  [ ! -f "$data/sessions/$1/start-hash" ] || bad "session start: hashed the tree before the first prompt"
  hook_run prompt "$(jq -cn --arg s "$1" --arg d "${2:-$repo}" '{session_id: $s, cwd: $d, prompt: "go"}')"
  [ -f "$data/sessions/$1/start-hash" ] || bad "session start: the first prompt left no start-hash for $1"
}
stop() {
  local extra="${2:-}"
  [ -n "$extra" ] || extra='{}'
  hook_run stop "$(jq -cn --arg s "$1" --arg d "${3:-$repo}" --argjson x "$extra" \
    '{session_id: $s, cwd: $d, hook_event_name: "Stop", stop_hook_active: false, background_tasks: []} + $x')"
}
reminded() { jq -r '.hookSpecificOutput.additionalContext // empty' "$scratch/out" 2>/dev/null | grep -q 'not been reviewed'; }
start gate
stop gate
[ ! -s "$scratch/out" ] || bad "review gate: a clean tree got a reminder"
printf 'two\n' > "$repo/a.txt"
stop gate
reminded || bad "review gate: an unreviewed change got no reminder"
[ "$(jq -r '.hookSpecificOutput.hookEventName' "$scratch/out")" = Stop ] || bad "review gate: the reminder is not Stop context"
stop gate '{"stop_hook_active": true}'
[ ! -s "$scratch/out" ] || bad "review gate: acted twice in one turn"
stop gate '{"background_tasks": [{"id": "t1", "type": "subagent", "status": "running", "description": "code-review medium a..b"}]}'
[ ! -s "$scratch/out" ] || bad "review gate: acted while a code-review ran"
stop gate '{"background_tasks": [{"id": "t1", "type": "subagent", "status": "completed", "description": "/code-review medium a..b"}]}'
reminded || bad "review gate: a finished code-review task silenced it"
stop gate '{"background_tasks": [{"id": "t1", "type": "shell", "status": "running", "description": "npm test"}]}'
reminded || bad "review gate: an unrelated background task silenced it"
hook_run pre-tool "$(jq -cn --arg d "$repo" '{session_id: "gate", cwd: $d, tool_name: "Skill", tool_input: {skill: "code-review", args: "medium a..b"}}')"
stop gate
reminded || bad "review gate: a review that was only asked for silenced it"
review_post() {
  hook_run post-tool "$(jq -cn --arg d "$repo" --arg a "$1" '{session_id: "gate", cwd: $d, tool_name: "Skill", tool_input: {skill: "code-review", args: $a}}')"
}
review_post "medium 123"
stop gate
reminded || bad "review gate: a review of a pull request silenced it"
review_post "medium HEAD~0..HEAD"
stop gate
reminded || bad "review gate: a review of another range silenced it"
for open_range in "medium HEAD.." "medium main..." "medium HEAD~0.."; do
  review_post "$open_range"
  stop gate
  reminded || bad "review gate: a review of '$open_range', which stops at HEAD, silenced it"
done
for target in "high https://github.com/o/r/pull/12" "medium feature/x" "medium #12"; do
  review_post "$target"
  stop gate
  reminded || bad "review gate: a review of '$target' silenced it"
done
GIT_INDEX_FILE="$scratch/snap-index" git -C "$repo" read-tree HEAD
GIT_INDEX_FILE="$scratch/snap-index" git -C "$repo" add -A
snap="$(git -C "$repo" -c user.name=t -c user.email=t@t commit-tree "$(GIT_INDEX_FILE="$scratch/snap-index" git -C "$repo" write-tree)" -p HEAD -m review)"
review_post "medium HEAD..$snap"
stop gate
[ ! -s "$scratch/out" ] || bad "review gate: a review of a snapshot of this tree got a reminder"
printf 'three\n' > "$repo/a.txt"
stop gate
reminded || bad "review gate: a change after the review got no reminder"
# A file the snapshot cannot read fails it, so no review of any range counts.
if [ "$(id -u)" != 0 ]; then
  printf 'u\n' > "$repo/unreadable.txt"
  chmod 000 "$repo/unreadable.txt"
  review_post "medium HEAD~0..HEAD"
  stop gate
  reminded || bad "review gate: a snapshot that could not read a file silenced it"
  chmod 644 "$repo/unreadable.txt"
  rm -f "$repo/unreadable.txt"
fi
# A glob among the arguments is a path, not files to expand into, even where
# a file's name would turn it into a review level.
mkdir -p "$scratch/globdir"
: > "$scratch/globdir/medium"
here="$PWD"
( cd "$scratch/globdir" &&
  jq -cn --arg d "$repo" '{session_id: "gate", cwd: $d, tool_name: "Skill", tool_input: {skill: "code-review", args: "m*m"}}' |
  env CLAUDE_PLUGIN_DATA="$data" "$here/$hook" post-tool > /dev/null 2>&1 )
stop gate
reminded || bad "review gate: a review of a path glob silenced it"
review_post "medium --max-findings 5"
stop gate
[ ! -s "$scratch/out" ] || bad "review gate: a reviewed tree got a reminder"
# Handoffs, like plans, are not changes to review, and an accented name hashes.
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
review_post "medium"
mkdir -p "$repo/sub"
ln -s sub "$repo/alink"
printf 'z\n' > "$repo/zfile"
review_post "medium"
printf 'z2\n' > "$repo/zfile"
stop gate
reminded || bad "review gate: an edit after an unhashable untracked link got no reminder"
rm -r "$repo/sub" "$repo/alink" "$repo/zfile"
review_post "medium"
printf 'new\n' > "$repo/b.txt"
stop gate
reminded || bad "review gate: a new untracked file after the review got no reminder"
hook_run expansion "$(jq -cn --arg d "$repo" '{session_id: "gate", cwd: $d, command_name: "code-review", command_args: "medium"}')"
stop gate
[ ! -s "$scratch/out" ] || bad "review gate: a typed review was not recorded"
# Changes the session started with are not its own.
start inherited
stop inherited
[ ! -s "$scratch/out" ] || bad "review gate: changes from before the session got a reminder"
# Only plans changed, or not a repo at all.
git -C "$repo" checkout -q -- a.txt
rm "$repo/b.txt"
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

# The reminder to review the whole pull request after a push, in a repo with
# a remote whose branches the pushes move. The remote names main as its
# default, as a clone does.
pr="$scratch/pr"
git init -q --bare "$scratch/pr-remote.git"
git clone -q "$scratch/pr-remote.git" "$pr" 2>/dev/null
git -C "$pr" symbolic-ref HEAD refs/heads/main
printf 'one\n' > "$pr/a.txt"
git -C "$pr" add a.txt
git -C "$pr" -c user.name=t -c user.email=t@t commit -qm init
git -C "$pr" push -q -u origin main 2>/dev/null
git -C "$pr" remote set-head origin main
git -C "$pr" checkout -q -b feature
git -C "$pr" push -q -u origin feature 2>/dev/null
pr_commit() {
  printf '%s\n' "$1" > "$pr/a.txt"
  git -C "$pr" -c user.name=t -c user.email=t@t commit -qam "$1"
}
# Stubs stand in for gh, glab and gt, so no test reaches a real service. Each
# exits with the status in $scratch/stub-status.
mkdir -p "$scratch/stub"
# The stub reads its status when it runs, so the expansion stays quoted.
# shellcheck disable=SC2016
for tool in gh glab gt; do
  printf '#!/bin/sh\nexit "$(cat %s/stub-status 2>/dev/null || echo 0)"\n' "$scratch" > "$scratch/stub/$tool"
  chmod +x "$scratch/stub/$tool"
done
# Runs a command through the hook as Claude Code would: pre-tool, the command
# itself, then post-tool, or PostToolUseFailure when the command fails. $2
# names a subagent.
pr_bash() {
  local agent="${2:-}" event=PostToolUse
  hook_run pre-tool "$(jq -cn --arg d "$pr" --arg c "$1" --arg a "$agent" \
    '{session_id: "pr", cwd: $d, hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}
      + (if $a == "" then {} else {agent_id: $a} end)')"
  (cd "$pr" && PATH="$scratch/stub:$PATH" && eval "$1") > /dev/null 2>&1 || event=PostToolUseFailure
  hook_run post-tool "$(jq -cn --arg d "$pr" --arg c "$1" --arg e "$event" --arg a "$agent" \
    '{session_id: "pr", cwd: $d, hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}}
      + (if $a == "" then {} else {agent_id: $a} end)')"
}
pr_review() {
  hook_run post-tool "$(jq -cn --arg d "$pr" --arg a "$1" '{session_id: "pr", cwd: $d, tool_name: "Skill", tool_input: {skill: "code-review", args: $a}}')"
}
pr_stop() { stop pr "${1:-}" "$pr"; }
pr_reminded() { jq -r '.hookSpecificOutput.additionalContext // empty' "$scratch/out" 2>/dev/null | grep -q 'review the whole PR'; }
start pr "$pr"
pr_stop
[ ! -s "$scratch/out" ] || bad "pr reminder: a branch nobody pushed this session got a reminder"
pr_commit two
pr_bash 'git push -q'
pr_stop
pr_reminded || bad "pr reminder: a push got no reminder"
[ "$(jq -r '.hookSpecificOutput.hookEventName' "$scratch/out")" = Stop ] || bad "pr reminder: the reminder is not Stop context"
pr_stop
[ ! -s "$scratch/out" ] || bad "pr reminder: reminded twice for the same push"
pr_commit three
pr_bash 'git push -q origin HEAD'
pr_stop '{"background_tasks": [{"id": "t1", "type": "subagent", "status": "running", "description": "code-review high a..b"}]}'
[ ! -s "$scratch/out" ] || bad "pr reminder: acted while a code-review ran"
pr_review "high $(git -C "$pr" rev-parse HEAD~2)..$(git -C "$pr" rev-parse HEAD~1)"
pr_stop
pr_reminded || bad "pr reminder: a review ending at another commit cleared it"
pr_commit four
pr_bash 'git push -q'
pr_review "high $(git -C "$pr" rev-parse HEAD~1)..HEAD"
pr_stop
pr_reminded || bad "pr reminder: a review of the last commit alone cleared it"
pr_review "high --max-findings 5 $(git -C "$pr" merge-base origin/main HEAD)..HEAD"
pr_stop
[ ! -s "$scratch/out" ] || bad "pr reminder: a review of the whole range did not clear it"
# A review that ran before the push counts once the push lands on its end.
pr_commit five
pr_review "high $(git -C "$pr" merge-base origin/main HEAD)..HEAD"
pr_bash 'git push -q'
pr_stop
[ ! -s "$scratch/out" ] || bad "pr reminder: a review run before the push did not count"
# A pull request opened on a commit whose push was already reminded about
# gets its own reminder.
pr_commit five-open
pr_bash 'git push -q'
pr_stop
pr_reminded || bad "pr reminder: a push got no reminder before its pull request opened"
pr_bash 'gh pr create --title x --body-file body.md'
pr_stop
pr_reminded || bad "pr reminder: a pull request opened on a commit already reminded about got no reminder"
# A pull request opened on the pushed branch asks for the same review, and a
# review of the pull request by number clears it.
pr_commit six
git -C "$pr" push -q 2>/dev/null
for web in 'gh pr create --web' 'gh pr create -w' 'gh pr create --web=true' 'gh pr create -dw' \
  'gh pr create --title x --body-file b.md --dry-run' 'glab mr create -w' 'glab mr create -yw' 'gt submit --dry-run'; do
  pr_bash "$web"
  pr_stop
  pr_reminded && bad "pr reminder: '$web', which opens no pull request, got a reminder"
done
printf '1\n' > "$scratch/stub-status"
pr_bash 'gh pr create --title x --body-file body.md'
pr_stop
pr_reminded && bad "pr reminder: a pull request that failed to open got a reminder"
rm -f "$scratch/stub-status"
pr_bash 'gh pr create --title x --body-file body.md'
pr_stop
pr_reminded || bad "pr reminder: a new pull request got no reminder"
pr_commit six-mr
git -C "$pr" push -q 2>/dev/null
pr_bash 'glab mr create --title x'
pr_stop
pr_reminded || bad "pr reminder: a new merge request got no reminder"
# The reminder went out above, so the state file shows what the review did.
pr_review "high https://gitlab.com/o/r/-/merge_requests/5"
[ "$(cat "$data/sessions/pr/pr-review" 2>/dev/null)" = "$(git -C "$pr" rev-parse HEAD)" ] \
  || bad "pr reminder: a review of the merge request did not count"
# What the classifier says about a pull request command decides its gate and
# whether it counts as opening one.
for case in 'gh pr create -twip -b x|gate pr open pr' 'gh pr create --web=false -t x|gate pr open pr' \
  'gh pr create -dw|gate push' 'gh pr create --dry-run=true|gate push' 'glab mr create --web=false -t x|gate pr open pr' \
  'glab mr create -yw|gate pr' 'gt submit|gate push gate pr open pr' 'gt submit --dry-run|gate push gate pr'; do
  said="$(printf '%s' "${case%%|*}" | awk -f hooks/classify-command.awk | tr '\n' ' ')"
  [ "$said" = "${case#*|} " ] || bad "classifier: '${case%%|*}' gave '$said', not '${case#*|}'"
done
# A pull request opened through the API counts too, by REST or GraphQL.
for api in 'gh api repos/o/r/pulls -f title=x -f head=feature -f base=main' \
  "gh api graphql -f query='mutation { createPullRequest(input: {}) { pullRequest { url } } }'"; do
  pr_commit "api-$(printf '%s' "$api" | cksum | cut -d' ' -f1)"
  git -C "$pr" push -q 2>/dev/null
  pr_bash "$api"
  pr_stop
  pr_reminded || bad "pr reminder: a pull request opened by '$api' got no reminder"
done
# A push that landed counts though the pull request after it failed to open.
pr_commit six-fail
printf '1\n' > "$scratch/stub-status"
pr_bash 'git push -q && gh pr create --title x --body-file b.md'
rm -f "$scratch/stub-status"
pr_stop
pr_reminded || bad "pr reminder: a push followed by a pull request that failed to open got no reminder"
# A commit and its push in one command count, though the branch's name was
# already among the remote branches.
pr_bash 'printf six2 > a.txt && git -c user.name=t -c user.email=t@t commit -qam six2 && git push -q'
pr_stop
pr_reminded || bad "pr reminder: a commit and push in one command got no reminder"
pr_commit seven
pr_bash 'git push -q'
pr_review "high 5abc"
pr_stop
pr_reminded || bad "pr reminder: a review of a commit read as a pull request cleared it"
pr_review "high https://github.com/o/r/pull/12/files/$(git -C "$pr" merge-base origin/main HEAD)..$(git -C "$pr" rev-parse HEAD)"
[ "$(cat "$data/sessions/pr/pr-review" 2>/dev/null)" = "$(git -C "$pr" rev-parse HEAD)" ] \
  && bad "pr reminder: a link to a range inside the pull request counted as the whole of it"
pr_review "high 12"
pr_stop
[ ! -s "$scratch/out" ] || bad "pr reminder: a review of the pull request did not clear it"
# A push to a remote branch the branch does not track, as to a fork, counts.
git init -q --bare "$scratch/pr-fork.git"
git -C "$pr" remote add fork "$scratch/pr-fork.git"
pr_commit eight
pr_bash 'git push -q fork HEAD:feature'
pr_stop
pr_reminded || bad "pr reminder: a push to a fork's branch got no reminder"
# What a push did not move records nothing.
pr_commit nine
pr_bash 'git push -q nowhere HEAD'
pr_stop
pr_reminded && bad "pr reminder: a failed push got a reminder"
pr_bash 'git push -q && false'
pr_stop
pr_reminded || bad "pr reminder: a push in a command that then failed got no reminder"
git -C "$pr" push -q 2>/dev/null
git -C "$pr" push -q fork HEAD:feature 2>/dev/null
# The branch is already at HEAD on the remote here, pushed outside the hook,
# so only a push that moves it again would count.
pr_commit ten
git -C "$pr" push -q 2>/dev/null
git -C "$pr" tag v1
pr_bash 'git push -q origin v1'
pr_stop
pr_reminded && bad "pr reminder: a tag push got a reminder"
# A push that starts outside the repo and changes into it has nothing to
# compare against, so this one, which moves nothing, records nothing.
cmd="cd $pr && git push -q"
hook_run pre-tool "$(jq -cn --arg d "$scratch/plain" --arg c "$cmd" '{session_id: "pr", cwd: $d, hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}')"
(eval "$cmd") > /dev/null 2>&1
hook_run post-tool "$(jq -cn --arg d "$pr" --arg c "$cmd" '{session_id: "pr", cwd: $d, hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: {command: $c}}')"
pr_stop
pr_reminded && bad "pr reminder: a push that moved nothing, run from outside the repo, got a reminder"
pr_bash 'git push -q origin HEAD:main'
pr_stop
pr_reminded && bad "pr reminder: a push to the default branch got a reminder"
pr_commit ten-agent
pr_bash 'git push -q' agent-1
pr_stop
pr_reminded && bad "pr reminder: a subagent's push got a reminder"
pr_bash 'git status --short'
pr_stop
pr_reminded && bad "pr reminder: a command that is not a push got a reminder"
# A commit on top of the pushed one leaves the reminder for the next push,
# and uncommitted changes get their own reminder first.
pr_commit eleven
pr_bash 'git push -q'
pr_commit twelve
pr_stop
pr_reminded && bad "pr reminder: reminded about a push HEAD has moved past"
pr_bash 'git push -q'
printf 'dirty\n' > "$pr/a.txt"
pr_stop
reminded || bad "pr reminder: uncommitted changes lost their reminder to the push"
git -C "$pr" checkout -q -- a.txt
pr_stop
pr_reminded || bad "pr reminder: the push got no reminder once the tree was clean"
# A three-dot range reads from the merge base, so it counts once the default
# branch has moved past where the branch left it.
side="$(git -C "$pr" -c user.name=t -c user.email=t@t commit-tree -p origin/main -m side "origin/main^{tree}")"
git -C "$pr" push -q origin "$side:refs/heads/main" 2>/dev/null
git -C "$pr" fetch -q origin
pr_commit thirteen
pr_bash 'git push -q'
pr_review "high origin/main...HEAD"
[ "$(cat "$data/sessions/pr/pr-review" 2>/dev/null)" = "$(git -C "$pr" rev-parse HEAD)" ] \
  || bad "pr reminder: a three-dot range from the default branch did not count as the whole PR"
pr_counted() { [ "$(cat "$data/sessions/pr/pr-review" 2>/dev/null)" = "$(git -C "$pr" rev-parse HEAD)" ]; }
pr_commit fourteen
pr_bash 'git push -q'
pr_review "high origin/main..HEAD"
pr_counted || bad "pr reminder: a two-dot range from the default branch did not count as the whole PR"
pr_commit fifteen
pr_bash 'git push -q'
pr_review "high origin/main..."
pr_counted || bad "pr reminder: a three-dot range with no end did not count as the whole PR"
# A link to one commit of the pull request reads part of it; its files page
# reads all of it.
pr_commit sixteen
pr_bash 'git push -q'
pr_review "high https://github.com/o/r/pull/12/commits/abc1234"
pr_counted && bad "pr reminder: a link to one commit of the pull request counted as the whole of it"
pr_review "medium https://github.com/o/r/pull/12"
pr_counted && bad "pr reminder: a review of the pull request below high counted"
pr_review "high https://github.com/o/r/pull/12/files"
pr_counted || bad "pr reminder: a link to the pull request's files did not count"
# Two commands running at once each keep their own state, by tool call.
pr_commit seventeen
pr_hook() {
  hook_run "$1" "$(jq -cn --arg d "$pr" --arg c "$2" --arg e "$3" --arg i "$4" \
    '{session_id: "pr", cwd: $d, hook_event_name: $e, tool_name: "Bash", tool_use_id: $i, tool_input: {command: $c}}')"
}
pr_hook pre-tool 'git push -q' PreToolUse t1
pr_hook pre-tool 'gh pr edit 12 --title x' PreToolUse t2
pr_hook post-tool 'gh pr edit 12 --title x' PostToolUse t2
git -C "$pr" push -q 2>/dev/null
pr_hook post-tool 'git push -q' PostToolUse t1
pr_stop
pr_reminded || bad "pr reminder: a push run beside another push command got no reminder"

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
for event in UserPromptSubmit UserPromptExpansion PreToolUse PostToolUse PostToolUseFailure Stop; do
  command="$(jq -r --arg e "$event" '.hooks[$e][0].hooks[0].command // empty' hooks/hooks.json)"
  case "$command" in
    "$quoted"*) ;;
    *) bad "hooks.json: $event does not run the quoted eng-hook: $command" ;;
  esac
done
[ "$(jq -r '.hooks.PreToolUse[0].matcher' hooks/hooks.json)" = 'Bash|Monitor|PowerShell|Skill|mcp__.*' ] \
  || bad "hooks.json: PreToolUse does not match Bash, Monitor, PowerShell, Skill and MCP tools"

[ "$fail" -eq 0 ] && printf 'hooks: ok\n'
exit "$fail"
