#!/usr/bin/env python3
"""Attacks the control socket as a hostile or broken script would, and checks that Arbor would not have noticed.

    scripts/socket-attack.py [path to arbor-sim [attack…]]      (make attack; default .build/debug/arbor-sim, every attack)

The target is `arbor-sim --serve`: the real server, endpoint, event feed and controller, with pretend windows. Nothing of
anybody's is touched: sockets, home folder and log are in a temporary folder. About half a minute. Exit code 0 if every
check held, 1 if one did not, 2 if the simulator could not be started.

Arbor's main thread moves people's windows and sees their clicks, so what is checked is that no client can hold it, kill
it, fill its log or use up its descriptors:

  fuzz    24 clients at once that send half lines, binary, thousands of lines, leave without reading, watch and vanish
  flood   two processes that connect and hang up as fast as they can, while a silent client waits for its two seconds
  emfile  more clients than the process has descriptors for. On macOS, or by name: Linux's libdispatch looks at
          /proc/self/task/<thread>/stat once a second while its threads are busy and ends the process when it cannot
          open that, so there a process without descriptors may die of something that is not Arbor's and not on a Mac.
          `withoutADescriptorLeftTheServerRestsInsteadOfSpinning` holds the server to the same on both.

From the Accessibility reviewer's attack on the server of F24.
"""
import multiprocessing
import os
import random
import resource
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time

failures = []


def check(what, holds, detail=""):
    print(("  ✔ " if holds else "  ✘ ") + what + (f"  ({detail})" if detail else ""))
    if not holds:
        failures.append(what)


class Simulator:
    """`arbor-sim --serve` in a folder of its own."""

    def __init__(self, binary, folder, name, descriptors=None):
        self.home = os.path.join(folder, name)
        os.makedirs(self.home)
        self.path = os.path.join(self.home, "s")

        def limit():
            if descriptors:
                resource.setrlimit(resource.RLIMIT_NOFILE, (descriptors, descriptors))

        self.process = subprocess.Popen(
            [binary, "--serve", self.path], env={**os.environ, "ARBOR_HOME": self.home}, preexec_fn=limit,
            stdout=subprocess.DEVNULL)
        for _ in range(200):
            if os.path.exists(self.path):
                return
            time.sleep(0.05)
        print("arbor-sim --serve did not start")
        sys.exit(2)

    def connect(self):
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        client.connect(self.path)
        return client

    def ask(self, line, timeout=10):
        """The reply, or the error as text."""
        try:
            client = self.connect()
            client.settimeout(timeout)
            client.sendall(line.encode() + b"\n")
            client.shutdown(socket.SHUT_WR)
            reply = b""
            while chunk := client.recv(65536):
                reply += chunk
            client.close()
            return reply.decode(errors="replace")
        except OSError as error:
            return repr(error)

    def alive(self):
        return self.process.poll() is None

    def cpu(self):
        """Seconds of processor time used so far."""
        try:
            fields = open(f"/proc/{self.process.pid}/stat").read().rsplit(")", 1)[1].split()
            return (int(fields[11]) + int(fields[12])) / os.sysconf("SC_CLK_TCK")
        except OSError:
            # macOS: [dd-]hh:mm:ss.cc or mm:ss.cc
            text = subprocess.run(["ps", "-o", "cputime=", "-p", str(self.process.pid)], capture_output=True, text=True).stdout
            seconds = 0.0
            for part in text.strip().replace("-", ":").split(":"):
                seconds = seconds * 60 + float(part or 0)
            return seconds

    def descriptors(self):
        """How many are open, or None where that cannot be seen cheaply (macOS)."""
        try:
            return len(os.listdir(f"/proc/{self.process.pid}/fd"))
        except OSError:
            return None

    def log_bytes(self):
        return sum(os.path.getsize(os.path.join(self.home, name)) for name in os.listdir(self.home) if name.endswith(".log"))

    def stop(self):
        self.process.kill()
        self.process.wait()


