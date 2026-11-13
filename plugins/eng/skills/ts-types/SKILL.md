---
name: ts-types
description: Use when designing or editing a TypeScript type, interface or signature, modelling state, or fixing a type error, and when a diff adds any, an as cast, or a non-null assertion. Covers unions, brands, narrowing, exhaustiveness and casts.
---

# TypeScript types

Make illegal states impossible to write down. Generated clients and
third-party definitions stay as they are. A test fixture may cast to build a
partial object.

## The rules

| Rule | What it means |
|---|---|
| Discriminated unions | Variants carry a literal `kind` or `status`. A bag of optional fields admits states that cannot happen. |
| Brands | A string or number with a specific meaning gets a brand, so a `UserId` and an `OrderId` cannot swap. Validate once, where the brand is made. |
| Construct, do not guard | `[T, ...T[]]` for a non-empty list, `start` plus `duration` for a range that cannot invert. Strengthen a type only where the loose one forces a `!`, a cast, or a "cannot happen" throw. |
| `unknown`, not `any` | Outside data is `unknown` until parsed, at the edge `eng:api-boundaries` names. |
| Casts | An `as` comes only directly after the check that makes it true. To remove one, find why inference fails: no discriminant, a source type too wide, an unparsed boundary. |
| Narrowing order | Discriminant switch, then `in`, then `typeof` or `instanceof`, then a type guard, then `as`. |
| Honest guards | An `isX` guard checks every part of its claim. A guard that checks less hides the bug behind a safe-sounding name. |
| Exhaustiveness | The default arm assigns the value to `never`, so a new variant breaks the build. |
| `satisfies`, not `as` | `satisfies` checks the shape and keeps the inferred type, literal keys included. `as` replaces it. |
| Derive | `Pick`, `Omit`, `Parameters`, `ReturnType`, `Awaited` before a new interface. When a `.proto`, OpenAPI or GraphQL schema, or migration defines the shape, use its generated type. |
| Object arguments | Three or more positional parameters become one object, except on hot paths such as parsers and per-request loops. |

For the syntax of a brand, the `never` check, `satisfies`, or a guard, read
[references/patterns.md](references/patterns.md).

## The tests

- If a comment could explain when this combination of fields is valid, split
  the type into a union.
- Two parameters with the same primitive type and different meanings get
  brands.
- Every `any`, `as` and `!` traces back to a boundary, and the validation
  goes there.
- Add a variant in your head. The compiler has to point at every match that
  needs a case.
- When nothing would throw with the loose type, keep it.

---

Adapted from the `typescript-best-practices` and
`principle-type-system-discipline` skills in cursor/plugins pstack, by
Lauren Tan (MIT).
