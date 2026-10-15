#!/usr/bin/env python3
"""Does a real window whose frame is set once for every frame of the display glide as macOS's own tiling does, or does it stutter?
Reads what probe-glide.sh brought back from a Mac. Needs no Mac.

  judge-glide.py <folder> [--seen 0.88] [--gap 2] [--no-bar] [--wrong 0] [--off 1] [--over 1.25] [--forgive 0] [--dead 2] [--blind 0]
  judge-glide.py --self-test

In the folder: glide.log (glide.swift's header has its grammar: every asking, with what it cost and how late it began), samples.log (sampler.swift's: what the
window server's list showed, on the same clock), and if they are there cpu.log (`<act> before|after <who> <seconds of processor time>`) and pictures.txt.
An act is called <who>.<n>: an app of the cast alone, a pair of them, or `film`, which is looked at and not judged, because taking pictures costs time.
An act's samples are those from its `act` line to the next act's, or to a second after its `done` line.

A row of the tables pools the acts of one kind on one kind of road, there and back. Times are ms, lengths points.
  kind       control (set once) or the number of steps, with the order of the two askings; macos: the bar, macOS's own tiling of the same window
  road       all edges (every edge moves), far stand (the right and bottom edges are to stand still while the left one moves), place only
  asking     what one asking took: mean, 95th percentile, worst.   late: steps that began more than half a step after they were due
  reached    of the frames asked for, how many were ever on the window server's list, all four edges at once. Of the bar: how many frames were seen at all
  gap        the longest time without a change, from the first asking to the last change
  step       EDGES OUT OF STEP: how far the worst state seen was from the nearest frame asked for, by its worst edge
  wrong      WRONG STATES: states seen with an edge over a point beyond both ends of its road; one that is to stand still has a road of no length.   by: by how much, at worst
  outw       of that, outwards: how far an edge lay outside the two frames together, over whatever is beside the window. The rest gave way inwards
  off        how far from the frame asked for the window ended, by its worst edge.   took: from the act's beginning to the last change seen (of the bar: from the first)
  jump       of a pair: when the window that is set once was seen at its end
  app, server, glide      processor time an act cost the apps, the window server and the tool. 30 ms are 10 % of a core for 0.3 s

THE VERDICT goes by macOS's own glide. Counted from films of five of them on one hosted Mac: 16 to 18 frames in 283 to 317 ms, four edges in step, never past the end, and in four of the
five one to three waits of 33 ms, once of 50: it does skip frames, and part of that is the hosted Mac's. A glide (not a control) STUTTERS if fewer than --seen of the frames asked
for were reached; or the gap is over --gap steps and one sample, OR OVER THE LONGEST GAP OF THE BAR ON THE SAME WINDOW IN THE SAME RUN and one sample, whichever is more (a line says when that raised it; --no-bar: --gap alone); or more than --wrong wrong states were seen; or it ended more than --off from the frame asked for; or it took over
--over times as long as it was to; or one asking took longer than the whole glide was to. An app whose CONTROLS end with another size than asked for has its own mind about sizes
(one size only, whole character cells): it is judged by its left and top edges alone. Where the controls end elsewhere too, ending elsewhere is no stutter.
A glide is DISTURBED if the sampler was blind meanwhile (its L lines, those of --blind ms and more), or if glide itself overslept: a step began over half a step late although its
thread had nothing else to do. That is the Mac's doing, so frames not reached, gaps and time are not held against such a glide, and an app all of whose glides were disturbed is not
judged. ONLY GLIDES OF ONE WINDOW ALONE IN THE ORDER by-edges HAVE A VOTE: the other orders are there to be compared with. An app stutters if more than --forgive of them do.
THE BAR IS THE CONTROL OF THE VERDICT: macOS's own glides in the folder are held to the same rule, by --gap alone and 18 frames in 300 ms, and a line says how many of them stutter by it. A rule that
macOS fails is too hard, or the sampler sees less of macOS's glide than of Arbor's. A bar that was disturbed raises no limit. Without a bar a line says that the verdict has no control.
The sampler looks twice as often as the display shows, so it sees about twice the wrong states a person could.
The last two lines are made to grep for: `stutter: N of 9 apps`, and `verdict: dead` from --dead apps on, else `verdict: alive`.
Exit code 0 whatever the verdict, 2 if there is nothing to judge.
"""
import argparse
import os
import sys
from collections import defaultdict


