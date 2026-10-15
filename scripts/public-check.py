#!/usr/bin/env python3
"""Keeps what is private out of a public repository, before it is pushed and again in CI.

Whatever is pushed or posted here can be read, copied and indexed by anybody, for good: deleting it later takes it out of
sight, not out of the world. People and agents work on Arbor from machines of their own, with notes of their own, and
what slips in is seldom a secret key. It is a link to somebody's working session, a path with a user's name in it, a
sentence about one person's Mac. Those were looked for by hand; this looks for them every time.

It checks two things.

  History   Everything being pushed goes back to the repository's first public commit and to no other beginning (a clone
            can hold history from elsewhere), and every new commit and tag was made under a no-reply address. As the hook it also
            keeps `main` and `swarm/trunk` of the repository itself for whoever lands work there, and only ever moving forward.
  Words     The lines, file names, commit messages, authors' names, branch and tag names that are new. RULES below says
            what is looked for and what to write instead. Each new commit is read by itself, merges too: what one commit
            adds and the next takes out again is still in the history.

The rules name kinds of things, never the things themselves, so that reading this file teaches nobody anything: any host
the project has not linked to before, not a list of hosts to avoid; the name in LICENSE, read from LICENSE; this
machine's own ids, read from its environment. There is no list of forbidden words here, not even in disguise. Words no
kind covers go, one to a line, in a file of your own outside the repository (`git config arbor.privateWords <path>`), or
in $PUBLIC_CHECK_WORDS. Honest exceptions are in public-check.allow, each with its reason. They belong to the commit: what is pushed or
compared is held to the exceptions it carries itself, wherever the clone happens to stand.

Usage: scripts/public-check.py             what this branch adds to origin's main and swarm/trunk (`make public-check`)
       … --base REF [--head REF] [--branch NAME] [--tag NAME]   what REF..head adds (head: HEAD); CI's way. For swarm/trunk less what origin's
                                           main has, for any branch but those two less what either has: that was read when it got there
       … --pre-push [--to URL]             as git's pre-push hook, which says on standard input what is being pushed; where to is
                                           in $PUBLIC_CHECK_TO or after --to, or else the remote's name in $PUBLIC_CHECK_REMOTE
       … --rules                           only whether the rules have changed since this clone last said it had read them (below)
       … --text [FILE…]                    free text, from standard input without a file: read a pull request's body or a
                                           comment through this BEFORE posting it
       … --tree                            every file at HEAD, old and new: a row of `make lint`
       … --unread [--begin] [--branch B]   which branches and tags of the public repository stand where no hook has read them (below)
       … --mask                            print findings without the words found (always so in GitHub Actions, whose
                                           logs and annotations are as public as the repository)

Rules that change. Agents who work to a brief kept outside the repository are deep in long work when a rule changes, and a message does
not reach them until they look up. So the change is enforced where the act happens. Beside the file of private words lies
`rules-version.txt`; its first line is a number, a time, and a sentence on what changed and what to read again. The hook compares the
number with `git config arbor.rulesRead` and refuses the push while they differ. No such file, as in a stranger's clone: not a word.

Pushes nobody read. All of this guards only a clone in which `make hooks` has been said, and nothing in a push tells whether it came from one. So
the hook leaves a note of each branch and tag it has read on its way to the public repository: a small file named after the commit and the ref, in
the folder `pushes-read` beside the private words, which is to lie outside every clone: nothing goes into commits. What it reads is all that main and the
trunk do not hold, whatever other branch has it already, so a push upon one that nobody read hides nothing. `--unread` asks the public repository where its branches and tags stand and names those for which there is no
note, or tells of one with `--branch`. `--unread --begin` names them, writes them down as they stand and ends with 0: at the beginning, for what was pushed
before there was a record, and later, with `--branch`, for what somebody has looked at. It is a way to notice, not a lock: whoever can write to
the folder can write a note, a branch that is gone again before anybody asks is not seen, and what is called as workflows call theirs is left out.

Exit code 0 when nothing was found, 1 when something was, 2 when it could not tell.
scripts/test-public-check.py holds it to a table of situations; `make lint` runs that.
"""

import argparse
import bisect
import datetime
import fnmatch
import hashlib
import json
import os
import re
import socket
import subprocess
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
# Raise it whenever the check gets stricter or a hole in it is mended. The hook has two copies to choose from, the one `make hooks` kept
# and the one on the branch that is checked out, and lets the newer do the reading.
VERSION = 10
# The first public commit. All history begins here.
ROOT_COMMIT = "51b162d5f28c02846134c1f4a113c787f5164602"
# Where work is integrated: what these hold on origin has been read before. In this order: see read_elsewhere.
INTEGRATION = ("main", "swarm/trunk")
# The public repository itself, under whatever name a clone knows it.
UPSTREAM = re.compile(r"github\.com(:\d+)?[:/]+evbarleyg/arbor(\.git)?/?$", re.IGNORECASE)  # ssh.github.com:443 is GitHub's too
NO_REPLY = re.compile(r"^([\w.+\[\]-]+@users\.noreply\.github\.com|noreply@github\.com)$")
MASK = "▒▒▒"
# A little more than the newest number passes: a branch is pushed before its pull request has one, others are opened
# meanwhile, and git by itself can only ask the remote for pull requests, not for issues.
NUMBER_SLACK = 15
ZERO = re.compile(r"^0+$")
# What GitHub takes, in the message of the newest commit of a push, for a wish that no workflow be started.
NO_RUN = re.compile(r"\[(skip ci|ci skip|no ci|skip actions|actions skip)\]|^skip-checks:\s*true", re.IGNORECASE | re.MULTILINE)


class Unclear(Exception):
    pass


# MARK: the rules

def rule(name, why, pattern, flags=re.IGNORECASE):
    return (name, why, re.compile(pattern, flags))


# A letter and a number also name board items and probes (B2, H4), which are welcome. It takes the words around them to
# tell that somebody is meant.
ROLE = r"(?:B1?\d|H1?\d|R\d|T[1-5]|S[1-4]|C[1-3])"
SAID = r"session|said|says|found|finds|owns|asked|asks|reported|reports|agreed|stopped|reviewed|landed|merged|wrote"

