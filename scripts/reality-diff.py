#!/usr/bin/env python3
"""Compares what scripts/mac-shell/reality.sh wrote down on a hosted Mac with what it wrote down in a rehearsal on Linux.

Every difference is a lie of the stand-ins (Sources/ArborTesting, Sources/arbor-fakemac), to be cured there, or a fault of Arbor, to be
reported. Their number is the one to bring down to zero. `make reality` runs all of it; docs/TESTING.md has the manual.

Usage: scripts/reality-diff.py <mac folder> <linux folder> [--also <mac folder>]… [--known FILE] [--check] [--markdown FILE]
                               [--write-known FILE]

  <folder>            holds <journey>.jsonl, one observation a line (scripts/mac-shell/reality.py has the form)
  --also <folder>     another run of the same commit on a Mac. What one run on a real Mac shows and another does not is timing, not a
                      finding: it is classed `unstable` and counted apart
  --known FILE        the ratchet (collab/evidence/reality-known.txt): a key a line, then a word on it. `~` before a key: it comes and goes
  --check             exit code 1 when a key appears that the list does not have, or when a key of the list is gone (take it off: the
                      list shrinks with every cure)
  --markdown FILE     the same report as Markdown
  --write-known FILE  write the list anew from this comparison, keeping the words of the keys it already has

Observations are aligned by journey and step and compared field by field. One line per divergence: its class, its KEY
(journey/step/field/window, the same from run to run) and both values. The classes:

  belief           Arbor ends up believing something else: a window's status, frame or slot, the tree, the camera, its replies
  truth            real windows end up elsewhere than the stand-ins' (more than a point), or on screen where those are not
  belief-vs-truth  on the Mac alone, what Arbor believes is not what the window server shows: a fault of Arbor or of its Accessibility
                   layer, whatever the stand-ins do
  focus            who Arbor thinks has the keyboard, who has it, which app is in front
  stacking         the order of the windows from front to back
  overlays         how many of Arbor's own windows are on screen at a level
  answers          a window asked for the same frame took another, or Arbor asked it for another frame to begin with
  reports-extra    the Mac reports, or Arbor does there, what does not happen in the rehearsal
  reports-missing  the stand-ins report, or Arbor does on them, what does not happen on the Mac
  reports-order    the same reports and calls in another order
  unplayed         a journey or a step that one of the two worlds does not have
  unstable         any of these that not every run on a real Mac shows, or at a step that had not come to rest

A difference in what is believed or shown that stays the same from one step to the next is one divergence, under the step where it
began. A frame that Arbor has right in both worlds is one divergence too, of `truth`: that it believes something else follows. While a window is dragged or resized or a seam is dragged, how many moves are reported is a matter of timing (a trace thins them by the
clock), so a run of moves counts as one of each kind, written `~kind`.

Exit codes: 0; 1 as --check says; 2 when there is nothing to compare.
"""

import argparse
import collections
import glob
import json
import os
import re
import sys
import tempfile

CLASSES = ["belief", "truth", "belief-vs-truth", "focus", "stacking", "overlays", "answers", "reports-extra", "reports-missing",
           "reports-order", "unplayed"]
UNSTABLE = "unstable"
TOLERANCE = 1

Divergence = collections.namedtuple("Divergence", "kind key journey step mac linux")


# MARK: Reading


def load(folder):
    """{journey: [observation…]} in the order they were made."""
    journeys = {}
    for path in sorted(glob.glob(os.path.join(folder, "*.jsonl"))):
        rows = []
        with open(path, encoding="utf-8") as lines:
            for line in lines:
                if line.strip():
                    try:
                        rows.append(json.loads(line))
                    except ValueError:
                        pass  # a last line cut off with the run; the step then counts as not played
        # A drag that is held over a step goes on in the next one.
        in_gesture = False
        for row in rows:
            row["calm"], in_gesture = calm(row.get("reports", []), in_gesture)
        journeys[os.path.basename(path)[:-len(".jsonl")]] = rows
    return journeys


def read_known(path):
    """{key: (comes and goes, word)} in the order of the file."""
    known = {}
    with open(path, encoding="utf-8") as lines:
        for line in lines:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            key, _, word = line.partition(" ")
            known[key.lstrip("~")] = (key.startswith("~"), word.strip())
    return known


