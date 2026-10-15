#!/usr/bin/env python3
"""Where the time goes between a command and the windows at rest, act by act, from what Arbor itself wrote down.

  first-dock.py table <arbor.log> <trace.jsonl>…     a table: one row for each command that moved a window
  first-dock.py ready <arbor.log>                    what was got ready ahead of the first motion, and how long each piece took
  first-dock.py wait <arbor.log> <n>                 how many ms the stage kept the windows waiting the n-th time it came up (1 is the first)
  first-dock.py --self-test

Needs no Mac: a trace (docs/TRACES.md) has every question Arbor asked of the window system with the time it took, and the log has the stage.
first-dock.sh prints these on a hosted Mac; any day's log and traces can be read again later, on Linux.

The columns, all in ms from the moment the command arrived:
  first move   until Arbor first asked a window to move: what the person waits before anything happens
  of it stage  of that, what the stage took to come up (the log's "kept the windows waiting"; "-" in logs from before that line)
  at rest      until the last window had answered
  answered     until the command was done
  stage down   until the stage had lifted and the real windows showed: what the person sees as the end
  moves        questions of the kind "take this frame", the windows they went to, and the time the apps took to answer them all
"""
import json
import re
import sys
from datetime import datetime, timezone

STAMP = re.compile(r"^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3})Z (\w+) +(.*)$")
WAIT = re.compile(r"the stage kept the windows waiting (\d+) ms")
TOGETHER = re.compile(r"moveTogether, \d+ windows, took ([\d.]+) s")
QUIET = ("state", "status", "stats", "trace", "get ", "bindings", "doctor")


def log_lines(path):
    """[(ms since 1970, text)]"""
    lines = []
    with open(path, encoding="utf-8", errors="replace") as file:
        for line in file:
            match = STAMP.match(line.rstrip("\n"))
            if match:
                moment = datetime.strptime(match.group(1), "%Y-%m-%dT%H:%M:%S.%f").replace(tzinfo=timezone.utc)
                lines.append((round(moment.timestamp() * 1000), match.group(3)))
    return lines


def acts(trace_lines):
    """The commands of a trace that moved a window: [{command, began, first, rest, done, moves, windows, apps}], seconds of the trace."""
    found, act = [], None
    for line in trace_lines:
        if "command" in line and not line["command"].startswith(QUIET):
            act = {"command": line["command"], "began": line["t"], "first": None, "rest": None, "moves": 0, "windows": set(), "apps": 0.0}
        elif act is None:
            continue
        elif line.get("call") == "setFrame" or TOGETHER.match(line.get("note", "")):
            # Windows moved side by side are waited for in one place, which leaves a remark; each then has its line as well, with no time to it.
            together = TOGETHER.match(line.get("note", ""))
            took = float(together.group(1)) if together else line.get("took", 0)
            if act["first"] is None:
                act["first"] = line["t"] - took
            act["rest"] = line["t"]
            act["apps"] += took
            if not together:
                act["moves"] += 1
                act["windows"].add(line["id"])
        elif "done" in line:
            act["done"] = line["t"]
            if act["moves"]:
                found.append(act)
            act = None
    return found


def table(log_path, trace_paths):
    log = log_lines(log_path)
    rows = []
    for path in trace_paths:
        with open(path, encoding="utf-8") as file:
            lines = [json.loads(line) for line in file if line.strip()]
        if not lines:
            continue
        name = lines[0].get("name", "")
        found = acts(lines[1:])
        # The trace counts seconds from its first line, and the log says when it began to record: after the header was written, which takes a
        # moment. "stage up" is the better mark where there is one: it is logged as the stage is up, and the first move is asked for right then.
        zero = next((at for at, text in log if text.startswith(f"trace {name}: recording")), None)
        if zero is not None and found:
            up = next((at for at, text in log if at >= zero and text.startswith("stage up")), None)
            if up is not None and abs(up - (zero + found[0]["first"] * 1000)) < 250:
                zero = up - found[0]["first"] * 1000
        for index, act in enumerate(found):
            row = {
                "command": act["command"], "first": ms(act["first"] - act["began"]), "rest": ms(act["rest"] - act["began"]),
                "done": ms(act["done"] - act["began"]), "moves": act["moves"], "windows": len(act["windows"]), "apps": ms(act["apps"]),
                "stage": None, "down": None,
            }
            if zero is not None:
                began = zero + act["began"] * 1000
                # Up to the next act: one that put up no stage has none of its neighbour's.
                until = zero + found[index + 1]["began"] * 1000 if index + 1 < len(found) else began + 5000
                mine = [(at, text) for at, text in log if began - 5 <= at < until]
                row["stage"] = next((int(wait.group(1)) for _, text in mine if (wait := WAIT.match(text))), None)
                row["down"] = next((round(at - began) for at, text in mine if text == "stage down"), None)
            rows.append(row)
    return rows


def ms(seconds):
    return round(seconds * 1000)


