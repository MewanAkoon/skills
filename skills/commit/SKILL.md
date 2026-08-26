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

Skip it too while a merge, rebase, cherry-pick, or revert is in progress. The
`merge-conflicts` skill finishes those and writes their commit itself. Step 1
says how to spot one.

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

Then check whether git is already part way through something:

```bash
ls "$(git rev-parse --git-dir)" \
  | grep -xE 'MERGE_HEAD|CHERRY_PICK_HEAD|REVERT_HEAD|rebase-apply|rebase-merge'
```

A hit means a merge, rebase, cherry-pick, or revert is mid-flight. Hand the
run to `merge-conflicts` and stop, because a plain `git commit` during a
rebase leaves the rebase sitting unfinished. The two `rebase-` entries are
directories that last the whole rebase, which `REBASE_HEAD` does not.

End condition: that probe printed nothing, and `git status --porcelain -uall`
printed at least one path.

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

Check each path before staging it. Stop and name the file when its name starts
with `.env` and is neither `.env.example` nor `.env.sample`, so `.env.local`
and `.env.production` both stop the run. Stop too when a path matches `*.pem`,
`*.key`, `id_rsa`, or `credentials`.

When the staged files cover unrelated concerns, name the groups to the user
and commit them one at a time: stage the group, derive its scope, write its
message, commit, then move to the next.

End condition: every staged path belongs to the change named in the message
you are about to write.

## 3. Match the repo's convention

Read what the repo already does:

```bash
git log --oneline -30
ls -a "$(git rev-parse --show-toplevel)" | grep -i commitlint || echo "no config file"
grep -o '"commitlint"[[:space:]]*:' "$(git rev-parse --show-toplevel)/package.json" \
  2>/dev/null || echo "no commitlint key"
```

Both probes read the repo root, not the working directory, so they still find
the config from inside a package of a monorepo. The second looks for a
`commitlint` key rather than the word anywhere in the file, because a repo
that installs `@commitlint/cli` as a dependency without configuring it has no
rules to follow.

A config file or that key wins. Follow it and skip the rest of this step.

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

Omit the scope when nothing is left to name. That happens when every segment
was a container, as for `src/lib/utils.ts`, and when the prefix reduces to the
repo root, as for root config files and a change spanning several units.

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
snapshot. Only its unstaged (` M`) and untracked (`??`) entries matter later:
those are work the user already had in progress, and step 7 leaves them alone.
Anything else that appears afterwards came from a hook.

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
  Re-stage every path that now carries unstaged content and was not an
  unstaged or untracked entry in the step 6 snapshot. A staged file that has
  picked up a second status letter is the hook's work, whether that reads
  `MM` for an edit or `AM` for a file this change adds. Retry the commit once.
- **Hook failed and nothing was modified.** A real failure, such as a type
  error or a lint rule with no autofix. Print the hook output, stop, and tell
  the user what to fix. Do not retry.
- **Hook passed but files were modified or created.** A hook rewrote files
  silently. Run `git status --porcelain -uall` again, ignore the paths the
  snapshot listed as unstaged or untracked, stage what is left, and commit it
  as `chore(lint): apply auto-fixes`.

End condition: `git status --porcelain -uall` returns nothing beyond the
unstaged and untracked entries the step 6 snapshot held.

## 8. Push, when asked

Only on `/commit push` or a direct request.

```bash
git rev-parse --abbrev-ref HEAD
git remote
git for-each-ref --format='%(upstream:remotename)' "$(git symbolic-ref -q HEAD)"
git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null
```

`$REMOTE` is what the third command prints, or `origin` when `git remote`
lists it, or the only name it lists. It is a name to substitute into the
commands below, not a shell variable, because a variable set in one command
does not survive into the next one. Then read the default branch:

```bash
git symbolic-ref --short refs/remotes/$REMOTE/HEAD 2>/dev/null | sed 's|^[^/]*/||'
```

When that prints nothing, fall back to the first of these the remote has:

```bash
git ls-remote --heads $REMOTE main master develop trunk
```

Push when the current branch is not that default branch. When it is the
default branch, say so and let the user confirm before pushing.

No upstream means `git push -u $REMOTE <branch>`. Otherwise `git push`.

## 9. Confirm

```bash
git log --oneline -3
```
