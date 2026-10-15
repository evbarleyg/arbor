#!/usr/bin/env python3
"""The newcomer's score: the tasks down, what each cost across, with Arbor beside macOS alone.

    scripts/newcomer/score.py <folder or journal.jsonl>…        one for each run; fetch.sh brings them: .newcomer/<run>/
    scripts/newcomer/score.py --self-test

It reads the journals the rig kept (rig.py), which hold what the newcomer sent, what the window server's list showed before and after every
act, and the rig's verdict on each task. Nothing in it is anybody's opinion but the remarks, and those are counted, not weighed.

    done          what the windows showed at the end of the task (tasks.py), whatever the newcomer thought
    acts          clicks, drags, keys, texts typed, scrolls, moves of the pointer, passwords. Not waiting
    wrong turns   the times it said `wrong`, and the acts after which nothing on the screen had changed
    stuck, surprised, looked up      the times it said so
    moved untouched   windows whose frame changed in a round though the act did not touch them: they were not under the press or the release and
                  had the keyboard neither before nor after. Each window counts once a round. What moved between two rounds, while nobody did
                  anything, was touched by nobody
    seconds       from the task's first picture to its end. Most of it is the way through Git and the newcomer's thinking, the same for all runs

A run with Arbor is held against the first run without: better where it is done and nothing counted is worse and something is better; worse where it
is not done though macOS alone was, or everything that differs is worse. A task macOS alone does not have (installing, quitting) is a cost.
"""

import json
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tasks  # noqa: E402
from rig import DEAD  # noqa: E402

COUNTED = ("acts", "wrong", "stuck", "surprised", "lookup", "untouched")
HEADS = ("done", "acts", "wrong turns", "stuck", "surprised", "looked up", "moved untouched", "seconds")
NO_ACT = ("wait", "ready")


def read(path):
    if os.path.isdir(path):
        path = os.path.join(path, "journal.jsonl")
    entries = []
    with open(path) as file:
        for line in file:
            try:
                entries.append(json.loads(line))
            except ValueError:
                pass  # the last line of a run that was cut off
    return entries


def is_dead(entry):
    """An act after which a person would have seen nothing happen."""
    return (entry["verb"] not in NO_ACT + ("move",) and entry.get("cells") is not None and entry["cells"] <= DEAD
            and not entry["moved"] and not entry["gone"] and not entry["come"])


def tally(entries):
    """{"run": the run's own facts, "tasks": {id: counts}, "remarks": […], "timing": {part: [seconds…]}, "nonsense": n, "end": how}"""
    score = {"run": {}, "tasks": {}, "remarks": [], "timing": {}, "nonsense": 0, "end": "cut off", "left": 0}
    for entry in entries:
        kind = entry["kind"]
        if kind == "run":
            score["run"] = entry
        elif kind == "task-begin":
            score["tasks"][entry["task"]] = dict({name: 0 for name in COUNTED}, dead=0, left=0, done=None, how="cut off", notes=[], seconds=None, who=[])
        elif kind == "nonsense":
            score["nonsense"] += 1
        elif kind == "end":
            score["end"] = entry["how"]
        elif kind == "remark":
            score["remarks"].append(entry)
            counts = score["tasks"].get(entry["task"])
            if counts and entry["verb"] in counts:
                counts[entry["verb"]] += 1
        elif kind == "round":
            counts = score["tasks"][entry["task"]]
            if entry["verb"] not in NO_ACT:
                counts["acts"] += 1
            if is_dead(entry):
                counts["dead"] += 1
                counts["wrong"] += 1
            strangers = [each for each in entry["moved"] if each["id"] not in entry["touched"]] + entry["idle_moved"]
            counts["untouched"] += len(strangers)
            counts["who"] += [each["owner"] for each in strangers]
            counts["left"] += len([each for each in entry["gone"] if each not in entry["touched"]]) + len(entry["idle_gone"])
            for part, seconds in entry["timing"].items():
                if isinstance(seconds, (int, float)) and not isinstance(seconds, bool):
                    score["timing"].setdefault(part, []).append(seconds)
        elif kind == "task-end":
            score["tasks"][entry["task"]].update(done=entry["done"], how=entry["how"], notes=entry["notes"], seconds=entry["seconds"])
    return score


def name_of(score):
    run = score["run"]
    if run.get("arm") == "macos":
        return "macOS alone"
    return "Arbor %s" % (run.get("build") or "?")[:9]