def slug(text):
    return re.sub(r"\s+", "-", re.sub(r"['’]", "", str(text).strip()))


def show(value):
    if value is None:
        return "none"
    if isinstance(value, bool):
        return "yes" if value else "no"
    if is_frame(value):
        return f"{value[0]},{value[1]} {value[2]}x{value[3]}"
    if isinstance(value, list):
        return "[" + " ".join(show(entry) for entry in value) + "]"
    if isinstance(value, dict):
        return "{" + " ".join(f"{key}:{show(entry)}" for key, entry in sorted(value.items())) + "}"
    return str(value)


def is_frame(value):
    return isinstance(value, list) and len(value) == 4 and all(isinstance(number, (int, float)) and not isinstance(number, bool) for number in value)


def same(a, b):
    """Equal, give or take a point in every number of a frame. A count is not a frame: one panel is not none."""
    if is_frame(a) and is_frame(b):
        return all(abs(x - y) <= TOLERANCE for x, y in zip(a, b))
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(same(a[key], b[key]) for key in a)
    return a == b


# MARK: What is believed and what shows


def fields(observation):
    """Everything that is compared as it stands: {(class, field): value}."""
    found = {}
    belief, truth = observation.get("belief"), observation.get("truth") or {}
    found[("belief", "belief/running")] = bool(belief and belief.get("running"))
    if belief:
        for name in ("says", "paused", "held", "waiting"):
            found[("belief", f"belief/{name}")] = belief.get(name)
        found[("focus", "belief/focused")] = belief.get("focused")
        for number, display in enumerate(belief.get("displays", []), start=1):
            where = "belief" if number == 1 else f"belief/display-{number}"
            for name, value in display.items():
                found[("belief", f"{where}/{name}")] = value
        for window, entry in belief.get("windows", {}).items():
            for name in ("status", "frame", "slot"):
                found[("belief", f"belief/{name}/{window}")] = entry.get(name)
    found[("belief", "belief/replies")] = observation.get("replies", [])
    for window, entry in truth.get("windows", {}).items():
        found[("truth", f"truth/frame/{window}")] = entry.get("frame")
        found[("truth", f"truth/on-screen/{window}")] = entry.get("on")
    found[("stacking", "truth/order")] = truth.get("order", [])
    found[("focus", "truth/front")] = truth.get("front")
    found[("focus", "truth/keyboard")] = truth.get("keyboard")
    for level, count in truth.get("overlays", {}).items():
        found[("overlays", f"truth/overlays/level-{level}")] = count
    return found


def absent(field):
    """What a field that one world lacks counts as."""
    return 0 if "/overlays/" in field else None


def against_itself(observation):
    """Where belief and truth part within one world: {field: (believed, shown)}."""
    found = {}
    belief, truth = observation.get("belief"), observation.get("truth") or {}
    if not belief or not belief.get("running"):
        return found
    shown = truth.get("windows", {})
    for window, entry in belief.get("windows", {}).items():
        real = shown.get(window)
        if real is None:
            found[f"exists/{window}"] = (entry["status"], "gone")
            continue
        away = any(word in entry["status"].split() for word in ("minimized", "hidden"))
        if away == bool(real.get("on")):
            found[f"on-screen/{window}"] = (entry["status"], "on screen" if real.get("on") else "not on screen")
        if not away and not same(entry.get("frame"), real.get("frame")):
            found[f"frame/{window}"] = (entry.get("frame"), real.get("frame"))
    for window, real in shown.items():
        if window not in belief.get("windows", {}) and real.get("on"):
            found[f"exists/{window}"] = ("unknown", "on screen")
    if belief.get("focused") != truth.get("keyboard"):
        found["focused"] = (belief.get("focused"), truth.get("keyboard"))
    return found


# MARK: What crossed the seam

# Written down, and not compared: this is the seam to the window system. On a Mac every save of state.json wakes the watcher of
# settings.json, which lies in the same folder, twice; the stand-ins have no files to watch. The report says how often it was left out.
ANOTHER_SEAM = {"settingsFileMayHaveChanged"}
BEGINS = re.compile(r"^(dragBegan|resizeBegan):")
ENDS = re.compile(r"^(dragEnded|resizeEnded|dragCancelled):")
MOVES = re.compile(r"^(dragMoved:\S+|changed:\S+|setFrame:\S+|action:seamDragged)")
FOLLOWS_A_SEAM = re.compile(r"^(setFrame|changed):")
SET_FRAME = re.compile(r"^setFrame:(\S+) (\S+ \S+)→(.+)$")


