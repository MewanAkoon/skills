---
name: pr-feedback
description: Use when the user shares a link to a PR review comment, or asks to address, triage, or verify review feedback, including a bot's review. Re-reads the PR, every thread, and the current code, judges each comment on evidence, fixes the valid ones, and drafts replies for the user to post.
---

# PR feedback

## What this does

It judges each review comment on a pull request against the code as it
stands, fixes the ones that hold up, and drafts replies to a file for you to
post.

## When it runs

When the user shares a PR comment link or a review, or asks to address,
triage, or verify feedback, from a person or a bot. A request to review the
PR itself, rather than its comments, goes to `/code-review`.

## How to use it

Paste the comment link, or the PR link with what you want done. You get a
verdict per comment, fixes once you approve, then a drafts file and a "ready
to commit".

---

## Step 1: Gather

Read the PR, its diff, its review bodies, and its issue comments:

```bash
gh pr view <n> --json number,url,title,body,baseRefName,headRefName,headRefOid,reviews,comments
gh pr diff <n>
```

Read every review thread with its state, which the REST list hides.
`--paginate` reads past 100 threads:

```bash
gh api graphql --paginate -f owner=<owner> -f repo=<repo> -F n=<n> -f query='
query($owner:String!,$repo:String!,$n:Int!,$endCursor:String){repository(owner:$owner,name:$repo){
pullRequest(number:$n){reviewThreads(first:100,after:$endCursor){pageInfo{hasNextPage endCursor}
nodes{isResolved isOutdated path line
comments(first:100){totalCount nodes{databaseId author{login} body url}}}}}}}'
```

A `totalCount` over 100 means only that thread's first 100 comments came
back: say so in the report.

Confirm the checked-out branch is the PR's `headRefName` and contains
`headRefOid` (`git merge-base --is-ancestor <headRefOid> HEAD`), because
judging and fixing read the code on disk. Local commits ahead of the PR are
fine, and a comment they answer is "already addressed". On another branch,
stop and ask the user to switch, such as with `gh pr checkout <n>`. When the
link points at one comment, still read every thread, and lead with that one.

**Done when:** every unresolved thread, review body, and issue comment is
listed with its id, and the checkout is the PR's branch with its head commit,
or the run has stopped and asked the user to switch.

## Step 2: Judge each comment

Open the code at the line as it is now, not as the comment saw it. Put each
comment in one class: valid, partly valid, not valid, already addressed, a
question, or defer, for a valid point that belongs in its own change. Give the
evidence: a `file:line`, a test run, or command output. Let the evidence
decide, whoever wrote the comment. Look at nearby code for the same problem.

**Done when:** every comment has a class and its evidence, or one comment is
too unclear to judge and the run asks the user about it before fixing any.

## Step 3: Present the verdicts

A table: comment (author, `file:line`, the point in a few words), class,
evidence, and the proposed action with its test's level. Then wait, unless
the user's message already asked you to address or fix them.

**Done when:** the table is presented and the turn has ended, or the user had
already approved the fixes.

## Step 4: Fix

Call the Skill tool with `eng:implement` for the approved fixes. Its last step
reviews them.

**Done when:** that review reports ready, or not ready with each blocker, or
`eng:implement` stopped and named why, or no fix was approved.

## Step 5: Draft the replies

One reply per thread, review body, or issue comment that needs one, as short
as the point allows. A fixed comment: what changed, in a sentence. A comment
that does not hold: the evidence, in one or two sentences. Leave out thanks,
"good catch", and anything about sessions, worktrees, or tools.

Write them all to `pr-<n>-replies.md` in the scratchpad directory your system
prompt names, or in `${TMPDIR:-/tmp}/drafts` when it names none. Under each
reply, put the command that posts it once the user copies the text: `pbpaste`
on macOS, `wl-paste` or `xclip -o` elsewhere. A reply in a review thread,
where `<databaseId>` is the thread's first comment:

```bash
pbpaste | gh api repos/<owner>/<repo>/pulls/<n>/comments/<databaseId>/replies -F body=@-
```

A reply to a review body or an issue comment, which has no thread:

```bash
pbpaste | gh pr comment <n> --body-file -
```

**Done when:** each one that needs a reply has one in the file, whose path is
in the report, or the report says none needs one.

## Step 6: Report

The verdict per comment, what was fixed, the checks run, the drafts file's
path, and whether it is ready to commit or to update the PR. For each
deferred comment, offer an issue draft through `eng:issue`, or ticket text for
another tracker. The user posts the replies, and a commit or an issue
waits for their request.

**Done when:** each of those is in the report.
