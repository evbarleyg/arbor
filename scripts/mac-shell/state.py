#!/usr/bin/env python3
"""Answers questions about Arbor's state for Mac shell scripts (scripts/mac-shell/lib.sh).

Reads the reply of `arborctl state` on stdin.

  state.py json                 the state object, indented
  state.py summary              a few readable lines: the camera, every window, tiles, the Desktop
  state.py frame <window>       x y w h: where Arbor last saw the window
  state.py slot <window>        x y w h: where the layout puts the window (fails when it has no slot)
  state.py tile <window>        x y w h: the tile that stands in for the window (fails when there is none)
  state.py desktop [n]          x y w h: the Desktop's part of display n's layout (fails when it is out of view)
  state.py screen [n]           x y w h: display n's visible frame (displays count from 1, the main one first)
  state.py display-frame [n]    x y w h: all of display n
  state.py display-id [n]       display n's identifier
  state.py displays             how many displays Arbor arranges
  state.py display <window>     the number of the display whose workspace holds the window
  state.py is <window> <what>   exit code 0 or 1; what: docked floating parked managed minimized hidden tile focused pinned
  state.py ready <count>        exit code 0 when Arbor runs and manages that many windows, 3 when it lacks
                                Accessibility permission, otherwise 1

Numbers are rounded to whole points, so that shell arithmetic can use them.
"""

import json
import sys


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


def find_window(state, wanted):
    for window in state["windows"]:
        if window["id"] == wanted:
            return window
    fail(f"Arbor knows no window {wanted}")


def find_tile(state, wanted):
    for display in state["displays"]:
        for tile in display["tiles"]:
            if wanted in tile["windows"]:
                return tile
    return None


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


def summary(state):
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
        lines.append(f"  w{window['id']} {words(rect(window['frame'])):<20} {' '.join(traits)}")
    return "\n".join(lines)


def main():
    arguments = sys.argv[1:]
    if not arguments:
        fail(__doc__)
    try:
        state = json.load(sys.stdin)["state"]
    except (ValueError, KeyError):
        fail("no state on stdin; is Arbor running?")
    query, arguments = arguments[0], arguments[1:]

    if query == "json":
        print(json.dumps(state, indent=1, sort_keys=True))
    elif query == "summary":
        print(summary(state))
    elif query == "screen":
        print(words(rect(nth_display(state, arguments)["visibleFrame"])))
    elif query == "display-frame":
        print(words(rect(nth_display(state, arguments)["frame"])))
    elif query == "display-id":
        print(nth_display(state, arguments)["id"])
    elif query == "displays":
        print(len(state["displays"]))
    elif query == "display" and arguments:
        number = display_number(state, find_window(state, window_id(arguments[0])).get("display"))
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
    elif query in ("frame", "slot", "tile", "is") and arguments:
        wanted = window_id(arguments[0])
        if query == "frame":
            print(words(rect(find_window(state, wanted)["frame"])))
        elif query == "slot":
            slots = [display["windowFrames"].get(str(wanted)) for display in state["displays"]]
            slots = [slot for slot in slots if slot]
            if not slots:
                fail(f"window {wanted} has no slot in view")
            print(words(rect(slots[0])))
        elif query == "tile":
            tile = find_tile(state, wanted)
            if not tile:
                fail(f"no tile holds window {wanted}")
            print(words(rect(tile["frame"])))
        else:
            what = arguments[1] if len(arguments) > 1 else ""
            window = find_window(state, wanted)
            if what == "floating":
                answer = window["managed"] and not window["docked"]
            elif what == "tile":
                answer = find_tile(state, wanted) is not None
            elif what == "focused":
                answer = state.get("focused") == wanted
            elif what in ("docked", "parked", "managed", "minimized", "hidden", "fullScreen", "pinned"):
                answer = window[what]
            else:
                fail(f"cannot tell whether a window is `{what}`")
            sys.exit(0 if answer else 1)
    else:
        fail(__doc__)


if __name__ == "__main__":
    main()
