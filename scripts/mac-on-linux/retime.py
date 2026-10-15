#!/usr/bin/env python3
"""Puts a copy of Arbor's sources on the model's clock (README.md next to this file), after scripts/typecheck-mac/prepare.py has made it fit for Linux.

    retime.py <folder with the copied sources> <folder in it that must know no other clock> [<folder or file in that whose threads are the model's>...]

Rewrites the copy in place, never changing the number of lines. Waiting, the time, which macOS this is, and the question whether a process is there go to the
model of a Mac (scripts/typecheck-mac/stubs/FakeMacOS), so that a test says `mac.pass(0.3)` and everything due runs, in order, with no real waiting.
In the folder named it also reports, in the compiler's format, every other way to wait or to tell the time: code that used one would run on
the machine's clock while the model stands still, and the stories would prove nothing about it. What may do so all the same is listed in ALLOWED, with the reason. Exit code 1 if it
found any other.
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
    # Nor is Arbor's own number that of the process the test runs in.
    (re.compile(r"(?<![\w.])getpid\(\)"), "FakeMac.getpid()"),
    (re.compile(r"\bDispatchTime\b"), "FakeDispatchTime"),
    # What the person has set in System Settings is the model's to say.
    (re.compile(r"\bUserDefaults\(suiteName:"), "FakeMac.defaults(suiteName:"),
]

# Other threads than the main one, and the main one's waiting for them (stubs/FakeMacOS/Threads.swift). Only where the clock must be the model's: elsewhere a queue is for files.
THREADS = [
    (re.compile(r"\bDispatchQueue\.main\.async\b(?!After)"), "FakeMac.mainAsync"),
    (re.compile(r"\bDispatchQueue\b(?!\.(main|global)\b)"), "FakeDispatchQueue"),
    (re.compile(r"\bDispatchSemaphore\b"), "FakeDispatchSemaphore"),
    (re.compile(r"\bDispatchGroup\b"), "FakeDispatchGroup"),
]

OTHER_CLOCKS = re.compile(
    r"\bTask\.sleep\(|\basyncAfter\(|\bTimer\.|\bThread\.sleep|\busleep\(|\bnanosleep\(|(?<![\w.])sleep\(|\bContinuousClock\b|\bSuspendingClock\b"
    r"|\bDate\(\)|\bDate\.now\b|\bDispatchWallTime\b|\bDispatchWorkItem\b|\bDispatchQueue\.global\b|\bOperationQueue\b|\bCFAbsoluteTimeGetCurrent\(|\bCACurrentMediaTime\(|\bmach_absolute_time\("
    r"|\bclock_gettime|\bDispatchSource\.makeTimerSource|\bperform\(.*afterDelay:|\bRunLoop\b.*\brun\(")


# Where the machine's clock does no harm: the file, what is written there, and why.
ALLOWED = [
    ("ArborKit/Controller/Controller.swift", "Date()", "the default of `now`, which the stories replace by the model's clock (tests/StoreyTwo.swift)"),
    ("ArborKit/Support/Log.swift", "Date()", "the time stamp of a line in arbor.log, which nothing reads back"),
    ("ArborKit/Platform/InstanceLock.swift", "usleep(", "the app's wait for another Arbor's lock on a real file, at launch; no story takes the lock"),
]


def main():
    root = sys.argv[1]
    strict = [os.path.join(root, sys.argv[2])]
    threads = [os.path.join(root, named) for named in sys.argv[3:]]
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
                is_strict = any(path == named or path.startswith(named + os.sep) for named in strict)
                has_threads = any(path == named or path.startswith(named + os.sep) for named in threads)
                for pattern, replacement in REWRITES + (THREADS if has_threads else []):
                    new = pattern.sub(replacement, new)
                if new != line:
                    lines[number] = new
                    changed = True
                code = new.split("//")[0]
                match = OTHER_CLOCKS.search(code)
                if match and is_strict and (os.path.relpath(path, root), match.group(0)) not in [(file, what) for file, what, _ in ALLOWED]:
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
