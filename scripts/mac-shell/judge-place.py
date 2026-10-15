#!/usr/bin/env python3
"""Does a real window whose PLACE ALONE is set once for every frame of the display glide as macOS's own tiling does?
Reads what probe-place.sh brought back from a Mac. Needs no Mac.

  judge-place.py <folder> [--roads]      --roads: of every film also where the window was seen, frame by frame
  judge-place.py --self-test

In the folder: glide.log (glide.swift's header has its grammar: every tick, every asking), films/<act>/ (camera.swift's: every frame the display showed, with the moment it showed it), and if
they are there pulse.log (pulse.swift's) and cpu.log (`<group> before|after <who> <seconds of processor time>`). An act is called <group>-<n>, and a group is one way of moving, played several times: from one playing only
what is structural is believed. What a group is its log says: `macos` is THE BAR, macOS's own tiling of the same window from one half of the display to the other, which keeps the size; a duration of 0
is a control, the place set once; the rest are glides. A group `app-<name>` is a real app's; `app-pair` is two of them changing places at once, and counts as one more.

WHAT IS JUDGED FROM WHAT. How smooth a glide is, from what the DISPLAY showed and from nothing else: the films, in which the windows are test windows of one flat colour each on a black desk, so that the box
of a colour is the window to the pixel. The films need numpy and Pillow (scripts/polish/film.py); where those are missing the logs are read, the films are said not to be, and the verdict is `none`.
A real app's window is no flat rectangle and is not filmed: of it only what the tool's own clock can say, what an asking costs, whether it was back within the frame, where the window ended. A paced glide
in which every asking was answered within the frame and without an error, and that ended where it was to, has no miss; an app KEEPS UP by the rule of the groups, below.

NO VERDICT WITHOUT A WITNESS, AND NONE ON WHAT WAS NOT PLAYED. A playing has a vote only if it was
  paced       no window's thread waited for a tick for over a frame and a half (from the end of one asking, or from the start, to the beginning of the next). A wait that long is the pacer's doing or the
              Mac's: what was asked for was then a few jumps. A wait because the APP was slow to answer is the app's doing, and is held against the glide
  witnessed   its film is there and whole, and shows the window at rest where the log has it, before and after; and the display did not stand still for half a second or more, from the cause to the first move
              or between two moves. On GitHub's Macs the whole display does that for about a second when a process shows a window again that was away for a while: the virtual GPU's doing, no app's
The same goes for the bar, which has no pacer: one that nobody witnessed is said to be unwitnessed, never to have passed.
THE INSTRUMENTS come first: the camera's own square, filmed in the same run moving in a way that is known, right once and wrong in five ways, is given to scripts/polish/judge.py, which must find nothing in the
right one and in each of the others the fault that was put there (docs/POLISH.md). Otherwise camera and ruler are not believed. (How late the right one is shown and with what waits is the Mac's doing, no fault of theirs.)
A frame that shows a window on its way and is stamped before the asking that caused it has a wrong time, as macOS was seen to give the first frame after a rest: it is put a frame before the next, and that is said.

THE MARK, from films of macOS's own tiling on such a Mac. A playing meets it if the window
  frames      was seen at 16 places or more of the 18 that 0.3 s have room for (less what was asked for where the ruler cannot see: beyond the display's edge)
  wait        never stood still for over 35 ms between its first move and 95 % of the road; or for over what THIS RUN'S CONTROLS show, and 2 ms: the camera's square, and for a glide also the middle one of the bar's longest waits
  leap        covered at most 17 % of the road from one frame to the next; a glide, at most 26 %. (17 % is the curve macOS has. Arbor's own, which the glides are asked for on, covers 21 % of a road in the fastest
              sixtieth of 0.3 s, so that a glide shown to perfection leaps that far: a matter of choosing a curve. A fifth more is let pass. What is to be caught is two steps shown as one, or asked for as one)
  eased       took at least 1.4 times as long from 50 % to 95 % of the road as from 5 % to 50 %
  past, back  was never over 2 points beyond the end, and never went back by over 2
  time        was within 2 points of the end 0.3 s and two and a half frames after its first move, at the latest
  end         ended where it was to, within a point by Accessibility and within 2 by the film
Where one window hides another the hidden one's steps are not told, and nothing is made of them.
A SECOND OPINION: where one window moves alone and stays in view, which is all its ruler can follow, the polish judge is asked too, with what the square lets pass in this run: a miss of its M3 (eased, never past the end),
M5 (smooth), M6 (no hop at either end), M8 (nothing flickers) or M9 (nothing flashes) is a miss here. (Its M2 wants 0.46 s, and is not asked.)

DOES THE CAMERA DISTURB A GLIDE? The table of the pacers has a line for each group, filmed or not: what its ticks were worth by the tool's own log, and how often meanwhile the display's own beat faltered as another
process was told it (pulse.swift's `U link`, written for waits of over 40 ms). Of a glide that was not filmed that is all anybody knows: whether it was paced and whether the display went on, not what was shown.
pulse.swift's strip makes every frame of a film differ from the one before. So each line of a film also has the display's own longest wait while the window was on its way: a window that waited longer than that
waited while the display went on. It is told and excuses nothing: a window server that drops a frame because a window is being moved drops it for the strip too.

A GROUP glides if at least three of its playings have a vote and at most one of those misses the mark; with fewer votes nothing is said of it.
THE VERDICT, the last line, made to grep for:
  verdict: none: <why>       the instruments are not believed; or fewer than three of the bar's playings were witnessed; or the bar misses its own mark (then the Mac shows no glide at all, or the mark
                             is too hard); or the controls stand still for over 70 ms themselves; or most glides had no vote; or no road has a group with enough votes
  verdict: glides            on every road that was filmed some group glides (a road is the group's first word: across-link and across-spin are two ways along one road)
  verdict: stutters: <roads> on these roads none does
Exit code 0 whatever the verdict, 2 if there is nothing to judge.
"""
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
# The mark.
FRAMES_MISSED, WAIT, LEAP, SETTLE, BEYOND, LATE_FRAMES = 2, 35.0, 0.17, 1.4, 2, 2.5
# How long macOS's own glide is to last, in ms.
BAR_LASTS = 300
# A thread that waited longer than this many frames for a tick was not paced.
PATIENCE = 1.5
VOTES, MISSES = 3, 1
# Controls that stand still for longer than this themselves excuse nothing: there is no verdict then.
EXCUSED = 70.0
# A display that shows nothing new for this long while the ticks go on is not the glide's doing.
FROZEN = 500.0
# The ruler: a colour is there where this many pixels of a row or a column have it (more than a title bar's red button has), and within this much of it in red, green and blue.
LEAST, NEAR = 20, 40
# The window in front throws its shadow on the one behind: so far from its edge the other's colour may be another.
SHADOW = 40


# MARK: The log


