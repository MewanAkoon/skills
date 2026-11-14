# Checking in rounds

Read this at investigate's steps 1 and 6, and before giving an answer or a
report. Nothing is presented until at least two independent passes agree on
it: the session's own and a checker's, round after round.

## Who checks

A plan, a report, or an answer resting on more than one file gets one
general-purpose subagent per round, briefed as below with a scratch directory
made with `mktemp -d` in the scratchpad. A one-line answer gets a fresh read
of the source it rests on in place of a subagent. Pass each subagent the
model and effort below; [models.md](models.md) says what to do where a
harness cannot set them.

## The rounds

1. **Round 1 settles the facts:** what the code does, the root cause, what
   breaks. Run it on Opus at high effort, in the background. On a task,
   launch it at the start of the investigation, beside your own reading. For
   an answer or a report, launch it once the trace shows the work rests on
   more than one file. Brief it with the request and the sources, not with an
   answer, so a wrong premise is caught there. Save the text of any source
   the subagent cannot reach, such as a ticket read through a tracker's MCP
   server, to the scratchpad and pass its path.
2. **Round 2 reviews the plan,** or the answer or report, and improves it in
   place, as code review does a diff. It and every later round run on Sonnet
   at medium effort. The reviewer gets the plan and checks every claim it
   rests on against the code or the ticket.
3. **Each later round reads only what changed** since the last one, and
   re-runs an experiment only when a changed claim rests on it.

Only a blocking finding starts another round: a wrong fact, or a gap that
changes what gets built or would break something. Fix a smaller point in
place, with no new round. When the checker already ran a blocker's fix and
saw it work, such as a command it re-ran with the missing flag, apply the fix
in place and log it, and start no round for it. Fixing a round's own smaller
points is not a change that needs another read, so the work is final once at
least two rounds ran and the latest found no blocker.

A disagreement that turns on the user's preference, or a blocker still open
after round 3, becomes a planning question to the user, one at a time with a
recommendation. Write the answer in before the next round.

## What is presented

The plan's Check rounds section, or a line in an answer or report, says how
many rounds ran, where the passes disagreed, and how each was settled.
Nothing is presented while they disagree.

## Put these in the brief word for word

- Read and run, never write. Use `git log`, `git show`, `git blame`, `gh`
  and `gh api` reads, search, and the repo's checks in their report-only
  modes. Edit no file, commit nothing, post nothing, start no subagents. A
  probe writes only under the scratch directory.
- Report findings only, about 3,000 characters at most. Every finding gives a
  `file:line` or the command run, what is wrong in one sentence, a
  confidence of high, medium, or low, and whether it blocks. Twelve at most,
  the most serious first. "None" is a valid result.
- Name the strongest rival explanation or approach and the evidence that
  rules it out, or list it as an open question.
- Claims: confirm each claim the work rests on with a `file:line` or a run,
  or refute it with one. A claim whose backing line says something narrower
  fails. Watch for a fact true in one place and stale in its twin elsewhere.
- Plan: each change names a file that exists or is marked new, each change in
  behaviour names a test, each doc the change makes false is listed, nothing
  asked for is missing and nothing unasked is added, and names agree from
  item to item. Name a simpler approach when one exists, and a risk the plan
  does not list.

---

The plan checks in the brief are adapted from the `writing-plans` skill in
obra/superpowers (MIT).
