#!/usr/bin/env bash
# Runs two of the repo's own checks against scratch inputs: the version rule
# in scripts/check.sh, in scratch repos holding only what the rule reads, and
# the finding count in scripts/validate-plugin.sh, against a stand-in claude
# that prints canned output. Both fail quietly when they go wrong, by
# skipping a rule or by reading no finding, so a passing run of either says
# nothing on its own.
# Needs bash, jq, git, and the usual POSIX tools. check.sh runs it.

set -uo pipefail

SELF="$(readlink -f "$0" 2>/dev/null || true)"
[ -n "$SELF" ] || { printf 'error: readlink -f cannot resolve %s\n' "$0" >&2; exit 1; }
cd "$(dirname "$SELF")/.." || exit 1

fail=0
bad() { printf 'FAIL  %s\n' "$1" >&2; fail=1; }

scratch="$(mktemp -d)" && [ -n "$scratch" ] || { bad "mktemp -d failed"; exit 1; }
trap 'rm -rf "$scratch"' EXIT

# The version rule.
#
# Each case builds a repo with check.sh, both manifests and one skill,
# commits it as the base, changes something, and runs check.sh with
# CHECK_BASE at that commit. The tree fails most other checks on purpose, so
# a case reads only whether the version rule's message appears. The tree has
# no test scripts, so check.sh does not run this one again.
rule='so version [0-9.]* must be newer than'
n=0

# base <manifest path> <version>: a new scratch repo, committed, with its path
# in $repo.
base() {
  n=$((n + 1))
  repo="$scratch/repo$n"
  mkdir -p "$repo/scripts" "$repo/.claude-plugin" "$repo/plugins/eng/skills/x" "$repo/plugins/eng/evals/x"
  cp scripts/check.sh "$repo/scripts/"
  cp .claude-plugin/marketplace.json "$repo/.claude-plugin/"
  jq --arg v "$2" '.version = $v' plugins/eng/.claude-plugin/plugin.json > "$scratch/plugin.json"
  mkdir -p "$repo/$(dirname "$1")"
  cp "$scratch/plugin.json" "$repo/$1"
  printf -- '---\nname: x\n---\none\n' > "$repo/plugins/eng/skills/x/SKILL.md"
  printf 'case\n' > "$repo/plugins/eng/evals/x/prompt.md"
  printf 'readme\n' > "$repo/README.md"
  git -C "$repo" init -q
  git -C "$repo" add -A
  git -C "$repo" -c user.name=t -c user.email=t@t commit -qm base
}

# at <version>: the head's manifest, at the new path, set to that version.
at() {
  jq --arg v "$1" '.version = $v' plugins/eng/.claude-plugin/plugin.json > "$scratch/plugin.json"
  mkdir -p "$repo/plugins/eng/.claude-plugin"
  cp "$scratch/plugin.json" "$repo/plugins/eng/.claude-plugin/plugin.json"
}

# expect <fires|quiet> <case name>: run check.sh and read the rule's message.
expect() {
  out="$(cd "$repo" && CHECK_BASE="$(git rev-parse HEAD)" ./scripts/check.sh 2>&1)"
  if printf '%s\n' "$out" | grep -q "$rule"; then
    [ "$1" = fires ] || bad "version rule: $2: asked for a bump"
  else
    [ "$1" = quiet ] || bad "version rule: $2: asked for no bump"
  fi
}

base plugins/eng/.claude-plugin/plugin.json 0.15.0
printf 'two\n' >> "$repo/plugins/eng/skills/x/SKILL.md"
expect fires "a changed skill, same version"

base plugins/eng/.claude-plugin/plugin.json 0.15.0
printf 'new\n' > "$repo/plugins/eng/skills/x/new.md"
expect fires "a new untracked file in a skill, same version"

base plugins/eng/.claude-plugin/plugin.json 0.15.0
printf 'icon\n' > "$repo/plugins/eng/.claude-plugin/icon.png"
expect fires "a new icon, same version"

base plugins/eng/.claude-plugin/plugin.json 0.15.0
printf 'two\n' >> "$repo/plugins/eng/skills/x/SKILL.md"
at 0.15.1
expect quiet "a changed skill, version bumped"

base plugins/eng/.claude-plugin/plugin.json 0.15.0
printf 'two\n' >> "$repo/README.md"
expect quiet "a root file only"

base plugins/eng/.claude-plugin/plugin.json 0.15.0
printf 'two\n' >> "$repo/plugins/eng/evals/x/prompt.md"
expect quiet "an eval only"

# A base from before the move, with the manifest at the repo root.
base .claude-plugin/plugin.json 0.14.0
at 0.14.0
expect fires "a base with the manifest at the old path, same version"

base .claude-plugin/plugin.json 0.14.0
at 0.15.0
expect quiet "a base with the manifest at the old path, version bumped"

# The wrapper's count.
#
# The stand-in prints $STUB_OUT and exits $STUB_STATUS for both of the
# wrapper's runs.
stub="$scratch/claude"
cat > "$stub" <<'STUB'
#!/bin/sh
printf '%s\n' "$STUB_OUT"
exit "${STUB_STATUS:-0}"
STUB
chmod +x "$stub"

# wrapper <ok|fails> <case name> <output> [status]
wrapper() {
  if CLAUDE_BIN="$stub" STUB_OUT="$3" STUB_STATUS="${4:-0}" ./scripts/validate-plugin.sh >/dev/null 2>&1; then
    [ "$1" = ok ] || bad "validate-plugin: $2: passed"
  else
    [ "$1" = fails ] || bad "validate-plugin: $2: failed"
  fi
}

passed='✔ Validation passed'
wrapper ok "a clean run" "$passed"
wrapper ok "a clean run with the plugin directory checks" \
  "$(printf '✔ These checks found nothing to report\n\n%s' "$passed")"
wrapper fails "a warning" "$(printf '⚠ Found 1 warning:\n\n  ❯ CLAUDE.md: x\n\n%s' "$passed")"
wrapper fails "a plugin directory warning" \
  "$(printf '⚠ Found 1 plugin directory warning:\n\n  ❯ icon: x\n\n%s' "$passed")"
wrapper fails "a problem the plugin directory refuses" \
  "$(printf '✘ Found 1 problem the plugin directory refuses a submission for:\n\n  ❯ x\n\n%s' "$passed")"
wrapper fails "an error and two warnings" "$(printf '✘ Found 1 error and 2 warnings:\n\n%s' "$passed")"
wrapper fails "a finding with no count" "$(printf '⚠ warning: x\n\n%s' "$passed")"
wrapper fails "a run that exits non-zero" "$passed" 1

[ "$fail" -eq 0 ] && printf 'checks: ok\n'
exit "$fail"
