#!/usr/bin/env python3
"""Checks the arithmetic of mac-queue.py against a table of situations, with GitHub's answers made up.

Contributors decide by its numbers whether to start a run now or later, and a wrong one looks as good as a right one.
The made-up jobs have the shapes the real ones had (see the top of mac-queue.py). No network.
The Linux CI job runs this. Exit code 1 when a row comes out wrong.
"""

import contextlib
import importlib.util
import io
import json
import os
import sys

path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mac-queue.py")
spec = importlib.util.spec_from_file_location("mac_queue", path)
queue = importlib.util.module_from_spec(spec)
spec.loader.exec_module(queue)

MAC, LINUX, RUNNER = ["macos-26"], ["ubuntu-latest"], "GitHub Actions 7"


def at(clock):
    return f"2026-01-01T{clock}Z"


# It is noon in every row, so the last hour began at 11:00:00.
NOON = queue.when(at("12:00:00"))


def job(status, asked, started, ended=None, conclusion=None, runner=RUNNER, name="macos", labels=None):
    return {
        "name": name, "status": status, "conclusion": conclusion, "labels": MAC if labels is None else labels,
        "runner_name": runner, "created_at": at(asked), "started_at": at(started), "completed_at": ended and at(ended),
    }


def waiting(asked, **more):
    return job("queued", asked, asked, runner="", **more)  # `started_at` is a placeholder


def running(asked, started, **more):
    return job("in_progress", asked, started, **more)


def finished(asked, started, ended, conclusion="success", **more):
    return job("completed", asked, started, ended, conclusion, **more)


def skipped(asked, ended):
    return job("completed", asked, ended, ended, "skipped", runner="")


def cancelled_waiting(asked, ended, **more):
    return job("completed", asked, asked, ended, "cancelled", **{"runner": "", **more})


def run(*jobs, branch="feat/x", workflow="ci", title="feat: x", number=1, status="completed", updated="12:00:00"):
    return {
        "id": number, "path": f".github/workflows/{workflow}.yml", "status": status, "head_branch": branch,
        "display_title": title, "html_url": f"https://example.com/runs/{number}", "updated_at": at(updated),
        "jobs": list(jobs),
    }


NOTHING = dict(
    running=0, waiting=0, now=[], over=[], finished=0, waits=0, wait_mean=0, wait_longest=0, run_mean=0, run_longest=0,
    mac_seconds=0, most_at_once=0, by_branch=[], by_job=[], by_mac=[], mean_wait=0, mean_wait_jobs=0, alarm=False,
)
SHELL = dict(workflow="mac-shell", title="Mac shell: scripts/mac-shell/shots-F10.sh [eyes.shots-F10]")

