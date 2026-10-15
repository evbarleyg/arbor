#!/usr/bin/env python3
"""The newcomer's score: the tasks down, what each cost across, with Arbor beside macOS alone.

    scripts/newcomer/score.py <folder or journal.jsonl>…        one for each run; fetch.sh brings them: .newcomer/<run>/
    scripts/newcomer/score.py --self-test

It reads the journals the rig kept (rig.py), which hold what the newcomer sent, what the window server's list showed before and after every
act, and the rig's verdict on each task. Nothing in it is anybody's opinion but the remarks, and those are counted, not weighed.

    done          what the windows showed at the end of the task (tasks.py), whatever the newcomer thought. "already so": it was done before the task began,
                  because a task before it had failed
    acts          clicks, drags, scrolls, moves of the pointer, texts typed, passwords, and every chord pressed. Not waiting
    wrong turns   acts after which nothing on the screen had changed (not the picture, not who has the keyboard, not the order of the windows), and the times it
                  said `wrong`; one that it said right after such an act is the same turn
    stuck, surprised, looked up      the times it said so
    moved untouched   windows whose frame changed in a round though the act did not touch them: they were not under the press or the release, and for
                  keys did not have the keyboard before or after. Each window counts once a round. What moved between two rounds or after the last act, while
                  nobody did anything, was touched by nobody. A window that moves and is back within one round is seen by the sampler alone (samples.log)
    unasked       of those, the ones the act did not even name, by the table in docs/VIABLE.md, section 6: an Arrange, a pause, a resume, Float All, Quit, undo and
                  redo name every window; any other command of Arbor's, and a drag, name the docked windows; nothing names a floating window, and nobody named what
                  moved while nothing was done. Without Arbor nothing is named
    seconds       from the task's first picture to its end. Most of it is the way through Git and the newcomer's thinking, the same for all runs

A run with Arbor is held against every run without, on what needs nobody's word: done, acts, acts that changed nothing, moved untouched. How often somebody says that
it is surprised depends on who it is, so what was said stands beside the verdict and is no part of it. Better: done, nothing counted worse and something better,
against each of them. Worse: not done, or not reached, where macOS alone did it, or everything that differs is worse. A task macOS alone does not have (installing,
quitting) is a cost. Where the two began from different places (one had less to bring back, or found the task done), they are not compared.
One run is one newcomer: a difference of an act or two is no finding.
"""

import json
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tasks  # noqa: E402
from rig import DEAD  # noqa: E402

COUNTED = ("acts", "wrong", "stuck", "surprised", "lookup", "untouched", "unasked")
JUDGED = ("acts", "dead", "untouched")
HEADS = ("done", "acts", "wrong turns", "stuck", "surprised", "looked up", "moved untouched", "unasked", "seconds")
# Commands of Arbor's that name every window (docs/VIABLE.md, section 6).
# What else its log says at that level: how it started, what it found.
NO_COMMAND = ("Arbor", "watchdog", "control", "keyboard", "started", "registered", "setup", "trace", "update", "permission", "display", "displays")
NAME_ALL = ("arrange", "pause", "resume", "float-all", "quit", "undo", "redo")
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
    return (entry["verb"] not in NO_ACT + ("move", "release") and entry.get("fine", True) and entry.get("cells") is not None and entry["cells"] <= DEAD
            and not entry["moved"] and not entry["gone"] and not entry["come"] and not entry.get("turned"))


def commands(entry):
    """The commands Arbor's log says it ran: `… INFO  dock left: docked …`."""
    found = []
    for line in entry.get("said") or []:
        words = line.split(" INFO ", 1)[1].split(":")[0].split()
        if words and words[0] not in NO_COMMAND:
            found.append(words[0])
    return found


def named(entry):
    """Which windows the act named: "all", or a set of ids."""
    ran = commands(entry)
    if any(command in NAME_ALL for command in ran):
        return "all"
    return set(entry.get("docked") or []) if ran or entry["verb"] in ("drag", "release") else set()


