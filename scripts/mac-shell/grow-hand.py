#!/usr/bin/env python3
"""Reads inhand.jsonl (scripts/mac-shell/probe-a-size-call-in-the-hand.sh) and prints a line or two for every trial, then what the repeats have in common.

  grow-hand.py inhand.jsonl            every trial
  grow-hand.py inhand.jsonl --sum      one line per app and trial: do the repeats agree, and on what
"""
import collections
import json
import sys


def f(r):
    return "-" if r is None else "%g,%g %gx%g" % tuple(r)


def p(r):
    return "-" if r is None else "%g,%g" % tuple(r)


def load(path):
    trials = collections.OrderedDict()
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        try:
            o = json.loads(line)
        except ValueError:
            print("not JSON, line %d: %s" % (n, line.rstrip()))
            continue
        o["line"] = n
        if "label" in o:
            trials.setdefault(o["label"], []).append(o)
    return trials


def grip(g):
    if g is None or g.get("ax") is None or g.get("pointer") is None:
        return None
    return (g["pointer"][0] - g["ax"][0], g["pointer"][1] - g["ax"][1])


def facts(rows):
    out = collections.OrderedDict()
    looks = {o["name"]: o for o in rows if o["kind"] == "look"}
    hands = [o for o in rows if o["kind"] == "hand"]
    put = next((o for o in rows if o["kind"] == "put"), None)
    out["put"] = f(put["ax"]) if put else "-"
    for h in hands:
        name = h["name"]
        asked = "; ".join("%s %gx%g" % (c["call"], c["asked"][0], c["asked"][1]) if c["call"] == "size" else "pos %g,%g" % tuple(c["asked"]) for c in h["calls"])
        before = h.get("before")
        out[name + " asked"] = asked
        if "sinceRelease" in h:
            out[name + " since release ms"] = round(h["sinceRelease"], 2)
        if before:
            out[name + " before"] = f(before["ax"]) + " ptr " + p(before["pointer"]) + (" down" if before["button"] else " UP")
        out[name + " once"] = f(h["once"]["ax"]) + " / ws " + f(h["once"]["ws"])
        for l in h["later"]:
            out[name + " %d" % l["after"]] = f(l["ax"]) + " / ws " + f(l["ws"]) + (" down" if l["button"] else " up") + " @%.1f" % l["at"]
        out[name + " reports"] = " ".join("%s@%.1f" % (n[1].replace("AX", ""), n[0]) for n in h["notes"]) or "none"
        out[name + " call ms"] = " ".join("%.1f" % c["ms"] for c in h["calls"])
        if before and before.get("ax") and h["later"][-1].get("ax"):
            a, b = before["ax"], h["later"][-1]["ax"]
            out[name + " origin moved by"] = "%g,%g" % (b[0] - a[0], b[1] - a[1])
            out[name + " grip before -> after"] = "%s -> %s" % (p(grip(before)), p(grip(h["later"][-1])))
    for name in ("held", "carried-up", "carried", "let-go", "rest"):
        if name in looks:
            o = looks[name]
            out[name] = f(o["ax"]) + " / ws " + f(o["ws"]) + " ptr " + p(o["pointer"]) + (" down" if o["button"] else " up") + " grip " + p(grip(o))
    return out


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    trials = load(sys.argv[1])
    if len(sys.argv) > 2 and sys.argv[2] == "--sum":
        groups = collections.OrderedDict()
        for label, rows in trials.items():
            if not any(o["kind"] == "trial" for o in rows):
                continue
            groups.setdefault(label.rsplit(".", 1)[0], []).append(facts(rows))
        for name, all_facts in groups.items():
            print("\n%s (%d times)" % (name, len(all_facts)))
            for key in all_facts[0]:
                if key.endswith(("call ms", "reports", "since release ms")) or key[-3:] in (" 50", "200", "500"):
                    values = [x.get(key) for x in all_facts]
                    if key[-3:] in (" 50", "200", "500"):
                        values = [str(v).split(" @")[0] for v in values]
                        print("  %-34s %s" % (key, values[0] if len(set(values)) == 1 else " | ".join(values)))
                    else:
                        print("  %-34s %s" % (key, " | ".join(str(v) for v in values)))
                    continue
                values = [x.get(key) for x in all_facts]
                print("  %-34s %s" % (key, values[0] if len(set(values)) == 1 else "DIFFER: " + " | ".join(str(v) for v in values)))
        return
    for label, rows in trials.items():
        print("\n" + label + " (line %d)" % rows[0]["line"])
        if any(o["kind"] == "skipped" for o in rows):
            print("  SKIPPED")
            continue
        for key, value in facts(rows).items():
            print("  %-34s %s" % (key, value))


main()
