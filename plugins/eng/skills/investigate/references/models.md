# Model and effort per task

Read this before starting a subagent, from `eng:investigate` or
`eng:implement`. Pass the model and the effort on each call.

| Task | Model | Effort |
|---|---|---|
| Main session: investigate, plan, implement, deliver | the session's own (Opus) | high |
| Check round 1, facts from scratch | Opus | high |
| Check round 2 onward, what changed | Sonnet | medium |
| Intent check, diff against plan | Sonnet | medium |
| Docs fetch, file search | Haiku | low |

Where a harness cannot set a subagent's model or its effort, the subagent
runs on the session's own.

Where the harness has an advisor tool, consult it twice: once on the final
plan before asking for approval, and once per run before the first PR is
marked ready. When it is overloaded, say so and go on.

Batch edits and commands: a few larger edits rather than one small edit per
call, and independent reads in one call. The session's own context, not its
subagents, is most of what a run costs.
