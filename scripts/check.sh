#!/usr/bin/env bash
# Checks this repo against the invariants in AGENTS.md.
# Needs bash, jq, and the usual POSIX tools. Run before committing.
#
# --doctor adds the checks CI cannot run, because a fresh runner has no
# Claude Code install to inspect: whether Claude Code is new enough, whether
# the plugin is installed at user scope at this version, whether bare copies
# of its skills are still loading beside it, whether the skillOverrides entry
# the README asks for is in place, and whether the session hook logged errors.

set -uo pipefail

# Resolve through a symlink, so invoking this from a bin directory on PATH
# still finds the clone rather than the symlink's own directory.
SELF="$(readlink -f "$0" 2>/dev/null || true)"
# An empty SELF would make `dirname` return `.`, so the cd below would succeed
# into the wrong directory and every glob would quietly match nothing. Say what
# is wrong instead. `readlink -f` is GNU and BSD both today, and missing on
# macOS before Big Sur.
[ -n "$SELF" ] || { printf 'error: readlink -f cannot resolve %s\n' "$0" >&2; exit 1; }
cd "$(dirname "$SELF")/.." || exit 1

doctor=no
for arg in "$@"; do
  case "$arg" in
    --doctor) doctor=yes ;;
    *) printf 'usage: check.sh [--doctor]\n' >&2; exit 2 ;;
  esac
done

fail=0
bad() { printf 'FAIL  %s\n' "$1" >&2; fail=1; }
warn() { printf 'WARN  %s\n' "$1" >&2; }

# Is MAJOR.MINOR.PATCH $1 newer than $2? Field by field, so 0.10.0 counts as
# newer than 0.9.0.
newer() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    split(a, x, "."); split(b, y, ".")
    for (i = 1; i <= 3; i++) {
      if (x[i] + 0 > y[i] + 0) exit 0
      if (x[i] + 0 < y[i] + 0) exit 1
    }
    exit 1
  }'
}

# Everything between the opening and closing --- of a markdown file.
frontmatter() {
  awk 'NR==1 && $0=="---" { inside=1; next } inside && $0=="---" { exit } inside' "$1"
}

# Everything after the frontmatter.
body() {
  awk 'NR==1 && $0=="---" { inside=1; next } inside && $0=="---" { inside=0; started=1; next } started' "$1"
}

# Every markdown file this repo owns, committed or not, so .gitignore decides
# what counts and a new file is checked before anyone commits it. git's own
# errors are left to print, because a file list that comes back empty makes
# every check reading it pass without opening a thing.
markdown() {
  git ls-files --cached --others --exclude-standard -- '*.md' '*.mdc' | present
}

# git lists a file it still has in the index even after someone deletes it on
# disk, so every reader below would open a path that is gone and print its own
# error. Dropping those keeps a partial adoption, which starts by deleting a
# skill directory, from making this script look broken.
present() {
  while IFS= read -r p; do
    [ -f "$p" ] && printf '%s\n' "$p"
  done
  return 0
}

# The same list without the untracked files. The block runner below executes
# what it finds, so it reads only what someone has staged or committed rather
# than whatever happens to be sitting in the tree. Staged counts, so a new
# file is checked after `git add` and before the commit.
tracked_markdown() {
  git ls-files --cached -- '*.md' '*.mdc' | present
}

# Byte length of a string, the same in every locale. ${#var} counts characters
# under UTF-8 and bytes under C, so a budget read that way passes on one
# machine and fails on another.
bytes() {
  printf '%s' "$1" | LC_ALL=C wc -c | tr -d ' '
}

