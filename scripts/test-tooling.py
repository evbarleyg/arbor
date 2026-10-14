#!/usr/bin/env python3
"""Checks that the tools which say "all is well" can also say the opposite.

parity.py, ci-step.py, scenarios.sh with arbor-sim, lint-imports.py, lint-mac-shell.py, mutate.py, fuzz-launch.py, ci-mtimes.py and the safety nets of
scripts/mac-shell/lib.sh each get situations that must come out as failures (a misspelt status, a test that was renamed, a log cut off by a crash, a scenario whose
commands do nothing) next to ones that must pass. Every row here passed when it should have failed
before 2026-10-14.

`make check` runs this. The scenario rows need .build/debug/arbor-sim and are skipped, loudly, without it.
The rows for lib.sh run small scripts for real, against stand-ins for a Mac, under `bash` or $ARBOR_TEST_BASH (macOS has 3.2).
Exit code 1 when a row comes out wrong.
"""

import concurrent.futures
import importlib.util
import os
import pty
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

rows = []


def row(what, got, expected):
    rows.append((what, got, expected))


# MARK: parity.py

def item(**fields):
    return {"id": "T01", "status": "shipped", **fields}


def level(entry, passed=(), failed=(), steps=None, runnable=()):
    return parity.level_of(entry, set(passed), set(failed), steps or {}, set(runnable))[0]


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

    start, end = "◇ Test run started.", "✔ Test run with 3 tests in 1 suite passed after 0.1 seconds."
    row("a finished run", parity.run_problem(f"{start}\n{end}"), None)
    row("a run with a known issue, whose symbol differs",
        parity.run_problem(f"{start}\n━ Test run with 1 test in 1 suite passed after 0.1 seconds with 1 known issue."), None)
    row("a run cut off by a crash", parity.run_problem(start) is not None, True)
    row("the second of two runs cut off", parity.run_problem(f"{start}\n{end}\n{start}") is not None, True)
    row("a failed run", parity.run_problem(f"{start}\n✘ Test run with 3 tests in 1 suite failed after 0.1 seconds.") is not None, True)
    row("swift test exits with an error", parity.run_problem(f"{start}\n{end}", 1) is not None, True)

    skipped = '➜ Test macTest() skipped: "Carbon exists only on macOS"'
    row("a macOS-only test in a Linux log counts",
        parity.parse_tests(f"↳ Target Platform: x86_64-unknown-linux-gnu\n{skipped}")[2], {"macTest"})
    row("the same test skipped on a Mac does not",
        parity.parse_tests(f"↳ Target Platform: arm64e-apple-macos14.0\n{skipped}")[2], set())
    row("a test skipped for another reason does not",
        parity.parse_tests('↳ Target Platform: x86_64-unknown-linux-gnu\n➜ Test t() skipped: "later"')[2], set())
    row("one failing case of a parameterised test fails it",
        parity.parse_tests("✔ Test t(x:) passed after 0.1 seconds.\n✘ Test t(x:) failed after 0.1 seconds.")[:2], (set(), {"t"}))

    begun = "◇ Test t() started."
    row("a `passed` line lost from a run that finished and passed", parity.parse_tests(f"{start}\n{begun}\n{end}")[0], {"t"})
    row("the same from a run that did not finish", parity.parse_tests(f"{start}\n{begun}")[0], set())
    row("the same from a run in which something failed",
        parity.parse_tests(f"{start}\n{begun}\n✘ Test u() failed after 0.1 seconds.\n✘ Test run with 2 tests in 1 suite failed after 0.1 seconds.")[0], set())
    row("a test with a known issue proves nothing",
        parity.parse_tests(f"{start}\n{begun}\n━ Test t() recorded a known issue at T.swift:3:5: Expectation failed\n{end}")[0], set())

    with tempfile.TemporaryDirectory() as folder:
        os.makedirs(os.path.join(folder, "Tests", "T"))
        with open(os.path.join(folder, "Tests", "T", "T.swift"), "w", encoding="utf-8") as handle:
            handle.write("\n".join([
                "@Test func one() {}", "@Test(arguments: [f(1), g((2))]) func two(x: Int) {}", "  @Test @MainActor\n  func three() {}",
                '@Test(.disabled("later")) func four() {}', "#if canImport(Carbon)", "@Test func mac() {}", "#else",
                '@Test(.disabled("Carbon exists only on macOS")) func mac() {}', "#endif", "func helper() {}",
            ]))
        row("the tests the sources declare, off macOS", parity.declared_tests(False, folder), ({"one", "two", "three"}, {"mac"}, 5))
        row("and on macOS", parity.declared_tests(True, folder), ({"one", "two", "three", "mac"}, set(), 5))
        linux = "↳ Target Platform: x86_64-unknown-linux-gnu"

        def closing(count, outcome="passed"):
            return f"✔ Test run with {count} tests in 1 suite {outcome} after 0.1 seconds."

        wanted = {"one", "four", "mac", "gone"}
        row("both lines of a test lost, and the runs ran as many tests as there are",
            parity.recover(wanted, f"{start}\n{linux}\n{closing(2)}\n{start}\n{closing(3)}", folder), ({"one"}, {"mac"}))
        row("the same, but the runs ran fewer tests than there are", parity.recover(wanted, f"{start}\n{linux}\n{closing(4)}", folder), (set(), set()))
        row("the same, but a run did not finish", parity.recover(wanted, f"{start}\n{linux}\n{closing(5)}\n{start}", folder), (set(), set()))
        row("the same, but a run failed", parity.recover(wanted, f"{start}\n{linux}\n{closing(5, 'failed')}", folder), (set(), set()))

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


