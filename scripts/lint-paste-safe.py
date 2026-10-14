#!/usr/bin/env python3
"""Finds `#` in the shell blocks of the pages a person installs Arbor from.

At its prompt macOS's own shell, zsh, does not take `#` for a comment (`interactivecomments` is off). A pasted
`./scripts/make-signing-identity.sh   # once per Mac` hands the script four arguments: it prints its usage and makes
no certificate. An apostrophe in such a remark opens a quote that swallows every line after it. Nobody noticed as
long as the commands were tried in bash. So the blocks of these pages hold commands and nothing else, and the words
stand above or below them.

Only the pages whose blocks change the Mac, and the blocks of the README that do. The reference lists elsewhere keep
their remarks, with a sentence above them. Part of `make lint`; `--self-test` tries the check on wrong and right text.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The page, and the heading its blocks are checked under (None: all of them).
PAGES = [("docs/INSTALL.md", None), ("README.md", "## Install and run")]
FENCE = re.compile(r"^```(\w*)\s*$")
SHELLS = {"bash", "sh", "zsh", "shell", "console"}


def problems_in(text, name, heading=None):
    """One line for every line with a `#` in a shell block, under `heading` if one is given."""
    problems = []
    within = heading is None
    shell = fenced = False
    for number, line in enumerate(text.split("\n"), 1):
        fence = FENCE.match(line)
        if fence:
            shell = not fenced and fence.group(1) in SHELLS
            fenced = not fenced
        elif not fenced and heading is not None and line.startswith("## "):
            within = line.strip() == heading
        elif fenced and shell and within and "#" in line:
            problems.append(f"{name}:{number}: `#` in a block that is pasted whole; zsh does not take it for a comment: "
                            + line.strip())
    return problems


def self_test():
    wrong = "## Install and run\n\n```bash\n./make.sh   # once per Mac\nmake install\n```\n"
    right = "## Install and run\n\nOnce per Mac:\n\n```bash\n./make.sh\nmake install\n```\n"
    cases = [
        ("a remark after a command", problems_in(wrong, "x"), 1),
        ("a remark on a line of its own", problems_in("```sh\n# first\nmake\n```\n", "x"), 1),
        ("commands only", problems_in(right, "x"), 0),
        ("under the heading", problems_in(wrong, "x", "## Install and run"), 1),
        ("under another heading", problems_in("## Command line\n\n```bash\nctl help  # all\n```\n", "x", "## Install and run"), 0),
        ("after the heading's section has ended",
         problems_in(right + "\n## Command line\n\n```bash\nctl help  # all\n```\n", "x", "## Install and run"), 0),
        ("a block that is no shell's", problems_in("```json\n{\"a\": \"#fff\"}\n```\n", "x"), 0),
        ("a heading's own marks, outside a block", problems_in("# Title\n\n## More\n", "x"), 0),
        ("a `## ` inside a block ends no section", problems_in(
            "## Install and run\n\n```text\n## not a heading\n```\n\n```bash\nmake  # x\n```\n", "x", "## Install and run"), 1),
    ]
    failed = [f"{what}: {len(found)} found, {wanted} expected" for what, found, wanted in cases if len(found) != wanted]
    for line in failed:
        print("lint-paste-safe self-test:", line)
    return 1 if failed else 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    problems = []
    for page, heading in PAGES:
        with open(os.path.join(ROOT, page), encoding="utf-8") as file:
            text = file.read()
        if heading is not None and f"\n{heading}\n" not in text:
            problems.append(f"{page}: no heading `{heading}`; tell scripts/lint-paste-safe.py what it is called now")
        problems += problems_in(text, page, heading)
    for line in problems:
        print(line)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
