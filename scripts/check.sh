#!/usr/bin/env bash
# Checks every skill against the invariants in AGENTS.md.
# Needs bash and the usual POSIX tools. Run before committing.
#
# --doctor adds the one check CI cannot run, because CI has no $HOME: whether
# every skill here is currently linked into the directory link.sh writes to.

set -uo pipefail

# Resolve through a symlink, so invoking this from a bin directory on PATH
# still finds the clone rather than the symlink's own directory.
SELF="$(readlink -f "$0")"
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
  git ls-files --cached --others --exclude-standard -- '*.md' '*.mdc'
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
  [ -f "skills/$linked/SKILL.md" ] || bad "README links skills/$linked/SKILL.md, which does not exist"
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
for f in .claude/rules/authoring-skills.md .cursor/rules/authoring-skills.mdc; do
  head -1 "$f" | grep -qx -- '---' || bad "$f: no frontmatter, so its body cannot be compared"
done
diff -q <(body .claude/rules/authoring-skills.md) <(body .cursor/rules/authoring-skills.mdc) >/dev/null \
  || bad "the .claude and .cursor rule bodies have drifted apart"

# Every command block marked runnable actually runs. A block opts in with
# `bash checked` on its fence, because most blocks in this repo are templates
# carrying <placeholders> or commands with side effects, and running those
# would be worse than checking nothing.
#
# Each block runs from the repo root with stdin closed. A command that falls
# back to reading standard input then ends rather than waiting, which is the
# shape the xargs bug took: silent on BSD, a wait for input on GNU.
blocks="$(mktemp -d)"
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

    # check.sh running check.sh runs forever, so a block naming it is a
    # marking mistake rather than something to execute.
    if grep -q 'check\.sh' "$blocks/block.sh"; then
      bad "$f: block $i is marked checked and names check.sh, which would recurse"
    elif ! bash -e "$blocks/block.sh" >/dev/null 2>&1 </dev/null; then
      bad "$f: block $i is marked checked and exits non-zero"
    fi

    i=$((i + 1))
  done
done < <(markdown)
rm -rf "$blocks"

# Em dash, en dash, and minus sign. All three read as an em dash once rendered,
# so banning only the first leaves the tell in place.
while IFS= read -r f; do
  lines="$(grep -n '[—–−]' "$f" | cut -d: -f1 | tr '\n' ' ')"
  [ -z "$lines" ] || bad "$f: dash on line ${lines% }"
done < <(markdown)

# Machine state, so it warns rather than failing, and only when asked. CI has
# no $HOME to check and would fail every run.
if [ "$doctor" = yes ]; then
  dest="$HOME/.claude/skills"
  repo="$(pwd)"
  missing=0

  for dir in skills/*/; do
    name="$(basename "$dir")"
    link="$dest/$name"
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

  if [ "$missing" -gt 0 ]; then
    printf 'doctor: %d to fix, run ./link.sh\n' "$missing"
  else
    printf 'doctor: every skill is linked into %s\n' "$dest"
  fi
fi

printf '%d skills, %d model-invoked\n' "$(find skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "$model_count"
[ "$fail" -eq 0 ] && printf 'ok\n'
exit "$fail"
