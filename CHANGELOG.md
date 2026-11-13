# Changelog

Each release of the `eng` plugin, newest first. The version is the one in
`plugins/eng/.claude-plugin/plugin.json`, and a release covers every pull request merged
while `main` carried it. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the numbers
follow semantic versioning.

## 0.17.0 - unreleased

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

## 0.16.0 - unreleased

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

## 0.15.0 - unreleased

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

## 0.14.0 - unreleased

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

## 0.13.0 - unreleased

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

## 0.12.0 - unreleased

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

## 0.11.0 - unreleased

### Changed

- `eng:pr` assigns each pull request it opens to the account `gh` is signed
  in as, with `--assignee @me`, and still adds no reviewer the user did not
  name. Assignees the user names, or none, win, and a PR to a fork's upstream
  gets none. When the assignee fails after the PR opened, the run goes on and
  says what is missing, and when no PR opened, it tries once without the
  default `@me`. The explanation of its stop on an operation in flight or an
  unmerged path moves to a reference file, to make room.

## 0.9.1 - unreleased

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

## 0.9.0 - unreleased

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

## 0.8.2 - 2026-10-29

### Changed

- The README's MCP row summarises what still asks and links to the exact
  rules (#28).

### Fixed

- When the command parser fails, the hook asks instead of letting the
  command run, and still denies a post it had already found (#30).

## 0.8.1 - 2026-10-29

### Fixed

- The command classifier no longer crashes on GNU awk 5.3, which had let
  commands piped into a shell run unread. CI runs on Ubuntu 24.04 and
  26.04 (#29).

## 0.8.0 - 2026-10-27

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
