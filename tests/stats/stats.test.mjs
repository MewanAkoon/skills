// Runs scripts/stats.mjs against the transcript tree in tests/stats/home and
// checks the numbers it reports. Every expected value below was counted by
// hand from those files. Run with: npm run test:stats
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const script = path.join(here, '..', '..', 'scripts', 'stats.mjs');
const home = path.join(here, 'home');

function run(args) {
  return execFileSync(process.execPath, [script, ...args], {
    env: { ...process.env, CLAUDE_CONFIG_DIR: home },
    // From a temporary directory, so a path the script resolved against its
    // own working directory by mistake reads as scratch and shows.
    cwd: os.tmpdir(),
    encoding: 'utf8',
  });
}

const json = (args) => JSON.parse(run(['--json', ...args]));
const july = ['--since', '2026-07-06', '--until', '2026-07-19'];

test('counts each week of forks, resumes, a subagent and a compaction', () => {
  const out = json(july);
  assert.deepEqual(out.weeks.map((w) => w.week), ['2026-07-06', '2026-07-13']);
  const [first, second] = out.weeks;

  // a-resume.jsonl copies s1's first message and sorts before it, yet the
  // message stays s1's.
  assert.equal(first.typed, 6);
  assert.equal(first.sessions, 1);
  assert.equal(first.families, 1);
  // Turn p7 holds a commit message with an apostrophe, a cd into /tmp
  // before a real push, a push inside an if, a {owner}/{repo} path with a
  // quoted method, and a here-string.
  assert.deepEqual(first.writes, { commit: 3, push: 5, pr: 1, post: 2 });
  // A heredoc body, a --help, a grep, git commit-tree and gh api -X GET name
  // a write without making one. Writes into a repo under /tmp are scratch.
  assert.equal(first.scratchWrites, 2);
  assert.equal(first.writeTurns, 4);
  // The PR came in a turn a task notification started, after a bare /compact.
  assert.equal(first.unaskedWriteTurns, 1);
  assert.equal(first.subagentWrites, 1);
  assert.equal(first.commitsWithoutSkill, 2);
  assert.equal(first.prWritesWithoutSkill, 1);
  assert.equal(first.posts, 2);
  assert.equal(first.anotherPass, 1);
  assert.equal(first.editingFamilies, 1);
  assert.equal(first.draftRequests, 1);
  assert.equal(first.draftsWithFile, 1);
  assert.equal(first.compactions, 1);
  assert.equal(first.typedCompact, 1);
  assert.equal(first.familiesCompacted, 1);
  assert.equal(first.reviewRuns, 1);
  assert.equal(first.ultraReviews, 0);
  // 150 from the main session's split reply, counted once, and 300 from
  // the subagent, and 10 from a reply under the review alias. Cache reads
  // are counted apart.
  assert.equal(first.reviewTokens, 460);
  assert.equal(first.reviewCacheReads, 1000);
  assert.equal(first.reviewedSessions, 1);
  assert.equal(first.hookErrors, 1);

  // s2 resumes s1: the copied first message is not counted again. s4 forks
  // s1 and shares only a message id with it. s5 resumes s1 and shares only
  // its session id. All four stay one family, beside s3.
  assert.equal(second.typed, 7);
  assert.equal(second.sessions, 5);
  assert.equal(second.families, 2);
  // A commit run from a working directory under /tmp, and an ultra review.
  assert.equal(second.scratchWrites, 1);
  assert.equal(second.reviewRuns, 1);
  assert.equal(second.ultraReviews, 1);
  assert.deepEqual(second.writes, { commit: 2, issue: 1, push: 1 });
  assert.equal(second.writeTurns, 3);
  // "ship it" asks for no issue, and "yes" approves without naming the
  // commit. "push" covers the commit made before it.
  assert.equal(second.unaskedWriteTurns, 1);
  assert.equal(second.approvedWriteTurns, 1);
  assert.equal(second.commitsWithoutSkill, 2);
  assert.equal(second.anotherPass, 1);
  assert.equal(second.draftRequests, 1);
  // Its turn only sent output to /dev/null.
  assert.equal(second.draftsWithFile, 0);
});

