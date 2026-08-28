# Agent instructions

For any agent working in this repo.

## What this repo is

A source of agent skills, not an application. There is nothing to build and no
test suite. Every `SKILL.md` loads into some other repo's session, so a change
here changes how an agent behaves everywhere.

Four scripts, all bash, no build step. The commands they carry:

| Command | What it does |
|---|---|
| `./scripts/check.sh` | Checks the invariants below. CI runs this one. |
| `./scripts/check.sh --doctor` | Adds the linking check, which needs a `$HOME`. |
| `./scripts/fired.sh` | Counts how often each skill has fired. |
| `./scripts/plugins.sh` | Lists the installed plugins and what they grant. |
| `./scripts/plugins.sh --descriptions` | Adds the text that competes for an invocation. |
| `./link.sh` | Links every skill into `~/.claude/skills`. |

Three of them need nothing but bash and the usual POSIX tools. `plugins.sh`
is the exception: it needs `jq`, and the `claude` CLI to say what is
installed.

`package.json` carries those as `npm run check`, `doctor`, `fired`, `plugins`,
and `link`, plus `npm run lint`, which runs shellcheck over every one of them.
It declares no dependencies. `lint` fetches a pinned shellcheck through `npx`,
and CI runs that same pinned version rather than the runner image's, which
moves on its own and disagreed with a local one about `A && B || C`.

`link.sh` symlinks each skill directory into `~/.claude/skills`, which Claude
Code owns and Cursor also loads. Skills are never copied into a working repo.

## Before changing a skill

Read [WRITING-RULES.md](WRITING-RULES.md). It is the standard every file here
follows, and enforcing it is what this repo is for.

## Before installing a plugin

Read [PLUGINS.md](PLUGINS.md). It says what a plugin brings into a session,
the checks one passes before it joins the set, and the verdicts already
reached. `./scripts/plugins.sh` answers the half of that test a machine can
answer.

## Invariants

`./scripts/check.sh` verifies these, so run it before committing.

- The `name` in the frontmatter matches the directory name, and both satisfy
  the Agent Skills spec: 1 to 64 characters, lowercase letters, digits, and
  single hyphens, with no hyphen at either end.
- The `description` is present and at most 1024 characters, which is the cap
  the spec sets.
- A user-invoked skill sets `disable-model-invocation: true`. A model-invoked
  skill omits the field.
- Every skill has a row in the `README.md` table, under the heading matching
  its invocation mode and not under the other one.
- Every `README.md` table row points at a skill that exists.
- Every relative markdown link in a tracked or new markdown file resolves to a
  file that exists, ignoring the ones inside fenced code blocks, which are
  templates.
- The two rules files carry the same body.
- Every command block whose fence reads `bash checked` runs from the repo root
  with stdin closed and exits zero.
- No markdown file contains an em dash, an en dash, or a minus sign.

What limits the model-invoked set is conflict, not count. Before adding one,
work through the test in [WRITING-RULES.md](WRITING-RULES.md) under
"Invocation". No script checks that.

`./scripts/check.sh --doctor` adds one check CI cannot run, because CI has no
`$HOME`: whether every skill in this repo is currently linked into
`~/.claude/skills`. Run it when a skill has been added, renamed, or removed,
and run `./link.sh` when it reports a gap.

## When a change makes a claim false

Behaviour and the prose describing it come apart one sentence at a time. After
changing what something does, search for every place that says what it does
and re-derive each from the new behaviour, rather than editing the sentence
nearest the change. Comments, headings, and the strings a script prints all
count, and the twin is usually in another file.

Mark a command block `bash checked` when its content can rot, and
`./scripts/check.sh` runs it. A pipeline that encodes an assumption earns the
marker. A bare script invocation does not, because there is nothing in it to
go stale.

A marked block runs in CI too, which has only the checkout and the usual
POSIX tools. No `$HOME`, no installed plugins, no `claude` CLI, and no
`~/.claude/projects` to read. A block needing any of those belongs in its own
fence with no marker, next to the one that can run anywhere.

## Prose

Every file here is prose a human reads, so
[skills/plain-writing/SKILL.md](skills/plain-writing/SKILL.md) governs this
repo's own files too.

## Which file each harness reads

| Path | Read by |
|---|---|
| `AGENTS.md` | Cursor |
| `CLAUDE.md` | Claude Code, which imports `AGENTS.md` |
| `.cursor/rules/*.mdc` | Cursor |
| `.claude/rules/*.md` | Claude Code |
| `skills/*/SKILL.md` | both, through `link.sh` |

Anything true for both harnesses belongs in this file. The two rules
directories carry one body in each harness's own format. Both fire on
`skills/**`. Cursor can also pull its copy in by description, where the
Claude rule has no equivalent.
