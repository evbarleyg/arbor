#!/usr/bin/env python3
"""Launch fuzzing: whatever state.json and settings.json say, Arbor must start, work, and quit with every window in view.

Takes files Arbor itself wrote in a rich session, damages them in one place after another, and starts a fresh
`arbor-sim launch` on each (Sources/arbor-sim/Launch.swift): the real decoders, the real controller, a fake window system.
Every start runs the same script of everyday commands with `health` lines in between. docs/TESTING.md, "Launch fuzzing".

    scripts/fuzz-launch.py all                      everything, about an hour on four cores
    scripts/fuzz-launch.py all --limit 300          a sample of each kind, a few minutes (`make fuzz`)
    scripts/fuzz-launch.py state numbers shapes     only state.json, only these kinds of damage

What is fuzzed:
    state      state.json is damaged; Arbor starts with and without its windows, on one display and on two
    settings   settings.json is damaged; the script also drives set, bind, rule, exclude and reset on that same file
    audit      nothing is started: what does Arbor read from a damaged state.json, what would it save again, did it note a
               repair, were the bytes kept? A loss nobody noted is a loss of which no copy is made.
    earlier    nothing is damaged: the files in collab/evidence/state-files, which earlier versions of Arbor wrote, must be read
               without a note, lose nothing, and come through the script. (`--save-bases` writes this version's, to add there.)
Kinds of damage:
    numbers    each number becomes huge, tiny, negative, another's
    shapes     each value becomes null, text, a list, an object…, is deleted, or (in a list) doubled
    strings    each text and each name becomes empty, invisible, enormous, another's
    several    two to six of the above at once, at random

Exits with 1 if anything was found. Each distinct finding is printed once, with the damage that caused it and the file,
which is kept (--keep, or a folder in the temporary directory that is named at the end). What is found and not fixed yet is
listed in KNOWN, counted apart, and no reason to exit with 1.
"""
import argparse, collections, copy, glob, json, os, random, re, resource, shutil, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EARLIER = os.path.join(ROOT, "collab", "evidence", "state-files")
KINDS = ["numbers", "shapes", "strings", "several"]

# ---------------------------------------------------------------------------------------------------------------------
# The sessions the base files come from. Between them the two state files hold every field there is; a test of the
# product (`nothingIsSaidAboutAFullSession`) and `check_bases` below say so when a new field is missing here.

BASE_SESSIONS = {
    # Two displays: names, saved views, a kept group, a pin, a guest, a summoned window, remembered frames.
    "A": (6, 2, ["dock 101 left", "dock 103 right", "dock 102 beside 103 bottom", "save-view 1", "zoom 101", "name web",
                 "save-view 2", "back", "zoom 103", "name mail", "show-all", "move 105 1500 100 600 400", "focus 105",
                 "dock 105 left", "name side", "focus 101", "pin 106", "zoom 101", "open Books", "flush", "back", "forward",
                 "summon Music", "flush"]),
    # The second display unplugged (a dormant arrangement), a tab group, a stashed window, a pause that ends by itself.
    "B": (7, 2, ['layout "Safari | Desktop | (Mail / [Notes Maps])"', "save-view 3", "name all", "zoom 103", "back",
                 "move 107 1500 100 600 400", "focus 107", "dock 107 right", "move 106 1700 300 400 300", "focus 101",
                 "summon Music", "flush", "summon Music", "flush", "displays 1", "flush", "zoom 101", "pause 30"]),
}
# Every key a workspace, a tree, a node or the file can have, so that none goes unfuzzed because no session made one.
EXPECTED_KEYS = {"back", "camera", "floating", "forward", "guests", "names", "pinned", "savedViews", "stashed", "summonFrames",
                 "summoned", "tree", "undockedFrames", "dormant", "hints", "pause", "version", "workspaces", "keeps", "visits",
                 "desktopIsOwedRoom", "welcomed", "hintsShown", "leftAt"}

SETTINGS_SESSION = [
    "rule add com.example.notes dock left title Inbox", "rule add com.example.maps dock beside com.example.safari right",
    "rule add com.example.books ignore", "rule add com.example.photos float", "bind ctrl+opt+x dock left",
    "bind ctrl+opt+y set gap 0", "unbind ctrl+opt+d", "exclude com.example.excluded", "pass-through com.example.emacs",
    "set focusRingColour #FF8800", "set tabsEnabled on"]

