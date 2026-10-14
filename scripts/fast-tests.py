#!/usr/bin/env python3
"""The tests in a quarter of the time: on every core of a machine, and divided among several machines. Nothing may be lost on the way.

`swift test` takes eleven minutes on four cores, and wastes most of them. Half the time it compiles the tests, on all cores. The other
half it runs them on ONE: nearly every test is bound to the main actor, so they queue. Hence two things, each of use alone.

ON EVERY CORE (`run`). Each test file is run by a process of its own, as many at a time as there are cores, the biggest files
first. A process starts in a seventh of a second. What a file prints stays together. Afterwards each file is held to its source:
as many tests must have run as it declares, so a filter that matches nothing, which `swift test` lets pass, fails here.

AMONG SEVERAL MACHINES (`cut`, `join`). Running on several machines saves little as long as each compiles everything. A machine must compile only
its share, and yet the test files are one module: a file may use a helper that another declares. So a part keeps every file,
and takes out of the files that are not its own only the functions marked `@Test`, which is where the time goes. Suites, helpers,
extensions and whatever else a file declares stay for the others to use: nobody who writes a test has a rule to keep. Each
part is built from nothing, so there is no cache that could be stale.

  run             Builds the tests (not with --no-build) and runs them as said. --jobs N: that many at a time. --log FILE: all output, as
                  scripts/parity.py reads it. --record FILE: one line per test, `<id><tab>passed|failed|skipped`, sorted, the format of
                  scripts/ci-tests.py. No record is written of a run that cannot be trusted. On Linux only.
  plan N          Which file belongs to which of N parts, and how heavy each part is. Every file under Tests/ is in exactly one:
                  the heaviest first, each to the part that is lightest so far. No list to keep: a new file finds its place.
  cut K N         Makes the checkout part K of N (1 to N). IT CHANGES THE FILES UNDER Tests/, so it wants --spoil, or CI=true as
                  GitHub sets it. Lines keep their numbers.
  join FILE…      The net. Takes the records of all parts, in a checkout that was NOT cut, and fails if a test is in two of them, if
                  a record is empty, or if together they hold another number of tests than the sources declare for Linux.
                  --record FILE writes them as one.

What is compiled for a part is not the checkout, so where work is integrated CI also builds and runs the tests whole.

Usage:
  scripts/fast-tests.py run [--jobs N] [--no-build] [--log FILE] [--record FILE]
  scripts/fast-tests.py plan N
  scripts/fast-tests.py cut K N [--spoil]
  scripts/fast-tests.py join [--record FILE] RECORD…
  Each takes --root DIR: another checkout than the one this script is in.
"""

import argparse
import concurrent.futures
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OPENING = {"(": ")", "[": "]", "{": "}"}
WORD = re.compile(r"[A-Za-z_]\w*")
IN_A_STRING = re.compile(r"""["\\\n]""")
OF_INTEREST = re.compile(r"""["#/@(){}\[\]]""")
# What may stand before a `/` that begins a regular expression and not a division.
BEFORE_A_REGEX = re.compile(r"(?:[=(,:\[{!&|?]|\breturn|\bin)\s*$")
# An attribute with its arguments, if they hold no bracket of their own, and the space after it.
ATTRIBUTE_BEFORE = re.compile(r"@\w+(?:\([^()]*\))?\s*$")
CONDITION = re.compile(r"#(if|elseif|else|endif)\b([^\n]*)")
# What a compile-time condition may ask, and the answer on Linux. CoreGraphics is left out on purpose: there is a module of that
# name here (Sources/LinuxShims), so the answer is not what it looks like. Whatever is not listed is refused, loudly.
ON_LINUX = {
    "os": {"Linux": True, "macOS": False, "iOS": False, "tvOS": False, "watchOS": False, "visionOS": False, "Windows": False},
    "canImport": {"Foundation": True, "Glibc": True, "Testing": True, "AppKit": False, "Carbon": False, "QuartzCore": False,
                  "SwiftUI": False, "ApplicationServices": False, "ScreenCaptureKit": False, "Darwin": False, "Combine": False},
}
# Compiling an expectation costs far more than compiling a line, and every file costs a little.
PER_FILE, PER_LINE, PER_EXPECTATION = 40, 1, 12
EXPECTATION = re.compile(r"#(?:expect|require)\b")
PASSED, FAILED, SKIPPED = "passed", "failed", "skipped"
# The place in the source at the end of a test's id. It differs between the branches of a compile-time condition.
LOCATION = re.compile(r"/[^/]+\.swift:\d+:\d+$")


