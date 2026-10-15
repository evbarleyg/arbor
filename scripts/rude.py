#!/usr/bin/env python3
"""Runs the tests, the scenarios and the chaos lab's walks against a fake that behaves as badly as macOS is known to.

    scripts/rude.py                          every manner, one after the other; those that throw dice with the seeds 1 to 3
    scripts/rude.py order slow               only these
    scripts/rude.py --seeds 1,2,3,4,5 order  more orders
    scripts/rude.py --check                  exit 1 unless what fails is exactly what collab/evidence/rude-known.txt lists (`make rude`)
    scripts/rude.py --write-known            take off that list what no longer fails; what is new goes on it as UNTRIAGED, which no check lets pass
    scripts/rude.py --out DIR                keep the logs of what failed there (default .build/rude)
    scripts/rude.py --only tests|scenarios|walks
    scripts/rude.py --suite SummonTests      only that suite's tests (may be given again), under every manner: seconds. For a test one has just written
    scripts/rude.py --jobs 2                 how many runs side by side (default: one per core; each keeps one core busy)
    scripts/rude.py --lint                   the list alone, nothing is built or run: its form, and that it has not grown (`make lint`)
    scripts/rude.py --self-test              tries all of the above on right and wrong text (`make lint`)

The stand-ins are politer than macOS (docs/REALITY.md). `ARBOR_RUDE=<manner>` makes every FakeWindowSystem in a process drop one courtesy
(Sources/ArborTesting/FakeWindowSystem+Rude.swift says which, and what was seen on a Mac). This script sets it, runs what `make check` runs,
and lists what fails. Whatever fails is a fault a Mac would have shown, a test that pins a courtesy of the fake's, or a fake that is ruder
than any Mac. Which of the three is for a person to say, in the remark behind the line in rude-known.txt: ARBOR, TEST or FAKE, and a few words.

THE LIST ONLY SHRINKS. A test that pins a courtesy is mended (it waits, or it says `staysPolite(because:)`), a fake that is too rude is
mended; what stays on the list are faults of Arbor's that wait for their cure. A new failure is nobody's to add: `--lint` holds
the list against the one on the branch work is landed on and fails on a line that is not there, unless its manner is new altogether.
It also counts the tests that say `staysPolite`, which may not become more either.

Everything is also run with a polite fake, the same way: the control. What fails there as well is no finding about manners.

The last lines are the numbers to watch: `suites that hold under every manner that counts: N of M` (up) and
`rude: N failures (tests a, scenarios b, walks c) under M manners` (down).
It builds once (`swift build --build-tests`, `swift build`), needs `swift` on the path, and starts the test runner itself, as on Linux one can.
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

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANNERS = ["ahead", "order", "twice", "slow", "numbers", "closes", "small"]
# What if: manners that nobody has measured at the seam, or that no Arbor could make up for. Run by name, counted apart, never a reason to fail.
#   late    nobody has seen an app read back a stale frame yet (`apptool limits` on a Mac says "late yes" when one does)
#   silent  was seen, and lies below the seam: with no report at all there is nothing for the controller to go by
WHAT_IF = ["late", "silent"]
# The manners that throw dice. The others do the same thing whatever the seed, and are run once.
DICE = ["order", "late", "silent"]
KINDS = ["tests", "scenarios", "walks"]
VERDICTS = ("ARBOR", "TEST", "FAKE")
KNOWN = os.path.join(ROOT, "collab", "evidence", "rude-known.txt")
# Where work is landed: the list there is the longest this one may be.
BASE = os.environ.get("ARBOR_RUDE_BASE", "origin/swarm/trunk")
ANSI = re.compile(r"\x1b\[[0-9;]*m|\x1b\]8;;.*?\x1b\\")
# Suites whose subject is the fake's own manners, good or bad: what they expect of a polite one does not hold of a rude one. And the chaos lab's books,
# until a script can say which manners it was found with: that a long one found with a polite fake still breaks its rule says nothing about another fake.
SKIP = ("RudeFakeTests", "FaithfulFakeTests", "ChaosKnownFailureTests")
# No suite, no round of scenarios and no round of walks takes a tenth of this. Whatever does hangs, and counts as a run that did not end.
TIME_LIMIT = 1800
STAYS_POLITE = re.compile(r"\.staysPolite\(because:")
HEAD = """# What fails against the rude fake (scripts/rude.py; docs/TESTING.md, "The rude fake"): <manner> <kind> <name>   # ARBOR|TEST|FAKE: whose fault, in a few words
# `make rude` fails on a failure that is not listed here, and on a line here that no longer fails: delete it with the cure.
# THE LIST ONLY SHRINKS (`make lint`): a new test holds under every manner, or waits, or says `staysPolite(because:)`.
"""


# MARK: reading what a run left

def name_of(test):
    """`Suite/function` out of Swift Testing's id, `Module.Suite/function(label:)/File.swift:1:2`."""
    return test.split(".", 1)[1].split("(", 1)[0] if "." in test else test.split("(", 1)[0]


