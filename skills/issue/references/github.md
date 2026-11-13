# Several issues, sub-issues, and blockers

Propose the breakdown as vertical slices, each testable, and wait for
approval, which a Delivery naming each issue already is. Draft each to its own
pair of files, then file the parent, then each blocker, then the rest.

With `gh` 2.94 or later:

```bash
gh issue create --repo <owner/repo> --title "$(cat "<title path>")" \
  --body-file "<body path>" --parent <parent> --blocked-by <n>,<m>
```

On an older `gh`, REST takes the database id, and a blocker is a "Blocked by
#<m>" first line:

```bash
id="$(gh api repos/<owner>/<repo>/issues/<child> --jq .id)"
gh api repos/<owner>/<repo>/issues/<parent>/sub_issues -X POST -F sub_issue_id="$id"
```

List the URLs in the order filed.
