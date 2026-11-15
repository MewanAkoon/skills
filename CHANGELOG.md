# Changelog

Each release of the `eng` plugin, newest first. The version is the one in
`plugins/eng/.claude-plugin/plugin.json`. A pull request adds its entry under
`## Unreleased` and leaves the version alone. A release moves those entries
under a heading for its version with its date, bumps `plugin.json`, tags the
commit `vX.Y.Z`, and fast-forwards the `stable` branch that installs follow.
A version marked "not tagged" reached `main`, and every install that followed
`main` then, but has no tag. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the numbers
follow semantic versioning.

## Unreleased

### Added

- A setup check that tells you what a machine is missing. On a new session the
  hook shows you, and not the model, one line for each setting the README's
  Setup section asks for that is missing from your user settings, and for each
  tool in the new `standards/dependencies.md` that is not installed, with its
  install command: Claude Code 2.1.293 or later, git, jq, `gh` and its login,
  and the gh-stack extension and skill. The first prompt outside plan mode
  adds a line when the permission mode and rules would stop `git commit`,
  `git push`, `gh pr create`, `gh pr edit`, `gh pr ready`, `gh stack` or an
  MCP issue write for a prompt, since only a prompt carries the mode. Auto
  mode shows nothing. A plugin cannot ship any of these settings itself, so
  each is warned about. The checks live in `hooks/setup-check`, which
  `check.sh --doctor` now runs too, so the two agree, and which runs under a
  3-second limit so a hanging `gh` never costs the session its contract. It
  installs nothing and writes no settings file.

- Stacked pull requests through gh-stack, without being asked, in
  `implement/references/stack.md`. A plan whose Changes split into dependent
  layers, or a branch already in a stack, names one branch per layer under
  Delivery, after checking the gh-stack extension is installed. The run
  builds the stack one layer at a time with `gh stack init` and
  `gh stack add`, adopting a branch when the top layer is checked out in
  another worktree, opens the PRs with `gh stack submit --auto`, then sets
  each new PR's title, body, tracker line and `@me` assignee with
  `gh pr edit`. It reviews each layer from the one below, marks each PR
  ready on its own, and restacks with `gh stack rebase --upstack` and
  `gh stack push` when it changes a lower layer, or `gh stack sync` when one
  merges, with no question. Before its first stack rebase, push, submit or
  sync, it fetches and stops with a report when a layer it has not committed
  on differs from its remote, since `gh stack push` would overwrite or
  publish another session's work there.
- `eng:merge-conflicts` resolves a conflict in a rebase the run started,
  and continues a stack's rebase with `gh stack rebase --continue`.
  `eng:commit` and `eng:pr` hand a paused stack rebase that lists their
  branch to it.
- The `issue-asks-to-connect` eval: an issue run in a repo tracked in Jira,
  with no Jira tools in the session, names the server to connect and
  drafts nothing.
- A security review when a change touches a trust boundary, in
  `implement/references/security.md`. Every review report opens with one
  line naming the trust boundaries the diff touches, or none. When it
  touches one, the intent check reads the diff against a security checklist
  in this repo's own words, and once the work is committed, a subagent runs
  Claude Code's built-in `security-review` once before the push, since it
  reads only committed changes. Their valid findings go through the review
  loop's ledger and fixes. Where the built-in is missing or cannot run, the
  report says so. The fast path runs the intent check for the checklist
  alone on such a change.
- `OPTIONAL-EXTRAS.md` lists Cloudflare's `security-audit` for a whole-repo
  audit now and then, and Trail of Bits' `differential-review` for a deep
  review of one risky diff.
- `tests/review-loop/setup.sh` takes `shell` or `docs` to build a change that
  does or does not touch a trust boundary, and gives every scratch repo a
  bare origin with `origin/HEAD` set.
