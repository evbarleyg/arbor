#!/usr/bin/env python3
"""Keeps the scripts working with the Python a person's Mac has.

A Mac has the python3 it was given one day: the one that comes with Xcode's Command Line Tools has long been 3.9, and whoever has another has
whichever they once installed. CI's runners have a newer one. So a line that only a newer Python can read passes every check there is
and stops `make check` on somebody's Mac: a backslash inside the braces of an f-string, which is read from 3.12 on, did.

This reads every *.py, every file that begins with `#!… python`, the pieces that stand in shell scripts, the Makefile and workflows
(`python3 - <<'TAG'` up to TAG, `… > x.py <<'TAG'`, `python3 -c '…'`) and what a page offers for pasting (```python). Python handed over in a way it
cannot follow (through a pipe, from a variable, `shell: python`) is a fault by itself: what cannot be read here is not kept to anything. A program
that a script holds in a string is not seen. It holds what it reads to FLOOR in three ways:

  read      Each piece is compiled by every Python older than this one that is to be found here (python3.9, python3.10 … on the PATH, and
            /usr/bin/python3). Nothing judges what an old Python can read as well as an old Python.
  grammar   Where there is none, this Python says what it can of the older grammar, which is most of it, and what f-strings may hold only
            since 3.12 is looked for in the tokens. Some is missed (`a[i := 0]`, `a[*b]`, a format three braces deep).
  names     What compiles can still fail when it runs: `zip(strict=True)`, `itertools.pairwise`, `datetime.UTC`, `import tomllib`,
            `int | None` where it is worked out, `(?>…)` and `a*+` in a pattern. The lists below are of what came after FLOOR. They are not
            complete. What stands under `if sys.version_info …`, `if hasattr(…)`, `if TYPE_CHECKING` or in a `try` that catches its absence is let be.

What no list has is found by trying: the workflow `Old Python` runs this, `make lint` and the tools' own tests under FLOOR itself.

A piece of a shell script in double quotes, or up to a TAG that is not quoted, is the shell's to fill in first. Such a piece is read with each `$…` taken
for a name; if that makes no Python it is left alone, and the last line says how many were.

Usage: scripts/lint-python.py              part of `make lint`
       scripts/lint-python.py FILE…        only these
       … --floor-here                      it is a fault, too, if no Python as old as FLOOR is here to read them: CI's way
       scripts/lint-python.py --self-test
Exit code 0 when all is well, 1 when something is not, 2 when it could not tell.
"""

import ast
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import tokenize

# The oldest python3 a Mac that can build Arbor is likely to have. .github/workflows/old-python.yml installs it; --self-test holds the two together.
FLOOR = (3, 9)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# The tree has some 120. Far fewer, or none from a shell script: then it is this script that has stopped seeing.
AT_LEAST = 60

# module → name → the Python it came with.
ATTRIBUTES = {
    "itertools": {"pairwise": "3.10", "batched": "3.12"}, "datetime": {"UTC": "3.11"}, "contextlib": {"chdir": "3.11", "aclosing": "3.10"},
    "enum": {"StrEnum": "3.11", "verify": "3.11", "member": "3.11"}, "hashlib": {"file_digest": "3.11"}, "math": {"cbrt": "3.11", "exp2": "3.11", "sumprod": "3.12"},
    "typing": {"Self": "3.11", "TypeAlias": "3.10", "ParamSpec": "3.10", "TypeGuard": "3.10", "Never": "3.11", "LiteralString": "3.11", "assert_never": "3.11",
               "override": "3.12", "Required": "3.11", "NotRequired": "3.11"},
    "os": {"process_cpu_count": "3.13"}, "operator": {"call": "3.11"}, "re": {"NOFLAG": "3.11"},
    "sys": {"stdlib_module_names": "3.10", "exception": "3.11", "orig_argv": "3.10"}, "statistics": {"correlation": "3.10", "covariance": "3.10", "linear_regression": "3.10"},
    "types": {"NoneType": "3.10", "EllipsisType": "3.10", "UnionType": "3.10"}, "inspect": {"get_annotations": "3.10"},
    "asyncio": {"timeout": "3.11", "TaskGroup": "3.11", "Runner": "3.11"}, "logging": {"getLevelNamesMapping": "3.11"}, "http": {"HTTPMethod": "3.11"},
    "random": {"binomialvariate": "3.12"}, "calendar": {"Month": "3.12", "Day": "3.12"},
}
MODULES = {"tomllib": "3.11", "wsgiref.types": "3.11"}
# function, by its last name → keyword → the Python it came with.
KEYWORDS = {
    "zip": {"strict": "3.10"}, "dataclass": {"slots": "3.10", "kw_only": "3.10", "match_args": "3.10", "weakref_slot": "3.11"}, "field": {"kw_only": "3.10"},
    "TemporaryDirectory": {"ignore_cleanup_errors": "3.10", "delete": "3.12"}, "NamedTemporaryFile": {"delete_on_close": "3.12"},
    "glob": {"root_dir": "3.10", "dir_fd": "3.10", "include_hidden": "3.11"}, "iglob": {"root_dir": "3.10", "dir_fd": "3.10", "include_hidden": "3.11"},
    "rmtree": {"onexc": "3.12", "dir_fd": "3.11"},
    **{name: {"process_group": "3.11", "pipesize": "3.10"} for name in ("run", "Popen", "call", "check_call", "check_output")},
    # In the last 3.9s too, but not in all of them.
    "extractall": {"filter": "3.12"}, "extract": {"filter": "3.12"},
    **{name: {"key": "3.10"} for name in ("bisect", "bisect_left", "bisect_right", "insort", "insort_left", "insort_right")},
}
METHODS = {"bit_count": "3.10", "hardlink_to": "3.10", "add_note": "3.11"}
BUILTINS = {"aiter": "3.10", "anext": "3.10", "EncodingWarning": "3.10", "ExceptionGroup": "3.11", "BaseExceptionGroup": "3.11"}
STATEMENTS = {"Match": ("3.10", "match … case"), "TryStar": ("3.11", "except*"), "TypeAlias": ("3.12", "type A = …")}
TAKE_A_PATTERN = {"compile", "search", "match", "fullmatch", "sub", "subn", "findall", "finditer", "split"}
TYPES = {"int", "str", "float", "bool", "bytes", "bytearray", "complex", "list", "dict", "set", "frozenset", "tuple", "type", "object"}
# Who catches one of these has thought of a Python that lacks the thing.
ABSENCE = {"ImportError", "ModuleNotFoundError", "NameError", "AttributeError", "TypeError", "Exception"}
ASKS_FIRST = {"version_info", "hasattr", "TYPE_CHECKING"}


class Piece:
    """Some Python: where it stands, on which line it begins, and whether the shell has a hand in it first. Without a text: a place where there is
    Python that cannot be followed."""

    def __init__(self, path, line, text, filled_in=False):
        self.path, self.line, self.text, self.filled_in = path, line, text, filled_in


# MARK: finding it