STATE_SCRIPT = [
    "quiet", "health", "ascii", "spaces", "layout", "dock 107 left", "health", "drag 107 2 400", "resize 101 right 50",
    "float 101", "dock 101 top", "zoom 102", "back", "forward", "view 1", "view 2", "view 3", "go web", "go all", "show-all",
    "in", "out", "neighbor right", "focus 104", "focus 101", "summon Music", "flush", "summon Music", "flush",
    "toggle-pin 106", "pin 105", "health", "minimize 103", "restore 103", "close 102", "flush", "health", "name again",
    "unname web", "desktop", "home", "displays 2", "flush", "health", "displays 1", "flush", "displays 0", "flush", "health",
    "displays 1", "flush", "health", "pause", "resume", "health", "exclude com.example.mail", "include com.example.mail",
    "arrange", "health", "home", "arrange all", "float-all here", "float-all", "flush", "ascii", "state", "health",
    "quit-check"]

SETTINGS_SCRIPT = [
    "quiet", "health", "settings-file @FILE@", "health", "settings", "bindings", "rules", "get gap", "dock 107 left",
    "dock 101 right", "zoom 101", "open Terminal", "flush", "back", "show-all", "health", "resize 101 left 50",
    "summon Music", "flush", "desktop", "home", "wait 3", "flush", "health", "set gap 20", "set tabsEnabled on",
    "bind ctrl+opt+x dock left", "rule add com.example.notes dock left", "open Notes", "flush",
    "exclude com.example.mail", "include com.example.mail", "pass-through com.example.maps", "health", "reset gap",
    "reset all", "health", "displays 2", "flush", "displays 1", "flush", "pause", "resume", "arrange", "health",
    "reset everything", "reload-settings", "settings", "health", "set gap 30", "get gap", "float-all", "flush", "health",
    "quit-check"]

# ---------------------------------------------------------------------------------------------------------------------
# Found, not fixed yet: a short name, the verdict, where the damage was and what the finding says (both regular
# expressions), who has it, and what a person would see. As narrow as can be: whatever an entry covers goes unseen. **Delete
# the entry with the fix.** A run of everything says which entries no longer find anything.

KNOWN = [
    ("lopsided-weight", "UNHEALTHY", r"tree\.nodes\.\*\.weight$", r"does not read back as it is",
     "the core", "A weight up to 1e12, or down to 5e-324, is believed. Beside ordinary ones it leaves slots of no width, whose frames are then remembered."),
    ("returns-as-a-guest", "UNHEALTHY", r"workspaces\.main\.floating", r"\[parked[a-z-]*\] w\d+ floats on side, whose Desktop is in view, but is parked",
     "the controller", "A window that only the arrangement of a display that was unplugged lists, started with that display back and the main one framing a "
     "window: `reconcile` takes it in as having opened unseen (`placedOnPurpose`), then it returns to its display's arrangement, where the first "
     "layout leaves it alone. It stays where it is, on the main display, and counts as out of view on the other until that is laid out again."),
    ("slot-in-no-tree", "UNHEALTHY", r"^workspaces\.main$", r"\[pending\] the waiting slot w\d+ is in no tree",
     "the app shell", "A file that lists one display both as connected and as unplugged, started without its windows: the remembered arrangement is discarded, and "
     "the slots that waited in it are still on the list until the next timer runs. Nobody sees it."),
    ("blind-beside-1e999", "SILENT LOSS", r"", r"^beside a number like 1e999",
     "L", "`PersistedState.keysLeftOut` reads the file with JSONSerialization, which refuses it whole for one number out of range, where the decoders "
     "shrug it off. A field of a later Arbor in such a file still goes without a note."),
]


def known(verdict, place):
    """The name of the entry of KNOWN that covers this finding, if one does."""
    for name, what, where, says, _, _ in KNOWN:
        if verdict[0] == what and re.search(where, place) and re.search(says, verdict[1]):
            return name
    return None


# ---------------------------------------------------------------------------------------------------------------------
# Damage

BIGGEST = 9223372036854775807
WHOLE = [BIGGEST, BIGGEST - 1, -BIGGEST - 1, -1, 0, 1, 2, 3, 5, 7, 8, 77, 101, 102, 4294967295, 1.5, 1e300]
REAL = [0, -1, 0.5, 1e308, -1e308, 1e300, -1e300, 1.7976931348623157e308, 1e-320, 5e-324, 1e15, -1e15, 0.001, 59.999, 1441]
# Written into the text as they stand: Python's own writer would not produce them.
RAW = ["1e999", "-1e999", "1e-999", "12345678901234567890123", "-0"]
SHAPES = [None, "x", "", [], {}, True, False, 1.5, [1], {"a": 1}, "1", [[]], [None], {"": ""}, [[0, 0], [0, 0]],
          [[1e300, 1e300], [1e300, 1e300]], [[0, 0], [-5, -5]], [{"app": "a"}], ["a", "a"]]
