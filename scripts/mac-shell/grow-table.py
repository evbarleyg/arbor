#!/usr/bin/env python3
"""Reads grow.jsonl (scripts/mac-shell/probe-how-far-a-window-grows.sh) and prints its tables.

  grow-table.py grow.jsonl              every result, a line each, by circumstance (label)
  grow-table.py grow.jsonl --orders     order x circumstance for every journey
  grow-table.py grow.jsonl --calls NAME [LABEL]   every call of the results of that name
"""
import json
import sys


def f(r):
    return "-" if r is None else ",".join(format(v, "g") for v in r[:2]) + " " + "x".join(format(v, "g") for v in r[2:])


def load(path):
    out = []
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        try:
            o = json.loads(line)
        except ValueError:
            out.append({"kind": "text", "text": line.rstrip(), "line": n})
            continue
        o["line"] = n
        out.append(o)
    return out


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    rows = load(sys.argv[1])
    mode = sys.argv[2] if len(sys.argv) > 2 else ""
    if mode == "--calls":
        name = sys.argv[3]
        label = sys.argv[4] if len(sys.argv) > 4 else None
        for o in rows:
            if o.get("name") != name or (label and o.get("label") != label):
                continue
            if o["kind"] == "call":
                print(f'{o["line"]:5} {o["label"]:<18}{o.get("order",""):<5}{"" if o.get("reads", True) else "blind "}{o["call"]:<5}{o["asked"]} err {o["error"]} {o["ms"]:.1f} ms: {f(o.get("before"))} -> ax {f(o.get("ax"))} ws {f(o.get("ws"))}')
            elif o["kind"] == "result":
                print(f'{o["line"]:5} {o["label"]:<18}{o.get("order",""):<5}= {f(o["rest"])} notes {o["notes"]}')
        return
    if mode == "--late":
        for o in rows:
            if o["kind"] != "result" or "later" not in o:
                continue
            looks = o["later"]
            late = [l["after"] for l in looks if l["ax"] != o["end"] or l["ws"] != o["endServer"]]
            last = o["notes"][-1][0] if o["notes"] else None
            print(f'{o["line"]:5} {o["label"]:<24}{o["name"]:<30}{o.get("order",""):<5}{f(o["placed"]):<22}-> {f(o.get("target")):<22} once {f(o["end"])} / {f(o["endServer"])} | '
                  + " | ".join(f'{l["after"]}: {"=" if l["ax"] == o["end"] else f(l["ax"])} / {"=" if l["ws"] == o["endServer"] else f(l["ws"])} (at {l["axAt"]:.0f}, took {l["axTook"]:.1f})' for l in looks)
                  + f' | notes m{o["moved"]} r{o["resized"]} last {last} | calls {o["ms"]:.1f} ms | ' + ("LATE " + str(late) if late else "same") + ("" if o["end"] == o["endServer"] else " ONCE-DIFFERS"))
        return
    if mode == "--orders":
        seen = {}
        for o in rows:
            if o["kind"] == "result" and o.get("order") in ("SPS", "PS", "SP", "sPS"):
                seen.setdefault((o["label"], o["name"]), []).append(o)
        for (label, name), group in seen.items():
            first = group[0]
            print(f'\n{label} / {name}: {f(first["placed"])}{"" if first["placedRight"] else " (wanted " + f(first["start"]) + ")"} -> {f(first["target"])}')
            for o in group:
                short = o.get("short")
                print(f'  {o["line"]:5} {o["order"]:<4}{"reads" if o.get("reads") else "blind":<6}{"RIGHT" if o["right"] else "WRONG":<6}{f(o["rest"]):<24} short {short}  moved {o["moved"]} resized {o["resized"]}  {o["ms"]:6.1f} ms  half way: {"; ".join(f(h) for h in o["halfway"]) or "-"}'
                      + ("" if o["end"] == o["rest"] else f'  AT ONCE {f(o["end"])}') + ("" if o["rest"] == o["restServer"] else f'  SERVER {f(o["restServer"])}'))
        return
    label = None
    for o in rows:
        if o.get("label") != label and "label" in o:
            label = o["label"]
            print(f"\n######## {label}")
        k = o["kind"]
        if k == "displays":
            print(f'{o["line"]:5} displays ({o["why"]}): ' + "; ".join(f'{d["n"]}: {f(d["frame"])} visible {f(d["visible"])} @{d["scale"]:g}' for d in o["displays"]))
        elif k == "window":
            print(f'{o["line"]:5} window {o["window"]} {o["bundle"]} {o["subrole"]} enhanced {o["enhanced"]} at {f(o["frame"])}')
        elif k == "result":
            print(f'{o["line"]:5} {o["name"]:<44}{o.get("order",""):<5}{"blind " if o.get("reads") is False else "":<6}{f(o["placed"]):<22}{"" if o["placedRight"] else "(!) "}-> {f(o.get("target")):<24}= {f(o["rest"]):<24}{"RIGHT" if o.get("right") else "OTHER"} short {o.get("short")} m{o["moved"]} r{o["resized"]} {o["ms"]:.1f} ms'
                  + ("" if o["end"] == o["rest"] else f'  AT ONCE {f(o["end"])}') + ("" if o["rest"] == o["restServer"] else f'  SERVER {f(o["restServer"])}'))
        elif k in ("skipped", "note", "text"):
            print(f'{o["line"]:5} {k}: {o.get("text")}')


main()