class Act:
    """One playing. Frames are (x, y, w, h); ticks (time, n, since the one before, late); calls, by window, (began, tick, took, error, x, y)."""

    def __init__(self, name, time, pace, duration, period):
        self.name, self.time, self.pace, self.duration, self.period = name, time, pace, duration, period
        self.group = name.rsplit("-", 1)[0]
        self.asks, self.ticks, self.calls, self.reads, self.go, self.done, self.cpu = {}, [], {}, {}, None, None, 0.0

    @property
    def kind(self):
        return "bar" if self.pace == "macos" else "control" if self.duration == 0 else "glide"

    def waited(self):
        """The longest that a window's thread, free to ask, waited for a tick; None if one of them never asked."""
        longest = 0.0
        for window in self.asks:
            free = self.go
            if free is None or not self.calls.get(window):
                return None
            for began, _, took, _, _, _ in self.calls[window]:
                longest, free = max(longest, began - free), began + took
        return longest

    def paced(self):
        return self.waited() is not None and self.waited() <= PATIENCE * self.period

    def cause(self, window):
        """Before this nothing of the act can have been on the display: the window's first asking; of the bar, the press."""
        return self.calls[window][0][0] if self.calls.get(window) else self.time

    def seen(self, window, series):
        return ride(series, self.asks[window][1][0], self.asks[window][2][0], self.period, self.cause(window))

    def off(self):
        """How far from where they were to end the windows ended, by Accessibility; None if one did not say."""
        if any(window not in self.reads for window in self.asks):
            return None
        return max(max(abs(self.reads[window][0] - to[0]), abs(self.reads[window][1] - to[1])) for window, (_, _, to) in self.asks.items())


def read_log(lines):
    acts = {}
    for line in lines:
        words = line.split()
        if len(words) < 3:
            continue
        time, kind, name, rest = float(words[0]), words[1], words[2], words[3:]
        if kind == "act":
            acts[name] = Act(name, time, rest[0], float(rest[1]), float(rest[2]))
        act = acts.get(name)
        if act is None:
            continue
        if kind == "ask":
            numbers = [float(word) for word in rest[2:10]]
            act.asks[int(rest[0])] = (int(rest[1]), tuple(numbers[:4]), tuple(numbers[4:]))
        elif kind == "tick":
            act.ticks.append((time, int(rest[0]), float(rest[1]), float(rest[2])))
        elif kind == "go":
            act.go = time
        elif kind == "call":
            act.calls.setdefault(int(rest[0]), []).append((time, int(rest[1]), float(rest[2]), int(rest[3]), float(rest[4]), float(rest[5])))
        elif kind == "read" and rest[2] != "?":
            act.reads[int(rest[0])] = tuple(float(word) for word in rest[2:6])
        elif kind == "done":
            act.done, act.cpu = time, float(rest[0])
    return acts


# MARK: The road, as the display showed it


def set_right(series, start, cause, period):
    """The series with every frame that shows the window on its way and is stamped before the act's cause put a frame's time before the frame after it; and how many there were. After a rest macOS was seen to hand
    the camera the first frame that changes with the time of the frame before, which the camera believes if it is under a quarter of a second old."""
    right, wrong = list(series), 0
    for index in range(len(right) - 2, -1, -1):
        time, place = right[index]
        if time < cause - 2 and place is not None and abs(place - start) >= 1:
            right[index], wrong = (right[index + 1][0] - period, place), wrong + 1
    return right, wrong


def ride(series, start, end, period, cause=0):
    """What can be measured of one window's road. `series`: [(ms, where its left edge was seen, or None where it could not be told)], a line for every frame of the film. `cause`: nothing of the act can have been
    shown before. None if it was never seen to move."""
    sign, road = (1 if end >= start else -1), abs(end - start)
    series, stale = set_right(series, start, cause, period)
    # (time, how far along, the step or None where frames before it did not tell)
    moves, seen, last, hidden = [], [], None, False
    for time, place in series:
        if place is None:
            hidden = True
            continue
        way = (place - start) * sign
        seen.append((time, way))
        if last is None and hidden:
            moves.append((time, way, None))
        elif last is not None and abs(way - last) >= 1:
            moves.append((time, way, None if hidden else way - last))
        last, hidden = way, False
    if not moves or road == 0:
        return None

    def reaches(share):
        """When it was first that far, between two frames. A frame that equals the last is not sent: after a long wait the window stood where it was until a frame before the new one."""
        for (before, a), (after, b) in zip(seen, seen[1:]):
            if a < share * road <= b:
                before = after - period if after - before > 4.5 * period else before
                return before + (after - before) * (share * road - a) / (b - a)
        return None

    waits = [after[0] - before[0] for before, after in zip(moves, moves[1:]) if after[2] is not None and before[1] < 0.95 * road]
    steps = [step for _, _, step in moves if step is not None]
    early, half, late = reaches(0.05), reaches(0.5), reaches(0.95)
    there = next((time for time, way in seen if way >= road - BEYOND), None)
    frames = [time for time, _ in series if moves[0][0] - 1.5 * period <= time <= (there if there is not None else moves[-1][0])]
    return {"frames": len(moves), "first": moves[0][0], "wait": max(waits, default=0.0), "leap": max(steps, default=0) / road, "past": max(way for _, way in seen) - road,
            "back": max([-step for step in steps], default=0), "settle": (late - half) / max(half - early, 1) if None not in (early, half, late) else None,
            "took": there - moves[0][0] + period if there is not None else None, "from": min(way for _, way in seen), "to": max(way for _, way in seen), "stale": stale, "rests": series[-1][1] is not None,
            "display": max((after - before for before, after in zip(frames, frames[1:])), default=0.0)}


def eased(progress):
    """Arbor's curve, as glide.swift has it."""
    low, high = 0.0, 1.0
    for _ in range(40):
        t = (low + high) / 2
        low, high = (t, high) if 3 * (1 - t) * (1 - t) * t * 0.2 + t**3 < progress else (low, t)
    t = (low + high) / 2
    return 3 * (1 - t) * t * t + t**3


