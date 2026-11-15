# eng

Engineering skills for Claude Code, shipped as one plugin, `eng`: a standing
workflow from ticket to pull request, and skills for commits, PRs, issues,
review feedback, debugging, TypeScript, API boundaries and plain writing. It
runs in Claude Code. Cursor is not supported yet, and eng's guards have not
been shown to hold there.

## Setup

You need Claude Code 2.1.293 or later (`claude --version`), `git`, `jq`, and
`gh` signed in, plus the gh-stack extension and skill for stacked PRs.
Without `jq` the hooks guard nothing.

1. `claude plugin marketplace add 'MewanAkoon/skills#stable'`
2. `claude plugin install eng@mewanakoon`
3. Merge the settings below into `~/.claude/settings.json`, adding to any
   `permissions.allow` or `permissions.ask` list already there:
   - `skillOverrides`, required: a bare `commit` or `pr` skill cannot take a
     request meant for `eng:commit` or `eng:pr`.
   - `attribution`, required: no AI credit lines on commits and PRs.
   - the `gh stack` rules, required for stacked PRs: `gh stack` runs without
     a prompt, and a stack merge or unstack still asks.
   - allow rules for eng's own writes, optional: they stop the prompts
     outside auto mode, as "Setup in detail" says.
4. Start a new session. `claude plugin list` shows `eng@mewanakoon` enabled,
   `jq --version` prints a version, and the session shows a line starting
   `eng:` for anything still missing.

```json
{
  "skillOverrides": { "commit": "off", "pr": "off" },
  "attribution": { "commit": "", "pr": "", "sessionUrl": false },
  "permissions": {
    "allow": ["Bash(gh stack:*)"],
    "ask": ["Bash(gh stack merge:*)", "Bash(gh stack unstack:*)"]
  }
}
```

To update, run `claude plugin update eng@mewanakoon` and start a new session.
Installs follow the `stable` branch, so they change only at a release.

To remove, run `claude plugin uninstall eng@mewanakoon`, then
`claude plugin marketplace remove mewanakoon`. The uninstall deletes the
plugin's data folder, `~/.claude/plugins/data/eng-mewanakoon/`.

## Setup in detail

**Tools.** [dependencies.md](plugins/eng/standards/dependencies.md) lists
each tool the skills rely on with its install command, the gh-stack extension
and skill for stacked PRs among them. The new-session lines name the same
list. Without `jq` the hooks send no lines and guard nothing, so `jq --version`
is the check for it.

**In a session.** `/plugin marketplace add MewanAkoon/skills#stable` and
`/plugin install eng@mewanakoon` do the same as steps 1 and 2. Both forms
install at user scope, as the install's `(scope: user)` line shows, so the
skills load in every project on the machine.

**Optional allow rules.** Outside auto mode, each of eng's own writes
prompts. To stop that, add `Bash(git commit:*)`, `Bash(git push:*)`,
`Bash(gh pr create:*)`, `Bash(gh pr edit:*)`, `Bash(gh pr ready:*)`, and
`mcp__<server>` for your tracker's MCP server to `permissions.allow`. With
`Bash(git push:*)` allowed, a plain push to `main` no longer prompts either,
and only the skills hold it back.

