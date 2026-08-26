---
name: architect
description: A design pass that settles types, signatures, and module shape as a sketch with stub bodies.
disable-model-invocation: true
---

# Architect

## What this does

It designs the shape of a change before any working code exists. Types,
function signatures, and module boundaries first, with empty bodies. Then
implementation fills them in.

The point is that the shape is the expensive thing to change later, and it is
the cheap thing to change now.

## When to use it

Before writing code that crosses a module boundary, adds a new service or
collection, or changes how existing pieces talk to each other.

Skip it for a change inside one function.

## How to use it

Type `/architect` and describe the change. You will be asked to approve the
sketch before any real code is written. Read it properly, that approval is
the point of the whole skill.

---

## Phase 1: Ground

Read the code the change will touch and build a real model of it. Not a list
of file names. Trace one real request or one real job end to end and say what
happens at each hop.

Name what already exists that this change has to live alongside: existing
types it must match, existing patterns in this codebase, existing callers.

**Done when:** the trace is written out, one line per hop, each naming a
`file:line`, and the constraints are a numbered list. Name the typecheck command
for this repo here too, because phases 2 and 4 both end on it.

## Phase 2: Sketch

Write the types and signatures. Every body is `throw new Error("not
implemented")`, with any pseudocode as a comment above the throw. A body that is
only a comment does not compile once the return type is anything but `void`, and
phase 2 ends on a compile.

Cover:

- The domain types, with the [ts-types](../ts-types/SKILL.md) rules applied.
  Model the variants, brand the ids, make the impossible state unwritable.
- Every function signature at the new boundary, with real parameter and
  return types.
- Where each piece lives, and which module owns it.
- What the failure cases return. An error type, a discriminated result, or a
  thrown domain error. Pick one and use it throughout.

Two things worth doing here that are hard to do later:

**Sketch two shapes, not one,** when there is a real fork. Put them side by
side with the trade-off in one sentence each. Most designs have one obvious
alternative that never gets written down.

**Write the call site first.** Write the code that would use this thing
before you write the thing. If the call site is awkward, the interface is
wrong, and you found out in thirty seconds instead of after the
implementation.

**Done when:** the typecheck command from phase 1 passes on the sketch, with
no implementation in it. Use that command, not a bare `tsc`, which picks up
the root config and reports errors from packages you have not touched.

## Phase 3: Agree

Show the sketch. Say what it commits to, what it leaves open, and what the
rejected alternative was, or one sentence saying why there was no real fork.

Then ask one question about a specific detail in the sketch, something a reader
could only answer having looked at it. A decision in reply to that question is
the approval.

If the answer is a question back, or "I don't know", ask once more with the
options spelled out. If that comes back empty too, pick the one you would
defend, say which you picked and why, and carry that into phase 4 as a
decision you made rather than one they made.

**Done when:** the question has a decision against it, and the record says
whether it was theirs or yours.

## Phase 4: Implement

Fill the bodies in, one at a time, against the agreed sketch. Run the typecheck
command named in phase 1 after each one.

Do not change a signature quietly. If a signature is wrong, stop and go to
phase 5.

**Done when:** every body is filled and the phase 1 typecheck command passes.

## Phase 5: Scrap when it is wrong

If the implementation shows the sketch was wrong, say so out loud and say
what it got wrong. Then go back to phase 2 and redesign.

Do not bend the implementation around a bad sketch. A sketch that survives by
being worked around is worse than no sketch, because the shape is now wrong
and nobody said so.

**Done when:** the redesign is agreed the same way phase 3 agreed the first
one.

---

Adapted from the `architect` skill in cursor/plugins pstack, by Lauren Tan
(MIT). The Cursor subagent and model-routing steps are removed.
