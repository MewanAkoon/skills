# Updating an open PR

When `git merge-base --is-ancestor <headRefOid> HEAD` fails, the PR holds
commits this branch lacks, or the branch was rebased: say so and stop. When
`git rev-list --count <headRefOid>..HEAD` is above zero, push those commits
with `git push <remote> HEAD:<headRefName>` if the request or Delivery asks
for the push, else ask first. Never `--force`.

Show the current and proposed title and summary. Send without asking again
when the user's latest message asked for this update, or Delivery lists it;
otherwise ask.

```bash
gh pr edit <number> --title "$(cat <title file>)" --body-file <body file>
```

When that fails, use REST with the number written in, since `gh api` fills
only `{owner}`, `{repo}`, and `{branch}`, and a literal `{number}` gives a 404:

```bash
gh api repos/{owner}/{repo}/pulls/<number> --method PATCH \
  -f title="$(cat <title file>)" -F body=@<body file>
```
