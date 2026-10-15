#!/usr/bin/env python3
"""Lays two playings of one walk side by side: what a hosted Mac brought back, and what the stand-ins showed on Linux.

  walk-diff.py <samples of the Mac> <samples of the stand-ins> [--within <points>] [--all]
  walk-diff.py --with <samples> --without <samples> [--within <points>] [--all] [--json <file>]
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

**With Arbor and without** (`collab/IDEAS.md`, I25). The other pair worth laying side by side is one walk played twice in one place: with Arbor running, and without it
(`WALK_WITHOUT_ARBOR=1` on a Mac, `arbor-sim walk --rehearse --without-arbor` on Linux). Of a walk by somebody who does not know Arbor (`arbor-sim walk … --stranger`), who asks nothing
of it, **the right answer is that nothing differs.** What differs is one of three things, each counted once, at the act where it first shows:

  UNASKED    a window the act does not name is elsewhere, or has another size, than without Arbor: Arbor moved what the person did not touch
  REVERSED   the window the act does name (it was dragged, double-clicked, switched to, brought back) is not where the same act leaves it without Arbor: Arbor undid, or changed,
             what the person did
  IN FRONT   another window ends in front, or an act applied in one playing and not in the other

Each is a failure at the weight of a lost window. Below them it says what the journey cost either way: acts, keys, presses of the button, seconds. Arbor must not be worse than macOS alone.

Exit code 0 when the two agree all the way, 1 when they part, 2 when a file is no playing of a walk.
"""

import difflib
import json
import sys


class Act:
    def __init__(self, number, slug):
        self.number, self.slug = number, slug
        self.kind, self.setup, self.judged = "", False, True
        # At its end: label -> (x, y, w, h); the label in front; the labels that are docked; the displays.
        self.frames, self.front, self.docked, self.displays = {}, None, set(), []
        # The labels the act is about; what it cost: keys, presses of the button, milliseconds.
        self.names, self.keys, self.presses, self.took = set(), 0, 0, 0


# The keys of an `end` that say which windows the person laid a hand on, or called.
ABOUT = ("drags", "zooms", "front", "comes", "lands", "own", "place", "leaves")


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
        elif kind == "K" and current is not None and rest[0].isdigit():
            current.keys += int(rest[0])
        elif kind == "B" and current is not None and rest[0] == "down":
            current.presses += 1
        elif kind == "M" and rest[0] == "begin" and len(rest) == 3:
            current = Act(int(rest[1]), rest[2])
            current.took = -int(parts[0])
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
            current.took += int(parts[0])
            current.names = {labels[window] for key in ABOUT for window in keys.get(key, "").split(",") if window in labels}
            acts.append(current)
            current = None
    return acts


def words(frame):
    return "%g,%g %g×%g" % frame


def where(side):
    return NAMES[side] if NAMES[side].startswith("with") else f"on {NAMES[side]}"


def out_of_view(frame, displays):
    """Less than a twentieth of it shows: Arbor has put it beyond an edge. How far beyond is between Arbor, macOS and the Dock."""
    x, y, w, h = frame
    showing = sum(max(0, min(x + w, dx + dw) - max(x, dx)) * max(0, min(y + h, dy + dh) - max(y, dy)) for dx, dy, dw, dh in displays)
    return w * h > 0 and showing < 0.05 * w * h


NAMES = ["the Mac", "Linux"]


def differences(mac, linux, within):
    """What differs at the end of an act that both played: a list of sentences."""
    found = []
    for label in sorted(set(mac.frames) | set(linux.frames)):
        here, there = mac.frames.get(label), linux.frames.get(label)
        if here is None or there is None:
            found.append(f"{label} is on the screen only {where(1) if here is None else where(0)}")
        elif out_of_view(here, mac.displays) and out_of_view(there, linux.displays):
            continue
        elif max(abs(a - b) for a, b in zip(here, there)) > within:
            state = "docked" if label in mac.docked and label in linux.docked else "floating" if label not in mac.docked | linux.docked else "docked in one"
            found.append(f"{label} ({state}): {NAMES[0]} {words(here)}, {NAMES[1]} {words(there)}")
    if mac.docked != linux.docked:
        found.append(f"docked {where(0)}: {' '.join(sorted(mac.docked)) or 'nothing'}; {where(1)}: {' '.join(sorted(linux.docked)) or 'nothing'}")
    if mac.front != linux.front:
        found.append(f"in front {where(0)}: {mac.front}; {where(1)}: {linux.front}")
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


