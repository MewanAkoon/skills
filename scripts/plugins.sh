#!/usr/bin/env bash
# Lists the plugins running alongside these skills, and answers the parts of
# the test in PLUGINS.md that a machine can answer: what each plugin costs on
# every turn, what it lets an agent do without asking, and where it overlaps
# what is already here.
#
# The roster is read from the installed plugins rather than written down, for
# the same reason check.sh --doctor reads $HOME and fired.sh reads the
# transcripts. A list kept in a file is wrong by the next install. That also
# means this cannot run in CI, which has no plugins and no $HOME.
#
# What it cannot answer is whether two descriptions claim the same decision.
# That is the competition test in WRITING-RULES.md, and it needs a person.

set -uo pipefail

# Resolve through a symlink, so invoking this from a bin directory on PATH
# still finds the clone rather than the symlink's own directory.
SELF="$(readlink -f "$0")"
cd "$(dirname "$SELF")/.." || exit 1

for tool in claude jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '%s is not on PATH, so the installed plugins cannot be read\n' "$tool" >&2
    exit 1
  fi
done

roster="$(claude plugin list --json 2>/dev/null)"
if [ -z "$roster" ] || ! printf '%s' "$roster" | jq -e 'type == "array"' >/dev/null 2>&1; then
  printf 'claude plugin list --json returned nothing usable\n' >&2
  exit 1
fi

# One frontmatter field from a component file, empty when it carries none.
# Its first line only, so a folded YAML value reads short and the listing
# total below is a floor rather than an exact count.
field() {
  awk -v key="$2" '
    NR == 1 && $0 == "---" { inside = 1; next }
    inside && $0 == "---" { exit }
    inside {
      k = key ":"
      if (substr($0, 1, length(k)) == k) {
        v = substr($0, length(k) + 1)
        sub(/^[[:space:]]+/, "", v)
        sub(/[[:space:]]+$/, "", v)
        print v
        exit
      }
    }
  ' "$1"
}

# The skills in this repo, to match plugin component names against.
repo_skills=""
for dir in skills/*/; do
  repo_skills="$repo_skills $(basename "$dir")"
done

grants=""      # components that pre-approve tools
bounded=""     # agents that name a tool list, so they cannot exceed it
collisions=""  # component names that match a skill in this repo
undescribed="" # parts that widen reach while carrying no description
listing=0      # characters of name and description carried on every turn
components=0

plugins="$(printf '%s' "$roster" | jq '[.[] | select(.enabled)] | length')"
printf '%s plugins enabled\n' "$plugins"

# "id<tab>version<tab>scope<tab>installPath", enabled ones only.
while IFS=$'\t' read -r id version scope path; do
  [ -n "$id" ] || continue

  printf '\n  %s  %s  %s\n' "$id" "$version" "$scope"

  if [ ! -d "$path" ]; then
    printf '    install path is missing: %s\n' "$path"
    continue
  fi

  found=0

  # skills/<name>/SKILL.md, agents/<name>.md, commands/<name>.md. A file under
  # a skill's references/ is read on demand rather than listed, so the find is
  # depth-limited to the component itself.
  for kind in skill agent command; do
    case "$kind" in
      skill)   files=$(find "$path/skills" -mindepth 2 -maxdepth 2 -name 'SKILL.md' 2>/dev/null | sort) ;;
      agent)   files=$(find "$path/agents" -mindepth 1 -maxdepth 1 -name '*.md' 2>/dev/null | sort) ;;
      command) files=$(find "$path/commands" -mindepth 1 -maxdepth 1 -name '*.md' 2>/dev/null | sort) ;;
    esac

    while IFS= read -r file; do
      [ -n "$file" ] || continue
      found=$((found + 1))
      components=$((components + 1))

      if [ "$kind" = skill ]; then
        name="$(basename "$(dirname "$file")")"
      else
        name="$(basename "$file" .md)"
      fi

      description="$(field "$file" description)"
      allowed="$(field "$file" allowed-tools)"
      hidden="$(field "$file" disable-model-invocation)"

      note=""
      # A component the model cannot reach on its own is absent from the
      # listing, so it costs nothing until someone types it. Claude Code takes
      # any of these in any letter case, so the value is folded before the
      # comparison.
      case "$(printf '%s' "$hidden" | tr '[:upper:]' '[:lower:]')" in
        true|yes|on|1) note="  user-invoked" ;;
        *) listing=$((listing + ${#name} + ${#description})) ;;
      esac

      printf '    %-8s %s%s\n' "$kind" "$name" "$note"

      if [ -n "$allowed" ]; then
        printf '             grants %s\n' "$allowed"
        grants="$grants$id:$name -> $allowed"$'\n'
      fi

      # Only an agent's tools field restricts anything, so only an agent is
      # read for it. On a skill the field is not frontmatter Claude Code acts
      # on.
      if [ "$kind" = agent ]; then
        tools="$(field "$file" tools)"
        if [ -n "$tools" ]; then
          printf '             limited to %s\n' "$tools"
          bounded="$bounded$id:$name -> $tools"$'\n'
        fi
      fi

      # The quotes make the expansion literal, so a name is compared rather
      # than treated as a pattern.
      case " $repo_skills " in
        *" $name "*) collisions="$collisions$id:$name"$'\n' ;;
      esac
    done <<< "$files"
  done

  # An MCP server and a hooks directory carry no description, so they cost
  # nothing on a turn and never show up in a listing. Both widen what the
  # plugin can reach, and a hook runs without anyone invoking it, so they are
  # reported rather than only printed here.
  if [ -f "$path/.mcp.json" ]; then
    printf '    %-8s .mcp.json\n' "mcp"
    undescribed="$undescribed$id -> an MCP server"$'\n'
    found=$((found + 1))
    components=$((components + 1))
  fi
  if [ -d "$path/hooks" ]; then
    printf '    %-8s hooks/\n' "hooks"
    undescribed="$undescribed$id -> hooks, which run uninvoked"$'\n'
    found=$((found + 1))
    components=$((components + 1))
  fi

  # Says what was looked for rather than what the plugin does. A plugin can
  # still deliver something by another route, as an LSP integration does.
  if [ "$found" -eq 0 ]; then
    printf '    nothing under skills/, agents/, commands/, .mcp.json or hooks/\n'
  fi
done < <(printf '%s' "$roster" | jq -r '
  .[] | select(.enabled) | [.id, .version, .scope, .installPath] | @tsv
' | sort)

# Roughly four characters to the token. Close enough to weigh one plugin
# against another, which is all this number is for.
printf '\n%d components. %d characters of name and description ride every\n' \
  "$components" "$listing"
printf 'turn, near %d tokens.\n' "$((listing / 4))"

report() {
  if [ -z "$2" ]; then
    printf '\n%s: none\n' "$1"
  else
    printf '\n%s:\n' "$1"
    printf '%s' "$2" | sed 's/^/  /'
  fi
}

report 'Pre-approve tools for the turn that invokes them, so no prompt' "$grants"
report 'Reach further while carrying no description' "$undescribed"
report 'Bounded by a tool list, so they cannot exceed it' "$bounded"
report 'Share a name with a skill in this repo' "$collisions"

printf '\nPLUGINS.md holds the rest of the test, which needs a person.\n'
