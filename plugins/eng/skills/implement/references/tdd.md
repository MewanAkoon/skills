# Test-first changes

Read this before writing code for any change in behaviour, at implement's step
2. It runs a red-green-refactor loop and holds the rules that decide whether the
tests you end up with are worth keeping. [tdd-good-tests.md](tdd-good-tests.md)
shows what a good test asserts, and [tdd-mocking.md](tdd-mocking.md) says when
to run the real thing and when to stub. Open each when its question comes up,
not before.

## Use the repo's own setup

Find how this repo tests before writing one. Read the test config of the
package being changed (`jest.config.*`, `vitest.config.*`,
`playwright.config.*`, the `test` script in its manifest) and the nearest
existing test of the same kind. Match its runner, its file location, its
helpers, and how it starts a database or an emulator. A repo's testing doc,
when it has one, outranks everything below.

## Agree the seam

A seam is the public boundary you test at. You observe behaviour through it
without reaching inside the implementation.

| Seam | Test through | Use it when |
|---|---|---|
| Service function | Call the exported function directly | Business logic. The default choice. |
| HTTP route or handler | The repo's in-process client, such as supertest against the app | Status codes, validation, auth, serialization |
| Data layer | The repository or query code against a real local store, such as the Firestore emulator or a throwaway Postgres for Prisma | Query shape, indexes, transactions, what comes back |
| User flow | The repo's end-to-end runner, such as Playwright | A path through the UI that a user would notice breaking |

When the approved plan's **Tests** section, a `pr-feedback` verdict table, or
the request itself gives the level a test runs at, that level is the seam:
write it down and go on.
Otherwise ask the user which seam the test belongs at, and wait.

Run the package's test command once before the first test, and write down
every test that already fails, so later runs can tell those from failures
this work causes.

**Done when:** a seam is written down, from the plan or the user, and so is
the list of tests already failing, or a note that none are. Or the run is
waiting on the user to name the seam, or has stopped because the suite does
not run, with the command and its error named.

## Write one failing test

Write exactly one test. Run it. Confirm it fails on the assertion you wrote,
not on a setup error, by reading the failure message.

Name the test as a capability: "rejects a checkout when the cart is empty"
says what the system does, and survives a refactor. Take the expected value
from somewhere independent of the code: a literal worked out by hand, a
worked example, the ticket.

A test that passes on its first run found one of two things. Either the
behaviour exists already, so keep the test, say so, and write the next one. Or
the test never reaches the code it is about, so the seam or the setup is wrong:
stop there and name it.

**Done when:** one test runs and fails with a message naming your assertion,
or it passed on its first run and the record says which of the two causes
it was, with the code step skipped or the run stopped.

## Write the smallest code that passes

Write only enough to turn that one test green, then run the package's tests.
Leave the next behaviour for the next cycle. When the test cannot pass without
breaking the plan, or a failure resists every fix, stop and say so.

**Done when:** the tests pass apart from the ones recorded at the start as
already failing, or the run has stopped with the failing test, its output, and
what the plan got wrong.

## Repeat, then refactor

One seam, one test, one small implementation per cycle, each test answering
what the last cycle taught. Once the seam does everything agreed, refactor
toward the clean solution the codebase would want, one change at a time,
running the tests after each and undoing any change that turns them red.

**Done when:** the seam does everything it was agreed to do, every cycle added
one test and only the code that turned it green, and the refactor left the
tests green apart from the list taken at the start.

## The three ways tests go wrong

**Implementation-coupled.** The test mocks an internal collaborator, reaches
into a private method, or checks a result by reading the database directly
instead of asking the interface. A refactor then breaks the test while the
behaviour is unchanged. Assert through the interface a caller uses.

**Tautological.** The assertion recomputes the expected value the way the
code does, so it agrees with the code whatever the code says.
`expect(total(items)).toBe(items.reduce(sum))` is this, and so is a snapshot
generated from the code under test. Bring the expected value in from outside.

**Horizontal slicing.** Writing every test first and then all the code. Bulk
tests describe behaviour you imagined, lock in a structure before you
understand the problem, and stop reacting to what the code teaches. Work one
vertical slice at a time.

---

Adapted from the `tdd` skill in mattpocock/skills (MIT).
