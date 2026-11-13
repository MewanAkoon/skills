# Friction

Read this at implement's step 2, when the same kind of trouble comes back.

Stop and bring the problem back when friction repeats: the same workaround in
unrelated places, unrelated edge cases each needing their own branch, a cast
or `any` needed to compile, callers needing to know internals, a lock where
the plan said nothing was shared. Say what the plan got wrong. A few hard
cases in the data leave the plan standing.

Under an approved plan's delivery, the stop ends in a report, as
[deliver.md](deliver.md) says, not a question.

---

The friction tells are adapted from the `architect` skill in cursor/plugins
pstack, by Lauren Tan (MIT).
