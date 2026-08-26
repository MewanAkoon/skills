---
name: merge-conflicts
description: Use when git reports unmerged paths, after a merge, rebase, cherry-pick, revert, stash pop, or applied patch, or when the user says a pull left both versions inside a file. Resolves hunk by hunk by tracing each side to what it was trying to do, then finishes the operation.
---

# Merge conflicts

## What this does

It resolves an in-progress merge, rebase, cherry-pick, revert, stash pop, or
patch, one hunk at a time. Each side gets traced back to the change it came
from before anything is picked, so the resolution keeps both intents where
they fit together.

It also looks for the conflicts git cannot see: the two sides that merge
cleanly and still break each other.

## When it runs

Automatically, when `git status` reports unmerged paths.

Conflict markers inside a file git has not listed as unmerged are text, not a
conflict. Leave a parser fixture or a document about conflicts alone.

Skip it when the user says they are taking the conflict themselves, and when
every unmerged path is generated output. For a lockfile, take one side whole
and re-run install, so only the two branches' own dependency changes move:

```bash
git checkout --theirs pnpm-lock.yaml   # confirm which side that is, see step 1
pnpm install
```

## How to use it

Nothing to invoke. It says which step it is on, and it prints a line for
every hunk where the two sides contradicted each other.

---

## Step 1: See the state

```bash
git status
git diff --name-only --diff-filter=U
```

Say which operation is in progress and list the unmerged paths. Name the two
sides by branch, or by the stash entry for a stash pop.

`--ours` and `--theirs` swap between operations. In a merge, cherry-pick,
revert, and stash pop, `--ours` is where you already are. In a rebase,
`--ours` is the upstream being replayed onto and `--theirs` is your own
commit. Confirm against the commits before trusting either word.

**Done when:** the operation is named, the unmerged paths are listed, and
each side is tied to a real branch, commit, or stash entry.

## Step 2: Trace each side

The ref holding the other side depends on the operation, and `git log
--merge` fails outside a plain merge, so name the ref first:

```bash
OTHER=$(cat .git/MERGE_HEAD .git/REBASE_HEAD .git/CHERRY_PICK_HEAD 2>/dev/null | head -1)
# a stash pop has no such ref: the other side is stash@{0}

git log --oneline --left-right "HEAD...$OTHER" -- <file>
git log -p "HEAD...$OTHER" -- <file>
```

Where a commit subject carries a PR or an issue number, read it with
`gh pr view <n>` or `gh issue view <n>`.

**Done when:** for every unmerged path, you can say in one sentence what each
side was trying to do.

## Step 3: Resolve each hunk

Keep both intents where they compose. A rename on one side and a new call
site on the other compose: apply the rename to the new call site.

Where the two intents contradict each other, pick the one that matches the
goal of the operation being finished, and print one line saying what the
other side wanted and what picking this way gives up. Keep going after
printing it.

Every resolved hunk holds code from one side, from both sides, or the
smallest bridge needed to join them. New behaviour that appeared on neither
side goes in its own commit afterwards, so say it out loud rather than
folding it into the resolution.

One TypeScript case is worth handling on sight: two sides adding members to
the same union or the same interface almost always both belong.

**Done when:** `git diff --check` and `git diff --cached --check` are both
clean, `grep -n '^<<<<<<<\|^|||||||\|^>>>>>>>' <unmerged paths>` returns
nothing, and every contradicting hunk has its trade-off line on the record.

The staged check matters: rebase and cherry-pick stage the files they resolve
themselves, and `git diff --check` reports nothing for a staged file even
when the markers are still in it.

## Step 4: Find the semantic conflicts

Both sides can apply cleanly and still be wrong together. These are the cases
git has no way to flag:

- One side renamed a field or a type, the other side added code that reads
  the old name in a file that never conflicted.
- One side changed a function signature, the other side added callers.
- One side added a required field to a Mongoose schema, the other side added
  a path that creates documents without it, so writes throw `ValidationError`
  at runtime and nothing fails at compile time.
- One side changed an index or a unique constraint, the other side added
  writes the new constraint rejects.
- Both sides added a route, a queue consumer, or an event handler under the
  same name.

**Done when:** the symbols changed on either side are listed by name, each
one has its caller count on the record, and every caller outside the unmerged
paths has been opened.

## Step 5: Run the project's own checks

Find them rather than guessing: `package.json` scripts, the CI workflow
files, `turbo.json` or the workspace config. Run typecheck, then tests, then
lint and format.

Report each command and its exit code. Fix the failures this operation
caused. For a failure that was already red on both parent commits, say so and
leave it.

**Done when:** each check is listed with its exit code, and every failure
introduced by the operation is fixed.

## Step 6: Finish the operation

Stage the resolved files and continue:

```bash
git add <files>
git merge --continue    # or: rebase, cherry-pick, revert, am
```

A rebase stops again on the next commit. Repeat from step 1 until it runs
out.

A stash pop has no continue. Stage the resolved files, confirm the working
tree holds what you want, then drop the entry git kept:

```bash
git stash drop stash@{0}
```

Finish the operation rather than backing out of it. When the right move is
`--abort`, say why and wait for the user to answer.

**Done when:** `git status` reports no operation in progress and no unmerged
paths, and for a stash pop, `git stash list` no longer holds the entry that
produced the conflict.

---

Adapted from the `resolving-merge-conflicts` skill in mattpocock/skills
(MIT).
