#!/usr/bin/env python3
"""Keeps the ledger of where real macOS differed from what Arbor's stand-ins or tests expected, and writes docs/REALITY.md from it.

    scripts/reality-ledger.py              check collab/reality.json, print the counts, rewrite docs/REALITY.md
    scripts/reality-ledger.py --check      also fail if docs/REALITY.md is out of date (`make lint`, CI)
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

What goes red BY ITSELF is worked out, not kept by hand: a test (one for macOS alone needs CI's Mac), a scenario, a trace, a tool or a real-window
runner that .github/workflows/ci.yml or the Makefile's `check` and `lint` start, directly or through a script they start. A step of any other Mac shell
script, and any other tool, guards only when somebody starts it, and the page says "by hand".

The preface and the afterword are prose and are copied as they stand, but for the files they name in backticks, which must exist.

Exit code 1 if a name is not found or, with --check, the page does not say what reality.json says; 2 if reality.json itself is wrong. A page whose
counts have moved only because the rest of the repository has (CI starts another script) gets a note, so that nobody's lint fails on it.
"""
import argparse
import collections
import contextlib
import glob
import io
import json
import os
import re
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

    def tests(self):
        """The tests that run everywhere, and those compiled or enabled on macOS alone."""
        if "tests" not in self.indexes:
            everywhere, mac = set(), set()
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
                        if ".disabled" not in arguments:
                            (mac if only_mac else everywhere).add(name)
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


def problems_of(entry, tree):
    """What is wrong with the names one entry gives."""
    found = []
    for knob in entry["knobs"]:
        if not tree.declares(knob, STAND_INS):
            found.append(f"knob `{knob}`: no stand-in declares it (write `Type.member`, or the name of a type or of a function that belongs to none)")
    for guard in entry["guards"]:
        sort, _, name = guard.partition(": ")
        if not name.strip():
            found.append(f"a guard is `test: `, `scenario: `, `trace: `, `e2e: ` or `tool: ` and a name, not “{guard}”")
        elif sort == "test":
            if name not in tree.tests()[0] | tree.tests()[1]:
                found.append(f"there is no test `{name}`, or it is disabled")
        elif sort == "scenario":
            if not name.endswith(".sim") or not tree.is_file(f"collab/scenarios/{name}"):
                found.append(f"there is no scenario {name}")
        elif sort == "trace":
            recording = name[:-len(".expect")] + ".jsonl" if name.endswith(".expect") else name
            if not recording.endswith(".jsonl") or not all(tree.is_file(f"collab/evidence/traces/{file}") for file in {name, recording}):
                found.append(f"there is no trace {name}")
        elif sort == "e2e":
            if len(name) < 8 or name not in tree.steps(by_itself=False):
                found.append(f"no real-window runner has a step or a check with the words “{name}”")
        elif sort == "tool":
            if not tree.is_file(f"scripts/{name}"):
                found.append(f"there is no scripts/{name}")
        else:
            found.append(f"a guard is `test: `, `scenario: `, `trace: `, `e2e: ` or `tool: ` and a name, not “{guard}”")
    if entry["copes"] != "open":
        first = entry["copes"].split()[0].rstrip(":,;")
        if "/" in first:
            if not tree.is_file(first):
                found.append(f"copes: there is no {first}")
        elif not (first[:1].isupper() or "." in first) or not tree.declares(first, ("Sources/**/*.swift",)):
            found.append(f"copes: it is `open`, or begins with a file, or with `Type.member` or a type declared under Sources/, not with “{first}”")
    for source in entry["sources"]:
        if not tree.is_file(source):
            found.append(f"source: there is no file {source} (no line numbers: they rot)")
    for number in entry.get("backlog", []):
        if number not in tree.words("collab/BACKLOG.md"):
            found.append(f"collab/BACKLOG.md has no {number}")
    if entry["modelled"] in ("yes", "partly") and not entry["knobs"]:
        found.append(f"modelled “{entry['modelled']}” but no knob is named")
    if entry["modelled"] == "cannot" and entry["layer"] == "at the seam":
        found.append("what crosses the seam can be played by a stand-in: that it “cannot” be is for what lies below or beside it")
    return found


