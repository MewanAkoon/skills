# Several issues, sub-issues, and blockers

Read this when the user asked to split work into several issues, or to link
issues as parents, children, or blockers.

## Order

File in dependency order, so every number a later command needs exists:

1. The parent, when there is one.
2. Each issue that blocks another.
3. The rest, each naming its parent and its blockers as it is created.

Draft all of them first, one body file per issue (`issue-<slug>-1.md` and on),
with every command listed in the reply, and file only after the user approves
the breakdown and asks to file.

## With gh 2.94 or later

`gh issue create` and `gh issue edit` take the relationships directly:

```bash
gh issue create --repo <owner/repo> --title "<title>" --body-file <path> \
  --parent <parent> --blocked-by <n>,<m>
gh issue edit <n> --repo <owner/repo> --add-sub-issue <a>,<b>
gh issue edit <n> --repo <owner/repo> --add-blocked-by <m>
```

Check the version with `gh --version` before using these.

## With an older gh

The REST API takes the issue's database id, not its number. Read the id
first, then link:

```bash
id="$(gh api repos/<owner>/<repo>/issues/<child> --jq .id)"
gh api repos/<owner>/<repo>/issues/<parent>/sub_issues -X POST -F sub_issue_id="$id"
```

A blocker has no REST shape every account can rely on, so with an older `gh`
write "Blocked by #<m>" as the first line of the body instead.

## After filing

Read each issue back with
`gh issue view <n> --repo <owner/repo> --json number,url,labels`, and list
every URL in the report in the order filed.
