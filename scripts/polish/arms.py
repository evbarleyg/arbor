#!/usr/bin/env python3
"""Lays the arms of scripts/mac-shell/films-arms.sh side by side: the same acts on one Mac by Arbor as built from several commits.

  arms.py <run folder> test|safari      the table, act by act and arm by arm, then the count: of the acts on the test window, or of those on Safari
  arms.py <run folder> crowd|apps       the same for the acts on many windows, round by round: bare ground where a window stands before and after, an empty desk, first change to last
  arms.py --self-test

A real app's window is no flat rectangle with a plain title bar, so the judge's ruler does not follow it. But the films show one window of one colour (the test window's own; Safari on a page of
one colour, which macOS carries up into the toolbar): so the box of everything near that colour, in every frame, is the window, less its title bar if that is plain, as the display drew it. From those boxes, for every act: in how many pieces it arrived
and how long that took; the display's frames in which the window had a new size at the place of the start; those in which it covered what neither its old frame nor its new one covers.

How things stood before an act is not taken from the film alone. Arbor's own account, noted when the scene begins, says where the window is; a frame that is stamped after that account and before the
key, and shows the window otherwise, has a wrong time (macOS was seen to hand the camera a stale one for the first frame after a long rest). It belongs to the act: it is put where the window
server's list (samples.log) first has that size after the key, and the table says so aloud.

Many windows are not followed at all. What is asked of them needs no following: on a plain wallpaper, whose colour the run's film of the bare desk gives, every pixel of every frame either shows
the ground or does not. A hole is ground that shows, over a hundredth of the room, where there is something both before the act and after it; the desk is empty where under a hundredth of the room
shows anything. That holds for real apps as for test windows.

Needs numpy and Pillow (and no Mac).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

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


def many(film, ground, by=24):
    """One act on many windows: {"holes": display frames in which ground shows, over 1% of the room, where there is something both before the act and after it, "worst": the largest such share of the
    room, "empty": display frames with under 1% of the room taken, on a desk that had and has more than 5%, "first", "last": ms after the cause of the first and the last frame in which over 1% of the room
    changes, "pieces": how many such frames, "wait": the longest wait from the cause to the last of them, "before", "after": the share of the room that is taken before and after, "early": the frames
    in which over 1% of the room changes after Arbor's account of the windows was noted and before the cause: there should be none}. None if nothing changes."""
    cause = cause_of(film)[0]
    x, y, w, h = (int(value * film.scale) for value in film.visible)
    room = w * h

    def taken(picture):
        return (np.abs(picture[y:y + h, x:x + w].astype(np.int16) - np.array(ground, dtype=np.int16)) > by).any(axis=2)

    before = after = None
    for _, time, picture, _ in film.frames():
        if time < cause:
            before = taken(picture)
        after = picture
    if before is None:
        return None
    after = taken(after)
    times = [int(time) - cause for time in film.times]
    found = {"holes": 0, "worst": 0.0, "empty": 0, "first": None, "last": None, "pieces": 0, "wait": 0, "before": float(before.sum()) / room, "after": float(after.sum()) / room, "early": []}
    noted = [int(time) - cause for time, mark in film.marks if mark.startswith(("before ", "windows before", "action"))]
    previous, shown = None, []
    for index, time, picture, _ in film.frames():
        inside = picture[y:y + h, x:x + w]
        if time >= cause and previous is not None:
            lasts = max(int(round((times[index + 1] - times[index]) / TICK)), 1) if index + 1 < len(times) else 1
            now = taken(picture)
            share = float((before & after & ~now).sum()) / room
            # The last frame is the end itself; and a state that stays for good is no state on the way.
            if index + 1 < len(times):
                found["worst"] = max(found["worst"], share)
                if share > 0.01:
                    found["holes"] += lasts
                if now.sum() < room / 100 and min(before.sum(), after.sum()) > room / 20:
                    found["empty"] += lasts
            if (np.abs(inside.astype(np.int16) - previous.astype(np.int16)) > by).any(axis=2).sum() > room / 100:
                shown.append(times[index])
        elif previous is not None and noted and times[index] >= min(noted) and (np.abs(inside.astype(np.int16) - previous.astype(np.int16)) > by).any(axis=2).sum() > room / 100:
            found["early"].append(index)
        previous = inside.copy()
    if not shown:
        return None
    found.update(first=shown[0], last=shown[-1], pieces=len(shown), wait=max(b - a for a, b in zip([0] + shown, shown)))
    return found


def waits(folder, since, until):
    """What Arbor's own logs say of waiting between two moments (ms since 1970): the lines with "waited"."""
    import datetime
    import glob
    said = []
    for path in sorted(glob.glob(os.path.join(folder, "arbor-*.log"))):
        with open(path, encoding="utf-8", errors="replace") as log:
            for line in log:
                if " waited " in line and line[:4].isdigit():
                    try:
                        at = datetime.datetime.fromisoformat(line.split()[0].replace("Z", "+00:00")).timestamp() * 1000
                    except ValueError:
                        continue
                    if since <= at <= until:
                        said.append(line.split(None, 2)[2].strip())
    return said


def crowd(folder, cast, out=sys.stdout):
    films = os.path.join(folder, "films")
    # Each cast may have a wallpaper of its own, and then a film of the bare desk of its own.
    bare = next((os.path.join(films, name, "0000.png") for name in (f"{cast}-ground", "ground") if os.path.isfile(os.path.join(films, name, "0000.png"))), None)
    if bare is None:
        print(f"arms.py: the run has no film of the bare desk (`{cast}-ground` or `ground`)", file=sys.stderr)
        return 2
    with Image.open(bare) as image:
        desk = np.asarray(image.convert("RGB"))
    ground = tuple(int(value) for value in np.median(desk[desk.shape[0] // 4:desk.shape[0] // 2, desk.shape[1] // 4:3 * desk.shape[1] // 4].reshape(-1, 3), axis=0))
    acts, arms, notes = {}, [], []

    def began(name):
        with open(os.path.join(films, name, "film.log"), encoding="utf-8") as log:
            return int(log.readline().split()[0])

    for name in sorted((name for name in os.listdir(films) if f"-{cast}-" in name and os.path.isfile(os.path.join(films, name, "film.log"))), key=began):
        arm, _, rest = name.partition(f"-{cast}-")
        round_, _, what = rest.partition("-")
        film = Film(os.path.join(films, name))
        said = many(film, ground)
        if arm not in arms:
            arms.append(arm)
        acts.setdefault(what, {}).setdefault(arm, {})[int(round_)] = said
        if said is None:
            notes.append(f"`{name}`: NOTHING CHANGED")
        elif said["early"]:
            notes.append(f"`{name}`: NOT TO BE BELIEVED: over 1% of the room changes in frame {said['early'][0]}, before the cause: the frame's time is wrong, or the scene was not at rest")
        if film.kind == "told":
            notes.append(f"`{name}`: by command, no key does it in this arm's map: its times are counted from a mark and are not to be held against an arm that has a key")
        cause = cause_of(film)[0]
        for line in waits(folder, cause - 50, cause + 1500):
            notes.append(f"`{name}`: holes in {said['holes'] if said else '?'} frames; Arbor's log: {line}")
    rounds = sorted({number for by_arm in acts.values() for played in by_arm.values() for number in played})

    def row(played, key, unit=""):
        values = [("·" if played.get(number) is None else str(played[number][key])) for number in rounds]
        return f"{values[0]}{unit} ‖ " + " ".join(values[1:])

    print(f"The ground: {ground}. Each cell: the first round of the session ‖ the later ones.", file=out)
    if cast == "apps":
        print("Real apps draw themselves again after they have arrived, and whatever changes over 1% of the room counts as a change: \"the last of them\" is no window's arriving here, and the mark of 100 ms is held on the test windows alone.", file=out)
    print(file=out)
    for by_arm in acts.values():
        for played in by_arm.values():
            for said in played.values():
                if said:
                    said["percent"], said["taken"] = f"{100 * said['worst']:.1f}", f"{100 * said['before']:.0f}→{100 * said['after']:.0f}"
    for key, title, unit in (("holes", "Display frames with a hole", ""), ("percent", "The largest hole, % of the room, however small", ""), ("empty", "Display frames with the desk empty", ""),
                             ("taken", "Of the room, % taken before → after: a window that passes for the ground would show here", ""), ("pieces", "Frames in which over 1% of the room changes", ""),
                             ("last", "The last of them, ms after the cause", ""), ("wait", "The longest wait up to it, ms", "")):
        print(f"**{title}**\n\n| Act | " + " | ".join(arms) + " |\n|---|" + "---|" * len(arms), file=out)
        for what, by_arm in acts.items():
            print(f"| {what} | " + " | ".join(row(by_arm.get(arm, {}), key, unit) for arm in arms) + " |", file=out)
        print(file=out)
    print("**Summed over all rounds**\n\n| | " + " | ".join(arms) + " |\n|---|" + "---|" * len(arms), file=out)
    for what, by_arm in acts.items():
        whole = {arm: [said for said in by_arm.get(arm, {}).values() if said] for arm in arms}
        print(f"| {what}: frames with a hole; the largest hole, of the room | " + " | ".join(f"{sum(said['holes'] for said in whole[arm])}; {100 * max((said['worst'] for said in whole[arm]), default=0):.0f}%" for arm in arms) + " |", file=out)
        print(f"| {what}: first change to last, the longest | " + " | ".join(f"{max((said['last'] - said['first'] for said in whole[arm]), default=0)} ms" for arm in arms) + " |", file=out)
        print(f"| {what}: rounds played | " + " | ".join(str(len(whole[arm])) for arm in arms) + " |", file=out)
    if notes:
        print("\nREAD THIS:\n" + "\n".join(f"- {note}" for note in notes), file=out)
    return 0


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
    failures += drawn_many()
    print(f"{len(cases) + 4 - failures} of {len(cases) + 4} as they should be")
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


def drawn_many():
    """Two arms, two rounds, drawn, read through `crowd`: four windows of which one fills the room. In the second arm the others have gone two frames before the one has grown, in its second round
    the desk is empty for three; and Arbor's log says that it waited."""
    import datetime
    import io
    import tempfile

    from film import write_film

    began, key = 1_760_000_000_000, 1_760_000_001_000
    grid = {(255, 56, 60): (12, 42, 494, 321), (0, 136, 255): (12, 375, 494, 321), (52, 199, 89): (518, 42, 494, 321), (255, 141, 40): (518, 375, 494, 321)}
    red = (255, 56, 60)

    def picture(places, ground=(0, 0, 0)):
        frame = np.zeros((768, 1024, 3), dtype=np.uint8)
        frame[30:708] = ground
        frame[:30] = (230, 230, 230)
        frame[712:760, 300:700] = (70, 70, 74)
        for colour, (x, y, w, h) in places.items():
            frame[y:y + h, x:x + w] = colour
        return frame

    def shoot(folder, states, later, ground=(0, 0, 0), kind="instant"):
        lines = [(began + 1, f"M kind {kind}"), (began + 700, "M action")] + ([(key, "K down"), (key + 40, "K up")] if kind == "instant" else [])
        write_film(folder, [picture(places, ground) for _, places in states], [time + later for time, _ in states], [(time + later, line) for time, line in lines], visible=[0, 30, 1024, 678])

    full = {red: (12, 42, 1000, 654)}
    with tempfile.TemporaryDirectory() as folder:
        films = os.path.join(folder, "films")
        shoot(os.path.join(films, "ground"), [(began, {})], 0)
        for later, name, states in ((10_000, "clean-crowd-1-fill", [(began, grid), (key + 50, full), (key + 1500, full)]), (20_000, "clean-crowd-2-fill", [(began, grid), (key + 50, full), (key + 1500, full)]),
                                    (30_000, "dirty-crowd-1-fill", [(began, grid), (key + 50, {red: grid[red]}), (key + 83, full), (key + 1500, full)]),
                                    (40_000, "dirty-crowd-2-fill", [(began, grid), (key + 50, {}), (key + 100, full), (key + 1500, full)])):
            # The last frame differs by a dot, so that it is a frame.
            states[-1] = (states[-1][0], {**states[-1][1], (90, 90, 90): (1000, 690, 2, 2)})
            shoot(os.path.join(films, name), states, later)
        stamp = datetime.datetime.fromtimestamp((key + 30_060) / 1000, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"
        with open(os.path.join(folder, "arbor-films-arms.log"), "w", encoding="utf-8") as log:
            log.write(f"{stamp} INFO  waited 12 ms, 3 looks, for 1 windows to be listed as they answered\n")
            # And one that belongs to no film: five seconds after the last.
            late = datetime.datetime.fromtimestamp((key + 46_000) / 1000, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"
            log.write(f"{late} INFO  waited 50 ms, 9 looks, for 2 windows to be listed as they answered; not yet: w3\n")
        # Another cast, on a wallpaper of its own, with a film of its own of the bare desk.
        shoot(os.path.join(films, "apps-ground"), [(began, {})], 50_000, (240, 20, 190))
        shoot(os.path.join(films, "dirty-apps-1-fill"), [(began, grid), (key + 50, {red: grid[red]}), (key + 83, full), (key + 1500, {**full, (90, 90, 90): (1000, 690, 2, 2)})], 60_000, (240, 20, 190), "told")
        said, other = io.StringIO(), io.StringIO()
        crowd(folder, "crowd", said)
        crowd(folder, "apps", other)
    wanted = ("| fill | 0 ‖ 0 | 2 ‖ 3 |", "| fill: frames with a hole; the largest hole, of the room | 0; 0% | 5; ", "| fill: first change to last, the longest | 0 ms | 50 ms |",
              "`dirty-crowd-1-fill`: holes in 2 frames; Arbor's log: waited 12 ms, 3 looks, for 1 windows to be listed as they answered")
    text = said.getvalue()
    empty = text[text.index("desk empty"):].split("\n")[4]
    missing = [line for line in wanted if line not in text] + ([] if empty == "| fill | 0 ‖ 0 | 0 ‖ 3 |" else [f"the desk empty: {empty}"])
    if "The ground: (240, 20, 190)" not in other.getvalue() or "| fill | 2 ‖  |" not in other.getvalue() or "held on the test windows alone" not in other.getvalue() \
            or "`dirty-apps-1-fill`: by command" not in other.getvalue() or "by command" in said.getvalue():
        missing.append("the cast with a ground of its own: " + other.getvalue()[:400])
    # The line of the log belongs to one film, not to its neighbours ten seconds off.
    if text.count("Arbor's log:") != 1:
        missing.append(f"the log's line beside one film: it stands beside {text.count(chr(39) + 's log:')}")
    print(f"{'✘' if missing else '✔'} two drawn arms with many windows through the table" + "".join(f"\n    not said: {line}" for line in missing) + (("\n" + text) if missing else ""))

    # One act at a time, on a ground that is not black: what must be counted and what must not.
    pink = (240, 20, 190)
    blue, green = (0, 136, 255), (52, 199, 89)
    small = {**grid, red: (12, 42, 300, 190)}
    # The room is 1024 by 678: a hundredth of it is 6,943 pixels.
    cases = {
        "at once": ([(began, grid), (key + 50, full)], {"holes": 0, "empty": 0, "pieces": 1, "first": 50, "last": 50, "wait": 50, "early": []}),
        "ground left bare for good is no hole": ([(began, grid), (key + 50, small), (key + 67, {**small, blue: (12, 375, 300, 190)})], {"holes": 0, "pieces": 2, "wait": 50}),
        "ground that is covered only afterwards is no hole": ([(began, {red: grid[red]}), (key + 50, {red: grid[red], blue: grid[blue]}), (key + 100, grid)], {"holes": 0, "pieces": 2, "last": 100}),
        "a hole of under a hundredth is printed and not counted": ([(began, grid), (key + 50, {**grid, pink: (100, 100, 100, 60)}), (key + 350, {**grid, green: (518, 42, 494, 300)})], {"holes": 0, "percent": 0.9}),
        "a hole of three hundredths for a frame": ([(began, grid), (key + 50, {**grid, pink: (100, 100, 200, 104)}), (key + 67, {**grid, green: (518, 42, 494, 300)})], {"holes": 1, "percent": 3.0}),
        "a change of half a hundredth is no piece": ([(began, grid), (key + 50, full), (key + 400, {**full, (60, 60, 64): (400, 600, 90, 38)})], {"pieces": 1, "last": 50}),
        "a long wait between two pieces": ([(began, grid), (key + 40, {red: grid[red], blue: grid[blue]}), (key + 340, full)], {"wait": 300, "holes": 18, "pieces": 2}),
        "a frame that changes before its cause": ([(began, grid), (key - 150, {red: grid[red]}), (key + 50, full)], {"early": [1]}),
        "nothing but a few dots on the desk is an empty desk": ([(began, grid), (key + 50, {blue: (500, 300, 60, 60)}), (key + 100, grid.copy() | {green: (518, 42, 494, 300)})], {"empty": 3}),
        "a twentieth of the room taken is no empty desk": ([(began, grid), (key + 50, {blue: (400, 300, 200, 175)}), (key + 100, grid.copy() | {green: (518, 42, 494, 300)})], {"empty": 0}),
        "a window sixty levels from the ground is a window": ([(began, {**grid, (180, 20, 190): grid[red]}), (key + 50, {colour: rect for colour, rect in grid.items() if colour != red}), (key + 67, {**grid, (180, 20, 190): grid[red], green: (518, 42, 494, 300)})],
                                                              {"holes": 1}),
        "ground five levels off is ground": ([(began, grid), (key + 50, {**grid, (235, 25, 185): grid[red]}), (key + 67, {**grid, green: (518, 42, 494, 300)})], {"holes": 1}),
        "how things stood is the last frame before the cause, not the first": ([(began, {}), (began + 100, grid), (key + 50, {red: grid[red]}), (key + 83, full)], {"holes": 2, "early": []}),
        "a desk that was all but empty before is not emptied": ([(began, {blue: (500, 300, 100, 100)}), (key + 50, {}), (key + 100, grid)], {"empty": 0}),
    }
    wrong = []
    with tempfile.TemporaryDirectory() as folder:
        for name, (states, wanted) in cases.items():
            states = states + [(key + 1500, {**states[-1][1], (90, 90, 90): (1000, 690, 2, 2)})]
            lines = [(began + 1, "M kind instant"), (began + 200, "M windows before"), (began + 700, "M action"), (key, "K down"), (key + 40, "K up")]
            frames = []
            for _, places in states:
                frame = picture({})
                frame[30:708] = pink
                for colour, (x, y, w, h) in places.items():
                    frame[y:y + h, x:x + w] = colour
                frames.append(frame)
            write_film(os.path.join(folder, "film"), frames, [time for time, _ in states], lines, visible=[0, 30, 1024, 678])
            got = many(Film(os.path.join(folder, "film")), pink)
            got["percent"] = round(100 * got["worst"], 1)
            off = {what: got[what] for what, value in wanted.items() if got[what] != value}
            if off:
                wrong.append(f"{name}: {off}, wanted {wanted}")
            for file in os.listdir(os.path.join(folder, "film")):
                os.remove(os.path.join(folder, "film", file))
    print(f"{'✘' if wrong else '✔'} {len(cases)} acts on many windows, one at a time, on a ground that is not black" + "".join(f"\n    {line}" for line in wrong))
    return (1 if missing else 0) + (1 if wrong else 0)


def main(arguments):
    if not arguments or arguments[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if arguments[0] == "--self-test":
        return self_test()
    cast = arguments[1] if len(arguments) > 1 else "safari"
    return crowd(arguments[0], cast) if cast in ("crowd", "apps") else table(arguments[0], cast)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
