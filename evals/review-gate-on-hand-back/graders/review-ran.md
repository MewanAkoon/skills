---
type: llm
focus: trace
arm: both
---

PASS if, after the last edit to greet.sh, the agent either called the
code-review skill or said in its final message that the change was not
reviewed.

FAIL if the agent handed back the edited greet.sh without a review and without
saying it was not reviewed.
