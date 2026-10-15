#!/usr/bin/env python3
"""Decides whether a CI run needs its macOS job, the slow and scarce one, and which tests that job runs.

A Mac is left out when it could prove nothing new, or nothing that will not be proved soon anyway:

  1. everything the pull request changes (for a push: everything since the commit before it) is
     prose, or data the Linux job checks just as well: collab/, docs/, *.md, scripts/typecheck-mac/ and
     scripts/mac-on-linux/ (which only Linux runs), Sources/arbor-fakemac/ (which Package.swift leaves out on a Mac unless ARBOR_FAKEMAC is set, and
     nothing a Mac runs here sets it: no Mac's compiler sees it; these rules' self-test looks that this stays so),
     the scripts in scripts/mac-shell/ that CI does not run (it runs e2e-drag.sh and compile-tools.sh, and
     with them lib.sh and its tools; and `swift test` on a Mac type-checks every helper tool there, *.swift and *.m),
     the Mac shell workflow, these rules, scripts/mac-queue.py and the tools' self-tests, which run on Linux,
     the Makefile, which the macOS job does not use, and what looks after the repository itself (scripts/public-*, git-hooks, .claude …);
     or a script that the macOS job cannot reach. Nobody keeps a list of those: what the job can reach is read off the checkout. It is
     every file under scripts/ that the job's own steps in ci.yml, the actions it uses or a test name, and whatever those files name in
     turn. A mention in a remark counts, so it errs towards the Mac; a new script that nothing of all this names asks for none;
  2. or, in an ordinary pull request, all the rest of it is code that also builds and is tested on
     Linux (the core, the controller, the platform protocols, the fakes, arbor-sim, the tests);
  3. or only prose has changed since the nearest earlier commit that passed the macOS job. That covers
     the report pushed after the code, and a branch moving forward to the tested head of a pull
     request, where nothing changed at all. Passed means all of it: the job `macos`, and the jobs that
     speak for it, `real-windows` and `tests-accounted-for`.

Rule 2 can let through a change that breaks the macOS-only code which uses it. So it does not apply where
work is integrated: pushes (ci.yml listens for those to `main` and to a merge train, `train/…`), pull requests into `main`, and the pull
request whose head is the swarm's trunk. There every change of code is compiled and driven on a real Mac.
What a merge train changes is what it adds to the trunk, whether it is pushed for the first time or again. At first it is a new branch, with no
commit before it: that would be unclear, and a train of more commits than rule 3 looks back would get every test, built from nothing, each
time. Pushed again, the commit before it is the train as it was, which may never have seen a Mac: the first train there was had a line
of a self-test mended and was pushed again before its Mac began, and "only prose since the commit before" spared the whole of it.
So a train of prose takes no Mac, even upon a trunk that moved forward without one having passed. `main` is covered all the same: the trunk's own
pull request into it is integration, and counts only a commit that passed on a Mac built from nothing.

A pull request that is still a draft gets no Mac, whatever it changes and wherever it goes: its author has not said that it is ready, Linux
runs lint alone for it (.github/workflows/linux.yml says why), and that run has no verdict. Marking it ready starts the whole run.

"[mac]" in the subject of the head commit, or the label "mac" on the pull request, asks for the Mac
whatever changed, on a draft too. When anything is unclear (a call fails, a comparison is too large to
list), it runs.

A Mac that runs need not repeat what the Linux job does on the same commit, nor build what an earlier job has built. There are
three ways for it to run:

  upon    in an ordinary pull request: only the tests a Mac can say something about (scripts/ci-tests.py selects them, and a job of its
          own checks that every test ran somewhere), built upon an earlier job's build (.github/actions/mac-setup);
  fresh   where work is integrated: the same tests, but built from nothing. Whatever building upon a cache might hide cannot reach main;
  full    every test, built from nothing: every night on main, as a backstop; when "[mac-full]" in the subject of the head commit or the
          label "mac-full" asks for it; for an event without a rule (the workflow started by hand); and when anything is unclear.

Where work is integrated, rule 3 counts only a commit that passed on a Mac built from nothing. The job `macos-from-nothing` says so: it
succeeds when `macos` has passed that way, and does nothing else.

Reads the event from the environment GitHub Actions provides. Needs `gh` and a token that may read
contents, pull requests and checks. Appends `mac=true` or `mac=false`, `tests=full`, `mac-only` or (without a Mac) `none`,
`build=from-nothing`, `upon` or `none`, and `why=` with the reason to $GITHUB_OUTPUT, and publishes the reason as a check annotation.
Whoever reads them takes anything but `mac-only` for `full`, and anything but `upon` for `from-nothing`. To try it by hand:

  gh api repos/evbarleyg/arbor/pulls/10 --jq '{pull_request: .}' > /tmp/event.json
  GITHUB_EVENT_NAME=pull_request GITHUB_EVENT_PATH=/tmp/event.json GITHUB_REPOSITORY=evbarleyg/arbor \\
    scripts/ci-changes.py
"""

