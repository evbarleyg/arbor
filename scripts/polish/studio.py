"""Films that were never shot: drawn here, right and wrong in known ways, so that the judge can be judged.

A net is worth what it catches. Every check of docs/POLISH.md that a script measures has a film here that breaks it and nothing
else, and `judge.py --self-test` fails unless exactly that check says so; the film that breaks nothing must pass them all.
"""

import os

import numpy as np

from film import write_film
from measure import TICK, bezier

WIDTH, HEIGHT = 1024, 768
ROOM = (0, 31, 1024, 705)
RED, BLUE, GREEN, ORANGE = (255, 56, 60), (0, 136, 255), (52, 199, 89), (255, 141, 40)
CARD = (92, 96, 104)
BEGAN = 1_760_000_000_000
# The key goes down this long after the film begins.
LEAD = 420


def desk():
    picture = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
    picture[:31] = 226
    picture[712:762, 40:984] = 48
    for place in range(20):
        picture[718:756, 50 + place * 46:88 + place * 46] = ((place * 53) % 255, (place * 97) % 255, (place * 31) % 255)
    return picture


def paint(picture, rect, colour):
    x, y, w, h = (int(round(value)) for value in rect)
    x0, y0, x1, y1 = max(x, 0), max(y, ROOM[1]), min(x + w, WIDTH), min(y + h, ROOM[3])
    if x1 > x0 and y1 > y0:
        picture[y0:y1, x0:x1] = colour


def window(picture, rect, colour, card=False):
    x, y, w, h = rect
    if card:
        paint(picture, rect, (130, 134, 140))
        paint(picture, (x + 1, y + 1, w - 2, h - 2), CARD)
        side = min(w, h) * 0.3
        paint(picture, (x + w / 2 - side / 2, y + h / 2 - side / 2, side, side), (30, 30, 34))
        return
    bar = 28 * h / max(rect[3], 1)
    paint(picture, rect, colour)
    paint(picture, (x, y, w, bar), (232, 232, 232))
    paint(picture, (x + w / 2 - w * 0.15, y + h / 2 - 8, w * 0.3, 16), (255, 255, 255))


def between(a, b, share):
    return [p + (q - p) * share for p, q in zip(a, b)]


# Two columns of two, and the same with the first window framed: the others leave past the edges, as the plane grows.
GRID = {RED: (12, 43, 494, 319), BLUE: (12, 374, 494, 319), GREEN: (518, 43, 494, 319), ORANGE: (518, 374, 494, 319)}
FRAMED = {RED: (12, 43, 1000, 650), BLUE: (12, 717, 1000, 650), GREEN: (1036, 43, 1000, 650), ORANGE: (1036, 717, 1000, 650)}


