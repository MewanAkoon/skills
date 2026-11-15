# The intent check

Brief a general-purpose subagent with this, on Sonnet at medium effort, as
[models.md](../../investigate/references/models.md) says, writing out `R`, the
plan or request and the items approved, `<parent>`, the range, and the files
already changed at the start, which are not extra.

Put these in the brief word for word, as
[checks.md](../../investigate/references/checks.md) does for every other
check:

- Read and run, never write. Use `git log`, `git show`, `git blame`, search,
  and the repo's checks in their report-only modes. Edit no file, commit
  nothing, post nothing, start no subagents, and do not call the advisor.
  Write only under `R`. Compare the diff with the approved plan, and run no
  probe beyond the old-code test below.
- Report each plan item as done, missing, extra, or wrong, quoting the plan
  line. Report each bug fix's test as seen failing on the old code, extracted
  with
  `mkdir "$R/old" && git -C "$(git rev-parse --show-toplevel)" archive <parent> | tar -x -C "$R/old"`.
  Back each changed sentence of prose with a `file:line`.
- Every other finding gives a `file:line` or the command run, what is wrong
  in one sentence, a confidence of high, medium, or low, and whether it
  blocks. Twelve at most, the most serious first, and the cap never cuts the
  item report. "None" is a valid result. About 3,000 characters at most.
- A backing line that says something narrower than the claim fails. Watch
  for a fact true in one place and stale in its twin elsewhere.

When the brief carries the checklist in [security.md](security.md), it also
reports each security finding with its input, the path it takes, and the
`file:line`, or says it found none.

## The fix-round review

From round 2 on, `review.md` reviews the fix diff in a general-purpose
subagent on Sonnet at medium effort, whose description starts with
`code-review medium`, so the Stop hook waits for it when it runs in the
background. Its brief, with the hashes written out: call the Skill tool
with `code-review` and `medium <parent>..<snapshot>`, follow it on that
range alone, not the uncommitted tree, which earlier rounds read, and reply
with each finding's `file:line`, its point and its failure scenario, or
"none". It edits, commits, and posts nothing, starts no subagents, and does
not call the advisor. When it cannot call the Skill tool, the main session
runs the same review itself, on that range alone, and the report says so.

## Without code-review

Where `code-review` is missing or fails, the session gives the intent check a
bug lens in every round, and reports that the built-in did not run.
