#!/usr/bin/env python3
"""Checks that splitting CI's Linux work into jobs that run side by side has lost nothing.

One job ran everything, one step after another, and could not forget any. Several can: a new job that the last one does
not wait for fails without anybody noticing, a job or a step that may be skipped proves nothing, and a step of
`make check` that no job took over is simply not run (two were not, for as long as the list was kept by hand). So this
reads .github/workflows/ci.yml and the Makefile and says what does not hold:

  every job on a Linux runner is named linux-… (but `changes`), and the job `linux` needs it, and needs no other;
  `linux` runs whatever became of them and fails unless each succeeded: its script is run here, on made-up results;
  no Linux job and no step of one has a condition that could skip it, and none may fail and pass all the same;
  every command of `make check`, as it stands there, is a command of some Linux job, and so is what ALSO lists;
  all of them use the same image, which scripts/linux.sh takes from the first.

Then it holds itself to a table of workflows that are wrong in one way each. `make lint` runs this. It reads the files as
text: the Swift image has no YAML parser, and the few shapes that matter are easy to tell.
Exit code 1 when something does not hold or a row comes out wrong.
"""

import json
import os
import re
import shlex
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERDICT = "linux"
# On Linux too, but it decides about the Mac and proves nothing about the code.
NOT_A_CHECK = {"changes"}
# What CI's Linux jobs run beyond `make check`.
ALSO = ["make typecheck-mac", "scripts/parity.py --test-log test.log --check", "scripts/test-ci-changes.py",
        "scripts/test-mac-queue.py"]
JOB = re.compile(r"""^  ["']?([A-Za-z_][\w-]*)["']?:\s*(?:#.*)?$""")
KEY = re.compile(r"^(\s*)(?:- )?([\w-]+):\s*(.*)$")
# They only widen when something runs.
HARMLESS = {"${{ !cancelled() }}", "${{ always() }}"}


def jobs_of(workflow):
    """Each job's name with its lines, comments left out."""
    jobs, name, inside = {}, None, False
    for line in workflow.split("\n"):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if re.match(r"^\S", line):
            inside = line.startswith("jobs:")
        elif inside and JOB.match(line):
            name = JOB.match(line).group(1)
            jobs[name] = []
        elif inside and name:
            jobs[name].append(line)
    return jobs


def values_of(lines, wanted, depth=None):
    """What stands after each `wanted:` in a job, at any depth or `depth` spaces in."""
    found = [KEY.match(line) for line in lines]
    return [key.group(3).strip() for key in found if key and key.group(2) == wanted and depth in (None, len(key.group(1)))]


def scripts_of(lines):
    """The text of each `run:` of a job, be it one line or a block."""
    scripts, index = [], 0
    while index < len(lines):
        key = KEY.match(lines[index])
        index += 1
        if not key or key.group(2) != "run":
            continue
        if key.group(3).strip() not in ("|", ">", "|-", ">-"):
            scripts.append(key.group(3).strip())
            continue
        # The key may stand after "- ", which counts as indentation.
        margin = len(lines[index - 1]) - len(lines[index - 1].lstrip(" -"))
        block = []
        while index < len(lines) and len(lines[index]) - len(lines[index].lstrip()) > margin:
            block.append(lines[index])
            index += 1
        indent = min(len(line) - len(line.lstrip()) for line in block) if block else 0
        scripts.append("\n".join(line[indent:] for line in block))
    return scripts


def plain(command):
    """A command without what does not change what it checks: make's @, ci-step.py and its options, python3, ./"""
    command = command.strip().lstrip("@")
    try:
        words = shlex.split(command)
    except ValueError:
        return command
    if words and words[0].endswith("scripts/ci-step.py"):
        words = words[1:]
        while words and words[0] in ("--summary", "--log"):
            words = words[2:]
        words = words[1:]
    if words and words[0] == "python3":
        words = words[1:]
    if words and words[0].startswith("./"):
        words[0] = words[0][2:]
    return " ".join(words)


def steps_of(makefile, target, seen=()):
    """The commands `make <target>` runs, those of the targets it depends on first. None if there is no such rule."""
    rule = re.search(rf"^{re.escape(target)}:(.*)\n((?:(?:\t|#).*\n)*)", makefile, re.M)
    if not rule:
        return None
    steps = []
    for needed in rule.group(1).split():
        if needed not in seen:
            steps += steps_of(makefile, needed, (*seen, target)) or []
    return steps + [plain(line) for line in rule.group(2).splitlines() if line.startswith("\t")]


def verdict_on(script, results):
    """The exit code of the verdict's script when the jobs it waits for ended like this."""
    needs = json.dumps({name: {"result": result, "outputs": {}} for name, result in results.items()})
    environment = {**os.environ, "RESULTS": needs}
    return subprocess.run(["bash", "-e", "-c", script], env=environment, capture_output=True, check=False).returncode