def shoot(folder, kind="camera", start=None, end=None, curve=(0.2, 0, 0, 1), seconds=0.46, latency=34, cards=False, hop=0,
          pause=None, blink=False, flash=False, overshoot=0.0, stutter=None, bars=False, lag=None, instant=False,
          afterthought=False, fps=60, fade=0, offset=0, left=None, words=True, halfway=False, one_by_one=False, hole=False, empty=False):
    """Draws one film. Every argument but the first few is one way of getting it wrong."""
    start, end = start or GRID, end or FRAMED
    x, y = bezier(curve)
    frames, times = [], []
    lines = [(BEGAN + 1, "M scene " + folder.rsplit("/", 1)[-1]), (BEGAN + 1, f"M kind {kind}"), (BEGAN + LEAD - 20, "M action"),
             (BEGAN + LEAD - 8, "K modifiers"), (BEGAN + LEAD, "K down"), (BEGAN + LEAD + 40, "K up")]

    def take(time, places, as_cards=False, extra=None, mix=1.0):
        picture = desk()
        for colour, rect in places.items():
            window(picture, rect, colour)
        if as_cards:
            # The cards lie over the windows' pictures, as opaque as `mix` says.
            covered = desk()
            for colour, rect in places.items():
                window(covered, (rect[0] + offset, rect[1], rect[2], rect[3]), colour, card=True)
            picture = (picture * (1 - mix) + covered * mix).round().astype(np.uint8)
        if extra:
            extra(picture)
        if not frames or (picture != frames[-1]).any():
            frames.append(picture)
            times.append(int(round(time)))

    take(BEGAN, start)
    begins = BEGAN + LEAD + latency
    tick = 1000 / fps
    if instant:
        if halfway:
            # Size and place are asked for one after the other, and the display shows what lies between: the new size at the old place.
            take(begins, {colour: (start[colour][0], start[colour][1], rect[2], rect[3]) for colour, rect in end.items()})
            begins += tick
        if hole:
            # All are at their new places but one, which has left its old place and is not there yet.
            take(begins, {colour: rect for place, (colour, rect) in enumerate(end.items()) if place})
            begins += tick
        if empty:
            take(begins, {})
            begins += 4 * tick
        if one_by_one:
            # Each window a frame after the one before, nine frames apart in all.
            for count in range(1, len(end)):
                take(begins, {colour: (end if place < count else start)[colour] for place, colour in enumerate(end)})
                begins += 3 * tick
        take(begins, end)
    else:
        count = int(round(seconds * 1000 / tick))
        for step in range(count + 1):
            now = step * tick
            share = now / (seconds * 1000)
            if pause and share > pause[0]:
                # Stops on the way for a while, then goes on.
                share = max(pause[0], share - pause[1])
            progress = float(np.interp(min(share, 1), x, y))
            if overshoot:
                progress += overshoot * np.sin(np.pi * min(share, 1)) * share**3
            if stutter and stutter[0] <= step < stutter[1]:
                continue
            places = {}
            for colour in start:
                mine = progress
                if lag and colour == lag[0]:
                    mine = float(np.interp(max(share - lag[1], 0), x, y))
                target = end[colour]
                if hop:
                    target = (target[0] - hop, target[1], target[2], target[3])
                places[colour] = between(start[colour], target, mine)
            extra = None
            if flash and 10 <= step < 12:
                extra = lambda picture: paint(picture, (700, 420, 150, 110) if flash is True else flash, (250, 250, 250))
            if bars and 3 <= step < 20:
                extra = lambda picture: picture.__setitem__((slice(712, 762), slice(40, 984)), 20)
            if blink and step == count:
                take(begins + now, {})
                continue
            mix = min(1.0, (step + 1) / fade, (count - step) / fade) if fade else 1.0
            take(begins + now, places, as_cards=cards, extra=extra, mix=mix)
        extra_steps = int((pause[1] * seconds * 1000) / tick) if pause else 0
        for step in range(count + 1, count + 1 + extra_steps):
            share = max(pause[0], step * tick / (seconds * 1000) - pause[1])
            places = {colour: between(start[colour], end[colour], float(np.interp(min(share, 1), x, y))) for colour in start}
            take(begins + step * tick, places, as_cards=cards)
            count = step
        # The stage lifts, and the real windows are what is seen.
        take(begins + (count + 2) * tick, end)
    if afterthought:
        moved = {**end, RED: (end[RED][0] + 60, end[RED][1], end[RED][2] - 60, end[RED][3])}
        take(times[-1] + 400, moved)
    # The heads-up line goes, as it does after every command: no afterthought.
    if words:
        take(times[-1] + 1500, moved if afterthought else end, extra=lambda picture: paint(picture, (410, 612, 200, 36), (60, 60, 64)))
    for number, rect in enumerate((moved if afterthought else end).values()):
        if rect[0] + rect[2] <= ROOM[2] and rect[1] + rect[3] <= ROOM[3]:
            lines.append((times[-1], f"M after {number} {rect[0]} {rect[1]} {rect[2]} {rect[3]} docked"))
    lines.append((times[-1], "M overlay after 0 506 43 12 650"))
    if left is not None:
        lines.append((times[-1], f"M overlay after {left} 12 43 494 650"))
    write_film(folder, frames, times, lines, visible=[0, 31, 1024, 674])


