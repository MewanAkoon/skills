# Review loop

Read this at implement's step 5. Never pass a bare level, `ultra`,
`--comment`, or `--fix`.

## 1. Snapshot

Make a directory once with `mktemp -d` in the scratchpad, and write its
literal path for `R` in every command. A snapshot holds every file, untracked
too, keeps `.claude/plans` and `.claude/handoffs` as `HEAD` has them, and
leaves your index, branch, and refs alone:

```bash
cp "$(git rev-parse --git-dir)/index" "$R/index"
GIT_INDEX_FILE="$R/index" git add -A
GIT_INDEX_FILE="$R/index" git reset -q -- ':/.claude/plans' ':/.claude/handoffs'
tree="$(GIT_INDEX_FILE="$R/index" git write-tree)"
git commit-tree "$tree" -p <parent> -m review | tee -a "$R/snapshots"
```

`<parent>` is the commit step 1 named, then the last snapshot.

## 2. Check and review

Run the repo's lint, typecheck, and tests in report-only modes. Call the Skill
tool with `code-review` and `high <parent>..<snapshot>`, hashes written out.
In round 1, brief the intent check in [intent-check.md](intent-check.md) at
the same time. When a later round finds nothing to fix, brief it once more on
that snapshot, with step 1's commit as `<parent>`, before the report. When
`code-review` runs in the background and the turn must end first, say so, and
carry on from section 3 when it reports.

## 3. Triage

Open the code at every finding. Mark it valid, invalid with the reason, or a
judgement call, and blocking, should-fix, or nit. Keep a ledger in
`$R/findings`, one line per finding across rounds: round, `file:line`, the
point, the marks, and what was done. Before fixing, read it:

- A finding that would undo an earlier fix or reverse a ruling is a judgement
  call: it goes in the report with both sides, and the code stays.
- A finding the ledger shows as invalid or left stays so without new
  evidence, such as a failing run.
- A finding about code the change did not touch, or an improvement the plan
  did not ask for, goes to follow-ups.

## 4. Fix, until clean

Fix valid blocking and should-fix findings, one-line nits, and every check
the change broke, then go back to section 1 for a new snapshot and a review
of only what changed. Stop when a round finds nothing valid to fix. Stop
early, not ready, when two rounds in a row fail to lower the count of open
valid findings, or after six rounds.

## 5. Report

Ready only when every check passes, no valid blocking finding remains, the
intent check ran on round 1 and on the final tree, except on implement's fast
path, and the last review saw the final tree. List what was fixed, each
finding left and why, the follow-ups, and what was not checked. Name
`/security-review` when the diff touches authentication, payments, secrets, or
cryptography, and `/run` when the change alters what the running app does, or
give the commands that show it running.

**Done when:** the report says ready or not ready, and why.

## Without code-review

Where `code-review` is missing or fails, give the intent check a bug lens in
every round, and report that the built-in did not run.
