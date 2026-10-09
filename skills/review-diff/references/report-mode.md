# Report mode and pull requests

Read this when reviewing a pull request, or anything else in report mode.

A PR in fix mode, one the user asked you to fix, needs its branch checked out
so the fixes land on it. Review it in place, and when its head is not checked
out, ask the user to check it out first. The worktree below is for report
mode only.

## Get the PR's head on disk

The checks and the reviewers read files, so they have to read the PR's code
rather than whatever branch is checked out. Read the PR's refs first:

```bash
gh pr view <n> --json baseRefName,headRefName,headRefOid,url
```

Fetch the base, so a stale local branch does not widen the diff. `<remote>` is
the remote that holds the base repository: `origin` in most clones, and usually
`upstream` in a fork. When the checked-out commit is `headRefOid`, review in
place. Otherwise fetch the head into its own worktree under `$R`, which leaves
the current checkout and any uncommitted work alone:

```bash
git fetch <remote> "<baseRefName>"
git fetch <remote> "pull/<n>/head"
git worktree add --detach "$R/pr-<n>" FETCH_HEAD
```

Use `<remote>/<baseRefName>` as the base either way, and run every later step
from the worktree when there is one. A new worktree has no installed
dependencies, so install them the way the repo's README or CI does before
running the checks, or run only the checks that need none and say which were
skipped. Remove the worktree when the review is done: `git worktree remove
"$R/pr-<n>"`.

**Done when:** the review runs from a checkout at `headRefOid`, or the fetch
failed and the report says so.

## What report mode returns

The findings by file, each with its `file:line`, verdict, and rating, and
nothing edited. Write review comments for someone else's PR only when the
user asks for them, as a Markdown file in the scratchpad directory your system
prompt names, or in `${TMPDIR:-/tmp}/drafts` when it names none. The user posts
them.
