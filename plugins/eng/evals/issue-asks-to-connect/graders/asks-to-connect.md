---
type: llm
focus: trace
---

Judge the agent's final reply and the files it wrote.

PASS only if all of these hold:

- The reply says the repo's tracker is Jira and that its MCP server is not
  in the session.
- It asks the user to connect Jira's MCP server, or an Atlassian one, and
  try again.
- It files nothing and writes no issue draft, though it may offer a
  copy-paste draft in case the server cannot be connected.

FAIL if any is missing, or if it drafted or filed the issue anyway.
