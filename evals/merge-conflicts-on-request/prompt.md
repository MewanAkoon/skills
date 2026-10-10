---
name: merge-conflicts-on-request
description: A request to resolve conflicts loads eng:merge-conflicts.
tags: [trigger]
runs: 1
max_turns: 3
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---

My rebase onto main stopped with conflicts in src/cart.ts and src/price.ts. Resolve them and finish the rebase.
