# Reads one shell command on stdin, the whole of it, and prints one line per
# remote write it finds, for hooks/eng-hook to decide on:
#
#   post <what>            a comment, review or reply; always denied
#   gate commit|push|pr|issue
#                          a write the matching eng skill runs
#   confirm <what>         any other write outside this machine; always asks
#   open pr                a pull or merge request it opens, beside its gate
#                          line, for the reminder to review the whole PR
#
# It prints nothing for a command that writes nowhere else. Plain POSIX awk,
# because the hook runs on macOS's awk and on Linux's.
#
# The command is split the way a shell would split it: on ; & | && || ( ) and
# newlines outside quotes, with quotes removed, backslashes applied, comments
# dropped, and heredoc bodies skipped as data. Each piece is then read from its
# first word, past variable assignments and wrappers such as timeout or env,
# and past git's global options, so `git -C dir push` is seen and a command
# that only quotes `gh pr comment` is not. A string passed to sh -c, bash -c or
# eval is split and read the same way.
#
# Commands inside $( ) and backticks are read the same way.
#
# What it cannot see: git aliases, push settings, a tag pushed by its bare
# name, a command built at run time, and anything inside a script it calls.

BEGIN {
  nseg = 0
  wrappers = " timeout time nice nohup stdbuf command builtin noglob xargs sudo doas env exec caffeinate watch flock chronic unbuffer ionice taskpolicy arch coproc setsid npx pnpx bunx ! { } then do else elif if while until "
  wrapvalue["exec"] = " -a "
  wrapvalue["watch"] = " -n -d --interval "
  wrapvalue["flock"] = " -w -E --timeout "
  wrapvalue["ionice"] = " -c -n -p "
  wrapvalue["taskpolicy"] = " -c -d -g -b -t -l -p "
  wrapvalue["doas"] = " -u -C "
  # The wrapper options that take the next word as their value.
  wrapvalue["sudo"] = " -u -g -h -p -C -D -r -t -U --user --group --host --prompt "
  wrapvalue["env"] = " -u -C --unset --chdir "
  wrapvalue["timeout"] = " -s -k --signal --kill-after "
  wrapvalue["nice"] = " -n --adjustment "
  wrapvalue["stdbuf"] = " -i -o -e "
  wrapvalue["xargs"] = " -I -L -n -P -s -d -E -a "
  shells = " sh bash zsh dash ksh fish "
  composevalue = " -f --file -p --project-name --env-file --profile --project-directory --ansi --progress --parallel -H --host --log-level -c --context --tlscacert --tlscert --tlskey --workdir "
  # Each tool's options whose next word is a value, often free text, never a
  # flag. has_flag reads the list for the tool being read.
  gitvalue = " -m -F -t -C -c --message --file --template --author --date --reuse-message --reedit-message "
  ghvalue = " -b -t -F -B -H -R -l -a -r -m -T --body --title --body-file --base --head --repo --label --assignee --reviewer --milestone --template "
  glabvalue = " -m -t -d -b -s -a -l --message --title --description --target-branch --source-branch --assignee --label --milestone --reviewer "
  pkgflags = " --tag --otp --registry --access "
  # curl, wget and httpie options whose value is never where the request goes.
  httpvalue = " -u --user -H --header -o --output -e --referer -A --user-agent -b --cookie -c --cookie-jar -K --config -E --cert --key --cacert -w --write-out < > "
  shellvalue = " -o -O +o +O --rcfile --init-file "
  # npm, pnpm, yarn and bun options that take a value before the subcommand.
  pkgvalue = " --filter -F --prefix -C --dir --workspace --registry --cwd "
  # In npm -w names a workspace; in pnpm it is --workspace-root, with no value.
  npmvalue = pkgvalue "-w "
  # gh api flags that take the next word as their value.
  apivalue = " -X --method -f -F --field --raw-field --input -H --header -q --jq -t --template --hostname --cache -p --preview "
}

{ buf = (NR > 1) ? buf "\n" $0 : $0 }

END {
  split_command(buf)
  # A command substitution, or a string handed to sh -c or eval, waits in the
  # queue and is split once the segments before it are read.
  for (s = 1; ; s++) {
    while (s > nseg && qi < nq) split_command(queue[++qi])
    if (s > nseg) break
    # A command this long is past reading, so it asks rather than passes.
    if (s >= 500) { emit("confirm a command too long to read"); break }
    classify(s)
  }
}

# Skips a heredoc body. Position i ends the line that opened it, and d is its
# delimiter, with a leading dash when tabs before the closing line are
# stripped. Returns the position that ends the delimiter line, and leaves the
# body in `body`.
function skip_body(str, i, n, d,    strip, k, line) {
  strip = (substr(d, 1, 1) == "-")
  if (strip) d = substr(d, 2)
  body = ""
  while (i < n) {
    k = index(substr(str, i + 1), "\n")
    line = (k > 0) ? substr(str, i + 1, k - 1) : substr(str, i + 1)
    i += (k > 0) ? k : length(line)
    if (strip) sub(/^\t+/, "", line)
    if (line == d) break
    body = body line "\n"
  }
  return i
}

