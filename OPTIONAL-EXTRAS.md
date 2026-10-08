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

Judged against the skills here on 2026-08-28, against the set as it stood
then. Every entry below is an example of applying the four questions further
down, not a standing answer. A verdict about someone else's repo has a short
shelf life, and nothing here can check one. Run the questions against your own
set and your own install before taking any of these as decided.

- **`feature-dev`.** Its three agents each name a `tools` list carrying no
  `Bash` and no `Edit`, so none of them writes a file or runs a command. That
  is a property of the files rather than a promise inside them.
- **`frontend-design`.** One skill, and nothing here claims the same decision.
- **`typescript-lsp`.** No skill, agent, or command, so it costs nothing on a
  turn. It needs a global `typescript-language-server` and a `typescript` on
  the 5.x line, because TypeScript 7 is the native port and ships no
  `tsserver`. To re-check that: `npm view typescript@7 bin` lists `tsc`
  alone, where `npm view typescript@5.9.3 bin` lists `tsc` and `tsserver`.

Not adopted here, and why. The reason is the transferable part; whether it
applies to you depends on your set and your account.

- **`code-review`.** Its last step posts the result to a pull request, and its
  frontmatter pre-approves the command that does it. That one is categorical:
  [AGENTS.md](AGENTS.md) under "What an agent here never does" rules it out
  whatever else it offers.
- **`superpowers`.** Its descriptions ride every turn to re-cover skills that
  exist here already. Count the overlap against your own set, because a fork
  that dropped half of these overlaps differently.
- **`github`.** It duplicates an already authenticated `gh`, and its tools
  reach the same endpoint by a route harder to spot than a shell command.
- **`context7`.** Redundant if your account already has a docs connector.
  Check before installing.

## With Cursor

None of the above transfers. Cursor's marketplace is browsable only inside
Cursor, so nothing general can be listed here, and an equivalent to any of the
three may well be there to find. To see what your own install has cached:

```bash
ls ~/.cursor/plugins/cache/*/*/
```

That prints an error rather than nothing on a machine with no Cursor plugins,
because the glob has nothing to expand. Expect service integrations rather
than workflow additions, and put whatever it prints through the four questions
below.

Cursor also syncs its own skills into `~/.cursor/skills-cursor`, several of
them review skills, so read those before adding anything that reviews a diff.
That directory is Cursor's, and `link.sh` neither writes to it nor prunes it.

## Before enabling any of them

Read the files, not the README. The four questions below are the durable part
and apply to whatever you are installing in either tool. The paths are the
Claude Code ones, because that is where the layout is documented; find the
equivalent for anything else.

In Claude Code the files are readable before anything is enabled, because
adding a marketplace clones every plugin in it, installed or not:

```bash
ls ~/.claude/plugins/marketplaces/<marketplace>/plugins/<name>/
```

A plugin the marketplace only points at, rather than holding itself, sits
under `external_plugins/` beside that directory. Cursor installs its own under
`~/.cursor/plugins`. Then four questions, and the first failure is the answer.

1. **What does its last step do?** Read the last step of every file under
   `commands/` and `skills/`. A component is judged on its terminal action,
   not on the sentence describing it. [AGENTS.md](AGENTS.md) under "What an
   agent here never does" rules the posting step out categorically, and a
   component whose whole purpose is that step has no configuration that saves
   it.
2. **Does it grant itself tools?** A component that pre-approves tools in its
   frontmatter runs them with no prompt. In Claude Code that field is
   `allowed-tools`; find the equivalent in whatever you are installing. It
   grants and never restricts, which [WRITING-RULES.md](WRITING-RULES.md)
   covers under "Tool access". A grant naming a command that a rule forbids
   defeats the rule without looking like it does.
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

   [WRITING-RULES.md](WRITING-RULES.md) under "Keeping skills" absorbs that
   same cost for a skill here, which reads like a double standard and is not.
   A skill here exists because someone corrected an agent three times, and the
   whole file is open to read. A plugin arrives as a bundle nobody in this
   repo audited, and it brings components you did not ask for along with the
   one you wanted.
