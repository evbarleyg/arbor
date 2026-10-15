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

A poller somebody has to keep alive is forgotten one day. So the one that counts runs at GitHub (.github/workflows/state.yml), with
the workflow's own token, which comes under the limit of this repository's workflows and not under the one people and agents share, and
with --publish puts both files on a branch after every round. Readers say --from and that branch: a file more than a minute old is then
brought up to date by `git fetch`, which no limit counts. Two pollers that publish to one branch hand over by themselves: the one that
finds the other's commit there was the earlier one, and ends. One that cannot publish three rounds in a row ends with an error.

It hears the title and description of every open pull request each round anyway. With --watch PATTERN --then COMMAND it runs COMMAND, with the
number after it, for each that has the pattern in them. The workflow uses that for the one thing that must not wait for a runner: a platform
appends a link to the author's working session to the pull requests it creates, and scripts/public-text.py, which replaces it, is
started by an event and stands in the queue like everything else. The poller is running already.

Usage: scripts/gh-state.py --out FILE [--queue FILE] [--every SECONDS] [--cache FILE] [--once] [--for MINUTES] [--publish BRANCH] [--watch PATTERN --then COMMAND]
                                                              the poller; every 150 seconds, for ever, by default
       scripts/gh-state.py --read FILE [--from BRANCH] [WHAT]  prints the file, or the lines about WHAT (a pull request's number, a branch, a commit)
       scripts/gh-state.py --read FILE [--from BRANCH] --wait WHAT [--for MINUTES]   waits, asking nobody, until WHAT's checks have all finished; 60 by default
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
import shlex
import subprocess
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
EVERY = 150
# Below this many requests the poller leaves the rest to those who have to act; of a small limit, below a fifth.
LEAVE = 400
# What is published hangs on the commit everything here descends from, so that a clone that fetches it holds no second history.
ROOT = "51b162d5f28c02846134c1f4a113c787f5164602"
# The two files, as they are called on the branch.
STATE, QUEUE = "github-state.md", "mac-queue-cache.json"
# How the first begins: a reader puts a newer one only in the place of such a file.
HEADING = "# How things stand at GitHub"
# A reader's copy older than this is brought up to date. A fetch costs little, and scripts/mac-queue.py believes a look for 200 seconds.
LOOK_AGAIN = datetime.timedelta(seconds=60)
# So many rounds in a row that could not be published, and the poller ends with an error: a run that stays green while nobody hears of
# anything is worse than one that is red.
UNHEARD = 3
# So many rounds in a row is somebody told of one pull request. What has not helped by then will not, and every telling costs requests.
TOLD_AT_MOST = 3
# Where git is to look, as whoever called has set it. In a hook or a rebase these point at another repository. The others (how to reach
# a server, whom to ask for a password, which certificates to believe) are needed as they are.
ELSEWHERE = ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_COMMON_DIR", "GIT_PREFIX", "GIT_NAMESPACE",
             "GIT_SHALLOW_FILE", "GIT_GRAFT_FILE", "GIT_IMPLICIT_WORK_TREE")
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


