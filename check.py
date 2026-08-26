#!/usr/bin/env python3
"""Checks every skill against the mechanical half of WRITING-RULES.md.

The judgement calls stay manual; they are items 10 to 13 in that file.
Run before committing. Exits non-zero on any failure.

Written in Python rather than shell because the checks need to parse YAML
frontmatter, skip fenced code blocks, and walk filenames containing spaces.
A shell version silently skipped those and still printed a pass, which is why
the file is named .py despite the shell-shaped job it does.
"""

import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.realpath(__file__))
SELF = os.path.basename(os.path.realpath(__file__))
os.chdir(REPO)

EM_DASH = "—"
EN_DASH = "–"
HORIZONTAL_BAR = "―"
DASH_ENTITIES = ("&mdash;", "&#8212;", "&ndash;", "&#8211;")

# Files whose subject matter is the banned patterns themselves. They quote the
# words in order to ban them, so the word check cannot apply to them.
RULE_FILES = {"WRITING-RULES.md", "skills/plain-writing/SKILL.md"}

failures = []
warnings = []


def fail(msg, detail=None):
    failures.append((msg, detail or []))


def warn(msg):
    warnings.append(msg)


# Scanned for dashes. A stray em dash in link.sh or in a yaml display_name is
# a real violation.
EXTS = (".md", ".markdown", ".yaml", ".yml", ".txt", ".sh", ".py")

# Scanned for banned words and filler. Code is left out: strip_code only knows
# markdown fences, so every identifier in a .py or .sh file would read as
# prose, and plain-writing's own skip condition says renaming a variable called
# enhanceOrder is not this skill's business.
PROSE_EXTS = (".md", ".markdown", ".yaml", ".yml", ".txt")

# This file holds the dash characters as data, so the dash rule cannot apply to
# it. Adding .sh and .py above is what brings link.sh and this file under the
# dash rule at all.
DASH_EXEMPT = {SELF}
SKIP_DIRS = {".git", "node_modules", ".venv", "venv", "dist", "build"}


def _walk_files():
    for root, dirs, names in os.walk(REPO):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for n in sorted(names):
            yield os.path.relpath(os.path.join(root, n), REPO)


def _gitignored(paths):
    """Which of these paths git would ignore. Empty set when git cannot say."""
    if not paths:
        return set()
    try:
        out = subprocess.run(["git", "check-ignore", "-z", "--stdin"],
                             cwd=REPO, capture_output=True,
                             input="\0".join(paths).encode()).stdout
    except OSError:
        return set()
    return {f for f in out.decode("utf-8", "replace").split("\0") if f}


def _scannable():
    """The walk decides what exists; git only subtracts from it.

    Deriving the list from `git ls-files` instead made the scan silently
    empty whenever git returned nothing, for instance in a copy of this repo
    vendored inside a project whose .gitignore excludes it. Every prose check
    then passed over zero files and the script still printed success. The walk
    cannot come back empty, so that failure mode is gone.
    """
    found = list(_walk_files())
    ignored = _gitignored(found)          # one subprocess for the whole batch
    kept = [f for f in found if f not in ignored]
    if not kept:
        # Every file ignored means the rules belong to some enclosing repo,
        # not to this one. Scanning everything beats scanning nothing.
        warn("git reports every file as ignored, so .gitignore was not applied")
        return found
    return kept


_FILES = None


def text_files():
    """Every file worth scanning for prose violations, symlinks excluded."""
    global _FILES
    if _FILES is None:
        _FILES = _scannable()
    for rel in sorted(_FILES):
        if not rel.lower().endswith(EXTS):
            continue
        full = os.path.join(REPO, rel)
        if os.path.isfile(full) and not os.path.islink(full):
            yield rel


def read(path):
    with open(os.path.join(REPO, path), encoding="utf-8", errors="replace") as fh:
        return fh.read()


