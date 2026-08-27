# Type patterns

Worked examples for each rule in `SKILL.md`. Read the row you need.

## Discriminated unions

An optional-field bag lets a caller build a state that cannot happen:

```ts
type Payment = {
  status: string;
  chargeId?: string;
  failureReason?: string;
};
```

Nothing stops `{ status: "succeeded", failureReason: "card declined" }`.

Model the variants instead:

```ts
type Payment =
  | { status: "pending" }
  | { status: "succeeded"; chargeId: string }
  | { status: "failed"; failureReason: string };
```

Now the compiler knows `chargeId` exists only on the succeeded branch, and
the impossible combination cannot be written.

## Branded types

```ts
type Brand<T, B extends string> = T & { readonly __brand: B };

type UserId = Brand<string, "UserId">;
type OrderId = Brand<string, "OrderId">;

function toUserId(raw: string): UserId {
  if (!/^[0-9a-f]{24}$/.test(raw)) throw new Error("not a user id");
  return raw as UserId;
}
```

The `as` inside `toUserId` is the one allowed cast. It sits directly after
the check that makes it true, and it is the only way into the type.

```ts
function getUser(id: UserId) {}
getUser(order.id); // compile error, OrderId is not UserId
```

## Construct, do not guard

A non-empty array, enforced by shape:

```ts
type NonEmpty<T> = [T, ...T[]];

function first<T>(items: NonEmpty<T>): T {
  return items[0]; // no undefined, no ! needed
}
```

A range that cannot invert:

```ts
type Range = { start: Date; durationMs: number };
```

There is no way to express an end before a start, so no validator is needed.

## Simplest total type

Keep the loose type while every operation on it stays total:

```ts
const sum = (xs: number[]) => xs.reduce((a, b) => a + b, 0); // [] is 0
```

Strengthen where the loose type forces a lie at a use site. The tells are `!`,
`xs[0] as T`, and a "cannot happen" throw:

```ts
// partiality smuggled past the compiler
function newest(sessions: Session[]): Session {
  return sessions.at(0)!;
}

// strengthen the input and the assertion disappears
function newest(sessions: NonEmpty<Session>): Session {
  return sessions[0];
}
```

Returning `Session | undefined` is the other total signature. Either way the
empty case lands at the call site, the one place that knows what empty means.

## unknown over any

```ts
async function loadConfig(): Promise<AppConfig> {
  const raw: unknown = JSON.parse(await readFile(path, "utf8"));
  return AppConfigSchema.parse(raw);
}
```

`unknown` forces the parse. `any` would let the raw value flow into the rest
of the app untouched.

## No `as` casts

```ts
// a crash waiting for the wrong payload
const user = data as User;

// the cast earned, sitting after the checks that make it true
function parseUser(data: unknown): User {
  if (typeof data !== "object" || data === null) throw new Error("expected object");
  const raw = data as Record<string, unknown>;
  if (typeof raw.id !== "string") throw new Error("expected id");
  // ... every other field
  return data as User;
}
```

When taking an `as` out of existing code, find why the compiler cannot infer
the type:

- No discriminant. Add one and switch to a discriminated union.
- Source type too wide, such as `Record<string, unknown>`. Narrow it.
- Untyped boundary. Add a parse function or a schema.
- Genuinely inexpressible. Reach for a branded type or `satisfies`.

## Narrowing order

Discriminant switch, the best case:

```ts
switch (payment.status) {
  case "succeeded":
    return payment.chargeId;
  case "failed":
    return payment.failureReason;
  case "pending":
    return null;
}
```

The `in` operator, when there is no discriminant to switch on:

```ts
if ("chargeId" in payment) {
  return payment.chargeId;
}
```

A type guard, when the check is real work:

```ts
function isMongoDuplicateKeyError(err: unknown): err is { code: 11000 } {
  return typeof err === "object" && err !== null && "code" in err && err.code === 11000;
}
```

## Honest type guards

The guard above checks everything it claims. This one does not:

```ts
function isMongoError(err: unknown): err is MongoError {
  return typeof err === "object" && err !== null;
}
```

Every caller now treats any object as a `MongoError`, and the lie is invisible
at the call site, because the name says it is safe. Prefer discriminant
narrowing wherever a discriminant exists, since a guard adds a layer the
reader has to follow.

## Exhaustiveness

```ts
function describe(payment: Payment): string {
  switch (payment.status) {
    case "pending":
      return "waiting";
    case "succeeded":
      return `charged ${payment.chargeId}`;
    case "failed":
      return `failed: ${payment.failureReason}`;
    default: {
      const _exhaustive: never = payment;
      return _exhaustive;
    }
  }
}
```

Add a fourth variant to `Payment` and this function stops compiling. That is
the point. Without the `never` line, the new variant silently falls through.

## satisfies over as

```ts
const routes = {
  health: { method: "GET", path: "/health" },
  createUser: { method: "POST", path: "/users" },
} satisfies Record<string, RouteDef>;

routes.health.method; // "GET", the literal, still narrow
```

With `as Record<string, RouteDef>` the literal widens to `string` and you
lose the narrowing. `satisfies` checks the shape and keeps the literals.

## Parse at the boundary

Validate once where the data crosses in, then trust the type inside.

```ts
// the edge: parse once, then trust the result
export function handle(raw: unknown): Result {
  const input = InputSchema.parse(raw); // throws here, nowhere deeper
  return process(input);                // process takes Input, not unknown
}
```

A wire format such as protobuf parses with `ignoreUnknownFields`, so a
forward-compatible field addition does not break an old client. A persisted
JSON blob carries a version and parses inside a try/catch. Deeper in the call
chain, use the parsed type as it stands.

## Derive, do not redeclare

```ts
type User = { id: UserId; email: string; passwordHash: string; createdAt: Date };

type PublicUser = Omit<User, "passwordHash">;
type CreateUserInput = Pick<User, "email"> & { password: string };
```

When `User` gains a field, these follow. A hand-written `PublicUser`
interface would drift and nobody would notice until a field went missing
from an API response.

## Object arguments

```ts
// call site says nothing
transfer(fromId, toId, 500, true);

// call site documents itself
transfer({ from: fromId, to: toId, amountCents: 500, allowOverdraft: true });
```

Skip this in a tokenizer, a per-frame render loop, or anywhere the allocation
shows up in a profile.
