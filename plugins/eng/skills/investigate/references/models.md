# Model and effort per task

Read this before starting a subagent, from `eng:investigate` or
`eng:implement`. Pass the model and the effort on each call.

| Task | Model | Effort |
|---|---|---|
| Main session: investigate, plan, implement, deliver | the session's own (Opus) | high |
| Check round 1, facts from scratch | Opus | high |
| Check round 2 onward, what changed | Sonnet | medium |
| Intent check, diff against plan | Sonnet | medium |
| Review of a fix diff, `code-review medium` | Sonnet | medium |
| Security review, the built-in `security-review` | Sonnet | medium |
| Docs fetch, file search | Haiku | low |

Where a harness cannot set a subagent's model or its effort, the subagent
runs on the session's own.

Where the harness has an advisor tool, the main session calls it at most
twice: once after the last check round on a plan reports, before asking for
approval, and once before the run's first `gh pr ready`. A run with no plan
or no PR skips that call. No subagent calls it, and every brief says so,
since each call resends the whole conversation. A point it raises after the
last round is applied in place, like a round's smaller points, and logged
with the rulings; it starts no round. When it is overloaded, say so and go
on.

Batch edits and commands: a few larger edits rather than one small edit per
call, and independent reads in one call. The session's own context, not its
subagents, is most of what a run costs.