LONG = "a" * 200000
STRINGS = ["", " ", "\t", "\n", "\u0000", "‮", "é", "🪟", "a b", "/", "..", "../../etc/passwd", "*", "%s%n%@", "\\", "\"",
           LONG, "1", "-1", "101", "web", "WEB", "main", "side", "left", "com.example.safari", "COM.EXAMPLE.SAFARI",
           "horizontal", "vertical", "diagonal", "desktop", "stack", "split"]
# What a value of settings.json can be mistaken for: commands, shortcuts, colours, actions.
SETTINGS_STRINGS = ["bind f1 " * 3000 + "desktop", "set gap 1e999", "quit", "reset everything", "pause", "rule add * ignore",
                    "dock sideways", "ctrl+opt+", "+", "cmd+cmd", "#GGGGGG", "#12", "accent ", "shift+cmd+opt+ctrl+fn", "none",
                    "dock beside com.example.safari left", "dock beside  left", "ignore", "pin", "float",
                    "layout " + "(" * 5000, "layout " + "[ " * 3000, "go " + "x" * 100000]
DELETE, DOUBLE = object(), object()
# Fields whose keys are windows, spaces, apps or names rather than fields: reports lump their entries together.
TABLES = ("nodes", "floating", "hints", "savedViews", "guests", "names", "undockedFrames", "summonFrames", "hintsShown", "bindings", "leftAt")


def places(node, path=()):
    """Every place that can be damaged, as (path, what is there): number, string, value (anything), key."""
    if isinstance(node, dict):
        for key, value in node.items():
            yield path + (key,), "key"
            yield path + (key,), "value"
            yield from places(value, path + (key,))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            yield path + (index,), "value"
            yield from places(value, path + (index,))
    elif isinstance(node, bool):
        return
    elif isinstance(node, (int, float)):
        yield path, "number"
    elif isinstance(node, str):
        yield path, "string"


def label(path):
    """A path with the entries of tables and lists lumped together: workspaces.main.floating.*[][]"""
    words = []
    for index, part in enumerate(path):
        if index and path[index - 1] in TABLES:
            words.append("*")
        else:
            words.append("[]" if isinstance(part, int) else str(part))
    return ".".join(words).replace(".[]", "[]")


def damaged(document, path, what, value):
    """Changes `document` in place. False if that place is no longer there, or the change would change nothing."""
    node = document
    for part in path[:-1]:
        try:
            node = node[part]
        except (KeyError, IndexError, TypeError):
            return False
    last = path[-1]
    if not isinstance(node, (dict, list)):  # an earlier change put text there, which has a first character too
        return False
    try:
        node[last]
    except (KeyError, IndexError, TypeError):
        return False
    if what == "key":
        if not isinstance(node, dict) or str(value) in node:
            return False
        node[str(value)] = node.pop(last)
    elif value is DELETE:
        del node[last]
    elif value is DOUBLE:
        if not isinstance(node, list):
            return False
        node.insert(last, copy.deepcopy(node[last]))
    else:
        if type(node[last]) is type(value) and node[last] == value:
            return False
        node[last] = copy.deepcopy(value)  # a later change may reach into it, and SHAPES is for everybody
    return True


def cases(base, kind, strings, rng, count):
    """(label, [(path, what, value)…]) for every damage of this kind."""
    everywhere = list(places(base))
    raw = ["@RAW@" + text for text in RAW]
    if kind == "numbers":
        for path, what in everywhere:
            numeric_key = what == "key" and re.fullmatch(r"-?\d+", str(path[-1]))
            if what == "number":
                for value in dict.fromkeys(WHOLE + REAL + raw):
                    yield label(path), [(path, what, value)]
            elif numeric_key:
                for value in WHOLE:
                    if isinstance(value, int):
                        yield label(path) + " (key)", [(path, what, value)]
    elif kind == "shapes":
        for path, what in everywhere:
            if what == "value":
                for value in SHAPES + [DELETE, DOUBLE]:
                    yield label(path), [(path, what, value)]
    elif kind == "strings":
        for path, what in everywhere:
            if what == "string" or (what == "key" and not re.fullmatch(r"-?\d+", str(path[-1]))):
                for value in strings:
                    yield label(path) + (" (key)" if what == "key" else ""), [(path, what, value)]
    else:
        for _ in range(count):
            changes = []
            for _ in range(rng.randint(2, 6)):
                path, what = rng.choice(everywhere)
                if what == "key":
                    value = rng.choice(strings + [v for v in WHOLE if isinstance(v, int)])
                elif what == "number" and rng.random() < 0.7:
                    value = rng.choice(WHOLE + REAL + raw)
                elif what == "string" and rng.random() < 0.7:
                    value = rng.choice(strings)
                else:
                    what, value = "value", rng.choice(SHAPES + [DELETE, DOUBLE])
                changes.append((path, what, value))
            yield "several", changes


