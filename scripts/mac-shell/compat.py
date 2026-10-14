#!/usr/bin/env python3
"""Compares what Arbor believes with what the window server shows, and prints the compatibility matrix.

For scripts/mac-shell/lib-apps.sh and compat.sh.

  compat.py audit <windows file> [pid…]   the reply of `arborctl state` on stdin, the output of `pointer windows` in the file.
                                          One line per finding: FAIL (wrong), ODD (worth a look) or NOTE (for the record).
                                          The pids are the apps under test: their windows that Arbor does not list are noted.
                                          Exit code 0, 1 when the worst is ODD, 2 when it is FAIL.
  compat.py ids [pid]                     state on stdin: the ids of the windows Arbor arranges (of that process)
  compat.py brief                         state on stdin: the camera, slots, tiles and windows in a few lines, no titles
  compat.py matrix <cells file>           the matrix as a Markdown table, then every cell that is not a plain ✔
                                          (cells: app, step, verdict, picture, note, separated by tabs)
"""

import json
import sys

SYMBOLS = {"ok": "✔", "fail": "✘", "odd": "odd", "na": "–"}


def rect(value):
    """A rectangle is {"x", "y", "width", "height"} since schema 2, and was [[x, y], [width, height]]."""
    if isinstance(value, dict):
        return (value["x"], value["y"], value["width"], value["height"])
    (x, y), (width, height) = value
    return (x, y, width, height)


def words(frame):
    x, y, width, height = (round(number) for number in frame)
    return f"{x},{y} {width}×{height}"


def overlap(a, b):
    """The width and height two rectangles share; either is 0 or less when they are apart."""
    width = min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])
    height = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
    return width, height


def shared_area(a, b):
    width, height = overlap(a, b)
    return width * height if width > 0 and height > 0 else 0


def read_state():
    try:
        return json.load(sys.stdin)["state"]
    except (ValueError, KeyError):
        print("FAIL Arbor did not answer `state`")
        sys.exit(2)


def read_server(path):
    """id pid layer x y w h on|off owner…"""
    windows = {}
    with open(path, encoding="utf-8") as lines:
        for line in lines:
            parts = line.split()
            if len(parts) < 8:
                continue
            try:
                numbers = [float(part) for part in parts[:7]]
            except ValueError:
                continue
            windows[int(numbers[0])] = {
                "pid": int(numbers[1]),
                "layer": int(numbers[2]),
                "frame": tuple(numbers[3:7]),
                "on": parts[7] == "on",
            }
    return windows


def audit(state, server, pids):
    findings = []
    screens = [rect(display["frame"]) for display in state["displays"]]
    slots = {}
    tiled = set()
    for display in state["displays"]:
        for key, value in display["windowFrames"].items():
            slots[int(key)] = rect(value)
        for tile in display["tiles"]:
            tiled.update(tile["windows"])

    def on_screen_share(frame):
        area = frame[2] * frame[3]
        return max(shared_area(frame, screen) for screen in screens) / area if area > 0 else 0

    placed = {}
    for window in state["windows"]:
        if not window["managed"]:
            continue
        name = f"w{window['id']}"
        real = server.get(window["id"])
        if real is None:
            findings.append(f"FAIL {name} is gone from the window server but Arbor still lists it")
            continue
        present = not window["minimized"] and not window["hidden"]
        believed = rect(window["frame"])
        if not present:
            if real["on"]:
                what = "minimized" if window["minimized"] else "hidden"
                findings.append(f"ODD {name} is {what} for Arbor but on screen at {words(real['frame'])}")
            continue
        if max(abs(a - b) for a, b in zip(believed, real["frame"])) > 1.5:
            findings.append(f"FAIL {name} is at {words(real['frame'])} but Arbor believes {words(believed)}")
        share = on_screen_share(real["frame"])
        if window["parked"]:
            if share > 0.02:
                findings.append(f"FAIL {name} is parked but {share:.0%} of it shows, at {words(real['frame'])}")
            continue
        if not real["on"]:
            findings.append(f"ODD {name} is in view for Arbor but the window server does not show it")
        if share < 0.9:
            findings.append(f"FAIL {name} is in view for Arbor but only {share:.0%} of it is on a display: {words(real['frame'])}")
        slot = slots.get(window["id"])
        if slot:
            placed[window["id"]] = real["frame"]
            x, y, width, height = real["frame"]
            beyond = max(slot[0] - x, slot[1] - y, x + width - slot[0] - slot[2], y + height - slot[1] - slot[3])
            if beyond > 4:
                findings.append(
                    f"FAIL {name} sticks {round(beyond)} points out of its slot: window {words(real['frame'])}, slot {words(slot)}"
                )
            elif slot[2] - width > 4 or slot[3] - height > 4:
                # In the middle it looks meant; anywhere else it looks broken.
                off = max(abs(x + width / 2 - slot[0] - slot[2] / 2), abs(y + height / 2 - slot[1] - slot[3] / 2))
                level = "NOTE" if off <= 2 else "ODD"
                findings.append(f"{level} {name} fills {round(width)}×{round(height)} of its slot {words(slot)}")
        elif window["docked"] and window["id"] not in tiled:
            findings.append(f"ODD {name} is docked and not parked, but has neither a slot nor a tile")

    ids = sorted(placed)
    for index, first in enumerate(ids):
        for second in ids[index + 1 :]:
            width, height = overlap(placed[first], placed[second])
            if width > 6 and height > 6:
                findings.append(f"FAIL docked w{first} and w{second} overlap by {round(width)}×{round(height)}")

    for window in state["windows"]:
        floats = window["managed"] and not window["docked"] and not window["parked"]
        real = server.get(window["id"])
        if not floats or window["minimized"] or window["hidden"] or real is None:
            continue
        for other, frame in sorted(placed.items()):
            width, height = overlap(real["frame"], frame)
            if width > 20 and height > 20:
                # In front or behind, half a docked window out of sight is not an arrangement.
                level = "ODD" if width * height > 0.5 * frame[2] * frame[3] else "NOTE"
                findings.append(f"{level} floating w{window['id']} and docked w{other} overlap by {round(width)}×{round(height)}")

    known = {window["id"] for window in state["windows"]}
    for number, real in sorted(server.items()):
        big = real["frame"][2] >= 100 and real["frame"][3] >= 60
        if real["pid"] in pids and real["layer"] == 0 and real["on"] and big and number not in known:
            findings.append(f"NOTE window {number} of pid {real['pid']} shows at {words(real['frame'])} and Arbor does not list it")
    return findings


