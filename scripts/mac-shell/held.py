#!/usr/bin/env python3
"""Where does a dragged window stand still while the pointer goes on?

    scripts/mac-shell/held.py <samples.log> [<beginning of a slug>]
    scripts/mac-shell/held.py --self-test

Reads the samples of a playing (sampler.swift's lines, with lib-day.sh's marks) and says of every act that dragged a window, was
performed and began with the press that took it:

- how fast the pointer went on its way, which is not what the script asked for: from the first sample in which it has moved to the first
  in which it is where it ends. pointer.swift rests after the press, and at the end it rests, goes a point aside and comes back. Of a
  drag in a handful of steps this is rough: by a tenth and more either way;
- how far the pointer went and how far the window, from the press to the end of the act. Both rest by then, so this is exact, and what the
  window is short of is what it was held for in all;
- every place at which the window stood, along the way, while the pointer went on.

A sample is all the lines of one moment: the windows, then the pointer, each only if it has changed. A stand is what the samples show and
no more: the window keeps its place along the way while the pointer goes eight points and more, and more than one and a half of its usual
strides from sample to sample. A drag in long steps shows as strides with rests between them, and a window that follows a sample late then stands for
one stride at every step: that is no stand. WHAT IS SHOWN IS LESS THAN WHAT WAS: a hold shows for certain only if it is longer than that by two
strides, so a hold of 31 points shows in steps of two or five and not in steps of twenty, and one of 9 only now and then. What the window is
short of says it in every case. A stand's points are right within two strides. A hosted Mac also hiccups: a short stand in a drag that ends
short of nothing was none of macOS's holding.

Nothing is judged. probe-held-at-the-edges.sh is read with it, and so is any walk, where a drag against an edge ends in macOS's tile.
"""
import math
import sys
from statistics import median

LEAST = 8  # points


def samples(lines):
    """(ms, the lines of that moment, each split into words). What is cut short or damaged is left out."""
    at, group = None, []
    for line in lines:
        word = line.split()
        if len(word) < 3 or not (word[0].isascii() and word[0].isdigit()):
            continue
        if int(word[0]) != at:
            if group:
                yield at, group
            at, group = int(word[0]), []
        group.append(word[1:])
    if group:
        yield at, group


def numbers(words):
    try:
        found = tuple(float(word) for word in words)
    except ValueError:
        return None
    return found if all(math.isfinite(number) for number in found) else None


def drags(lines, beginning=""):
    """Every such act: its number and slug, (ms, the pointer, the window's frame) by sample from the press to the release, and the frame at the end."""
    frames, act, found = {}, None, []
    for at, group in samples(lines):
        for word in group:
            kind = word[0]
            if kind == "W" and len(word) >= 8 and word[3] == "0" and numbers(word[4:8]):
                frames[word[1]] = numbers(word[4:8])
            elif kind == "M" and word[1] == "begin" and len(word) >= 4:
                act = {"number": word[2], "slug": word[3], "pointer": None, "released": False, "track": []}
            elif kind == "B" and act and len(word) >= 4 and numbers(word[2:4]):
                if word[1] == "down":
                    act["pointer"] = numbers(word[2:4])
                elif word[1] == "up" and act["pointer"]:
                    act["released"] = True
            elif kind == "P" and act and act["pointer"] and len(word) >= 3 and numbers(word[1:3]):
                act["pointer"] = numbers(word[1:3])
            elif kind == "M" and word[1] == "end" and act:
                said = dict(pair.split("=", 1) for pair in word[3:] if "=" in pair)
                window = said.get("drags", "").split(",")[0]
                track = [(ms, pointer, seen[window]) for ms, pointer, seen in act["track"] if window in seen]
                # A window that was not there at the press was not taken by it.
                whole = track and len(track) == len(act["track"])
                if act["released"] and said.get("judge") != "no" and act["slug"].startswith(beginning) and whole:
                    found.append({"number": act["number"], "slug": act["slug"], "track": track, "after": frames.get(window, track[-1][2])})
                act = None
        if act and act["pointer"] and not act["released"]:
            act["track"].append((at, act["pointer"], dict(frames)))
    return found