def misses(act, window, found, wait):
    """Why this window's road does not meet the mark: a list of words, empty if it does. `wait`: the longest that is let pass."""
    _, start, end = act.asks[window]
    road, faults = abs(end[0] - start[0]), []
    if found is None:
        return ["it was never seen to move"]
    lasts, leap, unseen = (act.duration, LEAP, 0) if act.kind == "glide" else (BAR_LASTS, LEAP, 0)
    if act.kind == "glide":
        ways = [abs(x - start[0]) for _, _, _, _, x, _ in act.calls[window]]
        leap = max(LEAP, 1.2 * max(eased(min(step / 200 + act.period / lasts, 1)) - eased(step / 200) for step in range(200)))
        # What was asked for where the ruler cannot see.
        unseen = sum(1 for way in ways if way < found["from"] - 0.5 or way > found["to"] + 0.5)
    needed = round(lasts / act.period) - FRAMES_MISSED - unseen
    if found["frames"] < needed:
        faults.append(f"seen at {found['frames']} places, under {needed}")
    if found["wait"] > wait:
        faults.append(f"stood still for {found['wait']:.0f} ms, over {wait:.0f}")
    if found["leap"] > leap:
        faults.append(f"{found['leap'] * 100:.0f} % of the road in one frame, over {leap * 100:.0f}")
    if found["settle"] is not None and found["settle"] < SETTLE:
        faults.append(f"not eased: {found['settle']:.1f}, under {SETTLE}")
    if found["past"] > BEYOND:
        faults.append(f"{found['past']:.0f} points past the end")
    if found["back"] > BEYOND:
        faults.append(f"{found['back']:.0f} points backwards")
    # Where the end is out of view nobody sees it arrive.
    if found["took"] is None and found["rests"] or found["took"] is not None and found["took"] > lasts + LATE_FRAMES * act.period:
        faults.append("never seen at the end" if found["took"] is None else f"took {found['took']:.0f} ms, over {lasts + LATE_FRAMES * act.period:.0f}")
    if act.kind == "glide" and (act.off() is None or act.off() > 1):
        faults.append("did not say where it ended" if act.off() is None else f"ended {act.off():.0f} points off")
    return faults


# MARK: The films


def follow(folder, act):
    """({window: series for `ride`}, "") from the film of an act in which every window keeps its size, or (None, why the film is no witness)."""
    sys.path.insert(0, os.path.join(HERE, "..", "polish"))
    import numpy as np
    from film import Film
    if not os.path.isfile(os.path.join(folder, "film.log")):
        return None, "not filmed"
    film = Film(folder)
    if film.dropped or len(film) == 0:
        return None, "the camera ran out of room" if film.dropped else "the film has no frame"
    left, top, right, bottom = film.room()
    frames = [(time, picture[top:bottom, left:right].astype(np.int16)) for _, time, picture, _ in film.frames()]
    scale = film.scale

    def inner(frame):
        """The part of a window that is its colour whatever lies at its edges, if that much of it is in the room: in the room's pixels."""
        x0, y0, x1, y1 = (frame[0] + 20) * scale - left, (frame[1] + 50) * scale - top, (frame[0] + frame[2] - 20) * scale - left, (frame[1] + frame[3] - 20) * scale - top
        x0, y0, x1, y1 = int(max(x0, 0)), int(max(y0, 0)), int(min(x1, right - left)), int(min(y1, bottom - top))
        return (x0, y0, x1, y1) if x1 - x0 >= LEAST * scale and y1 - y0 >= LEAST * scale else None

    colours = {}
    for window, (_, start, end) in act.asks.items():
        # Where it can be seen at rest: before the act, or after it.
        for frame, picture in ((start, frames[0][1]), (end, frames[-1][1])):
            if inner(frame) and window not in colours:
                x0, y0, x1, y1 = inner(frame)
                colours[window] = np.median(picture[y0:y1, x0:x1].reshape(-1, 3), axis=0)
        if window not in colours:
            return None, f"w{window} is in view neither before nor after"
    boxes = []
    for _, picture in frames:
        found = {}
        for window, colour in colours.items():
            near = (np.abs(picture - colour) <= NEAR).all(axis=2)
            columns = np.flatnonzero(near.sum(axis=0) >= LEAST * scale)
            if columns.size and (near.sum(axis=1) >= LEAST * scale).any():
                found[window] = (int(columns[0]) + left, int(columns[-1]) + 1 + left)
        boxes.append(found)
    tracks = {}
    for window, (_, start, end) in act.asks.items():
        wide, series = start[2] * scale, []
        for (time, _), found in zip(frames, boxes):
            place = None
            if window in found:
                a, b = found[window]
                others = [box for other, box in found.items() if other != window]
                # What ends at the room's own edge, or at another window's or in its shadow, may go on behind it.
                free_left = a > left + 1 and not any(0 <= a - box[1] <= SHADOW * scale for box in others)
                free_right = b < right - 1 and not any(0 <= box[0] - b <= SHADOW * scale for box in others)
                place = a if b - a >= wide - 2 or free_left else b - wide if free_right else None
            series.append((time, None if place is None else place / scale))
        # Where Accessibility had it, which need not be where it was to go.
        for frame, (_, place), when in ((start, series[0], "before"), (act.reads.get(window, end), series[-1], "after")):
            if inner(frame) and (place is None or abs(place - frame[0]) > BEYOND):
                return None, f"{when} the act the film has w{window} at {place}, the log at {frame[0]:.0f}"
        tracks[window] = series
    return tracks, ""


def second_opinion(folder, allow):
    """What the polish judge misses in a film, of the checks that are asked of it here."""
    sys.path.insert(0, os.path.join(HERE, "..", "polish"))
    import judge as polish
    _, verdicts = polish.judge(folder, allow)
    return [f"the polish judge's {check}: {verdicts[check].said}" for check in ("M3", "M5", "M6", "M8", "M9") if verdicts[check].status == polish.MISS]


def instruments(films):
    """(whether camera and ruler are believed, what to say, the longest wait in the film of the square that moves as it should, what the polish judge lets pass for it) by the polish judge's own rule."""
    sys.path.insert(0, os.path.join(HERE, "..", "polish"))
    import judge as polish
    said, believed, wait, allow = [], True, 0.0, None
    for kind, wanted in polish.METRONOME.items():
        folder = os.path.join(films, f"metronome-{kind}")
        if not os.path.isfile(os.path.join(folder, "film.log")):
            said.append(f"  metronome {kind}: NOT FILMED")
            believed = False
            continue
        m, verdicts = polish.judge(folder)
        # How late the square that moves as it should is shown, and with what waits, is the Mac's doing: it is what is let pass below.
        missed = sorted(check for check, verdict in verdicts.items() if verdict.status == polish.MISS and (wanted or check not in ("M1", "M5", "M10")))
        unseen = [check for check in (wanted or ["M2", "M3", "M4", "M5", "M6"]) if verdicts[check].status == polish.UNSEEN]
        right = all(check in missed for check in wanted) and bool(wanted or not missed) and not unseen
        believed &= right
        said.append(f"  metronome {kind}: {'as it should be' if right else 'WRONG'}: missed {', '.join(missed) or 'nothing'} (must miss {', '.join(wanted) or 'nothing'})"
                    + (f", could not see {', '.join(unseen)}" if unseen else ""))
        if kind == "good":
            wait, allow = m["gap"], polish.leeway({"metronome-good": (m, verdicts)})
    return believed, said, wait, allow


# MARK: The verdict


def middle(values):
    return statistics.median(values) if values else 0.0