PYTHON = r"(?:\bpython[\d.]*|\$\{?PYTHON\w*(?::-[^}\s]*)?\}?)[\"']?"
SWITCHES = r"(?:\s+-[A-Za-z]+(?:\s+[a-z][\w:=,.]*)?)*?"
HEREDOC = re.compile(r"(?<!<)<<(?!<)(-?)\s*(\\?['\"]?)([A-Za-z_][\w-]*)")
TAKES_IT = re.compile(PYTHON + r"(?=\s)[^|;&]*$|>\s*\S+\.py[\"']?\s*$")
INLINE = re.compile(PYTHON + SWITCHES + r"\s+-[A-Za-z]*c\s+(['\"])")
# Python that is handed over somehow: each such line must be where a piece begins.
HANDED_OVER = re.compile(PYTHON + SWITCHES + r"\s+(?:-[A-Za-z]*c|-)(?=\s|$)|" + PYTHON + r"\s*<<|\|\s*" + PYTHON + r"\s*$|^\s*(?:-\s+)?shell:\s*python")
FENCE = re.compile(r"^```python[ \t]*\n(.*?)^```[ \t]*$", re.MULTILINE | re.DOTALL)


def indent(line):
    return len(line) - len(line.lstrip())


def pieces_in_shell(path, text, makefile=False):
    """The Python in a shell script, a Makefile or a workflow."""
    # A line that goes on after a backslash is one line. Every change made here keeps the length, so that a place in one text is the same place in the other.
    flat = list(text.replace("\\\n", "  "))
    found, begun = [], set()

    def line_of(place):
        return text.count("\n", 0, place) + 1

    def lines():
        start, whole = 0, "".join(flat)
        while start <= len(whole):
            end = whole.find("\n", start)
            end = len(whole) if end < 0 else end
            yield start, whole[start:end]
            start = end + 1

    def blank(start, end):
        flat[start:end] = [character if character == "\n" else " " for character in flat[start:end]]

    rows = list(lines())
    at = 0
    while at < len(rows):
        start, line = rows[at]
        at += 1
        here = None if line.lstrip().startswith("#") else HEREDOC.search(line)
        if not here:
            continue
        # The word that ends it stands alone, no further in than the line that began it (in a workflow everything is set in).
        end = next((n for n in range(at, len(rows)) if rows[n][1].strip() == here.group(3) and (here.group(1) or indent(rows[n][1]) <= indent(line))), None)
        if end is None:
            continue  # `a << b` in some arithmetic; if it is Python's, HANDED_OVER says so below
        if TAKES_IT.search(line[:here.start()]) or here.group(3).upper() in ("PY", "PYTHON"):
            found.append(Piece(path, line_of(rows[at][0]), textwrap.dedent(text[rows[at][0]:rows[end][0]]), filled_in=not here.group(2)))
            begun.add(start)
        blank(rows[at][0], rows[end][0] + len(rows[end][1]))  # whosever it is, it is no shell
        at = end + 1

    whole = "".join(flat)
    for start in INLINE.finditer(whole):
        begins = whole.rfind("\n", 0, start.start()) + 1
        if whole[begins:start.start()].lstrip().startswith("#"):
            continue
        quote, at, source = start.group(1), start.end(), []
        while at < len(text) and text[at] != quote:
            if quote == '"' and text[at] == "\\" and at + 1 < len(text):
                source.append(text[at + 1] if text[at + 1] in '"\\$`' else text[at:at + 2])
                at += 2
                continue
            source.append(text[at])
            at += 1
            # '\'' is how a single quote is written between single quotes.
            while quote == "'" and text[at:at + 4] == "'\\''":
                source.append("'")
                at += 4
        if at < len(text):
            code = textwrap.dedent("".join(source).replace("$$", "$") if makefile else "".join(source))
            found.append(Piece(path, line_of(start.end()), code if code.endswith("\n") else code + "\n", filled_in=quote == '"' or makefile))
            begun.add(begins)
            blank(start.end(), at)
    for start, line in lines():
        if start not in begun and not line.lstrip().startswith("#") and HANDED_OVER.search(line):
            found.append(Piece(path, line_of(start), None))
    return sorted(found, key=lambda piece: piece.line)


def pieces_of(path, text):
    first = text.split("\n", 1)[0]
    if path.endswith(".py") or (first.startswith("#!") and "python" in first):
        return [Piece(path, 1, text)]
    name = os.path.basename(path)
    if path.endswith((".sh", ".yml", ".yaml", ".bash", ".zsh")) or name == "Makefile" or (first.startswith("#!") and re.search(r"\b(ba|z|da|)sh\b", first)):
        return pieces_in_shell(path, text, makefile=name == "Makefile")
    if path.endswith(".md"):
        return [Piece(path, text.count("\n", 0, fence.start(1)) + 1, fence.group(1)) for fence in FENCE.finditer(text)]
    return []


def files(root=ROOT):
    """Every file that is git's or could become so: a new script is read before it is added."""
    try:
        listed = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=root, capture_output=True, text=True, check=False)
        if listed.returncode == 0:
            return sorted(name for name in listed.stdout.split("\0") if name)
    except OSError:
        pass
    # No git here, as in a container that sees only the files.
    return sorted(os.path.relpath(os.path.join(folder, name), root) for folder, _, names in os.walk(root) if not re.search(r"(^|/)\.(git|build)(/|$)", folder) for name in names)


# MARK: read by an old Python

# Runs under whatever is found, so it is written for the oldest.
READER = """
import json, sys
wrong = []
for place, source in enumerate(json.load(sys.stdin)):
    try:
        compile(source, "piece", "exec")
    except SyntaxError as error:
        wrong.append([place, error.lineno or 1, error.msg])
    except Exception as error:
        wrong.append([place, 1, "%s: %s" % (type(error).__name__, error)])
json.dump(wrong, sys.stdout)
"""


def asked(program):
    """Which Python a program says it is; None if it says nothing of the kind."""
    try:
        said = subprocess.run([program, "-c", "import sys; print(sys.version_info[0], sys.version_info[1])"], capture_output=True, text=True, timeout=30, check=False)
        return tuple(int(word) for word in said.stdout.split()) if said.returncode == 0 else None
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return None


def older_pythons(which=shutil.which, version_of=asked):
    """(version, program) of every Python here that is older than this one and no older than FLOOR, each version once."""
    found = {}
    for program in [which(f"python3.{minor}") for minor in range(FLOOR[1], sys.version_info[1])] + ["/usr/bin/python3", which("python3")]:
        version = version_of(program) if program else None
        if version and FLOOR <= version < sys.version_info[:2]:
            found.setdefault(version, program)
    return sorted(found.items())


def read_by(program, sources):
    """[place, line, what] for each of `sources` that `program` cannot read."""
    done = subprocess.run([program, "-c", READER], input=json.dumps(sources), capture_output=True, text=True, timeout=300, check=False)
    if done.returncode != 0:
        raise OSError(f"{program}: {done.stderr.strip()[-200:]}")
    return json.loads(done.stdout)


# MARK: what this Python can say of the older grammar

