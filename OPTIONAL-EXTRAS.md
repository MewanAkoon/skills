# Optional extras

Nothing in this file is part of this repo. The skills work with none of it
installed, no session loads it, and no skill or script depends on it.
`check.sh` lints its links and its prose the way it lints every file here, and
that is the whole of its involvement. These are notes on what pairs well with
these skills in each tool, written down so the same ground is not covered
twice.

## Why plugins are not part of this repo

A Claude Code plugin and a Cursor plugin are different artifacts. Claude Code
installs one under `~/.claude/plugins` and reads its manifest at
`.claude-plugin/plugin.json`. Cursor installs from its own marketplace under
`~/.cursor/plugins` and reads `.cursor-plugin/plugin.json`. The two trees do
not overlap: nothing installed in one shows up in the other. A vendor can ship
both manifests from one repo, as `figma` does, and it is still two installs
with two enabled states.

So a plugin adopted here would serve one harness and be dead weight in the
other, which is the opposite of what this repo is for. See
[AGENTS.md](AGENTS.md) under "What belongs here". Install what you want in
your own tool. What follows is a recommendation, never a dependency.

## With Claude Code

Judged against the skills here on 2026-08-28. A verdict outlives the version
it was reached on, so add a line rather than editing one when it changes.

- **`feature-dev`.** Its three agents each name a `tools` list carrying no
  `Bash` and no `Edit`, so none of them writes a file or runs a command. That
  is a property of the files rather than a promise inside them.
- **`frontend-design`.** One skill, and nothing here claims the same decision.
- **`typescript-lsp`.** No skill, agent, or command, so it costs nothing on a
  turn. It needs a global `typescript-language-server` and a `typescript` on
  the 5.x line, because TypeScript 7 is the native port and ships no
  `tsserver.js`.

Enabled here but never judged: `claude-md-management` and `claude-code-setup`.
The first pre-approves `Read, Edit, Glob` for its `revise-claude-md` command,
so that command edits files without a prompt.

Not recommended, and why:

- **`code-review`.** Its last step posts the result to a pull request, and its
  frontmatter pre-approves the command that does it.
- **`superpowers`.** Its descriptions ride every turn to re-cover six skills
  that exist here already, written for this work rather than in general.
- **`github`.** It duplicates an already authenticated `gh`, and its tools
  reach the same endpoint by a route harder to spot than a shell command.
- **`context7`.** A connector on the claude.ai account covers the same ground.

## With Cursor

None of the above transfers. The Cursor set is not enumerable from disk, so
what follows is what was found rather than a survey: the plugins cached on
this machine are `linear` and `figma`, both service integrations rather than
workflow additions, and neither is a counterpart to the three above. To see
what is there:

```bash
ls ~/.cursor/plugins/cache/*/*/
```

Cursor also syncs its own skills into `~/.cursor/skills-cursor`, several of
them review skills, so read those before adding anything that reviews a diff.
That directory is Cursor's, and `link.sh` neither writes to it nor prunes it.

## Before enabling any of them

Read the files, not the README. Four questions, and the first failure is the
answer.

1. **What does its last step do?** Read the last step of every file under
   `commands/` and `skills/`. A component is judged on its terminal action,
   not on the sentence describing it. Nothing here posts a comment or a review
   to a pull request, whoever asks and however they ask, and a component whose
   purpose is that step has no configuration that saves it.
2. **Does it grant itself tools?** `allowed-tools` in a component's
   frontmatter pre-approves the tools it names for the turn that invokes it,
   so they run with no prompt. It grants and never restricts, which
   [WRITING-RULES.md](WRITING-RULES.md) covers under "Tool access". A grant
   naming a command that a rule forbids defeats the rule without looking like
   it does.
3. **Does it re-cover something already here?** What competes is the
   `description` in a component's frontmatter, not the summary a table
   carries, so read the real ones side by side. Two components compete when
   they claim the same decision and the agent has to pick one, which is the
   test in [WRITING-RULES.md](WRITING-RULES.md) under "Invocation". Composing
   is fine. Competing is not.
4. **What does it cost while doing nothing?** Every description in a listing
   rides every turn, whether or not the thing runs. An MCP server loads its
   tool schemas on every turn too. Something earning its place one session a
   month rarely earns a permanent line in the prompt.
