#!/usr/bin/env python3
"""Does a real window that is moved in steps glide, or does it stutter? Reads what probe-glide.sh brought back from a Mac. Needs no Mac.

  judge-glide.py <folder> [--seen 0.75] [--gap 2] [--off 1] [--forgive 0] [--dead 2]
  judge-glide.py --self-test

In the folder: glide.log (glide.swift's header has its grammar: every call, with what it cost and how late it began), samples.log (sampler.swift's: what the
window server's list showed, on the same clock), and if they are there cpu.log (`<act> before|after <who> <seconds of processor time>`) and pictures.txt.
An act is called <who>.<n>: an app of the cast alone, a set of them (two…, four…), or `film`, which is looked at and not judged, because taking pictures costs time.
An act's samples are those from its `act` line to the next act's, or to a second after its `done` line.

A row of the table pools the acts of one kind. Times are ms.
  kind       control (one call) or the number of steps; +size: with a change of size, set first in one call; /threads: a thread for each app
  step       what a call that moves took: mean, 95th percentile, worst.   size: the worst call that resized
  late       steps that began more than half a step after they were due, of all steps
  seen       of the places asked for, how many were ever on the window server's list.   odd: places seen there that nobody asked for
  gap        the longest time without a change of place, from the first call to the last change
  lag        of a set: the longest time between the first and the last window being seen at the same step's place
  sizes      changes of size seen beyond the one asked for: content laid out again on the way
  ended      acts that ended within --off points of the place asked for.   by: when the last of them was seen there, from the act's beginning
  app, server, glide      processor time an act cost the apps moved, the window server and the tool. 20 ms are 10 % of a core for 0.2 s

THE VERDICT. A glide (not a control) STUTTERS if fewer than --seen of the places asked for were seen, or the gap is over --gap steps and one sample, or it ended
more than --off points from where it was asked to, or its worst call took longer than the whole glide was to take. Where the app's controls end elsewhere too,
ending elsewhere is the app's manner and no stutter. A glide is DISTURBED if the sampler was blind meanwhile (its L lines), or if glide itself overslept: a step began over half
a step late although its thread had nothing else to do. That is the Mac's doing, so places not seen and gaps are not held against such a glide, and an app all of whose
glides were disturbed is not judged. An app stutters if more than --forgive of its glides ALONE do. The last two lines are made to grep for: `stutter: N of 9 apps`, and `verdict: dead` from --dead apps on, else `verdict: alive`.
Exit code 0 whatever the verdict, 2 if there is nothing to judge.
"""
import argparse
import os
import sys
from collections import defaultdict


class Journey:
    """One window in one act."""

    def __init__(self, pid, start, end):
        self.pid, self.start, self.end, self.calls = pid, start, end, []  # calls: (time, kind, step, took, error, late, x, y)


class Act:
    def __init__(self, name, time, steps, duration, order):
        self.name, self.time, self.steps, self.duration, self.order = name, time, steps, duration, order
        self.who, self.journeys, self.done, self.cpu, self.until = name.rsplit(".", 1)[0], {}, None, {}, None

    @property
    def kind(self):
        resized = any(journey.start[2:] != journey.end[2:] for journey in self.journeys.values())
        return ("control" if self.steps == 1 else str(self.steps)) + ("+size" if resized else "") + ("/threads" if self.order == "threads" else "")


def read_lines(path):
    with open(path, encoding="utf-8", errors="replace") as file:
        return [line.split() for line in file if line.strip()]


def read_acts(folder):
    acts = {}
    for words in read_lines(os.path.join(folder, "glide.log")):
        time, kind, act = float(words[0]), words[1], acts.get(words[2])
        if kind == "act":
            acts[words[2]] = Act(words[2], time, int(words[3]), float(words[4]), words[5])
        elif act is None:
            continue
        elif kind == "ask":
            numbers = [float(word) for word in words[5:13]]
            act.journeys[int(words[3])] = Journey(words[4], numbers[:4], numbers[4:])
        elif kind == "call":
            act.journeys[int(words[3])].calls.append((time, words[4], int(words[5]), float(words[6]), int(words[7]), float(words[8]), float(words[9]), float(words[10])))
        elif kind == "done":
            act.done, act.cpu["glide"] = time, float(words[3])
    found = sorted((act for act in acts.values() if act.done is not None), key=lambda act: act.time)
    for act, following in zip(found, found[1:] + [None]):
        act.until = min(act.done + 1000, following.time if following else act.done + 1000)
    cpu = os.path.join(folder, "cpu.log")
    before = {}
    for words in read_lines(cpu) if os.path.exists(cpu) else []:
        if len(words) != 4:  # a process that had gone
            continue
        if words[1] == "before":
            before[words[0], words[2]] = float(words[3])
        elif (words[0], words[2]) in before and words[0] in acts:
            who = "server" if words[2] == "server" else "app"
            acts[words[0]].cpu[who] = acts[words[0]].cpu.get(who, 0) + (float(words[3]) - before[words[0], words[2]]) * 1000
    return found


