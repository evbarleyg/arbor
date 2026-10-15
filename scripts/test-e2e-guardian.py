#!/usr/bin/env python3
"""Holds arbor-e2e's guardian to a table of endings: whatever becomes of the runner, is an Arbor, a watchdog or a folder left?

The guardian is a program in Perl inside Sources/arbor-e2e/Guardian.swift, which only a Mac compiles. The program itself needs no Mac. This
reads it out of that file and runs it as the runner does, against stand-ins:

  - for Arbor and its watchdog, a small C program. Like Arbor it makes its folder, takes the lock in it as `InstanceLock` does (ten tries, then it
    leaves with 75, having started nothing), writes its number into the file, quits when asked and tells its watchdog so, and is started again when
    it ends any other way. It can be deaf to SIGTERM, and slow to reach the lock;
  - for the runner, a few lines of Python in a process group of their own, ended as the row says.

Rows named "control" leave a part out and must come out badly: a table that cannot fail proves nothing.

`make check` runs this through scripts/test-tooling.py; by itself it prints its rows (`-v`: all of them). It also runs on a Mac, with macOS's own
perl and locks. Under half a minute: the rows run side by side, and most of a row is the guardian waiting.
"""

import concurrent.futures
import itertools
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(os.path.dirname(HERE), "Sources", "arbor-e2e", "Guardian.swift")

STAND_IN = r"""
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>

static int line = -1;

static void note(const char *what) {
  FILE *log = fopen(getenv("STAND_IN_LOG"), "a");
  if (log) { fprintf(log, "%s %d\n", what, (int)getpid()); fclose(log); }
}

static void quit(int number) {
  (void)number;
  note("asked");
  if (line >= 0 && write(line, "q", 1) != 1) _exit(1);
  _exit(0);
}

int main(int count, char **arguments) {
  alarm(120);  // Whatever goes wrong with the table, nothing of it stays.
  if (count == 3 && strcmp(arguments[1], "--watchdog") == 0) {
    char byte;
    note("watchdog");
    if (read(0, &byte, 1) == 1 && byte == 'q') return 0;
    usleep(300000);
    setenv("ARBOR_RESTARTS", "1", 1);
    if (fork() == 0) { execl(arguments[0], arguments[0], (char *)0); _exit(1); }
    return 0;
  }
  note("arbor");
  if (getenv("ARBOR_RESTARTS") && getenv("STAND_IN_SLOW")) usleep(atoi(getenv("STAND_IN_SLOW")) * 1000);
  char path[4096], number[16];
  mkdir(getenv("ARBOR_HOME"), 0700);
  snprintf(path, sizeof path, "%s/arbor.lock", getenv("ARBOR_HOME"));
  snprintf(number, sizeof number, "%d\n", (int)getpid());
  int lock = open(path, O_RDWR | O_CREAT | O_CLOEXEC, 0600), tries = 10;
  while (flock(lock, LOCK_EX | LOCK_NB) != 0) {
    if (--tries == 0) { note("turned-away"); return 75; }
    usleep(100000);
  }
  if (ftruncate(lock, 0) != 0 || pwrite(lock, number, strlen(number), 0) < 0) return 1;
  if (!getenv("ARBOR_NO_WATCHDOG")) {
    int ends[2];
    if (pipe(ends) != 0) return 1;
    number[strlen(number) - 1] = 0;
    if (fork() == 0) {
      dup2(ends[0], 0); close(ends[0]); close(ends[1]);
      execl(arguments[0], arguments[0], "--watchdog", number, (char *)0);
      _exit(1);
    }
    close(ends[0]);
    line = ends[1];
    fcntl(line, F_SETFD, FD_CLOEXEC);
  }
  signal(SIGTERM, getenv("STAND_IN_DEAF") ? SIG_IGN : quit);
  note("holds");
  for (;;) pause();
}
"""

