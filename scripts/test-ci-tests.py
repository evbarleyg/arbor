#!/usr/bin/env python3
"""Checks ci-tests.py against tables of made-up test files, event streams and records. No Swift, no network.

A mistake there lets a test run nowhere while every check is green, which is the one thing that script exists to prevent.
So most rows are about the net failing when it must. The Linux CI job runs this. Exit code 1 when a row comes out wrong.
"""

import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ci-tests.py")
spec = importlib.util.spec_from_file_location("ci_tests", SCRIPT)
tests = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tests)

FULL, OWN = tests.FULL, tests.MAC_ONLY
P, F, S = tests.PASSED, tests.FAILED, tests.SKIPPED
REFUSED = "refused"

PLAIN = "import Testing\nimport ArborCore\n@Suite struct A { @Test func a() {} }\n"

# Whether the file is selected for the Mac, the situation, its text.
SELECTION = [
    (False, "nothing about the platform", PLAIN),
    (False, "every module that is vouched for",
     "import CoreGraphics\nimport Foundation\n@testable import ArborKit\nimport ArborTesting\n" + PLAIN),
    (True, "#if os(macOS)", "#if os(macOS)\n" + PLAIN + "#endif\n"),
    (True, "an indented #if canImport", PLAIN + "  #if canImport(Carbon)\n  #endif\n"),
    (True, "#if !os(Linux)", "#if !os(Linux)\n" + PLAIN + "#endif\n"),
    (True, "#if arch", PLAIN + "#if arch(arm64)\n#endif\n"),
    (True, "#elseif", PLAIN + "#if FLAG\n#elseif os(macOS)\n#endif\n"),
    (True, "a condition nobody has thought of", PLAIN + "#if hasFeature(Something)\n#endif\n"),
    (True, "a test that is disabled", 'import Testing\n@Test(.disabled("only on macOS")) func a() {}\n'),
    (True, "a test that is enabled if", "import Testing\n@Test(.enabled(if: flag)) func a() {}\n"),
    (True, "the trait on a later line", "import Testing\n@Test(\n  arguments: [1, 2],\n  .enabled(if: f(g(h(1))))\n) func a(n: Int) {}\n"),
    (True, "the trait after a bracket in the arguments", "import Testing\n@Test(arguments: list(), .disabled()) func a(n: Int) {}\n"),
    (True, "a suite that is disabled", 'import Testing\n@Suite(.disabled("not now")) struct A { @Test func a() {} }\n'),
    (False, "a method of the same name in the body of a test", PLAIN + "func f() { _ = item.enabled(false).disabled(true) }\n"),
    (False, "the words in a comment", PLAIN + "// #if os(macOS): see FileManager, getuid, .disabled(\n/* import AppKit\n#if os(macOS) */\n"),
    (False, "the words in a string", PLAIN + 'let app = "Calendar FileManager getuid()"\nlet more = """\n#if os(macOS)\nimport AppKit\n"""\n'),
    (True, "getuid", PLAIN + "let root = getuid() == 0\n"),
    (True, "import AppKit", "import AppKit\n" + PLAIN),
    (True, "import Carbon.HIToolbox", "import Carbon.HIToolbox\n" + PLAIN),
    (True, "@preconcurrency import ApplicationServices", "@preconcurrency import ApplicationServices\n" + PLAIN),
    (True, "import struct QuartzCore.CATransform3D", "import struct QuartzCore.CATransform3D\n" + PLAIN),
    (True, "a module nobody has vouched for", "import Synchronization\n" + PLAIN),
    (True, "the socket's module", "@testable import ArborIPC\n" + PLAIN),
    (True, "real files", PLAIN + "let f = FileManager.default\n"),
    (True, "the place of the source", PLAIN + "let here = #filePath\n"),
    (True, "a subprocess", PLAIN + "let p = Process()\n"),
    (True, "a real wait", PLAIN + "func w() async throws { try await Task.sleep(for: .seconds(1)) }\n"),
    (True, "a queue", PLAIN + "let q = DispatchQueue.main\n"),
    (False, "a helper with a condition and no test, which cannot be run", "#if os(macOS)\nimport AppKit\nstruct Picture {}\n#endif\n"),
]