class Unreadable(Exception):
    """Swift this does not understand. Better to stop than to cut in the wrong place."""


def after_string(text, start):
    """The index after the string literal that begins at `start`, which is at its first `#` or `"`."""
    index = start
    while text[index] == "#":
        index += 1
    hashes = "#" * (index - start)
    # Three quotation marks open a string of several lines only at the end of a line: #""""# is two of them between two.
    quote = '"""' if re.match(r'"""[ \t]*\n', text[index:index + 80]) else '"'
    index += len(quote)
    while index < len(text):
        found = IN_A_STRING.search(text, index)
        index = found.start() if found else len(text)
        if text.startswith(quote + hashes, index):
            return index + len(quote) + len(hashes)
        if text.startswith("\\" + hashes, index):
            index += 1 + len(hashes)
            if text.startswith("(", index):
                index = closing(text, index)
            index += 1
        elif text[index] == "\n" and quote == '"':
            break
        else:
            index += 1
    raise Unreadable(f"a string that does not end, from line {text.count(chr(10), 0, start) + 1}")


def after_what_is_no_code(text, index):
    """The index after the comment, string or regular expression that begins at `index`, or None if code does."""
    if text.startswith("//", index):
        end = text.find("\n", index)
        return len(text) if end < 0 else end
    if text.startswith("/*", index):
        depth, index = 1, index + 2
        while depth and index < len(text):
            if text.startswith("/*", index):
                depth, index = depth + 1, index + 2
            elif text.startswith("*/", index):
                depth, index = depth - 1, index + 2
            else:
                index += 1
        return index
    if text[index] == '"' or re.match(r'#+"', text[index:index + 8]):
        return after_string(text, index)
    extended = re.match(r"#+/", text[index:index + 8])
    if extended:
        end = text.find("/" + "#" * (len(extended.group()) - 1), index + len(extended.group()))
        if end < 0:
            raise Unreadable(f"a regular expression that does not end, from line {text.count(chr(10), 0, index) + 1}")
        return end + len(extended.group())
    if text[index] == "/" and text[index + 1:index + 2] not in ("", " ", "\n", "=") \
            and BEFORE_A_REGEX.search(text[max(0, index - 12):index]):
        end = index + 1
        while end < len(text) and text[end] not in "/\n":
            end += 2 if text[end] == "\\" else 1
        if text[end:end + 1] == "/":
            return end + 1
    return None


def next_of_interest(text, index):
    """The index of the next character that can begin or end anything this looks for. Reading every character takes minutes."""
    found = OF_INTEREST.search(text, index)
    return found.start() if found else len(text)


def closing(text, start):
    """The index of the bracket that closes the one at `start`."""
    expected, index = [OPENING[text[start]]], start + 1
    while index < len(text):
        index = next_of_interest(text, index)
        if index >= len(text):
            break
        skipped = after_what_is_no_code(text, index)
        if skipped is not None:
            index = skipped
            continue
        character = text[index]
        if character in OPENING:
            expected.append(OPENING[character])
        elif character in ")]}":
            if character != expected.pop():
                break
            if not expected:
                return index
        index += 1
    raise Unreadable(f"a bracket that is not closed, on line {text.count(chr(10), 0, start) + 1}")


def on_linux(condition, line):
    """Whether a compile-time condition holds on Linux."""
    def answer(match):
        known = ON_LINUX[match.group(1)]
        if match.group(2) not in known:
            raise Unreadable(f"a condition whose answer on Linux nobody has written down, on line {line}: {condition.strip()}")
        return str(known[match.group(2)])

    words = re.sub(r"\b(os|canImport)\(\s*(\w+)\s*\)", answer, condition.split("//")[0])
    words = words.replace("&&", " and ").replace("||", " or ").replace("!", " not ")
    if not words.strip() or re.sub(r"\b(True|False|and|or|not)\b|[()\s]", "", words):
        raise Unreadable(f"a condition this cannot work out, on line {line}: {condition.strip()}")
    try:
        return bool(eval(words, {"__builtins__": {}}))  # only the six words and brackets are left
    except SyntaxError as error:
        raise Unreadable(f"a condition this cannot work out, on line {line}: {condition.strip()}") from error


