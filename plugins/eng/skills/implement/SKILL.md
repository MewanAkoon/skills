---
name: implement
description: Use when the user approves a plan or names the exact change to make.
---

# Implement

Carry an agreed change into the code, test what changed, correct what it made
false, review it, and deliver it as the Delivery that covers the run allows. A
request to investigate or plan goes to `eng:investigate`, and one to review a
PR or diff goes to `/code-review`.

**The fast path.** A change the user names exactly, of a few lines with no
behaviour to design, skips the test-first loop and the intent check, but for
the one [references/security.md](references/security.md) asks for: get onto
the branch as step 1 says, make it, run the repo's checks, correct what it
made false, review it as step 5 says, and deliver it as step 6 says.
Everything else runs every step.

## Step 1: Name what is being done, and where

Before the first edit, state in one line: the plan or request, the items
approved, the directory, the branch, the commit work starts from
(`git rev-parse --short HEAD`), and the files already changed
(`git status --short`). Do only the items approved. Then get onto the
work's branch, as [references/deliver.md](references/deliver.md) says under
"The branch", or create or join the stack, as
[references/stack.md](references/stack.md) says.

**Done when:** that line is written and `HEAD` in the work's directory is on
the work's branch.

## Step 2: Make the change

One change at a time. Where it alters behaviour, work test-first as
[references/tdd.md](references/tdd.md) says. Match the nearest example of the
same kind in the repo, and prefer the clean solution the codebase would want
over the smallest diff. Keep agreed signatures.

A decision the plan did not settle is a ruling, logged as `deliver.md` says,
when it serves the plan's goal. A change that would alter the goal stops the
run. So does friction that repeats: the same workaround in unrelated places, a
cast or `any` needed to compile, callers needing internals. Say what the plan
got wrong.

A rename, retype, or move that breaks callers goes expand, migrate, contract,
and one touching stored or serialized data calls `eng:blast-radius` first.
Before removing a guard, retry, or special case the user did not name, call
`eng:why`, and keep the code when it finds a reason that still holds.

Parts that touch disjoint files can run in parallel subagents, as
[references/parallel.md](references/parallel.md) says.

**Done when:** every approved item is in the code, or the run has stopped with
its reason named.

## Step 3: Test the behaviour that changed

Test at the level a caller sees. Run targeted tests as you go and the repo's
full check (lint, typecheck, tests) at the end. A bug fix's test comes from
the reproduction, named after what broke.

**Done when:** the full check passes, and each change in behaviour has a test
seen failing on its assertion, then passing, or the report says why not.

## Step 4: Correct what the change made false

Search for every place that describes the changed behaviour: docs, READMEs,
comments, help text, the strings a script prints, `AGENTS.md`. Re-derive each
from the new behaviour. Code comments follow `eng:plain-writing`.

**Done when:** the terms searched and the files corrected are listed.

## Step 5: Review

Follow [references/review.md](references/review.md). On the fast path, run
`code-review` at `medium` in place of `high`, with no intent check but the
security one.

**Done when:** its report says ready, or not ready with each blocker named, or
the review still runs in the background and the reply says so.

## Step 6: Deliver

Follow [references/deliver.md](references/deliver.md) for the Delivery that
covers the run: an approved plan's, the default one for a change the user
named, or the follow-up one on the user's open PR.

**Done when:** its hand-back is written.

## Report

What changed, by file; every check run, with its result; anything done
outside the plan; the review report; what was not checked; any risk.

---

The friction tells are adapted from the `architect` skill in cursor/plugins
pstack, by Lauren Tan (MIT).
