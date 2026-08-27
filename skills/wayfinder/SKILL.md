---
name: wayfinder
description: A map of decision tickets for work too big for one session.
disable-model-invocation: true
---

# Wayfinder

## What this does

It takes a loose idea that is too big for one agent session and charts the
route to it as a map of small questions, held in Markdown files in the repo.
Each question is a decision, and each session resolves one of them.

The map is deliberately incomplete. You chart the part of the route you can
see, and each answer reveals a bit more of the rest.

## When to use it

When an idea arrives that cannot fit in one session, and the way to it is not
visible yet. A migration whose shape depends on what the data turns out to
be, a new subsystem where half the design is still open questions, a course
or a spec being written from nothing.

Skip it when the work fits in one session, which is `/architect` or
`/grill-me`. Skip it when the decisions are already made and what is left is
execution: that is a task list, not a map.

## How to use it

Two modes.

- `/wayfinder <the loose idea>` charts a new map. It questions you first,
  then writes the map and the first tickets, and stops.
- `/wayfinder .scratch/<slug>` works the map: it picks the next ticket,
  resolves it with you, records the answer, and stops.

One decision per session, so the answer gets a whole context window. Research
tickets are the exception, and several can run at once.

The file layout, the map template, the ticket template, the resolution
format, and the command that finds the next ticket are in
[references/tracker-local.md](references/tracker-local.md). Read that file
before creating or updating anything in the map.

---

## A session produces decisions

Every ticket resolves a decision, so a session produces decisions rather than
deliverables. The pull to just go and do the work is usually the signal that
the map has reached its edge, and that is the point to hand off. An effort
that wants execution inside the map says so under the map's notes, and then
this section does not apply to it.

## The map

The map is one file, `.scratch/<slug>/map.md`, built from the template in the
reference.

It is an index. A decision lives in its own ticket file, and the map carries
one line of gist and a link to it. Open tickets are not listed on the map at
all: they are files in `tickets/`, and you find them by looking.

Name the destination first. It fixes the scope, so every later question is
either on the way to it or out of scope. One or two lines: the spec to hand
off, the decision to lock, the change to make.

Refer to a ticket by its title in everything you write for the human. A list
of numbers is unreadable a week later. The number stays in the filename and
the link.

## Tickets

One ticket is one question whose answer is a decision, sized so that
answering it fits in one session. Each ticket is a file under `tickets/`,
with the fields the template names.

Every ticket is either HITL, worked live with the human, or AFK, driven by
the agent alone. A HITL ticket resolves only through that live exchange, and
the human supplies every answer on their side of it. An agent that answers
its own grilling questions has broken the ticket.

Four types:

- **Research** (AFK). An answer that exists somewhere outside this repo: a
  third-party API's real behaviour, a library's constraints, what the data
  actually looks like.
- **Prototype** (HITL). The question is "how should this look" or "how should
  this behave", and prose keeps going in circles. Build the cheapest rough
  thing that can be reacted to, and link it from the ticket.
- **Grilling** (HITL). A decision that gets made by talking it through. The
  default type. Ask one question at a time and follow the answer. Where the
  ticket needs a harder interrogation than this, ask the user to run
  `/grill-me` on it and bring back the result. Where the answer is a shape
  rather than a choice, ask them to run `/architect`.
- **Task** (HITL or AFK). Manual work that unblocks a decision without being
  one: getting an API key so the API can be judged, moving data so its shape
  can be seen, provisioning access. The answer records what was done and any
  facts later tickets depend on.

A session claims a ticket before doing any work.

A ticket is **takeable** when it is open, unclaimed, and every ticket that
blocks it is closed. Those are the frontier.

## Fog

Beyond the tickets sits the part of the route you can tell is coming and
cannot yet describe. It goes in the map's "not yet specified" section, as
loosely as you can see it.

The test for whether something becomes a ticket is whether you can state the
question sharply now, not whether you can answer it now. A sharp question
that is blocked for a week is a ticket. A vague area is fog.

Resolving a ticket usually sharpens some fog. Turn that into tickets and
delete the patch of fog it came from, so each thing exists in one place.

## Out of scope

Work that sits past the destination is not fog, and it never graduates. It
goes in the map's "out of scope" section with one line saying why.

When a ticket that already exists turns out to be past the destination, close
it, move one line to "out of scope", and leave it out of "decisions so far".
That section records the route actually walked, and a scope boundary is not a
step on it.

## Mode 1: chart the map

1. **Name the destination.** Question the user until they can say in two
   lines what reaching the end of this effort looks like. Where that needs a
   harder interrogation, ask them to run `/grill-me` first and come back with
   the result.
2. **Map the frontier.** Question them again, this time going wide rather
   than deep: fan out across the whole space, and write the list of open
   questions, marking which ones could be taken today. If this turns up no
   fog, the effort fits in one session. Say so and stop.
3. **Write the map file** from the template: destination, notes, empty
   decisions, the fog you found.
4. **Write the tickets you can state sharply**, one file each, then wire the
   blocking edges in a second pass once all the files have numbers.
5. **Run the research tickets** now, in parallel, and record their answers.
6. **Stop** once those answers are recorded. Charting resolves no grilling,
   prototype, or task tickets.

**Done when:** the map file names a destination the user agreed to, every
question from step 2 is either a ticket file or a line under "not yet
specified", every ticket's blocked-by line names tickets that exist or says
none, every research ticket created in step 4 is closed with its answer, and
at least one ticket is takeable. Or step 2 turned up no fog, in which case
nothing is written and the run has said the effort fits in one session.

## Mode 2: work the map

1. **Read the map file only.** Not every ticket. The map is the low
   resolution view, and it is what fits alongside a session's real work.
2. **Pick a ticket.** The one the user named, or the first line printed by
   the takeable-tickets loop in the reference. **Claim it before anything
   else.**
3. **Resolve it.** Work out who answers before anything else. Research runs
   afk, prototype and grilling run hitl, and a task ticket carries its own
   `Driver` field. An hitl ticket waits for the human on every question, an
   afk ticket runs to its answer without one. Open closed tickets on demand when
   you need the detail behind a decision, and use the skills the map's notes
   name. Where the answer turns out to wait on something this session cannot
   get, unclaim the ticket and write one line on it naming what it waits on.
4. **Record the answer** in the ticket file, mark it closed, and append one
   line of gist plus the link to the map's decisions.
5. **Update the route.** Four things, each of which gets a line saying what
   changed or that nothing did: tickets the answer surfaced, fog it sharpened
   into tickets, anything the answer put past the destination, and open
   tickets the answer invalidated. Deleting a ticket includes removing its
   number from every blocked-by line that names it.
6. **Check whether the map cleared.** When no ticket is open and nothing is
   left under "not yet specified", write out what the map produced: the
   destination, and the decisions that make the way to it clear.

**Done when:** the ticket is closed with its answer written down and an hitl
ticket's answers came from the human rather than from the agent, the map's
decisions has one new line linking it, each of step 5's four updates has a
line saying what changed or that nothing did, and step 6 has either written
the map out or named what is still open, whether a ticket or a patch of fog.
Or the ticket is back to unclaimed with a line naming what it waits on, and
the map is unchanged.

---

Adapted from the `wayfinder` skill in mattpocock/skills (MIT). The issue
tracker is narrowed to local Markdown files.
