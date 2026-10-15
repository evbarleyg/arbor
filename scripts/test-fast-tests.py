#!/usr/bin/env python3
"""Holds fast-tests.py to a table: Swift it must cut in the right place, Swift it must refuse, runs and records that must not pass.

A cut in the wrong place is loud when what is left does not compile. It is silent when it takes a test with it that was meant to
stay, or a helper, or leaves a test in two parts; and a net that lets a lost test through is worth nothing. Then the real
test files: every `@Test` in them is found, every file is in exactly one part, and all parts together hold all tests.
`make lint` runs this. Exit code 1 when a row comes out wrong.
"""

import importlib.util
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("fast_tests", os.path.join(HERE, "fast-tests.py"))
shard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shard)

rows = []


def row(what, got, expected):
    rows.append((what, got, expected))


def left(text):
    """What stays of a text, without the empty lines the cut leaves."""
    try:
        return re.sub(r"\n\s*\n+", "\n", shard.without_tests(text)).strip()
    except shard.Unreadable:
        return "REFUSED"


SUITE = "@Suite struct S {\n%s\n  func helper() { f { 1 } }\n}"
KEPT = "@Suite struct S {\n  func helper() { f { 1 } }\n}"

# What a test may look like. Each goes, whole, and nothing else does.
for what, test in [
    ("a plain test", "  @Test func a() { #expect(1 == 1) }"),
    ("braces inside", "  @Test func a() {\n    if x { y { z } }\n  }"),
    ("a name in words", '  @Test("it holds") func a() {}'),
    ("arguments with brackets and a closure", "  @Test(arguments: [(1, 2)].map { $0 }) func a(p: (Int, Int)) {}"),
    ("a trait with a string that holds a brace", '  @Test(.disabled("only on macOS }")) func a() {}'),
    ("the function on the next line", "  @Test\n  func a() {}"),
    ("an attribute after it", "  @Test @MainActor func a() async throws {}"),
    ("an attribute before it", "  @MainActor @Test func a() {}"),
    ("an attribute on the line before it", "  @MainActor\n  @Test func a() {}"),
    ("an attribute with arguments before it", "  @available(macOS 14, *) @Test func a() {}"),
    ("a default value that is a closure", "  @Test func a(f: () -> Int = { 1 }) {}"),
    ("a brace in a string", '  @Test func a() { let s = "}" }'),
    ("a quotation mark in a string", '  @Test func a() { let s = "\\"}" }'),
    ("a brace in what a string works out", '  @Test func a() { let s = "\\(f { "}" })" }'),
    ("a brace in a raw string", '  @Test func a() { let s = #"\\"}"# }'),
    ("a raw string that works something out", '  @Test func a() { let s = #"\\#(f { 1 })}"# }'),
    ("quotation marks alone in a raw string", '  @Test func a() { let s = [#""""#, #""}""#] }'),
    ("a string of several lines", '  @Test func a() {\n    let s = """\n      } "quoted" }\n      """\n  }'),
    ("a raw string of several lines", '  @Test func a() {\n    let s = #"""\n      } """ }\n      """#\n  }'),
    ("a brace in a comment", "  @Test func a() {\n    // }\n    /* } /* } */ } */\n  }"),
    ("an apostrophe in a comment", "  @Test func a() {\n    // it's \"not a string\n  }"),
    ("a brace in a regular expression", "  @Test func a() { let r = /\\}[\"]/ }"),
    ("a brace in an extended regular expression", "  @Test func a() { let r = #/}\"/# }"),
    ("a division", '  @Test func a() { let x = b / c; let y = d / e; let s = "}" }'),
    ("two tests", "  @Test func a() {}\n  @Test func b() {}"),
    ("a generic test", "  @Test func a<T: P>(x: T) where T: Q {}"),
]:
    row(f"cut: {what}", left(SUITE % test), KEPT)

row("cut: a condition around a test stays", left(SUITE % "  #if os(macOS)\n  @Test func a() {}\n  #endif"),
    KEPT.replace("{\n", "{\n  #if os(macOS)\n  #endif\n", 1))