def outcome_of(events):
    """What an event stream says: the tests that failed, those that came to an end, those that began and did not, and whether the run ended.
    A JSON object to a line: first every test about to run ("kind": "test"), then what happened. A crash leaves a line cut short, or none."""
    failed, finished, begun, ended = set(), set(), [], False
    for line in events.split("\n"):
        try:
            entry = json.loads(line)
            kind, payload = entry["kind"], entry["payload"]
        except (ValueError, KeyError, TypeError):
            continue
        if kind != "event":
            continue
        what, test = payload.get("kind"), payload.get("testID")
        ended |= what == "runEnded"
        # Suites begin and end as well; a function's id has brackets.
        if not test or "(" not in test:
            continue
        if what == "testStarted":
            begun.append(name_of(test))
        elif what in ("testEnded", "testSkipped"):
            finished.add(name_of(test))
        elif what == "issueRecorded":
            issue = payload.get("issue", {})
            if issue.get("isFailure", not issue.get("isKnown", False)):
                failed.add(name_of(test))
    return failed, finished, [name for name in begun if name not in finished], ended


def culprit(lines, unfinished):
    """The test that took its process with it. All of a suite's tests begin at once and then wait their turn on the main actor, so that it began and did not
    end is true of many: the backtrace names it among its frames, `Suite.function(label:) + 123 in …`. None if it names none of them."""
    if len(unfinished) == 1:
        return unfinished[0]
    crash = next((index for index, line in enumerate(lines) if "crashed" in line.lower() or "Fatal error" in line), None)
    for line in lines[crash:] if crash is not None else []:
        for suite, function in re.findall(r"\b([\w.]+)\.(\w+)\(", line):
            if (name := f"{suite.replace('.', '/')}/{function}") in unfinished:
                return name
    return None


def failed_scenarios(lines):
    return {line.split()[1].rstrip(":") for line in lines if line.startswith("✘ ") and len(line.split()) > 1}


def broken_by_walks(lines, count, steps):
    """The rules a hunt's walks broke: `rule:walk` -> the shrunk script, or None past the few of a rule that a hunt shrinks. None if the hunt did
    not get to its end."""
    if not any(re.match(rf"^{count} seeds × {steps} steps: ", line) for line in lines):
        return None
    broken, walk, name = {}, None, None
    for line in lines:
        if match := re.match(r"chaos: seed (\d+) broke a rule", line):
            walk, name = match.group(1), None
        elif walk and (match := re.match(r"\s+\[([\w-]+)\]", line)):
            name, walk = f"{match.group(1)}:{walk}", None
            broken[name] = []
        elif match := re.match(r"seed (\d+): \[([\w-]+)\]", line):
            broken[f"{match.group(2)}:{match.group(1)}"] = None
        elif name and line.startswith("    "):
            broken[name].append(line.strip())
        elif name and not line.strip():
            name = None
    return broken


def by_their_siblings(names, without_script):
    """A hunt shrinks a few walks of each rule and only counts the rest. Those go by the ones that were shrunk: if each of them breaks the rule
    politely too (`!`), so, for all anybody knows, do they."""
    judged = set()
    for name in names:
        rule = name.lstrip("!").split(":")[0]
        shrunk = [other for other in names if other.lstrip("!").split(":")[0] == rule and other.lstrip("!") not in without_script]
        judged.add("!" + name if name in without_script and shrunk and all(other.startswith("!") for other in shrunk) else name)
    return judged


def rules_broken(lines):
    """Every rule a replay that goes on to its end says was broken."""
    return {match.group(1) for line in lines if (match := re.match(r"\s+\[([\w-]+)\]", line))}


# MARK: running

def products():
    return os.path.realpath(os.path.join(ROOT, ".build", "debug"))


def runner():
    """ArborKitTests' own runner: only that target meets the fake. `swift test` holds a lock on .build, so two of them would wait for each other."""
    path = os.path.join(products(), "ArborKitTests-test-runner")
    return [path, "--testing-library", "swift-testing"] if os.access(path, os.X_OK) else None


def run(command, manner, seed, log):
    """The exit code (None: it was ended) and what was printed. Several go on side by side, and each writes a log and opens sockets, so each has a temporary
    folder of its own, with a short name: the path of a socket may have a hundred characters or so. No ARBOR_HOME for the tests: `swift test` sets none."""
    with tempfile.TemporaryDirectory(prefix="rude-") as own, open(log, "w", encoding="utf-8") as out:
        environment = {key: value for key, value in os.environ.items() if key != "ARBOR_HOME"}
        environment.update(ARBOR_RUDE=manner, ARBOR_RUDE_SEED=str(seed), TMPDIR=own, LD_LIBRARY_PATH=products(), NO_COLOR="1")
        if "-test-runner" not in command[0]:
            environment["ARBOR_HOME"] = own
        try:
            code = subprocess.run(command, cwd=ROOT, env=environment, stdout=out, stderr=subprocess.STDOUT, check=False, timeout=TIME_LIMIT).returncode
        except subprocess.TimeoutExpired:
            code = None
            out.write(f"\nrude.py: ended after {TIME_LIMIT} s\n")
    with open(log, encoding="utf-8", errors="replace") as text:
        return code, [ANSI.sub("", line.rstrip("\n")) for line in text]


