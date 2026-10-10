---
name: issue-on-file-request
description: A request to file an issue loads eng:issue.
tags: [trigger]
runs: 1
max_turns: 3
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---

File an issue for this: the CSV export button crashes when the list is empty.