# Ids as `swift test` matches filters against them (found by trying, with 6.4.1), and whether the filters for
# Tests/ArborKitTests/Mac.swift and Tests/ArborCoreTests/Deep/Also.swift must find them.
FILTERED = [
    (True, "ArborKitTests.Suite/a()/Mac.swift:3:4"),
    (True, "ArborKitTests.Outer/Inner/a(_:label:)/Mac.swift:30:14"),
    (True, "ArborKitTests.outsideAnySuite()/Mac.swift:3:2"),
    (True, "ArborKitTests.`a name in backticks`()/Mac.swift:7:2"),
    (True, "ArborKitTests.SuiteFromAnotherFile/addedInAnExtension()/Mac.swift:9:20"),
    (True, "ArborCoreTests.Suite/a()/Also.swift:3:4"),
    (False, "ArborKitTests.Suite/a()/Other.swift:3:4"),
    (False, "ArborKitTests.Suite/a()/NotMac.swift:3:4"),
    (False, "ArborKitTests.Suite/a()/MacXswift:3:4"),
    (False, "ArborKitTests.Suite/a()/Mac.swift.swift:3:4"),
    (False, "ArborCoreTests.Suite/a()/Mac.swift:3:4"),
    (False, "ArborKitTests.Suite/a()/Also.swift:3:4"),
    (False, "ArborKitTests.Mac"),
]


def function(identifier):
    return {"kind": "test", "payload": {"kind": "function", "id": identifier, "name": "x()"}, "version": 0}


def suite(identifier):
    return {"kind": "test", "payload": {"kind": "suite", "id": identifier, "name": "X"}, "version": 0}


def event(kind, identifier=None, **more):
    payload = {"kind": kind, "instant": {"absolute": 1.0, "since1970": 2.0}, "messages": [], **more}
    if identifier:
        payload["testID"] = identifier
    return {"kind": "event", "payload": payload, "version": 0}


def ran(identifier):
    return [event("testStarted", identifier), event("testEnded", identifier)]


def issue(identifier, **fields):
    return event("issueRecorded", identifier, issue=fields)


START, END = event("runStarted"), event("runEnded")
A, B = "M.S/a()/F.swift:3:4", "M.S/b()/F.swift:4:4"

