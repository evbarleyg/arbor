#!/usr/bin/env python3
"""Lets CI's Mac run only the tests a Mac can say something about, and proves that no test was dropped on the way.

Nearly every test drives the same code on Linux and on macOS, and the `linux` job has run it on the same commit. A hosted
Mac is the scarce machine. So in an ordinary pull request it runs a selection; where work is integrated, and when asked,
it runs everything (scripts/ci-changes.py decides: `tests=mac-only` or `tests=full`). Four commands:

  select    The test files that may behave differently on a Mac, or exist only there, each with the reason, and the
            `swift test --filter` that runs them. Read from the sources, and generous: a compile-time condition, a trait
            that switches a test on or off, an import nobody has vouched for, a question about the user, real files,
            sockets, processes, threads and clocks, and the files in ALWAYS.
  run       `swift test`, on everything or on the selection, and the record of it (see `record`). With --all also the
            list of every test the build contains, selected or not. Output and exit code are those of `swift test`,
            unless the record cannot be trusted: then it says why and fails.
  record    From the event stream `swift test` wrote: a sorted text file, one line per test function,
            `<id><tab>passed|failed|skipped`. The id is `swift test list`'s, Module.Suite/Inner/function(label:), the same
            on both platforms. No record is written of a run that did not finish.
  account   The net. Takes the Mac's record, the Mac's list and Linux's record, and fails if any test ran nowhere: the
            selection missed a test that only a Mac compiles, or that Linux skips; a test is skipped on both; a record is
            missing, empty, or speaks of other tests than the list. Each such test becomes an error annotation. The
            summary says how many tests ran where, and in which mode the Mac ran and why.

What `swift test` 6.4 does, found by trying (the self-test scripts/test-ci-tests.py holds the shapes):

  --filter takes a regular expression and searches for it in Module.Suite/Inner/function(label:)/File.swift:line:column. So a
  file can be named, which covers whatever stands in it: tests outside a suite, nested suites, an extension of a suite
  from another file. Display names are not searched. A suite that matches brings all its tests. Several filters add
  up. A filter that matches nothing is a warning and exit code 0, hence the checks here.

  --event-stream-output-path FILE --event-stream-version 0 (options --help hides; version 0 is the stable one) writes a
  JSON object per line: every test about to run, then what happened. Each test target is a run of its own in the same
  file. A crash leaves a "runStarted" without its "runEnded". The file of --xunit-output simply lacks the
  target that crashed and looks complete, so it is not used.

  The line and column must go from the id: a test that is `.disabled` off macOS stands in the `#else` branch, on another line.

Usage:
  scripts/ci-tests.py select [--root DIR]
  scripts/ci-tests.py run --mode full|mac-only --record FILE [--all FILE] [argument for swift test…]
  scripts/ci-tests.py record EVENTS FILE
  scripts/ci-tests.py account --mac FILE --mac-all FILE --linux FILE [--mode MODE] [--why TEXT]
"""

import argparse
import glob
import importlib.util
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FULL, MAC_ONLY = "full", "mac-only"
PASSED, FAILED, SKIPPED = "passed", "failed", "skipped"

# Files without any mark that are about the platform all the same. Say why.
ALWAYS = {
    # Pins what Arbor relies on in CGRect, which is CoreGraphics' on macOS and Foundation's on Linux.
    "Tests/ArborCoreTests/GeometryTests.swift": "pins the CGRect of each platform",
}

# Tests that run neither on CI's Mac nor on CI's Linux, on purpose. Every entry is a decision: say why, and who runs it instead.
NOWHERE_ON_PURPOSE = {
    # Debug lines are written only with ARBOR_DEBUG set, which CI does not do; without it the test would pass idly.
    # scripts/privacy-smoke.sh (`make check`) tries the same refusals with debug logging on. By hand:
    # ARBOR_DEBUG=1 swift test --filter whatIsRefusedWhileTheViewIsHeld
    "ArborKitTests.FinderTests/whatIsRefusedWhileTheViewIsHeldIsLoggedWithoutItsWords()",
}

# Modules that are the same code on both platforms, or close enough that importing them says nothing. CoreGraphics is here because
# off macOS only its geometry types exist, so whatever else a test wants of it stands behind a compile-time condition. ArborIPC is
# not: it is the socket, which each system implements in its own way.
PORTABLE = {"Testing", "Foundation", "CoreGraphics", "ArborCore", "ArborKit", "ArborTesting"}

