"""The newcomer's tasks, in the words it is given, and how the rig tells whether each was done (scripts/newcomer/README.md).

The words are the same with Arbor and with macOS alone, and say what is wanted, never how. Whether a task was done is read from the
window server's list of windows, so that it needs nobody's opinion, and the newcomer is not told: a person is not told either.

A look at the Mac is a dictionary:
    windows   {"<id>": {"pid": n, "layer": n, "frame": [x, y, w, h], "on": bool, "owner": "<app>"}}
    order     the ids of what is on screen, from the frontmost to the one at the back
    focused   the id of the window with the keyboard, or None
    display   [x, y, w, h], all of it            visible   the part between the menu bar and the Dock
    arbor     "none", "waiting" (it runs and has no permission yet) or "running"
Points, origin top-left, y down. Never a window's title.

Written for Python 3.9, which is what a hosted Mac has.
"""

# How far from where it was a window may end and still be back: a title bar is 28 points high, a hand is no ruler.
NEAR = 12

TASKS = [
    {"id": "install", "arms": ("arbor",), "minutes": 20,
     "title": "install and start it",
     "words": "A build of Arbor has been downloaded for you: Arbor.zip, in the Downloads folder. Install it, start it, and get it to "
              "the point where it is ready to arrange windows."},
    {"id": "side-by-side", "arms": ("arbor", "macos"), "minutes": 12,
     "title": "two windows side by side",
     "words": "Put the TextEdit window and the Safari window side by side, TextEdit on the left and Safari on the right, so that "
              "the two together fill the screen and neither covers the other."},
    {"id": "fill", "arms": ("arbor", "macos"), "minutes": 12,
     "title": "one window fills the screen, and stays",
     "words": "Make the Calendar window fill the screen, and keep it there: it has to stay that big."},
    {"id": "find", "arms": ("arbor", "macos"), "minutes": 12,
     "title": "find a window that went out of view",
     "words": "The Notes window was open when you came. Find it, and bring it to the front so that all of it can be seen."},
    {"id": "undo", "arms": ("arbor", "macos"), "minutes": 12,
     "title": "undo a mistake",
     "words": "Make the Finder window take up the left half of the screen. Then suppose that was a mistake: put everything back "
              "exactly as it was before you did it."},
    {"id": "back", "arms": ("arbor", "macos"), "minutes": 12,
     "title": "go back to how the Mac was",
     "words": "Go back to how the Mac was when you first saw it: every window where it was then, and as big as it was then."},
    {"id": "quit", "arms": ("arbor",), "minutes": 10,
     "title": "quit, and leave the Mac as it was found",
     "words": "Quit Arbor, and leave the Mac as you found it."},
]


def tasks_for(arm):
    return [task for task in TASKS if arm in task["arms"]]


# MARK: Geometry

def area(frame):
    return max(0, frame[2]) * max(0, frame[3])


def overlap(a, b):
    width = min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])
    height = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
    return max(0, width) * max(0, height)


def share(part, whole):
    """How much of `whole` lies under `part`, 0 to 1."""
    return overlap(part, whole) / area(whole) if area(whole) else 0.0


def near(a, b, by=NEAR):
    return all(abs(a[index] - b[index]) <= by for index in range(4))


def window(look, identifier):
    return look["windows"].get(str(identifier)) if identifier else None


def on_screen(look, identifier):
    found = window(look, identifier)
    return bool(found and found["on"] and str(identifier) in look["order"])


def covered(look, identifier):
    """The largest share of the window that one ordinary window in front of it hides."""
    mine, most = window(look, identifier), 0.0
    for other in look["order"]:
        if other == str(identifier):
            break
        above = look["windows"].get(other)
        if above and above["layer"] == 0:
            most = max(most, share(above["frame"], mine["frame"]))
    return most


def ordinary(look, without=("Arbor",)):
    """The windows people arrange: layer 0, big enough to be one, and not Arbor's own."""
    return {identifier: found for identifier, found in look["windows"].items()
            if found["layer"] == 0 and found["owner"] not in without and found["frame"][2] >= 100 and found["frame"][3] >= 60}


def moved(before, after, by=2):
    """What changed between two looks among the windows people arrange: (moved, gone, come).

    moved: {"id", "owner", "from", "to"} for every window both looks have whose frame differs. A window Arbor sends out of view keeps
    its place in the window server's list and gets a frame past the display's edge, so it is among these.
    gone and come: ids that left the screen or came on it without a change of frame: closed, hidden, minimized, another Space.
    """
    was, now = ordinary(before), ordinary(after)
    changed, gone, come = [], [], []
    for identifier in sorted(set(was) & set(now), key=int):
        if not near(was[identifier]["frame"], now[identifier]["frame"], by):
            changed.append({"id": identifier, "owner": now[identifier]["owner"], "from": was[identifier]["frame"], "to": now[identifier]["frame"]})
        elif was[identifier]["on"] and not now[identifier]["on"]:
            gone.append(identifier)
        elif now[identifier]["on"] and not was[identifier]["on"]:
            come.append(identifier)
    gone += sorted((identifier for identifier in set(was) - set(now) if was[identifier]["on"]), key=int)
    come += sorted((identifier for identifier in set(now) - set(was) if now[identifier]["on"]), key=int)
    return changed, gone, come