def brief(state):
    lines = []
    for display in state["displays"]:
        desktop = words(rect(display["desktopFrame"])) if display.get("desktopFrame") else "out of view"
        lines.append(f"camera n{display['camera']}, visible {words(rect(display['visibleFrame']))}, Desktop {desktop}")
        for tile in display["tiles"]:
            inside = " ".join(f"w{window}" for window in tile["windows"]) or "-"
            lines.append(f"  tile n{tile['node']} {tile['kind']} {words(rect(tile['frame']))} holds {inside}")
    slots = {}
    for display in state["displays"]:
        slots.update(display["windowFrames"])
    for window in state["windows"]:
        traits = [name for name in ("docked", "parked", "minimized", "hidden") if window[name]]
        if not window["docked"]:
            traits.insert(0, "floating" if window["managed"] else "not managed")
        if state.get("focused") == window["id"]:
            traits.append("focused")
        slot = slots.get(str(window["id"]))
        where = f", slot {words(rect(slot))}" if slot else ""
        lines.append(f"  w{window['id']} {window.get('bundleID') or 'pid ' + str(window['pid'])} {words(rect(window['frame']))}{where}: {' '.join(traits)}")
    return "\n".join(lines)


def matrix(path):
    apps, steps, cells, rest = [], [], {}, []
    with open(path, encoding="utf-8") as lines:
        for line in lines:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            app, step, verdict = parts[:3]
            picture = parts[3] if len(parts) > 3 else ""
            note = parts[4] if len(parts) > 4 else ""
            if app not in apps:
                apps.append(app)
            if step not in steps:
                steps.append(step)
            cells[(app, step)] = verdict
            if verdict != "ok" and (verdict != "na" or note):
                rest.append((app, step, verdict, picture, note))
    if not apps:
        return "no cells"
    out = ["| step | " + " | ".join(apps) + " |", "|---|" + "---|" * len(apps)]
    for step in steps:
        row = [SYMBOLS.get(cells.get((app, step), ""), " ") for app in apps]
        out.append(f"| {step} | " + " | ".join(row) + " |")
    counts = {verdict: sum(1 for value in cells.values() if value == verdict) for verdict in SYMBOLS}
    out.append("")
    out.append(f"{counts['ok']} ✔, {counts['odd']} odd, {counts['fail']} ✘, {counts['na']} not applicable")
    out.append("")
    for app, step, verdict, picture, note in rest:
        out.append(f"- {SYMBOLS.get(verdict, verdict)} **{app} / {step}** ({picture or 'no picture'}): {note}")
    return "\n".join(out)


def main():
    arguments = sys.argv[1:]
    if not arguments:
        print(__doc__, file=sys.stderr)
        sys.exit(64)
    query, arguments = arguments[0], arguments[1:]
    if query == "audit" and arguments:
        findings = audit(read_state(), read_server(arguments[0]), {int(word) for word in arguments[1:]})
        for finding in findings:
            print(finding)
        if any(finding.startswith("FAIL") for finding in findings):
            sys.exit(2)
        sys.exit(1 if any(finding.startswith("ODD") for finding in findings) else 0)
    elif query == "ids":
        wanted = int(arguments[0]) if arguments else None
        state = read_state()
        print(*[w["id"] for w in state["windows"] if w["managed"] and wanted in (None, w["pid"])])
    elif query == "brief":
        print(brief(read_state()))
    elif query == "matrix" and arguments:
        print(matrix(arguments[0]))
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(64)


if __name__ == "__main__":
    main()
