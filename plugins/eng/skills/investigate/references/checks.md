# The second check and the plan check

Read this at step 5 or step 7. Brief one general-purpose subagent with the
check below, the paths and URLs it needs, and a scratch directory: `mktemp -d`
under the scratchpad your system prompt names, or under `${TMPDIR:-/tmp}`.

## Rules for the subagent

Put these in the brief word for word:

- Read and run, never write. Use `git log`, `git show`, `git blame`,
  `gh ... view` and `gh api` reads, search, and the repo's checks in the
  modes that only report. Edit no file, commit nothing, post nothing, and
  start no subagents. A probe that needs a file writes it only under the
  scratch directory named in this brief.
- Every finding gives a `file:line` or the command you ran, what is wrong in
  one sentence, and a confidence: high, medium, or low.
- Twelve findings at most, the most serious first. "None" is a valid result.

## Claims check (step 5)

For each finding, confirm it with a `file:line` or a run, or refute it with
one. A finding with nothing behind it fails, and so does one whose backing
line says something narrower. Watch for three shapes: a statement still
describing both halves of a system after one half changed, a fact true in one
place and stale in its twin elsewhere, and a mechanism explained that nobody
checked.

## Plan check (step 7)

Before any code exists. Each change names the file it lands in, and the file
exists or is marked new. Each change in behaviour names a test. Each doc the
change makes false is listed. Nothing the request asked for is missing, and
nothing it did not ask for is added. Names and types agree from one item to
the next, and the plan is in proportion to the change. Name a simpler approach
when one exists, and a risk the plan does not list.

## Output

```
Check: claims | plan
1. [high|medium|low] path:line or command
   What is wrong, and the evidence.
Checked and clean: <one line per area that held>
```

---

The plan check's last two tests are adapted from the `writing-plans` skill in
obra/superpowers (MIT).