# The record expected (or REFUSED), the situation, the event stream.
STREAMS = [
    ({"M.S/a()": P, "M.S/b()": S}, "one passed, one skipped",
     [START, suite("M.S"), function(A), function(B), event("testStarted", "M.S"), *ran(A), event("testSkipped", B), event("testEnded", "M.S"), END]),
    ({"M.S/a()": F}, "an issue", [START, function(A), event("testStarted", A), issue(A, isKnown=False), event("testEnded", A), END]),
    ({"M.S/a()": F}, "the issue's line after the end's: tests run side by side", [START, function(A), *ran(A), issue(A, isKnown=False), END]),
    ({"M.S/a()": P}, "a known issue", [START, function(A), event("testStarted", A), issue(A, isKnown=True), event("testEnded", A), END]),
    ({"M.S/a()": P}, "a warning, in a later version of the stream",
     [START, function(A), event("testStarted", A), issue(A, isKnown=False, isFailure=False, severity="warning"), event("testEnded", A), END]),
    ({"M.S/a()": F}, "a failure, in a later version", [START, function(A), issue(A, isKnown=False, isFailure=True), *ran(A), END]),
    ({"M.S/a()": P, "M.T/a()": S, "N.S/a()": F}, "the same name in three places",
     [START, function(A), function("M.T/a()/F.swift:9:4"), *ran(A), event("testSkipped", "M.T/a()/F.swift:9:4"), END,
      START, function("N.S/a()/F.swift:3:4"), issue("N.S/a()/F.swift:3:4"), *ran("N.S/a()/F.swift:3:4"), END]),
    ({"M.a()": P, "M.`a b`()": P, "M.O/I/c(_:d:)": P}, "outside a suite, in backticks, nested with arguments",
     [START, function("M.a()/F.swift:1:2"), function("M.`a b`()/F.swift:2:2"), function("M.O/I/c(_:d:)/F.swift:3:2"),
      *ran("M.a()/F.swift:1:2"), *ran("M.`a b`()/F.swift:2:2"), event("testStarted", "M.O/I/c(_:d:)/F.swift:3:2"),
      event("testCaseStarted", "M.O/I/c(_:d:)/F.swift:3:2"), event("testCaseEnded", "M.O/I/c(_:d:)/F.swift:3:2"),
      event("testEnded", "M.O/I/c(_:d:)/F.swift:3:2"), END]),
    ({"M.S/a()": S}, "a suite that is off skips its tests one by one",
     [START, suite("M.S"), function(A), event("testSkipped", "M.S"), event("testSkipped", A), END]),
    ({"M.S/a(_:)": S}, "two functions with one id: the worse news counts",
     [START, function("M.S/a(_:)/F.swift:3:4"), function("M.S/a(_:)/F.swift:4:4"), *ran("M.S/a(_:)/F.swift:3:4"),
      event("testSkipped", "M.S/a(_:)/F.swift:4:4"), END]),
    ({"M.S/a()": P}, "a target without a test that matches, beside one with", [START, END, START, function(A), *ran(A), END]),
    (REFUSED, "an empty stream", []),
    (REFUSED, "no run at all", [function(A)]),
    (REFUSED, "a filter that matched nothing", [START, END, START, END]),
    (REFUSED, "a crash", [START, function(A), function(B), *ran(A), event("testStarted", B)]),
    (REFUSED, "a crash after the last test", [START, function(A), *ran(A)]),
    (REFUSED, "a second target that crashed before it announced a test", [START, function(A), *ran(A), END, START]),
    (REFUSED, "tests without a run around them", [function(A), *ran(A)]),
    (REFUSED, "a crash in the first of two targets", [START, function(A), event("testStarted", A), START, function(B), *ran(B), END]),
    (REFUSED, "a test that was announced and never heard of again", [START, function(A), function(B), *ran(A), END]),
    (REFUSED, "a test that started and never ended, in a run that did", [START, function(A), event("testStarted", A), END]),
]

ON_PURPOSE = {"M.S/debugOnly()"}
BOTH = {"M.S/a()": P, "M.S/b()": P}

