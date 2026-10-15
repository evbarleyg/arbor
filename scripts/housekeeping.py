#!/usr/bin/env python3
"""Prunes the branches nobody needs any more, once a day, so that no person has to.

Two kinds pile up. Every Mac shell run leaves its output on a branch `mac-shell-out/<tag>`, pictures and all, which whoever started
the run fetches within minutes. And every pull request leaves its branch behind when it has landed. Some of the environments
agents work in may push branches but not delete them, so neither kind ever goes, every clone fetches them all, and the list of
branches stops telling anybody anything.

What goes:

  output   `mac-shell-out/*` whose one commit is more than a day old.
  landed   A branch that had a pull request, now closed, still stands where it stood then, and holds nothing that `main` or `swarm/trunk`
           lacks. Nothing is lost with it: every commit is in the history.
  trains   `train/*`, and `line/*`, the trunk-to-be that is shown while it is being tried by hand. Neither ever has a pull request. Each goes as soon
           as `main` or `swarm/trunk` holds all of it: the trunk has moved forward to it. One that failed stays, like other work that has not landed.

What never goes, whatever else is true of it: the default branch, `main`, `swarm/trunk`, a protected branch, a branch that an open pull
request comes from or goes into (whoever's), and `gallery/*`, whose pictures pages link to by the branch's name. A branch that never
had a pull request stays: it may be a mark somebody set. Work that has not landed is nobody's to tidy away, however old: it
is only counted.

Many hands push here all day, so what was true when the branches were listed may not be when one is deleted. A branch is deleted only
if it still stands at the very commit the decision was made on (git's --force-with-lease, which the server itself checks), and after
one more look for an open pull request.

Usage: scripts/housekeeping.py --prune       in the workflow `Housekeeping`
       scripts/housekeeping.py --dry-run     only says what would go
       scripts/housekeeping.py --self-test   the rules against a table of situations, with GitHub's part made up

Needs $GITHUB_REPOSITORY, and in $GITHUB_TOKEN or $GH_TOKEN a token that may write contents (for --dry-run: read).
Exit code 0, or 1 when a branch that should go could not be deleted, or 2 when GitHub's answers made no sense: then nothing is deleted.
"""

import base64
import datetime
import http.client
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

OUTPUT_PREFIX = "mac-shell-out/"
TRAIN_PREFIX = ("train/", "line/")
KEPT_PREFIXES = ("gallery/",)
KEPT_FOR = datetime.timedelta(days=1)
INTEGRATION = ("main", "swarm/trunk")
# More than this at once means something is wrong with the rules or with GitHub's answers, not with the branches.
AT_MOST = 300
NO_ANSWER = (OSError, http.client.HTTPException)  # urllib's own errors are OSErrors


