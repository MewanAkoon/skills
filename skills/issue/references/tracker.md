# Finding the tracker

Read this at issue's step 1. Only the user or the repo's guidance names the
tracker.

## Who names it

1. The user's message, such as "file it in Jira".
2. The repo's guidance: the files `eng:commit`'s
   [repo-guidance.md](../../commit/references/repo-guidance.md) finds, at the
   root and in the package the issue is about. A line such as
   "work is tracked in Linear, team Skills (key SKI)" names the tracker and
   the team to file in. So does a `bugs` URL in `package.json`, or a contact
   link in `.github/ISSUE_TEMPLATE/config.yml`, that sends issues to another
   issue tracker.

The user's message wins. Read the guidance even then, for the team, project
or repo it names for that same tracker. Guidance that names one tracker and
an exception, such as Dependabot PRs on GitHub, names the first. Guidance
that sends each kind of work to its own tracker names the one for this
issue's kind, and asks when the issue fits none. When two guidance files
name different trackers for the same work, ask.

## When neither names one

Use GitHub, in this repo, when `gh repo view` shows issues on, and say in the
reply that no tracker is named, so the draft is for GitHub. Offer one line
for the repo's guidance that names its tracker, so the next run reads it
there. Adding that line is a change to the repo, so it waits for the user.
When issues are off or `gh` cannot reach the repo, ask.

History, such as issue keys in branch names or commit subjects, matches too
many things that are not trackers to decide this, so it does not.

## The team, project or repo

The user or the guidance names it. For Linear without a team, ask, listing the
teams `list_teams` returns when Linear's tools are in the session. For GitHub
without one, use this repo.

## What each tracker gets

- GitHub: the steps in `SKILL.md` as written.
- Linear, when its MCP tools are in the session, loaded or deferred. A
  connector's server can be named by an id, so tell Linear's tools by their
  descriptions or the server's instructions. Load deferred ones with
  ToolSearch first, then follow [linear.md](linear.md).
- Any other tracker, or Linear with no tools in the session: never call its
  tools. Skip steps 2, 3 and 6, and in step 5 write copy-paste text with no
  command.
