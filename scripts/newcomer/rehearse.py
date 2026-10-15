#!/usr/bin/env python3
"""Tries the newcomer's rig from end to end without a Mac and without GitHub: part of `make lint`.

    scripts/newcomer/rehearse.py [-v]

Everything is the real thing but two ends: the Mac is fakemac.py, and GitHub is a bare repository in a temporary folder. The courier pushes
pictures to it, a clone of the screen branch is all the "newcomer" has, and it plays with the kit's own script, run by `sh`. So this tries
the protocol, the language, what is refused before it becomes public, nonsense, time limits, a run that is cut off, the journal and the score. It proves the rig,
not Arbor and not macOS.
"""

import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
VERBOSE = "-v" in sys.argv[1:]
WORLD = {"display": [0, 0, 1440, 900], "visible": [0, 25, 1440, 800], "windows": [
    {"id": 10, "owner": "Archive", "frame": [1100, 600, 300, 200]}, {"id": 11, "owner": "TextEdit", "frame": [100, 100, 500, 400]},
    {"id": 12, "owner": "Safari", "frame": [300, 150, 700, 500]}, {"id": 13, "owner": "Calendar", "frame": [200, 200, 800, 500]},
    {"id": 14, "owner": "Notes", "frame": [600, 300, 400, 300]}, {"id": 15, "owner": "Finder", "frame": [50, 450, 500, 300]}]}
CAST = "textedit=11,safari=12,calendar=13,notes=14,finder=15"
failures = []


def check(name, fine, more=""):
    if not fine:
        failures.append(name)
    if VERBOSE or not fine:
        print("%s %s%s" % ("✔" if fine else "✘", name, "" if fine else ": %s" % more))


def git(folder, *arguments, **keywords):
    return subprocess.run(["git", "-C", folder] + list(arguments), stdout=subprocess.PIPE, stderr=subprocess.PIPE, **keywords)


class Run:
    """One run of the rig, with its courier, its GitHub and its newcomer's clone."""

    def __init__(self, work, name, arm, *more):
        self.name, self.folder = name, os.path.join(work, name)
        self.origin, self.box, self.out, self.kit = (os.path.join(self.folder, each) for each in ("origin.git", "box", "out", "kit"))
        os.makedirs(self.out)
        subprocess.run(["git", "init", "--quiet", "--bare", self.origin], check=True)
        subprocess.run([os.path.join(HERE, "lay-kit.sh"), self.box, name, arm, os.path.join(ROOT, "README.md")], check=True)
        with open(os.path.join(self.folder, "world.json"), "w") as file:
            json.dump(WORLD, file)
        self.courier = subprocess.Popen(["bash", os.path.join(HERE, "courier.sh"), self.box, self.origin, name], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                                        env=dict(os.environ, TZ="UTC"))
        self.courier.stdin.write(b"\n")
        self.courier.stdin.close()
        self.rig = subprocess.Popen([sys.executable, os.path.join(HERE, "rig.py"), "--run", name, "--arm", arm, "--box", self.box, "--remote", self.origin,
                                     "--out", self.out, "--cast", CAST, "--build", "abc1234", "--system", "0.0", "--fake", os.path.join(self.folder, "world.json"),
                                     "--poll", "0.03", "--haste", "0.05"] + list(more))

    def branch(self, which):
        return "mac-shell-out/newcomer.%s.%s" % (self.name, which)

    def clone(self):
        limit = time.time() + 20
        while git(self.origin, "rev-parse", "--verify", "--quiet", "refs/heads/" + self.branch("screen")).returncode != 0:
            if time.time() > limit:
                raise SystemExit("rehearse.py: no first picture within 20 s")
            time.sleep(0.05)
        subprocess.run(["git", "clone", "--quiet", "--depth", "1", "--single-branch", "--branch", self.branch("screen"), "file://" + self.origin, self.kit], check=True)

    def mac(self, *words):
        """What the newcomer types: (exit code, what it read)."""
        done = subprocess.run(["sh", "./mac"] + list(words), cwd=self.kit, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              env=dict(os.environ, NEWCOMER_NAP="0.03", NEWCOMER_TRIES="400", TZ="America/Los_Angeles"))
        if VERBOSE:
            print("    $ ./mac %s\n%s" % (" ".join(words), "".join("      %s\n" % line for line in done.stdout.decode().split("\n") if line)), end="")
        return done.returncode, done.stdout.decode()

    def raw(self, data):
        """A message nobody's script has looked at, as anybody who can push could leave it. Returns the status after it."""
        before = open(os.path.join(self.kit, "round")).read()
        blob = git(self.kit, "hash-object", "-w", "--stdin", input=data).stdout.decode().strip()
        tree = git(self.kit, "mktree", input=("100644 blob %s\taction\n" % blob).encode()).stdout.decode().strip()
        identity = dict(os.environ, GIT_AUTHOR_NAME="x", GIT_AUTHOR_EMAIL="x@users.noreply.github.com", GIT_COMMITTER_NAME="x", GIT_COMMITTER_EMAIL="x@users.noreply.github.com")
        commit = git(self.kit, "commit-tree", tree, "-m", "mac-shell: junk %f" % time.time(), env=identity).stdout.decode().strip()
        git(self.kit, "push", "--quiet", "--force", "origin", "%s:refs/heads/%s" % (commit, self.branch("action")))
        limit = time.time() + 10
        while time.time() < limit:
            said = self.mac("look")[1]
            if open(os.path.join(self.kit, "round")).read() != before:
                return said
            time.sleep(0.03)
        return "(no answer)"

    def round(self):
        return open(os.path.join(self.kit, "round")).read().strip().encode()

    def end(self, patience=20):
        try:
            code = self.rig.wait(patience)
        except subprocess.TimeoutExpired:
            self.rig.kill()
            code = "still running"
        open(os.path.join(self.box, "stop"), "w").close()
        try:
            self.courier.wait(10)
        except subprocess.TimeoutExpired:
            self.courier.kill()
            check("%s: the courier ends when it is told to" % self.name, False)
        return code

    def journal(self):
        """As it comes back: from the record branch."""
        text = git(self.origin, "show", "refs/heads/%s:journal.jsonl" % self.branch("record")).stdout.decode()
        return [json.loads(line) for line in text.split("\n") if line]


