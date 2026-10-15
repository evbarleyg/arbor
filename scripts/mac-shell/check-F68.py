#!/usr/bin/env python3
"""Reads what scripts/mac-shell/check-F68.sh brings back: traces, and the `appSizes` of a state.json.

  check-F68.py roads <trace>                     every frame Arbor asked for and what the window took, command by command; exit code 1 if a
                                                 window went out of its way: more than one change of place, or a side that went both ways
  check-F68.py question <trace> <id> <w|h> <n>   the request that asked window <id> for a width (height) of <n>: where it stood, what it took,
                                                 how long that lasted; exit code 1 unless there is exactly one, put where the window stood,
                                                 that asked for no more than the window had on either side
  check-F68.py kept <state.json> <bundle id>     what is kept of the app, as WxH; `nothing` if nothing is
  check-F68.py keep <state.json> <bundle id> <width>   writes another width into what is kept: a store that is wrong
"""

import json
import sys

# As in ArborTesting/Roads.swift.
TOLERANCE = 6


def lines(path):
    with open(path, encoding="utf-8") as handle:
        rows = [json.loads(line) for line in handle if line.strip()]
    return rows[0], rows[1:]


def moves(path):
    """[(command, id, before, asked, took, seconds)] in order. `before` is where the window was last known to be."""
    header, rows = lines(path)
    at = {window["id"]: window["frame"] for window in header.get("windows", [])}
    command, found = "(before any command)", []
    for row in rows:
        if "command" in row:
            command = row["command"]
        if row.get("event") in ("appeared", "changed") and "frame" in row.get("window", {}):
            at[row["window"]["id"]] = row["window"]["frame"]
        if row.get("call") == "setFrame" and row.get("result"):
            found.append((command, row["id"], at.get(row["id"]), row["frame"], row["result"], row.get("took", 0)))
            at[row["id"]] = row["result"]
    return found


def brief(frame):
    return "?" if frame is None else "%g,%g %g×%g" % tuple(frame)


def detour(road):
    places = sum(1 for a, b in zip(road, road[1:]) if a[:2] != b[:2])
    if places > 1:
        return "changed place %d times" % places
    for index, name in ((2, "width"), (3, "height")):
        steps = [b[index] - a[index] for a, b in zip(road, road[1:])]
        if any(step > TOLERANCE for step in steps) and any(step < -TOLERANCE for step in steps):
            return "its %s went both ways" % name
    return None


def shows(frame, displays):
    """Whether a display shows more of it than the sliver that parking leaves."""
    for x, y, width, height in displays:
        if min(frame[0] + frame[2], x + width) - max(frame[0], x) > 2 and min(frame[1] + frame[3], y + height) - max(frame[1], y) > 2:
            return True
    return False


def roads(path):
    found, order, faults = {}, [], 0
    displays = [display["frame"] for display in lines(path)[0]["displays"]]
    for command, window, before, asked, took, seconds in moves(path):
        key = (command, window)
        if key not in found:
            found[key] = [before] if before else []
            order.append(key)
        # What nobody can see is no part of the road: a window asked for a size in its corner is still in its corner.
        if before is None or shows(before, displays) or shows(took, displays):
            found[key].append(took)
        print("  %-28s w%s %s asked %s took %s%s" % (command, window, brief(before), brief(asked), brief(took), " in %d ms" % (seconds * 1000) if seconds else ""))
    for key in order:
        what = detour(found[key])
        if what:
            faults += 1
            print("  OUT OF ITS WAY: %s, w%s: %s: %s" % (key[0], key[1], what, " → ".join(brief(frame) for frame in found[key])))
    return 1 if faults else 0


def question(path, window, side, size):
    index = 2 if side == "w" else 3
    put = [move for move in moves(path) if move[1] == window and move[3][index] == size]
    for _, _, before, asked, took, seconds in put:
        print("  w%s stood at %s, was asked for %s and took %s in %d ms" % (window, brief(before), brief(asked), brief(took), seconds * 1000))
    if len(put) != 1:
        print("  asked %d times, not once" % len(put))
        return 1
    _, _, before, asked, _, _ = put[0]
    if before is None or asked[:2] != before[:2]:
        print("  not where it stood")
        return 1
    if asked[2] > before[2] or asked[3] > before[3]:
        print("  asked for more than it had")
        return 1
    return 0


def main(arguments):
    if len(arguments) == 2 and arguments[0] == "roads":
        return roads(arguments[1])
    if len(arguments) == 5 and arguments[0] == "question" and arguments[3] in ("w", "h"):
        return question(arguments[1], int(arguments[2]), arguments[3], float(arguments[4]))
    if len(arguments) in (3, 4) and arguments[0] in ("kept", "keep"):
        with open(arguments[1], encoding="utf-8") as handle:
            state = json.load(handle)
        entry = state.get("appSizes", {}).get(arguments[2])
        if arguments[0] == "kept" and len(arguments) == 3:
            print("%gx%g" % (entry["width"], entry["height"]) if entry else "nothing")
            return 0
        if arguments[0] == "keep" and len(arguments) == 4 and entry:
            entry["width"] = float(arguments[3])
            with open(arguments[1], "w", encoding="utf-8") as handle:
                json.dump(state, handle)
            return 0
    print(__doc__)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