# The situation, the runs, the options, and what is expected of the facts (only the keys that are named).
TABLE = [
    ("an empty hour", [], {}, NOTHING),
    ("a run without jobs", [run()], {}, NOTHING),
    ("a Linux job", [run(finished("11:30:00", "11:30:02", "11:50:00", labels=LINUX), waiting("11:59:00", labels=LINUX))],
     {}, NOTHING),
    ("a job without labels", [run(finished("11:30:00", "11:30:02", "11:50:00", labels=[]))], {}, NOTHING),
    ("a skipped job", [run(skipped("11:30:00", "11:30:00"))], {}, NOTHING),
    ("one that GitHub took a while to skip did not wait for a Mac", [run(skipped("11:30:00", "11:30:03"))], {}, NOTHING),
    ("another kind of Mac", [run(finished("11:30:00", "11:30:10", "11:31:10", labels=["self-hosted", "macOS-15-xlarge"]))],
     {}, dict(finished=1, mac_seconds=60)),

    ("a job still waiting", [run(waiting("11:57:30"), status="queued")], {},
     {**NOTHING, **dict(waiting=1, mean_wait=150, mean_wait_jobs=1, now=[dict(
         state="waiting", seconds=150, job="ci / macos", mac="macos-26", branch="feat/x", script="", url="https://example.com/runs/1")])}),
    ("one that has waited since before the period", [run(waiting("09:00:00"), status="queued")], {},
     dict(waiting=1, mean_wait=10800, mean_wait_jobs=1, waits=0, alarm=True)),
    ("a status nobody has seen counts as waiting", [run(job("pending", "11:59:00", "11:59:00", runner=""))], {},
     dict(waiting=1, running=0, mean_wait=60)),

    ("a job running", [run(running("11:50:00", "11:50:10", name="shell"), status="in_progress", **SHELL)], {},
     dict(running=1, waiting=0, finished=0, waits=1, wait_mean=10, run_mean=0, mac_seconds=590, most_at_once=1,
          mean_wait=10, mean_wait_jobs=1, now=[dict(
              state="running", seconds=590, job="mac-shell / shell", mac="macos-26", branch="feat/x",
              script="shots-F10.sh [eyes.shots-F10]", url="https://example.com/runs/1")])),
    ("one that has run since before the period", [run(running("10:49:00", "10:50:00"), status="in_progress")], {},
     dict(running=1, waits=0, mean_wait_jobs=0, mac_seconds=3600, most_at_once=1, now=[dict(
         state="running", seconds=4200, job="ci / macos", mac="macos-26", branch="feat/x", script="", url="https://example.com/runs/1")])),

    ("a finished job", [run(finished("11:30:00", "11:30:08", "11:40:08"))], {},
     dict(running=0, waiting=0, now=[], finished=1, waits=1, wait_mean=8, wait_longest=8, run_mean=600, run_longest=600,
          mac_seconds=600, most_at_once=1, mean_wait=8, mean_wait_jobs=1, alarm=False)),
    ("a failed one used its Mac too", [run(finished("11:30:00", "11:30:08", "11:40:08", "failure"))], {},
     dict(finished=1, mac_seconds=600)),
    ("so did one cancelled while it ran", [run(finished("11:30:00", "11:30:08", "11:40:08", "cancelled"))], {},
     dict(finished=1, waits=1, wait_mean=8, mac_seconds=600)),
    ("it began before the period: the part within it, the whole run time, not its wait",
     [run(finished("10:40:00", "10:50:00", "11:05:00"))], {},
     dict(finished=1, waits=0, mean_wait_jobs=0, run_mean=900, mac_seconds=300, most_at_once=1)),
    ("it ended before the period", [run(finished("10:30:00", "10:30:08", "10:59:59"))], {}, NOTHING),
    ("a shorter period", [run(finished("11:30:00", "11:30:08", "11:40:08"), finished("11:52:00", "11:52:20", "11:53:20"))],
     dict(minutes=10), dict(finished=1, waits=1, wait_mean=20, mac_seconds=60)),

    ("cancelled while it waited", [run(cancelled_waiting("11:30:00", "11:34:00"))], {},
     {**NOTHING, **dict(waits=1, wait_mean=240, wait_longest=240, mean_wait=240, mean_wait_jobs=1)}),
    ("the same, told by equal times", [run(job("completed", "11:30:00", "11:34:00", "11:34:00", "cancelled"))], {},
     {**NOTHING, **dict(waits=1, wait_mean=240, wait_longest=240, mean_wait=240, mean_wait_jobs=1)}),
    ("the same, without a name at all", [run(cancelled_waiting("11:30:00", "11:34:00", runner=None))], {},
     dict(finished=0, waits=1, wait_mean=240, mac_seconds=0)),
    ("cancelled the moment it was created", [run(cancelled_waiting("11:30:00", "11:30:00"))], {}, NOTHING),
    ("cancelled while it waited, before the period", [run(cancelled_waiting("10:30:00", "10:34:00"))], {}, NOTHING),

    ("one ends the second another starts",
     [run(finished("11:00:00", "11:00:10", "11:10:00"), finished("11:00:00", "11:10:00", "11:20:00"))], {},
     dict(most_at_once=1, finished=2, mac_seconds=1190)),
    ("they share one second",
     [run(finished("11:00:00", "11:00:10", "11:10:01"), finished("11:00:00", "11:10:00", "11:20:00"))], {},
     dict(most_at_once=2)),
    ("five at once, a sixth after the first, two more waiting",
     [run(*[running("11:40:00", f"11:40:0{n}") for n in range(4)], finished("11:40:00", "11:40:04", "11:50:00"),
          running("11:40:00", "11:50:00"), waiting("11:40:00"), waiting("11:41:00"), status="in_progress")], {},
     dict(most_at_once=5, running=5, waiting=2, finished=1)),
    ("one of several jobs alike goes by their common name",
     [run(finished("11:00:00", "11:00:10", "11:10:10", name="shell (a.sh b.sh)"), finished("11:00:00", "11:00:10", "11:10:10", name="shell (c.sh)"))], {},
     dict(by_job=[dict(job="ci / shell", mac_seconds=1200, jobs=2)])),
    ("two kinds of Mac at once: three in all, two of one kind",
     [run(finished("11:00:00", "11:00:10", "11:10:10"), finished("11:00:00", "11:00:10", "11:10:10"),
          finished("11:00:00", "11:00:10", "11:05:10", labels=["macos-15"]))], {},
     dict(most_at_once=3, by_mac=[dict(mac="macos-26", mac_seconds=1200, jobs=2, most_at_once=2),
                                  dict(mac="macos-15", mac_seconds=300, jobs=1, most_at_once=1)])),
    ("two runs, one after the other, and one across both",
     [run(finished("11:00:00", "11:01:00", "11:10:00")), run(finished("11:00:00", "11:11:00", "11:20:00"), number=2),
      run(finished("11:00:00", "11:05:00", "11:15:00"), number=3)], {}, dict(most_at_once=2)),

    ("who: the most Mac minutes first, whoever has more jobs",
     [run(finished("11:00:00", "11:00:10", "11:01:10"), finished("11:00:00", "11:00:10", "11:02:10", name="real-windows")),
      run(finished("11:10:00", "11:10:10", "11:20:10", name="shell"), branch="fix/y", number=2, **SHELL),
      run(running("11:58:50", "11:59:00"), waiting("11:59:00", name="real-windows"), number=3, status="in_progress")], {},
     dict(mac_seconds=840,
          by_branch=[dict(branch="fix/y", mac_seconds=600, jobs=1), dict(branch="feat/x", mac_seconds=240, jobs=3)],
          by_job=[dict(job="mac-shell / shell", mac_seconds=600, jobs=1), dict(job="ci / macos", mac_seconds=120, jobs=2),
                  dict(job="ci / real-windows", mac_seconds=120, jobs=1)])),

    ("mean and longest", [run(finished("11:00:00", "11:00:10", "11:10:10"), finished("11:00:00", "11:01:30", "11:05:30"))],
     {}, dict(wait_mean=50, wait_longest=90, run_mean=420, run_longest=600)),
    ("the mean wait is five minutes exactly: no alarm",
     [run(finished("11:00:00", "11:04:00", "11:10:00"), finished("11:00:00", "11:06:00", "11:10:00"))], {},
     dict(mean_wait=300, alarm=False)),
    ("a second more: alarm",
     [run(finished("11:00:00", "11:04:00", "11:10:00"), finished("11:00:00", "11:06:02", "11:10:00"))], {},
     dict(mean_wait=301, alarm=True)),
    ("those who got a Mac got it at once, those still waiting make the alarm",
     [run(finished("11:00:00", "11:00:10", "11:10:00"), waiting("11:48:00"), status="in_progress")], {},
     dict(wait_mean=10, mean_wait=365, mean_wait_jobs=2, alarm=True)),
    ("one gave up after a long wait: alarm", [run(cancelled_waiting("11:00:00", "11:20:00"))], {}, dict(alarm=True)),
    ("a lower bar", [run(finished("11:00:00", "11:02:00", "11:10:00"))], dict(alarm=1.5), dict(mean_wait=120, alarm=True)),
    ("a higher bar", [run(waiting("11:40:00"))], dict(alarm=30), dict(mean_wait=1200, alarm=False)),
    ("GitHub's clock is ahead of this one", [run(running("11:59:50", "12:00:02"), waiting("12:00:01"))], {},
     dict(running=1, waiting=1, mac_seconds=0, most_at_once=0, mean_wait=6)),
]

