# Updating an open PR

Read this in step 7, when the branch already has an open PR.

Show the user what changes before touching anything:

```
Existing PR: <url>

Current title:  <existing title>
Proposed title: <new title>

Current summary:  <first line of existing body, or "(none)">
Proposed summary: <new summary>
```

Ask "Apply these updates to the PR? (yes / no)" and stop on no.

On yes, write the title and body files as step 6 of `SKILL.md` says, then:

```bash
gh pr edit --title "$(cat "<title path>")" --body-file "<body path>"
```

When `gh pr edit` exits non-zero, read [rest-fallback.md](rest-fallback.md)
and send the same title and body through the REST API.
