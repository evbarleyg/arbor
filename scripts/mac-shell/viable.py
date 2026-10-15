#!/usr/bin/env python3
"""The viable gate's verdict: reads what the runs of one commit brought back and says VIABLE, NOT VIABLE or INVALID.

The gate's numbers are not in this file. They are in the first block of JSON in docs/VIABLE.md, which also says what every word
here means: an act, a user-hour, a cell, a cast, a detector, a run that counts.

  viable.py ledger <commit> <directory…> [-o <file>]   makes the ledger from runs' directories, each with the `run.json` its script wrote
                                                       and, if it got that far, the findings `jolts.py report --json` wrote
                                                       (`day-findings.json`). A `rings.json` in one of them or beside it is taken along
  viable.py check <ledger> [--runs <file>]             the table, the reasons and the verdict. `--runs`: every job of the gate's workflow on that
                                                       commit that got a Mac, as GitHub lists them, a line for each job and attempt with the
                                                       parts it was given: `<run id> <attempt> <first part>-<last part>`; of an attempt in which no
                                                       job got one, `<run id> <attempt> -`. Every attempt of a run has a line.
                                                       Without it the verdict is never VIABLE: nobody has looked for runs that were left out
  viable.py --self-test

Exit code 0 for VIABLE, 1 for NOT VIABLE, 2 for INVALID (nothing shows that the nets catch anything), for a ledger that cannot be
read and for a mistake in the call.

Where evidence is missing, said twice or contradicts itself, it is read against the commit, never for it.

The ledger:

  {"gate": 1, "commit": "<40 hex>",
   "runs": [{"manifest": {…run.json…},
             "sampler": {"samples": n, "late": n},
             "acts": [{"id": "reach-safari#2", "act": "switch", "judged": true}, …],
             "findings": [{"detector": "jolt", "level": "FAIL", "id": "reach-safari#2", "what": "…", "explained": "…"}]}],
   "rings": {"linux": {"commit": "…", "walks": n, "acts_per_walk": n, "violations": n, "known_failures_of_severity_1_or_2": n},
             "stand_ins": {"commit": "…", "open_divergences_that_touch_a_detector": n},
             "polish": {"commit": "…", "judged": [{"move": 1, "appearance": "light", "rows_failing": []}, …]}}}

One run of GitHub's may play several scripts, on one Mac or spread over several: each has a manifest of its own with `"part"` and `"parts"`, counted over
the whole run and written down before its first script begins. A script that is alone in its run is part 1 of 1, and says so.

An act's id is its slug and which act of that slug it is in its run, so that it means the same act in the run without Arbor, which
leaves out the acts that are Arbor's own keys. The manifest of a sabotage run also has `"offences": [{"detector": "jolt", "id": "idle#3"}, …]`.

Everything in a ledger comes from hosted Macs and from Linux. Nothing from a person's Mac belongs in one.
"""

import copy
import json
import os
import re
import sys
import tempfile

PAGE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "VIABLE.md")
COUNTED = ("day", "walk", "sit")
KINDS = COUNTED + ("control", "sabotage")
# Attempts of a run, and scripts in one.
MOST = 64
# Numbers of the page's block that another tool has to keep to, and which.
READ_ELSEWHERE = {
    "sampler.blind_ms_max": "jolts.py: an act during which the sampler was blind for longer is not judged",
    "sampler.late_ms": "sampler.swift: a sample that comes later than this after the one before is counted as late",
    "input.release_ms_max": "jolts.py: a single release that reaches the apps later than this, with a process of Arbor's there, is input-held",
}


class Unreadable(Exception):
    """The ledger, the page or the call is not what it has to be: there is nothing to judge."""


class Numbers(dict):
    """The page's block, which remembers what was asked of it, so that the test can tell a number nobody reads."""

    def __init__(self, values, path="", used=None):
        super().__init__(values)
        self.path, self.used = path, used if used is not None else set()

    def __getitem__(self, key):
        value, path = super().__getitem__(key), f"{self.path}{key}"
        if isinstance(value, dict):
            return Numbers(value, f"{path}.", self.used)
        self.used.add(path)
        return value

    def items(self):
        return [(key, self[key]) for key in self]

    def plain(self):
        """A copy in ordinary dictionaries. It asks nothing: `json.dumps` goes through `items` and leaves every number looking read."""
        return {key: Numbers(value).plain() if isinstance(value, dict) else copy.deepcopy(value) for key, value in dict.items(self)}

    def leaves(self):
        for key in self:
            value = super().__getitem__(key)
            if isinstance(value, dict):
                yield from Numbers(value, f"{self.path}{key}.").leaves()
            else:
                yield f"{self.path}{key}"


def numbers(page=PAGE):
    """The gate's numbers: the first block of JSON on the page."""
    with open(page, encoding="utf-8") as handle:
        block = re.search(r"```json\n(.*?)```", handle.read(), flags=re.S)
    if not block:
        raise Unreadable(f"{page} has no block of JSON")
    return Numbers(json.loads(block.group(1)))


def count(value, what):
    """A number that is a number. `true` is none."""
    if isinstance(value, bool) or not isinstance(value, (int, float)) or value < 0:
        raise Unreadable(f"{what} is {value!r}, which is no count")
    return value


def playing(manifest):
    """(run, attempt, part, parts): which playing of a script this is. One run of GitHub's may play several scripts, on one Mac or on several."""
    if not manifest.get("run"):
        raise Unreadable("a run without GitHub's id")
    found = []
    for name in ("attempt", "part", "parts"):
        value = manifest.get(name)
        # A number far beyond what a run can hold is a slip: a time or an id in the wrong place.
        if isinstance(value, bool) or not isinstance(value, int) or not 1 <= value <= MOST:
            raise Unreadable(f"run {manifest['run']}: {name} is {value!r}; a number from 1 to {MOST} is wanted")
        found.append(value)
    attempt, part, parts = found
    if part > parts:
        raise Unreadable(f"run {manifest['run']}: part {part} of {parts}")
    return str(manifest["run"]), attempt, part, parts


def name_of(run):
    identifier, attempt, part, parts = playing(run["manifest"])
    return f"run {identifier}.{attempt} ({run['manifest'].get('script', '?')}{f', part {part} of {parts}' if parts > 1 else ''})"


def why_not(run, gate, commit):
    """Why a run does not count, or None."""
    manifest, acts, sampler = run["manifest"], run.get("acts") or [], run.get("sampler") or {}
    if manifest.get("gate") != gate["gate"]:
        return f"it was made for gate {manifest.get('gate')}, and this is gate {gate['gate']}"
    if manifest.get("commit") != commit:
        return "it ran on another commit"
    if manifest.get("kind") not in KINDS:
        return f"no kind of run is called {manifest.get('kind')}"
    if manifest.get("settings") != "shipped":
        return "Arbor's settings were not as they ship"
    if "seconds" not in manifest or count(manifest["seconds"], "seconds") > gate["run_seconds_max"]:
        return f"it took {manifest.get('seconds', 'nobody knows how many')} seconds; {gate['run_seconds_max']} are allowed"
    if manifest.get("tiling") not in gate["tiling"] or manifest.get("display") not in gate["display"]:
        return f"there is no cell {manifest.get('tiling')} / {manifest.get('display')}"
    if manifest.get("cast") not in gate["cast"]:
        return f"there is no cast {manifest.get('cast')}"
    if manifest.get("tiling") == "defaults" and manifest.get("tiling_seen_to_act") is not True:
        return "macOS's own tiling was not seen to act before Arbor started"
    if not isinstance(manifest.get("reduce_motion"), bool):
        return "it does not say whether macOS's Reduce Motion was on"
    # Without Arbor there is no stage either way.
    if manifest["kind"] != "control" and manifest.get("stage_seen") is not (not manifest["reduce_motion"]):
        return ("Reduce Motion was on, and Arbor's stage was seen all the same" if manifest["reduce_motion"] and manifest.get("stage_seen") is True
                else "Reduce Motion was off, and Arbor's stage was never seen" if manifest.get("stage_seen") is False
                else "it does not say whether Arbor's stage was seen")
    if len(set(manifest.get("apps") or [])) < gate["apps_per_run_min"]:
        return f"fewer than {gate['apps_per_run_min']} apps opened a window"
    if not acts:
        return "it brought back no acts: nobody knows what happened in it"
    if "samples" not in sampler or "late" not in sampler or not count(sampler["samples"], "samples"):
        return "the sampler gave no account of itself"
    if count(sampler["late"], "late") / sampler["samples"] > gate["sampler"]["share_of_samples_late_max"]:
        return f"{sampler['late']} of {sampler['samples']} samples came late"
    if manifest["kind"] != "sabotage" and not heard(run):
        return "it does not say how late presses, releases and keys reached the apps: the witness saw nothing"
    # In a run without Arbor there is nothing of Arbor's to judge: it is there to be compared with.
    if manifest["kind"] != "control":
        judged = sum(1 for act in acts if act.get("judged") is True)
        if judged / len(acts) < gate["share_of_acts_judged_min"]:
            return f"only {judged} of {len(acts)} acts were judged"
    return None