def text_of(document):
    return re.sub(r'"@RAW@([^"]*)"', r"\1", json.dumps(document, ensure_ascii=False))


def shown(value):
    text = "DELETE" if value is DELETE else "DOUBLE" if value is DOUBLE else json.dumps(value)
    return text if len(text) < 60 else text[:50] + "…(%d)" % len(text)


# ---------------------------------------------------------------------------------------------------------------------
# Running and judging

class Rig:
    def __init__(self, options):
        self.sim, self.timeout = options.sim, options.timeout
        self.work = tempfile.mkdtemp(prefix="arbor-fuzz-")
        self.keep = options.keep or os.path.join(self.work, "found")
        for folder in ("cases", "home", "base"):
            os.makedirs(os.path.join(self.work, folder))
        os.makedirs(self.keep, exist_ok=True)
        # A home of its own: the log, and whatever else Arbor writes, stay away from the real one.
        self.environment = dict(os.environ, ARBOR_HOME=os.path.join(self.work, "home"), SWIFT_BACKTRACE="enable=no")
        self.met = set()  # the entries of KNOWN that covered something

    def run(self, arguments):
        """(exit code or "hang", output)"""
        def modest():  # A loop that eats memory should end as a crash, not take the machine along.
            try:
                resource.setrlimit(resource.RLIMIT_AS, (4 << 30, 4 << 30))
            except (ValueError, OSError):
                pass
        try:
            done = subprocess.run([self.sim, "launch"] + arguments, capture_output=True, text=True, errors="replace",
                                  timeout=self.timeout, env=self.environment, stdin=subprocess.DEVNULL, preexec_fn=modest)
            return done.returncode, done.stdout
        except subprocess.TimeoutExpired as expired:
            output = expired.stdout or ""
            return "hang", output.decode(errors="replace") if isinstance(output, bytes) else output

    def case_file(self, text):
        handle, path = tempfile.mkstemp(suffix=".json", dir=os.path.join(self.work, "cases"))
        with os.fdopen(handle, "w", encoding="utf-8") as file:
            file.write(text)
        return path

    def beside(self, path):
        """What lies beside a case file now: Arbor sets a file it cannot read aside, and copies one it repairs."""
        return {name: open(name, encoding="utf-8", errors="replace").read() for name in glob.glob(path[:-5] + ".*") if name != path}

    def clean(self, path):
        for name in glob.glob(path[:-5] + "*"):
            try:
                os.unlink(name)
            except OSError:
                pass


def last_line(output):
    lines = [line[2:] for line in output.splitlines() if line.startswith("> ")]
    return (lines[-1] if lines else "while starting")[:80]


def judge(code, output, script):
    """("ok",), ("refused",), or (what is wrong, the detail)."""
    if code == "hang":
        return "HANG", last_line(output)
    if code != 0:
        return "CRASH", last_line(output)
    lines = output.splitlines()
    health = [line for line in lines if line.startswith("HEALTH")]
    for line in health:
        if line != "HEALTH ok":
            return "UNHEALTHY", line[7:170]
    for line in lines:
        if line.startswith("LAYOUT OUT OF DATE"):
            return "STALE LAYOUT", line[20:170]
        if line.startswith("QUIT") and line != "QUIT ok":
            return "LOST AT QUIT", line[5:170]
    if len(health) != script.count("health") or "QUIT ok" not in lines:
        return "CUT SHORT", "%d of %d health lines" % (len(health), script.count("health"))
    return ("refused",) if "STATE refused" in lines else ("ok",)


def launch_state(rig, document, changes, windows, displays):
    path = rig.case_file(text_of(document))
    code, output = rig.run(["--state", path, "--settings", os.path.join(rig.work, "base", "tabs.json"),
                            "--windows", str(windows), "--displays", str(displays)] + STATE_SCRIPT)
    rig.clean(path)
    return judge(code, output, STATE_SCRIPT)


