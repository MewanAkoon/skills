# What eng relies on

The tools below sit outside the plugin, and the skills need them to work as
written. This table is the one list of them. At the start of each new session
the plugin's hook reads it through `hooks/setup-check`, and for each tool it
finds missing shows you one line with the install command. It installs
nothing. `./scripts/check.sh --doctor`, run from a clone of the repo, reads the
same table.

The Check column is what `setup-check` runs: a kind it knows and its argument.
`check.sh` fails on a row whose kind it does not know, and holds the Claude
Code row's check to the minimum it sets.

| What | Needed for | Check | Install |
|---|---|---|---|
| Claude Code 2.1.293 or later | the built-in /code-review that eng:implement, eng:investigate, eng:pr and eng:pr-feedback run, and the plugin's hooks | `version 2.1.293` | `claude update` |
| git | every skill that reads history or commits | `command git` | `xcode-select --install` on macOS, or your package manager |
| jq | the plugin's hooks | `command jq` | `brew install jq` on macOS, or your package manager |
| gh | eng:pr, eng:pr-feedback, eng:issue on GitHub, eng:why and eng:implement's delivery | `command gh` | `brew install gh` on macOS, or see cli.github.com |
| a gh login | eng:pr, eng:pr-feedback, eng:issue on GitHub, eng:why and eng:implement's delivery | `gh-login` | `gh auth login` |
| the gh-stack extension | stacked pull requests in eng:implement, eng:commit, eng:pr and eng:merge-conflicts | `gh-extension github/gh-stack` | `gh extension install github/gh-stack` |
| the gh-stack skill | stacked pull requests, whose commands it holds | `skill gh-stack` | `gh skill install github/gh-stack gh-stack --agent claude-code --scope user` |

The kinds:

- `version V`: the Claude Code running the session, read from `AI_AGENT`,
  else from `claude --version`, is V or later. When neither gives a version,
  nothing is shown.
- `command C`: `C` is on `PATH`.
- `gh-login`: `gh auth token` finds a token, which needs no network. It is
  skipped when `gh` is missing, since that row already says so.
- `gh-extension R`: `gh extension list` names the repository `R`. Skipped
  when `gh` is missing.
- `skill N`: a skill named `N` sits in the user's skills folder, under
  `CLAUDE_CONFIG_DIR` when it is set, or in the project's `.claude/skills`.

Not checked: the `read:project` scope on the gh login, which only a GitHub
Projects tracker needs. Only `gh auth status` shows it, and that goes to the
network. `gh auth refresh -s read:project` adds it.

These are dependencies: listed here, checked, and recommended when missing.
A plugin that pairs well with eng but that no skill needs is an optional
extra, and lives in the repository's `OPTIONAL-EXTRAS.md`, which no session
loads.

The settings eng needs are not in this table, because a plugin cannot set
them itself. `setup-check` checks those too, and the README's Setup section
lists them.