row("cut: a test outside any suite", left("@Test func a() {}\nfunc helper() {}"), "func helper() {}")
row("cut: a suite inside a suite", left("struct A {\n  struct B {\n    @Test func a() {}\n    let x = 1\n  }\n}"), "struct A {\n  struct B {\n    let x = 1\n  }\n}")
row("cut: the comment above a test stays, which harms nothing", left("struct A {\n  /// Why.\n  @Test func a() {}\n}"), "struct A {\n  /// Why.\n}")
for what, text in [
    ("@Test in a comment", "struct A {\n  // @Test func a() {}\n  let x = 1\n}"),
    ("@Test in a string", 'struct A {\n  let s = "@Test func a() {}"\n}'),
    ("@Test in a string of several lines", 'struct A {\n  let s = """\n    @Test func a() {\n    """\n}'),
    ("another attribute that begins alike", "struct A {\n  @Tested func a() {}\n}"),
    ("no test at all", "extension Harness {\n  func f() { g { 1 } }\n}"),
    ("nothing", ""),
]:
    row(f"cut: left alone: {what}", left(text), text.strip())
for what, text in [
    ("a test that is not closed", "@Test func a() {\n  x()\n"),
    ("a string that does not end", 'struct A {\n  @Test func a() { let s = "\n }\n}'),
    ("a string that is open where the file ends", '@Test func a() { let s = "abc'),
    ("a raw string that is open where the file ends", '@Test func a() { let s = #"abc"'),
    ("brackets that do not match", "struct A {\n  @Test func a() { f(] }\n}"),
    ("@Test on something that is no function", "struct A {\n  @Test var a: Int { 1 }\n}"),
    ("@Test and then the end of the suite", "struct A {\n  @Test\n}\nfunc f() {}"),
    ("@Test and then nothing", "@Test"),
]:
    row(f"cut: refused: {what}", left(text), "REFUSED")

# MARK: what Linux compiles


def counted(text):
    try:
        return shard.declared(text)
    except shard.Unreadable:
        return "REFUSED"


TEST = "@Test func %s() {}\n"
for what, text, expected in [
    ("no condition", TEST % "a" + TEST % "b", 2),
    ("only on macOS", "#if os(macOS)\n" + TEST % "a" + "#endif\n" + TEST % "b", 1),
    ("only off macOS", "#if !os(macOS)\n" + TEST % "a" + "#endif\n", 1),
    ("one for each", "#if os(macOS)\n" + TEST % "a" + "#else\n" + TEST % "a" + TEST % "b" + "#endif\n", 2),
    ("a framework Linux lacks", "#if canImport(AppKit)\n" + TEST % "a" + "#endif\n", 0),
    ("three branches, the second taken", "#if os(macOS)\n" + TEST % "a" + "#elseif os(Linux)\n" + TEST % "b" + "#else\n" + TEST % "c" + "#endif\n", 1),
    ("three branches, the first taken", "#if os(Linux)\n" + TEST % "a" + "#elseif canImport(Glibc)\n" + TEST % "b" + "#else\n" + TEST % "c" + "#endif\n", 1),
    ("one inside another", "#if os(Linux)\n#if os(macOS)\n" + TEST % "a" + "#else\n" + TEST % "b" + "#endif\n" + TEST % "c" + "#endif\n", 2),
    ("inside one that is not taken", "#if os(macOS)\n#if os(Linux)\n" + TEST % "a" + "#endif\n#endif\n", 0),
    ("both must hold", "#if os(Linux) && canImport(AppKit)\n" + TEST % "a" + "#endif\n", 0),
    ("either may hold", "#if os(macOS) || (os(Linux) && !canImport(Carbon))\n" + TEST % "a" + "#endif\n", 1),
    ("a comment after the condition", "#if os(macOS) // the real thing\n" + TEST % "a" + "#endif\n", 0),
    ("a condition inside a test is the test's own business", "@Test func a() {\n#if os(macOS)\n  x()\n#endif\n}\n", 1),
    ("a condition in a string", 'let s = """\n#if os(macOS)\n"""\n' + TEST % "a", 1),
    ("a condition in a comment", "// #if os(macOS)\n" + TEST % "a", 1),
    ("a condition nobody has answered", "#if canImport(CoreGraphics)\n" + TEST % "a" + "#endif\n", "REFUSED"),
    ("a flag nobody has answered", "#if FAST\n" + TEST % "a" + "#endif\n", "REFUSED"),
    ("a question about the compiler", "#if swift(>=6.4)\n" + TEST % "a" + "#endif\n", "REFUSED"),
    ("no condition at all", "#if\n" + TEST % "a" + "#endif\n", "REFUSED"),
    ("something that is no condition", "#if os(Linux) os(macOS)\n" + TEST % "a" + "#endif\n", "REFUSED"),
    ("an attempt at something else", "#if __import__\n" + TEST % "a" + "#endif\n", "REFUSED"),
    ("never closed", "#if os(Linux)\n" + TEST % "a", "REFUSED"),
    ("closed and never opened", TEST % "a" + "#endif\n", "REFUSED"),
    ("#else out of the blue", "#else\n" + TEST % "a", "REFUSED"),
]:
    row(f"on Linux: {what}", counted(text), expected)
