#!/usr/bin/env python3
"""Keeps the ledger of where real macOS differed from what Arbor's stand-ins or tests expected, and writes docs/REALITY.md from it.

    scripts/reality-ledger.py              check collab/reality.json, print the counts, rewrite docs/REALITY.md
    scripts/reality-ledger.py --check      also fail if docs/REALITY.md is out of date (`make lint`, CI)
    scripts/reality-ledger.py --rings [f]  print what ring 2 of docs/VIABLE.md asks of this ledger, or put it into the rings.json named
    scripts/reality-ledger.py --self-test  situations that must come out as failures

collab/reality.json holds one entry for every known case. An entry says what was expected, what happened, how it was found, whether the
stand-ins (Sources/ArborTesting, Sources/arbor-fakemac, Sources/arbor-sim) can do the same by now, and what would go red if Arbor forgot
it again. A ledger rots when the things it names are renamed or deleted, so every name in an entry is looked up, in code and not in comments:

    knobs    `Type.member`: a stand-in declares or extends the type, and the member between its braces. Or a name alone: a type, or a function
             or a value that belongs to no type
    guards   `test: name`      an `@Test` of that name under Tests/ that is not disabled
             `scenario: file`  a *.sim in collab/scenarios
             `trace: file`     a *.jsonl in collab/evidence/traces, or the *.expect beside one
             `e2e: words`      at least eight characters out of a text in quotes in Sources/arbor-e2e or scripts/mac-shell/*.sh, on a line that
                               can fail (not one that only observes): a step or a check on real windows
             `tool: file`      a file under scripts/
    copes    `open`, or words that begin with a file in the repository, or with `Type.member` or a type declared anywhere under Sources/
    sources  files in the repository, without line numbers, which rot
    backlog  numbers that collab/BACKLOG.md has
    touches  ids of the detectors a person's trouble would set off: the first column of the table in docs/VIABLE.md, section 5

**Your lint failed and you never touched the ledger?** You reworded a step, or renamed a test, a switch of a stand-in or a file, that a case names. That
is wanted: it keeps the ledger true. Under every ✘ a line that begins with → says which field of which case to change, and to what.

What goes red BY ITSELF is worked out, not kept by hand: a test (one for macOS alone needs CI's Mac), a scenario, a trace, a tool or a real-window
runner that .github/workflows/ci.yml or the Makefile's `check` and `lint` start, directly or through a script they start. A step of any other Mac shell
script, and any other tool, guards only when somebody starts it, and the page says "by hand".

The preface and the afterword are prose and are copied as they stand, but for the files they name in backticks, which must exist.

Ring 2 of docs/VIABLE.md asks that no open row of this ledger touches a detector. A case counts there when it names a detector and Arbor does not cope
yet, or it crosses the seam and the stand-ins play it partly or not at all: then the walks on Linux cannot vouch for that detector. `--rings` prints
`{"stand_ins": {"commit": …, "open_divergences_that_touch_a_detector": n}}`, each case counted once, which is what scripts/mac-shell/viable.py reads from a
rings.json; given a file it puts that key into it and keeps the others. It refuses while the ledger differs from the commit it would name.

Exit code 1 if a name is not found or, with --check, the page does not say what reality.json says; 2 if reality.json itself is wrong. A page whose
counts have moved only because the rest of the repository has (CI starts another script, the gate has a new detector) gets a note, so that nobody's lint
fails on it: that part of the page lies between two comments, and --check leaves it out.
"""
import argparse
import collections
import contextlib
import difflib
import glob
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

KINDS = collections.OrderedDict([
    ("order-of-reports", "Order of reports: what belongs together arrives in another order than expected"),
    ("missing-report", "Missing reports: something happens and nobody says so"),
    ("extra-report", "Reports nobody expected: said twice, said of things that are no windows, said when nothing happened"),
    ("late-or-partial-answer", "Late or partial answers: a call returns before the deed, after it, with half of it, or with something else"),
    ("second-actor", "A second actor: macOS, an app or another tool moves things too"),
    ("geometry", "Geometry: displays, bars, sizes and coordinates that are not what was assumed"),
    ("identity", "Identity: what counts as a window, an app or a display, and whether it is the same one as before"),
    ("permissions", "Permissions: what macOS allows, to whom, and how it says no"),
    ("timing", "Timing: how long things take, and what can happen meanwhile"),
    ("input", "Input: where presses, keys and gestures really go"),
    ("looks", "Looks: what is on the screen is not what the model said"),
    ("never-exercised", "Never exercised: what ships switched on, or within reach, and has never had a key pressed or a hand laid on it on a real Mac"),
    ("toolchain", "Toolchain and machines: compilers, runners and shells that differ from the ones at hand"),
])
LAYERS = collections.OrderedDict([
    ("below the seam", "in the macOS-only code under the platform protocols (AX, Input, UI, App), which no test on Linux runs"),
    ("at the seam", "in what crosses the platform protocols: a stand-in can play it to the controller"),
    ("controller", "in the controller or the core, given reports that were right"),
    ("test", "in a test, a script or a harness that expected the wrong thing"),
    ("machine", "in the machine, the toolchain or the way things are built and installed"),
])
MODELLED = ["yes", "partly", "no", "cannot"]
HURT = {
    1: "a window lost, hidden or stuck; input blocked; something moved that the person did not move",
    2: "a visible jolt, the wrong window, a wrong view",
    3: "cosmetic, or a nuisance with an easy way out",
    4: "only tests, tools and the people who run them",
}
TEXTS = ["id", "kind", "layer", "expected", "happened", "found", "modelled", "copes"]
LISTS = ["knobs", "guards", "sources"]
STAND_INS = ("Sources/ArborTesting/*.swift", "Sources/arbor-fakemac/*.swift", "Sources/arbor-sim/*.swift")
# How well an entry is guarded, best first. Every entry is in exactly one.
WATCHES = collections.OrderedDict([
    ("linux", "Guarded without a Mac"),
    ("mac", "Guarded only on CI's Macs"),
    ("hand", "Only when somebody starts a script"),
    ("none", "Not guarded"),
])

