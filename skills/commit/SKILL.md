---
name: commit
description: Use when the user's latest message asks to commit, stage, check in, or push. Groups related files into one change, matches the message convention the repo already uses, and recovers from pre-commit hooks that rewrite files.
---

# Commit

## What this does

It stages the files that belong to one change, writes a message in whatever
convention the repo already uses, and recovers when a pre-commit hook
rewrites files underneath it.

## When it runs

When the working tree is dirty and the user has asked for a commit. The ask
decides. When the change looks unfinished, such as half of a refactor, code
that does not build, or a file saved while still exploring, say so and
confirm before committing.

This skill shapes a commit. It does not decide that one happens. A go-ahead
given earlier in the conversation does not carry forward, and "address the
review" or "fix the comments" asks for changes and nothing else. With a dirty
tree and no ask, say what you would commit and wait. A retry such as "try
again" after a failed commit is the same ask. A background task's notification
is not a message from the user, so the ask before it still stands.

A request only to stage stops after step 2. A request only to push goes
straight to step 8 when there is nothing new to commit, and otherwise asks
whether to commit the changes first.

Skip it while a merge, rebase, cherry-pick, or revert is in progress. The
`eng:merge-conflicts` skill resolves those and writes their commit, once the
user has asked for that. Step 1 says how to spot one.

## How to use it

Nothing to invoke. Type `/eng:commit` to force a run, or `/eng:commit push` to
push after the commits land.

---

## 1. Read the working tree

```bash
git status --porcelain -uall
git diff
git diff --staged
```

`-uall` lists the files inside a new directory rather than collapsing it to
`?? packages/`. Stop with "Nothing to commit" only when that command prints
nothing and no push was asked for, because both diffs are empty for a change
made only of new files. With a push asked for, go to step 8.

Then check whether git is part way through something, and whether anything is
unmerged, because a conflict can outlive its operation:

```bash
ls "$(git rev-parse --git-dir)" \
  | grep -xE 'MERGE_HEAD|CHERRY_PICK_HEAD|REVERT_HEAD|rebase-apply|rebase-merge'
git diff --name-only --diff-filter=U
```

A hit from either means the run belongs to `eng:merge-conflicts`, so hand it
over and stop. A plain `git commit` mid-rebase leaves the rebase unfinished, and
`git add` on a conflicted path clears the flag without resolving anything, so
the markers would land in history. `git apply --3way` leaves unmerged paths with
no operation in progress, which is why the second check exists.

End condition: both checks printed nothing and `git status --porcelain -uall`
printed at least one path, or the run has gone to step 8 for a push, or the
run has stopped with its reason named, which is either nothing to commit or
work handed to `eng:merge-conflicts`.

## 2. Stage the change

When the user named files, they are the group: stage exactly those. When
files are already staged, work with those, and leave a partly staged path as
the user staged it. Add any untracked (`??`) or unstaged file in the same
directory or module as something already staged, and ask before adding one
that sits somewhere else.

When nothing is staged, work out the group first. Files in the same directory
or module belong together, and so do files that import one another. Stage that
group by name, tracked and untracked alike, then ask about anything that fits
neither test. Stage by name so the list shows in the transcript, and reach for
`git add -A` or `git add .` only after the user says to.

Leave out untracked working files other skills write under `.claude/plans/`
and `.claude/handoffs/`, unless the user names them, and say which were left
out.

Check each path that will be committed, whether you staged it or the user
did. Stop and name the file when its name starts
with `.env` and is neither `.env.example` nor `.env.sample`, or when it
matches `*.pem`, `*.key`, `id_rsa`, or `credentials`.

When the staged files cover unrelated concerns, name the groups to the user
and commit them one at a time: stage the group, derive its scope, write its
message, commit, then move to the next.

End condition: every staged path belongs to the change named in the message
you are about to write, or the run is waiting on the user's answer about a
file outside the staged group, a file that fits neither test, or staging with
`git add -A`, or the run has stopped with the secret it found named.

## 3. Match the repo's convention

```bash
git log --oneline -30
ls -a "$(git rev-parse --show-toplevel)" | grep -i commitlint || echo "no config file"
grep -o '"commitlint"[[:space:]]*:' "$(git rev-parse --show-toplevel)/package.json" \
  2>/dev/null || echo "no commitlint key"
```

Both probes read the repo root, so they find the config from inside a
monorepo package. The second wants a `commitlint` key, because a repo that
only installs `@commitlint/cli` has no rules to follow. A config file or that
key wins, including over a history that disagrees with it.

Otherwise pick the shape most of the last 30 subjects share:

- Most look like `type(scope): text` or `type: text`, so use the template in
  step 5.
- Most open with a capitalised verb, as in "Add retry to the poller", so write
  that shape with no type and no scope.
- Most carry a ticket prefix like `ABC-123:`, so keep it. Read the ticket id
  from the branch name, and ask for it when the branch name has none.