# MARK: Was it done?

def back_where_it_was(look, then, cast, notes):
    """How many of the cast's windows are where they were in the look `then`, and as big."""
    back = 0
    for name, identifier in sorted(cast.items()):
        was = window(then, identifier)
        if not was or not was["on"]:
            continue
        if not on_screen(look, identifier):
            notes.append("%s is not on the screen" % name)
        elif not near(window(look, identifier)["frame"], was["frame"]):
            notes.append("%s is at %s, it was at %s" % (name, window(look, identifier)["frame"], was["frame"]))
        else:
            back += 1
    return back


def judge(task, look, cast, first, begun, seen):
    """(done, notes). `first`: the look before the first task that arranges anything; `begun`: at this task's beginning; `seen`: every look
    since. The notes say what is amiss, for whoever reads the score."""
    notes = []
    visible, display = look["visible"], look["display"]
    if task == "install":
        if look["arbor"] != "running":
            notes.append({"none": "Arbor does not run", "waiting": "Arbor runs and waits for the Accessibility permission"}.get(look["arbor"], look["arbor"]))
    elif task == "side-by-side":
        left, right = cast.get("textedit"), cast.get("safari")
        for name, identifier in (("textedit", left), ("safari", right)):
            if not on_screen(look, identifier):
                notes.append("%s is not on the screen" % name)
        if not notes:
            a, b = window(look, left)["frame"], window(look, right)["frame"]
            if a[0] + a[2] / 2 >= b[0] + b[2] / 2:
                notes.append("textedit is not to the left of safari")
            if overlap(a, b) > 0.02 * min(area(a), area(b)):
                notes.append("they overlap")
            for name, frame, identifier in (("textedit", a, left), ("safari", b, right)):
                if not 0.3 * visible[2] <= frame[2] <= 0.7 * visible[2]:
                    notes.append("%s is %d wide of %d" % (name, frame[2], visible[2]))
                if frame[3] < 0.85 * visible[3]:
                    notes.append("%s is %d high of %d" % (name, frame[3], visible[3]))
                if covered(look, identifier) > 0.05:
                    notes.append("%s is partly behind another window" % name)
            if (overlap(a, visible) + overlap(b, visible)) < 0.85 * area(visible):
                notes.append("together they fill %d %% of the screen" % round(100 * (overlap(a, visible) + overlap(b, visible)) / area(visible)))
    elif task == "fill":
        notes += fills(look, cast.get("calendar"), "calendar", visible, display)
    elif task == "find":
        identifier = cast.get("notes")
        if not on_screen(look, identifier):
            notes.append("notes is not on the screen")
        else:
            if share(display, window(look, identifier)["frame"]) < 0.98:
                notes.append("%d %% of notes is on the display" % round(100 * share(display, window(look, identifier)["frame"])))
            if covered(look, identifier) > 0.02:
                notes.append("notes is partly behind another window")
    elif task == "undo":
        identifier = cast.get("finder")
        half = [visible[0], visible[1], visible[2] / 2, visible[3]]
        if not any(on_screen(each, identifier) and share(window(each, identifier)["frame"], half) > 0.8
                   and window(each, identifier)["frame"][2] <= 0.65 * visible[2] for each in seen):
            notes.append("finder never took up the left half")
        back_where_it_was(look, begun, cast, notes)
    elif task in ("back", "quit"):
        if task == "quit" and look["arbor"] != "none":
            notes.append("Arbor still runs")
        if task == "quit" and any(found["owner"] == "Arbor" and found["on"] for found in look["windows"].values()):
            notes.append("something of Arbor's is still on the screen")
        back_where_it_was(look, first, cast, notes)
    else:
        notes.append("no such task: %s" % task)
    return not notes, notes


def fills(look, identifier, name, visible, display):
    if not on_screen(look, identifier):
        return ["%s is not on the screen" % name]
    frame = window(look, identifier)["frame"]
    # Between the menu bar and the Dock, or macOS's full screen, which is all of the display.
    if share(frame, visible) < 0.9 and share(frame, display) < 0.95:
        return ["%s fills %d %% of the screen" % (name, round(100 * share(frame, visible)))]
    if covered(look, identifier) > 0.05:
        return ["%s is partly behind another window" % name]
    return []
