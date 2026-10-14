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
  // p1 loaded eng:commit, which stays in context for the family's later
  // turns, across the compaction too, so no commit came without it.
  assert.equal(first.commitsWithoutSkill, 0);
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
  // s2 resumes s1, whose p1 loaded eng:commit, so only s3's commit lacks it.
  assert.equal(second.commitsWithoutSkill, 1);
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
  assert.equal(json([]).totals.typed, 58);
});

test('reads what you typed mid-turn, and what a request word means', () => {
  // proj-e: a commit in the turn that loads eng:commit and one in the next
  // turn, which has it already. A push asked for in a message typed while its
  // turn ran, beside a meta wake, a task notification, and an interrupt
  // marker, none of them typed. Then pushes after "don't push yet" and a
  // second marker, after "pushback" and "postgres", after "pushed", and after
  // "don't forget to push" beside a queued message from a peer, not typed.
  // The next week, gh secret set after a message naming only a description,
  // with a queued message that carries no origin, typed as a user entry with
  // none would be. Then a push after "commit it without pushing". The week
  // after, pushes after "don't wait for CI before you push" and "don't ever
  // forget to push", and a commit after "don't hesitate to commit", which
  // all ask for one. Last, pushes after "commit it without forgetting to
  // push", which asks, and after "don't stop the server or push anything" and
  // "don't push yet - wait for CI", which do not. The week after, pushes
  // after "don't wait to push", "don't you forget to push" and a negation
  // that an em dash ends before "push the fix", which all ask. Then "never
  // use --force or push to main", which does not, and "don't merge - push
  // it", which does. The week after, "commit it without waiting to push",
  // which leaves the push for later, "don't merge -- push it", "no need to
  // wait to push" and "no need to keep waiting to push", which ask, and "he
  // never waits to push, so commit only", which reports and does not ask.
  // Then "don't wait for CI to push", "don't bother waiting to push", "don't
  // waste time waiting to push", "don't wait for the CI run to push" and
  // "don't wait for GitHub Actions to push", which ask, and "don't wait for
  // me to push" and "don't bother to push", which do not. Last, commits after
  // "check it in" and "check in the changes", which ask, and after "just
  // checking in, how is it going?", which does not.
  const { totals, weeks } = json(['--project', 'proj-e']);
  assert.equal(totals.typed, 37);
  assert.equal(totals.writeTurns, 35);
  assert.deepEqual(weeks.map((w) => w.unaskedWriteTurns), [2, 2, 0, 2, 1, 5]);
  assert.equal(totals.approvedWriteTurns, 0);
  assert.equal(totals.commitsWithoutSkill, 0);
  assert.deepEqual(totals.writes, { commit: 7, push: 28, api: 1 });
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
  const { totals, weeks } = json([...july, '--project', 'proj-b']);
  assert.equal(totals.typed, 3);
  assert.deepEqual(totals.writes, { issue: 1, commit: 1, push: 1 });
  // The hook log names no project, so its errors cannot be kept to one.
  assert.equal(totals.hookErrors, null);
  assert.ok(weeks.every((w) => w.hookErrors === null));
  assert.match(run([...july, '--project', 'proj-b']), /Hook errors\s+n\/a/);
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
    assert.match(drift, /version 1 there and 3 here/);
    assert.match(drift, /definitions changed: typed;/);
    assert.match(drift, /counts are new: posts;/);
    assert.match(drift, /counts are gone: retired\./);
    assert.match(json([...july, '--compare', file]).baseline.drift, /typed/);
    // A file with no saved totals is refused.
    fs.writeFileSync(file, '{}');
    assert.throws(() => run([...july, '--compare', file]), /holds no saved totals/);
    // So is one whose totals lack the writes every headline row reads.
    fs.writeFileSync(file, JSON.stringify({ totals: { typed: 1 } }));
    assert.throws(() => run([...july, '--compare', file]), /holds no saved totals/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('rejects an unknown flag', () => {
  assert.throws(() => run(['--nope']), /unknown flag --nope/);
});

test('rejects a date that does not exist and a window that ends before it starts', () => {
  assert.throws(() => run(['--since', '2026-13-01']), /--since takes a date as YYYY-MM-DD/);
  assert.throws(() => run(['--until', '2026-02-30']), /--until takes a date as YYYY-MM-DD/);
  assert.throws(() => run(['--since', '2026-10-10', '--until', '2026-10-01']), /--since comes after --until/);
  assert.throws(() => run(['--since', '2999-01-01']), /--since is after today/);
});

test('--compare shows n/a where an older baseline lacks a count', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'stats-'));
  const file = path.join(dir, 'old.json');
  try {
    fs.writeFileSync(file, JSON.stringify({ version: 1, totals: { typed: 4, writes: { commit: 1 } } }));
    const text = run([...july, '--compare', file]);
    assert.doesNotMatch(text, /undefined|NaN/);
    assert.match(text, /Families compacted\s+n\/a/);
    // Writes that are not numbers are no saved totals.
    // A count that is not a number reads n/a too, and so does the remote
    // writes row when a kind holds no number. Definitions that are no object
    // are none.
    fs.writeFileSync(file, JSON.stringify({ definitions: ['a'], totals: { weeks: {}, typed: 'x', commitsWithoutSkill: 1, label: 'x', writes: { commit: 'x', push: null } } }));
    const odd = run([...july, '--compare', file]);
    assert.doesNotMatch(odd, /undefined|NaN/);
    assert.match(odd, /Typed messages per week\s+n\/a/);
    assert.match(odd, /Remote writes per week\s+n\/a/);
    assert.match(odd, /Commits without the skill\s+n\/a/);
    assert.match(odd, /Baseline \(.*, n\/a wk\)/);
    assert.doesNotMatch(odd, /counts are gone: 0/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
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
  // The temporary directory itself is scratch, not only what sits under it.
  ['cd /tmp; git init; git commit -m x', '/repo', 'commit*'],
  ['git push', '/private/var/folders', 'push*'],
  ['git push', '/tmpfoo', 'push'],
  // Only a POST on a comment path is a post. Removing or editing one is not.
  ['gh api -X DELETE repos/o/r/issues/comments/1', '', 'api'],
  ['gh api --method PATCH repos/o/r/pulls/comments/1 -f body=x', '', 'api'],
  ['gh api repos/o/r/issues/1/comments -f body=x', '', 'post'],
  // git or gh named by a path, or run through a shell's -c.
  ['/usr/bin/git push', '/repo', 'push'],
  ['bash -c "git push"', '/repo', 'push'],
  ["sh -c 'cd /tmp/x && git commit -m y'", '/repo', 'commit*'],
  ['bash -c "git status"', '/repo', ''],
  ['bash -c "cd $(mktemp -d) && git init && git commit -m x"', '/repo', 'commit*'],
  // The outer shell fills in its variables in double quotes, and the inner
  // one inherits what it exported. A -c after a script's name is the
  // script's.
  ['D=$(mktemp -d); bash -c "cd $D && git init && git commit -m x"', '/repo', 'commit*'],
  ["export GIT_DIR=/tmp/x/.git; bash -c 'git push'", '/repo', 'push*'],
  ["D=/tmp/x; bash -c 'cd $D && git push'", '/repo', 'push'],
  ['bash -o pipefail -c "git push"', '/repo', 'push'],
  ["bash deploy.sh -c 'gh release create v1'", '/repo', ''],
  ['bash -O extglob -c "git push"', '/repo', 'push'],
  ["bash --rcfile f -c 'git push'", '/repo', 'push'],
  ['bash -c -- "git push"', '/repo', 'push'],
  ["sh -- -c 'git push'", '/repo', ''],
  ["D=/tmp/x bash -c 'cd $D && git push'", '/repo', 'push*'],
  ['D=/tmp/x; bash -c "cd ${D:-/r} && git push"', '/repo', 'push*'],
  ['export D=/tmp/x; bash -c "cd \\$D && git push"', '/repo', 'push*'],
  ['D=/tmp/x; bash -c "cd \\$D && git push"', '/repo', 'push'],
  // Options after -c, and a group holding o, which takes the next word.
  ['bash -euo pipefail -c "git push"', '/repo', 'push'],
  ['bash -c -e "git push"', '/repo', 'push'],
  ["bash -ec 'git push'", '/repo', 'push'],
  ["bash -oc pipefail 'git push'", '/repo', 'push'],
  ["bash -oO pipefail extglob -c 'git push'", '/repo', 'push'],
  ["set -ox allexport; D=/tmp/x; bash -c 'cd $D && git push'", '/repo', 'push*'],
  // In double quotes the outer shell expands before the line's assignments
  // exist, so $D is empty there; in single quotes the inner shell has it.
  ['D=/tmp/x bash -c "cd $D && git push"', '/repo', 'push'],
  ['D=/r; D=/tmp/x bash -c "cd $D && git push"', '/repo', 'push'],
  // There the outer shell still has its own TMPDIR, and an unset name takes
  // its fallback.
  ['TMPDIR=/x bash -c "cd $TMPDIR && git push"', '/repo', 'push*'],
  ['D=/r bash -c "cd ${D-/tmp/y} && git push"', '/repo', 'push*'],
  // Single quotes keep $D as written.
  ["D=/tmp/x; cd '$D' && git push", '/repo', 'push'],
  // A word is read part by part, and a value filled in is not read again.
  ['D=/tmp/x; cd \'\'"$D" && git push', '/repo', 'push*'],
  ["D='$TMPDIR'; cd ${D:-/r} && git push", '/repo', 'push'],
  ['cd ${toString-/tmp/x} && git push', '/repo', 'push*'],
  // A fallback is read as a word of its own, quotes and variables too.
  ['cd ${D:-$TMPDIR/x} && git push', '/repo', 'push*'],
  ['cd ${D:-"/tmp/x"} && git push', '/repo', 'push*'],
  ['E=/tmp/q; cd "${D:-$E}" && git push', '/repo', 'push*'],
  // A backslash before a newline joins the lines, in double quotes too.
  ['cd "/t\\\nmp/x" && git push', '/repo', 'push*'],
  ['cd /t\\\nmp/x && git push', '/repo', 'push*'],
  ['D="/t\\\nmp/x"; cd $D && git push', '/repo', 'push*'],
  ['bash -c "cd /tmp/x && \\\ngit push"', '/repo', 'push*'],
  ['cd /tmp/x && \\\n  git init && \\\n  git commit -m x', '/repo', 'commit*'],
  ['git \\\n  push', '/repo', 'push'],
  // An escaped space keeps a path whole.
  ['git -C /tmp/my\\ dir push', '/repo', 'push*'],
  // Not at the end of a comment. Quotes are followed across lines and into
  // $( ), so a # inside a string opens none.
  ['cd /tmp/x && git commit -m "$(echo "it\'s done")" && \\\n git push', '/repo', 'commit* push*'],
  ['cd /tmp/x && echo a\\\n#b && \\\n git push', '/repo', 'push*'],
  // Single quotes keep one. A # inside a string over several lines, or after
  // an escaped space, opens no comment; one after ; does.
  ["cd '/t\\\nmp/x' && git push", '/repo', 'push'],
  ['git commit -m "Close\n#12 done" && git \\\n push', '/repo', 'commit push'],
  ['echo a\\ #x && git \\\n push', '/repo', 'push'],
  ['git status;# x <<EOF\ngit push\nEOF', '/repo', 'push'],
  // In $'...' a backslash escapes a quote.
  ["git commit -m $'It\\'s done' && git push", '/repo', 'commit push'],
  ["echo $'a #b\\'' && git \\\n push", '/repo', 'push'],
  ["X=$'a\\'b' git push", '/repo', 'push'],
  ["cd $'/tm\\x70/x' && git push", '/repo', 'push*'],
  ["cd $'/tm\\u0070/x' && git push", '/repo', 'push*'],
  // A backslash before the first $ leaves the next one to open $'...'.
  ["echo \\$$'a\\'b' && git push", '/repo', 'push'],
  ["echo \\$'a\\' && git push", '/repo', 'push'],
  // A string that runs itself through bash -c stops at a depth, not at the
  // stack's end.
  [`export x='bash -c "$x"'; bash -c "$x"`, '/repo', ''],
  // An escape past the last code point is kept, not thrown on.
  ["cd $'\\UFFFFFFFF' && git push", '/repo', 'push'],
  // $$ is the process id, and the ' after it opens a plain string.
  ["echo $$'a\\' && git push", '/repo', 'push'],
  ['# tidy up \\\ngit push', '/repo', 'push'],
  ['git status # \\\ngit commit -m x', '/repo', 'commit'],
  // An escaped quote is one character of its word, so the idiom that puts a
  // quote inside single quotes keeps the string whole.
  ["bash -c 'git commit -m \"it'\\''s done\" && git push'", '/repo', 'commit push'],
  // A $(mktemp) in a bash -c string runs in the inner shell, from where it
  // has moved to.
  ["bash -c 'cd /tmp/a && cd $(mktemp -d -p .) && git init && git commit -m x'", '/repo', 'commit*'],
  // The string bash -c runs is read part by part as well.
  ['D=/tmp/x; bash -c \'\'"cd $D && git push"', '/repo', 'push*'],
  ["set -oo pipefail allexport; D=/tmp/x; bash -c 'cd $D && git push'", '/repo', 'push*'],
  // A wrapper's --flag=value is no assignment.
  ["timeout --kill-after=/tmp/y 5 bash -c 'cd $after && git push'", '/repo', 'push'],
  // An escaped backslash before $ leaves the $ to expand, and the inner
  // shell drops the backslash left before the path.
  ['D=/tmp/x; bash -c "cd \\\\$D && git push"', '/repo', 'push*'],
  // gh groups that write to a repo other than through pr, issue or api.
  ['gh repo create x --public', '', 'api'],
  ['gh workflow run ci.yml', '', 'api'],
  ['gh run rerun 12', '', 'api'],
  ['gh secret set X', '', 'api'],
  ['gh repo view x', '', ''],
  ['gh run list', '', ''],
];

test('reads each shell command the way the shell does', async () => {
  const { bashCall } = await import(script);
  for (const [command, cwd, expected] of CASES) {
    const { writes } = bashCall(command, cwd);
    const got = writes.map((w) => w.kind + (w.scratch ? '*' : '')).join(' ');
    assert.equal(got, expected, command);
  }
});

test('reads long runs of backslashes, quotes and assignments without stalling', async () => {
  // A pattern where the same text can match more than one way backtracks
  // without end once the whole match fails.
  const { bashCall } = await import(script);
  const start = Date.now();
  bashCall(`X=${'\\'.repeat(40)}" git push`, '/repo');
  bashCall(`X=${"$'a'".repeat(24)}" git push`, '/repo');
  bashCall(`X=${'a=a'.repeat(18)}" git push`, '/repo');
  bashCall(`X=${Array.from({ length: 24 }, (_, n) => `a${n}=1`).join(',')} echo hi`, '/repo');
  // A string that runs itself several times over branches out at each level.
  bashCall(`export x='${Array(8).fill('bash -c "$x"').join('; ')}'; bash -c "$x"`, '/repo');
  // Many inner strings in one call are each still read.
  const { writes } = bashCall(`${'bash -c "echo hi"; '.repeat(40)}bash -c "git push"`, '/repo');
  assert.deepEqual(writes.map((w) => w.kind), ['push']);
  // A string cut off deep inside is still read where it sits shallower.
  const deep = (n) => (n ? `bash -c ${JSON.stringify(deep(n - 1))}` : 'git push');
  assert.deepEqual(bashCall(`${deep(9)}; bash -c "git push"`, '/repo').writes.map((w) => w.kind), ['push']);
  assert.deepEqual(bashCall(`${deep(10)}; ${deep(3)}`, '/repo').writes.map((w) => w.kind), ['push']);
  assert.deepEqual(bashCall(`export x='bash -c "$x"; bash -c "$x"; bash -c "$x"'; bash -c "$x"; bash -c "git push"`, '/repo').writes.map((w) => w.kind), ['push']);
  bashCall(`export x='${'bash -c "$x"; '.repeat(4)}echo ${'a'.repeat(3000)}'; bash -c "$x"`, '/repo');
  // One that grows at each level never repeats.
  bashCall(`export x='${'a=$a.1 bash -c "$x"; '.repeat(8)}'; bash -c "$x"`, '/repo');
  assert.deepEqual(bashCall(`export x='a=$a.1 bash -c "$x"; a=$a.2 bash -c "$x"'; ${'bash -c "$x"; '.repeat(50)}bash -c "git push"`, '/repo').writes.map((w) => w.kind), ['push']);
  assert.deepEqual(bashCall(`${Array.from({ length: 5000 }, (_, i) => `bash -c "echo ${i}"; `).join('')}bash -c "git push"`, '/repo').writes.map((w) => w.kind), ['push']);
  // A string that runs itself is remembered once its own read ends, so
  // repeats of it cost nothing more.
  assert.deepEqual(bashCall(`export x='bash -c "$x"; a=$a.1 bash -c "$x"; a=$a.2 bash -c "$x"'; ${'bash -c "$x"; '.repeat(20)}bash -c "git push"`, '/repo').writes.map((w) => w.kind), ['push']);
  assert.deepEqual(bashCall(`export x='a=$a.1 bash -c "$x"; a=$a.2 bash -c "$x"'; bash -c "$x"; bash -c "git push"`, '/repo').writes.map((w) => w.kind), ['push']);
  const many = Array.from({ length: 300 }, (_, i) => `bash -c "echo ${i}"; `).join('');
  assert.deepEqual(bashCall(`${many}bash -c "git push"`, '/repo').writes.map((w) => w.kind), ['push']);
  assert.ok(Date.now() - start < 1000);
});

// Whether a message asks for a commit, for phrases a count turns on.
const ASKS_COMMIT = [
  ['check in the changes', true],
  ['go ahead with checking in the changes', true],
  ['check in please', true],
  ['check in the readme changes', true],
  ['remember to check in the fix', true],
  ["let's check in the changes", true],
  ['check it in', true],
  ['check it in please', true],
  ['just checking in, how is it going?', false],
  ['hi, checking in', false],
  ['I just wanted to check in', false],
  ['I just wanted to check in\nHow is it?', false],
  ["let's check in next week", false],
  ['can we check in?', false],
  ['I checked in with Bob yesterday', false],
  ['check in the console', false],
  ['check this in the browser', false],
  ['check in everything', true],
  ["check in, don't push yet", true],
  ['Let me check in.', false],
  ['check it in a minute', false],
  ['checking in on test results', false],
  ["don't push yet, just commit", true],
  ["don't commit or push", false],
];

// Whether a message asks for a remote MCP write, such as one to Google Drive.
const ASKS_MCP = [
  ['upload it to Drive', true],
  ['create a Notion page for this', true],
  ['trash the old copy in Drive', true],
  ['save the sheet', true],
  ['what does this file say?', false],
  ['add a test for the parser', false],
  ['upload it', true],
  ['update the event handler', false],
  ['add a page break to the README', false],
  ['share your thoughts on the docs', false],
  ['add an event to my calendar', true],
  ['save this to my Google Drive', true],
  ['create a Google Doc for the spec', true],
  ["save this to Mewan's Drive", true],
  ['add it to the follow-up sheet', true],
  ['add the meeting to my calendar', true],
  ['add a b c d Drive', true],
  ['add a b c d e Drive', false],
  ['add a test - see the Drive', false],
  ['update the google analytics snippet', false],
  ['add it to the Google Sheets tracker', true],
  ['share it on Google Slides', true],
  ['save this once-a-week report to Drive', true],
  ['update the design document', false],
  ['check the Slack thread and add a test', false],
  ['fix the database and add a test', false],
  ['copy that, thanks', false],
  ['can you share your thoughts?', false],
];

test('reads which messages ask for an MCP write', async () => {
  const { asksFor } = await import(script);
  for (const [text, expected] of ASKS_MCP) assert.equal(asksFor('mcp', text), expected, text);
});

test('reads which messages ask for a commit', async () => {
  const { asksFor } = await import(script);
  for (const [text, expected] of ASKS_COMMIT) assert.equal(asksFor('commit', text), expected, text);
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
