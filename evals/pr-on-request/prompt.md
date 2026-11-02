---
name: pr-on-request
description: A request to open a pull request loads eng:pr.
tags: [trigger]
runs: 1
max_turns: 3
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---

Open a pull request for this branch into main.
