# Updating an open PR

Read this when the branch already has an open PR: the first section in step
2, the rest in step 7.

## In step 2

The check against `headRefOid` works whether or not the branch tracks
anything.

When `git merge-base --is-ancestor <headRefOid> HEAD` fails, the PR's head
is not in this branch: someone pushed commits this clone lacks, or the
branch was rebased since its last push. Say so and stop, because the first
needs a pull and the second a force push, and the user decides either.

When `git rev-list --count <headRefOid>..HEAD` prints more than zero, those
commits are not on the PR yet, so ask "<count> local commits are not on the PR
yet. Push them first? (yes / no)". Yes means
`git push <head remote> HEAD:<headRefName>` before step 7, never with
`--force`. `<head remote>` is the remote for the repository the PR's head lives
in, whether that is this one or a fork: the one matching
`headRepository.nameWithOwner` by [remote.md](remote.md)'s rule. When no
remote matches, or more than one, say which repository the push needs and
stop. A failed push prints its output and stops. `SKILL.md` step 2 says what
no means.

## In step 7

Show the user what changes before touching anything:

```
Existing PR: <url>

Current title:  <existing title>
Proposed title: <new title>

Current summary:  <first line of existing body, or "(none)">
Proposed summary: <new summary>
```

When the user's latest message asked for this update, send it with no second
prompt. Otherwise ask "Apply these updates to the PR? (yes / no)" and stop on
no.

To send it, write the title and body files as step 6 of `SKILL.md` says, then:

```bash
gh pr edit --title "$(cat "<title path>")" --body-file "<body path>"
```

When `gh pr edit` exits non-zero, read [rest-fallback.md](rest-fallback.md)
and send the same title and body through the REST API.
