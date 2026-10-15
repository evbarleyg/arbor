#!/usr/bin/env python3
"""Takes a census of the tests and regenerates docs/CENSUS.md.

Reads the sources as text; builds and runs nothing, so it needs no Swift and takes half a minute. It answers three
questions.

1. What does each `@Test` function touch? Every one is put into exactly one class, by its body and by the helpers of its
   own test target that it reaches (followed by name, five calls deep):

  A  pure                   no stand-in, no macOS API, no file: values in, values out
  B  a stand-in or a tool   the subject is the fake, the harness, the chaos lab, traces as a tool, benchmarks, or the
                            repository's own text (docs and sources read as text)
  C  commands only          the real controller on stand-ins; windows are opened and everything else is a command, a
                            shortcut pressed and let go, or time passing
  D  the world acts         as C, and the test has macOS, an app or a hand do something, or tells a stand-in what macOS
                            or an app will answer
  E  a recording            a trace from collab/evidence is replayed: what a real Mac reported and real apps answered
  F  real macOS code        compiled only on macOS and calling AppKit, Carbon, CoreGraphics or Arbor's macOS-only types
  G  real files, sockets,   POSIX and Dispatch for real, the same on macOS and Linux
     processes, queues

   Where a test touches several, the first of F, E, B, G, D, C, A wins (`classify`).
2. For each helper that stands for the world: how many tests rest on it, and does a committed recording of a real Mac
   hold the kind of report it makes up?
3. For each file that only a Mac can run: lines, branches, and what executes it without being asked: a test of class F or
   G, `make e2e`, `make e2e-drag` (CI's job real-windows); or only a Mac shell script that somebody has to start; or nothing.

**Not part of `make check` or CI, and it should not be.** Half of it is judgement, kept in tables so that it can be argued
with: which members of the stand-ins stand for the world, which suites have a tool for a subject (right below), what a
recording would have to hold (EVIDENCE), what a run must switch on to get into a file (WIRING), what the ranking of
features in the document rests on (RANKING_…). The script stops, and names what it met, when the sources have outgrown
a table: a public member of a stand-in that is in none, a file of real code without an entry, a source line its reading of the
wiring rests on that is gone, a default the ranking goes by that has changed. Then a person looks, mends the table, and
reads what the document says about it. A check that fails for whoever adds a helper to a fake would teach people to
fill in tables without looking.

The document is scripts/census-template.md with the tables and numbers put in: `{{table:classes}}`, `{{functions}}`,
`{{d:system.userFocus}}` (`Census.lookup` lists the forms). Prose, and the whole of its section 4, are written there.

Usage:
  scripts/census.py                        print the tables, and each test file's classes
  scripts/census.py --write                regenerate docs/CENSUS.md, whole
  scripts/census.py --out DIR              also write tests.tsv (one row per test), files.tsv, helpers.tsv, realcode.tsv to DIR
  scripts/census.py --show NAME            how the tests of that name (a function or a suite) were classified, through which helpers
  scripts/census.py --sample 60 --seed 4   sixty tests drawn at random, with their bodies, to check by hand ([--per-class])
  scripts/census.py --self-test            small sources whose answers are known

Nothing is written into the checkout but docs/CENSUS.md, and that only with --write. Exit code 1 when the sources have
outgrown a table or the self-test fails.
"""
import argparse
import collections
import json
import os
import random
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = "scripts/census-template.md"
DOCUMENT = "docs/CENSUS.md"

# ---------------------------------------------------------------------------------------------------------------------
# Judgements, 1: what the members of the fakes stand for
# ---------------------------------------------------------------------------------------------------------------------
# Every public member of FakeWindowSystem, FakeOverlays, Harness, ManualScheduler, MemoryStateStore, FakeLoginItem and
# FakeReleaseFeed must be in one of these lists, or the script stops: a new helper has to be looked at.

# The fake sends Arbor a report, or changes the world behind Arbor's back: macOS, an app or a hand acts.
SYSTEM_REPORTS = """
close setMinimized setHidden unhideApp setOnActiveSpace userMove setTitle userFocus drag activate activateApp setDisplays
setListed openUnlisted finishSlowFocus userResize releaseMouse backgroundFocus setFullScreen userFocusesNothing sheetTakesTheKeyboard
userSwitchesApp appsSettle setUnresponsive openTab selectTab closeTab dragAndLoseTheRelease quit quitApp comesForward
settleFocus click userClick beginDrag moveDrag holdDrag holdModifierKeys endDrag loseTheReleaseOfTheDrag appsReact grab
carry letGo loseTheRelease moveSilently report renumber finishRestoring openStrayDialog forgetSession type keyDown keyUp
hold
""".split()
# The test tells the fake what macOS or an app will answer when Arbor asks or acts. Methods, then properties that are set.
SYSTEM_ANSWERS = "setMinimumSize setMaximumSize setSizeStep setBehaviour setTitleBar".split()
SYSTEM_ANSWER_PROPERTIES = """
cursor mouseDown focused heldModifiers secondsSinceInput displayList stubbornFrames focusIsSlow defersFocus restoresLate
willSetFrame echoes holdsEchoes isDenied flagLags refusesTaps stackingIsUnknown strangers missingApps unlaunchableApps
ignoresMoveTogether
""".split()
# Opening a window is set-up by the definition of class C, whether before or after the start. It is counted in part 2 all
# the same, because after the start it is a report like any other.
SYSTEM_OPEN = ["open"]
# What Arbor itself calls (the protocol), what a test reads, what only delivers the echo of Arbor's own call, wiring.
SYSTEM_NEUTRAL = """
events windows resizing started frameLog slowFocus afterEvents unresponsive backgroundTabs deniedCalls questions
mayUseAccessibility unlisted clock frontmost raiseLog leavesStrayDialogs strayDialogs appWhoseDialogsNeverWait
focusRequests openRequests launchedApps moveLog focusLog focusedWindowReads passTime answersAhead standardDisplay start stop
starts setFrameOnce allWindows displays setFrame moveTogether whereMacOSPuts focus focusedWindow cursorLocation
isMouseButtonDown secondsSinceClickOrModifierKey leaveStrayDialogs bringInStrayDialogs strayDialogsWaiting modifierKeysDown
inputActivity isHolding frame isVisible clearFrameLog existingWindowIDs launchApp deliverEchoes reportFocus stackedWindows
install place remove hasHeldEchoes dragging frameAfterResizing openApplication raise windowsFrontToBack clearRaiseLog
snapshot minimumSize maximumSize sizeStep behaviour lastRequest placeIsArborsDoing groundHasShifted movesNotArbors
changedItsWays window requested before after together wasFocused focus frames keyboard wholePoints
titleBarStaysReachable flightFromTheDock flightFromFullScreen none jolts titleBar usualTitleBar measuredTitleBars reports
""".split()

# A hand on one of Arbor's own panels: the fake calls the action the real panel would call.
OVERLAY_ACTIONS = """
clickTile clickOutline dragSeam dismissCheatSheet submitName cancelName typeInFinder moveFinderSelection chooseInFinder
dismissFinder clickMinimap
""".split()
OVERLAY_NEUTRAL = """
actions preview previewHistory scenes tiles seams transitions finishedAnimations onAnimate namePrompt headsUp messages
cheatSheets minimaps minimapHistory updateLog showDropPreview update removeAll animate finishAnimations clearTransitions
showHeadsUp showCheatSheet finder finderBeeps showFinder showMinimap display changed
""".split()

# Harness: a key that is held, or whose release is a report of its own; the permission taken away.
HARNESS_REPORTS = "keyDown keyUp keyRepeat revokeAccessibility grantAccessibility watchAccessibility".split()
HARNESS_NEUTRAL = """
system overlays store scheduler controller releases loginItem recorder start run press registeredShortcuts key display
workspace layout visibleFrame frame ascii lastTrace layoutProblems staleLayouts measure beginStep stepMark movesInStep jolts
""".split()

# What the stand-ins for GitHub's releases and macOS's login items are told to answer.
OTHER_ANSWERS = {"releases": "reply answer".split(), "loginItem": "status refuses statusAfterRefusal".split()}
OTHER_NEUTRAL = """
saved saveCount repairs keptCopy loadProblem load save afterEach now schedule cancel pendingKeys runPending advance fire location lines isClosed failure
text write close requests latestRelease changes setEnabled description
""".split()

# The ways into the controller that the macOS-only layers use, called by a test itself: the test makes the report up.
# The members of WindowSystemEvents and OverlayActions are read from the protocols and added to these.
CONTROLLER_REPORTS = "shortcut gesture callSignalsChanged keyboardLayoutChanged settingsFileMayHaveChanged sessionIsEnding".split()
# Facts about the Mac that the app hands to the controller, set by a test.
CONTROLLER_FACTS = """
accessibilityGranted accessibilityProbe systemFacts systemShortcuts registeredBindings refusedBindings nameOfApp
""".split()

# A line of a chaos script and the helper `ChaosRunner.perform` turns it into (Sources/ArborTesting/ChaosRunner.swift).
CHAOS_WORDS = {
    "close": "system.close", "quit-app": "system.quitApp", "minimize": "system.setMinimized", "restore": "system.setMinimized",
    "hide": "system.setHidden", "show": "system.setHidden", "space": "system.setOnActiveSpace",
    "full-screen": "system.setFullScreen", "title": "system.setTitle", "limits": "system.setMinimumSize",
    "behave": "system.setBehaviour", "move": "system.userMove", "react": "system.appsReact", "settle": "system.appsReact",
    "cursor": "system.cursor=", "focus": "system.userFocus", "switch-app": "system.userSwitchesApp",
    "focus-nothing": "system.userFocusesNothing", "background-focus": "system.backgroundFocus", "press": "system.mouseDown=",
    "grab": "system.grab", "carry": "system.carry", "release": "system.letGo", "lose-release": "system.loseTheRelease",
    "cmd": "system.holdModifierKeys", "key": "controller.shortcut", "pinch": "controller.gesture",
    "activate": "system.activate", "hang": "system.setUnresponsive", "wake": "system.setUnresponsive",
    "tab-open": "system.openTab", "tab-select": "system.selectTab", "tab-close": "system.closeTab",
    "list": "system.setListed", "unlist": "system.setListed", "edge": "system.userResize", "tile": "overlays.clickTile",
    "palette": "overlays.typeInFinder", "seam": "overlays.dragSeam", "displays": "system.setDisplays",
    "renumber": "system.renumber",
}

# ---------------------------------------------------------------------------------------------------------------------
# Judgements, 2: suites whose subject is a stand-in or a tool (class B whatever they touch, unless F applies)
# ---------------------------------------------------------------------------------------------------------------------
TOOL_SUITES = {
    "FaithfulFakeTests": "the fake window system itself",
    "ManualSchedulerTests": "the fake scheduler itself",
    "LayoutCheckTests": "Harness.layoutProblems",
    "ScenarioExpectationTests": "the `expect` lines of scenarios (ArborTesting/Expectations.swift)",
    "PinExpectationTests": "the `expect` lines of scenarios",
    "ChaosTests": "the chaos lab: text forms, determinism, shrinking",
    "ChaosKnownFailureTests": "the chaos lab's list of known failures",
    "TraceRecorderTests": "the trace recorder",
    "TraceFileTests": "the trace format",
    "TraceFormatTests": "the trace format",
    "TitleTokenTests": "the trace recorder: what stands for a title",
    "TraceReplayTests": "the trace replayer, on traces written by hand",
    "TraceRepliesTests": "the trace recorder: what it leaves out",
    "TraceWordsTests": "the trace recorder: what it leaves out",
    "TraceForwardingTests": "the recording decorators, read as source text",
    "DocTranscriptTests": "the transcripts in the documentation and the machinery that runs them",
    "TimingTests": "benchmarks (ArborTesting/Benchmark.swift)",
    "MacShellToolsTests": "the Mac shell's helper tools, handed to the compiler",
}
# … except these, whose subject is the controller.
NOT_TOOL = {("ChaosTests", "randomActionsKeepEveryInvariant")}
# Single tests in suites about a feature that try the tool's knowledge of the feature: `expect summoned 104` and the like.
TOOL_TESTS = re.compile(r"^scenariosCan")

MAC_FOLDERS = ["Sources/ArborKit/AX", "Sources/ArborKit/UI", "Sources/ArborKit/Input", "Sources/ArborKit/App"]
REAL_FOLDERS = MAC_FOLDERS + ["Sources/ArborKit/IPC", "Sources/Arbor", "Sources/arborctl", "Sources/ArborTestWindows",
                              "Sources/arbor-e2e"]

CLASS_NAMES = {
    "A": "pure", "B": "a stand-in or a tool is the subject", "C": "logic on stand-ins, commands only",
    "D": "logic on stand-ins, the world acts", "E": "replays a recording of a real Mac", "F": "runs real macOS code",
    "G": "real files, sockets, processes, queues",
}


# ---------------------------------------------------------------------------------------------------------------------
# Reading Swift: enough to find declarations, their bodies and the #if they stand in
# ---------------------------------------------------------------------------------------------------------------------
def blank(chars, a, b):
    for k in range(a, b):
        if chars[k] != "\n":
            chars[k] = " "


def lex(src):
    """(code, bare), both as long as src: `code` has comments blanked, `bare` the contents of strings and regexes too."""
    n = len(src)
    code, bare = list(src), list(src)

    def skip_comment(i):
        if src.startswith("//", i):
            j = src.find("\n", i)
            return n if j < 0 else j
        depth, j = 1, i + 2
        while j < n and depth:
            if src.startswith("/*", j):
                depth, j = depth + 1, j + 2
            elif src.startswith("*/", j):
                depth, j = depth - 1, j + 2
            else:
                j += 1
        return j

    def string_start(i):
        j = i
        while j < n and src[j] == "#":
            j += 1
        if j < n and src[j] == '"':
            eol = src.find("\n", j)
            multi = src.startswith('"""', j) and src[j + 3:eol if eol >= 0 else n].strip() == ""
            return j - i, ('"""' if multi else '"')
        return None

    def skip_string(i, hashes, quote):
        j = i + hashes + len(quote)
        close, escape = quote + "#" * hashes, "\\" + "#" * hashes
        while j < n:
            if src.startswith(close, j):
                return j + len(close)
            if src.startswith(escape, j):
                k = j + len(escape)
                j = skip_parens(k) if k < n and src[k] == "(" else k + 1
                continue
            if quote == '"' and src[j] == "\n":
                return j
            j += 1
        return n

    def skip_parens(i):
        depth, j = 0, i
        while j < n:
            c = src[j]
            if src.startswith("//", j) or src.startswith("/*", j):
                j = skip_comment(j)
                continue
            if c in '"#':
                s = string_start(j)
                if s:
                    j = skip_string(j, *s)
                    continue
            if c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
                if depth == 0:
                    return j + 1
            j += 1
        return n

    def regex_end(i):
        """If a regex literal /…/ starts at i, the index after it. A slash after a value is a division."""
        k = i - 1
        while k >= 0 and src[k] in " \t":
            k -= 1
        if k >= 0 and (src[k].isalnum() or src[k] in '_)]}"') and not re.search(r"\b(of|return|in|case)$", src[max(0, k - 6):k + 1]):
            return None
        if i + 1 >= n or src[i + 1] in " \t\n/*":
            return None
        j, in_class = i + 1, False
        while j < n and src[j] != "\n":
            if src[j] == "\\":
                j += 2
                continue
            if src[j] == "[":
                in_class = True
            elif src[j] == "]":
                in_class = False
            elif src[j] == "/" and not in_class:
                return j + 1
            j += 1
        return None

    i = 0
    while i < n:
        c = src[i]
        if c == "/" and (src.startswith("//", i) or src.startswith("/*", i)):
            j = skip_comment(i)
            blank(code, i, j)
            blank(bare, i, j)
            i = j
            continue
        if c in '"#':
            s = string_start(i)
            if s:
                j = skip_string(i, *s)
                blank(bare, i + s[0] + 1, max(i + s[0] + 1, j - s[0] - 1))
                i = j
                continue
        if c == "/":
            j = regex_end(i)
            if j:
                blank(bare, i + 1, j - 1)
                i = j
                continue
        i += 1
    return "".join(code), "".join(bare)