# What Runner.init, startGuardian, launchArbor and cleanUp do. `pass_fds` is this table's own: a descriptor that closes when the guardian has ended.
RUNNER = r"""
import os, shutil, signal, subprocess, sys, time
guardian, arbor, home, telltale = sys.argv[1:5]
options = sys.argv[5:]
def patiently(what):
    until = time.time() + 10
    while not what():
        if time.time() > until:
            sys.exit("not ready")
        time.sleep(0.01)
os.makedirs(home)
if "cwd-goes" in options:
    os.makedirs(home + "-from")
    os.chdir(home + "-from")
read, write = os.pipe()
# Foundation makes a child the leader of a group of its own. "same-group": not even that, so that what is done to the runner's group reaches it.
started = subprocess.Popen(["/usr/bin/perl", "-e", guardian, "arbor-e2e-guardian", home], stdin=read, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                           pass_fds=[int(telltale)], preexec_fn=None if "same-group" in options else os.setpgrp)
os.close(read)
os.close(int(telltale))
said = started.stdout.readline().strip()
if not said.isdigit() or ("setsid()" in guardian and os.getsid(int(said)) != int(said)):
    sys.exit("not ready")
started.stdout.close()
process = None
if "arbor" in options:
    process = subprocess.Popen([arbor], stdin=subprocess.DEVNULL, start_new_session="apart" in options)
    patiently(lambda: os.path.getsize(home + "/arbor.lock") > 0)
    time.sleep(0.2)
if "cwd-goes" in options:
    os.chdir("/")
    os.rmdir(home + "-from")
print("ready", flush=True)
sys.stdin.readline()
# An orderly end.
if process:
    process.send_signal(signal.SIGTERM)
    time.sleep(0.5)
if "removes" in options:
    shutil.rmtree(home)
"""


def program(text=None):
    """The guardian, as the compiler would hand it to the runner."""
    if text is None:
        with open(SOURCE, encoding="utf-8") as handle:
            text = handle.read()
    found = re.search(r'static let guardian = #"""\n(.*?)\n( *)"""#', text, re.S)
    if not found:
        return None
    lines, indent = found.group(1).split("\n"), found.group(2)
    if any(line.strip() and not line.startswith(indent) for line in lines):
        return None
    return "\n".join(line[len(indent):] for line in lines)


def alive(pid):
    """Whether the process runs. One that has ended and waits for a parent that never asks does not."""
    state = subprocess.run(["ps", "-o", "stat=", "-p", str(pid)], capture_output=True, text=True, check=False).stdout.strip()
    return bool(state) and not state.startswith("Z")


def compiler():
    return shutil.which("cc") or shutil.which("clang") or shutil.which("gcc")


