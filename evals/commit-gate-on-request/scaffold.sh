#!/usr/bin/env bash
# A repo with one commit and one uncommitted change to commit.
set -euo pipefail
git init -q
git config user.name eval
git config user.email eval@example.com
echo "# notes" > NOTES.md
git add -A
git commit -qm "add notes"
echo "- the export button crashes on an empty list" >> NOTES.md
