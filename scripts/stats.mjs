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
  typed: 'Messages you typed, including those typed while a turn ran: no tool results, task notifications, relays, compaction summaries, command output or interrupt markers. A slash command counts.',
  families: 'Sessions joined when one resumes or forks another, which shows as a shared message id or an entry carrying the other session id.',
  writeTurns: 'Turns with a remote write: git commit or push, a tag push included; gh pr, issue, label or release writes; gh repo, workflow, run, secret, variable or gist writes; gh api writes; MCP tools whose name holds a write verb, on servers other than local and project ones. A git or gh named by a path, or run through bash, sh or zsh -c, counts; one run through find -exec does not. A dry run or a help request is no write.',
  unaskedWriteTurns: 'Write turns where what you typed in the turn, or else your latest typed message before it, lacks the word for one of its writes, such as commit, push, PR, merge or post, and for an MCP write also upload or publish, or a word such as create, save, update or delete with a place such as Drive, Notion or a calendar as one of the five words after it, with no punctuation or and, then or but between them, and is no approval. A word counts with its inflections, such as pushed, and not inside a longer word, such as pushback. What follows don\'t, do not, never, no need to or without asks for nothing, up to punctuation, an em dash, an en dash not after a digit, a spaced hyphen or double hyphen, or a word such as and, but, then, before or until. A reminder still asks: a stretch that opens with forget or hesitate, as in don\'t forget to push, or, after any of those words but without, with wait to, keep waiting to, bother waiting to or waste time waiting to, also with for and a check, such as CI, tests, the build, a workflow, review or the linter, with up to two words before it and run, job, pass, to pass or to finish after it, before the to, as in don\'t wait for CI to push. Push covers commit.',
  approvedWriteTurns: 'Write turns where that text lacks the word but opens with an approval, such as yes or go ahead.',
  subagentWrites: 'Remote writes made from a subagent.',
  scratchWrites: 'Writes whose repo sits under a temporary directory, reached through the working directory, cd, git -C, --git-dir, GIT_DIR or a directory mktemp made there, or that git init made under a loop variable or a helper argument. They are left out of every other count.',
  commitsWithoutSkill: 'Commits in a family that had loaded no commit skill by that turn. prWritesWithoutSkill is the same for gh pr create, edit, ready, close or reopen and the pr skill.',
  posts: 'gh pr or issue comment, gh pr review, gh api POST calls to comments, reviews or replies, and MCP comment, reply, post or send tools.',
  anotherPass: 'Typed messages asking for another, one more, final, second, third or fresh pass, review, verification, round or look, for something one more time, for a re-review, or to review, verify or check again.',
  editingFamilies: 'Families with an Edit, MultiEdit, Write or NotebookEdit call.',
  draftRequests: 'Typed messages asking for a draft, or to give, write, prepare or compose a comment, reply, message or response. draftsWithFile counts those whose turn wrote a file.',
  compactions: 'compact_boundary entries. typedCompact counts typed /compact.',
  reviewRuns: 'code-review or review loaded through the Skill tool or typed. ultraReviews counts those with ultra.',
  reviewTokens: 'Input, output and cache-write tokens of replies attributed to code-review or review, each reply counted once. reviewCacheReads holds their cache reads.',
  hookErrors: 'Error lines in the eng hook log. Not counted with --project, because the log names no project.',
  unplacedSubagentWrites: 'Writes in a subagent file that names no turn, which are reported here and counted nowhere else. One number for the whole window, kept in totals and not per week. Zero on a healthy history.',
};

// Raised when the report's shape changes. 2: unplacedSubagentWrites in totals.
// 3: hookErrors is null with --project.
const REPORT_VERSION = 3;

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
  const untilGiven = opts.until !== undefined;
  opts.until ??= new Date().toISOString().slice(0, 10);
  // A date must exist: 2026-02-30 matches the pattern but names no day.
  const real = (date) => {
    const day = new Date(`${date}T00:00:00Z`);
    return /^\d{4}-\d{2}-\d{2}$/.test(date) && !Number.isNaN(day.getTime()) && day.toISOString().startsWith(date);
  };
  for (const key of ['since', 'until']) {
    if (opts[key] !== undefined && !real(opts[key])) fail(`--${key} takes a date as YYYY-MM-DD`);
  }
  if (opts.since && opts.since > opts.until) fail(untilGiven ? '--since comes after --until' : '--since is after today in UTC');
  return opts;
}

// --- Reading what a message says ---------------------------------------

const NOT_TYPED = /^(?:<(?:task-notification|local-command-std(?:out|err)|bash-std(?:out|err)|relay\b|project_claude_message|cross-session-message|coordinator-relay)|\[Request interrupted by user)/;

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
    if (content.some((block) => block?.type === 'tool_result')) return null;
    text = content.filter((block) => block?.type === 'text' && typeof block.text === 'string').map((block) => block.text).join('\n');
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
  ['api', /^gh\s+(?:repo\s+(?:create|edit|delete|rename|archive|unarchive|fork|sync)|workflow\s+(?:run|enable|disable)|run\s+(?:rerun|cancel|delete)|(?:secret|variable)\s+(?:set|delete)|gist\s+(?:create|edit|delete))\b/],
];
const POST_PATH = /comments|reviews|replies/;
const POST_MUTATION = /\b(?:addComment|addPullRequestReview\w*|submitPullRequestReview)\b/;

// One piece of a shell word: a quoted string, $$ (the process id), an
// escaped character, or a plain one. Each piece can match only one way, so a
// pattern built on it never backtracks without end.
const PIECE = String.raw`"(?:[^"\\]|\\[\s\S])*"|\$\$|\$'(?:[^'\\]|\\[\s\S])*'|'[^']*'|\\[\s\S]|(?!\$['$])[^\s"'\\]|\\$`;
// The words of one simple command, each quoted string kept whole.
const WORD_RE = new RegExp(`(?:${PIECE})+`, 'g');

// The text of a $'...' string, with its escapes read as the shell reads
// them. An escape it does not know keeps its backslash.
const ANSI_ESCAPES = { n: '\n', t: '\t', r: '\r', a: '\x07', b: '\b', e: '\x1b', E: '\x1b', f: '\f', v: '\v', '\\': '\\', "'": "'", '"': '"', '?': '?' };
const ansiText = (text) =>
  text.replace(/\\(x[0-9a-fA-F]{1,2}|u[0-9a-fA-F]{1,4}|U[0-9a-fA-F]{1,8}|[0-7]{1,3}|c[\s\S]|[\s\S])/g, (m, e) => {
    if (/^[xuU]./.test(e)) {
      // Past the last code point fromCodePoint would throw, so the escape
      // stays as written.
      const code = parseInt(e.slice(1), 16);
      return code <= 0x10ffff ? String.fromCodePoint(code) : m;
    }
    if (/^[0-7]+$/.test(e)) return String.fromCharCode(parseInt(e, 8));
    if (e[0] === 'c' && e.length === 2) return String.fromCharCode(e.charCodeAt(1) & 31);
    return ANSI_ESCAPES[e] ?? m;
  });
const words = (raw) => raw.match(WORD_RE) || [];
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
  // Only a POST adds a comment or review. DELETE, PATCH and PUT on the same
  // paths remove, edit or dismiss one.
  return verb === 'POST' && POST_PATH.test(target || '') ? 'post' : 'api';
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