def done_word(counts):
    if counts["done"]:
        return "yes" if counts["how"] == "done" else "yes (%s)" % {"time": "and never said so", "giveup": "and gave up"}.get(counts["how"], counts["how"])
    return "NO (%s)" % {"done": "thought so", "giveup": "gave up", "time": "out of time"}.get(counts["how"], counts["how"])


def compare(counts, base):
    """How a run with Arbor did against macOS alone on one task."""
    if base is None:
        return "a cost macOS alone does not have"
    if not counts["done"]:
        return "WORSE" if base["done"] else "no better: neither did it"
    if not base["done"]:
        return "BETTER"
    less = [name for name in COUNTED if counts[name] < base[name]]
    more = [name for name in COUNTED if counts[name] > base[name]]
    if less and not more:
        return "BETTER"
    if more and not less:
        return "WORSE"
    return "the same" if not more else "mixed: less %s; more %s" % (", ".join(less), ", ".join(more))


def table(scores):
    base = next((score for score in scores if score["run"].get("arm") == "macos"), None)
    lines = ["| task | with | " + " | ".join(HEADS) + " | against macOS alone |", "|---|---|" + "---|" * (len(HEADS) + 1)]
    for task in tasks.TASKS:
        first = True
        for score in scores:
            counts = score["tasks"].get(task["id"])
            if counts is None:
                if score["run"].get("arm") in task["arms"]:
                    cells = ["not reached"] + ["–"] * (len(HEADS) - 1) + [""]
                else:
                    cells = ["nothing to do"] + ["0"] * (len(HEADS) - 1) + [""]
            else:
                cells = [done_word(counts)] + [str(counts[name]) for name in COUNTED] + [str(round(counts["seconds"])) if counts["seconds"] is not None else "–"]
                if score is base or base is None:
                    cells.append("")
                elif "macos" in task["arms"] and task["id"] not in base["tasks"]:
                    cells.append("macOS alone did not get that far")
                else:
                    cells.append(compare(counts, base["tasks"].get(task["id"])))
            lines.append("| %s | %s | %s |" % (task["title"] if first else "", name_of(score), " | ".join(cells)))
            first = False
    return lines


def report(scores):
    lines = ["# The newcomer's score", ""]
    for score in scores:
        run = score["run"]
        lines.append("- **%s**: run `%s`, macOS %s, display %s, ended: %s%s" % (
            name_of(score), run.get("run", "?"), run.get("system", "?"), "x".join(str(int(each)) for each in (run.get("display") or [0, 0, 0, 0])[2:]),
            score["end"], ". Helped: " + run["helped"] if run.get("helped") else ""))
    lines += [""] + table(scores) + [""]
    for score in scores:
        amiss = [(task, counts) for task, counts in score["tasks"].items() if counts["notes"] or counts["who"] or counts["left"] or counts["dead"]]
        if amiss:
            lines += ["## %s: what lies behind the numbers" % name_of(score), ""]
        for task, counts in amiss:
            parts = []
            if counts["notes"]:
                parts.append("at the end: " + "; ".join(counts["notes"]))
            if counts["who"]:
                parts.append("moved untouched: " + ", ".join("%s x%d" % (owner, counts["who"].count(owner)) for owner in sorted(set(counts["who"]))))
            if counts["left"]:
                parts.append("%d left the screen untouched (hidden, minimized, another Space)" % counts["left"])
            if counts["dead"]:
                parts.append("%d acts changed nothing on the screen" % counts["dead"])
            lines.append("- %s: %s" % (task, ". ".join(parts)))
        if amiss:
            lines.append("")
    for score in scores:
        if score["remarks"]:
            lines += ["## %s: what it said" % name_of(score), ""]
            lines += ["- %s, picture %d, **%s**: %s" % (remark["task"], remark["round"], remark["verb"], remark["words"]) for remark in score["remarks"]]
            lines.append("")
    lines += ["## What a round costs, in seconds (median; the slowest)", "",
              "| with | rounds | picture | push | the newcomer, there and back | fetch | act | come to rest | not understood |", "|---|---|---|---|---|---|---|---|---|"]
    for score in scores:
        timing = score["timing"]
        cells = ["%.1f; %.1f" % (statistics.median(timing[part]), max(timing[part])) if timing.get(part) else "–"
                 for part in ("shot", "push", "thought", "fetch", "act", "settle")]
        lines.append("| %s | %d | %s | %d |" % (name_of(score), len(timing.get("act", [])), " | ".join(cells), score["nonsense"]))
    return "\n".join(lines) + "\n"