OPEN, CLOSE = "([{", ")]}"


def match(bare, i):
    depth = 0
    for j in range(i, len(bare)):
        c = bare[j]
        if c in OPEN:
            depth += 1
        elif c in CLOSE:
            depth -= 1
            if depth == 0:
                return j + 1
    return len(bare)


def body_open(bare, i):
    """From i (after a declaration's name) the index of the `{` that opens its body, or -1."""
    depth, j, n = 0, i, len(bare)
    while j < n:
        c = bare[j]
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
            if depth < 0:
                return -1
        elif c == "{" and depth == 0:
            return j
        elif c == "}" and depth == 0:
            return -1
        elif c == "\n" and depth == 0:
            rest = bare[j:j + 200].lstrip()
            if not rest.startswith(("{", "->", "where", "throws", "async", ".", ",", ")")):
                return -1
        j += 1
    return -1


class Decl:
    __slots__ = ("kind", "name", "file", "start", "open", "end", "parent", "attrs", "private", "conds", "line", "key")

    def bare(self):
        return self.file.bare[self.start:self.end]

    def code(self):
        return self.file.code[self.start:self.end]

    def __repr__(self):
        return f"<{self.kind} {self.name} {self.file.rel}:{self.line}>"


TYPE = re.compile(r"\b(struct|class|enum|extension|actor|protocol)\s+([A-Za-z_][\w.]*)")
FUNC = re.compile(r"\b(func)\s+(`[^`]+`|[A-Za-z_]\w*)|\b(init)\s*[?(<]")
PROP = re.compile(r"\b(?:let|var)\s+([A-Za-z_]\w*)")
COND = re.compile(r"^[ \t]*#(if|elseif|else|endif)\b(.*)$", re.M)
MODIFIERS = ("private", "fileprivate", "static", "mutating", "nonisolated", "final", "public", "internal", "override", "class",
             "indirect", "lazy", "weak", "unowned", "open", "package")


class Source:
    def __init__(self, path, rel):
        self.path, self.rel = path, rel
        self.src = open(path, encoding="utf-8").read()
        self.code, self.bare = lex(self.src)
        self._conds()
        self._scan()

    def line(self, i):
        return self.src.count("\n", 0, i) + 1

    def _conds(self):
        self.regions, stack, last = [], [], 0
        for m in COND.finditer(self.bare):
            self.regions.append((last, m.start(), [s[-1] for s in stack]))
            last = m.end()
            word, rest = m.group(1), " ".join(m.group(2).split())
            if word == "if":
                stack.append([rest])
            elif word == "elseif" and stack:
                stack[-1].append("!(" + stack[-1][0] + ") && " + rest)
            elif word == "else" and stack:
                stack[-1].append("!(" + stack[-1][0] + ")")
            elif word == "endif" and stack:
                stack.pop()
        self.regions.append((last, len(self.bare), []))

    def conds_at(self, i):
        for a, b, c in self.regions:
            if a <= i <= b:
                return c
        return []

    def _attrs(self, i):
        """Where the attributes and modifiers before the keyword at i begin."""
        j, bare = i, self.bare
        while True:
            k = j
            while k > 0 and bare[k - 1] in " \t\n":
                k -= 1
            if k == 0:
                break
            if bare[k - 1] == ")":
                depth, p = 0, k - 1
                while p >= 0:
                    if bare[p] in CLOSE:
                        depth += 1
                    elif bare[p] in OPEN:
                        depth -= 1
                        if depth == 0:
                            break
                    p -= 1
                q = p
                while q > 0 and (bare[q - 1].isalnum() or bare[q - 1] in "_."):
                    q -= 1
                if q > 0 and bare[q - 1] == "@":
                    j = q - 1
                    continue
                if bare[q:p] in MODIFIERS:
                    j = q
                    continue
                break
            q = k
            while q > 0 and (bare[q - 1].isalnum() or bare[q - 1] == "_"):
                q -= 1
            if q > 0 and bare[q - 1] == "@":
                j = q - 1
                continue
            if bare[q:k] in MODIFIERS:
                j = q
                continue
            break
        return j

    def _make(self, kind, name, keyword, opening, end):
        d = Decl()
        d.kind, d.name, d.file, d.open, d.end = kind, name, self, opening, end
        d.start = self._attrs(keyword)
        d.attrs = self.bare[d.start:keyword]
        d.private = bool(re.search(r"\b(private|fileprivate)\b(?!\s*\(set\))", d.attrs))
        d.conds = self.conds_at(keyword)
        d.line = self.line(keyword)
        d.parent = None
        d.key = keyword
        return d

    def _scan(self):
        bare, found = self.bare, []
        for m in TYPE.finditer(bare):
            if m.group(2) in ("func", "var", "let"):
                continue
            o = body_open(bare, m.end())
            if o >= 0:
                found.append(("type:" + m.group(1), m.group(2), m.start(), o))
        for m in FUNC.finditer(bare):
            name = m.group(2).strip("`") if m.group(2) else "init"
            if not m.group(2) and m.start() > 0 and bare[m.start() - 1] == ".":
                continue
            o = body_open(bare, m.end(2) if m.group(2) else m.end(3))
            if o >= 0:
                found.append(("func", name, m.start(), o))
        found.sort(key=lambda f: f[2])
        spans = [self._make(kind, name, start, o, match(bare, o)) for kind, name, start, o in found]
        stack = []
        for d in spans:
            while stack and stack[-1].end <= d.key:
                stack.pop()
            d.parent = stack[-1] if stack else None
            stack.append(d)
        funcs = [(d.open, d.end) for d in spans if d.kind == "func"]
        types = [d for d in spans if d.kind.startswith("type")]
        props = []
        for m in PROP.finditer(bare):
            i = m.start()
            if any(a < i < b for a, b in funcs) or (props and props[-1].key <= i < props[-1].end):
                continue
            p = self._make("prop", m.group(1), i, m.end(), self._statement_end(m.end()))
            for d in types:
                if d.open < i < d.end:
                    p.parent = d
            props.append(p)
        self.decls = sorted(spans + props, key=lambda d: d.key)

    def _statement_end(self, i):
        bare, n = self.bare, len(self.bare)
        depth, j = 0, i
        while j < n:
            c = bare[j]
            if c in OPEN:
                depth += 1
            elif c in CLOSE:
                depth -= 1
                if depth < 0:
                    return j
            elif c == "\n" and depth == 0:
                rest, prev = bare[j:j + 200].lstrip(), bare[i:j].rstrip()
                if not (rest[:1] in (".", "?", "+", "&", "|", "{") or prev[-1:] in ("=", ",", "+", "&", "|", ":", "(")):
                    return j
            j += 1
        return n


def swift_files(root, folder):
    out = []
    for dp, _, names in os.walk(os.path.join(root, folder)):
        for name in names:
            if name.endswith(".swift"):
                path = os.path.join(dp, name)
                out.append(Source(path, os.path.relpath(path, root)))
    return sorted(out, key=lambda s: s.rel)


# ---------------------------------------------------------------------------------------------------------------------
# Resolving the helpers a test calls, within its test target
# ---------------------------------------------------------------------------------------------------------------------
IDENT = re.compile(r"(?<![\w.])([A-Za-z_]\w*)")
MEMBER = re.compile(r"\.([A-Za-z_]\w*)")
ARGUMENT = re.compile(r"\s*([A-Za-z_]\w*)\s*:(?!:)")


def pieces(bare, opening):
    """What stands between the bracket at `opening` and its partner, cut at the commas that are not inside anything."""
    end = match(bare, opening) - 1
    out, depth, start = [], 0, opening + 1
    for j in range(opening + 1, end):
        c = bare[j]
        if c in OPEN or c == "<" and bare[j - 1].isalnum():
            depth += 1
        elif c in CLOSE or c == ">" and depth and bare[j - 1] != "-":
            depth -= 1
        elif c == "," and depth == 0:
            out.append(bare[start:j])
            start = j + 1
    if bare[start:end].strip():
        out.append(bare[start:end])
    return out, end + 1


def parameters(f):
    """(label, can be left out, is a closure) for each parameter of a function."""
    bare = f.file.bare
    at = bare.index(f.name, f.key) + len(f.name) if f.name != "init" else f.key + 4
    opening = bare.find("(", at)
    if opening < 0 or opening > f.open:
        return []
    out = []
    for piece in pieces(bare, opening)[0]:
        words = piece.split(":")[0].split()
        words = [w for w in words if not w.startswith("@")]
        out.append((words[0] if words else "_", "=" in piece, "->" in piece))
    return out


def fits(f, labels, trailing):
    params, i = parameters(f), 0
    for label in labels:
        while i < len(params) and params[i][0] != label:
            if not params[i][1]:
                return False
            i += 1
        if i == len(params):
            return False
        i += 1
    rest = params[i:]
    if trailing:
        closures = [p for p in rest if p[2]]
        if not closures:
            return False
        rest = [p for p in rest if not p[2]]
    return all(p[1] for p in rest)


def overloads(found, text, end):
    """Of several functions of one name, those that the call whose name ends at `end` can mean, going by its labels."""
    funcs = [f for f in found if f.kind == "func"]
    if not funcs:
        return found
    j = end
    while j < len(text) and text[j] in " \t":
        j += 1
    labels, trailing = [], False
    if j < len(text) and text[j] == "(":
        args, after = pieces(text, j)
        for a in args:
            m = ARGUMENT.match(a)
            labels.append(m.group(1) if m else "_")
        trailing = text[after:after + 3].lstrip(" ")[:1] == "{"
    elif j < len(text) and text[j] == "{":
        trailing = True
    else:
        return found
    # `for x in helper() {`: the brace after a call need not be a closure for it
    return [f for f in funcs if fits(f, labels, trailing) or fits(f, labels, False)] + [f for f in found if f.kind != "func"]


class Target:
    """The declarations of one test target, and who can see them."""

    def __init__(self, files, implicit=()):
        self.files = files
        self.implicit = set(implicit)                   # members that run because the thing exists: AppKit calls them
        self.types = collections.defaultdict(list)      # name -> type declarations (extensions too)
        self.members = collections.defaultdict(list)    # id(type decl) -> members
        self.top = collections.defaultdict(list)        # name -> funcs and properties at the top of a file
        for s in files:
            for d in s.decls:
                if d.kind.startswith("type"):
                    self.types[d.name.split(".")[-1]].append(d)
                elif d.parent is None:
                    self.top[d.name].append(d)
                elif d.parent.kind.startswith("type"):
                    self.members[id(d.parent)].append(d)
        self.own = {name for name, ds in self.types.items() if any(d.kind != "type:extension" for d in ds)}

    @staticmethod
    def visible(d, file):
        return d.file is file or not d.private

    def type_group(self, name, file):
        """The declarations of the type called `name` as seen from `file`: those in the file, else the others."""
        found = [d for d in self.types.get(name, []) if self.visible(d, file)]
        here = [d for d in found if d.file is file and d.kind != "type:extension"]
        if here:
            return here + [d for d in found if d.kind == "type:extension"]
        return found

    def members_of(self, group, name, file):
        return [m for t in group for m in self.members[id(t)] if m.name == name and self.visible(m, file)]

    def resolve(self, test, depth=5):
        """The test and the declarations of its target that it reaches, each with the way it was reached."""
        seen, out = {id(test)}, [(test, "")]
        in_play = {}                                     # type name -> group

        def chain(d):
            names, p = [], d.parent
            while p:
                if p.kind.startswith("type"):
                    names.append(p.name.split(".")[-1])
                p = p.parent
            return names

        def add(d, via, nxt):
            if id(d) not in seen and d.kind in ("func", "prop"):
                seen.add(id(d))
                out.append((d, via))
                nxt.append(d)

        frontier, foreign = [test], set()
        for name in chain(test):
            group = self.type_group(name, test.file)
            in_play[name] = group
            for m in self.members_of(group, "init", test.file):     # a suite's init runs before each of its tests
                add(m, name + ".init", frontier)
        for _ in range(depth):
            nxt = []
            types_before = len(in_play)
            for d in frontier:
                text, file = d.bare(), d.file
                mine = chain(d)
                for m in IDENT.finditer(text):
                    name = m.group(1)
                    after = text[m.end():m.end() + 2].lstrip()[:1]
                    if name in self.own and name[0].isupper():
                        group = self.type_group(name, file)
                        if not group:
                            continue
                        in_play.setdefault(name, group)
                        if after in ("(", "{"):              # made here: what its properties start as, and its init
                            for t in group:
                                for mem in self.members[id(t)]:
                                    if (mem.name == "init" or (mem.kind == "prop" and "static" not in mem.attrs)
                                            or (mem.name in self.implicit and mem.file.rel.startswith("Sources/"))):
                                        add(mem, name, nxt)
                        continue
                    found = []
                    for ty in mine:
                        found = self.members_of(in_play.get(ty) or self.type_group(ty, file), name, file)
                        if found:
                            break
                    if not found:
                        tops = [t for t in self.top.get(name, []) if self.visible(t, file)]
                        found = [t for t in tops if t.file is file] or tops
                    for f in overloads(found, text, m.end()):
                        if f is not d:
                            add(f, f.name, nxt)
            # `.name` is looked for in the target's types that are in play. A type that has just come into play may be what
            # an earlier `.name` meant, so then everything is read again.
            # … and in the extensions the target makes of other people's types, if the type has been named at all
            everything = "\n".join(x.bare() for x, _ in out)
            known = len(foreign)
            foreign = {ty for ty in self.types if ty not in self.own and re.search(r"\b%s\b" % re.escape(ty), everything)}
            for d in ([x for x, _ in out] if len(in_play) != types_before or len(foreign) != known else frontier):
                text, file = d.bare(), d.file
                for m in MEMBER.finditer(text):
                    name = m.group(1)
                    if name == "init":
                        continue
                    for ty, group in list(in_play.items()):
                        for f in overloads(self.members_of(group, name, file), text, m.end()):
                            add(f, ty + "." + name, nxt)
                    for ty in foreign:                       # extensions of types that are not the target's own
                        for f in overloads(self.members_of([x for x in self.types[ty] if self.visible(x, file)], name, file), text, m.end()):
                            add(f, ty + "." + name, nxt)
            frontier = nxt
        return out


# ---------------------------------------------------------------------------------------------------------------------
# The stand-ins: their public members, checked against the tables above
# ---------------------------------------------------------------------------------------------------------------------
def public_members(sources, type_name):
    names = {}
    for s in sources:
        for d in s.decls:
            p = d.parent
            holders = []
            while p:
                holders.append(p.name)
                p = p.parent
            if d.kind in ("func", "prop") and holders and holders[-1] == type_name and "public" in d.attrs and d.name != "init":
                names.setdefault(d.name, d)
    return names


def check_tables(testing):
    known = {
        "FakeWindowSystem": SYSTEM_REPORTS + SYSTEM_ANSWERS + SYSTEM_ANSWER_PROPERTIES + SYSTEM_OPEN + SYSTEM_NEUTRAL,
        "FakeOverlays": OVERLAY_ACTIONS + OVERLAY_NEUTRAL,
        "Harness": HARNESS_REPORTS + HARNESS_NEUTRAL,
        "ManualScheduler": OTHER_NEUTRAL, "MemoryStateStore": OTHER_NEUTRAL,
        "FakeLoginItem": OTHER_NEUTRAL + OTHER_ANSWERS["loginItem"], "FakeReleaseFeed": OTHER_NEUTRAL + OTHER_ANSWERS["releases"],
    }
    unknown = []
    for type_name, names in known.items():
        for member in public_members(testing, type_name):
            if member not in names:
                unknown.append(f"{type_name}.{member}")
    if unknown:
        sys.exit("census.py: these public members of the stand-ins are in none of its tables; look at them and add them: "
                 + ", ".join(sorted(unknown)))


def protocol_members(source, protocol):
    for d in source.decls:
        if d.kind == "type:protocol" and d.name == protocol:
            return re.findall(r"\bfunc\s+(\w+)", source.bare[d.open:d.end])
    return []


