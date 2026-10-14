#!/usr/bin/env python3
"""Finds lines in scripts/mac-shell/ that would change a person's Mac without asking whose Mac it is, or by accident.

Mac shell scripts are written for GitHub's Macs, which are thrown away after the run, but they also get run on
people's own. There a `defaults write`, a `killall Safari` or an `rm -rf ~/Applications/Arbor.app` is damage.
lib.sh has the guard: `on_throwaway_mac` ($GITHUB_ACTIONS is true; $CI is not enough, people set it),
`needs_throwaway_mac "<would…>"` for a whole script, `arbor_may "<would…>" || return` for a helper.

The second kind of line means no harm and does it all the same. With a full disk `dir=$(mktemp -d)` leaves `dir` empty, and
then `rm -rf "$dir/"*` is the root folder, `cd "$dir"` stays in the checkout (bash 3.2 takes `cd ""` for a success) and
`pkill -f "^$dir/"` matches every process of the account. So in a line that removes, moves, overwrites, kills or changes folder,
a variable must be SURE not to be empty, every time it is set: made by `scratch_dir <name> [VARIABLE]`; one of lib.sh's own
(ARBOR_SESSION_DIR, ARBOR_HOME, ARBOR_OUT, ARBOR_ROOT, ARBOR_BIN, ARBOR_LEDGER, SCRATCH_DIR); a literal; a `$(…)` with `|| die` (or exit,
return) on the line or `[ -n "$x" ] || die` on the next, but not `local x=$(…) || die`, where the status is `local`'s; built from a
sure one (`app="$SCRATCH_DIR/Arbor.app"`). Or it is written `"${dir:?}"`, at which bash ends the script when it is empty, or tested
on the line (`[ -n "$dir" ] && rm -rf "$dir"`). And it must be quoted.
lib.sh has the safe ways: `scratch_dir`, `scratch_remove`, `started` and `kill_started`, `limit`, `at_exit`.

A line that matches passes when

  * the script calls needs_throwaway_mac, unindented, before its first such line outside a function;
  * or an enclosing `if`, or the line itself, asks on_throwaway_mac, arbor_may, arbor_may_shoot, arbor_can_shoot or throwaway (or
    compares $GITHUB_ACTIONS with true itself);
  * or an earlier line of the same block asks and leaves otherwise (`arbor_may "…" || return 1`);
  * or it, or the comment line above it, says `# safe anywhere: <why>`. That is said about what a line does, not about what is in
    its variables: for a variable that is not sure, and for an unchecked mktemp, the waiver is `# never empty: <why>`.

The same goes for what an unattended build on a person's Mac would run for a commit with nobody watching:
scripts/sim-smoke.sh, scripts/scenarios.sh, scripts/e2e.sh, and every script under scripts/ that one of them names.

It reads indentation and words, not shell, so it is a net, not a proof. Part of `make lint`, so of `make check`; and on a person's
Mac lib.sh runs it before it starts any script, and starts none from a checkout that fails.

Usage: scripts/lint-mac-shell.py [file…]     (default: every *.sh under scripts/mac-shell, and what an unattended build runs)
       scripts/lint-mac-shell.py --self-test
"""

import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