def shoot_drag(folder, pull=0, preview_off=0, drop=(1021, 368), tint=False):
    """A window dragged by its title bar to the right edge, held there over a preview, let go: it glides into the slot."""
    x, y = bezier((0.2, 0, 0, 1))
    slot, begin = (518, 43, 494, 650), (200, 200, 400, 300)
    press = (400, 212)
    frames, times = [], []
    down = BEGAN + LEAD
    lines = [(BEGAN + 1, "M kind drag"), (BEGAN + LEAD - 20, "M action"), (down, f"B down {press[0]} {press[1]}")]

    def take(time, rect, preview=False):
        picture = desk()
        window(picture, GRID[BLUE], BLUE)
        if preview:
            paint(picture, slot, (24, 62, 118))
        # A preview drawn over the window that is held tints it: ugly, and not the hand-over's fault.
        window(picture, rect, (150, 60, 120) if preview and tint else RED)
        if not frames or (picture != frames[-1]).any():
            frames.append(picture)
            times.append(int(round(time)))

    take(BEGAN, begin)
    steps = 48
    for step in range(1, steps + 1):
        pointer = between(press, drop, step / steps)
        lines.append((int(down + step * TICK), f"P {pointer[0]:.0f} {pointer[1]:.0f}"))
        # The window is where the pointer was a frame ago.
        behind = between(press, drop, (step - 1) / steps)
        rect = (begin[0] + behind[0] - press[0], begin[1] + behind[1] - press[1], begin[2], begin[3])
        if pull and 8 <= step < 14:
            rect = (rect[0], rect[1] - pull, rect[2], rect[3])
        take(down + step * TICK, rect)
    held = (begin[0] + drop[0] - press[0], begin[1] + drop[1] - press[1], begin[2], begin[3])
    rested = down + (steps + 1) * TICK
    take(rested, held)
    take(rested + 120, held, preview=True)
    lines.append((int(rested + 500), f"M overlay held 3 {slot[0] + preview_off} {slot[1]} {slot[2]} {slot[3]}"))
    up = int(rested + 800)
    lines.append((up, f"B up {drop[0]} {drop[1]}"))
    for step in range(1, 29):
        take(up + 17 + step * TICK, between(held, slot, float(np.interp(step / 28, x, y))))
    lines.append((times[-1] + 900, "M after 1 518 43 494 650 docked"))
    lines.append((times[-1] + 900, "M overlay after 0 506 43 12 650"))
    take(times[-1] + 1000, slot)
    frames.append(frames[-1].copy())
    paint(frames[-1], (410, 612, 200, 36), (60, 60, 64))
    times.append(times[-1] + 1000)
    write_film(folder, frames, times, lines, visible=[0, 31, 1024, 674])


# Where a menu under one icon at the right of the menu bar would lie, and the light wallpaper of the dark scenes as a hosted Mac's display shows it.
MENU = (713, 24, 306, 682)
LIGHT = (197, 202, 209)


def bare(folder, name, colour):
    """The film of the bare desk that a session begins with: one frame."""
    picture = desk()
    picture[31:705] = colour
    write_film(os.path.join(folder, name), [picture], [BEGAN], [(BEGAN + 1, "M kind bare")], visible=[0, 31, 1024, 674])