# A one-line frontmatter value has to parse as YAML, which both harnesses do
# before they read a field. A block scalar (`>` or `|`) leaves only its
# indicator on the line, so every length check here would read one character.
# A plain value holding ": " or " #" is not what it looks like: the first is
# invalid YAML, and Claude Code then drops the whole frontmatter and falls back
# to the body's first line, and the second starts a comment that cuts the value
# short. A colon before a tab or at the end, and a leading character YAML
# reserves, either fail the parse or change what the value means. Quoting the
# value is the other fix, and a quoted value is checked for the quotes and
# backslashes inside it that would end or garble it.
plain_yaml() {
  tab="$(printf '\t')"
  case "$2" in
    '>'*|'|'*) bad "$1: description is a block scalar. Write it on one line"; return ;;
    \'*\')
      # Inside single quotes YAML reads a doubled quote as one, and any other
      # single quote ends the value early.
      inner="${2:1:${#2}-2}"
      inner="${inner//\'\'/}"
      case "$inner" in
        *\'*) bad "$1: description holds a single quote inside single quotes. Double it, or reword" ;;
      esac
      return ;;
    \"*\")
      # Inside double quotes a backslash starts an escape and a bare double
      # quote ends the value, and neither is worth the risk in prose.
      inner="${2:1:${#2}-2}"
      case "$inner" in
        *\\*|*\"*) bad "$1: description holds a backslash or a double quote inside double quotes. Use single quotes, or reword" ;;
      esac
      return ;;
    \"*|\'*) bad "$1: a quoted description has to end on its closing quote, with nothing after it"; return ;;
  esac
  case "$2" in
    *': '*|*' #'*|*":$tab"*|*"$tab#"*|*':')
      bad "$1: description holds \": \", a space or tab before \"#\", a colon before a tab, or a trailing colon, which YAML misreads. Reword it, or quote the value" ;;
  esac
  # One character per pattern, because a bracket set holding quotes and
  # brackets is easy to get wrong and fails silently when it is.
  case "${2:0:1}" in
    '`'|'@'|'%'|'['|']'|'{'|'}'|'!'|'&'|'*'|'?'|','|'#')
      bad "$1: description starts with a character YAML reserves. Reword it, or quote the value" ;;
  esac
  case "$2" in
    '- '*) bad "$1: description starts with \"- \", which YAML reads as a list. Reword it, or quote the value" ;;
  esac
}

# A description that runs onto an indented second line is still one YAML
# value, but every length check here reads only its first line, so a long
# description would pass its budget unmeasured.
continued_description() {
  printf '%s\n' "$2" | awk '/^description:/ { getline nxt; if (nxt ~ /^[ \t]/) exit 1; exit 0 }' \
    || bad "$1: description continues onto a second line. Keep it on one line"
}

# The README table rows under one heading, used to check where a skill is listed.
section() {
  sed -n "/^### $1\$/,/^#\{2,3\} /p" README.md
}

# Does one of those sections hold a table row for this skill?
row_in() {
  printf '%s\n' "$1" | grep -q "^| \[$2\](skills/$2/SKILL\.md) |"
}

readme_model="$(section 'Model-invoked')"
readme_user="$(section 'User-invoked')"

model_count=0
model_names=" "
description_total=0

# Names Claude Code already uses for a built-in command or a bundled skill, as
# of 2.1.293. A skill here with one of these names would be shadowed, or would
# shadow the built-in, depending on how it is typed. commit and pr are the two
# this repo keeps on purpose: every reference writes them eng:commit and
# eng:pr, and the README's skillOverrides entry turns the built-ins off.
reserved=" add-dir agents batch bug claude-api clear code-review compact config
 context cost dataviz debug doctor explain-usage exit export feedback
 fewer-permission-prompts help hooks ide init insights install-github-app
 keybindings-help login logout loop mcp memory memory-types model permissions
 plan plugin plugin-authoring release-notes reload-plugins resume review rewind
 run run-skill-generator schedule security-review simplify skill-doctor skills
 status statusline tasks terminal-setup theme todos update-config upgrade usage
 verify workflow-authoring "