def read_samples(folder):
    """({window: [(time, x, y, w, h)]}, [(from, to) while the sampler saw nothing], its rate, its last words)"""
    frames, blind, hertz, last = defaultdict(list), [], 60.0, ""
    for words in read_lines(os.path.join(folder, "samples.log")):
        if words[1] == "W" and len(words) >= 9:
            frames[int(words[2])].append((float(words[0]), *(float(word) for word in words[5:9])))
        elif words[1] == "L":
            blind.append((float(words[0]) - float(words[2]), float(words[0])))
        elif words[1:4] == ["M", "sampler", "at"]:
            hertz = float(words[4])
        elif words[1] == "S":
            last = " ".join(words[2:])
    return frames, blind, hertz, last


def look(act, frames, blind, hertz, limits):
    """What was seen of an act: a dictionary of numbers, with "faults", the reasons for which it stutters."""
    step = act.duration / act.steps
    seen = asked = odd = sizes = late = refused = 0
    gap = off = by = 0.0
    first_seen = defaultdict(dict)
    for window, journey in act.journeys.items():
        moves = [call for call in journey.calls if call[1] == "move"]
        places = {}
        for call in moves:
            places.setdefault((call[6], call[7]), call[2])
        now = [frame for frame in frames.get(window, []) if frame[0] <= act.time][-1:] or [(act.time, *journey.start)]
        changes, met, strangers, resized = [moves[0][0]] if moves else [act.time], set(), set(), 0
        for frame in [frame for frame in frames.get(window, []) if act.time < frame[0] <= act.until]:
            if frame[3:] != now[0][3:]:
                resized += 1
            if frame[1:3] != now[0][1:3]:
                changes.append(frame[0])
                place = next((place for place in places if abs(place[0] - frame[1]) <= 0.5 and abs(place[1] - frame[2]) <= 0.5), None)
                if place is None:
                    strangers.add(frame[1:3])
                elif place not in met:
                    met.add(place)
                    first_seen[places[place]][window] = frame[0]
            now = [frame]
        sizes += max(resized - (journey.start[2:] != journey.end[2:]), 0)
        refused += max(abs(now[0][3] - journey.end[2]), abs(now[0][4] - journey.end[3])) > limits.off
        seen, asked, odd = seen + len(met), asked + len(places), odd + len(strangers)
        # Nothing was ever seen to move: it stood still for as long as anybody looked.
        gap = max([gap] + [later - earlier for earlier, later in zip(changes, changes[1:])] + ([act.until - changes[0]] if len(changes) == 1 else []))
        off = max(off, abs(now[0][1] - journey.end[0]), abs(now[0][2] - journey.end[1]))
        by = max(by, changes[-1] - act.time)
        late += sum(call[5] > step / 2 for call in moves if act.steps > 1)
    calls = [call for journey in act.journeys.values() for call in journey.calls]
    # A step that began late although the thread that makes it had nothing else to do: the tool overslept, and no app kept it.
    overslept = 0.0
    for lane in {journey.pid if act.order == "threads" else "" for journey in act.journeys.values()}:
        free = 0.0
        for call in sorted(call for journey in act.journeys.values() if lane in ("", journey.pid) for call in journey.calls if call[1] == "move"):
            overslept = max(overslept, call[0] - max(call[0] - call[5], free))
            free = call[0] + call[3]
    lags = [max(times.values()) - min(times.values()) for times in first_seen.values() if len(times) == len(act.journeys)]
    found = {"took": [call[3] for call in calls if call[1] == "move"], "size": max([call[3] for call in calls if call[1] == "size"], default=0),
             "late": late, "seen": seen, "asked": asked, "odd": odd, "gap": gap, "lag": max(lags, default=0), "sizes": sizes, "refused": refused, "off": off, "by": by,
             "errors": sum(call[4] != 0 for call in calls), "blind": any(start < act.done + 50 and end > act.time for start, end in blind) or overslept > step / 2,
             "end_unseen": any(start < act.until <= end for start, end in blind), "faults": []}
    if act.steps > 1:
        allowed = limits.gap * step + 1000 / hertz
        if seen < limits.seen * asked and not found["blind"]:
            found["faults"].append(f"only {seen} of {asked} places were seen")
        if gap > allowed and not found["blind"]:
            found["faults"].append(f"it stood still for {gap:.0f} ms (allowed: {allowed:.0f})")
        if max((call[3] for call in calls), default=0) > act.duration:
            found["faults"].append(f"a call took {max(call[3] for call in calls):.0f} ms, longer than the whole glide")
    return found