def tally(entries):
    """{"run": the run's own facts, "tasks": {id: counts}, "remarks": […], "timing": {part: [seconds…]}, "nonsense": n, "end": how}"""
    score = {"run": {}, "tasks": {}, "remarks": [], "timing": {}, "nonsense": 0, "end": "cut off", "left": 0}
    for entry in entries:
        kind = entry["kind"]
        if kind == "run":
            score["run"] = entry
        elif kind == "task-begin":
            score["tasks"][entry["task"]] = dict({name: 0 for name in COUNTED}, dead=0, left=0, blind=0, wallpaper=0, done=None, how="cut off", notes=[], seconds=None,
                                                 who=[], already=entry.get("already", False), away=entry.get("away", 0), helped=None, last_dead=None)
        elif kind == "nonsense":
            score["nonsense"] += 1
        elif kind == "end":
            score["end"] = entry["how"]
        elif kind == "remark":
            score["remarks"].append(entry)
            counts = score["tasks"].get(entry["task"])
            if counts and entry["verb"] == "wrong" and counts["last_dead"] in (entry["round"], entry["round"] - 1):
                counts["last_dead"] = None  # it saw for itself that nothing had happened: one turn, not two
            elif counts and entry["verb"] in counts:
                counts[entry["verb"]] += 1
        elif kind == "round":
            counts = score["tasks"][entry["task"]]
            if entry["verb"] not in NO_ACT:
                counts["acts"] += len(entry["line"].split()) - 1 if entry["verb"] == "key" else 1
            if is_dead(entry):
                counts["dead"] += 1
                counts["wrong"] += 1
                counts["last_dead"] = entry["round"]
            if entry.get("cells") is None:
                counts["blind"] += 1
            bystanders = [each for each in entry["moved"] if each["id"] not in entry["touched"]]
            strangers = bystanders + entry["idle_moved"]
            names = named(entry)
            counts["untouched"] += len(strangers)
            counts["unasked"] += len(entry["idle_moved"]) + len([each for each in bystanders if names != "all" and each["id"] not in names])
            counts["who"] += [each["owner"] for each in strangers]
            if entry["verb"] == "click" and not entry.get("pressed") and len(bystanders) >= 3:
                counts["wallpaper"] += len(bystanders)
            counts["left"] += len([each for each in entry["gone"] if each not in entry["touched"]]) + len(entry["idle_gone"])
            for part, seconds in entry["timing"].items():
                if isinstance(seconds, (int, float)) and not isinstance(seconds, bool):
                    score["timing"].setdefault(part, []).append(seconds)
        elif kind == "task-end":
            counts = score["tasks"][entry["task"]]
            counts.update(done=entry["done"], how=entry["how"], notes=entry["notes"], seconds=entry["seconds"])
            late = entry.get("idle_moved") or []
            counts["untouched"] += len(late)
            counts["unasked"] += len(late)
            counts["who"] += [each["owner"] for each in late]
            counts["left"] += len(entry.get("idle_gone") or [])
        elif kind == "helped":
            score["tasks"][entry["task"]]["helped"] = entry["how"]
    return score


def name_of(score):
    run = score["run"]
    if run.get("arm") == "macos":
        return "macOS alone"
    return "Arbor %s" % (run.get("build") or "?")[:9]


def done_word(counts):
    if counts["done"] and counts.get("already"):
        return "yes (already so)"
    if counts["done"]:
        return "yes" if counts["how"] == "done" else "yes (%s)" % {"time": "and never said so", "giveup": "and gave up"}.get(counts["how"], counts["how"])
    return "NO (%s)" % {"done": "thought so", "giveup": "gave up", "time": "out of time"}.get(counts["how"], counts["how"])


def compare(counts, base, task=""):
    """How a run with Arbor did against one run with macOS alone on one task."""
    if base is None:
        return "a cost macOS alone does not have"
    if counts is None:
        return "WORSE: not reached" if base["done"] else "neither did it"
    if counts.get("already") != base.get("already"):
        return "not comparable: one of them found it done"
    if task in ("back", "quit") and counts.get("away") != base.get("away"):
        return "not comparable: %d against %d windows to bring back" % (counts.get("away", 0), base.get("away", 0))
    if not counts["done"]:
        return "WORSE" if base["done"] else "neither did it"
    if not base["done"]:
        return "BETTER"
    less = [name for name in JUDGED if counts[name] < base[name]]
    more = [name for name in JUDGED if counts[name] > base[name]]
    if less and not more:
        return "BETTER"
    if more and not less:
        return "WORSE"
    words = {"dead": "acts that changed nothing", "untouched": "moved untouched"}
    return "the same" if not more else "mixed: less %s; more %s" % (", ".join(words.get(name, name) for name in less), ", ".join(words.get(name, name) for name in more))


def against(counts, bases, task):
    """Against every run without Arbor: a verdict only where they all give the same."""
    verdicts = [compare(counts, base["tasks"].get(task["id"]), task["id"]) for base in bases if "macos" not in task["arms"] or task["id"] in base["tasks"]]
    if not verdicts:
        return "macOS alone did not get that far"
    return verdicts[0] if len(set(verdicts)) == 1 else "it depends on the run: " + "; ".join(sorted(set(verdicts)))