WRITES = r"\b(rm|cp|mv|mkdir|touch|ln|ditto|tee|rsync|install)\b"
THEIRS = r"(\$HOME|\$\{HOME\}|~)/|(?<![\w.$}])/(Applications|Library|Users|usr/local|etc|opt)/"
GESTURES = "posts gestures or keys past lib.sh's nets: they go to whatever lies at that place or has the keyboard (ask `arbor_input_is_ours click x y` first)"
RISKS = [
    ("changes a setting", r"\bdefaults\s+(-currentHost\s+)?(write|delete|import|rename)\b|\bPlistBuddy\b"),
    ("has Arbor change settings of macOS", r"\bfix-setup\b|\bARBOR_MAC_SWITCHES="),
    ("resets or edits privacy permissions", r"\btccutil\b|TCC\.db"),
    ("scripts other apps", r"\bosascript\b"),
    ("kills processes by name", r"\b(killall|pkill)\b"),
    ("changes which app opens what", r"\blsregister\b"),
    ("changes keychains", r"\bsecurity\s+(create|delete|default|import|unlock|lock|set)-?\w*|\bsecurity\s+list-keychains\b.*\s-s\b"),
    ("acts as root", r"\bsudo\b"),
    ("changes login items or services", r"\bsfltool\b|\blaunchctl\s+(load|unload|bootstrap|bootout|enable|disable|kickstart|remove|submit)\b"),
    ("opens an app, a bundle, a document or a URL: the app may be running with somebody's windows, a bundle gets registered",
     r"(^|[;&|(]|\b(then|do|else|limit \d+|bounded \d+))\s*open\s+[-\"$/\w]"),
    ("takes a picture of the screen", r"\bscreencapture\s+-"),
    ("installs or removes the app", r"(^|[;&|(!]|\b(then|do|else|if|limit \d+))\s*(\w+=\S*\s+|limit \d+\s+)*make\s+(install|uninstall)\b"),
    ("changes the machine", r"\b(pmset|networksetup|systemsetup|nvram|dscl)\b|\bscutil\s+--set\b|\bspctl\s+--(master|global)"),
    ("changes keyboard layouts", r"TIS(Enable|Disable|Select|Deselect)InputSource"),
    ("changes the working tree", r"\bgit\s+(checkout|reset|clean|stash|restore|commit|push)\b"),
    ("writes outside the session's folders", f"{WRITES}.*({THEIRS})"),
    ("posts input past lib.sh's nets, which look where a press lands and who gets the keys (use click, drag, key, release, move)",
     r"\$\{?ARBOR_POINTER\}?\"?\s+(click|drag|key|release|move|pinch)\b"),
    (GESTURES, r"\$\{?WITNESS\}?\"?\s+(pinch|scroll|wheel|hold|hold-space)\b"),
    ("stops a process that may hold event taps: everybody's input waits until macOS gives up on the tap", r"\bkill\s+-(s\s+)?(SIG)?STOP\b"),
    ("takes the session's folder away, so that arborctl and Arbor would use the person's own (without ARBOR_SOCKET the socket is the one in that folder)",
     r"\bunset\s+[^;&|]*\bARBOR_HOME\b|\benv\s+(-i\b|-u\s*ARBOR_HOME\b)|\bARBOR_HOME=(\"\"|'')?(\s|$)"),
    ("moves $HOME: what `open` starts gets the real one all the same", r"(^|[;&|(]\s*|\b(export|env)\s+)HOME="),
    ("says who the person is or what they have open, in output that gets pasted into pull requests (`pointer windows` names only the run's own)",
     r"\b(whoami|hostname|logname)\b|\bid\s+-\w*n|\bscutil\s+--get\b|\$\{?(USER|LOGNAME)\b|(^|[;&|(]\s*)lsappinfo\b|\bpgrep\s+-\w*l"
     r"|^(?!.*\$\().*\$\{?ARBOR_POINTER\}?\"?\s+windows\b(?!\s+--pid)(?![^|]*\|)"),
    ("sends something off this Mac: what a script wrote there is the person's to send", r"(^|[;&|(]|\b(then|do|else)\s)\s*(curl|wget|scp|sftp|nc|gh|ftp)\s+(?!--version\b)"),
]
RISKS = [(what, re.compile(pattern)) for what, pattern in RISKS]

ASKS = r"(\b(on_throwaway_mac|arbor_may|arbor_may_shoot|arbor_can_shoot|needs_throwaway_mac|throwaway)\b|GITHUB_ACTIONS(:-)?\}?\"?\s*=\s*\"?true)"
ASKED = re.compile(rf"(?<!! )(?<!!){ASKS}")
LEAVES = re.compile(rf"{ASKS}.*\|\|\s*(\{{[^}}]*?)?\b(return|exit|die|continue|break)\b")
WHOLE_SCRIPT = re.compile(r"^needs_throwaway_mac\b(?!\s*\()")
WAIVER = re.compile(r"#\s*safe anywhere:\s*\S")
NAME_WAIVER = re.compile(r"#\s*never empty:\s*\S")
FUNCTION = re.compile(r"^\s*(function\s+)?[\w-]+\s*\(\)\s*\{?")


def indent(line):
    return len(line) - len(line.lstrip())


def code(line):
    """The line without its comment. Good enough for lines that are not full of quoted #."""
    return re.sub(r"(^|\s)#.*$", "", line)


# MARK: Lines that do harm by accident

# Set by the shell, or by lib.sh from something it has checked.
NEVER_EMPTY = {"HOME", "PWD", "ARBOR_SESSION_DIR", "ARBOR_SESSION_DIRS", "ARBOR_HOME", "ARBOR_OUT", "ARBOR_ROOT", "ARBOR_BIN", "ARBOR_LEDGER", "SCRATCH_DIR"}
DECLARES = r"(?:(?:local|export|readonly|declare|typeset)\s+(?:-\w+\s+)*)"
ASSIGNS = re.compile(rf"^\s*({DECLARES})?(\w+)=(.*)$")
STOPS = re.compile(r"\|\|\s*(\{[^}]*?)?\b(die|exit|return|fail|continue|break)\b")
HARMLESS = {"?", "!", "$", "#"}
PREFIX = r"(?:^|[;&|({'`]|\b(?:then|do|else|sudo|exec|command|xargs|limit\s+\S+|bounded\s+\S+|arbor_within\s+\S+|check\s+\"[^\"]*\"|eventually)\s)\s*"
VERB = re.compile(PREFIX + r"(rm|rmdir|mv|cp|ditto|rsync|find|cd|pushd|pkill|pgrep|killall|kill)\s+((?:\"[^\"]*\"|\$\([^)]*\)|[^;&|)'`])*)")
SEARCH = r"\b(pgrep|pidof|lsappinfo|lsof|ps)\b"
ASSIGNMENT = re.compile(r"(?:^|[;&|({]|\b(?:then|do|else|local|export|readonly)\s)\s*(\w+)=((?:\"[^\"]*\"|'[^']*'|\$\([^)]*\)|[^\s;&|)])*)")
SCRATCH = re.compile(r"(?:^|[;&|({]|\b(?:then|do|else)\s)\s*scratch_dir\s+[\w-]+(?:\s+(\w+))?")


