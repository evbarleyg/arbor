#!/usr/bin/env python3
"""Scores Arbor against TrellisWM and regenerates docs/FEATURES.md.

Reads collab/parity.json, the record of a test run, and the real-window evidence in
collab/evidence/*-latest.txt, and works out a level for every item:

  verified  shipped, listed tests pass, listed real-window steps passed
  tested    shipped, listed tests pass
  unproven  shipped, but no listed test or step has run
  broken    whatever its status: a listed test failed or is missing, a listed step failed, or no
            runner has a step of that name
  otherwise the item's status (partial, review, in-progress, planned, missing, not-planned)

Real-window steps are the `▸` headings that arbor-e2e (`make e2e`) and scripts/mac-shell/proof.sh print. A
step has passed when the evidence shows at least one ✔ and no ✘ under it. A step that a runner
has but the evidence does not is simply not counted yet.

The record of a test run is what Swift Testing writes for tools (`make test` asks for it: one line of JSON for every test
there is and for everything that happened to it; each test process writes a file, and `swift test` puts the files together). What
`swift test` prints is for people, and proves nothing: it passes the tests' output on in pieces of 4096 bytes and drops each piece
that ends or begins inside a character of several bytes (✔ ◇ ➜ ↳), some hundred lines at a time, from a run that ends well.
Nothing here reads it.

A listed test that needs a macOS framework is skipped on Linux. If its reason for skipping contains
"only on macOS", it counts as passing in a record from another platform, so the levels and
FEATURES.md come out the same everywhere; macOS CI is what proves it. Any other skipped
test, and every skipped test in a record from macOS, proves nothing, and neither does a test with a known issue.

Usage:
  scripts/parity.py                          run the tests (`make test`), print the score, rewrite docs/FEATURES.md
  scripts/parity.py --report FILE [FILE…]    use the records of tests that have just run (several: the parts of one suite)
  scripts/parity.py --check                  also fail if docs/FEATURES.md is out of date (CI)

Exit code 1 if any item is broken, if a test run failed or did not finish or its record is damaged (then nothing in
it proves anything), or, with --check, if FEATURES.md is stale. Exit code 2 if parity.json itself is
wrong: an unknown status, a spec that does not exist, an id the reference does not have.
"""

import argparse
import collections
import glob
import json
import os
import platform
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PARITY = os.path.join(ROOT, "collab", "parity.json")
EVIDENCE = os.path.join(ROOT, "collab", "evidence", "*-latest.txt")
# TrellisWM's features as the project's reference notes number them. The notes are not in this repository, so the list stands here:
# a T row that is dropped from parity.json, or misnumbered, is still noticed. A new one is added in both places.
REFERENCE_IDS = set(
    "T00 T01 T02 T03 T04 T05 T06 T07 T08 T09 T10 T11 T12 T13 T14 T15 T16 T17 T18 T19 T20 T21 T30 T31 T32 T33 T34 T35 T36 T37 T38 T39 T40 T41 T42 T43 T44 T50 T51 T52 T53 T54 T60 T61 T62 T63 T64 T70 T71 T72 T73 T74 T75 T76 T77".split()
)
# Where real-window steps are defined: step("title", …) and print("\n▸ title …") in Swift, claim "title" in shell.
RUNNERS = [os.path.join(ROOT, "Sources", "arbor-e2e", "*.swift"), os.path.join(ROOT, "scripts", "mac-shell", "*.sh")]
FEATURES = os.path.join(ROOT, "docs", "FEATURES.md")
REPORT = os.path.join(ROOT, ".build", "test-report.jsonl")
SPECS = os.path.join(ROOT, "docs", "features")

# Colours and hyperlinks.
ANSI = re.compile(r"\x1b\[[0-9;]*m|\x1b\]8;;.*?\x1b\\")
PLATFORM_LINE = re.compile(r"Target Platform:\s*(\S+)")
STEP_LINE = re.compile(r"^▸ (.+?)(?:\s{2}\(.*\))?\s*$")
STEP_SOURCE = re.compile(r'(?:\bstep\(|^\s*claim |▸ )"?([^"\\(]+?)(?:"|\s{2}\(|\s*$)', re.MULTILINE)

