---
name: issue
description: Use when the user's latest message asks to draft, file, edit, label, or close a GitHub issue or a ticket, or to turn a plan or deferred review items into issues. Writes the draft to files and changes GitHub only when asked. Working on an issue you were handed is eng:investigate.
---

# Issue

## What this does

It turns a problem, a plan, or a deferred review item into an issue written from
the repo's own template and labels. The body goes to a file, and the reply gives
the command that would file it. Nothing on GitHub changes until the user's
latest message asks for it.

## When it runs

When the user's latest message asks to draft, file, edit, label, or close an
issue or a ticket, or to split a plan or deferred review items into issues.
Reading issues to answer a question needs no request and is not this skill.
Working on an issue the user handed you, such as "look into issue 42", goes
to `eng:investigate`.

An earlier go-ahead does not carry forward: each create, edit, label change,
or close needs the latest message to ask for it. This skill never comments on
an issue, and never passes `--comment` to `gh issue close`.

## How to use it

Say what the issue is about, or point at the plan or the review items. You get
the draft's title and body files and the command that would file it. Say "file
it" to create it.

---

## Step 1: Find the target

```bash
gh repo view [<owner/repo>] --json nameWithOwner,hasIssuesEnabled
```

Pass the repo the user names, or nothing for this one. For Fibery, Jira,
Linear, or any tracker other than GitHub, never call its tools: skip steps 2,
3, and 6, and in step 5 write copy-paste text with no command. The user files
it.

**Done when:** the target is named, or the run has stopped because issues are
off for the repo or `gh` is not signed in, or the target is another tracker
and the draft will be text only.

## Step 2: Look for a duplicate

Search open and closed issues for the same problem, with key words from the
title and the error text. Keep them to letters, digits, spaces, `_`, and `.`,
because the shell expands a `$` or a backtick inside double quotes, and the
search reads a `:` or a leading `-` as syntax:

```bash
gh search issues --repo <owner/repo> "<key words>" --json number,title,state,url
```

A match goes back to the user with its link instead of a new draft.

**Done when:** the search ran and either found nothing that covers this, or
the match is reported and the run has stopped.

## Step 3: Read the template and the labels

Read `.github/ISSUE_TEMPLATE/` when the repo has one, pick the template that
fits, and fill its sections. List the labels that exist:

```bash
gh label list --repo <owner/repo> --limit 200 --json name,description
```

Use only labels that exist, and never create one. Set `--type` only when the
user or the template names an issue type.

**Done when:** the template is chosen or the repo has none, and the labels are
picked from the list or left out.

## Step 4: Write the body

Write the behaviour, not the implementation: the problem as a user meets it,
the expected result, acceptance criteria someone can test, what is in and out
of scope, and what blocks it. Link the source: the PR comment, the plan, the
error. Follow `eng:plain-writing`.

Split into several issues only when the user asked for that. Propose the
breakdown first, as vertical slices that each deliver something testable, and
wait for approval. [references/github.md](references/github.md) covers
sub-issues, blockers, and the order to file them in.

**Done when:** every section the template asks for holds content, and every
acceptance criterion can be checked by someone who did not write it, or a
breakdown is proposed and the run is waiting for the user's approval.

## Step 5: Draft, then stop

Write the body alone to `issue-<slug>.md` in the scratchpad directory your
system prompt names, or in `${TMPDIR:-/tmp}/drafts` when it names none, so the
file can be passed to `gh` as it stands, and the title alone to
`issue-<slug>.title` beside it. In the reply, give the title, the labels, both
files' paths, and the exact command that would file it. Always pass a title
and a body file, so `gh` never prompts. Reading the title from its file keeps
a backtick, a `$`, or an apostrophe in it literal in every shell. Typed into
the command, a title in double quotes is expanded, and one in single quotes
breaks on an apostrophe:

```bash
gh issue create --repo <owner/repo> --title "$(cat "<title path>")" \
  --body-file "<body path>" --label <name>
```

Stop there unless the user's latest message asked to file it.

**Done when:** both files' paths, the title, and the command are in the
reply, or for another tracker the copy-paste text is, or the latest message
asked to file it and the run goes on to step 6.

## Step 6: File, edit, or close, when asked

Run the command from step 5, or the edit or close the user asked for:

```bash
gh issue edit <n> --repo <owner/repo> --add-label <name>
gh issue close <n> --repo <owner/repo> --reason "not planned"
gh issue close <n> --repo <owner/repo> --duplicate-of <m>
```

Then read the issue back. GitHub drops labels silently when the account lacks
the access to set them:

```bash
gh issue view <n> --repo <owner/repo> --json number,url,title,labels,state
```

**Done when:** the issue's URL is in the reply and its labels and state match
what was asked, or a mismatch is reported, or the command failed and its
output is reported.

## Report

The draft's two paths, or the issue's URL. The labels as GitHub shows them. A
duplicate found instead, with its link. What the user still has to do, such
as filing in another tracker.

---

The duplicate check and the label rule follow the `dedupe` and
`triage-issue` commands in anthropics/claude-code. The body shape is adapted
from the `to-tickets` skill in mattpocock/skills (MIT).