class Word:
    """One word of a command: what it starts with, and every variable in it as (name, quoted, checked)."""

    def __init__(self):
        self.text = ""
        self.start = None  # ("variable", name, checked), ("substitution",) or ("literal",)
        self.variables = []
        self.substitution = False


def words(text):
    found, word, quote, index = [], None, "", 0

    def begin(kind):
        nonlocal word
        if word is None:
            word = Word()
            word.start = kind

    while index < len(text):
        char = text[index]
        if quote == "'":
            quote = "" if char == "'" else quote
            word.text += char
        elif char == "\\" and index + 1 < len(text):
            begin(("literal",))
            word.text += text[index:index + 2]
            index += 1
        elif char in "\"'" and (not quote or quote == char):
            opening = word is None
            begin(None)
            quote = "" if quote else char
            word.text += char
            if opening:
                word.start = None  # decided by what follows the quotation mark
        elif char.isspace() and not quote:
            if word is not None:
                found.append(word)
            word = None
        elif char == "$" and index + 1 < len(text) and text[index + 1] == "(":
            depth, end = 0, index + 1
            while end < len(text):
                depth += (text[end] == "(") - (text[end] == ")")
                if depth == 0:
                    break
                end += 1
            begin(("substitution",))
            word.start = word.start or ("substitution",)
            word.substitution = True
            word.text += text[index:end + 1]
            index = end
        elif char == "`":
            begin(("substitution",))
            word.start = word.start or ("substitution",)
            word.substitution = True
            word.text += char
        elif char == "$":
            match = re.match(r"\$\{(\w+|[@*#?!$])([^}]*)\}|\$(\w+|[@*#?!$])", text[index:])
            if match:
                name = match.group(1) or match.group(3)
                checked = bool(match.group(2)) and bool(re.match(r":?\?", match.group(2)))
                begin(("variable", name, checked))
                word.start = word.start or ("variable", name, checked)
                word.variables.append((name, bool(quote), checked))
                word.text += match.group(0)
                index += len(match.group(0)) - 1
            else:
                begin(("literal",))
                word.start = word.start or ("literal",)
                word.text += char
        else:
            begin(("literal",))
            word.start = word.start or ("literal",)
            word.text += char
        index += 1
    if word is not None:
        found.append(word)
    for entry in found:
        entry.start = entry.start or ("literal",)
    return found


def declared(text):
    """The variables `scratch_dir` fills in this text."""
    return {match.group(1) or "SCRATCH_DIR" for line in text.splitlines() for match in SCRATCH.finditer(code(line))}


def sure_names(lines, shared=()):
    """The variables of a script that cannot be empty, as far as its own assignments tell."""
    values = {}
    for index, line in enumerate(lines):
        match = ASSIGNS.match(line)
        if match:
            following = next((later for later in lines[index + 1:] if later.strip()), "")
            values.setdefault(match.group(2), []).append((bool(match.group(1)), match.group(3).strip(), following))
    made = set(shared) | declared("\n".join(lines))
    # What lib.sh vouches for and the script then sets itself is the script's to vouch for.
    sure = (NEVER_EMPTY | made) - set(values)
    while True:
        more = {name for name, assignments in values.items()
                if name not in sure and all(is_sure(name, *assignment, sure) for assignment in assignments)}
        if not more:
            return sure
        sure |= more


def is_sure(name, declaring, value, following, sure):
    tested = re.search(rf'\[\[?\s+-[nd]\s+"?\$\{{?{name}\}}?"?\s+\]\]?\s*\|\|', following) and STOPS.search(following)
    text = value.lstrip('"\'')
    if text.startswith(("$(", "`")):
        # The status of a declaration is the declaration's, not the command's.
        return bool(tested or (STOPS.search(value) and not declaring))
    fallback = re.match(r"\$\{\w+:-([^}]+)\}", text)
    if fallback:
        return is_sure(name, declaring, fallback.group(1), following, sure)
    start = re.match(r"\$\{?(\w+)", text)
    if start:
        return bool(tested or start.group(1) in sure or re.match(r"\$\{\w+:\?", text))
    return bool(text) and not text.startswith(("$", ";", "#"))