def holder():
    """The one name the repository's check knows, read from where it reads it."""
    with open(os.path.join(ROOT, "LICENSE")) as file:
        line = next(line for line in file if line.startswith("Copyright"))
    return " ".join(word for word in line.split() if word.isalpha() and word != "Copyright")


def no_python(work):
    """A PATH with git and the shell's usual tools, and no python3."""
    folder = os.path.join(work, "no-python")
    os.makedirs(folder, exist_ok=True)
    for tool in ("git", "sh", "cat", "sed", "cut", "wc", "grep", "dirname", "sleep", "rm", "mv"):
        if not os.path.exists(os.path.join(folder, tool)):
            os.symlink(shutil.which(tool), os.path.join(folder, tool))
    return folder


def functions(kit):
    """The functions of ./mac by themselves, to ask them one at a time."""
    text = open(os.path.join(kit, "mac")).read()
    with open(os.path.join(kit, "functions"), "w") as file:
        file.write(text[text.index("is_modifier()"):text.index("# clean <text>")])
    return kit


def ends(journal):
    return {entry["task"]: (entry["how"], entry["done"]) for entry in journal if entry["kind"] == "task-end"}


def with_arbor(work):
    run = Run(work, "with", "arbor", "--limits", "back=0.01")
    run.clone()
    files = sorted(os.listdir(run.kit))
    check("the newcomer gets its script, its words of use, the README's first screen, a picture, and nothing of the source",
          files == [".git", "HOWTO.md", "LICENSE", "README-first-screen.md", "answers", "check", "mac", "round", "run", "screen.jpg", "status.txt"], files)
    check("the words of use are whole", "@ABOUT@" not in open(os.path.join(run.kit, "HOWTO.md")).read() and "called Arbor" in open(os.path.join(run.kit, "HOWTO.md")).read())
    check("before `ready` nothing has begun", "Nothing has begun" in run.mac("look")[1])
    check("and an act is not carried out", "nothing has begun yet" in run.mac("click", "5", "5")[1])
    check("ready: the first task", "task 1 of 8" in run.mac("ready")[1])

    # What must not become public is stopped on the newcomer's side, before anything is written to Git. (Spelled in two halves, or this file would not pass either.)
    tip = git(run.origin, "rev-parse", "refs/heads/" + run.branch("action")).stdout
    for name, words in (("a path", ("surprised", "see /Us" "ers/somebody/x")), ("an address", ("type", "write to me@example.org")), ("an id of a session", ("type", "session" "_0123456789abcdefghijklmn")),
                        ("a link", ("stuck", "https://example.org")), ("what is not ASCII", ("surprised", "⌘ did nothing")), ("a word that is none", ("sudo", "rm")),
                        ("a remark of 201 characters", ("wrong", "x" * 201)), ("words after an act", ("click", "my", "neighbour", "lives", "in", "Berlin")), ("words after done", ("done", "it", "was", "easy")),
                        ("a host after wait", ("wait", "wiki.example.org")), ("a path after password", ("password", "/etc/hosts")), ("an id after release", ("release", "0123abcd-0123-abcd")),
                        ("a path in giving up", ("giveup", "see /etc/hosts")), ("121 characters to type", ("type", "x" * 121)), ("a key that is none", ("key", "cmd+banana")),
                        ("a line hidden in an argument", ("click", "1", "2\nstuck at home")), ("the name in LICENSE", ("surprised", holder()))):
        check("refused by ./mac: %s" % name, run.mac(*words)[0] == 1)
    for name, environment, words_file in (("there is no python3", {"PATH": no_python(work)}, ""), ("the check cannot tell", {}, "/nowhere/at/all")):
        if words_file:
            git(run.kit, "config", "arbor.privateWords", words_file)
        done = subprocess.run(["sh", "./mac", "stuck", "nothing private in this"], cwd=run.kit, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=dict(os.environ, **environment))
        git(run.kit, "config", "--unset", "arbor.privateWords")
        check("words are not sent when %s" % name, done.returncode == 1, done.stdout.decode())
    for words in (("key", "fn+ctrl+left"), ("key", "cmd+shift+["), ("key", "'"), ("key", "7"), ("scroll", "5", "5", "-3", "holding", "ctrl+opt"), ("drag", "1", "2", "3", "4", "holding", "fn+cmd", "keep")):
        check("not refused: %s" % " ".join(words), subprocess.run(["sh", "-c", 'verb=$1; shift; . ./functions; numbers_and_names "$@"', "sh"] + list(words), cwd=functions(run.kit)).returncode == 0)
    check("and nothing of that was pushed or kept", git(run.origin, "rev-parse", "refs/heads/" + run.branch("action")).stdout == tip and not os.path.exists(os.path.join(run.kit, ".remarks")))

    # Nonsense, as somebody could push it who does not use the script.
    for name, data, wanted in (
            ("bytes that are no text", b"\xff\xfe\x00\x01", "plain ASCII"), ("a megabyte", b"1\n" + b"x" * 1000000, "plain ASCII"), ("no number", b"click 1 1\n", "begins with the number"),
            ("a place off the picture", run.round, "between 0 and 1439"),
            ("two acts", None, "one act to a message"), ("a shell's words", None, "does not belong after click"), ("a key that is none", None, "there is no key"),
            ("a remark with a path in it", None, "a remark is letters")):
        number = run.round()
        data = {"a place off the picture": number + b"\nclick 5000 5\n", "two acts": number + b"\nclick 1 1\nclick 2 2\n", "a shell's words": number + b"\nclick 1 1 ; rm -rf /\n",
                "a key that is none": number + b"\nkey cmd+$(id)\n", "a remark with a path in it": number + b"\nstuck /etc/passwd\nwait 1\n"}.get(name, data)
        said = run.raw(data)
        check("not understood, and said so: %s" % name, "not understood, and nothing was done" in said and wanted in said, said)

    check("install: the download is opened", "your last word: double-click 1200 700" in run.mac("double-click", "1200", "700")[1])
    check("the password is typed for it", "typed for you" in run.mac("password")[1])
    check("done: the next task", "task 2 of 8" in run.mac("done")[1])
    check("from ready on the first picture is kept", os.path.exists(os.path.join(run.kit, "first.jpg")))
    # What the Mac's account could do to the folder the courier pushes must not run in the newcomer's.
    with open(os.path.join(run.box, "screen", "mac"), "a") as file:
        file.write("echo overwritten\n")
    run.mac("drag", "110", "105", "6", "400")
    check("a remark waits for the next act", run.mac("surprised", "another window went away, I had touched only one")[1].startswith("noted"))
    run.mac("drag", "950", "155", "1439", "400", "keep")
    run.mac("release")
    check("the script that runs is the one that was cloned, whatever is pushed later", "overwritten" not in open(os.path.join(run.kit, "mac")).read())
    check("task 3", "task 3 of 8" in run.mac("done")[1])
    run.mac("double-click", "900", "30")
    run.mac("key", "ctrl+opt+z")
    check("task 4", "task 4 of 8" in run.mac("done")[1])
    run.mac("key", "cmd+tab", "cmd+tab", "cmd+tab")
    run.mac("key", "f5")
    run.mac("double-click", "300", "210")
    check("task 5", "task 5 of 8" in run.mac("done")[1])
    run.mac("lookup", "how to switch windows: the Window menu")
    run.mac("key", "cmd+tab", "cmd+tab", "cmd+tab", "cmd+tab")
    run.mac("key", "cmd+tab")
    check("task 6", "task 6 of 8" in run.mac("done")[1])
    check("giving up: task 7", "task 7 of 8" in run.mac("giveup", "the Finder window is nowhere to be seen")[1])
    time.sleep(1)
    said = run.mac("click", "700", "30")[1]
    check("its time runs out, which the next picture says", "task 8 of 8" in said and "the time for the task before this one was up" in said, said)
    check("and a word that was on its way is not carried out, which its sender is told", "was NOT carried out" in said, said)
    check("the next word is in step again", "your last word: key ctrl+opt+q" in run.mac("key", "ctrl+opt+q")[1])
    check("after the last task it is over", "That was the last task" in run.mac("done")[1])
    check("and nothing more is sent", run.mac("click", "1", "1")[0] == 1)
    check("the rig ends well", run.end() == 0)

    journal = run.journal()
    check("the journal comes back on the record branch, whole", journal and journal[0]["kind"] == "run" and journal[-1] == dict(journal[-1], kind="end", how="played"), journal[-1:])
    check("what became of each task", ends(journal) == {"install": ("done", True), "side-by-side": ("done", True), "return": ("done", True), "fill": ("done", False), "find": ("done", True),
                                                        "undo": ("giveup", False), "back": ("time", False), "quit": ("done", False)}, ends(journal))
    rounds = [entry for entry in journal if entry["kind"] == "round"]
    first_drag = next(entry for entry in rounds if entry["verb"] == "drag")
    check("the window that was dragged was touched", "11" in first_drag["touched"] and [each["id"] for each in first_drag["moved"]] == ["11", "15"], first_drag)
    check("the one that was pushed away was not", "15" not in first_drag["touched"])
    check("a key that does nothing changes nothing on the screen", next(entry for entry in rounds if entry["line"] == "key f5")["cells"] == 0)
    check("what Arbor takes back is seen", any("it did not stay" in note for entry in journal if entry["kind"] == "task-end" for note in entry["notes"]))
    check("remarks are kept with their task and picture", [(entry["task"], entry["verb"]) for entry in journal if entry["kind"] == "remark"]
          == [("side-by-side", "surprised"), ("find", "lookup"), ("undo", "giveup")])
    check("nonsense is counted, and none of it is kept", len([entry for entry in journal if entry["kind"] == "nonsense"]) == 8 and len([entry for entry in journal if entry["kind"] == "late"]) == 1 and "passwd" not in json.dumps(journal) and "rm -rf" not in json.dumps(journal))
    check("nor is any of it quoted", all(quoted == "…" for entry in journal if entry["kind"] == "nonsense" for quoted in re.findall(r"'([^']*)'", entry["why"])))
    check("what Arbor took back after the last act was moved by nobody", [each["owner"] for entry in journal if entry["kind"] == "task-end" and entry["task"] == "fill" for each in entry["idle_moved"]] == ["Calendar"])
    check("a drag that ends a few pixels short of the edge ends on it", next(entry for entry in rounds if entry["line"] == "drag 110 105 6 400")["moved"][0]["to"][:2] == [0, 25])
    check("every part of a round was timed", all(part in rounds[3]["timing"] for part in ("shot", "push", "thought", "fetch", "act", "settle")), rounds[3]["timing"])
    for which in ("screen", "action", "record"):
        log = git(run.origin, "log", "--format=%ae %ad %s", "--date=format:%z", "refs/heads/" + run.branch(which)).stdout.decode().strip().split("\n")
        check("the %s branch is one commit, made as the output of a Mac shell run is, and tells no time zone" % which,
              len(log) == 1 and log[0].startswith("mac-shell@users.noreply.github.com +0000 mac-shell: "), log)
    check("every picture is kept, small", len(os.listdir(os.path.join(run.out, "screens"))) == int(run.round()), os.listdir(os.path.join(run.out, "screens"))[-3:])
    return run


