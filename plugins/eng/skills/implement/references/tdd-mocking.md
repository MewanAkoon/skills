# Mocking rules

The default is not to mock. Reach for a real thing first and stub only what
you genuinely cannot run.

## Run it for real

**The data layer.** Run the store the code really talks to, the way the repo
already does: the Firestore emulator for Firestore, a throwaway Postgres
container for Prisma, an in-memory server where the driver has one. Each
starts in seconds and gives real queries, real indexes, real transactions.
Stubbing the client or the model teaches nothing about whether the query is
right, and that is usually the thing in doubt. Clear the data between tests,
the way the nearest existing test does:

```ts
afterEach(async () => {
  // Prisma against a throwaway Postgres; truncate what the test wrote
  await prisma.$executeRawUnsafe('TRUNCATE "Order", "OrderLine" CASCADE');
});
```

**Your own modules.** If a service calls another service in the same
codebase, call the real one. Mocking an internal collaborator couples the
test to the current call structure, which is exactly what you want to be free
to change.

**The HTTP layer.** An in-process client, such as supertest against the app,
runs the real routes. No mocking needed, and you get real middleware, real
serialization, real status codes.

## Stub it

**Third-party HTTP.** Anything you do not own: Stripe, SendGrid, an upstream
partner API. Use `nock` or `msw` to intercept at the network layer rather
than replacing the client module, so your own request-building code still
runs and is still tested.

```ts
nock("https://api.stripe.com")
  .post("/v1/charges")
  .reply(200, { id: "ch_123", status: "succeeded" });
```

**Time.** Use fake timers rather than sleeping. A test that waits on a real
clock is slow and flaky.

```ts
vi.useFakeTimers();
vi.setSystemTime(new Date("2026-01-15T10:00:00Z"));
```

**Randomness and IDs.** Inject the generator so the test can supply a fixed
value. A function that calls `crypto.randomUUID()` internally cannot be
asserted on.

**Anything slow, paid, or irreversible.** Sending real email, charging a real
card, calling a rate-limited API.

## The test for whether a mock belongs

Ask what the mock is standing in for.

- Something outside your process that you cannot control. Stub it.
- Something inside your codebase. Do not stub it. If calling it for real is
  painful, the pain is telling you the seam is in the wrong place, and that
  is worth fixing rather than mocking around.

## Never assert on the mock

```ts
// tests that a call happened, not that the system behaves
expect(emailClient.send).toHaveBeenCalledTimes(1);

// tests the behaviour a user would notice
const sent = emailStub.sent();
expect(sent).toHaveLength(1);
expect(sent[0].to).toBe("customer@example.com");
```

A call-count assertion breaks when you batch two sends into one, even though
the user-visible behaviour is identical. Assert on the collected effect
instead.