def heard(run):
    """{kind of event: within how many µs 99 in 100 of them reached the apps}, as jolts.py counted them. Empty if the run does not say."""
    kinds = (run.get("input") or {}).get("kinds")
    if not isinstance(kinds, dict):
        return {}
    return {kind: count(told.get("p99_us") if isinstance(told, dict) else None, f"{name_of(run)}: the lateness of {kind}") for kind, told in kinds.items()}


def journey(manifest):
    """What has to be the same for two runs to have played the same acts."""
    return tuple(manifest.get(key) for key in ("script", "seed", "tiling", "display", "cast", "reduce_motion"))


def judge(ledger, gate, listed=None):
    """(verdict, reasons, lines of the table). `listed`: {(GitHub's run id, attempt): the parts whose jobs got a Mac}, or None if nobody asked."""
    if not isinstance(ledger, dict) or not isinstance(ledger.get("runs"), list) or not isinstance(ledger.get("rings"), dict):
        raise Unreadable("a ledger has `runs`, a list, and `rings`")
    commit = ledger.get("commit")
    if not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise Unreadable(f"the ledger's commit is {commit!r}: forty hexadecimal digits are wanted")
    for run in ledger["runs"]:
        if not isinstance(run, dict) or not isinstance(run.get("manifest"), dict):
            raise Unreadable("a run without a manifest")
        for finding in run.get("findings") or []:
            if not finding.get("detector") or finding.get("level") not in ("FAIL", "ODD") or not finding.get("id"):
                raise Unreadable(f"{name_of(run)}: a finding needs a detector, a level (FAIL or ODD) and its act's id: {finding}")

    reasons, invalid, table = [], [], []
    per_hour = gate["acts_per_user_hour"]
    cells = {(tiling, display): 0 for tiling in gate["tiling"] for display in gate["display"]}
    controls = dict.fromkeys(cells, 0)
    casts = dict.fromkeys(gate["cast"], 0)
    casts_at = {cast: set() for cast in gate["cast"]}
    kinds = dict.fromkeys(gate["acts_min"], 0)
    apps, provoked = set(), set()
    total = from_walks = sabotage = fails = odd = fell_out = 0
    bare, without_stage = dict.fromkeys(gate["tiling"], 0), 0

    if ledger.get("gate") != gate["gate"]:
        reasons.append(f"the ledger is of gate {ledger.get('gate')}, the page describes gate {gate['gate']}")

    seen = {}
    for run in ledger["runs"]:
        key = playing(run["manifest"])[:3]
        if key in seen:
            invalid.append(f"{name_of(run)} is in the ledger twice")
        if not isinstance(run["manifest"].get("started"), bool):
            raise Unreadable(f"{name_of(run)} does not say whether its script began")
        seen[key] = run
    # How many scripts a run plays is written down before the first begins, so that none can be left out afterwards. It is the same in every attempt.
    sizes = {}
    for (identifier, _, _), run in seen.items():
        sizes.setdefault(identifier, set()).add(playing(run["manifest"])[3])
    # A hosted Mac's failure does not sink a commit: a part whose script never began may be played in a later attempt of the same run. That it never began is
    # said by the stub the job left in its place, or by GitHub, which gave its job no Mac. An absence says nothing.
    played = {(identifier, part) for (identifier, _, part), run in seen.items() if run["manifest"]["started"]}
    for identifier, found in sorted(sizes.items()):
        if len(found) > 1:
            invalid.append(f"run {identifier}: its parts do not agree how many they are")
        for part in range(1, max(found) + 1):
            if (identifier, part) not in played:
                reasons.append(f"run {identifier} has {max(found)} parts, and no attempt played part {part}")
    if listed is None:
        reasons.append("nobody compared the ledger with GitHub's list of jobs (--runs), so runs may have been left out")
    else:
        for (identifier, attempt), parts in sorted(listed.items()):
            for part in sorted(parts):
                if (identifier, attempt, part) not in seen:
                    reasons.append(f"in run {identifier}.{attempt} a job got a Mac for part {part}, and the ledger leaves it out: there is not even a stub")
        # An attempt that is nowhere may be the one that went badly. GitHub lists a run's latest attempt unless it is asked for all.
        for identifier, attempt in sorted(set(listed) | {key[:2] for key in seen}):
            for earlier in range(1, attempt):
                if (identifier, earlier) not in listed:
                    reasons.append(f"run {identifier} has an attempt {attempt}, and GitHub's list says nothing of attempt {earlier}: not even that no job of it got a Mac")
        for identifier, attempt, part in sorted(seen):
            if part not in listed.get((identifier, attempt), ()):
                invalid.append(f"the ledger has part {part} of run {identifier}.{attempt}, and GitHub knows of no job that got a Mac for it")
    for (identifier, attempt, part), run in sorted(seen.items()):
        if not run["manifest"]["started"]:
            # Its script never began, it says, and here is what the script saw.
            if run.get("acts") or run.get("findings") or run.get("sampler") or run.get("input"):
                invalid.append(f"part {part} of run {identifier}.{attempt} says that its script never began, and brought back what a script brings back")
            table.append(f"  never began: part {part} of run {identifier}.{attempt}" + (", played in another attempt" if (identifier, part) in played else ""))

    # What began counts, in every attempt, and nothing replaces it.
    runs = [run for run in seen.values() if run["manifest"]["started"]]
    excuses = {id(run): why_not(run, gate, commit) for run in runs}
    # What the Mac does by itself: found at the same act of the same journey with Arbor not running.
    alone = {}
    for run in runs:
        if run["manifest"].get("kind") == "control" and not excuses[id(run)]:
            found = alone.setdefault(journey(run["manifest"]), set())
            found.update((finding["detector"], finding["id"]) for finding in run.get("findings") or [])

    # Who holds input back. A figure over a run says what the journey is made of as much as who held anything: a press on a window of an app that is not in front takes
    # macOS twenty to a hundred times as long as any other. So like is compared with like: a journey with its own control, kind of event by kind of event. Of several controls the
    # quickest is the measure.
    quiet, met, compared = {}, set(), set()
    for run in runs:
        if run["manifest"].get("kind") == "control" and not excuses[id(run)]:
            measure = quiet.setdefault(journey(run["manifest"]), {})
            for kind, late in heard(run).items():
                measure[kind] = min(late, measure.get(kind, late))
    for run in runs:
        if run["manifest"].get("kind") not in COUNTED or excuses[id(run)] or journey(run["manifest"]) not in quiet:
            continue
        met.add(journey(run["manifest"]))
        for kind, late in sorted(heard(run).items()):
            alone_late = quiet[journey(run["manifest"])].get(kind)
            if alone_late is None:
                continue
            compared.add(kind)
            if late > alone_late + 1000 * gate["input"]["p99_more_ms_max"]:
                fails += 1
                reasons.append(f"input-held in {name_of(run)}: 99 in 100 events of the kind {kind} reached the apps within {late / 1000:.1f} ms, "
                               f"in the same journey without Arbor within {alone_late / 1000:.1f}")
    for run in runs:
        if run["manifest"].get("kind") == "control" and not excuses[id(run)] and journey(run["manifest"]) not in met:
            reasons.append(f"{name_of(run)} is the control of no journey that counts: there is nothing to compare it with")
    for kind in sorted({kind for run in runs if run["manifest"].get("kind") in COUNTED and not excuses[id(run)] for kind in heard(run)} - compared):
        reasons.append(f"events of the kind {kind} were compared with no run without Arbor: nobody knows whether they are held back")

    for run in runs:
        manifest, findings = run["manifest"], run.get("findings") or []
        kind = manifest.get("kind")
        if excuses[id(run)]:
            fell_out += 1
            table.append(f"  does not count: {name_of(run)}: {excuses[id(run)]}")
            # Whatever else was wrong with the run, Arbor fell over on this commit.
            if manifest.get("commit") == commit and kind in COUNTED:
                for finding in findings:
                    if finding["detector"] == "crash" and finding["level"] == "FAIL":
                        fails += 1
                        reasons.append(f"crash in {name_of(run)}, which counts although the run does not: {finding.get('what', '')}")
            continue
        cell = (manifest["tiling"], manifest["display"])
        if kind == "control":
            controls[cell] += 1
            continue
        if kind == "sabotage":
            sabotage += 1
            offences = manifest.get("offences")
            if not isinstance(offences, list) or not offences or not all(isinstance(o, dict) and o.get("detector") and o.get("id") for o in offences):
                invalid.append(f"{name_of(run)} does not say which offences were committed, and at which acts")
                continue
            reported = {(finding["detector"], finding["id"]) for finding in findings if finding["level"] == "FAIL"}
            missed = sorted(f"{o['detector']} at {o['id']}" for o in offences if (o["detector"], o["id"]) not in reported)
            if len(missed) > gate["controls"]["sabotage_offences_missed_max"]:
                invalid.append(f"{name_of(run)}: committed and not reported: {', '.join(missed)}")
            provoked.update(o["detector"] for o in offences if (o["detector"], o["id"]) in reported)
            # One offence may set off several detectors. A report at an act where nothing was done is a false alarm.
            scenes = {o["id"] for o in offences}
            wolf = sorted(f"{detector} at {act}" for detector, act in reported if act not in scenes)
            if wolf:
                invalid.append(f"{name_of(run)}: reported where nothing was committed: {', '.join(wolf)}")
            continue
        judged = [act for act in run["acts"] if act.get("judged") is True]
        total += len(judged)
        cells[cell] += len(judged)
        casts[manifest["cast"]] += len(judged)
        casts_at[manifest["cast"]].add(manifest["tiling"])
        apps.update(manifest["apps"])
        if kind == "walk":
            from_walks += len(judged)
        # With macOS's Reduce Motion on there is no stage, and whatever a window does on its way is seen.
        if manifest["reduce_motion"]:
            without_stage += len(judged)
            bare[manifest["tiling"]] += sum(1 for act in judged if act.get("act") in gate["reduce_motion"]["kinds_that_move"])
        for act in judged:
            if act.get("act") in kinds:
                kinds[act["act"]] += 1
            # Counted within `drag`, as the page says.
            if act.get("act") == "drag-where-macos-tiles":
                kinds["drag"] += 1
        for finding in findings:
            words = f"{finding['detector']} in {name_of(run)}, at {finding['id']}: {finding.get('what', '')}"
            if (finding["detector"], finding["id"]) in alone.get(journey(manifest), ()):
                table.append(f"  not Arbor's, the run without it shows the same: {words}")
            elif finding["level"] == "FAIL":
                fails += 1
                reasons.append(words)
            elif not finding.get("explained"):
                odd += 1
                reasons.append(f"odd and not explained: {words}")
    # The two limits are nought today. Should the page ever allow some, those within the limit are listed and do not decide.
    allowed = (fails <= gate["fail_max"], odd <= gate["odd_unexplained_max"])
    if fails or odd:
        kept = []
        for reason in reasons:
            is_odd = reason.startswith("odd and not explained: ")
            is_fail = not is_odd and re.match(r"[a-z-]+ in run |crash in run ", reason)
            if (is_odd and allowed[1]) or (is_fail and allowed[0]):
                table.append(f"  within what the page allows: {reason}")
            else:
                kept.append(reason)
        reasons = kept

    def hours(acts):
        return acts / per_hour

    table.append(f"  judged acts: {total} = {hours(total):.1f} user-hours of {gate['user_hours']}")
    if hours(total) < gate["user_hours"]:
        reasons.append(f"{hours(total):.1f} user-hours were played; {gate['user_hours']} are asked for")
    for (tiling, display), acts in cells.items():
        table.append(f"  {tiling:9}{display:8}{hours(acts):5.1f} h, {controls[(tiling, display)]} without Arbor")
        if hours(acts) < gate["user_hours_per_cell_min"]:
            reasons.append(f"the cell {tiling} / {display} has {hours(acts):.1f} user-hours; {gate['user_hours_per_cell_min']} are asked for")
        if controls[(tiling, display)] < gate["controls"]["without_arbor_per_cell_min"]:
            reasons.append(f"the cell {tiling} / {display} was played {controls[(tiling, display)]} times without Arbor; {gate['controls']['without_arbor_per_cell_min']} are asked for")
    for cast, acts in casts.items():
        table.append(f"  cast {cast:12}{hours(acts):5.1f} h")
        if hours(acts) < gate["user_hours_per_cast_min"]:
            reasons.append(f"the cast {cast} has {hours(acts):.1f} user-hours; {gate['user_hours_per_cast_min']} are asked for")
        absent = [tiling for tiling in gate["tiling"] if tiling not in casts_at[cast]]
        if absent:
            reasons.append(f"the cast {cast} was never played at {' or '.join(absent)}")
    table.append(f"  real apps: {len(apps)}")
    if len(apps) < gate["real_apps_min"]:
        reasons.append(f"{len(apps)} different apps took part; {gate['real_apps_min']} are asked for")
    for tiling, acts in bare.items():
        least = gate["reduce_motion"]["acts_that_move_per_tiling_min"]
        table.append(f"  Reduce Motion on, {tiling:9}{acts:5} acts that move windows, of {least}")
        if acts < least:
            reasons.append(f"{acts} acts that move windows were played with Reduce Motion on at {tiling}; {least} are asked for")
    if total and without_stage / total > gate["reduce_motion"]["share_of_acts_max"]:
        reasons.append(f"{without_stage / total:.0%} of the acts were played with Reduce Motion on; at most {gate['reduce_motion']['share_of_acts_max']:.0%} may be: a Mac comes with it off")
    if total and from_walks / total < gate["share_of_acts_from_walks_min"]:
        reasons.append(f"{from_walks / total:.0%} of the acts came from walks; {gate['share_of_acts_from_walks_min']:.0%} are asked for")
    for kind, least in gate["acts_min"].items():
        table.append(f"  {kind:24}{kinds[kind]:5} of {least}")
        if kinds[kind] < least:
            reasons.append(f"{kinds[kind]} acts of the kind {kind}; {least} are asked for")
    if sabotage < gate["controls"]["sabotage_runs_min"]:
        invalid.append(f"{sabotage} sabotage runs count; {gate['controls']['sabotage_runs_min']} are asked for: nothing shows that the detectors catch anything")
    else:
        asleep = [detector for detector in gate["detectors"] if detector not in provoked]
        if asleep:
            invalid.append(f"never shown to catch anything: {', '.join(asleep)}")
    if runs and fell_out / len(runs) > gate["share_of_runs_that_do_not_count_max"]:
        invalid.append(f"{fell_out} of {len(runs)} runs do not count: too many fell out to believe the rest")

    rings = ledger["rings"]
    linux, wanted = rings.get("linux"), gate["linux"]
    if not linux:
        reasons.append("ring 1: the walks on Linux were not reported")
    else:
        if linux.get("commit") != commit:
            reasons.append("ring 1: the walks ran on another commit")
        walks, length = count(linux.get("walks", 0), "walks"), count(linux.get("acts_per_walk", 0), "acts_per_walk")
        if walks < wanted["walks"] or length < wanted["acts_per_walk"]:
            reasons.append(f"ring 1: {walks} walks of {length}; {wanted['walks']} of {wanted['acts_per_walk']} are asked for")
        if "violations" not in linux or count(linux["violations"], "violations") > wanted["violations_max"]:
            reasons.append(f"ring 1: {linux.get('violations', 'an unknown number of')} violations")
        excused = "known_failures_of_severity_1_or_2"
        if excused not in linux or count(linux[excused], excused) > wanted[f"{excused}_max"]:
            reasons.append("ring 1: a known failure of severity 1 or 2 is being excused, or nobody says that none is")
    stand_ins, open_rows = rings.get("stand_ins"), "open_divergences_that_touch_a_detector"
    if not stand_ins:
        reasons.append("ring 2: the ledger of differences between the stand-ins and real Macs was not reported")
    else:
        if stand_ins.get("commit") != commit:
            reasons.append("ring 2: the differences were counted on another commit")
        if open_rows not in stand_ins or count(stand_ins[open_rows], open_rows) > gate["stand_ins"][f"{open_rows}_max"]:
            reasons.append(f"ring 2: {stand_ins.get(open_rows, 'an unknown number of')} open differences touch a detector")
    polish = rings.get("polish")
    if not polish:
        reasons.append("ring 4: the polish rubric was not judged")
    else:
        if polish.get("commit") != commit:
            reasons.append("ring 4: the rubric was judged on another commit")
        failing = {}
        for entry in polish.get("judged") or []:
            if not isinstance(entry.get("rows_failing"), list):
                raise Unreadable(f"ring 4: {entry} does not say which rows fail")
            # Judged twice, it fails whatever failed either time.
            failing.setdefault((entry.get("move"), entry.get("appearance")), set()).update(entry["rows_failing"])
        for move in range(1, gate["polish"]["moves"] + 1):
            for appearance in gate["polish"]["appearance"]:
                rows = failing.get((move, appearance))
                if rows is None:
                    reasons.append(f"ring 4: move {move} was not judged in {appearance}")
                elif len(rows) > gate["polish"]["rows_failing_max"]:
                    reasons.append(f"ring 4: move {move} in {appearance} fails: {', '.join(sorted(rows))}")

    if invalid:
        return "INVALID", invalid + reasons, table
    return ("NOT VIABLE" if reasons else "VIABLE"), reasons, table


