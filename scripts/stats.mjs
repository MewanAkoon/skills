#!/usr/bin/env node
// Counts, per week, whether sessions keep the workflow in
// standards/workflow.md: remote writes nobody asked for, writes from
// subagents, commits and PRs made without their skill, posts, requests for
// another review pass, drafts, compactions, and what code-review cost. It
// reads Claude Code's own transcripts and the eng hook's log, so it reports
// only on a machine with a Claude Code history. CI runs its fixtures in
// tests/stats instead.
//
//   npm run stats -- [--since YYYY-MM-DD] [--until YYYY-MM-DD]
//                    [--project <substring>] [--json]
//                    [--save <file>] [--compare <file>]
//
// It reads ${CLAUDE_CONFIG_DIR:-~/.claude}/projects/*/<session>.jsonl, the
// subagent files under <session>/subagents/, and
// plugins/data/eng-mewanakoon/eng-hook.log. Nothing it prints or saves holds
// message text, only counts.
//
// The counts are heuristics. A typed message's words decide whether a remote
// write was asked for, and regular expressions over Bash commands and MCP
// tool names decide what was a write. DEFINITIONS below is saved with every
// baseline, so a later run can tell when a definition moved.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import readline from 'node:readline';
import { fileURLToPath } from 'node:url';

const DEFINITIONS = {
  typed: 'Messages you typed: no tool results, task notifications, relays, compaction summaries or command output. A slash command counts.',
  families: 'Sessions joined when one resumes or forks another, which shows as a shared message id or an entry carrying the other session id.',
  writeTurns: 'Turns with a remote write: git commit or push, a tag push included; gh pr, issue, label or release writes; gh api writes; MCP tools whose name holds a write verb, on servers other than local and project ones.',
  unaskedWriteTurns: 'Write turns where your latest typed message lacks the word for one of its writes, such as commit, push, PR, merge or post, and is no approval. Push covers commit.',
  approvedWriteTurns: 'Write turns where that message lacks the word but opens with an approval, such as yes or go ahead.',
  subagentWrites: 'Remote writes made from a subagent.',
  scratchWrites: 'Writes whose repo sits under a temporary directory, reached through the working directory, cd, git -C, --git-dir, GIT_DIR or a directory mktemp made there, or that git init made under a loop variable or a helper argument. They are left out of every other count.',
  commitsWithoutSkill: 'Commits in a turn that loaded no commit skill. prWritesWithoutSkill is the same for gh pr create, edit, ready, close or reopen and the pr skill.',
  posts: 'gh pr or issue comment, gh pr review, gh api calls that write comments, reviews or replies, and MCP comment, reply, post or send tools.',
  anotherPass: 'Typed messages asking for another, one more, final, second, third or fresh pass, review, verification, round or look, for something one more time, for a re-review, or to review, verify or check again.',
  editingFamilies: 'Families with an Edit, MultiEdit, Write or NotebookEdit call.',
  draftRequests: 'Typed messages asking for a draft, or to give, write, prepare or compose a comment, reply, message or response. draftsWithFile counts those whose turn wrote a file.',
  compactions: 'compact_boundary entries. typedCompact counts typed /compact.',
  reviewRuns: 'code-review or review loaded through the Skill tool or typed. ultraReviews counts those with ultra.',
  reviewTokens: 'Input, output and cache-write tokens of replies attributed to code-review or review, each reply counted once. reviewCacheReads holds their cache reads.',
  hookErrors: 'Error lines in the eng hook log.',
};

const USAGE = `usage: npm run stats -- [--since YYYY-MM-DD] [--until YYYY-MM-DD]
                        [--project <substring>] [--json]
                        [--save <file>] [--compare <file>]`;

function fail(message) {
  process.stderr.write(`stats: ${message}\n${USAGE}\n`);
  process.exit(2);
}

function parseArgs(argv) {
  const opts = { json: false };
  const takes = { '--since': 'since', '--until': 'until', '--project': 'project', '--save': 'save', '--compare': 'compare' };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--json') opts.json = true;
    else if (arg === '--help' || arg === '-h') {
      process.stdout.write(`${USAGE}\n`);
      process.exit(0);
    } else if (takes[arg]) {
      if (i + 1 >= argv.length) fail(`${arg} needs a value`);
      opts[takes[arg]] = argv[++i];
    } else fail(`unknown flag ${arg}`);
  }
  // A window with no end runs to today, and says so in what it saves, so a
  // baseline's per-week rates do not depend on the day they are read.
  opts.until ??= new Date().toISOString().slice(0, 10);
  for (const key of ['since', 'until']) {
    if (opts[key] !== undefined && !/^\d{4}-\d{2}-\d{2}$/.test(opts[key])) fail(`--${key} takes a date as YYYY-MM-DD`);
  }
  return opts;
}

// --- Reading what a message says ---------------------------------------

const NOT_TYPED = /^<(task-notification|local-command-std(out|err)|bash-std(out|err)|relay\b|project_claude_message|cross-session-message|coordinator-relay)/;

function unescapeXml(text) {
  return text.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');
}

// Returns { text, command } for a message you typed, or null for anything
// else that arrives as a user entry.
function typedMessage(entry) {
  if (entry.type !== 'user' || entry.isMeta || entry.isCompactSummary || entry.isSidechain) return null;
  if (entry.origin && entry.origin.kind !== 'human') return null;
  const content = entry.message?.content;
  let text;
  if (typeof content === 'string') text = content;
  else if (Array.isArray(content)) {
    if (content.some((block) => block.type === 'tool_result')) return null;
    text = content.filter((block) => block.type === 'text').map((block) => block.text).join('\n');
  } else return null;

  text = text.replace(/<system-reminder>[\s\S]*?<\/system-reminder>/g, '').trim();
  if (text.startsWith('<wake')) {
    // A project thread wraps the message in an envelope. The message that
    // woke the session is the one marked trigger="true".
    const message = /<message\b([^>]*\btrigger="true"[^>]*)>([\s\S]*?)<\/message>/.exec(text);
    if (!message || !/\bfrom="human"/.test(message[1])) return null;
    text = unescapeXml(message[2]).trim();
  }
  if (!text || NOT_TYPED.test(text)) return null;

  const name = /<command-name>\/?([^<]+)<\/command-name>/.exec(text);
  if (name) {
    const args = /<command-args>([\s\S]*?)<\/command-args>/.exec(text);
    const command = name[1].trim();
    return { text: `/${command} ${args ? args[1].trim() : ''}`.trim(), command };
  }
  const bash = /^<bash-input>([\s\S]*?)<\/bash-input>/.exec(text);
  if (bash) return { text: `!${bash[1]}`, command: null };
  return { text, command: null };
}

