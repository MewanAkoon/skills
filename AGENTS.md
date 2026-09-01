# Agent instructions

For any agent working in this repo.

## What this repo is

A source of agent skills, not an application. There is nothing to build and no
test suite. Every `SKILL.md` loads into some other repo's session, so a change
here changes how an agent behaves everywhere.

Three scripts, all bash, no build step. The commands they carry:

| Command | What it does |
|---|---|
| `./scripts/check.sh` | Checks the invariants below. CI runs this one. |
| `./scripts/check.sh --doctor` | Adds the linking check, which needs a destination to inspect. Fails when a link is missing. |
| `./scripts/fired.sh` | Counts how often each skill has fired. |
| `./link.sh` | Links the skills into the destination, minus anything in `.skillsignore`. |
| `./link.sh --unlink` | Removes the links this clone made, leaving the clone. |

None of them needs a package installed. All three resolve their own path
with `readlink -f`, and `check.sh` takes its file list from `git`, so those
two are the requirements beyond bash and the usual POSIX tools.

`package.json` carries those as `npm run check`, `doctor`, `fired`, and
`link`, plus `npm run lint`, which runs shellcheck over every one of them.
It declares no dependencies. `lint` fetches shellcheck through `npx`, pinning
the wrapper in `package.json` and the binary it downloads with
`SHELLCHECKJS_RELEASE`, because the wrapper takes the latest binary otherwise.
CI runs that same pinned pair rather than the runner image's shellcheck, which
moves on its own and disagreed with a local one about `A && B || C`.

`link.sh` symlinks each skill directory into `~/.claude/skills`, which Claude
Code owns and Cursor also loads, as
[Cursor's skills documentation](https://cursor.com/docs/skills) states. Skills
are never copied into a working repo. `SKILLS_DEST` overrides the destination,
and `check.sh --doctor` reads the same variable, so the two agree on where the
links belong.

A skill named in an optional `.skillsignore` at the clone root is not linked,
and a link this clone made for one is removed. The file lets someone take a
subset without deleting anything, so it is what a fork adjusts rather than the
skill list. `link.sh` removes only links it created, which are the ones named
after a skill directory here, and reports anything it leaves alone.

## What belongs here

Everything this repo ships loads into both Claude Code and Cursor, so anything
added has to work in both. The skill is the unit that travels: plain markdown
under `skills/`, read by whichever harness picked it up, carrying no machinery
of its own.

Tool-specific machinery stays out, even when it is useful on the machine you
are sitting at. A Claude Code plugin and a Cursor plugin are different
artifacts, installed from different marketplaces into different directories,
and the two trees do not overlap. Adopting either would serve one harness and
be dead weight in the other. Recommendations of that kind live in
[OPTIONAL-EXTRAS.md](OPTIONAL-EXTRAS.md), which no session loads and nothing
depends on. Anything that would make a skill run its procedure in one harness
and not the other belongs there instead, or nowhere.

Three exceptions, all narrow. A maintenance script runs on one machine rather
than in a session, so it may read a harness's own files: `link.sh` writes to
`~/.claude/skills` and `fired.sh` reads `~/.claude/projects`, and both say so
where they do it. A skill may carry a harness-specific frontmatter field when
it is a second lock over a body that is already right without it, which is why
`review-diff` sets `disallowed-tools` that Cursor does not read.
[WRITING-RULES.md](WRITING-RULES.md) under "Tool access" holds that trade and
the condition on it. And the Cursor rules file carries a `description`, which
lets Cursor pull it in by relevance where the Claude rule has no equivalent;
that one adds a way in rather than changing what either file says, so both
harnesses still get the same body on `skills/**`.

None of the three covers a procedure that only works in one harness.

## What an agent here never does

Post a comment or a review to a pull request, whoever asks and however they
ask. Reading stays open: viewing a pull request, its diff, and its review
threads are all unaffected, and so is opening one. The rule is categorical
because the mistake is public and cannot be taken back, so anything whose
whole purpose is that step has no configuration that saves it.

## Before changing a skill

Read [WRITING-RULES.md](WRITING-RULES.md). It is the standard every file here
follows, and enforcing it is what this repo is for.

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
- The two rules files close their frontmatter, carry a body that is not empty,
  and carry the same body. An unclosed fence reads as an empty body, and two
  empty bodies compare equal.
- Both rules files still scope themselves to `skills/**`, and the Cursor one
  still sets `alwaysApply: false`. That scoping is what decides when either
  rule loads.
- A skill other than `review-diff` carrying `allowed-tools` or
  `disallowed-tools` warns rather than fails, because whether the body holds
  without the field is not something a script can read.
- `link.sh` and every `scripts/*.sh` parse under `bash -n`, because nothing
  else in the checker runs them.
- Every command block whose fence reads `bash checked`, in a staged or
  committed markdown file, runs from the repo root with stdin closed and exits
  zero. The checker executes these, so an untracked file is left alone.
- No markdown file contains an em dash, an en dash, or a minus sign.

What limits the model-invoked set is conflict, not count. Before adding one,
work through the test in [WRITING-RULES.md](WRITING-RULES.md) under
"Invocation". No script checks that.

Nothing here deletes a skill for going unused. A model-invoked one that stays
quiet, on an install that checks out, gets demoted to user-invoked instead:
the description stops riding every turn and the file stays.
[WRITING-RULES.md](WRITING-RULES.md) under "Keeping skills" holds it.

`./scripts/check.sh --doctor` adds one check CI cannot run, because a fresh
runner has no `~/.claude` to inspect: whether every skill in this repo is
currently linked into `~/.claude/skills`. Run it when a skill has been added,
renamed, or removed, and run `./link.sh` when it reports a gap. A missing link
fails the run, so a hook can gate on it.

## When a change makes a claim false

Behaviour and the prose describing it come apart one sentence at a time. After
changing what something does, search for every place that says what it does
and re-derive each from the new behaviour, rather than editing the sentence
nearest the change. Comments, headings, and the strings a script prints all
count, and the twin is usually in another file.

Mark a command block `bash checked` when its content can rot, and
`./scripts/check.sh` runs it. A pipeline that encodes an assumption earns the
marker, because the assumption is what goes stale.

Mark it only when it runs anywhere, because CI runs it too, with the checkout
and the usual POSIX tools and little else. A fresh runner has no `~/.claude`,
so nothing reading session transcripts or a tool's own installed files will
work there. `./scripts/fired.sh` reads `~/.claude/projects`, so a block
calling it stays unmarked. A block that needs an environment belongs in its
own fence with no marker, beside the one that runs anywhere.

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
