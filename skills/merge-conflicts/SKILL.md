---
name: merge-conflicts
description: Use when git reports unmerged paths or conflict markers after a merge, rebase, cherry-pick, revert, stash pop, pull, or applied patch, and the user's latest message asks to resolve them, reports them, or asks for that operation. Resolves hunk by hunk by tracing each side's intent, then finishes it.
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

When `git status` reports unmerged paths, or an operation is paused with every
conflict already resolved and staged, and the user's latest message asks to
resolve them, reports them, as "the merge left conflicts" does, or asks for
the operation that produced them. An earlier message does not carry forward,
because step 6 writes a commit. Otherwise, such as a rebase left half done
before a request to investigate or review, report the operation and the
unmerged paths and wait for the user.

Two states skip ahead. With nothing left unmerged, record a stash pop's entry
as step 2 says, run step 3's marker checks over the staged paths, then go to
step 6. When every unmerged path is generated output, run step 1, record a
stash pop's entry, regenerate each path as step 3 says, then go to step 5.

Conflict markers inside a file git has not listed as unmerged are text, not a
conflict. Leave a parser fixture or a document about conflicts alone.

Skip it when the user says they are taking the conflict themselves.

## How to use it

Nothing to invoke. It prints a line for every hunk where the two sides
contradicted each other.

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

**Done when:** the operation is named, or recorded as none for a bare
`git apply --3way`, the unmerged paths are listed, and each side is tied to a
real branch, commit, stash entry, or patch file.

## Step 2: Trace each side

The ref holding the other side depends on the operation, and `git log
--merge` fails for a stash pop, `git am`, `git apply --3way`, and on git
before 2.45, so name the ref first. Read only the ref for the operation
step 1 named, `MERGE_HEAD`, `REBASE_HEAD`, `CHERRY_PICK_HEAD`, or
`REVERT_HEAD`, because a finished rebase can leave a stale `REBASE_HEAD`
behind that would mask the others:

```bash
cat "$(git rev-parse --git-dir)/<REF>"
# a stash pop has no such ref: the other side is the stash entry, by SHA
```

Ask git for the directory rather than writing `.git/` by hand. In a linked
worktree `.git` is a file, so every hardcoded path under it fails.

`$OTHER` below stands for the SHA that prints. Write it into each command
yourself, because a shell variable set in one command does not survive into
the next one. Empty output means all four reads failed, and `HEAD...` with
nothing after it compares HEAD to itself and prints nothing at all. Stop there
and name the operation from step 1, unless it is one of the three that keep no
such ref.

For a merge or a rebase, read the history on both sides:

```bash
git log --oneline --left-right "HEAD...$OTHER" -- <file>
git log -p "HEAD...$OTHER" -- <file>
```

For a cherry-pick or a revert, read the one commit instead. The range would
pull in the source branch's history for a cherry-pick, and for a revert it
leaves out the commit being undone. A revert's other side is the inverse of
what this prints:

```bash
git show $OTHER -- <file>
```

A stash pop is the first of the three that keep no such ref. Its other side is
the entry git kept, and the stash stack is shared by every worktree of the
repo, so another session's push can move it off `stash@{0}`. Record it by SHA
as soon as the run starts, and check its message is the work that was popped.
When it is not, ask the user which entry it was. Then read the other side from
that SHA:

```bash
git stash list -1 --format='%H %gs'
git stash show -p <sha>
```

An applied patch is the second and the third, because neither `git am` nor
`git apply --3way` records a commit to compare against. In both the other
side is the patch. `git am` keeps a copy, so read it from there and carry on
to step 3:

```bash
cat "$(git rev-parse --git-dir)"/rebase-apply/info     # author, subject, date
cat "$(git rev-parse --git-dir)"/rebase-apply/patch    # what it changes
```

`git apply --3way` keeps no copy and starts no operation, so `git status`
names none. Ask the user which patch file they applied, read that, and say on
the record that the other side came from the user rather than from git.

Where a commit subject carries a PR or an issue number, read it with
`gh pr view <n>` or `gh issue view <n>`.

**Done when:** the other side has been read from `$OTHER` as a real commit,
over the range for a merge or a rebase and with `git show` for a cherry-pick
or a revert, or from the recorded stash SHA or the patch for the three that
keep no such ref, and for every unmerged path you can say in one sentence what
each side was trying to do, or the run has stopped with its reason named,
which is an empty `$OTHER` for an operation that should keep a ref, a stash
entry the user has to name, or a bare `git apply --3way` waiting on the user
to name the patch file.

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

Regenerate a lockfile or other generated output rather than merging it by
hand. First resolve any conflict in the manifest it comes from, such as
`package.json`, hunk by hunk like any other file, because the install reads
it. Then take one side of the lockfile whole and re-run the install or the
generator, so only the two branches' own dependency changes move.

Read the lockfile and the install command off the repo rather than assuming
either. Whichever lockfile is the unmerged path names the tool: `pnpm-lock.yaml`
is pnpm, `package-lock.json` npm, `yarn.lock` yarn, `go.sum` `go mod tidy`,
`Cargo.lock` cargo, `poetry.lock` poetry, `Gemfile.lock` bundler. The shape is
the same in each:

```bash
git checkout --theirs <lockfile>   # confirm which side that is, see step 1
<the project's install command>
git add <lockfile>
```