row("cut: a test only a Mac compiles goes too", left("#if os(macOS)\n" + TEST % "a" + "#endif\nlet x = 1"), "#if os(macOS)\n#endif\nlet x = 1")
row("weight: a test only a Mac compiles weighs nothing here", shard.weight("#if os(macOS)\n" + TEST % "a" + "#endif\n"), 0)

numbered = "struct A {\n  @Test func a() {\n    x()\n  }\n  func helper() {}\n}\n"
row("cut: lines keep their numbers", shard.without_tests(numbered).split("\n").index("  func helper() {}"), numbered.split("\n").index("  func helper() {}"))

# MARK: the plan

weights = {"a": 50, "b": 30, "c": 20, "d": 20, "e": 10, "f": 0}
row("plan: the heaviest first, each to the lightest part", shard.plan(weights, 2), [["a", "d"], ["b", "c", "e", "f"]])
row("plan: every file in exactly one part", sorted(name for part in shard.plan(weights, 4) for name in part), sorted(weights))
row("plan: the same whatever the order", shard.plan(dict(reversed(list(weights.items()))), 3), shard.plan(weights, 3))
row("plan: one part has everything", shard.plan(weights, 1), [sorted(weights)])
row("plan: more parts than files", sum(1 for part in shard.plan({"a": 1}, 3) if part), 1)
row("weight: a helper weighs nothing", shard.weight("func helper() {\n  #expect(true)\n}"), 0)
row("weight: an expectation weighs more than a line",
    shard.weight("@Test func a() {\n  #expect(x)\n}") > shard.weight("@Test func a() {\n  x()\n}"), True)

# MARK: one file's process


def stream(*entries):
    return "".join(json.dumps(entry) + "\n" for entry in entries)


def test(name, kind="function"):
    return {"kind": "test", "payload": {"kind": kind, "id": name}}


def event(kind, name=None, **more):
    return {"kind": "event", "payload": {"kind": kind, **({"testID": name} if name else {}), **more}}


A, B = "M.S/a()/F.swift:3:4", "M.S/b()/F.swift:7:4"
BEGIN, END = event("runStarted"), event("runEnded")
FINE = stream(test("M.S", "suite"), test(A), test(B), BEGIN, event("testStarted", A), event("testEnded", A), event("testSkipped", B), END)
RED = stream(test(A), BEGIN, event("testStarted", A), event("issueRecorded", A, issue={"isKnown": False}), event("testEnded", A), END)
KNOWN = stream(test(A), BEGIN, event("testStarted", A), event("issueRecorded", A, issue={"isKnown": True}), event("testEnded", A), END)


def verdict(expected, code, events):
    return shard.judged("F.swift", expected, code, events)[1] or "fine"