def launch_settings(rig, document, changes, displays):
    path = rig.case_file(text_of(document))
    script = [line.replace("@FILE@", path) for line in SETTINGS_SCRIPT]
    code, output = rig.run(["--state", rig.copy_of_state(), "--settings", path, "--windows", "7", "--displays", str(displays)] + script)
    verdict = judge(code, output, SETTINGS_SCRIPT)
    if verdict == ("ok",):
        # After `reset everything` and `set gap 30` the file is there, is JSON, and says 30.
        try:
            gap = json.load(open(path, encoding="utf-8")).get("gap")
            if gap != 30:
                verdict = "FILE", "gap is %r after `set gap 30`" % gap
        except (OSError, ValueError) as error:
            verdict = "FILE", "not JSON at the end: %s" % str(error)[:80]
    rig.clean(path)
    return verdict


def facts(node, path=()):
    """Every leaf as (path, value). A list of plain values is a bag: one dropped must not look like all the rest moved."""
    if isinstance(node, dict):
        for key, value in node.items():
            yield from facts(value, path + (key,))
    elif isinstance(node, list):
        if all(not isinstance(item, (dict, list)) for item in node):
            for item in node:
                yield path, plain(item)
        else:
            for index, item in enumerate(node):
                yield from facts(item, path + (index,))
    elif node is not None:
        yield path, plain(node)


def plain(value):
    if isinstance(value, (bool, str)) or value is None:
        return json.dumps(value)
    try:
        return repr(float(value) + 0.0)  # -0.0 is 0.0
    except OverflowError:
        return repr(value)


def audit(rig, document, changes, strictly=False):
    """`strictly`: of a file that is not damaged. A note would be a false alarm."""
    text = text_of(document)
    path = rig.case_file(text)
    code, output = rig.run(["--state", path, "--audit"])
    beside, still_there = rig.beside(path), os.path.exists(path)
    rig.clean(path)
    if code == "hang":
        return "HANG", "reading"
    if code != 0:
        return "CRASH", "reading"
    kept = text in beside.values()
    if "STATE refused" in output:
        return ("refused",) if kept and not still_there else ("REFUSED AND NOT KEPT", str(sorted(map(os.path.basename, beside))))
    notes = int(re.search(r"^NOTES (\d+)", output, re.M).group(1))
    if (notes or kept) and strictly:
        return "NOTED", re.search(r"^NOTES \d+ (.*)$", output, re.M).group(1)[:150] or "tidied, and a copy made"
    if kept:
        return ("ok",)  # also where nobody is told: what was merely tidied is not counted among the notes
    if notes:
        return ("ok",) if kept else ("NOTED AND NOT KEPT", str(sorted(map(os.path.basename, beside))))
    # Nothing was noted, so no copy is made, and the next save is all there is. What was in the file that would not be
    # in that? The damaged place itself does not count (rubbish may go), nor what hangs under a renamed key's new name.
    try:
        saved = collections.Counter(facts(json.loads(re.search(r"^SAVED (.*)$", output, re.M).group(1))))
        was = collections.Counter(facts(json.loads(text)))
    except ValueError:
        return ("ok",)  # Numbers only Arbor's reader takes (1e999 is refused by Python's): nothing to compare.
    excused = []
    for where, what, value in changes:
        excused.append(tuple(where))
        if isinstance(where[-1], int):
            excused.append(tuple(where[:-1]))  # in a bag, or shifting the rest of a list
    for where, what, value in changes:
        if what == "key":  # whatever else was damaged under it now hangs under its new name
            old, new = tuple(where), tuple(where[:-1]) + (str(value),)
            excused += [new + root[len(old):] for root in list(excused) if root[:len(old)] == old]
    # What follows from the rest: `keeps` counts the names and views that keep a group, and the weights of one group
    # are brought to scale together.
    derived = {"keeps"} | ({"weight"} if any(where[-1] == "weight" for where, _, _ in changes) else set())
    gone = [fact for fact, times in was.items() if saved[fact] < times
            and not any(fact[0][:len(root)] == root for root in excused) and fact[0][-1] not in derived]
    if gone:
        return "SILENT LOSS", "%s%d, e.g. %s" % ("beside a number like 1e999: " if re.search(r"\de-?999\b", text) else "", len(gone),
                                                "; ".join(".".join(map(str, p)) + "=" + v[:30] for p, v in gone[:3]))
    return ("ok",)


# ---------------------------------------------------------------------------------------------------------------------
# The base files

