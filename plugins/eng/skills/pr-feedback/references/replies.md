# Posting commands for the drafts

Read this at pr-feedback's step 5, for the command under each reply.

Each command posts its reply from the clipboard: `pbpaste` on macOS,
`wl-paste` or `xclip -selection clipboard -o` elsewhere. A reply in a review
thread, where `<databaseId>` is the thread's first comment:

```bash
pbpaste | gh api repos/<owner>/<repo>/pulls/<n>/comments/<databaseId>/replies -F body=@-
```

A reply to a review body or an issue comment, which has no thread:

```bash
pbpaste | gh pr comment <n> --body-file -
```
