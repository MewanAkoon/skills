# The intent check

Brief a general-purpose subagent with this, on Sonnet at medium effort, as
[models.md](../../investigate/references/models.md) says, writing out `R`, the
plan or request and the items approved, `<parent>`, the range, and the files
already changed at the start, which are not extra.

It reports each plan item as done, missing, extra, or wrong, quoting the plan
line; each bug fix's test seen failing on the old code, extracted with
`mkdir "$R/old" && git -C "$(git rev-parse --show-toplevel)" archive <parent> | tar -x -C "$R/old"`;
and each changed sentence of prose backed by a `file:line`. It compares the
diff with the approved plan and runs no probe beyond that old-code test. It
edits, commits, and posts nothing, starts no subagents, does not call the
advisor, writes only under `R`, and reports findings only, about 3,000
characters at most.

When the brief carries the checklist in [security.md](security.md), it also
reports each security finding with its input, the path it takes, and the
`file:line`, or says it found none.

## The fix-round review

From round 2 on, `review.md` reviews the fix diff in a general-purpose
subagent on Sonnet at medium effort, whose description starts with
`code-review medium`, so the Stop hook waits for it when it runs in the
background. Its brief, with the hashes written out:
call the Skill tool with `code-review` and `medium <parent>..<snapshot>`,
follow it, and reply with each finding's `file:line`, its point and its
failure scenario, or "none". It edits, commits, and posts nothing, starts no
subagents, and does not call the advisor. When it cannot call the Skill
tool, the main session runs the review itself and the report says so.

## Without code-review

Where `code-review` is missing or fails, the session gives the intent check a
bug lens in every round, and reports that the built-in did not run.
