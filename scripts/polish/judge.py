#!/usr/bin/env python3
"""The judge of polish: scores the films of scripts/mac-shell/films.sh against docs/POLISH.md.

Nobody is asked to look at Arbor and say whether it feels right. A hosted Mac films it, and this reads the films anywhere: what a
ruler can settle it measures, and for the rest it lays the frames out on sheets that an agent with eyes goes through, whose
verdicts (collab/polish/eyes-run-<n>.json) it counts like its own.

  judge.py score <run folder> [--json <file>] [--eyes <file>] [--stills <file>]
                                        every film in <run folder>/films: the table, the findings with the frames that show
                                        them, the score. Exit code 1 when the instruments fail their own test (the metronome)
  judge.py sheets <run folder> <folder> three sheets per scene: how it begins, the whole, how it ends
  judge.py measure <film folder>        everything that was measured of one film
  judge.py sheet <film folder> <png> [--from <ms>] [--to <ms>] [--columns n] [--crop x,y,w,h] [--zoom n]
                                        its frames side by side, each with its number and its time after the cause
  judge.py briefs <run folder> <score.json> <sheets folder> <folder> [n]
                                        for n (6) reviewers with eyes: brief-<k>.md, each with its share of the scenes, their sheets and the misses the
                                        ruler claims, to confirm or refute. REVIEWERS.md, beside this file, is what each reviewer is told
  judge.py eyes <run id> <commit> <verdicts.json>… > eyes-run-<n>.json
                                        the reviewers' files as one, in the form `score --eyes` reads
  judge.py frame <film folder> <n> <png>    one frame, whole
  judge.py curve <film folder>          time and progress, one line per frame: the easing curve as it was seen
  judge.py --self-test                  films drawn by studio.py, each wrong in one known way: every check must catch its own

Needs numpy and Pillow (and no Mac). The checks' numbers are docs/POLISH.md's: change them there first.
"""

import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

from film import Film, apart_by, near  # noqa: E402
from measure import TICK, cause_of, measure  # noqa: E402

PASS, MISS, UNSEEN = "pass", "miss", "unseen"
# What a miss costs, by how bad it is (docs/POLISH.md, "How bad a miss is").
WEIGHT = {1: 5, 2: 3, 3: 1}

MOVES = ("camera", "structure", "control")
SETTLES = MOVES + ("drag", "follow")
ALL = SETTLES + ("hold", "instant", "panel")
# Of Arbor's own windows, the levels of those that have no business on screen once things are at rest: the drop preview, the stage.
PASSING = (3, 4)


def ms(value):
    return f"{value:.0f} ms"


class Verdict:
    def __init__(self, status, said, frames=()):
        self.status, self.said, self.frames = status, said, list(frames)


def frame_at(m, time):
    return int(np.searchsorted(m["film"].times, time))


# Each check takes the measures of one film and returns a Verdict. `allow` is what the metronome showed the camera to be worth
# on the Mac that shot the films: nothing is held against Arbor that a motion known to be right shows as well.


def answers(m, allow):
    if m["cause_known"] != "exact":
        return Verdict(UNSEEN, "the film does not say when the key went down")
    if m["latency"] is None:
        return Verdict(MISS, "nothing on the display ever changed")
    limit = 100 + allow["latency"]
    return Verdict(PASS if m["latency"] <= limit else MISS, f"first change after {ms(m['latency'])} (at most {ms(limit)})",
                   [m["episodes"][0][2]])


def lasts(m, allow):
    motion = m["motion"]
    if not motion.seen or motion.fit is None:
        return Verdict(UNSEEN, "nothing could be followed from where it was to where it went")
    name, _, duration, error = motion.fit
    if error > 0.05:
        duration, name = motion.visible / 0.92, "no curve known; by what was seen"
    good = 400 <= duration <= 520
    return Verdict(PASS if good else MISS, f"meant to last {ms(duration)} ({name}), seen moving for {ms(motion.visible)}; 400 to 520")


def eased(m, allow):
    motion = m["motion"]
    if not motion.seen or motion.settle is None:
        return Verdict(UNSEEN, "nothing could be followed from where it was to where it went")
    faults = []
    if motion.settle < 1.4:
        faults.append(f"it does not slow down: the second half of the road takes {motion.settle:.1f} times as long as the first (at least 1.4)")
    if motion.overshoot > 2:
        faults.append(f"it goes {motion.overshoot:.0f} px too far and comes back")
    elif motion.backwards > 2:
        faults.append(f"it goes {motion.backwards:.0f} px backwards on the way")
    if motion.leap > 0.34 + allow["leap"]:
        faults.append(f"{motion.leap * 100:.0f}% of the road in one frame: a jump with a tail, not a glide")
    if faults:
        return Verdict(MISS, "; ".join(faults))
    return Verdict(PASS, f"slows down ({motion.settle:.1f}), never past the end, at most {motion.leap * 100:.0f}% of the road per frame")


def one_motion(m, allow):
    motion = m["motion"]
    faults, frames = [], []
    for spell in m["afterthoughts"]:
        # A few pixels are a hop, which is M6's.
        if 3 <= spell[5] <= 40:
            continue
        faults.append(f"something {'moves' if spell[5] else 'changes'} again {ms(spell[0] - m['cause'])} after the cause")
        frames.append(spell[2])
    if motion.seen:
        for push in motion.pushes:
            if push["left"] > 40:
                faults.append(f"a second push, {push['left']:.0f} px before the end, after a pause of {ms(push['pause'])}")
                frames.append(frame_at(m, push["time"]))
        if motion.spread > 0.1:
            faults.append(f"not in step: at one moment one edge was {motion.spread * 100:.0f}% of its road ahead of another")
        astray = [stray for stray in motion.strays if stray[2] > 6 * m["film"].scale]
        if astray:
            worst = max(astray, key=lambda stray: stray[2])
            faults.append(f"not in step: {len(astray)} edges that come in or go out over the display's edge are up to {worst[2]:.0f} px from where "
                          "the others' progress puts them")
    elif not m["episodes"]:
        return Verdict(UNSEEN, "nothing moved")
    if faults:
        return Verdict(MISS, "; ".join(faults), frames)
    return Verdict(PASS, "one motion, everything in step" if motion.seen else "one spell of change")


