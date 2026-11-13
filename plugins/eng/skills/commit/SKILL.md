---
name: commit
description: Use when the user's latest message asks to commit, stage, check in, or push.
---

# Commit

A request only to stage ends after step 2. A request only to push, with
nothing to commit, goes to Push.

## 1. Read the tree

Run `git status`, `git status --porcelain -uall`, `git diff`, and
`git diff --staged`. `-uall` lists the files inside a new directory. Only the
plain `git status` names a paused operation. When it reports a
merge, rebase, cherry-pick, or revert in progress, or an unmerged path, hand
the run to `eng:merge-conflicts` and stop. With nothing listed, say so and
end.

**Done when:** a path is listed and nothing is mid-operation.

## 2. Stage the change

Paths the user named are the group. Otherwise keep what is staged, a partly
staged path as it is, and add files in the same module or that import one
another. Stage by name, never `git add -A` or `.` unless told. Leave
untracked `.claude/plans/` and `.claude/handoffs/` files out unless named.

A file that fits no group: without a Delivery, as `eng:implement`'s
`references/deliver.md` names one, ask. Under one, its grouping decides, and
the file stays uncommitted, named in the hand-back as a ruling. Commit
unrelated groups one at a time.

Stop and name the file when a path starts with `.env`, other than
`.env.example` or `.env.sample`, or matches `*.pem`, `*.key`, `id_rsa`, or
`credentials`.

**Done when:** every staged path belongs to one change.

## 3. Match the convention

Follow [references/repo-guidance.md](references/repo-guidance.md). The order
is a commitlint config (a `commitlint` file at the root or a `"commitlint"`
key in `package.json`), then that guidance, then the shape most of
`git log --oneline -30` shares: `type(scope): text`, a capitalised verb, or a
ticket prefix taken from the branch name. Fewer than five commits, or no
shared shape, means conventional commits, lowercase and imperative.

**Done when:** the first source that sets a shape has set it.

## 4. Derive the scope

For `type(scope):` only. Use the config's or guidance's list when there is
one. Otherwise take the staged paths' common prefix, drop grouping segments
such as `src`, `lib`, `apps`, `packages`, `internal`, and use the first left,
without a leading dot. `.github/workflows/` is `ci`. With nothing left, omit
it.

**Done when:** the scope is listed, a real directory, `ci`, or omitted.

## 5. Write the message

Subject: one line, about 60 characters, no full stop. Body: only a reason the
diff does not show, at most two bullets, or split the commit. Trailers: only
those the guidance requires.

**Done when:** the message fits those limits.

## 6. Commit

Write the message to a file in the scratchpad, or in `mktemp -d`. Snapshot
`git status --porcelain -uall`, and for each partly staged path the hash of
its held-back lines:

```bash
git diff --no-color --no-ext-diff -U0 -- <path> | grep '^[-+]' | git hash-object --stdin
```

Run `git commit -F <file>`, never with `--no-verify`. Amending asks first.

**Done when:** `git commit` returned and its output is kept.

## 7. Handle the hooks

Clean when it exited zero, every hash matches, and no path is new against the
snapshot. Otherwise:

- A held-back hash changed: stage nothing, name the path, stop for the user's
  `git add -p`.
- Failed, files changed: re-stage the hook's paths, retry once, then stop.
- Failed, nothing changed: print the output and stop.
- Passed, files changed: commit them in the repo's shape, such as
  `chore(<scope>): apply auto-fixes`.

Print `git log --oneline -<n>` for this run's commits.

**Done when:** no path is new against the snapshot.

## Push

On a request to push, or a push Delivery lists. `git rev-parse --abbrev-ref
HEAD` printing `HEAD` means detached: stop. The remote is the upstream's,
else `origin`, else the only one; with several and no `origin`, ask; with
none, stop. Confirm before pushing the default branch, which
`git symbolic-ref --short refs/remotes/<remote>/HEAD` names after
`git remote set-head <remote> -a`. Read the upstream:

```bash
git for-each-ref --format='%(upstream:lstrip=2)' "$(git symbolic-ref -q HEAD)"
```

`<remote>/<branch>`: `git push`. Empty: `git push -u <remote> <branch>`.
Another branch, such as `origin/main`: under a Delivery, push with `-u` to
its branch and log a ruling; otherwise ask first.

A push rejected after a rebase this run made proposes
`git push --force-with-lease`, run only on the user's yes. Any other
rejection: fetch, report what `git push` said and what the remote branch has
that this one lacks, and stop.

**Done when:** `git push` exited zero onto `<remote>/<branch>`.