def judge(acts, tracks, trusted, cpu=None, say=print, roads=False, second=None, beats=None):
    """`tracks`: {act's name: ({window: series}, "") or (None, why not)}. `trusted`: (believed, lines, the square's longest wait, …), or None where the films cannot be read. `second`: {act's name: what the
    polish judge misses}. `beats`: what read_pulse returns. Returns the verdict."""
    groups = {}
    for act in acts.values():
        groups.setdefault(act.group, []).append(act)

    def filmed(kind):
        """{group: its playings of that kind}, for the groups of which one was filmed. (The window is set back after a group's last glide, under the group's name.)"""
        found = {group: [act for act in plays if act.kind == kind] for group, plays in groups.items()}
        return {group: plays for group, plays in found.items() if any(act.name in tracks for act in plays)}

    say("the instruments: " + ("the films are not read here: no numpy, or no Pillow" if trusted is None else "believed" if trusted[0] else "NOT BELIEVED"))
    for line in trusted[1] if trusted else []:
        say(line)
    square = max(WAIT, trusted[2] + 2) if trusted else WAIT

    def table(group, plays, wait):
        """Prints a group's playings; returns (votes, those that meet the mark, the longest wait of each that has a vote)."""
        votes, met, waits = 0, 0, []
        for act in plays:
            found, why = tracks.get(act.name, (None, "not filmed"))
            words = []
            if act.kind != "bar" and not act.paced():
                words.append("NOT PACED: " + ("no tick came" if act.waited() is None else f"waited {act.waited():.0f} ms for a tick"))
            if found is None:
                words.append(f"UNWITNESSED: {why}")
            rides = {window: act.seen(window, series) for window, series in (found or {}).items()}
            for window, one in rides.items():
                if one:
                    say(f"  {act.name} w{window}: {one['frames']} places, the longest wait {one['wait']:.0f} ms (the display's own {one['display']:.0f}), {one['leap'] * 100:.0f} % at the most in one frame, eased "
                        + (f"{one['settle']:.1f}" if one["settle"] is not None else "?") + ", there after " + (f"{one['took']:.0f} ms" if one["took"] is not None else "?")
                        + (f", the first move {one['first'] - act.go:.0f} ms after the start" if act.go else "")
                        + (f"; {one['stale']} FRAMES STAMPED BEFORE THEIR CAUSE, put a frame before the next" if one["stale"] else ""))
                if roads:
                    for time, place in found[window]:
                        say(f"      {time - (act.go or act.time):7.0f} {'?' if place is None else format(place, '.0f')}")
            stood = max([max(one["wait"], one["first"] - act.cause(window)) for window, one in rides.items() if one], default=0)
            if stood >= FROZEN:
                words.append(f"UNWITNESSED: THE DISPLAY STOOD STILL for {stood:.0f} ms"
                             + (" while the ticks went on" if act.kind != "bar" and act.paced() else "") + ": as the virtual GPU of GitHub's Macs does when a window is shown again after a while away")
            if words:
                say(f"  {act.name}: no vote: " + "; ".join(words))
                continue
            faults = [f"w{window} {fault}" for window, one in rides.items() for fault in misses(act, window, one, wait)] + (second or {}).get(act.name, [])
            votes, met = votes + 1, met + (not faults)
            waits.append(max((one["wait"] for one in rides.values() if one), default=0.0))
            say(f"  {act.name}: " + ("meets the mark" if not faults else "MISSES: " + "; ".join(faults)))
        return votes, met, waits

    bar_votes, bar_met, allowed, verdicts, all_votes, all_plays = 0, 0, square, {}, 0, 0
    # Where the films cannot be read there is nothing to say of them, playing by playing.
    if trusted is not None:
        bars = [act for plays in filmed("bar").values() for act in plays]
        say(f"the bar, macOS's own tiling: a wait of {square:.0f} ms is let pass")
        bar_votes, bar_met, waits = table("the bar", bars, square)
        say(f"the bar: {len(bars)} played, {bar_votes} witnessed, {len(bars) - bar_votes} UNWITNESSED, {bar_met} meet the mark")
        allowed = max(square, middle(waits) + 2)
        for group, plays in filmed("glide").items():
            say(f"{group}: a wait of {allowed:.0f} ms is let pass")
            votes, met, _ = table(group, plays, allowed)
            all_votes, all_plays = all_votes + votes, all_plays + len(plays)
            verdicts[group] = None if votes < VOTES else votes - met <= MISSES
            say(f"{group}: {len(plays)} played, {votes} with a vote, {met} meet the mark: " + {None: "too few votes to say", True: "glides", False: "STUTTERS"}[verdicts[group]])
        for group, plays in filmed("control").items():
            say(f"{group}, the place set once:")
            for act in plays:
                for window, series in (tracks.get(act.name, (None, ""))[0] or {}).items():
                    one = act.seen(window, series)
                    say(f"  {act.name} w{window}: " + (f"seen at {one['frames']} places" if one else "never seen to move"))

    pacers(groups, beats, say)
    apps(groups, cpu or {}, say)

    roads_of = {}
    for group, verdict in verdicts.items():
        roads_of.setdefault(group.split("-")[0], []).append(verdict)
    if trusted is None:
        verdict = "none: the films are not read here"
    elif not trusted[0]:
        verdict = "none: the instruments are not believed"
    elif bar_votes < VOTES:
        verdict = f"none: only {bar_votes} of macOS's own glides were witnessed: nothing to hold a glide against"
    elif bar_votes - bar_met > MISSES:
        verdict = f"none: {bar_votes - bar_met} of {bar_votes} of macOS's own glides miss the mark: the Mac shows no glide, or the mark is too hard"
    elif allowed > EXCUSED:
        verdict = f"none: this run's own controls stand still for {allowed - 2:.0f} ms: the Mac shows no glide"
    elif 2 * all_votes <= all_plays:
        verdict = f"none: only {all_votes} of {all_plays} glides were paced and witnessed"
    elif not any(verdict is not None for verdict in verdicts.values()):
        verdict = "none: no road has a group with enough votes"
    else:
        bad = sorted(road for road, said in roads_of.items() if True not in said and False in said)
        silent = sorted(road for road, said in roads_of.items() if True not in said and False not in said)
        for road in silent:
            say(f"nothing can be said of the road {road}")
        verdict = "stutters: " + ", ".join(bad) if bad else "glides"
    say(f"verdict: {verdict}")
    return verdict


def read_pulse(lines):
    """[(from, to)]: when the display's own beat faltered, as another process was told it."""
    return [(float(words[0]) - float(words[3]), float(words[0])) for words in map(str.split, lines) if len(words) == 4 and words[1:3] == ["U", "link"]]


