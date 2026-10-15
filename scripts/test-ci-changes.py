#!/usr/bin/env python3
"""Checks the rules of ci-changes.py against a table of situations, with GitHub's answers made up.

A mistake there either runs a Mac for nothing or lets code through unchecked, and shows only weeks later.
The Linux CI job runs this. Exit code 1 when a row comes out wrong.
"""

import importlib.util
import os
import sys

path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ci-changes.py")
spec = importlib.util.spec_from_file_location("ci_changes", path)
rules = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rules)

CORE, CONTROLLER, TEST = "Sources/ArborCore/A.swift", "Sources/ArborKit/Controller/C.swift", "Tests/ArborKitTests/T.swift"
UI, DOC, SHOTS = "Sources/ArborKit/UI/B.swift", "docs/x.md", "scripts/mac-shell/shots-F1.sh"
NEW_BRANCH = "0" * 40


def pull(ref="feat/x", labels=(), base=rules.INTEGRATION_BRANCH):
    head = {"sha": "H", "ref": ref}
    return "pull_request", {"pull_request": {"number": 1, "head": head, "base": {"ref": base}, "labels": [{"name": name} for name in labels]}}


def push(before="B"):
    return "push", {"before": before}


TRUNK = pull(ref=rules.INTEGRATION_BRANCH, base=rules.MAIN)
# No Mac at all; its own tests, built upon an earlier build; the same, built from nothing; every test, built from nothing.
NO, UPON, FRESH, FULL = None, rules.UPON, rules.FRESH, rules.FULL