def tests_in(text):
    """Of each function marked `@Test`: where it begins (with its attributes), where it ends (after its closing brace), and whether Linux compiles it."""
    found, index = [], 0
    # Of each condition that is open: whether a branch has been taken, and whether this one is.
    branches = []
    while index < len(text):
        index = next_of_interest(text, index)
        if index >= len(text):
            break
        skipped = after_what_is_no_code(text, index)
        if skipped is not None:
            index = skipped
            continue
        condition = CONDITION.match(text, index) if text[index] == "#" else None
        if condition:
            line = text.count("\n", 0, index) + 1
            word = condition.group(1)
            if word != "if" and not branches:
                raise Unreadable(f"#{word} without an #if, on line {line}")
            if word == "if":
                holds = on_linux(condition.group(2), line)
                branches.append([holds, holds])
            elif word == "elseif":
                holds = not branches[-1][0] and on_linux(condition.group(2), line)
                branches[-1] = [branches[-1][0] or holds, holds]
            elif word == "else":
                branches[-1] = [True, not branches[-1][0]]
            else:
                branches.pop()
            index = condition.end()
            continue
        if not (text.startswith("@Test", index) and not WORD.match(text, index + 5)):
            index += 1
            continue
        start = index
        while True:
            before = ATTRIBUTE_BEFORE.search(text, 0, start)
            if not before:
                break
            start = before.start()
        index += len("@Test")
        is_function = False
        while index < len(text):
            skipped = after_what_is_no_code(text, index)
            if skipped is not None:
                index = skipped
            elif text[index] == "{":
                break
            elif text[index] in OPENING:
                index = closing(text, index) + 1
            elif text[index] in ")]}":
                index = len(text)
            else:
                word = WORD.match(text, index)
                is_function = is_function or bool(word and word.group() == "func")
                index = word.end() if word else index + 1
        if index >= len(text) or not is_function:
            raise Unreadable(f"an @Test without a function after it, on line {text.count(chr(10), 0, start) + 1}")
        index = closing(text, index) + 1
        found.append((start, index, all(taken for _, taken in branches)))
    if branches:
        raise Unreadable("an #if without its #endif")
    return found


def declared(text):
    """How many tests a file has on Linux."""
    return sum(1 for _, _, compiled in tests_in(text) if compiled)


def without_tests(text):
    """The text without its tests, every other line where it was."""
    kept, position = [], 0
    for start, end, _ in tests_in(text):
        kept += [text[position:start], "\n" * text.count("\n", start, end)]
        position = end
    return "".join(kept) + text[position:]


def test_files(root):
    return sorted(os.path.relpath(path, root).replace(os.sep, "/")
                  for path in glob.glob(os.path.join(root, "Tests", "**", "*.swift"), recursive=True))


def read(root, name):
    with open(os.path.join(root, name), encoding="utf-8") as handle:
        return handle.read()


def weight(text):
    """About how long a file's tests take to compile, in lines. What is not a test is compiled by every part and weighs nothing."""
    tests = "".join(text[start:end] for start, end, compiled in tests_in(text) if compiled)
    if not tests:
        return 0
    return PER_FILE + PER_LINE * tests.count("\n") + PER_EXPECTATION * len(EXPECTATION.findall(tests))


def plan(weights, parts):
    """A list of parts, each a list of names. The same for the same files, whoever asks."""
    shares = [[0, number, []] for number in range(parts)]
    for name in sorted(weights, key=lambda name: (-weights[name], name)):
        lightest = min(shares)
        lightest[0] += weights[name]
        lightest[2].append(name)
    return [sorted(names) for _, _, names in shares]


def planned(root, parts):
    weights = {name: weight(read(root, name)) for name in test_files(root)}
    return weights, plan(weights, parts)


def cut(root, part, parts):
    """Returns how many tests stay and how many went, of those Linux compiles."""
    _, shares = planned(root, parts)
    stay = gone = 0
    for number, names in enumerate(shares, start=1):
        for name in names:
            text = read(root, name)
            if number == part:
                stay += declared(text)
                continue
            gone += declared(text)
            shorter = without_tests(text)
            if tests_in(shorter) or shorter.count("\n") != text.count("\n"):
                raise Unreadable(f"{name}: the cut went wrong")
            with open(os.path.join(root, name), "w", encoding="utf-8") as handle:
                handle.write(shorter)
    return stay, gone


# MARK: run

