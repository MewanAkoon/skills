---
name: how
description: A subsystem walkthrough, and a placement answer for new code.
disable-model-invocation: true
---

# How

## What this does

It builds the mental model of a subsystem that a senior engineer would have
after a week in it: what triggers it, what happens at each hop, where the
files are, and what a newcomer gets wrong.

It also answers placement. "Which module owns this" is the same question with
the answer pointed forwards.

## When to use it

Before changing code in a service you did not write. When you inherit a
codebase. When you know what to build and not where to put it. When a
reviewer asks you to explain a flow you only half understand.

Skip it for a single function you can read in one screen. Skip it when the
question is why the code ended up this way, which is `/why`.

## How to use it

Type `/how` and the question: "how does the invoice webhook work", "walk me
through what happens when a user signs up", "which package should the retry
helper live in".

It states its reading of the question in one line and then answers. It does
not ask clarifying questions first, so redirect it if that line is wrong.

---

## Step 1: Fix the question and the scope

Restate the question in one line, naming the concrete thing being asked
about.

Then size it:

- **Narrow.** One module, a handful of files, one flow. Read it in a single
  pass.
- **Wide.** Several packages or services, a cross-cutting concern, or a full
  overview. Name two to four angles that each cover a different slice, and
  work through each one before writing anything. For a request flow the
  angles are usually the entry path, the data model and its writes, and the
  surrounding configuration and infrastructure.

When it could go either way, treat it as narrow. Widen it after the single
pass hits something it cannot explain.

**Done when:** the question is restated in one line, the scope is declared
narrow or wide, and a wide scope has its angles named.

## Step 2: Trace one real path end to end

Pick one concrete trigger: a single HTTP request, one queue message, one cron
tick, one page render. Follow that one path. In a wide scope, run this step
once per angle from step 1.

Open the code at every hop. A file name and an import graph tell you what the
author intended to build, not what runs.

In this stack the hops usually run route or controller, validation, service,
repository or Mongoose model, database, then whatever shapes the response.
Note every place the path leaves the process: another service, a third-party
API, a queue, a cache.

**Done when:** every hop from trigger to stored or returned result is named
with a `file:line`, and each hop says which function runs and what it does to
the data.

## Step 3: Name what surprised you

Write down what a newcomer would get wrong:

- A name that means something other than what it says.
- Ordering that matters and is not obvious, such as middleware that has to
  run before something else.
- A default that is not the default you would expect.
- Code that looks dead and runs, or looks live and does not.
- An interface with one implementation, and whether a second was ever
  planned.

**Done when:** at least one entry is written down, or the explanation states
that the trace found nothing surprising.

## Step 4: Answer the placement question

Only when the question was about where code goes.

List the candidate locations, two or three. For each one, say what it already
owns, what it imports, and who imports it. That fixes which direction a new
dependency would point.

Then pick one. Name the runner-up and give one sentence for why it lost.

**Done when:** one path is named as the answer, one alternative is named as
rejected, and the reason fits in a sentence.

## Output

Use these headings, dropping any that the question does not need.

**Overview.** One or two paragraphs. What this thing is, what it does, why it
exists.

**Key pieces.** The types, services, and models the rest of the explanation
depends on. One line each.

**The path.** The trace from step 2, in prose, with `file:line` references so
the reader can go and look. Include a code block only where the code says
something the prose cannot.

**Where to start reading.** The two or three files someone new to this area
opens first.

**Gotchas.** Step 3.

**Placement.** Step 4, when it ran.

## What this leaves to other skills

It explains the design without arguing with it. To find what a change would
break, use `/blast-radius`. To pull apart a design before building it, use
`/grill-me`. To find out why the design is what it is, use `/why`.

---

Adapted from the `how` skill in cursor/plugins pstack, by Lauren Tan (MIT).
The subagent fan-out and model routing are removed, and critique mode is
dropped in favour of the existing `blast-radius` and `grill-me` skills.
