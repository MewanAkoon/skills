---
name: handoff
description: Compact the current session into a document another agent or another day can pick up from.
disable-model-invocation: true
---

# Handoff

## What this does

It writes down what a fresh agent needs to continue this work, so the next
session starts where this one ended.

## When to use it

When switching tools mid-task, when the context is running thin, at the end
of a day on unfinished work, or before handing a branch to someone. Skip it
when the work is finished, because the commits and the PR carry it.

## How to use it

Type `/eng:handoff`, optionally with what the next session is for. The
document goes to `<repo>/.claude/handoffs/<slug>.md`, or a path you name, and
you get the path. Paste it as the first message of the next session.

---

## Sections

In this order, under a page in all:

- **Goal.** One or two sentences that make sense to someone who read nothing
  else.
- **State.** Done and working, done and untested, not started, with real
  files and functions.
- **Decisions made.** Each with its reason and the options rejected, or the
  next session reopens them.
- **Constraints.** True, and not visible in the code: a rate limit, a pinned
  dependency and why, a known flaky test.
- **Dead ends.** What was tried, and what went wrong.
- **Next step.** One action concrete enough to start without another
  decision, such as "move `resolveInvoice` from `billing/service.ts` to
  `billing/resolve.ts` and update its four callers".
- **Open questions.** What a human must decide, with the options.

Point at code by `file:line` and at committed files, PRs and tickets by path
or URL, rather than pasting them. Inline the part of a plan or reproduction
that lives only on this machine. Write `<REDACTED>` for any key, token,
password, connection string or personal data, since the document travels.

## Checking it

If this were all you had, could you do the next step? Add what is missing.
Then run `git check-ignore <path>`, and when the repo does not ignore the
file, say so, so the user keeps it out of commits.

**Done when:** every name the next step uses appears in the document as a
real path or name, each section holds content or says it is empty, every
secret reads `<REDACTED>`, and the file is saved with its path given, plus
the ignore note when it applies.

---

Adapted from the `handoff` skill in mattpocock/skills (MIT).
