#!/usr/bin/env python3
"""For how long did the display stand still? Reads what framewatch.swift wrote down while a script played (or the films of a camera that writes the same
grammar) and says, scene by scene.

With pulse.swift's strip on the display every frame differs from the one before, so a wait between two frames is a display that showed one
picture for that long, whatever else was or was not meant to move.

  standstill.py table <run folder>             a line for each scene: the longest wait that begins between the cause and 1.5 s after it | the same for what is
                                               not the strip, every wait of 100 ms and more, the longest wait before the cause (nothing is being done then), what
                                               the processes burnt meanwhile; then a line for each group of scenes
  standstill.py calm <run folder> <group> <ms> whether in every scene of that group (`back` is back-1, back-2, …) the display never stood still for that long. Fails,
                                               too, where the instrument was blind: fewer than 40 frames in the second before the cause
  standstill.py each <run folder> <group>      the longest standstill of each scene of that group, in ms, on one line: to print beside another group's
  standstill.py waits <run folder> <ms>        every wait of that length in frames.log, inside a scene or not, with the mark that came last before it
  standstill.py longest <film folder>          that film's longest wait, of the display or of what is not the strip, in ms: for a script that decides what to keep
  standstill.py worst <run folder> <n>         `<from> <to> <scene>` in seconds since 1970, outwards to whole seconds, for the n longest waits
  standstill.py story <run folder> <scene>     everything that is known about that scene on one clock, ms after the cause: frames, marks, the mover's steps,
                                               the pulse's own trouble, the sampler's lines, Arbor's log
  standstill.py --self-test

A run folder holds frames.log (framewatch.swift: a scene goes from one mark `scene <name>` to the next; `scene` alone ends one) or films/<name>/film.log.
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
    def __init__(self, folder, movers=(), name=None, lines=None, closed=None):
        self.folder = folder
        self.name = name or os.path.basename(os.path.normpath(folder))
        self.lines = lines_of(os.path.join(folder, "film.log")) if lines is None else lines
        # A line cut short, by whoever reads while it is being written, is no frame.
        self.frames = sorted((time, int(rest[0]), [int(word) for word in rest[1:5]]) for time, kind, rest in self.lines if kind == "F" and len(rest) >= 5)
        self.marks = [(time, " ".join(rest)) for time, kind, rest in self.lines if kind == "M"]
        # When the scene was closed: a display that still stands still then has stood still until then at least.
        self.closed = closed
        times = [time for time, _, _ in self.lines]
        begin, end = (min(times), max(times)) if times else (0, 0)
        action = next((time for time, mark in self.marks if mark == "action"), begin)
        keys = [time for time, kind, rest in self.lines if kind == "K" and rest[:1] == ["down"] and time >= action]
        goes = [time for time, kind, rest in movers if rest[:1] == ["go"] and action <= time <= (closed or end)]
        goes += [time for time, mark in self.marks if mark == "go"]
        clicks = [time for time, kind, rest in self.lines if kind == "B" and rest[:1] == ["up"] and time >= action]
        self.cause, self.how = (keys[-1], "key") if keys else (goes[0], "go") if goes else (clicks[-1], "click") if clicks else (action, "about")
        ups = [time for time, kind, rest in self.lines if kind == "K" and rest[:1] == ["up"] and time >= self.cause]
        # For how long the key was down, as whoever listens where the keyboard comes in was told. The tool that presses it lets go at once.
        self.held = ups[0] - self.cause if keys and ups else None

    def times(self):
        times = [time for time, _, _ in self.frames]
        return times + [self.closed] if times and self.closed and self.closed > times[-1] else times

    def waits(self, least=0):
        """[(ms after the cause at which the wait begins, its length)]"""
        times = self.times()
        return [(a - self.cause, b - a) for a, b in zip(times, times[1:]) if SINCE <= a - self.cause <= UNTIL and b - a >= least]

    def waits_elsewhere(self):
        """The same for what is not the pulse's strip, while a motion should be playing (waits that begin up to 0.35 s after the cause): a display that goes on while the
        stage stands still, and a film without the strip, in which the rest after the motion is no standstill."""
        times = [time for time, _, place in self.frames if not inside_the_strip(place)]
        return [(a - self.cause, b - a) for a, b in zip(times, times[1:]) if 0 <= a - self.cause <= 350]

    def sight(self):
        """Frames in the second before the cause. With the strip up about sixty; far fewer, and whoever reads this film is blind."""
        return sum(1 for time, _, _ in self.frames if -1000 + SINCE <= time - self.cause <= SINCE)

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


def witnesses(run):
    """What saw the display's beat or the window server's answers come late, and films nothing: [(when it ended, how long, who)]"""
    found = [(time, int(rest[1]), "link") for time, kind, rest in lines_of(os.path.join(run, "pulse.log")) if kind == "U" and rest[:1] == ["link"] and len(rest) > 1]
    found += [(time, int(rest[0]), "list") for time, kind, rest in lines_of(os.path.join(run, "samples.log")) if kind == "L" and rest]
    return found


def late(film, seen, who):
    """The longest such wait that ends between the cause and 2.5 s after it."""
    return max((length for time, length, whose in seen if whose == who and 0 <= time - film.cause <= UNTIL + 1000), default=0)


def films_of(run):
    movers = lines_of(os.path.join(run, "mover.log"))
    films = [Film(os.path.dirname(path), movers) for path in glob.glob(os.path.join(run, "films", "*", "film.log"))]
    name, lines = None, []
    for line in lines_of(os.path.join(run, "frames.log")) + [(0, "M", ["scene", ""])]:
        if line[1] == "M" and line[2][:1] == ["scene"]:
            if name:
                films.append(Film(run, movers, name, lines, closed=line[0] or None))
            name, lines = " ".join(line[2][1:]), []
        else:
            lines.append(line)
    # In the order in which they were taken. Not by the files' own times, which do not survive the way home.
    return sorted(films, key=lambda film: film.lines[0][0] if film.lines else 0)


def table(run):
    groups, seen = {}, witnesses(run)
    print("the display's longest standstill as filmed | the same for what is not the strip || and as told by who films nothing: the display's beat, the window list, the key held")
    for film in films_of(run):
        others = f"beat {late(film, seen, 'link'):4d}  list {late(film, seen, 'list'):4d}  key " + (f"{film.held:4d}" if film.held is not None else "   -")
        if len(film.frames) < 2:
            print(f"   not filmed                            || {others}  {film.name}")
            groups.setdefault(group_of(film.name), []).append((None, late(film, seen, "link"), film.held))
            continue
        start, length = film.longest()
        elsewhere = max(film.waits_elsewhere(), key=lambda wait: wait[1], default=(0, 0))
        more = ", ".join(f"{long} from {at:+d}" for at, long in film.waits(100) if (at, long) != (start, length))
        burnt = " ".join(f"{name} {ms}" for name, ms in sorted(film.burnt().items()))
        print(f"{length:5d} ms from {start:+5d} | {elsewhere[1]:5d} from {elsewhere[0]:+5d} || {others}  {film.name:36s} ({film.how}); {film.before()} before"
              + (f"; also {more}" if more else "") + (f"; cpu ms/s: {burnt}" if burnt else ""))
        groups.setdefault(group_of(film.name), []).append((length, late(film, seen, "link"), film.held))
    print()
    print("group: filmed | the display's beat | the key held")
    for name, rows in groups.items():
        print(f"{name:36s} " + " | ".join(" ".join("    -" if row[column] is None else f"{row[column]:5d}" for row in rows) for column in range(3)))
    return 0


def group_of(name):
    return re.sub(r"-\d+(?=-|$)", "", name, count=1)


def calm(run, group, limit):
    films = [film for film in films_of(run) if group_of(film.name) == group]
    if not films:
        print(f"no scene of the group {group}")
        return 1
    bad = 0
    for film in films:
        start, length = film.longest()
        if film.sight() < 40:
            print(f"{film.name}: blind: {film.sight()} frames in the second before the cause, where the strip alone makes about sixty")
            bad += 1
        elif length >= limit:
            print(f"{film.name}: the display showed one picture for {length} ms, from {start:+d} ms after the cause")
            bad += 1
    if not bad:
        print(f"{group}: at most {max(film.longest()[1] for film in films)} ms in {len(films)} scenes")
    return 1 if bad else 0


def waits(run, least):
    """Every wait of that length in frames.log, with the mark that came last before it."""
    before, mark, found = None, "", 0
    for time, kind, rest in lines_of(os.path.join(run, "frames.log")):
        if kind == "M":
            mark = (time, " ".join(rest))
        elif kind == "F":
            if before is not None and time - before >= least:
                found += 1
                stamp = datetime.datetime.fromtimestamp(before / 1000, datetime.timezone.utc).strftime("%H:%M:%S.%f")[:-3]
                print(f"{stamp}  {time - before:5d} ms" + (f", {before - mark[0]} ms after the mark `{mark[1]}`" if mark else ""))
            before = time
    print(f"{found} in all")
    return 0


def self_test():
    import tempfile

    def scene(name, base, holes=(), rate=17, strip=True):
        lines = [f"{base - 1500} M scene {name}", f"{base - 400} M action", f"{base} K down", f"{base + 60} K up"]
        number = 0
        for time in range(-1400, 2500, rate):
            if any(a < time < b for a, b in holes):
                continue
            number += 1
            lines.append(f"{base + time} F {number} " + ("440 31 256 12" if strip else "0 40 1024 700"))
        return lines

    with tempfile.TemporaryDirectory() as run:
        lines = scene("good-1", 1_000_000) + scene("good-2", 1_010_000, [(-900, -700)]) + scene("bad-1", 1_020_000, [(480, 860)])
        lines += scene("late-1", 1_030_000, [(1700, 2300)]) + scene("blind-1", 1_040_000, rate=200)
        lines += scene("outlasts-1", 1_050_000, [(90, 9000)]) + [f"{1_050_000 + 2600} M scene"]
        with open(os.path.join(run, "frames.log"), "w", encoding="utf-8") as file:
            file.write("\n".join(sorted(lines, key=lambda line: int(line.split()[0]))) + "\n")
        films = {film.name: film for film in films_of(run)}
        failed = []
        for what, holds in [
            ("six scenes are read", len(films) == 6),
            ("a standstill that outlasts its scene lasts until the scene is closed at least", films["outlasts-1"].longest()[1] >= 2400),
            ("calm fails what outlasts its scene", calm(run, "outlasts", 300) == 1),
            ("a steady display stands still for a frame at most", films["good-1"].longest()[1] <= 17),
            ("a wait before the cause is no standstill of the scene", films["good-2"].longest()[1] <= 17 and films["good-2"].before() >= 200),
            ("a wait in mid-motion is found, with where it begins", films["bad-1"].longest()[1] >= 380 and 450 <= films["bad-1"].longest()[0] <= 490),
            ("a wait that begins over 1.5 s after the cause is not the scene's", films["late-1"].longest()[1] <= 17),
            ("calm passes the good", calm(run, "good", 150) == 0),
            ("calm fails the bad", calm(run, "bad", 150) == 1),
            ("calm fails the blind", calm(run, "blind", 150) == 1),
            ("calm fails a group nobody played", calm(run, "nothing", 150) == 1),
        ]:
            if not holds:
                failed.append(what)
    for what in failed:
        print(f"✘ {what}")
    print("standstill.py: " + (f"{len(failed)} of its own checks failed" if failed else "its own checks hold"))
    return 1 if failed else 0


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
    if arguments == ["--self-test"]:
        return self_test()
    if len(arguments) == 4 and arguments[0] == "calm":
        return calm(arguments[1], arguments[2], int(arguments[3]))
    if len(arguments) == 3 and arguments[0] == "each":
        print(" ".join(str(film.longest()[1]) for film in films_of(arguments[1]) if group_of(film.name) == arguments[2] and len(film.frames) > 1) or "-")
        return 0
    if len(arguments) == 3 and arguments[0] == "waits":
        return waits(arguments[1], int(arguments[2]))
    if len(arguments) == 3 and arguments[0] == "worst":
        return worst(arguments[1], int(arguments[2]))
    if len(arguments) == 3 and arguments[0] == "story":
        return story(arguments[1], arguments[2])
    print(__doc__)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
