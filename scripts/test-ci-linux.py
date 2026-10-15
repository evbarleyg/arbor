#!/usr/bin/env python3
"""Checks that splitting CI's Linux work into jobs that run side by side has lost nothing.

One job ran everything, one step after another, and could not forget any. Several can: a new job that the last one does
not wait for fails without anybody noticing, a job or a step that may be skipped proves nothing, and a step of
`make check` that no job took over is simply not run (two were not, for as long as the list was kept by hand). So this
reads .github/workflows/linux.yml, ci.yml, which calls it, and the Makefile, and says what does not hold:

  ci.yml calls linux.yml in a job `linux`, always, and no other workflow; its other jobs on Linux runners are those of NOT_A_CHECK
  and the few that speak for the Mac job;
  every job of linux.yml is named linux-…, has a shorter name for its check, and `linux-verdict` needs it, and needs no other;
  `linux-verdict` runs whatever became of them, and before anything else fails unless each succeeded: that script is run
  here, on made-up results;
  no Linux job and no step of one has a condition that could skip it, and none may fail and pass all the same. But for ONE switch:
  ci.yml may ask for lint alone (`all: false`, for a pull request that is still a draft). Then every job but lint is skipped and the
  verdict with them: whenever there is a verdict, all it waits for has run. The switch is used in the jobs' conditions and nowhere
  else. Marking the draft ready must start a run, and nothing else may be said about which pull requests start one. A push to
  `main` and a merge train (`train/…`), where the sum of what was landed is tried, must start one, whatever they change. What in
  ci.yml goes by Linux's record, or vouches for a run, does not run for a draft either;
  the closing of a pull request starts a run that ends the one under way (one group for all runs of a pull request, by its number)
  and takes no runner: every job of ci.yml says so itself, or falls with one that does;
  every command of `make check`, as it stands there, is a command of some Linux job, and so is what ALSO lists;
  the jobs that use an image use the same, which scripts/linux.sh takes from the first in linux.yml. But `oldest-swift` in ci.yml,
  which is there for the oldest Swift that README.md promises: it has another, compiles everything and type-checks the
  macOS-only code, and what it runs counts for nothing above (or dropping the type-check with the newest would go unnoticed);
  `tests-whole` runs plain `swift test` and holds it against the record that `linux-verdict` hands on, under the same names.

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
PREFIX, VERDICT = "linux-", "linux-verdict"
# The job of ci.yml that stands for all of them, and what it must say.
CALLER, CALLED = "linux", "./.github/workflows/linux.yml"
# Jobs of ci.yml on Linux runners that are not part of the verdict: `changes` decides about the Mac and proves nothing
# about the code; `tests-whole` runs only where work is integrated, takes twelve minutes, and whoever integrates waits
# for it by name; `oldest-swift` takes eleven, and whoever lands reads it by name.
WHOLE_JOB, OLDEST_JOB = "tests-whole", "oldest-swift"
NOT_A_CHECK = {"changes", WHOLE_JOB, OLDEST_JOB}
OLDEST_RUNS = ["swift build --build-tests", "make typecheck-mac"]
# On Linux runners because they need no Mac, but what they say is about the macOS job, after which they run and with which they are
# skipped. Each is a check of its own, by its own name: what real windows said there, whether every test ran there or here, that it
# had built from nothing.
OF_THE_MAC = {"real-windows", "tests-accounted-for", "macos-from-nothing"}
# What that job must run, and what is handed from the verdict to it.
WHOLE_RUNS = ["swift test", "scripts/fast-tests.py same whole.jsonl linux.tsv"]
HANDED_ON = ("tests-linux", "linux.tsv")
# What CI's Linux jobs run beyond `make check`.
ALSO = ["make typecheck-mac", "scripts/parity.py --report test-*.jsonl --check", "scripts/test-ci-changes.py",
        "scripts/test-mac-queue.py", "scripts/test-ci-tests.py"]
# What stands for a command of `make check`: all of these together, or it does not count. The tests are divided among several
# machines (scripts/fast-tests.py): each cuts out its part, builds it and runs it, and one job holds the parts against the sources.
INSTEAD = {"swift test": [
    "scripts/fast-tests.py cut $PART $PARTS",
    "swift build --build-tests",
    "scripts/fast-tests.py run --no-build --events test-$PART.jsonl",
    "scripts/fast-tests.py join --record linux.tsv test-*.jsonl",
], "scripts/test-tooling.py": [
    # The rows that need a build where there is one, the others, three minutes of them, on a machine of their own.
    "scripts/test-tooling.py --only scenarios rehearse",
    "scripts/test-tooling.py --but scenarios rehearse",
]}
# Of `make check`, but no check: it forgets the record of the run before, as fast-tests.py does by itself.
TIDYING = {"rm -f $(TEST_REPORT)"}
JOB = re.compile(r"""^  ["']?([A-Za-z_][\w-]*)["']?:\s*(?:#.*)?$""")
KEY = re.compile(r"^(\s*)(?:- )?([\w-]+):\s*(.*)$")
# They only widen when something runs.
HARMLESS = {"${{ !cancelled() }}", "${{ always() }}"}
# The one switch: what a job may say, what the verdict must then say, what ci.yml may hand over, and the job that runs whatever it hands over.
SWITCH, SWITCHED_VERDICT = "${{ inputs.all }}", "${{ inputs.all && !cancelled() }}"
NOT_A_DRAFT = "github.event_name != 'pull_request' || !github.event.pull_request.draft"
WHEN_ALL = "${{ " + NOT_A_DRAFT + " }}"
# What is said of pull requests, no more and no less. A filter (paths, branches, fewer types) stops runs without a word, and a commit
# without a run has no check that failed.
FOR_PULL_REQUESTS = ["types: [opened, synchronize, reopened, ready_for_review, closed]"]
# The last of them is there to end the run under way, which it does by being of the same group; and for nothing else.
OPEN = "github.event.action != 'closed'"
GROUP = ["group: ci-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}", "cancel-in-progress: true"]
# Where the sum of what was landed is tried, whatever its parts were spared.
FOR_PUSHES = ['branches: [main, "train/**"]']
WHOLE_WHEN = "${{ " + OPEN + " && (github.event_name != 'pull_request' || (github.base_ref == 'main' && !github.event.pull_request.draft)) }}"
OLDEST_WHEN = "${{ " + OPEN + " && (" + NOT_A_DRAFT + ") }}"
# They go by the record Linux leaves, or say that a run was complete.
NOT_FOR_DRAFTS = ("tests-accounted-for", "macos-from-nothing")
ALWAYS = "linux-lint"


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
        while words and words[0] in ("--summary", "--log", "--report"):
            words = words[2:]
        words = words[1:]
    if words and words[0] == "python3":
        words = words[1:]
    if words and words[0].startswith("./"):
        words[0] = words[0][2:]
    # And so is `make test`: where the record goes does not change what runs. $(TEST_ARGS) is empty unless somebody fills it.
    if words[:2] == ["swift", "test"] and words[2::2][:2] == ["--event-stream-output-path", "--event-stream-version"]:
        words = ["swift", "test", *(word for word in words[6:] if word != "$(TEST_ARGS)")]
    # It builds the same, and leaves out the index that only an editor reads.
    if words[:2] == ["swift", "build"]:
        words = [word for word in words if word != "--disable-index-store"]
    # `swift test` on everything, which also leaves a record of what ran.
    if words[:5] == ["scripts/ci-tests.py", "run", "--mode", "full", "--record"] and len(words) > 5:
        words = ["swift", "test", *words[6:]]
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


def events_of(caller):
    """What starts a workflow: the event → the lines under it, remarks left out."""
    events, name = {}, None
    for line in (re.search(r"^on:\n((?:(?: .*)?\n)*)", caller, re.M) or [None, ""])[1].split("\n"):
        if not line.strip() or line.strip().startswith("#"):
            continue
        if re.match(r"  \S", line):
            name, _, rest = line.strip().partition(":")
            events[name] = [rest.strip()] if rest.strip() else []
        elif name:
            events[name].append(line.strip())
    return events


def all_of(condition):
    """What a condition asks for all at once: the parts of `${{ a && b && (c || d) }}`. One part where an `||` stands outside all brackets."""
    parts, depth, text = [""], 0, re.sub(r"^\$\{\{\s*|\s*\}\}$", "", condition.strip())
    for index, letter in enumerate(text):
        depth += (letter == "(") - (letter == ")")
        if depth == 0 and text[index:index + 2] == "||":
            return [text]
        if depth == 0 and text[index:index + 2] == "&&":
            parts.append("")
        elif not (depth == 0 and text[index - 1:index + 1] == "&&"):
            parts[-1] += letter
    return [part.strip() for part in parts]


def taken_when_closed(jobs):
    """The jobs that would run for a pull request that was closed. One does not if it says so; nor if it waits for one that does not and either goes by
    the rule (a job is skipped when one it needs was) or asks for that job's result. `!cancelled()` and the like put the rule out of force: a job
    with one of them runs after a skipped job, whose outputs are empty, and empty is not 'false'."""
    spared = set()
    while True:
        before = len(spared)
        for name, lines in jobs.items():
            conditions = values_of(lines, "if", 4)
            asked = [part for condition in conditions for part in all_of(condition)]
            fallen = [need for need in re.findall(r"[\w-]+", " ".join(values_of(lines, "needs", 4))) if need in spared]
            by_the_rule = not re.search(r"\b(cancelled|always|failure)\(\)", " ".join(conditions))
            if OPEN in asked or fallen and (by_the_rule or any(f"needs.{need}.result {how}" in asked for need in fallen for how in ("!= 'skipped'", "== 'success'"))):
                spared.add(name)
        if len(spared) == before:
            return [name for name in jobs if name not in spared]


def verdict_on(script, results):
    """The exit code of the verdict's script when the jobs it waits for ended like this."""
    needs = json.dumps({name: {"result": result, "outputs": {}} for name, result in results.items()})
    environment = {**os.environ, "RESULTS": needs}
    return subprocess.run(["bash", "-e", "-c", script], env=environment, capture_output=True, check=False).returncode


def problems_in(workflow, makefile, caller):
    jobs, others = jobs_of(workflow), jobs_of(caller)
    found = []
    if values_of(others.get(CALLER, []), "uses", 4) != [CALLED]:
        found.append(f"ci.yml has no job `{CALLER}` that uses {CALLED}")
    elif [line.strip() for line in others[CALLER][1:]] not in ([], ["if: ${{ " + OPEN + " }}", "with:", f"all: {WHEN_ALL}"]):
        found.append(f"ci.yml's job `{CALLER}` says more than what it uses, that drafts get lint alone and that a closed pull request gets nothing: "
                     "but for that it must run always, and wait for nothing")
    elif len(others[CALLER]) > 1:
        if events_of(caller).get("pull_request") != FOR_PULL_REQUESTS:
            found.append(f"a draft gets lint alone, so `pull_request:` must say `{FOR_PULL_REQUESTS[0]}` and nothing else: without the last of them "
                         "marking a draft ready starts no run, and a filter stops runs without a word")
        if [line.replace("'", '"') for line in events_of(caller).get("push", [])] != FOR_PUSHES:
            found.append(f"`push:` must say `{FOR_PUSHES[0]}` and nothing else: a push to main or a merge train that starts no run leaves the sum untried")
        if values_of(others.get(WHOLE_JOB, []), "if", 4) != [WHOLE_WHEN]:
            found.append(f"`{WHOLE_JOB}` must say `if: {WHOLE_WHEN}`: where work is integrated, and not for a draft, which has no parts to hold it against")
        group = re.search(r"^concurrency:\n((?:  .*\n)*)", caller, re.M)
        if [line.strip() for line in (group[1] if group else "").splitlines()] != GROUP:
            found.append(f"`concurrency:` must say `{GROUP[0]}` and `{GROUP[1]}`: the closing of a pull request ends the run under way by being of its group, "
                         "and the ref of one that was merged is the branch it went into")
        found += [f"{name} would take a runner for a pull request that was closed: it neither says `{OPEN}` (with `&&`, outside all brackets) nor falls with a job that does"
                  for name in taken_when_closed(others)]
        found += [f"{name} runs for a draft too, where Linux left no record: its condition lacks `({NOT_A_DRAFT})`" for name in NOT_FOR_DRAFTS
                  if name in others and not any(f"({NOT_A_DRAFT})" in condition for condition in values_of(others[name], "if", 4))]
    found += [f"{name} in ci.yml runs on Linux, so nobody waits for it: it belongs in linux.yml" for name, lines in others.items()
              if name not in (*NOT_A_CHECK, *OF_THE_MAC) and any("ubuntu" in value for value in values_of(lines, "runs-on"))]
    found += [f"{name} in ci.yml calls another workflow, whose jobs nothing here looks at" for name, lines in others.items()
              if name != CALLER and values_of(lines, "uses", 4)]
    found += [f"{name} is not named {PREFIX}…" for name in jobs if not name.startswith(PREFIX)]
    found += [f"{name} has no `name:`, so its check would be called `{CALLER} / {name}`" for name, lines in jobs.items()
              if not values_of(lines, "name", 4)]
    whole = others.get(WHOLE_JOB, [])
    ran = {plain(line) for script in scripts_of(whole) for line in script.split("\n")}
    found += [f"`{WHOLE_JOB}` does not run `{command}`" for command in WHOLE_RUNS if command not in ran]
    if HANDED_ON[0] not in values_of(whole, "name"):
        found.append(f"`{WHOLE_JOB}` does not fetch `{HANDED_ON[0]}`")
    if values_of(whole, "continue-on-error"):
        found.append(f"{WHOLE_JOB} may fail and pass all the same (continue-on-error)")
    oldest = others.get(OLDEST_JOB, [])
    ran = {plain(line) for script in scripts_of(oldest) for line in script.split("\n")}
    found += [f"`{OLDEST_JOB}` does not run `{command}`" for command in OLDEST_RUNS if command not in ran]
    if "ALL: 1" not in [line.strip() for line in oldest]:
        found.append(f"`{OLDEST_JOB}` type-checks only a part of the macOS-only code (ALL: 1)")
    if values_of(oldest, "if") != ([OLDEST_WHEN] if len(others.get(CALLER, [])) > 1 else []) or values_of(oldest, "needs", 4):
        found.append(f"{OLDEST_JOB} has a condition other than that drafts get lint alone and closed pull requests nothing, or waits for a job that may be skipped: what is skipped proves nothing")
    if values_of(oldest, "continue-on-error"):
        found.append(f"{OLDEST_JOB} may fail and pass all the same (continue-on-error)")
    if VERDICT not in jobs:
        return found + [f"there is no job `{VERDICT}`"]
    parts = sorted(name for name in jobs if name != VERDICT)

    needs = sorted(re.findall(r"[\w-]+", " ".join(values_of(jobs[VERDICT], "needs", 4))))
    found += [f"`{VERDICT}` does not wait for {name}" for name in parts if name not in needs]
    found += [f"`{VERDICT}` waits for {name}, which is no Linux job" for name in needs if name not in parts]
    if not parts:
        found.append(f"`{VERDICT}` has nothing to wait for")
    switched = sorted(name for name in parts if values_of(jobs[name], "if", 4) == [SWITCH])
    if not set(values_of(jobs[VERDICT], "if", 4)) & ({SWITCHED_VERDICT} if switched else HARMLESS):
        found.append(f"`{VERDICT}` is skipped when a job it waits for fails: it needs `if: ${{{{ !cancelled() }}}}`" if not switched else
                     f"`{VERDICT}` must say `if: {SWITCHED_VERDICT}`: with lint alone it would ask jobs that did not run, or be skipped at the first failure")
    if switched:
        if ALWAYS in switched or ALWAYS not in parts:
            found.append(f"{ALWAYS} must run whatever ci.yml asks for")
        found += [f"{name} runs even when ci.yml asks for lint alone" for name in parts if name not in (*switched, ALWAYS)]
        if not re.search(r"^      all:\n        type: boolean\n        default: true$", workflow, re.M):
            found.append("whoever calls linux.yml and says nothing must get all of it: `all` needs `type: boolean` and `default: true`, and no more")
    found += [f"the switch is used elsewhere than in a job's own condition, where nothing here can follow it: `{line.strip()}`" for line in workflow.split("\n")
              if re.search(r"\binputs\s*[.\[]", line) and not line.strip().startswith("#") and line not in (f"    if: {SWITCH}", f"    if: {SWITCHED_VERDICT}")]
    told = [index for index, line in enumerate(jobs[VERDICT]) if line.strip() == "RESULTS: ${{ toJSON(needs) }}"]
    if not told:
        found.append(f"`{VERDICT}` is not told how the jobs it waits for ended (RESULTS: ${{{{ toJSON(needs) }}}})")
    elif values_of(jobs[VERDICT][:told[0]], "run") or values_of(jobs[VERDICT][:told[0]], "uses"):
        found.append(f"`{VERDICT}` does something else before it asks how the jobs ended")
    script = (scripts_of(jobs[VERDICT][told[0] if told else 0:]) or ["true"])[0]
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
    for name in jobs:
        # The job's own may be the switch. A step's may not: the job would report success without it.
        own, every = values_of(jobs[name], "if", 4), values_of(jobs[name], "if")
        of_steps = every[len(own):] if every[:len(own)] == own else every
        for condition in (*(each for each in own if each != (SWITCHED_VERDICT if name == VERDICT else SWITCH)), *of_steps):
            if condition not in HARMLESS:
                found.append(f"{name} has a condition, `{condition}`: what is skipped proves nothing")
        if values_of(jobs[name], "continue-on-error"):
            found.append(f"{name} may fail and pass all the same (continue-on-error)")
    if HANDED_ON[0] not in values_of(jobs[VERDICT], "name") or HANDED_ON[1] not in values_of(jobs[VERDICT], "path"):
        found.append(f"`{VERDICT}` does not hand on `{HANDED_ON[1]}` as `{HANDED_ON[0]}`")
    images = sorted({image for name, lines in (*jobs.items(), *others.items()) if name != OLDEST_JOB for image in values_of(lines, "container", 4)})
    if len(images) > 1:
        found.append(f"the jobs use different images: {', '.join(images)}")
    if values_of(oldest, "container", 4) in ([], images):
        found.append(f"`{OLDEST_JOB}` has no image of its own: it is there for the oldest Swift")
    if not any(values_of(lines, "container", 4) for lines in jobs.values()):
        found.append("no job of linux.yml names an image any more, and scripts/linux.sh takes its from there")

    run = {plain(line) for lines in jobs.values() for script in scripts_of(lines) for line in script.split("\n")}
    for command in sorted(run):
        words = command.split()
        if words[:1] == ["make"] and all(steps_of(makefile, word) is not None for word in words[1:]):
            run |= {step for word in words[1:] for step in steps_of(makefile, word)}
    run |= {step for step, commands in INSTEAD.items() if all(command in run for command in commands)}
    check = steps_of(makefile, "check")
    if not check:
        found.append("the Makefile has no `check`, or it runs nothing")
    found += [f"`make check` runs `{step}`, and no Linux job does" for step in check or [] if step not in run | TIDYING]
    found += [f"no Linux job runs `{step}` any more" for step in ALSO if step not in run]
    return found


CI = """
jobs:
  changes:
    runs-on: ubuntu-latest
  macos:
    runs-on: macos-26
    if: ${{ needs.changes.outputs.mac != 'false' }}
    steps:
      - run: swift build
  linux:
    uses: ./.github/workflows/linux.yml
  tests-whole:
    if: ${{ github.event_name == 'push' }}
    runs-on: ubuntu-latest
    container: swift:1
    steps:
      - run: ./scripts/ci-step.py test swift test --event-stream-output-path whole.jsonl --event-stream-version 0
      - uses: actions/download-artifact@v4
        with:
          name: tests-linux
      - run: ./scripts/ci-step.py same ./scripts/fast-tests.py same whole.jsonl linux.tsv
  oldest-swift:
    runs-on: ubuntu-latest
    container: swift:0
    steps:
      - run: ./scripts/ci-step.py older swift build --build-tests
      - env:
          ALL: 1
        run: ./scripts/ci-step.py older-typecheck make typecheck-mac
"""
GOOD = """
jobs:
  linux-a:
    name: a
    runs-on: ubuntu-latest
    steps:
      - run: ./scripts/ci-step.py lint make lint
      - run: ./scripts/ci-step.py ci-changes ./scripts/test-ci-changes.py
      - run: ./scripts/ci-step.py mac-queue ./scripts/test-mac-queue.py
      - run: ./scripts/ci-step.py ci-tests ./scripts/test-ci-tests.py
      - name: Build
        run: ./scripts/ci-step.py --summary 'warning:' build swift build
      - run: ./scripts/ci-step.py typecheck-mac make typecheck-mac
  linux-b:
    name: b
    runs-on: ubuntu-latest
    container: swift:1
    steps:
      - run: ./scripts/ci-step.py --report test.jsonl test swift test
      - run: ./scripts/ci-step.py smoke ./scripts/smoke.sh
  linux-verdict:
    name: verdict
    needs: [linux-a, linux-b]
    if: ${{ !cancelled() }}
    runs-on: ubuntu-latest
    steps:
      - env:
          RESULTS: ${{ toJSON(needs) }}
        run: |
          echo "$RESULTS" | grep -q '"result"'
          ! echo "$RESULTS" | grep -oE '"result": *"[a-z]+"' | grep -qv success
      - run: ./scripts/ci-step.py parity python3 scripts/parity.py --report test-*.jsonl --check
      - uses: actions/upload-artifact@v4
        with:
          name: tests-linux
          path: linux.tsv
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
# The same two with the one switch: linux-lint stands for linux-a there.
DRAFTS = (GOOD.replace("linux-a", "linux-lint").replace("jobs:\n", "on:\n  workflow_call:\n    inputs:\n      all:\n        type: boolean\n        default: true\njobs:\n", 1)
          .replace("    name: b\n", "    name: b\n    if: ${{ inputs.all }}\n").replace("    if: ${{ !cancelled() }}\n", "    if: ${{ inputs.all && !cancelled() }}\n"))
PUSHES = '  push:\n    # Where work is integrated.\n    branches: [main, "train/**"]\n'
TYPES = "    types: [opened, synchronize, reopened, ready_for_review, closed]\n"
ONE_GROUP = "concurrency:\n  " + GROUP[0] + "\n  " + GROUP[1] + "\n"
IF_OPEN = "    if: ${{ " + OPEN + " }}\n"
MAC_WHEN = "${{ !cancelled() && " + OPEN + " && needs.changes.outputs.mac != 'false' }}"
CI_DRAFTS = ("on:\n" + PUSHES + "  pull_request:\n" + TYPES + ONE_GROUP
             + CI.replace("linux.yml\n", "linux.yml\n" + IF_OPEN + "    with:\n      all: " + WHEN_ALL + "\n").replace("${{ github.event_name == 'push' }}", WHOLE_WHEN)
             .replace("  changes:\n", "  changes:\n" + IF_OPEN).replace("    if: ${{ needs.changes.outputs.mac != 'false' }}\n", "    needs: changes\n    if: " + MAC_WHEN + "\n")
             .replace("    container: swift:0\n", "    container: swift:0\n    if: " + OLDEST_WHEN + "\n")
             + "  tests-accounted-for:\n    needs: [changes, linux, macos]\n    if: ${{ !cancelled() && needs.macos.result != 'skipped' && (" + NOT_A_DRAFT + ") }}\n    runs-on: ubuntu-latest\n"
             + "  macos-from-nothing:\n    needs: [changes, macos]\n    if: ${{ needs.macos.result == 'success' && (" + NOT_A_DRAFT + ") }}\n    runs-on: ubuntu-latest\n")
WHOLE = "      - run: ./scripts/ci-step.py --report test.jsonl test swift test\n"
WITH_A_RECORD = "\t@rm -f $(TEST_REPORT)\n\tswift test --event-stream-output-path $(TEST_REPORT) --event-stream-version 0 $(TEST_ARGS)\n"
TOOLING = "      - run: ./scripts/ci-step.py tooling python3 scripts/test-tooling.py\n"
WITH_TOOLING = MAKEFILE.replace("\t@./scripts/smoke.sh\n", "\t@./scripts/smoke.sh\n\t@python3 scripts/test-tooling.py\n")
DIVIDED = "".join(f"      - run: ./scripts/ci-step.py x ./{command}\n".replace("./swift", "swift") for command in INSTEAD["swift test"])
SMOKE = "      - run: ./scripts/ci-step.py smoke ./scripts/smoke.sh\n"
NEEDS = "needs: [linux-a, linux-b]"
CONDITION = NEEDS + "\n    if: ${{ !cancelled() }}"
LAST = """          ! echo "$RESULTS" | grep -oE '"result": *"[a-z]+"' | grep -qv success\n"""


def changed(old, new, text=GOOD):
    assert old in text, old
    return text.replace(old, new)


OLDEST = CI[CI.index("  oldest-swift:"):]

# What must be said (a part of it; None: nothing), the situation, linux.yml, the Makefile, and ci.yml if it is not CI.
TABLE = [
    (None, "all is well", GOOD, MAKEFILE),
    (None, "a step that runs even after a failure", changed(SMOKE, SMOKE + "      - if: ${{ !cancelled() }}\n        run: true\n"), MAKEFILE),
    ("does not wait for linux-b", "a job nobody waits for", changed(NEEDS, "needs: [linux-a]"), MAKEFILE),
    ("does not wait for linux-b", "the same, with a comment after its name", changed("  linux-b:", "  linux-b: # more", changed(NEEDS, "needs: [linux-a]")), MAKEFILE),
    ("does not wait for linux-b", "the same, its name in quotation marks", changed("  linux-b:", '  "linux-b":', changed(NEEDS, "needs: [linux-a]")), MAKEFILE),
    ("does not wait for linux-c", "a new job after a comment at the margin", GOOD + "# more\n  linux-c:\n    name: c\n    steps:\n      - run: false\n", MAKEFILE),
    ("linux-c has no `name:`", "a job whose check would have a long name", changed(NEEDS, "needs: [linux-a, linux-b, linux-c]") + "  linux-c:\n    steps:\n      - run: true\n", MAKEFILE),
    ("linux-b waits for changes", "a job that waits for one that may be skipped", changed("  linux-b:\n", "  linux-b:\n    needs: changes\n"), MAKEFILE),
    (None, "a job that waits for another Linux job", changed("  linux-b:\n", "  linux-b:\n    needs: [linux-a]\n"), MAKEFILE),
    ("fuzz is not named linux-", "a job by another name", GOOD + "  fuzz:\n    runs-on: ubuntu-latest\n    steps:\n      - run: false\n", MAKEFILE),
    ("fuzz in ci.yml runs on Linux", "a job on Linux in ci.yml", GOOD, MAKEFILE, CI + "  fuzz:\n    runs-on: ubuntu-latest\n    steps:\n      - run: false\n"),
    ("no job `linux` that uses", "ci.yml does not call linux.yml", GOOD, MAKEFILE, changed("  linux:\n    uses: ./.github/workflows/linux.yml\n", "", CI)),
    ("no job `linux` that uses", "ci.yml calls something else", GOOD, MAKEFILE, changed("workflows/linux.yml", "workflows/other.yml", CI)),
    ("no job `linux` that uses", "the job that calls it has another name", GOOD, MAKEFILE, changed("  linux:\n", "  headless:\n", CI)),
    ("suite in ci.yml calls another workflow", "ci.yml calls a second workflow", GOOD, MAKEFILE, CI + "  suite:\n    uses: ./.github/workflows/suite.yml\n"),
    ("`tests-whole` does not run `swift test", "the whole is not run", GOOD, MAKEFILE, changed("test swift test --event", "test true --event", CI)),
    ("`tests-whole` does not run `swift test", "only some of the whole is run", GOOD, MAKEFILE, changed("--event-stream-version 0", "--event-stream-version 0 --filter Core", CI)),
    ("`tests-whole` does not run `scripts/fast-tests.py same", "the whole is compared with nothing", GOOD, MAKEFILE,
     changed("      - run: ./scripts/ci-step.py same ./scripts/fast-tests.py same whole.jsonl linux.tsv\n", "", CI)),
    ("`tests-whole` does not fetch", "the whole fetches something else", GOOD, MAKEFILE, changed("name: tests-linux", "name: tests", CI)),
    ("`tests-whole` does not run", "there is no whole at all", GOOD, MAKEFILE, CI[:CI.index("  tests-whole:")]),
    ("tests-whole may fail and pass", "the whole may fail", GOOD, MAKEFILE, changed("    container: swift:1\n", "    container: swift:1\n    continue-on-error: true\n", CI)),
    ("does not hand on", "the record is handed on under another name", changed("name: tests-linux", "name: linux-tests"), MAKEFILE),
    ("does not hand on", "the record is not handed on", changed("          path: linux.tsv\n", "          path: other.tsv\n"), MAKEFILE),
    (None, "drafts get lint alone", DRAFTS, MAKEFILE, CI_DRAFTS),
    (None, "linux.yml has the switch and ci.yml does not use it", DRAFTS, MAKEFILE),
    ("starts no run", "marking a draft ready starts nothing", DRAFTS, MAKEFILE, changed(", ready_for_review", "", CI_DRAFTS)),
    ("starts no run", "no types at all: the usual three, and marking ready is none of them", DRAFTS, MAKEFILE, changed(TYPES, "", CI_DRAFTS)),
    ("starts no run", "a push to a pull request starts nothing", DRAFTS, MAKEFILE, changed("synchronize, ", "", CI_DRAFTS)),
    ("starts no run", "it is said of another event", DRAFTS, MAKEFILE, changed("  pull_request:\n" + TYPES, "  pull_request:\n  pull_request_review:\n" + TYPES, CI_DRAFTS)),
    ("a filter stops runs", "only pull requests that touch some paths", DRAFTS, MAKEFILE, changed(TYPES, TYPES + "    paths: [Sources/**]\n", CI_DRAFTS)),
    ("a filter stops runs", "all but some paths", DRAFTS, MAKEFILE, changed(TYPES, TYPES + "    paths-ignore:\n      - docs/**\n", CI_DRAFTS)),
    ("a filter stops runs", "only pull requests into main", DRAFTS, MAKEFILE, changed(TYPES, "    branches: [main]\n" + TYPES, CI_DRAFTS)),
    (None, "a remark among them", DRAFTS, MAKEFILE, changed(TYPES, "    # Why.\n" + TYPES, CI_DRAFTS)),
    ("leaves the sum untried", "a merge train starts nothing", DRAFTS, MAKEFILE, changed(', "train/**"', "", CI_DRAFTS)),
    ("leaves the sum untried", "only one train does", DRAFTS, MAKEFILE, changed("train/**", "train/1", CI_DRAFTS)),
    ("leaves the sum untried", "a push to main starts nothing", DRAFTS, MAKEFILE, changed("[main, ", "[", CI_DRAFTS)),
    ("leaves the sum untried", "no push starts anything", DRAFTS, MAKEFILE, changed(PUSHES, "", CI_DRAFTS)),
    ("leaves the sum untried", "listed, and taken out again", DRAFTS, MAKEFILE, changed('"train/**"]', '"train/**", "!train/**"]', CI_DRAFTS)),
    ("leaves the sum untried", "only trains that touch some paths", DRAFTS, MAKEFILE, changed('"train/**"]\n', '"train/**"]\n    paths: [Sources/**]\n', CI_DRAFTS)),
    (None, "quoted the other way", DRAFTS, MAKEFILE, changed('"train/**"', "'train/**'", CI_DRAFTS)),
    ("`tests-whole` must say", "the whole on main alone, never on a train", DRAFTS, MAKEFILE, changed(WHOLE_WHEN, "${{ github.ref == 'refs/heads/main' }}", CI_DRAFTS)),
    ("`tests-whole` must say", "the whole runs for a draft into main, and finds no record", DRAFTS, MAKEFILE,
     changed(WHOLE_WHEN, "${{ github.event_name != 'pull_request' || github.base_ref == 'main' }}", CI_DRAFTS)),
    ("`tests-whole` must say", "the whole never runs", DRAFTS, MAKEFILE, changed(WHOLE_WHEN, "${{ false }}", CI_DRAFTS)),
    ("`tests-whole` must say", "the whole always runs", DRAFTS, MAKEFILE, changed("    if: " + WHOLE_WHEN + "\n", "", CI_DRAFTS)),
    ("oldest-swift has a condition", "eleven minutes of the oldest Swift for every push to a draft", DRAFTS, MAKEFILE, changed("    container: swift:0\n    if: " + OLDEST_WHEN + "\n", "    container: swift:0\n" + IF_OPEN, CI_DRAFTS)),
    ("oldest-swift has a condition", "the oldest Swift only where work is integrated: not before trains are how work lands", DRAFTS, MAKEFILE,
     changed("    container: swift:0\n    if: " + OLDEST_WHEN + "\n", "    container: swift:0\n    if: " + WHOLE_WHEN + "\n", CI_DRAFTS)),
    ("tests-accounted-for runs for a draft too", "the account is asked for where Linux left no record", DRAFTS, MAKEFILE, changed("'skipped' && (" + NOT_A_DRAFT + ")", "'skipped'", CI_DRAFTS)),
    ("starts no run", "the closing of a pull request starts nothing, and its last run goes on for nobody", DRAFTS, MAKEFILE, changed(", closed", "", CI_DRAFTS)),
    ("says more than what it uses", "all of Linux for a pull request that was closed", DRAFTS, MAKEFILE, changed("linux.yml\n" + IF_OPEN, "linux.yml\n", CI_DRAFTS)),
    ("says more than what it uses", "Linux is spared on another ground", DRAFTS, MAKEFILE, changed("linux.yml\n" + IF_OPEN, "linux.yml\n    if: ${{ github.actor != 'somebody' }}\n", CI_DRAFTS)),
    ("changes would take a runner", "a job that waits for nothing does not say it", DRAFTS, MAKEFILE, changed("  changes:\n" + IF_OPEN, "  changes:\n", CI_DRAFTS)),
    ("macos would take a runner", "a Mac for every closed pull request: what was skipped said nothing, and nothing is not 'false'", DRAFTS, MAKEFILE,
     changed(MAC_WHEN, "${{ !cancelled() && needs.changes.outputs.mac != 'false' }}", CI_DRAFTS)),
    ("tests-accounted-for would take a runner", "and what asks for the Mac's result goes with it", DRAFTS, MAKEFILE,
     changed(MAC_WHEN, "${{ !cancelled() && needs.changes.outputs.mac != 'false' }}", CI_DRAFTS)),
    ("macos would take a runner", "it says so, or something else", DRAFTS, MAKEFILE, changed(MAC_WHEN, "${{ !cancelled() && (" + OPEN + " || needs.changes.outputs.mac != 'false') }}", CI_DRAFTS)),
    ("macos would take a runner", "the same without brackets", DRAFTS, MAKEFILE, changed(MAC_WHEN, "${{ !cancelled() && " + OPEN + " || needs.changes.outputs.mac != 'false' }}", CI_DRAFTS)),
    ("macos would take a runner", "it says the opposite", DRAFTS, MAKEFILE, changed(MAC_WHEN, MAC_WHEN.replace("!= 'closed'", "== 'closed'"), CI_DRAFTS)),
    ("tests-accounted-for would take a runner", "it runs whatever became of the others, and asks for nobody's result", DRAFTS, MAKEFILE,
     changed("needs.macos.result != 'skipped' && ", "", CI_DRAFTS)),
    ("tidy would take a runner", "a new job that always runs", DRAFTS, MAKEFILE, CI_DRAFTS + "  tidy:\n    needs: macos\n    if: ${{ always() }}\n    runs-on: macos-26\n"),
    ("tidy would take a runner", "a new job that waits for nothing", DRAFTS, MAKEFILE, CI_DRAFTS + "  tidy:\n    runs-on: macos-26\n"),
    (None, "a new job that goes by the rule: skipped when what it needs was", DRAFTS, MAKEFILE, CI_DRAFTS + "  tidy:\n    needs: macos\n    runs-on: macos-26\n"),
    (None, "the same with a condition of its own", DRAFTS, MAKEFILE, CI_DRAFTS + "  tidy:\n    needs: macos\n    if: ${{ github.ref == 'refs/heads/main' }}\n    runs-on: macos-26\n"),
    (None, "and at second hand", DRAFTS, MAKEFILE, CI_DRAFTS + "  tidy:\n    needs: macos-from-nothing\n    runs-on: macos-26\n"),
    ("`concurrency:` must say", "the group goes by the ref: a merged pull request's is the branch it went into", DRAFTS, MAKEFILE,
     changed("github.event.pull_request.number || github.ref", "github.ref", CI_DRAFTS)),
    ("`concurrency:` must say", "the newer run waits for the older", DRAFTS, MAKEFILE, changed("cancel-in-progress: true", "cancel-in-progress: false", CI_DRAFTS)),
    ("`concurrency:` must say", "no group at all", DRAFTS, MAKEFILE, changed(ONE_GROUP, "", CI_DRAFTS)),
    ("`type: boolean`", "the switch is a text, and \"false\" is true", changed("type: boolean", "type: string", DRAFTS), MAKEFILE, CI_DRAFTS),
    ("used elsewhere", "a step that asks the switch itself, and leaves", changed(SMOKE, SMOKE + "        env:\n          ALL: ${{ inputs.all }}\n", DRAFTS), MAKEFILE, CI_DRAFTS),
    ("used elsewhere", "a list of parts that is empty for a draft", changed("    name: b\n", "    name: b\n    strategy:\n      matrix:\n        part: ${{ fromJSON(inputs['all'] && '[1]' || '[]') }}\n", DRAFTS), MAKEFILE, CI_DRAFTS),
    ("says more than what it uses", "ci.yml asks for lint alone on another ground", DRAFTS, MAKEFILE, changed(WHEN_ALL, "${{ github.actor != 'somebody' }}", CI_DRAFTS)),
    ("says more than what it uses", "ci.yml never asks for all of it", DRAFTS, MAKEFILE, changed(WHEN_ALL, "false", CI_DRAFTS)),
    ("says more than what it uses", "ci.yml hands over something more", DRAFTS, MAKEFILE, changed("all: " + WHEN_ALL + "\n", "all: " + WHEN_ALL + "\n      more: true\n", CI_DRAFTS)),
    ("must say `if: ${{ inputs.all && !cancelled() }}`", "with the switch, the verdict runs on a draft too", changed("inputs.all && !cancelled()", "!cancelled()", DRAFTS), MAKEFILE, CI_DRAFTS),
    ("must say `if: ${{ inputs.all && !cancelled() }}`", "with the switch, the verdict is skipped at the first failure",
     changed("    if: ${{ inputs.all && !cancelled() }}\n", "    if: ${{ inputs.all }}\n", DRAFTS), MAKEFILE, CI_DRAFTS),
    ("linux-lint must run whatever", "lint is switched off with the rest", changed("    name: a\n", "    name: a\n    if: ${{ inputs.all }}\n", DRAFTS), MAKEFILE, CI_DRAFTS),
    ("linux-c runs even when", "a heavy job that drafts run too",
     changed("needs: [linux-lint, linux-b]", "needs: [linux-lint, linux-b, linux-c]", DRAFTS) + "  linux-c:\n    name: c\n    steps:\n      - run: true\n", MAKEFILE, CI_DRAFTS),
    ("linux-b has a condition", "a job switched by something else", changed("    if: ${{ inputs.all }}\n", "    if: ${{ inputs.some }}\n", DRAFTS), MAKEFILE, CI_DRAFTS),
    ("linux-b has a condition", "a STEP on the switch, in a job that reports success", changed(SMOKE, "      - if: ${{ inputs.all }}\n  " + SMOKE.replace("- ", "  "), DRAFTS), MAKEFILE, CI_DRAFTS),
    ("and `default: true`", "whoever says nothing gets lint alone", changed("default: true", "default: false", DRAFTS), MAKEFILE, CI_DRAFTS),
    ("and `default: true`", "no default", changed("        default: true\n", "", DRAFTS), MAKEFILE, CI_DRAFTS),
    ("says more than what it uses", "ci.yml calls it on a condition", GOOD, MAKEFILE, changed("linux.yml\n", "linux.yml\n    if: ${{ false }}\n", CI)),
    ("says more than what it uses", "ci.yml calls it after a job that may be skipped", GOOD, MAKEFILE, changed("  linux:\n", "  linux:\n    needs: changes\n", CI)),
    (None, "a job on Linux that speaks for the Mac job", GOOD, MAKEFILE, CI + "  real-windows:\n    needs: macos\n    runs-on: ubuntu-latest\n    steps:\n      - run: false\n"),
    ("waits for real-windows", "the verdict waits for such a one, which is skipped with the Mac", changed(NEEDS, "needs: [linux-a, linux-b, real-windows]"), MAKEFILE,
     CI + "  real-windows:\n    runs-on: ubuntu-latest\n"),
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
    ("something else before", "the verdict asks only after other steps", changed("      - env:\n", "      - run: true\n      - env:\n"), MAKEFILE),
    ("something else before", "the verdict asks only after an action", changed("      - env:\n", "      - uses: actions/checkout@v5\n      - env:\n"), MAKEFILE),
    ("linux-verdict may fail and pass", "the verdict may fail", changed(CONDITION, CONDITION + "\n    continue-on-error: true"), MAKEFILE),
    ("linux-verdict has a condition", "the verdict's step may be skipped", changed("      - env:\n", "      - if: ${{ failure() }}\n        env:\n"), MAKEFILE),
    ("linux-a has a condition", "a job that may be skipped", changed("  linux-a:\n", "  linux-a:\n    if: ${{ false }}\n"), MAKEFILE),
    ("linux-b has a condition", "a step that may be skipped", changed(SMOKE, "      - if: ${{ false }}\n  " + SMOKE.replace("- ", "  ")), MAKEFILE),
    ("linux-b may fail and pass", "a job that may fail", changed("  linux-b:\n", "  linux-b:\n    continue-on-error: true\n"), MAKEFILE),
    ("linux-b may fail and pass", "a step that may fail", changed(SMOKE, "      - continue-on-error: true\n  " + SMOKE.replace("- ", "  ")), MAKEFILE),
    ("there is no job", "no verdict at all", changed("  linux-verdict:\n", "  linux-last:\n"), MAKEFILE),
    ("nothing to wait for", "no jobs but the verdict", "\njobs:\n" + changed(NEEDS, "needs: []")[GOOD.index("  linux-verdict:"):], MAKEFILE),
    ("no job of linux.yml names an image", "the image is gone from linux.yml", changed("    container: swift:1\n", ""), MAKEFILE),
    ("different images", "one job on another image", changed("    name: a\n", "    name: a\n    container: swift:2\n"), MAKEFILE),
    ("`oldest-swift` has no image of its own", "the oldest Swift is the usual one", GOOD, MAKEFILE, changed("container: swift:0", "container: swift:1", CI)),
    ("`oldest-swift` has no image of its own", "it runs on the bare runner, with whatever is there", GOOD, MAKEFILE, changed("    container: swift:0\n", "", CI)),
    ("`oldest-swift` does not run `swift build --build-tests`", "the tests are not compiled by it", GOOD, MAKEFILE, changed("older swift build --build-tests", "older swift build", CI)),
    ("`oldest-swift` does not run `make typecheck-mac`", "the macOS-only code is not looked at by it", GOOD, MAKEFILE, changed("older-typecheck make typecheck-mac", "older-typecheck true", CI)),
    ("type-checks only a part", "only what changed is type-checked", GOOD, MAKEFILE, changed("ALL: 1", "ALL: 0", CI)),
    ("oldest-swift may fail and pass", "it may fail", GOOD, MAKEFILE, changed("    container: swift:0\n", "    container: swift:0\n    continue-on-error: true\n", CI)),
    ("oldest-swift has a condition", "it runs only now and then", GOOD, MAKEFILE, changed("    container: swift:0\n", "    container: swift:0\n    if: ${{ github.event_name == 'push' }}\n", CI)),
    ("oldest-swift has a condition", "a step of it may be skipped", GOOD, MAKEFILE, changed("      - run: ./scripts/ci-step.py older swift", "      - if: ${{ false }}\n        run: ./scripts/ci-step.py older swift", CI)),
    ("oldest-swift has a condition", "it waits for the Mac's decision", GOOD, MAKEFILE, changed("    container: swift:0\n", "    container: swift:0\n    needs: changes\n", CI)),
    ("`oldest-swift` does not run", "there is no such job", GOOD, MAKEFILE, CI[:CI.index("  oldest-swift:")]),
    ("linux-oldest-swift", "it is put into linux.yml, and nobody waits for it", changed("  linux-verdict:\n", OLDEST.replace("  oldest-swift:", "  linux-oldest-swift:\n    name: oldest") + "  linux-verdict:\n"), MAKEFILE),
    ("runs `make typecheck-mac`", "the type-check runs with the oldest Swift alone", changed("typecheck-mac make typecheck-mac", "typecheck-mac true"), MAKEFILE),
    ("different images", "the whole on another image", GOOD, MAKEFILE, changed("container: swift:1", "container: swift:2", CI)),
    ("runs `scripts/smoke.sh`", "a step of make check was dropped", changed(SMOKE, ""), MAKEFILE),
    ("runs `scripts/smoke.sh`", "it is only spoken of, in a comment", changed(SMOKE, "      # ./scripts/smoke.sh runs elsewhere\n"), MAKEFILE),
    ("runs `scripts/smoke.sh`", "it is only spoken of, in a name", changed(SMOKE, "      - name: scripts/smoke.sh\n        run: true\n"), MAKEFILE),
    ("runs `scripts/smoke.sh`", "a name speaks of make check", changed(SMOKE, "      - name: make check\n        run: true\n"), MAKEFILE),
    ("runs `scripts/smoke.sh`", "its failure is thrown away", changed(SMOKE, SMOKE.rstrip("\n") + " || true\n"), MAKEFILE),
    (None, "it stands in a block", changed(SMOKE, "      - run: |\n          echo first\n          ./scripts/smoke.sh\n"), MAKEFILE),
    ("runs `scripts/new.sh`", "make check has a new step", GOOD, changed("smoke.sh\n", "smoke.sh\n\t@./scripts/new.sh\n", MAKEFILE)),
    ("runs `scripts/new.sh`", "a new step after a comment", GOOD, changed("smoke.sh\n", "smoke.sh\n# And then:\n\t@./scripts/new.sh\n", MAKEFILE)),
    ("runs `scripts/smoke.sh && ./scripts/new.sh`", "a new step on an old line", GOOD, changed("smoke.sh\n", "smoke.sh && ./scripts/new.sh\n", MAKEFILE)),
    ("runs `swift test`", "the tests run only on the Mac", changed("test swift test", "test true"), MAKEFILE, changed("- run: swift build", "- run: swift test", CI)),
    (None, "the tests run through the script that records them", changed("test swift test", "test ./scripts/ci-tests.py run --mode full --record linux.tsv"), MAKEFILE),
    ("runs `swift test`", "through that script, only the Mac's selection", changed("test swift test", "test ./scripts/ci-tests.py run --mode mac-only --record linux.tsv"), MAKEFILE),
    ("runs `swift test`", "through that script, only some", changed("test swift test", "test ./scripts/ci-tests.py run --mode full --record linux.tsv --filter Geometry"), MAKEFILE),
    ("runs `swift test`", "that script only selects", changed("test swift test", "test ./scripts/ci-tests.py select"), MAKEFILE),
    ("runs `swift test`", "only some of the tests run", changed("test swift test", "test swift test --filter Geometry"), MAKEFILE),
    (None, "make check's tests leave a record too, and forget the one before", GOOD, changed("\tswift test\n", WITH_A_RECORD, MAKEFILE)),
    (None, "the same, and the job says `make test`", changed("test swift test", "test make test"), changed("\tswift test\n", WITH_A_RECORD, MAKEFILE)),
    ("runs `swift test`", "the same, and the job runs only some", changed("test swift test", "test make test TEST_ARGS=--filter=Geometry"),
     changed("\tswift test\n", WITH_A_RECORD, MAKEFILE)),
    ("runs `swift test --filter Geometry`", "make check itself runs only some", GOOD, changed("$(TEST_ARGS)", "--filter Geometry", changed("\tswift test\n", WITH_A_RECORD, MAKEFILE))),
    (None, "the tests are divided among machines", changed(WHOLE, DIVIDED), MAKEFILE),
    (None, "the tools' self-test as it stands in make check", changed(SMOKE, SMOKE + TOOLING), WITH_TOOLING),
    (None, "the same in two", changed(SMOKE, SMOKE + TOOLING.replace(".py\n", ".py --only scenarios rehearse\n") + TOOLING.replace(".py\n", ".py --but scenarios rehearse\n")), WITH_TOOLING),
    ("runs `scripts/test-tooling.py`", "only the one half", changed(SMOKE, SMOKE + TOOLING.replace(".py\n", ".py --only scenarios rehearse\n")), WITH_TOOLING),
    ("runs `scripts/test-tooling.py`", "only the other", changed(SMOKE, SMOKE + TOOLING.replace(".py\n", ".py --but scenarios rehearse\n")), WITH_TOOLING),
    ("runs `scripts/test-tooling.py`", "two halves that do not meet", changed(SMOKE, SMOKE + TOOLING.replace(".py\n", ".py --only scenarios rehearse\n") + TOOLING.replace(".py\n", ".py --but scenarios rehearse lint\n")), WITH_TOOLING),
    (None, "a build without the index is a build", changed("build swift build", "build swift build --disable-index-store"), MAKEFILE),
    ("runs `swift build`", "a build of one product is not", changed("build swift build", "build swift build --product arbor-sim"), MAKEFILE),
    ("runs `swift test`", "divided, and nobody counts them afterwards", changed(WHOLE, "".join(DIVIDED.splitlines(True)[:3])), MAKEFILE),
    ("runs `swift test`", "divided, and built, and not run", changed(WHOLE, "".join(DIVIDED.splitlines(True)[:2] + DIVIDED.splitlines(True)[3:])), MAKEFILE),
    ("runs `swift test`", "divided, and a part's failure is thrown away", changed(WHOLE, DIVIDED.replace(".jsonl\n", ".jsonl || true\n", 1)), MAKEFILE),
    ("lint-a.py", "lint was dropped", changed("      - run: ./scripts/ci-step.py lint make lint\n", ""), MAKEFILE),
    ("lint-a.py", "lint is only printed", changed("lint make lint", "lint make lint -n"), MAKEFILE),
    ("runs `scripts/lint-b.py`", "a lint that make check runs by another way", GOOD,
     changed("check: lint build test", "more:\n\t@python3 scripts/lint-b.py\ncheck: lint more build test", MAKEFILE)),
    ("has no `check`", "make check was renamed", GOOD, changed("check:", "verify:", MAKEFILE)),
    ("runs `scripts/parity.py", "parity was dropped", changed("      - run: ./scripts/ci-step.py parity python3 scripts/parity.py --report test-*.jsonl --check\n", ""), MAKEFILE),
    ("runs `scripts/parity.py", "parity no longer minds FEATURES.md", changed("test-*.jsonl --check", "test-*.jsonl"), MAKEFILE),
    ("runs `make typecheck-mac`", "the type-check was dropped", changed("typecheck-mac make typecheck-mac", "typecheck-mac true"), MAKEFILE),
    ("runs `scripts/test-ci-changes.py`", "the Mac's rules go unchecked", changed("      - run: ./scripts/ci-step.py ci-changes ./scripts/test-ci-changes.py\n", ""), MAKEFILE),
]


def main():
    wrong = 0
    for expected, situation, workflow, makefile, *caller in TABLE:
        said = problems_in(workflow, makefile, *(caller or [CI]))
        if (not said) if expected is None else any(expected in problem for problem in said):
            continue
        wrong += 1
        print(f"✘ {situation}: expected {expected or 'nothing'}, got {said or 'nothing'}")
    print(f"{len(TABLE) - wrong} of {len(TABLE)} workflows judged as expected")

    texts = []
    for path in (".github/workflows/linux.yml", "Makefile", ".github/workflows/ci.yml"):
        with open(os.path.join(ROOT, path), encoding="utf-8") as handle:
            texts.append(handle.read())
    found = problems_in(*texts)
    for problem in found:
        print(f"✘ linux.yml: {problem}")
    if not found:
        parts = [name for name in jobs_of(texts[0]) if name != VERDICT]
        print(f"linux.yml: `{VERDICT}` waits for {', '.join(parts)}; between them they run all of `make check`")
    return 1 if wrong or found else 0


if __name__ == "__main__":
    sys.exit(main())
