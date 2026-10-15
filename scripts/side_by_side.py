"""A table of situations whose rows are worked out side by side.

The self-tests of what keeps private things out (test-public-check.py, test-public-clone.py) make a repository for each situation and ask git
some twenty things about it. One after the other that took a minute of everybody's `make lint`, nearly all of it spent waiting for git. The situations
have nothing to do with one another, so they can be played at once.

    table = Table()
    row = table.row                       row(what, got, expected), as ever

    @table.later                          a call of it begins at once, in a process of its own, and the script goes on; as many at a time as
    def situation(…): … row(…)            there are processors

    for what, got, expected in table.finish(exactly=352): …     in the order they were written down in, however they came in

Such a call sees everything as it is when it is made, and whatever it changes besides its own files is lost: it must stand by itself. (One that is
made from within another is simply made, there and then.)

These rows decide whether a change to those tools counts as sound, so none may be lost on the way and pass for one that held. Every call that
was begun is accounted for: one that does not get to its end, leaves by sys.exit, has nothing to say, takes longer than LIMIT, or whose process
dies, is one red row beside those it had made, and the others still have their say. And the script says how many rows there are: a number
that is written down and does not come from the run. Whoever adds rows or takes some out changes it.

$ARBOR_AT_ONCE says how many at a time, instead of the number of processors; 1: one after the other, in this process.
"""

import atexit
import os
import pickle
import shutil
import signal
import sys
import tempfile
import time
import traceback

# Seconds. The longest story there is takes a quarter of a minute, three times that on a machine that is busy.
LIMIT = 240


class Table:
    def __init__(self, at_once=None, limit=LIMIT):
        self.rows, self.running, self.place, self.folder, self.playing, self.limit, self.most = [], {}, 0, None, False, limit, 0
        wanted = os.environ.get("ARBOR_AT_ONCE", "").strip()
        if not at_once and wanted and not wanted.lstrip("-").isdigit():
            sys.exit(f"ARBOR_AT_ONCE is {wanted!r}: a whole number is wanted")
        self.at_once = (at_once or int(wanted or 0) or os.cpu_count() or 1) if hasattr(os, "fork") else 1

    def row(self, what, got, expected):
        self.rows.append((self.place, len(self.rows), what, got, expected))

    def later(self, function):
        def begun(*arguments, **more):
            if self.playing:
                return function(*arguments, **more)
            self.place += 1
            self.begin(self.place, f"{function.__name__}, the {self.place // 2 + 1}th to be begun,", lambda: function(*arguments, **more))
            self.place += 1
            return None
        return begun

    def play(self, name, job):
        before, self.playing = len(self.rows), True
        try:
            job()
            if len(self.rows) == before:
                self.row(f"{name} has something to say", "not a row", "a row at least")
        except (Exception, SystemExit) as error:  # a git that behaves otherwise, say
            lines = [frame.lineno for frame in traceback.extract_tb(error.__traceback__) if frame.filename != __file__]
            self.row(f"{name} gets to its end", f"line {lines[-1] if lines else '?'}: {type(error).__name__}: {error}", "it does")
        finally:
            self.playing = False

    def begin(self, place, name, job):
        if self.at_once < 2:
            return self.play(name, job)
        while len(self.running) >= self.at_once:
            self.take_in()
        if not self.folder:
            self.folder = tempfile.mkdtemp()
            atexit.register(self.give_up)  # should the script not get as far as finish()
        sys.stdout.flush()  # or what waits there to be printed is printed by the child as well
        sys.stderr.flush()
        child = os.fork()
        if child == 0:
            code = 1
            try:
                self.rows = []
                self.play(name, job)
                with open(os.path.join(self.folder, f"{place}.part"), "wb") as handle:
                    pickle.dump(self.rows, handle)
                os.rename(os.path.join(self.folder, f"{place}.part"), os.path.join(self.folder, str(place)))
                code = 0
            except BaseException:  # the parent sees only that something is missing: this says what
                traceback.print_exc()
            finally:
                os._exit(code)  # not the parent's way out: what the parent has open and has to clear away is the parent's
        self.running[child] = (place, name, time.monotonic())
        self.most = max(self.most, len(self.running))
        return None

    def take_in(self):
        """Waits until one of them has ended, and takes in what it has to say. Only its own: a process of somebody else's is theirs to wait for."""
        while True:
            for child, (place, name, began) in self.running.items():
                ended, status = os.waitpid(child, os.WNOHANG)
                if not ended and time.monotonic() - began > self.limit:
                    os.kill(child, signal.SIGKILL)
                    ended, status = os.waitpid(child, 0)
                    status = f"{status}, having been stopped after {self.limit} seconds"
                if ended:
                    del self.running[child]
                    try:
                        if status != 0:
                            raise OSError("it did not end well")
                        with open(os.path.join(self.folder, str(place)), "rb") as handle:
                            self.rows += pickle.load(handle)
                    except Exception as error:  # whatever it is: what it had to say is not to be had
                        self.rows.append((place, 0, f"{name} gets to its end", f"its process ended with status {status} ({type(error).__name__}: {error})", "it does"))
                    return
            time.sleep(0.005)

    def give_up(self):
        for child in self.running:
            try:
                os.kill(child, signal.SIGKILL)
                os.waitpid(child, 0)
            except OSError:
                pass
        self.running = {}
        if self.folder:
            shutil.rmtree(self.folder, ignore_errors=True)
            self.folder = None

    def finish(self, exactly=None):
        while self.running:
            self.take_in()
        self.give_up()
        if exactly is not None and len(self.rows) != exactly:
            self.place += 1
            self.row("there are as many rows as are written down: whoever added some or took some out changes the number", len(self.rows), exactly)
        return [(what, got, expected) for _, _, what, got, expected in sorted(self.rows, key=lambda one: one[:2])]


