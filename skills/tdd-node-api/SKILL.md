---
name: tdd-node-api
description: Use when building or fixing behaviour in a Node API test-first. Triggers on "TDD", "red-green-refactor", "write a failing test first", "add a regression test", or any request to build a service function, route handler, or repository method with tests. Defines where the test goes and what makes it worth keeping.
---

# TDD for Node APIs

## What this does

It runs a red-green loop for backend TypeScript work and holds the rules that
decide whether the tests you end up with are worth keeping. It defines where
a test belongs, what a good test asserts, and the three ways backend tests
usually go wrong.

## When it runs

Automatically when a task is building or fixing behaviour in a service, route
handler, or repository function and a test path exists. You can also start it
by hand with `/tdd-node-api`.

Skip it for one-line config edits, type-only changes, and throwaway scripts.

## How to use it

Say what behaviour you want. The agent asks you to confirm the seam before it
writes anything. Answer that one question and let the loop run. It stops
after each green test so you can look.

---

## Step 1: Agree the seam

A seam is the public boundary you test at. You observe behaviour through it
without reaching inside the implementation.

Name the seam and confirm it with the user before writing anything. In a Node
service the choices are:

| Seam | Test through | Use it when |
|---|---|---|
| Service function | Call the exported function directly | Business logic. The default choice. |
| HTTP route | Supertest against the Express or Nest app | Status codes, validation, auth, serialization |
| Repository | Call the repo against a real Mongo instance | Query shape, indexes, aggregation results |

Ask: "Which seam should this test live at?" Wait for the answer.

You cannot test everything. Agreeing the seam up front puts the effort on the
critical path instead of spreading it thin across every edge case.

**Done when:** the user has named a seam and it is written down.

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

**Done when:** one test runs, fails, and the message names your assertion.

## Step 3: Write the smallest code that passes

Write only enough to turn that one test green. Run the whole suite. Leave the
next test's behaviour for the next cycle.

**Done when:** the whole suite is green.

## Step 4: Go back to step 2

One seam, one test, one small implementation per cycle. Each test responds to
what the last cycle taught you.

Refactoring happens after the loop, at review time, not inside it.

**Done when:** the seam from step 1 does all the behaviour it was agreed to
do, the whole suite is green, and every cycle added one test and only the code
that turned it green. A cycle that added several tests at once, or code no
test asked for, is the horizontal slicing named below.

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
