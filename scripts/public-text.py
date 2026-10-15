#!/usr/bin/env python3
"""Reads what people and agents post here (issues, pull requests, comments, reviews) for what should have stayed private.

scripts/public-check.py reads what is pushed. What is posted is just as public, and nothing reads it before it is: issues
had to be reworded by hand because they named somebody and described a tester's Mac, and a platform appends a link to
the author's working session to the pull requests it creates. The workflow `Public text` runs this at every post and
every edit. It reads the whole thread each time, so it needs no memory, and does three things:

  mends     A link to a working session becomes the generic link, in place. That is the one edit it makes to anybody's words:
            the pattern is exact, the replacement fixed, and nobody can want the link.
  answers   Everything else it finds goes into ONE comment on the thread: where, which line, what to write instead. Never the
            words themselves. The comment follows the thread: it changes as things are reworded and goes when nothing is left.
  fails     While a pull request's own title or description holds something, its check is red. Only those: the check belongs to the run
            that an edit of them starts again. A run started by an issue or a comment counts for the default branch's newest commit,
            which has nothing to do with it, so there the comment is the only sign.

Those who work on the repository (its owner, members, collaborators, and the apps that post for them) are held to all the rules.
Anybody else is only told of what would give away something of their own: an address, a path with their name in it, a session. A
stranger who links to a blog or thanks the maintainer by name has done nothing that needs an answer from a machine.

Words from a secret ($PUBLIC_CHECK_WORDS) are looked for only in what those who work here post, and the comment then names the post
and nothing more. Otherwise anybody could post guesses and read the list off the answers.

What is posted is read as data and nothing else. No code of a pull request is checked out or run, no text reaches a shell, and
what is quoted back stands in a code block, where it can neither mention anybody nor link anywhere.

Usage: scripts/public-text.py                        in the workflow: the thread of the event in $GITHUB_EVENT_PATH
       scripts/public-text.py --recent HOURS          in the workflow, once a night: every thread that changed in that time, for what no
                                                      event brought here (a review on a fork's pull request, a run that failed)
       scripts/public-text.py --thread N              in a workflow: that thread. The poller (.github/workflows/state.yml) calls it so where a link to a
                                                      working session stands in a description: it is running already, and waits for no runner
       scripts/public-text.py --link-pattern          prints what such a link looks like, for the poller to look out for: it stands in one place only
       scripts/public-text.py --thread N --dry-run    by hand: changes nothing and prints what it would do
       scripts/public-text.py --all --dry-run         every thread there is: an audit

Only the workflow writes: a comment posted under another account would not be found again, and would stay for ever.

Needs $GITHUB_REPOSITORY, and in $GITHUB_TOKEN or $GH_TOKEN a token that may write issues and pull requests.
Exit code 0 when nothing is left to reword, 1 when something is, 2 when it could not tell.
scripts/test-public-text.py holds it to a table of situations, with GitHub's part made up; `make lint` runs that.
"""

import datetime
import http.client
import importlib.util
import json
import os
import re
import sys
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("public_check", os.path.join(HERE, "public-check.py"))
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)

# How the comment is found again. Only in a comment of the workflow's own account does it count.
MARKER = "<!-- public-text -->"
OWN_ACCOUNT = "github-actions[bot]"
# Their posts quote other projects' release notes, links and all, and no person wrote them.
NOT_READ = {"dependabot[bot]"}
# With whatever hangs on to it, up to the blank, bracket or quote that ends a link.
SESSION_LINK = re.compile(r"https://claude\.ai/code/session_[0-9A-Za-z]+[^\s()<>\[\]\"'`]*")
GENERIC_LINK = "https://claude.ai/code"
LISTED_AT_MOST = 20
INSIDERS = {"OWNER", "MEMBER", "COLLABORATOR"}
FOR_EVERYBODY = {"session", "email", "home", "here"}


class GitHub:
    """The few calls this needs."""

    def __init__(self, repository, token):
        self.repository, self.base, self.token = repository, f"https://api.github.com/repos/{repository}", token

    def call(self, method, path, body=None):
        request = urllib.request.Request(
            self.base + path, method=method, data=None if body is None else json.dumps(body).encode("utf-8"),
            headers={"Authorization": f"Bearer {self.token}", "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"})
        with urllib.request.urlopen(request, timeout=30) as answer:
            text = answer.read()
        return json.loads(text) if text else None

    def every(self, path):
        page, items = 1, []
        while True:
            batch = self.call("GET", f"{path}{'&' if '?' in path else '?'}per_page=100&page={page}")
            items += batch
            if len(batch) < 100:
                return items
            page += 1


