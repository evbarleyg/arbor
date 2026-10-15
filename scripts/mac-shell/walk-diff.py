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
of it, **the right answer is that nothing differs.** What differs is one of three things:

  UNASKED    a window the act does not name is elsewhere, or has another size, than without Arbor: Arbor moved what the person did not touch. So is whatever differs once Arbor has
             started, and once it has quit
  REVERSED   the window the act does name (it was dragged, double-clicked, put into full screen, switched to, brought back) is not where the same act leaves it without Arbor: Arbor
             undid, or changed, what the person did
  IN FRONT   another app or window ends in front, two windows lie the other way round in the pile, or an act applied in one playing and not in the other

Each is a failure at the weight of a lost window. **Each difference is counted once**, at the act where it first shows: by how much a window differs is remembered for the whole walk, so one that stays
where Arbor put it, leaves the screen and comes back, or coincides for an act (both playings fill the screen) is not found again; one that Arbor moves again, otherwise, is. What differs
before Arbor is started for the first time is the scene's or the Mac's, and nobody's doing: it is listed under THE TWO DID NOT BEGIN ALIKE and not counted. **Such a pair is a poor one**: what follows from it later (a window
held elsewhere at an edge, an act that finds nothing to click on) is still counted, and what Arbor does by just that much is not seen. An act that could not be performed in one of the playings (a press that did not take hold, which happens without Arbor too) is listed and not
judged, and what it leaves behind is nobody's doing either. A window that Arbor moves and puts back within one act is not seen here: that is `jolts.py`'s to find.

**Where a walk asks something of Arbor** (`--stranger --docked`): an act of a kind that is Arbor's alone (`ASKED` below), which the control cannot play. The windows it is about, and those its `moves=` says it may
move, are where the person wanted them: that much is remembered and not blamed, unless a window that was to be docked is lost or out of view. Every other window that moved with them is UNASKED, at that act. So
is, later, a window that an act any Mac has does not name, whatever that act's `moves=` allows: nobody touched it. **Of a window that Arbor placed this judgement sees little after that**: only that it goes where it has
not been. That it falls back to where it is without Arbor, or to an earlier place of Arbor's, by itself or at an act that merely names it (a click, an unhide), that Quit leaves it where Arbor had it, and whether Arbor did what was asked at all, is not seen here: those
are for `jolts.py` (rules 2 and 5) and for `lib-walk.sh`'s own checks. A key or a drag that means something to Arbor alone but is of a kind any Mac has (`focus_key`, `drag_onto`) counts as an act that applied in one playing only:
this judgement is for walks that ask nothing after their beginning.

Below them it says what the journey cost either way: acts, keys, presses of the button, and seconds **until the screen was at rest**, not until the script had looked it over, which takes longer where
there is an Arbor to ask; and how many of those seconds came after the last key or press of an act, which a person spends waiting. An act without a key or a press (the script opens an app; half a minute of
nothing) is in the seconds and not in the waiting; so is what the screen did between two keys of one act. At rest are the windows of apps: what macOS does in its menu bar seconds later is not waited
for. What was asked of Arbor is counted apart and is in none of the costs, so that like is held against like. Arbor must not be worse than macOS alone.

Exit code 2 as well when Arbor did not run in the first playing, or did in the second: two controls agree about everything.

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
        # The labels the act is about; the pile, by labels, from the front; the app in front; whether it is a round of input; whether windows may leave the screen by the dozen.
        self.names, self.pile, self.app, self.instrument, self.leaves_any = set(), [], None, False, False
        # The labels it may move besides, or any at all.
        self.may_move, self.moves_any = set(), False
        # What it cost: keys and presses of the button; when it began, when the last key or press came if any did, when the screen was at rest.
        self.keys, self.presses, self.began, self.hand, self.rest = 0, 0, 0, None, 0


# The keys of an `end` that say which windows the person laid a hand on, or called. (`lands` is on its way into lib-walk.sh, beside `comes`.)
ABOUT = ("drags", "zooms", "front", "comes", "lands", "own", "place", "leaves")


# The kinds of acts that are asked of Arbor and of nobody else: every word of lib-walk.sh of such a kind is left out where Arbor is not acting.
ASKED = ("dock-key", "resize", "tile-click", "view", "way-out")


class Playing(list):
    """The acts of a playing, in order; and whether a process of Arbor's was ever said to run."""
    arbor = False


def playing(lines):
    frames, labels, ids, order, acts, current, displays, app, news, level = {}, {}, {}, [], Playing(), None, {}, None, {}, set()
    for line in lines:
        parts = line.split()
        if len(parts) < 3:
            continue
        kind, rest = parts[1], parts[2:]
        # The windows of apps, as everywhere here. macOS puts up and takes down windows of its own above them long after an act, an indicator in the menu bar among them, and a `G` does not
        # say of which kind its window was.
        ordinary = kind == "W" and len(rest) >= 7 and rest[2] == "0"
        hand = kind == "B" or kind == "K" and rest[0].isdigit() and int(rest[0]) > 0
        if current is not None and (hand or ordinary or kind == "Z" or kind == "G" and rest[0] in level):
            current.rest = int(parts[0])
            if hand:
                current.hand = current.rest
        if kind in "WG":
            (level.add if ordinary else level.discard)(rest[0])
        if ordinary:
            frames[rest[0]] = tuple(float(number) for number in rest[3:7])
        elif kind == "G":
            frames.pop(rest[0], None)
        elif kind == "A" and len(rest) == 2:
            app = rest[1]
        elif kind == "D" and len(rest) == 4:
            displays["main"] = tuple(float(number) for number in rest)
        elif kind == "Y":
            if len(rest) >= 5:
                displays[rest[0]] = tuple(float(number) for number in rest[1:5])
            else:
                displays.pop(rest[0], None)
        elif kind == "Z":
            order = rest[0].split(",")
        elif kind == "M" and rest[0] == "arbor" and len(rest) == 2 and rest[1].isdigit():
            acts.arbor = True
        elif kind == "M" and rest[0] == "label" and len(rest) == 3:
            # A new window's label ends in the number of its step, which differs as soon as one act does. It goes by which of its app's new windows it is.
            name = rest[2]
            if "-new-" in name:
                base = name[:name.index("-new-")]
                news[base] = news.get(base, 0) + 1
                name = f"{base}-new.{news[base]}"
            labels[rest[1]] = name
            # The window that was given a name last stands for it: an app that was opened again has another number.
            ids[name] = rest[1]
        elif kind == "K" and current is not None and rest[0].isdigit():
            current.keys += int(rest[0])
        elif kind == "B" and current is not None and rest[0] == "down":
            current.presses += 1
        elif kind == "M" and rest[0] == "begin" and len(rest) == 3:
            current = Act(int(rest[1]), rest[2])
            current.began = current.rest = int(parts[0])
        elif kind == "M" and rest[0] == "end" and current is not None and rest[1] == str(current.number):
            keys = dict(word.split("=", 1) for word in rest[2:] if "=" in word)
            current.kind = keys.get("act", "")
            # A round of input is an instrument and no act either: it is compared, and counts towards nothing.
            current.instrument = keys.get("act") == "instrument"
            current.setup = keys.get("setup") == "1" or current.instrument
            current.judged = keys.get("judge") != "no"
            current.leaves_any = keys.get("leaves") == "any"
            current.frames = {name: frames[window] for name, window in ids.items() if window in frames}
            current.pile = [labels[window] for window in order if ids.get(labels.get(window)) == window and window in frames]
            current.front = current.pile[0] if current.pile else None
            current.app = app
            current.docked = {labels[window] for window in keys.get("docked", "").split(",") if window in labels}
            current.displays = list(displays.values())
            current.names = {labels[window] for key in ABOUT for window in keys.get(key, "").split(",") if window in labels}
            current.may_move, current.moves_any = {labels[window] for window in keys.get("moves", "").split(",") if window in labels}, keys.get("moves") == "any"
            # Full screen says only on the way out whose it was.
            if current.slug == "leave-full-screen":
                for earlier in [act for act in acts if act.slug == "full-screen"][-1:]:
                    earlier.names |= {labels[window] for window in keys.get("comes", "").split(",") if window in labels}
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


