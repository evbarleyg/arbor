#!/usr/bin/env python3
"""Finds controller code that takes a window out of a tree without saying who gets its space.

`Workspace.forget`, `undock`, `dock` and `tryDock`, `LayoutTree.remove` and `Drop`, take `shareSpace:`, which the controller fills from
`settings.shareRemovedSpace` (F33). The parameter has a default, so that the pure model and its tests read as
before. A controller call that leaves it out therefore compiles, and is wrong only for people who have switched
the setting off: the whole group moves where only the neighbour should. No test of the new code would notice.
This check does. Part of `make lint`.

    scripts/lint-share-space.py              check Sources/ArborKit/Controller
    scripts/lint-share-space.py --self-test  check the check
"""

import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# `x.forget(w`, `x.undock(w`, `x.dock(w, at:`, `x.tryDock(w, at:` and `tree.remove(w` / `$0.remove(w`. Not `forgetInDormantWorkspaces(`, `parked.remove(`, an array's `$0.remove(at:`, another type's `forget()`.
CALL = re.compile(r"(?:\.(?:forget|undock)\((?!\))|\.(?:dock|tryDock)\((?=[^()]*?,\s*at:)|(?:\btree|\$0)\.remove\((?!at:)|\bDrop\((?=\s*window:))")
NOISE = re.compile(r'//.*?$|/\*.*?\*/|"(\\.|[^"\\\n])*"', re.M | re.S)


def problems_in(text, name):
    """One line per call that does not pass `shareSpace:`."""
    # Blank out comments and strings, keeping the positions.
    code = NOISE.sub(lambda match: re.sub(r"[^\n]", " ", match.group(0)), text)
    problems = []
    for match in CALL.finditer(code):
        depth, end = 1, match.end()
        while end < len(code) and depth:
            depth += {"(": 1, ")": -1}.get(code[end], 0)
            end += 1
        if "shareSpace:" not in code[match.end():end]:
            line = code.count("\n", 0, match.start()) + 1
            problems.append(f"{name}:{line}: pass `shareSpace: settings.shareRemovedSpace` (see scripts/lint-share-space.py)")
    return problems


def self_test():
    cases = [
        ("workspaces[d]!.forget(id)\n", 1),
        ("workspaces[d]!.forget(id, shareSpace: settings.shareRemovedSpace)\n", 0),
        ("workspace.undock(\n  id, floatingAt: frame(for: id),\n  shareSpace: settings.shareRemovedSpace)\n", 0),
        ("workspace.undock(\n  id, floatingAt: frame(for: id))\nlet shareSpace: Bool\n", 1),
        ("copy.dock(window, at: .beside(node, edge))\n", 1),
        ("copy.dock(window, at: target, evenShare: true, shareSpace: settings.shareRemovedSpace)\n", 0),
        ("workspace.tryDock(id, at: .cameraEdge(edge)).refusal(of: id)\n", 1),
        ("workspace.tryDock(id, at: .cameraEdge(edge), shareSpace: settings.shareRemovedSpace)\n", 0),
        ("workspace.changeStructure { $0.remove(window) }\n", 1),
        ("workspace.tree.remove(window, shareSpace: false)\n", 0),
        ("parked.remove(window)\nforgetInDormantWorkspaces(window)\nsystem.dock(window)\n", 0),
        ("editRules { $0.remove(at: number - 1) }\n", 0),
        ("controller.menuBarRoom.forget()\n", 0),
        ("var drop = Drop(window: window, target: target, display: display, frame: current)\n", 1),
        ("Drop(\n  window: window, target: target, display: display, frame: current, shareSpace: settings.shareRemovedSpace)\n", 0),
        ("// workspaces[d]!.forget(id)\n", 0),
    ]
    failed = [text for text, expected in cases if len(problems_in(text, "x.swift")) != expected]
    for text in failed:
        print(f"self-test failed for: {text!r}")
    return 1 if failed else 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    problems = []
    for path in sorted(glob.glob(os.path.join(ROOT, "Sources/ArborKit/Controller/*.swift"))):
        with open(path, encoding="utf-8") as handle:
            problems += problems_in(handle.read(), os.path.relpath(path, ROOT))
    for problem in problems:
        print(problem)
    if not problems:
        print("every removal says who gets the space")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
