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

## unknown over any

```ts
async function loadConfig(): Promise<AppConfig> {
  const raw: unknown = JSON.parse(await readFile(path, "utf8"));
  return AppConfigSchema.parse(raw);
}
```

`unknown` forces the parse. `any` would let the raw value flow into the rest
of the app untouched.

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

That guard checks everything it claims. A guard that returns
`typeof err === "object"` while claiming `err is MongoError` is lying, and
the lie is invisible at the call site.

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
