---
name: commit
description: Use when a repo has uncommitted changes that are finished, or when the user says commit, stage, check in, or push. Groups related files into one change, matches the message convention the repo already uses, and recovers from pre-commit hooks that rewrite files.
---

# Commit

## What this does

It stages the files that belong to one change, writes a message in whatever
convention the repo already uses, and recovers when a pre-commit hook
rewrites files underneath it.

## When it runs

When the working tree is dirty and the change is finished. Finished means the
thing it set out to do now happens and the code builds. Half of a refactor is
not finished, and neither is a file saved while still exploring.

Skip it while the user is still iterating on the same code, and when the user
has not yet seen the changes.

## How to use it

Nothing to invoke. Type `/commit` to force a run, or `/commit push` to push
after the commits land.

---

## 1. Read the working tree

Run these together. The `-uall` matters, because plain `git status
--porcelain` collapses a new directory to `?? packages/` and hides the files
inside it:

```bash
git status --porcelain -uall
git diff
git diff --staged
```

Stop with "Nothing to commit" only when `git status --porcelain -uall`
prints nothing. Both diffs come back empty for a change made entirely of new
files, so they cannot decide this on their own.

## 2. Stage the change

When files are already staged, work with those. Add any untracked (`??`) or
unstaged file that sits in the same directory or module as something already
staged. Ask before adding one that sits somewhere else.

When nothing is staged, work out the group first. Files in the same directory
or module belong together, and so do files that import one another. Stage that
group by name, tracked and untracked alike, then ask about anything that fits
neither test.

Stage files by name so the list is visible in the transcript. Reach for
`git add -A` or `git add .` only after the user says to.

Check each path before staging it. Stop and name the file when one matches
`.env` and it is not `.env.example` or `.env.sample`, or when it matches
`*.pem`, `*.key`, `id_rsa`, or `credentials`.

When the staged files cover unrelated concerns, name the groups to the user
and commit them one at a time: stage the group, derive its scope, write its
message, commit, then move to the next.

End condition: every staged path belongs to the change named in the message
you are about to write.

## 3. Match the repo's convention

Read what the repo already does:

```bash
git log --oneline -30
ls -a | grep -i commitlint || echo "no commitlint config"
grep -l commitlint package.json 2>/dev/null || true
```

A commitlint config wins. Follow it and skip the rest of this step.

Otherwise read the last 30 subject lines and pick the shape most of them
share:

- Most look like `type(scope): text` or `type: text`, so use the template in
  step 5.
- Most open with a capitalised verb, as in "Add retry to the poller", so
  write that shape with no type and no scope.
- Most carry a ticket prefix like `ABC-123:`, so keep the prefix. Read the
  ticket id out of the branch name, and ask the user for it when the branch
  name has none.

Fewer than five commits, or no shape shared by most of them, means use the
conventional commits shape.

Whichever shape you pick, step 5 supplies the length, the body rule, and the
ending. Only the shape itself is decided here.

End condition: the subject you draft matches the same pattern as most of the
last 30 subjects.

## 4. Derive the scope

Only for the `type(scope):` shape. Take the common directory prefix of the
staged paths and drop the leading segments that only group code: `src`,
`lib`, `app`, `apps`, `packages`, `modules`, `integrations`, `components`,
`services`, `features`, `internal`, `pkg`, `cmd`. The first segment left is
the scope, with any leading dot stripped.

```
packages/database-pg/src/client.ts  ->  database-pg
apps/backend/src/server.ts          ->  backend
src/modules/book-formats/pdf.ts     ->  book-formats
src/auth/login.ts                   ->  auth
.claude/skills/commit/SKILL.md      ->  claude
.github/workflows/release.yml       ->  ci
```

`.github/workflows/` is the one exception to the rule, because `ci` is what
everyone calls those files.

Omit the scope when the prefix reduces to the repo root, which happens for
root config files and for a change spanning several units.

End condition: the scope names a directory that exists in the repo, or it is
`ci`, or there is no scope.

To fork this for one repo, replace this rule with that repo's literal path
map. The rule is here because a generic skill cannot know the layout. A fork
can.

## 5. Write the message

These hold whichever shape step 3 picked:

- The subject is one line of about 60 characters at most, with no full stop.
- The subject takes its mood and its capitalisation from that shape, so a
  repo writing "Add retry to the poller" keeps the capital A.
- A body is for a reason the subject and the diff do not already carry. One
  or two bullets, and the message ends at the last one with no trailers of
  any kind.

Two body bullets is the ceiling. Wanting a third means the commit covers too
much, so go back to step 2 and split it.

When step 3 picked the conventional commits shape, the subject looks like
this, with an imperative lowercase description:

```
type(scope): short description

- optional bullet
```

Types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `chore`, `style`,
`build`, `ci`.

End condition: the subject fits in roughly 60 characters and someone scanning
`git log` learns what changed from it without opening the diff.

## 6. Commit

Record the output of `git status --porcelain -uall` first and keep it as the
snapshot. Step 7 uses it to tell hook output apart from files the user had
already left lying around.

Commit with `-F` and a single-quoted heredoc, which keeps backticks and
special characters literal and needs no temp file. The `EOF` terminator sits
at column 0, with no leading spaces or tabs:

```bash
git commit -F <(cat <<'EOF'
type(scope): short description

- optional bullet
EOF
)
```

Let the hooks run. When a hook blocks a commit that has to land anyway, fix
what the hook reported rather than passing `--no-verify`.

Create a new commit every time. When the user wants a change folded into the
commit before it, say that amending rewrites history and ask them to confirm
first.

## 7. Handle what the hooks did

- **Hook failed and files were modified.** The hook fixed things itself.
  Re-stage those files and retry the commit once.
- **Hook failed and nothing was modified.** A real failure, such as a type
  error or a lint rule with no autofix. Print the hook output, stop, and tell
  the user what to fix. Do not retry.
- **Hook passed but files were modified or created.** A hook rewrote files
  silently. Run `git status --porcelain -uall` again, ignore everything that
  was in the step 6 snapshot, stage what is left, and commit it as
  `chore(lint): apply auto-fixes`.

End condition: `git status --porcelain -uall` returns nothing beyond what the
step 6 snapshot held.

## 8. Push, when asked

Only on `/commit push` or a direct request.

```bash
git rev-parse --abbrev-ref HEAD
git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'
git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null
```

When the second command prints nothing, fall back to the first of `main`,
`master`, `develop`, or `trunk` that exists on the remote.

Push when the current branch is not that default branch. When it is the
default branch, say so and let the user confirm before pushing.

No upstream means `git push -u origin <branch>`. Otherwise `git push`.

## 9. Confirm

```bash
git log --oneline -3
```
