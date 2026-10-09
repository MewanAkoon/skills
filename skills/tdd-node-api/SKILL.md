---
name: tdd-node-api
description: Use when adding or changing behaviour in a Node or TypeScript service function, route handler, or repository method in a repo with tests, and on TDD or red-green-refactor. Skip config and type-only edits. Defines where the test goes and what makes it worth keeping.
---

# TDD for Node APIs

## What this does

It runs a red-green-refactor loop for backend TypeScript work and holds the
rules that decide whether the tests you end up with are worth keeping. It
defines where a test belongs, what a good test asserts, and the three ways
backend tests usually go wrong.

## When it runs

Automatically when a task is building or fixing behaviour in a service, route
handler, or repository function and a test path exists. It writes code, so it
runs inside `eng:implement` or on a request that names the exact change. A bug
report with no approved plan goes to `eng:investigate` first, and so does a
request for a regression test on a reported bug, because the reproduction
`eng:investigate` builds becomes that test once the plan is approved. You can
also start it by hand with `/eng:tdd-node-api`.

Skip it for one-line config edits, type-only changes, and throwaway scripts.

## How to use it

Say what behaviour you want. When no approved plan names the seam, the agent
asks which seam to test at and waits for your answer. Then the loop runs one
test at a time until the seam does everything agreed, and stops early when a
new test passes without reaching the code it is about, or when step 3 cannot
turn a test green within the plan. You get the new tests, the code that turned
each one green, and any test that was already failing before the work began.

---

## Step 1: Agree the seam

A seam is the public boundary you test at. You observe behaviour through it
without reaching inside the implementation.

Name the seam before writing anything. In a Node service the choices are:

| Seam | Test through | Use it when |
|---|---|---|
| Service function | Call the exported function directly | Business logic. The default choice. |
| HTTP route | Supertest against the Express or Nest app | Status codes, validation, auth, serialization |
| Repository | Call the repo against a real Mongo instance | Query shape, indexes, aggregation results |

When an approved plan's **Tests** section gives the level each test runs at,
that level is the seam, so write it down and go on. Otherwise ask the user:
"Which seam should this test live at?" Wait for the answer.

You cannot test everything. Agreeing the seam up front puts the effort on the
critical path instead of spreading it thin across every edge case.

Run the whole suite once before the first test, and write down every test
that already fails, so step 3 can tell those from failures this work causes.

**Done when:** a seam is written down, taken from the approved plan or named
by the user, and so is the list of tests already failing, or a note that none
are. Or the run is waiting on the user to name the seam, or has stopped
because the suite does not run, with the command and its error named.

## Step 2: Write one failing test

Write exactly one test. Run it. Confirm it fails on the assertion you wrote,
not on a setup error. Read the failure message to check.

A good test reads like a statement of a capability. "rejects a checkout when
the cart is empty" tells a reader what the system does, and it survives a
refactor because it never touches internal structure.

Take the expected value from somewhere independent: a known-good literal, a
worked example, the ticket. Compute it a different way than the code does.

More detail is in [references/good-tests.md](references/good-tests.md). Rules
for when a real Mongo instance is worth it, and when to stub, are in
[references/mocking.md](references/mocking.md).

A test that passes on its first run found one of two things. Either the
behaviour exists already, so keep the test, say so, and go to step 4. Or the
test never reaches the code it is about, so the seam or the setup is wrong,
and the run stops there with that named.

**Done when:** one test runs, fails, and the message names your assertion, or
it passed on its first run and the record names why, which is behaviour that
exists already, with step 3 skipped, or a seam or setup that misses the code,
with the run stopped.

## Step 3: Write the smallest code that passes

Write only enough to turn that one test green. Run the whole suite. Leave the
next test's behaviour for the next cycle. When the test cannot pass without
breaking the plan, or a failure resists every fix, stop there.

**Done when:** the whole suite is green apart from the tests step 1 recorded
as already failing, and the report names those. Or the run has stopped
because the test cannot pass without breaking the plan, or because a failure
resists every fix, with the failing test, its output, and what the plan got
wrong named.

## Step 4: Go back to step 2, then refactor

One seam, one test, one small implementation per cycle. Each test responds to
what the last cycle taught you.

Refactoring happens after the loop, not inside it. Once the seam does
everything agreed, refactor toward the clean solution the codebase would
want, one change at a time, and run the whole suite after each change. Fix or
undo a change that turns the suite red before making the next one.

**Done when:** the seam from step 1 does all the behaviour it was agreed to
do, every cycle added one test and only the code that turned it green, and
the refactor either found nothing to change or ran the whole suite after each
change and left it green apart from the failures step 1 recorded. A cycle
that added several tests at once, or code no test asked for, is the
horizontal slicing named below.

---

## The three ways backend tests go wrong

**Implementation-coupled.** The test mocks an internal collaborator, reaches
into a private method, or checks the result by querying Mongo directly
instead of asking the interface. The tell is that a refactor breaks the test
while the behaviour is unchanged. Assert through the same interface a caller
uses.

**Tautological.** The assertion recomputes the expected value the way the
code does, so it agrees with the code no matter what the code says.
`expect(total(items)).toBe(items.reduce(sum))` is this. So is a snapshot
generated from the code under test. Bring the expected value in from outside.

**Horizontal slicing.** Writing every test first, then all the
implementation. Bulk tests describe behaviour you imagined rather than
behaviour that exists. They lock in a test structure before you understand
the problem, and they stop reacting to real changes. Work one vertical slice
at a time instead.

---

Adapted from the `tdd` skill in mattpocock/skills (MIT).