def read(drag):
    """The pointer's speed on its way, and by axis: its way, the window's, and where the window stood."""
    track = drag["track"]
    start, end = track[0][1], track[-1][1]
    # Nowhere, or there and back.
    if end == start:
        return None
    moved = next(index for index, (_, pointer, _) in enumerate(track) if pointer != start)
    there = next(index for index, (_, pointer, _) in enumerate(track) if pointer == end)
    way = ((track[there][1][0] - track[moved][1][0]) ** 2 + (track[there][1][1] - track[moved][1][1]) ** 2) ** 0.5
    result = {"speed": way / ((track[there][0] - track[moved][0]) / 1000) if track[there][0] > track[moved][0] else None, "axes": []}
    for axis, name in ((0, "across"), (1, "down")):
        pointer = end[axis] - start[axis]
        if abs(pointer) < 20:
            continue
        sign = 1 if pointer > 0 else -1
        gone = [sign * (sample[1][axis] - start[axis]) for sample in track[: there + 1]]
        strides = [b - a for a, b in zip(gone, gone[1:]) if b != a]
        stride = median(strides) if strides else 0
        # Where the window shows a new place.
        new = [index for index in range(there + 1) if index == 0 or track[index][2][axis] != track[index - 1][2][axis]]
        stands = []
        for place, first in enumerate(new):
            let_go = place + 1 < len(new)
            last = new[place + 1] - 1 if let_go else there
            if gone[last] - gone[first] >= LEAST and gone[last] - gone[first] > 1.5 * stride:
                stands.append({"at": track[first][2][axis], "far": track[first][2][axis] + track[first][2][axis + 2], "points": gone[last] - gone[first], "ms": track[last][0] - track[first][0], "let go": let_go})
        result["axes"].append({"name": name, "pointer": pointer, "window": drag["after"][axis] - track[0][2][axis], "stands": stands})
    return result


def report(lines, beginning=""):
    out = []
    for drag in drags(lines, beginning):
        found = read(drag)
        if not found:
            continue
        speed = "in one stride" if found["speed"] is None else f"at {found['speed']:.0f} points a second"
        out.append(f"{drag['number']} {drag['slug']}: the pointer went {speed}")
        for axis in found["axes"]:
            short = abs(axis["pointer"]) - (axis["window"] if axis["pointer"] > 0 else -axis["window"])
            out.append(f"   {axis['name']}: the pointer {axis['pointer']:+.0f}, the window {axis['window']:+.0f}: " + (f"short by {short:.0f}" if short >= 0 else f"further by {-short:.0f}"))
            for stand in axis["stands"]:
                where = f"x = {stand['at']:g} (right edge {stand['far']:g})" if axis["name"] == "across" else f"y = {stand['at']:g} (lower edge {stand['far']:g})"
                out.append(
                    f"      stood at {where} for {stand['ms']} ms while the pointer went {stand['points']:.0f} points"
                    + ("" if stand["let go"] else "; it did not let go")
                )
    return out


