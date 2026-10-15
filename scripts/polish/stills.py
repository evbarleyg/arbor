#!/usr/bin/env python3
"""The ruler for pictures at rest: what docs/POLISH.md asks of a panel in S1 to S7, measured in a picture of the real app.

A picture does not say where in it a panel is or which of its marks are words. Somebody with eyes does: a reviewer looks, names the rectangle,
and this measures inside it. So the number is a script's and the judgement of what it is a number of is a reviewer's.
Rectangles are x,y,w,h in the picture's own pixels, origin top-left.

  stills.py crop <png> <box> <out.png> [--zoom n]   that part of the picture, enlarged without smoothing (4), to look at
  stills.py differs <png> <png>                     the boxes in which two pictures of the same size differ: where something came or went
  stills.py read <png> <box>                        S4, S6: the contrast of ink to ground (WCAG) in a box drawn closely round ONE line of words, strip by strip
  stills.py fits <png> <panel's box> [--scale n]    S3: how far the ink keeps from the panel's edges, in points
  stills.py edges <png> <panel's box> [--reach n]   S1, S2, S6: across each straight side, from n (5) pixels outside to n inside: how many pixels the step takes, and the
                                                    outline's contrast to what is around it. A soft shadow outside, or a mark of the panel's own within reach, is counted in: look, and shorten the reach
  stills.py flat <png> <box>                        S7: how much a ground varies, the ink left out
  stills.py --self-test                             pictures drawn here, each wrong in one known way

Needs numpy and Pillow (and no Mac). The numbers that pass are docs/POLISH.md's: change them there first.
"""

import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# A strip of a line of words, in pixels: wide enough for a letter or two, narrow enough for what shines through glass to be one colour in it.
STRIP = 24
# From here on a pixel is ink, in levels of 255 from the ground (docs/POLISH.md, S3).
INK = 60


def picture(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float64)


def box_of(text):
    x, y, w, h = (int(word) for word in text.split(","))
    return x, y, w, h


def part(image, box):
    x, y, w, h = box
    return image[max(y, 0):y + h, max(x, 0):x + w]


def luminance(colour):
    """WCAG's relative luminance of an sRGB colour, or of an array of them."""
    c = np.asarray(colour, dtype=np.float64) / 255
    linear = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return linear @ np.array([0.2126, 0.7152, 0.0722])


def contrast(a, b):
    first, second = sorted((float(luminance(a)), float(luminance(b))), reverse=True)
    return (first + 0.05) / (second + 0.05)


def ground_of(area):
    """What most of an area is: the median, channel by channel. Words cover less than half of a box drawn round them."""
    return np.median(area.reshape(-1, 3), axis=0)


def away(area, ground):
    return np.abs(area - ground).max(axis=2)


def read(image, box):
    """[(x, contrast, ink, ground)] for every strip of the box that has ink in it. The ink is the fiftieth of the strip's pixels farthest from its ground:
    the cores of the strokes. Their soft edges are nearer the ground, and thin strokes have no core at all, which is what an eye finds too."""
    area, found = part(image, box), []
    for left in range(0, area.shape[1], STRIP):
        strip = area[:, left:left + STRIP]
        if strip.shape[1] < STRIP // 2:
            continue
        ground = ground_of(strip)
        distance = away(strip, ground).ravel()
        if distance.max() < 25:
            continue
        count = max(int(distance.size * 0.02), 3)
        ink = strip.reshape(-1, 3)[np.argsort(distance)[-count:]].mean(axis=0)
        found.append((box[0] + left, contrast(ink, ground), ink, ground))
    return found


