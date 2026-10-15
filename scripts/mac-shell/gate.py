#!/usr/bin/env python3
"""The plan of a gate: which journeys a commit has to be taken on before `viable.py` can call it VIABLE.

  gate.py plan [first|rest|whole]          the rows, one playing of gate.sh each, as a table
  gate.py row <commit> <part> <parts>      what gate.sh plays as part <part> of <parts>: `name=value` lines for the shell
  gate.py acts <seed> <display> <acts> <cast>   the acts of a walk, one word a line (walk.py's)
  gate.py --self-test

The numbers are not here. They are in the first block of JSON in docs/VIABLE.md, and the plan is worked out from them: every cell (macOS's tiling, the
displays) gets the same four journeys, the casts and Reduce Motion are spread over them, each cell has a control, and a gate has its sabotage run and
its sits. The self-test holds the plan to the page, so a number that is raised there fails here until the plan has grown.

A commit is first given two user-hours, one at each setting of macOS's tiling (`first`), and the others only if those are clean (`rest`). gate.sh is
told nothing but which part of how many it is, so **how many parts a dispatch has says which of the three it is**; no two of them are as long.

A walk is seeded from the commit and the row's name (and a number that only they decide: `salt_of`), not from its place in a dispatch: the same row is the same journey in `whole` and in `rest`, and
its control walks the same way.
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import walk  # noqa: E402

# What a walk is asked for. The beginning and the end add seventeen (Arbor is started, its welcome left open for half a minute and closed, everything is brought into view, it is quit,
# every app is called up once more).
ACTS = 100
JOURNEYS_PER_CELL = 5
# Measured on hosted Macs, over five journeys: the scene takes 62 s to set and the two desks a few more, an act 2.1 s and 0.6 s until the next, one in which nobody does anything 31 s.
# Four rounds of input, which are no acts, take some 13 s each: reckoned, not measured, since one program posts a round (a program for each press took 31 s).
SCENE, ACT, IDLE = 65 + 4 * 13, 2.7, 31
# Of the acts a walk is written with, this share is played and judged, at the least. Measured: 101 of 116 applied when their turn came, and 96 % of those were
# judged (the sampler is blind at times): 0.84.
# **One share for every kind of act, which is wrong, and known to be.** Written and judged over two walks: drags 23 and 1, what is macOS's own 10 and 0, clicks on a tile 2 and 0, drags
# where macOS tiles 9 and 4, resizes 15 and 6, opening and closing 30 and 17; views 49 and 43, docks by key 23 and 19. So this plan meets the page's numbers in what is written, not in what
# is played: a gate by it would end short of acts (it could not pass falsely: viable.py counts what was judged). Not to be dispatched whole until the words reach what they need by
# themselves and this is reckoned by kind.
COUNTED = 0.8


def numbers():
    with open(os.path.join(HERE, "..", "..", "docs", "VIABLE.md"), encoding="utf-8") as handle:
        return json.loads(re.search(r"```json\n(.*?)```", handle.read(), flags=re.S).group(1))


def rows(gate):
    """Every row of a whole gate: dictionaries with name, kind, script, cast, display, tiling, motion. The two of `first` come first."""
    casts = gate["cast"]
    journeys, controls = [], []
    for tiling in gate["tiling"]:
        for display in gate["display"]:
            for place in range(JOURNEYS_PER_CELL):
                row = {"name": f"{tiling}.{display}.{place + 1}", "kind": "walk", "script": "gate.sh", "cast": casts[0], "display": display, "tiling": tiling, "motion": "moving"}
                if place == 0:
                    # The one that has a control, and in two cells of each tiling the one with no stage to forgive anything.
                    row["motion"] = "still" if display != gate["display"][0] else "moving"
                    controls.append(dict(row, name=row["name"] + ".control", kind="control"))
                elif place == 1 and display != "two":
                    # The written day has no second display to plug in.
                    row.update(kind="day", script="day.sh")
                elif place >= 2:
                    row["cast"] = casts[(place - 1) % len(casts)]
                journeys.append(row)
    first = [next(row for row in journeys if row["tiling"] == tiling and row["kind"] == "walk" and row["motion"] == "moving") for tiling in gate["tiling"]]
    others = {"cast": casts[0], "display": gate["display"][0], "tiling": gate["tiling"][0], "motion": "moving"}
    extra = [dict(others, name=f"sabotage.{n + 1}", kind="sabotage", script="day-sabotage.sh") for n in range(gate["controls"]["sabotage_runs_min"])]
    extra += [dict(others, name=f"sit.{n + 1}", kind="sit", script="day-sit.sh", tiling=tiling) for n, tiling in enumerate(gate["tiling"])]
    return first + [row for row in journeys if row not in first] + controls + extra


def dispatch(gate, which):
    whole = rows(gate)
    few = len(gate["tiling"])
    return {"first": whole[:few], "rest": whole[few:], "whole": whole}[which]


def seed_of(commit, row, salt):
    name = row["name"][:-len(".control")] if row["kind"] == "control" else row["name"]
    return f"{commit[:12]}.{name}.{salt}"


def asked(display):
    """What is done to the second display comes on top of what a walk is asked for, and each such act is followed by a look at everything."""
    return ACTS - 24 if display == "two" else ACTS


def acts_of(seed, display, acts=None, cast="stock"):
    return walk.walk(seed, acts or asked(display), display == "two", cast)


# The kind of act each word counts as (lib-walk.sh). A name that ends in _ stands for every word that begins so.
KINDS = {"switch": "switch_ focus_key", "tile-click": "tile_click", "open-close": "open_new close_new minimize restore hide unhide quit_app reopen",
         "dock-key": "dock_key float_key arrange_key undo redo rotate mirror pin send_across", "drag": "drag_onto drag_out drag_by carry_across", "drag-where-macos-tiles": "drag_edge",
         "view": "view peek save_view view_n", "resize": "resize_", "macos-own": "full_screen wallpaper_click title_double_click",
         "way-out": "pause resume float_all float_all_here hold_view", "display-change": "display", "idle": "idle_act"}
# Every app of the cast is called up once, to see that it still comes. The smallest cast has this many.
ROLL_CALL = ["switch"] * min(len(cast["apps"]) for cast in walk.CASTS.values())
# Words that are several acts, and what every journey begins and ends with: Arbor is started, its welcome left open for half a minute and closed; everything is brought into view, and it is quit.
SEVERAL = {"quit_and_start": ["quit-and-start"] + ROLL_CALL[::3] + ["quit-and-start", "open-close"], "wallpaper_click": ["macos-own"] * 2,
           "title_double_click": ["macos-own"] * 2, "hold_view": ["way-out", "view", "way-out"], "display": ["display-change", "view"]}
AROUND = ["quit-and-start", "idle", "open-close", "view", "quit-and-start"] + ROLL_CALL


def kinds_of(line):
    """The kinds of the acts a line of a walk is played as, if it applies when its turn comes."""
    word = line.split()[0]
    if word in SEVERAL:
        return SEVERAL[word]
    return [kind for kind, words in KINDS.items() for known in words.split() if word == known or known.endswith("_") and word.startswith(known)][:1] or [None]


def written(commit, row, salt):
    return AROUND + [kind for line in acts_of(seed_of(commit, row, salt), row["display"], cast=row["cast"]) for kind in kinds_of(line)]


def short_of(gate, commit, salt):
    """What the journeys of a whole gate, as they are written, have too little of: (what, has, wanted). A day is about as long as a walk and of the same
    mixture, and is counted as the walk in its place would be."""
    journeys = [row for row in rows(gate) if row["kind"] in ("walk", "day")]
    acts = {row["name"]: written(commit, row, salt) for row in journeys}

    def counted(chosen, kinds=None):
        return COUNTED * sum(kinds is None or kind in kinds for row in chosen for kind in acts[row["name"]])

    hour = gate["acts_per_user_hour"]
    wanted = [("user-hours", counted(journeys) / hour, gate["user_hours"])]
    for tiling in gate["tiling"]:
        for display in gate["display"]:
            wanted.append((f"user-hours at {tiling}, {display}", counted([row for row in journeys if (row["tiling"], row["display"]) == (tiling, display)]) / hour,
                           gate["user_hours_per_cell_min"]))
        wanted.append((f"acts that move windows with Reduce Motion on at {tiling}", counted(
            [row for row in journeys if row["tiling"] == tiling and row["motion"] == "still"], gate["reduce_motion"]["kinds_that_move"]),
            gate["reduce_motion"]["acts_that_move_per_tiling_min"]))
    for cast in gate["cast"]:
        wanted.append((f"user-hours with the cast {cast}", counted([row for row in journeys if row["cast"] == cast]) / hour, gate["user_hours_per_cast_min"]))
    for kind, least in gate["acts_min"].items():
        # The page counts a drag where macOS tiles as a drag too.
        wanted.append((f"acts of the kind {kind}", counted(journeys, [kind, "drag-where-macos-tiles"] if kind == "drag" else [kind]), least))
    for row in journeys:
        idle = acts[row["name"]].count("idle")
        # A tenth to spare: a run that takes too long does not count, and its Mac was spent for nothing.
        wanted.append((f"seconds to spare in {row['name']}", 0.9 * gate["run_seconds_max"] - (SCENE + ACT * (len(acts[row["name"]]) - idle) + IDLE * idle), 0))
    return [(what, has, least) for what, has, least in wanted if has < least]


SALTS = 40


def salt_of(gate, commit):
    """Dice fall as they fall, and a gate that turns out two resizes short has cost five hours of Macs for nothing. So the walks of a commit are seeded with the
    commit and the first number with which they have enough of everything **as they are written**. Nothing that a run brought back has a say in it."""
    return next((salt for salt in range(SALTS) if not short_of(gate, commit, salt)), None)


def self_test():
    gate, failures = numbers(), []
    whole = rows(gate)
    journeys = [row for row in whole if row["kind"] in ("walk", "day")]

    def want(what, has, at_least):
        if has < at_least:
            failures.append(f"{what}: the plan has {has:.1f}, docs/VIABLE.md wants {at_least:.1f}")

    tries = []
    for n in range(24):
        commit = f"{n * 0x9e3779b97f4a7c15 % 2**64:016x}" * 3
        commit = commit[:40]
        salt = salt_of(gate, commit)
        if salt is None:
            failures.append(f"commit {commit[:12]}: none of {SALTS} ways to seed its walks has enough of everything; the first lacks " + "; ".join(
                f"{what} ({has:.0f} of {least})" for what, has, least in short_of(gate, commit, 0)))
        else:
            tries.append(salt)
    # If it takes long to find one, the mixture is wrong, and the dice are made to mend it.
    if tries and sum(tries) / len(tries) > 3:
        failures.append(f"it takes {sum(tries) / len(tries):.1f} tries on average to seed a commit's walks: walk.py's mixture is short of something")
    for tiling in gate["tiling"]:
        for display in gate["display"]:
            want(f"controls at {tiling}, {display}", len([row for row in whole if (row["tiling"], row["display"], row["kind"]) == (tiling, display, "control")]),
                 gate["controls"]["without_arbor_per_cell_min"])
    if set(gate["cast"]) != set(walk.CASTS):
        failures.append(f"docs/VIABLE.md has the casts {gate['cast']}, walk.py {sorted(walk.CASTS)}")
    if any(None in written("0" * 40, row, 0) for row in journeys):
        failures.append("a word of walk.py's has no kind here")
    want("the share of acts from walks", len([row for row in journeys if row["kind"] == "walk"]) / len(journeys), gate["share_of_acts_from_walks_min"])
    want("the share of acts with motion", 1 - len([row for row in journeys if row["motion"] == "still"]) / len(journeys), 1 - gate["reduce_motion"]["share_of_acts_max"])
    want("sabotage runs", len([row for row in whole if row["kind"] == "sabotage"]), gate["controls"]["sabotage_runs_min"])
    for row in whole:
        if row["kind"] == "control" and not any(seed_of("c" * 40, row, 0) == seed_of("c" * 40, other, 0) and other["kind"] == "walk" and all(
                row[key] == other[key] for key in ("script", "cast", "display", "tiling", "motion")) for other in whole):
            failures.append(f"{row['name']} is the control of no walk")
    lengths = [len(dispatch(gate, which)) for which in ("first", "rest", "whole")]
    if len(set(lengths)) != 3:
        failures.append(f"two dispatches are as long as each other, and gate.sh could not tell them apart: {lengths}")
    if max(lengths) > 64:
        failures.append(f"{max(lengths)} parts: viable.py takes 64 for a slip")
    if len({row["name"] for row in whole}) != len(whole):
        failures.append("two rows have one name")
    if dispatch(gate, "first") + dispatch(gate, "rest") != whole:
        failures.append("first and rest are not the whole")
    if {row["tiling"] for row in dispatch(gate, "first")} != set(gate["tiling"]):
        failures.append("the first user-hours are not one at each setting of macOS's tiling")
    if seed_of("a" * 40, whole[0], 0) == seed_of("b" * 40, whole[0], 0):
        failures.append("two commits are walked the same way")
    for failure in failures:
        print(f"✘ {failure}")
    print("gate.py: " + (f"the plan of {len(whole)} parts meets the page's numbers" if not failures else f"{len(failures)} failed"))
    return 1 if failures else 0


def main(arguments):
    if arguments == ["--self-test"]:
        return self_test()
    gate = numbers()
    if arguments[:1] == ["plan"] and len(arguments) <= 2 and (arguments[1:] or ["whole"])[0] in ("first", "rest", "whole"):
        chosen = dispatch(gate, (arguments[1:] or ["whole"])[0])
        for part, row in enumerate(chosen, 1):
            print(f"{part:>2} of {len(chosen)}  {row['name']:<28} {row['kind']:<9} {row['script']:<16} {row['cast']:<9} {row['display']:<7} {row['tiling']:<9} {row['motion']}")
        return 0
    if arguments[:1] == ["row"] and len(arguments) == 4 and re.fullmatch(r"[0-9a-f]{40}", arguments[1]) and arguments[2].isdigit() and arguments[3].isdigit():
        commit, part, parts = arguments[1], int(arguments[2]), int(arguments[3])
        chosen = next((dispatch(gate, which) for which in ("first", "rest", "whole") if len(dispatch(gate, which)) == parts), None)
        if chosen is None or not 1 <= part <= parts:
            print(f"gate.py: part {part} of {parts} is of no dispatch of a gate's: " + ", ".join(
                f"{which} has {len(dispatch(gate, which))}" for which in ("first", "rest", "whole")), file=sys.stderr)
            return 64
        row = chosen[part - 1]
        for key in ("name", "kind", "script", "cast", "display", "tiling", "motion"):
            print(f"{key}={row[key]}")
        salt = salt_of(gate, commit)
        if salt is None:
            print(f"gate.py: no way to seed the walks of {commit[:12]} has enough of everything (--self-test says more)", file=sys.stderr)
            return 70
        print(f"seed={seed_of(commit, row, salt) if row['script'] == 'gate.sh' else ''}")
        print(f"acts={asked(row['display'])}")
        return 0
    if arguments[:1] == ["acts"] and len(arguments) == 5 and arguments[3].isdigit() and arguments[4] in walk.CASTS:
        print("\n".join(acts_of(arguments[1], arguments[2], int(arguments[3]), arguments[4])))
        return 0
    print(__doc__)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