def judged(with_arbor, without, within=2.0):
    """One walk with Arbor and without: (findings, costs). A finding is a dictionary: judgement, playing (whose number `act` is), act, slug, window, words."""
    findings, undone = [], []
    # By how much each window has been seen to differ, for the whole walk: (dx, dy, dw, dh), or which playing lacks it. And which pairs have been seen the other way round in the pile.
    seen, turned, fronts = {}, set(), set()
    # Of those, what a round of input left behind that the control has not: excused for as long as it lasts.
    excused = set()
    # And of those, what still showed at the last look. Of two windows of which one has gone for good the excuse is never used up, and it is about nothing that can be seen.
    alive = set()
    # The windows that stayed on the screen, or off it, because Arbor undid an act that takes windows away by the dozen: remembered until both playings show them again.
    stayed = {}
    # After the last Quit every app is called up once, to see that it still comes: that belongs to the Quit, which the control does not have.
    quit_at = max((index for index, act in enumerate(with_arbor) if act.kind == "quit-and-start" and act.slug == "quit"), default=None)
    if quit_at is not None and all(act.slug.startswith(("dock-icon-", "input-")) for act in with_arbor[quit_at + 1:]):
        with_arbor = with_arbor[:quit_at + 1] + [act for act in with_arbor[quit_at + 1:] if act.slug.startswith("input-")]
    matcher = difflib.SequenceMatcher(a=[act.slug for act in with_arbor], b=[act.slug for act in without], autojunk=False)
    # Before it is started for the first time Arbor has done nothing: what differs by then is how the two playings found the Mac. It is said, so that nobody takes what follows from it for
    # Arbor's: a window that lies elsewhere is held elsewhere at an edge, covers what another act wants to click on, and comes forward in another turn.
    # A playing whose first such act is a Quit had Arbor from the outset.
    first = next((act for act in with_arbor if act.kind == "quit-and-start"), None)
    first = first if first is not None and first.slug == "launch" else None
    started, otherwise = first is None, []

    def find(judgement, act, window, sentence, playing="with"):
        findings.append({"judgement": judgement, "playing": playing, "act": act.number, "slug": act.slug, "window": window, "words": sentence})

    def known(label, delta):
        return any(type(old) is type(delta) and (old == delta if isinstance(delta, str) else max(abs(a - b) for a, b in zip(old, delta)) <= within) for old in seen.get(label, []))

    def look(here, there, blame, names, pile=True, asked=False):
        """Holds the screen at the end of `here` (with Arbor) against that at the end of `there` (without). `blame` False: what differs is remembered, and is nobody's doing. `pile` False: which
        window lies over which is the doing of a round of input. `asked` True: where the windows are that the act is about is what the person told Arbor."""
        reversed_here = False
        for named in (True, False):
            for label in sorted(set(here.frames) | set(there.frames)):
                if (label in names) != named:
                    continue
                a, b = here.frames.get(label), there.frames.get(label)
                sentence = f"with Arbor {words(a) if a else 'not on the screen'}, without {words(b) if b else 'not on the screen'}"
                if a is None or b is None:
                    delta = "with" if b is None else "without"
                    # Where an act takes the other windows off the screen and Arbor undid the act, that they are still there is the same thing over again.
                    if not named and (here.leaves_any or there.leaves_any) and reversed_here:
                        if not known(label, delta):
                            seen.setdefault(label, []).append(delta)
                            stayed[label] = delta
                        continue
                else:
                    # Both show it again: that is over, and the same thing another time is another thing.
                    if label in stayed:
                        seen[label].remove(stayed.pop(label))
                    delta = tuple(x - y for x, y in zip(a, b))
                    if max(abs(number) for number in delta) <= within:
                        continue
                if known(label, delta):
                    continue
                seen.setdefault(label, []).append(delta)
                # Asked to dock a window, Arbor may not lose it, nor send it out of view. (A view may: that is what a view is.)
                if asked and named and a is not None and not (here.kind == "dock-key" and here.displays and out_of_view(a, here.displays)):
                    continue
                if blame:
                    reversed_here = reversed_here or named
                    find("REVERSED" if named else "UNASKED", here, label, sentence)
        both = [label for label in here.pile if label in there.pile]
        place = {label: index for index, label in enumerate(there.pile)}
        inverted = [(over, under) for index, over in enumerate(both) for under in both[index + 1:] if place[over] > place[under]]
        front = (here.front, there.front, here.app, there.app) if here.front != there.front or here.app != there.app else None
        # Once the two agree again the excuse is used up: the same difference another time is somebody's doing. Of two windows that are not both to be seen nobody can say that they agree.
        for old in [old for old in excused if old != front and old not in inverted and old[0] in both and old[1] in both]:
            excused.discard(old)
            turned.discard(old)
            fronts.discard(old)
        new = [pair for pair in inverted if pair not in turned]
        turned.update(new)
        if not pile:
            excused.update(new)
        if front is not None and front not in fronts:
            fronts.add(front)
            if not pile:
                excused.add(front)
            elif blame:
                find("IN FRONT", here, here.front, f"with Arbor {here.front} of {here.app} ends in front, without {there.front} of {there.app}")
        elif new and blame and pile:
            find("IN FRONT", here, new[0][0], f"with Arbor {new[0][0]} lies over {new[0][1]}, without under it" + (f"; and {len(new) - 1} more pairs" if len(new) > 1 else ""))
        alive.clear()
        alive.update(old for old in excused if old == front or old in inverted)

    def parted(here, there):
        """In what the two screens differ, in words."""
        told = [f"{label}: with Arbor {words(a) if a else 'not on the screen'}, without {words(b) if b else 'not on the screen'}"
                for label, a, b in ((label, here.frames.get(label), there.frames.get(label)) for label in sorted(set(here.frames) | set(there.frames)))
                if a is None or b is None or max(abs(x - y) for x, y in zip(a, b)) > within]
        if here.front != there.front or here.app != there.app:
            told.append(f"in front: with Arbor {here.front} of {here.app}, without {there.front} of {there.app}")
        both = [label for label in here.pile if label in there.pile]
        place = {label: index for index, label in enumerate(there.pile)}
        if turns := sum(place[over] > place[under] for index, over in enumerate(both) for under in both[index + 1:]):
            told.append(f"{turns} pairs of windows lie the other way round")
        return told

    def starts(here):
        nonlocal started, otherwise
        if here is first:
            started, otherwise = True, parted(before, last) if before is not None and last is not None else []

    last = before = None
    for tag, a1, a2, b1, b2 in matcher.get_opcodes():
        if tag == "equal":
            for here, there in zip(with_arbor[a1:a2], without[b1:b2]):
                starts(here)
                performed = here.judged and there.judged
                if not performed and not here.setup:
                    undone.append({"act": here.number, "slug": here.slug, "playing": "with" if not here.judged else "without"})
                # The scene is nobody's doing. A round of input is no act, and where it finds the windows Arbor put them all the same: after the last Quit it is the one look there is.
                # Whom a round clicks on depends on who lies where when it begins. Begun over what an earlier round left, which the control has not had and which still shows, it ends as it does
                # by the rounds' doing, if either pressed on anything. That is so in four walks of five: there nobody looks at who is in front after the last Quit, only at Quit itself.
                look(here, there, performed and started and (here.instrument or not here.setup), set() if here.instrument else here.names | there.names,
                     pile=not (here.instrument and alive and (here.presses or there.presses)))
                last, before = there, here
        else:
            for here in with_arbor[a1:a2]:
                # The Mac without Arbor as it stands at that point of the journey. Before its first act there is nothing to hold Arbor against: what differs from the end of that act is remembered.
                there, begun = (last, True) if last is not None else (without[0] if without else None, False)
                if there is None:
                    continue
                starts(here)
                before = here
                if not started:
                    look(here, there, False, set())
                elif here.kind == "quit-and-start" or here.instrument:
                    # Arbor's own start and Quit, and the round of input after the start, are no part of the person's journey. What differs after them nobody asked for.
                    # A round of input clicks on windows: which is in front after it is the round's doing, if it pressed on any. So if the control has just had a round itself: a round presses
                    # only on title bars of which a free point shows, so the second over one pile does not click as the first did. (A control that plays every round has no such act.)
                    look(here, there, begun, set(), pile=not (here.instrument and here.presses))
                elif here.setup:
                    look(here, there, False, set())
                elif here.kind in ASKED:
                    if not here.judged:
                        undone.append({"act": here.number, "slug": here.slug, "playing": "with"})
                    look(here, there, begun and here.judged, set(here.frames) | set(there.frames) if here.moves_any else here.names | here.may_move, asked=True)
                else:
                    find("IN FRONT", here, None, "played with Arbor alone: without it the act did not apply")
            for there in without[b1:b2]:
                if not there.setup and started:
                    find("IN FRONT", there, None, "played without Arbor alone: with it the act did not apply", playing="without")
                last = there

    def cost(acts):
        mine = [act for act in acts if not act.setup and act.kind != "quit-and-start"]
        counted = [act for act in mine if act.kind not in ASKED]
        return {"acts": len(counted), "keys": sum(act.keys for act in counted), "presses": sum(act.presses for act in counted),
                "seconds": round(sum(act.rest - act.began for act in counted) / 1000, 1),
                "waiting": round(sum(max(0, act.rest - act.hand) for act in counted if act.hand is not None) / 1000, 1), "asked": len(mine) - len(counted)}

    return findings, {"with": cost(with_arbor), "without": cost(without), "not_performed": undone, "began_otherwise": otherwise}