def searched_variables(lines):
    """Per line, the variables that hold a pid somebody looked up: those set outside functions, and those set in the line's own function."""
    region, regions = None, []
    for index, line in enumerate(lines):
        if line.strip() and indent(line) == 0:
            region = index if FUNCTION.match(line) and not line.rstrip().endswith("}") else region if line.startswith("}") else None
        regions.append(region)
    found = {}
    for index, line in enumerate(lines):
        for match in ASSIGNMENT.finditer(line):
            if re.search(rf"\$\([^)]*{SEARCH}", match.group(2)):
                found.setdefault(regions[index], set()).add(match.group(1))
    return [found.get(None, set()) | found.get(region, set()) for region in regions]


def accidents(line, following, proven, searched, before="", harness=True):
    """What could go wrong in this line: (because of what may be in a variable, otherwise)."""
    found, other = [], []
    # [ -n "$x" ] && rm -rf "$x"
    proven = proven | set(re.findall(r'\[\[?\s+-[nd]\s+"?\$\{?(\w+)\}?"?\s+\]\]?\s*&&', line))

    def unproven(word):
        return word.start[0] == "variable" and word.start[1] not in proven and not word.start[2] and word.start[1] not in HARMLESS

    def name(word):
        return "$" + word.start[1]

    for match in VERB.finditer(line):
        verb, operands = match.group(1), words(match.group(2))
        options = [word.text for word in operands if word.text.startswith("-")]
        paths = [word for word in operands if not word.text.startswith("-")]
        for word in operands:
            for variable, quoted, _ in word.variables:
                if not quoted and variable not in HARMLESS:
                    found.append(f"${variable} is not quoted in a line that runs {verb}: empty it vanishes, with a space or a * in it it is several things")
        if verb in ("rm", "rmdir"):
            recursive = verb == "rm" and any(re.match(r"-\w*[rR]", option) for option in options)
            for word in paths:
                if unproven(word) and (recursive or re.search(r"[*?]", re.sub(r"\$\{[^}]*\}", "", word.text))):
                    found.append(f"removes whatever {name(word)} names, and / or the checkout if it is empty (scratch_dir makes the folder, scratch_remove removes it)")
        elif verb == "mv":
            found += [f"moves what {name(word)} names, which nothing has checked (scratch_dir, or \"${{{word.start[1]}:?}}\")" for word in paths if unproven(word)]
        elif verb in ("cp", "ditto", "rsync"):
            whole = verb != "cp" or any(re.match(r"-\w*[rRa]", option) for option in options)
            if whole and paths and unproven(paths[-1]):
                found.append(f"copies a folder over what {name(paths[-1])} names, which nothing has checked (scratch_dir, or \"${{{paths[-1].start[1]}:?}}\")")
        elif verb == "find":
            if re.search(r"-delete\b|-exec\s+(rm|mv)\b", match.group(2)):
                found += [f"deletes below {name(word)}, which is / if it is empty (scratch_dir, or \"${{{word.start[1]}:?}}\")"
                          for word in operands[:1] if unproven(word)]
        elif verb in ("cd", "pushd"):
            found += [f"bash 3.2 takes `cd \"\"` for a success, so with {name(word)} empty the next lines run where the script already was (scratch_dir, or \"${{{word.start[1]}:?}}\")"
                      for word in paths[:1] if unproven(word)]
        elif verb in ("pkill", "pgrep", "killall"):
            for word in paths:
                loose = [variable for variable, _, checked in word.variables if variable not in proven and not checked and variable not in HARMLESS]
                if loose and any("f" in option for option in options if not option.startswith("--")):
                    found.append(f"a pattern built from ${loose[0]} matches every process of the account if that is empty (started and kill_started know the script's own)")
        elif verb == "kill":
            for word in paths:
                bare = word.text.strip("\"'")
                if word.substitution:
                    other.append("kills what a search found, not what the script started (started and kill_started know the script's own)")
                elif bare in ("0", "-1") or re.match(r"-\$|-\d+$", bare) and operands.index(word) > 0 and bare.lstrip("-").isdigit() is False:
                    other.append("kills a whole process group, which may be the caller's too")
                elif word.start[0] == "variable" and word.start[1] in searched:
                    other.append(f"kills a process that was looked up ({name(word)}), not one the script started: it may be the person's (arbor_started_here, started, kill_started)")
            for option in options:
                if re.match(r"-\$|-\"\$", option):
                    other.append("kills a whole process group, which may be the caller's too")
    made = ASSIGNS.match(line)
    if made and re.search(r"(\$\(|`)\s*mktemp\b", made.group(3)):
        if not is_sure(made.group(2), bool(made.group(1)), made.group(3).strip(), following, proven):
            found.append("mktemp fails on a full disk and leaves the variable empty (scratch_dir checks, and cleans up)")
    if re.search(r"\$\(\s*scratch_dir\b|`\s*scratch_dir\b", line):
        other.append("scratch_dir in $( ) can end only the subshell, and prints nothing: call it as a command, `scratch_dir <name> VARIABLE`")
    if re.search(PREFIX + r"wait\s*($|[;&|)#])", line):
        other.append("`wait` without a process waits for every child, for ever if one of them never ends (wait \"$pid\")")
    asked = re.search(PREFIX + r"wait\s+\"?\$\{?(\w*(?:PID|pid))\b", line)
    if asked and not re.search(r"\bkill\b|\barbor_gone\b|\barbor_await_exit\b[^|;]*&&", line + " " + before):
        other.append(f"waits for ever if ${asked.group(1)} does not end, which asking it to quit does not make sure of (check \"it ends\" ended \"${asked.group(1)}\")")
    if harness and re.search(PREFIX + r"trap\s.*\bEXIT\b", line) and not re.search(r"\b(arbor_exit|apps_exit)\b|trap\s+-\s", line):
        other.append("replaces lib.sh's trap on EXIT, so nothing stops Arbor and the test windows (at_exit '<command>' adds to it)")
    if re.search(PREFIX + r"(?:(?:env|nohup)\s+)?(?:(?:\"[^\"]*\"|\$\w+|\w+=\S*)\s+)*\"?[^\s\"]*/Arbor\"?(?:\s+(?!--version)|$)", line):
        if "ARBOR_ONLY_PIDS=" not in line:
            other.append("starts an Arbor that is not limited to test windows (ARBOR_ONLY_PIDS): it would arrange the person's (arbor_start)")
        elif "ARBOR_NO_WATCHDOG=" not in line:
            other.append("starts an Arbor with its watchdog: killed, it is started again under a process id nobody knows (ARBOR_NO_WATCHDOG=1)")
    return found, other


