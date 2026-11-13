# Plan template

Every section gets content or the word "none". Keep each to what a reviewer
needs to approve or reject the plan. Point at code with `file:line` rather
than pasting it.

A plan file lives in `.claude/plans` of the checkout the work happens in,
and opens with two lines: `Plan name: <name>`, short and in lowercase with
hyphens, and `Status: awaiting approval` once it is presented. A plan written
in an earlier session waits again once it is changed in this one. When the user
wants one approved again, set its status back to awaiting approval. Approval of a plan in chat alone grants no writes. How the user
approves, and what that lets the run do, is in `eng:implement`'s
`references/deliver.md`.

**Goal.** One or two sentences: what will be true when this is done.

**Current behaviour.** What happens today, with the `file:line` that makes it
happen.

**Expected behaviour.** What should happen instead, and who said so: the
ticket, the thread, the user.

**Constraints.** What the change has to live with: types and callers it must
match, patterns the repo already uses, limits a source named.

**Root cause.** For a bug, the cause and the run that showed it. For a
feature, the reason the current code cannot do it.

**Approach.** The change in a paragraph. When there was a real alternative,
name it and say in one sentence why it lost.

**Changes.** Grouped by area, each naming the file and what changes in it.
Number the items so the user can approve some of them. A rename, retype, or
move that would break every caller at once becomes three items in order:
expand (add the new form beside the old), migrate the callers, then contract
(remove the old form), so each item leaves the checks passing.

**Tests.** For each change in behaviour, the test that covers it and the level
it runs at. For a bug, the reproduction that becomes the regression test.

**Docs.** Every doc, comment, or help string the change makes false.

**Risks.** What could break elsewhere, with the evidence level from
`eng:blast-radius` when it ran. A conflict with an ADR goes here.

**Out of scope.** What this plan deliberately leaves alone.

**Open questions.** Decisions the user has to make, each with the options and
a recommendation. A plan is ready to approve only when every one has an
answer. Until then, say so and present it as a draft.

**Delivery.** What approval of this plan lets the run do without asking
again: a line `Branch: <branch>`, `feature/`, `fix/` or `chore/` plus a short
name; the commits, grouped as they will land; push to that branch; the PR, a
draft until the post-PR review loop and CI are clean unless this says
otherwise, and its title; each issue write, named as `eng:implement`'s
`references/deliver.md` says; the checks that must pass; and the post-PR review
loop, with the standing rules for what review may find. Leave out anything
that should wait for the user. Merges, releases, tags, deploys, force pushes
and pushes to the default branch never go here.

**Progress.** Empty at first. The run adds each ruling and each pushed
commit, so a new session can resume from the file.

## Walk-through

Before asking anything, go through each item in Changes as if implementing it
now: the files opened, the tests written, the review, the commits, the PR.
List every decision point it hits. Each one the code or the repo's patterns
answer goes into the plan. Every other one goes into Open questions. For what
cannot be known until the run, such as what review will find or a check that
still fails after the last review round, ask for a standing rule instead.
Ask them one at a time, each with a recommendation, waiting for the answer
before the next, and write each answer in. Repeat only if the answers raise
new ones. What the walk-through still misses becomes a ruling during the run.

## Before presenting it

Read the plan once more as the person who has to approve it:

- Coverage: every requirement in the request has an item, and every item
  traces back to one.
- Names: a type, function, or file is called the same thing in every item that
  mentions it.
- Proportion: the plan is no bigger than the change. A one-file fix gets a few
  lines, not every section padded out.

Fix what this turns up before step 7's cross-check.

---

The pass above is adapted from the `writing-plans` skill in obra/superpowers
(MIT).
