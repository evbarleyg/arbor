#!/usr/bin/env python3
"""Lays two playings of one walk side by side: what a hosted Mac brought back, and what the stand-ins showed on Linux.

  walk-diff.py <samples of the Mac> <samples of the stand-ins> [--within <points>] [--all]
  walk-diff.py --self-test

Both files are in sampler.swift's grammar with lib-day.sh's marks: the first was written by the sampler while lib-walk.sh played the walk against real apps, the
second by `arbor-sim walk --rehearse --scene <the first> --samples <the second> < the walk`, which begins where the Mac began. The same acts, the same
Arbor. So **every difference is either a lie of the stand-ins or a fault that only a Mac shows**, and each goes to whoever keeps that: the ledger of differences
(collab/reality.json) or the board.

Windows go by their labels, which are the cast's names, since their numbers mean nothing elsewhere. Acts are matched by their slugs, in order. It says

  * which acts were played in one place and not in the other: there the two disagreed on whether the act applies;
  * for each act played in both, at its end: which windows are elsewhere (by more than 2 points, or --within), which window is in front, what is docked. A window that
    is out of view in both places is alike, wherever beyond the edge it was put. What was said at the act before is not said again;
  * **where the two part for the first time.** From there on one difference breeds the next, so that act is the one to look at. What follows is counted, and
    listed with --all.

Exit code 0 when the two agree all the way, 1 when they part, 2 when a file is no playing of a walk.
"""

import difflib
import sys


class Act:
    def __init__(self, number, slug):
        self.number, self.slug = number, slug
        self.kind, self.setup, self.judged = "", False, True
        # At its end: label -> (x, y, w, h); the label in front; the labels that are docked; the displays.
        self.frames, self.front, self.docked, self.displays = {}, None, set(), []


def playing(lines):
    """The acts of a playing, in order."""
    frames, labels, order, acts, current, displays = {}, {}, [], [], None, {}
    for line in lines:
        parts = line.split()
        if len(parts) < 3:
            continue
        kind, rest = parts[1], parts[2:]
        if kind == "W" and len(rest) >= 7 and rest[2] == "0":
            frames[rest[0]] = tuple(float(number) for number in rest[3:7])
        elif kind == "G":
            frames.pop(rest[0], None)
        elif kind == "D" and len(rest) == 4:
            displays["main"] = tuple(float(number) for number in rest)
        elif kind == "Y":
            if len(rest) >= 5:
                displays[rest[0]] = tuple(float(number) for number in rest[1:5])
            else:
                displays.pop(rest[0], None)
        elif kind == "Z":
            order = rest[0].split(",")
        elif kind == "M" and rest[0] == "label" and len(rest) == 3:
            # A new-window's label ends in the number of its step, which differs as soon as one act does.
            name = rest[2]
            if "-new-" in name:
                name = name[:name.index("-new-") + 4]
            labels[rest[1]] = name
        elif kind == "M" and rest[0] == "begin" and len(rest) == 3:
            current = Act(int(rest[1]), rest[2])
        elif kind == "M" and rest[0] == "end" and current is not None and rest[1] == str(current.number):
            keys = dict(word.split("=", 1) for word in rest[2:] if "=" in word)
            current.kind = keys.get("act", "")
            # A round of input is an instrument and no act either: it is compared, and counts towards nothing.
            current.setup = keys.get("setup") == "1" or keys.get("act") == "instrument"
            current.judged = keys.get("judge") != "no"
            # The newest window of a label stands for it: an app that was opened again has another number.
            for window, frame in frames.items():
                if window in labels:
                    current.frames[labels[window]] = frame
            current.front = next((labels[window] for window in order if window in labels and window in frames), None)
            current.docked = {labels[window] for window in keys.get("docked", "").split(",") if window in labels}
            current.displays = list(displays.values())
            acts.append(current)
            current = None
    return acts


def words(frame):
    return "%g,%g %g×%g" % frame


def out_of_view(frame, displays):
    """Less than a twentieth of it shows: Arbor has put it beyond an edge. How far beyond is between Arbor, macOS and the Dock."""
    x, y, w, h = frame
    showing = sum(max(0, min(x + w, dx + dw) - max(x, dx)) * max(0, min(y + h, dy + dh) - max(y, dy)) for dx, dy, dw, dh in displays)
    return w * h > 0 and showing < 0.05 * w * h


