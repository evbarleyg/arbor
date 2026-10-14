#!/usr/bin/env python3
"""Does `make typecheck-mac` notice? And does it keep quiet where nothing is wrong? `make typecheck-mac-selftest`; three runs, a minute.

`probes/` mirrors `Sources/`, `Tests/` and `scripts/mac-shell/`. Each file there holds macOS-only code of the kind written without a Mac, right and wrong side by side. The files are
laid into a copy of the sources, each into its folder, and the check is run. Every line that ends in "// wrong" must be reported as an
error; no other line of a probe may be: a checker that cries wolf is not believed for long. Every folder the tool claims to cover must
have a probe with a mistake in it, so the claim itself is put to the test.

The probes use nothing of Arbor's. An earlier version spoilt lines of Arbor's own files instead, and whenever such a line moved, which with many
branches landing was every hour, the self-test broke.

They go in layer by layer, because a library that fails keeps what imports it from being looked at.
With a folder as its argument the self-test works on that `Sources`, and the `Tests` beside it, instead of the checkout's.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
PROBES = os.path.join(HERE, "probes")

LAYERS = [["Sources/ArborIPC"], ["Sources/ArborKit"],
          ["Sources/Arbor", "Sources/arborctl", "Sources/ArborTestWindows", "Sources/arbor-e2e", "Tests/ArborCoreTests",
           "Tests/ArborKitTests", "scripts/mac-shell"]]
# What the README says is covered. Each needs a probe with at least one mistake.
COVERED = ["Sources/" + folder for folder in [
    "ArborIPC", "ArborKit/AX", "ArborKit/App", "ArborKit/IPC", "ArborKit/Input", "ArborKit/Support", "ArborKit/UI", "Arbor", "arborctl",
    "ArborTestWindows", "arbor-e2e"]] + ["Tests/ArborCoreTests", "Tests/ArborKitTests", "scripts/mac-shell"]


def probes_of(target):
    """The probes for one target, as paths relative to probes/ (and so to the repository)."""
    found = []
    for folder, _, names in os.walk(os.path.join(PROBES, target)):
        found += [os.path.relpath(os.path.join(folder, name), PROBES) for name in names if name.endswith(".swift")]
    return sorted(found)


def main():
    failures = 0
    with_mistakes = set()
    for layer in LAYERS:
        probes = [probe for target in layer for probe in probes_of(target)]
        with tempfile.TemporaryDirectory() as scratch:
            given = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, "Sources")
            shutil.copytree(given, os.path.join(scratch, "Sources"))
            shutil.copytree(os.path.join(os.path.dirname(given), "Tests"), os.path.join(scratch, "Tests"))
            shutil.copytree(os.path.join(os.path.dirname(given), "scripts", "mac-shell"), os.path.join(scratch, "scripts", "mac-shell"),
                            ignore=lambda _, names: [name for name in names if not name.endswith(".swift")])
            for probe in probes:
                shutil.copy(os.path.join(PROBES, probe), os.path.join(scratch, probe))
            run = subprocess.run([os.path.join(HERE, "check.sh"), "--sources", os.path.join(scratch, "Sources")], capture_output=True, text=True)
        errors = re.findall(r"^((?:Sources|Tests|scripts/mac-shell)/.+?):(\d+):\d+: error: (.*)$", run.stdout, re.MULTILINE)
        for probe in probes:
            said = {}
            for file, line, message in errors:
                if file == probe:
                    said.setdefault(int(line), message)
            lines = open(os.path.join(PROBES, probe), encoding="utf-8").read().split("\n")
            wrong = {number for number, line in enumerate(lines, 1) if line.endswith("// wrong")}
            for number in sorted(wrong - set(said)):
                print(f"✘ {probe}:{number}: not reported: {lines[number - 1].strip()}")
            for number in sorted(set(said) - wrong):
                print(f"✘ {probe}:{number}: nothing is wrong with it: {said[number]}")
            failures += len(wrong ^ set(said))
            if wrong:
                with_mistakes.add(os.path.dirname(probe))
            print(f"{'✔' if wrong == set(said) else '✘'} {probe}: {len(wrong & set(said))} of {len(wrong)} mistakes reported, "
                  f"{len(set(said) - wrong)} false alarms")
        # The sources themselves are taken to be sound. If they are not, say so rather than blame the probes.
        for file in sorted({file for file, _, _ in errors} - set(probes)):
            print(f"  ? {file} has errors of its own: run `make typecheck-mac`")
    for folder in COVERED:
        if folder not in with_mistakes:
            print(f"✘ {folder}: said to be covered, but no probe plants a mistake there")
            failures += 1
    print("every mistake was reported, and nothing else" if failures == 0 else f"{failures} lines were judged wrongly")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
