#!/usr/bin/env python3
"""Checks that splitting CI's Linux work into jobs that run side by side has lost nothing.

One job ran everything, one step after another, and could not forget any. Several can: a new job that the last one does not wait
for fails without anybody noticing, a job that may be skipped never reports success, and a step of `make check` that no
job took over is simply not run (two were not, for as long as the list was kept by hand). So this reads
.github/workflows/ci.yml and the Makefile and says what does not hold:

  every job named linux-… is in the `needs` of the job `linux`, and `linux` needs nothing else;
  `linux` runs whatever became of them, and asks each for "success";
  no other Linux job has a condition, so none can end as "skipped";
  whatever `make check` runs, some Linux job runs.

Then it holds itself to a table of workflows that are wrong in one way each. The job linux-lint runs this. It reads the files as text:
the Swift image has no YAML parser, and the two levels of indentation that matter are easy to tell.
Exit code 1 when something does not hold or a row comes out wrong.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERDICT = "linux"
JOB = re.compile(r"^  ([A-Za-z_][\w-]*):\s*$")
KEY = re.compile(r"^    ([\w-]+):\s*(.*)$")
# What a recipe line of `make check` runs: the script, or the tool when it is no script of ours.
SCRIPT = re.compile(r"scripts/[\w./-]+")


def jobs_of(workflow):
    """Each job's name with its text, comments left out, and its own keys (`needs`, `if`, …), as written."""
    jobs, name, inside = {}, None, False
    for line in workflow.split("\n"):
        if re.match(r"^\S", line):
            inside = line.startswith("jobs:")
            continue
        if not inside:
            continue
        job = JOB.match(line)
        if job:
            name = job.group(1)
            jobs[name] = {"text": "", "keys": {}}
        elif name and not line.lstrip().startswith("#"):
            jobs[name]["text"] += line + "\n"
            key = KEY.match(line)
            if key:
                jobs[name]["keys"][key.group(1)] = key.group(2).strip()
    return jobs


def steps_of_check(makefile, target="check", seen=()):
    """What `make check` runs: the scripts its recipe names, the commands of the targets it depends on."""
    rule = re.search(rf"^{re.escape(target)}:(.*)\n((?:\t.*\n)*)", makefile, re.M)
    if not rule or target in seen:
        return []
    steps = [step for needed in rule.group(1).split() for step in steps_of_check(makefile, needed, (*seen, target))]
    for line in rule.group(2).splitlines():
        scripts = SCRIPT.findall(line)
        steps += scripts[:1] if scripts else [line.strip().lstrip("@")]
    return steps


def problems_in(workflow, makefile):
    jobs = jobs_of(workflow)
    parts = sorted(name for name in jobs if name.startswith(VERDICT + "-"))
    if VERDICT not in jobs:
        return [f"there is no job `{VERDICT}`"]
    found = []
    verdict = jobs[VERDICT]
    needs = sorted(re.findall(r"[\w-]+", verdict["keys"].get("needs", "")))
    found += [f"`{VERDICT}` does not wait for {name}" for name in parts if name not in needs]
    found += [f"`{VERDICT}` waits for {name}, which is no Linux job" for name in needs if name not in parts]
    if not parts:
        found.append(f"`{VERDICT}` has nothing to wait for")
    if verdict["keys"].get("if") not in ("${{ !cancelled() }}", "${{ always() }}"):
        found.append(f"`{VERDICT}` is skipped when a job it waits for fails: it needs `if: ${{{{ !cancelled() }}}}`")
    if "toJSON(needs)" not in verdict["text"] or '.result == "success"' not in verdict["text"]:
        found.append(f"`{VERDICT}` does not ask every job it waits for whether it succeeded")
    for name in parts:
        if "if" in jobs[name]["keys"]:
            found.append(f"{name} has a condition: a skipped job never reports success")
        if "continue-on-error" in jobs[name]["text"]:
            found.append(f"{name} may fail and pass all the same (continue-on-error)")
    run = "".join(jobs[name]["text"] for name in parts)
    # `make lint` stands for the scripts in its recipe.
    for target in re.findall(r"\bmake ([\w-]+)", run):
        run += " ".join(steps_of_check(makefile, target))
    found += [f"`make check` runs `{step}`, and no Linux job does" for step in steps_of_check(makefile) if step not in run]
    return found


