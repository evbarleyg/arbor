#!/usr/bin/env python3
"""Says whether there is a queue for GitHub's Macs, how long it is, and who is using them.

GitHub lends the whole repository only a handful of hosted Macs at a time. Every macOS job of every workflow and every
branch shares them: CI's `macos` and `real-windows`, the "Mac shell" runs of scripts/mac-shell/run.sh, the release
build. A job that finds none free waits, and nothing on the run's page says for how long or behind whom. Look here
before starting many runs, and when a run seems stuck.

Usage: scripts/mac-queue.py [--minutes N] [--alarm N] [--json] [--repo owner/name]
  --minutes N        how far to look back, 60 by default
  --alarm N          the mean wait, in minutes, above which it says ALARM, 5 by default
  --json             the same facts as one JSON object; every length of time in it is in seconds
  --repo owner/name  another repository than the one `origin` points to

It prints what is running and waiting NOW, the waits, run times and Mac minutes of THE LAST HOUR, WHO used them, and
a last line to grep for: `mean wait: 3 min 20 s over 14 jobs`. That mean is over the jobs whose wait ended within the
period (they got a Mac, or gave up) and, at what they have waited so far, those still waiting. The waits further up
leave out the ones still waiting. Mac minutes count only the part of a job that lies within the period, and
a job that is still running counts up to now.

Exit code 0; 3 with a line that starts with `ALARM:` when that mean is above --alarm; 1 when GitHub did not answer.
Needs `gh` and a token that may read the repository. It only reads: one request for every hundred runs, and one for
every run that could have held or wanted a Mac within the period.

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
RUNS = "[.workflow_runs[] | {id, path, status, head_branch, display_title, html_url, updated_at}]"
JOBS = "[.jobs[] | {name, status, conclusion, labels, runner_name, created_at, started_at, completed_at}]"
AT_ONCE = 8
# "Mac shell: scripts/mac-shell/shots-F10.sh at feat/x [tag]"; "at feat/x" is missing from the runs of older branches.
MAC_SHELL = re.compile(r"^Mac shell(?: \([^)]*\))?: (?:scripts/mac-shell/)?(?P<script>.*?)(?: at (?P<ref>\S+))?(?P<tag> \[[^\]]*\])?$")
ALARMED = 3


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
        "job": f"{workflow_of(run)} / {job['name']}",
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


def report(found, repo):
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
        + [""] + last_lines(found)
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--minutes", type=int, default=60, help="how far to look back")
    parser.add_argument("--alarm", type=float, default=5, help="the mean wait, in minutes, above which it says ALARM")
    parser.add_argument("--json", action="store_true", help="the same facts as one JSON object")
    parser.add_argument("--repo", help="owner/name, instead of what origin points to")
    args = parser.parse_args()

    try:
        repo = args.repo or repository()
        now = datetime.now(timezone.utc)
        found = facts(fetch(repo, now, args.minutes), now, args.minutes, args.alarm)
    except Unanswered as error:
        print(f"mac-queue.py: {error}", file=sys.stderr)
        return 1
    print(json.dumps({"repo": repo, **found}, indent=2) if args.json else report(found, repo))
    return ALARMED if found["alarm"] else 0


if __name__ == "__main__":
    sys.exit(main())
