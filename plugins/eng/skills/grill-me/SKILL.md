---
name: grill-me
description: Get interviewed about a plan or design until every open decision is resolved.
disable-model-invocation: true
---

# Grill me

## What this does

It interviews you until the design has no open decisions, and writes down
what you decided. Nothing gets built.

## When to use it

Before a feature or refactor you would hate to throw away, or on a plan the
agent has just presented with questions still open. Skip it for a task one
sentence describes.

## How to use it

Type `/eng:grill-me` with the idea, roughly, or after a plan. Answer the
questions. Say "enough" to stop, or "decide" for one you have no view on. You
get a short summary of the decisions.

---

## The interview

- One question at a time, depth-first. Follow an answer into its
  consequences before the next topic.
- Ask what is expensive to get wrong: data shape first, then boundaries,
  failure of each external call, a second run on the same input, existing
  data that does not fit, what is out of scope, and what done means.
- A vague answer gets asked again, as what the caller sees, what is logged,
  and what happens to half-finished work.
- Find facts yourself from the repo and its tools. Ask the user only what
  they alone can decide.
- On "decide" or "I don't know", give two concrete options with the
  trade-off, and take a pick.
- When an answer contradicts an earlier one, quote both and ask which holds.

## Ending

Stop when no remaining answer would change the build, or on "enough". Write
the decisions, the options rejected and why, and what is still open. Run on a
presented plan, the answers go into that plan's Open questions, each marked
settled with the user's answer, and the plan file is updated when it has one.

**Done when:** the summary, or the updated plan, is in front of the user and
the turn has ended. Building starts only when the user approves a plan or
names the exact change.

---

Adapted from the `grill-me` and `grilling` skills in mattpocock/skills (MIT).
