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

import contextlib
import copy
import io
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
    "input.p50_more_ms_max": "jolts.py: half of the events of a kind reach the apps at most this much later in a round of input with Arbor than in the one without beside it",
    "input.forward_p50_more_ms_max": "jolts.py: the same for presses on a window of an app that is not in front, which macOS itself holds",
    "input.events_per_kind_min": "jolts.py: fewer events of a kind than this in a round say nothing",
    "previews_together_ms_max": "jolts.py: macOS's tiling preview and Arbor's drop preview up together for longer than this is fought",
    "stage_margin_ms": "jolts.py: a change this shortly before Arbor's stage is seen belongs to what the stage then shows",
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
    if manifest.get("tiling") == "off" and manifest.get("tiling_seen_to_act") is not False:
        return ("macOS's own tiling is said to be off, and was seen to act before Arbor started" if manifest.get("tiling_seen_to_act") is True
                else "macOS's own tiling is said to be off, and it does not say whether it was seen to act")
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
    if manifest["kind"] in COUNTED and heard(run) is None:
        return "it does not say of which kinds of input its rounds say anything: the witness saw nothing, or no round was played"
    # In a run without Arbor there is nothing of Arbor's to judge: it is there to be compared with.
    if manifest["kind"] != "control":
        judged = sum(1 for act in acts if act.get("judged") is True)
        if judged / len(acts) < gate["share_of_acts_judged_min"]:
            return f"only {judged} of {len(acts)} acts were judged"
    # Every cell is proved by what was seen, never by what was set. Last, since it goes by the acts that are judged.
    return not_the_display(run, gate)


def heard(run):
    """The kinds of input of which a journey's own rounds say something, as jolts.py found (`"judged"`). None if the run does not say."""
    kinds = (run.get("input") or {}).get("judged")
    if not isinstance(kinds, list) or not all(isinstance(kind, str) for kind in kinds):
        return None
    return set(kinds)


def not_the_display(run, gate):
    """Why the samples do not bear out the display a run says it was played on; None if they do. The manifest has the script's own word for it, and a word is no evidence: a walk written
    for two displays was played on one from beginning to end, because no line of it plugged the second one in, and said "two"."""
    acts = run.get("acts") or []
    for act in acts:
        displays, elsewhere = act.get("displays"), act.get("windows_elsewhere")
        if not isinstance(displays, list) or not all(
                isinstance(size, list) and len(size) == 2 and all(isinstance(side, int) and not isinstance(side, bool) and side > 0 for side in size) for size in displays):
            return f"{act.get('id')} does not say what displays the sampler saw"
        if not isinstance(elsewhere, int) or isinstance(elsewhere, bool) or elsewhere < 0:
            return f"{act.get('id')} does not say how many windows lay on a second display"
        if elsewhere and len(displays) < 2:
            return f"{act.get('id')} says that {elsewhere} windows lay on a second display, and that the sampler saw {len(displays)}"
        if not displays:
            return f"the sampler saw no display at all at the end of {act.get('id')}"
    seen = [act["displays"] for act in acts]
    wanted, rule = run["manifest"].get("display"), gate["display_seen"]
    if wanted == "two":
        # In a run without Arbor nothing is judged, and all of it is what it is there for.
        counting = [act for act in acts if act.get("judged") is True or run["manifest"].get("kind") == "control"]
        both = sum(1 for act in counting if len(act["displays"]) >= 2)
        if not counting or both / len(counting) < rule["two_displays_share_of_acts_min"]:
            return f"it says it had two displays, and the sampler saw two at the end of {both} of {len(counting)} acts"
        # The going and the coming is what the cell is for. A display that goes with nothing on it tries nobody.
        went = came = False
        for before, act in zip(acts, acts[1:]):
            if act.get("act") != "display-change" or act not in counting or not did(act, run):
                continue
            if len(act["displays"]) < len(before["displays"]) and before["windows_elsewhere"] > 0:
                went = True
            # A display that comes back is what the cell is for. A journey that only plugs one in and then unplugs it has not played that.
            elif len(act["displays"]) > len(before["displays"]) and went:
                came = True
        if not went:
            return "it says it had two displays, and in none of its acts did one go that had a window on it"
        if not came:
            return "it says it had two displays, and in none of its acts did one come back after one had gone"
        return None
    for displays in seen:
        if len(displays) != 1:
            return f"it says it was played on one display ({wanted}), and the sampler saw {len(displays)}"
        if displays != seen[0]:
            return f"it says it was played on one display ({wanted}), and the sampler saw {seen[0][0][0]}×{seen[0][0][1]} and then {displays[0][0]}×{displays[0][1]}"
        if wanted == "desk" and displays[0] != list(rule["desk"]):
            return f"it says it was played on a desk's display, and the sampler saw {displays[0][0]}×{displays[0][1]}"
        if wanted == "laptop" and not rule["laptop_width_min"] <= displays[0][0] <= rule["laptop_width_max"]:
            return f"it says it was played on a laptop's display, and the sampler saw {displays[0][0]}×{displays[0][1]}"
    return None


