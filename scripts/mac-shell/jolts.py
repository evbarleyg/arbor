#!/usr/bin/env python3
"""The jolt detector: reads what sampler.swift wrote while a script played, and says what a person would have seen.

For every step of the script: which windows moved, how many times each moved and by which road, whether a window moved
that the step did not name, whether the window switched to ended in front and wholly in view, whether sizes came back,
whether a window was lost. The rules are the product's (docs/TESTING.md, "An ordinary day"):

  1  never fight macOS: where its own tiling answers a drag, Arbor stands aside
  2  nothing moves that the person did not move
  3  no jolts: a window moves once, to where it ends up
  4  the window you switch to comes to the front and into view
  5  quitting, Float All and pause give windows their own earlier sizes back
  6  drags never block input: what a person presses reaches the apps, at once
  L  no window is lost: none leaves the screen or ends out of view unless the step says so

Every finding also names its detector, by the names docs/VIABLE.md gives them: fought, moved-unasked, jolt, pulled, flash, stuck, slow, behind, focus, size-lost, input-held, lost; crash, busy, left-behind and told, which the
script finds out and hands on; and script for whatever else it checked.

  jolts.py report <samples> [--json <file>] [--control <findings of the run without Arbor>]
                                              the findings per rule, each with the step that shows it, then every step.
                                              Exit code 1 when a rule was broken, 0 when none was.
                                              A `witness.log` beside the samples (witness.swift log) is read with them: how late each press, release
                                              and key reached the far end of the event taps. With --control, that run's lateness is the measure
  jolts.py failing <samples>                  the numbers of the steps with a finding, one per line
  jolts.py sabotage <samples>                 for a run in which the script itself commits offences (`offence=`): does every detector report
                                              its own offence, that one alone, and nothing where none was committed? Exit code 1 if not
  jolts.py trace <samples> <step> [window]    every frame seen during that step
  jolts.py stories <samples> <folder> [log…]  the story of every step with a finding, as <folder>/<nnn>-<slug>.story.log; prints those steps' numbers
  jolts.py story <samples> <step> [log…]      one timeline of that step: what the screen showed, and the lines of those logs
                                              (arbor.log, `apptool watch`) that were written meanwhile
  jolts.py --self-test

The script says what it is doing in marks (lib-day.sh writes them):

  label <id> <name>        what to call a window in the report (never its title)
  arbor <pid>              Arbor's process, whose own panels are not windows for these rules
  chapter <title>
  begin <n> <slug>         a step begins: one thing a person does
  text <n> <words…>        what the person does, for the report
  finding <n> <rule> <FAIL|ODD> <words…>      something the script itself found out during the step. `-` for the rule, or `-:<detector>` for what only the
                           script can see: crash, busy, left-behind, told
  end <n> [key=value…]     things have settled, and this should hold:
    act=<kind>             what kind of thing the person did (docs/VIABLE.md lists the kinds), for the count
    moves=<ids>|any|none   the windows the step may move (default none)
    drags=<id>             the person drags this one: while the button is down it goes where the pointer goes
    zooms=<id>             the person double-clicks its title bar, which macOS answers: it may move, once, and whoever moves it again is fighting macOS
    front=<id>             it ends in front of every other window, its app in front, wholly in view
    leaves=<ids>|any       these may leave the screen (closed, hidden, minimized, another Space)
    comes=<ids>            these are on the screen at the end
    own=<ids>|all          where these are now is where the person wants them: the size and the place to give back later
    place=<ids>            the person moved these: the place is theirs from now on, the size to give back is what it was
    restores=<ids>|all     these have their own sizes back; places=1: their places too, as after Float All and Quit
    everything=1           no window may be out of view
    tiles=<id>@x:y:w:h,…   with everything=1, after Show Everything alone: for these windows a tile of Arbor's stands in, there. It counts as in view if a
                           panel of Arbor's is seen at that frame. keyboard=<id>: the window that has the keyboard, which is never one of them
    first=1                Arbor's first act of its own since it started
    returns=<n>            every window is where it was at the end of step n
    floating=<ids>         for the report: these float, so no arrangement explains a move of theirs
    docked=<ids>           these are docked at the end
    offence=<detector>     the script committed this offence itself during the step, to see whether it is found (`jolts.py sabotage`)
    judge=no               nothing is judged: Arbor is not running yet, and apps place their own windows as they open
    settled=<quiet|restless>:<ms>

What happens between a step's end and the next step's beginning counts for the step that ended: it came late.
"""

import datetime
import json
import os
import sys

