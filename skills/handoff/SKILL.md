---
name: handoff
description: Compact the current session into a document another agent or another day can pick up from.
disable-model-invocation: true
---

# Handoff

## What this does

It writes down everything a fresh agent would need to continue this work, so
the next session starts from where this one ended instead of from the
beginning.

## When to use it

When you are switching from one AI tool to another mid-task. When a session
has gone long and the context is getting thin. At the end of a work day on
something unfinished. Before handing a branch to someone else.

Skip it when the work is committed and the branch is green. A commit message
and a clean diff already carry everything the next session needs.

## How to use it

Type `/handoff`. Optionally say what the next session is for, which shortens
the sections that do not serve it, and drops none of them. The document is
printed in chat. Ask before writing it to a file, and take the path from the
user, so nothing lands in their working repo uninvited.

---

## What goes in

Write these sections, in this order. Keep the whole thing under a page.

**Goal.** One or two sentences. What we are trying to make true, stated so it
would still make sense to someone who has not read anything else.

**State.** What is done and works, what is done and untested, what is not
started. Name real files and real functions, not "the auth stuff". Run the test
suite before writing this, and put anything you did not watch pass under "done
and untested".

**Decisions made.** Each one as a line: what was decided and the reason.
Include the options that were rejected. Without the reasons, the next session
relitigates all of them.

**Constraints.** Things that are true and not obvious from the code. An API
that rate limits at 10 a second. A collection that cannot be migrated in
place. A dependency pinned for a reason. A test that is flaky for a known
reason.

**Dead ends.** Approaches already tried that did not work, and what went
wrong. This is the section that saves the most time and the one people leave
out.

**Next step.** The single next thing, concrete enough to start on without
another decision. Not "continue the refactor". Instead: "move
`resolveInvoice` out of `billing/service.ts` into `billing/resolve.ts` and
update the four callers listed above".

**Open questions.** Anything a human needs to decide before the work can
finish, with the options.

## What stays out

Do not paste code that is already in the branch. Reference `file:line`
instead. The next agent can read the repo, and pasted code goes stale the
moment someone commits.

Write the state the work is in, and leave out the story of how it got there.
The next session does not need the order things were discussed in.

Keep every approach you actually ran, in **Dead ends** above. Leave out the
options that were only discussed and dropped without being tried. Running it is
the test, not whether you judge that it taught you something.

## Checking it

Name the first file you would open and the first command you would run to do
the next step. If the document does not already contain both, it is not
finished, so add them.

**Done when:** all seven sections are present and non-empty, Next step names a
file path, and State names real functions.

---

Adapted from the `handoff` skill in mattpocock/skills (MIT).
