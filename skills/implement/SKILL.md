---
name: implement
description: Use when the user approves a plan or names the exact change to make. Carries the change through in the repo's own patterns, tests the behaviour that changed, splits work across subagents only where parts are independent, and corrects docs the change makes false.
---

# Implement

## What this does

It carries an agreed change into the code, tests what changed, corrects what
the change made false, and hands the result to `eng:review-diff`.

## When it runs

When the user approves a plan ("proceed", "go ahead", "do items 2 and 4") or
names the exact change. A request to investigate or plan is not approval, and
goes to `eng:investigate`. A request to review goes to `eng:review-diff`.
Committing waits for its own request.

## How to use it

Approve the plan or name the change. You get the change with its tests, then
a `eng:review-diff` report saying whether it is ready.

---

## Step 1: Name what is being done, and where

Before the first edit, state in one line: the plan or request being followed,
the items approved, the directory, the branch, and the commit work starts from
(`git rev-parse --show-toplevel`, `git branch --show-current`,
`git rev-parse --short HEAD`). When only some items are
approved, do only those.

**Done when:** that line is written and every edit after it lands in the
named directory.

## Step 2: Make the change

Take one change at a time. Where it alters behaviour, write its test at the
level step 3 names, watch it fail on the code as it stands, then make it pass.
Match the nearest existing example of the same kind in this repo, and prefer
the clean solution the codebase would want over the smallest diff. A change
the plan does not cover waits for the user, unless an approved item needs it
to work, and the report names it. When the plan sketched an interface, fill
one body at a time against the sketch and run the typecheck after each.

A rename, retype, or move that breaks callers goes expand, migrate, contract,
as the plan's items or, with no plan, in that order, and one that touches
stored or serialized data calls the Skill tool with `eng:blast-radius` first.
Before removing a guard, a retry, or a special case, call the Skill tool with
`eng:why`, even when the request named the removal. When it finds a reason the
code still serves, keep the code and bring the reason back to the user.

Keep agreed signatures. Stop and bring the problem back when friction repeats:
the same workaround in unrelated places, unrelated edge cases each needing
their own branch, a cast or `any` needed to compile, callers needing to know
internals, a lock where the plan said nothing was shared. Say what the plan
got wrong. A few hard cases in the data leave the plan standing.

Parts that touch disjoint files can run in parallel subagents, as
[references/parallel.md](references/parallel.md) describes.

**Done when:** every approved item is in the code, or the run has stopped
with the plan's flaw named, the reason `eng:why` found for keeping code, a
change the plan does not cover, or a parallel part's failure.

## Step 3: Test the behaviour that changed

Test at the level a caller sees. For a Node API, call the Skill tool with
`eng:tdd-node-api`. Run targeted tests as you go, and the repo's full check
command (lint, typecheck, tests) at the end.

A bug fix's test comes from the reproduction, at the seam the call site hit,
named after what broke. Say in one sentence why the fix makes it pass. When no
seam reproduces the bug honestly, write that down in the report instead,
because the architecture is what stops the bug being locked in.

**Done when:** each change in behaviour has a test seen failing first and now
passing, or one that passed on the old code is reported with what that means,
or a bug's missing seam is on the record, and the full check passes. Or a
failure is reported with its output, or the run is waiting on the user to
name the seam, or the repo has no tests and the report says so.

## Step 4: Correct what the change made false

Search for every place that describes the changed behaviour: docs, READMEs,
comments, help text, the strings a script prints, `AGENTS.md`. Re-derive each
from the new behaviour rather than editing the sentence nearest the change.
Code comments follow `eng:plain-writing`'s code comments reference.

**Done when:** the terms searched and the files corrected are listed, or the
search found nothing that described the change.

## Step 5: Review

Call the Skill tool with `eng:review-diff`.

**Done when:** `eng:review-diff` reports ready, or reports what remains.

## Report

What changed, by file. Every check run, with its result. Anything done outside
the plan. What remains. When the repo has a `verify-<app>` skill, name it so
the user can run it.

---

The friction tells in step 2 are adapted from the `architect` skill in
cursor/plugins pstack, by Lauren Tan (MIT).