row("run: all is well", verdict(2, 0, FINE), "fine")
row("run: what became of each test", shard.judged("F.swift", 2, 0, FINE)[0], {A: "passed", B: "skipped"})
row("run: a failed test is no reason to distrust the rest", shard.judged("F.swift", 1, 1, RED)[2], True)
row("run: a test that did not run is", shard.judged("F.swift", 3, 0, FINE)[2], False)
row("run: so is a crash", shard.judged("F.swift", 1, 139, stream(test(A), BEGIN))[2], False)
row("run: so is an exit code nothing explains", shard.judged("F.swift", 2, 1, FINE)[2], False)
row("run: a known issue fails nothing", verdict(1, 0, KNOWN), "fine")
row("run: a test failed", verdict(1, 1, RED), "F.swift: 1 of 1 tests failed")
row("run: a test failed, and the process says all is well", verdict(1, 0, RED), "F.swift: 1 of 1 tests failed")
row("run: no test failed, and the process says otherwise", "exit code 1" in verdict(2, 1, FINE), True)
row("run: fewer tests than the file declares", verdict(3, 0, FINE), "F.swift declares 3 tests and 2 ran")
row("run: more tests than the file declares", verdict(1, 0, FINE), "F.swift declares 1 tests and 2 ran")
row("run: the filter matched nothing", verdict(2, 0, stream(BEGIN, END)), "F.swift declares 2 tests and 0 ran")
row("run: a crash", "did not finish" in verdict(1, 139, stream(test(A), BEGIN, event("testStarted", A))), True)
row("run: killed in the middle of a line", "cannot be read" in verdict(1, 137, stream(test(A), BEGIN) + '{"kind": "ev'), True)
row("run: it never began", "no test run" in verdict(1, 1, ""), True)
row("run: two runs where one process makes one", "holds 2 test runs" in verdict(2, 0, FINE + KNOWN), True)
row("whole: a run for each test target", len(shard.outcome_of(FINE + stream(test("N.T/c()/G.swift:1:2"), BEGIN, event("testEnded", "N.T/c()/G.swift:1:2"), END), runs=None)), 3)
row("run: a test nothing is said of", "nothing says what became of it" in verdict(1, 0, stream(test(A), BEGIN, END)), True)
row("run: a test that began and did not end", "nothing says what became of it" in verdict(1, 0, stream(test(A), BEGIN, event("testStarted", A), END)), True)
row("record: sorted, without the place in the source", shard.as_record({B: "skipped", A: "passed"}), "M.S/a()\tpassed\nM.S/b()\tskipped\n")
row("record: of two functions with one id the worse news counts",
    shard.as_record({"M.S/a(_:)/F.swift:3:4": "passed", "M.S/a(_:)/F.swift:9:4": "failed"}), "M.S/a(_:)\tfailed\n")

# MARK: the net


def net(declared, *streams):
    return shard.joined([(f"part-{index}", events) for index, events in enumerate(streams, start=1)], declared)[1]


def says(problems, words):
    return any(words in problem for problem in problems)


def ran(*names, outcome="testEnded"):
    return stream(*(test(name) for name in names), BEGIN, *(event(outcome, name) for name in names), END)


C, TWIN = "M.T/c()/G.swift:1:2", "M.S/a()/F.swift:9:4"
row("join: all is well", net(3, FINE, ran(C)), [])
row("join: a failed test is a test that ran", net(1, RED), [])
row("join: several runs in a part", net(3, FINE + ran(C)), [])
row("join: one test too few", says(net(4, FINE, ran(C)), "declare 4 tests and the parts ran 3"), True)
row("join: one test too many", says(net(1, FINE), "declare 1 tests and the parts ran 2"), True)
row("join: a test in two parts", says(net(2, ran(A), FINE), f"{A} ran in two parts"), True)
row("join: a test in two parts makes up for a lost one in no count", net(2, ran(A), ran(A)) != [], True)
row("join: two functions that share an id are two tests", net(2, ran(A, TWIN)), [])
row("join: a part that ran nothing", says(net(1, ran(A), stream(BEGIN, END)), "part-2: that part ran nothing"), True)
row("join: a part that left nothing", says(net(1, ran(A), ""), "part-2: the event stream holds no test run"), True)
row("join: a part that did not finish", says(net(2, ran(A), stream(test(C), BEGIN)), "part-2: the run did not finish"), True)
row("join: something that is no event stream", says(net(1, "Test run with 1 test passed\n"), "cannot be read"), True)
row("join: the whole record", shard.as_record(shard.joined([("1", ran(B, outcome="testSkipped")), ("2", ran(A))], 2)[0]), "M.S/a()\tpassed\nM.S/b()\tskipped\n")

