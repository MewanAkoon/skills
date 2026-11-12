# Filing, editing, and closing

Read this at issue's step 6, once the write was asked for, as `SKILL.md`'s
"When it runs" says.

Step 5's command files the issue. These edit or close one:

```bash
gh issue edit <n> --repo <owner/repo> --add-label <name>
gh issue close <n> --repo <owner/repo> --reason "not planned"
gh issue close <n> --repo <owner/repo> --duplicate-of <m>
```

Then read the issue back. GitHub drops labels silently when the account lacks
the access to set them:

```bash
gh issue view <n> --repo <owner/repo> --json number,url,title,labels,state
```
