# Test-first changes

Read this before writing code for a change in behaviour, at implement's step 2.

Use the repo's own runner, file layout, helpers, and way of starting a
database or emulator, from the nearest existing test of the same kind.

The seam is the level the plan's Tests section, a `pr-feedback` verdict, or
the request names. Otherwise it is the level of the nearest existing test of
the same kind, and with none, the exported function a caller uses. Log either
default as a ruling and go on.

Before the first test, run the package's tests once and write down every test
that already fails, so later runs can tell those apart.

Then, one cycle at a time: write one test, named for what the system does,
with its expected value from outside the code, such as a literal worked out
by hand or the ticket. See it fail on that assertion, not on setup. Write the
least code that passes. When a test passes on its first run, either the
behaviour exists, so keep the test and say so, or the test never reaches the
code, so fix the seam. Refactor only with the tests green.

Mock only what is outside the process: third-party HTTP at the network layer,
time, randomness, anything paid or irreversible. Run the repo's own modules
and its data store for real, and assert on the effect, not on the mock.

**Done when:** each change in behaviour has a test seen failing on its
assertion and then passing, with the list of tests that already failed
written down, or the run has stopped because the suite does not run, with
the command and its error.

---

Adapted from the `tdd` skill in mattpocock/skills (MIT).
