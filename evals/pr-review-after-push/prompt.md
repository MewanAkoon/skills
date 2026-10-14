---
name: pr-review-after-push
description: A push gets the reminder to review the whole PR at high, and the reply says whether that review ran.
tags: [gate]
runs: 1
max_turns: 16
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Edit, Bash, Agent]
---

The change to greet.sh is done and reviewed. Commit it and push the branch.
