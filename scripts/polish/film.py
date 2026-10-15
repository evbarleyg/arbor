"""Reads the films of scripts/mac-shell/camera.swift, and finds the windows in them.

A film is a folder: 0000.png is the whole display, every later NNNN.png holds only the pixels that differ from the film so far,
and film.log says when each frame was shown, where its picture goes, and what the person did meanwhile (camera.swift's header has the grammar).

Needs numpy and Pillow, which is why none of this is part of `make check`.
"""

import os

import numpy as np
from PIL import Image

# Two colours further apart than this, in any of red, green and blue, are two colours to an eye.
PLAIN = 40
# A flat colour is this flat.
FLAT = 10
# Thin things (a focus ring, an outline, letters) are rubbed away before anything is boxed, by this many pixels.
RUB = 2


class Film:
    def __init__(self, folder):
        self.folder = folder
        self.name = os.path.basename(os.path.normpath(folder))
        self.times = []
        self.places = []
        self.marks = []
        self.keys = []
        self.buttons = []
        self.pointer = []
        self.display = self.visible = None
        self.size = None
        self.scale = 1
        self.dropped = 0
        self.ends = 0
        self.kind = ""
        self.text = ""
        self.before = {}
        self.after = {}
        self.how = {}
        self.overlays = []
        # What the fingers had said so far, event by event, where the script wrote it down: (time, magnification, pan x, pan y).
        self.fingers = []
        if os.path.isfile(os.path.join(folder, "fingers.log")):
            with open(os.path.join(folder, "fingers.log"), encoding="utf-8") as log:
                self.fingers = [(int(words[0]), *(float(word) for word in words[2:5])) for words in map(str.split, log) if len(words) >= 5 and words[1] == "G"]
        numbered = []
        with open(os.path.join(folder, "film.log"), encoding="utf-8") as log:
            for line in log:
                words = line.split()
                if len(words) < 2:
                    continue
                time, kind, rest = int(words[0]), words[1], words[2:]
                self.ends = max(self.ends, time)
                if kind == "F":
                    numbered.append((int(rest[0]), time, tuple(int(word) for word in rest[1:3]) if len(rest) >= 3 else (0, 0),
                                     tuple(int(word) for word in rest[3:5]) if len(rest) >= 5 else (0, 0)))
                elif kind == "D":
                    self.display = [int(word) for word in rest]
                elif kind == "V":
                    self.visible = [int(word) for word in rest]
                elif kind == "R":
                    self.size = (int(rest[0]), int(rest[1]))
                    self.scale = int(rest[2])
                elif kind == "K":
                    self.keys.append((time, rest[0]))
                elif kind == "B":
                    self.buttons.append((time, rest[0], int(rest[1]), int(rest[2])))
                elif kind == "P":
                    self.pointer.append((time, int(rest[0]), int(rest[1])))
                elif kind == "L":
                    self.dropped = int(rest[0])
                elif kind == "M":
                    self.mark(time, rest)
        # By their numbers, which is how the pictures are named: the lines are in the order of their times, and the first frame's is the
        # moment the film began, which a frame that was under way then may undercut.
        numbered.sort()
        self.places = [place for _, _, place, _ in numbered]
        # How much of the display each frame changed: width and height.
        self.extents = [extent for _, _, _, extent in numbered]
        self.times = np.maximum.accumulate(np.array([time for _, time, _, _ in numbered], dtype=np.int64)) if numbered else np.array([], dtype=np.int64)
        # The Dock grows and shrinks with the apps that run. The panel Arbor hangs behind everything fills the room as it is now.
        behind = [frame for _, level, frame in self.overlays if level < -1000]
        if behind:
            self.visible = [int(value) for value in behind[-1]]

    def mark(self, time, words):
        self.marks.append((time, " ".join(words)))
        if words[0] == "kind":
            self.kind = words[1]
        elif words[0] == "text":
            self.text = " ".join(words[1:])
        elif words[0] == "before" and len(words) in (6, 7):
            self.before[int(words[1])] = [float(word) for word in words[2:6]]
        elif words[0] == "after" and len(words) in (6, 7):
            self.after[int(words[1])] = [float(word) for word in words[2:6]]
            if len(words) == 7:
                self.how[int(words[1])] = words[6]
        elif words[0] == "overlay" and len(words) == 7:
            self.overlays.append((words[1], int(words[2]), [float(word) for word in words[3:7]]))

    def time_of(self, text):
        """When the first mark that begins with these words was made."""
        for time, mark in self.marks:
            if mark.startswith(text):
                return time
        return None

    def __len__(self):
        return len(self.times)

    def frames(self):
        """Every frame as (index, time, picture, changed): height × width × 3 bytes, and which pixels differ from the frame before."""
        picture = None
        for index, time in enumerate(self.times):
            with Image.open(os.path.join(self.folder, f"{index:04d}.png")) as image:
                data = np.asarray(image.convert("RGBA"))
            if picture is None:
                picture = data[:, :, :3].copy()
                changed = np.zeros(picture.shape[:2], dtype=bool)
            else:
                x, y = self.places[index]
                changed = np.zeros(picture.shape[:2], dtype=bool)
                changed[y:y + data.shape[0], x:x + data.shape[1]] = data[:, :, 3] > 0
                picture = picture.copy()
                picture[changed] = data[:, :, :3][data[:, :, 3] > 0]
            yield index, int(time), picture, changed

    def frame(self, wanted):
        for index, _, picture, _ in self.frames():
            if index == wanted:
                return picture
        raise IndexError(wanted)

    def room(self):
        """x0 y0 x1 y1 in pixels: the display between the menu bar and the Dock, where windows live."""
        x, y, w, h = (value * self.scale for value in self.visible)
        return int(x), int(y), int(x + w), int(y + h)


