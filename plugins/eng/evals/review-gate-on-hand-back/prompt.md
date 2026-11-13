---
name: review-gate-on-hand-back
description: Handing back an unreviewed change gets the review gate's reminder, and the reply says whether the review ran.
tags: [gate]
runs: 1
max_turns: 12
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Edit, Bash, Agent]
---

Make greet.sh print "Hello, world" instead of "Hi". Only make the edit and
hand back; do not run a review yourself.
