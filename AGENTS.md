# Agent instructions

For any agent working in this repo.

## What this repo is

A source of agent skills, not an application, shipped as one Claude Code
plugin, `eng`. There is nothing to build. The tests that run are the fixtures
`check.sh` runs for the hook, for `scripts/cloud-setup.sh`, and for
`check.sh`'s own version rule and the validator wrapper. `tests/review-loop/`
holds the setup for a check run by hand, and `plugins/eng/evals/` the cases for
`claude plugin eval`, also run by hand. Every `SKILL.md` loads into some other
repo's session, so a change here changes how an agent behaves everywhere.

The repo is the marketplace, and the plugin is one folder in it,
`plugins/eng/`, so an install copies that folder and nothing else.
`plugins/eng/.claude-plugin/plugin.json` names the plugin and carries its
version, and `icon.png` beside it is the plugin's icon.
`.claude-plugin/marketplace.json` at the root names the marketplace,
`mewanakoon`, and lists the one plugin with `"source": "./plugins/eng"`. Claude
Code finds the skills by its default scan of the plugin's `skills/`. Inside the
plugin each skill is `eng:<name>`, and that full name is how skills refer to
each other.

Six scripts, all in bash, and no build step. The commands they carry:

| Command | What it does |
|---|---|
| `./scripts/check.sh` | Checks the invariants below. CI runs this one. |
| `./scripts/check.sh --doctor` | Adds the install checks, which need a machine to inspect. Fails when anything needs fixing. |
| `./scripts/validate-plugin.sh` | Runs `claude plugin validate` over the root and, with `--strict`, over `plugins/eng`, and fails on any finding, plugin directory warnings included. CI runs it on a pinned Claude Code. |
| `./scripts/test-hooks.sh` | Feeds `plugins/eng/hooks/eng-hook` its inputs, from `tests/hooks/` and its own cases, and checks what it sends. `check.sh` runs it. |
| `./scripts/test-checks.sh` | Runs `check.sh`'s version rule in scratch repos and `validate-plugin.sh` against a stand-in `claude` that prints canned output, since both fail quietly when they break. `check.sh` runs it. |
| `./scripts/test-cloud-setup.sh` | Runs `cloud-setup.sh` against scratch homes and checks what it writes and what it leaves alone. `check.sh` runs it. |
| `scripts/cloud-setup.sh` | The setup script for a personal cloud environment, pasted in at claude.ai rather than run here. It writes the attribution and `skillOverrides` settings, and rules that carry them, into the cloud VM's `~/.claude`, and adds the `gh stack` permission rules to its settings, joining any lists already there, and writes nothing unless it runs as root on Linux, the way a cloud VM runs it. `CLOUD_SETUP_HOME` points it at another home on any system, which is how `test-cloud-setup.sh` runs it against scratch ones. |

None of them needs a package installed beyond `jq` and `git`, which macOS 15
and the CI runners ship, and `claude` for the validator and `--doctor`. The
hook needs the same two and `awk`, and `cloud-setup.sh` needs `jq` and `awk`.
Each script resolves its own path with `readlink -f`, apart from
`cloud-setup.sh`, which runs from a text box with no repo beside it, and
`check.sh` takes its file list from `git`.

`package.json` carries the commands run here as `npm run check`, `doctor`,
`validate`, `test:hooks`, `test:cloud-setup` and `test:checks`, plus
`npm run lint`, which runs shellcheck over every shell script and the hook.
It declares no dependencies. `lint` fetches shellcheck through `npx`, pinning
the wrapper in `package.json` and the binary it downloads with
`SHELLCHECKJS_RELEASE`, because the wrapper takes the latest binary otherwise.
CI runs that same pinned pair rather than the runner image's shellcheck, which
moves on its own and disagreed with a local one about `A && B || C`.

## What belongs here

The plugin is Claude Code packaging, and Claude Code is the harness this repo
serves first. Two kinds of file travel, both plain markdown readable by any
harness, and neither carrying machinery of its own:

- Skills under `plugins/eng/skills/`, the unit most of the repo is made of.
- `plugins/eng/standards/workflow.md`, the standing workflow every session
  follows. It names the skill for each step that has a procedure, so every
  skill it names has to exist and be model-invoked.

