#!/usr/bin/env python3
"""The judge of polish: scores the films of scripts/mac-shell/films.sh against docs/POLISH.md.

Nobody is asked to look at Arbor and say whether it feels right. A hosted Mac films it, and this reads the films anywhere: what a
ruler can settle it measures, and for the rest it lays the frames out on sheets that an agent with eyes goes through, whose
verdicts (collab/polish/eyes-run-<n>.json) it counts like its own.

  judge.py score <run folder> [--options] [--json <file>] [--eyes <file>] [--stills <file> [--without "<panel>, <panel>"]]
                                        every film in <run folder>/films (a run of films-light.sh; with --options, of films.sh, against the second column's table):
                                        the table, the findings with the frames that show them, the score. Exit code 1 when the instruments fail their own test (the metronome)
  judge.py sheets <run folder> <folder> three sheets per scene: how it begins, the whole, how it ends; of a drag also what happens while the button is down
  judge.py measure <film folder>        everything that was measured of one film
  judge.py sheet <film folder> <png> [--from <ms>] [--to <ms>] [--columns n] [--crop x,y,w,h] [--zoom n]
                                        its frames side by side, each with its number and its time after the cause
  judge.py briefs <run folder> <score.json> <sheets folder> <folder> [n]
                                        for n (6) reviewers with eyes: brief-<k>.md, each with its share of the scenes, their sheets and the misses the
                                        ruler claims, to confirm or refute. REVIEWERS.md, beside this file, is what each reviewer is told
  judge.py eyes <run id> <commit> <verdicts.json>… > eyes-run-<n>.json
                                        the reviewers' files as one, in the form `score --eyes` reads
  judge.py stills <commit> <where the pictures are from> <verdicts.json>… > stills-<n>.json
                                        the same for the reviewers of pictures at rest (REVIEWERS-STILLS.md, stills.py), in the form `score --stills` reads
  judge.py home <run folder>            of every scene with stand-ins: when the window server had each real window at its place, beside when the stand-ins
                                        went and when the display last changed (needs the run's samples.log). It scores nothing: it says where to look
  judge.py acts <run folder>            of every scene without motion: how long the display took from the first change to the last, how long the window server, in how many steps each
                                        window went, and for how many frames a window was neither where it had been nor where it belongs (needs samples.log)
  judge.py frame <film folder> <n> <png>    one frame, whole
  judge.py curve <film folder>          time and progress, one line per frame: the easing curve as it was seen
  judge.py --self-test                  films drawn by studio.py, each wrong in one known way: every check must catch its own

Needs numpy and Pillow (and no Mac). The checks' numbers are docs/POLISH.md's: change them there first.
"""

import io
import json
import multiprocessing
import os
import shutil
import sys
import tempfile
import types

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

from film import Film, apart_by, near  # noqa: E402
from measure import TICK, cause_of, flashes, measure  # noqa: E402

PASS, MISS, UNSEEN = "pass", "miss", "unseen"
# What a miss costs, by how bad it is (docs/POLISH.md, "How bad a miss is").
WEIGHT = {1: 5, 2: 3, 3: 1}

MOVES = ("camera", "structure", "control")
SETTLES = MOVES + ("drag", "follow")
# aside: macOS acts and Arbor stands aside. What moves is macOS's to answer for; Arbor's part is to add nothing, and to say what happened.
# instant: windows go to their places at once, at a key or a click. told: the same, at something the camera cannot time (a command, a window that closes itself). drop: a drag with
# the key held that ends so. out: a docked window dragged out plainly. plain: a drag that asks nothing of Arbor. closes: a window closes, and macOS fades it out over whatever Arbor does beneath.
ALL = SETTLES + ("hold", "instant", "told", "panel", "aside", "drop", "out", "plain", "closes")
AT_ONCE = ("instant", "told", "drop", "out")
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
    film = m["film"]
    # Of two keys in a row the second is the cause, and what the first set off is still under way: whose change the next frame is nobody can say.
    earlier = [time for time, what in film.keys if what == "down" and (film.time_of("action") or 0) <= time < m["cause"]]
    if earlier and ((film.times >= m["cause"] - 50) & (film.times < m["cause"])).any():
        return Verdict(UNSEEN, "the display was changing already when the key went down")
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
        hops = [push for push in motion.pushes if 3 <= push["left"] <= 40]
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


def apart(film):
    """Where the judge does not look for windows: the frames of a menu that was open when the act began (macOS fades it out over whatever moves beneath), in pixels, a little larger."""
    return [tuple(int(value * film.scale) for value in (x - 4, y - 4, x + w + 4, y + h + 4)) for when, level, (x, y, w, h) in film.overlays if when == "held" and level >= 100]


def touches_any(edges, boxes):
    return any(edges[0] < right and edges[2] > left and edges[1] < bottom and edges[3] > top for left, top, right, bottom in boxes)


def has_moved(film):
    """Whether, by Arbor's own account before and after, any window has another frame or another state. None where the film does not say."""
    if not film.before or not any(mark.startswith("windows after") for _, mark in film.marks):
        return None
    if set(film.before) != set(film.after):
        return True
    elsewhere = [window for window in film.before if max(abs(a - b) for a, b in zip(film.before[window], film.after[window])) > 2]
    # The hand takes a dragged window elsewhere by itself. Arbor has done something if it is docked that was not, or the other way round, or another window has moved as well.
    return any(film.was.get(window) != film.how.get(window) for window in film.before) or len(elsewhere) > (1 if film.kind in ("drop", "out") else 0)


def stirred(m):
    """The frames in which a followed window is seen to change after Arbor's account of the windows, noted when the scene begins, and before the cause. There should be none: the scene is at rest then.
    macOS was seen to hand the camera a stale time for the first frame after a long rest, which puts a frame of the act before the key that caused it: how things "stood before" is then the dirty state itself,
    and the act looks clean. Not asked of drags, in which the hand moves a window before the button goes up."""
    film, cause = m["film"], m["cause"]
    noted = [time for time, mark in film.marks if mark.startswith(("before ", "windows before"))]
    if not noted or film.kind not in ("instant", "told", "closes"):
        return []
    menus, found = apart(film), []
    for track in m["scan"].tracks:
        if track.detail:
            continue
        clean = [(int(time), index, rect.edges) for time, index, rect in zip(track.times, track.indices, track.rects) if time < cause and not rect.thin and not rect.ragged and not touches_any(rect.edges, menus)]
        found += [index for (_, _, before), (time, index, edges) in zip(clean, clean[1:]) if time >= noted[-1] and max(abs(p - q) for p, q in zip(before, edges)) > 2 * film.scale]
    return sorted(set(found))


def believed(m, verdict):
    """What R1, R4 and R5 say, unless the film's own witnesses speak against it."""
    film = m["film"]
    early = stirred(m)
    if early:
        return Verdict(UNSEEN, f"THE FILM IS NOT BELIEVED: a window changes in frame {early[0]}, after Arbor's account of the windows and before the cause: the frame's time is wrong, or the scene was not at rest", early[:8])
    # Under a menu that macOS fades out the ruler does not look. Where windows lie there, that it found nothing is no finding: eyes settle it.
    menus = apart(film)
    if verdict.status == PASS and menus and any(touches_any(tuple(value * film.scale for value in (x, y, x + w, y + h)), menus) for frames in (film.before, film.after) for x, y, w, h in frames.values()):
        return not_yet(None, None)
    return verdict


def pieces(m, until=None):
    """An act without motion, by its windows alone (a line of words that fades in afterwards is no part of their arriving): {"frames": those in which a window came, went, or changed its
    place or size, "times": when, "between": the frames in which some window is seen at a place or size that is neither its old nor its new one, "sized": those of them in which it has
    the size of the end at the place of the start, "followed": how many windows}."""
    cause, film = m["cause"], m["film"]
    # To the film's end: whatever comes late is part of the act.
    until = int(film.times[-1]) - cause if until is None else until
    # Arbor's own panels that were up when the act began are no windows, whatever becomes of them.
    menus = apart(film)
    panels = [tuple(int(value * film.scale) for value in (x, y, x + w, y + h)) for when, level, (x, y, w, h) in film.overlays if when in ("held", "before") and level > 0]

    def same(a, b):
        return a is not None and b is not None and max(abs(p - q) for p, q in zip(a, b)) <= 2

    changed, between, followed, sized = set(), set(), 0, set()
    for track in m["scan"].tracks:
        if track.detail or any(same(track.rects[0].edges, panel) for panel in panels):
            continue
        # What is there for a frame or two and was not before is a flash, which M9 asks about, or a blend of two things that fade across each other: no window.
        if len(track.indices) <= 2 and track.times[0] >= cause and track.indices[-1] < len(film) - 1:
            continue
        # The line of words is low and wide, and so is what it leaves of a window it lies across.
        seen = [(int(time), index, rect.edges, rect.ragged) for time, index, rect in zip(track.times, track.indices, track.rects)
                if time <= cause + until and not rect.thin and not touches_any(rect.edges, menus)]
        after = [entry for entry in seen if entry[0] >= cause]
        clean = [entry for entry in after if not entry[3]]
        if not clean:
            # Seen until the cause and in no frame after it: it went in the first frame that followed.
            gone = seen[-1][1] + 1 if seen else len(film)
            if seen and not after and gone < len(film) and cause <= film.times[gone] <= cause + until:
                changed.add(gone)
                followed += 1
            continue
        old = next((edges for time, _, edges, ragged in reversed(seen) if time < cause and not ragged), None)
        here = any(time < cause for time, _, _, _ in seen)
        # What is still there at the end has arrived; what has gone before that has no new place in view.
        new = clean[-1][2] if track.indices[-1] >= len(film) - 1 or track.times[-1] > cause + until else None
        before, moved = old, False
        for (_, index, _, _), (_, following, _, _) in zip(seen, seen[1:]):
            # Not in some frames between two in which it is: it went and came back.
            if following > index + 1 and film.times[following] >= cause:
                changed.update((index + 1, following))
                moved = True
        for _, index, edges, ragged in after:
            if not here:
                # It comes into view in this frame, whatever shows of it.
                changed.add(index)
                here = moved = True
                before = None if ragged else edges
            # Of a shape that is no rectangle (something lies across it) the edges say nothing.
            if ragged:
                continue
            # Held against where it was when it last counted as moved: steps of a pixel or two add up.
            if before is not None and not same(edges, before):
                changed.add(index)
                moved = True
                before = edges
            if before is None:
                before = edges
            if not same(edges, old) and not same(edges, new):
                between.add(index)
                # The commonest of them: it has been given its new size and not yet its new place.
                # (Its corner is where it was and its size is no longer what it was: how much of the new size shows depends on the room.)
                if old is not None and max(abs(edges[0] - old[0]), abs(edges[1] - old[1])) <= 2:
                    sized.add(index)
        if new is None and after[-1][1] + 1 < len(film):
            changed.add(after[-1][1] + 1)
            moved = True
        followed += moved
    frames = sorted(changed)
    return {"frames": frames, "times": [int(film.times[index]) - cause for index in frames], "between": sorted(between), "followed": followed, "sized": sorted(sized)}


