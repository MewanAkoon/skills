# The intent check

Read this at section 2 of [review.md](review.md), and brief the intent check's
subagent with what follows, with every value it relies on written out: `R`
(the directory review.md's section 1 made), the plan or request and the items
approved, the round, `<parent>`, the range, and the files implement's step 1
found already changed.

In the first round it covers the whole change: each plan item done, missing,
extra, or wrong, quoting the plan line; each bug fix's test seen failing on
the old code, extracted from the top of the tree with
`mkdir "$R/old" && git -C "$(git rev-parse --show-toplevel)" archive <parent> | tar -x -C "$R/old"`,
or reported unproven when the extract lacks what the test needs to run; every
changed sentence of prose backed by a `file:line`.
In a later round it checks, on that round's range, that the fix left each plan
item it touched done.
The files listed as already changed are not extra. It edits, commits, and
posts nothing, starts no subagents, and writes only under `R`.