def table(scores):
    bases = [score for score in scores if score["run"].get("arm") == "macos"]
    lines = ["| task | with | " + " | ".join(HEADS) + " | against macOS alone |", "|---|---|" + "---|" * (len(HEADS) + 1)]
    for task in tasks.TASKS:
        first = True
        for score in scores:
            counts = score["tasks"].get(task["id"])
            verdict = "" if score in bases or not bases else against(counts, bases, task)
            if counts is None and score["run"].get("arm") in task["arms"]:
                cells = ["not reached"] + ["–"] * (len(HEADS) - 1)
            elif counts is None:
                cells = ["nothing to do"] + ["0"] * (len(HEADS) - 1)
            else:
                cells = [done_word(counts) + (", then helped" if counts["helped"] else "")] + [str(counts[name]) for name in COUNTED]
                cells.append(str(round(counts["seconds"])) if counts["seconds"] is not None else "–")
            lines.append("| %s | %s | %s | %s |" % (task["title"] if first else "", name_of(score), " | ".join(cells), verdict))
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
        amiss = [(task, counts) for task, counts in score["tasks"].items()
                 if counts["notes"] or counts["who"] or counts["left"] or counts["dead"] or counts["helped"] or counts["blind"]]
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
            if counts["wallpaper"]:
                parts.append("%d of them after a click where no window lay: macOS sweeps the windows aside at a click on the wallpaper" % counts["wallpaper"])
            if counts["dead"]:
                parts.append("%d acts changed nothing on the screen" % counts["dead"])
            if counts["blind"]:
                parts.append("in %d rounds the pictures could not be compared" % counts["blind"])
            if counts["helped"]:
                parts.append("HELPED afterwards, so that the run could go on: %s" % counts["helped"])
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
        ("said right after it, `wrong` is the same turn", a_run("arbor", *a_task("fill", True, "done", a_round("fill", "key", cells=3), {"kind": "remark", "task": "fill", "round": 2, "verb": "wrong", "words": "w"}))["tasks"]["fill"]["wrong"], 1),
        ("said of something else, it is another", a_run("arbor", *a_task("fill", True, "done", a_round("fill", "key", cells=3), {"kind": "remark", "task": "fill", "round": 7, "verb": "wrong", "words": "w"}))["tasks"]["fill"]["wrong"], 2),
        ("a click that only gives the keyboard away is none", a_run("arbor", *a_task("fill", True, "done", a_round("fill", cells=3, turned=True)))["tasks"]["fill"]["wrong"], 0),
        ("nor is an act the Mac's tools did not take", a_run("arbor", *a_task("fill", True, "done", a_round("fill", cells=3, fine=False)))["tasks"]["fill"]["wrong"], 0),
        ("three chords are three acts", a_run("arbor", *a_task("fill", True, "done", a_round("fill", "key", line="key cmd+a cmd+b cmd+c")))["tasks"]["fill"]["acts"], 3),
        ("what moves after the last act counts", tally([{"kind": "run", "arm": "arbor"}, {"kind": "task-begin", "task": "fill"}, {"kind": "task-end", "task": "fill", "done": True, "how": "done", "notes": [], "seconds": 1, "idle_moved": [stranger]}])["tasks"]["fill"]["untouched"], 1),
        ("an Arrange names all it moves", a_run("arbor", *a_task("fill", True, "done", a_round("fill", "key", moved=[stranger], said=["05:00:00.000 INFO  arrange: 5 windows"])))["tasks"]["fill"]["unasked"], 0),
        ("and they still count as untouched", a_run("arbor", *a_task("fill", True, "done", a_round("fill", "key", moved=[stranger], said=["05:00:00.000 INFO  arrange: 5 windows"])))["tasks"]["fill"]["untouched"], 1),
        ("a dock names the docked", a_run("arbor", *a_task("fill", True, "done", a_round("fill", "key", moved=[stranger], docked=["2"], said=["05:00:00.000 INFO  dock left: docked"])))["tasks"]["fill"]["unasked"], 0),
        ("and no floating window", a_run("arbor", *a_task("fill", True, "done", a_round("fill", "key", moved=[stranger], docked=["7"], said=["05:00:00.000 INFO  dock left: docked"])))["tasks"]["fill"]["unasked"], 1),
        ("a remark more is no verdict", compare(a_run("arbor", *a_task("fill", True, "done", a_round("fill", moved=[mine]), {"kind": "remark", "task": "fill", "round": 9, "verb": "surprised", "words": "w"}))["tasks"]["fill"], plain["tasks"]["fill"]), "the same"),
        ("not reached where macOS alone did it", compare(None, plain["tasks"]["fill"]), "WORSE: not reached"),
        ("found done is not compared", compare(dict(plain["tasks"]["fill"], already=True), plain["tasks"]["fill"]), "not comparable: one of them found it done"),
        ("less to bring back is not compared", compare(dict(plain["tasks"]["fill"], away=1), dict(plain["tasks"]["fill"], away=4), "back"), "not comparable: 1 against 4 windows to bring back"),
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
    for wanted in ("| one window fills the screen, and stays | Arbor abc | yes | 1 | 0 | 0 | 0 | 0 | 1 | 1 | 10 | WORSE |", "| install and start it | Arbor abc | not reached",
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
