#!/usr/bin/env python3
"""Says whether there is a queue for GitHub's Macs, how long it is, and who is using them.

GitHub lends the whole repository only a handful of hosted Macs at a time. Every macOS job of every workflow and every
branch shares them: CI's `macos` and `real-windows`, the "Mac shell" runs of scripts/mac-shell/run.sh, the release
build. A job that finds none free waits, and nothing on the run's page says for how long or behind whom. Look here
before starting many runs, and when a run seems stuck.

Usage: scripts/mac-queue.py [--minutes N] [--alarm N] [--json] [--repo owner/name]
       scripts/mac-queue.py --turn 1|2|3 --for <branch> [--tag <tag>] [--known]     for scripts/mac-shell/run.sh: may a run of that priority start now?
       scripts/mac-queue.py --started N --for <branch>       likewise: it has just started a run on N Macs
  --minutes N        how far to look back, 60 by default
  --alarm N          the mean wait, in minutes, above which it says ALARM, 5 by default
  --json             the same facts as one JSON object; every length of time in it is in seconds
  --repo owner/name  another repository than the one `origin` points to

It prints what is running and waiting NOW (and which branch has more than its two jobs there), the waits, run times and Mac minutes of THE LAST HOUR, WHO used them, and
a last line to grep for: `mean wait: 3 min 20 s over 14 jobs`. That mean is over the jobs whose wait ended within the
period (they got a Mac, or gave up) and, at what they have waited so far, those still waiting. The waits further up
leave out the ones still waiting. Mac minutes count only the part of a job that lies within the period, and
a job that is still running counts up to now.

Exit code 0; 3 with a line that starts with `ALARM:` when that mean is above --alarm; 1 when GitHub did not answer.

--turn prints nothing and exits with 0 when the run may start, or says what it should wait for and exits with 4 (5 if it is a train). GitHub hands its Macs
out in no particular order (see below), so whoever can wait does so before starting a run, where waiting takes nobody's place:
priority 1 (a fault on real windows, a merge train) never waits for others, 2 waits while three or more jobs are waiting for a Mac,
3 while any is. And nobody has more than two jobs for one branch running or waiting at a time (priority 3: one); what runs or waits under
--tag does not count, since the run that is about to start replaces it.
A TRAIN GOES FIRST, before every priority: while CI's macOS job for a branch where work is integrated (train/…, swarm/trunk, main) is waiting for a Mac,
nothing else starts. Everybody's landing waits for that job, and a Mac that is taken now is gone for minutes. And it is seen coming: that job is not there
until the job before it has had a Linux runner, for which a train once waited thirteen minutes while others took the Macs. From the moment its run is
queued until it is settled whether it wants a Mac, one of the five is kept free: nothing starts while four or more jobs are running or waiting.
--known answers only from what somebody who shares the cache saw a short while ago, and asks GitHub nothing: exit code 1 if there is no such look.
For priority 1, which is not to be held up by what cannot be found out, nor to pay for finding out.
Needs `gh` and a token that may read the repository. It only reads: one request for every hundred runs, and one for
every run that could have held or wanted a Mac within the period: some twenty to forty. GitHub allows an account 5,000 an hour, for
everything everybody does under it, so do not run this in a loop; the last line but one says what is left.

--turn is made to be asked again and again, and costs little: two requests, and one for every run in progress that is not a Mac shell
run (of those the run's own state tells enough). With $ARBOR_MAC_QUEUE_CACHE naming a file, whoever asks within three minutes of somebody else
reads the answer there and asks GitHub nothing: for several checkouts, containers or people on one machine or one shared folder.
With $ARBOR_STATE_BRANCH naming the branch the poller at GitHub publishes to (scripts/gh-state.py; `state/github`), that file is first brought
up to date from there by `git fetch`, which no limit counts: then nobody who waits for a turn asks GitHub's API anything.
--started writes down beside that file that a run has just been started, and asks GitHub nothing: or everybody who was holding back would read
"nobody waits" in the same look at an emptied queue, and start together. It counts as waiting with every look that was made before the start or
within twenty seconds of it, whoever brings that look and whenever; a later look holds the run itself.

What GitHub's answers mean, found by looking at them on 2026-10-14 while five jobs ran and five waited:

  - A job that `needs:` another is not listed until that one has finished, and its `created_at` is that moment, give
    or take a second, not the moment the run was created. So `started_at` minus `created_at` is the wait for a Mac
    and holds nothing of the time the other job took.
  - With a Mac free that wait is six to twelve seconds, never zero.
  - A job with the status `queued` has a `started_at`, but it is a placeholder, equal to `created_at`; `runner_name`
    is "" and `runner_id` 0. Its wait so far is now minus `created_at`. When it gets a Mac `created_at` stays as it
    was and `started_at` becomes the real time.
  - A job cancelled while it waited is `completed` and `cancelled`, and keeps all of that: the placeholder, which is
    earlier than its `completed_at`, the empty `runner_name`, no steps. So only the missing name tells that it never
    had a Mac; by its times it ran for as long as it waited. `completed_at` is when it was cancelled.
  - Macs are not handed out in the order of asking: a job of 22:38:32 got one while two of 22:37:49 still waited.
  - A Mac is handed on five to seven seconds after the job before has ended.
  - A run with a `run-name`, like those of "Mac shell", has that text as its `name` too, and so has `workflow_name` of
    its jobs. The workflow is told by `path`.

Not seen there: a skipped job. It is left out by its `conclusion`, whatever its times say. And to be careful, any
other finished job whose `started_at` is not before its `completed_at` is taken to have had no Mac either.

What it leaves out: of a run that was run again, all attempts but the last; and a finished run that was created
more than six hours before the period began.
"""

