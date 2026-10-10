#!/usr/bin/env bash
# A small repo with an uncommitted change and a test that depends on the clock.
set -euo pipefail
git init -q
git config user.name eval
git config user.email eval@example.com
cat > format.sh <<'SH'
#!/usr/bin/env bash
# Prints today's date as YYYY-MM-DD.
date +%Y-%m-%d
SH
cat > test.sh <<'SH'
#!/usr/bin/env bash
# Fails when the minute changes between the two calls.
[ "$(./format.sh) $(date +%M)" = "$(date +%Y-%m-%d) $(date +%M)" ]
SH
chmod +x format.sh test.sh
git add -A
git commit -qm "add the date formatter"
echo "# notes" > NOTES.md
