# Jira

This replaces `SKILL.md`'s `gh` commands when Atlassian's MCP tools are in
the session, loaded or deferred. Know them by what they do, since a server can
be named by an id. A subagent drafts and never creates. Without the tools,
follow [tracker.md](tracker.md)'s copy-paste path.

- Site: where the tools take a cloud or site id, read it first from the tool
  that lists accessible resources.
- Duplicates: a JQL search on the project with the key words, open and
  resolved. Read a close match in full first.
- Fields: the project and issue type from the repo's guidance. Read the issue
  type's create metadata for the story points field, named "Story Points" or
  "Story point estimate", and for the priorities. Labels only ones the
  project already uses, else none, since Jira creates a new label silently.
- Values from [estimate.md](estimate.md): priority by name, Urgent as
  Highest, then High, Medium and Low as the project's list names them; the
  points in the story points field; the due date as `duedate`.
- Assignee: the account id from the tool that returns the signed-in user,
  unless the user's latest message or the guidance names someone else, or
  nobody. When the assignee fails, create without it and report that.
- Filing: read the title and body files again first. Create, then read the
  issue back and check its assignee, priority, points and due date. An edit
  changes only what was asked.
- Closing: the transition the user or Delivery names, matched against the
  issue's transitions. With none named, ask which, or under a plan skip the
  close and log a ruling.
- Several issues follow [github.md](github.md)'s order, each child linked to
  its parent.
- A comment is drafted to `comment-<issue>.md` with the call that would post
  it, for the user to run.