class Table:
    def __init__(self, folder, guardian):
        self.folder, self.guardian = folder, guardian
        self.arbor = os.path.join(folder, "Arbor")
        source = os.path.join(folder, "stand-in.c")
        with open(source, "w", encoding="utf-8") as handle:
            handle.write(STAND_IN)
        subprocess.run([compiler(), "-O0", "-o", self.arbor, source], check=True, capture_output=True)
        self.numbers = itertools.count(1)

    def ending(self, how, *, arbor=True, within="tmp", home="arbor-e2e-4711", lock=None, killed_first=False, environment=None, options=(), guardian=None,
               bystander=None):
        """Plays one ending and says what is left, and what the stand-ins noted."""
        place = os.path.join(self.folder, str(next(self.numbers)))
        home, log = os.path.join(place, within, home), os.path.join(place, "log")
        os.makedirs(os.path.dirname(home))
        open(log, "w", encoding="utf-8").close()
        variables = {key: value for key, value in os.environ.items() if not key.startswith(("ARBOR_", "STAND_IN_"))}
        variables.update(ARBOR_HOME=home, STAND_IN_LOG=log, **(environment or {}))
        others = []
        read, telltale = os.pipe()
        runner = subprocess.Popen([sys.executable, "-c", RUNNER, guardian or self.guardian, self.arbor, home, str(telltale)] + (["arbor"] if arbor else []) + list(options),
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=variables, start_new_session=True, pass_fds=[telltale], text=True)
        os.close(telltale)
        try:
            if runner.stdout.readline() != "ready\n":
                return {"left": ["the row never began"]}
            if bystander == "sleeper":
                others.append(subprocess.Popen(["sleep", "110"]))
            elif bystander == "arbor":
                # An Arbor that is not this run's: of this build, in another home.
                others.append(subprocess.Popen([self.arbor], stdin=subprocess.DEVNULL, start_new_session=True,
                                               env=dict(variables, ARBOR_HOME=os.path.join(place, "somebody"), ARBOR_NO_WATCHDOG="1", STAND_IN_LOG=os.devnull)))
                time.sleep(0.3)
            if lock is not None:
                with open(os.path.join(home, "arbor.lock"), "w", encoding="utf-8") as handle:
                    handle.write(lock.replace("BYSTANDER", str(others[0].pid)) + "\n")
            if killed_first:
                with open(os.path.join(home, "arbor.lock"), encoding="utf-8") as handle:
                    os.kill(int(handle.read()), signal.SIGKILL)
            began = time.time()
            if how == "orderly":
                runner.stdin.write("\n")
                runner.stdin.flush()
            elif how == "alone":
                runner.kill()
            else:
                os.killpg(runner.pid, {"group": signal.SIGKILL, "group asked": signal.SIGTERM}[how])
            runner.wait()
            runner.stdin.close()
            runner.stdout.close()
            # The guardian has ended when nobody holds the far end.
            os.set_blocking(read, False)
            while time.time() - began < 80:
                try:
                    if os.read(read, 1) == b"":
                        break
                except BlockingIOError:
                    time.sleep(0.05)
            took = time.time() - began
            time.sleep(0.5)
            with open(log, encoding="utf-8") as handle:
                said = [line.split() for line in handle]
            left = sorted({what for what, pid in said if what in ("arbor", "watchdog") and alive(pid)})
            answer = {what: sum(what == word for word, _ in said) for what in ("asked", "arbor", "turned-away")}
            answer.update(stays="arbor" in left, left=left + ["folder"] * os.path.exists(home) + ["guardian"] * (took >= 80), bystander=[other.poll() is None for other in others])
            return answer
        finally:
            os.close(read)
            if runner.poll() is None:
                runner.kill()
            with open(log, encoding="utf-8") as handle:
                for line in handle:
                    try:
                        os.kill(int(line.split()[1]), signal.SIGKILL)
                    except (OSError, ValueError, IndexError):
                        pass
            for other in others:
                other.kill()
                other.wait()


