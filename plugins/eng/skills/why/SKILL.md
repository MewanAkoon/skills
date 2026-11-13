---
name: why
description: Use before removing or rewriting a guard, retry, timeout, special case, odd constant, or redundant-looking code that the user's request did not name, and when asked why code is shaped the way it is. Traces the reason through git history and PRs.
---

# Why

Code the user named for removal needs none of this, because their request is
the reason. For anything else, the answer comes from the record, and the report
keeps what a source says apart from what you infer.

## Step 1: Find the commits

```bash
git log -L <start>,<end>:<file>
git blame -w -C -C -L <start>,<end> -- <file>
```

Without `-w -C -C`, one formatter run or one file split blames every line on
whoever moved it. Trace past the newest commit. The current shape is often
several decisions stacked, and the last one only moved the code.

For each commit, find its PR: a squashed subject ends in `(#1234)`, a merge
commit says `Merge pull request #1234`, and otherwise
`gh pr list --search <sha> --state merged`.

**Done when:** each commit touching the lines has a PR number or "no PR
found".

## Step 2: Read the record

```bash
gh pr view <n> --json title,body,closingIssuesReferences,comments,reviews
gh api --paginate repos/{owner}/{repo}/pulls/<n>/comments
```

`gh pr view` leaves out comments on lines of the diff, which is where a guard
usually got argued over. The `gh api` call returns them. Read the linked
issue, and the tests that landed in the same commit. A test name is often the
only record of the case that forced the code.

When the commit that added the code, or its PR, states the reason, report it
with its citation and stop.

**Done when:** every commit has its PR, issue and tests read, or its message
is the whole record, or the run has stopped on a stated reason.

## Step 3: Search outside git

List what this repo can reach, such as the tracker, ADRs, `docs/`, and
connectors for Slack, Notion, error tracking or metrics. Search each for the
symbol, the constant's value, and the week the change shipped. A monitor
threshold equal to the constant, or an error first seen the week before the
commit, is often the whole answer. Record empty searches too.

**Done when:** every reachable source has a query and a result, "nothing"
included.

## Step 4: Report

- **The code.** Paths, line ranges, symbols.
- **What the record says.** One bullet per claim, each citing a sha, a PR, an
  issue, or a `file:line`. A claim with no citation moves to the next list.
- **What this suggests.** Inference, hedged with "appears to", each bullet
  naming the evidence it rests on. When the evidence fits two stories, give
  both. A guess the user offered is one of these until the record backs it.
- **What is missing.** Questions the record did not answer.
- **Where I looked.** One line per source and what came back.

Before a change, end with three lines: **preserve** (what the record shows
was deliberate), **safe to change** (what nobody decided), **risk** (what
breaks if the original reason still holds).

**Done when:** every claim under "what the record says" has a citation, and
"where I looked" lists every source from step 3.

---

Adapted from the `why` skill in cursor/plugins pstack, by Lauren Tan (MIT).