def strip_code(text):
    """Blank out fenced blocks and inline code so prose checks skip them.

    Line count is preserved so reported line numbers stay true.
    """
    out, in_fence = [], False
    for line in text.split("\n"):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            out.append("")
            continue
        out.append("" if in_fence else re.sub(r"`[^`]*`", "", line))
    return "\n".join(out)


def unwrap(text):
    """Join hard-wrapped lines so a phrase split across two lines is still seen.

    Returns (joined_paragraph, offsets) where offsets maps a character index in
    the joined text back to its source line, so a match on the fifth line of a
    wrapped paragraph is not reported against the first.
    """
    paras, cur = [], []

    def flush():
        if not cur:
            return
        joined, offsets, pos = "", [], 0
        for lineno, piece in cur:
            if joined:
                joined += " "
                pos += 1
            offsets.append((pos, lineno))
            joined += piece
            pos += len(piece)
        paras.append((joined, offsets))

    for i, line in enumerate(text.split("\n"), 1):
        if line.strip():
            cur.append((i, re.sub(r"\s+", " ", line.strip())))
        else:
            flush()
            cur = []
    flush()
    return paras


def line_of(offsets, index):
    """The source line holding the character at `index` in a joined paragraph."""
    hit = offsets[0][1]
    for pos, lineno in offsets:
        if pos > index:
            break
        hit = lineno
    return hit


def parse_frontmatter(text):
    """Return (dict, error). Requires a real --- block starting at line 1."""
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return None, "no YAML frontmatter (line 1 is not ---)"
    try:
        end = next(i for i in range(1, len(lines)) if lines[i].strip() == "---")
    except StopIteration:
        return None, "frontmatter is never closed with ---"

    data, key = {}, None
    for raw in lines[1:end]:
        if not raw.strip():
            continue
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", raw)
        if m and not raw.startswith((" ", "\t")):
            key, val = m.group(1), m.group(2).strip()
            if val in ("|", ">", "|-", ">-", "|+", ">+"):
                data[key] = ""          # block scalar, body collected below
            else:
                data[key] = val.strip("\"'")
        elif key is not None and raw.startswith((" ", "\t")):
            data[key] = (data[key] + " " + raw.strip()).strip()
    return data, None


def banned_lists():
    """Derive the word and phrase lists from plain-writing, the one source.

    Hardcoding a second copy is what let the two drift apart.
    """
    src = read("skills/plain-writing/SKILL.md")

    def grab(marker):
        i = src.find(marker)
        if i == -1:
            return None
        seg = src[i + len(marker):]
        seg = seg[:seg.index(".\n\n")] if ".\n\n" in seg else seg[:400]
        return re.sub(r"\s+", " ", seg)

    words_raw = grab("Replace these with plain words every time they appear:")
    phrases_raw = grab("Delete these phrases:")
    filler_raw = grab("Delete chatbot filler:")
    if not all((words_raw, phrases_raw, filler_raw)):
        fail(f"{SELF} cannot find the banned lists in plain-writing/SKILL.md",
             ["Its wording changed. Update banned_lists() so the two stay in sync."])
        return [], []

    words = []
    for w in words_raw.split(","):
        w = w.strip().rstrip(".")
        w = re.sub(r"\(as a metaphor\)", "", w).strip()
        if w and " " not in w:
            words.append(w)

    phrases = []
    for chunk in (phrases_raw, filler_raw):
        chunk = re.sub(r'\(use "[^"]*"\)', "", chunk)
        for p in re.findall(r'"([^"]+)"', chunk):
            p = p.strip()
            if len(p.split()) >= 2:
                phrases.append(p)
    # Word-choice verbs listed as prose rather than in the comma list.
    phrases += ["serves as", "stands as", "boasts"]
    # Single-word filler such as "Certainly" is dropped above: as a bare word
    # it fires on ordinary prose. Catch that one by reading, not by script.
    return words, phrases


# ---------------------------------------------------------------- prose

print("== prose ==")