SHIPPED_LEVELS = {"verified", "tested", "unproven"}
LEVEL_ORDER = ["broken", "verified", "tested", "unproven", "partial", "review", "in-progress",
               "planned", "missing", "not-planned"]
STATUSES = {"shipped", "partial", "review", "in-progress", "planned", "missing", "not-planned"}
# What became of a test, in the words BROKEN lines use. A test skipped for a reason of its own "was skipped: …".
PASSED, FAILED, LEFT_TO_MACOS = "passed", "failed", "was left to macOS"
KNOWN_ISSUE, UNFINISHED, NOT_RUN, SKIPPED = "has a known issue", "did not finish", "did not run", "was skipped"
# outcomes: {function name: what became of it}. problems: why none of it proves anything. issues: what went wrong, for people.
Results = collections.namedtuple("Results", "outcomes problems issues count")


def run_tests():
    """`make test`, quietly. What it says is shown only if it leaves no record: then the build failed."""
    print("running the tests…", file=sys.stderr)
    result = subprocess.run(["make", "test", f"TEST_REPORT={REPORT}"], cwd=ROOT, capture_output=True, text=True, errors="replace",
                            check=False)
    if not os.path.exists(REPORT):
        print("\n".join((result.stdout + result.stderr).split("\n")[-40:]))


def read_report(path):
    """What one record of a test run says: ({test id: (function name, outcome)}, problems, issues, how many runs).

    The format is Swift Testing's own for tools, version 0: a line of JSON for each test there is, then one for each event.
    """
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = handle.read().split("\n")
    except OSError as error:
        return {}, [f"{path}: {error.strerror} (`make test` writes it)"], [], 0
    names, suites, started, ended, failed, known, skipped = {}, set(), set(), set(), set(), set(), {}
    problems, issues, runs, finished, run_failed = [], [], 0, 0, False
    on_mac = platform.system() == "Darwin"
    for number, line in enumerate(lines, 1):
        if not line:
            continue
        try:
            entry = json.loads(line)
            if entry["version"] != 0:
                problems.append(f"{path}: line {number} is in version {entry['version']} of the format, and this reads version 0")
                continue
            payload = entry["payload"]
            what, test = payload["kind"], payload.get("testID")
            texts = [message["text"] for message in payload.get("messages", [])]
            if entry["kind"] == "test":
                if what == "function":
                    # `dock(side:)` is the function dock. A name between backticks may hold anything.
                    name = payload["name"]
                    names[payload["id"]] = name[1:].split("`")[0] if name.startswith("`") else name.split("(")[0]
                else:
                    suites.add(payload["id"])
            elif test is not None and test not in names and test not in suites:
                problems.append(f"{path}: line {number} is about a test that the lines before it do not have")
            elif what == "runStarted":
                runs += 1
                for target in filter(None, map(PLATFORM_LINE.search, texts)):
                    on_mac = "apple" in target.group(1)
            elif what == "runEnded":
                finished += 1
                run_failed = run_failed or any(message["symbol"] == "fail" for message in payload["messages"])
            elif what == "testStarted":
                started.add(test)
            elif what == "testEnded":
                ended.add(test)
            elif what == "testSkipped":
                # The key with the underscore is nobody's promise. The message for people has the reason too, after the test's name.
                reasons = payload.get("_comments") or [text.split(" skipped: ", 1)[1] for text in texts if " skipped: " in text]
                mac_only = not on_mac and "only on macOS" in " ".join(reasons)
                skipped[test] = LEFT_TO_MACOS if mac_only else SKIPPED + (": " + "; ".join(reasons) if reasons else "")
            elif what == "issueRecorded":
                if payload["issue"]["isKnown"]:
                    known.add(test)
                else:
                    failed.add(test)
                    where = payload["issue"].get("sourceLocation") or {}
                    issues.append({"test": names.get(test), "text": "\n".join(texts), "path": where.get("_filePath"),
                                   "file": where.get("fileID"), "line": where.get("line"), "column": where.get("column")})
        except (ValueError, KeyError, TypeError, AttributeError):
            problems.append(f"{path}: line {number} is damaged")
    if runs == 0:
        problems.append(f"{path}: there is no test run in it")
    elif finished < runs:
        problems.append(f"{path}: {runs - finished} of {runs} test runs did not finish (a crash?)")
    elif set(names) - ended - set(skipped) - failed:
        # A test whose trait or condition throws fails without having started.
        open_ended = len(set(names) - ended - set(skipped) - failed)
        problems.append(f"{path}: the runs finished, yet nothing says how {open_ended} of the tests ended: lines are missing")
    if None in failed:
        problems.append(f"{path}: something went wrong outside any test")
    elif run_failed and not failed & set(names):
        problems.append(f"{path}: a test run failed")

    def outcome(test):
        if test in failed:
            return FAILED
        if test in known:
            return KNOWN_ISSUE
        if test in skipped:
            return skipped[test]
        if test in ended:
            return PASSED
        return UNFINISHED if test in started else NOT_RUN

    return {test: (name, outcome(test)) for test, name in names.items()}, problems, issues, runs


