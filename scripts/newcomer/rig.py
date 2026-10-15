#!/usr/bin/env python3
"""The loop on the hosted Mac: show a picture, wait for a word, carry it out with real input, write down what happened.

    rig.py --run <name> --arm arbor|macos --box <folder> --remote <url> --out <folder> --cast name=id,… [--until <epoch>] …

scripts/mac-shell/newcomer.sh sets the Mac up and starts this; scripts/newcomer/README.md says what it is for and how the parts talk.
One round:

    1  a picture of the screen, small, with a few lines of text beside it, is laid in <box>/screen and the courier is asked to push it
    2  the action branch is fetched every two seconds until it holds an answer to that picture, or the task's time is up
    3  the answer is taken apart (words.py); remarks are written down, the one act is carried out with the pointer and the keys
    4  when the windows have come to rest the window server's list is read again: what moved, and was it what the act touched?

The newcomer sees the picture and the text. The journal (<box>/record/journal.jsonl, one JSON object a line) it does not see: every look at the
windows, who moved, how long each part of the round took, and at the end of each task whether it was done (tasks.py). score.py reads it.

It takes the pointer and the keyboard and does whatever it is told with them, so it runs on GitHub's Macs and nowhere else, or
with --fake, against a Mac made of a few lines of Python (fakemac.py), which is how rehearse.py tries all of this on Linux.

Written for Python 3.9, which is what a hosted Mac has.
"""

import argparse
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tasks  # noqa: E402
import words  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
# A picture shrunk to this many cells is compared with the one before. Fewer cells than DEAD changed: nothing a person would have noticed happened.
CELLS = (144, 90)
DEAD = 14


def now():
    return round(time.time(), 2)


def run(command, timeout=20, env=None, data=None):
    """(exit code, what it printed). A tool that hangs or is not there answers like one that failed."""
    try:
        done = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=timeout, env=env, input=data)
        return done.returncode, done.stdout
    except (subprocess.TimeoutExpired, OSError):
        return 124, b""