TYPE = re.compile(r"\b(?:class|struct|enum|protocol|actor|extension|typealias)\s+`?([A-Za-z_]\w*)")
MEMBER = re.compile(r"\b(?:var|let|func|typealias|class|struct|enum|protocol|actor)\s+`?([A-Za-z_]\w*)")
CASES = re.compile(r"\b((?:if|guard|for|while)\s+)?case\s+([^\n{}]+)")
TEST = re.compile(r"@Test\b(\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\))?\s*(?:@\w+\s+)*(?:\w+\s+)*?func\s+`?(\w+)\s*\(")
QUOTED = re.compile(r'"((?:[^"\\]|\\.)*)"')
NAME = re.compile(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?")
FILE_IN_PROSE = re.compile(r"`([\w+./-]+\.(?:swift|sh|py|md|json|jsonl|yml|txt|sim|expect|m))`")


def without_comments(text, hash_too=False):
    """The code of a Swift file or a shell script. A `//` or `#` inside a text in quotes stays."""
    kept = []
    text = re.sub(r"/\*.*?\*/", lambda match: "\n" * match.group(0).count("\n"), text, flags=re.DOTALL) if not hash_too else text
    mark = "#" if hash_too else "//"
    for line in text.split("\n"):
        if mark not in line:
            kept.append(line)
            continue
        quoted, index = False, 0
        while index < len(line):
            character = line[index]
            if character == "\\":
                index += 1
            elif character == '"':
                quoted = not quoted
            elif not quoted and (line.startswith("//", index) if not hash_too else character == "#" and (index == 0 or line[index - 1].isspace())):
                line = line[:index]
                break
            index += 1
        kept.append(line)
    return "\n".join(kept)


class Tree:
    """What the names in the ledger are looked up in. Each file is read once."""

    def __init__(self, root):
        self.root = root
        self.indexes = {}
        self.cache = {}

    def paths(self, *patterns):
        return [path for pattern in patterns for path in sorted(glob.glob(os.path.join(glob.escape(self.root), pattern), recursive=True)) if os.path.isfile(path)]

    def read(self, path):
        if path not in self.cache:
            try:
                with open(path, encoding="utf-8", errors="replace") as file:
                    self.cache[path] = file.read()
            except OSError:
                self.cache[path] = ""
        return self.cache[path]

    def words(self, path):
        if ("words", path) not in self.indexes:
            self.indexes[("words", path)] = set(re.findall(r"\w+", self.read(os.path.join(self.root, path))))
        return self.indexes[("words", path)]

    def is_file(self, path):
        """A file inside the repository, named from its root."""
        return bool(path) and not os.path.isabs(path) and ".." not in path.split("/") and os.path.isfile(os.path.join(self.root, path))

    def index(self, patterns):
        """What each type declares between its braces, in all its declarations and extensions in these files; what a type inside it declares
        counts for both. Under "" what the files declare outside every brace."""
        if patterns not in self.indexes:
            found = collections.defaultdict(set)
            for path in self.paths(*patterns):
                # Braces in texts are no braces. Texts of several lines first, then what is left on one line, from the inside out for `"\("…")"`.
                code = re.sub(r'""".*?"""', '""', without_comments(self.read(path)), flags=re.DOTALL).replace('\\"', "")
                for _ in range(3):
                    code = re.sub(r'"[^"\n]*"', "", code)
                closes, open_at, outside, last = {}, [], [], 0
                for brace in re.finditer(r"[{}]", code):
                    if brace.group() == "{":
                        if not open_at:
                            outside.append(code[last:brace.start()])
                        open_at.append(brace.start())
                    elif open_at:
                        closes[open_at.pop()] = brace.start()
                        if not open_at:
                            last = brace.end()
                found[""].update(MEMBER.findall("\n".join(outside + [code[last:]])))
                for match in TYPE.finditer(code):
                    found[match.group(1)]
                    start = code.find("{", match.end())
                    # A typealias has no body: the next brace is somebody else's.
                    if start not in closes or match.group(0).startswith("typealias"):
                        continue
                    body = code[start:closes[start]]
                    found[match.group(1)].update(MEMBER.findall(body))
                    for before, cases in CASES.findall(body):
                        # `case a, b(Int)` declares; `case .a:`, `case let x` and `if case` match.
                        plain = re.sub(r"\([^()]*\)|=[^,]*", "", cases)
                        if not before and ":" not in plain and not plain.lstrip().startswith((".", "let ", "var ")):
                            found[match.group(1)].update(re.findall(r"(?:^|,)\s*`?([A-Za-z_]\w*)", plain))
            self.indexes[patterns] = found
        return self.indexes[patterns]

    def declares(self, name, patterns):
        """`Type.member`: Type declares member in one of these files. A name alone: a type, or a function or a value that belongs to no type."""
        if not NAME.fullmatch(name):
            return False
        kind, _, member = name.partition(".")
        index = self.index(patterns)
        return member in index[kind] if member and kind in index else not member and (kind in index or kind in index[""])

    def names(self, patterns):
        """Everything `declares` would say yes to in these files, spelt as a case would spell it."""
        index = self.index(patterns)
        return {kind for kind in index if kind} | index[""] | {f"{kind}.{member}" for kind, members in index.items() if kind for member in members}

    def files(self):
        """Every file a case or the prose may name, from the root."""
        if "files" not in self.indexes:
            found = self.paths("Sources/**/*", "scripts/**/*", "docs/**/*", "collab/**/*", "Tests/**/*", "*", ".github/**/*")
            self.indexes["files"] = sorted(os.path.relpath(path, self.root) for path in found)
        return self.indexes["files"]

    def detectors(self):
        """The ids of the viable gate's detectors, in the page's order: the first column, in backticks, of the first table of docs/VIABLE.md's section 5.
        None where there is no such page or table: then nobody can say which ids there are."""
        if "detectors" not in self.indexes:
            section = re.search(r"^## 5\.[^\n]*\n(.*?)(?=^## |\Z)", self.read(os.path.join(self.root, "docs", "VIABLE.md")), re.MULTILINE | re.DOTALL)
            rows = re.search(r"(?:^\|[^\n]*\n?)+", section.group(1), re.MULTILINE) if section else None
            self.indexes["detectors"] = (re.findall(r"^\| *`([\w-]+)` *\|", rows.group(0), re.MULTILINE) if rows else []) or None
        return self.indexes["detectors"]

    def tests(self):
        """The tests that run everywhere, and those compiled or enabled on macOS alone."""
        if "tests" not in self.indexes:
            everywhere, mac, self.indexes["disabled"] = set(), set(), set()
            for path in self.paths("Tests/**/*.swift"):
                compiled, kept = [], {True: [], False: []}
                for line in without_comments(self.read(path)).split("\n"):
                    word = line.strip()
                    if word.startswith("#if"):
                        compiled.append("mac" if re.search(r"(?<!!)(os\(macOS\)|canImport\((AppKit|Carbon|QuartzCore|SwiftUI|ApplicationServices)\))", word) else "both")
                    elif word.startswith("#else") and compiled:
                        compiled[-1] = "linux" if compiled[-1] == "mac" else "both"
                    elif word.startswith("#endif") and compiled:
                        compiled.pop()
                    else:
                        kept["mac" in compiled].append(line)
                for only_mac, lines in kept.items():
                    for arguments, name in TEST.findall("\n".join(lines)):
                        (self.indexes["disabled"] if ".disabled" in arguments else mac if only_mac else everywhere).add(name)
            self.indexes["tests"] = (everywhere, mac - everywhere)
        return self.indexes["tests"]

    def started(self):
        """The text of everything that CI or `make check` starts: the workflow, the rules of `check` and `lint` and of the targets the workflow
        makes, and the scripts those name, and the scripts these name in turn."""
        if "started" not in self.indexes:
            workflow = without_comments(self.read(os.path.join(self.root, ".github", "workflows", "ci.yml")), hash_too=True)
            makefile = self.read(os.path.join(self.root, "Makefile"))
            targets = {"check", "lint"} | set(re.findall(r"\bmake ([\w-]+)", workflow))
            text, done = workflow, set()
            while targets - done:
                target = (targets - done).pop()
                done.add(target)
                if rule := re.search(rf"^{re.escape(target)}:([^\n]*)\n((?:\t[^\n]*\n?)*)", makefile, re.MULTILINE):
                    targets |= set(rule.group(1).split())
                    text += "\n" + without_comments(rule.group(2), hash_too=True)
            seen, scripts = set(), {os.path.relpath(path, self.root): path for path in self.paths("scripts/*", "scripts/*/*")}
            for _ in range(3):
                for name in set(re.findall(r"(?:^|[\s\"'=(@;&|])(?:\./)?(scripts/[\w+./-]*\w)", text, re.MULTILINE)) & set(scripts) - seen:
                    seen.add(name)
                    if name.endswith((".sh", ".py")):
                        text += "\n" + without_comments(self.read(scripts[name]), hash_too=True)
            self.indexes["started"] = (text, seen)
        return self.indexes["started"]

    def steps(self, by_itself):
        """Every text in quotes on a line of a real-window runner that can fail: all runners, or those that are started by themselves."""
        key = ("steps", by_itself)
        if key not in self.indexes:
            text, scripts = self.started()
            runners = self.paths("scripts/mac-shell/*.sh")
            if by_itself:
                runners = [path for path in runners if os.path.relpath(path, self.root) in scripts]
            # scripts/e2e.sh is what runs arbor-e2e.
            if not by_itself or "scripts/e2e.sh" in scripts or "arbor-e2e" in text:
                runners += self.paths("Sources/arbor-e2e/*.swift")
            found = []
            for path in runners:
                for line in without_comments(self.read(path), hash_too=path.endswith(".sh")).split("\n"):
                    if '"' in line and not ("observe" in line and re.search(r"\bobserve\b", line)):
                        found += QUOTED.findall(line)
            self.indexes[key] = "\n".join(found)
        return self.indexes[key]


def watch(guard, tree):
    """How a guard that was found goes red: on `linux` and everywhere, only on CI's `mac`, or by `hand`."""
    sort, _, name = guard.partition(": ")
    if sort == "test":
        return "linux" if name in tree.tests()[0] else "mac"
    if sort == "e2e":
        return "mac" if name in tree.steps(by_itself=True) else "hand"
    if sort == "tool":
        return "linux" if os.path.join("scripts", name) in tree.started()[1] else "hand"
    return "linux"


def watch_of(entry, tree):
    kinds = {watch(guard, tree) for guard in entry["guards"]}
    return next((kind for kind in WATCHES if kind in kinds), "none")


def nearest(name, among, before=" (the nearest there is: ", after=")"):
    """Words for a remedy: what the name was probably changed to, or nothing where nothing is close."""
    close = difflib.get_close_matches(name, sorted(among), n=1, cutoff=0.6)
    return f"{before}{close[0]}{after}" if close else ""


def moved(path, tree):
    """The same for a file: one of that name in another folder, or one in any folder whose name is close."""
    same = [file for file in tree.files() if os.path.basename(file) == os.path.basename(path)]
    return f" (there is {same[0]})" if same else nearest(path, tree.files())


def problems_of(entry, tree):
    """What is wrong with the names one entry gives: what to say, the field to change, and what to put there."""
    found = []
    unguarded = "or take the guard out if nothing checks this any more"
    a_guard = "write `test: `, `scenario: `, `trace: `, `e2e: ` or `tool: ` and then the name"
    for knob in entry["knobs"]:
        if not tree.declares(knob, STAND_INS):
            found.append((
                f"knob `{knob}`: no stand-in declares it (write `Type.member`, or the name of a type or of a function that belongs to none)", "knobs",
                f"put the switch's or the helper's new name{nearest(knob, tree.names(STAND_INS))}, or take it out if no stand-in plays this any more and set “modelled” to match"))
    for guard in entry["guards"]:
        sort, _, name = guard.partition(": ")
        if not name.strip():
            found.append((f"a guard is `test: `, `scenario: `, `trace: `, `e2e: ` or `tool: ` and a name, not “{guard}”", "guards", a_guard))
        elif sort == "test":
            if name not in tree.tests()[0] | tree.tests()[1]:
                if name in tree.indexes["disabled"]:
                    found.append((f"the test `{name}` is disabled", "guards", "take the guard out for as long as the test does not run, or name a test that does"))
                else:
                    found.append((f"there is no test `{name}`", "guards", f"put the test's new name{nearest(name, tree.tests()[0] | tree.tests()[1])}, {unguarded}"))
        elif sort == "scenario":
            if not name.endswith(".sim") or not tree.is_file(f"collab/scenarios/{name}"):
                there = {os.path.basename(file) for file in tree.files() if file.startswith("collab/scenarios/") and file.endswith(".sim")}
                found.append((f"there is no scenario {name}", "guards", f"put the scenario's new name, a *.sim in collab/scenarios{nearest(name, there)}, {unguarded}"))
        elif sort == "trace":
            recording = name[:-len(".expect")] + ".jsonl" if name.endswith(".expect") else name
            if not recording.endswith(".jsonl") or not all(tree.is_file(f"collab/evidence/traces/{file}") for file in {name, recording}):
                there = {os.path.basename(file) for file in tree.files() if file.startswith("collab/evidence/traces/") and file.endswith(".jsonl")}
                found.append((f"there is no trace {name}", "guards", f"put the recording's new name, a *.jsonl in collab/evidence/traces{nearest(recording, there)}, {unguarded}"))
        elif sort == "e2e":
            if len(name) < 8 or name not in tree.steps(by_itself=False):
                close = nearest(name, set(tree.steps(by_itself=False).split("\n")), " (the nearest there is: “", "”)")
                found.append((
                    f"no real-window runner has a step or a check with the words “{name}”", "guards",
                    f"put words from the new step or check, eight characters or more out of its quotes{close}, {unguarded}"))
        elif sort == "tool":
            if not tree.is_file(f"scripts/{name}"):
                there = {file[len("scripts/"):] for file in tree.files() if file.startswith("scripts/")}
                found.append((f"there is no scripts/{name}", "guards", f"put the tool's new name, from scripts/ on{nearest(name, there)}, {unguarded}"))
        else:
            found.append((f"a guard is `test: `, `scenario: `, `trace: `, `e2e: ` or `tool: ` and a name, not “{guard}”", "guards", a_guard))
    if entry["copes"] != "open":
        first = entry["copes"].split()[0].rstrip(":,;")
        uncured = "or write “open” and nothing more if Arbor no longer copes"
        if "/" in first:
            if not tree.is_file(first):
                found.append((f"copes: there is no {first}", "copes", f"begin with the file that holds the cure now{moved(first, tree)}, {uncured}"))
        elif not (first[:1].isupper() or "." in first) or not tree.declares(first, ("Sources/**/*.swift",)):
            close = nearest(first, tree.names(("Sources/**/*.swift",))) if NAME.fullmatch(first) and (first[:1].isupper() or "." in first) else ""
            found.append((
                f"copes: it is `open`, or begins with a file, or with `Type.member` or a type declared under Sources/, not with “{first}”", "copes",
                f"begin with the `Type.member`, the type or the file that holds the cure now{close}, {uncured}"))
    for source in entry["sources"]:
        if not tree.is_file(source):
            found.append((
                f"source: there is no file {source} (no line numbers: they rot)", "sources",
                f"put the file's new place, from the repository's root{moved(source.partition(':')[0], tree)}, or another file that tells of this"))
    for number in entry.get("backlog", []):
        if number not in tree.words("collab/BACKLOG.md"):
            found.append((f"collab/BACKLOG.md has no {number}", "backlog", "put the number the backlog has for this now, or take it out"))
    if entry["modelled"] in ("yes", "partly") and not entry["knobs"]:
        found.append((f"modelled “{entry['modelled']}” but no knob is named", "knobs", "name the switch or the helper of a stand-in that plays this, or set “modelled” to “no”"))
    if entry["modelled"] == "cannot" and entry["layer"] == "at the seam":
        found.append((
            "what crosses the seam can be played by a stand-in: that it “cannot” be is for what lies below or beside it", "modelled",
            "put “no” if a stand-in could play this and does not, or change “layer” if it does not cross the seam"))
    return found


MISSING = "## Evidence that is cited and is not in the repository"


def prose_problems(data, tree):
    """Files the preface and the afterword name that are not there; a name without a folder is looked for everywhere. Under the heading for what is
    cited and missing it is the other way round: a file that has turned up has no business there."""
    names = {os.path.basename(path) for path in tree.files()}
    found = set()
    for part in ("preface", "afterword"):
        heading = ""
        for line in data.get(part, []):
            heading = line.strip() if line.startswith("## ") else heading
            for name in FILE_IN_PROSE.findall(line):
                there = tree.is_file(name) if "/" in name else name in names
                if heading == MISSING:
                    # Each item begins with what is missing; the files that cite it follow.
                    if there and line.lstrip("-* ").startswith(f"`{name}`"):
                        found.add((f"{part}: {name} is listed as missing and is there", part, "take the item out from under that heading"))
                elif not there and os.path.basename(name) not in names:
                    found.add((f"{part}: there is no file {name}", part, f"put the file's new name{nearest(name, tree.files() if '/' in name else names)}, or take the mention out"))
    return sorted(found)


def shape_problems(data, detectors=None):
    """What is wrong with the file itself. `detectors`: the ids “touches” may name, or None where nobody can say."""
    if not isinstance(data, dict):
        return ["the file holds an object with “preface”, “entries” and “afterword”"]
    found, seen = [], set()
    if unknown := set(data) - {"preface", "entries", "afterword"}:
        found.append(f"unknown keys at the top: {sorted(unknown)}")
    for key in ("preface", "entries"):
        if key not in data:
            found.append(f"no “{key}” at the top")
    for key in ("preface", "afterword"):
        if not (isinstance(data.get(key, []), list) and all(isinstance(line, str) for line in data.get(key, []))):
            found.append(f"“{key}” is a list of lines")
    if not isinstance(data.get("entries", []), list):
        return found + ["“entries” is a list"]
    for index, entry in enumerate(data.get("entries", [])):
        if not isinstance(entry, dict):
            found.append(f"entry {index + 1} is no object")
            continue
        name = entry["id"] if isinstance(entry.get("id"), str) and entry["id"] else f"entry {index + 1}"
        for key in TEXTS:
            if not isinstance(entry.get(key), str) or not entry[key].strip():
                found.append(f"{name}: “{key}” is a text, and not an empty one")
        for key in LISTS + ["backlog", "touches"]:
            value = entry.get(key, [] if key in ("backlog", "touches") else None)
            if not isinstance(value, list) or not all(isinstance(item, str) and item.strip() for item in value):
                found.append(f"{name}: “{key}” is a list of texts, none of them empty")
        if entry.get("certainty", "suspected") != "suspected":
            found.append(f"{name}: “certainty” is left out or is “suspected”")
        touches = [item for item in entry.get("touches", []) if isinstance(item, str)] if isinstance(entry.get("touches", []), list) else []
        for item in touches if detectors is not None else []:
            if item not in detectors:
                found.append(
                    f"{name}: “touches” names a detector of docs/VIABLE.md, section 5, and “{item}” is none{nearest(item, detectors)}. They are: {', '.join(detectors)}. "
                    "Put the detector's new id, or take it out; then python3 scripts/reality-ledger.py and commit both files")
        if len(set(touches)) != len(touches):
            found.append(f"{name}: “touches” names a detector twice")
        if unknown := set(entry) - set(TEXTS) - set(LISTS) - {"hurt", "backlog", "certainty", "touches"}:
            found.append(f"{name}: unknown keys {sorted(unknown)}")
        if name in seen:
            found.append(f"{name}: the id is taken")
        seen.add(name)
        if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name):
            found.append(f"{name}: an id is small letters, digits and dashes")
        for key, allowed in (("kind", KINDS), ("layer", LAYERS), ("modelled", MODELLED)):
            if isinstance(entry.get(key), str) and entry[key] not in allowed:
                found.append(f"{name}: no such {key}: {entry[key]}")
        if type(entry.get("hurt")) is not int or entry["hurt"] not in HURT:
            found.append(f"{name}: hurt is 1, 2, 3 or 4")
        if isinstance(entry.get("copes"), str) and entry["copes"] != "open" and re.match(r"open\b", entry["copes"]):
            found.append(f"{name}: what Arbor does not cope with yet says “open” and nothing more")
    return found


