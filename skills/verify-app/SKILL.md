---
name: verify-app
description: A generator for a project-local skill that drives this app and captures evidence.
disable-model-invocation: true
---

# Verify app

## What this does

It writes a skill into the repo you are in, which teaches an agent how to
start this app, drive one real user path, and capture proof that the path
worked. The generated skill is the thing you keep. This skill only produces
it.

The reader of the generated skill is an agent that has never seen the app,
opening it cold in the middle of a task. Write it for that reader.

## When to use it

Once per project, when there is no scripted way to prove a feature works from
the outside. Run it again when the app grows a second surface, such as a CLI
next to the API.

Skip it when the repo is a library with no runnable surface. Its tests are
the verification.

## How to use it

Type `/verify-app` in the repo. It reads the repo, asks only what it cannot
find, writes `.claude/skills/verify-<app>/`, then runs its own output once to
prove it works.

Whether the generated skill stays out of commits depends on this machine, not
on this repo, so step 3 checks before writing rather than assuming. To give
the skill to the team, `git add -f .claude/skills/verify-<app>`.

---

## Step 1: Interview the repo

Answer these from the code. Ask the user only what the repo cannot tell you,
such as a credential.

- **Surface.** What does a user touch? An HTTP API, a Next.js UI, a CLI, a
  worker consuming a queue. A repo can have several. Pick the primary one and
  name the others.
- **Start.** The command that runs it locally, taken from `package.json`
  scripts, the Makefile, `docker-compose.yml`, or the README quickstart. With
  it: ports, required env vars, the database it expects, seed data, and how
  auth is obtained.
- **Drive.** How an agent interacts with it without a human. Look for what
  already exists first: Playwright or Cypress specs, supertest setups, a
  seeded `mongodb-memory-server`, a Postman collection, curl examples in the
  README. Only when none exists, pick a recipe: Playwright for a browser
  surface, HTTP calls for an API, a PTY session for a CLI.
- **Observe.** What proof can be captured. Screenshots, response bodies with
  status codes, a document read back out of Mongo, log lines, exit codes.
- **Isolate.** Whether two instances can run at once: ports, database names,
  data directories. When they cannot, the generated skill says so and refuses
  to drive an instance it did not start.

**Done when:** all five have an answer, and each answer names a real file, a
real command, or a real port in this repo.

## Step 2: Get it running yourself

Start the app with the command from step 1 and confirm it serves. Fix the
checkout first if it does not build, or report exactly what is broken and
stop.

A skill written against an app you never started teaches steps that do not
work.

**Done when:** the app started, one request or one command got a real
response, and the teardown command stopped it, or the run has stopped with
the build failure named and nothing written to disk.

## Step 3: Write the skill

Ask git whether the target path is ignored here, before anything is written to
it. A global gitignore covering `.claude/` is one setup step on one machine,
so a fresh clone or a teammate's checkout answers differently:

```bash
git check-ignore -q .claude/skills/verify-<app>
case $? in
  0) echo "ignored" ;;
  1) echo "not ignored" ;;
  *) echo "check-ignore failed" ;;
esac
```

Read the exit status rather than whether the command succeeded, because `-q`
prints nothing either way and a run outside a repository exits 128 like any
other error.

The path does not have to exist yet for this to answer. On `not ignored`, say
so and ask whether to add `.claude/` to the repo's own `.gitignore` first,
because otherwise the generated skill lands in the next `git add -A`. Add it
on yes. On no, say the generated skill will be committed along with everything
else, and carry on. On `check-ignore failed`, print what git said and stop,
because there is no repository to write a skill into.

Create `.claude/skills/verify-<app>/SKILL.md` with frontmatter carrying
`name: verify-<app>`, a description naming the app and the surface, and
`disable-model-invocation: true`. Without frontmatter the skill never
registers.

One file serves both tools. Cursor reads `.claude/skills` alongside its own
directories, so a second link under `.cursor/skills` would list the skill
twice in its picker.

Write these sections, each holding real commands from this repo:

- **Launch.** The exact command, the env it needs, and the signal that says
  it is ready: a log line, a port answering, a health endpoint returning 200.
  Include the teardown command in the same section.
- **Doctor.** One read-only check that answers "is this instance worth
  driving": the process is up, the port belongs to us, the build is current,
  the auth token is valid. For a browser surface it also checks that the
  browser binary is installed, with `npx playwright install chromium` as the
  fix. An agent runs Doctor first when anything looks strange.
- **Drive.** The harness with this repo's real selectors, routes, and
  commands. Prefer handles that survive a redesign: `getByRole` and
  `getByLabel` first, `getByTestId` where the accessible name moves, then
  route paths and CLI flags. Coordinates and tab order go stale in a week.
  End the section with one line: read `references/features/<name>.md` for the
  feature being verified before driving it.
- **Evidence.** What to capture and where it lands. Capture the action and
  the state it produced, not only the final screen. Check the side effect too:
  the document written, the message queued, the file created. Drive the path a
  user drives, not a test-only endpoint that skips the middle.
- **Cleanup.** Stop what this run started, by pid or container id. Cleanup
  removes instances and scratch data and leaves the evidence in place.
- **Helpers.** Any script it ships is executable, and the body shows how to
  call it.

**Done when:** the ignore check has been run, its answer is on the record
along with what the user chose when it said `not ignored`, the file exists,
its Launch and teardown commands are the ones that worked in step 2, every
other section holds a command built from a real path, port, or selector in
this repo, and a grep for `TODO` and for `<placeholder>` style angle brackets
returns nothing; or nothing was written because `check-ignore failed` and the
run stopped with git's message printed.

## Step 4: Seed the feature map

Create `.claude/skills/verify-<app>/references/features/README.md` as an
index, and one file per user-facing feature. Start with the three to five
that matter most, found from routes, CLI commands, or the nav.

Each feature file uses these four headings:

```markdown
## What it is
## How a user reaches it
## How to drive it
## What proves it worked
```

The map is what stops a later proof from driving the one convenient entry
point and calling the feature verified.

**Done when:** `references/features/README.md` links every feature file, and
each file has all four headings filled with content from this repo.

## Step 5: Run your own output

Follow only the text in the generated file: launch, doctor, drive one mapped
feature, capture evidence, clean up. Where a step needs a fact the file does
not hold, add that fact to the file and start the run again. Three runs is the
ceiling. A fourth means the gap is larger than a missing fact.

Run the cleanup after failed attempts too, so a broken run does not leave a
port held.

**Done when:** the run completed from the file alone and the evidence still
exists at its named location after cleanup, or three runs have been spent and
the run has stopped naming the step that failed and the fact the file still
does not hold.

## Step 6: Hand it over

Tell the user what was generated and what was proved.

**Done when:** the message names the generated path, lists every feature file
by name, names the one feature that was driven end to end, and names the
features mapped but not yet driven.

Keeping it honest is one line of maintenance: when a feature changes, its
file changes in the same PR. A map that describes last quarter's UI produces
proofs that pass on a broken app.

---

Adapted from the `create-verification-skill` skill in cursor/plugins pstack,
by Lauren Tan (MIT).
