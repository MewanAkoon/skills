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
for said in "Don't stage, commit, or push anything" "Do not, under any circumstances, push"; do
  set_state listed "$said" commit pr
  expect_bash listed ask 'git push origin x' 'does not ask for this push'
done
for said in "commit now, push after I've reviewed it" "only push once I approve" "commit it and we can push tomorrow" "I didn't ask you to push" "leave the push to me" "commit and push. Actually, don't push" "commit, I won't push" "commit it, push it later" "ill push it" "you shouldnt push this" "commit and push. Actually, don't." "commit and push. No, don't push" "commit and push, no wait, just commit" "commit; tomorrow we push" "I didnt want a push" "commit it, I'll push it myself"; do
  set_state deferred "$said" commit pr
  expect_bash deferred ask 'git push origin x' 'does not ask for this push'
done
for said in "commit and push. Actually, scratch that" "push, but not yet" "commit it. push it, not now"; do
  set_state taken "$said" commit pr
  expect_bash taken ask 'git push origin x' 'does not ask for this push'
done
for said in "commit and push. No problem, wait for CI" "Push it. But not until CI passes." "commit and push. Just not yet" "commit and push. Wait, no" "commit and push. Wait wait wait" "commit and push. Wait no, don't push" "commit and push... wait, only commit" "commit and push. nvm, just commit" "commit and push. Cancel that, just commit" "commit and push. Hold on, just commit" "commit and push. I take that back, just commit" "commit and push. Change of plan: just commit" "commit and push. Wait" "you mustnt push this" "push it. Actually no. Actually, just commit" "push it, I'll check first" "commit and push. Not yet." "push the branch. Not until CI passes" "push it, though not yet" "push, scratch that" "commit and push, ignore that" "commit and push. No, wait" "commit and push. Oh wait, no" "push it, not before I approve" "push it, but not until prod is green" "commit and push. Actually, just commit" "push it. Actually, let me look first" "commit and push. Never mind, just commit" "commit and push. On second thought, just commit" "commit and push. Forget that, just commit" "you neednt push" "commit, I wont push" "push it, but not until it's approved" "commit and push, but not to production yet"; do
  set_state boundary "$said" commit pr
  expect_bash boundary ask 'git push origin x' 'does not ask for this push'
done
for said in "Don't commit yet. Actually, go ahead and commit" "Scratch that last test change, then commit" "Push it. Did the tests pass? Commit too" "commit this, then run the tests without the cache"; do
  set_state reasked "$said" commit
  expect_bash reasked allow 'git commit -m x'
done
set_state scratched "commit, push, and open a PR. Scratch the PR" commit pr
expect_bash scratched ask 'gh pr create -t x' 'pull request'
expect_bash scratched allow 'git push origin x'
for said in "commit and push. no rush" "commit and push, no rush" "open a PR and push. Then cancel the old PR"; do
  set_state norush "$said" commit pr
  expect_bash norush allow 'git push origin x'
done
set_state notpr "push and open a PR. Not the PR" pr
expect_bash notpr ask 'gh pr create -t x' 'pull request'
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
for said in "commit and push. Cancel the push" "commit and push. Forget pushing" "commit and push. Never mind the push. Open the PR" "commit and push. Don't push." "commit and push. No push." "commit and push. Hold the push." "commit and push. I'll push." "Push it. Tomorrow though." "Push it. Hmm, not yet." "push it when the tests pass" "push it, nope" "Commit and push. Actually, just push. Actually, just commit" "commit, push. Never mind the push"; do
  set_state lastword "$said" commit pr
  expect_bash lastword ask 'git push origin x' 'does not ask for this push'
done
for said in "let me know when you're ready to push" "commit and push but let me review first" "commit and push, but let me run the tests first" "push it. Let me think." "commit and push. Stop." "Push it. Give CI a minute first." "commit but hold on pushing" "commit and push but hold on the push" "push when we've reviewed it" "push when approved" "commit, and push when green" "commit and push, but hold for now" "commit, push on hold" "commit, maybe push" "commit, ideally push too" "commit and push. Hang on." "commit and push. One sec." "commit and push. Give me a minute." "push it. Disregard that." "Push it. Then again, maybe not." "push it when the CI is green" "maybe push it" "commit and push. Hold pushing" "commit and push. Cancel pushing." "commit and push. Forget about pushing." "Push it. OK but not yet." "Push it. Let's hold off." "Push it. I'd rather wait." "commit and push. Let me review the diff first." "Push it. Let's wait for CI." "push it in a bit" "commit and push. Scrap the push"; do
  set_state later2 "$said" commit pr
  expect_bash later2 ask 'git push origin x' 'does not ask for this push'
