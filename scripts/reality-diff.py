#!/usr/bin/env python3
"""Compares what scripts/mac-shell/reality.sh wrote down on a hosted Mac with what it wrote down in a rehearsal on Linux.

Every difference is a lie of the stand-ins (Sources/ArborTesting, Sources/arbor-fakemac), to be cured there, or a fault of Arbor, to be
reported. Their number is the one to bring down to zero. `make reality` runs all of it; docs/TESTING.md has the manual.

Usage: scripts/reality-diff.py <mac folder> <linux folder> [--also <mac folder>]… [--known FILE] [--check] [--markdown FILE]
                               [--write-known FILE]

  <folder>            holds <journey>.jsonl, one observation a line (scripts/mac-shell/reality.py has the form)
  --also <folder>     another run of the same commit on a Mac. What one run on a real Mac shows and another does not is timing, not a
                      finding: it is classed `unstable` and counted apart
  --known FILE        the ratchet (collab/evidence/reality-known.txt): a key a line, then a word on it. `~` before a key: it comes and goes.
                      The word is as a rule the name of a cause, `@title-bar`, which a line of its own explains: `@title-bar stand-in: …`
                      A `~` key may hold `*` for anything: what a fight with an animation leaves in a key is never the same twice
  --check             exit code 1 when a key appears that the list does not have, or when a key of the list is gone (take it off: the
                      list shrinks with every cure)
  --markdown FILE     the same report as Markdown
  --write-known FILE  write the list anew from this comparison, keeping the words of the keys it already has

A folder may say in commit.txt at which commit it was made (reality.sh writes it). If Arbor itself differs between the Mac's and the rehearsal's, a
warning says so and names the journeys with anything new as to be recorded again. --check fails on them all the same.

Observations are aligned by journey and step and compared field by field. One line per divergence: its class, its KEY
(journey/step/field/window, the same from run to run) and both values. The classes:

  belief           Arbor ends up believing something else: a window's status, frame or slot, the tree, the camera, its replies
  truth            real windows end up elsewhere than the stand-ins' (more than a point), or on screen where those are not
  belief-vs-truth  on the Mac alone, what Arbor believes is not what the window server shows: a fault of Arbor or of its Accessibility
                   layer, whatever the stand-ins do
  focus            who Arbor thinks has the keyboard, who has it, which app is in front
  stacking         the order of the windows from front to back
  overlays         how many of Arbor's own windows are on screen at a level, and how many of macOS's own by owner (`furniture`)
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
import subprocess
import sys
import tempfile

CLASSES = ["belief", "truth", "belief-vs-truth", "focus", "stacking", "overlays", "answers", "reports-extra", "reports-missing",
           "reports-order", "unplayed"]
UNSTABLE = "unstable"
TOLERANCE = 1

# field: the key without its journey and step. lasting: of what is believed or shown, which may stay as it is from step to step.
Divergence = collections.namedtuple("Divergence", "kind key journey step field mac linux lasting")


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


def recorded_at(folder):
    """The commit a folder of observations was made at (commit.txt beside the journeys: its first word), or None."""
    try:
        with open(os.path.join(folder, "commit.txt"), encoding="utf-8") as file:
            return (file.read().split() or [None])[0]
    except OSError:
        return None


ARBOR = ["Sources/ArborCore", "Sources/ArborKit"]


def arbor_differs(checkout, there, here):
    """Whether Arbor itself differs between two commits (here None: what lies in the checkout). None: Git cannot tell."""
    command = ["git", "-C", checkout, "diff", "--quiet", there] + ([here] if here else []) + ["--"] + ARBOR
    code = subprocess.run(command, capture_output=True, check=False).returncode
    return {0: False, 1: True}.get(code)


def read_known(path):
    """{key: (comes and goes, word)} in the order of the file, {@cause: what it is}, and [(pattern, word)] for `~` keys with a `*` in them."""
    known, causes, shapes = {}, {}, []
    with open(path, encoding="utf-8") as lines:
        for line in lines:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            key, _, word = line.partition(" ")
            if key.startswith("@"):
                causes[key] = word.strip()
            elif is_shape(key):
                shapes.append((re.compile(re.escape(key[1:]).replace(r"\*", ".*") + "$"), word.strip()))
            else:
                known[key.lstrip("~")] = (key.startswith("~"), word.strip())
    return known, causes, shapes


def is_shape(key):
    """Only what comes and goes may be named by its shape: a finding has one key."""
    return key.startswith("~") and "*" in key


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
            for name in ("status", "frame", "slot", "bundle"):
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
    for owner, count in truth.get("furniture", {}).items():
        found[("overlays", f"truth/furniture/{slug(owner)}")] = count
    return found


def absent(field):
    """What a field that one world lacks counts as."""
    return 0 if "/overlays/" in field or "/furniture/" in field else None


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
        left, again = 0, collections.Counter()
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
                    # The same request may be made twice in a step, and answered otherwise each time: a key for each.
                    again[a[1]] += 1
                    number = f"#{again[a[1]]}" if again[a[1]] > 1 else ""
                    found.append(("answers", f"answers/{window}/{slug(a[1])}{number}", f"took {a[2]}", f"took {b[2]}"))
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


def compare(mac, linux):
    """Every difference between two sets of journeys, step by step: what merely goes on is there at every step (`fold` sees to that
    once it is known which of them can be relied on). Returns them, and the (journey, step)s that both worlds have."""
    found, compared = [], set()

    def unplayed(journey, step, there, here):
        words = ("played" if there else "not played", "played" if here else "not played")
        found.append(Divergence("unplayed", f"{journey}/{slug(step)}/unplayed", journey, step, "unplayed", *words, False))

    for journey in sorted(set(mac) | set(linux)):
        if not mac.get(journey) or not linux.get(journey):
            unplayed(journey, "-", mac.get(journey), linux.get(journey))
            continue
        there = {row["step"]: row for row in linux[journey]}
        for row in mac[journey]:
            step = row["step"]
            other = there.pop(step, None)
            if other is None:
                unplayed(journey, step, True, False)
                continue
            compared.add((journey, step))

            def note(kind, field, a, b, lasting=True):
                found.append(Divergence(kind, f"{journey}/{slug(step)}/{field}", journey, step, field, a, b, lasting))

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
            rehearsed = against_itself(other)
            for field, (believed, shown) in sorted(against_itself(row).items()):
                also = "the same in the rehearsal" if field in rehearsed else "at one in the rehearsal"
                note("belief-vs-truth", f"belief-vs-truth/{field}", f"believes {show(believed)}, shows {show(shown)}", also)
            for kind, field, a, b in compare_reports(row["calm"], other["calm"]):
                note(kind, field, a, b, lasting=False)
        for step in there:
            unplayed(journey, step, False, True)
    return found, compared


def restless(mac):
    """The (journey, step)s that had not come to rest when they were written down."""
    return {(journey, row["step"]) for journey, rows in mac.items() for row in rows if not row.get("settled", True)}


def fold(found, order, is_solid):
    """Without what merely goes on: a lasting difference with the same two values as at the step before. Only like goes on from like: a
    finding does not go on from something that cannot be relied on, or it would hide behind it for as long as it lasts."""
    kept, before, now, place, at = [], {}, {}, None, -1
    for divergence in sorted(found, key=order):
        if place != (divergence.journey, divergence.step):
            # The step before is the one before in the journey: across a step that was not compared nothing goes on.
            follows = place is not None and place[0] == divergence.journey and order(divergence)[1] == at + 1
            before, now = (now if follows else {}), {}
            place, at = (divergence.journey, divergence.step), order(divergence)[1]
        if divergence.lasting:
            what = (divergence.kind, divergence.field, is_solid(divergence))
            now[what] = (divergence.mac, divergence.linux)
            if before.get(what) == now[what]:
                continue
        kept.append(divergence)
    return kept


# MARK: Reporting


def report(args):
    mac, linux = load(args.mac), load(args.linux)
    if not mac and not linux:
        print(f"reality-diff.py: no <journey>.jsonl in {args.mac} or in {args.linux}", file=sys.stderr)
        return 2
    runs = [mac] + [load(folder) for folder in args.also]
    known, causes, shapes = read_known(args.known) if args.known else ({}, {}, [])

    # Which runs show a difference, and which could have: those that played its step and had come to rest there.
    first, shows, could = {}, collections.defaultdict(set), collections.defaultdict(set)
    for number, run in enumerate(runs):
        differences, compared = compare(run, linux)
        for place in compared - restless(run):
            could[place].add(number)
        for place in compared:
            could.setdefault(place, set())
        for divergence in differences:
            first.setdefault(divergence.key, divergence)
            shows[divergence.key].add(number)
    steps = len(could)

    def comes_and_goes(divergence):
        """Some run that could have shown it did not."""
        return divergence.kind != "unplayed" and bool(could[(divergence.journey, divergence.step)] - shows[divergence.key])

    def in_a_shape(key):
        return key not in known and any(shape.match(key) for shape, _ in shapes)

    def is_solid(divergence):
        """A finding: every run that could show it does, at least one could, and the list does not say that it comes and goes. That a run
        was cut short is one whichever run it was."""
        if divergence.kind != "unplayed" and (comes_and_goes(divergence) or not could[(divergence.journey, divergence.step)]):
            return False
        return not known.get(divergence.key, (False,))[0] and not in_a_shape(divergence.key)

    # In the order of the rehearsal's steps, which is whole; a step only a Mac has comes after them.
    places = {}
    for world in [linux] + runs:
        for journey, rows in world.items():
            for row in rows:
                places.setdefault(journey, {}).setdefault(row["step"], len(places[journey]))

    def order(divergence):
        return (divergence.journey, places.get(divergence.journey, {}).get(divergence.step, -1), CLASSES.index(divergence.kind), divergence.key)

    found = fold(first.values(), order, is_solid)
    verdicts = {d.key: ("known" if d.key in known else "new") if is_solid(d) else UNSTABLE for d in found}

    # A key of the list that did not show is gone if it could have shown, or if nobody has its step any more. Of a step that was not played, or
    # had not come to rest, nothing can be said: the key waits.
    by_slug = {(journey, slug(step)): (journey, step) for journey, steps_ in places.items() for step in steps_}
    gone, waits = [], []
    for key, (unsteady, _) in known.items():
        if key in verdicts:
            continue
        place = by_slug.get(tuple(key.split("/")[:2]))
        if place is None or could.get(place):
            if not unsteady:
                gone.append(key)
        else:
            waits.append(key)
    marks = {"new": "✘ new     ", "known": "· known   ", UNSTABLE: "~ unstable"}
    lines, table = [], collections.defaultdict(collections.Counter)
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
    for key in waits:
        lines.append(f"? waits      {key}   its step was not played, or had not come to rest: nothing can be said of it ({known[key][1]})")

    counts = collections.Counter(verdicts.values())
    total = counts["new"] + counts["known"]
    summary = [f"{'class':<16} {'all':>4} {'new':>4} {'known':>5} {'unstable':>8}"]
    for kind in CLASSES:
        row = table[kind]
        if sum(row.values()):
            summary.append(f"{kind:<16} {row['new'] + row['known']:>4} {row['new']:>4} {row['known']:>5} {row[UNSTABLE]:>8}")
    # One lie shows at many steps. By what the list says of them, the largest first: where a cure takes the most keys.
    by_cause = collections.Counter(known[key][1] for key, state in verdicts.items() if state == "known")
    if by_cause:
        summary += ["", f"{'all':>4} by cause"]
        summary += [f"{count:>4} {word} {causes.get(word, '')}".rstrip()[:200] for word, count in by_cause.most_common()]
    journeys = len(set(mac) | set(linux))
    last = f"reality: {total} divergences in {steps} steps of {journeys} journeys (new: {counts['new']}, known: {counts['known']}, gone: {len(gone)})"
    apart = f"reality: {counts[UNSTABLE]} more come and go between runs on real Macs, or were seen before things had come to rest; counted apart"
    aside = []
    for word in sorted(ANOTHER_SEAM):
        times = [sum(row.get("reports", []).count(word) for rows in world.values() for row in rows) for world in (mac, linux)]
        if any(times):
            aside.append(f"reality: not compared, being of another seam than the window system's: {word} (mac: {times[0]}×, linux: {times[1]}×)")
    # A recording outlives the Arbor it was made of. What is new then is as likely the older Arbor's doing as a lie of the stand-ins: said, not forgiven.
    there, here = recorded_at(args.mac), recorded_at(args.linux)
    differs = arbor_differs(args.checkout, there, here) if there else False
    if differs is not False:
        stale = collections.Counter(d.journey for d in found if verdicts[d.key] == "new")
        again = ", ".join(f"{journey} ({count} new)" for journey, count in sorted(stale.items())) or "none has anything new"
        why = "Arbor has changed since" if differs else "Git does not know that commit, so nobody can tell whether Arbor has changed since"
        aside.append(f"reality: WARNING: the Mac's side was recorded at {there[:7]}, and {why} ({' and '.join(ARBOR)}): the two sides may not play the "
                     f"same Arbor. To be recorded again: {again}")
    # The table once more on one line, for readers who get only the lines that begin with `reality:` (CI's annotations).
    short = ", ".join(f"{kind} {table[kind]['new'] + table[kind]['known']}" for kind in CLASSES if table[kind]["new"] + table[kind]["known"])
    aside.append(f"reality: by class: {short or 'nothing'}")
    print("\n".join(lines + [""] + summary + [""] + aside + [apart, last]))

    if args.markdown:
        with open(args.markdown, "w", encoding="utf-8") as out:
            out.write(f"# Reality\n\n**{last[len('reality: '):]}**\n\n{apart[len('reality: '):]}.\n\n")
            out.write("| class | all | new | known | unstable |\n|---|---|---|---|---|\n")
            for kind in CLASSES:
                row = table[kind]
                if sum(row.values()):
                    out.write(f"| {kind} | {row['new'] + row['known']} | {row['new']} | {row['known']} | {row[UNSTABLE]} |\n")
            if by_cause:
                out.write("\n| all | cause | |\n|---|---|---|\n")
                for word, count in by_cause.most_common():
                    out.write(f"| {count} | {word} | {causes.get(word, '')} |\n".replace("||", "| |"))
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
        write_known(args, found, verdicts, known, in_a_shape, comes_and_goes, set(gone), by_slug, places)

    return 1 if args.check and (counts["new"] or gone) else 0


def write_known(args, found, verdicts, known, in_a_shape, comes_and_goes, gone, by_slug, places):
    """The list anew. Whatever it says that this comparison does not refute stays: the words, the keys that come and go and did not show
    this time, the keys of steps that were not played. Only what is gone goes."""
    head = []
    if args.known:
        # What stands above the first key stays: the remarks, the causes and the shapes. Read before anything is written: it may be the same file.
        with open(args.known, encoding="utf-8") as old:
            for line in old:
                if line.strip() and line[0] not in "#@" and not is_shape(line.split()[0]):
                    break
                head.append(line)
    entries = {}
    for divergence in found:
        key = divergence.key
        if verdicts[key] != UNSTABLE:
            entries[key] = ""
        elif not in_a_shape(key):
            # A finding of the list is not taken for one that comes and goes because this time its step had not come to rest.
            entries[key] = "~" if comes_and_goes(divergence) or known.get(key, (True,))[0] else ""
    for key, (unsteady, _) in known.items():
        if key not in entries and key not in gone:
            entries[key] = "~" if unsteady else ""

    def order(key):
        journey, step = by_slug.get(tuple(key.split("/")[:2]), (key.split("/")[0], None))
        return (journey, places.get(journey, {}).get(step, -1), key)

    # Aside and then into place, so that whatever goes wrong half way leaves the list as it was.
    aside = args.write_known + ".new"
    with open(aside, "w", encoding="utf-8") as out:
        out.writelines(head)
        out.writelines(f"{entries[key]}{key} {known.get(key, (False, '?'))[1]}\n" for key in sorted(entries, key=order))
    os.replace(aside, args.write_known)


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

    def run(mac, linux, known=None, also=None, check=True, write=None, commits=(None, None), checkout=None):
        """The exit code, the classes of what is new, the last line, everything printed, and the list as --write-known left it.
        write: "aside" for a file of its own, "over" for the file --known names."""
        with tempfile.TemporaryDirectory() as folder:
            arguments = []
            for name, rows in (("mac", mac), ("linux", linux), ("also", also)):
                if rows is None:
                    continue
                os.makedirs(os.path.join(folder, name))
                with open(os.path.join(folder, name, "j.jsonl"), "w", encoding="utf-8") as out:
                    out.writelines(json.dumps(row) + "\n" for row in rows)
                arguments += ["--also", os.path.join(folder, name)] if name == "also" else [os.path.join(folder, name)]
            for name, sha in zip(("mac", "linux"), commits):
                if sha:
                    with open(os.path.join(folder, name, "commit.txt"), "w", encoding="utf-8") as out:
                        out.write(sha + "\n")
            if checkout:
                arguments += ["--checkout", checkout]
            if known is not None:
                with open(os.path.join(folder, "known"), "w", encoding="utf-8") as out:
                    out.write(known)
                arguments += ["--known", os.path.join(folder, "known")]
            written = os.path.join(folder, "known" if write == "over" else "written")
            if write:
                arguments += ["--write-known", written]
            saved, sys.stdout = sys.stdout, open(os.path.join(folder, "out"), "w", encoding="utf-8")
            try:
                code = report(parser().parse_args(arguments + (["--check"] if check else [])))
            finally:
                sys.stdout.close()
                sys.stdout = saved
            with open(os.path.join(folder, "out"), encoding="utf-8") as printed:
                text = printed.read()
            if write:
                with open(written, encoding="utf-8") as file:
                    written = file.read()
        news = sorted({line.split()[2] for line in text.splitlines() if line.startswith("✘ new")})
        return code, news, text.splitlines()[-1], text, written

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
    yield ("reality-diff: what comes and goes may be named by its shape",
           classes([look(reports=["setFrame:W1 12,43 494x650→-194,316 490x442", "setFrame:W1 12,43 494x650→12,43 494x650"])],
                   [look(reports=["setFrame:W1 12,43 494x650→12,43 494x650"])], known="~j/dock/reports/setFrame:W1-* why\n"), (0, []))
    yield ("reality-diff: a finding may not: without the ~ a shape is a key like any other, and it is gone",
           classes([look(status="floating")], [look()], known="j/dock/belief/* why\n"), (1, ["belief"]))
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

    # What lets the number fall, or the list rot, for the wrong reason.
    def new_keys(*arguments, **options):
        return [line.split()[3] for line in run(*arguments, **options)[3].splitlines() if line.startswith("✘ new")]

    three = [look(), look(step="zoom"), look(step="back")]
    floats = [look(status="floating"), look(step="zoom", status="floating"), look(step="back", status="floating")]
    yield ("reality-diff: a difference that begins before things came to rest, and lasts, is a finding from the first step at rest",
           new_keys([look(status="floating", settled=False)] + floats[1:], three), ["j/zoom/belief/status/W1"])
    yield ("reality-diff: one that begins under a key that comes and goes, and lasts, is a finding from the next step",
           new_keys(floats, three, known="~j/dock/belief/status/W1 why\n"), ["j/zoom/belief/status/W1"])
    yield ("reality-diff: one that begins at another step in another run is a finding from where every run shows it",
           new_keys(floats, three, also=[look()] + floats[1:]), ["j/zoom/belief/status/W1"])
    yield ("reality-diff: a run that was cut short says nothing about the steps it never played, and that it was cut short is a finding",
           new_keys([look(), look(step="zoom", status="floating")], three[:2], also=[look()]), ["j/zoom/belief/status/W1", "j/zoom/unplayed"])
    yield ("reality-diff: a step that had not come to rest in one run is judged by the runs in which it had",
           new_keys([look(status="floating", settled=False)], [look()], also=[look(status="floating")]), ["j/dock/belief/status/W1"])
    yield ("reality-diff: a known key of a step that was not played is not cured: it waits",
           run([look()], three[:2], known="j/zoom/belief/status/W1 why\n")[2],
           "reality: 1 divergences in 1 steps of 1 journeys (new: 1, known: 0, gone: 0)")
    yield ("reality-diff: nor one of a journey that was not played",
           run([], [look()], known="j/dock/belief/status/W1 why\n")[2],
           "reality: 1 divergences in 0 steps of 1 journeys (new: 1, known: 0, gone: 0)")
    yield ("reality-diff: a known key of a step that neither world has any more is gone",
           run([look()], [look()], known="j/renamed/belief/status/W1 why\n")[2],
           "reality: 0 divergences in 1 steps of 1 journeys (new: 0, known: 0, gone: 1)")
    twice = ["setFrame:W1 12,43 494x650→12,43 494x600", "setFrame:W1 12,43 494x650→12,43 494x500"]
    asked_twice = run([look(reports=twice)], [look(reports=["setFrame:W1 12,43 494x650→12,43 494x650"] * 2)], write="aside")
    yield ("reality-diff: the same request twice in a step, with two other answers, is two keys",
           [line.split()[3] for line in asked_twice[3].splitlines() if line.startswith("✘ new")],
           ["j/dock/answers/W1/12,43-494x650", "j/dock/answers/W1/12,43-494x650#2"])
    yield ("reality-diff: and the table, the number and the list agree about them",
           ([line.split()[1] for line in asked_twice[3].splitlines() if line.startswith("answers ")], asked_twice[2].split()[1],
            len(asked_twice[4].splitlines())), (["2"], "2", 2))

    head = "# a remark\n@cause what it is\n~j/dock/reports/setFrame:* @cause\n\n"
    listed = head + "j/dock/belief/status/W1 @cause\n~j/dock/truth/overlays/level-6 a word to keep\nj/dock/truth/frame/W1 cured\n"
    kept = head + "j/dock/belief/status/W1 @cause\n~j/dock/truth/overlays/level-6 a word to keep\n"
    yield ("reality-diff: --write-known keeps a key that comes and goes and did not show this time, with its word, and drops what is gone",
           run([look(status="floating")], [look()], known=listed, write="aside")[4], kept)
    yield ("reality-diff: --write-known over the list itself keeps the remarks, the causes and the shapes",
           run([look(status="floating")], [look()], known=listed, write="over")[4], kept)
    yield ("reality-diff: --write-known keeps the keys of a step that was not played",
           run([look()], three[:2], known="j/zoom/belief/status/W1 why\n", write="aside")[4], "j/zoom/belief/status/W1 why\nj/zoom/unplayed ?\n")
    yield ("reality-diff: --write-known does not take a known finding for one that comes and goes because one run had not come to rest",
           run([look(status="floating", settled=False)], [look()], known="j/dock/belief/status/W1 why\n", write="aside")[4],
           "j/dock/belief/status/W1 why\n")

    with tempfile.TemporaryDirectory() as checkout:
        def git(*words):
            identity = ["-c", "user.name=nobody", "-c", "user.email=nobody@example.com"]
            return subprocess.run(["git", "-C", checkout, *identity, *words], capture_output=True, text=True, check=False).stdout.strip()

        def commit(path, text):
            os.makedirs(os.path.dirname(os.path.join(checkout, path)), exist_ok=True)
            with open(os.path.join(checkout, path), "w", encoding="utf-8") as out:
                out.write(text)
            git("add", "--all")
            git("commit", "--quiet", "--message", "x")
            return git("rev-parse", "HEAD")

        git("init", "--quiet")
        commits = [commit("Sources/ArborKit/a.swift", "1"), commit("docs/a.md", "1"), commit("Sources/ArborKit/a.swift", "2")]

        def warned(there, here):
            answer = run([look(status="floating")], [look()], commits=(there, here), checkout=checkout)
            return answer[0], [line.partition("To be recorded again: ")[2] for line in answer[3].splitlines() if "WARNING" in line]

        yield "reality-diff: a recording of the same Arbor", warned(commits[0], commits[0]), (1, [])
        yield "reality-diff: only prose has changed since the recording", warned(commits[0], commits[1]), (1, [])
        yield ("reality-diff: Arbor has changed since the recording: a warning names the journeys with anything new, and the check still fails",
               warned(commits[0], commits[2]), (1, ["j (1 new)"]))
        yield "reality-diff: a recording from a commit nobody has", warned("0" * 40, commits[2]), (1, ["j (1 new)"])
        yield "reality-diff: a recording that does not say where it is from", warned(None, commits[2]), (1, [])

    with tempfile.TemporaryDirectory() as folder:
        with open(os.path.join(folder, "list"), "w", encoding="utf-8") as out:
            out.write(listed)
        saved, sys.stderr = sys.stderr, open(os.devnull, "w", encoding="utf-8")
        try:
            code = report(parser().parse_args([folder, folder, "--check", "--known", os.path.join(folder, "list"),
                                               "--write-known", os.path.join(folder, "list")]))
        finally:
            sys.stderr.close()
            sys.stderr = saved
        with open(os.path.join(folder, "list"), encoding="utf-8") as file:
            left = file.read()
    yield "reality-diff: two empty folders are no agreement", code, 2
    yield "reality-diff: and leave the list alone", left, listed


def parser():
    made = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    made.add_argument("mac")
    made.add_argument("linux")
    made.add_argument("--also", action="append", default=[])
    made.add_argument("--known")
    made.add_argument("--check", action="store_true")
    made.add_argument("--markdown")
    made.add_argument("--write-known")
    made.add_argument("--checkout", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))), help=argparse.SUPPRESS)
    return made


if __name__ == "__main__":
    sys.exit(report(parser().parse_args()))
