#!/usr/bin/env python3
"""Keeps what a hosted Mac sends back small, and says what was left out.

    scripts/ci-keep-output.py <folder>          before the folder is pushed as a branch mac-shell-out/<tag>
    scripts/ci-keep-output.py --self-test

Everybody's `git fetch` brings every output branch along, so one run's films are paid for by all. A branch holds at most 40 MB.
What tells what happened always stays: what the scripts printed, exit codes, Arbor's logs, traces (docs/TRACES.md) and every other text. They
are small, Git packs them well, and they are what becomes a test. What goes, until the rest fits: films, the largest first; then pictures, the
largest first; then whatever else is over a megabyte and not on the list below.

Nothing goes silently: `dropped.txt` at the top of the folder lists every file that was left out with its size, and a warning on the job
says how many and how much. A file over 50 MB goes whatever the limit: GitHub refuses a push with one of 100.

A script that needs more says so, where everybody can read it: it writes the number of megabytes, 200 at most, into `keep-mb.txt` in its
output folder (`echo 150 > "$ARBOR_OUT/keep-mb.txt"`). Of several scripts in one run the largest wish counts, for all of them together.

Python 3.9, which is what the hosted Macs have, and nothing but the standard library.
"""

import os
import sys
import tempfile

LIMIT_MB = 40
MOST_MB = 200
ONE_FILE_MB = 50
MB = 1_000_000
FILMS = {".mov", ".mp4", ".m4v", ".webm", ".gif"}
PICTURES = {".png", ".jpg", ".jpeg", ".heic", ".tif", ".tiff", ".bmp"}
# Whatever their size (short of what GitHub refuses): without them nobody can tell what the run was.
ALWAYS = {"output.txt", "exit-code.txt", "summary.txt", "keep-mb.txt", "run.json"}
TELLS_WHAT_HAPPENED = {".jsonl", ".log", ".txt", ".json", ".tsv", ".md"}


def files_in(folder):
    found = []
    for where, _, names in os.walk(folder):
        for name in names:
            path = os.path.join(where, name)
            if os.path.islink(path) or not os.path.isfile(path):
                continue
            found.append((os.path.relpath(path, folder), os.path.getsize(path)))
    return sorted(found)


def limit_for(folder, files):
    """The limit in bytes, and the wishes that could not be read."""
    limit, odd = LIMIT_MB, []
    for path, _ in files:
        if os.path.basename(path) != "keep-mb.txt":
            continue
        with open(os.path.join(folder, path), encoding="utf-8", errors="replace") as file:
            text = file.read().strip()
        if text.isdigit() and int(text) > 0:
            limit = max(limit, min(int(text), MOST_MB))
        else:
            odd.append(path)
    return limit * MB, odd


def rank(path, size):
    """The order in which files go: the lower the sooner; None never."""
    name, kind = os.path.basename(path), os.path.splitext(path)[1].lower()
    if name in ALWAYS:
        return None
    if kind in FILMS:
        return 0
    if kind in PICTURES:
        return 1
    if kind in TELLS_WHAT_HAPPENED:
        return None
    return 2 if size > MB else None


def choose(files, limit):
    """What is left out: [(path, size, why)]."""
    dropped = [(path, size, f"over {ONE_FILE_MB} MB") for path, size in files if size > ONE_FILE_MB * MB]
    gone = {path for path, _, _ in dropped}
    total = sum(size for path, size in files if path not in gone)
    candidates = [(rank(path, size), -size, path) for path, size in files if path not in gone and rank(path, size) is not None]
    for _, size, path in sorted(candidates):
        if total <= limit:
            break
        dropped.append((path, -size, "to fit"))
        total += size
    return dropped, total


def megabytes(size):
    return f"{size / MB:.1f} MB"


def keep(folder, say=print):
    files = files_in(folder)
    # Of an earlier call: what it says is no longer in the folder, so it would be forgotten by writing the list anew.
    earlier = ""
    note = os.path.join(folder, "dropped.txt")
    if os.path.isfile(note):
        with open(note, encoding="utf-8", errors="replace") as file:
            earlier = file.read()
        files = [(path, size) for path, size in files if path != "dropped.txt"]
    limit, odd = limit_for(folder, files)
    for path in odd:
        say(f"::warning title=mac-shell output::{path} should hold a number of megabytes and nothing else: not counted")
    dropped, total = choose(files, limit)
    stuck = []
    for entry in dropped:
        try:
            os.remove(os.path.join(folder, entry[0]))
        except OSError as error:
            # In a folder nobody may write to, say. It stays, and the rest of the output is not lost over it.
            say(f"::warning title=mac-shell output::{entry[0]} could not be left out: {error.strerror}")
            stuck.append(entry)
    dropped = [entry for entry in dropped if entry not in stuck]
    total += sum(size for _, size, _ in stuck)
    if dropped:
        lost = sum(size for _, size, _ in dropped)
        head = (
            f"Left out of this branch: {len(dropped)} file(s), {megabytes(lost)}, so that it stays under {limit // MB} MB "
            f"(scripts/ci-keep-output.py; a script that needs more writes the megabytes, {MOST_MB} at most, into keep-mb.txt in its output folder)."
        )
        with open(note, "w", encoding="utf-8") as file:
            file.write(earlier + head + "\n" + "".join(f"{size:>12}  {path}  ({why})\n" for path, size, why in dropped))
        names = ", ".join(path for path, _, _ in dropped[:8]) + (" …" if len(dropped) > 8 else "")
        say(f"::warning title=mac-shell output::left out {len(dropped)} file(s), {megabytes(lost)}, listed in dropped.txt: {names}")
    if total > limit:
        say(f"::warning title=mac-shell output::{megabytes(total)} of logs, traces and text are over the limit of {limit // MB} MB and stay: they tell what happened")
    say(f"mac-shell output: {len(files) - len(dropped)} file(s), {megabytes(total)}")
    return dropped