class RealMac:
    """Eyes and hands: the tools of scripts/mac-shell, compiled by newcomer.sh, and macOS's own."""

    def __init__(self, options):
        self.tools = options.tools
        self.samples = options.samples
        self.read_to = 0
        self.display = self.visible = None
        self.ask = os.fdopen(options.sampler_in, "w") if options.sampler_in else None
        self.answers = os.fdopen(options.sampler_out, "r") if options.sampler_out else None
        self.questions = 0
        self.arm = options.arm
        self.scale = 1.0
        # Arbor as the newcomer starts it lives in the account's own folders, whatever lib.sh has set up for this script.
        self.clean = {name: value for name, value in os.environ.items() if not name.startswith("ARBOR_")}

    def tool(self, name, *arguments, **keywords):
        return run([os.path.join(self.tools, name)] + [str(each) for each in arguments], **keywords)

    def mark(self, text):
        if self.ask:
            self.ask.write("mark %s\n" % text)
            self.ask.flush()

    def settle(self, calm=600, at_most=5000):
        """Waits until no window has moved, come or gone for a while: the sampler sees every frame."""
        if not self.ask:
            time.sleep(1)
            return
        self.questions += 1
        word = "n%d" % self.questions
        self.ask.write("quiet %d %d %s\n" % (calm, at_most, word))
        self.ask.flush()
        # The sampler answers within at_most; one that has died closes its end, and then a line is empty.
        while True:
            line = self.answers.readline()
            if not line or line.split()[-1:] == [word]:
                return

    def frames(self):
        """The display, and what the menu bar and the Dock leave of it, as the sampler last wrote them down."""
        try:
            with open(self.samples, "rb") as log:
                log.seek(self.read_to)
                fresh = log.read()
        except OSError:
            fresh = b""
        whole = fresh.rfind(b"\n") + 1
        self.read_to += whole
        for line in fresh[:whole].decode("utf-8", "replace").split("\n"):
            parts = line.split()
            if len(parts) == 6 and parts[1] in ("D", "V"):
                frame = [float(each) for each in parts[2:6]]
                if parts[1] == "D":
                    self.display = frame
                else:
                    self.visible = frame

    def arbor_app(self):
        """Where the Arbor that runs was started from, or None."""
        code, out = run(["pgrep", "-fl", r"Arbor\.app/Contents/MacOS/Arbor"], timeout=5)
        for line in out.decode("utf-8", "replace").split("\n"):
            found = re.search(r"(/.*?Arbor\.app)/Contents/MacOS/Arbor", line)
            if found:
                return found.group(1)
        return None

    def arbor(self):
        if self.arm != "arbor":
            return "none"
        app = self.arbor_app()
        if not app:
            return "none"
        code, out = run([app + "/Contents/Helpers/arborctl", "status"], timeout=4, env=self.clean)
        return "running" if out.startswith(b"running") or out.startswith(b"paused") else "waiting"

    def look(self):
        self.frames()
        found, order = {}, []
        code, out = self.tool("pointer", "windows")
        for line in out.decode("utf-8", "replace").split("\n"):
            parts = line.split()
            if len(parts) >= 9:
                found[parts[0]] = {"pid": int(parts[1]), "layer": int(parts[2]), "frame": [float(each) for each in parts[3:7]],
                                   "on": parts[7] == "on", "owner": " ".join(parts[8:])}
        code, out = self.tool("pointer", "windows", "--on-screen")
        for line in out.decode("utf-8", "replace").split("\n"):
            if line.split():
                order.append(line.split()[0])
        code, out = self.tool("apptool", "focused", timeout=5)
        focused = out.split()[0].decode() if code == 0 and out.split() else None
        return {"windows": found, "order": order, "focused": focused, "display": self.display, "visible": self.visible, "arbor": self.arbor()}

    def picture(self, path):
        """Writes a small JPEG of the whole screen, pointer and all, one pixel to a point. Returns (width, height), or None."""
        raw = path + ".raw.jpg"
        code, _ = run(["screencapture", "-x", "-C", "-t", "jpg", raw], timeout=15)
        if code != 0 or not os.path.exists(raw):
            return None
        self.frames()
        width, height = int(self.display[2]), int(self.display[3])
        run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "55", "-z", str(height), str(width), raw, "--out", path], timeout=15)
        os.remove(raw)
        return (width, height) if os.path.exists(path) else None

    def cells(self, path):
        """The picture shrunk to CELLS, as rows of grey values from the top, without the menu bar, whose clock ticks."""
        small = path + ".bmp"
        code, _ = run(["sips", "-s", "format", "bmp", "-z", str(CELLS[1]), str(CELLS[0]), path, "--out", small], timeout=15)
        try:
            with open(small, "rb") as file:
                data = file.read()
            os.remove(small)
        except OSError:
            return None
        return bitmap(data)

    def smaller(self, path, into):
        run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "40", "-Z", "800", path, "--out", into], timeout=15)

    def under(self, x, y):
        code, out = self.tool("apptool", "top-at", x, y, timeout=5)
        return out.split()[0].decode() if code == 0 and out.split() else None

    def perform(self, action):
        verb = action["verb"]
        held = ["--mods", action["holding"]] if "holding" in action else []
        if verb in ("click", "double-click", "right-click"):
            extra = {"click": [], "double-click": ["2"], "right-click": ["--right"]}[verb]
            return self.tool("pointer", "click", action["x"], action["y"], *(extra + held))[0] == 0
        if verb == "move":
            return self.tool("pointer", "move", action["x"], action["y"])[0] == 0
        if verb == "drag":
            # Slowly, and with a rest before letting go, as somebody who watches for a preview: macOS and Arbor both want a moment at an edge.
            extra = ["--duration", "0.9", "--hold", "1.0"] + (["--no-release"] if action.get("keep") else [])
            return self.tool("pointer", "drag", action["x"], action["y"], action["to_x"], action["to_y"], *(extra + held))[0] == 0
        if verb == "release":
            return self.tool("pointer", "release", *([action["x"], action["y"]] if "x" in action else []))[0] == 0
        if verb == "scroll":
            return self.tool("witness", "wheel", action["x"], action["y"], action["notches"])[0] == 0
        if verb in ("key", "type"):
            fine = True
            for chord in action["chords"] if verb == "key" else words.chords_for(action["text"]):
                fine = self.tool("pointer", "key", chord)[0] == 0 and fine
                time.sleep(0.12 if verb == "key" else 0.01)
            return fine
        if verb == "wait":
            time.sleep(action["seconds"])
            return True
        return False

    def calm(self):
        self.tool("pointer", "calm")

    def password(self):
        """Nobody knows the password of the account a hosted Mac runs jobs under. What it would have allowed is done by other means (password.sh)."""
        code, out = run(["bash", os.path.join(HERE, "password.sh"), os.path.join(self.tools, "pointer"), self.arbor_app() or "-"], timeout=60, env=self.clean)
        return out.decode("utf-8", "replace").strip().split("\n")[-1] or "nothing"


