# Security review

Read this at `review.md` section 2, and at `deliver.md` step 5. When the diff
touches a trust boundary, the intent check reads it against the checklist
below, and once the work is committed, the built-in `security-review` reads
it again. Each covers what the other leaves out: the built-in's own prompt
skips most shell injection, CI and dependency issues.

## Does the diff touch a trust boundary

Decide on `<parent>..<snapshot>`, with step 1's commit as `<parent>`. It does
when an added or changed line, outside tests and docs, does one of these:

- **Auth, sessions or permissions:** decides who someone is or what they may
  do, or issues, checks or ends a session.
- **Untrusted input:** reads a request, message, upload, argument, variable
  or file that someone other than the code's owner can set.
- **Shell, exec, eval or templates:** builds a command, code or a template
  from a value known only at run time.
- **File paths:** opens, writes, deletes or extracts a path built from such a
  value.
- **Queries:** builds SQL, NoSQL, LDAP, XPath or a search query.
- **Secrets, tokens or crypto:** reads, stores, logs or compares a secret, or
  hashes, signs, encrypts or draws random values for security.
- **Outbound network calls:** sends a request to a host or URL, above all one
  built from input.
- **Deserialisation:** turns outside bytes into objects, such as pickle,
  YAML tags, XML entities, or Java or PHP serialisation.
- **Dependencies or lockfiles:** adds, removes or bumps a package, or changes
  a lockfile or registry setting.
- **CI workflows:** changes a workflow, its triggers, its permissions, or the
  actions it runs.
- **Hooks or permission rules:** changes a git or agent hook, an allow or
  deny list, or a sandbox setting.

A change to tests, docs, comments or formatting alone touches none. The
review report opens with one line: `Trust boundary: none`, or the kinds with a
`file:line` each, such as
`Trust boundary: shell (lib/list.sh:3), untrusted input (serve.sh:4)`.

**Done when:** that line is written.

## The checklist

Each intent check brief carries the items for the kinds touched. A finding
names the input, the path it takes to the boundary, and the `file:line`, and
counts only when someone outside the code's owner can reach it.

- **Auth:** every new entry point checks identity and rights on the server
  before it acts, and a failed check denies.
- **Input:** checked where it enters, for type, size and allowed values, and
  rejected rather than repaired.
- **Shell and templates:** no outside value reaches `sh -c`, `eval`, a
  backtick, or a template's source. Arguments go as a list, after `--`, with
  every variable quoted.
- **Paths:** resolved, then confirmed under the intended root, so `..`, an
  absolute path or a symlink cannot leave it. Archive entries are checked
  before extraction.
- **Queries:** values are bound as parameters, never joined into the text.
- **Secrets:** none in code, logs, errors, URLs or the repo. Compared in
  constant time. Crypto and random values come from the platform's library,
  never MD5 or SHA-1 for passwords or signatures.
- **Outbound:** a host from input is checked against an allow list that keeps
  internal addresses and cloud metadata out, and TLS checks stay on.
- **Deserialisation:** outside bytes go only to a parser that builds plain
  data, such as a safe YAML loader.
- **Dependencies:** each new package is the one meant, spelled right and
  maintained, pinned, with its lockfile updated beside it, and its install
  scripts read.
- **CI:** no `pull_request_target` or `workflow_run` job runs a fork's code
  with secrets, no `${{ github.event.* }}` sits inside a `run:` line,
  `permissions` are as narrow as the job needs, and third-party actions are
  pinned to a commit.
- **Hooks and rules:** a hook fails closed, an allow rule names the exact
  command, and nothing switches off a check another rule relies on.

Leave out denial of service, rate limits, resource use, and lines the change
did not touch.

On implement's fast path, which runs no intent check otherwise, brief one for
this list alone, on round 1 and on the final tree.

**Done when:** the intent check has reported on each kind touched.

## The built-in

`deliver.md` step 5 runs Claude Code's `security-review` once per run, on a
stack at the top layer this run built, when any layer's report names a trust
boundary. It reads only the commits between `origin/HEAD` and `HEAD`, which
is why it waits for the commit.

1. When `git rev-parse --verify -q origin/HEAD` prints nothing, run
   `git remote set-head origin -a`.
2. Brief a general-purpose subagent to call the Skill tool with
   `security-review` and no arguments, and to reply with its report alone,
   editing, committing and posting nothing. It runs in a subagent because
   its prompt ends with a report-only reply, which would end the run's turn.
3. Each finding goes in the review loop's ledger as round `S`, through
   `review.md` sections 3 and 4. A finding on a layer this run built is fixed
   on that layer, as [stack.md](stack.md) says, and one in lines another run
   wrote goes to follow-ups. A fix round reruns `code-review` on what
   changed, never `security-review`, and the report says the built-in did
   not see the fix.

**Done when:** each of its findings is in the ledger with its marks.

## Where it cannot run

When the skill is missing, as in Cursor, when it fails, when there is no
`origin` or `set-head` fails, or when the run commits nothing, the checklist
has already run. The report says the built-in did not run, and why.

**Done when:** the report says so.

---

The reachability rule and the exclusions are adapted from the prompt in
[anthropics/claude-code-security-review](https://github.com/anthropics/claude-code-security-review)
(MIT).