class GitHub:
    def __init__(self, repository, token):
        self.repository, self.token = repository, token

    def call(self, path):
        request = urllib.request.Request(f"https://api.github.com/repos/{self.repository}{path}", headers={
            "Authorization": f"Bearer {self.token}", "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"})
        with urllib.request.urlopen(request, timeout=30) as answer:
            return json.loads(answer.read())

    def every(self, path):
        page, items = 1, []
        while True:
            batch = self.call(f"{path}{'&' if '?' in path else '?'}per_page=100&page={page}")
            items += batch
            if len(batch) < 100:
                return items
            page += 1

    def default_branch(self):
        return self.call("")["default_branch"]

    def branches(self):
        return [(branch["name"], branch["commit"]["sha"], branch["protected"]) for branch in self.every("/branches")]

    def pull_requests(self, query="state=all"):
        """head (None when it is a fork's branch, which only shares a name with one here), head's commit, base, whether open."""
        return [(pull["head"]["ref"] if (pull["head"].get("repo") or {}).get("full_name") == self.repository else None,
                 pull["head"]["sha"], pull["base"]["ref"], pull["state"] == "open") for pull in self.every(f"/pulls?{query}")]

    def is_in_use(self, name):
        """Whether an open pull request comes from or goes into the branch, asked afresh."""
        owner, quoted = self.repository.split("/")[0], urllib.parse.quote(name, safe="")
        return bool(self.call(f"/pulls?state=open&per_page=1&base={quoted}") or self.call(f"/pulls?state=open&per_page=1&head={owner}:{quoted}"))

    def committed_at(self, sha):
        date = self.call(f"/commits/{sha}")["commit"]["committer"]["date"]
        return datetime.datetime.fromisoformat(date.replace("Z", "+00:00"))

    def adds_nothing_to(self, base, sha):
        """Whether `base` holds every commit that leads up to `sha`."""
        try:
            return self.call(f"/compare/{urllib.parse.quote(base, safe='')}...{sha}")["ahead_by"] == 0
        except urllib.error.HTTPError as error:
            if error.code == 404:  # no common ancestor
                return False
            raise

    def address(self):
        return f"https://github.com/{self.repository}.git"

    def delete(self, name, sha):
        """Deletes the branch if it still stands at `sha`. "gone", "moved" (or deleted by somebody else), or what git said."""
        header = "AUTHORIZATION: basic " + base64.b64encode(f"x-access-token:{self.token}".encode()).decode()
        # The token travels in the environment, not on a command line or in a file.
        environment = dict(os.environ, GIT_TERMINAL_PROMPT="0", GIT_CONFIG_COUNT="1", GIT_CONFIG_KEY_0="http.https://github.com/.extraheader", GIT_CONFIG_VALUE_0=header)
        done = subprocess.run(["git", "push", "--porcelain", f"--force-with-lease=refs/heads/{name}:{sha}", self.address(), f":refs/heads/{name}"],
                              capture_output=True, text=True, env=environment, timeout=120, check=False)
        said = done.stdout + done.stderr
        return "gone" if done.returncode == 0 else "moved" if "stale info" in said or "remote ref does not exist" in said else said.strip()[-300:]


def to_prune(github, now):
    """(branch, its commit, why) for every branch that goes, and how many stay with work that has not landed."""
    default = github.default_branch()
    branches, pulls = github.branches(), github.pull_requests()
    names = {name for name, _, _ in branches}
    if default not in names:
        raise ValueError(f"GitHub's list of branches lacks the default branch, {default}")
    kept = {default, *INTEGRATION}
    in_use = {ref for head, _, base, is_open in pulls if is_open for ref in (head, base)}
    closed_at = {(head, sha) for head, sha, _, is_open in pulls if head and not is_open}
    going, staying = [], 0
    for name, sha, protected in branches:
        if name in kept or protected or name in in_use or name.startswith(KEPT_PREFIXES):
            continue
        if name.startswith(OUTPUT_PREFIX):
            age = now - github.committed_at(sha)
            if age > KEPT_FOR:
                going.append((name, sha, f"the output of a Mac shell run, {age.days} day{'' if age.days == 1 else 's'} old"))
            continue
        holder = next((base for base in INTEGRATION if base in names and github.adds_nothing_to(base, sha)), None) if (name, sha) in closed_at or name.startswith(TRAIN_PREFIX) else None
        if holder:
            going.append((name, sha, f"{'a merge train,' if name.startswith(TRAIN_PREFIX) else 'its pull request is closed'} and {holder} holds all of it"))
        else:
            staying += 1
    return going, staying


def notice(level, message):
    text = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::{level} title=housekeeping::{text}" if os.environ.get("GITHUB_ACTIONS") else f"housekeeping: {message}")


def run(github, now, dry_run):
    try:
        going, staying = to_prune(github, now)
        if len(going) > AT_MOST:
            raise ValueError(f"{len(going)} branches would go at once, more than {AT_MOST}: look at the rules first")
    except (ValueError, KeyError, TypeError, AttributeError, *NO_ANSWER) as error:
        notice("error", f"nothing was deleted: {type(error).__name__}: {error}")
        return 2
    gone = failed = 0
    for name, sha, why in going:
        if dry_run:
            print(f"would delete {name}: {why}")
            continue
        try:
            outcome = "in use" if github.is_in_use(name) else github.delete(name, sha)
        except (*NO_ANSWER, subprocess.TimeoutExpired, KeyError, TypeError) as error:
            outcome = f"{type(error).__name__}: {error}"
        if outcome == "gone":
            gone += 1
            print(f"deleted {name} ({sha[:8]}): {why}")
        elif outcome in ("moved", "in use"):
            print(f"left {name}: since the list was read it has moved, gone, or got a pull request")
        else:
            failed += 1
            notice("warning", f"could not delete {name}: {outcome}")
    notice("notice", f"{len(going) if dry_run else gone} branches {'would go' if dry_run else 'deleted'}; {staying} that have not landed, or never had a pull request, stay")
    return 1 if failed else 0