def guarded(lines, index, waiver=WAIVER):
    if waiver.search(lines[index]) or (index > 0 and lines[index - 1].lstrip().startswith("#") and waiver.search(lines[index - 1])):
        return True
    if ASKED.search(code(lines[index])):
        return True
    level = indent(lines[index])
    for above in range(index - 1, -1, -1):
        line = code(lines[above])
        if not line.strip():
            continue
        depth = indent(line)
        if depth > level:
            continue
        if depth == level and LEAVES.search(line):
            return True
        if depth < level:
            if ASKED.search(line) and re.search(r"\b(if|elif|while)\b|&&\s*\{?\s*$", line):
                return True
            level = depth
        if depth == 0 and FUNCTION.match(line):
            return False
    return False


def problems(text, shared=(), harness=True):
    """(line number, what it does, the line) for every unguarded risk. shared: variables that files it sources prove.
    harness: whether lib.sh is sourced, whose trap must then be left in place."""
    lines = text.splitlines()
    found = []
    whole = None
    in_function = False
    # A command that goes on after a backslash is judged as one line, at its first.
    logical = [code(raw) for raw in lines]
    for index in range(len(lines) - 2, -1, -1):
        if logical[index].rstrip().endswith("\\"):
            logical[index] = logical[index].rstrip()[:-1] + " " + logical[index + 1].lstrip()
            logical[index + 1] = ""
    # app="$HOME/Applications/Arbor.app" … rm -rf "$app"
    theirs = {match.group(1) for match in re.finditer(rf"(?m)^\s*(?:local\s+|export\s+)?(\w+)=.*({THEIRS})", text)} - {"PATH"}
    risks = list(RISKS)
    # A script that runs off GitHub's Macs only when a person sets a switch of its own (`[ "$X_HERE" = 1 ] || needs_throwaway_mac …`) is about what the
    # taps do with raw input. Everything else in it is still read.
    if re.search(r"(?m)^\[ .* \]\s*\|\|\s*needs_throwaway_mac\b", text):
        risks = [risk for risk in risks if risk[0] != GESTURES]
    if theirs:
        names = "|".join(sorted(theirs))
        risks.append(("writes outside the session's folders", re.compile(rf"{WRITES}.*\$\{{?({names})\b")))
    proven, searched = sure_names(logical, shared), searched_variables(logical)
    # perl -e ' … ' over several lines is not shell: `kill "TERM", $pid` means something else there.
    foreign, inside_quotes = set(), False
    for index, line in enumerate(logical):
        if inside_quotes:
            foreign.add(index)
            inside_quotes = "'" not in line
        elif re.search(r"\b(perl|python3?|awk|ruby|sed)\b[^']*'[^']*$", line):
            inside_quotes = True
    for index, raw in enumerate(lines):
        line = logical[index]
        if indent(raw) == 0 and code(raw).strip():
            in_function = bool(FUNCTION.match(code(raw))) and not code(raw).rstrip().endswith("}")
        if WHOLE_SCRIPT.match(line) and whole is None:
            whole = index
        if not line.strip():
            continue
        inside = in_function or indent(raw) > 0 and in_function
        for what, pattern in risks:
            if pattern.search(line):
                found.append((index, what, raw.strip(), inside, WAIVER))
                break
        if index not in foreign:
            following = next((later for later in logical[index + 1:] if later.strip()), "")
            before = " ".join([earlier for earlier in logical[:index] if earlier.strip()][-2:])
            names, other = accidents(line, following, proven, searched[index], before, harness)
            found += [(index, what, raw.strip(), inside, NAME_WAIVER) for what in names]
            # One reason to ask whose Mac it is is enough for a line.
            if not found or found[-1][0] != index or names:
                found += [(index, what, raw.strip(), inside, WAIVER) for what in other]
    kept = []
    for index, what, shown, inside, waiver in found:
        # A function runs when it is called, which is after the guard at the top of the script.
        if whole is not None and (index > whole or inside):
            continue
        if not guarded(lines, index, waiver):
            kept.append((index + 1, what, shown))
    return kept