def did(act, run):
    """Whether an act was performed. It has to say."""
    if not isinstance(act.get("performed"), bool):
        raise Unreadable(f"{name_of(run)}: {act.get('id')} does not say whether it was performed")
    if not act["performed"] and act.get("judged") is True:
        raise Unreadable(f"{name_of(run)}: {act.get('id')} says that it was not performed, and that it was judged")
    return act["performed"]


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

    journeys = [run for run in runs if run["manifest"].get("kind") in COUNTED and not excuses[id(run)]]
    # Who holds input back is asked within each journey, in rounds of the same events with and without Arbor on the same Mac, and what is found there is a finding like any other.
    # A journey may say nothing of a kind: too few events, or the Mac itself moved. Silence is not read in the commit's favour.
    for kind in gate["input"]["kinds"]:
        spoke = sum(1 for run in journeys if kind in heard(run))
        if spoke < gate["input"]["share_of_journeys_that_judge_a_kind_min"] * len(journeys) or not journeys:
            invalid.append(f"only {spoke} of {len(journeys)} journeys say whether input of the kind {kind} is held back")
    # A control is the same journey with Arbor not running. One that is nobody's excuses nothing and shows nothing.
    performed_alone = {}
    for run in runs:
        if run["manifest"].get("kind") == "control" and not excuses[id(run)]:
            if not any(journey(other["manifest"]) == journey(run["manifest"]) for other in journeys):
                reasons.append(f"{name_of(run)} is the control of no journey that counts: there is nothing to compare it with")
            performed_alone.setdefault(journey(run["manifest"]), set()).update(act["id"] for act in run["acts"] if did(act, run))
    # An act that could not be performed is not judged. A press that does not take hold of a title bar happens without Arbor too. But where the same act was performed in the journey's own
    # control, something took the window from under the pointer; and too many of them, and either the instrument is sick or Arbor does that, and nobody can tell which from a count.
    undone = [(run, act) for run in journeys for act in run["acts"] if not did(act, run)]
    for run, act in undone:
        if act["id"] in performed_alone.get(journey(run["manifest"]), ()):
            fails += 1
            reasons.append(f"{act['id']} could not be performed in {name_of(run)}, and was performed in the same journey without Arbor")
    everything_asked = sum(len(run["acts"]) for run in journeys)
    if undone:
        table.append(f"  not performed, so not judged: {len(undone)} of {everything_asked} acts")
    if everything_asked and len(undone) / everything_asked > gate["share_of_acts_not_performed_max"]:
        invalid.append(f"{len(undone)} of {everything_asked} acts could not be performed: the instrument is sick, or Arbor takes windows from under the pointer")

    def weigh(run, which=""):
        """What was found in a journey: Arbor's, unless its own control shows the same at the same act."""
        nonlocal fails, odd
        for finding in run.get("findings") or []:
            words = f"{finding['detector']} in {name_of(run)}{which}, at {finding['id']}: {finding.get('what', '')}"
            if (finding["detector"], finding["id"]) in alone.get(journey(run["manifest"]), ()):
                table.append(f"  not Arbor's, the run without it shows the same: {words}")
            elif finding["level"] == "FAIL":
                fails += 1
                reasons.append(words)
            elif not finding.get("explained"):
                odd += 1
                reasons.append(f"odd and not explained: {words}")

    for run in runs:
        manifest, findings = run["manifest"], run.get("findings") or []
        kind = manifest.get("kind")
        if excuses[id(run)]:
            fell_out += 1
            table.append(f"  does not count: {name_of(run)}: {excuses[id(run)]}")
            # A journey on this commit with nothing against it but that it was played on another display than it says counts for no cell. What was found in it is found: else a journey
            # that is cut short, or in which the window is taken from under the hand that carries it across, would fall out and take its findings with it.
            if kind in COUNTED and excuses[id(run)] == not_the_display(run, gate):
                weigh(run, ", which counts for no cell")
            # Whatever else was wrong with the run, Arbor fell over on this commit.
            elif manifest.get("commit") == commit and kind in COUNTED:
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
        weigh(run)
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
        # A round of input is an instrument, not an act: it counts towards nothing, and what is found during it is found.
        if step.get("act") != "instrument":
            run["acts"].append({"id": identifier, "act": step.get("act"), "judged": step.get("judged") is True, "performed": step.get("performed"),
                                "displays": step.get("displays"), "windows_elsewhere": step.get("windows_elsewhere")})
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
    arrived = {"judged": list(gate["input"]["kinds"])}
    runs = []

    def manifest(number, kind, cell, cast):
        return {
            "gate": gate["gate"], "started": True, "commit": commit, "run": str(1000 + number), "attempt": 1, "part": 1, "parts": 1, "script": f"{kind}.sh", "kind": kind, "seed": None,
            "tiling": cell[0], "tiling_seen_to_act": cell[0] == "defaults", "display": cell[1], "cast": cast, "apps": apps, "settings": "shipped",
            "seconds": gate["run_seconds_max"], "reduce_motion": False, "stage_seen": kind != "control",
        }

    still = dict.fromkeys(gate["tiling"], gate["reduce_motion"]["acts_that_move_per_tiling_min"])
    for number, (cell, cast) in enumerate(plan):
        acts = [{"id": f"{kind}#{index}", "act": kind, "judged": True, "performed": True} for index, kind in enumerate(wanted[number * per_run:(number + 1) * per_run])]
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
                "sampler": dict(sampler), "input": copy.deepcopy(arrived), "acts": [{"id": "switch#0", "act": "switch", "judged": False, "performed": True}], "findings": [],
            })
    for again in range(gate["controls"]["sabotage_runs_min"]):
        offences = [{"detector": detector, "id": f"idle#{index}"} for index, detector in enumerate(gate["detectors"])]
        runs.append({
            "manifest": dict(manifest(6000 + again, "sabotage", (gate["tiling"][-1], gate["display"][0]), gate["cast"][0]), offences=offences),
            "sampler": dict(sampler), "acts": [{"id": offence["id"], "act": "idle", "judged": True, "performed": True} for offence in offences],
            "findings": [dict(offence, level="FAIL", what="planted") for offence in offences],
        })
    # What the sampler saw at the end of each act, as the run's cell has it. With two displays the second comes, has a window sent to it, goes, and comes again: three acts more, of a kind
    # the gate asks for anyway. It is there for just the share of acts that is asked for.
    rule = gate["display_seen"]
    for run in runs:
        wanted, acts = run["manifest"]["display"], run["acts"]
        if wanted == "two":
            judged = run["manifest"]["kind"] != "control"
            acts[:0] = [{"id": f"display-change#{9000 + n}", "act": "display-change", "judged": judged, "performed": True} for n in range(4)]
        both = -(-rule["two_displays_share_of_acts_min"] * len(acts) // 1)
        for index, act in enumerate(acts):
            act["displays"] = [list(rule["desk"])] if wanted == "desk" else [[rule["laptop_width_max"], 900]]
            act["windows_elsewhere"] = 0
            # One display; it comes; it goes; it comes, and stays for as long as it has to.
            if wanted == "two" and (index == 1 or 3 <= index < both + 2):
                act["displays"].append(list(rule["desk"]))
                act["windows_elsewhere"] = 1
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
    expect("acts that were not judged", lambda l: [act.update(judged=False) for run in every(l, *COUNTED) for act in run["acts"][-(len(run["acts"]) // 20):]], "NOT VIABLE", "are asked for")

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

    # Who holds input back is asked within each journey. Here: whether enough journeys say anything, and what became of the acts that could not be performed.
    def pair(ledger):
        """A control, and the journeys it is the control of."""
        control = every(ledger, "control")[0]
        return control, [run for run in every(ledger, *COUNTED) if journey(run["manifest"]) == journey(control["manifest"])]

    def one_more(ledger, of, **changes):
        """The same journey, or its control, played once more in a run of its own, which the gate does not need."""
        extra = copy.deepcopy(of)
        extra["manifest"].update(run="8200", **changes)
        ledger["runs"].append(extra)
        return extra

    and_8200 = {**everything, ("8200", 1): {1}}

    def silent(ledger, kind, share):
        """So many of the journeys say nothing of that kind of input."""
        journeys = every(ledger, *COUNTED)
        for run in journeys[:int(share * len(journeys))]:
            run["input"]["judged"].remove(kind)

    least = gate["input"]["share_of_journeys_that_judge_a_kind_min"]
    many = len(every(good, *COUNTED))
    expect("as many journeys as may be say nothing of scrolls", lambda l: silent(l, "scroll", (many - -(-least * many // 1)) / many), "VIABLE", "")
    expect("… and one more", lambda l: silent(l, "scroll", (many - -(-least * many // 1) + 1) / many), "INVALID", "say whether input of the kind scroll is held back")
    expect("no journey says anything of keys", lambda l: silent(l, "key", 1), "INVALID", f"only 0 of {many} journeys say whether input of the kind key")
    expect("input held back in a round is a finding like any other", lambda l: every(l, "walk")[0]["findings"].append({"detector": "input-held", "level": "FAIL", "id": "input-started#1", "what": "w"}),
           "NOT VIABLE", "input-held in run")
    expect("a journey that does not say of which kinds it says anything", lambda l: every(l, "walk")[0].update(input=None), "NOT VIABLE", "the witness saw nothing, or no round was played")
    expect("… or says it in words", lambda l: every(l, "walk")[0].update(input={"judged": "all"}), "NOT VIABLE", "the witness saw nothing, or no round was played")
    expect("… or in numbers", lambda l: every(l, "walk")[0].update(input={"judged": [1, 2]}), "NOT VIABLE", "the witness saw nothing, or no round was played")
    expect("a control need not say it: it is there for what windows do by themselves", lambda l: pair(l)[0].update(input=None), "VIABLE", "")
    expect("a journey that does not count says nothing for anybody", lambda l: (silent(l, "up", 1), [one_more(l, every(l, "walk")[0], settings="mine")["input"].update(judged=list(gate["input"]["kinds"]))]),
           "INVALID", "input of the kind up", listed=and_8200)
    expect("a control of no journey", lambda l: pair(l)[0]["manifest"].update(seed="another"), "NOT VIABLE", "is the control of no journey that counts")

    # The display a run says it was played on is the script's own word. The samples have to bear it out.
    def on(ledger, display, kinds=COUNTED):
        return [run for run in every(ledger, *kinds) if run["manifest"]["display"] == display]

    def seen(run, displays, how_many=None):
        for act in run["acts"][:how_many]:
            act["displays"] = copy.deepcopy(displays)
            # Nothing lies on a display that is not there.
            if len(displays) < 2:
                act["windows_elsewhere"] = 0

    small, large = [gate["display_seen"]["laptop_width_max"], 900], list(gate["display_seen"]["desk"])
    expect("written for two displays, and played on one from beginning to end", lambda l: seen(on(l, "two")[0], [small]), "NOT VIABLE", "the sampler saw two at the end of 0 of")
    def last_with_two(run):
        return [act for act in run["acts"] if len(act["displays"]) >= 2][-1]

    expect("… the second was there for one act fewer than is asked for", lambda l: last_with_two(on(l, "two")[0]).update(displays=[small], windows_elsewhere=0), "NOT VIABLE",
           "it says it had two displays, and the sampler saw two at the end of")
    def unjudged_with_two(ledger):
        """A few of the acts with two displays are not judged: few enough for the run to count otherwise."""
        acts = [act for act in on(ledger, "two")[0]["acts"][4:] if len(act["displays"]) >= 2]
        for act in acts[:3]:
            act.update(judged=False)

    expect("… it was there during acts that are not judged", unjudged_with_two, "NOT VIABLE", "it says it had two displays, and the sampler saw two at the end of")
    expect("… it was there all the time: it never went", lambda l: seen(on(l, "two")[0], [small, large]), "NOT VIABLE", "in none of its acts did one go that had a window on it")
    expect("… it went with nothing on it", lambda l: on(l, "two")[0]["acts"][1].update(windows_elsewhere=0), "NOT VIABLE", "in none of its acts did one go that had a window on it")
    expect("… it went in an act of another kind", lambda l: on(l, "two")[0]["acts"][2].update(act="idle"), "NOT VIABLE", "in none of its acts did one go that had a window on it")
    expect("… it went in an act that is not judged", lambda l: on(l, "two")[0]["acts"][2].update(judged=False), "NOT VIABLE", "in none of its acts did one go that had a window on it")
    def never_back(ledger):
        """It comes, has a window on it for most of the journey, and goes in the last act."""
        acts = on(ledger, "two")[0]["acts"]
        for act in acts[1:-1]:
            act.update(displays=[small, large], windows_elsewhere=1)
        for act in acts[2:4]:
            act.update(act="idle")
        acts[-1].update(act="display-change", displays=[small], windows_elsewhere=0)

    expect("… it came, went, and never came back", never_back, "NOT VIABLE", "in none of its acts did one come back after one had gone")
    expect("… it does not say how many windows were on it", lambda l: on(l, "two")[0]["acts"][1].pop("windows_elsewhere"), "NOT VIABLE", "does not say how many windows lay on a second display")
    for name, value in (("a part of a window", 0.5), ("fewer than none", -1), ("yes", True), ("a word", "one")):
        expect(f"… or says {name}", lambda l, value=value: on(l, "two")[0]["acts"][1].update(windows_elsewhere=value), "NOT VIABLE", "does not say how many windows lay on a second display")
    expect("… any act at all that does not say it, in a run on one display too", lambda l: on(l, "laptop")[0]["acts"][7].pop("windows_elsewhere"), "NOT VIABLE",
           "does not say how many windows lay on a second display")
    expect("windows on a second display that the sampler did not see", lambda l: on(l, "laptop")[0]["acts"][7].update(windows_elsewhere=5), "NOT VIABLE",
           "says that 5 windows lay on a second display, and that the sampler saw 1")
    expect("… it went in an act that was not performed", lambda l: on(l, "two")[0]["acts"][2].update(performed=False, judged=False), "NOT VIABLE", "")
    expect("… in a control, it went in an act that was not performed", lambda l: on(l, "two", ("control",))[0]["acts"][2].update(performed=False), "NOT VIABLE",
           "in none of its acts did one go that had a window on it")
    expect("… it came back in an act of another kind", lambda l: on(l, "two")[0]["acts"][3].update(act="idle"), "NOT VIABLE", "in none of its acts did one come back after one had gone")
    expect("… it came back in an act that is not judged", lambda l: (
        on(l, "two")[0]["acts"][3].update(judged=False),
        # One more act with two displays, so that there are still enough of them.
        next(act for act in on(l, "two")[0]["acts"][4:] if len(act["displays"]) < 2).update(displays=[small, large])), "NOT VIABLE", "in none of its acts did one come back after one had gone")

    def gone_in_between(ledger):
        """It goes in an act that is not judged, and the act after it, a judged change of displays, finds one display as the judged act before the two had two: nothing went in that one."""
        acts = on(ledger, "two")[0]["acts"]
        acts[2].update(judged=False)
        acts.insert(3, dict(acts[2], id="display-change#9100", judged=True))

    expect("… it went in an act that is not judged, and the next judged one finds it gone", gone_in_between, "NOT VIABLE", "in none of its acts did one go that had a window on it")
    expect("… no display at all where there was one", lambda l: on(l, "two")[0]["acts"][0].update(displays=[]), "NOT VIABLE", "the sampler saw no display at all at the end of")
    expect("an act that was not performed, and was judged", lambda l: on(l, "laptop")[0]["acts"][7].update(performed=False), "UNREADABLE", "says that it was not performed, and that it was judged")
    expect("… a control that says two and had one excuses nothing", lambda l: seen(on(l, "two", ("control",))[0], [small]), "NOT VIABLE", "the sampler saw two at the end of 0 of")
    expect("a second display turns up in a run on a laptop's", lambda l: seen(on(l, "laptop")[0], [small, large], 1), "NOT VIABLE", "played on one display (laptop), and the sampler saw 2")
    expect("… and in one on a desk's", lambda l: seen(on(l, "desk")[0], [large, large], 1), "NOT VIABLE", "played on one display (desk), and the sampler saw 2")
    expect("no display at all at the end of an act", lambda l: seen(on(l, "laptop")[0], [], 1), "NOT VIABLE", "the sampler saw no display at all at the end of")
    expect("a laptop's display as wide as a desk's", lambda l: seen(on(l, "laptop")[0], [[small[0] + 1, 900]], 1), "NOT VIABLE", "played on a laptop's display, and the sampler saw")
    expect("a desk's display that is a laptop's", lambda l: seen(on(l, "desk")[0], [small], 1), "NOT VIABLE", "played on a desk's display, and the sampler saw")
    expect("… or of the right width and another height", lambda l: seen(on(l, "desk")[0], [[large[0], large[1] + 120]], 1), "NOT VIABLE", "played on a desk's display, and the sampler saw")
    expect("a laptop's display smaller than any Mac's", lambda l: seen(on(l, "laptop")[0], [[gate["display_seen"]["laptop_width_min"] - 1, 768]]), "NOT VIABLE", "played on a laptop's display, and the sampler saw")
    expect("… the narrowest that is one", lambda l: [seen(run, [[gate["display_seen"]["laptop_width_min"], 800]]) for run in l["runs"] if run["manifest"]["display"] == "laptop"], "VIABLE", "")
    expect("… tall and narrow: it goes by the width", lambda l: seen(on(l, "laptop")[0], [[gate["display_seen"]["laptop_width_min"] - 1, small[0]]]), "NOT VIABLE", "played on a laptop's display, and the sampler saw")
    expect("a display that is another in the middle of the run", lambda l: on(l, "laptop")[0]["acts"][7].update(displays=[[small[0] - 80, 900]]), "NOT VIABLE", "and then")
    expect("… a second one in the middle of the run", lambda l: on(l, "laptop")[0]["acts"][7].update(displays=[small, large]), "NOT VIABLE", "played on one display (laptop), and the sampler saw 2")
    expect("… a desk's that is another in the middle of the run", lambda l: on(l, "desk")[0]["acts"][7].update(displays=[small]), "NOT VIABLE", "and then")
    expect("a control on one display that had two", lambda l: seen(on(l, "laptop", ("control",))[0], [small, large]), "NOT VIABLE", "played on one display (laptop), and the sampler saw 2")
    expect("a sabotage run on another display than it says", lambda l: seen(every(l, "sabotage")[0], [large]), "INVALID", "played on a laptop's display, and the sampler saw")
    expect("a sit on another display than it says", lambda l: seen(one_more(l, on(l, "laptop")[0], kind="sit"), [large]), "VIABLE", "played on a laptop's display, and the sampler saw", listed=and_8200)
    for name, size in (("nothing by nothing", [0, 0]), ("less than nothing", [-5, -5]), ("yes by no", [True, False]), ("a fraction", [1600.5, 900]), ("three sides", [1600, 900, 2])):
        expect(f"a display of {name}", lambda l, size=size: on(l, "laptop")[0]["acts"][7].update(displays=[size]), "NOT VIABLE", "does not say what displays the sampler saw")
    expect("an act that does not say what displays were seen", lambda l: on(l, "laptop")[0]["acts"][0].pop("displays"), "NOT VIABLE", "does not say what displays the sampler saw")
    expect("… an act in the middle of the run", lambda l: on(l, "laptop")[0]["acts"][7].pop("displays"), "NOT VIABLE", "does not say what displays the sampler saw")
    expect("… or says it in words", lambda l: on(l, "laptop")[0]["acts"][0].update(displays="one"), "NOT VIABLE", "does not say what displays the sampler saw")
    expect("… or in a number", lambda l: on(l, "laptop")[0]["acts"][0].update(displays=2), "NOT VIABLE", "does not say what displays the sampler saw")
    expect("… or in half a size", lambda l: on(l, "laptop")[0]["acts"][0].update(displays=[[1600]]), "NOT VIABLE", "does not say what displays the sampler saw")
    expect("… or in words for numbers", lambda l: on(l, "laptop")[0]["acts"][0].update(displays=[["1600", "900"]]), "NOT VIABLE", "does not say what displays the sampler saw")

    def cut_short(ledger, level="FAIL", excused=False):
        """A journey the gate does not need, in which something was found, and whose last act never ended: no display was seen at its end."""
        control, journeys = pair(ledger)
        extra = one_more(ledger, journeys[0])
        found = {"detector": "jolt", "level": level, "id": extra["acts"][5]["id"], "what": "moved 2 times"}
        extra["findings"].append(found)
        extra["acts"].append({"id": "launch#99", "act": "quit-and-start", "judged": False, "performed": True, "displays": [], "windows_elsewhere": 0})
        if excused:
            control["findings"].append(dict(found))

    expect("a journey that is cut short counts for no cell, and what was found in it is found", cut_short, "NOT VIABLE", "jolt in run 8200.1 (walk.sh), which counts for no cell, at", listed=and_8200)
    expect("… an oddity too", lambda l: cut_short(l, level="ODD"), "NOT VIABLE", "odd and not explained: jolt in run 8200.1", listed=and_8200)
    expect("… but for what its own control shows at the same act", lambda l: cut_short(l, excused=True), "VIABLE", "not Arbor's, the run without it shows the same", listed=and_8200)

    def found_on_another_commit(ledger):
        cut_short(ledger)
        ledger["runs"][-1]["manifest"]["commit"] = "f" * 40

    expect("… what was found on another commit is not", found_on_another_commit, "VIABLE", "it ran on another commit", listed=and_8200)
    expect("tiling said to be off, and seen to act", lambda l: [run["manifest"].update(tiling_seen_to_act=True) for run in every(l, *COUNTED) if run["manifest"]["tiling"] == "off"][:0], "INVALID",
           "is said to be off, and was seen to act")
    expect("… in one run", lambda l: next(run for run in every(l, *COUNTED) if run["manifest"]["tiling"] == "off")["manifest"].update(tiling_seen_to_act=True), "NOT VIABLE",
           "is said to be off, and was seen to act")
    expect("… or it does not say", lambda l: next(run for run in every(l, *COUNTED) if run["manifest"]["tiling"] == "off")["manifest"].pop("tiling_seen_to_act"), "NOT VIABLE",
           "is said to be off, and it does not say whether it was seen to act")

    def undone(ledger, how_many, of=None):
        """So many acts, spread over the journeys, could not be performed."""
        acts = [act for run in (of or every(ledger, *COUNTED)) for act in run["acts"]]
        for act in acts[::max(1, len(acts) // how_many)][:how_many]:
            act.update(performed=False, judged=False)

    asked = sum(len(run["acts"]) for run in every(good, *COUNTED))
    most = int(gate["share_of_acts_not_performed_max"] * asked)
    expect("one act could not be performed", lambda l: undone(l, 1), "NOT VIABLE", f"not performed, so not judged: 1 of {asked} acts")
    expect("too many acts could not be performed", lambda l: undone(l, most + 1), "INVALID", "the instrument is sick, or Arbor takes windows from under the pointer")

    def taken_from_under_the_pointer(ledger, also_alone):
        control, journeys = pair(ledger)
        act = journeys[0]["acts"][0]
        act.update(performed=False, judged=False)
        control["acts"].append({"id": act["id"], "act": act["act"], "judged": False, "performed": not also_alone, "displays": control["acts"][0]["displays"], "windows_elsewhere": 0})

    expect("an act that could not be performed, and was in the journey's control", lambda l: taken_from_under_the_pointer(l, False), "NOT VIABLE", "was performed in the same journey without Arbor")
    def spare_journey(ledger, in_its_control=None, in_another=None):
        """A journey the gate does not need, in which one act could not be performed. `in_its_control`, `in_another`: whether that act was performed there, if it is there at all."""
        control, journeys = pair(ledger)
        extra = one_more(ledger, journeys[0])
        extra["acts"].append({"id": "drag#999", "act": "drag", "judged": False, "performed": False, "displays": extra["acts"][0]["displays"], "windows_elsewhere": 0})
        for where, performed in ((control, in_its_control), (every(ledger, "control")[1], in_another)):
            if performed is not None:
                where["acts"].append({"id": "drag#999", "act": "drag", "judged": False, "performed": performed, "displays": where["acts"][0]["displays"], "windows_elsewhere": 0})

    expect("it could not be performed in the control either", lambda l: spare_journey(l, in_its_control=False), "VIABLE", "not performed, so not judged: 1 of", listed=and_8200)
    expect("it was performed in the control", lambda l: spare_journey(l, in_its_control=True), "NOT VIABLE", "drag#999 could not be performed in run 8200", listed=and_8200)
    expect("it was performed in another journey's control", lambda l: spare_journey(l, in_another=True), "VIABLE", "not performed, so not judged: 1 of", listed=and_8200)
    expect("an act that does not say whether it was performed", lambda l: every(l, "walk")[0]["acts"][0].pop("performed"), "UNREADABLE", "does not say whether it was performed")
    expect("… or says it in words", lambda l: every(l, "walk")[0]["acts"][0].update(performed="yes"), "UNREADABLE", "does not say whether it was performed")

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

    expect("the page is content with fewer journeys that say something of a kind", lambda l: silent(l, "scroll", 0.75), "VIABLE", "",
           page=with_number(["input", "share_of_journeys_that_judge_a_kind_min"], 0.2))
    expect("the page knows one kind of input more", nothing, "INVALID", "input of the kind pinch", page=with_number(["input", "kinds"], [*gate["input"]["kinds"], "pinch"]))
    least_seen = min(sum(1 for act in run["acts"] if len(act["displays"]) >= 2) / len(run["acts"]) for run in good["runs"] if run["manifest"]["display"] == "two")
    expect("the page asks for exactly the share of acts that the second display was there for", nothing, "VIABLE", "", page=with_number(["display_seen", "two_displays_share_of_acts_min"], least_seen))
    expect("the page asks for the second display during more of the acts", nothing, "INVALID", "it says it had two displays", page=with_number(["display_seen", "two_displays_share_of_acts_min"], 0.9))
    expect("the page has a wider smallest laptop", nothing, "INVALID", "played on a laptop's display", page=with_number(["display_seen", "laptop_width_min"], gate["display_seen"]["laptop_width_max"] + 1))
    expect("the page has a narrower laptop", nothing, "INVALID", "played on a laptop's display", page=with_number(["display_seen", "laptop_width_max"], gate["display_seen"]["laptop_width_max"] - 1))
    expect("the page has another desk", nothing, "INVALID", "played on a desk's display", page=with_number(["display_seen", "desk"], [2560, 1440]))
    expect("the page allows no act at all to go unperformed", lambda l: undone(l, 1), "INVALID", "the instrument is sick", page=with_number(["share_of_acts_not_performed_max"], 0))
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
                step = {"number": number, "slug": act["id"].replace("#", "-"), "act": act["act"], "judged": act["judged"], "performed": act["performed"],
                        "displays": act["displays"], "windows_elsewhere": act["windows_elsewhere"], "findings": []}
                by_id[act["id"]] = step
                steps.append(step)
            # Rounds of input, which are no acts: were they taken for acts, these would be acts that are not judged, and too many of them.
            steps += [{"number": 9000 + n, "slug": f"input-{n}", "act": "instrument", "judged": False, "performed": True, "findings": []} for n in range(len(run["acts"]))]
            for finding in run["findings"]:
                by_id[finding["id"]]["findings"].append({"detector": finding["detector"], "rule": "3", "level": finding["level"], "what": finding["what"]})
            if "offences" in run["manifest"]:
                put(f"{directory}/run.json", dict(run["manifest"], offences=[dict(o, id=o["id"].replace("#", "-") + "#1") for o in run["manifest"]["offences"]]))
            put(f"{directory}/day-findings.json", {"sampler": "samples 30000 seconds 540.0 hz 55.5 cost-ms 1.20 late 10 longest-gap-ms 200", "input": run.get("input"), "steps": steps})
        put("undone/run.json", good["runs"][0]["manifest"])
        put("undone/day-findings.json", {"sampler": "", "steps": [{"number": 1, "slug": "drag", "act": "drag", "judged": False, "performed": False, "displays": [[1600, 900]], "windows_elsewhere": 0, "findings": []},
                                                                 {"number": 2, "slug": "idle", "act": "idle", "judged": True, "performed": True, "displays": [[1600, 900], [1920, 1080]], "windows_elsewhere": 3, "findings": []}]})
        if [act["performed"] for act in run_from(os.path.join(scratch, "undone"))["acts"]] != [False, True]:
            failures.append("the ledger does not carry whether an act was performed")
        if [act["displays"] for act in run_from(os.path.join(scratch, "undone"))["acts"]] != [[[1600, 900]], [[1600, 900], [1920, 1080]]]:
            failures.append("the ledger does not carry what displays the sampler saw")
        if [act["windows_elsewhere"] for act in run_from(os.path.join(scratch, "undone"))["acts"]] != [0, 3]:
            failures.append("the ledger does not carry how many windows lay on the second display")
        # The checker's own sabotage, from files, as a run comes back: a manifest that says "two" over findings in which the sampler saw one display from beginning to end.
        liar = next(run for run in good["runs"] if run["manifest"]["display"] == "two" and run["manifest"]["kind"] in COUNTED)
        put("says-two/run.json", liar["manifest"])
        put("says-two/day-findings.json", {"sampler": "samples 1000 seconds 100 hz 10 cost-ms 1 late 0 longest-gap-ms 30", "input": liar["input"], "steps": [
            {"number": number, "slug": act["id"].replace("#", "-"), "act": act["act"], "judged": True, "performed": True, "displays": [[1600, 900]], "windows_elsewhere": 0, "findings": []}
            for number, act in enumerate(liar["acts"])]})
        said = why_not(run_from(os.path.join(scratch, "says-two")), gate, liar["manifest"]["commit"])
        if said != f"it says it had two displays, and the sampler saw two at the end of 0 of {len(liar['acts'])} acts":
            failures.append(f"a manifest that says two displays over samples that show one: {said}")
        # 1 is a verdict. Whatever a ledger made by hand can break ends in 2.
        for name, change in (("nothing among a run's acts", lambda l: every(l, "control")[0]["acts"].append(None)), ("a number for its apps", lambda l: l["runs"][0]["manifest"].update(apps=5)),
                             ("a list for what it heard", lambda l: l["runs"][0].update(input=[1])), ("a word for its findings", lambda l: l["runs"][0].update(findings="x"))):
            broken = copy.deepcopy(good)
            change(broken)
            put("broken.json", broken)
            with contextlib.redirect_stdout(io.StringIO()) as said:
                code = main(["check", os.path.join(scratch, "broken.json")])
            if code != 2 or "it cannot be read" not in said.getvalue():
                failures.append(f"a ledger with {name}: exit code {code}, wanted 2; it said: {said.getvalue()[-120:]}")
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
    except Exception as problem:  # noqa: BLE001  Whatever a ledger made by hand can break: 1 is a verdict, and this is none.
        print(f"viable.py: it cannot be read: {type(problem).__name__}: {problem}")
        return 2
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
