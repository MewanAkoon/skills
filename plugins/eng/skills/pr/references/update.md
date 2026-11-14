# Updating an open PR

When `git merge-base --is-ancestor <headRefOid> HEAD` fails, the PR holds
commits this branch lacks, or the branch was rebased. A rebase this run made
is accepted when this pairs every commit and changes no added or removed
line:

```bash
git range-diff "$(git merge-base <headRefOid> <base remote>/<base>)"..<headRefOid> <base remote>/<base>..HEAD
```

Its push is a lease push, which follows `eng:commit`'s Push section, and the
title and body wait until it lands. Anything else: say so and stop.

When `git rev-list --count <headRefOid>..HEAD` is above zero, push those
commits with `git push <remote> HEAD:<headRefName>`, or on a stack with
`gh stack push` after the layer check in `eng:implement`'s
[stack.md](../../implement/references/stack.md), if the request asks or a
Delivery covers the PR, as `eng:implement`'s
[deliver.md](../../implement/references/deliver.md) says, else ask first.
Never `--force`.

Show the current and proposed title and summary. Send without asking again
when the user's latest message asked for this update or a Delivery covers
the PR; otherwise ask.

```bash
gh pr edit <number> --title "$(cat <title file>)" --body-file <body file>
```

When that fails, use REST with the number written in, since `gh api` fills
only `{owner}`, `{repo}`, and `{branch}`, and a literal `{number}` gives a 404:

```bash
gh api repos/{owner}/{repo}/pulls/<number> --method PATCH \
  -f title="$(cat <title file>)" -F body=@<body file>
```
