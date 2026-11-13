---
name: issue-draft-fields
description: An issue draft names its assignee and carries the estimate section, with no AI credit.
tags: [content]
runs: 1
max_turns: 15
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write]
---

File an issue for this: the CSV export in export.sh crashes when the list is empty.
