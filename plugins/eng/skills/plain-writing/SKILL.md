---
name: plain-writing
description: Use before writing prose a person will read outside this chat, such as a doc, README, commit message, PR or issue body, code comment, changelog, or message draft, and before a reply longer than three paragraphs. Removes AI tells.
---

# Plain writing

The Punctuation and Word choice sections reach every session through the
`eng` plugin's hook. The rest applies to prose that outlives the chat,
commit messages, PR and issue bodies and code comments included, and to a
reply longer than three paragraphs. Skip text a program reads, and text
quoted word for word.

## Punctuation

Never use em dashes. When a sentence reaches for one, split it into two
sentences or use a comma. Do not swap in parentheses or en dashes instead.
That trades one tell for another.

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
question", "Good catch", "You're absolutely right", "Certainly".

## Sentences

Write in active voice and name the actor. "The compiler validates the query",
not "the query is validated".

One idea per sentence. Cut adverbs: "runs quickly" becomes the number.

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

A bold lead-in earns its place by adding new detail after it:
"**Schema in TypeScript.** Tables live in one file." A label that restates
its line, as in "**Performance:** Performance improved by 20%", becomes prose.
Bold sparingly.

## Named sources only

Name the source or delete the claim. "Experts believe", "industry reports
suggest", and "some critics argue" are all placeholders for a citation you do
not have.

End on a specific fact or a next step. "The future looks bright" and similar
closers say nothing.

## Code comments

Before writing or editing a comment in code, read
[references/code-comments.md](references/code-comments.md). It holds two
checks: whether the comment earns its place, and whether everything it points
at resolves from a fresh clone.

## Self-audit

After writing, read it back and ask one question: what in here makes this
obviously AI generated? Fix what that turns up before handing it over.

---

Adapted from the `unslop` skill in cursor/plugins pstack, by Lauren Tan (MIT).
