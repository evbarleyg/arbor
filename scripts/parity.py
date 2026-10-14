#!/usr/bin/env python3
"""Scores Arbor against TrellisWM and regenerates docs/FEATURES.md.

Reads collab/parity.json, runs `swift test` (or reads a saved log), reads the
real-window evidence in collab/evidence/*-latest.txt, and works out a level
for every item:

  verified  shipped, listed tests pass, listed real-window steps passed
  tested    shipped, listed tests pass
  unproven  shipped, but no listed test or step has run
  broken    whatever its status: a listed test failed or is missing, a listed step failed, or no
            runner has a step of that name
  otherwise the item's status (partial, review, in-progress, planned, missing, not-planned)

Real-window steps are the `▸` headings that arbor-e2e (`make e2e`) and scripts/mac-shell/proof.sh print. A
step has passed when the evidence shows at least one ✔ and no ✘ under it. A step that a runner
has but the evidence does not is simply not counted yet.

A listed test that needs a macOS framework is skipped on Linux. If its reason for skipping contains
"only on macOS", it counts as passing in a log from another platform, so the levels and
FEATURES.md come out the same everywhere; macOS CI is what proves it. Any other skipped
test, and every skipped test in a log from macOS, proves nothing and counts as not found.

Usage:
  scripts/parity.py                     run the tests, print the score, rewrite docs/FEATURES.md
  scripts/parity.py --test-log FILE     use a saved `swift test` log instead of running the tests
  scripts/parity.py --check             also fail if docs/FEATURES.md is out of date (CI)

Exit code 1 if any item is broken, if the test run failed or did not finish (then nothing it
printed proves anything), or, with --check, if FEATURES.md is stale. Exit code 2 if parity.json itself is
wrong: an unknown status, a spec that does not exist, an id the reference does not have.
"""

import argparse
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
SPECS = os.path.join(ROOT, "docs", "features")

# Colours and hyperlinks.
ANSI = re.compile(r"\x1b\[[0-9;]*m|\x1b\]8;;.*?\x1b\\")
TEST_LINE = re.compile(r"^\s*([✔✘])\s+Test\s+(\w+)\(")
# `swift test` now and then loses lines of a long output (seen with 474 tests: eight "passed" lines gone from a run
# that closed with "180 tests passed"). A test that started, in a log where every run finished and passed, has passed.
START_LINE = re.compile(r"^\s*◇\s+Test\s+(\w+)\(.*\bstarted\b")
KNOWN_ISSUE_LINE = re.compile(r"\bTest\s+(\w+)\(.*\brecorded a known issue\b")
SKIP_LINE = re.compile(r'^\s*[^\s✔✘]+\s+Test\s+(\w+)\([^)]*\)\s+skipped: ".*only on macOS')
PLATFORM_LINE = re.compile(r"Target Platform:\s*(\S+)")
STEP_LINE = re.compile(r"^▸ (.+?)(?:\s{2}\(.*\))?\s*$")
# Not anchored on the symbol in front: it differs when the run recorded a known issue.
RUN_STARTED = re.compile(r"\bTest run started\b")
RUN_ENDED = re.compile(r"\bTest run with \d+ tests? in \d+ suites? (passed|failed)\b")
RUN_SIZE = re.compile(r"\bTest run with (\d+) tests? in \d+ suites? passed\b")
# `@Test`, its arguments if any (brackets up to three deep), other attributes and modifiers, `func name(`.
DECLARATION = re.compile(r"@Test\b(\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\))?\s*(?:@\w+\s+)*(?:\w+\s+)*?func\s+(\w+)\s*\(")
STEP_SOURCE = re.compile(r'(?:\bstep\(|^\s*claim |▸ )"?([^"\\(]+?)(?:"|\s{2}\(|\s*$)', re.MULTILINE)

SHIPPED_LEVELS = {"verified", "tested", "unproven"}
LEVEL_ORDER = ["broken", "verified", "tested", "unproven", "partial", "review", "in-progress",
               "planned", "missing", "not-planned"]
STATUSES = {"shipped", "partial", "review", "in-progress", "planned", "missing", "not-planned"}


def run_tests():
    print("running swift test…", file=sys.stderr)
    result = subprocess.run(["swift", "test"], cwd=ROOT, capture_output=True, text=True)
    return result.stdout + result.stderr, result.returncode


def declared_tests(on_mac, root=ROOT):
    """What the sources under Tests/ declare for that platform: the tests that run, the ones left to macOS, and how many in all."""
    runs, mac_only, count = set(), set(), 0
    for path in sorted(glob.glob(os.path.join(root, "Tests", "**", "*.swift"), recursive=True)):
        with open(path, encoding="utf-8") as handle:
            lines = handle.read().split("\n")
        compiled, kept = [], []
        for line in lines:
            word = line.strip()
            if word.startswith("#if"):
                # A condition this does not know makes the count come out wrong, and then nothing is recovered.
                compiled.append({"os(macOS)": on_mac, "!os(macOS)": not on_mac, "canImport(Carbon)": on_mac,
                                 "canImport(AppKit)": on_mac}.get(word[3:].strip(), True))
            elif word.startswith("#else") and compiled:
                compiled[-1] = not compiled[-1]
            elif word.startswith("#endif") and compiled:
                compiled.pop()
            elif all(compiled):
                kept.append(line)
        for arguments, name in DECLARATION.findall("\n".join(kept)):
            count += 1
            if ".disabled" not in arguments:
                runs.add(name)
            elif "only on macOS" in arguments and not on_mac:
                mac_only.add(name)
    return runs, mac_only, count