# What is expected, the situation, the event, then GitHub's answers: `files` of the pull request, files
# `between` two commits, which of the commits H, P1, P2 (newest first) `passed` on a Mac, on which of them it had built `fresh`,
# from nothing, the head's `subject`.
TABLE = [
    (NO, "only prose", pull(), dict(files=[DOC, "collab/BOARD.md", "README.md"])),
    (NO, "only code that builds on Linux", pull(), dict(files=[CORE, CONTROLLER, TEST, DOC])),
    (NO, "the same with a Mac shell script", pull(), dict(files=[CORE, SHOTS])),
    (NO, "stand-ins that only Linux compiles", pull(), dict(files=[CORE, "scripts/typecheck-mac/stubs/AppKit/View.swift"])),
    (NO, "stories that only Linux tells", pull(), dict(files=[CORE, "scripts/mac-on-linux/tests/main.swift", "scripts/mac-on-linux/known-failures.txt"])),
    (NO, "the Mac shell workflow and what runs the scripts there, which CI's own job does not use", pull(), dict(files=[
        ".github/workflows/mac-shell.yml", "scripts/ci-mac-shell.sh", "scripts/mac-shell/run.sh", "scripts/mac-shell/preflight.sh"])),
    (NO, "these rules, their table and the tools' self-tests, which Linux runs", pull(), dict(files=[
        "scripts/ci-changes.py", "scripts/test-ci-changes.py", "scripts/test-tooling.py", "scripts/test-ci-tests.py"])),
    (NO, "trunk: the same", TRUNK, dict(files=[".github/workflows/mac-shell.yml", "scripts/ci-changes.py"])),
    (NO, "the workflow that holds the Linux jobs", pull(), dict(files=[".github/workflows/linux.yml"])),
    (UPON, "the workflow that calls it, and holds the macOS job", pull(), dict(files=[".github/workflows/linux.yml", ".github/workflows/ci.yml"])),
    (NO, "the look at the queue for the Macs, and its self-test", pull(), dict(files=["scripts/mac-queue.py", "scripts/test-mac-queue.py"])),
    (NO, "scripts the macOS job cannot reach, with prose", pull(), dict(files=["scripts/census.py", "scripts/tools/ledger.py", DOC, "CLAUDE.md"])),
    (NO, "trunk: the same", TRUNK, dict(files=["scripts/census.py"])),
    (NO, "such a script and code that builds on Linux", pull(), dict(files=["scripts/census.py", CORE])),
    (FRESH, "trunk: such a script and code that builds on Linux", TRUNK, dict(files=["scripts/census.py", CORE])),
    (UPON, "such a script and macOS-only code", pull(), dict(files=["scripts/census.py", UI])),
    (NO, "only such a script since the pass", pull(), dict(files=[UI, "scripts/census.py"], passed={"P1"}, between={("P1", "H"): ["scripts/census.py"]})),
    (UPON, "a script that only sounds like it", pull(), dict(files=["scripts/mac-queue.py.sh"])),
    (UPON, "the set-up of a hosted Mac, which CI's job begins with", pull(), dict(files=[".github/actions/mac-setup/action.yml"])),
    (UPON, "what keeps a build", pull(), dict(files=[".github/actions/mac-keep-build/action.yml"])),
    (UPON, "what builds, names a build and restores time stamps", pull(), dict(files=["scripts/ci-build.sh"])),
    (UPON, "the same", pull(), dict(files=["scripts/ci-build-key.sh"])),
    (UPON, "the same", pull(), dict(files=["scripts/ci-mtimes.py"])),
    (UPON, "the script that installs the toolchain", pull(), dict(files=["scripts/ci-toolchain.sh"])),
    (UPON, "the script that selects the tests, which the Mac runs", pull(), dict(files=["scripts/ci-tests.py"])),
    (UPON, "the wrapper of every step", pull(), dict(files=["scripts/ci-step.py"])),
    (UPON, "the Mac shell script CI runs", pull(), dict(files=[DOC, "scripts/mac-shell/e2e-drag.sh"])),
    (UPON, "what that script is built on", pull(), dict(files=[DOC, "scripts/mac-shell/lib.sh"])),
    (UPON, "what compiles the helper tools in CI's build step", pull(), dict(files=[DOC, "scripts/mac-shell/compile-tools.sh"])),
    (UPON, "a helper tool, which only a Mac's tests type-check", pull(), dict(files=[DOC, "scripts/mac-shell/curtain.swift"])),
    (UPON, "the one in Objective-C too", pull(), dict(files=[DOC, "scripts/mac-shell/vdisplay.m"])),
    (UPON, "macOS-only code", pull(), dict(files=[CORE, UI])),
    (UPON, "the app's main.swift and the real-window runner", pull(), dict(files=["Sources/Arbor/main.swift", "Sources/arbor-e2e/Steps.swift"])),
    (NO, "macOS-only code whose head has passed", pull(), dict(files=[CORE, UI], passed={"H"})),
    (NO, "prose since the pass", pull(), dict(files=[CORE, UI, DOC], passed={"P1"}, between={("P1", "H"): [DOC]})),
    (UPON, "code since the pass", pull(), dict(files=[CORE, UI], passed={"P1"}, between={("P1", "H"): [CORE]})),
    (UPON, "the manifest (which is part of a build's name, so nothing is built upon)", pull(), dict(files=["Package.swift"])),
    (UPON, "a script CI runs", pull(), dict(files=["scripts/parity.py"])),
    (UPON, "a workflow", pull(), dict(files=[".github/workflows/ci.yml"])),
    (UPON, "the socket client's module", pull(), dict(files=["Sources/ArborIPC/ArborPaths.swift"])),
    (NO, "the Makefile, which the macOS job does not use", pull(), dict(files=["Makefile"])),
    (UPON, "resources", pull(), dict(files=["Makefile", "Resources/Info.plist"])),
    (NO, "what looks after the repository itself, on Linux or at GitHub's", pull(), dict(files=[
        "scripts/public-check.py", "scripts/public-check.allow", "scripts/test-public-check.py", "scripts/git-hooks/pre-push", "scripts/lint-workflows.py",
        "scripts/housekeeping.py", "scripts/gh-state.py", ".github/workflows/public-check.yml", ".github/workflows/housekeeping.yml", ".github/dependabot.yml",
        ".claude/settings.json"])),
    (UPON, "scripts and workflows that only begin like those", pull(), dict(files=["scripts/publish-release.sh"])),
    (UPON, "the same", pull(), dict(files=["scripts/public/x.sh"])),
    (UPON, "the same", pull(), dict(files=[".github/workflows/publish.yml"])),
    (UPON, "a path nobody has thought of", pull(), dict(files=[".gitignore"])),
    (UPON, "macOS-only code renamed into docs/", pull(), dict(files=["docs/B.md", UI])),
    (UPON, "[mac] in the subject", pull(), dict(files=[CORE], subject="fix: y [mac]")),
    (UPON, "the label mac", pull(labels=["mac"]), dict(files=[DOC])),
    (FULL, "[mac-full] in the subject", pull(), dict(files=[DOC], subject="fix: y [mac-full]")),
    (FULL, "[mac-full] though the head has passed", pull(), dict(files=[UI], fresh={"H"}, subject="fix: y [mac-full]")),
    (FULL, "the label mac-full", pull(labels=["mac-full"]), dict(files=[DOC])),
    (FULL, "both labels", pull(labels=["mac", "mac-full"]), dict(files=[UI])),
    (NO, "another label", pull(labels=["bug"]), dict(files=[CORE])),
    (FULL, "the list of files cannot be read", pull(), dict()),
    (UPON, "the same, and asked for with [mac]", pull(), dict(subject="fix: y [mac]")),
    (FULL, "no files at all", pull(), dict(files=[])),
    (FRESH, "trunk: code that builds on Linux", TRUNK, dict(files=[CORE])),
    (FRESH, "trunk: macOS-only code", TRUNK, dict(files=[UI])),
    (FRESH, "trunk: asked for with [mac]", TRUNK, dict(files=[DOC], subject="docs: y [mac]")),
    (FULL, "trunk: asked for with [mac-full]", TRUNK, dict(files=[DOC], subject="docs: y [mac-full]")),
    (NO, "trunk: only prose", TRUNK, dict(files=[DOC])),
    (NO, "trunk: moved to a head that passed, built from nothing", TRUNK, dict(files=[CORE, UI], fresh={"H"})),
    (FRESH, "trunk: moved to a head that passed, built upon a cache: that pass does not count here", TRUNK, dict(files=[CORE, UI], passed={"H"})),
    (FRESH, "trunk: merged an unchecked branch", TRUNK, dict(files=[CORE, UI], fresh={"P2"}, between={("P2", "H"): [CORE]})),
    (NO, "trunk: merge commit of a tested, rebased head", TRUNK, dict(files=[UI], fresh={"P1"}, between={("P1", "H"): []})),
    (NO, "trunk: passed upon a cache since, from nothing before that, prose between", TRUNK,
     dict(files=[UI], passed={"P1"}, fresh={"P2"}, between={("P2", "H"): [DOC]})),
    (FRESH, "any other branch into main is integration too", pull(ref="hotfix/x", base=rules.MAIN), dict(files=[UI])),
    (FRESH, "into main: code that builds on Linux", pull(ref="hotfix/x", base=rules.MAIN), dict(files=[CORE])),
    (FRESH, "into main: a pass upon a cache does not count", pull(ref="hotfix/x", base=rules.MAIN), dict(files=[UI], passed={"H"})),
    (NO, "into main: only prose", pull(ref="hotfix/x", base=rules.MAIN), dict(files=[DOC])),
    (NO, "push: only prose", push(), dict(between={("B", "H"): [DOC]})),
    (FRESH, "push: code that builds on Linux", push(), dict(between={("B", "H"): [CORE]})),
    (NO, "push: fast-forward to a head that passed, built from nothing", push(), dict(between={("B", "H"): [CORE, UI]}, fresh={"H"})),
    (FRESH, "push: fast-forward to a head that passed upon a cache", push(), dict(between={("B", "H"): [CORE, UI]}, passed={"H"})),
    (FULL, "push: a new branch", push(NEW_BRANCH), dict()),
    (NO, "push: a new branch at a commit that passed, built from nothing", push(NEW_BRANCH), dict(fresh={"H"})),
    (FULL, "every night", ("schedule", {}), dict()),
    (FULL, "every night, whatever has passed", ("schedule", {}), dict(fresh={"H"})),
    (FULL, "started by hand, for which there is no rule", ("workflow_dispatch", {}), dict()),
]

