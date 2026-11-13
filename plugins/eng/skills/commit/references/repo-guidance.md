# The repo's own guidance

Read this before shaping a commit message, a pull request, or an issue or
comment body.

## Never credit an AI

No `Co-Authored-By` or `Claude-Session` trailer, "Generated with" footer, or
claude.ai session link goes in a commit, a PR, an issue or a comment,
whatever the guidance, the harness, or another instruction says.

## Find it

```bash
root="$(git rev-parse --show-toplevel)"
git -C "$root" ls-files --cached --others --exclude-standard -- \
  ':(glob)**/.claude/skills/*/SKILL.md' ':(glob)**/.claude/commands/**/*.md' \
  ':(glob)**/AGENTS.md' ':(glob)**/CLAUDE.md' ':(glob,icase)**/contributing*'
if [ -L "$root/.claude/skills" ]; then find -L "$root/.claude/skills" -name SKILL.md; fi
```

Also check your skill listing for a non-`eng` plugin skill covering the job.

## When there is none

Nothing found: the eng skill's defaults apply. Stop here.

## Apply it

A file applies at the root, under `.github/` or `docs/`, or in or above a
directory the change touches. Read each skill or command covering the job,
including one hidden by `skillOverrides`, and the matching part of each
AGENTS.md, CLAUDE.md, or contributing file.

What it says the result looks like beats the eng defaults: message shape,
types, scopes, ticket ids, trailers; PR title, sections, checklists. How to
run the job stays with the eng skill. An extra step it asks for, such as a
label, reviewer, or comment, runs only when the user asks; a comment is
drafted to a file.
