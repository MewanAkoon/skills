---
name: api-boundaries
description: Use when writing or reviewing a route handler, controller, middleware, config loader, message consumer, or any call to a third-party API. Also use when deciding where validation belongs or when reviewing defensive checks scattered through a service. Puts validation at the edge and keeps internal code free of guards.
---

# API boundaries

## What this does

It decides where validation lives. All of it goes at the points where data
enters the process. Everything inside those points trusts its types and holds
no defensive checks.

## When it runs

Automatically, on route handlers, controllers, middleware, config loaders,
queue consumers, and outbound third-party calls. Also when a review turns up
null checks buried in a service function.

## How to use it

Nothing to invoke. When you are unsure whether a check belongs somewhere, ask
"is this a boundary" and the agent will apply the test below.

---

## Where the boundaries are

In a Node service there are five, and only five:

1. **HTTP in.** Request body, query string, route params, headers.
2. **Config in.** Environment variables, config files, secrets.
3. **Storage out.** Documents read back from MongoDB, rows from Postgres.
4. **Messages in.** Queue payloads, webhooks, event consumers.
5. **Third party in.** Response bodies from any API you do not own.

Everything else is inside.

## What happens at a boundary

Parse the incoming value into a named domain type. One parse, at the edge,
before the value reaches any business logic.

```ts
// boundary
const input = CreateOrderSchema.parse(req.body);
await createOrder(input);
```

`CreateOrderSchema.parse` is the boundary. `createOrder` receives a
`CreateOrderInput` and treats it as true.

Three rules for the parse:

- Parse the whole object, not one field at a time. A half-parsed object is an
  unknown object.
- The parse produces a named type, not `Record<string, unknown>`. That type
  is where the untyped data stops.
- Errors at the boundary are the only place a validation error message gets
  written. Inside, a bad value is a bug, not a user error.

## What happens inside

Inside, a function trusts its parameter types completely.

```ts
// inside
async function createOrder(input: CreateOrderInput) {
  const total = priceOrder(input.items);
  return orders.insert({ ...input, total });
}
```

No null check on `input`. No re-validation of `input.items`. If the type says
it is there, it is there, because a boundary already made that true.

Keep business logic in pure functions that take domain types and return
values. Those functions are where the reasoning lives and they should be
callable from a test with no setup.

## The test for a defensive check

When you find a guard in the middle of a service, ask what could make it
fire.

- If a real input could make it fire, a boundary is missing. Add the parse at
  the edge and delete the guard.
- If only a bug could make it fire, delete the guard. It converts a crash you
  would notice into a wrong answer you would not.

A guard that returns early on `undefined` in the middle of a service does not
make the code safer. It makes a missing parse invisible.

## Mongo specifically

Documents coming back from the database are a boundary. Mongoose types
describe the schema you declared, not what is actually stored, and old
documents written before a migration will not match. Parse on read for any
collection where the shape has changed, or where documents predate the
current schema.

---

Adapted from the `principle-boundary-discipline` skill in cursor/plugins
pstack, by Lauren Tan (MIT).
