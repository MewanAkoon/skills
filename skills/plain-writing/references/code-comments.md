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
// The upstream rate limiter returns 429 for about a second after a burst,
// so two retries clears it and a third only adds latency.
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

## 5. Sweep before finishing

Grep the files you changed and fix every hit. Drop the marker and keep the
reason behind it.

```bash
grep -rniE "§|\.plan\.md|the .* review|round-[0-9]|\bPR-[0-9]|#[0-9]{3}" <paths>
```

End condition: both greps return nothing across the files you touched.
