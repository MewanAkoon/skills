---
name: ts-types
description: Use when reading or editing any .ts or .tsx file, designing a type or interface, reviewing a function signature, or deciding how to model a piece of state. Use it when tsc reports a type error, and when an any, an as cast, or a non-null assertion appears in a diff. Covers discriminated unions, branded types, narrowing, exhaustiveness, and where casts are allowed.
---

# TypeScript type discipline

## What this does

It holds the type-system rules this codebase follows, so the agent models
data the same way every time instead of reaching for optional fields and
`as` casts.

The one idea underneath all of it: make illegal states impossible to write
down, so the compiler catches the mistake instead of a runtime check.

## When it runs

Automatically, on any TypeScript file. Also when designing a type before any
code exists.

## How to use it

Nothing to invoke. If a suggested type feels loose, say "check this against
ts-types" and the agent will walk the table and the tests.

---

## The rules

| Rule | What it means |
|---|---|
| Discriminated unions | Model variants with a literal `kind` or `status` field. A bag of optional fields lets callers construct states that cannot happen. |
| Branded types | Brand semantic primitives with `& { readonly __brand: "UserId" }` so a `UserId` and an `OrderId` cannot be swapped. Validate once, at creation. |
| Construct, do not guard | Build the shape so the bad value cannot exist. `[T, ...T[]]` for a non-empty list. `start` plus `duration` for a range that cannot invert. |
| Simplest total type | Keep `T[]` while every operation on it stays total. Strengthen to a non-empty type only where the loose one forces a `!`, a cast, or a "cannot happen" throw. |
| `unknown` over `any` | Data from outside the process is `unknown` until parsed. `any` switches off type checking everywhere it spreads. |
| No `as` casts | Every `as` is a runtime failure waiting for the right input. Cast only after validation has actually run. |
| Narrowing order | Prefer, in this order: discriminant switch, `in` operator, `typeof` or `instanceof`, a user-defined type guard, and only then `as`. |
| Honest type guards | A guard must check the claim it makes. A lying guard is worse than a cast because the bug hides behind a name that says it is safe. Name them `isX` or `hasX`. |
| Exhaustiveness | Put `const _exhaustive: never = value;` in the default arm so adding a variant breaks the build. |
| `satisfies` over `as` | It validates the value against the type without widening the literals. |
| Parse at the boundary | Data crossing into the process gets parsed into a named domain type at the edge. See the `api-boundaries` skill for where that edge is. |
| Derive, do not redeclare | Reach for `Pick`, `Omit`, `Parameters`, `ReturnType`, `Awaited`, and `typeof` before writing a new interface that duplicates an existing shape. When a `.proto`, an OpenAPI or GraphQL schema, a database migration, or a design-token file already defines the shape, derive from the generated type. A hand-written parallel drifts the moment the schema moves. |
| Object arguments | Pass an object rather than three positional parameters, so call sites document themselves. Skip this on hot paths such as parsers and per-request loops. |

Worked examples for each rule are in
[references/patterns.md](references/patterns.md). Read that file when a rule
is unclear or when you need the exact syntax.

## The tests

Run these against a type before committing to it:

- Try writing the comment that explains when this combination of fields is
  valid. If it can be written, split the type into a union.
- Look for two parameters that share a primitive type and mean different
  things. Brand them.
- Trace every `any`, `as`, and `!` back to the boundary it came from, and
  validate there instead.
- Add a variant in your head. The compiler has to point at every match that
  now needs a case.
- Ask what would throw if the type stayed loose. When nothing would, keep the
  plain type.

## Where this does not apply

Test fixtures may use casts to build partial objects. Generated client code
and third-party type definitions are left alone.

---

Adapted from the `typescript-best-practices` and
`principle-type-system-discipline` skills in cursor/plugins pstack, by
Lauren Tan (MIT).
