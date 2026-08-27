# Local Markdown tracker

## Layout

```
.scratch/<slug>/
  map.md
  tickets/
    01-name-the-storage-shape.md
    02-pick-the-retry-window.md
  assets/
    02-retry-prototype.ts
```

`<slug>` is the effort in two or three words, hyphenated. Ticket numbers are
two digits, assigned in creation order, and never reused. An asset created
while resolving a ticket goes in `assets/` and is linked from the ticket
file, not pasted into it.

## Map template

```markdown
# <Effort name>

## Destination

<What reaching the end of this map looks like: the spec, the decision, or the
change this effort is finding its way to. One or two lines.>

## Notes

<Domain context. Skills every session on this map should use. Standing
preferences for this effort.>

## Decisions so far

- [<Closed ticket title>](tickets/01-name-the-storage-shape.md): <one line of
  gist, enough to judge whether to open the ticket for the detail>

## Not yet specified

- <A question you can see coming and cannot yet state sharply. Delete the
  line when it graduates into a ticket.>

## Out of scope

- <Work ruled past the destination, and why. Link the closed ticket when
  there was one.>
```

## Ticket template

```markdown
# 02: <Ticket title, the question in a few words>

**Type:** research | prototype | grilling | task
**Status:** open
**Blocked by:** 01
**Claimed:** none

## Question

<The decision this ticket resolves, in a few sentences.>
```

`**Type:**` fixes who resolves the ticket: research runs afk, prototype and
grilling run hitl, and an hitl ticket resolves only with the human answering
in person. A task ticket adds `**Driver:** hitl` or `**Driver:** afk`,
because it is the one type that goes either way.

`**Blocked by:**` holds ticket numbers separated by commas, or `none`.
`**Claimed:**` holds `none` until a session takes it, then the date and who
is driving, such as `2026-08-26 mewan`.

## Resolution

Editing a ticket on resolution:

1. Set `**Status:** closed`.
2. Append an `## Answer` section: the decision, the reasoning in a few lines,
   and links to any assets.
3. Add one line to the map's "decisions so far" pointing at the file.

```markdown
## Answer

<The decision. What was chosen, what it rules out, and the one fact that
decided it.>

Assets: [retry prototype](../assets/02-retry-prototype.ts)
```

## Finding the takeable tickets

Run from `.scratch/<slug>/tickets`:

```bash
for f in *.md; do
  grep -q '^\*\*Status:\*\* open' "$f" || continue
  grep -q '^\*\*Claimed:\*\* none' "$f" || continue
  takeable=yes
  for b in $(sed -n 's/^\*\*Blocked by:\*\* //p' "$f" | tr ',' ' '); do
    [ "$b" = "none" ] && continue
    blocker=$(find . -maxdepth 1 -name "$b-*.md" -print -quit)
    if [ -z "$blocker" ]; then
      echo "$f: blocked by ticket $b, which does not exist"
      takeable=no
      continue
    fi
    grep -q '^\*\*Status:\*\* closed' "$blocker" || takeable=no
  done
  if [ "$takeable" = yes ]; then head -1 "$f"; fi
done
```

It prints the title line of every takeable ticket, and a line for any ticket
pointing at a blocker that was deleted. `find` does the existence test rather
than a bare glob, because zsh fails an unmatched glob before the command runs
and prints its own error that a redirect cannot swallow. An empty result with open tickets
left means all of them are blocked or claimed, so the next move is to finish
a blocker.

## Concurrency

Two sessions can work one map at the same time. Write the claim line before
doing any work, and re-read `map.md` before appending to it, because the
other session may have appended since you loaded it.
