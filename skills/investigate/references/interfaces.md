# Sketching an interface

Read this when the plan adds or reshapes a type, a function signature, a
module boundary, or the way two pieces talk to each other. The shape is
expensive to change after implementation and cheap to change now, so it gets
settled in the plan.

## Write the call site first

Write the code that would use the new thing before the thing itself. An
awkward call site means the interface is wrong, and you found out in thirty
seconds instead of after the implementation.

## Sketch types and signatures with empty bodies

- The domain types, with the `eng:ts-types` rules applied in a TypeScript repo:
  model the variants, brand the ids, make the impossible state unwritable.
- Every function signature at the new boundary, with real parameter and
  return types.
- Where each piece lives, and which module owns it.
- What failure returns: an error type, a discriminated result, or a thrown
  domain error. Pick one and use it throughout.

Bodies are a `throw new Error("not implemented")` or two lines of pseudocode.

## Sketch two shapes at a real fork

When there is a real alternative, put both side by side with the trade-off in
one sentence each. Most designs have one obvious alternative that never gets
written down.

## Screen against the red flags

Read [design-red-flags.md](design-red-flags.md) and screen every shape against
its four flags, both sides of a fork included.

**Done when:** each sketched shape would compile with no implementation in it,
and each carries the four flags marked absent or named alongside the revision
that answers them.

---

Adapted from the `architect` skill in cursor/plugins pstack, by Lauren Tan
(MIT).
