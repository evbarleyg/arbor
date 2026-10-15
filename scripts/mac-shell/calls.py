#!/usr/bin/env python3
"""How did a window get where it is? The frames Arbor asked it to take from a command on, out of Arbor's own trace.

    scripts/mac-shell/calls.py <trace.jsonl or a folder of them> <window id> <command>
    scripts/mac-shell/calls.py --self-test

A check that looks at a window once it rests sees where it ended and not how it got there: a window sent to a corner and, seven
milliseconds later, to the middle passes it (seen: System Settings on a hosted Mac, the first time it was made to fill the view).
The trace has every frame Arbor asked for, what the app made of it and when (docs/TRACES.md).

Of a folder the newest trace is read, by its name. Counted is every `setFrame` for that window from the LAST time the command came
(its text as the trace has it: `zoom`, `zoom 49`) to the end of the trace, so what a timer does after the command is done counts too.
Have a remark written first (lib.sh's arbor_trace_note): it brings what the recorder still holds to the file.

One line: the number, the time from the first question put to the last one answered, and each question with its answer:

    2 calls in 73 ms: 12 43 1000 655 > 12 43 723 655; 150.5 43 723 655 > 150 43 723 655

`0 calls`: nothing was asked of it. `? …`: it cannot tell (no trace, no such command), and says why. Nothing is judged here.
"""
import json
import os
import sys


def newest(path):
    """The trace to read: the file itself, or the last by name in a folder (their names begin with the date). None if there is none."""
    if not os.path.isdir(path):
        return path if os.path.isfile(path) else None
    names = sorted(name for name in os.listdir(path) if name.endswith(".jsonl"))
    return os.path.join(path, names[-1]) if names else None


def entries(path):
    """The trace's lines. One that is cut short, because Arbor is still writing it, is left out."""
    found = []
    with open(path, encoding="utf-8", errors="replace") as file:
        for line in file:
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if isinstance(entry, dict):
                found.append(entry)
    return found


def calls(trace, window, command):
    """The `setFrame` entries for `window` after the last `command`. None if the command never came."""
    last = None
    for index, entry in enumerate(trace):
        if entry.get("command") == command:
            last = index
    if last is None:
        return None
    return [entry for entry in trace[last:] if entry.get("call") == "setFrame" and entry.get("id") == window]


def words(frame):
    """A frame as the scripts print it. An app that did not answer has none."""
    return " ".join(f"{number:g}" for number in frame) if frame else "no answer"


def line(found):
    if not found:
        return "0 calls"
    # An entry is written when the answer is there.
    span = found[-1]["t"] - (found[0]["t"] - found[0].get("took", 0))
    told = "; ".join(f"{words(entry.get('frame'))} > {words(entry.get('result'))}" for entry in found)
    return f"{len(found)} call{'' if len(found) == 1 else 's'} in {round(span * 1000)} ms: {told}"


def read(path, window, command):
    trace = newest(path)
    if trace is None:
        return f"? no trace at {path}"
    found = calls(entries(trace), window, command)
    return f"? `{command}` is not in {os.path.basename(trace)}" if found is None else line(found)


def self_test():
    import tempfile
    # As a hosted Mac recorded them.
    trace = [
        {"name": "t"}, {"t": 0.001, "note": "a claim"},
        {"t": 1.0, "command": "zoom", "from": "shortcut"},
        {"t": 1.05, "call": "setFrame", "frame": [12, 43, 1000, 655], "id": 7, "result": [12, 43, 1000, 655], "took": 0.04},
        {"t": 1.06, "done": "zoom", "ok": True},
        {"t": 2.9489, "nested": True, "command": "zoom", "from": "shortcut"},
        {"t": 2.95, "call": "focusedWindow", "result": 49},
        {"t": 3.0167, "call": "setFrame", "frame": [12, 43, 1000, 655], "id": 49, "result": [12, 43, 723, 655], "took": 0.0663},
        {"t": 3.0238, "call": "setFrame", "frame": [150.5, 43, 723, 655], "id": 49, "result": [150, 43, 723, 655], "took": 0.0064},
        {"t": 3.1995, "done": "zoom", "ok": True},
        {"t": 3.3, "command": "state", "from": "script"}, {"t": 3.31, "done": "state", "ok": True},
        # After the command is done, by a timer: it counts. Another window's does not.
        {"t": 3.5, "call": "setFrame", "frame": [1, 2, 3, 4], "id": 8, "result": None, "took": 0.25},
    ]
    assert line(calls(trace, 49, "zoom")) == "2 calls in 73 ms: 12 43 1000 655 > 12 43 723 655; 150.5 43 723 655 > 150 43 723 655"
    # Only from the last time the command came: the first `zoom` was window 7's.
    assert line(calls(trace, 7, "zoom")) == "0 calls"
    assert line(calls(trace, 8, "zoom")) == "1 call in 250 ms: 1 2 3 4 > no answer"
    assert line(calls(trace, 8, "state")) == "1 call in 250 ms: 1 2 3 4 > no answer"
    assert calls(trace, 49, "zoom 49") is None
    with tempfile.TemporaryDirectory() as folder:
        assert read(folder, 49, "zoom") == f"? no trace at {folder}"
        assert read(os.path.join(folder, "none.jsonl"), 49, "zoom").startswith("? no trace at ")
        for name, lines in (("2026-01-01-100000-a-1-01.jsonl", trace[:5]), ("2026-01-01-100100-a-1-02.jsonl", trace)):
            with open(os.path.join(folder, name), "w", encoding="utf-8") as file:
                # The last line is still being written.
                file.write("\n".join(json.dumps(entry) for entry in lines) + '\n{"t":4.0,"call":"setFr')
        assert read(folder, 49, "zoom").startswith("2 calls in 73 ms: ")
        assert read(os.path.join(folder, "2026-01-01-100000-a-1-01.jsonl"), 7, "zoom").startswith("1 call in 40 ms: ")
        assert read(folder, 49, "home") == "? `home` is not in 2026-01-01-100100-a-1-02.jsonl"
    print("calls.py: its self-test passes")


def main(arguments):
    if arguments == ["--self-test"]:
        return self_test()
    if len(arguments) != 3 or not arguments[1].isdigit():
        sys.exit(__doc__)
    print(read(arguments[0], int(arguments[1]), arguments[2]))


if __name__ == "__main__":
    main(sys.argv[1:])