def smooth(m, allow):
    motion = m["motion"]
    if not motion.seen and not m["stalls"]:
        return Verdict(UNSEEN, "nothing could be followed")
    limit = 2 * TICK + 2 + allow["gap"]
    if m["stalls"]:
        stood, frame = max(m["stalls"])
        return Verdict(MISS, f"the display stands still for {ms(stood)} in the middle of the change, then cuts on", [frame - 1, frame])
    said = f"longest wait between two frames under way {ms(m['gap'])} (at most {ms(limit)}), {m['pace']:.0f} frames a second"
    return Verdict(PASS if m["gap"] <= limit else MISS, said)


def no_hop(m, allow):
    motion = m["motion"]
    if not motion.seen and not m["wobbles"] and not m["afterthoughts"]:
        return Verdict(UNSEEN, "nothing could be followed to its end")
    faults, frames = [], []
    if motion.seen:
        hops = [push for push in motion.pushes if push["left"] <= 40]
        if hops:
            worst = max(hops, key=lambda push: push["left"])
            faults.append(f"hops {worst['left']:.0f} px at the end")
            frames += [frame_at(m, worst["time"]) - 1, frame_at(m, worst["time"])]
        if motion.starts:
            worst = max(motion.starts, key=lambda start: start[1])
            faults.append(f"hops {worst[1]:.0f} px at the start")
            frames += [frame_at(m, worst[0]) - 1, frame_at(m, worst[0])]
    for spell in m["afterthoughts"]:
        if 3 <= spell[5] <= 40:
            faults.append(f"hops {spell[5]:.0f} px, {ms(spell[0] - m['cause'])} after the cause")
            frames += [spell[2] - 1, spell[2]]
    if m["wobbles"]:
        _, _, frame, off = max(m["wobbles"], key=lambda wobble: wobble[3])
        faults.append(f"{len(m['wobbles'])} edges that end where they began are up to {off:.0f} px elsewhere meanwhile")
        frames.append(frame)
    if faults:
        return Verdict(MISS, "; ".join(faults) + " (at most 2)", frames)
    return Verdict(PASS, "stand-ins begin where the windows are and glide to where they stay")


def softly(m, allow):
    step, frame = 0, None
    if m["looks"]:
        _, step, frame = max(m["looks"], key=lambda look: look[1])
    if step > 26:
        return Verdict(MISS, f"a window changes its look by {step / 2.55:.0f}% of full scale between two frames (at most 10%: a fade of some 130 ms)",
                       [frame - 1, frame])
    # That nothing abrupt was found says something only where a window was followed all the way.
    if not m["motion"].seen:
        return Verdict(UNSEEN, "nothing could be followed")
    if m["looks"]:
        return Verdict(PASS, f"what changes its look fades: at most {step / 2.55:.0f}% of full scale between two frames")
    return Verdict(PASS, "nothing changes its look")


def itself(m, allow):
    if not m["motion"].seen and not m["costumes"]:
        return Verdict(UNSEEN, "nothing could be followed")
    if m["costumes"]:
        return Verdict(MISS, "windows travel as something else: a card, not their picture")
    return Verdict(PASS, "every window looks like itself all the way")


def no_blink(m, allow):
    if m["scan"].background is None:
        return Verdict(UNSEEN, "no plain wallpaper to tell windows from")
    if m["blinks"]:
        _, frame, gone = m["blinks"][0]
        return Verdict(MISS, f"{len(m['blinks'])} things vanish for {ms(gone)} and come back", [frame - 1, frame, frame + 1])
    return Verdict(PASS, "nothing goes away and comes back")


def no_flash(m, allow):
    if m["washes"]:
        frame, shown, share = m["washes"][0]
        return Verdict(MISS, f"{share * 100:.0f}% of the room is something else for {ms(shown)}", [frame - 1, frame, frame + 1])
    if m["flashes"]:
        track, shown = m["flashes"][0]
        rect = track.rects[0]
        return Verdict(MISS, f"{len(m['flashes'])} things show for a moment: the first for {ms(shown)}, "
                       f"{rect.right - rect.left}×{rect.bottom - rect.top} px at {rect.left},{rect.top}", [track.indices[0]])
    return Verdict(PASS, "nothing shows for a moment only")


def rests(m, allow):
    if m["cause_known"] != "exact" or m["rest"] is None:
        return Verdict(UNSEEN, "the film does not say when the key went down")
    limit = 700 + allow["latency"]
    return Verdict(PASS if m["rest"] <= limit else MISS, f"at rest {ms(m['rest'])} after the cause (at most {ms(limit)})", [m["episodes"][0][3]])


def bars(m, allow):
    menu, dock = m["bars"]
    faults = []
    # Windows pass under both, and both let some of that through. What is theirs (the bar's ground and words, the Dock's icons) stays.
    if menu > 0.25:
        faults.append(f"{menu * 100:.0f}% of the menu bar is plainly another colour at one moment")
    if dock > 0.1:
        faults.append(f"{dock * 100:.0f}% of what the Dock shows is plainly another colour at one moment")
    return Verdict(MISS, "; ".join(faults)) if faults else Verdict(PASS, "the menu bar and the Dock stay as they are")


def at_once(m, allow):
    """For Reduce Motion, and for whatever is not meant to move: the end, at once, and nothing in between."""
    if not m["episodes"]:
        return Verdict(UNSEEN, "nothing changed")
    first = m["episodes"][0]
    took = first[1] - first[0]
    limit = 100 + allow["gap"]
    return Verdict(PASS if took <= limit else MISS, f"from the first change to the last {ms(took)} (at most {ms(limit)}), in {first[3] - first[2] + 1} frames",
                   list(range(first[2], min(first[3], first[2] + 5) + 1)))


def few_places(m, allow):
    worst = 0
    for track in m["scan"].tracks:
        if track.detail:
            continue
        places = []
        for time, rect in zip(track.times, track.rects):
            if time >= m["cause"] - 5 and not any(max(abs(a - b) for a, b in zip(rect.edges, known)) <= 2 for known in places):
                places.append(rect.edges)
        worst = max(worst, len(places))
    if not m["episodes"]:
        return Verdict(UNSEEN, "nothing changed")
    return Verdict(PASS if worst <= 2 else MISS, f"a window is seen in at most {worst} places (where it was, where it is; at most 2)")


