# The plan check

Read this at investigate's step 6, when the plan spans more than one area.
Brief one general-purpose subagent with the rules and checks below, the plan,
the paths and URLs it needs, and a scratch directory made with `mktemp -d` in
the scratchpad.

## Put these in the brief word for word

- Read and run, never write. Use `git log`, `git show`, `git blame`, `gh`
  and `gh api` reads, search, and the repo's checks in their report-only
  modes. Edit no file, commit nothing, post nothing, start no subagents. A
  probe writes only under the scratch directory.
- Every finding gives a `file:line` or the command run, what is wrong in one
  sentence, and a confidence: high, medium, or low. Twelve at most, the most
  serious first. "None" is a valid result.
- Claims: confirm each finding the plan rests on with a `file:line` or a run,
  or refute it with one. A claim whose backing line says something narrower
  fails. Watch for a fact true in one place and stale in its twin elsewhere.
- Plan: each change names a file that exists or is marked new, each change in
  behaviour names a test, each doc the change makes false is listed, nothing
  asked for is missing and nothing unasked is added, and names agree from
  item to item. Name a simpler approach when one exists, and a risk the plan
  does not list.

---

The plan check's last tests are adapted from the `writing-plans` skill in
obra/superpowers (MIT).