# ---------------------------------------------------------------------------------------------------------------------
# Part 1: the classes
# ---------------------------------------------------------------------------------------------------------------------
class Rules:
    def __init__(self, root):
        self.root = root
        self.test_files = {}
        self.testing = swift_files(root, "Sources/ArborTesting")
        check_tables(self.testing)
        platform = {s.rel: s for s in swift_files(root, "Sources/ArborKit/Platform")}
        events = protocol_members(platform["Sources/ArborKit/Platform/WindowSystem.swift"], "WindowSystemEvents")
        actions = [a for a in protocol_members(platform["Sources/ArborKit/Platform/OverlayPresenter.swift"], "OverlayActions")
                   if a != "perform"]
        self.events, self.actions = events, actions

        def calls(receiver, names):
            return re.compile(r"\b%s[!?]?\s*\.\s*(%s)\s*(?:\(|\{)" % (receiver, "|".join(sorted(names, key=len, reverse=True))))

        def sets(receiver, names):
            # system.cursor = …, system.echoes.keyboard = …, system.stubbornFrames[a] = …, system.strangers.append(…)
            return re.compile(
                r"\b%s[!?]?\s*\.\s*(%s)\b(?:\s*\[[^\]\n]*\]|\s*[!?]|\.\w+)*\s*(?:[-+]?=(?!=)|\.(?:append|insert|formUnion|remove\w*|merge)\()"
                % (receiver, "|".join(sorted(names, key=len, reverse=True))))

        self.patterns = [
            ("report", "system.", calls("system", SYSTEM_REPORTS)),
            ("answer", "system.", calls("system", SYSTEM_ANSWERS)),
            ("answer", "system.", sets("system", SYSTEM_ANSWER_PROPERTIES), "="),
            ("panel", "overlays.", calls("overlays", OVERLAY_ACTIONS)),
            ("report", "controller.", calls("controller", events + CONTROLLER_REPORTS)),
            ("report", "events.", calls("events", events)),
            ("panel", "controller.", calls("controller", actions)),
            ("panel", "actions.", calls("actions", actions)),
            ("answer", "controller.", sets("controller", CONTROLLER_FACTS), "="),
            ("answer", "releases.", calls("releases", ["answer"])),
            ("answer", "releases.", sets("releases", ["reply"]), "="),
            ("answer", "loginItem.", sets("loginItem", OTHER_ANSWERS["loginItem"]), "="),
        ]
        self.harness_reports = re.compile(r"(?<!system)(?<!system[!?])\s*\.\s*(%s)\s*\(" % "|".join(HARNESS_REPORTS))
        self.open_call = re.compile(r"\bsystem[!?]?\s*\.\s*open\s*\(")
        self.copying = re.compile(r"\bfor\s+\w+\s+in\s+[\w.]*system\s*\.\s*allWindows\s*\(\)")
        self.any_open = re.compile(r"(?<!func )\bopen\w*\s*\(")
        self.refuses = re.compile(r"\bminimumSize:(?!\s*(?:minimumSize\b|CGSize\s*=|\.zero\b))|\bisResizable:(?!\s*(?:isResizable\b|Bool\b|true\b))")
        # ArborTesting's own helpers that make a harness, and what they have the world do while they are at it
        self.library = {}
        for s in self.testing:
            if s.rel.endswith("/Workload.swift"):
                self.library["Workload"] = [k for k, _ in self.world(s.bare)]
        # names declared in the folders that only build on macOS
        self.mac_types = {}
        for folder in MAC_FOLDERS:
            for s in swift_files(root, folder):
                for d in s.decls:
                    if d.kind.startswith("type") and d.kind != "type:extension" and d.parent is None:
                        self.mac_types[d.name] = s.rel
        headless = set()
        for folder in ("Sources/ArborCore", "Sources/ArborKit/Controller", "Sources/ArborKit/Platform", "Sources/ArborKit/Support",
                       "Sources/ArborKit/Trace", "Sources/ArborKit/IPC", "Sources/ArborIPC", "Sources/ArborTesting"):
            for s in swift_files(root, folder):
                headless |= {d.name for d in s.decls if d.kind.startswith("type") and d.kind != "type:extension"}
        for name in headless:
            self.mac_types.pop(name, None)
        # extensions in the macOS-only folders add members to headless types (ArborArtwork draws ArborGlyph, say): by file
        self.mac_word = re.compile(r"\b(%s)\b" % "|".join(sorted(self.mac_types, key=len, reverse=True) or ["\0"]))

    def world(self, bare):
        """Every place in `bare` where the world acts or is told what to answer: (helper, kind)."""
        found = []
        # `for window in old.system.allWindows() { new.system.open(…) … }` gives a new run of Arbor the windows of the last
        # one. What is done in there copies a world; nothing happens in it.
        for m in self.copying.finditer(bare):
            o = bare.find("{", m.end())
            # the braces of a closure in the loop's own header (`.sorted(by: { … })`) are not its body
            o = body_open(bare, m.end())
            if o >= 0:
                chars = list(bare)
                blank(chars, o, match(bare, o))
                bare = "".join(chars)
        for entry in self.patterns:
            kind, prefix, pattern = entry[:3]
            suffix = entry[3] if len(entry) > 3 else ""
            for m in pattern.finditer(bare):
                # `controller.shortcut(for: .back)` asks which keys a command has; `shortcut(binding, .pressed)` is a key going down
                if prefix + m.group(1) == "controller.shortcut" and bare[m.end():m.end() + 8].lstrip().startswith("for:"):
                    continue
                found.append((prefix + m.group(1) + suffix, kind))
        for m in self.harness_reports.finditer(bare):
            found.append(("harness." + m.group(1), "report"))
        for m in self.any_open.finditer(bare):          # system.open(…) and the test targets' own open(…) helpers
            if self.refuses.search(bare[m.end() - 1:match(bare, m.end() - 1)]):
                found.append(("system.open(minimumSize:)", "answer"))
                break
        return found


APPLE = re.compile(
    r"\b(NS[A-Z]\w+|CG(?:Event|Context|Image|Color|ColorSpace|WindowList\w*|Display\w*|ScrollPhase|MomentumScrollPhase|Path)\b|CA[A-Z]\w+|"
    r"kVK_\w+|kCG\w+|kAX\w+|AX[A-Z]\w+|TIS\w+|UCKey\w+|LMGetKbdType|CFRunLoop\w*|SMAppService|IOHID\w+|CTLine\w*|CTFont\w*)")
REAL_IO = re.compile(
    r"\b(FileStateStore|SettingsFile|ControlServer|ControlEndpoint|ControlClient\s*\(|ControlClient\.(?!classify)\w+|UnixSocket|InstanceLock|"
    r"MainQueueScheduler|FileTraceSink|LogFile|FileHandle|Pipe\s*\(|Process\s*\(|mkdtemp|socket\s*\(|DispatchSource|HandClient|"
    r"FileManager\.default\s*\.\s*(?:create\w+|remove\w+|contents\w*|fileExists|attributesOfItem|setAttributes|moveItem|copyItem|isWritableFile|isReadableFile))")
WRITES = re.compile(r"\.write\s*\(\s*to(?:File)?:|Data\s*\(\s*contentsOf:|String\s*\(\s*contentsOf(?:File)?:")
STAND_INS = re.compile(r"\b(FakeWindowSystem|FakeOverlays|ManualScheduler|MemoryStateStore|FakeLoginItem|FakeReleaseFeed|MemoryTraceSink)\s*\(")
HARNESS = re.compile(r"\b(Harness|Controller|Workload|ChaosRunner)\s*\(|\bChaosRunner\.(?:replay|run)\b")
HARNESS_USE = re.compile(r"\.\s*(system|overlays|scheduler|controller)\s*\.|\bh\.run\s*\(")
TRACE_TOOL = re.compile(r"\b(TraceReplayer|TraceRecorder|TraceWriter|MemoryTraceSink|RecordingWindowSystem|RecordingOverlays|RecordingScheduler)\b|\.lastTrace\b")
BENCH = re.compile(r"\b(BenchmarkCase|CoreBenchmark)\b")
WALK = re.compile(r"\bChaosGenerator\s*\(|\bChaosRunner\.run\s*\(|\bChaos\.hunt\b|\.next\s*\(\s*runner\s*\)")
SCRIPT = re.compile(r"\bChaosAction\.script\b|\bChaosRunner\.replay\b")
CLOCK = re.compile(r"\bscheduler[!?]?\s*\.\s*(advance|runPending|fire)\s*\(")
SAMPLES = re.compile(r"\bSampleKeyLayouts\b")


def strings_of(code, bare):
    """The text that is in `code` and blanked in `bare`: the contents of string literals, line by line."""
    out, line = [], []
    for a, b in zip(code, bare):
        if a == "\n":
            out.append("".join(line))
            line = []
        else:
            line.append(a if a != b or (a == " " and line) else "\0")
    out.append("".join(line))
    return [re.sub("\0+", "\0", s).strip("\0 ") for s in out]


def chaos_lines(code, bare):
    found = []
    for text in strings_of(code, bare):
        for piece in re.split(r"\0|\\n", text):
            words = piece.split()
            if not words:
                continue
            verb = words[0]
            if verb == "open" and "min" in words[1:]:
                found.append(("system.open(minimumSize:)", "answer"))
            if verb not in CHAOS_WORDS:
                continue
            # `focus 101` is a click, `focus left` a command; `show 1000` an app, `show-all` another word altogether
            if verb in ("focus", "close", "minimize", "restore", "hide", "show", "move", "grab", "title", "space") and not (
                    len(words) > 1 and re.fullmatch(r"\\?\(?[\w.]*\)?|\d+", words[1]) and (words[1][0].isdigit() or words[1].startswith("\\("))):
                continue
            helper = CHAOS_WORDS[verb]
            kind = "panel" if helper.startswith("overlays.") else "answer" if helper.endswith("=") or helper in (
                "system.setMinimumSize", "system.setBehaviour") else "report"
            found.append((helper, kind))
    return found


class Test:
    pass


def mac_only(conds):
    return any(re.fullmatch(r"os\(macOS\)|canImport\((AppKit|Carbon|Cocoa|ApplicationServices)\)", c) for c in conds)


def not_mac(conds):
    return any(re.fullmatch(r"!\((os\(macOS\)|canImport\((AppKit|Carbon|Cocoa|ApplicationServices)\))\)", c) for c in conds)


def classify(t, rules):
    """Sets t.cls, t.sub and t.why. The order of the questions is the order of precedence."""
    bare = "\n".join(d.bare() for d, _ in t.reach)
    code = "\n".join(d.code() for d, _ in t.reach)
    world = []
    for d, via in t.reach:
        for helper, kind in rules.world(d.bare()):
            world.append((helper, kind, via))
    for name, helpers in rules.library.items():
        if re.search(r"\b%s\s*\(" % name, bare):
            world += [(h, "report", name) for h in helpers]
    if SCRIPT.search(bare) or re.search(r"\bChaosRunner\b", bare):
        world += [(h, k, "a chaos script") for h, k in chaos_lines(code, bare)]
    if SAMPLES.search(bare):
        world.append(("SampleKeyLayouts", "answer", ""))
    t.world = world
    t.opens = bool(rules.open_call.search(bare))
    t.clock = bool(CLOCK.search(bare))
    t.walk = bool(WALK.search(bare))
    harness = bool(HARNESS.search(bare) or HARNESS_USE.search(bare))
    t.harness = harness
    apple = sorted(set(APPLE.findall(bare)))
    arbor_mac = sorted(set(rules.mac_word.findall(bare)))
    t.mac_code = sorted({rules.mac_types[n] for n in arbor_mac})
    t.mac_names = arbor_mac
    helpers = sorted({h for h, _, _ in world})

    def done(cls, sub, why):
        t.cls, t.sub, t.why = cls, sub, why

    # F: only a Mac compiles it, and it calls Apple's frameworks or Arbor's macOS-only code
    if t.mac and (apple or arbor_mac):
        return done("F", "", (arbor_mac + apple)[:6])
    # E: a committed recording is replayed
    if "collab/evidence" in code and re.search(r"\bTraceReplayer\b", bare):
        return done("E", "", ["collab/evidence", "TraceReplayer"])
    # B: the subject is a stand-in or a tool
    if t.suite_names & set(TOOL_SUITES) and not any((s, t.name) in NOT_TOOL for s in t.suite_names):
        suite = sorted(t.suite_names & set(TOOL_SUITES))[0]
        return done("B", "a suite on the list of tools", [suite + ": " + TOOL_SUITES[suite]])
    if TOOL_TESTS.search(t.name) and "ScenarioExpectation" in bare:
        return done("B", "a suite on the list of tools", ["ScenarioExpectation: the `expect` lines of scenarios"])
    if "collab/evidence" in code:
        return done("B", "repository text", ["collab/evidence read, nothing replayed"])
    if TRACE_TOOL.search(bare) or re.search(r'run\(\s*"trace (on|off)', code):
        return done("B", "traces", sorted(set(m.group(0) for m in TRACE_TOOL.finditer(bare)))[:3] or ["trace on"])
    if BENCH.search(bare):
        return done("B", "benchmarks", sorted(set(BENCH.findall(bare))))
    reads_repo = "#filePath" in bare and (WRITES.search(bare) or "FileManager" in bare)
    if reads_repo and not harness and not re.search(r"\b(FileStateStore|SettingsFile|ControlServer|Process\s*\()", bare):
        return done("B", "repository text", ["#filePath"])
    # G: the real thing under POSIX and Dispatch
    io = sorted(set(re.sub(r"\s|\($", "", m.group(1)) for m in REAL_IO.finditer(bare)))
    if not reads_repo and WRITES.search(bare):
        io.append("reads or writes a file")
    if io and not (reads_repo and all(i.startswith("FileManager") for i in io)):
        return done("G", "", io[:5])
    if reads_repo:
        return done("B", "repository text", ["#filePath"])
    if STAND_INS.search(bare) and not harness:
        return done("B", "a stand-in alone", sorted(set(STAND_INS.findall(bare))))
    # D and C: Arbor's logic on stand-ins
    if t.walk:
        return done("D", "random walk", ["the chaos lab's generator"] + helpers[:8])
    kinds = {k for _, k, _ in world}
    if kinds & {"report", "panel"}:
        return done("D", "reports", helpers)
    if kinds:
        return done("D", "answers only", helpers)
    if harness:
        return done("C", "", ["Harness"] + (["open"] if t.opens else []) + (["clock"] if t.clock else []))
    return done("A", "", [])


def collect_tests(root, rules):
    tests = []
    raw = 0
    for name in sorted(os.listdir(os.path.join(root, "Tests"))):
        if not os.path.isdir(os.path.join(root, "Tests", name)):
            continue
        target = Target(swift_files(root, os.path.join("Tests", name)))
        rules.test_files[name] = target.files
        for s in target.files:
            for d in s.decls:
                if d.kind != "func" or not re.search(r"@Test\b", d.attrs):
                    continue
                raw += 1
                t = Test()
                t.decl, t.name, t.file, t.line, t.target = d, d.name, s.rel, d.line, name
                suites, p = [], d.parent
                suite_attrs = ""
                while p:
                    if p.kind.startswith("type"):
                        suites.append(p.name)
                        suite_attrs += p.attrs
                    p = p.parent
                t.suite = ".".join(reversed(suites))
                t.suite_names = set(suites)
                attrs_code = s.code[d.start:d.key]
                m = re.search(r"@Test\s*\(", d.attrs)
                t.args = ""
                if m:
                    a = d.start + m.end() - 1
                    t.args = " ".join(s.code[a + 1:match(s.bare, a) - 1].split())
                t.parameterised = "arguments:" in t.args
                traits = []
                for word in ("disabled", "enabled", "timeLimit", "bug", "tags"):
                    if re.search(r"\.%s\s*\(" % word, s.bare[d.start:d.key]):
                        traits.append(word)
                if ".serialized" in suite_attrs:
                    traits.append("serialized suite")
                if "withKnownIssue" in d.bare():
                    traits.append("withKnownIssue")
                t.traits = traits
                t.conds = d.conds
                t.mac = mac_only(d.conds)
                t.placeholder = not_mac(d.conds) and "disabled" in traits
                t.reach = target.resolve(d)
                tests.append(t)
    # `#if os(macOS) … #else @Test(.disabled(…)) func sameName() {} #endif`: one function, written twice
    real = {(t.file, t.suite, t.name) for t in tests if not t.placeholder}
    merged = [t for t in tests if not (t.placeholder and (t.file, t.suite, t.name) in real)]
    for t in merged:
        classify(t, rules)
    return merged, raw


