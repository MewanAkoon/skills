---
name: blast-radius
description: Use when planning a change to something shared, such as a schema field, a utility many modules import, middleware on every route, a shared type, an env var, or an index, and when asked what a change breaks elsewhere. Finds breakage that grep misses and proves the key safety fact by running code.
---

# Blast radius

## What this does

It finds what a change breaks outside its own diff, and it makes the agent
say how strong its evidence is for each claim rather than handing you a
confident writeup.

## When to use it

When planning a change that looks small but touches something shared: a
Mongoose schema field, a utility every service imports, a middleware mounted
on every route, a shared type, an env var, a database index. Also when someone
asks what a change breaks elsewhere, and nothing more.

Skip it for a change that nothing outside its own file reads. A review of a
branch or a PR, someone else's diff included, goes to `eng:review-diff`, which
checks for regressions as one of its passes.

## How to use it

Nothing to invoke when it fires on its own, and `eng:investigate` calls it when
a plan touches shared code. To ask directly, type `/eng:blast-radius` with the
change you are planning. It comes back with a short list of risks and the
evidence level for each one.

---

## The trap this exists to avoid

A blast-radius writeup reads as convincing whether or not it is true. Listing
the callers is not the job, grep does that in a second. The job is the
breakage grep does not show you, and the proof that the one thing holding it
all together is true.

So do not hand back the writeup. Find the one or two facts the change's
safety depends on and prove those by running something.

## The confidence ladder

For every claim that the change is safe, get the evidence as far down this
list as is cheap, then say where it stopped.

1. **You said so.** Worthless alone. Never the final answer for the key fact.
2. **You pointed at a line.** A real `file:line`, or the library's own
   source. Better, still not proof.
3. **You showed the bad case cannot happen.** You walked the failure path
   step by step and it does not reach.
4. **You ran it.** A script, a query, a test that would fail if the claim
   were false, and it passed.

Label every claim with its level. Any safety fact that stopped below level 4
gets written down as unproven, not as settled. Level 4 is usually one small
script that imports the same library the app ships and calls the exact
function you are worried about. Write it under the scratchpad directory your
system prompt names, or under `${TMPDIR:-/tmp}` when it names none, and run it
against local or test data. A Node script there resolves imports from its own
directory, so load the app's packages with
`createRequire("<repo>/package.json")` from `node:module`.

A script that has to sit in the repo to run, a query against a shared or
production database, or a call to a live service waits for the user's
go-ahead, and until then the fact stays below level 4.

## Where to look

Grep finds direct callers. These are the things it does not find:

- **Runtime dispatch.** Dynamic imports, string-keyed handler maps, event
  emitter names, decorator metadata, DI container registrations.
- **Data already written.** A schema change is fine for new documents and
  wrong for the two million already in the collection. Check what is stored,
  not what the schema says.
- **Consumers outside this repo.** A mobile app on an old version, a webhook
  receiver, another service reading the same collection, a cached response.
- **Serialization boundaries.** A field rename that a test never sees because
  the test asserts on the object, and the client reads the JSON.
- **Order and timing.** Middleware order, index build time, a migration that
  runs while the old code is still serving traffic.
- **Config drift.** The env var exists in your `.env` and not in staging.

## Output

Keep it short. Under **Risks**, for each one:

- What breaks
- Why you think so, with a `file:line` or the query you ran
- Evidence level, 1 to 4
- What would settle it, if it is below 4

Then **Cleared**: what you checked that turned out fine, one line each naming
what you checked it with. Without this a reader cannot tell a risk you cleared
from one you never looked at.

Then **Before you merge**: the cheapest test or repro that would catch the
real bug.

Then one line at the end: the single fact this change's safety rests on, and
whether it is proven.

**Done when:** every risk carries an evidence level, every source you touched
appears under either Risks or Cleared, Before you merge names a test or repro
that would fail if the safety fact were false, and that fact is either
labelled proven by a level 4 run, or labelled unproven with the run that was
attempted and what stopped it, or with a run waiting on the user's go-ahead.

---

Adapted from the `blast-radius` skill in cursor/plugins pstack, by Lauren Tan
(MIT).
