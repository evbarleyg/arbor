#!/usr/bin/env python3
"""Runs a command with a terminal on standard input, where there is none: for scripts that ask `[ -t 0 ]` whether somebody is there.

    scripts/at-a-terminal.py <seconds> [--ctrl-c <seconds>] <command…>

What the command prints is passed on, its exit code is this one's (128 + the signal that ended it). Nothing is typed but, if asked for, ⌃C after
so many seconds, which reaches whatever is in the foreground of the terminal as it does from a keyboard. After the first number of seconds the
command and all it started in its session are killed, and this ends with 137 whoever still holds the terminal: a script that waits for what
nobody will type must fail a check, not hold up the run. scripts/release-tools-test.sh and scripts/mac-shell/check-signing.sh use it on
scripts/make-signing-identity.sh.
"""
import os
import pty
import select
import signal
import sys
import time


def main():
    arguments = sys.argv[1:]
    try:
        limit = float(arguments.pop(0))
        interrupt = None
        if arguments[0] == "--ctrl-c":
            interrupt = float(arguments[1])
            arguments = arguments[2:]
        if not arguments:
            raise IndexError
    except (IndexError, ValueError):
        print(__doc__.split("\n\n")[1].strip(), file=sys.stderr)
        return 64
    pid, terminal = pty.fork()  # the child leads a session, and so a process group, of its own
    if pid == 0:
        os.execvp(arguments[0], arguments)
    started = time.monotonic()
    while True:
        passed = time.monotonic() - started
        if passed >= limit:
            try:
                os.killpg(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            os.waitpid(pid, 0)
            return 137
        if interrupt is not None and passed >= interrupt:
            os.write(terminal, b"\x03")
            interrupt = None
        if not select.select([terminal], [], [], 0.05)[0]:
            continue
        try:
            piece = os.read(terminal, 4096)
        except OSError:  # Linux says so at the end, macOS reads nothing
            break
        if not piece:
            break
        sys.stdout.buffer.write(piece)
        sys.stdout.buffer.flush()
    status = os.waitpid(pid, 0)[1]
    return 128 + os.WTERMSIG(status) if os.WIFSIGNALED(status) else os.WEXITSTATUS(status)


if __name__ == "__main__":
    sys.exit(main())
