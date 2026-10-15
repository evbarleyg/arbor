#!/usr/bin/env python3
"""Makes way for a move from the trunk to main, and gives the way back afterwards.

A move waits for its own checks, and GitHub knows no priorities: whatever was started before stands in front of it, and whatever is
pushed meanwhile stands beside it. Whoever lands used to clear the line by hand: ask for all runs, cancel them one by one, remember which
Mac shell runs to start again, and write "please push nothing" where few would read it. Three times in one night. This does it.

Usage: scripts/make-way.py --for BRANCH --until "main is COMMIT" [--why TEXT] [--dry-run]
           1. holds everybody's pushes (hold.txt beside the file of private words: docs/PUBLIC.md; the hold ends by itself);
           2. cancels every run that waits or is under way, except those about BRANCH, the small ones that read for private things, a
              release, and Mac shell runs that have begun;
           3. writes down each run it has cancelled, beside the hold, as it goes.
           --until also takes a time that has not come yet, 2026-01-02T12:30Z.
       scripts/make-way.py --back [--dry-run]
           starts again, oldest first, what nobody's push would: the cancelled Mac shell runs, runs that a schedule or a hand had
           started, and main's own. Not one whose owner has started it again meanwhile. Then it takes the hold away.
       scripts/make-way.py --self-test

A Mac shell run is about the branch its title names ("… at BRANCH [tag]"): all of them are started from the trunk.

A request for each hundred runs of each kind of "not finished", and one for each run cancelled or started. When GitHub says that the hour's
requests are used up, it stops asking. Needs a token that may write actions in $GH_TOKEN or $GITHUB_TOKEN, or `gh` logged in; the
repository is $GITHUB_REPOSITORY or the one `origin` points to. Exits with 0, with 1 if something could not be done (what, and how things
stand now, is printed), with 2 if it was called wrongly.
"""

import argparse
import datetime
import http.client
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
# These take seconds on Linux and are what reads a push or a post for private things; and nobody cancels a release in passing.
LEFT_ALONE = re.compile(r"/(public-[a-z-]+|state|release)\.yml$")
MAC_SHELL = re.compile(r"/mac-shell\.yml$")
# As .github/workflows/mac-shell.yml writes its run-name.
TITLE = re.compile(r" at (?P<branch>\S+)(?: \(no pre-flight: .*\))? \[(?P<tag>[^\]]*)\]$")
# Every word GitHub has for "not finished".
UNFINISHED = ("queued", "in_progress", "waiting", "requested", "pending")
# What a request can end in, besides an answer.
NO_ANSWER = (OSError, http.client.HTTPException, ValueError, KeyError, TypeError)


class GitHub:
    def __init__(self, repository, token):
        self.repository, self.token = repository, token

    def ask(self, method, path):
        """The answer's body, or None where there is none. Apart, so that the self-test can stand in for it."""
        request = urllib.request.Request(f"https://api.github.com/repos/{self.repository}{path}", method=method, data=b"" if method == "POST" else None, headers={
            "Authorization": f"Bearer {self.token}", "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"})
        with urllib.request.urlopen(request, timeout=30) as answer:
            body = answer.read()
        return json.loads(body) if body.strip() else None


def unfinished(github):
    """Every run that is not finished, oldest first, each once."""
    runs = {}
    for status in UNFINISHED:
        for page in range(1, 11):  # GitHub lists the newest first, and those in front of a move are the oldest
            listed = github.ask("GET", f"/actions/runs?status={status}&per_page=100&page={page}")["workflow_runs"]
            for run in listed:
                path, title = run["path"].split("@")[0], run.get("display_title") or ""
                named = TITLE.search(title) if MAC_SHELL.search(path) else None
                runs[run["id"]] = {"id": run["id"], "path": path, "branch": named.group("branch") if named else run.get("head_branch") or "(no branch)",
                                   "tag": named.group("tag") if named else None, "title": title, "status": run["status"], "event": run.get("event") or "",
                                   "created_at": run["created_at"]}
            if len(listed) < 100:
                break
    return sorted(runs.values(), key=lambda run: (run["created_at"], run["id"]))