def differences(mac, linux, within):
    """What differs at the end of an act that both played: a list of sentences."""
    found = []
    for label in sorted(set(mac.frames) | set(linux.frames)):
        here, there = mac.frames.get(label), linux.frames.get(label)
        if here is None or there is None:
            found.append(f"{label} is on the screen only {'on Linux' if here is None else 'on the Mac'}")
        elif out_of_view(here, mac.displays) and out_of_view(there, linux.displays):
            continue
        elif max(abs(a - b) for a, b in zip(here, there)) > within:
            state = "docked" if label in mac.docked and label in linux.docked else "floating" if label not in mac.docked | linux.docked else "docked in one"
            found.append(f"{label} ({state}): the Mac {words(here)}, Linux {words(there)}")
    if mac.docked != linux.docked:
        found.append(f"docked on the Mac: {' '.join(sorted(mac.docked)) or 'nothing'}; on Linux: {' '.join(sorted(linux.docked)) or 'nothing'}")
    if mac.front != linux.front:
        found.append(f"in front on the Mac: {mac.front}; on Linux: {linux.front}")
    return found


def compare(mac, linux, within=2.0):
    """(lines of the report in full, lines of the summary, whether the two agree)."""
    report, only_mac, only_linux, both, differing = [], [], [], 0, []
    matcher = difflib.SequenceMatcher(a=[act.slug for act in mac], b=[act.slug for act in linux], autojunk=False)
    first, said = None, []
    for tag, a1, a2, b1, b2 in matcher.get_opcodes():
        if tag == "equal":
            for here, there in zip(mac[a1:a2], linux[b1:b2]):
                both += not here.setup
                found = differences(here, there, within)
                if found:
                    differing.append(here)
                    new = [sentence for sentence in found if sentence not in said]
                    if new:
                        report.append(f"{here.number} {here.slug} (Linux: {there.number})")
                        report += [f"    {sentence}" for sentence in new]
                    # While the scene is set nothing is Arbor's doing, and the walk has not begun.
                    if not here.setup:
                        first = first or (here, found)
                said = found
        else:
            # While the scene is set the walk has not begun: macOS does not answer every drag, so its tiling is tried up to three times; an app may open no window.
            for here in mac[a1:a2]:
                report.append(f"{here.number} {here.slug}: played on the Mac alone" + (", while the scene was set" if here.setup else ""))
                if not here.setup:
                    only_mac.append(here)
                    first = first or (here, ["played on the Mac alone"])
            for there in linux[b1:b2]:
                report.append(f"(Linux: {there.number}) {there.slug}: played on Linux alone" + (", while the scene was set" if there.setup else ""))
                if not there.setup:
                    only_linux.append(there)
                    first = first or (there, ["played on Linux alone"])
    played = [act for act in mac if not act.setup]
    summary = [
        f"the Mac played {len(played)} acts, {sum(act.judged for act in played)} of them judged; Linux played {sum(not act.setup for act in linux)}",
        f"{both} were played in both, {len(only_mac)} on the Mac alone, {len(only_linux)} on Linux alone",
        f"of those played in both, {both - sum(not act.setup for act in differing)} ended alike",
    ]
    if first:
        act, found = first
        before = sum(1 for other in played if other.number < act.number) if act in mac else None
        summary.append(f"THEY PART AT {act.number} {act.slug}" + (f", after {before} acts alike" if before is not None else " (Linux's number)") + ":")
        summary += [f"    {sentence}" for sentence in found]
    else:
        summary.append("they agree all the way")
    return report, summary, first is None


