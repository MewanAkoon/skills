# Changelog

Each release of the `eng` plugin, newest first. The version is the one in
`.claude-plugin/plugin.json`, and a release covers every pull request merged
while `main` carried it. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the numbers
follow semantic versioning.

## 0.9.0 - unreleased

### Fixed

- A long command no longer gets past the hook unread. The command parser
  read a 500 KB string in 23 seconds on macOS, past the hook's 10 second
  timeout, and now reads a megabyte of quoted string or heredoc in about a
  second. It also stops after
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