The manifests and `plugins/eng/hooks/` are the Claude Code packaging around
them. The session hook reads `standards/workflow.md` and `plain-writing` at run
time and adds nothing of its own, so a file read outside the plugin still reads
the same. The other hooks enforce the workflow's rules on posting, remote
writes and review, and in places go further. For example, a subagent never runs
`git commit` or pushes, a PR merge, release or deploy always asks, even when
your message asked for it, and under a plan you approved, a push of a tree the
review loop did not read is denied on the plan's branch, and any push off it
asks. Where no hook runs, the session reads an approval by the rule in
`plugins/eng/skills/implement/references/deliver.md`, and nothing checks the
pushed tree.

Other plugins stay out, even when useful on the machine you are sitting at.
Recommendations of that kind live in [OPTIONAL-EXTRAS.md](OPTIONAL-EXTRAS.md),
which no session loads and nothing depends on. A procedure that only works in
one harness belongs nowhere unless it says what happens in the other.

A skill may rely on a Claude Code built-in, such as `/code-review`, when it
says what happens where the built-in is missing. Without that fallback, the
skill's step does nothing in another harness, and nothing says so.

Two exceptions, both narrow. A skill may carry a harness-specific frontmatter
field when it is a second lock over a body that is already right without it. No
skill takes that trade today. [WRITING-RULES.md](WRITING-RULES.md) under "Tool
access" holds the trade and the condition on it. And the Cursor rules file
carries a `description`, which lets Cursor pull it in by relevance where the
Claude rule has no equivalent; that one adds a way in rather than changing what
either file says, so both harnesses still get the same body on
`plugins/eng/skills/**`.

Maintenance scripts run on one machine rather than in a session, so they may
read a harness's own files: `--doctor` reads Claude Code's plugin list, its
settings, its `~/.claude/skills` and the hook's log, and `cloud-setup.sh`
writes Claude Code's settings and `CLAUDE.md` on a cloud VM before the session
starts. Each says so where it does it.

## What an agent here never does

Post a comment or a review to a pull request, whoever asks and however they
ask. Reading stays open: viewing a pull request, its diff, and its review
threads are all unaffected, and so is opening one. The rule is categorical
because the mistake is public and cannot be taken back, so anything whose
whole purpose is that step has no configuration that saves it.

Every other comment, review or reply is drafted to a file too, a comment on
a Linear issue included.

## Before changing a skill

Read [WRITING-RULES.md](WRITING-RULES.md). It is the standard every file here
follows, and enforcing it is what this repo is for.

## Tracking work

Work here is tracked in Linear, team Skills (key SKI), not in GitHub issues.
Dependabot pull requests are the one exception.

- Every change has a SKI issue before work starts. An agent looks for an
  existing one first, and creates a new one only when the user asks for it,
  through `eng:issue`, which reads this section to find the tracker.
- The branch is named for the issue and its type, in lowercase:
  `feature/ski-N-short-desc`, `fix/ski-N-short-desc` or
  `chore/ski-N-short-desc`. A branch name holding `ski-N` links the issue as
  closing, so merging the pull request moves the issue to Done.
- The repo has no pull request template, so `eng:pr` uses its own body. Keep
  it, and make the last line of its What and why section one linking line,
  with a blank line before it so it renders as its own paragraph:
  `Fixes SKI-N` when merging finishes the issue, or `Part of SKI-N`
  when more pull requests follow. A partial pull request leaves `ski-N` out
  of its branch name, or the issue splits into sub-issues that each take
  `Fixes`.
- A Linear issue never names a pull request by number.
- Story points are 1, 2, 3, 5 or 8.

## Invariants

`./scripts/check.sh` verifies these, so run it before committing.

- The `name` in the frontmatter matches the directory name, and both satisfy
  the Agent Skills spec: 1 to 64 characters, lowercase letters, digits, and
  single hyphens, with no hyphen at either end.
- The `description` is present and at most 1024 characters, which is the cap
  the spec sets.
- A user-invoked skill sets `disable-model-invocation: true`. A model-invoked
  skill omits the field.
- Every skill has a row in the `README.md` table, under the heading matching
  its invocation mode and not under the other one.
