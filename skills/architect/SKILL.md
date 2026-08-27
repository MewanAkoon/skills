---
name: architect
description: Settle types, signatures, and module shape before writing any implementation.
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

**Done when:** the flow is written out hop by hop with a `file:line` at each
hop, and the constraints the design has to satisfy are listed by name.

## Phase 2: Sketch

Write the types and signatures. Bodies are `throw new Error("not
implemented")` or a two-line comment of pseudocode.

Cover:

- The domain types, with the `ts-types` rules applied. Model the variants,
  brand the ids, make the impossible state unwritable.
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

Read [references/design-red-flags.md](references/design-red-flags.md) and
screen every shape you sketched against its four flags before phase 3. A fork
is exactly where the screen pays, so run it on both sides of one.

**Done when:** each shape you sketched compiles with no implementation in it,
and carries the four flags either marked absent or named alongside the
revision that answers them.

## Phase 3: Agree

Show the sketch. Say what it commits to, what it leaves open, and what the
rejected alternative was.

Wait for approval. Do not start implementing on a "looks good" that came
before the user read it.

**Done when:** the user has approved this specific sketch, or has named
changes and approved the amended one, or has rejected the shape, which sends
you back to phase 2.

## Phase 4: Implement

Fill the bodies in, one at a time, against the agreed sketch. Run the
typecheck after each one.

Do not change a signature quietly. If a signature is wrong, stop and go to
phase 5.

**Done when:** every body is filled and the typecheck passes.

## Phase 5: Scrap when it is wrong

The trigger is a repeating pattern of friction, not one hard case. The tells:

- The same shape of workaround turning up in unrelated places.
- Several unrelated edge cases that each need their own branch.
- Types that need `any`, a cast, or an always-set optional field to compile.
- Reaching for a lock where the sketch said the state was not shared.
- Callers having to know the abstraction's internal rules to use it.

Complexity in the data is not complexity in the design, so a few hard cases
leave the shape standing. When the pattern is there, say so out loud and say
what the sketch got wrong. Then go back to phase 2 and redesign.

Do not bend the implementation around a bad sketch. A sketch that survives by
being worked around is worse than no sketch, because the shape is now wrong
and nobody said so.

**Done when:** either the redesign is agreed, or the original sketch is
confirmed as still correct.

---

Adapted from the `architect` skill in cursor/plugins pstack, by Lauren Tan
(MIT). The Cursor subagent, model-routing, and arena steps are removed, and
the phase 3 approval is always on rather than opt-in.