def grows_where_it_cannot(film, old, seen=None):
    """The one exception to "over" (the product owner, 2026-10-15): a window may show its new size at its old place if it grows, wider or higher by half a point or more, and its new frame lies
    within no display's room: x from the display's left edge to the visible frame's right one, y from the display's top to the visible frame's bottom, and half a point more on every side: the room
    as the product has it (`FramePlan.room`, `growsWhereItCannot`): one definition in both. (The Dock at the right: unmeasured on a Mac; the narrower room errs to the old full plan.) macOS cuts growth
    at the display's edge once the window stands there, and a size lost for good outranks a frame seen for a moment. The display shows only what of such a frame lies on it, so the frames are Arbor's
    own account, before and after; the window is the one whose frame before comes nearest the followed rectangle's left, right and bottom, with its top a title bar above. `seen`, the rectangle
    to be excused, has to be that size and no third one: as wide and as high as the new frame, or as much of it as the room or the display lets show from the old place. False where the film
    does not say. A film has one display, so a frame that lies wholly on another is taken to lie in no room: no film has two."""
    if not film.display or not film.visible:
        return False
    edges = tuple(value / film.scale for value in old.edges)
    near = [(max(abs(x - edges[0]), abs(x + w - edges[2]), abs(y + h - edges[3])), window) for window, (x, y, w, h) in film.before.items()
            if window in film.after and -3 <= edges[1] - y <= 45]
    if not near or min(near)[0] > 3:
        return False
    (x, y, w, h), (left, top, wide, high) = film.before[min(near)[1]], film.after[min(near)[1]]
    right, foot = film.visible[0] + film.visible[2], film.visible[1] + film.visible[3]
    grows = wide - w >= 0.5 or high - h >= 0.5
    within = film.display[0] - 0.5 <= left and left + wide <= right + 0.5 and film.display[1] - 0.5 <= top and top + high <= foot + 0.5
    if seen is not None:
        shown = tuple(value / film.scale for value in seen.edges)
        if min(abs(shown[2] - min(x + wide, edge)) for edge in (right, film.display[0] + film.display[2])) > 3:
            return False
        if min(abs(shown[3] - min(y + high, edge)) for edge in (foot, film.display[1] + film.display[3])) > 3:
            return False
    return grows and not within


def in_one_piece(m, until=None):
    """What is worse than a window a frame late, frame by frame between the first change of an act and its last: {"holes": frames in which the ground shows where there is a window both before
    the act and after it, "empty": frames in which there is nothing at all on a desk that had windows and has them again, "over": frames in which a window on its way covers what neither
    its old frame nor its new one covers, "excused": those of them that `grows_where_it_cannot` lets pass, which are counted and not booked}. None where the wallpaper is not plain."""
    film, scan, cause = m["film"], m["scan"], m["cause"]
    said = pieces(m, until)
    if scan.background is None or not said["frames"]:
        return None
    until = int(film.times[-1]) - cause if until is None else until
    x, y, width, height = (int(value * film.scale) for value in film.visible)
    first, last = said["frames"][0], said["frames"][-1]
    room, taken, found, menus = width * height, {}, {"holes": [], "empty": [], "over": [], "excused": []}, apart(film)
    for index, _, picture, _ in film.frames():
        if first - 1 <= index <= last:
            # Arbor darkens the ground behind docked windows: that is ground too.
            taken[index] = ~near(picture[y:y + height, x:x + width], scan.background, 64)
            # Under a menu that is fading out nothing is asked: there it counts as taken throughout.
            for left, top, right, bottom in menus:
                taken[index][max(top - y, 0):max(bottom - y, 0), max(left - x, 0):max(right - x, 0)] = True
        if index >= last:
            break
    before, after = taken[first - 1], taken[last]
    for index in range(first, last):
        if (before & after & ~taken[index]).sum() > room / 100:
            found["holes"].append(index)
        if taken[index].sum() < room / 100 and min(before.sum(), after.sum()) > room / 20:
            found["empty"].append(index)
    for track in scan.tracks:
        if track.detail:
            continue
        clean = [(int(time), index, rect) for time, index, rect in zip(track.times, track.indices, track.rects)
                 if not rect.thin and not rect.ragged and time <= cause + until and not touches_any(rect.edges, menus)]
        old = next((rect for time, _, rect in reversed(clean) if time < cause), None)
        new = clean[-1][2] if clean and clean[-1][0] >= cause else None
        if old is None or new is None:
            continue
        for time, index, rect in clean:
            # Within two pixels of either it is there: the ruler is no finer.
            if time < cause or index >= last or any(max(abs(p - q) for p, q in zip(rect.edges, other.edges)) <= 2 for other in (old, new)):
                continue
            # The part of it that lies in neither: its area, less what it shares with the old frame and with the new, plus what those two share within it.
            def shared(*others):
                left, top = max([rect.left] + [other.left for other in others]), max([rect.top] + [other.top for other in others])
                right, bottom = min([rect.right] + [other.right for other in others]), min([rect.bottom] + [other.bottom for other in others])
                return max(right - left, 0) * max(bottom - top, 0)
            if rect.area - shared(old) - shared(new) + shared(old, new) > 400 * film.scale**2:
                # The exception excuses the new size at the old place, and nothing else that happens in the same act.
                there = max(abs(rect.left - old.left), abs(rect.top - old.top)) <= 2 * film.scale
                found["excused" if there and grows_where_it_cannot(film, old, rect) else "over"].append(index)
    found["over"], found["excused"] = sorted(set(found["over"])), sorted(set(found["excused"]))
    return found


def whole(m, allow):
    if not m["episodes"]:
        return Verdict(UNSEEN, "nothing changed")
    found = in_one_piece(m)
    if found is None or has_moved(m["film"]) is False:
        return Verdict(UNSEEN, "no window could be followed, the wallpaper is not plain, or no window has another frame after the act than before it")
    said = [f"{what} in {len(frames)} frames" for what, frames in (("the desk is empty", found["empty"]), ("the ground shows through a hole", found["holes"]),
                                                                  ("a window covers what neither its old nor its new frame covers", found["over"])) if frames]
    # An exception that nobody counts grows.
    excused = f"; the exception for what grows where it cannot was used in {len(found['excused'])} frames" if found["excused"] else ""
    return believed(m, Verdict(MISS if said else PASS, ("; ".join(said) or "no hole, no empty desk, no window over what neither of its frames covers") + excused,
                               sorted(set(found["empty"] + found["holes"] + found["over"]))[:8]))


def at_once(m, allow):
    """For whatever is not meant to move: the end, at once."""
    if not m["episodes"]:
        return Verdict(UNSEEN, "nothing changed")
    said = pieces(m)
    if not said["followed"] or has_moved(m["film"]) is False:
        return Verdict(UNSEEN, "no window could be followed, or none has another frame after the act than before it")
    took = said["times"][-1] - said["times"][0]
    limit = 100 + allow["gap"]
    return believed(m, Verdict(PASS if took <= limit else MISS, f"the windows arrive in {len(said['frames'])} pieces, {ms(took)} from the first to the last (at most {ms(limit)})", said["frames"][:8]))


def old_or_new(m, allow):
    if not m["episodes"]:
        return Verdict(UNSEEN, "nothing changed")
    said = pieces(m)
    if not said["followed"] or has_moved(m["film"]) is False:
        return Verdict(UNSEEN, "no window could be followed, or none has another frame after the act than before it")
    return believed(m, Verdict(MISS if said["between"] else PASS, f"in {len(said['between'])} frames a window is at a place or size that is neither its old nor its new one (none)", said["between"][:8]))


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


NOTHING_DOCKED = "no window is docked at the end: there are no gaps to ask about"


def even_gaps(m, allow):
    """On the last frame, from the edges of the docked windows outwards: how many pixels of wallpaper until the next thing."""
    film, scan = m["film"], m["scan"]
    docked = [frame for window, frame in film.after.items() if film.how.get(window) == "docked"]
    if scan.background is None or max(scan.background) > 60:
        return Verdict(UNSEEN, "on a light wallpaper shadows fill the gaps: for eyes")
    if not docked and film.after:
        return Verdict(UNSEEN, NOTHING_DOCKED)
    if not docked:
        return Verdict(UNSEEN, "the film does not say which windows are docked")
    picture = film.frame(len(film) - 1)
    empty = near(picture, scan.background, 24)
    # The focus ring is drawn in the gap, round the window that has the keyboard: a few pixels of it are gap, not window.
    ring = near(picture, (0, 122, 255), 40)
    x0, y0, x1, y1 = scan.room
    gaps = []
    for x, y, w, h in docked:
        left, top, right, bottom = (int(round(value * film.scale)) for value in (x, y, x + w, y + h))
        if left < x0 or top < y0 or right > x1 or bottom > y1:
            continue
        # Along three lines a side, and the middle one of the three answers: a seam's grip or the Desktop's mark may lie in a gap.
        for horizontal, start, step, low, high in ((True, left + 8, -1, x0, x1), (True, right - 8, 1, x0, x1), (False, top + 8, -1, y0, y1), (False, bottom - 8, 1, y0, y1)):
            runs = []
            for share in (0.25, 0.5, 0.75):
                at = int(top + share * (bottom - top)) if horizontal else int(left + share * (right - left))
                line, ringed = (empty[at, :], ring[at, :]) if horizontal else (empty[:, at], ring[:, at])
                place = start
                while low <= place < high and not line[place]:
                    place += step
                run = 0

                def thickness(from_place, direction):
                    count = 0
                    while low <= from_place < high and ringed[from_place] and count <= 5 * film.scale:
                        from_place += direction
                        count += 1
                    return count if count <= 4 * film.scale else 0

                run += thickness(place - step, -step)
                while low <= place < high and line[place]:
                    place += step
                    run += 1
                run += thickness(place, step)
                place += thickness(place, step) * step
                # The Dock's plate reaches a few pixels into the room, as it does under any window: what is measured is Arbor's gap.
                left_over = (place - low + 1) if step < 0 else (high - place)
                runs.append(run + left_over if 0 < left_over <= 4 * film.scale else run)
            gaps.append(sorted(runs)[1])
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
    if track is not None and track.indices[-1] < len(film) - 1:
        # At once it may go further in one frame than the ruler follows: what has its colour and is there at the end is the same window.
        # (The ruler may have taken it for the preview in another costume, since it is where the preview was.)
        track = next((other for other in m["scan"].tracks if not other.detail and other.indices[-1] >= len(film) - 1 and apart_by(other.last.colour, track.last.colour) <= 12), None)
    if track is None:
        return Verdict(UNSEEN, "the dragged window could not be followed to its rest")
    x, y, w, h = (value * film.scale for value in previews[0])
    off = max(abs(a - b) for a, b in zip(track.last.edges, (x, y, x + w, y + h)))
    return Verdict(PASS if off <= 2 * film.scale else MISS, f"the window rests up to {off:.0f} px from where the preview was (at most 2)")


