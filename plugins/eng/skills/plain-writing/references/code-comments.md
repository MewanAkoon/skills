# Code comments

Two checks decide whether a comment stays. `SKILL.md` still governs the
sentence itself.

## 1. It says why

A comment adds a reason, a trade-off, an invariant or a gotcha the code
cannot state. `// Retry twice` over `retry(fetchUser, 2)` restates the call
and goes. `// Upstream returns 429 for about a second after a burst; two
retries clear it` stays. A comment inside a body is one line. A doc comment
on an exported symbol runs as long as its contract needs.

## 2. It resolves from a fresh clone, and stays true

Point only at what a reader can open from a clone: a symbol, a repo path, a
file under `docs/`, a URL that will last. A planning doc, a chat thread, a
section number like `§3.2`, an agent scratch directory or any untracked file
is a dead end, so inline a one-line version of the reason instead. Leave out
PR numbers, review rounds, ticket ids, and "recently", "now", "new" or
"currently". Write what is true: `// Values above 1000 overflow the
downstream counter, so clamp here.`

Before finishing, sweep the files you changed and read every hit. The pattern
over-matches on purpose.

```bash
git diff -z --name-only --diff-filter=d HEAD \
  | xargs -0 -r grep -HnIiE \
    "§|\.plan\.md|the .* review|round-[0-9]|\bPR-[0-9]|#[0-9]{3}"
```

That misses files this change created, which are untracked. Pick those by
hand from `git ls-files --others --exclude-standard` and pass them to the same
grep by name. Leave the index alone, because `eng:commit` reads what is staged
as the user's chosen group.

**Done when:** every edited and every new file went through the grep, every
hit was read, and no comment in them points outside the repo.
