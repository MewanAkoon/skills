#!/usr/bin/env bash
# Checks this repo against the invariants in AGENTS.md.
# Needs bash and the usual POSIX tools. Run before committing.
#
# --doctor adds the one check CI cannot run, because a fresh runner has no
# ~/.claude to inspect: whether every skill here is currently linked into the
# directory link.sh writes to.

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

  description="$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -1)"
  if [ -z "$description" ]; then
    bad "$name: frontmatter has no description"
  elif [ "${#description}" -gt 1024 ]; then
    bad "$name: description is ${#description} characters, over the spec's 1024"
  fi

  # Cursor reads neither tools field, so a skill leaning on one is restricted
  # in Claude Code and wide open in Cursor. AGENTS.md allows it only as a
  # second lock over a body already right without it, and names `review-diff`
  # as the one that took the trade. Staying quiet about that one keeps this
  # warning meaning "someone added a second", which is the thing worth
  # noticing. A rename makes it speak up, which is the intent.
  if [ "$name" != review-diff ] &&
     printf '%s\n' "$fm" | grep -qE '^(allowed|disallowed)-tools:'; then
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
  fi
done

# Every README row points at a skill that exists.
while IFS= read -r linked; do
  [ -f "skills/$linked/SKILL.md" ] || bad "a README table row lists $linked, which has no skills/$linked/SKILL.md"
done < <(grep -o '](skills/[^/]*/SKILL\.md)' README.md | sed 's#](skills/##; s#/SKILL\.md)##' | sort -u)

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

# link.sh and scripts/*.sh parse as bash. fired.sh embeds an awk program in
# single quotes, so an unbalanced apostrophe in a printed string ends the
# program and leaves a file that fails only when someone runs it, and nothing
# else in this script runs them.
#
# `npm run lint` catches that too, and more of it: a balanced pair of
# apostrophes passes the parse below while leaving the awk program mangled,
# and shellcheck reports it. This check earns its place by needing only bash,
# because it runs before a commit, where fetching shellcheck over the network
# would not.
for f in link.sh scripts/*.sh; do
  bash -n "$f" || bad "$f: does not parse"
done

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
while IFS= read -r f; do
  lines="$(grep -n -e '—' -e '–' -e '−' "$f" | cut -d: -f1 | tr '\n' ' ')"
  [ -z "$lines" ] || bad "$f: dash on line ${lines% }"
done < <(markdown)

# Machine state, so it runs only when asked. A fresh runner has no ~/.claude,
# so CI would fail every run.
if [ "$doctor" = yes ]; then
  if [ -z "${HOME:-}" ] && [ -z "${SKILLS_DEST:-}" ]; then
    warn "no \$HOME and no \$SKILLS_DEST, so the link check cannot run"
    doctor=skipped
  fi
fi

if [ "$doctor" = yes ]; then
  # The same default and the same override link.sh uses, so the two agree on
  # where the links belong.
  dest="${SKILLS_DEST:-$HOME/.claude/skills}"
  repo="$(pwd)"
  missing=0
  ignored_count=0

  for dir in skills/*/; do
    name="$(basename "$dir")"
    link="$dest/$name"

    # A skill listed in .skillsignore is meant to be absent, so its absence is
    # the correct state rather than something to fix.
    if [ -f .skillsignore ] &&
       grep -qE "^[[:space:]]*${name}[[:space:]]*(#.*)?$" .skillsignore; then
      ignored_count=$((ignored_count + 1))
      continue
    fi

    if [ ! -L "$link" ]; then
      warn "$name is not linked into $dest"
      missing=$((missing + 1))
    elif [ "$(readlink "$link")" != "$repo/skills/$name" ]; then
      warn "$name in $dest points at $(readlink "$link")"
      missing=$((missing + 1))
    fi
  done

  # Links this repo made whose skill is gone. Every tool keeps listing them.
  if [ -d "$dest" ]; then
    for link in "$dest"/*; do
      [ -L "$link" ] || continue
      case "$(readlink "$link")" in
        "$repo"/skills/*)
          [ -e "$link" ] || { warn "$(basename "$link") in $dest points at a skill that is gone"; missing=$((missing + 1)); } ;;
      esac
    done
  fi

  if [ "$ignored_count" -gt 0 ]; then
    printf 'doctor: %d ignored by .skillsignore\n' "$ignored_count"
  fi

  # A missing link means the skills are not installed, so this fails the run
  # rather than printing a warning under an `ok`. That also lets a hook or a
  # script gate on it.
  if [ "$missing" -gt 0 ]; then
    printf 'doctor: %d to fix, run ./link.sh\n' "$missing"
    fail=1
  else
    printf 'doctor: every skill is linked into %s, which Cursor loads too\n' "$dest"
  fi
fi

printf '%d skills, %d model-invoked\n' "$(find skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "$model_count"
[ "$fail" -eq 0 ] && printf 'ok\n'
exit "$fail"