# What goes to $GITHUB_OUTPUT, where every line is an answer and the last one of a name counts.
OUTPUT = [
    ("every test, from nothing", (FULL, "changed: x"), ["why=changed: x", "tests=full", "build=from-nothing", "mac=true"]),
    ("its own tests, from nothing", (FRESH, "changed: x"), ["why=changed: x", "tests=mac-only", "build=from-nothing", "mac=true"]),
    ("its own tests, upon a cache", (UPON, "changed: x"), ["why=changed: x", "tests=mac-only", "build=upon", "mac=true"]),
    ("no Mac", (NO, "only prose"), ["why=only prose", "tests=none", "build=none", "mac=false"]),
    ("a word nobody knows is taken for the most", ("sideways", "x"), ["why=x", "tests=full", "build=from-nothing", "mac=true"]),
    ("a file name with an answer of its own", (FULL, "changed: a\nmac=false\r\ntests=mac-only\nbuild=upon"),
     ["why=changed: a mac=false tests=mac-only build=upon", "tests=full", "build=from-nothing", "mac=true"]),
]


# What the macOS job can reach: where it starts, the files under scripts/, and which of them it reaches.
A_JOB = "run: ./scripts/ci-step.py build ./scripts/build.sh\n"
REACH = [
    ("what a step names", [A_JOB], {"scripts/build.sh": "", "scripts/ci-step.py": "", "scripts/census.py": ""}, ["scripts/build.sh", "scripts/ci-step.py"]),
    ("and what that names in turn", [A_JOB], {"scripts/build.sh": "exec \"$(dirname \"$0\")/tools/inner.sh\"", "scripts/tools/inner.sh": "third.sh", "scripts/third.sh": ""},
     ["scripts/build.sh", "scripts/third.sh", "scripts/tools/inner.sh"]),
    ("a Python module that is imported", [A_JOB], {"scripts/ci-step.py": "from parity import ANSI\nimport lint_imports\n", "scripts/parity.py": "",
                                                  "scripts/lint-imports.py": "", "scripts/other.py": ""},
     ["scripts/ci-step.py", "scripts/lint-imports.py", "scripts/parity.py"]),
    ("what a test names", ["let path = \"scripts/mac-shell/pointer.swift\""], {"scripts/mac-shell/pointer.swift": "", "scripts/mac-shell/other.swift": ""},
     ["scripts/mac-shell/pointer.swift"]),
    ("a remark counts: it errs towards the Mac", ["# see census.py"], {"scripts/census.py": ""}, ["scripts/census.py"]),
    ("two that name each other", ["a.sh"], {"scripts/a.sh": "b.sh", "scripts/b.sh": "a.sh"}, ["scripts/a.sh", "scripts/b.sh"]),
    ("a name inside a longer one is another name", ["test-build.sh my_build.sh build.shx build.sh-old x.build.sh"], {"scripts/build.sh": ""}, []),
    ("at the end of a sentence it is the name", ["It calls build.sh."], {"scripts/build.sh": ""}, ["scripts/build.sh"]),
    ("nothing names it", [A_JOB], {"scripts/census.py": "build.sh"}, []),
]