IMPORT = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*import\s+(?:(?:struct|class|enum|protocol|func|var|let|typealias)\s+)?(\w+)", re.M)
ATTRIBUTE = re.compile(r"@(?:Test|Suite)\s*\(")
CONDITION_TRAIT = re.compile(r"\.(?:enabled|disabled)\b")
DECLARES_A_TEST = re.compile(r"@Test\b")
# What to look for in the text of a file, and what to call it.
MARKS = [
    ("a compile-time condition", re.compile(r"^\s*#(?:if|elseif)\b", re.M)),
    ("asks who the user is", re.compile(r"\bgete?uid\b")),
    ("real files", re.compile(r"\b(?:FileManager|FileHandle|NSTemporaryDirectory|NSHomeDirectory)\b|#filePath\b")),
    ("processes", re.compile(r"\bProcess\(\)|\bposix_spawn|\bkill\(|\bgetpid\b")),
    ("sockets", re.compile(r"\bsocket\(|\bsockaddr|\bUnixSocket\b")),
    ("threads and clocks", re.compile(r"\b(?:DispatchQueue|DispatchSemaphore|DispatchSource|Thread|RunLoop|Timer)\b|\b(?:Task\.sleep|usleep|sleep)\(")),
    ("the language of the machine", re.compile(r"\b(?:Locale|TimeZone|Calendar|DateFormatter|NumberFormatter)\b|\blocalized")),
]

# Comments, and what stands between quotation marks: an app called "Calendar" is no question about the calendar.
WORDS = re.compile(r'//[^\n]*|/\*.*?\*/|""".*?"""|"(?:\\.|[^"\\\n])*"', re.S)

LOCATION = re.compile(r"/[^/]+\.swift:\d+:\d+$")
LISTED = re.compile(r"^[A-Za-z_]\w*\.\S.*\)$")
# GitHub shows at most ten annotations of each level per step (ci-step.py keeps to the same number).
LIMIT = 10


class Untrustworthy(Exception):
    """A record, a list or a selection that proves nothing."""


def sibling(name):
    """Another script as a module, though its file name is no module name. It may import its own neighbours by name."""
    if os.path.join(ROOT, "scripts") not in sys.path:
        sys.path.insert(0, os.path.join(ROOT, "scripts"))
    spec = importlib.util.spec_from_file_location(name[:-len(".py")].replace("-", "_"), os.path.join(ROOT, "scripts", name))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Annotations as every other step publishes them. What is printed besides avoids the marks ci-step.py looks for in the output of a
# failed step, so that nothing is said twice when a command runs under it.
annotate = sibling("ci-step.py").annotate


def in_brackets(text, start):
    """The text from the bracket at `start` to the one that closes it, or to the end when none does: rather too much than too little."""
    depth = 0
    for index in range(start, len(text)):
        depth += {"(": 1, ")": -1}.get(text[index], 0)
        if depth == 0:
            return text[start:index + 1]
    return text[start:]


def marks_in(text):
    """Why a Mac may have something of its own to say about a test file with this text. Empty when nothing suggests it."""
    text = WORDS.sub(lambda match: '""' if match.group().startswith('"') else "", text)
    found = [name for name, pattern in MARKS if pattern.search(text)]
    if any(CONDITION_TRAIT.search(in_brackets(text, match.end() - 1)) for match in ATTRIBUTE.finditer(text)):
        found.append("a trait that switches a test on or off")
    foreign = sorted(set(IMPORT.findall(text)) - PORTABLE)
    if foreign:
        found.append("imports " + ", ".join(foreign))
    return found


def select(sources, always=None):
    """{path: reason} for the files to run on the Mac, out of {path: text}. Files that declare no test cannot be run."""
    always = ALWAYS if always is None else always
    chosen = {}
    for path, text in sources.items():
        reasons = ([always[path]] if path in always else []) + marks_in(text)
        if reasons and DECLARES_A_TEST.search(text):
            chosen[path] = "; ".join(reasons)
    return chosen


def filters_for(paths):
    """One regular expression per test target, for `swift test --filter`: every test that stands in one of these files."""
    by_target = {}
    for path in paths:
        parts = path.split("/")
        by_target.setdefault(parts[1], set()).add(parts[-1])
    return [
        "^%s\\..*/(%s):\\d+:\\d+$" % (re.escape(target), "|".join(re.escape(name) for name in sorted(names)))
        for target, names in sorted(by_target.items())
    ]


