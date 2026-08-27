---
name: diagnose-bug
description: A gated debugging loop for bugs that resisted the obvious fix.
disable-model-invocation: true
---

# Diagnose bug

## What this does

It forces a reproducible failing signal before any fix is attempted, then
works from that signal to a root cause. The gates exist because the default
failure mode is guessing a fix from a stack trace and declaring victory when
the error stops appearing.

## When to use it

Reach for it when a bug survived the first obvious fix, when the cause is not
in the stack trace, when it only reproduces sometimes, or when a performance
regression has no obvious source.

Skip it for a bug you already understand. A typo does not need six phases.

## How to use it

Type `/diagnose-bug` and describe the symptom. The agent will not propose a
fix until phase 5, and it will say which phase it is in as it goes.

---

## Phase 1: Get it red

Build the smallest thing that fails on this bug, reliably, on demand.

That is usually a test, but a script or a curl command counts. What matters
is that you can run one command and watch it fail, and that it fails for this
bug and not for something nearby.

Say out loud what the loop is and how long it takes to run. A loop that takes
two minutes will get run three times. A loop that takes two seconds will get
run fifty times, and that difference decides whether the rest of this works.

If the bug will not reproduce, that is the whole problem right now. Add
logging to the failing environment and go get a reproduction. When you run
out of ways to get one, stop and say so: list what you tried, and ask the
user for an environment that reproduces it, a captured artifact, or
permission to instrument production.

**Gate:** one command, run twice, fails both times, for this bug. Or the run
has stopped with what was tried listed and that ask put to the user.

## Phase 2: Shrink it

Cut everything the failure does not need. Remove middleware, drop fields from
the payload, replace the database call with a literal, delete branches.

After each cut, run the loop. If it still fails, keep the cut. If it passes,
put it back, and note what you just learned: the thing you removed is part of
the cause.

Stop when every remaining piece is load-bearing.

**Gate:** the reproduction is small enough to read in one screen, and every
line in it is needed.

## Phase 3: Name the hypotheses

Write three to five hypotheses, ranked, before testing any of them. Producing
one anchors you on the first plausible idea, and the shrunken reproduction is
usually consistent with several.

For each, write the observation that would prove it wrong. If you cannot name
one, that hypothesis is too vague to test. Sharpen it until you can.

**Gate:** three to five ranked claims on the record, each with the
observation that would falsify it.

## Phase 4: Instrument

Take the top hypothesis and go and make its observation. Log the value, set
the breakpoint, print the query the ORM actually sent, capture the timing.

Tag every log you add with one unique marker, `[DEBUG-<4 hex>]`, so phase 6
clears them with a single grep.

Read what came back. If it kills the hypothesis, cross it off and take the
next one. If the whole list dies, go back to phase 3 with what you learned.
Do not adjust a hypothesis to fit and carry on. That is how a wrong theory
survives three rounds of evidence.

**Gate:** you have looked at real output from a real run, and it either
confirms one hypothesis or has killed every one on the list.

## Phase 5: Fix the cause

Fix the thing the evidence pointed at, not the place the error surfaced.

A null check where the crash happened is not a fix if the value was never
supposed to be null. Trace back to where it became null and fix it there.

Run the loop. It goes green.

**Gate:** the loop passes and you can say, in one sentence, why the change
makes it pass.

## Phase 6: Lock it in

Turn the phase 1 reproduction into a permanent test in the suite, at a seam
that exercises the bug the way the call site hit it. Give it a name that says
what broke, so the next person who breaks it knows what they did.

Where no seam does that honestly, a test there would give false confidence.
Record that instead: the architecture is what stops this bug being locked
down, and that is itself a finding.

Run the full suite. Then remove the phase 4 logging.

**Gate:** the full suite green, `grep -rF '<the phase 4 marker>' .` returning
nothing, and either a committed test that fails on the old code and passes on
the new, or the missing seam written down. Use `-F`, because those brackets
are a character class to grep otherwise and the search matches almost every
line.

---

## Rules across all phases

Change one thing at a time. Two changes and a green run tells you nothing
about which one mattered.

Read a credential from an environment variable rather than pasting it into
the loop, so a loop you run fifty times does not leave the value in shell
history.

Say what you actually know versus what you are assuming. "The handler
receives an empty array" and "I think the handler receives an empty array"
are different, and mixing them up is how phases 3 and 4 collapse into
guessing.

If you find yourself trying a fix to see if it helps, you are back in phase
3 and you skipped the hypothesis.

---

Adapted from the `diagnosing-bugs` skill in mattpocock/skills (MIT).
