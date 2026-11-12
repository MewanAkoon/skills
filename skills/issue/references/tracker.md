# Finding the tracker

Read this at issue's step 1. No standard file names a repo's tracker, so a
tracker the repo names outright beats any guess from its history.

## Where to look, in order

The first of these sources that names a tracker decides. Guidance that names
one tracker for its work and an exception, such as Dependabot PRs on GitHub,
names the first. Guidance that sends each kind of work to its own tracker,
such as bugs to GitHub and features to Linear, names the one for this issue's
kind. When the issue fits no kind it names, ask.

1. The user's message names one, such as "file it in Jira".
2. The repo's guidance names one: the files `eng:commit`'s
   [repo-guidance.md](../../commit/references/repo-guidance.md) finds, read
   for the tracker rather than for commits. A line such as
   "work is tracked in Linear, team Skills (key SKI)" names the tracker and
   the team or project to file in.
3. Standard metadata: the `bugs` URL in `package.json`, and the
   `contact_links` in `.github/ISSUE_TEMPLATE/config.yml`, which a repo uses
   to send people to another tracker. Either counts only when it points away
   from this repo's GitHub issues, where npm points `bugs` by default.
4. The repo's history. Read recent branch names, commit subjects, and PR
   bodies, leaving out the PR list when `gh` cannot reach the repo:

   ```bash
   git branch -a --sort=-committerdate | head -20
   git log -30 --format=%s%n%b
   gh pr list --state all --limit 20 --json headRefName,body
   ```

   An issue key is letters other than `GH` or `gh`, a hyphen and a number,
   such as `SKI-21` or `ski-21`. It counts when the same prefix shows up with
   two or more numbers in linking lines, commit subjects, or branch names
   other than a bot's, such as `dependabot/`, so a lone `UTF-8` does not. A
   key points at Linear or Jira, and a link to `linear.app` or
   `atlassian.net` tells which. With no such link, ask. `Fixes #123`,
   `Fixes GH-123` or a `github.com` issue link points at GitHub, but the
   `(#123)` a squash merge adds to a subject is a PR number and points
   nowhere.
5. GitHub, when `gh repo view` shows issues on.

## When it guessed

When the tracker came from source 3 or 4, say so in the reply, name the
evidence, and offer one line for the repo's guidance that names the tracker
and its team or project, so the next run reads it instead. Adding that line
is a change to the repo, so it waits for the user.

When one source points at two trackers for the same work, ask which one
before drafting. When nothing names one, ask.

## What each tracker gets

- GitHub: the steps in `SKILL.md` as written.
- Linear, when its MCP tools are in the session, loaded or deferred. A
  connector's server can be named by an id, so tell Linear's tools by their
  descriptions or the server's instructions. Load deferred ones with
  ToolSearch first, then follow [linear.md](linear.md).
- Any other tracker, or Linear with no tools in the session: never call its
  tools.
  Skip steps 2, 3 and 6, and in step 5 write copy-paste text with no command.