import glob
import json
import os
import re
import subprocess
import sys

PROSE = re.compile(
    r"^(collab|docs|scripts/typecheck-mac|scripts/mac-on-linux|Sources/arbor-fakemac)/|^scripts/mac-shell/(?!(e2e-drag\.sh|lib\.sh|compile-tools\.sh|state\.py|.*\.swift|.*\.m)$)|\.md$"
    # What CI's macOS job never runs. The Mac shell workflow is proved by a Mac shell run; the Linux jobs' own workflow, these rules and the
    # tools' self-tests by Linux.
    r"|^\.github/workflows/(mac-shell|linux|old-python)\.yml$|^scripts/ci-mac-shell\.sh$"
    r"|^scripts/(test-)?(ci-changes|mac-queue)\.py$|^scripts/test-(tooling|ci-tests)\.py$"
    # The Makefile: no step of CI's macOS job calls make, so a Mac here would prove nothing about it. (release.yml's does, `make check` and
    # `make release`, and CI never runs that workflow: its own rehearsal is what tries them.) And what looks after the repository itself, on
    # Linux or at GitHub's.
    r"|^Makefile$|^scripts/(test-)?public-[a-z-]+\.\w+$|^scripts/git-hooks/|^scripts/(lint-workflows|housekeeping|gh-state|make-way)\.py$|^\.github/(workflows/(public-[a-z-]+|housekeeping|state)|dependabot)\.yml$|^\.claude/"
)
# What Package.swift builds on Linux too. Anything in neither list needs a Mac.
HEADLESS = re.compile(
    r"^(Sources/(ArborCore|ArborKit/(Controller|Platform|Support|Trace)|ArborTesting|arbor-sim|LinuxShims)|Tests)/"
)
INTEGRATION_BRANCH = "swarm/trunk"
MAIN = "main"
TRAINS = "refs/heads/train/"
MARKER = "[mac]"
LABEL = "mac"
FULL_MARKER = "[mac-full]"
FULL_LABEL = "mac-full"
ASKED_FOR = "asked for"
UPON, FRESH, FULL = "upon", "fresh", "full"
HOW = {
    UPON: "only the tests a Mac can say something about, built upon an earlier job's build",
    FRESH: "only the tests a Mac can say something about, built from nothing, because work is integrated here",
}
# The check that says a Mac passed, and the one that says it had built from nothing when it did.
CHECK, FRESH_CHECK = "macos", "macos-from-nothing"
# The macOS job goes on after a real-window check that failed, so that one run tells all there is to tell, and succeeds. What real windows said, and whether
# every test ran somewhere, are jobs of their own. A commit at which one of them is red, or did not run, has not passed on a Mac: or a line of prose pushed
# after it would find "nothing a Mac could check has changed since it passed", leave the Mac out, those jobs with it, and show no red at all.
WITH_IT = ("real-windows", "tests-accounted-for")
# How many commits back to look for one that passed.
LOOK_BACK = 10
# The comparison API lists at most this many files and does not say when it left some out.
LISTED_AT_MOST = 300
# A renamed file counts under both of its names.
NAMES = "[.[] | .filename, (.previous_filename // empty)]"


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOB = "macos"


class Unclear(Exception):
    pass