def self_test():
    def playing(way=(120, 0), step=2, every=40, holds=(), wall=None, late=0, hz=38.6, ends="drags=7 front=7", after=None, hiccup=None, deaf=None):
        """A drag as pointer.swift makes it and sampler.swift sees it. The window 7 is at 100,50 300×200, the press at 150,60.

        `holds`: (where the window's x or y stands, for how many points of the pointer's way), along the longer axis. `wall`: beyond that place never.
        `late`: the window follows so many ms after the pointer. `hiccup`: (from ms, to ms) in which the window does not follow, and then does. `deaf`: (from ms, to ms) without a sample."""
        axis = 0 if abs(way[0]) >= abs(way[1]) else 1
        length = (way[0] ** 2 + way[1] ** 2) ** 0.5
        count = max(1, round(length / step))
        # The pointer in time: the press, a rest, the glide, a rest, a point aside, back, the hold, the release.
        path, at = [(0, (150.0, 60.0))], 150
        for index in range(1, count + 1):
            path.append((at, (float(round(150 + way[0] * index / count)), float(round(60 + way[1] * index / count)))))
            at += every
        end = path[-1][1]
        path += [(at + 150, (end[0] + 1, end[1])), (at + 200, end)]
        release = at + 250 + 500

        def pointer(ms):
            return [place for when, place in path if when <= ms][-1]

        def window(ms):
            if hiccup and hiccup[0] <= ms < hiccup[1]:
                ms = hiccup[0]
            place = pointer(max(ms - late, 0))
            frame = [100 + place[0] - 150, 50 + place[1] - 60]
            sign = 1 if way[axis] > 0 else -1
            lost = 0
            for where, points in holds:
                beyond = sign * (frame[axis] - lost * sign - where)
                if beyond > 0:
                    lost += min(beyond, points)
            frame[axis] -= sign * lost
            if wall is not None and sign * (frame[axis] - wall) > 0:
                frame[axis] = wall
            return frame

        lines = ["1000 W 7 1 0 100 50 300 200 TextEdit", "1000 W 8 1 0 900 50 300 200 Notes", "1000 P 150 60", "1010 M begin 3 pull", "1020 B down 150 60"]
        ms, seen, shown = 0.0, [100, 50], (150.0, 60.0)
        while ms < release:
            now = 1020 + round(ms)
            frame = window(ms)
            if deaf and deaf[0] <= ms < deaf[1]:
                ms += 1000 / hz
                continue
            # The sampler writes what has changed: the windows, then the pointer, under one moment.
            if frame != seen:
                lines.append(f"{now} W 7 1 0 {frame[0]:g} {frame[1]:g} 300 200 TextEdit")
            if pointer(ms) != shown:
                lines.append(f"{now} P {pointer(ms)[0]:g} {pointer(ms)[1]:g}")
            seen, shown, ms = frame, pointer(ms), ms + 1000 / hz
        lines.append(f"{1020 + release} B up {end[0]:g} {end[1]:g}")
        if after:
            lines += [f"{1020 + release + 50} W 7 1 0 {after[0]} {after[1]} 300 200 TextEdit", f"{1020 + release + 60} P 999 999"]
        lines.append(f"{1020 + release + 900} M end 3 act=drag {ends}")
        return lines

    failed = []

    def check(name, got, wanted):
        if got != wanted:
            failed.append(f"✘ {name}: {got!r}, wanted {wanted!r}")

    def near(name, got, wanted, within):
        if got is None or abs(got - wanted) > within:
            failed.append(f"✘ {name}: {got!r}, wanted {wanted!r} within {within}")

    def stands(lines, axis=0):
        """Of the first axis that is spoken of, or of another."""
        return [(stand["at"], stand["let go"]) for drag in drags(lines) for stand in read(drag)["axes"][axis]["stands"]]

    def points(lines):
        return [stand["points"] for drag in drags(lines) for stand in read(drag)["axes"][0]["stands"]]

    def ways(lines):
        return [(axis["name"], axis["pointer"], axis["window"]) for axis in read(drags(lines)[0])["axes"]]

    def speed(lines):
        return read(drags(lines)[0])["speed"]

    check("in the open the window follows and stands nowhere", stands(playing()), [])
    check("nor if it follows a sample late", stands(playing(late=30)), [])
    check("nor in long steps, a sample late: it stands for a stride at every step, and at the rest after the press", stands(playing(way=(380, 0), step=20, every=65, late=30)), [])
    long = playing(way=(380, 0), step=20, every=65, late=30)
    busy = [extra for line in long for extra in ([line, f"{int(line.split()[0]) + 7} W 8 1 0 {900 + len(line) % 2} 50 300 200 Notes"] if " P " in line else [line])]
    check("nor if other windows stir between the strides", stands(busy), [])
    check("nor if the hand trembles once", stands(long[:5] + ["1100 P 151 60"] + long[5:]), [])
    check("nor if a step is no whole number of points, so that no two strides are alike", stands(playing(way=(789, 0), step=26.3, every=65, late=30)), [])
    check("nor in two steps, after which the pointer goes a point aside", stands(playing(way=(40, 0), step=20, every=65, late=30)), [])
    check("held and let go", stands(playing(holds=[(140, 30)])), [(140.0, True)])
    check("for so many points, within a stride", points(playing(holds=[(140, 30)])), [30.0])
    check("eight points are a stand", points(playing(holds=[(140, 8)])), [8.0])
    check("seven are none", points(playing(step=1, every=20, holds=[(140, 7)])), [])
    check("six are none", (points(playing(holds=[(140, 6)])), ways(playing(holds=[(140, 6)]))[0][2]), ([], 114.0))
    check("one long stride, because the sampler was late, hides no stand", stands(playing(holds=[(140, 12)], deaf=(300, 700))), [(140.0, True)])
    check("what it is short of is exact", ways(playing(holds=[(140, 30)])), [("across", 120.0, 90.0)])
    check("twice", stands(playing(way=(200, 0), holds=[(120, 30), (160, 20)])), [(120.0, True), (160.0, True)])
    check("in long steps a hold of a step and a half shows", stands(playing(way=(380, 0), step=20, every=65, late=30, holds=[(200, 31)])), [(200.0, True)])
    check("but not for certain: 31 points in the probe's steps of twenty", (stands(playing(way=(380, 0), step=20, every=65, holds=[(165, 31)])), ways(playing(way=(380, 0), step=20, every=65, holds=[(165, 31)]))[0][2]), ([], 349.0))
    check("one shorter than a step does not", stands(playing(way=(380, 0), step=67, every=65, holds=[(200, 31)])), [])
    check("and the window is short of it all the same", ways(playing(way=(380, 0), step=67, every=65, holds=[(200, 31)])), [("across", 380.0, 349.0)])
    check("a wall", stands(playing(wall=140)), [(140.0, False)])
    near("a wall holds while the pointer goes on, not while it rests", [stand["ms"] for stand in read(drags(playing(wall=140))[0])["axes"][0]["stands"]][0], 40 * 40, 90)
    check("where a fast drag ends in the open nothing holds", stands(playing(way=(240, 0), step=2, every=8, late=20)), [])
    check("a window that never comes away", stands(playing(wall=100)), [(100.0, False)])
    check("a hiccup is a stand, and the window is short of nothing", (len(stands(playing(hiccup=(1000, 1400)))), ways(playing(hiccup=(1000, 1400)))[0][2]), (1, 120.0))
    check("to the left", (stands(playing(way=(-120, 0), holds=[(60, 30)])), ways(playing(way=(-120, 0), holds=[(60, 30)]))), ([(60.0, True)], [("across", -120.0, -90.0)]))
    check("downwards", (stands(playing(way=(0, 120), holds=[(90, 30)])), ways(playing(way=(0, 120), holds=[(90, 30)]))), ([(90.0, True)], [("down", 120.0, 90.0)]))
    check("upwards", ways(playing(way=(0, -44), wall=16)), [("down", -44.0, -34.0)])
    check("a little aslant is straight", ways(playing(way=(120, 18))), [("across", 120.0, 120.0)])
    check("a little more is aslant", ways(playing(way=(120, 25))), [("across", 120.0, 120.0), ("down", 25.0, 25.0)])
    check("aslant it stands along one way while it goes on along the other", (stands(playing(way=(120, 60), holds=[(140, 30)])), stands(playing(way=(120, 60), holds=[(140, 30)]), axis=1)), ([(140.0, True)], []))
    check("aslant, each axis by itself", ways(playing(way=(120, 60), holds=[(140, 30)])), [("across", 120.0, 90.0), ("down", 60.0, 60.0)])
    for every, true in ((40, 50), (10, 200), (85, 23.5)):
        near(f"the speed is that of the way, without the rests at both ends: {true}", speed(playing(way=(380, 0), every=every)), true, true * 0.04)
    near("so in long steps", speed(playing(way=(380, 0), step=20, every=14)), 20 / 0.014, 20 / 0.014 * 0.12)
    near("and aslant it is along the way", speed(playing(way=(300, 400), every=10)), 200, 8)
    near("a hold does not slow the pointer", speed(playing(way=(380, 0), holds=[(140, 30)])), 50, 2)
    check("where the window goes after the release counts, where the pointer goes does not", ways(playing(holds=[(140, 30)], after=(200, 50))), [("across", 120.0, 100.0)])
    check("an act that was not performed is left out", drags(playing(ends="drags=7 judge=no performed=no")), [])
    check("an act that drags nothing is left out", drags(playing(ends="front=7")), [])
    check("of several windows the first is the one in hand", ways(playing(ends="drags=7,8")), [("across", 120.0, 120.0)])
    check("one that was never let go is left out", drags([line for line in playing() if " B up " not in line]), [])
    check("by the beginning of a slug", (len(drags(playing(), "pu")), len(drags(playing(), "ull"))), (1, 0))
    held = playing(holds=[(140, 30)])
    # After the pointer's line of a moment in which the window stands.
    middle = next(index for index, line in enumerate(held) if " W 7 1 0 140 " in line) + 4
    moment = held[middle - 1].split()[0]
    check("another window's samples change nothing", stands(held[:middle] + [f"{moment} W 8 1 0 901 50 300 200 Notes"] + held[middle:]), [(140.0, True)])
    check("what is drawn above the windows is none", stands(held[:middle] + [f"{moment} W 7 1 25 0 0 10 10 TextEdit"] + held[middle:]), [(140.0, True)])
    check("a window that comes after the press was not taken by it", drags([line for line in held if not line.startswith("1000 W 7 ") and not line.startswith("1020 W 7 ")]), [])
    check("what is cut short or damaged is passed over", stands(held[:middle] + [f"{moment} P 9999", f"{moment} W 7 1 0 1 2 3 - x", f"{moment} W 7 1 0 1 2", f"{moment} B down", f"{moment} B down 1 x", "x", "x y z", ""] + held[middle:]), [(140.0, True)])
    check("so at the end", report(held[:-2] + [f"{held[-3].split()[0]} P 9999"] + held[-2:]), report(held))
    check("a release left over from before is none of this act's", stands(held[:4] + ["1015 B up 150 60"] + held[4:]), [(140.0, True)])
    check("a click drags nothing", report(["1000 W 7 1 0 100 50 300 200 TextEdit", "1010 M begin 3 pull", "1020 B down 150 60", "1046 P 150 60", "1072 B up 150 60", "1900 M end 3 drags=7"]), [])
    check("nor one within a moment", report(["1000 W 7 1 0 100 50 300 200 TextEdit", "1010 M begin 3 pull", "1020 B down 150 60", "1020 B up 150 60", "1900 M end 3 drags=7"]), [])
    check("nothing comes of nothing", report([]), [])
    check(
        "in words",
        report(playing(way=(0, 120), wall=90)),
        ["3 pull: the pointer went at 50 points a second", "   down: the pointer +120, the window +40: short by 80", "      stood at y = 90 (lower edge 290) for 1580 ms while the pointer went 80 points; it did not let go"],
    )
    check(
        "across",
        report(playing(holds=[(140, 30)])),
        ["3 pull: the pointer went at 50 points a second", "   across: the pointer +120, the window +90: short by 30", "      stood at x = 140 (right edge 440) for 595 ms while the pointer went 30 points"],
    )
    check("short of nothing", report(playing())[1], "   across: the pointer +120, the window +120: short by 0")
    check("a window that goes the other way is short of both ways", report(playing(after=(50, 50)))[1], "   across: the pointer +120, the window -50: short by 170")
    check("there and back is nowhere", report([line.replace("B up 270 60", "B up 150 60") for line in playing()[:-2]] + ["9000 P 150 60", "9010 B up 150 60", "9900 M end 3 drags=7"]), [])
    check("what is no number is no frame", stands(held[:middle] + [f"{moment} W 7 1 0 nan 50 300 200 x", "² W 7"] + held[middle:]), [(140.0, True)])
    check("a window that macOS tiles goes further than the pointer", report(playing(after=(400, 50)))[1], "   across: the pointer +120, the window +300: further by 180")
    check("to the left in words", report(playing(way=(-120, 0), holds=[(60, 30)]))[1], "   across: the pointer -120, the window -90: short by 30")
    check(
        "nor have two in a moment that another moment's line has parted",
        report(["1000 W 7 1 0 100 50 300 200 TextEdit", "1010 M begin 3 pull", "1020 B down 150 60", "1100 P 160 60", "1101 A 1 x", "1100 P 190 60", "1100 W 7 1 0 140 50 300 200 TextEdit", "1500 B up 190 60", "1900 M end 3 drags=7"])[0],
        "3 pull: the pointer went in one stride",
    )
    check("one stride has no speed", report(playing(way=(30, 0), step=30))[0], "3 pull: the pointer went in one stride")
    for line in failed:
        print(line)
    print(f"held.py: {'FAILED' if failed else 'all situations hold'}")
    return 1 if failed else 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        sys.exit(self_test())
    if not 2 <= len(sys.argv) <= 3 or sys.argv[1].startswith("-"):
        sys.exit(__doc__.strip())
    try:
        with open(sys.argv[1], encoding="utf-8", errors="replace") as log:
            said = report(log, *sys.argv[2:])
    except OSError as error:
        sys.exit(f"held.py: {error}")
    if said:
        print("\n".join(said))
