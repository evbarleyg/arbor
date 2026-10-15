#!/usr/bin/env python3
"""Says how much of the macOS-only code the real-window checks executed, from what scripts/mac-shell/coverage.sh brought back.

  coverage-report.py <coverage.json…> [--markdown FILE]   the table per folder and per file, and one closing line
  coverage-report.py --functions <export.json>            per file the functions that never ran, then the largest of them all
  coverage-report.py --self-test

A coverage.json is what `llvm-cov export -summary-only` prints; an export.json is the same without `-summary-only`, which also
lists every function. A measurement is called after its folder: mac-shell/coverage/both/coverage.json is `both`.

With several files the tables show what each measurement executed, side by side. They are sorted by the LAST one, and the columns that
can be given only once (not executed, functions never run, regions never entered) and the closing line are the last one's. So
name the widest measurement last.

The macOS-only code is Sources/ArborKit/AX, UI, Input and App: what Package.swift leaves out everywhere but on a Mac. Other folders in the
files (IPC, which Linux builds and tests as well) get their rows and stay out of the sum.

How llvm-cov counts, which is not how a person counts lines:
  - a line is one that lies in the body of a function, a closure or an initial value. Comments and blank lines in a body count, and
    go with the code around them. Imports, declarations without a body and comments between functions do not count at all;
  - a line was executed if any part of it was: in `guard let x else { return }` the `return` hides behind the `guard`;
  - a region is a stretch of code that runs as one, so it does tell the two apart. Swift's compiler records no branches:
    regions never entered are the nearest thing;
  - every closure is a function of its own, the hidden one to the right of `&&`, `||` and `??` too, so more functions "never ran" than
    there are `func`s that did not. In the list of functions a closure's lines count for the function around it as well.

Exit code 0, or 2 for a file that cannot be read and for a mistake in the call. It judges nothing: there is no number to reach.
"""

import json
import os
import sys

MAC_ONLY = ("AX", "UI", "Input", "App")
KIT = "Sources/ArborKit/"


class Unreadable(Exception):
    """Not an export of llvm-cov's."""


def short(path):
    """From Sources/ on: the checkout lies somewhere else on every machine."""
    place = path.find("Sources/")
    return path[place:] if place >= 0 else path


def folder_of(path):
    """Sources/ArborKit/AX/AXHelpers.swift is in ArborKit/AX."""
    parts = short(path).split("/")
    return "/".join(parts[1:3] if len(parts) > 3 else parts[1:2])


def is_mac_only(path):
    name = short(path)
    return name.startswith(KIT) and name[len(KIT):].split("/")[0] in MAC_ONLY


def label_of(path):
    name = os.path.basename(path)
    folder = os.path.basename(os.path.dirname(os.path.abspath(path)))
    return folder if name in ("coverage.json", "export.json") and folder else os.path.splitext(name)[0]


def read(path):
    try:
        with open(path, encoding="utf-8") as handle:
            export = json.load(handle)
        return export["data"][0]
    except (OSError, ValueError, KeyError, IndexError, TypeError) as problem:
        raise Unreadable(f"{path} is no export of llvm-cov's: {problem}") from problem


class Count:
    """Lines, functions and regions: how many there are and how many ran."""

    KINDS = ("lines", "functions", "regions")

    def __init__(self, summary=None):
        for kind in self.KINDS:
            numbers = (summary or {}).get(kind, {})
            setattr(self, kind, numbers.get("count", 0))
            setattr(self, kind + "_run", numbers.get("covered", 0))

    def add(self, other):
        for kind in self.KINDS:
            for name in (kind, kind + "_run"):
                setattr(self, name, getattr(self, name) + getattr(other, name))

    @property
    def percent(self):
        return 100.0 * self.lines_run / self.lines if self.lines else 0.0


def measure(data):
    """{file: Count}"""
    try:
        return {short(entry["filename"]): Count(entry["summary"]) for entry in data["files"]}
    except (KeyError, TypeError) as problem:
        raise Unreadable(f"an export without {problem}") from problem


def gather(measurement, key):
    """The files' counts summed up under key(file); files for which it answers None are left out."""
    sums = {}
    for name, count in measurement.items():
        group = key(name)
        if group is not None:
            sums.setdefault(group, Count()).add(count)
    return sums


def rows(measurements, key):
    """One row per group, the one with the most lines that the last measurement did not execute first."""
    gathered = [gather(measurement, key) for measurement in measurements]
    last = gathered[-1]
    names = sorted(last, key=lambda name: (last[name].lines_run - last[name].lines, name))
    table = []
    for name in names:
        count = last[name]
        earlier = [sums[name].lines_run if name in sums else 0 for sums in gathered[:-1]]
        table.append([name, count.lines] + earlier + [
            count.lines_run, f"{count.percent:.1f}", count.lines - count.lines_run, count.functions,
            count.functions - count.functions_run, count.regions, count.regions - count.regions_run])
    return table