def grammar(source):
    """(line, since, what) for what FLOOR's grammar does not have, as far as this Python tells."""
    try:
        ast.parse(source, feature_version=FLOOR)
    except SyntaxError as error:
        try:
            tree = ast.parse(source)
        except SyntaxError:
            return [(error.lineno or 1, None, f"Python {sys.version_info[0]}.{sys.version_info[1]} cannot read this: {error.msg}")]
        # It names the line where the statement ends; these are where it begins.
        known = sorted((node.lineno, *STATEMENTS[type(node).__name__]) for node in ast.walk(tree) if type(node).__name__ in STATEMENTS)
        return (known or [(error.lineno or 1, "a later Python", error.msg)]) + in_f_strings(source)
    return in_f_strings(source)


def in_f_strings(source):
    """What an f-string may hold between its braces only since 3.12. Only a Python from 3.12 on takes f-strings apart into tokens; an older one needs no telling."""
    if not hasattr(tokenize, "FSTRING_START"):
        return []
    found, inside, before = [], [], None  # inside: the quote of each f-string that is open
    try:
        for token in tokenize.generate_tokens(io.StringIO(source).readline):
            # The text of an f-string, and of the format after a colon, comes as tokens of a kind of their own: it is between the braces of the
            # f-strings around that one. All else is between the braces of all that are open.
            around = inside[:-1] if token.type == tokenize.FSTRING_MIDDLE else inside
            # A backslash that only joins two lines is no token: the next one is further down without a new line having been told of.
            joined = before is not None and before.type not in (tokenize.NL, tokenize.NEWLINE) and token.start[0] > before.end[0]
            before, above = token, before
            if around:
                if joined or "\\" in token.string:
                    found.append((above.end[0] if joined else token.start[0], "3.12", "a backslash between the braces of an f-string: work it out on a line of its own, or add strings together"))
                elif token.type == tokenize.COMMENT:
                    found.append((token.start[0], "3.12", "a remark between the braces of an f-string"))
                elif "\n" in token.string and any(len(quote) == 1 for quote in around):
                    found.append((token.start[0], "3.12", "a new line between the braces of an f-string that is written on one line"))
                elif token.type in (tokenize.STRING, tokenize.FSTRING_START, tokenize.FSTRING_MIDDLE) and any(quote in token.string for quote in around):
                    found.append((token.start[0], "3.12", "the f-string's own quote between its braces: use the other kind inside"))
            if token.type == tokenize.FSTRING_START:
                inside.append(token.string.lstrip("rRbBfFuU"))
            elif token.type == tokenize.FSTRING_END:
                inside.pop()
    except (tokenize.TokenError, IndentationError, SyntaxError):
        pass  # then it does not compile either, and that has been said
    return found


# MARK: names that came later

def in_pattern(pattern):
    """What a regular expression holds that `re` reads only since 3.11. This Python's own reader of patterns says."""
    try:
        from re import _parser  # since 3.11, which is also when there was something to find
    except ImportError:
        return None
    try:
        parsed = _parser.parse(pattern)
    except Exception:  # not a pattern after all, or one with a mistake: not this script's business
        return None

    def walk(item):
        if isinstance(item, (list, tuple)) or type(item).__name__ == "SubPattern":
            for one in item:
                found = walk(one)
                if found:
                    return found
        return {"POSSESSIVE_REPEAT": "a quantifier that gives nothing back (`a*+`, `a++`, `a?+`)", "ATOMIC_GROUP": "a group that gives nothing back (`(?>…)`)"}.get(str(item))
    return walk(parsed)


def within(*nodes):
    return {id(inner) for node in nodes if node is not None for inner in ast.walk(node)}


def names(source):
    """(line, since, what) for what came to the library and the built-ins after FLOOR."""
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return []
    everything = list(ast.walk(tree))
    functions = [node for node in everything if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))]
    found, let_be = [], set()

    def called_so(node):
        return node.id if isinstance(node, ast.Name) else node.attr if isinstance(node, ast.Attribute) else None

    for node in everything:
        if isinstance(node, ast.Try) and any(handler.type is None or ABSENCE & {called_so(part) for part in ast.walk(handler.type)} for handler in node.handlers):
            let_be |= within(*node.body)
        elif isinstance(node, (ast.If, ast.IfExp)) and ASKS_FIRST & {called_so(part) for part in ast.walk(node.test)}:
            let_be |= within(node)

    def say(node, since, what):
        if since and id(node) not in let_be:
            found.append((node.lineno, since, what))

    known_as = {}  # the name a module goes by here → the module
    for node in everything:
        if isinstance(node, ast.Import):
            for alias in node.names:
                known_as[alias.asname or alias.name.split(".")[0]] = alias.name if alias.asname else alias.name.split(".")[0]
                say(node, MODULES.get(alias.name), f"the module {alias.name}")
        elif isinstance(node, ast.ImportFrom) and node.module:
            say(node, MODULES.get(node.module), f"the module {node.module}")
            for alias in node.names:
                say(node, ATTRIBUTES.get(node.module, {}).get(alias.name), f"{node.module}.{alias.name}")
    # Whatever the file names so itself, anywhere, is its own.
    own = {node.id for node in everything if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Store)} | {node.arg for node in everything if isinstance(node, ast.arg)}
    own |= {node.name for node in everything if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))}
    own |= {alias.asname or alias.name for node in everything if isinstance(node, ast.ImportFrom) for alias in node.names}

    # `A | B` of two types. An annotation is worked out when its line runs, but for a plain name's inside a function, and none is with annotations put off.
    put_off = any(isinstance(node, ast.ImportFrom) and node.module == "__future__" and any(alias.name == "annotations" for alias in node.names) for node in tree.body)
    inside_functions = within(*[statement for function in functions for statement in function.body])
    of_arguments = [one.annotation for function in functions for one in
                    [*function.args.posonlyargs, *function.args.args, *function.args.kwonlyargs, function.args.vararg, function.args.kwarg] if one] + [function.returns for function in functions]
    of_names = [node for node in everything if isinstance(node, ast.AnnAssign)]
    never = within(*[node.annotation for node in of_names if put_off or id(node) in inside_functions], *(of_arguments if put_off else []))
    annotations = within(*of_arguments, *[node.annotation for node in of_names]) - never

    def a_type(node):
        return ((isinstance(node, ast.Constant) and node.value is None) or (isinstance(node, ast.Name) and node.id in TYPES and node.id not in own)
                or (isinstance(node, ast.Subscript) and a_type(node.value)))

    def union(node):
        return isinstance(node, ast.BinOp) and isinstance(node.op, ast.BitOr)

    for node in everything:
        if union(node) and id(node) not in never:
            if a_type(node.left) or a_type(node.right) or (id(node) in annotations and not (isinstance(node.left, ast.Constant) and isinstance(node.right, ast.Constant))):
                say(node, "3.10", "`A | B` of two types, where it is worked out when the line runs: Optional or Union; in an annotation, `from __future__ import annotations` at the top")
        elif isinstance(node, ast.Attribute):
            module = known_as.get(node.value.id) if isinstance(node.value, ast.Name) else None
            say(node, ATTRIBUTES.get(module, {}).get(node.attr), f"{module}.{node.attr}")
            if module is None and node.attr not in own:
                say(node, METHODS.get(node.attr), f".{node.attr}()")
        elif isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load) and node.id not in own:
            say(node, BUILTINS.get(node.id), node.id)
        elif isinstance(node, ast.Call):
            called, given = called_so(node.func) or "", {keyword.arg for keyword in node.keywords}
            if called in own:
                continue
            for keyword in node.keywords:
                say(node, KEYWORDS.get(called, {}).get(keyword.arg), f"{called}({keyword.arg}=…)")
                if keyword.arg == "encoding" and isinstance(keyword.value, ast.Constant) and keyword.value.value == "locale":
                    say(node, "3.10", 'encoding="locale"')
            if called in ("isinstance", "issubclass") and len(node.args) == 2 and union(node.args[1]):
                say(node, "3.10", f"{called}(x, A | B): write a tuple, (A, B)")
            if called in ("to_bytes", "from_bytes") and isinstance(node.func, ast.Attribute) and len(node.args) < 2 and "byteorder" not in given:
                say(node, "3.11", f".{called}() without saying which end comes first")
            if called in ("format_exception", "print_exception", "format_exception_only") and len(node.args) == 1 and not given & {"value", "tb"}:
                say(node, "3.10", f"{called}(error) with the error alone: give its type and its traceback as well")
            if (called in TAKE_A_PATTERN and isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Name) and known_as.get(node.func.value.id) == "re"
                    and node.args and isinstance(node.args[0], ast.Constant) and isinstance(node.args[0].value, (str, bytes))):
                what = in_pattern(node.args[0].value)
                say(node.args[0], "3.11" if what else None, f"in a pattern, {what}")
    return found