def judged(with_arbor, without, within=2.0):
    """One walk with Arbor and without: (findings, costs). A finding is a dictionary: judgement, act (its number with Arbor), slug, window, words. Each difference once, at the act
    where it first shows: a window that was moved unasked stays elsewhere for the rest of the walk, and that is one thing Arbor did."""
    findings, said = [], set()
    # After Quit every app is called up once, to see that it still comes: that belongs to the Quit, which the control does not have.
    quit_at = max((index for index, act in enumerate(with_arbor) if act.kind == "quit-and-start" and act.slug == "quit"), default=None)
    if quit_at is not None and all(act.slug.startswith(("dock-icon-", "input-")) for act in with_arbor[quit_at + 1:]):
        with_arbor = with_arbor[:quit_at + 1] + [act for act in with_arbor[quit_at + 1:] if act.slug.startswith("input-")]
    matcher = difflib.SequenceMatcher(a=[act.slug for act in with_arbor], b=[act.slug for act in without], autojunk=False)

    def find(judgement, act, window, sentence):
        findings.append({"judgement": judgement, "act": act.number, "slug": act.slug, "window": window, "words": sentence})

    for tag, a1, a2, b1, b2 in matcher.get_opcodes():
        if tag == "equal":
            for here, there in zip(with_arbor[a1:a2], without[b1:b2]):
                now = set()
                for label in sorted(set(here.frames) | set(there.frames)):
                    a, b = here.frames.get(label), there.frames.get(label)
                    if a is not None and b is not None and max(abs(x - y) for x, y in zip(a, b)) <= within:
                        continue
                    # By how much, so that a window Arbor moves again is found again, and one that only stays where it was put is not.
                    key = (label, None if a is None or b is None else tuple(round(x - y) for x, y in zip(a, b)), a is None, b is None)
                    now.add(key)
                    if key in said or here.setup:
                        continue
                    sentence = (f"with Arbor {words(a) if a else 'not on the screen'}, without {words(b) if b else 'not on the screen'}")
                    find("REVERSED" if label in here.names | there.names else "UNASKED", here, label, sentence)
                if here.front != there.front:
                    key = ("front", here.front, there.front)
                    now.add(key)
                    if key not in said and not here.setup:
                        find("IN FRONT", here, here.front, f"with Arbor {here.front} ends in front, without {there.front}")
                said = now
        else:
            # Arbor's own start and Quit are no acts of the person's journey, and the control has none.
            for here in with_arbor[a1:a2]:
                if not here.setup and here.kind != "quit-and-start":
                    find("IN FRONT", here, None, "played with Arbor alone: without it the act did not apply")
            for there in without[b1:b2]:
                if not there.setup:
                    find("IN FRONT", there, None, "played without Arbor alone (the number is that playing's): with it the act did not apply")

    def cost(acts):
        counted = [act for act in acts if not act.setup and act.kind != "quit-and-start"]
        return {"acts": len(counted), "keys": sum(act.keys for act in counted), "presses": sum(act.presses for act in counted),
                "seconds": round(sum(act.took for act in counted) / 1000, 1)}

    return findings, {"with": cost(with_arbor), "without": cost(without)}


