#!/usr/bin/env python3
"""Makes a test that runs everywhere out of a recording of a real Mac, in one command.

    scripts/trace-to-test.py <trace.jsonl> <name> --shows "<what it shows, in a sentence>"
                             [--through "<words of a remark>" | --until "<words of a remark>"]
                             [--cure <commit, branch or a..b>] [--apps <bundle id>,…] [--no-tests]
    scripts/trace-to-test.py --again <name>… | --again --all      what Arbor does has changed, and rightly: write the expectations anew
    scripts/trace-to-test.py --jolts                              where, in all the recordings, today's Arbor moves a window twice in answer to one thing
    scripts/trace-to-test.py --self-test
    make test-from-trace TRACE=<trace.jsonl> NAME=<name> SHOWS="…" [THROUGH="…"] [UNTIL="…"] [CURE=…]

A hosted Mac is lent for minutes. Every Mac shell script and every run of arbor-e2e records what macOS reported and what the apps
answered (docs/TRACES.md), and the traces come back with the run, in `traces/`. This takes one of them and

 1. CUTS it after the step that matters. `--through "step 89"` keeps everything up to the next heading after the first remark that holds those
    words; `--until "…"` ends right before that remark. (Headings and checks are remarks: `make replay FILE=…` shows them with `#`. A trace
    cannot be cut at the front: its first line is the world it began in. That is why a new one begins at every `step`.)
 2. LEAVES OUT the script's own questions (`state`, `status`…: a third of a trace), and proves that this changes nothing: Arbor must do to
    the windows exactly what it does in a replay of the whole. Otherwise they stay.
 3. READS it for anything private: titles must be tokens (scripts/trace-check.py), nothing may be in it that scripts/public-check.py would stop at a
    push, and every app in it must be Apple's or Arbor's own test windows, or be named with --apps by whoever knows that the Mac was nobody's.
 4. PUTS it under collab/evidence/traces/<name>.jsonl, with a row in the README there.
 5. WRITES <name>.expect: what Arbor did in the replay (how often it moved each window, where each ended up and in what state, whom it asked to
    take the keyboard, who has it, what the view is on). `TraceCorpusTests` replays every trace in that folder on macOS and Linux and holds it to those lines.
 6. PROVES that the test can fail, given the cure: `--cure <commit>` builds Arbor without that commit's changes to Sources/ArborCore and
    Sources/ArborKit (or, for a cure that has not landed yet, with them) and replays there as well. The expectations are written from the cured
    Arbor, must hold there and must NOT hold on the other. Without --cure it says that nobody has seen this test fail.
 7. RUNS `TraceCorpusTests`, which also tries every way back from every state of the new trace.

Lines of an `.expect` file above the one that begins with `# ----` are a person's and stay; those below are written anew by `--again`.
Where Swift is (on Linux: in the container). Exit code 0, or 1 with the reason; then every file is as it was.
"""

import argparse
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRACES = os.path.join(ROOT, "collab", "evidence", "traces")
MARK = "# ---- what Arbor did, written by scripts/trace-to-test.py"
TABLE = "## Made into tests from runs on hosted Macs"
LIMIT = 200_000
# What a script asks to find out where things are. Arbor does nothing about them, which step 2 checks and does not take on trust.
QUESTIONS = {"state", "status", "ascii", "stats", "get", "doctor", "displays", "spaces", "bindings", "rules", "version", "menu", "menu-bar"}
# What Arbor asks of the window system without changing anything.
ASKS = {"focusedWindow", "cursorLocation", "isMouseButtonDown", "allWindows", "displays"}
OWN_APPS = {"ArborTestWindows", "ArborTestWindows2", "Arbor"}


class Refusal(Exception):
    pass


# MARK: The text of a trace


def parse(text):
    """[(the line as it stands, what it says or None for a remark with # and a blank line)]"""
    lines = []
    for number, raw in enumerate(text.split("\n"), 1):
        bare = raw.strip()
        if not bare or bare.startswith("#"):
            lines.append((raw, None))
            continue
        try:
            lines.append((raw, json.loads(bare)))
        except ValueError:
            # The last line of a trace that was cut off while it was being written. Readers drop it too.
            if any(later.strip() for later in text.split("\n")[number:]):
                raise Refusal(f"line {number} is not JSON")
    while lines and not lines[-1][0].strip():
        lines.pop()
    first = next((said for _, said in lines if said is not None), None)
    if not isinstance(first, dict) or "trace" not in first:
        raise Refusal("the first line is no header of a trace (docs/TRACES.md)")
    return lines


def header_at(lines):
    """Where the header is: the first line, or the first after remarks with #."""
    return next(index for index, (_, said) in enumerate(lines) if said is not None)


def is_heading(said):
    """A remark that begins a step: not a check's, and not one of Arbor's own, which stand in the middle of what it does."""
    return said is not None and "note" in said and not said["note"].startswith(("✔", "✘", "moveTogether, "))