# The position of the parenthesis that closes the one at position i. A heredoc
# inside is skipped whole, since an apostrophe or a parenthesis in its body is
# text. Inside (( )) a << is a shift, and <<< is a here-string, so neither
# starts one.
function closing(str, i, n,    depth, arith, c, q, d, k) {
  depth = 0
  arith = 0
  q = ""
  for (; i <= n; i++) {
    c = substr(str, i, 1)
    if (q != "") {
      if (c == q) q = ""
      else if (c == "\\" && q == "\"") i++
      continue
    }
    if (!arith && c == "<" && substr(str, i + 1, 1) == "<" && substr(str, i + 2, 1) != "<" && substr(str, i - 1, 1) != "<") {
      d = substr(str, i + 2)
      sub(/^[ \t]*/, "", d)
      if (!match(d, /^-?[ \t]*['"]?[A-Za-z0-9_.-]+/)) continue
      d = substr(d, 1, RLENGTH)
      gsub(/['" \t]/, "", d)
      k = index(substr(str, i), "\n")
      if (k == 0) continue
      i = skip_body(str, i + k - 1, n, d)
      continue
    }
    if (c == "'" || c == "\"") { q = c; continue }
    if (c == "\\") { i++; continue }
    if (c == "(") {
      depth++
      if (!arith && substr(str, i + 1, 1) == "(") arith = depth
    } else if (c == ")") {
      if (arith == depth) arith = 0
      if (--depth == 0) return i
    }
  }
  return n
}

# Removes -R and --repo, with their values, from segment s from position i
# on, leaving alone a word that is the value of another option in the list
# values.
function drop_repo(s, i, values,    j, k, isvalue) {
  k = i - 1
  isvalue = 0
  for (j = i; j <= segn[s]; j++) {
    if (isvalue) { segw[s, ++k] = segw[s, j]; isvalue = 0; continue }
    if (segw[s, j] == "-R" || segw[s, j] == "--repo") { j++; continue }
    if (segw[s, j] ~ /^(-R.|--repo=)/) continue
    segw[s, ++k] = segw[s, j]
    isvalue = has(values, segw[s, j])
  }
  for (j = k + 1; j <= segn[s]; j++) delete segw[s, j]
  segn[s] = k
}

# What reaches segment s on stdin, when it can be read: its own heredoc, or a
# heredoc or the words of echo or printf piped from the command before it.
function stdin_text(s,    w) {
  if (s in hdbody) return hdbody[s]
  if (!(s in piped)) return ""
  if (piped[s] in hdbody) return hdbody[piped[s]]
  if (base(segw[piped[s], 1]) ~ /^(echo|printf)$/) {
    # printf turns \n into a line break, and so does echo in dash and zsh, so
    # both are read that way.
    w = rest(piped[s], 2)
    gsub(/\\n/, "\n", w)
    return w
  }
  return ""
}

# Queues every $( ) and backtick command in text where quotes are plain
# characters, as in a heredoc body.
function live_substitutions(text,    n, i, c, k) {
  n = length(text)
  for (i = 1; i <= n; i++) {
    c = substr(text, i, 1)
    if (c == "\\") { i++; continue }
    if (c == "`") {
      k = index(substr(text, i + 1), "`")
      if (k == 0) return
      queue[++nq] = substr(text, i + 1, k - 1)
      i += k
    } else if (c == "$" && substr(text, i + 1, 1) == "(" && substr(text, i + 2, 1) != "(") {
      k = closing(text, i + 1, n)
      queue[++nq] = substr(text, i + 2, k - i - 2)
      i = k
    }
  }
}

# Queues the command inside $( ) or backticks starting at position i, adds a
# placeholder to the word, and returns the position where it ends.
function substitution(str, i, n,    k) {
  if (substr(str, i, 1) == "`") {
    k = index(substr(str, i + 1), "`")
    k = (k > 0) ? i + k : n
    queue[++nq] = substr(str, i + 1, k - i - 1)
  } else {
    k = closing(str, i + 1, n)
    # $(( )) is arithmetic, not a command.
    if (substr(str, i + 2, 1) != "(") queue[++nq] = substr(str, i + 2, k - i - 2)
  }
  word = word "$(...)"
  inword = 1
  return k
}

function emit(line) {
  if (!(line in seen)) { seen[line] = 1; print line }
}

# Ends the word being built, if any, and adds it to the current segment.
function end_word() {
  if (inword) {
    # A heredoc's delimiter is not an argument.
    if (wanthd && word == "-" && !quoted) hddash = 1
    else if (wanthd) {
      hd[++nhd] = (hddash ? "-" : "") word
      hdseg[nhd] = nseg
      hdq[nhd] = quoted
      wanthd = 0
      hddash = 0
    }
    else { segn[nseg]++; segw[nseg, segn[nseg]] = word }
  }
  word = ""
  inword = 0
  quoted = 0
}

function end_segment() {
  end_word()
  if (segn[nseg] > 0) { nseg++; segn[nseg] = 0 }
}

function split_command(str,    i, n, c, nx, q, j) {
  nseg++
  segn[nseg] = 0
  word = ""; inword = 0; q = ""; nhd = 0; wanthd = 0
  n = length(str)
  for (i = 1; i <= n; i++) {
    c = substr(str, i, 1)
    nx = substr(str, i + 1, 1)
    if (q == "'") {
      if (c == "'") q = ""; else word = word c
      continue
    }
    # $'...' takes backslash escapes, so \' does not end it.
    if (q == "a") {
      if (c == "\\") { word = word nx; i++ }
      else if (c == "'") q = ""
      else word = word c
      continue
    }
    if (q == "\"") {
      if (c == "\"") q = ""
      else if ((c == "$" && nx == "(") || c == "`") i = substitution(str, i, n)
      else if (c == "\\" && (nx == "\"" || nx == "\\" || nx == "$" || nx == "`")) { word = word nx; i++ }
      else if (c == "\\" && nx == "\n") i++
      else word = word c
      continue
    }
    if (c == "\\") {
      if (nx != "\n") { word = word nx; inword = 1; quoted = 1 }
      i++
      continue
    }
    if (c == "$" && nx == "'") { q = "a"; inword = 1; i++; continue }
    if (c == "'" || c == "\"") { q = c; inword = 1; quoted = 1; continue }
    if ((c == "$" && nx == "(") || c == "`") { i = substitution(str, i, n); continue }
    # (( )) is arithmetic, where << is a shift, so it stays one word.
    if (c == "(" && nx == "(" && !inword) {
      i = closing(str, i, n)
      word = word "((...))"
      inword = 1
      continue
    }
    if (c == "#" && !inword) {
      while (i < n && substr(str, i + 1, 1) != "\n") i++
      continue
    }
    if (c == " " || c == "\t") { end_word(); continue }
    if (c == "\n") {
      end_segment()
      # Skip each pending heredoc body, in order, up to its delimiter line.
      for (j = 1; j <= nhd; j++) {
        i = skip_body(str, i, n, hd[j])
        hdbody[hdseg[j]] = hdbody[hdseg[j]] body
        # An unquoted delimiter leaves $( ) and backticks live in the body.
        if (!hdq[j]) live_substitutions(body)
      }
      nhd = 0
      continue
    }
    if (c == "<" && nx == "<" && substr(str, i + 2, 1) == "<") {
      word = word "<<<"
      inword = 1
      i += 2
      continue
    }
    if (c == "<" && nx == "<") {
      end_word()
      i++
      # A dash after << belongs to the delimiter word, which marks it.
      wanthd = 1
      continue
    }
    if (c == "&" && (substr(word, length(word), 1) == ">" || substr(word, length(word), 1) == "<" || nx == ">")) {
      word = word c; inword = 1
      continue
    }
    if (c == ";" || c == "&" || c == "|" || c == "(" || c == ")") {
      end_segment()
      if ((c == "&" || c == "|") && (nx == "&" || nx == "|")) i++
      # A single | feeds this segment's output to the next one.
      else if (c == "|") piped[nseg] = nseg - 1
      continue
    }
    # A redirect glued to a word, as in git push>/dev/null, is not part of it,
    # but 2>&1 and the like keep their file descriptor number.
    if ((c == ">" || c == "<") && inword && word !~ /^[0-9]*&?$/ && word !~ /[<>]$/) end_word()
    word = word c
    inword = 1
  }
  end_segment()
}

function base(w) {
  sub(/.*\//, "", w)
  return w
}

function has(list, w) {
  return index(list, " " w " ") > 0
}

# The segment's words from position i on, joined by spaces.
function rest(s, i,    out) {
  out = ""
  for (; i <= segn[s]; i++) out = out (out == "" ? "" : " ") segw[s, i]
  return out
}

function classify(s,    i, n, w, cmd, j, list, k, m) {
  n = segn[s]
  if (n == 0) return
  # prisma can sit behind npx, pnpm, yarn, bunx and their options, so look
  # past those, but not past a word such as echo.
  for (j = 1; j + 2 <= n; j++) {
    if (base(segw[s, j]) == "prisma") {
      if (segw[s, j + 1] == "migrate" && segw[s, j + 2] == "deploy") emit("confirm prisma migrate deploy")
      break
    }
    if (segw[s, j] !~ /^(npx|pnpx|bunx|pnpm|yarn|bun|exec|dlx|run|-.*|[A-Za-z_][A-Za-z0-9_]*=.*)$/) break
  }
  i = 1
  while (i <= n) {
    w = segw[s, i]
    if (w ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { i++; continue }
    # function f { ... } runs its body when called, so read it here.
    if (w == "function") { i += 2; continue }
    # A redirection: alone it takes the next word as its target.
    if (w ~ /^[0-9]*(>>?|<|&>>?|>&|<&|<>|>\|)$/) { i += 2; continue }
    if (w ~ /^[0-9]*(>>?|<|&>>?|>&|<&|<>|>\|)/) { i++; continue }
    if (has(wrappers, base(w))) {
      cmd = base(w)
      i++
      while (i <= n) {
        w = segw[s, i]
        if (w ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || w ~ /^[0-9.]+[smhd]?$/) { i++; continue }
        # env -S splits its value into a command and runs it, as sh -c does.
        if (cmd == "env" && w ~ /^(-[A-Za-z]*S|--split-string)/) {
          if (w ~ /^--split-string=/) { sub(/^[^=]*=/, "", w); queue[++nq] = w " " rest(s, i + 1) }
          else if (w ~ /^-[A-Za-z]*S$/ || w == "--split-string") queue[++nq] = rest(s, i + 1)
          else { sub(/^-[A-Za-z]*S/, "", w); queue[++nq] = w " " rest(s, i + 1) }
          return
        }
        if (w ~ /^-/) { i++; if (has(wrapvalue[cmd], w)) i++; continue }
        break
      }
      # watch joins its words and hands them to sh -c.
      if (cmd == "watch") { queue[++nq] = rest(s, i); return }
      # flock takes a lock file before the command, or runs -c's string.
      if (cmd == "flock") {
        i++
        if (segw[s, i] == "-c" || segw[s, i] == "--command") { queue[++nq] = segw[s, i + 1]; return }
      }
      continue
    }
    break
  }
  if (i > n) return
  cmd = base(segw[s, i])
  if (has(shells, cmd)) {
    for (j = i + 1; j < n; j++)
      if (segw[s, j] ~ /^-[A-Za-z]*c[A-Za-z]*$/) { queue[++nq] = segw[s, j + 1]; return }
    for (j = i + 1; j <= n; j++) {
      if (segw[s, j] == "<<<") { queue[++nq] = segw[s, j + 1]; return }
      if (segw[s, j] ~ /^<<</) { queue[++nq] = substr(segw[s, j], 4); return }
    }
    for (j = i + 1; j <= n && segw[s, j] ~ /^[-+]/; j++) if (has(shellvalue, segw[s, j])) j++
    if (base(segw[s, j]) ~ /^deploy.*\.sh$/) emit("confirm a deploy")
    if (segw[s, j] == "/dev/stdin" || segw[s, j] == "-") j = n + 1
    # No script to run, so the shell runs what reaches its stdin: its own
    # heredoc, or one piped from the command before it.
    if (j > n || segw[s, j] ~ /^[0-9]*</) {
      w = stdin_text(s)
      if (w != "") queue[++nq] = w
    }
    return
  }
  if (cmd == "eval") { queue[++nq] = rest(s, i + 1); return }
  # source and . run a script in this shell.
  if ((cmd == "source" || cmd == ".") && base(segw[s, i + 1]) ~ /^deploy.*\.sh$/) { emit("confirm a deploy"); return }
  # A nested Claude Code run of a review that posts.
  if (cmd == "claude" && rest(s, i + 1) ~ /\/(code-)?review/ && rest(s, i + 1) ~ /--(comment|post)/) { emit("post a code-review run with --comment or --post"); return }
  # Tracker CLIs that comment or approve.
  valueflags = (cmd == "glab") ? glabvalue : pkgflags
  # glab takes -R or --repo anywhere, as gh does, so drop it and its value.
  if (cmd == "glab") drop_repo(s, i + 1, glabvalue)
  if (cmd == "glab" && has_flag(s, i + 1, "^(-h|--help)$")) return
  if (cmd == "glab" && segw[s, i + 1] ~ /^(mr|issue)$/ && segw[s, i + 2] ~ /^(note|comment|approve)$/) { emit("post glab " segw[s, i + 1] " " segw[s, i + 2]); return }
  if (cmd == "glab") {
    w = segw[s, i + 1] " " segw[s, i + 2]
    # --fill implies --push, which pushes the branch.
    # -f is --fill; it may sit among glab's other one-letter switches, -y and -w.
    # A create opens a merge request, unless --web or -w, alone or among those
    # switches, leaves it to the browser.
    if (w ~ /^mr (create|new|update|ready)$/) {
      emit("gate pr")
      if (has_flag(s, i + 3, "^(--push|--fill|-[yw]*f[A-Za-z]*)$")) emit("gate push")
      if (w ~ /^mr (create|new)$/ && !has_flag(s, i + 3, "^(--web(=true)?|-[yf]*w[yf]*)$")) emit("open pr")
    }
    else if (w ~ /^(issue (create|new|update|close|reopen|delete)|label (create|delete|edit))$/) emit("gate issue")
    else if (w ~ /^(mr (merge|close|reopen|delete|revoke|rebase)|release (create|delete|upload)|repo (create|delete|fork|archive)|ci (run|retry|cancel|delete)|variable (set|update|delete)|schedule (create|delete|run))$/) emit("confirm glab " w)
    else if (segw[s, i + 1] == "api") glab_api(s, i + 1)
    return
  }
  if (cmd == "jira" && rest(s, i + 1) ~ /(^| )comment( |$)/) { emit("post jira comment"); return }
  if (cmd == "linear" && rest(s, i + 1) ~ /(^| )comment( |$)/) { emit("post linear comment"); return }
  if (cmd == "docker" || cmd == "docker-compose") {
    j = i + 1
    if (cmd == "docker") {
      for (; j <= n && segw[s, j] ~ /^-/; j++) if (segw[s, j] ~ /^(-H|--host|-c|--context|--config|-l|--log-level|--tlscacert|--tlscert|--tlskey)$/) j++
    }
    k = j
    # compose, as a docker subcommand or its own binary: the first word past
    # its options, and the values of those that take one, is the subcommand.
    if (cmd == "docker-compose" || segw[s, k] == "compose") {
      if (cmd == "docker") k++
      for (; k <= n && segw[s, k] ~ /^-/; k++) if (has(composevalue, segw[s, k])) k++
      # alpha holds the experimental subcommands, such as publish.
      if (segw[s, k] == "alpha") k++
    } else if (segw[s, k] ~ /^(buildx|builder|image)$/) {
      for (k++; k <= n && segw[s, k] ~ /^-/; k++) if (segw[s, k] ~ /^(--builder)$/) k++
    }
    w = " " rest(s, k) " "
    if (segw[s, k] ~ /^(push|publish)$/ || w ~ /^ (image|manifest) push / || w ~ /^ imagetools create / ||
        (segw[s, k] ~ /^(build|bake|b)$/ && (w ~ / --push( |=)/ || w ~ /type=registry|push=true/))) emit("confirm docker push")
    return
  }
  if (cmd == "changeset" && segw[s, i + 1] == "publish") { emit("confirm a package publish"); return }
  if (cmd == "find") {
    for (j = i + 1; j <= n; j++) {
      if (segw[s, j] !~ /^-(exec|execdir|ok|okdir)$/) continue
      w = ""
      for (j++; j <= n && segw[s, j] != ";" && segw[s, j] != "+"; j++) w = w " " segw[s, j]
      queue[++nq] = w
    }
    return
  }
  if (cmd == "git") { git_command(s, i); return }
  if (cmd == "gh") { gh_command(s, i); return }
  if (cmd == "curl" || cmd == "wget" || cmd == "http" || cmd == "https" || cmd == "xh") { http_command(s, i); return }
  if (cmd == "npm" || cmd == "pnpm" || cmd == "yarn" || cmd == "bun") {
    list = (cmd == "npm") ? npmvalue : pkgvalue
    for (j = i + 1; j <= n && segw[s, j] ~ /^-/; j++) if (has(list, segw[s, j])) j++
    # yarn workspace <name> <command>
    if (cmd == "yarn" && segw[s, j] == "workspace") for (j += 2; j <= n && segw[s, j] ~ /^-/; j++) ;
    if (segw[s, j] ~ /^(exec|dlx)$/) j++
    if (segw[s, j] == "changeset" && segw[s, j + 1] == "publish") { emit("confirm a package publish"); return }
    if (segw[s, j] == "npm") for (j++; j <= n && segw[s, j] ~ /^-/; j++) if (has(npmvalue, segw[s, j])) j++
    if (segw[s, j] ~ /^(un)?publish$/ && !has_flag(s, j + 1, "^--dry-run$")) emit("confirm a package publish")
    return
  }
  if ((cmd == "cargo" || cmd == "poetry") && segw[s, i + 1] == "publish") { if (!has_flag(s, i + 2, "^--dry-run$")) emit("confirm a package publish"); return }
  # Graphite's submit pushes branches and opens pull requests.
  if (cmd == "gt" && segw[s, i + 1] ~ /^(submit|ss)$/) { emit("gate push"); emit("gate pr"); if (!has_flag(s, i + 2, "^--dry-run$")) emit("open pr"); return }
  if (cmd == "twine" && segw[s, i + 1] == "upload") { emit("confirm a package publish"); return }
  if (cmd == "gem" && segw[s, i + 1] == "push") { emit("confirm a package publish"); return }
  if (cmd == "gcloud") {
    w = " " rest(s, i + 1) " "
    if (w ~ / builds submit / || w ~ / (run|app|functions) deploy /) emit("confirm a deploy")
    return
  }
  if ((cmd == "firebase" || cmd == "firebase-tools") && rest(s, i + 1) ~ /(^| |:)deploy( |$)/) { emit("confirm a deploy"); return }
  if (cmd == "terraform" || cmd == "tofu") {
    for (j = i + 1; j <= n && segw[s, j] ~ /^-/; j++) ;
    if (segw[s, j] ~ /^(apply|destroy)$/) emit("confirm a deploy")
    return
  }
  if (cmd ~ /^deploy.*\.sh$/) { emit("confirm a deploy"); return }
  w = " " rest(s, i + 1) " "
  if (cmd == "kubectl") {
    for (j = i + 1; j <= n && segw[s, j] ~ /^-/; j++) if (segw[s, j] ~ /^-(n|-namespace|-context|-kubeconfig)$/) j++
    if (segw[s, j] ~ /^(apply|create|delete|replace|patch|scale|set|edit|label|annotate|run|expose|drain|cordon|uncordon|taint|autoscale|cp)$/ ||
        (segw[s, j] == "rollout" && segw[s, j + 1] ~ /^(restart|undo|pause|resume)$/)) emit("confirm a deploy")
    return
  }
  if (cmd == "helm" && w ~ / (install|upgrade|uninstall|rollback|delete|push) /) { emit("confirm a deploy"); return }
  if ((cmd == "fly" || cmd == "flyctl" || cmd == "netlify" || cmd == "serverless" || cmd == "sls" || cmd == "wrangler") && w ~ / (deploy|publish) /) { emit("confirm a deploy"); return }
  # vercel deploys unless its first word names another subcommand.
  if (cmd == "vercel") {
    for (j = i + 1; j <= n && (segw[s, j] ~ /^-/ || segw[s, j] ~ /^[0-9]*[<>&]/); j++) if (segw[s, j] ~ /^--(token|scope|cwd)$/) j++
    if (segw[s, j] !~ /^(ls|list|logs|env|login|logout|whoami|dev|pull|inspect|link|domains|dns|project|projects|help|build|certs|secrets|teams|switch|init|git|bisect|--version)$/) emit("confirm a deploy")
    return
  }
  # aws: an operation named for a write, or an s3 copy or removal.
  if (cmd == "aws") {
    for (j = i + 1; j <= n && segw[s, j] ~ /^-/; j++) if (segw[s, j] ~ /^--(profile|region|output|endpoint-url)$/) j++
    if (segw[s, j] == "s3") {
      # cp, sync and mv write to S3 when a path after the first one is an s3:
      # path. The first may be - for stdin; an option's value may count as a
      # path, which only moves the first one earlier.
      m = 0; w = ""
      for (k = j + 2; k <= n; k++) if (segw[s, k] == "-" || segw[s, k] !~ /^-/) { if (++m > 1 && segw[s, k] ~ /^s3:/) w = segw[s, k] }
      if (segw[s, j + 1] ~ /^(rm|rb|mb)$/ || (segw[s, j + 1] ~ /^(cp|sync|mv)$/ && w != "")) emit("confirm a deploy")
    } else if (segw[s, j + 1] ~ /^(put|update|create|delete|deploy|start|stop|terminate|run|invoke|publish|register|modify|attach|detach|tag|untag|reboot|restore|import|associate|disassociate|enable|disable|set|apply|cancel|execute|send|upload)(-|$)/) emit("confirm a deploy")
    return
  }
}

function git_command(s, i,    n, j, w, sub_, risky, options, b) {
  valueflags = gitvalue
  n = segn[s]
  j = i + 1
  while (j <= n) {
    w = segw[s, j]
    if (w == "-C" || w == "-c" || w == "--git-dir" || w == "--work-tree" || w == "--namespace" || w == "--super-prefix" || w == "--config-env") { j += 2; continue }
    if (w ~ /^-/) { j++; continue }
    break
  }
  sub_ = segw[s, j]
  # Help comes right after the subcommand; elsewhere -h or --help may be a
  # message, as in git commit -am --help.
  if (segw[s, j + 1] ~ /^(-h|--help)$/) return
  if (sub_ == "commit") { if (!has_flag(s, j + 1, "^--dry-run$")) emit("gate commit"); return }
  if (sub_ == "send-pack" || (sub_ == "svn" && segw[s, j + 1] == "dcommit")) { emit("gate push"); return }
  if ((sub_ == "subtree" || sub_ == "lfs") && segw[s, j + 1] == "push") { emit("gate push"); return }
  if (sub_ == "send-email") { emit("confirm git send-email"); return }
  # A dry run, -n alone or among other one-letter switches; -o takes its value
  # glued on, as in -onotify, so a word starting -o is not one.
  if (sub_ != "push" || has_flag(s, j + 1, "^(--dry-run|-[a-np-zA-Z]*n[a-np-zA-Z]*)$")) return
  emit("gate push")
  risky = 0
  for (j++; j <= n; j++) {
    w = segw[s, j]
    if (w ~ /^--(force|force-with-lease|force-if-includes|delete|mirror|prune|tags|follow-tags)(=|$)/) risky = 1
    else if (w ~ /^--push-option(=|$)/) { options = 1; if (w !~ /=/) j++ }
    else if (w == "--repo") j++
    else if (w ~ /^-[A-Za-z]/ && w !~ /^--/) {
      # A bundle of short switches: f or d before any o forces or deletes, and
      # o takes the rest of the word as a push option, or the next word when
      # it ends the bundle.
      b = w
      if (match(b, /o/)) { options = 1; if (RSTART == length(b)) j++; b = substr(b, 1, RSTART - 1) }
      if (b ~ /[fd]/) risky = 1
    }
    else if (w ~ /^[+:]/ || w ~ /(^|:)refs\/tags\// || w == "tag") risky = 1
  }
  if (risky) emit("confirm a push that forces, deletes or pushes tags")
  if (options) emit("confirm a push with push options, which the server acts on")
}

# True when a word from position from on matches re as a flag, and is not the
# value of an option such as -m or --body.
function has_flag(s, from, re,    j) {
  for (j = from; j <= segn[s]; j++) {
    if (j > from && has(valueflags, segw[s, j - 1])) continue
    if (segw[s, j] ~ re) return 1
  }
  return 0
}

function gh_command(s, i,    g, c, from, comment, at) {
  # gh takes -R or --repo anywhere, so drop it and its value first.
  drop_repo(s, i + 1, ghvalue)
  g = segw[s, i + 1]
  c = segw[s, i + 2]
  at = i + 1
  from = i + 3
  # gh's built-in aliases name the same commands.
  if (c == "new") c = "create"
  # Help writes nothing.
  valueflags = ghvalue
  if (segw[s, i + 3] ~ /^(-h|--help)$/) return
  comment = has_flag(s, i + 1, "^(--comment(=.*)?|-c.*)$")
  if (g == "api") { api_command(s, at); return }
  if (g == "pr") {
    if (c == "comment" || c == "review") emit("post gh pr " c)
    else if ((c == "close" || c == "reopen") && comment) emit("post gh pr " c " --comment")
    else if (c == "create") {
      # --web and --dry-run open no pull request, but either can push the branch.
      # -w may sit among the other switches that take no value, -d and -f.
      if (has_flag(s, from, "^(--web(=true)?|--dry-run(=true)?|-[df]*w[df]*)$")) emit("gate push"); else { emit("gate pr"); emit("open pr") }
    }
    else if (c == "edit" || c == "ready") emit("gate pr")
    else if (c ~ /^(merge|close|reopen|update-branch|revert)$/) emit("confirm gh pr " c)
    return
  }
  if (g == "issue") {
    if (c == "comment") emit("post gh issue comment")
    else if ((c == "close" || c == "reopen") && comment) emit("post gh issue " c " --comment")
    else if (c == "create") { if (!has_flag(s, from, "^(--web|-w)$")) emit("gate issue") }
    else if (c ~ /^(edit|close|reopen|transfer|delete|lock|unlock|pin|unpin|develop)$/) emit("gate issue")
    return
  }
  if (g == "label" && c ~ /^(create|edit|delete|clone)$/) { emit("gate issue"); return }
  if (g == "release" && c ~ /^(create|edit|delete|delete-asset|upload)$/) { emit("confirm gh release " c); return }
  if (g == "workflow" && c ~ /^(run|enable|disable)$/) { emit("confirm gh workflow " c); return }
  if (g == "run" && c ~ /^(rerun|cancel|delete)$/) { emit("confirm gh run " c); return }
  if (g == "repo" && c ~ /^(create|delete|edit|archive|unarchive|rename|fork|sync)$/) { emit("confirm gh repo " c); return }
  if (g == "gist" && c ~ /^(create|new|edit|delete|rename)$/) { emit("confirm gh gist " c); return }
  if (g == "cache" && c == "delete") { emit("confirm gh cache delete"); return }
  if (g == "project" && c ~ /^(create|edit|delete|close|copy|link|unlink|mark-template|item-add|item-create|item-edit|item-delete|item-archive|field-create|field-delete)$/) { emit("confirm gh project " c); return }
  if ((g == "secret" || g == "variable") && c ~ /^(set|delete)$/) { emit("confirm gh " g " " c); return }
}

# glab api: read like gh api, with GitLab's names for a comment.
function glab_api(s, i,    j, n, w, method, body, text) {
  n = segn[s]
  method = ""; body = 0
  for (j = i + 1; j <= n; j++) {
    w = segw[s, j]
    if (w == "-X" || w == "--method") { method = segw[s, j + 1]; j++; continue }
    if (w ~ /^--method=/) { method = substr(w, 10); continue }
    if (w ~ /^-X./) { method = substr(w, 3); continue }
    if (w ~ /^(-f|-F|--field|--raw-field|--input)$/) { body = 1; j++; continue }
    if (w ~ /^(-[fF].|--(field|raw-field|input)=)/) body = 1
  }
  if (method == "") method = body ? "POST" : "GET"
  method = toupper(method)
  if (method == "GET" || method == "HEAD") return
  text = rest(s, i + 1) " " stdin_text(s)
  fileq = file_arg(s, i + 1)
  if (text ~ /(^| )\/?graphql( |$)/ && text !~ /mutation/) {
    if (unreadable_query(text)) emit("confirm a GraphQL request whose query is not on the command line")
    return
  }
  if (text ~ /(notes|discussions|award_emoji|approve|createNote|createDiscussion|awardEmoji|mergeRequestApprove)/) emit("post glab api")
  else emit("confirm glab api write")
}

# True when a GraphQL request takes its query from a file, a variable, stdin
# or a substitution, so the query itself cannot be read here.
function unreadable_query(text) {
  return fileq || text ~ /query=\$|--input|\$\(\.\.\.\)/
}

# True when one of segment s's words from position i on hands the request a
# file: a word of its own starting with @, a query or an option set to @file,
# or a short option glued to it, as in -d@x. Each word is whole here, so an @
# inside a quoted query, such as a directive, is not one.
function file_arg(s, i,    j, w) {
  for (j = i; j <= segn[s]; j++) {
    w = segw[s, j]
    if (w ~ /^@/ || w ~ /query=@/ || w ~ /^-[^=]*=@/ || w ~ /^-[A-Za-z]@/) return 1
  }
  return 0
}

function api_command(s, i,    j, n, w, method, body, path) {
  n = segn[s]
  method = ""; body = 0; path = ""
  for (j = i + 1; j <= n; j++) {
    w = segw[s, j]
    if (w == "-X" || w == "--method") { method = segw[s, j + 1]; j++; continue }
    if (w ~ /^--method=/) { method = substr(w, 10); continue }
    if (w ~ /^-X./) { method = substr(w, 3); continue }
    if (w == "-f" || w == "-F" || w == "--field" || w == "--raw-field" || w == "--input") { body = 1; j++; continue }
    if (w ~ /^(-[fF].|--(field|raw-field|input)=)/) { body = 1; continue }
    if (has(apivalue, w)) { j++; continue }
    if (w ~ /^-/) continue
    if (path == "") path = w
  }
  if (method == "") method = body ? "POST" : "GET"
  # A query read from stdin may be a heredoc on this command.
  fileq = file_arg(s, i + 1)
  api_write(toupper(method), path, rest(s, i + 1) " " stdin_text(s))
}

function http_command(s, i,    j, n, w, method, body, url, cmd, get, hook) {
  cmd = base(segw[s, i])
  n = segn[s]
  method = ""; body = 0; url = ""
  for (j = i + 1; j <= n; j++) {
    w = segw[s, j]
    if (w == "-X" || w == "--request" || w == "--method") { method = segw[s, j + 1]; j++; continue }
    if (w ~ /^-X./) { method = substr(w, 3); continue }
    if (w ~ /^--(request|method)=/) { method = w; sub(/^[^=]*=/, "", method); continue }
    # -G sends the data as query parameters on a GET.
    if (w == "--get" || (w ~ /^-[A-Za-z]*G[A-Za-z]*$/ && cmd == "curl")) get = 1
    if (w ~ /^(--data|--data-ascii|--data-raw|--data-binary|--data-urlencode|--json|--form|--form-string|--post-data|--post-file|--body-data|--body-file)$/) { body = 1; j++; continue }
    if (w ~ /^--(data|data-ascii|data-raw|data-binary|data-urlencode|json|form|form-string|post-data|post-file|body-data|body-file)=/) { body = 1; continue }
    # Short flags combine, as in -sd, -sXPOST or -dfoo.
    if (w ~ /^-[A-Za-z]*X[A-Za-z]+$/ && w !~ /^--/) { method = w; sub(/^-[A-Za-z]*X/, "", method); continue }
    if (w ~ /^-[A-Za-z]*X$/) { method = segw[s, j + 1]; j++; continue }
    if (w ~ /^-[A-Za-z]*[dFT]$/) { body = 1; if (w ~ /T$/) method = "PUT"; j++; continue }
    if (w ~ /^-[dF]./) { body = 1; continue }
    if (toupper(w) ~ /^(GET|HEAD|POST|PATCH|PUT|DELETE)$/ && cmd != "curl" && cmd != "wget") { method = toupper(w); continue }
    if (w == "-T" || w ~ /^--upload-file(=|$)/) { method = "PUT"; continue }
    # httpie and xh send a body, so POST, when given a field such as a=b or a:=1.
    if ((url != "" || hook) && (cmd == "http" || cmd == "https" || cmd == "xh") && w ~ /^[^=:\/-][^=:\/]*:?=[^=]/) body = 1
    # curl --url= names the request's URL.
    if (w ~ /^--url=/) w = substr(w, 7)
    # api.github.com, or a GitHub Enterprise host, which has github in its name.
    if (w ~ /(api\.github\.com|uploads\.github\.com|github[^\/ ]*\/api\/(v3\/|graphql))/) url = w
    # A chat webhook takes a POST as a message to a channel.
    # A field such as url=... is data, not where the request goes. A URL's own
    # query string is still the URL.
    if (w !~ /^[A-Za-z_][A-Za-z0-9_.-]*:?=/ && w ~ /(hooks\.slack\.com|slack\.com\/api\/chat\.(post|schedule)|discord(app)?\.com\/api\/(webhooks|channels)|webhook\.office\.com|outlook\.office\.com\/webhook|logic\.azure\.com.*\/workflows|chat\.googleapis\.com)/) hook = 1
    # A URL held in a variable named for a webhook, alone or after other
    # variables, as in "${BASE}${SLACK_WEBHOOK_PATH}".
    # A webhook variable that names an id, a secret or a token is not the URL,
    # and neither is the value of an option such as -u, -H or a < redirect.
    if (!has(httpvalue, segw[s, j - 1]) && w !~ /^[A-Za-z_][A-Za-z0-9_.-]*:?=/ && w !~ /: / &&
        w ~ /\$\{?[A-Za-z0-9_]*([Ww][Ee][Bb][Hh][Oo][Oo][Kk]|[Hh][Oo][Oo][Kk]_[Uu][Rr][Ll])[A-Za-z0-9_]*/ &&
        w !~ /\$\{?[A-Za-z0-9_]*[Ww][Ee][Bb][Hh][Oo][Oo][Kk][A-Za-z0-9_]*_([Ii][Dd]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Tt][Oo][Kk][Ee][Nn]|[Kk][Ee][Yy]|[Ss][Ii][Gg])\}?([^A-Za-z0-9_]|$)/) hook = 1
  }
  # httpie and xh send what reaches their stdin as the body.
  if (cmd == "http" || cmd == "https" || cmd == "xh") {
    # --offline only prints the request; stdin, < and --raw send a body.
    if (has_flag(s, i + 1, "^--offline$")) return
    if ((s in piped) || has_flag(s, i + 1, "^(<.*|--raw(=.*)?)$")) body = 1
  }
  if (hook && !(get && method == "") && (body || (method != "" && toupper(method) !~ /^(GET|HEAD)$/))) { emit("post a message to a chat webhook"); return }
  if (url == "") return
  if (method == "" && get) method = "GET"
  if (url ~ /uploads\.github\.com/ && (method != "" || body)) { emit("confirm an upload to GitHub"); return }
  if (method == "") method = body ? "POST" : "GET"
  sub(/^[a-z]*:\/\//, "", url)
  sub(/^api\.github\.com/, "", url)
  sub(/^[^\/]*\/api\/v3/, "", url)
  sub(/^[^\/]*\/api\/graphql/, "graphql", url)
  fileq = file_arg(s, i + 1)
  api_write(toupper(method), url, rest(s, i + 1) " " stdin_text(s))
}

# Decides what a GitHub API request writes, from its method, its path, and the
# text of the command, which holds a GraphQL query when there is one.
function api_write(method, path, text) {
  if (method == "GET" || method == "HEAD") return
  sub(/[?#].*/, "", path)
  sub(/^\/+/, "", path)
  if (path ~ /^search\//) return
  if (path == "graphql") {
    # A query read from a file or a variable cannot be read here, so it asks.
    if (text !~ /mutation/) {
      if (unreadable_query(text)) emit("confirm a GraphQL request whose query is not on the command line")
      return
    }
    if (text ~ /(addComment|addPullRequestReview|submitPullRequestReview|updatePullRequestReview|deletePullRequestReview|resolveReviewThread|unresolveReviewThread|updateIssueComment|deleteIssueComment|addDiscussionComment|updateDiscussionComment|addReaction|removeReaction|minimizeComment)/) emit("post a GraphQL comment or review mutation")
    else if (text ~ /(createIssue|updateIssue|closeIssue|reopenIssue|deleteIssue|transferIssue|pinIssue|unpinIssue|lockLockable|unlockLockable|LabelsToLabelable|LabelsFromLabelable|createLabel|updateLabel|deleteLabel|SubIssue|AssigneesToAssignable|AssigneesFromAssignable|BlockedBy)/) emit("gate issue")
    else if (text ~ /(createPullRequest|updatePullRequest|markPullRequestReadyForReview|convertPullRequestToDraft)/) { emit("gate pr"); if (text ~ /createPullRequest/) emit("open pr") }
    else emit("confirm a GraphQL mutation")
    return
  }
  if (path ~ /(^|\/)(comments|reviews|replies|reactions)(\/|$)/) { emit("post " method " " path); return }
  if (path ~ /(^|\/)pulls\/[0-9]+\/merge$/) { emit("confirm " method " " path); return }
  # A file write or a new commit or ref lands on the remote like a push. A
  # deleted ref is a deleted branch or tag, which asks.
  if (path ~ /(^|\/)git\/refs(\/|$)/ && method == "DELETE") { emit("confirm " method " " path); return }
  if (path ~ /(^|\/)(contents|git\/(refs|commits|trees|blobs|tags))(\/|$)/) { emit("gate push"); return }
  if (path ~ /(^|\/)(issues|labels|milestones|sub_issues|sub_issue|dependencies|assignees)(\/|$)/) { emit("gate issue"); return }
  if (path ~ /(^|\/)pulls(\/|$)/) { emit("gate pr"); if (path ~ /(^|\/)pulls\/?$/ && method == "POST") emit("open pr"); return }
  emit("confirm " method " " path)
}
