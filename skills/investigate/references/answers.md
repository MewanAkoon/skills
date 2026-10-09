# Answering a question about the code

Read this when the request is a question, such as how a subsystem works or
where new code belongs, rather than a task.

Restate the question in one line first, naming the concrete thing asked
about. Then size it. A narrow question covers one module and one flow, and
gets one trace. A wide one spans several packages or a cross-cutting concern,
and gets two to four angles, each traced on its own: usually the entry path,
the data model and its writes, and the configuration around them. When it
could go either way, treat it as narrow and widen it when the trace hits
something it cannot explain.

## Placement

When the question is where code goes, list two or three candidate locations.
For each, say what it already owns, what it imports, and who imports it,
because that fixes which way a new dependency would point. Pick one, and name
the runner-up with one sentence on why it lost.

## The answer

Use these headings, dropping any the question does not need.

**Overview.** One or two paragraphs: what this is, what it does, why it
exists.

**Key pieces.** The types, services, and models the rest depends on, one line
each.

**The path.** The trace, in prose, with a `file:line` at each hop. A code
block only where the code says something the prose cannot.

**Where to start reading.** The two or three files someone new opens first.

**Gotchas.** What a newcomer would get wrong: a name that means something
else, ordering that matters and is not obvious, an unexpected default, code
that looks dead and runs, an interface with one implementation. When the trace
found nothing surprising, say so.

**Placement.** When it ran.

**Done when:** the question is restated, every hop in the path has a
`file:line`, and Gotchas, when the answer keeps it, holds at least one entry
or says the trace found nothing.

---

Adapted from the `how` skill in cursor/plugins pstack, by Lauren Tan (MIT).