def shoot_steps(folder, steps, kind="instant", ground=None, moved=True, menu=None, click=False, extra=(), before=None, after=None, was="docked", how="docked", scale=1, rim=False, paints=None):
    """An act at once, frame by frame. Steps are (ms after the cause, {colour: rectangle}[, how much of the menu or panel shows, 0 to 1[, the ground in this frame]]); the first (None) is how things stand
    before. A colour that is a word is painted flat, without a title bar: "words" is the line of words, the others are looked up in `paints`. `menu`: True for a menu whose frame the script has noted, a
    rectangle for a panel. `click`: the cause is a button. `rim`: the windows' shadows lie on what is left of the wallpaper. `before`, `after`, `was`, `how`: Arbor's own account, where it is not
    what the first and the last frame show."""
    frames, times = [], []
    lines = [(BEGAN + 1, f"M kind {kind}"), (BEGAN + LEAD - 20, "M action")]
    if kind not in ("told", "closes"):
        lines += [(BEGAN + LEAD - 40, "B down 800 580"), (BEGAN + LEAD, "B up 800 580")] if click else [(BEGAN + LEAD, "K down"), (BEGAN + LEAD + 40, "K up")]
    for step in steps:
        at, places = step[:2]
        shows, here = step[2] if len(step) > 2 else 0, step[3] if len(step) > 3 else ground
        picture = desk()
        if here is not None:
            picture[31:705] = here
        if rim:
            shade = np.linspace(0.72, 0.98, 1024)[None, :, None]
            for rows in (slice(31, 43), slice(693, 705)):
                picture[rows] = (picture[rows] * shade).astype(np.uint8)
            shade = np.linspace(0.72, 0.98, 674)[:, None, None]
            for columns in (slice(0, 12), slice(1012, 1024)):
                picture[31:705, columns] = (picture[31:705, columns] * shade).astype(np.uint8)
        for colour, rect in places.items():
            if isinstance(colour, str):
                paint(picture, rect, (60, 60, 64) if colour == "words" else paints[colour])
            else:
                window(picture, rect, colour)
        if shows:
            covered = picture.copy()
            paint(covered, MENU if menu is True else menu, (236, 236, 238))
            picture = (picture * (1 - shows) + covered * shows).round().astype(np.uint8)
        # Something shimmers, so that no frame is the same as the one before.
        picture[700:702, 1000 + 2 * (len(frames) % 8):1002 + 2 * (len(frames) % 8)] = 90
        if scale > 1:
            picture = picture.repeat(scale, axis=0).repeat(scale, axis=1)
        frames.append(picture)
        times.append(BEGAN + (LEAD + at if at is not None else 0))
    for when, time, places, state in (("before", BEGAN + 2, before or steps[0][1], was), ("after", times[-1], after or (steps[-1][1] if moved else steps[0][1]), how if moved else was)):
        for number, (colour, rect) in enumerate(places.items()):
            if not isinstance(colour, str):
                lines.append((time, f"M {when} {number} {rect[0]} {rect[1]} {rect[2]} {rect[3]} {state}"))
        lines.append((time, f"M windows {when}"))
    if menu is True:
        lines += [(BEGAN + LEAD - 300, "M overlay held 101 {} {} {} {}".format(*MENU)), (BEGAN + LEAD - 299, "M overlays held")]
    lines.append((times[-1], "M overlays after"))
    write_film(folder, frames, times, lines + list(extra), visible=[0, 31, 1024, 674], scale=scale)


