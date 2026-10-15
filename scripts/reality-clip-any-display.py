#!/usr/bin/env python3
"""scripts/reality-clip-any-display.py <folder with traces/>…: scripts/reality-clip.py for a Mac with the Dock anywhere and more than one display.

Every setFrame in every trace: what was asked, what the window took. Each is held against the display on which most of the ASKED frame lies, by the newest
`displays` answer in that trace. An answer that differs is sorted by the edge of that display's VISIBLE frame at which the taken frame ends although more was asked:
  clipped-bottom / clipped-right / clipped-left / clipped-top    the taken frame ends (within a point) at that edge and the asked one went on, or began before it
  parked        the asked frame lies on no display by more than a tenth: Arbor's corner, where macOS holds nothing back
  rounded       no side differs by a point or more
  other         anything else: printed whole, to be read
Prints every answer that differs, then a line of counts for each folder. Run with python3 -I.
"""
import collections, glob, json, os, sys

def flat(f):
    return [f[0][0], f[0][1], f[1][0], f[1][1]] if isinstance(f[0], list) else list(f)

def overlap(a, b):
    w = min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])
    h = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
    return max(w, 0) * max(h, 0)

def sort(asked, took, displays):
    area = asked[2] * asked[3] or 1
    best = max(displays, key=lambda d: overlap(asked, d["frame"]), default=None)
    if best is None:
        return "no-displays-known", None
    if overlap(asked, best["frame"]) < area / 10:
        return "parked", best
    if all(abs(x - y) < 1 for x, y in zip(asked, took)):
        return "rounded", best
    v = best["visible"]
    kinds = []
    if abs(took[1] + took[3] - (v[1] + v[3])) <= 1 and asked[1] + asked[3] > took[1] + took[3] + 1: kinds.append("clipped-bottom")
    if abs(took[0] + took[2] - (v[0] + v[2])) <= 1 and asked[0] + asked[2] > took[0] + took[2] + 1: kinds.append("clipped-right")
    if abs(took[0] - v[0]) <= 1 and asked[0] < took[0] - 1: kinds.append("clipped-left")
    if abs(took[1] - v[1]) <= 1 and asked[1] < took[1] - 1: kinds.append("clipped-top")
    return "+".join(kinds) or "other", best

if not sys.argv[1:]:
    sys.exit(__doc__)
for folder in sys.argv[1:]:
    if not glob.glob(folder + "/traces/*.jsonl"):  # "0 answers differ" of a folder that is not there would read like a cure
        sys.exit("no traces/*.jsonl under " + folder)
    counts, calls, seen = collections.Counter(), 0, []
    for path in sorted(glob.glob(folder + "/traces/*.jsonl")):
        displays, last, name = [], {}, os.path.basename(path)[:-6]
        for n, line in enumerate(open(path, encoding="utf-8"), 1):
            o = json.loads(line)
            if o.get("call") == "displays" and o.get("result"):
                displays = [{"frame": flat(d["frame"]), "visible": flat(d["visible"]), "main": d.get("main")} for d in o["result"]]
                key = json.dumps(displays)
                if key not in seen:
                    seen.append(key)
                    print(f"{name} line {n}: displays " + " ; ".join(f'{"main " if d["main"] else ""}{d["frame"]} visible {d["visible"]}' for d in displays))
            if o.get("read") == "stackedWindows":
                for w in o["result"]: last[w["id"]] = flat(w["frame"])
            if o.get("event") in ("changed", "appeared") and "window" in o:
                last[o["window"]["id"]] = flat(o["window"]["frame"])
            if o.get("call") == "setFrame" and o.get("result"):
                calls += 1
                asked, took = flat(o["frame"]), flat(o["result"])
                if asked != took:
                    kind, d = sort(asked, took, displays)
                    counts[kind] += 1
                    print(f'{name:<10} line {n:<5} w{o["id"]} stood {last.get(o["id"])} asked {asked} took {took} | {kind} | visible {d["visible"] if d else None}')
                last[o["id"]] = took
    print(f"{folder}: {calls} setFrame calls, {sum(counts.values())} answers differ: " + (", ".join(f"{k} {v}" for k, v in sorted(counts.items())) or "none"))