# MARK: all of it

def as_python(piece):
    """The text to judge. Where the shell fills something in first, each `$…` stands for a name; None if that makes no Python, or nothing but the name."""
    if not piece.filled_in:
        return piece.text
    text = re.sub(r"\$\{[^}]*\}|\$\([^)]*\)|\$\w+|\$[@*#?!]", "shell", piece.text)
    try:
        ast.parse(text)
    except SyntaxError:
        return None
    return None if text.strip() == "shell" else text


def judge(pieces, pythons):
    """Lines to print, and how many pieces were left alone."""
    judged = [(piece, as_python(piece)) for piece in pieces if piece.text is not None]
    left_alone = sum(text is None for _, text in judged)
    judged = [(piece, text) for piece, text in judged if text is not None]
    lines, said = [], set()

    def say(piece, line, since, what):
        where = (piece.path, piece.line + line - 1)
        if where not in said:  # the first word on a line is enough: the ways overlap
            said.add(where)
            lines.append(f"{where[0]}:{where[1]}: {what}" + (f" (only from {since} on)" if since else ""))
    for piece in pieces:
        if piece.text is None:
            say(piece, 1, None, "Python is handed over here in a way that cannot be followed, so nothing keeps it to anything: write `python3 - <<'TAG'` or `python3 -c '…'`")
    for version, program in pythons:
        for place, line, what in read_by(program, [text for _, text in judged]):
            say(judged[place][0], line, None, f"Python {version[0]}.{version[1]} cannot read this: {what}")
    for piece, text in judged:
        for line, since, what in grammar(text) + names(text):
            say(piece, line, since, what)
    return sorted(lines, key=lambda line: (line.split(":")[0], int(line.split(":")[1]))), left_alone


def run(given, floor_here=False, root=ROOT, pythons=None):
    """What main does, said into a list: (exit code, lines)."""
    floor = f"{FLOOR[0]}.{FLOOR[1]}"
    if sys.version_info[:2] < FLOOR:
        return 1, [f"lint-python: this is Python {sys.version_info[0]}.{sys.version_info[1]}, and the scripts here want {floor} or later"]
    pieces = []
    for name in given or files(root):
        path = name if given else os.path.join(root, name)
        if given and not os.path.isfile(path):
            return 2, [f"lint-python: cannot tell: there is no file {name}"]
        if os.path.islink(path) or not os.path.isfile(path):
            continue
        try:
            with open(path, encoding="utf-8-sig") as handle:
                pieces += pieces_of(name, handle.read())
        except (OSError, UnicodeDecodeError):
            continue  # a picture, say
    pythons = older_pythons() if pythons is None else pythons
    try:
        lines, left_alone = judge(pieces, pythons)
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        return 2, [f"lint-python: cannot tell: an older Python did not get through its reading ({error})"]
    versions = [version for version, _ in pythons] + [sys.version_info[:2]]
    if not given and (len(pieces) < AT_LEAST or not any(not piece.path.endswith(".py") for piece in pieces)):
        lines.append(f"lint-python: only {len(pieces)} pieces of Python were found, or none in a shell script: this script has stopped seeing")
    if floor_here and versions[0] != FLOOR:
        lines.append(f"lint-python: no Python {floor} is here to read them, and one was asked for")
    if lines:
        return 1, lines + [f"lint-python: {len(lines)} to put right: the scripts must work with the Python a Mac has, from {floor} on (scripts/lint-python.py says more)"]
    return 0, [f"{len(pieces)} pieces of Python keep to {floor}, going by Python " + ", ".join(f"{major}.{minor}" for major, minor in versions)
               + ("" if versions[0] == FLOOR else f" and lists of what came later; {floor} itself is not here, CI has it")
               + (f"; {left_alone} that the shell fills in made no Python without it and were left alone" if left_alone else "")]


# MARK: --self-test

