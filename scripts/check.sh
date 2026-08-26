#!/usr/bin/env bash
# Checks every skill against the invariants in AGENTS.md.
# Needs only bash, awk, grep, and sed. Run before committing.

set -uo pipefail

cd "$(dirname "$0")/.."

MODEL_INVOKED_BUDGET=5

fail=0
bad() { printf 'FAIL  %s\n' "$1" >&2; fail=1; }

# Everything between the opening and closing --- of a markdown file.
frontmatter() {
  awk 'NR==1 && $0=="---" { inside=1; next } inside && $0=="---" { exit } inside' "$1"
}

# The README table rows under one heading, used to check where a skill is listed.
section() {
  sed -n "/^### $1\$/,/^#\{2,3\} /p" README.md
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
  [ -f "$yaml" ] && grep -q 'allow_implicit_invocation:[[:space:]]*false' "$yaml" && policied=yes

  if [ "$flagged" = yes ]; then
    # User-invoked: both halves of the pair, and a row under User-invoked.
    [ "$policied" = yes ] || bad "$name: user-invoked but $yaml is missing policy.allow_implicit_invocation: false"
    printf '%s\n' "$readme_user" | grep -q "](skills/$name/SKILL.md)" \
      || bad "$name: user-invoked but not listed under README '### User-invoked'"
  else
    # Model-invoked: neither half, and a row under Model-invoked.
    [ "$policied" = no ] || bad "$name: model-invoked but $yaml denies implicit invocation"
    printf '%s\n' "$readme_model" | grep -q "](skills/$name/SKILL.md)" \
      || bad "$name: model-invoked but not listed under README '### Model-invoked'"
    model_count=$((model_count + 1))
  fi
done

if [ "$model_count" -gt "$MODEL_INVOKED_BUDGET" ]; then
  bad "$model_count model-invoked skills, budget is $MODEL_INVOKED_BUDGET. Demote one before adding another."
fi

# Em dashes, in every markdown file the repo tracks.
while IFS= read -r f; do
  hits="$(grep -n '—' "$f" || true)"
  [ -n "$hits" ] && bad "$f: em dash on line ${hits%%:*}"
done < <(find . \( -name '*.md' -o -name '*.mdc' \) -not -path './.git/*')

if [ "$fail" -eq 0 ]; then
  printf 'ok  %d skills, %d model-invoked\n' "$(ls -d skills/*/ | wc -l | tr -d ' ')" "$model_count"
fi
exit "$fail"