# MARK: scenarios.sh and arbor-sim

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
    "pmset": '#!/bin/bash\necho "   PreventUserIdleDisplaySleep    $(cat "$FAKE/awake" 2>/dev/null || echo 0)"\n',
    "defaults": '#!/bin/bash\n[ "$1" = read ] || exit 0\ncat "$FAKE/defaults-${2#-}" 2>/dev/null || exit 1\n',
    "security": "#!/bin/bash\necho '\"/Users/x/Library/Keychains/login.keychain-db\"'\n",
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
        said = 'echo "in $ARBOR_ROOT/Sources and /private$ARBOR_ROOT/x, $HOME/Documents/tax.pdf, /Users/jo/Library and \\"/Users/al\\": done"'
        setup = 'echo "2026-10-14T11:00:00.000Z ERROR setup: Other window managers: Secret Tiler is running | quit it"'
        code, output = mac.run(f'{said}\n{said} >&2\n{said} > "$ARBOR_OUT/build.log"\n{said} > "$ARBOR_OUT/picture.png"\nyes | head -n 1\n'
                               f'{setup}\n{setup} > "$ARBOR_OUT/arbor.log"\nexit 3')
        clean = 'in <checkout>/Sources and <checkout>/x, ~/Documents/tax.pdf, ~/Library and "~": done'
        return [("lib.sh: on somebody's Mac what a run prints, on either output, says neither where the checkout nor where the home folder is",
                 (code, [line for line in output.splitlines() if line.startswith("in ") or line == "y"]), (3, [clean, clean, "y"])),
                ("lib.sh: nor do the logs it leaves; other files are left as they are",
                 (mac.read("out/build.log").strip(), "/Users/jo" in mac.read("out/picture.png")), (clean, True)),
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

    def stray_environment(mac):
        os.makedirs(os.path.join(mac.folder, "precious"))
        open(os.path.join(mac.folder, "precious", "empty.log"), "w", encoding="utf-8").close()
        del mac.environment["ARBOR_REHEARSAL"]
        mac.environment["ARBOR_OUT"] = os.path.join(mac.folder, "precious")
        code, _ = mac.run("true")
        return [("lib.sh: ARBOR_OUT from a stray environment is not taken", (code, os.path.exists(os.path.join(mac.folder, "precious", "empty.log"))), (0, True))]

    throwaway = [second_lock, folders, full_disk, disk_fills_up, strange_mktemp, refusals, strangers, limited, both_killed, supervisor_killed, two_at_once,
                 ended("the time limit"), ended("an interrupt"), ended("kill -9")]
    somebodys = [nets, pictures, discreet, nameless, curtain_down, stale_output, defaults_for_arbor, no_curtain, both_killed, supervisor_killed,
                 ended("the time limit", "on somebody's Mac, "), ended("an interrupt", "on somebody's Mac, "), ended("kill -9", "on somebody's Mac, "),
                 declined("not beside an Arbor that is running already", running__Arbor=str(canary)),
                 declined("not beside another window manager", running__Rectangle=str(canary)),
                 declined("not under somebody's hands", idle="20"), quiet_since, declined("not into a call", awake="1"), declined("not as root", uid="0"),
                 declined("not behind a locked screen", locked="yes"), declined("not under the screen saver", running__ScreenSaverEngine=str(canary))]
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

    def installed(cp):
        """(exit code, what the installed app holds, whether Arbor was asked to quit, what else lies beside it) with a stand-in for `cp`."""
        with tempfile.TemporaryDirectory(prefix="tooling-") as folder:
            home = os.path.join(folder, "home")
            for path in ("scripts", "bin", "build/Arbor.app/Contents/Helpers", "home/Applications/Arbor.app"):
                os.makedirs(os.path.join(folder, path))
            shutil.copy(os.path.join(HERE, "install.sh"), os.path.join(folder, "scripts", "install.sh"))
            for path, text in (("scripts/version.sh", "echo 1.0"), ("bin/swift", "echo 0"), ("bin/cp", cp),
                               ("build/Arbor.app/Contents/Helpers/arborctl", f'echo "$1" >> "{folder}/asked"; exit 2')):
                with open(os.path.join(folder, path), "w", encoding="utf-8") as handle:
                    handle.write(f"#!/bin/bash\n{text}\n")
                os.chmod(os.path.join(folder, path), 0o755)
            open(os.path.join(home, "Applications", "Arbor.app", "the-old-one"), "w", encoding="utf-8").close()
            done = subprocess.run(["bash", "scripts/install.sh"], cwd=folder, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                                  env={**kept, "HOME": home, "PATH": os.path.join(folder, "bin") + os.pathsep + os.environ["PATH"], "ARBOR_UNATTENDED": "1", "LAUNCH": "0"})
            return (done.returncode, sorted(os.listdir(os.path.join(home, "Applications", "Arbor.app"))), os.path.exists(os.path.join(folder, "asked")),
                    sorted(name for name in os.listdir(os.path.join(home, "Applications")) if name != "Arbor.app"))

    row("install.sh: the new app takes the old one's place, and nothing is left beside it", installed('exec /bin/cp "$@"'), (0, ["Contents"], True, []))
    row("install.sh: a copy that fails half way changes nothing: the old app stays, and the Arbor that runs is not asked to quit",
        installed('/bin/mkdir -p "${@: -1}/half"; exit 1'), (1, ["the-old-one"], False, []))
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


def check_fuzz_launch():
    for situation in fuzz_launch.situations():
        row(*situation)


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
    check_ci_mtimes()
    check_fuzz_launch()
    wrong = 0
    for what, got, expected in rows:
        if got != expected:
            wrong += 1
            print(f"✘ {what}: expected {expected!r}, got {got!r}")
    print(f"{len(rows) - wrong} of {len(rows)} tooling situations came out as expected")
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