def table(rows, header):
    lines = ["| " + " | ".join(header) + " |", "|" + "---|" * len(header)]
    return lines + ["| " + " | ".join(str(value).replace("|", "\\|").replace("\n", " ") for value in row) + " |" for row in rows]


def unvouched(entry):
    """Whether the walks on Linux cannot vouch for what this case touches: Arbor does not cope, or the stand-ins could play it to the controller and do not, or not wholly."""
    return entry["copes"] == "open" or (entry["layer"] == "at the seam" and entry["modelled"] in ("no", "partly"))


def ring_two(entries):
    """The rows ring 2 of docs/VIABLE.md counts, each once."""
    return [entry for entry in entries if entry.get("touches") and unvouched(entry)]


# What lies between these two on the page is worked out from the rest of the repository as well as from reality.json.
WORKED_OUT = ("<!-- Worked out, from here on, from the rest of the repository too: --check leaves it out. -->", "<!-- Worked out, up to here. -->")
UNTRIED = "never-exercised"


def document(data, tree):
    entries = data["entries"]
    watched = {entry["id"]: watch_of(entry, tree) for entry in entries}
    count = lambda some, test: sum(1 for entry in some if test(entry))
    out = ["<!-- Generated by scripts/reality-ledger.py from collab/reality.json. Do not edit by hand. -->", ""]
    out += data["preface"] + [""]

    out += [WORKED_OUT[0], "", "## The count", ""]
    rows = []
    for kind in KINDS:
        if of_kind := [entry for entry in entries if entry["kind"] == kind]:
            rows.append(
                [f"[{kind}](#{kind})", len(of_kind), count(of_kind, lambda e: e["hurt"] == 1)]
                + [count(of_kind, lambda e, m=m: e["modelled"] == m) for m in MODELLED]
                + [count(of_kind, lambda e, w=w: watched[e["id"]] == w) for w in WATCHES] + [count(of_kind, lambda e: e["copes"] == "open")])
    rows.append(["**all**"] + [sum(row[column] for row in rows) for column in range(1, 12)])
    out += table(rows, ["Kind", "Cases", "Hurt 1", "Stand-ins play it", "partly", "not yet", "cannot"] + list(WATCHES.values()) + ["Arbor does not cope yet"])
    out += ["", "**Where the difference bit**", ""]
    rows = []
    for layer, meaning in LAYERS.items():
        of_layer = [entry for entry in entries if entry["layer"] == layer]
        rows.append(
            [layer, meaning, len(of_layer), count(of_layer, lambda e: e["hurt"] <= 2)] + [count(of_layer, lambda e, w=w: watched[e["id"]] == w) for w in WATCHES])
    out += table(rows, ["Where", "That is", "Cases", "Hurt 1 or 2"] + list(WATCHES.values()))
    out += [
        "", "Each case is counted under the best guard it has: one that goes red on any machine (a test, a scenario, a replayed trace, a tool that `make check` or CI runs), "
        "one that needs CI's Macs (a test for macOS alone, a step of a real-window run that CI starts), one that somebody has to start, or none.",
        "", "Hurt: " + "; ".join(f"**{level}** {meaning}" for level, meaning in HURT.items()) + ".", ""]

    def listing(title, words, some):
        some = sorted(some, key=lambda e: (e["hurt"], list(WATCHES)[::-1].index(watched[e["id"]]), e["id"]))
        rows = [[f"[{e['id']}](#{e['id']})", e["hurt"], e["layer"], e["modelled"], WATCHES[watched[e["id"]]].lower()] for e in some]
        return [f"### {title}", "", words, ""] + table(rows, ["Case", "Hurt", "Where", "Stand-ins play it", "Guard"]) + [""]

    hurts = [entry for entry in entries if entry["hurt"] <= 2]
    out += ["## What to do first", "", "Only cases that hurt a person (1 or 2).", ""]
    out += listing("Arbor does not cope yet", "A fault that is known and open.", [e for e in hurts if e["copes"] == "open" and e["kind"] != UNTRIED])
    if untried := [e for e in hurts if e["copes"] == "open" and e["kind"] == UNTRIED]:
        out += listing("Nobody knows whether Arbor copes", "Within reach as Arbor ships, and never tried on a real Mac: see [never-exercised](#never-exercised).", untried)
    out += listing(
        "Arbor copes, and nothing would notice if it stopped", "No guard, or only a script that somebody has to start.",
        [e for e in hurts if e["copes"] != "open" and watched[e["id"]] in ("hand", "none")])
    out += listing(
        "The stand-ins could play it and do not", "So no test on Linux can meet it. (Those they play partly are not listed: see each kind.)",
        [e for e in hurts if e["modelled"] == "no"])

    counted = ring_two(entries)
    detectors = tree.detectors() or sorted({detector for entry in counted for detector in entry["touches"]})
    rows = []
    for detector in detectors:
        some = sorted((e for e in counted if detector in e["touches"]), key=lambda e: (e["copes"] != "open", e["hurt"], e["id"]))
        rows.append([f"`{detector}`", len(some), ", ".join(f"**[{e['id']}](#{e['id']})**" if e["copes"] == "open" else f"[{e['id']}](#{e['id']})" for e in some) or "none"])
    out += [
        "## Ring 2: what the walks on Linux cannot vouch for", "",
        "The viable gate (`docs/VIABLE.md`, section 2) asks of this ledger that no open row touches one of the detectors of its section 5: with such a row open, ten thousand clean walks "
        "against the stand-ins say nothing about that detector. Each case says which detectors a person's trouble would set off (*touches*). It counts here when Arbor does not cope with "
        "it yet or nobody knows (**bold**), or when it crosses the seam and the stand-ins play it only partly or not at all. "
        f"{len(counted)} cases count, each once, however many detectors it touches: that is the number `scripts/reality-ledger.py --rings` hands to the gate.", ""]
    out += table(rows, ["Detector", "Cases", "Open or unplayed cases that touch it"])
    out += ["", f"{sum(1 for row in rows if not row[1])} of the {len(rows)} detectors have none.", "", WORKED_OUT[1], ""]

    for kind, title in KINDS.items():
        of_kind = sorted((entry for entry in entries if entry["kind"] == kind), key=lambda e: (e["hurt"], e["id"]))
        if not of_kind:
            continue
        out += [f"## {kind}", "", title + ".", ""]
        for entry in of_kind:
            tags = [f"hurt {entry['hurt']}", entry["layer"]] + ([entry["certainty"]] if entry.get("certainty") else []) + entry.get("backlog", [])
            tags += ["touches " + ", ".join(f"`{detector}`" for detector in entry["touches"])] if entry.get("touches") else []
            says = {"yes": "yes", "partly": "partly", "no": "**no**", "cannot": "cannot: it lies below or beside the seam"}[entry["modelled"]]
            knobs = ", ".join(f"`{knob}`" for knob in entry["knobs"])
            marks = {"linux": "", "mac": " (on CI's Macs)", "hand": " (by hand)"}
            guards = [f"`{guard}`{marks[watch(guard, tree)]}" for guard in entry["guards"]]
            out += [
                f"### {entry['id']}", "", "*" + " · ".join(tags) + "*", "",
                f"- **Expected:** {entry['expected']}", f"- **Happened:** {entry['happened']}", f"- **Found by:** {entry['found']}",
                f"- **Stand-ins play it:** {says}" + (f" ({knobs})" if knobs else ""),
                "- **Guard:** " + ("; ".join(guards) if guards else "**none**"),
                "- **Arbor copes:** " + (("**nobody knows**" if kind == UNTRIED else "**not yet**") if entry["copes"] == "open" else entry["copes"]),
                "- **Read in:** " + ", ".join(f"`{source}`" for source in entry["sources"]), ""]
    out += data.get("afterword", [])
    return "\n".join(out).rstrip("\n") + "\n"


