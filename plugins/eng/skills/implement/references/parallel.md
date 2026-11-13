# Splitting work across subagents

Read this before giving parts of a change to parallel subagents.

Split only parts that touch disjoint files. When two parts add the same
concept, such as a field, a message key, or an event name, the brief fixes its
exact name for both. A file every part touches, such as a barrel export or a
route table, stays with the main session.

Each part works in this tree on a strict list of files by default. A separate
worktree suits a part only when this tree is clean: put `git rev-parse HEAD`
in the brief, and the part runs `git checkout --detach <sha>` when its own
`HEAD` differs, makes its change uncommitted, and runs `git add -N :/` so new
files show. Apply it from the top of the tree, since a subdirectory `git
apply` skips paths outside it and still exits 0:

```bash
git -C <worktree> diff --binary <sha> | git -C "$(git rev-parse --show-toplevel)" apply
```

A worktree lacks ignored files such as `.env` and `node_modules`, so only the
main session's test run counts.

The brief names the task, pointers rather than summaries, the files it may
change, and the limits: no subagents, no commits, no review, nothing written
outside this machine. Integrate every part, then run steps 3 to 5 on the
whole.

**Done when:** every part is integrated, or a part failed and its output is in
the report.