def calm(reports, in_gesture=False):
    """The reports with every run of moves within a gesture as one of each kind. Returns them, and whether a gesture is still going on."""
    reports = [word for word in reports if word not in ANOTHER_SEAM]
    last_seam = max((index for index, word in enumerate(reports) if word.startswith("action:seamDragged")), default=-1)
    result, run = [], set()
    seam = False

    def flush():
        # In one order: which of a window's move and the pointer's is reported first changes from run to run on the same Mac.
        result.extend(sorted(run))
        run.clear()

    for index, word in enumerate(reports):
        if word.startswith("action:seamDragged"):
            seam = True
        elif seam and index > last_seam and not FOLLOWS_A_SEAM.match(word):
            seam = False
        moving = MOVES.match(word) if in_gesture or seam else None
        # A flag that changes in mid-gesture (`+minimized`) is news, not a move.
        if moving and "+" not in word:
            run.add("~" + moving.group(1))
            continue
        flush()
        result.append(word)
        if BEGINS.match(word):
            in_gesture = True
        elif ENDS.match(word):
            in_gesture = False
    flush()
    return result, in_gesture


def numbers(text):
    return [int(number) for number in re.findall(r"-?\d+", text)]


def compare_reports(mac, linux):
    """[(class, field, mac's, linux's)] for two calmed lists of reports."""
    found = []
    mac, linux = list(mac), list(linux)

    # A call to the same window with another request or another answer is one finding, not a call too many on either side. Paired in
    # three rounds, each in the order of the calls: alike but for a point, then the same request, then whatever is left.
    def calls(words):
        found = collections.defaultdict(list)
        for index, word in enumerate(words):
            parts = SET_FRAME.match(word)
            if parts:
                found[parts.group(1)].append((index, parts.group(2), parts.group(3)))
        return found

    def alike(a, b):
        return a[1] == b[1] and (a[2] == b[2] or ("none" not in (a[2], b[2]) and same(numbers(a[2]), numbers(b[2]))))

    there, here = calls(mac), calls(linux)
    for window in sorted(set(there) & set(here)):
        left = 0
        for round_, matches in enumerate((alike, lambda a, b: a[1] == b[1], lambda a, b: True)):
            for a in list(there[window]):
                b = next((b for b in here[window] if matches(a, b)), None)
                if b is None:
                    continue
                there[window].remove(a)
                here[window].remove(b)
                # From here on the rehearsal's call goes by the Mac's word, so that it is neither extra nor missing nor out of order.
                linux[b[0]] = mac[a[0]]
                if round_ == 1:
                    found.append(("answers", f"answers/{window}/{slug(a[1])}", f"took {a[2]}", f"took {b[2]}"))
                elif round_ == 2:
                    left += 1
                    found.append(("answers", f"answers/{window}/asked-{left}", f"{a[1]}→{a[2]}", f"{b[1]}→{b[2]}"))

    count_mac, count_linux = collections.Counter(mac), collections.Counter(linux)
    for word in sorted(set(count_mac) | set(count_linux)):
        a, b = count_mac[word], count_linux[word]
        if a > b:
            found.append(("reports-extra", f"reports/{slug(word)}", f"{a}×", f"{b}×"))
        elif b > a:
            found.append(("reports-missing", f"reports/{slug(word)}", f"{a}×", f"{b}×"))

    def shared(words):
        left = {word: min(count_mac[word], count_linux[word]) for word in count_mac}
        kept = []
        for word in words:
            if left.get(word, 0) > 0:
                left[word] -= 1
                kept.append(word)
        return kept

    both_mac, both_linux = shared(mac), shared(linux)
    if both_mac != both_linux:
        first = next(index for index, (a, b) in enumerate(zip(both_mac, both_linux)) if a != b)
        start = max(first - 1, 0)
        found.append(("reports-order", "reports-order", " ".join(both_mac[start:first + 4]), " ".join(both_linux[start:first + 4])))
    return found


# MARK: Comparing


