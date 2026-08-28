---
name: review-diff
description: A diff review against written repo standards, plus a fixed smell baseline.
disable-model-invocation: true
disallowed-tools: Edit, Write, NotebookEdit
---

# Review diff

## What this does

It reviews the diff between `HEAD` and a fixed point you name, against two
things: the standards this repo has written down, and a fixed list of code
smells that applies even when the repo has written nothing down.

Every finding cites a `file:line` and names the standard or the smell it came
from, so you can disagree with it in one step.

It reports and changes nothing. Findings go in the reply for you to act on, so
the diff reads the same at the end of the review as at the start.

## When to use it

On your own branch before opening a PR, on someone else's branch you are
about to approve, or on work in progress when you want to know whether it is
drifting.

Skip it when the question is "does this break something else". That is
`/blast-radius`. Skip it when the question is "why is this failing". That is
`/diagnose-bug`.

## How to use it

Type `/review-diff` with a fixed point: `/review-diff since main`,
`/review-diff since HEAD~5`, or a commit SHA. You get findings grouped under
their heading, and each heading closes with its own count and its own worst
one.

If the change was supposed to do something specific, say what in one line
when you invoke it. That turns on step 5.

---

## Step 1: Pin the fixed point

```bash
git rev-parse <fixed-point>
git diff <fixed-point>...HEAD --stat
git log <fixed-point>..HEAD --oneline
git status --porcelain
git diff HEAD --stat
```

Three dots, so the comparison runs against the merge base rather than against
whatever landed on `main` since you branched.

The last two commands catch the work that is not committed yet. Review it
alongside the range, or say it is excluded. A review of a branch that ignores
the working tree misses whatever the author is holding.

If the user named no fixed point, ask for one and stop until they answer.

Stop when the diff lists no file and the working tree is clean, because there
is nothing to review.

**Done when:** the ref resolves, the diff and the commit list are on the
record, and uncommitted changes are either in the review or named as excluded,
or the review has stopped with its reason named, which is a diff that lists no
file and so has nothing to review, or a fixed point the user has yet to
name.

## Step 2: Get the intent in one line

Use the line the user gave when invoking. When there was none, ask what this
change is supposed to do, in one sentence. If they name a ticket or an issue,
read it with `gh issue view <n>` or from the path they give.

If there is nothing written and they do not answer, say "no stated intent,
reviewing standards only" and move on. Take the intent only from the user or
from a ticket. A review that infers the goal from the code can only confirm
that the code does what the code does.

**Done when:** one line of intent is on the record, or the review has been
declared standards-only.

## Step 3: Find the standards

Look for what this repo has written down: `AGENTS.md`, `CLAUDE.md`,
`CONTRIBUTING.md`, `CODING_STANDARDS.md`, `.cursor/rules/`, ADRs under
`docs/`, and the README of the package being changed.

Then find the repo's own check commands and run them. Look in `package.json`
scripts, the `Makefile`, `pyproject.toml`, or the CI workflow, and take the
lint, format, and typecheck entries. Run each in the mode that reports without
writing, so `eslint` with no `--fix` and `prettier --check` rather than the
forms that edit files. Check mode keeps the review from editing the diff it
just pinned, and anything the tooling already catches stays out of the review.

Record that this repo has no such tooling when the search turns up none, and
carry on to step 4. A repo of prose or config often has nothing to run, and
that is an answer rather than a blocked step.

**Done when:** the standards files are listed by path or the review records
that this repo documents none, and every check command found is listed with
its exit code, or the review records that the repo has none.

## Step 4: Review the diff

Read every changed file in full, not only the hunks. A hunk shows the change
and hides what the change now sits next to.

Check it against the standards from step 3 first. A documented repo standard
wins over anything below.

Then check it against this baseline, which holds whether or not the repo
documents anything:

| Smell | What it looks like in the diff | The fix |
|---|---|---|
| Mysterious name | A name that does not say what the thing does or holds | Rename it. When no honest name comes, the design is unclear, so say that instead |
| Duplicated code | The same logic shape in two hunks or two files | Extract the shape, call it from both |
| Feature envy | A function that reaches into another object's data more than its own | Move the function next to the data it uses |
| Data clumps | The same few parameters travelling together everywhere | Give them one type and pass that |
| Primitive obsession | A `string` or a `number` standing in for a domain concept | Give the concept its own type. See the `ts-types` skill for brands |
| Repeated switches | The same `switch` on the same field in several places | One map both sites share, or polymorphism |
| Shotgun surgery | One logical change forced edits across many files | Gather what changes together into one module |
| Divergent change | One file edited for several unrelated reasons | Split it so each module changes for one reason |
| Speculative generality | Options, hooks, or abstraction the stated intent does not need | Delete it and inline back until a real caller shows up |
| Message chains | `a.b().c().d()` walked by a caller that should not know the shape. A fluent builder such as a Mongoose query or a promise chain is not this | Hide the walk behind one method on the first object |
| Middle man | A function or class that only delegates onward | Call the real target directly |
| Refused bequest | A subclass or implementer that ignores most of what it inherits | Use composition |

The smells are judgement calls. Label each one as a judgement call, and label
a broken documented standard as a violation. The difference is what tells the
reader which findings to argue with.

Four things are worth a specific look, each one where the diff has them:

- Entry points that trust their input: route handlers, controllers,
  middleware, message consumers, CLI argument parsing. See the
  `api-boundaries` skill for where the edge is.
- `as` casts and `any` added by the diff, in a TypeScript repo. See the
  `ts-types` skill.
- Database queries written inline in an entry point rather than behind a
  repository or a service.
- New `await` inside a loop where the calls are independent.

To fork this for one repo, name that repo's real frameworks in these four
lines. A generic skill cannot know them. A fork can.

### Claims

Prose is the code's twin and rots the same way. For every sentence the diff
adds or changes that says what something does, name the `file:line` that makes
it true. A sentence with nothing behind it is a finding, and so is one whose
backing line says something narrower than the sentence claims.

The strings a script prints are claims as well. `costs 0 characters` is a
sentence about behaviour that happens to be printed rather than written down.

Three shapes cover most of them:

- **Half a system.** The diff changed one of two commands, and a sentence
  above them still describes both.
- **A twin left behind.** One fact sits in a comment, a heading, and a README,
  and the diff updated one of the three. Search for the fact, not for the file
  you were already in.
- **A mechanism nobody checked.** "A hook costs context in tool schemas" reads
  plausibly and is wrong. An explanation of why something behaves as it does
  needs a source the same way a measurement does.

**Done when:** every changed file has been opened in full, each finding names
the standard or the smell it came from, and every behavioural claim the diff
adds or changes either has a `file:line` behind it or is one of the findings.

## Step 5: Check the diff against the intent

Only when step 2 produced a line of intent. Three questions:

- What did the intent ask for that the diff does not do?
- What does the diff do that the intent did not ask for?
- What looks implemented but does the wrong thing?

**Done when:** each of the three questions has an answer, including "nothing".

## Step 6: Report

Group findings by file. For each one:

- `file:line`
- What is wrong, in one sentence
- Violation of a named standard, or judgement call on a named smell

When step 5 ran, keep its findings under their own heading rather than mixed
in, because "this breaks a convention" and "this builds the wrong thing" are
for different readers.

Close each heading with its own count and its own worst finding. Neither
heading's worst outranks the other's, because ranking the two together is the
mixing the separate headings exist to prevent.

**Done when:** every finding has a `file:line` and a named source, and each
heading holding findings ends on its own count and its own worst one.

---

Adapted from the `code-review` skill in mattpocock/skills (MIT), with the
parallel sub-agents removed and the spec axis folded in as step 5. The smell
baseline is condensed from Martin Fowler, *Refactoring*, chapter 3.
