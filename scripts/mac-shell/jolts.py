#!/usr/bin/env python3
"""The jolt detector: reads what sampler.swift wrote while a script played, and says what a person would have seen.

For every step of the script: which windows moved, how many times each moved and by which road, whether a window moved
that the step did not name, whether the window switched to ended in front and wholly in view, whether sizes came back,
whether a window was lost. The rules are the product's (docs/TESTING.md, "An ordinary day"):

  2  nothing moves that the person did not move
  3  no jolts: a window moves once, to where it ends up
  4  the window you switch to comes to the front and into view
  5  quitting, Float All and pause give windows their own earlier sizes back
  L  no window is lost: none leaves the screen or ends out of view unless the step says so

  jolts.py report <samples> [--json <file>]   the findings per rule, each with the step that shows it, then every step.
                                              Exit code 1 when a rule was broken, 0 when none was
  jolts.py failing <samples>                  the numbers of the steps with a finding, one per line
  jolts.py trace <samples> <step> [window]    every frame seen during that step
  jolts.py story <samples> <step> [log…]      one timeline of that step: what the screen showed, and the lines of those logs
                                              (arbor.log, `apptool watch`) that were written meanwhile
  jolts.py --self-test

The script says what it is doing in marks (lib-day.sh writes them):

  label <id> <name>        what to call a window in the report (never its title)
  arbor <pid>              Arbor's process, whose own panels are not windows for these rules
  chapter <title>
  begin <n> <slug>         a step begins: one thing a person does
  text <n> <words…>        what the person does, for the report
  finding <n> <rule> <FAIL|ODD> <words…>      something the script itself found out during the step
  end <n> [key=value…]     things have settled, and this should hold:
    act=<kind>             what kind of thing the person did (docs/VIABLE.md lists the kinds), for the count
    moves=<ids>|any|none   the windows the step may move (default none)
    yields=<ids>           these float, and may move too if they lay where one of `moves=` is at the end: it took their place
    drags=<id>             the person drags this one: while the button is down it goes where the pointer goes
    front=<id>             it ends in front of every other window, its app in front, wholly in view
    leaves=<ids>|any       these may leave the screen (closed, hidden, minimized, another Space)
    comes=<ids>            these are on the screen at the end
    own=<ids>|all          where these are now is where the person wants them: the size to give back later
    restores=<ids>|all     these have their own sizes back; places=1: their places too, as after Float All and Quit
    everything=1           no window may be out of view
    returns=<n>            every window is where it was at the end of step n
    floating=<ids>         for the report: these float, so no arrangement explains a move of theirs
    judge=no               nothing is judged: Arbor is not running yet, and apps place their own windows as they open
    settled=<quiet|restless>:<ms>

What happens between a step's end and the next step's beginning counts for the step that ended: it came late.
"""

import datetime
import json
import sys

# Two changes of one window further apart than this are two moves to a person, not one.
EPISODE_GAP = 250
# Points a window may travel beyond the straight road, per coordinate, before it counts as having gone elsewhere first.
EXCESS = 6
# A step during which the sampler saw nothing for longer than this is not judged: it says nothing either way.
BLIND = 250
# Points that are no move at all: apps round sizes, and Retina screens deal in halves.
SAME = 2
RULES = [
    ("2", "nothing moves that the person did not move"),
    ("3", "no jolts: a window moves once, to where it ends up"),
    ("4", "the window you switch to comes to the front and into view"),
    ("5", "quitting, Float All and pause give windows their own sizes back"),
    ("L", "no window is lost or stuck"),
    ("-", "what the script itself checked"),
]


def words(frame):
    x, y, width, height = (round(number) for number in frame)
    return f"{x},{y} {width}×{height}"


def differs(a, b, by=SAME):
    return any(abs(p - q) > by for p, q in zip(a, b))


def shared(a, b):
    width = min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])
    height = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
    return width * height if width > 0 and height > 0 else 0


def inside(frame, area, by=SAME):
    return (
        frame[0] >= area[0] - by
        and frame[1] >= area[1] - by
        and frame[0] + frame[2] <= area[0] + area[2] + by
        and frame[1] + frame[3] <= area[1] + area[3] + by
    )


def ids(value):
    return {int(word) for word in value.split(",") if word.strip().isdigit()}


class Step:
    def __init__(self, number, slug, chapter, began):
        self.number = number
        self.slug = slug
        self.chapter = chapter
        self.began = began
        self.ended = None
        self.text = ""
        self.wants = {}
        # id -> [(time, frame or None, button is down)], beginning with where it was when the step began
        self.traces = {}
        self.born = set()
        self.tops = []
        self.apps = []
        self.late_samples = []
        self.at_end = None
        self.findings = []
        self.moved = {}

    def find(self, rule, level, window, what, trace=None):
        self.findings.append({"rule": rule, "level": level, "window": window, "what": what, "trace": trace})