The `git add` is the part that finishes it. `git checkout --theirs` writes the
file but leaves the path unmerged, so without it `git merge --continue`
refuses with "Committing is not possible because you have unmerged files".

Then check the paths step 1 listed for leftover markers:

```bash
git diff --check -- <unmerged paths> | grep 'leftover conflict marker'
git diff --cached --check -- <unmerged paths> | grep 'leftover conflict marker'
grep -n '^<<<<<<<\|^|||||||\|^>>>>>>>' <unmerged paths>
```

The checks name those paths and keep only the marker lines, because in a merge
the staged diff also carries everything the other branch brings, and trailing
whitespace there would fail an unfiltered check.

**Done when:** all three commands print nothing, every contradicting hunk has
its trade-off line on the record, and every generated path has been
regenerated and staged.

The staged check matters: rebase and cherry-pick stage the files they resolve
themselves, and `git diff --check` reports nothing for a staged file even
when the markers are still in it.

## Step 4: Find the semantic conflicts

Both sides can apply cleanly and still be wrong together. These are the cases
git has no way to flag:

- One side renamed a field or a type, the other side added code that reads
  the old name in a file that never conflicted.
- One side changed a function signature, the other side added callers.
- One side added a required field to a schema or a model, the other side
  added a path that writes records without it, so the writes fail at runtime
  and nothing fails at compile time.
- One side changed an index or a unique constraint, the other side added
  writes the new constraint rejects.
- Both sides added a route, a queue consumer, or an event handler under the
  same name.

Past 20 callers for one symbol, open the ones under the directories this
operation touched and record how many you left unopened.

**Done when:** every symbol either side changed is listed by name with its
caller count, and every caller outside the unmerged paths is either opened or
counted under the 20-caller rule, or the record says neither side changed a
symbol.

## Step 5: Run the project's own checks

Find them rather than guessing: `package.json` scripts, the CI workflow
files, `turbo.json` or the workspace config. Run typecheck, then tests, then
lint and format in the mode that reports without writing, such as
`prettier --check`. A formatter that writes touches files neither side
changed. A rebase's continue then refuses with "You must edit all merge
conflicts", and a merge's commits without them and leaves them behind.

Record that this repo defines no such checks when the search turns up none,
and carry on to step 6. A repo of prose or config often has nothing to run,
and that is an answer rather than a blocked step.

Report each command and its exit code. Fix the failures this operation
caused. For a failure that was already red on both parent commits, say so and
leave it.

**Done when:** each check is listed with its exit code and every failure the
operation introduced is fixed, or the record says this repo defines no checks,
or a failure resisted the fix and the run has stopped with that command, its
output, and what was tried on the record.

## Step 6: Finish the operation

Stage the resolved files and continue:

```bash
git add <files>
GIT_EDITOR=true git merge --continue    # or: rebase, cherry-pick, revert, am
```

`GIT_EDITOR=true` makes each `--continue` keep the message git already
prepared. Without it, a merge or rebase continue opens an editor for the
message: in a shell with no `TERM` and no editor set it fails with "Terminal
is dumb, but EDITOR unset", and otherwise git waits for an editor nobody will
close. Cherry-pick and revert skip the editor when no terminal is attached,
and the prefix costs them nothing. The `eng:commit` skill stays out of those
paths. A rebase or a cherry-pick needs its own continue rather than a fresh
`git commit`.

A merge, cherry-pick, or revert continue runs the repo's pre-commit and
commit-msg hooks, and an am continue runs pre-applypatch, so record
`git status --porcelain -uall` before running it. A hook that exits non-zero
prints its output and leaves the operation paused. Handle that as the first
three cases of the `eng:commit` skill's `references/hooks.md` describe, with the
recorded status as its snapshot and one more continue as its retry, and run
none of that skill's other steps. A hook that passes can still rewrite files:
compare `git status --porcelain -uall` after the continue with the recorded
one, leave any path the hook changed unstaged, and name it in the report,
because committing it is a separate request.

A rebase stops again on the next commit. Repeat from step 1 until it runs
out.

A bare `git apply --3way` started no operation, so there is nothing to
continue and git prepared no message. Stage the resolved files and stop there.
A commit for them waits for the user's request, and the `eng:commit` skill makes
it.

A stash pop has no continue. Stage the resolved files, confirm the working
tree holds what you want, then drop the entry git kept. Find its current
position from the SHA step 2 recorded, because it may have moved:

```bash
git stash list --format='%H %gd' | awk -v s=<sha> '$1 == s { print $2 }'
git stash drop <the stash@{n} that printed>
```

When the lookup prints nothing, the entry is gone already, so drop nothing.

Finish the operation rather than backing out of it. When the right move is
`--abort`, say why and wait for the user to answer.

**Done when:** `git status` reports no operation in progress and no unmerged
paths, any path a passing hook rewrote is named in the report, and for a stash
pop `git stash list` no longer holds the entry that produced the conflict, or
the run has handed off or stopped with its reason named, which is a rebase that
stopped on its next commit and restarted at step 1, an `apply --3way` staged
and waiting on the user's request to commit, an `--abort` waiting on the user's
answer, or a hook's output printed with the operation still paused.

---

Adapted from the `resolving-merge-conflicts` skill in mattpocock/skills at
`daa01d8^`, the last version before upstream deleted it (MIT).
