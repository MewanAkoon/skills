# skills

Agent skills as plain markdown, for Claude Code and Cursor. One clone on disk,
symlinked into the global skill directory both tools read. Nothing gets
committed into working repos.

A skill is a folder holding a `SKILL.md`: a description that decides when it
applies, and a procedure the agent follows once it does. Both tools read the
same format from the same directory, which is why one clone serves both.

## Scope

Every skill here runs the same procedure in both Claude Code and Cursor, and
anything added has to. A skill is plain markdown that either harness can read,
which is the whole reason one clone serves both. Two narrow exceptions, both
named in [AGENTS.md](AGENTS.md) under "What belongs here": the maintenance
scripts read one tool's own files, since `fired.sh` can only count what Claude
Code writes down, and `review-diff` carries a Claude Code frontmatter field as
a lock over a body that is right without it.

Tool-specific machinery stays out, plugins included.
[AGENTS.md](AGENTS.md) under "What belongs here" carries the rule and the
reason. Install what you like in your own tool:
[OPTIONAL-EXTRAS.md](OPTIONAL-EXTRAS.md) says what pairs well with each, as a
recommendation rather than a dependency.

## Setup

Clone anywhere permanent. Fork first if you plan to edit.

```bash
git clone https://github.com/MewanAkoon/skills.git
cd skills
./link.sh
```

The location is yours to pick. Every script resolves its own path, so nothing
depends on where the clone sits. Move it later and re-run `link.sh`, because
the symlinks store an absolute path.

`link.sh` symlinks every skill folder into `~/.claude/skills`. Claude Code
owns that directory and Cursor loads it too, so one destination serves both.
Because they are symlinks, editing a file here takes effect immediately, and
`git pull` updates both tools at once.

Confirm it worked:

```bash
./scripts/check.sh --doctor
```

A good run ends with the destination named and no warnings above it:

```
doctor: every skill is linked into /Users/you/.claude/skills, which Cursor loads too
17 skills, 7 model-invoked
ok
```

A missing link fails the run, so this is safe to put in a hook.

Re-run `link.sh` after adding, renaming, or removing a skill, and after moving
the clone. `--doctor` tells you when you need to.

### Keeping working repos clean

Keep the clone outside any working repo. The symlinks live under `$HOME`, so
nothing lands in a project either way.

As an optional safety net you can ignore the agent directories globally. Check
what you already have first, because setting `core.excludesfile` replaces it:

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

Adopting the repo does not mean adopting all of it. List the skills you do not
want in a `.skillsignore` at the clone root, one name per line:

```
tdd-node-api
ts-types
```

`link.sh` skips those and removes any link it previously made for them. The
files stay in the clone, so you can change your mind by deleting the line and
re-running. `--doctor` counts an ignored skill as ignored rather than missing.

### Sharing one skill with a team

Only when the team should have it too, and only from your own fork:

```bash
npx skills add <you>/skills -s tdd-node-api
```

That copies files into the current repo and needs Node, unlike everything
else here. Default to the global setup instead.

### Removing it

`link.sh` can only clean up links it can still identify, and it needs the
clone to do that. So unlink before deleting the clone:

```bash
./link.sh --unlink
```

Then delete the clone. If you deleted it first, the links are already
orphaned, and `find ~/.claude/skills -maxdepth 1 -type l ! -exec test -e {} \;
-print` lists the dangling ones for you to remove.

## Skills

### Model-invoked

These fire on their own when the description matches. What limits the list is
not its length, it is conflict. Several of these firing at once is fine and
often right, since `commit` shapes a commit and `plain-writing` shapes the
words in it. What costs you is two skills claiming the same decision, because
the agent picks one, reads a whole `SKILL.md`, and follows the wrong
procedure. Add a skill when nothing here would contradict it.

