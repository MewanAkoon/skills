#!/usr/bin/env bash
# Counts how often each skill in this repo has fired. Nothing acts on the
# count, and no skill is deleted for going unused. A zero is a question about
# that skill's description or its linking.
#
# Claude Code writes one JSONL transcript per session under ~/.claude/projects
# and records "skill":"<name>" when a skill is invoked, whether the user typed
# it or the model reached for it. This reads those.
#
# Two things it cannot see. Cursor keeps no comparable transcript, so its runs
# are missing. A skill also named in ~/.claude/CLAUDE.md gets followed without
# being invoked, so its count reads lower than its influence.

set -uo pipefail

# Resolve through a symlink, so invoking this from a bin directory on PATH
# still finds the clone rather than the symlink's own directory.
SELF="$(readlink -f "$0")"
cd "$(dirname "$SELF")/.." || exit 1

TRANSCRIPTS="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"

# ~/.claude/projects reads better than the absolute path, and $HOME is the
# only part worth shortening.
SHOWN="$TRANSCRIPTS"
case "$SHOWN" in "$HOME"/*) SHOWN="~${SHOWN#"$HOME"}" ;; esac

if [ ! -d "$TRANSCRIPTS" ]; then
  echo "no transcripts at $TRANSCRIPTS, so nothing to count" >&2
  exit 0
fi

# One "YYYY-MM-DD<tab>path" line per transcript, in one stat call rather than
# one per file. BSD first, GNU second, so this runs on macOS and on Linux. The
# date is formatted here because macOS awk has no strftime.
dates() {
  if find "$TRANSCRIPTS" -name '*.jsonl' -type f -exec stat -f '%Sm%t%N' -t '%Y-%m-%d' {} + 2>/dev/null; then
    return 0
  fi
  find "$TRANSCRIPTS" -name '*.jsonl' -type f -exec stat -c '%y%t%n' {} + 2>/dev/null \
    | sed 's/^\([0-9][0-9-]\{9\}\)[^	]*/\1/'
}

# Every skill invocation in every transcript, as "path:<match>". One pass over
# the tree rather than one pass per skill.
hits() {
  grep -rHoE '"skill":"[a-z0-9_-]+"' "$TRANSCRIPTS" --include='*.jsonl' 2>/dev/null || true
}

names=""
for dir in skills/*/; do
  names="$names $(basename "$dir")"
done

sessions="$(find "$TRANSCRIPTS" -name '*.jsonl' -type f | wc -l | tr -d ' ')"

printf 'Across %s Claude Code sessions in %s\n\n' "$sessions" "$SHOWN"

# One tagged stream rather than two inputs. The usual NR==FNR idiom decides
# which input a line came from by counting records, and when the first input is
# empty it reads every line of the second as though it belonged to the first.
# Here that would silently count no skill at all and report the whole set as
# never fired, which is a wrong answer nothing else would catch. A `stat` that
# does not support either format is enough to empty the date list, so the tag
# carries the answer instead of the record count.
{
  dates | sed 's/^/D /'
  hits | sed 's/^/H /'
} | awk -v skills="$names" '
  # "D <date><tab><path>". Splitting on the tab keeps a path holding spaces
  # intact.
  substr($0, 1, 2) == "D " {
    rest = substr($0, 3)
    i = index(rest, "\t")
    if (i > 0) day[substr(rest, i + 1)] = substr(rest, 1, i - 1)
    next
  }

  # "H <path>:<match>", from grep -H. The match always begins at the first
  # `:"skill":"`, so splitting there survives a path with a colon.
  {
    rest = substr($0, 3)
    i = index(rest, ":\"skill\":\"")
    if (i == 0) next
    path = substr(rest, 1, i - 1)
    name = substr(rest, i + 10)
    sub(/".*$/, "", name)

    count[name]++
    # ISO dates compare correctly as strings.
    if (day[path] > last[name]) last[name] = day[path]
  }

  END {
    printf "%-18s %6s  %s\n", "SKILL", "FIRED", "LAST"

    n = split(skills, want, " ")
    total = 0
    never = 0

    for (j = 1; j <= n; j++) {
      s = want[j]
      if (s == "") continue
      total++
      if (count[s] > 0) {
        # Blank when the date list came back empty, which the tag above keeps
        # from costing the count itself.
        printf "%-18s %6d  %s\n", s, count[s], last[s] ? last[s] : "unknown"
      } else {
        printf "%-18s %6d  %s\n", s, 0, "never"
        never++
      }
    }

    printf "\n%d of %d have never fired.\n", never, total
    if (never > 0) {
      print "A zero is a question about the description or the linking."
      print "Check ./scripts/check.sh --doctor first: an unlinked skill cannot fire."
    }
  }
'
