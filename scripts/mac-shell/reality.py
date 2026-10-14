#!/usr/bin/env python3
"""Writes down what Arbor believes, what the window server shows and what crossed the seam, in a form two worlds can share.

For scripts/mac-shell/reality.sh, which runs unchanged on a hosted Mac and in a rehearsal on Linux; scripts/reality-diff.py compares
what the two runs left. Nothing here may depend on the world it runs in: windows are called W1, W2… in the order they opened,
processes by the names the script gives them, and there are no process ids, node ids, titles or times. Numbers are whole points.

  reality.py look <folder> <names file> <name=pid…>
      The folder holds what the script has just asked: `state` (the reply of `arborctl state`, empty when Arbor is not running),
      `windows` and `on-screen` (`pointer windows`, with and without --on-screen) and `keyboard` (`pointer keyboard`).
      Prints one line of JSON: {"belief": …, "truth": …}. The names file holds `<window id> <name>` lines; a window of one of the
      processes that has no name yet gets the next one, and the file is rewritten.
  reality.py line <journey> <step> <number> <settled: yes|no> <look file> <names file> <trace file> <name=pid…>
      Prints the observation: the look, and under `reports` and `replies` what the trace holds between the last two marks
      (`trace note` lines that begin with "reality: "), or after the last one once the trace has ended.

belief    running, says (the reply's own words), focused, camera and tree (as in docs/LAYOUTS.md, with windows for apps), back, forward,
          desktop, tiles, floating, and per window its status (docked or floating, then parked, tile, minimized, hidden…), its frame
          and its slot
truth     per window its frame and whether it is on screen, the order of those on screen from the front, which process is in
          front, which window keys go to, how many of Arbor's own windows are on screen at each level, and how many of everybody else's
          by owner (`furniture`: on a hosted Mac that is macOS itself)
reports   events as kind:Wn[:user|arbor][+minimized…], calls as setFrame:Wn asked→took, focus:Wn, raise:Wn…, overlay actions, and commands
          that did not come from the script. In the order they were recorded; nothing is collapsed. Left out: reads, timers, the
          raw lines only a Mac has, and whatever the script's own questions (`state`) set off
replies   what Arbor answered to each command that is not a question
"""

import json
import re
import sys

MARK = "reality: "
# What the script asks after every step. A rehearsal does not even write these down, so neither world may count them.
QUESTIONS = {"state", "status", "ascii", "layout", "stats", "doctor", "version", "bindings", "rules", "spaces", "displays"}
# Calls that only ask.
READS = {"allWindows", "displays", "focusedWindow", "cursorLocation", "isMouseButtonDown"}
TRAITS = ("parked", "minimized", "hidden", "fullScreen", "pinned", "summoned", "stashed")
FLAGS = ("minimized", "hidden", "offSpace", "fullScreen")


def fail(message):
    print(f"reality.py: {message}", file=sys.stderr)
    sys.exit(2)


def whole(numbers):
    return [round(number) for number in numbers]


def rect(value):
    """A CGRect in `state` is [[x, y], [width, height]]."""
    (x, y), (width, height) = value
    return whole([x, y, width, height])


def words(frame):
    if frame is None:
        return "none"
    x, y, width, height = whole(frame)
    return f"{x},{y} {width}x{height}"


class Names:
    """Window ids and process ids under names that are the same in both worlds."""

    def __init__(self, path, processes):
        self.path = path
        self.windows = {}
        self.processes = {}
        for word in processes:
            name, _, pid = word.partition("=")
            if pid.isdigit():
                self.processes[int(pid)] = name
        try:
            with open(path, encoding="utf-8") as lines:
                for line in lines:
                    number, name = line.split()
                    self.windows[int(number)] = name
        except FileNotFoundError:
            pass

    def add(self, numbers):
        """In the order of their numbers, which is the order they opened in: both worlds count upwards."""
        fresh = sorted(number for number in numbers if number not in self.windows)
        for number in fresh:
            self.windows[number] = f"W{len(self.windows) + 1}"
        if fresh:
            with open(self.path, "w", encoding="utf-8") as out:
                for number, name in self.windows.items():
                    out.write(f"{number} {name}\n")

    def window(self, number):
        return self.windows.get(number, "W?")

    def process(self, pid):
        return self.processes.get(pid, "other")

    def in_text(self, text):
        """`docked w101 at the left edge`, `zoom 101`."""
        return re.sub(r"\bw?(\d+)\b", lambda found: self.windows.get(int(found.group(1)), found.group(0)), text)