| Skill | Fires on | What it does |
|---|---|---|
| [plain-writing](skills/plain-writing/SKILL.md) | Any prose being written or edited | Strips AI tells, enforces plain language, gates code comments |
| [commit](skills/commit/SKILL.md) | Finished changes sitting in the working tree | Stages one change, matches the repo's message convention, survives hooks |
| [pr](skills/pr/SKILL.md) | A branch with commits ahead of its base | Resolves the base, writes title and body from the diff, creates or updates |
| [ts-types](skills/ts-types/SKILL.md) | Any `.ts` or `.tsx` file | Discriminated unions, brands, narrowing, exhaustiveness |
| [api-boundaries](skills/api-boundaries/SKILL.md) | Handlers, config, consumers, third-party calls | Validation at the edge, no guards inside |
| [tdd-node-api](skills/tdd-node-api/SKILL.md) | Test-first backend work | Seams, red-green loop, three anti-patterns |
| [merge-conflicts](skills/merge-conflicts/SKILL.md) | Unmerged paths after a merge, rebase, cherry-pick, revert, or stash pop | Traces both sides, resolves hunk by hunk, finishes the operation |

### User-invoked

Only fire when typed. Zero context cost.

| Skill | Invoke | What it does |
|---|---|---|
| [diagnose-bug](skills/diagnose-bug/SKILL.md) | `/diagnose-bug` | Six-phase debugging loop, gated |
| [blast-radius](skills/blast-radius/SKILL.md) | `/blast-radius` | What a change breaks elsewhere, with evidence levels |
| [grill-me](skills/grill-me/SKILL.md) | `/grill-me` | Interview until the design has no open branches |
| [architect](skills/architect/SKILL.md) | `/architect` | Types and module shape before implementation |
| [handoff](skills/handoff/SKILL.md) | `/handoff` | Compact this session for the next one |
| [review-diff](skills/review-diff/SKILL.md) | `/review-diff` | Diff against repo standards, plus a smell baseline |
| [how](skills/how/SKILL.md) | `/how` | Subsystem walkthrough, and where new code belongs |
| [why](skills/why/SKILL.md) | `/why` | Design rationale from the record, evidence apart from inference |
| [verify-app](skills/verify-app/SKILL.md) | `/verify-app` | Generates a project-local skill that drives this app |
| [wayfinder](skills/wayfinder/SKILL.md) | `/wayfinder` | Charts a big effort as decision tickets under `.scratch/` |

## Writing new skills

Read [WRITING-RULES.md](WRITING-RULES.md) first. It is the standard every file
here follows.

Run the checker before committing:

```bash
./scripts/check.sh
```

It covers the mechanical half of that standard. [AGENTS.md](AGENTS.md) lists
what it checks. CI runs the same script on every pull request and on every
push to `main`, on Linux and on macOS, without `--doctor`, since a fresh
runner has no `~/.claude` to inspect.

## Usage counts

A skill stays whether or not it fires. To see how often each one has fired:

```bash
./scripts/fired.sh
```

It reads the session transcripts Claude Code leaves under `~/.claude/projects`
and counts the times each skill was invoked. Read a zero as a question about
the skill's description or its linking, and answer it with
`./scripts/check.sh --doctor`, because an unlinked skill cannot fire. The
report says that much itself. It cannot see a skill named in
`~/.claude/CLAUDE.md`, which gets followed without being invoked, so that
skill's count reads lower than its influence.

Every script is also an `npm run` target, which is the only reason
`package.json` exists. It declares no dependencies.

## Optional extras

Plugins and anything else your tool loads alongside these skills sit outside
this repo, for the reason under "Scope" above.
[OPTIONAL-EXTRAS.md](OPTIONAL-EXTRAS.md) holds the notes: what pairs well with
Claude Code, what was found on the Cursor side, what to look at before
enabling any of it, and what was tried and dropped.

## Instructions for agents

[AGENTS.md](AGENTS.md) holds the rules for any agent working in this repo, and
its table says which file each harness reads.

## Attribution

Most skills here are adapted from two MIT-licensed repos, and each of those
names its source at the bottom. The rest were written for this repo.

- [mattpocock/skills](https://github.com/mattpocock/skills)
- [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack),
  by Lauren Tan