import argparse
import concurrent.futures
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone

PER_PAGE = 100
# A run can be much older than the period and have finished within it. Six hours is the longest a hosted job may take.
OLDER_RUNS = timedelta(hours=6)
# Only what is used: a job's steps are most of the answer.
RUNS = "[.workflow_runs[] | {id, path, status, head_branch, display_title, html_url, updated_at, created_at, run_started_at}]"
JOBS = "[.jobs[] | {name, status, conclusion, labels, runner_name, created_at, started_at, completed_at}]"
AT_ONCE = 8
# For how long one look at the queue will do for everybody who shares a cache. Longer than the round of whoever looks for all, so that
# nobody else asks while there is such a one, and short enough to tell whose turn it is: a Mac is held for minutes.
FRESH_FOR = 200
# "Mac shell: scripts/mac-shell/shots-F10.sh at feat/x [tag]"; "at feat/x" is missing from the runs of older branches.
MAC_SHELL = re.compile(r"^Mac shell(?: \([^)]*\))?: (?:scripts/mac-shell/)?(?P<script>.*?)(?: at (?P<ref>\S+))?(?: \(no pre-flight: .*\))?(?P<tag> \[[^\]]*\])?$")
# Where work is integrated.
INTEGRATED = re.compile(r"^(train/.+|swarm/trunk|main)$")
# GitHub lends the repository five Macs at a time, of all kinds together (measured). For a train that is on its way one of them stays free.
MACS, KEPT_FOR_A_TRAIN = 5, 1
FOR_A_TRAIN = ("a train goes first", "one Mac is kept free for it")
# For so many seconds after a run was started a look may miss it.
MISSED_FOR = 20
ALARMED = 3
NOT_YET = 4
# Not yet, and for everybody alike: when this ends, all who waited would let go together.
A_TRAIN = 5
# How many jobs may be waiting for a Mac when a run of this priority starts, and how many jobs its branch may have already.
MAY_WAIT = {1: None, 2: 2, 3: 0}
OF_ONE_BRANCH = {1: 1, 2: 1, 3: 0}
AT_MOST_OF_ONE_BRANCH = 2


class Unanswered(Exception):
    pass


# What GitHub says


