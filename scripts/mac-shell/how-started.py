#!/usr/bin/env python3
"""How does each Mac shell script start Arbor? A count, by reading the scripts.

    scripts/mac-shell/how-started.py              the count, and the scripts that are not the common case
    scripts/mac-shell/how-started.py check-F51.sh shots-minimap.sh      those scripts, a line each

Why anybody asks: an Arbor that is the bare binary and a child of the script's shell has the Accessibility permission from its first
instant and borrows it from whoever started the shell; macOS tells it things it does not tell the app a person opens (lib.sh, "As a person
starts it"). `run.sh --as-a-person` changes the start for every script that goes through one of the two doors, arbor_launch in lib.sh and
arbor_start_apps in lib-apps.sh. This says which scripts those are, and which start Arbor by a call of their own, which the switch does not reach.

It follows what a script reads in (`source`) and hands over to (`exec "$BASH"`), and the functions of the libraries that lead to a door. A name counts
where a command can stand, not inside a message. On 2026-10-15 a plain grep for the same names gave the same sum.
"""
import collections
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
# They start other scripts, or none: no playing of their own.
HARNESS = {"run.sh", "run-list.sh", "rehearse.sh", "preflight.sh", "compile.sh", "compile-tools.sh"}
DOORS = {"arbor_launch": "lib.sh", "arbor_start": "lib.sh", "arbor_relaunch": "lib.sh", "arbor_start_apps": "lib-apps.sh"}
BEFORE_A_COMMAND = (r'(?m)(?:^|[;&|({!]|\bthen|\bdo|\belse|\bif|\bwhile|\buntil|\beventually|\bcheck "[^"\n]*"|\brecorded [\w-]+)[ \t]*'
                    r'(?:[A-Za-z_]+=(?:"[^"\n]*"|\S*)[ \t]+)*')
READS_IN = re.compile(r'(?:source|exec "\$BASH"|exec bash|bash)\s+'
                      r'"\$(?:\(dirname "\$(?:0|\{BASH_SOURCE\[0\]\})"\)|GATE_HERE|folder)/([\w./-]+\.sh)"')
FUNCTION = re.compile(r"^(\w+)\(\) \{([^\n]*)\}[ \t]*$|^(\w+)\(\) \{[ \t]*\n(.*?)^\}", re.S | re.M)


def called(name, text):
    return re.search(BEFORE_A_COMMAND + name + r"(?![\w-])", text) is not None


def read():
    os.chdir(HERE)
    source = {}
    for path in sorted(glob.glob("*.sh") + glob.glob("suite/*.sh")):
        with open(path, encoding="utf-8") as file:
            source[path] = "\n".join(line for line in file.read().split("\n") if not line.lstrip().startswith("#"))
    return source


def leading_to_a_door(source, libraries):
    """Every function of a library but lib.sh that ends at a door. Of lib.sh the doors alone: nothing else in it starts Arbor."""
    bodies = {}
    for path in libraries:
        if path != "lib.sh":
            for match in FUNCTION.finditer(source[path]):
                bodies[match.group(1) or match.group(3)] = match.group(2) or match.group(4) or ""
    lead = {name: {door} for name, door in DOORS.items()}
    grew = True
    while grew:
        grew = False
        for name, body in bodies.items():
            for other in list(lead):
                if other != name and called(other, body) and not lead[other] <= lead.get(name, set()):
                    lead.setdefault(name, set()).update(lead[other])
                    grew = True
    return lead


def kin(path, source, seen):
    for match in READS_IN.finditer(source[path]):
        other = os.path.normpath(os.path.join(os.path.dirname(path), match.group(1)))
        if other in source and other not in seen:
            seen.add(other)
            kin(other, source, seen)
    return seen


def ways(text, lead):
    how = set()
    for name, doors in lead.items():
        if called(name, text):
            how |= {"bare, by " + door for door in doors}
    for pattern, way in (
        (r'"\$ARBOR_BIN/Arbor"(?! --)', "bare, by a call of its own"),
        (r'ARBOR_BUNDLED=1|Contents/MacOS/Arbor" *(?:>|&|\\|$)', "the bundle's binary, the shell's child"),
        (r"\bARBOR_BUNDLE=", "open, ARBOR_BUNDLE"),
        (r'open -n [^\n]*(?:\$app\b|\$ARBOR_APP|\$copy|\$bundle)|open -n "\$\{arguments', "open, by a call of its own"),
        (r'make install|install_here|open "\$download"|open "\$installed"', "open, by make install"),
        (r"arbor-e2e|make e2e", "arbor-e2e"),
    ):
        if re.search(pattern, text, re.M):
            how.add(way)
    return how


def main(asked):
    source = read()
    libraries = [path for path in source if os.path.basename(path).startswith("lib")]
    lead = leading_to_a_door(source, libraries)
    rows = {}
    for path in source:
        if path not in libraries and path not in HARNESS:
            others = [other for other in kin(path, source, set()) if other not in libraries]
            rows[path] = ways("\n".join([source[path]] + [source[other] for other in others]), lead)
    if asked:
        for path in asked:
            path = path.replace("scripts/mac-shell/", "")
            print(path + ": " + ("; ".join(sorted(rows[path])) or "starts no Arbor" if path in rows else "no script of this folder"))
        return
    bare = {path for path, how in rows.items() if any(way.startswith("bare") for way in how)}
    opened = {path for path, how in rows.items() if any(way.startswith("open") for way in how)}
    print(f"{len(rows)} scripts ({len(libraries)} libraries and {len(HARNESS)} tools of the harness aside)")
    print(f"{len(bare)} start the bare binary as the shell's child at least once")
    for way, count in sorted(collections.Counter(way for how in rows.values() for way in how).items()):
        print(f"  {count:4} {way}")
    print(f"{sum(1 for path in bare if all(way.startswith('bare') for way in rows[path]))} never start it any other way")
    beyond = sorted(path for path in bare if not any(way.startswith("bare, by lib") for way in rows[path]))
    print(f"the switch does not reach, no door being used: {' '.join(beyond) or 'none'}")
    print(f"{len(opened)} go through Launch Services at least once: {' '.join(sorted(opened))}")
    print(f"  never the bare binary: {' '.join(sorted(opened - bare))}")
    print(f"start no Arbor of their own: {' '.join(sorted(path for path, how in rows.items() if not how))}")


if __name__ == "__main__":
    main(sys.argv[1:])