def read(folder, name):
    try:
        with open(f"{folder}/{name}", encoding="utf-8") as file:
            return file.read()
    except FileNotFoundError:
        return ""


# MARK: What Arbor believes


def notation(tree, node, names):
    """A part of the tree as a line of text: `W1 | Desktop | (W2 / W3)`."""
    entry = tree["nodes"][str(node)]
    kind = entry["kind"]
    if "desktop" in kind:
        return "Desktop"
    if "stack" in kind:
        held = [names.window(number) for number in kind["stack"]["windows"]]
        return held[0] if len(held) == 1 else "[" + " ".join(held) + "]"
    if "split" in kind:
        sign = " | " if kind["split"]["axis"] == "horizontal" else " / "
        parts = []
        for child in kind["split"]["children"]:
            text = notation(tree, child, names)
            parts.append(f"({text})" if "split" in tree["nodes"][str(child)]["kind"] else text)
        return sign.join(parts)
    return "?" + "/".join(sorted(kind))


def belief(reply, names):
    if not reply.strip():
        return None
    try:
        answer = json.loads(reply)
        state = answer["state"]
    except (ValueError, KeyError):
        return None
    tiled = {}
    result = {
        "running": state["running"],
        "says": names.in_text(answer.get("message", "")),
        "focused": names.window(state["focused"]) if state.get("focused") is not None else None,
        "paused": state.get("paused", False),
        "held": state.get("held"),
        "waiting": len(state.get("waiting", [])),
        "displays": [],
        "windows": {},
    }
    slots = {}
    for display in state["displays"]:
        tree = display["tree"]
        tiles = []
        for tile in display["tiles"]:
            held = [names.window(number) for number in tile["windows"]]
            tiles.append({"kind": tile["kind"], "frame": rect(tile["frame"]), "windows": held})
            for number in tile["windows"]:
                tiled[number] = True
        for number, frame in display["windowFrames"].items():
            slots[int(number)] = rect(frame)
        result["displays"].append({
            "visible": rect(display["visibleFrame"]),
            "tree": notation(tree, tree["root"], names),
            "camera": "all" if display["camera"] == tree["root"] else notation(tree, display["camera"], names),
            "desktop": rect(display["desktopFrame"]) if display.get("desktopFrame") else None,
            "tiles": sorted(tiles, key=lambda tile: tile["frame"]),
            "floating": [names.window(number) for number in display["floating"]],
            "back": display["canGoBack"],
            "forward": display["canGoForward"],
        })
    for window in state["windows"]:
        if not window["managed"]:
            status = ["unmanaged"]
        else:
            status = ["docked" if window["docked"] else "floating"]
        if window["id"] in tiled:
            status.append("tile")
        status += [trait for trait in TRAITS if window.get(trait)]
        entry = {"status": " ".join(status), "frame": rect(window["frame"])}
        if window["id"] in slots:
            entry["slot"] = slots[window["id"]]
        result["windows"][names.window(window["id"])] = entry
    return result


# MARK: What the window server shows


def listed(text):
    """id pid layer x y w h on|off owner…"""
    rows = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 8:
            continue
        try:
            numbers = [float(part) for part in parts[:7]]
        except ValueError:
            continue
        rows.append({
            "id": int(numbers[0]), "pid": int(numbers[1]), "layer": int(numbers[2]), "frame": whole(numbers[3:7]),
            "on": parts[7] == "on", "owner": " ".join(parts[8:]),
        })
    return rows


def truth(folder, names):
    everything = listed(read(folder, "windows"))
    shown = listed(read(folder, "on-screen"))
    apps = {pid for pid, name in names.processes.items() if name != "arbor"}
    # Ordinary windows only: an app has helpers in the window server's list (a tooltip, a menu's shadow) that nobody opened.
    names.add(
        row["id"] for row in everything
        if row["pid"] in apps and row["layer"] == 0 and row["frame"][2] >= 100 and row["frame"][3] >= 60
    )
    result = {"windows": {}, "order": [], "overlays": {}, "furniture": {}}
    for row in everything:
        if row["id"] in names.windows:
            result["windows"][names.window(row["id"])] = {"frame": row["frame"], "on": row["on"]}
    for row in shown:
        if row["id"] in names.windows:
            result["order"].append(names.window(row["id"]))
        elif names.processes.get(row["pid"]) == "arbor":
            level = str(row["layer"])
            result["overlays"][level] = result["overlays"].get(level, 0) + 1
        elif row["pid"] not in apps:
            # The menu bar, the Dock, the wallpaper, and what macOS puts up by itself: the outline of its own tiling is WindowManager's.
            result["furniture"][row["owner"]] = result["furniture"].get(row["owner"], 0) + 1
    answer = read(folder, "keyboard").split()
    pid, window = (answer + ["-", "-"])[:2]
    result["front"] = names.process(int(pid)) if pid.isdigit() else "nobody"
    result["keyboard"] = names.window(int(window)) if window.isdigit() else None
    return result


