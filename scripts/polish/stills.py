#!/usr/bin/env python3
"""The ruler for pictures at rest: what docs/POLISH.md asks of a panel in S1 to S7, measured in a picture of the real app.

A picture does not say where in it a panel is or which of its marks are words. Somebody with eyes does: a reviewer looks, names the rectangle,
and this measures inside it. So the number is a script's and the judgement of what it is a number of is a reviewer's.
Rectangles are x,y,w,h in the picture's own pixels, origin top-left.

  stills.py crop <png> <box> <out.png> [--zoom n]   that part of the picture, enlarged without smoothing (4), to look at
  stills.py differs <png> <png>                     the boxes in which two pictures of the same size differ: where something came or went
  stills.py read <png> <box>                        S4, S6: the contrast of ink to ground (WCAG) in a box drawn closely round ONE line of words, strip by strip
  stills.py fits <png> <panel's box> [--scale n] [--radius pt]
                                                    S3: how far the ink keeps from the panel's edges, in points. A line from side to side, or a filled row, is ink to it: measure part by part
  stills.py edges <png> <panel's box> [--reach n]   S1, S2, S6: across each straight side, from n (5) pixels outside to n inside: how many pixels the step takes, and the
                                                    contrast to what is outside of the line at the side and of the ground. A soft shadow outside, or a mark of the panel's own within reach, is counted in: look, and shorten the reach
  stills.py flat <png> <box>                        S7: how much a ground varies, the ink left out, and how much was left out
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
    area = image[max(y, 0):y + h, max(x, 0):x + w]
    if not area.size:
        raise SystemExit(f"stills.py: {x},{y},{w},{h} lies outside the picture, which is {image.shape[1]} by {image.shape[0]}")
    return area


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
    """[(x, contrast, ink, ground)] for every strip of the box that has ink in it. The ground is taken column by column, as the median of the fifteen columns round each: so it
    follows what shines through glass, and where something behind the glass ends it changes where that ends. The ink is what lies nearly as far from its ground as the strip's
    farthest pixel does: the cores of the strokes, without their soft edges. A strip with fewer than six such pixels (a full stop, the tail of a letter) says nothing. In a strip
    of thin letters no pixel has the words' colour; the strips beside it are the same words, so each strip is also tried with its neighbours' ink, and the best counts.
    Tried on 1,800 lines of words drawn in known colours, 10 to 15 px high: the worst strip reads 2% low in the middle, and no more than 4% low in 19 lines of 20."""
    area, strips = part(image, box), []
    width = area.shape[1]
    grounds = np.array([np.median(area[:, max(column - 7, 0):column + 8].reshape(-1, 3), axis=0) for column in range(width)])
    distances = np.abs(area - grounds[None, :, :]).max(axis=2)
    for left in range(0, width, STRIP):
        # What is left over at the end goes with the last strip.
        if width - left < STRIP // 2 and left:
            continue
        right = width if width - left - STRIP < STRIP // 2 else left + STRIP
        distance = distances[:, left:right]
        if distance.max() < 25:
            continue
        rows, columns = np.where(distance >= 0.94 * distance.max())
        # Words are lighter than their ground or darker, not both. What is on the other side is a second ground at the strip's end, too narrow for the median to follow.
        lighter = area[rows, columns + left].sum(axis=1) > grounds[columns + left].sum(axis=1)
        keep = lighter if lighter.sum() * 2 >= len(rows) else ~lighter
        rows, columns = rows[keep], columns[keep]
        if len(rows) < 6:
            continue
        strips.append((left, area[rows, columns + left].mean(axis=0), grounds[columns + left].mean(axis=0)))
    found = []
    for left, _, ground in strips:
        value, ink = max(((contrast(ink, ground), ink) for other, ink, _ in strips if abs(other - left) <= STRIP), key=lambda pair: pair[0])
        found.append((box[0] + left, value, ink, ground))
    return found


def depth(height, width, radius):
    """(how many pixels each pixel of a box lies within a rectangle with round corners that fills it, below nought outside the corners; which pixels are in a corner)."""
    rows, columns = np.ogrid[:height, :width]
    down = np.maximum(np.maximum(radius - 0.5 - rows, rows - (height - 0.5 - radius)), 0)
    across = np.maximum(np.maximum(radius - 0.5 - columns, columns - (width - 0.5 - radius)), 0)
    straight = np.minimum(np.minimum(rows, height - 1 - rows), np.minimum(columns, width - 1 - columns)) + 0.5
    return np.where((down > 0) & (across > 0), radius - np.sqrt(down**2 + across**2), straight), (down > 0) & (across > 0)


def fits(image, box, scale=1, radius=None):
    """(left, top, right, bottom) in points between the panel's edges and its ink, or None without ink. What shows outside round corners is not the panel's, and a line that
    runs all the way round is its outline, not a word. The corners are taken for as round as can be, up to 32 points: that gives away a sliver in each and no more."""
    area = part(image, box)
    height, width = area.shape[:2]
    inner = area[height // 4:-(height // 4) or None]
    marks = away(area, ground_of(inner)) >= INK
    within, corners = depth(height, width, min(height / 2, width / 2, (32 if radius is None else radius) * scale))
    marks[within < 1] = False
    # Ring by ring from the outside, for as long as most of a ring is marked. Words that touch a side mark a little of it.
    ring = 1
    while ring <= 4 * scale:
        here = (within >= ring) & (within < ring + 1)
        if not here.any() or marks[here].mean() < 0.6:
            break
        marks[here] = False
        ring += 1
    # Round a bend a line of one pixel takes two.
    marks[corners & (within < ring + 1.5)] = False
    if not marks.any():
        return None
    rows, columns = np.where(marks.any(axis=1))[0], np.where(marks.any(axis=0))[0]
    return tuple(round(float(value) / scale, 1) for value in (columns[0], rows[0], width - 1 - columns[-1], height - 1 - rows[-1]))


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
    """Of one side: {"step": levels between outside and inside, "between": pixels from 10% to 90% of that step, "half": whether one row is about half-way, as a side off the
    pixel grid is, "outline": the contrast to what is outside of the line at the side, None if there is none, "ground": that of the panel's ground}. None under 60 px of side."""
    reach = max(reach, 3)
    if (box[3] if side in ("left", "right") else box[2]) < 60:
        return None
    lines = profiles(image, box, side, reach)
    line = np.median(lines, axis=0)
    outside, inside = line[:2].mean(axis=0), line[-2:].mean(axis=0)
    channel = int(np.abs(inside - outside).argmax())
    step = float(inside[channel] - outside[channel])
    # The box's first pixel is number `reach` of the line. A line of the panel's own is what one meets there, coming from outside, that is neither the outside nor yet the ground.
    own = [pixel for pixel in line[reach - 1:reach + 3] if np.abs(pixel - outside).max() > 10 and np.abs(pixel - inside).max() > 10]
    said = {"step": round(abs(step)), "between": None, "half": False, "ground": round(contrast(inside, outside), 2),
            "outline": round(max(contrast(pixel, outside) for pixel in own), 2) if own else None}
    if abs(step) >= INK:
        share = (line[:, channel] - outside[channel]) / step
        middle = (share > 0.1) & (share < 0.9)
        said["between"] = int(middle.sum())
        said["half"] = bool(((share > 0.3) & (share < 0.7)).sum() == 1 and middle.sum() == 1)
    return said


def flat(image, box):
    """(how far the ground's pixels lie apart, in levels: from the 1st to the 99th in a hundred of the channel that varies most, ink left out; the share that was left out as ink).
    A ground that lets strong colours through has parts as far from its middle as ink is: where much is left out, the first number says nothing."""
    area = part(image, box)
    inked = away(area, ground_of(area)).ravel() >= INK
    low, high = np.percentile(area.reshape(-1, 3)[~inked], [1, 99], axis=0)
    return float((high - low).max()), float(inked.mean())


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


def draw(ground=(40, 40, 44), ink=(235, 235, 235), behind=(255, 59, 48), margin=14, blur=0.0, offset=0.0, outline=None, glass=0, radius=0, tall=60, line=1):
    """A panel of 300 by 60 at 100,100 on a strong colour, with a line of strokes for words."""
    scale = 4
    large = Image.new("RGB", (500 * scale, (200 + tall) * scale), behind)
    pen = ImageDraw.Draw(large)
    x, y = (100 + offset) * scale, (100 + offset) * scale
    pen.rounded_rectangle([x, y, x + 300 * scale - 1, y + tall * scale - 1], radius * scale, fill=ground, outline=outline, width=line * scale if outline else 0)
    if glass:
        for column in range(0, 300, 50):
            tone = tuple(int(value + glass * (1 if column % 100 else -1)) for value in ground)
            pen.rectangle([x + column * scale, y + 2 * scale, x + (column + 50) * scale - 1, y + (tall - 2) * scale - 1], fill=tone)
    for stroke in range(100 + margin, 400 - margin - 3, 7):
        pen.rectangle([(stroke + offset) * scale, (122 + offset) * scale, (stroke + 3 + offset) * scale - 1, (138 + offset) * scale - 1], fill=ink)
    small = large.resize((500, 200 + tall), Image.BOX)
    if blur:
        small = small.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(small).astype(np.float64)


def self_test():
    panel, words, sides = (100, 100, 300, 60), (110, 118, 280, 24), ("left", "top", "right", "bottom")
    results = []

    def expect(name, holds, said):
        print(f"{'✔' if holds else '✘'} {name}: {said}")
        results.append(bool(holds))

    def worst(image, box=words):
        return min(value for _, value, _, _ in read(image, box))

    white, grey = (255, 255, 255), (118, 118, 118)
    expect("contrast is WCAG's", abs(contrast((0, 0, 0), white) - 21) < 0.01 and abs(contrast(grey, white) - 4.54) < 0.01 and abs(contrast((255, 0, 0), white) - 4.0) < 0.01,
           f"on white: black {contrast((0, 0, 0), white):.2f}, 118 grey {contrast(grey, white):.2f}, red {contrast((255, 0, 0), white):.2f}")
    good = draw()
    true = contrast((235, 235, 235), (40, 40, 44))
    expect("words that can be read", abs(worst(good) - true) < 0.1, f"{worst(good):.1f} : 1")
    expect("faint words", abs(worst(draw(ink=(120, 120, 124))) - contrast((120, 120, 124), (40, 40, 44))) < 0.1, f"{worst(draw(ink=(120, 120, 124))):.1f} : 1")
    soft = good.copy()
    for stroke in range(114, 383, 7):
        soft[122:138, [stroke - 1, stroke + 3]] = (np.array((235, 235, 235)) + np.array((40, 40, 44))) / 2
    expect("soft edges are not the ink", abs(worst(soft, (110, 110, 280, 40)) - true) < 0.1, f"{worst(soft, (110, 110, 280, 40)):.1f} : 1")
    stop = draw(margin=40)
    stop[136:138, 380:382] = (110, 110, 112)
    expect("a full stop says nothing about the words", abs(worst(stop, (134, 118, 264, 24)) - true) < 0.1 and not read(stop, (374, 118, 24, 24)), f"{worst(stop, (134, 118, 264, 24)):.1f} : 1")
    patchy = [value for _, value, _, _ in read(draw(ground=(120, 120, 124), ink=white, glass=45), words)]
    expect("words on glass are judged strip by strip, each on its own ground",
           abs(min(patchy) - contrast(white, (165, 165, 169))) < 0.15 and abs(max(patchy) - contrast(white, (75, 75, 79))) < 0.4, f"{min(patchy):.1f} to {max(patchy):.1f} : 1")
    ends = read(draw(ground=(120, 120, 124), ink=white, glass=45), (278, 118, 24, 24))
    expect("a second ground at a strip's end is not ink", len(ends) == 1 and abs(ends[0][1] - contrast(white, (165, 165, 169))) < 0.15, f"{ends[0][1]:.1f} : 1")
    thin = good.copy()
    thin[122:138, 206:230] = np.where((thin[122:138, 206:230] > 100).all(axis=2, keepdims=True), (150, 150, 152), thin[122:138, 206:230])
    expect("thin letters among others are the same words", abs(worst(thin) - true) < 0.1, f"{worst(thin):.1f} : 1")
    expect("one digit can be read", len(read(good, (114, 118, 10, 24))) == 1, read(good, (114, 118, 10, 24))[0][1])

    expect("words that keep their distance", fits(good, panel) == (14.0, 22.0, 17.0, 22.0), fits(good, panel))
    expect("at two pixels to the point", fits(good, panel, 2) == (7.0, 11.0, 8.5, 11.0), fits(good, panel, 2))
    expect("words that nearly touch a side", fits(draw(margin=3), panel)[0] == 3, fits(draw(margin=3), panel))
    expect("a first letter at the very side", fits(draw(margin=1), panel)[0] <= 3, fits(draw(margin=1), panel))
    expect("an outline is no word", fits(draw(margin=3, outline=white), panel)[:2] == (3.0, 22.0), fits(draw(margin=3, outline=white), panel))
    expect("nor is one of two pixels", fits(draw(margin=8, outline=white, line=2), panel)[:2] == (8.0, 22.0), fits(draw(margin=8, outline=white, line=2), panel))
    expect("round corners are no words", fits(draw(margin=34, radius=30), panel) == (34.0, 22.0, 39.0, 22.0), fits(draw(margin=34, radius=30), panel))
    expect("words near a capsule's end", fits(draw(margin=4, radius=30, outline=white), panel)[0] == 4, fits(draw(margin=4, radius=30, outline=white), panel))
    high = draw(tall=200, radius=20)
    expect("words in a tall panel's upper part", fits(draw(tall=200, radius=20, margin=2), (100, 100, 300, 200))[0] == 2, fits(draw(tall=200, radius=20, margin=2), (100, 100, 300, 200)))
    expect("no words, no verdict", fits(draw(ink=(40, 40, 44)), panel) is None, "none")

    large = (100, 100, 300, 200)
    crisp = [edge(high, large, side) for side in sides]
    expect("four crisp sides", all(said["between"] == 0 and not said["half"] for said in crisp), [said["between"] for said in crisp])
    off = [edge(draw(tall=200, offset=0.5), large, side) for side in sides]
    expect("four sides off the pixel grid", all(said["half"] for said in off), [said["half"] for said in off])
    ramp = draw(tall=200)
    for column, share in enumerate((0.2, 0.5, 0.8)):
        ramp[100:300, 100 + column] = np.array((255, 59, 48)) * (1 - share) + np.array((40, 40, 44)) * share
    expect("a side that takes three pixels", edge(ramp, large, "left")["between"] == 3, edge(ramp, large, "left"))
    expect("a side of 59 px is not asked, one of 60 is", edge(good, (100, 100, 300, 59), "left") is None and edge(good, panel, "left") is not None, "so")
    lined = [edge(draw(tall=200, behind=white, outline=(120, 120, 124)), large, side) for side in sides]
    expect("an outline is held against what is outside, on every side", all(abs(said["outline"] - contrast((120, 120, 124), white)) < 0.1 for said in lined), [said["outline"] for said in lined])
    bare = edge(draw(tall=200, ground=(250, 70, 60)), large, "top")
    far = draw(tall=200, ground=(250, 70, 60))
    far[103:104, 100:400] = white
    expect("a ground, or a mark further in, is no outline", bare["outline"] is None and edge(far, large, "top")["outline"] is None and crisp[0]["outline"] is None,
           f"{bare['outline']}, {edge(far, large, 'top')['outline']}, {crisp[0]['outline']}")

    inside = (104, 104, 292, 52)
    expect("a flat ground", flat(good, inside)[0] <= 2 and flat(good, inside)[1] < 0.25, flat(good, inside))
    expect("a ground that lets a little through", flat(draw(glass=12), inside)[0] > 2, flat(draw(glass=12), inside))
    expect("a ground that lets much through is not taken for ink", flat(draw(glass=45), inside)[1] > 0.25, flat(draw(glass=45), inside))
    spot = draw(ink=(40, 40, 44))
    spot[110:122, 110:160] += (40, 0, 0)
    expect("a spot on a twenty-fifth of the ground", flat(spot, inside)[0] >= 30, flat(spot, inside))
    gone = draw(ground=(255, 59, 48), ink=(255, 59, 48))
    expect("where two pictures differ", differs(good, gone) == [panel], differs(good, gone))
    print(f"{sum(results)} of {len(results)} drawn pictures measured as they should be")
    return 0 if all(results) else 1


def main(arguments):
    if not arguments or arguments[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    command = arguments.pop(0)
    if command == "--self-test":
        return self_test()
    options = {}
    for name in ("--zoom", "--scale", "--reach", "--radius"):
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
        print(f"worst {min(values):.2f} : 1, middle {float(np.median(values)):.2f} : 1, best {max(values):.2f} : 1, over {len(values)} strips."
              f" The ruler may read up to 4% low: the worst is at most {min(values) / 0.96:.2f}")
        return 0
    if command == "fits":
        said = fits(image, box_of(arguments[1]), options.get("--scale", 1), options.get("--radius"))
        print("no ink in that box" if said is None else "ink keeps %s pt from the left, %s from the top, %s from the right, %s from the bottom" % said)
        return 0
    if command == "edges":
        for side in ("left", "top", "right", "bottom"):
            said = edge(image, box_of(arguments[1]), side, int(options.get("--reach", 5)))
            print(f"  {side}: " + ("under 60 px of straight side: not asked" if said is None else
                                   f"a step of {said['step']} levels" + (f" over {said['between']} pixels between" if said["between"] is not None else ": too small to ask S1")
                                   + ("; ONE ROW HALF-WAY: off the pixel grid?" if said["half"] else "")
                                   + "; to what is outside: " + (f"the line at the side {said['outline']} : 1" if said["outline"] else "no line of its own at the side")
                                   + f", the ground {said['ground']} : 1"))
        return 0
    if command == "flat":
        varies, inked = flat(image, box_of(arguments[1]))
        print(f"the ground varies by {varies:.1f} levels; {inked:.0%} of the box was left out as ink"
              + (": TOO MUCH FOR WORDS. The ground itself is in several colours, or the box holds more than ground: look, and give boxes without words" if inked > 0.25 else ""))
        return 0
    print(__doc__)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
