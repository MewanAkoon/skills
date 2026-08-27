#!/usr/bin/env bash
# Checks every skill against the invariants in AGENTS.md.
# Needs bash and the usual POSIX tools. Run before committing.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

fail=0
bad() { printf 'FAIL  %s\n' "$1" >&2; fail=1; }

# Everything between the opening and closing --- of a markdown file.
frontmatter() {
  awk 'NR==1 && $0=="---" { inside=1; next } inside && $0=="---" { exit } inside' "$1"
}

# Everything after the frontmatter.
body() {
  awk 'NR==1 && $0=="---" { inside=1; next } inside && $0=="---" { inside=0; started=1; next } started' "$1"
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

  if ! printf '%s\n' "$fm" | grep -q '^description:[[:space:]]*[^[:space:]]'; then
    bad "$name: frontmatter has no description"
  fi

  yaml="${dir}agents/openai.yaml"
  flagged=no
  printf '%s\n' "$fm" | grep -q '^disable-model-invocation:[[:space:]]*true[[:space:]]*$' && flagged=yes
  policied=no
  denied=no
  [ -f "$yaml" ] && grep -q '^[[:space:]]*allow_implicit_invocation:' "$yaml" && policied=yes
  [ -f "$yaml" ] && awk '/^policy:[[:space:]]*$/ { inside=1; next }
                          /^[^[:space:]#]/ { inside=0 }
                          inside && /^[[:space:]]+allow_implicit_invocation:[[:space:]]*false[[:space:]]*$/ { found=1 }
                          END { exit !found }' "$yaml" && denied=yes

  if [ "$flagged" = no ] && printf '%s\n' "$fm" | grep -q '^disable-model-invocation:'; then
    bad "$name: model-invoked but frontmatter still carries disable-model-invocation"
  fi

  if [ "$flagged" = yes ]; then
    # User-invoked: both halves of the pair, a row under User-invoked, none under the other.
    [ "$denied" = yes ] || bad "$name: user-invoked but $yaml is missing policy.allow_implicit_invocation: false"
    row_in "$readme_user" "$name" \
      || bad "$name: user-invoked but not listed under README '### User-invoked'"
    row_in "$readme_model" "$name" \
      && bad "$name: user-invoked but also listed under README '### Model-invoked'"
  else
    # Model-invoked: neither half, a row under Model-invoked, none under the other.
    [ "$policied" = no ] || bad "$name: model-invoked but $yaml carries a policy block"
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

# The two rules files carry one body in two frontmatter formats.
for f in .claude/rules/authoring-skills.md .cursor/rules/authoring-skills.mdc; do
  head -1 "$f" | grep -qx -- '---' || bad "$f: no frontmatter, so its body cannot be compared"
done
diff -q <(body .claude/rules/authoring-skills.md) <(body .cursor/rules/authoring-skills.mdc) >/dev/null \
  || bad "the .claude and .cursor rule bodies have drifted apart"

git rev-parse --git-dir >/dev/null 2>&1 \
  || bad "not a git repository, so the em dash sweep did not run"

# Em dashes. git supplies the file list, so .gitignore decides what is ours
# and an unstaged new skill still gets checked.
while IFS= read -r f; do
  lines="$(grep -n '—' "$f" | cut -d: -f1 | tr '\n' ' ')"
  [ -z "$lines" ] || bad "$f: em dash on line ${lines% }"
done < <(git ls-files --cached --others --exclude-standard -- '*.md' '*.mdc' 2>/dev/null)

printf '%d skills, %d model-invoked\n' "$(ls -d skills/*/ | wc -l | tr -d ' ')" "$model_count"
[ "$fail" -eq 0 ] && printf 'ok\n'
exit "$fail"