def compare(mac, linux, with_itself=True):
    """Every divergence between two sets of journeys, those that merely go on left out. Returns them, and the steps compared."""
    found, steps = [], 0
    for journey in sorted(set(mac) | set(linux)):
        if journey not in mac or journey not in linux or not mac[journey] or not linux[journey]:
            played = ("played" if mac.get(journey) else "not played", "played" if linux.get(journey) else "not played")
            found.append(Divergence("unplayed", f"{journey}/-/unplayed", journey, "-", *played))
            continue
        there = {row["step"]: row for row in linux[journey]}
        before = {}
        for row in mac[journey]:
            step = row["step"]
            other = there.pop(step, None)
            if other is None:
                found.append(Divergence("unplayed", f"{journey}/{slug(step)}/unplayed", journey, step, "played", "not played"))
                continue
            steps += 1
            now = {}

            def note(kind, field, a, b, lasting=True):
                if lasting:
                    now[(kind, field)] = (a, b)
                    if before.get((kind, field)) == (a, b):
                        return
                found.append(Divergence(kind, f"{journey}/{slug(step)}/{field}", journey, step, a, b))

            ours, theirs = fields(row), fields(other)
            for kind, field in sorted(set(ours) | set(theirs)):
                a, b = ours.get((kind, field), absent(field)), theirs.get((kind, field), absent(field))
                if same(a, b):
                    continue
                # A frame that Arbor has right in both worlds differs because the window is elsewhere, which `truth` says already.
                shown = ("truth", field.replace("belief/", "truth/", 1))
                if field.startswith("belief/frame/") and same(a, ours.get(shown)) and same(b, theirs.get(shown)):
                    continue
                note(kind, field, show(a), show(b), lasting=field != "belief/replies")
            if with_itself:
                rehearsed = against_itself(other)
                for field, (believed, shown) in sorted(against_itself(row).items()):
                    also = "the same in the rehearsal" if field in rehearsed else "at one in the rehearsal"
                    note("belief-vs-truth", f"belief-vs-truth/{field}", f"believes {show(believed)}, shows {show(shown)}", also)
            for kind, field, a, b in compare_reports(row["calm"], other["calm"]):
                note(kind, field, a, b, lasting=False)
            before = now
        for step in there:
            found.append(Divergence("unplayed", f"{journey}/{slug(step)}/unplayed", journey, step, "not played", "played"))
    return found, steps


def restless(mac):
    """The steps that had not come to rest when they were written down, as the beginnings of their keys."""
    return {f"{journey}/{slug(row['step'])}/" for journey, rows in mac.items() for row in rows if not row.get("settled", True)}


# MARK: Reporting


