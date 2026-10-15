#!/usr/bin/env python3
"""Lays the arms of scripts/mac-shell/films-arms.sh side by side: the same acts on one Mac by Arbor as built from several commits.

  arms.py <run folder> test|safari      the table, act by act and arm by arm, then the count: of the acts on the test window, or of those on Safari
  arms.py --self-test

A real app's window is no flat rectangle with a plain title bar, so the judge's ruler does not follow it. But the films show one window of one colour (the test window's own; Safari on a page of
one colour, which macOS carries up into the toolbar): so the box of everything near that colour, in every frame, is the window, less its title bar if that is plain, as the display drew it. From those boxes, for every act: in how many pieces it arrived
and how long that took; the display's frames in which the window had a new size at the place of the start; those in which it covered what neither its old frame nor its new one covers.

How things stood before an act is not taken from the film alone. Arbor's own account, noted when the scene begins, says where the window is; a frame that is stamped after that account and before the
key, and shows the window otherwise, has a wrong time (macOS was seen to hand the camera a stale one for the first frame after a long rest). It belongs to the act: it is put where the window
server's list (samples.log) first has that size after the key, and the table says so aloud.

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


def alike(a, b, by=1):
    """Whether no edge of one box is further than that from the same edge of the other."""
    def edges(box):
        return box[0], box[1], box[0] + box[2], box[1] + box[3]
    return (a is None) == (b is None) and (a is None or max(abs(p - q) for p, q in zip(edges(a), edges(b))) <= by)


def act(sequence):
    """One act from its boxes: {"states": the boxes after the cause with their times (None: the window is not to be seen), "pieces", "took", "sized": display frames with a new size at the place of
    the start, "outside": display frames outside old ∪ new, "end"}. A box that differs by a point from the one before is the same box: an edge's soft pixel. None where the window was not
    to be seen before the act."""
    before = [entry for entry in sequence if entry[1] < 0]
    if not before or before[-1][2] is None:
        return None
    old, states = before[-1][2], []
    for _, time, box in sequence:
        if time >= 0 and not alike(box, states[-1][1] if states else old):
            states.append((time, box))
    if not states:
        return {"states": [], "pieces": 0, "took": 0, "sized": 0, "outside": 0, "end": old}
    new, sized, out = states[-1][1], 0, 0
    for (time, box), (following, _) in zip(states, states[1:]):
        frames = max(int(round((following - time) / TICK)), 1)
        if box is None:
            continue
        # Its corner is where it was and its size is no longer what it was: how much of the new size it gets there is macOS's to say.
        if max(abs(box[0] - old[0]), abs(box[1] - old[1])) <= 2 and max(abs(box[2] - old[2]), abs(box[3] - old[3])) > 2:
            sized += frames
        # Within two points of either it is there: the ruler is no finer.
        if not alike(box, old, 2) and not alike(box, new, 2) and outside(box, old, new or old) > 400:
            out += frames
    return {"states": states, "pieces": len(states), "took": states[-1][0] - states[0][0], "sized": sized, "outside": out, "end": new}


def set_right(film, sequence, samples):
    """The boxes with every frame that is stamped between Arbor's account of the windows and the cause, and shows the window otherwise than that account, put after the cause. Returns them and what to
    say about it, or nothing. The window is the one whose frame in the account has the first box's left, right and bottom (its title bar may be plain, and so no part of the box)."""
    cause = cause_of(film)[0]
    noted = [time - cause for time, mark in film.marks if mark.startswith("before ")]
    if not noted or not sequence or sequence[0][2] is None:
        return sequence, ""

    def fits(box, frame):
        return box is not None and max(abs(box[0] - frame[0]), abs(box[0] + box[2] - frame[0] - frame[2]), abs(box[1] + box[3] - frame[1] - frame[3])) <= 3

    told = next(((window, frame) for window, frame in film.before.items() if fits(sequence[0][2], frame)), None)
    if told is None:
        return sequence, "ARBOR'S OWN ACCOUNT HAS NO WINDOW WHERE THE FILM BEGINS"
    window, frame = told
    wrong = [entry for entry in sequence if noted[-1] <= entry[1] < 0 and not fits(entry[2], frame)]
    if not wrong:
        return sequence, ""
    right, said = [entry for entry in sequence if entry not in wrong], []
    for index, time, box in wrong:
        seen = [int(words[0]) - cause for words in samples if int(words[2]) == window and 0 <= int(words[0]) - cause <= 1000 and box is not None
                and abs(float(words[7]) - box[2]) <= 3 and abs(float(words[6]) + float(words[8]) - box[1] - box[3]) <= 3]
        at = min(seen) if seen else 0
        right.append((index, at, box))
        said.append(f"FRAME {index} IS STAMPED {-time} ms BEFORE ITS CAUSE; put at +{at}, " + ("where the window server first has that state" if seen else "the cause itself: nothing says better"))
    return sorted(right, key=lambda entry: (entry[1], entry[0])), "; ".join(said)