def self_test():
    wrong, rows = [], 0

    def row(what, got, expected):
        nonlocal rows
        rows += 1
        if got != expected:
            wrong.append(f"✘ {what}: expected {expected}, got {got}")

    new = sys.version_info >= (3, 12)
    if not new:
        print(f"lint-python: this is Python {sys.version_info[0]}.{sys.version_info[1]}: the rows on what only a newer one can take apart are left out")
    cases = [
        ("nothing newer than the floor", "import os\nprint(f\"{os.sep!r:>4} {'a'} {1 + 1}\")\nx = {**{}, 'a': [1][0]}\nwith open('x') as a, open('y') as b: pass\n", []),
        ("what came with the floor itself", "x = 'abc'.removeprefix('a')\ny = {} | {}\ndef f(a: list[int]) -> dict[str, int]: pass\n", []),
        ("match", "match x:\n    case 1: pass\n", [(1, "3.10")]) if sys.version_info >= (3, 10) else None,
        ("except*", "try:\n    pass\nexcept* OSError:\n    pass\n", [(1, "3.11")]) if sys.version_info >= (3, 11) else None,
        ("a type of its own", "x = 1\ntype A = int\n", [(2, "3.12")]) if new else None,
        ("what nobody can read", "x = (\n", [(1, None)]),
        ("the line that stopped `make check`", "import re\nx = 1\ny = f\"a {re.search(r'[\\w.]+', 'b').group()} c\"\n", [(3, "3.12")]) if new else None,
        ("a backslash in the text of an f-string is as old as f-strings", "x = f\"a\\n{1}\\t\"\ny = rf'\\w{1}'\n", []),
        ("in the format after the colon too", "x = f\"{1:\\t>4}\"\n", []),
        ("a backslash at the end of a line between the braces", "x = f'''{1 + \\\n 1}'''\n", [(1, "3.12")]) if new else None,
        ("the f-string's own quote between its braces", "d = {}\nx = f\"{d[\"a\"]}\"\n", [(2, "3.12")]) if new else None,
        ("the other kind of quote", "d = {}\nx = f\"{d['a']}\" + f'{d[\"a\"]}'\n", []),
        ("one quote inside three of its kind", "d = {}\nx = f\"\"\"{d[\"a\"]}\"\"\"\n", []),
        ("an f-string in an f-string, in the same quotes", "x = f\"{f\"{1}\"}\"\n", [(1, "3.12")]) if new else None,
        ("in the other quotes", "x = f\"{f'{1}'}\"\n", []),
        ("the outer one's quote in the inner one", "x = f\"{f'{\"a\"}'}\"\n", [(1, "3.12")]) if new else None,
        ("not if the outer one has three", "x = f\"\"\"{f'{\"a\"}'}\"\"\"\n", []),
        ("a new line in an inner one with three quotes, in an outer one on one line", "x = f\"{f'''{1 +\n1}'''}\"\n", [(1, "3.12")]) if new else None,
        ("after the inner one has ended, the outer one goes on", "x = f\"{f'{1}' + '\\n'}\"\n", [(1, "3.12")]) if new else None,
        ("a remark between the braces", "x = f'''{1 # one\n}'''\n", [(1, "3.12")]) if new else None,
        ("a new line between the braces of a one-line f-string", "x = f'{1 +\n1}'\n", [(1, "3.12")]) if new else None,
        ("of one with three quotes", "x = f'''{1 +\n1}'''\n", []),
        ("a dictionary between the braces, and braces that stand for themselves", "x = f\"{ {'a': 1}['a'] } {{}} {'}'}\"\n", []),
        ("a width that is worked out, a name with its value, two strings side by side", "w = x = 1\ny = f\"{x!r:>{w}} {x=} {'a' 'b'} {x:{'>'}4}\"\n", []),
        ("a quote of the other kind in the text", "x = f\"it's {1}\" + f'say \"{1}\"'\n", []),
        ("a backslash in a width that is worked out", "x = f\"{1:{'\\t'}>4}\"\n", [(1, "3.12")]) if new else None,
        ("after an f-string has ended, a backslash is a backslash", "x = f'{1}' + '\\n'\n", []),
        ("zip(strict=)", "x = 1\nfor a, b in zip([], [], strict=True): pass\n", [(2, "3.10")]),
        ("itertools.pairwise, by the module", "import itertools\nx = itertools.pairwise([])\n", [(2, "3.10")]),
        ("by another name for the module", "import itertools as it\nx = it.batched([], 2)\n", [(2, "3.12")]),
        ("by its own name", "from itertools import pairwise\n", [(1, "3.10")]),
        ("something else that is called so", "class A: pairwise = 1\nx = A.pairwise\nimport mine\ny = mine.pairwise\n", []),
        ("datetime.UTC", "import datetime\nx = datetime.datetime.now(datetime.UTC)\n", [(2, "3.11")]),
        ("datetime.timezone.utc", "import datetime\nx = datetime.datetime.now(datetime.timezone.utc)\n", []),
        ("tomllib", "import tomllib\n", [(1, "3.11")]),
        ("from tomllib", "from tomllib import load\n", [(1, "3.11")]),
        ("A | None for an argument", "def f(a: int | None = None): pass\n", [(1, "3.10")]),
        ("for what comes back", "def f() -> int | None: pass\n", [(1, "3.10")]),
        ("inside something", "from typing import List\ndef f(a: List[int | None]): pass\n", [(2, "3.10")]),
        ("for a name outside any function, and in a class", "x: int | None = None\nclass A:\n    y: int | str = 1\n", [(1, "3.10"), (3, "3.10")]),
        ("for a name in a function, where it is never worked out", "def f():\n    x: int | None = None\n", []),
        ("with annotations put off", "from __future__ import annotations\ndef f(a: int | None) -> int | None: pass\nx: int | None = None\n", []),
        ("| between numbers and sets is as old as Python", "x = 1 | 2\ny = {1} | {2}\ndef f(a=1 | 2): pass\n", []),
        ("isinstance(x, A | B)", "x = isinstance(1, int | str)\n", [(1, "3.10")]),
        ("isinstance with a tuple", "x = isinstance(1, (int, str))\n", []),
        ("int.bit_count", "x = (5).bit_count()\n", [(1, "3.10")]),
        ("bisect(key=)", "import bisect\nbisect.bisect_left([], 1, key=len)\n", [(2, "3.10")]),
        ("sorted(key=)", "sorted([], key=len)\n", []),
        ("TemporaryDirectory(ignore_cleanup_errors=)", "import tempfile\ntempfile.TemporaryDirectory(ignore_cleanup_errors=True)\n", [(2, "3.10")]),
        ("ExceptionGroup", "try: pass\nexcept ExceptionGroup: pass\n", [(2, "3.11")]),
        ("a name of one's own that is called so", "def anext(x): return x\nanext(1)\n", []),
        ("a quantifier that gives nothing back", "import re\nre.compile(r'a*+b')\n", [(2, "3.11")]) if sys.version_info >= (3, 11) else None,
        ("a group that gives nothing back", "import re\nx = 1\nre.search('(?>a)', 'a')\n", [(3, "3.11")]) if sys.version_info >= (3, 11) else None,
        ("a plus that is meant, then one or more; a star and a plus to choose from", "import re\nre.compile(r'a\\++')\nre.compile('[*+]+')\n", []),
        ("a text that is no pattern, given to something that is not re", "import mine\nmine.compile('a*+')\n'a*+'.split('*+')\n", []),
        ("a function with a type in brackets: what this Python says of it, without a name for it here", "def f[T](a): pass\n", [(1, "a later Python")]) if new else None,
        ("one fault of a kind does not hide the other", "match x:\n    case 1: pass\ny = f\"{'\\n'}\"\n", [(1, "3.10"), (3, "3.12")]) if new else None,
        ("a backslash in the text of an inner f-string is between the outer one's braces", "x = f\"{f'a\\n{1}'}\"\n", [(1, "3.12")]) if new else None,
        ("so is the outer one's quote there", "x = f'{f\"it's {1}\"}'\n", [(1, "3.12")]) if new else None,
        ("a string of several lines in an f-string on one", "x = f\"{'''a\nb'''}\"\n", [(1, "3.12")]) if new else None,
        ("whatever letters stand before the quote", "x = RF\"{\"a\"}\" + fR'{1}'\n", [(1, "3.12")]) if new else None,
        ("asked first, by the version", "import sys\nif sys.version_info >= (3, 11):\n    import tomllib\nelse:\n    tomllib = None\n", []),
        ("by hasattr, in one line", "import os\nn = os.process_cpu_count() if hasattr(os, 'process_cpu_count') else 1\n", []),
        ("only for whoever checks types", "from typing import TYPE_CHECKING\nif TYPE_CHECKING:\n    from typing import Self\n", []),
        ("tried, and its absence caught", "try:\n    import tomllib\nexcept ImportError:\n    tomllib = None\n", []),
        ("tried, and something else caught", "try:\n    import tomllib\nexcept OSError:\n    pass\n", [(2, "3.11")]),
        ("after the try", "try:\n    pass\nexcept ImportError:\n    pass\nimport tomllib\n", [(5, "3.11")]),
        ("what is done about its absence is not let be", "try:\n    pass\nexcept ImportError:\n    import tomllib\n", [(4, "3.11")]),
        ("tried, and everything caught", "try:\n    import tomllib\nexcept:\n    pass\n", []),
        ("a class of one's own | None, list[int] | a class of one's own", "X = Mine | None\nY = list[int] | Mine\n", [(1, "3.10"), (2, "3.10")]),
        ("other things done to None and to types", "x = '%s' % None\ny = [int] * 2\n", []),
        ("something a module of one's own has", "import mine\nmine.add_note(1)\n", []),
        ("a method of one's own that is called so", "class A:\n    def add_note(self, x): pass\nA().add_note(1)\n", []),
        ("a function of one's own that takes such a keyword", "def run(process_group=0): pass\nrun(process_group=1)\n", []),
        ("an argument, and something imported, that are called so", "from mine import ExceptionGroup\ndef f(anext): return anext, ExceptionGroup\n", []),
        ("a module imported by a part of it", "import os.path\nx = os.process_cpu_count()\n", [(2, "3.13")]),
        ("A | None given a name", "X = int | None\n", [(1, "3.10")]),
        ("handed to a function", "from typing import cast\nx = cast(int | None, 1)\n", [(2, "3.10")]),
        ("for a name under an if, outside any function", "if x:\n    y: A | B = 1\n", [(2, "3.10")]),
        ("numbers in an annotation", "from typing import Annotated\ndef f(a: Annotated[int, 1 | 2]): pass\n", []),
        ("something of one's own making that is called int", "int = 1\nx = int | 2\n", []),
        ("issubclass(x, A | B), of classes of one's own", "x = issubclass(A, B | C)\n", [(1, "3.10")]),
        ("every kind of argument", "async def f(a: A | B, /): pass\ndef g(*, a: A | B): pass\ndef h(*a: A | B): pass\ndef i(**a: A | B): pass\n", [(1, "3.10"), (2, "3.10"), (3, "3.10"), (4, "3.10")]),
        ("subprocess.run(process_group=), check_output(pipesize=)", "import subprocess\nsubprocess.run([], process_group=0)\nsubprocess.check_output([], pipesize=1)\n", [(2, "3.11"), (3, "3.10")]),
        ("shutil.rmtree(onexc=), typing.Self, error.add_note", "import shutil, typing\nshutil.rmtree('x', onexc=f)\nx = typing.Self\ne.add_note('x')\n", [(2, "3.12"), (3, "3.11"), (4, "3.11")]),
        ("a number into bytes without saying which end comes first", "x = (5).to_bytes(2)\ny = int.from_bytes(b'a')\n", [(1, "3.11"), (2, "3.11")]),
        ("saying it", "x = (5).to_bytes(2, 'big')\ny = int.from_bytes(b'a', byteorder='big')\n", []),
        ("an error printed by itself", "import traceback\ntraceback.print_exception(e)\nx = traceback.format_exception(e)\n", [(2, "3.10"), (3, "3.10")]),
        ("with its type and traceback", "import traceback\ntraceback.print_exception(type(e), e, e.__traceback__)\n", []),
        ("encoding=\"locale\"", "open('x', encoding='locale')\nopen('x', encoding='utf-8')\n", [(1, "3.10")]),
        ("a pattern of bytes, a pattern for findall, a pattern on a line of its own", "import re\nre.sub(b'a++', b'', b'')\nre.findall(\n    'a?+', '')\n", [(2, "3.11"), (4, "3.11")]) if sys.version_info >= (3, 11) else None,
        ("a pattern with a mistake in it is somebody else's business", "import re\nre.compile('(')\n", []),
    ]
    for what, source, expected in filter(None, cases):
        row(what, sorted({(line, since) for line, since, _ in grammar(source) + names(source)}, key=str), expected)
    # What is said here of the older grammar is held to the older Pythons there are.
    for version, program in older_pythons():
        cannot = {place for place, _, _ in read_by(program, [source for _, source, _ in filter(None, cases)])}
        for place, (what, source, _) in enumerate(filter(None, cases)):
            if version > FLOOR and any(since == "a later Python" for _, since, _ in grammar(source)):
                continue  # later than the floor is all that is known of it
            said = any(since is None or not since[0].isdigit() or tuple(int(part) for part in since.split(".")) > version for _, since, _ in grammar(source))
            row(f"{what}: whether Python {version[0]}.{version[1]} can read it", place not in cannot, not said)

    def found(path, text):
        return [(piece.line, piece.text, piece.filled_in) for piece in pieces_of(path, text)]
    row("a script in Python, by its name", found("a/b.py", "x = 1\n"), [(1, "x = 1\n", False)])
    row("by its first line", found("a/b", "#!/usr/bin/env python3\nx = 1\n"), [(1, "#!/usr/bin/env python3\nx = 1\n", False)])
    row("something else", found("a/b.md", "python3 -c 'x = 1'\n") + found("a/b", "python3 -c 'x = 1'\n"), [])
    row("up to a quoted word", found("a.sh", "echo\npython3 - \"$1\" <<'EOF'\nimport sys\nx = 1\nEOF\necho\n"), [(3, "import sys\nx = 1\n", False)])
    row("a shell script by its first line", found("a", "#!/bin/bash\npython3 - <<'EOF'\nx = 1\nEOF\n"), [(3, "x = 1\n", False)])
    row("up to a word that is not quoted: the shell fills it in", found("a.sh", "python3 - <<EOF\nx = $1\nEOF\n"), [(2, "x = $1\n", True)])
    row("set in, as in a workflow", found("a.yml", "    run: |\n      python3 - <<'PY'\n      if x:\n          y = 1\n      PY\n"), [(3, "if x:\n    y = 1\n", False)])
    row("with <<-", found("a.sh", "\tpython3 - <<-'EOF'\n\tx = 1\n\tEOF\n"), [(2, "x = 1\n", False)])
    row("something else's heredoc", found("a.sh", "cat <<'EOF'\nnot python\nEOF\n"), [])
    row("in a remark", found("a.sh", "# python3 - <<'EOF'\nx = 1\nEOF\n# python3 -c 'x = 1'\n"), [])
    row("two in one script", [line for line, _, _ in found("a.sh", "python3 - <<'A'\nx = 1\nA\npython3 - <<'A'\ny = 1\nA\n")], [2, 5])
    row("-c, between single quotes", found("a.sh", "x=$(python3 -c 'import sys; print(1)' \"$1\")\n"), [(1, "import sys; print(1)\n", False)])
    row("over several lines", found("a.sh", "echo\npython3 -c '\nimport sys\nprint(1)\n' x\n"), [(2, "\nimport sys\nprint(1)\n", False)])
    row("with a single quote, as the shell writes one there", found("a.sh", "python3 -c 'print('\\''a'\\'')'\n"), [(1, "print('a')\n", False)])
    row("between double quotes", found("a.sh", 'python3 -c "print(\\"$1\\")"\n'), [(1, 'print("$1")\n', True)])
    row("after other switches", found("a.sh", "python3 -I -c 'x = 1'\npython3 -Ic 'y = 1'\n"), [(1, "x = 1\n", False), (2, "y = 1\n", False)])
    row("in the Makefile, where a dollar is written twice", found("Makefile", "a:\n\t@python3 -c 'import re; re.sub(r\"x$$\", \"\", \"\")'\n"),
        [(2, 'import re; re.sub(r"x$", "", "")\n', True)])
    row("a script that is only run", found("a.sh", "python3 scripts/x.py --check 'a'\n"), [])
    lost = [(1, None, False)]
    row("the line goes on before <<", found("a.sh", "A=1 python3 - \"$1\" \\\n  \"$2\" << 'PYTHON'\nx = 1\nPYTHON\n"), [(3, "x = 1\n", False)])
    row("written into a file that is Python by its name", found("a.sh", "cat > \"$root/x.py\" <<'EOF'\nx = 1\nEOF\n"), [(2, "x = 1\n", False)])
    row("up to a word that says so", found("a.sh", "cat > \"$x\" <<'PY'\nx = 1\nPY\n"), [(2, "x = 1\n", False)])
    row("a word in double quotes, or after a backslash, is quoted as well", found("a.sh", "python3 - <<\"A\"\nx = 1\nA\npython3 - <<\\A\ny = 1\nA\n"), [(2, "x = 1\n", False), (5, "y = 1\n", False)])
    row("a word with a hyphen", found("a.sh", "python3 - <<'END-PY'\nx = 1\nEND-PY\n"), [(2, "x = 1\n", False)])
    row("without the hyphen for standard input", found("a.sh", "python3 <<'EOF'\nx = 1\nEOF\n"), [(2, "x = 1\n", False)])
    row("the word further in than where it began does not end it", found("a.sh", "python3 - <<'EOF'\nif x:\n    EOF\nEOF\n"), [(2, "if x:\n    EOF\n", False)])
    row("Python's heredoc without an end", found("a.sh", "python3 - <<'EOF'\nx = 1\n"), lost)
    row("with <<-, the word may stand further in", found("a.sh", "python3 - <<-'EOF'\n\tx = 1\n\tEOF\n"), [(2, "x = 1\n", False)])
    row("a here-string whose word stands alone further down", found("a.sh", "python3 - <<< x\nx\n"), lost)
    row("what stands in a piece is no shell either", found("a.sh", "python3 -c '\ny = 1 | python3\n'\n"), [(1, "\ny = 1 | python3\n", False)])
    row("what stands in somebody else's heredoc is no shell", found("a.sh", "cat <<EOF\nTry: python3 -c 'x = 1'\necho x | python3 -\nEOF\n"), [])
    row("<< in some arithmetic", found("a.sh", "x=$((1 << y))\ny\n"), [])
    row("python, python3.11, $PYTHON, \"${PYTHON:-python3}\"", [text for _, text, _ in found("a.sh", "python -c 'a'\npython3.11 -c 'b'\n$PYTHON -c 'c'\n\"${PYTHON:-python3}\" -c 'd'\n")], ["a\n", "b\n", "c\n", "d\n"])
    row("something that only ends like it", found("a.sh", "mypython3 -c 'a'\n"), [])
    row("a switch that takes a word", found("a.sh", "python3 -W ignore -X utf8 -c 'x = 1'\n"), [(1, "x = 1\n", False)])
    row("-c on the next line", found("a.sh", "python3 \\\n  -c 'x = 1'\n"), [(2, "x = 1\n", False)])
    row("-c set in", found("a.sh", "python3 -c '\n    if x:\n        y = 1\n'\n"), [(1, "\nif x:\n    y = 1\n", False)])
    row("-c without an end", found("a.sh", "python3 -c 'x = 1\n"), lost)
    row("Python's own backslash at the end of a line stays", found("a.sh", "python3 -c 'x = 1 + \\\n1'\n"), [(1, "x = 1 + \\\n1\n", False)])
    row("what a backslash does between double quotes", found("a.sh", 'python3 -c "a = \\`b\\` + \\\\ + \'\\n\'"\n'), [(1, "a = `b` + \\ + '\\n'\n", True)])
    for name in ("a.yaml", "a.bash", "a.zsh"):
        row(f"by its name: {name}", len(found(name, "python3 -c 'x = 1'\n")), 1)
    for first in ("#!/bin/sh", "#!/bin/zsh", "#!/usr/bin/env bash", "#!/bin/dash"):
        row(f"by its first line: {first}", len(found("a", first + "\npython3 -c 'x = 1'\n")), 1)
    row("by its first line: something else", found("a", "#!/usr/bin/env fish\npython3 -c 'x = 1'\n"), [])
    for what, text in (("through a pipe", "echo 'x = 1' | python3 -\n"), ("through a pipe, without the hyphen", "echo 'x = 1' | python3\n"), ("as a here-string", "python3 - <<< 'x = 1'\n"),
                       ("in $'…'", "python3 -c $'x = 1'\n"), ("without quotes", "python3 -c pass\n"), ("after something that could end the command", "python3 - 2>&1 <<'EOF'\nx = 1\nEOF\n")):
        row(f"handed over {what}: it cannot be followed", found("a.sh", text), lost)
    row("a workflow's step in Python", found("a.yml", "    - shell: python\n      run: |\n        x = 1\n") + found("a.yml", "      shell: python\n"), lost + lost)
    row("a module that is run; a script with a -c of its own; a script given a hyphen", found("a.sh", "python3 -m json.tool\npython3 x.py -c 5\npython3 x.py - <in\n"), [])
    row("what a page offers for pasting", found("a.md", "Text.\n\n```python\nx = 1\n```\n\n```bash\npython3 -c 'y'\n```\n\n```python\ny = 2\n```\n"), [(4, "x = 1\n", False), (12, "y = 2\n", False)])
    row("in the order they stand in", [line for line, _, _ in found("a.sh", "python3 -c 'a'\npython3 - <<'E'\nb\nE\necho | python3\npython3 -c 'c'\n")], [1, 3, 5, 6])

    def judged(path, text, pythons=()):
        return judge(pieces_of(path, text), list(pythons))[0]
    row("the line is the file's, not the piece's", judged("a.sh", "echo\necho\npython3 - <<'EOF'\nx = 1\nimport tomllib\nEOF\n"), ["a.sh:5: the module tomllib (only from 3.11 on)"])
    row("one word a line", len(judged("a.py", "import tomllib, itertools; itertools.pairwise([])\n")), 1)
    row("what the shell fills in stands for a name", judged("a.sh", 'python3 -c "import tomllib; print($1, ${A:-b}, $(ls))"\n'), ["a.sh:1: the module tomllib (only from 3.11 on)"])
    row("where that makes no Python, it is left alone", judged("a.sh", 'python3 -c "$1 tomllib $2"\n'), [])
    row("Python that cannot be followed is a fault", [line.split(": ")[0] for line in judged("a.sh", "echo\necho x | python3 -\n")], ["a.sh:2"])
    row("$@, $# and their kind", judged("a.sh", 'python3 -c "import tomllib; print($@, $#, $?)"\n'), ["a.sh:1: the module tomllib (only from 3.11 on)"])
    row("how many were left alone", [judge(pieces_of("a.sh", text), [])[1] for text in ('python3 -c "$1 x $2"\n', 'python3 -c "$code"\n', 'python3 -c "x = $1"\n', "python3 -c 'x = 1'\n")], [1, 1, 0, 0])
    row("what was left alone does not shift the places of the others", [line.split(": ")[0] for line in
        judge(pieces_of("a.sh", 'python3 -c "$1 x $2"\n') + pieces_of("b.py", "x = 1\n") + pieces_of("c.py", "x = = 1\n"), [((3, 9), sys.executable)])[0]], ["c.py:1"])
    if sys.version_info >= (3, 10):
        row("with no older Python here, the grammar is still judged", len(judged("a.py", "match x:\n    case 1: pass\n")), 1)
    row("in order", [line.split(": ")[0] for line in judge(pieces_of("b.py", "import tomllib\n") + pieces_of("a.py", "x = 1\nimport tomllib\n" + "\n" * 7 + "import tomllib\n"), [])[0]],
        ["a.py:2", "a.py:10", "b.py:1"])

    here = sys.version_info[:2]
    versions = {"/a/python3.9": (3, 9), "/a/python3.10": (3, 10), "/usr/bin/python3": (3, 9), "/a/python3": here, "/a/python3.8": (3, 8)}
    if here > (3, 10):
        row("the older Pythons there are, each version once, none below the floor and not this one again",
            older_pythons(which=lambda name: "/a/" + name if "/a/" + name in versions else None, version_of=versions.get), [((3, 9), "/a/python3.9"), ((3, 10), "/a/python3.10")])
    row("one from before the floor", older_pythons(which=lambda name: None, version_of={"/usr/bin/python3": (3, 8)}.get), [])
    row("none", older_pythons(which=lambda name: None, version_of=lambda program: None), [])
    row("one that says something else", older_pythons(which=lambda name: None, version_of=lambda program: (3,)), [])
    if here > FLOOR:
        row("macOS's own, and the one that is called python3", [older_pythons(which={"python3": "/b/python3"}.get, version_of={program: FLOOR}.get) for program in ("/usr/bin/python3", "/b/python3")],
            [[(FLOOR, "/usr/bin/python3")], [(FLOOR, "/b/python3")]])
    row("a Python is asked which it is", [asked(sys.executable), asked("/nowhere/python3"), asked("/bin/echo"), asked("/usr/bin/false")], [here, None, None, None])
    row("what stops an old Python in another way than a mistake in the grammar", [place[:2] for place in read_by(sys.executable, ["x = 1\n", "x = 1\0\n"])], [[1, 1]])
    row("read by a real Python: this one", read_by(sys.executable, ["x = 1\n", "x = (\n", "y = 2\n", "\n\nz = = 1\n"])[1][:2], [3, 3])
    row("what it says is printed with its version", judged("a.py", "x = 1\nx = = 1\n", [((3, 9), sys.executable)])[0].split(": ", 2)[:2], ["a.py:2", "Python 3.9 cannot read this"])
    old = older_pythons()
    if old and new:
        row(f"a real older one, {old[0][1]}, on the line that stopped `make check`", [place[:2] for place in read_by(old[0][1], ["x = 1\n", "y = f\"{'\\n'}\"\n"])], [[1, 1]])

    with tempfile.TemporaryDirectory() as folder:
        def write(name, text, encoding="utf-8"):
            os.makedirs(os.path.dirname(os.path.join(folder, name)), exist_ok=True)
            with open(os.path.join(folder, name), "w", encoding=encoding) as handle:
                handle.write(text)
            return os.path.join(folder, name)
        good, bad = write("scripts/good.py", "x = 1\n"), write("scripts/bad.sh", "python3 - <<'EOF'\n\nimport tomllib\nEOF\n")
        write(".git/hooks/x.py", "import tomllib\n")
        write("picture.py", "\xff", encoding="latin-1")
        row("a file that is well", run([good], pythons=[]),
            (0, [f"1 pieces of Python keep to 3.9, going by Python {here[0]}.{here[1]}" + ("" if here == FLOOR else " and lists of what came later; 3.9 itself is not here, CI has it")]))
        row("one that is not", (run([good, bad], pythons=[])[0], run([good, bad], pythons=[])[1][0]), (1, f"{bad}:3: the module tomllib (only from 3.11 on)"))
        row("one that is not there", run([good, os.path.join(folder, "none.py")], pythons=[])[0], 2)
        row("one that begins with a mark for the order of bytes", run([write("bom.py", "x = 1\n", encoding="utf-8-sig")], pythons=[])[0], 0)
        row("the Pythons that were found do the reading", run([write("worse.py", "x = = 1\n")], pythons=[((3, 9), sys.executable)])[1][0].split(": ")[1], "Python 3.9 cannot read this")
        row("an older Python that does not get through its reading", run([good], pythons=[((3, 9), "/usr/bin/false")])[0], 2)
        row("what was left alone is told of", "; 1 that the shell fills in made no Python without it and were left alone" in run([write("c.sh", 'python3 -c "$code"\n')], pythons=[])[1][0], True)
        if here > FLOOR:
            row("--floor-here, and it is not", run([good], floor_here=True, pythons=[])[0], 1)
        row("--floor-here, and it is", run([good], floor_here=True, pythons=[(FLOOR, sys.executable)] if here > FLOOR else [])[0], 0)
        os.remove(os.path.join(folder, "worse.py"))
        whole = run([], root=folder, pythons=[])
        row("a whole folder that is not git's: all of it but what is git's own", [line.split(": ")[0] for line in whole[1][:-2]], ["scripts/bad.sh:3"])
        row("far fewer pieces than there should be: this script has stopped seeing", (whole[0], "stopped seeing" in whole[1][-2]), (1, True))
        outside = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        shutil.rmtree(os.path.join(folder, ".git"))
        if shutil.which("git") and subprocess.run(["git", "init", "--quiet"], cwd=folder, env=outside, capture_output=True, check=False).returncode == 0:
            write(".gitignore", "bom.py\n")
            row("what git does not know yet is read too, but for what it is told to overlook", files(folder), [".gitignore", "c.sh", "picture.py", "scripts/bad.sh", "scripts/good.py"])
    with open(os.path.join(ROOT, ".github", "workflows", "old-python.yml"), encoding="utf-8") as handle:
        steps = handle.read()
    row("the workflow installs the floor, makes sure of it, and asks for it to be here",
        [f'python-version: "{FLOOR[0]}.{FLOOR[1]}"' in steps, f"!= {FLOOR}" in steps, "lint-python.py --floor-here" in steps, "lint-python.py --self-test" in steps], [True] * 4)

    for line in wrong:
        print(line)
    print(f"{rows - len(wrong)} of {rows} lint-python situations came out as expected")
    return 1 if wrong else 0


def main(arguments):
    if "--self-test" in arguments:
        return self_test()
    code, lines = run([name for name in arguments if not name.startswith("-")], floor_here="--floor-here" in arguments)
    print("\n".join(lines))
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