def heading(first, labels):
    executed = [f"executed ({label})" for label in labels] if len(labels) > 1 else ["executed"]
    return [first, "lines"] + executed + ["%", "not executed", "functions", "never run", "regions", "never entered"]


def plain(head, table):
    widths = [max(len(str(row[index])) for row in [head] + table) for index in range(len(head))]
    lines = []
    for row in [head] + table:
        cells = [str(row[0]).ljust(widths[0])] + [str(cell).rjust(width) for cell, width in zip(row[1:], widths[1:])]
        lines.append("  ".join(cells).rstrip())
    lines.insert(1, "-" * len(lines[0]))
    return lines


def markdown(head, table):
    lines = ["| " + " | ".join(head) + " |", "|---|" + "---:|" * (len(head) - 1)]
    for row in table:
        lines.append("| " + " | ".join([f"`{row[0]}`"] + [str(cell) for cell in row[1:]]) + " |")
    return lines


def closing(measurement):
    total = gather(measurement, lambda name: "all" if is_mac_only(name) else None).get("all", Count())
    return (f"real-window coverage: {total.lines_run} of {total.lines} lines ({total.percent:.1f} %) of the macOS-only code; "
            f"{total.functions - total.functions_run} functions never run")


def report(measurements, labels, draw):
    """The lines of the whole report; `draw` is plain or markdown."""

    def folder(name):
        return folder_of(name) if is_mac_only(name) else folder_of(name) + " (not in the sum)"

    lines = []
    if len(labels) > 1:
        lines += draw(heading("measurement", labels[-1:]),
                      [rows([measurement], lambda name: label if is_mac_only(name) else None)[0]
                       for measurement, label in zip(measurements, labels) if any(is_mac_only(name) for name in measurement)])
        lines.append("")
    lines += draw(heading("folder", labels), rows(measurements, folder))
    lines.append("")
    lines += draw(heading("file", labels), rows(measurements, lambda name: name))
    lines.append("")
    lines.append(closing(measurements[-1]))
    return lines


# MARK: Functions


def never_run(data):
    """{file: (how many functions, [(first line, lines, name)])} for the functions whose first instruction never ran."""
    files = {short(entry["filename"]) for entry in data.get("files", [])}
    found = {}
    for function in data.get("functions", []):
        name = short(function["filenames"][0])
        # llvm-cov leaves the files that were not asked for out of `files`, but not their functions out of `functions`.
        if name not in files:
            continue
        own = [region for region in function["regions"] if region[5] == 0] or function["regions"]
        first, last = min(region[0] for region in own), max(region[2] for region in own)
        entry = found.setdefault(name, [0, []])
        entry[0] += 1
        if function["count"] == 0:
            # A function that only its file can see is listed as <file>:<name>.
            entry[1].append((first, last - first + 1, function["name"].split(":")[-1]))
    return found


def functions_report(data, largest=25):
    found = never_run(data)
    lines = []
    for name in sorted(found, key=lambda name: (-sum(size for _, size, _ in found[name][1]), name)):
        count, missing = found[name]
        lines.append(f"{name}: {len(missing)} of {count} functions never ran")
        lines += [f"  line {first:4}  {size:3} lines  {function}" for first, size, function in sorted(missing)]
        lines.append("")
    everything = sorted(((size, name, first, function) for name, (_, missing) in found.items() for first, size, function in missing),
                        key=lambda entry: (-entry[0], entry[1], entry[2]))
    lines.append(f"The {min(largest, len(everything))} largest (a closure's lines count for the function around it as well):")
    lines += [f"  {size:3} lines  {name}:{first}  {function}" for size, name, first, function in everything[:largest]]
    return lines


# MARK: Its own test


