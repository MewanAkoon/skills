# The PR body template

Read this when step 4 found neither a template nor a body format, or for the
Evidence or Merge danger section a format lacks.

````
## What and why
<!-- What changed and why, not how. -->
<one paragraph>

## Type of change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactor (no behaviour change)
- [ ] Dependency update
- [ ] Config / infra / env change
- [ ] Documentation

## Evidence
- Before: <command and what it printed>
- After: <command and what it prints now>

**How to review locally:**
```sh
<commands a reviewer runs>
```

## Merge danger
- Door: <one-way or two-way>, because <reason>
- Blast radius: <small, medium, or wide>, <what could break>
- Look hardest at: <file or area>

## What did you deliberately not do?
- <deliberate omission>
````

Tick the boxes that apply. Every section holds real content or is deleted.
