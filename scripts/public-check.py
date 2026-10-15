#!/usr/bin/env python3
"""Keeps what is private out of a public repository, before it is pushed and again in CI.

Whatever is pushed or posted here can be read, copied and indexed by anybody, for good: deleting it later takes it out of
sight, not out of the world. People and agents work on Arbor from machines of their own, with notes of their own, and
what slips in is seldom a secret key. It is a link to somebody's working session, a path with a user's name in it, a
sentence about one person's Mac. Those were looked for by hand; this looks for them every time.

It checks two things.

  History   Everything being pushed goes back to the repository's first public commit and to no other beginning (a clone
            can hold history from elsewhere), and every new commit and tag was made under a no-reply address.
  Words     The lines, file names, commit messages, authors' names, branch and tag names that are new. RULES below says
            what is looked for and what to write instead. Each new commit is read by itself, merges too: what one commit
            adds and the next takes out again is still in the history.

The rules name kinds of things, never the things themselves, so that reading this file teaches nobody anything: any host
the project has not linked to before, not a list of hosts to avoid; the name in LICENSE, read from LICENSE; this
machine's own ids, read from its environment. There is no list of forbidden words here, not even in disguise. Words no
kind covers go, one to a line, in a file of your own outside the repository (`git config arbor.privateWords <path>`), or
in $PUBLIC_CHECK_WORDS. Honest exceptions are in public-check.allow, each with its reason.

Usage: scripts/public-check.py             what this branch adds to origin's main and swarm/trunk (`make public-check`)
       … --base REF [--head REF] [--branch NAME] [--tag NAME]   what REF..head adds (head: HEAD); CI's way
       … --pre-push                        as git's pre-push hook, which says on standard input what is being pushed
       … --rules                           only whether the rules have changed since this clone last said it had read them (below)
       … --text [FILE…]                    free text, from standard input without a file: read a pull request's body or a
                                           comment through this BEFORE posting it
       … --tree                            every file at HEAD, old and new: an audit to read, not a gate
       … --mask                            print findings without the words found (always so in GitHub Actions, whose
                                           logs and annotations are as public as the repository)

Rules that change. Agents who work to a brief kept outside the repository are deep in long work when a rule changes, and a message does
not reach them until they look up. So the change is enforced where the act happens. Beside the file of private words lies
`rules-version.txt`; its first line is a number, a time, and a sentence on what changed and what to read again. The hook compares the
number with `git config arbor.rulesRead` and refuses the push while they differ. No such file, as in a stranger's clone: not a word.

Exit code 0 when nothing was found, 1 when something was, 2 when it could not tell.
scripts/test-public-check.py holds it to a table of situations; `make lint` runs that.
"""

import argparse
import bisect
import fnmatch
import json
import os
import re
import socket
import subprocess
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
# Raise it whenever the check gets stricter or a hole in it is mended. The hook has two copies to choose from, the one `make hooks` kept
# and the one on the branch that is checked out, and lets the newer do the reading.
VERSION = 3
# The first public commit. All history begins here.
ROOT_COMMIT = "51b162d5f28c02846134c1f4a113c787f5164602"
# Where work is integrated: what these hold on origin has been read before.
INTEGRATION = ("main", "swarm/trunk")
# The public repository itself, under whatever name a clone knows it.
UPSTREAM = re.compile(r"github\.com[:/]evbarleyg/arbor(\.git)?/?$", re.IGNORECASE)
NO_REPLY = re.compile(r"^([\w.+\[\]-]+@users\.noreply\.github\.com|noreply@github\.com)$")
MASK = "▒▒▒"
# A little more than the newest number passes: a branch is pushed before its pull request has one, others are opened
# meanwhile, and git by itself can only ask the remote for pull requests, not for issues.
NUMBER_SLACK = 15
ZERO = re.compile(r"^0+$")


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


