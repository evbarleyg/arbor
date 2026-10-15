#!/usr/bin/env python3
"""Holds the workflows in .github to the rules a public repository run by agents needs.

Many hands write workflows here, quickly. Each of these rules was once a sentence somebody had to remember:

  pinned       Every action is named by the full id of a commit, with its exact version as a remark. A tag like @v5 can be moved to
               other code by whoever gets hold of the action's repository, and that code would run with this repository's token.
               `--pin` rewrites the lines; Dependabot keeps them current (.github/dependabot.yml); `--verify` asks the action's own
               repository whether the commit is the one that version names, since GitHub also serves commits of forks under it.
  free         Jobs run on GitHub's free hosted runners and nowhere else. No larger runners, which are paid for. Never
               `self-hosted`: in a public repository a stranger's pull request would run its code on that machine.
               The label is written out, or is an input that offers a choice among such labels and nothing else: nobody can tell
               what any other expression will come to, or what a workflow in another repository runs on.
  limited      Every job has `timeout-minutes`, a plain number, two hours at most. Without it a job that hangs holds its runner for
               six hours, and there are only a few Macs for everybody.
  permissions  Every workflow says at its top what its token may do, so that it does not depend on the repository's setting.
               The top grants nothing that writes; a job that must write says so itself.
  no text in commands   Nothing is written into a command (`run:`, `script:`, `shell:`) as ${{ … }} but a few values nobody can type: the
               commit's id, the run's number, the runner's own. Everything else reaches a shell through `env:` and "$NAME". Written into
               the command it becomes part of the script, and a title like `"; curl … | sh; "` runs.
  no strangers' code with a token   A workflow that strangers can start and that runs with the repository's own token
               (`pull_request_target`, `workflow_run`, `issues`, `issue_comment`, discussions) reaches for nothing of a pull request:
               not its commit, its branch, its repository or what another run built from it.

Workflows are read line by line, as they are written here (block style, two spaces a level, plain keys), not with a YAML parser,
which Python does not bring along. YAML allows much else; what this cannot follow it reports as unreadable rather than pass over.
It does not look at images (`container:`, `services:`): CI's is named by its tag, so that it follows the Swift release.

Usage: scripts/lint-workflows.py              part of `make lint`
       scripts/lint-workflows.py --pin        rewrite every `uses:` that names a tag; asks github.com for the commit
       scripts/lint-workflows.py --verify     ask github.com whether every pin is the commit its remark says; the workflow `Public check` does
       scripts/lint-workflows.py --self-test  try the rules on right and wrong text
"""

import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
USES = re.compile(r"^(\s*(?:-\s+)?uses:\s*)([^\s#]+)(.*)$")
PINNED = re.compile(r"^[\w.-]+/[\w./-]+@[0-9a-f]{40}$")
VERSION = re.compile(r"^v?\d+(\.\d+)*$")
VERSION_REMARK = re.compile(r"^\s+# (v?\d+(?:\.\d+)*)$")
# The standard runners, free for public repositories. `-large`, `-xlarge`, `-Ncores` and names of one's own are not.
FREE = re.compile(r"^(ubuntu-(latest|slim|\d\d\.\d\d(-arm)?)|macos-(latest|\d\d(-intel)?)|windows-(latest|\d{4}|11-arm))$")
LONGEST = 120
EXPRESSION = re.compile(r"\$\{\{(.*?)(\}\}|$)")
NOBODY_TYPES = re.compile(r"^\s*(github\.(sha|run_id|run_number|run_attempt|repository|workspace|event_name|job)|runner\.\w+)\s*$")
STARTED_BY_STRANGERS = re.compile(r"\b(pull_request_target|workflow_run|issues|issue_comment|discussion|discussion_comment)\b")
OF_THE_PULL_REQUEST = re.compile(
    r"head\.(sha|ref|repo)|\['head'\]|head_ref|head_sha|head_branch|head_repository|\bpull/|merge_commit_sha|gh pr (checkout|diff)|download-artifact")