- `investigate/references/models.md` names the model and effort for each
  subagent: Opus at high for round 1 of a check, Sonnet at medium for later
  rounds and the intent check, Haiku at low for a docs fetch or file search.
  Where a harness cannot set one, the subagent runs on the session's own.
  Where there is an advisor tool, the session consults it on the final plan
  and before the run's first `gh pr ready`.
- `eng:plain-writing` spells out made-up abbreviations, numbers test plans,
  reproduction steps and setup instructions one action per step, leads with
  what the reader must know or do, and checks after writing that every
  negation survived and that no sentence reads two ways. These rules draw on
  the `i-have-adhd` and `caveman` skills, credited in its footer.

### Changed

- `standards/workflow.md` is six steps: understand, plan and stop,
  implement and review, writes, posting, and final updates. It now says that
  every finding, plan and report is checked in rounds until independent
  passes agree, that `/code-review` runs at `high` on the full diff and at
  `medium` on each fix diff, that pushes to the default branch and changes
  to global config need your message, that every reply leads with the
  result, and that `eng:<name>` is the skill `<name>` where skills have no
  plugin prefix. The contract-at-start eval asks for step 4.
- The README leads with requirements, setup, the settings with which are
  required, a check that needs no clone, update and removal, and follows with
  the workflow, the skills, five guardrails and a guarantee table that
  matches the hook. It drops the hook rules 0.16.0 removed, the old-symlink
  migration, the Cursor copy advice and the cloud steps, which a cloud
  session cannot use, since it loads no plugins. Working on the repo, the
  checks, evals, subsets and sharing one skill move to a new
  `CONTRIBUTING.md`, and `AGENTS.md` leaves the invariants to `check.sh`.
- `check.sh` drops the per-skill size budgets, keeping the 15,000-byte cap,
  the description budgets and `workflow.md`'s 3,000 bytes; drops the check
  that the docs and CI state the Claude Code minimum; bans the en dash and
  minus sign only in markdown, and the em dash everywhere; and drops the
  `bash checked` block runner and the tools-field warning.
- `eng:implement`'s test step says a test or subagent never writes through a
  path that is, or was, a link to an installed binary, and never touches the
  live Claude Code install.
- The plugin, marketplace and hooks descriptions are short and say what the
  plugin does now. The CHANGELOG dates 0.9.0 by its tag, dates each untagged
  version by the day it reached `main`, and adds the missing 0.10.0 entry.
- An approved run stops on a valid security finding left unfixed, not on
  any action that touches security.
- `eng:issue` works any tracker through whatever MCP server is connected for
  it, with one procedure in `issue/references/mcp.md`, and GitHub through
  `gh`. `linear.md` and `jira.md` fold into it, keeping only the quirks that
  break a write. With no tools for the tracker, the run stops, names the
  server to connect and files nothing; the copy-paste draft comes only when
  you say it cannot be connected. With no tracker named, it asks instead of
  taking GitHub. `estimate.md` calibrates from any tracker's closed issues,
  and `eng:investigate` names the server to connect for a ticket it cannot
  read.
- The hook denies a subagent's MCP write whatever the server or its items,
  such as an Asana task, a Monday item, a Fibery entity, a Notion page or a
  doc, not only one named for an issue, ticket or work item. Well-known
  servers that run on this machine, Playwright, Puppeteer, Serena, memory,
  filesystem and sequential-thinking, are left out, except for an issue,
  ticket or work item write. The main session is unchanged.
- The README's hook table no longer says a Linear `save_comment` on an issue
  runs, that a write waits for `eng:issue` to load since your latest message,
  or that the hook reads MCP inputs through `risky_input`.
- `gh stack link` no longer asks. It pushes the branches it names, so the
  hook gates it as a push and a PR write, as it does `submit`: it runs in
  the main session and is denied in a subagent. `gh stack merge` and
  `unstack` still ask.
- `deliver.md` no longer hands a restack back as a follow-up, and checks the
  gh-stack extension at planning: plain branches only when you decline it
  there, and a run stops, naming the install, when it goes missing mid-run.
