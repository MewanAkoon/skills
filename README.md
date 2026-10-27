# skills

Agent skills as plain markdown, shipped as one Claude Code plugin, `eng`, from
this repo. Install it once and every skill loads in every session, under its
full name: `eng:commit`, `eng:pr`, `eng:why`, and so on. Nothing gets committed
into working repos.

A skill is a folder holding a `SKILL.md`: a description that decides when it
applies, and a procedure the agent follows once it does. The plugin is that
folder of skills plus two small manifests in `.claude-plugin/`, which is the
packaging the Claude Code docs describe and the one
[mattpocock/skills](https://github.com/mattpocock/skills) uses.

## Scope

Claude Code first. The skills themselves stay plain markdown that any harness
can read, but the way they ship, the plugin and its manifests, is Claude Code
packaging. Cursor support comes later; "If you use Cursor" below says where it
stands.

One other file ships the same way:
[standards/workflow.md](standards/workflow.md), the standing workflow every
session follows. A SessionStart hook in the plugin sends it, with
`plain-writing`'s core rules, at the start of every session and again after
each compaction. Other hooks in the plugin enforce the rules that have to hold,
listed under "What the hooks enforce" below. The hooks are Claude Code
packaging, like the manifests.

One narrow exception to "plain markdown", named in [AGENTS.md](AGENTS.md)
under "What belongs here": the Cursor rules file carries a `description` that
gives it a second way in.

Other plugins stay out of this one. [OPTIONAL-EXTRAS.md](OPTIONAL-EXTRAS.md)
says what pairs well with it, as a recommendation rather than a dependency.

## Setup

You need Claude Code 2.1.293 or later. In any Claude Code session:

```
/plugin marketplace add MewanAkoon/skills
/plugin install eng@mewanakoon
```

Or from a shell:

```bash
claude plugin marketplace add MewanAkoon/skills
claude plugin install eng@mewanakoon
```

Both install at user scope, so the skills load in every project on the
machine. There is no clone to keep and no script to run.

Then turn off the bare copies of two skills. A project may carry its own
`commit` and `pr` skills, and those load beside the plugin's today and can take
a request meant for it. Claude Code also reserves both names for built-in
skills it keeps switched off for now and can switch on. Add this to
`~/.claude/settings.json`:

```json
{
  "skillOverrides": {
    "commit": "off",
    "pr": "off"
  }
}
```

`skillOverrides` hides a skill by name from you and the model alike, for this
machine only, and never touches plugin skills. So `eng:commit` and `eng:pr`
stay, and a team repo's own `commit` and `pr` stay for everyone else. On your
machine `eng:commit` and `eng:pr` still read those files, and follow what they
say about how a commit message or a PR should look.

To confirm it worked from a clone of this repo:

```bash
./scripts/check.sh --doctor
```

A good run ends like this:

```
doctor: eng@mewanakoon <version> is installed and enabled, with no bare copies beside it
15 skills, 12 model-invoked
ok
```

It fails when Claude Code is older than 2.1.293, when the plugin is not
installed at user scope, is disabled, or is at another version than this clone,
when an old link or a personal copy of one of these skills is still loading,
when the `skillOverrides` entry is missing, or when one of the plugin's hooks
has logged an error.

### Updating

Claude Code leaves auto-update off for marketplaces outside Anthropic's. Turn
it on once in `/plugin`, under Marketplaces, or update by hand:

```bash
claude plugin update eng@mewanakoon
```

A release is a new `version` in `.claude-plugin/plugin.json`. An install stays
on the version it has until that string changes.

### Moving from the old symlinks

Before the plugin, `link.sh` symlinked each skill into `~/.claude/skills`.
Those links are personal skills with bare names, and they would load beside
the plugin's copies. From the clone:

1. Run `./link.sh --unlink`. It removes the links this clone made and leaves
   anything else alone. If you linked with `SKILLS_DEST` set, run it with the
   same value. A `.skillsignore` in the clone no longer does anything, so
   delete it.
2. Install the plugin and add the `skillOverrides` entry, as above.
3. If your `~/.claude/CLAUDE.md`, or a hook of yours, names a path under
   `~/.claude/skills`, point it at the skill's full name instead, such as
   `eng:plain-writing`. Those paths no longer exist.
4. Run `./scripts/check.sh --doctor`.

### Working on this repo

Add your clone as the marketplace instead of the GitHub one:

```
/plugin marketplace add ~/path/to/skills
/plugin install eng@mewanakoon
```

Both sources are named `mewanakoon`, so if you added the GitHub one first,
this repoints it at your clone, and the plugin you installed updates from the
clone from then on. Claude Code prints how to undo that.

A directory marketplace loads the plugin from the folder itself, so an edit
shows up after `/reload-plugins`. To try the working tree for one session
without installing anything:

```bash
claude --plugin-dir .
```

### If you use Cursor

Cursor reads skills from `~/.claude/skills`, which the plugin no longer fills.
Cursor's changelog says it also imports plugins installed in Claude Code while
**Settings, Agents, Third-Party Imports** is on, which would bring these
skills with it. That is not yet confirmed for this plugin. A skill folder
copied into `~/.cursor/skills` works too, with one catch: the skills name each
other and their commands with the plugin's prefix, `eng:commit` and
`/eng:commit`, which Cursor does not have. Drop the `eng:` prefix in a copy you
make for Cursor.

### Keeping working repos clean

The plugin itself installs under `~/.claude/plugins`, outside every project.
Some skills write working files: `investigate` and `wayfinder` under
`.claude/plans/`, and `handoff` under `.claude/handoffs/`. `eng:commit` leaves
them out unless you name them. As an optional safety net you can ignore them
globally. Check what you already have first, because setting `core.excludesfile`
replaces it:

```bash
git config --global core.excludesfile
```

If that prints a path, append to that file instead of the one below. If it
prints nothing:

```bash
printf '.claude/\n.skills.json\n' >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```

Ignoring `.claude/` applies to every repo you touch, including teams that
commit `.claude/settings.json` on purpose. Skip this step if that is you.

### Taking a subset

A plugin installs as a unit, and it loads every folder under `skills/`. To
take part of it, fork the repo, delete the skill folders you do not want along
with their README rows, and install from your fork. `./scripts/check.sh` names
anything left pointing at a skill you removed. Listing skills in `plugin.json`
does not narrow the set, because that field adds to the `skills/` scan rather
than replacing it.

### Sharing one skill with a team

Only when the team should have it too, and only from your own fork:

```bash
npx skills add <you>/skills -s why
```

That copies files into the current repo and needs Node. Default to the plugin
instead. The copy is a project skill without the plugin's prefix, so change its
`eng:` names to bare ones, `/eng:why` to `/why`, as for Cursor above.

### Removing it

```bash
claude plugin uninstall eng@mewanakoon
claude plugin marketplace remove mewanakoon
```

Remove the `skillOverrides` entry too if you want Claude Code's own `commit`
and `pr` back.

## The workflow

[standards/workflow.md](standards/workflow.md) is eight standing steps:
understand first, plan and stop, implement on approval, review until clean,
commit and open PRs only when asked, handle PR feedback on evidence and
review the whole PR after each push, never post, and report briefly. The
plugin's SessionStart hook sends it at the start of every session and after
each compaction. It names the skill for each step
that has a procedure, so a change of phase is the cue to load it:

| Step | Skill |
|---|---|
| 1 and 2, understand and plan | `eng:investigate` |
| 3, implement | `eng:implement` |
| 4, review | `eng:implement`'s review loop, through the built-in `/code-review` |
| 5, writes outside this machine | `eng:commit`, `eng:pr`, `eng:issue` |
| 6, PR feedback and the review after each push | `eng:pr-feedback`, and the built-in `/code-review` at `high` on the whole PR |

The other skills hold knowledge a phase reaches for, or are modes you start
yourself.

Step 1 also reads the repo's own guidance: its skills and commands under
`.claude/`, `AGENTS.md`, and `CONTRIBUTING`. Where that guidance says how a
result should look, such as a commit message or a PR body, it beats an eng
skill's defaults. The eng skill still runs the job, with its checks and the
rules on writes and posting. A repo with no such guidance gets the eng
defaults unchanged.

### What the hooks enforce

The skills say what to do. The plugin's hooks stop what must not happen, in
every session and inside subagents. They run in Claude Code only.

| Action | What happens |
|---|---|
| A comment, review or reply: `gh pr comment`, `gh pr review`, `gh issue comment`, a close or reopen with `--comment`, an API write to a comment, review or reply endpoint, a GraphQL comment or review mutation, a tracker CLI's comment or approval such as `glab mr note`, a chat webhook post, an MCP tool named for posting, or a code-review run with `--comment` or `--post` | Denied, with a note to write the draft to a file |
| A `git commit` or push, a PR create, edit or ready, an issue or label write, and a GitHub MCP tool that writes files or pushes | Denied in a subagent, when `eng:commit`, `eng:pr` or `eng:issue` has not loaded since your latest message, and when your latest message says not to. Otherwise it runs, with no prompt. `gh issue create --web`, which you submit yourself, passes |
| A PR merge, close or reopen, a release, a workflow run or rerun, a repo, gist, project, secret or variable write, a push that forces, deletes or sends tags, a package or image publish, a deploy through gcloud, firebase, terraform, kubectl, helm, vercel, fly, netlify, wrangler, serverless, aws or a `deploy*.sh` script, `prisma migrate deploy`, and an MCP write that is risky: one whose name says it deletes, trashes, clears, moves, shares, sends, uploads, publishes, merges, deploys, runs, schedules, cancels or stops something, or names, beside any verb the hook does not know as a read, access, members, roles, a payment, refund, charge, payout, transfer or invoice, a deployment or release, a secret, token or variable, a repo or gist, a webhook, or a calendar or meeting, and one whose input deletes a whole doc, tab or sheet, trashes, archives or drops data, or sets something to trash, runs a SQL drop, truncate or delete in a query or statement field, changes access or makes something public, moves a file to a new parent or folder, comments, assigns, invites or subscribes anyone but you, sends a notification, or names a person through a `user://` link, even you, or a mention of anyone but you | You confirm it in a prompt, auto mode included |
| Any other MCP write, one that only creates or changes something, such as a doc, page, sheet or issue edit through Claude Docs, Notion, Google Drive, Sheets, Linear or any other server | The hook stays out. Claude Code's own permission settings decide, so "always allow" on a tool, or a `permissions.allow` rule, stops its prompt, and in auto mode the classifier decides. Deleting text inside a doc through an op, as Claude Docs does, counts as editing it |
| A code-review Claude starts with `ultra` or `--fix` | Denied. One you type yourself is yours |
| Handing back changed code that has not been reviewed since it last changed | One reminder to run the review step |
| Handing back after a push that moves a remote branch other than the default to HEAD, or after opening a PR, before a review reaches that commit | One reminder per pushed commit to review the whole PR at `high`, which Claude skips when the branch has no PR. A review at `high` or above of the PR by number or by a link to the PR or its files after the push counts, and so does a range whose ends meet at or before the merge base with a remote's default branch and that ends at that commit, run after the push or as the last such range before it |

The Claude app's own MCP servers, such as the one a project thread replies
through, are exempt from every check, because they carry the conversation
with you. Two of their tools are the exception. A command the terminal tool
runs is read like any other, and the tool that turns on a PR's auto-merge
asks like a merge. Three hints are best effort: a review comment link
names `eng:pr-feedback`, a pull request link with no request gets a note to
ask what you want, and a git conflict names `eng:merge-conflicts`.

A write runs unless your latest message plainly says not to, including a
write the message never names. A plain no is a negation tied to the write:
"don't commit", "no PR", "don't stage, commit or push", "commit without
pushing", "hold the push", "never mind the push", "I'll push it myself", or a
deferral right after it, such as "push it later" or "push once I approve".
Reading back from the last place the message names the write, the first that
refuses or asks for it decides. So "commit, but don't push" lets the commit
run and denies the push, and "I didn't push it, can you push" or "don't push.
Actually, push it" asks for the push. A refusal that only narrows the write,
such as "don't commit the .env file" or "don't push to main", is not a no, and
neither is a fact such as "there's no PR yet" or "it wasn't pushed". A
question that opens with a question word is not read, so "why don't you push,
then?" refuses nothing, while "don't push yet, okay?" still refuses. Anything subtler, such as a
takeback ("actually, just commit"), a wait ("wait for CI before you push") or a
condition ("let me review first"), the hook lets run, and the skills hold it
back: `eng:commit`, `eng:pr` and `eng:issue` read what you meant and act only
on what you asked for. A subagent's report, a background task or a CI event is
not your message, so it changes none of this. When the hook cannot read its
state at all, it lets the write run, as every check here fails open.

The hooks catch a slip, not a determined bypass. They read commands the way
a shell splits them, so a quoted
`gh pr comment` in a grep or a heredoc stays allowed, while a command inside
`$( )`, or a heredoc fed to a shell, is read too. They cannot see git aliases or push settings, a tag pushed
by its bare name, a commit made by anything but `git commit`, such as
`git merge`, `pull`, `rebase` or `cherry-pick`, a command built at run time or hidden in a script,
an MCP tool whose name and input both hide what it does, or a browser posting through a web
page. The reminder to review the whole PR reads only the Bash tool. It misses
a PR opened through an MCP tool or `glab api`, a push run in the background, a push to a URL
rather than a named remote, a push from a clone that tracks only one
branch, and a push run after a `cd` that leaves the directory the session started in or is outside git. It reads a short commit hash made only of digits as a PR number, counts a review of any PR by number or link, whichever PR it is, and counts no range as the whole PR on a remote whose default branch is unnamed and neither main nor master, or for a PR based on another branch, such as one in a stack. When the reminder cannot go out in the turn of the push, it goes out at the end of a later turn. It keeps one pushed commit per session, so of two branches pushed in one turn only the last gets a reminder, and `gt submit` counts as opening a PR even when it only updates one, which can bring a second reminder for the same commit. A PR opened with `--head` for another branch counts as one for the branch HEAD is on, when that branch is pushed. It checks only the repo the session is in at the stop, so a PR pushed from another repo gets no reminder once the session moves on, and it counts a review when the review starts, so one that is cancelled still counts. A hook that breaks fails open: it logs an error, which
`./scripts/check.sh --doctor` reports, and the session carries on.

## Skills

Every skill loads as `eng:<name>`. The tables link the folders.

### Model-invoked

These fire on their own when the description matches. What limits the list is
not its length, it is conflict. Several of these firing at once is fine and
often right, since `commit` shapes a commit and `plain-writing` shapes the
words in it. What costs you is two skills claiming the same decision, because
the agent picks one, reads a whole `SKILL.md`, and follows the wrong
procedure. Add a skill when nothing here would contradict it.

Two of these assume a stack, and say so in their own descriptions:
`ts-types` is TypeScript only, and `api-boundaries` is written for Node
services. The rest are language-neutral, though a few reach
for a TypeScript example. If you work in something else, "Taking a subset"
above leaves out the ones you do not want.

| Skill | Fires on | What it does |
|---|---|---|
| [investigate](skills/investigate/SKILL.md) | A ticket, thread, issue, error or log, bug report, or question about the code | Reads the sources and the code, checks the findings, ends with a plan and stops |
| [implement](skills/implement/SKILL.md) | An approved plan, or a request that names the exact change | Makes the change test-first in the repo's patterns, corrects docs it makes false, reviews it through `/code-review` |
| [pr-feedback](skills/pr-feedback/SKILL.md) | A PR comment link, or a request to address review feedback | Judges each comment on evidence, fixes the valid ones, drafts replies to a file |
| [plain-writing](skills/plain-writing/SKILL.md) | Prose that outlives the chat, such as a doc, a commit message, a PR or issue body, or a long reply | Strips AI tells, enforces plain language, gates code comments. Its core reaches every session through the hook |
| [commit](skills/commit/SKILL.md) | A message asking to commit or push | Stages one change, matches the repo's own commit guidance or message convention, survives hooks |
| [pr](skills/pr/SKILL.md) | A message asking to open or update a PR | Resolves the base, writes title and body from the diff in the repo's own PR format, creates or updates |
| [issue](skills/issue/SKILL.md) | A message asking to draft, file, edit, label, or close an issue | Drafts from the repo's template and labels to files, files only when asked |
| [ts-types](skills/ts-types/SKILL.md) | Any `.ts` or `.tsx` file, a type error, or a diff adding `any` or a cast | Discriminated unions, brands, narrowing, exhaustiveness |
| [api-boundaries](skills/api-boundaries/SKILL.md) | Handlers, middleware, config, consumers, third-party calls, or where a check belongs | Validation at the edge, no guards inside |
| [merge-conflicts](skills/merge-conflicts/SKILL.md) | Unmerged paths or conflict markers, when your latest message asks to resolve them, reports them, or asks for that operation | Traces both sides, resolves hunk by hunk, finishes the operation |
| [why](skills/why/SKILL.md) | Removing or rewriting a guard, retry, timeout, special case, odd constant, or redundant-looking code, or asking why code is shaped the way it is | Traces the rationale from git history, evidence apart from inference |
| [blast-radius](skills/blast-radius/SKILL.md) | Planning a change to something shared, or a question about what a change breaks | What a change breaks elsewhere, with evidence levels |

### User-invoked

Only fire when typed. Zero context cost.

| Skill | Invoke | What it does |
|---|---|---|
| [grill-me](skills/grill-me/SKILL.md) | `/eng:grill-me` | Interview until the design has no open branches |
| [handoff](skills/handoff/SKILL.md) | `/eng:handoff` | Compact this session for the next one |
| [wayfinder](skills/wayfinder/SKILL.md) | `/eng:wayfinder` | Charts a big effort as decision tickets under `.claude/plans/` |

To see a change working in the running app, Claude Code's built-in `/verify`
runs it, `/run` drives it, and `/run-skill-generator` writes the per-project
skill both follow.

Type the full name. A bare name is not sure to reach the plugin's skill:
`commit` and `pr` are names Claude Code keeps for skills of its own.

## Writing new skills

Read [WRITING-RULES.md](WRITING-RULES.md) first. It is the standard every file
here follows.

Run the checker before committing, and the plugin validator when a manifest
changes. Run the validator on the same pinned Claude Code as CI, because its
rules change between releases:

```bash
./scripts/check.sh
CLAUDE_BIN="npx --yes @anthropic-ai/claude-code@2.1.293" ./scripts/validate-plugin.sh
```

Without `CLAUDE_BIN` it uses the `claude` on your PATH, which may disagree
with CI.

The checker covers the mechanical half of that standard, and
[AGENTS.md](AGENTS.md) lists what it checks. CI runs it on every pull request
and on every push to `main`, on Linux and on macOS, without `--doctor`, since
a fresh runner has no Claude Code install to inspect. The checker also runs
`./scripts/test-hooks.sh`, which feeds the plugin's hooks their inputs,
including every command case under `tests/hooks/pre-tool/`, and checks what
they send, and, where Node 18.1 or later is installed, the fixtures for
`scripts/stats.mjs`. CI also runs the validator on a pinned Claude Code.

A change to anything the plugin loads needs a new `version` in
`.claude-plugin/plugin.json`, or the checker fails. Without it, nobody who
installed from GitHub would receive the change. Bump past whatever `main`
carries when you merge: CI checks `main` again after each push, so two pull
requests that picked the same version fail there.

### Evals

`evals/` holds cases for `claude plugin eval`: each workflow skill loads at its
moment, `eng:issue` stays out of "look into issue 42", the contract is in
context at the start, looking into a repo commits nothing, a commit waits for
`eng:commit`, and an unreviewed hand-back gets the review gate's reminder. Every run is a
model call on your account, so they stay out of CI. Run them before a release:

```bash
claude plugin eval . --ablation none --runs 1 --scaffold --allow-tools Bash \
  --no-publish --max-cost-usd 2
```

`--scaffold` builds the scratch repo one case needs. Bash is a gated tool, so a
case gets it only when it lists Bash in `allowed_tools` and the run passes
`--allow-tools Bash`; the case that forbids `git commit` does both.

The eval sandbox blocks `git`, so two things are checked by hand: the review
loop, and whether Claude acts on the reminder to review the whole PR after a
push. `./scripts/test-hooks.sh` covers when that reminder fires. For the
review loop, in an empty directory, run `tests/review-loop/setup.sh` from the
clone, then:

```bash
claude -p "The plan in PLAN.md is approved. Implement it." \
  --plugin-dir <clone> --allowedTools "Read Glob Grep Edit Write Bash Skill Agent" \
  --output-format stream-json --verbose
```

A good run calls `code-review` with `high` and a `<hash>..<hash>` range,
briefs the intent check beside it, and commits nothing. For the reminder,
push a PR's branch in a live session: the next hand-back runs `code-review`
with `high` on the whole PR, or says that review is still owed.

## Usage counts

A skill stays whether or not it fires. To see how often each one has fired,
run `/skill-doctor` in Claude Code. It lists every loaded skill with its uses,
when it last ran, and what its description costs on every turn.

To see whether the workflow holds, run `npm run stats`. It reads this
machine's Claude Code transcripts and the hook's log, and prints per week the
remote writes nobody asked for, those made from subagents, commits and PRs
made without their skill, posts, requests for another review pass, drafts,
compactions, and what code-review cost. The counts are heuristics, and the
script's `DEFINITIONS` say how each one is made. It saves a baseline, with
those definitions, and sets its headline numbers beside a later run, saying
when a definition has changed since:

```bash
npm run stats -- --since 2026-07-01 --until 2026-10-08 --save <baseline.json>
npm run stats -- --since <date> --compare <baseline.json>
```

It holds counts only, never message text, but keep a baseline out of the
repo all the same: it describes one person's work.

Every script you run while working here is also an `npm run` target, which is
the only reason `package.json` exists. It declares no dependencies.
`scripts/legacy.sh` has none, because `link.sh` and `--doctor` load it, and
neither do the setup scripts under `tests/` and `evals/`, which build scratch
repos for one check each.

## Optional extras

Other plugins, and anything else your tool loads alongside these skills, sit
outside this repo. [OPTIONAL-EXTRAS.md](OPTIONAL-EXTRAS.md) holds the notes:
what pairs well with Claude Code, what was found on the Cursor side, what to
look at before enabling any of it, and what was tried and dropped.

## Instructions for agents

[AGENTS.md](AGENTS.md) holds the rules for any agent working in this repo, and
its table says which file each harness reads.

## Attribution

Most skills here are adapted from two MIT-licensed repos, and each of those
names its source at the bottom. The rest were written for this repo.

- [mattpocock/skills](https://github.com/mattpocock/skills)
- [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack),
  by Lauren Tan
