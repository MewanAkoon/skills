---
name: api-boundaries
description: Use when touching a Node or TypeScript route handler, controller, middleware, webhook, queue consumer, or config loader, reading process.env, req.body, or parsed JSON, calling an API you do not own, or deciding where a validation or null check belongs.
---

# API boundaries

Validation lives where data enters the process, and nowhere else. Skip tests,
one-off scripts and generated clients. Where the run may not edit, or the
guard sits outside the plan or the named change, the parse to add and the
guard to delete go in the plan or the report.

## The boundaries

HTTP in (body, query, params, headers), config in (env, files, secrets),
storage read back, messages in (queues, webhooks, events), and third-party
responses. Also CLI arguments, stdin, files read from disk, cache entries and
IPC. Everything else is inside.

## At a boundary

```ts
const input = CreateOrderSchema.parse(req.body);
await createOrder(input);
```

- Parse the whole object once, before any business logic. A half-parsed
  object is an unknown object.
- The parse yields a named domain type, not `Record<string, unknown>`.
- The boundary is the only place that writes a validation error. Inside, a
  bad value is a bug.

## Inside

A function trusts its parameter types. No null check on a parsed input, no
re-validation of its fields.

## A defensive check in the middle

Ask what could make it fire. If a real input could, a boundary is missing.
Add the parse at the edge and delete the guard. If only a bug could, delete
the guard, because it turns a crash you would see into a wrong answer you
would not. When the guard predates you and nothing explains it, call the
Skill tool with `eng:why` first, since a guard added after an incident
answers "only a bug" wrongly.

## Stored data

An ORM's or SDK's types describe the declared schema, not what is stored. A
document written before a field existed lacks it, and a `Json` column holds
whatever was written. Parse on read wherever the shape has changed or records
predate the schema.

---

Adapted from the `principle-boundary-discipline` skill in cursor/plugins
pstack, by Lauren Tan (MIT).
