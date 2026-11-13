# Plan template

A plan file opens with its title. Every section gets content or "none", kept
to what a reviewer needs to approve or reject it. Point at code with
`file:line` rather than pasting it.

**Goal.** What will be true when this is done.

**Current behaviour.** What happens today, with the `file:line` behind it.

**Expected behaviour.** What should happen instead, and who said so.

**Constraints.** What the change must live with.

**Root cause.** For a bug, the cause and the run that showed it. For a
feature, why the current code cannot do it.

**Approach.** The change in a paragraph, and a real alternative with why it
lost. A new or reshaped interface is sketched here: the call site first, then
the types and signatures with empty bodies.

**Changes.** Numbered, grouped by area, each naming its file. A rename,
retype, or move that breaks callers becomes three items: expand, migrate the
callers, contract, so each leaves the checks passing.

**Tests.** For each change in behaviour, its test and the level it runs at.
For a bug, the reproduction that becomes the regression test.

**Docs.** Every doc, comment, or help string the change makes false.

**Risks.** What could break elsewhere, with `eng:blast-radius`'s evidence
level when it ran, and any conflict with an ADR.

**Out of scope.** What the plan leaves alone.

**Open questions.** Each with options and a recommendation. Until each has an
answer, the plan is a draft.

**Delivery.** What approval lets the run do without asking again: `Branch:
<feature/, fix/ or chore/><ticket key>-<short name>`, lowercase, or
`<type>/<short name>` without a ticket; `Base: <branch>`, with the default
branch as fallback when the base is not on origin yet; the commits as they
will land; the push; the PR and its title, opened as a draft and marked ready
by `eng:implement`'s `references/deliver.md`; each issue write, named as
`eng:implement`'s `references/deliver.md` says, a new issue sized now with the
values in `eng:issue`'s [estimate.md](../../issue/references/estimate.md) so
the run asks nothing; the checks that must pass; and standing rules for what
review may find. Delivery names no start condition that waits on work outside
the session. Merges, releases, tags, deploys, force pushes and pushes to the
default branch never go here.

**Progress.** Empty at first. The run adds each ruling, each pushed commit,
and `Reviewed: <sha>` for the last pushed commit the review loop read.

## Walk-through

Before presenting, go through each change as if implementing it: files,
tests, review, commits, PR. Each decision the code or the repo's patterns
answer goes in the plan. Ask the rest one at a time, each with a
recommendation, and write each answer in. For what only the run can know,
such as what review will find, ask for a standing rule.