class World:
    """The screen as the samples tell it."""

    def __init__(self):
        self.frames = {}
        self.last_frames = {}
        self.pids = {}
        self.owners = {}
        self.layers = {}
        self.order = []
        self.app = None
        self.visible = None
        self.display = None
        self.button = False
        self.arbors = set()
        self.labels = {}

    def ordinary(self, window):
        return self.layers.get(window) == 0 and self.pids.get(window) not in self.arbors

    def name(self, window):
        if window in self.labels:
            return f"{self.labels[window]} (w{window})"
        return f"w{window} of {self.owners.get(window, '?')}"

    def snapshot(self):
        return {
            "frames": {window: frame for window, frame in self.frames.items() if self.ordinary(window)},
            "order": [window for window in self.order if self.ordinary(window)],
            "app": self.app,
            "visible": self.visible,
            "display": self.display,
        }


def read(path):
    """Plays the samples and returns the world at the end, the steps, and the sampler's own account of itself."""
    world = World()
    steps = []
    by_number = {}
    current = None
    chapter = ""
    account = ""
    own = {}
    with open(path, encoding="utf-8", errors="replace") as lines:
        for line in lines:
            parts = line.rstrip("\n").split(" ")
            if len(parts) < 2 or not parts[0].isdigit():
                continue
            time, kind, rest = int(parts[0]), parts[1], parts[2:]
            if kind == "W" and len(rest) >= 7:
                window = int(rest[0])
                frame = tuple(float(number) for number in rest[3:7])
                known = window in world.last_frames
                world.pids[window], world.layers[window] = int(rest[1]), int(rest[2])
                world.owners[window] = " ".join(rest[7:]).replace("_", " ")
                world.frames[window] = world.last_frames[window] = frame
                if current and world.ordinary(window):
                    if window not in current.traces:
                        current.traces[window] = []
                        if not known:
                            current.born.add(window)
                    current.traces[window].append((time, frame, world.button))
            elif kind == "G" and rest:
                window = int(rest[0])
                if current and world.ordinary(window):
                    current.traces.setdefault(window, [(current.began, world.frames.get(window), False)])
                    current.traces[window].append((time, None, world.button))
                world.frames.pop(window, None)
            elif kind == "Z":
                world.order = [int(word) for word in rest[0].split(",")] if rest and rest[0] else []
                top = next((window for window in world.order if world.ordinary(window)), None)
                if current and (not current.tops or current.tops[-1] != top):
                    current.tops.append(top)
            elif kind == "A" and rest:
                world.app = int(rest[0])
                if current:
                    current.apps.append(world.app)
            elif kind == "B" and rest:
                world.button = rest[0] == "down"
            elif kind == "V" and len(rest) == 4:
                world.visible = tuple(float(number) for number in rest)
            elif kind == "D" and len(rest) == 4:
                world.display = tuple(float(number) for number in rest)
            elif kind == "L" and rest:
                if current:
                    current.late_samples.append(int(rest[0]))
            elif kind == "S":
                account = " ".join(rest)
            elif kind == "M" and rest:
                verb, rest = rest[0], rest[1:]
                if verb == "label" and len(rest) >= 2:
                    world.labels[int(rest[0])] = " ".join(rest[1:])
                elif verb == "arbor" and rest:
                    world.arbors.add(int(rest[0]))
                elif verb == "chapter":
                    chapter = " ".join(rest)
                elif verb == "begin" and len(rest) >= 2:
                    current = Step(int(rest[0]), rest[1], chapter, time)
                    for window, frame in world.frames.items():
                        if world.ordinary(window):
                            current.traces[window] = [(time, frame, world.button)]
                    top = next((window for window in world.order if world.ordinary(window)), None)
                    current.tops.append(top)
                    steps.append(current)
                    by_number[current.number] = current
                elif verb == "text" and len(rest) >= 2 and int(rest[0]) in by_number:
                    by_number[int(rest[0])].text = " ".join(rest[1:])
                elif verb == "finding" and len(rest) >= 4 and int(rest[0]) in by_number:
                    by_number[int(rest[0])].find(rest[1], rest[2], None, " ".join(rest[3:]))
                elif verb == "end" and rest and int(rest[0]) in by_number:
                    step = by_number[int(rest[0])]
                    step.ended = time
                    step.wants = dict(word.split("=", 1) for word in rest[1:] if "=" in word)
                    step.at_end = world.snapshot()
    for step in steps:
        judge(step, world, by_number, own)
    return world, steps, account


