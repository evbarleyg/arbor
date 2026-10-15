"""What can be measured of a film: when it answered, how it moved, what hopped, flickered or flashed. docs/POLISH.md says what passes."""

import numpy as np

from film import PLAIN, Scan, apart_by, near

# The display shows a frame this often, in milliseconds.
TICK = 1000 / 60
# Timing functions a motion may follow, as cubic Béziers. The fit says how long the motion was MEANT to last: the last tenth of
# an eased motion covers less than a pixel, so what can be seen of it is shorter.
CURVES = {
    "Arbor's": (0.2, 0, 0, 1),
    "ease-out": (0, 0, 0.58, 1),
    "ease": (0.25, 0.1, 0.25, 1),
    "ease-in-out": (0.42, 0, 0.58, 1),
    "ease-in": (0.42, 0, 1, 1),
    "sharp ease-out": (0.16, 1, 0.3, 1),
    "linear": (0, 0, 1, 1),
}


def bezier(points, count=801):
    x1, y1, x2, y2 = points
    s = np.linspace(0, 1, count)
    x = 3 * (1 - s) ** 2 * s * x1 + 3 * (1 - s) * s * s * x2 + s**3
    y = 3 * (1 - s) ** 2 * s * y1 + 3 * (1 - s) * s * s * y2 + s**3
    return x, y


def held(times, values, tick=TICK):
    """A frame that equals the last is not sent. So after a long wait the value was still the old one a frame before the new one came.
    After a short wait that is not so sure: a busy display skips a frame or three, and what moves is then further on, on the same curve."""
    t, v = [times[0]], [values[0]]
    for index in range(1, len(times)):
        if times[index] - times[index - 1] > 4.5 * tick:
            t.append(times[index] - tick)
            v.append(values[index - 1])
        t.append(times[index])
        v.append(values[index])
    return np.array(t, dtype=float), np.array(v, dtype=float)


def crossing(times, progress, level):
    """When the progress first reaches that level, between two samples."""
    above = np.flatnonzero(progress >= level)
    if above.size == 0:
        return None
    index = above[0]
    if index == 0:
        return float(times[0])
    a, b = progress[index - 1], progress[index]
    return float(times[index - 1] + (times[index] - times[index - 1]) * (level - a) / (b - a))


def fit(times, progress):
    """(curve's name, start, duration, error): the timing function, of those known, that the progress follows best."""
    best = None
    first = crossing(times, progress, 0.02)
    last = crossing(times, progress, 0.98)
    if first is None or last is None:
        return None
    span = max(last - first, TICK)

    def error_of(x, y, start, duration):
        return float(np.sqrt(np.mean((np.interp((times - start) / duration, x, y) - progress) ** 2)))

    for name, points in CURVES.items():
        x, y = bezier(points)
        # Roughly first, then closely around the best.
        rough = min((error_of(x, y, start, duration), start, duration)
                    for duration in np.arange(0.6 * span, 3.2 * span, 16)
                    for start in np.arange(first - 0.35 * duration, first + TICK, 12))
        close = min((error_of(x, y, start, duration), start, duration)
                    for duration in np.arange(max(rough[2] - 16, 8), rough[2] + 17, 2)
                    for start in np.arange(rough[1] - 12, rough[1] + 13, 2))
        # Two curves can tell the same story at different lengths. Of those that fit about as well, the first in the list: Arbor's own.
        if best is None or close[0] < best[3] - 0.004:
            best = (name, float(close[1]), float(close[2]), close[0])
    return best