def pacers(groups, beats, say):
    """Whether the camera beside it disturbs a glide, and what each pacer is worth: the ticks from the start on, group by group."""
    say("the pacers (ms): group, playings, paced; between two ticks: the middle, the worst; a tick's lateness: the middle, the worst; from the tick to the asking: the middle, the worst; "
        "the tool's own processor time; how often the display's beat faltered meanwhile, and for how long at the most")
    for group, plays in groups.items():
        plays = [act for act in plays if act.kind == "glide" and act.go is not None]
        if not plays or group.startswith("app-"):
            continue
        gaps = [gap for act in plays for time, _, gap, _ in act.ticks if time > act.go]
        late = [late for act in plays for time, _, _, late in act.ticks if time > act.go]
        when = {(act.name, n): time for act in plays for time, n, _, _ in act.ticks}
        woken = [began - when[(act.name, tick)] for act in plays for calls in act.calls.values() for began, tick, _, _, _, _ in calls if (act.name, tick) in when]
        faltered = [until - since for since, until in beats or [] if any(since < (act.done or act.go) and until > act.go for act in plays)]
        say(f"  {group} ({plays[0].pace}): {len(plays)}, {sum(act.paced() for act in plays)}; {middle(gaps):.2f}, {max(gaps, default=0):.2f}; {middle(late):.2f}, {max(late, default=0):.2f}; "
            f"{middle(woken):.2f}, {max(woken, default=0):.2f}; {middle([act.cpu for act in plays]):.0f}; "
            + ("nobody listened" if beats is None else "{}, {:.0f}".format(len(faltered), max(faltered, default=0))))


def apps(groups, cpu, say):
    """The real apps, by the tool's own clock. A paced glide misses if an asking was not answered within the frame, or with an error, or the window ended elsewhere. An app keeps up by the rule of the groups."""
    names = [group for group in groups if group.startswith("app-")]
    if not names:
        return
    say("the real apps, by the tool's own clock (ms): glides, paced, of those without a miss; askings; an asking: the middle, the worst; over a frame; errors; ended off by; "
        "processor time a glide, the app's and the window server's")
    keep = judged = 0
    for group in names:
        glides = [act for act in groups[group] if act.kind == "glide"]
        paced = [act for act in glides if act.paced()]
        calls = [call for act in paced for calls in act.calls.values() for call in calls]
        met = sum(all(call[2] <= act.period and call[3] == 0 for calls in act.calls.values() for call in calls) and act.off() is not None and act.off() <= 1 for act in paced)
        off = max((act.off() if act.off() is not None else 9999 for act in paced), default=0)
        share = " ".join(f"{(after - before) * 1000 / max(len(glides), 1):.0f}" for before, after in cpu.get(group, {}).values()) or "?"
        word = "too few paced glides to say" if len(paced) < VOTES else "keeps up" if len(paced) - met <= MISSES else "DOES NOT KEEP UP"
        judged, keep = judged + (len(paced) >= VOTES), keep + (word == "keeps up")
        say(f"  {group[4:]}: {len(glides)}, {len(paced)}, {met}; {len(calls)}; {middle([call[2] for call in calls]):.2f}, {max((call[2] for call in calls), default=0):.2f}; "
            f"{sum(call[2] > glides[0].period for call in calls)}; {sum(call[3] != 0 for call in calls)}; {off:.0f}; {share}: {word}")
    say(f"apps: {keep} of {judged} keep up" + (f", {len(names) - judged} could not be told" if judged < len(names) else ""))


def read_cpu(lines):
    """{group: {who: (seconds before, seconds after)}}"""
    found = {}
    for group, when, who, seconds in (line.split() for line in lines if len(line.split()) == 4):
        before, after = found.setdefault(group, {}).get(who, (0.0, 0.0))
        found[group][who] = (float(seconds), after) if when == "before" else (before, float(seconds))
    return found


def main(arguments):
    if arguments[:1] == ["--self-test"]:
        return self_test()
    roads = "--roads" in arguments
    arguments = [word for word in arguments if word != "--roads"]
    if len(arguments) != 1 or arguments[0].startswith("-"):
        print(__doc__)
        return 64
    folder = arguments[0]
    if not os.path.isfile(os.path.join(folder, "glide.log")):
        print(f"judge-place.py: no glide.log in {folder}: nothing to judge")
        return 2
    with open(os.path.join(folder, "glide.log"), encoding="utf-8") as log:
        acts = read_log(log)
    cpu = {}
    if os.path.isfile(os.path.join(folder, "cpu.log")):
        with open(os.path.join(folder, "cpu.log"), encoding="utf-8") as log:
            cpu = read_cpu(log)
    beats = None
    if os.path.isfile(os.path.join(folder, "pulse.log")):
        with open(os.path.join(folder, "pulse.log"), encoding="utf-8") as log:
            beats = read_pulse(log)
    films = os.path.join(folder, "films")
    names = [act.name for act in acts.values() if os.path.isdir(os.path.join(films, act.name))]
    try:
        import numpy  # noqa: F401
        import PIL  # noqa: F401
    except ImportError:
        judge(acts, {name: (None, "the films are not read here") for name in names}, None, cpu, beats=beats)
        return 0
    tracks, trusted = {name: follow(os.path.join(films, name), acts[name]) for name in names}, instruments(films)
    alone = [name for name in names if acts[name].kind != "control" and tracks[name][0] and len(tracks[name][0]) == 1 and all(place is not None for series in tracks[name][0].values() for _, place in series)]
    judge(acts, tracks, trusted, cpu, roads=roads, beats=beats, second={name: second_opinion(os.path.join(films, name), trusted[3]) for name in alone})
    return 0


# MARK: The judge, tried


PERIOD = 1000 / 60


def made_up(name, began, windows, pace="link", duration=300.0, late=(), slow=(), ends=0, silent=False):
    """The lines glide.swift writes for one playing. `windows`: {number: (from x, to x)}. `late`: {tick: ms it comes late}. `slow`: {tick: ms the app takes}. Returns (lines, {window: [(time, x asked)]})."""
    lines, asked = [f"{began} act {name} {pace} {duration:.0f} {PERIOD:.2f}"], {window: [] for window in windows}
    for window, (start, end) in windows.items():
        lines.append(f"{began} ask {name} {window} 77 {start} 43 494 600 {end} 43 494 600")
    if pace == "macos":
        return lines + [f"{began + 700} done {name} 5.0"], asked
    late, slow, busy = dict(late), dict(slow), 0.0
    go = began + 2 * PERIOD
    for tick in range(1, 60):
        time = began + (tick - 1) * PERIOD + late.get(tick, 0)
        lines.append(f"{time:.2f} tick {name} {tick} {PERIOD:.2f} 0.30")
        if tick == 3:
            lines.append(f"{time:.2f} go {name} 3")
        if tick <= 3 or silent or time < busy:
            continue
        last = duration - (time - go) < PERIOD / 2
        for window, (start, end) in windows.items():
            place = end if last else round(start + (end - start) * eased((time - go) / duration))
            lines.append(f"{time + 0.2:.2f} call {name} {window} {tick} {slow.get(tick, 0.6)} 0 {place} 43")
            asked[window].append((time + 0.2 + slow.get(tick, 0.6), place))
        busy = time + slow.get(tick, 0.6)
        if last:
            break
    for window, (start, end) in windows.items():
        lines.append(f"{time + 3:.2f} read {name} {window} 0.2 {end + ends} 43 494 600")
    return lines + [f"{time + 4:.2f} done {name} 9.0"], asked