def road(trace):
    """A trace as text: when, from the first entry on, and where."""
    start = trace[0][0]
    shown = trace if len(trace) <= 12 else trace[:6] + [None] + trace[-5:]
    parts = []
    for entry in shown:
        if entry is None:
            parts.append(f"… {len(trace) - 11} more …")
            continue
        time, frame, _ = entry
        parts.append(f"+{time - start} ms {words(frame) if frame else 'off the screen'}")
    return " · ".join(parts)


def measure(trace):
    """How a window travelled: (moves, frames seen, milliseconds, the worst detour in points, whether it ended elsewhere)."""
    seen = [entry for entry in trace if entry[1] is not None]
    changes = [
        (after[0], after[1]) for before, after in zip(seen, seen[1:]) if differs(before[1], after[1], by=0.6)
    ]
    if not changes:
        return 0, 0, 0, 0, False
    moves = 1
    for before, after in zip(changes, changes[1:]):
        if after[0] - before[0] > EPISODE_GAP:
            moves += 1
    detour = 0
    for index in range(4):
        values = [entry[1][index] for entry in seen]
        travelled = sum(abs(b - a) for a, b in zip(values, values[1:]))
        detour = max(detour, travelled - abs(values[-1] - values[0]))
    return moves, len(changes), changes[-1][0] - changes[0][0], detour, differs(seen[0][1], seen[-1][1])


def remember(step, own):
    """Where these windows are now is where the person wants them. A window that just opened is where its app put it."""
    frames = step.at_end["frames"]
    mine = step.wants.get("own", "")
    for window in frames if mine == "all" else ids(mine) | {born for born in step.born if born not in own}:
        if window in frames:
            own[window] = frames[window]


