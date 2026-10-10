# Debugging a bug that resisted the obvious fix

Read this when a CI check fails, or a bug survived one fix, reproduces only
sometimes, has no cause in the stack trace, or is a performance regression
with no obvious source.

The gates exist because the default failure is guessing a fix from a stack
trace and declaring victory when the error stops appearing. Phases 1 to 4 run
during the investigation, and phase 5 puts the fix in the plan. After
approval, `eng:implement` makes the fix and turns the reproduction into the
regression test.

Investigation leaves the repo's code unchanged. Keep the reproduction, and
every file a loop or a probe writes, such as captured output, in the
scratchpad directory your system prompt names, or under `${TMPDIR:-/tmp}` when
it names none, never in a bare `/tmp` path. A reproduction that has to sit in
the repo, and logging added to the repo's code, are edits: ask before making
them. Remove the logging before presenting the plan, and name the
reproduction's path in it.

## A failing CI check

Read the failure before reproducing anything. For a GitHub Actions check:

```bash
gh pr checks <n>
gh run view <run-id> --log-failed
```

For another CI, use the command or page the repo's docs name. Then work out
whether it fails on the base branch too, because a check that was already red
is not this change's bug.

## Phase 1: Get it red

Build the smallest thing that fails on this bug, reliably, on demand. A test,
a script, or a curl command all count. What matters is one command that fails
for this bug and not for something nearby.

Say what the loop is and how long it takes. A loop that takes two minutes gets
run three times. One that takes two seconds gets run fifty times, and that
difference decides whether the rest of this works.

If the bug will not reproduce, that is the whole problem right now. Add logging
where it fails, asking first as above, and get a reproduction. When you run out
of ways, stop: list what you tried, and ask the user for an environment that
reproduces it, a captured artifact, or permission to instrument production.

A flaky bug needs its failure rate raised first: loop the trigger, add load or
parallel runs, or narrow the timing window, until it fails often enough to
test against. When the bug arrived between a commit that works and one that
does not, script the loop to exit non-zero on the bug and let git bisect find
the commit. Bisect checks out other commits, so run it in a worktree made for
it, under the scratchpad or `${TMPDIR:-/tmp}`:

```bash
git worktree add --detach <dir> HEAD
git -C <dir> bisect start <bad> <good>
git -C <dir> bisect run <script>
git -C <dir> bisect reset
git worktree remove <dir>
```

**Gate:** one command, run twice, fails both times, for this bug, or for a
flaky bug fails in a stated share of runs high enough to test against. Or the
run has stopped with what was tried listed and that request put to the user,
or has stopped to ask before putting a reproduction or logging in the repo.

## Phase 2: Shrink it

Cut everything the failure does not need: middleware, payload fields,
branches. Replace a database call with a literal. After each cut, run the
loop. Still failing: keep the cut. Passing: put it back, because what you
removed is part of the cause.

**Gate:** the reproduction fits on one screen, and every line in it is needed.

## Phase 3: Name the hypotheses

Write three to five hypotheses, ranked, before testing any. One hypothesis
anchors you on the first plausible idea, and a small reproduction is usually
consistent with several. For each, write the observation that would prove it
wrong. A hypothesis with no such observation is too vague to test, so sharpen
it.

**Gate:** three to five ranked claims, each with its falsifying observation.

## Phase 4: Instrument

Take the top hypothesis and make its observation: log the value, set the
breakpoint, print the query the ORM actually sent, capture the timing. Tag
every log line with one marker, `[DEBUG-<4 hex>]`, so one search removes them
all.

A performance regression is measured rather than logged: a baseline from a
timing harness over several runs, a profiler, or the query plan, compared
before and after, and bisected the same way when a fast commit is known.

A result that kills the hypothesis crosses it off, and you take the next. When
the whole list dies, go back to phase 3 with what you learned. Bending a
hypothesis to fit the evidence is how a wrong theory survives three rounds.

**Gate:** the run has stopped to ask before adding logging to the repo, or real
output from a real run either confirms one hypothesis or has killed every one
on the list, and `grep -rF '[DEBUG-<marker>]' .` returns nothing once the
logging is removed. Use `-F`, because the brackets are a character class
otherwise.

## Phase 5: Name the fix

Put the fix in the plan at the place the evidence points to, not where the
error surfaced. A null check at the crash site is not a fix when the value was
never supposed to be null. Say in one sentence why the fix will make the loop
pass.

**Gate:** the plan names the fix, its place, the sentence, and the
reproduction that becomes the regression test.

## Across all phases

Change one thing at a time. Two changes and a pass say nothing about which
one mattered.

Read credentials from an environment variable rather than pasting them into
the loop, so fifty runs leave nothing in shell history.

Keep what you know apart from what you assume. "The handler receives an empty
array" and "I think the handler receives an empty array" are different
claims. Trying a fix to see whether it helps means phase 3 got skipped.

---

Adapted from the `diagnosing-bugs` skill in mattpocock/skills (MIT).
