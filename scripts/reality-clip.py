#!/usr/bin/env python3
"""Every `setFrame` in the traces of scripts/mac-shell/reality.sh: where the window stood, what was asked, what it took.

  scripts/reality-clip.py <reality folder>…      a folder that holds traces/*.jsonl, from a Mac or from a rehearsal

Prints the answers that differ from what was asked, then what was asked past the visible bottom or the right edge and taken as asked, then the number of calls.
An answer cut at the Dock reads "took bottom 704" where the visible bottom is 705. It knows one display, 1024 points wide, with the Dock at the bottom:
scripts/reality-clip-any-display.py is for the others. It judges nothing. collab/reports/2026-10-15-how-far-a-window-grows.md was read off its output.
"""
import json, sys, glob, os
def flat(f):
    return [f[0][0], f[0][1], f[1][0], f[1][1]] if isinstance(f[0], list) else list(f)
def run(path, label):
    last, visible, display, rows = {}, None, None, []
    for n, line in enumerate(open(path), 1):
        o = json.loads(line)
        if o.get("call") == "displays" and o.get("result"):
            visible, display = o["result"][0]["visible"], o["result"][0]["frame"]
        if o.get("read") == "stackedWindows":
            for w in o["result"]: last[w["id"]] = flat(w["frame"])
        if o.get("event") in ("changed", "appeared") and "window" in o:
            last[o["window"]["id"]] = flat(o["window"]["frame"])
        if o.get("call") == "setFrame" and o.get("result"):
            a, r, b = o["frame"], o["result"], last.get(o["id"])
            rows.append((label, n, o["t"], o["id"], b, a, r, visible))
            last[o["id"]] = r
    return rows
rows = []
for folder in sys.argv[1:]:
    for path in sorted(glob.glob(folder + "/traces/*.jsonl")):
        rows += run(path, os.path.basename(folder.rstrip("/")) + ":" + os.path.basename(path)[:-6])
if not rows:  # "0 answers differ" of a folder that is not there would read like a cure
    sys.exit("no setFrame call in any traces/*.jsonl under: " + (" ".join(sys.argv[1:]) or "(no folder named)"))
def show(r):
    label, n, t, w, b, a, res, v = r
    vb = v[1] + v[3]
    same = b is not None and b[:2] == a[:2]
    print(f"{label:<28} line {n:<5} w{w} stood {b} asked {a} took {res} | origin {'same' if same else 'NEW '} | asked bottom {a[1]+a[3]} right {a[0]+a[2]} | took bottom {res[1]+res[3]} right {res[0]+res[2]} | visible bottom {vb}")
print("== answers that differ from what was asked"); 
for r in rows:
    if r[5] != r[6]: show(r)
print("== asked past the visible bottom or the right edge, and taken as asked")
for r in rows:
    label, n, t, w, b, a, res, v = r
    if a == res and (a[1] + a[3] > v[1] + v[3] or a[0] + a[2] > 1024): show(r)
print(len(rows), "setFrame calls")
