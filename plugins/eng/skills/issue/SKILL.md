---
name: issue
description: Use when the user's latest message asks to draft, file, edit, label, close, or comment on an issue or a ticket, or to turn a plan or deferred review items into issues. Working on an issue you were handed is eng:investigate.
---

# Issue

A comment is drafted to a file and never posted, on any tracker, so
`gh issue close` never gets `--comment`. An issue body or comment carries no
AI credit, as "Never credit an AI" in `eng:commit`'s
[repo-guidance.md](../commit/references/repo-guidance.md) says.

## Step 1: Find the tracker

Follow [references/tracker.md](references/tracker.md). For Linear or Jira
with their tools, [references/linear.md](references/linear.md) or
[references/jira.md](references/jira.md) replaces the `gh` commands below.

**Done when:** the tracker and its target are named, or the run asked.

## Step 2: Look for a duplicate

Search open and closed issues with key words limited to letters, digits,
spaces, `_` and `.`, so neither the shell nor the search reads syntax:

```bash
gh search issues --repo <owner/repo> "<key words>" --json number,title,state,url
```

**Done when:** nothing covers this, or the match's link is reported and the
run has stopped.

## Step 3: Read the template and the labels

Fill the template in `.github/ISSUE_TEMPLATE/` that fits. Use only labels
from `gh label list --repo <owner/repo> --limit 200 --json name`, never a new
one. Set `--type` only when the user or the template names one.

**Done when:** the template and labels are picked, or there are none.

## Step 4: Write the body

The behaviour, not the implementation, except in the recommended approach:
the problem as a user meets it, the expected result, acceptance criteria
someone else can test, scope, blockers, and a link to the source. A new issue
ends with the section in [references/estimate.md](references/estimate.md).
Follow `eng:plain-writing`. Split or link issues only when asked, or when
`estimate.md` sizes the work above the scale, as
[references/github.md](references/github.md) says.

**Done when:** every template section and the estimate section hold content,
and every criterion can be checked by someone else.

## Step 5: Draft

Write the body to `issue-<slug>.md` and the title to `issue-<slug>.title` in
the scratchpad, or a `mktemp -d` directory. Give the title, labels, assignee,
the field values, both paths and the command, which reads the title from its
file so quotes and `$` stay literal. The assignee is the user, `@me`, unless
their message or the guidance names someone else, or nobody:

```bash
gh issue create --repo <owner/repo> --title "$(cat "<title path>")" \
  --body-file "<body path>" --label <name> --assignee @me
```

On GitHub, `github.md` says which fields a Project takes. Stop here unless the
write was asked for, or Delivery names it.

**Done when:** the paths, the assignee, the field values and the command, or
on a copy-paste path the fields file, are in the reply.

## Step 6: File, edit, or close

Run step 5's command, or an edit or close:

```bash
gh issue edit <n> --repo <owner/repo> --add-label <name>
gh issue close <n> --repo <owner/repo> --reason "not planned"
gh issue close <n> --repo <owner/repo> --duplicate-of <m>
```

An edit changes only what was asked, never the assignee or the estimate
fields unasked. Read it back, because GitHub drops labels the account cannot
set, and an assignee can fail:
`gh issue view <n> --repo <owner/repo> --json url,labels,state,assignees`.

When the create fails on the assignee, first check
`gh issue list --repo <owner/repo> --state open --limit 10 --json number,title`
for the title, since the issue may exist with only the assignee failed. When
it is there, keep it and report the missing assignee. With none there, run the
command once without `--assignee` and say so.

**Done when:** the URL is in the reply and its labels, state, assignee and
fields match, or each mismatch or failure is reported.

## Report

The draft's paths or the URL, the labels, assignee and fields the tracker
shows, any duplicate, and what the user still has to do.

---

The duplicate check and the label rule follow the `dedupe` and
`triage-issue` commands in anthropics/claude-code. The body shape is adapted
from the `to-tickets` skill in mattpocock/skills (MIT).
