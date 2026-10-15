#!/usr/bin/env python3
"""Lays the arms of scripts/mac-shell/films-arms.sh side by side: the same acts on one Mac by Arbor as built from several commits.

  arms.py <run folder> test|safari      the table, act by act and arm by arm, then the count: of the acts on the test window, or of those on Safari
  arms.py --self-test

A real app's window is no flat rectangle with a plain title bar, so the judge's ruler does not follow it. But the films show one window of one colour (the test window's own; Safari on a page of
one colour, which macOS carries up into the toolbar): so the box of everything near that colour, in every frame, is the window, less its title bar if that is plain, as the display drew it. From those boxes, for every act: in how many pieces it arrived
and how long that took; the display's frames in which the window had the size of the end at the place of the start; those in which it covered what neither its old frame nor its new one covers.

Needs numpy and Pillow (and no Mac).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402

from film import Film  # noqa: E402
from measure import TICK, cause_of  # noqa: E402


def boxes(film, colour, by=(40, 45, 60)):
    """[(frame, ms after the cause, (x, y, w, h) or None)], one entry for every frame in which the box of that colour is another than in the frame before. In points."""
    cause, found = cause_of(film)[0], []
    _, top, _, height = (int(value * film.scale) for value in film.visible)
    for index, time, picture, _ in film.frames():
        near = np.ones(picture.shape[:2], dtype=bool)
        for channel in range(3):
            near &= np.abs(picture[:, :, channel].astype(np.int16) - colour[channel]) < by[channel]
        # The menu bar and the Dock have colours of their own.
        near[:top], near[top + height:] = False, False
        rows, columns = np.where(near.sum(axis=1) > 100 * film.scale)[0], np.where(near.sum(axis=0) > 60 * film.scale)[0]
        box = tuple(int(round(value / film.scale)) for value in (columns[0], rows[0], columns[-1] - columns[0] + 1, rows[-1] - rows[0] + 1)) if len(rows) and len(columns) else None
        if not found or found[-1][2] != box:
            found.append((index, int(time) - cause, box))
    return found


def outside(box, old, new):
    """The area of a box that lies in neither of two others, in square points."""
    def shared(*others):
        left, top = max(other[0] for other in others), max(other[1] for other in others)
        right, bottom = min(other[0] + other[2] for other in others), min(other[1] + other[3] for other in others)
        return max(right - left, 0) * max(bottom - top, 0)
    return box[2] * box[3] - shared(box, old) - shared(box, new) + shared(box, old, new)


def act(sequence, ends):
    """One act from its boxes: {"states": the boxes after the cause with their times, "pieces", "took", "sized": display frames with the size of the end at the place of the start,
    "outside": display frames outside old ∪ new, "end"}. A box that differs by a point from the one before is the same box: an edge's soft pixel."""
    before = [entry for entry in sequence if entry[1] < 0 and entry[2]]
    after = [entry for entry in sequence if entry[1] >= 0 and entry[2]]
    if not before or not after:
        return None
    old, states = before[-1][2], []
    for _, time, box in after:
        if max(abs(a - b) for a, b in zip(box, states[-1][1] if states else old)) > 1:
            states.append((time, box))
    if not states:
        return {"states": [], "pieces": 0, "took": 0, "sized": 0, "outside": 0, "end": old}
    new, sized, out = states[-1][1], 0, 0
    for (time, box), (following, _) in zip(states, states[1:]):
        frames = max(int(round((following - time) / TICK)), 1)
        if max(abs(box[0] - old[0]), abs(box[1] - old[1])) <= 2 and (abs(box[2] - new[2]) <= 2 or abs(box[3] - new[3]) <= 2) and max(abs(box[2] - old[2]), abs(box[3] - old[3])) > 2:
            sized += frames
        if outside(box, old, new) > 400:
            out += frames
    return {"states": states, "pieces": len(states), "took": states[-1][0] - states[0][0], "sized": sized, "outside": out, "end": new}


# The colours as a hosted Mac's display shows them.
CAST = {"test": (255, 56, 60), "safari": (255, 141, 40)}


