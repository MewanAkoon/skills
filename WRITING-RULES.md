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

Adapting a skill from elsewhere is fine, and every skill here started that way.
What does not carry over is the description. Keep the body, throw the
description away, and write a new one from the prompts you actually type. The
content is worth borrowing; the trigger has to be yours.

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
nothing in Claude Code.

Keep the model-invoked set to four or five. When a sixth is worth having,
demote one first.

`disable-model-invocation` is a Claude Code field. Cursor does not read it, so
in Cursor every skill here is model-invoked and every description is loaded.
The description is therefore the only thing keeping a user-invoked skill from
firing on its own, and it has to carry no trigger condition. Write it as a noun
phrase naming what the skill produces. The flag protects one tool of the two.

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

A skill adapted from somewhere else names the source and its licence on the
last line of `SKILL.md`. One line per skill, not per file, so files under
`references/` inherit it. Six months from now you will want to diff against
upstream and you will not remember which files were yours.

## Before committing

Every rule below still holds whether or not you run the script. `./check.py`
exits non-zero on the first group, apart from item 4 which warns, so you do not
have to hold those in your head. Nothing runs it for you: there is no commit
hook, and adding one is your call. Read the rules anyway before writing,
because a rule you know is a rule you do not trip over.

Checked by `./check.py`:

1. No em dashes, en dashes, or horizontal bars, and no HTML entity that
   renders as one, in any Markdown, YAML, text, shell, or Python file.
   `check.py` is exempt, because it holds those characters as data in order to
   search for them.
2. No banned words and no filler phrases in Markdown, YAML, or text files,
   outside the two that quote the lists in order to ban them: this file and
   `plain-writing/SKILL.md`. Shell and Python are checked for dashes only,
   because an identifier is not prose and `plain-writing` says so.
3. The three opening headings, in order, and a skip condition somewhere in
   the second one.
4. An attribution line on the last line of `SKILL.md`. The script warns here
   instead of failing, because a skill you wrote yourself has no source to
   name. Read the warning and confirm that is the case.
5. A row in the README table.
6. Frontmatter `name` matching the directory name, and a description that is
   not empty.
7. A user-invoked skill's description names no trigger condition: no opening
   condition, no "use this for" or "reach for", no temporal word followed by
   an activity such as "before writing".
8. Every file in `references/` is linked from `SKILL.md`.
9. Five model-invoked skills at most.

The script also warns when `~/.claude/CLAUDE.md` is missing the prose block
from step 2 of the README's setup. That is machine state rather than repo
state, so it is a warning and never a failure: a fresh clone, a CI run, and
anyone else's machine all lack the file. Set `CLAUDE_CONFIG_DIR` if your Claude
config lives somewhere else.

Judged by you, because no script can:

10. The description would fire on a real prompt you would actually type. Say
    that prompt out loud, then read the description against it word by word.
    If you are guessing, you have not tested it.
11. Every step ends on something checkable, or the skill is pure reference and
    has no steps. A step that ends on "handled properly", "as appropriate", or
    "make sure it is correct" is the step that will be skipped. Rewrite it as
    a thing you could see on a screen.
12. No sentence states a default the model already follows. Read each one and
    ask what an agent would do without it. Delete the whole sentence when the
    answer is "the same thing".
13. Reference material that only some runs need is in `references/`, pointed
    to by a line saying when to read it, not just that it exists.

## After committing

Run the skill twice, in two fresh sessions, on the same prompt. If the
behaviour differs, a step is underspecified, and it is almost always a vague
completion criterion. Fix that one step and nothing else.

## Pruning

No tool reports which skills fired, so the test is recall, not a log. Every
two weeks, read the README table and name one real occasion each skill changed
what an agent did. A skill you cannot place a use for goes.

Model-invoked skills go first. One that never triggers is not neutral, its
description costs tokens on every turn of every conversation. Demote it to
user-invoked before deleting it, and delete it if you never type it either.
