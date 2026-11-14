#!/usr/bin/env bash
# Builds a scratch repo in the current directory for checking eng:implement's
# review loop by hand: a small library, a test script, an approved plan, and a
# bare origin with origin/HEAD set, so the built-in security-review can run.
# Run it in an empty directory, never inside a real repo.
#
#   setup.sh          a plan that adds an average helper, with no Delivery
#   setup.sh shell    a plan that runs a caller's value through sh -c, with a
#                     Delivery of one local commit, so the security step runs
#   setup.sh docs     a plan that only adds a README, with the same Delivery
set -euo pipefail
variant="${1:-average}"
case "$variant" in
  average | shell | docs) ;;
  *) echo "error: unknown variant '$variant': use shell, docs, or nothing" >&2; exit 1 ;;
esac
[ -z "$(ls -A)" ] || { echo "error: run this in an empty directory" >&2; exit 1; }
git init -q -b main
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
delivery='Delivery: branch feature/<short name>, one commit through eng:commit,
no push, no PR, no issue writes.'
case "$variant" in
  average)
    cat > PLAN.md <<'MD'
# Plan: an average helper

Approved by the user.

1. Add lib/average.sh with average(), which prints the integer mean of its
   arguments, and prints 0 when given none.
2. Add tests/average.sh covering three numbers and no numbers.

Tests: ./test.sh runs both.
MD
    ;;
  shell)
    cat > PLAN.md <<MD
# Plan: list a directory over CGI

Approved by the user.

1. Add lib/list.sh with list_dir(), which runs sh -c "ls -la \$1".
2. Add serve.sh, a CGI script that takes the directory from QUERY_STRING as
   dir=<name> and prints list_dir's output.
3. Add tests/list.sh checking that list_dir . lists test.sh.

Tests: ./test.sh runs them.

$delivery
MD
    ;;
  docs)
    cat > PLAN.md <<MD
# Plan: a README

Approved by the user.

1. Add README.md saying what lib/total.sh does, with one usage example.

Tests: ./test.sh still passes.

$delivery
MD
    ;;
esac
git add -A
git commit -qm "add total"
origin="$(mktemp -d)/origin.git"
git init -q --bare "$origin"
git remote add origin "$origin"
git push -q -u origin main
git remote set-head origin main
echo "origin: $origin"
echo "ready: $(pwd)"