def unfit(with_arbor, without):
    """Why the two are no pair of a walk with Arbor and its control, or None. Two controls agree about everything."""
    if not with_arbor.arbor:
        return "in the playing given as --with no Arbor was ever started"
    if without.arbor:
        return "in the playing given as --without Arbor was started"
    return None


def verdict(findings, costs, everything):
    lines = []
    for judgement in ("UNASKED", "REVERSED", "IN FRONT"):
        mine = [finding for finding in findings if finding["judgement"] == judgement]
        acts = len({(finding["playing"], finding["act"]) for finding in mine})
        lines.append(f"{judgement}: {len(mine)}" + (f", at {acts} acts" if mine else ""))
        for finding in mine if everything else mine[:6]:
            lines.append(f"    {finding['act']}{' (of the playing without)' if finding['playing'] == 'without' else ''} {finding['slug']}: " + (f"{finding['window']}: " if finding["window"] else "") + finding["words"])
        if not everything and len(mine) > 6:
            lines.append(f"    … and {len(mine) - 6} more (--all)")
    if costs["began_otherwise"]:
        lines.append("THE TWO DID NOT BEGIN ALIKE. Before Arbor was started, so nobody's doing and not counted; what follows from it is among the above all the same, and what hides behind it is not seen:")
        lines += [f"    {sentence}" for sentence in costs["began_otherwise"]]
    for act in costs["not_performed"]:
        lines.append(f"not performed {act['playing']} Arbor, so not judged: {act['act']} {act['slug']}")
    for side in ("with", "without"):
        cost = costs[side]
        lines.append(f"{side + ' Arbor:':<15} {cost['acts']} acts, {cost['keys']} keys, {cost['presses']} presses, {cost['seconds']} s until the screen was at rest, {cost['waiting']} s of them after the last key or press"
                     + (f"; and {cost['asked']} acts asked of Arbor, which are in none of these" if cost["asked"] else ""))
    acts = len({(finding["playing"], finding["act"]) for finding in findings})
    lines.append("NOTHING DIFFERS" if not findings else f"SOMETHING NEW DIFFERS AT {acts} OF {costs['with']['acts'] + costs['with']['asked']} ACTS ({len(findings)} things)")
    return lines


