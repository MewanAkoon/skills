# The intent check

Brief a general-purpose subagent with this, writing out `R`, the plan or
request and the items approved, `<parent>`, the range, and the files already
changed at the start, which are not extra.

It reports each plan item as done, missing, extra, or wrong, quoting the plan
line; each bug fix's test seen failing on the old code, extracted with
`mkdir "$R/old" && git -C "$(git rev-parse --show-toplevel)" archive <parent> | tar -x -C "$R/old"`;
and each changed sentence of prose backed by a `file:line`. It edits,
commits, and posts nothing, starts no subagents, and writes only under `R`.

When the brief carries the checklist in [security.md](security.md), it also
reports each security finding with its input, the path it takes, and the
`file:line`, or says it found none.