def verdict(findings, costs, everything):
    lines = []
    for judgement in ("UNASKED", "REVERSED", "IN FRONT"):
        mine = [finding for finding in findings if finding["judgement"] == judgement]
        acts = len({finding["act"] for finding in mine})
        lines.append(f"{judgement}: {len(mine)}" + (f", at {acts} acts" if mine else ""))
        for finding in mine if everything else mine[:6]:
            lines.append(f"    {finding['act']} {finding['slug']}: " + (f"{finding['window']}: " if finding["window"] else "") + finding["words"])
        if not everything and len(mine) > 6:
            lines.append(f"    … and {len(mine) - 6} more (--all)")
    for side in ("with", "without"):
        cost = costs[side]
        lines.append(f"{side + ' Arbor:':<15} {cost['acts']} acts, {cost['keys']} keys, {cost['presses']} presses, {cost['seconds']} s")
    acts = len({(finding["act"], finding["slug"]) for finding in findings})
    lines.append("NOTHING DIFFERS" if not findings else f"SOMETHING NEW DIFFERS AT {acts} OF {costs['with']['acts']} ACTS ({len(findings)} things)")
    return lines


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
    def judge(what, with_arbor, without, *wanted):
        findings, costs = judged(playing(with_arbor), playing(without))
        got = [(finding["judgement"], finding["act"], finding["window"]) for finding in findings]
        if got != list(wanted):
            failures.append(f"{what}: {got}, not {list(wanted)}")
        return costs

    judge("nothing differs", start + step(1, "look"), other + step(1, "look"))
    judge("a window nobody touched", start + step(1, "drag", "2500 W 2 20 0 600 0 400 300 Two", end="act=drag drags=1 front=1"), other + step(1, "drag", end="act=drag drags=71 front=71"),
          ("UNASKED", 1, "two"))
    judge("the window that was dragged", start + step(1, "drag", "2500 W 1 10 0 0 0 500 800 One", end="act=drag drags=1 front=1"),
          other + step(1, "drag", "2500 W 71 10 0 90 40 400 300 One", end="act=drag drags=71 front=71"), ("REVERSED", 1, "one"))
    judge("a double-click that is pulled back", start + step(1, "double-click", end="act=macos-own zooms=1 front=1"),
          other + step(1, "double-click", "2500 W 71 10 0 0 0 1000 800 One", end="act=macos-own zooms=71 front=71"), ("REVERSED", 1, "one"))
    judge("what stays elsewhere is one thing", start + step(1, "drag", "2500 W 2 20 0 600 0 400 300 Two", end="act=drag drags=1") + step(2, "look") + step(3, "look"),
          other + step(1, "drag", end="act=drag drags=71") + step(2, "look") + step(3, "look"), ("UNASKED", 1, "two"))
    judge("what is moved again is another", start + step(1, "drag", "2500 W 2 20 0 600 0 400 300 Two", end="act=drag drags=1") + step(2, "look", "2500 W 2 20 0 700 0 400 300 Two"),
          other + step(1, "drag", end="act=drag drags=71") + step(2, "look"), ("UNASKED", 1, "two"), ("UNASKED", 2, "two"))
    judge("another window in front", start + step(1, "look", "2500 Z 2,1"), other + step(1, "look"), ("IN FRONT", 1, "two"))
    judge("Arbor's own start and Quit are no part of the journey", start + step(1, "launch", end="act=quit-and-start") + step(2, "look") + step(3, "quit", end="act=quit-and-start"),
          other + step(1, "look"))
    judge("the roll call after the last Quit belongs to it", start + step(1, "look") + step(2, "quit", end="act=quit-and-start") + step(3, "dock-icon-one", end="act=switch front=1"),
          other + step(1, "look"))
    judge("an act that applied in one only", start + step(1, "look") + step(2, "drag"), other + step(1, "look"), ("IN FRONT", 2, None))
    judge("the scene is not judged", start + step(1, "open", "2500 W 2 20 0 600 0 400 300 Two", end="act=open-close setup=1") + step(2, "look", "2600 W 2 20 0 500 0 400 300 Two"),
          other + step(1, "open", end="act=open-close setup=1") + step(2, "look"))
    costs = judge("what a journey costs", start + step(1, "key", "2100 K 1", "2200 K 1", "2300 B down 1 1", "2300 B up 1 1"), other + step(1, "key", "2100 K 1"))
    if costs != {"with": {"acts": 1, "keys": 2, "presses": 1, "seconds": 1.0}, "without": {"acts": 1, "keys": 1, "presses": 0, "seconds": 1.0}}:
        failures.append(f"what a journey costs: {costs}")
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
    pair, report_to = None, None
    if "--json" in arguments:
        at = arguments.index("--json")
        if at + 1 >= len(arguments):
            print("walk-diff.py: --json takes a file", file=sys.stderr)
            return 64
        report_to = arguments[at + 1]
        del arguments[at:at + 2]
    if "--with" in arguments or "--without" in arguments:
        try:
            pair = [arguments[arguments.index("--with") + 1], arguments[arguments.index("--without") + 1]]
        except (ValueError, IndexError):
            print("walk-diff.py: --with <samples> --without <samples>", file=sys.stderr)
            return 64
        if len(arguments) != 4:
            print(__doc__)
            return 64
        arguments = pair
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
    if pair:
        findings, costs = judged(both[0], both[1], within)
        if report_to:
            with open(report_to, "w", encoding="utf-8") as handle:
                json.dump({"findings": findings, "costs": costs}, handle, indent=1, ensure_ascii=False)
                handle.write("\n")
        print("\n".join(verdict(findings, costs, everything)))
        return 1 if findings else 0
    report, summary, agree = compare(both[0], both[1], within)
    if everything:
        print("\n".join(report + [""]))
    print("\n".join(summary))
    return 0 if agree else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