def cut(lines, through=None, until=None):
    """The lines up to where the step that matters ends."""
    words = (through or until or "").lower()
    if not words:
        return lines
    found = next((index for index, (_, said) in enumerate(lines) if said and "note" in said and words in said["note"].lower()), None)
    if found is None:
        remarks = [said["note"] for _, said in lines if said and "note" in said]
        raise Refusal(f"no remark holds “{through or until}”. The remarks are:\n  " + "\n  ".join(remarks or ["(none)"]))
    if until:
        return lines[:found]
    end = next((index for index in range(found + 1, len(lines)) if is_heading(lines[index][1])), len(lines))
    return lines[:end]


def without_the_end_line(lines):
    """`end` counts the lines before it, and after a cut or a thinning it would count wrongly. A trace need not have one."""
    return [(raw, said) for raw, said in lines if not (said and "end" in said)]


def without_questions(lines):
    """Leaves out each question of the script's with what Arbor asked in order to answer it. Returns the rest and how many went."""
    kept, dropped, index = [], 0, 0
    while index < len(lines):
        raw, said = lines[index]
        if said and "command" in said and not said.get("nested") and said["command"].split(" ")[0] in QUESTIONS:
            end = index + 1
            while end < len(lines) and lines[end][1] is not None and ("read" in lines[end][1] or lines[end][1].get("call") in ASKS):
                end += 1
            if end < len(lines) and lines[end][1] is not None and lines[end][1].get("done") == said["command"]:
                dropped += 1
                index = end + 1
                continue
        kept.append((raw, said))
        index += 1
    return kept, dropped


def text_of(lines):
    return "\n".join(raw for raw, _ in lines) + "\n"


def windows_in(said):
    found = [said["window"]] if isinstance(said.get("window"), dict) else []
    found += [window for window in said.get("windows", []) if isinstance(window, dict)]
    if said.get("call") == "allWindows":
        found += said.get("result") or []
    for argument in said.get("args") or []:
        if isinstance(argument, dict) and "app" in argument and "pid" in argument:
            found.append(argument)
    return found


def strangers(lines, allowed):
    """The apps in the trace that are neither Apple's nor Arbor's own nor named by the caller."""
    found, judged = set(), set()

    def look_at(app, bundle):
        judged.add(bundle)
        # A program that is no bundle has no bundle id: the test windows, as `swift build` leaves them.
        known = app in OWN_APPS if bundle is None else bundle.startswith(("com.apple.", "dev.arbor.")) or bundle in allowed
        if not known:
            found.add(f"{app} ({bundle})")

    names = set()
    for _, said in lines:
        for window in windows_in(said or {}):
            look_at(window.get("app"), window.get("bundle"))
            names.add(window.get("app"))
        if said and said.get("event") == "applicationActivated" and len(said.get("args") or []) == 2:
            look_at(said["args"][1], said["args"][0])
            names.add(said["args"][1])
    # And wherever else an app can be named: lists and rules in the settings, commands, what Arbor was asked to open.
    shipped = bundle_ids_arbor_ships_with()
    for _, said in lines:
        for text in strings_in(said):
            for word in text.split():
                if BUNDLE_ID.fullmatch(word) and not word.startswith(("com.apple.", "dev.arbor.", "com.example.")) and word not in allowed | shipped | judged:
                    found.add(f"? ({word})")
        asked_for = []
        if said and said.get("call") in ("launchApp", "openApplication"):
            asked_for = [argument for argument in said.get("args") or [] if isinstance(argument, str)]
        elif said and said.get("command", "").startswith("summon "):
            asked_for = [said["command"][len("summon "):]]
        for name in asked_for:
            if name not in names | allowed and not BUNDLE_ID.fullmatch(name):
                found.add(f"{name} (asked for by name)")
    return sorted(found)


BUNDLE_ID = re.compile(r"[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9_-]+){2,}")


