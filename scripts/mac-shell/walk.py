#!/usr/bin/env python3
"""Writes a walk: a journey for a real Mac, made from a seed, in the words of lib-walk.sh.

  walk.py <seed> [--acts n] [--display laptop|desk|two] [--tiling defaults|off] [--reduce-motion on]   prints the script, to be saved as <seed>.sh
  walk.py <seed> --control                                   prints its control, which plays <seed>.sh beside it without Arbor
  walk.py --self-test

The same seed gives the same walk, on any machine and any version of Python. The kinds of act come in the proportions docs/VIABLE.md asks of the whole
gate ("The mixture"). The walk knows nothing of the state of the screen: lib-walk.sh leaves out an act that does not apply. It only keeps what belongs
together near each other (what is minimized is restored a few acts later, a pause is resumed, full screen is left), because a walk that hides every
app in its first minute has nothing left to walk through.

A plain random walk, until the generator of the Linux walks writes these words too.
"""

import sys

APPS = ["finder", "safari", "textedit", "terminal", "notes", "calendar", "settings", "preview", "mail"]
# docs/VIABLE.md, acts_min. A drag where macOS tiles counts within the drags there, and is a kind of its own here.
MIXTURE = [("switch", 480), ("open-close", 300), ("dock-key", 160), ("drag", 160), ("drag-where-macos-tiles", 80), ("view", 400),
           ("resize", 80), ("macos-own", 80), ("way-out", 60), ("idle", 40)]


class Dice:
    """A generator of its own (a linear congruential one, Knuth's constants): `random` makes no promise across versions."""

    def __init__(self, seed):
        self.state = 0
        for byte in str(seed).encode():
            self.state = (self.state * 257 + byte + 1) % 2**64
        for _ in range(8):
            self.roll(2)

    def roll(self, sides):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 33) % sides

    def pick(self, choices):
        return choices[self.roll(len(choices))]

    def weighted(self, pairs):
        at = self.roll(sum(weight for _, weight in pairs))
        for choice, weight in pairs:
            if at < weight:
                return choice
            at -= weight
        return pairs[-1][0]


