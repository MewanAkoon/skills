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

## How to use it

Type `/handoff`. Optionally say what the next session is for, which narrows
what gets included. Paste the resulting document as the first message of the
next session, or save it next to the branch.

---

## What goes in

Write these sections, in this order. Keep the whole thing under a page.

**Goal.** One or two sentences. What we are trying to make true, stated so it
would still make sense to someone who has not read anything else.

**State.** What is done and works, what is done and untested, what is not
started. Name real files and real functions, not "the auth stuff".

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

The document gets pasted into another tool, so write `<REDACTED>` in place of
any key, token, password, connection string, or personal data.

## What stays out

Point at code with `file:line` rather than pasting it. The next agent can
read the repo, and pasted code goes stale the moment someone commits.

Write the state the conversation arrived at. The order things were discussed
in stays out.

Record a failed approach when it taught something. Reasoning that reached no
conclusion has nothing to teach, so it stays out.

## Checking it

Read the document back and ask: if this were all I had, no chat history and
no memory, could I do the next step?

If the answer needs anything from the session that is not written down, add
it.

**Done when:** every file, function, and decision the next step names appears
elsewhere in the document as a real path or a real name, each section above
holds content or one line saying it is empty, and every key, token, password,
connection string, and piece of personal data reads `<REDACTED>`.

---

Adapted from the `handoff` skill in mattpocock/skills (MIT).