# The tests the net must name (None stands for a complaint about the records as a whole), the situation, the mode, the Mac's
# record, what the Mac's list has beyond its record, Linux's record.
NET = [
    ([], "the Mac ran its own, Linux the rest", OWN, {"M.Mac/x()": P}, BOTH, BOTH),
    ([], "the Mac ran everything", FULL, {**BOTH, "M.Mac/x()": P}, [], BOTH),
    ([], "Linux skipped it, as root; the Mac ran it", OWN, {"M.S/notAsRoot()": P}, BOTH, {**BOTH, "M.S/notAsRoot()": S}),
    ([], "Linux has the stand-in, the Mac the test", OWN, {"M.Carbon/codes()": P}, BOTH, {**BOTH, "M.Carbon/codes()": S}),
    ([], "the stand-in takes no arguments, the Mac's test does", OWN, {"M.Keys/layouts(name:id:)": P}, BOTH, {**BOTH, "M.Keys/layouts()": S}),
    (["M.Keys/layouts()", "M.Keys/layouts(name:id:)"], "such a stand-in, and the Mac skipped the test", OWN, {"M.Keys/layouts(name:id:)": S, "M.Mac/x()": P}, BOTH,
     {**BOTH, "M.Keys/layouts()": S}),
    (["M.Keys/layouts()", "M.Keys/layouts(name:id:)"], "such a stand-in, and the selection left the test out", OWN, {"M.Mac/x()": P}, [*BOTH, "M.Keys/layouts(name:id:)"],
     {**BOTH, "M.Keys/layouts()": S}),
    (["M.Keys/layouts()"], "a test of that name in another suite is not what it stands in for", OWN, {"M.Other/layouts(name:id:)": P}, BOTH,
     {**BOTH, "M.Keys/layouts()": S}),
    (["M.Keys/lay()"], "nor one whose name only begins alike", OWN, {"M.Keys/layouts(name:id:)": P}, BOTH, {**BOTH, "M.Keys/lay()": S}),
    ([], "a test that exists on Linux only", OWN, {"M.Mac/x()": P}, BOTH, {**BOTH, "M.Shim/onlyHere()": P}),
    ([], "a test that failed has run: its own job is red", OWN, {"M.Mac/x()": F}, BOTH, {"M.S/a()": F, "M.S/b()": P}),
    ([], "skipped on both, on purpose", OWN, {"M.Mac/x()": P, "M.S/debugOnly()": S}, BOTH, {**BOTH, "M.S/debugOnly()": S}),
    ([], "skipped on Linux, left out on the Mac, on purpose", OWN, {"M.Mac/x()": P}, [*BOTH, "M.S/debugOnly()"], {**BOTH, "M.S/debugOnly()": S}),
    (["M.Mac/missed()"], "a test only the Mac compiles, which the selection missed", OWN, {"M.Mac/x()": P}, [*BOTH, "M.Mac/missed()"], BOTH),
    (["M.S/notAsRoot()"], "a test Linux skips, which the selection missed", OWN, {"M.Mac/x()": P}, [*BOTH, "M.S/notAsRoot()"],
     {**BOTH, "M.S/notAsRoot()": S}),
    (["M.S/never()"], "skipped on both", OWN, {"M.Mac/x()": P, "M.S/never()": S}, BOTH, {**BOTH, "M.S/never()": S}),
    (["M.S/never()"], "skipped on both, with the Mac running everything", FULL, {**BOTH, "M.S/never()": S}, [], {**BOTH, "M.S/never()": S}),
    (["M.Mac/off()"], "only the Mac compiles it, and skips it", OWN, {"M.Mac/x()": P, "M.Mac/off()": S}, BOTH, BOTH),
    (["M.Carbon/renamed()"], "a stand-in on Linux whose test the Mac no longer has", OWN, {"M.Carbon/codes()": P}, BOTH,
     {**BOTH, "M.Carbon/renamed()": S}),
    (["M.Mac/m1()", "M.Mac/m2()"], "two at once", OWN, {"M.Mac/x()": P}, [*BOTH, "M.Mac/m2()", "M.Mac/m1()"], BOTH),
    (["M.S/a()", "M.S/b()"], "Linux's record is of other tests altogether", OWN, {"M.Mac/x()": P}, BOTH, {"Other.S/a()": P}),
    ([None], "the Mac was to run everything and its record is short", FULL, {"M.S/a()": P}, ["M.S/b()"], BOTH),
    ([None, "M.Mac/x()"], "the same, and nobody else ran it", FULL, BOTH, ["M.Mac/x()"], BOTH),
]
# Here the list is given whole: it lacks what the record has.
STRANGERS = ([None, "M.Mac/x()"], "the record and the list name tests differently", OWN, {"M.Mac.x": P}, {"M.Mac/x()", *BOTH}, BOTH)


def text_of(record):
    return tests.as_text(record)


GOOD = dict(mac=text_of({"M.Mac/x()": P}), all="M.Mac/x()\nM.S/a()\nM.S/b()\n", linux=text_of(BOTH))

