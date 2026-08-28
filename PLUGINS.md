# Plugins

A plugin ships skills, agents, commands, MCP servers and hooks into the same
session these skills load into. It changes agent behaviour without a commit to
this repo, and it arrives as someone else's judgement about what an agent
should do, so it gets the scrutiny a skill here gets.

## The roster is not in this file

`./scripts/plugins.sh` prints it, read from what is installed rather than from
a list someone remembered to update. It answers the mechanical half of the
test below: what each plugin costs on every turn, which components run without
a prompt, which reach further while carrying no description at all, which are
bounded by a tool list, and which share a name with a skill here.

A roster written into this file would be wrong by the next install, and no
check could catch it, because CI has neither plugins nor a `$HOME`.

## Before installing one

Install nothing on the strength of its README. Adding a marketplace, the first
command under "Installing and removing" below, clones every plugin in it,
installed or not, so the files are readable before anything is enabled:

```bash
ls ~/.claude/plugins/marketplaces/<marketplace>/plugins/<name>/
```

A plugin the marketplace only points at, rather than holding itself, sits
under `external_plugins/` alongside that `plugins/` directory.

Read the files, then work through these in order. The first check it fails is
the answer.

### 1. What does it run at the end?

List the parts, then read the last step of every file under `commands/` and
`skills/`. A plugin is judged on its terminal action, not on the sentence
describing it.

`code-review` failed here. The last step of its `commands/code-review.md`
posts the result with `gh pr comment`. Posting is what that command is for
rather than a side effect of it, and the rule it runs into is categorical:
nothing here posts a comment or a review to a pull request, whoever asks and
however they ask. A plugin whose purpose is the forbidden step has no
configuration that saves it.

### 2. Does it grant itself tools?

`allowed-tools` in a component's frontmatter pre-approves the tools it names
for the turn that invokes it, so they run with no prompt. It grants and never
restricts, which [WRITING-RULES.md](WRITING-RULES.md) covers under "Tool
access". A grant naming a command that a rule forbids defeats the rule without
looking like it does.

`./scripts/plugins.sh` prints every grant in the installed set.

### 3. Does it re-cover something already here?

What competes is the `description` in a component's frontmatter, not the
summary a table carries, so read the real ones side by side:

```bash checked
grep -L '^disable-model-invocation: true' skills/*/SKILL.md | xargs -r grep -h '^description:'
./scripts/plugins.sh --descriptions
```

The first is what this repo loads, the second what the installed plugins load,
because a candidate can collide with another plugin as easily as with a skill.
Both commands drop what a model cannot reach on its own, which is why the
first one filters rather than reading every file: a user-invoked component
competes with nothing until someone types its name. The candidate's own are in
the marketplace clone you opened for check 1.

Two components compete when they claim the same decision and the agent has to
pick one, which is the test in [WRITING-RULES.md](WRITING-RULES.md) under
"Invocation". Composing is fine. Competing is not, because the agent reads a
whole file and then follows the wrong procedure.

`superpowers` failed here. Its descriptions rode every turn to re-cover six
skills that exist here already, written for this work rather than in general.

### 4. Is it safe by construction or only by instruction?

An agent that names a `tools` list cannot reach past it, whatever its prose
says. Prefer that to a plugin promising restraint in a paragraph.

`feature-dev` passed here. Its `code-reviewer` names no `Bash` and no `Edit`,
so it cannot write a file or run a command. That is a property of the file
rather than a promise inside it.

### 5. What does it cost while doing nothing?

Every description in a listing rides every turn of every conversation, whether
or not the plugin runs. `./scripts/plugins.sh` prints a figure per plugin and
one for the set, so a candidate can be weighed against what is already being
paid for. It counts descriptions and nothing else. An MCP server loads its
tool schemas on every turn, so a plugin carrying one costs more than its
figure says. A hook costs only what it prints when its event fires, which is
often nothing. The script names both rather than pricing either. A plugin
earning its place one session a month rarely earns a permanent line in the
prompt.

## Decisions on record

A decision stays true after the thing it was about is gone, which is why these
are written down and the roster is not. Add a line rather than editing one
when a verdict changes, so a plugin can appear under more than one heading.
The entry further down the file is the standing one.

"Installed but not yet judged" is the exception, and the one heading entries
leave: judging a plugin is what empties it.

### Kept

- **`feature-dev`.** Its three agents each name a `tools` list holding no
  `Bash` and no `Edit`, so none of them writes a file or runs a command.
  Check 4.
- **`frontend-design`.** One skill, and nothing here claims the same decision.
  Check 3.
- **`typescript-lsp`.** No skill, agent or command at all, so it costs nothing
  on a turn. It needs a global `typescript-language-server` and a `typescript`
  on the 5.x line, because TypeScript 7 is the native port and ships no
  `tsserver.js`.

### Installed but not yet judged

Enabled before this test existed, so neither passed nor failed it. They sit
here rather than under "Kept", because a verdict nobody reached is not a
verdict.

- **`claude-md-management`.** `revise-claude-md` grants itself `Read, Edit,
  Glob`, which is check 2 exactly, so it edits files with no prompt. Decide
  whether editing `CLAUDE.md` unprompted is wanted before this moves.
- **`claude-code-setup`.** One skill, and no grant. Owes only check 3, read
  against the skills here.

### Removed, 2026-08-28

- **`code-review`.** Its terminal step posts to a pull request, and its
  frontmatter pre-approves the command that does it. Failed checks 1 and 2.
- **`superpowers`.** Always-on cost re-covering six skills that already exist
  here. Failed check 3.
- **`github`.** Installed but never configured, so every call returned 401. It
  duplicated an already authenticated `gh`, and its own tools reach the same
  endpoint check 1 rules out, by a route harder to spot than a shell command.
- **`context7`.** The connector on the claude.ai account covers the same
  ground, and it was verified answering before the plugin went.

## Installing and removing

```bash
claude plugin marketplace add <owner>/<repo>
claude plugin install <name>@<marketplace>
claude plugin uninstall <name>@<marketplace>
claude plugin list --json
```

Add the marketplace first. Installing before that reports "Plugin not found in
marketplace", which names the wrong cause and costs a round trip.

Uninstalling leaves the plugin's files under
`~/.claude/plugins/cache/<marketplace>/<name>/`. They cost nothing on a turn
and they make a reinstall quick. Delete one when you are sure the plugin is
not coming back.

The desktop app reads the same `~/.claude` the CLI does, so a plugin enabled
from either shows up in both, and a change to the enabled set needs a restart.