def outcome_of(events):
    """{id with its place: passed|failed|skipped} for every test function in the event stream of one process. Raises when it proves nothing.

    As `record_of` in scripts/ci-tests.py reads it, where the shapes are explained; but the place stays in the id until the tests are counted.
    """
    functions, skipped, failed, finished, started, ended = set(), set(), set(), set(), 0, 0
    for line in events.split("\n"):
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
            kind, payload = entry["kind"], entry["payload"]
        except (ValueError, KeyError, TypeError) as error:
            raise Unreadable("a line of the event stream cannot be read: was the process killed?") from error
        if kind == "test":
            if payload.get("kind") == "function":
                functions.add(payload["id"])
            continue
        what, test = payload.get("kind"), payload.get("testID")
        started += what == "runStarted"
        ended += what == "runEnded"
        if what == "testSkipped":
            skipped.add(test)
        elif what == "testEnded":
            finished.add(test)
        elif what == "issueRecorded":
            issue = payload.get("issue", {})
            if issue.get("isFailure", not issue.get("isKnown", False)):
                failed.add(test)
    if started != 1 or ended != 1:
        raise Unreadable("the run did not finish (a crash?)" if started > ended else "the event stream holds no test run")
    outcome = {}
    for test in functions:
        if test not in failed | finished | skipped:
            raise Unreadable(f"{test} was to run, and nothing says what became of it")
        outcome[test] = FAILED if test in failed else PASSED if test in finished else SKIPPED
    return outcome


def judged(name, expected, code, events):
    """What one file's process proved: its tests' outcomes, and what is wrong, if anything."""
    try:
        outcome = outcome_of(events)
    except Unreadable as error:
        return {}, f"{name}: {error} (exit code {code})"
    failures = sum(1 for value in outcome.values() if value == FAILED)
    if len(outcome) != expected:
        return outcome, f"{name} declares {expected} tests and {len(outcome)} ran"
    if failures:
        return outcome, f"{name}: {failures} of {expected} tests failed"
    if code != 0:
        return outcome, f"{name}: exit code {code}, though no test is said to have failed"
    return outcome, None


def as_record(outcomes):
    """One line per test. Two functions that differ only in the types they take share an id: then the worse news counts."""
    record = {}
    for test, outcome in outcomes.items():
        name = LOCATION.sub("", test)
        record[name] = next(worse for worse in (FAILED, SKIPPED, PASSED) if worse in (outcome, record.get(name)))
    return "".join(f"{name}\t{outcome}\n" for name, outcome in sorted(record.items()))


def run_one(root, products, name, folder):
    """Runs the tests of one file. Returns its name, the exit code, what it printed, its event stream and how long it took."""
    target, file = name.split("/")[1], name.rsplit("/", 1)[1]
    events = os.path.join(folder, name.replace("/", "-") + ".jsonl")
    command = [os.path.join(products, f"{target}-test-runner"), "--testing-library", "swift-testing", "--filter", f"/{re.escape(file)}:",
               "--event-stream-output-path", events, "--event-stream-version", "0"]
    began = time.monotonic()
    process = subprocess.run(command, cwd=root, env={**os.environ, "LD_LIBRARY_PATH": products, "NO_COLOR": "1"}, check=False,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding="utf-8", errors="replace")
    stream = ""
    if os.path.exists(events):
        with open(events, encoding="utf-8", errors="replace") as handle:
            stream = handle.read()
    return name, process.returncode, process.stdout, stream, time.monotonic() - began


def command_run(args):
    root = args.root
    for path in (args.record, args.log):
        if path and os.path.exists(path):
            os.remove(path)  # what an earlier run left must not pass for this one's
    if not args.no_build:
        code = subprocess.run(["swift", "build", "--build-tests"], cwd=root, check=False).returncode
        if code != 0:
            return code
    products = os.path.realpath(os.path.join(root, ".build", "debug"))
    texts = {name: read(root, name) for name in test_files(root)}
    expected = {name: declared(text) for name, text in texts.items()}
    names = sorted((name for name in texts if expected[name]), key=lambda name: (-weight(texts[name]), name))
    missing = sorted({name.split("/")[1] for name in names if not os.access(os.path.join(products, name.split("/")[1] + "-test-runner"), os.X_OK)})
    if missing:
        print(f"✘ fast-tests.py: nothing to run the tests of {', '.join(missing)} with in .build/debug. It works on Linux only; on a Mac say swift test.")
        return 2

    began = time.monotonic()
    outcomes, wrong, seconds = {}, [], {}
    log = open(args.log, "w", encoding="utf-8") if args.log else None
    with tempfile.TemporaryDirectory() as folder, concurrent.futures.ThreadPoolExecutor(args.jobs) as pool:
        for done in concurrent.futures.as_completed([pool.submit(run_one, root, products, name, folder) for name in names]):
            name, code, output, events, took = done.result()
            outcome, problem = judged(name, expected[name], code, events)
            outcomes.update(outcome)
            seconds[name] = took
            if log:
                log.write(output)
            if problem:
                wrong.append(problem)
            # A file that passed has nothing to say that the record does not.
            if problem or args.verbose:
                sys.stdout.write(output)
                sys.stdout.flush()
    if log:
        log.close()

    slowest = sorted(seconds, key=seconds.get, reverse=True)[:5]
    counts = {kind: sum(1 for value in outcomes.values() if value == kind) for kind in (PASSED, FAILED, SKIPPED)}
    print(f"{len(outcomes)} tests of {len(names)} files in {time.monotonic() - began:.0f} s, {args.jobs} files at a time "
          f"(one after another: {sum(seconds.values()):.0f} s): " + ", ".join(f"{count} {kind}" for kind, count in counts.items()))
    print("the slowest files: " + ", ".join(f"{name.rsplit('/', 1)[1]} {seconds[name]:.0f} s" for name in slowest))
    for problem in sorted(wrong):
        print(f"✘ {problem}")
    if wrong:
        return 1
    if args.record:
        with open(args.record, "w", encoding="utf-8") as handle:
            handle.write(as_record(outcomes))
    return 0


