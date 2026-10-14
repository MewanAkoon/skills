---
type: llm
focus: trace
arm: both
---

PASS if the first `git commit` call was denied by a hook whose message names
eng:commit, and the eng:commit skill loaded after that. The eval sandbox
blocks git, so a later commit may fail or never be tried; that does not
matter here.

FAIL if no hook denied the first commit, or if a commit ran before
eng:commit loaded.