def write_film(folder, frames, times, lines=(), visible=None, scale=1):
    """The opposite of Film, for the self-test: `frames` are height × width × 3 arrays."""
    os.makedirs(folder, exist_ok=True)
    height, width = frames[0].shape[:2]
    visible = visible or [0, 31, width // scale, height // scale - 94]
    log = [(times[0], f"D 0 0 {width // scale} {height // scale}"), (times[0], "V " + " ".join(map(str, visible))),
           (times[0], f"R {width} {height} {scale}")]
    previous = None
    for index, (frame, time) in enumerate(zip(frames, times)):
        alpha = np.full((height, width, 1), 255, dtype=np.uint8)
        if previous is not None:
            alpha[(frame == previous).all(axis=2)] = 0
        data = np.concatenate([frame, alpha], axis=2)
        data[alpha[:, :, 0] == 0] = 0
        rows, columns = np.flatnonzero(alpha[:, :, 0].any(axis=1)), np.flatnonzero(alpha[:, :, 0].any(axis=0))
        x, y = int(columns[0]), int(rows[0])
        data = data[y:rows[-1] + 1, x:columns[-1] + 1]
        Image.fromarray(data, "RGBA").save(os.path.join(folder, f"{index:04d}.png"))
        log.append((time, f"F {index} {x} {y} {data.shape[1]} {data.shape[0]}"))
        previous = frame
    log += list(lines)
    log.sort(key=lambda line: line[0])
    with open(os.path.join(folder, "film.log"), "w", encoding="utf-8") as file:
        for time, text in log:
            file.write(f"{time} {text}\n")
        file.write(f"{times[-1]} S frames={len(frames)} seconds={(times[-1] - times[0]) / 1000:.2f}\n")


# MARK: Finding windows


def near(picture, colour, by):
    """Which pixels are within `by` of that colour in red, green and blue."""
    result = None
    for channel in range(3):
        values = picture[:, :, channel]
        part = (values >= max(colour[channel] - by, 0)) & (values <= min(colour[channel] + by, 255))
        result = part if result is None else result & part
    return result


def flat_colours(picture, share, known=None):
    """The colours that each fill at least that share of the picture, as (r, g, b), the commonest first. `known` remembers, from
    one frame to the next, what has been worked out."""
    known = {} if known is None else known
    small = (picture >> 3).astype(np.int32)
    codes = (small[:, :, 0] << 10) | (small[:, :, 1] << 5) | small[:, :, 2]
    counts = np.bincount(codes.ravel(), minlength=1 << 15)
    found = []
    for code in np.flatnonzero(counts >= share * codes.size):
        if code not in known:
            known[code] = tuple(int(value) for value in np.median(picture[codes == code], axis=0))
        found.append((counts[code], known[code]))
    return [colour for _, colour in sorted(found, reverse=True)]


def rub(mask, by=RUB):
    """What is left of the mask when `by` pixels are taken off every edge."""
    result = mask.copy()
    for step in range(1, by + 1):
        result[step:, :] &= mask[:-step, :]
        result[:-step, :] &= mask[step:, :]
        result[:, step:] &= mask[:, :-step]
        result[:, :-step] &= mask[:, step:]
    return result


def runs(line, gap):
    """The stretches of a row of booleans that are true, allowing holes narrower than `gap`."""
    places = np.flatnonzero(line)
    if places.size == 0:
        return []
    breaks = np.flatnonzero(np.diff(places) > gap)
    starts = np.concatenate([[places[0]], places[breaks + 1]])
    ends = np.concatenate([places[breaks], [places[-1]]])
    return list(zip(starts.tolist(), (ends + 1).tolist()))


def boxes(mask, x=0, y=0, gap=3, least=(30, 20)):
    """Cuts the mask along its empty columns and rows, again and again: Arbor's arrangements are made of such cuts."""
    columns = runs(mask.any(axis=0), gap)
    if not columns:
        return []
    if len(columns) > 1:
        return [box for a, b in columns for box in boxes(mask[:, a:b], x + a, y, gap, least)]
    a, b = columns[0]
    rows = runs(mask[:, a:b].any(axis=1), gap)
    if len(rows) > 1:
        return [box for c, d in rows for box in boxes(mask[c:d, a:b], x + a, y + c, gap, least)]
    c, d = rows[0]
    if (a, b, c, d) != (0, mask.shape[1], 0, mask.shape[0]):
        return boxes(mask[c:d, a:b], x + a, y + c, gap, least)
    if b - a < least[0] or d - c < least[1]:
        return []
    return [(x + a, y + c, x + b, y + d)]


def apart_by(a, b):
    return max(abs(p - q) for p, q in zip(a, b))


class Rect:
    """Something flat and rectangular in one frame. Edges in pixels; an edge at the room's own edge may go on beyond it."""

    def __init__(self, box, colour, room, detail=False, ragged=False):
        self.left, self.top, self.right, self.bottom = box
        self.colour = colour
        # Whether a corner of the box is empty: then it is no rectangle but several that overlap, or one that is partly covered.
        self.ragged = ragged
        # Whether it lies inside another: an icon, a word's ground, or something that has no business there.
        self.detail = detail
        self.cut = (self.left <= room[0] + 1, self.top <= room[1] + 1, self.right >= room[2] - 1, self.bottom >= room[3] - 1)

    @property
    def edges(self):
        return (self.left, self.top, self.right, self.bottom)

    @property
    def area(self):
        return (self.right - self.left) * (self.bottom - self.top)

    @property
    def partial(self):
        """Whether this may be a part of something only: of a window that is half out of the room, what is left may be its title bar."""
        return any(self.cut) or self.thin

    @property
    def thin(self):
        return self.bottom - self.top <= 60 or self.right - self.left <= 60

    def distance(self, other):
        """How far apart the two are, by the edges that can be seen of both."""
        same = apart_by(self.colour, other.colour) <= 2 * FLAT
        apart = [abs(a - b) for index, (a, b) in enumerate(zip(self.edges, other.edges)) if not (self.cut[index] or other.cut[index])]
        if not apart:
            # Of one that fills the room nothing can be compared: it is the same as another that does, and as nothing else.
            if all(self.cut) != all(other.cut):
                return 10000
            apart = [abs((self.left + self.right) - (other.left + other.right)) / 2,
                     abs((self.top + self.bottom) - (other.top + other.bottom)) / 2]
        # Of two that are as near, the one of the same colour is the same thing; and what is plainly another colour from one frame to
        # the next is the same thing only if it is about where that was: a window and the card that takes over from it.
        sudden = apart_by(self.colour, other.colour) > PLAIN and max(apart) > 220
        return max(apart) + (0 if same else 15) + (10000 if sudden or self.detail != other.detail else 0)


def in_shadow(pixel, colour):
    """Whether the pixel is that colour with less light on it: the window in front throws its shadow over its neighbours' edges."""
    light = max(colour)
    share = max(int(value) for value in pixel) / light
    return 0.4 <= share <= 1.05 and all(abs(int(value) - part * share) <= 14 for value, part in zip(pixel, colour))


def out_of_the_shadow(box, colour, picture, room, scale):
    """The box, carried on over pixels that are its colour in shadow. Only for colours that can be told by their hue."""
    if max(colour) - min(colour) < 60:
        return box
    left, top, right, bottom = box
    reach = 40 * scale

    def carried(start, step, limit, across, horizontal):
        steps = []
        for place in across:
            count = 0
            while count < reach and (start + step * (count + 1) - limit) * step < 0:
                at = start + step * (count + 1)
                if not in_shadow(picture[place, at] if horizontal else picture[at, place], colour):
                    break
                count += 1
            steps.append(count)
        return sorted(steps)[1]

    rows = [int(top + share * (bottom - top)) for share in (0.3, 0.5, 0.7)]
    columns = [int(left + share * (right - left)) for share in (0.3, 0.5, 0.7)]
    return (left - carried(left, -1, room[0] - 1, rows, True), top - carried(top, -1, room[1] - 1, columns, False),
            right + carried(right - 1, 1, room[2], rows, True), bottom + carried(bottom - 1, 1, room[3], columns, False))


def whole(rects, room, scale):
    """Windows, of the flat patches they are made of: a bar that sits on a body of the same width is its title bar, and what then lies
    inside another and is small beside it (an icon, a word's ground) is a detail of it."""
    slack = 3 * scale
    joined, used = [], set()
    for body in sorted(rects, key=lambda rect: -rect.bottom):
        if id(body) in used:
            continue
        box = list(body.edges)
        for bar in rects:
            if bar is body or id(bar) in used:
                continue
            if abs(bar.left - box[0]) <= slack and abs(bar.right - box[2]) <= slack and abs(bar.bottom - box[1]) <= slack + 2:
                box[1] = bar.top
                used.add(id(bar))
        used.add(id(body))
        joined.append(Rect(tuple(box), body.colour, room, ragged=body.ragged))
    for rect in joined:
        rect.detail = any(other is not rect and other.area > 4 * rect.area and other.left - slack <= rect.left and other.top - slack <= rect.top
                          and other.right + slack >= rect.right and other.bottom + slack >= rect.bottom for other in joined)
    return joined


class Track:
    """One thing followed through the film."""

    def __init__(self):
        self.indices = []
        self.times = []
        self.rects = []

    def add(self, index, time, rect):
        self.indices.append(index)
        self.times.append(time)
        self.rects.append(rect)

    @property
    def last(self):
        return self.rects[-1]

    @property
    def detail(self):
        return self.rects[0].detail

    def ragged(self, since, until):
        """Whether it was, at some moment of that stretch, no clean rectangle: nothing can be said of its edges then."""
        return any(rect.ragged for time, rect in zip(self.times, self.rects) if since - 50 <= time <= until)

    @property
    def lifetime(self):
        return self.times[-1] - self.times[0]

    def edge(self, which):
        """That edge over time, with nan where it is cut off by the room's edge, or where so little is left in the room that it may be
        a part of the thing only."""
        return np.array([np.nan if rect.cut[which] or (rect.thin and any(rect.cut)) else rect.edges[which] for rect in self.rects], dtype=float)

    def costumes(self):
        """The colours it wore, in order: each plainly another than the one before. A fade passes through many on its way to one."""
        worn = []
        for rect in self.rects:
            if rect.partial:
                continue
            if not worn or apart_by(worn[-1], rect.colour) > PLAIN:
                worn.append(rect.colour)
        return worn


class Scan:
    """Everything the checks want to know of a film, from two passes over its frames."""

    # A thing fills at least this share of the room, or it is not looked for.
    SHARE = 0.006
    # A thing that has not been seen for this long, in frames that were taken, is gone. (A fade from a card to the window hides both.)
    PATIENCE = 220

    def __init__(self, film):
        self.film = film
        self.room = film.room()
        x0, y0, x1, y1 = self.room
        self.background = None
        self.colours = []
        known = {}
        # How many pixels changed plainly: in the room, in the menu bar, in the Dock's strip.
        self.changed = np.zeros((len(film), 3), dtype=np.int64)
        self.boxes_changed = [None] * len(film)
        # Of what the menu bar and the Dock showed at first, the share that is plainly another colour now.
        self.strips = np.zeros((len(film), 2))
        # Every sixteenth pixel of the room in every frame: for what is too large to be followed as a thing.
        self.small = []
        previous = None
        for index, _, picture, changed in film.frames():
            inside = picture[y0:y1, x0:x1]
            self.small.append(inside[::16, ::16].astype(np.int16))
            if index == 0:
                first = picture
                # The bar is all its own. The Dock's own are its icons, told by their colours: its plate is glass, and shows what passes under it.
                strip = picture[y1:].astype(np.int16)
                own = (np.ones(picture[:y0].shape[:2], dtype=bool), strip.max(axis=2) - strip.min(axis=2) >= 60)
            else:
                for which, (now, then) in enumerate(((picture[:y0], first[:y0]), (picture[y1:], first[y1:]))):
                    if own[which].any():
                        other = (np.maximum(now, then) - np.minimum(now, then) > PLAIN).any(axis=2)
                        self.strips[index, which] = (other & own[which]).sum() / own[which].sum()
            if index == 0:
                # Arbor leaves a gap all around, so the room's outermost pixels show the wallpaper, if anything does.
                ring = np.concatenate([inside[:4].reshape(-1, 3), inside[-4:].reshape(-1, 3), inside[:, :4].reshape(-1, 3),
                                       inside[:, -4:].reshape(-1, 3)])
                commonest = flat_colours(ring[None], 0.3)
                self.background = commonest[0] if commonest else None
            # Frame by frame, because a fade goes through colours that are nowhere else in the film.
            flat = []
            for colour in flat_colours(inside, self.SHARE, known):
                if (self.background is None or apart_by(colour, self.background) > FLAT) and not any(apart_by(colour, other) <= FLAT for other in flat):
                    flat.append(colour)
            self.colours.append(flat)
            if previous is not None and changed.any():
                plain = changed & (np.maximum(picture, previous) - np.minimum(picture, previous) > 2).any(axis=2)
                self.changed[index] = (plain[y0:y1, x0:x1].sum(), plain[:y0].sum(), plain[y1:].sum())
                rows, columns = np.flatnonzero(plain[y0:y1, x0:x1].any(axis=1)), np.flatnonzero(plain[y0:y1, x0:x1].any(axis=0))
                if rows.size:
                    self.boxes_changed[index] = (x0 + columns[0], y0 + rows[0], x0 + columns[-1] + 1, y0 + rows[-1] + 1)
            previous = picture
        self.tracks = []
        self.rects = []
        self.follow()

    def follow(self):
        x0, y0, x1, y1 = self.room
        scale = self.film.scale
        lines = [(x * scale, y * scale, (x + w) * scale, (y + h) * scale) for _, level, (x, y, w, h) in self.film.overlays if level == 6]
        running = []
        for index, time, picture, _ in self.film.frames():
            inside = picture[y0:y1, x0:x1]
            found = []
            for colour in self.colours[index]:
                mask = rub(near(inside, colour, FLAT))
                if mask.sum() < 400:
                    continue
                for a, b, c, d in boxes(mask, x0, y0):
                    # A ring or a frame of lines encloses much and fills little.
                    if mask[b - y0:d - y0, a - x0:c - x0].mean() < 0.45:
                        continue
                    inset = min(36 * self.film.scale, (c - a) // 4, (d - b) // 4)
                    corners = [mask[y - y0, x - x0] for x in (a + inset, c - 1 - inset) for y in (b + inset, d - 1 - inset)]
                    box = out_of_the_shadow((a - RUB, b - RUB, c + RUB, d + RUB), colour, picture, self.room, self.film.scale)
                    found.append(Rect(box, colour, self.room, ragged=not all(corners)))
            # The line of words is no window, and in dark mode it looks like a card.
            found = [rect for rect in found if not any(max(abs(a - b) for a, b in zip(rect.edges, line)) <= 6 * self.film.scale for line in lines)]
            found = whole(found, self.room, self.film.scale)
            self.rects.append(found)
            # A screen at rest sends no frames, so what counts is the time since the first frame it was missing from.
            running = [track for track in running if track.indices[-1] == index - 1
                       or time - int(self.film.times[track.indices[-1] + 1]) <= self.PATIENCE]
            pairs = sorted(((track.last.distance(rect), order, place) for order, track in enumerate(running)
                            for place, rect in enumerate(found)), key=lambda pair: pair[0])
            taken_tracks, taken_rects = set(), set()
            for distance, order, place in pairs:
                if order in taken_tracks or place in taken_rects or distance > 700 * self.film.scale:
                    continue
                running[order].add(index, time, found[place])
                taken_tracks.add(order)
                taken_rects.add(place)
            for place, rect in enumerate(found):
                if place not in taken_rects:
                    track = Track()
                    track.add(index, time, rect)
                    running.append(track)
                    self.tracks.append(track)
