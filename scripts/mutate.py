#!/usr/bin/env python3
"""Cheap mutation testing: which lines of the headless stack can break without a test noticing?

Copies the checkout to a scratch folder, then changes one thing at a time there (flips a
comparison, swaps `min` and `max`, drops a statement, changes a constant), builds, and runs what
`make check` runs. A mutant that fails to compile is thrown away; one that makes a test, the
smoke run or a scenario fail is killed; one that passes everything SURVIVED, which means either
that nothing checks that line or that the change makes no difference. A person decides which.
One whose build did not end in time says nothing ("timed out"): run it again on a quieter machine.

Usage:
  scripts/mutate.py                                   a sample of every headless source file
  scripts/mutate.py --per-file 0 Sources/ArborCore/Drop.swift    every mutant of one file
  scripts/mutate.py --list Sources/ArborCore/Drop.swift          show the mutants it would run, run nothing (a sample
                                                                 too: all of them with --per-file 0)
  scripts/mutate.py --again survivors.tsv                        after writing tests: only what SURVIVED in that --out file

  --per-file N   at most N mutants per file, spread over its lines (default 12; 0 means all)
  --seed N       which sample (default 1)
  --shard I/N    run only every Nth mutant, starting at I: for several copies side by side, each
                 with a --scratch of its own
  --shuffle      run them in random order, so that a run cut short has still looked everywhere
  --scratch DIR  where the copy goes (default: a folder next to the checkout)
  --out FILE     append one tab-separated line per mutant: outcome, file:line, operator, before, after,
                 and which tests noticed

Each mutant takes as long as an incremental build plus the tests: ten to twenty seconds on a machine of its
own, minutes on a busy one. The checkout itself is never changed.

A mutant that has SURVIVED again after you wrote a test for it is the tool telling the truth: the test passes with the
line broken. Try each new test against its mutant (--again, or break the line by hand) before you push it. See "Mutation testing" in docs/TESTING.md.
"""

import argparse
import glob
import os
import random
import re
import shutil
import signal
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_FILES = ["Sources/ArborCore/*.swift", "Sources/ArborKit/Controller/*.swift",
                 "Sources/ArborKit/Platform/*.swift", "Sources/ArborTesting/Expectations.swift"]
# For the tests, the smoke run and the scenarios, where a mutant can loop for ever. Raised to five times what
# the slowest of them takes with nothing changed, if that is more: on a busy machine the tests alone can take minutes.
TIMEOUT = 120
# A build ends by itself, and the first one builds everything from nothing.
BUILD_TIMEOUT = 900

# (name, pattern, replacement). Operators need spaces around them, which keeps generics,
# arrows and ranges out; the code base is formatted that way throughout.
SWAPS = [
    ("<  to <=", r" < ", " <= "), ("<= to <", r" <= ", " < "),
    (">  to >=", r" > ", " >= "), (">= to >", r" >= ", " > "),
    ("== to !=", r" == ", " != "), ("!= to ==", r" != ", " == "),
    ("&& to ||", r" && ", " || "), ("|| to &&", r" \|\| ", " && "),
    ("+  to -", r" \+ ", " - "), ("-  to +", r" - ", " + "),
    ("*  to /", r" \* ", " / "), ("/  to *", r" / ", " * "),
    ("+= to -=", r" \+= ", " -= "), ("-= to +=", r" -= ", " += "),
    ("true to false", r"\btrue\b", "false"), ("false to true", r"\bfalse\b", "true"),
    ("drop !", r"(?<=[\s(,:])!(?=[A-Za-z_(])", ""),
    ("min to max", r"\bmin\(", "max("), ("max to min", r"\bmax\(", "min("),
    ("first to last", r"\.first\b(?!\()", ".last"), ("last to first", r"\.last\b(?!\()", ".first"),
    ("minX to maxX", r"\.minX\b", ".maxX"), ("maxX to minX", r"\.maxX\b", ".minX"),
    ("minY to maxY", r"\.minY\b", ".maxY"), ("maxY to minY", r"\.maxY\b", ".minY"),
    ("width to height", r"\.width\b", ".height"), ("height to width", r"\.height\b", ".width"),
    ("left to right", r"\.left\b", ".right"), ("right to left", r"\.right\b", ".left"),
    ("top to bottom", r"\.top\b", ".bottom"), ("bottom to top", r"\.bottom\b", ".top"),
    ("leading to trailing", r"\bisLeading\b(?! *:)", "isLeading == false"),
]
NUMBER = re.compile(r"(?<![\w.\"])(\d+(?:\.\d+)?)(?![\w.\"]|\.\d)")
SKIP_LINE = re.compile(r"^\s*(//|import |@|#|\}|\{|\)|\]|case \w+(, \w+)*$|Log\.|public (static )?let \w+ = \")")
# A line that is one whole statement with an effect and no declaration: safe to drop.
STATEMENT = re.compile(r"^\s*(?!let |var |guard |if |for |while |switch |case |default|return|func |else|defer|do |try |throw |"
                       r"public |private |internal |fileprivate |static |struct |class |enum |extension |init|break|continue|"
                       r"precondition|assert|fatalError)[A-Za-z_][\w.\[\]!?$]*(\(.*\))?( [-+*/]?= .+)?$")
