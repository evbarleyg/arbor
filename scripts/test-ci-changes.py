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


def pull(ref="feat/x", labels=()):
    head = {"sha": "H", "ref": ref}
    return "pull_request", {"pull_request": {"number": 1, "head": head, "labels": [{"name": name} for name in labels]}}


def push(before="B"):
    return "push", {"before": before}


TRUNK = pull(ref=rules.INTEGRATION_BRANCH)

# What is expected, the situation, the event, then GitHub's answers: `files` of the pull request, files
# `between` two commits, which of the commits H, P1, P2 (newest first) `passed`, the head's `subject`.
TABLE = [
    (False, "only prose", pull(), dict(files=[DOC, "collab/BOARD.md", "README.md"])),
    (False, "only code that builds on Linux", pull(), dict(files=[CORE, CONTROLLER, TEST, DOC])),
    (False, "the same with a Mac shell script", pull(), dict(files=[CORE, SHOTS])),
    (False, "stand-ins that only Linux compiles", pull(), dict(files=[CORE, "scripts/typecheck-mac/stubs/AppKit/View.swift"])),
    (False, "the Mac shell workflow and its set-up, which CI's own jobs do not use", pull(), dict(files=[
        ".github/workflows/mac-shell.yml", ".github/actions/mac-setup/action.yml", ".github/actions/mac-keep-build/action.yml",
        "scripts/ci-build.sh", "scripts/ci-build-key.sh", "scripts/ci-mtimes.py", "scripts/mac-shell/run.sh"])),
    (False, "these rules, their table and the tools' self-test, which Linux runs", pull(), dict(files=[
        "scripts/ci-changes.py", "scripts/test-ci-changes.py", "scripts/test-tooling.py"])),
    (False, "trunk: the same", TRUNK, dict(files=[".github/workflows/mac-shell.yml", "scripts/ci-changes.py"])),
    (True, "the script that installs the toolchain in CI's jobs too", pull(), dict(files=["scripts/ci-toolchain.sh"])),
    (True, "another action", pull(), dict(files=[".github/actions/other/action.yml"])),
    (True, "the wrapper of every step", pull(), dict(files=["scripts/ci-step.py"])),
    (False, "the look at the queue for the Macs, and its self-test", pull(), dict(files=["scripts/mac-queue.py", "scripts/test-mac-queue.py"])),
    (False, "trunk: the same", TRUNK, dict(files=["scripts/mac-queue.py", "scripts/test-mac-queue.py"])),
    (True, "a script that only sounds like it", pull(), dict(files=["scripts/mac-queue.py.sh"])),
    (True, "the Mac shell script CI runs", pull(), dict(files=[DOC, "scripts/mac-shell/e2e-drag.sh"])),
    (True, "what that script is built on", pull(), dict(files=[DOC, "scripts/mac-shell/lib.sh"])),
    (True, "a helper tool, which only a Mac's tests type-check", pull(), dict(files=[DOC, "scripts/mac-shell/curtain.swift"])),
    (True, "the one in Objective-C too", pull(), dict(files=[DOC, "scripts/mac-shell/vdisplay.m"])),
    (True, "macOS-only code", pull(), dict(files=[CORE, UI])),
    (False, "macOS-only code whose head has passed", pull(), dict(files=[CORE, UI], passed={"H"})),
    (False, "prose since the pass", pull(), dict(files=[CORE, UI, DOC], passed={"P1"}, between={("P1", "H"): [DOC]})),
    (True, "code since the pass", pull(), dict(files=[CORE, UI], passed={"P1"}, between={("P1", "H"): [CORE]})),
    (True, "the manifest", pull(), dict(files=["Package.swift"])),
    (True, "a script CI runs", pull(), dict(files=["scripts/parity.py"])),
    (True, "a workflow", pull(), dict(files=[".github/workflows/ci.yml"])),
    (True, "the socket client's module", pull(), dict(files=["Sources/ArborIPC/ArborPaths.swift"])),
    (False, "the Makefile, which no macOS job uses", pull(), dict(files=["Makefile"])),
    (True, "resources", pull(), dict(files=["Makefile", "Resources/Info.plist"])),
    (False, "what looks after the repository itself, on Linux or at GitHub's", pull(), dict(files=[
        "scripts/public-check.py", "scripts/public-check.allow", "scripts/test-public-check.py", "scripts/git-hooks/pre-push", "scripts/lint-workflows.py",
        "scripts/housekeeping.py", ".github/workflows/public-check.yml", ".github/workflows/housekeeping.yml", ".github/dependabot.yml",
        ".claude/settings.json"])),
    (True, "scripts and workflows that only begin like those", pull(), dict(files=["scripts/publish-release.sh"])),
    (True, "the same", pull(), dict(files=["scripts/public/x.sh"])),
    (True, "the same", pull(), dict(files=[".github/workflows/publish.yml"])),
    (True, "a path nobody has thought of", pull(), dict(files=[".gitignore"])),
    (True, "macOS-only code renamed into docs/", pull(), dict(files=["docs/B.md", UI])),
    (True, "[mac] in the subject", pull(), dict(files=[CORE], subject="fix: y [mac]")),
    (True, "the label mac", pull(labels=["mac"]), dict(files=[DOC])),
    (False, "another label", pull(labels=["bug"]), dict(files=[CORE])),
    (True, "the list of files cannot be read", pull(), dict()),
    (True, "no files at all", pull(), dict(files=[])),
    (True, "trunk: code that builds on Linux", TRUNK, dict(files=[CORE])),
    (False, "trunk: only prose", TRUNK, dict(files=[DOC])),
    (False, "trunk: moved to a tested head", TRUNK, dict(files=[CORE, UI], passed={"H"})),
    (True, "trunk: merged an unchecked branch", TRUNK, dict(files=[CORE, UI], passed={"P2"}, between={("P2", "H"): [CORE]})),
    (False, "trunk: merge commit of a tested, rebased head", TRUNK, dict(files=[UI], passed={"P1"}, between={("P1", "H"): []})),
    (False, "push: only prose", push(), dict(between={("B", "H"): [DOC]})),
    (True, "push: code that builds on Linux", push(), dict(between={("B", "H"): [CORE]})),
    (False, "push: fast-forward to a tested head", push(), dict(between={("B", "H"): [CORE, UI]}, passed={"H"})),
    (True, "push: a new branch", push(NEW_BRANCH), dict()),
    (False, "push: a new branch at a tested commit", push(NEW_BRANCH), dict(passed={"H"})),
    (True, "an event without a rule", ("schedule", {}), dict()),
]


def pretend(files=None, between=None, passed=(), subject="feat: x"):
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
    rules.passed_on_a_mac = lambda _repo, sha: sha in passed
    rules.subject = lambda _repo, _sha: subject


def main():
    wrong = 0
    for expected, situation, (name, event), answers in TABLE:
        pretend(**answers)
        needed, reason = rules.decide(name, event, "owner/repo", "H")
        if needed != expected:
            wrong += 1
            print(f"✘ {situation}: expected {expected}, got {needed} ({reason})")
    print(f"{len(TABLE) - wrong} of {len(TABLE)} situations decided as expected")
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