# MARK: What crossed the seam


def argument(value, names):
    if isinstance(value, bool) or value is None:
        return json.dumps(value)
    if isinstance(value, int):
        if value in names.windows:
            return names.windows[value]
        if value in names.processes:
            return names.processes[value]
        return str(value)
    if isinstance(value, str):
        return names.in_text(value)
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def report(line, names):
    """One line of a trace as a word, or None for what is left out."""
    arguments = ",".join(argument(value, names) for value in line.get("args", []))
    if "event" in line:
        kind = line["event"]
        if kind in ("appeared", "changed"):
            window = line["window"]
            word = f"{kind}:{names.window(window['id'])}"
            if kind == "changed":
                word += ":user" if line.get("user") else ":arbor"
            return word + "".join(f"+{flag}" for flag in FLAGS if window.get(flag))
        if "id" in line:
            return f"{kind}:{names.window(line['id'])}"
        return f"{kind}:{arguments}" if arguments else kind
    if "action" in line:
        return f"action:{line['action']}" + (f":{arguments}" if arguments else "")
    if "call" in line:
        kind = line["call"]
        if kind in READS:
            return None
        if kind == "setFrame":
            return f"setFrame:{names.window(line['id'])} {words(line['frame'])}→{words(line.get('result'))}"
        if kind == "showDropPreview":
            return "preview:" + ("off" if line.get("frame") is None else words(line["frame"]))
        if "id" in line:
            return f"{kind}:{names.window(line['id'])}"
        return f"{kind}:{arguments}" if arguments else kind
    if "command" in line and line.get("from") != "script":
        return f"command:{names.in_text(line['command'])}:{line.get('from', 'nobody')}"
    return None


def is_question(text):
    parts = text.split()
    return bool(parts) and parts[0] in QUESTIONS and (parts[0] != "layout" or len(parts) == 1)


def since_the_last_mark(path, names):
    """The lines between the last two marks; after the last one if the trace has ended since."""
    sections, ended = [[]], False
    try:
        with open(path, encoding="utf-8") as lines:
            rows = [line for line in lines if line.endswith("\n")][1:]
    except OSError:
        return [], []
    for row in rows:
        try:
            line = json.loads(row)
        except ValueError:
            continue
        if str(line.get("note", "")).startswith(MARK):
            sections.append([])
        elif "end" in line:
            ended = True
        else:
            sections[-1].append(line)
    section = sections[-1] if ended else sections[-2] if len(sections) > 1 else []
    reports, replies, asking = [], [], None
    for line in section:
        if asking is not None:
            if line.get("done") == asking:
                asking = None
            continue
        if "command" in line and is_question(line["command"]):
            asking = line["command"]
            continue
        if "done" in line:
            replies.append(("" if line.get("ok") else "failed: ") + names.in_text(line.get("message", "")))
            continue
        word = report(line, names)
        if word is not None:
            reports.append(word)
    return reports, replies


def dump(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def main():
    arguments = sys.argv[1:]
    if len(arguments) >= 3 and arguments[0] == "look":
        folder, path = arguments[1:3]
        names = Names(path, arguments[3:])
        # The window server first: it is what gives a new window its name.
        seen = truth(folder, names)
        print(dump({"belief": belief(read(folder, "state"), names), "truth": seen}))
    elif len(arguments) >= 8 and arguments[0] == "line":
        journey, step, number, settled, look, path, trace = arguments[1:8]
        names = Names(path, arguments[8:])
        try:
            with open(look, encoding="utf-8") as file:
                seen = json.load(file)
        except (OSError, ValueError):
            fail(f"no look to write down in {look}")
        reports, replies = since_the_last_mark(trace, names)
        print(dump({
            "journey": journey, "step": step, "n": int(number), "settled": settled == "yes", "belief": seen["belief"],
            "truth": seen["truth"], "reports": reports, "replies": replies,
        }))
    else:
        fail(__doc__)


if __name__ == "__main__":
    main()