for path in text_files():
    if path in DASH_EXEMPT:
        continue
    body = read(path)
    for name, ch in (("em dash", EM_DASH), ("en dash", EN_DASH),
                     ("horizontal bar", HORIZONTAL_BAR)):
        if ch in body:
            hits = [f"line {i}: {l.strip()[:70]}"
                    for i, l in enumerate(body.split("\n"), 1) if ch in l]
            fail(f"{path} contains an {name}", hits[:5])
    for ent in DASH_ENTITIES:
        if ent in body:
            fail(f"{path} contains the HTML entity {ent}, which renders as a dash")

WORDS, PHRASES = banned_lists()

for path in text_files():
    if path in RULE_FILES or not path.lower().endswith(PROSE_EXTS):
        continue
    prose = strip_code(read(path))
    for para, offsets in unwrap(prose):
        low = para.lower()
        for w in WORDS:
            m = re.search(rf"\b{re.escape(w)}\w*\b", low)
            if m:
                fail(f"{path}:{line_of(offsets, m.start())} "
                     f"uses the banned word '{w}'", [f"...{para[max(0, m.start() - 40):m.end() + 40]}..."])
        for p in PHRASES:
            m = re.search(rf"\b{re.escape(p.lower())}", low)
            if m:
                fail(f"{path}:{line_of(offsets, m.start())} "
                     f"uses the banned phrase '{p}'", [f"...{para[max(0, m.start() - 40):m.end() + 40]}..."])

# --------------------------------------------------------------- skills

print("== skills ==")

skills_dir = os.path.join(REPO, "skills")
if not os.path.isdir(skills_dir):
    fail("there is no skills/ directory")
    dirs = []
else:
    dirs = sorted(d for d in os.listdir(skills_dir)
                  if os.path.isdir(os.path.join(skills_dir, d)))
    if not dirs:
        fail("skills/ contains no skill directories")

readme = read("README.md") if os.path.exists("README.md") else ""
model_invoked = []