def rests_of(m):
    """The windows in the film's last frame, whole ones only."""
    return [rect for rect in m["scan"].rects[-1] if not rect.detail and not rect.partial]


def even_gaps(m, allow):
    """On the last frame, from the edges of the docked windows outwards: how many pixels of wallpaper until the next thing."""
    film, scan = m["film"], m["scan"]
    docked = [frame for window, frame in film.after.items() if film.how.get(window) == "docked"]
    if scan.background is None or max(scan.background) > 60:
        return Verdict(UNSEEN, "on a light wallpaper shadows fill the gaps: for eyes")
    if not docked:
        return Verdict(UNSEEN, "the film does not say which windows are docked, or none is")
    picture = film.frame(len(film) - 1)
    empty = near(picture, scan.background, 24)
    x0, y0, x1, y1 = scan.room
    gaps = []
    for x, y, w, h in docked:
        left, top, right, bottom = (int(round(value * film.scale)) for value in (x, y, x + w, y + h))
        if left < x0 or top < y0 or right > x1 or bottom > y1:
            continue
        across, down = (top + bottom) // 2, (left + right) // 2
        # From well inside the window, so that a frame that is a pixel off is found out too.
        for line, start, step, low, high in ((empty[across, :], left + 8, -1, x0, x1), (empty[across, :], right - 8, 1, x0, x1),
                                             (empty[:, down], top + 8, -1, y0, y1), (empty[:, down], bottom - 8, 1, y0, y1)):
            place = start
            while low <= place < high and not line[place]:
                place += step
            run = 0
            # As far as the room goes: under the bars the wallpaper goes on.
            while low <= place < high and line[place]:
                place += step
                run += 1
            gaps.append(run)
    # What is wider is no gap: the Desktop's part, or room nobody takes.
    gaps = [gap for gap in gaps if 0 < gap <= 40 * film.scale]
    if not gaps:
        return Verdict(UNSEEN, "no docked window has a neighbour at the end")
    inner = sorted(gaps)
    return Verdict(PASS if inner[-1] - inner[0] <= 1 * film.scale else MISS, f"gaps from {inner[0]} to {inner[-1]} px")


def dragged(m):
    """The thing under the pointer when the button went down: the largest whose top is about there."""
    film = m["film"]
    downs = [button for button in film.buttons if button[1] == "down"]
    if not downs:
        return None, None
    time, _, x, y = downs[0]
    x, y = x * film.scale, y * film.scale
    found = []
    for track in m["scan"].tracks:
        if track.detail or track.times[0] > time:
            continue
        rect = [rect for when, rect in zip(track.times, track.rects) if when <= time][-1]
        # Its title bar may not have been found with it: then the pointer is just above what was.
        if not rect.thin and rect.left <= x <= rect.right and rect.top - 40 * film.scale <= y <= rect.top + 40 * film.scale:
            found.append((rect.area, track))
    return (max(found, key=lambda pair: pair[0])[1] if found else None), downs[0]


def not_pulled(m, allow):
    film = m["film"]
    track, down = dragged(m)
    ups = [button for button in film.buttons if button[1] == "up"]
    if track is None or not ups or len(film.pointer) < 5:
        return Verdict(UNSEEN, "no window could be followed under the pointer")
    times = np.array([down[0]] + [point[0] for point in film.pointer], dtype=float)
    xs, ys = (np.array([down[which + 1]] + [point[which] for point in film.pointer], dtype=float) * film.scale for which in (1, 2))
    # Only where all of it is seen, as it was when it was taken: not under a preview's tint, not half behind the Dock, not partly covered.
    taken = [rect for time, rect in zip(track.times, track.rects) if time <= down[0]][-1]
    held = [(time, rect) for time, rect in zip(track.times, track.rects)
            if down[0] < time < ups[0][0] and not any(rect.cut) and not rect.ragged and apart_by(rect.colour, taken.colour) <= 20
            and abs((rect.right - rect.left) - (taken.right - taken.left)) <= 3 and abs((rect.bottom - rect.top) - (taken.bottom - taken.top)) <= 34]
    if len(held) < 5:
        return Verdict(UNSEEN, "the dragged window was seen whole in too few frames")
    # By its left and its bottom: the top is where its title bar is, if that was found. macOS's own dragging trails the pointer, so the
    # window may be wherever the pointer has put it in the last tenth of a second. Anywhere else, somebody pulled.
    grip = (taken.left - down[2] * film.scale, taken.bottom - down[3] * film.scale)
    worst, where = 0.0, held[0][0]
    for time, rect in held:
        lately = (times >= time - 100) & (times <= time + 5)
        for value, line in ((rect.left - grip[0], xs), (rect.bottom - grip[1], ys)):
            recent = np.concatenate([line[lately], [np.interp(time - 100, times, line), np.interp(time, times, line)]])
            off = max(recent.min() - value, value - recent.max(), 0)
            if off > worst:
                worst, where = float(off), time
    limit = 6 * film.scale
    return Verdict(PASS if worst <= limit else MISS, f"up to {worst:.0f} px from where the pointer has had it in the last 100 ms (at most {limit})", [frame_at(m, where)])


def preview_true(m, allow):
    film = m["film"]
    previews = [frame for when, level, frame in film.overlays if when == "held" and level == 3]
    track, _ = dragged(m)
    if not previews:
        return Verdict(UNSEEN, "no drop preview was up while the drag was held, or the film does not say")
    if track is None or track.indices[-1] < len(film) - 1:
        return Verdict(UNSEEN, "the dragged window could not be followed to its rest")
    x, y, w, h = (value * film.scale for value in previews[0])
    off = max(abs(a - b) for a, b in zip(track.last.edges, (x, y, x + w, y + h)))
    return Verdict(PASS if off <= 2 * film.scale else MISS, f"the window rests up to {off:.0f} px from where the preview was (at most 2)")