def settled(page):
    """The page without what is worked out from the rest of the repository: the counts, the lists of what to do first, ring 2, and how each guard goes red."""
    head, _, rest = page.partition(WORKED_OUT[0])
    return head + re.sub(r"(?<=`) \((?:by hand|on CI's Macs)\)", "", rest.partition(WORKED_OUT[1])[2])


def load(root):
    """The ledger and the tree it is looked up in, or None and what is wrong with the file."""
    path = os.path.join(root, "collab", "reality.json")
    tree = Tree(root)
    try:
        with open(path, encoding="utf-8") as file:
            data = json.load(file)
    except (OSError, ValueError) as error:
        return None, tree, [f"{path}: {error}"]
    return data, tree, shape_problems(data, tree.detectors())


def head_of(root):
    """The commit the ledger belongs to, or None and why not."""
    def git(*words):
        return subprocess.run(["git", "-C", root, *words], capture_output=True, text=True, check=True).stdout.strip()
    try:
        if changed := git("status", "--porcelain", "--", "collab/reality.json", "docs/VIABLE.md"):
            return None, f"what is counted would not be the commit's: commit first ({' '.join(changed.split())})"
        return git("rev-parse", "HEAD"), ""
    except (OSError, subprocess.CalledProcessError) as error:
        return None, f"git does not say which commit this is: {error}"


