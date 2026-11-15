---
name: issue-asks-to-connect
description: An issue run whose tracker has no tools in the session names the server to connect and drafts nothing.
tags: [content]
runs: 1
max_turns: 15
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write]
---

File an issue for this: the CSV export in export.sh crashes when the list is empty.
