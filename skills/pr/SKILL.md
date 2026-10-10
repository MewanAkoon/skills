---
name: pr
description: Use when the user's latest message asks to open, raise, or update a pull request or its description. Resolves the base branch, drafts a title and body from the real diff, and creates or updates the pull request.
---

# PR

## What this does

It reads everything the branch changed against its base, writes a title and a
description from the diff, and either opens a pull request or updates the one
that is already open.

## When it runs

When a branch has commits the base does not and the user has asked for a pull
request. The ask decides. When the branch looks unreviewable, such as a build
that fails or work left half done, say so and confirm before opening one.
Reviewable does not mean every commit has landed.

This skill shapes a pull request. It does not decide that one gets opened.
Opening one puts the branch in front of reviewers, so a go-ahead given earlier
in the conversation does not carry forward. With a reviewable branch and no
ask, say what the PR would say and wait. A retry such as "try again" after a
failed attempt is the same ask. A background task's notification is not a
message from the user, so the ask before it still stands.

Skip it when the branch already has an open PR whose description still
matches the diff.

Skip it too while a merge, rebase, cherry-pick, or revert is in progress.
Step 2 says how to spot one.

## How to use it

Nothing to invoke. Type `/eng:pr` to force a run, or `/eng:pr draft` to open it
as a draft.

---

## 1. Resolve the remote and the base branch

```bash
git rev-parse --abbrev-ref HEAD
git remote
git for-each-ref --format='%(upstream:remotename)' "$(git symbolic-ref -q HEAD)"
```

The third command names the remote this branch already tracks. Take it when it
prints something. Otherwise take `origin` when `git remote` lists it, or the
only name listed when there is exactly one. Ask the user which to use when
several are listed and none is `origin`. Stop when `git remote` lists nothing
at all, because there is nowhere to open a PR.

An empty third command also means the branch has no upstream, which is what
step 6 checks before it pushes.

Call that name `$REMOTE`. It, `$BASE` and `$CURRENT_BRANCH` are names to
substitute into the commands below, not shell variables, because a variable
set in one command does not survive into the next one.

Then the base branch:

```bash
git symbolic-ref --short refs/remotes/$REMOTE/HEAD 2>/dev/null | sed 's|^[^/]*/||'
```

When that prints nothing, ask the remote itself:

```bash
git remote show $REMOTE | sed -n '/HEAD branch/s/.*: //p'
```

When that prints nothing, or prints `(unknown)` as it does for an empty
remote, ask the remote which of these it carries:

```bash
git ls-remote --heads $REMOTE \
  refs/heads/main refs/heads/master refs/heads/develop refs/heads/trunk
```

Each name is a full ref, because a bare `main` also matches
`refs/heads/release/main`. That output is sorted by ref name rather than by
the order the names were asked for, so a remote holding both `develop` and
`main` prints `develop` first. Read the whole list, then take `main`, else
`master`, else `develop`, else `trunk`. When it prints none of them, ask the
user which branch the PR targets.

Stop and tell the user when the current branch is that default branch,
because a PR cannot be opened from it. Stop too when the checkout is
detached, which is what `git rev-parse --abbrev-ref HEAD` printing the
literal `HEAD` means, because there is no branch to open a PR from.

End condition: `$REMOTE` is one of the names `git remote` printed and `$BASE`
names a branch that remote has, or the run is waiting on the user to name the
remote or the base, or the run has stopped with its reason named, which is no
remote at all, a detached `HEAD`, or a current branch that is already
`$BASE`.

## 2. Check the state of things

```bash
git status --porcelain -uall
ls "$(git rev-parse --git-dir)" \
  | grep -xE 'MERGE_HEAD|CHERRY_PICK_HEAD|REVERT_HEAD|rebase-apply|rebase-merge'
git diff --name-only --diff-filter=U
gh auth status
git remote get-url $REMOTE
```

A hit on the second command means a merge, rebase, cherry-pick, or revert is
mid-flight. Stop and say which one. `HEAD` is part way through the operation,
so the diff you would describe is not the diff that will land, and a rebase
still to finish rewrites every commit the PR would show. The
`eng:merge-conflicts` skill finishes the operation once the user asks for it.

Any path the third command lists stops the run the same way, even with no
operation in flight, which is the state `git apply --3way` leaves behind. That
probe reports every unmerged path, including the `AA` and `DD` cases that
carry no `U` in the status output.