def self_test():
    def summary(lines, lines_run, functions, functions_run, regions=0, regions_run=0):
        return {"lines": {"count": lines, "covered": lines_run}, "functions": {"count": functions, "covered": functions_run},
                "regions": {"count": regions, "covered": regions_run}}

    def export(**files):
        return {"files": [{"filename": "/somewhere/else/Sources/ArborKit/" + name.replace("_", "/") + ".swift", "summary": numbers}
                          for name, numbers in files.items()]}

    narrow = measure(export(AX_Windows=summary(100, 40, 10, 6, 50, 10), Input_Tap=summary(60, 0, 5, 0, 20, 0),
                            IPC_Server=summary(30, 30, 3, 3, 9, 9)))
    wide = measure(export(AX_Windows=summary(100, 50, 10, 7, 50, 20), Input_Tap=summary(60, 45, 5, 4, 20, 10),
                          IPC_Server=summary(30, 30, 3, 3, 9, 9)))
    failures = []

    def expect(what, got, wanted):
        if got != wanted:
            failures.append(f"{what}: got {got!r}, wanted {wanted!r}")

    expect("the closing line leaves IPC out", closing(narrow),
           "real-window coverage: 40 of 160 lines (25.0 %) of the macOS-only code; 9 functions never run")
    expect("nothing measured is nothing executed", closing({}),
           "real-window coverage: 0 of 0 lines (0.0 %) of the macOS-only code; 0 functions never run")
    one = report([narrow], ["both"], plain)
    expect("one closing line, at the end", [line.startswith("real-window coverage:") for line in one].count(True), 1)
    expect("it is the last line", one[-1], closing(narrow))
    expect("the file with the most unexecuted lines comes first",
           [row[0] for row in rows([narrow], lambda name: name)],
           ["Sources/ArborKit/AX/Windows.swift", "Sources/ArborKit/Input/Tap.swift", "Sources/ArborKit/IPC/Server.swift"])
    expect("a row: lines, executed, percent, not executed, functions, never run, regions, never entered",
           rows([narrow], lambda name: name)[0][1:], [100, 40, "40.0", 60, 10, 4, 50, 40])
    two = report([narrow, wide], ["both", "with-session"], plain)
    expect("several measurements close with the last", two[-1],
           "real-window coverage: 95 of 160 lines (59.4 %) of the macOS-only code; 4 functions never run")
    expect("and show each one's executed lines", rows([narrow, wide], lambda name: name)[1][:4], ["Sources/ArborKit/Input/Tap.swift", 60, 0, 45])
    expect("and name them in the heading", heading("file", ["both", "with-session"])[2:4], ["executed (both)", "executed (with-session)"])
    expect("a folder outside the sum says so", any(line.startswith("ArborKit/IPC (not in the sum)") for line in one), True)
    expect("a file the earlier measurement lacks counts as nothing executed",
           rows([{}, wide], lambda name: name)[0][:4], ["Sources/ArborKit/AX/Windows.swift", 100, 0, 50])
    expect("markdown has as many cells in every row", len({line.count("|") for line in markdown(heading("file", ["a"]), rows([wide], str))}), 1)
    expect("a measurement is called after its folder", label_of("mac-shell/coverage/both/coverage.json"), "both")
    expect("or after its file", label_of("somewhere/e2e.json"), "e2e")
    expect("the folder of a file", folder_of("/x/Sources/ArborKit/AX/AXHelpers.swift"), "ArborKit/AX")
    expect("the folder of a file right under its target", folder_of("/x/Sources/Arbor/main.swift"), "Arbor")
    expect("the controller is not macOS-only", is_mac_only("Sources/ArborKit/Controller/Controller.swift"), False)

    path = "/somewhere/else/Sources/ArborKit/AX/Windows.swift"
    data = {"files": [{"filename": path}], "functions": [
        {"name": "ran", "count": 3, "filenames": [path], "regions": [[10, 1, 12, 2, 3, 0, 0, 0]]},
        {"name": "Windows.swift:hidden", "count": 0, "filenames": [path], "regions": [[20, 1, 29, 2, 0, 0, 0, 0], [22, 5, 24, 6, 0, 0, 0, 0]]},
        {"name": "small", "count": 0, "filenames": [path], "regions": [[40, 1, 40, 9, 0, 0, 0, 0]]},
        {"name": "elsewhere", "count": 0, "filenames": ["/somewhere/else/Sources/ArborCore/Tree.swift"], "regions": [[1, 1, 90, 2, 0, 0, 0, 0]]}]}
    expect("functions that never ran, with where they begin and how long they are", never_run(data),
           {"Sources/ArborKit/AX/Windows.swift": [3, [(20, 10, "hidden"), (40, 1, "small")]]})
    expect("the largest is named first", functions_report(data)[-2], "   10 lines  Sources/ArborKit/AX/Windows.swift:20  hidden")
    try:
        measure({"files": [{"filename": "x"}]})
        failures.append("an export without summaries was taken for one")
    except Unreadable:
        pass

    for failure in failures:
        print(f"✘ {failure}")
    print(f"coverage-report.py --self-test: {'FAILED' if failures else 'passed'}")
    return 1 if failures else 0


def main(arguments):
    if arguments == ["--self-test"]:
        return self_test()
    try:
        if len(arguments) == 2 and arguments[0] == "--functions":
            print("\n".join(functions_report(read(arguments[1]))))
            return 0
        page = None
        if "--markdown" in arguments:
            index = arguments.index("--markdown")
            if index + 1 >= len(arguments):
                print(__doc__)
                return 2
            page = arguments[index + 1]
            del arguments[index:index + 2]
        if not arguments or any(argument.startswith("-") for argument in arguments):
            print(__doc__)
            return 2
        measurements, labels = [measure(read(path)) for path in arguments], [label_of(path) for path in arguments]
        print("\n".join(report(measurements, labels, plain)))
        if page:
            with open(page, "w", encoding="utf-8") as handle:
                handle.write("\n".join(report(measurements, labels, markdown)) + "\n")
        return 0
    except Unreadable as problem:
        print(f"coverage-report.py: {problem}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
