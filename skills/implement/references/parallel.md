# Splitting work across subagents

Read this before giving parts of an approved change to parallel subagents.

## What can split

Split only parts that touch disjoint files. Two implementers that edit the
same file, or each name the same new thing differently, produce work that
cannot be merged without a second pass.

- When two parts add the same concept, such as a field, a message key, an
  event name, or a helper, the brief fixes its exact name for both.
- A file every part would touch, such as a barrel export, a route table, a
  message catalogue, or a dependency injection registration, stays with the
  main session, which edits it while integrating.

## Where each part runs

By default each part works in this working tree, on a strict list of files it
may change.

A separate worktree (`isolation: worktree` in Claude Code) suits a part only
when this tree is clean, because a new worktree starts from a commit and
carries none of the uncommitted work. Record the starting commit with `git
rev-parse HEAD` and put it in the brief. Before its first edit, the part checks
its own `HEAD` and runs `git checkout --detach <sha>` when it differs, since a
worktree can start from the default branch instead. The part leaves its change
uncommitted, with `git add -N .` so new files show. The main session then
applies it, unstaged, with `git -C <worktree> diff --binary <sha> | git apply`.
`--binary` carries binary files, and `--3way` is only for when the plain apply
fails, because it stages what it applies.

A worktree also lacks ignored files such as `.env`, fixtures, and
`node_modules`, so its tests can skip or pass for the wrong reason. The part
lists any test it skipped, and only the main session's run on the integrated
whole counts.

## The brief

- The task, in a sentence or two.
- Pointers: the plan file and section, and the files to read. Never a pasted
  summary.
- The files it may change, by path, and the exact names fixed above.
- For a worktree, the starting commit.
- What to return: the files changed, every check run with its result, and any
  test skipped.
- The limits: no subagents, no commits, and nothing posted or written outside
  this machine. No `eng:implement` and no review either: the part makes its
  change and stops.

Integrate every part in the main session, then run `eng:implement`'s steps 3
to 5 on the whole, so the review sees the parts together.

**Done when:** every part has come back and is integrated, or a part failed
and its output is in the report.