def judge(step, world, by_number, own):
    wants = step.wants
    end = step.at_end
    if wants.get("judge") == "no" and end:
        for window, trace in step.traces.items():
            moves, frames, took, _, _ = measure(trace)
            if moves:
                step.moved[window] = (moves, frames, took)
        remember(step, own)
        return
    may = wants.get("moves", "none")
    named = ids(may)
    dragged = ids(wants.get("drags", ""))
    may_leave = wants.get("leaves", "")
    kin = {world.pids.get(window) for window in named | dragged}
    if end:
        taken = [end["frames"][window] for window in named | dragged if window in end["frames"]]
        for window in ids(wants.get("yields", "")):
            trace = step.traces.get(window)
            if trace and trace[0][1] and any(shared(trace[0][1], frame) > 0 for frame in taken):
                named.add(window)

    for window, trace in sorted(step.traces.items()):
        if window in dragged:
            # In the hand it goes where the hand goes. What counts is what happens to its size meanwhile, and everything after.
            held = [entry for entry in trace if entry[2] and entry[1]]
            if any(differs(a[1][2:], b[1][2:]) for a, b in zip(held, held[1:])):
                step.find("3", "ODD", window, "changed its size while it was being dragged", road(held))
            last_held = max((index for index, entry in enumerate(trace) if entry[2]), default=0)
            trace = trace[last_held:]
        moves, frames, took, detour, elsewhere = measure(trace)
        if window in step.born and trace:
            # Where it first showed is where its app put it.
            pass
        if moves:
            step.moved[window] = (moves, frames, took)
        if moves and may != "any" and window not in named and window not in dragged:
            if window in step.born:
                step.find("3", "FAIL", window, "opened in one place and was then moved to another", road(trace))
            elif window not in world.labels and world.pids.get(window) in kin:
                step.find("2", "ODD", window, "moved along with a window of its app", road(trace))
            else:
                kind = "a floating window, " if window in ids(wants.get("floating", "")) else ""
                how = "moved" if elsewhere else "moved and came back"
                step.find("2", "FAIL", window, f"{kind}{how}, and the step did not name it", road(trace))
        if moves > 1:
            step.find("3", "FAIL", window, f"moved {moves} times", road(trace))
        elif detour > EXCESS and (may == "any" or window in named or window in dragged):
            step.find("3", "FAIL", window, f"went {round(detour)} points out of its way before it ended up", road(trace))
        gone = trace and trace[-1][1] is None
        if gone and may_leave != "any" and window not in ids(may_leave) and window in world.labels:
            step.find("L", "FAIL", window, "left the screen, and the step did not say it would", road(trace))
        elif not gone and any(entry[1] is None for entry in trace) and may_leave != "any" and window not in ids(may_leave):
            if window in world.labels:
                step.find("3", "FAIL", window, "left the screen and came back", road(trace))

    if end is None:
        step.find("-", "FAIL", None, "the step never ended: the script stopped here")
        return
    if step.ended is not None:
        for window, trace in step.traces.items():
            late = [entry for entry in trace if entry[0] > step.ended]
            if late and window in step.moved:
                step.find("3", "ODD", window, f"was still moving {late[-1][0] - step.ended} ms after everything had been quiet for a second")

    tops = [top for top in step.tops if top is not None]
    if len(tops) > 3:
        step.find("4", "ODD", None, "the window in front changed %d times: %s" % (len(tops) - 1, " → ".join(world.name(top) for top in tops[:8])))

    frames, order, area = end["frames"], end["order"], end["visible"]
    display = end["display"] or area
    for window in sorted(ids(wants.get("front", ""))):
        if window not in frames:
            step.find("4", "FAIL", window, "is not on the screen at all")
            continue
        if order and order[0] != window:
            ahead = order[: order.index(window)] if window in order else order[:3]
            covering = [other for other in ahead if shared(frames[other], frames[window]) > 0]
            step.find(
                "4", "FAIL", window,
                "is not in front: %s ahead of it%s" % (
                    ", ".join(world.name(other) for other in ahead[:4]),
                    ", of which %d cover part of it" % len(covering) if covering else ", none of which covers it"))
        if end["app"] is not None and end["app"] != world.pids.get(window):
            step.find("4", "FAIL", window, f"its app is not the one in front (process {end['app']} is)")
        if area and not inside(frames[window], area):
            share = shared(frames[window], area) / max(frames[window][2] * frames[window][3], 1)
            step.find("4", "FAIL", window, f"is not wholly in view: {share:.0%} of it, at {words(frames[window])} in {words(area)}")

    for window in sorted(ids(wants.get("comes", ""))):
        if window not in frames:
            step.find("L", "FAIL", window, "should be on the screen and is not")

    restores = wants.get("restores", "")
    for window in sorted(frames if restores == "all" else ids(restores)):
        if window not in own or window not in frames:
            continue
        if differs(own[window][2:], frames[window][2:]):
            step.find("5", "FAIL", window, f"is {words(frames[window])}; its own size was {words(own[window])}")
        elif wants.get("places") == "1" and differs(own[window][:2], frames[window][:2]):
            step.find("5", "FAIL", window, f"has its size back but not its place: {words(frames[window])}, it was at {words(own[window])}")

    if wants.get("everything") == "1" and display:
        for window, frame in sorted(frames.items()):
            if window not in world.labels:
                continue
            share = shared(frame, display) / max(frame[2] * frame[3], 1)
            if share < 0.5 and not (window in own and shared(own[window], display) / max(own[window][2] * own[window][3], 1) < 0.5):
                step.find("L", "FAIL", window, f"is out of view: {share:.0%} of it is on the display, at {words(frame)}")

    if wants.get("returns", "").isdigit() and int(wants["returns"]) in by_number:
        before = by_number[int(wants["returns"])].at_end
        for window, frame in sorted(frames.items()):
            if before and window in before["frames"] and differs(before["frames"][window], frame):
                step.find(
                    "2", "FAIL", window,
                    f"is not back where it was after step {wants['returns']}: {words(frame)}, it was at {words(before['frames'][window])}")

    if wants.get("settled", "").startswith("restless"):
        step.find("3", "ODD", None, "windows were still moving when the step gave up waiting for quiet")

    remember(step, own)


# MARK: The report


def judged(step):
    return step.at_end is not None and step.wants.get("judge") != "no" and max(step.late_samples, default=0) <= BLIND


def checked(step, rule):
    wants = step.wants
    if not judged(step):
        return False
    return {
        "2": wants.get("moves", "none") != "any" or "returns" in wants,
        "3": True,
        "4": "front" in wants,
        "5": "restores" in wants,
        "L": True,
        "-": True,
    }[rule]


def fails(step, rule=None):
    return [finding for finding in step.findings if finding["level"] == "FAIL" and rule in (None, finding["rule"])]


