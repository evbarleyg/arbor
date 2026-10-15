#!/usr/bin/env python3
"""One poller, many readers: asks GitHub how things stand, for everybody, and writes it into one file.

GitHub allows an account five thousand requests an hour. Agents that work under one account share them, and each one that waits for a
check by asking every ten seconds spends six a minute; a dozen of them, with a look at the queue for the Macs now and then, spend
the lot, and then nobody can read a check, open a pull request or start a run until the hour is up. That has happened.

So ONE process asks, every two or three minutes, and all the others read what it wrote. It asks sparingly: with If-None-Match wherever
it has asked before (an answer of "nothing has changed" does not count against the limit), for a commit's checks only while they
are unfinished, for a run's jobs only where a Mac can be among them, and git itself for what git can tell. When few of the
hour's requests are left it stops asking until the hour is up, and says so in the file.

The file is plain text: when it was read, how many requests are left, where `swarm/trunk` and `main` stand, a line for each open
pull request with its checks, what was closed lately, who has a Mac and who waits for one. It is written beside and renamed, so
a reader never sees half of it.

With --queue it also writes, from the same answers, the file scripts/mac-queue.py shares one look at the queue through
($ARBOR_MAC_QUEUE_CACHE): as long as that is fresh, nobody who waits for a turn on a Mac asks GitHub anything.

Usage: scripts/gh-state.py --out FILE [--queue FILE] [--every SECONDS] [--cache FILE] [--once]    the poller; 150 seconds by default
       scripts/gh-state.py --read FILE [WHAT]                 prints the file, or the lines about WHAT (a pull request's number, a branch, a commit)
       scripts/gh-state.py --read FILE --wait WHAT [--for MINUTES]   waits, asking nobody, until WHAT's checks have all finished; 60 by default
       scripts/gh-state.py --self-test

--wait exits with 0 when all is green, 1 when something failed, 3 when the time was up or the file has gone stale (nobody is polling).
Needs a token in $GH_TOKEN or $GITHUB_TOKEN, or `gh` logged in; the repository is $GITHUB_REPOSITORY or the one `origin` points to.
"""

import argparse
import datetime
import http.client
import importlib.util
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
EVERY = 150
# Below this many requests the poller leaves the rest to those who have to act.
LEAVE = 400
# A file older than this was written by a poller that has stopped.
STALE = datetime.timedelta(minutes=12)
# Workflows a job of which can want a Mac, besides the Mac shell. Of the others' runs only the number matters.
WITH_MACS = re.compile(r"/(ci|release)\.yml$")
MAC_SHELL = re.compile(r"/mac-shell\.yml$")
# What scripts/mac-queue.py keeps of a run and of a job.
OF_A_RUN = ("id", "path", "status", "head_branch", "display_title", "html_url", "updated_at", "created_at", "run_started_at")
OF_A_JOB = ("name", "status", "conclusion", "labels", "runner_name", "created_at", "started_at", "completed_at")
MARKS = {"success": "✔", "failure": "✘", "skipped": "–", "cancelled": "∅", "timed_out": "✘", "neutral": "–", "action_required": "?", "startup_failure": "✘",
         "queued": "⧖", "in_progress": "…", "waiting": "⧖", "pending": "⧖", "requested": "⧖"}
RED = {"failure", "timed_out", "startup_failure", "action_required"}
NO_ANSWER = (OSError, http.client.HTTPException, ValueError)


def utc(text):
    return datetime.datetime.fromisoformat(text.replace("Z", "+00:00"))


