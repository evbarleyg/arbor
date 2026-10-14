#!/usr/bin/env python3
"""Decides whether a CI run needs its macOS job, the slow and scarce one.

A Mac is left out when it could prove nothing new, or nothing that will not be proved soon anyway:

  1. everything the pull request changes (for a push: everything since the commit before it) is
     prose, or data the Linux job checks just as well: collab/, docs/, *.md, scripts/typecheck-mac/ (which
     only Linux runs), and the scripts in scripts/mac-shell/ that CI does not run (it runs e2e-drag.sh, and
     with it lib.sh and its tools; and `swift test` on a Mac type-checks every helper tool there, *.swift and *.m);
  2. or, in an ordinary pull request, all the rest of it is code that also builds and is tested on
     Linux (the core, the controller, the platform protocols, the fakes, arbor-sim, the tests);
  3. or only prose has changed since the nearest earlier commit that passed the macOS job. That covers
     the report pushed after the code, and a branch moving forward to the tested head of a pull
     request, where nothing changed at all.

Rule 2 can let through a change that breaks the macOS-only code which uses it. So it does not apply where
work is integrated: pushes to `main`, and the pull request whose head is the swarm's trunk. There every
change of code is compiled and driven on a real Mac.

"[mac]" in the subject of the head commit, or the label "mac" on the pull request, asks for the Mac
whatever changed. When anything is unclear (a call fails, a comparison is too large to
list), it runs.

Reads the event from the environment GitHub Actions provides. Needs `gh` and a token that may read
contents, pull requests and checks. Appends `mac=true` or `mac=false` to $GITHUB_OUTPUT and publishes
the reason as a check annotation. To try it by hand:

  gh api repos/evbarleyg/arbor/pulls/10 --jq '{pull_request: .}' > /tmp/event.json
  GITHUB_EVENT_NAME=pull_request GITHUB_EVENT_PATH=/tmp/event.json GITHUB_REPOSITORY=evbarleyg/arbor \\
    scripts/ci-changes.py
"""

import json
import os
import re
import subprocess
import sys

PROSE = re.compile(r"^(collab|docs|scripts/typecheck-mac)/|^scripts/mac-shell/(?!(e2e-drag\.sh|lib\.sh|state\.py|.*\.swift|.*\.m)$)|\.md$")
# What Package.swift builds on Linux too. Anything in neither list needs a Mac.
HEADLESS = re.compile(
    r"^(Sources/(ArborCore|ArborKit/(Controller|Platform|Support|Trace)|ArborTesting|arbor-sim|LinuxShims)|Tests)/"
)
INTEGRATION_BRANCH = "swarm/trunk"
MARKER = "[mac]"
LABEL = "mac"
ASKED_FOR = "asked for"
# How many commits back to look for one that passed.
LOOK_BACK = 10
# The comparison API lists at most this many files and does not say when it left some out.
LISTED_AT_MOST = 300
# A renamed file counts under both of its names.
NAMES = "[.[] | .filename, (.previous_filename // empty)]"


class Unclear(Exception):
    pass


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


def passed_on_a_mac(repo, sha):
    [passed] = api(
        f"repos/{repo}/commits/{sha}/check-runs?check_name=macos&per_page=100",
        '[.check_runs[].conclusion] | any(. == "success")',
    )
    return passed


def subject(repo, sha):
    [commit] = api(f"repos/{repo}/commits/{sha}", "{message: .commit.message}")
    return (commit["message"].splitlines() or [""])[0]


def beyond(names, *kinds):
    """The names that none of the patterns covers."""
    return sorted({name for name in names if not any(kind.search(name) for kind in kinds)})


def some(names):
    return ", ".join(names[:4]) + (f" and {len(names) - 4} more" if len(names) > 4 else "")


def decide(name, event, repo, sha):
    """Whether the Mac is needed, and why."""
    if name == "pull_request":
        pull = event["pull_request"]
        head, whole = pull["head"]["sha"], "the pull request"
        integration = pull["head"].get("ref") == INTEGRATION_BRANCH
        changed = lambda: files_of_pull_request(repo, pull["number"])
        if any(label.get("name") == LABEL for label in pull.get("labels", [])):
            return True, f'{ASKED_FOR}: the pull request has the label "{LABEL}"'
    elif name == "push":
        head, whole, integration = sha, "the push", True
        changed = lambda: files_between(repo, event["before"], head)
    else:
        return True, f"there is no rule for {name} events"
    if MARKER in subject(repo, head):
        return True, f"{ASKED_FOR}: the head commit's subject says {MARKER}"

    names = []
    try:
        names = changed()
        if names and not beyond(names, PROSE):
            return False, f"{whole} changes only prose and data that the Linux job checks too"
        if names and not integration and not beyond(names, PROSE, HEADLESS):
            return False, f"{whole} changes only code that Linux builds and tests too; a Mac sees it when it is integrated"
    except Unclear:
        pass  # a new branch has no commit before it, say; the last rule may still apply

    for commit in recent_commits(repo, head):
        if passed_on_a_mac(repo, commit):
            since = beyond(files_between(repo, commit, head), PROSE)
            if since:
                return True, f"changed since {commit[:7]} passed: {some(since)}"
            return False, f"nothing a Mac could check has changed since {commit[:7]} passed"
    what = some(beyond(names, PROSE) if integration else beyond(names, PROSE, HEADLESS)) or "unknown"
    return True, f"changed: {what}; none of the last {LOOK_BACK} commits has passed on a Mac"


def main():
    try:
        with open(os.environ["GITHUB_EVENT_PATH"], encoding="utf-8") as handle:
            event = json.load(handle)
        needed, reason = decide(
            os.environ["GITHUB_EVENT_NAME"], event, os.environ["GITHUB_REPOSITORY"], os.environ.get("GITHUB_SHA", "")
        )
    except Exception as error:  # whatever went wrong, running the Mac is the safe answer
        needed, reason = True, f"could not tell what changed ({type(error).__name__}: {error})"

    answer = f"mac={'true' if needed else 'false'}"
    if "GITHUB_OUTPUT" in os.environ:
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as handle:
            handle.write(answer + "\n")
    print(answer)
    message = f"{'runs' if needed else 'skipped'}: {reason}".replace("%", "%25").replace("\n", "%0A")
    print(f"::notice title=macOS job::{message}")


if __name__ == "__main__":
    sys.exit(main())