def report(ledger, gate, listed=None):
    verdict, reasons, table = judge(ledger, gate, listed)
    lines = [f"The viable gate, number {gate['gate']}, on {ledger['commit']}", *table]
    if reasons:
        lines.append(f"{len(reasons)} reasons:")
        lines += [f"  ✘ {reason}" for reason in reasons]
    lines.append(verdict)
    return verdict, "\n".join(lines)


def read_json(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError) as problem:
        raise Unreadable(f"{path}: {problem}") from problem


def read_listed(path):
    """{(run id, attempt): parts} from lines `<run id> <attempt> <first part>-<last part>`, one for each job that got a Mac; `<run id> <attempt> -` for an attempt in which none did."""
    listed = {}
    try:
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                if not line.strip():
                    continue
                nobody = re.fullmatch(r"(\d+) (\d+) -", line.strip())
                if nobody and 1 <= int(nobody.group(2)) <= MOST:
                    listed.setdefault((nobody.group(1), int(nobody.group(2))), set())
                    continue
                found = re.fullmatch(r"(\d+) (\d+) (\d+)-(\d+)", line.strip())
                if not found:
                    raise Unreadable(f"{path}: “{line.strip()}” is not `<run id> <attempt> <first part>-<last part>`")
                attempt, first, last = (int(word) for word in found.groups()[1:])
                if not 1 <= attempt <= MOST or not 1 <= first <= last <= MOST:
                    raise Unreadable(f"{path}: “{line.strip()}”: attempts and parts are numbers from 1 to {MOST}, the first part not after the last")
                parts = listed.setdefault((found.group(1), attempt), set())
                if parts & set(range(first, last + 1)):
                    raise Unreadable(f"{path}: “{line.strip()}”: two jobs of one attempt were given the same part")
                parts.update(range(first, last + 1))
    except OSError as problem:
        raise Unreadable(f"{path}: {problem}") from problem
    if not listed:
        raise Unreadable(f"{path} lists no job at all: a gate has runs, so the listing went wrong")
    return listed