SELF_TEST = [
    (1, 'defaults write com.apple.x y -bool true\n'),
    (1, 'if [ -n "${CI:-}" ]; then\n  defaults write com.apple.x y -bool true\nfi\n'),
    (0, 'if on_throwaway_mac; then\n  defaults write com.apple.x y -bool true\nfi\n'),
    (1, 'if ! on_throwaway_mac; then\n  defaults write com.apple.x y -bool true\nfi\n'),
    (0, 'on_throwaway_mac && killall WindowManager\n'),
    (0, 'f() {\n  arbor_may "do it" || return 1\n  killall WindowManager\n}\n'),
    (1, 'f() {\n  killall WindowManager\n  arbor_may "do it" || return 1\n}\n'),
    (0, 'f() {\n  case "$1" in\n    on)\n      if arbor_may "x"; then\n        defaults write a b c\n      fi ;;\n  esac\n}\n'),
    (0, 'source lib.sh\nneeds_throwaway_mac "kill Safari"\npkill -x Safari\n'),
    (0, 'source lib.sh\nf() {\n  pkill -x Safari\n}\nneeds_throwaway_mac "kill Safari"\nf\n'),
    (1, 'source lib.sh\npkill -x Safari\nneeds_throwaway_mac "kill Safari"\n'),
    (0, '# safe anywhere: it only lists them\nfor tool in killall defaults; do echo "$tool"; done\n'),
    (1, 'pkill -f "^$root/.build/"  # safe anywhere: only what this checkout built\n'),
    (0, 'pkill -f "^${root:?}/.build/"  # safe anywhere: only what this checkout built\n'),
    (0, '# defaults write in a comment\necho hello\n'),
    (1, 'rm -rf "$HOME/Applications/Arbor.app"\n'),
    (0, 'rm -rf "$ARBOR_SESSION_DIR/Arbor.app"\n'),
    (1, 'open -a Safari\n'),
    (1, 'open -g -b "$BUNDLE"\n'),
    (1, 'open "arbor://zoom/$W1"\n'),
    (1, 'open -n --env A=b "$app"\n'),
    (1, 'if x; then open "$@"; fi\n'),
    (0, 'echo "> open arbor://show-all"\n'),
    (0, 'claim "open an arbor:// URL"\n'),
    (1, 'app="$HOME/Applications/ArborKeys.app"\nrm -rf "$app"\n'),
    (0, 'app="$ARBOR_SESSION_DIR/ArborKeys.app"\nrm -rf "$app"\n'),
    (0, 'if [ "${GITHUB_ACTIONS:-}" = true ]; then\n  sudo tccutil reset Accessibility\nfi\n'),
    (1, 'if [ "${GITHUB_ACTIONS:-}" != true ]; then\n  sudo tccutil reset Accessibility\nfi\n'),
    (0, 'defaults read com.apple.WindowManager Enable\n'),
    (1, 'ctl fix-setup\n'),
    (1, 'arbor_start 3 ARBOR_MAC_SWITCHES=1\n'),
    (0, 'source lib.sh\nneeds_throwaway_mac "switch tiling off"\narbor_start 3 ARBOR_MAC_SWITCHES=1\nctl fix-setup undo\n'),
    (1, 'sudo tccutil reset Accessibility\n'),
    (1, 'screencapture -x "$path"\n'),
    (0, 'f() {\n  arbor_may_shoot "$1" || return 1\n  screencapture -x "$path"\n}\n'),
    (0, 'if throwaway; then macos_tiling off; defaults write a b c; fi\n'),
    (1, 'security default-keychain -d user -s "$keychain"\n'),
    (0, 'security find-identity -p codesigning\n'),
    (1, 'git checkout --quiet -- Sources/Arbor/main.swift\n'),
    (1, 'touch "$HOME/Desktop/arbor-F14.txt"\n'),
    (0, 'cp "$HOME/Library/Logs/x" "$ARBOR_OUT/"  # safe anywhere: it reads there and writes here\n'),
    (1, 'work=$(mktemp -d)\n'),
    (0, 'work=$(mktemp -d) || die "no temporary folder"\n'),
    (0, 'work=$(mktemp -d /tmp/x.XXXXXX) || exit 2\n'),
    (0, 'work=$(mktemp -d)\n[ -n "$work" ] || die "no temporary folder"\n'),
    (1, 'f() {\n  local work=$(mktemp -d) || die "local succeeds whatever mktemp did"\n}\n'),
    (0, 'f() {\n  local work\n  work=$(mktemp -d) || return 1\n  rm -rf "$work"\n}\n'),
    (2, 'work=$(mktemp -d)\nrm -rf "$work/build"\n'),
    (0, 'work=$(mktemp -d) || die "no"\nrm -rf "$work/build"\npkill -f "^$work/"  # safe anywhere: only what ran in there\n'),
    (1, 'root=$(git rev-parse --show-toplevel)\nrm -rf "$root/.build/x"\n'),
    (0, 'root=$(git rev-parse --show-toplevel)\nrm -rf "${root:?}/.build/x"\n'),
    (0, 'rm -rf "$sure"; echo "$unsure"\nsure=/tmp/x\n'),
    # Empty until it is made: the making is checked, a trap that fires before it is not.
    (0, 'work=""\nwork=$(mktemp -d) || die "no"\n'),
    (1, 'work=""\ntrap \'rm -rf "$work/build"; arbor_exit\' EXIT\nwork=$(mktemp -d) || die "no"\n'),
    (0, 'work=""\ntrap \'[ -n "$work" ] && rm -rf "$work/build"; arbor_exit\' EXIT\nwork=$(mktemp -d) || die "no"\n'),
    (0, 'root=$(git rev-parse --show-toplevel)\n[ -n "$root" ] && rm -rf "$root/.build/x"\n'),
    (1, 'rm -rf "$1/build"\n'),
    (1, 'rm -rf "$NOBODY_SET_THIS"/*\n'),
    (0, 'copy="$ARBOR_SESSION_DIR/copy"\nrm -rf "$copy"\nfind "$copy" -name "*.log" -delete\n'),
    (1, 'copy="$maybe/copy"\nrm -rf "$copy"\n'),
    (0, 'rm -rf /tmp/arbor-fixed-name\n'),
    (0, 'rm -f "$whatever"\n'),
    (0, 'if on_throwaway_mac; then\n  rm -rf "$1/build"\nfi\n'),
    (1, 'rm -rf "$1/build"  # safe anywhere: it is only a build folder\n'),
    (0, 'rm -rf "$1/build"  # never empty: the one caller passes a literal\n'),
    (0, 'source lib.sh\nneeds_throwaway_mac "wipe things"\nrm -rf "$1/build"\n'),
    (0, 'work=$(mktemp -d) || { echo "no temporary folder"; exit 2; }\n'),
    (1, 'work=$(mktemp -d) || { echo "no temporary folder"; }\n'),
    (1, 'limit 600 make install LAUNCH=0\n'),
    (1, 'ARBOR_KEEP_LOGIN_ITEM=1 limit 120 make uninstall\n'),
    (1, 'if ! limit 900 make install > "$ARBOR_OUT/install.txt" 2>&1; then\n  exit 1\nfi\n'),
    (0, 'echo "\\`make app\\` does not get through, so neither would make install"\n'),
    (1, 'unset ARBOR_HOME\n'),
    (0, 'unset ARBOR_SOCKET\n'),
    (0, 'on_throwaway_mac || { echo "part 2 skipped"; exit 0; }\npkill -x TextEdit\n'),
    (1, 'on_throwaway_mac || { echo "part 2 would be skipped"; }\npkill -x TextEdit\n'),
    (1, '"$WITNESS" hold-space 10\n'),
    (0, '"$WITNESS" taps\n'),
    (0, 'source lib.sh\n[ "${ARBOR_INPUT_TAPS_HERE:-}" = 1 ] || needs_throwaway_mac "click at fixed places"\n"$WITNESS" wheel 10 10 2 --ctrl\n'),
    (1, 'source lib.sh\n[ "${ARBOR_INPUT_TAPS_HERE:-}" = 1 ] || needs_throwaway_mac "click at fixed places"\nkillall Dock\n'),
    (1, 'echo "user $(whoami)"\n'),
    (1, 'lsappinfo info -only name "$(lsappinfo front)"\n'),
    (1, '"$ARBOR_POINTER" windows --on-screen\n'),
    (0, '"$ARBOR_POINTER" windows --pid "$ARBOR_PID"\n'),
    (0, 'id=$("$ARBOR_POINTER" windows | awk \'{ print $1 }\')\n'),
    (0, 'pointer windows --on-screen\n'),
    (1, 'curl -F file=@"$ARBOR_OUT/output.txt" https://example.com\n'),
    (0, 'echo "curl $(curl --version | head -n 1)"\n'),
    (1, '"$ARBOR_BIN/arborctl" quit\nwait "$ARBOR_PID"\n'),
    (0, 'kill -KILL "$ARBOR_PID"\nwait "$ARBOR_PID"\n'),
    (0, 'arbor_await_exit "$ARBOR_PID" 50 && wait "$ARBOR_PID"\n'),
    (0, 'swiftc x.swift &\ncompiler=$!\nwait "$compiler"\n'),
]


