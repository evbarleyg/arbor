#!/usr/bin/env python3
"""Answers questions about Arbor's state and the real windows for Mac shell scripts (scripts/mac-shell/lib.sh).

Reads on stdin the reply of `arborctl state` (one line of JSON) and, after it, what `pointer windows` prints: the
window server's own list, `id pid layer x y w h on|off owner`. Questions about where a window IS are
answered from the window server's list, so that they check what Arbor did and not what it believes.

Printing something:
  state.py json                 the state object, indented
  state.py summary              a few readable lines: the camera, every window, tiles, the Desktop
  state.py frame <window>       x y w h: where Arbor last saw the window
  state.py shown <window>       the same, but fails when the window is out of view: there is nothing to aim at
  state.py slot <window>        x y w h: where the layout puts the window (fails when it has no slot)
  state.py tile <window>        x y w h: the tile that stands in for the window (fails when there is none)
  state.py desktop [n]          x y w h: the Desktop's part of display n's layout (fails when it is out of view)
  state.py screen [n]           x y w h: display n's visible frame (displays count from 1, the main one first)
  state.py display-frame [n]    x y w h: all of display n
  state.py display-id [n]       display n's identifier
  state.py displays             how many displays Arbor arranges
  state.py display <window>     the number of the display whose workspace holds the window

Yes or no: exit code 0 or 1, and on 1 a line that says why.
  state.py is <window> <what>   docked floating parked managed minimized hidden fullScreen pinned tile focused known
  state.py at_edge <window> <edge>          it reaches that edge of the screen, a gap away
  state.py fills <window>                   it fills the screen, a gap away from every edge
  state.py in_slot <window>                 it is where the layout puts it
  state.py frame_is <window> x y w h
  state.py corner_is <window> x y           its top-left corner
  state.py left_of <a> <b> | above <a> <b>
  state.py same_column <a> <b> | same_row <a> <b>     same left edge and width | same top edge and height
  state.py desktop_between <a> <b>          the Desktop's part of the layout lies between the two, left to right
  state.py camera_on root|desktop|<window>  what the camera frames
  state.py can back|forward
  state.py depth_is <window> <n>            how many spaces its slot is nested in (1: a child of the root split)
  state.py count docked|floating|managed|tiles|windows|parked <n>
  state.py tile_is <window> window|group    the kind of the tile that stands in for it
  state.py tile_shown <window>              a window of Arbor's own (ARBOR_PID) is on screen where that tile should be
  state.py no_overlaps                      no two docked windows or tiles in view overlap
  state.py layout_matches                   every docked window in view is where the layout puts it
  state.py ready <count>        exit code 0 when Arbor runs and manages that many windows, 3 when it lacks
                                Accessibility permission, otherwise 1

Numbers are rounded to whole points, so that shell arithmetic can use them. Comparisons allow 3 points.
Where a window is compared with the screen or with another, it has to be in view: parked in the corner, every
window is right of and below every other.
The gap comes from the environment (ARBOR_GAP, default 12).
"""

import json
import os
import sys

TOLERANCE = 3
GAP = float(os.environ.get("ARBOR_GAP") or 12)


def rect(value):
    """A CGRect is encoded as [[x, y], [width, height]]."""
    (x, y), (width, height) = value
    return [x, y, width, height]


def words(numbers):
    return " ".join(str(round(number)) for number in numbers)


def fail(message):
    print(f"state.py: {message}", file=sys.stderr)
    sys.exit(1)


def window_id(word):
    try:
        return int(word.lstrip("w"))
    except ValueError:
        fail(f"expected a window id, got {word}")


def close(a, b, tolerance=TOLERANCE):
    return abs(a - b) <= tolerance


def same(a, b, tolerance=TOLERANCE):
    return all(close(x, y, tolerance) for x, y in zip(a, b))