def account(sampler):
    """The sampler's account of itself, which jolts.py passes on as it was written: `samples 30000 seconds 540.0 … late 10 …`."""
    if isinstance(sampler, dict):
        return sampler
    words = sampler.split() if isinstance(sampler, str) else []
    told = {}
    for name, value in zip(words[::2], words[1::2]):
        try:
            told[name] = float(value) if "." in value else int(value)
        except ValueError:
            pass
    return told


def run_from(directory):
    """One run of the ledger, from what its script and jolts.py left in a directory."""
    run = {"manifest": read_json(os.path.join(directory, "run.json")), "sampler": {}, "input": None, "acts": [], "findings": []}
    path = os.path.join(directory, "day-findings.json")
    # A run that ended before its report is in the ledger all the same: it was started, so it is accounted for.
    if not os.path.exists(path):
        return run
    found = read_json(path)
    run["sampler"] = account(found.get("sampler"))
    run["input"] = found.get("input")
    times = {}
    for step in found.get("steps") or []:
        slug = step.get("slug") or "?"
        times[slug] = times.get(slug, 0) + 1
        identifier = f"{slug}#{times[slug]}"
        run["acts"].append({"id": identifier, "act": step.get("act"), "judged": step.get("judged") is True})
        for finding in step.get("findings") or []:
            if not finding.get("detector"):
                raise Unreadable(f"{path}: step {step.get('number')}: a finding without `detector`: {finding.get('what')}")
            entry = {"detector": finding["detector"], "level": finding.get("level"), "id": identifier, "what": finding.get("what", "")}
            if finding.get("explained"):
                entry["explained"] = finding["explained"]
            run["findings"].append(entry)
    return run


def make_ledger(commit, directories, gate):
    ledger = {"gate": gate["gate"], "commit": commit, "runs": [], "rings": {}}
    looked = set()
    for directory in directories:
        if not os.path.isdir(directory):
            raise Unreadable(f"{directory} is no directory")
        if not os.path.exists(os.path.join(directory, "run.json")):
            raise Unreadable(f"{directory} has no run.json: a run that is not accounted for")
        ledger["runs"].append(run_from(directory))
        for place in (directory, os.path.dirname(os.path.abspath(directory))):
            path = os.path.realpath(os.path.join(place, "rings.json"))
            if path in looked or not os.path.exists(path):
                continue
            looked.add(path)
            for ring, told in read_json(path).items():
                if ledger["rings"].setdefault(ring, told) != told:
                    raise Unreadable(f"{path} says something else about the ring {ring} than another rings.json")
    return ledger


# MARK: Its own test