def read_reports(paths):
    """The same of several records, the parts of one suite, as Results.

    parity.json lists tests by the names of their functions. Where two suites have a function of one name, or two records have one
    test, the worst that became of any of them counts.
    """
    order = [FAILED, KNOWN_ISSUE, UNFINISHED, NOT_RUN, SKIPPED, LEFT_TO_MACOS, PASSED]
    named, every, problems, issues, runs = {}, [], [], [], 0
    for path in paths:
        tests, wrong, found, count = read_report(path)
        problems, issues, runs = problems + wrong, issues + found, runs + count
        for name, outcome in tests.values():
            every.append(outcome)
            named[name] = min(named.get(name, outcome), outcome, key=lambda o: order.index(o.split(":")[0]))
    skipped = sum(1 for outcome in every if outcome == LEFT_TO_MACOS or outcome.startswith(SKIPPED))
    count = f"tests: {len(every)}, passed: {every.count(PASSED)}, skipped: {skipped}, test runs: {runs}"
    return Results(named, problems, issues, count)


def parse_evidence(path):
    """Returns ({step title: passed}, header line) from the output of a real-window runner."""
    marks, order, header, current = {}, [], None, None
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if header is None and line.startswith("# "):
                header = line[2:].strip()
                continue
            match = STEP_LINE.match(line)
            if match:
                # A title that comes again (one per session, say) adds to what it has.
                current = match.group(1).strip()
                if current not in marks:
                    marks[current] = ""
                    order.append(current)
                continue
            if line.startswith("== "):
                current = None  # a heading of lib.sh's: what follows is preparation, not the step before
                continue
            mark = re.match(r"^\s+([✔✘])", line)
            if current and mark:
                marks[current] += mark.group(1)
    # A step with nothing under it is where the run died, or one that checked nothing.
    return {step: "✘" not in marks[step] for step in order if marks[step]}, header


def read_evidence(pattern=EVIDENCE):
    steps, headers = {}, []
    for path in sorted(glob.glob(pattern)):
        found, header = parse_evidence(path)
        for step, passed in found.items():
            steps[step] = passed and steps.get(step, True)
        if header:
            headers.append(header)
    return steps, headers


def known_steps(patterns=None):
    """The titles of every step some runner can run."""
    titles = set()
    for pattern in patterns or RUNNERS:
        for path in glob.glob(pattern):
            with open(path, encoding="utf-8") as handle:
                titles.update(title.strip() for title in STEP_SOURCE.findall(handle.read()))
    return titles