def percentile(values, share):
    ordered = sorted(values)
    return ordered[max(-(-len(ordered) * share // 100) - 1, 0)] if ordered else 0


def judge(folder, limits, out=print):
    """Prints the tables and the verdict. Returns (apps that stutter, apps judged)."""
    acts = read_acts(folder)
    frames, blind, hertz, last = read_samples(folder)
    looks = {act.name: look(act, frames, blind, hertz, limits) for act in acts}
    cast = []
    for act in acts:
        if act.who not in cast:
            cast.append(act.who)
    out(f"{len(acts)} acts; the sampler ran at {hertz:.0f} Hz" + (f" ({last})" if last else "") + f"; it was blind {len(blind)} times")
    head = f"{'who':<10}{'kind':<17}{'acts':>4} {'step: mean':>10}{'p95':>7}{'worst':>7}{'size':>7}{'late':>8}{'seen':>9}{'odd':>4}{'gap':>6}{'lag':>6}{'sizes':>6}{'ended':>7}{'by':>6}{'app':>6}{'server':>7}{'glide':>6}"
    verdicts = {}
    for who in cast:
        mine = [act for act in acts if act.who == who]
        out("")
        out(head)
        for kind in dict.fromkeys(act.kind for act in mine):
            group = [act for act in mine if act.kind == kind]
            rows = [looks[act.name] for act in group]
            took = [value for row in rows for value in row["took"]]
            cpu = [sum(act.cpu.get(part, 0) for act in group) / len(group) for part in ("app", "server", "glide")]
            out(f"{who:<10}{kind:<17}{len(group):>4} {sum(took) / max(len(took), 1):>10.1f}{percentile(took, 95):>7.1f}{max(took, default=0):>7.1f}"
                f"{max(row['size'] for row in rows):>7.1f}{sum(row['late'] for row in rows):>4}/{len(took):<3}{sum(row['seen'] for row in rows):>5}/{sum(row['asked'] for row in rows):<3}"
                f"{sum(row['odd'] for row in rows):>4}{max(row['gap'] for row in rows):>6.0f}{max(row['lag'] for row in rows):>6.0f}{sum(row['sizes'] for row in rows):>6}"
                f"{sum(row['off'] <= limits.off for row in rows):>4}/{len(rows):<2}{max(row['by'] for row in rows):>6.0f}{cpu[0]:>6.0f}{cpu[1]:>7.0f}{cpu[2]:>6.0f}")
        errors = sum(looks[act.name]["errors"] for act in mine)
        if errors:
            out(f"  {errors} calls came back with an AXError")
        refused = sum(looks[act.name]["refused"] for act in mine)
        if refused:
            out(f"  {refused} times a window ended with another size than asked for: the app's own limits, and no stutter")
        # The control says what the app does with ONE call. What it does then too is not the steps' doing.
        controls = [looks[act.name]["off"] for act in mine if act.steps == 1]
        placeable = not controls or min(controls) <= limits.off
        glides = [act for act in mine if act.steps > 1]
        unseen = sum(looks[act.name]["blind"] for act in glides)
        for act in glides:
            if looks[act.name]["off"] > limits.off and placeable and not looks[act.name]["end_unseen"]:
                looks[act.name]["faults"].append(f"it ended {looks[act.name]['off']:.0f} points from where it was asked to")
        bad = [act for act in glides if looks[act.name]["faults"]]
        word = "STUTTERS" if len(bad) > limits.forgive else "smooth"
        if who == "film" or (word == "smooth" and unseen == len(glides)):
            word = "not judged"
        verdicts[who] = (word, len({window for act in mine for window in act.journeys}), len(bad))
        out(f"  {who}: {word}" + (f", {len(bad)} of {len(glides)} glides at fault" if glides else "") + (f"; {unseen} were disturbed" if unseen else "")
            + ("" if placeable else "; its controls end elsewhere than asked too, so that is not held against the steps"))
        spent = [sum(act.cpu.get(part, 0) for act in glides) * 100 / max(sum(act.duration for act in glides), 1) for part in ("app", "server", "glide")]
        out(f"    of a core, over its glides: the app{'s' if verdicts[who][1] > 1 else ''} {spent[0]:.0f} %, the window server {spent[1]:.0f} %, glide {spent[2]:.0f} %")
        for act in bad[:4]:
            out(f"    {act.name} ({act.kind}): " + "; ".join(looks[act.name]["faults"]))
    pictures = os.path.join(folder, "pictures.txt")
    if os.path.exists(pictures):
        out("")
        out("How long ScreenCaptureKit takes (picture-time.swift's header has the grammar):")
        for words in read_lines(pictures):
            out("  " + " ".join(words))
    # An app alone is one window; a set has its line above and no vote.
    apps = {who: word for who, (word, windows, _) in verdicts.items() if windows == 1 and word != "not judged"}
    stutter = sorted(who for who, word in apps.items() if word == "STUTTERS")
    out("")
    out(f"limits: seen {limits.seen}, gap {limits.gap} steps and a sample, off {limits.off} pt, forgive {limits.forgive}, dead from {limits.dead} apps")
    out("stutters: " + (" ".join(stutter) or "none") + "; sets: " + (", ".join(f"{who} {word}" for who, (word, windows, _) in verdicts.items() if windows > 1) or "none"))
    out(f"were each app forgiven one glide more: {sum(verdicts[who][2] > limits.forgive + 1 for who in apps)} of {len(apps)} apps")
    out(f"stutter: {len(stutter)} of {len(apps)} apps")
    out("verdict: " + ("dead" if len(stutter) >= limits.dead else "alive"))
    return stutter, sorted(apps)


def parse(arguments):
    parser = argparse.ArgumentParser(usage="judge-glide.py <folder> [--seen 0.75] [--gap 2] [--off 1] [--forgive 0] [--dead 2] | --self-test   (its header says more)")
    parser.add_argument("folder")
    parser.add_argument("--seen", type=float, default=0.75)
    parser.add_argument("--gap", type=float, default=2)
    parser.add_argument("--off", type=float, default=1)
    parser.add_argument("--forgive", type=int, default=0)
    parser.add_argument("--dead", type=int, default=2)
    return parser.parse_args(arguments)


# MARK: The self-test

def make_up(folder, cast, blind=()):
    """Logs as a Mac would leave them. cast: {name: manner}; each app plays a control and two glides, and the sampler looks 120 times a second.
    Manners: smooth; late (60 ms a call); slow (one call of 250 ms); elsewhere (20 points off a moment after the end); never (so after its control too);
    skips (the window server shows every third place); overslept (not the app: the tool begins a step 60 ms late)."""
    log, shown, clock = [], defaultdict(list), 1_000_000.0
    for index, (name, manner) in enumerate(cast.items()):
        window, place = 100 + index, (60.0, 80.0)
        shown[window].append((clock - 500, place))
        for number, steps in enumerate((1, 8, 12), 1):
            act, duration, goal = f"{name}.{number}", 0 if steps == 1 else 200, (540.0, 220.0) if place[0] == 60 else (60.0, 80.0)
            log.append(f"{clock:.2f} act {act} {steps} {duration} by-window")
            log.append(f"{clock:.2f} ask {act} {window} 7 {place[0]:.0f} {place[1]:.0f} 700 500 {goal[0]:.0f} {goal[1]:.0f} 700 500")
            free = clock
            for step in range(1, steps + 1):
                due = clock + duration * step / steps
                began = max(due, free) + (60 if manner == "overslept" and step == 4 else 0)
                took = {"late": 60.0}.get(manner, 1.0) if not (manner == "slow" and step == 3) else 250.0
                at = tuple(round(place[axis] + (goal[axis] - place[axis]) * step / steps) for axis in (0, 1))
                log.append(f"{began:.2f} call {act} {window} move {step} {took:.2f} 0 {began - due:.2f} {at[0]} {at[1]}")
                free = began + took
                if manner != "skips" or step % 3 == 0 or step == steps:
                    shown[window].append((free, at))
            if manner == "never" or (manner == "elsewhere" and steps > 1):
                shown[window].append((free + 30, (goal[0] + 20, goal[1])))
            log.append(f"{free:.2f} done {act} 5.00")
            place, clock = goal, free + 600
    samples = ["999000 M sampler at 120 Hz"] + [f"{end:.0f} L {end - start:.0f}" for start, end in blind]
    for window, places in shown.items():
        last = None
        for tick in range(int((clock - 999_000) * 120 / 1000)):
            time = 999_000 + tick * 1000 / 120
            now = [place for since, place in places if since <= time][-1:]
            if now and now[0] != last and not any(start < time < end for start, end in blind):
                last = now[0]
                samples.append(f"{time:.0f} W {window} 7 0 {last[0]:.0f} {last[1]:.0f} 700 500 App")
    for name, lines in (("glide.log", log), ("samples.log", sorted(samples, key=lambda line: float(line.split()[0])))):
        with open(os.path.join(folder, name), "w", encoding="utf-8") as file:
            file.write("\n".join(lines) + "\n")


def self_test():
    import tempfile
    failures = []

    def expect(what, cast, stutter, verdict, options=(), blind=()):
        with tempfile.TemporaryDirectory() as folder:
            make_up(folder, cast, blind)
            said = []
            found, judged = judge(folder, parse([folder, *options]), said.append)
            if found != sorted(stutter) or said[-1] != f"verdict: {verdict}" or said[-2] != f"stutter: {len(stutter)} of {len(judged)} apps":
                failures.append(f"{what}: {found}, {said[-2]}, {said[-1]}\n" + "\n".join(said))

    expect("smooth apps", {"a": "smooth", "b": "smooth"}, [], "alive")
    expect("one that answers late", {"a": "smooth", "b": "late"}, ["b"], "alive")
    expect("one call longer than the glide", {"a": "slow"}, ["a"], "alive")
    expect("one that ends elsewhere", {"a": "elsewhere", "b": "smooth"}, ["a"], "alive")
    expect("one that skips places", {"a": "skips", "b": "smooth"}, ["a"], "alive")
    expect("two of them: dead", {"a": "skips", "b": "smooth", "c": "late"}, ["a", "c"], "dead")
    expect("the number of apps that kills can be set", {"a": "skips", "b": "late"}, ["a", "b"], "alive", ["--dead", "3"])
    expect("the limits can be set", {"a": "skips", "b": "late"}, [], "alive", ["--gap", "9", "--seen", "0.2"])
    expect("so can how far off is off", {"a": "elsewhere"}, [], "alive", ["--off", "25"])
    expect("and how many glides are forgiven", {"a": "late"}, [], "alive", ["--forgive", "2"])
    expect("what the control does too is not the steps' doing", {"a": "never"}, [], "alive")
    expect("a glide the sampler did not see is not judged", {"a": "smooth"}, [], "alive", blind=[(1_000_500.0, 1_003_000.0)])
    expect("nor one in which the tool overslept", {"a": "overslept"}, [], "alive")
    expect("but where it ended is seen all the same", {"a": "elsewhere"}, ["a"], "alive", blind=[(1_000_500.0, 1_000_700.0), (1_001_300.0, 1_001_500.0)])
    with tempfile.TemporaryDirectory() as folder:
        if main([folder]) != 2:
            failures.append("an empty folder must come out as 2")
    for failure in failures:
        print(f"✘ judge-glide.py self-test: {failure}")
    if failures:
        sys.exit(1)
    print("judge-glide.py: its self-test passes")


def main(arguments):
    if arguments == ["--self-test"]:
        return self_test()
    limits = parse(arguments)
    try:
        _, judged = judge(limits.folder, limits)
    except (OSError, ValueError, IndexError, KeyError) as problem:
        print(f"judge-glide.py: cannot read the logs in {limits.folder}: {problem!r}", file=sys.stderr)
        return 2
    return 0 if judged else 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
