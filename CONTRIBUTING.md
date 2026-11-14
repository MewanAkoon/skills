# Contributing

How to work on this repo. [README.md](README.md) covers installing and using
eng, and [AGENTS.md](AGENTS.md) holds the rules any agent working here
follows.

## Working on this repo

Add your clone as the marketplace instead of the GitHub one:

```
/plugin marketplace add ~/path/to/skills
/plugin install eng@mewanakoon
```

Both sources are named `mewanakoon`, so if you added the GitHub one first,
this repoints it at your clone, and the installed plugin updates from the
clone from then on. Claude Code prints how to undo that. Going back to GitHub
takes the three commands under "Moving an install that follows main" in the
README, since the add from GitHub is refused while your settings list the
clone.

A directory marketplace loads the plugin from the folder itself, so an edit
shows up after `/reload-plugins`. To try the working tree for one session
without installing anything:

```bash
claude --plugin-dir plugins/eng
```

Every script you run while working here is also an `npm run` target, which
is the only reason `package.json` exists. It declares no dependencies.

## Checks

Run the checker before committing, the linter after changing a shell script,
and the plugin validator when a manifest changes. Run the validator on the
same pinned Claude Code as CI, because its rules change between releases:

```bash
./scripts/check.sh
npm run lint
CLAUDE_BIN="npx --yes @anthropic-ai/claude-code@2.1.293" ./scripts/validate-plugin.sh
```

Without `CLAUDE_BIN` the validator uses the `claude` on your `PATH`, which may
disagree with CI.

`check.sh` holds the repo's invariants, each with a comment on what it holds
and why. It also runs `./scripts/test-hooks.sh`, which feeds the plugin's
hooks their inputs from `tests/hooks/` and checks what they send,
`./scripts/test-cloud-setup.sh`, which runs the cloud setup script against
scratch homes, and `./scripts/test-checks.sh`, which runs the validator
wrapper against canned output. It reads every markdown file the repo owns,
[OPTIONAL-EXTRAS.md](OPTIONAL-EXTRAS.md) included, for links that resolve and
for dashes, and that is the whole of its involvement with that file.

CI runs the checker on every pull request and every push to `main`, on Linux
and on macOS, and the validator on a pinned Claude Code. It runs no
`--doctor`, since a fresh runner has no Claude Code install to inspect.

### The doctor

`./scripts/check.sh --doctor` adds the checks of this machine's install. A
good run ends like this:

```
doctor: eng@mewanakoon <version> is installed and enabled, with no bare copies beside it, the settings and tools it needs, and no hook errors logged
<n> skills, <m> model-invoked
ok
```

It fails when the plugin is not installed at user scope, is disabled, or is
at another version than this clone; when a personal copy of one of these
skills still loads from `~/.claude/skills`; when a setting the README's Setup
asks for is missing; when a tool in
[dependencies.md](plugins/eng/standards/dependencies.md) is missing, Claude
Code 2.1.293 or later among them; when this clone's own
`.claude/settings.json` or `settings.local.json` turns attribution back on; or
when one of the plugin's hooks has logged an error. `CLAUDE_CONFIG_DIR` moves
where it looks, as it does for Claude Code.

## Writing skills

Read [WRITING-RULES.md](WRITING-RULES.md) first. It is the standard every file
here follows. Every skill has a row in the README under the heading for its
invocation mode, which `check.sh` checks.

A pull request leaves the `version` in
`plugins/eng/.claude-plugin/plugin.json` alone and adds its entry under
`## Unreleased` at the top of [CHANGELOG.md](CHANGELOG.md). Installs follow
`stable`, so a change reaches them at the next release.

## Evals

`plugins/eng/evals/` holds cases for `claude plugin eval`: each workflow skill
loads at its moment, a request to open a PR among them; `eng:issue` stays out
of "look into issue 42"; an issue draft carries its assignee and estimate; an
issue run with no tools for the repo's tracker asks you to connect its server;
the workflow is in context at the start; looking into a repo commits nothing;
a commit waits for `eng:commit`; and an unreviewed hand-back gets the hook's
reminder. Every run is a model call on your account, so they stay out of CI.
Run them before a release:

```bash
claude plugin eval plugins/eng --ablation none --runs 1 --scaffold --allow-tools Bash Write Edit \
  --no-publish --max-cost-usd 3
```

`--scaffold` builds the scratch repo a case needs. Bash, Write and Edit are
gated tools, so a case gets one only when it lists it in `allowed_tools` and
the run passes it to `--allow-tools`.

The eval sandbox blocks `git`, so the review loop is checked by hand. In an
empty directory, run `tests/review-loop/setup.sh` from the clone, or
`setup.sh shell` or `setup.sh docs` for the security step, then:

```bash
claude -p "The plan in PLAN.md is approved. Implement it." \
  --plugin-dir <clone>/plugins/eng --allowedTools "Read Glob Grep Edit Write Bash Skill Agent" \
  --output-format stream-json --verbose
```

A good run calls `code-review` with `high` and a `<hash>..<hash>` range,
briefs the intent check beside it, and commits nothing. With `shell`, the
report names a shell trust boundary, the intent check carries the security
checklist, and after one local commit a subagent calls `security-review`
once. With `docs`, the report says `Trust boundary: none`, and neither runs.

## Taking a subset

A plugin installs as a unit, and it loads every folder under
`plugins/eng/skills/`. To take part of it, fork the repo, delete the skill
folders you do not want along with their README rows, and install from your
fork. `./scripts/check.sh` names anything left pointing at a skill you
removed. Listing skills in `plugin.json` does not narrow the set, because
that field adds to the `skills/` scan rather than replacing it.

## Sharing one skill with a team

Only when the team should have it too, and only from your own fork:

```bash
npx skills add <you>/skills -s why
```

That copies files into the current repo and needs Node. Default to the plugin
instead. The copy is a project skill without the plugin's prefix, and without
the workflow that says `eng:<name>` means `<name>`, so change its `eng:` names
to bare ones, `/eng:why` to `/why`.
