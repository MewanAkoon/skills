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
3. Neither: GitHub in this repo when `gh repo view --json hasIssuesEnabled`
   says issues are on, else ask. Say so, with one line the guidance could add.

Linear with no team named: ask, listing `list_teams`. Under a plan, Delivery
names both.

- GitHub: `SKILL.md` as written.
- Linear with its MCP tools, loaded or deferred: know them by description,
  since a server can be named by an id, and follow [linear.md](linear.md).
- Anything else: call no tools, skip search, labels and filing, and write
  copy-paste text. A comment asked for there is a `comment-<issue>.md` draft.