def report(args):
    mac, linux = load(args.mac), load(args.linux)
    if not mac and not linux:
        print(f"reality-diff.py: no <journey>.jsonl in {args.mac} or in {args.linux}", file=sys.stderr)
        return 2
    others = [load(folder) for folder in args.also]
    known = read_known(args.known) if args.known else {}
    found, steps = compare(mac, linux)
    unsettled = restless(mac)
    # A divergence is a finding if every run on a Mac shows it. What only some show is written down too, so that the list knows it when it comes.
    seen, always = {divergence.key for divergence in found}, {divergence.key for divergence in found}
    for other in others:
        again = compare(other, linux)[0]
        always &= {divergence.key for divergence in again}
        unsettled |= restless(other)
        for divergence in again:
            if divergence.key not in seen:
                seen.add(divergence.key)
                found.append(divergence)

    def verdict(divergence):
        if divergence.key not in always or any(divergence.key.startswith(start) for start in unsettled):
            return UNSTABLE
        if divergence.key in known:
            return UNSTABLE if known[divergence.key][0] else "known"
        return "new"

    verdicts = {divergence.key: verdict(divergence) for divergence in found}
    gone = [key for key, (comes_and_goes, _) in known.items() if key not in verdicts and not comes_and_goes]
    marks = {"new": "✘ new     ", "known": "· known   ", UNSTABLE: "~ unstable"}
    lines, table = [], collections.defaultdict(collections.Counter)
    order = {journey: {row["step"]: index for index, row in enumerate(rows)} for journey, rows in mac.items()}
    found.sort(key=lambda d: (d.journey, order.get(d.journey, {}).get(d.step, 10_000), CLASSES.index(d.kind), d.key))
    place = None
    for divergence in found:
        if place != (divergence.journey, divergence.step):
            place = (divergence.journey, divergence.step)
            lines.append(f"== {divergence.journey}: {divergence.step}")
        state = verdicts[divergence.key]
        table[divergence.kind][state] += 1
        lines.append(f"{marks[state]} {divergence.kind:<15} {divergence.key}   mac: {divergence.mac} | linux: {divergence.linux}")
    for key in gone:
        lines.append(f"✘ gone       {key}   it is on the list of known divergences and did not show: take it off ({known[key][1]})")

    counts = collections.Counter(verdicts.values())
    total = counts["new"] + counts["known"]
    summary = [f"{'class':<16} {'all':>4} {'new':>4} {'known':>5} {'unstable':>8}"]
    for kind in CLASSES:
        row = table[kind]
        if sum(row.values()):
            summary.append(f"{kind:<16} {row['new'] + row['known']:>4} {row['new']:>4} {row['known']:>5} {row[UNSTABLE]:>8}")
    journeys = len(set(mac) | set(linux))
    last = f"reality: {total} divergences in {steps} steps of {journeys} journeys (new: {counts['new']}, known: {counts['known']}, gone: {len(gone)})"
    apart = f"reality: {counts[UNSTABLE]} more come and go between runs on real Macs, or were seen before things had come to rest; counted apart"
    aside = []
    for word in sorted(ANOTHER_SEAM):
        times = [sum(row.get("reports", []).count(word) for rows in world.values() for row in rows) for world in (mac, linux)]
        if any(times):
            aside.append(f"reality: not compared, being of another seam than the window system's: {word} (mac: {times[0]}×, linux: {times[1]}×)")
    print("\n".join(lines + [""] + summary + [""] + aside + [apart, last]))

    if args.markdown:
        with open(args.markdown, "w", encoding="utf-8") as out:
            out.write(f"# Reality\n\n**{last[len('reality: '):]}**\n\n{apart[len('reality: '):]}.\n\n")
            out.write("| class | all | new | known | unstable |\n|---|---|---|---|---|\n")
            for kind in CLASSES:
                row = table[kind]
                if sum(row.values()):
                    out.write(f"| {kind} | {row['new'] + row['known']} | {row['new']} | {row['known']} | {row[UNSTABLE]} |\n")
            place = None
            for divergence in found:
                if place != (divergence.journey, divergence.step):
                    place = (divergence.journey, divergence.step)
                    out.write(f"\n## {divergence.journey}: {divergence.step}\n\n| | class | key | Mac | Linux | reading |\n|---|---|---|---|---|---|\n")
                cells = [verdicts[divergence.key], divergence.kind, f"`{divergence.key}`", divergence.mac, divergence.linux,
                         known.get(divergence.key, (False, ""))[1]]
                out.write("| " + " | ".join(str(cell).replace("|", "\\|") for cell in cells) + " |\n")
            if gone:
                out.write("\n## Gone\n\n" + "".join(f"- `{key}`\n" for key in gone))

    if args.write_known:
        with open(args.write_known, "w", encoding="utf-8") as out:
            if args.known:
                with open(args.known, encoding="utf-8") as old:
                    for line in old:
                        if not line.startswith("#"):
                            break
                        out.write(line)
            for divergence in found:
                mark = "~" if verdicts[divergence.key] == UNSTABLE else ""
                out.write(f"{mark}{divergence.key} {known.get(divergence.key, (False, '?'))[1]}\n")

    return 1 if args.check and (counts["new"] or gone) else 0


# MARK: The tool tests itself (scripts/test-tooling.py runs these)