Uncommitted changes mean asking: "You have uncommitted changes that will not
be in the PR. Continue? (yes / no)". Stop on no.

When `gh` is missing, unauthenticated, or the remote is not GitHub, skip the
rest of this step, work through steps 3 to 5, print the title and body for the
user to paste in themselves, and stop there. Say plainly that you did not
create anything.

Otherwise look for an existing PR in one call:

```bash
gh pr view --json baseRefName,number,url,title,body,state 2>/dev/null || true
```

Call the result `PR_DATA`.

- `PR_DATA` has content and `state` is `OPEN`: take `baseRefName` as the
  base, work through steps 3 to 5, then update the PR in step 7. When
  `git rev-list --count @{u}..HEAD` prints more than zero, those commits are
  not on the PR yet, so ask "<n> local commits are not on the PR yet. Push
  them first? (yes / no)". Yes means `git push` before step 7, never with
  `--force`, and a failed push prints its output and stops. No means steps 3
  to 5 describe only what the remote holds, read from `@{u}` rather than
  `HEAD`.
- `PR_DATA` is empty, or `state` is `CLOSED` or `MERGED`: take the base the
  user's message named, or else ask "What is the base branch for this PR?
  (default: <resolved default>)" and take their answer, or the resolved
  default on an empty reply. A stacked branch needs a base other than the
  default, which is why this asks. Work through steps 3 to
  5, then create the PR in step 6.

End condition: `PR_DATA` is on the record, or the run is waiting on the
user's answer about the base or about pushing, or `gh` is unusable and the
run goes on to steps 3 to 5 only to print the title and body, or the run has
stopped with its reason named, which is an operation in flight, an unmerged
path, a declined prompt, or a failed push.

## 3. Read the diff

```bash
git fetch $REMOTE $BASE
git log --oneline $REMOTE/$BASE..HEAD
git diff --stat $REMOTE/$BASE...HEAD
```

The fetch matters. Comparing against a stale `$REMOTE/$BASE` describes a diff
that no longer exists.

The dots differ on purpose. `git log` takes two, so it lists only the commits
this branch adds. Three dots there would be the symmetric difference and would
count commits that live only on the base. `git diff` takes three, so it
compares against the merge base and ignores what the base did afterwards.

Stop and tell the user there is nothing to open a PR for when no commits are
ahead of the base.

Read the full diff when the stat line shows 20 files or fewer:

```bash
git diff $REMOTE/$BASE...HEAD
```

Above 20 files, or above roughly 500 changed lines, read it one directory or
one package at a time and summarise per unit instead of per line.

End condition: you can name what every changed file does in the change, or
you have deliberately grouped it under a unit you can name, or the run has
stopped because no commits are ahead of the base and there is nothing to open
a PR for.

## 4. Pick the template

The repo's own template wins whenever one exists:

```bash
find "$(git rev-parse --show-toplevel)" -maxdepth 3 -ipath '*pull_request_template*' \
  -not -path '*/.git/*' -not -path '*/node_modules/*'
```

The search starts at the repo root so it still finds the template from inside
a subdirectory.

Found one? Fill in its sections and its checkboxes, keep its headings exactly
as they are, and skip the body template in step 5. The title guidance in step
5 still applies. When the template has no section for test evidence or for
merge risk, add step 5's Evidence or Merge danger section at its end.

Found none? Use the body template in step 5.

End condition: the `find` has run, and either a template path is on the record
with its headings to be kept as they are, or the search printed nothing and
step 5's body template applies.

## 5. Draft the title and body

The title and the body both describe what the code does. The ticket and the
branch name are not evidence of what landed.

For the title, match the convention already in use:

```bash
gh pr list --state merged --limit 20 --json title --jq '.[].title'
```

When most of those titles share a shape, such as a `[Type]` prefix, a
`type:` prefix, or a ticket id, write the new title in that shape. When they
share nothing, or the command returns nothing, use `[Type] Short description`
at 70 characters or fewer, picking the type from:

- `[Feat]` for a new feature or an improvement
- `[Fix]` for a bug fix
- `[Chore]` for maintenance, config, tooling, or dependencies
- `[Refactor]` for a restructure with no behaviour change
- `[Docs]` for documentation alone

The description is title-cased and names what the change makes true. A list
of the files touched is not that.

For the body:

````
## What and why
<!-- One paragraph. What changed and why, not how. -->
<one paragraph summary>

## Type of change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactor (no behaviour change)
- [ ] Dependency update
- [ ] Config / infra / env change

---