# MARK: whole and in parts

ONE = "M.S/a()\tpassed\nM.S/b()\tskipped\n"
row("same: they agree", shard.differences(ONE, ONE), [])
row("same: a test no part ran", shard.differences(ONE, "M.S/a()\tpassed\n"), ["M.S/b() ran whole (skipped) and in no part"])
row("same: a test only a part ran", shard.differences("M.S/a()\tpassed\n", ONE), ["M.S/b() ran in a part (skipped) and not whole"])
row("same: another outcome", shard.differences(ONE, ONE.replace("skipped", "passed")), ["M.S/b(): skipped whole, passed in its part"])

# MARK: `run` from end to end

# A stand-in for a test runner. It knows the tests of two files and does what BEHAVE says, as the real one would: it lists, it heeds the filter, it
# writes the event stream, it prints, it exits with 1 when a test failed.
RUNNER = '''#!/usr/bin/env python3
import json, os, re, sys
tests = {"T.A/one()/A.swift:1:2": "A.swift", "T.A/two()/A.swift:2:2": "A.swift", "T.B/three()/B.swift:1:2": "B.swift"}
behave = os.environ.get("BEHAVE", "")
if behave == "more": tests["T.B/four()/B.swift:9:2"] = "B.swift"
arguments = sys.argv[1:]
if "--list-tests" in arguments:
    print("\\n".join(re.sub(r"/[^/]+:\\d+:\\d+$", "", name) for name in tests))
    sys.exit(0)
pattern = arguments[arguments.index("--filter") + 1]
mine = [] if behave == "deaf" else [name for name in tests if re.search(pattern, name)]
with open(arguments[arguments.index("--event-stream-output-path") + 1], "w") as events:
    def say(what, **payload): events.write(json.dumps({"kind": what, "payload": payload}) + "\\n"); events.flush()
    for name in mine: say("test", kind="function", id=name)
    say("event", kind="runStarted")
    for name in mine:
        if behave == "crash" and "three" in name: os.abort()
        if behave == "red" and "two" in name: say("event", kind="issueRecorded", testID=name, issue={"isKnown": False})
        say("event", kind="testEnded", testID=name)
        print("ran", name, "at home in", os.environ["TMPDIR"], "which is", "there" if os.path.isdir(os.environ["TMPDIR"]) else "missing", "told", os.environ.get("ARBOR_HOME"))
    say("event", kind="runEnded")
sys.exit(1 if behave == "red" and any("two" in name for name in mine) else 0)
'''


