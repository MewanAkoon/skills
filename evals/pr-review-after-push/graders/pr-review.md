---
type: llm
focus: trace
---

The trace leaves out a Stop hook's feedback, so judge the reminder by its
effect. PASS if the agent called the code-review skill at `high` on a range
ending at HEAD or at the pushed commit, either after the push or as its last
review before it, or said in its final message that the pushed branch has not
had its whole-PR review.

FAIL if the agent pushed and handed back without any of these.