def spells_after_keys(m):
    """For every key or click of the scene: (its time, the first spell of change after it, before the next one)."""
    film = m["film"]
    action = film.time_of("action") or 0
    causes = sorted([time for time, what in film.keys if what == "down" and time >= action]
                    + [time for time, what, _, _ in film.buttons if what == "down" and time >= action])
    found = []
    for place, cause in enumerate(causes):
        following = causes[place + 1] if place + 1 < len(causes) else float("inf")
        spell = next((spell for spell in m["episodes"] if cause - 5 <= spell[0] < following), None)
        found.append((cause, spell))
    return found


def panel_prompt(m, allow):
    found = spells_after_keys(m)
    if not found:
        return Verdict(UNSEEN, "the film does not say when the keys went down")
    faults, frames = [], []
    for cause, spell in found:
        if spell is None:
            faults.append("a key changes nothing")
            continue
        if spell[0] - cause > 100 + allow["latency"]:
            faults.append(f"first change {ms(spell[0] - cause)} after the key")
            frames.append(spell[2])
        if spell[1] - spell[0] > 250 + allow["gap"]:
            faults.append(f"it takes {ms(spell[1] - spell[0])} to come or go")
            frames += [spell[2], spell[3]]
    if faults:
        return Verdict(MISS, "; ".join(faults) + " (at most 100 ms, 250 ms)", frames)
    return Verdict(PASS, "; ".join(f"{ms(spell[0] - cause)} after the key, over {ms(spell[1] - spell[0])}" for cause, spell in found))


def panel_still(m, allow):
    found = [spell for _, spell in spells_after_keys(m) if spell is not None]
    if not found:
        return Verdict(UNSEEN, "nothing changed")
    for spell in found:
        boxes = [m["scan"].boxes_changed[index] for index in range(spell[2], spell[3] + 1) if m["scan"].boxes_changed[index] is not None]
        wander = max(max(abs(a - b) for a, b in zip(box, spell[4])) for box in boxes)
        if len(boxes) > 2 and wander > 6 * m["film"].scale:
            return Verdict(MISS, f"what changes wanders by {wander} px while it comes or goes: a slide or a growth, not a fade", [spell[2], spell[3]])
    return Verdict(PASS, "it fades, or is there, in one place")


def not_yet(m, allow):
    return Verdict(UNSEEN, "the judge cannot measure this yet")


def nothing_left(m, allow):
    film = m["film"]
    if not film.after and not any(when == "after" for when, _, _ in film.overlays):
        return Verdict(UNSEEN, "the film does not say which panels were up at its end")
    left = [level for when, level, _ in film.overlays if when == "after" and level in PASSING]
    return Verdict(MISS, f"still up at the end: panels at levels {left}") if left else Verdict(PASS, "no stage and no preview is left")


CHECKS = [
    # id, what it asks, how bad a miss is, the kinds of scene it is asked of, the function
    ("M1", "answers at once", 2, ALL, answers),
    ("M2", "lasts about 460 ms", 2, SETTLES, lasts),
    ("M3", "eased: quick off the mark, gentle at the end, never past it", 2, SETTLES, eased),
    ("M4", "one motion per action", 1, SETTLES, one_motion),
    ("M5", "smooth", 2, SETTLES, smooth),
    ("M6", "no hop when the real window takes over", 1, SETTLES, no_hop),
    ("M7", "what changes its look does so softly", 1, SETTLES, softly),
    ("M8", "nothing flickers", 1, ALL, no_blink),
    ("M9", "nothing flashes", 1, ALL, no_flash),
    ("M10", "at rest soon", 3, SETTLES, rests),
    ("M11", "the menu bar and the Dock are left alone", 2, ALL, bars),
    ("M12", "a window looks like itself all the way", 3, SETTLES, itself),
    ("M13", "nothing is left behind", 1, tuple(kind for kind in ALL if kind != "control"), nothing_left),
    ("S8", "even gaps", 3, MOVES[:2] + ("drag", "instant"), even_gaps),
    ("R1", "without motion: the end at once, nothing in between", 1, ("instant",), at_once),
    ("R2", "without motion: the same end", 2, ("instant",), not_yet),
    ("R3", "without motion: no slide anywhere", 2, ("instant",), few_places),
    ("D1", "Arbor never pulls what is being dragged", 1, ("drag",), not_pulled),
    ("D2", "the preview tells the truth", 2, ("drag",), preview_true),
    ("D3", "the preview comes and goes softly, once", 2, ("drag",), not_yet),
    ("D4", "others make room in one motion", 1, ("drag",), not_yet),
    ("G1", "what follows the fingers follows them closely", 1, ("follow",), not_yet),
    ("P1", "a panel is there at once and gone at once", 2, ("panel",), panel_prompt),
    ("P2", "a panel fades or is there; it does not jump", 2, ("panel",), panel_still),
]
NO_LEEWAY = {"latency": 0, "gap": 0, "leap": 0}

# What an agent with eyes asks of every scene's sheet (docs/POLISH.md, "Eyes").
EYES = [
    ("E1", "one thing happens, and one can tell what", 2),
    ("E2", "no frame is ugly", 2),
    ("E3", "it could be macOS's own", 3),
    ("E4", "it says what is needed and no more", 3),
]

# The scenes that count: name, kind, which of the five moves it stands for (0: none). One that was not filmed, because the script
# failed or because Arbor cannot do it yet, scores nothing.
MOVES_FILMED_TWICE = [
    ("tab-make", "drag", 1), ("tab-change", "structure", 1), ("tab-drag-group", "drag", 1),
    ("dock-drag-edge", "drag", 2), ("dock-drag-beside", "drag", 2), ("rearrange", "drag", 2),
    ("double-click-desktop", "camera", 3), ("double-click-again", "camera", 3), ("double-click-title", "camera", 3),
    ("rectangle", "drag", 4), ("save-view", "panel", 4), ("view", "camera", 4),
    ("show-everything", "camera", 5), ("pinch-in", "camera", 5), ("pinch-out", "camera", 5), ("zoom-continuous", "follow", 5),
    ("frame", "camera", 0),
]
SCENES = MOVES_FILMED_TWICE + [("dark-" + name, kind, move) for name, kind, move in MOVES_FILMED_TWICE] + [
    ("tile", "structure", 2), ("tile-open", "camera", 2), ("tile-back", "camera", 2),
    ("dock-key", "structure", 0), ("neighbour", "camera", 0), ("back", "camera", 0), ("out", "camera", 0), ("in", "camera", 0),
    ("twice-quickly", "camera", 0), ("peek", "hold", 0), ("seam", "drag", 0), ("desktop", "camera", 0), ("desktop-back", "camera", 0),
    ("float", "structure", 0), ("undo", "structure", 0), ("drag-out", "drag", 0), ("close", "structure", 0),
    ("panel-shortcuts", "panel", 0), ("panel-go-to", "panel", 0), ("panel-minimap", "panel", 0), ("panel-menu", "panel", 0),
    ("quit", "instant", 0),
    ("reduced-dock-key", "instant", 0), ("reduced-frame", "instant", 0), ("reduced-show-everything", "instant", 0),
    ("eight-frame", "camera", 0), ("eight-show-everything", "camera", 0),
]