# Ways to write a key that YAML allows and the patterns here would read past.
ODD_KEY = re.compile(
    r"""^\s*(-\s+)?["'](uses|run|script|shell|runs-on|timeout-minutes|permissions|on|jobs|steps)["']\s*:"""
    r"""|[{,\[]\s*["']?(uses|run|script|shell|runs-on|timeout-minutes|permissions)["']?\s*:"""
    r"""|^\s*(-\s+)?(uses|run|script|shell|runs-on|timeout-minutes|permissions)\s+:|^\s*(-\s+)?(uses|runs-on|timeout-minutes):\s*$""")


def indent(line):
    return len(line) - len(line.lstrip(" "))


def code(line):
    """The line without a remark of its own. A `#` inside quotes or a word is none."""
    return re.sub(r"(^|\s)#.*$", "", line) if not re.search(r"""['"].*#.*['"]""", line) else line


def choices(head, name):
    """What an input of `workflow_dispatch` lets people choose from; None if it lets them type."""
    at = next((index for index, line in enumerate(head) if re.match(rf"^\s+{re.escape(name)}:\s*$", code(line))), None)
    if at is None or any(re.search(r"\bworkflow_call\b", code(line)) for line in head):  # a caller hands over what it likes
        return None
    block = []
    for line in head[at + 1:]:
        if line.strip() and indent(line) <= indent(head[at]):
            break
        block.append(code(line).strip())
    if "type: choice" not in block:
        return None
    options = []
    for index, line in enumerate(block):
        if line.startswith("options:"):
            inline = re.match(r"^options:\s*\[(.*)\]$", line)
            listed = inline.group(1).split(",") if inline else [item[1:] for item in block[index + 1:] if item.startswith("-")]
            options = [option.strip().strip("'\"") for option in listed]
    return options or None


CHOSEN = re.compile(r"^\$\{\{\s*inputs\.([\w-]+)\s*(?:\|\|\s*'([\w.-]+)'\s*)?\}\}$")