for name in dirs:
    rel = f"skills/{name}"
    skill_path = f"{rel}/SKILL.md"
    if not os.path.exists(os.path.join(REPO, skill_path)):
        fail(f"{name}: no SKILL.md")
        continue

    body = read(skill_path)
    fm, err = parse_frontmatter(body)
    if err:
        fail(f"{name}: {err}")
        continue

    if fm.get("name") != name:
        fail(f"{name}: frontmatter name is {fm.get('name')!r}, expected {name!r}")

    desc = (fm.get("description") or "").strip()
    if not desc or desc in ("|", ">", "|-", ">-"):
        fail(f"{name}: description is empty")

    heads = re.findall(r"^## (.+?)\s*$", strip_code(body), re.M)[:3]
    ok_heads = (["What this does", "When it runs", "How to use it"],
                ["What this does", "When to use it", "How to use it"])
    if heads not in ok_heads:
        fail(f"{name}: opening headings are {heads}",
             ["Expected: What this does / When it runs (or When to use it) / How to use it"])

    if len(heads) >= 2:
        prose = strip_code(body)
        seg = prose.split(f"## {heads[1]}", 1)[-1].split("## ", 1)[0]
        if "skip" not in seg.lower():
            fail(f"{name}: the '{heads[1]}' section names no skip condition",
                 ["WRITING-RULES: 'Including when to skip it.'"])

    blocks = [b.strip() for b in re.split(r"\n\s*\n", body) if b.strip()]
    tail = blocks[-1] if blocks else ""
    if not re.search(r"\bAdapted from\b", tail) and "licen" not in tail.lower():
        warn(f"{name}: last line is not an attribution. Confirm the skill is original.")

    row = re.search(rf"^\|.*\({re.escape(rel)}/SKILL\.md\).*\|", readme, re.M)
    if not row:
        fail(f"{name}: no row in a README table linking {skill_path}")

    user_invoked = str(fm.get("disable-model-invocation", "")).lower() == "true"
    if user_invoked:
        # Three shapes name a moment to run in. Matching bare "when" or "if"
        # instead rejected ordinary English: "what to try if it happens again"
        # names no trigger, and an author had no way to write it.
        TEMPORAL = r"before|when|while|during|whenever|after|upon|any ?time|prior to"
        VERB = r"run|call|type|invoke|use|apply|follow|start|trigger|execute|reach"
        trigger = "|".join((
            # opens with a condition: "Before shipping a change, ..."
            rf"^\s*(?:{TEMPORAL}|if|as soon as)\b",
            # says outright how to reach it
            rf"\b(?:use(?: this| it)?\s+(?:{TEMPORAL}|for)"
            r"|triggers? on|reach for|invoke|run this|apply(?: this)? when"
            r"|at the start of|on encountering)\b",
            # temporal word plus an activity: "before writing", "while planning"
            rf"\b(?:{TEMPORAL})\s+\w+ing\b",
            # opens with an imperative and names a time: "Run before every
            # release." Both halves are required, so "Find what a change could
            # break" stays clean.
            rf"^\s*(?:{VERB})\b.*\b(?:{TEMPORAL})\b",
            # defers the verb: "the loop to follow when", "to be run prior to"
            rf"\bto (?:be )?(?:{VERB})\w*\s+(?:\w+\s+)??(?:{TEMPORAL})\b",
        ))
        if re.search(trigger, desc, re.I):
            fail(f"{name}: user-invoked, but the description names a trigger condition",
                 [desc,
                  "Cursor does not read disable-model-invocation, so this line is",
                  "all that stops the skill firing on its own there. Make it a noun",
                  "phrase naming what the skill produces, with no clause saying",
                  "when to run it."])
    else:
        model_invoked.append(name)

    refs = os.path.join(REPO, rel, "references")
    if os.path.isdir(refs):
        for root, subdirs, names in os.walk(refs):
            subdirs[:] = [d for d in subdirs if not d.startswith(".")]
            for n in sorted(n for n in names if not n.startswith(".")):
                link = os.path.relpath(os.path.join(root, n), os.path.join(REPO, rel))
                if not re.search(rf"\]\((?:\./)?{re.escape(link)}\)", body):
                    fail(f"{name}: {link} has no Markdown link in SKILL.md",
                         [f"Mentioning the path is not enough. Link it as "
                          f"[...]({link}) with a line saying when to read it."])

# ------------------------------------------------- always-on prose block

# Step 2 of Setup lives outside the repo, so this warns and never fails. A
# fresh clone, a CI run, and anyone else's machine all lack the file, and none
# of those are a reason to reject a commit.
if any(d == "plain-writing" for d in dirs):
    config = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
    claude_md = os.path.join(config, "CLAUDE.md")
    if not os.path.isfile(claude_md):
        warn(f"no {claude_md}, so step 2 of Setup is not done here. "
             "plain-writing reaches commit messages but not chat replies.")
    else:
        try:
            if "plain-writing" not in open(
                    claude_md, encoding="utf-8", errors="replace").read():
                warn(f"{claude_md} does not mention plain-writing. "
                     "See step 2 of Setup in the README.")
        except OSError as exc:
            warn(f"could not read {claude_md}: {exc}")

# -------------------------------------------------------- context budget

print("== context budget ==")
if len(model_invoked) > 5:
    fail(f"{len(model_invoked)} model-invoked skills, the cap is five",
         [", ".join(model_invoked)])
else:
    print(f"ok    {len(model_invoked)} model-invoked skills")

# --------------------------------------------------------------- report

print()
for msg in warnings:
    print(f"warn  {msg}")
for msg, detail in failures:
    print(f"FAIL  {msg}")
    for d in detail:
        print(f"        {d}")

print()
if failures:
    print(f"{len(failures)} failure(s). Fix them above.")
    sys.exit(1)
print("Checks 1 to 9 passed. Now read the skill and answer 10 to 13 under")
print("'Before committing' in WRITING-RULES.md. No script can judge those.")