for dir in skills/*/; do
  name="$(basename "$dir")"
  skill="${dir}SKILL.md"

  if [ ! -f "$skill" ]; then
    bad "$name: no SKILL.md"
    continue
  fi

  fm="$(frontmatter "$skill")"

  declared="$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1)"
  if [ -z "$declared" ]; then
    bad "$name: frontmatter has no name"
  elif [ "$declared" != "$name" ]; then
    bad "$name: frontmatter name is '$declared', directory is '$name'"
  fi

  # The Agent Skills spec: 1 to 64 characters, lowercase letters, digits, and
  # single hyphens, with no hyphen at either end. A name that only matches its
  # directory still breaks a strict validator when the directory is wrong too.
  if ! printf '%s' "$name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
    bad "$name: name must be lowercase letters, digits, and single hyphens"
  fi
  if [ "${#name}" -gt 64 ]; then
    bad "$name: name is ${#name} characters, over the spec's 64"
  fi
  case "$reserved" in
    *[[:space:]]"$name"[[:space:]]*) bad "$name: Claude Code already uses this name for a built-in" ;;
  esac

  description="$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -1)"
  if [ -z "$description" ]; then
    bad "$name: frontmatter has no description"
  elif [ "${#description}" -gt 1024 ]; then
    bad "$name: description is ${#description} characters, over the spec's 1024"
  fi
  plain_yaml "$name" "$description"
  continued_description "$name" "$fm"

  # Cursor reads neither tools field, so a skill leaning on one is restricted
  # in Claude Code and wide open in Cursor. AGENTS.md allows it only as a
  # second lock over a body already right without it, and no skill takes that
  # trade today, so any one that appears is worth a look.
  if printf '%s\n' "$fm" | grep -qE '^(allowed|disallowed)-tools:'; then
    warn "$name: carries a tools field Cursor does not read. AGENTS.md allows that only as a second lock over a body that holds without it"
  fi

  flagged=no
  printf '%s\n' "$fm" | grep -q '^disable-model-invocation:[[:space:]]*true[[:space:]]*$' && flagged=yes

  if [ "$flagged" = no ] && printf '%s\n' "$fm" | grep -q '^disable-model-invocation:'; then
    bad "$name: model-invoked but frontmatter still carries disable-model-invocation"
  fi

  if [ "$flagged" = yes ]; then
    # User-invoked: a row under User-invoked, none under the other.
    row_in "$readme_user" "$name" \
      || bad "$name: user-invoked but not listed under README '### User-invoked'"
    row_in "$readme_model" "$name" \
      && bad "$name: user-invoked but also listed under README '### Model-invoked'"
  else
    # Model-invoked: a row under Model-invoked, none under the other.
    row_in "$readme_model" "$name" \
      || bad "$name: model-invoked but not listed under README '### Model-invoked'"
    row_in "$readme_user" "$name" \
      && bad "$name: model-invoked but also listed under README '### User-invoked'"
    model_count=$((model_count + 1))
    model_names="$model_names $name "
    # Every model-invoked description rides every turn, so each has a cap and
    # the set has one. The set's cap leaves room for the harness's own skills
    # inside a listing budget the skills here do not control.
    dbytes="$(bytes "$description")"
    if [ "$dbytes" -gt 300 ]; then
      bad "$name: description is $dbytes bytes, over the budget of 300 for a model-invoked skill"
    fi
    description_total=$((description_total + dbytes))
  fi
done

if [ "$description_total" -gt 3900 ]; then
  bad "model-invoked descriptions total $description_total bytes, over the budget of 3900"
fi

# A file that loads into someone's context has a size budget, in bytes.
# AGENTS.md lists them under "Invariants".
budget() {
  [ -f "$1" ] || { bad "$1 is missing, so its budget cannot be checked"; return; }
  size="$(wc -c < "$1" | tr -d ' ')"
  [ "$size" -le "$2" ] || bad "$1 is $size bytes, over its budget of $2"
}

# Compaction keeps up to 5,000 estimated tokens of each skill a session has
# loaded, counted as characters divided by 4, so a SKILL.md past 20,000
# characters comes back cut short. 15,000 bytes leaves room under that, and
# anything only some runs need belongs in references/.
for skill_file in skills/*/SKILL.md; do
  budget "$skill_file" 15000
done