class Post:
    """One text somebody posted: what to call it, where it is, how to change it."""

    def __init__(self, what, item, method, path, field="body"):
        self.what, self.url, self.text = what, item["html_url"], item[field] or ""
        user = item.get("user") or {}
        self.author = user.get("login", "")
        self.is_insider = item.get("author_association") in INSIDERS or user.get("type") == "Bot"
        self.is_the_pull_requests_own = False
        self.method, self.path, self.field = method, path, field


def posts_of(github, number):
    """Everything posted in a thread, and the comments among it that are this script's own."""
    issue = github.call("GET", f"/issues/{number}")
    kind = "pull request" if "pull_request" in issue else "issue"
    posts = [Post(f"the {kind}'s title", issue, "PATCH", f"/issues/{number}", "title"),
             Post(f"the {kind}'s description", issue, "PATCH", f"/issues/{number}")]
    for post in posts:
        post.is_the_pull_requests_own = kind == "pull request"
    own = []
    for comment in github.every(f"/issues/{number}/comments"):
        post = Post("a comment", comment, "PATCH", f"/issues/comments/{comment['id']}")
        if post.author == OWN_ACCOUNT and MARKER in post.text:
            own.append(comment)
        else:
            posts.append(post)
    if kind == "pull request":
        posts += [Post("a comment on a line", comment, "PATCH", f"/pulls/comments/{comment['id']}") for comment in github.every(f"/pulls/{number}/comments")]
        posts += [Post("a review", review, "PUT", f"/pulls/{number}/reviews/{review['id']}") for review in github.every(f"/pulls/{number}/reviews")]
    return [post for post in posts if post.author not in NOT_READ], own


def quoted(excerpt):
    """An excerpt as it can stand in a comment: in a code span, which nothing gets out of."""
    return "`` " + excerpt.replace("`", "'").replace("\r", " ") + " ``"


def comment_for(found, repository):
    """The one comment. `found` is a list of (post, findings)."""
    lines = [
        MARKER,
        "**This repository is public, and some words in this thread are better reworded.** "
        f"[docs/PUBLIC.md](https://github.com/{repository}/blob/HEAD/docs/PUBLIC.md) says what stays out and why. Whoever wrote them, or anybody who may edit here, can "
        "change the text in place (the … menu, Edit). This comment follows along and goes away by itself when nothing is left.",
        "",
    ]
    listed = 0
    for post, findings in found:
        for finding in findings:
            listed += 1
            if listed <= LISTED_AT_MOST and finding.rule == "private":
                lines.append(f"- [{post.what}]({post.url}): a word that is on a private list of words to keep out of here")
            elif listed <= LISTED_AT_MOST:
                lines.append(f"- [{post.what}]({post.url}), line {finding.number}: {finding.why}")
                lines.append(f"  {quoted(finding.excerpt(True))}")
    if listed > LISTED_AT_MOST:
        lines.append(f"- and {listed - LISTED_AT_MOST} more")
    lines += ["", f"What was found is blanked out ({check.MASK}) so that this comment does not repeat it. If the check is wrong, say so here: "
              "an honest exception gets a line in `scripts/public-check.allow`."]
    return "\n".join(lines)


def notice(level, message):
    print(f"::{level} title=public-text::{check.escape(message)}" if os.environ.get("GITHUB_ACTIONS") else f"public-text: {message}")


