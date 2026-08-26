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

Run the suite once before you touch anything, and write down which tests are
already failing. This is the last moment that list is honest, and step 3
compares against it.

Read [references/mocking.md](references/mocking.md) before you steer the
answer: the repository seam is cheaper than it looks, because an in-memory
Mongo starts in a couple of seconds.

Then ask: "Which seam should this test live at?" Wait for the answer, and say
it back in one sentence naming the seam and what you will call through.

You cannot test everything. Agreeing the seam up front puts the effort on the
critical path instead of spreading it thin across every edge case.

**Done when:** the user has named one of the three seams, you have repeated it
back, and the already-failing tests are written down.

## Step 2: Write one failing test

Create the function first, with a real signature and a body of
`throw new Error("not implemented")`, so the run reaches your assertion instead
of dying on a missing import. An empty body fails to compile once the return
type is anything but `void`, the same way it does in `architect` phase 2. Then write exactly
one test, with the seam from step 1 as a comment on the first line of the test
file, so the next cycle can read it back.

Run it. Confirm it fails on the assertion you wrote, not on a setup error. Read
the failure message to check.

A good test reads like a statement of a capability. "rejects a checkout when
the cart is empty" tells a reader what the system does, and it survives a
refactor because it never touches internal structure.

Take the expected value from somewhere independent: a known-good literal, a
worked example, the ticket. Compute it a different way than the code does.

Read [references/good-tests.md](references/good-tests.md) when naming the test
or deciding what to assert on.

Read [references/mocking.md](references/mocking.md) when deciding whether to
run a dependency for real or stub it, including whether a real Mongo instance
is worth the setup.

**Done when:** one test runs, fails, and the message names your assertion.

## Step 3: Write the smallest code that passes

Write only enough to turn that one test green. Run the whole suite. Leave the
next test's behaviour for the next cycle.

Compare against the failures you wrote down in step 1. Green means no new ones,
so a suite that arrived broken does not become your problem mid-cycle.

**Done when:** your new test passes and the suite has no failures that were not
there at the start.

## Step 4: Go back to step 2

One seam, one test, one small implementation per cycle. Each test responds to
what the last cycle taught you.

Stop when every behaviour you named in step 1 has a test at the agreed seam.

Refactoring happens after the loop, at review time, not inside it.

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
