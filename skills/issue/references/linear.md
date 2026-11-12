# Linear

Read this when step 1 found Linear and Linear's MCP tools are in the session.
It replaces the `gh` commands in steps 2, 3, 5 and 6. Everything else in
`SKILL.md` holds: the duplicate check, the draft in files, and filing only
when the user's latest message asks. A subagent drafts and never calls
`save_issue`, since a brief is not the user's ask. When the Linear server has
no `save_issue` or `list_issues`, write copy-paste text instead.

## Step 2: Look for a duplicate

Search the team named in step 1 with `list_issues`, passing the team and a
`query` of key words from the title and the error text. Search open, closed
and archived issues, with `includeArchived`, a `limit` of 250, and `fields` of
id, title, status and url. When `hasNextPage` comes back true, say the search
covered only the first 250. Read the description of any close match with
`get_issue` before calling it a duplicate. A match goes back to the user with
its identifier and URL instead of a new draft.

## Step 3: Read the format and the labels

Read the repo's guidance for the issue format it asks for, such as Problem,
Acceptance criteria, Links and Constraints, and for the fields it sets: a
label, a priority, a project, an assignee, a parent, blockers. When the team
has issue templates, list them with `list_templates`, passing the team and
`type` issue, read the one that fits with `get_template`, and fill its
sections in the body. Leave `template` off `save_issue`, because it sets
fields and sub-issues the draft never showed. Instead, put the fields the
template sets into the draft, by name, leaving out any person. Treat them as
fields the guidance names. Also name any sub-issues the template would have
made, so the user can ask for them. List the team's labels with
`list_issue_labels`, following `cursor` while `hasNextPage` is true, and use
only labels that exist and are not retired. Set a field only when the guidance
or the user names it.

## Step 5: Draft, then stop

Write the body and the title to the two files as `SKILL.md` says. In the
reply give the title, the fields to set, both paths, and the `save_issue` call
that would file it: the team, the title, the body file's contents as the
`description`, and each field. Stop there unless the user's latest message
asked to file it.

## Step 6: File, edit, or close, when asked

Call `save_issue` with the fields from step 5. To create one, read the title
and the body from their files again, since the user may have edited them. Pass
`id` only to edit an issue, and change only the fields asked for. A change to
part of the body goes in `patch`, not a new `description`. `labels` replaces
the whole set, so an edit adds and removes labels with `addLabels` and
`removeLabels`. To close one as a duplicate, set `duplicateOf`. To close one
otherwise, set the `state` the user names, matched to one of the team's from
`list_issue_statuses`, and when the user names none, ask which of the team's
completed or canceled states to use. Then read it back with `get_issue`,
adding `includeRelations` when a blocker or a duplicate was set, and check
each field against what was asked. `list_issues` with a `parentId` lists the
issues filed under that parent.

For several issues, draft and file in the order [github.md](github.md) sets
out. Pass `parentId` and `blockedBy` to `save_issue` in place of its `gh`
commands and its "Blocked by" line, read each issue back as above, and list
every URL in the order filed.

An assignee other than the user, or an @mention in the body, reaches another
person, so add one only when the user's latest message or the repo's guidance
names that person.