def problems_in(workflow, makefile):
    jobs = jobs_of(workflow)
    if VERDICT not in jobs:
        return [f"there is no job `{VERDICT}`"]
    parts = sorted(name for name in jobs if name.startswith(VERDICT + "-"))
    found = [f"{name} runs on Linux and is not named {VERDICT}-…, so nobody waits for it"
             for name, lines in jobs.items() if name not in (*parts, VERDICT, *NOT_A_CHECK)
             and any("ubuntu" in value for value in values_of(lines, "runs-on"))]

    needs = sorted(re.findall(r"[\w-]+", " ".join(values_of(jobs[VERDICT], "needs", 4))))
    found += [f"`{VERDICT}` does not wait for {name}" for name in parts if name not in needs]
    found += [f"`{VERDICT}` waits for {name}, which is no Linux job" for name in needs if name not in parts]
    if not parts:
        found.append(f"`{VERDICT}` has nothing to wait for")
    if not set(values_of(jobs[VERDICT], "if", 4)) & HARMLESS:
        found.append(f"`{VERDICT}` is skipped when a job it waits for fails: it needs `if: ${{{{ !cancelled() }}}}`")
    if "${{ toJSON(needs) }}" not in values_of(jobs[VERDICT], "RESULTS"):
        found.append(f"`{VERDICT}` is not told how the jobs it waits for ended (RESULTS: ${{{{ toJSON(needs) }}}})")
    script = "\n".join(scripts_of(jobs[VERDICT]))
    good = {name: "success" for name in parts or ["linux-x"]}
    if verdict_on(script, good) != 0:
        found.append(f"`{VERDICT}` fails though every job succeeded")
    for result in ("failure", "cancelled", "skipped"):
        if verdict_on(script, {**good, sorted(good)[-1]: result}) == 0:
            found.append(f"`{VERDICT}` passes though a job ended as {result}")
    if verdict_on(script, {}) == 0:
        found.append(f"`{VERDICT}` passes though it heard of no job")

    for name in parts:
        for needed in re.findall(r"[\w-]+", " ".join(values_of(jobs[name], "needs", 4))):
            if needed not in parts:
                found.append(f"{name} waits for {needed}, which is no Linux job and may be skipped, and then so is {name}")
    for name in (*parts, VERDICT):
        for condition in values_of(jobs[name], "if"):
            if condition not in HARMLESS:
                found.append(f"{name} has a condition, `{condition}`: what is skipped proves nothing")
        if values_of(jobs[name], "continue-on-error"):
            found.append(f"{name} may fail and pass all the same (continue-on-error)")
    images = sorted({image for name in parts for image in values_of(jobs[name], "container", 4)})
    if len(images) > 1:
        found.append(f"the Linux jobs use different images: {', '.join(images)}")

    run = {plain(line) for name in parts for script in scripts_of(jobs[name]) for line in script.split("\n")}
    for command in sorted(run):
        words = command.split()
        if words[:1] == ["make"] and all(steps_of(makefile, word) is not None for word in words[1:]):
            run |= {step for word in words[1:] for step in steps_of(makefile, word)}
    check = steps_of(makefile, "check")
    if not check:
        found.append("the Makefile has no `check`, or it runs nothing")
    found += [f"`make check` runs `{step}`, and no Linux job does" for step in check or [] if step not in run]
    found += [f"no Linux job runs `{step}` any more" for step in ALSO if step not in run]
    return found


GOOD = """
jobs:
  changes:
    runs-on: ubuntu-latest
  macos:
    runs-on: macos-26
    if: ${{ needs.changes.outputs.mac != 'false' }}
    steps:
      - run: swift build
  linux-a:
    runs-on: ubuntu-latest
    steps:
      - run: ./scripts/ci-step.py lint make lint
      - run: ./scripts/ci-step.py ci-changes ./scripts/test-ci-changes.py
      - run: ./scripts/ci-step.py mac-queue ./scripts/test-mac-queue.py
      - name: Build
        run: ./scripts/ci-step.py --summary 'warning:' build swift build
      - run: ./scripts/ci-step.py typecheck-mac make typecheck-mac
  linux-b:
    runs-on: ubuntu-latest
    container: swift:1
    steps:
      - run: ./scripts/ci-step.py --log test.log test swift test
      - run: ./scripts/ci-step.py smoke ./scripts/smoke.sh
      - run: ./scripts/ci-step.py parity python3 scripts/parity.py --test-log test.log --check
  linux:
    needs: [linux-a, linux-b]
    if: ${{ !cancelled() }}
    runs-on: ubuntu-latest
    steps:
      - env:
          RESULTS: ${{ toJSON(needs) }}
        run: |
          echo "$RESULTS" | grep -q '"result"'
          ! echo "$RESULTS" | grep -oE '"result": *"[a-z]+"' | grep -qv success
"""
MAKEFILE = """
lint:
\t@python3 scripts/lint-a.py --self-test && python3 scripts/lint-a.py
build:
\tswift build
test:
\tswift test
check: lint build test
\t@./scripts/smoke.sh
typecheck-mac:
\t@./scripts/typecheck-mac/check.sh
"""
SMOKE = "      - run: ./scripts/ci-step.py smoke ./scripts/smoke.sh\n"
NEEDS = "needs: [linux-a, linux-b]"
CONDITION = NEEDS + "\n    if: ${{ !cancelled() }}"
LAST = """          ! echo "$RESULTS" | grep -oE '"result": *"[a-z]+"' | grep -qv success\n"""


