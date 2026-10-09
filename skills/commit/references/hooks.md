# What a pre-commit hook did

Read this when step 7's three checks do not all hold: `git commit` failed, a
partly staged path's hash changed, or `git status --porcelain -uall` lists a
path beyond the snapshot's in-progress entries.

## Reading the snapshot

Step 6 defines the in-progress entries and the partly staged paths. Leave the
in-progress entries alone. Anything else that appears after the commit came
from a hook. A hook can rewrite a partly staged path and leave its status
letters exactly as they were, which is why step 6 hashed its held-back lines.
The hash covers only those lines: when a hook rewrites the staged lines, as
lint-staged does, the diff's index header and hunk headers change, and so do
its context lines when the rewrite lands near a held-back line, so all three
stay out of it. `--no-color` and `--no-ext-diff` keep a colour setting or an
external diff tool from changing the lines the grep reads.

## The cases

Check the first case before the others, whether the hook passed or failed.

- **Hook rewrote a partly staged path.** Step 6's command prints a different
  hash for its held-back lines from the one the snapshot kept. The hook's fix
  now sits in the same unstaged diff as the lines the user held back, and
  staging the file whole would commit those lines too. Stage nothing more,
  print the hook output, name the path, and stop. Tell the user to stage the
  hook's lines in that file themselves, for example with `git add -p <path>`.
- **Hook failed and files were modified.** The hook fixed things itself.
  Re-stage every path that now carries unstaged content and was not an
  in-progress entry in the snapshot. A file the snapshot held fully staged that
  has picked up a second status letter is the hook's work, whether that reads
  `MM` for an edit or `AM` for a file this change adds. Retry the commit once.
  When the retry fails too, print its output, stop, and tell the user what to
  fix.
- **Hook failed and nothing was modified.** A real failure, such as a type
  error or a lint rule with no autofix. Print the hook output, stop, and tell
  the user what to fix, without retrying.
- **Hook passed but files were modified or created.** A hook rewrote files
  silently. Run `git status --porcelain -uall` again, ignore the snapshot's
  in-progress paths, and stage what is left. Commit it with a message in the
  shape step 3 picked and the scope step 4 derives from these paths, written
  to step 5's rules. In a conventional commits repo, fixes under `src/auth/`
  give `chore(auth): apply auto-fixes`.

**Done when:** `git status --porcelain -uall` lists no path beyond those of
the snapshot's in-progress entries, or the run has stopped with the hook
output printed for the user to fix, which is a partly staged path that the
hook rewrote and the run left unstaged, a hook failure that changed no files
and left the staged change exactly as it was, or a retry that failed after the
hook rewrote files and those files were re-staged.
