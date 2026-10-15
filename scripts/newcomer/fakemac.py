"""A Mac made of a few lines of Python, for trying the newcomer's rig on Linux (rehearse.py). It proves the rig, not Arbor and not macOS.

It has what rig.py's RealMac has: look, picture, cells, smaller, under, perform, settle, calm, password, mark. Its windows come from a JSON file:
{"display": [0, 0, 1440, 900], "visible": [0, 25, 1440, 800], "windows": [{"id": 11, "owner": "TextEdit", "frame": [x, y, w, h]}, …]}, the
frontmost first. What it understands of a person's hands:

    a click                       brings the window there to the front and gives it the keyboard
    a drag by the top 28 points   moves the window; let go at the left or right edge it takes that half, at the top edge all of the room
    a double-click up there       all of the room, and the second time back
    cmd+h                         hides the window with the keyboard
    cmd+tab                       brings the window at the very back to the front

And of Arbor, which here is a caricature with the faults the score has to catch:
    a double-click on "Archive"   (the window that stands for the download) starts it: it waits for the permission
    password                      gives it the permission, and its welcome goes
    while it runs                 a window that takes a half pushes the window at the very back out of view, which nobody touched;
                                  a window that fills the room is put back three looks later; ctrl+opt+z takes the last change back
    ctrl+opt+q                    it quits
"""

import copy
import json

TITLE_BAR = 28


class FakeMac:
    def __init__(self, path, arm):
        with open(path) as file:
            world = json.load(file)
        self.display, self.visible = world["display"], world["visible"]
        self.windows = [dict(window, on=True) for window in world["windows"]]
        self.arm = arm
        self.arbor = "none"
        self.history = []
        self.zoomed = {}
        self.pull_back = None
        self.pictures = 0
        self.marks = []
        self.held = None

    # MARK: Eyes

    def look(self):
        if self.pull_back:
            self.pull_back[0] -= 1
            if self.pull_back[0] <= 0:
                self.find(self.pull_back[1])["frame"] = self.pull_back[2]
                self.pull_back = None
        shown = [window for window in self.windows if window["on"]]
        return {
            "windows": {str(window["id"]): {"pid": window["id"] * 10, "layer": window.get("layer", 0), "frame": list(window["frame"]),
                                            "on": window["on"], "owner": window["owner"]} for window in self.windows},
            "order": [str(window["id"]) for window in shown],
            "focused": str(shown[0]["id"]) if shown else None,
            "display": list(self.display), "visible": list(self.visible), "arbor": self.arbor, "docked": []}

    def picture(self, path):
        self.pictures += 1
        with open(path, "wb") as file:
            file.write(b"\xff\xd8\xff\xe0 a picture of a Mac that is not there, number %d \xff\xd9" % self.pictures)
        return int(self.display[2]), int(self.display[3])

    def cells(self, _):
        rows = [[0] * 144 for _ in range(86)]
        for shade, window in reversed(list(enumerate(window for window in self.windows if window["on"]))):
            x, y, w, h = (int(value / 10) for value in window["frame"])
            for row in range(max(0, y - 4), min(86, y - 4 + h)):
                for column in range(max(0, x), min(144, x + w)):
                    rows[row][column] = 60 + 30 * (window["id"] % 6) + (40 if shade == 0 else 0)
        return rows

    def smaller(self, path, into):
        with open(path, "rb") as source, open(into, "wb") as target:
            target.write(source.read())

    def under(self, x, y):
        for window in self.windows:
            frame = window["frame"]
            if window["on"] and frame[0] <= x < frame[0] + frame[2] and frame[1] <= y < frame[1] + frame[3]:
                return str(window["id"])
        return None

    # MARK: Hands

    def find(self, identifier):
        return next(window for window in self.windows if str(window["id"]) == str(identifier))

    def raise_(self, window):
        self.windows.remove(window)
        self.windows.insert(0, window)

    def remember(self):
        self.history.append(copy.deepcopy(self.windows))

    def place(self, window, frame):
        self.remember()
        window["frame"] = list(frame)
        x, y, w, h = self.visible
        if self.arbor != "running":
            return
        if frame[2] == w / 2:
            behind = next((other for other in reversed(self.windows) if other is not window and other["on"] and other["owner"] != "Arbor"), None)
            if behind:
                behind["frame"] = [self.display[2] - 1, self.display[3] - 1] + behind["frame"][2:]
        elif frame == [x, y, w, h]:
            self.pull_back = [3, window["id"], self.history[-1][[each["id"] for each in self.history[-1]].index(window["id"])]["frame"]]

    def drop(self, window, x, y, dx, dy):
        left, top, width, height = self.visible
        if x <= self.display[0] + 5:
            self.place(window, [left, top, width / 2, height])
        elif x >= self.display[0] + self.display[2] - 6:
            self.place(window, [left + width / 2, top, width / 2, height])
        elif y <= top:
            self.place(window, [left, top, width, height])
        else:
            self.place(window, [window["frame"][0] + dx, window["frame"][1] + dy] + window["frame"][2:])

    def perform(self, action):
        verb = action["verb"]
        target = self.under(action["x"], action["y"]) if "x" in action else None
        window = self.find(target) if target else None
        if verb in ("click", "double-click", "drag") and window:
            self.raise_(window)
        on_title = bool(window) and action["y"] < window["frame"][1] + TITLE_BAR
        if verb == "double-click" and window and window["owner"] == "Archive" and self.arm == "arbor":
            self.arbor = "waiting"
            self.windows.insert(0, {"id": 99, "owner": "Arbor", "frame": [500, 300, 400, 300], "on": True})
        elif verb == "double-click" and on_title:
            if window["id"] in self.zoomed:
                self.place(window, self.zoomed.pop(window["id"]))
            else:
                self.zoomed[window["id"]] = list(window["frame"])
                self.place(window, self.visible)
        elif verb == "drag" and on_title:
            if action.get("keep"):
                self.held = (window, action["to_x"], action["to_y"], action["to_x"] - action["x"], action["to_y"] - action["y"])
            else:
                self.drop(window, action["to_x"], action["to_y"], action["to_x"] - action["x"], action["to_y"] - action["y"])
        elif verb == "release" and self.held:
            window, x, y, dx, dy = self.held
            self.held = None
            self.drop(window, x, y, dx, dy)
        elif verb == "key":
            for chord in action["chords"]:
                front = next((each for each in self.windows if each["on"]), None)
                if chord == "cmd+h" and front:
                    front["on"] = False
                elif chord == "ctrl+opt+z" and self.arbor == "running" and self.history:
                    self.windows = self.history.pop()
                    self.pull_back = None
                elif chord == "cmd+tab" and front:
                    self.raise_([each for each in self.windows if each["on"]][-1])
                elif chord == "ctrl+opt+q" and self.arbor != "none":
                    self.arbor = "none"
                    self.windows = [each for each in self.windows if each["owner"] != "Arbor"]
        return True

    def password(self):
        if self.arbor == "waiting":
            self.arbor = "running"
            self.windows = [each for each in self.windows if each["owner"] != "Arbor"]
            return "typed for you: Arbor has the permission now"
        return "nobody was asking for one"

    def help(self, how):
        self.arbor = "running"
        self.windows = [each for each in self.windows if each["owner"] != "Arbor"]
        return "installed, started and given the permission"

    def said(self):
        return []

    def settle(self, *_):
        pass

    def calm(self):
        self.held = None

    def mark(self, text):
        self.marks.append(text)