def problems_in(text, name):
    """One line for every rule broken in a workflow or a composite action."""
    problems = []
    lines = text.replace("\r\n", "\n").split("\n")
    is_workflow = "/workflows/" in name
    report = lambda number, rule, what: problems.append(f"{name}:{number}: [{rule}] {what}")

    jobs_at = next((index for index, line in enumerate(lines) if code(line).rstrip() == "jobs:"), None)
    head = lines[:jobs_at] if jobs_at is not None else lines
    on_at = next((index for index, line in enumerate(head) if re.match(r"""^["']?on["']?\s*:""", line)), None)
    triggers = []
    if on_at is not None:
        triggers = [head[on_at]]
        for line in head[on_at + 1:]:
            if line.strip() and not line.startswith((" ", "#", "-")):
                break
            triggers.append(line)
    privileged = any(STARTED_BY_STRANGERS.search(code(line)) for line in triggers)
    if is_workflow:
        if jobs_at is None:
            report(1, "unreadable", "no line `jobs:`")
        if on_at is None:
            report(1, "unreadable", "no line `on:`")
        at = next((index for index, line in enumerate(head) if line.startswith("permissions:")), None)
        if at is None:
            report(1, "permissions", "no `permissions:` above the jobs; `permissions: {}` or `contents: read`, and each job adds what it needs")
        else:
            for offset, line in enumerate(head[at:]):
                if offset and line.strip() and not line.startswith((" ", "#")):
                    break
                if re.search(r"\bwrite(-all)?\b", code(line)):
                    report(at + 1 + offset, "permissions", "the top grants a right to write to every job; give it to the one job that needs it")

    # Jobs: the keys two spaces in, below `jobs:`.
    job, job_line, job_has, jobs_seen = None, 0, set(), 0

    def close_job():
        if job and "uses" not in job_has:
            if "timeout-minutes" not in job_has:
                report(job_line, "limited", f"the job `{job}` has no `timeout-minutes`")
            if "runs-on" not in job_has:
                report(job_line, "unreadable", f"the job `{job}` has no `runs-on`")

    command_indent = None
    for index, line in enumerate(lines):
        number, bare = index + 1, code(line)
        if not line.strip():
            continue
        if "\t" in line[:indent(line) + 1]:
            report(number, "unreadable", "a tab where YAML wants spaces")
        if command_indent is not None and indent(line) <= command_indent:
            command_indent = None
        # Deeper in than a job's own keys: a job or an input may well be called `shell` or `script`.
        in_steps = indent(line) >= 6 and jobs_at is not None and index > jobs_at if is_workflow else indent(line) >= 4
        opened = re.match(r"^(\s*)(-\s+)?(run|script|shell):", bare) if command_indent is None and in_steps else None
        if command_indent is not None or opened:
            for found in EXPRESSION.finditer(line):
                if not found.group(2) or not NOBODY_TYPES.match(found.group(1)):
                    report(number, "no text in commands", f"{found.group(0)} in a command: hand it over in `env:` and write \"$NAME\"")
            if privileged and OF_THE_PULL_REQUEST.search(line):
                report(number, "no strangers' code with a token", "strangers can start this workflow, it holds the repository's token, and this command reaches for a pull request's code")
            if opened:
                command_indent = len(opened.group(1)) + len(opened.group(2) or "")
            continue

        if ODD_KEY.search(bare):
            report(number, "unreadable", "a key in quotes, in braces, with a space before its colon or with its value on the next line: write it plainly, `key: value`")
        if jobs_at is not None and index > jobs_at and bare.strip():
            key = re.match(r"^  ([\w.-]+):\s*(.*)$", bare)
            if key:
                close_job()
                job, job_line, job_has, jobs_seen = key.group(1), number, set(), jobs_seen + 1
            elif job is None:
                report(number, "unreadable", "the line after `jobs:` is no job's name two spaces in")
                job = ""
            inner = re.match(r"^    ([\w-]+):\s*(.*)$", bare)
            if inner and job:
                job_has.add(inner.group(1))
                value = inner.group(2).strip()
                if inner.group(1) == "runs-on":
                    label = value.strip("'\"")
                    chosen = CHOSEN.match(value)
                    offered = (choices(head, chosen.group(1)) or ["whatever is typed"]) + [chosen.group(2) or "ubuntu-latest"] if chosen else []
                    if chosen and all(FREE.match(option) for option in offered):
                        pass
                    elif "self-hosted" in label:
                        report(number, "free", "`self-hosted`: in a public repository a stranger's pull request would run its code on that machine")
                    else:
                        if not FREE.match(label):
                            report(number, "free", f"`{label}` is not one of GitHub's free hosted runners, written out (ubuntu-latest, macos-26 …)")
                elif inner.group(1) == "timeout-minutes" and not (re.match(r"^\d{1,3}$", value) and 0 < int(value) <= LONGEST):
                    report(number, "limited", f"`timeout-minutes: {value}`: a plain number of minutes, {LONGEST} at most")
                elif inner.group(1) == "uses" and not value.startswith("./"):
                    report(number, "free", "a workflow in another repository: nobody can tell from here what it runs on, or for how long")
        if re.search(r"\bself-hosted\b", bare) and not re.match(r"^    runs-on:", bare):
            report(number, "free", "`self-hosted`: in a public repository a stranger's pull request would run its code on that machine")

        uses = USES.match(line)
        if uses and not uses.group(2).startswith(("./", "docker://")):
            if not PINNED.match(uses.group(2).strip("'\"")) or uses.group(2) != uses.group(2).strip("'\""):
                report(number, "pinned", f"{uses.group(2)} is not named by a commit's full id; `scripts/lint-workflows.py --pin` rewrites it")
            elif not VERSION_REMARK.match(uses.group(3)):
                report(number, "pinned", f"say which version {uses.group(2)[:-32]}… is, as a remark and nothing else: `# v5.1.0` (Dependabot reads it too)")
        if uses and uses.group(2).startswith("docker://") and "@sha256:" not in uses.group(2):
            report(number, "pinned", f"{uses.group(2)} is not named by its digest (@sha256:…)")
        if privileged and OF_THE_PULL_REQUEST.search(bare):
            report(number, "no strangers' code with a token",
                   "strangers can start this workflow, it holds the repository's token, and here it reaches for a pull request's own commit, branch or build")
    close_job()
    if is_workflow and jobs_at is not None and not jobs_seen:
        report(jobs_at + 1, "unreadable", "no job below `jobs:`")
    return problems