def tried(behave="", sources=None, *more):
    """What `run` does in a made-up checkout: its exit code, what it printed, and the files it left."""
    with tempfile.TemporaryDirectory() as folder:
        os.makedirs(os.path.join(folder, "Tests", "T"))
        os.makedirs(os.path.join(folder, ".build", "debug"))
        for name, text in (sources or {"A.swift": TEST % "one" + TEST % "two", "B.swift": TEST % "three", "Helpers.swift": "func f() {}\n"}).items():
            with open(os.path.join(folder, "Tests", "T", name), "w", encoding="utf-8") as handle:
                handle.write(text)
        with open(os.path.join(folder, ".build", "debug", "T-test-runner"), "w", encoding="utf-8") as handle:
            handle.write(RUNNER)
        os.chmod(os.path.join(folder, ".build", "debug", "T-test-runner"), 0o755)
        for name in ("record", "events", "log"):
            with open(os.path.join(folder, name), "w", encoding="utf-8") as handle:
                handle.write("left by an earlier run\n")
        done = subprocess.run([sys.executable, os.path.join(HERE, "fast-tests.py"), "run", "--no-build", "--root", folder, "--jobs", "2", "--record",
                               os.path.join(folder, "record"), "--events", os.path.join(folder, "events"), "--log", os.path.join(folder, "log"), *more],
                              env={**os.environ, "BEHAVE": behave, "ARBOR_HOME": "/the/callers"}, capture_output=True, text=True, check=False)
        left = {}
        for name in ("record", "events", "log"):
            if os.path.exists(os.path.join(folder, name)):
                with open(os.path.join(folder, name), encoding="utf-8") as handle:
                    left[name] = handle.read()
        return done.returncode, done.stdout + done.stderr, left


code, said, files = tried()
row("run, whole: all is well", (code, "3 tests of 2 files" in said, "3 passed, 0 failed, 0 skipped" in said), (0, True, True))
row("run, whole: the record", files.get("record"), "T.A/one()\tpassed\nT.A/two()\tpassed\nT.B/three()\tpassed\n")
row("run, whole: the event streams, each a finished run", len(shard.outcome_of(files.get("events", ""), runs=2)), 3)
row("run, whole: a file that passes prints nothing, and the log has it all", ("ran T.A" in said, files.get("log", "").count("ran T.")), (False, 3))
row("run, whole: each file has a temporary folder of its own, which is there", (len(set(re.findall(r"at home in (\S+) which is there", files.get("log", "")))),
    max(map(len, re.findall(r"at home in (\S+)", files.get("log", ""))), default=99) < 40), (2, True))
row("run, whole: and no ARBOR_HOME, whatever the caller has", set(re.findall(r"told (\S+)", files.get("log", ""))), {"None"})
row("run, whole: --verbose prints it", "ran T.A/one()" in tried("", None, "--verbose")[1], True)
code, said, files = tried("red")
row("run, whole: a test fails", (code, "✘ Tests/T/A.swift: 1 of 2 tests failed" in said, "ran T.A/one()" in said, "ran T.B" in said), (1, True, True, False))
row("run, whole: and is in the record", files.get("record"), "T.A/one()\tpassed\nT.A/two()\tfailed\nT.B/three()\tpassed\n")
code, said, files = tried("crash")
row("run, whole: a crash", (code, "✘ Tests/T/B.swift: the run did not finish" in said), (1, True))
row("run, whole: leaves neither record nor events, not an earlier run's either", sorted(files), ["log"])
code, said, files = tried("deaf")
row("run, whole: the filter matches nothing", (code, "✘ Tests/T/A.swift declares 2 tests and 0 ran" in said, sorted(files)), (1, True, ["log"]))
code, said, files = tried("more")
row("run, whole: more was built than this reads", (code, "T was built with 4 tests, and this reads 3" in said, sorted(files)), (2, True, []))
code, said, files = tried("", {"A.swift": TEST % "one" + TEST % "two", "B.swift": "#if os(macOS)\n" + TEST % "three" + "#endif\n"})
row("run, whole: less is read than was built", (code, "T was built with 3 tests, and this reads 2" in said), (2, True))
row("run, whole: no test at all", (tried("", {"Helpers.swift": "func f() {}\n"})[0], "not one test" in tried("", {"Helpers.swift": "func f() {}\n"})[1]), (2, True))
code, said, files = tried("", {"A.swift": TEST % "one", "B.swift": "#if FAST\n" + TEST % "three" + "#endif\n"})
row("run, whole: a refusal names the file", (code, "✘ fast-tests.py: Tests/T/B.swift: a condition this cannot work out, on line 1: FAST" in said), (2, True))

# MARK: the gate