def self_test(quiet=False):
    wrong = 0
    for expected, text in SELF_TEST:
        got = len(problems(text))
        if got != expected:
            wrong += 1
            print(f"✘ expected {expected} problem(s), found {got}, in:\n{text}")
    if not quiet:
        print(f"lint-mac-shell: {len(SELF_TEST) - wrong} of {len(SELF_TEST)} examples judged as expected")
    return 1 if wrong else 0


def one_lock(text):
    """The numbers of the lines that take GITHUB_ACTIONS alone for "one of GitHub's Macs, which nobody owns". A runner that a person sets up on
    their own Mac sets it too, and anybody can export it; GitHub's Macs run jobs as `runner`, and no variable changes what the account is
    called. So whatever reads the variable, in whichever way, asks for the account as well, there or within the next six lines, or says
    `# safe anywhere: <why>`. Any language. After it has sourced lib.sh a script finds the variable gone where the account is another, and may
    ask as it likes. A net, not a proof: it does not follow what is done with the two answers."""
    lines = [re.sub(r"^\s*(#|//).*", "", line) for line in text.splitlines()]
    under_lib = next((number for number, line in enumerate(lines) if re.match(r"\s*(source|\.)\s.*\blib[\w-]*\.sh", line)), len(lines))
    # Taking it away, setting it and printing its name read nothing.
    harmless = re.compile(r"^\s*(unset|export|echo)\b|-u GITHUB_ACTIONS\b|(^|\s)GITHUB_ACTIONS=|safe anywhere: \S")
    # Asked of the system, not merely named: arbor-e2e is full of `runner`s of another kind (`self.runner = runner`).
    account = re.compile(r"(id -un|NSUserName\(\))[^\n]*\brunner\b")
    return [number + 1 for number, line in enumerate(lines[:under_lib])
            if "GITHUB_ACTIONS" in line and not harmless.search(line) and not any(account.search(later) for later in lines[number:number + 7])]