def situations():
    """(what, got, expected) for scripts/test-tooling.py."""
    guardian = program()
    rows = [("e2e guardian: the program can be read out of Guardian.swift", guardian is not None, True),
            ("e2e guardian: a C compiler for the stand-ins", compiler() is not None, True),
            ("e2e guardian: a program that is not indented as its last line is not read at all", program('static let guardian = #"""\n    a\n  b\n    """#\n'), None)]
    if guardian is None or compiler() is None:
        return rows
    in_the_group = guardian.replace("setsid() > 0 or exit 1;", "")
    at_once = guardian.replace("my $child = fork;", "my $child = 0;")
    stays_put = guardian.replace("chdir '/';", "")
    hasty = guardian.replace("sleep 15;", "sleep 1;")
    by_the_number = guardian.replace("until (flock($lock, LOCK_EX | LOCK_NB)) {", "until (time > $until - 40) {")
    rows.append(("e2e guardian: the controls below do leave a part out", [text != guardian for text in (in_the_group, at_once, stays_put, hasty, by_the_number)], [True] * 5))
    deaf, slow = {"STAND_IN_DEAF": "1"}, lambda seconds: {"STAND_IN_SLOW": str(seconds * 1000)}
    with tempfile.TemporaryDirectory(prefix="guardian-") as folder:
        table = Table(folder, guardian)
        plays = [
            # (what, expected: of the answer only these count, how, arguments)
            ("the runner finishes, Arbor has quit: only the folder is left to remove", {"left": [], "asked": 1}, "orderly", {}),
            ("the runner finishes before it started an Arbor", {"left": []}, "orderly", dict(arbor=False)),
            ("the runner is killed alone: Arbor is asked to quit, which tells its watchdog", {"left": [], "asked": 1, "arbor": 1}, "alone", {}),
            ("the same without a watchdog", {"left": [], "asked": 1}, "alone", dict(environment={"ARBOR_NO_WATCHDOG": "1"})),
            ("the runner's whole group is killed, Arbor and the guardian's starter in it: the folder goes", {"left": []}, "group", dict(options=["same-group"])),
            ("the whole group is killed, Arbor outside it", {"left": [], "asked": 1}, "group", dict(options=["apart", "same-group"])),
            ("the whole group is asked to end, Arbor outside it", {"left": [], "asked": 1}, "group asked", dict(options=["apart", "same-group"])),
            ("control: without a session of its own the guardian dies with the group", {"left": ["arbor", "watchdog", "folder"]}, "group",
             dict(options=["apart", "same-group"], guardian=in_the_group)),
            ("control: as the leader of a group, which Foundation makes of it, it would get no session, and the run would not begin", {"left": ["the row never began"]}, "alone",
             dict(guardian=at_once)),
            # Whether the next Arbor is turned away or gets the lock first and is dealt with in its turn is a race of 0.3 s. The rows with a slow one say which.
            ("an Arbor deaf to SIGTERM is killed, and the one its watchdog starts does not stay either", {"left": []}, "alone", dict(environment=deaf)),
            ("the runner finishes and a deaf Arbor is still there", {"left": []}, "orderly", dict(environment=deaf)),
            ("Arbor was killed a moment before the runner: the one its watchdog starts does not stay", {"left": []}, "alone", dict(killed_first=True)),
            ("the folder the guardian was started from is gone by then", {"left": [], "asked": 1}, "alone", dict(options=["cwd-goes"])),
            ("the same, and that one needs 3 s to reach the lock", {"left": [], "arbor": 2, "turned-away": 1}, "alone", dict(killed_first=True, environment=slow(3))),
            ("the same with 10 s, on a Mac that is busy", {"left": [], "arbor": 2, "turned-away": 1}, "alone", dict(killed_first=True, environment=slow(10))),
            ("control: the lock held for one second only, that one stays", {"stays": True}, "alone",
             dict(killed_first=True, environment=slow(10), guardian=hasty)),
            ("the runner is stopped a moment after it killed Arbor", {"left": [], "arbor": 2, "turned-away": 1}, "orderly", dict(killed_first=True, environment=slow(3))),
            ("control: had the runner removed the folder, the next Arbor would make it anew, with a lock that nobody holds", {"stays": True},
             "orderly", dict(killed_first=True, environment=slow(3), options=["removes"])),
            ("a temporary folder with blanks, what a shell or a pattern would misread, and letters that are not ASCII", {"left": [], "asked": 1}, "alone",
             dict(within="t (1) $HOME *?.\\d 'x' Büro 机")),
            ("an Arbor of this build in another home, as after `make run`: left alone", {"left": [], "asked": 1, "bystander": [True]}, "alone", dict(bystander="arbor")),
            ("a folder that has not the runner's kind of name is not removed", {"left": ["folder"], "asked": 1}, "alone", dict(home="precious")),
            ("control: going by the number in the file, it would signal whoever has that number by now", {"bystander": [False]}, "alone",
             dict(arbor=False, bystander="sleeper", lock="BYSTANDER", guardian=by_the_number)),
        ] + [
            # By the version of File::Path.
            ("control: still in that folder, it could not remove the run's", {"left": ["folder"]}, "alone", dict(options=["cwd-goes"], guardian=stays_put)),
        ] * (sys.platform == "linux") + [
            (f"nobody holds the lock and the file says {text!r}: nobody is signalled", {"left": [], "bystander": [True]}, "alone",
             dict(arbor=False, bystander="sleeper", lock=text))
            for text in ("BYSTANDER", "", "0", "-1", "1")
        ]
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(plays)) as pool:
            answers = list(pool.map(lambda play: table.ending(play[2], **play[3]), plays))
        for (what, expected, _, _), answer in zip(plays, answers):
            rows.append((f"e2e guardian: {what}", {key: answer.get(key) for key in expected}, expected))
    return rows


def main():
    rows = situations()
    wrong = 0
    for what, got, expected in rows:
        if got != expected:
            wrong += 1
            print(f"✘ {what}: expected {expected!r}, got {got!r}")
        elif "-v" in sys.argv[1:]:
            print(f"✔ {what}")
    print(f"{len(rows) - wrong} of {len(rows)} endings came out as expected")
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