# gate.sh itself, with a stand-in for everything it starts. Each says its name and fails if FAIL names it. The rule for `check` is the real
# Makefile's, so these rows hold whatever steps it has.
STAND_IN = '#!/bin/sh\nname="%s${1:+ $1}"\ncase ",$FAIL," in *",$name,"*) echo "$name says no"; exit 3;; esac\necho "$name is fine"\n'
PYTHON_STAND_IN = 'import os, sys\nname = "%s"\nif name in os.environ["FAIL"].split(","):\n    print(name, "says no")\n    sys.exit(3)\nprint(name, "is fine")\n'
with open(os.path.join(shard.ROOT, "Makefile"), encoding="utf-8") as handle:
    CHECK = re.search(r"^check:.*\n(?:(?:\t|#).*\n)*", handle.read(), re.M).group()
RECIPE = [line for line in CHECK.split("\n") if line.startswith("\t")]
# lint, build, tests, typecheck-mac, parity, and the recipe.
STEPS = 5 + len(RECIPE)


def gate(fail="", *arguments, rule=CHECK):
    """The exit code of gate.sh and what it printed when the steps FAIL names fail."""
    with tempfile.TemporaryDirectory() as folder:
        os.makedirs(os.path.join(folder, "scripts"))
        os.makedirs(os.path.join(folder, "bin"))
        shutil.copy(os.path.join(HERE, "gate.sh"), os.path.join(folder, "scripts", "gate.sh"))
        with open(os.path.join(folder, "Makefile"), "w", encoding="utf-8") as handle:
            handle.write("lint:\n\t@true\n\n" + rule + "\nafter:\n\t@./scripts/not-of-check.sh\n")
        for path in {"bin/make", "bin/swift", "scripts/fast-tests.py", "scripts/parity.py", *re.findall(r"scripts/[\w./-]+", rule)}:
            run_by_python = path.endswith(".py") and path != "scripts/fast-tests.py"
            with open(os.path.join(folder, path), "w", encoding="utf-8") as handle:
                handle.write((PYTHON_STAND_IN if run_by_python else STAND_IN) % os.path.basename(path))
            os.chmod(os.path.join(folder, path), 0o755)
        done = subprocess.run(["bash", os.path.join(folder, "scripts", "gate.sh"), *arguments], capture_output=True, text=True, check=False,
                              env={**os.environ, "PATH": os.path.join(folder, "bin") + os.pathsep + os.environ["PATH"], "FAIL": fail})
        return done.returncode, done.stdout + done.stderr


if platform.system() != "Linux":
    print("SKIPPED the rows that run gate.sh: it declines off Linux")
