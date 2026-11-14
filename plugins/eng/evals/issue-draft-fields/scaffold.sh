#!/usr/bin/env bash
# A repo tracked in Jira, with no Jira tools in the session. The prompt says
# the server cannot be connected, so the draft takes the copy-paste path and
# every field lands in a file.
set -euo pipefail
git init -q
git config user.name eval
git config user.email eval@example.com
cat > AGENTS.md <<'MD'
# Agent instructions

Work here is tracked in Jira, project WEB. Story points are 1, 2, 3, 5 or 8.
MD
cat > export.sh <<'SH'
#!/usr/bin/env bash
# Prints the rows given as arguments as CSV, with a header from the first.
set -euo pipefail
header="$1"
shift
printf '%s\n' "$header" "$@"
SH
chmod +x export.sh
git add -A
git commit -qm "add the CSV export"