def loop_scripts(root=ROOT):
    """What an unattended build runs, and what that runs."""
    found, waiting = [], ["sim-smoke.sh", "scenarios.sh", "e2e.sh"]
    while waiting:
        path = os.path.join(root, "scripts", waiting.pop(0))
        if path in found or not os.path.isfile(path):
            continue
        found.append(path)
        with open(path, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                waiting += re.findall(r"\bscripts/([\w-]+\.sh)\b", code(line))
    return found


def main():
    arguments = sys.argv[1:]
    if arguments == ["--self-test"]:
        return self_test()
    paths = arguments or sorted(glob.glob(os.path.join(ROOT, "scripts", "mac-shell", "**", "*.sh"), recursive=True)) + loop_scripts()
    count = 0
    for path in paths:
        # What the libraries beside a script are sure of, the script may be sure of too.
        shared, libraries = set(), []
        for folder in {os.path.dirname(os.path.abspath(path)), os.path.join(ROOT, "scripts", "mac-shell")}:
            for library in glob.glob(os.path.join(folder, "lib*.sh")):
                with open(library, encoding="utf-8", errors="replace") as handle:
                    libraries.append(handle.read())
        for text in libraries:
            shared |= declared(text)
        for text in libraries:
            shared |= sure_names([code(line) for line in text.splitlines()], shared)
        with open(path, encoding="utf-8", errors="replace") as handle:
            text = handle.read()
            harness = os.path.basename(path).startswith("lib") or bool(re.search(r"(?m)^\s*(source|\.)\s.*\blib[\w-]*\.sh", text))
            for number, what, shown in problems(text, shared, harness):
                count += 1
                print(f"{os.path.relpath(path, ROOT)}:{number}: {what}: {shown[:140]}")
    locks = 0
    if not arguments:
        # What can do something to a Mac. Not the Python scripts, which go by the variable only for how they print.
        for pattern in ("scripts/**/*.sh", "scripts/**/*.swift", "scripts/**/*.m", "Sources/**/*.swift", "Makefile", ".github/workflows/*.yml"):
            for path in sorted(glob.glob(os.path.join(ROOT, pattern), recursive=True)):
                with open(path, encoding="utf-8", errors="replace") as handle:
                    for number in one_lock(handle.read()):
                        locks += 1
                        print(f"{os.path.relpath(path, ROOT)}:{number}: GITHUB_ACTIONS alone opens this. A runner on a person's own Mac sets it too: ask for the "
                              "account as well, which is `runner` on GitHub's Macs (lib.sh, \"A second lock\")")
    if count:
        print(f"\n{count} line(s) would change a person's Mac without asking whose it is, or could by accident. Use lib.sh's safe ways (scratch_dir, "
              "scratch_remove, started,\nkill_started, limit, at_exit); put `needs_throwaway_mac \"<would…>\"` after sourcing lib.sh, or `on_throwaway_mac &&` or "
              "`if on_throwaway_mac; then`\naround the step; or say `# safe anywhere: <why>` (of a variable: `# never empty: <why>`). See docs/TESTING.md, \"On a person's own Mac\".")
        return 1
    return 1 if locks else 0


if __name__ == "__main__":
    sys.exit(main())
