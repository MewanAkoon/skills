# The findings ledger

Read this at section 3 of [review.md](review.md), every round.

Keep `$R/ledger.md`, one line per finding, across every round of the loop:
the round, `file:line`, the point in a few words, the two marks, and what
was done: fixed, left with its reason, or moved to follow-ups.

Before fixing a finding, read the ledger:

- A finding that asks to undo or reshape an earlier fix, or to reverse a
  ruling, is a judgement call. It goes in the report with both sides, and
  the code stays as it is.
- A finding the ledger already shows as invalid or left stays that way
  unless it brings new evidence, such as a failing run.
- A finding about code the change did not touch, or an improvement the plan
  did not ask for, goes to follow-ups, not the code.

So each round only adds fixes, and no round undoes another.

Count the open valid findings after each round. When two rounds in a row
fail to lower the count, the loop is not converging, and section 4 stops it.
