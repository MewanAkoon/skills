# An operation in flight

Step 2 reads this when its second or third command prints anything.

A hit on the second command means a merge, rebase, cherry-pick, or revert is
mid-flight. Stop and say which one. `HEAD` is part way through the operation,
so the diff you would describe is not the diff that will land, and a rebase
still to finish rewrites every commit the PR would show. The
`eng:merge-conflicts` skill finishes the operation once the user asks for it.

Any path the third command lists stops the run the same way, even with no
operation in flight, which is the state `git apply --3way` leaves behind. That
probe reports every unmerged path, including the `AA` and `DD` cases that
carry no `U` in the status output.

**Done when:** the run has stopped with the operation in flight, or the
unmerged paths, named.