def macos_alone(work):
    run = Run(work, "alone", "macos")
    run.clone()
    check("macOS alone: no README of Arbor's", not os.path.exists(os.path.join(run.kit, "README-first-screen.md")) and "Arbor" not in open(os.path.join(run.kit, "HOWTO.md")).read())
    check("macOS alone: six tasks", "task 1 of 6" in run.mac("ready")[1])
    for words in (("drag", "110", "105", "0", "400"), ("drag", "950", "155", "1439", "400"), ("done",), ("double-click", "900", "30"), ("double-click", "900", "30"), ("done",),
                  ("key", "cmd+tab", "cmd+tab", "cmd+tab"), ("double-click", "300", "210"), ("done",),
                  ("key", "cmd+tab", "cmd+tab", "cmd+tab", "cmd+tab"), ("key", "cmd+tab"), ("done",)):
        run.mac(*words)
    # Cut off in the middle of a task, as a job that is cancelled or out of time is.
    run.rig.send_signal(signal.SIGTERM)
    check("cut off, the rig still ends by itself", run.end() == 0)
    journal = run.journal()
    check("and what there was comes back", ends(journal) == {"side-by-side": ("done", True), "return": ("done", True), "fill": ("done", True), "find": ("done", True), "undo": ("cut", False)} and journal[-1]["how"] == "cut", ends(journal))
    check("without Arbor nothing moved that was not touched", not [each for entry in journal if entry["kind"] == "round" for each in entry["moved"] if each["id"] not in entry["touched"]])
    return run


