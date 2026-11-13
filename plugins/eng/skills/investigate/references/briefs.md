# Briefing subagents for the trace

Read this at investigate's step 3, before starting a subagent for the trace.
Steps 5 and 7, when they start one, brief it from `checks.md`.

Use Explore for searches, and a general-purpose agent for reads that need
`gh`, git, or an MCP tool. Each brief carries:

- The question, in one sentence.
- Pointers: paths, URLs, and commit SHAs, never pasted summaries.
- The return shape: claims, each with `file:line` and whether it was seen or
  inferred.
- The limits: read-only, no subagents, no commits, nothing posted.