class Journey:
    """One window in one act. Frames are (x, y, w, h); calls are (time, kind, step, took, error, late, frame)."""

    def __init__(self, pid, glides, start, end):
        self.pid, self.glides, self.start, self.end, self.calls = pid, glides, start, end, []


class Act:
    def __init__(self, name, time, steps, duration, order):
        self.name, self.time, self.steps, self.duration, self.order = name, time, steps, duration, order
        self.who, self.journeys, self.done, self.cpu, self.until = name.rsplit(".", 1)[0], {}, None, {}, None

    @property
    def glider(self):
        return next(journey for journey in self.journeys.values() if journey.glides)

    @property
    def kind(self):
        return "macos" if self.order == "macos" else ("control" if self.steps == 1 else str(self.steps)) + " " + self.order

    @property
    def road(self):
        start, end = edges(self.glider.start), edges(self.glider.end)
        return "place only" if self.glider.start[2:] == self.glider.end[2:] else "far stand" if start[2:] == end[2:] else "all edges"

    @property
    def votes(self):
        return self.steps > 1 and self.order == "by-edges" and len(self.journeys) == 1 and self.who != "film"


def edges(frame):
    return (frame[0], frame[1], frame[0] + frame[2], frame[1] + frame[3])


def apart(one, other, count=4):
    """How far two frames are apart, by their worst edge. count=2: by the left and top edges alone."""
    return max(abs(a - b) for a, b in list(zip(edges(one), edges(other)))[:count])


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
            numbers = tuple(float(word) for word in words[6:14])
            act.journeys[int(words[3])] = Journey(words[4], words[5] == "glides", numbers[:4], numbers[4:])
        elif kind == "call":
            act.journeys[int(words[3])].calls.append((time, words[4], int(words[5]), float(words[6]), int(words[7]), float(words[8]), tuple(float(word) for word in words[9:13])))
        elif kind == "done":
            act.done, act.cpu["glide"] = time, float(words[3])
    found = sorted((act for act in acts.values() if act.done is not None and act.journeys), key=lambda act: act.time)
    for act, following in zip(found, found[1:] + [None]):
        act.until = min(act.done + 1000, following.time if following else act.done + 1000)
    cpu, before = os.path.join(folder, "cpu.log"), {}
    for words in read_lines(cpu) if os.path.exists(cpu) else []:
        if len(words) != 4:  # a process that had gone
            continue
        if words[1] == "before":
            before[words[0], words[2]] = float(words[3])
        elif (words[0], words[2]) in before and words[0] in acts:
            who = "server" if words[2] == "server" else "app"
            acts[words[0]].cpu[who] = acts[words[0]].cpu.get(who, 0) + (float(words[3]) - before[words[0], words[2]]) * 1000
    return found


def read_samples(folder, least=0):
    """({window: [(time, frame)]}, [(from, to) while the sampler saw nothing], its rate, its last words)"""
    frames, blind, hertz, last = defaultdict(list), [], 60.0, ""
    for words in read_lines(os.path.join(folder, "samples.log")):
        if words[1] == "W" and len(words) >= 9:
            frames[int(words[2])].append((float(words[0]), tuple(float(word) for word in words[5:9])))
        elif words[1] == "L" and float(words[2]) >= least:
            blind.append((float(words[0]) - float(words[2]), float(words[0])))
        elif words[1:4] == ["M", "sampler", "at"]:
            hertz = float(words[4])
        elif words[1] == "S":
            last = " ".join(words[2:])
    return frames, blind, hertz, last


