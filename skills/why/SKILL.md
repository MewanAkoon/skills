---
name: why
description: Trace the design rationale behind existing code through git history.
disable-model-invocation: true
---

# Why

## What this does

It works out why a piece of code has the shape it has, from the record:
commits, pull requests, the issues they close, the tests that shipped with
them, and whatever else this repo can reach.

It keeps two things apart in the answer: what a source actually says, and
what you are inferring from a pattern. That separation is the product.

## When to use it

Before deleting a guard, a retry, a timeout, a special case, or a constant
with an oddly specific value. Before rewriting something that looks wrong.
When a reviewer asks why the code is like this and nobody left a comment.

Skip it for code written this week that you already understand. Skip it when
the question is what the code does, which is `/how`.

## How to use it

Type `/why` with a file, a line range, or a symbol name. You get back a short
report with a citation on every claim, and a list of everywhere that was
searched and came back empty.

---

## Step 1: Anchor on the code

Pin down what is being investigated: the file paths, the line ranges, the
symbols. Then get the commits.

```bash
git log -20 --follow --date=short --pretty='%h %ad %an %s' -- <file>
git log -L <start>,<end>:<file>                  # every commit that touched these lines
git blame -w -C -C -L <start>,<end> -- <file>    # ignore reformatting and moved code
git log --follow -p -20 -- <file>
```

`-w -C -C` on the blame matters. Without it, one formatter run or one file
split makes every line blame to whoever moved it.

For the PR behind a commit: a merge commit carries `Merge pull request
#1234`, a squashed commit ends its subject with `(#1234)`, and a repo that
rebases has neither. When the subject has no number, find it with
`gh pr list --search <sha> --state merged`.

**Done when:** there is a list of commits touching the target, with dates and
authors, and a PR number or a recorded "no PR found" for each one.

## Step 2: Read the record

```bash
gh pr view <n> --json title,body,createdAt,mergedAt,closingIssuesReferences,comments,reviews
gh issue view <n> --comments
```

Read the PR body, the review threads, and the linked issue. Read the tests
that landed in the same commit: a test name is often the only written record
of the case that forced the code. Read the comments the commit added, and
check whether a comment nearby was written at the same time or years later.

**Done when:** every commit from step 1 has either a source read or a note
saying its message is the whole record.

## Step 3: Search outside git

List the sources this repo can reach before searching any of them: an issue
tracker, ADRs and specs under `docs/` or `.scratch/`, a Notion or Slack
workspace where a connector is available.

Search each one on the symbol name, the constant's value, the ticket key, and
the week the change shipped.

An empty search carries information. "Searched the tracker for the retry
threshold, nothing" says the number was chosen in a PR rather than in a plan.

**Done when:** the reachable sources are listed, and every source on that
list has a named query and a recorded result, including "nothing".

## Step 4: Sort evidence from inference

- Cite every claim about intent with a commit sha, a PR number, an issue id,
  or a `file:line` for a comment. A claim with no citation belongs under
  inference.
- Hedge indirect evidence. Say "appears to" and "suggests" when the source
  does not say it outright.
- When the evidence fits more than one story, give both, with the evidence
  for each, and let the reader pick.
- Treat a guess the user offers as one hypothesis among the others, and check
  it against the record the same way.
- Trace back past the newest commit. The current shape is usually several
  decisions stacked up, and the last one often only moved the code.
- Take intent from an external source. The code tells you what it does. A
  null check tells you a null arrives, not why.

**Done when:** every claim sits under either the evidence heading with a
citation, or the inference heading with the chain that led to it.

## Step 5: Report

**The question.** One line.

**The code.** Paths, line ranges, symbols.

**What the record says.** One bullet per claim, each with its citation.

**What this suggests.** Inference, hedged, each bullet naming the evidence it
rests on.

**Competing readings.** Only when the evidence fits several stories.

**What is missing.** The questions the record did not answer.

**Where I looked.** One line per source: what was searched, what came back or
"nothing found".

When the investigation came before a change, close with three lines:
**preserve** (behaviour the record shows was deliberate), **safe to change**
(what the record shows nobody decided), **risk** (what breaks if the original
reason still holds).

**Done when:** every bullet under "what the record says" has a citation, and
"where I looked" lists every source from step 3, empty ones included.

---

Adapted from the `why` skill in cursor/plugins pstack, by Lauren Tan (MIT).
The seven-category investigator fan-out is narrowed to git history plus
whatever else the repo can reach.
