# skills

My agent skills. One clone on disk, symlinked into every AI tool's global
skill directory. Nothing gets committed into working repos.

## Setup

Clone once, somewhere permanent:

```bash
git clone git@github.com:MewanAkoon/skills.git ~/Work/Personal/skills
cd ~/Work/Personal/skills
./link.sh
```

`link.sh` symlinks every skill folder into each agent's global skill
directory. Because they are symlinks, editing a file here takes effect
immediately, and `git pull` updates every tool at once.

Re-run `link.sh` only after adding or renaming a skill.

### Keeping working repos clean

The repo sits at `~/Work/Personal/skills`, in its own area away from client
work, and the symlinks live under `$HOME`. Nothing lands in a project. As a
safety net:

```bash
printf '.claude/\n.cursor/skills/\n.agents/\n.scratch/\n.skills.json\n' >> ~/.gitignore_global
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
| [why](skills/why/SKILL.md) | `/why` | Design rationale from git history and the rest of the record, evidence kept apart from inference |
| [verify-app](skills/verify-app/SKILL.md) | `/verify-app` | Generates a project-local skill that drives this app |
| [wayfinder](skills/wayfinder/SKILL.md) | `/wayfinder` | Charts a big effort as decision tickets under `.scratch/` |

## Writing new skills

Read [WRITING-RULES.md](WRITING-RULES.md) first. It is the standard every file
here follows.

## Attribution

Skills here are adapted from two MIT-licensed repos. Each file names its
source at the bottom.

- [mattpocock/skills](https://github.com/mattpocock/skills)
- [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack),
  by Lauren Tan