# ---------------------------------------------------------------------------------------------------------------------
# Part 2: what the recordings hold
# ---------------------------------------------------------------------------------------------------------------------
def read_traces(root):
    folder = os.path.join(root, "collab/evidence/traces")
    traces = []
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".jsonl"):
            continue
        lines, by_hand, remark = [], 0, False
        for raw in open(os.path.join(folder, name), encoding="utf-8"):
            raw = raw.strip()
            if raw.startswith("#"):
                remark = True
                continue
            if raw:
                try:
                    lines.append(json.loads(raw))
                except ValueError:
                    pass
        if lines:
            traces.append((name[:-6], lines[0], lines[1:]))
    return traces


def fingerprints(traces):
    """For each kind of report or answer, the recordings of a real Mac that hold it."""
    seen = collections.defaultdict(set)
    counts = collections.Counter()
    kinds = collections.Counter()
    for name, header, lines in traces:
        if header.get("os") == "simulated":
            continue

        def mark(what):
            seen[what].add(name)
            counts[what] += 1

        displays = header.get("displays", [])
        if len(displays) > 1:
            mark("more than one display")
        frames = {w["id"]: w.get("frame") for w in header.get("windows", [])}
        titles = {w["id"]: w.get("title") for w in header.get("windows", [])}
        pids = {w["id"]: w.get("pid") for w in header.get("windows", [])}
        asked_focus = {}
        dragging = resizing = None
        last_press = -10
        focused_pid = pids.get(header.get("focused"))
        for o in lines:
            t = o.get("t", 0)
            for key in ("event", "action", "call", "read"):
                if key in o:
                    kinds[key + ":" + str(o[key])] += 1
            if "raw" in o:
                word = o["raw"].split()[0]
                kinds["raw:" + word] += 1
                mark("raw " + word)
                if word == "leftMouseDown":
                    last_press = t
            event = o.get("event")
            if event:
                mark("event " + event)
            if event == "changed":
                w = o["window"]
                for flag in ("minimized", "hidden", "offSpace", "fullScreen"):
                    if w.get(flag):
                        mark("changed, " + flag)
                if w.get("title") != titles.get(w["id"]):
                    mark("changed, another title")
                if o.get("user") and w.get("frame") != frames.get(w["id"]) and dragging != w["id"] and resizing != w["id"]:
                    mark("changed by somebody else, another frame, no drag")
                if not o.get("user"):
                    mark("changed, echo of Arbor's own move")
                frames[w["id"]], titles[w["id"]] = w.get("frame"), w.get("title")
            elif event == "appeared":
                frames[o["window"]["id"]] = o["window"].get("frame")
            elif event == "focused":
                if t - asked_focus.get(o["id"], -10) <= 1:
                    mark("focused, answering Arbor's focus")
                else:
                    mark("focused, not asked for by Arbor")
                    if t - last_press <= 1:
                        mark("focused, within a second of a press")
                    else:
                        mark("focused, with no press before it")
                    if pids.get(o["id"]) != focused_pid and focused_pid is not None:
                        mark("focused, a window of another app")
                focused_pid = pids.get(o["id"], focused_pid)
            elif event == "dragBegan":
                dragging = o["id"]
            elif event in ("dragEnded", "dragCancelled"):
                dragging = None
            elif event == "resizeBegan":
                resizing = o["id"]
            elif event == "resizeEnded":
                resizing = None
            elif event == "displaysChanged":
                to = o.get("to", [])
                if len(to) != len(displays) or [d.get("frame") for d in to] != [d.get("frame") for d in displays]:
                    mark("displaysChanged, a display came, went, moved or changed size")
                else:
                    mark("displaysChanged, only the room the Dock or menu bar leaves")
                displays = to
            if "action" in o:
                mark("action " + o["action"])
            call = o.get("call")
            if call:
                mark("call " + call)
            if call == "focus":
                asked_focus[o["id"]] = t
            if call == "setFrame":
                asked, took = o.get("frame"), o.get("result")
                if took is None:
                    mark("setFrame, no answer")
                elif asked:
                    if took[2] > asked[2] + 1 or took[3] > asked[3] + 1:
                        mark("setFrame, took more than asked")
                    if took[2] < asked[2] - 1 or took[3] < asked[3] - 1:
                        mark("setFrame, took less than asked")
                    if abs(took[1] - asked[1]) > 1 and took[2:] == asked[2:]:
                        mark("setFrame, stopped short of the place asked for")
                    frames[o["id"]] = took
            if "read" in o:
                mark("read " + o["read"])
    return seen, counts, kinds


# What a recording would have to hold for a helper's report to have been seen on a Mac: any of the fingerprints named.
# `differs` quotes collab/evidence/traces/README.md ("What real macOS does that FakeWindowSystem does not") where the fake, read
# today, still does otherwise than the recording.
EVIDENCE = {
    "system.open": (["event appeared"], ""),
    "system.open(minimumSize:)": (["setFrame, took more than asked"], ""),
    "system.close": (["event destroyed"], ""),
    "system.quit": (["event destroyed"], ""),
    "system.quitApp": (["event destroyed"], ""),
    "system.setMinimized": (["changed, minimized"], "row 13: on a Mac the Dock grows and `displaysChanged` follows; the fake sends one `changed`"),
    "system.setHidden": (["changed, hidden"], "row 11: on a Mac unhiding first moves windows that were nearly off screen; the fake changes "
                         "the flag only"),
    "system.unhideApp": (["changed, hidden"], ""),
    "system.finishRestoring": (["changed, minimized", "changed, hidden"], ""),
    "system.restoresLate=": (["changed, minimized", "changed, hidden"], ""),
    "system.setOnActiveSpace": (["changed, offSpace"], ""),
    "system.setFullScreen": (["changed, fullScreen"], ""),
    "system.userMove": (["changed by somebody else, another frame, no drag"], ""),
    "system.moveSilently": (["changed by somebody else, another frame, no drag"], ""),
    "system.report": (["changed by somebody else, another frame, no drag"], ""),
    "system.setTitle": (["changed, another title"], ""),
    "system.userFocus": (["focused, within a second of a press"],
                         "the fake also announces the app (`applicationActivated`), which no recording holds"),
    "system.userClick": (["event pointerPressed"], ""),
    "system.click": (["event pointerPressed"], ""),
    "system.comesForward": (["read secondsSinceClickOrModifierKey"], ""),
    "system.settleFocus": (["focused, answering Arbor's focus"], ""),
    "system.finishSlowFocus": (["focused, answering Arbor's focus"], ""),
    "system.focusIsSlow=": (["focused, answering Arbor's focus"], ""),
    "system.defersFocus=": (["focused, answering Arbor's focus"], ""),
    "system.backgroundFocus": (["focused, a window of another app"], ""),
    "system.userSwitchesApp": (["event keyboardFocusMoved"], ""),
    "system.userFocusesNothing": (["event keyboardFocusMoved", "event applicationActivated"], ""),
    "system.sheetTakesTheKeyboard": (["event keyboardFocusMoved"], ""),
    "system.activate": (["event applicationActivated"], ""),
    "system.activateApp": (["event applicationActivated"], ""),
    "system.drag": (["event dragBegan"], "rows 6 and 7: on a Mac `dragBegan` comes 0.3 s late with the window already moved, frames lag "
                    "the pointer, and a press on a window that is not focused focuses it first; the fake does none of it"),
    "system.beginDrag": (["event dragBegan"], "rows 6 and 7, as for `drag`"),
    "system.grab": (["event dragBegan"], "rows 6 and 7, as for `drag`"),
    "system.moveDrag": (["event dragMoved"], "row 6: on a Mac `dragMoved` and `changed` are not in step; the fake sends them in pairs"),
    "system.carry": (["event dragMoved"], "row 6, as for `moveDrag`"),
    "system.holdDrag": (["event dragMoved"], ""),
    "system.endDrag": (["event dragEnded"], ""),
    "system.letGo": (["event dragEnded"], ""),
    "system.holdModifierKeys": (["read modifierKeysDown"], ""),
    "system.heldModifiers=": (["read modifierKeysDown"], ""),
    "system.loseTheReleaseOfTheDrag": (["event dragCancelled"], ""),
    "system.loseTheRelease": (["event dragCancelled"], ""),
    "system.dragAndLoseTheRelease": (["event dragCancelled"], ""),
    "system.userResize": (["event resizeBegan"], "rows 7, 9 and 15: a Mac focuses first, stalls in mid-drag, and reports nothing for a "
                          "window that cannot be resized"),
    "system.releaseMouse": (["event resizeEnded"], ""),
    "system.setDisplays": (["displaysChanged, a display came, went, moved or changed size"], ""),
    "system.displayList=": (["displaysChanged, a display came, went, moved or changed size"], ""),
    "system.setListed": (["event windowFound"], ""),
    "system.openUnlisted": (["event windowFound"], ""),
    "system.openTab": (["event windowReplaced"], ""),
    "system.selectTab": (["event windowReplaced"], ""),
    "system.closeTab": (["event windowReplaced"], ""),
    "system.setUnresponsive": (["setFrame, no answer"], ""),
    "system.appsSettle": (["changed by somebody else, another frame, no drag"], ""),
    "system.stubbornFrames=": (["changed by somebody else, another frame, no drag"], ""),
    "system.appsReact": (["changed, echo of Arbor's own move"], ""),
    "system.holdsEchoes=": (["changed, echo of Arbor's own move"], ""),
    "system.echoes=": (["changed, echo of Arbor's own move"], ""),
    "system.setBehaviour": (["setFrame, took more than asked", "setFrame, took less than asked"], ""),
    "system.setMinimumSize": (["setFrame, took more than asked"], ""),
    "system.setMaximumSize": (["setFrame, took less than asked"], ""),
    "system.setSizeStep": (["setFrame, took more than asked"], ""),
    "system.willSetFrame=": (["setFrame, took more than asked"], ""),
    "system.cursor=": (["call cursorLocation"], ""),
    "system.mouseDown=": (["call isMouseButtonDown"], ""),
    "system.focused=": (["call focusedWindow"], ""),
    "system.secondsSinceInput=": (["read secondsSinceClickOrModifierKey"], ""),
    "system.type": (["read inputActivity"], ""),
    "system.keyDown": (["read inputActivity"], ""),
    "system.keyUp": (["read inputActivity"], ""),
    "system.hold": (["read isHolding"], ""),
    "system.strangers=": (["read stackedWindows"], ""),
    "system.stackingIsUnknown=": (["read windowsFrontToBack"], ""),
    "system.openStrayDialog": (["read strayDialogsWaiting"], ""),
    "system.isDenied=": (["event accessibilityWasRefused", "read mayUseAccessibility"], ""),
    "system.flagLags=": (["read mayUseAccessibility"], ""),
    "system.refusesTaps=": (["read mayUseAccessibility"], ""),
    "system.missingApps=": (["call openApplication"], ""),
    "system.unlaunchableApps=": (["call launchApp"], ""),
    "system.ignoresMoveTogether=": ([], ""),
    "system.renumber": ([], ""),
    "system.forgetSession": ([], ""),
    "harness.keyDown": (["event shortcut"], ""),
    "harness.keyUp": (["event shortcut"], ""),
    "harness.keyRepeat": (["event shortcut"], ""),
    "harness.revokeAccessibility": (["event accessibilityWasRefused", "read mayUseAccessibility"], ""),
    "harness.grantAccessibility": (["read mayUseAccessibility"], ""),
    "harness.watchAccessibility": (["read mayUseAccessibility"], ""),
    "overlays.clickTile": (["action tileActivated"], ""),
    "overlays.dragSeam": (["action seamDragged"], ""),
    "overlays.clickOutline": (["action peekOutlineClicked"], ""),
    "overlays.dismissCheatSheet": (["action cheatSheetDismissed"], ""),
    "overlays.submitName": ([], ""),
    "overlays.cancelName": ([], ""),
    "overlays.typeInFinder": ([], ""),
    "overlays.moveFinderSelection": ([], ""),
    "overlays.chooseInFinder": (["action finderChose"], ""),
    "overlays.dismissFinder": (["action finderDismissed"], ""),
    "overlays.clickMinimap": (["action minimapClicked"], ""),
    "controller.shortcut": (["event shortcut"], ""),
    "controller.gesture": ([], ""),
    "controller.callSignalsChanged": ([], ""),
    "controller.keyboardLayoutChanged": ([], ""),
    "controller.settingsFileMayHaveChanged": ([], ""),
    "controller.sessionIsEnding": ([], ""),
    "controller.accessibilityGranted=": (["read mayUseAccessibility"], ""),
    "controller.accessibilityProbe=": (["read mayUseAccessibility"], ""),
    "controller.systemFacts=": ([], ""),
    "controller.systemShortcuts=": ([], ""),
    "controller.registeredBindings=": ([], ""),
    "controller.refusedBindings=": ([], ""),
    "controller.nameOfApp=": ([], ""),
    "releases.answer": ([], ""), "releases.reply=": ([], ""),
    "loginItem.status=": ([], ""), "loginItem.refuses=": ([], ""), "loginItem.statusAfterRefusal=": ([], ""),
    "SampleKeyLayouts": ([], ""),
}
EVENT_WORDS = {
    "windowAppeared": "event appeared", "windowDestroyed": "event destroyed", "windowChanged": "event changed",
    "windowFocused": "event focused", "tileActivated": "action tileActivated", "seamDragged": "action seamDragged",
}
# Checked otherwise than by a recording: a test of class F compares the stand-in with what macOS says, on every run on a Mac.
CHECKED_BY_A_TEST = {"SampleKeyLayouts": "LayoutShortcutTests.theSampleLayoutsAreWhatMacOSHas (class F) compares them with macOS's own layouts"}
# Not macOS: what these stand for is GitHub's answer, or a file of Arbor's own.
NOT_MACOS = {"releases.answer", "releases.reply=", "system.ignoresMoveTogether=", "system.forgetSession"}


FAITHFUL_CITES = "collab/evidence/ax-events.txt"      # what FaithfulFakeTests says it holds the fake to


# The same situation brought about on real windows by one of the two runs CI makes on a Mac. They check what Arbor ends up
# doing, not what macOS reported on the way. Each pattern is looked for in Sources/arbor-e2e or in e2e-drag.sh.
ON_REAL_WINDOWS = {
    "system.open": r'tell\("open ', "system.open(minimumSize:)": r'tell\("min-size ', "system.setMinimumSize": r'tell\("min-size ',
    "system.close": r'tell\("close ', "system.setMinimized": r'tell\("minimize ', "system.setHidden": r'tell\("hide',
    "system.userMove": r'tell\("move ', "system.appsSettle": r'tell\("insist ', "system.stubbornFrames=": r'tell\("insist ',
    "system.openTab": r'open\("tab"', "system.selectTab": r'tell\("select ', "system.closeTab": r'open\("tab"',
    "system.setFullScreen": r'tell\("full-screen ', "system.setUnresponsive": r'tell\("hang ',
    "system.userSwitchesApp": r'other\.send\("activate"', "system.comesForward": r'other\.send\("activate"',
    "system.activate": r'other\.send\("activate"', "system.activateApp": r'other\.send\("activate"',
    "system.backgroundFocus": r'tell\("key ', "system.userFocus": r'tell\("key ',
    "system.drag": r"^drag \$\(titlebar_of", "system.beginDrag": r"^drag \$\(titlebar_of", "system.moveDrag": r"^drag \$\(titlebar_of",
    "system.endDrag": r"^release$", "system.grab": r"^drag \$\(titlebar_of", "system.carry": r"^drag \$\(titlebar_of",
    "system.letGo": r"^release$", "system.userResize": r"drag the right edge of the docked window",
    "controller.settingsFileMayHaveChanged": r"func editSettings",
}
# A claim of collab/evidence/gestures-latest.txt that makes the same gesture with real input.
CLAIMS = {
    "system.drag": "drag a window to the left screen edge", "system.beginDrag": "drag a window to the left screen edge",
    "system.moveDrag": "drag a window to the left screen edge", "system.endDrag": "drag a window to the left screen edge",
    "system.setMinimized": "minimize a docked window and bring it back", "system.setHidden": "hide the app and show it again",
    "system.close": "close a docked window", "overlays.clickTile": "a click on the tile goes in",
    "overlays.dragSeam": "drag the gap between two windows", "system.userResize": "drag a docked window's own edge",
    "system.setFullScreen": "a docked window goes full screen and comes back",
    "system.comesForward": "switching to an app whose window is out of view brings it into view",
    "system.userSwitchesApp": "switching to an app whose window is out of view brings it into view",
    "system.open(minimumSize:)": "a window that cannot shrink to its slot becomes a tile",
}