MISSING = "## Evidence that is cited and is not in the repository"


def prose_problems(data, tree):
    """Files the preface and the afterword name that are not there; a name without a folder is looked for everywhere. Under the heading for what is
    cited and missing it is the other way round: a file that has turned up has no business there."""
    names = {os.path.basename(path) for path in tree.paths("Sources/**/*", "scripts/**/*", "docs/**/*", "collab/**/*", "Tests/**/*", "*", ".github/**/*")}
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
                        found.add(f"{part}: {name} is listed as missing and is there")
                elif not there and os.path.basename(name) not in names:
                    found.add(f"{part}: there is no file {name}")
    return sorted(found)


def shape_problems(data):
    """What is wrong with the file itself."""
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
        for key in LISTS + ["backlog"]:
            value = entry.get(key, [] if key == "backlog" else None)
            if not isinstance(value, list) or not all(isinstance(item, str) and item.strip() for item in value):
                found.append(f"{name}: “{key}” is a list of texts, none of them empty")
        if entry.get("certainty", "suspected") != "suspected":
            found.append(f"{name}: “certainty” is left out or is “suspected”")
        if unknown := set(entry) - set(TEXTS) - set(LISTS) - {"hurt", "backlog", "certainty"}:
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


def document(data, tree):
    entries = data["entries"]
    watched = {entry["id"]: watch_of(entry, tree) for entry in entries}
    count = lambda some, test: sum(1 for entry in some if test(entry))
    out = ["<!-- Generated by scripts/reality-ledger.py from collab/reality.json. Do not edit by hand. -->", ""]
    out += data["preface"] + [""]

    out += ["## The count", ""]
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
    out += listing("Arbor does not cope yet", "A fault that is known and open.", [e for e in hurts if e["copes"] == "open"])
    out += listing(
        "Arbor copes, and nothing would notice if it stopped", "No guard, or only a script that somebody has to start.",
        [e for e in hurts if e["copes"] != "open" and watched[e["id"]] in ("hand", "none")])
    out += listing(
        "The stand-ins could play it and do not", "So no test on Linux can meet it. (Those they play partly are not listed: see each kind.)",
        [e for e in hurts if e["modelled"] == "no"])

    for kind, title in KINDS.items():
        of_kind = sorted((entry for entry in entries if entry["kind"] == kind), key=lambda e: (e["hurt"], e["id"]))
        if not of_kind:
            continue
        out += [f"## {kind}", "", title + ".", ""]
        for entry in of_kind:
            tags = [f"hurt {entry['hurt']}", entry["layer"]] + ([entry["certainty"]] if entry.get("certainty") else []) + entry.get("backlog", [])
            says = {"yes": "yes", "partly": "partly", "no": "**no**", "cannot": "cannot: it lies below or beside the seam"}[entry["modelled"]]
            knobs = ", ".join(f"`{knob}`" for knob in entry["knobs"])
            marks = {"linux": "", "mac": " (on CI's Macs)", "hand": " (by hand)"}
            guards = [f"`{guard}`{marks[watch(guard, tree)]}" for guard in entry["guards"]]
            out += [
                f"### {entry['id']}", "", "*" + " · ".join(tags) + "*", "",
                f"- **Expected:** {entry['expected']}", f"- **Happened:** {entry['happened']}", f"- **Found by:** {entry['found']}",
                f"- **Stand-ins play it:** {says}" + (f" ({knobs})" if knobs else ""),
                "- **Guard:** " + ("; ".join(guards) if guards else "**none**"),
                "- **Arbor copes:** " + ("**not yet**" if entry["copes"] == "open" else entry["copes"]),
                "- **Read in:** " + ", ".join(f"`{source}`" for source in entry["sources"]), ""]
    out += data.get("afterword", [])
    return "\n".join(out).rstrip("\n") + "\n"


