---
name: no-issue-on-look-into
description: Working on an issue goes to eng:investigate, not eng:issue.
tags: [trigger]
runs: 1
max_turns: 3
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---

Look into issue 42 in this repo and tell me what it would take to fix.
