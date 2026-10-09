# Plan template

Every section gets content or the word "none". Keep each to what a reviewer
needs to approve or reject the plan. Point at code with `file:line` rather
than pasting it.

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
a recommendation.