def read_sources(root):
    sources = {}
    for path in sorted(glob.glob(os.path.join(root, "Tests", "**", "*.swift"), recursive=True)):
        with open(path, encoding="utf-8") as handle:
            sources[os.path.relpath(path, root).replace(os.sep, "/")] = handle.read()
    return sources


def missing_from(always, sources):
    """A file that was renamed takes its place in ALWAYS with it, or the list rots unnoticed."""
    return sorted(set(always) - set(sources))


def lines_of(text):
    """Not `splitlines`, which also breaks at U+2028 and its like: the event stream quotes the arguments of tests, odd names among them."""
    lines = text.split("\n")
    return lines[:-1] if lines[-1] == "" else lines


def test_id(identifier):
    """The id without the place in the source, which differs between the branches of a compile-time condition."""
    return LOCATION.sub("", identifier)


def record_of(lines):
    """{id: passed|failed|skipped} for every test function in an event stream. Raises when the stream proves nothing."""
    functions, skipped, failed, finished, started, ended = set(), set(), set(), set(), 0, 0
    for line in lines:
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
            kind, payload = entry["kind"], entry["payload"]
        except (ValueError, KeyError, TypeError) as error:
            # The last line of a process that was killed, say.
            raise Untrustworthy(f"a line of the event stream cannot be read ({type(error).__name__})") from error
        if kind == "test":
            if payload.get("kind") == "function":
                functions.add(payload["id"])
            continue
        what, test = payload.get("kind"), payload.get("testID")
        if what == "runStarted":
            started += 1
        elif what == "runEnded":
            ended += 1
        elif what == "testSkipped":
            skipped.add(test)
        elif what == "testEnded":
            finished.add(test)
        elif what == "issueRecorded":
            issue = payload.get("issue", {})
            # Later versions of the stream say outright whether an issue fails the test (a warning does not).
            if issue.get("isFailure", not issue.get("isKnown", False)):
                failed.add(test)
    if started == 0:
        raise Untrustworthy("the event stream holds no test run")
    if ended != started:
        raise Untrustworthy(f"{started - ended} of {started} test runs did not finish (a crash?)")

    # Tests run side by side and their lines mingle, so the verdict waits for the end of the stream.
    record = {}
    for identifier in functions:
        name = test_id(identifier)
        if identifier in failed:
            status = FAILED
        elif identifier in finished:
            status = PASSED
        elif identifier in skipped:
            status = SKIPPED
        else:
            raise Untrustworthy(f"{name} was to run, and the event stream does not say what became of it")
        # Two functions that differ only in the types they take share an id. Then the worse news counts.
        record[name] = next(worse for worse in (FAILED, SKIPPED, PASSED) if worse in (status, record.get(name)))
    if not record:
        raise Untrustworthy("not one test ran: does the filter still match anything?")
    return record


def as_text(record):
    return "".join(f"{name}\t{status}\n" for name, status in sorted(record.items()))


def record_from_text(text, whose):
    record = {}
    for line in lines_of(text):
        name, tab, status = line.rpartition("\t")
        if not tab or status not in (PASSED, FAILED, SKIPPED):
            raise Untrustworthy(f"{whose}: not a line of a record: {line[:120]!r}")
        record[name] = status
    if not record:
        raise Untrustworthy(f"{whose} is empty")
    return record


def listed_tests(text, whose="the list of tests"):
    """The ids in the output of `swift test list`, whatever else was printed around them."""
    names = {line.strip() for line in lines_of(text) if LISTED.match(line.strip())}
    if not names:
        raise Untrustworthy(f"{whose} is empty")
    return names


def mode_of(text):
    """Only the exact word saves anything. Whatever else arrives (nothing at all, when the deciding job failed) means everything."""
    return MAC_ONLY if text == MAC_ONLY else FULL


