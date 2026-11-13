# GitHub fields, several issues, sub-issues, and blockers

## Fields

GitHub issues have no priority, points or due date of their own, so the body
section from [estimate.md](estimate.md) carries them, and a priority label
only when the repo already has one.

When the repo's guidance names a GitHub Project, set its fields too. Read
them with `gh project field-list <number> --owner <owner> --format json`; a
failure, such as a token without `read:project`, means no fields. Add the
issue, then set each field the project has, by name, where
`gh project item-edit --help` lists `--field`:

```bash
gh project item-add <number> --owner <owner> --url <issue url>
gh project item-edit <number> --owner <owner> --url <issue url> --field "<name>" --number <points>
gh project item-edit <number> --owner <owner> --url <issue url> --field "<name>" --date <YYYY-MM-DD>
gh project item-edit <number> --owner <owner> --url <issue url> --field "<name>" --value "<option>"
```

Where `--help` does not list `--field`, pass the ids instead: `--id` from
`item-add --format json`, `--project-id` from
`gh project view <number> --owner <owner> --format json`, and `--field-id`
and `--single-select-option-id` from `field-list`. Read the fields back with
`gh project item-list <number> --owner <owner> --limit 500 --format json`.

The hook asks the user to confirm each `gh project` write in the main session
and denies it in a subagent, so a subagent lists these commands in its report
instead.

## Several issues

Propose the breakdown as vertical slices, each testable, and wait for
approval, which a Delivery naming each issue already is. Draft each to its own
pair of files, then file the parent, then each blocker, then the rest.

With `gh` 2.94 or later:

```bash
gh issue create --repo <owner/repo> --title "$(cat "<title path>")" \
  --body-file "<body path>" --assignee @me --parent <parent> --blocked-by <n>,<m>
```

On an older `gh`, REST takes the database id, and a blocker is a "Blocked by
#<m>" first line:

```bash
id="$(gh api repos/<owner>/<repo>/issues/<child> --jq .id)"
gh api repos/<owner>/<repo>/issues/<parent>/sub_issues -X POST -F sub_issue_id="$id"
```

List the URLs in the order filed.
