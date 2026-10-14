#!/usr/bin/env python3
"""Changes to a copy of Arbor's Accessibility layer that take a known cure out again (README.md next to this file, "Does the net hold?").

    mutants.py --list                      one line each: the name, a tab, and the stories that must go red, with tabs between them
    mutants.py --apply <name> <sources>    makes the change in the copy under <sources>. Exit code 1 if the text to change is not there exactly once

A story that stays green without the cure it is about proves nothing. `make mac-on-linux-selftest` makes each change, builds, and expects red.
When the layer is rewritten and a change no longer fits, that is reported: write the change anew, or delete it together with its story.
"""
import sys

LAYER = "ArborKit/AX/AXWindowSystem.swift"

MUTANTS = [
    {
        # The fault of 2026-10-14 on hosted Macs: every window opened in a running app was filed as "seen for the first time and did not just open".
        "name": "whoever sees a window first goes by what its app has said so far",
        "file": LAYER,
        "old": "    let hasOpenedSince = counted.insert(id).inserted\n",
        "new": "    let hasOpenedSince = false\n",
        "stories": ["a window opens in a running app that reports the focus before the creation"],
    },
]


def main():
    if sys.argv[1:] == ["--list"]:
        for mutant in MUTANTS:
            print("\t".join([mutant["name"]] + mutant["stories"]))
        return 0
    if len(sys.argv) == 4 and sys.argv[1] == "--apply":
        mutant = next((m for m in MUTANTS if m["name"] == sys.argv[2]), None)
        if mutant is None:
            print(f"no such change: {sys.argv[2]}")
            return 1
        path = f"{sys.argv[3]}/{mutant['file']}"
        text = open(path, encoding="utf-8").read()
        if text.count(mutant["old"]) != 1 or mutant["old"].count("\n") != mutant["new"].count("\n"):
            return 1
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text.replace(mutant["old"], mutant["new"]))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
