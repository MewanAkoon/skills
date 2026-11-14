---
name: investigate
description: Use at the start of a task, before changing code, when given a ticket, a Slack thread, an issue, an error or log, a bug report, or a question about how or where something works. Reads the sources, code and history, and ends with a checked plan that waits for approval.
---

# Investigate

Find out what is true before anything changes, write a plan checked against
it, and stop. A request that names the exact change, or points to an approved
plan, goes to `eng:implement` instead. One to review a PR or a diff goes to
`/code-review`. A question about the code, rather than a task, or a report
such as an audit or a status review, follows
[references/answers.md](references/answers.md) and ends in an answer, with no
plan and no stop. Every subagent runs on the model and effort in
[references/models.md](references/models.md).

## Step 1: Read the sources

Read everything the request points to, in full: a PR with its review
threads, a whole Slack thread, a ticket, handoff or plan file, and the whole
of an error or log, not the line quoted in the request.

Read a ticket key or link with its tracker's MCP tools, found as `eng:issue`'s
[tracker.md](../issue/references/tracker.md) says, or `gh` for GitHub. When
the session has none for that tracker, say which tracker's MCP server to
connect, and read nothing in its place: no guess at the ticket from its key,
a branch name or a search.

On a task, launch round 1 of the check in
[references/checks.md](references/checks.md) as the reading starts, beside
your own, briefed with the request and the sources, not an answer.

**Done when:** every source the request names is read, or listed with the
reason it could not be, and on a task round 1 is running.

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
is longer than a screen. The lists steps 1 to 3 ask for go in its Progress,
not the reply.

**Done when:** every section the task needs is filled, and the rest are
left out.

## Step 6: Check it in rounds

Check every plan in rounds, as [references/checks.md](references/checks.md)
says: round 1 settles the facts from the question and the sources, and each
later round reviews the plan in place, reading only what changed. Only a
blocking finding starts another round. Record each round in the plan's Check
rounds section.

**Done when:** at least two rounds ran and the latest found no blocker, or a
blocker still open after round 3 is a question to the user.

## Step 7: Stop

Present the plan only once it is final: no check is running, the latest
round found no blocker, and nothing has changed since that round read it but
its own smaller points. Until then ask for no approval, in prose or in a
harness's next-step box, and say only that planning continues. A re-check
started after an approval ask withdraws it, and that turn ends with no
approval button. Where the harness has an advisor tool, consult it on the
final plan first. Lead with the result and any departure from the request,
then wait. Repo files other than the plan file stay unedited, and the branch
stays as it is, until the user approves. A yes that names items approves
those items. In Claude Code plan mode, call ExitPlanMode with the
plan. When several decisions are still open, suggest `/eng:grill-me`.

**Done when:** the plan is in front of the user and the turn has ended, or
ExitPlanMode has returned, approval going to `eng:implement` and feedback back
to step 6.

---

The trace and the answer shape are adapted from the `how` skill in
cursor/plugins pstack, by Lauren Tan (MIT). The debugging reference is
adapted from the `diagnosing-bugs` skill in mattpocock/skills (MIT).
