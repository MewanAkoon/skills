# Debugging a bug that resisted the obvious fix

Read this at investigate's step 4. The fix goes in the plan, and the
reproduction becomes its regression test.

The repo's code stays unchanged. The reproduction, and every file a loop or a
probe writes, go in the scratchpad, or a directory made with `mktemp -d`. A
reproduction that has to sit in the repo, and logging added to its code, are
edits: ask before making them, and remove the logging before presenting the
plan.

## A failing CI check

Read the failure before reproducing anything:

```bash
gh pr checks <n>
gh run view <run-id> --log-failed
```

Then check whether it fails on the base branch too.

## 1. Get it red

One command that fails for this bug and not for something nearby, run twice,
failing both times. A flaky bug needs its failure rate raised first, by
looping, adding load, or narrowing the timing window. When a good commit and a
bad one are known, script the loop to exit non-zero on the bug and bisect, in
a worktree made for it so this checkout stays put:

```bash
git worktree add --detach <dir> HEAD
git -C <dir> bisect start <bad> <good>
git -C <dir> bisect run <script>
git -C <dir> bisect reset
git worktree remove <dir>
```

When it will not reproduce, list what was tried and ask the user for an
environment that reproduces it, a captured artifact, or leave to instrument.

## 2. Name the hypotheses

Write three to five, ranked, before testing any, each with the observation
that would prove it wrong. One without such an observation is too vague to
test.

## 3. Instrument

Make the top hypothesis's observation. Tag every log line with one marker,
`[DEBUG-<4 hex>]`. A performance regression is measured instead: a baseline
over several runs, a profiler, or the query plan. When every hypothesis dies,
go back to phase 2 with what was learned. Once the logging is removed,
`grep -rF '[DEBUG-<marker>]' .` returns nothing; `-F`, because the brackets
are a character class otherwise.

## 4. Name the fix

At the place the evidence points to, not where the error surfaced, with one
sentence on why it makes the loop pass. Change one thing at a time.

**Done when:** the plan names the fix, its place, that sentence, and the
reproduction that becomes the regression test, or the run has asked for the
missing signal or for leave to edit the repo.

---

Adapted from the `diagnosing-bugs` skill in mattpocock/skills (MIT).