def situations():
    """(what, got, expected): situations that must come out as failures beside ones that must pass."""

    def look(step="dock", frame=(12, 43, 494, 650), real=None, status="docked", focused="W1", keyboard="W1", order=("W1",), reports=(),
             overlays=None, settled=True, replies=()):
        return {
            "journey": "j", "step": step, "n": 1, "settled": settled, "reports": list(reports), "replies": list(replies),
            "belief": {"running": True, "says": "running", "focused": focused, "displays": [{"tree": "W1 | Desktop", "camera": "all"}],
                       "windows": {"W1": {"status": status, "frame": list(frame)}}},
            "truth": {"windows": {"W1": {"frame": list(real or frame), "on": True}}, "order": list(order), "front": "test-windows",
                      "keyboard": keyboard, "overlays": overlays or {}},
        }

    def run(mac, linux, known=None, also=None, check=True):
        """The exit code, and the classes of what is new."""
        with tempfile.TemporaryDirectory() as folder:
            arguments = []
            for name, rows in (("mac", mac), ("linux", linux), ("also", also)):
                if rows is None:
                    continue
                os.makedirs(os.path.join(folder, name))
                with open(os.path.join(folder, name, "j.jsonl"), "w", encoding="utf-8") as out:
                    out.writelines(json.dumps(row) + "\n" for row in rows)
                arguments += ["--also", os.path.join(folder, name)] if name == "also" else [os.path.join(folder, name)]
            if known is not None:
                with open(os.path.join(folder, "known"), "w", encoding="utf-8") as out:
                    out.write(known)
                arguments += ["--known", os.path.join(folder, "known")]
            saved, sys.stdout = sys.stdout, open(os.path.join(folder, "out"), "w", encoding="utf-8")
            try:
                code = report(parser().parse_args(arguments + (["--check"] if check else [])))
            finally:
                sys.stdout.close()
                sys.stdout = saved
            with open(os.path.join(folder, "out"), encoding="utf-8") as printed:
                text = printed.read()
        return code, sorted({line.split()[2] for line in text.splitlines() if line.startswith("✘ new")}), text.splitlines()[-1]

    def classes(mac, linux, **options):
        return run(mac, linux, **options)[:2]

    moved = ["dragBegan:W1", "changed:W1:user", "dragMoved:W1", "changed:W1:user", "dragMoved:W1", "dragEnded:W1"]
    key = "j/dock/truth/frame/W1"
    yield "reality-diff: two worlds that agree", classes([look()], [look()]), (0, [])
    yield "reality-diff: a point apart is the same place", classes([look(real=(13, 43, 494, 650))], [look()]), (0, [])
    yield ("reality-diff: the real window ends up elsewhere, and Arbor does not know",
           classes([look(real=(12, 43, 494, 600))], [look()]), (1, ["belief-vs-truth", "truth"]))
    yield ("reality-diff: Arbor believes something else",
           classes([look(status="floating")], [look()]), (1, ["belief"]))
    yield ("reality-diff: the keyboard is elsewhere on the Mac",
           classes([look(keyboard=None)], [look()]), (1, ["belief-vs-truth", "focus"]))
    yield "reality-diff: another order from front to back", classes([look(order=("W2", "W1"))], [look(order=("W1", "W2"))]), (1, ["stacking"])
    yield "reality-diff: a panel the rehearsal does not have", classes([look(overlays={"5": 1})], [look()]), (1, ["overlays"])
    yield ("reality-diff: the Mac reports what the stand-ins do not",
           classes([look(reports=["focused:W1", "changed:W1:user"])], [look(reports=["focused:W1"])]), (1, ["reports-extra"]))
    yield ("reality-diff: the stand-ins report what the Mac does not",
           classes([look(reports=[])], [look(reports=["keyboardFocusMoved"])]), (1, ["reports-missing"]))
    yield ("reality-diff: the same reports in another order",
           classes([look(reports=["focused:W1", "changed:W1:arbor"])], [look(reports=["changed:W1:arbor", "focused:W1"])]), (1, ["reports-order"]))
    yield ("reality-diff: the same request, another answer",
           classes([look(reports=["setFrame:W1 1023,767 480x352→1023,737 480x352"])], [look(reports=["setFrame:W1 1023,767 480x352→1023,673 480x352"])]),
           (1, ["answers"]))
    yield ("reality-diff: another request is one finding, not a call too many on either side",
           classes([look(reports=["setFrame:W1 518,180 480x348→518,180 480x348"])], [look(reports=["setFrame:W1 518,176 480x352→518,176 480x352"])]),
           (1, ["answers"]))
    yield ("reality-diff: a call too many is one",
           classes([look(reports=["setFrame:W1 12,43 494x650→12,43 494x650"] * 2)], [look(reports=["setFrame:W1 12,43 494x650→12,43 494x650"])]),
           (1, ["reports-extra"]))
    yield ("reality-diff: an answer a point apart",
           classes([look(reports=["setFrame:W1 12,43 494x650→12,43 494x651"])], [look(reports=["setFrame:W1 12,43 494x650→12,43 494x650"])]), (0, []))
    yield ("reality-diff: more moves in one drag than in the other are no finding",
           classes([look(reports=moved)], [look(reports=moved[:3] + moved[-1:])]), (0, []))
    yield ("reality-diff: a drag that never ends is one",
           classes([look(reports=moved[:-1])], [look(reports=moved)]), (1, ["reports-missing"]))
    yield "reality-diff: a step the Mac never got to", classes([look()], [look(), look(step="zoom")]), (1, ["unplayed"])
    yield "reality-diff: a journey of which the Mac brought nothing back", classes([], [look()]), (1, ["unplayed"])
    yield "reality-diff: another reply", classes([look(replies=["failed: no such window"])], [look(replies=["docked W1"])]), (1, ["belief"])
    yield ("reality-diff: a window that is elsewhere, and Arbor knows, is one divergence and not two",
           classes([look(frame=(12, 43, 494, 600))], [look()]), (1, ["truth"]))
    yield ("reality-diff: the file watcher's pokes are of another seam",
           classes([look(reports=["settingsFileMayHaveChanged", "focused:W1"])], [look(reports=["focused:W1"])]), (0, []))
    yield ("reality-diff: a known divergence passes",
           classes([look(frame=(12, 43, 494, 600))], [look()], known=f"{key} why\n"), (0, []))
    yield ("reality-diff: a new one beside a known one does not",
           classes([look(frame=(12, 43, 494, 600), keyboard=None, focused=None)], [look()], known=f"{key} why\n"), (1, ["focus"]))
    yield "reality-diff: a known divergence that is gone must come off the list", classes([look()], [look()], known=f"{key} why\n"), (1, [])
    yield "reality-diff: one that comes and goes may be gone", classes([look()], [look()], known=f"~{key} why\n"), (0, [])
    yield ("reality-diff: and may be there",
           classes([look(real=(12, 43, 494, 600))], [look()], known=f"~{key} why\n~j/dock/belief-vs-truth/frame/W1 why\n"), (0, []))
    yield ("reality-diff: without --check the number is only reported",
           classes([look(status="floating")], [look()], check=False), (0, ["belief"]))
    yield ("reality-diff: what differs between two runs on Macs is counted apart",
           classes([look(real=(12, 43, 494, 600))], [look()], also=[look()]), (0, []))
    yield ("reality-diff: what both runs on Macs show is not",
           classes([look(real=(12, 43, 494, 600))], [look()], also=[look(real=(12, 43, 494, 600))]), (1, ["belief-vs-truth", "truth"]))
    yield ("reality-diff: nor is anything written down before things came to rest",
           classes([look(real=(12, 43, 494, 600), settled=False)], [look()]), (0, []))
    yield ("reality-diff: a difference that goes on is one divergence",
           run([look(status="floating"), look(step="zoom", status="floating")], [look(), look(step="zoom")])[2],
           "reality: 1 divergences in 2 steps of 1 journeys (new: 1, known: 0, gone: 0)")
    yield ("reality-diff: one that changes is two",
           run([look(status="floating"), look(step="zoom", status="floating parked")], [look(), look(step="zoom")])[2],
           "reality: 2 divergences in 2 steps of 1 journeys (new: 2, known: 0, gone: 0)")
    with tempfile.TemporaryDirectory() as folder:
        saved, sys.stderr = sys.stderr, open(os.devnull, "w", encoding="utf-8")
        try:
            code = report(parser().parse_args([folder, folder, "--check"]))
        finally:
            sys.stderr.close()
            sys.stderr = saved
    yield "reality-diff: two empty folders are no agreement", code, 2


def parser():
    made = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    made.add_argument("mac")
    made.add_argument("linux")
    made.add_argument("--also", action="append", default=[])
    made.add_argument("--known")
    made.add_argument("--check", action="store_true")
    made.add_argument("--markdown")
    made.add_argument("--write-known")
    return made


if __name__ == "__main__":
    sys.exit(report(parser().parse_args()))