def suites():
    """The suites of ArborKitTests, and the names of each one's tests."""
    listed = subprocess.run(runner() + ["--list-tests"], cwd=ROOT, capture_output=True, text=True, check=False,
                            env={**os.environ, "LD_LIBRARY_PATH": products(), "NO_COLOR": "1"}).stdout.splitlines()
    tests_of = {}
    for line in listed:
        if line.startswith("ArborKitTests.") and "(" in line:
            name = name_of(line.strip())
            tests_of.setdefault(name.split("/")[0], set()).add(name)
    return {suite: names for suite, names in tests_of.items() if suite not in SKIP}


def tests(manner, seed, out, suite, names):
    """The tests of one suite that fail, as `Suite/name`. A suite is a process of its own, because a test that unwraps what is not there takes the
    process with it: that test counts as failed, and the suite is run again without it. None if a run proves nothing: it hangs, it
    ends in a way that names no test, fewer tests ran than the suite has, or it says that it failed and no test did."""
    failed, done, skipped = set(), set(), []
    while True:
        stem = os.path.join(out, f"tests-{manner or 'polite'}-{seed}-{suite}{'-' + str(len(skipped)) if skipped else ''}")
        command = runner() + ["--filter", rf"^ArborKitTests\.{suite}/", "--event-stream-output-path", stem + ".jsonl", "--event-stream-version", "0"]
        for name in skipped:
            command += ["--skip", rf"^ArborKitTests\.{re.escape(name)}\("]
        code, lines = run(command, manner, seed, stem + ".log")
        events = ""
        if os.path.exists(stem + ".jsonl"):
            with open(stem + ".jsonl", encoding="utf-8", errors="replace") as stream:
                events = stream.read()
            os.remove(stem + ".jsonl")
        if code is None:
            return None
        now_failed, finished, unfinished, ended = outcome_of(events)
        failed |= now_failed
        done |= finished
        if ended:
            if done | set(skipped) != names or (code != 0 and not now_failed):
                return None
            if not failed and code == 0:
                os.remove(stem + ".log")
            return failed
        crashed = culprit(lines, unfinished)
        if crashed is None or len(skipped) > 40:
            return None
        failed.add(crashed)
        skipped.append(crashed)


def scenarios(manner, seed, out):
    code, lines = run(["./scripts/scenarios.sh"], manner, seed, os.path.join(out, f"scenarios-{manner or 'polite'}-{seed}.log"))
    # 0: all hold; 1: some do not. Anything else (nothing is built, no temporary folder) has tried none.
    return failed_scenarios(lines) if code in (0, 1) else None


def walks(manner, seed, out, count, steps):
    """The seeds of the walks are not the fake's: each seed of the fake sees the same walks. A manner can also just lead a walk to where no polite one has
    been. So each shrunk script is played once more to a polite fake: if it breaks its rule there as well it is a find for the chaos lab
    and none about manners, and comes back with a `!` before it."""
    sim = os.path.join(products(), "arbor-sim")
    stem = os.path.join(out, f"walks-{manner or 'polite'}-{seed}")
    _, lines = run([sim, "hunt", "1", str(count), str(steps)], manner, seed, stem + ".log")
    broken = broken_by_walks(lines, count, steps)
    if broken is None or not manner:
        return None if broken is None else set(broken)
    names = set()
    for name, script in broken.items():
        polite = set()
        if script:
            with open(f"{stem}-{name.replace(':', '-')}.script", "w", encoding="utf-8") as file:
                file.write("\n".join(script) + "\n")
            _, replayed = run(["/bin/sh", "-c", f'exec "{sim}" replay --quiet --go-on < "{file.name}"'], "", 1, file.name + ".polite.log")
            polite = rules_broken(replayed)
        names.add(("!" if name.split(":")[0] in polite else "") + name)
    return by_their_siblings(names, {name for name, script in broken.items() if not script})


# MARK: the list

def read_known(text):
    """key -> remark. A line is `<manner> <kind> <name>   # remark`."""
    known = {}
    for line in text.split("\n"):
        body, _, remark = line.partition("#")
        if words := body.split():
            known[" ".join(words)] = remark.strip()
    return known


def polite_in_head(text):
    match = re.search(r"^# tests that stay polite: (\d+)$", text, re.M)
    return int(match.group(1)) if match else None


def manners_in_head(text):
    match = re.search(r"^# manners: (.*)$", text, re.M)
    return match.group(1).split() if match else None


