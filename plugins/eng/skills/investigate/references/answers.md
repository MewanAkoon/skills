# Answering a question about the code

Read this when the request is a question, such as how a subsystem works or
where new code belongs, rather than a task. A question about why code is
shaped the way it is goes to `eng:why`. For any other, run `SKILL.md`'s steps
1 to 3, then answer in the shape below.

A narrow question gets one trace. A wide one, across packages, gets two to
four: usually the entry path, the data model and its writes, and the
configuration.

## The answer

Restate the question in one line, then use these headings, dropping any the
question does not need.

- **Overview.** What this is and why it exists.
- **Key pieces.** What the rest depends on.
- **The path.** The trace in prose, with a `file:line` at each hop.
- **Where to start reading.** The two or three files to open first.
- **Gotchas.** What a newcomer would get wrong: a misleading name, an order
  that matters, an unexpected default, code that looks dead and runs. When
  the trace found nothing surprising, say so.
- **Placement.** For a question about where code goes: two or three
  candidates, each with what it owns, imports, and is imported by, one
  picked, and the runner-up with why it lost.

**Done when:** the question is restated and every hop in the path has a
`file:line`.

---

Adapted from the `how` skill in cursor/plugins pstack, by Lauren Tan (MIT).