def look(act, frames, blind, hertz, limits, count=4, still=0):
    """What was seen of an act: a dictionary of numbers, with "faults", the reasons for which it stutters. count=2: only the left and top edges are looked at.
    still: it may stand still for that many ms, if that is more than the limits allow. The bar is held to what is asked of the glides: 18 frames in 300 ms."""
    steps, duration = (act.steps, act.duration) if act.steps else (18, 300.0)
    step = duration / steps
    found = {"wrong": 0, "beyond": 0.0, "outwards": 0.0, "out": 0.0, "off": 0.0, "size_off": 0.0, "jump": 0.0, "faults": []}
    for window, journey in act.journeys.items():
        states = [state for state in frames.get(window, []) if act.time < state[0] <= act.until]
        asked = {call[2]: call[6] for call in journey.calls}
        for _, frame in states:
            beyond = max(max(min(a, b) - edge, edge - max(a, b), 0) for a, b, edge in list(zip(edges(journey.start), edges(journey.end), edges(frame)))[:count])
            found["wrong"] += beyond > 1
            found["beyond"] = max(found["beyond"], beyond)
            hull = [(min, -1), (min, -1), (max, 1), (max, 1)]
            found["outwards"] = max([found["outwards"]] + [(edge - pick(a, b)) * sign for (pick, sign), a, b, edge in list(zip(hull, edges(journey.start), edges(journey.end), edges(frame)))[:count]])
            if asked:
                found["out"] = max(found["out"], min(apart(frame, other, count) for other in [journey.start, *asked.values()]))
        end = (states or [state for state in frames.get(window, []) if state[0] <= act.time] or [(act.time, journey.start)])[-1][1]
        found["off"] = max(found["off"], apart(end, journey.end, count))
        found["size_off"] = max(found["size_off"], abs(end[2] - journey.end[2]), abs(end[3] - journey.end[3]))
        if not journey.glides:
            found["jump"] = max([found["jump"]] + [time - act.time for time, frame in states if apart(frame, journey.end, count) <= limits.off][:1])
            continue
        distinct = set(asked.values())
        found["asked"] = len(distinct)
        found["reached"] = sum(any(apart(frame, other, count) <= 0.5 for _, frame in states) for other in distinct) if asked else len({frame for _, frame in states})
        changes = ([min(call[0] for call in journey.calls)] if journey.calls else []) + [time for time, _ in states]
        # Nothing was ever seen to move: it stood still for as long as anybody looked.
        found["gap"] = max([later - earlier for earlier, later in zip(changes, changes[1:])] or [act.until - act.time])
        found["took"] = changes[-1] - (act.time if journey.calls else changes[0]) if changes else 0
        firsts = {}
        for call in sorted(journey.calls):
            firsts.setdefault(call[2], call[5])
        found["late"] = sum(late > step / 2 for late in firsts.values()) if act.steps > 1 else 0
    calls = [call for journey in act.journeys.values() for call in journey.calls]
    # A step that began late although the thread that makes it had nothing else to do: the tool overslept, and no app kept it.
    overslept, free = 0.0, 0.0
    for call in sorted(act.glider.calls):
        overslept = max(overslept, call[0] - max(call[0] - call[5], free))
        free = call[0] + call[3]
    found.update(calls=[call[3] for call in calls], errors=sum(call[4] != 0 for call in calls),
                 disturbed=any(start < act.done + 50 and end > act.time for start, end in blind) or overslept > step / 2,
                 end_unseen=any(start < act.until <= end for start, end in blind))
    if steps > 1:
        allowed = max(limits.gap * step + 1000 / hertz, still)
        if found["reached"] < limits.seen * (found["asked"] or steps) and not found["disturbed"]:
            found["faults"].append(f"only {found['reached']} of {found['asked'] or steps} frames were reached")
        if found["gap"] > allowed and not found["disturbed"]:
            found["faults"].append(f"it stood still for {found['gap']:.0f} ms (allowed: {allowed:.0f})")
        if found["took"] > limits.over * duration and not found["disturbed"]:
            found["faults"].append(f"it took {found['took']:.0f} ms (allowed: {limits.over * duration:.0f})")
        if found["wrong"] > limits.wrong:
            found["faults"].append(f"{found['wrong']} wrong states were seen, an edge up to {found['beyond']:.0f} points off its road")
        if max(found["calls"], default=0) > duration:
            found["faults"].append(f"an asking took {max(found['calls']):.0f} ms, longer than the whole glide")
    return found