# Where a pattern has a group, the group is the find.
RULES = [
    rule("session", "an id of, or a link to, somebody's working session: leave it out; the generic https://claude.ai/code is fine",
         r"(?<![A-Za-z])[a-z]{2,16}_01[0-9A-Za-z]{16,}\b|claude\.ai/(?!code(?![\w/?#]))[\w/?#=&%.-]+"),
    rule("host", "a host this repository has not linked to before: an internal one must go; a public one that is needed gets a "
         "line in scripts/public-check.allow",
         r"\b(?:https?|wss?|ssh|git|ftp)://(?:[^@\s/]*@)?([a-z0-9-]+(?:\.[a-z0-9-]+)*)"
         r"|(?<![a-z0-9.-])(?:[a-z0-9-]+\.)+(?:dev|internal|corp|lan|intranet)\b(?!\()|(?<![\w/.:-])go/[a-z][a-z0-9-]+\b"),
    rule("email", "an e-mail address: only no-reply addresses and example.com belong here",
         r"(?<![\w.+-])[\w.+-]+@(?:[a-z0-9-]+\.)+[a-z]{2,}\b"),
    rule("home", "a path on one particular machine: write ~/…, /Users/you/… or a path inside the repository",
         r"(?<![\w.~-])/(?:Users|home)/(?!(?:runner|Shared|you)(?![\w.-]))[\w.-]+|(?<![\w.~-])/(?:root|mnt|media)/[\w.-]+"
         r"|/var/folders/\w|/Volumes/(?!Arbor)[\w.-]+|(?<![\w.~-])/tmp/claude[\w.-]*"),
    rule("person", "speaks of one particular person: say \"the maintainer\", \"a tester\", \"they\"; nothing about anybody's own Mac, "
         "apps, days or work",
         r"\b(?:he|He|HE|she|She|SHE)(?= [A-Za-z]|['’](?:s|d|ll)\b)|\b(?:him|Him|HIM|his|His|HIS|her|Her|HER|hers|Hers|HERS)\b"
         r"|(?<![Pp]roduct )\b(?:[Oo]wner|OWNER|[Mm]aintainer|MAINTAINER)['’]?[sS] (?:own |OWN )?(?i:mac\w*|laptop|machine|computer|desk|display|monitor"
         r"|screen|apps?|settings|account|calendar|schedule|time ?zone|employer|job)\b"
         r"|\b(?i:employer|pacific time)\b|\b\d{1,2}(?::\d\d)? ?(?:[AaPp]\.?[Mm]\.?) ?(?:PT|PST|PDT|ET|EST|EDT|CET|CEST)\b",
         0),
    rule("money", "a word on what things cost or who pays: leave it out; \"free hosted runners\" says all the public needs",
         r"\b(?:billing|spending (?:limit|cap)s?|allowance|invoice[sd]?|usage limits?|unlimited budget|(?:token|dollar|monthly|money) budget"
         r"|out of (?:credits|minutes)|costs? (?:ten|\d+) times)\b|\$\d+\.\d\d\b|\b\d+ ?(?:USD|EUR|dollars|euros)\b"),
    rule("model", "names a model or its maker: \"an agent\" or \"Claude Code\" says enough",
         r"\b(?:anthropic|openai|deepmind|gemini|gpt-?\d[\w.-]*|opus|sonnet|haiku|llama|mistral|copilot)\b"
         r"|(?<![\w-])claude[- ](?!code\b)(?:[a-z]+-)*v?\d[\w.-]*"),
    rule("role", "a role of the private phase, which means nothing to a reader here: say what the thing does, or who in plain words "
         "(\"a reviewer\", \"the product owner\")",
         r"\b" + ROLE + r"(?:['’]s\b| (?:" + SAID + r")\b)|\b(?:session|environment|lane|conductor|reviewer|builder|executor|owner:?) "
         + ROLE + r"\b|\b[Tt]he integrator\b|\b[Rr]elease manager\b|\bFRESH EYES\b|\bTRIAGE\b"
         r"|\bexecutor [LMS]\b", 0),
]
NAME_WHY = "the name in LICENSE belongs in LICENSE: say \"the maintainer\""
NUMBER_WHY = "no issue or pull request here has this number yet, so it is one of the private phase: say what the thing does"
REPOSITORY_WHY = "another repository of the same owner: whether there is one is nobody's business here"
HERE_WHY = "this very machine's or session's own"
PRIVATE_WHY = "a word on a private list (git config arbor.privateWords, or PUBLIC_CHECK_WORDS in the environment)"
OTHER_RULES = ("name", "number", "repository", "here", "private")
# Where something was found, when it was not in a file.
NO_FILE = ("message", "author", "branch", "tag", "path", "text")
NUMBER = re.compile(r"(?<![\w&/#])#(\d{1,4})\b")
# Names of environment variables whose values say which machine, session or person this is, or open a door.
TELLING = re.compile(r"_?(ID|UUID|TOKEN|KEY|SECRET|PASSWORD)$|EMAIL|HOSTNAME$|^HOME$")
# Shorter values turn up by chance.
TELLING_LENGTH = 8
# Values any machine may have.
ORDINARY = {"/home/runner", "/users/runner", "/github/home", "localhost"}


def is_colour(line, number):
    """`border: 1px solid #333;` is no reference to anything."""
    if len(number.group(1)) != 3 or line[number.end():number.end() + 1] != ";":
        return False
    return ": " in line[line.rfind(";", 0, number.start()) + 1:number.start()]


def read_lines(path):
    """The lines of a list that are neither empty nor remarks. A list that was asked for and cannot be read is no empty list."""
    try:
        with open(path, encoding="utf-8") as handle:
            lines = [line.strip() for line in handle]
    except OSError as error:
        raise Unclear(f"{path} cannot be read ({error.strerror}), and without it something would be missed") from error
    return [line for line in lines if line and not line.startswith("#")]


def names_in(licence):
    """The parts of the copyright holder's name, as a pattern. Also as a possessive, and in a branch's name."""
    found = re.search(r"^Copyright \(c\) \d{4}(?:-\d{4})? (.+)$", licence, re.MULTILINE)
    parts = [part for part in re.split(r"[\s-]+", found.group(1)) if len(part) >= 4] if found else []
    if not parts:
        return None
    return re.compile(r"(?<![A-Za-z])(?:" + "|".join(map(re.escape, parts)) + r")(?:['’]?s)?(?![A-Za-z])", re.IGNORECASE)


