---
name: grill-me
description: Get interviewed about a plan or design until every open decision is resolved.
disable-model-invocation: true
---

# Grill me

## What this does

It reverses the usual direction. Instead of the agent building what it thinks
you meant, it interviews you until the design has no unresolved branches
left, and only then writes anything.

Most bad output comes from a gap between what you pictured and what the agent
understood. This closes that gap before any code exists, which is the
cheapest point to close it.

## When to use it

Before starting any feature or refactor big enough that you would be annoyed
to throw it away. Before writing a spec. When you have a rough idea and you
know there are decisions inside it you have not made yet.

Skip it for a task you could describe completely in one sentence.

## How to use it

Type `/grill-me` and describe the thing, roughly. Answer the questions.
Say "enough" when you want it to stop early, or "I don't know, decide" for a
question you have no opinion on.

At the end you get a short written summary of every decision. Keep that. It
is the input to whatever you build next.

---

## Rules for the interview

**One question at a time.** A numbered list of eight questions gets three
lazy answers. One question gets a real one.

**Go depth-first.** Ask the goal question first and the data shape question
second. From there follow an answer into its consequences before moving to a
new topic. An answer that opens two new questions means those two come next,
not later.

**Ask about the thing that would be expensive to get wrong.** Data shape,
failure behaviour, ownership, and what happens on the second run. Not
variable names.

**When an answer is vague, ask again.** "It should handle errors gracefully"
is not an answer. Ask what the caller sees, what gets logged, and what
happens to the half-finished work.

**Decide when asked.** If the user says they do not know, name two concrete
options with the trade-off. If they pick, take their pick. If they hand the
decision back, choose one yourself and record the choice and the reason in the
summary, so the question does not come back a second time.

**Say when an answer contradicts an earlier one.** Quote both and ask which
one holds.

## Question areas worth reaching

Work through these, skipping the ones that do not apply:

- **The actual goal.** What does the user of this see that they do not see
  now? If nothing, why build it.
- **Data shape.** What is stored, in what form, and what is derived at read
  time. Ask this second, right after the goal, because everything downstream
  follows from it.
- **Boundaries.** What comes in from outside, what goes out, and what is
  internal.
- **Failure.** Every external call can fail. What happens for each one, and
  what does the caller see.
- **Second run.** What happens if this runs twice on the same input.
  Retries, duplicate webhooks, a double-clicked button.
- **Existing data.** What happens to the records that already exist and do
  not match the new shape.
- **Scope edges.** Name at least two things adjacent to this that you are
  choosing not to build, and one sentence each on why they are out. Getting
  the "not this" list explicit prevents half of the scope creep.
- **Done.** What has to be true before you would call this finished.

## Ending

Every area under "Question areas worth reaching" is either answered or written
into the summary as not applying, with one sentence on why. That is the floor.
Past it, stop when the remaining questions would not change the build.

On "enough", stop there and write the summary immediately, listing every area
you did not reach under "still open".

Write the summary in chat: the decisions made, the options rejected and why, the
decisions you made on the user's behalf, and anything still open. Short. It is a
record, not a document.

**Done when:** every question area is answered or recorded as not applying, and
the summary is written.

---

Adapted from the `grill-me` and `grilling` skills in mattpocock/skills (MIT).
