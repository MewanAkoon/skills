# Updating a PR through the REST API

Read this when `gh pr edit` exits non-zero in step 7. The usual cause is a
GraphQL deprecation, and the REST endpoint takes the same title and body.

Replace `{number}` with the number from `PR_DATA`, and leave `{owner}` and
`{repo}` exactly as written. `gh api` fills in `{owner}`, `{repo}`, and
`{branch}` from the current repo and no other placeholder, so a literal
`{number}` returns a 404 that looks like a missing PR.

Send the title and body files step 7 wrote. `-f` sends the title as a plain
string, and `-F` with `@` and a path sends the body file's contents as one
too. `gh` converts only a value typed after `-F`, where `true`, `42`, and
`{owner}` become a boolean, a number, and the repo's owner, so a body holding
any of them arrives as written.

```bash
gh api repos/{owner}/{repo}/pulls/{number} --method PATCH \
  -f title="$(cat "<title path>")" -F body=@"<body path>"
```

When this fails too, print what `gh api` said and stop.

**Done when:** the command exited zero, or its output is printed and the run
has stopped.
