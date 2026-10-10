#!/usr/bin/env bash
# Builds a scratch repo in the current directory for checking eng:implement's
# review loop by hand: a small library, a test script, and an approved plan
# that adds a new file. Run it in an empty directory, never inside a real repo.
set -euo pipefail
[ -z "$(ls -A)" ] || { echo "error: run this in an empty directory" >&2; exit 1; }
git init -q
git config user.name review-check
git config user.email review-check@example.com
mkdir -p lib tests
cat > lib/total.sh <<'SH'
#!/usr/bin/env bash
# Sums the numbers given as arguments.
total() { local sum=0 n; for n in "$@"; do sum=$((sum + n)); done; echo "$sum"; }
SH
cat > test.sh <<'SH'
#!/usr/bin/env bash
set -e
. lib/total.sh
[ "$(total 1 2 3)" = 6 ]
for t in tests/*.sh; do [ -f "$t" ] && bash "$t"; done
echo "tests: ok"
SH
chmod +x test.sh
cat > AGENTS.md <<'MD'
# Agent instructions

Run ./test.sh before calling work done. Shell scripts use bash.
MD
cat > PLAN.md <<'MD'
# Plan: an average helper

Approved by the user.

1. Add lib/average.sh with average(), which prints the integer mean of its
   arguments, and prints 0 when given none.
2. Add tests/average.sh covering three numbers and no numbers.

Tests: ./test.sh runs both.
MD
git add -A
git commit -qm "add total"
echo "ready: $(pwd)"
