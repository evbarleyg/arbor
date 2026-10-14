#!/usr/bin/env python3
"""Makes a copy of Arbor's sources fit for the Swift compiler on Linux, and checks what that compiler cannot (README.md).

    prepare.py <folder with the copied sources>

Rewrites the copy in place, never changing the number of lines, so that the compiler's messages point at the right ones.
Prints what it finds itself in the compiler's format, with paths relative to the folder. Exit code 1 if it found anything.
"""
import os
import re
import sys

# Linux has no Objective-C. `@objc` goes; `#selector(x)` becomes a reference to the method x, so its name and labels are still checked.
OBJC = re.compile(r"@objcMembers\s?|@objc(\([^)]*\))?\s?")
SELECTOR = re.compile(r"#selector\(((?:[^()]|\([^()]*\))*)\)")
MODIFIERS = r"(?:(?:private|fileprivate|internal|public|open|final|dynamic|static|class|nonisolated|@MainActor|@IBAction)\s+)*"
OBJC_FUNC = re.compile(r"@(?:objc(?:\([^)]*\))?|IBAction)\s+" + MODIFIERS + r"func\s+(\w+)")
# An override of a framework's method is exposed to Objective-C without saying so.
OVERRIDE_FUNC = re.compile(r"\boverride\s+" + MODIFIERS + r"func\s+(\w+)")

# Core Foundation types have no runtime class to test for: the Mac's compiler refuses `as?` and `is` with them.
CF_TYPE = (r"(?:CF[A-Z]\w+|AXUIElement|AXObserver|AXValue|AXTextMarker\w*|CG(?:Color|ColorSpace|Path|MutablePath|Image|Event|EventSource|Context|"
           r"Gradient|DataProvider|DisplayMode|Font|Layer|PDFDocument)|CVPixelBuffer|CVImageBuffer|CVBuffer|CVDisplayLink|CMSampleBuffer|"
           r"CMFormatDescription|CMBlockBuffer|IOSurfaceRef|TISInputSource|CTFont|CTLine|CTFrame|CTRun|SecKey|SecCertificate|SecTrust|SecCode|"
           r"SecStaticCode|SecTask|IOHIDManager|IOHIDDevice)")
CF_CAST = re.compile(r"\b(as\?|is)\s+(" + CF_TYPE + r")\b(?!\.)")

# The compiler runs on Linux, but the question is what a Mac would compile: conditions are answered as a Mac answers them.
# `canImport` of a framework answers itself: there is a stand-in or there is not.
CONDITION = re.compile(r"^\s*#(?:if|elseif)\b")
CONDITIONS = [
    (re.compile(r"\bos\(macOS\)"), "true"),
    (re.compile(r"\bos\(\w+\)"), "false"),
    (re.compile(r"\bcanImport\((?:Glibc|Musl|Android|WinSDK|FoundationNetworking|FoundationXML|FoundationEssentials|UIKit)\)"), "false"),
]

# CGRect and its kin can be hashed only from macOS 15, and Arbor runs on 14. Linux's always can. The Mac refuses where the conformance is
# asked for by name; it has let a struct's own, synthesised `Hashable` over a CGRect pass.
GEOMETRY = r"CG(?:Rect|Point|Size|Vector|AffineTransform)"
HASHED_GEOMETRY = re.compile(r"\bSet<(" + GEOMETRY + r")>|\[(" + GEOMETRY + r")\s*:\s*[A-Z\[(]")

# What the toolchain has on Linux whatever the version, and a Mac only from macOS 15 on. Arbor runs on 14, where the compiler refuses it. A file that
# asks `#available(macOS 15` knows what it is doing.
NEWER = [
    (re.compile(r"^\s*import Synchronization\b"), "'Synchronization' (Mutex, Atomic)", "15.0"),
    (re.compile(r"\bU?Int128\b"), "'Int128'", "15.0"),
    (re.compile(r"\bRangeSet\b|\.indices\(where:"), "'RangeSet'", "15.0"),
    (re.compile(r"\bInlineArray\b"), "'InlineArray'", "26.0"),
]
ASKS = re.compile(r"available\(macOS (1[5-9]|[2-9][0-9])")