# The exit code, the situation, the three files (None: there is no such file), what the output must mention.
COMMANDS = [
    (0, "all is well", GOOD, "2 ran on Linux only"),
    (1, "no record from the Mac", {**GOOD, "mac": None}, "the Mac's record is missing"),
    (1, "no list from the Mac", {**GOOD, "all": None}, "the Mac's list of tests is missing"),
    (1, "no record from Linux", {**GOOD, "linux": None}, "Linux's record is missing"),
    (1, "an empty record from the Mac", {**GOOD, "mac": ""}, "the Mac's record is empty"),
    (1, "an empty list from the Mac", {**GOOD, "all": ""}, "the Mac's list of tests is empty"),
    (1, "a list that holds only chatter", {**GOOD, "all": "Building for debugging...\nBuild complete! (0.1s)\n"}, "the Mac's list of tests is empty"),
    (1, "an empty record from Linux", {**GOOD, "linux": "\n"}, "not a line of a record"),
    (1, "something else in place of a record", {**GOOD, "linux": "<html>not found</html>\n"}, "not a line of a record"),
    (1, "a status nobody knows", {**GOOD, "linux": "M.S/a()\tmaybe\n"}, "not a line of a record"),
    (1, "a test that ran nowhere", {**GOOD, "all": GOOD["all"] + "M.Mac/missed()\n"},
     "::error title=a test ran nowhere::M.Mac/missed(): Linux does not compile it, and the selection for the Mac left it out"),
]


# A stand-in for `swift`: notes what it was asked, writes the event stream it was told to (in $STREAM), ends as told (in $CODE).
SWIFT = """#!/usr/bin/env python3
import json, os, sys
words = sys.argv[1:]
if words[:2] == ["test", "list"]:
    print("Building for debugging...\\nM.S/a()\\nM.S/b()\\nM.Mac/x()")
    sys.exit(int(os.environ["LIST_CODE"]))
with open(os.environ["ASKED"], "w") as handle:
    json.dump(words, handle)
if os.environ["STREAM"] != "none":
    with open(words[words.index("--event-stream-output-path") + 1], "w") as handle:
        handle.write(os.environ["STREAM"])
print("the output of swift test")
sys.exit(int(os.environ["CODE"]))
"""

WHOLE = [START, function(A), function(B), *ran(A), event("testSkipped", B), END]
RED = [START, function(A), issue(A, isKnown=False), *ran(A), END]

# The exit code, whether a record and a list are left, how many filters `swift test` was given; then the situation, the mode, the
# stream the stand-in writes (None: it writes none), its exit code, that of `swift test list`.
RUNS = [
    ((0, True, True, 0), "everything, and it passes", "full", WHOLE, 0, 0),
    ((0, True, True, 0), "no mode at all means everything", "", WHOLE, 0, 0),
    ((0, True, True, "some"), "the selection", "mac-only", WHOLE, 0, 0),
    ((1, True, True, 0), "a test fails: the record says so", "full", RED, 1, 0),
    ((1, False, False, 0), "it does not compile", "full", None, 1, 0),
    ((1, False, False, 0), "it crashes", "full", WHOLE[:-1], 1, 0),
    ((134, False, False, 0), "the exit code of a crash is passed on", "full", WHOLE[:-1], 134, 0),
    ((1, False, False, 0), "it says all is well and the run did not finish", "full", WHOLE[:-1], 0, 0),
    ((1, False, False, 0), "it says all is well and wrote no stream", "full", None, 0, 0),
    ((1, False, False, "some"), "the filters match nothing, which swift test calls a success", "mac-only", [START, END], 0, 0),
    ((1, True, True, 0), "it says all is well and a test failed", "full", RED, 0, 0),
    ((1, True, False, 0), "the tests cannot be listed", "full", WHOLE, 0, 1),
]