# MARK: --self-test

NOW = datetime.datetime(2026, 1, 2, 4, 0, tzinfo=datetime.timezone.utc)


class Stub(GitHub):
    """The real class with GitHub's answers made up, in GitHub's own shapes.

    branches: name → (commit, protected). held: base → the commits it holds. pulls: (head, commit, base, state[, the head's repository]).
    hours: commit → its age. meanwhile: branch → what happens to it after the list was read ("moved", "pull request", or what git says)."""

    def __init__(self, branches, held=None, pulls=(), hours=None, meanwhile=None, default="trunk-of-old", lacks=()):
        super().__init__("x/arbor", "t0ken")
        self.all = {default: ("D", False), "main": ("M", True), "swarm/trunk": ("T", False), **branches}
        for name in lacks:
            del self.all[name]
        self.held, self.pulls, self.hours, self.meanwhile, self.default = held or {}, list(pulls), hours or {}, meanwhile or {}, default
        self.deleted, self.asked = [], []

    def call(self, path):
        self.asked.append(path)
        route, _, query = path.partition("?")
        fields = dict(urllib.parse.parse_qsl(query))
        page = lambda items: items[(int(fields.get("page", 1)) - 1) * int(fields["per_page"]):][:int(fields["per_page"])]
        if route == "":
            return {"default_branch": self.default}
        if route == "/branches":
            return page([{"name": name, "commit": {"sha": sha}, "protected": protected} for name, (sha, protected) in self.all.items()])
        if route == "/pulls":
            listed = [{"head": {"ref": head, "sha": sha, "repo": None if rest == [None] else {"full_name": rest[0] if rest else "x/arbor"}}, "base": {"ref": base, "repo": {"full_name": "x/arbor"}},
                       "state": "open" if state == "open" else "closed", "merged_at": "2026-01-01T00:00:00Z" if state == "merged" else None}
                      for head, sha, base, state, *rest in self.pulls]
            listed += [{"head": {"ref": "late", "sha": "L", "repo": {"full_name": "x/arbor"}}, "base": {"ref": name, "repo": {"full_name": "x/arbor"}}, "state": "open", "merged_at": None}
                       for name, what in self.meanwhile.items() if what == "pull request" and fields.get("per_page") == "1"]
            if fields.get("state") == "open":
                listed = [pull for pull in listed if pull["state"] == "open"]
            if "base" in fields:
                listed = [pull for pull in listed if pull["base"]["ref"] == fields["base"]]
            if "head" in fields:
                listed = [pull for pull in listed if pull["head"]["repo"] and f"{pull['head']['repo']['full_name'].split('/')[0]}:{pull['head']['ref']}" == fields["head"]]
            return page(listed)
        if route.startswith("/commits/"):
            made = NOW - datetime.timedelta(hours=self.hours[route[len("/commits/"):]])
            return {"commit": {"committer": {"date": made.strftime("%Y-%m-%dT%H:%M:%SZ")}}}
        if route.startswith("/compare/"):
            base, sha = urllib.parse.unquote(route[len("/compare/"):]).split("...")
            if sha == "ORPHAN":
                raise urllib.error.HTTPError(path, 404, "No common ancestor", None, None)
            return {"ahead_by": 0 if sha in self.held.get(base, ()) else 3, "behind_by": 0 if sha not in self.held.get(base, ()) else 5}
        raise AssertionError(path)

    def delete(self, name, sha):
        if self.all[name][0] != sha:
            raise AssertionError(f"{name} is to be deleted at {sha}, where it never stood")
        what = self.meanwhile.get(name, "gone")
        if what == "gone":
            self.deleted.append(name)
        return what