def shoot_drop(folder, kind="drop", halfway=False, preview=True, nothing=False, late=0):
    """A window dragged over the right half of one that fills the room, held there, let go: at once it has the right half and the other the left."""
    slot, begin, press, drop = (518, 43, 494, 650), (200, 200, 400, 300), (400, 212), (760, 300)
    wide, narrow = (12, 43, 1000, 650), (12, 43, 494, 650)
    frames, times = [], []
    down = BEGAN + LEAD
    lines = [(BEGAN + 1, f"M kind {kind}"), (BEGAN + 2, "M before 1 200 200 400 300 floating"), (BEGAN + 2, "M before 2 12 43 1000 650 docked"), (BEGAN + 2, "M windows before"),
             (BEGAN + LEAD - 20, "M action"), (down, f"B down {press[0]} {press[1]}")]

    def take(time, rect, shown=False, blue=wide):
        picture = desk()
        window(picture, blue, BLUE)
        if shown:
            paint(picture, slot, (24, 62, 118))
        window(picture, rect, RED)
        if not frames or (picture != frames[-1]).any():
            frames.append(picture)
            times.append(int(round(time)))

    take(BEGAN, begin)
    steps = 48
    for step in range(1, steps + 1):
        pointer = between(press, drop, step / steps)
        lines.append((int(down + step * TICK), f"P {pointer[0]:.0f} {pointer[1]:.0f}"))
        behind = between(press, drop, (step - 1) / steps)
        take(down + step * TICK, (begin[0] + behind[0] - press[0], begin[1] + behind[1] - press[1], begin[2], begin[3]))
    held = (begin[0] + drop[0] - press[0], begin[1] + drop[1] - press[1], begin[2], begin[3])
    rested = down + (steps + 1) * TICK
    take(rested, held)
    if preview:
        take(rested + 120, held, shown=True)
        lines.append((int(rested + 500), f"M overlay held 3 {slot[0]} {slot[1]} {slot[2]} {slot[3]}"))
    lines.append((int(rested + 501), "M overlays held"))
    up = int(rested + 800)
    lines.append((up, f"B up {drop[0]} {drop[1]}"))
    at, rest = up + 34, held if nothing else slot
    if nothing:
        # The preview goes, and that is all.
        take(at, held)
    else:
        if halfway:
            take(at, (held[0], held[1], slot[2], slot[3]), blue=narrow)
            at += TICK
        if late:
            take(at, held, blue=narrow)
            at += late
        take(at, slot, blue=narrow)
    lines.append((times[-1] + 900, f"M after 1 {rest[0]} {rest[1]} {rest[2]} {rest[3]} {'floating' if nothing else 'docked'}"))
    lines.append((times[-1] + 900, f"M after 2 12 43 {1000 if nothing else 494} 650 docked"))
    lines.append((times[-1] + 900, "M windows after"))
    lines.append((times[-1] + 900, "M overlays after"))
    frames.append(frames[-1].copy())
    paint(frames[-1], (410, 612, 200, 36), (60, 60, 64))
    times.append(times[-1] + 1500)
    write_film(folder, frames, times, lines, visible=[0, 31, 1024, 674])


def shoot_plain(folder, preview=False, docks=False, nudged=0, level=3, other=0, grown=0, no_drag=False):
    """A floating window dragged over a docked one, held there, let go. Nothing was asked of Arbor: nothing shows, and the window stays where it was let go."""
    slot, begin, press, drop = (518, 43, 494, 650), (560, 300, 300, 200), (700, 312), (300, 212)
    frames, times = [], []
    down = BEGAN + LEAD
    lines = [(BEGAN + 1, "M kind plain"), (BEGAN + 2, "M before 1 560 300 300 200 floating"), (BEGAN + 2, "M before 2 12 374 494 319 docked"),
             (BEGAN + LEAD - 20, "M action"), (down, f"B down {press[0]} {press[1]}")]

    def take(time, rect, shown=False):
        picture = desk()
        window(picture, GRID[BLUE], BLUE)
        if shown:
            paint(picture, slot, (24, 62, 118))
        window(picture, rect, RED)
        if not frames or (picture != frames[-1]).any():
            frames.append(picture)
            times.append(int(round(time)))

    take(BEGAN, begin)
    steps = 48
    for step in range(1, steps + 1):
        pointer = between(press, drop, step / steps)
        lines.append((int(down + step * TICK), f"P {pointer[0]:.0f} {pointer[1]:.0f}"))
        behind = between(press, drop, (step - 1) / steps)
        take(down + step * TICK, (begin[0] + behind[0] - press[0], begin[1] + behind[1] - press[1], begin[2], begin[3]))
    held = (begin[0] + drop[0] - press[0], begin[1] + drop[1] - press[1], begin[2], begin[3])
    rested = down + (steps + 1) * TICK
    take(rested, held)
    if preview:
        take(rested + 120, held, shown=True)
        lines.append((int(rested + 500), f"M overlay held {level} {slot[0]} {slot[1]} {slot[2]} {slot[3]}"))
    lines.append((int(rested + 501), "M overlays held"))
    up = int(rested + 800)
    lines.append((up, f"B up {drop[0]} {drop[1]}"))
    if no_drag:
        lines[:] = [line for line in lines if not line[1].startswith(("B ", "P "))]
    rest = slot if docks else (held[0] + nudged, held[1], held[2] + grown, held[3])
    take(up + 34, rest)
    lines.append((up + 1500, f"M after 1 {rest[0]} {rest[1]} {rest[2]} {rest[3]} {'docked' if docks else 'floating'}"))
    lines.append((up + 1500, f"M after 2 {12 + other} 374 494 319 docked"))
    lines.append((up + 1500, "M overlays after"))
    frames.append(frames[-1].copy())
    paint(frames[-1], (1000, 690, 4, 4), (60, 60, 64))
    times.append(up + 1600)
    write_film(folder, frames, times, lines, visible=[0, 31, 1024, 674])