def files():
    found = []
    for pattern in (".github/workflows/*.yml", ".github/workflows/*.yaml", ".github/actions/*/action.yml", ".github/actions/*/action.yaml"):
        found += glob.glob(os.path.join(ROOT, pattern))
    return sorted(found)


# MARK: --pin

def tags_of(action, ls_remote):
    """Version tags of an action's repository, each with the commit it stands for."""
    listed = dict(reversed(line.split("\t", 1)) for line in ls_remote("https://github.com/" + "/".join(action.split("/")[:2])).splitlines() if "\t" in line)
    tags = {name[len("refs/tags/"):] for name in listed if name.startswith("refs/tags/") and not name.endswith("^{}")}
    # A tag with a message of its own is an object; the commit behind it is listed under its name with ^{}.
    return {tag: listed.get(f"refs/tags/{tag}^{{}}") or listed[f"refs/tags/{tag}"] for tag in tags if VERSION.match(tag)}


def most_exact(tags, sha):
    """Of the versions that name a commit, the one that says most: v5.1.0 rather than v5."""
    same = [tag for tag, commit in tags.items() if commit == sha]
    return max(same, key=lambda tag: (tag.count("."), [int(part) for part in tag.lstrip("v").split(".")]), default=None)


def pinned(text, ls_remote):
    """The text with every `uses:` that names a version rewritten, and what could not be."""
    lines, failed = text.split("\n"), []
    for index, line in enumerate(lines):
        uses = USES.match(line)
        if not uses or uses.group(2).startswith(("./", "docker://")) or PINNED.match(uses.group(2)) or "@" not in uses.group(2):
            continue
        action, ref = uses.group(2).rsplit("@", 1)
        tags = tags_of(action, ls_remote)
        if ref in tags:
            lines[index] = f"{uses.group(1)}{action}@{tags[ref]} # {most_exact(tags, tags[ref])}"
        else:
            failed.append(f"{uses.group(2)}: its repository has no version of that name (a branch moves, so there is nothing to pin it to)")
    return "\n".join(lines), failed


def unverified(text, ls_remote):
    """Every pin that is not the commit its remark says, going by the action's own repository."""
    wrong = []
    for line in text.split("\n"):
        uses = USES.match(line)
        remark = VERSION_REMARK.match(uses.group(3)) if uses and PINNED.match(uses.group(2)) else None
        if remark:
            action, sha = uses.group(2).rsplit("@", 1)
            tags = tags_of(action, ls_remote)
            if tags.get(remark.group(1)) != sha:
                wrong.append(f"{action}@{sha[:12]}… is not what {remark.group(1)} names in its repository")
            elif most_exact(tags, sha) != remark.group(1):
                wrong.append(f"{action}@{sha[:12]}…: say {most_exact(tags, sha)}, not {remark.group(1)}: Dependabot keeps only an exact version current")
    return wrong


ANSWERS = {}


def ask_github(url):
    if url not in ANSWERS:
        try:
            done = subprocess.run(["git", "ls-remote", url], capture_output=True, text=True, timeout=60, check=False,
                                  env=dict(os.environ, GIT_TERMINAL_PROMPT="0"))
            if done.returncode != 0:
                print(f"{url}: {done.stderr.strip()[:200]}", file=sys.stderr)
            ANSWERS[url] = done.stdout if done.returncode == 0 else ""
        except subprocess.TimeoutExpired:
            print(f"{url}: no answer within a minute", file=sys.stderr)
            ANSWERS[url] = ""
    return ANSWERS[url]


# MARK: --self-test

GOOD = """name: X
on:
  pull_request:
permissions:
  contents: read
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      contents: write # to push
    steps:
      - uses: actions/checkout@0123456789012345678901234567890123456789 # v5.1.0
      - uses: ./.github/actions/mac-setup
      - name: Say it
        env:
          TITLE: ${{ github.event.pull_request.title }}
        run: |
          echo "$TITLE" ${{ github.sha }} ${{ runner.temp }}
"""


