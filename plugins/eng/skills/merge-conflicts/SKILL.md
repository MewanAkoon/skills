---
name: merge-conflicts
description: Use when git reports unmerged paths or conflict markers after a merge, rebase, cherry-pick, revert, stash pop, pull, or applied patch, and the user's latest message asks to resolve them, reports them, or asks for that operation, or a rebase the run started stopped on them.
---

# Merge conflicts

`eng:commit` and `eng:pr` hand to this skill when `git status` shows an
operation in progress. Without a request to resolve it, or a rebase this run
started under a Delivery, report the operation and the unmerged paths, and
wait. Conflict markers in a file git has not listed as unmerged are text,
such as a parser fixture: leave them.

For a paused `gh stack rebase` this run started, which lists this branch as
`eng:implement`'s [stack.md](../implement/references/stack.md) checks, run
every step in the worktree its output named for the conflict, by absolute
path.

## Step 1: See the state

```bash
git status
git diff --name-only --diff-filter=U
```

Name the operation and the two sides. In a merge, cherry-pick, revert or
stash pop, `--ours` is where you are. In a rebase the words swap:
`--ours` is the upstream, `--theirs` your own commit.

**Done when:** the operation is named, the unmerged paths are listed, and each
side is tied to a branch, commit, stash entry or patch.

## Step 2: Trace each side

Read only the ref for the operation step 1 named, since a finished rebase can
leave a stale `REBASE_HEAD`: `MERGE_HEAD`, `REBASE_HEAD`, `CHERRY_PICK_HEAD` or
`REVERT_HEAD`, from `cat "$(git rev-parse --git-dir)/<REF>"`. In a linked
worktree `.git` is a file, so never write that path by hand. When the ref is
missing, stop and say so.

- Merge or rebase: `git log -p "HEAD...<sha>" -- <file>`.
- Cherry-pick or revert: `git show <sha> -- <file>`. A range would pull in the
  wrong history. A revert's side is the inverse of what prints.
- Stash pop: the stash stack is shared across worktrees, so find the entry by
  its message in `git stash list --format='%H %gs'`, record its SHA, and read
  `git stash show -p <sha>`. When no message matches, ask which entry it was.
- `git am`: the patch in `"$(git rev-parse --git-dir)"/rebase-apply/patch`.
  `git apply --3way` keeps nothing, so ask which patch file was applied.

**Done when:** for every unmerged path you can say in one sentence what each
side was trying to do, or the run has stopped on a missing ref or an ask.

## Step 3: Resolve each hunk

Keep both intents where they compose, such as one side's rename applied to the
other's new call site. Where they contradict, pick the one that fits the
operation's goal and print one line on what the other side gave up. New
behaviour from neither side goes in a later commit.

Regenerate a lockfile or generated output rather than merging it. Resolve the
manifest first, take one side of the lockfile, run the install, then
`git add` it: `git checkout --theirs` leaves the path unmerged. When the
install fails, print its output and stop.

Then check for leftover markers, staged and unstaged, since rebase and
cherry-pick stage what they resolve:

```bash
git diff --check -- <paths> | grep 'leftover conflict marker'
git diff --cached --check -- <paths> | grep 'leftover conflict marker'
grep -n '^<<<<<<<\|^|||||||\|^>>>>>>>' <paths that still exist>
```

**Done when:** all three print nothing, every contradiction has its line, and
every generated path is regenerated and staged.

## Step 4: Find the semantic conflicts

Look for what merges cleanly and still breaks: a rename against new reads of
the old name, a signature change against new callers, a new required field or
constraint against new writes, and two handlers or routes under one name. Past
20 callers of one symbol, open those under the touched directories and count
the rest.

**Done when:** every symbol either side changed is listed with its caller
count, or the record says neither changed one.

## Step 5: Run the project's checks

Find them in `package.json` or CI files. Run typecheck, tests, then lint and
format in report-only mode, since a formatter that writes touches files
neither side changed. Fix what the operation broke. A failure
red on both parents is reported, not fixed.

**Done when:** each check is listed with its exit code, or the repo has none.

## Step 6: Finish the operation

```bash
git add <files>
GIT_EDITOR=true git merge --continue    # or rebase, cherry-pick, revert, am
```

Without `GIT_EDITOR=true` a continue opens an editor nobody closes. It also
runs the commit hooks. One that fails and changed files: stage
its changes and continue once more. One that fails and changed nothing: print
its output and stop. One that passes and rewrote files: leave them unstaged
and name them. A rebase stops on the next commit: repeat from step 1. A
stack rebase continues with `gh stack rebase --continue` in place of
`git rebase --continue`, which would leave the layers above it behind. It
takes no `GIT_EDITOR` prefix and opens no editor.

A stash pop has no continue: stage, then drop the entry by the SHA step 2
recorded, found again with `git stash list --format='%H %gd'`, since its
position moves. `git apply --3way` stages and stops; the commit waits for a
request. `--abort` asks the user first.

**Done when:** `git status` shows no operation and no unmerged paths, or the
run has stopped with its reason named.

---

Adapted from the `resolving-merge-conflicts` skill in mattpocock/skills at
`daa01d8^`, the last version before upstream deleted it (MIT).