def nothing_shown(m, allow):
    """While the button is down: no preview, no stage, no line of words."""
    held = [(level, frame) for when, level, frame in m["film"].overlays if when == "held"]
    if not any(mark.startswith("overlays held") for _, mark in m["film"].marks) or {what for _, what, _, _ in m["film"].buttons} != {"down", "up"}:
        return Verdict(UNSEEN, "the film does not say which panels were up while the drag was held, or shows no drag")
    shown = sorted({level for level, _ in held if level in PASSING + (6,)})
    return Verdict(MISS if shown else PASS, f"while the button is down Arbor shows panels at the levels {shown}" if shown else "while the button is down Arbor shows nothing that was not there before")


def let_be(m, allow):
    film = m["film"]
    downs, ups = ([(x, y) for _, what, x, y in film.buttons if what == which] for which in ("down", "up"))
    moved = [window for window in film.after if window in film.before and max(abs(a - b) for a, b in zip(film.after[window], film.before[window])) > 2]
    if not downs or not ups or not film.before:
        return Verdict(UNSEEN, "the film does not say where the windows were, or where the button went down and came up")
    if len(moved) != 1:
        return Verdict(MISS, f"{len(moved)} windows are elsewhere after the drag than before it (one: the one that was dragged)")
    window = moved[0]
    (x, y, w, h), (x2, y2, w2, h2) = film.before[window], film.after[window]
    off = max(abs((x2 - x) - (ups[-1][0] - downs[0][0])), abs((y2 - y) - (ups[-1][1] - downs[0][1])), abs(w2 - w), abs(h2 - h))
    right = off <= 2 and film.how.get(window) == "floating"
    return Verdict(PASS if right else MISS, f"the window is {off:.0f} px from where the pointer took it, size counted in (at most 2), and is {film.how.get(window)}")


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


def follows(m, allow):
    """Whatever the fingers' sum means to Arbor, a width that follows it is a smooth function of it, a moment later."""
    film = m["film"]
    down, up = film.time_of("fingers down"), film.time_of("fingers up")
    if not film.fingers or down is None or up is None:
        return Verdict(UNSEEN, "the film does not say what the fingers did")
    said_at = np.array([event[0] for event in film.fingers], dtype=float)
    said = np.array([event[1] for event in film.fingers], dtype=float)
    best = None
    for track in m["scan"].tracks:
        if track.detail:
            continue
        seen = [(time, rect.right - rect.left) for time, rect in zip(track.times, track.rects)
                if down <= time <= up and not rect.cut[0] and not rect.cut[2] and not rect.ragged]
        if len(seen) >= 12 and (best is None or np.ptp([width for _, width in seen]) > np.ptp([width for _, width in best])):
            best = seen
    if best is None or np.ptp([width for _, width in best]) < 40 * film.scale:
        return Verdict(UNSEEN, "no window's width could be followed while the fingers were down")
    times, widths = (np.array(column, dtype=float) for column in zip(*best))
    fits = []
    for lag in range(0, 160, 4):
        sums = np.interp(times - lag, said_at, said)
        line = np.polyval(np.polyfit(sums, widths, 3), sums)
        fits.append((float(np.sqrt(np.mean((widths - line) ** 2))), lag, float((np.abs(widths - line) / widths).max()), int(np.abs(widths - line).argmax())))
    _, lag, off, where = min(fits)
    faults = []
    if lag > 2 * TICK + 2 + allow["gap"]:
        faults.append(f"{lag} ms behind the fingers (at most 35)")
    if off > 0.02:
        faults.append(f"at one moment {off * 100:.0f}% of its width from where the fingers have it (at most 2%)")
    if faults:
        return Verdict(MISS, "; ".join(faults), [frame_at(m, times[where])])
    return Verdict(PASS, f"{lag} ms behind the fingers, never more than {off * 100:.1f}% of its width from where they have it")


def not_yet(m, allow):
    return Verdict(UNSEEN, "the judge cannot measure this yet")


def nothing_left(m, allow):
    film = m["film"]
    if not film.after and not any(when == "after" for when, _, _ in film.overlays) and not any(mark.startswith("overlays after") for _, mark in film.marks):
        return Verdict(UNSEEN, "the film does not say which panels were up at its end")
    left = [level for when, level, _ in film.overlays if when == "after" and level in PASSING]
    return Verdict(MISS, f"still up at the end: panels at levels {left}") if left else Verdict(PASS, "no stage and no preview is left")


CHECKS = [
    # id, what it asks, how bad a miss is, the kinds of scene it is asked of, the function
    ("M1", "answers at once", 2, tuple(kind for kind in ALL if kind not in ("plain", "told", "closes")), answers),
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
    ("S8", "even gaps", 3, MOVES[:2] + ("drag", "closes") + AT_ONCE, even_gaps),
    ("R1", "at once: from the first window to the last", 1, AT_ONCE, at_once),
    ("R2", "at once: the same end as with motion", 2, ("instant",), not_yet),
    ("R3", "at once: no slide anywhere", 2, AT_ONCE, few_places),
    ("R4", "at once: every window is where it was or where it belongs", 2, AT_ONCE, old_or_new),
    ("R5", "at once: in one piece: no hole, no empty desk, nothing covered that neither frame covers", 1, AT_ONCE, whole),
    ("D1", "Arbor never pulls what is being dragged", 1, ("drag", "drop", "out", "plain"), not_pulled),
    ("D2", "the preview tells the truth", 2, ("drag", "drop"), preview_true),
    ("D3", "the preview comes and goes softly, once", 2, ("drag", "drop"), not_yet),
    ("D4", "others make room in one motion", 1, ("drag", "drop"), not_yet),
    ("D5", "in a plain drag nothing of Arbor's is on screen", 1, ("plain", "out"), nothing_shown),
    ("D6", "after a plain drag the window is where it was let go, floating, at its own size", 1, ("plain",), let_be),
    ("G1", "what follows the fingers follows them closely", 1, ("follow",), follows),
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
    ("E5", "nothing is drawn that was not asked for: whatever Arbor draws here would be missed", 2),
]