class Motion:
    """How the things that travel in a film travel, from `cause` on: every edge's road as a share of its whole road.

    Of a thing that changes its look on the way the top edge is left out, here and wherever edges are compared: a title bar in the shadow
    of the window above it is not flat, so a window may be found without it, and the card that stands in for it has none."""

    # An edge that travels less than this many points says little about a curve.
    LEAST = 24

    def __init__(self, scan, cause, until, tick=TICK):
        film = scan.film
        self.roads = []
        self.tick = tick
        self.cause = cause
        for track in scan.tracks:
            if track.detail or track.ragged(cause, until) or track.lifetime < 150 or track.times[0] > cause or track.times[-1] < until:
                continue
            times = np.array(track.times, dtype=float)
            for which in range(4):
                if which == 1 and len(track.costumes()) > 1:
                    continue
                values = track.edge(which)
                seen = ~np.isnan(values) & (times <= until)
                if seen.sum() < 4 or not seen[times <= cause][-1]:
                    continue
                t, v = times[seen], values[seen]
                start = v[t <= cause][-1]
                if abs(v[-1] - start) < self.LEAST * film.scale:
                    continue
                keep = t >= t[t <= cause][-1]
                self.roads.append((track, which, *held(t[keep], v[keep], tick)))
        self.seen = bool(self.roads)
        if not self.seen:
            return
        # One clock for all: every moment at which any of them was sampled.
        self.times = np.unique(np.concatenate([road[2] for road in self.roads]))
        shares = []
        for _, _, t, v in self.roads:
            shares.append(np.interp(self.times, t, (v - v[0]) / (v[-1] - v[0])))
        shares = np.array(shares)
        self.progress = np.median(shares, axis=0)
        self.spread = float((shares.max(axis=0) - shares.min(axis=0)).max())
        self.travel = float(max(abs(road[3][-1] - road[3][0]) for road in self.roads))
        self.longest = max(self.roads, key=lambda road: abs(road[3][-1] - road[3][0]))
        self.analyse()
        self.strays = self.out_of_step(scan, cause, until)
        self.starts = self.hops_at_the_start()

    def hops_at_the_start(self):
        """A glide gathers speed, so its first step is its smallest. A first step larger than the second is the stand-in not being
        where the window was. [(time, pixels)]"""
        found = []
        for _, _, t, v in self.roads:
            steps = np.abs(np.diff(v))
            moving = np.flatnonzero(steps >= 1)
            if moving.size < 3:
                continue
            first = moving[0]
            # By the frame, because the second step may have taken two.
            pace = steps / np.maximum(np.round(np.diff(t) / self.tick), 1)
            if first + 1 < len(steps) and steps[first] >= 3 and steps[first] > 1.5 * pace[first + 1] + 1:
                found.append((float(t[first + 1]), float(steps[first] - pace[first + 1])))
        return found

    def out_of_step(self, scan, cause, until):
        """Of an edge that comes from beyond the room's edge, or leaves over it, only a part of the road is seen. If it moves in step
        with the others, where it is depends on their progress in a straight line. [(track, edge, how far off in pixels)]"""
        whole = {(id(track), which) for track, which, _, _ in self.roads}
        found = []
        for track in scan.tracks:
            if track.detail or track.ragged(cause, until):
                continue
            times = np.array(track.times, dtype=float)
            for which in range(4):
                if (id(track), which) in whole or (which == 1 and len(track.costumes()) > 1):
                    continue
                values = track.edge(which)
                seen = ~np.isnan(values) & (times >= cause) & (times <= until)
                if seen.sum() < 5 or np.ptp(values[seen]) < self.LEAST * scan.film.scale:
                    continue
                share = np.interp(times[seen], self.times, self.progress)
                if np.ptp(share) < 0.1:
                    continue
                slope, start = np.polyfit(share, values[seen], 1)
                off = float(np.abs(values[seen] - (start + slope * share)).max())
                found.append((track, which, off))
        return found

    def analyse(self):
        _, _, t, v = self.longest
        direction = np.sign(v[-1] - v[0])
        way = (v - v[0]) * direction
        steps = np.diff(way)
        moving = np.flatnonzero(np.abs(steps) >= 1)
        self.first = float(t[moving[0] + 1])
        self.last = float(t[moving[-1] + 1])
        self.visible = self.last - self.first + self.tick
        self.overshoot = float(max(way.max() - way[-1], 0))
        # Not in the first frames after the cause: what was under way then goes on until the answer shows.
        late = steps[t[1:] >= self.cause + 70]
        self.backwards = float(max(-late.min(), 0)) if late.size else 0.0
        self.marks = {level: crossing(self.times, self.progress, level) for level in (0.05, 0.5, 0.95)}
        early, half, late = self.marks[0.05], self.marks[0.5], self.marks[0.95]
        # How much longer the second half of the road takes than the first: 1 for a motion that does not slow down.
        self.settle = (late - half) / max(half - early, 1) if None not in (early, half, late) else None
        self.fit = fit(self.times, self.progress)
        # The biggest share of the road covered between two frames.
        self.leap = float(np.abs(steps).max() / max(way[-1], 1))

        # Pushes: the speed rises, falls, and should not rise again. A wait counts for four frames at the most, so that a hop after a
        # rest is as sudden here as it is on the display.
        speed = np.abs(steps) / np.minimum(np.diff(t), 4 * self.tick)
        self.pushes = []
        peak = int(np.argmax(speed))
        index = peak + 1
        while index < len(speed):
            # Against the last three steps, not the last one: a frame that came a little early makes one step short and the next one long.
            calm = max(float(np.median(speed[max(index - 3, peak):index])), 0.02)
            if np.abs(steps[index]) >= 3 and speed[index] >= 3 * calm:
                # Everything from here to the end was not part of the glide.
                self.pushes.append({"time": float(t[index + 1]), "left": float(abs(way[-1] - way[index])), "pause": float(t[index + 1] - t[index])})
                following = np.flatnonzero(speed[index:] < speed[index] / 3)
                index += int(following[0]) if following.size else len(speed)
            index += 1