# A reference loads whole when a step reads it, and compaction keeps it the
# same way, so the same cap applies.
for reference in skills/*/references/*.md; do
  [ -f "$reference" ] || continue
  budget "$reference" 15000
done

budget standards/workflow.md 2800
budget skills/investigate/SKILL.md 6500
for lifecycle in implement pr-feedback; do
  budget "skills/$lifecycle/SKILL.md" 5000
done
budget skills/implement/references/review.md 3000
budget skills/issue/SKILL.md 6000

# Every skill the workflow names exists and is model-invoked, since the name
# is the cue to load it and a user-invoked skill refuses that call. The pattern
# reads "the X skill" and lists such as "the X, Y and Z skills", with or
# without backticks or the plugin's prefix, and across a line break. A name
# written any other way is not read, and a phrase such as "the same skill"
# reads as a skill called "same" and fails, which is the safe direction.
# Finding no name at all fails too, because a check that read nothing would
# otherwise pass.
workflow_names="$(
  [ -f standards/workflow.md ] && tr '\n' ' ' < standards/workflow.md | tr -d '`' \
    | grep -oE '[Tt]he ([a-z0-9:-]+, )*[a-z0-9:-]+(,? and [a-z0-9:-]+)? skills?' \
    | sed -E 's/^[Tt]he //; s/ skills?$//; s/,? and /,/; s/, /,/g' \
    | tr ',' '\n' | sed 's/^[a-z0-9-]*://' | sort -u
)"
[ -n "$workflow_names" ] \
  || bad "standards/workflow.md names no skill this check can read, so nothing was checked"
while IFS= read -r named; do
  [ -n "$named" ] || continue
  case "$model_names" in
    *" $named "*) ;;
    *) bad "standards/workflow.md names the $named skill, which is not a model-invoked skill here" ;;
  esac
done <<< "$workflow_names"

# Every README row points at a skill that exists.
while IFS= read -r linked; do
  [ -f "skills/$linked/SKILL.md" ] || bad "a README table row lists $linked, which has no skills/$linked/SKILL.md"
done < <(grep -o '](skills/[^/]*/SKILL\.md)' README.md | sed 's#](skills/##; s#/SKILL\.md)##' | sort -u)

# The plugin's two manifests. They are what an install reads, so a broken one
# breaks every install at once, and nothing else here opens them.
plugin_json=.claude-plugin/plugin.json
market_json=.claude-plugin/marketplace.json
plugin_name=""
market_name=""
version=""

if ! command -v jq >/dev/null 2>&1; then
  bad "jq is not installed, so the plugin manifests cannot be read"
elif [ ! -f "$plugin_json" ] || [ ! -f "$market_json" ]; then
  bad "$plugin_json and $market_json must both exist"
elif ! jq empty "$plugin_json" 2>/dev/null; then
  bad "$plugin_json is not valid JSON"
elif ! jq empty "$market_json" 2>/dev/null; then
  bad "$market_json is not valid JSON"
else
  plugin_name="$(jq -r '.name // empty' "$plugin_json")"
  market_name="$(jq -r '.name // empty' "$market_json")"
  version="$(jq -r '.version // empty' "$plugin_json")"

  [ -n "$plugin_name" ] || bad "$plugin_json: no name"
  [ -n "$market_name" ] || bad "$market_json: no name"

  # Claude Code does not check the format. Semver is this repo's convention,
  # and the version rule below compares the string, so it has to be one.
  printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' \
    || bad "$plugin_json: version '$version' is not MAJOR.MINOR.PATCH"

  # One plugin, served from the repo root, under the manifest's own name. A
  # second entry or another source would install something other than this
  # tree.
  [ "$(jq '.plugins | length' "$market_json")" = 1 ] \
    || bad "$market_json: lists other than exactly one plugin"
  [ "$(jq -r '.plugins[0].name // empty' "$market_json")" = "$plugin_name" ] \
    || bad "$market_json: its plugin is not named $plugin_name, as $plugin_json says"
  [ "$(jq -r '.plugins[0].source // empty' "$market_json")" = ./ ] \
    || bad "$market_json: its plugin's source is not ./"