class World:
    """Arbor's state and the window server's list."""

    def __init__(self, text):
        lines = text.splitlines()
        try:
            self.state = json.loads(lines[0])["state"]
            rest = lines[1:]
        except (ValueError, KeyError, IndexError):
            try:
                # The state alone, however it is laid out.
                self.state = json.loads(text)["state"]
                rest = []
            except (ValueError, KeyError):
                fail("no state on stdin; is Arbor running?")
        if not self.state:
            fail("the reply has no state; is Arbor running?")
        self.real = {}
        for line in rest:
            fields = line.split()
            if len(fields) < 8 or not fields[0].isdigit():
                continue
            self.real[int(fields[0])] = {
                "pid": int(fields[1]), "layer": int(fields[2]), "frame": [float(word) for word in fields[3:7]],
                "on": fields[7] == "on",
            }

    # Arbor's view

    def window(self, wanted):
        for window in self.state["windows"]:
            if window["id"] == wanted:
                return window
        return None

    def known(self, wanted):
        window = self.window(wanted)
        if not window:
            fail(f"Arbor knows no window {wanted}")
        return window

    def display(self):
        return self.state["displays"][0]

    def display_of(self, wanted):
        """The display whose tree or floating list holds the window, else the first."""
        for display in self.state["displays"]:
            if wanted in display["floating"] or self.leaf(display, wanted) is not None:
                return display
        return self.display()

    def visible(self, display=None):
        return rect((display or self.display())["visibleFrame"])

    def slot(self, wanted):
        for display in self.state["displays"]:
            slot = display["windowFrames"].get(str(wanted))
            if slot:
                return rect(slot)
        return None

    def tile(self, wanted):
        for display in self.state["displays"]:
            for tile in display["tiles"]:
                if wanted in tile["windows"]:
                    return tile
        return None

    @staticmethod
    def leaf(display, wanted):
        for key, node in display["tree"]["nodes"].items():
            stack = node["kind"].get("stack")
            if stack and wanted in stack["windows"]:
                return int(key)
        return None

    @staticmethod
    def depth(display, node):
        depth = 0
        parent = display["tree"]["nodes"][str(node)].get("parent")
        while parent is not None:
            depth += 1
            parent = display["tree"]["nodes"][str(parent)].get("parent")
        return depth

    # The window server's view

    def frame(self, wanted):
        entry = self.real.get(wanted)
        if entry:
            return entry["frame"]
        if self.real:
            fail(f"the window server has no window {wanted}")
        # Without the window server's list, Arbor's word is all there is.
        return rect(self.known(wanted)["frame"])

    def share_in_view(self, wanted):
        """How much of the window is on a display, 0 to 1; nothing when the window server does not show it."""
        entry = self.real.get(wanted)
        if entry and not entry["on"]:
            return 0
        x, y, width, height = self.frame(wanted)
        best = 0
        for display in self.state["displays"]:
            dx, dy, dwidth, dheight = rect(display["frame"])
            across = min(x + width, dx + dwidth) - max(x, dx)
            down = min(y + height, dy + dheight) - max(y, dy)
            if across > 0 and down > 0 and width * height > 0:
                best = max(best, across * down / (width * height))
        return best

    def seen(self, wanted):
        """The window's frame, for comparing it with the screen or another window."""
        frame = self.frame(wanted)
        if self.share_in_view(wanted) < 0.9:
            print(f"window {wanted} is out of view, at {words(frame)}")
            sys.exit(1)
        return frame


def display_number(state, identifier):
    for number, display in enumerate(state["displays"], start=1):
        if display["id"] == identifier:
            return number
    return None


def nth_display(state, arguments):
    try:
        number = int(arguments[0]) if arguments else 1
    except ValueError:
        fail(f"expected a display number, got {arguments[0]}")
    if not 1 <= number <= len(state["displays"]):
        fail(f"there is no display {number}; Arbor arranges {len(state['displays'])}")
    return state["displays"][number - 1]


def summary(world):
    state = world.state
    lines = []
    several = len(state["displays"]) > 1
    for number, display in enumerate(state["displays"], start=1):
        lines.append(
            f"display {number if several else ''} {words(rect(display['frame']))}, ".replace("  ", " ")
            + f"visible {words(rect(display['visibleFrame']))}, "
            f"camera n{display['camera']}, back {'yes' if display['canGoBack'] else 'no'}"
        )
        if display.get("desktopFrame"):
            lines.append(f"  Desktop          {words(rect(display['desktopFrame']))}")
        for tile in display["tiles"]:
            inside = " ".join(f"w{window}" for window in tile["windows"]) or "-"
            lines.append(f"  tile n{tile['node']} {tile['kind']:<8} {words(rect(tile['frame']))}  holds {inside}")
    for window in state["windows"]:
        traits = [name for name in ("docked", "parked", "minimized", "hidden", "fullScreen", "pinned") if window.get(name)]
        if not window["docked"]:
            traits.insert(0, "floating" if window["managed"] else "not managed")
        if state.get("focused") == window["id"]:
            traits.append("focused")
        if several:
            traits.insert(0, f"display {display_number(state, window.get('display')) or '-'},")
        line = f"  w{window['id']} {words(rect(window['frame'])):<20} {' '.join(traits)}"
        real = world.real.get(window["id"])
        if real and not same(real["frame"], rect(window["frame"]), 1):
            line += f"  (the window server: {words(real['frame'])})"
        lines.append(line)
    return "\n".join(lines)


