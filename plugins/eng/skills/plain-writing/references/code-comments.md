# Code comments

Read this before writing or editing a comment in source code. The rest of
`SKILL.md` still applies to the sentence itself. These five checks decide
whether the comment should exist and whether it will still make sense to
someone reading it in a year.

## 1. Why, not what

A comment earns its place by adding a reason, a trade-off, an invariant, or a
gotcha that the code cannot state on its own.

```ts
// Retry twice before giving up.
await retry(fetchUser, 2);
```

The line above restates the call, so delete it. This one carries something
the code does not:

```ts
// Upstream returns 429 for about a second after a burst; two retries clear it.
await retry(fetchUser, 2);
```

## 2. Every reference resolves in the repo

Point only at things a reader can open from a fresh clone: a code symbol, a
repo-relative path, a file under `docs/`, a nested `CLAUDE.md`, or an
external URL that will still be there next year.

A reference to a planning document, a design doc, a chat thread, a section
number like `§3.2`, or any file the repo does not track is a dead end for
everyone except the person who wrote it. That includes agent scratch
directories, which are gitignored by design and vanish with the session.

When the reason lives in one of those, do one of two things. Inline a
one-line version of the reason in the comment, or move the document into
`docs/`, commit it, and link that.

## 3. Timeless

Write for someone who has no idea when the line was added. Leave out PR
numbers, review rounds, ticket ids, and the words "recently", "now", "new",
"currently", and "we just changed".

```ts
// Changed in the round-3 review: we now clamp this.
```

Nobody reading that later knows which review, or what it did before. Write
what is true instead:

```ts
// Values above 1000 overflow the downstream counter, so clamp here.
```

## 4. Proportional

Comment density tracks how surprising the code is. Dense, load-bearing logic
carries more. Plain glue code carries none.

Keep the comment next to the line it explains. A block at the top of the file
explaining something 200 lines down will not be updated when that code moves.

Length follows the position. A doc comment on an exported symbol runs as long
as its content earns, because a contract, an invariant, or where each field
comes from is what the caller cannot see. A comment inside a body stays at one
line. Anything longer is a paragraph the reader holds in their head while
parsing the code under it.

## 5. Sweep before finishing

Grep the files you changed and read every hit. The pattern over-matches on
purpose, so a CSS value like `#404` or a sentence about a design review will
turn up alongside real leakage. Where the hit points at something a reader
cannot open, drop the marker and keep the reason behind it. Where it does not,
leave the line alone.

```bash
git diff -z --name-only --diff-filter=d HEAD \
  | xargs -0 -r grep -HnIiE \
    "§|\.plan\.md|the .* review|round-[0-9]|\bPR-[0-9]|#[0-9]{3}"
```

`git diff HEAD` covers the tracked files you edited. `--diff-filter=d` drops
the ones you deleted so grep is never handed a path that no longer exists. The
`-z` and `-0` pair carries filenames with spaces through intact, `-H` prints
the file name even when xargs hands grep a single path, `-I` skips binaries,
and `-r` stays quiet when there is nothing to grep.

A new file this change created is untracked, so that command misses it. List
the untracked paths with `git ls-files --others --exclude-standard`, keep only
the ones this change created, and pass those to the same `grep -HnIiE` by
name. The list also holds scratch files the change never touched, which is
why you pick from it by hand rather than sweeping all of it.

Leave the index alone. `eng:commit` reads what is staged as the group the user
chose, so staging here decides the commit before anyone asked for one.

Pass the paths by name too when the comments are already committed.

**Done when:** every edited file and every new file this change created was
handed to grep, every hit has been read, and no comment in the files you
touched still points at something outside the repo.
