# Pushing after the commit

Read this when the user asked to push, with `/eng:commit push` or in words.

## Find the branch, the remote, and the default branch

Follow the `eng:pr` skill's [references/remote.md](../../pr/references/remote.md).
It names `$REMOTE`, `$CURRENT_BRANCH`, and the default branch, and stops on a
detached `HEAD` or a repo with no remote.

## Push

When the current branch is the default branch, or the default is unknown, say
so and let the user confirm before pushing. On a yes, or on any other branch,
read the upstream:

```bash
git for-each-ref --format='%(upstream:lstrip=2)' "$(git symbolic-ref -q HEAD)"
```

When it prints `$REMOTE/$CURRENT_BRANCH`, push with `git push`, even when that
branch was deleted on the remote, which `@{u}` reports as an error once a
fetch prunes it. When it prints nothing, push with
`git push -u $REMOTE $CURRENT_BRANCH`. When it names another branch, such as
`origin/main` for a branch made from it, a plain `git push` would be refused
or would land on that branch. Say which branch it tracks, and ask before
pushing with `git push -u $REMOTE $CURRENT_BRANCH`. Name `$REMOTE` in the
question, because the push goes there and moves the upstream to a branch of
the same name. A push never uses `--force` unless the user asks for it by
name.

A push the remote rejects as non-fast-forward, or with "fetch first", means the
branch moved since you last fetched. Say so, and let the user choose between
`git pull --rebase` and leaving it where it is. Any other failed push, such as
a rejected login, a pre-push hook that exits non-zero, or a branch the remote
protects, ends the run. Print what `git push` said and stop.

**Done when:** `git push` exited zero and the upstream read above now prints
`$REMOTE/$CURRENT_BRANCH`, or the run is waiting on the user to confirm a push
to the default branch, with the default unknown, or from a branch tracking
another branch, or the run has stopped with its reason named, which is a
detached `HEAD`, no remote at all, several remotes with none called `origin`
and the user's choice still to come, a push the user declined, a
non-fast-forward rejection with the user's answer still to come, or any other
failed push with the output of `git push` printed.