def perfect(gate):
    """A ledger that passes, made from the page's own numbers."""
    commit = "c" * 40
    apps = [f"app.{number}" for number in range(max(gate["real_apps_min"], gate["apps_per_run_min"]))]
    cells = [(tiling, display) for tiling in gate["tiling"] for display in gate["display"]]
    per_run = gate["acts_per_user_hour"]
    wanted = []
    for kind, least in gate["acts_min"].items():
        if kind == "drag":
            least = max(0, least - gate["acts_min"]["drag-where-macos-tiles"])
        wanted += [kind] * least
    # Every cell meets every cast equally often, so whichever asks for most decides how many runs there are.
    rounds = max(
        -(-gate["user_hours"] // (len(cells) * len(gate["cast"]))),
        -(-gate["user_hours_per_cell_min"] // len(gate["cast"])),
        -(-gate["user_hours_per_cast_min"] // len(cells)),
        -(-len(wanted) // (per_run * len(cells) * len(gate["cast"]))),
    )
    plan = [(cell, cast) for _ in range(rounds) for cast in gate["cast"] for cell in cells]
    wanted += ["switch"] * (len(plan) * per_run - len(wanted))
    walks = -(-len(plan) * gate["share_of_acts_from_walks_min"] // 1)
    sampler = {"samples": 30000, "late": 0}
    arrived = {"kinds": {kind: {"events": 100, "p99_us": late} for kind, late in (("down", 2000), ("forward", 20000), ("up", 1500), ("key", 900))}}
    runs = []

    def manifest(number, kind, cell, cast):
        return {
            "gate": gate["gate"], "started": True, "commit": commit, "run": str(1000 + number), "attempt": 1, "part": 1, "parts": 1, "script": f"{kind}.sh", "kind": kind, "seed": None,
            "tiling": cell[0], "tiling_seen_to_act": True, "display": cell[1], "cast": cast, "apps": apps, "settings": "shipped",
            "seconds": gate["run_seconds_max"], "reduce_motion": False, "stage_seen": kind != "control",
        }

    still = dict.fromkeys(gate["tiling"], gate["reduce_motion"]["acts_that_move_per_tiling_min"])
    for number, (cell, cast) in enumerate(plan):
        acts = [{"id": f"{kind}#{index}", "act": kind, "judged": True} for index, kind in enumerate(wanted[number * per_run:(number + 1) * per_run])]
        runs.append({"manifest": manifest(number, "walk" if number < walks else "day", cell, cast), "sampler": dict(sampler), "input": copy.deepcopy(arrived), "acts": acts, "findings": []})
        moving = sum(1 for act in acts if act["act"] in gate["reduce_motion"]["kinds_that_move"])
        if still[cell[0]] > 0 and moving:
            still[cell[0]] -= moving
            runs[-1]["manifest"].update(reduce_motion=True, stage_seen=False)
    for again in range(gate["controls"]["without_arbor_per_cell_min"]):
        for number, cell in enumerate(cells):
            # The same journey as one in its cell, with Arbor not running.
            model = next(run["manifest"] for run in runs if (run["manifest"]["tiling"], run["manifest"]["display"]) == cell)
            runs.append({
                "manifest": dict(manifest(5000 + again * len(cells) + number, "control", cell, model["cast"]), script=model["script"], seed=model["seed"],
                                 reduce_motion=model["reduce_motion"]),
                "sampler": dict(sampler), "input": copy.deepcopy(arrived), "acts": [{"id": "switch#0", "act": "switch", "judged": False}], "findings": [],
            })
    for again in range(gate["controls"]["sabotage_runs_min"]):
        offences = [{"detector": detector, "id": f"idle#{index}"} for index, detector in enumerate(gate["detectors"])]
        runs.append({
            "manifest": dict(manifest(6000 + again, "sabotage", (gate["tiling"][-1], gate["display"][0]), gate["cast"][0]), offences=offences),
            "sampler": dict(sampler), "acts": [{"id": offence["id"], "act": "idle", "judged": True} for offence in offences],
            "findings": [dict(offence, level="FAIL", what="planted") for offence in offences],
        })
    polish = [
        {"move": move, "appearance": appearance, "rows_failing": []}
        for move in range(1, gate["polish"]["moves"] + 1) for appearance in gate["polish"]["appearance"]
    ]
    return {
        "gate": gate["gate"], "commit": commit, "runs": runs,
        "rings": {
            "linux": {
                "commit": commit, "walks": gate["linux"]["walks"], "acts_per_walk": gate["linux"]["acts_per_walk"],
                "violations": 0, "known_failures_of_severity_1_or_2": 0,
            },
            "stand_ins": {"commit": commit, "open_divergences_that_touch_a_detector": 0},
            "polish": {"commit": commit, "judged": polish},
        },
    }


def self_test():
    gate = numbers()
    good = perfect(gate)
    everything = {(run["manifest"]["run"], 1): {1} for run in good["runs"]}
    failures = []

    def expect(name, change, verdict, words, listed=everything, page=gate):
        ledger = copy.deepcopy(good)
        change(ledger)
        try:
            got, reasons, table = judge(ledger, page, listed)
        except Unreadable as problem:
            got, reasons, table = "UNREADABLE", [str(problem)], []
        if got != verdict or (words and not any(words in line for line in reasons + table)) or (verdict == "VIABLE" and reasons):
            failures.append(f"{name}: {got}, wanted {verdict} with “{words}”; its reasons: {reasons[:4]}")

    def every(ledger, *kinds):
        return [run for run in ledger["runs"] if run["manifest"].get("kind") in kinds]

    def find(ledger, kind, **finding):
        run = every(ledger, kind)[0]
        run["findings"].append({"id": run["acts"][0]["id"], "what": "w", **finding})

    def retitle(ledger, old, new):
        for run in ledger["runs"]:
            for act in run["acts"]:
                if act["act"] == old:
                    act["act"] = new

    def amend(ledger, kinds, **changes):
        for run in every(ledger, *kinds):
            run["manifest"].update(changes)

    def twin(ledger, kind, **changes):
        extra = copy.deepcopy(every(ledger, kind)[0])
        extra["manifest"].update(changes)
        ledger["runs"].append(extra)
        return extra

    nothing = lambda ledger: None  # noqa: E731
    first_cell, last_cell = (gate["tiling"][0], gate["display"][0]), (gate["tiling"][0], gate["display"][-1])

    expect("the perfect ledger", nothing, "VIABLE", "")
    expect("one jolt", lambda l: find(l, "day", detector="jolt", level="FAIL"), "NOT VIABLE", "jolt in run")
    expect("a failure that somebody explained away", lambda l: find(l, "day", detector="jolt", level="FAIL", explained="never mind"), "NOT VIABLE", "jolt in run")
    expect("one oddity nobody explained", lambda l: find(l, "walk", detector="focus", level="ODD"), "NOT VIABLE", "odd and not explained")
    expect("an oddity with its explanation", lambda l: find(l, "walk", detector="focus", level="ODD", explained="the app does that"), "VIABLE", "")

    def the_mac_does_it_alone(ledger, same_act=True):
        run = every(ledger, "day")[0]
        finding = {"detector": "jolt", "level": "FAIL", "id": run["acts"][0]["id"], "what": "an app moves its own window twice"}
        run["findings"].append(finding)
        control = twin(ledger, "control", run="8000", **{key: run["manifest"][key] for key in ("script", "seed", "tiling", "display", "cast", "reduce_motion")})
        control["findings"] = [dict(finding, id=finding["id"] if same_act else "elsewhere#1")]

    expect("what the run without Arbor shows too", the_mac_does_it_alone, "VIABLE", "", listed={**everything, ("8000", 1): {1}})
    expect("what it shows at another act", lambda l: the_mac_does_it_alone(l, same_act=False), "NOT VIABLE", "jolt in run", listed={**everything, ("8000", 1): {1}})
    expect("a cell nobody played", lambda l: l.update(runs=[r for r in l["runs"] if r["manifest"]["kind"] not in COUNTED or (r["manifest"]["tiling"], r["manifest"]["display"]) != last_cell]),
           "NOT VIABLE", f"the cell {last_cell[0]} / {last_cell[1]} has 0.0", listed=None)
    expect("a cell without its control", lambda l: amend(l, ["control"], display=gate["display"][0]), "NOT VIABLE", "times without Arbor")
    expect("no drags where macOS tiles", lambda l: retitle(l, "drag-where-macos-tiles", "switch"), "NOT VIABLE", "of the kind drag-where-macos-tiles")
    expect("every journey learnt by heart", lambda l: amend(l, ["walk"], kind="day"), "NOT VIABLE", "came from walks")
    expect("a cast played at one setting of tiling only", lambda l: [run["manifest"].update(cast=gate["cast"][1 if run["manifest"]["tiling"] == gate["tiling"][0] else 0])
                                                                    for run in every(l, *COUNTED) if run["manifest"]["cast"] in gate["cast"][:2]], "NOT VIABLE", "was never played at")
    def still_runs(ledger):
        return [run for run in every(ledger, *COUNTED) if run["manifest"]["reduce_motion"]]

    expect("nobody played with Reduce Motion on", lambda l: amend(l, COUNTED, reduce_motion=False, stage_seen=True), "NOT VIABLE", "with Reduce Motion on at")
    expect("Reduce Motion on at one setting of tiling only", lambda l: [run["manifest"].update(reduce_motion=False, stage_seen=True) for run in still_runs(l) if run["manifest"]["tiling"] == gate["tiling"][0]],
           "NOT VIABLE", f"with Reduce Motion on at {gate['tiling'][0]}")
    expect("Reduce Motion on, and nothing but idling", lambda l: [act.update(act="idle") for run in still_runs(l) for act in run["acts"]], "NOT VIABLE", "0 acts that move windows were played with Reduce Motion on")
    expect("Reduce Motion on all the way", lambda l: amend(l, COUNTED, reduce_motion=True, stage_seen=False), "NOT VIABLE", "a Mac comes with it off")
    expect("one run that does not say whether Reduce Motion was on", lambda l: every(l, "day")[-1]["manifest"].pop("reduce_motion"), "VIABLE", "does not say whether macOS's Reduce Motion was on")
    for nonsense in ("on", 1, None):
        expect(f"Reduce Motion is {nonsense!r}", lambda l, nonsense=nonsense: [run["manifest"].update(reduce_motion=nonsense) for run in still_runs(l)], "NOT VIABLE", "with Reduce Motion on at")
    expect("Reduce Motion written and not obeyed", lambda l: [run["manifest"].update(stage_seen=True) for run in still_runs(l)], "NOT VIABLE", "Arbor's stage was seen all the same")
    expect("Reduce Motion off, and never a stage", lambda l: every(l, "day")[-1]["manifest"].update(stage_seen=False), "VIABLE", "Arbor's stage was never seen")
    expect("nobody looked for the stage", lambda l: every(l, "day")[-1]["manifest"].pop("stage_seen"), "VIABLE", "does not say whether Arbor's stage was seen")

    def a_control_with_the_stage(ledger):
        run = still_runs(ledger)[0]
        finding = {"detector": "jolt", "level": "FAIL", "id": run["acts"][0]["id"], "what": "seen bare"}
        run["findings"].append(finding)
        control = twin(ledger, "control", run="8000", **{key: run["manifest"][key] for key in ("script", "seed", "tiling", "display", "cast")})
        control["findings"] = [dict(finding)]

    expect("a control played with Reduce Motion off excuses nothing seen with it on", a_control_with_the_stage, "NOT VIABLE", "jolt in run", listed={**everything, ("8000", 1): {1}})
    expect("too few apps", lambda l: amend(l, KINDS, apps=good["runs"][0]["manifest"]["apps"][:gate["apps_per_run_min"]]), "NOT VIABLE", "different apps")
    expect("acts that were not judged", lambda l: [act.update(judged=False) for run in every(l, *COUNTED) for act in run["acts"][:len(run["acts"]) // 20]], "NOT VIABLE", "are asked for")

    expect("no sabotage", lambda l: l.update(runs=[r for r in l["runs"] if r["manifest"]["kind"] != "sabotage"]), "INVALID", "sabotage runs count", listed=None)
    expect("an offence that no detector saw", lambda l: every(l, "sabotage")[0]["findings"].pop(), "INVALID", "committed and not reported")
    expect("an offence reported at another act", lambda l: every(l, "sabotage")[0]["findings"][0].update(id="idle#1"), "INVALID", "committed and not reported")
    expect("a detector that cries wolf", lambda l: every(l, "sabotage")[0]["findings"].append({"detector": "jolt", "level": "FAIL", "id": "quiet#1"}), "INVALID", "where nothing was committed")
    expect("one offence sets off two detectors", lambda l: every(l, "sabotage")[0]["findings"].append({"detector": "lost", "level": "FAIL", "id": "idle#0"}), "VIABLE", "")

    def provoke_only_one(ledger):
        for run in every(ledger, "sabotage"):
            run["manifest"]["offences"] = run["manifest"]["offences"][:1]
            run["findings"] = run["findings"][:1]

    expect("a sabotage that tries one detector", provoke_only_one, "INVALID", "never shown to catch anything")
    expect("a sabotage that does not say what it did", lambda l: every(l, "sabotage")[0]["manifest"].pop("offences"), "INVALID", "does not say which offences")

    for name, kinds, changes in [
        ("runs that took too long", COUNTED, {"seconds": gate["run_seconds_max"] + 1}),
        ("tiling written and never seen to act", COUNTED, {"tiling_seen_to_act": False}),
        ("other settings", COUNTED, {"settings": "all on"}),
        ("another commit's runs", COUNTED, {"commit": "d" * 40}),
        ("a cast nobody knows", COUNTED, {"cast": "friends"}),
        ("a kind nobody knows", COUNTED, {"kind": "stroll"}),
    ]:
        expect(name, lambda l, kinds=kinds, changes=changes: amend(l, kinds, **changes), "INVALID", "too many fell out")
    # The perfect ledger has hours to spare, so one run that falls out shows in the table and not in the verdict.
    expect("one run that took too long", lambda l: every(l, "day")[-1]["manifest"].update(seconds=gate["run_seconds_max"] + 1), "VIABLE", "does not count: run")
    expect("a blind sampler", lambda l: every(l, "day")[-1]["sampler"].update(late=15000), "VIABLE", "samples came late")
    expect("a sampler that does not say how many came late", lambda l: every(l, "day")[-1]["sampler"].pop("late"), "VIABLE", "gave no account of itself")
    expect("a run without its report", lambda l: every(l, "day")[-1].update(acts=[], findings=[], sampler={}), "VIABLE", "it brought back no acts")
    expect("a run most of which was not judged", lambda l: [act.update(judged=False) for act in every(l, "day")[-1]["acts"][::2]], "VIABLE", "acts were judged")

    def crash_in_a_run_that_does_not_count(ledger):
        extra = twin(ledger, "day", run="9999", seconds=gate["run_seconds_max"] * 2)
        extra["findings"] = [{"detector": "crash", "level": "FAIL", "id": "idle#3", "what": "Arbor ended"}]

    expect("a crash in a run that does not count", crash_in_a_run_that_does_not_count, "NOT VIABLE", "counts although the run does not", listed={**everything, ("9999", 1): {1}})

    expect("nobody asked GitHub", nothing, "NOT VIABLE", "nobody compared the ledger", listed=None)
    expect("a run left out", nothing, "NOT VIABLE", "the ledger leaves it out", listed={**everything, ("4242", 1): {1}})
    expect("a first attempt left out", lambda l: l["runs"][0]["manifest"].update(attempt=2), "NOT VIABLE", "in run 1000.1 a job got a Mac for part 1, and the ledger leaves it out", listed={**everything, ("1000", 2): {1}})
    expect("a first attempt left out, GitHub listing the run once", nothing, "NOT VIABLE", "1000.2", listed={**everything, ("1000", 2): {1}})
    expect("both attempts there", lambda l: twin(l, "walk", attempt=2), "VIABLE", "", listed={**everything, ("1000", 2): {1}})
    def batch(ledger, parts=2, keep=(1, 2)):
        """The first two counted runs become two scripts of one run of GitHub's."""
        first, second = every(ledger, "walk")[:2]
        second["manifest"]["run"] = first["manifest"]["run"]
        first["manifest"].update(part=1, parts=parts)
        second["manifest"].update(part=2, parts=parts)
        ledger["runs"] = [run for run in ledger["runs"] if run not in (first, second) or run["manifest"]["part"] in keep]

    batched = {key: {1, 2} if key[0] == "1000" else parts for key, parts in everything.items() if key[0] != "1001"}
    expect("two scripts in one run of GitHub's", batch, "VIABLE", "", listed=batched)
    expect("… of which one is left out", lambda l: batch(l, keep=(1,)), "NOT VIABLE", "no attempt played part 2", listed=batched)
    expect("… of three", lambda l: batch(l, parts=3), "NOT VIABLE", "no attempt played part 3", listed=batched)
    expect("… which do not agree how many they are", lambda l: (batch(l), every(l, "walk")[0]["manifest"].update(parts=3)), "INVALID", "do not agree how many", listed=batched)
    expect("… both calling themselves the first", lambda l: (batch(l), every(l, "walk")[1]["manifest"].update(part=1)), "INVALID", "is in the ledger twice", listed=batched)

    # Who holds input back: a journey against its own control, kind of event by kind of event.
    more = 1000 * gate["input"]["p99_more_ms_max"]

    def pair(ledger):
        """A control, and the journeys it is the control of."""
        control = every(ledger, "control")[0]
        return control, [run for run in every(ledger, *COUNTED) if journey(run["manifest"]) == journey(control["manifest"])]

    def late(run, kind, by):
        run["input"]["kinds"][kind]["p99_us"] += by

    expect("presses that bring an app forward are held back", lambda l: late(pair(l)[1][0], "forward", more + 1), "NOT VIABLE", "input-held in run")
    expect("… by just what is allowed", lambda l: late(pair(l)[1][0], "forward", more), "VIABLE", "")
    expect("… and so are they without Arbor", lambda l: (late(pair(l)[1][0], "forward", more + 1), late(pair(l)[0], "forward", more + 1)), "VIABLE", "")
    expect("keys are held back, and presses are quicker by as much: kinds are not set off against each other",
           lambda l: (late(pair(l)[1][0], "key", more + 1), late(pair(l)[1][0], "forward", -more)), "NOT VIABLE", "of the kind key")
    def one_more(ledger, of, **changes):
        """The same journey, or its control, played once more in a run of its own, which the gate does not need."""
        extra = copy.deepcopy(of)
        extra["manifest"].update(run="8200", **changes)
        ledger["runs"].append(extra)
        return extra

    and_8200 = {**everything, ("8200", 1): {1}}
    expect("the same journey played twice", lambda l: one_more(l, pair(l)[1][0]), "VIABLE", "", listed=and_8200)
    expect("… and held back the second time", lambda l: late(one_more(l, pair(l)[1][0]), "up", more + 1), "NOT VIABLE", "input-held in run 8200", listed=and_8200)
    expect("a run that does not count is compared with nothing", lambda l: late(one_more(l, pair(l)[1][0], settings="mine"), "forward", more + 1), "VIABLE", "does not count: run 8200",
           listed=and_8200)
    expect("a control that does not count is no measure", lambda l: late(one_more(l, pair(l)[0], settings="mine"), "forward", -more - 1), "VIABLE", "does not count: run 8200", listed=and_8200)
    def two_controls(ledger, by):
        control = pair(ledger)[0]
        slower = twin(ledger, "control", run="8100")
        slower["manifest"].update({key: control["manifest"][key] for key in ("script", "seed", "tiling", "display", "cast", "reduce_motion")})
        late(slower, "forward", by)
        late(pair(ledger)[1][0], "forward", more + 1)
    expect("of two controls the quicker is the measure", lambda l: two_controls(l, 5 * more), "NOT VIABLE", "input-held in run", listed={**everything, ("8100", 1): {1}})
    expect("another journey's control excuses nothing", lambda l: (late(pair(l)[1][0], "forward", more + 1), [late(control, "forward", 5 * more) for control in every(l, "control")[1:]]),
           "NOT VIABLE", "input-held in run")
    expect("a journey that does not say how late input arrived", lambda l: pair(l)[1][0].update(input=None), "NOT VIABLE", "the witness saw nothing")
    expect("… or says it of no kind", lambda l: pair(l)[1][0].update(input={"events": 5, "p99_us": 3}), "NOT VIABLE", "the witness saw nothing")
    expect("a control that does not say it", lambda l: pair(l)[0].update(input=None), "NOT VIABLE", "the witness saw nothing")
    expect("a lateness that is no number", lambda l: pair(l)[1][0]["input"]["kinds"]["key"].update(p99_us="soon"), "UNREADABLE", "the lateness of key")
    expect("a lateness that is not there", lambda l: pair(l)[1][0]["input"]["kinds"]["key"].pop("p99_us"), "UNREADABLE", "the lateness of key")
    expect("a control of no journey", lambda l: pair(l)[0]["manifest"].update(seed="another"), "NOT VIABLE", "is the control of no journey that counts")
    expect("a kind of event no control has", lambda l: [control["input"]["kinds"].pop("forward") for control in every(l, "control")], "NOT VIABLE",
           "events of the kind forward were compared with no run without Arbor")
    expect("a kind of event one control lacks and another has", lambda l: pair(l)[0]["input"]["kinds"].pop("forward"), "VIABLE", "")

    # A hosted Mac's failure does not sink a commit, and who says that a part never ran is GitHub or the batch, never an absence.
    def stub(ledger, part=2, attempt=1, **more):
        """The manifest a job leaves in the place of a part before its first script begins."""
        first = every(ledger, "walk")[0]["manifest"]
        ledger["runs"].append({"manifest": {"gate": first["gate"], "started": False, "commit": first["commit"], "run": first["run"], "attempt": attempt, "part": part,
                                            "parts": first["parts"], **more}, "sampler": {}, "acts": [], "findings": []})

    def again(ledger, part=2, attempt=2):
        every(ledger, "walk")[part - 1]["manifest"].update(attempt=attempt)

    once, twice = batched, {**batched, ("1000", 2): {2}}
    expect("the batch was stopped before part 2, which was played in a second attempt", lambda l: (batch(l), again(l), stub(l)), "VIABLE", "never began: part 2 of run 1000.1, played in another", listed=twice)
    expect("… and nobody played it again", lambda l: (batch(l, keep=(1,)), stub(l)), "NOT VIABLE", "no attempt played part 2", listed=once)
    expect("… and the second attempt was stopped before it too", lambda l: (batch(l, keep=(1,)), stub(l), stub(l, attempt=2)), "NOT VIABLE", "no attempt played part 2", listed=twice)
    expect("its job never got a Mac, says GitHub, and a second attempt played it", lambda l: (batch(l), again(l)), "VIABLE", "", listed={**batched, ("1000", 1): {1}, ("1000", 2): {2}})
    expect("a first attempt that got a Mac is left out, and the second passed off as the first playing", lambda l: (batch(l), again(l)), "NOT VIABLE",
           "in run 1000.1 a job got a Mac for part 2, and the ledger leaves it out", listed=twice)
    def both_attempts(ledger, finding=None):
        batch(ledger)
        extra = twin(ledger, "walk", attempt=2)
        if finding:
            every(ledger, "walk")[0]["findings"].append({"id": extra["acts"][0]["id"], "what": "w", **finding})
    expect("what began is never replaced: a jolt in the first attempt stays, however clean the second", lambda l: both_attempts(l, {"detector": "jolt", "level": "FAIL"}),
           "NOT VIABLE", "jolt in run 1000.1", listed={**batched, ("1000", 2): {1}})
    expect("a second attempt alone, in the ledger and in GitHub's list: where is the first?", lambda l: l["runs"][0]["manifest"].update(attempt=2), "NOT VIABLE",
           "GitHub's list says nothing of attempt 1", listed={**{key: parts for key, parts in everything.items() if key[0] != "1000"}, ("1000", 2): {1}})
    expect("… in which no job got a Mac, says GitHub", lambda l: l["runs"][0]["manifest"].update(attempt=2), "VIABLE", "",
           listed={**{key: parts for key, parts in everything.items() if key[0] != "1000"}, ("1000", 1): set(), ("1000", 2): {1}})
    expect("a third attempt, and nothing of the second", lambda l: l["runs"][0]["manifest"].update(attempt=3), "NOT VIABLE", "GitHub's list says nothing of attempt 2",
           listed={**{key: parts for key, parts in everything.items() if key[0] != "1000"}, ("1000", 1): set(), ("1000", 3): {1}})
    for what, brought in (("acts", {"acts": [{"id": "idle#1", "act": "idle", "judged": True}]}), ("a finding", {"findings": [{"detector": "jolt", "level": "FAIL", "id": "idle#1", "what": "w"}]}),
                          ("the sampler's account", {"sampler": {"samples": 10, "late": 0}}), ("the witness's", {"input": {"kinds": {}, "events": 1}})):
        expect(f"a stub that brought back {what}", lambda l, brought=brought: (batch(l), again(l), stub(l), l["runs"][-1].update(brought)), "INVALID", "brought back what a script brings back", listed=twice)
    expect("a stub and a manifest for one part of one attempt", lambda l: (batch(l), stub(l)), "INVALID", "is in the ledger twice", listed=once)
    expect("a stub for a part no job was given", lambda l: (batch(l), again(l), stub(l)), "INVALID", "the ledger has part 2 of run 1000.1, and GitHub knows of no job",
           listed={**batched, ("1000", 1): {1}, ("1000", 2): {2}})
    expect("a second attempt GitHub knows nothing of", lambda l: (batch(l), again(l), stub(l)), "INVALID", "the ledger has part 2 of run 1000.2", listed=once)
    expect("a stub is no run: it neither counts nor falls out", lambda l: [stub(l, part=1, run=str(9100 + n), parts=1) for n in range(len(l["runs"]))], "NOT VIABLE", "no attempt played part 1",
           listed={**everything, **{(str(9100 + n), 1): {1} for n in range(len(good["runs"]))}})
    expect("the stubs of a second attempt disagree with the first on how many parts there are", lambda l: (batch(l), again(l), stub(l, parts=3)), "INVALID", "do not agree how many", listed=twice)
    expect("a manifest that does not say whether its script began", lambda l: l["runs"][0]["manifest"].pop("started"), "UNREADABLE", "does not say whether its script began")
    expect("… or says it in words", lambda l: l["runs"][0]["manifest"].update(started="yes"), "UNREADABLE", "does not say whether its script began")
    expect("part 3 of 2", lambda l: l["runs"][0]["manifest"].update(part=3, parts=2), "UNREADABLE", "part 3 of 2")
    expect("a part that is no number", lambda l: l["runs"][0]["manifest"].update(part="first"), "UNREADABLE", "part is 'first'")
    expect("parts that are no number, and a finding by nobody", lambda l: (l["runs"][0]["manifest"].update(parts="two"), l["runs"][0]["findings"].append({"level": "FAIL"})), "UNREADABLE", "parts is 'two'")
    expect("a run that does not say which part it is", lambda l: l["runs"][0]["manifest"].pop("part"), "UNREADABLE", "part is None")
    expect("a run that does not say of how many", lambda l: l["runs"][0]["manifest"].pop("parts"), "UNREADABLE", "parts is None")
    expect("a run id where the parts belong", lambda l: l["runs"][0]["manifest"].update(parts=2000000000), "UNREADABLE", "parts is 2000000000")
    expect("a time where the attempt belongs", lambda l: l["runs"][0]["manifest"].update(attempt=1760000000), "UNREADABLE", "attempt is 1760000000")
    expect("a run GitHub never heard of", lambda l: twin(l, "day", run="31337"), "INVALID", "GitHub knows of no job that got a Mac for it")
    expect("half the acts, every run twice", lambda l: ([run.update(acts=run["acts"][::2]) for run in every(l, *COUNTED)], l["runs"].extend(copy.deepcopy(every(l, *COUNTED)))),
           "INVALID", "is in the ledger twice")

    expect("a violation in the walks", lambda l: l["rings"]["linux"].update(violations=1), "NOT VIABLE", "ring 1: 1 violations")
    expect("nobody counted the violations", lambda l: l["rings"]["linux"].pop("violations"), "NOT VIABLE", "ring 1: an unknown number")
    expect("too few walks", lambda l: l["rings"]["linux"].update(walks=10), "NOT VIABLE", "ring 1: 10 walks")
    expect("a known failure excused", lambda l: l["rings"]["linux"].update(known_failures_of_severity_1_or_2=1), "NOT VIABLE", "being excused")
    expect("walks on another commit", lambda l: l["rings"]["linux"].update(commit="d" * 40), "NOT VIABLE", "ring 1: the walks ran on another commit")
    expect("no word from the walks", lambda l: l["rings"].pop("linux"), "NOT VIABLE", "ring 1")
    expect("a stand-in that lies about a rule", lambda l: l["rings"]["stand_ins"].update(open_divergences_that_touch_a_detector=2), "NOT VIABLE", "ring 2: 2 open")
    expect("differences counted on another commit", lambda l: l["rings"]["stand_ins"].update(commit="d" * 40), "NOT VIABLE", "ring 2: the differences")
    expect("a row of the rubric fails", lambda l: l["rings"]["polish"]["judged"][3].update(rows_failing=["hand-over"]), "NOT VIABLE", "fails: hand-over")
    expect("judged twice, failing once", lambda l: l["rings"]["polish"]["judged"].insert(0, {"move": 1, "appearance": gate["polish"]["appearance"][0], "rows_failing": ["cadence"]}),
           "NOT VIABLE", "fails: cadence")
    expect("a move nobody judged", lambda l: l["rings"]["polish"]["judged"].pop(), "NOT VIABLE", "was not judged in")
    expect("an empty ledger", lambda l: l.update(runs=[], rings={}), "INVALID", "sabotage runs count", listed=None)
    expect("another gate's ledger", lambda l: l.update(gate=gate["gate"] + 1), "NOT VIABLE", "the page describes gate")

    expect("no commit anywhere", lambda l: (l.pop("commit"), [run["manifest"].pop("commit") for run in l["runs"]], [ring.pop("commit") for ring in l["rings"].values()]), "UNREADABLE", "forty hexadecimal")
    expect("an attempt that is no number", lambda l: l["runs"][0]["manifest"].update(attempt="x"), "UNREADABLE", "attempt is 'x'")
    expect("violations that are no number", lambda l: l["rings"]["linux"].update(violations=None), "UNREADABLE", "no count")
    expect("samples that are no number", lambda l: l["runs"][0]["sampler"].update(samples="many"), "UNREADABLE", "no count")
    expect("a finding by nobody", lambda l: every(l, "sabotage")[0]["findings"].append({"level": "FAIL", "id": "idle#0"}), "UNREADABLE", "needs a detector")

    # Numbers that change on the page change the verdict: none is written down here a second time.
    def with_number(path, value):
        values = gate.plain()
        target = values
        for key in path[:-1]:
            target = target[key]
        target[path[-1]] = value
        return Numbers(values)

    expect("the page allows input to be held longer", lambda l: late(pair(l)[1][0], "forward", more + 1), "VIABLE", "", page=with_number(["input", "p99_more_ms_max"], gate["input"]["p99_more_ms_max"] + 1))
    expect("the page allows one oddity", lambda l: find(l, "walk", detector="focus", level="ODD"), "VIABLE", "", page=with_number(["odd_unexplained_max"], 1))
    expect("the page allows one failure", lambda l: find(l, "day", detector="jolt", level="FAIL"), "VIABLE", "", page=with_number(["fail_max"], 1))
    expect("the page asks for more apps a run", nothing, "INVALID", "too many fell out", page=with_number(["apps_per_run_min"], len(good["runs"][0]["manifest"]["apps"]) + 1))
    expect("the page asks for more acts with Reduce Motion on", nothing, "NOT VIABLE", "with Reduce Motion on at",
           page=with_number(["reduce_motion", "acts_that_move_per_tiling_min"], 100000))
    def moving(ledger):
        return [act for run in still_runs(ledger) if run["manifest"]["tiling"] == gate["tiling"][0] for act in run["acts"]
                if act["act"] in gate["reduce_motion"]["kinds_that_move"]]

    exactly = with_number(["reduce_motion", "acts_that_move_per_tiling_min"], len(moving(good)))
    expect("the page asks for exactly the acts there are with Reduce Motion on", nothing, "VIABLE", "", page=exactly)
    expect("… and one of them was not judged", lambda l: moving(l)[0].update(judged=False), "NOT VIABLE", f"{len(moving(good)) - 1} acts that move windows", page=exactly)
    expect("the page allows fewer acts with Reduce Motion on", nothing, "NOT VIABLE", "a Mac comes with it off", page=with_number(["reduce_motion", "share_of_acts_max"], 0.001))
    expect("the page knows one detector more", nothing, "INVALID", "never shown to catch anything: dizzy", page=with_number(["detectors"], [*gate["detectors"], "dizzy"]))
    for path, value in [(["share_of_acts_from_walks_min"], 0.6), (["controls", "sabotage_runs_min"], 2), (["controls", "without_arbor_per_cell_min"], 2),
                        (["acts_min", "switch"], 6000), (["real_apps_min"], 5), (["user_hours"], 50), (["user_hours_per_cast_min"], 11),
                        (["reduce_motion", "acts_that_move_per_tiling_min"], 200)]:
        page = with_number(path, value)
        other = perfect(page)
        verdict, reasons, _ = judge(other, page, {(run["manifest"]["run"], 1): {1} for run in other["runs"]})
        if verdict != "VIABLE":
            failures.append(f"with {'.'.join(path)} at {value} the perfect ledger is {verdict}: {reasons[:3]}")
    fresh = numbers()
    if fresh.plain() != json.loads(json.dumps(numbers())) or fresh.used:
        failures.append(f"a copy of the page's block is another block, or leaves numbers looking read: {sorted(fresh.used)[:4]}")
    # What only another tool reads is never asked for here. If it looks read, something has walked over the whole block, and the test below has no teeth.
    if set(READ_ELSEWHERE) & gate.used:
        failures.append(f"numbers that only another tool reads look read here: {', '.join(sorted(set(READ_ELSEWHERE) & gate.used))}")
    unread = sorted(set(gate.leaves()) - gate.used - set(READ_ELSEWHERE))
    if unread:
        failures.append(f"numbers on the page that nothing reads: {', '.join(unread)}")

    # From directories to a verdict, through the command line.
    def call(*arguments):
        import contextlib
        import io
        said = io.StringIO()
        with contextlib.redirect_stdout(said):
            code = main(list(arguments))
        return code, said.getvalue()

    def expect_call(name, arguments, code, words):
        got, said = call(*arguments)
        if got != code or words not in said:
            failures.append(f"{name}: exit code {got}, wanted {code} with “{words}”; it said: {said[-300:]}")

    with tempfile.TemporaryDirectory() as scratch:
        def put(path, value):
            path = os.path.join(scratch, path)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(value if isinstance(value, str) else json.dumps(value))
            return path

        commit = good["commit"]
        directories = []
        for run in good["runs"]:
            directory = f"runs/{run['manifest']['run']}"
            directories.append(os.path.join(scratch, directory))
            put(f"{directory}/run.json", run["manifest"])
            steps, by_id = [], {}
            for number, act in enumerate(run["acts"]):
                # Each act's slug is its own, so `#1` follows; the offences and findings are written to match.
                step = {"number": number, "slug": act["id"].replace("#", "-"), "act": act["act"], "judged": act["judged"], "findings": []}
                by_id[act["id"]] = step
                steps.append(step)
            for finding in run["findings"]:
                by_id[finding["id"]]["findings"].append({"detector": finding["detector"], "rule": "3", "level": finding["level"], "what": finding["what"]})
            if "offences" in run["manifest"]:
                put(f"{directory}/run.json", dict(run["manifest"], offences=[dict(o, id=o["id"].replace("#", "-") + "#1") for o in run["manifest"]["offences"]]))
            put(f"{directory}/day-findings.json", {"sampler": "samples 30000 seconds 540.0 hz 55.5 cost-ms 1.20 late 10 longest-gap-ms 200", "input": run.get("input"), "steps": steps})
        put("runs/rings.json", good["rings"])
        listing = put("listed.txt", "".join(f"{identifier} {attempt} 1-1\n" for identifier, attempt in everything))
        ledger = os.path.join(scratch, "ledger.json")
        expect_call("a ledger from directories", ["ledger", commit, *directories, "-o", ledger], 0, "")
        expect_call("… is viable", ["check", ledger, "--runs", listing], 0, "\nVIABLE")
        with open(listing, encoding="utf-8") as handle:
            expect_call("… also with a run of which no job ever got a Mac", ["check", ledger, "--runs", put("dash.txt", handle.read() + "4242 1 -\n")], 0, "\nVIABLE")
        expect_call("… and not without the listing", ["check", ledger], 1, "NOT VIABLE")
        expect_call("the same directory twice", ["ledger", commit, *directories, directories[0], "-o", ledger], 0, "")
        expect_call("… is found out", ["check", ledger, "--runs", listing], 2, "is in the ledger twice")
        os.remove(os.path.join(directories[0], "day-findings.json"))
        expect_call("a run that never reported", ["ledger", commit, *directories, "-o", ledger], 0, "")
        expect_call("… is in the ledger and does not count", ["check", ledger, "--runs", listing], 1, "it brought back no acts")
        expect_call("a directory that is not there", ["ledger", commit, os.path.join(scratch, "nowhere")], 2, "is no directory")
        os.makedirs(os.path.join(scratch, "empty"))
        expect_call("a directory without a manifest", ["ledger", commit, os.path.join(scratch, "empty")], 2, "has no run.json")
        put("runs/1001/rings.json", {"linux": dict(good["rings"]["linux"], violations=3)})
        expect_call("two accounts of one ring", ["ledger", commit, *directories], 2, "says something else about the ring linux")
        put("old/run.json", good["runs"][0]["manifest"])
        put("old/day-findings.json", {"sampler": "", "steps": [{"number": 1, "slug": "idle", "findings": [{"rule": "-", "level": "FAIL", "what": "Arbor died"}]}]})
        expect_call("findings that name no detector", ["ledger", commit, os.path.join(scratch, "old")], 2, "a finding without `detector`")
        expect_call("a ledger that is not there", ["check", os.path.join(scratch, "no.json")], 2, "no.json")
        expect_call("a ledger cut short", ["check", put("short.json", '{"gate": 1,')], 2, "short.json")
        expect_call("a listing with a heading", ["check", ledger, "--runs", put("heading.txt", "id attempt parts\n1000 1 1-1\n")], 2, "is not `<run id> <attempt> <first part>-<last part>`")
        for name, text, words in (("the old form", "1000 1\n", "is not `<run id>"), ("parts the wrong way round", "1000 1 3-2\n", "the first part not after the last"),
                                  ("part nought", "1000 1 0-2\n", "numbers from 1 to"), ("a run id where the parts belong", "1000 1 1-2000000000\n", "numbers from 1 to"),
                                  ("attempt nought", "1000 0 1-1\n", "numbers from 1 to"), ("attempt nought in which nobody got a Mac", "1000 0 -\n", "is not `<run id>"), ("one part given to two jobs", "1000 1 1-4\n1000 1 4-8\n", "were given the same part")):
            expect_call(f"a listing with {name}", ["check", ledger, "--runs", put("odd.txt", text)], 2, words)
        expect_call("an empty listing", ["check", ledger, "--runs", put("none.txt", "")], 2, "lists no job at all")
        expect_call("-o and nothing after it", ["ledger", commit, directories[0], "-o"], 2, "viable.py ledger")
        expect_call("no such command", ["verdict"], 2, "viable.py ledger")

    for failure in failures:
        print(f"✘ {failure}")
    print("viable.py: its own test " + ("FAILED" if failures else "passed"))
    return 1 if failures else 0


def main(arguments):
    try:
        if arguments == ["--self-test"]:
            return self_test()
        if len(arguments) >= 3 and arguments[0] == "ledger":
            rest, out = arguments[1:], None
            if "-o" in rest:
                index = rest.index("-o")
                if index + 1 >= len(rest):
                    print(__doc__)
                    return 2
                out = rest[index + 1]
                del rest[index:index + 2]
            text = json.dumps(make_ledger(rest[0], rest[1:], numbers()), indent=1, ensure_ascii=False)
            if out:
                with open(out, "w", encoding="utf-8") as handle:
                    handle.write(text + "\n")
            else:
                print(text)
            return 0
        if arguments[:1] == ["check"] and (len(arguments) == 2 or (len(arguments) == 4 and arguments[2] == "--runs")):
            listed = read_listed(arguments[3]) if len(arguments) == 4 else None
            verdict, text = report(read_json(arguments[1]), numbers(), listed)
            print(text)
            return {"VIABLE": 0, "NOT VIABLE": 1}.get(verdict, 2)
    except Unreadable as problem:
        print(f"viable.py: {problem}")
        return 2
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
