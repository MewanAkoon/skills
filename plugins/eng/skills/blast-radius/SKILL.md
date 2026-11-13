---
name: blast-radius
description: Use when planning a change to something shared, such as a schema field, a utility many modules import, middleware on every route, a shared type, an env var, or an index, and when asked what a change breaks elsewhere. Proves the key safety fact by running code.
---

# Blast radius

Listing callers is what grep does. The job is the breakage grep misses, and
proof of the one or two facts the change's safety rests on. A review of a
branch or a PR goes to `/code-review` instead.

## The evidence ladder

Label every safety claim with the level its evidence reached:

1. **You said so.** Never enough for the key fact.
2. **You pointed at a line.** A `file:line`, or the library's own source.
3. **You showed the bad case cannot happen.** The failure path, walked step
   by step, does not reach.
4. **You ran it.** A script, query or test that would fail if the claim were
   false, and it passed.

A safety fact below level 4 is written down as unproven. Level 4 is usually
one small script that imports the library the app ships and calls the exact
function in question. Write it in the scratchpad, or a `mktemp -d`
directory, and run it on local or test data. A Node script there resolves
imports from its own directory, so load the app's packages with
`createRequire("<repo>/package.json")` from `node:module`. A script that has
to live in the repo, a query on a shared or production database, or a call to
a live service waits for the user's go-ahead.

## Where grep misses

- **Runtime dispatch.** Dynamic imports, string-keyed handler maps, event
  names, decorator metadata, DI registrations.
- **Data already written.** A schema change that fits new records and not the
  ones already stored. Check what is stored, not what the schema says.
- **Consumers outside the repo.** An old mobile app, a webhook receiver,
  another service on the same collection, a cached response.
- **Serialization.** A rename the test never sees because it asserts on the
  object while the client reads the JSON.
- **Order and timing.** Middleware order, index build time, a migration
  running while old code still serves traffic.
- **Config drift.** An env var in `.env` and missing in staging.

## Output

**Risks**, each with what breaks, the `file:line` or query behind it, its
level, and what would settle it when below 4. **Cleared**, one line for each
thing checked that turned out fine, naming how. **Before you merge**, the
cheapest test that would catch the real bug. Last, one line: the fact the
change's safety rests on, and whether it is proven.

**Done when:** every risk has a level, every source touched appears under
Risks or Cleared, and the key fact is proven at level 4 or labelled unproven
with the run tried and what stopped it, a wait on the user's go-ahead
included.

---

Adapted from the `blast-radius` skill in cursor/plugins pstack, by Lauren Tan
(MIT).