# Two changes of one window further apart than this are two moves to a person, not one.
EPISODE_GAP = 250
# Points a window may travel beyond the straight road, per coordinate, before it counts as having gone elsewhere first.
EXCESS = 6
# AppKit lets a window pop or slide open: for this long after it first shows, within this many points or this share of its size (it
# grows from some 95 %), it is still opening.
OPENING = 600
OPENING_REACH = 24
OPENING_SHARE = 0.08
# A step during which the sampler saw nothing for longer than this does not count as judged: it may have missed something. What it did see
# stands, because a gap can hide a move and cannot make one up.
BLIND = 250
# A window Arbor moves is at rest this long after the key or the drop: later is worth a look, much later is a failure.
SLOW_ODD = 700
SLOW = 1500
# The first act after Arbor has started may take this long (odd from what is a failure otherwise).
SLOW_FIRST = 3000
# An oddity that explains itself: a sheet or a dialog of a window that was moved in the same step.
FOLLOWS = "follows its window"
# The acts that are answered by Arbor alone, so that how long the answer takes is Arbor's doing.
ARBORS_OWN = {"dock-key", "view", "resize", "way-out", "drag", "tile-click"}
# The acts during which the app in front has no reason to change.
NO_SWITCH = {"idle", "dock-key", "resize"}
# From one sample to the next a dragged window may move this many points further than the pointer did: it lags, and makes up for it (18 points
# were seen with nobody pulling). Whoever sets its frame sends it much further.
PULLED = 40
# Over the drag so far it may be that far ahead of the pointer's travel, and this far behind: macOS holds it back (49 points were seen, 40 under the menu bar).
BEHIND = 150
# The pointer's road is looked at from this long before the first of the two samples to this long after the second: window and pointer are not read at one moment.
SKEW = (150, 60)
# macOS gives a window it had tiled its size back under the hand, in a motion of its own that shifts the origin too. Nothing is made of a move this soon after.
RESIZING = 300
# After a drop a window is where it was let go, or where the preview was, to within this many points (a gap, a size its app rounds).
DROPPED = 24
# The button is up for the apps this many microseconds after it came up, at the latest.
HELD = 50000
# Of a hundred events that are not Arbor's own, the latest but one reaches the apps at most this many microseconds later than without Arbor.
HELD_MORE = 10000
# Less of a window than this on the display is its parking strip; more than that, and it shows.
STRIP = 0.03
SHOWS = 0.05
# Points that are no move at all: apps round sizes, and Retina screens deal in halves.
SAME = 2
DETECTORS = {"6": "input-held", "1": "fought", "2": "moved-unasked", "3": "jolt", "4": "focus", "5": "size-lost", "L": "lost", "-": "script"}
RULES = [
    ("1", "never fight macOS: where it answers a drag, Arbor stands aside"),
    ("2", "nothing moves that the person did not move"),
    ("3", "no jolts: a window moves once, to where it ends up"),
    ("4", "the window you switch to comes to the front and into view"),
    ("5", "quitting, Float All and pause give windows their own sizes back"),
    ("6", "what a person presses reaches the apps, at once"),
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


def showing(frame, displays):
    """The share of a window that is on some display. Displays do not overlap."""
    return sum(shared(frame, display) for display in displays) / max(frame[2] * frame[3], 1)


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
        self.app_before = None
        # When a key went down or the button changed.
        self.inputs = []
        # Where the pointer was while the button was down: (time, x, y).
        self.pointer = []
        # During a drag: macOS's tiling preview was up when the button came up; Arbor's and macOS's previews were up together.
        self.macos_answered = False
        self.both_previews = False
        self.arbor_previewed = False
        self.stages_up = {}
        self.all_displays = []
        self.under_the_stage = 0
        # Where Arbor's drop preview was when the button came up, if it was up.
        self.preview_at_drop = None
        # What reached the far end of the event taps: (time, kind, microseconds late, whether Arbor posted it).
        self.arrived = []
        self.at_end = None
        self.findings = []
        self.moved = {}

    def stage_went_up(self, stage, time, display):
        self.stages_up[stage] = (time, display)

    def stage_came_down(self, stage, time):
        """Under the stage the real windows go to their places where nobody sees them. A person sees each where the stage found it, and
        then, when the stage comes down, where it is by then. What the stand-ins do meanwhile is on the film, not in the samples."""
        since, display = self.stages_up.pop(stage, (None, None))
        if since is None:
            return
        for window, trace in self.traces.items():
            hidden = [index for index, entry in enumerate(trace) if entry[0] >= since and index > 0]
            # Each display has a stage of its own, which hides what is on that display. What shows on another display meanwhile is seen.
            frames = [trace[index][1] for index in [hidden[0] - 1] + hidden if trace[index][1]] if hidden else []
            if hidden and all(showing(frame, self.other_displays(display)) <= STRIP for frame in frames):
                last = trace[hidden[-1]]
                del trace[hidden[0]:]
                trace.append((time, last[1], last[2]))
        self.under_the_stage += 1

    def other_displays(self, display):
        return [other for other in self.all_displays if other != display]

    def find(self, rule, level, window, what, trace=None, detector=None, explained=None):
        self.findings.append({
            "rule": rule, "detector": detector or DETECTORS[rule], "level": level, "window": window, "what": what, "trace": trace})
        if explained:
            self.findings[-1]["explained"] = explained


class World:
    """The screen as the samples tell it."""

    def __init__(self):
        self.frames = {}
        self.seen = set()
        self.pids = {}
        self.owners = {}
        self.layers = {}
        self.order = []
        self.app = None
        self.visible = None
        self.display = None
        # The displays besides the main one: id -> (frame, the part between its menu bar and the Dock).
        self.others = {}
        self.button = False
        self.arbors = set()
        # The previews that are up: macOS's own (windows of WindowManager's) and Arbor's (its panels at level 3).
        self.macos_previews = set()
        self.arbor_previews = set()
        self.macos_preview_left = 0
        self.arbor_preview_last = (0, None)
        # Arbor's stage, while it is up: a panel at level 4 over the whole display that shows a picture of the desktop and a stand-in for each window.
        self.stages = set()
        self.stage_seen = False
        self.labels = {}

    def displays(self):
        return ([self.display] if self.display else []) + [frame for frame, _ in self.others.values()]

    def ordinary(self, window):
        return (self.layers.get(window) == 0 and self.pids.get(window) not in self.arbors
                and not self.owners.get(window, "").startswith("WindowManager"))

    def name(self, window):
        if window in self.labels:
            return f"{self.labels[window]} (w{window})"
        return f"w{window} of {self.owners.get(window, '?')}"

    def snapshot(self):
        return {
            "frames": {window: frame for window, frame in self.frames.items() if self.ordinary(window)},
            # A mark can fall between the lines of one sample: a window that has gone may still be in the pile.
            "order": [window for window in self.order if self.ordinary(window) and window in self.frames],
            "arbors": [frame for window, frame in self.frames.items() if self.pids.get(window) in self.arbors],
            "app": self.app,
            "visible": self.visible,
            "displays": ([self.display] if self.display else []) + [frame for frame, _ in self.others.values()],
            "visibles": ([self.visible] if self.visible else []) + [visible for _, visible in self.others.values()],
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
    # The script learns Arbor's process id a moment after Arbor has put up its first panel.
    with open(path, encoding="utf-8", errors="replace") as lines:
        for line in lines:
            parts = line.split()
            if len(parts) == 4 and parts[1:3] == ["M", "arbor"] and parts[3].isdigit():
                world.arbors.add(int(parts[3]))
    with open(path, encoding="utf-8", errors="replace") as lines:
        for line in lines:
            parts = line.rstrip("\n").split(" ")
            if len(parts) < 2 or not parts[0].isdigit():
                continue
            time, kind, rest = int(parts[0]), parts[1], parts[2:]
            if kind == "W" and len(rest) >= 7:
                window = int(rest[0])
                frame = tuple(float(number) for number in rest[3:7])
                known = window in world.seen
                showing = window in world.frames
                world.pids[window], world.layers[window] = int(rest[1]), int(rest[2])
                world.owners[window] = " ".join(rest[7:]).replace("_", " ")
                world.frames[window] = frame
                world.seen.add(window)
                covered = [display for display in world.displays() if shared(frame, display) >= 0.95 * display[2] * display[3]]
                if world.pids[window] in world.arbors and world.layers[window] == 4 and covered:
                    if window not in world.stages and current:
                        current.all_displays = world.displays()
                        current.stage_went_up(window, time, covered[0])
                    world.stages.add(window)
                    world.stage_seen = True
                if world.owners[window] == "WindowManager" and world.layers[window] == 0:
                    world.macos_previews.add(window)
                elif world.pids[window] in world.arbors and world.layers[window] == 3 and world.button and not showing:
                    # Other panels of Arbor's float at that level too. The preview is the one that comes up while the button is down, as
                    # often as the drag passes a place to drop: it is one panel, put away and brought out again.
                    world.arbor_previews.add(window)
                    if current:
                        current.arbor_previewed = True
                if current and world.button and world.macos_previews and world.arbor_previews:
                    current.both_previews = True
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
                world.gone_frame = world.frames.pop(window, None)
                if window in world.stages:
                    world.stages.discard(window)
                    if current:
                        current.stage_came_down(window, time)
                if window in world.arbor_previews:
                    world.arbor_preview_last = (time, world.gone_frame)
                if window in world.macos_previews:
                    world.macos_preview_left = time
                world.macos_previews.discard(window)
                world.arbor_previews.discard(window)
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
                if current:
                    current.inputs.append(time)
                    if len(rest) >= 3:
                        current.pointer.append((time, float(rest[1]), float(rest[2])))
                    if not world.button:
                        # It goes with the button, and within one sample its going is written first.
                        current.macos_answered = bool(world.macos_previews) or time - world.macos_preview_left <= 150
                        up = [world.frames[preview] for preview in world.arbor_previews if preview in world.frames]
                        if up:
                            current.preview_at_drop = up[0]
                        elif time - world.arbor_preview_last[0] <= 150:
                            current.preview_at_drop = world.arbor_preview_last[1]
            elif kind == "P" and len(rest) >= 2:
                if current:
                    current.pointer.append((time, float(rest[0]), float(rest[1])))
            elif kind == "K":
                if current:
                    current.inputs.append(time)
            elif kind == "V" and len(rest) == 4:
                world.visible = tuple(float(number) for number in rest)
            elif kind == "D" and len(rest) == 4:
                world.display = tuple(float(number) for number in rest)
            elif kind == "Y" and rest:
                if len(rest) == 9:
                    numbers = tuple(float(number) for number in rest[1:])
                    world.others[rest[0]] = (numbers[:4], numbers[4:])
                else:
                    world.others.pop(rest[0], None)
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
                    current.app_before = world.app
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
                    rule, _, detector = rest[1].partition(":")
                    by_number[int(rest[0])].find(rule if rule in DETECTORS else "-", rest[2], None, " ".join(rest[3:]), None, detector or None)
                elif verb == "end" and rest and int(rest[0]) in by_number:
                    step = by_number[int(rest[0])]
                    step.ended = time
                    step.wants = dict(word.split("=", 1) for word in rest[1:] if "=" in word)
                    step.at_end = world.snapshot()
    world.witnessed = hear(os.path.join(os.path.dirname(os.path.abspath(path)), "witness.log"), steps)
    for step in steps:
        judge(step, world, by_number, own)
    return world, steps, account


def hear(path, steps):
    """Hands each step what the witness saw arrive during it. Whether there was a witness at all."""
    if not os.path.exists(path):
        return False
    index = 0
    with open(path, encoding="utf-8", errors="replace") as lines:
        for line in lines:
            parts = line.split()
            if len(parts) != 5 or parts[1] != "E" or not parts[0].isdigit() or not parts[3].lstrip("-").isdigit():
                continue
            time = int(parts[0])
            while index + 1 < len(steps) and steps[index + 1].began <= time:
                index += 1
            if steps and steps[index].began <= time:
                steps[index].arrived.append((time, parts[2], int(parts[3]), parts[4] == "arbor"))
    return True


def lateness(steps):
    """How late the events that are not Arbor's own reached the apps, over the steps that are judged: how many, the middle one, the latest but one in a hundred, the latest."""
    late = sorted(delay for step in steps if step.wants.get("judge") != "no" for _, _, delay, arbors in step.arrived if not arbors)
    if not late:
        return None
    return {"events": len(late), "p50_us": late[len(late) // 2], "p99_us": late[min(len(late) - 1, len(late) * 99 // 100)], "max_us": late[-1]}


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
    for window in ids(step.wants.get("place", "")):
        if window in frames and window in own:
            own[window] = frames[window][:2] + own[window][2:]


def macos_tiles(area):
    """Where macOS itself puts a window that is dragged to an edge or a corner: all of the space between the menu bar and the Dock, its halves, its quarters."""
    x, y, width, height = area
    columns = [(x, width), (x, width / 2), (x + width / 2, width / 2)]
    rows = [(y, height), (y, height / 2), (y + height / 2, height / 2)]
    return [(left, top, wide, high) for left, wide in columns for top, high in rows]


def pulled(held, pointer):
    """The most a dragged window moved beyond what the pointer moved meanwhile, and when.

    Not how far it is from where the pointer would carry it: macOS itself holds a dragged window back, under the menu bar and where its edge meets another
    window's, and it does not catch up (49 points behind at the end of a drag of 130, with no Arbor running). But it never runs ahead."""
    worst, when, resized = 0, None, None
    for (before, old, _), (time, new, _) in zip(held, held[1:]):
        if differs(old[2:], new[2:], by=0.6):
            # Its size changes under the hand, which has a finding of its own, and its origin with it.
            resized = time
        if resized is not None and time - resized < RESIZING:
            continue
        near = [(x, y) for at, x, y in pointer if before - SKEW[0] <= at <= time + SKEW[1]]
        for axis in (0, 1):
            went = max(point[axis] for point in near) - min(point[axis] for point in near) if near else 0
            beyond = abs(new[axis] - old[axis]) - went
            if beyond > worst:
                worst, when = beyond, time
    return worst, when


def adrift(held, pointer):
    """Over the drag so far: the most the window was ahead of the pointer's travel, and the most it was behind. A slow glide out of the hand, or a window that is put
    back at every move, adds up, however seldom anybody looks."""
    ahead = behind = 0
    taken = resized = None
    for (_, old, _), (time, new, _) in zip(held, held[1:]):
        if differs(old[2:], new[2:], by=0.6):
            taken, resized = None, time
        if resized is not None and time - resized < RESIZING:
            continue
        near = [(x, y) for at, x, y in pointer if time - SKEW[0] <= at <= time + SKEW[1]] or [(x, y) for at, x, y in pointer if at <= time][-1:]
        if not near:
            continue
        if taken is None:
            # Where it was taken hold of; and anew once its size has kept still after a change under the hand.
            taken = (new, ([(x, y) for at, x, y in pointer if at <= time] or near)[-1])
            continue
        for axis in (0, 1):
            moved = new[axis] - taken[0][axis]
            travel = [point[axis] - taken[1][axis] for point in near]
            if min(travel) <= moved <= max(travel):
                continue
            nearest = min(travel, key=lambda went: abs(went - moved))
            # Further than the hand in the hand's own direction, or anywhere at all with the hand at rest or going the other way.
            if abs(moved) > abs(nearest) and moved * nearest >= 0 or moved * nearest < 0:
                ahead = max(ahead, abs(moved - nearest))
            else:
                behind = max(behind, abs(moved - nearest))
    return ahead, behind


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
    # What is said to go or to come is named by that.
    named |= ids(may_leave) | ids(wants.get("comes", "")) | ids(wants.get("zooms", ""))
    kin = {world.pids.get(window) for window in named | dragged}
    screens = (end or {}).get("displays") or world.displays()
    if wants.get("act") in ("switch", "tile-click") and screens:
        # To bring a window into view that is out of view, the view has to move.
        for window in ids(wants.get("front", "")):
            first = (step.traces.get(window) or [(0, None, False)])[0][1]
            if first is None or showing(first, screens) < 0.5:
                may = "any"
    for window, trace in sorted(step.traces.items()):
        if window in dragged:
            # In the hand it goes where the hand goes. What counts is what happens to its size meanwhile, and everything after.
            held = [entry for entry in trace if entry[2] and entry[1]]
            if any(differs(a[1][2:], b[1][2:]) for a, b in zip(held, held[1:])):
                step.find("3", "ODD", window, "changed its size while it was being dragged", road(held))
            away, when = pulled(held, step.pointer)
            if away > PULLED:
                step.find("3", "FAIL", window, f"moved {round(away)} points further than the pointer did, {when - step.began} ms into the step", road(held), "pulled")
            else:
                ahead, behind = adrift(held, step.pointer)
                if ahead > PULLED or behind > BEHIND:
                    step.find("3", "FAIL", window, f"was {round(ahead)} points ahead of the pointer's travel and {round(behind)} behind it at the most", road(held), "pulled")
            # The sampler can miss a preview. A window that ends in a tile of macOS's own was tiled by macOS all the same.
            final = trace[-1][1] if trace else None
            area = (end or {}).get("visible") or world.visible
            if not step.macos_answered and final and area and any(not differs(final, tile, by=4) for tile in macos_tiles(area)):
                step.macos_answered = True
            if step.both_previews:
                step.find("1", "FAIL", window, "macOS's tiling preview and Arbor's drop preview were up at the same time")
            elif step.macos_answered and step.arbor_previewed:
                step.find("1", "FAIL", window, "macOS answered the drag, and Arbor's drop preview had been up during it: one after the other is both reacting")
            if step.macos_answered and window in ids(wants.get("docked", "")):
                step.find("1", "FAIL", window, "macOS's tiling preview was up when it was let go, and Arbor docked it")
            elif step.macos_answered and measure(trace[max((index for index, entry in enumerate(trace) if entry[2]), default=0):])[0] > 1:
                step.find("1", "FAIL", window, "macOS's tiling preview was up when it was let go, macOS tiled it, and it was moved again afterwards")
            last_held = max((index for index, entry in enumerate(trace) if entry[2]), default=0)
            taken = trace[0][1]
            trace = trace[last_held:]
            let_go, ended, drop = trace[0][1], trace[-1][1], step.pointer[-1][1:] if step.pointer else None
            if held and let_go and ended and not step.macos_answered and differs(let_go, ended, by=DROPPED):
                preview = step.preview_at_drop
                in_preview = preview and inside(ended, preview, by=DROPPED)
                # A window that gets its own size back at the drop stays under the pointer by its title bar.
                in_hand = drop and ended[0] <= drop[0] <= ended[0] + ended[2] and ended[1] - 4 <= drop[1] <= ended[1] + 60
                # A drag that is called off: a docked window let go over its own place goes back to it.
                back = taken and not differs(taken, ended, by=DROPPED)
                if not in_preview and not in_hand and not back:
                    step.find("3", "FAIL", window, "ended neither where it was let go nor where the preview was: let go at %s, %s, now at %s" % (
                        words(let_go), "the preview at " + words(preview) if preview else "no preview", words(ended)), road(trace), "stuck")
        if window in step.born and trace and trace[0][1]:
            # Where it has opened is where its app put it.
            opened = 0
            reach = max(OPENING_REACH, OPENING_SHARE * max(trace[0][1][2:]))
            for index, entry in enumerate(trace):
                if not entry[1] or entry[0] - trace[0][0] > OPENING or differs(trace[0][1], entry[1], by=reach):
                    break
                opened = index
            trace = trace[opened:]
        moves, frames, took, detour, elsewhere = measure(trace)
        # macOS shrinks a window into the Dock and lets it grow out of it, by a road of its own.
        if window in ids(may_leave) | ids(wants.get("comes", "")):
            detour = 0
        follows = window not in world.labels and any(
            other != window and world.pids.get(other) == world.pids.get(window) and len(theirs) > 1 and theirs[0][1] and trace and trace[0][1]
            and theirs[0][1][2] * theirs[0][1][3] > trace[0][1][2] * trace[0][1][3]
            for other, theirs in step.traces.items())
        if moves:
            step.moved[window] = (moves, frames, took)
        if moves and may != "any" and window not in named and window not in dragged:
            if window in step.born:
                step.find("3", "FAIL", window, "opened in one place and was then moved to another", road(trace))
            elif follows or (window not in world.labels and world.pids.get(window) in kin):
                step.find("2", "ODD", window, "moved along with a window of its app", road(trace), None, FOLLOWS)
            else:
                kind = "a floating window, " if window in ids(wants.get("floating", "")) else ""
                how = "moved" if elsewhere else "moved and came back"
                step.find("2", "FAIL", window, f"{kind}{how}, and the step did not name it", road(trace))
        shares = [showing(entry[1], screens) for entry in trace if entry[1]] if screens else []
        if len(shares) > 2 and shares[0] < STRIP and shares[-1] < STRIP and max(shares) > SHOWS:
            step.find("3", "FAIL", window, f"is out of view before and after, and {max(shares):.0%} of it showed in between", road(trace), "flash")
        elif moves > 1 and window in ids(wants.get("zooms", "")):
            step.find("1", "FAIL", window, f"macOS answered the double-click on its title bar, and it was moved again afterwards ({moves} moves)", road(trace))
        elif moves > 1:
            step.find("3", "FAIL", window, f"moved {moves} times", road(trace))
        elif detour > EXCESS and (may == "any" or window in named or window in dragged):
            # A sheet or a panel hangs on its window, and goes where that goes at each stage of its move.
            step.find("3", "ODD" if follows else "FAIL", window, f"went {round(detour)} points out of its way before it ended up", road(trace),
                      None, FOLLOWS if follows else None)
        gone = trace and trace[-1][1] is None
        if gone and may_leave != "any" and window not in ids(may_leave) and window in world.labels:
            step.find("L", "FAIL", window, "left the screen, and the step did not say it would", road(trace))
        elif not gone and any(entry[1] is None for entry in trace) and may_leave != "any" and window not in ids(may_leave):
            if window in world.labels:
                step.find("3", "FAIL", window, "left the screen and came back", road(trace), "flash")

    if end is None:
        step.find("-", "FAIL", None, "the step never ended: the script stopped here")
        return
    if step.ended is not None:
        for window, trace in step.traces.items():
            late = [entry for entry in trace if entry[0] > step.ended]
            if late and window in step.moved:
                step.find("3", "ODD", window, f"was still moving {late[-1][0] - step.ended} ms after everything had been quiet for a second")

    if wants.get("act") in ARBORS_OWN and step.moved:
        changes = [entry[0] for window in step.moved for before, entry in zip(step.traces[window], step.traces[window][1:])
                   if entry[1] and before[1] and not entry[2] and differs(before[1], entry[1], by=0.6)]
        asked = max((time for time in step.inputs if changes and time <= min(changes)), default=None)
        if changes and asked is not None:
            took = max(changes) - asked
            first = wants.get("first") == "1"
            if took > (SLOW if first else SLOW_ODD):
                failed = took > (SLOW_FIRST if first else SLOW)
                step.find("3", "FAIL" if failed else "ODD", None,
                          f"the last window came to rest {took} ms after the key or the button" + (", in Arbor's first act since it started" if first else ""), None, "slow",
                          None if failed else "listed, and no reason, until the release build has answered")

    if wants.get("act") in NO_SWITCH and any(app != step.app_before for app in step.apps):
        step.find("4", "FAIL", None, "the app in front changed (to process %s), and nobody switched" % ", ".join(str(app) for app in step.apps))

    for time, kind, delay, _ in step.arrived:
        if kind == "up" and delay > HELD:
            step.find("6", "FAIL", None, f"the button came up, and the apps heard of it {delay // 1000} ms later")

    tops = [top for top in step.tops if top is not None]
    if len(tops) > 3:
        step.find("4", "ODD", None, "the window in front changed %d times: %s" % (len(tops) - 1, " → ".join(world.name(top) for top in tops[:8])))

    frames, order, areas = end["frames"], end["order"], end["visibles"]
    displays = end["displays"] or areas
    for window in sorted(ids(wants.get("front", ""))):
        if window not in frames:
            step.find("4", "FAIL", window, "is not on the screen at all")
            continue
        # A window that is out of view is in nobody's way, wherever it is in the pile.
        ahead = [other for other in (order[: order.index(window)] if window in order else order[:3])
                 if not displays or showing(frames[other], displays) > STRIP]
        if ahead:
            covering = [other for other in ahead if shared(frames[other], frames[window]) > 0]
            step.find(
                "4", "FAIL", window,
                "is not in front: %s ahead of it%s" % (
                    ", ".join(world.name(other) for other in ahead[:4]),
                    ", of which %d cover part of it" % len(covering) if covering else ", none of which covers it"),
                None, "behind")
        if end["app"] is not None and end["app"] != world.pids.get(window):
            step.find("4", "FAIL", window, f"its app is not the one in front (process {end['app']} is)")
        if areas and not any(inside(frames[window], area) for area in areas):
            step.find("4", "FAIL", window, f"is not wholly in view: {showing(frames[window], areas):.0%} of it, at {words(frames[window])} in {' and '.join(words(area) for area in areas)}")

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

    if wants.get("everything") == "1" and displays:
        tiles = {}
        for word in wants.get("tiles", "").split(","):
            window, _, place = word.partition("@")
            if window.isdigit() and place.count(":") == 3:
                tiles[int(window)] = tuple(float(number) for number in place.split(":"))
        for window in sorted(ids(wants.get("keyboard", "")) & set(tiles)):
            step.find("4", "FAIL", window, "has the keyboard, and only a tile of it shows")
        for window, frame in sorted(frames.items()):
            if window not in world.labels:
                continue
            share = showing(frame, displays)
            if share < 0.5 and window in tiles and any(not differs(tiles[window], panel, by=4) for panel in end["arbors"]):
                continue
            if share < 0.5 and not (window in own and showing(own[window], displays) < 0.5):
                step.find("L", "FAIL", window, f"is out of view: {share:.0%} of it is on a display, at {words(frame)}")

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
    if step.at_end is None or wants.get("judge") == "no":
        return False
    return {
        "1": "drags" in wants or "zooms" in wants,
        "2": wants.get("moves", "none") != "any" or "returns" in wants,
        "3": True,
        "4": "front" in wants or wants.get("act") in NO_SWITCH,
        "5": "restores" in wants,
        "6": any(kind == "up" for _, kind, _, _ in step.arrived),
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
    heard = lateness(steps)
    if heard:
        out.append(f"Input: {heard['events']} presses, releases, keys and scrolls reached the apps, half of them within {heard['p50_us']} µs, 99 in 100 within {heard['p99_us']} µs, the latest after {heard['max_us']} µs.")
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
            out.append(f"- {mark} **{step.number} {step.slug}** ({step.text}): {who}{finding['what']} [{finding['detector']}]")
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
            out.append("| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |")
            out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
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
        "input": lateness(steps),
        "stage_seen": world.stage_seen,
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


def sabotage(steps):
    """Every offence found by its own detector and by no other, and nothing found where nothing was done."""
    out, missed = [], 0
    out.append("| # | Step | Offence committed | Reported | |")
    out.append("|---|---|---|---|---|")
    for step in steps:
        if step.wants.get("judge") == "no":
            continue
        committed = step.wants.get("offence", "")
        reported = sorted({finding["detector"] for finding in step.findings if finding["level"] == "FAIL"})
        good = reported == ([committed] if committed else [])
        missed += not good
        out.append(f"| {step.number} | {step.slug} | {committed or 'none'} | {', '.join(reported) or 'nothing'} | {'✔' if good else '✘'} |")
    offences = {step.wants["offence"] for step in steps if step.wants.get("offence")}
    out.append("")
    out.append(f"{len(offences)} kinds of offence committed: {', '.join(sorted(offences))}. "
               + ("Every one was reported by its own detector alone." if not missed else f"{missed} steps were judged wrongly."))
    return "\n".join(out) + "\n", missed


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

    def detectors(name, lines, wanted):
        _, steps, _ = play(lines)
        got = sorted({finding["detector"] for step in steps for finding in step.findings if finding["level"] == "FAIL"})
        if got != sorted(wanted):
            failures.append(f"{name}: expected the detectors {sorted(wanted)}, got {got}")

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
    parked = start + ["1500 M begin 2 zoom", "1600 W 2 20 0 999 799 400 300 Two", "1900 M end 2 moves=any"]
    detectors("a window out of view shows for a moment", parked + [
        "2000 M begin 3 walk", "2140 W 2 20 0 500 100 400 300 Two", "2180 W 2 20 0 999 799 400 300 Two", "3000 M end 3 moves=any"], ["flash"])
    detectors("a window out of view that is moved along its corner shows nothing", parked + [
        "2000 M begin 3 walk", "2140 W 2 20 0 999 790 400 300 Two", "3000 M end 3 moves=any"], [])
    detectors("covered", start + ["2000 M begin 2 switch", "2100 A 20 app.two", "3000 M end 2 front=2"], ["behind"])
    detectors("a window out of view is in nobody's way", parked + [
        "2000 M begin 3 switch", "2100 Z 2,1", "3000 M end 3 front=1"], [])
    detectors("the keyboard is elsewhere", start + ["2000 M begin 2 switch", "2100 Z 2,1", "3000 M end 2 front=2"], ["focus"])
    detectors("an app comes forward by itself", start + ["2000 M begin 2 idle", "2100 A 20 app.two", "3000 M end 2 act=idle"], ["focus"])
    detectors("an app comes forward because somebody switched", start + [
        "2000 M begin 2 switch", "2100 A 20 app.two", "2100 Z 2,1", "3000 M end 2 act=switch front=2"], [])
    detectors("at rest in good time", start + [
        "2000 M begin 2 dock", "2300 K 1", "2500 W 1 10 0 0 30 500 700 One", "3600 M end 2 act=dock-key moves=1"], [])
    detectors("at rest far too late", start + [
        "2000 M begin 2 dock", "2300 K 1", "4000 W 1 10 0 0 30 500 700 One", "5100 M end 2 act=dock-key moves=1"], ["slow"])
    detectors("the first act after a start may take longer", start + [
        "2000 M begin 2 dock", "2300 K 1", "4000 W 1 10 0 0 30 500 700 One", "5100 M end 2 act=dock-key moves=1 first=1"], [])
    detectors("but not for ever", start + [
        "2000 M begin 2 dock", "2300 K 1", "5400 W 1 10 0 0 30 500 700 One", "6500 M end 2 act=dock-key moves=1 first=1"], ["slow"])
    detectors("what macOS takes its time over is not Arbor's", start + [
        "2000 M begin 2 full", "2300 K 1", "4000 W 1 10 0 0 0 1000 800 One", "5100 M end 2 act=macos-own moves=1"], [])
    stage = ["2050 W 70 99 4 0 0 1000 800 Arbor"]
    expect("under the stage a window goes about unseen", start + ["2000 M begin 2 dock"] + stage + [
        "2100 W 1 10 0 600 30 400 300 One", "2140 W 1 10 0 0 30 400 300 One", "2500 W 1 10 0 0 30 500 700 One", "2600 G 70",
        "3700 M end 2 moves=1"], [])
    expect("what it does once the stage is down is seen", start + ["2000 M begin 2 dock"] + stage + [
        "2100 W 1 10 0 0 30 500 700 One", "2600 G 70", "3100 W 1 10 0 0 30 480 700 One", "4200 M end 2 moves=1"], [("3", "FAIL")])
    expect("a window nobody named is seen elsewhere when the stage comes down", start + ["2000 M begin 2 dock"] + stage + [
        "2100 W 1 10 0 0 30 500 700 One", "2120 W 2 20 0 600 100 400 300 Two", "2600 G 70", "3700 M end 2 moves=1"], [("2", "FAIL")])
    expect("a small panel of Arbor's at that level hides nothing", start + ["2000 M begin 2 dock", "2050 W 70 99 4 100 100 300 200 Arbor",
        "2100 W 1 10 0 600 30 400 300 One", "2140 W 1 10 0 0 30 400 300 One", "2600 G 70", "3700 M end 2 moves=1"], [("3", "FAIL")])
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
    away = docked + ["4000 M begin 3 all", "4100 W 2 20 0 999 799 400 300 Two"]
    expect("a tile that is seen stands in for its window", away + [
        "4100 W 60 99 0 520 30 100 700 Arbor", "5000 M end 3 moves=any everything=1 tiles=2@520:30:100:700 keyboard=1"], [])
    expect("a tile that Arbor speaks of and nobody sees does not", away + [
        "5000 M end 3 moves=any everything=1 tiles=2@520:30:100:700 keyboard=1"], [("L", "FAIL")])
    expect("the window with the keyboard is never a tile", away + [
        "4100 W 60 99 0 520 30 100 700 Arbor", "5000 M end 3 moves=any everything=1 tiles=2@520:30:100:700 keyboard=2"], [("4", "FAIL")])
    second = ["1050 Y 7 1000 0 800 600 1000 25 800 575"]
    expect("a window on a second display is in view", start + second + [
        "2000 M begin 2 move", "2100 W 2 20 0 1200 100 400 300 Two", "2100 Z 2,1", "2100 A 20 app.two", "3100 M end 2 moves=2 front=2 everything=1"], [])
    expect("without that display it is lost", start + [
        "2000 M begin 2 move", "2100 W 2 20 0 1200 100 400 300 Two", "3100 M end 2 moves=2 everything=1"], [("L", "FAIL")])
    expect("and when the display has gone it is lost", start + second + [
        "2000 M begin 2 move", "2100 W 2 20 0 1200 100 400 300 Two", "2500 Y 7", "3600 M end 2 moves=2 everything=1"], [("L", "FAIL")])
    expect("a stage hides its own display", start + second + ["1500 M begin 2 move", "1600 W 2 20 0 1200 100 400 300 Two", "1900 M end 2 moves=2",
        "2000 M begin 3 dock", "2050 W 70 99 4 1000 0 800 600 Arbor",
        "2100 W 2 20 0 1500 100 300 300 Two", "2140 W 2 20 0 1000 25 400 575 Two", "2600 G 70", "3700 M end 3 moves=2"], [])
    expect("and not the other one", start + second + ["2000 M begin 2 dock", "2050 W 70 99 4 1000 0 800 600 Arbor",
        "2100 W 1 10 0 600 30 400 300 One", "2140 W 1 10 0 0 30 400 300 One", "2600 G 70", "3700 M end 2 moves=1"], [("3", "FAIL")])
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
        line for i in range(1, 9) for line in (
            f"{2100 + 16 * i} W 1 10 0 {100 + (-1) ** i * 20 * i} 100 400 300 One", f"{2100 + 16 * i} P {300 + (-1) ** i * 20 * i} 110")] + [
        "2290 W 51 99 3 0 30 500 700 Arbor"]
    expect("in the hand a window goes where the hand goes", drag + [
        "2300 B up 10 110", "2320 W 1 10 0 12 42 476 676 One", "3400 M end 2 drags=1"], [])
    expect("after the drop it moves once", drag + [
        "2300 B up 10 110", "2320 W 1 10 0 12 42 476 676 One", "2800 W 1 10 0 12 42 456 676 One", "3900 M end 2 drags=1"],
        [("3", "FAIL")])
    glide = start + ["2000 M begin 2 drag", "2050 B down 300 110"]
    for i in range(1, 9):
        glide += [f"{2100 + 16 * i} W 1 10 0 {100 + 20 * i} 100 400 300 One", f"{2100 + 16 * i} P {300 + 20 * i} 110"]
    detectors("a dragged window goes with the pointer", glide + ["2300 B up 460 110", "3400 M end 2 drags=1"], [])
    detectors("one sample behind the pointer is not pulled", start + ["2000 M begin 2 drag", "2050 B down 300 110"] + [
        line for i in range(1, 9) for line in (f"{2100 + 16 * i} W 1 10 0 {100 + 40 * (i - 1)} 100 400 300 One", f"{2100 + 16 * i} P {300 + 40 * i} 110")] + [
        "2300 B up 620 110", "2316 W 1 10 0 420 100 400 300 One", "3400 M end 2 drags=1"], [])
    detectors("a dragged window is pulled out of the hand", glide + [
        "2250 W 1 10 0 600 400 400 300 One", "2280 W 1 10 0 260 100 400 300 One", "2300 B up 460 110", "3400 M end 2 drags=1"], ["pulled"])
    detectors("macOS holds it back where its edge meets another's, and it does not catch up", start + ["2000 M begin 2 drag", "2050 B down 300 110"] + [
        line for i in range(1, 9) for line in (f"{2100 + 16 * i} W 1 10 0 {100 + 20 * min(i, 3) + 20 * max(i - 6, 0)} 100 400 300 One", f"{2100 + 16 * i} P {300 + 20 * i} 110")] + [
        "2300 B up 460 110", "3400 M end 2 drags=1"], [])
    detectors("under the menu bar macOS holds it back", start + ["2000 M begin 2 drag", "2050 B down 300 110"] + [
        line for i in range(1, 9) for line in (f"{2100 + 16 * i} W 1 10 0 100 {max(100 - 20 * i, 30)} 400 300 One", f"{2100 + 16 * i} P 300 {110 - 20 * i}")] + [
        "2300 B up 300 -50", "3400 M end 2 drags=1"], [])
    detectors("macOS gives a tiled window its size back under the hand", start + [
        "2000 M begin 2 drag", "2050 B down 500 40", "2100 W 1 10 0 4 39 1000 700 One", "2100 P 504 49", "2150 W 1 10 0 13 57 950 680 One", "2150 P 508 58",
        "2160 W 1 10 0 60 48 950 680 One", "2200 W 1 10 0 200 56 600 400 One", "2200 P 512 66", "2260 W 1 10 0 300 65 400 300 One", "2260 P 516 75",
        "2600 W 1 10 0 310 85 400 300 One", "2600 P 526 95", "2700 W 1 10 0 330 105 400 300 One", "2700 P 546 115", "2800 B up 546 115",
        "3900 M end 2 drags=1"], [])
    tiling = glide + ["2240 W 50 5 0 -15 16 1030 760 WindowManager"]
    detectors("macOS answers the drag and Arbor stands aside", tiling + [
        "2300 B up 460 110", "2310 G 50", "2320 W 1 10 0 0 30 1000 700 One", "3400 M end 2 drags=1"], [])
    detectors("both previews are up", tiling + [
        "2260 W 51 99 3 0 30 500 700 Arbor", "2300 B up 460 110", "2310 G 50", "2310 G 51", "2320 W 1 10 0 0 30 1000 700 One",
        "3400 M end 2 drags=1"], ["fought"])
    detectors("Arbor's preview is one panel, brought out again and again", glide[:len(start) + 4] + [
        "2120 W 51 99 3 0 30 500 700 Arbor", "2125 G 51"] + glide[len(start) + 4:] + [
        "2240 W 51 99 3 0 30 500 700 Arbor", "2240 W 50 5 0 -15 16 1030 760 WindowManager", "2300 G 50", "2300 G 51", "2300 B up 460 110",
        "2320 W 1 10 0 0 30 1000 700 One", "3400 M end 2 drags=1"], ["fought"])
    detectors("macOS tiles it, and a moment later it is sent elsewhere", tiling + [
        "2300 G 50", "2300 B up 460 110", "2320 W 1 10 0 0 30 500 700 One", "3900 W 1 10 0 999 799 500 700 One", "5000 M end 2 drags=1"],
        ["fought", "jolt"])
    detectors("a switch to a window that is out of view moves the view", parked + [
        "2000 M begin 3 switch", "2100 W 2 20 0 500 100 400 300 Two", "2100 W 1 10 0 999 799 400 300 One", "2100 Z 2,1", "2100 A 20 app.two",
        "3200 M end 3 act=switch front=2"], [])
    detectors("a switch to a window in view moves nothing", start + [
        "2000 M begin 2 switch", "2100 W 1 10 0 999 799 400 300 One", "2100 Z 2,1", "2100 A 20 app.two", "3200 M end 2 act=switch front=2"],
        ["moved-unasked"])
    detectors("dropped where the preview was", glide + [
        "2260 W 51 99 3 0 30 500 700 Arbor", "2300 B up 460 110", "2310 G 51", "2320 W 1 10 0 12 42 476 676 One", "3400 M end 2 drags=1 docked=1"], [])
    detectors("dropped, and it goes somewhere else altogether", glide + [
        "2260 W 51 99 3 0 30 500 700 Arbor", "2300 B up 460 110", "2310 G 51", "2320 W 1 10 0 520 300 400 300 One", "3400 M end 2 drags=1"], ["stuck"])
    detectors("a drag that is called off: it goes back to where it was taken from", glide + [
        "2300 B up 460 110", "2320 W 1 10 0 100 100 400 300 One", "3400 M end 2 drags=1 docked=1"], [])
    detectors("dropped with no preview, and it stays", glide + ["2300 B up 460 110", "3400 M end 2 drags=1"], [])
    detectors("dropped with no preview, and it gets its own size back under the pointer", glide + [
        "2300 B up 460 110", "2320 W 1 10 0 360 100 200 150 One", "3400 M end 2 drags=1"], [])
    detectors("what the script hands on keeps its name", start + [
        "2000 M begin 2 idle", "2500 M finding 2 -:busy FAIL Arbor used 4 % of a core", "3000 M end 2"], ["busy"])
    detectors("Arbor's preview was up earlier in a drag that macOS answered", glide[:len(start) + 4] + [
        "2120 W 51 99 3 0 30 500 700 Arbor", "2125 G 51"] + glide[len(start) + 4:] + [
        "2240 W 50 5 0 -15 16 1030 760 WindowManager", "2300 G 50", "2300 B up 460 110", "2320 W 1 10 0 0 30 1000 700 One", "3400 M end 2 drags=1"], ["fought"])
    detectors("the sampler missed macOS's preview, but the window ends in macOS's own tile", glide + [
        "2260 W 51 99 3 0 30 500 700 Arbor", "2290 G 51", "2300 B up 460 110", "2320 W 1 10 0 0 30 500 700 One", "3400 M end 2 drags=1"], ["fought"])
    slow_glide = start + ["2000 M begin 2 drag", "2050 B down 300 110"]
    for i in range(1, 30):
        slow_glide += [f"{2100 + 50 * i} W 1 10 0 {100 + 10 * i + 3 * i} 100 400 300 One", f"{2100 + 50 * i} P {300 + 10 * i} 110"]
    detectors("a slow glide out of the hand adds up", slow_glide + ["3600 B up 590 110", "4700 M end 2 drags=1"], ["pulled"])
    put_back = start + ["2000 M begin 2 drag", "2050 B down 300 110"]
    for i in range(1, 30):
        put_back += [f"{2100 + 50 * i} W 1 10 0 {100 + (10 if i % 2 else 0)} 100 400 300 One", f"{2100 + 50 * i} P {300 + 10 * i} 110"]
    detectors("a window that is put back at every move falls behind", put_back + ["3600 B up 590 110", "4700 M end 2 drags=1"], ["pulled"])
    detectors("macOS zooms a window at a double-click, and that is that", start + [
        "2000 M begin 2 zoom", "2050 B down 300 110", "2050 B up 300 110", "2200 W 1 10 0 0 30 1000 700 One", "3300 M end 2 zooms=1"], [])
    detectors("macOS zooms a window at a double-click, and it is pulled back", start + [
        "2000 M begin 2 zoom", "2050 B down 300 110", "2050 B up 300 110", "2200 W 1 10 0 0 30 1000 700 One", "2500 W 1 10 0 100 100 400 300 One",
        "3600 M end 2 zooms=1"], ["fought"])
    detectors("macOS answers the drag and Arbor docks the window all the same", tiling + [
        "2300 B up 460 110", "2310 G 50", "2320 W 1 10 0 0 30 500 700 One", "3400 M end 2 drags=1 docked=1"], ["fought"])
    detectors("Arbor's preview alone is what a drag is for", glide + [
        "2260 W 51 99 3 0 30 500 700 Arbor", "2300 B up 460 110", "2310 G 51", "2320 W 1 10 0 12 42 476 676 One",
        "3400 M end 2 drags=1 docked=1"], [])
    expect("a new window stays where it opened", start + [
        "2000 M begin 2 new", "2100 W 3 10 0 200 200 400 300 One", "2100 Z 3,1,2", "3000 M end 2"], [])
    expect("a new window is moved after it opened", start + [
        "2000 M begin 2 new", "2100 W 3 10 0 200 200 400 300 One", "2100 Z 3,1,2", "2300 W 3 10 0 0 30 400 300 One",
        "3000 M end 2"], [("3", "FAIL")])
    expect("a new window pops open", start + [
        "2000 M begin 2 new", "2100 W 3 10 0 203 202 394 296 One", "2100 Z 3,1,2", "2160 W 3 10 0 200 200 400 300 One",
        "2230 W 3 10 0 199 199 402 302 One", "2400 W 3 10 0 200 200 400 300 One", "3400 M end 2"], [])
    expect("a large new window pops open by more points", start + [
        "2000 M begin 2 new", "2100 W 3 10 0 171 68 644 416 One", "2100 Z 3,1,2", "2140 W 3 10 0 168 67 667 435 One",
        "2200 W 3 10 0 164 64 675 441 One", "2420 W 3 10 0 165 65 673 439 One", "3400 M end 2"], [])
    expect("Arbor's first panel shows before the script knows its process", [
        "900 W 8 98 0 0 0 50 50 Arbor"] + start + [
        "2000 M begin 2 launch", "2100 W 7 98 0 500 100 300 300 Arbor", "2300 W 7 98 0 400 100 300 300 Arbor", "2500 M arbor 98",
        "3400 M end 2"], [])
    expect("the road into the Dock is macOS's own", start + [
        "2000 M begin 2 minimize", "2100 W 2 20 0 500 100 460 300 Two", "2150 W 2 20 0 700 500 100 80 Two", "2200 G 2", "2200 Z 1",
        "3200 M end 2 leaves=2"], [])
    expect("a sheet goes where its window goes, at each stage", start + [
        "1300 W 5 20 0 600 150 200 100 Two",
        "2000 M begin 2 float-all", "2100 W 2 20 0 500 100 600 300 Two", "2100 W 5 20 0 700 150 200 100 Two",
        "2130 W 2 20 0 300 100 600 300 Two", "2130 W 5 20 0 500 150 200 100 Two", "3200 M end 2 moves=any"], [("3", "ODD")])
    moved = docked + ["3500 M begin 3 drag", "3550 B down 10 40", "3600 W 1 10 0 300 200 500 700 One", "3650 B up 310 210",
                      "4700 M end 3 drags=1 place=1"]
    expect("a move by hand changes the place to give back, not the size", moved + [
        "5000 M begin 4 quit", "5100 W 1 10 0 300 200 400 300 One", "6100 M end 4 moves=any restores=all places=1"], [])
    expect("and the old place is then the wrong one", moved + [
        "5000 M begin 4 quit", "5100 W 1 10 0 100 100 400 300 One", "6100 M end 4 moves=any restores=all places=1"], [("5", "FAIL")])
    expect("before Arbor runs nothing is judged", start + [
        "2000 M begin 2 open", "2100 W 2 20 0 600 100 400 300 Two", "2600 W 2 20 0 500 100 400 300 Two", "2700 G 1",
        "3700 M end 2 judge=no"], [])
    expect("what the script found", start + [
        "2000 M begin 2 idle", "2500 M finding 2 - FAIL Arbor believes otherwise", "3000 M end 2"], [("-", "FAIL")])
    expect("a step that never ended", start + ["2000 M begin 2 idle"], [("-", "FAIL")])
    expect("a mark falls between the lines of one sample", start + [
        "2000 M begin 2 close", "2100 A 20 app.two", "3000 G 1", "3000 M end 2 front=2 leaves=1", "3000 Z 2"], [])
    detectors("another panel of Arbor's at the preview's level is no preview", start + ["1300 W 52 99 3 300 300 200 100 Arbor"] + tiling[len(start):] + [
        "2300 B up 460 110", "2310 G 50", "2320 W 1 10 0 0 30 1000 700 One", "3400 M end 2 drags=1"], [])

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
    offences = start + [
        "2000 M begin 2 clean", "2100 W 1 10 0 0 30 500 700 One", "3000 M end 2 moves=1",
        "4000 M begin 3 twice", "4100 W 1 10 0 0 30 480 700 One", "4600 W 1 10 0 0 30 460 700 One", "5700 M end 3 moves=1 offence=jolt"]
    if sabotage(play(offences)[1])[1] != 0:
        failures.append("sabotage: an offence that was found by its own detector counts as missed")
    for name, spoilt in (("missed", [line.replace("4600 W 1 10 0 0 30 460", "4600 W 1 10 0 0 30 480") for line in offences]),
                         ("found by another detector as well", offences[:-1] + ["4700 W 2 20 0 0 0 400 300 Two", offences[-1]]),
                         ("found where none was committed", [line.replace(" offence=jolt", "") for line in offences])):
        if sabotage(play(spoilt)[1])[1] != 1:
            failures.append(f"sabotage: an offence {name} must count against the run")
    with tempfile.TemporaryDirectory() as folder:
        samples = os.path.join(folder, "samples.log")
        with open(samples, "w", encoding="utf-8") as handle:
            handle.write("\n".join(start + ["2000 M begin 2 click", "3000 M end 2", "4000 M begin 3 click", "5000 M end 3"]) + "\n")
        with open(os.path.join(folder, "witness.log"), "w", encoding="utf-8") as handle:
            handle.write("2100 E down 300 none\n2150 E up 400 none\n4100 E down 300 none\n4350 E up 210000 none\n4400 E key 900 none\n")
        _, heard, _ = read(samples)
        got = [[finding["detector"] for finding in step.findings] for step in heard]
        if got != [[], [], ["input-held"]]:
            failures.append(f"a mouse-up that is held back for 210 ms is input-held, in its own step and no other: {got}")
        if lateness(heard) != {"events": 5, "p50_us": 400, "p99_us": 210000, "max_us": 210000}:
            failures.append(f"the lateness of five events: {lateness(heard)}")
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
        options = dict(zip(rest[::2], rest[1::2]))
        if "--control" in options and steps:
            with open(options["--control"], encoding="utf-8") as handle:
                without, heard = json.load(handle).get("input"), lateness(steps)
            if without and heard and heard["p99_us"] > without["p99_us"] + HELD_MORE:
                steps[-1].find("6", "FAIL", None, f"99 in 100 events reached the apps within {heard['p99_us']} µs; without Arbor, within {without['p99_us']} µs")
        print(report(world, steps, account), end="")
        if "--json" in options:
            with open(options["--json"], "w", encoding="utf-8") as handle:
                json.dump(as_json(world, steps, account), handle, indent=1, ensure_ascii=False)
        return 1 if any(fails(step) for step in steps) else 0
    if command == "failing":
        for step in steps:
            if step.findings:
                print(step.number)
        return 0
    if command == "sabotage":
        text, missed = sabotage(steps)
        print(text, end="")
        return 1 if missed or not any(step.wants.get("offence") for step in steps) else 0
    if command == "stories" and rest:
        for step in steps:
            if step.findings:
                with open(f"{rest[0]}/{step.number:03d}-{step.slug}.story.log", "w", encoding="utf-8") as handle:
                    handle.write(story(path, world, steps, step.number, rest[1:]))
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
