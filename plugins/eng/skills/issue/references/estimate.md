# Estimate and priority

Every new issue's body ends with this section, and the tracker's own fields
carry the same values where they exist. [mcp.md](mcp.md) maps them for a
tracker's MCP tools, and [github.md](github.md) for GitHub.

## The section

```markdown
## Estimate and priority

- Priority: <Urgent, High, Medium or Low>. <one-line reason>
- Effort: <Low, Medium or High>. Story points: <n>.
- Time: about <total> of session time, <share> of yours (<what needs you>).

  | Plan | Implement | Test | PR and review | Merge | Final test |
  | -- | -- | -- | -- | -- | -- |
  | <t> | <t> | <t> | <t> | <t> | <t> |
- Due: <YYYY-MM-DD>. <reason>   (or: Due: none. <reason>)
- Calibrated against: <issues or PRs read>   (or: uncalibrated)
- Recommended approach: <two to four lines>
```

The recommended approach is the one place the body names the
implementation. What needs the user is approving the plan, merging, and the
final test.

## Size

Size from the files and steps the change touches. Points come from the scale
the repo's guidance names, else the scale recent issues in that tracker use,
else 1, 2, 3, 5, 8. Effort goes by rank: Low is the bottom third of the
scale's values and High the top third, each rounded up, and Medium the rest.
When that leaves Medium empty, Low and High give it their inner values. On
1, 2, 3, 5, 8 that is 1 and 2, then 3, then 5 and 8.

Work that sizes above the top value is proposed as two issues and waits for
approval, as [github.md](github.md) says. Under a plan the split is settled
at planning, and the run files what Delivery names, with its values as
approved.

## Calibrate

Each source measures one thing:

- Time, when the repo's pull requests are on GitHub:
  `gh pr list --state merged --limit 20 --json createdAt,mergedAt`. Open to
  merge measures the PR and review plus merge phases. Drop spans under 15
  minutes and over 8 hours, and take the median. Merge is the 10 minutes it
  takes the user, and PR and review is the rest of the median.
- Without GitHub pull requests, a closed issue's span in the tracker in use
  stands in: its search or list tool on the team or project, filtered to
  completed, asking for the created, started and completed dates and the
  estimate where it returns them. From started to completed measures
  everything after plan, or the whole total when started is missing or
  equals created. A tracker that records the start only as a move to an in
  progress state counts from that move, when its tools return it.
- Points, whatever the time source: closed issues in the same tracker that
  carry an estimate, from that same search. Match the points of ones of
  similar size.

As a fallback, one pull request across a handful of files takes about 2 hours
of session work from plan through test, and 1 to 2 hours from open to merge.
Plan, implement and test scale from the size against those 2 hours, and the
final test takes about 15 minutes of the user's time. With no
history, because the tracker has no tools or a read fails, use the fallback
for every phase and write "uncalibrated".

## Priority and due date

- Urgent: broken for users now, or blocks a release. Due the second working
  day after filing.
- High: blocks other work, or touches every run. Due the fifth working day
  after filing.
- Medium: the default. A date only when a release or a blocked issue needs
  one.
- Low: nothing waits on it. No date.

Working days run Monday to Friday. A date the user, a release, or Delivery
names wins, and so does an earlier one a release or a blocked issue needs.

## Fields

Set each field the tracker has. A label carries priority only when one
already exists. Where a field does not exist, the section still carries the
value. A save that fails on one field is retried once without it, the value
stays in the body, and the report says so. Read each field back, and report
one the tracker dropped or changed.
