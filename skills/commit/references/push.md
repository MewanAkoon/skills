# Pushing after the commit

Read this when the user asked to push, with `/eng:commit push` or in words.

## Find the branch and the remote

```bash
git rev-parse --abbrev-ref HEAD
git remote
git for-each-ref --format='%(upstream:remotename)' "$(git symbolic-ref -q HEAD)"
```

The first printing the literal `HEAD` means the checkout is detached and there
is no branch to push. Say so and stop.

The third command names the remote this branch already tracks. Take it when it
prints something. Otherwise take `origin` when `git remote` lists it, or the
only name listed when there is exactly one. Ask the user which to use when
several are listed and none is `origin`. Stop when `git remote` lists nothing,
because there is nowhere to push. An empty third command also means the branch
has no upstream, which decides the push command below.

Call that name `$REMOTE`. It is a name to write into the commands below, not a
shell variable, because a variable set in one command does not survive into
the next one.

## Find the default branch

```bash
git symbolic-ref --short refs/remotes/$REMOTE/HEAD 2>/dev/null | sed 's|^[^/]*/||'
```

When that prints nothing, ask the remote itself:

```bash
git remote show $REMOTE | sed -n '/HEAD branch/s/.*: //p'
```

When that prints nothing, or prints `(unknown)` as it does for an empty
remote, ask which of these the remote carries:

```bash
git ls-remote --heads $REMOTE \
  refs/heads/main refs/heads/master refs/heads/develop refs/heads/trunk
```

Each name is a full ref, because a bare `main` also matches
`refs/heads/release/main`. The output is sorted by ref name, not by the order
asked for, so read the whole list, then take `main`, else `master`, else
`develop`, else `trunk`. When it prints none of them, the default branch is
unknown.

## Push

When the current branch is the default branch, or the default is unknown, say
so and let the user confirm before pushing. Otherwise push: with no upstream,
`git push -u $REMOTE <branch>`, and otherwise `git push`. A push never uses
`--force` unless the user asks for it by name.

A push the remote rejects as non-fast-forward, or with "fetch first", means the
branch moved since you last fetched. Say so, and let the user choose between
`git pull --rebase` and leaving it where it is. Any other failed push, such as
a rejected login, a pre-push hook that exits non-zero, or a branch the remote
protects, ends the run. Print what `git push` said and stop.

**Done when:** `git push` exited zero and `git rev-parse --abbrev-ref
--symbolic-full-name '@{u}'` names a branch on `$REMOTE`, or the run is waiting
on the user to confirm a push to the default branch or with the default
unknown, or the run has stopped with its reason named, which is a detached
`HEAD`, no remote at all, several remotes with none called `origin` and the
user's choice still to come, a push the user declined on the default branch or
with the default unknown, a non-fast-forward rejection with the user's answer
still to come, or any other failed push with the output of `git push` printed.
