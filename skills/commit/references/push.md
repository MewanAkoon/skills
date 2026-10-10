# Pushing after the commit

Read this when the user asked to push, with `/eng:commit push` or in words.

## Find the branch, the remote, and the default branch

Follow the `eng:pr` skill's [references/remote.md](../../pr/references/remote.md).
It names `$REMOTE`, `$CURRENT_BRANCH`, and the default branch, stops on a
detached `HEAD` or a repo with no remote, and says whether the branch has an
upstream, which decides the push command below.

## Push

When the current branch is the default branch, or the default is unknown, say
so and let the user confirm before pushing. Otherwise push: with no upstream,
`git push -u $REMOTE $CURRENT_BRANCH`, and otherwise `git push`. A push never
uses `--force` unless the user asks for it by name.

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
