---
name: commit-on-request
description: A request to commit loads eng:commit.
tags: [trigger]
runs: 1
max_turns: 3
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---

Commit the changes I just made to the pricing module.