def wobbles(scan, cause, until):
    """Edges that end where they began should not have been anywhere else meanwhile. [(track, edge, frame, pixels)]"""
    found = []
    for track in scan.tracks:
        if track.detail or track.ragged(cause, until) or track.times[0] > cause or track.times[-1] < until:
            continue
        times = np.array(track.times, dtype=float)
        for which in range(4):
            if which == 1 and len(track.costumes()) > 1:
                continue
            values = track.edge(which)
            seen = ~np.isnan(values) & (times <= until)
            # Where it was when the cause came, not where it was last seen whole.
            if seen.sum() < 3 or not (times <= cause).any() or not seen[times <= cause][-1]:
                continue
            start = values[times <= cause][-1]
            if abs(values[seen][-1] - start) > 2:
                continue
            off = np.abs(values - start)
            off[~seen | (times < cause)] = 0
            if off.max() > 2:
                found.append((track, which, track.indices[int(off.argmax())], float(off.max())))
    return found


def looks(scan, cause, until):
    """How abruptly each thing that was followed changes its colour: [(track, the largest step between two frames in levels, frame)].
    Looked at in a patch at its lower left, away from title bars, words and icons, also in the frames in which a fade hid it from
    the follower: there it is taken to be between where it was last seen and where it is seen next."""
    film = scan.film
    wanted = [track for track in scan.tracks
              if not track.detail and track.lifetime >= 150 and track.times[0] <= cause and (len(track.costumes()) > 1 or len(track.indices) <= track.indices[-1] - track.indices[0])]
    if not wanted:
        return []
    series = {id(track): [] for track in wanted}
    for index, time, picture, _ in film.frames():
        if time > until + 400:
            break
        for track in wanted:
            if not track.indices[0] <= index <= track.indices[-1]:
                continue
            # Not while a part of it is out of the room: how large it is cannot be told then.
            place = int(np.searchsorted(track.indices, index))
            if track.rects[place].partial or track.rects[max(place - 1, 0)].partial:
                continue
            left, top, right, bottom = [np.interp(index, track.indices, [rect.edges[which] for rect in track.rects]) for which in range(4)]
            box = (int(left + 0.08 * (right - left)), int(top + 0.62 * (bottom - top)), int(left + 0.3 * (right - left)), int(top + 0.9 * (bottom - top)))
            patch = picture[max(box[1], 0):box[3], max(box[0], 0):box[2]]
            if patch.size:
                series[id(track)].append((index, patch.reshape(-1, 3).mean(axis=0)))
    found = []
    for track in wanted:
        samples = series[id(track)]
        if len(samples) < 2:
            continue
        # From the cause on: what a preview's tint does to a window that is still held is another check's.
        steps = [float(np.abs(b[1] - a[1]).max()) if film.times[b[0]] >= cause - 5 else 0.0 for a, b in zip(samples[:-1], samples[1:])]
        worst = int(np.argmax(steps))
        found.append((track, steps[worst], samples[worst + 1][0]))
    return found


def cause_of(film):
    """(time, how it is known): the moment of the thing a person did last before things moved."""
    action = film.time_of("action") or int(film.times[0])
    goes = next((time for time, mark in film.marks if mark.startswith("metronome") and " goes " in mark), None)
    if goes is not None:
        return goes, "exact"
    lifted = film.time_of("fingers up")
    if lifted is not None:
        return lifted, "exact"
    ups = [time for time, what, _, _ in film.buttons if what == "up" and time >= action]
    if film.kind == "panel":
        # Whatever came first, a key or a click: a menu is opened with one and closed with the other.
        first = sorted([time for time, what in film.keys if what == "down" and time >= action]
                       + [time for time, what, _, _ in film.buttons if what == "down" and time >= action])
        if first:
            return first[0], "exact"
    if film.kind == "drag" and ups:
        return ups[-1], "exact"
    downs = [time for time, what in film.keys if what == "down" and time >= action]
    if downs:
        # Of two keys in a row the second: what is asked is how things go on from where the first had got them.
        return (downs[0] if film.kind == "hold" else downs[-1]), "exact"
    if ups:
        return ups[-1], "exact"
    return action, "about"