def walk(seed, acts, two=False):
    """The lines of a walk of about that many acts. Some words are two acts (a click on the wallpaper and a second one), one is a dozen.
    `two`: with a second display that comes, goes, moves and changes size; the dice are rolled as without it, so the rest of the walk is the same."""
    dice = Dice(seed)
    changes = Dice(f"{seed} displays")
    lines, owed, count = [], [], 0
    restart_at = acts // 2

    def say(line, worth=1):
        nonlocal count
        lines.append(line)
        count += worth

    def later(line):
        owed.append([1 + dice.roll(4), line])

    restarted = False
    while count < acts:
        # Before anything else, and not counted: what is owed comes due, and Arbor is started again, when it would have without.
        if two and changes.roll(12) == 0:
            lines.append(changes.weighted([("display plug", 4), ("display unplug", 2), ("display left", 1), ("display right", 1), ("display smaller", 1),
                                           ("display larger", 1), ("send_across", 4)]))
            continue
        for debt in owed:
            debt[0] -= 1
        due = [debt for debt in owed if debt[0] <= 0]
        if due:
            owed.remove(due[0])
            say(due[0][1])
            continue
        if not restarted and count >= restart_at and not owed:
            restarted = True
            say("quit_and_start", 12)
            continue
        kind = dice.weighted(MIXTURE)
        app, other = dice.pick(APPS), dice.pick(APPS)
        if kind == "switch":
            say(dice.weighted([(f"switch_dock {app}", 4), (f"switch_click {app}", 4), (f"switch_cmdtab {1 + dice.roll(3)}", 3),
                               ("switch_backtick", 1), (f"tile_click {1 + dice.roll(2)}", 1), (f"focus_key {dice.pick(['left', 'right', 'up', 'down'])}", 2),
                               (f"switch_menu {dice.pick(['safari', 'finder', 'textedit', 'terminal'])}", 1)]))
        elif kind == "open-close":
            what = dice.roll(5)
            if what == 0:
                say(f"switch_dock {dice.pick(['safari', 'textedit', 'finder', 'terminal'])}")
                say("open_new")
                later("close_new")
            elif what == 1:
                say(f"switch_dock {app}")
                say("minimize")
                later(f"restore {app}")
            elif what == 2:
                say(f"switch_dock {app}")
                say("hide")
                later(f"unhide {app}")
            elif what == 3:
                quits = dice.pick(["textedit", "preview", "safari"])
                say(f"quit_app {quits}")
                later(f"reopen {quits}")
            else:
                say("close_new")
        elif kind == "dock-key":
            say(f"switch_to {app}")
            say(dice.weighted([(f"dock_key {dice.pick(['left', 'right', 'up', 'down'])}", 8), ("float_key", 2), ("arrange_key", 1), ("undo", 2), ("redo", 1),
                               ("rotate", 1), ("mirror", 1), ("pin", 1)]))
        elif kind == "drag":
            say(dice.weighted([(f"drag_onto {app} {other} {dice.pick(['left', 'right', 'top', 'bottom'])}", 3), (f"drag_out {app}", 2),
                               (f"drag_by {app} {dice.roll(401) - 200} {dice.roll(241) - 120}", 2)]))
        elif kind == "drag-where-macos-tiles":
            say(f"drag_edge {app} {dice.pick(['left', 'right', 'top'])}")
        elif kind == "view":
            say(dice.weighted([("view frame", 4), ("view all", 4), ("view out", 2), ("view in", 2), ("view left", 2), ("view right", 2), ("view back", 2),
                               ("view forward", 1), ("view desktop", 1), ("view home", 1), ("peek", 1), (f"save_view {1 + dice.roll(3)}", 1), (f"view_n {1 + dice.roll(3)}", 1)]))
        elif kind == "resize":
            say(dice.weighted([(f"resize_gap {app} {dice.pick([-80, -40, 40, 80])}", 2), (f"resize_key {dice.pick(['grow', 'shrink', 'balance'])}", 3),
                               (f"resize_edge {app} {dice.pick(['left', 'right', 'top', 'bottom'])} {dice.pick([-60, -30, 30, 60])}", 2)]))
        elif kind == "macos-own":
            what = dice.roll(3)
            if what == 0:
                say("wallpaper_click", 2)
            elif what == 1:
                say(f"title_double_click {app}", 2)
            else:
                say("switch_dock safari")
                say("full_screen on")
                say("full_screen off")
        elif kind == "way-out":
            what = dice.roll(5)
            if what < 2:
                say("pause")
                later("resume")
            elif what == 2:
                say("hold_view", 3)
            else:
                say(dice.pick(["float_all", "float_all", "float_all_here"]))
        else:
            say("idle_act")
    for _, line in owed:
        say(line)
    return lines


def script(seed, acts, display, tiling, control, still=False):
    head = [
        "#!/bin/bash",
        f"# A walk from the seed {seed}: scripts/mac-shell/walk.py {seed} --acts {acts} --display {display} --tiling {tiling}"
        + (" --reduce-motion on" if still else "") + (" --control" if control else ""),
        "# Written by a program. Change the program, not this file.",
    ]
    if control:
        # The same script, so that what it brings back is told to be the same journey: only Arbor is missing.
        return "\n".join(head + ["export WALK_WITHOUT_ARBOR=1", f'exec "$BASH" "$(dirname "${{BASH_SOURCE[0]}}")/{seed}.sh"']) + "\n"
    # With Reduce Motion on Arbor puts up no stage, and every move of every window shows.
    head += ["WALK_REDUCE_MOTION=on"] if still else []
    head += ['source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"', f"walk_begin stock {display} {tiling} {seed}"]
    return "\n".join(head + walk(seed, acts, display == "two") + ["walk_end"]) + "\n"