# MARK: its own rows

class Odd(Exception):
    """Can be written down and not be read again."""

    def __init__(self, one, other):
        super().__init__(one)


def played(at_once, limit=LIMIT):
    """One table with everything that can happen in it, and what became of it."""
    table = Table(at_once=at_once, limit=limit)
    parent, word = os.getpid(), "then"

    @table.later
    def waits(name, seconds=0.0):
        time.sleep(seconds)
        table.row(name, os.getpid() != parent, at_once > 1)
        table.row(name + ", again", 2, 2)
        table.row(name + ", a third time", 3, 3)

    @table.later
    def reads():
        time.sleep(0.1)
        table.row("as it was", word, "then")

    @table.later
    def is_wrong():
        table.row("wrong", 1, 2)

    @table.later
    def trips():
        table.row("before it trips", 1, 1)
        raise RuntimeError("over something")

    @table.later
    def leaves():
        sys.exit(0)

    @table.later
    def dies():
        os._exit(0) if at_once > 1 else sys.exit(0)

    @table.later
    def says_nothing():
        pass

    @table.later
    def says_much():
        table.row("a megabyte", "x" * 1_000_000, "x" * 1_000_000)

    @table.later
    def says_what_cannot_be_handed_on():
        table.row("a function", (lambda: 1) if at_once > 1 else None, None)

    @table.later
    def says_what_cannot_be_taken_in():
        table.row("something odd", Odd(1, 2) if at_once > 1 else None, None)

    @table.later
    def calls_others():
        table.row("outer begins", 1, 1)
        is_wrong()
        table.row("outer ends", 1, 1)

    @table.later
    def never_ends():
        table.row("it began", 1, 1)
        time.sleep(60)
    began = time.monotonic()
    table.row("first", 1, 1)
    reads()
    word = "now"
    waits("second", seconds=0.5)
    table.row("third", 1, 1)
    waits("fourth", 0.1)
    waits("fifth", 0.6)
    for one in (is_wrong, trips, leaves, dies, says_nothing, says_much, says_what_cannot_be_handed_on, says_what_cannot_be_taken_in, calls_others):
        one()
    if limit != LIMIT:
        never_ends()
    table.row("last", 1, 1)
    folder = table.folder
    rows = table.finish(exactly=1)
    short = lambda what: what.split(",")[0] if "to be begun" in what else what
    return {"names": [short(what) for what, _, _ in rows], "red": [short(what) for what, got, expected in rows if got != expected], "rows": rows,
            "took": time.monotonic() - began, "most": table.most, "left": bool(folder and os.path.exists(folder)) or table.folder is not None}