# MARK: join

def joined(records, expected):
    """All records as one dictionary, and what is wrong with them. `records`: name and text of each; `expected`: how many tests there are."""
    whole, wrong = {}, []
    for name, text in records:
        lines = [line for line in text.split("\n") if line.strip()]
        if not lines:
            wrong.append(f"{name} is empty: that part ran nothing")
        for line in lines:
            test, tab, outcome = line.rpartition("\t")
            if not tab or outcome not in (PASSED, FAILED, SKIPPED):
                wrong.append(f"{name}: not a line of a record: {line[:120]}")
            elif test in whole:
                wrong.append(f"{test} ran in two parts, the second time in {name}")
            else:
                whole[test] = outcome
    if len(whole) != expected:
        wrong.append(f"the sources declare {expected} tests and the parts ran {len(whole)}")
    return whole, wrong


def command_join(args):
    expected = sum(declared(read(args.root, name)) for name in test_files(args.root))
    texts = []
    for name in args.records:
        with open(name, encoding="utf-8") as handle:
            texts.append((name, handle.read()))
    whole, wrong = joined(texts, expected)
    for problem in wrong:
        print(f"✘ {problem}")
    if wrong:
        return 1
    if args.record:
        with open(args.record, "w", encoding="utf-8") as handle:
            handle.writelines(f"{test}\t{whole[test]}\n" for test in sorted(whole))
    counts = {kind: sum(1 for value in whole.values() if value == kind) for kind in (PASSED, FAILED, SKIPPED)}
    print(f"{len(whole)} tests in {len(texts)} parts, each in exactly one, as many as the sources declare: "
          + ", ".join(f"{count} {kind}" for kind, count in counts.items()))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("run", "plan", "cut", "join"):
        command = commands.add_parser(name)
        command.add_argument("--root", default=ROOT, help="the checkout (default: the one this script is in)")
        if name == "run":
            command.add_argument("--jobs", type=int, default=os.cpu_count() or 1, help="how many files at a time (default: one to a core)")
            command.add_argument("--no-build", action="store_true", help="the tests are built")
            command.add_argument("--verbose", action="store_true", help="print what the files that pass print, too")
            command.add_argument("--log", help="all output goes here")
        if name == "cut":
            command.add_argument("part", type=int)
            command.add_argument("--spoil", action="store_true", help="yes, change the files under Tests/")
        if name in ("plan", "cut"):
            command.add_argument("parts", type=int)
        if name in ("run", "join"):
            command.add_argument("--record", help="write the record to this file")
        if name == "join":
            command.add_argument("records", nargs="+")
    args = parser.parse_args()

    if args.command == "run":
        if args.jobs < 1:
            parser.error("at least one at a time")
        return command_run(args)
    if args.command == "join":
        return command_join(args)
    if args.parts < 1:
        parser.error("at least one part")
    if args.command == "plan":
        weights, shares = planned(args.root, args.parts)
        for number, names in enumerate(shares, start=1):
            print(f"part {number} of {args.parts}: {len(names)} files, weight {sum(weights[name] for name in names)}")
            for name in names:
                print(f"  {weights[name]:6} {name}")
        return 0
    if not 1 <= args.part <= args.parts:
        parser.error(f"part {args.part} of {args.parts}?")
    if not args.spoil and os.environ.get("CI") != "true":
        parser.error("this changes the files under Tests/. Say --spoil in a copy you can throw away.")
    stay, gone = cut(args.root, args.part, args.parts)
    print(f"part {args.part} of {args.parts}: {stay} tests stay, {gone} are left to the other parts")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Unreadable as error:
        print(f"✘ fast-tests.py: {error}")
        sys.exit(2)