def rings(root, target, head=head_of):
    """What scripts/mac-shell/viable.py reads about ring 2 from a rings.json: printed, or put into the file named beside what other rings have put there."""
    data, _, wrong = load(root)
    commit, why = head(root)
    for line in wrong + ([why] if not commit else []):
        print(f"reality-ledger: {line}")
    if wrong or not commit:
        return 2
    told = {}
    if target and os.path.exists(target):
        try:
            with open(target, encoding="utf-8") as file:
                told = json.load(file)
        except (OSError, ValueError) as error:
            told = error
        if not isinstance(told, dict):
            print(f"reality-ledger: {target} holds no object, and is left as it is: {told}")
            return 2
    told["stand_ins"] = {"commit": commit, "open_divergences_that_touch_a_detector": len(ring_two(data["entries"]))}
    if target:
        with open(target, "w", encoding="utf-8") as file:
            json.dump(told, file, indent=1)
            file.write("\n")
    print(json.dumps({"stand_ins": told["stand_ins"]}))
    return 0


def run(root, check):
    data, tree, wrong = load(root)
    if wrong:
        for line in wrong:
            print(f"reality-ledger: {line}")
        return 2
    code = 0
    for name, problems in [(entry["id"], problems_of(entry, tree)) for entry in data["entries"]] + [(None, prose_problems(data, tree))]:
        for problem, field, remedy in problems:
            print(f"✘ {name or 'the prose'}: {problem}")
            print("  → collab/reality.json, " + (f'case "{name}", ' if name else "") + f'"{field}": {remedy}; then python3 scripts/reality-ledger.py and commit both files')
            code = 1
    text = document(data, tree)
    target = os.path.join(root, "docs", "REALITY.md")
    current = tree.read(target) if os.path.exists(target) else ""
    if check:
        if settled(current) != settled(text):
            print("✘ docs/REALITY.md is out of date: run scripts/reality-ledger.py and commit it")
            code = 1
        elif current != text:
            # Somebody else's change (a script that CI now starts, a test that moved under `#if os(macOS)`) is no reason to fail their lint.
            print("note: what guards what has moved since docs/REALITY.md was written; scripts/reality-ledger.py brings its counts up to date")
    elif current != text:
        with open(target, "w", encoding="utf-8") as file:
            file.write(text)
    entries = data["entries"]
    number = lambda test: sum(1 for entry in entries if test(entry))
    print(
        f"reality ledger: {len(entries)} cases; the stand-ins play {number(lambda e: e['modelled'] == 'yes')}, partly {number(lambda e: e['modelled'] == 'partly')}, "
        f"not yet {number(lambda e: e['modelled'] == 'no')}, out of their reach {number(lambda e: e['modelled'] == 'cannot')}; "
        f"{number(lambda e: watch_of(e, tree) in ('hand', 'none'))} that nothing guards by itself; {number(lambda e: e['copes'] == 'open' and e['kind'] != UNTRIED)} Arbor does not cope with yet, "
        f"{number(lambda e: e['kind'] == UNTRIED)} never exercised; {len(ring_two(entries))} open or unplayed that touch a detector")
    return code