def problems_in(data, reference_ids, specs):
    """What is wrong with parity.json itself."""
    problems = []
    ids = [item["id"] for item in data["features"]]
    problems += [f"{i}: listed twice" for i in sorted({i for i in ids if ids.count(i) > 1})]
    for item in data["features"]:
        if item.get("status") not in STATUSES:
            problems.append(f"{item['id']}: unknown status {item.get('status')!r}; one of {', '.join(sorted(STATUSES))}")
        if item.get("spec") and not any(name.startswith(item["spec"] + "-") for name in specs):
            problems.append(f"{item['id']}: no spec {item['spec']} in docs/features")
        if item["id"].startswith("T") and item["id"] not in reference_ids:
            problems.append(f"{item['id']}: not one of the reference's ids")
    problems += [f"{i}: one of the reference's ids but not in parity.json" for i in sorted(reference_ids - set(ids))]
    return problems


def spec_file(spec_id):
    if not spec_id:
        return None
    for name in sorted(os.listdir(SPECS)):
        if name.startswith(spec_id + "-"):
            return name
    return None


def level_of(item, passed, failed, steps, runnable, outcomes=None):
    status = item["status"]
    tests = item.get("tests", [])
    e2e = item.get("e2e", [])
    missing = [t for t in tests if t not in passed]
    failed_steps = [s for s in e2e if steps.get(s) is False]
    unknown_steps = [s for s in e2e if s not in steps and s not in runnable]
    run_steps = [s for s in e2e if steps.get(s) is True]
    notes = []
    if tests:
        notes.append(f"tests {len(tests) - len(missing)}/{len(tests)}")
    if e2e:
        notes.append(f"real windows {len(run_steps)}/{len(e2e)}")
    # Whatever the status: what an item lists as proof has to exist and pass.
    if missing or failed_steps or unknown_steps:
        detail = ", ".join([f"test {t} {'failed' if t in failed else (outcomes or {}).get(t, 'not found')}" for t in missing]
                           + [f"step '{s}' failed" for s in failed_steps]
                           + [f"no runner has a step '{s}'" for s in unknown_steps])
        return "broken", detail
    if status != "shipped":
        return status, ", ".join(notes)
    if item.get("kind") == "policy":
        return "verified", "nothing to test"
    if not tests and not e2e:
        return "unproven", "no tests or steps listed"
    if not tests and not run_steps:
        return "unproven", ", ".join(notes)
    if e2e and len(run_steps) == len(e2e):
        return "verified", ", ".join(notes)
    return "tested", ", ".join(notes)


def render(data, results, header):
    lines = [
        "# Features",
        "",
        "Generated by `make parity` from `collab/parity.json`; do not edit by hand.",
        "Reference items (T..) are features of TrellisWM;",
        "A.. items are Arbor-only. Levels are explained in `collab/README.md`.",
        "",
    ]
    lines += summary_lines(data, results, header)
    areas = []
    for item in data["features"]:
        if item["area"] not in areas:
            areas.append(item["area"])
    for area in areas:
        lines += ["", f"## {area}", "",
                  "| ID | Feature | TrellisWM | Arbor | Level | Evidence | Spec |",
                  "|---|---|---|---|---|---|---|"]
        for item in data["features"]:
            if item["area"] != area:
                continue
            level, note = results[item["id"]]
            if item.get("branch"):
                note = (note + "; " if note else "") + f"`{item['branch']}`"
            spec = item.get("spec") or ""
            spec_name = spec_file(spec)
            spec_link = f"[{spec}](features/{spec_name})" if spec_name else spec
            cells = [item["id"], item["title"], item.get("trellis", ""), item.get("arbor", ""),
                     f"**{level}**" if level == "broken" else level, note, spec_link]
            lines.append("| " + " | ".join(c.replace("|", "\\|") for c in cells) + " |")
    return "\n".join(lines) + "\n"