def build_bases(rig):
    base = os.path.join(rig.work, "base")
    with open(os.path.join(base, "tabs.json"), "w") as file:
        file.write('{"tabsEnabled": true}\n')

    def session(arguments, lines, what):
        code, output = rig.run(arguments + ["quiet"] + lines + ["health"])
        failed = [line for line in output.splitlines() if line.startswith(("COMMAND FAILED", "usage:", "LAYOUT OUT OF DATE"))]
        if code != 0 or failed or "HEALTH ok" not in output:
            sys.exit("the session that makes %s went wrong (exit %s): %s\nBring the script in %s up to date."
                     % (what, code, "; ".join(failed[:3]) or output[-300:], os.path.basename(__file__)))

    states = {}
    for name, (windows, displays, lines) in BASE_SESSIONS.items():
        path = os.path.join(base, "state%s.json" % name)
        session(["--settings", os.path.join(base, "tabs.json"), "--windows", str(windows), "--displays", str(displays)],
                lines + ["save-state " + path], "state " + name)
        states[name] = json.load(open(path))
    states["A"]["workspaces"]["main"]["desktopIsOwedRoom"] = True  # takes a window that refuses its slot; simpler by hand
    states["A"]["hintsShown"] = {"peek": 2, "step-in": 1}  # counted by the app's panels, which the simulator does not have
    settings_path = os.path.join(base, "settings.json")
    session([], ["settings-file " + settings_path] + SETTINGS_SESSION, "settings.json")
    settings = json.load(open(settings_path))
    # The file holds only what differs from the defaults (Q27). Here every key is wanted, as in a file somebody wrote out in full, so that every
    # number, switch and choice gets damaged.
    code, output = rig.run(["quiet", "settings-file " + settings_path, "settings --json"])
    listed = json.loads(output[output.index("\n[\n"):output.rindex("]") + 1])
    settings = {**{entry["key"]: entry["value"] for entry in listed}, **settings}
    if len(settings) < 60:
        sys.exit("settings.json for the fuzzer has only %d keys: `settings --json` no longer lists them all?" % len(settings))
    settings["pauseForApps"] = ["com.example.game"]  # no command writes this list
    rig.copy_of_state = lambda: os.path.join(base, "stateA.json")
    check_bases(states)
    # Undamaged, they must come through everything: otherwise every start below finds the same thing.
    for name, state in sorted(states.items()):
        verdicts = {audit(rig, state, [], strictly=True)} | {launch_state(rig, state, [], windows, displays) for windows in (7, 0) for displays in (1, 2)}
        if verdicts != {("ok",)}:
            sys.exit("state %s, as Arbor saved it, does not come through: %s" % (name, sorted(verdicts - {("ok",)})))
    verdicts = {launch_settings(rig, settings, [], displays) for displays in (1, 2)}
    if verdicts != {("ok",)}:
        sys.exit("settings.json, as Arbor saved it, does not come through: %s" % sorted(verdicts - {("ok",)}))
    return states, settings


def check_bases(states):
    def keys(node):
        if isinstance(node, dict):
            for key, value in node.items():
                yield key
                yield from keys(value)
        elif isinstance(node, list):
            for value in node:
                yield from keys(value)
    missing = EXPECTED_KEYS - {key for state in states.values() for key in keys(state)}
    if missing:
        sys.exit("no base state has %s: the sessions in %s no longer make them" % (", ".join(sorted(missing)), os.path.basename(__file__)))


# ---------------------------------------------------------------------------------------------------------------------

