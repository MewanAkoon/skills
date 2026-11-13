# Type patterns

The syntax the rules in `SKILL.md` need.

## Brand

```ts
type Brand<T, B extends string> = T & { readonly __brand: B };
type UserId = Brand<string, "UserId">;

function toUserId(raw: string): UserId {
  if (!/^[0-9a-f]{24}$/.test(raw)) throw new Error("not a user id");
  return raw as UserId;
}
```

The `as` sits right after the check that makes it true, and this function is
the only way into the type.

## Exhaustiveness

```ts
switch (payment.status) {
  case "pending":
    return "waiting";
  case "succeeded":
    return payment.chargeId;
  default: {
    const _exhaustive: never = payment;
    return _exhaustive;
  }
}
```

## satisfies

```ts
const routes = {
  health: { method: "GET", path: "/health" },
} satisfies Record<string, RouteDef>;

routes.health.method; // "GET", still the literal
routes.helth;         // compile error
```

Under `as Record<string, RouteDef>`, `method` widens to the declared union
and `routes.helth` compiles. The literal survives `satisfies` only when the
declared field is a union of literals, not `string`.

## Honest guard

```ts
function isUniqueViolation(err: unknown): err is { code: "P2002" } {
  return typeof err === "object" && err !== null && "code" in err && err.code === "P2002";
}
```

A guard that returned `typeof err === "object" && err !== null` for a
`DbError` claim would let every object through as one.
