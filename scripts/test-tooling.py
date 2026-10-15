#!/usr/bin/env python3
"""Checks that the tools which say "all is well" can also say the opposite.

parity.py, ci-step.py, scenarios.sh with arbor-sim, lint-imports.py, lint-mac-shell.py, mutate.py, fuzz-launch.py, ci-mtimes.py, reality-diff.py and the safety nets of
scripts/mac-shell/lib.sh each get situations that must come out as failures (a misspelt status, a test that was renamed, a record cut off by a crash, a scenario whose
commands do nothing) next to ones that must pass. Every row here passed when it should have failed
before 2026-10-14.

arbor-e2e's guardian gets its situations too; test-e2e-guardian.py has them.

`make check` runs this. The scenario rows need .build/debug/arbor-sim and are skipped, loudly, without it; so is the row for the fake Mac's
list of windows without .build/debug/arbor-fakemac.
The rows for lib.sh run small scripts for real, against stand-ins for a Mac, under `bash` or $ARBOR_TEST_BASH (macOS has 3.2).
Exit code 1 when a row comes out wrong.
"""

import concurrent.futures
import contextlib
import fnmatch
import importlib.util
import io
import json
import os
import pty
import re
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import mutate  # noqa: E402
import parity  # noqa: E402

spec = importlib.util.spec_from_file_location("lint_imports", os.path.join(HERE, "lint-imports.py"))
lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint)

spec = importlib.util.spec_from_file_location("lint_mac_shell", os.path.join(HERE, "lint-mac-shell.py"))
mac_lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mac_lint)

spec = importlib.util.spec_from_file_location("fuzz_launch", os.path.join(HERE, "fuzz-launch.py"))
fuzz_launch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fuzz_launch)

spec = importlib.util.spec_from_file_location("reality_diff", os.path.join(HERE, "reality-diff.py"))
reality_diff = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reality_diff)

rows = []


def row(what, got, expected):
    rows.append((what, got, expected))


# MARK: parity.py

def item(**fields):
    return {"id": "T01", "status": "shipped", **fields}


def level(entry, passed=(), failed=(), steps=None, runnable=()):
    return parity.level_of(entry, set(passed), set(failed), steps or {}, set(runnable))[0]


LINUX, MAC = "x86_64-unknown-linux-gnu", "arm64e-apple-macos14.0"


def record(fates, target=LINUX, suite="T.S", folder="/w"):
    """The lines Swift Testing writes about one run: {test: "passes", "fails", "known", "crashes" or "skipped: reason"}."""
    def line(about, **payload):
        return json.dumps({"kind": about, "payload": payload, "version": 0}, ensure_ascii=False)

    def said(symbol, text):
        return [{"symbol": symbol, "text": text}]

    def event(kind, test=None, messages=(), **more):
        return line("event", kind=kind, messages=list(messages), **({"testID": identity(test)} if test else {}), **more)

    def identity(test):
        return f"{suite}/{test if '(' in test else test + '()'}/T.swift:3:2"

    place = {"_filePath": f"{folder}/Tests/T/T.swift", "fileID": "T/T.swift", "line": 3, "column": 2}
    lines = [line("test", kind="suite", id=suite, name="S", sourceLocation=place)]
    lines += [line("test", kind="function", id=identity(test), name=identity(test).split("/")[1], isParameterized="(" in test,
                   sourceLocation=place) for test in fates]
    lines.append(event("runStarted", messages=said("default", "Test run started.") + said("details", f"Target Platform: {target}")))
    lines.append(event("testStarted", messages=said("default", "Suite S started."), testID=suite))
    for test, fate in fates.items():
        if fate.startswith("skipped"):
            reason = fate[len("skipped: "):]
            lines.append(event("testSkipped", test, said("skip", f"Test {test}() skipped" + (f': "{reason}"' if reason else ".")),
                               _comments=[reason] if reason else []))
            continue
        lines.append(event("testStarted", test))
        if fate == "crashes":
            return lines
        if fate != "passes":
            lines.append(event("issueRecorded", test, said("fail", "Expectation failed: 1 == 2") + said("details", "1 → 1"),
                               issue={"isKnown": fate == "known", "sourceLocation": place}))
        lines.append(event("testEnded", test))
    lines.append(event("testEnded", messages=said("pass", "Suite S passed after 0.1 seconds."), testID=suite))
    outcome = "failed" if "fails" in fates.values() else "passed"
    lines.append(event("runEnded", messages=said(outcome[:4], f"Test run with {len(fates)} tests in 1 suite {outcome} after 0.1 seconds.")))
    return lines


@contextlib.contextmanager
def saved(records):
    """Each list of lines as a file."""
    with tempfile.TemporaryDirectory() as folder:
        paths = [os.path.join(folder, f"part-{index}.jsonl") for index in range(len(records))]
        for path, lines in zip(paths, records):
            with open(path, "w", encoding="utf-8") as handle:
                handle.write("".join(line + "\n" for line in lines))
        yield paths


def read(*records):
    """What parity.py makes of them: what became of each test, and how many reasons it has to believe none of it."""
    with saved(records) as paths:
        outcomes, problems, _, _ = parity.read_reports(paths)
    return outcomes, len(problems)


def score(*records):
    """parity.py from end to end, on a parity.json of one item that lists the tests `a` and `mac`: its exit code, and its complaints."""
    features = [item(area="x", title="t", tests=["a", "mac"])]
    kept = parity.PARITY, parity.FEATURES, parity.REFERENCE_IDS, sys.argv
    output = io.StringIO()
    with saved(records) as paths, tempfile.TemporaryDirectory() as folder:
        parity.PARITY, parity.FEATURES, parity.REFERENCE_IDS = os.path.join(folder, "parity.json"), os.path.join(folder, "F.md"), {"T01"}
        with open(parity.PARITY, "w", encoding="utf-8") as handle:
            json.dump({"features": features}, handle)
        sys.argv = ["parity.py", "--report", *paths]
        try:
            with contextlib.redirect_stdout(output):
                parity.main()
        except SystemExit as stop:
            code = stop.code
        finally:
            parity.PARITY, parity.FEATURES, parity.REFERENCE_IDS, sys.argv = kept
    said = [line for line in output.getvalue().split("\n") if line.startswith(("BROKEN", "THE TESTS"))]
    return code, " / ".join(line.split(": ", 1)[1].replace(os.path.dirname(paths[0]) + os.sep, "") for line in said)