def campaign(rig, options, what, kind, name, base):
    """Runs one kind of damage on one base file. Returns the number of findings."""
    rng = random.Random(options.seed)
    strings = STRINGS + (SETTINGS_STRINGS if what == "settings" else [])
    jobs = []
    for place, changes in cases(base, kind, strings, rng, options.several):
        document = copy.deepcopy(base)
        if not any([damaged(document, *change) for change in changes]):
            continue
        if what == "state":
            jobs += [(place, changes, document, (windows, displays)) for windows in (7, 0) for displays in (1, 2)]
        elif what == "settings":
            jobs += [(place, changes, document, (displays,)) for displays in (1, 2)]
        else:
            jobs.append((place, changes, document, ()))
    if options.limit and len(jobs) > options.limit:
        jobs = rng.sample(jobs, options.limit)
    run = {"state": launch_state, "settings": launch_settings, "audit": audit}[what]
    with ThreadPoolExecutor(max_workers=options.jobs) as pool:
        verdicts = list(pool.map(lambda job: run(rig, job[2], job[1], *job[3]), jobs))

    def relabelled(verdict, changes):
        """Known if the damage of any one place explains it: `several` damages places of every kind at once."""
        entries = [known(verdict, label(where)) for where, _, _ in changes] if len(verdict) > 1 else []
        return next((("known: " + entry, verdict[1]) for entry in entries if entry), verdict)
    verdicts = [relabelled(verdict, changes) for (_, changes, _, _), verdict in zip(jobs, verdicts)]
    rig.met.update(verdict[0][7:] for verdict in verdicts if verdict[0].startswith("known: "))
    tally = collections.Counter(verdict[0] for verdict in verdicts)
    title = "%s %s, %s" % (what, name, kind) if name else "%s, %s" % (what, kind)
    print("%-28s %6d  %s" % (title, len(jobs), "  ".join("%s %d" % item for item in sorted(tally.items()))), flush=True)
    seen = set()
    for (place, changes, document, how), verdict in zip(jobs, verdicts):
        # What was lost is spelt with the damage in it, which is different every time.
        finding = (place, verdict[0], "" if verdict[0] == "SILENT LOSS" else verdict[-1][:50])
        if verdict[0] in ("ok", "refused") or verdict[0].startswith("known: ") or finding in seen:
            continue
        seen.add(finding)
        path = os.path.join(rig.keep, "%s%s-%s-%d.json" % (what, name, kind, len(seen)))
        with open(path, "w", encoding="utf-8") as file:
            file.write(text_of(document))
        print("    %s at %s: %s" % (verdict[0], place, verdict[1]))
        print("        " + "; ".join("%s -> %s" % (".".join(map(str, p)), shown(v)) + (" (the key)" if w == "key" else "")
                                     for p, w, v in changes)
              + ("" if not how else "   windows, displays: " + ", ".join(map(str, how)) if len(how) == 2 else "   displays: %d" % how[0]))
        print("        " + path)
    return sum(count for verdict, count in tally.items() if verdict not in ("ok", "refused") and not verdict.startswith("known: "))


def earlier_versions(rig):
    """What an earlier Arbor saved is somebody's arrangement. Returns the number of files that do not come through."""
    found = 0
    for path in sorted(glob.glob(os.path.join(EARLIER, "*.json"))):
        state = json.load(open(path))
        verdicts = {audit(rig, state, [], strictly=True)} | {launch_state(rig, state, [], windows, displays) for windows in (7, 0) for displays in (1, 2)}
        wrong = sorted(verdicts - {("ok",)})
        print("%-28s %6d  %s" % ("earlier, " + os.path.basename(path)[:-5], 5, "ok" if not wrong else "; ".join(": ".join(verdict) for verdict in wrong)), flush=True)
        found += bool(wrong)
    return found