def is_what(world, wanted, what):
    if what == "known":
        return world.window(wanted) is not None, f"Arbor knows no window {wanted}"
    window = world.known(wanted)
    if what == "floating":
        answer = window["managed"] and not window["docked"]
    elif what == "tile":
        answer = world.tile(wanted) is not None
    elif what == "focused":
        return world.state.get("focused") == wanted, f"the focused window is {world.state.get('focused')}"
    elif what in ("docked", "parked", "managed", "minimized", "hidden", "fullScreen", "pinned"):
        answer = window.get(what, False)
    else:
        fail(f"cannot tell whether a window is `{what}`")
    traits = [name for name in ("managed", "docked", "parked", "minimized", "hidden") if window[name]]
    return answer, f"it is {' '.join(traits) or 'not managed'} at {words(rect(window['frame']))}"


def at_edge(world, wanted, edge):
    x, y, width, height = world.seen(wanted)
    vx, vy, vwidth, vheight = world.visible(world.display_of(wanted))
    pairs = {
        "left": (x, vx + GAP), "right": (x + width, vx + vwidth - GAP),
        "top": (y, vy + GAP), "up": (y, vy + GAP),
        "bottom": (y + height, vy + vheight - GAP), "down": (y + height, vy + vheight - GAP),
    }
    if edge not in pairs:
        fail(f"expected left, right, top or bottom, got {edge}")
    actual, expected = pairs[edge]
    return close(actual, expected), f"its {edge} edge is at {round(actual)}, not {round(expected)}: {words([x, y, width, height])}"


def fills(world, wanted):
    vx, vy, vwidth, vheight = world.visible(world.display_of(wanted))
    expected = [vx + GAP, vy + GAP, vwidth - 2 * GAP, vheight - 2 * GAP]
    actual = world.frame(wanted)
    return same(actual, expected), f"it is at {words(actual)}, not {words(expected)}"


def in_slot(world, wanted):
    slot = world.slot(wanted)
    if not slot:
        return False, "the layout has no slot for it in view"
    actual = world.frame(wanted)
    return same(actual, slot), f"it is at {words(actual)}, its slot at {words(slot)}"


def camera_on(world, what):
    if what in ("root", "desktop"):
        display = world.display()
        expected = display["tree"][what]
    else:
        wanted = window_id(what)
        display = world.display_of(wanted)
        expected = world.leaf(display, wanted)
        if expected is None:
            return False, f"window {wanted} is not docked"
    return display["camera"] == expected, f"the camera is on n{display['camera']}, not n{expected}"


def count(world, what, expected):
    windows = world.state["windows"]
    if what == "docked":
        actual = sum(1 for window in windows if window["docked"])
    elif what == "floating":
        actual = sum(1 for window in windows if window["managed"] and not window["docked"])
    elif what == "managed":
        actual = sum(1 for window in windows if window["managed"])
    elif what == "parked":
        actual = sum(1 for window in windows if window["parked"])
    elif what == "windows":
        actual = len(windows)
    elif what == "tiles":
        actual = sum(len(display["tiles"]) for display in world.state["displays"])
    else:
        fail(f"cannot count `{what}`")
    return actual == expected, f"{actual} {what}, not {expected}"


def no_overlaps(world):
    boxes = []
    for display in world.state["displays"]:
        for key in display["windowFrames"]:
            boxes.append((f"w{key}", world.frame(int(key))))
        for tile in display["tiles"]:
            boxes.append((f"tile n{tile['node']}", rect(tile["frame"])))
    for index, (name, a) in enumerate(boxes):
        for other, b in boxes[index + 1:]:
            across = min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])
            down = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
            if across > 2 and down > 2:
                return False, f"{name} at {words(a)} overlaps {other} at {words(b)}"
    return True, ""


def layout_matches(world):
    wrong = []
    for display in world.state["displays"]:
        for key, slot in sorted(display["windowFrames"].items()):
            actual = world.frame(int(key))
            if not same(actual, rect(slot)):
                wrong.append(f"w{key} expected {words(rect(slot))} actual {words(actual)}")
    return not wrong, "; ".join(wrong)