def self_test():
    failures = []

    def expect(what, holds):
        if not holds:
            failures.append(what)

    def situation(sizes, wishes=None):
        """Makes the files (sparse, so that 60 MB cost nothing), runs `keep`, returns what is left, what was said and dropped.txt."""
        with tempfile.TemporaryDirectory() as folder:
            for path, size in sizes.items():
                os.makedirs(os.path.dirname(os.path.join(folder, path)) or folder, exist_ok=True)
                with open(os.path.join(folder, path), "wb") as file:
                    file.truncate(size)
            for path, text in (wishes or {}).items():
                os.makedirs(os.path.dirname(os.path.join(folder, path)) or folder, exist_ok=True)
                with open(os.path.join(folder, path), "w", encoding="utf-8") as file:
                    file.write(text)
            said = []
            keep(folder, said.append)
            left = {path for path, _ in files_in(folder)}
            note = ""
            if "dropped.txt" in left:
                with open(os.path.join(folder, "dropped.txt"), encoding="utf-8") as file:
                    note = file.read()
            return left, "\n".join(said), note

    left, said, note = situation({"output.txt": 10, "a.png": 5 * MB, "traces/x.jsonl": 2 * MB})
    expect("a small run is left as it is", left == {"output.txt", "a.png", "traces/x.jsonl"} and "warning" not in said and not note)

    left, said, note = situation({"output.txt": 10, "film.mov": 30 * MB, "small.mov": 4 * MB, "a.png": 9 * MB, "b.png": 8 * MB, "arbor.log": MB})
    expect("films go first, the largest first, and no more than needed", left == {"output.txt", "small.mov", "a.png", "b.png", "arbor.log", "dropped.txt"})
    expect("what went is listed with its size", "film.mov" in note and str(30 * MB) in note and "1 file(s)" in note)
    expect("and the job says so", "::warning" in said and "film.mov" in said)

    left, _, note = situation({"a.png": 30 * MB, "b.png": 20 * MB, "c.png": 15 * MB, "1-x/arbor.log": 3 * MB, "1-x/traces/t.jsonl": 19 * MB})
    expect("then pictures, and never a log or a trace", left == {"c.png", "1-x/arbor.log", "1-x/traces/t.jsonl", "dropped.txt"})

    left, said, _ = situation({"output.txt": 30 * MB, "samples.log": 30 * MB})
    expect("text alone over the limit stays, and that is said", left == {"output.txt", "samples.log"} and "stay" in said)

    left, _, note = situation({"core.bin": 45 * MB, "tiny.bin": 100, "a.log": 10})
    expect("something else that is big goes, something small does not", left == {"tiny.bin", "a.log", "dropped.txt"})

    left, _, note = situation({"huge.log": 60 * MB, "output.txt": 5})
    expect("what GitHub might refuse goes whatever it is", left == {"output.txt", "dropped.txt"} and "over 50 MB" in note)

    left, _, _ = situation({"film.mov": 45 * MB, "b.mov": 45 * MB, "c.mov": 45 * MB}, {"2-films/keep-mb.txt": "150\n"})
    expect("a script that asks for more gets it", left == {"film.mov", "b.mov", "c.mov", "2-films/keep-mb.txt"})

    left, _, _ = situation({"a.mov": 45 * MB, "b.mov": 45 * MB, "c.mov": 45 * MB, "d.mov": 45 * MB, "e.mov": 45 * MB}, {"keep-mb.txt": "100000"})
    expect("but no more than the most", len([path for path in left if path.endswith(".mov")]) == 4)

    left, said, _ = situation({"a.mov": 45 * MB}, {"keep-mb.txt": "all of it"})
    expect("a wish that is no number is not counted, and that is said", "a.mov" not in left and "should hold a number" in said)

    with tempfile.TemporaryDirectory() as folder:
        for name in ("a.mov", "b.mov"):
            with open(os.path.join(folder, name), "wb") as file:
                file.truncate(30 * MB)
        keep(folder, lambda _: None)
        with open(os.path.join(folder, "c.mov"), "wb") as file:
            file.truncate(35 * MB)
        keep(folder, lambda _: None)
        with open(os.path.join(folder, "dropped.txt"), encoding="utf-8") as file:
            note = file.read()
        expect("called twice, the list holds what went both times", note.count(".mov") == 2 and note.count("Left out") == 2)

    if os.geteuid() != 0:  # root may write anywhere
        with tempfile.TemporaryDirectory() as folder:
            os.makedirs(os.path.join(folder, "locked"))
            for name in ("locked/a.mov", "b.mov"):
                with open(os.path.join(folder, name), "wb") as file:
                    file.truncate(45 * MB)
            os.chmod(os.path.join(folder, "locked"), 0o555)
            said = []
            keep(folder, said.append)
            os.chmod(os.path.join(folder, "locked"), 0o755)
            expect("a file that cannot be removed stays, and that is said", os.path.exists(os.path.join(folder, "locked/a.mov")) and any("could not be left out" in line for line in said))

    for failure in failures:
        print(f"✘ {failure}")
    print(f"ci-keep-output self-test: {'failed' if failures else 'passed'}")
    return 1 if failures else 0


def main(arguments):
    if arguments == ["--self-test"]:
        return self_test()
    if len(arguments) != 1 or arguments[0].startswith("-"):
        print(__doc__.strip().split("\n\n")[1], file=sys.stderr)
        return 64
    if not os.path.isdir(arguments[0]):
        print(f"ci-keep-output: no folder {arguments[0]}", file=sys.stderr)
        return 2
    keep(arguments[0])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
