# Updating a PR through the REST API

Read this when `gh pr edit` exits non-zero in step 7. The usual cause is a
GraphQL deprecation, and the REST endpoint takes the same title and body.

Replace `{number}` with the number from `PR_DATA`, and leave `{owner}` and
`{repo}` exactly as written. `gh api` fills in `{owner}`, `{repo}`, and
`{branch}` from the current repo and no other placeholder, so a literal
`{number}` returns a 404 that looks like a missing PR.

Pass the title and body with `-f`, which sends each value as a plain string.
`-F` would turn a body reading `true` or `42` into a JSON boolean or number,
and would read a value starting with `@` as a filename:

```bash
gh api repos/{owner}/{repo}/pulls/{number} --method PATCH \
  -f title="$(cat <<'EOF'
<title>
EOF
)" \
  -f body="$(cat <<'EOF'
<body>
EOF
)"
```

When this fails too, print what `gh api` said and stop.

**Done when:** the command exited zero, or its output is printed and the run
has stopped.
