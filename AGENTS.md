# Agent instructions

For any agent working in this repo.

## What this repo is

A source of agent skills, shipped as one Claude Code plugin, `eng`. There is
nothing to build. Every `SKILL.md` loads into some other repo's session, so a
change here changes how an agent behaves everywhere.

The repo is the marketplace, `mewanakoon`, and the plugin is one folder in it,
`plugins/eng/`, so an install copies that folder and nothing else.
`plugins/eng/.claude-plugin/plugin.json` names the plugin and carries its
version, beside its `icon.png`. `.claude-plugin/marketplace.json` lists the one
plugin with `"source": "./plugins/eng"`. Inside the plugin each skill is
`eng:<name>`, and that full name is how skills refer to each other.

The scripts are bash and need only `jq` and `git`, plus `claude` for the
validator and `--doctor`. The oldest Claude Code supported is 2.1.293, set as
`cc_min` in `scripts/check.sh`.

- `./scripts/check.sh` checks the invariants and runs `test-hooks.sh`,
  `test-checks.sh` and `test-cloud-setup.sh`. CI runs it.
- `./scripts/check.sh --doctor` adds the checks of this machine's install.
- `./scripts/validate-plugin.sh` runs `claude plugin validate`. CI runs it
  on a pinned Claude Code.
- `npm run lint` runs a pinned shellcheck over every shell script.
- `scripts/cloud-setup.sh` is pasted in at claude.ai as a cloud
  environment's setup script, not run here.

[CONTRIBUTING.md](CONTRIBUTING.md) has the rest of working here.

## What belongs here

Three kinds of file travel with the plugin, all plain markdown any harness can
read:

- Skills under `plugins/eng/skills/`.
- `plugins/eng/standards/workflow.md`, the standing workflow every session
  follows. Every skill it names as "the X skill" exists and is model-invoked.
- `plugins/eng/standards/dependencies.md`, the one list of tools outside the
  plugin that the skills need, with a check and an install command for each.

A dependency is something a skill needs to work as written, and goes in
`dependencies.md`. An optional extra pairs well but nothing needs it, and goes
in [OPTIONAL-EXTRAS.md](OPTIONAL-EXTRAS.md), which nothing loads.

The manifests and `plugins/eng/hooks/` are Claude Code packaging. The session
hook sends `workflow.md` and `plain-writing`'s Punctuation and Word choice
sections, read at run time, and on a new session shows you what the machine
is missing, from `hooks/setup-check`. What the other hooks decide is in the
header of `plugins/eng/hooks/eng-hook`, which the README's guarantee table
follows. Where no hook runs, the session reads an approval by the rule in
`plugins/eng/skills/implement/references/deliver.md`.

Other plugins stay out. A procedure that works in only one harness, or leans
on a Claude Code built-in such as `/code-review`, says what happens without
it. Two narrow exceptions: a harness-specific frontmatter field as a second
lock over a body already right without it, as
[WRITING-RULES.md](WRITING-RULES.md) says under "Tool access", which no skill
takes today; and the Cursor rules file's `description`, which adds a way in
without changing what it says. Maintenance scripts may read a harness's own
files, and each says so where it does.

## What an agent here never does

Post a comment or a review to a pull request, whoever asks and however they
ask. Reading stays open, and so does opening a pull request. The rule is
categorical because the mistake is public and cannot be taken back.

Every other comment, review or reply is drafted to a file too, a comment on a
Linear issue included.

## Before changing a skill

Read [WRITING-RULES.md](WRITING-RULES.md). It is the standard every file here
follows. Before adding a model-invoked skill, work through its "Invocation"
test, which no script checks. A model-invoked skill that stays quiet on an
install that checks out is demoted to user-invoked, not deleted, as its
"Keeping skills" section says.

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
- The repo has no pull request template, so `eng:pr` uses its own body. The
  last line of its What and why section is a paragraph of its own:
  `Fixes SKI-N` when merging finishes the issue, or `Part of SKI-N` when more
  pull requests follow, whose branch name then leaves `ski-N` out, unless
  the issue splits into sub-issues that each take `Fixes`.
- A Linear issue never names a pull request by number.
- Story points are 1, 2, 3, 5 or 8.

## Versions and releases

Installs follow the `stable` branch, and Claude Code updates an install only
when `version` in `plugins/eng/.claude-plugin/plugin.json` changes.

- A pull request leaves `version` alone and adds its entry under
  `## Unreleased` at the top of `CHANGELOG.md`.
- A release moves those entries under the new version and its date, bumps
  `version`, tags the commit on `main` as `vX.Y.Z`, and fast-forwards
  `stable` to it. `stable` moves no other way, and never by a force push.
- The merge, the tag and the push to `stable` each wait for the user's own
  message. The hook does not read a push to `stable` as a release.

## Checks

`./scripts/check.sh` holds the invariants, and each check's comment says what
it holds and why. Run it before committing. Two limits shape writing: a
model-invoked description is at most 300 bytes and the set at most 3,900,
because each rides every turn; `workflow.md` is at most 3,000 bytes and the
block the session hook sends at most 5,000, because both load in every
session. Every other `SKILL.md` and reference file stays under 15,000 bytes.

## When a change makes a claim false

Behaviour and the prose describing it come apart one sentence at a time. After
changing what something does, search for every place that says what it does
and re-derive each from the new behaviour, rather than editing the sentence
nearest the change. Comments, headings, and the strings a script prints all
count, and the twin is usually in another file.

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
| `plugins/eng/skills/*/SKILL.md` | Claude Code, through the `eng` plugin. Cursor only if its import of installed Claude Code plugins brings them, which is not settled. |
| `plugins/eng/standards/workflow.md` | Claude Code, through the plugin's SessionStart hook, with `plain-writing`'s Punctuation and Word choice sections |
| `plugins/eng/standards/dependencies.md` | The plugin's `hooks/setup-check`, at session start and from `--doctor`. No model reads it. |

Anything true for both harnesses belongs here. The two rules files carry one
body, and both fire on `plugins/eng/skills/**`.