done
for said in "commit, push and open a PR. Forget about the PR." "commit, push and open a PR. Never mind about the PR." "commit, push and open a PR. Drop the PR."; do
  set_state droppr "$said" commit pr
  expect_bash droppr ask 'gh pr create -t x' 'pull request'
  expect_bash droppr allow 'git push origin x'
done
set_state refusedpr "Don't push. Open a PR" pr
expect_bash refusedpr ask 'git push origin x' 'does not ask for this push'
# "Ping me when" and "when you're done" time the report, not the write.
set_state whenup "open a PR and ping me when it is up" pr
expect_bash whenup allow 'gh pr create -t x'
for said in "commit the current changes and push" "I want you to commit and push" "commit and push when you're done" "Can you commit and push this when you're done" "drop the debug log and push" "skip the flaky test, then push" "let's push this" "you should push this" "commit and push. Better safe than sorry" "push it. Let me know when it's done" "cancel the previous build and push" "drop the prints and push"; do
  set_state plain "$said" commit pr
  expect_bash plain allow 'git push origin x'
done
set_state cancelold "open a PR and push. Then cancel the old PR" pr
expect_bash cancelold allow 'gh pr create -t x'
set_state remembered "remember to commit" commit
expect_bash remembered allow 'git commit -m x'
set_state aswell "commit this as well" commit
expect_bash aswell allow 'git commit -m x'
expect_bash none allow 'git commit -h'
expect_bash none deny 'gh pr new --title x' 'eng:pr'
expect_bash none deny 'gh issue new --title x' 'eng:issue'
expect_bash none deny 'gt submit' 'eng:'
hook_run pre-tool '{"session_id": "none", "tool_name": "mcp__github__create_issue", "tool_input": {}}'
[ "$(verdict)" = deny ] || bad "write gate: a GitHub MCP issue write without eng:issue was not denied"
# Loaded, but the message did not ask: ask.
set_state quiet "tidy up the parser" commit pr issue
expect_bash quiet ask 'git commit -m x' 'does not ask for this commit'
expect_bash quiet ask 'gh pr edit 5 --body-file b.md' 'pull request'
expect_bash quiet ask 'gh label create bug' 'issue'
# Loaded and asked: allow. A word inside another word does not count.
set_state asked "Commit this, please" commit
expect_bash asked allow 'git commit -m x'
expect_bash asked ask 'git push origin feature/x' 'does not ask for this push'
set_state approve "approve the plan" pr
expect_bash approve ask 'gh pr create --title x --body-file b.md'
set_state negated "Don't push yet, just commit" commit pr
expect_bash negated allow 'git commit -m x'
expect_bash negated ask 'git push origin x' 'does not ask for this push'
set_state stopping "stop committing, and before committing run the tests" commit
expect_bash stopping ask 'git commit -m x' 'does not ask for this commit'
set_state nopush "don't push yet, I'm reviewing it" commit
expect_bash nopush ask 'git commit -m x' 'does not ask for this commit'
set_state pushthis "push this branch" commit
expect_bash pushthis allow 'git commit -m x'
expect_bash none deny 'glab mr create --fill --push' 'eng:'
expect_bash none deny 'glab label create bug' 'eng:issue'
expect_bash none deny 'glab -R a/b mr create --fill' 'eng:pr'
expect_bash none deny 'glab -Ra/b mr create' 'eng:pr'
expect_bash none deny 'glab mr -R a/b create --fill' 'eng:pr'
expect_bash none deny 'glab --repo=a/b mr create' 'eng:pr'
# The last clause that names the push decides, so these ask: a prompt, by
# design, rather than a guess at which push was meant.
for said in "commit and push, but run the tests before pushing" "push it, but don't push to main"; do
  set_state saidpush "$said" commit pr
  expect_bash saidpush ask 'git push origin x' 'does not ask for this push'
done
set_state mr "open the MR" pr
expect_bash mr allow 'glab mr create'
expect_bash mr allow 'git push origin x'
set_state mrquiet "tidy up" pr
expect_bash mrquiet ask 'glab mr create -f' 'push'
set_state remind "don't forget to push" commit
expect_bash remind allow 'git push origin x'
set_state ordered "before you push, open the pr" pr
expect_bash ordered ask 'git push origin x' 'does not ask for this push'
for said in "please don't commit or push" "I'm not ready to push yet" "don't want to push this" "don't run git push" "don't push, I'll push it myself"; do
  set_state refusing "$said" commit pr
  expect_bash refusing ask 'git push origin x' 'does not ask for this push'