- A pull request no longer bumps the version. `scripts/check.sh` drops the
  rule that failed a change to what the plugin loads without a newer
  `version`, with its cases in `scripts/test-checks.sh` and CI's `CHECK_BASE`
  and full-history fetch. It still checks that `plugin.json` carries a
  `MAJOR.MINOR.PATCH` version.
- Setup installs from `MewanAkoon/skills#stable`, the branch only a release
  moves, so an install changes only at a release. The README says how to move
  an install that follows `main`.
- Every plan, answer and report is checked in rounds until at least two
  independent passes agree, in `investigate/references/checks.md`, which
  replaces the plan check that ran only on plans spanning more than one area.
  Round 1 starts with the investigation and settles the facts from the
  request and its sources. Later rounds review the plan in place and read
  only what changed. Only an unverified blocker starts another round, and one
  still open after round 3 becomes a question to you. A checker reports
  findings only, in about 3,000 characters, and names the strongest rival
  explanation. The plan gains a Check rounds section, and is offered for
  approval only once no check runs and the latest round found no blocker.
- A plan leaves out the sections it does not need instead of writing "none",
  and its Progress holds the lists a Done-when line asks for. An answer opens
  with the result.
- The review loop runs `code-review` at `high` on round 1 and at `medium` on
  each later fix diff, and says `code-review` and the intent check are the
  two passes it needs. The intent check runs no probe beyond its old-code
  test, and the fallback for a missing `code-review` moves into
  `intent-check.md`.
- `eng:implement` stops after three failed fixes for the same problem and
  names the assumption it doubts, and its report quotes a failing check's
  deciding error line. The hand-back leads with the result and leaves out
  empty items.

## 0.22.0 - 2026-11-14, not tagged

### Changed

- After a rebase it made, a run pushes again with
  `git push -u --force-with-lease=refs/heads/<branch>:<sha> <remote> <local>:<branch>`,
  leased on the commit it last pushed there, without asking, under any
  Delivery that covers a push. `eng:commit`'s Push section takes the sha
  from the run's notes or this clone's push reflog. With neither it fetches
  and asks, leasing on the fetched sha only on your yes, and it asks too
  when the branch is the default.
  A stacked branch rebases and pushes with `gh stack rebase` and
  `gh stack push`.
- `deliver.md` says a Delivery that covers a push also covers the force
  pushes `eng:commit`'s Push section makes without asking. The plan template
  and `standards/workflow.md` step 5 keep only force pushes outside that
  section for your latest message.

### Fixed

- A lease push whose refspec source is a default branch, such as
  `git push --force-with-lease=refs/heads/feature/x:<sha> origin main:feature/x`,
  passed the hook with no prompt and forced `main`'s history over
  `feature/x`. The hook now asks when either side of a refspec is a default
  branch, a source also by its last path part and in any case, so
  `origin/main`, `origin/HEAD`, `feature/main` and `Main` ask too. A source
  given as a bare `HEAD`, a sha or another ref at the default's commit is
  still not seen.

## 0.21.0 - 2026-11-14, not tagged

### Changed