class GitHub:
    """GET requests that remember what they were told, and how many of them counted."""

    def __init__(self, repository, token, cache=None):
        self.repository, self.token, self.cache, self.counted = repository, token, cache if cache is not None else {}, []

    def fetch(self, url, etag):
        """(status, etag, body) of one request. Apart, so that the self-test can stand in for it."""
        headers = {"Authorization": f"Bearer {self.token}", "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}
        if etag:
            headers["If-None-Match"] = etag
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as answer:
                return answer.status, answer.headers.get("ETag"), json.loads(answer.read())
        except urllib.error.HTTPError as error:
            if error.code == 304:
                return 304, etag, None
            raise

    def get(self, path, keep, now=None):
        """`keep` of the answer to a request: only what is used is remembered, since answers are large."""
        url = f"https://api.github.com/repos/{self.repository}{path}" if path.startswith("/") else f"https://api.github.com/{path}"
        etag, kept = self.cache.get(url, (None, None))
        status, etag, body = self.fetch(url, etag)
        if status != 304:
            kept = keep(body)
            self.cache[url] = (etag, kept)
            if path != "rate_limit":
                self.counted.append(now or time.time())
        return kept

    def forget(self, but):
        """Drops what is remembered of requests that will not be made again."""
        for url in [url for url in self.cache if ("/check-runs" in url or "/jobs" in url) and not any(part in url for part in but)]:
            del self.cache[url]


def heads_by_git(cwd=None):
    """Where the branches work is integrated on stand. git's own protocol has no such limit."""
    listed = subprocess.run(["git", "ls-remote", "origin", "refs/heads/swarm/trunk", "refs/heads/main"], cwd=cwd or HERE, capture_output=True, text=True, timeout=60, check=False)
    return {name.replace("refs/heads/", ""): sha[:8] for sha, name in (line.split("\t") for line in listed.stdout.splitlines() if "\t" in line)}


def read_state(github, finished, now):
    """Everything the file says, as a dictionary. `finished`: commit → its checks, for commits whose checks are all in; kept between rounds."""
    limit = github.get("rate_limit", lambda body: body["resources"]["core"])
    state = {"limit": limit, "paused": limit["remaining"] < LEAVE}
    if state["paused"]:
        return state
    pull = lambda item: {"number": item["number"], "branch": item["head"]["ref"], "sha": item["head"]["sha"], "base": item["base"]["ref"], "title": item["title"],
                         "draft": item["draft"], "merged": bool(item.get("merged_at")), "closed_at": item.get("closed_at")}
    state["open"] = github.get("/pulls?state=open&per_page=100", lambda body: [pull(item) for item in body])
    state["closed"] = github.get("/pulls?state=closed&sort=updated&direction=desc&per_page=15", lambda body: [pull(item) for item in body])
    run = lambda item: {**{key: item.get(key) for key in OF_A_RUN}, "sha": item["head_sha"]}
    active = []
    for status in ("queued", "in_progress"):
        active += github.get(f"/actions/runs?status={status}&per_page=100", lambda body: [run(item) for item in body["workflow_runs"]])
    state["active"] = list({item["id"]: item for item in active}.values())

    busy = {item["sha"] for item in state["active"]}
    check = lambda item: {"name": item["name"], "state": item["conclusion"] or item["status"], "since": item["started_at"]}
    state["checks"] = {}
    for item in state["open"]:
        sha = item["sha"]
        if sha not in finished:
            checks = github.get(f"/commits/{sha}/check-runs?per_page=100", lambda body: [check(one) for one in body["check_runs"]])
            state["checks"][sha] = checks
            # All in: there are some, none is under way, and no run for the commit is still to come.
            if checks and sha not in busy and all(one["state"] in MARKS and MARKS[one["state"]] not in "⧖…" for one in checks):
                finished[sha] = checks
        state["checks"][sha] = finished.get(sha, state["checks"].get(sha, []))
    for sha in [sha for sha in finished if sha not in {item["sha"] for item in state["open"]}]:
        del finished[sha]

    state["macs"] = []
    for item in state["active"]:
        path = "/" + item["path"].split("@")[0]
        if MAC_SHELL.search(path):
            # One job on one Mac, which the run's own state tells of: as scripts/mac-queue.py takes it.
            kind, waits = re.match(r"^Mac shell \(([^)]*)\)", item["display_title"] or ""), item["status"] != "in_progress"
            item["jobs"] = [{"name": "shell", "status": "queued" if waits else "in_progress", "conclusion": None, "labels": [kind.group(1) if kind else "macos-26"],
                             "runner_name": "" if waits else "?", "created_at": item["created_at"], "started_at": item.get("run_started_at") or item["created_at"], "completed_at": None}]
        elif WITH_MACS.search(path) and item["status"] == "in_progress":  # of a run of which nothing has started no job has asked for a Mac either
            item["jobs"] = github.get(f"/actions/runs/{item['id']}/jobs?filter=latest&per_page=100", lambda body: [{key: one.get(key) for key in OF_A_JOB} for one in body["jobs"]])
        else:
            item["jobs"] = []
        state["macs"] += [{**one, "branch": item["head_branch"], "title": item["display_title"], "path": path} for one in item["jobs"]
                          if one["status"] != "completed" and any("macos" in label.lower() for label in one["labels"])]
    github.forget([item["sha"] for item in state["open"]] + [f"/runs/{item['id']}/" for item in state["active"]])
    return state


def verdict(checks):
    """One word for a commit's checks."""
    states = [one["state"] for one in checks]
    if not states:
        return "NO CHECKS YET"
    if any(state in RED for state in states):
        return "RED" if all(MARKS.get(state, "?") not in "⧖…" for state in states) else "RED, unfinished"
    if any(MARKS.get(state, "?") in "⧖…" for state in states):
        return "unfinished"
    return "CANCELLED" if "cancelled" in states else "GREEN"


def minutes(since, now):
    return f"{max(0, int((now - utc(since)).total_seconds() // 60))} min"


def written(state, heads, now, every, spent):
    """The file's text."""
    limit = state["limit"]
    lines = ["# How things stand at GitHub, asked by one poller for everybody (scripts/gh-state.py)", "",
             f"read {now.strftime('%Y-%m-%d %H:%M:%S')} UTC, next in about {every} s",
             f"requests left this hour: {limit['remaining']} of {limit['limit']}, new ones at {datetime.datetime.fromtimestamp(limit['reset'], datetime.timezone.utc).strftime('%H:%M:%S')} UTC; "
             f"the poller spent {spent} in the last hour",
             f"A time more than {int(STALE.total_seconds() // 60)} minutes old means that the poller has stopped: say so, and do not start polling yourself.", "",
             " · ".join(f"{name} {sha}" for name, sha in sorted(heads.items(), reverse=True)) or "(git did not say where the branches stand)"]
    if state["paused"]:
        return "\n".join(lines + ["", f"PAUSED: fewer than {LEAVE} requests are left, and they are for those who have to act. What stood here before is out of date."]) + "\n"
    lines += ["", f"## Open pull requests: {len(state['open'])}", "", "✔ passed  ✘ failed  – skipped  ∅ cancelled  … running  ⧖ waiting", ""]
    for item in sorted(state["open"], key=lambda item: item["number"]):
        checks = {}
        for one in state["checks"][item["sha"]]:  # of two runs of one name the worse shows, then the unfinished
            rank = lambda value: (value in RED, MARKS.get(value, "?") in "⧖…", value == "success")
            if one["name"] not in checks or rank(one["state"]) > rank(checks[one["name"]]):
                checks[one["name"]] = one["state"]
        shown = " ".join(f"{name} {MARKS.get(value, '?')}" for name, value in sorted(checks.items()))
        lines.append(f"#{item['number']} {item['branch']} {item['sha'][:8]} -> {item['base']}{' (draft)' if item['draft'] else ''} | {verdict(state['checks'][item['sha']])} | {shown} | {item['title'][:90]}")
    lines += ["", "## Closed lately", ""]
    for item in state["closed"]:
        lines.append(f"#{item['number']} {'landed' if item['merged'] else 'closed'} {utc(item['closed_at']).strftime('%H:%M')} {item['branch']} {item['sha'][:8]} -> {item['base']} | {item['title'][:90]}")
    running, waiting = [one for one in state["macs"] if one["status"] == "in_progress"], [one for one in state["macs"] if one["status"] != "in_progress"]
    lines += ["", f"## Macs: {len(running)} running, {len(waiting)} waiting", ""]
    for word, since, jobs in (("running", "started_at", running), ("waiting", "created_at", waiting)):
        for one in sorted(jobs, key=lambda one: one[since]):
            what = one["title"] if one["path"].endswith("mac-shell.yml") else f"{one['name']} of {one['branch']}"
            lines.append(f"{word} {minutes(one[since], now)}: {what[:120]}")
    others = [item for item in state["active"]]
    lines += ["", f"## Runs of all kinds: {sum(item['status'] != 'in_progress' for item in others)} waiting, {sum(item['status'] == 'in_progress' for item in others)} running"]
    return "\n".join(lines) + "\n"


def save(path, text):
    beside = f"{path}.{os.getpid()}.new"
    with open(beside, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(beside, path)


def poll(github, out, cache_file, every, once, clock=time.time, sleep=time.sleep, heads=heads_by_git, queue=None):
    finished = {}
    while True:
        now = datetime.datetime.fromtimestamp(clock(), datetime.timezone.utc)
        try:
            state = read_state(github, finished, now)
            github.counted = [at for at in github.counted if at > clock() - 3600]
            save(out, written(state, heads(), now, every, len(github.counted)))
            if queue and not state["paused"]:
                runs = [{key: value for key, value in item.items() if key != "sha"} for item in state["active"]]
                save(queue, json.dumps({"repo": github.repository, "at": now.strftime("%Y-%m-%dT%H:%M:%SZ"), "runs": runs}))
            if cache_file:
                save(cache_file, json.dumps(github.cache))
            print(f"{now.strftime('%H:%M:%S')} written; {state['limit']['remaining']} left, {len(github.counted)} spent here in the last hour", flush=True)
        except (*NO_ANSWER, KeyError, TypeError, subprocess.TimeoutExpired) as error:  # the next round may fare better; the file's time tells
            print(f"{now.strftime('%H:%M:%S')} no round: {type(error).__name__}: {error}", flush=True)
        if once:
            return 0
        sleep(every)


# MARK: readers

def lines_about(text, what):
    what = what.lstrip("#")
    if re.fullmatch(r"[0-9a-f]{8,40}", what):
        what = what[:8]  # as commits are written in the file
    pattern = re.compile(rf"^#{what} " if what.isdigit() and len(what) < 8 else rf"(^| ){re.escape(what)}( |$)")
    return [line for line in text.splitlines() if line.startswith("#") and " | " in line and pattern.search(line)]


def age_of(text, now):
    found = re.search(r"^read (\d{4}-\d\d-\d\d \d\d:\d\d:\d\d) UTC", text, re.MULTILINE)
    return now - datetime.datetime.strptime(found.group(1), "%Y-%m-%d %H:%M:%S").replace(tzinfo=datetime.timezone.utc) if found else None


def wait(path, what, limit, clock=time.time, sleep=time.sleep):
    until = clock() + limit * 60
    while True:
        try:
            with open(path, encoding="utf-8") as handle:
                text = handle.read()
        except OSError:
            text = ""
        age = age_of(text, datetime.datetime.fromtimestamp(clock(), datetime.timezone.utc))
        if age is None or age > STALE:
            print(f"{path} is missing or out of date: nobody is polling. Say so; do not start polling yourself.")
            return 3
        found = lines_about(text, what)
        for line in found:
            word = line.split(" | ")[1]
            if " landed " in line or " closed " in line or word in ("GREEN", "RED", "CANCELLED"):
                print(line)
                return 0 if word == "GREEN" or " landed " in line else 1
        if clock() >= until:
            print("\n".join(found) or f"nothing about {what} in {path}")
            return 3
        sleep(30)


# MARK: --self-test

def self_test():
    import contextlib
    import io
    import tempfile
    rows = []
    start = datetime.datetime(2026, 1, 2, 12, 0, tzinfo=datetime.timezone.utc)

    class Stub(GitHub):
        """GitHub's part made up: path → body. An ETag is the body's own text, so an unchanged body answers 304."""

        def __init__(self, answers):
            super().__init__("x/arbor", "t0ken")
            self.answers, self.asked = answers, []

        def fetch(self, url, etag):
            path = url.replace("https://api.github.com/repos/x/arbor", "").replace("https://api.github.com/", "")
            self.asked.append(path)
            body = self.answers[path]
            if isinstance(body, Exception):
                raise body
            tag = json.dumps(body)
            return (304, etag, None) if tag == etag else (200, tag, json.loads(tag))

    def pull(number, sha, state="open", **more):
        return {"number": number, "head": {"ref": f"fix/{number}", "sha": sha * 40}, "base": {"ref": "swarm/trunk"}, "title": f"fix: {number}", "draft": False,
                "merged_at": "2026-01-02T11:50:00Z" if state == "merged" else None, "closed_at": None if state == "open" else "2026-01-02T11:50:00Z", **more}

    def checks(**states):
        return {"check_runs": [{"name": name.replace("_", "-"), "status": value if value in ("queued", "in_progress") else "completed",
                                "conclusion": None if value in ("queued", "in_progress") else value, "started_at": "2026-01-02T11:40:00Z"} for name, value in states.items()]}

    def a_run(number, sha, path=".github/workflows/ci.yml", status="in_progress", title="x"):
        return {"id": number, "path": path, "status": status, "head_branch": "fix/1", "head_sha": sha * 40, "display_title": title, "created_at": "2026-01-02T11:30:00Z",
                "run_started_at": "2026-01-02T11:50:00Z", "updated_at": "2026-01-02T11:55:00Z", "html_url": f"https://github.com/x/arbor/actions/runs/{number}", "more": "than is kept"}

    def jobs(*given):
        return {"jobs": [{"name": name, "status": status, "conclusion": None, "labels": [label], "runner_name": "", "created_at": "2026-01-02T11:45:00Z", "started_at": "2026-01-02T11:50:00Z",
                          "completed_at": None, "steps": ["most of the answer"]} for name, status, label in given]}

    def world(remaining=4000, **more):
        return {"rate_limit": {"resources": {"core": {"limit": 5000, "remaining": remaining, "reset": int(start.timestamp()) + 1800}}},
                "/pulls?state=open&per_page=100": [pull(1, "a"), pull(2, "b")],
                "/pulls?state=closed&sort=updated&direction=desc&per_page=15": [pull(3, "c", "merged"), pull(4, "d", "closed")],
                "/actions/runs?status=queued&per_page=100": {"workflow_runs": [a_run(12, "e", ".github/workflows/mac-shell.yml", "queued", "Mac shell: night.sh at fix/8 [u]"), a_run(15, "a", status="queued"),
                                                                               a_run(13, "f", ".github/workflows/public-check.yml", "queued")]},
                "/actions/runs?status=in_progress&per_page=100": {"workflow_runs": [a_run(11, "a"), a_run(14, "e", ".github/workflows/mac-shell.yml", title="Mac shell (macos-15): day.sh at fix/9 [t]")]},
                f"/commits/{'a' * 40}/check-runs?per_page=100": checks(linux="in_progress", macos="queued", public_check="success"),
                f"/commits/{'b' * 40}/check-runs?per_page=100": checks(linux="success", macos="skipped", public_check="success"),
                "/actions/runs/11/jobs?filter=latest&per_page=100": jobs(("linux", "in_progress", "ubuntu-latest"), ("macos", "queued", "macos-26")),
                **more}

    def rounds(github, count, folder, change=None):
        times = iter(range(10 ** 6))
        clock = lambda: start.timestamp() + 150 * next(times) // 3  # the clock is read three times a round
        out = os.path.join(folder, "state.md")
        for number in range(count):
            if change and number:
                change(github.answers)
            github.asked = []
            with contextlib.redirect_stdout(io.StringIO()):
                if number == 0:
                    github.finished = {}
                now = datetime.datetime.fromtimestamp(clock(), datetime.timezone.utc)
                state = read_state(github, github.finished, now)
                save(out, written(state, {"swarm/trunk": "11111111", "main": "22222222"}, now, 150, len(github.counted)))
        with open(out, encoding="utf-8") as handle:
            return handle.read()

    with tempfile.TemporaryDirectory() as folder:
        github = Stub(world())
        text = rounds(github, 1, folder)
        rows += [
            ("a pull request whose checks are under way", [line for line in text.splitlines() if line.startswith("#1 ")],
             ["#1 fix/1 aaaaaaaa -> swarm/trunk | unfinished | linux … macos ⧖ public-check ✔ | fix: 1"]),
            ("one whose checks are all in", [line for line in text.splitlines() if line.startswith("#2 ")],
             ["#2 fix/2 bbbbbbbb -> swarm/trunk | GREEN | linux ✔ macos – public-check ✔ | fix: 2"]),
            ("what landed, and what was only closed", [line[:22] for line in text.splitlines() if line.startswith(("#3 ", "#4 "))], ["#3 landed 11:50 fix/3 ", "#4 closed 11:50 fix/4 "]),
            ("who has a Mac and who waits, Linux's jobs left out", [line for line in text.splitlines() if line.startswith(("running ", "waiting ", "## Macs"))],
             ["## Macs: 1 running, 2 waiting", "running 10 min: Mac shell (macos-15): day.sh at fix/9 [t]", "waiting 30 min: Mac shell: night.sh at fix/8 [u]", "waiting 15 min: macos of fix/1"]),
            ("only a run that is under way and can want a Mac is asked about: not the Mac shell's, not one that waits, not Linux's own",
             ([path for path in github.asked if "/jobs" in path], "## Runs of all kinds: 3 waiting, 2 running" in text), (["/actions/runs/11/jobs?filter=latest&per_page=100"], True)),
            ("where the branches stand, and what is left", ("swarm/trunk 11111111 · main 22222222" in text, "requests left this hour: 4000 of 5000, new ones at 12:30:00 UTC" in text), (True, True)),
            ("the first round counts every request but the one about the limit", len(github.counted), 7),
        ]
        rounds(github, 2, folder)
        rows += [
            ("a second round with nothing changed counts none", len(github.counted), 7),
            ("and does not ask again for checks that are all in", f"/commits/{'b' * 40}/check-runs?per_page=100" in github.asked, False),
            ("but does for those under way", f"/commits/{'a' * 40}/check-runs?per_page=100" in github.asked, True),
        ]

        def finish(answers):
            answers[f"/commits/{'a' * 40}/check-runs?per_page=100"] = checks(linux="failure", macos="cancelled", public_check="success")
            answers["/actions/runs?status=in_progress&per_page=100"] = {"workflow_runs": []}
        github = Stub(world())
        text = rounds(github, 2, folder, finish)
        rows.append(("a check fails", [line.split(" | ")[1:3] for line in text.splitlines() if line.startswith("#1 ")], [["RED", "linux ✘ macos ∅ public-check ✔"]]))

        def pushed(answers):
            answers["/pulls?state=open&per_page=100"] = [pull(1, "a"), pull(2, "9")]
            answers[f"/commits/{'9' * 40}/check-runs?per_page=100"] = {"check_runs": []}
        github = Stub(world())
        text = rounds(github, 2, folder, pushed)
        rows += [("a new push: the old commit's green does not stick", [line.split(" | ")[1] for line in text.splitlines() if line.startswith("#2 ")], ["NO CHECKS YET"]),
                 ("and what was remembered of the old commit is dropped", any("b" * 40 in url for url in github.cache), False)]

        all_in_but_more_to_come = world(**{f"/commits/{'a' * 40}/check-runs?per_page=100": checks(public_check="success")})
        github = Stub(all_in_but_more_to_come)
        rounds(github, 2, folder)
        rows.append(("every check so far is in, and a run for the commit is still going: asked again", f"/commits/{'a' * 40}/check-runs?per_page=100" in github.asked, True))

        twice = world(**{f"/commits/{'b' * 40}/check-runs?per_page=100": {"check_runs": checks(public_check="skipped")["check_runs"] + checks(public_check="success", linux="success")["check_runs"]}})
        rows.append(("two runs of one name, one of them skipped", [line.split(" | ")[1:3] for line in rounds(Stub(twice), 1, folder).splitlines() if line.startswith("#2 ")], [["GREEN", "linux ✔ public-check ✔"]]))

        github = Stub(world(remaining=LEAVE - 1))
        text = rounds(github, 1, folder)
        rows.append(("little is left: it asks for nothing more, and says so", (github.asked, "PAUSED" in text, "## Open" in text), (["rate_limit"], True, False)))

        for error in (urllib.error.HTTPError("u", 403, "rate limit", None, None), TimeoutError("slow"), http.client.RemoteDisconnected("gone")):
            github, path = Stub(world(**{"/pulls?state=open&per_page=100": error})), os.path.join(folder, "kept.md")
            save(path, "what stood here before\n")
            with contextlib.redirect_stdout(io.StringIO()) as said:
                code = poll(github, path, None, 150, True, clock=start.timestamp, heads=lambda: {})
            with open(path, encoding="utf-8") as handle:
                rows.append((f"GitHub does not answer ({type(error).__name__}): the file stays as it was, and the poller goes on", (code, handle.read(), "no round" in said.getvalue()), (0, "what stood here before\n", True)))

        github, path, cache, queue = Stub(world()), os.path.join(folder, "polled.md"), os.path.join(folder, "cache.json"), os.path.join(folder, "queue.json")
        with contextlib.redirect_stdout(io.StringIO()):
            poll(github, path, cache, 150, True, clock=start.timestamp, heads=lambda: {"main": "22222222"}, queue=queue)
        with open(queue, encoding="utf-8") as handle:
            shared = json.load(handle)
        rows += [
            ("the queue's file: whose, and of when", (shared["repo"], shared["at"]), ("x/arbor", "2026-01-02T12:00:00Z")),
            ("every run that waits or is under way, with what mac-queue.py keeps of it and no more", (sorted(one["id"] for one in shared["runs"]), {tuple(sorted(one)) for one in shared["runs"]}),
             ([11, 12, 13, 14, 15], {tuple(sorted(OF_A_RUN + ("jobs",)))})),
            ("its jobs likewise", {one["id"]: [(job["name"], job["status"], job["labels"], tuple(sorted(job)) == tuple(sorted(OF_A_JOB))) for job in one["jobs"]] for one in shared["runs"]},
             {11: [("linux", "in_progress", ["ubuntu-latest"], True), ("macos", "queued", ["macos-26"], True)], 12: [("shell", "queued", ["macos-26"], True)], 13: [],
              14: [("shell", "in_progress", ["macos-15"], True)], 15: []}),
        ]
        spec = importlib.util.spec_from_file_location("mac_queue", os.path.join(HERE, "mac-queue.py"))
        mac_queue = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mac_queue)
        asked = []
        taken = mac_queue.shared("x/arbor", start + datetime.timedelta(seconds=30), lambda: asked.append(1) or [], queue)
        rows.append(("mac-queue.py takes it for its own, and asks GitHub nothing", (asked, [one["id"] for one in taken] == [one["id"] for one in shared["runs"]]), ([], True)))
        for one in shared["runs"]:
            if one["id"] in (12, 14):
                rows.append((f"a Mac shell run stands for the same job here as there ({one['status']})", one["jobs"], [mac_queue.stands_for(one)]))
        with open(cache, encoding="utf-8") as handle:
            again = Stub(world())
            again.cache = {url: tuple(value) for url, value in json.load(handle).items()}
        with contextlib.redirect_stdout(io.StringIO()):
            poll(again, path, cache, 150, True, clock=start.timestamp, heads=lambda: {})
        rows += [("a poller that starts again with what the last one remembered counts nothing", len(again.counted), 0),
                 ("nothing is left lying beside the file", sorted(name for name in os.listdir(folder) if ".new" in name), [])]

        # Readers.
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        rows += [
            ("the lines about a pull request", [line[:3] for line in lines_about(text, "2")], ["#2 "]),
            ("with its mark", [line[:3] for line in lines_about(text, "#2")], ["#2 "]),
            ("not those of one whose number begins alike", lines_about(text.replace("#2 ", "#21 "), "2"), []),
            ("about a branch", [line[:3] for line in lines_about(text, "fix/1")], ["#1 "]),
            ("about a commit, by its full id", [line[:3] for line in lines_about(text, "b" * 40)], ["#2 "]),
        ]

        def waited(what, at=0, limit=60, text=text):
            save(path, text)
            ticks = iter(range(10 ** 6))
            with contextlib.redirect_stdout(io.StringIO()):
                return wait(path, what, limit, clock=lambda: start.timestamp() + at + 30 * next(ticks), sleep=lambda seconds: None)
        rows += [
            ("--wait: green", waited("2"), 0),
            ("--wait: landed", waited("3"), 0),
            ("--wait: closed without landing", waited("4"), 1),
            ("--wait: red", waited("1", text=text.replace("| unfinished |", "| RED |")), 1),
            ("--wait: red, but not all in: it goes on waiting, until the file is stale", waited("1", text=text.replace("| unfinished |", "| RED, unfinished |")), 3),
            ("--wait: unfinished when the time is up", waited("1", limit=5), 3),
            ("--wait: nobody is polling", waited("2", at=3600), 3),
        ]
        with contextlib.redirect_stdout(io.StringIO()):
            rows.append(("--wait: no file", wait(os.path.join(folder, "none.md"), "2", 1, clock=start.timestamp, sleep=lambda seconds: None), 3))
    failed = [f"{what}: got {got!r}, expected {wanted!r}" for what, got, wanted in rows if got != wanted]
    for line in failed:
        print("gh-state self-test:", line)
    print(f"{len(rows) - len(failed)} of {len(rows)} gh-state situations came out as expected")
    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(usage="see the top of scripts/gh-state.py", add_help=False)
    for flag in ("--out", "--cache", "--queue", "--read", "--wait"):
        parser.add_argument(flag)
    parser.add_argument("--every", type=int, default=EVERY)
    parser.add_argument("--for", dest="limit", type=float, default=60)
    for flag in ("--once", "--self-test", "--help"):
        parser.add_argument(flag, action="store_true")
    parser.add_argument("what", nargs="?")
    options = parser.parse_args()
    if options.self_test:
        return self_test()
    if options.read and options.wait:
        return wait(options.read, options.wait, options.limit)
    if options.read:
        with open(options.read, encoding="utf-8") as handle:
            text = handle.read()
        print("\n".join(text.splitlines()[2:4] + lines_about(text, options.what)) if options.what else text, end="" if not options.what else "\n")
        return 0
    if not options.out or options.help:
        print(__doc__)
        return 0 if options.help else 2
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN") or subprocess.run(["gh", "auth", "token"], capture_output=True, text=True, check=False).stdout.strip()
    origin = subprocess.run(["git", "remote", "get-url", "origin"], cwd=HERE, capture_output=True, text=True, check=False).stdout.strip()
    found = re.search(r"github\.com[:/]([\w.-]+/[\w.-]+?)(\.git)?/?$", origin)
    repository = os.environ.get("GITHUB_REPOSITORY") or (found.group(1) if found else None)
    if not token or not repository:
        print("gh-state: a token ($GH_TOKEN, $GITHUB_TOKEN or `gh auth login`) and a repository ($GITHUB_REPOSITORY or origin) are needed")
        return 2
    cache = {}
    if options.cache and os.path.exists(options.cache):
        with open(options.cache, encoding="utf-8") as handle:
            cache = {url: tuple(value) for url, value in json.load(handle).items()}
    return poll(GitHub(repository, token, cache), options.out, options.cache, max(60, options.every), options.once, queue=options.queue)


if __name__ == "__main__":
    sys.exit(main())
