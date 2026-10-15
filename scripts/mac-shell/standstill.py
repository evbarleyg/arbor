#!/usr/bin/env python3
"""For how long did the display stand still? Reads the films of a run (camera.swift's film.log) and says, scene by scene.

With pulse.swift's strip on the display every frame differs from the one before, so a wait between two frames is a display that showed one
picture for that long, whatever else was or was not meant to move.

  standstill.py table <run folder>             a line for each film: the longest wait that begins between the cause and 1.5 s after it | the same for what is not the strip, every wait of
                                               100 ms and more, the longest wait before the cause (nothing is being done then), what the processes burnt meanwhile; then a line for each group of films
  standstill.py longest <film folder>          that film's longest wait, of the display or of what is not the strip, in ms: for a script that decides what to keep
  standstill.py worst <run folder> <n>         `<from> <to> <film>` in seconds since 1970, outwards to whole seconds, for the n longest waits
  standstill.py story <run folder> <film>      everything that is known about that film on one clock, ms after the cause: frames, marks, the mover's steps,
                                               the pulse's own trouble, the sampler's lines, Arbor's log

The cause is the last key that went down after the script's mark `action`, or the mover's `go`, or the mark `go`, or the button coming up, or else `action` itself.
Needs nothing but Python.
"""

import datetime
import glob
import os
import re
import sys

SINCE, UNTIL = -50, 1500


def lines_of(path):
    if not os.path.isfile(path):
        return []
    with open(path, encoding="utf-8", errors="replace") as file:
        found = []
        for line in file:
            words = line.split()
            if len(words) >= 2 and words[0].lstrip("-").isdigit():
                found.append((int(words[0]), words[1], words[2:]))
        return found


class Film:
    def __init__(self, folder, movers=()):
        self.folder = folder
        self.name = os.path.basename(os.path.normpath(folder))
        self.lines = lines_of(os.path.join(folder, "film.log"))
        self.frames = sorted((time, int(rest[0]), [int(word) for word in rest[1:5]]) for time, kind, rest in self.lines if kind == "F")
        self.marks = [(time, " ".join(rest)) for time, kind, rest in self.lines if kind == "M"]
        begin, end = (self.frames[0][0], self.frames[-1][0]) if self.frames else (0, 0)
        action = next((time for time, mark in self.marks if mark == "action"), begin)
        keys = [time for time, kind, rest in self.lines if kind == "K" and rest[:1] == ["down"] and time >= action]
        goes = [time for time, kind, rest in movers if rest[:1] == ["go"] and action <= time <= end]
        goes += [time for time, mark in self.marks if mark == "go"]
        clicks = [time for time, kind, rest in self.lines if kind == "B" and rest[:1] == ["up"] and time >= action]
        self.cause, self.how = (keys[-1], "key") if keys else (goes[0], "go") if goes else (clicks[-1], "click") if clicks else (action, "about")

    def waits(self, least=0):
        """[(ms after the cause at which the wait begins, its length)]"""
        times = [time for time, _, _ in self.frames]
        return [(a - self.cause, b - a) for a, b in zip(times, times[1:]) if SINCE <= a - self.cause <= UNTIL and b - a >= least]

    def waits_elsewhere(self):
        """The same for what is not the pulse's strip, while a motion should be playing (waits that begin up to 0.35 s after the cause): a display that goes on while the
        stage stands still, and a film without the strip, in which the rest after the motion is no standstill."""
        times = [time for time, _, place in self.frames if not inside_the_strip(place)]
        return [(a - self.cause, b - a) for a, b in zip(times, times[1:]) if 0 <= a - self.cause <= 350]

    def act(self):
        """Of what is not the strip: when the display first and last changed after the cause (up to 1.5 s), and in how many frames."""
        times = [time - self.cause for time, _, place in self.frames if not inside_the_strip(place) and 0 < time - self.cause <= UNTIL]
        return (times[0], times[-1], len(times)) if times else (0, 0, 0)

    def before(self):
        """The longest wait that ends before the cause: what this Mac does with nothing being done, in the same film."""
        times = [time for time, _, _ in self.frames]
        return max((b - a for a, b in zip(times, times[1:]) if b <= self.cause + SINCE), default=0)

    def longest(self):
        return max(self.waits(), key=lambda wait: wait[1], default=(0, 0))

    def burnt(self):
        """What each process burnt between the two marks `cpu …`, in ms of processor for each second that passed: {name: ms}"""
        seen = {}
        for time, mark in self.marks:
            words = mark.split()
            if len(words) == 3 and words[0] == "cpu":
                seen.setdefault(words[1], []).append((time, seconds(words[2])))
        return {name: round((values[-1][1] - values[0][1]) * 1e6 / max(values[-1][0] - values[0][0], 1)) for name, values in seen.items() if len(values) > 1}


STRIP = (440, 31, 256, 12)


def inside_the_strip(place):
    if len(place) < 4:
        return False
    x, y, w, h = place
    return STRIP[0] <= x and STRIP[1] <= y and x + w <= STRIP[0] + STRIP[2] and y + h <= STRIP[1] + STRIP[3]


def seconds(cputime):
    """ps's cputime, [[dd-]hh:]mm:ss.cc"""
    total = 0.0
    for part in re.split("[-:]", cputime):
        total = total * 60 + float(part)
    return total


