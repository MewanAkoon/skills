---
name: pr
description: Use when the user's latest message asks to open, raise, or update a pull request or its description. Resolves the base, drafts the title and body from the real diff, and creates or updates the PR.
---

# PR

## 1. Check the state

Run `git status`, `git status --porcelain -uall`, `gh auth status`, and
`gh pr view --json number,url,state,baseRefName,headRefName,headRefOid,title,body`.
When the plain `git status` reports a merge, rebase, cherry-pick, or revert in
progress, or an unmerged path, hand the run to `eng:merge-conflicts` and
stop. Stop too on a detached `HEAD` or no remote.

Uncommitted changes, other than untracked `.claude/plans/` and
`.claude/handoffs/` files: without a Delivery, as `eng:implement`'s
[deliver.md](../implement/references/deliver.md) names one, ask whether to
continue without them; under one, leave them out and name them in the
hand-back as a ruling.

With a remote that is not GitHub, take the base from the message or
Delivery's `Base:`, else the default from `git remote set-head <remote> -a`
then `git symbolic-ref --short refs/remotes/<remote>/HEAD`, run steps 3 to 5,
print the title and body, and say nothing was created. On a GitHub remote
with `gh` missing or not signed in, do the same, then stop and name the fix,
installing `gh` or `gh auth login`. An open PR is updated as
[references/update.md](references/update.md) says, on its `baseRefName`.

**Done when:** the run knows whether it creates or updates.

## 2. Resolve the base

The base is the one the user's message names. Otherwise it is Delivery's
`Base:`, else the stack parent, else the default branch, logged as a ruling.
The stack parent comes from `gh stack view --json` when it lists this branch:
the `name` of the entry below it in `branches[]`, bottom first, or `trunk`
for the bottom one, since each `base` there is a SHA. When
`git ls-remote --exit-code --heads <remote> <base>` fails, use the default
branch and log that as a ruling.

`gh repo view --json defaultBranchRef,parent` gives the default. A set
`parent` means a fork: the base lives on the remote whose URL holds the
parent's `owner/name`. Stop when the current branch is the base.

**Done when:** the base and its remote are named.

## 3. Read the diff

```bash
git fetch <base remote> <base>
git log --oneline <base remote>/<base>..HEAD
git diff --stat <base remote>/<base>...HEAD
```

With no commits ahead, stop. Past about 20 files or 500 lines, read one
package at a time.

**Done when:** every changed file has a named role.

## 4. Pick the format

Follow `eng:commit`'s [repo-guidance.md](../commit/references/repo-guidance.md),
then look for a template:

```bash
find "$(git rev-parse --show-toplevel)" -maxdepth 3 -ipath '*pull_request_template*' -not -path '*/node_modules/*'
```

A template wins: keep its headings, and add Evidence and Merge danger from
[references/body.md](references/body.md) when it lacks them. With neither,
use that file.

**Done when:** the format is chosen.

## 5. Draft the title and body

Describe what the diff does. Match the shape most of
`gh pr list --state merged --limit 20 --json title` share; with none, use
`[Type] Title Case Description` in 70 characters, the type `[Feat]`, `[Fix]`,
`[Chore]`, `[Refactor]`, or `[Docs]`.

Evidence is a before and after from this session's runs, or the tests run
now with the before marked unseen.

Merge danger names the door and blast radius. A one-way door is one a revert
does not undo: a destructive migration, changed data, a removed public API,
sent messages. Take the blast radius from the plan or `eng:blast-radius`. A
diff touching migrations, Terraform, Docker, Kubernetes, workflows, or an
`.env` example names the infrastructure, env variables, and rollback.

**Done when:** no placeholder survives.

## 6. Create

Push as `eng:commit`'s Push section says, unless the upstream holds `HEAD`.
Write title and body to files in the scratchpad, or `mktemp -d`. Every PR
opens as a draft. Assign whoever the user names, else `@me`; add no
reviewer. A stack opens through `gh stack submit --auto`, which drafts each
new PR.

```bash
gh pr create --draft --title "$(cat <title file>)" --body-file <body file> --base <base> --assignee @me
```

On failure print what `gh` said; an existing PR goes to update.md. Then run
`gh pr view --json url,state`, since the PR may exist with only the assignee
failed; with none, retry once without `--assignee` and say so.

**Done when:** `gh pr view` shows the PR open.

## 7. Confirm

Read back `gh pr view --json state,title,url` and print the URL. Then
finish as deliver.md's steps 8 and 9 say, a plain request to open a PR
included: the post-PR review, `/code-review high <from>..HEAD`, where
`<from>` is the `Reviewed:` commit, else
`git merge-base <base remote>/<base> HEAD`, then ready by its Ready section.
Without a Delivery, fixes the review finds wait for the user, and the PR
stays a draft until they land.

**Done when:** the read-back title is the drafted one, and the PR is ready
or the hand-back says why it is a draft.