def told_by_this_machine(environment, hostname):
    """What this machine would give away about itself: value → the name it goes by."""
    values = {hostname: "host name"} if hostname else {}
    for name, value in environment.items():
        if TELLING.search(name):
            values[value] = name
    # Not a no-reply address: it is what commits are meant to carry, trailers too. Not numbers: an account's or a run's number is in
    # every address and link GitHub makes of it, for all to see.
    return {value: name for value, name in values.items()
            if len(value) >= TELLING_LENGTH and value.lower() not in ORDINARY and not NO_REPLY.match(value) and not value.isdigit()}


def blanked(line, spans, first=0, last=None):
    """line[first:last] with the spans, which are in order and apart, blanked out."""
    last = len(line) if last is None else last
    text, at = "", first
    for start, end in spans[max(0, bisect.bisect_left(spans, (first, 0)) - 1):]:
        if start >= last:
            break
        if end > at:
            text += line[at:max(at, start)] + MASK
            at = end
    return text + line[at:max(at, last)]


def merged(spans):
    """The spans in order, with those that overlap made one."""
    whole = []
    for start, end in sorted(spans):
        if whole and start <= whole[-1][1]:
            whole[-1] = (whole[-1][0], max(end, whole[-1][1]))
        else:
            whole.append((start, end))
    return whole


class Finding:
    def __init__(self, where, number, name, why, line, start, end):
        self.where, self.number, self.rule, self.why, self.line, self.start, self.end = where, number, name, why, line, start, end
        self.source = None  # the commit, tag or file it is in
        self.unfit = [(start, end)]  # everything in the line that is not fit to be repeated

    def excerpt(self, masked):
        """The line, cut to what surrounds the find."""
        first, last = max(0, self.start - 70), min(len(self.line), self.end + 70)
        if masked:
            middle = blanked(self.line, self.unfit, first, last)
        else:
            middle = self.line[first:self.start] + f"»{self.line[self.start:self.end]}«" + self.line[self.end:last]
        return ("…" if first else "") + middle + ("…" if last < len(self.line) else "")


class Checker:
    """The rules with the lists that go with them."""

    def __init__(self, allowed=(), licence="", highest=None, owner=None, here=None, private=()):
        self.allowed = []
        for line in allowed:
            fields = line.split(None, 2)
            if len(fields) != 3:
                raise Unclear(f"public-check.allow: three fields are wanted (rules, where, what), got: {line}")
            self.allowed.append((fields[0].split(","), fields[1], re.compile(fields[2], re.IGNORECASE)))
        self.highest = highest
        self.more = [(names_in(licence), "name", NAME_WHY)]
        if owner:
            self.more.append((re.compile(r"(?<![\w.-])" + re.escape(owner) + r"/[\w.-]*\w", re.IGNORECASE), "repository", REPOSITORY_WHY))
        self.more += [(re.compile(re.escape(value)), "here", f"{HERE_WHY} {what}") for value, what in (here or {}).items()]
        self.more += [(re.compile(re.escape(word), re.IGNORECASE), "private", PRIVATE_WHY) for word in private]

    def is_allowed(self, name, where, found):
        return any(name in rules and fnmatch.fnmatchcase(where, glob) and what.fullmatch(found) for rules, glob, what in self.allowed)

    def spans(self, line):
        """Every find in one line: rule, why, start, end."""
        for name, why, pattern in RULES:
            for match in pattern.finditer(line):
                yield (name, why, *match.span(match.lastindex or 0))
        for pattern, name, why in self.more:
            for match in pattern.finditer(line) if pattern else ():
                yield name, why, match.start(), match.end()
        if self.highest is not None:
            for match in NUMBER.finditer(line):
                if int(match.group(1)) > self.highest and not is_colour(line, match):
                    yield "number", NUMBER_WHY, match.start(), match.end()

    def check(self, where, text, first_line=1, numbered=True):
        """The findings in a text of one or more lines. `where` is a path or one of NO_FILE."""
        findings = []
        for offset, line in enumerate(text.split("\n")):
            unfit, before, taken = [], len(findings), bytearray(len(line))
            for name, why, start, end in self.spans(line):
                if self.is_allowed(name, where, line[start:end]):
                    continue
                # One finding per place: an address at a maker's host is an address, not also a maker and a host.
                if taken.find(1, start, end) < 0:
                    findings.append(Finding(where, first_line + offset if numbered else None, name, why, line, start, end))
                taken[start:end] = b"\1" * (end - start)
                unfit.append((start, end))
            unfit = merged(unfit)
            for finding in findings[before:]:
                finding.unfit = unfit
        return findings

    def fit_to_print(self, where, name):
        """A file's, a branch's or a tag's name as it may be repeated in public."""
        return blanked(name, merged(span for finding in self.check(where, name.replace("\n", " ")) for span in finding.unfit))


# MARK: git

def git(*arguments, cwd=None, check=True, said=None):
    """git's output; with check=False its exit code too. `said` goes to its standard input."""
    # History as it is, not as `git replace` makes it look: a push sends the real objects.
    result = subprocess.run(["git", "-c", "core.quotepath=off", *arguments], cwd=cwd, capture_output=True, text=True, input=said,
                            errors="replace", check=False, env=dict(os.environ, GIT_NO_REPLACE_OBJECTS="1"))
    if check and result.returncode != 0:
        raise Unclear(f"git {' '.join(arguments[:3])}…: {result.stderr.strip()[:300]}")
    return result.stdout if check else (result.returncode, result.stdout)


def history_problems(head, cwd=None):
    """Why `head` may not be pushed, going by where its history begins."""
    if git("rev-parse", "--is-shallow-repository", cwd=cwd).strip() == "true":
        raise Unclear("this clone is shallow, so nobody can tell where its history begins: git fetch --unshallow origin")
    grafts = os.path.join(cwd or ".", git("rev-parse", "--git-common-dir", cwd=cwd).strip(), "info", "grafts")
    if os.path.exists(grafts):
        raise Unclear(f"{grafts} makes history look other than it is, so nobody can tell where it begins: remove the file")
    roots = git("rev-list", "--max-parents=0", head, cwd=cwd).split()
    foreign = [root for root in roots if root != ROOT_COMMIT]
    way_out = "Start again from origin's branch (git checkout -b <name> origin/swarm/trunk) and bring the work over as a patch you have read"
    if ROOT_COMMIT not in roots:
        return [f"{head[:12]} does not descend from the first public commit, {ROOT_COMMIT[:8]}: it is history from somewhere else. {way_out}"]
    if foreign:
        return [f"{head[:12]} also goes back to {', '.join(root[:8] for root in foreign)}: history from somewhere else was merged in. {way_out}"]
    return []