test('totals count sessions and families once across weeks', () => {
  const { totals } = json(july);
  assert.equal(totals.weeks, 2);
  assert.equal(totals.typed, 13);
  assert.equal(totals.sessions, 5);
  assert.equal(totals.families, 2);
  assert.equal(totals.writeTurns, 7);
  assert.equal(totals.unaskedWriteTurns, 2);
  assert.equal(totals.approvedWriteTurns, 1);
  assert.deepEqual(totals.writes, {
    commit: 5, push: 6, pr: 1, post: 2, issue: 1,
  });
});

test('with no flags it reads every transcript up to today', () => {
  assert.equal(json([]).totals.typed, 21);
});

test('a window with no end runs to today, so quiet weeks still count', () => {
  // The last activity in proj-a is in the week of 2026-07-13, and in proj-b
  // the week of 2026-07-27, the fourth from 2026-07-06. proj-c and proj-d go
  // on to the weeks of 2026-08-10 and 2026-08-17.
  assert.ok(json(['--since', '2026-07-06']).totals.weeks > 6);
});

test('reads shell the way the shell does', () => {
  // proj-c holds one call per case: a comment with an apostrophe, a heredoc
  // with no space before it, a cd inside a subshell, a mktemp repo, an
  // exported variable, a -C inside a message, gh api flags inside quoted
  // values, a commit's own -C run from /tmp into a real repo, and sudo tee.
  const out = json(['--project', 'proj-c']);
  const { totals } = out;
  // agent-y.jsonl carries no turn id, so its commit and push are reported,
  // not counted: two writes from one call, since the count is per write. Its
  // git status is no write.
  assert.equal(out.totals.unplacedSubagentWrites, 2);
  // Outside the window it is not reported at all.
  assert.equal(json(['--project', 'proj-c', '--until', '2026-08-10']).totals.unplacedSubagentWrites, 0);
  // agent-z.jsonl names its turn only after its first call, which still
  // counts in that turn. The malformed lines in s6.jsonl add nothing.
  assert.deepEqual(totals.writes, { push: 3, commit: 3, api: 1, post: 1 });
  assert.equal(totals.scratchWrites, 2);
  assert.equal(totals.draftRequests, 1);
  assert.equal(totals.draftsWithFile, 1);
});

test('skips malformed transcript lines without stopping', () => {
  // s6.jsonl holds a null content block, an unnamed tool call, and a user
  // line with only a null block and an empty text block, which is no typed
  // message. agent-y.jsonl holds a line that is only null.
  const { totals } = json(['--project', 'proj-c']);
  assert.equal(totals.typed, 2);
});

test('reads the harder shell cases', () => {
  // proj-d holds one call per case: mktemp in quotes and in a cd, git init in
  // a real repo, a commit's own -C run from /tmp, a shift and a quoted <<
  // before a push, gh api fields written with = or attached, a case pattern
  // inside a subshell, a cd and a commit inside backticks, -C with its path
  // attached, git --namespace, cd -, a relative -C, a comment naming a
  // heredoc, and an emptied variable. Then a bare (( )) shift, esac right
  // before ), case after then, nested parens in $(( )), cd ~, mktemp in
  // backticks, --git-dir, a backslash-quoted heredoc, xargs -I and timeout.
  // Then commit and PR bodies in "$(cat <<'EOF' ... )" naming writes, mktemp
  // in a loop, a scaffold function that runs git init, mktemp with its own
  // directory, sudo -u, xargs -n, two -C flags, and --attr-source. Last,
  // mktemp beside $PWD and under -p, and git init -b in a scaffold. Round 5
  // added a subshell opening with ((, a new repo under $HOME, cd ~ then a
  // relative cd, mktemp with a bare template and with --tmpdir, --git-dir
  // beside --work-tree, nested case, and timeout -s. Round 6 added mktemp
  // -dt, nested case with a space before ;;, relative cds with no working
  // directory, a loop scaffold, GIT_DIR, $HOME, mktemp under $TMPDIR,
  // --work-tree alone, xargs -I{}, and two subshells opening with ((.
  const { totals } = json(['--project', 'proj-d']);
  assert.deepEqual(totals.writes, {
    commit: 4, push: 31, post: 2, api: 1, pr: 2,
  });
  assert.equal(totals.scratchWrites, 22);
  // A redirect with no space writes a file, and so does one between two
  // $(( )) or after two subshells opening with ((. $(( )), (( )) with && or
  // ;, and [[ ]] alone do not.
  assert.equal(totals.draftRequests, 4);
  assert.equal(totals.draftsWithFile, 3);
});

