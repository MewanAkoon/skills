---
type: llm
focus: trace
---

Judge the issue the agent drafted, in the files it wrote and its final reply.

PASS only if all of these hold:

- The draft names the user, or the person filing, as the assignee.
- An "Estimate and priority" section gives a priority of Urgent, High,
  Medium or Low with a one-line reason.
- It gives an effort of Low, Medium or High and story points of 1, 2, 3, 5
  or 8.
- It splits the time into plan, implement, test, PR and review, merge, and
  final test, with a total and how much needs the user.
- It gives a due date, or "none" with a reason.
- It gives a recommended approach in two to four lines.

FAIL if any is missing.