- Every `README.md` table row points at a skill that exists.
- Every relative link in a tracked or new markdown file resolves to a file or
  folder that exists, whatever kind of file it names. Web and mail links,
  links to a heading in the same file, and links inside fenced code blocks,
  which are templates, are left out.
- The two rules files close their frontmatter, carry a body that is not empty,
  and carry the same body. An unclosed fence reads as an empty body, and two
  empty bodies compare equal.
- Both rules files still scope themselves to `plugins/eng/skills/**`, and the
  Cursor one still sets `alwaysApply: false`. That scoping is what decides when
  either rule loads.
- A skill carrying `allowed-tools` or `disallowed-tools` warns rather than
  fails, because whether the body holds without the field is not something a
  script can read. No skill carries one today.
- Every description is one line of YAML. Unquoted, it
  is not a `>` or `|` block, holds no `: `, space or tab before `#`, colon
  before a tab, or trailing colon, and starts with no character YAML reserves.
  Quoted, it ends on its closing quote with nothing after it, and holds no
  quote or backslash inside that would end or garble it. Claude Code drops the
  whole frontmatter of a file whose YAML fails to parse.
- `plugins/eng/standards/workflow.md` names at least one skill as "the X
  skill", and every skill named that way exists and is model-invoked.
- Size budgets, because each of these loads into someone's context. A
  model-invoked description is at most 300 bytes, and the set at most 3,900.
  `plugins/eng/standards/workflow.md` is at most 3,000 bytes, and the block the
  session hook sends at most 5,000. `investigate`'s `SKILL.md` is at most 6,500
  bytes, `issue`'s 6,000, and `implement`'s and `pr-feedback`'s 5,000 each,
  with `implement/references/review.md` at most 3,500. Every other `SKILL.md`
  and every reference file is at most 15,000 bytes, inside the 20,000
  characters compaction keeps of a skill.
- Every `scripts/*.sh`, `tests/*/*.sh`, and `plugins/eng/evals/*/scaffold.sh`
  parses under `bash -n`, because the checker runs few of them.
  `plugins/eng/hooks/eng-hook` parses under `sh -n`, which names a syntax error
  plainly, `plugins/eng/hooks/classify-command.awk` loads in `awk`, and the
  hook's fixtures, `scripts/test-cloud-setup.sh`'s cases and
  `scripts/test-checks.sh`'s cases pass.
- Both manifests parse. The marketplace lists exactly one plugin, under the
  name `plugin.json` gives it, with `"source": "./plugins/eng"`, and
  `plugin.json` carries a `MAJOR.MINOR.PATCH` version. Both give the plugin the
  same description.
- `plugins/eng/.claude-plugin/icon.png` is a PNG, square, 512 to 2048 pixels a
  side, and under 2 MB. 2.1.318's plugin directory checks warn without one,
  and the validator CI pins does not look for it.
- The PreToolUse timeout in `plugins/eng/hooks/hooks.json` is at least 3
  seconds more than the command parser's time limit, which
  `plugins/eng/hooks/eng-hook` sets as `PARSE_SECONDS` on a line of its own, so
  the hook stops a slow parser and asks before Claude Code stops the hook and
  runs the command unread.
- `README.md`, `AGENTS.md` and `.github/workflows/check.yml` each state the
  oldest Claude Code these skills support, and state the same one as `cc_min`
  in `scripts/check.sh`.
- When anything the plugin loads changed since the branch left `origin/main`
  (under `plugins/eng/`: `skills/`, `standards/`, `hooks/` and
  `.claude-plugin/` today; `agents/`, `commands/`, `output-styles/`, `themes/`,
  `monitors/`, `workflows/`, `bin/`, `.mcp.json` and `.lsp.json` once they
  exist), the version is newer than the one at that point, compared field by
  field. `evals/` is left out, since no session loads it. A base from before
  0.15.0 carries `plugin.json` at the root, and the rule reads it there.
  `CHECK_BASE` names another base. A clone without that ref gets a warning
  instead. CI on a push to `main` sets it to `main` as it was before the push,
  so two pull requests that bumped to the same version fail once the second
  lands. Requiring branches to be up to date before merging stops that
  earlier.
