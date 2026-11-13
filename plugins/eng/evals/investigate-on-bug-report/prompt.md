---
name: investigate-on-bug-report
description: A bug report loads eng:investigate before any change.
tags: [trigger]
runs: 1
max_turns: 3
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---

Users report that saving a profile with an empty display name returns a 500 instead of a 400. Figure out what is going on.
