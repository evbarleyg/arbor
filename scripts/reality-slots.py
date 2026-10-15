#!/usr/bin/env python3
"""scripts/reality-slots.py <reality folder>…: what scripts/mac-shell/reality.sh wrote down, read for one thing: at every step, every docked window the window server shows: does its real frame fill the slot Arbor gives it?"""
import glob, json, os, sys
if not sys.argv[1:]:
    sys.exit(__doc__)
for folder in sys.argv[1:]:
    if not glob.glob(folder + "/*.jsonl"):  # "0 not filling" of a folder that is not there would read like a cure
        sys.exit("no *.jsonl under " + folder)
    looked, short = 0, []
    for path in sorted(glob.glob(folder + "/*.jsonl")):
        for line in open(path):
            o = json.loads(line)
            if not o.get("belief") or not o.get("truth"): continue
            for name, b in (o["belief"].get("windows") or {}).items():
                t = (o["truth"].get("windows") or {}).get(name)
                if b.get("status") != "docked" or not b.get("slot") or not t or not t.get("on"): continue
                looked += 1
                if any(abs(x - y) > 1 for x, y in zip(t["frame"], b["slot"])):
                    short.append(f'  {os.path.basename(path)[:-6]}/{o["step"]}: {name} is {t["frame"]} in the slot {b["slot"]}')
    print(f"{folder}: {looked} looks at a docked window on screen, {len(short)} not filling its slot")
    print("\n".join(short))
