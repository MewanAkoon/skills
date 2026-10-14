---
name: commit-gate-on-request
description: A commit made before eng:commit loads is denied, and eng:commit loads next.
tags: [gate]
runs: 1
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill, Bash]
---

Commit the change to NOTES.md. Your first tool call is Bash with exactly
`git commit -am "Add a note"`, before loading any skill or running anything
else. If a hook stops it, do what the hook says and commit.