def self_test():
    names = ["first", "as it was", "second", "second, again", "second, a third time", "third", "fourth", "fourth, again", "fourth, a third time", "fifth", "fifth, again", "fifth, a third time",
             "wrong", "before it trips", "trips", "leaves", "dies", "says_nothing", "a megabyte", "says_what_cannot_be_handed_on", "says_what_cannot_be_taken_in", "outer begins", "wrong", "outer ends", "last"]
    count = "there are as many rows as are written down: whoever added some or took some out changes the number"
    red = ["wrong", "trips", "leaves", "dies", "says_nothing", "says_what_cannot_be_handed_on", "says_what_cannot_be_taken_in", "wrong", count]
    sys.stderr.flush()
    quiet, kept = os.open(os.devnull, os.O_WRONLY), os.dup(2)
    os.dup2(quiet, 2)  # a child that cannot hand on what it has says why, which is for whoever reads a real run
    try:
        four, one, hurried = played(4), played(1), played(3, limit=1.5)
    finally:
        os.dup2(kept, 2)
    said = {what.split(",")[0]: got for what, got, _ in four["rows"] if "to be begun" in what}
    in_one = lambda listed: [{"says_what_cannot_be_handed_on": "a function", "says_what_cannot_be_taken_in": "something odd"}.get(name, name) for name in listed]  # nothing is handed on there
    table = [
        ("in the order they were written down in, each row of each", four["names"], names + [count]),
        ("red is what is wrong, what trips, leaves, dies, says nothing or what cannot be handed on or taken in, and the count: nothing else, and all of it", four["red"], red),
        ("one that trips says where and over what", said["trips"].split(": ", 1)[1], "RuntimeError: over something"),
        ("one that leaves by sys.exit, with 0 at that", said["leaves"].split(": ", 1)[1], "SystemExit: 0"),
        ("one whose process dies without a word, with 0 at that", "its process ended with status 0 (FileNotFoundError" in said["dies"], True),
        ("the count says how many there are and how many are written down", [(got, expected) for what, got, expected in four["rows"] if what == count], [(len(names), 1)]),
        ("side by side: 1.3 seconds of waiting take less than one", four["took"] < 1.0, True),
        ("as many at a time as was said, and no more", (four["most"], hurried["most"]), (4, 3)),
        ("nothing is left lying about", (four["left"], one["left"], hurried["left"]), (False, False, False)),
        ("one after the other comes to the same", (one["names"], one["red"]), (in_one(names) + [count], [name for name in red if not name.startswith("says_what")])),
        ("in this very process", one["most"], 0),
        ("one that never ends is stopped, and is red; what it had said is lost with it", [(what.split(",")[0], "having been stopped after 1.5 seconds" in got) for what, got, _ in hurried["rows"] if "never_ends" in what],
         [("never_ends", True)]),
        ("the others are none the worse for it", [name for name in hurried["names"] if name != "never_ends"], names + [count]),
        ("the right count: not a word", exact(3), ["a", "b", "c"]),
        ("$ARBOR_AT_ONCE", [asked(value) for value in ("", "0", "1", " 3 ", "-2")], [os.cpu_count() or 1, os.cpu_count() or 1, 1, 3, -2]),
        ("which is no number", asked("four"), "ARBOR_AT_ONCE is 'four': a whole number is wanted"),
        ("without fork, one after the other", without_fork(), 1),
        ("somebody else's process is theirs to wait for", somebody_elses(), 3),
        ("what the script had yet to print is printed once", printed_once(), 1),
        ("a script that does not get as far as finish() leaves nothing behind", abandoned(), (False, False)),
    ]
    wrong = [f"✘ {what}: expected {expected!r}, got {got!r}" for what, got, expected in table if got != expected]
    print("\n".join(wrong + [f"{len(table) - len(wrong)} of {len(table)} side-by-side situations came out as expected"]))
    return 1 if wrong else 0


def exact(number):
    table = Table(at_once=2)
    begun = table.later(lambda name: table.row(name, 1, 1))
    table.row("a", 1, 1)
    begun(name="b")
    table.row("c", 1, 1)
    return [what for what, _, _ in table.finish(exactly=number)]


def asked(value):
    saved, os.environ["ARBOR_AT_ONCE"] = os.environ.get("ARBOR_AT_ONCE"), value
    try:
        return Table().at_once
    except SystemExit as left:
        return left.code
    finally:
        del os.environ["ARBOR_AT_ONCE"]
        if saved is not None:
            os.environ["ARBOR_AT_ONCE"] = saved


def without_fork():
    fork = os.fork
    del os.fork
    try:
        return Table(at_once=4).at_once
    finally:
        os.fork = fork


def somebody_elses():
    import subprocess
    table = Table(at_once=2)
    begun = table.later(lambda: (time.sleep(0.05), table.row("x", 1, 1)))
    with subprocess.Popen([sys.executable, "-c", "import sys; sys.exit(3)"]) as theirs:
        time.sleep(0.3)
        for _ in range(4):
            begun()
        table.finish()
        return theirs.wait()


def in_a_script(text):
    import subprocess
    return subprocess.run([sys.executable, "-c", f"import sys; sys.path.insert(0, {os.path.dirname(os.path.abspath(__file__))!r})\nimport os, time, side_by_side\n" + text],
                          capture_output=True, text=True, check=False, env={key: value for key, value in os.environ.items() if key != "PYTHONUNBUFFERED"})


def printed_once():
    done = in_a_script("table = side_by_side.Table(at_once=2)\nprint('once', end=' ')\ntable.later(lambda: (print('x' * 100000), table.row('a', 1, 1)))()\ntable.finish()\n")
    return done.stdout.count("once")


def abandoned():
    done = in_a_script("table = side_by_side.Table(at_once=2)\ntable.later(lambda: time.sleep(60))()\nprint(table.folder, list(table.running)[0])\nraise RuntimeError\n")
    folder, child = done.stdout.split()
    try:
        os.kill(int(child), 0)
        alive = True
    except OSError:
        alive = False
    return os.path.exists(folder), alive


if __name__ == "__main__":
    try:
        verdict = self_test()
    except SystemExit as left:  # one of the things it is there to catch
        verdict = f"✘ the self-test was left by sys.exit({left.code})"
    sys.exit(verdict)