def written(known, polite):
    lines = [f"{key}   # {remark}\n" for key, remark in sorted(known.items())]
    return HEAD + f"# manners: {' '.join(MANNERS)}\n# tests that stay polite: {polite}\n" + "".join(lines)


def compared(found, known, manners, only, untried=()):
    """What is new, what has gone, and what is on the list without a verdict. Only what this run could have found counts as gone: not a manner or a kind
    it left out, and nothing of a run that did not end (`untried`: manner, kind, suite)."""
    def tried(key):
        manner, kind, name = key.split()
        return (manner, kind, name.split("/")[0] if kind == "tests" else "") not in untried
    in_scope = {key for key in known if key.split()[0] in manners and (not only or key.split()[1] == only)}
    return sorted(found - set(known)), sorted(key for key in in_scope - found if tried(key)), sorted(key for key in in_scope if not has_verdict(known[key]))


def has_verdict(remark):
    return any(remark.startswith(verdict + ":") and remark[len(verdict) + 1:].strip() for verdict in VERDICTS)


def updated(found, known, manners, only, untried=()):
    """The list after a run: without what has gone, with what is new marked as nobody's yet."""
    new, gone, _ = compared(found, known, manners, only, untried)
    kept = {key: remark for key, remark in known.items() if key not in gone}
    kept.update({key: "UNTRIAGED" for key in new})
    return kept


def lint(text, base, polite):
    """What is wrong with the list. `base`: the list where work is landed, None if there is none yet. `polite`: how many tests say staysPolite."""
    problems = []
    for number, line in enumerate(text.split("\n"), 1):
        body, _, remark = line.partition("#")
        words = body.split()
        if not words:
            continue
        if len(words) != 3 or words[0] not in MANNERS or words[1] not in KINDS:
            problems.append(f"line {number}: `{body.strip()}` is not <manner> <kind> <name> (what-ifs are not listed)")
        elif words[0] == "small" and words[1] != "walks":
            problems.append(f"line {number}: the tests and the scenarios on the small display are counted apart and not listed")
        if not has_verdict(remark.strip()):
            problems.append(f"line {number}: `{body.strip()}` wants a verdict and a few words behind it: # {'|'.join(VERDICTS)}: …")
    said = polite_in_head(text)
    if said != polite:
        problems.append(f"{polite} tests say staysPolite(because:), and the list's head says {said}: `# tests that stay polite: {polite}`")
    if manners_in_head(text) != MANNERS:
        problems.append(f"the list's head does not say which manners it is about: `# manners: {' '.join(MANNERS)}`")
    if base is not None:
        before = read_known(base)
        # Not the manners that have lines there: one with none left would pass for new.
        old_manners = manners_in_head(base) or MANNERS
        for key in sorted(set(read_known(text)) - set(before)):
            if key.split()[0] in old_manners:
                problems.append(f"`{key}` is new on the list, which only shrinks: cure the fault, or let the test wait, or have it say staysPolite(because:)")
        if (earlier := polite_in_head(base)) is not None and polite > earlier:
            problems.append(f"{polite} tests say staysPolite(because:), where there were {earlier}: that number does not grow either; let the test wait for what is owed")
    return problems


def count_polite():
    total = 0
    for path in glob.glob(os.path.join(ROOT, "Tests", "**", "*.swift"), recursive=True):
        with open(path, encoding="utf-8") as text:
            total += len(STAYS_POLITE.findall(text.read()))
    return total


def git(*words):
    # In a container job the checkout belongs to another user, and git would refuse it.
    return subprocess.run(["git", "-c", f"safe.directory={ROOT}", *words], cwd=ROOT, capture_output=True, text=True, check=False)


def fetch_words(target, shallow):
    """One commit is enough, where the checkout has no more itself. In a whole clone a depth would cut the history off there, for everything that comes after."""
    return ["fetch", "--quiet"] + (["--depth=1"] if shallow else []) + ["origin", target]


def known_at_base():
    """The list where work is landed, and why it cannot be read, if it cannot. (None, None): there is no list there yet.
    A pull request's check has one commit and no more: the branch it is for merged with it. So that branch's tip is fetched and is what to compare with."""
    path = os.path.relpath(KNOWN, ROOT)
    if target := os.environ.get("GITHUB_BASE_REF"):
        fetched = git(*fetch_words(target, git("rev-parse", "--is-shallow-repository").stdout.strip() == "true"))
        if fetched.returncode != 0:
            return None, f"{target} cannot be fetched: {fetched.stderr.strip()[-200:]}"
        commit = "FETCH_HEAD"
    else:
        fork = git("merge-base", "HEAD", BASE)
        if fork.returncode != 0:
            return None, f"{BASE} is not to be had here"
        commit = fork.stdout.strip()
    shown = git("show", f"{commit}:{path}")
    if shown.returncode == 0:
        return shown.stdout, None
    return None, None if git("cat-file", "-e", f"{commit}^{{commit}}").returncode == 0 else f"{commit} cannot be read"