# Whatever Arbor draws of its own, and what is asked of a picture of each (docs/POLISH.md, "Panels"): check, severity.
PANELS = ["heads-up line", "drop preview", "tile", "seam", "focus ring", "peek outline", "rectangle", "minimap", "go to", "shortcuts",
          "name field", "menu", "settings", "coach", "setup check", "tab strip"]
STILLS = [("S1 at 1x", 2), ("S1 at 2x", 2), ("S2", 3), ("S3", 1), ("S4 light", 2), ("S4 dark", 2), ("S6", 2)]

# What the metronome's films must say, or the instruments are not to be believed: kind -> the checks that must miss.
METRONOME = {"good": [], "linear": ["M3"], "slow": ["M2"], "twice": ["M4"], "hop": ["M6"], "flash": ["M9"]}


def complete(m):
    """Numbers that need the film's own frames rather than a window's road."""
    film, motion = m["film"], m["motion"]
    m["gap"], m["pace"] = 0.0, 0.0
    if motion.seen:
        late = motion.marks[0.95] or motion.last
        under_way = film.times[(film.times >= motion.first - m["tick"] - 1) & (film.times <= late + 1)]
        if len(under_way) > 1:
            m["gap"] = float(np.diff(under_way).max())
            m["pace"] = 1000 * (len(under_way) - 1) / float(under_way[-1] - under_way[0])
    return m


def judge(folder, allow=None):
    film = Film(folder)
    m = complete(measure(film))
    verdicts = {}
    for identifier, _, _, kinds, check in CHECKS:
        if film.kind in kinds:
            verdicts[identifier] = check(m, allow or NO_LEEWAY)
            # Of a film in which nothing happens, or whose end is missing, nothing good can be said either.
            if film.dropped:
                verdicts[identifier] = Verdict(UNSEEN, f"the camera ran out of room: the film's last {film.dropped} frames are missing")
            elif not m["episodes"] and verdicts[identifier].status == PASS:
                verdicts[identifier] = Verdict(UNSEEN, "nothing happens in the film")
    return m, verdicts


# MARK: Looking