def public_already(top):
    """What need not be read again, as arguments for git rev-list: what the public repository is known to have, and the remote being pushed
    to (the hook says which, in $PUBLIC_CHECK_REMOTE). NOT what any other remote has: a clone that also knows a private place is the very
    clone this check is for, and what lies there is new to the public however long this clone has had it."""
    names = {os.environ.get("PUBLIC_CHECK_REMOTE", "")}
    for line in git("remote", "--verbose", cwd=top).splitlines():
        name, _, rest = line.partition("\t")
        if UPSTREAM.search(rest.rsplit(" ", 1)[0]):
            names.add(name)
    known = set(git("remote", cwd=top).split())
    # Where the history begins is checked apart from this, so remote-tracking refs from somewhere else under a good name gain nothing.
    return [f"--remotes={name}/*" for name in sorted(names & known)] + first_commit_if_here(top)


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

def checker_for(top, here=None):
    """The checker for a clone. `here`: what this machine would give away, where its environment is not the place to look."""
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
        allowed=read_lines(os.environ.get("PUBLIC_CHECK_ALLOW") or os.path.join(HERE, "public-check.allow")), licence=licence, highest=highest,
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


def pre_push(top, lines, masked):
    unread = unread_rules(top)
    if unread:
        print(f"✘ {unread}\npublic-check: nothing was pushed.")
        return 1
    checker, code = None, 0
    for line in lines:
        fields = line.split()
        if len(fields) != 4 or ZERO.match(fields[1]):  # a branch being deleted adds nothing
            continue
        _, sha, remote_ref, _ = fields
        checker = checker or checker_for(top)
        commit = git("rev-parse", "--verify", sha + "^{commit}", cwd=top).strip()
        problems, findings, count = check_range(checker, [commit, "--not", *public_already(top)], commit, top)
        if remote_ref.startswith("refs/tags/"):
            kind, name = "tag", remote_ref[len("refs/tags/"):]
            more_problems, more = check_tag(checker, name, top)
            problems, findings = problems + more_problems, findings + more
        else:
            kind, name = "branch", remote_ref.replace("refs/heads/", "", 1)
            findings += checker.check("branch", name, numbered=False)
        shown = checker.fit_to_print(kind, name) if masked else name
        code |= report(checker, problems, findings, f"{kind} {shown} ({new_commits(count)})", masked)
    if code:
        print("public-check: nothing was pushed.")
    return code


def main(arguments=None, cwd=None):
    parser = argparse.ArgumentParser(usage="see the top of scripts/public-check.py", add_help=False)
    for flag in ("--base", "--head", "--branch", "--tag"):
        parser.add_argument(flag)
    for flag in ("--pre-push", "--rules", "--text", "--tree", "--mask", "--help"):
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
            unread = unread_rules(top)
            print(f"✘ {unread}" if unread else "public-check: the rules are as this clone last read them, or there are none to read")
            return 1 if unread else 0
        if options.pre_push:
            return pre_push(top, sys.stdin.read().splitlines(), masked)
        checker = checker_for(top)
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
        if options.base and not ZERO.match(options.base):  # all noughts: a branch's first push has nothing before it
            selection = [head, "^" + git("rev-parse", "--verify", options.base + "^{commit}", cwd=top).strip()]
        else:
            # Not "what no remote has": a branch that is on the remote already is read all the same, until it is put right.
            integrated = [f"refs/remotes/origin/{name}" for name in INTEGRATION
                          if git("rev-parse", "--verify", "--quiet", f"refs/remotes/origin/{name}", cwd=top, check=False)[0] == 0]
            if not integrated:
                raise Unclear("neither origin/main nor origin/swarm/trunk is here to compare with: git fetch origin")
            selection = [head, "--not", *integrated, *first_commit_if_here(top)]
        branch = options.branch
        if branch is None and not options.head and not options.tag:
            branch = git("rev-parse", "--abbrev-ref", "HEAD", cwd=top).strip()
        problems, findings, count = check_range(checker, selection, head, top)
        what = new_commits(count)
        if branch and branch != "HEAD":
            findings += checker.check("branch", branch, numbered=False)
            what += f" on {checker.fit_to_print('branch', branch) if masked else branch}"
        if options.tag:
            more_problems, more = check_tag(checker, options.tag, top)
            problems, findings = problems + more_problems, findings + more
        return report(checker, problems, findings, what, masked)
    except Unclear as error:
        print(f"public-check: cannot tell: {error}")
        if os.environ.get("GITHUB_ACTIONS"):
            print(f"::error title=public-check::{escape(str(error))}")
        return 2


if __name__ == "__main__":
    sys.exit(main())