def run_run(mode, entries, code, list_code):
    with tempfile.TemporaryDirectory() as folder:
        swift, asked = os.path.join(folder, "swift"), os.path.join(folder, "asked.json")
        record, listing = os.path.join(folder, "record.tsv"), os.path.join(folder, "all.txt")
        with open(swift, "w", encoding="utf-8") as handle:
            handle.write(SWIFT)
        os.chmod(swift, 0o755)
        # What an earlier run left must not survive a run that leaves nothing.
        for path in (record, listing):
            with open(path, "w", encoding="utf-8") as handle:
                handle.write("M.Old/stale()\tpassed\n")
        stream = "none" if entries is None else "".join(json.dumps(entry) + "\n" for entry in entries)
        result = subprocess.run(
            [sys.executable, SCRIPT, "run", "--mode", mode, "--record", record, "--all", listing, "--skip-build", "--no-parallel"],
            capture_output=True, text=True, check=False,
            env={**os.environ, "PATH": folder + os.pathsep + os.environ["PATH"], "ASKED": asked, "STREAM": stream, "CODE": str(code),
                 "LIST_CODE": str(list_code)})
        with open(asked, encoding="utf-8") as handle:
            words = json.load(handle)
        fresh = [os.path.exists(path) and "stale" not in open(path, encoding="utf-8").read() for path in (record, listing)]
        stale = [os.path.exists(path) and "stale" in open(path, encoding="utf-8").read() for path in (record, listing)]
        return result.returncode, fresh, stale, words, result.stdout


def check(wrong, situation, expected, got):
    if got != expected:
        wrong.append(situation)
        print(f"✘ {situation}: expected {expected}, got {got}")


def run_account(files, mode=OWN):
    with tempfile.TemporaryDirectory() as folder:
        paths = {}
        for name, text in files.items():
            paths[name] = os.path.join(folder, name)
            if text is not None:
                with open(paths[name], "w", encoding="utf-8") as handle:
                    handle.write(text)
        page = os.path.join(folder, "summary.md")
        result = subprocess.run(
            [sys.executable, SCRIPT, "account", "--mac", paths["mac"], "--mac-all", paths["all"], "--linux", paths["linux"],
             "--mode", mode, "--why", "made up"],
            capture_output=True, text=True, check=False, env={**os.environ, "GITHUB_STEP_SUMMARY": page})
        written = open(page, encoding="utf-8").read() if os.path.exists(page) else ""
        return result.returncode, result.stdout + result.stderr, written