REWRITES = [
    # Darwin's are computed properties; glibc's are global variables, which Swift 6 lets nobody touch.
    (re.compile(r"(?<![\w.])std(err|out|in)\b(?!\w)"), r"MacFoundation.std\1"),
    # Where glibc has the same name with another type.
    (re.compile(r"(?<![\w.])SOCK_(STREAM|DGRAM)\b(?!\.rawValue)"), r"Int32(SOCK_\1.rawValue)"),
    (re.compile(r"(?<![\w.])SHUT_(RDWR|RD|WR)\b"), r"Int32(SHUT_\1)"),
    (re.compile(r"\btv_usec: (?:Int32|__darwin_suseconds_t)\("), "tv_usec: Int("),
    (re.compile(r"^(\s*)(\S.*\.sun_len = )"), r"\1// \2"),
    # Initializers that Linux's Foundation leaves out and no extension can add.
    (re.compile(r"\bNS(Mutable)?AttributedString\(\)"), r'NS\1AttributedString(string: "")'),
]


def code_only(line):
    """The line without a trailing comment. Good enough: no string in Arbor holds `//` followed by something these checks look for."""
    at = line.find("//")
    return line if at < 0 else line[:at]


def main():
    root = sys.argv[1]
    files = sorted(os.path.join(folder, name) for folder, _, names in os.walk(root) for name in names if name.endswith(".swift"))
    texts = {path: open(path, encoding="utf-8").read() for path in files}
    exposed = set()
    for text in texts.values():
        exposed.update(OBJC_FUNC.findall(text))
        exposed.update(OVERRIDE_FUNC.findall(text))

    problems = []
    for path, text in texts.items():
        shown = os.path.relpath(path, root)
        lines = text.split("\n")
        for number, line in enumerate(lines, 1):
            code = code_only(line)
            for match in SELECTOR.finditer(code):
                parts = match.group(1).split("(")[0].strip().split(".")
                framework = len(parts) > 1 and re.match(r"(NS|CA|SC|UN)[A-Z]", parts[0])
                if not framework and ":" not in parts[0] and parts[-1] not in exposed:
                    problems.append(f"{shown}:{number}:{match.start() + 1}: error: argument of '#selector' refers to "
                                    f"'{parts[-1]}', which no file marks '@objc'")
            for match in CF_CAST.finditer(code):
                how = ("conditional downcast to Core Foundation type '%s' will always succeed" if match.group(1) == "as?"
                       else "'is' test is always true because '%s' is a Core Foundation type")
                problems.append(f"{shown}:{number}:{match.start() + 1}: error: {how % match.group(2)}; compare CFGetTypeID, then 'as!'")
            for match in HASHED_GEOMETRY.finditer(code):
                problems.append(f"{shown}:{number}:{match.start() + 1}: error: conformance of '{match.group(1) or match.group(2)}' to 'Hashable' "
                                "is only available in macOS 15 or newer, and Arbor runs on 14")
            for pattern, what, version in NEWER:
                match = pattern.search(code)
                if match and not ASKS.search(text):
                    problems.append(f"{shown}:{number}:{match.start() + 1}: error: {what} is only available in macOS {version} or newer, and Arbor runs on 14")
            if CONDITION.match(line):
                for pattern, replacement in CONDITIONS:
                    line = pattern.sub(replacement, line)
            line = SELECTOR.sub(r"Selector(checked: \1)", line)
            line = OBJC.sub("", line)
            for pattern, replacement in REWRITES:
                line = pattern.sub(replacement, line)
            lines[number - 1] = line
        # At the end, where it moves no line. On a Mac, Foundation, AppKit and Carbon each bring all of MacFoundation.
        extra = "import MacFoundation\n"
        if re.search(r"^\s*import Carbon\b", text, re.MULTILINE):
            extra += "import CarbonSwift\nimport ApplicationServices\n"
        with open(path, "w", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n" + extra)
    for problem in problems:
        print(problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