fi

# A change to what the plugin loads needs a new version. Claude Code keeps an
# install on the version it has until the string changes, so an edit without a
# bump never reaches anyone who installed the plugin from GitHub. plugin.json
# counts too, since it can declare hooks and servers inline. The base is
# origin/main unless CHECK_BASE names another ref.
loaded="skills hooks standards agents commands output-styles themes monitors workflows bin .mcp.json .lsp.json $plugin_json"
base="${CHECK_BASE:-origin/main}"
if [ -n "$version" ]; then
  if ! git rev-parse --verify -q "$base^{commit}" >/dev/null 2>&1; then
    warn "no $base to compare against, so the version rule was not checked"
  else
    mb="$(git merge-base HEAD "$base" 2>/dev/null || true)"
    # Before the base had a manifest there is no earlier version to compare.
    if [ -n "$mb" ] && git cat-file -e "$mb:$plugin_json" 2>/dev/null; then
      old="$(git show "$mb:$plugin_json" | jq -r '.version // empty')"
      # shellcheck disable=SC2086
      if ! git diff --quiet "$mb" -- $loaded ||
         [ -n "$(git ls-files --others --exclude-standard -- $loaded)" ]; then
        newer "$version" "$old" \
          || bad "$plugin_json: what the plugin loads changed since $base, so version $version must be newer than $old"
      fi
    fi
  fi
fi

# Inside the plugin a skill is reached as plugin:skill, and Claude Code does
# not resolve every bare name: a bare commit came back unknown with eng:commit
# installed. So every reference to a skill here, and every command a skill
# tells someone to type, uses the full name.
if [ -n "$plugin_name" ]; then
  while IFS= read -r ref; do
    [ -f "skills/$ref/SKILL.md" ] \
      || bad "a skill references $plugin_name:$ref, which is not a skill here"
  done < <(grep -rhoE "(^|[^a-z0-9-])$plugin_name:[a-z0-9-]+" skills --include='*.md' \
             | sed "s/^.*$plugin_name://" | sort -u)

  names="$(find skills -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | paste -sd'|' -)"
  # Inside backticks, quotes or plain prose alike. A path such as skills/why
  # has no space, quote or backtick before the slash, so it does not match.
  while IFS= read -r hit; do
    bad "$hit: types a skill by its bare name; write /$plugin_name:<name>"
  done < <(grep -rnE '(^|[[:space:]`("'"'"'])/('"$names"')([[:space:]`.,;:)"'"'"']|$)' skills --include='*.md' \
             | cut -d: -f1,2 | sort -u)
fi

# The link check and the dash sweep both take their file list from git, and an
# empty list is indistinguishable from a clean run. So this sits ahead of both
# rather than after them, where it would report a repository that was never
# read as a pass.
git rev-parse --git-dir >/dev/null 2>&1 \
  || bad "not a git repository, so the link check and the dash sweep read nothing"

# Every relative markdown link resolves, in the root files as well as the
# skills, because the root ones point at each other and nothing else catches a
# rename. A link inside a fenced code block is a template rather than a link,
# so the fence state is tracked and those are skipped.
while IFS=$'\t' read -r src link; do
  [ -f "$(dirname "$src")/$link" ] || bad "$src links $link, which does not exist"