FOURTEEN = [run(*[finished("11:00:00", "11:03:20", "11:10:00") for _ in range(14)])]
A_QUEUE = [
    run(running("11:50:00", "11:50:10", name="shell"), status="in_progress", branch="trunk", **SHELL),
    run(waiting("11:48:00"), waiting("11:59:15", name="real-windows"), number=2, status="queued"),
    run(finished("11:00:00", "11:00:10", "11:30:40", name="build"), workflow="release", branch="trunk", number=3),
]
THE_REPORT = """\
GitHub's Macs for owner/repo at 12:00 UTC

NOW: 1 running, 2 waiting
  running   9 min 50 s  mac-shell / shell  macos-26  trunk   shots-F10.sh [eyes.shots-F10]  https://example.com/runs/1
  waiting  12 min 00 s  ci / macos         macos-26  feat/x                                 https://example.com/runs/2
  waiting         45 s  ci / real-windows  macos-26  feat/x                                 https://example.com/runs/2

THE LAST HOUR
  finished     1 job
  wait         mean 10 s, longest 10 s, of 2 jobs that got a Mac or gave up
  run          mean 30 min 30 s, longest 30 min 30 s
  Mac minutes  40
  at once      1 at most

WHO: Mac minutes and jobs by branch
  40 min  2 jobs  trunk

and by workflow / job
  30 min  1 job  release / build
  10 min  1 job  mac-shell / shell

and by kind of Mac
  40 min  2 jobs  macos-26  1 at once at most

mean wait: 3 min 16 s over 4 jobs, 2 of them still waiting"""


