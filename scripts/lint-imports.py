#!/usr/bin/env python3
"""Finds Swift files that use Foundation or CoreGraphics' geometry without importing it.

On Linux `import CoreGraphics` is a stand-in that passes on all of Foundation (Sources/LinuxShims), so
a file that says `JSONEncoder` and imports only CoreGraphics compiles there. On macOS it does not. The
other way round, `CGRect` is Foundation's on Linux, while on macOS Foundation alone brings the type
without its members, so a file that uses geometry writes `import CoreGraphics` (collab/README.md). This
check catches both mistakes on either platform, before a macOS CI run meets them.

It looks for the names below outside comments and string literals, so it is a net, not a proof:
add a name when one slips through. Part of `make check`.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# These bring Foundation along on macOS.
IMPORTS = re.compile(r"^\s*(@\w+(\(.*?\))?\s+)*import\s+(Foundation|AppKit|Cocoa|ServiceManagement)\b", re.M)
TYPES = ["Bundle", "CharacterSet", "Data", "Date", "DateFormatter", "FileHandle", "FileManager", "ISO8601DateFormatter",
         "IndexSet", "JSONDecoder", "JSONEncoder", "JSONSerialization", "Locale", "NSDictionary", "NSError", "NSLock",
         "NSNumber", "NSRegularExpression", "NSString", "Notification", "NotificationCenter", "Pipe", "Process",
         "ProcessInfo", "PropertyListDecoder", "PropertyListEncoder", "RunLoop", "Thread", "TimeInterval", "Timer", "URL",
         "URLComponents", "UUID", "UserDefaults"]
MEMBERS = ["components(separatedBy:", "trimmingCharacters(in:", "replacingOccurrences(of:", "range(of:", "localizedDescription",
           "addingTimeInterval(", "timeIntervalSince", "removingPercentEncoding", "write(to:", "capitalized"]
USES = re.compile(r"(?<![\w.`])(" + "|".join(TYPES) + r")\b(?!\s*:)|\.(" + "|".join(re.escape(m) for m in MEMBERS) + ")"
                  + r"|\bString\(format:")
# These bring the geometry types along on macOS, members included.
GEOMETRY_IMPORTS = re.compile(r"^\s*(@\w+(\(.*?\))?\s+)*import\s+(CoreGraphics|AppKit|Cocoa|SwiftUI|QuartzCore|ApplicationServices)\b", re.M)
GEOMETRY = re.compile(r"(?<![\w.`])(CGRect|CGPoint|CGSize|CGFloat)\b|\.(minX|midX|maxX|minY|midY|maxY)\b|\.insetBy\(dx:")
NOISE = re.compile(r'//.*?$|/\*.*?\*/|#*""".*?"""#*|#"(.*?)"#|"(\\.|[^"\\\n])*"', re.M | re.S)


def problems_in(text, name):
    """What is wrong with the imports of one file, at most one line per module."""
    problems = []
    # Blank out comments and strings, keeping the line numbers.
    code = NOISE.sub(lambda match: re.sub(r"[^\n]", " ", match.group(0)), text)
    for module, imports, uses in (("Foundation", IMPORTS, USES), ("CoreGraphics", GEOMETRY_IMPORTS, GEOMETRY)):
        if imports.search(code):
            continue
        for number, line in enumerate(code.split("\n"), 1):
            match = uses.search(line)
            if match:
                used = match.group(0).lstrip(".").rstrip("(:")
                problems.append(f"{name}:{number}: error: uses `{used}` without `import {module}`")
                break
    return problems


def main():
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
        print("These compile on Linux, where CoreGraphics is a stand-in that passes on Foundation and CGRect is Foundation's, but not on macOS.")
        return 1
    if files < 50:
        print(f"only {files} Swift files were found, so this proves nothing")
        return 1
    print("imports are fine")
    return 0


if __name__ == "__main__":
    sys.exit(main())