def summary_lines(data, results, header):
    reference = [i for i in data["features"] if i["id"].startswith("T") and i["status"] != "not-planned"]
    shipped = [i for i in reference if results[i["id"]][0] in SHIPPED_LEVELS]
    verified = [i for i in reference if results[i["id"]][0] == "verified" and i.get("kind") != "policy"]
    counts = {}
    for level, _ in results.values():
        counts[level] = counts.get(level, 0) + 1
    percent = round(100 * len(shipped) / len(reference)) if reference else 0
    lines = [
        f"**TrellisWM parity: {len(shipped)} of {len(reference)} reference items shipped ({percent}%), "
        f"{len(verified)} verified on real windows.**",
        "",
        "Levels: " + ", ".join(f"{level} {counts[level]}" for level in LEVEL_ORDER if level in counts) + ".",
    ]
    for line in header:
        lines += ["", f"Real-window evidence: {line}."]
    return lines


def next_up(data, results, count=8):
    order = {"planned": 0, "missing": 1, "partial": 2}
    candidates = [i for i in data["features"]
                  if results[i["id"]][0] in order and not i.get("branch")]
    candidates.sort(key=lambda i: (i.get("priority", 3), order[results[i["id"]][0]], i["id"]))
    return candidates[:count]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--report", nargs="+", metavar="FILE",
                        help="the record of tests that have just run, as `make test` leaves it in .build/test-report.jsonl")
    parser.add_argument("--check", action="store_true", help="fail if docs/FEATURES.md is out of date")
    args = parser.parse_args()

    with open(PARITY, encoding="utf-8") as handle:
        data = json.load(handle)

    ids = [item["id"] for item in data["features"]]
    reference_ids = REFERENCE_IDS
    wrong = problems_in(data, reference_ids, os.listdir(SPECS))
    if wrong:
        print("collab/parity.json:\n  " + "\n  ".join(wrong))
        sys.exit(2)

    if not args.report:
        run_tests()
    outcomes, problems, _, count = read_reports(args.report or [REPORT])
    if not outcomes:
        sys.exit("no test results found; did the build fail?\n  " + "\n  ".join(problems[:5]))
    print(count)
    passed = {test for test, outcome in outcomes.items() if outcome == PASSED}
    failed = {test for test, outcome in outcomes.items() if outcome == FAILED}
    mac_only = {test for test, outcome in outcomes.items() if outcome == LEFT_TO_MACOS}
    if mac_only:
        print("left to macOS and taken as passing: " + ", ".join(sorted(mac_only)))
        passed |= mac_only
    steps, header = read_evidence()
    runnable = known_steps()

    results = {item["id"]: level_of(item, passed, failed, steps, runnable, outcomes) for item in data["features"]}
    text = render(data, results, header)

    for line in summary_lines(data, results, header):
        if line:
            print(line.replace("**", ""))
    broken = [(i, results[i][1]) for i in ids if results[i][0] == "broken"]
    for item_id, detail in broken:
        print(f"BROKEN {item_id}: {detail}")
    unsound = "; ".join(problems[:3] + [f"and {len(problems) - 3} more of the kind"] * (len(problems) > 3)
                        + ["failed: " + ", ".join(sorted(failed))] * bool(failed))
    if unsound:
        print(f"THE TESTS DID NOT ALL RUN AND PASS, so the levels above prove nothing: {unsound}")
    upcoming = next_up(data, results)
    if upcoming:
        print("Next up: " + ", ".join(f"{i['id']} {i['title']} ({i.get('spec') or 'needs a spec'})"
                                      for i in upcoming))

    stale = False
    if args.check:
        current = open(FEATURES, encoding="utf-8").read() if os.path.exists(FEATURES) else ""
        if current != text:
            stale = True
            print("docs/FEATURES.md is out of date; run `make parity` and commit it")
    else:
        with open(FEATURES, "w", encoding="utf-8") as handle:
            handle.write(text)
        print("wrote docs/FEATURES.md")

    sys.exit(1 if broken or stale or unsound else 0)


if __name__ == "__main__":
    main()