def sheet(film, path, since=None, until=None, columns=6, crop=None, zoom=None, cause=None, only=None):
    """Lays frames out side by side. Times are counted from the cause."""
    cause = cause if cause is not None else int(film.times[0])
    chosen = []
    for index, time, picture, _ in film.frames():
        if only is not None and index not in only:
            continue
        if (since is not None and time - cause < since) or (until is not None and time - cause > until):
            continue
        part = picture if crop is None else picture[crop[1]:crop[1] + crop[3], crop[0]:crop[0] + crop[2]]
        chosen.append((index, time - cause, Image.fromarray(part)))
    if not chosen:
        raise SystemExit("judge.py: no frames in that stretch")
    width, height = chosen[0][2].size
    factor = zoom if zoom else min(1.0, 340 / width)
    cell = (max(int(width * factor), 1), max(int(height * factor), 1))
    rows = (len(chosen) + columns - 1) // columns
    page = Image.new("RGB", (columns * (cell[0] + 6) + 6, rows * (cell[1] + 20) + 6), (70, 70, 76))
    draw = ImageDraw.Draw(page)
    for place, (index, time, picture) in enumerate(chosen):
        x, y = 6 + (place % columns) * (cell[0] + 6), 6 + (place // columns) * (cell[1] + 20)
        page.paste(picture.resize(cell, Image.NEAREST if factor > 1 else Image.LANCZOS), (x, y + 14))
        draw.text((x + 2, y + 1), f"#{index}  {time:+d} ms", fill=(255, 255, 255))
    page.save(path)
    return len(chosen)


# MARK: The score


def leeway(results):
    """What a motion known to be right looks like through this camera on this Mac."""
    good = results.get("metronome-good")
    if not good or not good[0]["motion"].seen:
        return dict(NO_LEEWAY)
    m = good[0]
    return {
        # The metronome's mark is made when the animation is handed over, so what follows is macOS's and the camera's time.
        "latency": max(0, (m["latency"] or 0) - 2 * TICK),
        "gap": max(0, m["gap"] - 2 * TICK),
        "leap": max(0, m["motion"].leap - 0.2),
    }


def score(folder, eyes_path=None, stills_path=None, out=sys.stdout):
    films = os.path.join(folder, "films")
    filmed = sorted(name for name in os.listdir(films) if os.path.isfile(os.path.join(films, name, "film.log")))
    results = {}
    for name in [name for name in filmed if name.startswith("metronome-")]:
        results[name] = judge(os.path.join(films, name))
    allow = leeway(results)
    for name in [name for name in filmed if not name.startswith("metronome-")]:
        results[name] = judge(os.path.join(films, name), allow)

    # The same keys with and without motion, from the same beginning: the session with pictures is the one that has it.
    for name in ("dock-key", "frame", "show-everything"):
        still, moving = results.get("reduced-" + name), results.get("pictures-" + name)
        if not still or not moving:
            continue
        a, b = rests_of(still[0]), rests_of(moving[0])
        if not a or len(a) != len(b):
            still[1]["R2"] = Verdict(MISS if a and b else UNSEEN, f"{len(a)} windows at rest without motion, {len(b)} with")
            continue
        off = max(min(max(abs(p - q) for p, q in zip(one.edges, other.edges)) for other in b) for one in a)
        still[1]["R2"] = Verdict(PASS if off <= 1 else MISS, f"windows rest within {off} px of where they rest with motion (at most 1)")

    print("## The instruments\n", file=out)
    trusted = True
    for kind, wanted in METRONOME.items():
        result = results.get(f"metronome-{kind}")
        if result is None:
            print(f"- metronome {kind}: NOT FILMED", file=out)
            trusted = False
            continue
        missed = sorted(identifier for identifier, verdict in result[1].items() if verdict.status == MISS)
        # The good film proves nothing unless the ruler could follow it.
        unseen = [identifier for identifier in (wanted or ["M2", "M3", "M4", "M5", "M6"]) if result[1][identifier].status == UNSEEN]
        right = all(identifier in missed for identifier in wanted) and (wanted or not missed) and not unseen
        trusted &= right
        print(f"- metronome {kind}: {'as it should be' if right else 'WRONG'}: missed {', '.join(missed) or 'nothing'}"
              f" (must miss {', '.join(wanted) or 'nothing'})", file=out)
    print(f"- allowed for this camera on this Mac: {ms(allow['latency'])} of delay, {ms(allow['gap'])} between frames\n", file=out)

    def read(path):
        if not path:
            return {}
        with open(path, encoding="utf-8") as file:
            return json.load(file)

    seen_by_eye = read(eyes_path)
    # Verdicts are about frames, so about one run's films and no other's.
    if seen_by_eye and str(seen_by_eye.get("run")) not in os.path.basename(os.path.normpath(folder)):
        raise SystemExit(f"judge.py: {eyes_path} is about run {seen_by_eye.get('run')}, not about {folder}")
    eyes, stills = seen_by_eye.get("scenes", {}), read(stills_path).get("panels", {})
    cells = []  # (scene or panel, check, title, severity, move, Verdict)
    table = []
    for name, kind, move in SCENES:
        row = {}
        for identifier, title, severity, kinds, _ in CHECKS:
            if kind not in kinds:
                continue
            verdict = results[name][1].get(identifier) if name in results else Verdict(UNSEEN, "not filmed")
            if verdict is None:
                verdict = Verdict(UNSEEN, f"filmed as {results[name][0]['film'].kind}, not as {kind}")
            # A miss that somebody with eyes could not find in the frames is no finding. It is no pass either: nothing was measured.
            fooled = eyes.get(name, {}).get("refuted", {}).get(identifier)
            if verdict.status == MISS and fooled:
                verdict = Verdict(UNSEEN, "the ruler was fooled, say eyes")
            if eyes.get(name, {}).get("void"):
                verdict = Verdict(UNSEEN, "the film does not show its scene, say eyes")
            cells.append((name, identifier, title, severity, move, verdict))
            row[identifier] = verdict.status
        for identifier, title, severity in EYES:
            seen = eyes.get(name, {}).get(identifier) if name in results and not eyes.get(name, {}).get("void") else None
            verdict = Verdict(seen["status"], seen["said"], seen.get("frames", [])) if seen else Verdict(UNSEEN, "nobody has gone through the sheet")
            cells.append((name, identifier, title, severity, move, verdict))
            row[identifier] = verdict.status
        table.append((name, kind, move, row))
    for panel in PANELS:
        for identifier, severity in STILLS:
            seen = stills.get(panel, {}).get(identifier)
            verdict = Verdict(seen["status"], seen["said"]) if seen else Verdict(UNSEEN, "no picture has been measured")
            cells.append((panel, identifier, "", severity, 0, verdict))

    total = sum(WEIGHT[cell[3]] for cell in cells)
    earned = sum(WEIGHT[cell[3]] for cell in cells if cell[5].status == PASS)
    seen = sum(WEIGHT[cell[3]] for cell in cells if cell[5].status != UNSEEN)
    number = 100 * earned / total

    identifiers = [check[0] for check in CHECKS] + [check[0] for check in EYES]
    sign = {PASS: "✔", MISS: "✘", UNSEEN: "·", None: " "}
    print("## The table (✔ passes, ✘ misses, · could not be seen, which counts as a miss)\n", file=out)
    print("| scene | kind | move | " + " | ".join(identifiers) + " |", file=out)
    print("|---|---|---|" + "---|" * len(identifiers), file=out)
    for name, kind, move, row in table:
        print(f"| {name} | {kind} | {move or ''} | " + " | ".join(sign[row.get(identifier)] for identifier in identifiers) + " |", file=out)

    trials = [name for name in filmed if name not in {scene[0] for scene in SCENES} and not name.startswith("metronome-")]
    if trials:
        print("\n## Judged, not counted\n", file=out)
        for name in trials:
            said = "; ".join(f"{identifier} {verdict.status}" + (f" ({verdict.said})" if verdict.status == MISS else "")
                             for identifier, verdict in results[name][1].items() if verdict.status != PASS)
            print(f"- `{name}`: {said or 'passes all that was asked'}", file=out)

    print("\n## Findings, the worst first\n", file=out)
    misses = [cell for cell in cells if cell[5].status == MISS]
    for name, identifier, title, severity, move, verdict in sorted(misses, key=lambda cell: (cell[3], cell[1], cell[0])):
        where = f" (frames {', '.join(map(str, verdict.frames))})" if verdict.frames else ""
        print(f"- **severity {severity}** {identifier} {title}: `{name}`: {verdict.said}{where}", file=out)
    print("\n## Not seen\n", file=out)
    reasons = {}
    for name, identifier, _, _, _, verdict in cells:
        if verdict.status == UNSEEN:
            reasons.setdefault(verdict.said, {}).setdefault(name, []).append(identifier)
    for said, where in reasons.items():
        names = ", ".join(f"`{name}` ({' '.join(found)})" if len(where) <= 12 else f"`{name}`" for name, found in where.items())
        print(f"- {said}: {names}", file=out)

    gate = [cell for cell in cells if cell[4] and cell[3] <= 2 and cell[5].status != PASS]
    worst = sum(1 for cell in misses if cell[3] == 1)
    print(f"\n## Score: {number:.1f} of 100 ({earned} of {total} points); seen {100 * seen / total:.0f}%; {worst} misses of severity 1", file=out)
    print(f"The rubric {'PASSES' if not gate and number >= 90 else 'does not pass'}: {len(gate)} cells of severity 1 or 2 in the five moves "
          "miss or are unseen.", file=out)
    if not trusted:
        print("\nTHE INSTRUMENTS FAILED THEIR OWN TEST: the score above is not to be believed.", file=out)
    return {
        "score": round(number, 1), "earned": earned, "total": total, "seen": round(100 * seen / total, 1), "trusted": trusted,
        "leeway": allow, "gate": len(gate), "severity1": worst,
        "cells": [{"where": name, "check": identifier, "severity": severity, "move": move, "status": verdict.status, "said": verdict.said,
                   "frames": [int(frame) for frame in verdict.frames]} for name, identifier, _, severity, move, verdict in cells],
    }


# MARK: The judge judged


def self_test():
    import studio

    # name -> (how the film is wrong, the checks that must miss, the checks that may miss besides)
    cases = {
        "good": ({}, [], []),
        "good-out": ({"start": studio.FRAMED, "end": studio.GRID}, [], []),
        "camera-at-30": ({"fps": 30}, [], ["M5"]),
        "lazy": ({"latency": 300}, ["M1"], ["M10"]),
        "slow": ({"seconds": 0.9}, ["M2", "M10"], []),
        "hasty": ({"seconds": 0.2}, ["M2"], []),
        "linear": ({"curve": (0, 0, 1, 1)}, ["M3"], []),
        "ease-in-out": ({"curve": (0.42, 0, 0.58, 1)}, ["M3"], []),
        "overshoot": ({"overshoot": 0.08}, ["M3"], ["M6"]),
        "twice": ({"pause": (0.3, 0.5)}, ["M4"], ["M2", "M3", "M10"]),
        "twice-shortly": ({"pause": (0.3, 0.2)}, ["M4"], ["M2", "M3", "M5", "M10"]),
        "afterthought": ({"afterthought": True}, ["M4"], []),
        "out-of-step": ({"lag": (studio.GREEN, 0.15), "start": studio.FRAMED, "end": studio.GRID}, ["M4"], []),
        "stutter": ({"stutter": (4, 9)}, ["M5"], ["M2", "M3"]),
        "hop": ({"hop": 7}, ["M6"], []),
        "cards": ({"cards": True}, ["M7", "M12"], []),
        "cards-that-fade": ({"cards": True, "fade": 9}, ["M12"], []),
        "cards-out-of-place": ({"cards": True, "fade": 9, "offset": 5}, ["M6", "M12"], []),
        "preview-left": ({"left": 3}, ["M13"], []),
        "blink": ({"blink": True}, ["M8"], ["M7", "M9"]),
        "good-and-not-a-frame-more": ({"words": False}, [], []),
        "flash": ({"flash": True}, ["M9"], []),
        "flash-at-the-edge": ({"flash": (0, 420, 150, 110)}, ["M9"], []),
        "flash-of-everything": ({"flash": (0, 31, 1024, 674)}, ["M9"], ["M7", "M8"]),
        "bars": ({"bars": True}, ["M11"], []),
        "at-once": ({"instant": True, "kind": "instant"}, [], []),
        "not-at-once": ({"kind": "instant"}, ["R1", "R3"], []),
        "uneven": ({"end": {**studio.FRAMED, studio.RED: (12, 43, 996, 650)}}, ["S8"], []),
    }
    # The same for what is drawn by another hand: name -> (who draws it, how it is wrong, must miss, may miss)
    others = {
        "drag": (studio.shoot_drag, {}, [], []),
        "drag-that-rests-in-the-room": (studio.shoot_drag, {"drop": (760, 300)}, [], []),
        "drag-under-a-tint": (studio.shoot_drag, {"tint": True}, [], []),
        "drag-pulled": (studio.shoot_drag, {"pull": 30}, ["D1"], []),
        "drag-preview-lies": (studio.shoot_drag, {"preview_off": 8}, ["D2"], []),
        "panel": (studio.shoot_panel, {}, [], []),
        "panel-by-a-click": (studio.shoot_panel, {"click": True}, [], []),
        "panel-late": (studio.shoot_panel, {"late": 300}, ["P1", "M1"], []),
        "panel-slow": (studio.shoot_panel, {"fade": 30}, ["P1"], []),
        "panel-slides": (studio.shoot_panel, {"slide": 60}, ["P2"], []),
    }
    cases = {name: (studio.shoot, *case) for name, case in cases.items()} | others
    failures = 0
    with tempfile.TemporaryDirectory() as folder:
        for name, (draw, faults, must, may) in cases.items():
            draw(os.path.join(folder, name), **faults)
            _, verdicts = judge(os.path.join(folder, name))
            missed = [identifier for identifier, verdict in verdicts.items() if verdict.status == MISS]
            unseen = [identifier for identifier, verdict in verdicts.items() if verdict.status == UNSEEN and verdict.said != not_yet(None, None).said]
            wrong = [f"{identifier} did not miss" for identifier in must if identifier not in missed]
            wrong += [f"{identifier} missed: {verdicts[identifier].said}" for identifier in missed if identifier not in must + may]
            wrong += [f"{identifier} saw nothing: {verdicts[identifier].said}" for identifier in unseen]
            failures += bool(wrong)
            print(f"{'✘' if wrong else '✔'} {name}: missed {', '.join(missed) or 'nothing'}" + "".join(f"\n    {line}" for line in wrong))
    print(f"{len(cases) - failures} of {len(cases)} drawn films judged as they should be")
    return 1 if failures else 0


def option(arguments, name, default=None):
    if name in arguments:
        place = arguments.index(name)
        value = arguments[place + 1]
        del arguments[place:place + 2]
        return value
    return default


def main(arguments):
    if not arguments or arguments[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    command = arguments.pop(0)
    if command == "--self-test":
        return self_test()
    if command == "score":
        path, eyes, stills = option(arguments, "--json"), option(arguments, "--eyes"), option(arguments, "--stills")
        summary = score(arguments[0], eyes, stills)
        if path:
            with open(path, "w", encoding="utf-8") as file:
                json.dump(summary, file, indent=1)
        return 0 if summary["trusted"] else 1
    if command == "measure":
        m, verdicts = judge(arguments[0])
        motion = m["motion"]
        print(f"{m['film'].name}: {m['film'].kind}: {m['film'].text}")
        print(f"frames {len(m['film'])}, cause {m['cause_known']}, first change {m['latency']} ms, at rest {m['rest']} ms, camera's tick {m['tick']:.1f} ms")
        print(f"wallpaper {m['scan'].background}, flat colours at first {m['scan'].colours[0]}")
        for a, b, c, d, box in m["episodes"]:
            print(f"  change from {a - m['cause']} to {b - m['cause']} ms, frames {c} to {d}, within {box}")
        for track in m["scan"].tracks:
            first, last = track.rects[0], track.last
            print(f"  thing {track.costumes()} frames {track.indices[0]}–{track.indices[-1]}: {first.edges} -> {last.edges}")
        if motion.seen:
            print(f"  roads {len(motion.roads)}, longest {motion.travel:.0f} px, moving from {motion.first - m['cause']:.0f} to {motion.last - m['cause']:.0f} ms, "
                  f"fit {motion.fit}, settle {motion.settle}, spread {motion.spread:.3f}, pushes {motion.pushes}")
        for identifier, verdict in verdicts.items():
            print(f"{identifier:4s} {verdict.status:6s} {verdict.said} {verdict.frames or ''}")
        return 0
    if command == "curve":
        m, _ = judge(arguments[0])
        if not m["motion"].seen:
            print("nothing could be followed")
            return 1
        for time, progress in zip(m["motion"].times, m["motion"].progress):
            print(f"{time - m['cause']:7.1f} {progress:.4f}")
        return 0
    if command == "sheet":
        since, until = option(arguments, "--from"), option(arguments, "--to")
        columns, crop, zoom = int(option(arguments, "--columns", 6)), option(arguments, "--crop"), option(arguments, "--zoom")
        frames = option(arguments, "--frames")
        film = Film(arguments[0])
        count = sheet(film, arguments[1], int(since) if since else None, int(until) if until else None, columns,
                      [int(word) for word in crop.split(",")] if crop else None, float(zoom) if zoom else None, cause_of(film)[0],
                      {int(word) for word in frames.split(",")} if frames else None)
        print(f"{count} frames on {arguments[1]}")
        return 0
    if command == "sheets":
        # Three sheets of twelve frames a scene, large enough to see a pixel's worth of trouble: how it begins, the whole, how it ends.
        os.makedirs(arguments[1], exist_ok=True)
        films = os.path.join(arguments[0], "films")
        for name in sorted(os.listdir(films)):
            if not os.path.isfile(os.path.join(films, name, "film.log")):
                continue
            film = Film(os.path.join(films, name))
            cause = cause_of(film)[0]
            after = [index for index, time in enumerate(film.times) if time >= cause - 5]
            if not after:
                continue
            first = max(after[0] - 1, 0)
            every = list(range(first, len(film)))
            # The end of the change: the last frame that comes less than 300 ms after the one before it, the line of words' going aside.
            busy = [index for index in every[1:] if film.times[index] - film.times[index - 1] < 300 and film.times[index] <= cause + 2500]
            last = busy[-1] if busy else every[-1]
            parts = {"begins": every[:12], "whole": [every[int(place)] for place in np.linspace(0, len(every) - 1, min(12, len(every)))],
                     "ends": [index for index in every if last - 9 <= index <= last + 2]}
            for part, chosen in parts.items():
                sheet(film, os.path.join(arguments[1], f"{name}-{part}.png"), columns=4, zoom=480 / film.size[0], cause=cause, only=set(chosen))
            print(f"{name}: {len(every)} frames from the cause on")
        return 0
    if command == "briefs":
        run, scored, sheets, out = arguments[:4]
        count = int(arguments[4]) if len(arguments) > 4 else 6
        with open(scored, encoding="utf-8") as file:
            cells = json.load(file)["cells"]
        films = os.path.join(run, "films")
        names = [name for name in sorted(os.listdir(films))
                 if os.path.isfile(os.path.join(films, name, "film.log")) and not name.startswith("metronome-") and Film(os.path.join(films, name)).kind != "bare"]
        os.makedirs(out, exist_ok=True)
        for share in range(count):
            with open(os.path.join(out, f"brief-{share}.md"), "w", encoding="utf-8") as brief:
                for name in names[share::count]:
                    film = Film(os.path.join(films, name))
                    brief.write(f"## {name}\nKind: {film.kind}. The person {film.text}. {len(film)} frames.\n")
                    brief.write("Sheets: " + ", ".join(os.path.abspath(os.path.join(sheets, f"{name}-{part}.png")) for part in ("begins", "whole", "ends")) + "\n")
                    brief.write(f"Film folder: {os.path.abspath(os.path.join(films, name))}\nThe ruler's claims to confirm or refute by looking:\n")
                    claims = [cell for cell in cells if cell["where"] == name and cell["status"] == MISS and not cell["check"].startswith("E")]
                    for cell in claims:
                        brief.write(f"- {cell['check']}: {cell['said']}" + (f" (frames {cell['frames']})" if cell["frames"] else "") + "\n")
                    brief.write("\n" if claims else "- (none)\n\n")
        print(f"{len(names)} scenes for {count} reviewers in {out}")
        return 0
    if command == "eyes":
        scenes = {}
        for path in arguments[2:]:
            with open(path, encoding="utf-8") as file:
                for name, said in json.load(file)["scenes"].items():
                    entry = {check: {"status": said[check]["status"], "said": said[check]["said"], "frames": said[check].get("frames", [])}
                             for check, _, _ in EYES if check in said}
                    refuted = {claim["claim"].split(":")[0].strip(): claim["why"] for claim in said.get("claims", []) if claim["verdict"].startswith("refute")}
                    entry.update({key: value for key, value in (("refuted", refuted), ("other", said.get("other")), ("void", said.get("void"))) if value})
                    scenes[name] = entry
        json.dump({"run": arguments[0], "commit": arguments[1], "scenes": scenes}, sys.stdout, indent=1, ensure_ascii=False)
        return 0
    if command == "frame":
        Image.fromarray(Film(arguments[0]).frame(int(arguments[1]))).save(arguments[2])
        return 0
    print(__doc__)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