def episodes(film, scan, since, least=150, pause=120):
    """The stretches of time in which the room changed: [(first time, last time, first frame, last frame, box)]."""
    found = []
    for index in range(1, len(film)):
        time = int(film.times[index])
        if time < since or scan.changed[index][0] < least * film.scale**2:
            continue
        box = scan.boxes_changed[index]
        if found and time - found[-1][1] <= pause:
            a, _, c, _, old = found[-1]
            found[-1] = (a, time, c, index, (min(old[0], box[0]), min(old[1], box[1]), max(old[2], box[2]), max(old[3], box[3])))
        else:
            found.append((time, time, index, index, box))
    return found


def moved_in(scan, spell):
    """How far, in pixels, the thing that moved most in that spell of change moved."""
    most = 0
    for track in scan.tracks:
        if track.detail:
            continue
        before = [rect for index, rect in zip(track.indices, track.rects) if index < spell[2]]
        after = [rect for index, rect in zip(track.indices, track.rects) if index >= spell[3]]
        if before and after:
            most = max([most] + [abs(a - b) for which, (a, b) in enumerate(zip(before[-1].edges, after[0].edges))
                                 if not before[-1].cut[which] and not after[0].cut[which]])
    return most


def is_small(box, room):
    """Whether what changed is a line of words rather than a window: Arbor's heads-up line coming or going."""
    return (box[3] - box[1]) <= 0.12 * (room[3] - room[1]) and (box[2] - box[0]) <= 0.6 * (room[2] - room[0])


def flashes(scan, since, longest=130):
    """Things that were there for a moment: [(track, milliseconds)]. Not the first or the last that is seen of something that comes
    into the room or leaves it: a title bar ahead of its window."""
    film = scan.film
    found = []
    for track in scan.tracks:
        if track.times[0] < since or track.indices[0] == 0 or track.indices[-1] >= len(film) - 1:
            continue
        shown = int(film.times[track.indices[-1] + 1]) - track.times[0]
        if shown > longest:
            continue
        first, last = track.rects[0], track.last
        # A sliver at the room's edge is the first or the last of something that comes or goes. (So a sliver that flashes there is left to eyes.)
        room = scan.room
        if first.thin and (min(first.left - room[0], room[2] - first.right, first.top - room[1], room[3] - first.bottom) <= 80 * film.scale):
            continue
        if track.detail and not stays_the_same_around(scan, track):
            continue
        part = False
        for other in scan.tracks:
            if other is track or other.lifetime <= 130:
                continue
            if 0 <= other.indices[0] - track.indices[-1] <= 2 and touches(other.rects[0], last):
                part = True
            if 0 <= track.indices[0] - other.indices[-1] <= 2 and touches(other.last, first):
                part = True
        if not part:
            found.append((track, shown))
    return really(scan, found)


def washes(scan, since):
    """Moments at which two fifths of the room or more were plainly something else for 130 ms or less, and then what they had been:
    [(frame, milliseconds, share of the room)]. Too large to be followed as a thing, and the worst flash there is."""
    film, found = scan.film, []
    for index in range(1, len(film) - 1):
        if film.times[index] < since:
            continue
        before, now = scan.small[index - 1], scan.small[index]
        other = (np.abs(now - before).max(axis=2) > PLAIN)
        if other.mean() < 0.4:
            continue
        for later in range(index + 1, len(film)):
            if film.times[later] - film.times[index] > 130:
                break
            back = other & (np.abs(scan.small[later] - before).max(axis=2) <= PLAIN)
            if back.mean() >= 0.4:
                found.append((index, int(film.times[later] - film.times[index]), float(back.mean())))
                break
    return found


def really(scan, candidates):
    """Of things that were found for a moment only, those whose place plainly looked otherwise just before and just after. The others
    were there all along, and only the finding of them flickered."""
    if not candidates:
        return []
    wanted = {}
    for place, (track, _) in enumerate(candidates):
        for index, role in ((track.indices[0] - 1, "before"), (track.indices[0], "during"), (track.indices[-1] + 1, "after")):
            wanted.setdefault(index, []).append((place, role))
    seen = {}
    for index, _, picture, _ in scan.film.frames():
        for place, role in wanted.get(index, []):
            rect = candidates[place][0].rects[0]
            seen[(place, role)] = picture[max(rect.top, 0):rect.bottom, max(rect.left, 0):rect.right].astype(np.int16)
    kept = []
    for place, candidate in enumerate(candidates):
        during = seen[(place, "during")]
        other = [(np.abs(during - seen[(place, role)]).max(axis=2) > PLAIN).mean() for role in ("before", "after")]
        if min(other) >= 0.5:
            kept.append(candidate)
    return kept