def fits(image, box, scale=1):
    """(left, top, right, bottom) in points between the panel's edges and its ink, or None without ink. A band one tenth of the shorter side wide along the edges,
    at most 4 points, is the panel's own outline and corners, unless the ink reaches into it from inside."""
    area = part(image, box)
    inner = area[area.shape[0] // 4:-(area.shape[0] // 4) or None]
    marks = away(area, ground_of(inner)) >= INK
    # What shows outside round corners is not the panel's. A capsule's corners are half its height.
    corner = int(min(min(area.shape[:2]) / 2, 24 * scale))
    for rows in (slice(None, corner), slice(-corner, None)):
        for columns in (slice(None, corner), slice(-corner, None)):
            marks[rows, columns] = False
    rim = int(min(min(area.shape[:2]) / 10, 4 * scale))
    core = marks.copy()
    core[:rim], core[-rim:], core[:, :rim], core[:, -rim:] = False, False, False, False
    if not core.any():
        return None
    rows, columns = np.where(core.any(axis=1))[0], np.where(core.any(axis=0))[0]
    first, last, left, right = int(rows[0]), int(rows[-1]), int(columns[0]), int(columns[-1])

    def goes_on(line, inside, beside):
        """Ink that goes on into the rim touches or is clipped. An outline is marked beside the ink as well; ink is not."""
        return line[inside].any() and not line[beside].any()

    across, down = np.zeros(area.shape[0], dtype=bool), np.zeros(area.shape[1], dtype=bool)
    across[first:last + 1], down[left:right + 1] = True, True
    middle_rows, middle_columns = np.zeros_like(across), np.zeros_like(down)
    middle_rows[rim:-rim], middle_columns[rim:-rim] = True, True
    while left > 0 and left <= rim and goes_on(marks[:, left - 1], across, middle_rows & ~across):
        left -= 1
    while right < area.shape[1] - 1 and right >= area.shape[1] - 1 - rim and goes_on(marks[:, right + 1], across, middle_rows & ~across):
        right += 1
    while first > 0 and first <= rim and goes_on(marks[first - 1], down, middle_columns & ~down):
        first -= 1
    while last < area.shape[0] - 1 and last >= area.shape[0] - 1 - rim and goes_on(marks[last + 1], down, middle_columns & ~down):
        last += 1
    return tuple(round(value / scale, 1) for value in (left, first, area.shape[1] - 1 - right, area.shape[0] - 1 - last))


def profiles(image, box, side, reach=5):
    """Lines of pixels across one side of a box, from outside to inside, along its middle three fifths (corners are round)."""
    x, y, w, h = box
    height, width = image.shape[:2]
    if side in ("left", "right"):
        along = range(y + h // 5, y + h - h // 5)
        at = x if side == "left" else x + w - 1
        span = range(at - reach, at + reach + 1) if side == "left" else range(at + reach, at - reach - 1, -1)
        return np.array([[image[a, min(max(b, 0), width - 1)] for b in span] for a in along if 0 <= a < height])
    along = range(x + w // 5, x + w - w // 5)
    at = y if side == "top" else y + h - 1
    span = range(at - reach, at + reach + 1) if side == "top" else range(at + reach, at - reach - 1, -1)
    return np.array([[image[min(max(b, 0), height - 1), a] for b in span] for a in along if 0 <= a < width])


def edge(image, box, side, reach=5):
    """Of one side: {"step": levels between outside and inside, "between": pixels from 10% to 90% of that step, "outline": contrast of the most
    different pixel on the way to the outside, "half": whether one row is about half-way, as a side off the pixel grid is}. None under 60 px."""
    lines = profiles(image, box, side, reach)
    if len(lines) < 60:
        return None
    line = np.median(lines, axis=0)
    outside, inside = line[:2].mean(axis=0), line[-2:].mean(axis=0)
    channel = int(np.abs(inside - outside).argmax())
    step = float(inside[channel] - outside[channel])
    said = {"step": round(abs(step)), "between": None, "half": False,
            "outline": round(max(contrast(pixel, outside) for pixel in line[2:-2]), 2)}
    if abs(step) >= INK:
        share = (line[:, channel] - outside[channel]) / step
        middle = (share > 0.1) & (share < 0.9)
        said["between"] = int(middle.sum())
        said["half"] = bool(((share > 0.3) & (share < 0.7)).sum() == 1 and middle.sum() == 1)
    return said


def flat(image, box):
    """How far the ground's pixels lie apart, in levels: from the 5th to the 95th in a hundred of the channel that varies most, ink left out."""
    area = part(image, box)
    pixels = area.reshape(-1, 3)[away(area, ground_of(area)).ravel() < INK]
    low, high = np.percentile(pixels, [5, 95], axis=0)
    return float((high - low).max())


def differs(first, second, least=12, apart=10):
    """The boxes in which two pictures differ, cut apart wherever `apart` rows or columns in a row are the same."""
    def runs(flags):
        found, start, quiet = [], None, 0
        for index, flag in enumerate(list(flags) + [False] * (apart + 1)):
            if flag:
                start, quiet = (index if start is None else start), 0
            elif start is not None:
                quiet += 1
                if quiet > apart:
                    found.append((start, index - quiet + 1))
                    start = None
        return found

    changed = np.abs(first - second).max(axis=2) > least
    boxes = []
    for top, bottom in runs(changed.any(axis=1)):
        for left, right in runs(changed[top:bottom].any(axis=0)):
            rows = np.where(changed[top:bottom, left:right].any(axis=1))[0]
            boxes.append((left, top + int(rows[0]), right - left, int(rows[-1] - rows[0] + 1)))
    return boxes


def draw(ground=(40, 40, 44), ink=(235, 235, 235), behind=(255, 59, 48), margin=14, blur=0.0, offset=0.0, outline=None, glass=0, radius=0):
    """A panel of 300 by 60 at 100,100 on a strong colour, with a line of strokes for words."""
    scale = 4
    large = Image.new("RGB", (500 * scale, 260 * scale), behind)
    pen = ImageDraw.Draw(large)
    x, y = (100 + offset) * scale, (100 + offset) * scale
    pen.rounded_rectangle([x, y, x + 300 * scale - 1, y + 60 * scale - 1], radius * scale, fill=ground, outline=outline, width=scale if outline else 0)
    if glass:
        for column in range(0, 300, 50):
            tone = tuple(int(value + glass * (1 if column % 100 else -1)) for value in ground)
            pen.rectangle([x + column * scale, y + 2 * scale, x + (column + 50) * scale - 1, y + 58 * scale - 1], fill=tone)
    for stroke in range(100 + margin, 400 - margin - 3, 7):
        pen.rectangle([(stroke + offset) * scale, (122 + offset) * scale, (stroke + 3 + offset) * scale - 1, (138 + offset) * scale - 1], fill=ink)
    small = large.resize((500, 260), Image.BOX)
    if blur:
        small = small.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(small).astype(np.float64)


def self_test():
    panel, words = (100, 100, 300, 60), (110, 118, 280, 24)
    failures = []

    def expect(name, holds, said):
        print(f"{'✔' if holds else '✘'} {name}: {said}")
        if not holds:
            failures.append(name)

    good = draw()
    worst = min(value for _, value, _, _ in read(good, words))
    expect("words that can be read", abs(worst - contrast((235, 235, 235), (40, 40, 44))) < 0.3, f"{worst:.1f} : 1")
    faint = min(value for _, value, _, _ in read(draw(ink=(120, 120, 124)), words))
    expect("faint words", 2.5 < faint < 4.5, f"{faint:.1f} : 1")
    patchy = [value for _, value, _, _ in read(draw(ground=(120, 120, 124), ink=(255, 255, 255), glass=45), words)]
    expect("words on glass are judged where they are worst", min(patchy) < 3 < max(patchy), f"{min(patchy):.1f} to {max(patchy):.1f} : 1")
    expect("words that keep their distance", fits(good, panel) == (14.0, 22.0, 17.0, 22.0), fits(good, panel))
    tight = fits(draw(margin=3), panel)
    expect("words that nearly touch a side", tight[0] == 3, tight)
    lined = fits(draw(margin=3, outline=(255, 255, 255)), panel)
    expect("an outline is no word", lined[0] == 3 and lined[1] == 22, lined)
    expect("round corners are no words", fits(draw(margin=34, radius=30), panel) == (34.0, 22.0, 39.0, 22.0), fits(draw(margin=34, radius=30), panel))
    expect("no words, no verdict", fits(draw(ink=(40, 40, 44)), panel) is None, "none")
    sharp = edge(good, panel, "top")
    expect("a crisp side", sharp["between"] == 0 and not sharp["half"], sharp)
    soft = edge(draw(blur=1.6), panel, "top")
    expect("a soft side", soft["between"] > 1, soft)
    off = edge(draw(offset=0.5), panel, "top")
    expect("a side off the pixel grid", off["half"], off)
    expect("a short side is not asked", edge(good, (100, 100, 300, 60), "right") is None, "none")
    plain = edge(draw(ground=(250, 70, 60)), panel, "top")
    lined = edge(draw(ground=(250, 70, 60), outline=(255, 255, 255)), panel, "top")
    expect("an outline stands out", plain["outline"] < 1.5 and lined["outline"] >= 3, f"{plain['outline']} without, {lined['outline']} with")
    expect("a flat ground", flat(good, (104, 104, 292, 52)) <= 2, flat(good, (104, 104, 292, 52)))
    expect("a ground that lets things through", flat(draw(glass=12), (104, 104, 292, 52)) > 2, flat(draw(glass=12), (104, 104, 292, 52)))
    expect("where two pictures differ", differs(good, draw(ground=(255, 59, 48), ink=(255, 59, 48))) == [panel], differs(good, draw(ground=(255, 59, 48), ink=(255, 59, 48))))
    print(f"{16 - len(failures)} of 16 drawn pictures measured as they should be")
    return 1 if failures else 0


def main(arguments):
    if not arguments or arguments[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    command = arguments.pop(0)
    if command == "--self-test":
        return self_test()
    options = {}
    for name in ("--zoom", "--scale", "--reach"):
        if name in arguments:
            place = arguments.index(name)
            options[name] = float(arguments[place + 1])
            del arguments[place:place + 2]
    image = picture(arguments[0])
    if command == "crop":
        x, y, w, h = box_of(arguments[1])
        zoom = int(options.get("--zoom", 4))
        Image.open(arguments[0]).convert("RGB").crop((x, y, x + w, y + h)).resize((w * zoom, h * zoom), Image.NEAREST).save(arguments[2])
        print(f"{w * zoom} x {h * zoom} in {arguments[2]}")
        return 0
    if command == "differs":
        for box in differs(image, picture(arguments[1])):
            print(",".join(map(str, box)))
        return 0
    if command == "read":
        strips = read(image, box_of(arguments[1]))
        if not strips:
            print("no ink in that box")
            return 1
        for x, value, ink, ground in strips:
            print(f"  x {x}: {value:.2f} : 1, ink {tuple(int(v) for v in ink)} on {tuple(int(v) for v in ground)}")
        values = [value for _, value, _, _ in strips]
        print(f"worst {min(values):.2f} : 1, middle {float(np.median(values)):.2f} : 1, best {max(values):.2f} : 1, over {len(values)} strips")
        return 0
    if command == "fits":
        said = fits(image, box_of(arguments[1]), options.get("--scale", 1))
        print("no ink in that box" if said is None else "ink keeps %s pt from the left, %s from the top, %s from the right, %s from the bottom" % said)
        return 0
    if command == "edges":
        for side in ("left", "top", "right", "bottom"):
            said = edge(image, box_of(arguments[1]), side, int(options.get("--reach", 5)))
            print(f"  {side}: " + ("under 60 px of straight side: not asked" if said is None else
                                   f"a step of {said['step']} levels" + (f" over {said['between']} pixels between" if said["between"] is not None else ": too small to ask S1")
                                   + ("; ONE ROW HALF-WAY: off the pixel grid?" if said["half"] else "") + f"; on the way, at most {said['outline']} : 1 to what is outside"))
        return 0
    if command == "flat":
        print(f"the ground varies by {flat(image, box_of(arguments[1])):.1f} levels")
        return 0
    print(__doc__)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