def report(world, steps, account):
    out = []
    broken = sum(1 for step in steps if fails(step))
    count = sum(1 for step in steps if judged(step))
    seconds = (steps[-1].ended or steps[-1].began) - steps[0].began if steps else 0
    out.append(f"{len(steps)} steps in {seconds // 1000} s, {count} of them judged, {broken} with a rule broken. The sampler: {account or 'it was cut off'}.")
    out.append("")
    out.append("## Per rule")
    out.append("")
    out.append("| Rule | | Steps that checked it | Steps that broke it | Which |")
    out.append("|---|---|---|---|---|")
    for rule, title in RULES:
        bad = [step for step in steps if fails(step, rule)]
        which = ", ".join(f"{step.number} {step.slug}" for step in bad[:12]) + (" …" if len(bad) > 12 else "")
        out.append(f"| {rule} | {title} | {sum(1 for step in steps if checked(step, rule))} | {len(bad)} | {which} |")
    out.append("")
    out.append("## Findings")
    for rule, title in RULES:
        found = [(step, finding) for step in steps for finding in step.findings if finding["rule"] == rule]
        if not found:
            continue
        out.append("")
        out.append(f"### Rule {rule}: {title}")
        out.append("")
        for step, finding in found:
            mark = "✘" if finding["level"] == "FAIL" else "~"
            who = world.name(finding["window"]) + " " if finding["window"] is not None else ""
            out.append(f"- {mark} **{step.number} {step.slug}** ({step.text}): {who}{finding['what']}")
            if finding["trace"]:
                out.append(f"  - {finding['trace']}")
    out.append("")
    out.append("## Every step")
    out.append("")
    out.append("Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).")
    chapter = None
    for step in steps:
        if step.chapter != chapter:
            chapter = step.chapter
            out.append("")
            out.append(f"### {chapter}")
            out.append("")
            out.append("| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |")
            out.append("|---|---|---|---|---|---|---|---|---|---|---|")
        moved = ", ".join(
            f"{world.labels.get(window, 'w%d' % window)} ×{moves} ({frames}, {took} ms)"
            for window, (moves, frames, took) in sorted(step.moved.items()))
        cells = []
        for rule, _ in RULES:
            if fails(step, rule):
                cells.append("✘")
            elif any(finding["rule"] == rule for finding in step.findings):
                cells.append("~")
            else:
                cells.append("✔" if checked(step, rule) else "")
        settled = step.wants.get("settled", "").replace(":", " ") + (" ms" if "settled" in step.wants else "")
        if step.late_samples:
            settled += f"; blind for {max(step.late_samples)} ms"
        out.append(f"| {step.number} | {step.slug} | {step.text} | {moved} | {settled} | " + " | ".join(cells) + " |")
    return "\n".join(out) + "\n"


def as_json(world, steps, account):
    return {
        "sampler": account,
        "steps": [
            {
                "number": step.number,
                "slug": step.slug,
                "chapter": step.chapter,
                "text": step.text,
                "act": step.wants.get("act", ""),
                "judged": judged(step),
                "began": step.began,
                "milliseconds": (step.ended or step.began) - step.began,
                "moved": {str(window): list(value) for window, value in step.moved.items()},
                "findings": [
                    dict(finding, window=world.name(finding["window"]) if finding["window"] is not None else None)
                    for finding in step.findings
                ],
            }
            for step in steps
        ],
    }


def clock(time):
    return datetime.datetime.fromtimestamp(time / 1000, datetime.timezone.utc).strftime("%H:%M:%S.%f")[:-3]


def story(path, world, steps, number, logs):
    """What the screen showed during a step and what the logs say about the same time, in order."""
    index = next((index for index, step in enumerate(steps) if step.number == number), None)
    if index is None:
        return f"there is no step {number}\n"
    step = steps[index]
    until = steps[index + 1].began if index + 1 < len(steps) else step.began + 60000
    lines = []
    with open(path, encoding="utf-8", errors="replace") as samples:
        for line in samples:
            parts = line.rstrip("\n").split(" ")
            if len(parts) < 2 or not parts[0].isdigit() or not step.began <= int(parts[0]) < until:
                continue
            time, kind, rest = int(parts[0]), parts[1], parts[2:]
            if kind == "W" and len(rest) >= 7:
                if int(rest[2]) != 0 and int(rest[1]) not in world.arbors:
                    continue
                level = "" if int(rest[2]) == 0 else f" (level {rest[2]})"
                said = f"{world.name(int(rest[0]))} {words(tuple(float(number) for number in rest[3:7]))}{level}"
            elif kind == "G" and rest:
                if world.layers.get(int(rest[0])) != 0 and world.pids.get(int(rest[0])) not in world.arbors:
                    continue
                said = f"{world.name(int(rest[0]))} left the screen"
            elif kind == "Z":
                said = "front to back: " + " ".join(world.labels.get(int(word), "w" + word) for word in rest[0].split(",") if word)
            elif kind == "A":
                said = "in front: process " + " ".join(rest)
            elif kind == "B":
                said = "the button is " + " ".join(rest)
            elif kind == "L":
                said = f"(nothing was seen for {rest[0]} ms)"
            elif kind == "M":
                said = "-- " + " ".join(rest)
            else:
                continue
            lines.append((time, 0, f"{clock(time)} SCREEN {said}"))
    for log in logs:
        try:
            with open(log, encoding="utf-8", errors="replace") as handle:
                for line in handle:
                    stamp, _, said = line.rstrip("\n").partition(" ")
                    try:
                        when = datetime.datetime.strptime(stamp, "%Y-%m-%dT%H:%M:%S.%fZ").replace(tzinfo=datetime.timezone.utc)
                    except ValueError:
                        continue
                    time = round(when.timestamp() * 1000)
                    if step.began <= time < until:
                        lines.append((time, 1, f"{clock(time)} {said}"))
        except OSError:
            continue
    head = [f"{step.number} {step.slug}: {step.text}", f"expected: {step.wants}"]
    for finding in step.findings:
        who = world.name(finding["window"]) + " " if finding["window"] is not None else ""
        head.append(f"{finding['level']} rule {finding['rule']}: {who}{finding['what']}")
    return "\n".join(head + [""] + [line for _, _, line in sorted(lines, key=lambda entry: entry[:2])]) + "\n"