def shown(asked, began, start, drop=(), hold=None, extra=None, beyond=None, linear=False):
    """What a display that shows every place a frame after it was asked for shows: a series for `ride`. `drop`: these frames (counted from 0) are not shown. `hold`: (frame, ms) all from that frame on come
    that much later. `extra`: (frame, points) that frame is shown so far from where it belongs. `beyond`: further right than that the ruler does not see. `linear`: it is shown at an even pace instead."""
    series = [(began - 400, start)]
    for index, (time, place) in enumerate(asked):
        if index in drop:
            continue
        if linear:
            place = round(start + (asked[-1][1] - start) * (index + 1) / len(asked))
        place += extra[1] if extra and index == extra[0] else 0
        series.append((time + PERIOD + (hold[1] if hold and index >= hold[0] else 0), None if beyond and place > beyond else place))
    return series


def macos(began, start, end, waits=()):
    """macOS's own glide as it was filmed: 18 places in 0.3 s, at most 17 % of the road in a frame. `waits`: {frame: ms more before it}."""
    shares = (0.053, 0.2, 0.369, 0.52, 0.647, 0.744, 0.818, 0.871, 0.91, 0.938, 0.958, 0.971, 0.98, 0.987, 0.991, 0.995, 0.998, 1.0)
    series, time = [(began - 400, start)], began + 60
    for index, share in enumerate(shares):
        time += PERIOD + dict(waits).get(index, 0)
        series.append((time, round(start + (end - start) * share)))
    return series


