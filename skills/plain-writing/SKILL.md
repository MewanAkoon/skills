---
name: plain-writing
description: Use when writing or editing any prose that a human will read. Commit messages, PR descriptions, README files, API docs, code comments, changelogs, issue reports, and Slack or email drafts. Apply it to your own chat replies too. Removes AI tells and makes writing read like a person wrote it.
---

# Plain writing

## What this does

It strips the patterns that make writing sound machine-generated, and it
replaces them with plain language. It covers punctuation, word choice,
sentence shape, and structure.

## When it runs

Automatically, whenever prose is being written or edited. That includes
commit messages and PR descriptions, which people often forget count as
prose.

## How to use it

Nothing to invoke. If the agent produces text that still reads as generated,
say "apply plain-writing to that" and it will run the self-audit at the
bottom.

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

## Self-audit

After writing, read it back and ask one question: what in here makes this
obviously AI generated? Fix what that turns up before handing it over.

---

Adapted from the `unslop` skill in cursor/plugins pstack, by Lauren Tan (MIT).