def pretend(files=None, between=None, passed=(), fresh=(), subject="feat: x"):
    def files_of_pull_request(_repo, _number):
        if files is None:
            raise rules.Unclear("no list")
        return files

    def files_between(_repo, base, head):
        if base == head:
            return []
        if (base, head) not in (between or {}):
            raise rules.Unclear(f"{base}...{head}")
        return between[(base, head)]

    rules.files_of_pull_request = files_of_pull_request
    rules.files_between = files_between
    rules.recent_commits = lambda _repo, _head: ["H", "P1", "P2"]
    # A Mac that passed after building from nothing has passed.
    rules.passed_on_a_mac = lambda _repo, sha, check: sha in fresh or (check == rules.CHECK and sha in passed)
    rules.subject = lambda _repo, _sha: subject
    # Of the scripts in the table these two are out of the macOS job's reach.
    rules.out_of_reach = lambda: rules.re.compile(r"^scripts/(census\.py|tools/ledger\.py)$")


real_reach, real_checkout, real_out_of_reach = rules.reach, rules.checkout, rules.out_of_reach


def real_pattern_without_a_checkout():
    def nothing(root=None):
        raise rules.Unclear("nothing there")

    rules.checkout = nothing
    try:
        return real_out_of_reach()
    finally:
        rules.checkout = real_checkout


def main():
    wrong = 0
    for expected, situation, (name, event), answers in TABLE:
        pretend(**answers)
        tests, reason = rules.decide(name, event, "owner/repo", "H")
        if tests != expected:
            wrong += 1
            print(f"✘ {situation}: expected {expected}, got {tests} ({reason})")
    for situation, decision, expected in OUTPUT:
        lines = rules.answers(*decision)
        if lines != expected:
            wrong += 1
            print(f"✘ {situation}: expected {expected}, got {lines}")
    for situation, starts, scripts, expected in REACH:
        got = sorted(real_reach(starts, scripts))
        if got != expected:
            wrong += 1
            print(f"✘ reach: {situation}: expected {expected}, got {got}")
    # The real thing. What ci.yml's job plainly runs is within reach, and a script that nothing names is not.
    starts, scripts = real_checkout()
    reached = real_reach(starts, {**scripts, "scripts/nobody-names-this-one.py": ""})
    plain = {"scripts/ci-step.py", "scripts/ci-build.sh", "scripts/ci-tests.py", "scripts/parity.py", "scripts/e2e.sh", "scripts/sim-smoke.sh",
             "scripts/scenarios.sh", "scripts/release-tools-test.sh", "scripts/ci-toolchain.sh", "scripts/ci-mtimes.py", "scripts/ci-build-key.sh",
             "scripts/mac-shell/e2e-drag.sh", "scripts/mac-shell/lib.sh", "scripts/mac-shell/compile-tools.sh", "scripts/mac-shell/pointer.swift"}
    for situation, got, expected in [
        ("this repository: what the job plainly runs", sorted(plain - reached), []),
        ("this repository: a script nothing names", "scripts/nobody-names-this-one.py" in reached, False),
        ("a checkout without the workflow or the tests: everything counts as within reach", bool(real_pattern_without_a_checkout().search("scripts/census.py")), False),
    ]:
        if got != expected:
            wrong += 1
            print(f"✘ reach: {situation}: expected {expected}, got {got}")
    count = len(TABLE) + len(OUTPUT) + len(REACH) + 3
    print(f"{count - wrong} of {count} situations decided as expected")
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
