# The branch, the remote, and the default branch

Read this from step 1 of this skill, or from the `eng:commit` skill's push
reference. It names the branch, the remote to use, and that remote's default
branch. What to do with them is the caller's. The last two sections serve
steps 2 and 3 of this skill.

## The branch and the remote

```bash
git rev-parse --abbrev-ref HEAD
git remote
git for-each-ref --format='%(upstream:remotename)' "$(git symbolic-ref -q HEAD)"
```

The first printing the literal `HEAD` means the checkout is detached and there
is no branch. Say so and stop.

The third command names the remote this branch already tracks. Take it when it
prints a name other than `.`, which it prints for a branch tracking a local
branch. Otherwise take `origin` when `git remote` lists it, or the only name
listed when there is exactly one. Ask the user which to use when several are
listed and none is `origin`. Stop when `git remote` lists nothing, because
there is no remote to work with.

Call that name `$REMOTE`, and the branch `$CURRENT_BRANCH`. They are names to
write into the commands below, not shell variables, because a variable set in
one command does not survive into the next one.

## The default branch

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
asked for, so a remote holding both `develop` and `main` prints `develop`
first. Read the whole list, then take `main`, else `master`, else `develop`,
else `trunk`. When it prints none of them, the default branch is unknown.

**Done when:** `$REMOTE` is one of the names `git remote` printed, and the
default branch is named or recorded as unknown. Or the run is waiting on the
user to pick a remote, or has stopped on a detached `HEAD` or a repo with no
remote.

## Matching a repository to a remote

The remote for a GitHub repository `owner/name` is the one whose
`git remote get-url` holds `owner/name` right after the host's `/` or `:`,
with nothing after it but an optional `.git`, ignoring case as GitHub does.

## The base repository

Step 3 reads this before it fetches. Where `gh` works, ask it which repository
the PR targets:

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner
```

When the printed repository matches `$REMOTE` by the rule above, or `gh` is
unusable or the command fails, `$BASE_REMOTE` is `$REMOTE`. Otherwise
`$REMOTE` is a fork, and `$BASE_REMOTE` is the remote that matches the printed
repository. When no remote matches, or more than one, say which repository
the PR targets and stop.

**Done when:** `$BASE_REMOTE` is named, or the run has stopped with the base
repository named and no single remote for it.