GUARD = re.compile(r"^\s*guard (?!.*\b(let|var|case)\b).* else \{ (return[^}]*|continue|break) \}$")


def code_part(line):
    """The line without a trailing comment, and with string literals blanked, for matching only."""
    masked = re.sub(r'"(?:\\.|[^"\\])*"', lambda m: '"' + "_" * (len(m.group(0)) - 2) + '"', line)
    cut = masked.find("//")
    return masked if cut < 0 else masked[:cut] + " " * (len(masked) - cut)


def balanced(text):
    return all(text.count(a) == text.count(b) for a, b in ("()", "[]", "{}"))


def mutants_of(path):
    """Every mutant of a file as (line number, operator, new line or None to drop it)."""
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().split("\n")
    found, in_text = [], False
    for number, line in enumerate(lines, 1):
        if line.count('"""') % 2 == 1:
            in_text = not in_text
            continue
        if in_text or not line.strip() or SKIP_LINE.match(line):
            continue
        code = code_part(line)
        for name, pattern, replacement in SWAPS:
            for match in re.finditer(pattern, code):
                found.append((number, name, line[:match.start()] + replacement + line[match.end():]))
        for match in NUMBER.finditer(code):
            text = match.group(1)
            changed = "1" if float(text) == 0 else (str(int(text) + 1) if "." not in text else str(float(text) * 2))
            found.append((number, "number", line[:match.start()] + changed + line[match.end():]))
        stripped = code.rstrip()
        if balanced(stripped) and (STATEMENT.match(stripped) or GUARD.match(stripped)):
            found.append((number, "drop line", None))
    return lines, found


def sample(found, limit, rng):
    """At most `limit` mutants, on different lines where possible, spread over the file."""
    if not limit or len(found) <= limit:
        return found
    by_line = {}
    for mutant in found:
        by_line.setdefault(mutant[0], []).append(mutant)
    numbers = sorted(by_line)
    if len(numbers) > limit:
        step = len(numbers) / limit
        numbers = sorted({numbers[int((i + rng.random()) * step)] for i in range(limit)})
    picked = [rng.choice(by_line[n]) for n in numbers]
    rest = [m for m in found if m not in picked]
    rng.shuffle(rest)
    return sorted(picked + rest[:limit - len(picked)])


def run(command, cwd, limit=None):
    # A group of its own: a mutant that loops for ever does so in a child of `swift test`, which would outlive it
    # and keep a core busy for the rest of the day.
    process = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                               errors="replace", start_new_session=True)
    try:
        output, _ = process.communicate(timeout=limit or TIMEOUT)
        return process.returncode, output
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.communicate()
        return 124, "timed out"


def patience(unchanged):
    """How long a mutant's tests get, given the seconds that everything takes with nothing changed."""
    return max(TIMEOUT, round(5 * unchanged))


