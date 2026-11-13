# Linear

This replaces `SKILL.md`'s `gh` commands. A subagent drafts and never calls
`save_issue` or `save_comment`. Without `save_issue` or `list_issues`, write
copy-paste text.

- Duplicates: `list_issues` with the team, a `query`, `includeArchived` and a
  `limit` of 250. When `hasNextPage` is true, say only 250 were searched. Read
  a close match with `get_issue` first.
- Fields: from the repo's guidance. Fill a team template from `get_template`,
  but leave `template` off `save_issue`, since it sets fields and sub-issues
  the draft never showed. Labels from `list_issue_labels`, following `cursor`,
  existing and not retired.
- Filing: read the title and body files again first. Pass `id` only to edit,
  and change only what was asked. Part of a body goes in `patch`. `labels`
  replaces the set, so edits use `addLabels` and `removeLabels`.
- Closing: `duplicateOf` for a duplicate, else the `state` the user or
  Delivery names, matched against `list_issue_statuses`. With none named, ask
  which completed or canceled state, or under a plan skip the close and log a
  ruling.
- Read back with `get_issue`, adding `includeRelations` for a blocker or
  duplicate. Several issues follow [github.md](github.md)'s order with
  `parentId` and `blockedBy`.
- An assignee other than the user, or an @mention, only when the user's
  latest message or the guidance names that person.

## A comment

Only on the user's latest message, never from a plan. Call `save_comment` with
the identifier as `issueId` and the `body` alone, then give its URL from
`list_comments`. Otherwise draft it to `comment-<issue>.md` with the call that
would post it. Never edit, delete or reply to a comment, resolve a thread, or
comment on a project, document or status update: draft those.
