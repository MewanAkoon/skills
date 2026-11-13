# Linear

This replaces `SKILL.md`'s `gh` commands. A subagent drafts and never calls
`save_issue`. Without `save_issue` or `list_issues`, follow
[tracker.md](tracker.md)'s copy-paste path.

- Duplicates: `list_issues` with the team, a `query`, `includeArchived` and a
  `limit` of 250. When `hasNextPage` is true, say only 250 were searched. Read
  a close match with `get_issue` first.
- Fields: from the repo's guidance. Fill a team template from `get_template`,
  but leave `template` off `save_issue`, since it sets fields and sub-issues
  the draft never showed. Labels from `list_issue_labels`, following `cursor`,
  existing and not retired.
- Filing: read the title and body files again first. A new issue sets
  `assignee: "me"`, `priority` (1 Urgent, 2 High, 3 Medium, 4 Low),
  `estimate` and `dueDate` from [estimate.md](estimate.md). An assignee
  other than the user, nobody, or an @mention only when the user's latest
  message or the guidance names it. When the save fails on the assignee,
  save once without it and report that. Pass `id` only to edit,
  and change only what was asked. Part of a body goes in `patch`. `labels`
  replaces the set, so edits use `addLabels` and `removeLabels`.
- Closing: `duplicateOf` for a duplicate, else the `state` the user or
  Delivery names, matched against `list_issue_statuses`. With none named, ask
  which completed or canceled state, or under a plan skip the close and log a
  ruling.
- Read back with `get_issue`, checking the assignee, priority, estimate and
  due date, and adding `includeRelations` for a blocker or duplicate.
  Several issues follow [github.md](github.md)'s order with `parentId` and
  `blockedBy`.

## A comment

Draft it to `comment-<issue>.md` with the `save_comment` call that would post
it, the identifier as `issueId` and the `body` alone, for the user to run.
An edit, a reply, a thread to resolve, or a comment on a project, document
or status update is drafted the same way.
