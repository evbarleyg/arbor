#!/usr/bin/env python3
"""Shows every piece of free text in a trace, so that a person can see nothing private is in it.

  scripts/trace-check.py <file.jsonl>…        (make trace-check FILE=<file.jsonl>)

A trace (docs/TRACES.md) never holds window titles: each is replaced by a token such as `title[3]`, and the title
patterns of rules by marks such as `[p1]`. What it does hold in words: the names and bundle ids of the apps whose windows
were open, the commands that ran and their replies, remarks made with `trace note`, and the settings. This prints
them. Exits with 1 if a title or a pattern is anything but a token, which would be a bug in the recorder.
"""

import json
import re
import sys

TOKEN = re.compile(r"^(title(-\d+|\[\d+\])(\[[a-z]\d+\])*)?$")
MARK = re.compile(r"^\[p\d+\]$")


def windows_in(line):
    found = [line["window"]] if isinstance(line.get("window"), dict) else []
    found += line.get("windows", [])
    if line.get("call") == "allWindows":
        found += line.get("result", [])
    return found


def check(path):
    apps, bad, notes, commands, messages, bindings, excluded = set(), [], [], set(), set(), set(), set()
    count = 0
    with open(path, encoding="utf-8") as handle:
        for number, text in enumerate(handle, 1):
            text = text.strip()
            if not text or text.startswith("#"):
                continue
            try:
                line = json.loads(text)
            except ValueError:
                print(f"  line {number} is not JSON (cut off?)")
                continue
            count += 1
            for window in windows_in(line):
                apps.add(f"{window.get('app')} ({window.get('bundle')})")
                if not TOKEN.match(window.get("title", "")):
                    bad.append(f"line {number}: a window's title is {window['title']!r}")
            settings = line.get("settings")
            if isinstance(settings, dict):
                for rule in settings.get("rules", []):
                    if "title" in rule and not MARK.match(rule["title"]):
                        bad.append(f"line {number}: a rule's title pattern is {rule['title']!r}")
                bindings.update(f"{chord}: {command}" for chord, command in settings.get("bindings", {}).items())
                excluded.update(settings.get("excludedBundleIDs", []))
            if "note" in line:
                notes.append(line["note"])
            if "command" in line:
                commands.add(line["command"])
            if "done" in line:
                messages.add(line.get("message", ""))

    print(f"{path}: {count} lines")
    for title, values in (
        ("apps", sorted(apps)), ("remarks", notes), ("commands", sorted(commands)), ("replies", sorted(messages)),
        ("shortcuts changed in settings", sorted(bindings)), ("apps excluded in settings", sorted(excluded)),
    ):
        if values:
            print(f"  {title}:")
            for value in values:
                print(f"    {value}")
    for problem in bad:
        print(f"  ✘ {problem}")
    print("  ✘ do not commit this file" if bad else "  ✔ titles are tokens only; read the lists above before committing")
    return not bad


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sys.exit(0 if all([check(path) for path in sys.argv[1:]]) else 1)