def account(mac, mac_all, linux, mode, on_purpose=None):
    """Where every test ran. Returns the groups, and what is wrong: [(test or None, complaint)]."""
    on_purpose = NOWHERE_ON_PURPOSE if on_purpose is None else on_purpose
    on_mac = {name for name, status in mac.items() if status != SKIPPED}
    on_linux = {name for name, status in linux.items() if status != SKIPPED}
    # A test that only Linux compiles and then skips has run nowhere either: the stand-in of a Mac's test that was renamed, say.
    nowhere = (set(mac_all) | set(mac) | set(linux)) - on_mac - on_linux
    groups = {
        "both": on_mac & on_linux,
        "mac": on_mac - on_linux,
        "linux": on_linux - on_mac,
        "on purpose": nowhere & on_purpose,
        "nowhere": nowhere - on_purpose,
    }

    wrong = []
    strangers = sorted(set(mac) - set(mac_all))
    if strangers:
        wrong.append((None, f"the Mac's record has {len(strangers)} tests that its list lacks ({strangers[0]}, say): "
                            "the two do not name tests alike, so nothing can be told"))
    unheard = sorted(set(mac_all) - set(mac))
    if mode == FULL and unheard:
        wrong.append((None, f"the Mac was to run everything, and its record lacks {len(unheard)} tests ({unheard[0]}, say)"))
    for name in sorted(groups["nowhere"]):
        if name not in mac_all:
            why = "only Linux compiles it, and skips it: is it the stand-in of a test the Mac no longer has?"
        elif name in mac:
            why = "the Mac skipped it, and " + ("so did Linux" if name in linux else "Linux does not compile it")
        else:
            why = ("Linux skipped it" if name in linux else "Linux does not compile it") + ", and the selection for the Mac left it out"
        wrong.append((name, why))
    return groups, wrong


def stale(groups, on_purpose=None):
    """Entries of NOWHERE_ON_PURPOSE that no longer excuse anything."""
    return sorted((NOWHERE_ON_PURPOSE if on_purpose is None else on_purpose) - groups["on purpose"])


def summary(groups, wrong, mode, why):
    """The lines of the summary, as Markdown that also reads well as plain text."""
    total = sum(len(group) for group in groups.values())
    why = why or ("every test" if mode == FULL else "only the tests a Mac can say something about")
    lines = [
        f"The Mac ran in mode `{mode}`: {why}.",
        "",
        f"- {total} tests in all",
        f"- {len(groups['linux'])} ran on Linux only",
        f"- {len(groups['mac'])} ran on the Mac only",
        f"- {len(groups['both'])} ran on both",
        f"- {len(groups['on purpose'])} ran nowhere, on purpose (`NOWHERE_ON_PURPOSE` in `scripts/ci-tests.py` says why)",
    ]
    lines += [f"  - `{name}`" for name in sorted(groups["on purpose"])]
    lines.append(f"- {len(groups['nowhere'])} ran nowhere")
    lines += [f"  - `{name}` ran nowhere: {complaint}" for name, complaint in wrong if name]
    lines += [""] + [f"**{complaint}**" for name, complaint in wrong if not name]
    return lines


REMEDY = ("Give its file a reason to be selected (`scripts/ci-tests.py select` lists the reasons; ALWAYS is the last resort), "
          "or decide that it need not run and say so in NOWHERE_ON_PURPOSE.")


def publish(wrong):
    """One error annotation per test, as far as GitHub shows them; the last one carries whatever is left."""
    entries = [(name or "the records", complaint) for name, complaint in wrong]
    for name, complaint in entries[:LIMIT - 1]:
        annotate("error", "a test ran nowhere" if name != "the records" else "tests not accounted for", f"{name}: {complaint}")
    rest = entries[LIMIT - 1:]
    if rest:
        annotate("error", f"{len(rest)} more tests ran nowhere", "\n".join(f"{name}: {complaint}" for name, complaint in rest))


def read(path, whose):
    try:
        with open(path, encoding="utf-8", newline="\n") as handle:
            return handle.read()
    except OSError as error:
        raise Untrustworthy(f"{whose} is missing ({path}: {error.strerror}): did its test run finish?") from error


def write(path, text):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


def forget(path):
    """What an earlier run left must not pass for this one's."""
    if os.path.exists(path):
        os.remove(path)


def selection(root):
    sources = read_sources(root)
    gone = missing_from(ALWAYS, sources)
    if gone:
        raise Untrustworthy(f"ALWAYS names files that do not exist: {', '.join(gone)}")
    chosen = select(sources)
    if not chosen:
        raise Untrustworthy(f"nothing under {os.path.join(root, 'Tests')} was selected")
    return chosen, len(sources)


def command_select(args):
    chosen, out_of = selection(args.root)
    for path, reason in sorted(chosen.items()):
        print(f"{path}: {reason}")
    print(f"\n{len(chosen)} of {out_of} files. To run them:\n")
    print("swift test " + " ".join(f"--filter '{pattern}'" for pattern in filters_for(chosen)))
    return 0


def command_record(args):
    forget(args.file)
    write(args.file, as_text(record_of(lines_of(read(args.events, "the event stream")))))
    return 0