def show(rows):
    print("| command | first move | of it stage | at rest | answered | stage down | moves |")
    print("|---|---|---|---|---|---|---|")
    for row in rows:
        blank = lambda value: "-" if value is None else value
        print(f"| {row['command']} | {row['first']} | {blank(row['stage'])} | {row['rest']} | {row['done']} | {blank(row['down'])} "
              f"| {row['moves']} to {row['windows']} windows, {row['apps']} ms |")


def ready(log_path):
    pieces = [(found.group(1), int(found.group(2))) for _, text in log_lines(log_path) if (found := re.match(r"got ready (.*?) in (\d+) ms", text))]
    return pieces


def waits(log_path):
    return [int(found.group(1)) for _, text in log_lines(log_path) if (found := WAIT.match(text))]


def self_test():
    import os
    import tempfile
    log = """2026-01-01T10:00:00.000Z INFO  started: 1 display(s), 2 managed window(s)
2026-01-01T10:00:00.100Z DEBUG got ready the stage of D in 40 ms, the desktop 30 of them
2026-01-01T10:00:00.200Z DEBUG got ready the costume of com.example.one in 7 ms
2026-01-01T10:00:05.040Z INFO  trace t: recording to /somewhere
2026-01-01T10:00:06.015Z DEBUG stage up on D: 2 stand-ins, 0.46 s
2026-01-01T10:00:06.016Z DEBUG the stage kept the windows waiting 9 ms: its panel 0, 2 costumes 1 (0 not ready), the desktop 0, going up 8
2026-01-01T10:00:06.200Z DEBUG stage retargeted on D: 2 stand-ins, 0.27 s
2026-01-01T10:00:06.740Z DEBUG stage down
2026-01-01T10:00:09.020Z DEBUG stage up on D: 2 stand-ins, 0.46 s
2026-01-01T10:00:09.021Z DEBUG the stage kept the windows waiting 4 ms: its panel 0, 2 costumes 0 (0 not ready), the desktop 0, going up 4
2026-01-01T10:00:09.600Z DEBUG stage down
"""
    trace = [
        {"name": "t"}, {"t": 0.5, "command": "state"}, {"t": 0.51, "done": "state"},
        {"t": 1.0, "command": "dock left"}, {"t": 1.001, "call": "focusedWindow", "result": 1},
        {"t": 1.1, "call": "setFrame", "id": 1, "took": 0.085}, {"t": 1.19, "call": "setFrame", "id": 2, "took": 0.08},
        {"t": 1.195, "call": "setFrame", "id": 2}, {"t": 1.21, "done": "dock left"},
        {"t": 2.0, "command": "zoom"}, {"t": 2.01, "done": "zoom"},
        # No stage for this one: the next one's is not its own.
        {"t": 3.0, "command": "relayout"}, {"t": 3.05, "call": "setFrame", "id": 1, "took": 0.04}, {"t": 3.06, "done": "relayout"},
        # Side by side: the waiting is in the remark.
        {"t": 4.0, "command": "back"}, {"t": 4.12, "note": "moveTogether, 2 windows, took 0.1 s"}, {"t": 4.121, "call": "setFrame", "id": 1},
        {"t": 4.122, "call": "setFrame", "id": 2}, {"t": 4.13, "done": "back"},
    ]
    with tempfile.TemporaryDirectory() as folder:
        log_path, trace_path = os.path.join(folder, "arbor.log"), os.path.join(folder, "t.jsonl")
        with open(log_path, "w", encoding="utf-8") as file:
            file.write(log)
        with open(trace_path, "w", encoding="utf-8") as file:
            file.write("\n".join(json.dumps(line) for line in trace))
        rows = table(log_path, [trace_path])
        # The log began to speak of the trace 40 ms late; "stage up" sets the clocks side by side.
        expected = [
            {"command": "dock left", "first": 15, "rest": 195, "done": 210, "moves": 3, "windows": 2, "apps": 165, "stage": 9, "down": 740},
            {"command": "relayout", "first": 10, "rest": 50, "done": 60, "moves": 1, "windows": 1, "apps": 40, "stage": None, "down": None},
            {"command": "back", "first": 20, "rest": 122, "done": 130, "moves": 2, "windows": 2, "apps": 100, "stage": 4, "down": 600},
        ]
        assert rows == expected, rows
        assert ready(log_path) == [("the stage of D", 40), ("the costume of com.example.one", 7)], ready(log_path)
        assert waits(log_path) == [9, 4], waits(log_path)
    print("first-dock.py: its self-test passes")


def main(arguments):
    if arguments == ["--self-test"]:
        return self_test()
    if len(arguments) >= 3 and arguments[0] == "table":
        return show(table(arguments[1], arguments[2:]))
    if len(arguments) == 2 and arguments[0] == "ready":
        pieces = ready(arguments[1])
        for name, took in pieces:
            print(f"{took:5d} ms  {name}")
        print(f"{sum(took for _, took in pieces):5d} ms  in all, {len(pieces)} pieces, the longest {max((took for _, took in pieces), default=0)} ms")
        return None
    if len(arguments) == 3 and arguments[0] == "wait":
        found = waits(arguments[1])
        index = int(arguments[2]) - 1
        print(found[index] if index < len(found) else "")
        return None
    sys.exit(__doc__)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except OSError as problem:
        sys.exit(f"first-dock.py: {problem}")