def api(path, jq):
    """The parsed result of `jq` over a GET request."""
    result = subprocess.run(["gh", "api", path, "--jq", jq], capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise Unanswered(f"{path}: {(result.stderr or result.stdout).strip()[:200]}")
    return json.loads(result.stdout)


def pages(path, jq):
    """Every page of a list. By hand: `gh api --paginate` has stopped early on these lists."""
    found, page = [], 1
    while True:
        answer = api(f"{path}&per_page={PER_PAGE}&page={page}", jq)
        found += answer
        if len(answer) < PER_PAGE:
            return found
        page += 1


def could_matter(run, since):
    """Whether a job of this run can have held or wanted a Mac after `since`. Only then are its jobs asked for."""
    return run["status"] != "completed" or when(run["updated_at"]) >= since


def fetch(repo, now, minutes):
    """The runs that could matter, each with its `jobs`."""
    since = now - timedelta(minutes=minutes)
    runs = f"repos/{repo}/actions/runs"
    listed = pages(f"{runs}?created=>={stamp(since - OLDER_RUNS)}", RUNS)
    for status in ("queued", "in_progress"):  # however old
        listed += pages(f"{runs}?status={status}", RUNS)
    wanted = [run for run in {run["id"]: run for run in listed}.values() if could_matter(run, since)]
    with concurrent.futures.ThreadPoolExecutor(AT_ONCE) as pool:
        jobs = pool.map(lambda run: pages(f"{runs}/{run['id']}/jobs?filter=latest", JOBS), wanted)
        return [{**run, "jobs": found} for run, found in zip(wanted, jobs)]


def stands_for(run):
    """A Mac shell run as the one job it mostly is, told from the run alone. Of a run on several Macs this makes one."""
    kind = re.match(r"^Mac shell \(([^)]*)\)", run.get("display_title") or "")
    waits = run["status"] != "in_progress"
    return {
        "name": "shell", "status": "queued" if waits else "in_progress", "conclusion": None, "labels": [kind.group(1) if kind else "macos-26"],
        "runner_name": "" if waits else "?", "created_at": run["created_at"], "started_at": run.get("run_started_at") or run["created_at"],
        "completed_at": None,
    }


def fetch_now(repo):
    """What is running and waiting at this moment, for few requests: good enough to tell whose turn it is."""
    runs = f"repos/{repo}/actions/runs"
    listed = {run["id"]: run for status in ("queued", "in_progress") for run in pages(f"{runs}?status={status}", RUNS)}
    found = []
    for run in listed.values():
        if workflow_of(run) == "mac-shell":
            found.append({**run, "jobs": [stands_for(run)]})
        elif run["status"] == "in_progress":
            # Of a run of which nothing has started yet no job has asked for a Mac either.
            found.append({**run, "jobs": pages(f"{runs}/{run['id']}/jobs?filter=latest", JOBS)})
    return found


def fetched(path, branch=None):
    """Has scripts/gh-state.py bring the cache up to date from the branch the poller at GitHub publishes to, if one is named. It never puts
    an older look in a newer one's place. Whatever goes wrong costs requests, nothing else."""
    branch = os.environ.get("ARBOR_STATE_BRANCH", "") if branch is None else branch
    if not branch or os.path.basename(path) != "mac-queue-cache.json":  # the name it has on the branch, and gets beside the other file
        return
    try:
        subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "gh-state.py"), "--read",
                        os.path.join(os.path.dirname(os.path.abspath(path)), "github-state.md"), "--from", branch, "0"], capture_output=True, timeout=150, check=False)
    except (OSError, subprocess.TimeoutExpired):
        pass


def shared(repo, now, look, path=None, fetch=fetched):
    """`look()`, or what somebody who shares the cache saw a short while ago."""
    path = os.environ.get("ARBOR_MAC_QUEUE_CACHE", "") if path is None else path
    if not path:
        return look()
    fetch(path)
    try:
        with open(path, encoding="utf-8") as handle:
            kept = json.load(handle)
        if kept["repo"] == repo and 0 <= (now - when(kept["at"])).total_seconds() < FRESH_FOR:
            return kept["runs"] + just_started(repo, when(kept["at"]), path)
    except (OSError, ValueError, KeyError, TypeError):
        pass  # none yet, or half of one: then this look is the first
    runs = look()
    try:
        with open(f"{path}.{os.getpid()}", "w", encoding="utf-8") as handle:
            json.dump({"repo": repo, "at": stamp(now), "runs": runs}, handle)
        os.replace(f"{path}.{os.getpid()}", path)
    except OSError:
        pass  # a cache that cannot be written costs requests, nothing else
    return runs + just_started(repo, now, path)