# The scenes that count: name, kind, which of the five moves it stands for (0: none). One that was not filmed, because the script
# failed or because Arbor cannot do it yet, scores nothing.
MOVES_FILMED_TWICE = [
    ("tab-make", "drag", 1), ("tab-change", "structure", 1), ("tab-drag-group", "drag", 1),
    ("dock-drag-edge", "aside", 2), ("dock-drag-beside", "drag", 2), ("rearrange", "drag", 2),
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

# What ships: name, kind, whether the gate asks for it. The nine keys, Go to…, the menu with its one icon, a plain drag, a drag with the key held; in light and in dark.
GATE_FILMED_TWICE = [
    ("dock-first", "instant", 1), ("dock-second", "instant", 1), ("fill", "instant", 1), ("everything", "instant", 1), ("back", "instant", 1),
    ("float", "instant", 1), ("undo", "instant", 1), ("float-back", "instant", 1), ("pause", "instant", 1), ("resume", "instant", 1),
    ("go-to", "panel", 1), ("go-to-choose", "instant", 1), ("menu", "panel", 1), ("menu-arrange", "instant", 1),
    ("drag-plain", "plain", 1), ("drag-held", "drop", 1), ("drag-out", "out", 1),
]
SHIPS = GATE_FILMED_TWICE + [("dark-" + name, kind, gate) for name, kind, gate in GATE_FILMED_TWICE] + [
    ("dock-third", "instant", 0), ("dock-fourth", "instant", 0), ("dock-fourth-again", "instant", 0), ("close", "closes", 0), ("quit", "told", 0),
    ("eight-arrange", "instant", 0), ("eight-fill", "instant", 0), ("eight-everything", "instant", 0), ("eight-arrange-again", "instant", 0),
    ("crowd-arrange", "instant", 0), ("crowd-arrange-again", "instant", 0),
    ("eight-arrange-told", "told", 0), ("eight-arrange-told-again", "told", 0), ("crowd-arrange-told", "told", 0), ("crowd-arrange-told-again", "told", 0),
]

# The laboratory's own column: the same table, with every scene of the moves taken from the session in which Arbor's gestures are on and
# macOS's own tiling is off (`on-…`), where it was filmed. There the drag to an edge is Arbor's.
ON = {"dock-drag-edge": "drag"}

# Whatever Arbor draws of its own, and what is asked of a picture of each (docs/POLISH.md, "Panels"): check, severity.
PANELS = ["heads-up line", "drop preview", "tile", "seam", "focus ring", "peek outline", "rectangle", "minimap", "go to", "shortcuts",
          "name field", "menu", "settings", "coach", "setup check", "tab strip"]
STILLS = [("S1 at 1x", 2), ("S1 at 2x", 2), ("S2", 3), ("S3", 1), ("S4 light", 2), ("S4 dark", 2), ("S4 light on glass", 2), ("S4 dark on glass", 2),
          ("S6", 2), ("S7", 3)]
# What is on screen as Arbor ships; the rest is there for whoever switches it on.
SHIPPED = ["menu", "drop preview", "tile", "go to", "heads-up line", "coach", "setup check", "settings"]
TABLES = {"ships": (SHIPS, SHIPPED), "options": (SCENES, [panel for panel in PANELS if panel not in SHIPPED])}
# These have no ground of their own, so nothing to see through; and these no words, so nothing to clip or to read.
GROUNDLESS = ("drop preview", "seam", "focus ring", "peek outline", "rectangle")
WORDLESS = GROUNDLESS + ("minimap",)

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


def much(m):
    """Whether a tenth of the room or more changed, over three frames or more: windows on their way, whether or not the ruler could tell which."""
    _, _, width, height = m["film"].visible
    room = width * height * m["film"].scale**2
    return any(last - first >= 2 and (box[2] - box[0]) * (box[3] - box[1]) >= room / 10 for _, _, first, last, box in m["episodes"])


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
            # After a plain drag nothing is what should happen.
            elif not m["episodes"] and verdicts[identifier].status == PASS and film.kind != "plain":
                verdicts[identifier] = Verdict(UNSEEN, "nothing happens in the film")
            # A line of words that comes and goes is a change too. Where windows were to move, none could be followed and little of the room ever changed, the key did nothing.
            elif film.kind in SETTLES and not m["motion"].seen and not much(m) and verdicts[identifier].status == PASS:
                verdicts[identifier] = Verdict(UNSEEN, "no window was seen to move")
            elif film.kind in AT_ONCE and verdicts[identifier].status == PASS and (not pieces(m)["followed"] or has_moved(film) is False):
                verdicts[identifier] = Verdict(UNSEEN, "no window was seen to move")
            elif film.kind == "plain" and verdicts[identifier].status == PASS and {what for _, what, _, _ in film.buttons} != {"down", "up"}:
                verdicts[identifier] = Verdict(UNSEEN, "the film shows no drag")
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


def judged(task):
    """One film, for `score`, which measures several at a time: what it needs of the measures, and no frames."""
    m, verdicts = judge(*task)
    return {"film": types.SimpleNamespace(kind=m["film"].kind), "rests": rests_of(m)}, verdicts


def first_lines(trusted, short, seen, total, which):
    """What whoever reads one line of a score must know, before anything else: that the instruments failed; that it is not what ships; that under half was seen."""
    lines = []
    if not trusted:
        lines.append("**THE INSTRUMENTS FAILED THEIR OWN TEST: the score below is not to be believed.**")
    if short:
        lines.append("**NOT YET WHAT SHIPS: " + ". And ".join(short) + ".**")
    if 2 * seen < total:
        lines.append(f"**SEEN: {100 * seen // total}% OF {'WHAT SHIPS' if which == 'ships' else 'THE OPTIONS'}, UNDER HALF. Whatever follows is about that part; the rest counts as missed.**")
    return lines


def score(folder, eyes_path=None, stills_path=None, out=sys.stdout, without=(), which="ships"):
    scenes, panels = TABLES[which]
    films = os.path.join(folder, "films")
    filmed = sorted(name for name in os.listdir(films) if os.path.isfile(os.path.join(films, name, "film.log")))
    results = {}
    for name in [name for name in filmed if name.startswith("metronome-")]:
        results[name] = judge(os.path.join(films, name))
    allow = leeway(results)
    others = [name for name in filmed if not name.startswith("metronome-")]
    with multiprocessing.get_context("fork").Pool(os.cpu_count()) as pool:
        results.update(zip(others, pool.map(judged, [(os.path.join(films, name), allow) for name in others], chunksize=1)))

    # The same keys with and without motion, from the same beginning: the session with pictures is the one that has it.
    for name in ("dock-key", "frame", "show-everything"):
        still, moving = results.get("reduced-" + name), results.get("pictures-" + name)
        if not still or not moving:
            continue
        a, b = still[0]["rests"], moving[0]["rests"]
        if not a or len(a) != len(b):
            still[1]["R2"] = Verdict(MISS if a and b else UNSEEN, f"{len(a)} windows at rest without motion, {len(b)} with")
            continue
        off = max(min(max(abs(p - q) for p, q in zip(one.edges, other.edges)) for other in b) for one in a)
        still[1]["R2"] = Verdict(PASS if off <= 1 else MISS, f"windows rest within {off} px of where they rest with motion (at most 1)")

    first = out
    out = io.StringIO()
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
        note = ""
        if kind == "flash" and not right:
            # The spark is put out by a timer, which on a busy Mac comes late: then it is no flash. What the film is there to prove is that
            # the ruler sees a thing that comes and goes on real frames, and how long it stays.
            seen = [(track, shown) for track, shown in flashes(result[0]["scan"], result[0]["cause"], longest=600)
                    if abs(track.rects[0].right - track.rects[0].left - 120 * result[0]["film"].scale) <= 4]
            if seen:
                right, note = True, f"; the spark stayed {seen[0][1]} ms, too long for a flash, and was measured as that (frames {seen[0][0].indices[0]} to {seen[0][0].indices[-1]})"
        trusted &= right
        print(f"- metronome {kind}: {'as it should be' if right else 'WRONG'}: missed {', '.join(missed) or 'nothing'}"
              f" (must miss {', '.join(wanted) or 'nothing'}){note}", file=out)
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
    pictures = read(stills_path)
    eyes, stills = seen_by_eye.get("scenes", {}), pictures.get("panels", {})
    def column(everything_on):
        """(cells, table): a cell is (scene or panel, check, title, severity, move, Verdict)."""
        cells, table = [], []
        for name, kind, move in scenes:
            plain = name[5:] if name.startswith("dark-") else name
            twin = ("on-dark-" if name.startswith("dark-") else "on-") + plain
            if everything_on and twin in results:
                name, kind = twin, ON.get(plain, kind)
            row = {}
            for identifier, title, severity, kinds, _ in CHECKS:
                # With no motion to hold it against there is no "same end"; and whether anything slides is looked at more closely by the check after it.
                if kind not in kinds or which == "ships" and identifier in ("R2", "R3"):
                    continue
                # On a light wallpaper shadows fill the gaps, and no ruler can measure them.
                if which == "ships" and identifier == "S8" and name.startswith("dark-"):
                    continue
                verdict = results[name][1].get(identifier) if name in results else Verdict(UNSEEN, "not filmed")
                if verdict is None:
                    verdict = Verdict(UNSEEN, f"filmed as {results[name][0]['film'].kind}, not as {kind}")
                # A pause, a quit: what cannot be asked is no cell, and so no miss.
                if verdict.said == NOTHING_DOCKED:
                    continue
                # What the ruler cannot measure yet, eyes may settle.
                by_eye = eyes.get(name, {}).get(identifier)
                if verdict.said == not_yet(None, None).said and by_eye:
                    verdict = Verdict(by_eye["status"], by_eye["said"], by_eye.get("frames", []))
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
        for panel in panels:
            for identifier, severity in STILLS:
                if panel in WORDLESS and identifier.split()[0] in ("S3", "S4") or panel in GROUNDLESS and identifier == "S7":
                    continue
                seen = stills.get(panel, {}).get(identifier)
                verdict = Verdict(seen["status"], seen["said"]) if seen else Verdict(UNSEEN, "no picture has been measured")
                if panel in without:
                    verdict = Verdict(UNSEEN, "what draws it has changed since it was pictured")
                cells.append((panel, identifier, "", severity, 0, verdict))
        return cells, table

    # Of the options, each move is taken from the session in which it is switched on.
    cells, table = column(which == "options")
    lab_cells, lab_table = cells, table
    total = sum(WEIGHT[cell[3]] for cell in cells)
    earned = sum(WEIGHT[cell[3]] for cell in cells if cell[5].status == PASS)
    seen = sum(WEIGHT[cell[3]] for cell in cells if cell[5].status != UNSEEN)
    number = 100 * earned / total
    lab_number = 100 * sum(WEIGHT[cell[3]] for cell in lab_cells if cell[5].status == PASS) / sum(WEIGHT[cell[3]] for cell in lab_cells)

    identifiers = [check[0] for check in CHECKS] + [check[0] for check in EYES]
    sign = {PASS: "✔", MISS: "✘", UNSEEN: "·", None: " "}
    print("## The table (✔ passes, ✘ misses, · could not be seen, which counts as a miss)\n", file=out)
    print("| scene | kind | move | " + " | ".join(identifiers) + " |", file=out)
    print("|---|---|---|" + "---|" * len(identifiers), file=out)
    for name, kind, move, row in table:
        print(f"| {name} | {kind} | {move or ''} | " + " | ".join(sign[row.get(identifier)] for identifier in identifiers) + " |", file=out)

    trials = [name for name in filmed if name not in {line[0] for line in table} and not name.startswith("metronome-")]
    if trials:
        print("\n## Judged, not counted\n", file=out)
        for name in trials:
            said = "; ".join(f"{identifier} {verdict.status}" + (f" ({verdict.said})" if verdict.status == MISS else "")
                             for identifier, verdict in results[name][1].items() if verdict.status != PASS)
            print(f"- `{name}`: {said or 'passes all that was asked'}", file=out)

    print("\n## Findings, the worst first\n", file=out)
    misses = [cell for cell in cells + [cell for cell in lab_cells if cell[0].startswith("on-")] if cell[5].status == MISS]
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
    worst = sum(1 for cell in cells if cell[5].status == MISS and cell[3] == 1)
    print(f"\n## Score: {number:.1f} of 100 ({earned} of {total} points); seen {100 * seen / total:.0f}%; {worst} misses of severity 1", file=out)
    # What the films themselves say they are of (films/ships.json, from `second_build`): a film of switches, or of what is left of the first build, is not a film of what ships.
    told = {}
    if which == "ships" and os.path.isfile(os.path.join(films, "ships.json")):
        with open(os.path.join(films, "ships.json"), encoding="utf-8") as file:
            told = json.load(file)
    short = []
    if told.get("written"):
        short.append("written out, because the commit filmed ships otherwise: " + ", ".join(f"{key} {json.dumps(value)}" for key, value in told["written"].items()))
    if told.get("still"):
        short.append("still the first build's, and no switch can change it: " + "; ".join(told["still"]))
    if which != "ships":
        print("That is the options, each switched on: the second column, which no gate reads.", file=out)
    elif short:
        print("That is NOT YET Arbor as the second build ships: " + ". And ".join(short) + ".", file=out)
    else:
        print("That is Arbor as it ships, on a Mac as it comes." + ("" if told else " (By the films' own word there is none: they say nothing of what was switched.)"), file=out)
    excused = [cell[0] for cell in cells if cell[1] == "R5" and "the exception for what grows where it cannot" in cell[5].said]
    print(f"The one exception to R5, for what grows where it cannot, was used in {len(excused)} scenes" + (f": {', '.join(excused)}." if excused else "."), file=out)
    if pictures:
        print(f"The pictures at rest are of {pictures['commit']}: {pictures['from']}." + (f" Left out, because what draws them has changed since: {', '.join(without)}." if without else ""), file=out)
    print(f"The rubric {'PASSES' if not gate and number >= 90 else 'does not pass'}: {len(gate)} cells of severity 1 or 2 in what the gate asks for "
          "miss or are unseen.", file=out)
    for line in first_lines(trusted, short, seen, total, which):
        print(line + "\n", file=first)
    first.write(out.getvalue())
    return {
        "score": round(number, 1), "everything_on": round(lab_number, 1), "earned": earned, "total": total, "seen": round(100 * seen / total, 1), "trusted": trusted,
        "leeway": allow, "ships": told, "gate": len(gate), "severity1": worst, "pictures": pictures.get("commit"),
        "cells": [{"where": name, "check": identifier, "severity": severity, "move": move, "status": verdict.status, "said": verdict.said,
                   "frames": [int(frame) for frame in verdict.frames]}
                  for name, identifier, _, severity, move, verdict in cells],
    }


# MARK: The judge judged


def home_of(samples, since, until, windows):
    """What the window server says of one scene, from the lines of sampler.swift between two moments: when the stage came and went, when each of
    the windows was moved last, which of them after the stage had gone, and the longest the sampler saw nothing for."""
    stage, up, down, moved, blind = None, None, None, {}, 0
    for words in samples:
        time, kind = int(words[0]), words[1]
        if not since <= time <= until:
            continue
        if kind == "W" and int(words[4]) == PASSING[1] and words[9] == "Arbor" and stage is None:
            stage, up = words[2], time
        elif kind == "G" and words[2] == stage and down is None:
            down = time
        elif kind == "W" and int(words[2]) in windows:
            moved[int(words[2])] = time
        elif kind == "L":
            blind = max(blind, int(words[2]))
    late = sorted(window for window, time in moved.items() if down is not None and time > down)
    return {"up": up, "down": down, "moved": moved, "late": late, "blind": blind}


def home(folder, out=sys.stdout):
    with open(os.path.join(folder, "samples.log"), encoding="utf-8") as log:
        samples = [words for words in map(str.split, log) if len(words) > 2 and words[1] in ("W", "G", "L")]
    films, late = os.path.join(folder, "films"), 0
    for name in sorted(os.listdir(films)):
        if not os.path.isfile(os.path.join(films, name, "film.log")) or name.startswith("metronome-"):
            continue
        film = Film(os.path.join(films, name))
        cause = cause_of(film)[0]
        # No further than the film goes: what the script does next, to set the next scene, is not this scene's.
        said = home_of(samples, cause - 20, min(cause + 4000, film.ends), set(film.after))
        if said["up"] is None:
            continue
        # The line of words goes seconds later, by itself.
        shown = [int(time) for time, (w, h) in zip(film.times, film.extents) if cause < time <= cause + 2500 and w * h > 40000 * film.scale**2]
        after = {window: time - cause for window, time in sorted(said["moved"].items())}
        late += bool(said["late"])
        down = f"{said['down'] - cause:+d}" if said["down"] else "the film's end, and beyond"
        print(f"{name}: stage {said['up'] - cause:+d} to {down}; windows moved last at "
              + (", ".join(f"{window} {time:+d}" for window, time in after.items()) or "no time")
              + f"; the display changed last at {shown[-1] - cause if shown else 0:+d}"
              + (f"; AFTER THE STAGE WENT: {', '.join(map(str, said['late']))}" if said["late"] else "")
              + (f"; the sampler saw nothing for up to {said['blind']} ms" if said["blind"] else ""), file=out)
    print(f"{late} scenes in which a window was still being moved when the stand-ins had gone", file=out)
    return 0


def act_of(samples, since, until, tick=1000 / 60):
    """One act as the window server saw it, from the W lines of ordinary windows: {window: [(time, frame)…]} for those that moved between the two moments, each beginning with where
    it was before; when the first and the last move were seen; and for how many of the display's frames some window was at a place or size that is neither its old nor its new one."""
    before, moves = {}, {}
    for words in samples:
        if words[1] != "W" or words[4] != "0" or words[9] == "Arbor":
            continue
        time, window, frame = int(words[0]), int(words[2]), tuple(float(word) for word in words[5:9])
        if time < since:
            before[window] = frame
        elif time <= until:
            moves.setdefault(window, [(since, before.get(window))]).append((time, frame))
    between = []
    for steps in moves.values():
        old, new = steps[0][1], steps[-1][1]
        between += [(time, later) for (time, frame), (later, _) in zip(steps[1:], steps[2:]) if frame not in (old, new)]
    # Two windows that are nowhere at the same moment are one bad frame, not two.
    bad, reached = 0.0, 0
    for start, end in sorted(between):
        bad += max(end - max(start, reached), 0)
        reached = max(reached, end)
    times = [time for steps in moves.values() for time, _ in steps[1:]]
    return {"moves": moves, "first": min(times, default=None), "last": max(times, default=None), "between": round(bad / tick)}


def acts(folder, out=sys.stdout):
    """Of every scene without motion: the two numbers that say whether "at once" is at once, by the display and by the window server."""
    samples = []
    if os.path.isfile(os.path.join(folder, "samples.log")):
        with open(os.path.join(folder, "samples.log"), encoding="utf-8") as log:
            samples = [words for words in map(str.split, log) if len(words) > 8 and words[1] == "W"]
    films = os.path.join(folder, "films")
    print("| Scene | Answers | On the display: pieces | first to last | the longest wait | frames with a window neither old nor new | holes, empty desk, over others | By the window server: first to last move | steps of each window that moved | frames in between |\n"
          "|---|---|---|---|---|---|---|---|---|---|", file=out)
    used, aloud = 0, []
    for name in sorted(os.listdir(films)):
        if not os.path.isfile(os.path.join(films, name, "film.log")):
            continue
        film = Film(os.path.join(films, name))
        if film.kind not in AT_ONCE + ("bare", "closes") or name.startswith("metronome-") or name.endswith("ground"):
            continue
        m = measure(film)
        cause, seen, worse = m["cause"], pieces(m), in_one_piece(m) or {}
        said = act_of(samples, cause - 20, min(cause + 2000, film.ends))
        steps = ", ".join(f"{window}: {len(moved) - 1}" for window, moved in sorted(said["moves"].items()))
        print(f"| `{name}` | {f'{seen_at(seen)} ms' if seen['frames'] and m['cause_known'] == 'exact' else '?'} | {len(seen['frames']) or 'none followed'} | "
              + (f"{seen['times'][-1] - seen['times'][0]} ms" if seen["frames"] else "") + f" | {waited(m, seen)} | {len(seen['between'])} {seen['between'][:8] if seen['between'] else ''}" + (f", of them the new size at the old place: {len(seen['sized'])}" if seen["sized"] else "") + " | "
              + (", ".join(f"{what} {frames}" for what, frames in worse.items() if frames) or "none") + " | "
              + (f"{said['last'] - said['first']} ms" if said["moves"] else "nothing moved") + f" | {steps or 'none'} | {said['between']} |", file=out)
        used += bool(worse.get("excused"))
        if stirred(m):
            aloud.append(f"`{name}`: NOT TO BE BELIEVED: a window changes in frame {stirred(m)[0]}, after Arbor's account of the windows and before the cause: the frame's time is wrong, or the scene was not at rest")
        if has_moved(film) is False:
            aloud.append(f"`{name}`: by Arbor's own account no window has another frame or state after the act than before it: whatever is counted above is no window's doing")
        if apart(film):
            aloud.append(f"`{name}`: a menu was open when the act began: the ruler does not look under it")
    print(f"\nThe one exception to \"over\", for what grows where it cannot (\"excused\"), was used in {used} acts.", file=out)
    if aloud:
        print("\nREAD THIS:\n" + "\n".join(f"- {line}" for line in aloud), file=out)
    return 0


def waited(m, seen):
    """How long the display stood still at the longest between the cause and the last piece of an act: before it answered, or between two frames of any kind. It is printed for every film, scored or
    not: a first use that is played once unscored is measured all the same, since a fault that is masked is not cured."""
    if not seen["frames"]:
        return ""
    film, cause = m["film"], m["cause"]
    times = [cause] + [int(time) for time in film.times[:seen["frames"][-1] + 1] if time > cause]
    return f"{max(after - before for before, after in zip(times, times[1:]))} ms" + ("" if m["cause_known"] == "exact" else " (from a mark, not a key)")


def seen_at(seen):
    return seen["times"][0]


def more_drawn(words):
    """What a second review drew to kill the mutants that the self-test let live: name -> (who draws it, how, must miss, may miss)."""
    import studio

    red, blue, green, orange, grid, framed = studio.RED, studio.BLUE, studio.GREEN, studio.ORANGE, studio.GRID, studio.FRAMED
    spread = {orange: (40, 70, 300, 200), red: (400, 70, 300, 190), blue: (400, 285, 300, 190), green: (400, 500, 300, 190)}
    end = {orange: grid[red], blue: grid[blue], red: grid[green], green: grid[orange]}
    fade = [(50 + 17 * step, 1 - step / 10) for step in range(1, 11)]
    late = {**end, blue: (40, 300, 300, 190)}
    own = dict(zip(grid, [(12, 43, 300, 190), (12, 374, 300, 190), (518, 43, 300, 190), (518, 374, 300, 190)]))
    home = dict(zip(grid, [(40, 70, 300, 200), (400, 70, 300, 190), (400, 285, 300, 190), (400, 500, 300, 190)]))
    paints = {"blend": (150, 120, 90), "thing": (90, 200, 200), "icon": (250, 250, 250), "hole": (0, 0, 0)}
    dim = tuple(int(value * 0.8) for value in studio.LIGHT)
    three, shifted = {blue: (12, 43, 494, 650), red: (518, 43, 494, 319), green: (518, 374, 494, 319)}, {blue: (12, 43, 494, 650), red: (518, 43, 494, 311), green: (518, 366, 494, 327)}
    move = {**grid, blue: (12, 374, 494, 311), red: (12, 43, 494, 311)}
    half = {**move, red: grid[red]}
    nudged = {colour: (x, y + 30, w, h - 30) for colour, (x, y, w, h) in grid.items()}
    apart_a, apart_b = {red: (30, 60, 300, 250), blue: (30, 380, 300, 250)}, {red: (600, 60, 300, 250), blue: (600, 380, 300, 250)}
    small = {**grid, red: (12, 43, 300, 190)}
    without = {colour: rect for place, (colour, rect) in enumerate(grid.items()) if place}
    menu = {"menu": True, "click": True, "was": "floating"}
    dark = {"ground": studio.LIGHT, "rim": True}
    steps = studio.shoot_steps
    return {
        "menu-arrange": (steps, {"steps": [(None, spread, 1), (50, end, 1)] + [(at, end, shows) for at, shows in fade] + [(1900, {**end, **words})], **menu}, [], []),
        "menu-arrange-and-the-left-column-is-late": (steps, {"steps": [(None, {**spread, blue: (40, 300, 300, 190)}, 1), (50, late, 1)] + [(at, late, shows) for at, shows in fade] + [(400, end), (1900, {**end, **words})], **menu},
                                                     ["R1"], ["R4", "R5"]),
        "dark-pause-in-two-steps": (steps, {"steps": [(None, grid), (50, own), (300, home), (1900, {**home, **words})], "how": "floating", **dark}, ["R1", "R4"], ["R5"]),
        "dark-pause": (steps, {"steps": [(None, grid), (50, home), (1900, {**home, **words})], "how": "floating", **dark}, [], []),
        "dark-a-hole-under-shadows": (steps, {"steps": [(None, framed), (34, without), (51, grid), (1900, {**grid, **words})], **dark}, ["R5"], []),
        "dark-the-first-dock-and-the-ground-darkens": (steps, {"steps": [(None, home, 0, studio.LIGHT), (50, {**home, red: (12, 43, 380, 650)}, 0, dim), (1900, {**home, red: (12, 43, 380, 650), **words}, 0, dim)],
                                                               "ground": studio.LIGHT, "was": "floating"}, [], []),
        "a-blend-for-a-frame": (steps, {"steps": [(None, grid), (34, {**framed, "blend": (300, 200, 260, 220)}), (51, framed), (1900, {**framed, **words})], "paints": paints}, [], ["M9"]),
        "a-thing-for-five-frames": (steps, {"steps": [(None, grid)] + [(34 + 17 * step, {**framed, "thing": (300, 200, 260, 220)}) for step in range(5)] + [(119, framed), (1900, {**framed, **words})], "paints": paints},
                                    ["R4"], ["M9", "R1", "R5"]),
        "told-in-two-steps": (steps, {"steps": [(None, grid), (150, own), (400, home), (1900, {**home, **words})], "kind": "told", "how": "floating"}, ["R1", "R4"], ["R5"]),
        "told": (steps, {"steps": [(None, grid), (150, home), (1900, {**home, **words})], "kind": "told", "how": "floating"}, [], []),
        "closes": (steps, {"steps": [(None, grid), (100, {red: grid[red], blue: grid[blue], green: (518, 43, 494, 650)}), (1900, {red: grid[red], blue: grid[blue], green: (518, 43, 494, 650), **words})], "kind": "closes"}, [], []),
        "a-bystander-a-pixel-larger": (steps, {"steps": [(None, three), (34, {**three, blue: (11, 42, 496, 652), red: shifted[red]}), (51, shifted), (1900, {**shifted, **words})]}, [], []),
        "a-hole-of-three-hundredths": (steps, {"steps": [(None, move), (34, {**half, "hole": (600, 100, 160, 130)}), (51, grid), (1900, {**grid, **words})], "paints": paints}, ["R5"], ["R4"]),
        "a-hole-of-a-two-hundredth": (steps, {"steps": [(None, move), (34, {**half, "hole": (600, 100, 60, 55)}), (51, grid), (1900, {**grid, **words})], "paints": paints}, [], ["R4"]),
        "a-window-creeps": (steps, {"steps": [(None, grid)] + [(34 + 17 * step, {**grid, red: (12, 43, 494 - 2 * step, 319)}) for step in range(1, 21)] + [(1900, {**grid, red: (12, 43, 454, 319), **words})]}, ["R1", "R4"], ["R3", "S8"]),
        "one-window-goes-and-comes-back": (steps, {"steps": [(None, grid), (34, without), (184, {**grid, blue: (12, 374, 494, 310)}), (1900, {**grid, blue: (12, 374, 494, 310), **words})]}, ["R1"], ["R4", "R5", "M8", "S8"]),
        "an-icon-wanders-in-a-window": (steps, {"steps": [(None, {**grid, "icon": (100, 120, 100, 100)}), (34, {**framed, "icon": (100, 120, 100, 100)}), (284, {**framed, "icon": (400, 300, 100, 100)}),
                                                          (1900, {**framed, "icon": (400, 300, 100, 100), **words})], "paints": paints}, [], []),
        "a-square-icon-grows-on-a-tile": (steps, {"steps": [(None, grid), (34, {**framed, "icon": (400, 250, 140, 140)}), (51, {**framed, "icon": (390, 240, 160, 160)}), (68, {**framed, "icon": (380, 230, 180, 180)}),
                                                            (1900, {**framed, "icon": (380, 230, 180, 180), **words})], "paints": paints}, [], []),
        "at-two-pixels-to-the-point-a-hole": (steps, {"steps": [(None, framed), (34, without), (51, grid), (1900, {**grid, **words})], "scale": 2}, ["R5"], []),
        "at-two-pixels-to-the-point-the-new-size-at-the-old-place": (steps, {"steps": [(None, {red: (500, 300, 200, 150), blue: grid[blue]}), (34, {red: (500, 300, 494, 319), blue: grid[blue]}), (51, {red: (518, 43, 494, 319), blue: grid[blue]}),
                                                                                       (1900, {red: (518, 43, 494, 319), blue: grid[blue], **words})], "scale": 2}, ["R4", "R5"], []),
        "windows-nudged-by-thirty": (steps, {"steps": [(None, grid), (34, nudged), (1900, {**nudged, **words})]}, [], ["S8"]),
        "an-empty-desk-between-two-arrangements-apart": (steps, {"steps": [(None, apart_a), (34, {}), (84, apart_b), (1900, {**apart_b, **words})]}, ["R5"], ["M8", "S8"]),
        "ground-left-bare-for-good-in-the-first-piece": (steps, {"steps": [(None, grid), (34, small), (51, {**small, blue: (12, 374, 300, 190)}), (1900, {**small, blue: (12, 374, 300, 190), **words})]}, [], ["S8"]),
    }


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
        "cards-out-of-place": ({"cards": True, "fade": 9, "offset": 5}, ["M6", "M12"], ["M4"]),
        "preview-left": ({"left": 3}, ["M13"], []),
        "blink": ({"blink": True}, ["M8"], ["M7", "M9"]),
        "good-and-not-a-frame-more": ({"words": False}, [], []),
        "flash": ({"flash": True}, ["M9"], []),
        "flash-at-the-edge": ({"flash": (0, 420, 150, 110)}, ["M9"], []),
        "flash-of-everything": ({"flash": (0, 31, 1024, 674)}, ["M9"], ["M7", "M8"]),
        "bars": ({"bars": True}, ["M11"], []),
        "at-once": ({"instant": True, "kind": "instant"}, [], []),
        "not-at-once": ({"kind": "instant"}, ["R1", "R3", "R4"], ["R5"]),
        "new-size-at-the-old-place": ({"instant": True, "kind": "instant", "halfway": True, "start": {studio.RED: (500, 300, 200, 150), studio.BLUE: studio.GRID[studio.BLUE]},
                                       "end": {studio.RED: (518, 43, 494, 319), studio.BLUE: studio.GRID[studio.BLUE]}}, ["R4", "R5"], ["R3", "S8"]),
        "one-by-one": ({"instant": True, "kind": "instant", "one_by_one": True}, ["R1"], ["R3", "R4", "R5"]),
        "a-hole": ({"instant": True, "kind": "instant", "hole": True, "start": studio.FRAMED, "end": studio.GRID}, ["R5"], []),
        "an-empty-desk": ({"instant": True, "kind": "instant", "empty": True}, ["R5"], ["R1", "M8"]),
        "uneven": ({"end": {**studio.FRAMED, studio.RED: (12, 43, 996, 650)}}, ["S8"], []),
    }
    words = {"words": (410, 612, 200, 36)}
    # The same for what is drawn by another hand: name -> (who draws it, how it is wrong, must miss, may miss)
    others = {
        "drag": (studio.shoot_drag, {}, [], []),
        "drag-that-rests-in-the-room": (studio.shoot_drag, {"drop": (760, 300)}, [], []),
        "drag-under-a-tint": (studio.shoot_drag, {"tint": True}, [], []),
        "drag-pulled": (studio.shoot_drag, {"pull": 30}, ["D1"], []),
        "drag-preview-lies": (studio.shoot_drag, {"preview_off": 8}, ["D2"], []),
        "others-leave-then-one-fills": (studio.shoot_steps, {"steps": [(None, studio.GRID), (34, {studio.RED: studio.GRID[studio.RED]}), (367, {studio.RED: studio.FRAMED[studio.RED]}),
                                                                       (1900, {studio.RED: studio.FRAMED[studio.RED], **words})]}, ["R1", "R5"], []),
        "an-empty-desk-for-long": (studio.shoot_steps, {"steps": [(None, studio.GRID), (34, {}), (634, studio.FRAMED), (1900, {**studio.FRAMED, **words})]}, ["R1", "R5"], ["M8"]),
        "one-arrives-very-late": (studio.shoot_steps, {"steps": [(None, studio.FRAMED), (34, {**studio.GRID, studio.RED: (12, 43, 300, 319)}), (1584, studio.GRID),
                                                                 (1900, {**studio.GRID, **words})]}, ["R1", "R4"], ["R5"]),
        "at-once-on-a-light-ground": (studio.shoot_steps, {"steps": [(None, studio.GRID), (34, studio.FRAMED), (1900, {**studio.FRAMED, **words})], "ground": (185, 190, 198)}, [], []),
        "a-hole-on-a-light-ground": (studio.shoot_steps, {"steps": [(None, studio.FRAMED), (34, {colour: rect for place, (colour, rect) in enumerate(studio.GRID.items()) if place}), (51, studio.GRID),
                                                                    (1900, {**studio.GRID, **words})], "ground": (185, 190, 198)}, ["R5"], []),
        "a-small-window-wanders-over-a-large-one": (studio.shoot_steps, {"steps": [(None, {studio.BLUE: (12, 43, 494, 650), studio.RED: (600, 100, 200, 160)}),
                                                                                   (34, {studio.BLUE: (12, 43, 1000, 650), studio.RED: (300, 300, 200, 160)}),
                                                                                   (284, {studio.BLUE: (12, 43, 1000, 650), studio.RED: (600, 100, 200, 160)}),
                                                                                   (1900, {studio.BLUE: (12, 43, 1000, 650), studio.RED: (600, 100, 200, 160), **words})]}, ["R1", "R4", "R5"], []),
        # From 612,243 200 by 300 to 500 by 400 at 700,100, which hangs over the display's right edge: the new size shows at the old place first, and may.
        "grows-where-it-cannot": (studio.shoot_steps, {"steps": [(None, {studio.BLUE: (12, 43, 494, 650), studio.RED: (612, 243, 200, 300)}), (34, {studio.BLUE: (12, 43, 494, 650), studio.RED: (612, 243, 500, 400)}),
                                                                 (51, {studio.BLUE: (12, 43, 494, 650), studio.RED: (700, 100, 500, 400)}),
                                                                 (1900, {studio.BLUE: (12, 43, 494, 650), studio.RED: (700, 100, 500, 400), **words})]}, ["R4"], []),
        "grows-where-it-can": (studio.shoot_steps, {"steps": [(None, {studio.BLUE: (12, 43, 494, 650), studio.RED: (612, 243, 200, 300)}), (34, {studio.BLUE: (12, 43, 494, 650), studio.RED: (612, 243, 400, 400)}),
                                                              (51, {studio.BLUE: (12, 43, 494, 650), studio.RED: (520, 100, 400, 400)}),
                                                              (1900, {studio.BLUE: (12, 43, 494, 650), studio.RED: (520, 100, 400, 400), **words})]}, ["R4", "R5"], ["S8"]),
        "grows-where-it-cannot-and-strays": (studio.shoot_steps, {"steps": [(None, {studio.BLUE: (12, 43, 494, 650), studio.RED: (612, 243, 200, 300)}), (34, {studio.BLUE: (12, 43, 494, 650), studio.RED: (100, 243, 500, 400)}),
                                                                            (51, {studio.BLUE: (12, 43, 494, 650), studio.RED: (700, 100, 500, 400)}),
                                                                            (1900, {studio.BLUE: (12, 43, 494, 650), studio.RED: (700, 100, 500, 400), **words})]}, ["R4", "R5"], []),
        **more_drawn(words),
        "drop": (studio.shoot_drop, {}, [], []),
        "dragged-out": (studio.shoot_drop, {"kind": "out", "preview": False}, [], []),
        "dragged-out-with-the-new-size-first": (studio.shoot_drop, {"kind": "out", "preview": False, "halfway": True}, ["R4", "R5"], []),
        "drop-with-the-new-size-first": (studio.shoot_drop, {"halfway": True}, ["R4", "R5"], []),
        "drop-that-takes-its-time": (studio.shoot_drop, {"late": 300}, ["R1"], ["R5"]),
        "dragged-out-with-a-preview": (studio.shoot_drop, {"kind": "out"}, ["D5"], []),
        "plain-drag": (studio.shoot_plain, {}, [], []),
        "plain-drag-with-words": (studio.shoot_plain, {"preview": True, "level": 6}, ["D5"], ["M9"]),
        "plain-drag-with-a-stage": (studio.shoot_plain, {"preview": True, "level": 4}, ["D5"], ["M9"]),
        "plain-drag-and-another-window-stirs": (studio.shoot_plain, {"other": 30}, ["D6"], []),
        "plain-drag-and-the-window-grows": (studio.shoot_plain, {"grown": 12}, ["D6"], []),
        "plain-drag-with-a-preview": (studio.shoot_plain, {"preview": True}, ["D5"], ["M9"]),
        "plain-drag-that-docks": (studio.shoot_plain, {"docks": True}, ["D6"], []),
        "plain-drag-put-right": (studio.shoot_plain, {"nudged": 9}, ["D6"], []),
        "fingers": (studio.shoot_follow, {}, [], []),
        "fingers-far-ahead": (studio.shoot_follow, {"lag": 6}, ["G1"], []),
        "fingers-and-a-step": (studio.shoot_follow, {"step": 30}, ["G1"], []),
        "panel": (studio.shoot_panel, {}, [], []),
        "panel-by-a-click": (studio.shoot_panel, {"click": True}, [], []),
        "panel-late": (studio.shoot_panel, {"late": 300}, ["P1", "M1"], []),
        "panel-slow": (studio.shoot_panel, {"fade": 30}, ["P1"], []),
        "panel-slides": (studio.shoot_panel, {"slide": 60}, ["P2"], []),
    }
    cases = {name: (studio.shoot, *case) for name, case in cases.items()} | others
    grown = {studio.BLUE: (12, 43, 494, 650), studio.RED: (612, 243, 400, 400)}
    spread = {studio.ORANGE: (40, 70, 300, 200), studio.RED: (400, 70, 300, 190), studio.BLUE: (400, 285, 300, 190), studio.GREEN: (400, 500, 300, 190)}
    arranged = {studio.ORANGE: studio.GRID[studio.RED], studio.BLUE: studio.GRID[studio.BLUE], studio.RED: studio.GRID[studio.GREEN], studio.GREEN: studio.GRID[studio.ORANGE]}
    left = {studio.ORANGE: arranged[studio.ORANGE], studio.BLUE: arranged[studio.BLUE]}
    # Films that are dirty where the ruler cannot know it: R1, R4 and R5 may say what they like but "passes": name -> (who draws it, how).
    blind = {
        # The frame with the new size at the old place carries a time before the key, as macOS was seen to stamp one.
        "a-frame-stamped-before-its-cause": (studio.shoot_steps, {"steps": [(None, {studio.BLUE: (12, 43, 494, 650), studio.RED: (612, 243, 200, 300)}), (-300, grown), (51, {studio.BLUE: (12, 43, 494, 650), studio.RED: (520, 100, 400, 400)}),
                                                                            (1900, {studio.BLUE: (12, 43, 494, 650), studio.RED: (520, 100, 400, 400), **words})]}),
        # The right column, which lies under the menu, comes long after the menu has gone.
        "menu-arrange-and-the-right-column-is-late": (studio.shoot_steps, {"steps": [(None, spread, 1), (50, left, 1)] + [(50 + 17 * step, left, 1 - step / 10) for step in range(1, 11)] + [(450, arranged), (1900, {**arranged, **words})],
                                                                           "menu": True, "click": True, "was": "floating", "after": arranged}),
    }
    # Films in which nothing may be earned: name -> (who draws it, how).
    barren = {
        "nothing-but-words": (studio.shoot, {"end": studio.GRID}),
        "nothing-but-words-at-once": (studio.shoot_steps, {"steps": [(None, studio.GRID), (34, {**studio.GRID, **words}), (1900, studio.GRID)]}),
        "a-panel-goes-and-no-window-moves": (studio.shoot_steps, {"steps": [(None, {**studio.GRID, (70, 70, 74): (212, 201, 600, 300)}), (34, studio.GRID), (1900, {**studio.GRID, **words})], "moved": False}),
        "a-drop-that-docks-nothing": (studio.shoot_drop, {"nothing": True}),
        "a-plain-drag-without-a-drag": (studio.shoot_plain, {"no_drag": True}),
    }
    failures = 0
    with tempfile.TemporaryDirectory() as folder:
        # The bare desks that the two kinds of session begin with.
        studio.bare(folder, "ground", (0, 0, 0))
        studio.bare(folder, "dark-ground", studio.LIGHT)
        for name, (draw, faults, must, may) in cases.items():
            draw(os.path.join(folder, name), **faults)
            _, verdicts = judge(os.path.join(folder, name))
            missed = [identifier for identifier, verdict in verdicts.items() if verdict.status == MISS]
            unseen = [identifier for identifier, verdict in verdicts.items() if verdict.status == UNSEEN and verdict.said not in (not_yet(None, None).said, NOTHING_DOCKED) and not verdict.said.endswith("for eyes")]
            wrong = [f"{identifier} did not miss" for identifier in must if identifier not in missed]
            wrong += [f"{identifier} missed: {verdicts[identifier].said}" for identifier in missed if identifier not in must + may]
            wrong += [f"{identifier} saw nothing: {verdicts[identifier].said}" for identifier in unseen]
            failures += bool(wrong)
            print(f"{'✘' if wrong else '✔'} {name}: missed {', '.join(missed) or 'nothing'}" + "".join(f"\n    {line}" for line in wrong))
        # The room of the exception, edge by edge, with the Dock at each of its three places. The window stands at 100, 100, 200 wide and 300 high; its drawn rectangle begins a title bar lower.
        class Was:
            edges = (100, 128, 300, 400)

        def excused(visible, after, before=None, seen=None, was=Was):
            film = types.SimpleNamespace(display=[0, 0, 1024, 768], visible=visible, scale=1, before=before or {1: [100.0, 100.0, 200.0, 300.0]}, after=after if isinstance(after, dict) else {1: after})
            return grows_where_it_cannot(film, was, seen)
        at_right, at_left, below = [0, 31, 960, 737], [70, 31, 954, 737], [0, 31, 1024, 667]
        rooms = {
            "within": excused(at_right, [400.0, 100.0, 500.0, 400.0]) is False,
            "over the visible frame's right edge": excused(at_right, [500.0, 100.0, 500.0, 400.0]) is True,
            "to the point on that edge": excused(at_right, [460.0, 100.0, 500.0, 400.0]) is False,
            "0.4 over it, as the product lets pass": excused(at_right, [460.4, 100.0, 500.0, 400.0]) is False,
            "0.6 over it": excused(at_right, [460.6, 100.0, 500.0, 400.0]) is True,
            "below the foot": excused(at_right, [400.0, 400.0, 500.0, 400.0]) is True,
            "to the point on the foot": excused(at_right, [400.0, 368.0, 500.0, 400.0]) is False,
            "the Dock below: on the display and under the visible foot": excused(below, [400.0, 320.0, 500.0, 400.0]) is True,
            "the Dock below: to the point on the visible foot": excused(below, [400.0, 298.0, 500.0, 400.0]) is False,
            "the Dock at the left: in its strip there is room": excused(at_left, [10.0, 100.0, 500.0, 400.0]) is False,
            "the Dock at the left: the right edge is the visible frame's own": excused(at_left, [500.0, 100.0, 524.0, 400.0]) is False,
            "the Dock at the left: a point over it": excused(at_left, [501.0, 100.0, 524.0, 400.0]) is True,
            "over the display's left edge": excused(at_right, [-10.0, 100.0, 500.0, 400.0]) is True,
            "over the display's top": excused(at_right, [400.0, -10.0, 500.0, 400.0]) is True,
            "under the menu bar there is room": excused(at_right, [400.0, 10.0, 500.0, 400.0]) is False,
            "one that shrinks": excused(at_right, [980.0, 100.0, 150.0, 200.0]) is False,
            "one that only grows higher": excused(at_right, [900.0, 100.0, 200.0, 400.0]) is True,
            "one that only grows wider": excused(at_right, [900.0, 100.0, 300.0, 300.0]) is True,
            "wider and shorter": excused(at_right, [900.0, 100.0, 300.0, 200.0]) is True,
            "of two windows the nearer one decides": excused(at_right, {1: [900.0, 100.0, 300.0, 300.0], 2: [400.0, 100.0, 100.0, 100.0]}, {2: [102.0, 100.0, 196.0, 298.0], 1: [100.0, 100.0, 200.0, 300.0]}) is True,
            "none near: nobody is excused": excused(at_right, [900.0, 100.0, 300.0, 300.0], {1: [140.0, 100.0, 200.0, 300.0]}) is False,
            "another window with the same sides and foot, and its top elsewhere": excused(at_right, [900.0, 100.0, 300.0, 300.0], {1: [100.0, 300.0, 200.0, 100.0]}) is False,
            "seen at the new size": excused(at_right, [900.0, 100.0, 300.0, 350.0], seen=types.SimpleNamespace(edges=(100, 128, 400, 450))) is True,
            "seen at a third size": excused(at_right, [900.0, 100.0, 300.0, 350.0], seen=types.SimpleNamespace(edges=(100, 128, 500, 540))) is False,
            "seen as wide as the new and no higher than the old": excused(at_right, [900.0, 100.0, 300.0, 350.0], seen=types.SimpleNamespace(edges=(100, 128, 400, 400))) is False,
            "seen cut at the room's foot": excused(at_right, [900.0, 60.0, 300.0, 700.0], seen=types.SimpleNamespace(edges=(100, 128, 400, 768))) is True,
        }
        wrong = [name for name, right in rooms.items() if not right]
        failures += bool(wrong)
        print(f"{'✘' if wrong else '✔'} the room of the exception, {len(rooms)} frames: " + ("WRONG: " + "; ".join(wrong) if wrong else "each as the product has it"))
        _, verdicts = judge(os.path.join(folder, "grows-where-it-cannot"))
        counted = "was used in 1 frames" in verdicts["R5"].said
        failures += not counted
        print(f"{'✔' if counted else '✘'} the exception is counted: {verdicts['R5'].said}")
        for name, (draw, how) in blind.items():
            draw(os.path.join(folder, name), **how)
            _, verdicts = judge(os.path.join(folder, name))
            passed = [identifier for identifier in ("R1", "R4", "R5") if verdicts[identifier].status == PASS]
            failures += bool(passed)
            print(f"{'✘' if passed else '✔'} {name}: " + (f"PASSES {', '.join(passed)}" if passed else f"passes none of R1, R4, R5: {verdicts['R5'].said[:90]}"))
        for name, (draw, how) in barren.items():
            draw(os.path.join(folder, name), **how)
            _, verdicts = judge(os.path.join(folder, name))
            # That nothing is left behind, and that bars and Dock are left alone, is true of a film in which a drag took place and did nothing.
            earned = [identifier for identifier, verdict in verdicts.items() if verdict.status == PASS]
            failures += bool(earned)
            print(f"{'✘' if earned else '✔'} {name}: earns {', '.join(earned) or 'nothing'}")
        # The score itself, through the command: the table of what ships, its new rows, and the first lines.
        table = os.path.join(folder, "table")
        for drawn, scenes in (("at-once", ["fill"]), ("told", ["eight-arrange-told", "crowd-arrange-told-again", "quit"]), ("ground", ["ground"])):
            for scene in scenes:
                shutil.copytree(os.path.join(folder, drawn), os.path.join(table, "films", scene))
        wrong = []

        def scored(ships):
            path = os.path.join(table, "films", "ships.json")
            if ships is None:
                if os.path.exists(path):
                    os.remove(path)
            else:
                with open(path, "w", encoding="utf-8") as file:
                    json.dump(ships, file)
            said = io.StringIO()
            return score(table, out=said), [line for line in said.getvalue().splitlines() if line]
        summary, lines = scored(None)
        cells = {(cell["where"], cell["check"]): cell for cell in summary["cells"]}
        wrong += [] if lines[0].startswith("**THE INSTRUMENTS FAILED") else ["no metronome was filmed, and the first line does not say that the instruments failed"]
        wrong += [] if lines[1].startswith("**SEEN: ") and "UNDER HALF" in lines[1] else ["four films of some seventy, and the second line does not say that under half was seen"]
        wrong += [] if any("they say nothing of what was switched" in line for line in lines) else ["films that say nothing of their switches are taken at their word"]
        for name, kind, gate in SHIPS:
            found = {check for where, check in cells if where == name}
            wrong += [] if "R5" in found or kind not in AT_ONCE else [f"{name} has no cell for R5"]
            wrong += [] if ("M1" in found) == (kind in ("instant", "drop", "out")) or kind not in AT_ONCE else [f"{name}, {kind}: M1 is {'asked' if 'M1' in found else 'not asked'}"]
            # (A panel of the same name has cells of its own under it: the menu.)
            wrong += [] if name in SHIPPED or all(bool(cells[name, check]["move"]) == bool(gate) for check in found) else [f"{name}: the gate {'does not ask' if gate else 'asks'} for it"]
        for name in ("eight-arrange", "eight-arrange-again", "crowd-arrange", "crowd-arrange-again", "eight-arrange-told", "eight-arrange-told-again", "crowd-arrange-told", "crowd-arrange-told-again"):
            wrong += [] if (name, "R1") in cells and not cells[name, "R1"]["move"] else [f"{name} is no row of what ships, or the gate asks for it"]
        for name in ("fill", "eight-arrange-told", "crowd-arrange-told-again"):
            wrong += [] if all(cells[name, check]["status"] == PASS for check in ("R1", "R4", "R5")) else [f"{name}, drawn clean, does not pass R1, R4 and R5"]
        wrong += [] if cells["crowd-arrange-told", "R5"]["status"] == UNSEEN else ["a scene that was not filmed is not unseen"]
        wrong += [] if summary["total"] == sum(WEIGHT[cell["severity"]] for cell in summary["cells"]) and summary["earned"] == sum(WEIGHT[cell["severity"]] for cell in summary["cells"] if cell["status"] == PASS) \
            else ["the sum is not the sum of its cells"]
        summary, lines = scored({"written": {"focusRing": False}, "still": ["a plain drag docks"]})
        wrong += [] if lines[1].startswith("**NOT YET WHAT SHIPS") and "focusRing false" in lines[1] and "a plain drag docks" in lines[1] else ["films of switches: the second line does not say so"]
        wrong += [] if not any("That is Arbor as it ships" in line for line in lines) else ["films of switches are called Arbor as it ships"]
        summary, lines = scored({"written": {}, "still": ["a plain drag docks"]})
        wrong += [] if lines[1].startswith("**NOT YET WHAT SHIPS") and "written out" not in lines[1] else ["what no switch can give: the second line does not say so, or speaks of switches"]
        summary, lines = scored({"written": {}, "still": []})
        wrong += [] if not any("NOT YET" in line for line in lines) and any(line.startswith("That is Arbor as it ships, on a Mac as it comes.") and "nothing of what" not in line for line in lines) \
            else ["films of what ships are not called so"]
        wrong += [] if first_lines(True, [], 500, 1000, "ships") == [] else ["exactly half is called under half"]
        wrong += [] if first_lines(True, [], 4999, 10000, "ships")[0].startswith("**SEEN: 49% OF WHAT SHIPS") else ["a hair under half is rounded up to half"]
        wrong += [] if first_lines(True, [], 0, 1000, "options")[0].startswith("**SEEN: 0% OF THE OPTIONS") else ["nothing seen of the options"]
        failures += bool(wrong)
        print(f"{'✘' if wrong else '✔'} the score, through the command: " + ("; ".join(wrong) if wrong else "its rows, its sums and its first lines"))
        # The window server's account beside a drawn film, through the command itself.
        run = os.path.join(folder, "run")
        studio.shoot(os.path.join(run, "films", "late"), cards=True)
        film = Film(os.path.join(run, "films", "late"))
        cause, window = cause_of(film)[0], sorted(film.after)[0] if film.after else 7
        with open(os.path.join(run, "samples.log"), "w", encoding="utf-8") as log:
            log.write(f"{cause + 15} W 50 2 4 0 0 1024 768 Arbor\n{cause + 30} W {window} 1 0 5 5 9 9 Oak\n{cause + 600} G 50\n{cause + 700} W {window} 1 0 6 6 9 9 Oak\n"
                      f"{film.ends + 50} W {window} 1 0 7 7 9 9 Oak\n")
        told = io.StringIO()
        home(run, told)
        right = (not film.after or "AFTER THE STAGE WENT" in told.getvalue()) and "stage +15 to +600" in told.getvalue()
        failures += not right
        print(f"{'✔' if right else '✘'} home: {told.getvalue().splitlines()[0]}")
    print(f"{len(cases) + len(barren) + len(blind) + 4 - failures} of {len(cases) + len(barren) + len(blind) + 4} drawn films judged as they should be")
    account = [line.split() for line in ("90 W 7 1 0 0 0 9 9 Oak", "110 W 50 2 4 0 0 100 100 Arbor", "120 W 7 1 0 5 5 9 9 Oak", "130 W 8 1 0 5 5 9 9 Elm",
                                         "140 W 51 2 3 0 0 9 9 Arbor", "300 L 45", "600 G 50", "640 W 8 1 0 6 6 9 9 Elm", "5000 W 7 1 0 1 1 9 9 Oak")]
    said = home_of(account, 100, 4000, {7, 8})
    wanted = {"up": 110, "down": 600, "moved": {7: 120, 8: 640}, "late": [8], "blind": 45}
    print(f"{'✔' if said == wanted else '✘'} the window server's account: {said}")
    # One window goes at once; another takes its new size at its old place for two frames; a third was moved before the act.
    account = [line.split() for line in ("50 W 1 9 0 0 0 10 10 Oak", "50 W 2 9 0 0 0 10 10 Elm", "60 W 3 9 0 5 5 10 10 Ash", "120 W 1 9 0 50 0 20 10 Oak", "120 W 2 9 0 0 0 20 10 Elm",
                                         "153 W 2 9 0 50 50 20 10 Elm", "130 W 7 9 4 0 0 99 99 Arbor")]
    act = act_of(account, 100, 1000)
    right = (act["first"], act["last"], act["between"], sorted(act["moves"])) == (120, 153, 2, [1, 2])
    print(f"{'✔' if right else '✘'} an act in two steps: first {act['first']}, last {act['last']}, {act['between']} frames in between, windows {sorted(act['moves'])}")
    return 1 if failures or said != wanted or not right else 0


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
        options = "--options" in arguments
        arguments = [argument for argument in arguments if argument != "--options"]
        without = [panel.strip() for panel in (option(arguments, "--without") or "").split(",") if panel.strip()]
        if set(without) - set(PANELS):
            raise SystemExit(f"judge.py: no panels of docs/POLISH.md: {', '.join(sorted(set(without) - set(PANELS)))}")
        summary = score(arguments[0], eyes, stills, without=without, which="options" if options else "ships")
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
            downs, ups = ([time for time, what, _, _ in film.buttons if what == which] for which in ("down", "up"))
            if film.kind in ("drag", "aside", "drop", "out", "plain") and downs and ups:
                # What happens while the button is down comes before the cause.
                held = [index for index, time in enumerate(film.times) if downs[0] - 20 <= time <= ups[-1] + 20]
                if held:
                    parts["held"] = [held[int(place)] for place in np.linspace(0, len(held) - 1, min(12, len(held)))]
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
                    brief.write("Sheets: " + ", ".join(os.path.abspath(os.path.join(sheets, f"{name}-{part}.png")) for part in ("held", "begins", "whole", "ends")
                                                       if os.path.isfile(os.path.join(sheets, f"{name}-{part}.png"))) + "\n")
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
                             for check in [check for check, _, _ in EYES] + ["D3", "D4"] if check in said}
                    refuted = {claim["claim"].split(":")[0].strip(): claim["why"] for claim in said.get("claims", []) if claim["verdict"].startswith("refute")}
                    entry.update({key: value for key, value in (("refuted", refuted), ("other", said.get("other")), ("void", said.get("void"))) if value})
                    scenes[name] = entry
        json.dump({"run": arguments[0], "commit": arguments[1], "scenes": scenes}, sys.stdout, indent=1, ensure_ascii=False)
        return 0
    if command == "stills":
        panels, other = {}, []
        for path in arguments[2:]:
            with open(path, encoding="utf-8") as file:
                said = json.load(file)
            other += said.get("other", []) + said["panels"].pop("other", [])
            for panel, cells in said["panels"].items():
                if panel not in PANELS:
                    raise SystemExit(f"judge.py: {path} speaks of {panel}, which is no panel of docs/POLISH.md")
                for cell, verdict in cells.items():
                    if cell not in dict(STILLS) or verdict["status"] not in (PASS, MISS):
                        raise SystemExit(f"judge.py: {path}, {panel}: {cell}: {verdict['status']} is no cell of docs/POLISH.md, or no verdict")
                    # Of two reviewers the one who found a fault is believed.
                    if panels.setdefault(panel, {}).get(cell, {}).get("status") != MISS:
                        panels[panel][cell] = {"status": verdict["status"], "said": verdict["said"], "pictures": verdict.get("pictures", [])}
        json.dump({"commit": arguments[0], "from": arguments[1], "panels": panels, "other": other}, sys.stdout, indent=1, ensure_ascii=False)
        return 0
    if command == "home":
        return home(arguments[0])
    if command == "acts":
        return acts(arguments[0])
    if command == "frame":
        Image.fromarray(Film(arguments[0]).frame(int(arguments[1]))).save(arguments[2])
        return 0
    print(__doc__)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
