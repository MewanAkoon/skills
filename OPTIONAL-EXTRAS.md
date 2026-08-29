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

[AGENTS.md](AGENTS.md) under "What belongs here" says why that keeps plugins
out of the repo. Install what you want in your own tool. What follows is a
recommendation, never a dependency.

## With Claude Code

Judged against the skills here on 2026-08-28. A verdict outlives the version
it was reached on. When one changes, move the entry to its new heading and
date it, so a reader sees one standing answer per plugin rather than two
undated ones under different headings.

- **`feature-dev`.** Its three agents each name a `tools` list carrying no
  `Bash` and no `Edit`, so none of them writes a file or runs a command. That
  is a property of the files rather than a promise inside them.
- **`frontend-design`.** One skill, and nothing here claims the same decision.
- **`typescript-lsp`.** No skill, agent, or command, so it costs nothing on a
  turn. It needs a global `typescript-language-server` and a `typescript` on
  the 5.x line, because TypeScript 7 is the native port and ships no
  `tsserver`. To re-check that: `npm view typescript@7 bin` lists `tsc`
  alone, where `npm view typescript@5.9.3 bin` lists `tsc` and `tsserver`.

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

None of the above transfers, and no counterpart to the three is recorded here.
Cursor's marketplace is browsable only inside Cursor, so this section records
what is installed rather than what exists, and an equivalent may well be there
to find. What is cached on this machine is `linear` and `figma`, both service
integrations rather than workflow additions:

```bash
ls ~/.cursor/plugins/cache/*/*/
```

That prints an error rather than nothing on a machine with no Cursor plugins,
because the glob has nothing to expand.

Cursor also syncs its own skills into `~/.cursor/skills-cursor`, several of
them review skills, so read those before adding anything that reviews a diff.
That directory is Cursor's, and `link.sh` neither writes to it nor prunes it.

## Before enabling any of them

Read the files, not the README. They are readable before anything is enabled,
because adding a marketplace clones every plugin in it, installed or not:

```bash
ls ~/.claude/plugins/marketplaces/<marketplace>/plugins/<name>/
```

A plugin the marketplace only points at, rather than holding itself, sits
under `external_plugins/` beside that directory. Then four questions, and the
first failure is the answer.

1. **What does its last step do?** Read the last step of every file under
   `commands/` and `skills/`. A component is judged on its terminal action,
   not on the sentence describing it. [AGENTS.md](AGENTS.md) under "What an
   agent here never does" rules the posting step out categorically, and a
   component whose whole purpose is that step has no configuration that saves
   it.
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