def read_thread(github, checker, number, dry_run=False):
    """Mends, answers, and returns how many findings are left: in all, and in a pull request's own title and description."""
    def change(method, path, body, what):
        """Whether it worked. A token that may only read (a pull request from a fork) is no reason to fall over."""
        if dry_run:
            print(f"public-text: would {what}")
            return True
        try:
            github.call(method, path, body)
            return True
        except urllib.error.HTTPError as error:
            notice("warning", f"#{number}: could not {what} (HTTP {error.code})")
            return False

    posts, own = posts_of(github, number)
    found = []
    for post in posts:
        if SESSION_LINK.search(post.text):
            # Read once more, right before writing: whoever has edited the post since must not get the earlier wording back.
            fresh = post.text if dry_run else github.call("GET", post.path)[post.field] or ""
            mended = SESSION_LINK.sub(GENERIC_LINK, fresh)
            if mended == fresh:
                post.text = fresh
            elif change(post.method, post.path, {post.field: mended}, f"replace the link to a working session in {post.what}"):
                post.text = mended
                notice("notice", f"#{number}: a link to a working session in {post.what} is now the generic link. The earlier wording stays in "
                       "its edit history, where somebody with the right to can delete it (the \"edited\" menu)")
        findings = [finding for finding in checker.check("text", post.text) if post.is_insider or finding.rule in FOR_EVERYBODY]
        if findings:
            found.append((post, findings))

    left = sum(len(findings) for _, findings in found)
    if found:
        body = comment_for(found, github.repository)
        if not own:
            change("POST", f"/issues/{number}/comments", {"body": body}, "post the comment")
        elif own[0]["body"] != body:
            change("PATCH", f"/issues/comments/{own[0]['id']}", {"body": body}, "bring the comment up to date")
        for post, findings in found:
            for finding in [finding for finding in findings if finding.rule != "private"][:3]:
                notice("error", f"#{number}, {post.what}, line {finding.number}: {finding.why} | {finding.excerpt(True)}")
    for comment in own[1 if found else 0:]:
        change("DELETE", f"/issues/comments/{comment['id']}", None, "take the comment away")
    print(f"public-text: #{number}: {left} to reword in {len(posts)} posts" if left else f"public-text: #{number}: nothing private found in {len(posts)} posts")
    return left, sum(len(findings) for post, findings in found if post.is_the_pull_requests_own)


def thread_of(event):
    """The number of the issue or pull request an event is about."""
    for key in ("issue", "pull_request"):
        if isinstance(event.get(key), dict) and isinstance(event[key].get("number"), int):
            return event[key]["number"]
    raise check.Unclear("this event is about no issue and no pull request")


def main(arguments, make_github=GitHub, make_checker=None):
    if "--link-pattern" in arguments:
        print(SESSION_LINK.pattern)
        return 0
    dry_run = "--dry-run" in arguments
    try:
        repository, token = os.environ.get("GITHUB_REPOSITORY"), os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
        if not repository or not token:
            raise check.Unclear("$GITHUB_REPOSITORY and a token in $GITHUB_TOKEN or $GH_TOKEN are needed")
        if not dry_run and not os.environ.get("GITHUB_ACTIONS"):
            raise check.Unclear("only the workflow writes; by hand, say --dry-run")
        github = make_github(repository, token)
        only_its_own = False
        if "--all" in arguments:
            if not dry_run:
                raise check.Unclear("--all is an audit: say --dry-run with it")
            numbers = sorted(issue["number"] for issue in github.every("/issues?state=all"))
        elif "--recent" in arguments:
            since = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=float(arguments[arguments.index("--recent") + 1]))
            numbers = sorted(issue["number"] for issue in github.every(f"/issues?state=all&since={since.strftime('%Y-%m-%dT%H:%M:%SZ')}"))
        elif "--thread" in arguments:
            numbers = [int(arguments[arguments.index("--thread") + 1])]
        else:
            with open(os.environ["GITHUB_EVENT_PATH"], encoding="utf-8") as handle:
                numbers = [thread_of(json.load(handle))]
            only_its_own = True
        # Of all this runner's environment holds, only the token is nobody's business: the rest is numbers GitHub shows everybody.
        checker = (make_checker or (lambda: check.checker_for(check.git("rev-parse", "--show-toplevel", cwd=HERE).strip(), here={token: "token"})))()
        left = [read_thread(github, checker, number, dry_run) for number in numbers]
        if only_its_own:
            return 1 if os.environ.get("GITHUB_EVENT_NAME") == "pull_request_target" and left[0][1] else 0
        return 1 if any(in_all for in_all, _ in left) else 0
    except (check.Unclear, OSError, http.client.HTTPException, KeyError, ValueError, IndexError, TypeError) as error:
        notice("error", f"cannot tell: {type(error).__name__}: {error}")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
