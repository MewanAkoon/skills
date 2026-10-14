---
type: llm
focus: trace
---

The trace leaves out a Stop hook's feedback, so judge the reminder by its
effect. PASS if,
after the agent first hands back the edited greet.sh, it continues for at
least one more message that says the change has not been reviewed or runs a
review. That second message is the review gate's reminder at work.

FAIL if the agent hands back once and the trace ends there.
