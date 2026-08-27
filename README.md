# skills

My agent skills. One clone on disk, symlinked into the global skill directory
Claude Code and Cursor read. Nothing gets committed into working repos.

## Setup

Clone once, somewhere permanent:

```bash
git clone git@github.com:MewanAkoon/skills.git ~/Work/Personal/skills
cd ~/Work/Personal/skills
./link.sh
```

`link.sh` symlinks every skill folder into `~/.claude/skills`. Claude Code
owns that directory and Cursor loads it too, so one destination serves both.
Because they are symlinks, editing a file here takes effect immediately, and
`git pull` updates both tools at once. The script also drops links whose skill
has been renamed or deleted.

Re-run `link.sh` after adding, renaming, or removing a skill. To find out
whether you need to:

```bash
./scripts/check.sh --doctor
```

### Keeping working repos clean

The repo sits at `~/Work/Personal/skills`, in its own area away from client
work, and the symlinks live under `$HOME`. Nothing lands in a project. As a
safety net:

```bash
printf '.claude/\n.cursor/skills/\n.scratch/\n.skills.json\n' >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```

### Sharing one skill with a client team

Only when the team should have it too:

```bash
npx skills add MewanAkoon/skills -s tdd-node-api
```

That copies files into the current repo. Default to the global setup instead.

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
push to `main`, on Linux and on macOS, without `--doctor`, since CI has no
`$HOME` to inspect.

## Pruning

`WRITING-RULES.md` says to delete a skill that has not fired in two weeks.
To see which those are:

```bash
./scripts/fired.sh
```

It reads the session transcripts Claude Code leaves under `~/.claude/projects`
and counts the times each skill was invoked. Two caveats, both printed with
the report: an unlinked skill cannot fire, so run `--doctor` first, and a
skill named in `~/.claude/CLAUDE.md` gets followed without being invoked.

Every script is also an `npm run` target, which is the only reason
`package.json` exists. It declares no dependencies.

## Instructions for agents

[AGENTS.md](AGENTS.md) holds the rules for any agent working in this repo, and
its table says which file each harness reads.

## Attribution

Most skills here are adapted from two MIT-licensed repos, and each of those
names its source at the bottom. The rest were written for this repo.

- [mattpocock/skills](https://github.com/mattpocock/skills)
- [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack),
  by Lauren Tan