- A push with an explicit lease,
  `git push --force-with-lease=refs/heads/<branch>:<sha> origin <branch>`,
  gets the same decision from the hook as a plain push, so it no longer
  asks after a restack. That holds when the leased branch and every branch
  the command names are not the default (`main`, `master`, or a remote's
  HEAD in the session's directory) and the push is the whole command. A
  bare `--force`, a lease with no sha or on a bare name, a delete, mirror,
  prune, tag push or push option, and a lease push to the default branch
  still ask, and a subagent's push is still denied.

### Fixed

- A unique prefix of a long `git push` option, such as `--force-w=`,
  `--del`, `--m` for `--mirror`, or `--pu=` for `--push-option`, passed the
  hook with no prompt. The hook now reads it as the full option.

## 0.20.0 - 2026-11-13, not tagged

### Changed

- Approved or named work finishes without asking. `eng:implement`'s
  `deliver.md` now names three Deliveries: an approved plan's, a default one
  for a change you name directly (branch, commit, push, draft PR, review,
  ready), and a follow-up one for a later change or valid review fix on your
  own open PR, in any session. A message such as "only make the edit"
  narrows it, and none covers a merge, release, tag, deploy, force push or
  push to the default branch. A merge your latest message asks for is not
  asked about again in chat.
- Work starts on the ticket's branch, `<type>/<ticket-key>-<slug>` with the
  type from the ticket's labels, checked out or created from the default
  branch, or from a harness branch such as `claude/...`. Unrelated
  uncommitted changes stay put, and the work and its own changes move to a
  worktree by patch. Investigation switches no branch.
- A precondition with a workaround gets its fallback and a ruling: the
  default branch for a missing base, `git remote set-head` for a missing
  `origin/HEAD`, plain branches without gh-stack. Only a missing credential
  or a hook deny stops a run.
- `eng:pr` opens every PR as a draft, takes the base from your message,
  Delivery, the stack parent or the default branch without asking, and
  finishes with the post-PR review and ready. The title and body are
  refreshed after each push when the new commits made them false, and
  `update.md` accepts a branch this run rebased when `git range-diff` shows
  the same changes.
- A PR goes ready once the local check and review are clean and CI has
  started, read once with `gh pr checks`, replacing the 600-second CI wait.
  A failing check is fixed like a finding.
- `eng:pr-feedback` runs `gh pr checkout` on another branch instead of
  asking you to switch.
- The plan template's `Branch:` carries the ticket key, and
  `standards/workflow.md` step 5 names the new Deliveries.
- The manifest description says commits and PRs follow work you approve or
  name.

## 0.19.0 - 2026-11-13, not tagged

### Changed

- `eng:issue` assigns every new issue to you: `--assignee @me` on GitHub,
  `assignee: "me"` in Linear, the signed-in user in Jira. Your message or
  the repo's guidance naming someone else, or nobody, wins, and an edit
  leaves the assignee alone. When the assignee fails, the issue is filed
  without it and the report says so.
- Every new issue ends with an "Estimate and priority" section: priority
  with a reason, effort and story points, a time estimate across plan,
  implement, test, PR and review, merge and final test, a due date set by
  priority, and the recommended approach, the one place the body names the
  implementation. The new `issue/references/estimate.md` holds the rules,
  calibrates time from the repo's merged pull requests and points from
  closed issues, and falls back to about 2 hours per pull request. The
  tracker's own fields carry the same values where they exist: Linear's
  priority, estimate and due date, Jira's priority, story points and due
  date, and a GitHub Project's fields when the guidance names one.
- Jira with Atlassian's MCP tools is handled like Linear, in the new
  `issue/references/jira.md`. Without tools, the copy-paste draft adds a
  fields file.
- No AI credit line, "Generated with" footer or session link goes in an
  issue or a comment, the same rule as commits and pull requests.
- A new issue in an approved plan's Delivery names its assignee and every
  estimate value, so the run files it without asking.

### Added

- The `issue-draft-fields` eval case checks that an issue draft carries its
  assignee, the estimate section, and no AI credit.

## 0.18.0 - 2026-11-13, not tagged

### Fixed

- A subagent's issue write through MCP is denied on any tracker, as the
  README says. GitHub's always were, Linear's had been until 0.16.0, and
  other trackers' never were. A tool whose name writes, links, locks, pins
  or transfers an issue, ticket or work item maps to the issue gate,
  whatever its server is called, so Linear's `save_issue`, Jira's issue
  writes, Sentry's `update_issue` and `link_issue`, Zendesk's ticket writes
  and Azure DevOps's work item writes are denied in a subagent. A draft
  issue, and a verb on none of the hook's lists, such as `clone_issue`,
  still pass. The main session's decisions do not change: these writes stay
  with Claude Code's own permissions, and a delete still asks.
- `mcp.cases` takes a leading `subagent` field, so its cases can run as a
  subagent, and a line the runner cannot read fails the count.

## 0.17.0 - 2026-11-13, not tagged

### Changed

- Every skill is cut to what a current model gets wrong without it. The
  skills come to about 77 KB, down from 194 KB, and 16 reference files are
  gone, mostly tutorials and rare-case procedures. Each shared rule now lives
  in one place: the AI-credit ban and the repo-guidance probe in
  `eng:commit`'s `repo-guidance.md`, the mid-operation probe in
  `eng:merge-conflicts`, the approval rule in `eng:implement`'s `deliver.md`.
- An approved plan runs to its draft PR without a question. Any plain yes,
  such as "lgtm" or "go ahead", covers Delivery, and a message that says not
  to commit, push or open a PR narrows it. `eng:pr` takes its base from
  Delivery's `Base:`, `eng:commit` its grouping, and the test seam defaults to
  the nearest existing test of the same kind, each logged as a ruling. When
  `Base:` is not on origin yet, the run branches from the default branch and
  names the restack as a follow-up, rather than stopping.
- `eng:implement` has a fast path: a small change you name exactly runs the
  repo's checks and a review loop at `/code-review medium`. The intent check
  runs in round 1 and on the final tree only. The review after a push covers
  only the commits since the last reviewed one, and the CI wait has a
  10-minute limit.
- A push rejected after a rebase the run made proposes
  `git push --force-with-lease`, which asks. Nothing proposes
  `git pull --rebase`.
- `eng:investigate` sends subagents only into areas that span several
  files, runs one merged check only on a plan that spans more than one area,
  and writes the plan file whenever Delivery lists writes. The plan template
  drops `Plan name:` and `Status:` and gains `Branch:` and `Base:`.
- `eng:why` no longer fires on a change the request names, and `eng:ts-types`
  no longer fires on reading a `.ts` file.
- No skill describes the hook's plan grants, comment gate, or whole-PR
  reminder any more.
- Workflow step 5 takes any plain approval, and step 6 reviews only the
  commits no review has read.
- `eng:issue` drafts a Linear issue comment to a file like every other
  comment, and workflow step 7 drops its exception, to match the hook that
  now denies it.

### Removed

- `eng:wayfinder`.

## 0.16.0 - 2026-11-13, not tagged

### Removed

- The hook no longer reads your messages. Gone with that: the plan grants
  and `grant-writes.log`, the check for a "no" in your latest message, the
  rule that a commit, push, PR or issue write waits for its skill to load,
  and the hints for a pull request link, a review comment link and a git
  conflict.
- The reminder to review the whole PR after a push, and the
  `PostToolUseFailure` hook that fed it. Nothing checks any more that a
  pushed tree is the one the review read.
- The exception for a comment on a Linear issue. It is a post like any other
  now, and denied.
- The MCP checks that read a tool's input, and the nouns, such as
  `permission`, `payment` or `token`, that made a name ask.
- The `commit-gate-on-request` eval, which tested the skill-loaded gate.

### Changed

- In the main session the hook decides only that a post is denied and a
  write that is hard to take back asks, apart from the code-review flag
  guard and the ask when its command parser fails. A commit, push, PR or
  issue write gets no decision, so Claude Code's own permission settings
  decide it. That covers `gh stack push`, `sync` and `submit`; `gh stack merge`,
  `unstack` and `link` ask.
- Every remote write the hook finds from a subagent is denied, with one
  reason: a commit, push, PR or issue write, a post, and every write that
  asks in the main session, such as `gh stack merge` or a deploy. That holds
  for shell commands, for a post through any MCP tool, and for the GitHub and
  git MCP writes the hook maps to commits, pushes, PRs and issues. Other MCP
  writes, such as a Linear issue, a Notion page or a GitHub repository or
  gist, pass unless their name is one that asks, which a subagent is
  denied.
- An MCP tool asks only when its name deletes, merges, releases, deploys,
  sends or publishes, or when it closes, reopens or updates the branch of a
  GitHub PR. A share, trash, move, assignment or invite no longer asks, and
  neither does an input that deletes inside a generic tool. GitHub and git
  writes through MCP still count as commits, pushes, PRs and issue writes,
  so a GitHub `delete_issue` gets no decision and a subagent's is denied.
- The review reminder keeps one hash. Any code-review the main session runs
  clears it, whatever it was pointed at, and a tree gets the reminder once:
  a second stop on the same changes passes.

## 0.15.0 - 2026-11-13, not tagged

### Changed

- The plugin now lives in `plugins/eng/`, and the marketplace lists it with
  `"source": "./plugins/eng"`, so an install copies the skills, hooks,
  standards, evals, manifest and icon, and none of the repo's scripts, tests or
  docs. The plugin id `eng@mewanakoon` and its data directory stay the same,
  so `claude plugin update eng@mewanakoon` moves an install across.
- `scripts/validate-plugin.sh` validates the root and `plugins/eng --strict`,
  and fails on any finding, a plugin directory warning included, where it
  used to allow the root `CLAUDE.md` warning. `check.sh` checks the icon,
  and its version rule reads `plugins/eng/` and leaves `evals/` out, so an
  eval-only change needs no release. `scripts/test-checks.sh` covers the
  rule and the wrapper.

### Added

- An icon at `plugins/eng/.claude-plugin/icon.png`, which the plugin
  directory asks for.
- Permission rules for `gh stack` in the README's setup: allow
  `Bash(gh stack:*)`, and ask for `Bash(gh stack merge:*)` and
  `Bash(gh stack unstack:*)`. `scripts/cloud-setup.sh` adds them to a cloud
  VM's settings, joining any permission lists already there, and
  `./scripts/check.sh --doctor` names any one that is missing.

### Removed

- `link.sh`, which removed the symlinks of the install before the plugin.
  `./scripts/check.sh --doctor` still names each old link, and the README
  says how to remove one. `scripts/legacy.sh` went with it, and its list of
  retired skill names now lives in `check.sh`.
- `scripts/stats.mjs`, its fixtures, and the `stats` and `test:stats` npm
  scripts, so `check.sh` no longer needs Node. `npm run lint` and CI's
  pinned validator still run through npx. The hook still writes its logs.

## 0.14.0 - 2026-11-12, not tagged

### Changed

- `eng:issue` now makes an issue write that a plan you approved names under
  Delivery without another ask, as `eng:commit` and `eng:pr` already do for a
  commit and a PR. Delivery names a new issue by its team or repo and what it
  is about, and an edit, label change or close by the issue and the change. A
  line that names no write, such as "file an issue for each follow-up review
  finds", grants nothing, and a comment still needs your latest message.
  `eng:implement`'s delivery makes those writes once the review loop reports
  ready, before the commit, and the hand-back lists each one with its URL, or
  why it was skipped. The plan template gives Delivery a place for them.

## 0.13.0 - 2026-11-12, not tagged

### Changed

- `eng:issue` can comment on a Linear issue when your latest message asks
  for that comment, through Linear's `save_comment` with only the issue and
  the body. Without that ask it drafts the comment to a file. Every other
  comment, GitHub's included, stays a draft, and so does an edit, a reply,
  or a comment on a Linear project, document, initiative, milestone or
  status update. Workflow step 7 says so.
- The hook lets that comment through the write gate: denied in a subagent,
  when `eng:issue` has not loaded since your latest message, or when that
  message says not to comment, and denied when there is no state to read.
  A comment that mentions someone asks you to confirm it.
- Linear issue writes, through `save_issue` or the old server's
  `create_issue` and `update_issue`, now go through the same gate as GitHub
  issue writes.

## 0.12.0 - 2026-11-12, not tagged

### Changed

- `eng:issue` now works out which tracker a repo uses before it drafts: the
  one your message names, or else the one the repo's guidance names, with
  the team, project or repo to file in. When neither names one, it drafts
  for GitHub if issues are on, says so, and offers a line for the repo's
  guidance, and otherwise asks. It never guesses from history. In
  Linear, with Linear's tools in the session, it searches for a duplicate,
  drafts to files, and creates the issue only when your latest message
  asks. The hook gates GitHub issue writes but not Linear's, so there the
  skill and the workflow hold that rule. Any other tracker still gets
  copy-paste text.

## 0.11.0 - 2026-11-12, not tagged

### Changed

- `eng:pr` assigns each pull request it opens to the account `gh` is signed
  in as, with `--assignee @me`, and still adds no reviewer the user did not
  name. Assignees the user names, or none, win, and a PR to a fork's upstream
  gets none. When the assignee fails after the PR opened, the run goes on and
  says what is missing, and when no PR opened, it tries once without the
  default `@me`. The explanation of its stop on an operation in flight or an
  unmerged path moves to a reference file, to make room.

## 0.10.0 - 2026-11-11, not tagged

### Added

- A plan you approved could deliver itself. The hook recorded a plain
  approval of a plan file in `.claude/plans` that named a branch, and on that
  branch let a plain `git push` or `gh pr create` run without a prompt once
  a review at `high` had read the tree, while it denied a push of an
  unreviewed tree. After a push, the Stop hook held the hand-back until the
  whole PR was reviewed. 0.16.0 removed the grant, and approved Delivery now
  rests on the skills and Claude Code's permissions.
- `implement/references/deliver.md` holds the delivery steps, stops and
  hand-back, and `investigate/references/plan.md` gains the plan file header,
  Delivery, Walk-through and Progress.

### Changed

- The review loop runs until a round finds nothing valid to fix, with a
  findings ledger so no round undoes another, and stops early only when it
  is not converging or after six rounds.

## 0.9.1 - 2026-11-10, not tagged

### Changed

- Every skill file with a tighter size budget, and `eng:pr` and
  `eng:merge-conflicts`, now sits at 90% of its budget or less, so later
  edits have room. Each moves blocks into reference files read at the step
  that needs them: `eng:implement` its rename and guard rules and its intent
  check, `eng:pr-feedback` its thread query and reply commands, `eng:pr` its
  body template and its check of an open PR's head, `eng:issue` its edit,
  close and read-back commands, `eng:investigate` its subagent briefs and
  its question path, and `eng:merge-conflicts` the stash pop, `git am` and
  `git apply --3way` branches. A few repeated or explanatory sentences are
  gone. What each skill does is unchanged.

## 0.9.0 - 2026-11-05

### Fixed

- A long command no longer gets past the hook unread. The command parser
  read a 500 KB string in 23 seconds on macOS, past the hook's 10 second
  timeout, and now reads a megabyte of quoted string or heredoc in a second
  or two. It also stops after
  5 seconds and asks, and it keeps looking for a post past its 500-segment
  cap.
- Posts and writes that ran with no prompt now meet the guard:
  `gh discussion comment`, `gh stack` and `gt merge`, a command behind a
  runner such as `op run`, `npm exec` or `uv run`, gh's `remove` commands,
  deploy keys, SSH and GPG keys, codespaces, gh aliases, `gh pr lock`,
  Discord's versioned API, Power Automate webhooks, a GitHub MCP branch
  update, and a risky verb among the first words of a several-word MCP
  command, such as `gh repo delete x`.
- The hook saves your message before it hashes the tree, writes each loaded
  skill on its own line, logs a failed read of your message, sweeps up temp
  files a stopped hook left, cuts its log to 1000 lines once it passes 2000,
  and reads "stop pushing" as a no.
- `eng:pr` compares a fork's branch with the upstream base, and
  `eng:pr-feedback` pastes from the clipboard on Linux.

### Changed

- `eng:commit` and `eng:pr` keep the `Claude-Session` trailer and the
  claude.ai session link out, and `eng:pr` adds no reviewer or assignee you
  did not name and asks no second time for an update you asked for.
- `check.sh` checks every relative link, the parser limit against the hook
  timeout, matching manifest descriptions and one Claude Code minimum.
  `--doctor` also reads this clone's own settings, `stats.mjs` honours
  `CLAUDE_CODE_PLUGIN_CACHE_DIR`, CI runs the stats fixtures on Node 18.1
  and pins macOS, and `cloud-setup.sh` writes through a `mktemp` file.

### Added

- This changelog, and an eval case for a request to open a PR.

## 0.8.3 - 2026-11-01

### Added

- Setup turns Claude Code's attribution off, and `check.sh --doctor` fails
  until it is (#32).
- `scripts/cloud-setup.sh` gives a cloud session the same `skillOverrides`
  and `attribution` settings as the Mac, through the VM's own
  `~/.claude` (#33).

### Fixed

- The hook's header says what a parser crash still denies, with tests for
  a subagent's push, a push with no skill loaded and a push the gate
  allows (#32).

## 0.8.2 - 2026-10-29, not tagged

### Changed

- The README's MCP row summarises what still asks and links to the exact
  rules (#28).

### Fixed

- When the command parser fails, the hook asks instead of letting the
  command run, and still denies a post it had already found (#30).

## 0.8.1 - 2026-10-29, not tagged

### Fixed

- The command classifier no longer crashes on GNU awk 5.3, which had let
  commands piped into a shell run unread. CI runs on Ubuntu 24.04 and
  26.04 (#29).

## 0.8.0 - 2026-10-27, not tagged

### Changed

- MCP writes ask only when the tool or its input is risky, such as a
  delete, a share, a send or a deploy. Ordinary edits go to Claude Code's
  own permissions (#26).

## 0.7.0 - 2026-10-15

### Added

- After a PR opens and after each push, the workflow reviews the whole PR,
  and the hook reminds once per pushed commit until a review reaches
  it (#23).

### Changed

- CI pins its Ubuntu runner to 24.04, after `ubuntu-latest` moved to 26.04
  and failed six hook cases (#27).

## 0.6.0 - 2026-10-14

### Added

- `npm run stats` counts, per week, remote writes and whether they were
  asked for, review passes, drafts and compactions, from this machine's
  transcripts (#18).

### Changed

- The write gate lets a commit, push, PR or issue write run unless your
  latest message says not to, and a subagent's report no longer replaces
  your message (#20).

## 0.5.0 - 2026-10-14

### Added

- `eng:commit` and `eng:pr` find and follow a repo's own commit and PR
  guidance, including its own skills, and keep the eng defaults where it
  has none (#22).

## 0.4.0 - never released

This number was taken on a branch and never reached `main`. 0.5.0 follows
0.3.0 directly.

## 0.3.0 - 2026-10-14

### Added

- Hooks that deny posts, gate commits, pushes, PRs and issues on their
  skill, ask before other remote writes, and remind about review before
  changed code is handed back (#19).

## 0.2.0 - 2026-10-10

### Added

- A SessionStart hook sends the workflow and the core writing rules, and
  `eng:investigate`, `eng:implement`, `eng:pr-feedback` and `eng:issue`
  carry it through. Review runs through the built-in `/code-review` (#15).

### Fixed

- `eng:commit` and `eng:pr` pass text through files, which macOS bash 3.2
  needs, and read the upstream before they push (#16).

## 0.1.0 - 2026-10-09

### Added

- The skills ship as the Claude Code plugin `eng` from the `mewanakoon`
  marketplace in this repo, and every skill is named `eng:<name>` (#14).
- `check.sh` checks the manifests and requires a version bump when anything
  the plugin loads changes (#14).

Before 0.1.0 the skills had no version, and `link.sh` linked them into
`~/.claude/skills` (#2 to #12).