def predicate(world, query, arguments):
    """Returns (holds, why not), or None when `query` is no predicate."""

    def ids(number):
        if len(arguments) < number:
            fail(f"{query} takes {number} window ids")
        return [window_id(word) for word in arguments[:number]]

    if query == "is" and len(arguments) >= 2:
        return is_what(world, window_id(arguments[0]), arguments[1])
    if query == "at_edge" and len(arguments) >= 2:
        return at_edge(world, window_id(arguments[0]), arguments[1])
    if query == "fills":
        return fills(world, *ids(1))
    if query == "in_slot":
        return in_slot(world, *ids(1))
    if query == "frame_is" and len(arguments) >= 5:
        actual = world.frame(window_id(arguments[0]))
        expected = [float(word) for word in arguments[1:5]]
        return same(actual, expected), f"it is at {words(actual)}, not {words(expected)}"
    if query == "corner_is" and len(arguments) >= 3:
        actual = world.frame(window_id(arguments[0]))[:2]
        expected = [float(word) for word in arguments[1:3]]
        return same(actual, expected), f"its corner is at {words(actual)}, not {words(expected)}"
    if query in ("left_of", "above", "same_column", "same_row", "desktop_between"):
        first, second = (world.seen(window) for window in ids(2))
        where = f"the first is at {words(first)}, the second at {words(second)}"
        if query == "left_of":
            return first[0] + first[2] <= second[0] + TOLERANCE, where
        if query == "above":
            return first[1] + first[3] <= second[1] + TOLERANCE, where
        if query == "same_column":
            return close(first[0], second[0]) and close(first[2], second[2]), where
        if query == "same_row":
            return close(first[1], second[1]) and close(first[3], second[3]), where
        desktop = world.display().get("desktopFrame")
        if not desktop:
            return False, "the Desktop is out of view"
        x, _, width, _ = rect(desktop)
        return first[0] + first[2] < x and x + width < second[0], f"the Desktop is at {words(rect(desktop))}; {where}"
    if query == "camera_on" and arguments:
        return camera_on(world, arguments[0])
    if query == "can" and arguments and arguments[0] in ("back", "forward"):
        key = "canGoBack" if arguments[0] == "back" else "canGoForward"
        return world.display()[key], f"there is nothing to go {arguments[0]} to"
    if query == "depth_is" and len(arguments) >= 2:
        wanted = window_id(arguments[0])
        display = world.display_of(wanted)
        leaf = world.leaf(display, wanted)
        if leaf is None:
            return False, f"window {wanted} is not docked"
        depth = world.depth(display, leaf)
        return depth == int(arguments[1]), f"it is nested {depth} deep, not {arguments[1]}"
    if query == "count" and len(arguments) >= 2:
        return count(world, arguments[0], int(arguments[1]))
    if query in ("tile_is", "tile_shown") and arguments:
        tile = world.tile(window_id(arguments[0]))
        if not tile:
            return False, "no tile stands in for it"
        if query == "tile_is":
            return len(arguments) > 1 and tile["kind"] == arguments[1], f"its tile is a {tile['kind']} tile"
        own = [entry["frame"] for entry in world.real.values()
               if str(entry["pid"]) == os.environ.get("ARBOR_PID") and entry["on"] and entry["layer"] == 0]
        shown = any(same(frame, rect(tile["frame"])) for frame in own)
        return shown, f"the tile should be at {words(rect(tile['frame']))}; Arbor's windows: {[words(f) for f in own]}"
    if query == "no_overlaps":
        return no_overlaps(world)
    if query == "layout_matches":
        return layout_matches(world)
    return None


def main():
    arguments = sys.argv[1:]
    if not arguments:
        fail(__doc__)
    world = World(sys.stdin.read())
    state = world.state
    query, arguments = arguments[0], arguments[1:]

    if query == "json":
        print(json.dumps(state, indent=1, sort_keys=True))
    elif query == "summary":
        print(summary(world))
    elif query == "screen":
        print(words(rect(nth_display(state, arguments)["visibleFrame"])))
    elif query == "display-frame":
        print(words(rect(nth_display(state, arguments)["frame"])))
    elif query == "display-id":
        print(nth_display(state, arguments)["id"])
    elif query == "displays":
        print(len(state["displays"]))
    elif query == "display" and arguments:
        number = display_number(state, world.known(window_id(arguments[0])).get("display"))
        if number is None:
            fail(f"window {arguments[0]} is on no display")
        print(number)
    elif query == "desktop":
        frame = nth_display(state, arguments).get("desktopFrame")
        if not frame:
            fail("the Desktop is out of view")
        print(words(rect(frame)))
    elif query == "ready" and arguments:
        if not state["accessibility"]:
            sys.exit(3)
        managed = sum(1 for window in state["windows"] if window["managed"])
        sys.exit(0 if state["running"] and managed >= int(arguments[0]) else 1)
    elif query == "frame" and arguments:
        print(words(rect(world.known(window_id(arguments[0]))["frame"])))
    elif query == "shown" and arguments:
        wanted = window_id(arguments[0])
        if world.known(wanted)["parked"] or world.share_in_view(wanted) < 0.5:
            fail(f"window {wanted} is out of view")
        print(words(rect(world.known(wanted)["frame"])))
    elif query == "slot" and arguments:
        slot = world.slot(window_id(arguments[0]))
        if not slot:
            fail(f"window {arguments[0]} has no slot in view")
        print(words(slot))
    elif query == "tile" and arguments:
        tile = world.tile(window_id(arguments[0]))
        if not tile:
            fail(f"no tile holds window {arguments[0]}")
        print(words(rect(tile["frame"])))
    else:
        answer = predicate(world, query, arguments)
        if answer is None:
            fail(__doc__)
        holds, why = answer
        if not holds:
            print(why)
        sys.exit(0 if holds else 1)


if __name__ == "__main__":
    main()