## Evidence
<!-- Before and after from a real run: the test that failed and now passes, or output that changed. -->
- Before: <command and what it printed>
- After: <command and what it prints now>

**How to review locally:**
```sh
# Commands to run and verify this PR
```

---

## Merge danger
<!-- Whether a revert undoes this, how far a break would reach, where to look hardest. -->
- Door: <one-way or two-way>, because <reason>
- Blast radius: <small, medium, or wide>, <what could break>
- Look hardest at: <file or area>

## What did you deliberately not do?
<!-- Scope decisions, known trade-offs, follow-up tickets -->
- <deliberate omission>
````

Tick the boxes that apply under Type of change, and replace the comment under
"How to review locally" with the commands a reviewer runs. A template shipped
with every box empty is worse than no template.

Evidence comes from a run this session made: the test `eng:implement` saw fail
and then pass, the checks its review ran, or output the change altered. A green
run on its own is a claim, and the before and after together are the
evidence. When this session ran nothing, run the repo's tests now for the
After line, and write that the before was not observed.

Merge danger is always there. A one-way door is a change a revert does not
undo: a destructive migration, deleting or backfilling data, removing a
public API or field, or sending messages or webhooks. Everything else is
two-way. Take the blast radius from the plan's risks or a `eng:blast-radius` run
when there was one, rather than a fresh guess. When the diff touches
`migrations/`, `migrate/`, `*.tf`, `Dockerfile`, `docker-compose*`, `helm/`,
`k8s/`, `.github/workflows/`, or an `.env` example file, add the lines that
apply under it:

```
- Infrastructure: <what changes>
- Env variables: <names>
- Migration: `<path from the diff>`, rollback: <simple revert, manual, other>, data impact on rollback: <impact>
```

The body ends at its last section, with no AI disclosure footer and no
`Co-Authored-By` trailer.

End condition: no angle-bracket placeholder such as `<reason>` or
`<file or area>` survives into the body, every checklist has the boxes that
apply ticked, Evidence names the commands and what they printed, or says the
before was not observed, or says why no run applies to a docs-only change or
a repo with no tests, Merge danger names the door and the blast radius,
and "How to review locally" holds real commands. Every section
holds real content or is deleted. The `<!-- -->` comments stay, since GitHub
hides them when it renders the page.

## 6. Create, when no PR exists

Push first when the branch has no upstream, or has commits its upstream
lacks:

```bash
git push -u $REMOTE $CURRENT_BRANCH
```

When the push fails, for a reason such as no permission to push, a pre-push
hook that exits non-zero, or a branch of the same name that has moved on the
remote, print what `git push` said and stop.

Then create it. The single-quoted heredoc keeps backticks and special
characters literal, and process substitution avoids a temp file. Every `EOF`
terminator sits at column 0, with no leading spaces or tabs. Add `--draft` on
`/eng:pr draft`:

```bash
gh pr create \
  --title "$(cat <<'EOF'
<title>
EOF
)" \
  --body-file <(cat <<'EOF'
<body>
EOF
) \
  --base $BASE
```

When `gh pr create` fails, print what `gh` said and stop. One cause is a PR
already open for this branch. Name its number so the user can rerun and take
step 7 instead.

End condition: `gh pr create` printed a URL and the branch now has an upstream
on `$REMOTE`, or the run has stopped with the command's own output printed,
which is a failed `git push`, a PR already open for this branch, or another
`gh pr create` error.

## 7. Update, when a PR is open

Show the user what changes before touching anything:

```
Existing PR: <url>

Current title:  <existing title>
Proposed title: <new title>

Current summary:  <first line of existing body, or "(none)">
Proposed summary: <new summary>
```

Ask "Apply these updates to the PR? (yes / no)" and stop on no.

On yes:

```bash
gh pr edit \
  --title "$(cat <<'EOF'
<title>
EOF
)" \
  --body-file <(cat <<'EOF'
<body>
EOF
)
```

When `gh pr edit` exits non-zero, read
[references/rest-fallback.md](references/rest-fallback.md) and send the same
title and body through the REST API.

End condition: the user answered the prompt, and either they declined and
nothing was sent, or `gh pr edit` or the REST fallback exited zero, or both
failed and their output is printed.

## 8. Confirm

Print the PR URL.

End condition: `gh pr view --json state,title,url` returns the PR open, and
its title is the one step 5 drafted, or the one it already carried when the
user declined the update in step 7. A URL printed from memory proves nothing
about what landed.
