---
name: issue
description: Use when the user's latest message asks to draft, file, edit, label, or close an issue or a ticket, or to turn a plan or deferred review items into issues. Finds the repo's tracker, drafts to files, and writes to it only when asked. Working on an issue you were handed is eng:investigate.
---

# Issue

## What this does

It turns a problem, a plan, or a deferred review item into an issue in the
repo's own tracker, written from its template and labels. The body goes to a
file, and the reply gives the command or call that would file it.

## When it runs

When the user's latest message asks to draft, file, edit, label, or close an
issue or a ticket, or to split a plan or deferred review items into issues.
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

Work out the tracker, its target, and the steps below it takes from
[references/tracker.md](references/tracker.md). For Linear with its tools,
[references/linear.md](references/linear.md) replaces the `gh` commands in
steps 2, 3, 5 and 6. For GitHub, or with no tracker named, pass the repo
named, or nothing:

```bash
gh repo view [<owner/repo>] --json nameWithOwner,hasIssuesEnabled
```

**Done when:** the tracker and its target are named, or the run asked for
one, or it stopped on GitHub issues off or `gh` signed out, or the draft will
be copy-paste text.

## Step 2: Look for a duplicate

Search open and closed issues for the same problem, with key words from the
title and the error text. Keep them to letters, digits, spaces, `_`, and `.`,
so neither the shell nor the search reads one as syntax:

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
system prompt names, or in `${TMPDIR:-/tmp}/drafts` when it names none, and the
title alone to `issue-<slug>.title` beside it. In the reply, give the title,
the labels, both files' paths, and the exact command that would file it,
passing both files. Reading the title from its file keeps a backtick, a `$`,
or an apostrophe in it literal in every shell:

```bash
gh issue create --repo <owner/repo> --title "$(cat "<title path>")" \
  --body-file "<body path>" --label <name>
```

Stop there unless the user's latest message asked to file it.

**Done when:** both files' paths, the title, and the command are in the
reply, or for another tracker the copy-paste text is, or the latest message
asked to file it and the run goes on to step 6.

## Step 6: File, edit, or close, when asked

Run the command from step 5, or the edit or close the user asked for, then
read the issue back, as [references/file.md](references/file.md) shows.

**Done when:** the issue's URL is in the reply and its labels and state match
what was asked, or a mismatch is reported, or the run asked which state to
close it with, or the command failed and its output is reported.

## Report

The draft's two paths, or the issue's URL. The labels as the tracker shows
them. A duplicate found instead, with its link. What the user still has to do,
such as filing in another tracker.

**Done when:** each of those that applies to this run is in the reply.

---

The duplicate check and the label rule follow the `dedupe` and
`triage-issue` commands in anthropics/claude-code. The body shape is adapted
from the `to-tickets` skill in mattpocock/skills (MIT).
