---
name: review-diff
description: Use before reporting implementation work as done, and when the user asks to review, validate, or finalise a branch, a PR, or uncommitted changes. Runs independent reviewer passes against the repo's written standards, the plan, and a smell baseline, then fixes what holds up and checks again.
---

# Review diff

## What this does

It pins a diff, runs the repo's checks, and sends the diff to `eng:reviewer`
subagents, one per lens. It checks every finding against the code, fixes what
holds up in your own work, and repeats until a round comes back clean.

## When it runs

Before handing back implementation work, and when asked to review a branch, a
PR, or uncommitted changes. A question about what a change breaks elsewhere,
and nothing more, goes to `eng:blast-radius`. Claude Code's bundled
`/code-review` and `/simplify` run only when the user types them, because one
can post to the PR and the other edits.

## How to use it

Nothing to invoke after `eng:implement`. Otherwise say "review this PR", or
"another pass" after a review. Step 7 says what comes back.

---

## Step 1: Pin the mode and the range

Fix mode covers changes this session made, and a branch the user asks to have
fixed. Report mode covers the rest, a report-only request included, and edits
nothing. For a PR, or any report mode run, read
[references/report-mode.md](references/report-mode.md).

Snapshot the working tree, new files included, so a later round can diff
against it. `R` is a directory the first round makes with
`mktemp -d "<dir>/review.XXXXXX"`, where `<dir>` is the scratchpad your system
prompt names, or `${TMPDIR:-/tmp}` when it names none. Write its path
wherever `$R` appears, in every round. `<start>` is the commit `eng:implement`
named for this session's work, or `$(git merge-base HEAD <base>)` for a branch
or a PR:

```bash
cp "$(git rev-parse --git-dir)/index" "$R/index"
GIT_INDEX_FILE="$R/index" git add -A
tree="$(GIT_INDEX_FILE="$R/index" git write-tree)"
git diff -M <start> "$tree" > "$R/diff.patch"
echo "$tree" >> "$R/trees"
```

**Done when:** the mode, the base, and the diff file's path are stated, or
the user has been asked for the base or to check out a PR, or the review has
stopped on an empty diff or a failed fetch.

## Step 2: Get the intent

Take it from the plan file, the ticket, the PR body, or the user's line,
never from the code.

**Done when:** one line of intent is stated, or "no stated intent".

## Step 3: Run the checks

Find the repo's lint, typecheck, and test commands in its package manifest,
`Makefile`, or CI workflow. Run each once in the mode that reports without
writing, such as `prettier --check` rather than `--write`. Save the output to
`$R/checks.txt`.

**Done when:** each command is listed with its exit code, or the repo has
none.

## Step 4: Send the reviewers

Spawn `eng:reviewer` subagents in parallel, one per lens:

- **standards**: written standards and the smell baseline. Always.
- **intent**: intent, behaviour, and tests. Always.
- **regressions**: what breaks elsewhere. When shared code changed.
- **claims**: what the changed prose says. When prose changed.

A diff under about 150 changed lines in one area gets one reviewer with every
lens that applies. Each brief names the lenses, the repo root, the paths to
`diff.patch` and `checks.txt`, the intent line, the plan file, and `$R/probe`
for probes. Without a `eng:reviewer` agent, brief general-purpose agents the
same way and tell them to edit nothing.

**Done when:** every lens sent has returned findings or "none".

## Step 5: Triage

Remove duplicates. Open the code at each finding yourself. Mark it valid,
invalid with the reason, or a judgement call, and rate it blocking,
should-fix, or nit.

**Done when:** every finding has a verdict and a rating.

## Step 6: Fix and go again

Fix every valid blocking and should-fix finding in the change under review,
every check from step 3 that the change broke, and nits that take a line. A
finding in code the change did not touch goes in the report. Run step 3
again, take a new snapshot, and diff it against the previous tree in
`$R/trees`. Send one `eng:reviewer` with every lens over that diff, with the
earlier findings to confirm as fixed. Another pass the user asks for is one
more round, over the whole range when nothing changed since the last.

**Done when:** a round finds nothing blocking or should-fix and the checks the
change touched pass, or three rounds have run and what remains is listed with
the reason each stayed, or the review is in report mode.

## Step 7: Report

Ready or not ready. What was fixed. What remains, and why. Every check run,
with its result.

**Done when:** the report names every finding from step 5 as fixed, invalid,
or remaining.

---

The parallel lenses are adapted from the `code-review` skill in
mattpocock/skills (MIT).
