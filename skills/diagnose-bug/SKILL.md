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
fix until phase 3, and it will say which phase it is in as it goes.

---

## Phase 1: Get it red

Build the smallest thing that fails on this bug, reliably, on demand.

That is usually a test, but a script or a curl command counts. What matters
is that you can run one command and watch it fail, and that it fails for this
bug and not for something nearby.

Say out loud what the loop is and how long it takes to run. A loop that takes
two minutes will get run three times. A loop that takes two seconds will get
run fifty times, and that difference decides whether the rest of this works.

If the bug will not reproduce, that is the whole problem right now. Add logging
to the failing environment and go get a reproduction.

After two rounds of logging with no reproduction, stop and hand back what the
logging did show, plus the next instrumentation you would add. A bug you cannot
trigger is not one you can fix from here.

**Gate:** one command, run twice, fails both times, for this bug.

## Phase 2: Shrink it

Cut everything the failure does not need. Remove middleware, drop fields from
the payload, replace the database call with a literal, delete branches.

Make the cuts on a scratch branch or a copy, and keep a list of what you cut.
Phase 5 changes the real code, and it should not arrive carrying phase 2's
deletions.

After each cut, run the loop. If it still fails, keep the cut. If it passes,
put it back, and note what you just learned: the thing you removed is part of
the cause.

Stop when every remaining piece is load-bearing.

**Gate:** the reproduction is under 40 lines and every line in it is needed.

## Phase 3: Name a hypothesis

Write one sentence: what you think is happening and why the shrunken
reproduction is consistent with it.

Then write the observation that would prove you wrong. If you cannot name
one, the hypothesis is too vague to test. Sharpen it until you can.

**Gate:** a specific claim on the record, plus the observation that would
falsify it.

## Phase 4: Instrument

Go and make that observation. Log the value, set the breakpoint, print the
query the ORM actually sent, capture the timing.

Read what came back. If it contradicts the hypothesis, go back to phase 3
with what you learned. Do not adjust the hypothesis to fit and carry on. That
is how a wrong theory survives three rounds of evidence.

Output that is neither a confirmation nor a refutation sends you back to phase 3
as well. Sharpen the observation until it can only come out one way.

**Gate:** you have looked at real output from a real run, and it either
confirms or kills the hypothesis.

## Phase 5: Fix the cause

Fix the thing the evidence pointed at, not the place the error surfaced.

A null check where the crash happened is not a fix if the value was never
supposed to be null. Trace back to where it became null and fix it there.

Run the loop. If it is still red, the evidence pointed at the wrong thing, so
go back to phase 3 rather than patching until the red goes away.

**Gate:** the loop passes and you can say, in one sentence, why the change
makes it pass.

## Phase 6: Lock it in

Turn the phase 1 reproduction into a permanent test in the suite. Give it a
name that says what broke, so the next person who breaks it knows what they
did.

Before committing anything, prove the test catches the bug. Stash only the
files you changed in phase 5, by naming them, and pass `-u` so a file the fix
added goes with them:

```bash
git stash push -u -- src/path/you/fixed.ts
```

Two things this avoids. A bare `git stash` takes the new test along with the
fix, and a run with no test present reports nothing to do, which reads like a
pass. Without `-u`, a fix that added a new file is refused with "did not match
any file(s) known to git", so nothing is stashed and the test passes when it
should fail.

With the fix stashed and the test still on disk, run the test and watch it
fail. Then `git stash pop` and watch it pass.

Run the full suite. Then remove the temporary logging from phase 4, and diff
against the branch point rather than the working tree, because a commit empties
`git diff` and hides whatever went in with it.

Ask before committing. The user may want the change on a different branch.

**Gate:** the new test runs and fails with the fix stashed, passes once it is
restored, the full suite is green, and `git diff <branch-point>` shows no phase
4 logging.

---

## Rules across all phases

Change one thing at a time. Two changes and a green run tells you nothing
about which one mattered.

Say what you actually know versus what you are assuming. "The handler
receives an empty array" and "I think the handler receives an empty array"
are different, and mixing them up is how phases 3 and 4 collapse into
guessing.

If you find yourself trying a fix to see if it helps, you are back in phase
3 and you skipped the hypothesis.

---

Adapted from the `diagnosing-bugs` skill in mattpocock/skills (MIT).