Fewer than five commits, no shape most of them share, or `git log` exiting
128 on a repo with no commits, all mean the conventional commits shape.

End condition: the subject you draft satisfies the commitlint config when the
repo has one, and otherwise matches the shape most of the last 30 subjects
share, or uses the conventional commits shape for one of the reasons above,
or the run is waiting on the user for the ticket id.

## 4. Derive the scope

Only for the `type(scope):` shape. Take the common directory prefix of the
staged paths and drop the leading segments that only group code: `src`,
`lib`, `app`, `apps`, `packages`, `modules`, `integrations`, `components`,
`services`, `features`, `internal`, `pkg`, `cmd`. The first segment left is
the scope, with any leading dot stripped.

```
packages/database-pg/src/client.ts  ->  database-pg
apps/backend/src/server.ts          ->  backend
src/auth/login.ts                   ->  auth
.claude/skills/commit/SKILL.md      ->  claude
.github/workflows/release.yml       ->  ci
```

`.github/workflows/` is the one exception, because `ci` is what everyone calls
those files. Omit the scope when nothing is left to name, as for
`src/lib/utils.ts`, root config files, or a change spanning several units.

End condition: the scope names a directory that exists in the repo, or it is
`ci`, or there is no scope.

## 5. Write the message

- The subject is one line of about 60 characters at most, with no full stop.
  It takes its mood and capitalisation from step 3's shape, so a repo writing
  "Add retry to the poller" keeps the capital A.
- A body is for a reason the subject and the diff do not already carry: one or
  two bullets, and the message ends at the last one.
- The message carries no trailer of any kind, `Co-Authored-By` included, even
  when the harness would add one by default.
- Wanting a third bullet means the commit covers too much, so go back to
  step 2 and split it.

For the conventional commits shape, the description is imperative and
lowercase, and the type is one of `feat`, `fix`, `perf`, `refactor`, `test`,
`docs`, `chore`, `style`, `build`, `ci`:

```
type(scope): short description

- optional bullet
```

End condition: the subject fits in roughly 60 characters, carries step 3's
shape, and has no full stop; the body runs to two bullets at most and stops at
the last one; or the run has gone back to step 2 to split the commit.

## 6. Commit

First write the message alone to `commit-message.txt`, replacing any earlier
one. Put it in the scratchpad directory your system prompt names, or when it
names none, in one directory per run from `mktemp -d`. The file keeps quotes,
backticks, and `$` literal in every shell. macOS's bash 3.2 rejects or garbles
a heredoc inside `<( )` when the text holds an unmatched quote or bracket,
such as a single apostrophe. Writing the file before the snapshot means that,
should that directory sit inside the repo, step 7 does not take the file for a
hook's output.

Then record a snapshot for step 7: the output of `git status --porcelain
-uall`, plus a hash of the held-back lines of every partly staged path. Its
in-progress entries, the ones with a letter in the second column (` M`, `MM`,
`AM`) and the untracked `??` ones, hold work the user already had in progress.
A partly staged path has a letter in both columns, such as `MM`, `AM`, or `MD`:

```bash
git diff --no-color --no-ext-diff -U0 -- <path> | grep '^[-+]' | git hash-object --stdin
```

Then commit from the message file:

```bash
git commit -F "<message path>"
```

Let the hooks run. When one blocks the commit, step 7 handles it, and
`--no-verify` is never the way past it. Create a new commit every time. When
the user wants a change folded into the commit before it, say that amending
rewrites history and ask them to confirm first.

End condition: the message file and the snapshot, with a hash for every
partly staged path, are written in that order before the commit runs, and
`git commit` has returned with its exit status and any hook output captured,
or the run is waiting on the user to confirm an amend.

## 7. Handle what the hooks did

There is nothing to handle only when `git commit` exited zero, every partly
staged path still gives the hash the snapshot kept, and `git status
--porcelain -uall` lists no path beyond the snapshot's in-progress entries. A
hook can rewrite a staged file and still pass, so check all three. Otherwise
read [references/hooks.md](references/hooks.md) and handle the case it
matches.

End condition: those three checks hold, or the reference's case has run to
one of its endings.

## 8. Push, when asked

Only on `/eng:commit push` or a direct request to push. Read
[references/push.md](references/push.md) and follow it. It resolves the remote
and the default branch, stops on a detached `HEAD` or a repo with no remote,
and asks before a push from the default branch, with the default unknown, or
from a branch that tracks another one, and after a rejection.

End condition: the reference's push step reached one of its endings, or no
push was asked for.

## 9. Confirm

Print one line per commit this run created, so a run that split three groups
or added a hook fix-up prints each of them:

```bash
git log --oneline -<commits this run created>
```

End condition: every commit this run created is in that output, newest first,
and nothing the run did not create sits above them.
