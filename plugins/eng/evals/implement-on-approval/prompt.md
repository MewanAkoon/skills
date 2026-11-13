---
name: implement-on-approval
description: An approved plan loads eng:implement.
tags: [trigger]
runs: 1
max_turns: 3
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---

The plan we agreed is approved. Go ahead and implement it: rename getUser to fetchUser everywhere it is used.
