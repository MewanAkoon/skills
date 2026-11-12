# Several issues, sub-issues, and blockers

Read this when a split into several issues, or a link between issues as
parents, children, or blockers, was asked for, as `SKILL.md`'s "When it runs"
says.

Propose the breakdown first, as vertical slices that each deliver something
testable, and wait for the user's approval. An approved plan whose Delivery
names each issue is that approval already.

## Order

File in dependency order, so every number a later command needs exists:

1. The parent, when there is one.
2. Each issue that blocks another.
3. The rest, each naming its parent and its blockers as it is created.

Draft all of them first, one body file and one title file per issue
(`issue-<slug>-1.md` and `issue-<slug>-1.title`, and on), with every command
listed in the reply, and file only once the breakdown is approved and filing
is asked for.

## With gh 2.94 or later

`gh issue create` and `gh issue edit` take the relationships directly:

```bash
gh issue create --repo <owner/repo> --title "$(cat "<title path>")" \
  --body-file "<body path>" --parent <parent> --blocked-by <n>,<m>
gh issue edit <n> --repo <owner/repo> --add-sub-issue <a>,<b>
gh issue edit <n> --repo <owner/repo> --add-blocked-by <m>
```

Check the version with `gh --version` before using these. The title comes
from its file for the reason `SKILL.md`'s step 5 gives.

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