def changed(old, new, text=GOOD):
    assert old in text, old
    return text.replace(old, new)


# What must be said (a part of it; None: nothing), the situation, the workflow, the Makefile.
TABLE = [
    (None, "all is well", GOOD, MAKEFILE),
    (None, "a step that runs even after a failure", changed(SMOKE, SMOKE + "      - if: ${{ !cancelled() }}\n        run: true\n"), MAKEFILE),
    ("does not wait for linux-b", "a job nobody waits for", changed(NEEDS, "needs: [linux-a]"), MAKEFILE),
    ("does not wait for linux-b", "the same, with a comment after its name", changed("  linux-b:", "  linux-b: # more", changed(NEEDS, "needs: [linux-a]")), MAKEFILE),
    ("does not wait for linux-b", "the same, its name in quotation marks", changed("  linux-b:", '  "linux-b":', changed(NEEDS, "needs: [linux-a]")), MAKEFILE),
    ("does not wait for linux-c", "a new job after a comment at the margin", GOOD + "# more\n  linux-c:\n    steps:\n      - run: false\n", MAKEFILE),
    ("linux-b waits for changes", "a job that waits for one that may be skipped", changed("  linux-b:\n", "  linux-b:\n    needs: changes\n"), MAKEFILE),
    (None, "a job that waits for another Linux job", changed("  linux-b:\n", "  linux-b:\n    needs: [linux-a]\n"), MAKEFILE),
    ("fuzz runs on Linux", "a job on Linux by another name", GOOD + "  fuzz:\n    runs-on: ubuntu-latest\n    steps:\n      - run: false\n", MAKEFILE),
    ("waits for macos", "the verdict waits for a Mac", changed(NEEDS, "needs: [linux-a, linux-b, macos]"), MAKEFILE),
    ("waits for linux-c", "a job that was renamed", changed(NEEDS, "needs: [linux-a, linux-b, linux-c]"), MAKEFILE),
    ("is skipped when", "the verdict has no condition", changed(CONDITION, NEEDS), MAKEFILE),
    ("is skipped when", "the verdict runs only after success", changed(CONDITION, NEEDS + "\n    if: ${{ success() }}"), MAKEFILE),
    ("is not told", "the verdict hears nothing", changed("${{ toJSON(needs) }}", "{}"), MAKEFILE),
    ("passes though a job ended as failure", "the verdict looks at nothing", changed(LAST, "          true\n"), MAKEFILE),
    ("passes though a job ended as skipped", "the verdict minds only failures", changed(LAST, """          ! echo "$RESULTS" | grep -q '"failure"'\n"""), MAKEFILE),
    ("passes though a job ended as failure", "the verdict's answer is thrown away", changed(LAST, LAST.rstrip("\n") + " || true\n"), MAKEFILE),
    ("passes though it heard of no job", "the verdict is content with nothing", changed("""          echo "$RESULTS" | grep -q '"result"'\n""", ""), MAKEFILE),
    ("fails though every job succeeded", "the verdict never passes", changed(LAST, "          false\n"), MAKEFILE),
    ("linux may fail and pass", "the verdict may fail", changed(CONDITION, CONDITION + "\n    continue-on-error: true"), MAKEFILE),
    ("linux has a condition", "the verdict's step may be skipped", changed("      - env:\n", "      - if: ${{ failure() }}\n        env:\n"), MAKEFILE),
    ("linux-a has a condition", "a job that may be skipped", changed("  linux-a:\n", "  linux-a:\n    if: ${{ false }}\n"), MAKEFILE),
    ("linux-b has a condition", "a step that may be skipped", changed(SMOKE, "      - if: ${{ false }}\n  " + SMOKE.replace("- ", "  ")), MAKEFILE),
    ("linux-b may fail and pass", "a job that may fail", changed("  linux-b:\n", "  linux-b:\n    continue-on-error: true\n"), MAKEFILE),
    ("linux-b may fail and pass", "a step that may fail", changed(SMOKE, "      - continue-on-error: true\n  " + SMOKE.replace("- ", "  ")), MAKEFILE),
    ("there is no job", "no verdict at all", changed("  linux:\n", "  verdict:\n"), MAKEFILE),
    ("nothing to wait for", "no jobs but the verdict", changed(NEEDS, "needs: []").replace("linux-a", "a").replace("linux-b", "b"), MAKEFILE),
    ("different images", "one job on another image", changed("  linux-a:\n    runs-on: ubuntu-latest\n", "  linux-a:\n    runs-on: ubuntu-latest\n    container: swift:2\n"), MAKEFILE),
    ("runs `scripts/smoke.sh`", "a step of make check was dropped", changed(SMOKE, ""), MAKEFILE),
    ("runs `scripts/smoke.sh`", "it is only spoken of, in a comment", changed(SMOKE, "      # ./scripts/smoke.sh runs elsewhere\n"), MAKEFILE),
    ("runs `scripts/smoke.sh`", "it is only spoken of, in a name", changed(SMOKE, "      - name: scripts/smoke.sh\n        run: true\n"), MAKEFILE),
    ("runs `scripts/smoke.sh`", "a name speaks of make check", changed(SMOKE, "      - name: make check\n        run: true\n"), MAKEFILE),
    ("runs `scripts/smoke.sh`", "its failure is thrown away", changed(SMOKE, SMOKE.rstrip("\n") + " || true\n"), MAKEFILE),
    (None, "it stands in a block", changed(SMOKE, "      - run: |\n          echo first\n          ./scripts/smoke.sh\n"), MAKEFILE),
    ("runs `scripts/new.sh`", "make check has a new step", GOOD, changed("smoke.sh\n", "smoke.sh\n\t@./scripts/new.sh\n", MAKEFILE)),
    ("runs `scripts/new.sh`", "a new step after a comment", GOOD, changed("smoke.sh\n", "smoke.sh\n# And then:\n\t@./scripts/new.sh\n", MAKEFILE)),
    ("runs `scripts/smoke.sh && ./scripts/new.sh`", "a new step on an old line", GOOD, changed("smoke.sh\n", "smoke.sh && ./scripts/new.sh\n", MAKEFILE)),
    ("runs `swift test`", "the tests run only on the Mac", changed("test swift test", "test true").replace("- run: swift build", "- run: swift test"), MAKEFILE),
    ("runs `swift test`", "only some of the tests run", changed("test swift test", "test swift test --filter Geometry"), MAKEFILE),
    ("lint-a.py", "lint was dropped", changed("      - run: ./scripts/ci-step.py lint make lint\n", ""), MAKEFILE),
    ("lint-a.py", "lint is only printed", changed("lint make lint", "lint make lint -n"), MAKEFILE),
    ("runs `scripts/lint-b.py`", "a lint that make check runs by another way", GOOD,
     changed("check: lint build test", "more:\n\t@python3 scripts/lint-b.py\ncheck: lint more build test", MAKEFILE)),
    ("has no `check`", "make check was renamed", GOOD, changed("check:", "verify:", MAKEFILE)),
    ("runs `scripts/parity.py", "parity was dropped", changed("      - run: ./scripts/ci-step.py parity python3 scripts/parity.py --test-log test.log --check\n", ""), MAKEFILE),
    ("runs `scripts/parity.py", "parity no longer minds FEATURES.md", changed("test.log --check", "test.log"), MAKEFILE),
    ("runs `make typecheck-mac`", "the type-check was dropped", changed("typecheck-mac make typecheck-mac", "typecheck-mac true"), MAKEFILE),
    ("runs `scripts/test-ci-changes.py`", "the Mac's rules go unchecked", changed("      - run: ./scripts/ci-step.py ci-changes ./scripts/test-ci-changes.py\n", ""), MAKEFILE),
]


def main():
    wrong = 0
    for expected, situation, workflow, makefile in TABLE:
        said = problems_in(workflow, makefile)
        if (not said) if expected is None else any(expected in problem for problem in said):
            continue
        wrong += 1
        print(f"✘ {situation}: expected {expected or 'nothing'}, got {said or 'nothing'}")
    print(f"{len(TABLE) - wrong} of {len(TABLE)} workflows judged as expected")

    with open(os.path.join(ROOT, ".github", "workflows", "ci.yml"), encoding="utf-8") as handle:
        workflow = handle.read()
    with open(os.path.join(ROOT, "Makefile"), encoding="utf-8") as handle:
        makefile = handle.read()
    found = problems_in(workflow, makefile)
    for problem in found:
        print(f"✘ ci.yml: {problem}")
    if not found:
        parts = [name for name in jobs_of(workflow) if name.startswith(VERDICT + "-")]
        print(f"ci.yml: `{VERDICT}` waits for {', '.join(parts)}; between them they run all of `make check`")
    return 1 if wrong or found else 0


if __name__ == "__main__":
    sys.exit(main())