GOOD = """
jobs:
  macos:
    if: ${{ !cancelled() }}
    steps:
      - run: swift build
  linux-a:
    steps:
      - run: ./scripts/ci-step.py lint make lint
      - run: ./scripts/ci-step.py build swift build
  linux-b:
    steps:
      - run: ./scripts/ci-step.py test swift test
      - run: ./scripts/ci-step.py smoke ./scripts/smoke.sh
  linux:
    needs: [linux-a, linux-b]
    if: ${{ !cancelled() }}
    steps:
      - env:
          RESULTS: ${{ toJSON(needs) }}
        run: jq -e 'all(.[]; .result == "success")' <<<"$RESULTS"
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
"""

# What must be said (a part of it; None: nothing), the situation, the workflow, the Makefile.
TABLE = [
    (None, "all is well", GOOD, MAKEFILE),
    ("does not wait for linux-b", "a job nobody waits for", GOOD.replace("[linux-a, linux-b]", "[linux-a]"), MAKEFILE),
    ("waits for macos", "the verdict waits for a Mac", GOOD.replace("[linux-a, linux-b]", "[linux-a, linux-b, macos]"), MAKEFILE),
    ("waits for linux-c", "a job that was renamed", GOOD.replace("[linux-a, linux-b]", "[linux-a, linux-b, linux-c]"), MAKEFILE),
    ("is skipped when", "the verdict has no condition",
     GOOD.replace("needs: [linux-a, linux-b]\n    if: ${{ !cancelled() }}", "needs: [linux-a, linux-b]"), MAKEFILE),
    ("is skipped when", "the verdict runs only after success",
     GOOD.replace("linux-b]\n    if: ${{ !cancelled() }}", "linux-b]\n    if: ${{ success() }}"), MAKEFILE),
    ("does not ask", "the verdict looks at nothing", GOOD.replace('.result == "success"', "true"), MAKEFILE),
    ("does not ask", "the verdict minds only failures", GOOD.replace('.result == "success"', '.result != "failure"'), MAKEFILE),
    ("linux-a has a condition", "a job that may be skipped", GOOD.replace("  linux-a:\n", "  linux-a:\n    if: ${{ false }}\n"), MAKEFILE),
    ("may fail and pass", "a job that may fail", GOOD.replace("  linux-b:\n", "  linux-b:\n    continue-on-error: true\n"), MAKEFILE),
    ("may fail and pass", "a step that may fail",
     GOOD.replace("      - run: ./scripts/ci-step.py test swift test", "      - continue-on-error: true\n        run: swift test"), MAKEFILE),
    ("there is no job", "no verdict at all", GOOD.replace("  linux:\n", "  verdict:\n"), MAKEFILE),
    ("nothing to wait for", "no jobs but the verdict",
     GOOD.replace("linux-a", "a").replace("linux-b", "b").replace("needs: [a, b]", "needs: []"), MAKEFILE),
    ("runs `scripts/smoke.sh`", "a step of make check was dropped", GOOD.replace("      - run: ./scripts/ci-step.py smoke ./scripts/smoke.sh\n", ""), MAKEFILE),
    ("runs `scripts/smoke.sh`", "a step of make check is only spoken of",
     GOOD.replace("      - run: ./scripts/ci-step.py smoke ./scripts/smoke.sh\n", "      # ./scripts/smoke.sh runs elsewhere\n"), MAKEFILE),
    ("runs `scripts/new.sh`", "make check has a new step", GOOD, MAKEFILE + "\t@./scripts/new.sh\n"),
    ("runs `swift test`", "the tests run only on the Mac",
     GOOD.replace("test swift test", "test true").replace("- run: swift build", "- run: swift test"), MAKEFILE),
    ("runs `scripts/lint-a.py`", "lint was dropped", GOOD.replace("      - run: ./scripts/ci-step.py lint make lint\n", ""), MAKEFILE),
    ("runs `scripts/lint-b.py`", "a lint that make check runs by another way", GOOD,
     MAKEFILE.replace("check: lint build test", "more:\n\t@python3 scripts/lint-b.py\ncheck: lint more build test")),
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