def nobody(work):
    run = Run(work, "nobody", "macos", "--patience", "0.3")
    check("nobody says ready: the rig gives the Mac back", run.end() == 3)
    check("and says so", run.journal()[-1]["how"] == "nobody came")


def main():
    work = tempfile.mkdtemp(prefix="newcomer-rehearsal-")
    try:
        began = time.time()
        first, second = with_arbor(work), macos_alone(work)
        nobody(work)
        for run in (first, second):
            shutil.copy(os.path.join(run.out, "journal.jsonl"), os.path.join(run.folder, "journal.jsonl"))
        score = subprocess.run([sys.executable, os.path.join(HERE, "score.py"), first.folder, second.folder], stdout=subprocess.PIPE).stdout.decode()
        if VERBOSE:
            print(score)
        for wanted in ("| two windows side by side | Arbor abc1234 | yes | 3 | 0 | 0 | 1 | 0 | 1 | 1 |", "|  | macOS alone | yes | 2 | 0 | 0 | 0 | 0 | 0 | 0 |", "| WORSE |",
                       "| one window fills the screen, and stays | Arbor abc1234 | NO (thought so) |", "| install and start it | Arbor abc1234 | yes | 2 |", "a cost macOS alone does not have",
                       "**surprised**: another window went away, I had touched only one"):
            check("the score has: %s" % wanted, wanted in score, score)
        print("newcomer: the rehearsal %s (%d s)" % ("FAILED: %d" % len(failures) if failures else "passed", time.time() - began))
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