def unquoted(name):
    """A file's name as `git diff` writes it after `+++ `: in quotes, C's way, if it holds a quote, a backslash or a control character."""
    if not name.startswith('"'):
        return name[:-1] if name.endswith("\t") else name  # a tab closes a name with a space in it
    simple = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}
    return re.sub(r"\\([0-7]{3}|.)", lambda found: simple.get(found.group(1)) or chr(int(found.group(1), 8)), name[1:-1])


HUNK = re.compile(r"^@@ -\S+ \+(\d+)(?:,\d+)? @@")
GONE = object()


def added_lines(patches):
    """(commit, path, line number, text) for every line that `git log --patch` shows as added."""
    commit = path = None
    number = 0
    for line in patches.split("\n"):
        if line.startswith("\0commit "):
            commit, path = line[8:], None
        elif line.startswith("diff --git "):
            path = None
        elif path is None:  # a file's heading, up to its `+++`
            if line.startswith("+++ "):
                name = unquoted(line[4:])
                if name != "/dev/null" and not name.startswith("b/"):
                    raise Unclear("git names a file in a way this check does not know")
                path = GONE if name == "/dev/null" else name[2:]
            elif line.startswith("@@"):
                raise Unclear("git shows changed lines without saying which file they are in")
        elif line.startswith("@@"):
            found = HUNK.match(line)
            if not found:
                raise Unclear("git heads a group of changed lines in a way this check does not know")
            number = int(found.group(1))
        elif line.startswith("+") and path is not GONE:
            yield commit, path, number, line[1:]
            number += 1


# A merge is shown as what it changes about the merge git would have made by itself. The rest keeps a person's own
# settings for git from changing what the output looks like.
DIFF = ("--diff-merges=remerge", "--find-renames", "--no-color", "--no-ext-diff", "--no-textconv", "--src-prefix=a/", "--dst-prefix=b/")
ADDRESS_WAY_OUT = "Set yours (git config user.email <id>+<login>@users.noreply.github.com) and make it again"


def check_range(checker, selection, head, cwd=None):
    """History, authors, messages, new file names and added lines of the commits in `selection` (arguments for git rev-list)."""
    problems = history_problems(head, cwd)
    findings, seen = [], set()

    def keep(found, source, key):
        for finding in found:
            if (key, finding.rule, finding.line) not in seen:
                seen.add((key, finding.rule, finding.line))
                finding.source = source
                findings.append(finding)

    log = git("log", "--reverse", "--format=%H%x00%an%x00%ae%x00%cn%x00%ce%x00%B%x01", *selection, cwd=cwd)
    commits = [entry.strip("\n").split("\0", 5) for entry in log.split("\x01") if entry.strip()]
    for sha, author, author_address, committer, committer_address, message in commits:
        for who, address in (("author", author_address), ("committer", committer_address)):
            if not NO_REPLY.match(address):
                problems.append(f"commit {sha[:8]}: its {who}'s address is no no-reply address. {ADDRESS_WAY_OUT}")
        if NO_RUN.search(message):
            problems.append(f"commit {sha[:8]}: its message asks GitHub to start no run for the push, and then nothing reads the push there. Make it again without those words")
        keep(checker.check("author", f"{author}\n{committer}", numbered=False), sha[:8], "author")
        keep(checker.check("message", message), sha[:8], sha)
    if commits:
        names = git("log", "--format=", "--name-only", "--diff-filter=ACR", "-z", *DIFF, *selection, cwd=cwd)
        for name in sorted(set(filter(None, names.split("\0")))):
            keep(checker.check("path", name, numbered=False), None, "path")
        patches = git("log", "--reverse", "--format=%x00commit %h", "--patch", "--unified=0", *DIFF, *selection, cwd=cwd)
        for commit, path, number, text in added_lines(patches):
            keep(checker.check(path, text, number), commit, path)
    return problems, findings, len(commits)


def check_tag(checker, name, cwd=None):
    """The name of a tag and, if it is more than a name, who made it and what they wrote."""
    problems, findings = [], checker.check("tag", name, numbered=False)
    ref = f"refs/tags/{name}"
    if git("cat-file", "-t", ref, cwd=cwd, check=False)[1].strip() == "tag":
        tagger, address, message = git("for-each-ref", "--format=%(taggername)%00%(taggeremail:trim)%00%(contents)", ref, cwd=cwd).split("\0", 2)
        if not NO_REPLY.match(address):
            problems.append(f"the tag's maker's address is no no-reply address. {ADDRESS_WAY_OUT}")
        findings += checker.check("author", tagger, numbered=False) + checker.check("message", message)
    for finding in findings:
        finding.source = "the tag's" if finding.where != "tag" else None
    return problems, findings


def first_commit_if_here(cwd=None):
    return [ROOT_COMMIT] if git("cat-file", "-e", ROOT_COMMIT + "^{commit}", cwd=cwd, check=False)[0] == 0 else []


def public_already(top, read=False):
    """What need not be read again, as arguments for git rev-list: what the public repository is known to have, and the remote being pushed
    to (the hook says which, in $PUBLIC_CHECK_REMOTE). NOT what any other remote has: a clone that also knows a private place is the very
    clone this check is for, and what lies there is new to the public however long this clone has had it.
    `read`: only what was read on its way there, which is what main and the trunk hold. Any other branch may have come from a clone without the hook."""
    names = {os.environ.get("PUBLIC_CHECK_REMOTE", "")}
    for line in git("remote", "--verbose", cwd=top).splitlines():
        name, _, rest = line.partition("\t")
        if UPSTREAM.search(rest.rsplit(" ", 1)[0]):
            names.add(name)
    known = set(git("remote", cwd=top).split())
    # Where the history begins is checked apart from this, so remote-tracking refs from somewhere else under a good name gain nothing.
    if read:
        integrated = [f"refs/remotes/{name}/{branch}" for name in sorted(names & known) for branch in INTEGRATION]
        return [ref for ref in integrated if git("rev-parse", "--verify", "--quiet", ref, cwd=top, check=False)[0] == 0] + first_commit_if_here(top)
    return [f"--remotes={name}/*" for name in sorted(names & known)] + first_commit_if_here(top)