def self_test():
    import contextlib
    import io

    def pruned(dry_run=False, **fields):
        github = Stub(**fields)
        with contextlib.redirect_stdout(io.StringIO()):
            code = run(github, NOW, dry_run)
        return code, github.deleted

    X, Y = {"fix/x": ("A", False)}, {"fix/x": ("A", False), "fix/y": ("B", False)}
    on_trunk, on_main = {"swarm/trunk": {"A", "B"}}, {"main": {"A", "B"}}
    merged = [("fix/x", "A", "swarm/trunk", "merged")]
    out = {"mac-shell-out/a.b": ("A", False)}
    cases = [
        ("nothing but the branches work is integrated on", pruned(branches={}), (0, [])),
        ("output of two days ago", pruned(branches=out, hours={"A": 49}), (0, ["mac-shell-out/a.b"])),
        ("output of this evening", pruned(branches=out, hours={"A": 3}), (0, [])),
        ("output of just under a day ago", pruned(branches=out, hours={"A": 23}), (0, [])),
        ("old output that is protected", pruned(branches={"mac-shell-out/a.b": ("A", True)}, hours={"A": 49}), (0, [])),
        ("old output that an open pull request comes from", pruned(branches=out, hours={"A": 49}, pulls=[("mac-shell-out/a.b", "A", "main", "open")]), (0, [])),
        ("a branch that only begins like it", pruned(branches={"mac-shell-outing": ("A", False)}, hours={"A": 99}), (0, [])),
        ("a branch whose pull request has landed", pruned(branches=X, pulls=merged, held=on_trunk), (0, ["fix/x"])),
        ("landed on main", pruned(branches=X, pulls=[("fix/x", "A", "main", "merged")], held=on_main), (0, ["fix/x"])),
        ("the same with a commit since", pruned(branches={"fix/x": ("C", False)}, pulls=merged, held=on_trunk), (0, [])),
        ("shown as merged, into another branch, and the trunk has none of it", pruned(branches=X, pulls=[("fix/x", "A", "fix/base", "merged")]), (0, [])),
        ("shown as merged, and the trunk has been wound back since", pruned(branches=X, pulls=merged), (0, [])),
        ("closed without landing", pruned(branches=X, pulls=[("fix/x", "A", "swarm/trunk", "closed")]), (0, [])),
        ("closed, and landed some other way", pruned(branches=X, pulls=[("fix/x", "A", "swarm/trunk", "closed")], held=on_trunk), (0, ["fix/x"])),
        ("an open pull request", pruned(branches=X, pulls=[("fix/x", "A", "swarm/trunk", "open")], held=on_trunk), (0, [])),
        ("landed once, and open again under the same name", pruned(branches=X, pulls=merged + [("fix/x", "A", "main", "open")], held=on_trunk), (0, [])),
        ("landed, and another open pull request goes into it", pruned(branches=Y, pulls=merged + [("fix/y", "B", "fix/x", "open")], held={"swarm/trunk": {"A"}}), (0, [])),
        ("landed, and a fork's open pull request goes into it", pruned(branches=X, pulls=merged + [("theirs", "F", "fix/x", "open", "someone/arbor")], held=on_trunk), (0, [])),
        ("landed, and an open pull request from a fork that is gone goes into it", pruned(branches=X, pulls=merged + [("theirs", "F", "fix/x", "open", None)], held=on_trunk), (0, [])),
        ("a fork's merged pull request from a branch of the same name says nothing about this one",
         pruned(branches=X, pulls=[("fix/x", "A", "swarm/trunk", "merged", "someone/arbor")], held=on_trunk), (0, [])),
        ("a fork's open pull request from a branch of the same name does not protect this one",
         pruned(branches=X, pulls=merged + [("fix/x", "F", "swarm/trunk", "open", "someone/arbor")], held=on_trunk), (0, ["fix/x"])),
        ("never had a pull request, and the trunk holds all of it: a mark somebody set", pruned(branches=X, held=on_trunk), (0, [])),
        ("a merge train that the trunk has moved forward to", pruned(branches={"train/7": ("A", False)}, held=on_trunk), (0, ["train/7"])),
        ("the line that was tried by hand, likewise", pruned(branches={"line/13": ("A", False)}, held=on_trunk), (0, ["line/13"])),
        ("a merge train that failed", pruned(branches={"train/7": ("A", False)}, hours={"A": 99}), (0, [])),
        ("a merge train with an open pull request after all", pruned(branches={"train/7": ("A", False)}, pulls=[("train/7", "A", "main", "open")], held=on_trunk), (0, [])),
        ("a branch that only begins like a train", pruned(branches={"trains": ("A", False)}, held=on_trunk), (0, [])),
        ("work that has not landed, however old", pruned(branches={"probe/x": ("A", False)}, hours={"A": 9999}), (0, [])),
        ("no ancestor in common with anything", pruned(branches={"fix/x": ("ORPHAN", False)}, pulls=[("fix/x", "ORPHAN", "swarm/trunk", "closed")]), (0, [])),
        ("a protected branch that has landed", pruned(branches={"fix/x": ("A", True)}, pulls=merged, held=on_trunk), (0, [])),
        ("pictures that pages link to by the branch's name", pruned(branches={"gallery/pictures": ("A", False)}, pulls=[("gallery/pictures", "A", "swarm/trunk", "merged")], held=on_trunk), (0, [])),
        ("swarm/trunk after its pull request into main has landed", pruned(branches={}, pulls=[("swarm/trunk", "T", "main", "merged")], held={"main": {"T"}}), (0, [])),
        ("the default branch, whatever it is called, after the same", pruned(branches={}, pulls=[("trunk-of-old", "D", "main", "merged")], held={"main": {"D"}}), (0, [])),
        ("main where it is neither the default branch nor protected", pruned(branches={"main": ("M", False)}, pulls=[("main", "M", "swarm/trunk", "merged")], held={"swarm/trunk": {"M"}}), (0, [])),
        ("there is no swarm/trunk", pruned(branches=X, pulls=[("fix/x", "A", "main", "merged")], held=on_main, lacks=["swarm/trunk"]), (0, ["fix/x"])),
        ("--dry-run", pruned(dry_run=True, branches=X, pulls=merged, held=on_trunk), (0, [])),
        ("pushed to since the list was read", pruned(branches=X, pulls=merged, held=on_trunk, meanwhile={"fix/x": "moved"}), (0, [])),
        ("a pull request into it was opened since the list was read", pruned(branches=X, pulls=merged, held=on_trunk, meanwhile={"fix/x": "pull request"}), (0, [])),
        ("one that cannot be deleted does not stop the rest",
         pruned(branches=Y, pulls=merged + [("fix/y", "B", "swarm/trunk", "merged")], held=on_trunk, meanwhile={"fix/x": "remote: refused by a rule"}), (1, ["fix/y"])),
        ("far too many at once: nothing goes", pruned(branches={f"fix/{n}": ("A", False) for n in range(AT_MOST + 1)},
                                                      pulls=[(f"fix/{n}", "A", "swarm/trunk", "merged") for n in range(AT_MOST + 1)], held=on_trunk), (2, [])),
        ("a list of branches without the default branch cannot be right: nothing goes", pruned(branches=X, pulls=merged, held=on_trunk, lacks=["trunk-of-old"]), (2, [])),
        ("more branches and pull requests than one page holds: the last are seen too",
         pruned(branches={**{f"probe/{n}": ("P", False) for n in range(250)}, **X}, pulls=[(f"probe/{n}", "Q", "main", "closed") for n in range(250)] + merged, held=on_trunk), (0, ["fix/x"])),
        ("the open pull request that protects it is on the last page",
         pruned(branches=X, pulls=merged + [(f"probe/{n}", "Q", "main", "closed") for n in range(250)] + [("fix/y", "B", "fix/x", "open")], held=on_trunk), (0, [])),
    ]
    for error in (TimeoutError("slow"), http.client.RemoteDisconnected("gone"), urllib.error.HTTPError("u", 403, "rate limit", None, None), KeyError("commit")):
        class Broken(Stub):
            def call(self, path, error=error):
                if path.startswith("/compare/"):
                    raise error
                return super().call(path)
        github = Broken(branches=X, pulls=merged, held=on_trunk)
        with contextlib.redirect_stdout(io.StringIO()):
            cases.append((f"GitHub stops answering half way ({type(error).__name__}): nothing goes", (run(github, NOW, False), github.deleted), (2, [])))
    odd = Stub(branches={"fix/a#b%c é": ("A", False)}, pulls=[("fix/a#b%c é", "A", "swarm/trunk", "merged")], held=on_trunk)
    with contextlib.redirect_stdout(io.StringIO()):
        run(odd, NOW, False)
    cases.append(("a name with marks that mean something in an address", odd.deleted, ["fix/a#b%c é"]))

    # The deletion itself, by the real git against a repository made for the purpose.
    import tempfile
    with tempfile.TemporaryDirectory() as folder:
        quiet = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        quiet.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
        git = lambda *given: subprocess.run(["git", "-C", folder, "-c", "user.name=x", "-c", "user.email=x@users.noreply.github.com", *given],
                                            capture_output=True, text=True, env=quiet, check=True, input="").stdout.strip()
        git("init", "--quiet", "--bare", "--initial-branch=main", ".")
        tree = git("mktree")
        first = git("commit-tree", tree, "-m", "one")
        second = git("commit-tree", tree, "-p", first, "-m", "two")

        class Local(GitHub):
            def address(self):
                return folder
        local, saved = Local("x/arbor", "t0ken"), dict(os.environ)
        os.environ.clear()
        os.environ.update(quiet)
        try:
            for name in ("stays-put", "moves"):
                git("update-ref", f"refs/heads/{name}", first)
            git("update-ref", "refs/heads/moves", second)
            outcomes = [local.delete("stays-put", first), local.delete("moves", first), local.delete("never-was", first)]
        finally:
            os.environ.clear()
            os.environ.update(saved)
        cases.append(("git deletes a branch that stands where it stood, and leaves one that has moved or is gone",
                      (outcomes, git("for-each-ref", "--format=%(refname:short) %(objectname)")), (["gone", "moved", "moved"], f"moves {second}")))

    def arguments(*given):
        saved = dict(os.environ)
        for name in ("GITHUB_TOKEN", "GH_TOKEN", "GITHUB_REPOSITORY"):
            os.environ.pop(name, None)
        try:
            with contextlib.redirect_stdout(io.StringIO()) as output:
                code = main(list(given))
        finally:
            os.environ.clear()
            os.environ.update(saved)
        return code, "Usage:" in output.getvalue()
    cases += [(f"arguments: {' '.join(given) or 'none'}", arguments(*given), (2, True))
              for given in [(), ("--help",), ("--dryrun",), ("-n",), ("--dry_run",), ("--prune", "--dry-run"), ("--prune", "x")]]
    cases.append(("arguments: --prune gets as far as asking for a token", arguments("--prune"), (2, False)))

    failed = [f"{what}: got {got!r}, expected {wanted!r}" for what, got, wanted in cases if got != wanted]
    for line in failed:
        print("housekeeping self-test:", line)
    print(f"{len(cases) - len(failed)} of {len(cases)} housekeeping situations came out as expected")
    return 1 if failed else 0


def main(arguments):
    if arguments == ["--self-test"]:
        return self_test()
    if arguments not in (["--prune"], ["--dry-run"]):
        print(__doc__)
        return 2
    repository, token = os.environ.get("GITHUB_REPOSITORY"), os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not repository or not token:
        notice("error", "$GITHUB_REPOSITORY and a token in $GITHUB_TOKEN or $GH_TOKEN are needed")
        return 2
    return run(GitHub(repository, token), datetime.datetime.now(datetime.timezone.utc), arguments == ["--dry-run"])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
