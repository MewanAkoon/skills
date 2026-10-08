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

Two narrow exceptions to "plain markdown", both named in [AGENTS.md](AGENTS.md)
under "What belongs here": `review-diff` carries a Claude Code frontmatter
field as a lock over a body that is right without it, and the Cursor rules
file carries a `description` that gives it a second way in.

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
doctor: eng@mewanakoon 0.1.0 is installed and enabled, with no bare copies beside it
17 skills, 8 model-invoked
ok
```

It fails when Claude Code is older than 2.1.293, when the plugin is not
installed at user scope, is disabled, or is at another version than this clone,
when an old link or a personal copy of one of these skills is still loading, or
when the `skillOverrides` entry is missing.

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

The plugin installs under `~/.claude/plugins`, so nothing lands in a project.
Some skills write working files, such as `wayfinder` under `.scratch/`. As an
optional safety net you can ignore those globally. Check what you already have
first, because setting `core.excludesfile` replaces it:

```bash
git config --global core.excludesfile
```

If that prints a path, append to that file instead of the one below. If it
prints nothing:

```bash
printf '.claude/\n.scratch/\n.skills.json\n' >> ~/.gitignore_global
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
npx skills add <you>/skills -s tdd-node-api
```

That copies files into the current repo and needs Node. Default to the plugin
instead.

### Removing it

```bash
claude plugin uninstall eng@mewanakoon
claude plugin marketplace remove mewanakoon
```

Remove the `skillOverrides` entry too if you want Claude Code's own `commit`
and `pr` back.

## Skills

Every skill loads as `eng:<name>`. The tables link the folders.

### Model-invoked

These fire on their own when the description matches. What limits the list is
not its length, it is conflict. Several of these firing at once is fine and
often right, since `commit` shapes a commit and `plain-writing` shapes the
words in it. What costs you is two skills claiming the same decision, because
the agent picks one, reads a whole `SKILL.md`, and follows the wrong
procedure. Add a skill when nothing here would contradict it.

Three of these assume a stack, and say so in their own descriptions:
`ts-types` is TypeScript only, and `tdd-node-api` and `api-boundaries` are
written for Node services. The rest are language-neutral, though a few reach
for a TypeScript example. If you work in something else, "Taking a subset"
above leaves out the ones you do not want.

| Skill | Fires on | What it does |
|---|---|---|
| [plain-writing](skills/plain-writing/SKILL.md) | Any reply or prose being written, chat answers included | Strips AI tells, enforces plain language, gates code comments |
| [commit](skills/commit/SKILL.md) | Finished changes sitting in the working tree | Stages one change, matches the repo's message convention, survives hooks |
| [pr](skills/pr/SKILL.md) | A branch with commits ahead of its base | Resolves the base, writes title and body from the diff, creates or updates |
| [ts-types](skills/ts-types/SKILL.md) | Any `.ts` or `.tsx` file | Discriminated unions, brands, narrowing, exhaustiveness |
| [api-boundaries](skills/api-boundaries/SKILL.md) | Handlers, config, consumers, third-party calls | Validation at the edge, no guards inside |
| [tdd-node-api](skills/tdd-node-api/SKILL.md) | Test-first backend work | Seams, red-green loop, three anti-patterns |
| [merge-conflicts](skills/merge-conflicts/SKILL.md) | Unmerged paths after a merge, rebase, cherry-pick, revert, or stash pop | Traces both sides, resolves hunk by hunk, finishes the operation |
| [why](skills/why/SKILL.md) | About to delete a guard, a retry, a timeout, or an odd constant | Traces the rationale from git history, evidence apart from inference |

### User-invoked

Only fire when typed. Zero context cost.

| Skill | Invoke | What it does |
|---|---|---|
| [diagnose-bug](skills/diagnose-bug/SKILL.md) | `/eng:diagnose-bug` | Six-phase debugging loop, gated |
| [blast-radius](skills/blast-radius/SKILL.md) | `/eng:blast-radius` | What a change breaks elsewhere, with evidence levels |
| [grill-me](skills/grill-me/SKILL.md) | `/eng:grill-me` | Interview until the design has no open branches |
| [architect](skills/architect/SKILL.md) | `/eng:architect` | Types and module shape before implementation |
| [handoff](skills/handoff/SKILL.md) | `/eng:handoff` | Compact this session for the next one |
| [review-diff](skills/review-diff/SKILL.md) | `/eng:review-diff` | Diff against repo standards, plus a smell baseline |
| [how](skills/how/SKILL.md) | `/eng:how` | Subsystem walkthrough, and where new code belongs |
| [verify-app](skills/verify-app/SKILL.md) | `/eng:verify-app` | Generates a project-local skill that drives this app |
| [wayfinder](skills/wayfinder/SKILL.md) | `/eng:wayfinder` | Charts a big effort as decision tickets under `.scratch/` |

A bare form such as `/grill-me` also works while no other command has that
name.

## Writing new skills

Read [WRITING-RULES.md](WRITING-RULES.md) first. It is the standard every file
here follows.

Run the checker before committing, and the plugin validator when a manifest
changes:

```bash
./scripts/check.sh
./scripts/validate-plugin.sh
```

The checker covers the mechanical half of that standard, and
[AGENTS.md](AGENTS.md) lists what it checks. CI runs it on every pull request
and on every push to `main`, on Linux and on macOS, without `--doctor`, since
a fresh runner has no Claude Code install to inspect. CI also runs the
validator on a pinned Claude Code.

A change to anything the plugin loads needs a new `version` in
`.claude-plugin/plugin.json`, or the checker fails. Without it, nobody who
installed from GitHub would receive the change.

## Usage counts

A skill stays whether or not it fires. To see how often each one has fired,
run `/skill-doctor` in Claude Code. It lists every loaded skill with its uses,
when it last ran, and what its description costs on every turn.

Every script is also an `npm run` target, which is the only reason
`package.json` exists. It declares no dependencies.

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