test('a saved window with no end records the day it ran', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'stats-'));
  const file = path.join(dir, 'open.json');
  try {
    const today = () => new Date().toISOString().slice(0, 10);
    const before = today();
    run(['--since', '2026-07-06', '--save', file]);
    const saved = JSON.parse(fs.readFileSync(file, 'utf8'));
    // A run that crosses midnight UTC may save either day.
    assert.ok([before, today()].includes(saved.window.until));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('--project keeps only matching project folders', () => {
  const { totals } = json([...july, '--project', 'proj-b']);
  assert.equal(totals.typed, 3);
  assert.deepEqual(totals.writes, { issue: 1, commit: 1, push: 1 });
});

test('--save writes the JSON and --compare reads it back', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'stats-'));
  const file = path.join(dir, 'baseline.json');
  try {
    run([...july, '--project', 'proj-b', '--save', file]);
    const saved = JSON.parse(fs.readFileSync(file, 'utf8'));
    assert.equal(saved.totals.typed, 3);
    const text = run([...july, '--compare', file]);
    // proj-b alone: 1 of 2 write turns unasked. Everything: 2 of 7.
    assert.match(text, /Unasked write turns\s+50%\s+29%/);
    assert.doesNotMatch(text, /counted differently/);
    // A baseline that counted differently says so, in text and in JSON.
    saved.definitions.typed = 'something else';
    delete saved.definitions.posts;
    saved.definitions.retired = 'gone now';
    saved.version = 1;
    fs.writeFileSync(file, JSON.stringify(saved));
    const drift = run([...july, '--compare', file]);
    assert.match(drift, /version 1 there and 2 here/);
    assert.match(drift, /definitions changed: typed;/);
    assert.match(drift, /counts are new: posts;/);
    assert.match(drift, /counts are gone: retired\./);
    assert.match(json([...july, '--compare', file]).baseline.drift, /typed/);
    // A file with no saved totals is refused.
    fs.writeFileSync(file, '{}');
    assert.throws(() => run([...july, '--compare', file]), /holds no saved totals/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('rejects an unknown flag', () => {
  assert.throws(() => run(['--nope']), /unknown flag --nope/);
});

// Each command alone, so two mistakes that cancel in a total still show.
// A write is its kind, with * when it lands in a scratch repo.
const CASES = [
  ['git commit -m "fix user\'s bug" && git push origin \'main\'', '/repo', 'commit push'],
  ['cd /tmp/build && make; cd /repo && if git push origin HEAD; then :; fi', '', 'push'],
  ['gh api -X "POST" repos/{owner}/{repo}/pulls/1/comments -f body=x', '', 'post'],
  ['git commit -F - <<< "msg"\ngit push', '', 'commit push'],
  ["# don't forget\ngit push", '', 'push'],
  ['cat<<EOF > m\ngit push --force\nEOF\ngit commit -F m', '', 'commit'],
  ['(cd /tmp/x && make) && git push origin HEAD', '/repo', 'push'],
  ['tmp="$(mktemp -d)"; cd "$tmp" && git commit -m x', '/repo', 'commit*'],
  ['cd $(mktemp -d) && git commit -m y', '/repo', 'commit*'],
  ['export S=/tmp/p; cd $S && git commit -m x', '/repo', 'commit*'],
  ['git commit -m "fix -C /tmp/x"', '/repo', 'commit'],
  ['gh api -X PATCH repos/o/r/pulls/1 -f body="addresses review comments"', '', 'api'],
  ["gh api repos/o/r/issues/1/comments -f body='use -X GET to read'", '', 'post'],
  ['git -C /repo commit -C HEAD --amend', '/private/tmp/w', 'commit'],
  ['git init && git add . && git commit -m init && git push -u origin main', '/Users/x/new', 'commit push'],
  ['git commit -C HEAD --amend', '/private/tmp/w2', 'commit*'],
  ['x=$((a<<b))\ngit push', '', 'push'],
  ['echo "a<<b"\ngit push', '', 'push'],
  ['gh api --raw-field=body=x repos/o/r/issues/1/comments', '', 'post'],
  ["gh api repos/o/r/issues --input=- <<< '{}'", '', 'api'],
  ['gh api repos/o/r/issues/2/comments -fbody=x', '', 'post'],
  ['(cd /tmp/x; case $v in a) :;; esac; git push)', '/repo', 'push*'],
  ['(cd /tmp/x; case $v in a) :;; esac); git push', '/repo', 'push'],
  ['(cd /tmp/x; if t; then case $v in a) :;; esac; fi; git push)', '/repo', 'push*'],
  ['echo `cd /tmp/x` `git commit -m q`; git push', '/repo', 'commit push'],
  ['git -C"/tmp/x" commit -m z', '/repo', 'commit*'],
  ['git --namespace foo push', '', 'push'],
  ['cd /tmp/x && make; cd - && git push', '/repo', 'push'],
  ['cd /tmp && git -C x push', '/repo', 'push*'],
  ['# use cat <<EOF here\ngit push', '', 'push'],
  ['X=/tmp/a; X=; cd $X && git push', '/repo', 'push'],
  ['((a<<b))\ngit push', '', 'push'],
  ['(cd /tmp/x; y=$((a*(b+1))); git push)', '/repo', 'push*'],
  ['cd ~/work && git push', '/tmp/x', 'push'],
  ['cd `mktemp -d` && git commit -m x', '/repo', 'commit*'],
  ['git --git-dir /tmp/x/.git push', '/repo', 'push*'],
  ['cat <<\\EOF\ngit push\nEOF', '', ''],
  ['xargs -I {} git -C {} push', '', 'push'],
  ['timeout 60 git push', '', 'push'],
  ['git commit -m "$(cat <<\'EOF\'\nWrap "the `git push` call"\nEOF\n)"', '/repo', 'commit'],
  ['for i in 1; do d=$(mktemp -d) && cd "$d" && git commit -m x; done', '/repo', 'commit*'],
  ['S=/tmp/s; mk() { d=$1; cd "$d"; git init -q; git commit -qm i; }; mk $S/p', '/repo', 'commit*'],
  ['D=$(mktemp -d "$(pwd)/w.XXXX"); cd "$D" && git push', '/repo', 'push'],
  ['sudo -u bob git push', '', 'push'],
  ['ls | xargs -n 1 git push', '', 'push'],
  ['git -C /tmp -C x push', '/repo', 'push*'],
  ['git -C /tmp/x -C /repo push', '', 'push'],
  ['git --attr-source HEAD push', '', 'push'],
  ['cd /tmp/w && d=$(mktemp -d "$PWD/x.XXXX") && cd "$d" && git commit -m a', '/repo', 'commit*'],
  ['mk() { d=$1; cd "$d"; git init -q -b main; git commit -qm i; }; mk x', '/repo', 'commit*'],
  ['d=$(mktemp -d -p "$PWD") && cd "$d" && git push', '/repo', 'push'],
  ['((cd /tmp/x && git push) || true)', '/repo', 'push*'],
  ['cd $HOME/new && git init && git commit -m i && git push', '/repo', 'commit push'],
  ['cd ~ && cd work && git push', '/tmp/x', 'push'],
  ['d=$(mktemp -d build.XXXX) && cd "$d" && git push', '/repo', 'push'],
  ['d=$(mktemp -d --tmpdir foo.XXXX) && cd "$d" && git push', '/repo', 'push*'],
  ['git --git-dir=/repo/.git --work-tree=/tmp/x push', '/repo', 'push'],
  ['case $x in a) (case $y in b) :;; esac);; c) cd /tmp/z;; esac; git push', '/repo', 'push'],
  ['timeout -s KILL 60 git push', '/repo', 'push'],
  ['d=$(mktemp -dt foo.XXXX) && cd "$d" && git push', '/repo', 'push*'],
  ['case $x in a) case $y in b) :;; esac ;; c) cd /tmp/z;; esac; git push', '/repo', 'push'],
  ['cd foo && cd bar && git push', '', 'push'],
  ['for d in a b; do git -C "$d" init; git -C "$d" commit -m x; done', '/repo', 'commit*'],
  ['GIT_DIR=/tmp/x/.git git push', '/repo', 'push*'],
  ['cd $HOME && git push', '/tmp/x', 'push'],
  ['d=$(mktemp -d "${TMPDIR:-/tmp}/x.XXXX"); cd $d; git push', '/repo', 'push*'],
  ['git --work-tree=/tmp/x push', '/repo', 'push'],
  ['xargs -I{} git -C {} push', '', 'push'],
  ['((cd /tmp/x); git push)', '/repo', 'push'],
  ['case $1 in t) cd /tmp/x;; *) git push;; esac', '/repo', 'push'],
  ['export GIT_DIR=/tmp/x/.git; git push', '/repo', 'push*'],
  ['env GIT_DIR=/tmp/x/.git git push', '/repo', 'push*'],
  ['cd ${HOME:-/tmp/a} && git push', '/tmp/y', 'push'],
  ['case $x in a) cd /tmp/z; esac>/dev/null; git push', '/repo', 'push'],
  ['X=; cd ${X:-/tmp/a} && git push', '/repo', 'push*'],
  ['cd ${PWD:-/x} && git push', '/tmp/y', 'push*'],
  ['git commit -m "for d in a"; git init "$d"; git -C "$d" commit -m x', '/repo', 'commit'],
  ['d=$(mktemp -d -p/tmp x.XXXX) && cd "$d" && git push', '/repo', 'push*'],
  ['d=$(mktemp -dp /tmp) && cd "$d" && git push', '/repo', 'push*'],
  ['d=$(mktemp -d -pd x.XXXX) && cd "$d" && git push', '/repo', 'push'],
  ['GIT_DIR=/tmp/x/.git; git push', '/repo', 'push'],
  ['export GIT_DIR=/tmp/x/.git; unset GIT_DIR; git push', '/repo', 'push'],
  ['(export GIT_DIR=/tmp/x/.git); git push', '/repo', 'push'],
  ['(S=/tmp/x); cd $S && git push', '/repo', 'push'],
  ['GIT_DIR=/tmp/x/.git; export GIT_DIR; git push', '/repo', 'push*'],
  ['typeset -x GIT_DIR=/tmp/x/.git; git push', '/repo', 'push*'],
  ['f() { local -x GIT_DIR=/tmp/x/.git; git push; }; f', '/repo', 'push*'],
  ['f() { local D=/tmp/x; cd $D && git push; }; f', '/repo', 'push*'],
  ['export -- GIT_DIR=/tmp/x/.git; git push', '/repo', 'push*'],
  ['set -a; GIT_DIR=/tmp/x/.git; git push', '/repo', 'push*'],
  ['export GIT_DIR=/tmp/x/.git; export -n GIT_DIR; git push', '/repo', 'push'],
  ['case a in a) export GIT_DIR=/tmp/x/.git ;; esac; git push', '/repo', 'push*'],
  ['export GIT_DIR=/tmp/x/.git; unset -f GIT_DIR; git push', '/repo', 'push*'],
  ['while read d; do git init /r/$d; git -C /r/$d commit -m y; done', '/repo', 'commit*'],
  ['if x; then :; elif for d in a; do git init /r/$d; git -C /r/$d commit -m y; done; then :; fi', '/repo', 'commit*'],
  ['d=$(mktemp -d -p) && cd "$d" && git push', '/repo', 'push'],
  ["X=it\\'s git push", '', 'push'],
  ['X="a\\"b" git push', '', 'push'],
  ['X="a b" git push', '', 'push'],
  ['time for d in a; do git init /r/$d; git -C /r/$d commit -m y; done', '/repo', 'commit*'],
  ['case $1 in *) d=/tmp/x;; esac; cd $d && git push', '/repo', 'push*'],
  ['OUT="$(git push origin HEAD 2>&1)"', '/repo', 'push'],
  ['echo "$(git commit -m x)" "`git push`"', '/repo', 'commit push'],
  ['echo "$(cd /tmp/x && git push)"; git commit -m y', '/repo', 'push* commit'],
  ['cd && git push', '/tmp/x', 'push'],
  ['gh -R o/r pr create --title x', '', 'pr'],
  ['gh --repo=o/r issue comment 3 --body-file b', '', 'post'],
  ['gh -R o/r api repos/o/r/issues/1/comments -f body=x', '', ''],
  ['git push --dry-run', '/repo', ''],
  ['git push -n origin main', '/repo', ''],
  ['git commit -n -m x', '/repo', 'commit'],
  ['gh pr create --dry-run --title x', '', ''],
  ['pushd /tmp/x && git commit -m a; popd; git push', '/repo', 'commit* push'],
  ['git commit -m fix -- -h', '/repo', 'commit'],
  ['git push -h', '/repo', ''],
  ['gh pr create --help', '', ''],
  ['while IFS= read -r d; do git init /r/$d; git -C /r/$d commit -m y; done', '/repo', 'commit*'],
  ['read -p "dir? " d; git init /r/$d; git -C /r/$d commit -m y', '/repo', 'commit*'],
  ['read -p d x; git init /r/$d; git -C /r/$d commit -m y', '/repo', 'commit'],
  ['set -e -a; GIT_DIR=/tmp/x/.git; git push', '/repo', 'push*'],
  ['set -o allexport; GIT_DIR=/tmp/x/.git; git push', '/repo', 'push*'],
  ['set  -a; GIT_DIR=/tmp/x/.git; git push', '/repo', 'push*'],
  ['set -a; set +o allexport; GIT_DIR=/tmp/x/.git; git push', '/repo', 'push'],
  ['time -p git push', '/repo', 'push'],
  ['for d; do git init /r/$d; git -C /r/$d commit -m y; done', '/repo', 'commit*'],
  ['export GIT_DIR A=1; GIT_DIR=/tmp/x/.git; git push', '/repo', 'push*'],
  ['D="/tmp/a\\" b"; cd "$D" && git push', '/repo', 'push*'],
  ['read -r -a arr; git init /r/$arr; git -C /r/$arr commit -m y', '/repo', 'commit*'],
  ['read -ra arr; git init /r/$arr; git -C /r/$arr commit -m y', '/repo', 'commit*'],
  ['read -rp d x; git init /r/$d; git -C /r/$d commit -m y', '/repo', 'commit'],
  ['git commit -m --dry-run', '/repo', 'commit'],
  ['git push -nf', '/repo', ''],
  ['git push -fn origin', '/repo', ''],
  ['git push -o --dry-run origin', '/repo', 'push'],
  ['gh pr create --title x --body --dry-run', '', 'pr'],
  ['gh pr comment 1 --body-file -h', '', 'post'],
  ['git commit --author -h -m x', '/repo', 'commit'],
  ['gh issue create --label -h --title t', '', 'issue'],
  ['set -- -a; GIT_DIR=/tmp/x/.git; git push', '/repo', 'push'],
  ['(cd /tmp/y; pushd /repo2); popd; git push', '/repo', 'push'],
  ['cd -P /tmp/x && git push', '/repo', 'push*'],
  ['cd -- /tmp/x && git push', '/repo', 'push*'],
  ['pushd +1; git push', '/repo', 'push'],
  ['cd /tmp/x; pushd /repo; pushd +1; git push', '/r', 'push*'],
  ['cd /tmp/x; pushd /repo; pushd /repo2; pushd -0; git push', '/r', 'push*'],
  ['cd /tmp/x; pushd /repo; pushd /repo2; pushd -1; git push', '/r', 'push'],
  ['gh pr create --reviewer -h --title t', '', 'pr'],
  ['pushd /repo; pushd; git push', '/tmp/x', 'push*'],
  ['pushd; git push', '/tmp/x', 'push*'],
  ['git commit -m --help', '/repo', 'commit'],
  ['git push -o -h origin', '/repo', 'push'],
  ['echo "$(case $x in a) git push;; esac)"', '/repo', 'push'],
  ['for d do git init /r/$d; git -C /r/$d commit -m y; done', '/repo', 'commit*'],
  ['echo "$(echo case)"; git push', '/repo', 'push'],
  ['echo "$(grep --ignore-case x f)"; git push', '/repo', 'push'],
  ['echo "$(case $x in (a) echo y;; esac)"; git push', '/repo', 'push'],
  ['echo "$(case $x in a) y=$(pwd);; esac)"; git push', '/repo', 'push'],
  ['git commit -a --dry-run', '/repo', ''],
  ['git commit -p --dry-run', '/repo', ''],
  ['git commit -a -h', '/repo', ''],
  ['f() { local D=/tmp/x; }; f; cd ${D:-/repo2} && git push', '/repo', 'push'],
  ['local D=/tmp/x; cd $D && git push', '/repo', 'push'],
  ['read -pd x; git init /r/$x; git -C /r/$x commit -m z', '/repo', 'commit*'],
  ['pushd -n /tmp/x; git push', '/repo', 'push'],
  ['pushd -n /tmp/x; pushd; git push', '/repo', 'push*'],
  ['set -euo allexport; GIT_DIR=/tmp/x/.git; git push', '/repo', 'push*'],
  ['f() {\n  local D=/tmp/x\n  cd $D && git push\n}', '/repo', 'push*'],
  ['function f() { local D=/tmp/x; cd $D && git push; }', '/repo', 'push*'],
  ['f() ( local D=/tmp/x; cd $D && git push )', '/repo', 'push*'],
  ['f() { local D=/tmp/x; { true; }; cd $D && git push; }', '/repo', 'push*'],
  ['f() { { true; }; local D=/tmp/x; cd $D && git push; }', '/repo', 'push*'],
  ['D=/repo; f() { local D=/tmp/x; }; cd $D && git push', '/r', 'push'],
  ['pushd /tmp/x; pushd -n +1; git push', '/repo', 'push*'],
  ['echo "$(echo if case)"; git push', '/repo', 'push'],
  ['git commit -m "$(echo use case)"; git push', '/repo', 'commit push'],
  ['X="$(cat src/case/a)"; git push', '/repo', 'push'],
  ['echo "$(test-case)"; git push', '/repo', 'push'],
  ['echo "$(case $x in (a) git push;; esac)"; git commit -m y', '/repo', 'push commit'],
  ['echo "$(case $x in a) echo $(pwd);; esac)"; git commit -m y', '/repo', 'commit'],
  ['echo "$(case $x in a) case $y in b) z;; esac;; esac)"; git push', '/repo', 'push'],
  ['gh release create v1 -n --dry-run', '', 'release'],
  ['gh api repos/o/r/issues/1/comments -f -h', '', 'post'],
  ['git push --receive-pack --dry-run origin', '/repo', 'push'],
  ['git commit -o --dry-run f', '/repo', ''],
  ['set -eo pipefail -a; GIT_DIR=/tmp/x/.git; git push', '/repo', 'push*'],
  ['read < f d; git init /r/$d; git -C /r/$d commit -m y', '/repo', 'commit*'],
  ['{ git status; } > /tmp/out.txt; git push', '/repo', 'push'],
  ['f() { local D=/tmp/x; if { true; }; then cd $D && git push; fi; }', '/repo', 'push*'],
  ['f() { local D=/tmp/x; time { true; }; cd $D && git push; }', '/repo', 'push*'],
  ['( local D=/tmp/x; cd $D && git push )', '/repo', 'push'],
  ['f() ( true ); local D=/tmp/x; cd $D && git push', '/repo', 'push'],
  ['(cd /tmp/x; echo "$(echo `a)`)"; git push); git push', '/repo', 'push* push'],
  ['echo `echo \\`git push\\``; git commit -m x', '/repo', 'push commit'],
  ['echo `cd /tmp/x`; git push', '/repo', 'push'],
  ['gh pr -R o/r create -t -h', '', 'pr'],
  ['gh pr reopen 1 -c -h', '', 'pr'],
  ['gh pr create --recover f --dry-run', '', ''],
  ['if true; then f() { local D=/tmp/x; cd $D && git push; }; fi', '/repo', 'push*'],
  ['for i in 1; do f() { local D=/tmp/x; cd $D && git push; }; done', '/repo', 'push*'],
  ['my.f() { local D=/tmp/x; cd $D && git push; }', '/repo', 'push*'],
  ['f() { if { true; }; then :; fi; local D=/tmp/x; cd $D; git push; }', '/repo', 'push*'],
  ['function f { local D=/tmp/x; cd $D && git push; }', '/repo', 'push*'],
  ['pushd /tmp/x; pushd -n +1; popd; git push', '/repo', 'push*'],
  ['pushd /tmp/x; pushd +1 -n; git push', '/repo', 'push*'],
  ['git commit -m push -o --dry-run', '/repo', ''],
  ['if true; then function f { local D=/tmp/x; cd $D && git push; }; fi', '/repo', 'push*'],
  ['pushd /tmp/x; popd +1; git push', '/repo', 'push*'],
  ['pushd /tmp/x; popd -n; git push', '/repo', 'push*'],
  ['pushd /tmp/x; popd +0; cd -; git push', '/repo', 'push*'],
  ['pushd /tmp/x; cd /r; popd; cd -; git push', '/r', 'push'],
  ['pushd /tmp/x; popd -n +0; popd; git push', '/repo', 'push*'],
  ['pushd /tmp/x; popd -n -1; popd; git push', '/repo', 'push*'],
  ['f() { declare D=/tmp/x; }; cd $D && git push', '/repo', 'push'],
  ['f() { declare -g D=/tmp/x; }; cd $D && git push', '/repo', 'push*'],
  ['gh pr create -f --dry-run', '', ''],
  ['gh label create bug -f -h', '', ''],
  ['gh pr merge -m -h', '', ''],
  ['gh pr create -m v1 --dry-run', '', ''],
  ['echo ) ; local D=/tmp/x; cd $D && git push', '/repo', 'push'],
  ['echo "$(echo `a)`)"; git push', '/repo', 'push'],
  ['echo "`echo \\`git push\\``"; git commit -m x', '/repo', 'push commit'],
  ['read d < file; git init /r/$file; git -C /r/$file commit -m y', '/repo', 'commit'],
  ['GIT_DIR="/tmp/my dir/.git" git push', '/repo', 'push*'],
  ['sudo -u git GIT_DIR=/tmp/x/.git git push', '/repo', 'push*'],
  ["git commit -m x # it's\nfor d in a; do git init /r/$d; git -C /r/$d commit -m y; done; echo 'z'", '/repo', 'commit commit*'],
  ['case x in a) : ;; esac.d) cd /tmp/x ;; esac; git push', '/repo', 'push'],
];

test('reads each shell command the way the shell does', async () => {
  const { bashCall } = await import(script);
  for (const [command, cwd, expected] of CASES) {
    const { writes } = bashCall(command, cwd);
    const got = writes.map((w) => w.kind + (w.scratch ? '*' : '')).join(' ');
    assert.equal(got, expected, command);
  }
});

test('importing the script never runs or breaks it', () => {
  // An argument that is no file once crashed the check for running as a
  // script.
  const out = execFileSync(
    process.execPath,
    ['--input-type=module', '-e', `await import(${JSON.stringify(script)}); console.log('ok');`, 'no-such-file'],
    { encoding: 'utf8', env: { ...process.env, CLAUDE_CONFIG_DIR: home } },
  );
  assert.equal(out.trim(), 'ok');
});

// Whether a command writes a file, which decides whether a draft became one.
const WRITES_FILE = [
  ['echo hi>reply.md', true],
  ['{ git status; } > /tmp/out.txt', true],
  ['echo x | sudo tee f', true],
  ['git status >/dev/null 2>&1', false],
  ['echo "a -> b"', false],
  ['echo $((a>b)); [[ a > b ]]; (( a > b ))', false],
  ['echo "$(psql -c "select 1 where 2 > 1")"', false],
  ['echo $((a)) > f.txt $((b))', true],
];

test('tells a command that writes a file from one that does not', async () => {
  const { bashCall } = await import(script);
  for (const [command, expected] of WRITES_FILE) {
    assert.equal(bashCall(command, '/repo').wroteFile, expected, command);
  }
});