def situations():
    """(what, got, expected) for `scripts/test-tooling.py`: a judge that cannot see a planted mistake proves nothing."""
    script = ["quiet", "health", "dock 101 left", "health", "quit-check"]
    good = "STATE read\n> quiet\n> health\nHEALTH ok\n> dock 101 left\n> health\nHEALTH ok\n> quit-check\nQUIT ok\n"
    second = "> health\nHEALTH ok\n> quit"
    for what, code, output, expected in [
        ("all is well", 0, good, ("ok",)),
        ("the file was refused, and all is well", 0, good.replace("STATE read", "STATE refused"), ("refused",)),
        ("killed by a signal", -11, good[:good.index("HEALTH")], ("CRASH", "health")),
        ("a trap while starting", 132, "STATE read\n", ("CRASH", "while starting")),
        ("no end", "hang", good[:good.index(second)], ("HANG", "dock 101 left")),
        ("a rule is broken", 0, good.replace("HEALTH ok\n> quit", "HEALTH 1: w101 is lost\n> quit"), ("UNHEALTHY", "1: w101 is lost")),
        ("a display was not laid out again", 0, good.replace(second, "LAYOUT OUT OF DATE: main\n" + second), ("STALE LAYOUT", "main")),
        ("a window is out of view after quitting", 0, good.replace("QUIT ok", "QUIT 1 out of view: w101"),
         ("LOST AT QUIT", "1 out of view: w101")),
        ("a health line is missing", 0, good.replace(second, "> quit"), ("CUT SHORT", "1 of 2 health lines")),
        ("it ended before quitting", 0, good.replace("QUIT ok\n", ""), ("CUT SHORT", "2 of 2 health lines")),
    ]:
        yield "fuzz-launch.py: " + what, judge(code, output, script), expected

    document = {"a": {"7": [1, 2]}, "b": "x"}
    for what, change, expected in [
        ("a number is changed", (("a", "7", 0), "number", 5), {"a": {"7": [5, 2]}, "b": "x"}),
        ("a key is renamed", (("a", "7"), "key", 8), {"a": {"8": [1, 2]}, "b": "x"}),
        ("an element is doubled", (("a", "7", 1), "value", DOUBLE), {"a": {"7": [1, 2, 2]}, "b": "x"}),
        ("a value is deleted", (("b",), "value", DELETE), {"a": {"7": [1, 2]}}),
        ("a place that is not there is no damage", (("c", 0), "value", 1), None),
        ("the same value again is no damage", (("b",), "string", "x"), None),
        ("a place inside what has become text is not there", (("b", 0), "value", 1), None),
    ]:
        changed = copy.deepcopy(document)
        yield "fuzz-launch.py: " + what, changed if damaged(changed, *change) else None, expected
    squeezed = ("UNHEALTHY", "1: what is saved does not read back as it is: workspaces.main: frames were remembered for windows that …")
    yield "fuzz-launch.py: a known finding is known", known(squeezed, "workspaces.main.tree.nodes.*.weight"), "lopsided-weight"
    yield "fuzz-launch.py: the same from damage elsewhere is news", known(squeezed, "workspaces.main.camera"), None
    yield "fuzz-launch.py: a crash in the same place is news", known(("CRASH", "health"), "workspaces.main.tree.nodes.*.weight"), None
    shape, changed = [[]], {"a": 1}
    damaged(changed, ("a",), "value", shape)
    damaged(changed, ("a", 0), "value", "x")
    yield "fuzz-launch.py: damage within damage leaves the list of shapes alone", (changed, shape), ({"a": ["x"]}, [[]])
    yield "fuzz-launch.py: a number Python would not write", text_of({"a": "@RAW@1e999"}), '{"a": 1e999}'
    gone = collections.Counter(facts({"a": [1, 2, 3], "b": {"c": -0.0}})) - collections.Counter(facts({"a": [1, 3], "b": {"c": 0}}))
    yield "fuzz-launch.py: one of a list is gone, the rest did not move, -0 is 0", list(gone), [(("a",), "2.0")]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("what", nargs="?", choices=["state", "settings", "audit", "earlier", "all"])
    parser.add_argument("kinds", nargs="*", choices=KINDS + [[]], help="default: all four")
    parser.add_argument("--sim", default=os.path.join(ROOT, ".build", "debug", "arbor-sim"))
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 4)
    parser.add_argument("--limit", type=int, default=0, help="at most this many starts of each kind on each file, picked at random")
    parser.add_argument("--several", type=int, default=2500, help="how many files `several` makes")
    parser.add_argument("--seed", type=int, default=20261014)
    parser.add_argument("--timeout", type=float, default=30, help="seconds a start may take; raise it on a busy machine")
    parser.add_argument("--keep", help="where to keep the files that found something")
    parser.add_argument("--save-bases", metavar="PREFIX", help="also write the two state files as PREFIX-A.json and PREFIX-B.json")
    options = parser.parse_args()
    if not options.what:
        parser.error("say what to fuzz: state, settings, audit, earlier or all")
    if not os.access(options.sim, os.X_OK):
        sys.exit("there is no %s: run `make build` first" % options.sim)

    rig = Rig(options)
    states, settings = build_bases(rig)
    for name, state in states.items() if options.save_bases else []:
        with open("%s-%s.json" % (options.save_bases, name), "w") as file:
            json.dump(state, file, sort_keys=True)
            file.write("\n")
    found = earlier_versions(rig) if options.what in ("earlier", "all") else 0
    for what in {"all": ["state", "settings", "audit"], "earlier": []}.get(options.what, [options.what]):
        for name, base in [("", settings)] if what == "settings" else sorted(states.items()):
            for kind in options.kinds or KINDS:
                found += campaign(rig, options, what, kind, name, base)
    for name, _, _, _, owner, story in KNOWN:
        if name in rig.met:
            print("known: %s (%s): %s" % (name, owner, story))
        elif options.what == "all" and not options.kinds and not options.limit:
            print("KNOWN lists %s, which nothing met: if it is fixed, delete the entry" % name)
    if found:
        print("%d start(s) found something; the files are in %s" % (found, rig.keep))
    else:
        print("nothing found")
        if not options.keep:
            shutil.rmtree(rig.work, ignore_errors=True)
    sys.exit(1 if found else 0)


if __name__ == "__main__":
    main()