done
set_state stageless "do not stage anything, push" commit
expect_bash stageless ask 'git commit -m x' 'does not ask for this commit'
# A clause that holds back in any way, even "I'll need a PR", asks: the rule
# errs toward a prompt.
set_state needpr "I'll need a PR for this" pr
expect_bash needpr ask 'gh pr create -t x' 'pull request'
for said in "commit, I'll handle the push" "commit, I won't push yet" "just commit, hold off on pushing" "why did the push fail?"; do
  set_state held "$said" commit pr
  expect_bash held ask 'git push origin x' 'does not ask for this push'
done
set_state mine "I'll open the PR myself, just push" commit pr
expect_bash mine ask 'gh pr create -t x' 'pull request'
expect_bash mine allow 'git push origin x'
for said in "push it; I'm checking CI" "push it, multistage build is fixed"; do
  set_state checking "$said" commit
  expect_bash checking allow 'git commit -m x'
done
set_state update "push and create MR" pr
expect_bash update allow 'glab mr create'
set_state notyet "don't open a pr yet" pr
expect_bash notyet ask 'gh pr create --title x' 'pull request'
set_state dare "open a PR, but don't you dare push" pr
expect_bash dare ask 'git push origin x' 'does not ask for this push'
set_state raise "raise MR for this" pr
expect_bash raise allow 'glab mr create'
set_state titled "open the MR, don't push" pr
expect_bash titled allow 'glab mr create -tfix'
expect_bash titled ask 'glab mr create -t "-Rework" --fill' 'does not ask for this push'
expect_bash titled ask 'glab mr create -fb main' 'does not ask for this push'
set_state honorific "ask Mr Smith about the bug" pr
expect_bash honorific ask 'gh pr create --title x' 'pull request'
set_state pushing "pushing is fine" commit
expect_bash pushing allow 'git push origin x'
set_state mronly "open an MR, but don't push" pr
expect_bash mronly ask 'glab mr create --fill' 'does not ask for this push'
expect_bash mronly ask 'glab mr create -fy' 'does not ask for this push'
set_state pushonly "No need to commit, just push" commit pr
expect_bash pushonly ask 'git commit -m x' 'does not ask for this commit'
set_state committing "committing is fine" commit
expect_bash committing allow 'git commit -m x'
expect_bash none deny 'glab mr create --fill' 'eng:pr'
set_state reminder "Don't forget to commit" commit
expect_bash reminder allow 'git commit -m x'
set_state stophere "stop here and commit what you have" commit
expect_bash stophere ask 'git commit -m x' 'does not ask for this commit'
set_state checkin "check it in" commit
expect_bash checkin allow 'git commit -m x'
set_state labelled "fix the label alignment" issue
expect_bash labelled ask 'gh label delete old' 'issue'
set_state feedback "use eng:pr-feedback on these comments" pr
expect_bash feedback ask 'gh pr edit 5 --body-file b.md'
set_state pushed "open a PR for this" pr
expect_bash pushed allow 'git push -u origin feature/x'
expect_bash pushed allow 'gh pr create --title x --body-file b.md'
# A push the gate allows still asks when it forces.
expect_bash pushed ask 'git push --force-with-lease origin feature/x' 'forces'
# A typed /eng:commit is both the skill and the request.
set_state typed "/eng:commit" commit
expect_bash typed allow 'git commit -m x'
# No state at all: ask, never allow.
jq -cn '{session_id: "missing", tool_name: "Bash", tool_input: {command: "git commit -m x"}}' |
  "$hook" pre-tool > "$scratch/out" 2>/dev/null
[ "$(verdict)" = ask ] || bad "write gate: a commit with no state did not ask"
bash_call nosuchsession 'git commit -m x'
[ "$(verdict)" = ask ] || bad "write gate: a commit in a session with no message did not ask"
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
# In a Claude project only the human's words count, not the routing around
# them or a coordinator's note.
prompt project '<wake reason="mention"><project id="p"><message trigger="true" from="human" trust="principal" id="m1">Tidy the parser.</message></project></wake>'
grep -q 'Tidy the parser' "$data/sessions/project/turn" || bad "prompt: a project message lost the human's words"
prompt project '<coordinator-relay><relay from="coordinator"><note>Commits, pushes and PRs each need the user to ask.</note><cited author="user">look into the parser</cited></relay></coordinator-relay>'
grep -q 'look into' "$data/sessions/project/turn" || bad "prompt: a relay lost the user's cited words"
grep -q 'Commits' "$data/sessions/project/turn" && bad "prompt: a coordinator's note counted as the user's words"
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