def shoot_panel(folder, late=34, fade=5, slide=0, click=False):
    """A panel that a key brings and the same key sends away."""
    frames, times = [], []
    first, second = BEGAN + LEAD, BEGAN + LEAD + 1500
    opens = [(first, "B down 770 15"), (first + 40, "B up 770 15")] if click else [(first, "K down"), (first + 40, "K up")]
    lines = [(BEGAN + 1, "M kind panel"), (BEGAN + LEAD - 20, "M action"), *opens, (second, "K down"), (second + 40, "K up")]

    def take(time, mix, shift=0):
        picture = desk()
        for colour, rect in GRID.items():
            window(picture, rect, colour)
        covered = picture.copy()
        paint(covered, (312, 200 + shift, 400, 300), (236, 236, 238))
        picture = (picture * (1 - mix) + covered * mix).round().astype(np.uint8)
        if not frames or (picture != frames[-1]).any():
            frames.append(picture)
            times.append(int(round(time)))

    take(BEGAN, 0)
    for step in range(1, fade + 1):
        take(first + late + step * TICK, step / fade, shift=slide * (fade - step) // fade)
    for step in range(1, fade + 1):
        take(second + late + step * TICK, 1 - step / fade)
    lines.append((times[-1] + 900, "M after 1 12 43 494 319 docked"))
    write_film(folder, frames, times, lines, visible=[0, 31, 1024, 674])


def shoot_follow(folder, lag=1, step=0):
    """Two fingers spread over the first window for a second and a half, unevenly, as fingers do; it grows with them; they let go, and the
    view settles on it."""
    import os
    x, y = bezier((0.2, 0, 0, 1))
    frames, times, fingers = [], [], []
    down = BEGAN + LEAD
    lines = [(BEGAN + 1, "M kind follow"), (BEGAN + LEAD - 20, "M action"), (down, "M fingers down")]

    def take(time, share):
        picture = desk()
        for colour in GRID:
            window(picture, between(GRID[colour], FRAMED[colour], share), colour)
        if not frames or (picture != frames[-1]).any():
            frames.append(picture)
            times.append(int(round(time)))

    def spread(count):
        # Fast, slow, a rest, fast again: up to 0.6 of the way.
        return 0.6 * float(np.interp(count, [0, 25, 50, 60, 90], [0, 0.45, 0.6, 0.6, 1]))

    take(BEGAN, 0)
    for count in range(1, 91):
        fingers.append((int(down + count * TICK), spread(count)))
        share = spread(max(count - lag, 0))
        if step and 40 <= count < 44:
            share += step / 506
        take(down + count * TICK, share)
    for count in range(91, 91 + lag + 1):
        take(down + count * TICK, spread(min(count - lag, 90)))
    up = int(down + (92 + lag) * TICK)
    lines.append((up, "M fingers up"))
    for count in range(1, 29):
        take(up + 17 + count * TICK, 0.6 + 0.4 * float(np.interp(count / 28, x, y)))
    lines.append((times[-1] + 900, "M after 1 12 43 1000 650 docked"))
    lines.append((times[-1] + 900, "M overlay after 0 506 43 12 650"))
    write_film(folder, frames, times, lines, visible=[0, 31, 1024, 674])
    with open(os.path.join(folder, "fingers.log"), "w", encoding="utf-8") as file:
        for time, total in fingers:
            file.write(f"{time} G {total:.4f} 0 0\n")