def turn(priority, waits, own=0, own_waiting=0, others=0):
    runs = [run(*[waiting("11:59:00")] * waits, *[running("11:50:00", "11:50:10")] * others, branch="theirs", status="in_progress"),
            run(*[running("11:50:00", "11:50:10")] * own, *[waiting("11:59:00")] * own_waiting, number=2, branch="mine", status="in_progress")]
    return queue.hold_back(queue.facts(runs, NOON), priority, "mine")


def said(runs, **options):
    return queue.report(queue.facts(runs, NOON, **options), "owner/repo")


def asked_of_github():
    """What `fetch` asks for and brings back when the first list has more than one page."""
    full = [run(number=n, updated="11:30:00") for n in range(queue.PER_PAGE)]
    rest = [run(number=200, updated="10:59:59"), run(number=201, status="queued", updated="08:00:00")]
    old = run(number=300, status="in_progress", updated="01:00:00")
    asked = []

    def api(request, _jq):
        asked.append(request)
        if "/jobs?" in request:
            return [waiting("11:59:00")]
        if "created=" in request:
            return {"page=1": full, "page=2": rest}[request.rsplit("&", 1)[1]]
        return [rest[1]] if "status=queued" in request else [old]

    real, queue.api = queue.api, api
    try:
        runs = queue.fetch("owner/repo", NOON, 60)
    finally:
        queue.api = real
    lists = [request for request in asked if "/jobs?" not in request]
    return lists, sorted(found["id"] for found in runs), all(found["jobs"] for found in runs)