else:
    code, said = gate()
    row("gate.sh: all is well", (code, said.count("✔"), "the gate is open" in said), (0, STEPS, True))
    row("gate.sh: every line of the recipe of `make check` is a step",
        [line for line in RECIPE if "✔ " + os.path.splitext(os.path.basename(re.search(r"scripts/[\w./-]+", line).group()))[0] + " " not in said], [])
    row("gate.sh: and nothing of the rule after it", "not-of-check" in said, False)
    code, said = gate(rule=CHECK + "\t@./scripts/brand-new.sh\n")
    row("gate.sh: a step added to `make check` is a step of it", (code, said.count("✔"), "✔ brand-new " in said), (0, STEPS + 1, True))
    code, said = gate("brand-new.sh --thoroughly", rule=CHECK + "# And then:\n\t@./scripts/brand-new.sh --thoroughly && ./scripts/scenarios.sh\n")
    row("gate.sh: after a comment too, with its arguments, and it can fail", (code, "brand-new.sh --thoroughly says no" in said, "the gate is shut: brand-new (" in said), (1, True, True))
    code, said = gate(rule=CHECK.replace("check: lint build test", "check: lint build test more"))
    row("gate.sh: something `make check` depends on besides", (CHECK.startswith("check: lint build test\n"), code, said.count("✔"), "✔ more " in said), (True, 0, STEPS + 1, True))
    code, said = gate(rule=CHECK + "\t@$(MAKE) more\n")
    row("gate.sh: a line only make can read is refused, not left out", (code, "cannot run this line" in said), (1, True))
    code, said = gate(rule="verify: lint\n\t@true\n")
    row("gate.sh: no rule for check", (code, "the Makefile has no rule for check" in said), (1, True))
    code, said = gate("scenarios.sh")
    row("gate.sh: a step fails", (code, "✘ scenarios" in said, "scenarios.sh says no" in said, "the gate is shut: scenarios (" in said), (1, True, True, True))
    row("gate.sh: and all the others still run", said.count("✔"), STEPS - 1)
    code, said = gate("make typecheck-mac,test-tooling.py")
    row("gate.sh: steps in the background fail", (code, "the gate is shut: test-tooling typecheck-mac (" in said), (1, True))
    code, said = gate("make lint")
    row("gate.sh: lint fails, and the rest is still looked at", (code, said.count("✔"), "the gate is shut: lint (" in said), (1, STEPS - 1, True))
    code, said = gate("swift build")
    row("gate.sh: it does not build, so nothing else is tried", (code, said.count("✔"), "it does not build" in said), (1, 1, True))
    code, said = gate("fast-tests.py run")
    row("gate.sh: the tests fail, so parity is not asked", (code, "not asked" in said, "the gate is shut: tests (" in said), (1, True, True))
    row("gate.sh: parity fails", gate("parity.py")[0], 1)
    row("gate.sh: an argument it does not know", (gate("", "--fast")[0], "✔" in gate("", "--fast")[1]), (64, False))

# MARK: the real files

root = shard.ROOT
names = shard.test_files(root)
unreadable = []
for name in names:
    try:
        shard.read(root, name)
    except shard.Unreadable as error:
        unreadable.append(str(error))
row("the real files: all can be read", unreadable, [])
if unreadable:
    names = []
counts = {name: len(shard.tests_in(shard.read(root, name))) for name in names}
linux = {name: shard.declared(shard.read(root, name)) for name in names}
row("the real files: there are some", len(names) > 100, True)
row("the real files: every @Test is found",
    {name: count for name, count in counts.items() if count != len(re.findall(r"^\s*(?:@\w+\s+)*@Test\b", shard.read(root, name), re.M))}, {})
# In a part the other files' tests are gone, so a test that reads the sources of the tests would see something else than in the checkout.
row("the real files: no test reads the sources of the tests",
    [name for name in names if re.search(r'''"Tests[/"]|/Tests/''', shard.read(root, name))], [])
for parts in (1, 5):
    with tempfile.TemporaryDirectory() as folder:
        stayed = []
        for part in range(1, parts + 1):
            copy = os.path.join(folder, str(part))
            shutil.copytree(os.path.join(root, "Tests"), os.path.join(copy, "Tests"))
            stay, gone = shard.cut(copy, part, parts)
            kept = {name: len(shard.tests_in(shard.read(copy, name))) for name in names}
            there = sum(shard.declared(shard.read(copy, name)) for name in names)
            row(f"the real files, part {part} of {parts}: what it says is what is there", (stay, stay + gone), (there, sum(linux.values())))
            row(f"the real files, part {part} of {parts}: a file keeps all of its tests or none",
                [name for name in names if kept[name] not in (0, counts[name])], [])
            stayed.append({name for name in names if kept[name]})
        row(f"the real files, {parts} parts: every file with tests is whole in exactly one",
            sorted(name for part in stayed for name in part), sorted(name for name in names if counts[name]))
    weights, shares = shard.planned(root, parts)
    heavy = [sum(weights[name] for name in share) for share in shares]
    row(f"the real files, {parts} parts: the heaviest is within a tenth of the lightest", max(heavy) <= min(heavy) * 1.1, True)


def main():
    wrong = 0
    for what, got, expected in rows:
        if got != expected:
            wrong += 1
            print(f"✘ {what}: expected {expected!r}, got {got!r}")
    print(f"{len(rows) - wrong} of {len(rows)} rows as expected")
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
