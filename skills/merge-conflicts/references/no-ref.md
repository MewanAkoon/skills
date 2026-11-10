# A stash pop, `git am`, and `git apply --3way`

Read this when the operation is one of these three, which keep no ref for the
other side: the first section in step 2, the second in step 6.

## In step 2

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

## In step 6

A bare `git apply --3way` started no operation, so there is nothing to
continue and git prepared no message. Stage the resolved files and stop there.
A commit for them waits for the user's request, and the `eng:commit` skill makes
it.

A stash pop has no continue. Stage the resolved files, confirm the working
tree holds what you want, then drop the entry git kept. Find its current
position from the SHA recorded under "In step 2", because it may have moved:

```bash
git stash list --format='%H %gd' | awk -v s=<sha> '$1 == s { print $2 }'
git stash drop <the stash@{n} that printed>
```

When the lookup prints nothing, the entry is gone already, so drop nothing.
