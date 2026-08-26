# What a good test looks like

## Name the capability, not the function

```ts
// says nothing about behaviour
it("createOrder works", ...)
it("test 2", ...)

// says what the system does
it("rejects an order when the cart is empty", ...)
it("charges the card before writing the order", ...)
it("returns 409 when the idempotency key was already used", ...)
```

A reader who has never seen the code should be able to list the system's
capabilities by reading the test names.

## Assert on the observable result

```ts
// implementation-coupled: breaks on any refactor
expect(orderRepo.insert).toHaveBeenCalledWith(expect.objectContaining({ total: 4500 }));

// behavioural: survives a refactor
const order = await createOrder(input);
expect(order.total).toBe(4500);
```

The second one still passes when `insert` is renamed, moved, or replaced by a
different persistence call. That is the whole point.

## Expected values come from outside the code

```ts
// tautological, passes no matter what priceOrder does
expect(priceOrder(items)).toBe(items.reduce((n, i) => n + i.price * i.qty, 0));

// independent, from the ticket
expect(priceOrder([{ price: 1500, qty: 2 }, { price: 1500, qty: 1 }])).toBe(4500);
```

Work the number out by hand once and write it down. If the code and the
literal disagree, one of them is wrong and the test tells you.

## One behaviour per test

```ts
// three behaviours, and you learn about one failure at a time
it("creates the order, sends the email, and updates stock", ...)

// three tests, all three failures visible in one run
it("creates the order", ...)
it("sends a confirmation email", ...)
it("decrements stock for each line item", ...)
```

## Arrange with a builder, not a literal wall

```ts
function anOrder(overrides: Partial<CreateOrderInput> = {}): CreateOrderInput {
  return {
    customerId: toCustomerId("507f1f77bcf86cd799439011"),
    items: [{ sku: "SKU-1", price: 1500, qty: 1 }],
    currency: "USD",
    ...overrides,
  };
}

it("rejects an order when the cart is empty", async () => {
  await expect(createOrder(anOrder({ items: [] }))).rejects.toThrow(EmptyCart);
});
```

The override is the only thing that varies, so the test says exactly what it
is about. Everything the test does not mention is irrelevant to it.

## Route tests assert on the contract

```ts
it("returns 400 with a field list when the body is invalid", async () => {
  const res = await request(app).post("/orders").send({ items: [] });

  expect(res.status).toBe(400);
  expect(res.body.errors).toEqual([{ field: "items", message: "must not be empty" }]);
});
```

Status code and response shape are the contract a client depends on. Assert
on both. Do not assert on internal logging or which service function ran.

## What not to test

- Framework behaviour. Express routing and Mongoose validation are already
  tested by their authors.
- Getters, setters, and pass-through wrappers with no logic.
- Exact error message strings, unless a client parses them. Assert the error
  type or code instead, so a wording change does not break the suite.
