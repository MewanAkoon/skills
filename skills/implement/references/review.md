# Review loop

Read this at implement's step 5. Review runs through the built-in `code-review`,
plus an intent check it lacks. Never pass `ultra`, `--comment`, or `--fix`.

## 1. Snapshot

Make a directory once with `mktemp -d` under the scratchpad your system prompt
names, or `${TMPDIR:-/tmp}`, and write its literal path for `R` in every
command. A snapshot holds every file, untracked ones included, and leaves your
index, branch, and refs alone:

```bash
cp "$(git rev-parse --git-dir)/index" "$R/index"
GIT_INDEX_FILE="$R/index" git add -A
tree="$(GIT_INDEX_FILE="$R/index" git write-tree)"
git commit-tree "$tree" -p <parent> -m review | tee -a "$R/snapshots"
```

`<parent>` is the commit implement's step 1 named, then the last snapshot.

**Done when:** the new snapshot's hash is printed.

## 2. Check and review

Run the repo's lint, typecheck, and tests in their report-only modes. Then
call the Skill tool with `code-review` and the arguments
`medium <parent>..<snapshot>`, hashes written out.

In every round, at the same time, brief a general-purpose subagent with the
intent check. In the first round it covers the whole change: each plan item
done, missing, extra, or wrong, quoting the plan line; each bug fix's test seen
failing on the old code, extracted from the top of the tree with
`mkdir "$R/old" && git -C "$(git rev-parse --show-toplevel)" archive <parent> | tar -x -C "$R/old"`,
or reported as unproven when the extract lacks the dependencies, env, or
fixtures to run it; every changed sentence of prose backed by a `file:line`.
In a later round it checks, on that round's range, that the fix left each plan
item it touched done.
Name the files implement's step 1 found already changed, so it does not call
them extra. It edits, commits, and posts nothing, writes nothing outside this
machine, starts no subagents, and writes only under `R`.

**Done when:** the review's result and the intent check's are in. In the
terminal `code-review` runs in the background: if the turn must end first, say
the review is still running, and carry on from section 3 when it reports.

## 3. Triage

Open the code at every finding. Mark it valid, invalid with the reason, or a
judgement call, and blocking, should-fix, or nit. Judgement calls go to the
user in the report, not into the code.

**Done when:** every finding has both marks.

## 4. Fix, at most twice

Fix valid blocking and should-fix findings, one-line nits, and every check
the change broke. Then go back to section 1, after a fix of any size: a new
snapshot on the last one, and a review of only what changed. The third review
is the last, and fixes nothing: what it finds goes in the report.

**Done when:** the last review ran on the tree as it now stands.

## 5. Report

Ready only when every check passes, no valid blocking finding remains, the
intent check ran in every round, and the last review saw the final tree.
Otherwise not ready, with each reason. List what was fixed, each finding left
and why, each claim beside its evidence (a check, a test, a `file:line`), and
what was not checked.
Name `/security-review` when the diff touches authentication, payments, secrets,
or cryptography, and `/verify`, or `/run-skill-generator` first, when the change
has a runtime surface.

**Done when:** the report says ready or not ready, and why.

## Without code-review

Where `code-review` is missing or fails, add a bug lens to the intent check,
and say in the report that the built-in did not run.