# The colours as a hosted Mac's display shows them.
CAST = {"test": (255, 56, 60), "safari": (255, 141, 40)}


def table(folder, cast, out=sys.stdout):
    films, acts, arms, colour, notes, samples = os.path.join(folder, "films"), {}, [], CAST[cast], [], []
    if os.path.isfile(os.path.join(folder, "samples.log")):
        with open(os.path.join(folder, "samples.log"), encoding="utf-8") as log:
            samples = [words for words in map(str.split, log) if len(words) > 8 and words[1] == "W"]

    def began(name):
        with open(os.path.join(films, name, "film.log"), encoding="utf-8") as log:
            return int(log.readline().split()[0])

    # In the order they were played, which is the order the script names the arms in.
    for name in sorted((name for name in os.listdir(films) if os.path.isfile(os.path.join(films, name, "film.log"))), key=began):
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
        sequence, note = set_right(film, boxes(film, colour), samples)
        said = act(sequence)
        if note:
            notes.append(f"`{name}`: {note}")
        if said is not None:
            said["kind"] = film.kind
            acts.setdefault(what if arm != "macos" else name, {})[arm] = said
            if arm not in arms:
                arms.append(arm)
        else:
            notes.append(f"`{name}`: THE WINDOW IS NOT TO BE SEEN BEFORE THE ACT: not counted")
    arms = [arm for arm in arms if arm != "macos"]

    def told(said):
        if not said["states"]:
            return "NOTHING HAPPENED"
        return " · ".join(f"+{time}: " + (f"{box[0]},{box[1]} {box[2]}×{box[3]}" if box else "gone") for time, box in said["states"]) + (" (by command: the times are from a mark, not a key)" if said["kind"] == "told" else "")

    print("| Act | " + " | ".join(arms) + " |\n|---|" + "---|" * len(arms), file=out)
    for what, by_arm in acts.items():
        if "macos" not in by_arm:
            print(f"| {what} | " + " | ".join(told(by_arm[arm]) if arm in by_arm else "NOT FILMED" for arm in arms) + " |", file=out)
    # An arm in which an act failed must not look the cleaner for it: only what every arm has, and in which something happened in every arm, is summed.
    common = [by_arm for by_arm in acts.values() if "macos" not in by_arm and all(arm in by_arm and by_arm[arm]["states"] for arm in arms)]
    print(f"\nSummed over the {len(common)} acts that every arm has:\n\n| | " + " | ".join(arms) + " |\n|---|" + "---|" * len(arms), file=out)
    rows = (("Display frames with a new size at the place of the start", lambda said: sum(one["sized"] for one in said)),
            ("Display frames with the window outside old ∪ new", lambda said: sum(one["outside"] for one in said)),
            ("Acts that arrive in one piece", lambda said: f"{sum(one['pieces'] == 1 for one in said)} of {len(said)}"),
            ("Pieces in all acts", lambda said: sum(one["pieces"] for one in said)),
            ("The longest act, first to last", lambda said: f"{max((one['took'] for one in said), default=0)} ms"))
    for title, count in rows:
        print(f"| {title} | " + " | ".join(str(count([by_arm[arm] for by_arm in common])) for arm in arms) + " |", file=out)
    print("| Where each act ends | " + " | ".join("; ".join(f"{what.split('-')[0]}: {by_arm[arm]['end'][2]}×{by_arm[arm]['end'][3]}" if by_arm[arm]["end"] else f"{what.split('-')[0]}: gone"
                                                            for what, by_arm in acts.items() if by_arm in common) for arm in arms) + " |", file=out)
    if any("macos" in by_arm for by_arm in acts.values()):
        print("\nmacOS's own tiling of the same window:", file=out)
    for what, by_arm in acts.items():
        if "macos" in by_arm:
            said = by_arm["macos"]
            print(f"- {what}: {said['pieces']} states drawn over {said['took']} ms, ending at {said['end']}", file=out)
    if notes:
        print("\nREAD THIS:\n" + "\n".join(f"- {note}" for note in notes), file=out)
    return 0