def recover(missing, log, root=ROOT):
    """Which of the listed tests that a log does not mention passed all the same, and which were left to macOS.

    `swift test` can lose both lines of a test (see START_LINE). But its closing lines say how many tests ran, skipped ones
    included. If every run finished and passed, and together they ran exactly as many tests as the sources declare, then every
    test the sources declare has run and passed, whether or not its lines survived.
    """
    lines = [ANSI.sub("", raw) for raw in log.splitlines()]
    if run_problem(log) is not None or parse_tests(log)[1]:
        return set(), set()
    targets = [match.group(1) for match in map(PLATFORM_LINE.search, lines) if match]
    on_mac = "apple" in targets[-1] if targets else platform.system() == "Darwin"
    runs, mac_only, count = declared_tests(on_mac, root)
    if count == 0 or count != sum(int(match.group(1)) for match in map(RUN_SIZE.search, lines) if match):
        return set(), set()
    return missing & runs, missing & mac_only


def parse_tests(log):
    """Returns the tests that passed, failed, and were left to macOS by a run elsewhere."""
    passed, failed, mac_only, started, doubtful = set(), set(), set(), set(), set()
    on_mac = platform.system() == "Darwin"
    for raw in log.splitlines():
        line = ANSI.sub("", raw)
        start = START_LINE.match(line)
        if start:
            started.add(start.group(1))
            continue
        known = KNOWN_ISSUE_LINE.search(line)
        if known:
            doubtful.add(known.group(1))
            continue
        target = PLATFORM_LINE.search(line)
        if target:
            on_mac = "apple" in target.group(1)
            continue
        skip = SKIP_LINE.match(line)
        if skip:
            mac_only.add(skip.group(1))
            continue
        match = TEST_LINE.match(line)
        if not match:
            continue
        symbol, name = match.groups()
        if symbol == "✘":
            failed.add(name)
        elif " passed" in line:
            passed.add(name)
    if not failed and started and run_problem(log) is None:
        passed |= started - doubtful
    return passed - failed, failed, set() if on_mac else mac_only - failed


def run_problem(log, code=0):
    """Why the test run as a whole proves nothing, or None. A crash ends the log without a closing line."""
    lines = [ANSI.sub("", raw) for raw in log.splitlines()]
    started = sum(1 for line in lines if RUN_STARTED.search(line))
    ended = [match.group(1) for match in map(RUN_ENDED.search, lines) if match]
    if len(ended) < started:
        return f"{started - len(ended)} of {started} test runs did not finish (a crash?)"
    if "failed" in ended:
        return "the test run failed"
    if code != 0:
        return f"swift test exited with code {code}"
    return None


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


def level_of(item, passed, failed, steps, runnable):
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
        detail = ", ".join([f"test {t} {'failed' if t in failed else 'not found'}" for t in missing]
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
    parser.add_argument("--test-log", help="use this saved `swift test` output")
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

    code = 0
    if args.test_log:
        with open(args.test_log, encoding="utf-8", errors="replace") as handle:
            log = handle.read()
    else:
        log, code = run_tests()
    passed, failed, mac_only = parse_tests(log)
    listed = {test for item in data["features"] for test in item.get("tests", [])}
    if code == 0 and listed - passed - mac_only:
        found, left = recover(listed - passed - mac_only, log)
        if found or left:
            print("not in the output, which lost lines, but run and passed by the count of tests: " + ", ".join(sorted(found | left)))
        passed, mac_only = passed | found, mac_only | left
    if not args.test_log and not failed and run_problem(log, code) is None and listed - passed - mac_only:
        # Both lines of a test can be among the lost ones (see START_LINE). A test that is really gone is still gone
        # the second time; what either run saw pass has passed.
        print("some listed tests are not in the output of a run that passed; running once more…", file=sys.stderr)
        again, code = run_tests()
        second = parse_tests(again)
        if not second[1] and run_problem(again, code) is None:
            passed, mac_only = passed | second[0], mac_only | second[2]
        else:
            log, (passed, failed, mac_only) = again, second
    if not passed and not failed:
        sys.exit("no test results found; did the build fail?")
    if mac_only:
        print("left to macOS and taken as passing: " + ", ".join(sorted(mac_only)))
        passed |= mac_only
    steps, header = read_evidence()
    runnable = known_steps()

    results = {item["id"]: level_of(item, passed, failed, steps, runnable) for item in data["features"]}
    text = render(data, results, header)

    for line in summary_lines(data, results, header):
        if line:
            print(line.replace("**", ""))
    broken = [(i, results[i][1]) for i in ids if results[i][0] == "broken"]
    for item_id, detail in broken:
        print(f"BROKEN {item_id}: {detail}")
    unsound = run_problem(log, code)
    if not unsound and failed:
        unsound = "failed: " + ", ".join(sorted(failed))
    if unsound:
        print(f"THE TESTS DO NOT PASS, so the levels above prove nothing: {unsound}")
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
