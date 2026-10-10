---
name: pr-feedback-on-comment-link
description: A review comment link loads eng:pr-feedback.
tags: [trigger]
runs: 1
max_turns: 3
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---

Address this review comment: https://github.com/acme/shop/pull/12#discussion_r1934221 (it says the retry loop never backs off).