def read_state(github, finished, now, watch=None):
    """Everything the file says, as a dictionary. `finished`: commit → its checks, for commits whose checks are all in; kept between rounds.
    `watch`: a pattern; which open pull requests have it in their title or description is noted."""
    limit = github.get("rate_limit", lambda body: body["resources"]["core"])
    state = {"limit": limit, "leaves": min(LEAVE, limit["limit"] // 5)}
    state["paused"] = limit["remaining"] < state["leaves"]
    if state["paused"]:
        return state
    pull = lambda item: {"number": item["number"], "branch": item["head"]["ref"], "sha": item["head"]["sha"], "base": item["base"]["ref"], "title": item["title"],
                         "draft": item["draft"], "merged": bool(item.get("merged_at")), "closed_at": item.get("closed_at"),
                         "watched": bool(watch and watch.search(f"{item['title'] or ''}\n{item.get('body') or ''}"))}
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
    lines = [HEADING + ", asked by one poller for everybody (scripts/gh-state.py)", "",
             f"read {now.strftime('%Y-%m-%d %H:%M:%S')} UTC, next in about {every} s",
             f"requests left this hour: {limit['remaining']} of {limit['limit']}, new ones at {datetime.datetime.fromtimestamp(limit['reset'], datetime.timezone.utc).strftime('%H:%M:%S')} UTC; "
             f"the poller spent {spent} in the last hour",
             f"A time more than {int(STALE.total_seconds() // 60)} minutes old means that the poller has stopped: say so, and do not start polling yourself.", "",
             " · ".join(f"{name} {sha}" for name, sha in sorted(heads.items(), reverse=True)) or "(git did not say where the branches stand)"]
    if state["paused"]:
        return "\n".join(lines + ["", f"PAUSED: fewer than {state['leaves']} requests are left, and they are for those who have to act. What stood here before is out of date."]) + "\n"
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


def git(*arguments, cwd=None, given=None, who=None):
    """git's answer."""
    environment = {key: value for key, value in os.environ.items() if key not in ELSEWHERE}
    done = subprocess.run(["git", *arguments], cwd=cwd or HERE, input=given or "", capture_output=True, text=True, errors="replace", timeout=120, check=False,
                          env={**environment, **(who or {})})
    if done.returncode:
        raise OSError(f"git {arguments[0]}: {done.stderr.strip()[:200]}")
    return done.stdout


def published_now(branch, cwd=None):
    """The commit `branch` stands at, at origin; "" if there is no such branch."""
    return git("ls-remote", "origin", f"refs/heads/{branch}", cwd=cwd).split("\t")[0]


def publish(branch, files, cwd=None, root=ROOT):
    """Puts `files` (name → path) on `branch` at origin: always one commit on top of the first, in place of the one before. The commit."""
    try:
        git("cat-file", "-e", root + "^{commit}", cwd=cwd)
    except OSError:  # a checkout with no history, as a workflow's: that one commit is all that is wanted of it
        git("fetch", "--quiet", "--no-tags", "--depth", "1", "origin", root, cwd=cwd)
    entries = "".join(f"100644 blob {git('hash-object', '-w', path, cwd=cwd).strip()}\t{name}\n" for name, path in files.items() if os.path.exists(path))
    bot = {f"GIT_{role}_{key}": value for role in ("AUTHOR", "COMMITTER")
           for key, value in (("NAME", "github-actions[bot]"), ("EMAIL", "41898282+github-actions[bot]@users.noreply.github.com"))}
    commit = git("commit-tree", git("mktree", cwd=cwd, given=entries).strip(), "-p", root, "-m", "state: how things stand at GitHub", cwd=cwd, who=bot).strip()
    git("push", "--quiet", "--force", "origin", f"{commit}:refs/heads/{branch}", cwd=cwd)
    return commit


def read_text(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return handle.read()
    except OSError:
        return ""


def refresh(path, branch, cwd=None, clock=time.time):
    """Brings `path`, and the queue's file beside it, up to date from `branch`. Never puts an older one in a newer one's place, nor anything
    in the place of a file that is something else."""
    def now():
        return datetime.datetime.fromtimestamp(clock(), datetime.timezone.utc)

    def stale(text):
        """How old, or None for a file whose time says nothing: there is none, or it lies in the future."""
        age = age_of(text, now())
        return age if age is not None and age > datetime.timedelta(minutes=-2) else None
    mine = read_text(path)
    if mine.strip() and not mine.startswith(HEADING):
        print(f"gh-state: {path} is not a file of this script's, so it is left as it is: name another", file=sys.stderr)
        return
    if stale(mine) is not None and stale(mine) < LOOK_AGAIN:
        return
    try:
        git("fetch", "--quiet", "--no-tags", "origin", f"+refs/heads/{branch}:refs/arbor/state", cwd=cwd)
        theirs = git("show", f"refs/arbor/state:{STATE}", cwd=cwd)
        if stale(theirs) is None:
            return
        beside = os.path.join(os.path.dirname(os.path.abspath(path)), QUEUE)
        try:
            queue = git("show", f"refs/arbor/state:{QUEUE}", cwd=cwd)
            # By its own time: scripts/mac-queue.py writes that file too, whenever it has had to look for itself.
            if looked_at(queue) > looked_at(read_text(beside)):
                save(beside, queue)
        except OSError:  # a round in which the poller left the rest to others writes none
            pass
        # Read again: the fetch took a while, and somebody nearer by may have written meanwhile.
        age = stale(read_text(path))
        if age is None or stale(theirs) < age:
            save(path, theirs)
    except (OSError, subprocess.TimeoutExpired) as error:  # the file's own time tells
        print(f"gh-state: {branch} could not be fetched ({error})", file=sys.stderr)


def looked_at(queue):
    """When the look at the queue in this text was taken, as text that sorts by time; "" if it says nothing."""
    try:
        at = json.loads(queue)["at"]
        return at if isinstance(at, str) else ""
    except (ValueError, KeyError, TypeError):
        return ""


def poll(github, out, cache_file, every, once, clock=time.time, sleep=time.sleep, heads=heads_by_git, queue=None, until=None, published=None, standing=None, watch=None,
         told=None):
    """`published` puts the files on the branch and says as which commit; `standing` says which commit is there now. `told` hears the number
    of each open pull request that has `watch` in its title or description."""
    finished, mine, unheard, tries = {}, None, 0, {}
    while True:
        now = datetime.datetime.fromtimestamp(clock(), datetime.timezone.utc)
        if mine and standing:
            # Two that publish to one branch need no third to tell them apart: whoever finds another's commit there was the earlier one.
            try:
                there = standing()
            except (OSError, subprocess.TimeoutExpired):
                there = ""
            if there and there != mine:
                print(f"{now.strftime('%H:%M:%S')} another poller has published since ({there[:8]}): it has taken over, and this one ends", flush=True)
                return 0
        wrote = False
        try:
            state = read_state(github, finished, now, watch)
            github.counted = [at for at in github.counted if at > clock() - 3600]
            save(out, written(state, heads(), now, every, len(github.counted)))
            if queue and not state["paused"]:
                runs = [{key: value for key, value in item.items() if key != "sha"} for item in state["active"]]
                save(queue, json.dumps({"repo": github.repository, "at": now.strftime("%Y-%m-%dT%H:%M:%SZ"), "runs": runs}))
            if cache_file:
                save(cache_file, json.dumps(github.cache))
            wrote = True
            print(f"{now.strftime('%H:%M:%S')} written; {state['limit']['remaining']} left, {len(github.counted)} spent here in the last hour", flush=True)
        except (*NO_ANSWER, KeyError, TypeError, subprocess.TimeoutExpired) as error:  # the next round may fare better; the file's time tells
            print(f"{now.strftime('%H:%M:%S')} no round: {type(error).__name__}: {error}", flush=True)
        if told and wrote:
            found = [item["number"] for item in state.get("open", []) if item.get("watched")]
            tries = {number: tries.get(number, 0) + 1 for number in found}
            for number in [number for number in found if tries[number] <= TOLD_AT_MOST]:
                try:
                    told(number)
                except (OSError, subprocess.SubprocessError) as error:
                    print(f"{now.strftime('%H:%M:%S')} #{number}: {type(error).__name__}: {error}", flush=True)
        if published and wrote:
            try:
                mine, unheard = published({STATE: out, **({QUEUE: queue} if queue else {})}), 0
            except (OSError, subprocess.TimeoutExpired) as error:
                unheard += 1
                print(f"{now.strftime('%H:%M:%S')} NOT PUBLISHED, {unheard} in a row: {error}", flush=True)
                if unheard >= UNHEARD:
                    return 1
        if once or (until is not None and clock() + every >= until):
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
    try:
        return now - datetime.datetime.strptime(found.group(1), "%Y-%m-%d %H:%M:%S").replace(tzinfo=datetime.timezone.utc) if found else None
    except ValueError:  # the 45th of the 13th
        return None


def wait(path, what, limit, clock=time.time, sleep=time.sleep, refreshed=None):
    until = clock() + limit * 60
    while True:
        if refreshed:
            refreshed()
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

        # Published by one clone, read by another, with a real git between them.
        origin, one, two = (os.path.join(folder, name) for name in ("origin.git", "one", "two"))
        somebody = {f"GIT_{role}_{key}": value for role in ("AUTHOR", "COMMITTER") for key, value in (("NAME", "x"), ("EMAIL", "x@example.com"))}
        git("init", "--quiet", "--bare", origin, cwd=folder)
        git("init", "--quiet", one, cwd=folder)
        git("remote", "add", "origin", origin, cwd=one)
        first = git("commit-tree", git("mktree", cwd=one).strip(), "-m", "the first commit", cwd=one, who=somebody).strip()
        git("push", "--quiet", "origin", f"{first}:refs/heads/main", cwd=one)
        git("clone", "--quiet", "--branch", "main", origin, two, cwd=folder)
        theirs, mine = os.path.join(folder, "theirs"), os.path.join(folder, "mine")
        os.mkdir(theirs), os.mkdir(mine)

        def at(minute, second=0):
            return text.replace("read 2026-01-02 12:00:00 UTC", f"read 2026-01-02 12:{minute:02}:{second:02} UTC")

        def look(minute, second=0):
            return json.dumps({"repo": "x/arbor", "at": f"2026-01-02T12:{minute:02}:{second:02}Z", "runs": []})

        def put(minute, queue=None, state=None):
            save(os.path.join(theirs, "s.md"), state or at(minute))
            save(os.path.join(theirs, "q.json"), queue or look(minute))
            return publish("state/github", {STATE: os.path.join(theirs, "s.md"), QUEUE: os.path.join(theirs, "q.json")}, cwd=one, root=first)

        def got(minute, name="state.md", second=0, clock=None):
            with contextlib.redirect_stderr(io.StringIO()) as said:
                refresh(os.path.join(mine, "state.md"), "state/github", cwd=two, clock=clock or (lambda: start.timestamp() + 60 * minute + second))
            got.said = said.getvalue()
            return read_text(os.path.join(mine, name))

        def have(state=None, queue=None):
            for name, content in (("state.md", state), (QUEUE, queue)):
                if content is not None:
                    save(os.path.join(mine, name), content)
        commit = put(0)
        rows += [
            ("--from: where there is no file yet, both are brought", (got(1) == at(0), got(1, QUEUE) == look(0)), (True, True)),
            ("what is published is one commit on top of the first, so no clone gets a second history",
             (git("rev-list", "refs/arbor/state", cwd=two).split(), git("rev-list", "--max-parents=0", "refs/arbor/state", cwd=two).split()), ([commit, first], [first])),
            ("under the name of GitHub's own hand, and an address that leads to nobody",
             git("log", "-1", "--format=%an <%ae> %cn <%ce>", "refs/arbor/state", cwd=two).strip(),
             "github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com> github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>"),
            ("where the branch stands can be asked", published_now("state/github", cwd=one), commit),
            ("a branch that is not there", published_now("state/none", cwd=one), ""),
        ]
        put(3)
        have(at(3, 30))
        rows.append(("--from: a file less than a minute old is left alone, and nothing is fetched", (got(4, second=29) == at(3, 30), git("rev-parse", "refs/arbor/state", cwd=two).strip()), (True, commit)))
        have(at(0))
        rows += [
            ("--from: an older one is brought up to date", got(4) == at(3), True),
            ("and the branch is still two commits long", len(git("rev-list", "refs/arbor/state", cwd=two).split()), 2),
        ]
        have(at(10))
        rows.append(("--from: what somebody nearer by wrote later is not replaced by what the branch has", got(20) == at(10), True))
        have(at(3))
        os.utime(os.path.join(mine, "state.md"), (1, 1))
        rows.append(("--from: one that is just as old is not written again", (got(20) == at(3), os.path.getmtime(os.path.join(mine, "state.md"))), (True, 1.0)))
        have(at(0), look(4, 50))
        rows.append(("--from: a look at the queue that scripts/mac-queue.py took later stays, though the other file is brought up to date", (got(5) == at(3), got(5, QUEUE) == look(4, 50)), (True, True)))
        have(at(0), "half a fi")
        rows.append(("--from: half a file in the queue's place is replaced", got(5, QUEUE) == look(3), True))
        have(at(50))
        rows.append(("--from: a file from the future says nothing, and is replaced", got(5) == at(3), True))
        for what, content in (("a day that does not exist", text.replace("read 2026-01-02 12:00:00 UTC", "read 2026-13-45 99:99:99 UTC")), ("no time at all", HEADING + "\n")):
            have(content)
            rows.append((f"--from: a file with {what}: likewise", got(5) == at(3), True))
        with open(os.path.join(mine, "state.md"), "wb") as handle:
            handle.write(HEADING.encode() + b"\n\xff\xfe\n")
        rows.append(("--from: or with a byte that is no text", got(5) == at(3), True))
        have("# My notes\nnot to be lost\n", look(1))
        rows.append(("--from: a file that is something else is left as it is, with a word, and so is what lies beside it",
                     (got(5), got(5, QUEUE) == look(1), "is not a file of this script's" in got.said), ("# My notes\nnot to be lost\n", True, True)))
        have(at(0))
        put(6, state=text.replace("read 2026-01-02 12:00:00 UTC", "read 2026-13-45 99:99:99 UTC"))
        rows.append(("--from: the branch's own file has a time nobody can read: nothing is taken from it", got(7) == at(0), True))
        put(6)

        def meanwhile():
            """The clock of a reader beside whom somebody writes while it fetches: its third look at it is the first after the fetch."""
            meanwhile.looks += 1
            if meanwhile.looks == 3:
                have(at(6, 30))
            return start.timestamp() + 60 * 7
        meanwhile.looks = 0
        have(at(0))
        rows.append(("--from: somebody nearer by writes a newer one while the fetch is under way: theirs stays", got(7, clock=meanwhile) == at(6, 30), True))
        os.environ["GIT_DIR"], kept = os.path.join(folder, "nowhere"), os.environ.get("GIT_DIR")
        have(at(0))
        rows.append(("--from: called from a hook, whose GIT_DIR points elsewhere", got(7) == at(6), True))
        os.environ.pop("GIT_DIR") if kept is None else os.environ.update(GIT_DIR=kept)
        os.environ["GIT_CONFIG_COUNT"], os.environ["GIT_CONFIG_KEY_0"], os.environ["GIT_CONFIG_VALUE_0"] = "1", f"url.{origin}.insteadOf", "https://nowhere.invalid/x.git"
        git("remote", "set-url", "origin", "https://nowhere.invalid/x.git", cwd=two)
        have(at(0))
        rows.append(("--from: how to reach the server, as whoever called has set it, is kept", got(7) == at(6), True))
        for key in ("GIT_CONFIG_COUNT", "GIT_CONFIG_KEY_0", "GIT_CONFIG_VALUE_0"):
            del os.environ[key]
        git("remote", "set-url", "origin", origin, cwd=two)

        bare = os.path.join(folder, "shallow")
        git("clone", "--quiet", "--depth", "1", "--branch", "later", "file://" + (lambda: (git("push", "--quiet", "origin", git("commit-tree", git("mktree", cwd=one).strip(), "-p", first, "-m", "later", cwd=one, who=somebody).strip() + ":refs/heads/later", cwd=one), origin)[1])(), bare, cwd=folder)
        rows.append(("a checkout with no history, as a workflow's, fetches the one commit it needs",
                     (git("rev-list", "--count", "HEAD", cwd=bare).strip(), git("rev-list", publish("state/github", {STATE: os.path.join(theirs, "s.md"), "none": os.path.join(theirs, "none")}, cwd=bare, root=first), cwd=bare).split()[1:],
                      git("ls-tree", "--name-only", published_now("state/github", cwd=one), cwd=bare).split()), ("1", [first], [STATE])))
        # The command line, with the clones above and a stand-in for GitHub.
        def called(*arguments, **more):
            with contextlib.redirect_stdout(io.StringIO()) as said, contextlib.redirect_stderr(io.StringIO()):
                code = main(list(arguments), root=first, sleep=lambda seconds: None, **more)
            return code, said.getvalue()
        wired = os.path.join(folder, "wired")
        os.mkdir(wired)
        code, _ = called("--out", os.path.join(wired, "o.md"), "--queue", os.path.join(wired, "o.json"), "--once", "--publish", "state/wired", clone=one, github=Stub(world()))
        rows.append(("--out --queue --once --publish: one round, and both files are on that branch", (code, git("ls-tree", "--name-only", published_now("state/wired", cwd=one), cwd=one).split()), (0, [STATE, QUEUE])))
        code, said = called("--read", os.path.join(wired, "r.md"), "--from", "state/wired", "2", clone=two)
        rows.append(("--read --from: fetched from that branch, and the line is printed", (code, [line[:9] for line in said.splitlines() if line.startswith("#")], os.path.exists(os.path.join(wired, QUEUE))), (0, ["#2 fix/2 "], True)))
        os.remove(os.path.join(wired, "r.md"))
        rows.append(("--read without --from fetches nothing, and says so", (called("--read", os.path.join(wired, "r.md"), "2", clone=two)[0], os.path.exists(os.path.join(wired, "r.md"))), (3, False)))
        rows.append(("--read --from --wait: likewise fetched", (called("--read", os.path.join(wired, "r.md"), "--from", "state/wired", "--wait", "2", clone=two)[0], os.path.exists(os.path.join(wired, "r.md"))), (0, True)))
        noted = os.path.join(wired, "noted")
        watched = Stub(world(**{"/pulls?state=open&per_page=100": [pull(7, "a", body="https://example.com/watched-1")]}))
        called("--out", os.path.join(wired, "o.md"), "--once", "--watch", r"example\.com/watched-", "--then", f"{shlex.quote(sys.executable)} -c 'import sys; open(sys.argv[1], \"w\").write(sys.argv[2])' {shlex.quote(noted)}",
               clone=one, github=watched)
        rows.append(("--watch --then: the command is run with the number after it", read_text(noted), "7"))
        code, _ = called("--out", os.path.join(wired, "o.md"), "--every", "60", "--for", "0.5", "--publish", "state/wired", clone=one, github=Stub(world()))
        rows.append(("--for: half a minute is no time for a second round", code, 0))

        os.rename(origin, origin + ".gone")
        have(at(0))
        rows.append(("--from: GitHub cannot be reached: the file stays, with a word, and its own time tells", (got(30) == at(0), "could not be fetched" in got.said), (True, True)))
        os.rename(origin + ".gone", origin)

        calls = []
        with contextlib.redirect_stdout(io.StringIO()):
            waited_for = wait(path, "1", 2, clock=lambda: start.timestamp() + 30 * len(calls), sleep=lambda seconds: None, refreshed=lambda: calls.append(1))
        rows.append(("--wait --from: it looks before every reading", (waited_for, len(calls) > 3), (3, True)))

        def small(remaining):
            return {"rate_limit": {"resources": {"core": {"limit": 1000, "remaining": remaining, "reset": int(start.timestamp()) + 1800}}}}
        rows += [
            ("a workflow's own limit is a thousand: with 250 left it goes on", read_state(Stub(world(**small(250))), {}, start)["paused"], False),
            ("below a fifth it leaves the rest to the other workflows", read_state(Stub(world(**small(199))), {}, start)["paused"], True),
        ]
        ticks, sent = [], []
        with contextlib.redirect_stdout(io.StringIO()):
            poll(Stub(world()), os.path.join(folder, "p.md"), None, 150, False, clock=lambda: start.timestamp() + 150 * len(ticks), sleep=ticks.append,
                 heads=lambda: {}, queue=os.path.join(folder, "p.json"), until=start.timestamp() + 600, published=sent.append)
        rows.append(("--for: the poller ends by itself before the time is up, and has published every round",
                     (len(ticks), [sorted(files) for files in sent]), (3, [[STATE, QUEUE]] * 4)))

        def looped(published, standing, rounds=9, github=None):
            ticks = []
            with contextlib.redirect_stdout(io.StringIO()) as said:
                code = poll(github or Stub(world()), os.path.join(folder, "p.md"), None, 150, False, clock=lambda: start.timestamp() + 150 * len(ticks), sleep=ticks.append,
                            heads=lambda: {}, until=start.timestamp() + 150 * rounds, published=published, standing=standing)
            return code, len(ticks), said.getvalue()

        def refused(files):
            raise OSError("git push: refused")
        there = iter(["a1", "a1", "b1"])
        code, slept, said = looped(lambda files: "a1", lambda: next(there))
        rows.append(("another poller has published: this one, the earlier, ends, without an error and without publishing over it", (code, slept, "has taken over" in said), (0, 3, True)))
        rows.append(("nobody else publishes: it goes on to its end", looped(lambda files: "a1", lambda: "a1")[:2], (0, 8)))
        rows.append(("the branch is gone, or cannot be asked after: that is nobody's taking over", (looped(lambda files: "a1", lambda: "")[:2], looped(lambda files: "a1", refused and (lambda: refused(None)))[:2]), ((0, 8), (0, 8))))
        code, slept, said = looped(refused, lambda: "a1")
        rows.append(("three rounds in a row that nobody hears of: it ends with an error, and has said so each time", (code, slept, said.count("NOT PUBLISHED")), (1, 2, 3)))
        turns = iter([True, True, False, True, True, False, True, True, False])

        def now_and_then(files):
            if next(turns):
                raise OSError("git push: refused")
            return "a1"
        rows.append(("two in a row, now and then: it goes on", looped(now_and_then, lambda: "a1")[:2], (0, 8)))
        sent = []
        looped(sent.append, lambda: "a1", rounds=3, github=Stub({"rate_limit": TimeoutError("slow")}))
        rows.append(("a round that was not written is not published", sent, []))
        link = re.compile(r"https://example\.com/watched-")

        def with_bodies(**bodies):
            return world(**{"/pulls?state=open&per_page=100": [pull(1, "a", body=bodies.get("one")), pull(2, "b", body=bodies.get("two"), **({"title": bodies["title"]} if "title" in bodies else {}))]})

        def heard(github, rounds=5, change=None, told=None):
            numbers, ticks = [], []

            def sleep(seconds):
                ticks.append(seconds)
                if change:
                    change(len(ticks), github.answers)
            with contextlib.redirect_stdout(io.StringIO()):
                code = poll(github, os.path.join(folder, "p.md"), None, 150, False, clock=lambda: start.timestamp() + 150 * len(ticks), sleep=sleep, heads=lambda: {},
                            until=start.timestamp() + 150 * rounds, watch=link, told=told or numbers.append)
            return code, numbers
        rows += [
            ("--watch: nothing of the kind in any description, one of which is none at all: nobody is told", heard(Stub(with_bodies(one="fine", two=None))), (0, [])),
            ("--watch: it stands in one, and stays: told three rounds in a row, and no more", heard(Stub(with_bodies(one="x\nhttps://example.com/watched-1\n"))), (0, [1, 1, 1])),
            ("--watch: in a title", heard(Stub(with_bodies(title="see https://example.com/watched-1")), rounds=1), (0, [2])),
            ("--watch: gone after the first telling: told once", heard(Stub(with_bodies(one="https://example.com/watched-1")), change=lambda tick, answers: answers.update(with_bodies(one="mended"))), (0, [1])),
            ("--watch: gone, and there again later: the count begins anew",
             heard(Stub(with_bodies(one="https://example.com/watched-1")), rounds=9,
                   change=lambda tick, answers: answers.update(with_bodies(one="mended" if tick == 4 else "https://example.com/watched-1"))), (0, [1, 1, 1, 1, 1, 1])),
        ]

        rows.append(("--watch: rounds in which GitHub does not answer tell nobody of what an earlier one heard",
                     heard(Stub(with_bodies(one="https://example.com/watched-1")), change=lambda tick, answers: answers.update(rate_limit=TimeoutError("slow"))), (0, [1])))

        def falls_over(number):
            raise subprocess.TimeoutExpired("x", 300)
        rows.append(("--watch: the command takes for ever, or is not there: the poller goes on", heard(Stub(with_bodies(one="https://example.com/watched-1")), told=falls_over)[0], 0))
        rows.append(("what is left to others is said as it is", ("fewer than 200 requests" in written(read_state(Stub(world(**small(199))), {}, start), {}, start, 150, 0),
                                                                 "fewer than 400 requests" in written(read_state(Stub(world(remaining=399)), {}, start), {}, start, 150, 0)), (True, True)))
    failed = [f"{what}: got {got!r}, expected {wanted!r}" for what, got, wanted in rows if got != wanted]
    for line in failed:
        print("gh-state self-test:", line)
    print(f"{len(rows) - len(failed)} of {len(rows)} gh-state situations came out as expected")
    return 1 if failed else 0


def main(arguments=None, clone=None, root=ROOT, github=None, sleep=time.sleep):
    """All but the first are for the self-test: a clone, a first commit and a GitHub of its own."""
    parser = argparse.ArgumentParser(usage="see the top of scripts/gh-state.py", add_help=False)
    for flag in ("--out", "--cache", "--queue", "--read", "--wait", "--publish", "--watch", "--then"):
        parser.add_argument(flag)
    parser.add_argument("--from", dest="branch")
    parser.add_argument("--every", type=int, default=EVERY)
    parser.add_argument("--for", dest="limit", type=float)
    for flag in ("--once", "--self-test", "--help"):
        parser.add_argument(flag, action="store_true")
    parser.add_argument("what", nargs="?")
    options = parser.parse_args(arguments)
    if options.self_test:
        return self_test()
    refreshed = (lambda: refresh(options.read, options.branch, cwd=clone)) if options.read and options.branch else None
    if options.read and options.wait:
        return wait(options.read, options.wait, options.limit or 60, sleep=sleep, refreshed=refreshed)
    if options.read:
        if refreshed:
            refreshed()
        text = read_text(options.read)
        if not text:
            print(f"gh-state: there is no {options.read}, or nothing in it" + ("" if options.branch else "; --from BRANCH fetches one"))
            return 3
        print("\n".join(text.splitlines()[2:4] + lines_about(text, options.what)) if options.what else text, end="" if not options.what else "\n")
        return 0
    if not options.out or options.help:
        print(__doc__)
        return 0 if options.help else 2
    try:
        token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN") or subprocess.run(["gh", "auth", "token"], capture_output=True, text=True, check=False).stdout.strip()
    except OSError:  # there is no gh here
        token = ""
    origin = subprocess.run(["git", "remote", "get-url", "origin"], cwd=HERE, capture_output=True, text=True, check=False).stdout.strip()
    found = re.search(r"github\.com[:/]([\w.-]+/[\w.-]+?)(\.git)?/?$", origin)
    repository = os.environ.get("GITHUB_REPOSITORY") or (found.group(1) if found else None)
    if not github and (not token or not repository):
        print("gh-state: a token ($GH_TOKEN, $GITHUB_TOKEN or `gh auth login`) and a repository ($GITHUB_REPOSITORY or origin) are needed")
        return 2
    cache = {}
    if options.cache and os.path.exists(options.cache):
        with open(options.cache, encoding="utf-8") as handle:
            cache = {url: tuple(value) for url, value in json.load(handle).items()}
    return poll(github or GitHub(repository, token, cache), options.out, options.cache, max(60, options.every), options.once, sleep=sleep, queue=options.queue,
                until=time.time() + options.limit * 60 if options.limit else None,
                published=(lambda files: publish(options.publish, files, cwd=clone, root=root)) if options.publish else None,
                standing=(lambda: published_now(options.publish, cwd=clone)) if options.publish else None,
                watch=re.compile(options.watch) if options.watch and options.then else None,
                told=(lambda number: subprocess.run([*shlex.split(options.then), str(number)], timeout=300, check=False)) if options.watch and options.then else None)


if __name__ == "__main__":
    sys.exit(main())