// --- Recognising remote writes -----------------------------------------

const GH_WRITES = [
  ['post', /^gh\s+(?:pr|issue)\s+comment\b|^gh\s+pr\s+review\b/],
  ['pr', /^gh\s+pr\s+(?:create|edit|ready|close|reopen)\b/],
  ['merge', /^gh\s+pr\s+merge\b/],
  ['issue', /^gh\s+issue\s+(?:create|edit|close|reopen|delete|transfer|lock|unlock|pin|unpin)\b/],
  ['label', /^gh\s+label\s+(?:create|edit|delete|clone)\b/],
  ['release', /^gh\s+release\s+(?:create|edit|delete|upload)\b/],
];
const POST_PATH = /comments|reviews|replies/;
const POST_MUTATION = /\b(?:addComment|addPullRequestReview\w*|submitPullRequestReview)\b/;

// The words of one simple command, each quoted string kept whole.
const words = (raw) => raw.match(/(?:"(?:[^"\\]|\\.)*"|'[^']*'|[^\s"'])+/g) || [];
const unquote = (word) => word.replace(/^(['"])(.*)\1$/s, '$2');

// gh api writes when it is told a write method, or when it sends fields
// without -X GET. A graphql call writes only when it holds a mutation. The
// method and the path are read from the words of the command, so text inside
// a field's value decides neither.
const GH_API_VALUE_FLAGS = new Set(['-H', '--header', '-q', '--jq', '-t', '--template', '-p', '--preview', '--hostname', '--cache']);
const GH_API_FIELD_FLAGS = new Set(['-f', '-F', '--field', '--raw-field', '--input']);
function ghApiWrite(raw) {
  const list = words(raw).slice(2);
  let method = null;
  let fields = false;
  let target = null;
  for (let i = 0; i < list.length; i++) {
    const word = list[i];
    const attached = /^(?:-X|--method=)(\S+)$/.exec(word);
    if (attached) method = unquote(attached[1]);
    else if (word === '-X' || word === '--method') method = unquote(list[++i] || '');
    else if (GH_API_FIELD_FLAGS.has(word)) {
      fields = true;
      i++;
    } else if (/^(?:--field|--raw-field|--input)=|^-[fF]\S/.test(word)) fields = true;
    else if (GH_API_VALUE_FLAGS.has(word)) i++;
    else if (!word.startsWith('-') && target === null) target = unquote(word);
  }
  if (target === 'graphql') {
    if (!/\bmutation\b/.test(raw)) return null;
    return POST_MUTATION.test(raw) ? 'post' : 'api';
  }
  const verb = method ? method.toUpperCase() : fields ? 'POST' : 'GET';
  if (verb === 'GET') return null;
  return POST_PATH.test(target || '') ? 'post' : 'api';
}

// git's own options come before the subcommand. Returns the subcommand,
// every directory -C names in order, and the --git-dir, which decides the
// repo over the work tree. A commit's -C <commit> or a -C in a message is
// not one.
const GIT_VALUE_FLAGS = new Set(['-c', '--work-tree', '--namespace', '--exec-path', '--super-prefix', '--config-env', '--attr-source']);
function gitCommand(raw) {
  const list = words(raw).slice(1);
  const targets = [];
  let gitDir = null;
  for (let i = 0; i < list.length; i++) {
    const word = list[i];
    const attached = /^-C(.+)$/.exec(word);
    const named = /^--git-dir=(.+)$/.exec(word);
    if (attached) targets.push(attached[1]);
    else if (word === '-C') targets.push(list[++i] || '');
    else if (named) gitDir = named[1];
    else if (word === '--git-dir') gitDir = list[++i] || '';
    else if (GIT_VALUE_FLAGS.has(word)) i++;
    else if (!word.startsWith('-')) return { sub: word, targets, gitDir };
  }
  return { sub: null, targets, gitDir };
}

// The index just past the parenthesis that closes the one at i.
function closing(text, i) {
  let depth = 0;
  let j = i;
  do {
    if (text[j] === '(') depth++;
    else if (text[j] === ')') depth--;
    j++;
  } while (j < text.length && depth > 0);
  return j;
}

// Whether $(( or (( at i starts arithmetic. Arithmetic ends in )) closing
// both parentheses together. When the inner one closes first, as in
// ((cd x && git push) || true), the (( opened two subshells, which is how
// bash reads it too.
function arithmeticAt(text, i) {
  const start = text.startsWith('$((', i) ? i + 1 : text.startsWith('((', i) ? i : -1;
  if (start === -1) return false;
  return closing(text, start + 1) === closing(text, start) - 1;
}

// Removes arithmetic, $(( )) and (( )), from a command, each to its own
// closing parentheses.
function stripArithmetic(text) {
  let out = '';
  for (let i = 0; i < text.length; i++) {
    if (arithmeticAt(text, i)) i = closing(text, text[i] === '$' ? i + 1 : i) - 1;
    else out += text[i];
  }
  return out;
}

// Drops heredoc bodies, which hold scripts, messages and test cases that
// name commands without running them. It reads the whole command the way the
// shell does: a << inside quotes, (( )) or a comment opens nothing, and
// neither does a here-string (<<<), but one inside a $( ) does, even when the
// $( ) sits in double quotes, as in -m "$(cat <<'EOF' ... )".
function dropHeredocs(command) {
  let out = '';
  const pending = [];
  // Each context is a quote, or a command level with its own parenthesis
  // depth and arithmetic depth. The bottom one is the command itself.
  const stack = [{ kind: 'sh', parens: 0, arithmetic: 0 }];
  for (let i = 0; i < command.length; i++) {
    const c = command[i];
    const top = stack.at(-1);
    if (c === '\n' && pending.length) {
      out += c;
      // Skip each body up to its delimiter line.
      while (pending.length && i < command.length) {
        const end = command.indexOf('\n', i + 1);
        const line = command.slice(i + 1, end === -1 ? command.length : end);
        i = end === -1 ? command.length : end;
        if (line.trim() === pending[0]) pending.shift();
      }
      if (i < command.length) i--;
      continue;
    }
    out += c;
    if (top.kind === "'") {
      if (c === "'") stack.pop();
    } else if (top.kind === '"') {
      if (c === '\\') out += command[++i] ?? '';
      else if (c === '"') stack.pop();
      else if (command.startsWith('$(', i) && !command.startsWith('$((', i)) {
        out += command[++i];
        stack.push({ kind: 'sh', parens: 0, arithmetic: 0 });
      }
    } else if (c === '\\') out += command[++i] ?? '';
    else if (c === "'" || c === '"') stack.push({ kind: c });
    else if (c === '#' && (i === 0 || /\s/.test(command[i - 1]))) {
      while (i + 1 < command.length && command[i + 1] !== '\n') out += command[++i];
    } else if (arithmeticAt(command, i)) {
      top.arithmetic++;
      const skip = c === '$' ? 2 : 1;
      out += command.slice(i + 1, i + 1 + skip);
      i += skip;
    } else if (top.arithmetic && command.startsWith('))', i)) {
      top.arithmetic--;
      out += command[++i];
    } else if (command.startsWith('$(', i)) {
      out += command[++i];
      stack.push({ kind: 'sh', parens: 0, arithmetic: 0 });
    } else if (c === '(') top.parens++;
    else if (c === ')') {
      if (top.parens) top.parens--;
      else if (stack.length > 1) stack.pop();
    } else if (!top.arithmetic && command.startsWith('<<<', i)) {
      out += command.slice(i + 1, i + 3);
      i += 2;
    } else if (!top.arithmetic && command.startsWith('<<', i)) {
      const match = /^<<-?\s*\\?(['"]?)([A-Za-z_]\w*)\1/.exec(command.slice(i));
      if (match) {
        pending.push(match[2]);
        out += match[0].slice(1);
        i += match[0].length - 1;
      }
    }
  }
  return out;
}

// Keywords that may come before a command, as in "then git push".
const KEYWORDS = String.raw`(?:(?:if|then|elif|else|while|until|do|time|!|\{)\s+)*`;
const AFTER_KEYWORDS = new RegExp(`^${KEYWORDS}`);

// Splits a command line into simple commands at the operators outside
// quotes, and drops comments. Each comes back raw and bare, the bare one with
// every quoted string emptied, so a grep pattern or a commit message naming a
// write is not one. A subshell's start and end, from ( ), $( ) or backticks,
// come back as markers, so a cd inside one ends with it, and so do a case
// and esac. Arithmetic, $(( )) or (( )), stays inside its command, and a case
// pattern's ) closes nothing.
function splitShell(command) {
  const segments = [];
  const open = [];
  let raw = '';
  let bare = '';
  let quote = null;
  const add = (text) => {
    raw += text;
    bare += text;
  };
  // case and esac open and close a case, after any keyword that may come
  // before a command. Each word is read once, however often this runs. A
  // case is a scope like a subshell, since a cd in one branch may not run.
  let read = -1;
  const word = () => {
    if (read === bare.trimEnd().length) return;
    read = bare.trimEnd().length;
    const w = bare.trim().replace(AFTER_KEYWORDS, '');
    if (w === 'case') {
      open.push('case');
      segments.push({ marker: 'open', scope: 'case' });
    } else if (/^esac(?=$|[\s;&|<>()])/.test(w) && open.at(-1) === 'case') {
      open.pop();
      segments.push({ marker: 'close', scope: 'case' });
    }
  };
  const cut = (marker) => {
    word();
    read = -1;
    if (bare.trim()) segments.push({ raw: raw.trim(), bare: bare.trim() });
    if (marker) segments.push({ marker });
    raw = '';
    bare = '';
  };
  for (let i = 0; i < command.length; i++) {
    const c = command[i];
    if (quote) {
      raw += c;
      if (c === '\\' && quote === '"' && i + 1 < command.length) raw += command[++i];
      else if (c === quote) {
        bare += c;
        quote = null;
      }
      continue;
    }
    if (c === '#' && /(?:^|\s)$/.test(bare)) {
      while (i + 1 < command.length && command[i + 1] !== '\n') i++;
    } else if (c === '\\' && i + 1 < command.length) {
      add(c + command[++i]);
    } else if (c === "'" || c === '"') {
      quote = c;
      add(c);
    } else if (arithmeticAt(command, i)) {
      // Arithmetic, which may nest parentheses, stays in its command.
      const j = closing(command, c === '$' ? i + 1 : i);
      add(command.slice(i, j));
      i = j - 1;
    } else if (command.startsWith('$(', i) || c === '(') {
      open.push('(');
      cut('open');
      if (c === '$') i++;
    } else if (c === ')') {
      if (!/\s$/.test(bare)) word();
      // A case pattern's ) ends the pattern, and a command follows it.
      if (open.at(-1) === 'case') cut();
      else {
        if (open.at(-1) === '(') open.pop();
        cut('close');
      }
    } else if (c === '`') {
      if (open.at(-1) === '`') {
        open.pop();
        cut('close');
      } else {
        open.push('`');
        cut('open');
      }
    } else if (c === ';' && open.at(-1) === 'case' && (command[i + 1] === ';' || command[i + 1] === '&')) {
      // ;;, ;& and ;;& end a case branch. Each branch starts where the case
      // did, even one that ;& falls into: which branch ran is unknown.
      word();
      if (bare.trim()) segments.push({ raw: raw.trim(), bare: bare.trim() });
      raw = '';
      bare = '';
      read = -1;
      segments.push({ marker: 'close', scope: 'case' }, { marker: 'open', scope: 'case' });
      i += command.startsWith(';;&', i) ? 2 : 1;
    } else if (';\n|&'.includes(c)) {
      if (c === '&' && /[<>]$/.test(bare)) add(c); // 2>&1 and >&2 redirect
      else cut();
    } else {
      if (/\s/.test(c) && !/\s$/.test(bare)) word();
      add(c);
    }
  }
  cut();
  return segments;
}

const LEADING = /^(?:(?:[A-Za-z_]\w*=(?:"(?:[^"\\]|\\.)*"|'[^']*'|\\.|[^\s"'\\])*|if|then|elif|else|while|until|do|!|\{|command|exec|time|env|nohup|sudo(?:\s+-u\s+\S+|\s+-\w+)*|xargs(?:\s+-I\s*\S+|\s+-\w+(?:\s+\d+)?)*|timeout(?:\s+-[sk]\s+\S+|\s+--(?:signal|kill-after)(?:=\S+|\s+\S+)|\s+-\S+)*\s+\S+)\s+)+/;
const DECLARE = new RegExp(`^${KEYWORDS}(?:(?:export|local|declare|readonly|typeset)(?:\\s+(?:--|[-+]\\w+))*\\s+)?`);
const TMP = /^(?:\/private)?\/(?:tmp|var\/folders)\//;
const ASSIGNMENT = /([A-Za-z_]\w*)=("[^"]*"|'[^']*'|\S*)/g;
const ASSIGNMENTS = /^(?:[A-Za-z_]\w*=(?:"[^"]*"|'[^']*'|\S*)\s*)+$/;
// Replaces each $(mktemp ...) or `mktemp ...` with a placeholder, and
// keeps its arguments, so the directory it makes can be read once the
// directory and variables at that point are known.
function replaceMktemp(text, made) {
  const hold = (args) => `__mktemp${made.push(args) - 1}__`;
  let out = text.replace(/`\s*mktemp\b([^`]*)`/g, (m, args) => hold(args));
  for (let start = out.search(/\$\(\s*mktemp\b/); start !== -1; start = out.search(/\$\(\s*mktemp\b/)) {
    let depth = 0;
    let end = start + 1;
    for (; end < out.length; end++) {
      if (out[end] === '(') depth++;
      else if (out[end] === ')' && --depth === 0) break;
    }
    const args = out.slice(out.indexOf('mktemp', start) + 6, end);
    out = out.slice(0, start) + hold(args) + out.slice(end + 1);
  }
  return out;
}

// The directory git init names, past the options that take a value.
const INIT_VALUE_FLAGS = new Set(['-b', '--initial-branch', '--template', '--separate-git-dir', '--object-format', '--ref-format']);
function initDirectory(raw) {
  const list = words(raw);
  for (let i = list.indexOf('init') + 1; i < list.length; i++) {
    if (INIT_VALUE_FLAGS.has(list[i])) i++;
    else if (!list[i].startsWith('-')) return list[i];
  }
  return null;
}

// A path from a directory. A directory this script cannot place, such as
// one under ~ or a relative one, stays relative: resolving it would use this
// script's own working directory.
function resolveFrom(from, to) {
  if (/^[/~]/.test(to) || !from) return to;
  return from.startsWith('/') ? path.posix.resolve(from, to) : path.posix.join(from, to);
}

// Reads one Bash call: the remote writes it makes, whether each lands in a
// throwaway repo under a temporary directory, and whether it writes a file.
// It follows cd, cd -, subshells, git -C, --git-dir and GIT_DIR through the
// call, with the variables it sets, and places what mktemp makes. A repo git
// init made under a loop variable or a helper's argument is a scaffold.
function bashCall(command, cwd) {
  const vars = {};
  const temps = [];
  // mktemp makes its directory under -p DIR or --tmpdir=DIR, under the
  // temporary directory with -t, a bare --tmpdir or no template, and beside
  // its template otherwise, which for a bare template is the current
  // directory.
  const mktempDir = (args) => {
    const list = words(args);
    let base = null;
    let temporary = false;
    let template = null;
    for (let i = 0; i < list.length; i++) {
      const word = list[i];
      if (word.startsWith('--tmpdir=')) base = word.slice(9);
      else if (word === '--tmpdir') temporary = true;
      else if (/^-[a-zA-Z]/.test(word) && !word.startsWith('--')) {
        // Short flags may come together, as in -dt. -p takes the rest of
        // its word, or the next word, as its directory.
        for (let k = 1; k < word.length; k++) {
          if (word[k] === 't') temporary = true;
          else if (word[k] === 'p') {
            base = word.slice(k + 1) || list[++i] || '';
            break;
          }
        }
      } else if (!word.startsWith('-')) template = unquote(word);
    }
    if (base !== null) return `${resolveFrom(dir, expand(base))}/mktemp`;
    if (temporary || template === null) return '/tmp/mktemp';
    return `${resolveFrom(dir, expand(path.posix.dirname(template)))}/mktemp`;
  };
  // $PWD is the directory at that point, $HOME is ~, and $TMPDIR is
  // temporary when the call did not set them.
  const known = (name) => (name === 'PWD' && dir ? dir : name === 'HOME' ? '~' : name === 'TMPDIR' ? '/tmp' : undefined);
  const expand = (word) =>
    unquote(word)
      .replace(/__mktemp(\d+)__/g, (m, n) => mktempDir(temps[n]))
      .replace(/\$\{(\w+)(:?)-([^}]*)\}/g, (m, name, colon, fallback) => {
        const value = vars[name] ?? known(name);
        return value === undefined || (colon && value === '') ? fallback : value;
      })
      .replace(/\$\{?(\w+)\}?/g, (m, name) => vars[name] ?? known(name) ?? m);
  let dir = cwd || '';
  let last = dir;
  const dirs = [];
  const writes = [];
  let wroteFile = false;
  const made = new Set();
  const text = replaceMktemp(dropHeredocs(command), temps);
  const segments = splitShell(text);
  // Variables a loop, a read or a helper's arguments fill, which the call
  // cannot name. They come from the split commands, so quotes and comments
  // hide none.
  const loops = [];
  for (const { bare } of segments) {
    if (!bare) continue;
    const loop = new RegExp(`^${KEYWORDS}(?:for|select)\\s+(\\w+)\\s+in\\b`).exec(bare);
    const read = new RegExp(`^${KEYWORDS}read((?:\\s+-\\w+)*)((?:\\s+\\w+)+)`).exec(bare);
    if (loop) loops.push(loop[1]);
    if (read) loops.push(...read[2].trim().split(/\s+/));
  }
  const unnamed = new RegExp(`\\$\\{?(?:[\\d@*]${loops.map((name) => `|${name}\\b`).join('')})`);
  // Exported names reach git; a plain assignment does not, unless set -a is
  // on. A subshell keeps its own copy of both; a case branch does not.
  let exported = new Set();
  let exportAll = false;
  for (const segment of segments) {
    if (segment.marker === 'open') {
      dirs.push([dir, last, { ...vars }, new Set(exported), exportAll]);
      continue;
    }
    if (segment.marker === 'close') {
      if (dirs.length) {
        const [d, l, savedVars, savedExported, savedAll] = dirs.pop();
        [dir, last] = [d, l];
        if (segment.scope !== 'case') {
          for (const name of Object.keys(vars)) delete vars[name];
          Object.assign(vars, savedVars);
          [exported, exportAll] = [savedExported, savedAll];
        }
      }
      continue;
    }
    const bareCommand = segment.bare.replace(AFTER_KEYWORDS, '');
    if (/^set\s+[-+]\w*a/.test(bareCommand)) {
      exportAll = bareCommand.startsWith('set -');
      continue;
    }
    // export NAME, export -n NAME, declare -x and +x, and the rest.
    const declaration = /^(export|local|declare|readonly|typeset)((?:\s+(?:--|[-+]\w+))*)(?:\s|$)/.exec(segment.raw.replace(AFTER_KEYWORDS, ''));
    const flags = declaration ? declaration[2] : '';
    const exporting = exportAll || (declaration && (declaration[1] === 'export' ? !/\s-\w*n/.test(flags) : /\s-\w*x/.test(flags)));
    const unexporting = declaration && (declaration[1] === 'export' ? /\s-\w*n/.test(flags) : /\s\+\w*x/.test(flags));
    const raw = segment.raw.replace(DECLARE, '');
    const unset = /^unset((?:\s+-\w+)*)\s+(.+)$/.exec(raw);
    if (unset) {
      // unset -f removes functions and leaves variables alone.
      if (!/f/.test(unset[1])) {
        for (const name of unset[2].split(/\s+/)) {
          delete vars[name];
          exported.delete(name);
        }
      }
      continue;
    }
    if (declaration && /^[A-Za-z_]\w*(?:\s+[A-Za-z_]\w*)*$/.test(raw.trim())) {
      for (const name of raw.trim().split(/\s+/)) {
        if (exporting) exported.add(name);
        if (unexporting) exported.delete(name);
      }
      continue;
    }
    if (ASSIGNMENTS.test(raw)) {
      for (const [, name, value] of raw.matchAll(ASSIGNMENT)) {
        vars[name] = expand(value);
        if (exporting) exported.add(name);
        if (unexporting) exported.delete(name);
      }
      continue;
    }
    const body = raw.replace(LEADING, '');
    const bare = segment.bare.replace(DECLARE, '').replace(LEADING, '');
    const plain = stripArithmetic(bare).replace(/\[\[[\s\S]*?\]\]/g, '');
    if (/(?<![=>])>{1,2}\s*(?!&|\/dev\/null\b)[^\s|&>]/.test(plain) || /^tee\s/.test(bare)) wroteFile = true;
    const cd = /^cd\s+("[^"]*"|'[^']*'|\S+)/.exec(body);
    if (cd) {
      const to = expand(cd[1]);
      [dir, last] = [to === '-' ? last : resolveFrom(dir, to), dir];
      continue;
    }
    if (/\s(?:--help|-h)(?:\s|$)/.test(bare)) continue;
    let kind = null;
    let where = dir;
    if (/^git\s/.test(bare)) {
      const { sub, targets, gitDir: named } = gitCommand(body);
      // GIT_DIR set before git on its line, or exported earlier in the call.
      const before = words(raw.slice(0, raw.length - body.length)).find((w) => w.startsWith('GIT_DIR='));
      const gitDir = named ?? (before ? before.slice(8) : exported.has('GIT_DIR') ? vars.GIT_DIR : undefined);
      if (sub === 'commit' || sub === 'push') kind = sub;
      for (const target of targets) where = resolveFrom(where, expand(target));
      if (gitDir) where = resolveFrom(where, expand(gitDir));
      if (sub === 'init') {
        const arg = initDirectory(body);
        made.add(arg ? resolveFrom(where, expand(arg)) : where);
      }
    } else if (/^gh\s+api\b/.test(bare)) kind = ghApiWrite(body);
    else if (/^gh\s/.test(bare)) kind = GH_WRITES.find(([, pattern]) => pattern.test(bare))?.[0] ?? null;
    if (!kind) continue;
    // A repo git init made in a directory a helper's argument or a loop
    // variable names, such as $1, is a scaffold.
    const scratch = TMP.test(where) || (unnamed.test(where) && made.has(where));
    // One call that commits twice, or defines a helper that does, is one write.
    if (!writes.some((w) => w.kind === kind && w.scratch === scratch)) writes.push({ kind, scratch });
  }
  return { writes, wroteFile };
}

// MCP servers that only talk to this machine or this project's own chat.
const LOCAL_MCP = /^(?:hearthbot|ccd_|claude-code-remote|Claude_Browser|claude-in-chrome|Claude_Code_iOS|visualize|terminal|scheduled-tasks|mcp-registry|memory)/;
const MCP_WRITE = /(?:^|[_-])(?:create|update|delete|send|post|add|reply|comment|merge|publish|upload|share|trash|copy|move|append|insert|clear|edit|remove)(?:[_-]|$)/i;
const MCP_POST = /(?:^|[_-])(?:comment|reply|post|send)(?:[_-]|$)/i;

function mcpWrite(name) {
  const match = /^mcp__(.+?)__(.+)$/.exec(name);
  if (!match || LOCAL_MCP.test(match[1]) || !MCP_WRITE.test(match[2])) return null;
  return MCP_POST.test(match[2]) ? 'post' : 'mcp';
}

// The words in your message that ask for each kind of write. Asking to push
// asks for the commit it needs. An approval such as "yes" or "go ahead" names
// no write and is counted apart, because an approval is not a request: the
// workflow wants those confirmed.
const APPROVAL = /^\W*(?:yes|yep|yeah|ok(?:ay)?|sure|go ahead|proceed|approved?|do it|sounds good|lgtm|looks good)\b/i;
const ANY_REQUEST = /\b(?:commit|push|ship|check in|prs?|pull requests?|merge|issues?|tickets?|labels?|release|tag|post|comment|reply|send|submit)\b/i;
const REQUEST = {
  commit: /\b(?:commit|push|ship|check in)/i,
  push: /\b(?:push|ship)/i,
  pr: /\b(?:prs?|pull requests?|title|description)\b/i,
  merge: /\bmerge/i,
  issue: /\b(?:issues?|tickets?)\b/i,
  label: /\blabel/i,
  release: /\b(?:release|tag)/i,
  post: /\b(?:post|comment|reply|send|submit)/i,
  api: ANY_REQUEST,
  mcp: ANY_REQUEST,
};

const ANOTHER_PASS = /\b(?:another|one more|final|second|third|fresh)\b[^.?!\n]{0,40}?\b(?:pass|review|verification|round|look)\b|\bone more time\b|\bre-?review\b|\b(?:review|verify|check)\w*\s+(?:it\s+|this\s+|that\s+|them\s+)?again\b/i;
const DRAFT = /\bdrafts?\b|\b(?:give me|write|prepare|compose)\b[^.?!\n]{0,60}?\b(?:comment|reply|message|response)\b/i;
const EDIT_TOOLS = new Set(['Edit', 'MultiEdit', 'Write', 'NotebookEdit']);
const REVIEW_SKILLS = new Set(['code-review', 'review']);
const skillName = (name) => String(name || '').replace(/^eng:/, '');

// --- Reading the files ---------------------------------------------------

function transcriptFiles(projects, filter) {
  const files = [];
  for (const project of fs.readdirSync(projects, { withFileTypes: true })) {
    if (!project.isDirectory() || (filter && !project.name.includes(filter))) continue;
    const dir = path.join(projects, project.name);
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.isFile() && entry.name.endsWith('.jsonl')) {
        files.push({ file: path.join(dir, entry.name), session: entry.name.slice(0, -6), sub: false });
      } else if (entry.isDirectory()) {
        const subagents = path.join(dir, entry.name, 'subagents');
        if (!fs.existsSync(subagents)) continue;
        for (const sub of fs.readdirSync(subagents)) {
          if (sub.endsWith('.jsonl')) files.push({ file: path.join(subagents, sub), session: entry.name, sub: true });
        }
      }
    }
  }
  // Main files first, so a turn belongs to the session you typed in rather
  // than to one of its subagents.
  return files.sort((a, b) => a.sub - b.sub || a.file.localeCompare(b.file));
}

class Families {
  constructor() {
    this.parent = new Map();
  }
  find(id) {
    let root = id;
    while (this.parent.has(root) && this.parent.get(root) !== root) root = this.parent.get(root);
    this.parent.set(id, root);
    return root;
  }
  join(a, b) {
    const ra = this.find(a);
    const rb = this.find(b);
    if (ra !== rb) this.parent.set(rb, ra);
  }
}

async function collect(files) {
  const seen = new Map(); // uuid to the file session it was first read in
  const families = new Families();
  const typed = []; // { ts, session, prompt, text, command }
  const turns = new Map(); // promptId to the turn
  const compactions = []; // { ts, session }
  const review = new Map(); // requestId to { ts, session, tokens }
  const reviewRuns = []; // { ts, session, args }

  const turnFor = (prompt, session, ts) => {
    let turn = turns.get(prompt);
    if (!turn) {
      turn = { session, ts, typed: null, skills: new Set(), writes: [], scratchWrites: 0, edits: false, wroteFile: false };
      turns.set(prompt, turn);
    }
    if (ts && (!turn.ts || ts < turn.ts)) turn.ts = ts;
    return turn;
  };

  for (const { file, session: fileSession, sub } of files) {
    families.find(fileSession);
    let prompt = null;
    const lines = readline.createInterface({ input: fs.createReadStream(file), crlfDelay: Infinity });
    for await (const line of lines) {
      if (!line) continue;
      let entry;
      try {
        entry = JSON.parse(line);
      } catch {
        continue;
      }
      if (entry.promptId) prompt = entry.promptId;
      // A resumed or forked session starts with copies of the entries it
      // continues, which keep the sessionId of the session that wrote them.
      // That id, not the file, says whose entry it is, and the two sessions
      // are one family.
      const session = (!sub && entry.sessionId) || fileSession;
      if (session !== fileSession) families.join(fileSession, session);
      if (entry.uuid) {
        const first = seen.get(entry.uuid);
        if (first !== undefined) {
          if (!sub) families.join(first, fileSession);
          continue;
        }
        seen.set(entry.uuid, fileSession);
      }
      const ts = entry.timestamp;
      if (!ts) continue;
      const turn = prompt ? turnFor(prompt, session, ts) : null;
      if (entry.attributionSkill && turn) turn.skills.add(skillName(entry.attributionSkill));

      if (entry.type === 'system' && entry.subtype === 'compact_boundary') {
        compactions.push({ ts, session });
        continue;
      }

      if (entry.type === 'user' && !sub) {
        const message = typedMessage(entry);
        if (message) {
          typed.push({ ts, session, prompt, ...message });
          if (turn && !turn.typed) turn.typed = message.text;
          if (message.command) {
            const name = skillName(message.command);
            if (turn) turn.skills.add(name);
            if (REVIEW_SKILLS.has(name)) reviewRuns.push({ ts, session, args: message.text });
          }
        }
        continue;
      }

      if (entry.type !== 'assistant') continue;
      const usage = entry.message?.usage;
      if (usage && REVIEW_SKILLS.has(skillName(entry.attributionSkill))) {
        // A reply split into several entries repeats its usage on each.
        const tokens = (usage.input_tokens || 0) + (usage.output_tokens || 0) + (usage.cache_creation_input_tokens || 0);
        const cacheReads = usage.cache_read_input_tokens || 0;
        const key = entry.requestId || entry.uuid;
        const known = review.get(key);
        if (!known || tokens > known.tokens) review.set(key, { ts: known ? known.ts : ts, session, tokens, cacheReads });
      }
      const content = entry.message?.content;
      if (!Array.isArray(content) || !turn) continue;
      for (const block of content) {
        if (block.type !== 'tool_use') continue;
        const input = block.input || {};
        if (block.name === 'Skill') {
          const name = skillName(input.skill);
          turn.skills.add(name);
          if (REVIEW_SKILLS.has(name)) reviewRuns.push({ ts, session, args: String(input.args || '') });
        } else if (block.name === 'Bash') {
          const command = String(input.command || '');
          const call = bashCall(command, entry.cwd);
          for (const { kind, scratch } of call.writes) {
            if (scratch) turn.scratchWrites++;
            else turn.writes.push({ kind, sub, ts });
          }
          if (call.wroteFile) turn.wroteFile = true;
        } else if (block.name.startsWith('mcp__')) {
          const kind = mcpWrite(block.name);
          if (kind) turn.writes.push({ kind, sub, ts });
        }
        if (EDIT_TOOLS.has(block.name)) {
          turn.edits = true;
          if (block.name === 'Write') turn.wroteFile = true;
        }
      }
    }
  }
  return { families, typed, turns, compactions, review, reviewRuns };
}

function readHookErrors(log) {
  if (!fs.existsSync(log)) return [];
  return fs
    .readFileSync(log, 'utf8')
    .split('\n')
    .filter((line) => / error: /.test(line))
    .map((line) => ({ ts: line.split(' ')[0] }));
}

// --- Counting --------------------------------------------------------------

function weekOf(ts) {
  const date = new Date(ts);
  date.setUTCHours(0, 0, 0, 0);
  date.setUTCDate(date.getUTCDate() - ((date.getUTCDay() + 6) % 7));
  return date.toISOString().slice(0, 10);
}

function emptyBucket() {
  return {
    typed: 0, sessions: new Set(), families: new Set(),
    writeTurns: 0, unaskedWriteTurns: 0, approvedWriteTurns: 0, writes: {}, subagentWrites: 0, scratchWrites: 0,
    commitsWithoutSkill: 0, prWritesWithoutSkill: 0, posts: 0,
    anotherPass: 0, editingFamilies: new Set(),
    draftRequests: 0, draftsWithFile: 0,
    compactions: 0, typedCompact: 0, familiesCompacted: new Set(),
    reviewRuns: 0, ultraReviews: 0, reviewTokens: 0, reviewCacheReads: 0, reviewedSessions: new Set(),
    hookErrors: 0,
  };
}

function finish(bucket) {
  const out = {};
  for (const [key, value] of Object.entries(bucket)) out[key] = value instanceof Set ? value.size : value;
  return out;
}

// The latest message you typed in the family at or before a time. A resumed
// session's first turns can follow a message the session before it holds.
function latestTyped(byFamily, family, ts) {
  const list = byFamily.get(family) || [];
  let found = null;
  for (const message of list) {
    if (message.ts > ts) break;
    found = message;
  }
  return found ? found.text : '';
}

function count(data, hookErrors, opts) {
  const start = opts.since ? `${opts.since}T00:00:00` : '';
  const end = opts.until ? new Date(Date.parse(`${opts.until}T00:00:00Z`) + 86400000).toISOString() : '\uffff';
  const inWindow = (ts) => ts >= start && ts < end;
  const weeks = new Map();
  const totals = emptyBucket();
  const add = (ts, fn) => {
    if (!inWindow(ts)) return;
    const week = weekOf(ts);
    if (!weeks.has(week)) weeks.set(week, emptyBucket());
    fn(weeks.get(week));
    fn(totals);
  };
  const family = (session) => data.families.find(session);

  const byFamily = new Map();
  for (const message of data.typed.sort((a, b) => (a.ts < b.ts ? -1 : a.ts > b.ts ? 1 : 0))) {
    const key = family(message.session);
    if (!byFamily.has(key)) byFamily.set(key, []);
    byFamily.get(key).push(message);
    add(message.ts, (b) => {
      b.typed++;
      b.sessions.add(message.session);
      b.families.add(family(message.session));
      if (ANOTHER_PASS.test(message.text)) b.anotherPass++;
      if (message.command === 'compact') b.typedCompact++;
      if (!message.command && DRAFT.test(message.text)) {
        b.draftRequests++;
        if (data.turns.get(message.prompt)?.wroteFile) b.draftsWithFile++;
      }
    });
  }

  for (const turn of data.turns.values()) {
    if (turn.edits) add(turn.ts, (b) => b.editingFamilies.add(family(turn.session)));
    if (turn.scratchWrites) add(turn.ts, (b) => (b.scratchWrites += turn.scratchWrites));
    if (!turn.writes.length) continue;
    const request = turn.typed ?? latestTyped(byFamily, family(turn.session), turn.ts);
    const missing = turn.writes.some((write) => !REQUEST[write.kind].test(request));
    const approved = missing && APPROVAL.test(request);
    add(turn.ts, (b) => {
      b.writeTurns++;
      if (approved) b.approvedWriteTurns++;
      else if (missing) b.unaskedWriteTurns++;
      for (const write of turn.writes) {
        b.writes[write.kind] = (b.writes[write.kind] || 0) + 1;
        if (write.sub) b.subagentWrites++;
        if (write.kind === 'post') b.posts++;
        if (write.kind === 'commit' && !turn.skills.has('commit')) b.commitsWithoutSkill++;
        if (write.kind === 'pr' && !turn.skills.has('pr')) b.prWritesWithoutSkill++;
      }
    });
  }

  for (const c of data.compactions) {
    add(c.ts, (b) => {
      b.compactions++;
      b.familiesCompacted.add(family(c.session));
    });
  }
  for (const run of data.reviewRuns) {
    add(run.ts, (b) => {
      b.reviewRuns++;
      if (/\bultra\b/.test(run.args)) b.ultraReviews++;
    });
  }
  for (const r of data.review.values()) {
    add(r.ts, (b) => {
      b.reviewTokens += r.tokens;
      b.reviewCacheReads += r.cacheReads;
      b.reviewedSessions.add(r.session);
    });
  }
  for (const e of hookErrors) add(e.ts, (b) => b.hookErrors++);

  const rows = [...weeks.keys()].sort().map((week) => ({ week, ...finish(weeks.get(week)) }));
  const total = finish(totals);
  total.weeks = spanWeeks(opts, rows);
  return { rows, total };
}

// Calendar weeks the window covers, so a per-week rate counts quiet weeks.
function spanWeeks(opts, rows) {
  const first = opts.since || rows[0]?.week;
  const last = opts.until;
  if (!first || !last) return 0;
  return Math.round((Date.parse(weekOf(`${last}T00:00:00Z`)) - Date.parse(weekOf(`${first}T00:00:00Z`))) / 604800000) + 1;
}

// --- Printing --------------------------------------------------------------

const pct = (part, whole) => (whole ? `${Math.round((100 * part) / whole)}%` : 'n/a');
const perWeek = (value, weeks) => (weeks ? (value / weeks).toFixed(1) : 'n/a');
const thousands = (value) => (value && value < 10000 ? `${(value / 1000).toFixed(1)}k` : `${Math.round(value / 1000)}k`);
const sum = (writes) => Object.values(writes).reduce((a, b) => a + b, 0);

function table(header, rows) {
  const widths = header.map((h, i) => Math.max(h.length, ...rows.map((r) => String(r[i]).length)));
  const line = (cells) => cells.map((c, i) => (i === 0 ? String(c).padEnd(widths[i]) : String(c).padStart(widths[i]))).join('  ');
  return [line(header), ...rows.map(line)].join('\n');
}

function weekly(rows, total) {
  const header = ['Week', 'Typed', 'Fam', 'Write turns', 'Unasked', 'Subagent', 'No skill', 'Posts', 'Passes', 'Drafts', 'Compact', 'Reviews', 'Review tok'];
  const cells = (r) => [
    r.week, r.typed, r.families, r.writeTurns, pct(r.unaskedWriteTurns, r.writeTurns), r.subagentWrites,
    r.commitsWithoutSkill + r.prWritesWithoutSkill, r.posts, r.anotherPass, `${r.draftsWithFile}/${r.draftRequests}`,
    r.compactions, r.reviewRuns, thousands(r.reviewTokens),
  ];
  return table(header, [...rows.map(cells), cells({ ...total, week: `All ${total.weeks} wk` })]);
}

// The numbers --compare sets beside a baseline: rates per week, or shares where a count only
// means something against its whole.
function headline(t) {
  return [
    ['Typed messages per week', perWeek(t.typed, t.weeks)],
    ['Write turns per week', perWeek(t.writeTurns, t.weeks)],
    ['Unasked write turns', pct(t.unaskedWriteTurns, t.writeTurns)],
    ['Write turns on an approval', pct(t.approvedWriteTurns, t.writeTurns)],
    ['Remote writes per week', perWeek(sum(t.writes), t.weeks)],
    ['Subagent writes per week', perWeek(t.subagentWrites, t.weeks)],
    ['Commits without the skill', pct(t.commitsWithoutSkill, t.writes.commit || 0)],
    ['PR writes without the skill', pct(t.prWritesWithoutSkill, t.writes.pr || 0)],
    ['Posts per week', perWeek(t.posts, t.weeks)],
    ['Another-pass per editing family', t.editingFamilies ? (t.anotherPass / t.editingFamilies).toFixed(1) : 'n/a'],
    ['Drafts with a file', pct(t.draftsWithFile, t.draftRequests)],
    ['Families compacted', pct(t.familiesCompacted, t.families)],
    ['Review tokens per reviewed session', t.reviewedSessions ? thousands(t.reviewTokens / t.reviewedSessions) : 'n/a'],
    ['Ultra reviews', String(t.ultraReviews)],
    ['Hook errors', String(t.hookErrors)],
  ];
}

function compare(total, baseline) {
  const before = new Map(headline(baseline.totals));
  const rows = headline(total).map(([label, now]) => [label, before.get(label) ?? 'n/a', now]);
  const span = (t, o) => `${o.since || 'start'} to ${o.until || 'end'}, ${t.weeks} wk`;
  return table(['', `Baseline (${span(baseline.totals, baseline.window)})`, 'Now'], rows);
}

// --- Main ----------------------------------------------------------------

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const config = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
  const projects = path.join(config, 'projects');
  if (!fs.existsSync(projects)) {
    process.stderr.write(`stats: no transcripts at ${projects}\n`);
    process.exit(1);
  }
  let baseline;
  if (opts.compare) {
    try {
      baseline = JSON.parse(fs.readFileSync(opts.compare, 'utf8'));
    } catch (error) {
      fail(`cannot read ${opts.compare}: ${error.message}`);
    }
  }

  const files = transcriptFiles(projects, opts.project);
  const data = await collect(files);
  const hookErrors = readHookErrors(path.join(config, 'plugins', 'data', 'eng-mewanakoon', 'eng-hook.log'));
  const { rows, total } = count(data, hookErrors, opts);

  const report = {
    version: 1,
    generated: new Date().toISOString(),
    window: { since: opts.since || null, until: opts.until || null, project: opts.project || null },
    files: files.length,
    definitions: DEFINITIONS,
    totals: total,
    weeks: rows,
  };
  if (opts.save) {
    fs.mkdirSync(path.dirname(path.resolve(opts.save)), { recursive: true });
    fs.writeFileSync(opts.save, `${JSON.stringify(report, null, 2)}\n`);
  }
  if (opts.json) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
    return;
  }
  const out = [`${files.length} transcript files under ${projects}`, '', weekly(rows, total), '', table(['', 'All weeks'], headline(total))];
  if (baseline) out.push('', compare(total, baseline));
  if (opts.save) out.push('', `Saved to ${opts.save}`);
  process.stdout.write(`${out.join('\n')}\n`);
}

// Run as a script, it reports. Imported, as the tests do, it only lends
// bashCall.
export { bashCall };
const runAsScript = () => {
  try {
    return fs.realpathSync(process.argv[1]) === fileURLToPath(import.meta.url);
  } catch {
    return false;
  }
};
if (process.argv[1] && runAsScript()) {
  main().catch((error) => {
    process.stderr.write(`stats: ${error.stack || error}\n`);
    process.exit(1);
  });
}