def command_lint():
    if not os.path.exists(KNOWN):
        sys.exit(f"rude.py: there is no {os.path.relpath(KNOWN, ROOT)}")
    with open(KNOWN, encoding="utf-8") as text:
        now = text.read()
    base, why_not = known_at_base()
    problems = lint(now, base, count_polite())
    for problem in problems:
        print(f"rude-known.txt: {problem}")
    if why_not:
        # What cannot be found out does not pass. But for a push of what has been landed, which has nothing to be held against.
        landed = os.environ.get("GITHUB_EVENT_NAME") in ("push", "schedule", "workflow_dispatch")
        print(f"rude.py --lint: whether the list has grown cannot be told: {why_not}" + ("" if landed else " (git fetch origin; or ARBOR_RUDE_BASE=<branch>)"))
        if not landed:
            sys.exit(1)
    sys.exit(1 if problems else 0)


# MARK: the run

def summed(results, manners):
    """What the runs come to. `results`: (manner, seed, kind, suite) -> names or None; the manner "" is the control.
    Returns what was found (`manner kind name`), the runs that did not end, what fails politely, the suites that fell by manner, and lines to print."""
    control = {kind: set() for kind in KINDS}
    for (manner, _, kind, _), names in results.items():
        if manner == "" and names is not None:
            control[kind] |= names
    found, cut_short, said, tally = set(), [], [], {}
    fell = {manner: set() for manner in manners}
    for (manner, seed, kind, suite), names in results.items():
        if names is None:
            cut_short.append((manner, kind, suite, seed))
            if manner and kind == "tests":
                fell[manner].add(suite)
            continue
        if manner == "":
            continue
        names = names - control[kind]
        if kind == "walks":
            led = sorted(name[1:] for name in names if name.startswith("!"))
            said += [f"{manner:8} seed {seed} walk {name.split(':')[1]} breaks {name.split(':')[0]}, and so does its script with a polite fake: "
                     "for the chaos lab, no finding about manners" for name in led if name not in control[kind]]
            names = {name for name in names if not name.startswith("!")}
            # The list is kept by rule: which walk it is changes with every change to the walks.
            said += [f"{manner:8} seed {seed} walk {name.split(':')[1]} breaks {name.split(':')[0]}, which it keeps with a polite fake" for name in sorted(names)]
            names = {name.split(":")[0] for name in names}
        if names and kind == "tests":
            fell[manner].add(suite)
        tally[(manner, seed, kind)] = tally.get((manner, seed, kind), 0) + len(names)
        found |= {f"{manner} {kind} {name}" for name in names}
    said += [f"{manner:8} seed {seed} {kind:9} {count} fail" for (manner, seed, kind), count in sorted(tally.items())]
    polite = sorted(f"{kind} {name}" for kind in ("tests", "scenarios") for name in control[kind])
    return found, cut_short, polite, fell, said


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("manners", nargs="*", help="of: " + " ".join(MANNERS + WHAT_IF))
    parser.add_argument("--seeds", default="1,2,3")
    parser.add_argument("--only", choices=KINDS)
    parser.add_argument("--suite", action="append", default=[], help="only this suite's tests; may be given again")
    parser.add_argument("--walks", type=int, default=200, help="how many random walks (default 200)")
    parser.add_argument("--steps", type=int, default=200, help="how long each is (default 200)")
    parser.add_argument("--out", default=os.path.join(ROOT, ".build", "rude"))
    parser.add_argument("--known", default=KNOWN)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--write-known", action="store_true")
    parser.add_argument("--no-build", action="store_true")
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 2, help="how many runs side by side (default: one per core)")
    parser.add_argument("--lint", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        sys.exit(self_test())
    if args.lint:
        command_lint()
    if args.suite:
        if args.write_known or args.only not in (None, "tests"):
            sys.exit("rude.py: --suite is for a look at some tests: not with --write-known, and with no other --only than tests")
        args.only = "tests"
    manners = args.manners or MANNERS
    if unknown := [manner for manner in manners if manner not in MANNERS + WHAT_IF]:
        sys.exit(f"rude.py: no such manner: {' '.join(unknown)} (there are: {' '.join(MANNERS)}; and, what if: {' '.join(WHAT_IF)})")
    seeds = [int(seed) for seed in args.seeds.split(",")]
    os.makedirs(args.out, exist_ok=True)
    if not args.no_build:
        for command in (["swift", "build", "--build-tests"], ["swift", "build"]):
            if subprocess.run(command, cwd=ROOT, check=False).returncode != 0:
                sys.exit("rude.py: it does not build")
    kinds = [args.only] if args.only else KINDS
    if "tests" in kinds and not runner():
        sys.exit("rude.py: there is no test runner to start (.build/debug/ArborKitTests-test-runner): build first; on Linux only")
    all_suites = suites() if "tests" in kinds else {}
    if "tests" in kinds and not all_suites:
        sys.exit("rude.py: no tests are listed")
    if missing := [suite for suite in args.suite if suite not in all_suites]:
        sys.exit(f"rude.py: no such suite in ArborKitTests, or one that is left out: {' '.join(missing)}")
    if args.suite:
        all_suites = {suite: all_suites[suite] for suite in args.suite}

    def one(manner, seed, kind, suite):
        if kind == "tests":
            return tests(manner, seed, args.out, suite, all_suites[suite])
        if kind == "scenarios":
            return scenarios(manner, seed, args.out)
        return walks(manner, seed, args.out, args.walks, args.steps)

    # "" is the control, run the same way: what fails with a polite fake as well is no finding about manners.
    tasks = []
    for manner in [""] + manners:
        for seed in seeds if manner in DICE else seeds[:1]:
            for kind in kinds:
                tasks += [(manner, seed, kind, suite) for suite in (sorted(all_suites) if kind == "tests" else [""])]
    # The long ones first, or the last of them would run alone at the end.
    tasks.sort(key=lambda task: task[2] == "tests")
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = dict(zip(tasks, pool.map(lambda task: one(*task), tasks)))
    found, cut_short, polite, fell, said = summed(results, manners)
    for line in said:
        print(line)
    for name in polite:
        print(f"POLITE   {name} fails with a polite fake as well: no finding about manners, and not as it should be")
    for manner, kind, suite, seed in cut_short:
        name = f"{manner or 'polite'} {kind} {suite} seed {seed}".replace("  ", " ")
        print(f"DID NOT END   {name}: a hang, a crash that names no test, or fewer tests than the suite has; see the logs in {args.out}")

    counts = {(manner, kind): sum(1 for key in found if key.startswith(f"{manner} {kind} ")) for manner in manners for kind in KINDS}
    print()
    print(f"{'manner':8} {'tests':>6} {'scenarios':>10} {'walks':>6}   suites that hold")
    for manner in manners:
        holds = f"{len(all_suites) - len(fell[manner])} of {len(all_suites)}" if all_suites else "-"
        print(f"{manner:8} {counts[(manner, 'tests')]:6} {counts[(manner, 'scenarios')]:10} {counts[(manner, 'walks')]:6}   {holds}")
    # Counted apart: the what-ifs, and the tests and scenarios on the small display, most of which are written in the numbers of the large one.
    apart = {key for key in found if key.split()[0] in WHAT_IF or (key.split()[0] == "small" and key.split()[1] != "walks")}
    found -= apart
    if apart:
        with open(os.path.join(args.out, "apart.txt"), "w", encoding="utf-8") as out:
            out.write("".join(f"{key}\n" for key in sorted(apart)))
        print(f"counted apart, and listed in {os.path.join(args.out, 'apart.txt')}: {len(apart)} (the what-ifs, and the tests and scenarios on the small display)")
    if all_suites and (counted := [manner for manner in manners if manner not in WHAT_IF and manner != "small"]):
        down = set().union(*[fell[manner] for manner in counted])
        print(f"suites that hold under every manner that counts ({' '.join(counted)}): {len(all_suites) - len(down)} of {len(all_suites)}")

    text = ""
    if os.path.exists(args.known):
        with open(args.known, encoding="utf-8") as file:
            text = file.read()
    known = read_known(text)
    if args.suite:
        known = {key: remark for key, remark in known.items() if key.split()[2].split("/")[0] in args.suite}
    untried = {(manner, kind, suite) for manner, kind, suite, _ in cut_short}
    new, gone, untriaged = compared(found, known, manners, args.only, untried)
    if args.write_known:
        with open(args.known, "w", encoding="utf-8") as out:
            out.write(written(updated(found, known, manners, args.only, untried), count_polite()))
    else:
        for key in new:
            print(f"NEW   {key}")
        for key in gone:
            print(f"GONE  {key}   (cured? delete the line from {os.path.relpath(args.known, ROOT)})")
        for key in untriaged:
            print(f"WHOSE {key}   (ARBOR, TEST or FAKE? say so behind the line)")
    total = {kind: sum(1 for key in found if key.split()[1] == kind) for kind in KINDS}
    print(
        f"rude: {len(found)} failures (tests {total['tests']}, scenarios {total['scenarios']}, walks {total['walks']}) "
        f"under {len(manners)} manners; new {len(new)}, gone {len(gone)}, runs that did not end {len(cut_short)}, polite failures {len(polite)}")
    if args.check and (new or gone or untriaged or cut_short or polite):
        sys.exit(1)


# MARK: the self-test

def self_test():
    wrong = []

    def expect(what, got, wanted):
        if got != wanted:
            wrong.append(f"{what}: got {got!r}, wanted {wanted!r}")

    def event(kind, test=None, **more):
        return json.dumps({"kind": "event", "version": 0, "payload": {"kind": kind, **({"testID": test} if test else {}), **more}})

    a, b = "ArborKitTests.S/a()/S.swift:1:2", "ArborKitTests.S/b(x:)/S.swift:9:2"
    expect("a name", name_of(b), "S/b")
    expect("a name in a suite within a suite", name_of("ArborKitTests.S/T/c()/S.swift:1:2"), "S/T/c")
    whole = [event("runStarted"), event("testStarted", "ArborKitTests.S"), event("testStarted", a), event("testEnded", a), event("testStarted", b),
             event("issueRecorded", b, issue={"isKnown": False}), event("testEnded", b), event("testEnded", "ArborKitTests.S"), event("runEnded")]
    expect("a run that ended", outcome_of("\n".join(whole)), ({"S/b"}, {"S/a", "S/b"}, [], True))
    expect("a known issue is no failure", outcome_of("\n".join([event("testStarted", a), event("issueRecorded", a, issue={"isKnown": True}), event("testEnded", a), event("runEnded")]))[0], set())
    expect("a crash names the test that began and did not end", outcome_of("\n".join(whole[:5]) + '\n{"kind": "ev'), (set(), {"S/a"}, ["S/b"], False))
    expect("nothing at all", outcome_of(""), (set(), set(), [], False))
    trace = ["✔ Test a() passed", "S.swift:370: Fatal error: Unexpectedly found nil", "*** Program crashed: Illegal instruction ***", " 2 0x00 Optional.unwrap() + 1 in libswiftCore.so",
             " 3 [ra] 0x00 S.b(x:) + 6150 in ArborKitTests.so at /x/S.swift:370:5", " 4 0x00 S.c() + 1 in ArborKitTests.so"]
    expect("of many that began the backtrace names the one that crashed", culprit(trace, ["S/a", "S/b", "S/c"]), "S/b")
    expect("in a suite within a suite", culprit(["Fatal error", " 3 0x00 S.T.c() + 1 in ArborKitTests.so"], ["S/T/c", "S/T/d"]), "S/T/c")
    expect("one that began and did not end needs no backtrace", culprit([], ["S/b"]), "S/b")
    expect("a backtrace that names none of them", culprit(trace, ["S/y", "S/z"]), None)
    expect("what stands before the crash names nobody", culprit(["S.a() is slow", "no crash here"], ["S/a", "S/b"]), None)

    expect("scenarios", failed_scenarios(["✔ 01-a.sim", "✘ 18-b.sim: 2 expectations failed", "  ✘ indented is detail"]), {"18-b.sim"})
    hunt = ["seed 1", "chaos: seed 95 broke a rule at step 11:", "  [moved-at-resume] Arbor moved w104", "    launch", "chaos: seed 7 broke a rule at step 2:",
            "  [vanished] w1 is gone", "200 seeds × 200 steps: [(key: \"vanished\", value: 1)]"]
    hunt[4:4] = ["    dock 101 left", "", "seed 12: [vanished] w3 is gone ← close 103"]
    expect("walks, with the scripts of those that were shrunk", broken_by_walks(hunt, 200, 200),
           {"moved-at-resume:95": ["launch", "dock 101 left"], "vanished:12": None, "vanished:7": []})
    expect("a walk without a script goes by those of its rule that have one", by_their_siblings({"!slot:1", "!slot:2", "slot:9", "lost:3", "lost:8", "!gone:4", "gone:5", "gone:6", "alone:2"}, {"slot:9", "lost:8", "gone:6", "alone:2"}),
           {"!slot:1", "!slot:2", "!slot:9", "lost:3", "lost:8", "!gone:4", "gone:5", "gone:6", "alone:2"})
    expect("what a replay broke", rules_broken(["STEP 1", "RULE slot", "  [slot] w1 is at", "  [moved-twice] Arbor moved", "STEP 2"]), {"slot", "moved-twice"})
    expect("a hunt that did not get to its end proves nothing", broken_by_walks(hunt[:-1], 200, 200), None)

    results = {
        ("", 1, "tests", "S"): {"S/red-anyway"}, ("", 1, "tests", "T"): set(), ("", 1, "walks", ""): {"vanished:7"}, ("", 1, "scenarios", ""): set(),
        ("slow", 1, "tests", "S"): {"S/red-anyway", "S/a"}, ("slow", 1, "tests", "T"): set(), ("slow", 1, "walks", ""): {"vanished:7", "vanished:9", "lost:3", "!slot:4"},
        ("order", 1, "tests", "S"): {"S/red-anyway"}, ("order", 2, "tests", "S"): set(), ("order", 1, "tests", "T"): None, ("order", 1, "scenarios", ""): {"18.sim"},
    }
    found, cut_short, polite, fell, _ = summed(results, ["slow", "order"])
    expect("what is found: not what fails politely, a walk's rule though another walk breaks it politely", found,
           {"slow tests S/a", "slow walks vanished", "slow walks lost", "order scenarios 18.sim"})
    expect("a run that did not end", cut_short, [("order", "tests", "T", 1)])
    expect("what fails politely is said", polite, ["tests S/red-anyway"])
    expect("the suites that fell: also one whose run did not end", fell, {"slow": {"S"}, "order": {"T"}})

    known = read_known("# head\nslow tests S/a   # ARBOR: a fault\norder tests S/b # TEST: pins\n\ntwice tests S/c\nslow walks lost # UNTRIAGED\n")
    expect("the list is read", known, {"slow tests S/a": "ARBOR: a fault", "order tests S/b": "TEST: pins", "twice tests S/c": "", "slow walks lost": "UNTRIAGED"})
    expect("new, gone, and without a verdict; a manner that was not run is left alone",
           compared({"slow tests S/a", "slow tests S/z", "slow walks lost"}, known, ["slow", "order"], None), (["slow tests S/z"], ["order tests S/b"], ["slow walks lost"]))
    expect("what was not tried has not gone", compared(set(), known, ["slow", "order"], None, {("slow", "tests", "S"), ("slow", "walks", "")})[1], ["order tests S/b"])
    expect("nor is it taken off the list", sorted(updated(set(), known, ["slow"], None, {("slow", "tests", "S")})), ["order tests S/b", "slow tests S/a", "twice tests S/c"])
    expect("a kind that was not run is left alone", compared({"slow tests S/a"}, known, ["slow"], "tests"), ([], [], []))
    expect("the list after a run", updated({"slow tests S/a", "slow tests S/z", "slow walks lost"}, known, ["slow", "order"], None),
           {"slow tests S/a": "ARBOR: a fault", "twice tests S/c": "", "slow walks lost": "UNTRIAGED", "slow tests S/z": "UNTRIAGED"})
    expect("written and read again", read_known(written({"slow tests S/a": "ARBOR: a fault"}, 2)), {"slow tests S/a": "ARBOR: a fault"})
    expect("and its head", polite_in_head(written({}, 2)), 2)

    expect("a check's shallow checkout fetches one commit", fetch_words("trunk", True), ["fetch", "--quiet", "--depth=1", "origin", "trunk"])
    expect("a whole clone is never made shallow", fetch_words("trunk", False), ["fetch", "--quiet", "origin", "trunk"])
    good = written({"slow tests S/a": "ARBOR: a fault", "small walks lost": "ARBOR: lost"}, 1)
    expect("a good list", lint(good, None, 1), [])
    expect("a good list that has shrunk", lint(good, written({"slow tests S/a": "ARBOR: x", "slow tests S/b": "TEST: y", "small walks lost": "ARBOR: z"}, 3), 1), [])
    for what, text, base, polite, part in [
        ("no verdict", good + "slow tests S/b\n", None, 1, "wants a verdict"),
        ("a verdict without a word", good + "slow tests S/b # ARBOR:\n", None, 1, "wants a verdict"),
        ("untriaged", good + "slow tests S/b # UNTRIAGED\n", None, 1, "wants a verdict"),
        ("no such manner", good + "rude tests S/b # TEST: x\n", None, 1, "is not <manner>"),
        ("a what-if", good + "late tests S/b # TEST: x\n", None, 1, "is not <manner>"),
        ("no such kind", good + "slow suites S # TEST: x\n", None, 1, "is not <manner>"),
        ("too many words", good + "slow tests S/b c # TEST: x\n", None, 1, "is not <manner>"),
        ("tests on the small display", good + "small tests S/b # TEST: x\n", None, 1, "counted apart"),
        ("scenarios on the small display", good + "small scenarios 02.sim # TEST: x\n", None, 1, "counted apart"),
        ("the head is out of date", good, None, 2, "the list's head says 1"),
        ("no head", "slow tests S/a # ARBOR: a fault\n", None, 0, "the list's head says None"),
        ("no manners in the head", "# tests that stay polite: 0\n", None, 0, "which manners it is about"),
        ("it has grown by a manner that had no line left", good, written({"small walks lost": "ARBOR: z"}, 1), 1, "`slow tests S/a` is new on the list"),
        ("it has grown from nothing", good, written({}, 1), 1, "`slow tests S/a` is new on the list"),
        ("it has grown", good, written({"slow tests S/b": "ARBOR: x", "small walks lost": "ARBOR: z"}, 1), 1, "`slow tests S/a` is new on the list"),
        ("more tests stay polite", written({}, 2), written({}, 1), 2, "where there were 1"),
    ]:
        problems = lint(text, base, polite)
        if not any(part in problem for problem in problems):
            wrong.append(f"{what}: passes, or fails for another reason: {problems}")
    expect("a new manner brings its own lines", lint(good, written({"small walks lost": "ARBOR: z"}, 1).replace(" slow ", " "), 1), [])

    for line in wrong:
        print(f"rude.py --self-test: {line}")
    return 1 if wrong else 0


if __name__ == "__main__":
    main()