def stays_the_same_around(scan, detail):
    """Whether what the detail lies in was there, whole and in the same colour, before it came and after it went. Otherwise it came and
    went with it: the icon of a card."""
    first, last = detail.indices[0], detail.indices[-1]
    for track in scan.tracks:
        if track.detail or track.indices[0] > first - 2 or track.indices[-1] < last + 2:
            continue
        around = [rect for index, rect in zip(track.indices, track.rects) if first - 2 <= index <= last + 2]
        inside = all(rect.left <= detail.rects[0].left and rect.right >= detail.rects[0].right and rect.top <= detail.rects[0].top
                     and rect.bottom >= detail.rects[0].bottom for index, rect in zip(track.indices, track.rects) if first <= index <= last)
        if around and inside and all(apart_by(rect.colour, around[0].colour) <= PLAIN for rect in around):
            return True
    return False


def touches(a, b, by=60):
    return a.left - by <= b.right and b.left - by <= a.right and a.top - by <= b.bottom and b.top - by <= a.bottom


def blinks(scan, since):
    """Things that went away and came back to the same place within a moment, leaving the wallpaper to be seen: [(track, frame, ms)]."""
    film = scan.film
    if scan.background is None:
        return []
    found = []
    wanted = {}
    for track in scan.tracks:
        if track.detail:
            continue
        for a, b in zip(range(len(track.indices) - 1), range(1, len(track.indices))):
            if track.indices[b] - track.indices[a] > 1 and track.times[b] >= since:
                wanted.setdefault(track.indices[a] + 1, []).append((track, a, b))
    if not wanted:
        return []
    for index, _, picture, _ in film.frames():
        for track, a, b in wanted.get(index, []):
            rect = track.rects[a]
            middle = picture[rect.top + 8:rect.bottom - 8, rect.left + 8:rect.right - 8]
            if middle.size and near(middle, scan.background, PLAIN).mean() > 0.7:
                found.append((track, index, track.times[b] - int(film.times[index])))
    return found


def measure(film):
    """Everything in one dictionary. `scan` and `motion` are objects; the rest is numbers and lists."""
    scan = Scan(film)
    cause, how = cause_of(film)
    result = {"film": film, "scan": scan, "cause": cause, "cause_known": how}
    spells = episodes(film, scan, cause - 5)
    result["episodes"] = spells
    result["latency"] = spells[0][0] - cause if spells else None
    result["rest"] = spells[0][1] - cause if spells else None
    over = next((time for time, mark in film.marks if mark.startswith("metronome") and mark.endswith("is over")), None)
    result["afterthoughts"] = [spell + (moved_in(scan, spell),) for spell in spells[1:]
                               if not is_small(spell[4], scan.room) and (over is None or spell[0] < over - 50)]
    # A change of a fifth of the room after a standstill is no afterthought: the display stood still in the middle of things.
    room_area = (scan.room[2] - scan.room[0]) * (scan.room[3] - scan.room[1])
    result["stalls"] = []
    previous = spells[0] if spells else None
    for spell in result["afterthoughts"]:
        most = max(int(scan.changed[index][0]) for index in range(spell[2], spell[3] + 1))
        if most >= 0.2 * room_area and spell[0] - cause <= 3000:
            result["stalls"].append((spell[0] - previous[1], spell[2]))
            result["rest"] = spell[1] - cause
        previous = spell
    # What the camera managed, which on a busy Mac is not what the display showed: the usual wait between two frames under way.
    tick = TICK
    if spells and spells[0][3] - spells[0][2] >= 4:
        tick = float(np.clip(np.median(np.diff(film.times[spells[0][2]:spells[0][3] + 1])), TICK, 60))
    result["tick"] = tick
    until = spells[0][1] if spells else cause
    result["motion"] = Motion(scan, cause, until, tick)
    result["wobbles"] = wobbles(scan, cause, until)
    result["looks"] = looks(scan, cause, until)
    result["flashes"] = flashes(scan, cause - 5)
    result["washes"] = washes(scan, cause - 5)
    result["blinks"] = blinks(scan, cause - 5)
    after = film.times >= cause
    result["bars"] = (float(scan.strips[after, 0].max(initial=0)), float(scan.strips[after, 1].max(initial=0)))
    costumes = [track.costumes() for track in scan.tracks if not track.detail and track.lifetime >= 150 and len(track.costumes()) > 1]
    result["costumes"] = costumes
    return result