def in_the_way(runs, branch):
    """All but those about the branch, the ones left alone, and a Mac shell run that is under way: it has its Mac, and gives it back soonest by finishing."""
    return [run for run in runs if run["branch"] != branch and not LEFT_ALONE.search(run["path"]) and not (MAC_SHELL.search(run["path"]) and run["status"] == "in_progress")]


def nobody_pushes(run):
    """Whether only starting it again brings this run back."""
    return bool(MAC_SHELL.search(run["path"])) or run.get("event") in ("schedule", "workflow_dispatch") or (run.get("event") == "push" and run["branch"] == "main")


def each(github, runs, verb, word, dry, done=lambda run: None):
    """Asks GitHub to `verb` each run, and calls `done` after each that it did. Those it did not."""
    refused = []
    for place, run in enumerate(runs):
        line = f"{run['path'].rsplit('/', 1)[-1]} {run['branch']}: {run['title'][:90]}"
        if dry:
            print(f"would be {word}: {line}")
            continue
        try:
            github.ask("POST", f"/actions/runs/{run['id']}/{verb}")
        except NO_ANSWER as error:  # finished meanwhile, as a rule
            refused.append(run)
            print(f"NOT {word} ({getattr(error, 'code', None) or type(error).__name__}): {line}")
            if getattr(error, "code", None) in (401, 403, 429):  # not this run's fault, and the next would fare no better
                refused += runs[place + 1:]
                print(f"GitHub refuses: {len(runs) - place - 1} more were not asked for")
                break
            continue
        print(f"{word}: {line}")
        done(run)
    return refused


