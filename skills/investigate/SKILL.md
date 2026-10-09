---
name: investigate
description: Use at the start of a task, before changing code, when given a ticket, a Slack thread, an issue, an error or log, a bug report, or a question about how or where something works. Reads the sources, the code and its history, verifies the findings, and ends with a checked plan that waits for approval.
---

# Investigate

## What this does

It finds out what is true before anything changes, then writes a plan checked
against that and stops. It reads what the request points to, traces the code
and its history, has a second agent check the findings, and ends with a plan
that waits for approval.

## When it runs

At the start of any task that will change code, config, or docs, and for a
question about how or where something works. A request that names the exact
change, or points to an approved plan, skips this and goes to `eng:implement`.

## How to use it

Nothing to invoke. Paste the link, ticket, error, or question. A task ends with
findings and a plan, then a stop: approve it, or approve some items, to start
`eng:implement`. A question ends with an answer and no plan.

---

## Step 1: Read the sources

Read everything the request points to. A PR: `gh pr view <n> --json
title,body,files,reviews,comments` and its review threads. A Slack link: the
whole thread. A ticket, a handoff document, a plan file: in full. An error or
a log: the whole of it, not the line quoted in the request.

**Done when:** every source the request names is read, or listed with the
reason it could not be.

## Step 2: Read what the repo says about itself

In this order: the root `AGENTS.md` or `CLAUDE.md`, the docs its pointer table
names, the nested `AGENTS.md` or `CLAUDE.md` in each directory touched,
`CONTRIBUTING.md`, ADRs under `docs/adr/`, a glossary, `.claude/rules/` and
`.cursor/rules/`, and the package README. A missing file is not a finding. A
conflict with an ADR goes in the plan as a risk.

**Done when:** the files read are listed by path, or the repo has none.

## Step 3: Trace the code and its history

Pick one concrete trigger, such as one request, one message, or one job, and
follow it end to end. Open the code at every hop. Note each place the path
leaves the process: another service, a queue, a cache, a third-party API.

Read `git log -L` or `git blame` on the lines that will change. Before
removing a guard, a retry, or a special case, call the Skill tool with
`eng:why`. When the change touches something shared, such as a schema, a shared
type, a utility many modules import, middleware, or an env var, call the Skill
tool with `eng:blast-radius`.

Split questions that do not depend on each other across two to four
subagents at once: Explore for searches, a general-purpose agent for reads
that need `gh`, git, or an MCP tool. Each brief carries:

- The question, in one sentence.
- Pointers: paths, URLs, and commit SHAs, never pasted summaries.
- The return shape: claims, each with `file:line` and whether it was seen or
  inferred.
- The limits: read-only, no subagents, no commits.

**Done when:** every hop has a `file:line` and a sentence on what runs there,
the changed lines have their history read, and each subagent question has an
answer or is listed as open.

## Step 4: Get real signal for a bug

The user's account of a bug is a hypothesis until the error, the log, or a
failing request backs it. Before running anything for a flaky test, a bug
that reproduces only sometimes, one that survived a fix, or a performance
regression, read [references/debugging.md](references/debugging.md) and work
its phases.

**Done when:** the cause rests on output from a run you observed, or the plan
names the signal that is missing and asks for it, or the run has stopped to
ask before putting a reproduction or logging in the repo, or the task is not a
bug.

## Step 5: Check the findings a second time

Give the findings to a `eng:reviewer` subagent with the claims lens, the paths
it needs, and a directory from `mktemp -d` under the scratchpad your system
prompt names, or under `${TMPDIR:-/tmp}` when it names none, for any probe it
runs. When no agent named `eng:reviewer` is installed, brief a general-purpose
agent with the same lens and tell it to edit nothing. Drop a finding it refutes,
or mark it disputed with both sides. When every finding cites one short file,
re-open each cited line yourself instead.

**Done when:** every finding is confirmed, dropped, or marked disputed.

## Step 6: Write the plan

Fill in [references/plan.md](references/plan.md). When the change adds or
reshapes an interface, sketch it first with
[references/interfaces.md](references/interfaces.md). A plan longer than a
screen, or one another session will carry out, goes in
`<repo>/.claude/plans/<slug>.md`.

**Done when:** every section of the template holds content or reads "none".

## Step 7: Cross-check and revise

Read the plan against the code, the findings, the request, and the patterns
the repo already uses. Each change names the file it lands in, each change in
behaviour names its test, each doc the change makes false is listed, and
nothing the request asked for is missing. For a plan that spans more than one
area, a `eng:reviewer` with the plan lens makes this pass. Revise and read
again.

**Done when:** a pass turns up nothing new, or what remains is listed under
open questions.

## Step 8: Stop

Present the plan and wait. Edits to repo files wait for approval, except the
plan file. In Claude Code plan mode, call ExitPlanMode with the plan. When
several decisions are still open, suggest `/eng:grill-me`.

**Done when:** the plan is in front of the user and the turn has ended, or,
in plan mode, ExitPlanMode has returned approval, which goes to `eng:implement`,
or feedback, which goes back to step 7.

## Questions

For a question rather than a task, run steps 1 to 3, and step 5 when the
answer rests on more than one finding. Then answer in the shape in
[references/answers.md](references/answers.md). There is no plan and no stop.
A question about why code is shaped the way it is goes to the `eng:why` skill,
which reads the history behind it.

---

Step 3's trace and the answer shape are adapted from the `how` skill, and the
interface sketch from the `architect` skill, both in cursor/plugins pstack, by
Lauren Tan (MIT). The debugging reference is adapted from the
`diagnosing-bugs` skill in mattpocock/skills (MIT).
