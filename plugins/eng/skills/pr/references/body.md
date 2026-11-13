# The PR body template

Read this in step 5 when step 4 found neither a template nor a body format,
and in step 4 for the Evidence or Merge danger section a format lacks.

````
## What and why
<!-- One paragraph. What changed and why, not how. -->
<one paragraph summary>

## Type of change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactor (no behaviour change)
- [ ] Dependency update
- [ ] Config / infra / env change
- [ ] Documentation

---

## Evidence
<!-- Before and after from a real run: the test that failed and now passes, or output that changed. -->
- Before: <command and what it printed>
- After: <command and what it prints now>

**How to review locally:**
```sh
# Commands to run and verify this PR
```

---

## Merge danger
<!-- Whether a revert undoes this, how far a break would reach, where to look hardest. -->
- Door: <one-way or two-way>, because <reason>
- Blast radius: <small, medium, or wide>, <what could break>
- Look hardest at: <file or area>

## What did you deliberately not do?
<!-- Scope decisions, known trade-offs, follow-up tickets -->
- <deliberate omission>
````

Tick the boxes that apply under Type of change, and replace the comment under
"How to review locally" with the commands a reviewer runs. A template shipped
with every box empty is worse than no template.
