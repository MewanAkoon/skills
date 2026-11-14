# Finding the tracker

Only the user or the repo's guidance names it, never history such as issue
keys in branch names.

1. The user's message, such as "file it in Jira", wins.
2. The guidance `eng:commit`'s
   [repo-guidance.md](../../commit/references/repo-guidance.md) finds, at the
   root and in the issue's package: a line such as "tracked in Linear, team
   Skills (key SKI)", a `bugs` URL in `package.json`, or a contact link in
   `.github/ISSUE_TEMPLATE/config.yml`. Read it even after the user names one,
   for the team. A tracker plus an exception names the first. When files
   disagree, or the issue fits none of the kinds they route, ask.
3. Neither: ask which tracker, with what was found: whether
   `gh repo view --json hasIssuesEnabled` says GitHub issues are on, and
   which trackers' MCP servers the session has. Recommend GitHub when its
   issues are on, and give one line the guidance could add.

The team, project or space comes from the guidance. With none named, ask,
listing what the tracker's tools return. Under a plan, Delivery names the
tracker and its target.

## Its tools

- GitHub: `SKILL.md` as written, with [github.md](github.md)'s fields.
- Any other tracker: find its MCP tools, loaded or deferred, by what they
  do, since a server can be named by an id. A tool counts when its
  description says it acts on that tracker's own items, not when it only
  mentions the tracker, as Sentry's `link_issue` mentions Jira. Where the
  harness lists deferred tools by name alone, search them by the tracker's
  name and what the step needs, such as "linear issue" with Claude Code's
  ToolSearch. Then read one thing the guidance names, such as the team, the
  project or a known key, to confirm the server is that tracker's, and
  follow [mcp.md](mcp.md).
- No tools for it in the session, or the confirming read fails: stop before
  step 2, call no tracker tools, and file nothing. Say which tracker's MCP
  server to connect and ask again after, showing it through a tool that
  suggests connectors where the session has one, and say a copy-paste draft
  is there if it cannot be connected. A comment needs no tools and is
  drafted as [mcp.md](mcp.md) says.

Only when the user says the server cannot be connected: skip search, labels
and filing. Step 5's draft is the copy-paste text, with a third file,
`issue-<slug>.fields`, with one `Name: value` line each for the tracker and
project, the assignee step 5 names, priority, effort, story points, due
date, and labels.

Under a plan, planning settles this, and Delivery names a tracker whose tools
the session has. When they are gone at run time, log a ruling, draft the
issue, file nothing, and report the server to connect.