def bitmap(data):
    """A BMP of 24 or 32 bits a pixel as rows of grey values, from the top. None for anything else."""
    if data[:2] != b"BM" or len(data) < 54:
        return None
    start = int.from_bytes(data[10:14], "little")
    width = int.from_bytes(data[18:22], "little", signed=True)
    height = int.from_bytes(data[22:26], "little", signed=True)
    size = int.from_bytes(data[28:30], "little") // 8
    if size not in (3, 4) or width <= 0 or height == 0:
        return None
    stride = (width * size + 3) // 4 * 4
    rows = []
    for row in range(abs(height)):
        line = data[start + row * stride:start + row * stride + width * size]
        if len(line) < width * size:
            return None
        rows.append([(line[index] + line[index + 1] + line[index + 2]) // 3 for index in range(0, width * size, size)])
    if height > 0:
        rows.reverse()
    return rows[len(rows) // 25:]


def changed_cells(before, after):
    """In how many cells two pictures differ by more than a tenth of the way from black to white. None: it cannot be told."""
    if not before or not after or len(before) != len(after):
        return None
    return sum(1 for one, other in zip(before, after) for a, b in zip(one, other) if abs(a - b) > 25)


class Post:
    """The way out. The courier (courier.sh) holds the token; this process never sees it. They talk through files in the box."""

    def __init__(self, box):
        self.box = box
        self.number = 0

    def send(self, what, patience=60):
        """Asks the courier to push <box>/<what>, and waits. True when it says that GitHub has it."""
        self.number += 1
        answer = os.path.join(self.box, "answer-%d" % self.number)
        request = os.path.join(self.box, "request")
        with open(request + ".new", "w") as file:
            file.write("%d %s\n" % (self.number, what))
        os.rename(request + ".new", request)
        limit = time.time() + patience
        while time.time() < limit:
            if os.path.exists(answer):
                with open(answer) as file:
                    said = file.read().strip()
                return said == "0"
            time.sleep(0.05)
        return False


class Inbox:
    """The way in: the action branch, fetched without a token, as anybody can."""

    def __init__(self, folder, remote, branch):
        self.folder, self.remote, self.branch = folder, remote, branch
        self.last = None
        os.makedirs(folder, exist_ok=True)
        self.git("init", "--quiet")

    def git(self, *arguments):
        environment = dict(os.environ, GIT_TERMINAL_PROMPT="0", GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        return run(["git", "-C", self.folder] + list(arguments), timeout=25, env=environment)

    def poll(self):
        """What lies on the branch, as bytes, if it is new since the last time; otherwise None."""
        code, _ = self.git("fetch", "--quiet", "--no-tags", "--depth", "1", self.remote, "+refs/heads/%s:refs/newcomer/action" % self.branch)
        if code != 0:
            return None
        code, tip = self.git("rev-parse", "refs/newcomer/action")
        if code != 0 or tip == self.last:
            return None
        self.last = tip
        code, size = self.git("cat-file", "-s", "refs/newcomer/action:action")
        if code != 0 or int(size) > words.LONGEST_MESSAGE:
            return b"\xff"  # which words.py calls nonsense
        return self.git("cat-file", "blob", "refs/newcomer/action:action")[1]


class Rig:
    def __init__(self, options, mac):
        self.options, self.mac = options, mac
        self.post = Post(options.box)
        self.inbox = Inbox(os.path.join(options.box, "inbox"), options.remote, "mac-shell-out/newcomer.%s.action" % options.run)
        self.screen = os.path.join(options.box, "screen")
        self.record = os.path.join(options.box, "record")
        self.kept = os.path.join(options.out, "screens")
        for folder in (self.screen, self.record, self.kept):
            os.makedirs(folder, exist_ok=True)
        self.journal = open(os.path.join(self.record, "journal.jsonl"), "a")
        self.cast = dict(pair.split("=") for pair in options.cast.split(",") if pair)
        self.tasks = tasks.tasks_for(options.arm)
        self.limits = {pair.split("=")[0]: float(pair.split("=")[1]) for pair in options.limits.split(",") if pair}
        self.round = 0
        self.size = None
        self.cells = None
        self.shown = None
        self.stopped = False
        self.timing = {}
        self.answering = 0

    def write(self, kind, **facts):
        self.journal.write(json.dumps(dict({"kind": kind, "t": now()}, **facts), sort_keys=True) + "\n")
        self.journal.flush()

    # MARK: Out

    def show(self, lines):
        """A new picture with these lines beside it. Sets self.round to its number."""
        self.round += 1
        began = time.time()
        path = os.path.join(self.screen, "screen.jpg")
        size = self.mac.picture(path)
        if size:
            self.size = size
        before, self.cells = self.cells, self.mac.cells(path) if size else None
        shot = time.time()
        with open(os.path.join(self.screen, "round"), "w") as file:
            file.write("%d\n" % self.round)
        # Which picture's answer this one shows the outcome of: 0 when nobody's, so that whoever sent a word meanwhile learns that it came too late.
        with open(os.path.join(self.screen, "answers"), "w") as file:
            file.write("%d\n" % self.answering)
        self.answering = 0
        with open(os.path.join(self.screen, "status.txt"), "w") as file:
            file.write("\n".join(["picture %d (screen.jpg, %d x %d)" % ((self.round,) + (self.size or (0, 0)))] + lines) + "\n")
        sent = self.post.send("screen")
        self.shown = time.time()
        self.timing.update(shot=round(shot - began, 2), push=round(self.shown - shot, 2), pushed=sent)
        if size:
            self.mac.smaller(path, os.path.join(self.kept, "%03d.jpg" % self.round))
        # While the newcomer thinks. Nobody waits for it.
        self.post.send("record", patience=0)
        return changed_cells(before, self.cells)

    # MARK: In

    def hear(self, until):
        """The next message that answers the picture on show: (remarks, act). (None, None) when the time is up.
        Nonsense is answered with a new picture that says so."""
        while not self.stopped:
            if time.time() >= until:
                return None, None
            asked = time.time()
            data = self.inbox.poll()
            if data is None:
                time.sleep(max(0.0, self.options.poll - (time.time() - asked)))
                continue
            self.timing.update(thought=round(time.time() - self.shown, 2), fetch=round(time.time() - asked, 2))
            try:
                answered, remarks, act = words.parse_message(data, *(self.size or (1, 1)))
            except words.Nonsense as nonsense:
                self.write("nonsense", round=self.round, why=str(nonsense))
                self.answering = self.round
                self.show(self.lines + ["not understood, and nothing was done: %s" % nonsense])
                continue
            if answered != self.round:
                # It was on its way while the picture changed: a task's time was up. No new picture for it, or its sender, who has fetched this one by
                # now, would be one behind for ever.
                self.write("late", round=self.round, answered=answered)
                continue
            self.answering = self.round
            return remarks, act
        return None, None

    # MARK: One task

    def heading(self, index, until):
        task = self.tasks[index]
        left = max(0, int((until - time.time()) / 60))
        return "task %d of %d, about %d minutes left: %s" % (index + 1, len(self.tasks), left, task["words"])

    def play(self, index, first):
        """One task, from its first picture to `done`, `giveup` or the end of its time. Returns False when the run is over."""
        task = self.tasks[index]
        began = time.time()
        until = min(began + self.limits.get(task["id"], task["minutes"] * self.options.haste) * 60, self.options.until)
        begun = after = self.mac.look()
        seen = [begun]
        self.mac.mark("newcomer task %s" % task["id"])
        self.write("task-begin", task=task["id"], number=index + 1, look=begun, round=self.round + 1)
        self.lines = [self.heading(index, until)]
        self.show(self.lines + self.notes)
        self.notes = []
        how = "time"
        while True:
            remarks, act = self.hear(until)
            if remarks is None:
                if self.stopped:
                    how = "cut"
                break
            for remark in remarks:
                self.write("remark", task=task["id"], round=self.round, verb=remark["verb"], words=remark["words"])
            if act is None:
                self.lines = [self.heading(index, until)]
                self.show(self.lines + ["noted"])
                continue
            if act["verb"] in words.ENDS:
                how = act["verb"]
                if "words" in act:
                    self.write("remark", task=task["id"], round=self.round, verb="giveup", words=act["words"])
                break
            after = self.act(task["id"], act, after, index, until)
            seen.append(after)
        self.mac.calm()
        look = self.mac.look()
        done, notes = tasks.judge(task["id"], look, self.cast, first, begun, seen + [look])
        if task["id"] == "fill" and done:
            # "And keep it there": what is taken back is taken back within seconds.
            time.sleep(8 * self.options.haste)
            look = self.mac.look()
            done, notes = tasks.judge(task["id"], look, self.cast, first, begun, seen + [look])
            notes = ["it did not stay: " + note for note in notes]
        self.write("task-end", task=task["id"], how=how, done=done, notes=notes, seconds=round(time.time() - began, 1), look=look)
        self.notes = {"time": ["the time for the task before this one was up"], "cut": []}.get(how, [])
        return not self.stopped and time.time() < self.options.until

    def act(self, task, act, rested, index, until):
        """Carries one act out and shows what came of it. `rested`: the look after the act before. Returns the look after this one."""
        line = words.say(act)
        before = self.mac.look()
        # What moved while nobody did anything was touched by nobody.
        idle = tasks.moved(rested, before)
        touched = {before["focused"]}
        if "x" in act and act["verb"] != "move":
            touched.add(self.mac.under(act["x"], act["y"]))
        if "to_x" in act:
            touched.add(self.mac.under(act["to_x"], act["to_y"]))
        self.mac.mark("newcomer round %d %s" % (self.round, act["verb"]))
        began = time.time()
        helped = None
        if act["verb"] == "password":
            helped = self.mac.password()
            fine = True
        elif act["verb"] == "ready":
            fine = True
        else:
            fine = self.mac.perform(act)
        acted = time.time()
        self.mac.settle()
        after = self.mac.look()
        touched.add(after["focused"])
        self.timing.update(act=round(acted - began, 2), settle=round(time.time() - acted, 2))
        moved, gone, come = tasks.moved(before, after)
        timing, self.timing = self.timing, {}
        answered = self.round
        self.lines = [self.heading(index, until)]
        said = ["your last word: %s" % line]
        if not fine:
            said.append("the Mac's pointer or keyboard did not take it")
        if helped:
            said.append("password: %s" % helped)
        cells = self.show(self.lines + said)
        self.write("round", task=task, round=answered, line=line, verb=act["verb"], fine=fine, helped=helped,
                   touched=sorted(each for each in touched if each), moved=moved, gone=gone, come=come,
                   idle_moved=idle[0], idle_gone=idle[1], cells=cells, timing=timing, arbor=after["arbor"], order=after["order"][:12])
        return after

    # MARK: The whole run

    def go(self):
        options = self.options
        self.notes, self.lines = [], []
        first = self.mac.look()
        self.write("run", run=options.run, arm=options.arm, build=options.build, system=options.system, helped=options.helped,
                   cast=self.cast, display=first["display"], visible=first["visible"], tasks=[task["id"] for task in self.tasks])
        self.lines = ["Nothing has begun. Read HOWTO.md; when you are ready to begin, say: ./mac ready"]
        self.show(self.lines)
        waited = time.time()
        while True:
            remarks, act = self.hear(min(waited + options.patience, options.until))
            if remarks is None:
                self.write("end", how="cut" if self.stopped else "nobody came")
                self.farewell("Nobody said ready in time: this Mac has gone.")
                return 3
            if act and act["verb"] == "ready":
                break
            self.show(self.lines + ["nothing has begun yet: say ready"])
        self.timing = {}
        first = self.mac.look()
        self.write("ready", look=first, waited=round(time.time() - waited, 1))
        how = "played"
        for index in range(len(self.tasks)):
            if not self.play(index, first):
                how = "cut" if self.stopped else "out of time"
                break
        self.write("end", how=how)
        self.farewell("That was the last task. Thank you: this Mac is going away now, and nothing more is looked at.")
        return 0

    def farewell(self, line):
        with open(os.path.join(self.screen, "over"), "w") as file:
            file.write("over\n")
        self.show([line])
        self.post.send("record")
        self.journal.close()
        shutil.copy(os.path.join(self.record, "journal.jsonl"), os.path.join(self.options.out, "journal.jsonl"))


def main():
    parser = argparse.ArgumentParser(description="The newcomer's loop on a hosted Mac: see scripts/newcomer/README.md")
    parser.add_argument("--run", required=True)
    parser.add_argument("--arm", required=True, choices=("arbor", "macos"))
    parser.add_argument("--box", required=True, help="the folder shared with the courier")
    parser.add_argument("--remote", required=True, help="where the action branch is fetched from")
    parser.add_argument("--out", required=True, help="where what goes back with the run's output is left")
    parser.add_argument("--cast", required=True, help="name=window id, with commas between")
    parser.add_argument("--build", default="", help="which commit the Arbor in Downloads was built from")
    parser.add_argument("--system", default="")
    parser.add_argument("--helped", default="", help="what the newcomer was spared, for the score to say")
    parser.add_argument("--until", type=float, default=0, help="seconds since 1970: when all of it has to be over")
    parser.add_argument("--patience", type=float, default=2400, help="seconds to wait for `ready`")
    parser.add_argument("--poll", type=float, default=2.0, help="seconds between two looks at the action branch")
    parser.add_argument("--haste", type=float, default=1.0, help="a minute lasts this many minutes: for rehearsals")
    parser.add_argument("--limits", default="", help="task=minutes, with commas between: other limits than tasks.py has, for rehearsals")
    parser.add_argument("--tools", default="", help="the folder with pointer, apptool and witness")
    parser.add_argument("--samples", default="", help="the sampler's log")
    parser.add_argument("--sampler-in", type=int, default=0, help="the descriptor on which the sampler takes commands")
    parser.add_argument("--sampler-out", type=int, default=0, help="the descriptor on which it answers")
    parser.add_argument("--fake", default="", help="no Mac: fakemac.py, which keeps its windows in this file")
    options = parser.parse_args()
    if not re.match(r"[A-Za-z0-9-]{1,20}\Z", options.run):
        parser.error("--run takes 1 to 20 letters, digits and dashes")
    options.until = options.until or time.time() + 6000
    if options.fake:
        import fakemac
        mac = fakemac.FakeMac(options.fake, options.arm)
    elif os.environ.get("GITHUB_ACTIONS") == "true" and sys.platform == "darwin":
        mac = RealMac(options)
    else:
        sys.exit("rig.py: it takes the pointer and the keyboard and does with them what it is told from afar: only on one of GitHub's Macs (or with --fake)")
    rig = Rig(options, mac)

    def stop(*_):
        rig.stopped = True
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        return rig.go()
    finally:
        mac.calm()


if __name__ == "__main__":
    sys.exit(main())