def self_test():
    start = ["1000 D 0 0 1000 800", "1000 W 1 10 0 0 0 400 300 One", "1000 W 2 20 0 500 0 400 300 Two", "1000 Z 1,2", "1000 M label 1 one", "1000 M label 2 two"]
    other = ["5000 D 0 0 1000 800", "5000 W 71 10 0 0 0 400 300 One", "5000 W 72 20 0 500 0 400 300 Two", "5000 Z 71,72", "5000 M label 71 one", "5000 M label 72 two"]

    def step(number, slug, *lines, end="act=idle"):
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
    judge("whichever playing says that it was", start + step(1, "drag", "2500 W 1 10 0 0 0 500 800 One", end="act=drag"), other + step(1, "drag", "2500 W 71 10 0 90 40 400 300 One", end="act=drag drags=71"),
          ("REVERSED", 1, "one"))
    judge("be it the one with Arbor", start + step(1, "drag", "2500 W 1 10 0 0 0 500 800 One", end="act=drag drags=1"), other + step(1, "drag", "2500 W 71 10 0 90 40 400 300 One", end="act=drag"), ("REVERSED", 1, "one"))
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
    judge("an act that applied in one only", start + step(1, "look") + step(2, "drag", end="act=drag"), other + step(1, "look"), ("IN FRONT", 2, None))
    judge("the scene is not judged", start + step(1, "open", "2500 W 2 20 0 600 0 400 300 Two", end="act=open-close setup=1") + step(2, "look", "2600 W 2 20 0 500 0 400 300 Two"),
          other + step(1, "open", end="act=open-close setup=1") + step(2, "look"))
    costs = judge("what a journey costs", start + step(1, "key", "2100 K 1", "2200 K 1", "2300 B down 1 1", "2300 B up 1 1"), other + step(1, "key", "2100 K 1"))
    # Until the screen was at rest: the last key at 2200 and the press at 2300, not the script's `end` at 3000.
    if costs != {"with": {"acts": 1, "keys": 2, "presses": 1, "seconds": 0.3, "waiting": 0.0, "asked": 0}, "without": {"acts": 1, "keys": 1, "presses": 0, "seconds": 0.1, "waiting": 0.0, "asked": 0},
                 "not_performed": [], "began_otherwise": []}:
        failures.append(f"what a journey costs: {costs}")

    def waits(what, lines, seconds, waiting):
        cost = judged(playing(start + step(1, "act", *lines)), playing(other + step(1, "act")))[1]["with"]
        if (cost["seconds"], cost["waiting"]) != (seconds, waiting):
            failures.append(f"{what}: {cost['seconds']} s, {cost['waiting']} s of them waiting, not {seconds} and {waiting}")

    waits("the pile is no hand", ["2100 K 1", "2400 Z 2,1"], 0.4, 0.3)
    waits("letting go is", ["2100 B down 1 1", "2300 B up 9 9", "2400 W 1 10 0 8 8 400 300 One"], 0.4, 0.1)
    waits("no key and no press: nothing to wait from", ["2700 W 1 10 0 8 8 400 300 One"], 0.7, 0.0)
    waits("no key at all is no key", ["2100 K 1", "2200 K 0", "2300 K x", "2400 W 1 10 0 8 8 400 300 One"], 0.4, 0.3)
    waits("what the screen does between two keys is in the seconds alone", ["2100 K 1", "2800 W 1 10 0 8 8 400 300 One", "2900 K 1", "2950 W 1 10 0 9 9 400 300 One"], 0.9, 0.1)
    waits("a window that has gone to another level is no ordinary window when it goes", ["2100 K 1", "2200 W 2 20 25 500 0 400 300 Two", "2900 G 2"], 0.1, 0.0)
    waits("what has gone cannot go again", ["2100 K 1", "2200 G 2", "2900 G 2"], 0.2, 0.1)
    waits("a clock that goes back makes nobody wait less than nothing", ["2300 K 1", "2200 W 1 10 0 8 8 400 300 One"], 0.2, 0.0)
    expect("a window at another level for a while is where it was", start + step(1, "look", "2500 W 1 10 3 0 0 400 300 One"), other + step(1, "look"), True)
    said = "\n".join(verdict(*judged(playing(start + step(1, "act", "2100 K 1", "2400 Z 2,1", "2500 Z 1,2")), playing(other + step(1, "act"))), False))
    if "0.5 s until the screen was at rest, 0.4 s of them after the last key or press" not in said:
        failures.append(f"the verdict says what was waited: {said}")
    # As a hosted Mac had it: 25 acts of 87 "lasted" two seconds and a half longer by a window of 28 by 28 points in the menu bar.
    costs = judge("a window of macOS's own that goes seconds later keeps nobody waiting", start + ["1000 W 5 1 2147483630 900 1 28 28 Window_Server"] + step(1, "key", "2100 K 1", "2400 W 1 10 0 0 0 400 300 One", "2900 G 5"),
                  other + step(1, "key", "2100 K 1", "2200 W 71 10 0 0 0 400 300 One"))
    if (costs["with"]["seconds"], costs["with"]["waiting"], costs["without"]["seconds"], costs["without"]["waiting"]) != (0.4, 0.3, 0.2, 0.1):
        failures.append(f"a window of macOS's own that goes seconds later keeps nobody waiting: {costs}")
    costs = judge("a window of an app that goes is waited for", start + step(1, "close", "2100 K 1", "2900 G 2"), other + step(1, "close", "2100 K 1", "2300 G 72"))
    if (costs["with"]["waiting"], costs["without"]["waiting"]) != (0.8, 0.2):
        failures.append(f"a window of an app that goes is waited for: {costs}")

    moved = step(1, "drag", "2500 W 2 20 0 600 0 400 300 Two", end="act=drag drags=1")
    still = step(1, "drag", end="act=drag drags=71")
    judge("what leaves the screen in both and comes back is the same thing still",
          start + moved + step(2, "full-screen", "2500 G 2", end="act=macos-own leaves=any") + step(3, "leave-full-screen", "2500 W 2 20 0 600 0 400 300 Two", end="act=macos-own comes=1"),
          other + still + step(2, "full-screen", "2500 G 72", end="act=macos-own leaves=any") + step(3, "leave-full-screen", "2500 W 72 20 0 500 0 400 300 Two", end="act=macos-own comes=71"),
          ("UNASKED", 1, "two"))
    scene = step(1, "open", "2100 W 1 10 0 30 40 400 300 One", end="act=open-close setup=1")
    judge("what the scene differs by comes back after both have filled the screen, and is nobody's doing",
          start + scene + step(2, "double-click", "2500 W 1 10 0 0 0 1000 800 One", end="act=macos-own zooms=1") + step(3, "again", "2500 W 1 10 0 30 40 400 300 One", end="act=macos-own zooms=1"),
          other + step(1, "open", end="act=open-close setup=1") + step(2, "double-click", "2500 W 71 10 0 0 0 1000 800 One", end="act=macos-own zooms=71")
          + step(3, "again", "2500 W 71 10 0 0 0 400 300 One", end="act=macos-own zooms=71"))
    costs = judge("a press that did not take hold in the control is nobody's reversal, nor is what it leaves behind",
                  start + step(1, "drag", "2500 W 1 10 0 90 40 400 300 One", end="act=drag drags=1") + step(2, "look"),
                  other + step(1, "drag", end="act=drag judge=no performed=no undone=drag_window drags=71") + step(2, "look"))
    if costs["not_performed"] != [{"act": 1, "slug": "drag", "playing": "without"}]:
        failures.append(f"an act that was not performed is listed: {costs['not_performed']}")
    judge("what Quit moves", start + step(1, "look") + step(2, "quit", "2500 W 2 20 0 0 400 300 200 Two", end="act=quit-and-start"), other + step(1, "look"), ("UNASKED", 2, "two"))
    judge("what shows only in the round of input after Quit", start + step(1, "look") + step(2, "quit", end="act=quit-and-start")
          + step(3, "input-after", "2500 W 2 20 0 0 400 300 200 Two", end="act=instrument round=after front=1"), other + step(1, "look") + step(2, "input-after", end="act=instrument round=after front=71"),
          ("UNASKED", 3, "two"))
    judge("a round of input that the control has not leaves in front what it clicked last, and a window it finds elsewhere Arbor moved all the same",
          start + step(1, "look") + step(2, "input-last", "2400 B down 10 10", "2500 Z 2,1", "2500 W 1 10 0 0 400 400 300 One", end="act=instrument round=last front=2") + step(3, "quit", end="act=quit-and-start"),
          other + step(1, "look"), ("UNASKED", 2, "one"))
    before, vorher = step(1, "input-before", end="act=instrument round=before front=1"), step(1, "input-before", end="act=instrument round=before front=71")
    judge("a round is not the same twice: after a round of its own the control does not stand as a second round would leave it",
          start + before + step(2, "launch", end="act=quit-and-start") + step(3, "input-started", "2400 B down 10 10", "2500 Z 2,1", end="act=instrument round=started front=1") + step(4, "look"), other + vorher + step(2, "look"))
    judge("nor as to two windows below the one in front", start + ["1000 W 3 30 0 100 400 400 300 Three", "1000 Z 1,2,3", "1000 M label 3 three"] + before + step(2, "launch", end="act=quit-and-start")
          + step(3, "input-started", "2400 B down 10 10", "2500 Z 1,3,2", end="act=instrument round=started front=1"), other + ["5000 W 73 30 0 100 400 400 300 Three", "5000 Z 71,72,73", "5000 M label 73 three"] + vorher)
    started = step(3, "input-started", "2400 B down 10 10", "2500 Z 2,1", end="act=instrument round=started front=2")
    judge("where the control plays that round too, the two begin alike, and another window in front at its end is Arbor's doing",
          start + before + step(2, "launch", end="act=quit-and-start") + started, other + vorher + step(2, "input-started", "6400 B down 10 10", end="act=instrument round=started front=71"), ("IN FRONT", 3, "two"))
    judge("before it is started Arbor has done nothing: how the two playings found the Mac is nobody's doing",
          start + step(1, "input-before", "2400 B down 10 10", "2500 Z 2,1", "2500 W 1 10 0 0 400 400 300 One", end="act=instrument round=before front=2") + step(2, "launch", end="act=quit-and-start") + step(3, "look"),
          other + step(1, "input-before", "6400 B down 10 10", end="act=instrument round=before front=71") + step(2, "look"))
    judge("from its start on it has", start + before + step(2, "launch", "2500 W 1 10 0 0 400 400 300 One", end="act=quit-and-start") + step(3, "look"), other + vorher + step(2, "look"), ("UNASKED", 2, "one"))
    launch = step(2, "launch", end="act=quit-and-start")
    judge("nor has it at an act before its start that is no round", start + step(1, "look", "2500 W 1 10 0 0 400 400 300 One") + launch + step(3, "look-again"), other + step(1, "look") + step(2, "look-again"))
    judge("nor at one that only one playing has", start + step(1, "drag", "2500 Z 2,1", end="act=drag") + launch + step(3, "look"), other + step(1, "look"))
    judge("whichever", start + before + launch + step(3, "look"), other + step(1, "drag", end="act=drag") + step(2, "input-before", end="act=instrument round=before front=71") + step(3, "look"))
    judge("one of the control's alone where Arbor has its start comes after it: the walk's first act may be the one that did not apply", start + before + launch + step(3, "look"),
          other + vorher + step(2, "drag", end="act=drag") + step(3, "look"), ("IN FRONT", 2, None))
    judge("it is the first start that counts", start + before + launch + step(3, "quit", end="act=quit-and-start") + step(4, "look", "2500 W 1 10 0 0 400 400 300 One") + step(5, "launch", end="act=quit-and-start"),
          other + vorher + step(2, "look"), ("UNASKED", 4, "one"))
    judge("and where it stands in the walk, not what the acts are numbered", start + step(7, "input-before", end="act=instrument round=before front=1") + step(8, "launch", end="act=quit-and-start")
          + step(3, "look", "2500 W 1 10 0 0 400 400 300 One"), other + vorher + step(2, "look"), ("UNASKED", 3, "one"))
    judge("the start that turns the pile right after the round that both have had", start + before + step(2, "launch", "2500 Z 2,1", end="act=quit-and-start"), other + vorher, ("IN FRONT", 2, "two"))
    judge("a round of Arbor's alone that pressed on nothing has brought nobody forward", start + before + launch + step(3, "input-started", "2500 Z 2,1", end="act=instrument round=started front=2"),
          other + vorher, ("IN FRONT", 3, "two"))
    costs = judge("how the two found the Mac is said", start + step(1, "input-before", "2500 Z 2,1", "2500 W 1 10 0 0 400 400 300 One", end="act=instrument round=before front=2") + launch + step(3, "look"),
                  other + vorher + step(2, "look"))
    if costs["began_otherwise"] != ["one: with Arbor 0,400 400×300, without 0,0 400×300", "in front: with Arbor two of None, without one of None", "1 pairs of windows lie the other way round"]:
        failures.append(f"how the two found the Mac is said: {costs['began_otherwise']}")
    if "THE TWO DID NOT BEGIN ALIKE" not in "\n".join(verdict([], costs, False)):
        failures.append("how the two found the Mac is said: not in the verdict")
    if "    one: with Arbor 0,400 400×300, without 0,0 400×300" not in verdict([], costs, False):
        failures.append("how the two found the Mac is said: the headline alone")

    def began(what, with_arbor, without, told, *wanted):
        costs = judge(what, with_arbor, without, *wanted)
        if costs["began_otherwise"] != told:
            failures.append(f"{what}: {costs['began_otherwise']}, not {told}")

    moved = step(3, "look", "2500 W 1 10 0 0 400 400 300 One")
    began("what Arbor does after its start is no part of it, nor at Quit", start + before + launch + moved + step(4, "quit", end="act=quit-and-start"), other + vorher + step(2, "look"), [], ("UNASKED", 3, "one"))
    began("nor at a second start", start + before + launch + moved + step(4, "quit", end="act=quit-and-start") + step(5, "launch", end="act=quit-and-start"), other + vorher + step(2, "look"), [],
          ("UNASKED", 3, "one"))
    began("a playing that begins with a Quit had Arbor from the outset", start + step(1, "look", "2500 W 1 10 0 0 400 400 300 One") + step(2, "quit", end="act=quit-and-start") + step(3, "launch", end="act=quit-and-start"),
          other + step(1, "look"), [], ("UNASKED", 1, "one"))
    began("a start that both have is a start", start + before + launch + moved, other + vorher + step(2, "launch", end="act=quit-and-start") + step(3, "look"), [], ("UNASKED", 3, "one"))
    began("it is the screen right before the start that counts: what the two agree on again by then is over", start + step(1, "open", "2500 W 1 10 0 0 400 400 300 One", end="act=open-close setup=1")
          + step(2, "input-before", "2500 W 1 10 0 0 0 400 300 One", end="act=instrument round=before front=1") + step(3, "launch", end="act=quit-and-start"),
          other + step(1, "open", end="act=open-close setup=1") + step(2, "input-before", end="act=instrument round=before front=71"), [])
    began("an act of the scene that the playing with Arbor alone has, too", start + before + step(2, "tiling-acts", "2500 W 1 10 0 0 400 400 300 One", end="act=drag setup=1") + step(3, "launch", end="act=quit-and-start"),
          other + vorher, ["one: with Arbor 0,400 400×300, without 0,0 400×300"])
    began("two points are no difference there either", start + step(1, "input-before", "2500 W 1 10 0 2 0 400 300 One", end="act=instrument round=before front=1") + launch, other + vorher, [])
    began("a window that one playing alone has", start + step(1, "input-before", "2500 G 2", end="act=instrument round=before front=1") + launch, other + vorher, ["two: with Arbor not on the screen, without 500,0 400×300"])
    began("whichever", start + before + launch, other + step(1, "input-before", "6500 G 72", end="act=instrument round=before front=71"), ["two: with Arbor 500,0 400×300, without not on the screen"])
    began("another app in front with the same window", start + ["1000 A 10 app.one"] + step(1, "input-before", "2500 A 20 app.two", end="act=instrument round=before front=1") + launch,
          other + ["5000 A 10 app.one"] + vorher, ["in front: with Arbor one of app.two, without one of app.one"])
    judge("a round of Arbor's alone that pressed on nothing, after one of the control's that did",  start + step(1, "input-before", "2400 B down 10 10", end="act=instrument round=before front=1") + launch
          + step(3, "input-started", "2500 Z 2,1", end="act=instrument round=started front=2"), other + step(1, "input-before", "6400 B down 10 10", end="act=instrument round=before front=71"), ("IN FRONT", 3, "two"))
    judge("what the control alone tries again while a scene is set is no act, after the start either", start + before + launch + step(3, "look"),
          other + vorher + step(2, "tiling-acts", end="act=drag setup=1") + step(3, "look"))
    costs = judge("what the start does is no part of that", start + before + step(2, "launch", "2500 W 1 10 0 0 400 400 300 One", end="act=quit-and-start"), other + vorher, ("UNASKED", 2, "one"))
    if costs["began_otherwise"] or "BEGIN ALIKE" in "\n".join(verdict([], costs, False)):
        failures.append(f"what the start does is no part of how the two found the Mac: {costs['began_otherwise']}")
    judge("what the start brings to the front", start + step(1, "look") + step(2, "launch", "2500 Z 2,1", end="act=quit-and-start") + step(3, "look-again"), other + step(1, "look") + step(2, "look-again"),
          ("IN FRONT", 2, "two"))
    judge("what Quit brings to the front", start + step(1, "look") + step(2, "quit", "2500 Z 2,1", end="act=quit-and-start"), other + step(1, "look"), ("IN FRONT", 2, "two"))
    judge("chosen from the menu with a press, too: a Quit is no round", start + step(1, "look") + step(2, "quit", "2400 B down 900 10", "2500 Z 2,1", end="act=quit-and-start"), other + step(1, "look"),
          ("IN FRONT", 2, "two"))
    rounds = step(2, "input-last", "2400 B down 10 10", "2500 Z 2,1", end="act=instrument round=last front=2")
    judge("what a round left is excused for as long as it lasts", start + step(1, "look") + rounds + step(3, "look-again") + step(4, "and-again"), other + step(1, "look") + step(2, "look-again") + step(3, "and-again"))
    both = (start + ["1000 W 3 30 0 100 400 400 300 Three", "1000 Z 1,2,3", "1000 M label 3 three"] + step(1, "look"), other + ["5000 W 73 30 0 100 400 400 300 Three", "5000 Z 71,72,73", "5000 M label 73 three"] + step(1, "look"))
    judge("a round that both have, begun over what a round of Arbor's alone left, ends as it does by the rounds' doing",
          both[0] + rounds + step(3, "quit", end="act=quit-and-start") + step(4, "input-after", "2400 B down 10 10", "2500 Z 3,2,1", end="act=instrument round=after front=3"),
          both[1] + step(2, "input-after", "6500 Z 72,71,73", end="act=instrument round=after front=72"))
    judge("so if it was the control's that pressed",
          both[0] + rounds + step(3, "quit", end="act=quit-and-start") + step(4, "input-after", "2500 Z 3,2,1", end="act=instrument round=after front=3"),
          both[1] + step(2, "input-after", "6400 B down 10 10", "6500 Z 72,71,73", end="act=instrument round=after front=72"))
    judge("a round in which nobody pressed on anything turned nothing round",
          both[0] + rounds + step(3, "quit", end="act=quit-and-start") + step(4, "input-after", "2500 Z 3,2,1", end="act=instrument round=after front=3"),
          both[1] + step(2, "input-after", "6500 Z 72,71,73", end="act=instrument round=after front=72"), ("IN FRONT", 4, "three"))
    judge("nor does an excuse count that is about a window gone since: the two began alike",
          both[0] + rounds + step(3, "close-two", "2500 G 2", "2500 Z 1,3", end="act=open-close leaves=2") + step(4, "quit", end="act=quit-and-start")
          + step(5, "input-after", "2400 B down 10 10", "2500 Z 3,1", end="act=instrument round=after front=3"),
          both[1] + step(2, "close-two", "6500 G 72", "6500 Z 71,73", end="act=open-close leaves=72") + step(3, "input-after", "6400 B down 10 10", end="act=instrument round=after front=71"), ("IN FRONT", 5, "three"))
    judge("a window that it finds elsewhere Arbor moved all the same",
          both[0] + rounds + step(3, "quit", end="act=quit-and-start") + step(4, "input-after", "2400 B down 10 10", "2500 Z 3,2,1", "2500 W 1 10 0 0 400 400 300 One", end="act=instrument round=after front=3"),
          both[1] + step(2, "input-after", "6500 Z 72,71,73", end="act=instrument round=after front=72"), ("UNASKED", 4, "one"))
    judge("an act is no round: what is new after it is somebody's doing, whatever is excused meanwhile",
          both[0] + rounds + step(3, "press-somewhere", "2400 B down 10 10", "2500 Z 3,2,1"), both[1] + step(2, "press-somewhere", "6400 B down 10 10"), ("IN FRONT", 3, "three"))
    judge("begun alike, it ends alike or it is Arbor's doing",
          both[0] + step(2, "quit", end="act=quit-and-start") + step(3, "input-after", "2400 B down 10 10", "2500 Z 3,2,1", end="act=instrument round=after front=3"),
          both[1] + step(2, "input-after", "6500 Z 72,71,73", end="act=instrument round=after front=72"), ("IN FRONT", 3, "three"))
    judge("and no longer: the same thing again, after the two have agreed, is somebody's doing",
          start + step(1, "look") + rounds + step(3, "click-one", "2500 Z 1,2", end="act=switch front=1") + step(4, "leave-alone", "2500 Z 2,1"),
          other + step(1, "look") + step(2, "click-one", end="act=switch front=71") + step(3, "leave-alone"), ("IN FRONT", 4, "two"))
    again = step(3, "click-one", "2500 Z 1,2", end="act=switch front=1") + step(4, "leave-alone", "2500 Z 2,1") + step(5, "click-one", "2500 Z 1,2", end="act=switch front=1") + step(6, "leave-alone", "2500 Z 2,1")
    wieder = step(2, "click-one", end="act=switch front=71") + step(3, "leave-alone") + step(4, "click-one", end="act=switch front=71") + step(5, "leave-alone")
    judge("and from then on it is counted once, like any other", start + step(1, "look") + rounds + again, other + step(1, "look") + wieder, ("IN FRONT", 4, "two"))
    judge("a round excuses what it left, not what was there before it", start + step(1, "look", "2500 Z 2,1") + step(2, "input-last", "2400 B down 10 10", end="act=instrument round=last front=2") + again, other + step(1, "look") + wieder,
          ("IN FRONT", 1, "two"))
    judge("nor another app that was in front before it", start + ["1000 A 10 app.one"] + step(1, "look", "2500 A 20 app.two") + step(2, "input-last", "2400 B down 10 10", end="act=instrument round=last front=1")
          + step(3, "click-one", "2500 A 10 app.one", end="act=switch front=1") + step(4, "leave-alone", "2500 A 20 app.two"),
          other + ["5000 A 10 app.one"] + step(1, "look") + step(2, "click-one", end="act=switch front=71") + step(3, "leave-alone"), ("IN FRONT", 1, "one"))
    judge("a round after the scene, which is no round, is excused as any", start + step(1, "look-around", end="act=idle setup=1") + step(2, "input-started", "2400 B down 10 10", "2500 Z 2,1", end="act=instrument round=started front=2"),
          other + step(1, "look-around", end="act=idle setup=1"))
    judge("what the scene left is nobody's doing for good", start + step(1, "look") + step(2, "close-welcome", "2500 Z 2,1", end="act=open-close setup=1") + step(3, "click-one", "2500 Z 1,2", end="act=switch front=1")
          + step(4, "leave-alone", "2500 Z 2,1"), other + step(1, "look") + step(2, "click-one", end="act=switch front=71") + step(3, "leave-alone"))
    judge("of two windows that are not both to be seen nobody can say that they agree", start + ["1000 W 3 30 0 100 400 400 300 Three", "1000 Z 1,2,3", "1000 M label 3 three"] + step(1, "look")
          + step(2, "input-last", "2400 B down 10 10", "2500 Z 3,2,1", end="act=instrument round=last front=3") + step(3, "full-screen", "2500 G 1", "2500 G 2", "2500 Z 3", end="act=macos-own leaves=any")
          + step(4, "leave-full-screen", "2500 W 1 10 0 0 0 400 300 One", "2500 W 2 20 0 500 0 400 300 Two", "2500 Z 3,2,1", end="act=macos-own leaves=any comes=3 front=3"),
          other + ["5000 W 73 30 0 100 400 400 300 Three", "5000 Z 71,72,73", "5000 M label 73 three"] + step(1, "look") + step(2, "full-screen", "2500 G 71", "2500 G 72", "2500 Z 73", end="act=macos-own leaves=any")
          + step(3, "leave-full-screen", "2500 W 71 10 0 0 0 400 300 One", "2500 W 72 20 0 500 0 400 300 Two", "2500 Z 73,71,72", end="act=macos-own leaves=any comes=73 front=73"))
    judge("nor of two of which one is away", start + step(1, "look") + rounds + step(3, "hide-one", "2500 G 1", "2500 Z 2", end="act=open-close leaves=1")
          + step(4, "show-one", "2500 W 1 10 0 0 0 400 300 One", "2500 Z 2,1", end="act=open-close comes=1"),
          other + step(1, "look") + step(2, "hide-one", "2500 G 71", "2500 Z 72", end="act=open-close leaves=71") + step(3, "show-one", "2500 W 71 10 0 0 0 400 300 One", "2500 Z 71,72", end="act=open-close comes=71"))
    judge("whichever of the two", start + step(1, "look") + rounds + step(3, "hide-two", "2500 G 2", "2500 Z 1", end="act=open-close leaves=2")
          + step(4, "show-two", "2500 W 2 20 0 500 0 400 300 Two", "2500 Z 2,1", end="act=open-close comes=2"),
          other + step(1, "look") + step(2, "hide-two", "2500 G 72", "2500 Z 71", end="act=open-close leaves=72") + step(3, "show-two", "2500 W 72 20 0 500 0 400 300 Two", "2500 Z 71,72", end="act=open-close comes=72"))
    judge("nor another app in front over the same pile", start + ["1000 A 10 app.one"] + step(1, "look") + step(2, "input-last", "2400 B down 10 10", "2500 A 20 app.two", end="act=instrument round=last front=1")
          + step(3, "look-again") + step(4, "click-one", "2500 A 10 app.one", end="act=switch front=1") + step(5, "leave-alone", "2500 A 20 app.two"),
          other + ["5000 A 10 app.one"] + step(1, "look") + step(2, "look-again") + step(3, "click-one", end="act=switch front=71") + step(4, "leave-alone"), ("IN FRONT", 5, "one"))
    judge("nor a pair below the front", start + ["1000 W 3 30 0 100 400 400 300 Three", "1000 Z 1,2,3", "1000 M label 3 three"] + step(1, "look")
          + step(2, "input-last", "2400 B down 10 10", "2500 Z 1,3,2", end="act=instrument round=last front=1") + step(3, "click", "2500 Z 1,2,3", end="act=switch front=1") + step(4, "leave-alone", "2500 Z 1,3,2"),
          other + ["5000 W 73 30 0 100 400 400 300 Three", "5000 Z 71,72,73", "5000 M label 73 three"] + step(1, "look") + step(2, "click", end="act=switch front=71") + step(3, "leave-alone"),
          ("IN FRONT", 4, "three"))

    docks = step(2, "dock-left", "2500 W 1 10 0 0 0 500 800 One", end="act=dock-key moves=,1, front=1")
    plain = other + step(1, "look") + step(2, "look-again")
    judge("what was asked of Arbor is not unasked, then or later", start + step(1, "look") + docks + step(3, "look-again"), plain)
    judge("what moves beside it is, at that act", start + step(1, "look") + step(2, "dock-left", "2500 W 1 10 0 0 0 500 800 One", "2500 W 2 20 0 500 0 500 300 Two", end="act=dock-key moves=,1, front=1")
          + step(3, "look-again"), plain, ("UNASKED", 2, "two"))
    judge("unless the act says that it may move it: the window docked before makes room", start + step(1, "look") + docks
          + step(3, "dock-right", "2500 W 1 10 0 0 0 250 800 One", "2500 W 2 20 0 250 0 250 800 Two", end="act=dock-key moves=1,2, front=2") + step(4, "look-again"), plain)
    judge("or that it may move any", start + step(1, "look") + step(2, "arrange", "2500 W 1 10 0 0 0 500 800 One", "2500 W 2 20 0 500 0 500 800 Two", end="act=view moves=any") + step(3, "look-again"), plain)
    for kind in ("dock-key", "resize", "tile-click", "view", "way-out"):
        judge(f"{kind} is asked of Arbor", start + step(1, "look") + step(2, "asks", "2500 W 1 10 0 0 0 500 800 One", end=f"act={kind} front=1") + step(3, "look-again"), plain)
    for kind in ("", "display-change", "switch", "open-close", "drag-where-macos-tiles", "macos-own", "idle", "bogus"):
        judge(f"`{kind}` is not: any Mac has it", start + step(1, "look") + step(2, "acts", end=f"act={kind} front=1" if kind else "front=1") + step(3, "look-again"), plain, ("IN FRONT", 2, None))
    judge("another window in front after what was asked", start + step(1, "look") + step(2, "dock-left", "2500 W 1 10 0 0 0 500 800 One", "2500 Z 2,1", end="act=dock-key moves=,1, front=1") + step(3, "look-again"),
          plain, ("IN FRONT", 2, "two"))
    judge("and a docked window that moves again when nobody touched it", start + step(1, "look") + docks + step(3, "click-two", "2500 W 1 10 0 -490 0 500 800 One", "2500 Z 2,1", end="act=switch front=2"),
          other + step(1, "look") + step(2, "click-two", "2500 Z 72,71", end="act=switch front=72"), ("UNASKED", 3, "one"))
    judge("asked to dock it, Arbor sends it out of view", start + step(1, "look") + step(2, "dock-left", "2500 W 1 10 0 -5000 0 400 300 One", end="act=dock-key moves=,1, front=1") + step(3, "look-again"), plain,
          ("REVERSED", 2, "one"))
    judge("or loses it", start + step(1, "look") + step(2, "dock-left", "2500 G 1", "2500 Z 2", end="act=dock-key moves=,1, front=1") + step(3, "look-again"), plain, ("REVERSED", 2, "one"), ("IN FRONT", 2, "two"))
    judge("the person may take it there", start + step(1, "look") + docks + step(3, "double-click", "2500 W 1 10 0 0 0 1000 800 One", end="act=macos-own zooms=1 front=1"),
          other + step(1, "look") + step(2, "double-click", "2500 W 71 10 0 0 0 1000 800 One", end="act=macos-own zooms=71 front=71"))
    home, heim = "2500 W 1 10 0 0 0 400 300 One", "2500 W 71 10 0 0 0 400 300 One"
    for what, mine, theirs in (
            ("drags it to where it is without Arbor", step(3, "drag", "2500 W 1 10 0 90 40 400 300 One", end="act=drag drags=1 front=1"), step(2, "drag", "2500 W 71 10 0 90 40 400 300 One", end="act=drag drags=71 front=71")),
            ("zooms it", step(3, "double-click", "2500 W 1 10 0 0 0 1000 800 One", end="act=macos-own zooms=1 front=1"), step(2, "double-click", "2500 W 71 10 0 0 0 1000 800 One", end="act=macos-own zooms=71 front=71")),
            ("has Arbor let it float", step(3, "float", home, end="act=dock-key restores=1 moves=,1, front=1"), []),
            ("has Arbor let all float", step(3, "float-all", home, end="act=way-out moves=any"), [])):
        judge(f"the person {what}: from then on it is no window of Arbor's", start + step(1, "look") + docks + mine + step(4, "leave-alone") + step(5, "look-again"),
              other + step(1, "look") + theirs + step(3, "leave-alone") + step(4, "look-again"))
    judge("nor is one whose app was quit and opened again", start + step(1, "look") + docks + step(3, "quit-one", "2500 G 1", "2500 Z 2", end="act=open-close leaves=1")
          + step(4, "reopen-one", "2500 W 9 11 0 0 0 400 300 One", "2500 M label 9 one", "2500 Z 9,2", end="act=open-close comes=9 front=9") + step(5, "leave-alone"),
          other + step(1, "look") + step(2, "quit-one", "2500 G 71", "2500 Z 72", end="act=open-close leaves=71")
          + step(3, "reopen-one", "2500 W 79 11 0 0 0 400 300 One", "2500 M label 79 one", "2500 Z 79,72", end="act=open-close comes=79 front=79") + step(4, "leave-alone"))
    judge("full screen says on the way out whose it was, whatever lay between", start + step(1, "full-screen", end="act=macos-own leaves=any") + step(2, "leave-alone")
          + step(3, "leave-full-screen", end="act=macos-own leaves=any comes=1 front=1"),
          other + step(1, "full-screen", "2500 W 71 10 0 0 0 1000 800 One", "2500 G 72", "2500 Z 71", end="act=macos-own leaves=any") + step(2, "leave-alone")
          + step(3, "leave-full-screen", heim, "2500 W 72 20 0 500 0 400 300 Two", "2500 Z 71,72", end="act=macos-own leaves=any comes=71 front=71"), ("REVERSED", 1, "one"))
    undone = step(1, "full-screen", end="act=macos-own leaves=any") + step(2, "leave-full-screen", end="act=macos-own leaves=any comes=1 front=1")
    done = step(1, "full-screen", "2500 W 71 10 0 0 0 1000 800 One", "2500 G 72", "2500 Z 71", end="act=macos-own leaves=any") + step(
        2, "leave-full-screen", heim, "2500 W 72 20 0 500 0 400 300 Two", "2500 Z 71,72", end="act=macos-own leaves=any comes=71 front=71")
    judge("what stayed because a full screen was undone is forgotten once both show it again: that it stays another time is another thing",
          start + undone + step(3, "hide-two", end="act=open-close leaves=2"), other + done + step(3, "hide-two", "2500 G 72", "2500 Z 71", end="act=open-close leaves=72"), ("REVERSED", 1, "one"), ("REVERSED", 3, "two"))
    judge("be it unnamed", start + undone + step(3, "look"), other + done + step(3, "look", "2500 G 72", "2500 Z 71"), ("REVERSED", 1, "one"), ("UNASKED", 3, "two"))
    judge("a docked window fills the screen as it does without Arbor, and goes back to its place: nothing new", start + step(1, "look") + docks
          + step(3, "full-screen", "2500 W 1 10 0 0 0 1000 800 One", "2500 G 2", "2500 Z 1", end="act=macos-own leaves=any")
          + step(4, "leave-full-screen", "2500 W 1 10 0 0 0 500 800 One", "2500 W 2 20 0 500 0 400 300 Two", "2500 Z 1,2", end="act=macos-own leaves=any comes=1 front=1")
          + step(5, "double-click", "2500 W 1 10 0 0 0 1000 800 One", end="act=macos-own zooms=1 front=1") + step(6, "double-click-again", "2500 W 1 10 0 0 0 500 800 One", end="act=macos-own zooms=1 front=1"),
          other + step(1, "look") + step(2, "full-screen", "2500 W 71 10 0 0 0 1000 800 One", "2500 G 72", "2500 Z 71", end="act=macos-own leaves=any")
          + step(3, "leave-full-screen", heim, "2500 W 72 20 0 500 0 400 300 Two", "2500 Z 71,72", end="act=macos-own leaves=any comes=71 front=71")
          + step(4, "double-click", "2500 W 71 10 0 0 0 1000 800 One", end="act=macos-own zooms=71 front=71") + step(5, "double-click-again", heim, end="act=macos-own zooms=71 front=71"))
    judge("what an act any Mac has may move by its own word is unasked all the same: nobody touched it", start + step(1, "look") + docks
          + step(3, "hide-two", "2500 G 2", "2500 Z 1", "2500 W 1 10 0 0 0 1000 800 One", end="act=open-close leaves=2 moves=1,"), other + step(1, "look") + step(2, "hide-two", "2500 G 72", "2500 Z 71", end="act=open-close leaves=72"),
          ("UNASKED", 3, "one"))
    judge("what is asked may bring a window that the control has not on its screen", start + step(1, "hide-one", "2500 G 1", "2500 Z 2", end="act=open-close leaves=1")
          + step(2, "view-all", "2500 W 1 10 0 0 0 400 300 One", "2500 Z 2,1", end="act=view moves=1,") + step(3, "look"), other + step(1, "hide-one", "2500 G 71", "2500 Z 72", end="act=open-close leaves=71") + step(2, "look"))

    def screens(one, two, base, undone=False):
        full = lambda number, window, owner, back, stays: step(  # noqa: E731
            number, "full-screen", *([] if stays else [f"2500 W {window} {owner} 0 0 0 1000 800 X", f"2500 G {two if window == one else one}", f"2500 Z {window}"]), end="act=macos-own leaves=any") + step(
            number + 1, "leave-full-screen", f"2500 W {one} 10 0 0 0 400 300 One", f"2500 W {two} 20 0 500 0 400 300 Two", f"2500 Z {back}", end=f"act=macos-own leaves=any comes={window} front={window}")
        return base + full(1, one, 10, f"{two},{one}", False) + full(3, two, 20, f"{two},{one}", undone)

    judge("of two full screens each is its own window's", screens("1", "2", start, undone=True), screens("71", "72", other), ("REVERSED", 3, "two"))
    for kind in ("resize", "tile-click", "view", "way-out"):
        judge(f"{kind} may send a window out of view: that is what was asked", start + step(1, "look") + docks + step(3, "asks", "2500 W 1 10 0 999 790 500 800 One", end=f"act={kind} moves=1, front=2") + step(4, "look-again"), plain)
    judge("a control that names no display", start + step(1, "look") + docks + step(3, "look-again"), other[1:] + step(1, "look") + step(2, "look-again"))
    judge("a playing that names none: nobody can say what is out of view", start[1:] + step(1, "look") + docks + step(3, "look-again"), plain)
    judge("what Arbor moved unasked and left there is one thing, Quit or no Quit", start + step(1, "look") + docks + step(3, "look-again", "2500 W 1 10 0 -300 0 500 800 One") + step(4, "quit", end="act=quit-and-start"), plain,
          ("UNASKED", 3, "one"))
    judge("a start ends nothing of what was asked", start + step(1, "look") + docks + step(3, "launch", end="act=quit-and-start") + step(4, "look-again"), plain)
    judge("that the window asked about is elsewhere excuses no other that is off the screen", start + step(1, "look") + step(2, "dock-left", "2500 W 1 10 0 0 0 500 800 One", "2500 G 2", "2500 Z 1",
          end="act=dock-key moves=,1, front=1 leaves=any") + step(3, "look-again"), plain, ("UNASKED", 2, "two"))
    judge("Quit gives it back", start + step(1, "look") + docks + step(3, "look-again") + step(4, "quit", "2500 W 1 10 0 0 0 400 300 One", end="act=quit-and-start"), plain)
    costs = judge("what was asked and could not be done is listed, and what it leaves behind is nobody's doing",
                  start + step(1, "look") + step(2, "dock-left", "2500 W 2 20 0 600 0 400 300 Two", end="act=dock-key judge=no performed=no moves=,1, front=1") + step(3, "look-again"), plain)
    if costs["not_performed"] != [{"act": 2, "slug": "dock-left", "playing": "with"}]:
        failures.append(f"what was asked and could not be done is listed: {costs['not_performed']}")
    first = step(1, "dock-left", "2500 W 1 10 0 0 0 500 800 One", "2500 W 2 20 0 500 0 500 300 Two", end="act=dock-key moves=,1, front=1")
    judge("before the control's first act there is nothing to hold Arbor against: what differs from the end of that act is remembered", start + first + step(2, "click-one", end="act=switch front=1") + step(3, "look"),
          other + step(1, "click-one", end="act=switch front=71") + step(2, "look", "2500 W 72 20 0 500 0 500 300 Two"))
    judge("an act that any Mac has and the control has not is said, first of all or not", start + step(1, "drag", end="act=drag") + step(2, "look"), other + step(1, "look"), ("IN FRONT", 1, None))
    judge("nor is what the control's first act does the doing of a start before it", start + step(1, "launch", end="act=quit-and-start") + step(2, "click-two", "2500 Z 2,1", end="act=switch front=2"),
          other + step(1, "click-two", "2500 Z 72,71", end="act=switch front=72"))
    judge("what is asked later, against the control as it stands by then", start + step(1, "look") + step(2, "drag", "2500 W 2 20 0 600 0 400 300 Two", end="act=drag drags=2")
          + step(3, "dock-left", "2500 W 1 10 0 0 0 500 800 One", end="act=dock-key moves=,1, front=1") + step(4, "look-again"),
          other + step(1, "look") + step(2, "drag", "2500 W 72 20 0 600 0 400 300 Two", end="act=drag drags=72") + step(3, "look-again"))
    judge("a round of input forgets nothing of what was asked", start + step(1, "look") + docks + step(3, "input-last", "2400 B down 10 10", end="act=instrument round=last front=1") + step(4, "look-again"), plain)
    judge("what is asked while the scene is set is the scene's", start + step(1, "look") + step(2, "dock-left", "2500 W 1 10 0 0 0 500 800 One", "2500 W 2 20 0 500 0 500 300 Two", end="act=dock-key setup=1 moves=,1, front=1")
          + step(3, "click-one", end="act=switch front=1"), other + step(1, "look") + step(2, "click-one", end="act=switch front=71"))
    asks = start + step(1, "look", "2100 K 1") + step(2, "dock-left", "2100 K 3", "2200 B down 1 1", "2200 B up 1 1", "2500 W 1 10 0 0 0 500 800 One", "2500 W 2 20 0 500 0 500 300 Two", end="act=dock-key moves=,1, front=1")
    costs = judge("what was asked of Arbor is in none of the costs", asks + step(3, "look-again"), other + step(1, "look", "2100 K 1") + step(2, "look-again"), ("UNASKED", 2, "two"))
    like = {"acts": 2, "keys": 1, "presses": 0, "seconds": 0.1, "waiting": 0.0}
    if costs["with"] != {**like, "asked": 1} or costs["without"] != {**like, "asked": 0}:
        failures.append(f"what was asked of Arbor is in none of the costs: {costs}")
    said = "\n".join(verdict(*judged(playing(asks + step(3, "look-again")), playing(other + step(1, "look", "2100 K 1") + step(2, "look-again"))), False))
    for sentence in ("; and 1 acts asked of Arbor, which are in none of these", "SOMETHING NEW DIFFERS AT 1 OF 3 ACTS (1 things)"):
        if sentence not in said:
            failures.append(f"what was asked of Arbor is counted apart: nothing says `{sentence}`\n{said}")
    judge("what the start moves is unasked at the start, not a reversal of the first act", start + step(1, "look-around", end="act=idle setup=1")
          + step(2, "launch", "2500 W 1 10 0 50 60 400 300 One", end="act=quit-and-start") + step(3, "click-one", end="act=switch front=1"),
          other + step(1, "look-around", end="act=idle setup=1") + step(2, "click-one", end="act=switch front=71"), ("UNASKED", 2, "one"))
    judge("a full screen that is undone is one reversal, and the windows that stayed are no more",
          start + step(1, "full-screen", end="act=macos-own leaves=any") + step(2, "leave-full-screen", end="act=macos-own leaves=any comes=1 front=1"),
          other + step(1, "full-screen", "2500 W 71 10 0 0 0 1000 800 One", "2500 G 72", "2500 Z 71", end="act=macos-own leaves=any")
          + step(2, "leave-full-screen", "2500 W 71 10 0 0 0 400 300 One", "2500 W 72 20 0 500 0 400 300 Two", "2500 Z 71,72", end="act=macos-own leaves=any comes=71 front=71"),
          ("REVERSED", 1, "one"))
    third, dritte = ["1000 W 3 30 0 100 400 400 300 Three", "1000 Z 1,2,3", "1000 M label 3 three"], ["5000 W 73 30 0 100 400 400 300 Three", "5000 Z 71,72,73", "5000 M label 73 three"]
    judge("two windows the other way round below the one in front", start + third + step(1, "click", "2500 Z 1,3,2", end="act=switch front=1"), other + dritte + step(1, "click", end="act=switch front=71"),
          ("IN FRONT", 1, "three"))
    judge("another app in front, with the pile as it was", start + ["1000 A 10 app.one"] + step(1, "look", "2500 A 99 app.arbor"), other + ["5000 A 10 app.one"] + step(1, "look"), ("IN FRONT", 1, "one"))
    new = lambda base, extra=(): step(1, "new", f"2100 W {base}8 10 0 10 10 50 50 One", f"2100 M label {base}8 one-new-1") + step(  # noqa: E731
        2, "new", f"2100 W {base}9 10 0 20 20 50 50 One", f"2100 M label {base}9 one-new-2", *extra)
    judge("of two new windows of one app the older is looked at too", start + new("", ["2500 W 8 10 0 700 500 50 50 One"]), other + new("7"), ("UNASKED", 2, "one-new.1"))
    for what, first, second, fits in (("Arbor in the first alone", True, False, True), ("two controls", False, False, False), ("Arbor in both", True, True, False), ("the wrong way round", False, True, False)):
        pair = [playing((["1000 M arbor 99"] if arbor else []) + start + step(1, "look")) for arbor in (first, second)]
        if (unfit(*pair) is None) != fits:
            failures.append(f"{what}: {unfit(*pair)}")
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
    if len(arguments) != 2 or report_to and not pair:
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
        if unfit(*both):
            print(f"walk-diff.py: {unfit(*both)}", file=sys.stderr)
            return 2
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
