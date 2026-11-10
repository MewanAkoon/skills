---
name: implement
description: Use when the user approves a plan or names the exact change to make. Carries the change through in the repo's own patterns, tests the behaviour that changed, splits work across subagents only where parts are independent, and corrects docs the change makes false.
---

# Implement

## What this does

It carries an agreed change into the code, tests what changed, corrects what
the change made false, and reviews the result through `/code-review`.

## When it runs

When the user approves a plan ("proceed", "go ahead", "do items 2 and 4") or
names the exact change. A request to investigate or plan is not approval and
goes to `eng:investigate`. One to review a PR, a branch, or a diff goes to
`/code-review`. Committing waits for its own request.

## How to use it

Approve the plan or name the change. You get the change, its tests, and a
review report.

---

## Step 1: Name what is being done, and where

Before the first edit, state in one line: the plan or request, the items
approved, the directory, the branch, the commit work starts from
(`git rev-parse --short HEAD`), and any files already changed
(`git status --short`). Do only the items approved.

**Done when:** that line is written and every edit after it lands in the
named directory.

## Step 2: Make the change

Take one change at a time. Where it alters behaviour, work test-first as
[references/tdd.md](references/tdd.md) sets out, before any code. Match the
nearest example of the same kind in this repo, and prefer the clean solution
the codebase would want over the smallest diff. A change the plan does not cover
waits for the user, unless an approved item needs it to work, and the report
names it. When the plan sketched an interface, fill one body at a time against
the sketch and run the typecheck after each.

Before a rename, retype, or move that breaks callers, or removing a guard, a
retry, or a special case, even one the request named, read
[references/risky.md](references/risky.md).

Keep agreed signatures. Stop and bring the problem back when friction repeats:
the same workaround in unrelated places, unrelated edge cases each needing
their own branch, a cast or `any` needed to compile, callers needing to know
internals, a lock where the plan said nothing was shared. Say what the plan
got wrong. A few hard cases in the data leave the plan standing.

Parts that touch disjoint files can run in parallel subagents, as
[references/parallel.md](references/parallel.md) describes.

**Done when:** every approved item is in the code, or the run has stopped
with its reason named, which is the plan's flaw, a reason `eng:why` found to
keep code, a change the plan does not cover, a failed parallel part, or a
`tdd.md` stop: a seam to agree, a suite that will not run, or a test that
never reaches the code.

## Step 3: Test the behaviour that changed

Test at the level a caller sees. Run targeted tests as you go, and the repo's
full check (lint, typecheck, tests) at the end.

A bug fix's test comes from the reproduction, at the seam the call site hit,
named after what broke. Say in one sentence why the fix makes it pass. When no
seam reproduces the bug honestly, say so in the report.

**Done when:** the full check passes and each change in behaviour has a test
seen failing then passing, a test that passed on the old code reported with
what that means, or a bug's missing seam on the record. Or a failure is
reported with its output, or the report says the repo has no tests.

## Step 4: Correct what the change made false

Find every place that describes the changed behaviour: docs, READMEs,
comments, help text, the strings a script prints, `AGENTS.md`. Re-derive each
from the new behaviour.
Code comments follow `eng:plain-writing`'s code comments reference.

**Done when:** the terms searched and the files corrected are listed, or the
search found nothing that described the change.

## Step 5: Review

Read [references/review.md](references/review.md) first and follow it.

**Done when:** its report says ready, or not ready with each blocker named, or
the review still runs in the background and the reply says so.

## Report

What changed, by file. Every check run, with its result. Anything done outside
the plan. The review report. What was not checked, and any risk.

**Done when:** each of those is in the report, or marked none.

---

The friction tells in step 2 are adapted from the `architect` skill in
cursor/plugins pstack, by Lauren Tan (MIT).