def main():
    wrong, count = [], 0

    for expected, situation, text in SELECTION:
        count += 1
        check(wrong, f"selection: {situation}", expected, bool(tests.select({"Tests/T/F.swift": text}, always={})))
    count += 2
    check(wrong, "selection: a file on the list, with its reason", {"Tests/T/F.swift": "because"},
          tests.select({"Tests/T/F.swift": PLAIN, "Tests/T/G.swift": PLAIN}, always={"Tests/T/F.swift": "because"}))
    check(wrong, "selection: a file on the list that is gone", ["Tests/T/Gone.swift"],
          tests.missing_from({"Tests/T/Gone.swift": "because"}, {"Tests/T/F.swift": PLAIN}))

    filters = tests.filters_for(["Tests/ArborKitTests/Mac.swift", "Tests/ArborCoreTests/Deep/Also.swift"])
    for expected, identifier in FILTERED:
        count += 1
        check(wrong, f"filter: {identifier}", expected, any(re.search(pattern, identifier) for pattern in filters))

    for expected, situation, entries in STREAMS:
        count += 1
        try:
            got = tests.record_of([json.dumps(entry) for entry in entries])
        except tests.Untrustworthy:
            got = REFUSED
        check(wrong, f"record: {situation}", expected, got)
    count += 3
    half = [json.dumps(entry) for entry in [START, function(A), *ran(A), END]]
    try:
        got = tests.record_of(half[:-1] + [half[-1][:20]])
    except tests.Untrustworthy:
        got = REFUSED
    check(wrong, "record: a last line cut short", REFUSED, got)
    count += 1
    odd = json.dumps(event("testCaseStarted", A, messages=[{"text": "a name with \u2028, \u0085 and \x0c in it"}]), ensure_ascii=False)
    check(wrong, "record: separators of lines that JSON leaves as they are", {"M.S/a()": P},
          tests.record_of(tests.lines_of("\n".join(half[:2] + [odd] + half[2:]) + "\n")))
    check(wrong, "record: the same id from either branch of a condition", tests.test_id("M.Carbon/codes()/C.swift:12:6"),
          tests.test_id("M.Carbon/codes()/C.swift:38:6"))
    record = {"M.S/b()": S, "M.S/a()": P, "M.`a b`()": F}
    check(wrong, "record: written sorted, and read back", (record, sorted(record)),
          (tests.record_from_text(text_of(record), "it"), [line.split("\t")[0] for line in text_of(record).splitlines()]))

    for expected, situation, mode, mac, more, linux in NET + [STRANGERS]:
        count += 1
        listed = set(more) if situation == STRANGERS[1] else set(mac) | set(more)
        _, complaints = tests.account(mac, listed, linux, mode, on_purpose=ON_PURPOSE)
        check(wrong, f"net: {situation}", expected, [name for name, _ in complaints])

    count += 3
    groups, complaints = tests.account({"M.Mac/x()": P, "M.S/a()": P, "M.S/debugOnly()": S}, {"M.Mac/x()", "M.S/debugOnly()", *BOTH},
                                       {**BOTH, "M.S/debugOnly()": S, "M.Shim/l()": P}, OWN, on_purpose=ON_PURPOSE)
    check(wrong, "net: how many ran where", dict(both=1, mac=1, linux=2, purpose=1, nowhere=0),
          dict(both=len(groups["both"]), mac=len(groups["mac"]), linux=len(groups["linux"]), purpose=len(groups["on purpose"]),
               nowhere=len(groups["nowhere"])))
    check(wrong, "net: an excuse that is still needed", [], tests.stale(groups, ON_PURPOSE))
    groups, _ = tests.account({"M.S/debugOnly()": P}, {"M.S/debugOnly()"}, BOTH, OWN, on_purpose=ON_PURPOSE)
    check(wrong, "net: an excuse for a test that ran", ["M.S/debugOnly()"], tests.stale(groups, ON_PURPOSE))

    for text, expected in [("mac-only", OWN), ("full", FULL), ("", FULL), ("none", FULL), ("MAC-ONLY", FULL), ("mac-only ", FULL)]:
        count += 1
        check(wrong, f"mode: {text!r}", expected, tests.mode_of(text))

    for expected, situation, files, mention in COMMANDS:
        count += 1
        code, output, _ = run_account(files)
        check(wrong, f"account: {situation}", (expected, True), (code, mention in output))
    count += 2
    many = GOOD["all"] + "".join(f"M.Mac/m{index:02}()\n" for index in range(25))
    code, output, page = run_account({**GOOD, "all": many})
    check(wrong, "account: more tests than GitHub shows annotations, all of them named", (1, tests.LIMIT, 25, 25),
          (code, output.count("::error "), sum(1 for index in range(25) if output.count(f"M.Mac/m{index:02}()") >= 2),
           page.count(" ran nowhere: ")))
    code, output, page = run_account(GOOD)
    check(wrong, "account: the summary names the mode and the reason", (0, True, True),
          (code, "mode `mac-only`" in page and "made up" in page, "mode mac-only" in output))

    for (code, record, listing, filters), situation, mode, entries, swift_code, list_code in RUNS:
        count += 1
        got, fresh, stale, words, output = run_run(mode, entries, swift_code, list_code)
        given = words.count("--filter")
        check(wrong, f"run: {situation}", (code, [record, listing], [False, False], filters, True, True),
              (got, fresh, stale, "some" if filters == "some" and given > 0 else given,
               words[-2:] == ["--skip-build", "--no-parallel"], "the output of swift test" in output))

    # The two lists in the script against the sources, so that a renamed file or test is noticed here and not on the Mac.
    count += 2
    sources = tests.read_sources(tests.ROOT)
    check(wrong, "the tree: every file in ALWAYS exists", [], tests.missing_from(tests.ALWAYS, sources))
    everything = "\n".join(sources.values())
    check(wrong, "the tree: every test in NOWHERE_ON_PURPOSE exists", [],
          [name for name in sorted(tests.NOWHERE_ON_PURPOSE) if f"func {re.split(r'[/.]', name)[-1].split('(')[0]}(" not in everything])

    print(f"{count - len(wrong)} of {count} rows came out as expected")
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
