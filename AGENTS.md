# Agent instructions

For any agent working in this repo.

## What this repo is

A source of agent skills, not an application, shipped as one Claude Code
plugin, `eng`. There is nothing to build and no test suite. Every `SKILL.md`
loads into some other repo's session, so a change here changes how an agent
behaves everywhere.

The repo is both the plugin and the marketplace that lists it, the way
mattpocock/skills ships. `.claude-plugin/plugin.json` names the plugin and
carries its version; `.claude-plugin/marketplace.json` names the marketplace,
`mewanakoon`, and lists the one plugin with `"source": "./"`. Claude Code finds
the skills by its default scan of `skills/`. Inside the plugin each skill is
`eng:<name>`, and that full name is how skills refer to each other.

Three scripts, all bash, no build step. The commands they carry:

| Command | What it does |
|---|---|
| `./scripts/check.sh` | Checks the invariants below. CI runs this one. |
| `./scripts/check.sh --doctor` | Adds the install checks, which need a machine to inspect. Fails when anything needs fixing. |
| `./scripts/validate-plugin.sh` | Runs `claude plugin validate` and allows only the root `CLAUDE.md` warning. CI runs it on a pinned Claude Code. |
| `./link.sh --unlink` | Removes the symlinks an older install of this repo made. |
| `./link.sh` | Prints how to install the plugin instead, and exits 1. |

None of them needs a package installed beyond `jq`, which macOS 15 and the CI
runners ship, and `claude` for the validator and `--doctor`. All three resolve
their own path with `readlink -f`, and `check.sh` takes its file list from
`git`. `scripts/legacy.sh` is not run on its own: `link.sh` and `--doctor` both
source it for the old skill names and for resolving where a link points.

`package.json` carries those as `npm run check`, `doctor`, `validate`, and
`unlink`, plus `npm run lint`, which runs shellcheck over every script.
It declares no dependencies. `lint` fetches shellcheck through `npx`, pinning
the wrapper in `package.json` and the binary it downloads with
`SHELLCHECKJS_RELEASE`, because the wrapper takes the latest binary otherwise.
CI runs that same pinned pair rather than the runner image's shellcheck, which
moves on its own and disagreed with a local one about `A && B || C`.

## What belongs here

The plugin is Claude Code packaging, and Claude Code is the harness this repo
serves first. Three kinds of file travel, all plain markdown readable by any
harness, and none carrying machinery of its own:

- Skills under `skills/`, the unit most of the repo is made of.
- `standards/workflow.md`, the standing workflow every session follows. It
  names the skill for each step that has a procedure, so every skill it names
  has to exist and be model-invoked.
- Agents under `agents/`, the subagents a skill starts. An agent is written
  once and serves any harness, so its body holds every rule it follows.

The manifests sit beside these rather than inside them, so a file read outside
the plugin still reads the same.

Other plugins stay out, even when useful on the machine you are sitting at.
Recommendations of that kind live in [OPTIONAL-EXTRAS.md](OPTIONAL-EXTRAS.md),
which no session loads and nothing depends on. A procedure that only works in
one harness belongs nowhere unless it says what happens in the other.

A skill may rely on a Claude Code built-in, such as `/code-review`, when it
says what happens where the built-in is missing. Without that fallback, the
skill's step does nothing in another harness, and nothing says so.

Two exceptions, both narrow. A skill or an agent may carry a harness-specific
frontmatter field when it is a second lock over a body that is already right
without it, which is why `agents/reviewer.md` names `tools` that Cursor does
not read.
[WRITING-RULES.md](WRITING-RULES.md) under "Tool access" holds that trade and
the condition on it. And the Cursor rules file carries a `description`, which
lets Cursor pull it in by relevance where the Claude rule has no equivalent;
that one adds a way in rather than changing what either file says, so both
harnesses still get the same body on `skills/**`.

Maintenance scripts run on one machine rather than in a session, so they may
read a harness's own files: `link.sh --unlink` removes links under
`~/.claude/skills` and the other directories an older install wrote to, and
`--doctor` reads Claude Code's plugin list and settings. Both say so where they do it.

## What an agent here never does