done < <(
  markdown | while IFS= read -r f; do
    awk -v F="$f" '
      /^```/ { fence = !fence; next }
      {
        line = $0
        while (match(line, /\]\([^)]*\.md[^)]*\)/)) {
          L = substr(line, RSTART + 2, RLENGTH - 3)
          sub(/#.*$/, "", L)
          if (!fence && L !~ /^https?:/ && L != "") printf "%s\t%s\n", F, L
          line = substr(line, RSTART + RLENGTH)
        }
      }' "$f"
  done
)

# The two rules files carry one body in two frontmatter formats.
#
# `body` returns everything after the closing ---, so a file with an opening
# fence and no closing one yields nothing. Two such files compared equal and
# the whole check passed while the bodies shared not one line. Requiring the
# close, and a body with something in it, closes that.
claude_rule=.claude/rules/authoring-skills.md
cursor_rule=.cursor/rules/authoring-skills.mdc

for f in "$claude_rule" "$cursor_rule"; do
  if ! head -1 "$f" | grep -qx -- '---'; then
    bad "$f: no frontmatter, so its body cannot be compared"
  elif [ "$(sed -n '2,$p' "$f" | grep -cx -- '---')" -eq 0 ]; then
    bad "$f: frontmatter is never closed, so its body reads as empty"
  elif [ -z "$(body "$f")" ]; then
    bad "$f: body is empty, so comparing it proves nothing"
  fi
done

diff -q <(body "$claude_rule") <(body "$cursor_rule") >/dev/null \
  || bad "the .claude and .cursor rule bodies have drifted apart"

# Both rules files fire on skills/**, which AGENTS.md states as an invariant
# and nothing checked. Widening either one silently changes when the rule
# loads, which is the half of this pair that actually decides behaviour.
grep -q '^  - "skills/\*\*"$' "$claude_rule" \
  || bad "$claude_rule: paths no longer scopes it to skills/**"
grep -qx 'globs: skills/\*\*' "$cursor_rule" \
  || bad "$cursor_rule: globs no longer scopes it to skills/**"
grep -qx 'alwaysApply: false' "$cursor_rule" \
  || bad "$cursor_rule: alwaysApply is not false, so it loads in every session"

# link.sh, scripts/*.sh, tests/*/*.sh and evals/*/scaffold.sh parse as bash,
# and the plugin's hook as sh. This script embeds awk programs in single quotes, so an unbalanced
# apostrophe in a printed string ends the program and leaves a file that fails
# only when someone runs it, and nothing else here runs the others.
#
# `npm run lint` catches that too, and more of it: a balanced pair of
# apostrophes passes the parse below while leaving an awk program mangled,
# and shellcheck reports it. This check earns its place by needing only bash,
# because it runs before a commit, where fetching shellcheck over the network
# would not.
for f in link.sh scripts/*.sh tests/*/*.sh evals/*/scaffold.sh; do
  bash -n "$f" || bad "$f: does not parse"
done
sh -n hooks/eng-hook || bad "hooks/eng-hook: does not parse"

# The hook runs at every session start, and a broken one fails silently by
# design, so its fixtures run here as well as in CI. The script holds the
# 5,000-byte budget for the block it sends.
./scripts/test-hooks.sh >/dev/null || bad "scripts/test-hooks.sh failed; run it for the details"

# Every command block marked runnable actually runs. A block opts in with
# `bash checked` on its fence, because most blocks in this repo are templates
# carrying <placeholders> or commands with side effects, and running those
# would be worse than checking nothing.
#
# Each block runs from the repo root with stdin closed. A command that falls
# back to reading standard input then ends rather than waiting, which is the
# shape the xargs bug took: silent on BSD, a wait for input on GNU.
#
# A block is free to run check.sh. The variable below is set while blocks are
# running and skips this section when it is already set, so the inner run
# finishes instead of recursing. Matching the name in the block text would
# refuse a block that only mentions it, and README.md holds two that do.
if [ -z "${CHECK_SH_RUNNING_BLOCKS:-}" ]; then
  export CHECK_SH_RUNNING_BLOCKS=1
  blocks="$(mktemp -d)"
  trap 'rm -rf "$blocks"' EXIT

  while IFS= read -r f; do
    count="$(grep -c '^```bash checked$' "$f")"
    [ "$count" -gt 0 ] || continue

    i=1
    while [ "$i" -le "$count" ]; do
      awk -v want="$i" '
        /^```bash checked$/ { n++; if (n == want) inside = 1; next }
        /^```/ { if (inside) exit; next }
        inside { print }
      ' "$f" > "$blocks/block.sh"

      # Keep the output and replay it on failure. These blocks are the only
      # executable documentation here, and a bare block number says nothing
      # about which command failed or why.
      if ! bash -e "$blocks/block.sh" >"$blocks/out" 2>&1 </dev/null; then
        bad "$f: block $i is marked checked and exits non-zero"
        sed 's/^/      /' "$blocks/out" >&2
      fi

      i=$((i + 1))
    done
  done < <(tracked_markdown)

  rm -rf "$blocks"
  unset CHECK_SH_RUNNING_BLOCKS
fi

# Em dash, en dash, and minus sign. All three read as an em dash once rendered,
# so banning only the first leaves the tell in place.
#
# One -e per character rather than a bracket set. A bracket holding multi-byte
# characters is only character-wise in a UTF-8 locale; under LC_ALL=C it is a
# set of six bytes, and a curly quote, a bullet, and an ellipsis all share
# bytes with it. That reported a dash on a line holding none. A whole fixed
# string matches byte-wise in every locale.
#
# The three are written as byte escapes, so this script holds none of them and
# the sweep can cover every file the repo owns, scripts included.
em="$(printf '\342\200\224')"
en="$(printf '\342\200\223')"
minus="$(printf '\342\210\222')"
while IFS= read -r f; do
  lines="$(grep -n -F -e "$em" -e "$en" -e "$minus" "$f" | cut -d: -f1 | tr '\n' ' ')"
  [ -z "$lines" ] || bad "$f: dash on line ${lines% }"
done < <(git ls-files --cached --others --exclude-standard | present)

# Machine state, so it runs only when asked. A fresh runner has no Claude Code
# install, so CI would fail every run.
if [ "$doctor" = yes ] && [ -z "${HOME:-}" ] && [ -z "${CLAUDE_CONFIG_DIR:-}" ]; then
  bad "no \$HOME and no \$CLAUDE_CONFIG_DIR, so the install cannot be checked"
  doctor=skipped
fi

if [ "$doctor" = yes ]; then
  config="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  repo="$(pwd)"
  problems=0
  fix() { warn "$1"; problems=$((problems + 1)); }

  # Installed, enabled, and at the version this clone carries. Auto-update is
  # off for a marketplace outside Anthropic's, so a stale version is the
  # common case after a pull.
  id="$plugin_name@$market_name"
  if [ -z "$plugin_name" ] || [ -z "$market_name" ]; then
    fix "the manifests above could not be read, so the install cannot be checked"
  elif ! command -v claude >/dev/null 2>&1; then
    fix "claude is not on PATH, so the plugin install cannot be checked"
  elif ! command -v jq >/dev/null 2>&1; then
    fix "jq is not installed, so the plugin list cannot be read"
  else
    # The README's minimum. 2.1.292 closed a hole that let the model run a
    # user-invoked skill after compaction, and 2.1.293 is the first release
    # every plugin check here ran on, so nothing older is known to work.
    cc="$(claude --version 2>/dev/null | sed -nE 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -1)"
    if [ -z "$cc" ]; then
      fix "claude --version printed no version, so the 2.1.293 minimum cannot be checked"
    elif newer 2.1.293 "$cc"; then
      fix "Claude Code is $cc, and these skills need 2.1.293 or later. Run: claude update"
    fi

    # Listed from / rather than from this clone, so the enabled state is the
    # user-scope one and not what this repo's own project settings say. The
    # README installs at user scope, which is what loads in every project.
    if ! list="$(cd / && claude plugin list --json 2>/dev/null)" ||
       ! printf '%s' "$list" | jq -e 'type == "array"' >/dev/null 2>&1; then
      fix "claude plugin list --json failed or printed something other than a list, so the install cannot be checked"
    elif ! entry="$(printf '%s' "$list" | jq -c --arg id "$id" '.[] | select(.id == $id and .scope == "user")' | head -1)" ||
         [ -z "$entry" ]; then
      fix "$id is not installed at user scope. The README's Setup section has the two commands"
    else
      [ "$(printf '%s' "$entry" | jq -r '.enabled')" = true ] \
        || fix "$id is installed but disabled. Turn it on in /plugin"
      installed="$(printf '%s' "$entry" | jq -r '.version // empty')"
      [ "$installed" = "$version" ] \
        || fix "$id is at $installed and this clone is at $version. Update whichever is behind: claude plugin update $id, or git pull"
    fi
  fi

  # A personal skill with the same name as one of the plugin's loads beside
  # it, and two skills then claim one moment. That holds wherever it points:
  # a link into another clone of this repo loads just the same. A link into
  # this clone under any other name loads a second copy too, but link.sh did
  # not make it, so it is left for whoever did.
  skills_dir="$config/skills"
  # The names an older install linked, and how to resolve a link, both shared
  # with link.sh. Several of those names stop being folders here once skills
  # move, and a link left for one still loads.
  # shellcheck source=scripts/legacy.sh
  . scripts/legacy.sh
  if [ -d "$skills_dir" ]; then
    for entry_path in "$skills_dir"/*; do
      [ -e "$entry_path" ] || [ -L "$entry_path" ] || continue
      name="$(basename "$entry_path")"
      if [ -d "skills/$name" ] || legacy_name "$name"; then
        # A retired name has no plugin skill to sit beside, but a copy of it
        # still loads as a bare skill nobody maintains.
        what="$plugin_name:$name, and loads beside it"
        [ -d "skills/$name" ] || what="a skill the plugin retired, which can still load as a bare skill"
        if [ -L "$entry_path" ]; then
          fix "$skills_dir/$name is an old link to $(link_target "$entry_path" || readlink "$entry_path"), a copy of $what. Run ./link.sh --unlink from that clone, or remove it"
        else
          fix "$skills_dir/$name is a personal copy of $what"
        fi
      elif [ -L "$entry_path" ]; then
        case "$(link_target "$entry_path" || true)" in
          "$repo"/skills/*) fix "$skills_dir/$name links into this clone and loads a second copy of a skill. link.sh did not make it; remove it by hand" ;;
        esac
      fi
    done
  fi

  # The session hook fails open, so a broken one only shows in its log. Claude
  # Code names the data directory after the plugin id, with every character
  # other than a letter, a digit, _ or - turned into -.
  data_root="${CLAUDE_CODE_PLUGIN_CACHE_DIR:-$config/plugins}/data"
  hook_log="$data_root/$(printf '%s' "$id" | sed 's/[^A-Za-z0-9_-]/-/g')/eng-hook.log"
  if [ -s "$hook_log" ]; then
    fix "the session hook logged $(wc -l < "$hook_log" | tr -d ' ') error(s) in $hook_log, the latest: $(tail -1 "$hook_log"). Fix the cause, then delete the log"
  fi

  # The README's skillOverrides entry. Without it a bare commit or pr, from
  # Claude Code itself or from a project, can take a request meant for the
  # plugin's.
  settings="$config/settings.json"
  if [ -f "$settings" ] && ! jq empty "$settings" >/dev/null 2>&1; then
    fix "$settings is not valid JSON, so Claude Code cannot read it either"
  else
    for name in commit pr; do
      value=""
      [ -f "$settings" ] && value="$(jq -r --arg n "$name" '.skillOverrides[$n] // empty' "$settings" 2>/dev/null)"
      [ "$value" = off ] \
        || fix "$settings does not set skillOverrides.$name to \"off\", so a bare $name can load beside $plugin_name:$name"
    done
  fi

  # Anything to fix fails the run rather than printing a warning under an
  # `ok`, which also lets a hook or a script gate on it.
  if [ "$problems" -gt 0 ]; then
    printf 'doctor: %d to fix\n' "$problems"
    fail=1
  else
    printf 'doctor: %s %s is installed and enabled, with no bare copies beside it\n' "$id" "$version"
  fi
fi

printf '%d skills, %d model-invoked\n' "$(find skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "$model_count"
[ "$fail" -eq 0 ] && printf 'ok\n'
exit "$fail"
