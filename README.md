# skills

My agent skills. One clone on disk, symlinked into Claude Code's and Cursor's
global skill directories. Nothing gets committed into working repos.

## Setup

Two steps. Both are needed on every machine.

### 1. Clone and link

```bash
git clone git@github.com:MewanAkoon/skills.git ~/Work/Personal/skills
cd ~/Work/Personal/skills
./link.sh
```

`link.sh` symlinks every skill folder into Claude Code's and Cursor's global
skill directories. Because they are symlinks, editing a file here takes effect
immediately, and `git pull` updates both tools at once. It also drops links
whose skill has been renamed or deleted.

Re-run `link.sh` after adding, renaming, or removing a skill.

### 2. Add the prose block to your global instructions

Append this to `~/.claude/CLAUDE.md`, which Claude Code loads at the start of
every session:

```markdown
# Prose
Apply the plain-writing skill (`~/.claude/skills/plain-writing/SKILL.md`) to
every piece of prose, chat replies included, before sending it.
```

A skill loads when something triggers it. Writing a commit message is a
trigger, so `plain-writing` reaches commit messages and PR bodies from step 1
alone. A plain chat reply is not a trigger, so nothing guarantees the
description is consulted on that turn. This block is what closes that gap.

Its own rules stay in `SKILL.md`, one copy. The block says only the thing the
skill cannot make true about itself, that it always applies.

### Keeping working repos clean

The repo sits at `~/Work/Personal/skills`, in its own area away from client
work, and the symlinks live under `$HOME`. Nothing lands in a project. As a
safety net:

```bash
printf '.claude/\n.cursor/skills/\n.skills.json\n' >> ~/.gitignore_global
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

These fire on their own when the description matches. Their descriptions sit
in context on every turn, so keep this list short.

| Skill | Fires on | What it does |
|---|---|---|
| [plain-writing](skills/plain-writing/SKILL.md) | Any prose being written or edited | Strips AI tells, enforces plain language |
| [ts-types](skills/ts-types/SKILL.md) | Any `.ts` or `.tsx` file | Discriminated unions, brands, narrowing, exhaustiveness |
| [api-boundaries](skills/api-boundaries/SKILL.md) | Handlers, config, consumers, third-party calls | Validation at the edge, no guards inside |
| [tdd-node-api](skills/tdd-node-api/SKILL.md) | Test-first backend work | Seams, red-green loop, three anti-patterns |

### User-invoked

Only fire when typed. Zero context cost.

| Skill | Invoke | What it does |
|---|---|---|
| [diagnose-bug](skills/diagnose-bug/SKILL.md) | `/diagnose-bug` | Six-phase debugging loop, gated |
| [blast-radius](skills/blast-radius/SKILL.md) | `/blast-radius` | What a change breaks elsewhere, with evidence levels |
| [grill-me](skills/grill-me/SKILL.md) | `/grill-me` | Interview until the design has no open branches |
| [architect](skills/architect/SKILL.md) | `/architect` | Types and module shape before implementation |
| [handoff](skills/handoff/SKILL.md) | `/handoff` | Compact this session for the next one |

## Writing new skills

Read [WRITING-RULES.md](WRITING-RULES.md) first. It is the standard every file
here follows.

Run `./check.sh` before committing. It needs `python3`, which ships with macOS.
It enforces items 1 to 9 of the list at the end of `WRITING-RULES.md`, which is
the mechanical half, and it derives its banned-word list from
`plain-writing/SKILL.md` so the two cannot drift apart. Items 10 to 13 are
judgement calls no script can make, and they are the ones that decide whether a
skill actually fires.

## Attribution

Skills here are adapted from two MIT-licensed repos. Each `SKILL.md` names its
source on the last line, and files under `references/` inherit it.

- [mattpocock/skills](https://github.com/mattpocock/skills)
- [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack),
  by Lauren Tan
