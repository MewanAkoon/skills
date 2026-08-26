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

Skip it for a change whose every caller is in the diff you are already looking
at. If grep for the symbol returns only lines you just wrote, there is no blast
radius to find.

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

## How to work through it

Read "Where to look", "The confidence ladder" and "Output" below before you
start step 1. Each step depends on one of them.

1. List what the change touches, then list what else reads or writes the same
   thing. Grep gives you the direct callers. Walk every category under "Where
   to look" for the rest, because grep finds none of those.
2. Write one sentence per item saying why it breaks or why it is safe. One
   sentence, so a weak claim has nowhere to hide.
3. Name the one or two claims the change's safety actually rests on. Take
   those to level 4 on the ladder below by running something.
4. Write the report in the shape under "Output".

Finish step 1 before starting step 3. Reaching for evidence while the list is
still growing puts the effort into the first risk found rather than the worst
one, and the worst one is usually not first.

## The confidence ladder

Get every claim to level 2 at least. Get the one or two the change rests on to
level 4, whatever it costs. Say where each one stopped.

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

Then one line at the end per fact the change's safety rests on, and whether
each is proven.

**Done when:** every risk carries a level of 2 or better, and each fact the
change rests on is at level 4. When you could not reach level 4, the report
names the exact command you could not run and the access you would need to run
it. "It was expensive" does not close this gate.

---

Adapted from the `blast-radius` skill in cursor/plugins pstack, by Lauren Tan
(MIT).
