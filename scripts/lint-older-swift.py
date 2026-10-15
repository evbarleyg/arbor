#!/usr/bin/env python3
"""Finds the one thing that crashes the older of the Swift releases Arbor promises to build with, and that only a Mac would notice.

Swift 6.3 (Xcode 26.4 to 26.6) dies while it generates code for

    Binding<String>(get: { @MainActor in … }, set: { @MainActor new in … })

with "fatal error encountered during compilation" and a stack dump that names the file and no line. It happens only with Apple's
SwiftUI, so neither the Linux build nor `make typecheck-mac` sees it, with any compiler. `Binding<String>.onMainActor(get:set:)`
(Sources/ArborKit/UI/SettingsListViews.swift) says the same and compiles everywhere; its comment has the reason.

What else the older compiler refuses it refuses on Linux too, with a line number: CI's job `linux-oldest-swift` is the net for that.

It looks for the words outside comments and strings, so it is a net, not a proof: closures that are first given a name and a
`@MainActor` type and then handed over crash it as well, and only the Mac job finds those. Part of `make lint`; `--self-test` tries the
check on wrong and right text.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# A closure marked @MainActor under the label `get:` or `set:`, whoever is called: `Binding<…>(`, `Binding<…>.init(`, a bare `.init(`.
# Nothing else in Arbor has those labels, and under `onMainActor(get:set:)` the mark is not needed.
CRASHES = re.compile(r"\b(get|set):\s*\{\s*(@\w+(\([^()]*\))?\s+)*@MainActor\b")
NOISE = re.compile(r'//.*?$|/\*.*?\*/|#*""".*?"""#*|#"(.*?)"#|"(\\.|[^"\\\n])*"', re.M | re.S)


def problems_in(text, name):
    """One line for every binding with such a closure: for the first of its two."""
    # Blank out comments and strings, keeping the line numbers.
    code = NOISE.sub(lambda match: re.sub(r"[^\n]", " ", match.group(0)), text)
    problems, getter = [], None
    for match in CRASHES.finditer(code):
        # A marked setter belongs to the marked getter before it if nothing but that getter's closure lies between.
        if match.group(1) == "set" and getter is not None and "get:" not in code[getter:match.start()] \
                and code.count("{", getter, match.start()) == code.count("}", getter, match.start()):
            getter = None
            continue
        getter = code.rindex("{", 0, match.end()) if match.group(1) == "get" else None
        problems.append(
            f"{name}:{code.count(chr(10), 0, match.start()) + 1}: error: Swift 6.3 crashes on a @MainActor closure handed to "
            "Binding(get:set:); write Binding<…>.onMainActor(get: { … }, set: { new in … })")
    return problems


def self_test():
    cases = [
        ("on one line", "Binding<Bool>(get: { @MainActor in isOn }, set: { @MainActor new in set(new) })", 1),
        ("over several lines", "Binding<String>(\n  get: { @MainActor in text },\n  set: { @MainActor new in\n    text = new\n  })", 1),
        ("the type left to the compiler", "Binding(get: { @MainActor in text }, set: { @MainActor new in text = new })", 1),
        ("a type with arguments of its own", "Binding<Pane<Int>?>(get: { @MainActor in pane }, set: { @MainActor new in go(new) })", 1),
        ("a tuple", "Binding<(Int, Int)>(get: { @MainActor in pair }, set: { @MainActor new in pair = new })", 1),
        ("only the setter is marked, and it is the setter that crashes", "Binding<Bool>(get: { isOn }, set: { @MainActor new in set(new) })", 1),
        ("a getter with braces of its own", "Binding<Bool>(get: { rows.contains { $0.isOn } }, set: { @MainActor new in set(new) })", 1),
        ("a marked getter with braces of its own", "Binding<Bool>(get: { @MainActor in rows.contains { $0.isOn } }, set: { @MainActor new in set(new) })", 1),
        (".init", "var x: Binding<String> { .init(get: { @MainActor in text }, set: { @MainActor new in text = new }) }", 1),
        ("the type's .init", "Binding<String>.init(get: { @MainActor in text }, set: { @MainActor new in text = new })", 1),
        ("another mark first", "Binding<Bool>(get: { @Sendable @MainActor in isOn }, set: { _ in })", 1),
        ("two of them", "Binding(get: { @MainActor in a }, set: { _ in })\nBinding(get: { @MainActor in b }, set: { _ in })", 2),
        ("two of them, all four marked",
         "Binding(get: { @MainActor in a }, set: { @MainActor n in a = n })\nBinding(get: { @MainActor in b }, set: { @MainActor n in b = n })", 2),
        ("the helper", "Binding<Bool>.onMainActor(get: { isOn }, set: { new in set(new) })", 0),
        ("the helper's own line", "Binding(get: get, set: set)", 0),
        ("closures that are not marked", "Binding<Bool>(get: { isOn }, set: { new in set(new) })", 0),
        ("a task on the main actor", "Task { @MainActor [weak self] in self?.look() }", 0),
        ("in a comment", "// Binding(get: { @MainActor in a }, set: { @MainActor new in a = new })", 0),
        ("a computed property's accessors", "var a: Int {\n  get { b }\n  set { b = newValue }\n}", 0),
    ]
    failed = [f"{what}: {len(problems_in(text, 'x'))} found, {wanted} expected" for what, text, wanted in cases
              if len(problems_in(text, "x")) != wanted]
    second = problems_in("\nvar a: Binding<Bool> {\n  Binding<Bool>(get: { @MainActor in a }, set: { _ in })\n}", "x")
    if len(second) != 1 or not second[0].startswith("x:3:"):
        failed.append(f"the line number: {second}")
    for line in failed:
        print("lint-older-swift self-test:", line)
    return 1 if failed else 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    problems, files = [], 0
    for top in ("Sources", "Tests"):
        for folder, _, names in os.walk(os.path.join(ROOT, top)):
            for name in sorted(names):
                if not name.endswith(".swift"):
                    continue
                path = os.path.join(folder, name)
                with open(path, encoding="utf-8") as handle:
                    problems += problems_in(handle.read(), os.path.relpath(path, ROOT))
                files += 1
    for problem in problems:
        print(problem)
    if problems:
        return 1
    if files < 50:
        print(f"only {files} Swift files were found, so this proves nothing")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