def cited(testing_sources, root):
    """For each helper of the fakes: the recordings its doc comment or body cites, and whether the file is in the repository."""
    out = {}
    pattern = re.compile(r"collab/evidence/[\w./*-]+|seen on macOS \d+|recorded on macOS \d+|the order seen on macOS \d+", re.I)
    for s in testing_sources:
        for d in s.decls:
            if d.kind not in ("func", "prop"):
                continue
            # the doc comment stands right above the declaration
            head = s.src[:d.start].rstrip().split("\n")
            doc = []
            while head and head[-1].lstrip().startswith("//"):
                doc.append(head.pop())
            text = "\n".join(doc) + s.src[d.start:d.end]
            hits = sorted(set(pattern.findall(text)))
            if hits:
                out[d.name] = hits
    return out


def gesture_claims(root):
    path = os.path.join(root, "collab/evidence/gestures-latest.txt")
    claims, current = [], None
    head = ""
    if not os.path.exists(path):
        return head, claims
    for line in open(path, encoding="utf-8"):
        if not head and line.startswith("#"):
            head = line.strip("# \n")
        if line.startswith("▸ "):
            current = [line[2:].strip(), 0, 0]
            claims.append(current)
        elif current and line.startswith("  ✔"):
            current[1] += 1
        elif current and line.startswith("  ✘"):
            current[2] += 1
    return head, claims


# ---------------------------------------------------------------------------------------------------------------------
# Part 3: the code only a Mac can run, and who runs it
# ---------------------------------------------------------------------------------------------------------------------
def count_branches(bare):
    """if, guard, while, and each `case` and `default` of a switch. Not counted: `??`, `?:`, `for … where`, `catch`."""
    counts = collections.Counter()
    for m in re.finditer(r"\b(if|guard|while|case)\b", bare):
        word = m.group(1)
        if word == "if" and bare[max(0, m.start() - 1):m.start()] == "#":
            continue
        if word == "case":
            # `if case`, `guard case`, `for case` were counted with their keyword or are no branch; the `case` of an enum's
            # declaration has no colon after its pattern
            if re.search(r"\b(if|guard|while|for)\s*$|,\s*$", bare[max(0, m.start() - 12):m.start()]):
                continue
            depth, j, colon = 0, m.end(), False
            while j < len(bare):
                c = bare[j]
                if c in OPEN:
                    depth += 1
                elif c in CLOSE:
                    depth -= 1
                    if depth < 0:
                        break
                elif c == ":" and depth == 0:
                    colon = True
                    break
                elif c == "\n" and depth == 0 and not bare[m.end():j].rstrip().endswith(","):
                    break
                j += 1
            if not colon:
                continue
        counts[word] += 1
    counts["case"] += len(re.findall(r"\bdefault\s*:", bare))
    return counts


def lines_of_code(code):
    return sum(1 for line in code.split("\n") if line.strip())


# What has to be true of a run for it to get into a file at all. Each entry: alternatives, each a list of features that must
# all hold; [] is "any launch of the app with Accessibility". Read off Sources/ArborKit/App/ArborApp.swift and the callers of
# each type; ANCHORS below are the lines this reading rests on, and the script stops if one of them is gone.
#   hotkeys, status, prompt   the run switches ARBOR_NO_HOTKEYS, ARBOR_NO_STATUS_ITEM, ARBOR_NO_PROMPT off
#   allpids                   the run does not limit Arbor to its own test processes
#   motion                    the run switches macOS's Reduce Motion off (the hosted Macs come with it on: docs/TESTING.md)
#   watchdog                  the run leaves the watchdog on
#   tile                      a window refuses its slot
#   hold                      a key is pressed and kept down
#   drag                      the real pointer drags something
#   cmd:x                     the command x is sent;  text:x  the script mentions x
WIRING = {
    "Sources/ArborKit/AX/AXHelpers.swift": ([[]], ""),
    "Sources/ArborKit/AX/AXWindowSystem.swift": ([[]], "whatever the three test windows and one display do not bring about is not entered"),
    "Sources/ArborKit/AX/AXWindowSystem+Input.swift": ([[]], "`inputActivity`; `isHolding` only with a shortcut held"),
    "Sources/ArborKit/AX/AXWindowSystem+Launch.swift": ([["text:layout --open"]], ""),
    "Sources/ArborKit/AX/AXWindowSystem+Opening.swift": ([["cmd:summon"]], ""),
    "Sources/ArborKit/AX/AXWindowSystem+StackedWindows.swift": ([[]], ""),
    "Sources/ArborKit/AX/AXWindowSystem+Stacking.swift": ([["cmd:pin"], ["cmd:summon"]], ""),
    "Sources/ArborKit/AX/ScreenGeometry.swift": ([[]], ""),
    "Sources/ArborKit/UI/AppKitOverlays.swift": ([[]], "panels are shown; no tile is clicked and no gap handle dragged"),
    "Sources/ArborKit/UI/AppKitOverlays+HeadsUp.swift": ([["cmd:show-shortcuts"], ["hotkeys"], ["status"], ["drag"]], ""),
    "Sources/ArborKit/UI/AppKitOverlays+Motion.swift": ([[]], ""),
    "Sources/ArborKit/UI/ArborArtwork.swift": ([["status"], ["prompt"], ["cmd:welcome"], ["cmd:check-setup"]], ""),
    "Sources/ArborKit/UI/BackdropPanel.swift": ([[]], ""),
    "Sources/ArborKit/UI/CheatSheetPanel.swift": ([["cmd:show-shortcuts"]], ""),
    "Sources/ArborKit/UI/ContinuousCorners.swift": ([[]], ""),
    "Sources/ArborKit/UI/FinderPanel.swift": ([["cmd:find"]], "it comes and goes; no key is typed into it"),
    "Sources/ArborKit/UI/FocusRingPanel.swift": ([[]], ""),
    "Sources/ArborKit/UI/HeadsUpPanel.swift": ([["hotkeys"], ["status"], ["drag"]],
                                               "the hint after the first dock by a real drag shows; nothing looks at it"),
    "Sources/ArborKit/UI/MinimapPanel.swift": ([["cmd:minimap"]], ""),
    "Sources/ArborKit/UI/NamePanel.swift": ([["cmd:ask-name"], ["hotkeys", "text:ctrl+opt+n"]], ""),
    "Sources/ArborKit/UI/Onboarding.swift": ([["prompt"], ["cmd:welcome"], ["cmd:check-setup"]], ""),
    "Sources/ArborKit/UI/PeekOutlinePanel.swift": ([["hotkeys", "hold"]], ""),
    "Sources/ArborKit/UI/SettingsListViews.swift": ([["cmd:settings-window"]], "the window opens on one pane; nothing in it is clicked"),
    "Sources/ArborKit/UI/SettingsViews.swift": ([["cmd:settings-window"]], "the window opens on one pane; nothing in it is clicked"),
    "Sources/ArborKit/UI/SettingsWindow.swift": ([["cmd:settings-window"]], ""),
    "Sources/ArborKit/UI/Stage.swift": ([["motion"]], ""),
    "Sources/ArborKit/UI/StageDirector.swift": ([[]], "with Reduce Motion on `play` returns at its first line; what keeps pictures fresh runs"),
    "Sources/ArborKit/UI/StatusMenu.swift": ([["status"]], ""),
    "Sources/ArborKit/UI/TileDrawing.swift": ([["tile"]], ""),
    "Sources/ArborKit/UI/UpdateWindow.swift": ([["cmd:check-for-updates"]], ""),
    "Sources/ArborKit/UI/WindowPictures.swift": ([[]], "pictures are taken; none is shown, for want of a stage"),
    "Sources/ArborKit/Input/DesktopProbe.swift": ([["hotkeys", "text:guardDesktopClicks"]], ""),
    "Sources/ArborKit/Input/EventTap.swift": ([["hotkeys"]], ""),
    "Sources/ArborKit/Input/GestureTap.swift": ([["hotkeys"]], ""),
    "Sources/ArborKit/Input/HotKeyCenter.swift": ([["hotkeys"]], ""),
    "Sources/ArborKit/Input/KeyboardLayout.swift": ([[]], ""),
    "Sources/ArborKit/Input/PointerInput.swift": ([["hotkeys"]], ""),
    "Sources/ArborKit/Input/RectangleFramer.swift": ([["hotkeys"]], ""),
    "Sources/ArborKit/Input/SystemShortcutReader.swift": ([[]], ""),
    "Sources/ArborKit/Input/WindowList.swift": ([["hotkeys"]], ""),
    "Sources/ArborKit/App/ArborApp.swift": ([[]], "not what the switches keep off: shortcuts, taps, the menu bar item, the welcome window; "
                                            "nor URLs, About, rescue's alert"),
    "Sources/ArborKit/App/ArborEnvironment.swift": ([[]], ""),
    "Sources/ArborKit/App/CallSensor.swift": ([["allpids", "text:holdStillWhile"]], ""),
    "Sources/ArborKit/App/FrontmostAppWatcher.swift": ([[]], ""),
    "Sources/ArborKit/App/LaunchArguments.swift": ([[]], "the way through; `--version` and `--launch-at-login` by scripts/candidate-check.sh "
                                                   "and install.sh, by hand"),
    "Sources/ArborKit/App/MacFacts.swift": ([["cmd:doctor"], ["cmd:check-setup"], ["cmd:welcome"], ["prompt"], ["allpids"]], ""),
    "Sources/ArborKit/App/ProcessGuards.swift": ([[]], ""),
    "Sources/ArborKit/App/SettingsWatcher.swift": ([[]], ""),
    "Sources/ArborKit/App/SystemLoginItem.swift": ([["cmd:settings-window"], ["cmd:launch-at-login"], ["text:--launch-at-login"]],
                                                   "its status is read; nothing is switched"),
    "Sources/ArborKit/App/Watchdog.swift": ([["watchdog"]], ""),
    "Sources/ArborKit/IPC/ControlEndpoint.swift": ([[]], ""),
    "Sources/ArborKit/IPC/ControlServer.swift": ([[]], ""),
    "Sources/Arbor/main.swift": ([[]], ""),
    "Sources/arborctl/main.swift": ([["ctl"]], ""),
    "Sources/ArborTestWindows/Commands.swift": ([[]], ""),
    "Sources/ArborTestWindows/main.swift": ([[]], ""),
}
# One call that an automatic run does make into a file whose work it otherwise leaves alone.
SIDE_DOORS = {
    "Sources/ArborKit/Input/EventTap.swift": "`EventTap.isPermitted()` is asked at launch (a tap made and thrown away); no tap is installed",
    "Sources/ArborKit/UI/PeekOutlinePanel.swift": "told at every layout that there is no outline to show",
    "Sources/ArborKit/UI/NamePanel.swift": "told at every layout that there is no field to show",
    "Sources/ArborKit/UI/UpdateWindow.swift": "made at launch, never shown",
}
# The members those side doors lead to, counted as run.
SIDE_DOOR_MEMBERS = {
    "Sources/ArborKit/Input/EventTap.swift": ["isPermitted", "refusal"],
    "Sources/ArborKit/UI/PeekOutlinePanel.swift": ["update", "removeAll"],
    "Sources/ArborKit/UI/NamePanel.swift": ["update", "removeAll"],
}
# Following names credits these to EventTapThreadTests, which never starts a tap (two of its tests say so in their names:
# aTapThatIsNeverStartedIsNotInstalled, aTapThatIsNotInstalledCannotBeResumed). Without a port each caller returns before them.
NOT_BY_TESTS = {
    "Sources/ArborKit/Input/EventTap.swift": ["start", "install", "handle", "eventTapCallback", "act", "switchOn", "stopAfterCurrentEvent"],
}
ANCHORS = [
    ("Sources/ArborKit/App/ArborApp.swift", r"if !environment\.noHotkeys \{\s*let input = PointerInput\("),
    ("Sources/ArborKit/App/ArborApp.swift", r"let bindings = environment\.noHotkeys \? \[\] : controller\.activeBindings"),
    ("Sources/ArborKit/App/ArborApp.swift", r"if !environment\.noStatusItem \{ statusMenu = StatusMenu\("),
    ("Sources/ArborKit/App/ArborApp.swift", r"if environment\.onlyPIDs == nil \{\s*callSensor = CallSensor"),
    ("Sources/ArborKit/App/ArborApp.swift", r"if !environment\.noPrompt, let page = controller\.pageToWelcomeOn\(\)"),
    ("Sources/ArborKit/App/ArborApp.swift", r"thoroughly \? EventTap\.isPermitted\(\)"),
    ("Sources/ArborKit/UI/StageDirector.swift", r"guard !NSWorkspace\.shared\.accessibilityDisplayShouldReduceMotion else"),
    ("Sources/arbor-e2e/main.swift", r'environment\["ARBOR_NO_HOTKEYS"\] = "1"'),
    ("Sources/arbor-e2e/main.swift", r'environment\["ARBOR_NO_STATUS_ITEM"\] = "1"'),
    ("Sources/arbor-e2e/main.swift", r'environment\["ARBOR_NO_PROMPT"\] = "1"'),
    ("Sources/arbor-e2e/main.swift", r'environment\["ARBOR_ONLY_PIDS"\] ='),
    ("scripts/mac-shell/lib.sh", r"ARBOR_NO_PROMPT=1 ARBOR_DEBUG=1 ARBOR_NO_HOTKEYS=1 ARBOR_NO_STATUS_ITEM=1"),
    ("scripts/mac-shell/lib.sh", r"ARBOR_NO_WATCHDOG=1 \"\$@\""),
    (".github/workflows/ci.yml", r"\./scripts/e2e\.sh --full-screen"),
    (".github/workflows/ci.yml", r"\./scripts/mac-shell/e2e-drag\.sh"),
    (".github/workflows/ci.yml", r"test swift test"),
    (".github/workflows/ci.yml", r"\./scripts/sim-smoke\.sh"),
    (".github/workflows/mac-shell.yml", r"on:\s*workflow_dispatch:"),
    ("scripts/sim-smoke.sh", r"\./scripts/cli-smoke\.sh"),
    ("docs/TESTING.md", r"Reduce Motion is on"),
]
NOT_RUNS = re.compile(r"^(lib.*|run|run-list|rehearse|sweep|compile|compile-tools|e2e|e2e-drag|check-harness|desktop-facts)\.sh$")


def read(root, rel):
    return open(os.path.join(root, rel), encoding="utf-8").read()


def shell_features(text):
    # remarks say what a script does not do as often as what it does
    text = "\n".join(line for line in text.split("\n") if not line.lstrip().startswith("#"))
    f = set()
    if re.search(r"^\s*(if ! )?arbor_start(_apps)?\b", text, re.M) or re.search(r'ARBOR_BIN/Arbor"|Arbor\.app', text):
        f.add("launch")
    for word, name in (("hotkeys", "HOTKEYS"), ("status", "STATUS_ITEM"), ("prompt", "PROMPT"), ("watchdog", "WATCHDOG")):
        if "ARBOR_NO_%s=0" % name in text:
            f.add(word)
    if re.search(r"Arbor\.app", text) and re.search(r"\bopen\b", text):
        f.add("watchdog")           # a bundle opened as a person opens it has everything on
    if re.search(r"macos_reduce_motion off|reduce_motion false", text):
        f.add("motion")
    if re.search(r"arbor_start_apps all|session=all", text):
        f.add("allpids")
    if re.search(r"--down\b|hold-space", text):
        f.add("hold")
    if re.search(r"--min-size|\btile_of\b", text):
        f.add("tile")
    if re.search(r"^\s*drag\s", text, re.M):
        f.add("drag")
    if re.search(r"\bctl\b|arborctl", text):
        f.add("ctl")
    for verb in re.findall(r"(?:\bctl|\bask|arborctl\"?)\s+([a-z][a-z-]+)", text):
        f.add("cmd:" + verb)
    return f, text