def self_test():
    def a_round(task, verb="click", **more):
        return dict({"kind": "round", "task": task, "round": 1, "verb": verb, "line": verb, "touched": ["1"], "moved": [], "gone": [], "come": [],
                     "idle_moved": [], "idle_gone": [], "cells": 500, "timing": {"act": 0.5, "pushed": True}}, **more)

    def a_run(arm, *entries):
        return tally([{"kind": "run", "arm": arm, "build": "abc", "run": "r"}] + list(entries) + [{"kind": "end", "how": "played"}])

    def a_task(task, done, how, *rounds):
        return [{"kind": "task-begin", "task": task}] + list(rounds) + [{"kind": "task-end", "task": task, "done": done, "how": how, "notes": [], "seconds": 10}]

    stranger = {"id": "2", "owner": "Notes", "from": [0, 0, 1, 1], "to": [9, 9, 1, 1]}
    mine = {"id": "1", "owner": "Safari", "from": [0, 0, 1, 1], "to": [9, 9, 1, 1]}
    plain = a_run("macos", *a_task("fill", True, "done", a_round("fill", moved=[mine])))
    cases = [
        ("the window that was touched does not count", plain["tasks"]["fill"]["untouched"], 0),
        ("another one does", a_run("arbor", *a_task("fill", True, "done", a_round("fill", moved=[mine, stranger])))["tasks"]["fill"]["untouched"], 1),
        ("nor is what moves between two rounds anybody's", a_run("arbor", *a_task("fill", True, "done", a_round("fill", idle_moved=[mine])))["tasks"]["fill"]["untouched"], 1),
        ("waiting is no act", a_run("arbor", *a_task("fill", True, "done", a_round("fill", "wait", cells=0)))["tasks"]["fill"]["acts"], 0),
        ("nor a wrong turn", a_run("arbor", *a_task("fill", True, "done", a_round("fill", "wait", cells=0)))["tasks"]["fill"]["wrong"], 0),
        ("a key that changes nothing is one", a_run("arbor", *a_task("fill", True, "done", a_round("fill", "key", cells=3)))["tasks"]["fill"]["wrong"], 1),
        ("unless the picture could not be compared", a_run("arbor", *a_task("fill", True, "done", a_round("fill", "key", cells=None)))["tasks"]["fill"]["wrong"], 0),
        ("done and the same", compare(plain["tasks"]["fill"], plain["tasks"]["fill"]), "the same"),
        ("not done where macOS alone was", compare(a_run("arbor", *a_task("fill", False, "done"))["tasks"]["fill"], plain["tasks"]["fill"]), "WORSE"),
        ("done with more acts", compare(a_run("arbor", *a_task("fill", True, "done", a_round("fill"), a_round("fill")))["tasks"]["fill"], plain["tasks"]["fill"]), "WORSE"),
        ("done with fewer", compare(a_run("arbor", *a_task("fill", True, "done"))["tasks"]["fill"], plain["tasks"]["fill"]), "BETTER"),
        ("a task macOS alone does not have", compare(plain["tasks"]["fill"], None), "a cost macOS alone does not have"),
        ("it thought so", done_word({"done": False, "how": "done"}), "NO (thought so)"),
    ]
    failed = [name for name, got, wanted in cases if got != wanted]
    for name, got, wanted in cases:
        print("%s %s%s" % ("✘" if name in failed else "✔", name, ": %r, not %r" % (got, wanted) if name in failed else ""))
    text = report([a_run("arbor", *a_task("fill", True, "done", a_round("fill", moved=[stranger]))), plain])
    for wanted in ("| one window fills the screen, and stays | Arbor abc | yes | 1 | 0 | 0 | 0 | 0 | 1 | 10 | WORSE |", "| install and start it | Arbor abc | not reached",
                   "|  | macOS alone | nothing to do | 0", "moved untouched: Notes x1"):
        if wanted not in text:
            print("✘ the report lacks: %s" % wanted)
            failed.append(wanted)
    return 1 if failed else 0


def main():
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    if not sys.argv[1:] or sys.argv[1].startswith("-"):
        print(__doc__)
        return 64
    print(report([tally(read(path)) for path in sys.argv[1:]]), end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