def films_of(run):
    movers = lines_of(os.path.join(run, "mover.log"))
    films = [Film(os.path.dirname(path), movers) for path in glob.glob(os.path.join(run, "films", "*", "film.log"))]
    # In the order in which they were taken. Not by the files' own times, which do not survive the way home.
    return sorted(films, key=lambda film: film.lines[0][0] if film.lines else 0)


def table(run):
    groups = {}
    for film in films_of(run):
        if len(film.frames) < 2:
            print(f"{film.name}: no frames")
            continue
        start, length = film.longest()
        elsewhere = max(film.waits_elsewhere(), key=lambda wait: wait[1], default=(0, 0))
        others = ", ".join(f"{long} from {at:+d}" for at, long in film.waits(100) if (at, long) != (start, length))
        shown = sum(1 for time, _, _ in film.frames if 0 <= time - film.cause <= UNTIL)
        burnt = " ".join(f"{name} {ms}" for name, ms in sorted(film.burnt().items()))
        print(f"{length:5d} ms from {start:+5d} | {elsewhere[1]:5d} from {elsewhere[0]:+5d}  {film.name:34s} {shown:3d} frames in 1.5 s ({film.how}); the act {film.act()[0]:+d} to {film.act()[1]:+d} in {film.act()[2]} frames; {film.before()} before" + (f"; also {others}" if others else "") + (f"; cpu ms/s: {burnt}" if burnt else ""))
        groups.setdefault(re.sub(r"-\d+(?=-|$)", "", film.name, count=1), []).append((length, elsewhere[1]))
    print()
    print("group: the display's longest standstill in each film | the longest wait of what is not the strip, that begins in the first 0.35 s")
    for name, pairs in groups.items():
        whole, rest = [pair[0] for pair in pairs], [pair[1] for pair in pairs]
        print(f"{name:34s} {' '.join(f'{length:5d}' for length in whole)}   median {sorted(whole)[len(whole) // 2]:5d} | {' '.join(f'{length:5d}' for length in rest)}   median {sorted(rest)[len(rest) // 2]}")
    return 0


def worst(run, count):
    found = []
    for film in films_of(run):
        start, length = film.longest()
        if length >= 150:
            found.append((length, film.cause + start, film.name))
    for length, at, name in sorted(found, reverse=True)[:count]:
        print((at - 300) // 1000, (at + length + 300) // 1000 + 1, name)
    return 0


def arbor_log(run):
    """Arbor's logs: `2026-10-15T01:43:16.654Z LEVEL text`, or whatever begins with such a time."""
    found = []
    for path in sorted(glob.glob(os.path.join(run, "arbor-*.log"))):
        if "stderr" in path:
            continue
        with open(path, encoding="utf-8", errors="replace") as file:
            for line in file:
                match = re.match(r"\[?(\d{4}-\d\d-\d\d[T ]\d\d:\d\d:\d\d[.,]\d+)(Z|[+-]\d\d:?\d\d)?\]?\s*(.*)", line)
                if not match:
                    continue
                zone = (match.group(2) or "Z").replace("Z", "+00:00")
                stamp = datetime.datetime.fromisoformat(match.group(1).replace(",", ".").replace(" ", "T") + zone)
                found.append((round(stamp.timestamp() * 1000), "arbor", [match.group(3)]))
    return found


def story(run, name):
    film = next((film for film in films_of(run) if film.name == name), None)
    if film is None:
        print(f"no film {name}")
        return 1
    rows = [(time, "F", [str(number)] + [str(value) for value in place]) for time, number, place in film.frames]
    rows += [(time, kind, rest) for time, kind, rest in film.lines if kind in "MKB"]
    for file, label in (("mover.log", "mover"), ("pulse.log", "pulse"), ("samples.log", "server")):
        rows += [(time, label, [kind] + rest) for time, kind, rest in lines_of(os.path.join(run, file))]
    rows += arbor_log(run)
    before = None
    for time, kind, rest in sorted(rows, key=lambda row: row[0]):
        if not -400 <= time - film.cause <= 3000:
            continue
        if kind == "F":
            wait = time - before if before is not None else 0
            before = time
            if wait < 40 and rest[3:] and int(rest[3]) <= 256 and int(rest[4]) <= 12:
                continue
            print(f"{time - film.cause:+6d} F {' '.join(rest)}" + (f"   <-- after {wait} ms" if wait >= 40 else ""))
        else:
            print(f"{time - film.cause:+6d} {kind} {' '.join(rest)}")
    return 0


def main(arguments):
    if len(arguments) == 2 and arguments[0] == "table":
        return table(arguments[1])
    if len(arguments) == 2 and arguments[0] == "longest":
        film = Film(arguments[1], lines_of(os.path.join(arguments[1], "..", "..", "mover.log")))
        print(max([film.longest()[1]] + [length for _, length in film.waits_elsewhere()]))
        return 0
    if len(arguments) == 3 and arguments[0] == "worst":
        return worst(arguments[1], int(arguments[2]))
    if len(arguments) == 3 and arguments[0] == "story":
        return story(arguments[1], arguments[2])
    print(__doc__)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