def judge(scratch):
    """Returns (outcome, what noticed)."""
    code, output = run(["swift", "build", "--build-tests"], scratch, BUILD_TIMEOUT)
    if code == 124:
        return "timed out", "the build"
    if code != 0:
        return "uncompilable", ""
    code, output = run(["swift", "test", "--skip-build"], scratch)
    if code != 0:
        names = re.findall(r"✘ Test (\w+)\(", output)
        return "killed", ",".join(sorted(set(names))[:3]) or ("timeout" if code == 124 else f"exit {code}")
    for script in ("scripts/sim-smoke.sh", "scripts/scenarios.sh"):
        code, output = run(["bash", script], scratch)
        if code != 0:
            return "killed", script
    return "SURVIVED", ""


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("files", nargs="*", help="source files or globs, relative to the checkout")
    parser.add_argument("--per-file", type=int, default=12)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--shard", default="0/1")
    parser.add_argument("--shuffle", action="store_true")
    parser.add_argument("--scratch", default=ROOT.rstrip("/") + "-mutants")
    parser.add_argument("--out")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--again", action="append", default=[], help="an earlier --out file: run only what survived there")
    args = parser.parse_args()
    index, shards = (int(part) for part in args.shard.split("/"))

    # By what the line said rather than by its number, which moves when the file is edited.
    survivors = set()
    for name in args.again:
        with open(name, encoding="utf-8") as handle:
            for row in (line.rstrip("\n").split("\t") for line in handle):
                if row[0] == "SURVIVED":
                    survivors.add((row[1].rsplit(":", 1)[0], row[2], row[3], row[4]))
    patterns = args.files or (sorted({survivor[0] for survivor in survivors}) if args.again else DEFAULT_FILES)
    paths = sorted({p for pattern in patterns for p in glob.glob(os.path.join(ROOT, pattern))})
    if not paths:
        sys.exit("no such source files")
    rng = random.Random(args.seed)
    work = []
    for path in paths:
        relative = os.path.relpath(path, ROOT)
        lines, found = mutants_of(path)
        if args.again:
            chosen = [m for m in found if (relative, m[1], lines[m[0] - 1].strip(), (m[2] or "").strip()) in survivors]
        else:
            chosen = sample(found, args.per_file, rng)
        for mutant in chosen:
            work.append((relative, lines, mutant))
    if args.shuffle:
        rng.shuffle(work)
    work = work[index::shards]
    if args.list:
        for relative, lines, (number, name, changed) in work:
            print(f"{relative}:{number}\t{name}\t{lines[number - 1].strip()}\t{(changed or '').strip()}")
        print(f"{len(work)} mutants", file=sys.stderr)
        return

    shutil.rmtree(args.scratch, ignore_errors=True)
    shutil.copytree(ROOT, args.scratch, symlinks=True,
                    ignore=shutil.ignore_patterns(".git", ".build", "build", "*-mutants*"))
    print(f"{len(work)} mutants in {args.scratch}; checking that the unchanged copy passes…", flush=True)
    outcome, detail = judge(args.scratch)
    if outcome != "SURVIVED":
        sys.exit(f"the unchanged copy does not pass ({outcome} {detail}); fix that first")
    # Built by now, so this measures the tests, the smoke run and the scenarios together: more than the slowest of them.
    global TIMEOUT
    started = time.monotonic()
    judge(args.scratch)
    TIMEOUT = patience(time.monotonic() - started)

    counts = {}
    for relative, lines, (number, name, changed) in work:
        target = os.path.join(args.scratch, relative)
        mutated = list(lines)
        mutated[number - 1] = changed if changed is not None else ""
        with open(target, "w", encoding="utf-8") as handle:
            handle.write("\n".join(mutated))
        outcome, detail = judge(args.scratch)
        with open(target, "w", encoding="utf-8") as handle:
            handle.write("\n".join(lines))
        counts[outcome] = counts.get(outcome, 0) + 1
        row = "\t".join([outcome, f"{relative}:{number}", name, lines[number - 1].strip(), (changed or "").strip(), detail])
        print(row, flush=True)
        if args.out:
            with open(args.out, "a", encoding="utf-8") as handle:
                handle.write(row + "\n")
    print(", ".join(f"{key} {value}" for key, value in sorted(counts.items())))


if __name__ == "__main__":
    main()
