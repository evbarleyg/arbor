#!/usr/bin/env python3
"""Puts a copy of Arbor's sources on the model's clock (README.md next to this file), after scripts/typecheck-mac/prepare.py has made it fit for Linux.

    retime.py <folder with the copied sources> [<folder or file in it that must know no other clock>...]

Rewrites the copy in place, never changing the number of lines. Waiting, the time, which macOS this is, and the question whether a process is there go to the
model of a Mac (scripts/typecheck-mac/stubs/FakeMacOS), so that a test says `mac.pass(0.3)` and everything due runs, in order, with no real waiting.
In the folders named it also reports, in the compiler's format, every other way to wait or to tell the time: code that used one would run on
the machine's clock while the model stands still, and the stories would prove nothing about it. Exit code 1 if it found any.
"""
import os
import re
import sys

REWRITES = [
    (re.compile(r"\bTask\.sleep\((nanoseconds|for):"), r"FakeMac.sleep(\1:"),
    (re.compile(r"\bProcessInfo\.processInfo\.systemUptime\b"), "FakeMac.uptime"),
    # Which macOS this is: not the kernel of the machine the test runs on.
    (re.compile(r"\bProcessInfo\.processInfo\.operatingSystemVersion\b"), "FakeMac.operatingSystemVersion"),
    # The model's processes are nobody's on this machine.
    (re.compile(r"(?<![\w.])kill\("), "FakeMac.kill("),
]

OTHER_CLOCKS = re.compile(
    r"\bTask\.sleep\(|\basyncAfter\(|\bTimer\.|\bThread\.sleep|\busleep\(|\bnanosleep\(|(?<![\w.])sleep\(|\bContinuousClock\b|\bSuspendingClock\b"
    r"|\bDate\(\)|\bDate\.now\b|\bDispatchTime\.now\(|\bDispatchWallTime\b|\bCFAbsoluteTimeGetCurrent\(|\bCACurrentMediaTime\(|\bmach_absolute_time\("
    r"|\bclock_gettime|\bDispatchSource\.makeTimerSource|\bperform\(.*afterDelay:|\bRunLoop\b.*\brun\(")


def main():
    root = sys.argv[1]
    strict = [os.path.join(root, named) for named in sys.argv[2:]]
    problems = []
    for folder, _, names in sorted(os.walk(root)):
        for name in sorted(names):
            if not name.endswith(".swift"):
                continue
            path = os.path.join(folder, name)
            text = open(path, encoding="utf-8").read()
            lines = text.split("\n")
            changed = False
            for number, line in enumerate(lines):
                new = line
                for pattern, replacement in REWRITES:
                    new = pattern.sub(replacement, new)
                if new != line:
                    lines[number] = new
                    changed = True
                code = new.split("//")[0]
                match = OTHER_CLOCKS.search(code)
                if match and any(path == named or path.startswith(named + os.sep) for named in strict):
                    problems.append(f"{os.path.relpath(path, root)}:{number + 1}:{match.start() + 1}: error: '{match.group(0)}' goes by the machine's clock, "
                                    "which the model of a Mac does not rule: teach scripts/mac-on-linux/retime.py to send it there")
            if changed:
                # At the end, where it moves no line.
                with open(path, "w", encoding="utf-8") as handle:
                    handle.write("\n".join(lines) + "import FakeMacOS\n")
    for problem in problems:
        print(problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