def self_test():
    failures = []
    if walk("4711", 110) != walk("4711", 110):
        failures.append("the same seed gives two walks")
    if walk("4711", 110) == walk("4712", 110):
        failures.append("two seeds give the same walk")
    # Pinned, so that a change of the generator, which changes what every seed means, does not go unnoticed.
    if walk("4711", 110)[:3] != PINNED:
        failures.append(f"the walk from 4711 begins {walk('4711', 110)[:3]}, not {PINNED}")
    for seed in range(200):
        lines = walk(seed, 110)
        for opens, closes in (("minimize", "restore"), ("hide", "unhide"), ("pause", "resume"), ("full_screen on", "full_screen off"), ("quit_app", "reopen")):
            if sum(line.startswith(opens) for line in lines) != sum(line.startswith(closes) for line in lines):
                failures.append(f"seed {seed}: as many of `{opens}` as of `{closes}`")
        if lines.count("quit_and_start") != 1:
            failures.append(f"seed {seed}: Arbor is quit and started once in every walk")
        between = [line for line in lines[lines.index("full_screen on") + 1:][:1]] if "full_screen on" in lines else ["full_screen off"]
        if between != ["full_screen off"]:
            failures.append(f"seed {seed}: full screen is left with the next act")
    plain = [line for line in walk("4711", 110, two=True) if line.split()[0] not in ("display", "send_across")]
    if plain[:60] != walk("4711", 110)[:60]:
        failures.append("with a second display the rest of the walk is another walk")
    moving, still = script("4711", 110, "laptop", "off", False).split("\n"), script("4711", 110, "laptop", "off", False, still=True).split("\n")
    if [line for line in still[2:] if line != "WALK_REDUCE_MOTION=on"] != moving[2:] or still.index("WALK_REDUCE_MOTION=on") > still.index(moving[3]):
        failures.append("with Reduce Motion on it is another walk, or the library hears of it too late")
    words = {line.split()[0] for seed in range(200) for line in walk(seed, 110, two=True)}
    missing = WORDS - words
    if missing:
        failures.append(f"never walked in 200 walks: {sorted(missing)}")
    if words - WORDS:
        failures.append(f"words lib-walk.sh does not list: {sorted(words - WORDS)}")
    for failure in failures:
        print(f"✘ {failure}")
    print("walk.py: " + ("every walk is whole, and the same seed walks the same way" if not failures else f"{len(failures)} failed"))
    return 1 if failures else 0


WORDS = {"switch_dock", "switch_click", "switch_to", "switch_cmdtab", "switch_backtick", "switch_menu", "tile_click", "focus_key", "arrange_key", "undo",
         "redo", "rotate", "mirror", "pin", "peek", "save_view", "view_n", "resize_edge", "float_all_here", "hold_view", "open_new", "close_new", "minimize", "restore", "hide", "unhide",
         "quit_app", "reopen", "dock_key", "float_key", "drag_onto", "drag_out", "drag_by", "drag_edge", "view", "resize_gap", "resize_key", "full_screen",
         "wallpaper_click", "title_double_click", "pause", "resume", "float_all", "quit_and_start", "idle_act", "display", "send_across"}
PINNED = ['view all', 'switch_dock calendar', 'minimize']


def main(arguments):
    if arguments == ["--self-test"]:
        return self_test()
    if not arguments or arguments[0].startswith("-"):
        print(__doc__)
        return 64
    seed, rest = arguments[0], arguments[1:]
    options = {"--acts": "110", "--display": "laptop", "--tiling": "defaults", "--reduce-motion": "off"}
    control = "--control" in rest
    rest = [word for word in rest if word != "--control"]
    for name, value in zip(rest[::2], rest[1::2]):
        if name not in options:
            print(f"walk.py: no option {name}", file=sys.stderr)
            return 64
        options[name] = value
    print(script(seed, int(options["--acts"]), options["--display"], options["--tiling"], control, options["--reduce-motion"] == "on"), end="")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
