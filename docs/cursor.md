# eng in Cursor

eng installs in Cursor as well as Claude Code, from the same folder: Cursor
reads `plugins/eng/.cursor-plugin/plugin.json`, and Claude Code reads
`plugins/eng/.claude-plugin/plugin.json`. Everything below was tested with
the Cursor CLI 2026.11.11 on macOS, in scratch repos, unless it says
otherwise. The Cursor IDE was not tested.

## Which way in

- **eng is installed in Claude Code on this machine.** Install nothing in
  Cursor. Until a release that carries this change is installed, which
  0.22.0 does not, the import brings the skills and the workflow and guards
  nothing, as "What the import brings" says. Cursor imports installed
  Claude Code plugins by default, through Cursor Settings, Agents,
  Third-Party Imports, "Include Third-Party Plugins, Skills, and Other
  Configs"
  ([docs](https://cursor.com/docs/reference/third-party-hooks)). Updating
  the Claude Code install with `claude plugin update eng@mewanakoon` updates
  what Cursor loads, and that install follows `stable`, so it changes only
  at a release.
- **Cursor only.** Install the Cursor plugin, as the next section says.

Not both. With both installed every skill is listed twice and the workflow
arrives twice, as "Both installed" below says.

## Installing the Cursor plugin

These steps have not been run end to end. They change your Cursor account,
which the tests here did not, and the last one needs the plugins view.

1. Run `agent plugin marketplace list`. If it lists `mewanakoon` already,
   remove it with `agent plugin marketplace remove mewanakoon`. A listing
   added without `--git-ref` follows the default branch, `main`. One account
   tested here already had it, indexed in the same second as its other
   Claude Code marketplace, so Cursor may have copied it from Claude Code.
2. `agent plugin marketplace add https://github.com/MewanAkoon/skills --git-ref stable`
3. Install `eng` from `mewanakoon` in Cursor's plugins view: `/plugin` in
   the CLI, or Install in the IDE.
4. Start a new chat and run the check at the end of this page.

To update, run `agent plugin marketplace update mewanakoon`, or Refresh in
the IDE, then start a new chat. Cursor caches a plugin by commit, not by its
`version`, so an install changes only at a release only if the marketplace
keeps tracking `stable`. Cursor's docs say a Refresh pulls "from the
repository", and say nothing on whether `--git-ref` holds across one
([docs](https://cursor.com/docs/plugins)). The one fact tested here: an
account's `mewanakoon` entry stayed at the commit it was indexed at, across
two days of CLI runs, so the CLI does not refresh it on its own.

To remove, uninstall `eng` in the plugins view, then run
`agent plugin marketplace remove mewanakoon`.

## What the import brings

- **Skills, under bare names.** `commit`, not `eng:commit`, since a Cursor
  skill name allows no colon ([docs](https://cursor.com/docs/skills)). Type
  `/commit`. The workflow says `eng:<name>` means `<name>` where skills have
  no prefix.
- **The workflow and plain-writing's core rules**, from the SessionStart
  hook, as in Claude Code.
- **The hooks.** Which hooks file runs depends on the folder Cursor loads:
  - A folder with only `.claude-plugin/`, as every eng release up to 0.22.0
    is, runs `hooks/hooks.json`. Cursor names its shell tool `Shell` there
    and leaves `cwd` empty. The hook in those releases does not read `Shell`,
    so through their import nothing is denied and nothing asks: in an
    earlier probe `gh pr comment` ran. Every release that carries this change
    has both manifests.
  - A folder with both manifests, loaded with `--plugin-dir`, ran only
    `hooks/hooks-cursor.json`, the Cursor plugin's file. The import of a
    release that carries both is expected to do the same. That is checked
    after the release, since the import reads only `~/.claude`.

## Both installed

Every skill is listed twice under the same name. In the earlier probe
recorded in SKI-30, `/commit` loaded the Cursor plugin's copy in 2 of 2
runs. The workflow arrives twice, about 4.4 KB each time, and each hook
runs twice, which leaves a deny or an ask as it is. Keep one: uninstall the
Cursor plugin, or turn off Third-Party Imports, which also drops every other
Claude Code plugin and skill from Cursor.

## What holds in Cursor

| | Cursor plugin | Import running this change's `hooks.json` | ACP |
|---|---|---|---|
| The workflow and core writing rules at session start | Yes | Yes | No |
| A post through `gh`, an API call or a CLI denied | Yes | Yes | No |
| A post through an MCP tool, such as `save_comment`, denied | Yes | Yes | No |
| A merge, release, deploy or force push asks | Yes, even when the command is allowlisted | Only when the command is not allowlisted | No |
| A command the parser cannot read in time asks | Yes | As the row above | No |
| A hook that crashes or times out blocks the call | Yes, through `failClosed` | No, the call runs | No |

The middle column was measured on a copy of this tree without
`.cursor-plugin/`. It holds only if a release's import runs `hooks.json`,
and for 0.22.0 and earlier nothing in it holds. The Cursor plugin's column
comes from `beforeShellExecution` and
`beforeMCPExecution`, the two Cursor events whose ask stops a call. Through
`hooks.json`, Cursor's `preToolUse` takes eng's deny, but its ask does not
stop a command the allowlist lets through.

These stay Claude Code only:

- **The deny on a subagent's writes.** Cursor's hook input marks no
  subagent.
- **The review reminder at hand-back.** Cursor's `-p` runs logged no Stop
  hook, and the hook does nothing on one from Cursor.
- **The setup lines and the permission check.** Cursor's session start
  carries no source, and the settings they read are Claude Code's.
- **The guards on `/code-review` flags.** Cursor has no built-in
  `/code-review`. Without it, `eng:implement`'s intent check reads the diff
  for bugs too, as its reference says.

## ACP

eng does not load under ACP (`agent acp`). Retested on 2026-11-14 in a
workspace Cursor had marked trusted: no hook ran, not even a project
`.cursor/hooks.json`, no Claude Code plugin skill was listed, the workflow
was not in context, and `gh pr comment` ran without a permission request.
Use the CLI or the IDE.

## Settings

- **Tools.** The hooks need `jq`, and the skills need `git` and `gh`, as
  [dependencies.md](../plugins/eng/standards/dependencies.md) lists. Without
  `jq` the hook answers `{}`, so no command is blocked, but nothing is
  guarded and the workflow does not arrive.
- **The CLI allowlist.** `permissions.allow` in `~/.cursor/cli-config.json`,
  or in a project's `.cursor/cli.json`, takes entries such as `Shell(git)`
  and `Shell(gh)`, each matching a command's first word
  ([docs](https://cursor.com/docs/cli/reference/permissions)). Without
  them every `git` and `gh` command asks, and `agent -p` rejects it. With
  the Cursor plugin an eng ask still stops an allowlisted command. Through
  `hooks.json` it does not, so keep `gh` off the allowlist there if merges
  should ask.
- **The Claude Code settings the README's Setup asks for** are not read by
  Cursor. `skillOverrides` has nothing to do, since bare names are the only
  names. The `commit` and `pr` skills keep AI credit lines out themselves,
  without `attribution`. The `gh stack` rules are Claude Code permissions,
  and in Cursor `gh stack` runs as the allowlist treats `gh`.
- **State and the log.** Cursor gives a plugin no data folder, so the hook
  keeps both under `${XDG_STATE_HOME:-~/.local/state}/eng`. A hook error is
  logged to `eng-hook.log` there.

## A check to repeat in the IDE

In a scratch git repo with no remote, start a new chat and ask for each:

1. "Quote step 5 of your standing instructions." It quotes eng's step 5,
   which starts "Post no comment, review, or reply".
2. Run `gh pr comment 1 --body x`. A hook blocks it with "Posting a comment,
   review or reply is off limits".
3. With `gh` allowlisted, run `gh pr merge 1`. Cursor asks you first.
   Decline. Without the allowlist entry Cursor asks for any `gh` command,
   so the step shows nothing about eng.
4. Type `/commit`. It loads eng's commit skill, which reads its
   `references/repo-guidance.md`.

Cursor's Hooks settings tab and its Hooks output channel show which hooks
ran.

## Not tested

- The Cursor IDE.
- An install from the marketplace, and whether its updates follow `stable`.
- The import of a release that carries both manifests.
- The relative hook paths in `hooks-cursor.json` from a marketplace cache
  folder. Under `--plugin-dir` Cursor ran them from the plugin's root.
- The names Cursor reports for real MCP servers. A project server came
  through under its own name.
- Whether Cursor sets `CLAUDE_PLUGIN_DATA` for an imported plugin. It did
  not under `--plugin-dir`.
