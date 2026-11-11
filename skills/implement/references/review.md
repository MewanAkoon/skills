# Review loop

Read this at implement's step 5. Never pass a bare level, `ultra`,
`--comment`, or `--fix`.

## 1. Snapshot

Make a directory once with `mktemp -d` under the scratchpad your system prompt
names, or `${TMPDIR:-/tmp}`, and write its literal path for `R` in every
command. A snapshot holds every file, untracked too, but keeps the plans and
handoffs under `.claude/` as `HEAD` has them. It leaves your index, branch, and
refs alone:

```bash
cp "$(git rev-parse --git-dir)/index" "$R/index"
GIT_INDEX_FILE="$R/index" git add -A
GIT_INDEX_FILE="$R/index" git reset -q -- ':/.claude/plans' ':/.claude/handoffs'
tree="$(GIT_INDEX_FILE="$R/index" git write-tree)"
git commit-tree "$tree" -p <parent> -m review | tee -a "$R/snapshots"
```

`<parent>` is the commit implement's step 1 named, then the last snapshot.

**Done when:** the new snapshot's hash is printed.

## 2. Check and review

Run the repo's lint, typecheck, and tests in their report-only modes. Then
call the Skill tool with `code-review` and the arguments
`high <parent>..<snapshot>`, hashes written out.

In every round, at the same time, brief a general-purpose subagent with the
intent check in [intent-check.md](intent-check.md).

**Done when:** the review's result and the intent check's are in. When
`code-review` runs in the background and the turn must end first, say so,
and carry on from section 3 when it reports.

## 3. Triage

Open the code at every finding. Mark it valid, invalid with the reason, or a
judgement call, and blocking, should-fix, or nit, and log it in the ledger
as [ledger.md](ledger.md) says. A finding that would undo an earlier fix or
a ruling, or improve something outside the plan, is not fixed here.
Judgement calls go in the report, not the code.

**Done when:** every finding has both marks and a ledger line.

## 4. Fix, until clean

Fix valid blocking and should-fix findings, one-line nits, and every check
the change broke. Then go back to section 1: a new snapshot on the last one,
and a review of only what changed. Stop when a round finds nothing valid to
fix. Stop early, not ready, when two rounds in a row fail to lower the count
of open valid findings, or after six rounds.

**Done when:** a round found nothing valid to fix on the tree as it now
stands, or the loop stopped early with its reason named.

## 5. Report

Ready only when every check passes, no valid blocking finding remains, the
intent check ran in every round, and the last review saw the final tree.
Otherwise not ready, with each reason. List what was fixed, each finding left
and why, the follow-ups, each claim beside its evidence, and what was not
checked.
Name `/security-review` when the diff touches authentication, payments, secrets,
or cryptography, and `/run` when the change alters what the running app does.
Where `/run` is missing, give the commands that show the change running.

**Done when:** the report says ready or not ready, and why.

## Without code-review

Where `code-review` is missing or fails, add a bug lens to the intent check,
and report that the built-in did not run.
