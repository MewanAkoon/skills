#!/usr/bin/env bash
# Counts how often each skill in this repo has fired, so the pruning rule in
# WRITING-RULES.md has something to run against.
#
# Claude Code writes one JSONL transcript per session under ~/.claude/projects
# and records "skill":"<name>" when a skill is invoked, whether the user typed
# it or the model reached for it. This reads those.
#
# Two things it cannot see. Cursor keeps no comparable transcript, so its runs
# are missing. A skill also named in ~/.claude/CLAUDE.md gets followed without
# being invoked, so its count reads lower than its influence.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

TRANSCRIPTS="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"

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
  grep -rHoE '"skill":"[a-z0-9_-]+"' "$TRANSCRIPTS" --include='*.jsonl' 2>/dev/null
}

names=""
for dir in skills/*/; do
  names="$names $(basename "$dir")"
done

sessions="$(find "$TRANSCRIPTS" -name '*.jsonl' -type f | wc -l | tr -d ' ')"

printf 'Across %s Claude Code sessions in %s\n\n' "$sessions" "${TRANSCRIPTS/#$HOME/\~}"

awk -v skills="$names" '
  # First input: "date<tab>path". Splitting on the tab keeps a path holding
  # spaces intact.
  NR == FNR {
    i = index($0, "\t")
    if (i > 0) day[substr($0, i + 1)] = substr($0, 1, i - 1)
    next
  }

  # Second input: grep -H output, "path:<match>". The match always begins at
  # the first `:"skill":"`, so splitting there survives a path with a colon.
  {
    i = index($0, ":\"skill\":\"")
    if (i == 0) next
    path = substr($0, 1, i - 1)
    name = substr($0, i + 10)
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
        printf "%-18s %6d  %s\n", s, count[s], last[s]
      } else {
        printf "%-18s %6d  %s\n", s, 0, "never"
        never++
      }
    }

    printf "\n%d of %d have never fired.\n", never, total
    if (never > 0) {
      print "WRITING-RULES.md says to delete a skill that has not fired in two weeks."
      print "Check ./scripts/check.sh --doctor first: an unlinked skill cannot fire."
    }
  }
' <(dates) <(hits)