def fuzz(binary, folder, seconds=6):
    print("fuzz: 24 clients that misbehave in ten ways")
    sim = Simulator(binary, folder, "fuzz")
    for line in ["open A", "open B", "dock 101 left"]:
        sim.ask(line)
    base = sim.descriptors()
    stop = time.time() + seconds

    def worker(seed):
        dice = random.Random(seed)
        while time.time() < stop:
            try:
                client = sim.connect()
                kind = dice.randrange(10)
                if kind == 1:
                    client.sendall(b"sta")
                elif kind == 2:
                    client.sendall(os.urandom(dice.randrange(1, 200000)))
                elif kind == 3:
                    client.sendall(b"state\n" * 5000)
                elif kind == 4:
                    client.sendall(b"state\n")  # and leave without reading
                elif kind == 5:
                    client.sendall(b"watch\n")
                    time.sleep(dice.random() * 0.05)
                elif kind == 6:
                    client.sendall(b"watch --titles\n")
                    client.shutdown(socket.SHUT_WR)
                elif kind == 7:
                    client.sendall(b"x" * 100000)
                elif kind == 8:
                    client.sendall(b"dock 102 right\n" if dice.random() < 0.5 else b"float 102\n")
                    client.recv(100)
                elif kind == 9:
                    client.sendall(b"\xff\xfe\x00\n")
                    client.recv(10)
                client.close()
            except OSError:
                pass

    threads = [threading.Thread(target=worker, args=(seed,)) for seed in range(24)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    # Longer than the server gives a client to collect its reply.
    time.sleep(6)
    check("it is still running", sim.alive())
    if base is not None:
        check("every descriptor was given back", sim.descriptors() <= base, f"{base} before, {sim.descriptors()} after")
    before = sim.cpu()
    time.sleep(2)
    check("it is idle afterwards", sim.cpu() - before < 0.1, f"{sim.cpu() - before:.2f} s of processor time in 2 s")
    check("and answers", '"ok":true' in sim.ask("status"))
    sim.stop()


def hammer(path, until):
    while time.time() < until:
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            client.connect(path)
        except OSError:
            pass
        client.close()


def flood(binary, folder, seconds=6):
    print("flood: two processes connect and hang up as fast as they can")
    sim = Simulator(binary, folder, "flood")
    probe = sim.connect()
    began = time.time()
    until = began + seconds
    processes = [multiprocessing.Process(target=hammer, args=(sim.path, until)) for _ in range(2)]
    for process in processes:
        process.start()
    probe.settimeout(seconds + 10)
    try:
        probe.recv(10)
    except OSError:
        pass
    waited = time.time() - began
    check("a silent client is hung up on after its two seconds all the same", waited < 3, f"{waited:.1f} s")
    for process in processes:
        process.join()
    time.sleep(2)
    check("it is still running", sim.alive())
    check("and answers", '"ok":true' in sim.ask("status"))
    check("the log was not filled", sim.log_bytes() < 20_000, f"{sim.log_bytes()} bytes")
    sim.stop()


def emfile(binary, folder):
    print("emfile: more clients than there are descriptors")
    sim = Simulator(binary, folder, "emfile", descriptors=30)
    watchers = []
    for _ in range(16):
        watcher = sim.connect()
        watcher.sendall(b"watch\n")
        watchers.append(watcher)
    time.sleep(0.5)
    waiting = [sim.connect() for _ in range(20)]
    time.sleep(0.5)
    before = sim.cpu()
    time.sleep(3)
    used = sim.cpu() - before
    check("it does not spin while they wait", used < 0.5, f"{used:.2f} s of processor time in 3 s")
    check("it is still running", sim.alive())
    for client in waiting + watchers:
        client.close()
    time.sleep(2.5)
    check("and answers once there is room", '"ok":true' in sim.ask("status"))
    sim.stop()


def main():
    binary = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".build/debug/arbor-sim")
    if not os.access(binary, os.X_OK):
        print(f"{binary} is not there; run `swift build` first")
        return 2
    # Short, because a socket's path may have about a hundred bytes.
    folder = tempfile.mkdtemp(prefix="arbor-attack-", dir="/tmp")
    attacks = {"fuzz": fuzz, "flood": flood, "emfile": emfile}
    chosen = sys.argv[2:] or [name for name in attacks if name != "emfile" or sys.platform == "darwin"]
    if unknown := [name for name in chosen if name not in attacks]:
        print(f"no attack called {unknown[0]}; there are {', '.join(attacks)}")
        return 2
    try:
        for number, name in enumerate(chosen):
            os.makedirs(os.path.join(folder, str(number)))
            attacks[name](binary, os.path.join(folder, str(number)))
    finally:
        shutil.rmtree(folder, ignore_errors=True)
    print("the socket held" if not failures else f"{len(failures)} check(s) failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