def self_test():
    """A ledger that names what is not there, or counts a guard for more than it is, must not pass."""
    good = {
        "id": "a-case", "kind": "missing-report", "layer": "at the seam", "expected": "x", "happened": "y", "found": "z", "modelled": "yes",
        "knobs": ["Fake.knob"], "guards": ["test: aTest", "scenario: 01.sim", "trace: t.jsonl", "e2e: a step on real windows", "tool: t.py"],
        "copes": "Controller.copes does", "hurt": 1, "sources": ["docs/A.md"], "backlog": ["K7"]}
    files = {
        "Sources/ArborTesting/Fake.swift": "final class Fake {\n  var knob = 1 // and once there was a var gone\n  enum Manner { case polite, rude(Int) }\n}\nstruct Other { var elsewhere = 1 }\n"
                                           'func free() { let local = "}" }',
        "Sources/ArborKit/C.swift": "struct Controller { func copes() {} }\nfunc open() {}\nlet the = 1",
        "Tests/T/T.swift": '@Test func aTest() {}\n// @Test func commentedOut() {}\n@Test(.disabled("never")) func switchedOff() {}\nfunc helper() {}\n'
                           "#if os(macOS)\n@Test func onlyOnAMac() {}\n#endif\n@Test func theWindowComesBack() {}",
        "collab/scenarios/01.sim": "", "collab/scenarios/notes.md": "", "collab/evidence/traces/t.jsonl": "", "collab/evidence/traces/lonely.expect": "",
        "Sources/arbor-e2e/main.swift": 'step("a step on real windows")\n// step("a step that was taken out")\nobserve("a step that only looks on")',
        "scripts/mac-shell/check-F99.sh": 'step "a step somebody has to start"', "scripts/mac-shell/e2e-drag.sh": 'step "a drag that CI makes"',
        "scripts/t.py": "", "scripts/by-hand.py": "", "scripts/e2e.sh": ".build/debug/arbor-e2e", "docs/A.md": "", "collab/BACKLOG.md": "| K7 | a thing |",
        ".github/workflows/ci.yml": "run: ./scripts/e2e.sh\nrun: ./scripts/mac-shell/e2e-drag.sh\nrun: make lint\n# run: ./scripts/by-hand.py",
        "Makefile": "lint:\n\t@python3 scripts/t.py\n",
        "docs/VIABLE.md": "## 4. Across what\n\n| Value |\n|---|\n| `defaults` |\n\n## 5. The detectors\n\nWords.\n\n| Id | `FAIL` when |\n|---|---|\n| `lost` | a window is gone |\n| `jolt` | it moves twice |\n"
                          "| `focus` | the keyboard is elsewhere |\n\nMore words.\n\n| Control |\n|---|\n| `sabotage` |\n\n## 6. What an act may move\n\n| Act |\n|---|\n| `idle` |\n",
    }
    failures = []
    then = "; then python3 scripts/reality-ledger.py and commit both files\n"

    def situation(name, change, expected_code, said_words="", page_words="", top=None, without=()):
        with tempfile.TemporaryDirectory() as root:
            for path, text in files.items():
                if path in without:
                    continue
                os.makedirs(os.path.dirname(os.path.join(root, path)), exist_ok=True)
                with open(os.path.join(root, path), "w", encoding="utf-8") as file:
                    file.write(text)
            entry = json.loads(json.dumps(good))
            entries = [entry]
            change(entry, entries)
            data = {"preface": ["# Reality"], "entries": entries}
            data = top(data) if top else data
            with open(os.path.join(root, "collab", "reality.json"), "w", encoding="utf-8") as file:
                json.dump(data, file)
            said = io.StringIO()
            try:
                with contextlib.redirect_stdout(said):
                    code = run(root, check=False)
                    again = run(root, check=True) if code == 0 else 0
            except Exception as error:  # a traceback is no verdict
                code, again = f"{type(error).__name__}: {error}", 0
            page = open(os.path.join(root, "docs", "REALITY.md"), encoding="utf-8").read() if os.path.exists(os.path.join(root, "docs", "REALITY.md")) else ""
            if code != expected_code or said_words not in said.getvalue() or page_words not in page or again != 0:
                failures.append(f"{name}: exit {code} (wanted {expected_code}), check afterwards {again}; said {said.getvalue()!r}")
            # Whoever is told that something is wrong is told in the next line, and once, what to do about it.
            lines = said.getvalue().split("\n")
            for index, line in enumerate(lines[:-1]):
                if line.startswith("✘ ") != (lines[index + 1].startswith("  → collab/reality.json, ") and (lines[index + 1] + "\n").endswith(then)):
                    failures.append(f"{name}: a ✘ without its →, or a → without its ✘: {line!r}, {lines[index + 1]!r}")

    def sets(**values):
        return lambda entry, entries: entry.update(values)

    situation("a sound ledger passes, and the page it wrote is current", sets(), 0, "1 cases", "| at the seam | in what crosses")
    situation("a second case of an enum is a declaration too, and so is a function of no type", sets(knobs=["Manner.rude", "Fake.Manner", "Fake", "free"]), 0)
    for name, values, words in [
        ("a knob that was renamed, though a comment still has the word", {"knobs": ["Fake.gone"]}, "Fake.gone"),
        ("a member of another type", {"knobs": ["Fake.elsewhere"]}, "Fake.elsewhere"),
        ("a value inside a function", {"knobs": ["local"]}, "`local`"),
        ("a type nobody declares", {"knobs": ["NoSuchFake.knob"]}, "NoSuchFake"),
        ("a member without its type", {"knobs": ["knob"]}, "`knob`"),
        ("a knob of the real code, which is no stand-in", {"knobs": ["Controller.copes"]}, "Controller.copes"),
        ("a knob that ends in a full stop", {"knobs": ["Fake."]}, "Fake."),
        ("a test that was renamed", {"guards": ["test: noSuchTest"]}, "noSuchTest"),
        ("a test that was commented out", {"guards": ["test: commentedOut"]}, "commentedOut"),
        ("a test that was disabled", {"guards": ["test: switchedOff"]}, "switchedOff"),
        ("a helper that is no test", {"guards": ["test: helper"]}, "helper"),
        ("a scenario that was deleted", {"guards": ["scenario: 99.sim"]}, "99.sim"),
        ("a file beside the scenarios that no runner runs", {"guards": ["scenario: notes.md"]}, "notes.md"),
        ("a scenario outside the folder", {"guards": ["scenario: ../evidence/traces/t.jsonl"]}, "no scenario"),
        ("a trace that was deleted", {"guards": ["trace: no.jsonl"]}, "no.jsonl"),
        ("expectations whose recording is gone", {"guards": ["trace: lonely.expect"]}, "lonely.expect"),
        ("a step nobody runs", {"guards": ["e2e: another step altogether"]}, "another step"),
        ("a step that is only mentioned in a comment", {"guards": ["e2e: a step that was taken out"]}, "taken out"),
        ("a step that cannot fail", {"guards": ["e2e: a step that only looks on"]}, "looks on"),
        ("a few letters that occur everywhere", {"guards": ["e2e: a step"]}, "a step"),
        ("a tool that is gone", {"guards": ["tool: gone.py"]}, "gone.py"),
        ("a folder for a tool", {"guards": ["tool: mac-shell"]}, "mac-shell"),
        ("a guard of no known sort", {"guards": ["hope: it holds"]}, "hope"),
        ("a sort without a name", {"guards": ["test"]}, "“test”"),
        ("a cure that is not in the tree", {"copes": "Controller.vanished does"}, "vanished"),
        ("a cure in plain words", {"copes": "the controller waits"}, "“the”"),
        ("a cure in a file that is gone", {"copes": "Sources/ArborKit/Gone.swift waits"}, "Gone.swift"),
        ("a cure outside the repository", {"copes": "../../etc/passwd says"}, "passwd"),
        ("a source that is not in the tree", {"sources": ["docs/B.md"]}, "docs/B.md"),
        ("a source with a line number", {"sources": ["docs/A.md:3"]}, "line numbers"),
        ("a folder for a source", {"sources": ["docs"]}, "no file docs"),
        ("a backlog number nobody knows", {"backlog": ["K8"]}, "K8"),
        ("modelled, by nothing", {"knobs": []}, "no knob"),
        ("partly modelled, by nothing", {"knobs": [], "modelled": "partly"}, "no knob"),
        ("out of reach at the seam", {"modelled": "cannot", "knobs": []}, "below or beside"),
    ]:
        situation(name, sets(**values), 1, words)
    # What to do about it, in words a stranger can follow, with the name it was probably changed to where one is close.
    for name, values, words in [
        ("a renamed test is guessed at", {"guards": ["test: theWindowCameBack"]}, '  → collab/reality.json, case "a-case", "guards": put the test\'s new name (the nearest there is: theWindowComesBack), or take the guard out'),
        ("and not where nothing is close", {"guards": ["test: noSuchTest"]}, "put the test's new name, or take the guard out if nothing checks this any more" + then),
        ("a disabled test is called disabled", {"guards": ["test: switchedOff"]}, '`switchedOff` is disabled\n  → collab/reality.json, case "a-case", "guards": take the guard out for as long as'),
        ("a renamed knob", {"knobs": ["Fake.knobs"]}, '"knobs": put the switch\'s or the helper\'s new name (the nearest there is: Fake.knob), or take it out'),
        ("a knob that moved to another type", {"knobs": ["Faker.elsewhere"]}, "(the nearest there is: Other.elsewhere)"),
        ("a reworded step", {"guards": ["e2e: a step on the real windows"]},
         '"guards": put words from the new step or check, eight characters or more out of its quotes (the nearest there is: “a step on real windows”), or take the guard out if nothing checks this any more' + then),
        ("a step that is gone altogether", {"guards": ["e2e: something quite different from all"]}, "out of its quotes, or take the guard out"),
        ("a renamed scenario", {"guards": ["scenario: 02.sim"]}, "a *.sim in collab/scenarios (the nearest there is: 01.sim)"),
        ("a renamed trace", {"guards": ["trace: t2.jsonl"]}, "a *.jsonl in collab/evidence/traces (the nearest there is: t.jsonl)"),
        ("a renamed tool", {"guards": ["tool: by-hands.py"]}, "from scripts/ on (the nearest there is: by-hand.py)"),
        ("a renamed cure", {"copes": "Controller.coped does"}, '"copes": begin with the `Type.member`, the type or the file that holds the cure now (the nearest there is: Controller.copes), or write “open”'),
        ("a cure whose file moved", {"copes": "Sources/ArborCore/C.swift waits"}, '"copes": begin with the file that holds the cure now (there is Sources/ArborKit/C.swift)'),
        ("a source that moved", {"sources": ["docs/old/A.md"]}, '"sources": put the file\'s new place, from the repository\'s root (there is docs/A.md)'),
        ("a source with a line number is shown without", {"sources": ["docs/A.md:3"]}, "(there is docs/A.md)"),
        ("a backlog number", {"backlog": ["K8"]}, '"backlog": put the number the backlog has for this now, or take it out' + then),
        ("no knob", {"knobs": []}, '"knobs": name the switch or the helper'),
        ("out of reach", {"modelled": "cannot", "knobs": []}, '"modelled": put “no” if a stand-in could play this'),
    ]:
        situation(name, sets(**values), 1, words)
    situation("two things wrong, two remedies", sets(knobs=["Fake.gone"], backlog=["K8"]), 1, '"backlog": ')
    situation("the prose has its remedy too", sets(), 1, '  → collab/reality.json, "afterword": put the file\'s new name (the nearest there is: Sources/ArborKit/C.swift), or take the mention out' + then,
              top=lambda data: dict(data, afterword=["See `Sources/ArborKit/D.swift`."]))

    for name, values, words in [
        ("an unknown kind", {"kind": "bad luck"}, "no such kind"), ("an unknown layer", {"layer": "the attic"}, "no such layer"),
        ("an unknown answer to modelled", {"modelled": "maybe"}, "no such modelled"), ("hurt 5", {"hurt": 5}, "hurt is"), ("hurt true", {"hurt": True}, "hurt is"),
        ("hurt as a list", {"hurt": [1]}, "hurt is"), ("a kind that is a list", {"kind": []}, "“kind” is a text"), ("an id that is a number", {"id": 5}, "“id” is a text"),
        ("an id with capitals", {"id": "A Case"}, "small letters"), ("an empty cure", {"copes": " "}, "“copes” is a text"), ("no cure at all", {"copes": None}, "“copes” is a text"),
        ("open, with a story", {"copes": "open: nothing yet"}, "nothing more"), ("knobs that are numbers", {"knobs": [1]}, "“knobs” is a list"),
        ("an empty guard", {"guards": [""]}, "“guards” is a list"), ("guards as a text", {"guards": "test: aTest"}, "“guards” is a list"),
        ("a backlog as a text", {"backlog": "K7"}, "“backlog” is a list"), ("another certainty", {"certainty": 7}, "certainty"), ("a key nobody knows", {"colour": "red"}, "unknown keys"),
        ("a detector nobody knows", {"touches": ["lost", "bad-luck"]}, "“bad-luck” is none. They are: lost, jolt, focus. Put the detector's new id"),
        ("a detector that was renamed", {"touches": ["jolts"]}, "“jolts” is none (the nearest there is: jolt)"), ("what another table of the page has", {"touches": ["sabotage"]}, "is none"),
        ("what another section of the page has", {"touches": ["idle"]}, "is none"), ("a detector twice", {"touches": ["lost", "lost"]}, "twice"),
        ("detectors as a text", {"touches": "lost"}, "“touches” is a list"), ("an empty detector", {"touches": [""]}, "“touches” is a list"),
    ]:
        situation(name, sets(**values), 2, words)
    situation("an id used twice", lambda entry, entries: entries.append(dict(entry)), 2, "taken")
    situation("a key left out", lambda entry, entries: entry.pop("found"), 2, "found")
    situation("an entry that is a text", lambda entry, entries: entries.append("a case"), 2, "no object")
    situation("no entries", sets(), 2, "no “entries”", top=lambda data: {"preface": []})
    situation("no preface", sets(), 2, "no “preface”", top=lambda data: {"entries": []})
    situation("a preface that is one text", sets(), 2, "list of lines", top=lambda data: dict(data, preface="# Reality"))
    situation("a list at the top", sets(), 2, "holds an object", top=lambda data: [])
    situation("a misspelt afterword", sets(), 2, "unknown keys at the top", top=lambda data: dict(data, afterwards=["The end"]))
    situation("prose that names a file that is gone", sets(), 1, "Gone.swift", top=lambda data: dict(data, afterword=["See `Sources/Gone.swift`."]))
    situation(
        "prose may name what is cited and missing, under its own heading", sets(), 0,
        top=lambda data: dict(data, afterword=[MISSING, "- `collab/evidence/gone.txt`, cited by `Fake.swift`"]))
    situation(
        "and not what has turned up", sets(), 1, "listed as missing", top=lambda data: dict(data, afterword=[MISSING, "- `collab/evidence/traces/t.jsonl`"]))
    situation("prose that names a file by its name alone", sets(), 0, top=lambda data: dict(data, afterword=["See `Fake.swift` and `docs/A.md`."]))

    # What a guard counts for.
    situation("a test guards without a Mac", sets(guards=["test: aTest"]), 0, "0 that nothing guards by itself", "| **all** | 1 | 1 | 1 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 |")
    situation("a test for macOS alone needs CI's Macs", sets(guards=["test: onlyOnAMac"]), 0, "0 that nothing", "`test: onlyOnAMac` (on CI's Macs)")
    situation("a step of arbor-e2e needs CI's Macs", sets(guards=["e2e: a step on real windows"]), 0, "0 that nothing", "| **all** | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 |")
    situation("so does a step of a script the workflow names", sets(guards=["e2e: a drag that CI makes"]), 0, "0 that nothing", "(on CI's Macs)")
    situation("a step of a script that CI does not start is by hand", sets(guards=["e2e: a step somebody has to start"]), 0, "1 that nothing guards by itself", "(by hand)")
    situation("a tool that `make lint` runs guards", sets(guards=["tool: t.py"]), 0, "0 that nothing", "- **Guard:** `tool: t.py`\n")
    situation("a tool the workflow names only in a comment is by hand", sets(guards=["tool: by-hand.py"]), 0, "1 that nothing guards by itself", "`tool: by-hand.py` (by hand)")
    situation("no guard", sets(guards=[]), 0, "1 that nothing guards by itself", "**none**")
    situation("an open case that is guarded is still on the list of what to do first", sets(copes="open"), 0, "1 Arbor does not cope", "A fault that is known and open.\n\n| Case | Hurt | Where | Stand-ins play it | Guard |\n|---|---|---|---|---|\n| [a-case]")

    # Which detectors a case touches, and what ring 2 makes of it.
    none = "| `lost` | 0 | none |\n| `jolt` | 0 | none |\n| `focus` | 0 | none |\n\n3 of the 3 detectors have none."
    situation("a case says what it touches", sets(touches=["lost", "focus"]), 0, "0 open or unplayed", "*hurt 1 · at the seam · K7 · touches `lost`, `focus`*")
    situation("played and coped with: the walks can vouch", sets(touches=["lost"]), 0, "0 open or unplayed", none)
    situation("open counts, in bold, once for two detectors", sets(touches=["lost", "focus"], copes="open"), 0, "1 open or unplayed",
              "| `lost` | 1 | **[a-case](#a-case)** |\n| `jolt` | 0 | none |\n| `focus` | 1 | **[a-case](#a-case)** |\n\n1 of the 3 detectors have none.")
    situation("played partly at the seam counts", sets(touches=["jolt"], modelled="partly"), 0, "1 open or unplayed", "| `jolt` | 1 | [a-case](#a-case) |")
    situation("not played at the seam counts", sets(touches=["jolt"], modelled="no", knobs=[]), 0, "1 open or unplayed", "| `jolt` | 1 | [a-case](#a-case) |")
    situation("below the seam the stand-ins owe nothing", sets(touches=["jolt"], modelled="partly", layer="below the seam"), 0, "0 open or unplayed", none)
    situation("open and touching nothing is no row of ring 2", sets(copes="open"), 0, "0 open or unplayed", none)
    situation("without the gate's page any id passes, and the table has what the cases name", sets(touches=["whatever"], copes="open"), 0, "1 open or unplayed",
              "| `whatever` | 1 | **[a-case](#a-case)** |\n\n0 of the 1 detectors have none.", without=("docs/VIABLE.md",))
    situation("what was never tried is on a list of its own, and nobody knows", sets(kind=UNTRIED, copes="open", touches=["lost"]), 0, "0 Arbor does not cope with yet, 1 never exercised; 1 open or unplayed",
              "### Nobody knows whether Arbor copes")
    situation("and is no known fault", sets(kind=UNTRIED, copes="open"), 0, "", "A fault that is known and open.\n\n| Case | Hurt | Where | Stand-ins play it | Guard |\n|---|---|---|---|---|\n\n")
    situation("and its entry says so", sets(kind=UNTRIED, copes="open"), 0, "", "- **Arbor copes:** **nobody knows**")

    # What --check holds the page to, and what it lets pass; and what the gate is told.
    with tempfile.TemporaryDirectory() as root:
        for path, text in files.items():
            os.makedirs(os.path.dirname(os.path.join(root, path)), exist_ok=True)
            with open(os.path.join(root, path), "w", encoding="utf-8") as file:
                file.write(text)
        second = dict(good, id="b-case", copes="open", touches=["lost", "jolt"])
        third = dict(good, id="c-case", modelled="partly", touches=["jolt"], guards=["e2e: a step somebody has to start"])
        with open(os.path.join(root, "collab", "reality.json"), "w", encoding="utf-8") as file:
            json.dump({"preface": ["# Reality"], "entries": [good, second, third, dict(good, id="d-case", touches=["focus"]), dict(good, id="e-case", copes="open")]}, file)
        page = os.path.join(root, "docs", "REALITY.md")

        def checked(change=None, path=page):
            """What --check says once a file has been changed, which is then put back."""
            before = open(path, encoding="utf-8").read()
            with open(path, "w", encoding="utf-8") as file:
                file.write(change(before) if change else before)
            said = io.StringIO()
            with contextlib.redirect_stdout(said):
                code = run(root, check=True)
            with open(path, "w", encoding="utf-8") as file:
                file.write(before)
            return code, said.getvalue()

        with contextlib.redirect_stdout(io.StringIO()):
            run(root, check=False)
        # No case here is of the first kind: the page is still read to its end.
        for name, change, path, code, words in [
            ("a page just written", None, page, 0, "5 cases"),
            ("a case's words changed by hand, in a ledger without a case of the first kind", lambda text: text.replace("- **Expected:** x", "- **Expected:** something else", 1), page, 1, "out of date"),
            ("the last line of the page taken off", lambda text: text.rstrip("\n").rpartition("\n")[0] + "\n", page, 1, "out of date"),
            ("what a case touches changed by hand", lambda text: text.replace("touches `focus`", "touches `lost`"), page, 1, "out of date"),
            ("the preface changed by hand", lambda text: text.replace("# Reality", "# Fiction"), page, 1, "out of date"),
            ("a page from before the two comments", lambda text: text.replace(WORKED_OUT[0] + "\n", "").replace(WORKED_OUT[1] + "\n", ""), page, 1, "out of date"),
            ("a count that moved", lambda text: text.replace("| **all** | 5 |", "| **all** | 6 |"), page, 0, "note: "),
            ("a detector the gate has got since", lambda text: text.replace("| `focus` |", "| `told` | a word gets out |\n| `focus` |"), os.path.join(root, "docs", "VIABLE.md"), 0, "note: "),
            ("a script CI starts since", lambda text: text + "\nrun: ./scripts/mac-shell/check-F99.sh", os.path.join(root, ".github", "workflows", "ci.yml"), 0, "note: "),
            ("a detector the gate has renamed", lambda text: text.replace("`jolt`", "`jerk`"), os.path.join(root, "docs", "VIABLE.md"), 2, "“jolt” is none"),
        ]:
            if (got := checked(change, path))[0] != code or words not in got[1]:
                failures.append(f"--check, {name}: exit {got[0]} (wanted {code}); said {got[1]!r}")

        def told(target, head=lambda root: ("c" * 40, "")):
            said = io.StringIO()
            with contextlib.redirect_stdout(said):
                code = rings(root, target, head)
            return code, said.getvalue()

        wanted = {"stand_ins": {"commit": "c" * 40, "open_divergences_that_touch_a_detector": 2}}
        code, said = told("")
        if code != 0 or json.loads(said) != wanted:
            failures.append(f"--rings: two cases count, each once: exit {code}, said {said!r}")
        target = os.path.join(root, "rings.json")
        if told(target)[0] != 0 or json.load(open(target, encoding="utf-8")) != wanted:
            failures.append("--rings with a file that is not there yet does not make it")
        with open(target, "w", encoding="utf-8") as file:
            json.dump({"linux": {"walks": 10000}, "stand_ins": {"commit": "d" * 40, "open_divergences_that_touch_a_detector": 0}}, file)
        if told(target)[0] != 0 or json.load(open(target, encoding="utf-8")) != dict(wanted, linux={"walks": 10000}):
            failures.append("--rings with a file does not keep the other rings, or keeps its own old word")
        with open(target, "w", encoding="utf-8") as file:
            file.write("[1]")
        if told(target)[0] != 2 or open(target, encoding="utf-8").read() != "[1]":
            failures.append("--rings writes over a file that holds something else")
        code, said = told("", lambda root: (None, "commit first"))
        if code != 2 or "commit first" not in said or "stand_ins" in said:
            failures.append(f"--rings names a commit that does not hold what it counted: exit {code}, said {said!r}")
        if shutil.which("git"):
            def git(*words):
                subprocess.run(["git", "-C", root, "-c", "user.name=t", "-c", "user.email=t@example.com", "-c", "commit.gpgsign=false", *words], capture_output=True, check=False)
            git("init")
            if head_of(root)[0] is not None:
                failures.append("a repository without a commit has one")
            git("add", "-A")
            git("commit", "-m", "a ledger")
            if not re.fullmatch(r"[0-9a-f]{40}", head_of(root)[0] or ""):
                failures.append(f"the commit of a ledger that is committed is not told: {head_of(root)}")
            with open(os.path.join(root, "docs", "A.md"), "w", encoding="utf-8") as file:
                file.write("another file is nobody's business")
            if not head_of(root)[0]:
                failures.append("a change to a file that is not counted keeps the commit from being told")
            with open(os.path.join(root, "docs", "VIABLE.md"), "a", encoding="utf-8") as file:
                file.write("\n")
            if head_of(root)[0] or "docs/VIABLE.md" not in head_of(root)[1]:
                failures.append(f"a ledger counted against a page that is not committed is put down to the commit: {head_of(root)}")
        with open(os.path.join(root, "collab", "reality.json"), "w", encoding="utf-8") as file:
            json.dump({"preface": [], "entries": [dict(good, touches=["bad-luck"])]}, file)
        if told("")[0] != 2:
            failures.append("--rings counts in a ledger that is wrong")

    with tempfile.TemporaryDirectory() as root:
        os.makedirs(os.path.join(root, "collab"))
        os.makedirs(os.path.join(root, "docs"))
        with open(os.path.join(root, "collab", "reality.json"), "w", encoding="utf-8") as file:
            json.dump({"preface": ["# Reality"], "entries": []}, file)
        with open(os.path.join(root, "docs", "REALITY.md"), "w", encoding="utf-8") as file:
            file.write("edited by hand\n")
        with contextlib.redirect_stdout(io.StringIO()):
            if run(root, check=True) != 1:
                failures.append("a page edited by hand passes --check")
        page = f"x\n{WORKED_OUT[0]}\n## The count\n1 | 2\n{WORKED_OUT[1]}\n## input\n- **Guard:** `e2e: a step` (by hand); `test: t` (on CI's Macs)\n"
        if settled(page) != settled(page.replace("1 | 2", "3 | 4").replace(" (by hand)", " (on CI's Macs)")) or settled(page) == settled(page.replace("a step", "another")):
            failures.append("counts that moved make a page stale, or other words do not")
        with open(os.path.join(root, "collab", "reality.json"), "w", encoding="utf-8") as file:
            file.write("{ not json")
        with contextlib.redirect_stdout(io.StringIO()):
            if run(root, check=True) != 2:
                failures.append("a file that is no JSON does not end with 2")
    for failure in failures:
        print(f"✘ reality-ledger self-test: {failure}")
    return 1 if failures else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--rings", nargs="?", const="", metavar="FILE")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    sys.exit(self_test() if args.self_test else rings(ROOT, args.rings) if args.rings is not None else run(ROOT, args.check))


if __name__ == "__main__":
    main()
