# Writing rules

The standard every skill in this repo follows. Read it before writing a new
one, and check an edited one against it before committing.

## Where a skill comes from

Write a skill when you have corrected an agent on the same thing three times.
Not before.

A skill written from a blog post will never fire, because you borrowed the
trigger conditions along with the content. A skill written from your own
repeated correction fires, because the situation that produced it is a
situation you are actually in.

## The description

This is the only part loaded on every turn, and it is the only thing that
decides whether the skill runs. Write it first, on its own, before the body.

- Front-load the trigger. Start with the condition, not with what the skill
  is.
- List each distinct case once. Three synonyms for the same case is one case
  written three times, and it costs three times the tokens.
- Be slightly pushy. Agents under-trigger skills more often than they
  over-trigger them.

Fires:

```yaml
description: Use when reading or editing any .ts or .tsx file, designing a type, or reviewing a function signature.
```

Does not fire:

```yaml
description: A comprehensive guide to TypeScript type system best practices.
```

## Invocation

One question decides it: could the agent usefully reach for this on its own?

**Yes, model-invoked.** Omit `disable-model-invocation`. The description
carries triggers. Costs permanent context.

**No, user-invoked.** Set `disable-model-invocation: true`. The description
becomes a plain one-line summary for a human browsing slash commands. Costs
nothing.

What caps the model-invoked set is conflict, not count. A description costs
about seventy tokens, so the whole set is a few hundred. A false fire costs
far more, because the agent reads an entire `SKILL.md` and then follows the
wrong procedure.

So the test is competition, not overlap. Two skills compete when they claim
the same decision and the agent has to pick one. Two skills compose when they
govern different parts of the same moment, and both should run. `commit`
owns how a commit is staged and structured. `plain-writing` owns how the
message reads. Both firing on one commit is the intended outcome.

Before adding a model-invoked skill, read every description already in the
set and look for a prompt where the new skill and an existing one would give
conflicting instructions. When you find one, narrow the new description until
they no longer collide, move the overlapping part into the existing skill's
`references/`, or demote something. To print the set as it stands:

```bash checked
grep -L '^disable-model-invocation:[[:space:]]*true[[:space:]]*$' skills/*/SKILL.md | xargs -r grep -h '^description:'
```

It lists only what an agent can reach on its own, because a user-invoked
skill competes with nothing until someone types its name. The pattern is the
one `check.sh` uses to decide the same question, so the two agree on a file
whose flag carries extra spacing.

Claude Code and Cursor both read `disable-model-invocation`. The Agent Skills
spec allows only `name`, `description`, `license`, `compatibility`,
`metadata`, and `allowed-tools`, so a strict validator rejects the flag
outright. That is the trade a user-invoked skill makes: it works in both
harnesses from disk, and it will not upload to claude.ai.

An agent that does not read the flag treats the skill as model-invoked. So
for anything that must not auto-fire, also keep the description free of
trigger phrases. The flag alone is not a guarantee.

## Tool access

Two frontmatter fields govern tools and they pull in opposite directions.

`allowed-tools` grants. It pre-approves the listed tools for the turn that
invokes the skill, so they run without a permission prompt. Every other tool
stays callable, and the grant clears on your next message. Reach for it when a
skill runs a bundled script and the prompt would be noise.

`disallowed-tools` restricts. It takes the listed tools out of the pool while
the skill is active. Reach for it when a skill must not do something, so the
limit holds whatever the body says. `review-diff` lists `Edit, Write,
NotebookEdit` for that reason: a review that can edit the diff it just pinned
is reviewing a moving target.

Name only what the skill can do without. `review-diff` keeps `Bash`, because
its first step runs `git diff` and its third runs the repo's own lint
commands. A restriction that breaks the skill gets deleted the first time it
bites.