def table(folder, cast, out=sys.stdout):
    films, acts, arms, colour = os.path.join(folder, "films"), {}, [], CAST[cast]
    for name in sorted(os.listdir(films)):
        if not os.path.isfile(os.path.join(films, name, "film.log")) or name.startswith(("metronome-", "ground")):
            continue
        arm, _, what = name.partition("-")
        # <arm>-<cast>-<act>; films of the first run have no cast in their names and are Safari's.
        if what.startswith(("test-", "safari-")):
            if not what.startswith(cast + "-"):
                continue
            what = what.partition("-")[2]
        elif cast != "safari":
            continue
        film = Film(os.path.join(films, name))
        said = act(boxes(film, colour), film.ends)
        if said is not None:
            acts.setdefault(what if arm != "macos" else name, {})[arm] = said
            if arm not in arms:
                arms.append(arm)
    arms = [arm for arm in arms if arm != "macos"]
    print("| Act | " + " | ".join(arms) + " |\n|---|" + "---|" * len(arms), file=out)
    for what, by_arm in acts.items():
        if "macos" in by_arm:
            continue
        print(f"| {what} | " + " | ".join(" · ".join(f"+{time}: {box[0]},{box[1]} {box[2]}×{box[3]}" for time, box in by_arm[arm]["states"]) if arm in by_arm else "not filmed" for arm in arms) + " |", file=out)
    print("\n| | " + " | ".join(arms) + " |\n|---|" + "---|" * len(arms), file=out)
    rows = (("Display frames with the size of the end at the place of the start", lambda said: sum(one["sized"] for one in said)),
            ("Display frames with the window outside old ∪ new", lambda said: sum(one["outside"] for one in said)),
            ("Acts that arrive in one piece", lambda said: f"{sum(one['pieces'] <= 1 for one in said)} of {len(said)}"),
            ("Pieces in all acts", lambda said: sum(one["pieces"] for one in said)),
            ("The longest act, first to last", lambda said: f"{max(one['took'] for one in said)} ms"))
    for title, count in rows:
        print(f"| {title} | " + " | ".join(str(count([by_arm[arm] for by_arm in acts.values() if arm in by_arm])) for arm in arms) + " |", file=out)
    print("\nmacOS's own tiling of the same window:", file=out)
    for what, by_arm in acts.items():
        if "macos" in by_arm:
            said = by_arm["macos"]
            print(f"- {what}: {said['pieces']} states drawn over {said['took']} ms, ending at {said['end']}", file=out)
    return 0


def self_test():
    old, new = (260, 120, 574, 380), (12, 43, 574, 653)
    cases = {
        "at once": ([(0, -900, old), (1, 60, new)], (1, 0, 0, 0)),
        "moved, then grown": ([(0, -900, old), (1, 73, (12, 43, 574, 586)), (2, 89, new)], (2, 16, 0, 0)),
        "grown where it stands, for two frames": ([(0, -900, old), (1, 47, (260, 120, 574, 586)), (2, 80, (12, 77, 574, 586)), (3, 114, new)], (3, 67, 2, 2)),
        "the size of the end at the place of the start": ([(0, -900, old), (1, 38, (260, 120, 574, 653)), (2, 55, new)], (2, 17, 1, 1)),
        "a soft pixel is no piece": ([(0, -900, old), (1, 60, new), (2, 77, (12, 43, 574, 654))], (1, 0, 0, 0)),
        "nothing happens": ([(0, -900, old)], None),
    }
    failures = 0
    for name, (sequence, wanted) in cases.items():
        said = act(sequence, 0)
        got = None if said is None else (said["pieces"], said["took"], said["sized"], said["outside"])
        failures += got != wanted
        print(f"{'✔' if got == wanted else '✘'} {name}: {got}")
    right = outside((0, 0, 10, 10), (0, 0, 5, 10), (5, 0, 5, 10)) == 0 and outside((0, 0, 10, 10), (0, 0, 5, 10), (0, 0, 5, 10)) == 50 and outside((20, 20, 4, 4), (0, 0, 5, 5), (5, 5, 5, 5)) == 16
    failures += not right
    print(f"{'✔' if right else '✘'} what lies in neither of two boxes")
    print(f"{len(cases) + 1 - failures} of {len(cases) + 1} as they should be")
    return 1 if failures else 0


def main(arguments):
    if not arguments or arguments[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if arguments[0] == "--self-test":
        return self_test()
    return table(arguments[0], arguments[1] if len(arguments) > 1 else "safari")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