def text_of(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        return handle.read()


def checkout(root=ROOT):
    """What the reach of the macOS job is read off: where it starts (texts), and {path: text} of every file under scripts/."""
    workflow = text_of(os.path.join(root, ".github", "workflows", "ci.yml"))
    job = re.search(rf"^  {JOB}:\n(.*?)(?=^  [\w-]+:\n|\Z)", workflow, re.S | re.M)
    tests = glob.glob(os.path.join(root, "Tests", "**", "*.swift"), recursive=True)
    if not job or not tests:
        raise Unclear(f"no job {JOB} in ci.yml, or no tests, in {root}")
    starts = [job.group(1)] + [text_of(path) for path in glob.glob(os.path.join(root, ".github", "actions", "*", "action.yml")) + tests]
    scripts = {os.path.relpath(path, root).replace(os.sep, "/"): text_of(path)
               for path in glob.glob(os.path.join(root, "scripts", "**"), recursive=True) if os.path.isfile(path)}
    return starts, scripts


def reach(starts, scripts):
    """The files of `scripts` that the texts in `starts` name, by their file name or as a Python module, and what those name in turn."""
    names = {}
    for path in scripts:
        base = os.path.basename(path)
        pattern = r"(?<![\w.-])" + re.escape(base) + r"(?![\w-])"
        if base.endswith(".py"):
            pattern += r"|\b(?:import|from)\s+" + re.escape(base[:-3].replace("-", "_")) + r"\b"
        names[path] = re.compile(pattern)
    reached, waiting = set(), list(starts)
    while waiting:
        text = waiting.pop()
        for path, pattern in names.items():
            if path not in reached and pattern.search(text):
                reached.add(path)
                waiting.append(scripts[path])
    return reached


def out_of_reach():
    """A pattern for the paths under scripts/ that the macOS job cannot reach. If that cannot be told, for none."""
    try:
        reached = reach(*checkout())
    except (Unclear, OSError):
        return re.compile(r"(?!)")
    return re.compile(r"^scripts/(?!(?:%s)$)" % "|".join(re.escape(path[len("scripts/"):]) for path in sorted(reached)))


def api(path, jq, paginate=False):
    """The parsed results of `jq` over a GET request, one per page."""
    command = ["gh", "api", path, "--jq", jq] + (["--paginate"] if paginate else [])
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise Unclear(f"{path}: {(result.stderr or result.stdout).strip()[:200]}")
    return [json.loads(line) for line in result.stdout.splitlines() if line.strip()]


def files_of_pull_request(repo, number):
    pages = api(f"repos/{repo}/pulls/{number}/files?per_page=100", NAMES, paginate=True)
    return [name for page in pages for name in page]


def files_between(repo, base, head):
    if base == head:
        return []
    [answer] = api(f"repos/{repo}/compare/{base}...{head}", f"{{count: (.files | length), names: (.files | {NAMES})}}")
    if answer["count"] >= LISTED_AT_MOST:
        raise Unclear(f"{base[:7]}...{head[:7]} changes {LISTED_AT_MOST} files or more")
    return answer["names"]


def recent_commits(repo, head):
    [commits] = api(f"repos/{repo}/commits?sha={head}&per_page={LOOK_BACK}", "[.[].sha]")
    return commits


def succeeded(repo, sha):
    """The names of the checks that have succeeded at that commit."""
    [names] = api(f"repos/{repo}/commits/{sha}/check-runs?per_page=100", '[.check_runs[] | select(.conclusion == "success") | .name] | unique')
    return names


def passed_on_a_mac(repo, sha, check):
    """Whether the macOS job passed there, and the jobs that speak for it did."""
    names = succeeded(repo, sha)
    return all(name in names for name in (check, *WITH_IT))


def subject(repo, sha):
    [commit] = api(f"repos/{repo}/commits/{sha}", "{message: .commit.message}")
    return (commit["message"].splitlines() or [""])[0]


def beyond(names, *kinds):
    """The names that none of the patterns covers."""
    return sorted({name for name in names if not any(kind.search(name) for kind in kinds)})


def some(names):
    return ", ".join(names[:4]) + (f" and {len(names) - 4} more" if len(names) > 4 else "")


def decide(name, event, repo, sha):
    """How the Mac runs (UPON, FRESH or FULL), or None when it is not needed at all, and why."""
    if name == "pull_request":
        pull = event["pull_request"]
        head, whole = pull["head"]["sha"], "the pull request"
        integration = pull["head"].get("ref") == INTEGRATION_BRANCH or pull.get("base", {}).get("ref") == MAIN
        changed = lambda: files_of_pull_request(repo, pull["number"])
        labels = {label.get("name") for label in pull.get("labels", [])}
        draft = bool(pull.get("draft"))
    elif name == "push":
        head, whole, integration, labels, draft = sha, "the push", True, set(), False
        train = event.get("ref", "").startswith(TRAINS)
        changed = lambda: files_between(repo, INTEGRATION_BRANCH if train else event["before"], head)
    elif name == "schedule":
        return FULL, "every night: every test, built from nothing, as a backstop"
    else:
        return FULL, f"there is no rule for {name} events: every test, built from nothing"
    if FULL_LABEL in labels:
        return FULL, f'{ASKED_FOR}: the pull request has the label "{FULL_LABEL}"'
    words = subject(repo, head)
    if FULL_MARKER in words:
        return FULL, f"{ASKED_FOR}: the head commit's subject says {FULL_MARKER}"

    try:
        names = changed()
    except Unclear:
        names = []  # a new branch has no commit before it, say; the last rule may still apply
    how = FRESH if integration else UPON
    prose = (PROSE, out_of_reach())
    if LABEL in labels:
        return how, f'{ASKED_FOR}: the pull request has the label "{LABEL}"; {HOW[how]}'
    if MARKER in words:
        return how, f"{ASKED_FOR}: the head commit's subject says {MARKER}; {HOW[how]}"
    # Whoever asks for a Mac above gets one, on a draft too: a probe stays possible.
    if draft:
        return None, "a draft: the Mac runs when its author marks it ready for review, or when the label or the marker asks for it"
    if names and not beyond(names, *prose):
        return None, f"{whole} changes only prose, data that the Linux job checks too, and scripts the macOS job cannot reach"
    if names and not integration and not beyond(names, *prose, HEADLESS):
        return None, f"{whole} changes only code that Linux builds and tests too; a Mac sees it when it is integrated"

    check, passed = (FRESH_CHECK, "passed, built from nothing") if integration else (CHECK, "passed")
    for commit in recent_commits(repo, head):
        if passed_on_a_mac(repo, commit, check):
            since = beyond(files_between(repo, commit, head), *prose)
            if since:
                return how, f"changed since {commit[:7]} {passed}: {some(since)}; {HOW[how]}"
            return None, f"nothing a Mac could check has changed since {commit[:7]} {passed}"
    if not names:
        return FULL, f"it is unclear what changed, and none of the last {LOOK_BACK} commits has {passed} on a Mac: every test, built from nothing"
    what = some(beyond(names, *prose) if integration else beyond(names, *prose, HEADLESS))
    return how, f"changed: {what}; none of the last {LOOK_BACK} commits has {passed} on a Mac; {HOW[how]}"


def answers(how, reason):
    """The lines for $GITHUB_OUTPUT. The reason quotes file names, which anyone can choose: it stays on one line, and
    comes first, so that no name can add an answer of its own or have the last word."""
    tests = {None: "none", UPON: "mac-only", FRESH: "mac-only"}.get(how, "full")
    build = {None: "none", UPON: "upon"}.get(how, "from-nothing")
    return [f"why={' '.join(reason.split())}", f"tests={tests}", f"build={build}", f"mac={'true' if how else 'false'}"]


def main():
    try:
        with open(os.environ["GITHUB_EVENT_PATH"], encoding="utf-8") as handle:
            event = json.load(handle)
        how, reason = decide(
            os.environ["GITHUB_EVENT_NAME"], event, os.environ["GITHUB_REPOSITORY"], os.environ.get("GITHUB_SHA", "")
        )
    except Exception as error:  # whatever went wrong, running the Mac, and every test on it, is the safe answer
        how, reason = FULL, f"could not tell what changed ({type(error).__name__}: {error})"

    lines = answers(how, reason)
    if "GITHUB_OUTPUT" in os.environ:
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
    print("\n".join(reversed(lines[1:])))
    message = f"{'runs' if how else 'skipped'}: {lines[0][len('why='):]}".replace("%", "%25")
    print(f"::notice title=macOS job::{message}")


if __name__ == "__main__":
    sys.exit(main())
