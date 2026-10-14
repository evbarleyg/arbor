#!/usr/bin/env python3
"""Runs one CI step and publishes its outcome as check annotations.

Contributors without a Mac prove their work through CI, and a check's annotations are easier to come by than its logs.
Annotations can be read through the GitHub REST API (see "Executors without a Mac" in
collab/README.md), so this wrapper puts what matters there:

  the step passed   the end of its output as one notice, or the lines --summary picks, one each
  the step failed   what the compiler and Swift Testing reported as errors, on their file and line
                    where the output names them, then the end of the output as one last error

The command's output is passed through unchanged. So is its exit code, as a shell would report it.

Usage: scripts/ci-step.py [--log FILE] [--summary REGEX] <step name> <command> [argument…]
  --log FILE        also save the output to FILE
  --summary REGEX   what to publish of a long output when the step passes
"""

import argparse
import os
import re
import signal
import subprocess
import sys

from parity import ANSI

# GitHub shows at most ten annotations of each level per step.
LIMIT = 10
PASSED_LINES = 20
FAILED_LINES = 60
CHARACTERS = 20000

# Arbor's own scripts print little enough that the end of their output covers them.
FAILURE = re.compile(r"error:|✘")
# Swift Testing's notes under an issue.
DETAIL = re.compile(r"^\s*↳")
# Swift Testing's closing lines, which repeat what the issues said.
CLOSING = re.compile(r"✘ (Test|Suite) .* failed after")
# The compiler repeats each message under an excerpt of the source.
EXCERPT = re.compile(r"^\s*(\d+ )?[|`]")
LOCATION = re.compile(r"^(/\S+?):(\d+):(\d+): error: (.*)$")


def escape(text, is_property=False):
    text = text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    if is_property:
        text = text.replace(":", "%3A").replace(",", "%2C")
    return text


def annotate(level, title, message, **properties):
    fields = {"title": title, **properties}
    listed = ",".join(f"{key}={escape(str(value), True)}" for key, value in fields.items())
    print(f"::{level} {listed}::{escape(message)}", flush=True)


def unique(lines):
    seen = set()
    return [line for line in lines if not (line in seen or seen.add(line))]


def end_of(lines, count):
    return "\n".join(lines[-count:])[-CHARACTERS:] or "(no output)"


def failures(lines):
    """What went wrong, one entry per error or issue (with its notes), the most telling first."""
    found, in_issue = [], False
    for line in lines:
        if EXCERPT.match(line):
            continue
        if FAILURE.search(line):
            found.append(line.strip())
            in_issue = True
        elif in_issue and DETAIL.match(line):
            found[-1] += "\n" + line.strip()
        else:
            in_issue = False
    return sorted(unique(found), key=lambda entry: bool(CLOSING.search(entry)))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--log", help="also save the output to this file")
    parser.add_argument("--summary", help="what to publish when the step passes")
    parser.add_argument("name")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not args.command:
        parser.error("no command given")
    summary = re.compile(args.summary) if args.summary else None

    try:
        process = subprocess.Popen(args.command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   encoding="utf-8", errors="replace")
    except OSError as error:
        annotate("error", f"{args.name} could not start", str(error))
        return 127
    raw = []
    for line in process.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()
        raw.append(line)
    code = process.wait()

    if args.log:
        with open(args.log, "w", encoding="utf-8") as handle:
            handle.writelines(raw)
    lines = [ANSI.sub("", line.rstrip("\n")) for line in raw]

    if code == 0:
        if summary:
            for line in unique(l.strip() for l in lines if summary.search(l))[:LIMIT]:
                annotate("notice", args.name, line)
        else:
            annotate("notice", args.name, end_of(lines, PASSED_LINES))
        return 0

    root = os.getcwd() + os.sep
    for line in failures(lines)[:LIMIT - 1]:
        located = LOCATION.match(line)
        if located and located.group(1).startswith(root):
            path, row, column, message = located.groups()
            annotate("error", args.name, message, file=path[len(root):], line=row, col=column)
        else:
            annotate("error", args.name, line)
    if code < 0:
        outcome, code = f"was killed by {signal.Signals(-code).name}", 128 - code
    else:
        outcome = f"failed with exit code {code}"
    annotate("error", f"{args.name} {outcome}", end_of(lines, FAILED_LINES))
    return code


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        # The wrapper's own fault (a bad --summary, an unwritable --log). Say so where it can be read.
        annotate("error", "ci-step.py failed", f"{type(error).__name__}: {error}")
        raise