def e2e_features(root):
    text = "\n".join(s.code for s in swift_files(root, "Sources/arbor-e2e"))
    f = {"launch"}
    for word, name in (("hotkeys", "HOTKEYS"), ("status", "STATUS_ITEM"), ("prompt", "PROMPT"), ("watchdog", "WATCHDOG")):
        if 'environment["ARBOR_NO_%s"] = "1"' % name not in text:
            f.add(word)
    if 'environment["ARBOR_ONLY_PIDS"]' not in text:
        f.add("allpids")
    if "min-size" in text:
        f.add("tile")
    for m in re.finditer(r'(?:send\(|step\("[^"]*",\s*)"([a-z][a-z-]+)', text):
        f.add("cmd:" + m.group(1))
    return f, text


def satisfied(alternatives, features, text):
    if "launch" not in features:
        return False
    for needs in alternatives:
        if all((n[5:] in text) if n.startswith("text:") else (n in features) for n in needs):
            return True
    return False


def real_code(root, rules, tests):
    for rel, pattern in ANCHORS:
        if not re.search(pattern, read(root, rel)):
            sys.exit(f"census.py: {rel} no longer holds /{pattern}/, which the table of real code rests on: read it again")
    sources = [s for folder in REAL_FOLDERS for s in swift_files(root, folder)]
    missing = [s.rel for s in sources if s.rel not in WIRING and not s.rel.startswith("Sources/arbor-e2e/")]
    if missing:
        sys.exit("census.py: no entry in WIRING for " + ", ".join(missing))
    runs = {"e2e": e2e_features(root)}
    lib = shell_features(read(root, "scripts/mac-shell/lib.sh"))[0]
    by_hand = {}
    for name in sorted(os.listdir(os.path.join(root, "scripts/mac-shell"))):
        if name.endswith(".sh"):
            f, text = shell_features(read(root, "scripts/mac-shell/" + name))
            if name == "e2e-drag.sh":
                runs["e2e-drag"] = (f | {"ctl"}, text)      # lib.sh asks through arborctl
            elif not NOT_RUNS.match(name):
                by_hand[name] = (f, text)
    # What the tests of class F reach in the macOS-only sources, member by member: the same following of names that finds a
    # test's helpers, carried on into the sources. Generous still: a name that is reached is counted whole, whichever of its
    # branches run. What AppKit and SwiftUI call by themselves once a view exists and is drawn is counted with it.
    mac_sources = [s for s in sources if any(s.rel.startswith(f) for f in MAC_FOLDERS)]
    drawn = ("draw", "isFlipped", "layout", "updateLayer", "wantsUpdateLayer", "intrinsicContentSize", "body", "makeNSView",
             "updateNSView", "viewDidChangeEffectiveAppearance", "display", "action")
    reached_lines = collections.defaultdict(set)
    reached_decls = collections.defaultdict(dict)
    reached_by = collections.defaultdict(set)
    for name, files in rules.test_files.items():
        mine = [t for t in tests if t.cls == "F" and t.target == name]
        if not mine:
            continue
        both = Target(files + mac_sources, implicit=drawn)
        for t in mine:
            for d, _ in both.resolve(t.decl, depth=12):
                if d.file in mac_sources and d.name not in NOT_BY_TESTS.get(d.file.rel, ()):
                    first, last = d.file.line(d.start), d.file.line(d.end - 1)
                    reached_lines[d.file.rel].update(range(first, last + 1))
                    reached_decls[d.file.rel][id(d)] = d
                    reached_by[d.file.rel].add(t)
    io_tests = collections.defaultdict(set)
    for t in tests:
        if t.cls == "G":
            text = "\n".join(d.bare() for d, _ in t.reach)
            for n in ("ControlServer", "ControlEndpoint"):
                if re.search(r"\b%s\b" % n, text):
                    io_tests["Sources/ArborKit/IPC/%s.swift" % n].add(t)
    rows = []
    for s in sources:
        loc = lines_of_code(s.code)
        branches = count_branches(s.bare)
        row = {"file": s.rel, "loc": loc, "branches": sum(branches.values()), "kinds": branches}
        code_lines = s.code.split("\n")
        door = set()
        for d in s.decls:
            if d.kind == "func" and d.name in SIDE_DOOR_MEMBERS.get(s.rel, ()):
                door.update(range(s.line(d.start), s.line(d.end - 1) + 1))
                if id(d) not in reached_decls[s.rel]:
                    row["door_branches"] = row.get("door_branches", 0) + sum(count_branches(d.bare()).values())
        door_lines = sum(1 for n in door - reached_lines[s.rel] if code_lines[n - 1].strip())
        f_lines = sum(1 for n in reached_lines[s.rel] if code_lines[n - 1].strip())
        f_branches = sum(sum(count_branches(d.bare()).values()) for d in reached_decls[s.rel].values())
        holders = collections.Counter((d.parent.name if d.parent else d.name) for d in reached_decls[s.rel].values())
        row["f_tests"], row["f_names"], row["f_lines"] = reached_by[s.rel], [n for n, _ in holders.most_common()], f_lines
        row["g_tests"] = io_tests.get(s.rel, set())
        if s.rel.startswith("Sources/arbor-e2e/"):
            row["auto"], row["hand"], row["note"] = ["e2e (it is the runner)"], [], ""
        else:
            alternatives, note = WIRING[s.rel]
            row["auto"] = [name for name, (f, text) in runs.items() if satisfied(alternatives, f, text)]
            row["hand"] = sorted((name for name, (f, text) in by_hand.items() if satisfied(alternatives, f, text)),
                                 key=lambda n: (n != "input-taps.sh" or "/Input/" not in s.rel, n))
            row["note"] = note if row["auto"] else SIDE_DOORS.get(s.rel, "")
        if s.rel == "Sources/arborctl/main.swift":
            row["auto"] = ["cli-smoke.sh and watch-smoke.sh (both platforms)"] + row["auto"]
        entered = bool(row["auto"] or row["g_tests"])
        row["unrun_loc"] = 0 if entered else loc - f_lines - door_lines
        row["unrun_branches"] = 0 if entered else max(0, row["branches"] - f_branches - row.get("door_branches", 0))
        row["verdict"] = ("automatic" if entered and not row["note"] else "automatic, in part" if entered
                          else "in part by tests, the rest by hand" if row["f_tests"] and row["hand"]
                          else "in part by tests, the rest by nothing" if row["f_tests"]
                          else "by hand only" if row["hand"] else "nothing")
        rows.append(row)
    return rows, runs, by_hand


# ---------------------------------------------------------------------------------------------------------------------
# Printing
# ---------------------------------------------------------------------------------------------------------------------
def table(header, rows, out, align=None):
    out.append("| " + " | ".join(header) + " |")
    out.append("|" + "|".join(("---:" if align and align[i] == "r" else "---") for i in range(len(header))) + "|")
    for r in rows:
        out.append("| " + " | ".join(str(c) for c in r) + " |")
    out.append("")


def opens_after_start(t):
    """Whether a window is opened once Arbor runs: `h.system.open(` after `h.start()`, or after a helper that starts Arbor, and
    not before a later `h.start()` of the same `h` (a second harness that is still being set up)."""
    started = re.compile(r"(?:\b(\w+)\s*)?\.\s*start\s*\(\s*\)")
    opened = re.compile(r"(?:\b(\w+)[!?]?\s*\.\s*)?\bsystem[!?]?\s*\.\s*open\s*\(|(?<![\w.])(h)\s*\.\s*open\w*\s*\(")
    starters = {d.name for d, _ in t.reach[1:] if d.kind == "func" and d.name != "init" and started.search(d.bare())}
    made = {via for d, via in t.reach[1:] if d.name == "init" and started.search(d.bare())}
    for d, _ in t.reach:
        text = d.bare()
        starts = [(m.start(), m.group(1)) for m in started.finditer(text)]
        before = [p for p, _ in starts]
        if d is t.decl and (starters or made):
            before += [m.start() for m in re.finditer(r"\b(%s)\s*[({]" % "|".join(map(re.escape, starters | made)), text)]
        if not before:
            continue
        for m in opened.finditer(text):
            who = m.group(1) or m.group(2)
            if m.start() > min(before) and not any(p > m.start() and r == who for p, r in starts):
                return True
    return False


def helper_table(root, rules, tests):
    traces = read_traces(root)
    seen, counts, kinds = fingerprints(traces)
    real = [n for n, h, _ in traces if h.get("os") != "simulated"]
    citations = cited(rules.testing, root)
    faithful = set()
    for t in tests:
        if "FaithfulFakeTests" in t.suite_names:
            faithful |= {h for h, _, _ in t.world}
            if t.opens:
                faithful.add("system.open")
    resting = collections.defaultdict(set)
    everywhere = collections.defaultdict(set)
    kind_of = {}
    for t in tests:
        for h, k, _ in t.world:
            kind_of[h] = k
            everywhere[h].add(t)
            if t.cls == "D":
                resting[h].add(t)
        if t.opens and opens_after_start(t):
            everywhere["system.open"].add(t)
            if t.cls == "D":
                resting["system.open"].add(t)
            kind_of["system.open"] = "report"
    rows = []
    real_runs = "\n".join(x.code for x in swift_files(root, "Sources/arbor-e2e")) + "\n" + read(root, "scripts/mac-shell/e2e-drag.sh")
    _, claims = gesture_claims(root)
    for h in sorted(everywhere, key=lambda h: (-len(resting[h]), h)):
        base = h.split(".", 1)[1].rstrip("=") if "." in h else h
        if h in EVIDENCE:
            wanted, differs = EVIDENCE[h]
        elif base in rules.events + rules.actions:            # a report the test makes up itself
            name = EVENT_WORDS.get(base) or (("action " if base in rules.actions else "event ") + base)
            wanted, differs = [name], ""
        else:
            sys.exit("census.py: no entry in EVIDENCE for " + h)
        found = sorted(set().union(*[seen.get(w, set()) for w in wanted])) if wanted else []
        cites = list(citations.get(base.split("(")[0], []))
        if h in faithful and FAITHFUL_CITES not in cites:
            cites.append(FAITHFUL_CITES)
        absent = [c for c in cites if c.startswith("collab/") and not os.path.exists(os.path.join(root, c))]
        if h in CHECKED_BY_A_TEST:
            verdict = "checked on every Mac run"
        elif h in NOT_MACOS:
            verdict = "not macOS's to say"
        elif found and differs:
            verdict = "recorded; the fake differs"
        elif found:
            verdict = "recorded"
        elif cites:
            verdict = "cited only"
        else:
            verdict = "never"
        claim = next((c for c in claims if h in CLAIMS and CLAIMS[h] in c[0]), None)
        rows.append({"ci": bool(h in ON_REAL_WINDOWS and re.search(ON_REAL_WINDOWS[h], real_runs, re.M)),
                     "claim": f"{claim[1]} ✔ {claim[2]} ✘" if claim else "",
                     "helper": h, "kind": kind_of[h], "d": len(resting[h]), "all": len(everywhere[h]), "wanted": wanted,
                     "found": found, "differs": differs, "cites": cites, "absent": absent, "faithful": h in faithful,
                     "verdict": verdict})
    return rows, traces, real, kinds, seen


def show(t):
    print("=" * 120)
    print(f"[{t.cls}{': ' + t.sub if t.sub else ''}] {t.file}:{t.line} {t.suite}.{t.name}",
          "(parameterised)" if t.parameterised else "", " ".join(t.traits), " ".join(t.conds))
    print("   decided by:", "; ".join(t.why[:10]))
    world = []
    for h, k, via in t.world:
        item = f"{h} [{k}]" + (f" via {via}" if via else "")
        if item not in world:
            world.append(item)
    print("   the world:", "; ".join(world[:14]) or "-")
    print("   reaches:", ", ".join(f"{d.name} ({os.path.basename(d.file.rel)}:{d.line})" for d, _ in t.reach[1:][:14]) or "-")
    body = t.decl.file.src[t.decl.start:t.decl.end].split("\n")
    for line in body[:30]:
        print("   |", line[:170])
    if len(body) > 30:
        print("   | …", len(body) - 30, "more lines")


# ---------------------------------------------------------------------------------------------------------------------
# Judgements: what the ranking of features in the document's section 4 rests on
# ---------------------------------------------------------------------------------------------------------------------
# Section 4 is prose in the template: a person ranked the features. These are the facts of the sources it goes by. If one has
# changed the script stops, so that the ranking is read again and not merely printed again.
RANKING_DEFAULTS = {
    "hotkeysEnabled": "true", "gesturesEnabled": "true", "scrollZoom": "true", "peek": "true", "frameRectangleModifier": '"ctrl+opt"',
    "animationDuration": "0.46", "focusRing": "true", "makeRoom": "true", "messages": '"helpful"', "menuBarControls": "true",
    "newWindowsWhileFramed": '"guest"', "dimBehindArranged": "0.25",
    "guardDesktopClicks": "false", "continuousZoom": "false", "windowPictures": "false", "minimapDuration": "0",
    "holdStillWhileCameraIsOn": "false", "holdStillWhileMicrophoneIsOn": "false", "soleFloatTakesDesktop": "false",
    "newWindows": '"float"', "reflowWhileDragging": "false", "tabsEnabled": "false", "automaticUpdateChecks": "false",
    "shrinkOutOfView": "false", "passThroughApps": "[]", "pauseForApps": "[]",
}
RANKING_HAS_A_KEY = [".showAll", ".togglePause", ".askName", ".find", ".minimap", ".undo", ".focus(", ".grow(", ".rotate", ".home",
                     ".floatAll", ".showShortcuts", ".settings("]
RANKING_HAS_NO_KEY = [".pin", ".hold", ".summon"]


def check_ranking(root, template):
    wrong = []
    settings = read(root, "Sources/ArborCore/Settings.swift")
    for name, value in RANKING_DEFAULTS.items():
        m = re.search(r"public var %s\b(?:\s*:\s*[^=\n]+)?\s*=\s*(.+)" % name, settings)
        if not m or m.group(1).strip() != value:
            wrong.append(f"the setting {name} is {m.group(1).strip() if m else 'gone'}, not {value}")
    source = Source(os.path.join(root, "Sources/ArborKit/Controller/KeyBindings.swift"), "KeyBindings.swift")
    keys = "\n".join(line for line in source.bare.split("\n") if "KeyBinding(" in line)
    wrong += [f"{c} has no default shortcut any more" for c in RANKING_HAS_A_KEY if c not in keys]
    wrong += [f"{c} has a default shortcut now" for c in RANKING_HAS_NO_KEY if c in keys]
    for name in sorted(set(re.findall(r"`(?:scripts/(?:mac-shell/)?)?([\w-]+\.(?:sh|py))`", template))):
        if not any(os.path.exists(os.path.join(root, folder, name)) for folder in ("scripts", "scripts/mac-shell")):
            wrong.append(f"the template names {name}, which is in neither scripts/ nor scripts/mac-shell/")
    for name in sorted(set(re.findall(r"`((?:docs|collab|\.github)/[\w./-]+\.(?:md|yml|txt))`", template))):
        if not os.path.exists(os.path.join(root, name)) and name != FAITHFUL_CITES:
            wrong.append(f"the template names {name}, which is not there")
    # What section 4 puts between quotation marks is somebody's own words: a spec's, a step's, a comment's. They must still be there.
    def plain(text):
        return re.sub(r"\s+", " ", text.replace("*", "").replace("`", ""))

    said = ""
    for folder, ending in (("docs/features", ".md"), ("scripts/mac-shell", ".sh"), ("Sources/arbor-e2e", ".swift"),
                           ("Sources/ArborKit/Input", ".swift")):
        for name in sorted(os.listdir(os.path.join(root, folder))):
            if name.endswith(ending):
                said += plain(read(root, folder + "/" + name)) + "\n"
    section = template[template.index("## 4."):template.index("## What the numbers suggest")]
    for quote in re.findall(r'"([^"\n]*)"', section):
        if len(quote) >= 24 and plain(quote) not in said:
            wrong.append(f'nothing says "{quote}" any more')
    if wrong:
        sys.exit("census.py: section 4 of the template ranks the features by facts that no longer hold. Read it again, mend it and "
                 "the tables RANKING_… in this script:\n  " + "\n  ".join(wrong))