def save(path, text):
    beside = f"{path}.{os.getpid()}.new"
    with open(beside, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(beside, path)


def recorded(path):
    """What is written down. A record nobody can read is set aside, with a word: it must not stand in the way of the hold's end."""
    try:
        with open(path, encoding="utf-8") as handle:
            runs = json.load(handle)
        if not isinstance(runs, list) or not all(isinstance(run, dict) and {"id", "path", "branch", "title"} <= set(run) for run in runs):
            raise ValueError("not a list of runs")
        return runs
    except FileNotFoundError:
        return []
    except (OSError, ValueError) as error:
        os.replace(path, path + ".unreadable")
        print(f"what was written down cannot be read ({error}); it is now {os.path.basename(path)}.unreadable")
        return []


def make_way(github, folder, branch, until, why, dry=False):
    hold, record = os.path.join(folder, "hold.txt"), os.path.join(folder, "made-way.json")
    # First, so that nothing new comes while the line is being cleared.
    if dry:
        print(f"would hold pushes until {until}")
    else:
        save(hold, f"until {until}\n{why}\n")
        print(f"pushes are held until {until}")
    try:
        runs = unfinished(github)
    except NO_ANSWER as error:
        print(f"GitHub does not say what is running ({getattr(error, 'code', None) or type(error).__name__}: {error}). NOTHING WAS CANCELLED"
              + ("." if dry else "; the hold stands. Try again, or take it away: scripts/make-way.py --back"))
        return 1
    if not any(run["branch"] == branch for run in runs):
        print(f"note: no run that waits or is under way is about {branch}. Is that its name?")
    # On top of what an earlier call wrote down, and after every single one: whatever ends this early must not forget a Mac shell run.
    written = [] if dry else recorded(record)

    def note(run):
        if run["id"] not in {one["id"] for one in written}:
            written.append(run)
            save(record, json.dumps(written, indent=1))
    standing = in_the_way(runs, branch)
    refused = each(github, standing, "cancel", "cancelled", dry, note)
    if not dry:
        print(f"{len(standing) - len(refused)} cancelled; `scripts/make-way.py --back` starts again what no push would")
    return 1 if refused else 0


def give_back(github, folder, dry=False):
    hold, record = os.path.join(folder, "hold.txt"), os.path.join(folder, "made-way.json")
    runs = recorded(record)
    again = [run for run in runs if nobody_pushes(run)]
    code = 0
    if again:
        # A run started again takes the place of one with the same tag: not of the one its owner has started meanwhile.
        try:
            theirs = {run["tag"] for run in unfinished(github) if run["tag"]}
        except NO_ANSWER as error:
            print(f"GitHub does not say what is running ({getattr(error, 'code', None) or type(error).__name__}): nothing was started again, and it stays written down")
            theirs, again, code = set(), [], 1
        for run in [run for run in again if run.get("tag") in theirs]:
            print(f"started again by its owner meanwhile: {run['title'][:90]}")
        again = [run for run in again if run.get("tag") not in theirs]
    refused = each(github, again, "rerun", "started again", dry) if not code else [run for run in runs if nobody_pushes(run)]
    others = sorted({run["branch"] for run in runs if not nobody_pushes(run)})
    if others:
        print(f"not started again, a push or a rebase does that: the checks of {', '.join(others)}")
    if not dry:
        # What was refused stays written down, for another try. The hold goes in any case: that is what everybody waits for.
        if refused:
            save(record, json.dumps(refused, indent=1))
        elif os.path.exists(record):
            os.remove(record)
        if os.path.exists(hold):
            os.remove(hold)
        print("pushes are no longer held")
    return 1 if refused or code else 0


def until_what(text, now=None):
    """`text` if the hook will understand it and it is not over already; else None."""
    if re.fullmatch(r"main is [0-9a-f]{7,40}", text or ""):
        return text
    try:
        time = datetime.datetime.strptime(text or "", "%Y-%m-%dT%H:%MZ").replace(tzinfo=datetime.timezone.utc)
    except ValueError:
        return None
    return text if time > (now or datetime.datetime.now(datetime.timezone.utc)) else None


# MARK: --self-test

def self_test():
    import contextlib
    import io
    import tempfile
    rows = []

    class Stub(GitHub):
        def __init__(self, runs, refuses=None, hold=None, deaf=None):
            super().__init__("x/arbor", "t0ken")
            self.runs, self.refuses, self.asked, self.hold, self.held, self.deaf = runs, refuses or {}, [], hold, [], deaf

        def ask(self, method, path):
            self.asked.append(f"{method} {path}")
            self.held.append(bool(self.hold) and os.path.exists(self.hold))
            if method == "GET":
                if self.deaf:
                    raise self.deaf
                status, page = re.search(r"status=(\w+)", path).group(1), int(re.search(r"&page=(\d+)", path).group(1))
                newest_first = sorted((run for run in self.runs if run["status"] == status), key=lambda run: run["created_at"], reverse=True)
                return {"workflow_runs": newest_first[100 * (page - 1):100 * page]}
            error = self.refuses.get(int(path.split("/")[3]))
            if error:
                raise error
            return None

    def gone(code=409):
        return urllib.error.HTTPError("u", code, "Cannot cancel a workflow run that is completed", None, None)

    def run(number, workflow, branch, status="queued", title=None, event="pull_request"):
        return {"id": number, "path": f".github/workflows/{workflow}.yml", "head_branch": branch, "display_title": title or f"title {number}", "status": status,
                "event": event, "created_at": f"2026-01-02T{11 - number // 60:02}:{59 - number % 60:02}:00Z", "more": "than is kept"}

    def shell(number, about, status="queued", tag=None, more=""):
        """As scripts/mac-shell/run.sh starts them: from the trunk, whatever branch they are about."""
        return run(number, "mac-shell", "swarm/trunk", status, f"Mac shell: scripts/mac-shell/a.sh at {about}{more} [{tag or f't{number}'}]", "workflow_dispatch")

    def world():
        return [run(1, "ci", "fix/1"), run(2, "ci", "train/2", "in_progress"), shell(3, "fix/3"), run(4, "public-check", "fix/1"), shell(5, "fix/5", "in_progress"),
                run(6, "state", "main", "in_progress", event="schedule"), run(7, "release", "main", "waiting", event="push"), shell(8, "train/2", more=" (no pre-flight: in a hurry)"),
                dict(run(9, "public-text", "main"), path=".github/workflows/public-text.yml@main"), dict(run(10, "ci", "main", "pending", event="schedule"), path=".github/workflows/ci.yml@main"),
                dict(run(11, "ci", None, "requested"), display_title=None)]

    def posts(github):
        return [line.split("/actions/runs/")[1] for line in github.asked if line.startswith("POST")]

    def quietly(function, *arguments, **more):
        with contextlib.redirect_stdout(io.StringIO()) as said:
            return function(*arguments, **more), said.getvalue()

    def read(folder, name):
        try:
            with open(os.path.join(folder, name), encoding="utf-8") as handle:
                return handle.read()
        except OSError:
            return None

    def ids(folder):
        return [item["id"] for item in json.loads(read(folder, "made-way.json") or "[]")]

    with tempfile.TemporaryDirectory() as folder:
        github = Stub(world(), hold=os.path.join(folder, "hold.txt"))
        (code, said) = quietly(make_way, github, folder, "train/2", "main is 0123456", "A train is open.")
        rows += [
            ("all that waits or runs is cancelled, oldest first, but: what is about the train, Mac shell run or not; what reads for private things; a release; a Mac shell run that has its Mac",
             (code, posts(github)), (0, ["11/cancel", "10/cancel", "3/cancel", "1/cancel"])),
            ("the hold is written as the hook reads it", read(folder, "hold.txt"), "until main is 0123456\nA train is open.\n"),
            ("and before anything is asked of GitHub, so that nothing new comes meanwhile", all(github.held), True),
            ("what was cancelled is written down", ids(folder), [11, 10, 3, 1]),
            ("every word GitHub has for unfinished is asked after", sorted(re.search(r"status=(\w+)", line).group(1) for line in github.asked if line.startswith("GET")),
             ["in_progress", "pending", "queued", "requested", "waiting"]),
            ("the train's runs were seen, so nothing is said about its name", "Is that its name?" in said, False),
        ]
        github = Stub([shell(12, "fix/9"), shell(3, "fix/3"), run(2, "ci", "train/2", "in_progress")])
        quietly(make_way, github, folder, "train/2", "main is 0123456", "Again.")
        rows.append(("clearing the line a second time keeps what the first wrote down, each run once", ids(folder), [11, 10, 3, 1, 12]))
        github = Stub([shell(90, "fix/9", tag="t12")])
        (code, said) = quietly(give_back, github, folder)
        rows += [
            ("--back: what no push would start is started again, in the order it was written down: Mac shell runs and the nightly; not one whose owner has started it again",
             (code, posts(github)), (0, ["10/rerun", "3/rerun"])),
            ("whose checks were not started again is said, also where GitHub names no branch", "the checks of (no branch), fix/1" in said, True),
            ("the hold and the record are gone", (read(folder, "hold.txt"), read(folder, "made-way.json")), (None, None)),
        ]
        github = Stub([])
        (code, _) = quietly(give_back, github, folder)
        rows.append(("--back with nothing to give back asks GitHub nothing", (code, github.asked), (0, [])))

    with tempfile.TemporaryDirectory() as folder:
        github = Stub(world(), refuses={10: gone()})
        (code, said) = quietly(make_way, github, folder, "train/2", "2026-01-02T12:30Z", "x")
        rows.append(("a run that finished meanwhile cannot be cancelled: said, the rest is done, and it is not written down", (code, "NOT cancelled (409)" in said, ids(folder)), (1, True, [11, 3, 1])))
        github = Stub([], refuses={3: gone(500)})
        (code, _) = quietly(give_back, github, folder)
        rows.append(("--back: what could not be started stays written down for another try; the hold goes all the same", (code, ids(folder), read(folder, "hold.txt")), (1, [3], None)))

    with tempfile.TemporaryDirectory() as folder:
        quietly(make_way, Stub([run(1, "ci", "main", event="push"), run(2, "ci", "fix/2", event="push"), run(3, "ci", "train/2")]), folder, "train/2", "main is 0123456", "x")
        github = Stub([])
        quietly(give_back, github, folder)
        rows.append(("the checks of the last move to main are started again too: nobody pushes there but a move", (posts(github)), ["1/rerun"]))

    for what, error in (("half an answer", http.client.IncompleteRead(b"")), ("no JSON", json.JSONDecodeError("x", "", 0)), ("no connection", urllib.error.URLError("down"))):
        with tempfile.TemporaryDirectory() as folder:
            (code, _) = quietly(make_way, Stub(world(), refuses={3: error}), folder, "train/2", "main is 0123456", "x")
            rows.append((f"{what} at the third of four: the others are cancelled and written down", (code, ids(folder)), (1, [11, 10, 1])))

    class Interrupted(BaseException):
        pass
    with tempfile.TemporaryDirectory() as folder:
        with contextlib.suppress(Interrupted):
            quietly(make_way, Stub(world(), refuses={3: Interrupted()}), folder, "train/2", "main is 0123456", "x")
        rows.append(("ended by a hand at the third: the two before it are written down already", ids(folder), [11, 10]))

    with tempfile.TemporaryDirectory() as folder:
        github = Stub(world(), refuses={10: gone(403)})
        (code, said) = quietly(make_way, github, folder, "train/2", "main is 0123456", "x")
        rows.append(("the hour's requests are used up: it stops asking, and says how many it left", (code, posts(github), "2 more were not asked for" in said), (1, ["11/cancel", "10/cancel"], True)))

    with tempfile.TemporaryDirectory() as folder:
        github = Stub(world(), deaf=gone(403))
        (code, said) = quietly(make_way, github, folder, "train/2", "main is 0123456", "x")
        rows.append(("GitHub does not even list the runs: no traceback; it says that nothing was cancelled and that the hold stands",
                     (code, posts(github), "NOTHING WAS CANCELLED; the hold stands" in said, read(folder, "hold.txt") is not None), (1, [], True, True)))
        save(os.path.join(folder, "made-way.json"), json.dumps([{"id": 3, "path": "x/mac-shell.yml", "branch": "fix/3", "title": "t", "tag": "t3"}]))
        (code, _) = quietly(give_back, github, folder)
        rows.append(("--back when GitHub lists nothing: nothing is started, it stays written down, and the hold goes", (code, posts(github), ids(folder), read(folder, "hold.txt")), (1, [], [3], None)))

    for broken in ("", "{", "null", "[1]", '[{"id": 1}]'):
        with tempfile.TemporaryDirectory() as folder:
            save(os.path.join(folder, "made-way.json"), broken)
            save(os.path.join(folder, "hold.txt"), "until main is 0123456\n")
            (code, said) = quietly(give_back, Stub([]), folder)
            rows.append((f"--back with a record that reads {broken!r}: set aside with a word, and the hold goes",
                         (code, "cannot be read" in said, read(folder, "hold.txt"), read(folder, "made-way.json.unreadable")), (0, True, None, broken)))
    with tempfile.TemporaryDirectory() as folder:
        save(os.path.join(folder, "made-way.json"), "{")
        (code, _) = quietly(make_way, Stub(world()), folder, "train/2", "main is 0123456", "x")
        rows.append(("making way over such a record: likewise, and a new one is begun", (code, ids(folder)), (0, [11, 10, 3, 1])))

    with tempfile.TemporaryDirectory() as folder:
        github = Stub([run(number, "ci", f"fix/{number}") for number in range(1, 131)] + [run(200, "ci", "train/2")])
        (code, _) = quietly(make_way, github, folder, "train/2", "main is 0123456", "x")
        rows.append(("a hundred and thirty wait: all are cancelled, the oldest, which stand in front, first", (code, len(posts(github)), posts(github)[0], posts(github)[-1]), (0, 130, "130/cancel", "1/cancel")))

    with tempfile.TemporaryDirectory() as folder:
        github = Stub(world())
        (code, said) = quietly(make_way, github, folder, "train/2", "main is 0123456", "x", dry=True)
        rows.append(("--dry-run: it says what it would do, and does nothing", (code, posts(github), os.listdir(folder), said.count("would be cancelled")), (0, [], [], 4)))
        (_, said) = quietly(make_way, Stub(world()), folder, "train/3", "main is 0123456", "x", dry=True)
        rows.append(("a branch no run is about: it asks whether that is its name", "no run that waits or is under way is about train/3" in said, True))

    now = datetime.datetime(2026, 1, 2, 12, 0, tzinfo=datetime.timezone.utc)
    for text, good in (("main is 0123456", True), ("main is " + "a" * 40, True), ("2026-01-02T12:30Z", True), ("main is there", False), ("tomorrow", False), ("main is 012345", False),
                       ("2026-13-45T99:99Z", False), ("2026-01-02T11:59Z", False), ("", False), (None, False)):
        rows.append((f"--until {text}", until_what(text, now) is not None, good))

    # The command line, with a stand-in for GitHub and a folder of its own.
    with tempfile.TemporaryDirectory() as folder:
        def called(*arguments):
            github = Stub(world())
            (code, said) = quietly(main, list(arguments), github=github, folder=folder)
            return code, posts(github), said
        rows += [
            ("--for and --until", called("--for", "train/2", "--until", "main is 0123456")[:2], (0, ["11/cancel", "10/cancel", "3/cancel", "1/cancel"])),
            ("the reason given is the reason written, on one line", (called("--for", "train/2", "--until", "main is 0123456", "--why", "two\nlines")[0], read(folder, "hold.txt")),
             (0, "until main is 0123456\ntwo lines\n")),
            ("a branch named as git names it", called("--for", "refs/heads/train/2", "--until", "main is 0123456")[1], ["11/cancel", "10/cancel", "3/cancel", "1/cancel"]),
            ("or as a remote's", called("--for", "origin/train/2", "--until", "main is 0123456")[1], ["11/cancel", "10/cancel", "3/cancel", "1/cancel"]),
            ("--back --dry-run starts nothing and leaves the hold", (*called("--back", "--dry-run")[:2], read(folder, "hold.txt") is not None, len(ids(folder))), (0, [], True, 4)),
            ("--back; the Mac shell run among them waits again in this world, so it is its owner's", called("--back")[:2], (0, ["10/rerun"])),
            ("--for without --until", called("--for", "train/2")[:2], (2, [])),
            ("--for with a time that is past", called("--for", "train/2", "--until", "2020-01-02T12:30Z")[:2], (2, [])),
            ("--for and --back", called("--for", "train/2", "--until", "main is 0123456", "--back")[:2], (2, [])),
            ("neither", called()[:2], (2, [])),
        ]

    failed = [f"{what}: got {got!r}, expected {wanted!r}" for what, got, wanted in rows if got != wanted]
    for line in failed:
        print("make-way self-test:", line)
    print(f"{len(rows) - len(failed)} of {len(rows)} make-way situations came out as expected")
    return 1 if failed else 0


def said_by(*command):
    try:
        return subprocess.run(command, cwd=HERE, capture_output=True, text=True, check=False).stdout.strip()
    except OSError:  # there is no such program here
        return ""


def main(arguments=None, github=None, folder=None):
    parser = argparse.ArgumentParser(usage="see the top of scripts/make-way.py", add_help=False)
    parser.add_argument("--for", dest="branch")
    parser.add_argument("--until")
    parser.add_argument("--why", default="Work is on its way to main, and its checks want the runners.")
    for flag in ("--back", "--dry-run", "--self-test", "--help"):
        parser.add_argument(flag, action="store_true")
    options = parser.parse_args(arguments)
    if options.self_test:
        return self_test()
    if options.help or bool(options.back) == bool(options.branch) or (options.branch and not until_what(options.until)):
        print(__doc__)
        return 0 if options.help else 2
    if folder is None:
        words = said_by("git", "config", "--get", "arbor.privateWords")
        if not words:
            print("make-way: this clone does not say where the file of private words is (git config arbor.privateWords), and the hold lies beside it")
            return 2
        folder = os.path.dirname(os.path.expanduser(words))
    if github is None:
        token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN") or said_by("gh", "auth", "token")
        found = re.search(r"github\.com(:\d+)?[:/]+([\w.-]+/[\w.-]+?)(\.git)?/?$", said_by("git", "remote", "get-url", "origin"))
        repository = os.environ.get("GITHUB_REPOSITORY") or (found.group(2) if found else None)
        if not token or not repository:
            print("make-way: a token ($GH_TOKEN, $GITHUB_TOKEN or `gh auth login`) and a repository ($GITHUB_REPOSITORY or origin) are needed")
            return 2
        github = GitHub(repository, token)
    if options.back:
        return give_back(github, folder, options.dry_run)
    return make_way(github, folder, re.sub(r"^(refs/heads/|origin/)", "", options.branch), options.until, " ".join(options.why.split()), options.dry_run)


if __name__ == "__main__":
    sys.exit(main())