def self_test():
    start = ["1000 D 0 0 1000 800", "1000 W 1 10 0 0 0 400 300 One", "1000 W 2 20 0 500 0 400 300 Two", "1000 Z 1,2", "1000 M label 1 one", "1000 M label 2 two"]
    other = ["5000 D 0 0 1000 800", "5000 W 71 10 0 0 0 400 300 One", "5000 W 72 20 0 500 0 400 300 Two", "5000 Z 71,72", "5000 M label 71 one", "5000 M label 72 two"]

    def step(number, slug, *lines, end="act=view"):
        return [f"2000 M begin {number} {slug}", *lines, f"3000 M end {number} {end}"]

    failures = []

    def expect(what, mac, linux, agree, *said):
        report, summary, agreed = compare(playing(mac), playing(linux))
        text = "\n".join(report + summary)
        if agreed != agree:
            failures.append(f"{what}: {'they agree' if agreed else 'they part'}\n{text}")
        for sentence in said:
            if sentence not in text:
                failures.append(f"{what}: nothing says `{sentence}`\n{text}")

    expect("other numbers, the same screen", start + step(1, "look"), other + step(1, "look"), True, "they agree all the way")
    expect("two points are no difference", start + step(1, "look"), other + step(1, "look", "2500 W 71 10 0 2 0 400 300 One"), True)
    expect("three are", start + step(1, "look"), other + step(1, "look", "2500 W 71 10 0 3 0 400 300 One"), False, "THEY PART AT 1 look", "one (floating): the Mac 0,0 400×300, Linux 3,0 400×300")
    expect("another window in front", start + step(1, "look"), other + step(1, "look", "2500 Z 72,71"), False, "in front on the Mac: one; on Linux: two")
    expect("docked in one place", start + step(1, "dock", end="act=dock-key docked=1"), other + step(1, "dock", end="act=dock-key docked="), False,
           "docked on the Mac: one; on Linux: nothing")
    expect("an act the Mac left out", start + step(1, "look") + step(2, "leave"), other + step(1, "look") + step(2, "drag") + step(3, "leave"), False,
           "drag: played on Linux alone", "2 were played in both, 0 on the Mac alone, 1 on Linux alone")
    expect("an act Linux left out", start + step(1, "look") + step(2, "drag") + step(3, "leave"), other + step(1, "look") + step(2, "leave"), False,
           "2 drag: played on the Mac alone", "THEY PART AT 2 drag, after 1 acts alike")
    expect("out of view in both, wherever that is", start + step(1, "frame", "2500 W 2 20 0 999 770 400 300 Two"),
           other + step(1, "frame", "2500 W 72 20 0 999 790 400 300 Two"), True)
    expect("out of view in one", start + step(1, "frame", "2500 W 2 20 0 999 770 400 300 Two"), other + step(1, "frame"), False, "two (floating)")
    expect("what was said is not said again", start + step(1, "look") + step(2, "look-again"),
           other + step(1, "look", "2500 W 71 10 0 9 0 400 300 One") + step(2, "look-again"), False, "of those played in both, 0 ended alike")
    expect("a window that has gone", start + step(1, "close", "2500 G 2"), other + step(1, "close"), False, "two is on the screen only on Linux")
    expect("an app opened again has another number", start + step(1, "reopen", "2400 G 2", "2500 W 9 21 0 500 0 400 300 Two", "2500 M label 9 two"),
           other + step(1, "reopen"), True)
    expect("a new window's label tells its step, which is not compared", start + step(1, "new", "2500 W 9 20 0 10 10 50 50 Two", "2500 M label 9 two-new-1"),
           other + step(1, "new", "2500 W 79 20 0 10 10 50 50 Two", "2500 M label 79 two-new-44"), True)
    expect("what is tried again while the scene is set is no parting", start + step(1, "tiling-acts", end="act=drag setup=1") + step(2, "tiling-acts", end="act=drag setup=1") + step(3, "look"),
           other + step(1, "tiling-acts", end="act=drag setup=1") + step(2, "look"), True, "played on the Mac alone, while the scene was set", "0 on the Mac alone")
    expect("the setting of the scene is no act", start + step(1, "open", end="act=open-close setup=1") + step(2, "look"),
           other + step(1, "open", end="act=open-close setup=1") + step(2, "look"), True, "the Mac played 1 acts")
    for failure in failures:
        print(f"✘ {failure}")
    print("walk-diff.py: " + ("two playings are told apart where they differ, and nowhere else" if not failures else f"{len(failures)} failed"))
    return 1 if failures else 0


def main(arguments):
    if arguments == ["--self-test"]:
        return self_test()
    within, everything = 2.0, "--all" in arguments
    arguments = [word for word in arguments if word != "--all"]
    if "--within" in arguments:
        at = arguments.index("--within")
        try:
            within = float(arguments[at + 1])
        except (IndexError, ValueError):
            print("walk-diff.py: --within takes a number of points", file=sys.stderr)
            return 64
        del arguments[at:at + 2]
    if len(arguments) != 2:
        print(__doc__)
        return 64
    both = []
    for path in arguments:
        try:
            with open(path, encoding="utf-8") as handle:
                both.append(playing(handle))
        except OSError as error:
            print(f"walk-diff.py: {error}", file=sys.stderr)
            return 2
        if not both[-1]:
            print(f"walk-diff.py: {path} holds no act", file=sys.stderr)
            return 2
    report, summary, agree = compare(both[0], both[1], within)
    if everything:
        print("\n".join(report + [""]))
    print("\n".join(summary))
    return 0 if agree else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
