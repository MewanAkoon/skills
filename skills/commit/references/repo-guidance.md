# Reading the repo's own guidance

Read this before shaping a commit message or a pull request. Some repos carry
their own skills, commands, or contributing rules for the same job, and they
say how its commits and PRs should look. Many carry none, and then the eng
skill's own steps decide everything, as they always have.

## Find it

```bash
root="$(git rev-parse --show-toplevel)"
git -C "$root" ls-files --cached --others --exclude-standard -- \
  ':(glob)**/.claude/skills/*/SKILL.md' ':(glob)**/.claude/commands/**/*.md' \
  ':(glob)**/AGENTS.md' ':(glob)**/CLAUDE.md' ':(glob,icase)**/contributing*'
if [ -L "$root/.claude/skills" ]; then find -L "$root/.claude/skills" -name SKILL.md; fi
```

The `ls-files` lists every guidance file the repo holds, at the root and
inside packages, new files included. `find -L` covers a `.claude/skills` that
is a symlink, which `ls-files` lists only as the link.

Then look at the skill listing in your context for skills from a plugin other
than `eng` whose description covers the same job. A repo can enable such a
plugin in its own `.claude/settings.json`, so its skills arrive without a file
in the repo.

## When there is none

Both probes printed nothing and the listing holds no such skill: the repo has
no guidance for this job. Skip the rest of this file and carry on with the
eng skill's next step. Its defaults apply unchanged.

## Read what applies

A file applies when it sits at the repo root, under `.github/` or `docs/`, or
in a directory that holds a path this change touches, or above one. A file in
another package belongs to that package's work, not this one.

From the files that apply, read in full each skill or command whose name or
description covers the job in hand: commits for `eng:commit`, pull requests
for `eng:pr`. The first lines of a skill's frontmatter name it. A command's
name is its file name. Of each AGENTS.md, CLAUDE.md, and contributing file
that applies, read the part that covers the job.

Read them as files, so the eng skill's steps and checks stay in charge. A
skill hidden from the listing, such as one named `commit` or `pr` under
`skillOverrides`, still counts, because the file is still in the repo. A
plugin skill has no file in the repo: load it with the Skill tool, read it as
context only, and return to the eng skill's step.

## Apply it

What the guidance says about how the result looks wins over the eng skill's
defaults. For a commit that is the message: its shape, types, scopes, ticket
ids, body, length, and trailers. For a pull request it is the title and the
body: their format, sections and their order, checklists, and linked issues.
The one exception is a line crediting an AI, such as `Co-Authored-By` or a
"Generated with" footer, which stays out whatever the guidance says.

What it says about running the job gives way to the eng skill's steps. That
covers when to commit or open a PR, staging, hooks, amending, force pushes,
and anything posted. A step the guidance adds beyond the commit or the PR
itself, such as a label, a reviewer, or a comment, gets named to the user and
runs only when their latest message asks for it. A comment goes to a draft
file instead, as the workflow's step 7 says.

Where the guidance says nothing about a part of the result, the eng skill's
default for that part still applies. The eng skill names what it treats as
stronger than the guidance, such as a commitlint config.