def ends_with(runs, *arguments):
    """The exit code of the whole script and what it printed, when GitHub answers with `runs` (or does not answer)."""
    def fetch(_repo, _now, _minutes):
        if runs is None:
            raise queue.Unanswered("no answer")
        return runs

    real, queue.fetch, argv, sys.argv = queue.fetch, fetch, sys.argv, ["mac-queue.py", "--repo", "owner/repo", *arguments]
    try:
        with contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()):
            return queue.main(), out.getvalue()
    finally:
        queue.fetch, sys.argv = real, argv


LISTS = "repos/owner/repo/actions/runs?"
# What is checked, what came out, what is expected.
SINGLE = [
    ("the line to grep for", lambda: said(FOURTEEN).splitlines()[-1], "mean wait: 3 min 20 s over 14 jobs"),
    ("the same in an empty hour", lambda: said([]).splitlines()[-1], "mean wait: 0 s over 0 jobs"),
    ("the alarm comes last", lambda: said(FOURTEEN, alarm=3).splitlines()[-2:],
     ["mean wait: 3 min 20 s over 14 jobs", "ALARM: the mean wait is above 3 min; hold back the runs that can wait"]),
    ("no alarm, no such line", lambda: "ALARM" in said(FOURTEEN), False),
    ("the whole report", lambda: said(A_QUEUE), THE_REPORT),
    ("the heading of another period", lambda: "THE LAST 90 MINUTES" in said([], minutes=90), True),
    ("over the limit: three of one branch, running or waiting; two of another are within it",
     lambda: queue.facts([run(running("11:50:00", "11:50:10"), waiting("11:59:00"), waiting("11:59:00"), branch="greedy", status="in_progress"),
                          run(running("11:50:00", "11:50:10"), waiting("11:59:00"), number=2, branch="modest", status="in_progress"),
                          run(*[finished("11:00:00", "11:00:10", "11:10:00")] * 5, number=3, branch="done")], NOON)["over"],
     [dict(branch="greedy", jobs=3)]),
    ("over the limit: it is said under NOW", lambda: [line for line in said(
        [run(*[waiting("11:59:00")] * 3, branch="greedy", status="queued")]).splitlines() if "OVER" in line],
     ["  OVER THE LIMIT of 2 running or waiting for one branch: greedy (3)"]),
    ("over the limit: nobody is, and no such line", lambda: "OVER" in said(A_QUEUE), False),
    ("over the limit: whoever is named there is held back by run.sh at every priority",
     lambda: [bool(turn(n, 0, own=2, own_waiting=1)) for n in (1, 2, 3)], [True] * 3),
    ("whose turn: nobody waits, nothing of its own", lambda: [turn(n, 0) for n in (1, 2, 3)], ["", "", ""]),
    ("whose turn: one waits", lambda: [bool(turn(n, 1)) for n in (1, 2, 3)], [False, False, True]),
    ("whose turn: two wait", lambda: [bool(turn(n, 2)) for n in (1, 2, 3)], [False, False, True]),
    ("whose turn: three wait", lambda: [bool(turn(n, 3)) for n in (1, 2, 3)], [False, True, True]),
    ("whose turn: it says why", lambda: turn(2, 3), "3 jobs waiting for a Mac, and this has priority 2"),
    ("whose turn: one job of its own branch runs", lambda: [bool(turn(n, 0, own=1)) for n in (1, 2, 3)], [False, False, True]),
    ("whose turn: two of its own, one of them still waiting", lambda: [bool(turn(n, 0, own=1, own_waiting=1)) for n in (1, 2, 3)], [True] * 3),
    ("whose turn: it says that too", lambda: turn(1, 0, own=2), "2 jobs for mine are running or waiting already"),
    ("whose turn: five of other branches run, none waits", lambda: [turn(n, 0, others=5) for n in (1, 2, 3)], ["", "", ""]),
    ("exit code 4 when it is not its turn, and only the reason", lambda: ends_with([run(waiting("00:00:00"))], "--turn", "3", "--for", "mine"),
     (4, "1 job waiting for a Mac, and this has priority 3\n")),
    ("exit code 0 when it is, and not a word, however long others have waited", lambda: ends_with([run(waiting("00:00:00"))], "--turn", "1", "--for", "mine"),
     (0, "")),
    ("lengths of time", lambda: [queue.span(n) for n in (0, 59, 60, 200, 3905)],
     ["0 s", "59 s", "1 min 00 s", "3 min 20 s", "65 min 05 s"]),
    ("the repository in a URL", lambda: [queue.name_in(url) for url in (
        "https://github.com/owner/repo", "https://github.com/owner/repo.git", "https://github.com/owner/repo/",
        "git@github.com:owner/repo.git", "ssh://git@github.com/owner/repo.git")], ["owner/repo"] * 5),
    ("the workflow of a run", lambda: [queue.workflow_of({"path": text}) for text in (
        ".github/workflows/ci.yml", ".github/workflows/mac-shell.yml@refs/heads/main", None)], ["ci", "mac-shell", "?"]),
    ("the script of a run", lambda: [queue.script_of({"display_title": text}) for text in (
        "Mac shell: scripts/mac-shell/e2e.sh [123]", "Mac shell: tools/other.sh [t]", "fix: the Mac shell: a typo", None)],
     ["e2e.sh [123]", "tools/other.sh [t]", "", ""]),
    ("the script of a run whose title names the branch", lambda: queue.script_of(
        {"display_title": "Mac shell: scripts/mac-shell/e2e.sh at feat/x [x.e2e]"}), "e2e.sh [x.e2e]"),
    ("whose work a run is", lambda: [queue.branch_of({"display_title": text, "head_branch": "trunk"}) for text in (
        "Mac shell: scripts/mac-shell/e2e.sh at feat/x [x.e2e]", "Mac shell: scripts/mac-shell/e2e.sh [123]",
        "fix: look at feat/x [mac]", None)], ["feat/x", "trunk", "trunk", "trunk"]),
    ("a run of no branch", lambda: queue.branch_of({"display_title": "x", "head_branch": None}), "?"),
    ("lists are read page by page until one is short", lambda: asked_of_github()[0], [
        LISTS + "created=>=2026-01-01T05:00:00Z&per_page=100&page=1",
        LISTS + "created=>=2026-01-01T05:00:00Z&per_page=100&page=2",
        LISTS + "status=queued&per_page=100&page=1",
        LISTS + "status=in_progress&per_page=100&page=1"]),
    ("jobs: once for a run in two lists, not for one that ended before the period, for an old one that still runs",
     lambda: asked_of_github()[1:], (list(range(queue.PER_PAGE)) + [201, 300], True)),
    ("exit code 0", lambda: ends_with([])[0], 0),
    ("exit code 3 with the alarm", lambda: ends_with([run(waiting("00:00:00"))])[0], 3),
    ("exit code 1 without an answer", lambda: ends_with(None), (1, "")),
    ("--json says the same", lambda: [json.loads(ends_with([run(waiting("00:00:00"))], "--json", "--alarm", "7")[1])[key]
                                      for key in ("repo", "waiting", "alarm", "alarm_minutes", "minutes")],
     ["owner/repo", 1, True, 7, 60]),
]


def main():
    wrong = 0
    for situation, runs, options, expected in TABLE:
        found = queue.facts(runs, NOON, **options)
        differing = [f"{key}: expected {value}, got {found[key]}" for key, value in expected.items() if found[key] != value]
        if differing:
            wrong += 1
            print(f"✘ {situation}: " + "; ".join(differing))
    for situation, check, expected in SINGLE:
        found = check()
        if found != expected:
            wrong += 1
            print(f"✘ {situation}: expected {expected!r}, got {found!r}")
    total = len(TABLE) + len(SINGLE)
    print(f"{total - wrong} of {total} situations came out as expected")
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main())
