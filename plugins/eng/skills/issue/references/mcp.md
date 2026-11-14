# A tracker through its MCP tools

This replaces `SKILL.md`'s `gh` commands for every tracker but GitHub, with
the tools [tracker.md](tracker.md) found. Know each tool by what its
description says it does, whatever it is named. A subagent drafts and never
writes. Where a tool takes a site, workspace or cloud id, read it first from
the tool that lists what the account can reach.

- Duplicates: the search or list tool on the team or project, with step 2's
  key words, open and closed, archived included where it can. Take the
  largest page it allows, and when it reports more pages, say how many were
  searched. Read a close match in full first.
- Fields and labels: before filling anything, read what the item type
  takes, from the tool that returns its fields, create metadata or schema,
  for priority, points or estimate, due date, and any field the guidance
  names. Use only labels, tags or components that exist, read through every
  page, leaving out retired or archived ones. A team template fills the
  body, and is never passed as a parameter, since that sets fields or
  sub-items the draft never showed.
- Values from [estimate.md](estimate.md): priority in the tracker's own
  names or numbers, Urgent as its highest; the points in its estimate or
  story points field; the due date in its due date field.
- Assignee: the signed-in user, from the tool that returns them or the
  tracker's own word for "me", unless the user's latest message or the
  guidance names someone else, or nobody. An @mention only when they name
  one. When the save fails on the assignee, save once without it and report
  that.
- Filing: read the title and body files again first. Create, then read the
  item back and check its assignee, priority, points, due date and labels.
  An edit passes the item's id and changes only what was asked, putting part
  of a body in a patch where the tool takes one.
- Closing: the tracker's duplicate link for a duplicate, else the state or
  transition the user or Delivery names, matched against the tracker's own
  list. With none named, ask which, or under a plan skip the close and log a
  ruling.
- Several issues follow [github.md](github.md)'s order, each child linked to
  its parent and its blockers through the tracker's own fields.
- A comment, an edit of one, a reply, or one on anything but an issue is
  drafted to `comment-<issue>.md` with the call that would post it, the
  item's id and the body, for the user to run.

## Quirks that break a write

- Linear: `labels` on `save_issue` replaces the whole set, so an edit uses
  `addLabels` and `removeLabels`.
- Jira: a label the project does not have is created silently, so pass only
  labels it already uses. Story points sit in a custom field, named "Story
  Points" or "Story point estimate" in the create metadata.