def self_test():
    old, new = (260, 120, 574, 380), (12, 43, 574, 653)
    cases = {
        "at once": ([(0, -900, old), (1, 60, new)], (1, 0, 0, 0)),
        "moved, then grown": ([(0, -900, old), (1, 73, (12, 43, 574, 586)), (2, 89, new)], (2, 16, 0, 0)),
        "grown where it stands, for two frames": ([(0, -900, old), (1, 47, (260, 120, 574, 586)), (2, 80, (12, 77, 574, 586)), (3, 114, new)], (3, 67, 2, 2)),
        "the size of the end at the place of the start": ([(0, -900, old), (1, 38, (260, 120, 574, 653)), (2, 55, new)], (2, 17, 1, 1)),
        "a soft pixel is no piece": ([(0, -900, old), (1, 60, new), (2, 77, (12, 43, 574, 654))], (1, 0, 0, 0)),
        "nothing happens": ([(0, -900, old)], (0, 0, 0, 0)),
        "gone for a third of a second, and back": ([(0, -900, old), (1, 50, None), (2, 400, old)], (2, 350, 0, 0)),
        "gone for good": ([(0, -900, old), (1, 50, None)], (1, 0, 0, 0)),
        "two points larger all round for a frame": ([(0, -900, old), (1, 50, (10, 41, 578, 657)), (2, 67, new)], (2, 17, 0, 0)),
        "another size at a corner fifty points off": ([(0, -900, old), (1, 50, (310, 170, 574, 653)), (2, 67, new)], (2, 17, 0, 1)),
        "not to be seen before the act": ([(0, -900, None), (1, 50, new)], None),
    }
    failures = 0
    for name, (sequence, wanted) in cases.items():
        said = act(sequence)
        got = None if said is None else (said["pieces"], said["took"], said["sized"], said["outside"])
        failures += got != wanted
        print(f"{'✔' if got == wanted else '✘'} {name}: {got}")
    right = outside((0, 0, 10, 10), (0, 0, 5, 10), (5, 0, 5, 10)) == 0 and outside((0, 0, 10, 10), (0, 0, 5, 10), (0, 0, 5, 10)) == 50 and outside((20, 20, 4, 4), (0, 0, 5, 5), (5, 5, 5, 5)) == 16
    failures += not right
    print(f"{'✔' if right else '✘'} what lies in neither of two boxes")
    failures += drawn()
    print(f"{len(cases) + 2 - failures} of {len(cases) + 2} as they should be")
    return 1 if failures else 0


def drawn():
    """Two arms, drawn, read through `table`: a Dock with an icon of the page's colour, a menu bar, the red window that stands by. In the second arm the window grows where it stands first, and that
    frame is stamped before the key, as macOS was seen to do."""
    import io
    import tempfile

    from film import write_film

    began, key = 1_760_000_000_000, 1_760_000_001_000
    old, grown, new = (260, 120, 574, 380), (260, 120, 574, 586), (12, 42, 574, 654)

    def picture(box):
        frame = np.zeros((768, 1024, 3), dtype=np.uint8)
        frame[:30] = (230, 230, 230)
        frame[712:760, 300:700] = (70, 70, 74)
        frame[716:756, 320:480] = CAST["safari"]
        frame[560:690, 760:1000] = CAST["test"]
        frame[box[1]:box[1] + box[3], box[0]:box[0] + box[2]] = CAST["safari"]
        return frame

    def shoot(folder, states, later=0):
        lines = [(began + 1, "M kind instant"), (began + 200, "M before 35 260 120 574 380 floating"), (began + 200, "M windows before"), (began + 700, "M action"), (key, "K down"), (key + 40, "K up")]
        write_film(folder, [picture(box) for _, box in states], [time + later for time, _ in states], [(time + later, line) for time, line in lines], visible=[0, 30, 1024, 678])

    with tempfile.TemporaryDirectory() as folder:
        shoot(os.path.join(folder, "films", "clean-safari-1-dock-left"), [(began, old), (key + 50, new)])
        shoot(os.path.join(folder, "films", "dirty-safari-1-dock-left"), [(began, old), (began + 270, grown), (key + 73, new)], later=9000)
        with open(os.path.join(folder, "samples.log"), "w", encoding="utf-8") as log:
            log.write(f"{key + 9040} W 35 7 0 260 120 574 586 Safari\n{key + 9080} W 35 7 0 12 42 574 654 Safari\n")
        said = io.StringIO()
        table(folder, "safari", said)
    wanted = ("| 1-dock-left | +50: 12,42 574×654 | +40: 260,120 574×586 · +73: 12,42 574×654 |", "| Display frames with a new size at the place of the start | 0 | 2 |",
              "| Display frames with the window outside old ∪ new | 0 | 2 |", "| Acts that arrive in one piece | 1 of 1 | 0 of 1 |", "FRAME 1 IS STAMPED 730 ms BEFORE ITS CAUSE; put at +40")
    missing = [line for line in wanted if line not in said.getvalue()]
    print(f"{'✘' if missing else '✔'} two drawn arms through the table" + "".join(f"\n    not said: {line}" for line in missing) + (("\n" + said.getvalue()) if missing else ""))
    return 1 if missing else 0


def main(arguments):
    if not arguments or arguments[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if arguments[0] == "--self-test":
        return self_test()
    return table(arguments[0], arguments[1] if len(arguments) > 1 else "safari")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