- No skill takes a name Claude Code uses for a built-in command or bundled
  skill. `commit` and `pr` are the two kept on purpose, because every
  reference writes them `eng:commit` and `eng:pr` and the README's
  `skillOverrides` entry turns the built-ins off.
- Every `eng:<name>` in a skill names a skill here, and no skill tells anyone
  to type a skill by its bare name, such as `` `/why` ``, in backticks or in
  plain text. Claude Code does not resolve every bare name to the plugin's
  skill. A bare name in prose, such as "the why skill", is not checked.
- Every command block whose fence reads `bash checked`, in a staged or
  committed markdown file, runs from the repo root with stdin closed and exits
  zero. The checker executes these, so an untracked file is left alone.
- No file the repo owns contains an em dash, an en dash, or a minus sign.

What limits the model-invoked set is conflict, not count. Before adding one,
work through the test in [WRITING-RULES.md](WRITING-RULES.md) under
"Invocation". No script checks that.

Nothing here deletes a skill for going unused. A model-invoked one that stays
quiet, on an install that checks out, gets demoted to user-invoked instead:
the description stops riding every turn and the file stays.
[WRITING-RULES.md](WRITING-RULES.md) under "Keeping skills" holds it.

`./scripts/check.sh --doctor` adds the checks CI cannot run, because a fresh
runner has no Claude Code install to inspect: that Claude Code is 2.1.293 or
later; that `eng@mewanakoon` is installed at user scope, enabled and at this
clone's version; that no old link or personal copy of one of these skills sits
in `~/.claude/skills`; that `~/.claude/settings.json` is valid JSON and sets
`skillOverrides` for `commit` and `pr` to `"off"`, turns `attribution` off,
allows `Bash(gh stack:*)` and asks for `Bash(gh stack merge:*)` and
`Bash(gh stack unstack:*)`; and that the plugin's hooks have logged no error under
`~/.claude/plugins/data/eng-mewanakoon/`; and that this clone's own
`.claude/settings.json` and `.claude/settings.local.json`, where present, are
valid JSON and turn no AI credit line or session link back on.
`CLAUDE_CONFIG_DIR` moves where it looks, as it does for Claude Code, and
`CLAUDE_CODE_PLUGIN_CACHE_DIR` moves where it reads the hook's log. Anything to
fix fails the run, so a hook can gate on it.

## When a change makes a claim false

Behaviour and the prose describing it come apart one sentence at a time. After
changing what something does, search for every place that says what it does
and re-derive each from the new behaviour, rather than editing the sentence
nearest the change. Comments, headings, and the strings a script prints all
count, and the twin is usually in another file.

Mark a command block `bash checked` when its content can rot, and
`./scripts/check.sh` runs it. A pipeline that encodes an assumption earns the
marker, because the assumption is what goes stale.

Mark it only when it runs anywhere, because CI runs it too, with the checkout
and the usual POSIX tools and little else. A fresh runner has no `~/.claude`,
so nothing reading session transcripts or a tool's own installed files will
work there. `./scripts/check.sh --doctor` reads the install, so a block
calling it stays unmarked. A block that needs an environment belongs in its
own fence with no marker, beside the one that runs anywhere.

## Prose

Every file here is prose a human reads, so
[plugins/eng/skills/plain-writing/SKILL.md](plugins/eng/skills/plain-writing/SKILL.md)
governs this repo's own files too.

## Which file each harness reads

| Path | Read by |
|---|---|
| `AGENTS.md` | Cursor |
| `CLAUDE.md` | Claude Code, which imports `AGENTS.md` |
| `.cursor/rules/*.mdc` | Cursor |
| `.claude/rules/*.md` | Claude Code |
| `plugins/eng/skills/*/SKILL.md` | Claude Code, through the `eng` plugin. Cursor only if its import of installed Claude Code plugins brings them, which is unverified. |
| `plugins/eng/standards/workflow.md` | Claude Code, through the `eng` plugin's SessionStart hook, with `plain-writing`'s Punctuation and Word choice sections |

Anything true for both harnesses belongs in this file. The two rules
directories carry one body in each harness's own format. Both fire on
`plugins/eng/skills/**`. Cursor can also pull its copy in by description, where
the Claude rule has no equivalent.
