#!/usr/bin/env python3
"""What Arbor shows is spelled as macOS spells: color, gray, neighbor, minimized.

Decided by the product owner on 2026-10-14: American spelling in everything the app shows (menus, panels, the settings window, the
line on screen, replies, `doctor`, `help`). Keys of settings.json, words a command also answers to, comments and the docs stay as
they are. So this reads only what stands between quotation marks in the sources of the app and its command line tool.

  scripts/lint-spelling.py               every finding as path:line: word, in "…"; exit code 1 if there is one
  scripts/lint-spelling.py --self-test
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDERS = ["Sources/ArborCore", "Sources/ArborKit", "Sources/ArborIPC", "Sources/Arbor", "Sources/arborctl"]
BRITISH = re.compile(
    r"\b(\w*colour\w*|neighbour\w*|grey\w*|centre[ds]?|centring|behaviour\w*|minimis\w+|maximis\w+|organis\w+|recognis\w+|customis\w+"
    r"|licence|favour\w*|honour\w*|labelled|cancelled|cancelling|travell\w+|dialogue|catalogue|whilst|analyse[ds]?|programme|fulfil)\b",
    re.IGNORECASE)
# Typed, not read: keys of settings.json wherever they stand, and spellings a command goes on answering to where they stand alone.
KEYS = {"focusRingColour", "appColours", "appColourAmount"}
ALIASES = {"neighbour"}
INTERPOLATION = re.compile(r"\\\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\)")
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')


def texts(source):
    """(line number, text) for everything between quotation marks, interpolations taken out."""
    block = False
    for number, line in enumerate(source.split("\n"), 1):
        if line.count('"""') % 2 == 1:
            block = not block
            continue
        if block:
            yield number, INTERPOLATION.sub(" ", line)
            continue
        # A comment begins at the first // that is outside a literal.
        outside = LITERAL.sub(lambda found: '"' + "x" * len(found.group(1)) + '"', INTERPOLATION.sub(lambda f: "y" * len(f.group(0)), line))
        cut = outside.find("//")
        code = line if cut < 0 else line[:cut]
        for found in LITERAL.finditer(INTERPOLATION.sub(" ", code)):
            yield number, found.group(1)


def findings(source):
    for number, text in texts(source):
        for found in BRITISH.finditer(text):
            word = found.group(0)
            if word not in KEYS and not (word in ALIASES and text == word):
                yield number, word, text.strip()


def self_test():
    sample = '''
let a = "Focus ring colour"  // the colour of the line
let b = "focusRingColour"
let c = "docked \\(id) beside \\(neighbour)"
// "grey" in a comment
let d = """
  neighbor <edge>   move to the neighbouring space
  """
let e = "`focusRingColour` needs a color"
let f = "https://example.com//grey"
case "neighbor", "neighbour": "no neighbour on the left"
'''
    got = [(number, word) for number, word, _ in findings(sample)]
    want = [(2, "colour"), (7, "neighbouring"), (10, "grey"), (11, "neighbour")]
    if got != want:
        print(f"lint-spelling self-test: got {got}, want {want}")
        return 1
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    count = 0
    for folder in FOLDERS:
        for path in sorted(glob.glob(os.path.join(ROOT, folder, "**", "*.swift"), recursive=True)):
            for number, word, text in findings(open(path, encoding="utf-8").read()):
                print(f"{os.path.relpath(path, ROOT)}:{number}: {word}, in \"{text[:100]}\"")
                count += 1
    if count:
        print(f"{count} British spellings in what Arbor shows; macOS says color, gray, neighbor, minimized (scripts/lint-spelling.py)")
    return 1 if count else 0


if __name__ == "__main__":
    sys.exit(main())
