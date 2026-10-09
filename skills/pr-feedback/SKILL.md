---
name: pr-feedback
description: Use when the user shares a link to a PR review comment, or asks to address, triage, or verify review feedback, including a bot's review. Re-reads the PR, every thread, and the current code, judges each comment on evidence, fixes the valid ones, and drafts replies for the user to post.
---

# PR feedback

## What this does

It takes the review on a pull request, judges each comment against the code
as it stands, fixes the ones that hold up, and drafts the replies to a file
for you to post.

## When it runs

When the user shares a PR comment link or a review, or asks to address,
triage, or verify feedback, from a person or a bot. A request to review the
PR itself, rather than its comments, goes to `eng:review-diff`.

## How to use it

Paste the comment link, or the PR link with what you want done. You get a
verdict per comment, then fixes once you approve, then a drafts file and a
"ready to commit".

---

## Step 1: Gather

Read the PR's metadata and full diff, its review bodies, and its issue
comments:

```bash
gh pr view <n> --json number,url,title,body,baseRefName,headRefName,headRefOid,reviews,comments
gh pr diff <n>
```

Read every review thread with its state, because the REST list hides which
ones are resolved:

```bash
gh api graphql -F owner=<owner> -F repo=<repo> -F n=<n> -f query='
query($owner:String!,$repo:String!,$n:Int!){repository(owner:$owner,name:$repo){
pullRequest(number:$n){reviewThreads(first:100){nodes{isResolved isOutdated path line
comments(first:50){nodes{databaseId author{login} body url}}}}}}}'
```

Confirm the checked-out branch is the PR's `headRefName` and contains
`headRefOid` (`git merge-base --is-ancestor <headRefOid> HEAD`), because the
judging and the fixes read the code on disk. Local commits ahead of the PR
are fine, and a comment they answer is "already addressed". When the branch
is another one, stop and ask the user to switch, for example with
`gh pr checkout <n>`. When the link points at one comment,
still read every thread, and lead with that one.

**Done when:** every unresolved thread, review body, and issue comment is
listed with its id, and the checked-out branch is the PR's and contains its
head commit, or the run has stopped and asked the user to switch to it.

## Step 2: Judge each comment

Open the code at the line as it is now, not as the comment saw it. Put each
comment in one class: valid, partly valid, not valid, already addressed, or a
question. Give the evidence: a `file:line`, a test run, or the command output.
Let the evidence decide, whoever wrote the comment. Look at nearby code for
the same problem.

**Done when:** every comment has a class and its evidence.

## Step 3: Present the verdicts

A table: comment (author, `file:line`, the point in a few words), class,
evidence, and the proposed action. Then wait, unless the user's message
already asked you to address or fix them.

**Done when:** the table is presented and the turn has ended, or the user's
message had already approved the fixes.

## Step 4: Fix

Call the Skill tool with `eng:implement` for the approved fixes. It ends by
running `eng:review-diff`.

**Done when:** `eng:review-diff` reports ready, or reports what remains, or
`eng:implement` stopped and named why, or no fix was approved.

## Step 5: Draft the replies

One reply per thread, review body, or issue comment that needs one, in the
shortest natural wording that carries the point. A fixed comment: what changed,
in a sentence. A comment that does not hold: the evidence, in one or two
sentences. Leave out thanks, "good catch", and anything about sessions,
worktrees, or tools.

Write all of them to one file, `pr-<n>-replies.md`, in the scratchpad directory
your system prompt names, or in `${TMPDIR:-/tmp}/drafts` when it names none.
Under each reply, put the command that would post it after the user copies the
text. A reply in a review thread, where `<databaseId>` is the thread's first
comment, because GitHub takes no reply to a reply:

```bash
pbpaste | gh api repos/<owner>/<repo>/pulls/<n>/comments/<databaseId>/replies -F body=@-
```

A reply to a review body or an issue comment, which has no thread:

```bash
pbpaste | gh pr comment <n> --body-file -
```

**Done when:** every thread, review body, and issue comment that needs a reply
has one in the file and the file's path is in the report, or none needs a
reply and the report says so.

## Step 6: Report

The verdict per comment, what was fixed, the checks run, the drafts file's
path, and whether it is ready to commit or to update the PR. The user posts
the replies, and a commit waits for their request.

**Done when:** each of those is in the report.
