# skills

Agent skills as plain markdown, shipped as one Claude Code plugin, `eng`, from
this repo. Install it once and every skill loads in every session, under its
full name: `eng:commit`, `eng:pr`, `eng:why`, and so on. Nothing gets committed
into working repos.

A skill is a folder holding a `SKILL.md`: a description that decides when it
applies, and a procedure the agent follows once it does. The plugin is that
folder of skills plus two small manifests in `.claude-plugin/`, which is the
packaging the Claude Code docs describe and the one
[mattpocock/skills](https://github.com/mattpocock/skills) uses.

## Scope

Claude Code first. The skills themselves stay plain markdown that any harness
can read, but the way they ship, the plugin and its manifests, is Claude Code
packaging. Cursor support comes later; "If you use Cursor" below says where it
stands.

One other file ships the same way:
[standards/workflow.md](standards/workflow.md), the standing workflow every
session follows. A SessionStart hook in the plugin sends it, with
`plain-writing`'s core rules, at the start of every session and again after
each compaction. The hook is Claude Code packaging, like the manifests.

One narrow exception to "plain markdown", named in [AGENTS.md](AGENTS.md)
under "What belongs here": the Cursor rules file carries a `description` that
gives it a second way in.

Other plugins stay out of this one. [OPTIONAL-EXTRAS.md](OPTIONAL-EXTRAS.md)
says what pairs well with it, as a recommendation rather than a dependency.

## Setup

You need Claude Code 2.1.293 or later. In any Claude Code session:

```
/plugin marketplace add MewanAkoon/skills
/plugin install eng@mewanakoon
```

Or from a shell:

```bash
claude plugin marketplace add MewanAkoon/skills
claude plugin install eng@mewanakoon
```

Both install at user scope, so the skills load in every project on the
machine. There is no clone to keep and no script to run.

Then turn off the bare copies of two skills. A project may carry its own
`commit` and `pr` skills, and those load beside the plugin's today and can take
a request meant for it. Claude Code also reserves both names for built-in
skills it keeps switched off for now and can switch on. Add this to
`~/.claude/settings.json`:

```json
{
  "skillOverrides": {
    "commit": "off",
    "pr": "off"
  }
}
```

`skillOverrides` hides a skill by name from you and the model alike, for this
machine only, and never touches plugin skills. So `eng:commit` and `eng:pr`
stay, and a team repo's own `commit` and `pr` stay for everyone else.

To confirm it worked from a clone of this repo:

```bash
./scripts/check.sh --doctor
```

A good run ends like this:

```
doctor: eng@mewanakoon <version> is installed and enabled, with no bare copies beside it
15 skills, 12 model-invoked
ok
```

It fails when Claude Code is older than 2.1.293, when the plugin is not
installed at user scope, is disabled, or is at another version than this clone,
when an old link or a personal copy of one of these skills is still loading,
when the `skillOverrides` entry is missing, or when the plugin's session hook
has logged an error.

### Updating

Claude Code leaves auto-update off for marketplaces outside Anthropic's. Turn
it on once in `/plugin`, under Marketplaces, or update by hand:

```bash
claude plugin update eng@mewanakoon
```

A release is a new `version` in `.claude-plugin/plugin.json`. An install stays
on the version it has until that string changes.

### Moving from the old symlinks

Before the plugin, `link.sh` symlinked each skill into `~/.claude/skills`.
Those links are personal skills with bare names, and they would load beside
the plugin's copies. From the clone:

1. Run `./link.sh --unlink`. It removes the links this clone made and leaves
   anything else alone. If you linked with `SKILLS_DEST` set, run it with the
   same value. A `.skillsignore` in the clone no longer does anything, so
   delete it.
2. Install the plugin and add the `skillOverrides` entry, as above.
3. If your `~/.claude/CLAUDE.md`, or a hook of yours, names a path under
   `~/.claude/skills`, point it at the skill's full name instead, such as
   `eng:plain-writing`. Those paths no longer exist.
4. Run `./scripts/check.sh --doctor`.

### Working on this repo

Add your clone as the marketplace instead of the GitHub one:

```
/plugin marketplace add ~/path/to/skills
/plugin install eng@mewanakoon
```

Both sources are named `mewanakoon`, so if you added the GitHub one first,
this repoints it at your clone, and the plugin you installed updates from the
clone from then on. Claude Code prints how to undo that.

A directory marketplace loads the plugin from the folder itself, so an edit
shows up after `/reload-plugins`. To try the working tree for one session
without installing anything:

```bash
claude --plugin-dir .
```

### If you use Cursor

Cursor reads skills from `~/.claude/skills`, which the plugin no longer fills.
Cursor's changelog says it also imports plugins installed in Claude Code while
**Settings, Agents, Third-Party Imports** is on, which would bring these
skills with it. That is not yet confirmed for this plugin. A skill folder
copied into `~/.cursor/skills` works too, with one catch: the skills name each
other and their commands with the plugin's prefix, `eng:commit` and
`/eng:commit`, which Cursor does not have. Drop the `eng:` prefix in a copy you
make for Cursor.

### Keeping working repos clean

The plugin itself installs under `~/.claude/plugins`, outside every project.
Some skills write working files: `investigate` and `wayfinder` under
`.claude/plans/`, and `handoff` under `.claude/handoffs/`. `eng:commit` leaves
them out unless you name them. As an optional safety net you can ignore them
globally. Check what you already have first, because setting `core.excludesfile`
replaces it:

```bash
git config --global core.excludesfile
```

If that prints a path, append to that file instead of the one below. If it
prints nothing:

```bash
printf '.claude/\n.skills.json\n' >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```

Ignoring `.claude/` applies to every repo you touch, including teams that
commit `.claude/settings.json` on purpose. Skip this step if that is you.

### Taking a subset

A plugin installs as a unit, and it loads every folder under `skills/`. To
take part of it, fork the repo, delete the skill folders you do not want along
with their README rows, and install from your fork. `./scripts/check.sh` names
anything left pointing at a skill you removed. Listing skills in `plugin.json`
does not narrow the set, because that field adds to the `skills/` scan rather
than replacing it.

### Sharing one skill with a team

Only when the team should have it too, and only from your own fork:

```bash
npx skills add <you>/skills -s why
```

That copies files into the current repo and needs Node. Default to the plugin
instead. The copy is a project skill without the plugin's prefix, so change its
`eng:` names to bare ones, `/eng:why` to `/why`, as for Cursor above.

### Removing it

```bash
claude plugin uninstall eng@mewanakoon
claude plugin marketplace remove mewanakoon
```

Remove the `skillOverrides` entry too if you want Claude Code's own `commit`
and `pr` back.

## The workflow

[standards/workflow.md](standards/workflow.md) is eight standing steps:
understand first, plan and stop, implement on approval, review until clean,
commit and open PRs only when asked, handle PR feedback on evidence, never
post, and report briefly. The plugin's SessionStart hook sends it at the start
of every session and after each compaction. It names the skill for each step
that has a procedure, so a change of phase is the cue to load it:

| Step | Skill |
|---|---|
| 1 and 2, understand and plan | `eng:investigate` |
| 3, implement | `eng:implement` |
| 4, review | `eng:implement`'s review loop, through the built-in `/code-review` |
| 5, writes outside this machine | `eng:commit`, `eng:pr`, `eng:issue` |
| 6, PR feedback | `eng:pr-feedback` |

The other skills hold knowledge a phase reaches for, or are modes you start
yourself.

## Skills

Every skill loads as `eng:<name>`. The tables link the folders.

### Model-invoked

These fire on their own when the description matches. What limits the list is
not its length, it is conflict. Several of these firing at once is fine and
often right, since `commit` shapes a commit and `plain-writing` shapes the
words in it. What costs you is two skills claiming the same decision, because
the agent picks one, reads a whole `SKILL.md`, and follows the wrong
procedure. Add a skill when nothing here would contradict it.

Two of these assume a stack, and say so in their own descriptions:
`ts-types` is TypeScript only, and `api-boundaries` is written for Node
services. The rest are language-neutral, though a few reach
for a TypeScript example. If you work in something else, "Taking a subset"
above leaves out the ones you do not want.

| Skill | Fires on | What it does |
|---|---|---|
| [investigate](skills/investigate/SKILL.md) | A ticket, thread, issue, error or log, bug report, or question about the code | Reads the sources and the code, checks the findings, ends with a plan and stops |
| [implement](skills/implement/SKILL.md) | An approved plan, or a request that names the exact change | Makes the change test-first in the repo's patterns, corrects docs it makes false, reviews it through `/code-review` |
| [pr-feedback](skills/pr-feedback/SKILL.md) | A PR comment link, or a request to address review feedback | Judges each comment on evidence, fixes the valid ones, drafts replies to a file |
| [plain-writing](skills/plain-writing/SKILL.md) | Prose that outlives the chat, such as a doc, a commit message, a PR or issue body, or a long reply | Strips AI tells, enforces plain language, gates code comments. Its core reaches every session through the hook |
| [commit](skills/commit/SKILL.md) | A message asking to commit or push | Stages one change, matches the repo's message convention, survives hooks |
| [pr](skills/pr/SKILL.md) | A message asking to open or update a PR | Resolves the base, writes title and body from the diff, creates or updates |
| [issue](skills/issue/SKILL.md) | A message asking to draft, file, edit, label, or close an issue | Drafts from the repo's template and labels to a file, files only when asked |
| [ts-types](skills/ts-types/SKILL.md) | Any `.ts` or `.tsx` file, a type error, or a diff adding `any` or a cast | Discriminated unions, brands, narrowing, exhaustiveness |
| [api-boundaries](skills/api-boundaries/SKILL.md) | Handlers, middleware, config, consumers, third-party calls, or where a check belongs | Validation at the edge, no guards inside |
| [merge-conflicts](skills/merge-conflicts/SKILL.md) | Unmerged paths or conflict markers, when your latest message asks to resolve them, reports them, or asks for that operation | Traces both sides, resolves hunk by hunk, finishes the operation |
| [why](skills/why/SKILL.md) | Removing or rewriting a guard, retry, timeout, special case, odd constant, or redundant-looking code, or asking why code is shaped the way it is | Traces the rationale from git history, evidence apart from inference |
| [blast-radius](skills/blast-radius/SKILL.md) | Planning a change to something shared, or a question about what a change breaks | What a change breaks elsewhere, with evidence levels |

### User-invoked

Only fire when typed. Zero context cost.

| Skill | Invoke | What it does |
|---|---|---|
| [grill-me](skills/grill-me/SKILL.md) | `/eng:grill-me` | Interview until the design has no open branches |
| [handoff](skills/handoff/SKILL.md) | `/eng:handoff` | Compact this session for the next one |
| [wayfinder](skills/wayfinder/SKILL.md) | `/eng:wayfinder` | Charts a big effort as decision tickets under `.claude/plans/` |

To see a change working in the running app, Claude Code's built-in `/verify`
runs it, `/run` drives it, and `/run-skill-generator` writes the per-project
skill both follow.

Type the full name. A bare name is not sure to reach the plugin's skill:
`commit` and `pr` are names Claude Code keeps for skills of its own.

## Writing new skills

Read [WRITING-RULES.md](WRITING-RULES.md) first. It is the standard every file
here follows.

Run the checker before committing, and the plugin validator when a manifest
changes. Run the validator on the same pinned Claude Code as CI, because its
rules change between releases:

```bash
./scripts/check.sh
CLAUDE_BIN="npx --yes @anthropic-ai/claude-code@2.1.293" ./scripts/validate-plugin.sh
```

Without `CLAUDE_BIN` it uses the `claude` on your PATH, which may disagree
with CI.

The checker covers the mechanical half of that standard, and
[AGENTS.md](AGENTS.md) lists what it checks. CI runs it on every pull request
and on every push to `main`, on Linux and on macOS, without `--doctor`, since
a fresh runner has no Claude Code install to inspect. The checker also runs
`./scripts/test-hooks.sh`, which feeds the session hook its inputs and checks
what it sends. CI also runs the validator on a pinned Claude Code.

A change to anything the plugin loads needs a new `version` in
`.claude-plugin/plugin.json`, or the checker fails. Without it, nobody who
installed from GitHub would receive the change. Bump past whatever `main`
carries when you merge: CI checks `main` again after each push, so two pull
requests that picked the same version fail there.

### Evals

`evals/` holds cases for `claude plugin eval`: each workflow skill loads at its
moment, `eng:issue` stays out of "look into issue 42", the contract is in
context at the start, and looking into a repo commits nothing. Every run is a
model call on your account, so they stay out of CI. Run them before a release:

```bash
claude plugin eval . --ablation none --runs 1 --scaffold --allow-tools Bash \
  --no-publish --max-cost-usd 2
```

`--scaffold` builds the scratch repo one case needs. Bash is a gated tool, so a
case gets it only when it lists Bash in `allowed_tools` and the run passes
`--allow-tools Bash`; the case that forbids `git commit` does both.

The eval sandbox blocks `git`, so the review loop is checked by hand. In an
empty directory, run `tests/review-loop/setup.sh` from the clone, then:

```bash
claude -p "The plan in PLAN.md is approved. Implement it." \
  --plugin-dir <clone> --allowedTools "Read Glob Grep Edit Write Bash Skill Agent" \
  --output-format stream-json --verbose
```

A good run calls `code-review` with `medium` and a `<hash>..<hash>` range,
briefs the intent check beside it, and commits nothing.

## Usage counts

A skill stays whether or not it fires. To see how often each one has fired,
run `/skill-doctor` in Claude Code. It lists every loaded skill with its uses,
when it last ran, and what its description costs on every turn.

Every script you run while working here is also an `npm run` target, which is
the only reason `package.json` exists. It declares no dependencies.
`scripts/legacy.sh` has none, because `link.sh` and `--doctor` load it, and
neither do the setup scripts under `tests/` and `evals/`, which build scratch
repos for one check each.

## Optional extras

Other plugins, and anything else your tool loads alongside these skills, sit
outside this repo. [OPTIONAL-EXTRAS.md](OPTIONAL-EXTRAS.md) holds the notes:
what pairs well with Claude Code, what was found on the Cursor side, what to
look at before enabling any of it, and what was tried and dropped.

## Instructions for agents

[AGENTS.md](AGENTS.md) holds the rules for any agent working in this repo, and
its table says which file each harness reads.

## Attribution

Most skills here are adapted from two MIT-licensed repos, and each of those
names its source at the bottom. The rest were written for this repo.

- [mattpocock/skills](https://github.com/mattpocock/skills)
- [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack),
  by Lauren Tan