def nobody_looks():
    raise Unanswered("nobody who shares the cache has looked at the queue of late")


def note_started(repo, now, branch, macs, path=None):
    """Writes down, beside the cache, that a run on so many Macs has just been started for `branch`. Where no cache is named, nothing."""
    path = os.environ.get("ARBOR_MAC_QUEUE_CACHE", "") if path is None else path
    if not path:
        return False
    try:
        # Added to, not written anew: two who start at the same moment both get their line. What is old goes when there is much of it.
        if os.path.exists(f"{path}.started") and os.path.getsize(f"{path}.started") > 20_000:
            os.remove(f"{path}.started")
        with open(f"{path}.started", "a", encoding="utf-8") as handle:
            handle.write(json.dumps({"repo": repo, "at": stamp(now), "branch": branch, "macs": macs}) + "\n")
        return True
    except OSError:
        return False


def just_started(repo, looked, path):
    """The runs that were started too late for a look made at `looked` to hold them: as waiting. Not in the cache itself, which anybody's next look
    replaces: one that was made before the start and arrives after it (the poller's takes a while to get here) would take the note with it."""
    try:
        with open(f"{path}.started", encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except OSError:
        return []
    runs = []
    for number, line in enumerate(lines):
        try:
            note = json.loads(line)
            if note["repo"] != repo or when(note["at"]) + timedelta(seconds=MISSED_FOR) <= looked:
                continue
            for mac in range(int(note["macs"])):
                run = {
                    "id": f"just started {note['at']} {number} {mac}", "path": ".github/workflows/mac-shell.yml", "status": "queued", "head_branch": note["branch"],
                    "display_title": f"Mac shell: just started at {note['branch']} [?]", "html_url": "", "updated_at": note["at"], "created_at": note["at"],
                    "run_started_at": note["at"],
                }
                runs.append({**run, "jobs": [stands_for(run)]})
        except (ValueError, KeyError, TypeError, AttributeError):
            pass  # half a line: somebody is writing it
    return runs


def left_this_hour():
    """What is left of the hour's requests. Asking this costs none."""
    try:
        left = api("rate_limit", ".resources.core")
        return f"GitHub's API: {left['remaining']} of {left['limit']} requests left until {stamp(datetime.fromtimestamp(left['reset'], timezone.utc))[11:16]} UTC"
    except (Unanswered, KeyError, TypeError, ValueError):
        return ""


def repository():
    """owner/name of `origin`, as scripts/mac-shell/run.sh finds it."""
    here = os.path.dirname(os.path.abspath(__file__))
    command = ["git", "remote", "get-url", "origin"]
    result = subprocess.run(command, cwd=here, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise Unanswered("there is no remote named origin; name the repository with --repo owner/name")
    return name_in(result.stdout.strip())


def name_in(url):
    url = re.sub(r"^(https://[^/]*/|git@[^:]*:|ssh://[^/]*/)", "", url)
    return re.sub(r"/$", "", re.sub(r"\.git$", "", url))


# The arithmetic: nothing below asks anybody anything


def when(text):
    return datetime.fromisoformat(text.replace("Z", "+00:00")) if text else None


def stamp(time):
    return time.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def seconds(start, end):
    """Never negative: this machine's clock and GitHub's differ by a little."""
    return max(0, round((end - start).total_seconds()))


def on_a_mac(job):
    return any(label.lower().startswith("macos") for label in job.get("labels") or [])


def workflow_of(run):
    """`ci` for .github/workflows/ci.yml. The run's `name` will not do, see above."""
    return os.path.splitext(os.path.basename((run.get("path") or "?").split("@")[0]))[0]


def script_of(run):
    """`shots-F10.sh [eyes.shots-F10]` for a Mac shell run, nothing for any other."""
    title = MAC_SHELL.match(run.get("display_title") or "")
    return title.group("script") + (title.group("tag") or "") if title else ""


def branch_of(run):
    """Whose work it is. run.sh starts every Mac shell run from one branch's workflow, and the title says for which branch."""
    title = MAC_SHELL.match(run.get("display_title") or "")
    return title and title.group("ref") or run.get("head_branch") or "?"


def look_at(run, job, now):
    """One macOS job: its state, how long it waited, and from when to when it held a Mac (`start`, `end`)."""
    asked, started, ended = (when(job.get(key)) for key in ("created_at", "started_at", "completed_at"))
    found = {
        # Of a job that is one of several alike, "shell (a.sh b.sh)", only the name: the title of the run has the rest.
        "job": f"{workflow_of(run)} / {job['name'].split(' (')[0]}",
        "branch": branch_of(run),
        "mac": next(label for label in job["labels"] if label.lower().startswith("macos")),
        "script": script_of(run),
        "url": run.get("html_url") or "",
        "asked": asked,
        "start": None,
        "end": None,
    }
    if job["status"] == "completed":
        if job.get("runner_name") and started and started < ended:
            return {**found, "state": "finished", "wait": seconds(asked, started), "start": started, "end": ended}
        return {**found, "state": "gave up", "wait": seconds(asked, ended), "end": ended}
    if job["status"] == "in_progress":
        return {**found, "state": "running", "wait": seconds(asked, started), "start": started, "end": now}
    return {**found, "state": "waiting", "wait": seconds(asked, now)}


def mac_jobs(runs, now):
    return [
        look_at(run, job, now)
        for run in runs
        for job in run["jobs"]
        if on_a_mac(job) and job.get("conclusion") != "skipped"
    ]


def trains_coming(runs):
    """The branches where work is integrated whose CI run is under way and has not got as far as its macOS job: neither started, nor left out, nor waiting."""
    return sorted({
        branch_of(run) for run in runs
        if workflow_of(run) == "ci" and INTEGRATED.match(branch_of(run)) and run.get("status") != "completed" and not any(on_a_mac(job) for job in run["jobs"])
    })


def most_at_once(spans):
    """How many of the (start, end) hold at one moment, at most. One ending as another starts is a Mac handed on."""
    spans = [(start, end) for start, end in spans if start < end]
    held = most = 0
    # At the same moment -1 sorts before 1.
    for _time, step in sorted([(end, -1) for _start, end in spans] + [(start, 1) for start, _end in spans]):
        held += step
        most = max(most, held)
    return most


def mean(numbers):
    return round(sum(numbers) / len(numbers)) if numbers else 0


def shares(used, key):
    """Mac seconds and jobs for every value of `key`, the most seconds first."""
    sums = {}
    for job, span in used:
        entry = sums.setdefault(job[key], {key: job[key], "mac_seconds": 0, "jobs": 0})
        entry["mac_seconds"] += span
        entry["jobs"] += 1
    return sorted(sums.values(), key=lambda entry: (-entry["mac_seconds"], entry[key]))


def facts(runs, now, minutes=60, alarm=5):
    """Everything there is to say, ready for JSON."""
    since = now - timedelta(minutes=minutes)
    jobs = mac_jobs(runs, now)
    running = sorted((job for job in jobs if job["state"] == "running"), key=lambda job: job["start"])
    waiting = sorted((job for job in jobs if job["state"] == "waiting"), key=lambda job: job["asked"])
    finished = [job for job in jobs if job["state"] == "finished" and job["end"] >= since]

    # Whose wait came to an end within the period. One cancelled the moment it was created did not wait.
    served = [job["wait"] for job in jobs if job["start"] and job["start"] >= since]
    served += [job["wait"] for job in jobs if job["state"] == "gave up" and job["end"] >= since and job["wait"] > 0]
    all_waits = served + [job["wait"] for job in waiting]

    held = [(job, max(job["start"], since), job["end"]) for job in jobs if job["start"] and job["end"] > since]
    used = [(job, seconds(start, end)) for job, start, end in held]

    in_flight = {}
    for job in running + waiting:
        in_flight[job["branch"]] = in_flight.get(job["branch"], 0) + 1

    def line(job):
        lasted = job["wait"] if job["state"] == "waiting" else seconds(job["start"], now)
        rest = {key: job[key] for key in ("job", "mac", "branch", "script", "url")}
        return {"state": job["state"], "seconds": lasted, **rest}

    return {
        "at": stamp(now),
        "minutes": minutes,
        "running": len(running),
        "waiting": len(waiting),
        "now": [line(job) for job in running + waiting],
        "trains_coming": trains_coming(runs),
        # By the rule --turn holds a run back on, so that whoever looks here and run.sh see the same thing.
        "over": [{"branch": branch, "jobs": own} for branch, own in sorted(in_flight.items()) if own > AT_MOST_OF_ONE_BRANCH],
        "finished": len(finished),
        "waits": len(served),
        "wait_mean": mean(served),
        "wait_longest": max(served, default=0),
        "run_mean": mean([seconds(job["start"], job["end"]) for job in finished]),
        "run_longest": max((seconds(job["start"], job["end"]) for job in finished), default=0),
        "mac_seconds": sum(span for _job, span in used),
        "most_at_once": most_at_once([(start, end) for _job, start, end in held]),
        "by_branch": shares(used, "branch"),
        "by_job": shares(used, "job"),
        # Whether each kind has a limit of its own shows here: more at once in all than of any one kind.
        "by_mac": [{**entry, "most_at_once": most_at_once([(start, end) for job, start, end in held if job["mac"] == entry["mac"]])}
                   for entry in shares(used, "mac")],
        "mean_wait": mean(all_waits),
        "mean_wait_jobs": len(all_waits),
        "alarm_minutes": alarm,
        "alarm": mean(all_waits) > alarm * 60,
    }


def hold_back(found, priority, branch, tag=""):
    """Why a run of that priority for that branch should not start yet; nothing if it may."""
    trains = [job["branch"] for job in found["now"] if job["state"] == "waiting" and job["job"].startswith("ci /") and INTEGRATED.match(job["branch"])]
    if trains and not INTEGRATED.match(branch):
        return f"CI's macOS job for {trains[0]} is waiting for a Mac, and {FOR_A_TRAIN[0]}"
    if found["trains_coming"] and not INTEGRATED.match(branch) and len(found["now"]) >= MACS - KEPT_FOR_A_TRAIN:
        return f"{found['trains_coming'][0]} is on its way to a Mac, and {count(len(found['now']))} are running or waiting: {FOR_A_TRAIN[1]}"
    # A run started again under its tag cancels the one before (the workflow's concurrency group), so that one takes nobody's place.
    own = sum(1 for job in found["now"] if job["branch"] == branch and not (tag and job["script"].endswith(f" [{tag}]")))
    if own > OF_ONE_BRANCH[priority]:
        return f"{count(own)} for {branch} {'is' if own == 1 else 'are'} running or waiting already"
    if MAY_WAIT[priority] is not None and found["waiting"] > MAY_WAIT[priority]:
        return f"{count(found['waiting'])} waiting for a Mac, and this has priority {priority}"
    return ""


# Saying it


def span(length):
    return f"{length // 60} min {length % 60:02d} s" if length >= 60 else f"{length} s"


def count(number, noun="job"):
    return f"{number} {noun}" + ("" if number == 1 else "s")


def columns(rows, right=()):
    """The rows as lines, every column as wide as its widest cell; the columns in `right` are set flush right."""
    widths = [max(len(row[index]) for row in rows) for index in range(len(rows[0]))] if rows else []
    return [
        "  " + "  ".join(cell.rjust(width) if index in right else cell.ljust(width)
                         for index, (cell, width) in enumerate(zip(row, widths))).rstrip()
        for row in rows
    ]


def last_lines(found):
    still = f", {found['waiting']} of them still waiting" if found["waiting"] else ""
    lines = [f"mean wait: {span(found['mean_wait'])} over {count(found['mean_wait_jobs'])}{still}"]
    if found["alarm"]:
        lines.append(f"ALARM: the mean wait is above {found['alarm_minutes']:g} min; hold back the runs that can wait")
    return lines


def report(found, repo, left=""):
    period = "THE LAST HOUR" if found["minutes"] == 60 else f"THE LAST {found['minutes']} MINUTES"
    share = lambda key: columns(
        [(f"{round(entry['mac_seconds'] / 60)} min", count(entry["jobs"]), entry[key])
         for entry in found["by_" + key]],
        right=(0, 1),
    )
    return "\n".join(
        [f"GitHub's Macs for {repo} at {found['at'][11:16]} UTC", ""]
        + [f"NOW: {found['running']} running, {found['waiting']} waiting"]
        + columns([(job["state"], span(job["seconds"]), job["job"], job["mac"], job["branch"], job["script"], job["url"])
                   for job in found["now"]], right=(1,))
        + [f"  OVER THE LIMIT of {AT_MOST_OF_ONE_BRANCH} running or waiting for one branch: "
           + ", ".join(f"{entry['branch']} ({entry['jobs']})" for entry in found["over"])] * bool(found["over"])
        + ["", period]
        + columns([
            ("finished", count(found["finished"])),
            ("wait", f"mean {span(found['wait_mean'])}, longest {span(found['wait_longest'])}, "
                     f"of {count(found['waits'])} that got a Mac or gave up"),
            ("run", f"mean {span(found['run_mean'])}, longest {span(found['run_longest'])}"),
            ("Mac minutes", str(round(found["mac_seconds"] / 60))),
            ("at once", f"{found['most_at_once']} at most"),
        ])
        + ["", "WHO: Mac minutes and jobs by branch"] + share("branch")
        + ["", "and by workflow / job"] + share("job")
        + ["", "and by kind of Mac"]
        + columns([(f"{round(entry['mac_seconds'] / 60)} min", count(entry["jobs"]), entry["mac"], f"{entry['most_at_once']} at once at most")
                   for entry in found["by_mac"]], right=(0, 1))
        + [""] + [left] * bool(left) + last_lines(found)
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--minutes", type=int, default=60, help="how far to look back")
    parser.add_argument("--alarm", type=float, default=5, help="the mean wait, in minutes, above which it says ALARM")
    parser.add_argument("--json", action="store_true", help="the same facts as one JSON object")
    parser.add_argument("--repo", help="owner/name, instead of what origin points to")
    parser.add_argument("--turn", type=int, choices=sorted(MAY_WAIT), help="may a run of this priority start now?")
    parser.add_argument("--started", type=int, metavar="N", help="a run on N Macs has just been started: let whoever shares the cache know")
    parser.add_argument("--for", dest="branch", default="", help="with --turn and --started: the branch the run is for")
    parser.add_argument("--tag", default="", help="with --turn: the run's tag; what runs under it already will be replaced, and does not count")
    parser.add_argument("--known", action="store_true", help="with --turn: only from the shared cache, without asking GitHub")
    args = parser.parse_args()

    try:
        repo = args.repo or repository()
        now = datetime.now(timezone.utc)
        if args.started:
            note_started(repo, now, args.branch, args.started)
            return 0
        runs = shared(repo, now, nobody_looks if args.known else lambda: fetch_now(repo)) if args.turn else fetch(repo, now, args.minutes)
        found = facts(runs, now, args.minutes, args.alarm)
    except Unanswered as error:
        print(f"mac-queue.py: {error}", file=sys.stderr)
        return 1
    if args.turn:
        why = hold_back(found, args.turn, args.branch, args.tag)
        print(why, end="\n" if why else "")
        return (A_TRAIN if why.endswith(FOR_A_TRAIN) else NOT_YET) if why else 0
    print(json.dumps({"repo": repo, **found}, indent=2) if args.json else report(found, repo, left_this_hour()))
    return ALARMED if found["alarm"] else 0


if __name__ == "__main__":
    sys.exit(main())