# ---------------------------------------------------------------------------------------------------------------------
# Putting it together
# ---------------------------------------------------------------------------------------------------------------------
def markdown(header, rows, align=None):
    out = []
    table(header, rows, out, align)
    return "\n".join(out).rstrip("\n")


def percent(part, whole, digits=0):
    return f"{100 * part / whole:.{digits}f} %" if whole else "0 %"


class Census:
    """Everything the tables, the files and the document are made of."""

    def __init__(self, root):
        self.root = root
        self.rules = rules = Rules(root)
        self.tests, self.raw = tests, raw = collect_tests(root, rules)
        self.blocks = blocks = collections.OrderedDict()      # name -> (heading or None, markdown)
        self.facts = facts = {}
        total = len(tests)
        count = collections.Counter(t.cls for t in tests)

        # ---- 1: the classes
        rows = []
        for cls in "ABCDEFG":
            mine = [t for t in tests if t.cls == cls]
            rows.append([cls, CLASS_NAMES[cls], len(mine), len({t.file for t in mine}),
                         percent(len(mine), total, 2 if len(mine) * 1000 < total else 1), sum(1 for t in mine if t.parameterised)])
            facts[cls] = len(mine)
            facts[cls + "_pct"] = percent(len(mine), total, 2 if len(mine) * 1000 < total else 0)
        rows.append(["", "**all**", total, len({t.file for t in tests}), "100 %", sum(1 for t in tests if t.parameterised)])
        blocks["classes"] = ("Table 1. Every `@Test` function in one class", markdown(
            ["Class", "", "`@Test` functions", "Files", "Share", "of them parameterised"], rows, "llrrrr"))
        subs = collections.Counter((t.cls, t.sub) for t in tests if t.sub)
        blocks["subclasses"] = (None, markdown(["Class", "Of which", "Functions"], [[c, s, n] for (c, s), n in sorted(subs.items())], "llr"))
        by_target = collections.defaultdict(collections.Counter)
        for t in tests:
            by_target[t.target][t.cls] += 1
        blocks["targets"] = (None, markdown(
            ["Target"] + list("ABCDEFG") + ["all"],
            [[k] + [v.get(c, 0) for c in "ABCDEFG"] + [sum(v.values())] for k, v in sorted(by_target.items())], "lrrrrrrrr"))
        c_tests = [t for t in tests if t.cls == "C"]
        f_tests = [t for t in tests if t.cls == "F"]
        drawing = re.compile(r"\b(OffscreenPicture|NSBitmapImageRep|CGContext)\b")
        core = by_target.get("ArborCoreTests", {})
        facts.update({
            "attributes": raw, "functions": total, "twins": raw - total, "parameterised": sum(1 for t in tests if t.parameterised),
            "test_files": len({t.file for t in tests}),
            "mac_only": sum(1 for t in tests if t.mac), "mac_only_not_f": sum(1 for t in tests if t.mac and t.cls != "F"),
            "enabled_if": sum(1 for t in tests if "enabled" in t.traits), "disabled": sum(1 for t in tests if "disabled" in t.traits),
            "known_issue": sum(1 for t in tests if "withKnownIssue" in t.traits),
            "c_clock": sum(1 for t in c_tests if t.clock), "c_open_after": sum(1 for t in c_tests if t.opens and opens_after_start(t)),
            "never_mac": sum(count[c] for c in "ABCD"), "never_mac_pct": percent(sum(count[c] for c in "ABCD"), total, 1),
            "on_stand_ins": count["C"] + count["D"],
            "d_reports": subs[("D", "reports")], "d_answers": subs[("D", "answers only")], "d_walks": subs[("D", "random walk")],
            "d_helper_only": sum(1 for t in tests if t.cls == "D" and t.sub != "random walk" and not any(via == "" for _, _, via in t.world)),
            "b_listed": subs[("B", "a suite on the list of tools")],
            "core_not_a": sum(core.values()) - core.get("A", 0),
            "f_files": len({t.file for t in f_tests}),
            "f_drawing": sum(1 for t in f_tests if drawing.search("\n".join(d.bare() for d, _ in t.reach))),
            "f_files_none": len({t.file for t in f_tests}) - len({t.file for t in f_tests if t.mac_names}),
            "f_calls_ax": sum(1 for t in f_tests if re.search(r"\bAX[A-Z]\w+|\bkAX\w+", "\n".join(d.bare() for d, _ in t.reach))),
        })
        facts["f_drawing_pct"] = percent(facts["f_drawing"], count["F"])

        # pure tests of decisions that belong to the layers below the seam
        pure = {}
        for src in swift_files(root, "Sources/ArborCore"):
            for d in src.decls:
                if d.kind.startswith("type") and d.kind != "type:extension" and d.parent is None:
                    pure[d.name] = os.path.basename(src.rel)
        below = "\n".join(x.bare for f in ("Sources/ArborKit/AX", "Sources/ArborKit/Input") for x in swift_files(root, f))
        controller_files = swift_files(root, "Sources/ArborKit/Controller")
        decisions = sorted(n for n in pure if re.search(r"\b%s\b" % n, below)
                           and sum(1 for x in controller_files if re.search(r"\b%s\b" % n, x.bare)) <= 2)
        naming = re.compile(r"\b(%s)\b" % "|".join(decisions or ["\0"]))
        deciding = [t for t in tests if t.cls == "A" and naming.search("\n".join(d.bare() for d, _ in t.reach))]
        facts["a_decisions"] = len(deciding)
        blocks["decisions"] = (None, (
            f"Within class A: {len(deciding)} functions in {len({t.file for t in deciding})} files try the pure types that `ArborKit/AX` and "
            f"`ArborKit/Input` go by and the controller hardly knows (named in at most two of its files): "
            f"{', '.join('`%s`' % n for n in decisions)}. They are arithmetic, and what they are fed is a sequence of reports that the test made up."))

        by_file = collections.defaultdict(list)
        for t in f_tests:
            by_file[t.file].append(t)
        rows = []
        for f, ts in sorted(by_file.items()):
            names = sorted({n for t in ts for n in t.mac_names})
            apple = sorted({a for t in ts for a in APPLE.findall("\n".join(d.bare() for d, _ in t.reach))})
            families = sorted({re.match(r"NS|CG|CA|kVK|kCG|kAX|AX|TIS|UCKey|LM|CF|SM|IOHID|CT", a).group(0) for a in apple})
            rows.append([f"`{f}`", len(ts), ", ".join(f"`{n}` ({os.path.basename(rules.mac_types[n])})" for n in names) or "none of Arbor's",
                         " ".join(families)])
        blocks["class_f"] = ("Table 1a. Class F, file by file: the real code it reaches", markdown(
            ["Test file", "Functions", "Arbor's macOS-only types it names", "Apple's, by prefix"], rows, "lrll"))

        # ---- 2: the helpers
        self.helpers, traces, real, kinds, _ = helpers, traces, real, kinds, _ = helper_table(root, rules, tests)
        header = ["Helper", "Kind", "Tests of class D", "Tests of all classes", "A recording would hold", "Recordings that do", "Verdict",
                  "Outcome on real windows in CI", "Real input once (table 2d)"]

        def helper_row(r):
            found = (f"{len(r['found'])}: " + ", ".join(r["found"][:3]) + (" …" if len(r["found"]) > 3 else "")) if r["found"] else "none"
            return [f"`{r['helper']}`", r["kind"], r["d"], r["all"], "; ".join(r["wanted"]) or "nothing a trace records", found, r["verdict"],
                    "yes" if r["ci"] else "", r["claim"]]

        blocks["helpers"] = ("Table 2. What the world is made to do, how many tests rest on it, and whether a Mac was ever recorded doing it",
                             markdown(header, [helper_row(r) for r in helpers if r["d"]], "llrrlllll"))
        self.extra = {"helpers_top": markdown(header, [helper_row(r) for r in helpers if r["d"] >= 10], "llrrlllll")}
        facts["helpers_rest"] = sum(1 for r in helpers if 0 < r["d"] < 10)
        for verdict, key in (("never", "h_never"), ("cited only", "h_cited"), ("recorded", "h_recorded"),
                             ("recorded; the fake differs", "h_differs")):
            facts[key] = sum(1 for r in helpers if r["d"] and r["verdict"] == verdict)
        unverified = [r for r in helpers if r["verdict"] in ("never", "cited only")]

        def uncovered(limit):
            return markdown(
                ["Rank", "Helper", "Tests of class D", "of all classes", "Verdict", "What is cited for it", "Outcome on real windows in CI"],
                [[i + 1, f"`{r['helper']}`", r["d"], r["all"], r["verdict"],
                  "; ".join(c + (" (not in the repository)" if c in r["absent"] else "") for c in r["cites"]) or "-",
                  "yes" if r["ci"] else "no"] for i, r in enumerate(unverified[:limit])], "rlrrlll")

        blocks["uncovered"] = ("Table 2a. The premises no committed recording covers, by the number of class D tests resting on them", uncovered(30))
        self.extra["uncovered_top"] = uncovered(20)
        d_tests = [t for t in tests if t.cls == "D"]
        bad = {r["helper"] for r in unverified}
        weak = bad | {r["helper"] for r in helpers if r["verdict"] == "recorded; the fake differs"}
        opened = {id(t) for t in d_tests if t.opens and opens_after_start(t)}

        def rests(t, names):
            return any(h in names for h, _, _ in t.world) or ("system.open" in names and id(t) in opened)

        facts["d_uncovered"] = sum(1 for t in d_tests if t.walk or rests(t, bad))
        facts["d_weak"] = sum(1 for t in d_tests if t.walk or rests(t, weak))
        facts["d_borne_out"] = sum(1 for t in d_tests if not t.walk and not rests(t, weak))
        for key in ("d_uncovered", "d_weak", "d_borne_out"):
            facts[key + "_pct"] = percent(facts[key], len(d_tests))
        blocks["uncovered_sum"] = (None, (
            f"Of the {len(d_tests)} tests of class D, {facts['d_uncovered']} rest on at least one premise that no committed recording covers, and "
            f"{facts['d_weak']} on at least one that is either uncovered or known to differ from the recording. {facts['d_borne_out']} rest only on "
            "premises a recording bears out."))
        openers = [t for t in tests if t.cls in "CD" and t.opens]
        one_process = [t for t in openers if not re.search(r"\bpid:", "\n".join(d.bare() for d, _ in t.reach))]
        blocks["one_process"] = (None, (
            f"A premise of another kind: `open` gives every window process 1000 unless told otherwise. {len(one_process)} of the {len(openers)} tests "
            "of classes C and D that open windows never name a process, so all their apps are one process; "
            f"{sum(1 for t in one_process if any(h in ('system.close', 'system.setMinimized') for h, _, _ in t.world))} of those close or minimize a "
            "window, after which the fake hands the keyboard to \"the app's next window\", which there is any window at all."))
        blocks["differs"] = ("Table 2b. Recorded, and the fake is known to do otherwise", markdown(
            ["Helper", "Tests of class D", "The difference (collab/evidence/traces/README.md)"],
            [[f"`{r['helper']}`", r["d"], r["differs"]] for r in helpers if r["verdict"] == "recorded; the fake differs"], "lrl"))

        def tally(counter):
            return ", ".join(f"{k} ({v})" for k, v in counter.most_common())

        from_a_mac = [(n, h) for n, h, _ in traces if h.get("os") != "simulated"]
        shapes = collections.Counter(" + ".join("%d×%d" % tuple(d["frame"][2:]) for d in h.get("displays", [])) for _, h in from_a_mac)
        facts["traces"], facts["real_traces"] = len(traces), len(real)
        blocks["recordings"] = ("Table 2c. What the recordings hold", (
            f"{len(traces)} traces, {len(real)} of them from a Mac. Systems: {tally(collections.Counter(h.get('os') for _, h, _ in traces))}. "
            f"Builds of Arbor that recorded on the Mac: {tally(collections.Counter(h.get('arbor') for _, h in from_a_mac))}. "
            f"Displays there: {tally(shapes)}."))
        blocks["recording_kinds"] = (None, markdown(["Kind of line", "Lines in the recordings from a Mac"],
                                                    [[f"`{k}`", v] for k, v in sorted(kinds.items())], "lr"))
        events = [EVENT_WORDS.get(e, "event " + e)[6:] for e in rules.events] + ["shortcut"]
        blocks["never_recorded"] = (None, "Reports of `WindowSystemEvents` (and `shortcut`) that occur in no recording from a Mac: "
                                    + ", ".join(f"`{e}`" for e in events if "event:" + e not in kinds) + ".")
        head, self.claims = gesture_claims(root)
        blocks["claims_head"] = ("Table 2d. collab/evidence/gestures-latest.txt: real input, outcomes only",
                                 f"{head}. {sum(c[1] for c in self.claims)} checks passed, {sum(c[2] for c in self.claims)} failed.")
        blocks["claims"] = (None, markdown(["Claim", "✔", "✘"], self.claims, "lrr"))

        # ---- 3: the real code
        self.real, runs, _ = rows3, runs, _ = real_code(root, rules, tests)

        def who(r):
            parts = []
            if r["f_tests"]:
                files = sorted({os.path.basename(t.file)[:-6] for t in r["f_tests"]})
                parts.append(f"F: {len(r['f_tests'])} tests ({', '.join(files)}) reach {r['f_lines']} lines, in "
                             + ", ".join("`%s`" % n for n in r["f_names"][:4]))
            if r["g_tests"]:
                parts.append(f"G: {len(r['g_tests'])} tests")
            return "; ".join(parts + r["auto"]) or "-"

        blocks["runs"] = ("Table 3. Real code and who runs it", "What each automatic run brings. " + " ".join(
            f"**{k}**: " + (", ".join(sorted(x for x in f if ":" not in x and x != "launch")) or "nothing switched on")
            + ("; commands sent: " + ", ".join(sorted(x[4:] for x in f if x.startswith("cmd:")))
               if any(x.startswith("cmd:") for x in f) else "; no command but questions") + "." for k, (f, _) in runs.items())
            + " (watchdog: left on; tile: a window refuses its slot; drag: the real pointer drags; ctl: `arborctl` is used.)")
        blocks["real_code"] = (None, markdown(
            ["File", "Lines", "Branches", "Run automatically by", "Only when somebody starts", "Verdict", "Lines nothing runs automatically", "Note"],
            [[f"`{r['file'][8:]}`", r["loc"], r["branches"], who(r),
              (", ".join(r["hand"][:6]) + (f" and {len(r['hand']) - 6} more" if len(r["hand"]) > 6 else "")) if not r["auto"] else "",
              r["verdict"], r["unrun_loc"] or "", r["note"]] for r in rows3], "lrrlllrl"))
        groups = collections.OrderedDict()
        for r in rows3:
            key = "/".join(r["file"].split("/")[1:3]) if r["file"].startswith("Sources/ArborKit/") else r["file"].split("/")[1]
            g = groups.setdefault(key, collections.Counter())
            g.update({"files": 1, "loc": r["loc"], "branches": r["branches"], "unrun_loc": r["unrun_loc"],
                      "unrun_branches": r["unrun_branches"], "part": r["loc"] if r["verdict"] == "automatic, in part" else 0})
        sums = collections.Counter()
        for g in groups.values():
            sums.update(g)
        keys = ("files", "loc", "branches", "unrun_loc", "unrun_branches", "part")
        blocks["folders"] = (None, markdown(
            ["Folder", "Files", "Lines", "Branches", "Lines nothing runs automatically", "Branches among them", "Lines in files entered only in part"],
            [[f"`{k}`"] + [g[x] for x in keys] for k, g in groups.items()] + [["**all**"] + [sums[x] for x in keys]], "lrrrrrr"))
        mac = [r for r in rows3 if any(r["file"].startswith(f) for f in MAC_FOLDERS)]
        entry = groups.get("ArborKit/Input", collections.Counter())
        facts.update({
            "mac_lines": sum(r["loc"] for r in mac), "mac_branches": sum(r["branches"] for r in mac),
            "unrun_lines": sum(r["unrun_loc"] for r in mac), "unrun_branches": sum(r["unrun_branches"] for r in mac),
            "part_lines": sum(r["loc"] for r in mac if r["verdict"] == "automatic, in part"),
            "input_lines": entry["loc"], "input_branches": entry["branches"], "input_unrun": entry["unrun_loc"],
            "input_unrun_branches": entry["unrun_branches"], "input_unrun_pct": percent(entry["unrun_loc"], entry["loc"]),
        })
        facts["unrun_pct"] = percent(facts["unrun_lines"], facts["mac_lines"])
        blocks["mac_sum"] = (None, (
            f"The macOS-only part of the product ({', '.join(f[8:] for f in MAC_FOLDERS)}): {facts['mac_lines']} lines, {facts['mac_branches']} "
            f"branches; nothing runs {facts['unrun_lines']} lines ({facts['unrun_pct']}) and {facts['unrun_branches']} branches of it automatically, "
            f"and {facts['part_lines']} more lines are in files an automatic run enters only in part."))

    # -- looking things up for the template

    def lookup(self, key):
        """`{{table:classes}}`, `{{functions}}`, `{{d:system.userFocus}}`, `{{unrun:UI/Stage.swift}}`, `{{claim:close a docked window}}`."""
        kind, _, name = key.partition(":")
        if not name:
            return self.facts[key]
        if kind == "table":
            return self.extra[name] if name in self.extra else self.blocks[name][1]
        if kind in ("d", "all", "found"):
            row = next(r for r in self.helpers if r["helper"] == name)
            return len(row["found"]) if kind == "found" else row[kind]
        if kind in ("loc", "branches", "unrun", "g", "branches_pct"):
            row = next(r for r in self.real if r["file"] in ("Sources/ArborKit/" + name, "Sources/" + name))
            if kind == "branches_pct":
                return percent(row["branches"], self.facts["mac_branches"])
            return len(row["g_tests"]) if kind == "g" else row[{"loc": "loc", "branches": "branches", "unrun": "unrun_loc"}[kind]]
        if kind == "claim":
            claim = next(c for c in self.claims if name in c[0])
            return f"{claim[1]} ✔ {claim[2]} ✘"
        raise KeyError(key)

    def document(self, template):
        def fill(m):
            try:
                value = self.lookup(m.group(1))
            except (KeyError, StopIteration):
                sys.exit("census.py: the template asks for {{%s}}, which the census does not have" % m.group(1))
            return f"{value:,}" if isinstance(value, int) else str(value)

        return re.sub(r"\{\{([^{}]+)\}\}", fill, template)

    def printed(self):
        out = []
        for heading, text in self.blocks.values():
            if heading:
                out.append("### " + heading + "\n")
            out.append(text + "\n")
        out.append("### Each test file's classes\n")
        out.append(self.files_tsv())
        return "\n".join(out)

    # -- the files

    def files_tsv(self):
        per = collections.defaultdict(collections.Counter)
        for t in self.tests:
            per[t.file][t.cls] += 1
        return "file\tfunctions\t" + "\t".join("ABCDEFG") + "\n" + "".join(
            "\t".join([name, str(sum(c.values()))] + [str(c.get(k, "") or "") for k in "ABCDEFG"]) + "\n" for name, c in sorted(per.items()))

    def write_files(self, folder):
        os.makedirs(folder, exist_ok=True)

        def save(name, header, rows):
            with open(os.path.join(folder, name), "w", encoding="utf-8") as f:
                f.write("\t".join(header) + "\n")
                for row in rows:
                    f.write("\t".join(str(x) for x in row) + "\n")

        def world(t):
            seen = []
            for h, k, via in t.world:
                item = f"{h} [{k}]" + (f" via {via}" if via else "")
                if item not in seen:
                    seen.append(item)
            return "; ".join(seen)

        save("tests.tsv", ["file", "line", "suite", "function", "class", "subclass", "decided by", "the world (helper [kind] via)",
                           "parameterised", "traits", "#if"],
             [[t.file, t.line, t.suite, t.name, t.cls, t.sub, "; ".join(t.why), world(t), "yes" if t.parameterised else "",
               " ".join(t.traits), " && ".join(t.conds)] for t in self.tests])
        with open(os.path.join(folder, "files.tsv"), "w", encoding="utf-8") as f:
            f.write(self.files_tsv())
        save("helpers.tsv", ["helper", "kind", "tests of class D", "tests of all classes", "a recording would hold", "recordings that do",
                             "verdict", "differs", "cited", "cited and absent", "in FaithfulFakeTests", "outcome on real windows in CI"],
             [[r["helper"], r["kind"], r["d"], r["all"], "; ".join(r["wanted"]), ", ".join(r["found"]), r["verdict"], r["differs"],
               "; ".join(r["cites"]), "; ".join(r["absent"]), "yes" if r["faithful"] else "", "yes" if r["ci"] else ""] for r in self.helpers])
        save("realcode.tsv", ["file", "lines", "branches", "if", "guard", "case", "while", "class F tests", "class G tests", "automatic runs",
                              "by hand", "verdict", "lines nothing runs automatically", "branches among them", "note"],
             [[r["file"], r["loc"], r["branches"], r["kinds"]["if"], r["kinds"]["guard"], r["kinds"]["case"], r["kinds"]["while"],
               len(r["f_tests"]), len(r["g_tests"]), ", ".join(r["auto"]), ", ".join(r["hand"]), r["verdict"], r["unrun_loc"],
               r["unrun_branches"], r["note"]] for r in self.real])


