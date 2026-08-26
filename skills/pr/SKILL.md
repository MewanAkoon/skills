---
name: pr
description: Use when a branch has commits ahead of its base and the work is ready for review, or when the user says open a PR, raise a PR, or update the PR description. Resolves the base branch, drafts a title and body from the real diff, and creates or updates the pull request.
---

# PR

## What this does

It reads everything the branch changed against its base, writes a title and a
description from the diff rather than from the branch name, and either opens
a pull request or updates the one that is already open.

## When it runs

When a branch has commits the base does not, and the work on it is finished.
Finished means the branch is reviewable, not that every commit has landed.

Skip it while commits are still going onto the branch, and when the branch
already has an open PR whose description still matches the diff.

Skip it too while a merge, rebase, cherry-pick, or revert is in progress.
Step 2 says how to spot one.

## How to use it

Nothing to invoke. Type `/pr` to force a run, or `/pr draft` to open it as a
draft.

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

When that fails too, take the first of these the remote actually has:

```bash
git ls-remote --heads $REMOTE main master develop trunk
```

Stop and tell the user when the current branch is that default branch,
because a PR cannot be opened from it.

End condition: `$REMOTE` is one of the names `git remote` printed, `$BASE`
names a branch that remote actually has, and `$CURRENT_BRANCH` is not
`$BASE`.

## 2. Check the state of things

```bash
git status --porcelain -uall
ls "$(git rev-parse --git-dir)" \
  | grep -xE 'MERGE_HEAD|CHERRY_PICK_HEAD|REVERT_HEAD|rebase-apply|rebase-merge'
gh auth status
git remote get-url $REMOTE
```

A hit on the second command means a merge, rebase, cherry-pick, or revert is
mid-flight. Stop and say which one. `HEAD` is part way through the operation,
so the diff you would describe is not the diff that will land, and a rebase
still to finish rewrites every commit the PR would show. The
`merge-conflicts` skill finishes the operation.

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
  base, work through steps 3 to 5, then update the PR in step 7.
- `PR_DATA` is empty, or `state` is `CLOSED` or `MERGED`: ask "What is the
  base branch for this PR? (default: <resolved default>)" and take their
  answer, or the resolved default on an empty reply. Work through steps 3 to
  5, then create the PR in step 6.

End condition: `PR_DATA` is on the record, or the run has stopped with its
reason named, which is an operation in flight, a declined prompt, or no
usable `gh`.

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
you have deliberately grouped it under a unit you can name.

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
5 still applies, and so does the deployment notes section when the diff calls
for one.

Found none? Use the body template in step 5.

End condition: the `find` has run, and either a template path is on the record
with its headings to be kept as they are, or the search printed nothing and
step 5's body template applies.

## 5. Draft the title and body

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

The description is title-cased and names the intent of the change. A list of
the files touched is not an intent.

For the body:

````
## What & why
<!-- One paragraph. What changed and why, not how. -->
<one paragraph summary>

## Type of change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactor (no behaviour change)
- [ ] Dependency update
- [ ] Config / infra / env change

---

## Testing
- [ ] Unit tests added / updated
- [ ] Integration tests added / updated
- [ ] Manually tested

**Edge cases covered:**
<!-- Boundary conditions, failure modes, permission cases, unusual inputs. -->
- <edge case>

**How to review locally:**
```sh
# Commands to run and verify this PR
```

---

## What should reviewers focus on?
<!-- Skip style and syntax. Flag where you want human judgment. -->
- <focus area>

## What did you deliberately NOT do?
<!-- Scope decisions, known trade-offs, follow-up tickets -->
- <deliberate omission>
````

Describe what the code does. The ticket and the branch name are not evidence
of what landed.

Tick the boxes that apply under Type of change and Testing, and replace the
comment under "How to review locally" with the commands a reviewer actually
runs. A template shipped with every box empty is worse than no template.

Add a deployment notes section only when the diff touches infrastructure,
environment variables, or database migrations. Look for paths matching
`migrations/`, `migrate/`, `*.tf`, `Dockerfile`, `docker-compose*`, `helm/`,
`k8s/`, `.github/workflows/`, or any `.env` example file. Leave the section
out completely when none of them appear.

```
---

## Deployment notes
- [ ] Safe to deploy immediately
- [ ] Infrastructure changes required -> describe: <description>
- [ ] Env variable changes -> variable name(s): <names>
- [ ] DB migration required
      Migration file: `<path from the diff>`
      Rollback strategy: simple revert / manual rollback / other: ___
      Data impact on rollback: ___
```

Keep only the lines that apply. Tick "Safe to deploy immediately" only when
none of the others do.

The body ends at its last section, with no AI disclosure footer and no
`Co-Authored-By` trailer.

End condition: no angle-bracket placeholder such as `<edge case>` or
`<focus area>` survives into the body, every checklist has the boxes that
apply ticked, and "How to review locally" holds real commands. Every section
holds real content or is deleted. The `<!-- -->` comments stay, since GitHub
hides them when it renders the page.

## 6. Create, when no PR exists

Push first when the branch has no upstream:

```bash
git push -u $REMOTE $CURRENT_BRANCH
```

Then create it. The single-quoted heredoc keeps backticks and special
characters literal, and process substitution avoids a temp file. Every `EOF`
terminator sits at column 0, with no leading spaces or tabs. Add `--draft` on
`/pr draft`:

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

End condition: `gh pr create` printed a URL, and the branch now has an
upstream on `$REMOTE`.

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

A non-zero exit here is usually a GraphQL deprecation. Fall back to REST.
Replace `{number}` with the number from `PR_DATA`, and leave `{owner}` and
`{repo}` exactly as written. `gh api` fills in those two from the current repo
and nothing else, so a literal `{number}` returns a 404 that looks like a
missing PR:

```bash
gh api repos/{owner}/{repo}/pulls/{number} --method PATCH \
  --field title="$(cat <<'EOF'
<title>
EOF
)" \
  --field body="$(cat <<'EOF'
<body>
EOF
)"
```

End condition: the user answered the prompt, and either they declined and
nothing was sent, or one of the two commands exited zero.

## 8. Confirm

Print the PR URL.

End condition: `gh pr view --json state,title,url` returns the PR open, with
the title step 5 drafted. A URL printed from memory proves nothing about what
landed.