// Whether the ' at end opens a $'...' string, in which a backslash escapes
// the next character, a quote included: the $ before it is no part of $$ and
// no backslash escapes it. It reads backwards from end, so a long command
// costs no more per quote.
const ansiQuote = (text, end) => {
  // $$ is the shell's process id, so of the $ no backslash escapes, an odd
  // number must stand before the quote.
  let i = end;
  while (i > 0 && text[i - 1] === '$') i--;
  const dollars = end - i;
  let slashes = 0;
  while (i > 0 && text[i - 1] === '\\') {
    i--;
    slashes++;
  }
  // An odd number of backslashes escapes the first $ of the run.
  const open = dollars - (slashes % 2);
  return open > 0 && open % 2 === 1;
};

// Drops heredoc bodies, which hold scripts, messages and test cases that
// name commands without running them, and joins line continuations. It reads
// the whole command the way the shell does: a << inside quotes, (( )) or a
// comment opens nothing, and neither does a here-string (<<<), but one inside
// a $( ) does, even when the $( ) sits in double quotes, as in
// -m "$(cat <<'EOF' ... )". A backslash before a newline joins the lines
// outside quotes and in double quotes, but not in single quotes or at the end
// of a comment. A # opens a comment only at the start of a word, which an
// escaped space or a joined line does not end. In $'...' a backslash escapes
// the next character, a quote included.
function dropHeredocs(command) {
  let out = '';
  // Where out last took a character a backslash escaped.
  let escaped = -1;
  const pending = [];
  // Each context is a quote, or a command level with its own parenthesis
  // depth and arithmetic depth. The bottom one is the command itself.
  const stack = [{ kind: 'sh', parens: 0, arithmetic: 0 }];
  // Reads the character the backslash at i escapes, the backslash being in
  // out already, and returns where reading goes on. Before a newline the two
  // drop out.
  const escape = (i) => {
    if (command[i + 1] === '\n') out = out.slice(0, -1);
    else {
      out += command[i + 1] ?? '';
      escaped = out.length - 1;
    }
    return i + 1;
  };
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
    } else if (top.kind === "$'") {
      if (c === '\\') out += command[++i] ?? '';
      else if (c === "'") stack.pop();
    } else if (top.kind === '"') {
      if (c === '\\') i = escape(i);
      else if (c === '"') stack.pop();
      else if (command.startsWith('$(', i) && !command.startsWith('$((', i)) {
        out += command[++i];
        stack.push({ kind: 'sh', parens: 0, arithmetic: 0 });
      }
    } else if (c === '\\') i = escape(i);
    else if (c === "'" || c === '"') stack.push({ kind: c === "'" && ansiQuote(command, i) ? "$'" : c });
    else if (c === '#' && (out.length < 2 || (/[\s;&|(]/.test(out.at(-2)) && escaped !== out.length - 2))) {
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
const KEYWORD_WORDS = String.raw`(?:if|then|elif|else|while|until|do|time(?:\s+-p)?|!)`;
const KEYWORDS = String.raw`(?:(?:${KEYWORD_WORDS}|\{)\s+)*`;
const BEFORE_BRACE = new RegExp(String.raw`^(?:${KEYWORD_WORDS}\s+)*`);
const AFTER_KEYWORDS = new RegExp(`^${KEYWORDS}`);

// Splits a command line into simple commands at the operators outside
// quotes, and drops comments. Each comes back raw and bare, the bare one with
// every quoted string emptied, so a grep pattern or a commit message naming a
// write is not one. A subshell's start and end, from ( ), $( ) or backticks,
// come back as markers, so a cd inside one ends with it, and so do a case
// and esac. Arithmetic, $(( )) or (( )), stays inside its command, and a case
// pattern's ) closes nothing.
function splitShell(command) {
  return scanShell(command, 0, false).segments;
}

// The commands of the backtick substitution that opens at i, and the index of
// the backtick that closes it: the next one no backslash escapes. Inside, \`
// is the backtick of a nested substitution.
function backticks(command, i) {
  let stop = i + 1;
  while (stop < command.length && command[stop] !== '`') stop += command[stop] === '\\' ? 2 : 1;
  return [splitShell(command.slice(i + 1, stop).replace(/\\([`\\$])/g, '$1')), Math.min(stop, command.length)];
}

// The splitter itself. From start, it reads to the end of the text, or, when
// nested is set, to the ) that ends a $( ) begun just before start, and
// returns the segments with the index where it stopped.
function scanShell(command, start, nested) {
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
  // case is a scope for the directory, since a cd in one branch may not run;
  // variables set in it carry on.
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
  for (let i = start; i < command.length; i++) {
    const c = command[i];
    if (quote === '"' && (command.startsWith('$(', i) || c === '`') && !command.startsWith('$((', i)) {
      // A command substitution inside double quotes still runs. This same
      // reader reads it, and its commands come back in a subshell's
      // markers, while the quoted text keeps it whole.
      let inner;
      let stop;
      if (c === '`') [inner, stop] = backticks(command, i);
      else {
        const scanned = scanShell(command, i + 2, true);
        [inner, stop] = [scanned.segments, scanned.end];
      }
      segments.push({ marker: 'open' }, ...inner, { marker: 'close' });
      raw += command.slice(i, stop + 1);
      i = stop;
      continue;
    }
    if (quote) {
      raw += c;
      if (c === '\\' && quote !== "'" && i + 1 < command.length) raw += command[++i];
      else if (c === quote.at(-1)) {
        bare += c;
        quote = null;
      }
      continue;
    }
    // A # opens a comment at the start of a word, and an escaped space ends
    // no word.
    if (c === '#' && /(?:^|\s)$/.test(bare) && !/(?<!\\)(?:\\\\)*\\\s$/.test(bare)) {
      while (i + 1 < command.length && command[i + 1] !== '\n') i++;
    } else if (c === '\\' && i + 1 < command.length) {
      add(c + command[++i]);
    } else if (c === "'" || c === '"') {
      quote = c === "'" && ansiQuote(command, i) ? "$'" : c;
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
      else if (nested && !open.includes('(')) {
        // The ) that ends the $( ) this read began in.
        cut();
        return { segments, end: i };
      } else if (open.at(-1) === '(') {
        open.pop();
        cut('close');
      } else cut(); // A ) that closes nothing ends the command and no subshell.
    } else if (c === '`') {
      // A backtick substitution runs in a subshell, read like a $( ).
      const [inner, stop] = backticks(command, i);
      segments.push({ marker: 'open' }, ...inner, { marker: 'close' });
      raw += command.slice(i, stop + 1);
      bare += '``';
      i = stop;
    } else if (c === ';' && open.at(-1) === 'case' && (command[i + 1] === ';' || command[i + 1] === '&')) {
      // ;;, ;& and ;;& end a case branch. Each branch starts in the directory
      // the case started in, even one that ;& falls into: which branch ran
      // is unknown.
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
  return { segments, end: command.length };
}

// An assignment's value: quoted strings, escaped characters, and the rest
// up to a space.
const VALUE = String.raw`(?:${PIECE})*`;
// What may come before the command itself: assignments, keywords, a brace,
// and wrappers that run the command after them.
const WRAPPERS = String.raw`command|exec|env|nohup|sudo(?:\s+-u\s+\S+|\s+-\w+)*|xargs(?:\s+-I\s*\S+|\s+-\w+(?:\s+\d+)?)*|timeout(?:\s+-[sk]\s+\S+|\s+--(?:signal|kill-after)(?:=\S+|\s+\S+)|\s+-\S+)*\s+\S+`;
const LEADING = new RegExp(String.raw`^(?:(?:[A-Za-z_]\w*=${VALUE}|${KEYWORD_WORDS}|for\s+\w+\s+do|\{|${WRAPPERS})\s+)+`);
// "function f {" with no parentheses, after any keyword.
const FUNCTION_KEYWORD = new RegExp(String.raw`^((?:${KEYWORD_WORDS}\s+)*)function\s+[^\s(){}]+\s+(?=\{)`);
const KEYWORD_TOKEN = new RegExp(String.raw`^(?:if|then|elif|else|while|until|do|time|-p|!)$`);
const DECLARE = new RegExp(`^${KEYWORDS}(?:(?:export|local|declare|readonly|typeset)(?:\\s+(?:--|[-+]\\w+))*\\s+)?`);
const TOOL_PATH = /^\S*\/(?=(?:git|gh)\s)/;
const TMP = /^(?:\/private)?\/(?:tmp|var\/folders)(?:\/|$)/;
const ASSIGNMENT = new RegExp(String.raw`([A-Za-z_]\w*)=(${VALUE})`, 'g');
// Whitespace or the end follows each value, so a value cannot also be read as
// the start of the next assignment.
const ASSIGNMENTS = new RegExp(String.raw`^(?:[A-Za-z_]\w*=${VALUE}(?:\s+|$))+$`);
// The -R or --repo flag that gh's pr, issue and other groups take, before or
// after the group. gh api has no such flag, and fails on it.
const GH_REPO = /\s(?:-R|--repo)(?:\s+|=)\S+/g;
const LOOP = new RegExp(String.raw`^${KEYWORDS}(?:for|select)\s+(\w+)(?=\s*$|\s+in\b|\s+do\b)`);
const READ = new RegExp(String.raw`^${KEYWORDS}(?:[A-Za-z_]\w*=\S*\s+)*read\b(.*)$`);
// read's flags whose next word is a value. -a names the array read fills.
const READ_VALUE_LETTERS = 'dinNptu';
// Flags whose next word is a value, so a -h, -n or --dry-run after one is
// that value. The same letter means different things in different commands,
// as -f is --fill in gh pr create and --field in gh api, so the lists are
// kept per command. A command missing here only has gh's -R and git's -C
// and -c.
const flagSet = (text) => new Set(text.split(/\s+/));
const COMMON_VALUE_FLAGS = { git: flagSet('-C -c'), gh: flagSet('-R --repo') };
const VALUE_FLAGS = new Map(Object.entries({
  'git commit': '-m -F -C -c -t --message --file --author --date --template --fixup --squash --cleanup --trailer --reuse-message --reedit-message --pathspec-from-file',
  'git push': '-o --push-option --receive-pack --exec --repo',
  'gh pr create': '-t -b -F -B -H -l -a -r -m -p -T --title --body --body-file --base --head --label --assignee --reviewer --milestone --project --template --recover',
  'gh pr edit': '-t -b -F -B -m --title --body --body-file --base --milestone --add-label --remove-label --add-assignee --remove-assignee --add-reviewer --remove-reviewer --add-project --remove-project',
  'gh pr merge': '-t -b -F -A --subject --body --body-file --author-email --match-head-commit',
  'gh pr comment': '-b -F --body --body-file',
  'gh pr review': '-b -F --body --body-file',
  'gh pr close': '-c --comment',
  'gh pr reopen': '-c --comment',
  'gh issue create': '-t -b -F -l -a -m -p -T --title --body --body-file --label --assignee --milestone --project --template',
  'gh issue edit': '-t -b -F -m --title --body --body-file --milestone --add-label --remove-label --add-assignee --remove-assignee --add-project --remove-project',
  'gh issue comment': '-b -F --body --body-file',
  'gh issue close': '-c -r --comment --reason',
  'gh issue reopen': '-c --comment',
  'gh release create': '-n -F -t --notes --notes-file --title --target --discussion-category --notes-start-tag',
  'gh release edit': '-n -F -t --notes --notes-file --title --target --tag --discussion-category',
  'gh label create': '-c -d --color --description',
  'gh label edit': '-c -d -n --color --description --name',
}).map(([command, flags]) => [command, flagSet(flags)]));
// gh api's come from the lists ghApiWrite reads, with its method flag.
VALUE_FLAGS.set('gh api', new Set([...GH_API_VALUE_FLAGS, ...GH_API_FIELD_FLAGS, '-X', '--method']));

// The command a git or gh call runs, such as "git push" or "gh pr create".
function commandName(raw) {
  const list = words(raw.replace(GH_REPO, ''));
  if (list[0] === 'git') return `git ${gitCommand(raw).sub ?? ''}`.trim();
  if (list[0] !== 'gh') return '';
  const rest = list.slice(1).filter((w) => !w.startsWith('-'));
  return ['gh', ...rest.slice(0, rest[0] === 'api' ? 1 : 2)].join(' ');
}

// The option words of a git or gh command, before any --, leaving out the
// values that option flags take.
function options(raw) {
  const list = words(raw);
  const flags = VALUE_FLAGS.get(commandName(raw));
  const common = COMMON_VALUE_FLAGS[list[0]];
  const out = [];
  for (let i = 1; i < list.length && list[i] !== '--'; i++) {
    if (!list[i].startsWith('-')) continue;
    out.push(list[i]);
    if (flags?.has(list[i]) || common?.has(list[i])) i++;
  }
  return out;
}

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
// It follows cd, cd -, pushd, popd, subshells, git -C, --git-dir and
// GIT_DIR through the call, with the variables it sets, and places what
// mktemp makes. It reads the string bash, sh or zsh -c runs, with the
// variables this call filled in or passed on, and git or gh named by a path.
// A dry run or a help request writes nothing. A repo git init made under a
// loop variable or a helper's argument is a scaffold.
function bashCall(command, cwd, inherited = {}, inner = { seen: new Map(), active: new Map(), calls: 0, top: 0 }) {
  // Set when an inner string went unread: cut for depth, which a copy read
  // with no more room may reuse, or lost to a budget, which no copy may
  // reuse. loop is the shallowest string still being read that this one ran
  // again; its result is whole once that string's own read ends.
  let cut = false;
  let lost = false;
  let loop = Infinity;
  const vars = { ...inherited };
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
  // Fills in the variables the call knows, or those scope names, in one pass,
  // so a value filled in is never read again. A name scope holds as null is
  // known to be unset, and a name nobody knows stays as written; either way a
  // ${ :- } or ${ - } takes its fallback, and a null name otherwise comes out
  // empty. The fallback is a word of its own, read as one. A $ after an odd
  // number of backslashes is escaped and stays.
  const lookup = (scope, name) => (Object.hasOwn(scope, name) ? scope[name] : known(name));
  const fill = (text, scope, held) =>
    text.replace(/(?<=(?:^|[^\\])(?:\\\\)*)\$(?:\{(\w+)(?:(:?)-([^}]*))?\}|(\w+))/g, (m, braced, colon, fallback, plain) => {
      const value = lookup(scope, braced ?? plain);
      if (fallback !== undefined) return value == null || (colon && value === '') ? expand(fallback, scope, held) : value;
      return value === null ? '' : value ?? m;
    });
  // A word read part by part, as the shell does: single quotes keep
  // everything as written, $'...' reads its escapes as the shell does, double
  // quotes fill in variables and let a backslash make $, `, " and \ plain,
  // and outside quotes variables are filled in and a backslash makes any
  // character plain. Line continuations were joined before the call was
  // split. A ${ } is one part, whatever quotes it holds. held says what a
  // $(mktemp) held out of the call becomes: by default the directory it
  // makes.
  const PARTS = /\$'((?:[^'\\]|\\[\s\S])*)'|'([^']*)'|"((?:[^"\\]|\\[\s\S])*)"|((?:\$\{[^}]*\}|\$\$|(?!\$['$])[^'"\\]|\\[\s\S])+)|([\s\S])/g;
  const expand = (word, scope = vars, held = (n) => mktempDir(temps[n])) => {
    let out = '';
    for (const [, ansi, single, double, bare, lone] of word.replace(/__mktemp(\d+)__/g, (m, n) => held(n)).matchAll(PARTS)) {
      if (ansi !== undefined) out += ansiText(ansi);
      else if (single !== undefined) out += single;
      else if (double !== undefined) out += fill(double, scope, held).replace(/\\([$`"\\])/g, '$1');
      else if (bare !== undefined) out += fill(bare, scope, held).replace(/\\([\s\S])/g, '$1');
      else out += lone;
    }
    return out;
  };
  let dir = cwd || '';
  let last = dir;
  const dirs = [];
  const pushed = [];
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
    const loop = LOOP.exec(bare);
    const read = READ.exec(bare);
    if (loop) loops.push(loop[1]);
    if (read) {
      const list = words(read[1]);
      for (let i = 0; i < list.length; i++) {
        // A redirect may sit anywhere; its target is no name read fills.
        if (/^\d*[<>]+$/.test(list[i])) {
          i++;
          continue;
        }
        if (/^\d*[<>]/.test(list[i])) continue;
        if (/^-[a-zA-Z]+$/.test(list[i])) {
          // The first letter that takes a value takes the rest of the group,
          // or the next word when it ends the group.
          const at = [...list[i].slice(1)].findIndex((letter) => READ_VALUE_LETTERS.includes(letter));
          if (at !== -1 && at === list[i].length - 2) i++;
        } else if (/^[A-Za-z_]\w*$/.test(list[i])) loops.push(list[i]);
      }
    }
  }
  const unnamed = new RegExp(`\\$\\{?(?:[\\d@*]${loops.map((name) => `|${name}\\b`).join('')})`);
  // Exported names reach git; a plain assignment does not, unless set -a is
  // on. A subshell keeps its own copy of both; a case branch does not.
  let exported = new Set(Object.keys(inherited));
  let exportAll = false;
  // A function's body is read where it is written, as if it ran there. Each
  // { pushes a brace, a function's carrying the locals to undo at its }. A
  // function whose body is a subshell drops its locals with the subshell.
  // Outside a function, bash rejects local, so it changes nothing.
  const braces = [];
  const subshells = []; // for each open subshell, whether it is a function's body
  // Whether the body at k follows "name()", as in f() { or f() (, after any
  // keyword such as then or do.
  const definesFunction = (k) =>
    segments[k - 1]?.marker === 'close' &&
    segments[k - 2]?.marker === 'open' &&
    /^(?:function\s+)?[^\s()<>;&|$`"'{}]+$/.test((segments[k - 3]?.bare ?? '').replace(BEFORE_BRACE, ''));
  for (let k = 0; k < segments.length; k++) {
    let segment = segments[k];
    if (segment.marker === 'open' && segment.scope !== 'case') {
      // f() ( ... ) is a function whose body is a subshell, where a local
      // applies.
      subshells.push(definesFunction(k));
    }
    if (segment.marker === 'close' && segment.scope !== 'case') subshells.pop();
    if (!segment.marker) {
      // "function f {" with no parentheses: the rest reads like f() {.
      const declared = FUNCTION_KEYWORD.test(segment.bare);
      if (declared) segment = { raw: segment.raw.replace(FUNCTION_KEYWORD, '$1'), bare: segment.bare.replace(FUNCTION_KEYWORD, '$1') };
      // Each { a command starts with, past keywords, as in "{ if { true".
      let count = 0;
      for (const token of segment.bare.split(/\s+/)) {
        if (token === '{') count++;
        else if (!KEYWORD_TOKEN.test(token)) break;
      }
      const named = segment.bare.replace(BEFORE_BRACE, '').startsWith('{') && (declared || definesFunction(k));
      for (let n = 0; n < count; n++) braces.push(named && n === 0 ? new Map() : null);
      if (/^\}/.test(segment.bare) && braces.length) {
        const locals = braces.pop();
        for (const [name, [value, wasExported]] of locals ?? []) {
          if (value === undefined) delete vars[name];
          else vars[name] = value;
          if (wasExported) exported.add(name);
          else exported.delete(name);
        }
      }
    }
    if (segment.marker === 'open') {
      dirs.push([dir, last, { ...vars }, new Set(exported), exportAll, [...pushed]]);
      continue;
    }
    if (segment.marker === 'close') {
      if (dirs.length) {
        const [d, l, savedVars, savedExported, savedAll, savedPushed] = dirs.pop();
        [dir, last] = [d, l];
        if (segment.scope !== 'case') {
          pushed.splice(0, pushed.length, ...savedPushed);
          for (const name of Object.keys(vars)) delete vars[name];
          Object.assign(vars, savedVars);
          [exported, exportAll] = [savedExported, savedAll];
        }
      }
      continue;
    }
    const bareCommand = segment.bare.replace(AFTER_KEYWORDS, '');
    if (/^set\s/.test(bareCommand)) {
      // set -a, or -o allexport, exports every later assignment; + undoes it.
      // Options end at --, or at the first word that is no option.
      const list = words(bareCommand).slice(1);
      for (let i = 0; i < list.length && /^[-+]./.test(list[i]) && list[i] !== '--'; i++) {
        // Each o in a group names an option in a word of its own.
        const w = list[i];
        const named = list.slice(i + 1, i + 1 + (w.match(/o/g) || []).length);
        if (/^-[a-zA-Z]*a/.test(w) || (w.startsWith('-') && named.includes('allexport'))) exportAll = true;
        if (/^\+[a-zA-Z]*a/.test(w) || (w.startsWith('+') && named.includes('allexport'))) exportAll = false;
        i += named.length;
      }
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
    // Inside a function, declare and typeset make a local too, unless -g.
    const local = declaration && (declaration[1] === 'local' || (/^(?:declare|typeset)$/.test(declaration[1]) && !/\s-\w*g/.test(flags) && braces.some(Boolean)));
    if (local) {
      const frame = braces.findLast((brace) => brace);
      if (!frame && !subshells.includes(true)) continue;
      // Keep what each name held before, for the function's closing brace.
      for (const item of words(raw)) {
        const name = /^([A-Za-z_]\w*)(?:=|$)/.exec(item)?.[1];
        if (frame && name && !frame.has(name)) frame.set(name, [vars[name], exported.has(name)]);
      }
    }
    if (declaration) {
      for (const item of words(raw)) {
        const assignment = /^([A-Za-z_]\w*)=(.*)$/s.exec(item);
        const name = assignment ? assignment[1] : /^[A-Za-z_]\w*$/.test(item) ? item : null;
        if (!name) continue;
        if (assignment) vars[name] = expand(assignment[2]);
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
    // git or gh named by a path, such as /usr/bin/git, is git or gh.
    const body = raw.replace(LEADING, '').replace(TOOL_PATH, '');
    const bare = segment.bare.replace(DECLARE, '').replace(LEADING, '').replace(TOOL_PATH, '');
    const plain = stripArithmetic(bare).replace(/\[\[[\s\S]*?\]\]/g, '');
    if (/(?<![=>])>{1,2}\s*(?!&|\/dev\/null\b)[^\s|&>]/.test(plain) || /^tee\s/.test(bare)) wroteFile = true;
    // cd with no directory goes home, and pushd and popd move like cd.
    // pushd +N and -N turn the stack, counting from its left or right end.
    const cd = /^(cd|pushd)(?=\s|$)/.exec(body);
    if (cd) {
      const list = words(body).slice(1);
      // Options may come before or after the directory; -n keeps pushd
      // from moving, wherever it sits.
      const keep = cd[1] === 'pushd' && list.includes('-n');
      const rest = list.filter((w) => !/^-[LPe@n]+$/.test(w));
      const argument = rest[0] === '--' ? rest[1] : rest[0];
      const turn = cd[1] === 'pushd' && /^([+-])(\d+)$/.exec(argument ?? '');
      // With -n and no directory, pushd does nothing.
      if (keep && argument === undefined) continue;
      if (turn) {
        const stack = [dir, ...[...pushed].reverse()];
        const n = Number(turn[2]);
        const at = turn[1] === '+' ? n : stack.length - 1 - n;
        if (at >= 0 && at < stack.length) {
          const turned = [...stack.slice(at), ...stack.slice(0, at)];
          // With -n the stack turns and the directory stays.
          if (!keep) [dir, last] = [turned[0], dir];
          pushed.splice(0, pushed.length, ...turned.slice(1).reverse());
        }
        continue;
      }
      if (cd[1] === 'pushd' && argument === undefined) {
        // A bare pushd swaps the top two directories, and fails with one.
        if (pushed.length) [dir, last, pushed[pushed.length - 1]] = [pushed.at(-1), dir, dir];
        continue;
      }
      const to = argument === undefined ? '~' : expand(argument);
      if (keep) {
        // pushd -n adds the directory beneath the current one and stays put.
        pushed.push(resolveFrom(dir, to));
        continue;
      }
      if (cd[1] === 'pushd') pushed.push(dir);
      [dir, last] = [to === '-' ? last : resolveFrom(dir, to), dir];
      continue;
    }
    if (/^popd\b/.test(body)) {
      // popd +N or -N removes that entry and stays put unless it is the
      // top one; popd -n removes the entry beneath the top, and with -n popd
      // never moves.
      const list = words(body).slice(1);
      const at = list.map((w) => /^([+-])(\d+)$/.exec(w)).find(Boolean);
      const stack = [dir, ...[...pushed].reverse()];
      const keep = list.includes('-n');
      // With -n, the top entry is the directory, which stays, so the one
      // beneath it goes in its place.
      let index = at ? (at[1] === '+' ? Number(at[2]) : stack.length - 1 - Number(at[2])) : 0;
      if (keep && index === 0) index = 1;
      if (stack.length > 1 && index >= 0 && index < stack.length) {
        stack.splice(index, 1);
        // Removing the top entry moves to the next one.
        if (index === 0) [dir, last] = [stack[0], dir];
        pushed.splice(0, pushed.length, ...stack.slice(1).reverse());
      }
      continue;
    }
    // The assignments written before the command on its line, word by word,
    // so a wrapper's --flag=value is none.
    const prefix = {};
    for (const w of words(raw.slice(0, raw.length - body.length))) {
      const assignment = /^([A-Za-z_]\w*)=(.*)$/s.exec(w);
      if (assignment) prefix[assignment[1]] = assignment[2];
    }
    // bash, sh or zsh -c runs its string as a command of its own, from here.
    if (/^(?:\S*\/)?(?:ba|z)?sh\s/.test(bare)) {
      // The shell reads options up to its first other word, or up to --, and
      // with -c among them that word is the command: in bash -c -e "cmd" it
      // is "cmd", and in bash script.sh -c, the -c belongs to the script.
      // --rcfile, --init-file and each o or O in an option group take the
      // next word.
      const list = words(body).slice(1);
      let command = false;
      let i = 0;
      for (; i < list.length && /^[-+]/.test(list[i]) && list[i] !== '--'; i++) {
        if (/^-[a-zA-Z]*c/.test(list[i])) command = true;
        // Each o or O in a group takes a word of its own.
        if (/^(?:--rcfile|--init-file)$/.test(list[i])) i++;
        else if (/^[-+][a-zA-Z]+$/.test(list[i])) i += (list[i].match(/[oO]/g) || []).length;
      }
      if (list[i] === '--') i++;
      const word = command ? list[i] : undefined;
      if (word) {
        // The string is read as this shell reads any word: it fills in its
        // own variables outside single quotes, before the assignments on its
        // line exist, and removes quotes and escapes. A $(mktemp) held out of
        // it above goes back in for the inner call to run. The inner shell
        // inherits what this one exported, and those assignments. A name this
        // call cannot place is unset, except PWD, which any shell has even
        // when the call names no directory.
        const unset = Object.fromEntries(Object.keys(prefix).filter((name) => name !== 'PWD' && lookup(vars, name) === undefined).map((name) => [name, null]));
        const string = expand(word, { ...unset, ...vars }, (n) => `$(mktemp${temps[n]})`);
        const inherited = {};
        for (const name of exported) if (Object.hasOwn(vars, name)) inherited[name] = vars[name];
        for (const [name, value] of Object.entries(prefix)) inherited[name] = expand(value);
        // Each string is read once per directory and variables, eight levels
        // deep at most. A string that runs itself adds nothing the copy
        // already being read will not, so it is read as empty. One that grows
        // at each level never repeats, so below each string the command runs
        // directly at most 1024 strings are read, and below all of them 4096.
        // A command built to use that up, such as a string that loops back and
        // branches three or more ways, can hide a write past it; none in the
        // transcripts comes close.
        const key = JSON.stringify([string, dir, inherited]);
        const depth = inner.active.size;
        const room = 8 - depth;
        if (!depth) inner.top = 0;
        const known = inner.seen.get(key);
        let result = null;
        if (inner.active.has(key)) result = { writes: [], wroteFile: false, loop: inner.active.get(key) };
        else if (known && (!known.result.cut || room <= known.room)) result = known.result;
        else if (room <= 0) result = { writes: [], wroteFile: false, cut: true, loop: Infinity };
        else if (depth && (inner.calls >= 4096 || inner.top >= 1024)) result = { writes: [], wroteFile: false, cut: true, lost: true, loop: Infinity };
        else {
          // Only reads below the strings the command runs directly count
          // toward the budgets, so many plain ones never use them up.
          if (depth) {
            inner.calls++;
            inner.top++;
          }
          inner.active.set(key, depth);
          result = bashCall(string, dir, inherited, inner);
          inner.active.delete(key);
          // A loop back to this string, or deeper, is whole now.
          if (result.loop >= depth) result = { ...result, loop: Infinity };
          if (!result.lost && result.loop === Infinity) inner.seen.set(key, { result, room });
        }
        if (result.cut) cut = true;
        if (result.lost) lost = true;
        if (result.loop < loop) loop = result.loop;
        if (result.wroteFile) wroteFile = true;
        for (const write of result.writes) if (!writes.some((w) => w.kind === write.kind && w.scratch === write.scratch)) writes.push(write);
      }
      continue;
    }
    // The option words, read once: help requests and dry runs write nothing.
    const optionWords = /^(?:git|gh)\s/.test(bare) ? options(body) : [];
    if (optionWords.some((w) => w === '--help' || w === '-h')) continue;
    let kind = null;
    let where = dir;
    if (/^git\s/.test(bare)) {
      const { sub, targets, gitDir: named } = gitCommand(body);
      // GIT_DIR set before git on its line, or exported earlier in the call.
      const gitDir = named ?? prefix.GIT_DIR ?? (exported.has('GIT_DIR') ? vars.GIT_DIR : undefined);
      // A dry run sends nothing: --dry-run on both, and -n on a push, alone
      // or in a group such as -fn.
      const dry = optionWords.some((w) => w === '--dry-run' || (sub === 'push' && /^-[a-zA-Z]*n[a-zA-Z]*$/.test(w)));
      if ((sub === 'commit' || sub === 'push') && !dry) kind = sub;
      for (const target of targets) where = resolveFrom(where, expand(target));
      if (gitDir) where = resolveFrom(where, expand(gitDir));
      if (sub === 'init') {
        const arg = initDirectory(body);
        made.add(arg ? resolveFrom(where, expand(arg)) : where);
      }
    } else if (/^gh\s/.test(bare) && !optionWords.includes('--dry-run')) {
      const ghBare = bare.replace(GH_REPO, '');
      const ghBody = body.replace(GH_REPO, '');
      if (/^gh\s+api\b/.test(ghBare)) kind = ghBare === bare ? ghApiWrite(ghBody) : null;
      else kind = GH_WRITES.find(([, pattern]) => pattern.test(ghBare))?.[0] ?? null;
    }
    if (!kind) continue;
    // A repo git init made in a directory a helper's argument or a loop
    // variable names, such as $1, is a scaffold.
    const scratch = TMP.test(where) || (unnamed.test(where) && made.has(where));
    // One call that commits twice, or defines a helper that does, is one write.
    if (!writes.some((w) => w.kind === kind && w.scratch === scratch)) writes.push({ kind, scratch });
  }
  return { writes, wroteFile, cut, lost, loop };
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

// The words in your message that ask for each kind of write, with their
// inflections and nothing longer, so pushed asks and pushback does not.
// Asking to push asks for the commit it needs. An approval such as "yes" or "go
// ahead" names no write and is counted apart, because an approval is not a
// request: the workflow wants those confirmed.
// Check in asks for a commit only in its commit sense: before what gets
// committed, as in check in the changes, check in all the test files or check
// in everything; as check it in, unless a place to look or a time follows, as
// in check it in the browser or check it in a minute; or alone at the end of
// the message, as in check in please. A greeting, a plan, a question, and
// check in with or on someone ask for nothing: just checking in, let me check
// in, let's check in tomorrow, can we check in?
const CHECK_IN = [
  String.raw`check(?:s|ed|ing)?\s+in\s+(?:everything|all\s+of\s+it|(?:(?:the|my|your|our|these|those|this|that|all)\s+){0,2}(?:(?!on\b|with\b)[\w-]+\s+)?(?:changes?|fix(?:es)?|work|files?|commits?|diff|code|patch(?:es)?|tests?|updates?|edits?|readme|scripts?))`,
  String.raw`check(?:s|ed|ing)?\s+(?:it|this|that|them|these|those)\s+in(?!\s+(?:(?:the|a|an|my|your|our)\s+)?(?:browser|logs?|console|terminal|ui|app|readme|docs?|ci|devtools|chrome|safari|firefox|prod\w*|staging|minute|bit|while|second)\b)`,
  String.raw`(?<!\b(?:just|wanted\s+to|let['’]?s|let\s+me|we|i['’]ll|i\s+will|i['’]d|quick)\s+)check\s+in(?=(?:\s+(?:please|now))?[\s.!,]*$)`,
].join('|');
// The words that ask for a write through an MCP tool, such as one to Google
// Drive or Notion, besides any write's own word.
// A place one writes to through an MCP tool. Docs alone is left out, since in
// a repo it means the documentation, and Google alone, since Google Analytics
// or Google Fonts are code; Google Docs, Slides and Forms count.
// Words that start a new clause, past which a verb takes no place.
const CLAUSE_BREAK = String.raw`(?:and|then|but)`;
const MCP_PLACE = String.raw`(?:drive|notion|sheets?|spreadsheets?|google\s+(?:docs?|slides|forms?)|slack|calendar|linear|jira|confluence|canva|figma|gmail|emails?|database|folders?)`;
const MCP_VERB_SOURCE = String.raw`\b(?:creat(?:e|es|ed|ing)|sav(?:e|es|ed|ing)|cop(?:y|ies|ied|ying)|delet(?:e|es|ed|ing)|trash(?:es|ed|ing)?|shar(?:e|es|ed|ing)|updat(?:e|es|ed|ing)|add(?:s|ed|ing)?|mov(?:e|es|ed|ing)|writ(?:e|es|ing)|wrote|edit(?:s|ed|ing)?|remov(?:e|es|ed|ing))\b`;
const MCP_ASK = new RegExp(String.raw`\b(?:upload(?:s|ed|ing)?|publish(?:es|ed|ing)?)\b|${MCP_VERB_SOURCE}(?:\s+(?!${CLAUSE_BREAK}(?![\w'\u2019-]))(?=[\w'\u2019-]*\w)[\w'\u2019-]+){0,4}?\s+${MCP_PLACE}\b`, 'i');
const APPROVAL = /^\W*(?:yes|yep|yeah|ok(?:ay)?|sure|go ahead|proceed|approved?|do it|sounds good|lgtm|looks good)\b/i;
const WORDS = {
  commit: String.raw`commit(?:s|ted|ting)?|${CHECK_IN}`,
  push: String.raw`push(?:es|ed|ing)?|ship(?:s|ped|ping)?`,
  pr: String.raw`prs?|pull requests?|title|description`,
  merge: String.raw`merg(?:e|es|ed|ing)`,
  issue: String.raw`issues?|tickets?`,
  label: String.raw`label(?:s|ed|led|ing|ling)?`,
  release: String.raw`releas(?:e|es|ed|ing)|tag(?:s|ged|ging)?`,
  post: String.raw`post(?:s|ed|ing)?|comment(?:s|ed|ing)?|repl(?:y|ies|ied|ying)|send(?:s|ing)?|sent|submit(?:s|ted|ting)?`,
};
const asks = (...kinds) => new RegExp(String.raw`\b(?:${kinds.map((k) => WORDS[k]).join('|')})\b`, 'i');
// Any write's word, but a PR's only by name: a title or a description asks
// for no repo, workflow or secret.
const ANY_REQUEST = new RegExp(String.raw`\b(?:${Object.entries(WORDS).map(([k, w]) => (k === 'pr' ? 'prs?|pull requests?' : w)).join('|')})\b`, 'i');
const REQUEST = {
  commit: asks('commit', 'push'),
  push: asks('push'),
  pr: asks('pr'),
  merge: asks('merge'),
  issue: asks('issue'),
  label: asks('label'),
  release: asks('release'),
  post: asks('post'),
  api: ANY_REQUEST,
  // Upload or publish asks for an MCP write alone. Another verb, such as
  // create or save, asks only with a place one goes, such as Drive or Notion,
  // as one of the five words after it, with no punctuation or and, then or
  // but between them: "add a test" asks for none.
  mcp: { test: (text) => ANY_REQUEST.test(text) || MCP_ASK.test(text) },
};
// What follows one of these asks for nothing, up to punctuation, an em dash,
// an en dash not after a digit, a spaced hyphen or double hyphen, or a word
// that starts a new clause. A flag such as --force has no space after its
// hyphens and ends nothing: "don't push or commit yet, just tidy it" asks for
// neither, "commit it without pushing" asks for no push, and "don't wait for
// CI before you push" asks for one. A stretch that opens with forget or
// hesitate, as in "don't you forget to push", "don't ever forget to push" or
// "without forgetting to push", is a reminder and asks for what it names, and
// so is wait to after any of these words but without, as in "don't wait to
// push", "no need to wait to push" or "no need to keep waiting to push".
// "Don't wait for CI to push", "don't bother waiting to push" and "don't
// waste time waiting to push" ask too; bother and waste time alone do not.
// The for names a check, such as CI, tests, checks, the build, the pipeline,
// a workflow, GitHub Actions, review, approval, green or the linter, with up
// to two words before it, not a person: in "don't wait for me
// to push" someone else pushes. "Without waiting to push" is left negated,
// since it reads as leaving the push for later, and so are "never waited to
// push" and "never waits to push", which report rather than ask.
const NEGATED = /\b(?:don['’]?t|do not|never|no need to|without)\b[^.,;:!?\n]*?(?=\b(?:and|but|then|just|so|before|until|unless|after|when|once|if)\b|\u2014|(?<!\d)\u2013|\s--?\s|[.,;:!?\n]|$)/gi;
const REMINDER = /^\S+(?:\s+not|\s+need\s+to)?(?:\s+you)?\s+(?:ever\s+)?(?:forget\w*|hesitat\w*)\b|^(?!without\b)\S+(?:\s+not|\s+need\s+to)?(?:\s+you)?\s+(?:ever\s+)?(?:wait|keep\s+waiting|bother\s+waiting|waste\s+time\s+waiting)(?:\s+for\s+(?:\w+\s+){0,2}?(?:ci|checks?|tests?|builds?|pipeline|reviews?|approval|green|lint\w*|actions|workflows?)\b(?:\s+(?:run|job|pass|to\s+pass|to\s+finish))?)?\s+to\b/i;
const unasked = (text) => text.replace(NEGATED, (span) => (REMINDER.test(span) ? span : ' '));
// Whether text asks for a write of this kind, and the same for text unasked
// has already read.
const asksIn = (kind, asked) => REQUEST[kind].test(asked);
const asksFor = (kind, text) => asksIn(kind, unasked(text));

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

// The tool a content block calls and its input, or null when the block is no
// tool call. A malformed block calls nothing.
function toolCall(block) {
  if (!block || block.type !== 'tool_use' || typeof block.name !== 'string') return null;
  return { name: block.name, input: block.input && typeof block.input === 'object' ? block.input : {} };
}

// The writes one tool call makes, each with whether it lands in a scratch
// repo, and whether it writes a file. Edits are counted apart.
function callWrites(name, input, cwd) {
  if (name === 'Bash' && typeof input.command === 'string') return bashCall(input.command, cwd);
  const kind = name.startsWith('mcp__') ? mcpWrite(name) : null;
  return { writes: kind ? [{ kind, scratch: false }] : [], wroteFile: false };
}

// The turn a subagent file names on its first line that names one.
function firstPrompt(file) {
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    if (!line.includes('"promptId"')) continue;
    try {
      const promptId = JSON.parse(line).promptId;
      if (promptId) return promptId;
    } catch {
      // A line cut short names nothing.
    }
  }
  return null;
}

async function collect(files) {
  const seen = new Map(); // uuid to the file session it was first read in
  const families = new Families();
  const typed = []; // { ts, session, prompt, text, command }
  const turns = new Map(); // promptId to the turn
  const compactions = []; // { ts, session }
  const review = new Map(); // requestId to { ts, session, tokens }
  const reviewRuns = []; // { ts, session, args }
  const unplaced = []; // times of subagent writes with no turn to count them in

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
    // A subagent file's calls belong to the turn its file names, even those
    // read before the line that names it.
    let prompt = sub ? firstPrompt(file) : null;
    const lines = readline.createInterface({ input: fs.createReadStream(file), crlfDelay: Infinity });
    for await (const line of lines) {
      if (!line) continue;
      let entry;
      try {
        entry = JSON.parse(line);
      } catch {
        continue;
      }
      if (!entry || typeof entry !== 'object') continue;
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
      // A subagent's tool calls count only through the turn its file names.
      if (sub && !turn && entry.type === 'assistant') {
        // Each write that would count if its turn were known.
        const content = entry.message?.content;
        for (const block of Array.isArray(content) ? content : []) {
          const call = toolCall(block);
          if (call) for (const write of callWrites(call.name, call.input, entry.cwd).writes) if (!write.scratch) unplaced.push(ts);
        }
      }
      if (entry.attributionSkill && turn) turn.skills.add(skillName(entry.attributionSkill));

      if (entry.type === 'system' && entry.subtype === 'compact_boundary') {
        compactions.push({ ts, session });
        continue;
      }

      // A message typed while a turn runs is kept as a queued_command
      // attachment inside that turn, and never as a user entry of its own.
      const queued = entry.type === 'attachment' && entry.attachment?.type === 'queued_command' ? entry.attachment : null;
      if ((entry.type === 'user' || queued) && !sub) {
        const message = queued
          ? typedMessage({ type: 'user', isMeta: entry.isMeta || queued.isMeta, isSidechain: entry.isSidechain, origin: queued.origin, message: { content: queued.prompt } })
          : typedMessage(entry);
        if (message) {
          typed.push({ ts, session, prompt, ...message });
          // Every message typed in a turn is part of what it asks for.
          if (turn) turn.typed = turn.typed ? `${turn.typed}\n${message.text}` : message.text;
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
        const call = toolCall(block);
        if (!call) continue;
        const { name, input } = call;
        if (name === 'Skill') {
          const skill = skillName(input.skill);
          turn.skills.add(skill);
          if (REVIEW_SKILLS.has(skill)) reviewRuns.push({ ts, session, args: String(input.args || '') });
        } else {
          const effect = callWrites(name, input, entry.cwd);
          for (const { kind, scratch } of effect.writes) {
            if (scratch) turn.scratchWrites++;
            else turn.writes.push({ kind, sub, ts });
          }
          if (effect.wroteFile) turn.wroteFile = true;
        }
        if (EDIT_TOOLS.has(name)) {
          turn.edits = true;
          if (name === 'Write') turn.wroteFile = true;
        }
      }
    }
  }
  return { families, typed, turns, compactions, review, reviewRuns, unplaced };
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
  // The list is sorted by time, so a binary search finds the last one at or
  // before ts.
  let low = 0;
  let high = list.length;
  while (low < high) {
    const mid = (low + high) >> 1;
    if (list[mid].ts <= ts) low = mid + 1;
    else high = mid;
  }
  return low ? list[low - 1].text : '';
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

  // When each family first loaded each skill. A skill loaded in an earlier
  // turn is still in context for the turns after it.
  const loaded = new Map();
  for (const turn of data.turns.values()) {
    const key = family(turn.session);
    if (!loaded.has(key)) loaded.set(key, new Map());
    const first = loaded.get(key);
    for (const skill of turn.skills) if (!first.has(skill) || turn.ts < first.get(skill)) first.set(skill, turn.ts);
  }
  const hasSkill = (turn, skill) => loaded.get(family(turn.session))?.get(skill) <= turn.ts;

  for (const turn of data.turns.values()) {
    if (turn.edits) add(turn.ts, (b) => b.editingFamilies.add(family(turn.session)));
    if (turn.scratchWrites) add(turn.ts, (b) => (b.scratchWrites += turn.scratchWrites));
    if (!turn.writes.length) continue;
    const request = turn.typed ?? latestTyped(byFamily, family(turn.session), turn.ts);
    // Read once per turn, however many writes it made.
    const asked = unasked(request);
    const missing = turn.writes.some((write) => !asksIn(write.kind, asked));
    const approved = missing && APPROVAL.test(request);
    add(turn.ts, (b) => {
      b.writeTurns++;
      if (approved) b.approvedWriteTurns++;
      else if (missing) b.unaskedWriteTurns++;
      for (const write of turn.writes) {
        b.writes[write.kind] = (b.writes[write.kind] || 0) + 1;
        if (write.sub) b.subagentWrites++;
        if (write.kind === 'post') b.posts++;
        if (write.kind === 'commit' && !hasSkill(turn, 'commit')) b.commitsWithoutSkill++;
        if (write.kind === 'pr' && !hasSkill(turn, 'pr')) b.prWritesWithoutSkill++;
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
  // null when the run keeps to one project: the log names none, so its errors
  // cannot be kept to it.
  for (const e of hookErrors ?? []) add(e.ts, (b) => b.hookErrors++);

  const rows = [...weeks.keys()].sort().map((week) => ({ week, ...finish(weeks.get(week)) }));
  const total = finish(totals);
  if (hookErrors === null) for (const bucket of [...rows, total]) bucket.hookErrors = null;
  total.weeks = spanWeeks(opts, rows);
  // A count for the whole window only: a week row for it would stretch the
  // span, and every rate with it.
  total.unplacedSubagentWrites = data.unplaced.filter(inWindow).length;
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

// A count an older baseline lacks shows as n/a.
const pct = (part, whole) => (whole && part != null ? `${Math.round((100 * part) / whole)}%` : 'n/a');
const perWeek = (value, weeks) => (weeks && value != null ? (value / weeks).toFixed(1) : 'n/a');
const thousands = (value) => (value && value < 10000 ? `${(value / 1000).toFixed(1)}k` : `${Math.round(value / 1000)}k`);
// null when a kind holds no number, so the row reads n/a. A kind an older
// baseline lacks counts as none, since it was not counted then.
const sum = (writes) => (Object.values(writes).some((v) => !Number.isFinite(v)) ? null : Object.values(writes).reduce((a, b) => a + b, 0));

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

// The numbers --compare sets beside a baseline: rates per week, or shares
// where a count only means something against its whole. A count that is not a
// number, as in an older or edited baseline, reads n/a.
function headline(totals) {
  const num = (v) => (Number.isFinite(v) ? v : null);
  const t = Object.fromEntries(Object.entries(totals).map(([k, v]) => [k, k === 'writes' ? Object.fromEntries(Object.entries(v).map(([kind, n]) => [kind, num(n)])) : num(v)]));
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
    ['Another-pass per editing family', t.editingFamilies && t.anotherPass != null ? (t.anotherPass / t.editingFamilies).toFixed(1) : 'n/a'],
    ['Drafts with a file', pct(t.draftsWithFile, t.draftRequests)],
    ['Families compacted', pct(t.familiesCompacted, t.families)],
    ['Review tokens per reviewed session', t.reviewedSessions && t.reviewTokens != null ? thousands(t.reviewTokens / t.reviewedSessions) : 'n/a'],
    ['Ultra reviews', String(t.ultraReviews ?? 'n/a')],
    ['Hook errors', String(t.hookErrors ?? 'n/a')],
  ];
}

function compare(total, baseline) {
  const before = new Map(headline(baseline.totals));
  const rows = headline(total).map(([label, now]) => [label, before.get(label) ?? 'n/a', now]);
  const span = (t, o) => `${o.since || 'start'} to ${o.until || 'end'}, ${Number.isFinite(t.weeks) ? t.weeks : 'n/a'} wk`;
  const out = [table(['', `Baseline (${span(baseline.totals, baseline.window)})`, 'Now'], rows)];
  const drift = definitionDrift(baseline);
  if (drift) out.push('', drift);
  return out.join('\n');
}

// What differs between how the baseline counted and how this run counts, or
// '' when nothing does. The keys are DEFINITIONS' own, which the JSON uses.
function definitionDrift(baseline) {
  const before = baseline.definitions && typeof baseline.definitions === 'object' && !Array.isArray(baseline.definitions) ? baseline.definitions : {};
  const changed = Object.keys(DEFINITIONS).filter((key) => key in before && before[key] !== DEFINITIONS[key]);
  const added = Object.keys(DEFINITIONS).filter((key) => !(key in before));
  const removed = Object.keys(before).filter((key) => !(key in DEFINITIONS));
  const parts = [];
  if (baseline.version !== REPORT_VERSION) parts.push(`the report's shape is version ${baseline.version ?? 'unknown'} there and ${REPORT_VERSION} here`);
  if (changed.length) parts.push(`these definitions changed: ${changed.join(', ')}`);
  if (added.length) parts.push(`these counts are new: ${added.join(', ')}`);
  if (removed.length) parts.push(`these counts are gone: ${removed.join(', ')}`);
  return parts.length ? `Against the baseline, ${parts.join('; ')}. Read the matching rows with care.` : '';
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
    // Every headline row reads totals, and the remote writes row adds up
    // totals.writes.
    const totals = baseline?.totals;
    // A count that is not a number reads n/a, so only the shape is checked.
    if (!totals || typeof totals !== 'object' || !totals.writes || typeof totals.writes !== 'object') fail(`${opts.compare} holds no saved totals`);
    baseline.window ??= {};
  }

  const files = transcriptFiles(projects, opts.project);
  const data = await collect(files);
  const hookErrors = opts.project ? null : readHookErrors(path.join(config, 'plugins', 'data', 'eng-mewanakoon', 'eng-hook.log'));
  const { rows, total } = count(data, hookErrors, opts);

  const report = {
    version: REPORT_VERSION,
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
    // With --compare, the JSON carries the baseline's numbers and any drift.
    const output = baseline ? { ...report, baseline: { window: baseline.window, totals: baseline.totals, drift: definitionDrift(baseline) } } : report;
    process.stdout.write(`${JSON.stringify(output, null, 2)}\n`);
    return;
  }
  const out = [`${files.length} transcript files under ${projects}`, '', weekly(rows, total), '', table(['', 'All weeks'], headline(total))];
  if (total.unplacedSubagentWrites) {
    const writes = total.unplacedSubagentWrites === 1 ? 'write sits' : 'writes sit';
    out.push('', `${total.unplacedSubagentWrites} subagent ${writes} in files with no turn id, so they are not counted above.`);
  }
  if (baseline) out.push('', compare(total, baseline));
  if (opts.save) out.push('', `Saved to ${opts.save}`);
  process.stdout.write(`${out.join('\n')}\n`);
}

// Run as a script, it reports. Imported, as the tests do, it only lends
// bashCall and asksFor.
export { asksFor, bashCall };
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
