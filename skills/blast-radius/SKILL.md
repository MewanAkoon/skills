---
name: blast-radius
description: Find what a small change could break somewhere else, and prove the key safety fact by running code.
disable-model-invocation: true
---

# Blast radius

## What this does

It finds what a change breaks outside its own diff, and it makes the agent
say how strong its evidence is for each claim rather than handing you a
confident writeup.

## When to use it

Before shipping a change that looks small but touches something shared: a
Mongoose schema field, a utility every service imports, a middleware mounted
on every route, a shared type, an env var, a database index.

Also useful on a diff someone else wrote that you do not trust yet.

## How to use it

Type `/blast-radius` with the change described, or point it at a diff or a
branch. It comes back with a short list of risks and the evidence level for
each one.

---

## The trap this exists to avoid

A blast-radius writeup reads as convincing whether or not it is true. Listing
the callers is not the job, grep does that in a second. The job is the
breakage grep does not show you, and the proof that the one thing holding it
all together is actually true.

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

Label every claim with its level. A report where the critical fact sits at
level 1 is a report that has not done its job.

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

Keep it short. For each risk:

- What breaks
- Why you think so, with a `file:line` or the query you ran
- Evidence level, 1 to 4
- What would settle it, if it is below 4

Then one line at the end: the single fact this change's safety rests on, and
whether it is proven.

---

Adapted from the `blast-radius` skill in cursor/plugins pstack, by Lauren Tan
(MIT).