def command_run(args):
    # `swift test` runs in the checkout, wherever the caller stands.
    mode, events = mode_of(args.mode), os.path.abspath(args.record) + ".events"
    for path in [args.record, events] + ([args.all] if args.all else []):
        forget(path)
    command = ["swift", "test", "--event-stream-output-path", events, "--event-stream-version", "0"]
    if mode == MAC_ONLY:
        chosen, out_of = selection(ROOT)
        print(f"Running the tests of {len(chosen)} of {out_of} files (scripts/ci-tests.py select says which, and why).", flush=True)
        for pattern in filters_for(chosen):
            command += ["--filter", pattern]
    code = subprocess.run(command + args.arguments, cwd=ROOT, check=False).returncode

    try:
        record = record_of(lines_of(read(events, "the event stream")))
    except Untrustworthy as error:
        if code == 0:
            raise
        # It did not compile, or it crashed: `swift test` has said so. No record is left, which the net takes for a failure.
        print(f"No record: {error}")
        return code
    write(args.record, as_text(record))
    if args.all:
        listing = subprocess.run(["swift", "test", "list", "--skip-build"], cwd=ROOT, check=False, capture_output=True, text=True)
        if listing.returncode != 0:
            raise Untrustworthy(f"`swift test list` failed: {(listing.stderr or listing.stdout).strip()[-400:]}")
        write(args.all, "".join(name + "\n" for name in sorted(listed_tests(listing.stdout))))
    counts = {status: sum(1 for value in record.values() if value == status) for status in (PASSED, FAILED, SKIPPED)}
    print(f"Recorded {len(record)} tests in {args.record}: " + ", ".join(f"{count} {status}" for status, count in counts.items()))
    if code == 0 and counts[FAILED]:
        raise Untrustworthy(f"`swift test` reports success, and its event stream {counts[FAILED]} failed tests")
    return code


def command_account(args):
    mode = mode_of(args.mode)
    mac = record_from_text(read(args.mac, "the Mac's record"), "the Mac's record")
    mac_all = listed_tests(read(args.mac_all, "the Mac's list of tests"), "the Mac's list of tests")
    linux = record_from_text(read(args.linux, "Linux's record"), "Linux's record")
    groups, wrong = account(mac, mac_all, linux, mode)

    lines = summary(groups, wrong, mode, " ".join(args.why.split()))
    print("\n".join(lines).replace("`", "").replace("**", ""))
    if "GITHUB_STEP_SUMMARY" in os.environ:
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as handle:
            handle.write("## Where the tests ran\n\n" + "\n".join(lines) + "\n")
    for name in stale(groups):
        annotate("warning", "NOWHERE_ON_PURPOSE", f"{name} ran after all, or no longer exists: take it off the list in scripts/ci-tests.py")
    if wrong:
        publish(wrong)
        print("\n" + REMEDY.replace("`", ""))
        return 1
    annotate("notice", "tests accounted for", f"{mode}: " + ", ".join(line[2:] for line in lines if line.startswith("- ")).replace("`", ""))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)

    one = commands.add_parser("select", help="which test files a Mac can say something about, and why")
    one.add_argument("--root", default=ROOT, help="the checkout to read")
    one.set_defaults(run=command_select)

    one = commands.add_parser("run", help="swift test, with a record of what ran")
    one.add_argument("--mode", required=True, help=f"{MAC_ONLY} runs the selection; anything else runs everything")
    one.add_argument("--record", required=True, help="where to write the record")
    one.add_argument("--all", help="where to list every test the build contains")
    one.set_defaults(run=command_run)

    one = commands.add_parser("record", help="the record of an event stream")
    one.add_argument("events")
    one.add_argument("file")
    one.set_defaults(run=command_record)

    one = commands.add_parser("account", help="fails if a test ran nowhere")
    one.add_argument("--mac", required=True, help="the Mac's record")
    one.add_argument("--mac-all", required=True, help="every test the Mac's build contains")
    one.add_argument("--linux", required=True, help="Linux's record")
    one.add_argument("--mode", default="", help="the mode the Mac ran in")
    one.add_argument("--why", default="", help="why it ran in that mode")
    one.set_defaults(run=command_account)

    # Whatever `run` does not know is for `swift test`.
    args, args.arguments = parser.parse_known_args()
    if args.arguments and args.command != "run":
        parser.error("unrecognized arguments: " + " ".join(args.arguments))
    try:
        return args.run(args)
    except Untrustworthy as error:
        print(error)
        annotate("error", f"ci-tests.py {args.command}", str(error))
        return 1


if __name__ == "__main__":
    sys.exit(main())