# MARK: Self-test


def self_test():
    import os
    import tempfile

    failures = []

    def play(lines):
        with tempfile.NamedTemporaryFile("w", suffix=".log", delete=False, encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
        try:
            return read(handle.name)
        finally:
            os.unlink(handle.name)

    def expect(name, lines, wanted):
        _, steps, _ = play(lines)
        got = sorted({(finding["rule"], finding["level"]) for step in steps for finding in step.findings})
        if got != sorted(wanted):
            failures.append(f"{name}: expected {sorted(wanted)}, got {got}: " + "; ".join(
                finding["what"] for step in steps for finding in step.findings))

    start = [
        "1000 V 0 30 1000 700", "1000 D 0 0 1000 800", "1000 A 10 app.one",
        "1000 W 1 10 0 100 100 400 300 One", "1000 W 2 20 0 500 100 400 300 Two", "1000 W 9 99 0 0 0 50 50 Arbor",
        "1000 Z 1,2", "1000 M arbor 99", "1000 M label 1 one", "1000 M label 2 two",
        "1100 M begin 1 start", "1200 M end 1 own=all",
    ]
    expect("nothing happens", start + ["2000 M begin 2 idle", "3000 M end 2"], [])
    expect("one move of the named window", start + [
        "2000 M begin 2 dock", "2100 W 1 10 0 0 30 500 700 One", "3000 M end 2 moves=1 front=1"], [])
    expect("size first, place a moment later: one move", start + [
        "2000 M begin 2 dock", "2100 W 1 10 0 100 100 500 700 One", "2116 W 1 10 0 0 30 500 700 One", "3000 M end 2 moves=1"], [])
    expect("a smooth glide is one move", start + ["2000 M begin 2 dock"] + [
        f"{2100 + 16 * i} W 1 10 0 {100 - 10 * i} 100 400 300 One" for i in range(1, 11)] + ["3000 M end 2 moves=1"], [])
    expect("an unnamed window moves", start + [
        "2000 M begin 2 dock", "2100 W 2 20 0 600 100 400 300 Two", "3000 M end 2 moves=1"], [("2", "FAIL")])
    expect("an unnamed window moves and comes back", start + [
        "2000 M begin 2 dock", "2100 W 2 20 0 600 100 400 300 Two", "2150 W 2 20 0 500 100 400 300 Two", "3000 M end 2 moves=1"],
        [("2", "FAIL")])
    expect("a floating window gives way to the one that is docked where it lay", start + [
        "2000 M begin 2 dock", "2100 W 1 10 0 400 30 600 700 One", "2110 W 2 20 0 0 100 400 300 Two", "3000 M end 2 moves=1 yields=2"], [])
    expect("a floating window that lay elsewhere has nothing to give way to", start + [
        "2000 M begin 2 dock", "2100 W 1 10 0 0 30 450 700 One", "2110 W 2 20 0 550 100 400 300 Two", "3000 M end 2 moves=1 yields=2"],
        [("2", "FAIL")])
    expect("Arbor's own panels are no windows", start + [
        "2000 M begin 2 dock", "2100 W 9 99 0 10 10 50 50 Arbor", "3000 M end 2"], [])
    expect("two moves", start + [
        "2000 M begin 2 dock", "2100 W 1 10 0 0 30 500 700 One", "2600 W 1 10 0 0 30 480 700 One", "3700 M end 2 moves=1"],
        [("3", "FAIL")])
    expect("elsewhere first", start + [
        "2000 M begin 2 dock", "2100 W 1 10 0 600 30 400 300 One", "2140 W 1 10 0 0 30 400 300 One", "3000 M end 2 moves=1"],
        [("3", "FAIL")])
    expect("a flash during a move of the camera", start + [
        "2000 M begin 2 zoom", "2100 W 2 20 0 999 799 400 300 Two", "2140 W 2 20 0 500 100 400 300 Two",
        "2180 W 2 20 0 999 799 400 300 Two", "3000 M end 2 moves=any"], [("3", "FAIL")])
    expect("a late move counts for the step before", start + [
        "2000 M begin 2 dock", "2100 W 1 10 0 0 30 500 700 One", "3200 M end 2 moves=1", "3300 W 1 10 0 0 30 490 700 One",
        "3400 M begin 3 idle", "4400 M end 3"], [("3", "FAIL"), ("3", "ODD")])
    expect("behind another window", start + [
        "2000 M begin 2 switch", "2100 A 20 app.two", "3000 M end 2 front=2"], [("4", "FAIL")])
    expect("in front, but its app is not", start + [
        "2000 M begin 2 switch", "2100 Z 2,1", "3000 M end 2 front=2"], [("4", "FAIL")])
    expect("in front", start + [
        "2000 M begin 2 switch", "2100 Z 2,1", "2100 A 20 app.two", "3000 M end 2 front=2"], [])
    expect("in front, but out of view", start + [
        "2000 M begin 2 switch", "2100 Z 2,1", "2100 A 20 app.two", "2100 W 2 20 0 999 729 400 300 Two",
        "3000 M end 2 front=2 moves=any"], [("4", "FAIL")])
    docked = start + ["2000 M begin 2 dock", "2100 W 1 10 0 0 30 500 700 One", "3000 M end 2 moves=1"]
    expect("the size does not come back", docked + [
        "4000 M begin 3 quit", "4100 W 1 10 0 100 100 500 700 One", "5000 M end 3 moves=any restores=all"], [("5", "FAIL")])
    expect("the size comes back, the place does not", docked + [
        "4000 M begin 3 quit", "4100 W 1 10 0 120 100 400 300 One", "5000 M end 3 moves=any restores=all places=1"],
        [("5", "FAIL")])
    expect("everything comes back", docked + [
        "4000 M begin 3 quit", "4100 W 1 10 0 100 100 400 300 One", "5000 M end 3 moves=any restores=all places=1 everything=1"], [])
    expect("a window stays out of view", docked + [
        "4000 M begin 3 quit", "4100 W 2 20 0 999 799 400 300 Two", "5000 M end 3 moves=any everything=1"], [("L", "FAIL")])
    expect("a window leaves the screen", start + ["2000 M begin 2 idle", "2100 G 2", "2100 Z 1", "3000 M end 2"], [("L", "FAIL")])
    expect("a window is closed", start + ["2000 M begin 2 close", "2100 G 2", "2100 Z 1", "3000 M end 2 leaves=2"], [])
    expect("a hidden window comes back elsewhere", start + [
        "2000 M begin 2 hide", "2100 G 2", "3000 M end 2 leaves=2",
        "4000 M begin 3 unhide", "4100 W 2 20 0 300 100 400 300 Two", "5000 M end 3 comes=2 returns=1"], [("2", "FAIL")])
    expect("there and back", docked + [
        "4000 M begin 3 zoom", "4100 W 2 20 0 999 799 400 300 Two", "5000 M end 3 moves=any",
        "6000 M begin 4 back", "6100 W 2 20 0 500 100 400 300 Two", "7000 M end 4 moves=any returns=2"], [])
    expect("there and not quite back", docked + [
        "4000 M begin 3 zoom", "4100 W 2 20 0 999 799 400 300 Two", "5000 M end 3 moves=any",
        "6000 M begin 4 back", "6100 W 2 20 0 520 100 400 300 Two", "7000 M end 4 moves=any returns=2"], [("2", "FAIL")])
    drag = start + ["2000 M begin 2 drag", "2050 B down 300 110"] + [
        f"{2100 + 16 * i} W 1 10 0 {100 + (-1) ** i * 20 * i} 100 400 300 One" for i in range(1, 9)]
    expect("in the hand a window goes where the hand goes", drag + [
        "2300 B up 10 110", "2320 W 1 10 0 0 30 500 700 One", "3400 M end 2 drags=1"], [])
    expect("after the drop it moves once", drag + [
        "2300 B up 10 110", "2320 W 1 10 0 0 30 500 700 One", "2800 W 1 10 0 0 30 480 700 One", "3900 M end 2 drags=1"],
        [("3", "FAIL")])
    expect("a new window stays where it opened", start + [
        "2000 M begin 2 new", "2100 W 3 10 0 200 200 400 300 One", "2100 Z 3,1,2", "3000 M end 2"], [])
    expect("a new window is moved after it opened", start + [
        "2000 M begin 2 new", "2100 W 3 10 0 200 200 400 300 One", "2100 Z 3,1,2", "2300 W 3 10 0 0 30 400 300 One",
        "3000 M end 2"], [("3", "FAIL")])
    expect("before Arbor runs nothing is judged", start + [
        "2000 M begin 2 open", "2100 W 2 20 0 600 100 400 300 Two", "2600 W 2 20 0 500 100 400 300 Two", "2700 G 1",
        "3700 M end 2 judge=no"], [])
    expect("what the script found", start + [
        "2000 M begin 2 idle", "2500 M finding 2 - FAIL Arbor believes otherwise", "3000 M end 2"], [("-", "FAIL")])
    expect("a step that never ended", start + ["2000 M begin 2 idle"], [("-", "FAIL")])

    world, steps, account = play(docked + ["5000 S samples 10 seconds 1.0"])
    text = report(world, steps, account)
    for needle in ("| 2 | dock |", "one ×1 (1, 0 ms)", "samples 10"):
        if needle not in text:
            failures.append(f"the report lacks {needle!r}")
    told = as_json(world, steps, account)
    json.dumps(told)
    if [(step["act"], step["judged"]) for step in told["steps"]] != [("", True), ("", True)]:
        failures.append("the JSON does not say which steps were judged")
    _, blind, _ = play(start + ["2000 M begin 2 dock", "2400 L 400", "3000 M end 2 act=dock-key"])
    if judged(blind[1]) or not judged(blind[0]):
        failures.append("a step during which the sampler was blind for 400 ms must not be judged")
    with tempfile.TemporaryDirectory() as folder:
        samples, log = os.path.join(folder, "samples.log"), os.path.join(folder, "arbor.log")
        with open(samples, "w", encoding="utf-8") as handle:
            handle.write("\n".join(docked) + "\n")
        with open(log, "w", encoding="utf-8") as handle:
            handle.write("1970-01-01T00:00:01.500Z DEBUG too early\n1970-01-01T00:00:02.050Z DEBUG dock 1 left\n")
        world, steps, _ = read(samples)
        told = story(samples, world, steps, 2, [log])
        if "too early" in told or told.find("DEBUG dock 1 left") > told.find("one (w1) 0,30 500×700") or "dock 1 left" not in told:
            failures.append(f"the story is out of order or has too much in it:\n{told}")

    for failure in failures:
        print(f"✘ {failure}")
    print(f"jolts.py: {'all situations are told apart' if not failures else '%d failed' % len(failures)}")
    return 1 if failures else 0


def main(arguments):
    if arguments == ["--self-test"]:
        return self_test()
    if len(arguments) < 2:
        print(__doc__)
        return 64
    command, path, rest = arguments[0], arguments[1], arguments[2:]
    world, steps, account = read(path)
    if command == "report":
        print(report(world, steps, account), end="")
        if len(rest) == 2 and rest[0] == "--json":
            with open(rest[1], "w", encoding="utf-8") as handle:
                json.dump(as_json(world, steps, account), handle, indent=1, ensure_ascii=False)
        return 1 if any(fails(step) for step in steps) else 0
    if command == "failing":
        for step in steps:
            if step.findings:
                print(step.number)
        return 0
    if command == "story" and rest and rest[0].isdigit():
        print(story(path, world, steps, int(rest[0]), rest[1:]), end="")
        return 0
    if command == "trace" and rest:
        for step in steps:
            if str(step.number) != rest[0]:
                continue
            print(f"{step.number} {step.slug}: {step.text}; {step.wants}")
            for window, trace in sorted(step.traces.items()):
                if len(rest) > 1 and str(window) != rest[1].lstrip("w"):
                    continue
                if len(trace) > 1 or len(rest) > 1:
                    print(f"  {world.name(window)}")
                    for time, frame, held in trace:
                        print(f"    +{time - step.began} ms {words(frame) if frame else 'off the screen'}{' (button down)' if held else ''}")
        return 0
    print(__doc__)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