def percentile(values, share):
    ordered = sorted(values)
    return ordered[max(-(-len(ordered) * share // 100) - 1, 0)] if ordered else 0


HEAD = (f"{'who':<10}{'kind':<20}{'road':<11}{'acts':>4} {'asking: mean':>12}{'p95':>7}{'worst':>7}{'late':>5}{'reached':>9}{'gap':>5}{'step':>6}{'wrong':>6}{'by':>5}{'outw':>5}{'off':>5}{'took':>6}"
        f"{'jump':>6}{'app':>5}{'server':>7}{'glide':>6}")


def row(who, kind, road, group, rows):
    took = [value for each in rows for value in each["calls"]]
    cpu = [sum(act.cpu.get(part, 0) for act in group) / len(group) for part in ("app", "server", "glide")]
    return (f"{who:<10}{kind:<20}{road:<11}{len(group):>4} {sum(took) / max(len(took), 1):>12.1f}{percentile(took, 95):>7.1f}{max(took, default=0):>7.1f}{sum(each['late'] for each in rows):>5}"
            f"{sum(each['reached'] for each in rows):>5}/{sum(each['asked'] for each in rows):<3}{max(each['gap'] for each in rows):>5.0f}{max(each['out'] for each in rows):>6.0f}"
            f"{sum(each['wrong'] for each in rows):>6}{max(each['beyond'] for each in rows):>5.0f}{max(each['outwards'] for each in rows):>5.0f}{max(each['off'] for each in rows):>5.0f}{max(each['took'] for each in rows):>6.0f}"
            f"{max(each['jump'] for each in rows):>6.0f}{cpu[0]:>5.0f}{cpu[1]:>7.0f}{cpu[2]:>6.0f}")


def judge(folder, limits, out=print):
    """Prints the tables and the verdict. Returns (apps that stutter, apps judged)."""
    acts = read_acts(folder)
    frames, blind, hertz, last = read_samples(folder, limits.blind)
    out(f"{len(acts)} acts; the sampler ran at {hertz:.0f} Hz" + (f" ({last})" if last else "") + f"; it was blind {len(blind)} times")
    verdicts, summary, roads = {}, [], defaultdict(lambda: [0, 0])
    # THE CONTROL OF THE VERDICT: macOS's own glides of the same windows, in the same run, seen by the same sampler, held to the same rule.
    bars = {act.name: look(act, frames, blind, hertz, limits) for act in acts if act.order == "macos"}
    plain = limits.gap * 300 / 18 + 1000 / hertz
    for who in dict.fromkeys(act.who for act in acts):
        mine = [act for act in acts if act.who == who]
        # Of the same window, not of the whole run: one slow app's bar would excuse all the others.
        still = 0 if limits.no_bar else max([bars[act.name]["gap"] + 1000 / hertz for act in mine if act.name in bars and not bars[act.name]["disturbed"]], default=0)
        # The control says what the app does when it is asked ONCE. What it does then too is not the steps' doing.
        controls = [look(act, frames, blind, hertz, limits) for act in mine if act.steps == 1]
        wilful = bool(controls) and min(control["size_off"] for control in controls) > limits.off
        looks = {act.name: look(act, frames, blind, hertz, limits, 2 if wilful else 4, still) for act in mine}
        placeable = not controls or min(looks[act.name]["off"] for act in mine if act.steps == 1) <= limits.off
        out("")
        out(HEAD)
        for kind, road in dict.fromkeys((act.kind, act.road) for act in mine):
            group = [act for act in mine if (act.kind, act.road) == (kind, road)]
            out(row(who, kind, road, group, [looks[act.name] for act in group]))
        errors = sum(looks[act.name]["errors"] for act in mine)
        if errors:
            out(f"  {errors} askings came back with an AXError")
        if still > plain:
            out(f"  macOS's own glide of this window stood still for {still - 1000 / hertz:.0f} ms: so may its glides, and one sample ({still:.0f} ms, not {plain:.0f}). --no-bar goes by --gap alone")
        if wilful:
            out("  its controls end with another size than asked for: it is judged by its left and top edges alone")
        if not placeable:
            out("  its controls end elsewhere than asked too: that is not held against the steps")
        for act in mine:
            if act.steps > 1 and looks[act.name]["off"] > limits.off and placeable and not looks[act.name]["end_unseen"]:
                looks[act.name]["faults"].append(f"it ended {looks[act.name]['off']:.0f} points from the frame it was asked for")
        voters = [act for act in mine if act.votes]
        if not voters:
            continue
        bad = [act for act in voters if looks[act.name]["faults"]]
        disturbed = sum(looks[act.name]["disturbed"] for act in voters)
        word = "STUTTERS" if len(bad) > limits.forgive else "not judged" if disturbed == len(voters) else "smooth"
        verdicts[who] = (word, len(bad))
        out(f"  {who}: {word}, {len(bad)} of {len(voters)} glides at fault" + (f"; {disturbed} were disturbed" if disturbed else ""))
        for act in bad[:5]:
            out(f"    {act.name} ({act.kind}, {act.road}): " + "; ".join(looks[act.name]["faults"]))
        for road in dict.fromkeys(act.road for act in voters):
            roads[road][0] += any(act.road == road for act in bad)
            roads[road][1] += 1
        whole = [act for act in voters if act.road != "place only"] or voters
        seen = [looks[act.name] for act in whole]
        share = [sum(act.cpu.get(part, 0) for act in whole) * 100 / sum(act.duration for act in whole) for part in ("app", "server", "glide")]
        worst = min(seen, key=lambda each: each["reached"] / max(each["asked"], 1))
        summary.append(f"{who:<12}{worst['reached']:>4} of {worst['asked']:<4}{max(each['gap'] for each in seen):>6.0f}{max(each['out'] for each in seen):>13.0f}{sum(each['wrong'] for each in seen):>8}"
                       f"{max(each['off'] for each in seen):>10.0f}{max(each['took'] for each in seen):>7.0f}{share[0]:>7.0f} %{share[1]:>7.0f} %{share[2]:>6.0f} %   {word:<12}"
                       + "".join(f"{bar['reached']:>7}{bar['gap']:>5.0f}{bar['wrong']:>7}{bar['took']:>6.0f}" for bar in [looks[act.name] for act in mine if act.order == "macos"][:1]))
    out("")
    out("Each app's glides in the order by-edges, place and size at every step: the worst of them, wrong states in all; of a core, over the time they were to take. Beside it THE BAR, on the same window")
    out(f"{'':<12}{'reached':>11}{'gap':>7}{'out of step':>13}{'wrong':>8}{'ends off':>10}{'took':>7}{'app':>9}{'server':>9}{'glide':>8}{'':<15}{'macOS: seen':>7}{'gap':>5}{'wrong':>7}{'took':>6}")
    for line in summary:
        out(line)
    pictures = os.path.join(folder, "pictures.txt")
    if os.path.exists(pictures):
        out("")
        out("How long ScreenCaptureKit takes (picture-time.swift's header has the grammar):")
        for words in read_lines(pictures):
            out("  " + " ".join(words))
    apps = {who: word for who, (word, _) in verdicts.items() if word != "not judged"}
    stutter = sorted(who for who, word in apps.items() if word == "STUTTERS")
    out("")
    out(f"limits: seen {limits.seen}, gap {limits.gap} steps and a sample, wrong {limits.wrong}, off {limits.off}, over {limits.over}, forgive {limits.forgive}, dead from {limits.dead} apps")
    if bars:
        out(f"the bar: {sum(bool(bar['faults']) for bar in bars.values())} of {len(bars)} of macOS's own glides stutter by this rule")
        for name, bar in [(name, bar) for name, bar in bars.items() if bar["faults"]][:9]:
            out(f"    {name}: " + "; ".join(bar["faults"]))
    else:
        out("the verdict has no control: there is no glide of macOS's own in the folder, so nobody knows whether macOS itself would pass on that Mac")
    out("stutters: " + (" ".join(stutter) or "none") + "".join(f"; not judged: {who}" for who, (word, _) in verdicts.items() if word == "not judged"))
    out("apps with a glide at fault, road by road: " + ", ".join(f"{road} {bad} of {count}" for road, (bad, count) in roads.items()))
    out(f"were each app forgiven one glide more: {sum(verdicts[who][1] > limits.forgive + 1 for who in apps)} of {len(apps)} apps")
    out(f"stutter: {len(stutter)} of {len(apps)} apps")
    out("verdict: " + ("dead" if len(stutter) >= limits.dead else "alive"))
    return stutter, sorted(apps)


def parse(arguments):
    parser = argparse.ArgumentParser(usage="judge-glide.py <folder> [--seen 0.88] [--gap 2] [--no-bar] [--wrong 0] [--off 1] [--over 1.25] [--forgive 0] [--dead 2] [--blind 0] | --self-test   (its header says more)")
    parser.add_argument("folder")
    for name, kind, value in (("seen", float, 0.88), ("gap", float, 2), ("wrong", int, 0), ("off", float, 1), ("over", float, 1.25), ("forgive", int, 0), ("dead", int, 2), ("blind", float, 0)):
        parser.add_argument(f"--{name}", type=kind, default=value)
    parser.add_argument("--no-bar", action="store_true")
    return parser.parse_args(arguments)


# MARK: The self-test

def make_up(folder, cast, blind=(), bar=None):
    """Logs as a Mac would leave them. cast: {name: manner}. Each app plays a control and two glides of 18 steps in 300 ms in which its left edge moves and its right edge is to stand
    still, and the sampler looks 120 times a second. Manners: smooth (both askings show at once); torn (the second asking takes 10 ms, and what lies between shows); late (20 ms an
    asking); slow (one asking of 350 ms); elsewhere (20 points off a moment after the end); never (so after its control too); skips (the window server shows every third frame);
    fixed (it keeps its size, whatever is asked); silent (it answers nothing within the second it is given, and glide asks it no more); overslept (not the app: the tool begins a step 60 ms late); a number (one asking takes so long that the window stands still for that
    many ms). bar: macOS's own glide of the last window, 18 frames with one wait of that many ms."""
    log, shown, clock = [], defaultdict(list), 1_000_000.0
    text = lambda frame: " ".join(f"{number:.0f}" for number in frame)  # noqa: E731
    for index, (name, manner) in enumerate(cast.items()):
        window, frame = 100 + index, (640.0, 80.0, 560.0, 400.0)
        shown[window].append((clock - 500, frame))
        for number, steps in enumerate((1, 18, 18), 1):
            act, duration, goal = f"{name}.{number}", 0 if steps == 1 else 300, (240.0, 80.0, 960.0, 400.0) if frame[0] == 640 else (640.0, 80.0, 560.0, 400.0)
            log.append(f"{clock:.2f} act {act} {steps} {duration} {'place-first' if steps == 1 else 'by-edges'}")
            log.append(f"{clock:.2f} ask {act} {window} 7 glides {text(frame)} {text(goal)}")
            free, last = clock, frame
            for step in range(1, steps + 1):
                due = clock + duration * step / steps
                left = round(frame[0] + (goal[0] - frame[0]) * step / steps)
                following = (left, 80.0, 1200.0 - left, 400.0)
                if manner == "silent":
                    log.append(f"{due:.2f} call {act} {window} place {step} 1000.00 -25204 0.00 {text(following)}")
                    free = due + 1000
                    break
                for turn, kind in enumerate(("place", "size") if goal[2] > frame[2] else ("size", "place")):
                    began = max(due, free) + (60 if manner == "overslept" and step == 4 and turn == 0 else 0)
                    took = manner - 300 / 18 if isinstance(manner, int) and step == 9 and turn == 0 else 350.0 if manner == "slow" and step == 3 and turn == 0 else 20.0 if manner == "late" else 10.0 if manner == "torn" and turn == 1 else 1.0
                    log.append(f"{began:.2f} call {act} {window} {kind} {step} {took:.2f} 0 {began - due:.2f} {text(following)}")
                    free = began + took
                    if manner == "torn" and turn == 0:
                        shown[window].append((free, following[:2] + last[2:] if kind == "place" else last[:2] + following[2:]))
                if manner != "skips" or step % 3 == 0 or step == steps:
                    shown[window].append((free, following[:2] + (560.0, 400.0) if manner == "fixed" else following))
                last = following
            if manner == "never" or (manner == "elsewhere" and steps > 1):
                shown[window].append((free + 30, (goal[0], goal[1] + 20, goal[2], goal[3])))
            log.append(f"{free:.2f} done {act} 5.00")
            frame, clock = frame if manner == "silent" else goal, free + 600
    if bar is not None:
        log += [f"{clock:.2f} act {name}.4 0 0 macos", f"{clock:.2f} ask {name}.4 {window} 7 glides {text(frame)} 0 31 720 800"]
        for step in range(1, 19):
            share = step / 18
            shown[window].append((clock + 20 + 300 * share + (bar - 300 / 18 if step > 9 else 0), tuple(round(a + (b - a) * share) for a, b in zip(frame, (0.0, 31.0, 720.0, 800.0)))))
        log.append(f"{clock + 900:.2f} done {name}.4 5.00")
        clock += 1500
    samples = ["999000 M sampler at 120 Hz"] + [f"{end:.0f} L {end - start:.0f}" for start, end in blind]
    for window, states in shown.items():
        last = None
        for tick in range(int((clock - 999_000) * 120 / 1000)):
            time = 999_000 + tick * 1000 / 120
            now = [state for since, state in states if since <= time][-1:]
            if now and now[0] != last and not any(start < time < end for start, end in blind):
                last = now[0]
                samples.append(f"{time:.0f} W {window} 7 0 {text(last)} App")
    for name, lines in (("glide.log", log), ("samples.log", sorted(samples, key=lambda line: float(line.split()[0])))):
        with open(os.path.join(folder, name), "w", encoding="utf-8") as file:
            file.write("\n".join(lines) + "\n")


def self_test():
    import tempfile
    failures = []

    def expect(what, cast, stutter, verdict, options=(), blind=(), bar=None, says=""):
        with tempfile.TemporaryDirectory() as folder:
            make_up(folder, cast, blind, bar)
            said = []
            found, judged = judge(folder, parse([folder, *options]), said.append)
            if found != sorted(stutter) or said[-1] != f"verdict: {verdict}" or said[-2] != f"stutter: {len(stutter)} of {len(judged)} apps" or not any(says in line for line in said):
                failures.append(f"{what}: {found}, {said[-2]}, {said[-1]}\n" + "\n".join(said))

    long = [(1_000_500.0, 1_003_000.0)]
    expect("smooth apps", {"a": "smooth", "b": "smooth"}, [], "alive")
    expect("one whose far edge is seen to give way between the askings", {"a": "torn", "b": "smooth"}, ["a"], "alive")
    expect("one that answers late", {"a": "smooth", "b": "late"}, ["b"], "alive")
    expect("one asking longer than the glide", {"a": "slow"}, ["a"], "alive")
    expect("one that does not answer, and is not asked again", {"a": "silent", "b": "smooth"}, ["a"], "alive", says="an asking took 1000 ms, longer than the whole glide")
    expect("one that ends elsewhere", {"a": "elsewhere", "b": "smooth"}, ["a"], "alive")
    expect("one that skips frames", {"a": "skips", "b": "smooth"}, ["a"], "alive")
    expect("two of them: dead", {"a": "skips", "b": "smooth", "c": "torn"}, ["a", "c"], "dead")
    expect("the number of apps that kills can be set", {"a": "skips", "b": "late"}, ["a", "b"], "alive", ["--dead", "3"])
    expect("the limits can be set", {"a": "skips", "b": "late"}, [], "alive", ["--gap", "9", "--seen", "0.2", "--over", "4"])
    expect("so can how many wrong states are let pass", {"a": "torn"}, [], "alive", ["--wrong", "40", "--over", "2"])
    expect("and how far off is off", {"a": "elsewhere"}, [], "alive", ["--off", "25", "--wrong", "2"])
    expect("and how many glides are forgiven", {"a": "late"}, [], "alive", ["--forgive", "2"])
    expect("what the control does too is not the steps' doing", {"a": "never"}, [], "alive", ["--wrong", "2"])
    expect("an app of one size is judged by its near edges", {"a": "fixed"}, [], "alive")
    expect("a glide the sampler did not see is not judged", {"a": "smooth"}, [], "alive", blind=long)
    expect("unless gaps of that length are to be passed over", {"a": "smooth"}, ["a"], "alive", ["--blind", "3000"], blind=long)
    expect("nor one in which the tool overslept", {"a": "overslept"}, [], "alive")
    expect("but where it ended is seen all the same", {"a": "elsewhere"}, ["a"], "alive", blind=[(1_000_700.0, 1_000_800.0), (1_001_600.0, 1_001_700.0)])
    expect("a wait of 50 ms is a stutter beside a bar that is clean", {"a": 50}, ["a"], "alive", bar=17, says="the bar: 0 of 1 of macOS's own glides stutter by this rule")
    expect("and none beside a bar that waits 50 ms itself", {"a": 50}, [], "alive", bar=50, says="the bar: 1 of 1 of macOS's own glides stutter by this rule")
    expect("which is said", {"a": 50}, [], "alive", bar=50, says="macOS's own glide of this window stood still for")
    expect("a wait of 67 ms is one all the same", {"a": 67}, ["a"], "alive", bar=50)
    expect("one app's bar excuses no other app", {"a": 50, "b": "smooth"}, ["a"], "alive", bar=50)
    expect("the bar can be left out of the limit", {"a": 50}, ["a"], "alive", ["--no-bar"], bar=50)
    expect("a bar the sampler did not see raises nothing", {"a": 50}, ["a"], "alive", bar=50, blind=[(1_002_650.0, 1_002_670.0)])
    expect("without a bar the verdict has no control, and says so", {"a": "smooth"}, [], "alive", says="the verdict has no control")
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
    except (OSError, ValueError, IndexError, KeyError, StopIteration) as problem:
        print(f"judge-glide.py: cannot read the logs in {limits.folder}: {problem!r}", file=sys.stderr)
        return 2
    return 0 if judged else 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