def self_test():
    failures, count = [], 0

    def run(glides, bars=5, bar_waits=(), trusted=(True, [], 33.0), unfilmed=(), bar_unfilmed=0, stuck_bars=0, more=(), second=None, beats=None):
        """`glides`: {group: [keywords for one playing…]}; a keyword set has what made_up and shown take. Returns everything said."""
        lines, tracks, began = [], {}, 1_000_000.0
        for index in range(bars):
            name, (start, end) = f"bar-{index + 1}", ((0, 512) if index % 2 else (512, 0))
            lines += made_up(name, began, {31: (start, end)}, pace="macos")[0]
            tracks[name] = ({31: macos(began, start, end, {5: 900} if index < stuck_bars else bar_waits)}, "") if index >= bar_unfilmed else (None, "not filmed")
            began += 2000
        for group, plays in glides.items():
            for index, play in enumerate(plays):
                name, play = f"{group}-{index + 1}", dict(play)
                windows = play.pop("windows", {31: (12, 632)})
                film = {key: play.pop(key) for key in ("drop", "hold", "extra", "beyond", "linear") if key in play}
                wrote, asked = made_up(name, began, windows, **play)
                lines += wrote
                if not group.startswith(("app-", "blind-")):
                    tracks[name] = ({window: shown(asked[window], began, windows[window][0], **film) for window in windows}, "")
                if name in unfilmed:
                    tracks[name] = (None, "not filmed")
                began += 2000
        said = []
        judge(read_log(lines + list(more)), tracks, trusted, say=said.append, second=second, beats=beats)
        return said

    def expect(what, said, *wanted):
        nonlocal count
        count += 1
        missing = [line for line in wanted if not any(line in one for one in said)]
        if missing:
            failures.append(f"{what}: not said: {missing}\n    " + "\n    ".join(said))

    good = [{}] * 5
    expect("five glides that are shown as they were asked for", run({"across-link": good}), "across-link: 5 played, 5 with a vote, 5 meet the mark: glides", "verdict: glides",
           "the bar: 5 played, 5 witnessed, 0 UNWITNESSED, 5 meet the mark")
    expect("a tick that comes 30 ms late: that playing has no vote", run({"across-link": [{"late": {9: 30}}] + good[1:]}), "across-link-1: no vote: NOT PACED: waited 4", "5 played, 4 with a vote, 4 meet", "verdict: glides")
    expect("a tick 5 ms late is a tick", run({"across-link": [{"late": {9: 5}}] * 5}), "5 with a vote")
    expect("most glides not paced: no verdict", run({"across-link": [{"late": {9: 30}}] * 3 + good[:2]}), "verdict: none: only 2 of 5 glides were paced and witnessed")
    expect("no tick at all", run({"across-link": [{"silent": True}] * 5}), "NOT PACED: no tick came", "verdict: none: only 0 of 5")
    expect("an app that takes 40 ms over an asking is not the pacer's doing: the playing votes, and misses", run({"across-link": [{"slow": {6: 40.0}}] * 5}),
           "5 with a vote, 0 meet the mark: STUTTERS", "verdict: stutters: across")
    expect("a playing that was not filmed has no vote", run({"across-link": good}, unfilmed=("across-link-2",)), "across-link-2: no vote: UNWITNESSED: not filmed", "5 played, 4 with a vote, 4 meet")
    expect("two votes are too few", run({"across-link": good, "swap": good}, unfilmed=("swap-1", "swap-2", "swap-3")), "swap: 5 played, 2 with a vote, 2 meet the mark: too few votes to say",
           "nothing can be said of the road swap", "verdict: glides")
    expect("a bar nobody witnessed is unwitnessed, and there is no verdict", run({"across-link": good}, bar_unfilmed=3), "the bar: 5 played, 2 witnessed, 3 UNWITNESSED", "verdict: none: only 2 of macOS's own glides were witnessed")
    expect("no bar at all", run({"across-link": good}, bars=0), "verdict: none: only 0 of macOS's own")
    expect("a bar that misses its own mark", run({"across-link": good}, bar_waits={5: 60}), "the bar: 5 played, 5 witnessed, 0 UNWITNESSED, 0 meet", "verdict: none: 5 of 5 of macOS's own glides miss the mark")
    expect("instruments that are not believed", run({"across-link": good}, trusted=(False, ["  metronome linear: WRONG"], 33.0)), "the instruments: NOT BELIEVED", "verdict: none: the instruments are not believed")
    expect("films that cannot be read here", run({"across-link": good}, trusted=None), "verdict: none: the films are not read here")
    expect("one miss in five is let pass", run({"across-link": [{"drop": (3, 4, 5)}] + good[1:]}), "across-link-1: MISSES", "5 with a vote, 4 meet the mark: glides")
    expect("two are not", run({"across-link": [{"drop": (3, 4, 5)}] * 2 + good[2:]}), "5 with a vote, 3 meet the mark: STUTTERS", "verdict: stutters: across")
    expect("three frames that are not shown: too few places", run({"across-link": [{"drop": (12, 14, 16)}] * 5}), "seen at 15 places, under 16")
    expect("two are macOS's own measure", run({"across-link": [{"drop": (14, 16)}] * 5}), "5 meet the mark: glides")
    expect("a wait of 50 ms", run({"across-link": [{"hold": (8, 34)}] * 5}), "stood still for 51 ms, over 35")
    expect("a wait of 33 ms is let pass", run({"across-link": [{"hold": (8, 17)}] * 5}), "5 meet the mark: glides")
    expect("not beyond 95 % of the road", run({"across-link": [{"hold": (14, 34)}] * 5}), "5 meet the mark: glides")
    expect("what the camera's own square shows is let pass", run({"across-link": [{"hold": (8, 34)}] * 5}, trusted=(True, [], 50.0)), "a wait of 52 ms is let pass", "5 meet the mark: glides")
    expect("and what the middle one of the bar's shows", run({"across-link": [{"hold": (8, 34)}] * 5}, bar_waits={5: 34}, trusted=(True, [], 50.0)), "across-link: a wait of 53 ms is let pass")
    expect("controls that stand still for 80 ms excuse nothing", run({"across-link": good}, trusted=(True, [], 80.0)), "verdict: none: this run's own controls stand still for 80 ms")
    expect("a display that stands still for 0.8 s in mid-glide is not the glide's doing", run({"across-link": [{"hold": (5, 800)}] + good[1:]}), "across-link-1: no vote: UNWITNESSED: THE DISPLAY STOOD STILL for 817 ms while the ticks went on",
           "5 played, 4 with a vote, 4 meet")
    expect("nor one that stands still before the first move", run({"across-link": [{"hold": (0, 800), "drop": tuple(range(17))}] + good[1:]}), "across-link-1: no vote: UNWITNESSED: THE DISPLAY STOOD STILL", "4 with a vote, 4 meet")
    expect("0.3 s is", run({"across-link": [{"hold": (5, 300)}] * 5}), "stood still for 317 ms, over 35", "verdict: stutters: across")
    expect("two steps shown as one, where it is fastest", run({"across-link": [{"drop": (2,)}] * 5}), "% of the road in one frame, over 26")
    expect("a window that goes at an even pace", run({"across-link": [{"linear": True}] * 5}), "not eased: 1.0, under 1.4")
    expect("what is asked for out of the ruler's sight is not missed", run({"out": [{"windows": {31: (12, 1023)}, "beyond": 990}] * 5}), "out-1 w31: 12 places", "out: 5 played, 5 with a vote, 5 meet the mark: glides")
    expect("a frame 9 points past the end", run({"across-link": [{"extra": (17, 9)}] * 5}), "9 points past the end")
    expect("a frame 30 points back", run({"across-link": [{"extra": (10, -30)}] * 5}), "points backwards")
    expect("a glide that arrives late", run({"across-link": [{"hold": (15, 60)}] * 5}), "took 343 ms, over 342")
    expect("a window that ends elsewhere, by Accessibility", run({"across-link": [{"ends": 14}] * 5}), "ended 14 points off")
    expect("a window that never moves", run({"across-link": [{"drop": tuple(range(18))}] * 5}), "it was never seen to move")
    expect("a road on which one way glides is a road that can be had", run({"across-link": [{"drop": (3, 4, 5)}] * 5, "across-spin": [{"pace": "spin"}] * 5}), "across-link: 5 played, 5 with a vote, 0 meet the mark: STUTTERS",
           "across-spin: 5 played, 5 with a vote, 5 meet the mark: glides", "verdict: glides")
    expect("of two roads the one that stutters is named", run({"across-link": good, "swap": [{"windows": {31: (12, 518), 32: (518, 12)}, "drop": (3, 4, 5)}] * 5}), "verdict: stutters: swap")
    expect("a swap in which both glide", run({"swap": [{"windows": {31: (12, 518), 32: (518, 12)}}] * 5}), "swap-1 w31: 18 places", "swap-1 w32: 18 places", "swap: 5 played, 5 with a vote, 5 meet the mark: glides")
    expect("what the polish judge misses is a miss", run({"across-link": good}, second={f"across-link-{n}": ["the polish judge's M6: a hop of 9 px at the end"] for n in (1, 2)}),
           "across-link-1: MISSES: the polish judge's M6: a hop of 9 px at the end", "5 with a vote, 3 meet the mark: STUTTERS")
    expect("a real app that keeps up", run({"across-link": good, "app-finder": good}), "finder: 5, 5, 5; 90; 0.60, 0.60; 0; 0; 0; ?: keeps up", "apps: 1 of 1 keep up")
    expect("one that takes longer than a frame", run({"across-link": good, "app-mail": [{"slow": {7: 21.0}}] * 5}), "mail: 5, 5, 0; 85; 0.60, 21.00; 5; 0; 0; ?: DOES NOT KEEP UP", "apps: 0 of 1 keep up")
    expect("once in five glides is let pass", run({"across-link": good, "app-mail": [{"slow": {7: 21.0}}] + good[1:]}), "mail: 5, 5, 4; 89; 0.60, 21.00; 1; 0; 0; ?: keeps up")
    expect("one that ends elsewhere", run({"across-link": good, "app-notes": [{"ends": 3}] * 5}), "0; 0; 3; ?: DOES NOT KEEP UP")
    expect("one whose glides were not paced is not told", run({"across-link": good, "app-mail": [{"late": {9: 30}}] * 5}), "mail: 5, 0, 0;", "too few paced glides to say", "apps: 0 of 0 keep up, 1 could not be told")
    expect("the window set back under a group's name is none of its glides", run({"across-link": good}, more=made_up("across-link-back", 2_000_000.0, {31: (632, 12)}, duration=0.0)[0]), "across-link: 5 played, 5 with a vote")
    expect("a bar during which the display stood still is unwitnessed", run({"across-link": good}, stuck_bars=3), "bar-1: no vote: UNWITNESSED: THE DISPLAY STOOD STILL for 917 ms:", "the bar: 5 played, 2 witnessed")
    expect("blind glides are counted among the pacers and have no say", run({"across-link": good, "blind-link": [{"late": {9: 30}}] * 5}), "blind-link (link): 5, 0; 16.67", "9; nobody listened", "verdict: glides")
    expect("where the display's beat faltered during a glide, as another process was told it", run({"blind-link": good}, bars=0, beats=read_pulse(["1000200 U link 61", "1000900 U link 48", "1000950 U late 120", "1002250 U link 45"])),
           "blind-link (link): 5, 5; 16.67, 16.67; 0.30, 0.30; 0.20, 0.20; 9; 2, 61")

    early = [(0, 0), (90, 20), (517, 100), (533, 200), (550, 300), (567, 400), (583, 450), (600, 480), (617, 495), (633, 500)]
    count += 1
    if ride(early, 0, 500, PERIOD, cause=480)["wait"] > 17 or ride(early, 0, 500, PERIOD, cause=480)["stale"] != 1 or ride(early, 0, 500, PERIOD, cause=50)["wait"] != 427:
        failures.append(f"a frame stamped before its cause is put a frame before the next: {ride(early, 0, 500, PERIOD, cause=480)}")
    strip = [(time, 0 if time < 100 else 100 if time < 167 else 300 if time < 183 else 500) for time in (0, 17, 33, 50, 67, 83, 100, 117, 150, 167, 183, 200)]
    count += 1
    if (ride(strip, 0, 500, PERIOD)["wait"], ride(strip, 0, 500, PERIOD)["display"]) != (67, 33):
        failures.append(f"a window that waits while the display goes on: {ride(strip, 0, 500, PERIOD)}")
    # Hidden frames: what is not told is not made up.
    told = ride([(0, 0), (100, 10), (117, 100), (133, None), (150, 300), (167, 400), (183, 500)], 0, 500, PERIOD)
    count += 1
    if told["frames"] != 5 or told["wait"] > 17 or abs(told["leap"] - 0.2) > 0.001:
        failures.append(f"a step over a frame in which the window was hidden is not told: {told}")
    enters = ride([(0, None), (100, None), (117, 900), (133, 700), (150, 600), (167, 560), (183, 550)], 1000, 550, PERIOD)
    count += 1
    if enters["frames"] != 5 or enters["from"] != 100:
        failures.append(f"a window that comes into view is counted from where it is first seen: {enters}")
    cpu = read_cpu(["app-mail before app 1.00", "app-mail after app 1.25", "app-mail before server 7.00", "app-mail after server 7.10"])
    count += 1
    if cpu != {"app-mail": {"app": (1.0, 1.25), "server": (7.0, 7.1)}}:
        failures.append(f"the processor's share: {cpu}")

    try:
        import numpy  # noqa: F401
        import PIL  # noqa: F401
        drawn = drawn_films()
        count += len(drawn)
        failures += [fault for fault in drawn if fault]
    except ImportError:
        print("– the ruler was not tried on drawn films: no numpy, or no Pillow, here (`make polish-selftest` where they are)")
    for failure in failures:
        print(f"✘ {failure}")
    print(f"{count - len(failures)} of {count} as they should be")
    return 1 if failures else 0


