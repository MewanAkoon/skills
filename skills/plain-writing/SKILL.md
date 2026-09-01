---
name: plain-writing
description: Use before sending any reply longer than two sentences, and before writing or editing any prose a human will read. Your own chat answers, explanations, and summaries come first, because answering does not feel like a writing task and that is the case most often missed. Also commit messages, PR descriptions, docs in a repo, code comments, changelogs, issues, and message drafts. Removes AI tells and makes writing read like a person wrote it.
---

# Plain writing

## What this does

It strips the patterns that make writing sound machine-generated, and it
replaces them with plain language. It covers punctuation, word choice,
sentence shape, and structure.

## When it runs

Whenever prose is being written or edited. Your own replies in the
conversation count, and they are the case that gets missed, because answering
does not feel like a writing task. Any answer longer than two sentences is
prose someone reads.

Commit messages, PR descriptions, and code comments count too, and people
forget those are prose as well.

## How to use it

Nothing to invoke. The self-audit at the bottom runs on the text before it is
sent, not after someone complains about it.

---

## Punctuation

Never use em dashes. When a sentence reaches for one, split it into two
sentences or use a comma. Do not swap in parentheses or en dashes instead,
that trades one tell for another.

Use colons before a list or an example. Not as a mid-sentence connector.

Use straight quotes. Use sentence case for every heading. Leave emoji out of
headings and bullets.

## Word choice

Replace these with plain words every time they appear: additionally, crucial,
delve, enhance, robust, leverage, utilize, facilitate, seamless,
comprehensive, pivotal, underscore, showcase, testament, intricate,
landscape (as a metaphor), tapestry, ecosystem (as a metaphor), garner.

Reach for the plain word under a technical-sounding metaphor. Substrate
becomes base, wedge in becomes add, vector becomes way, gold-plating becomes
more than the job needs, evacuate becomes move out, endgame becomes the last
phase, and ratchet becomes the mechanism's real name or a limit that only
tightens. Write "the API" rather than "the API surface". Also drop nexus,
locus, bedrock, paradigm, modality, vantage, north star, flywheel,
scaffolding as a metaphor, and primitive as a noun.

Use "is" and "has" directly. "Serves as", "stands as", "boasts", and
"features" are longer ways of saying the same thing.

Delete these phrases: "It is important to note that", "It is worth
mentioning", "In order to" (use "to"), "Due to the fact that" (use
"because"), "In the event that" (use "if").

Delete chatbot filler: "I hope this helps", "Let me know if", "Great
question", "You're absolutely right", "Certainly".

## Sentences

Write in active voice and name the actor. "The compiler validates the query",
not "the query is validated". Passive is fine only when the actor genuinely
does not matter.

One idea per sentence. If a reader has to go back to parse a sentence, break
it in two.

Cut adverbs or use a stronger verb. "Runs quickly" becomes "is fast" or the
actual number. An adverb propping up a weak verb means the verb is wrong.

Cut a trailing -ing clause that carries no fact: "highlighting the need
for", "ensuring reliability", "reflecting the team's priorities". State the
fact it gestures at, or delete the clause. This one slips past the other
rules, because it is active voice, one idea, and contains no banned word.

State the point directly instead of writing "not just X, but Y".

Say what something does, not how it feels. "Types that follow your schema"
names a feeling. "A column rename fails the build" names the mechanism. If a
sentence cannot be restated as a concrete fact, instruction, or number, cut
it.

If a sentence could appear unchanged in another project's docs, it says
nothing about this project. Cut it.

## Structure

Group ideas by the natural number, not by three. The rule of three is a tell
when the third item was invented to fill the pattern.

Pick one term for a thing and repeat it. Cycling through synonyms for the
same concept makes the reader wonder whether you mean something different.

Write "**Schema in TypeScript.** Tables live in one file." That is a bold
lead-in followed by new detail, which is fine. Do not write "**Performance:**
Performance improved by 20%", where the label restates the line. Convert
those to prose.

Bold sparingly. Not every proper noun and acronym.

## Named sources only

Name the source or delete the claim. "Experts believe", "industry reports
suggest", and "some critics argue" are all placeholders for a citation you do
not have.

End on a specific fact or a next step. "The future looks bright" and similar
closers say nothing.

## Code comments

A comment in source code has to pass two checks the rest of this file does
not cover: whether it earns its place at all, and whether every reference in
it still resolves for someone with a fresh clone.

Read [references/code-comments.md](references/code-comments.md) before
writing or editing any comment in code. Skip it for every other kind of
prose.

## Self-audit

After writing, read it back and ask one question: what in here makes this
obviously AI generated? Fix what that turns up before handing it over.

---

Adapted from the `unslop` skill in cursor/plugins pstack, by Lauren Tan (MIT).
