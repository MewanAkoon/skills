# Mocking rules

The default is not to mock. Reach for a real thing first and stub only what
you genuinely cannot run.

## Run it for real

**MongoDB.** Use `mongodb-memory-server` or a throwaway container. Both start
in a couple of seconds and give you real query behaviour, real indexes, real
aggregation. Stubbing the Mongoose model teaches you nothing about whether
the query is correct, and query correctness is usually the thing you are
worried about.

```ts
let mongo: MongoMemoryServer;

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongo.stop();
});

afterEach(async () => {
  await Promise.all(Object.values(mongoose.connection.collections).map((c) => c.deleteMany({})));
});
```

**Your own modules.** If a service calls another service in the same
codebase, call the real one. Mocking an internal collaborator couples the
test to the current call structure, which is exactly what you want to be free
to change.

**The HTTP layer.** Supertest runs the real Express or Nest app in process.
No mocking needed, and you get real middleware, real serialization, real
status codes.

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
