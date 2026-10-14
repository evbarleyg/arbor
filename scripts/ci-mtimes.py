#!/usr/bin/env python3
"""Lets a build folder from a cache be built upon, after a fresh checkout, without trusting it.

  scripts/ci-mtimes.py record     after a build: note, in .build/ci-mtimes.tsv, each source file's content and time stamp
  scripts/ci-mtimes.py restore    after a checkout and after the cache put .build back: give every file whose CONTENT is
                                  what it was at that build the time stamp it had then

Why: SwiftPM, the compiler's incremental mode and lib.sh's `arbor_is_current` all tell by a file's time stamp whether it
has changed, and a checkout stamps every file with the present moment. So a cached .build is rebuilt from the first file
to the last, and the cache has bought nothing.

Why it cannot make a stale build pass for a fresh one: content decides, never a name or a date. A file is compared by Git's
own hash of what is in the working tree now. One that differs or is new is stamped with the present, or with the moment after the cached
build ended if that is later, and is compiled again. (The time of the checkout will not do. Another job may have built and saved
after this one checked out, and `arbor_is_current` would take its helper tool, being newer than the changed source, for current.) A file
that is gone is for SwiftPM to notice: the list of a target's files is part of its build plan. If the note is missing or damaged no file
gets an earlier time stamp, and everything is built.

For CI only: on a person's machine the time stamps are right as they are.
"""

import os
import subprocess
import sys
import time

NOTE = os.path.join(".build", "ci-mtimes.tsv")
# Everything a build or a Mac shell script compiles.
COMPILED = ["Package.swift", "Sources", "Tests", "scripts/mac-shell"]


def hashes():
    """Path to Git's hash of the file's content as it lies in the working tree (not as the index remembers it)."""
    listed = subprocess.run(["git", "ls-files", "-z", "--"] + COMPILED, capture_output=True, check=True).stdout
    paths = [path for path in listed.decode("utf-8", "surrogateescape").split("\0") if path and os.path.isfile(path)]
    answer = subprocess.run(["git", "hash-object", "--no-filters", "--stdin-paths"], input="\n".join(paths), capture_output=True,
                            text=True, errors="surrogateescape", check=True).stdout.split()
    if len(answer) != len(paths):
        raise RuntimeError(f"{len(paths)} files, {len(answer)} hashes")
    return dict(zip(paths, answer))


def record():
    lines = [f"{digest}\t{os.stat(path).st_mtime_ns}\t{path}\n" for path, digest in sorted(hashes().items())
             if "\n" not in path and "\t" not in path]
    with open(NOTE, "w", encoding="utf-8", errors="surrogateescape") as handle:
        # Nothing in .build is newer than this.
        handle.write(f"built\t{time.time_ns()}\t\n")
        handle.writelines(lines)
    print(f"noted {len(lines)} files in {NOTE}")


def restore():
    try:
        with open(NOTE, encoding="utf-8", errors="surrogateescape") as handle:
            noted = [line.rstrip("\n").split("\t", 2) for line in handle]
        then = {path: (digest, int(stamp)) for digest, stamp, path in noted}
        built = then.pop("")[1]
    except (OSError, ValueError, KeyError) as error:
        print(f"no usable {NOTE} ({type(error).__name__}): every file counts as changed")
        then, built = {}, 0
    now = hashes()
    same = [path for path, digest in now.items() if path in then and then[path][0] == digest]
    for path in same:
        os.utime(path, ns=(then[path][1], then[path][1]))
    changed = sorted(set(now) - set(same))
    # A whole second later: some file systems and some comparisons know no finer time.
    later = max(time.time_ns(), built + 1_000_000_000)
    for path in changed:
        os.utime(path, ns=(later, later))
    print(f"{len(same)} files are as they were at the cached build; {len(changed)} changed or new, {len(set(then) - set(now))} gone")
    for path in changed[:20]:
        print(f"  {path}")


def main():
    if sys.argv[1:] == ["record"]:
        record()
    elif sys.argv[1:] == ["restore"]:
        restore()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