def drawn_films():
    """The ruler on films that are drawn and written as the camera writes them. A list with "" for what is as it should be."""
    import tempfile

    import numpy as np
    sys.path.insert(0, os.path.join(HERE, "..", "polish"))
    from film import write_film
    red, blue, faults = (255, 56, 60), (20, 120, 230), []

    def picture(places):
        """A menu bar, a Dock, and windows with a plain title bar and a red button in it, words in the middle, round corners and a shadow, the last in front. `places`: [(colour, x, y)]."""
        frame = np.zeros((768, 1024, 3), dtype=np.uint8)
        for colour, x, y in places:
            a, b, c, d = max(x, 0), min(x + 494, 1024), max(y, 0), min(y + 600, 768)
            if b > a and d > c:
                frame[c:d, max(a - 16, 0):min(b + 16, 1024)] = frame[c:d, max(a - 16, 0):min(b + 16, 1024)] * 0.6
                frame[c:d, a:b] = colour
                frame[c:min(y + 28, d), a:b] = (236, 236, 236)
                if 0 <= x < 1000 and y < 680:
                    frame[y + 7:y + 21, x + 8:x + 22] = (255, 95, 87)
                frame[min(y + 290, d):min(y + 310, d), min(max(x + 180, 0), 1024):min(max(x + 310, 0), 1024)] = (255, 255, 255)
                for corner in ((x, y), (x + 490, y), (x, y + 596), (x + 490, y + 596)):
                    if 0 <= corner[0] < 1020 and 0 <= corner[1] < 764:
                        frame[corner[1]:corner[1] + 4, corner[0]:corner[0] + 4] = 0
        frame[:30] = (230, 230, 230)
        frame[705:] = (70, 70, 74)
        return frame

    def film(name, windows, roads, lines=()):
        """Draws `roads`, {window: (colour, [(x, y)…])}, a frame a sixtieth, and follows them. The first in front."""
        began = 1_760_000_000_000
        act = read_log(made_up(name, began + 400, windows)[0] + list(lines))[name]
        length = max(len(road) for _, road in roads.values())
        with tempfile.TemporaryDirectory() as folder:
            write_film(folder, [picture([(colour, *road[min(index, len(road) - 1)]) for colour, road in reversed(list(roads.values()))]) for index in range(length)],
                       [began] + [began + 500 + round(index * PERIOD) for index in range(1, length)], visible=[0, 30, 1024, 675])
            return follow(folder, act)

    def check(what, got, wanted):
        faults.append("" if got == wanted else f"{what}: {got}, not {wanted}")

    across = [12, 35, 137, 265, 355, 418, 518]
    tracks, why = film("across-1", {31: (12, 518)}, {31: (red, [(x, 43) for x in across])})
    check("a window is followed to the pixel", [place for _, place in tracks[31]] if tracks else why, [float(x) for x in across])
    back = [518, 400, 300, 200, 137, 35, 12]
    tracks, why = film("swap-1", {31: (12, 518), 32: (518, 12)}, {31: (red, [(x, 43) for x in across]), 32: (blue, [(x, 43) for x in back])})
    check("in a swap the window in front", [place for _, place in tracks[31]] if tracks else why, [float(x) for x in across])
    check("and the one behind it, by whichever of its edges shows", [place for _, place in tracks[32]] if tracks else why, [float(x) for x in back])
    same = [12, 137, 265, 265, 418, 518]
    tracks, why = film("swap-2", {31: (12, 518), 32: (518, 12)}, {31: (red, [(x, 43) for x in same]), 32: (blue, [(x, 43) for x in (518, 400, 330, 265, 137, 12)])})
    check("one that is wholly hidden is not told", [place for _, place in tracks[32]] if tracks else why, [518.0, 400.0, 330.0, None, 137.0, 12.0])
    tracks, why = film("swap-3", {31: (12, 518), 32: (518, 12)}, {31: (red, [(x, 43) for x in (12, 400, 300, 518)]), 32: (blue, [(x, 43) for x in (518, 600, -100, 12)])})
    check("nor one of which neither edge shows: one behind the other window or in its shadow, one beyond the display", [place for _, place in tracks[32]] if tracks else why, [518.0, None, None, 12.0])
    leaves = [(12, 43), (200, 160), (600, 410), (900, 596), (1000, 659), (1015, 668), (1023, 673)]
    tracks, why = film("out-1", {31: (12, 1023)}, {31: (red, leaves)}, ["0 ask out-1 31 77 12 43 494 600 1023 673 494 600"])
    check("a window that leaves is followed while it shows", [place for _, place in tracks[31]] if tracks else why, [12.0, 200.0, 600.0, 900.0, None, None, None])
    tracks, why = film("in-1", {31: (1023, 12)}, {31: (red, list(reversed(leaves)))}, ["0 ask in-1 31 77 1023 673 494 600 12 43 494 600"])
    check("and one that comes from where it first shows", [place for _, place in tracks[31]] if tracks else why, [None, None, None, 900.0, 600.0, 200.0, 12.0])
    tracks, why = film("across-2", {31: (40, 518)}, {31: (red, [(x, 43) for x in across])})
    check("a film that has the window elsewhere than the log is no witness", (tracks, why), (None, "before the act the film has w31 at 12.0, the log at 40"))
    tracks, why = film("across-3", {31: (12, 518)}, {31: (red, [(x, 43) for x in across[:-1]])})
    check("nor one that ends before the window is there", (tracks, why), (None, "after the act the film has w31 at 418.0, the log at 518"))
    return faults


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
