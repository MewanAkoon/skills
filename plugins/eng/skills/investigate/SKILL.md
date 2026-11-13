---
name: investigate
description: Use at the start of a task, before changing code, when given a ticket, a Slack thread, an issue, an error or log, a bug report, or a question about how or where something works. Reads the sources, code and history, and ends with a checked plan that waits for approval.
---

# Investigate

Find out what is true before anything changes, write a plan checked against
it, and stop. A request that names the exact change, or points to an approved
plan, goes to `eng:implement` instead. One to review a PR or a diff goes to
`/code-review`. A question about the code, rather than a task, follows
[references/answers.md](references/answers.md) and ends in an answer, with no
plan and no stop.

## Step 1: Read the sources

Read everything the request points to, in full: a PR with its review
threads, a whole Slack thread, a ticket, handoff or plan file, and the whole
of an error or log, not the line quoted in the request.

**Done when:** every source the request names is read, or listed with the
reason it could not be.

## Step 2: Read what the repo says about itself

Find the guidance files with the probe in `eng:commit`'s
`references/repo-guidance.md`, and read the parts that cover this task. Then
read what the probe does not list: the docs the root guidance file points at,
ADRs under `docs/adr/`, a glossary, `.claude/rules/` and `.cursor/rules/`, and
the package README. A conflict with an ADR goes in the plan as a risk.

**Done when:** the files read are listed by path, or the repo has none.

## Step 3: Trace the code and its history

Pick one concrete trigger, such as one request, one message, or one job, and
follow it end to end, opening the code at every hop. Note each place the path
leaves the process: another service, a queue, a cache, a third-party API.

Read `git log -L` or `git blame` on the lines that will change. Before
removing or rewriting code the request did not name, call the Skill tool with
`eng:why`. When the change touches something shared, such as a schema, a
shared type, a utility many modules import, middleware, or an env var, call
it with `eng:blast-radius`.

When the area spans several files, split independent questions across two to
four read-only subagents at once, each briefed with one question and pointers
rather than summaries, each returning claims with a `file:line`.

**Done when:** every hop has a `file:line` and a sentence on what runs there,
the changed lines have their history read, and each subagent question has an
answer or is listed as open.

## Step 4: Get real signal for a bug

The user's account of a bug is a hypothesis until an error, a log, or a
failing run backs it. For a failing CI check, a flaky test, a bug that
reproduces only sometimes or survived a fix, or a performance regression,
work the phases in [references/debugging.md](references/debugging.md). When
the signal cannot be had, the plan names what is missing and asks for it.

**Done when:** the cause rests on output from a run you observed, or the plan
names the missing signal, or the task is not a bug.

## Step 5: Write the plan

Fill in [references/plan.md](references/plan.md). The plan goes in
`<repo>/.claude/plans/<slug>.md` whenever its Delivery lists writes, or when it
is longer than a screen.

**Done when:** every section of the template holds content or reads "none".

## Step 6: Check it

Read the plan against the code, the findings and the request: each change
names its file, each change in behaviour its test, each doc it makes false is
listed, and nothing asked for is missing. When the plan spans more than one
area, one general-purpose subagent also runs the check in
[references/checks.md](references/checks.md), claims and plan together. Drop a
finding it refutes, or mark it disputed with both sides. Revise and read
again.

**Done when:** a pass turns up nothing new, or what remains is listed under
open questions.

## Step 7: Stop

Present the plan and wait. Repo files other than the plan file stay unedited,
and the branch stays as it is, until the user approves. A yes that names items
approves those items. In Claude Code plan mode, call ExitPlanMode with the
plan. When several decisions are still open, suggest `/eng:grill-me`.

**Done when:** the plan is in front of the user and the turn has ended, or
ExitPlanMode has returned, approval going to `eng:implement` and feedback back
to step 6.

---

The trace and the answer shape are adapted from the `how` skill in
cursor/plugins pstack, by Lauren Tan (MIT). The debugging reference is
adapted from the `diagnosing-bugs` skill in mattpocock/skills (MIT).