def self_test():
    def rules(text, name=".github/workflows/x.yml"):
        return sorted({re.search(r"\[(.*?)\]", problem).group(1) for problem in problems_in(text, name)})

    def changed(old, new):
        assert old in GOOD, old
        return GOOD.replace(old, new)

    def choice(options):
        return changed("  pull_request:", f"  workflow_dispatch:\n    inputs:\n      runner:\n        type: choice\n        options: {options}").replace(
            "ubuntu-latest", "${{ inputs.runner || 'macos-26' }}")

    sha = "0123456789012345678901234567890123456789"
    cases = [
        ("a workflow as it should be", rules(GOOD), []),
        ("an action by its tag", rules(changed(f"checkout@{sha} # v5.1.0", "checkout@v5")), ["pinned"]),
        ("by a branch", rules(changed(f"checkout@{sha} # v5.1.0", "checkout@main")), ["pinned"]),
        ("by a short id", rules(changed(f"checkout@{sha} # v5.1.0", "checkout@0123456 # v5")), ["pinned"]),
        ("by a commit, without saying which version", rules(changed(" # v5.1.0", "")), ["pinned"]),
        ("a part of an action's repository", rules(changed(f"actions/checkout@{sha}", f"actions/cache/restore@{sha}")), []),
        ("`uses:` as a step's second key", rules(changed(f"      - uses: actions/checkout@{sha} # v5.1.0", "      - name: Out\n        uses: actions/checkout@v5")), ["pinned"]),
        ("an image by its tag", rules(changed("./.github/actions/mac-setup", "docker://alpine:3")), ["pinned"]),
        ("a composite action is read too", rules("runs:\n  using: composite\n  steps:\n    - uses: actions/cache@v4\n", ".github/actions/x/action.yml"), ["pinned"]),
        ("a Mac", rules(changed("ubuntu-latest", "macos-26")), []),
        ("a larger Mac", rules(changed("ubuntu-latest", "macos-26-xlarge")), ["free"]),
        ("a larger Linux machine", rules(changed("ubuntu-latest", "ubuntu-latest-8-cores")), ["free"]),
        ("a machine of one's own", rules(changed("ubuntu-latest", "self-hosted")), ["free"]),
        ("the same in a list", rules(changed("ubuntu-latest", "[self-hosted, macOS]")), ["free"]),
        ("the same in a list over several lines", rules(changed("runs-on: ubuntu-latest", "runs-on:\n      - self-hosted")), ["free", "unreadable"]),
        ("a label that was never a runner's", rules(changed("ubuntu-latest", "ubuntu-latest-arm")), ["free"]),
        ("the small one", rules(changed("ubuntu-latest", "ubuntu-slim")), []),
        ("a label nobody can read off the page", rules(changed("ubuntu-latest", "${{ inputs.runner || 'macos-26' }}")), ["free"]),
        ("an input that offers free runners only", rules(choice("[macos-26, macos-15-intel]")), []),
        ("the same with the list over several lines", rules(choice("\n          - macos-26\n          - macos-15")), []),
        ("one of the choices is paid for", rules(choice("[macos-26, macos-26-xlarge]")), ["free"]),
        ("an input people type into", rules(choice("[macos-26]").replace("type: choice", "type: string")), ["free"]),
        ("the label used when nothing was chosen is paid for", rules(choice("[macos-26]").replace("|| 'macos-26'", "|| 'macos-26-large'")), ["free"]),
        ("the words in a remark", rules(changed("name: X", "name: X\n# never self-hosted")), []),
        ("no time limit", rules(changed("    timeout-minutes: 5\n", "")), ["limited"]),
        ("a time limit on a step only", rules(changed("    timeout-minutes: 5\n", "").replace("      - name: Say it", "      - name: Say it\n        timeout-minutes: 5")), ["limited"]),
        ("the second job has none", rules(GOOD + "  more:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo\n"), ["limited"]),
        ("a job that calls a workflow of this repository needs neither", rules(GOOD + "  more:\n    uses: ./.github/workflows/z.yml\n"), []),
        ("a job that calls a workflow of another", rules(GOOD + f"  more:\n    uses: x/y/.github/workflows/z.yml@{sha} # v1\n"), ["free"]),
        ("a time limit nobody can read off the page", rules(changed("timeout-minutes: 5", "timeout-minutes: ${{ inputs.minutes }}")), ["limited"]),
        ("a time limit of a week", rules(changed("timeout-minutes: 5", "timeout-minutes: 10000")), ["limited"]),
        ("a time limit of two hours", rules(changed("timeout-minutes: 5", "timeout-minutes: 120")), []),
        ("a time limit of three", rules(changed("timeout-minutes: 5", "timeout-minutes: 180")), ["limited"]),
        ("nothing said about the token", rules(changed("permissions:\n  contents: read\njobs:", "jobs:")), ["permissions"]),
        ("the top lets every job write", rules(changed("permissions:\n  contents: read\n", "permissions:\n  contents: write\n")), ["permissions"]),
        ("the top lets every job write everything", rules(changed("permissions:\n  contents: read\n", "permissions: write-all\n")), ["permissions"]),
        ("the same in braces", rules(changed("permissions:\n  contents: read\n", "permissions: {contents: write}\n")), ["permissions"]),
        ("the same in quotes", rules(changed("permissions:\n  contents: read\n", "permissions:\n  contents: 'write'\n")), ["permissions"]),
        ("the same after a remark at the margin", rules(changed("permissions:\n  contents: read\n", "permissions:\n  contents: read\n# and\n  issues: write\n")), ["permissions"]),
        ("the word in a remark", rules(changed("  contents: read\n", "  contents: read # jobs that write say so\n")), []),
        ("the top grants nothing", rules(changed("permissions:\n  contents: read\n", "permissions: {}\n")), []),
        ("a title in a command", rules(changed('echo "$TITLE"', 'echo "${{ github.event.pull_request.title }}"')), ["no text in commands"]),
        ("a branch's name in a command", rules(changed('echo "$TITLE"', "git checkout ${{ github.head_ref }}")), ["no text in commands"]),
        ("an input in a command of one line", rules(changed("        run: |\n", "        run: echo ${{ inputs.tag }}\n      - run: |\n")), ["no text in commands"]),
        ("what was handed over in `env:`, written as an expression all the same", rules(changed('echo "$TITLE"', "echo ${{ env.TITLE }}")), ["no text in commands"]),
        ("the whole event", rules(changed('echo "$TITLE"', "echo '${{ toJSON(github.event) }}'")), ["no text in commands"]),
        ("in brackets", rules(changed('echo "$TITLE"', "echo ${{ github['head_ref'] }}")), ["no text in commands"]),
        ("an earlier step's output", rules(changed('echo "$TITLE"', "echo ${{ steps.x.outputs.y }}")), ["no text in commands"]),
        ("the token", rules(changed('echo "$TITLE"', "curl -H 'Authorization: ${{ github.token }}'")), ["no text in commands"]),
        ("an expression over two lines", rules(changed('echo "$TITLE"', "echo ${{ github.sha ||\n            github.head_ref }}")), ["no text in commands"]),
        ("something harmless and something else in one expression", rules(changed('echo "$TITLE"', "echo ${{ github.sha && github.head_ref }}")), ["no text in commands"]),
        ("a block that says how far it is indented", rules(changed("run: |\n", "run: |2\n").replace('echo "$TITLE"', "echo ${{ inputs.x }}")), ["no text in commands"]),
        ("a command that goes on in the next line", rules(changed('        run: |\n          echo "$TITLE"', "        run: echo\n          ${{ inputs.x }}")), ["no text in commands"]),
        ("a command that begins in the next line", rules(changed('        run: |\n          echo "$TITLE"', "        run:\n          echo ${{ inputs.x }}")), ["no text in commands"]),
        ("a script for an action that runs scripts", rules(GOOD + f"      - uses: actions/github-script@{sha} # v8\n        with:\n          script: |\n            log('${{{{ inputs.x }}}}')\n"),
         ["no text in commands"]),
        ("the shell itself", rules(GOOD + "      - run: echo\n        shell: ${{ inputs.shell }}\n"), ["no text in commands"]),
        ("a job and an input that are called like a command's keys", rules(changed("  build:", "  shell:").replace(
            "  pull_request:", "  workflow_dispatch:\n    inputs:\n      script:\n        type: string")), []),
        ("in a composite action", rules("runs:\n  using: composite\n  steps:\n    - run: echo ${{ inputs.x }}\n      shell: bash\n", ".github/actions/x/action.yml"), ["no text in commands"]),
        ("after the command's block has ended", rules(GOOD + "      - name: ${{ inputs.tag }}\n        run: echo\n"), []),
        ("a workflow with a token, minding its own business", rules(changed("  pull_request:", "  pull_request_target:")), []),
        ("the same checking out the pull request", rules(changed("  pull_request:", "  pull_request_target:").replace(
            " # v5.1.0", " # v5.1.0\n        with:\n          ref: ${{ github.event.pull_request.head.sha }}")), ["no strangers' code with a token"]),
        ("an ordinary pull request's workflow may", rules(changed(" # v5.1.0", " # v5.1.0\n        with:\n          ref: ${{ github.event.pull_request.head.sha }}")), []),
        ("after another workflow", rules(changed("  pull_request:", "  workflow_run:\n    workflows: [CI]").replace(
            'echo "$TITLE"', 'git fetch origin "$HEAD"').replace("TITLE: ${{ github.event.pull_request.title }}", "HEAD: ${{ github.event.workflow_run.head_branch }}")),
         ["no strangers' code with a token"]),
        ("the same fetching it in a command", rules(changed("  pull_request:", "  pull_request_target:").replace('echo "$TITLE"', 'git fetch origin "pull/$N/head"')),
         ["no strangers' code with a token"]),
        ("with GitHub's own tool", rules(changed("  pull_request:", "  pull_request_target:").replace('echo "$TITLE"', 'gh pr checkout "$N"')), ["no strangers' code with a token"]),
        ("the fork's repository", rules(changed("  pull_request:", "  pull_request_target:").replace(
            " # v5.1.0", " # v5.1.0\n        with:\n          repository: ${{ github.event.pull_request.head.repo.full_name }}")), ["no strangers' code with a token"]),
        ("started by a comment", rules(changed("  pull_request:", "  issue_comment:").replace(
            " # v5.1.0", " # v5.1.0\n        with:\n          ref: refs/pull/${{ github.event.issue.number }}/head")), ["no strangers' code with a token"]),
        ("the trigger as an item of a list", rules(changed("  pull_request:", "  - pull_request_target").replace(
            " # v5.1.0", " # v5.1.0\n        with:\n          ref: ${{ github.event.pull_request.head.sha }}")), ["no strangers' code with a token"]),
        ("the trigger in brackets", rules(changed("on:\n  pull_request:", "on: [push, pull_request_target]").replace(
            " # v5.1.0", " # v5.1.0\n        with:\n          ref: ${{ github.event.pull_request.head.sha }}")), ["no strangers' code with a token"]),
        ("what another run built", rules(changed("  pull_request:", "  workflow_run:\n    workflows: [CI]").replace(
            "./.github/actions/mac-setup", f"actions/download-artifact@{sha} # v4.3.0")), ["no strangers' code with a token"]),
        ("a step in braces", rules(GOOD + "      - { uses: actions/checkout@v5 }\n"), ["unreadable"]),
        ("steps in brackets", rules(GOOD + "  more:\n    runs-on: ubuntu-latest\n    timeout-minutes: 5\n    steps: [{uses: a/b@v1}]\n"), ["unreadable"]),
        ("a key in quotes", rules(GOOD + '      - "uses": a/b@v1\n'), ["unreadable"]),
        ("a space before the colon", rules(GOOD + "      - uses : a/b@v1\n"), ["unreadable"]),
        ("the action's name on the next line", rules(GOOD + "      - uses:\n          a/b@v1\n"), ["unreadable"]),
        ("the action's name in quotes", rules(GOOD + '      - uses: "a/b@v1"\n'), ["pinned"]),
        ("four spaces a level", rules("name: X\non: push\npermissions: {}\njobs:\n    build:\n        runs-on: macos-26-xlarge\n        steps:\n            - run: echo\n"), ["unreadable"]),
        ("a job's name in quotes", rules('name: X\non: push\npermissions: {}\njobs:\n  "build":\n    runs-on: macos-26-xlarge\n'), ["unreadable"]),
        ("line ends as Windows writes them", rules(GOOD.replace("\n", "\r\n")), []),
        ("an input that another workflow can set to what it likes", rules(choice("[macos-26]").replace("  workflow_dispatch:", "  workflow_call:\n  workflow_dispatch:")), ["free"]),
        ("no triggers at all", rules(changed("on:\n  pull_request:\n", "")), ["unreadable"]),
        ("no jobs at all", rules("name: X\non: push\npermissions: {}\n"), ["unreadable"]),
    ]
    A, B, C, D, E = ("a" * 40, "b" * 40, "c" * 40, "d" * 40, "e" * 40)
    listing = "".join(f"{commit}\t{name}\n" for commit, name in [
        (A, "refs/heads/main"), (B, "refs/tags/v5"), (B, "refs/tags/v5.1"), (B, "refs/tags/v5.1.0"), (B, "refs/tags/release.5.1.0.final"), (B, "refs/tags/v5.1.0-rc.1"),
        (C, "refs/tags/v4"), (D, "refs/tags/v4^{}"), (D, "refs/tags/v4.10.0"), (D, "refs/tags/v4.9.0"), (E, "refs/tags/v3")])
    asked = []

    def ls_remote(url):
        asked.append(url)
        return listing
    cases += [
        ("--pin: a tag becomes its commit, and the remark the exact version",
         pinned("      - uses: actions/checkout@v5\n", ls_remote), (f"      - uses: actions/checkout@{B} # v5.1.0\n", [])),
        ("--pin: a tag with a message of its own stands for the commit behind it; of two versions the later",
         pinned("        uses: actions/cache/save@v4 # old remark", ls_remote), (f"        uses: actions/cache/save@{D} # v4.10.0", [])),
        ("--pin: it asks the action's repository, not a folder in it", asked[-1], "https://github.com/actions/cache"),
        ("--pin: a version that is not there is left and named", [pinned("- uses: a/b@v9", ls_remote)[0], len(pinned("- uses: a/b@v9", ls_remote)[1])], ["- uses: a/b@v9", 1]),
        ("--pin: so is a branch, which moves", [pinned("- uses: a/b@main", ls_remote)[0], len(pinned("- uses: a/b@main", ls_remote)[1])], ["- uses: a/b@main", 1]),
        ("--pin: what is pinned, and what is local, stays", pinned(GOOD, ls_remote), (GOOD, [])),
        ("--pin: what it writes, the lint takes", rules(changed(f"actions/checkout@{sha} # v5.1.0", pinned("actions/checkout@v5", ls_remote)[0]).replace(
            "      - uses: actions/checkout@v5", pinned("      - uses: actions/checkout@v5", ls_remote)[0])), []),
        ("--verify: the commit the version names", unverified(f"- uses: a/b@{B} # v5.1.0", ls_remote), []),
        ("--verify: some other commit, as of a fork", len(unverified(f"- uses: a/b@{A} # v5.1.0", ls_remote)), 1),
        ("--verify: a version that is not there", len(unverified(f"- uses: a/b@{B} # v9.9.9", ls_remote)), 1),
        ("--verify: the right commit under a version that says too little", len(unverified(f"- uses: a/b@{B} # v5", ls_remote)), 1),
        ("--verify: a version that has no more exact name", unverified(f"- uses: a/b@{E} # v3", ls_remote), []),
        ("--verify: no answer from the repository is no yes", len(unverified(f"- uses: a/b@{B} # v5.1.0", lambda url: "")), 1),
    ]
    failed = [f"{what}: got {got!r}, expected {wanted!r}" for what, got, wanted in cases if got != wanted]
    for line in failed:
        print("lint-workflows self-test:", line)
    return 1 if failed else 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    problems = []
    for path in files():
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        name = os.path.relpath(path, ROOT)
        if "--pin" in sys.argv:
            rewritten, failed = pinned(text, ask_github)
            problems += [f"{name}: {what}" for what in failed]
            if rewritten != text:
                with open(path, "w", encoding="utf-8") as handle:
                    handle.write(rewritten)
                print(f"{name}: pinned")
        elif "--verify" in sys.argv:
            problems += [f"{name}: [pinned] {what}" for what in unverified(text, ask_github)]
        else:
            problems += problems_in(text, name)
    for line in problems:
        print(line)
    if not problems and "--pin" not in sys.argv:
        print("every pin is the commit its remark says" if "--verify" in sys.argv else "the workflows keep to the rules")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