READ = ["Sources", "Tests", "scripts/mac-shell", "scripts/e2e.sh", ".github", "collab/evidence", "docs/features"]


def commit_of(root):
    """The last commit that changed anything the census reads, so that writing the page again after a commit that changed none of it
    (the one that brought the page, say) gives the same page."""
    def git(*words):
        return subprocess.run(["git", "-C", root] + list(words), capture_output=True, text=True, check=False).stdout.strip()

    commit = git("log", "-1", "--format=%h", "--", *READ) or "unknown"
    return commit + (", with changes that are not committed" if git("status", "--porcelain", "--", *READ) else "")


# ---------------------------------------------------------------------------------------------------------------------
# The script's own test
# ---------------------------------------------------------------------------------------------------------------------
SMALL = {
    "Sources/ArborKit/Platform/WindowSystem.swift": """
        public protocol WindowSystemEvents: AnyObject {
          func windowFocused(_ id: Int)
          func windowDestroyed(_ id: Int)
        }
        """,
    "Sources/ArborKit/Platform/OverlayPresenter.swift": """
        public protocol OverlayActions: AnyObject {
          func tileActivated(node: Int)
        }
        """,
    "Sources/ArborKit/UI/TilePanel.swift": "import AppKit\nfinal class TilePanel: NSPanel {}\n",
    "Sources/ArborTesting/Fakes.swift": """
        public final class FakeWindowSystem {
          public var cursor = 0
          public func open(app: String = "App", minimumSize: Int = 0) -> Int { 1 }
          public func allWindows() -> [Int] { [] }
          public func userFocus(_ window: Int) {}
          public func close(_ window: Int) {}
        }
        public final class FakeOverlays {
          public func clickTile(_ node: Int) {}
        }
        public final class Harness {
          public let system = FakeWindowSystem()
          public let overlays = FakeOverlays()
          public func start() {}
          public func run(_ text: String) {}
        }
        """,
    "Tests/SmallTests/OneTests.swift": """
        import Testing
        private func desk() -> Harness {
          let h = Harness()
          h.start()
          settle(h)
          return h
        }
        private func settle(_ h: Harness) { h.system.userFocus(1) }
        private struct Fixture { let h = Harness(); init() { h.start() } }

        @Suite struct OneTests {
          @Test func pure() { #expect(1 + 1 == 2) }
          @Test func aWordInAMessageIsNoCall() { #expect(Bool(true), "h.system.userFocus(1) // h.system.close(1)") }
          @Test func commandsOnly() {
            let h = Harness()
            _ = h.system.open(app: "Safari")
            h.start()
            h.run("dock 1 left")
          }
          @Test func theWorldActs() {
            let h = Harness()
            h.start()
            h.system.close(1)
          }
          @Test func throughTwoFileLocalHelpers() { desk().run("zoom") }
          @Test func onlyAnAnswer() {
            let h = Harness()
            h.system.cursor = 7
            h.run("in")
          }
          @Test func anAppThatRefuses() {
            let h = Harness()
            _ = h.system.open(app: "Xcode", minimumSize: 900)
            h.run("dock 1 left")
          }
          @Test func aHandOnAPanel() {
            let h = Harness()
            h.overlays.clickTile(3)
          }
          @Test func theSameWindowsForANewRun() {
            let old = Harness()
            let new = Harness()
            for window in old.system.allWindows() { if window > 1 { new.system.close(window) } }
            new.start()
          }
          @Test func itsOwnFixture() { Fixture().h.run("zoom") }
          struct Desk { let h = Harness() }
          @Test func itsOwnDesk() { Desk().h.run("zoom") }
          @Test(arguments: [1, 2, 3]) func manyCases(n: Int) { #expect(n > 0) }
          @Test func aRealFile() throws {
            try "x".write(to: url, atomically: true, encoding: .utf8)
            #expect(FileManager.default.fileExists(atPath: url.path))
          }
          @Test func theFakeAlone() { FakeWindowSystem().userFocus(1) }
          #if os(macOS)
            @Test func drawn() { _ = TilePanel() }
          #else
            @Test(.disabled("AppKit exists only on macOS")) func drawn() {}
          #endif
        }
        """,
    "Tests/SmallTests/TwoTests.swift": """
        import Testing
        private struct Fixture { let h = Harness(); init() { h.start(); h.system.userFocus(2) } }
        @Suite struct TwoTests {
          @Test func theOtherFilesFixture() { Fixture().h.run("zoom") }
          struct Desk { let h = Harness(); init() { h.system.close(1) } }
          @Test func theOtherSuitesDesk() { Desk().h.run("zoom") }
        }
        """,
}


def self_test():
    import tempfile
    import textwrap

    def small(changes=None):
        folder = tempfile.mkdtemp(prefix="arbor-census-")
        for rel, text in {**SMALL, **(changes or {})}.items():
            path = os.path.join(folder, rel)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as f:
                f.write(textwrap.dedent(text))
        return folder

    def done(folder):
        import shutil
        shutil.rmtree(folder, ignore_errors=True)

    situations = []
    folder = small()
    try:
        rules = Rules(folder)
        tests, raw = collect_tests(folder, rules)
    finally:
        done(folder)
    got = {t.name: t for t in tests}

    def cls(name):
        return got[name].cls + (": " + got[name].sub if got[name].sub else "")

    situations += [
        ("values in, values out", cls("pure"), "A"),
        ("a helper's name in a string or a comment is no call", cls("aWordInAMessageIsNoCall"), "A"),
        ("windows opened and commands run", cls("commandsOnly"), "C"),
        ("a window closes", cls("theWorldActs"), "D: reports"),
        ("a world helper two file-local helpers away", cls("throughTwoFileLocalHelpers"), "D: reports"),
        ("… and the row says through which", [via for h, _, via in got["throughTwoFileLocalHelpers"].world], ["settle"]),
        ("the pointer is put somewhere", cls("onlyAnAnswer"), "D: answers only"),
        ("a window that refuses to shrink", cls("anAppThatRefuses"), "D: answers only"),
        ("a click on a tile", cls("aHandOnAPanel"), "D: reports"),
        ("a loop that copies one run's windows into the next", cls("theSameWindowsForANewRun"), "C"),
        ("a private type is the one in the same file", cls("itsOwnFixture"), "C"),
        ("… in both files", cls("theOtherFilesFixture"), "D: reports"),
        ("two suites each have a `Desk`", (cls("itsOwnDesk"), cls("theOtherSuitesDesk")), ("C", "D: reports")),
        ("a parameterised test is one function", (cls("manyCases"), got["manyCases"].parameterised), ("A", True)),
        ("a file is written", cls("aRealFile"), "G"),
        ("a stand-in with no controller", cls("theFakeAlone"), "B: a stand-in alone"),
        ("compiled only on macOS, naming a macOS-only type", cls("drawn"), "F"),
        ("the `#else … .disabled` twin counts once", (raw, len(tests), sum(1 for t in tests if t.name == "drawn")), (18, 17, 1)),
    ]
    folder = small({"Sources/ArborTesting/More.swift": "extension FakeWindowSystem {\n  public func shakeTheMouse() {}\n}\n"})
    try:
        Rules(folder)
        stopped = "went on"
    except SystemExit as stop:
        stopped = "FakeWindowSystem.shakeTheMouse" in str(stop)
    finally:
        done(folder)
    situations.append(("a public member of a stand-in that is in no table stops the run", stopped, True))
    code, bare = lex('let a = "x { \\(f("y")) }" // {\nlet b = #"""#\nlet c = /[{]/\n')
    situations.append(("strings, comments and regexes hide their brackets", (bare.count("{"), bare.count("}"), len(bare) == len(code)), (0, 0, True)))
    situations.append(("branches: if, guard, while, the cases of a switch; not an enum's, not `if case`", sum(count_branches(
        "enum E { case a, b }\nif x { }\nguard y else { }\nwhile z { }\nswitch e {\ncase .a: break\ndefault: break\n}\nif case .a = e { }\n").values()), 6))
    failed = [s for s in situations if s[1] != s[2]]
    for what, result, expected in failed:
        print(f"✘ {what}: {result!r}, expected {expected!r}")
    print(f"census.py --self-test: {len(situations) - len(failed)} of {len(situations)} situations came out as they should")
    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--write", action="store_true", help="regenerate docs/CENSUS.md from scripts/census-template.md")
    parser.add_argument("--out", metavar="DIR", help="also write tests.tsv, files.tsv, helpers.tsv and realcode.tsv there")
    parser.add_argument("--show", metavar="NAME", help="how the tests of this name (function or suite) were classified, and stop")
    parser.add_argument("--sample", type=int, default=0, metavar="N", help="N tests drawn at random, with their bodies, and stop")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--per-class", action="store_true", help="draw the sample evenly from the classes")
    parser.add_argument("--self-test", action="store_true", help="try the script on small sources whose answers are known")
    options = parser.parse_args()
    if options.self_test:
        return self_test()

    if options.show or options.sample:
        rules = Rules(ROOT)
        tests, _ = collect_tests(ROOT, rules)
        if options.show:
            picked = [t for t in tests if options.show in (t.name, t.suite)]
        else:
            rnd = random.Random(options.seed)
            pool = sorted(tests, key=lambda t: (t.file, t.line))
            if options.per_class:
                by = collections.defaultdict(list)
                for t in pool:
                    by[t.cls].append(t)
                picked = [t for k in sorted(by) for t in rnd.sample(by[k], min(max(1, options.sample // len(by)), len(by[k])))]
            else:
                picked = rnd.sample(pool, options.sample)
        for t in picked:
            show(t)
        return 0 if picked else 1

    template = read(ROOT, TEMPLATE)
    check_ranking(ROOT, template)
    census = Census(ROOT)
    census.facts["commit"] = commit_of(ROOT)
    document = census.document(template)      # also without --write: a template that asks for what is not there is found at once
    if options.out:
        census.write_files(options.out)
    if options.write:
        with open(os.path.join(ROOT, DOCUMENT), "w", encoding="utf-8") as f:
            f.write(document)
        print(f"wrote {DOCUMENT}: {census.facts['functions']} test functions at {census.facts['commit']}")
    else:
        print(census.printed())
    return 0


if __name__ == "__main__":
    sys.exit(main())