def settled(page):
    """The page without what is worked out from the rest of the repository: the counts, the lists of what to do first, and how each guard goes red."""
    first = f"\n## {next(iter(KINDS))}\n"
    head, _, rest = page.partition("\n## The count\n")
    return head + first + re.sub(r"(?<=`) \((?:by hand|on CI's Macs)\)", "", rest.partition(first)[2])


def run(root, check):
    path = os.path.join(root, "collab", "reality.json")
    try:
        with open(path, encoding="utf-8") as file:
            data = json.load(file)
    except (OSError, ValueError) as error:
        print(f"reality-ledger: {path}: {error}")
        return 2
    if wrong := shape_problems(data):
        for line in wrong:
            print(f"reality-ledger: {line}")
        return 2
    tree = Tree(root)
    code = 0
    for name, problems in [(entry["id"], problems_of(entry, tree)) for entry in data["entries"]] + [("the prose", prose_problems(data, tree))]:
        for problem in problems:
            print(f"✘ {name}: {problem}")
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
        f"{number(lambda e: watch_of(e, tree) in ('hand', 'none'))} that nothing guards by itself; {number(lambda e: e['copes'] == 'open')} Arbor does not cope with yet")
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
                           "#if os(macOS)\n@Test func onlyOnAMac() {}\n#endif",
        "collab/scenarios/01.sim": "", "collab/scenarios/notes.md": "", "collab/evidence/traces/t.jsonl": "", "collab/evidence/traces/lonely.expect": "",
        "Sources/arbor-e2e/main.swift": 'step("a step on real windows")\n// step("a step that was taken out")\nobserve("a step that only looks on")',
        "scripts/mac-shell/check-F99.sh": 'step "a step somebody has to start"', "scripts/mac-shell/e2e-drag.sh": 'step "a drag that CI makes"',
        "scripts/t.py": "", "scripts/by-hand.py": "", "scripts/e2e.sh": ".build/debug/arbor-e2e", "docs/A.md": "", "collab/BACKLOG.md": "| K7 | a thing |",
        ".github/workflows/ci.yml": "run: ./scripts/e2e.sh\nrun: ./scripts/mac-shell/e2e-drag.sh\nrun: make lint\n# run: ./scripts/by-hand.py",
        "Makefile": "lint:\n\t@python3 scripts/t.py\n",
    }
    failures = []

    def situation(name, change, expected_code, said_words="", page_words="", top=None):
        with tempfile.TemporaryDirectory() as root:
            for path, text in files.items():
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
    for name, values, words in [
        ("an unknown kind", {"kind": "bad luck"}, "no such kind"), ("an unknown layer", {"layer": "the attic"}, "no such layer"),
        ("an unknown answer to modelled", {"modelled": "maybe"}, "no such modelled"), ("hurt 5", {"hurt": 5}, "hurt is"), ("hurt true", {"hurt": True}, "hurt is"),
        ("hurt as a list", {"hurt": [1]}, "hurt is"), ("a kind that is a list", {"kind": []}, "“kind” is a text"), ("an id that is a number", {"id": 5}, "“id” is a text"),
        ("an id with capitals", {"id": "A Case"}, "small letters"), ("an empty cure", {"copes": " "}, "“copes” is a text"), ("no cure at all", {"copes": None}, "“copes” is a text"),
        ("open, with a story", {"copes": "open: nothing yet"}, "nothing more"), ("knobs that are numbers", {"knobs": [1]}, "“knobs” is a list"),
        ("an empty guard", {"guards": [""]}, "“guards” is a list"), ("guards as a text", {"guards": "test: aTest"}, "“guards” is a list"),
        ("a backlog as a text", {"backlog": "K7"}, "“backlog” is a list"), ("another certainty", {"certainty": 7}, "certainty"), ("a key nobody knows", {"colour": "red"}, "unknown keys"),
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
        page = "x\n## The count\n1 | 2\n## order-of-reports\n- **Guard:** `e2e: a step` (by hand); `test: t` (on CI's Macs)\n"
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
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    sys.exit(self_test() if args.self_test else run(ROOT, args.check))


if __name__ == "__main__":
    main()