def check_parity():
    row("a listed test passes", level(item(tests=["a"]), passed=["a"]), "tested")
    row("a listed test was renamed", level(item(tests=["a"]), passed=["b"]), "broken")
    row("a listed test fails", level(item(tests=["a"]), failed=["a"]), "broken")
    row("a partial item lists a test that is gone", level(item(status="partial", tests=["a"])), "broken")
    row("a partial item whose test passes stays partial", level(item(status="partial", tests=["a"]), passed=["a"]), "partial")
    row("nothing is listed", level(item()), "unproven")
    row("a step passed", level(item(e2e=["s"]), steps={"s": True}, runnable=["s"]), "verified")
    row("a step failed", level(item(e2e=["s"]), steps={"s": False}, runnable=["s"]), "broken")
    row("a step no runner has (a typo, a rename)", level(item(tests=["a"], e2e=["s"]), passed=["a"]), "broken")
    row("only a step, and it has not run yet", level(item(e2e=["s"]), runnable=["s"]), "unproven")
    row("a test, and a step that has not run yet", level(item(tests=["a"], e2e=["s"]), passed=["a"], runnable=["s"]), "tested")
    row("one of two steps has run", level(item(e2e=["s", "t"]), steps={"s": True}, runnable=["s", "t"]), "tested")

    def problems(features, reference=("T01",), specs=("F01-x.md",)):
        return len(parity.problems_in({"features": features}, set(reference), list(specs)))

    row("a sound file", problems([item(spec="F01")]), 0)
    row("a misspelt status", problems([item(status="shiped")]), 1)
    row("a spec that does not exist", problems([item(spec="F99")]), 1)
    row("an id the reference does not have", problems([item(), item(id="T99")]), 1)
    row("a reference item without an entry", problems([item()], reference=("T01", "T02")), 1)
    row("an id listed twice", problems([item(), item()]), 1)
    row("Arbor-only ids need no reference", problems([item(), item(id="A01")]), 0)

    carbon = "skipped: Carbon exists only on macOS"
    row("a run that finished", read(record({"a": "passes", "b(x:)": "passes"})), ({"a": "passed", "b": "passed"}, 0))
    row("a test that fails", read(record({"a": "fails", "b": "passes"})), ({"a": "failed", "b": "passed"}, 0))
    row("a test with a known issue proves nothing", read(record({"a": "known"})), ({"a": "has a known issue"}, 0))
    row("a run cut off by a crash",
        read(record({"a": "passes", "b": "crashes", "c": "passes"})), ({"a": "passed", "b": "did not finish", "c": "did not run"}, 1))
    row("the second of two runs cut off", read(record({"a": "passes"}) + record({"b": "crashes"}, suite="U.S"))[1], 1)
    row("a macOS-only test in a record from Linux counts", read(record({"mac": carbon})), ({"mac": "was left to macOS"}, 0))
    row("the same test skipped on a Mac does not",
        read(record({"mac": carbon}, MAC)), ({"mac": "was skipped: Carbon exists only on macOS"}, 0))
    row("a test skipped for another reason does not", read(record({"a": "skipped: later"})), ({"a": "was skipped: later"}, 0))
    row("nor one skipped without a reason", read(record({"a": "skipped"})), ({"a": "was skipped"}, 0))
    row("the reason is found where only the message for people has it",
        read([line.replace('"_comments"', '"_other"') for line in record({"mac": carbon})]), ({"mac": "was left to macOS"}, 0))
    row("of two tests of one name, in two suites, the one that fails counts",
        read(record({"a": "passes"}) + record({"a": "fails"}, suite="U.S")), ({"a": "failed"}, 0))
    row("and so does the one that was skipped",
        read(record({"a": "skipped: later"}) + record({"a": "passes"}, suite="U.S")), ({"a": "was skipped: later"}, 0))
    row("a test shown under a name that speaks of macOS, skipped for another reason, does not count",
        read([line.replace("Test a() skipped", 'Test \\"menus, only on macOS\\" skipped').replace('"_comments"', '"_other"')
              for line in record({"a": "skipped: flaky"})]), ({"a": 'was skipped: "flaky"'}, 0))
    row("a name between backticks may hold brackets", read(record({"`a (b) c`()": "passes"})), ({"a (b) c": "passed"}, 0))
    thrown = [line for line in record({"a": "fails", "b": "passes"}) if "T.S/a()" not in line or "testStarted" not in line and "testEnded" not in line]
    row("a test whose trait throws fails without having started or ended", read(thrown), ({"a": "failed", "b": "passed"}, 0))
    row("a suite run in two parts", read(record({"a": "passes"}), record({"b": "passes"}, suite="U.S")), ({"a": "passed", "b": "passed"}, 0))
    row("one of the parts did not finish", read(record({"a": "passes"}), record({"b": "crashes"}, suite="U.S"))[1], 1)
    row("one of the parts is not there", parity.read_reports(["/no/such/file"])[:2], ({}, ["/no/such/file: No such file or directory (`make test` writes it)"]))
    row("an empty record", read([]), ({}, 1))
    row("a record in a format of later years", read([line.replace('"version": 0', '"version": "9.0"') for line in record({"a": "passes"})])[0], {})

    # The file is not what `swift test` prints, and nothing is known to damage it. If something does, that is said, and nothing is green.
    sound, bad = record({"a": "passes", "mac": carbon}), record({"a": "passes", "b": "fails"})
    row("a line torn in the middle", read(sound[:4] + [sound[4][:40]] + sound[5:])[1], 1)
    row("two lines run together", read(sound[:4] + [sound[4] + sound[5]] + sound[6:])[1], 1)
    row("the line that says a test ended is lost", read(sound[:6] + sound[7:]), ({"a": "did not finish", "mac": "was left to macOS"}, 1))
    row("a line of something else", read(sound[:4] + ["◇ Test a() started."] + sound[4:])[1], 1)

    nobodys = json.loads(next(line for line in bad if "issueRecorded" in line))
    del nobodys["payload"]["testID"]
    row("something goes wrong outside any test", read(sound[:-1] + [json.dumps(nobodys)] + sound[-1:]), (read(sound)[0], 1))

    def green(outcomes, problems):
        return not problems and set(outcomes.values()) <= {"passed", "was left to macOS"}

    row("the control: a sound record is green, one with a failure is not", (green(*read(sound)), green(*read(bad))), (True, False))
    row("whichever line of a record with a failure is lost, it does not turn green",
        [index for index in range(len(bad)) if green(*read(bad[:index] + bad[index + 1:]))], [])
    row("nor whichever line is torn",
        [index for index in range(len(bad)) if green(*read(bad[:index] + [bad[index][:len(bad[index]) // 2]] + bad[index + 1:]))], [])
    row("whichever line of a sound record is lost or torn, both tests are there and well, or it is not green",
        [index for index in range(len(sound)) for part in ([], [sound[index][:30]])
         if green(*read(sound[:index] + part + sound[index + 1:])) and set(read(sound[:index] + part + sound[index + 1:])[0]) != {"a", "mac"}], [])

    row("parity.py: the listed tests ran and passed", score(sound), (0, ""))
    row("parity.py: in two parts", score(record({"a": "passes"}), record({"mac": carbon}, suite="U.S")), (0, ""))
    row("parity.py: a listed test was deleted", score(record({"mac": carbon})), (1, "test a not found"))
    row("parity.py: a listed test was renamed", score(record({"a2": "passes", "mac": carbon})), (1, "test a not found"))
    row("parity.py: a macOS-only test was deleted", score(record({"a": "passes"})), (1, "test mac not found"))
    row("parity.py: a part was left out, so a listed test did not run", score(record({"mac": carbon}, suite="U.S")), (1, "test a not found"))
    row("parity.py: a listed test failed", score(record({"a": "fails", "mac": carbon})), (1, "test a failed / failed: a"))
    row("parity.py: a test failed and the run crashed: both are said", score(record({"a": "fails", "mac": carbon, "b": "crashes"})),
        (1, "test a failed / part-0.jsonl: 1 of 1 test runs did not finish (a crash?); failed: a"))
    row("parity.py: another test failed", score(record({"a": "passes", "mac": carbon, "b": "fails"})), (1, "failed: b"))
    row("parity.py: a listed test was skipped", score(record({"a": "skipped: later", "mac": carbon})), (1, "test a was skipped: later"))
    row("parity.py: a listed test has a known issue", score(record({"a": "known", "mac": carbon})), (1, "test a has a known issue"))
    row("parity.py: a macOS-only test skipped on a Mac",
        score(record({"a": "passes", "mac": carbon}, MAC)), (1, "test mac was skipped: Carbon exists only on macOS"))
    row("parity.py: the run crashed after the listed tests",
        score(record({"a": "passes", "mac": carbon, "b": "crashes"})), (1, "part-0.jsonl: 1 of 1 test runs did not finish (a crash?)"))
    row("parity.py: a torn line", score(sound[:-1] + [sound[-1][:50]])[0], 1)
    row("parity.py: a torn line is called that",
        score(sound[:6] + [sound[6][:50]] + sound[7:]),
        (1, "test a did not finish / part-0.jsonl: line 7 is damaged; "
            "part-0.jsonl: the runs finished, yet nothing says how 1 of the tests ended: lines are missing"))
    row("parity.py: nothing ran", score([])[0] not in (0, None), True)

    evidence = "\n".join([
        "# header", "▸ good  (dock 1 left)", "  ✔ a", "  ✔ b", "▸ bad", "  ✔ a", "  ✘ b", "▸ again", "  ✔ a",
        "== a heading", "  ✘ preparation that belongs to no step", "▸ again", "  ✔ b", "▸ died here",
    ])
    with tempfile.NamedTemporaryFile("w", suffix=".txt", encoding="utf-8", delete=False) as handle:
        handle.write(evidence)
    steps, header = parity.parse_evidence(handle.name)
    os.unlink(handle.name)
    row("evidence: a ✘ fails its step, a step with nothing under it did not run, a heading ends a step",
        steps, {"good": True, "bad": False, "again": True})
    row("evidence: the header", header, "header")
    row("the runners' steps are found", {"go back", "quit Arbor", "a URL runs a command"} <= parity.known_steps(), True)


# MARK: ci-step.py

def check_ci_step():
    def step(*command):
        result = subprocess.run([sys.executable, os.path.join(HERE, "ci-step.py"), "name", *command],
                                capture_output=True, text=True, check=False)
        return result.returncode, "::error" in result.stdout

    row("ci-step: a command that passes", step("true"), (0, False))
    row("ci-step: a command that fails", step("sh", "-c", "exit 3"), (3, True))
    row("ci-step: a command that crashes", step("sh", "-c", "kill -SEGV $$"), (139, True))
    row("ci-step: a command that does not exist", step("no-such-command-anywhere"), (127, True))

    def told(lines, *command):
        """The annotations of a step whose command leaves that record (or none) behind and prints next to nothing."""
        with tempfile.TemporaryDirectory() as folder:
            folder = os.path.realpath(folder)
            if lines is not None:
                with open(os.path.join(folder, "report.jsonl"), "w", encoding="utf-8") as handle:
                    handle.write("".join(line.replace("/w/", folder + "/") + "\n" for line in lines))
            result = subprocess.run([sys.executable, os.path.join(HERE, "ci-step.py"), "--report", "report.jsonl", "test", *command],
                                    capture_output=True, text=True, check=False, cwd=folder)
        return [line for line in result.stdout.split("\n") if line.startswith("::")]

    row("ci-step: what failed comes from the tests' record, with its place, though the output lost it",
        told(record({"a": "passes", "b": "fails"}), "sh", "-c", "exit 1")[0],
        "::error title=test,file=Tests/T/T.swift,line=3,col=2::Test b: Expectation failed: 1 == 2%0A1 → 1")
    row("ci-step: a crash: the tests that were under way",
        told(record({"a": "passes", "b": "crashes"}), "sh", "-c", "exit 1")[0],
        "::error title=test::under way when the run ended (a crash?): b")
    row("ci-step: a crash's last words, which only the output has, come first; what it printed of the tests is left to the record",
        told(record({"a": "fails", "b": "crashes"}), "sh", "-c", "echo 'T/T.swift:9: Fatal error: boom'; echo '✘ Test a() failed'; exit 1")[:3],
        ["::error title=test::T/T.swift:9: Fatal error: boom", "::error title=test::under way when the run ended (a crash?): b",
         "::error title=test,file=Tests/T/T.swift,line=3,col=2::Test a: Expectation failed: 1 == 2%0A1 → 1"])
    many = record({"a": "fails", "b": "fails"})
    issue = next(index for index, line in enumerate(many) if "issueRecorded" in line)
    row("ci-step: a test with twenty issues takes one place, so the next test is told too",
        [line.split("::")[2][:7] for line in told(many[:issue] + [many[issue]] * 20 + many[issue + 1:], "sh", "-c", "exit 1")[:2]],
        ["Test a:", "Test b:"])
    row("ci-step: tests built under another path: the place is in the words",
        told([line.replace("/w/", "/elsewhere/") for line in record({"b": "fails"})], "sh", "-c", "exit 1")[0],
        "::error title=test::Test b: Expectation failed: 1 == 2%0A1 → 1%0A(at T/T.swift:3)")
    row("ci-step: no record, because the build failed: the compiler's errors from the output",
        told(None, "sh", "-c", "echo 'error: no such module'; exit 1")[0], "::error title=test::error: no such module")
    row("ci-step: the tests passed: how many, and which did not run",
        told(record({"a": "passes", "mac": "skipped: Carbon exists only on macOS", "mac2": "skipped: AppKit exists only on macOS"}), "true"),
        ["::notice title=test::tests: 3, passed: 1, skipped: 2, test runs: 1", "::notice title=test::was left to macOS: mac, mac2"])


# MARK: scenarios.sh and arbor-sim

# One line in which a window goes somewhere and on from there.
TWICE = "shove 101 10 40 then 500 40\n"
SCENARIOS = [
    (0, "a scenario that holds", "open A\ndock 101 left\nexpect docked 101\n"),
    (1, "an expectation that does not hold", "open A\nexpect docked 101\n"),
    (1, "a misspelt command, and expectations that hold anyway", "open A\ndok 101 left\nexpect floating 101\n"),
    (1, "a command that fails, and nothing says it should", "open A\ndock 999 left\nexpect floating 101\n"),
    (0, "a command that fails as expected", "open A\ndock 999 left\nexpect fail\nexpect floating 101\n"),
    (1, "a failure as the last line", "open A\nexpect floating 101\ndock 999 left\n"),
    (1, "no expectations at all", "open A\ndock 101 left\n"),
    (1, "`Expect` is not `expect`", "open A\nExpect floating 101\n"),
    (1, "an expectation nobody knows", "open A\nexpect dcked 101\n"),
    (1, "a number the simulator refuses", "open A\nexpect floating 101\nseam 1e300 5\n"),
    (0, "a window that is moved once", "open A\nshove 101 10 40\nexpect moved-once\n"),
    (1, "a window that is moved twice in one line, and nothing answers for it", "open A\n" + TWICE + "expect floating 101\n"),
    (0, "a window that is moved twice, which is known", "open A\n" + TWICE + "expect jolt 101\n"),
    (1, "a window that is moved twice in the last line", "open A\nexpect floating 101\n" + TWICE),
    (1, "a known fault that has been mended", "open A\nshove 101 10 40\nexpect jolt 101\n"),
    (1, "another window answers for it", "open A\nopen B\n" + TWICE + "expect jolt 102\n"),
]


def check_scenarios():
    if not os.access(os.path.join(ROOT, ".build", "debug", "arbor-sim"), os.X_OK):
        print("SKIPPED the scenario rows: no .build/debug/arbor-sim; run swift build first")
        return
    for expected, what, text in SCENARIOS:
        with tempfile.TemporaryDirectory() as folder:
            with open(os.path.join(folder, "x.sim"), "w", encoding="utf-8") as handle:
                handle.write(text)
            result = subprocess.run(["bash", os.path.join(HERE, "scenarios.sh")], capture_output=True, check=False,
                                    env={**os.environ, "ARBOR_SCENARIOS": folder})
        row(f"scenario: {what}", result.returncode, expected)
    with tempfile.TemporaryDirectory() as folder:
        result = subprocess.run(["bash", os.path.join(HERE, "scenarios.sh")], capture_output=True, check=False,
                                env={**os.environ, "ARBOR_SCENARIOS": folder})
    row("scenario: an empty folder", result.returncode, 1)


# MARK: lint-imports.py

def check_lint():
    def modules(text):
        return [problem.rsplit("`import ", 1)[1].rstrip("`") for problem in lint.problems_in(text, "x.swift")]

    row("lint: Foundation through Linux's stand-in for CoreGraphics", modules("import CoreGraphics\nlet started = Date()\n"), ["Foundation"])
    row("lint: geometry through Foundation", modules("import Foundation\nlet x = window.frame.minX\n"), ["CoreGraphics"])
    row("lint: both at once", modules("let r = CGRect.zero\nlet d = Data()\n"), ["Foundation", "CoreGraphics"])
    row("lint: both imported", modules("import CoreGraphics\nimport Foundation\nlet r = CGRect.zero\nlet d = Data()\n"), [])
    row("lint: AppKit brings both", modules("import AppKit\nlet r = CGRect.zero\nlet d = Data()\n"), [])
    row("lint: comments and strings do not count", modules('// a Date, a CGRect\nlet text = "URL and CGSize"\n/* Data */ let n = 1\n'), [])
    row("lint: an import in a comment does not count", modules("// import Foundation\nlet d = Data()\n"), ["Foundation"])


# MARK: mutate.py

def check_mutate():
    source = "\n".join([
        "import Foundation", "// a < b in a comment", 'let text = "a < b"', "if a < b && !done {", "  save()", "}",
        "let n = 12", "guard ready else { return }", "guard let x = y else { return }",
    ])
    with tempfile.NamedTemporaryFile("w", suffix=".swift", encoding="utf-8", delete=False) as handle:
        handle.write(source)
    _, found = mutate.mutants_of(handle.name)
    os.unlink(handle.name)
    row("mutate: what it changes, and that comments, strings and bindings are left alone",
        sorted((number, name) for number, name, _ in found),
        [(4, "&& to ||"), (4, "<  to <="), (4, "drop !"), (5, "drop line"), (7, "number"), (8, "drop line")])
    import random
    many = [(line, "x", str(line)) for line in range(1, 40)]
    picked = mutate.sample(many, 30, random.Random(1))
    row("mutate: a sample has the size asked for and no mutant twice", (len(picked), len(set(picked))), (30, 30))
    mutate.TIMEOUT = 1
    code, _ = mutate.run(["sh", "-c", "sh -c 'exec sleep 31.4159' & wait"], ROOT)
    left = subprocess.run(["pgrep", "-f", "sleep 31.4159"], capture_output=True, check=False).returncode == 0
    row("mutate: a run that hangs is ended, grandchildren and all", (code, left), (124, False))
    row("mutate: a build gets a limit of its own", mutate.run(["sleep", "1.5"], ROOT, 10)[0], 0)
    real, asked = mutate.run, []
    mutate.run = lambda command, cwd, limit=None: (asked.append((command[1], limit)), (124, "timed out"))[1]
    row("mutate: a build that does not end in time is not called uncompilable", (mutate.judge(ROOT), asked),
        (("timed out", "the build"), [("build", mutate.BUILD_TIMEOUT)]))
    mutate.run = real
    mutate.TIMEOUT = 120
    row("mutate: on a busy machine the tests get longer, on a quick one no less", (mutate.patience(100), mutate.patience(9)), (500, 120))


# MARK: lint-mac-shell.py

def check_mac_shell_lint():
    def found(text, shared=()):
        return len(mac_lint.problems(text, shared))

    row("mac-shell lint: its own examples", mac_lint.self_test(quiet=True), 0)
    # A runner of GitHub's that a person sets up on their own Mac sets GITHUB_ACTIONS too, and arbor-e2e took that for a Mac that nobody owns.
    row("mac-shell lint: GITHUB_ACTIONS alone opens a gate, in shell, Swift and Objective-C",
        [mac_lint.one_lock(text) for text in (
            'if [ ! -t 0 ] && [ "${GITHUB_ACTIONS:-}" != true ]; then exit 77; fi\n',
            'private let runner: Runner\nlet alone = environment["GITHUB_ACTIONS"] != "true" && isatty(0) == 0\ninit(_ runner: Runner) {\n  self.runner = runner\n}\n',
            'const char *value = getenv("GITHUB_ACTIONS");\nreturn value && strcmp(value, "true") == 0;\n')], [[1], [2], [1]])
    row("mac-shell lint: however it is read",
        [mac_lint.one_lock(text) for text in (
            'if [ -n "$GITHUB_ACTIONS" ]; then macos_tiling off; fi\n', 'case "${GITHUB_ACTIONS:-}" in true) nobodys=yes ;; esac\n', "[ \"$GITHUB_ACTIONS\" = 'true' ] && x\n",
            'if [ true = "$GITHUB_ACTIONS" ]; then x; fi\n', 'let alone = environment["GITHUB_ACTIONS"] != nil\n',
            'let value = environment["GITHUB_ACTIONS"]\nlet alone = value == "true"\n', 'if os.environ.get("GITHUB_ACTIONS"):\n')], [[1]] * 7)
    row("mac-shell lint: lib.sh takes it away from where it is sourced, not before",
        mac_lint.one_lock('if [ "${GITHUB_ACTIONS:-}" = true ]; then macos_tiling off; fi\nsource "$(dirname "$0")/lib.sh"\n'), [1])
    row("mac-shell lint: with the account beside it, it may",
        [mac_lint.one_lock(text) for text in (
            'if [ "${GITHUB_ACTIONS:-}" = true ] && [ "$(id -un)" = runner ]; then nobodys=yes; fi\n',
            'on_throwaway_mac() { [ "${GITHUB_ACTIONS:-}" = true ]; }\n# why\n# why\nif on_throwaway_mac && [ "$(id -un)" != runner ]; then\n  unset GITHUB_ACTIONS\nfi\n',
            'static let throwaway = environment["GITHUB_ACTIONS"] == "true" && NSUserName() == "runner"\n',
            'const char *value = getenv("GITHUB_ACTIONS");\nreturn value && strcmp(value, "true") == 0 && [NSUserName() isEqualToString:@"runner"];\n')], [[], [], [], []])
    row("mac-shell lint: nor is it about a comment, taking the variable away, or a script under lib.sh, which has taken it away",
        [mac_lint.one_lock(text) for text in (
            '# [ "${GITHUB_ACTIONS:-}" = true ] would do\n', 'env -u GITHUB_ACTIONS bash x.sh\nunset GITHUB_ACTIONS\nunset A GITHUB_ACTIONS B\nexport GITHUB_ACTIONS=true\nGITHUB_ACTIONS=true ./x.sh\n',
            '  echo "GITHUB_ACTIONS is true, but the Mac is somebody\'s"\n', 'if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::notice::x"; fi  # safe anywhere: only how a line is printed\n',
            'source "$(dirname "$0")/lib.sh"\nif [ "${GITHUB_ACTIONS:-}" = true ]; then macos_tiling off; fi\n')], [[], [], [], [], []])
    # The fault of 2026-10-14 08:20 UTC: a full disk, an empty variable, and the clean-up takes the checkout or every process.
    row("mac-shell lint: mktemp unchecked", found('dir=$(mktemp -d /tmp/arbor-x.XXXXXX)\n'), 1)
    row("mac-shell lint: mktemp checked", found('dir=$(mktemp -d /tmp/arbor-x.XXXXXX) || die "no folder"\n'), 0)
    row("mac-shell lint: rm -rf of a variable nobody checked", found('rm -rf "$dir"\n'), 1)
    row("mac-shell lint: of one whose mktemp was checked", found('dir=$(mktemp -d) || exit 2\nrm -rf "$dir"\n'), 0)
    row("mac-shell lint: unless it starts out empty, for a trap may run before the folder is made",
        found('dir=""\ntrap \'rm -rf "$dir"; arbor_exit\' EXIT\ndir=$(mktemp -d) || exit 2\n'), 1)
    row("mac-shell lint: local hides what mktemp said", found('f() {\n  local dir=$(mktemp -d) || return 1\n}\n'), 1)
    row("mac-shell lint: tested on the line", found('[ -n "$dir" ] && rm -rf "$dir"\n'), 0)
    row("mac-shell lint: rm -rf of what scratch_dir made", found('scratch_dir f13 dir\nrm -rf "$dir"\n'), 0)
    row("mac-shell lint: and of what is built from it", found('scratch_dir f13\napp="$SCRATCH_DIR/Arbor.app"\nrm -rf "$app"\n'), 0)
    row("mac-shell lint: unless it is also set to something else", found('scratch_dir f13 dir\ndir=$1\nrm -rf "$dir"\n'), 1)
    row("mac-shell lint: ${dir:?} ends the script when it is empty", found('rm -rf "${dir:?}"\n'), 0)
    row("mac-shell lint: not quoted", found('scratch_dir f13 dir\nrm -rf $dir\n'), 1)
    row("mac-shell lint: a library's scratch_dir counts in the script", found('rm -rf "$APPS_TEMP"\n', {"APPS_TEMP"}), 0)
    row("mac-shell lint: everything inside an unchecked folder", found('rm -f "$dir"/*\n'), 1)
    row("mac-shell lint: one file is no danger", found('rm -f "$dir/log.txt"\n'), 0)
    row("mac-shell lint: cd into an unchecked variable", found('cd "$dir" || exit 2\n'), 1)
    row("mac-shell lint: cd beside the script", found('cd "$(dirname "$0")/../.." || exit 2\n'), 0)
    row("mac-shell lint: find -delete below an unchecked variable", found('find "$dir" -name "*.log" -delete\n'), 1)
    row("mac-shell lint: find that only looks", found('find "$dir" -name "*.log"\n'), 0)
    row("mac-shell lint: mv of an unchecked variable", found('mv "$old" "$ARBOR_OUT/"\n'), 1)
    row("mac-shell lint: cp -R over an unchecked variable", found('cp -R build/Arbor.app "$target"\n'), 1)
    row("mac-shell lint: pgrep -f with a pattern that may be ^/", found('count=$(pgrep -f "^$root/" | wc -l)\n'), 1)
    row("mac-shell lint: pgrep -f with a proven one", found('count=$(pgrep -f "^$ARBOR_SESSION_DIR/" | wc -l)\n'), 0)
    row("mac-shell lint: kill what a search found", found('kill $(pgrep -x Arbor)\n'), 1)
    row("mac-shell lint: kill a pid that was looked up", found('pid=$(pgrep -x Safari | head -n 1)\nkill "$pid"\n'), 1)
    row("mac-shell lint: kill a pid the script started", found('sleep 5 &\npid=$!\nkill "$pid"\n'), 0)
    row("mac-shell lint: a pid looked up in another function", found('f() {\n  local pid\n  pid=$(pgrep -x Dock)\n}\ng() {\n  kill "$pid"\n}\n'), 0)
    row("mac-shell lint: kill a process group", found('kill -TERM -- "-$group"\n'), 1)
    row("mac-shell lint: kill 0", found('kill 0\n'), 1)
    row("mac-shell lint: a bare wait", found('sleep 5 &\nwait\n'), 1)
    row("mac-shell lint: wait for one process", found('sleep 5 &\nwait $!\n'), 0)
    row("mac-shell lint: a trap that replaces the clean-up", found("trap 'rm -f \"$ARBOR_OUT/x\"' EXIT\n"), 1)
    row("mac-shell lint: a trap that goes on to it", found("trap 'code=$?; echo bye; (exit \"$code\"); arbor_exit' EXIT\n"), 0)
    row("mac-shell lint: scratch_dir in a subshell", found('dir=$(scratch_dir f13)\n'), 1)
    row("mac-shell lint: the pointer tool past the nets", found('"$ARBOR_POINTER" click 500 400\n'), 1)
    row("mac-shell lint: the pointer tool asked a question", found('"$ARBOR_POINTER" where\n'), 0)
    row("mac-shell lint: an Arbor over everybody's windows", found('env ARBOR_NO_WATCHDOG=1 "$ARBOR_BIN/Arbor" &\n'), 1)
    row("mac-shell lint: over several lines", found('env ARBOR_NO_WATCHDOG=1 \\\n  "$ARBOR_BIN/Arbor" > /dev/null &\n'), 1)
    row("mac-shell lint: an Arbor limited to test windows", found('env ARBOR_ONLY_PIDS="$pid" ARBOR_NO_WATCHDOG=1 \\\n  "$ARBOR_BIN/Arbor" &\n'), 0)
    row("mac-shell lint: with a watchdog that starts it again", found('env ARBOR_ONLY_PIDS="$pid" "$ARBOR_BIN/Arbor" &\n'), 1)
    row("mac-shell lint: a path that only ends like Arbor's", found('cp "$ARBOR_BIN/Arbor" "$ARBOR_SESSION_DIR/Arbor"\n'), 0)
    row("mac-shell lint: the session's folder taken away", found('unset ARBOR_HOME\n'), 1)
    row("mac-shell lint: without ARBOR_SOCKET the socket is the one in the session's folder", found('unset ARBOR_SOCKET\n'), 0)
    row("mac-shell lint: $HOME moved", found('export HOME=$sandbox/home\n'), 1)
    row("mac-shell lint: a process with event taps stopped", found('kill -STOP "$ARBOR_PID"\n'), 1)
    row("mac-shell lint: on a throwaway Mac all of it may be", found('source lib.sh\nneeds_throwaway_mac "x"\ndir=$(mktemp -d)\nrm -rf "$dir"\nwait\n'), 0)
    row("mac-shell lint: a waiver for what is in a variable", found('rm -rf "$dir" # never empty: the line above has compared it with /tmp/arbor-x.??????\n'), 0)
    row("mac-shell lint: which the waiver for what a line does is not", found('rm -rf "$dir" # safe anywhere: it is only a build folder\n'), 1)
    row("mac-shell lint: a waiver for what a line does", found('wait # safe anywhere: the one child ends by itself\n'), 0)
    row("mac-shell lint: perl is not shell", found("perl -e '\n  kill \"TERM\", -$pid;\n' \"$1\"\n"), 0)
    # What a run prints gets pasted into pull requests, and what it wrote is the person's to send.
    row("mac-shell lint: who the person is", found('echo "user $(whoami) on $(hostname)"\n'), 1)
    row("mac-shell lint: which app they have in front", found('lsappinfo info -only name "$(lsappinfo front)"\n'), 1)
    row("mac-shell lint: every window on their screen, by app", found('"$ARBOR_POINTER" windows --on-screen\n'), 1)
    row("mac-shell lint: through lib.sh, which names only the run's own", found('pointer windows --on-screen\n'), 0)
    row("mac-shell lint: a picture past shot and look", found('screencapture -x "$ARBOR_OUT/all.png"\n'), 1)
    row("mac-shell lint: output uploaded", found('curl -F file=@"$ARBOR_OUT/output.txt" https://example.com\n'), 1)
    row("mac-shell lint: output pushed", found('git push origin HEAD:evidence\n'), 1)
    row("mac-shell lint: an Arbor that was only asked to quit is waited for", found('ctl quit\nwait "$ARBOR_PID"\n'), 1)
    row("mac-shell lint: one that was killed may be", found('kill -KILL "$ARBOR_PID"\nwait "$ARBOR_PID"\n'), 0)
    row("mac-shell lint: a trap of its own in a script without lib.sh", len(mac_lint.problems("trap 'rm -rf /tmp/arbor-x' EXIT\n", (), False)), 0)
    row("mac-shell lint: and in one with it", found("trap 'rm -rf /tmp/arbor-x' EXIT\n"), 1)
    with tempfile.TemporaryDirectory(prefix="tooling-") as root:
        os.makedirs(os.path.join(root, "scripts"))
        for name, text in {"sim-smoke.sh": "./scripts/more-smoke.sh || exit 1\n# scripts/only-mentioned.sh\n", "more-smoke.sh": "exec ./scripts/sim-smoke.sh\n",
                           "only-mentioned.sh": "", "install.sh": "", "e2e.sh": ""}.items():
            with open(os.path.join(root, "scripts", name), "w", encoding="utf-8") as handle:
                handle.write(text)
        row("mac-shell lint: what an unattended build runs on a person's Mac is read too, with what that runs",
            [os.path.basename(path) for path in mac_lint.loop_scripts(root)], ["sim-smoke.sh", "e2e.sh", "more-smoke.sh"])
    row("mac-shell lint: defining the guard is not calling it", found('needs_throwaway_mac() {\n  exit 77\n}\nkillall Dock\n'), 1)


# MARK: scripts/mac-shell/lib.sh

LIB = os.path.join(HERE, "mac-shell", "lib.sh")
SWEEP = os.path.join(HERE, "mac-shell", "sweep.sh")
BASH = os.environ.get("ARBOR_TEST_BASH", "bash")
# What a Mac would answer, from files in $FAKE. What would be posted goes to $FAKE/posted.
STAND_INS = {
    "pointer": """#!/bin/bash
case "$1" in
  where) echo "100 100 up" ;;
  windows) if [ "$2" = --pid ]; then awk -v pid="$3" '$2 == pid' "$FAKE/windows"; else cat "$FAKE/windows"; fi ;;
  status-item) case " $* " in *" --frame "*) cat "$FAKE/status-item-frame" 2>/dev/null || exit 64 ;; *) cat "$FAKE/status-item" 2>/dev/null || exit 64 ;; esac ;;
  front) cat "$FAKE/front" 2>/dev/null || exit 64 ;;
  screen-access) cat "$FAKE/screen-access" 2>/dev/null || echo true ;;
  asleep) cat "$FAKE/asleep" 2>/dev/null || echo false ;;
  displays) echo "1 0 0 1024 768 1024 768 1" ;;
  wallpaper) echo "/System/Library/Desktop Pictures/x.heic" ;;
  *) echo "$*" >> "$FAKE/posted" ;;
esac
""",
    "screencapture": '#!/bin/bash\necho "$*" | sed "s|$FAKE/||g" >> "$FAKE/pictures"\necho picture > "${!#}"\n'
                     '[ -f "$FAKE/banner" ] && cat "$FAKE/banner" "$FAKE/windows" > "$FAKE/both" && mv "$FAKE/both" "$FAKE/windows"\nexit 0\n',
    "sips": "#!/bin/bash\nexit 0\n",
    "curtain": '#!/bin/bash\necho "0 31 1024 674" > "$3"\nexec sleep 600\n',
    "id": '#!/bin/bash\nif [ "$1" = -u ]; then cat "$FAKE/uid" 2>/dev/null || echo 501; else echo "uid=501"; fi\n',
    "pgrep": '#!/bin/bash\nname=${!#}\n[ -f "$FAKE/running-$name" ] && cat "$FAKE/running-$name" || exit 1\n',
    "ioreg": '#!/bin/bash\necho "    | |   \\"HIDIdleTime\\" = $(cat "$FAKE/idle" 2>/dev/null || echo 900)000000000"\n'
             '[ -f "$FAKE/locked" ] && echo "    \\"IOConsoleUsers\\" = ({\\"CGSSessionScreenIsLocked\\"=Yes,\\"kCGSSessionOnConsoleKey\\"=Yes})"\nexit 0\n',
    "pmset": '#!/bin/bash\necho "   PreventUserIdleDisplaySleep    $(cat "$FAKE/awake" 2>/dev/null || echo 0)"\necho "Listed by owning process:"\n'
             'cat "$FAKE/awake-owners" 2>/dev/null\nexit 0\n',
    "defaults": '#!/bin/bash\n[ "$1" = read ] || exit 0\ncat "$FAKE/defaults-${2#-}" 2>/dev/null || exit 1\n',
    "security": "#!/bin/bash\necho '\"/Users/you/Library/Keychains/login.keychain-db\"'\n",
    "lsappinfo": "#!/bin/bash\nexit 0\n",
    "launchctl": "#!/bin/bash\nexit 0\n",
}
REAL_MKTEMP = shutil.which("mktemp")


class FakeMac:
    """A folder of stand-ins and answers, and a way to run a script that sources lib.sh against it."""

    def __init__(self, somebodys=True):
        self.folder = tempfile.mkdtemp(prefix="tooling-")
        os.makedirs(os.path.join(self.folder, "bin"))
        os.makedirs(os.path.join(self.folder, "out"))
        for name, text in STAND_INS.items():
            self.tool(name, text)
        kept = {key: value for key, value in os.environ.items() if not key.startswith("ARBOR_") and key != "GITHUB_ACTIONS"}
        self.environment = {
            **kept, "FAKE": self.folder, "PATH": os.path.join(self.folder, "bin") + os.pathsep + os.environ["PATH"],
            "ARBOR_REHEARSAL": "1", "ARBOR_BUILT": "1", "ARBOR_OUT": os.path.join(self.folder, "out"),
            "ARBOR_BIN": os.path.join(self.folder, "bin"), "ARBOR_POINTER": os.path.join(self.folder, "bin", "pointer"),
            # People set $CI too, so it must open nothing.
            "ARBOR_CURTAIN": os.path.join(self.folder, "bin", "curtain"), "CI": "true",
        }
        self.where = "on somebody's Mac, " if somebodys else ""
        self.started = []
        if not somebodys:
            self.environment["GITHUB_ACTIONS"] = "true"

    def tool(self, name, text):
        path = os.path.join(self.folder, "bin", name)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text)
        os.chmod(path, 0o755)

    def put(self, name, text):
        with open(os.path.join(self.folder, name), "w", encoding="utf-8") as handle:
            handle.write(f"{text}\n")

    def read(self, name):
        try:
            with open(os.path.join(self.folder, name), encoding="utf-8") as handle:
                return handle.read()
        except OSError:
            return ""

    def start(self, body, before=""):
        path = os.path.join(self.folder, "script.sh")
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(f'{before}\nsource "{LIB}"\n{body}\n')
        process = subprocess.Popen([BASH, path], env=self.environment, cwd=self.folder, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, start_new_session=True)
        self.started.append(process)
        return process

    def run(self, body, before=""):
        process = self.start(body, before)
        output, _ = process.communicate(timeout=90)
        return process.returncode, output

    def await_file(self, name):
        # A minute: before a script starts, its supervisor reads every script (the lint) and may finish a neighbour's clean-up.
        for _ in range(1200):
            if self.read(name).strip():
                return
            time.sleep(0.05)

    def running(self, name):
        return [pid for pid in self.read(name).split() if alive(pid)]

    def left(self, name):
        return [path for path in self.read(name).split() if os.path.exists(path)]

    def close(self):
        # A situation that was given up (a machine too busy) leaves its run going, for up to a quarter of an hour, in its neighbours' way.
        for process in self.started:
            if process.poll() is None:
                process.terminate()
                try:
                    process.communicate(timeout=30)
                except subprocess.TimeoutExpired:
                    process.kill()
        shutil.rmtree(self.folder, ignore_errors=True)


def alive(pid):
    """Whether the process runs. One that has ended and waits for a parent that never asks does not."""
    state = subprocess.run(["ps", "-o", "stat=", "-p", str(pid)], capture_output=True, text=True).stdout.strip()
    return bool(state) and not state.startswith("Z")


NOTES = 'echo "$$" > "$FAKE/script"; echo "$ARBOR_SUPERVISOR" > "$FAKE/supervisor"; echo "$ARBOR_LEDGER $ARBOR_SESSION_DIR" > "$FAKE/folders"\n'
HANGS = NOTES + """scratch_dir hang
echo "$SCRATCH_DIR" >> "$FAKE/folders"
at_exit 'echo orderly >> "$FAKE/said"'
sleep 400 &
started $!
echo $! > "$FAKE/children"
(sleep 401) &
echo $! >> "$FAKE/children"
limit 300 sh -c 'echo $$ >> "$FAKE/children"; exec sleep 402' &
sleep 0.5
echo ready > "$FAKE/ready"
sleep 403
echo "not reached" >> "$FAKE/said"
"""


def lib_situations(canary):
    """Functions that each try one situation and return rows (what, got, expected): those that can run side by side, and the rest."""

    def folders(mac):
        code, output = mac.run(NOTES + 'scratch_dir demo\nscratch_dir other OTHER\necho "$SCRATCH_DIR $OTHER" >> "$FAKE/folders"\n'
                               '[ -d "$SCRATCH_DIR" ] && [ -d "$OTHER" ] && bash -c \'[ -d "$OTHER" ]\' && echo "made and exported"\nexit 5')
        made = mac.read("folders").split()
        return [("lib.sh: scratch_dir makes folders under /tmp/arbor- and exports them; the script's exit code comes through",
                 (code, "made and exported" in output, all(path.startswith("/tmp/arbor-") for path in made), len(made)), (5, True, True, 4)),
                ("lib.sh: every folder of the run is gone afterwards", mac.left("folders"), [])]

    def full_disk(mac):
        mac.tool("mktemp", "#!/bin/bash\nexit 1\n")
        code, output = mac.run('echo "the script ran" > "$FAKE/said"')
        return [("lib.sh: with a full disk nothing is started", (code, mac.read("said"), "nothing was started" in output), (2, "", True))]

    def disk_fills_up(mac):
        mac.tool("mktemp", f'#!/bin/bash\ncase "$*" in *arbor-late*) exit 1 ;; esac\nexec {REAL_MKTEMP} "$@"\n')
        code, _ = mac.run('scratch_dir late LATE\necho "went on with LATE=[${LATE:-}]" > "$FAKE/said"')
        return [("lib.sh: scratch_dir ends the script rather than leave its variable empty", (code, mac.read("said")), (2, ""))]

    def strange_mktemp(mac):
        mac.tool("mktemp", f'#!/bin/bash\ncase "$*" in *arbor-odd*) echo "$FAKE"; exit 0 ;; esac\nexec {REAL_MKTEMP} "$@"\n')
        code, _ = mac.run('scratch_dir odd\necho "went on" > "$FAKE/said"')
        return [("lib.sh: scratch_dir takes nothing but /tmp/arbor-<name>.XXXXXX for an answer", (code, mac.read("said")), (2, ""))]

    def refusals(mac):
        os.makedirs(os.path.join(mac.folder, "precious"))
        link = f"/tmp/arbor-link.{os.getpid() % 1000000:06d}"
        os.symlink(mac.folder, link)
        _, output = mac.run('scratch_dir mine\nmkdir "$SCRATCH_DIR/sub"\n'
                            'scratch_remove "" / "$HOME" /tmp /tmp/arbor-x "$FAKE/precious" "$SCRATCH_DIR/../.." "$SCRATCH_DIR/../..$FAKE/precious" '
                            f'"{link}/precious"\n'
                            'scratch_remove "$SCRATCH_DIR/sub" && [ ! -e "$SCRATCH_DIR/sub" ] && echo "its own it removes"')
        os.unlink(link)
        return [("lib.sh: scratch_remove refuses the empty string, /, the home folder, .. and a link out of /tmp",
                 (output.count("scratch_remove: refused"), os.path.isdir(os.path.join(mac.folder, "precious")), "its own it removes" in output),
                 (9, True, True))]

    def strangers(mac):
        _, output = mac.run(f'started {canary}\nkill_started {canary}\nkill_started 1 0 "" abc\n'
                            'sleep 300 &\nmine=$!\nstarted $mine\nsleep 301 &\nother=$!\nstarted $other\nkill_started $mine\n'
                            'kill -0 $mine 2>/dev/null || echo "mine is gone"\nkill -0 $other 2>/dev/null && echo "the other is left"\n'
                            'kill_started $nothing_in_this\nkill -0 $other 2>/dev/null && echo "with nothing named it is left too"\n'
                            'kill_started --all\nkill -0 $other 2>/dev/null || echo "all are gone"', before="nothing_in_this=''")
        return [("lib.sh: a process that ran before the script is not put on record, and kill_started leaves it alone",
                 (alive(canary), "somebody's: not put on record" in output, output.count("left alone")), (True, True, 5)),
                ("lib.sh: kill_started <pid> stops that one process of the script's", ("mine is gone" in output, "the other is left" in output), (True, True)),
                ("lib.sh: with an empty variable for a name it stops nothing; --all stops everything on record",
                 ("with nothing named it is left too" in output, "all are gone" in output), (True, True))]

    def ended(how, where=""):
        def situation(mac):
            process = mac.start(HANGS, before="ARBOR_TIME_LIMIT=" + ("3" if how == "the time limit" else "200"))
            mac.await_file("ready")
            if how == "an interrupt":
                os.kill(int(mac.read("supervisor")), signal.SIGINT)
            elif how == "kill -9":
                os.kill(int(mac.read("script")), signal.SIGKILL)
            output, _ = process.communicate(timeout=90)
            expected = {"the time limit": (124, "orderly\n"), "an interrupt": (130, "orderly\n"), "kill -9": (137, "")}[how]
            rows = [(f"lib.sh: {where}{how}: the exit code, and whether the script's own clean-up ran", (process.returncode, mac.read("said")), expected),
                    (f"lib.sh: {where}{how}: nothing it started is left running, no folder is left", (mac.running("children"), mac.left("folders")), ([], []))]
            if where:
                rows.append((f"lib.sh: {where}{how}: what the supervisor says last still comes out", "this Mac after the run" in output or "this Mac differs" in output, True))
            return rows
        return situation

    def both_killed(mac):
        process = mac.start(HANGS)
        mac.await_file("ready")
        os.kill(int(mac.read("supervisor")), signal.SIGKILL)
        os.kill(int(mac.read("script")), signal.SIGKILL)
        # Not communicate(): what is left running holds the pipe open.
        process.wait(timeout=90)
        before = len(mac.running("children"))
        subprocess.run([BASH, SWEEP], env=mac.environment, capture_output=True, text=True, timeout=90)
        return [(f"lib.sh: {mac.where}script and supervisor both killed: the next run finishes the clean-up",
                 (before, mac.running("children"), mac.left("folders")), (3, [], []))]

    def supervisor_killed(mac):
        process = mac.start(NOTES + 'scratch_dir alone\necho "$SCRATCH_DIR" >> "$FAKE/folders"\nsleep 404 &\necho $! > "$FAKE/children"\n'
                            'at_exit \'echo orderly >> "$FAKE/said"\'\necho ready > "$FAKE/ready"\nwhile sleep 0.2; do check "it goes on" true; done')
        mac.await_file("ready")
        os.kill(int(mac.read("supervisor")), signal.SIGKILL)
        process.wait(timeout=90)
        # Its clean-up looks the processes over some thirty times, which takes a while beside seven other situations.
        for _ in range(300):
            # All three: a neighbour that starts meanwhile takes the run for one that was cut off and lends a hand, in an order of its own.
            if not alive(mac.read("script").strip()) and not mac.running("children") and not mac.left("folders"):
                break
            time.sleep(0.1)
        return [(f"lib.sh: {mac.where}the supervisor alone killed: the script ends at its next step and cleans up after itself",
                 (alive(mac.read("script").strip()), mac.read("said"), mac.running("children"), mac.left("folders")), (False, "orderly\n", [], []))]

    def two_at_once(mac):
        first = mac.start(NOTES + 'echo ready > "$FAKE/ready"\nsleep 30')
        mac.await_file("ready")
        for_real = {key: value for key, value in mac.environment.items() if key != "ARBOR_REHEARSAL"}
        second = subprocess.run([BASH, SWEEP], env=for_real, capture_output=True, text=True, timeout=90)
        os.kill(int(mac.read("supervisor")), signal.SIGINT)
        first.communicate(timeout=90)
        return [("lib.sh: a second run while one is going on is declined",
                 (second.returncode, "another Mac shell script is running" in second.stdout), (77, True))]

    def limited(mac):
        _, output = mac.run('limit 1 sh -c \'sleep 50 & echo $! > "$FAKE/children"; sleep 60\'\necho "code $?"\nlimit 5 sh -c "exit 3"\necho "code $?"')
        return [("lib.sh: limit stops a program and what it started, and hands on an exit code",
                 ([line for line in output.splitlines() if line.startswith("code")], mac.running("children")), (["code 124", "code 3"], []))]

    def declined(what, **answers):
        def situation(mac):
            for name, text in answers.items():
                mac.put(name.replace("__", "-"), text)
            code, _ = mac.run('arbor_build\narbor_start 2\necho "went on" > "$FAKE/said"')
            return [(f"lib.sh: on somebody's Mac, {what}", (code, mac.read("said"), mac.read("posted")), (77, "", ""))]
        return situation

    def quiet_since(mac):
        # The stand-in's answer stands still while the run gets going, which takes seconds beside seven others.
        mac.put("idle", "90")
        went = 'arbor_build\necho "went on" >> "$FAKE/said"'
        mac.environment["ARBOR_QUIET_SINCE"] = str(int(time.time()) - 15)
        quiet, _ = mac.run(went)
        mac.environment["ARBOR_QUIET_SINCE"] = str(int(time.time()) - 250)
        touched, _ = mac.run(went)
        mac.environment["ARBOR_QUIET_SINCE"] = "soon"
        nonsense, _ = mac.run(went)
        return [("lib.sh: in a list, no input since the script before ended is as good as five quiet minutes; input since then is somebody's",
                 (quiet, touched, nonsense, mac.read("said")), (0, 77, 77, "went on\n"))]

    def keeps_awake(mac):
        went = 'arbor_build\necho "went on" >> "$FAKE/said"'
        line = '   pid {}({}): [0x0005f5a300018a5b] 00:00:04 PreventUserIdleDisplaySleep named: "{}"'
        mac.environment["ARBOR_KEEPS_AWAKE"] = "4711"
        mac.put("awake", "1")
        mac.put("awake-owners", line.format(4711, "caffeinate", "caffeinate command-line tool"))
        ours, _ = mac.run(went)
        mac.put("awake", "2")
        mac.put("awake-owners", line.format(4711, "caffeinate", "caffeinate command-line tool") + "\n" + line.format(500, "zoom.us", "a call"))
        both, _ = mac.run(went)
        mac.put("awake", "1")
        mac.put("awake-owners", line.format(4711, "zoom.us", "a call"))
        posing, _ = mac.run(went)
        mac.put("awake-owners", "   something macOS has never printed yet")
        unknown, _ = mac.run(went)
        return [("lib.sh: the list's own caffeinate is no call; a call beside it, a call under its number and a listing nobody can read are",
                 (ours, both, posing, unknown, mac.read("said")), (0, 77, 77, 77, "went on\n"))]

    def no_curtain(mac):
        mac.tool("curtain", "#!/bin/bash\nexit 1\n")
        return declined("not without a curtain")(mac)

    def nets(mac):
        mac.put("status-item", "900 12")
        mac.put("status-item-frame", "828.0 0.0 144.0 24.0")
        _, output = mac.run(f"""arbor_build
click 500 500
arbor_hang_curtain || exit 9
ARBOR_PID=4242
cat > "$FAKE/windows" <<LIST
800 4242 3 0 0 1024 768 on Arbor
801 {canary} 25 700 40 300 80 on Notification Center
802 {canary} 20 0 0 1024 768 on Dock
803 {canary} 0 100 100 200 200 on Somebody's App
804 $ARBOR_CURTAIN_PID 0 0 0 1024 768 on curtain
LIST
click 150 150
click 750 60
click 500 501
drag 500 502 150 150
click 5 5
click 20 760
click 2000 300
click "" ""
click 0 0
click 900 12
click 828 12
click 971 12
click 827 12
click 972 12
click 900 41
rightclick 900 12
rightclick 500 503
rm "$FAKE/status-item-frame"
click 900 13
echo {canary} > "$FAKE/front"
key cmd+w
key ctrl+opt+space --down
key ctrl+opt+space --up
release
echo "$ARBOR_CURTAIN_PID" > "$FAKE/front"
key cmd+w
key shift+cmd+q
key cmd+space
key cmd+tab
key ctrl+left
key ctrl+opt+left
key ctrl+opt+space
printf 'InputSourceKind\\nInputSourceKind\\n' > "$FAKE/defaults-com.apple.HIToolbox"
key ctrl+opt+space
ARBOR_PID=""
""")
        return [("lib.sh: on somebody's Mac only presses on the script's own windows and keys to its own apps are posted; letting go always is",
                 mac.read("posted").splitlines(),
                 ["click 500 501", "drag 500 502 150 150", "click 900 12", "click 828 12", "click 971 12", "click 900 12 --right", "key ctrl+opt+space --up", "release", "key cmd+w", "key ctrl+opt+left",
                  "key ctrl+opt+space", "key ctrl+opt+space --up", "calm", "move 100 100"]),
                ("lib.sh: and each one that is declined says why, without naming anybody's app", (output.count("skipped: "), "Somebody" in output), (20, False)),
                ("lib.sh: a right click that would take the curtain down is declined", output.count("would take the curtain down"), 1)]

    def pictures(mac):
        _, output = mac.run(f"""ARBOR_SETTLE=0
sleep 300 &
mine=$!
list() {{ cat > "$FAKE/windows"; echo "804 $ARBOR_CURTAIN_PID 0 0 0 1024 768 on curtain" >> "$FAKE/windows"; echo "805 {canary} 0 50 50 900 600 on Somebody's App" >> "$FAKE/windows"; }}
ARBOR_SHOTS=1 shot before-the-curtain
arbor_hang_curtain || exit 9
ARBOR_PID=4242
list <<LIST
799 {canary} 24 0 0 1024 31 on Window Server
800 4242 3 0 0 1024 768 on Arbor
802 {canary} 20 0 0 1024 768 on Dock
806 $mine 0 100 100 300 200 on ArborTestWindows
LIST
shot unasked
film unasked-film 2
look mine 806
look theirs 805
look nothing ""
look gone 999
export ARBOR_SHOTS=1
shot ours
panorama everything
echo false > "$FAKE/screen-access"
shot no-permission
look no-permission 806
echo true > "$FAKE/screen-access"
list <<LIST
801 {canary} 25 700 40 300 80 on Notification Center
LIST
shot banner
arbor_capture past-the-question unasked
list < /dev/null
echo "801 {canary} 25 700 40 300 80 on Notification Center" > "$FAKE/banner"
shot banner-meanwhile
rm "$FAKE/banner"
list < /dev/null
ARBOR_SHOTS_WHOLE_SCREEN_I_HAVE_CLOSED_EVERYTHING=1 shot whole-screen
ARBOR_PID=""
kill $mine
""")
        return [("lib.sh: on somebody's Mac a picture is of one window of the run's own; or, asked for, of the curtain's part of the main display while nothing of "
                 "theirs shows there; ARBOR_SHOTS=1 never gets the whole screen",
                 (mac.read("pictures").splitlines(), sorted(name for name in os.listdir(os.path.join(mac.folder, "out")) if name.endswith(".png"))),
                 (["-x -o -l806 out/mine.png", "-x -C -R0,31,1024,674 out/ours.png", "-x -C -R0,31,1024,674 out/banner-meanwhile.png", "-x -C out/whole-screen.png"],
                  ["mine.png", "ours.png", "whole-screen.png"])),
                ("lib.sh: and says why not, without naming anybody's app",
                 ([line.split(": ", 2)[1] for line in output.splitlines() if line.startswith(("shot ", "look ")) and ("skipped" in line or "thrown" in line)],
                  "Somebody" in output or "Notification" in output),
                 (["skipped"] * 11 + ["thrown away"], False))]

    def discreet(mac):
        mac.environment["HOME"] = os.path.join(mac.folder, "home of mine")
        os.makedirs(mac.environment["HOME"])
        said = 'echo "in $ARBOR_ROOT/Sources and /private$ARBOR_ROOT/x, $HOME/Documents/tax.pdf, /Users/you/Library and \\"/Users/you\\": done"'
        setup = ('echo "2026-10-14T11:00:00.000Z ERROR setup: Other window managers: Secret Tiler is running | quit it"\n'
                 'echo "2026-10-14T11:00:00.000Z INFO  shortcuts: Secret Tiler keys is a shortcut of macOS\'s as well, so one of the two does nothing"')
        code, output = mac.run(f'{said}\n{said} >&2\n{said} > "$ARBOR_OUT/build.log"\n{said} > "$ARBOR_OUT/picture.png"\nyes | head -n 1\n'
                               f'logs() {{\n{setup}\n}}\nlogs\nlogs > "$ARBOR_OUT/arbor.log"\nexit 3')
        clean = 'in <checkout>/Sources and <checkout>/x, ~/Documents/tax.pdf, ~/Library and "~": done'
        return [("lib.sh: on somebody's Mac what a run prints, on either output, says neither where the checkout nor where the home folder is",
                 (code, [line for line in output.splitlines() if line.startswith("in ") or line == "y"]), (3, [clean, clean, "y"])),
                ("lib.sh: nor do the logs it leaves; other files are left as they are",
                 (mac.read("out/build.log").strip(), "/Users/you" in mac.read("out/picture.png")), (clean, True)),
                ("lib.sh: what Arbor logs about the person's setup keeps its heading and loses the rest, in the output and in the log",
                 ("setup: Other window managers: (stays on this Mac)" in output, "Secret Tiler" in output + mac.read("out/arbor.log")), (True, False))]

    def nameless(mac):
        mac.put("windows", f"801 {canary} 0 10 10 300 200 on Secret Diary\n802 {canary} 20 0 0 1024 768 on Dock\n803 MINE 0 10 10 300 200 on ArborTestWindows")
        _, output = mac.run('sleep 300 &\nsed -i.bak "s/MINE/$!/" "$FAKE/windows"\npointer windows | cut -d " " -f 1,9-\nkill $!')
        return [("lib.sh: on somebody's Mac the list of windows names the run's own apps and macOS's furniture",
                 [line for line in output.splitlines() if line.startswith("80")], ["801 somebody", "802 Dock", "803 ArborTestWindows"])]

    def curtain_down(mac):
        code, _ = mac.run('arbor_build\narbor_hang_curtain\nkill "$ARBOR_CURTAIN_PID"\nsleep 0.3\nclick 500 500\necho "went on" > "$FAKE/said"')
        return [("lib.sh: when somebody takes the curtain down the script ends", (code, mac.read("said"), "click" in mac.read("posted")), (75, "", False))]

    def traces(mac):
        mac.put("defaults-com.apple.WindowManager", "EnableTilingByEdgeDrag = 1;")
        _, quiet = mac.run("true")
        _, loud = mac.run('echo "EnableTilingByEdgeDrag = 0;" > "$FAKE/defaults-com.apple.WindowManager"')
        mac.tool("lsappinfo", '#!/bin/bash\n[ -f "$FAKE/quit" ] || printf \'"Secret Diary" ASN:0x0: \\n    bundleID="com.example.diary"\\n    pid = 77 type="Foreground"\\n\'\n')
        _, private = mac.run('touch "$FAKE/quit"')
        kept = mac.read("out/stays-on-this-mac.txt")
        return [("lib.sh: on somebody's Mac a run that changed nothing says so", "nothing that was looked at differs" in quiet, True),
                ("lib.sh: and one that changed a setting is told on",
                 ("< setting WindowManager: EnableTilingByEdgeDrag = 1;" in loud, "> setting WindowManager: EnableTilingByEdgeDrag = 0;" in loud), (True, True)),
                ("lib.sh: of what differs about the person's own apps only how much is printed; which, stays in a file on their Mac",
                 ("app: 1 line(s) differ" in private, "diary" in private, "< app: com.example.diary 77" in kept), (True, False, True))]

    def stale_output(mac):
        mac.put("out/keys.log", "ready pid=1234")
        mac.put("out/output.txt", "the caller's")
        mac.run("true")
        return [("lib.sh: on somebody's Mac the last run's output does not pass for this one's", sorted(os.listdir(os.path.join(mac.folder, "out"))), ["output.txt"])]

    def defaults_for_arbor(mac):
        _, output = mac.run('env | grep -E "^ARBOR_(ONLY_PIDS|NO_[A-Z]*)=" | sort | tr "\\n" " "')
        return [("lib.sh: on somebody's Mac an Arbor started past arbor_start arranges nothing, stays dead, asks nothing and photographs nothing",
                 "ARBOR_NO_OPENING=1 ARBOR_NO_PICTURES=1 ARBOR_NO_PROMPT=1 ARBOR_NO_WATCHDOG=1 ARBOR_ONLY_PIDS=1" in output, True)]

    def second_lock(mac):
        mac.tool("uname", "#!/bin/bash\necho Darwin\n")
        mac.tool("id", '#!/bin/bash\ncase "$1" in -u) echo 501 ;; -un) cat "$FAKE/account" ;; esac\n')
        asks = 'on_throwaway_mac && echo "thrown away" || echo "somebody\'s"\nbash -c \'echo "a tool sees: ${GITHUB_ACTIONS:-nothing}"\''
        mac.put("account", "zelda")
        _, exported = mac.run(asks)
        mac.put("account", "runner")
        _, real = mac.run(asks)
        return [("lib.sh: GITHUB_ACTIONS=true on a Mac whose account is not GitHub's opens nothing, for the tools either",
                 ("somebody's" in exported, "a tool sees: nothing" in exported, "zelda" in exported), (True, True, False)),
                ("lib.sh: on GitHub's own it does", ("thrown away" in real, "a tool sees: true" in real), (True, True))]

    def which_build(mac):
        for name in ("ARBOR_BIN", "ARBOR_BUILT"):
            del mac.environment[name]
        mac.environment["ARBOR_APPS"] = os.path.join(mac.folder, "apps")
        mac.tool("swift", '#!/bin/bash\necho "$*" >> "$FAKE/swift-was-asked"\nexit 1\n')
        for name in ("swiftc", "clang"):
            mac.tool(name, "#!/bin/bash\nexit 0\n")
        found = []
        for configuration in (None, "debug", "release"):
            mac.environment.pop("ARBOR_CONFIGURATION", None)
            if configuration:
                mac.environment["ARBOR_CONFIGURATION"] = configuration
            mac.put("swift-was-asked", "")
            _, output = mac.run('echo "drives: ${ARBOR_BIN#"$ARBOR_ROOT"/}"\narbor_build')
            found.append((next((line[8:] for line in output.splitlines() if line.startswith("drives: ")), None), mac.read("swift-was-asked").split("\n")[1:-1]))
        mac.environment["ARBOR_CONFIGURATION"] = "Release"
        code, output = mac.run('echo "went on"')
        return [("lib.sh: which build a script drives, and asks swift for: debug unless it is told release", found,
                 [(".build/debug", ["build -c debug"])] * 2 + [(".build/release", ["build -c release"])]),
                ("lib.sh: any other configuration is refused before anything happens", (code, "went on" in output, "debug or release, not 'Release'" in output), (64, False, True))]

    def stray_environment(mac):
        os.makedirs(os.path.join(mac.folder, "precious"))
        open(os.path.join(mac.folder, "precious", "empty.log"), "w", encoding="utf-8").close()
        del mac.environment["ARBOR_REHEARSAL"]
        mac.environment["ARBOR_OUT"] = os.path.join(mac.folder, "precious")
        code, _ = mac.run("true")
        return [("lib.sh: ARBOR_OUT from a stray environment is not taken", (code, os.path.exists(os.path.join(mac.folder, "precious", "empty.log"))), (0, True))]

    throwaway = [second_lock, which_build, folders, full_disk, disk_fills_up, strange_mktemp, refusals, strangers, limited, both_killed, supervisor_killed, two_at_once,
                 ended("the time limit"), ended("an interrupt"), ended("kill -9")]
    somebodys = [nets, pictures, discreet, nameless, curtain_down, stale_output, defaults_for_arbor, no_curtain, both_killed, supervisor_killed,
                 ended("the time limit", "on somebody's Mac, "), ended("an interrupt", "on somebody's Mac, "), ended("kill -9", "on somebody's Mac, "),
                 declined("not beside an Arbor that is running already", running__Arbor=str(canary)),
                 declined("not beside another window manager", running__Rectangle=str(canary)),
                 declined("not under somebody's hands", idle="20"), quiet_since, keeps_awake, declined("not into a call", awake="1"), declined("not as root", uid="0"),
                 declined("not behind a locked screen", locked="yes"), declined("not under the screen saver", running__ScreenSaverEngine=str(canary)),
                 declined("not with the display asleep", asleep="true")]
    # One looks at what else is under /tmp, the other is no rehearsal and would be declined beside another run.
    return [(situation, False) for situation in throwaway] + [(situation, True) for situation in somebodys], [(traces, True), (stray_environment, False)]


def check_mac_shell_lib(canary, since):
    def tried(entry):
        situation, somebodys = entry
        mac = FakeMac(somebodys)
        began = time.time()
        try:
            return situation(mac)
        except Exception as error:  # noqa: BLE001  A script that never started (the lint declined the checkout, say) is a row that fails.
            return [(f"lib.sh: {getattr(situation, '__name__', 'a situation')} could be tried", repr(error), "")]
        finally:
            mac.close()
            if os.environ.get("ARBOR_TEST_TIMES"):
                print(f"{time.time() - began:5.1f} s  {getattr(situation, '__name__', situation)}")

    try:
        # Somebody's process: older than any run below by more than lib.sh, which has whole seconds to go by, can mistake.
        time.sleep(max(0, since + 4.2 - time.time()))
        together, alone = lib_situations(canary.pid)
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(tried, together))
        for result in results + [tried(entry) for entry in alone]:
            for what, got, expected in result:
                row(what, got, expected)
    finally:
        canary.kill()
        canary.wait()


# MARK: Makefile

def targets_without_a_rule(text):
    """A name that is only in .PHONY: `make <name>` then says "Nothing to be done" and succeeds, whatever it was meant to run."""
    phony = [name for line in text.splitlines() if line.startswith(".PHONY:") for name in line.split()[1:]]
    return [name for name in phony if not any(line.startswith(f"{name}:") for line in text.splitlines())]


def check_run_list():
    """run-list.sh: in order, with a clean environment, and no further than the first sign of trouble."""
    runner = os.path.join(HERE, "mac-shell", "run-list.sh")

    def tried(scripts, *arguments, interrupt=False, **more):
        with tempfile.TemporaryDirectory(prefix="tooling-") as folder:
            for name, text in scripts.items():
                with open(os.path.join(folder, name), "w", encoding="utf-8") as handle:
                    handle.write(text)
            os.makedirs(os.path.join(folder, "left"))
            environment = {**os.environ, "ARBOR_REHEARSAL": "1", "ARBOR_LIST_FOLDER": folder, "ARBOR_LIST_RESULTS": os.path.join(folder, "results"),
                           "ARBOR_OUT": os.path.join(folder, "left"), "ARBOR_LIST_FIRST": "a.sh b.sh", "ARBOR_LIST_REST": "c.sh d.sh e.sh", "FOLDER": folder,
                           "GITHUB_ACTIONS": "true", "ARBOR_SHOTS": "1", "ARBOR_BUSY_OK": "1", **more}
            process = subprocess.Popen([BASH, runner, *arguments], env=environment, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
            if interrupt:
                for _ in range(200):
                    if os.path.exists(os.path.join(folder, "ready")):
                        break
                    time.sleep(0.05)
                os.kill(process.pid, signal.SIGINT)
            output, _ = process.communicate(timeout=60)
            ran = sorted(os.listdir(os.path.join(folder, "results"))) if os.path.isdir(os.path.join(folder, "results")) else []
            kept = {name: sorted(os.listdir(os.path.join(folder, "results", name))) for name in ran if name != "summary.txt"}
            return process.returncode, [name for name in ran if name != "summary.txt"], output, kept

    def at_a_terminal(scripts, key):
        """As a person starts it: standard input is a terminal, and `key` is pressed when it asks for Return."""
        with tempfile.TemporaryDirectory(prefix="tooling-") as folder:
            for name, text in scripts.items():
                with open(os.path.join(folder, name), "w", encoding="utf-8") as handle:
                    handle.write(text)
            os.makedirs(os.path.join(folder, "left"))
            environment = {**os.environ, "ARBOR_REHEARSAL": "1", "ARBOR_LIST_FOLDER": folder, "ARBOR_LIST_RESULTS": os.path.join(folder, "results"),
                           "ARBOR_OUT": os.path.join(folder, "left"), "ARBOR_LIST_FIRST": "compile-tools.sh b.sh", "ARBOR_LIST_REST": ""}
            child, terminal = pty.fork()
            if child == 0:
                os.execve(shutil.which(BASH), [BASH, runner], environment)
            said, pressed, until = b"", False, time.time() + 30
            while time.time() < until:
                if select.select([terminal], [], [], 0.2)[0]:
                    try:
                        more = os.read(terminal, 4096)
                    except OSError:  # Linux says so when the other end has gone
                        break
                    if not more:
                        break
                    said += more
                if not pressed and b"Press Return" in said:
                    time.sleep(0.3)
                    os.write(terminal, key)
                    pressed = True
            ended, status = os.waitpid(child, os.WNOHANG)
            # The terminal closes a moment before its process has ended.
            while not ended and time.time() < until:
                time.sleep(0.05)
                ended, status = os.waitpid(child, os.WNOHANG)
            if not ended:
                os.kill(child, signal.SIGKILL)
                os.waitpid(child, 0)
                return "still waiting", []
            os.close(terminal)
            return os.WEXITSTATUS(status), [line.strip() for line in said.decode("utf-8", "replace").splitlines() if line.startswith("sees")]

    fine = 'echo "sees ${GITHUB_ACTIONS:-no} ${ARBOR_SHOTS:-no} ${ARBOR_BUSY_OK:-no} ${ARBOR_QUIET_SINCE:+quiet}"\necho log > "$ARBOR_OUT/arbor.log"\necho "3 passed, 0 failed"\n'
    good = {name: fine for name in ("a.sh", "b.sh", "c.sh", "d.sh", "e.sh")}
    code, ran, output, kept = tried(good)
    row("run-list: without a word, the first two", (code, ran), (0, ["01-a", "02-b"]))
    row("run-list: nothing from the caller's environment opens a gate; the second script is told since when it has been quiet",
        [line for line in output.splitlines() if line.startswith("sees")], ["sees no no no ", "sees no no no quiet"])
    row("run-list: what a script said and what it left are kept apart from the next one's", kept, {"01-a": ["arbor.log", "output.txt"], "02-b": ["arbor.log", "output.txt"]})
    code, ran, output, _ = tried(good, "--all", "--pictures")
    row("run-list: --all, in order; --pictures asks for them", (code, ran, "sees no 1 no quiet" in output), (0, ["01-a", "02-b", "03-c", "04-d", "05-e"], True))
    row("run-list: for a person at a terminal quiet counts from the moment they start it; --busy-ok is theirs to say",
        [line for line in tried(good, "--busy-ok", ARBOR_LIST_AT_A_TERMINAL="1")[2].splitlines() if line.startswith("sees")], ["sees no no 1 quiet", "sees no no 1 quiet"])
    tools = {"compile-tools.sh": fine, "b.sh": fine}
    row("run-list: at a terminal it asks for Return once everything is built, and quiet counts from there", at_a_terminal(tools, b"\n"), (0, ["sees no no no", "sees no no no quiet"]))
    row("run-list: at a terminal ⌃C instead of Return ends it, and nothing more is started", at_a_terminal(tools, b"\x03"), (1, ["sees no no no"]))
    def awake(listing):
        """What the scripts are told, with stand-ins for caffeinate and pmset on the PATH, and whether the caffeinate outlives the list."""
        with tempfile.TemporaryDirectory(prefix="tooling-") as tools:
            for name, text in (("caffeinate", f'echo $$ > "{tools}/pid"\nexec sleep 30'), ("pmset", listing.replace("TOOLS", tools))):
                with open(os.path.join(tools, name), "w", encoding="utf-8") as handle:
                    handle.write(f"#!/bin/bash\n{text}\n")
                os.chmod(os.path.join(tools, name), 0o755)
            told = 'echo "told ${ARBOR_KEEPS_AWAKE:-nothing}"\n'
            output = tried({"a.sh": told, "b.sh": told}, PATH=tools + os.pathsep + os.environ["PATH"], ARBOR_KEEPS_AWAKE="1")[2]
            with open(os.path.join(tools, "pid"), encoding="utf-8") as handle:
                pid = handle.read().strip()
            return [line.replace(pid, "its pid") for line in output.splitlines() if line.startswith("told")], alive(pid)

    row("run-list: it keeps the display awake, tells every script with which process, and lets go at the end",
        awake('echo "   pid $(cat "TOOLS/pid")(caffeinate): [0x1] 00:00:01 PreventUserIdleDisplaySleep named: \\"caffeinate command-line tool\\""'),
        (["told its pid", "told its pid"], False))
    row("run-list: where macOS does not list its caffeinate as the scripts look for it, it is given up, or they would all decline",
        awake('echo "   something else"'), (["told nothing", "told nothing"], False))
    some = {"compile-tools.sh": 'echo "✔ pointer"\necho "✘ scenery"\necho "✘ axfind"\nexit 2\n', "b.sh": fine}
    row("run-list: a tool that does not compile is a finding, and the harness is tried all the same",
        tried(some, ARBOR_LIST_FIRST="compile-tools.sh b.sh")[:2], (0, ["01-compile-tools", "02-b"]))
    row("run-list: without the pointer there is no going on",
        tried({**some, "compile-tools.sh": 'echo "✘ pointer"\nexit 1\n'}, ARBOR_LIST_FIRST="compile-tools.sh b.sh")[:2], (1, ["01-compile-tools"]))
    row("run-list: a script by name, after the first two", tried(good, "d.sh")[:2], (0, ["01-a", "02-b", "03-d"]))
    row("run-list: a script that is not on the list", tried(good, "lib.sh")[:2], (64, []))
    row("run-list: the harness fails a check: nothing else runs", tried({**good, "b.sh": "exit 1\n"}, "--all")[:2], (1, ["01-a", "02-b"]))
    row("run-list: a later script fails a check: a finding, and the list goes on", tried({**good, "c.sh": "exit 1\n"}, "--all")[:2], (0, ["01-a", "02-b", "03-c", "04-d", "05-e"]))
    row("run-list: a script declines: the Mac is not free", tried({**good, "c.sh": 'echo "skipped: somebody"\nexit 77\n'}, "--all")[:2], (1, ["01-a", "02-b", "03-c"]))
    row("run-list: a script is cut off", tried({**good, "d.sh": "exit 124\n"}, "--all")[:2], (1, ["01-a", "02-b", "03-c", "04-d"]))
    row("run-list: the Mac differs afterwards",
        tried({**good, "c.sh": 'echo "::warning title=mac-shell::this Mac differs from before the run (< before, > after):"\n'}, "--all")[:2], (1, ["01-a", "02-b", "03-c"]))
    slow = 'trap \'sleep 0.5; echo "cleaned up"; exit 130\' TERM\ntouch "$FOLDER/ready"\nsleep 30 &\nwait $!\n'
    code, ran, output, _ = tried({**good, "b.sh": slow}, "--all", interrupt=True)
    row("run-list: interrupted, it passes that on, waits for the script to clean up, and stops", (code, ran, "cleaned up" in output, "STOPPED" in output), (1, ["01-a", "02-b"], True, True))


def check_install():
    """Without a terminal nothing is installed, removed or started unless somebody says so."""
    root = os.path.dirname(HERE)
    with tempfile.TemporaryDirectory(prefix="tooling-") as home:
        kept = {key: value for key, value in os.environ.items() if key not in ("GITHUB_ACTIONS", "ARBOR_UNATTENDED", "PREFIX", "BINDIR")}

        def tried(command, **more):
            done = subprocess.run(command, cwd=root, env={**kept, "HOME": home, **more}, stdin=subprocess.DEVNULL, capture_output=True, text=True)
            return done.returncode, os.listdir(home)

        row("install.sh: from a loop it declines and touches nothing", tried(["bash", "scripts/install.sh"]), (77, []))
        row("install.sh: removing too", tried(["bash", "scripts/install.sh", "--uninstall"]), (77, []))
        row("install.sh: told that the owner asked, it goes on", tried(["bash", "scripts/install.sh", "--uninstall"], ARBOR_UNATTENDED="1")[0], 0)
        row("make run: from a loop it declines", tried(["make", "-o", "build", "run"])[0], 2)
        identity = ["bash", "scripts/make-signing-identity.sh"]
        row("make-signing-identity.sh: from a loop the login keychain is left alone, making and removing",
            (tried(identity), tried(identity + ["--remove"])), ((77, []), (77, [])))
        # On Linux it then ends because there are no keychains, on a Mac because that file is none: 1 either way.
        row("make-signing-identity.sh: another keychain, or the owner's word, and it goes on",
            (tried(identity + ["--keychain", os.path.join(home, "none")])[0], tried(identity, ARBOR_UNATTENDED="1")[0]), (1, 1))

        # A runner that somebody set up on their own Mac says GITHUB_ACTIONS=true as GitHub's do, under that person's name.
        with tempfile.TemporaryDirectory(prefix="tooling-") as tools:
            with open(os.path.join(tools, "id"), "w", encoding="utf-8") as file:
                file.write('#!/bin/bash\ncase "$1" in -un) echo "$FAKE_ACCOUNT" ;; *) exec /usr/bin/id "$@" ;; esac\n')
            os.chmod(os.path.join(tools, "id"), 0o755)

            def in_a_job(command, account):
                return tried(command, GITHUB_ACTIONS="true", FAKE_ACCOUNT=account, PATH=tools + os.pathsep + os.environ["PATH"])

            row("install.sh: a job on somebody's own Mac is a loop like any other, installing and removing",
                (in_a_job(["bash", "scripts/install.sh"], "zelda"), in_a_job(["bash", "scripts/install.sh", "--uninstall"], "zelda")), ((77, []), (77, [])))
            row("install.sh: on GitHub's own Macs, which are nobody's, it goes on", in_a_job(["bash", "scripts/install.sh", "--uninstall"], "runner")[0], 0)
            row("make-signing-identity.sh: a job on somebody's own Mac leaves the login keychain alone, making and removing",
                (in_a_job(identity, "zelda"), in_a_job(identity + ["--remove"], "zelda")), ((77, []), (77, [])))

    def leftover_after_uninstalling(beside):
        """Whether the hidden copy that a killed install left is still there, beside an installed app or alone."""
        with tempfile.TemporaryDirectory(prefix="tooling-") as home:
            for name in [".Arbor.app.new"] + (["Arbor.app"] if beside else []):
                os.makedirs(os.path.join(home, "Applications", name, "Contents", "Helpers"))
            subprocess.run(["bash", "scripts/install.sh", "--uninstall"], cwd=root, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                           env={**kept, "HOME": home, "ARBOR_UNATTENDED": "1"})
            return os.path.exists(os.path.join(home, "Applications", ".Arbor.app.new"))

    def uninstalled(swift, **more):
        """(exit code, whether the app is still there) with a stand-in for `swift scripts/out-of-view.swift`."""
        with tempfile.TemporaryDirectory(prefix="tooling-") as home:
            os.makedirs(os.path.join(home, "Applications", "Arbor.app", "Contents", "Helpers"))
            os.makedirs(os.path.join(home, "bin"))
            with open(os.path.join(home, "bin", "swift"), "w", encoding="utf-8") as handle:
                handle.write(f"#!/bin/bash\n{swift}\n")
            os.chmod(os.path.join(home, "bin", "swift"), 0o755)
            done = subprocess.run(["bash", "scripts/install.sh", "--uninstall"], cwd=root, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                                  env={**kept, "HOME": home, "PATH": os.path.join(home, "bin") + os.pathsep + os.environ["PATH"], "ARBOR_UNATTENDED": "1", **more})
            return done.returncode, os.path.isdir(os.path.join(home, "Applications", "Arbor.app")), "NOTHING WAS REMOVED" in done.stderr

    def installed(cp, rm='exec /bin/rm "$@"'):
        """(exit code, what the installed app holds, whether Arbor was asked to quit, what else lies beside it) with stand-ins for `cp` and `rm`."""
        with tempfile.TemporaryDirectory(prefix="tooling-") as folder:
            home = os.path.join(folder, "home")
            for path in ("scripts", "bin", "build/Arbor.app/Contents/Helpers", "home/Applications/Arbor.app"):
                os.makedirs(os.path.join(folder, path))
            shutil.copy(os.path.join(HERE, "install.sh"), os.path.join(folder, "scripts", "install.sh"))
            for path, text in (("scripts/version.sh", "echo 1.0"), ("bin/swift", "echo 0"), ("bin/cp", cp), ("bin/rm", rm),
                               ("build/Arbor.app/Contents/Helpers/arborctl", f'echo "$1" >> "{folder}/asked"; exit 2')):
                with open(os.path.join(folder, path), "w", encoding="utf-8") as handle:
                    handle.write(f"#!/bin/bash\n{text}\n")
                os.chmod(os.path.join(folder, path), 0o755)
            open(os.path.join(home, "Applications", "Arbor.app", "the-old-one"), "w", encoding="utf-8").close()
            done = subprocess.run(["bash", "scripts/install.sh"], cwd=folder, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                                  env={**kept, "HOME": home, "PATH": os.path.join(folder, "bin") + os.pathsep + os.environ["PATH"], "ARBOR_UNATTENDED": "1", "LAUNCH": "0"})
            app = os.path.join(home, "Applications", "Arbor.app")
            return (done.returncode, sorted(os.listdir(app)) if os.path.isdir(app) else "no app at all", os.path.exists(os.path.join(folder, "asked")),
                    sorted(name for name in os.listdir(os.path.join(home, "Applications")) if name != "Arbor.app"))

    row("install.sh: the new app takes the old one's place, and nothing is left beside it", installed('exec /bin/cp "$@"'), (0, ["Contents"], True, []))
    row("install.sh: a copy that fails half way changes nothing: the old app stays, and the Arbor that runs is not asked to quit",
        installed('/bin/mkdir -p "${@: -1}/half"; exit 1'), (1, ["the-old-one"], False, []))
    row("install.sh: ended before the swap, it leaves no hidden copy, and the old app",
        installed('/bin/cp "$@" && kill -TERM $PPID; sleep 1'), (143, ["the-old-one"], False, []))
    # By then the old Arbor has quit, and whichever copy is left is what fetches windows that are out of view.
    row("install.sh: once the swap has begun it is finished, whatever signal comes: never neither app",
        [installed('exec /bin/cp "$@"', rm=f'case "${{@: -1}}" in */Arbor.app) kill -{signal} $PPID; sleep 0.3 ;; esac; exec /bin/rm "$@"') for signal in ("TERM", "INT", "HUP")],
        [(0, ["Contents"], True, [])] * 3)
    row("install.sh: uninstalling removes the hidden copy that a killed install left, beside an app or alone",
        (leftover_after_uninstalling(True), leftover_after_uninstalling(False)), (False, False))
    row("install.sh: with windows still out of view after Arbor has quit, nothing is removed", uninstalled("echo 2"), (75, True, True))
    row("install.sh: with every window in view it is", uninstalled("echo 0"), (0, False, False))
    row("install.sh: told that they are not Arbor's doing, it is", uninstalled("echo 2", ARBOR_LEAVE_WINDOWS="1"), (0, False, False))
    row("install.sh: where nobody can say, as before", (uninstalled("exit 2"), uninstalled("echo nonsense")), ((0, False, False), (0, False, False)))


def check_e2e():
    """Whoever quotes a report quotes its beginning."""
    steps = "".join(f"\n▸ step {n}  (command {n})\n  ✔ it works\n" + ("  ✘ late — 3 is not 4\n  ✘ later still\n" if n == 180 else "") for n in range(1, 201))

    def tried(said, code, account=None):
        with tempfile.TemporaryDirectory(prefix="tooling-") as folder:
            os.makedirs(os.path.join(folder, "scripts"))
            os.makedirs(os.path.join(folder, ".build", "debug"))
            environment = {key: value for key, value in os.environ.items() if key != "GITHUB_ACTIONS"}
            if account:
                with open(os.path.join(folder, "id"), "w", encoding="utf-8") as handle:
                    handle.write(f"#!/bin/bash\necho {account}\n")
                os.chmod(os.path.join(folder, "id"), 0o755)
                environment.update(GITHUB_ACTIONS="true", PATH=folder + os.pathsep + os.environ["PATH"])
            shutil.copy(os.path.join(HERE, "e2e.sh"), os.path.join(folder, "scripts", "e2e.sh"))
            runner = os.path.join(folder, ".build", "debug", "arbor-e2e")
            with open(runner, "w", encoding="utf-8") as handle:
                handle.write(f"#!/bin/bash\ncat <<'END'\n{said}END\necho \"in a job of GitHub's: ${{GITHUB_ACTIONS:-no}}\"\nexit {code}\n")
            os.chmod(runner, 0o755)
            done = subprocess.run([BASH, os.path.join(folder, "scripts", "e2e.sh")], stdin=subprocess.DEVNULL, capture_output=True, text=True, check=False,
                                  env=environment)
            kept = os.path.join(folder, "collab", "evidence", "e2e-latest.txt")
            return done.returncode, done.stdout, open(kept, encoding="utf-8").read() if os.path.exists(kept) else None

    code, output, kept = tried(steps + "\n200 passed, 2 failed\n", 1)
    quoted = [line for line in output.splitlines() if "▸" in line or "✘" in line][:40]
    row("e2e.sh: a check that fails in a late step is in the first lines of the report, under its step",
        (code, quoted[:4]), (1, ["▸ step 180  (command 180)", "  ✘ late — 3 is not 4", "  ✘ later still", "▸ step 1  (command 1)"]))
    row("e2e.sh: the run follows whole, with one summary, and the evidence is the run alone",
        (output.count("▸ step "), output.count("200 passed, 2 failed"), kept.count("▸ step "), kept.count("✘"), "that failed" in kept), (201, 1, 200, 2, False))
    noted = steps.replace("  ✘ late — 3 is not 4\n", "  ✘ late — 3 is not 4\n    ↳ what Arbor logged\n    ↳ and then\n").replace("▸ step 181", "    ↳ under no failure\n▸ step 181")
    row("e2e.sh: the notes under a failed check come with it, and no others",
        tried(noted + "\n200 passed, 2 failed\n", 1)[1].splitlines()[1:7],
        ["▸ step 180  (command 180)", "  ✘ late — 3 is not 4", "    ↳ what Arbor logged", "    ↳ and then", "  ✘ later still", ""])
    code, output, kept = tried(steps.replace("  ✘ late — 3 is not 4\n  ✘ later still\n", "") + "\n200 passed, 0 failed\n", 0)
    row("e2e.sh: a run without failures is printed as it was", (code, "that failed" in output, output.count("▸ step "), kept is not None), (0, False, 200, True))
    row("e2e.sh: a run that could not start keeps its exit code and leaves no evidence", tried("somebody is using this Mac\n", 2)[::2], (2, None))
    row("e2e.sh: a job on somebody's own Mac is not one on GitHub's: the runner is not told so; under the account `runner` it is",
        [tried("x\n", 0, account)[1].splitlines()[-2] for account in ("jo", "runner")], ["in a job of GitHub's: no", "in a job of GitHub's: true"])
    lost = steps[:400] + "\narbor-e2e: no verdict (exit 5): set-up failed: no windows\n  screen locked: yes\n  error -25204\n\n--- arbor.log (last 100 lines) ---\na line\n"
    code, output, kept = tried(lost, 5)
    row("e2e.sh: why there is no verdict, and what the Mac said, are the first lines of the report",
        (code, output.splitlines()[:3], output.count("no verdict"), kept),
        (5, ["arbor-e2e: no verdict (exit 5): set-up failed: no windows", "  screen locked: yes", "  error -25204"], 2, None))


def check_e2e_guardian():
    spec = importlib.util.spec_from_file_location("e2e_guardian", os.path.join(HERE, "test-e2e-guardian.py"))
    guardian = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(guardian)
    for situation in guardian.situations():
        row(*situation)


def check_makefile():
    row("Makefile: a target whose rule a merge dropped", targets_without_a_rule(".PHONY: build e2e\nbuild:\n\tswift build\n"), ["e2e"])
    with open(os.path.join(os.path.dirname(HERE), "Makefile"), encoding="utf-8") as handle:
        row("Makefile: every target it declares has a rule", targets_without_a_rule(handle.read()), [])


# MARK: rehearse.sh

def check_rehearse():
    """It tells scripts that they are on a throwaway Mac, so on a real one it must not get as far as running any."""
    with tempfile.TemporaryDirectory() as folder:
        uname = os.path.join(folder, "uname")
        with open(uname, "w", encoding="utf-8") as handle:
            handle.write("#!/bin/sh\necho Darwin\n")
        os.chmod(uname, 0o755)
        witness = os.path.join(folder, "ran")
        script = os.path.join(folder, "script.sh")
        with open(script, "w", encoding="utf-8") as handle:
            handle.write(f"touch '{witness}'\n")
        environment = dict(os.environ, PATH=folder + os.pathsep + os.environ["PATH"])
        code = subprocess.run(
            ["bash", os.path.join(HERE, "mac-shell", "rehearse.sh"), script], env=environment, capture_output=True, check=False).returncode
        row("rehearse.sh: on a Mac it refuses and runs nothing", (code, os.path.exists(witness)), (77, False))

        # A script asks whether a panel is on screen by its level. One that the fake Mac leaves out makes the check red here and green on a Mac.
        if sys.platform != "linux":
            return
        if not os.access(os.path.join(ROOT, ".build", "debug", "arbor-fakemac"), os.X_OK):
            print("SKIPPED the row for the fake Mac's list of windows: no .build/debug/arbor-fakemac; run swift build first")
            return
        with open(script, "w", encoding="utf-8") as handle:
            handle.write(f"""source '{HERE}/mac-shell/lib.sh'
levels() {{ echo "levels:$(pointer windows $1 | awk '$NF == "Arbor" && $3 != 0 {{ printf " %s", $3 }}')"; }}
arbor_build
arbor_start 1 ARBOR_NO_HOTKEYS=0
ctl dock "$W1" left
ctl check-for-updates
key "ctrl+opt+["
levels --on-screen
ctl show-shortcuts
levels --on-screen
arbor_quit
levels
""")
        # Only what is on screen comes front to back. ⌃⌥[ with nothing to go back to is answered by a line, and is a key that stays bound.
        environment = {name: value for name, value in os.environ.items() if name not in ("ARBOR_REHEARSAL_AS", "ARBOR_REHEARSAL_DISPLAY")}
        said = subprocess.run(
            ["bash", os.path.join(HERE, "mac-shell", "rehearse.sh"), script], env=environment, capture_output=True, text=True, check=False).stdout
        row("rehearse.sh: the fake Mac lists the heads-up line, the panel of shortcuts, the update window and the backdrop, front to back, and none after Quit",
            [line for line in said.splitlines() if line.startswith("levels:")], ["levels: 6 3 -2147483602", "levels: 5 3 -2147483602", "levels:"])

        # macOS's own preview, round the window that is held where macOS tiles, and gone with the release. With ⌥ it is up for the line after too.
        with open(script, "w", encoding="utf-8") as handle:
            handle.write(f"""source '{HERE}/mac-shell/lib.sh'
level0() {{ echo "level 0:$(pointer windows --on-screen | awk '$3 == 0 && $NF != "Arbor" {{ printf " %s", ($NF == "WindowManager" ? $4 "," $5 "," $6 "," $7 : $1) }}')"; }}
arbor_build
arbor_start 3
ctl pause
read -r sx sy sw sh <<< "$(arbor_ask screen)"
read -r fx fy fw fh <<< "$(display_frame_of 1)"
drag $(titlebar_of "$W3") "$fx" $((sy + sh / 2)) --no-release
level0
release
level0
drag $(titlebar_of "$W3") $((sx + sw / 2)) $((sy + 200))
drag $(titlebar_of "$W2") $((sx + sw / 2)) $(((fy + sy) / 2)) --no-release
level0
release
drag $(titlebar_of "$W2") $((sx + sw / 2)) $((sy + 200))
drag $(titlebar_of "$W2") $((sx + 200)) $((sy + sh / 2)) --mods opt --no-release
level0
release --mods opt
level0
arbor_stop
""")
        said = subprocess.run(
            ["bash", os.path.join(HERE, "mac-shell", "rehearse.sh"), script], env=environment, capture_output=True, text=True, check=False).stdout
        row("rehearse.sh: the fake Mac lists macOS's own preview in front of and behind the window that is held where macOS tiles, and not after the release",
            [line for line in said.splitlines() if line.startswith("level 0:")],
            ["level 0: -15,16,542,704 103 -15,16,542,704 102 101", "level 0: 103 102 101", "level 0: -15,16,1054,704 102 -15,16,1054,704 103 101",
             "level 0: -15,16,542,704 102 -15,16,542,704 103 101", "level 0: 102 103 101"])


# MARK: ci-mtimes.py

def check_ci_mtimes():
    """A file may get its old time stamp back only if its content is what was built: anything else would hide a change from the compiler."""
    tool = os.path.join(HERE, "ci-mtimes.py")
    then, checkout = 1_000_000_000, 1_500_000_000
    with tempfile.TemporaryDirectory() as folder:
        def git(*arguments):
            subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.com", *arguments], cwd=folder, capture_output=True, check=True)

        def write(path, text, stamp):
            os.makedirs(os.path.dirname(os.path.join(folder, path)), exist_ok=True)
            with open(os.path.join(folder, path), "w", encoding="utf-8") as handle:
                handle.write(text)
            os.utime(os.path.join(folder, path), (stamp, stamp))

        def run(word):
            return subprocess.run([sys.executable, tool, word], cwd=folder, capture_output=True, text=True, check=False)

        def stamp(path):
            return int(os.stat(os.path.join(folder, path)).st_mtime)

        names = ["same", "changed", "same length", "gone", "edited after the checkout"]
        git("init", "--quiet")
        for name in names:
            write(f"Sources/A/{name}.swift", f"let a = 1 // {name}\n", then)
        write("docs/prose.md", "prose\n", then)
        for name in ["same", "changed", "gone"]:
            write(f"scripts/mac-shell/{name}.swift", f"// {name}\n", then)
        write("scripts/mac-shell/other.m", "// other\n", then)
        # Built an hour from now, by the clock of the Mac they were built on: no time stamp will show that they are stale.
        for name in ["same", "changed", "gone", "other", "of no source at all"]:
            write(f".build/mac-shell/{name}", "a tool\n", int(time.time()) + 3600)
        git("add", "--all")
        git("commit", "--quiet", "--message", "built")
        row("ci-mtimes.py: record", run("record").returncode, 0)

        # Another commit, checked out afresh: every file is stamped with the present.
        for name in names:
            write(f"Sources/A/{name}.swift", f"let a = 1 // {name}\n", checkout)
        write("Sources/A/changed.swift", "let a = 22222\n", checkout)
        write("Sources/A/same length.swift", "let a = 2 // same length\n", checkout)
        write("Sources/A/new.swift", "let b = 1\n", checkout)
        write("docs/prose.md", "prose\n", checkout)
        os.remove(os.path.join(folder, "Sources/A/gone.swift"))
        os.remove(os.path.join(folder, "scripts/mac-shell/gone.swift"))
        write("scripts/mac-shell/same.swift", "// same\n", checkout)
        write("scripts/mac-shell/other.m", "// other\n", checkout)
        write("scripts/mac-shell/changed.swift", "does not even compile\n", checkout)
        git("add", "--all")
        git("commit", "--quiet", "--message", "next")
        # The index still says what was committed. What lies in the folder is what gets compiled.
        write("Sources/A/edited after the checkout.swift", "let a = 3\n", checkout)
        row("ci-mtimes.py: restore", run("restore").returncode, 0)
        row("ci-mtimes.py: a file with the content that was built gets its time stamp back", stamp("Sources/A/same.swift"), then)
        # Later than the cached build, not merely later than its own earlier self: another job may have built after this one checked out.
        with open(os.path.join(folder, ".build/ci-mtimes.tsv"), encoding="utf-8") as handle:
            built = int(handle.readline().split("\t")[1]) // 10 ** 9 + 1
        for name in ["changed", "same length", "new", "edited after the checkout"]:
            row(f"ci-mtimes.py: {name}: counts as changed, and as newer than anything in the cache", stamp(f"Sources/A/{name}.swift") >= built, True)
        row("ci-mtimes.py: what no build reads is left alone", stamp("docs/prose.md"), checkout)
        row("ci-mtimes.py: only the helper tools whose source is what they were made of are left, whatever the clocks say",
            sorted(os.listdir(os.path.join(folder, ".build/mac-shell"))), ["other", "same"])

        for what, damage in [("missing", None), ("cut off", "0123\t"), ("not a note at all", "\x00\x01 nonsense\n")]:
            os.utime(os.path.join(folder, "Sources/A/same.swift"), (checkout, checkout))
            if os.path.exists(os.path.join(folder, ".build/ci-mtimes.tsv")):
                os.remove(os.path.join(folder, ".build/ci-mtimes.tsv"))
            if damage is not None:
                with open(os.path.join(folder, ".build/ci-mtimes.tsv"), "w", encoding="utf-8") as handle:
                    handle.write(damage)
            write(".build/mac-shell/same", "a tool\n", checkout)
            row(f"ci-mtimes.py: the note is {what}: every file counts as changed, no helper tool stays, and that is no failure",
                (run("restore").returncode, stamp("Sources/A/same.swift") > checkout, os.listdir(os.path.join(folder, ".build/mac-shell"))), (0, True, []))
        with open(os.path.join(folder, ".build/ci-mtimes.tsv"), "w", encoding="utf-8") as handle:
            handle.write(f"built\t{(int(time.time()) + 3600) * 10 ** 9}\t\n")
        run("restore")
        row("ci-mtimes.py: the clock of the Mac that built was an hour ahead: still newer", stamp("Sources/A/changed.swift") > time.time() + 3599, True)
        run("record")
        with open(os.path.join(folder, ".build/ci-mtimes.tsv"), encoding="utf-8") as handle:
            row("ci-mtimes.py: a build upon that one is no older than it", int(handle.readline().split("\t")[1]) // 10 ** 9 > time.time() + 3590, True)
        row("ci-mtimes.py: no such word", run("forget").returncode != 0, True)

        # ci-build.sh, with stand-ins for the compilers: swift build passes, and no helper tool compiles any more.
        for name in ["pointer", "curtain"]:
            write(f"scripts/mac-shell/{name}.swift", "does not compile\n", checkout)
            write(f".build/mac-shell/{name}", "the cached tool\n", then)
            os.chmod(os.path.join(folder, f".build/mac-shell/{name}"), 0o755)
        write("scripts/mac-shell/vdisplay.m", "fine\n", then)
        write(".build/mac-shell/vdisplay", "the cached tool\n", checkout)
        os.chmod(os.path.join(folder, ".build/mac-shell/vdisplay"), 0o755)
        write("Package.swift", "", then)
        write("scripts/mac-shell/compile-tools.sh", "#!/bin/sh\nmkdir -p mac-shell\nexit $#\n", then)
        write("bin/swift", "#!/bin/sh\necho Build complete\n", then)
        for path in ["scripts/mac-shell/compile-tools.sh", "bin/swift"]:
            os.chmod(os.path.join(folder, path), 0o755)
        built = subprocess.run([BASH, os.path.join(HERE, "ci-build.sh")], cwd=folder, capture_output=True, text=True, check=False,
                               env={**os.environ, "PATH": os.path.join(folder, "bin") + os.pathsep + os.environ["PATH"]})
        row("ci-build.sh: a helper tool that no longer compiles is gone, not replaced by the cached one; one that is current stays",
            (built.returncode, sorted(os.listdir(os.path.join(folder, ".build/mac-shell")))), (0, ["vdisplay"]))


# MARK: ci-mac-shell.sh and run.sh

def check_mac_shell_batch():
    """Several scripts on one Mac: each gets its turn, and nothing of one passes for another's."""
    runner = os.path.join(HERE, "ci-mac-shell.sh")
    scripts = {
        "fine.sh": "echo fine; echo picture > mac-shell/fine.png; echo '3 passed, 0 failed'\n",
        "fails.sh": "echo fails; ls mac-shell | grep -c png; echo log > mac-shell/fails.log; exit 1\n",
        "worse.sh": "exit 7\n",
        "hangs.sh": "trap 'echo cleaned up; exit 143' TERM\necho hangs\nsleep 60 & wait\n",
        "leaves.sh": "(sleep 20 &)\necho left\n",
        "part.sh": "echo part $MAC_SHELL_PART of $MAC_SHELL_PARTS\n",
    }

    def tried(*names, limit="60", **more):
        with tempfile.TemporaryDirectory(prefix="tooling-") as folder:
            for name, text in scripts.items():
                with open(os.path.join(folder, name), "w", encoding="utf-8") as handle:
                    handle.write(text)
            began = time.time()
            done = subprocess.run([BASH, runner, *names], cwd=folder, env={**os.environ, "MAC_SHELL_LIMIT": limit, **more}, capture_output=True,
                                  text=True, check=False, timeout=90)
            left = {}
            for where, _folders, files in os.walk(os.path.join(folder, "mac-shell")):
                for name in files:
                    with open(os.path.join(where, name), encoding="utf-8") as handle:
                        left[os.path.relpath(os.path.join(where, name), os.path.join(folder, "mac-shell"))] = handle.read()
            return done.returncode, left, done.stdout, time.time() - began

    code, left, said, _ = tried("fails.sh")
    row("ci-mac-shell.sh: one script: its exit code, and the files where they have always been",
        (code, sorted(left), left["exit-code.txt"]), (1, ["exit-code.txt", "fails.log", "output.txt"], "1\n"))
    row("ci-mac-shell.sh: one script: what it said, between the header and the exit code",
        (left["output.txt"].splitlines()[0][:25], left["output.txt"].splitlines()[1:]), ("# mac-shell: fails.sh at ", ["fails", "0", "exit code 1"]))
    row("ci-mac-shell.sh: the exit code is an annotation", "::notice title=mac-shell exit code::fails.sh exited with 1" in said, True)

    code, left, said, _ = tried("fine.sh", "fails.sh", "nothing.sh", "worse.sh", "fine.sh")
    row("ci-mac-shell.sh: several: the first exit code that is not 0", (code, left["exit-code.txt"]), (1, "1\n"))
    row("ci-mac-shell.sh: several: a folder for each, also for one that ran twice, failed, or is not there", sorted(left), sorted(
        ["exit-code.txt", "summary.txt", "1-fine/exit-code.txt", "1-fine/output.txt", "1-fine/fine.png", "2-fails/exit-code.txt", "2-fails/output.txt",
         "2-fails/fails.log", "3-nothing/exit-code.txt", "3-nothing/output.txt", "4-worse/exit-code.txt", "4-worse/output.txt",
         "5-fine/exit-code.txt", "5-fine/output.txt", "5-fine/fine.png"]))
    row("ci-mac-shell.sh: several: a script finds nothing of the one before in mac-shell/", left["2-fails/output.txt"].splitlines()[1:3], ["fails", "0"])
    row("ci-mac-shell.sh: several: each one's own exit code",
        [left[f"{name}/exit-code.txt"].strip() for name in ("1-fine", "2-fails", "3-nothing", "4-worse", "5-fine")], ["0", "1", "2", "7", "0"])
    row("ci-mac-shell.sh: several: a line for each in the summary", [line.split()[:4] for line in left["summary.txt"].splitlines()],
        [["1", "fine.sh", "exit", "0"], ["2", "fails.sh", "exit", "1"], ["3", "nothing.sh", "exit", "2"], ["4", "worse.sh", "exit", "7"],
         ["5", "fine.sh", "exit", "0"]])
    row("ci-mac-shell.sh: all pass", tried("fine.sh", "fine.sh")[0], 0)

    # Three seconds, not one: the limit is the next script's too, and on a busy machine one that does nothing has taken longer than a second over it.
    code, left, _, _ = tried("hangs.sh", "fine.sh", limit="3")
    row("ci-mac-shell.sh: one that hangs is stopped, may clean up, and the next one runs",
        (code, left["1-hangs/output.txt"].splitlines()[-2:], left["2-fine/exit-code.txt"]), (124, ["cleaned up", "exit code 124"], "0\n"))
    code, left, _, took = tried("leaves.sh", "fine.sh")
    row("ci-mac-shell.sh: what a script leaves running holds nobody up", (code, took < 10), (0, True))
    row("ci-mac-shell.sh: no script at all", tried()[0], 64)

    def parts(*names, **more):
        left = tried(*names, **more)[1]
        return [text.splitlines()[1] for path, text in sorted(left.items()) if path.endswith("output.txt")]

    row("ci-mac-shell.sh: one script is part 1 of 1", parts("part.sh"), ["part 1 of 1"])
    row("ci-mac-shell.sh: three on one Mac", parts("part.sh", "part.sh", "part.sh"), ["part 1 of 3", "part 2 of 3", "part 3 of 3"])
    row("ci-mac-shell.sh: one that is not there keeps its number", parts("part.sh", "nothing.sh", "part.sh")[::2], ["part 1 of 3", "part 3 of 3"])
    row("ci-mac-shell.sh: the second of two Macs with five scripts between them plays places 2 and 4",
        parts("part.sh", "part.sh", MAC_SHELL_SHARE="2/2", MAC_SHELL_PARTS="5"), ["part 2 of 5", "part 4 of 5"])
    row("ci-mac-shell.sh: the first plays 1, 3 and 5",
        parts("part.sh", "part.sh", "part.sh", MAC_SHELL_SHARE="1/2", MAC_SHELL_PARTS="5"), ["part 1 of 5", "part 3 of 5", "part 5 of 5"])
    row("ci-mac-shell.sh: one script given to three Macs: the third", parts("part.sh", MAC_SHELL_SHARE="3/3", MAC_SHELL_PARTS="3"), ["part 3 of 3"])
    row("ci-mac-shell.sh: a share that is none", parts("part.sh", MAC_SHELL_SHARE="x"), ["part 1 of 1"])

    # run.sh in a checkout of its own whose origin is a folder beside it, with a stand-in for `gh` that notes every call. GitHub allows an account
    # 5,000 calls an hour, and copies of this script have used them up: how many it makes is part of what it does.
    world = tempfile.TemporaryDirectory(prefix="tooling-")
    checkout, origin = os.path.join(world.name, "checkout"), os.path.join(world.name, "origin.git")

    def git(*arguments, where=checkout):
        return subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.com", *arguments], cwd=where, capture_output=True, text=True,
                              check=True).stdout.strip()

    os.makedirs(os.path.join(checkout, "scripts", "mac-shell"))
    for name in ("mac-shell/run.sh", "mac-shell/preflight.sh", "mac-queue.py"):
        shutil.copy(os.path.join(HERE, name), os.path.join(checkout, "scripts", name))
    for name in ["a", "b", "c", "d", "e", "e2e-drag", *map(str, range(9))]:
        with open(os.path.join(checkout, f"{name}.sh"), "w", encoding="utf-8") as handle:
            handle.write("echo hello\n")
    subprocess.run(["git", "init", "--quiet", "--bare", origin], check=True)
    git("init", "--quiet", "--initial-branch=elsewhere")
    git("add", "--all")
    git("commit", "--quiet", "--message", "scripts")
    git("remote", "add", "origin", origin)
    git("push", "--quiet", "origin", "HEAD:refs/heads/feat/x")

    # The stand-in: $CALLS gets a line for every call. A dispatch is noted in $NOTED and, unless $GOES says otherwise, refused.
    stand_in = r'''#!/bin/bash
echo "$*" >> "$CALLS"
case "$*" in
  *dispatches*) printf '%s\n' "$@" > "$NOTED"; [ -n "${GOES:-}" ] || exit 1; eval "$GOES" ;;
  *rate_limit*) echo '{}' ;;
  *"runs?event=workflow_dispatch"*) if [ -f "$NOTED" ]; then echo 7; else echo 0; fi ;;
  *actions/runs/7*) echo "${STATUS:-in_progress}" ;;
  *) echo 0 ;;
esac
'''
    with open(os.path.join(world.name, "gh"), "w", encoding="utf-8") as handle:
        handle.write(stand_in)
    os.chmod(os.path.join(world.name, "gh"), 0o755)

    def ran(*arguments, **more):
        noted, calls = os.path.join(world.name, "noted"), os.path.join(world.name, "calls")
        for path in (noted, calls):
            if os.path.exists(path):
                os.remove(path)
        environment = {**os.environ, "PATH": world.name + os.pathsep + os.environ["PATH"], "NOTED": noted, "CALLS": calls, "MAC_SHELL_WORKFLOW_REF": "home",
                       "ARBOR_MAC_PRIORITY": "1", "ORIGIN": origin, **more}
        environment.pop("ARBOR_MAC_QUEUE_CACHE", None)
        done = subprocess.run([BASH, "scripts/mac-shell/run.sh", *arguments], cwd=checkout, env=environment, capture_output=True, text=True, check=False,
                              timeout=120)
        made = []
        if os.path.exists(calls):
            with open(calls, encoding="utf-8") as handle:
                made = handle.read().splitlines()
        return done, noted, made

    NOT_STARTED = [None] * 4

    def started(*arguments):
        done, noted, _ = ran(*arguments)
        if not os.path.exists(noted):
            # Four of nothing, so that a row that looks into it comes out wrong and says so, instead of ending everything with a traceback.
            return done.returncode, NOT_STARTED, {}
        with open(noted, encoding="utf-8") as handle:
            asked = dict(line.strip().split("=", 1) for line in handle if "=" in line)
        return done.returncode, [asked.get(key) for key in ("ref", "inputs[ref]", "inputs[script]", "inputs[macs]")], asked

    row("run.sh: one script", started("a.sh", "feat/x")[:2], (97, ["home", "feat/x", "a.sh", ""]))
    row("run.sh: which build is not said unless it is the release build: an older workflow would refuse the start", "inputs[configuration]" in started("a.sh", "feat/x")[2], False)
    row("run.sh: --release: said, and under a tag of its own", [started("--release", "a.sh", "feat/x")[2].get(key) for key in ("inputs[configuration]", "inputs[tag]")],
        ["release", "feat-x.a-rel"])
    row("run.sh: the plain run's tag is as it was", started("a.sh", "feat/x")[2].get("inputs[tag]"), "feat-x.a")
    row("run.sh: ARBOR_CONFIGURATION=release says the same", (lambda noted: "inputs[configuration]=release" in open(noted, encoding="utf-8").read())(
        ran("a.sh", "feat/x", ARBOR_CONFIGURATION="release")[1]), True)
    row("run.sh: any other configuration starts nothing", (lambda done, noted, _: (done.returncode, os.path.exists(noted)))(*ran("a.sh", "feat/x", ARBOR_CONFIGURATION="fast")), (97, False))
    row("run.sh: --bare builds nothing, so not with --release", started("--bare", "--release", "a.sh", "feat/x")[:2], (97, NOT_STARTED))
    row("run.sh: three scripts go to one Mac", started("a.sh", "./b.sh", "c.sh", "feat/x")[:2], (97, ["home", "feat/x", "a.sh b.sh c.sh", ""]))
    row("run.sh: five are too many for one", started("a.sh", "b.sh", "c.sh", "d.sh", "e.sh", "feat/x")[1][3], '["a.sh c.sh e.sh","b.sh d.sh"]')
    row("run.sh: --macs 3", started("--macs", "3", "a.sh", "b.sh", "c.sh", "d.sh", "feat/x")[1][3], '["a.sh d.sh","b.sh","c.sh"]')
    row("run.sh: more Macs than scripts", started("--macs", "9", "a.sh", "b.sh", "feat/x")[1][3], '["a.sh","b.sh"]')
    row("run.sh: one script for three Macs to share", started("--macs", "3", "a.sh", "feat/x")[1][3], '["a.sh","a.sh","a.sh"]')
    row("run.sh: the ordinary Mac, set up, unless something else is asked for",
        [started("a.sh", "feat/x")[2].get(key) for key in ("inputs[runner]", "inputs[bare]")], ["macos-26", "false"])
    row("run.sh: --on and --bare, and a tag of its own for another kind of Mac",
        [started("--on", "macos-15-intel", "--bare", "e2e-drag.sh", "feat/x")[2].get(key) for key in ("inputs[runner]", "inputs[bare]", "inputs[tag]")],
        ["macos-15-intel", "true", "feat-x.e2e-drag-15-intel"])
    row("run.sh: too few Macs", started("--macs", "2", *[f"{n}.sh" for n in range(9)], "feat/x")[:2], (97, NOT_STARTED))
    row("run.sh: a slip in a script's name does not pass for a branch", started("a.sh", "b.sj", "c.sh")[:2], (97, NOT_STARTED))
    row("run.sh: no script", started("feat/x")[:2], (97, NOT_STARTED))
    row("run.sh: a path that could be more than a path", started("a;b.sh", "feat/x")[:2], (97, NOT_STARTED))
    row("run.sh: --macs 0", started("--macs", "0", "a.sh", "feat/x")[:2], (97, NOT_STARTED))
    row("run.sh: a branch GitHub does not have, found out without a call", (lambda done, _, made: (done.returncode, made))(*ran("a.sh", "feat/none")), (97, []))
    row("run.sh: a script GitHub does not have at that branch, likewise", (lambda done, _, made: (done.returncode, made))(*ran("z.sh", "feat/x")), (97, []))

    # Whose turn it is, with a stand-in for mac-queue.py that ends as told.
    real_queue = os.path.join(checkout, "scripts", "mac-queue.py")
    with open(real_queue, encoding="utf-8") as handle:
        kept_queue = handle.read()
    with open(real_queue, "w", encoding="utf-8") as handle:
        handle.write('import os, sys\nopen(os.environ["NOTED"] + ".asked", "w").write(" ".join(sys.argv[1:]))\nprint("three are waiting")\nsys.exit(int(os.environ["TURN"]))\n')
    for what, priority, turn, expected in [
        ("it is its turn", "3", "0", (97, True)),
        ("it is not", "3", "4", (98, False)),
        ("the queue cannot be read, as when GitHub refuses: that is no yes", "3", "1", (98, False)),
        ("the same at priority 2", "2", "1", (98, False)),
        ("the look at the queue falls over", "3", "120", (98, False)),
        ("priority 1 is held back too, by what holds everybody back: a train", "1", "4", (98, False)),
        ("priority 1: it is its turn", "1", "0", (97, True)),
        ("priority 1 alone is not held up by what cannot be found out", "1", "1", (97, True)),
        ("nor by a look that falls over", "1", "120", (97, True)),
    ]:
        done, noted, _ = ran("a.sh", "feat/x", ARBOR_MAC_PRIORITY=priority, TURN=turn, MAC_SHELL_TIMEOUT="0", MAC_SHELL_POLL="0")
        row(f"run.sh: whose turn: {what}", (done.returncode, os.path.exists(noted)), expected)
    asked = []
    for priority in "123":
        _, noted, _ = ran("a.sh", "feat/x", ARBOR_MAC_PRIORITY=priority, TURN="0", MAC_SHELL_TAG="t")
        with open(noted + ".asked", encoding="utf-8") as handle:
            asked.append(handle.read().split("--turn ")[1])
    row("run.sh: whose turn: it says for which branch and under which tag; priority 1 asks only what is known already, which costs no call", asked,
        ["1 --for feat/x --tag t --known", "2 --for feat/x --tag t", "3 --for feat/x --tag t"])
    # While work goes to main, with a stand-in for public-check.py --rules that ends as told.
    rules = os.path.join(checkout, "scripts", "public-check.py")
    with open(rules, "w", encoding="utf-8") as handle:
        handle.write('import os, sys\nprint("✘ PUSHES ARE HELD until main is 0123456. A train is open.\\nIt ends by itself.")\nsys.exit(int(os.environ["HELD"]))\n')
    for what, priority, held, expected in [
        ("its turn, but pushes are held: no Mac is asked for either, and it says why", "3", "1", (98, False, True)),
        ("nothing is held", "3", "0", (97, True, False)),
        ("nobody can tell: the queue decides", "3", "2", (97, True, False)),
        ("priority 1 does not ask", "1", "1", (97, True, False)),
    ]:
        done, noted, _ = ran("a.sh", "feat/x", ARBOR_MAC_PRIORITY=priority, TURN="0", HELD=held, MAC_SHELL_TIMEOUT="0", MAC_SHELL_POLL="0")
        row(f"run.sh: a hold: {what}", (done.returncode, os.path.exists(noted), "PUSHES ARE HELD until main is 0123456. A train is open." in done.stdout + done.stderr), expected)
    os.remove(rules)
    with open(real_queue, "w", encoding="utf-8") as handle:
        handle.write(kept_queue)

    # A whole run. The "Mac" pushes its output a few seconds after the dispatch, as the workflow's last deed but a few.
    pushes = '''( sleep 3; w=$(mktemp -d); cd "$w"; git init -q; echo 0 > exit-code.txt; echo said > output.txt; git add -A
      git -c user.name=m -c user.email=m@example.com commit -q -m "mac-shell: output of a.sh at 1234567 (run 7)"
      git push -q --force "$ORIGIN" HEAD:refs/heads/mac-shell-out/t ) > /dev/null 2>&1 &'''
    done, _, made = ran("a.sh", "feat/x", GOES=pushes, MAC_SHELL_TAG="t")
    polls = [call for call in made if call.startswith("api repos/") and call.endswith("actions/runs/7 --jq .status")]
    row("run.sh: a whole run: it ends when the output branch appears, with the script's exit code", (done.returncode, "exit code: 0" in done.stdout), (0, True))
    row("run.sh: a whole run: GitHub was not asked once whether it had ended", polls, [])
    row("run.sh: a whole run: ten calls at most", len(made) <= 10, True)
    shutil.rmtree(os.path.join(checkout, ".mac-shell"), ignore_errors=True)
    world.cleanup()


# MARK: preflight.sh

def check_preflight():
    """What has not been shown on Linux takes no Mac, and what cannot be told counts as not shown."""
    with tempfile.TemporaryDirectory(prefix="tooling-") as folder:
        def git(*arguments):
            return subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.com", *arguments], cwd=folder, capture_output=True,
                                  text=True, check=True).stdout.strip()

        def write(path, text, mode=0o644):
            os.makedirs(os.path.dirname(os.path.join(folder, path)), exist_ok=True)
            with open(os.path.join(folder, path), "w", encoding="utf-8") as handle:
                handle.write(text)
            os.chmod(os.path.join(folder, path), mode)

        def commit(files):
            for path, text in files.items():
                write(path, text)
            git("add", "--all")
            git("commit", "--quiet", "--allow-empty", "--message", "next")

        def flight(*arguments, swift="exit 0", trunk="trunk", path=True):
            write("bin/swift", f"#!/bin/sh\necho swift \"$@\" >> \"{folder}/ran\"\n{swift}\n", 0o755)
            write("bin/make", f"#!/bin/sh\necho make \"$@\" >> \"{folder}/ran\"\n", 0o755)
            if os.path.exists(os.path.join(folder, "ran")):
                os.remove(os.path.join(folder, "ran"))
            environment = {**os.environ, "ARBOR_TRUNK": trunk}
            if path:
                environment["PATH"] = os.path.join(folder, "bin") + os.pathsep + os.environ["PATH"]
            done = subprocess.run([BASH, "scripts/mac-shell/preflight.sh", *arguments], cwd=folder, env=environment, capture_output=True, text=True,
                                  check=False)
            ran = []
            if os.path.exists(os.path.join(folder, "ran")):
                with open(os.path.join(folder, "ran"), encoding="utf-8") as handle:
                    ran = handle.read().split("\n")[:-1]
            return done.returncode, ran, done.stdout + done.stderr

        library = 'source "$(dirname "$0")/lib.sh"\n'
        for name in ("preflight.sh", "run.sh"):
            shutil.copy(os.path.join(HERE, "mac-shell", name), os.path.join(folder, name))
        git("init", "--quiet", "--initial-branch=trunk")
        write(".gitignore", "/bin/\n/ran\n/.mac-shell/\n/noted\n")
        for name in ("preflight.sh", "run.sh"):
            os.makedirs(os.path.join(folder, "scripts/mac-shell"), exist_ok=True)
            shutil.move(os.path.join(folder, name), os.path.join(folder, "scripts/mac-shell", name))
        shutil.copy(os.path.join(HERE, "mac-queue.py"), os.path.join(folder, "scripts/mac-queue.py"))
        # The stand-in for the rehearsal does what the script's second line says.
        write("scripts/mac-shell/rehearse.sh", '#!/bin/bash\necho rehearse "$1" >> ran\neval "$(sed -n 2p "$1" | cut -c 3-)"\n', 0o755)
        write("scripts/mac-shell/lib.sh", "# the library\n")
        # The stand-in for the lint minds one word.
        write("scripts/lint-mac-shell.py", 'import sys\nopen("ran", "a").write("lint " + sys.argv[1] + "\\n")\nsys.exit("HARM" in open(sys.argv[1]).read())\n')
        write("scripts/typecheck-mac/stub.swift", "")
        write("Tests/T.swift", "")
        write("Package.swift", "")
        commit({"Sources/A.swift": "let a = 1\n", "scripts/mac-shell/old.sh": library + "# exit 2\n"})
        git("checkout", "--quiet", "-b", "work")
        old, new = "scripts/mac-shell/old.sh", "scripts/mac-shell/new.sh"

        row("preflight.sh: the trunk's code and a script of the trunk's owe nothing, whether or not it can be rehearsed", flight("--check", old)[0], 0)
        commit({"scripts/mac-shell/new.sh": library + "# exit 0\n"})
        row("preflight.sh: a new script is owed a rehearsal", flight("--check", new)[:2], (1, []))
        if sys.platform != "linux":
            row("preflight.sh: only on Linux", flight(new)[0], 2)
            return
        row("preflight.sh: it is rehearsed, and the code, being the trunk's, is left alone", flight(new)[:2], (0, [f"lint {new}", f"rehearse {new}"]))
        row("preflight.sh: which is noted", flight("--check", new)[0], 0)
        row("preflight.sh: and not done twice", flight(new)[:2], (0, []))
        for what, line, expected in [
            ("a check came out ✘: it got to its end", "exit 1", 0),
            ("it broke off", "exit 2", 1),
            ("it was killed", "kill -9 $$", 1),
            ("the fake Mac lacks something", "exit 64", 0),
            ("it declines there", "exit 77", 0),
            ("a function bash does not know, and on it went", "echo 'x.sh: line 4: arbor_strat: command not found'; exit 1", 1),
            ("a variable nobody set", "echo 'x.sh: line 5: W1: unbound variable'; exit 0", 1),
            ("a command Arbor does not know", "echo 'unknown command `dokc`; try `help`'; exit 1", 1),
        ]:
            commit({"scripts/mac-shell/new.sh": library + f"# {line}\n"})
            row(f"preflight.sh: changed, so rehearsed again: {what}", (flight("--check", new)[0], flight(new)[0], flight("--check", new)[0]),
                (1, expected, expected))
        commit({"scripts/mac-shell/new.sh": "if true; then\n"})
        row("preflight.sh: what bash cannot even read", flight(new)[:2], (1, []))
        commit({"scripts/mac-shell/new.sh": "echo hello\n# exit 2\n"})
        row("preflight.sh: a script that is not built on lib.sh is read and linted, no more", flight(new)[:2], (0, [f"lint {new}"]))
        commit({"scripts/mac-shell/new.sh": "echo HARM\n"})
        row("preflight.sh: what the lint minds takes no Mac, though the code is the trunk's and `make lint` is not run", (flight(new)[:2], flight("--check", new)[0]), ((1, [f"lint {new}"]), 1))
        # Built on lib.sh through another file.
        middle, upon = "scripts/mac-shell/middle.sh", "scripts/mac-shell/upon.sh"
        through = 'source "$(dirname "${BASH_SOURCE[0]}")/middle.sh"\n'
        commit({middle: library + "# exit 0\n", upon: through + "# exit 2\n"})
        row("preflight.sh: a script built on lib.sh through another file is rehearsed as well", flight(upon)[:2], (1, [f"lint {upon}", f"rehearse {upon}"]))
        commit({upon: through + "# exit 0\n"})
        row("preflight.sh: and passes when it gets to its end", (flight(upon)[0], flight("--check", upon)[0]), (0, 0))
        git("branch", "--force", "with-both")
        row("preflight.sh: both are the trunk's: nothing is owed", flight("--check", upon, trunk="with-both")[0], 0)
        shutil.rmtree(os.path.join(folder, ".mac-shell"))
        commit({middle: library + "# exit 0\n# changed\n"})
        row("preflight.sh: the file in the middle has changed: the script upon it is no longer what the trunk has", flight("--check", upon, trunk="with-both")[0], 1)
        commit({"scripts/mac-shell/round.sh": 'source "$(dirname "$0")/round.sh"\n# exit 0\n'})
        row("preflight.sh: a script that reads itself in does not go round for ever", flight("scripts/mac-shell/round.sh")[0], 0)
        git("reset", "--quiet", "--hard", "HEAD~5")
        commit({"scripts/mac-shell/lib.sh": "# the library, changed\n"})
        row("preflight.sh: the library has changed, so the trunk's script is owed a rehearsal too", flight("--check", old)[0], 1)
        git("reset", "--quiet", "--hard", "HEAD~1")

        commit({"Sources/A.swift": "let a = 2\n"})
        row("preflight.sh: other code than the trunk's is owed everything", flight("--check", new)[0], 1)
        row("preflight.sh: the tests fail: nothing is noted", (flight(new, swift='[ "$1" != test ]')[0], flight("--check", new)[0]), (1, 1))
        row("preflight.sh: lint, build, type-check, tests, in that order", flight(new)[:2],
            (0, ["make lint", "swift build", "make typecheck-mac", "swift test"]))
        row("preflight.sh: which is noted too", flight("--check", new)[0], 0)
        commit({"docs/x": "prose\n"})
        row("preflight.sh: another commit with the same code and scripts owes nothing", flight("--check", new)[0], 0)
        row("preflight.sh: no trunk to compare with: the note still counts", flight("--check", new, trunk="nowhere")[0], 0)
        shutil.rmtree(os.path.join(folder, ".mac-shell"))
        git("checkout", "--quiet", "trunk")
        row("preflight.sh: no trunk to compare with: the code is owed", flight("--check", old, trunk="nowhere")[0], 1)
        git("checkout", "--quiet", "work")
        row("preflight.sh: no swift here", flight(new, path=False)[0] if not shutil.which("swift") else 2, 2)
        write("Sources/A.swift", "let a = 3\n")
        row("preflight.sh: what is not committed is not what the Mac would run", flight("--check", new)[0], 1)
        git("checkout", "--quiet", "--", "Sources/A.swift")

        # run.sh in front of it, with a stand-in for `gh` that notes what was started.
        write("bin/gh", '#!/bin/sh\ncase "$*" in *dispatches*) printf "%s\\n" "$@" > noted; exit 1;; *commits/*) git rev-parse HEAD;; *) echo 0;; esac\n', 0o755)
        subprocess.run(["git", "init", "--quiet", "--bare", os.path.join(folder, "bin", "origin.git")], check=True)
        git("remote", "add", "origin", os.path.join(folder, "bin", "origin.git"))

        def started(*arguments, swift=True):
            flight("--check", new)  # writes the stand-ins
            git("push", "--quiet", "--force", "origin", "HEAD:refs/heads/work")
            if not swift:
                os.remove(os.path.join(folder, "bin/swift"))
            if os.path.exists(os.path.join(folder, "noted")):
                os.remove(os.path.join(folder, "noted"))
            environment = {**os.environ, "PATH": os.path.join(folder, "bin") + os.pathsep + os.environ["PATH"], "ARBOR_TRUNK": "trunk",
                           "MAC_SHELL_WORKFLOW_REF": "home", "ARBOR_MAC_PRIORITY": "1"}
            done = subprocess.run([BASH, "scripts/mac-shell/run.sh", *arguments], cwd=folder, env=environment, capture_output=True, text=True, check=False)
            asked = {}
            if os.path.exists(os.path.join(folder, "noted")):
                with open(os.path.join(folder, "noted"), encoding="utf-8") as handle:
                    asked = dict(line.strip().split("=", 1) for line in handle if "=" in line)
            return done.returncode, asked.get("inputs[script]"), asked.get("inputs[unchecked]")

        if not shutil.which("swift"):
            row("run.sh: not through the pre-flight, and no swift here: nothing is started", started(new, swift=False), (96, None, None))
        row("run.sh: all the same, with the reason for everybody to read", started("--no-preflight", "the fake Mac has no `tiling`; see #3", new, swift=False),
            (97, new, "the fake Mac has no  tiling   see  3"))
        commit({"scripts/mac-shell/new.sh": library + "# exit 2\n"})
        row("run.sh: where there is a swift it runs the pre-flight itself, and starts nothing when that fails", started(new), (96, None, None))
        commit({"scripts/mac-shell/new.sh": library + "# exit 0\n"})
        row("run.sh: and starts the run when it passes", started(new), (97, new, ""))
        shutil.rmtree(os.path.join(folder, ".git"))
        row("preflight.sh: where Git does not work nothing counts as shown", (flight("--check", new)[0], flight(new)[0]), (2, 2))


# MARK: ci-build-key.sh

def check_ci_build_key():
    """A build's name: there is always one, and it differs whenever what goes into the build does. A script that fails costs every run its cache, quietly."""
    with tempfile.TemporaryDirectory(prefix="tooling-") as folder:
        def git(*arguments):
            subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.com", *arguments], cwd=folder, capture_output=True, check=True)

        def write(path, text, mode=0o644):
            os.makedirs(os.path.dirname(os.path.join(folder, path)), exist_ok=True)
            with open(os.path.join(folder, path), "w", encoding="utf-8") as handle:
                handle.write(text)
            os.chmod(os.path.join(folder, path), mode)

        for name in ("sw_vers", "xcodebuild", "swift"):
            write(f"bin/{name}", f'#!/bin/sh\necho {name} "${{VERSION_OF_{name}:-1}}"\n', 0o755)
        write(".gitignore", "/bin/\n")
        for path in ("Package.swift", "Sources/A.swift", "Tests/T.swift", "scripts/mac-shell/pointer.swift", "scripts/mac-shell/compile-tools.sh", "docs/x.md"):
            write(path, "one\n")
        git("init", "--quiet")
        git("add", "--all")
        git("commit", "--quiet", "--message", "one")

        def key(kind, **more):
            environment = {name: value for name, value in os.environ.items() if not name.startswith("ARBOR_TEST_SOURCES_")}
            done = subprocess.run([BASH, os.path.join(HERE, "ci-build-key.sh"), kind], cwd=folder, capture_output=True, text=True, check=False,
                                  env={**environment, "PATH": os.path.join(folder, "bin") + os.pathsep + os.environ["PATH"], **more})
            lines = dict(line.split("=", 1) for line in done.stdout.splitlines() if "=" in line)
            return done.returncode, lines.get("key")

        def made(kind, **more):
            done = subprocess.run([BASH, os.path.join(HERE, "ci-build-key.sh"), kind], cwd=folder, capture_output=True, text=True, check=False,
                                  env={**os.environ, "PATH": os.path.join(folder, "bin") + os.pathsep + os.environ["PATH"], **more})
            return next((line[5:] for line in done.stdout.splitlines() if line.startswith("made=")), "")

        def takes(kind):
            """What a job of that kind takes for all it needs (a pattern), and the beginnings of the names it would build upon."""
            done = subprocess.run([BASH, os.path.join(HERE, "ci-build-key.sh"), kind], cwd=folder, capture_output=True, text=True, check=False,
                                  env={**os.environ, "PATH": os.path.join(folder, "bin") + os.pathsep + os.environ["PATH"]})
            lines = done.stdout.splitlines()
            return next(line[7:] for line in lines if line.startswith("enough=")), lines[lines.index("or<<.") + 1:lines.index(".")]

        def changed(path, kind, text="two\n"):
            before = key(kind)[1]
            write(path, text)
            git("add", "--all")
            git("commit", "--quiet", "--message", path)
            return key(kind)[1] != before

        for kind in ("products", "tests", "release"):
            row(f"ci-build-key.sh: {kind}: there is a name", (key(kind)[0], bool(key(kind)[1])), (0, True))
            row(f"ci-build-key.sh: {kind}: the same twice", key(kind) == key(kind), True)
            for name in ("sw_vers", "xcodebuild", "swift"):
                row(f"ci-build-key.sh: {kind}: another {name}, another name", key(kind) != key(kind, **{f"VERSION_OF_{name}": "2"}), True)
        row("ci-build-key.sh: with and without the tests are two names", key("products")[1] != key("tests")[1], True)
        row("ci-build-key.sh: it says in plain words what the first part of the name stands for, so that two runs can be held side by side",
            [made("products") == made("release"), made("products") != made("products", VERSION_OF_xcodebuild="2"), made("products") != made("products", ImageVersion="20261015.2"),
             "image 20261015.2" in made("products", ImageVersion="20261015.2"), "\n" in made("products")], [True, True, True, True, False])
        row("ci-build-key.sh: a release build has a name of its own", len({key(kind)[1] for kind in ("products", "tests", "release")}), 3)
        row("ci-build-key.sh: it takes its own for all it needs; a build with the tests will do for one without, as it did",
            [fnmatch.fnmatchcase(key(has)[1], takes(wants)[0]) for wants, has in (("release", "release"), ("products", "tests"), ("products", "products"))], [True] * 3)
        row("ci-build-key.sh: neither a debug build passes for a release build nor the other way round, and neither is built upon the other",
            [(wants, has) for wants, has in (("release", "products"), ("release", "tests"), ("products", "release"), ("tests", "release"))
             if fnmatch.fnmatchcase(key(has)[1], takes(wants)[0]) or any(key(has)[1].startswith(start) for start in takes(wants)[1])], [])
        row("ci-build-key.sh: a release build is built upon nothing at all: these very sources, or from the beginning", takes("release")[1], [])
        row("ci-build-key.sh: the control: a build without the tests is built upon one with them", any(key("tests")[1].startswith(start) for start in takes("products")[1]), True)
        row("ci-build-key.sh: which test files are compiled is part of the name of a build with tests",
            key("tests") != key("tests", ARBOR_TEST_SOURCES_T="T.swift"), True)
        row("ci-build-key.sh: and no part of the name of one without", key("products") == key("products", ARBOR_TEST_SOURCES_T="T.swift"), True)
        for path in ("Package.swift", "Sources/A.swift", "scripts/mac-shell/pointer.swift", "scripts/mac-shell/compile-tools.sh"):
            row(f"ci-build-key.sh: {path} changes: another name, with the tests and without", (changed(path, "products"), changed(path, "tests", "three\n")), (True, True))
            row(f"ci-build-key.sh: {path} changes: and of the release build", changed(path, "release", "four\n"), True)
        row("ci-build-key.sh: a test changes: another name with the tests, the same without", (changed("Tests/T.swift", "tests"), changed("Tests/T.swift", "products", "three\n")),
            (True, False))
        row("ci-build-key.sh: prose changes: the same name", (changed("docs/x.md", "products"), changed("docs/x.md", "tests", "three\n")), (False, False))
        row("ci-build-key.sh: no such kind", key("sideways")[0], 64)
        write("Sources/A.swift", "not committed\n")
        row("ci-build-key.sh: a checkout that differs from its commit has no name", key("products"), (2, None))


def check_fuzz_launch():
    for situation in fuzz_launch.situations():
        row(*situation)


def check_no_server_asks_its_name():
    """Python's HTTPServer asks for this machine's name when it binds, and macOS answers with an alert over the windows under test."""
    as_it_is = re.compile(r"HTTPServer\s*\(\s*\(|-m\s+http\.server\b")

    def starts_one(text):
        return [number + 1 for number, line in enumerate(text.splitlines()) if as_it_is.search(line)]

    row("no server asks its name: the module from the command line is found", starts_one("true\npython3 -m http.server 8765 --bind 127.0.0.1 &"), [2])
    row("no server asks its name: so is the class as it is", starts_one('server = http.server.HTTPServer(("127.0.0.1", 0), Handler)'), [1])
    row("no server asks its name: and the one with threads", starts_one('ThreadingHTTPServer( ("", 80), H).serve_forever()'), [1])
    row("no server asks its name: a class built on it is none, nor is starting that",
        starts_one('class Server(http.server.HTTPServer):\n    def server_bind(self): pass\nServer(("127.0.0.1", 0), Handler)'), [])
    # Also what is not committed yet, or a new file is first read by CI.
    listed = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", "scripts", "Tests", ".github", "Makefile"], cwd=ROOT,
                            capture_output=True, text=True, check=False)
    found, read = [], 0
    for path in filter(None, listed.stdout.split("\0")):
        if path == "scripts/test-tooling.py" or not os.path.isfile(os.path.join(ROOT, path)):
            continue
        try:
            with open(os.path.join(ROOT, path), encoding="utf-8") as handle:
                found += [f"{path}:{number}" for number in starts_one(handle.read())]
            read += 1
        except UnicodeDecodeError:
            pass  # a picture
    row("no server asks its name: nothing in scripts/, Tests/ or .github/ starts one as it is (scripts/mac-shell/serve.py says why, and does it right)", found, [])
    row("no server asks its name: and that was read off the files", read > 100, True)

    # The one that does it right never asks, and still answers.
    probe = """
import socket, sys, threading, urllib.request
def asked(*a): raise SystemExit("asked for the name")
socket.getfqdn = socket.gethostbyaddr = asked
import importlib.util
spec = importlib.util.spec_from_file_location("serve", %r)
serve = importlib.util.module_from_spec(spec); spec.loader.exec_module(serve)
import http.server
server = serve.Server(("127.0.0.1", 0), http.server.SimpleHTTPRequestHandler)
threading.Thread(target=server.serve_forever, daemon=True).start()
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
print(opener.open("http://127.0.0.1:%%d/" %% server.server_address[1], timeout=5).status, server.server_name)
""" % os.path.join(HERE, "mac-shell", "serve.py")
    with tempfile.TemporaryDirectory(prefix="tooling-") as folder:
        done = subprocess.run([sys.executable, "-c", probe], cwd=folder, capture_output=True, text=True, check=False, timeout=30)
    row("serve.py: binds without asking for the name, and answers", (done.returncode, done.stdout.strip()), (0, "200 127.0.0.1"))
    control = probe.replace("serve.Server(", "http.server.ThreadingHTTPServer(")
    with tempfile.TemporaryDirectory(prefix="tooling-") as folder:
        done = subprocess.run([sys.executable, "-c", control], cwd=folder, capture_output=True, text=True, check=False, timeout=30)
    row("serve.py: the control: Python's own does ask", (done.returncode, done.stderr.strip()), (1, "asked for the name"))
    row("serve.py: without a port it says how it is used", subprocess.run([sys.executable, os.path.join(HERE, "mac-shell", "serve.py")], capture_output=True, check=False).returncode, 1)


def check_reality_diff():
    for situation in reality_diff.situations():
        row(*situation)


def check_reality_observer():
    """reality.py must write the same words in both worlds, and nothing of what the script itself asked."""
    tool = os.path.join(HERE, "mac-shell", "reality.py")
    header = {"trace": 1, "displays": []}
    window = {"id": 4501, "pid": 70, "frame": [0, 0, 10, 10]}
    asked = [{"command": "state", "from": "script"}, {"call": "focus", "id": 4501}, {"done": "state", "ok": True, "message": "running"}]
    dock = [{"command": "dock 4501 left", "from": "script"}, {"call": "setFrame", "id": 4501, "frame": [12, 43.4, 494, 650], "result": [12, 43, 494, 650]},
            {"call": "focusedWindow", "result": 4501}, {"read": "stackedWindows", "result": []}, {"timer": "save"}, {"raw": "AXWindowMoved w4501"},
            {"done": "dock 4501 left", "ok": True, "message": "docked w4501 at the left edge"}]
    mark = [{"note": "reality: a step"}]

    def line(*parts):
        with tempfile.TemporaryDirectory() as folder:
            paths = {name: os.path.join(folder, name) for name in ("look", "names", "trace")}
            with open(paths["look"], "w", encoding="utf-8") as handle:
                handle.write('{"belief": null, "truth": {}}')
            with open(paths["names"], "w", encoding="utf-8") as handle:
                handle.write("4501 W1\n40 W2\n")
            with open(paths["trace"], "w", encoding="utf-8") as handle:
                handle.writelines(json.dumps(entry) + "\n" for entry in [header] + [entry for part in parts for entry in part])
            result = subprocess.run([sys.executable, tool, "line", "j", "a step", "1", "yes", paths["look"], paths["names"], paths["trace"], "arbor=60", "app=70"],
                                    capture_output=True, text=True, check=False)
        written = json.loads(result.stdout)
        return written["reports"], written["replies"]

    docked = (["setFrame:W1 12,43 494x650→12,43 494x650"], ["docked W1 at the left edge"])
    row("reality.py: a call with its answer, a reply, and no reads, timers or raw lines", line(dock, mark), docked)
    row("reality.py: what the script's own question set off is left out", line(asked, dock, asked, mark), docked)
    row("reality.py: only what came since the mark before", line(dock, mark, [{"event": "focused", "id": 4501}], mark), (["focused:W1"], []))
    row("reality.py: what came after the last mark waits for the next", line(dock, mark, [{"event": "focused", "id": 4501}]), docked)
    row("reality.py: unless the trace has ended", line(dock, mark, [{"call": "stop"}, {"end": "Arbor stopped", "lines": 9, "thinned": 0}]), (["stop"], []))
    row("reality.py: whose doing a change is, and what the window is now",
        line([{"event": "changed", "user": True, "window": dict(window, minimized=True)}, {"event": "changed", "user": False, "window": window}], mark),
        (["changed:W1:user+minimized", "changed:W1:arbor"], []))
    row("reality.py: a window nobody has named, a process by its name, a shortcut's command",
        line([{"event": "destroyed", "id": 9}, {"call": "unhideApp", "args": [70]}, {"command": "zoom 4501", "from": "shortcut"}], mark),
        (["destroyed:W?", "unhideApp:app", "command:zoom W1:shortcut"], []))

    # On a hosted Mac window ids are small numbers, and so are gaps, points and counts.
    def said(command, reply):
        return [{"command": command, "from": "script"}, {"done": command, "ok": True, "message": reply}]

    def pressed(command):
        return line([{"command": command, "from": "shortcut"}], mark)[0]

    row("reality.py: a number in a reply that happens to be a window's id is a number", line(said("set gap 40", "gap = 40 (was 12)"), mark), ([], ["gap = 40 (was 12)"]))
    row("reality.py: Arbor's replies write w and the id", line(said("zoom 40", "framed w40, 40 points wide"), mark), ([], ["framed W2, 40 points wide"]))
    row("reality.py: in a command only the places of windows hold windows",
        pressed("resize 40 right 40") + pressed("dock 40 beside 4501 bottom") + pressed("swap 40 4501") + pressed("set gap 40") + pressed("view 40")
        + pressed("move-to-display next 40") + pressed("grow 40"),
        ["command:resize W2 right 40:shortcut", "command:dock W2 beside W1 bottom:shortcut", "command:swap W2 W1:shortcut", "command:set gap 40:shortcut",
         "command:view 40:shortcut", "command:move-to-display next W2:shortcut", "command:grow 40:shortcut"])
    uuid = "07230EFA-7A8D-4E37-845C-19CC8737EEF5"
    row("reality.py: what is recorded by name is written by what each of its arguments is: nothing that only one world has gets through",
        line([{"event": "windowFound", "args": [dict(window, id=40, title="title[3]", bundle=None, app="ArborTestWindows")]},
              {"event": "windowReplaced", "args": [4501, dict(window, id=40, minimized=True)]}, {"action": "peekOutlineClicked", "args": [uuid]},
              {"action": "minimapClicked", "args": [uuid, 40.0, 12.4]}, {"action": "finderChose", "args": [{"window": 40}]},
              {"action": "finderChose", "args": [{"display": uuid, "space": 7}]}, {"call": "setMinimized", "args": [40, True]},
              {"event": "shortcut", "args": ["ctrl+opt+return", "zoom 40", "pressed"]}], mark)[0],
        ["windowFound:W2", "windowReplaced:W1,W2+minimized", "action:peekOutlineClicked:display", "action:minimapClicked:display,40,12", "action:finderChose:W2",
         "action:finderChose:space", "setMinimized:W2,true", "shortcut:ctrl+opt+return,zoom W2,pressed"])
    row("reality.py: a test app is a test app, whatever each world calls it; macOS's own apps have one name everywhere",
        line([{"event": "applicationActivated", "args": [None, "ArborTestWindows"]}, {"event": "applicationActivated", "args": ["dev.arbor.testwindows2", "ArborTestWindows2"]},
              {"event": "applicationActivated", "args": ["com.apple.finder", "Finder"]}, {"event": "applicationActivated"}], mark)[0],
        ["applicationActivated:test-app", "applicationActivated:test-app", "applicationActivated:Finder", "applicationActivated"])
    row("reality.py: of a name nobody has told it about, only the name", line([{"event": "somethingNew", "args": [40, uuid]}], mark)[0], ["somethingNew:…"])
    for question in ("get gap", "help", "watch windows --titles", "settings --json", "launch-at-login", "layout", "layout @2 --ids", "menu-bar", "stats reset"):
        row(f"reality.py: `{question}` is a question too", line(said(question, "an answer"), dock, mark), docked)
    for command in ("launch-at-login on", "layout 40 | Desktop", "set gap 40"):
        row(f"reality.py: `{command}` is none", line(said(command, "done"), mark), ([], ["done"]))

    # Three tables in reality.py say what Arbor's sources say. Asked of the tree, so that one that has drifted goes red.
    sys.path.insert(0, os.path.dirname(tool))  # it borrows from state.py, which lies beside it
    spec = importlib.util.spec_from_file_location("reality", tool)
    observer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(observer)

    def source(*parts):
        with open(os.path.join(ROOT, "Sources", *parts), encoding="utf-8") as handle:
            return handle.read()

    def cases_of_is_query(text):
        body = text[text.index("var isQuery: Bool {"):]
        return set(re.findall(r"\.(\w+)", " ".join(found for found in re.findall(r"case (.*?):", body[:body.index("default:")]))))

    row("reality.py: its questions are the cases of Command.isQuery",
        sorted(observer.QUESTIONS), sorted(cases_of_is_query(source("ArborCore", "Command.swift")) - {"settings"}
                                           | cases_of_is_query(source("ArborCore", "SettingsCommand.swift"))))
    row("reality.py: the verbs it takes a window after are those Command.text writes one after",
        sorted(observer.WINDOW_FIRST), sorted(set(re.findall(r'return "([a-z-]+)" \+ w\(', source("ArborCore", "Command.swift")))))
    named = set()
    for folder, _, files in os.walk(os.path.join(ROOT, "Sources", "ArborKit")):
        for name in files:
            with open(os.path.join(folder, name), encoding="utf-8") as handle:
                code = "\n".join(text for text in handle.read().splitlines() if not text.lstrip().startswith("//"))
            named |= set(re.findall(r'recorder\??\.(?:event|call|action)\(\s*"(\w+)"', code)) | set(re.findall(r'\btraced\("(\w+)"', code))
    row("reality.py: it knows the arguments of everything that is recorded by name", sorted(observer.NAMED), sorted(named))

    def look(windows):
        with tempfile.TemporaryDirectory() as folder:
            for name, text in (("windows", windows), ("on-screen", windows), ("keyboard", "70 4502\n"), ("names", "4501 W1\n")):
                with open(os.path.join(folder, name), "w", encoding="utf-8") as handle:
                    handle.write(text)
            result = subprocess.run([sys.executable, tool, "look", folder, os.path.join(folder, "names"), "arbor=60", "app=70"],
                                    capture_output=True, text=True, check=False)
        seen = json.loads(result.stdout)
        return seen["belief"], seen["truth"]["order"], seen["truth"]["overlays"], seen["truth"]["furniture"], seen["truth"]["front"], seen["truth"]["keyboard"]

    row("reality.py: a new window gets the next name; a helper, macOS's furniture and Arbor's own panels get none",
        look("9001 60 3 0 0 10 10 on Arbor\n4502 70 0 5 5 480 352 on App\n4503 70 0 5 5 40 20 on App\n4501 70 0 0 0 480 352 on App\n77 80 0 0 0 900 700 on Window Server\n"),
        (None, ["W2", "W1"], {"3": 1}, {"Window Server": 1}, "app", "W2"))


def check_fakemac_traces():
    """A rehearsal's traces are files as a Mac's are: they grow while they are recorded, and afterwards they are the script's."""
    fakemac = os.path.join(ROOT, ".build", "debug", "arbor-fakemac")
    if not os.access(fakemac, os.X_OK):
        print("SKIPPED the rows about a rehearsal's traces: no .build/debug/arbor-fakemac; run swift build first (on Linux)")
        return
    with tempfile.TemporaryDirectory() as session:
        home = os.path.join(session, "home")
        os.makedirs(home)
        environment = {**os.environ, "ARBOR_HOME": home, "ARBOR_SOCKET": "", "SWIFT_DETERMINISTIC_HASHING": "1", "ARBOR_ONLY_PIDS": "70"}

        def mac(*words):
            return subprocess.run([fakemac, *words], env=environment, capture_output=True, text=True, check=False)

        def traces():
            folder = os.path.join(home, "traces")
            return {name: len(open(os.path.join(folder, name), encoding="utf-8").readlines()) for name in os.listdir(folder)}

        mac("app-start", "70", "dev.arbor.testwindows", "ArborTestWindows", "--count", "2")
        # A process that is alive for as long as this takes: whoever finds Arbor's gone takes it for killed.
        mac("arbor-start", str(os.getpid()), "0")
        mac("arborctl", "trace", "on", "one")
        [begun] = traces().values()
        mac("arborctl", "dock", "101", "left")
        [grown] = traces().values()
        mac("arborctl", "trace", "off")
        [name] = traces()
        row("arbor-fakemac: a trace grows with what is done while it is recorded", begun < grown < traces()[name], True)
        os.remove(os.path.join(home, "traces", name))
        mac("arborctl", "dock", "102", "right")
        row("arbor-fakemac: a finished trace that the script has taken away does not come back", traces(), {})
        mac("arborctl", "trace", "on", "two")
        row("arbor-fakemac: nor with the next one", [name.endswith("-two.jsonl") for name in traces()], [True])


def check_reality_wrapper():
    """scripts/reality.sh (`make reality`) in a checkout made up for it, with a stand-in for the rehearsal."""
    observation = json.dumps({"journey": "j", "step": "dock", "n": 1, "settled": True, "reports": [], "replies": [], "belief": None,
                              "truth": {"windows": {"W1": {"frame": [0, 0, 480, 348], "on": True}}}})
    listed = "# a remark\nj/dock/truth/frame/W1 a word written by hand\n"

    def wrapper(tool=None, stale=None, **environment):
        """The exit code, whether it rehearsed, and the list afterwards."""
        with tempfile.TemporaryDirectory() as root:
            for folder in ("scripts/mac-shell", "collab/evidence", "mac", "empty", ".build/reality"):
                os.makedirs(os.path.join(root, folder))
            shutil.copy(os.path.join(HERE, "reality.sh"), os.path.join(root, "scripts"))
            if tool is None:
                shutil.copy(os.path.join(HERE, "reality-diff.py"), os.path.join(root, "scripts"))
            files = {"scripts/mac-shell/rehearse.sh": "#!/bin/bash\ntouch rehearsed\nmkdir -p .build/rehearsal/out/reality\n"
                                                      f"echo '{observation.replace('348', '352')}' > .build/rehearsal/out/reality/j.jsonl\n",
                     "collab/evidence/reality-known.txt": listed, "mac/j.jsonl": observation + "\n"}
            if tool is not None:
                files["scripts/reality-diff.py"] = tool
            if stale is not None:
                files[".build/reality/known.txt"] = stale
            for name, text in files.items():
                with open(os.path.join(root, name), "w", encoding="utf-8") as handle:
                    handle.write(text)
            os.chmod(os.path.join(root, "scripts/mac-shell/rehearse.sh"), 0o755)
            code = subprocess.run(["bash", os.path.join(root, "scripts", "reality.sh")], capture_output=True, check=False,
                                  env={**os.environ, "CHECK": "", "KNOWN": "", **environment}).returncode
            with open(os.path.join(root, "collab/evidence/reality-known.txt"), encoding="utf-8") as handle:
                return code, os.path.exists(os.path.join(root, "rehearsed")), handle.read()

    row("reality.sh: a run and a rehearsal that part as the list says", wrapper(MAC="mac", CHECK="1"), (0, True, listed))
    row("reality.sh: a folder without observations is refused before anything is rehearsed", wrapper(MAC="empty"), (2, False, listed))
    row("reality.sh: so is the second of two", wrapper(MAC="mac empty"), (2, False, listed))
    row("reality.sh: KNOWN=1 keeps the remarks and the words", wrapper(MAC="mac", KNOWN="1"), (0, True, listed))
    row("reality.sh: KNOWN=1 and a tool that crashes: the list stays, whatever an earlier run left lying about",
        wrapper(MAC="mac", KNOWN="1", tool="import sys\nsys.exit(3)\n", stale="j/dock/truth/frame/W1 ?\n"), (3, True, listed))

    def at_a_ref(slip):
        """`make reality-trunk` in a checkout of origin/trunk: the exit code, what run.sh was asked for, whether it rehearsed, the last line."""
        with tempfile.TemporaryDirectory() as root:
            for folder in ("scripts/mac-shell", "collab/evidence", "Sources"):
                os.makedirs(os.path.join(root, folder))
            for name in ("reality.sh", "reality-diff.py"):
                shutil.copy(os.path.join(HERE, name), os.path.join(root, "scripts"))
            files = {"scripts/mac-shell/rehearse.sh": "#!/bin/bash\ntouch rehearsed\nmkdir -p .build/rehearsal/out/reality\n"
                                                      f"echo '{observation.replace('348', '352')}' > .build/rehearsal/out/reality/j.jsonl\n",
                     "scripts/mac-shell/run.sh": "#!/bin/bash\necho \"$*\" > asked\nmkdir -p run/reality\necho 1234567890 > run/reality/commit.txt\n"
                                                 f"echo '{observation}' > run/reality/j.jsonl\necho output: run\n",
                     "collab/evidence/reality-known.txt": listed, "Sources/a.swift": "let a = 1\n", "Package.swift": "\n",
                     ".gitignore": ".build\nrun\nasked\nrehearsed\n"}
            for name, text in files.items():
                with open(os.path.join(root, name), "w", encoding="utf-8") as handle:
                    handle.write(text)
                os.chmod(os.path.join(root, name), 0o755)
            subprocess.run("git init -q . && git add -A && git -c user.name=m -c user.email=m@example.com commit -q -m all"
                           " && git update-ref refs/remotes/origin/trunk HEAD", shell=True, cwd=root, check=True)
            if slip:
                with open(os.path.join(root, "Sources/a.swift"), "w", encoding="utf-8") as handle:
                    handle.write("let a = 2\n")
            done = subprocess.run(["bash", os.path.join(root, "scripts", "reality.sh")], capture_output=True, check=False, text=True,
                                  env={**os.environ, "MAC": "", "KNOWN": "", "CHECK": "1", "REF": "trunk", "PRIORITY": "1", "STILL": "0"})
            asked = os.path.join(root, "asked")
            return (done.returncode, open(asked, encoding="utf-8").read().strip() if os.path.exists(asked) else None,
                    os.path.exists(os.path.join(root, "rehearsed")), (done.stdout.strip().splitlines() or [""])[-1])

    row("reality.sh: REF: the Mac is asked for that branch at that priority, and the last line is the verdict", at_a_ref(slip=False),
        (0, "--priority 1 scripts/mac-shell/reality.sh trunk", True,
         "trunk at 1234567: green: 1 divergences in 1 steps of 1 journeys (new: 0, known: 1, gone: 0)"))
    row("reality.sh: REF, and the code here is not that branch's: no Mac is asked, nothing is rehearsed", at_a_ref(slip=True), (2, None, False, ""))


def main():
    canary, since = subprocess.Popen(["sleep", "600"]), time.time()
    check_parity()
    check_ci_step()
    check_scenarios()
    check_lint()
    check_mutate()
    check_mac_shell_lint()
    check_mac_shell_lib(canary, since)
    check_rehearse()
    check_makefile()
    check_run_list()
    check_install()
    check_e2e()
    check_e2e_guardian()
    check_ci_mtimes()
    check_ci_build_key()
    check_mac_shell_batch()
    check_preflight()
    check_fuzz_launch()
    check_no_server_asks_its_name()
    check_reality_diff()
    check_reality_observer()
    check_fakemac_traces()
    check_reality_wrapper()
    wrong = 0
    for what, got, expected in rows:
        if got != expected:
            wrong += 1
            print(f"✘ {what}: expected {expected!r}, got {got!r}")
    print(f"{len(rows) - wrong} of {len(rows)} tooling situations came out as expected")
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
