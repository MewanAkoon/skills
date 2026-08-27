# Agent instructions

For any agent working in this repo.

## What this repo is

A source of agent skills, not an application. There is nothing to build and no
test suite, only `./scripts/check.sh`. Every `SKILL.md` loads into some other
repo's session, so a change here changes how an agent behaves everywhere.

`link.sh` symlinks each skill directory into the global skill directory of
Claude Code, Codex, and Cursor. Skills are never copied into a working repo.

## Before changing a skill

Read [WRITING-RULES.md](WRITING-RULES.md). It is the standard every file here
follows, and enforcing it is what this repo is for.

## Invariants

`./scripts/check.sh` verifies these, so run it before committing.

- The `name` in the frontmatter matches the directory name.
- A user-invoked skill sets `disable-model-invocation: true` and has an
  `agents/openai.yaml` carrying `policy.allow_implicit_invocation: false`.
- A model-invoked skill has neither the flag nor the `policy` block.
- Every skill has a row in the `README.md` table, under the heading matching
  its invocation mode and not under the other one.
- Every `README.md` table row points at a skill that exists.
- The two rules files carry the same body.
- No markdown file contains an em dash.

What limits the model-invoked set is conflict, not count. Before adding one,
work through the test in [WRITING-RULES.md](WRITING-RULES.md) under
"Invocation". No script checks that.

## Prose

Every file here is prose a human reads, so
[skills/plain-writing/SKILL.md](skills/plain-writing/SKILL.md) governs this
repo's own files too.

## Which file each harness reads

| Path | Read by |
|---|---|
| `AGENTS.md` | Cursor, Codex |
| `CLAUDE.md` | Claude Code, which imports `AGENTS.md` |
| `.cursor/rules/*.mdc` | Cursor |
| `.claude/rules/*.md` | Claude Code |
| `skills/*/SKILL.md` | all three, through `link.sh` |
| `skills/*/agents/openai.yaml` | Codex |

Anything true for all three harnesses belongs in this file. The two rules
directories carry one body in each harness's own format, and both fire on
`skills/**`.