`disallowed-tools` is a Claude Code field, and the trade is worse than the one
`disable-model-invocation` makes. Cursor reads that flag; its frontmatter has
no `disallowed-tools` and no `allowed-tools`, so a skill leaning on either is
restricted in one harness and wide open in the other. Both fields also sit
outside the Agent Skills spec, so the skill will not upload to claude.ai.

Write the body so the skill is right without the field, then add the field as
a second lock. A limit that holds in only one of the two harnesses this repo
links into is not one the body can leave unsaid.

## Structure

Every skill opens with three short headings, in this order:

- **What this does.** Two or three sentences.
- **When it runs** or **When to use it.** Including when to skip it.
- **How to use it.** What the human types and what comes back.

Then the body. Someone reading the file cold should not have to infer
anything.

## The body

**Steps are ordered actions. Reference is what gets consulted.** Both can
appear in one skill. What matters is that the main file holds only what every
run needs.

**Anything only some runs reach goes in `references/`,** pointed to from
`SKILL.md` with a line saying when to read it. Keep `SKILL.md` short enough to
read in one sitting.

**Every step ends on something checkable.** "Every route handler has a parse
call at the top" is verifiable. "Validation is handled properly" is an
invitation to stop early. Vague completion criteria are the main reason
agents quit halfway.

**An end condition admits every ending its step has.** A step that can stop
early has more than one ending, and the condition has to name them all. "The
probe printed nothing and there is at least one changed path" locks out the
step's own "nothing to commit" exit, so an agent that hits it either loops
looking for a state that will not arrive or drops the condition and moves on.
Both are worse than having no condition, because the line looks like a check
and is not one.

Write the stops in: "..., or the run has stopped with its reason named, which
is X or Y." Before writing the condition, list the step's endings, then read
the condition back against that list. A condition that names one ending for a
step that has three is the most common way this rule gets broken, and it
survives review because the sentence reads fine on its own.

**Say what to do, not what to avoid.** A prohibition pulls the banned
behaviour into context and makes it more available, not less. Write "return
early on invalid input", not "do not nest conditionals". Keep a ban only when
you cannot phrase it positively, and pair it with the positive target.

**Delete any line the model would follow anyway.** Read each sentence and ask
whether it changes behaviour compared to the default. "Be thorough" does not.
"Every modified collection accounted for" does. Delete the whole sentence
when it fails, do not trim words from it.

**Say each thing once.** One fact, one place. A duplicated fact costs tokens
and one copy is already stale.

## Prose style

The full standard is in `skills/plain-writing/SKILL.md` and it applies to
skill files too. The short version:

- No em dashes. Split the sentence or use a comma. Not parentheses instead.
- Active voice, name the actor.
- Plain words. No "leverage", "robust", "comprehensive", "crucial",
  "seamless", "utilize".
- No "It is important to note that". No "In order to".
- Sentence case headings. Straight quotes. No emoji.
- One idea per sentence.

## Attribution

A skill adapted from somewhere else ends with one line naming the source and
its licence. Six months from now you will want to diff against upstream and
you will not remember which files were yours.

## Before committing

Run `./scripts/check.sh`. It covers the mechanical half, listed in
[AGENTS.md](AGENTS.md).

Then read the skill back and check the half no script can:

1. The description would fire on a real prompt you would actually type.
2. Every step has a checkable end condition that admits every ending the step
   has, stops included, or the skill is pure reference and has no steps.
3. No sentence states a default the model already follows.
4. Reference material that only some runs need is in `references/`.
5. No filler, no banned words.

## After committing

Run the skill twice, in two fresh sessions, on the same prompt. If the
behaviour differs, a step is underspecified, and it is almost always a vague
completion criterion. Fix that one step and nothing else.

## Keeping skills

A skill stays until you remove it deliberately. Nothing here deletes one for
going unused, however long it stays quiet. Keep a skill written for a case
that has not come up yet.

`./scripts/fired.sh` counts the firings. Read a zero as a question about the
description or the linking, and answer it with `./scripts/check.sh --doctor`,
because a skill that is not linked cannot fire.