def strings_in(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, inner in value.items():
            yield key
            yield from strings_in(inner)
    elif isinstance(value, list):
        for inner in value:
            yield from strings_in(inner)


def bundle_ids_arbor_ships_with():
    """What everybody's settings hold from the start says nothing about anybody."""
    found = set()
    folder = os.path.join(ROOT, "Sources", "ArborCore")
    for name in os.listdir(folder):
        with open(os.path.join(folder, name), encoding="utf-8") as file:
            found.update(match.group(0) for match in BUNDLE_ID.finditer(file.read()))
    return found


# MARK: Replaying


def run(arguments, where=ROOT, **options):
    return subprocess.run(arguments, cwd=where, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, **options)


def simulator(where=ROOT):
    """arbor-sim of the checkout at `where`, built if it is older than its sources."""
    built = run(["swift", "build", "--product", "arbor-sim"], where)
    if built.returncode != 0:
        raise Refusal(f"arbor-sim does not build in {where}:\n" + "\n".join(built.stdout.splitlines()[-30:]))
    return os.path.join(where, ".build", "debug", "arbor-sim")


def course(sim, path):
    """What Arbor did to the windows, without the numbers of the lines, which a thinning changes."""
    told = run([sim, "replay", path, "--course"])
    if told.returncode != 0:
        raise Refusal(f"the trace does not replay:\n{told.stdout}")
    return [re.sub(r"^line \d+", "", line) for line in told.stdout.splitlines()]


def draft(sim, path):
    told = run([sim, "replay", path, "--expect"])
    if told.returncode != 0:
        raise Refusal(f"the trace does not replay:\n{told.stdout}")
    return told.stdout.splitlines()


def problems(sim, path):
    """The problems of a replay of the trace at `path` with the `.expect` file beside it; [] if there are none."""
    told = run([sim, "replay", path])
    if told.returncode == 0:
        return []
    found = [line.strip() for line in told.stdout.splitlines() if re.match(r"^  line \d+: ", line)]
    return found or told.stdout.splitlines()[-5:]


# MARK: With and without the cure


def git(*arguments, where=ROOT, **options):
    done = subprocess.run(["git", *arguments], cwd=where, text=True, capture_output=True, check=False, **options)
    if done.returncode != 0:
        raise Refusal(f"git {' '.join(arguments)}: {done.stderr.strip()}")
    return done.stdout


def the_other_arbor(cure):
    """A checkout like this one but for the cure, built. Returns (its arbor-sim, whether it is the one that HAS the cure, the cure's short name)."""
    first, _, last = cure.partition("..")
    commit = git("rev-parse", "--verify", f"{last or first}^{{commit}}").strip()
    landed = subprocess.run(["git", "merge-base", "--is-ancestor", commit, "HEAD"], cwd=ROOT, check=False).returncode == 0
    # A cure of several commits is named as Git names them: <the one before the first>..<the last>.
    base = git("rev-parse", "--verify", f"{first}^{{commit}}").strip() if last else f"{commit}^" if landed else git("merge-base", "HEAD", commit).strip()
    code = ["--", "Sources/ArborCore", "Sources/ArborKit"]
    patch = git("diff", "--binary", base, commit, *code)
    if not patch.strip():
        raise Refusal(f"{cure} changes nothing in Sources/ArborCore and Sources/ArborKit: what it cures lies where no replay reaches")
    where = os.path.join(ROOT, ".build", "trace-to-test", "the-other-arbor")
    # The build of the last time is kept: only what differs is compiled again.
    kept = where + ".build"
    if os.path.isdir(os.path.join(where, ".build")) and not os.path.isdir(kept):
        shutil.move(os.path.join(where, ".build"), kept)
    subprocess.run(["git", "worktree", "remove", "--force", where], cwd=ROOT, check=False, capture_output=True)
    shutil.rmtree(where, ignore_errors=True)
    git("worktree", "prune")
    git("worktree", "add", "--detach", "--force", where, "HEAD")
    if os.path.isdir(kept):
        shutil.move(kept, os.path.join(where, ".build"))
    # As this checkout is now, committed or not: the replayer that reads the new expectations may be among the changes.
    pending = git("diff", "--binary", "HEAD", "--", "Sources", "Package.swift")
    if pending.strip():
        git("apply", "--whitespace=nowarn", where=where, input=pending)
    for new in git("ls-files", "--others", "--exclude-standard", "--", "Sources").splitlines():
        os.makedirs(os.path.dirname(os.path.join(where, new)), exist_ok=True)
        shutil.copyfile(os.path.join(ROOT, new), os.path.join(where, new))
    git("apply", "--whitespace=nowarn", *(["-R"] if landed else []), where=where, input=patch)
    built = simulator(where)
    # Git need not go on knowing of it. The folder stays, for its build.
    shutil.rmtree(os.path.join(where, ".git"), ignore_errors=True)
    if os.path.isfile(os.path.join(where, ".git")):
        os.remove(os.path.join(where, ".git"))
    git("worktree", "prune")
    short = git("rev-parse", "--short", commit).strip()
    return built, not landed, f"{git('rev-parse', '--short', base).strip()}..{short}" if last else short


# MARK: What is written


def expectations(own, shows, written):
    head = own if own else [f"# {shows}"] if shows else []
    today = datetime.date.today().isoformat()
    return "\n".join(head + [f"{MARK} on {today}; `--again` writes it anew, and what stands above this line stays ----"] + written) + "\n"


def own_lines(path):
    """What a person wrote: everything above the mark, or all of a file that has none."""
    if not os.path.isfile(path):
        return []
    with open(path, encoding="utf-8") as file:
        lines = file.read().split("\n")
    for index, line in enumerate(lines):
        if line.startswith(MARK):
            return lines[:index]
    while lines and not lines[-1].strip():
        lines.pop()
    return lines


def subject(line):
    """What a line is about: `moved 75`, `frame 75`, `docked 75`; `camera`, `focused`, `asked-focus`, of which there is one each."""
    words = line.split()
    if words[:1] == ["expect"]:
        words = words[1:]
    if not words or words[0].startswith("#") or words[0] == "problem":
        return None
    return tuple(words[:1] if words[0] in ("camera", "focused", "asked-focus") else words[:2])


def without_what_is_said_already(written, own):
    """A person's word on a thing stands, also where today's Arbor does otherwise: a fault that is known is written down as what should hold."""
    said = {subject(line) for line in own}
    return [line for line in written if subject(line) not in said]


def readme_with(text, name, header, source, shows, proof):
    row = (
        f"| `{name}` | {header.get('recorded', '?')[:10]}, Arbor {header.get('arbor', '?')}, {header.get('os', '?')}; from `{source}` "
        f"| {shows} | {proof} |"
    )
    lines = text.rstrip("\n").split("\n")
    lines = [line for line in lines if not line.startswith(f"| `{name}` |")]
    if TABLE not in lines:
        at = next((index for index, line in enumerate(lines) if line.startswith("## ")), len(lines))
        lines[at:at] = [
            TABLE, "",
            "Each with one command, `scripts/trace-to-test.py` (docs/TRACES.md, \"From a run on a Mac to a test\"), which cut it, left the script's own questions out, read it for",
            "anything private and wrote the `.expect` file: how often Arbor moved each window, where each ended up, whom it asked to take the keyboard. The last column says",
            "whether anybody has seen the test fail.", "",
            "| Trace | Recorded | What it shows | Seen to fail |", "|---|---|---|---|", "",
        ]
    at = lines.index(TABLE)
    end = next(index for index in range(at, len(lines)) if lines[index].startswith("|---"))
    while end + 1 < len(lines) and lines[end + 1].startswith("|"):
        end += 1
    lines.insert(end + 1, row)
    return "\n".join(lines) + "\n"


# MARK: The two commands


def make(options):
    name = options.name
    if not re.fullmatch(r"[a-z0-9][a-z0-9.-]{1,48}", name):
        raise Refusal("a name of small letters, digits, dots and dashes, as the other traces have")
    if not options.shows or "|" in options.shows or "\n" in options.shows:
        raise Refusal('say what it shows: --shows "<a sentence, without | >"')
    target = os.path.join(TRACES, name + ".jsonl")
    if os.path.exists(target) and not options.replace:
        raise Refusal(f"there is a trace {name} already (--replace puts this one in its place)")
    with open(options.trace, encoding="utf-8") as file:
        whole = parse(file.read())
    header = whole[header_at(whole)][1]

    sim = simulator()
    with tempfile.TemporaryDirectory() as scratch:
        def written(lines, label):
            path = os.path.join(scratch, label + ".jsonl")
            with open(path, "w", encoding="utf-8") as file:
                file.write(text_of(lines))
            return path

        lines = without_the_end_line(cut(whole, options.through, options.until))
        print(f"1. cut: {len(lines)} of {len(whole)} lines")
        thin, questions = without_questions(lines)
        if questions and course(sim, written(thin, "thin")) == course(sim, written(lines, "cut")):
            print(f"2. left out {questions} questions of the script's: {len(thin)} lines, and Arbor does the same to the windows")
            lines = thin
        elif questions:
            print(f"2. the script's {questions} questions stay: without them Arbor does something else, which is worth a look")
            questions = 0
        else:
            print("2. the script asked nothing")
        remark = f"# From `{header.get('name', '?')}`, by scripts/trace-to-test.py: {len(whole)} lines"
        remark += f", cut {'after the step' if options.through else 'before'} “{options.through or options.until}”" if options.through or options.until else ""
        remark += f", without {questions} questions of the script's" if questions else ""
        lines = lines[:header_at(lines) + 1] + [(remark + ".", None)] + lines[header_at(lines) + 1:]
        size = len(text_of(lines).encode())
        if size >= LIMIT:
            raise Refusal(f"{size} bytes, and a trace in the repository has under {LIMIT}: cut it with --through or --until")

        path = written(lines, name)
        checked = run([sys.executable, os.path.join(ROOT, "scripts", "trace-check.py"), path])
        if checked.returncode != 0:
            raise Refusal("scripts/trace-check.py:\n" + checked.stdout)
        unknown = strangers(lines, set(filter(None, (options.apps or "").split(","))))
        if unknown:
            raise Refusal(
                "apps that are neither Apple's nor Arbor's own:\n  " + "\n  ".join(unknown)
                + "\nOn a person's Mac that is theirs to tell, and such a trace stays out of the repository. From a hosted Mac: name the bundle ids with --apps.")
        public = run([sys.executable, os.path.join(ROOT, "scripts", "public-check.py"), "--text", path])
        if public.returncode != 0:
            raise Refusal("scripts/public-check.py:\n" + public.stdout)
        print("3. nothing private: titles are tokens, the apps are Apple's or named, and the public check finds nothing")

        own = own_lines(os.path.join(TRACES, name + ".expect")) if options.replace else []
        expect = os.path.join(scratch, name + ".expect")
        proof = "nobody has"
        green, red = sim, None
        if options.cure:
            other, other_has_it, short = the_other_arbor(options.cure)
            green, red = (other, sim) if other_has_it else (sim, other)
        lines_written = without_what_is_said_already(draft(green, path), own)
        with open(expect, "w", encoding="utf-8") as file:
            file.write(expectations(own, options.shows, lines_written))
        broken = problems(green, path)
        if broken:
            raise Refusal("the replay has problems" + (" even with the cure" if red else "") + ":\n  " + "\n  ".join(broken)
                          + "\nA fault nobody has cured yet can be kept with a `problem …` line (docs/TRACES.md); write the .expect file by hand then.")
        print(f"5. {len(lines_written)} expectations, and they hold")
        if red:
            failing = problems(red, path)
            if not failing:
                raise Refusal(f"with and without {options.cure} Arbor does the same in this replay: the trace does not show that fault")
            print(f"6. without {short} the test fails, as it should:")
            for line in failing:
                print(f"     {line}")
            told = "; ".join(re.sub(r"^line \d+: expectation: ", "", line).split(";")[0] for line in failing[:2])
            proof = f"without {short}: {told}".replace("|", "/")
            if green is not sim:
                # The fault is still here. What should hold is written down as a person would, with a line each that says it is known not to
                # (docs/TRACES.md, "A bug nobody has fixed yet"): the test passes today, and fails with those words once the cure is in.
                known = [found.group(1) for found in (re.search(r"expectation: `(.*?)`", line) for line in failing) if found]
                if len(known) != len(failing):
                    raise Refusal(f"without {short} the replay has problems that are no expectations, so they cannot be marked as known:\n  " + "\n  ".join(failing))
                own = (own or [f"# {options.shows}"]) + [f"# NOT CURED HERE YET: {short} cures it. Once that is in, this test says so, and the `problem` lines go."]
                for line in known:
                    own += [line, f"problem {line}"]
                lines_written = [line for line in lines_written if line not in known]
                with open(expect, "w", encoding="utf-8") as file:
                    file.write(expectations(own, options.shows, lines_written))
                if problems(sim, path):
                    raise Refusal("marked as known, the problems are still reported:\n  " + "\n  ".join(problems(sim, path)))
                if not all("no problem containing" in line for line in problems(green, path)) or not problems(green, path):
                    raise Refusal("with the cure the test should say that the known problems are gone, and nothing else:\n  " + "\n  ".join(problems(green, path)))
                proof = f"it does today: {told}. {short} cures it".replace("|", "/")
                print(f"   {short} is not in this checkout: the {len(known)} line(s) are marked as known problems, so the test passes today and says so when the cure lands")
        else:
            print("6. NOBODY HAS SEEN THIS TEST FAIL: it holds today's behaviour in place. With --cure <commit> it is tried on an Arbor without the cure")

        touched = [target, os.path.join(TRACES, name + ".expect"), os.path.join(TRACES, "README.md")]
        before = as_they_are(touched)
        readme = readme_with(before[touched[2]].decode(), name, header, header.get("name", "?"), options.shows, proof)
        shutil.copyfile(path, target)
        shutil.copyfile(expect, touched[1])
        with open(touched[2], "w", encoding="utf-8") as file:
            file.write(readme)
    print(f"4. collab/evidence/traces/{name}.jsonl ({size} bytes), {name}.expect and a row in README.md")
    code = corpus_tests(options)
    if code != 0:
        put_back(before)
        print("   so the three files are as they were before", file=sys.stderr)
    return code


def as_they_are(paths):
    found = {}
    for path in paths:
        found[path] = None
        if os.path.isfile(path):
            with open(path, "rb") as file:
                found[path] = file.read()
    return found


def put_back(before):
    for path, content in before.items():
        if content is None:
            if os.path.exists(path):
                os.remove(path)
        else:
            with open(path, "wb") as file:
                file.write(content)


def corpus_tests(options):
    if options.no_tests:
        print("7. TraceCorpusTests not run (--no-tests)")
        return 0
    tested = run(["swift", "test", "--filter", "TraceCorpusTests"])
    tail = [line for line in tested.stdout.splitlines() if "✘" in line or "error:" in line or "Test run with" in line]
    print("7. TraceCorpusTests: " + ("passed" if tested.returncode == 0 else "FAILED"))
    for line in tail[-20:]:
        print(f"     {line}")
    return 0 if tested.returncode == 0 else 1


def again(options):
    names = sorted(file[:-6] for file in os.listdir(TRACES) if file.endswith(".jsonl")) if options.all else options.names
    sim = simulator()
    changed = 0
    all_before = as_they_are([os.path.join(TRACES, name + ".expect") for name in names])
    for name in names:
        path, expect = os.path.join(TRACES, name + ".jsonl"), os.path.join(TRACES, name + ".expect")
        if not os.path.isfile(path):
            raise Refusal(f"there is no trace {name}")
        before = ""
        if os.path.isfile(expect):
            with open(expect, encoding="utf-8") as file:
                before = file.read()
        if options.all and MARK not in before:
            continue
        own = own_lines(expect)
        new = without_what_is_said_already(draft(sim, path), own)
        old = [line for line in before.split("\n")[len(own) + 1:] if line]
        if new == old:
            continue
        changed += 1
        print(f"{name}:")
        for line in old:
            if line not in new:
                print(f"  - {line}")
        for line in new:
            if line not in old:
                print(f"  + {line}")
        with open(expect, "w", encoding="utf-8") as file:
            file.write(expectations(own, "", new))
        broken = problems(sim, path)
        if broken:
            put_back(all_before)
            raise Refusal(f"{name}: the replay has problems that no new expectation cures, and every file is as it was:\n  " + "\n  ".join(broken))
    print(f"{changed} of {len(names)} written anew. Read what changed: each line is something a person at that Mac would have seen.")
    return 0


JOLT = 0.5
HANDS = {"shortcut", "dragBegan", "dragMoved", "dragEnded", "resizeBegan", "resizeEnded", "pointerPressed"}


def is_an_act(said):
    """Something a person or an app did, to which Arbor may answer with a move of its own: two moves with one of these between them are two answers."""
    if said.get("nested"):
        return False
    return ("command" in said or "action" in said or said.get("event") in HANDS or (said.get("event") == "changed" and said.get("user"))
            or said.get("raw", "").startswith("leftMouse"))


def moments(lines):
    """For each line of a trace, by its number: when it was, and how many acts there had been by then."""
    found, acts = {}, 0
    for number, (_, said) in enumerate(lines, 1):
        if said and "t" in said:
            acts += 1 if is_an_act(said) else 0
            found[number] = (said["t"], acts)
    return found


def moved_again(line, when):
    """For `moved 98 4 at 32 138 138 261`: (98, [138]), where the next move came within half a second and nobody had done anything in between.
    A question (`138?`: the window was asked for a size where it stood, and then went) is no move."""
    found = re.fullmatch(r"moved (\d+) \d+ at ([\d? ]+)", line.strip())
    if not found:
        return None
    lines = [int(number) for number in found.group(2).split() if not number.endswith("?")]
    again = {first for first, second in zip(lines, lines[1:])
             if first in when and second in when and when[second][0] - when[first][0] < JOLT and when[second][1] == when[first][1]}
    return int(found.group(1)), sorted(again)


def jolts():
    """A window moves once, to where it ends up. The `.expect` files say where it does not, on what real Macs reported and real apps answered."""
    total = 0
    for file in sorted(os.listdir(TRACES)):
        if not file.endswith(".expect") or not os.path.isfile(os.path.join(TRACES, file[:-7] + ".jsonl")):
            continue
        with open(os.path.join(TRACES, file[:-7] + ".jsonl"), encoding="utf-8") as handle:
            when = moments(parse(handle.read()))
        with open(os.path.join(TRACES, file), encoding="utf-8") as handle:
            found = [pair for pair in (moved_again(line, when) for line in handle) if pair and pair[1]]
        by_line = {}
        for window, lines in found:
            for line in lines:
                by_line.setdefault(line, []).append(window)
        for line, windows in sorted(by_line.items()):
            total += len(windows)
            print(f"{file[:-7]}, line {line}: " + ", ".join(f"w{window}" for window in windows))
    print(f"{total} times a window is moved again within {JOLT} s, and nobody did anything in between. See one with: make replay FILE=collab/evidence/traces/<name>.jsonl")
    return 0


# MARK: The tool tests itself


def self_test():
    failures = []

    def expect(what, holds):
        if not holds:
            failures.append(what)

    def trace(*said):
        return parse("\n".join(json.dumps(line, ensure_ascii=False) if isinstance(line, dict) else line for line in said))

    header = {"trace": 1, "displays": [], "name": "day-9", "windows": [{"id": 1, "pid": 5, "app": "Finder", "bundle": "com.apple.finder", "title": "title[1]"}]}
    poll = [{"t": 1, "command": "state"}, {"t": 1, "call": "focusedWindow", "result": 1}, {"t": 1, "read": "inputActivity", "result": {}},
            {"t": 1, "done": "state", "ok": True, "message": "running"}]
    day = trace(
        header, {"t": 0, "note": "step 88 reach"}, {"t": 1, "command": "zoom 1"}, {"t": 1, "done": "zoom 1", "ok": True, "message": "ok"}, *poll,
        {"t": 2, "note": "step 89 leave full screen"}, {"t": 3, "event": "changed", "window": {"id": 1, "pid": 5, "app": "Finder", "bundle": "com.apple.finder"}},
        {"t": 3, "note": "✘ one move"}, *poll, {"t": 4, "note": "step 90 pause"}, {"t": 5, "command": "pause"}, {"t": 6, "end": "paused", "lines": 17, "thinned": 0})

    def notes(lines):
        return [said["note"] for _, said in lines if said and "note" in said]

    expect("--through keeps the step and its checks", notes(cut(day, through="step 89")) == ["step 88 reach", "step 89 leave full screen", "✘ one move"])
    expect("and what came after the last check of the step", cut(day, through="step 89")[-1][1].get("done") == "state")
    expect("--until ends before the remark", notes(cut(day, until="step 89")) == ["step 88 reach"])
    expect("the last step goes to the end", cut(day, through="step 90") == day)
    expect("capitals do not matter", len(cut(day, through="LEAVE FULL")) == len(cut(day, through="step 89")))
    expect("without words nothing is cut", cut(day) == day)
    try:
        cut(day, through="step 12")
        expect("a remark that is not there is an error", False)
    except Refusal as refusal:
        expect("which lists the remarks there are", "step 88 reach" in str(refusal))

    thin, count = without_questions(day)
    expect("the script's questions go, with what Arbor asked to answer them", count == 2 and not any(said and said.get("call") == "focusedWindow" for _, said in thin))
    expect("and nothing else", len(thin) == len(day) - 8 and any(said and said.get("command") == "zoom 1" for _, said in thin))
    acted = trace(header, {"t": 1, "command": "state"}, {"t": 1, "call": "setFrame", "id": 1, "frame": [0, 0, 1, 1], "result": [0, 0, 1, 1]},
                  {"t": 1, "done": "state", "ok": True, "message": ""})
    expect("a question Arbor did something about stays", without_questions(acted) == (acted, 0))
    nested = trace(header, {"t": 1, "event": "shortcut", "args": []}, {"t": 1, "command": "status", "nested": True}, {"t": 1, "done": "status", "ok": True, "message": ""})
    expect("so does one that came from inside something else", without_questions(nested)[1] == 0)
    expect("the line that counts the lines goes", not any(said and "end" in said for _, said in without_the_end_line(day)))

    expect("Apple's apps and the test windows are nobody's secret", strangers(trace(dict(header, windows=header["windows"] + [{"id": 2, "pid": 6, "app": "ArborTestWindows", "bundle": None}])), set()) == [])
    other = trace(header, {"t": 1, "event": "appeared", "window": {"id": 3, "pid": 7, "app": "Notes Pro", "bundle": "org.example.notes"}})
    expect("any other app is named", strangers(other, set()) == ["Notes Pro (org.example.notes)"])
    expect("unless the caller names it", strangers(other, {"org.example.notes"}) == [])
    expect("an app that only came forward counts too", strangers(trace(header, {"t": 1, "event": "applicationActivated", "args": ["org.example.chat", "Chat"]}), set()) == ["Chat (org.example.chat)"])
    expect("one without a bundle id too", strangers(trace(header, {"t": 1, "event": "applicationActivated", "args": [None, "Chat"]}), set()) == ["Chat (None)"])
    expect("the test windows coming forward do not", strangers(trace(header, {"t": 1, "event": "applicationActivated", "args": [None, "ArborTestWindows"]}), set()) == [])
    expect("a window without a bundle id that is not ours counts", strangers(trace(dict(header, windows=[{"id": 2, "pid": 6, "app": "Thing", "bundle": None}])), set()) == ["Thing (None)"])

    expect("remarks with # and blank lines survive", text_of(trace(header, "# by hand", {"t": 1, "note": "x"})).split("\n")[1] == "# by hand")
    expect("a last line that was cut off is dropped", len(parse(json.dumps(header) + '\n{"t":1,"note":"x"}\n{"t":2,"no')) == 2)
    for text, why in (("", "an empty file"), ('{"t":1,"note":"x"}', "a file without a header"), (json.dumps(header) + '\n{"t":1,"no\n{"t":2,"note":"x"}', "a broken line in the middle")):
        try:
            parse(text)
            expect(f"{why} is refused", False)
        except Refusal:
            pass

    readme = "# Traces\n\nWords.\n\n| Trace | What |\n|---|---|\n| `old` | x |\n\n## What real macOS does\n\nMore.\n"
    once = readme_with(readme, "new-one", {"recorded": "2026-10-14T23:20:16Z", "arbor": "dev", "os": "macOS 26"}, "day-9", "It shows.", "nobody has")
    expect("the first row brings its table, before the next chapter", once.index(TABLE) < once.index("| `new-one` |") < once.index("## What real macOS does"))
    expect("the rest of the page stays", all(line in once for line in readme.split("\n")))
    twice = readme_with(once, "second", {}, "day-2", "That too.", "without abc1234: `moved 5 1`")
    expect("the second goes under the first", twice.index("| `new-one` |") < twice.index("| `second` |") < twice.index("## What real macOS does") and twice.count(TABLE) == 1)
    expect("a trace made again has one row", readme_with(twice, "new-one", {}, "day-9", "Otherwise.", "nobody has").count("| `new-one` |") == 1)

    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, "x.expect")
        expect("no file, nothing of a person's", own_lines(path) == [])
        with open(path, "w", encoding="utf-8") as file:
            file.write("# by hand\nvisible 75\n")
        expect("a file without the mark is all a person's", own_lines(path) == ["# by hand", "visible 75"])
        with open(path, "w", encoding="utf-8") as file:
            file.write(expectations(["# by hand", "visible 75"], "", ["moved 75 1"]))
        expect("what stands above the mark stays", own_lines(path) == ["# by hand", "visible 75"])
    expect("what a person said is not said again", without_what_is_said_already(["visible 75", "moved 75 1"], ["# x", "expect  visible 75"]) == ["moved 75 1"])
    expect("a file nobody wrote a word for begins with the mark", expectations([], "", ["moved 1 0"]).startswith(MARK))
    clock = {32: (1.0, 1), 138: (9.0, 2), 139: (9.002, 2), 140: (9.004, 3), 261: (20.0, 3)}
    expect("not one that followed a hand step by step", moved_again("moved 98 2 at 139 140", clock) == (98, []))
    seam = trace(header, {"t": 1, "action": "seamDragged"}, {"t": 1, "call": "setFrame"}, {"t": 1.1, "timer": "x"}, {"t": 1.2, "action": "seamDragged"}, {"t": 1.2, "command": "state", "nested": True})
    expect("acts are counted line by line", [moments(seam)[number][1] for number in (2, 3, 4, 5, 6)] == [1, 1, 1, 2, 2])
    expect("a trace may begin with a remark", header_at(trace("# first", header)) == 1)
    expect("a window moved twice in answer to one line is found", moved_again("moved 98 4 at 32 138 138 261\n", clock) == (98, [138]))
    expect("so is one moved again a moment later, in answer to the next line", moved_again("moved 98 3 at 32 138 139", clock) == (98, [138]))
    expect("one that was asked for a size where it stood and then went is not", moved_again("moved 98 2 at 32 138? 138", clock) == (98, []))
    expect("asked, and then moved twice, it is", moved_again("moved 98 3 at 32 138? 138 138", clock) == (98, [138]))
    expect("one moved once each time is not", moved_again("moved 98 2 at 32 138", clock) == (98, []) and moved_again("moved 98 0", clock) is None)
    told = trace(header, {"t": 0, "note": "step 89 out"}, {"t": 1, "event": "focused", "id": 1}, {"t": 1, "note": "moveTogether, 4 windows, took 0.0 s"},
                 {"t": 1, "call": "setFrame", "id": 1, "frame": [0, 0, 1, 1], "result": [0, 0, 1, 1]}, {"t": 2, "note": "step 90 next"})
    expect("a remark of Arbor's own ends no step", cut(told, through="step 89")[-1][1].get("call") == "setFrame")
    expect("what a person said about a thing is not said otherwise below",
           without_what_is_said_already(["moved 75 3 at 3 76 76", "frame 75 1 2 3 4", "camera root"], ["moved 75 2 at 3 76", "problem moved 75 2 at 3 76", "camera 75"]) == ["frame 75 1 2 3 4"])
    for said, why in (({"t": 1, "command": "summon Chat"}, "an app asked for by name"), ({"t": 1, "call": "launchApp", "args": ["Chat"], "result": True}, "an app Arbor was asked to open")):
        expect(f"{why} counts", strangers(trace(header, said), set()) == ["Chat (asked for by name)"])
    expect("one whose window is in the trace does not", strangers(trace(header, {"t": 1, "command": "summon Finder"}), set()) == [])
    listed = trace(dict(header, settings={"excludedBundleIDs": ["org.example-corp.chat"], "rules": [{"app": "net.sample.mail", "action": "float"}]}))
    expect("nor do the lists and rules of the settings go unread", strangers(listed, set()) == ["? (net.sample.mail)", "? (org.example-corp.chat)"])
    expect("a new file begins with what the trace shows", expectations([], "It shows.", ["moved 1 0"]).startswith("# It shows.\n" + MARK))

    for failure in failures:
        print(f"✘ {failure}")
    print(f"trace-to-test self-test: {'failed' if failures else 'passed'}")
    return 1 if failures else 0


def main():
    parser = argparse.ArgumentParser(usage=__doc__.split("\n\n")[1], add_help=False)
    parser.add_argument("names", nargs="*")
    for flag in ("--shows", "--through", "--until", "--cure", "--apps"):
        parser.add_argument(flag)
    for flag in ("--again", "--all", "--self-test", "--no-tests", "--replace", "--help", "--jolts"):
        parser.add_argument(flag, action="store_true")
    options = parser.parse_args()
    if options.help:
        print(__doc__.strip())
        return 0
    if options.self_test:
        return self_test()
    if options.jolts:
        return jolts()
    try:
        if options.again:
            if bool(options.names) == options.all:
                raise Refusal("--again <name>…, or --again --all")
            return again(options)
        if len(options.names) != 2 or (options.through and options.until):
            print(__doc__.split("\n\n")[1], file=sys.stderr)
            return 64
        options.trace, options.name = options.names
        return make(options)
    except Refusal as refusal:
        print(f"trace-to-test: {refusal}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"trace-to-test: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
