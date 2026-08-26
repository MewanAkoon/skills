# Agent instructions

For any agent working in this repo. Cursor and Codex read this file directly.
Claude Code reads `CLAUDE.md`, which imports it.

## What this repo is

A source of agent skills, not an application. Nothing here builds and nothing
runs. Every `SKILL.md` gets loaded into some other repo's session, so a change
here changes how an agent behaves everywhere.

`link.sh` symlinks each skill directory into the global skill directory of
Claude Code, Codex, and Cursor. Skills are never copied into a working repo.

## Before changing a skill

Read [WRITING-RULES.md](WRITING-RULES.md). It is the standard every file here
follows, and enforcing it is what this repo is for.

## Invariants

These hold for every skill. `./scripts/check.sh` verifies all of them, so run
it before committing.

- The `name` in the frontmatter matches the directory name.
- A user-invoked skill sets `disable-model-invocation: true` and has an
  `agents/openai.yaml` carrying `policy.allow_implicit_invocation: false`.
- A model-invoked skill has neither the flag nor the `policy` block.
- Every skill has a row in the `README.md` table, under the heading matching
  its invocation mode.
- The model-invoked set stays at five or fewer. Adding a sixth means demoting
  one first.
- No markdown file contains an em dash.

## Prose

Every file here is prose a human reads, so
[skills/plain-writing/SKILL.md](skills/plain-writing/SKILL.md) governs this
repo's own files too. Where a sentence reaches for an em dash, rewrite it
with a comma or a full stop rather than swapping the character.

## Which file each harness reads

| Path | Read by |
|---|---|
| `AGENTS.md` | Cursor, Codex |
| `CLAUDE.md` | Claude Code |
| `.cursor/rules/*.mdc` | Cursor |
| `.claude/rules/*.md` | Claude Code |
| `skills/*/SKILL.md` | all three, through `link.sh` |
| `skills/*/agents/openai.yaml` | Codex |

Anything true for all three harnesses belongs in this file. The two rules
directories carry the same pointer in each harness's own format, and both
fire on `skills/**`. When you change one, change the other.