def read_elsewhere(branch, cwd=None):
    """With --base: what else need not be read, as arguments for git rev-list. What main or swarm/trunk holds was read by the run for the
    push that brought it there, and that run said what is wrong with it. The same words once more, in every pull request that holds the
    commit and when the trunk takes main in, tell nobody anything and cannot be put right there.

    Each of those two leaves out only the ones before it in INTEGRATION, so main leaves out nothing: it reads all that is new to it, whatever
    the trunk has. Were it each the other, a commit that reaches both within the minute a run takes to start would be left out by both.
    Nothing else counts, no plain branch of origin's, no tag, no other remote: that is where a commit waits to be read.

    It rests on every push to those two getting its run. So a message that asks GitHub for none is refused (NO_RUN), and one of them pushed
    anew or by force is read from the start (main() below). A run that ends early for another reason is red, and is to be run again."""
    if not branch or branch == "HEAD":  # nobody said what this is: it is read as asked
        return []
    names = INTEGRATION[:INTEGRATION.index(branch)] if branch in INTEGRATION else INTEGRATION
    return [f"^refs/remotes/origin/{name}" for name in names if git("rev-parse", "--verify", "--quiet", f"refs/remotes/origin/{name}", cwd=cwd, check=False)[0] == 0]


def highest_number(cwd=None):
    """The highest number an issue or pull request may be referred to by; None when nobody can be asked."""
    if os.environ.get("PUBLIC_CHECK_HIGHEST", "").isdigit():
        return int(os.environ["PUBLIC_CHECK_HIGHEST"])
    repository, token = os.environ.get("GITHUB_REPOSITORY"), os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if repository and token:
        try:
            request = urllib.request.Request(
                f"https://api.github.com/repos/{repository}/issues?state=all&sort=created&direction=desc&per_page=1",
                headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"})
            with urllib.request.urlopen(request, timeout=20) as answer:
                return json.load(answer)[0]["number"] + NUMBER_SLACK
        except Exception:  # the slower way may still work
            pass
    try:
        listed = subprocess.run(["git", "ls-remote", "origin", "refs/pull/*/head"], cwd=cwd, capture_output=True, text=True,
                                timeout=20, check=False)
    except subprocess.TimeoutExpired:
        return None
    numbers = [int(number) for number in re.findall(r"refs/pull/(\d+)/head", listed.stdout)]
    return max(numbers) + NUMBER_SLACK if listed.returncode == 0 and numbers else None


# MARK: the command line

def lines_of(text):
    return [line for line in (line.strip() for line in text.splitlines()) if line and not line.startswith("#")]


def checker_for(top, here=None, commit=None):
    """The checker for a clone. `here`: what this machine would give away, where its environment is not the place to look. `commit`: whose
    exceptions hold; without one, or where it has none, those beside this script."""
    none, carried = git("show", f"{commit}:scripts/public-check.allow", cwd=top, check=False) if commit else (1, "")
    private = os.environ.get("PUBLIC_CHECK_WORDS", "").split("\n")
    code, path = git("config", "--get", "arbor.privateWords", cwd=top, check=False)
    if code == 0 and path.strip():
        private += read_lines(os.path.expanduser(path.strip()))
    try:
        with open(os.path.join(top, "LICENSE"), encoding="utf-8") as handle:
            licence = handle.read()
    except OSError:
        licence = ""
    owner = re.search(r"github\.com[:/]([\w.-]+)/", git("remote", "get-url", "origin", cwd=top, check=False)[1])
    highest = highest_number(top)
    if highest is None:
        print("public-check: could not ask origin for its newest pull request, so numbers like #123 were not checked", file=sys.stderr)
    return Checker(
        allowed=read_lines(os.path.join(HERE, "public-check.allow")) if none else lines_of(carried), licence=licence, highest=highest,
        owner=os.environ.get("GITHUB_REPOSITORY_OWNER") or (owner.group(1) if owner else None),
        here=told_by_this_machine(os.environ, socket.gethostname()) if here is None else here, private=[word.strip() for word in private if word.strip()])


def escape(text, is_property=False):
    text = text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    return text.replace(":", "%3A").replace(",", "%2C") if is_property else text


def report(checker, problems, findings, what, masked):
    """Prints everything found, and in GitHub Actions the first of it as annotations, for readers who cannot get at logs."""
    for problem in problems:
        print(f"✘ {problem}")
    annotations = [f"::error title=public-check::{escape(problem)}" for problem in problems[:5]]
    for finding in findings:
        where = checker.fit_to_print("path", finding.where) if masked and finding.where not in NO_FILE else finding.where
        place = (f"{finding.source} " if finding.source else "") + (f"{where}:{finding.number}" if finding.number else where)
        print(f"✘ {place}: [{finding.rule}] {finding.why}\n    {finding.excerpt(masked)}")
        is_file = finding.number and where == finding.where and where not in NO_FILE
        at = f"file={escape(where, True)},line={finding.number}," if is_file else ""
        annotations.append(f"::error {at}title=public-check%3A {finding.rule}::{escape(place + ': ' + finding.why + ' | ' + finding.excerpt(True))}")
    if os.environ.get("GITHUB_ACTIONS"):
        print("\n".join(annotations[:10]))  # GitHub shows ten of a kind for each step
    count = len(problems) + len(findings)
    if count:
        print(f"public-check: {count} to put right in {what}. Reword, and where a commit that is not pushed yet holds it, make the commit again "
              "(a later commit does not take it out of the history). An honest exception gets a line, with its reason, in scripts/public-check.allow.")
    else:
        print(f"public-check: nothing private found in {what}")
    return 1 if count else 0


def new_commits(count):
    return f"{count} new commit{'' if count == 1 else 's'}"


def unread_rules(top):
    """What to tell whoever has not read the rules as they now are; None when there is nothing to tell."""
    code, words = git("config", "--get", "arbor.privateWords", cwd=top, check=False)
    if code != 0 or not words.strip():
        return None
    try:
        with open(os.path.join(os.path.dirname(os.path.expanduser(words.strip())), "rules-version.txt"), encoding="utf-8") as handle:
            number, _, what = handle.readline().strip().partition(" ")
    except OSError:
        return None
    if not number or git("config", "--get", "arbor.rulesRead", cwd=top, check=False)[1].strip() == number:
        return None
    return (f"THE RULES YOU WORK TO HAVE CHANGED, and this clone has not said that it has read them. Version {number}: {what}\n"
            f"Read your inbox and what that sentence names, now. Then: git config arbor.rulesRead {number}")


# A hold that nobody took away is taken for forgotten after this long.
HOLD_LASTS = datetime.timedelta(minutes=90)
# What a push to these starts is nothing, or seconds.
NOT_HELD = re.compile(r"(mac-shell-out|state)/")


def address(top, url):
    """Where a push goes, for whoever gave a remote's name."""
    return url if "/" in url else git("remote", "get-url", "--push", url, cwd=top, check=False)[1].strip()


def held(top, url=None, now=None):
    """Why nothing that starts checks is to be pushed just now; None when there is no such reason.

    While work goes from the trunk to main, every push that starts checks takes a runner from the checks the move waits for. Whoever
    lands says so in `hold.txt`, beside the file of private words: `until main is <commit>` or `until <2026-01-02T12:30Z>`, then why.
    It ends by itself: when main is there or past it, when the time has come, and in any case when the file is an hour and a half old.
    Whatever is wrong with the file, it never holds for longer than that, and never whoever lands."""
    code, words = git("config", "--get", "arbor.privateWords", cwd=top, check=False)
    if code != 0 or not words.strip():
        return None
    url = url and address(top, url)
    if url and not UPSTREAM.search(url):
        return None
    for key in ("arbor.mayLand", "arbor.ignoreHold"):  # whoever lands has to push; the other is for a push that was asked for
        if git("config", "--type=bool", "--get", key, cwd=top, check=False)[1].strip() == "true":
            return None
    path = os.path.join(os.path.dirname(os.path.expanduser(words.strip())), "hold.txt")
    now = now or datetime.datetime.now(datetime.timezone.utc)
    try:
        age = now - datetime.datetime.fromtimestamp(os.path.getmtime(path), datetime.timezone.utc)
        with open(path, encoding="utf-8-sig", errors="replace") as handle:
            until, _, why = handle.read().strip().partition("\n")
    except OSError:
        return None
    until = " ".join(until.split())
    if not until or age > HOLD_LASTS or age < -HOLD_LASTS:  # written in a future that far off: a clock is wrong, not a train open
        return None
    commit = re.fullmatch(r"until main is ([0-9a-f]{7,40})", until, re.IGNORECASE)
    time = re.fullmatch(r"until (\d{4}-\d\d-\d\dT\d\d:\d\d)(:\d\d)?Z", until, re.IGNORECASE)
    if commit:
        wanted = commit.group(1).lower()
        try:
            listed = subprocess.run(["git", "ls-remote", url or "origin", "refs/heads/main"], cwd=top, capture_output=True, text=True, timeout=20, check=False).stdout
        except subprocess.TimeoutExpired:  # the push would fare no better
            listed = ""
        there = listed.split("\t")[0]
        # Past it counts too, where this clone has both commits to compare.
        if there.startswith(wanted) or (there and git("merge-base", "--is-ancestor", wanted, there, cwd=top, check=False)[0] == 0):
            return None
    if time:
        try:
            if now >= datetime.datetime.strptime(time.group(1).upper(), "%Y-%m-%dT%H:%M").replace(tzinfo=datetime.timezone.utc):
                return None
        except ValueError:  # the 45th of the 13th: it holds like any first line nobody can read
            pass
    return (f"PUSHES ARE HELD {until}. {' '.join(why.split())}\n"
            "It ends by itself; go on working, and push then. If this very push was asked for: git -c arbor.ignoreHold=true push …")


def landing_problems(top, name, commit, there):
    """Why this push to a branch where work is integrated may not happen. `commit` is None when the branch is being deleted."""
    if git("config", "--type=bool", "--get", "arbor.mayLand", cwd=top, check=False)[1].strip() != "true":
        return [f"{name} is moved by whoever lands work, and by nobody else: hand in a pull request against swarm/trunk (CLAUDE.md). "
                "If landing is your job: git config arbor.mayLand true"]
    if commit is None:
        return [f"{name} is never deleted"]
    if not ZERO.match(there) and git("merge-base", "--is-ancestor", there, commit, cwd=top, check=False)[0] != 0:
        return [f"{name} only ever moves forward, and this push would leave out what is there now ({there[:8]}): git fetch, rebase, and push again, without force"]
    return []


READ = "pushes-read"
# What workflows and GitHub's own helpers push: no hook of anybody's stands in their way.
MADE_THERE = re.compile(r"refs/heads/(mac-shell-out/|dependabot/|state/github$)")
# The public repository's address, and nothing that only ends like it: whoever is asked where the branches stand is taken at their word.
ADDRESS = re.compile(r"(https://([^/@?#\\]*@)?|(ssh://)?git@)(ssh\.)?" + UPSTREAM.pattern, re.IGNORECASE)


def record_of_pushes(top):
    """The folder the notes lie in, beside the file of private words. None where there is no such file, as when a shared folder is not there just
    now, and where that is inside a clone, this one or another: a commit might take the notes along."""
    words = os.path.abspath(os.path.expanduser(git("config", "--get", "arbor.privateWords", cwd=top, check=False)[1].strip()))
    if not os.path.isfile(words):
        return None
    folder = above = os.path.realpath(os.path.join(os.path.dirname(words), READ))
    while above != os.path.dirname(above):
        above = os.path.dirname(above)
        if os.path.exists(os.path.join(above, ".git")):
            return None
    return folder


def note(sha, ref):
    """What the note of a push is called: nothing in it but what every file system takes, and no longer than one takes."""
    name = f"{sha}-{urllib.parse.quote(ref.encode('utf-8', 'surrogateescape'), safe='')}"
    return name if len(name) <= 200 else f"{name[:120]}-{hashlib.sha256(name.encode()).hexdigest()}"


def write_down(top, how, refs):
    """A note for each (object, ref): a file of its own, whose name says it all. The folder is shared by many machines over a network, where two that
    add to one file at once lose each other's lines; a file that is only ever made, under a name nobody else would give it, cannot be lost so.
    Whether all were written, or there was nowhere to write them."""
    folder, done = record_of_pushes(top), True
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    for sha, ref in refs if folder else []:
        try:
            os.makedirs(folder, exist_ok=True)
            with open(os.path.join(folder, note(sha, ref)), "w", encoding="utf-8") as handle:
                handle.write(f"{now} {how}\n")
        except OSError:
            done = False
    return done


def wordless(top):
    """What to tell a clone that knows of no private words. The setting lies in the clone: one made anew has lost it, a second one never had it."""
    if git("config", "--get", "arbor.privateWords", cwd=top, check=False)[1].strip() or os.environ.get("PUBLIC_CHECK_WORDS"):
        return None
    return ("THIS CLONE KNOWS OF NO PRIVATE WORDS (git config arbor.privateWords <path>; docs/PUBLIC.md): it reads by kinds alone, and does not ask whether the rules have "
            "changed or pushes are held")


def unguarded(top):
    """What this clone lacks of what guards a push, for whoever runs the check by hand and takes that for the whole of the rule."""
    try:
        with open(os.path.join(top, git("rev-parse", "--git-common-dir", cwd=top).strip(), "hooks", "pre-push"), encoding="utf-8", errors="replace") as handle:
            hook = "# arbor's pre-push hook" in handle.read() and not git("config", "--get", "core.hooksPath", cwd=top, check=False)[1].strip()
    except OSError:
        hook = False
    return [*([] if hook else ["THIS CLONE HAS NO HOOK: nothing reads a push from it unless somebody thinks of it, with whatever check is at hand: make hooks"]), *filter(None, [wordless(top)])]


def leave_notes(top, read):
    """After a push that was read and let pass. `read`: what went, and where to."""
    # Only whoever may push to the public repository gets to read this.
    if read and wordless(top):
        print(f"public-check: {wordless(top)}. No note of this push is left, so it counts as one that no hook has read", file=sys.stderr)
    if not write_down(top, f"read-by-{VERSION}", read):  # which is no reason not to push
        print("public-check: it could not be written down that this push was read: it will be taken for one that no hook has seen", file=sys.stderr)


def fit_for_a_line(ref):
    return ref.replace("refs/heads/", "", 1).encode("utf-8", "surrogateescape").decode("utf-8", "replace")


def unread_pushes(top, begin, only=None):
    folder = record_of_pushes(top)
    if not folder:
        raise Unclear("there is no record of pushes to go by: it lies beside the file of private words, which is to be there and outside every clone (git config arbor.privateWords <path>)")
    addresses = [url for name in git("remote", cwd=top).splitlines() for url in git("config", "--get-all", f"remote.{name}.url", cwd=top, check=False)[1].splitlines() if ADDRESS.match(url)]
    if not addresses:
        raise Unclear("no remote of this clone is the public repository")
    try:
        listed = subprocess.run(["git", "ls-remote", addresses[0]], cwd=top, capture_output=True, encoding="utf-8", errors="surrogateescape", timeout=60, check=False)
    except subprocess.TimeoutExpired:
        listed = None
    # Not HEAD, not what a tag points at, which comes with the tag, and not what GitHub keeps of pull requests.
    refs = [tuple(line.split("\t")) for line in listed.stdout.split("\n") if "\trefs/" in line and not line.endswith("^{}") and "\trefs/pull/" not in line] if listed and listed.returncode == 0 else []
    if not any(ref == "refs/heads/main" for _, ref in refs):
        raise Unclear(f"{addresses[0]} does not say where its branches stand")
    if only:
        refs = [(sha, ref) for sha, ref in refs if ref == f"refs/heads/{only}"]
        if not refs:
            raise Unclear(f"there is no branch {only} there")
    try:
        known = set(os.listdir(folder))
    except FileNotFoundError:
        if not begin:
            raise Unclear("the record of pushes has not been begun: scripts/public-check.py --unread --begin") from None
        known = set()
    except OSError as error:
        raise Unclear(f"the record of pushes cannot be read ({error.strerror})") from error
    theirs = [ref for _, ref in refs if MADE_THERE.match(ref)]
    unread = [(sha, ref) for sha, ref in refs if note(sha, ref) not in known and ref not in theirs]
    for sha, ref in unread:
        print(f"{'·' if begin else '✘'} {fit_for_a_line(ref)} stands at {sha[:8]}, and no note says that a hook has read that")
    ours, rest = len(refs) - len(theirs), f"{len(theirs)} more are what workflows push, and are left out"
    if begin:
        if not write_down(top, "stood-there", unread):
            raise Unclear("not all of that could be written down")
        print(f"public-check: these {len(unread)} of {ours} branches and tags are written down as they stand, unread, and are not asked about again; {rest}")
        return 0
    if unread:
        print(f"public-check: {len(unread)} of {ours} branches and tags stand where no hook has read them; {rest}. Such a push came past the hook (no `make hooks`, a scratch repository, "
              "--no-verify), through a check older than version 8, from a clone that knows of no private words, or was made at GitHub; or its note has "
              "not got here yet: the folder is shared over a network, so ask again in a few minutes. Read it (--base … --head …); --unread --begin --branch … then writes it off")
    else:
        print(f"public-check: all {ours} branches and tags stand where a hook has read them or where they were written down as they stood; {rest}")
    return 1 if unread else 0


def pre_push(top, lines, masked, url=None):
    # At the one kind of space no ref can hold, a name may hold others; and from the right, what is pushed may be called `HEAD@{1 day ago}`. A line taken
    # for something else would go unread.
    pushed = [line.rsplit(" ", 3) for line in lines if line]
    if any(len(fields) != 4 for fields in pushed):
        raise Unclear("git says what is being pushed in a way this check does not know")
    unread = unread_rules(top)
    if unread:
        print(f"✘ {unread}\npublic-check: nothing was pushed.")
        return 1
    # A branch that is deleted, a tag, and a push that has nothing to send start nothing.
    starts = [fields for fields in pushed if not ZERO.match(fields[1]) and fields[2].startswith("refs/heads/") and not NOT_HELD.match(fields[2][len("refs/heads/"):])]
    hold = held(top, url) if starts else None
    if hold:
        print(f"✘ {hold}\npublic-check: nothing was pushed.")
        return 1
    code, read = 0, []
    public = url is None or UPSTREAM.search(address(top, url))
    for _, sha, remote_ref, there in pushed:
        # A fork's branches are its owner's business.
        guarded = remote_ref.replace("refs/heads/", "", 1) if remote_ref.startswith("refs/heads/") and public else None
        if ZERO.match(sha):  # a branch being deleted adds nothing
            if guarded in INTEGRATION:
                code |= report(checker_for(top), landing_problems(top, guarded, None, there), [], f"branch {guarded}", masked)
            continue
        commit = git("rev-parse", "--verify", sha + "^{commit}", cwd=top).strip()
        checker = checker_for(top, commit=commit)
        # On its way to the public repository all is read that main and the trunk do not hold: a note of this push then needs no note of the one before.
        problems, findings, count = check_range(checker, [commit, "--not", *public_already(top, read=public)], commit, top)
        if remote_ref.startswith("refs/tags/"):
            kind, name = "tag", remote_ref[len("refs/tags/"):]
            more_problems, more = check_tag(checker, name, top)
            problems, findings = problems + more_problems, findings + more
        else:
            kind, name = "branch", remote_ref.replace("refs/heads/", "", 1)
            findings += checker.check("branch", name, numbered=False)
            if guarded in INTEGRATION:
                problems += landing_problems(top, guarded, commit, there)
        if public:
            read.append((sha, remote_ref))
        shown = checker.fit_to_print(kind, name) if masked else name
        code |= report(checker, problems, findings, f"{kind} {shown} ({new_commits(count)})", masked)
    if code:
        print("public-check: nothing was pushed.")
    else:
        leave_notes(top, read)
    return code


def main(arguments=None, cwd=None):
    parser = argparse.ArgumentParser(usage="see the top of scripts/public-check.py", add_help=False)
    for flag in ("--base", "--head", "--branch", "--tag", "--to"):
        parser.add_argument(flag)
    for flag in ("--pre-push", "--rules", "--text", "--tree", "--unread", "--begin", "--mask", "--help"):
        parser.add_argument(flag, action="store_true")
    parser.add_argument("files", nargs="*")
    options = parser.parse_args(arguments)
    masked = options.mask or bool(os.environ.get("GITHUB_ACTIONS"))
    if options.help:
        print(__doc__)
        return 0
    try:
        if options.files and not options.text:
            raise Unclear(f"what is to be done with {options.files[0]}? --text reads files; without it a branch is read")
        top = git("rev-parse", "--show-toplevel", cwd=cwd).strip()
        if options.rules:
            unread = unread_rules(top) or held(top)
            print(f"✘ {unread}" if unread else "public-check: the rules are as this clone last read them, or there are none to read")
            return 1 if unread else 0
        if options.unread:
            return unread_pushes(top, options.begin, options.branch)
        if options.begin:
            raise Unclear("--begin goes with --unread")
        if options.pre_push:
            return pre_push(top, sys.stdin.read().split("\n"), masked, options.to or os.environ.get("PUBLIC_CHECK_TO") or os.environ.get("PUBLIC_CHECK_REMOTE"))
        checker = checker_for(top) if options.text or options.tree else None
        if options.text:
            findings = []
            for name in options.files or ["-"]:
                try:
                    with (sys.stdin if name == "-" else open(name, encoding="utf-8", errors="replace")) as handle:
                        found = checker.check("text", handle.read())
                except OSError as error:
                    raise Unclear(f"{name} cannot be read ({error.strerror})") from error
                for finding in found:
                    finding.source = None if name == "-" else name
                findings += found
            return report(checker, [], findings, "the text", masked)
        if options.tree:
            findings = []
            for path in git("ls-files", "-z", cwd=top).split("\0"):
                full = os.path.join(top, path)
                if not path or os.path.islink(full) or not os.path.isfile(full):
                    continue
                with open(full, "rb") as handle:
                    raw = handle.read()
                findings += checker.check("path", path, numbered=False)
                if b"\0" not in raw[:8000]:
                    findings += checker.check(path, raw.decode("utf-8", errors="replace"))
            return report(checker, [], findings, "the whole tree", masked)

        head = git("rev-parse", "--verify", (options.head or "HEAD") + "^{commit}", cwd=top).strip()
        checker = checker_for(top, commit=head)
        branch = options.branch
        if branch is None and not options.head and not options.tag:
            branch = git("rev-parse", "--abbrev-ref", "HEAD", cwd=top).strip()
        base = None
        if options.base and not ZERO.match(options.base):  # all noughts: a branch's first push has nothing before it
            code, base = git("rev-parse", "--verify", "--quiet", options.base + "^{commit}", cwd=top, check=False)
            if code != 0 and branch not in INTEGRATION:
                raise Unclear(f"{options.base} is no commit here")
            base = base.strip() if code == 0 else None
        if base:
            selection = [head, "^" + base, *read_elsewhere(branch, top)]
        elif options.base and branch in INTEGRATION:
            # Pushed anew, or by force: what was there before is on no branch any more, and so not here. Neither should ever happen. There is nothing to
            # hold it against then, and it does not vouch for itself.
            selection = [head, *read_elsewhere(branch, top), "--not", *first_commit_if_here(top)]
        else:
            # Not "what no remote has": a branch that is on the remote already is read all the same, until it is put right.
            integrated = [f"refs/remotes/origin/{name}" for name in INTEGRATION
                          if git("rev-parse", "--verify", "--quiet", f"refs/remotes/origin/{name}", cwd=top, check=False)[0] == 0]
            if not integrated:
                raise Unclear("neither origin/main nor origin/swarm/trunk is here to compare with: git fetch origin")
            selection = [head, "--not", *integrated, *first_commit_if_here(top)]
        problems, findings, count = check_range(checker, selection, head, top)
        what = new_commits(count)
        more = int(git("rev-list", "--count", head, "^" + base, cwd=top)) - count if base else 0
        if branch and branch != "HEAD":
            findings += checker.check("branch", branch, numbered=False)
            what += f" on {checker.fit_to_print('branch', branch) if masked else branch}"
        if more:
            what += f" ({more} more left out: origin's {' or '.join(name.rsplit('origin/', 1)[1] for name in read_elsewhere(branch, top))} has them, and they were read on the way there)"
        if options.tag:
            more_problems, more = check_tag(checker, options.tag, top)
            problems, findings = problems + more_problems, findings + more
        code = report(checker, problems, findings, what, masked)
        for lack in unguarded(top) if not os.environ.get("GITHUB_ACTIONS") else []:  # where there is nobody to push
            print(f"public-check: {lack}", file=sys.stderr)
        return code
    except Unclear as error:
        print(f"public-check: cannot tell: {error}")
        if os.environ.get("GITHUB_ACTIONS"):
            print(f"::error title=public-check::{escape(str(error))}")
        return 2


if __name__ == "__main__":
    sys.exit(main())