Post a comment or a review to a pull request, whoever asks and however they
ask. Reading stays open: viewing a pull request, its diff, and its review
threads are all unaffected, and so is opening one. The rule is categorical
because the mistake is public and cannot be taken back, so anything whose
whole purpose is that step has no configuration that saves it.

## Before changing a skill

Read [WRITING-RULES.md](WRITING-RULES.md). It is the standard every file here
follows, and enforcing it is what this repo is for.

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
- Every relative markdown link in a tracked or new markdown file resolves to a
  file that exists, ignoring the ones inside fenced code blocks, which are
  templates.
- The two rules files close their frontmatter, carry a body that is not empty,
  and carry the same body. An unclosed fence reads as an empty body, and two
  empty bodies compare equal.
- Both rules files still scope themselves to `skills/**`, and the Cursor one
  still sets `alwaysApply: false`. That scoping is what decides when either
  rule loads.
- A skill carrying `allowed-tools` or `disallowed-tools` warns rather than
  fails, because whether the body holds without the field is not something a
  script can read. No skill carries one today.
- Every file under `agents/` has a `name` matching its file name and a
  `description`.
- Every description, in a skill or an agent, is one line of YAML. Unquoted, it
  is not a `>` or `|` block, holds no `: `, space or tab before `#`, colon
  before a tab, or trailing colon, and starts with no character YAML reserves.
  Quoted, it ends on its closing quote with nothing after it, and holds no
  quote or backslash inside that would end or garble it. Claude Code drops the
  whole frontmatter of a file whose YAML fails to parse.
- `standards/workflow.md` names at least one skill as "the X skill", and
  every skill named that way exists and is model-invoked.
- Size budgets, because each of these loads into someone's context. A
  model-invoked description is at most 300 bytes, and the set at most 3,900.
  `standards/workflow.md` is at most 2,500 bytes. `investigate`'s `SKILL.md` is
  at most 6,500 bytes, and `implement`, `review-diff`, and `pr-feedback` at
  most 5,000 each. Every other `SKILL.md` is at most 15,000 bytes, inside the
  20,000 characters compaction keeps of a skill. An agent file is at most 6,500
  bytes.
- `link.sh` and every `scripts/*.sh` parse under `bash -n`, because nothing
  else in the checker runs them.
- Both manifests parse. The marketplace lists exactly one plugin, under the
  name `plugin.json` gives it, with `"source": "./"`, and `plugin.json` carries
  a `MAJOR.MINOR.PATCH` version.
- When anything the plugin loads changed since the branch left `origin/main`
  (`skills/` and `plugin.json` today; `hooks/`, `standards/`, `agents/`,
  `commands/`, `output-styles/`, `themes/`, `monitors/`, `workflows/`, `bin/`,
  `.mcp.json` and `.lsp.json` once they exist),
  the version is newer than the one at that point, compared field by field.
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
in `~/.claude/skills`; and that `~/.claude/settings.json` is valid JSON and
sets `skillOverrides` for `commit` and `pr` to `"off"`. `CLAUDE_CONFIG_DIR`
moves where it looks, as it does for Claude Code. Anything to fix fails the
run, so a hook can gate on it.

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
[skills/plain-writing/SKILL.md](skills/plain-writing/SKILL.md) governs this
repo's own files too.

## Which file each harness reads

| Path | Read by |
|---|---|
| `AGENTS.md` | Cursor |
| `CLAUDE.md` | Claude Code, which imports `AGENTS.md` |
| `.cursor/rules/*.mdc` | Cursor |
| `.claude/rules/*.md` | Claude Code |
| `skills/*/SKILL.md` | Claude Code, through the `eng` plugin. Cursor only if its import of installed Claude Code plugins brings them, which is unverified. |
| `agents/*.md` | Claude Code, through the `eng` plugin, as `eng:<name>` |
| `standards/workflow.md` | Claude Code, through the `eng` plugin's SessionStart hook |

Anything true for both harnesses belongs in this file. The two rules
directories carry one body in each harness's own format. Both fire on
`skills/**`. Cursor can also pull its copy in by description, where the
Claude rule has no equivalent.
