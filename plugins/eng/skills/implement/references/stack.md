# Stacks

Read this when a plan's Changes split into layers, at implement's step 1
for a stack, and wherever `eng:commit`, `eng:pr` or `eng:merge-conflicts`
names it. A branch is in a stack when `gh stack view --json` lists it under
`branches[]`; exit 0 alone is not enough, since the trunk also exits 0. The
gh-stack skill holds the commands and their recovery, else
`gh stack <command> --help`. This file says when the run uses them.

## When to stack

Stack when Changes split into two or more dependent layers that each make
sense to review on their own, and always when the branch is already in a
stack. A one-part change stays a single PR.

Before planning one, check that `gh extension list` shows
`github/gh-stack`. When it is missing, the plan's open questions ask the
user to run `gh extension install github/gh-stack`. Only when they decline
does the plan use plain branches, each PR's `--base` the layer below, and
Delivery says so.

The Delivery names one branch per layer, bottom first, each with its PR
title and its tracker line, such as `Fixes SKI-N`. `Base:` is the trunk for
the bottom layer, or the top layer when joining a stack.

**Done when:** the plan names a stack, a single PR, or plain branches the
user chose.

## Build it, one layer at a time

The layers go bottom up. Each one is created before its first edit, then
goes through implement's steps 2 to 5 and `deliver.md`'s steps 4 and 5
before the next is added, so `gh stack add` carries no uncommitted change.
The review loop's `<parent>` for a layer is the tip of the layer below, and
each layer keeps its own `Reviewed:` line.

Create the first layer with `gh stack init <branch>`, adding `--base` when
the trunk is not the default branch, and each next one with
`gh stack add <branch>` run on the top layer. When the top is checked out in
another worktree, make the branch here with `git switch -c <branch> <top>`,
then run `gh stack add <branch>` in the worktree that
`gh stack checkout <top> --print-path` prints. It adopts the branch and
leaves that checkout as it was.

Before joining, the layers below that this run has not committed on pass the
layer check. When one fails, the run does not join: it branches from the
default branch, as `deliver.md`'s Rulings say. A later run on the branch
whose check passes joins with `gh stack add` as above, then puts the layer
on the one below with `gh stack rebase --upstack`.

A later change to a committed layer goes on the layer that owns it. Move
there with `gh stack checkout <layer>`, or its `--print-path` when another
worktree has it, commit through `eng:commit`, run
`gh stack rebase --upstack`, and come back with `gh stack top`.

**Done when:** every layer is committed on its own branch and
`gh stack view --json` lists them in order.

## The layer check

`gh stack push` and `submit` push every layer, and lease each on the ref
they have just fetched, so they overwrite newer remote commits on a layer
that is behind. Branch refs are shared by every worktree of a clone, so they
also publish another session's unpushed commits.

Before the run's first `gh stack rebase`, `push`, `submit` or `sync`, run
`git fetch <remote>`. Then every layer this run has not committed on, and
that `gh stack view --json` does not report `isMerged`, must equal its
remote, which means this exits 0 and prints nothing:

```bash
git rev-list <remote>/<branch>...<branch>
```

A layer ahead, behind, or with no remote branch holds work this run cannot
vouch for: stop with a report.

**Done when:** every such layer equals its remote, or the run has stopped.

## Open the PRs

Run `gh stack submit --auto`. It pushes every layer and opens a draft PR for
each one that lacks one. Never pass `--open`, which also readies PRs that
already exist. Exit 9 means stacked PRs are off on the repo: open each layer
through `eng:pr` as a plain draft with `--base` the layer below, and log it
as a ruling.

`--auto` titles a PR from its commit or branch name. The PRs the submit
opened are those on layers whose `pr` was absent from `gh stack view --json`
before it. For each of those, and only those, draft the title and body
through `eng:pr` from that layer's own diff, with the tracker line as the
last paragraph of What and why, then:

```bash
gh pr edit <number> --title "$(cat <title file>)" --body-file <body file> --add-assignee @me
```

Each layer's diff is `git log <parent>..<layer>` and
`git diff --stat <parent>...<layer>`, named by branch, so a layer need not be
checked out. `<parent>` is the local layer below, which may not be on the
remote before the submit; for the bottom layer it is `<remote>/<trunk>`.

Run `gh stack link --base <trunk> <bottom> ... <top>` only when the layers'
PRs exist but are not one stack on GitHub and this clone does not track
them, such as branches another clone made. `link` writes no local state, so
run `gh stack checkout <url of this worktree's layer's PR>` after it before
any other `gh stack` command; a bare number is read as a stack number
first. `submit` covers every other case.

**Done when:** each layer has an open draft PR with its own title, body,
tracker line and assignee.

## Review and ready

The post-PR review of a layer is `/code-review high <from>..<layer>`, with
`<from>` its `Reviewed:` commit, else `git merge-base <parent> <layer>`, so
it covers that layer's own diff, `<parent>` as above. Each PR is marked
ready on its own, by `deliver.md`'s Ready section.

**Done when:** each layer's PR is ready, or the hand-back says why it is a
draft.

## Restack

When this run changes a lower layer, run `gh stack rebase --upstack` from
that layer, which rebases the layers above it and only fast-forwards those
below from the remote, then `gh stack push` once the stack is pushed, with
no question. When a lower layer merges, run `gh stack sync` with `2>&1`,
since it exits 0 and prints "Sync aborted" when the local and remote stacks
have diverged: stop with a report then. The session that changed a lower
layer restacks it.

Where this run retargeted a base that did not merge, pass
`--accept-base-change` to `gh stack rebase` or `sync`. Where it did not,
stop with a report.

After a restack, a layer's `Reviewed:` moves to its rebased tip when
`git range-diff` pairs every commit with no change, as `eng:pr`'s
`update.md` checks. Otherwise drop that layer's `Reviewed:` line, so its
next review runs from the merge base with its parent. Then update each PR
whose title or body the restack made false, through `update.md`.

A forced update on a stack goes only through `gh stack push`, after the
layer check. On plain branches it goes through `eng:commit`'s explicit
lease.

**Done when:** `gh stack view --json` reports no `needsRebase` and every
layer this run moved is pushed.

## A conflict

`gh stack rebase` exits 3 on a conflict and pauses. Hand it to
`eng:merge-conflicts`, which resolves it in the worktree the output names,
since the caller's `git status` can look clean, and continues with
`gh stack rebase --continue`. A `gh stack sync` that exits 3 has already
restored every branch and paused nothing: run `gh stack rebase` to reach
the conflict. A dirty worktree that owns a layer stops the rebase: stop with
a report.

A paused stack rebase leaves `gh-stack-rebase-state` in
`git rev-parse --path-format=absolute --git-common-dir`, a JSON file in
gh-stack 0.3.0. When the file exists, it concerns this branch only when this
lists the current branch:

```bash
jq -r '.stackBranches[]' "$(git rev-parse --path-format=absolute --git-common-dir)/gh-stack-rebase-state"
```

**Done when:** no stack rebase that lists this branch is paused.