**The settings.** `skillOverrides` hides a skill by its bare name
([docs](https://code.claude.com/docs/en/skills#override-skill-visibility-from-settings)),
so `eng:commit` and `eng:pr` keep working. An empty `commit` or `pr` under
`attribution` drops that credit line, and `sessionUrl: false` drops the
session link
([docs](https://code.claude.com/docs/en/settings-reference#attribution)). The eng skills keep all of them out as well.

**Auto-update.** Claude Code leaves it off for marketplaces outside
Anthropic's. To turn it on, open `/plugin`, go to Marketplaces, pick
`mewanakoon`, and enable auto-update
([docs](https://code.claude.com/docs/en/discover-plugins#keep-plugins-updated)).
After an update by hand, `/reload-plugins` works in place of a new session
([docs](https://code.claude.com/docs/en/plugins/cli-reference#plugin-update)).
[CHANGELOG.md](CHANGELOG.md) says what each release brought.

**Removing.** An uninstall with `--keep-data` keeps the data folder, which
holds the hook's log and review state; delete it yourself then
([docs](https://code.claude.com/docs/en/plugins/cli-reference#plugin-uninstall)).
Take the `skillOverrides`, `attribution` and `gh stack` entries out of your
settings if you want Claude Code's defaults back.

**Moving an install that follows main.** An install added as
`MewanAkoon/skills`, with no `#stable`, follows `main`, which carries work
not yet released. To move it, with no session in the middle of a task:

```bash
claude plugin marketplace remove mewanakoon
claude plugin marketplace add 'MewanAkoon/skills#stable'
claude plugin install eng@mewanakoon
```

The remove comes first because Claude Code refuses to add `mewanakoon` again
while your settings list it at another ref, as 2.1.318 does in testing. It also uninstalls `eng` and
deletes its data folder. Your settings stay as they are.

## The workflow

[workflow.md](plugins/eng/standards/workflow.md) is six standing steps. The
plugin's hook sends it, with `plain-writing`'s core rules, at the start of
every session and after each compaction. Each step names the skill that holds
its procedure:

| Step | Skill |
|---|---|
| 1. Understand first, with real signal for a bug | `eng:investigate` |
| 2. Plan, ask at planning only, check in rounds, then stop | `eng:investigate` |
| 3. Implement, then review with `/code-review`, an intent check, and `/security-review` on a trust boundary | `eng:implement` |
| 4. Write outside the machine only when asked or when an approved Delivery covers it | `eng:commit`, `eng:pr`, `eng:issue` |
| 5. Post nothing; judge PR feedback on evidence | `eng:pr-feedback` |
| 6. Lead every reply with the result | |

A repo's own guidance, such as `AGENTS.md`, `CONTRIBUTING` or its `.claude/`
skills, beats an eng skill's defaults on how a result should look. The eng
skill still runs the job, with its checks and its rules on writes.

## Skills

Every skill loads as `eng:<name>`. Type the full name: a bare `commit` or `pr`
is not sure to reach the plugin's skill.

### Model-invoked

These fire on their own when the description matches.

| Skill | Fires on | What it does |
|---|---|---|
| [investigate](plugins/eng/skills/investigate/SKILL.md) | A ticket, thread, issue, error or log, bug report, or question about the code | Reads the sources and the code, checks the findings in rounds, ends with a plan and stops |
| [implement](plugins/eng/skills/implement/SKILL.md) | An approved plan, or a request that names the exact change | Makes the change, tests it, corrects docs it makes false, reviews it, and delivers it: branch, commits, push, draft PR, ready once clean. Dependent layers go out as a gh-stack stack |
| [pr-feedback](plugins/eng/skills/pr-feedback/SKILL.md) | A PR comment link, or a request to address review feedback | Judges each comment on evidence, fixes the valid ones, drafts replies to a file |
| [plain-writing](plugins/eng/skills/plain-writing/SKILL.md) | Prose that outlives the chat, such as a doc, a commit message, a PR or issue body, or a long reply | Strips AI tells and keeps language plain. Its core reaches every session through the hook |
| [commit](plugins/eng/skills/commit/SKILL.md) | A message asking to commit or push | Stages one change and matches the repo's commit convention |
| [pr](plugins/eng/skills/pr/SKILL.md) | A message asking to open or update a PR | Resolves the base, writes the title and body from the diff, opens a draft assigned to you |
| [issue](plugins/eng/skills/issue/SKILL.md) | A message asking to draft, file, edit, label, close, or comment on an issue | Finds the repo's tracker and works it through `gh` or its MCP server, sizes and dates each new issue, drafts every comment to a file |
| [ts-types](plugins/eng/skills/ts-types/SKILL.md) | A TypeScript type, interface or signature, a type error, or a diff adding `any`, a cast, or a non-null assertion | Discriminated unions, brands, narrowing, exhaustiveness |
| [api-boundaries](plugins/eng/skills/api-boundaries/SKILL.md) | Node handlers, middleware, config, consumers, third-party calls, or where a check belongs | Validation at the edge, no guards inside |
| [merge-conflicts](plugins/eng/skills/merge-conflicts/SKILL.md) | Unmerged paths or conflict markers, when you ask to resolve them or report them, or a rebase the run started stops on them | Traces both sides, resolves hunk by hunk, finishes the operation |
| [why](plugins/eng/skills/why/SKILL.md) | Removing a guard, retry, timeout, special case or odd constant the request did not name, or asking why code is shaped the way it is | Traces the reason through git history and PRs |
| [blast-radius](plugins/eng/skills/blast-radius/SKILL.md) | Planning a change to something shared, or asking what a change breaks | What breaks elsewhere, with evidence levels |

### User-invoked

These run only when typed, and cost no context until then.

| Skill | Invoke | What it does |
|---|---|---|
| [grill-me](plugins/eng/skills/grill-me/SKILL.md) | `/eng:grill-me` | Interview until the design has no open branches |
| [handoff](plugins/eng/skills/handoff/SKILL.md) | `/eng:handoff` | Compact this session for the next one |

## Guardrails

- Nothing is posted. Comments, reviews and replies are drafted to a file for
  you to post.
- Merges, releases, tags, deploys and force pushes wait for your own message.
- Commits, pushes and PRs happen when you ask, or when a plan you approved, a
  change you named, or a follow-up on your open PR covers them.
- A subagent writes nothing outside your machine.
- Work is reviewed before it comes back to you.

The skills hold all five. The plugin's hook enforces what can be read from a
command or a tool's name:

| Action | What the hook does |
|---|---|
| A comment, review or reply through `gh`, an API call, a tracker CLI, a chat webhook, or an MCP tool named for posting, Linear's `save_comment` included | Denies it, with a note to draft it to a file |
| `/code-review` with `--comment` or `--post`, or one the model starts with `ultra` or `--fix` | Denies it |
| A merge, release, deploy, package publish, workflow run, repo, secret or key write, `gh stack merge` or `unstack`, or an MCP write named for deleting, merging, releasing, deploying, sending or publishing | Asks you, in auto mode too |
| A push that forces, deletes, or sends tags or push options | Asks, apart from a push with an explicit lease that names no default branch |
| A commit, push, PR create, edit or ready, issue write, `gh stack` push, sync, submit or link, or other MCP write | Leaves it to your permission settings |
| Any of the writes above from a subagent | Denies it, apart from MCP servers that run on this machine |
| A shell command it cannot read in time | Asks, still denying a post it found |
| Changed code not reviewed since it last changed, at hand-back | Reminds once to run the review |
| A new session's start | Shows you a line for each missing setting or tool |
| The first prompt outside plan mode | In default, accept-edits or don't-ask mode, shows you a line when your permission rules would stop eng's writes |

The header of [eng-hook](plugins/eng/hooks/eng-hook) says what each hook
decides, and the cases under [tests/hooks/](tests/hooks/) show the exact
rules. The hook catches a slip, not a determined bypass: a git alias, a
command built at run time, a script that runs one, or an MCP tool whose name
hides what it does all get past it.

## Cloud sessions

eng does not run in Claude Code cloud sessions yet, because they load no
plugins from your machine or your settings.
([docs](https://code.claude.com/docs/en/cloud-environments#what-carries-over-from-your-setup))

## Working files

Plans go under `.claude/plans/` and handoffs under `.claude/handoffs/` in the
repo you work in, and `eng:commit` leaves them out unless you name them. To
keep them out of every repo, add `.claude/` to your global git ignore file,
unless a team you work with commits `.claude/settings.json`.

## More

- [CONTRIBUTING.md](CONTRIBUTING.md): working on this repo, the checks,
  evals, taking a subset of the skills, and sharing one skill.
- [AGENTS.md](AGENTS.md): the rules for any agent working in this repo.
- [OPTIONAL-EXTRAS.md](OPTIONAL-EXTRAS.md): what pairs well with eng, and
  what was tried and dropped.

## Attribution

Most skills here are adapted from two MIT-licensed repos, and each names its
source at the bottom. The rest were written for this repo.

- [mattpocock/skills](https://github.com/mattpocock/skills)
- [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack),
  by Lauren Tan
