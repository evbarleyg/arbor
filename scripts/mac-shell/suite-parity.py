#!/usr/bin/env python3
"""Lists the real-window suite's claims under the items of collab/parity.json that they prove.

A claim says which items it is proof of on the line after it:

    claim "drag a window to the left screen edge: a preview shows where it will land, and it docks there"
    proves T01 T11

This script reads those lines from scripts/mac-shell/suite/*.sh and lib.sh, and the evidence in
collab/evidence/*-latest.txt. An item ALL of whose claims hold gets them in its "e2e" list, which is what makes
`make parity` call it verified. An item one of whose claims failed or has not run gets none of them: it is not
verified by the ones that hold, and a failed claim in the list would make it broken and `make parity` fail for
everyone. What is left out, and why, is printed: those are findings. Steps of other runners (arbor-e2e, proof.sh), and
claims without a `proves` line, stay as they are listed.

  scripts/mac-shell/suite-parity.py           rewrite collab/parity.json; then run `make parity`
  scripts/mac-shell/suite-parity.py --check   change nothing; exit code 1 if it is not up to date
"""

import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import parity  # noqa: E402

CLAIM = re.compile(r'^\s*claim "(.*)"\s*\n(?:\s*proves ([^\n#]*))?', re.MULTILINE)


def claims_in(paths):
    """Returns ({item id: [claim titles]}, every claim's title), in the order the scripts make them."""
    proofs, titles = {}, []
    for path in paths:
        with open(path, encoding="utf-8") as handle:
            for title, ids in CLAIM.findall(handle.read()):
                titles.append(title)
                for item in ids.split():
                    if title not in proofs.setdefault(item, []):
                        proofs[item].append(title)
    return proofs, titles


def scripts():
    return sorted(glob.glob(os.path.join(HERE, "suite", "*.sh"))) + [os.path.join(HERE, "lib.sh")]


def relist(item, proofs, titles, steps):
    """Returns (the item's new "e2e" list, why its claims were left out: [(title, reason)])."""
    others = [title for title in item.get("e2e", []) if title not in titles]
    mine = proofs.get(item["id"], [])
    missing = [(title, "failed" if steps.get(title) is False else "has not run") for title in mine
               if steps.get(title) is not True]
    return others + ([] if missing else mine), missing


def main():
    check = "--check" in sys.argv[1:]
    proofs, titles = claims_in(scripts())
    steps, _ = parity.read_evidence()
    with open(parity.PARITY, encoding="utf-8") as handle:
        lines = handle.read().split("\n")

    managed = {title for claims in proofs.values() for title in claims}
    known, changed, verified = set(), [], 0
    for index, line in enumerate(lines):
        text = line.strip()
        # One item to a line, which is how the file is kept.
        if not text.startswith('{"id"'):
            continue
        item = json.loads(text.rstrip(","))
        known.add(item["id"])
        listed, missing = relist(item, proofs, managed, steps)
        for title, reason in missing:
            print(f"{item['id']} is not verified by the suite: '{title}' {reason}")
        verified += bool(proofs.get(item["id"]) and not missing)
        if listed == item.get("e2e", []):
            continue
        changed.append(item["id"])
        if listed:
            item["e2e"] = listed
        else:
            del item["e2e"]
        indent = line[:len(line) - len(line.lstrip())]
        lines[index] = indent + json.dumps(item, ensure_ascii=False) + ("," if text.endswith(",") else "")

    unknown = sorted(set(proofs) - known)
    if unknown:
        sys.exit(f"`proves` names items collab/parity.json does not have: {', '.join(unknown)}")
    print(f"{verified} of the {len(proofs)} items the suite has claims for have all of them borne out")
    if not changed:
        return 0
    if check:
        print(f"collab/parity.json is not up to date for {', '.join(changed)}; run scripts/mac-shell/suite-parity.py")
        return 1
    # All of it or none: a run that is stopped here must not leave half a scoreboard.
    with open(parity.PARITY + ".new", "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))
    os.replace(parity.PARITY + ".new", parity.PARITY)
    print(f"collab/parity.json: relisted {', '.join(changed)}; now run `make parity`")
    return 0


if __name__ == "__main__":
    sys.exit(main())
