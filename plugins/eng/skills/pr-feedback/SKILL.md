---
name: pr-feedback
description: Use when the user shares a link to a PR review comment, or asks to address, triage, or verify review feedback, including a bot's review. Judges each comment against the current code on evidence, fixes the valid ones, and drafts replies for the user to post.
---

# PR feedback

Judge each review comment against the code as it stands, fix the ones that
hold up, and draft the replies to a file for the user to post. A request to
review the PR itself, rather than its comments, goes to `/code-review`.

## Step 1: Gather

Read the PR, its diff, its review bodies, and its issue comments:

```bash
gh pr view <n> --json number,url,title,body,baseRefName,headRefName,headRefOid,reviews,comments
gh pr diff <n>
```

Read every review thread with its state, which the REST list hides, with the
query in [references/threads.md](references/threads.md). When the link points
at one comment, still read every thread, and lead with that one.

Judging and fixing read the code on disk, so the checkout must be the PR's
`headRefName` and contain `headRefOid`
(`git merge-base --is-ancestor <headRefOid> HEAD`). Local commits ahead of the
PR are fine, and a comment they answer is "already addressed". On another
branch with a clean tree, run `gh pr checkout <n>` and log it as a ruling.
With uncommitted changes, add a worktree where `eng:implement`'s
[deliver.md](../implement/references/deliver.md) puts one, with
`git worktree add --detach <dir>`, and run `gh pr checkout <n>` inside it.

**Done when:** every unresolved thread, review body, and issue comment is
listed with its id, and the checkout holds the PR's head commit.

## Step 2: Judge each comment

Open the code at the line as it is now. Put each comment in one class:
valid, partly valid, not valid, already addressed, a question, or defer, for a
valid point that belongs in its own change. Give the evidence, a `file:line`,
a run, or command output, which decides whoever wrote the comment. Look at
nearby code for the same problem. A comment too unclear to judge goes to the
user before any fix.

**Done when:** every comment has a class and its evidence.

## Step 3: Present the verdicts

A table: comment (author, `file:line`, the point in a few words), class,
evidence, and the proposed action with its test's level. Then wait, unless
the user's message asked to address or fix them, or a Delivery covers this
PR, an approved plan's or the follow-up one on the user's own PR, and the
message did not ask only to triage or verify, when each valid fix goes
ahead. A fix that would change an approved plan waits.

**Done when:** the table is presented, and the fixes are approved or the turn
has ended.

## Step 4: Fix

Call the Skill tool with `eng:implement` for the approved fixes. Its last step
reviews them.

**Done when:** that review reports ready, or not ready with each blocker, or
no fix was approved.

## Step 5: Draft the replies

One short reply per comment that needs one: what changed, or the evidence
that it does not hold. Leave out thanks and anything about sessions,
worktrees, or tools.

Write them to `pr-<n>-replies.md` in the drafts directory the workflow names,
with the command that posts each under it, as
[references/replies.md](references/replies.md) shows.

**Done when:** each comment that needs a reply has one in the file, or the
report says none needs one.

## Step 6: Report

The verdict per comment, what was fixed, the checks run, the drafts file's
path, and what comes next: the commit, push, body refresh and ready follow
the Delivery that covers the PR, a follow-up on the user's own PR included;
with none, they wait for the user's request. For each deferred
comment, offer an issue draft through `eng:issue`. The user posts the
replies.

**Done when:** each of those is in the report.
