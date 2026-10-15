#!/usr/bin/env python3
"""Keeps collab/parity.json and collab/reality.json in a shape that git can merge, and merges them by what they mean where git cannot.

Many pull requests land through one trunk, and nearly every one lists its tests in collab/parity.json. While an item was one line, with
up to 110 names on it, two pull requests that added a test to the same item changed the same line, and to neighbouring items, neighbouring
lines. Git called that a conflict, though nobody disagreed about anything. collab/reality.json, the ledger of macOS's surprises, had a key to
a line all along, but every new case went to its end, where it met everybody else's. There are two cures, and each covers what the other cannot:

  the shape   A key to a line and a name to a line, the keys in one order, the names of a list sorted, nothing listed twice. Two pull
              requests then meet only if they put a name into the same gap. In the ledger the cases stand in the order of their ids, so that
              a new one goes where the alphabet puts it. `--tidy` writes it and `make lint` (`--check`) holds the files to
              it. This is for whoever merges without this script, above all GitHub: a pull request that it cannot merge gets no CI run.
  the merge   `--merge` reads the three files for what they say, whatever shape each is in. `make hooks` (`--install`) has git call it by
              itself, in a rebase, a merge, a cherry-pick, and in `git am -3` wherever a patch does not apply as it is:

                an object            key by key
                a list of objects    by their "id". They stay in the order they were in, or in that of the side that moved some; what a side
                                     added follows what it followed there
                "tests", "e2e"       as sets: what either side added is in it, what either side took off is not
                "knobs", "guards", "sources", "backlog", "touches"
                                     the same, but they keep their order, which the page shows: as with objects, what a side added follows
                                     what it followed there
                "preface", "afterword"
                                     prose, a line to a text: git's own merge of lines
                "updated"            the later of two dates
                anything else        as whoever changed it left it. A list that is not named here is one thing, like a word

              It is a conflict only where both sides changed the same key of the same item, each in its own way, where one took an item off
              that the other changed, and where both added an item of one id and not the same. All the rest is merged; what is in dispute is
              named, and stands between markers like git's own: whoever takes the same side of all of them has the file as that side would
              have it. Which side is called ours changes nothing but the markers.

What no merge can know: a name one side added for a test that the other side renamed or deleted. It ends up listed, and `make parity` fails
with "test … not found". That is wanted: the list is wrong then, and says so. Nor that two keys of a case belong together: one side says that
the stand-ins play it no more and empties its knobs, the other adds a knob, and the case says "no" and has one. And a patch that `git am`
can apply as it is never comes here: a case it adds stands where its context was, which need not be where the alphabet puts it. `--check`
says so, and `--tidy` mends it.

A file that is not JSON, that has a key twice in one object, or an object in a list without an id of its own, has no meaning to merge by:
`--check` refuses it; in a merge that is said, the three files are left to git's merge of lines, and whatever comes of that is a conflict
until the file has a meaning again. So they are if this script cannot be run, or does not run to its end. In collab/parity.json an empty set says
what no set says, and is left out.

The pages that are made from such files (docs/FEATURES.md, docs/REALITY.md) cannot be merged at all: each is right only for the tree it was made
from. After `make hooks` git leaves them as they are on our side where both sides changed them. They are out of date then, which `make gate`
mends and CI's checks say. That holds for `git stash pop` and `git checkout -m` too: a page made again and not committed is not kept. A
commit that holds nothing but such a page comes to nothing: a rebase drops it, and `git cherry-pick` stops to ask (`--skip`).

  scripts/mergeable.py --tidy                           rewrite the file in the shape
  scripts/mergeable.py --check                          change nothing; exit code 1 if it is not in the shape (`make lint`)
  scripts/mergeable.py --merge BASE OURS THEIRS PATH    as `git merge-file` has it: the result goes into OURS, exit code 1 if there is a conflict.
                                                        PATH says which file the three are versions of: collab/parity.json, say
  scripts/mergeable.py --install                        have git do all this by itself in this clone and its worktrees (`make hooks`)
  scripts/mergeable.py --self-test                      situations and what must come of them (`make lint`)

On a branch from before this script, whose `make hooks` knows nothing of it:

  git fetch origin swarm/trunk && git show origin/swarm/trunk:scripts/mergeable.py > /tmp/mergeable.py && python3 /tmp/mergeable.py --install

A conflict that is there already, from before that: `git checkout -m -- collab/parity.json` merges the file once more, this time by
meaning; then `scripts/mergeable.py --check && git add collab/parity.json`.
"""

import argparse
import collections
import difflib
import json
import os
import re
import subprocess
import sys
import tempfile
import time

# Raised whenever a merge would come out otherwise, or is called otherwise: the copy a clone keeps is never replaced by an older one.
VERSION = 4
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
# keys: the order of an object's keys; the star stands for every key that is not there, by the alphabet; the long lists come last.
# sets: lists of names that are written sorted, and not at all when empty. in_order: sets that keep their order, and are written when empty.
# prose: lists of lines. later: dates. Each by where it is, a star for any object of a list: a key of that name elsewhere is a key like any other.
# by_id: whether objects with an id are written in the order of their ids.
Shape = collections.namedtuple("Shape", "indent keys sets in_order prose later by_id")
SHAPES = {
    "collab/parity.json": Shape(2, "updated about features id area title trellis arbor status kind spec priority branch * tests e2e".split(),
                                {"features.*.tests", "features.*.e2e"}, set(), set(), {"updated"}, False),
    "collab/reality.json": Shape(1, ("preface entries afterword id kind layer expected happened found modelled knobs guards copes hurt touches sources "
                                     "backlog certainty *").split(), set(), {f"entries.*.{key}" for key in ("knobs", "guards", "sources", "backlog", "touches")},
                                 {"preface", "afterword"}, set(), True),
}
GENERATED = ["docs/FEATURES.md", "docs/REALITY.md"]
ATTRIBUTES = [f"{path} merge=by-meaning" for path in SHAPES] + [f"{path} merge=keep-ours" for path in GENERATED]
# Where the copy lies is asked when git merges, so a clone may be moved. To git 0 is merged and 1 a conflict, and in both cases it takes what is in
# the file. But an empty script ends with 0 too, and Python with 1 whenever it falls over or cannot even read the script, and then our side is
# in the file, untouched: theirs would be lost, in silence or at the next `git add`. So the script answers git with two numbers that nothing
# else ends with, and whatever else comes back means that it has not done its work: then git merges the lines, as it would without all this.
MERGED, IN_DISPUTE = 10, 11
DRIVER = (f'python3 "$(git rev-parse --git-common-dir)/arbor-mergeable/mergeable.py" --driver %O %A %B %P; code=$?; [ $code -eq {MERGED} ] && exit 0; '
          f"[ $code -eq {IN_DISPUTE} ] && exit 1; git merge-file -L ours -L base -L theirs %A %O %B")
KEEP_OURS = 'echo %P "is made from other files: it stays as it is on our side, make it again" >&2'
PLAIN_MERGE = ["git", "merge-file", "-L", "ours", "-L", "base", "-L", "theirs"]
BASE, OURS, THEIRS = 0, 1, 2


class Missing:
    """What a side has where it has no such key or item. (None is JSON's null, which is something.)"""

    def __repr__(self):
        return "nothing"


MISSING = Missing()


class Conflict:
    """Stands in the result where both sides changed one thing, each in its own way."""

    def __init__(self, where, *sides):
        self.where, self.sides, self.hint = where, sides, ""

    def __str__(self):
        texts = [repr(side) if side is MISSING else json.dumps(side, ensure_ascii=False) for side in self.sides]
        # Long texts are shown from where they part.
        start = max(len(os.path.commonprefix([text for text, side in zip(texts, self.sides) if side is not MISSING])) - 20, 0)
        short = [text if len(text) <= 70 else "…" * (start > 0) + text[start:start + 70] + "…" * (start + 70 < len(text)) for text in texts]
        both_new = self.sides[BASE] is MISSING and all(isinstance(side, dict) for side in self.sides[1:])
        return (f"{', '.join(self.where) or 'the whole file'}: ours has {short[OURS]}, theirs has {short[THEIRS]}, it was {short[BASE]}"
                + (" (two things under one id: one of them needs another)" if both_new else self.hint))


def no_key_twice(pairs):
    keys = [key for key, _ in pairs]
    twice = sorted({key for key in keys if keys.count(key) > 1})
    if twice:
        # Python would keep the last and say nothing: half of an item's tests, say, after a merge of lines went wrong.
        raise ValueError(f"an object has the key {', '.join(twice)} twice")
    return dict(pairs)


def text_in(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def by_id(items):
    """{id: object} of a list of objects, each of which needs an id of its own to be told from the others by."""
    ids = [item.get("id") for item in items]
    if not all(isinstance(name, str) for name in ids):
        raise ValueError("an object in a list has no id, or one that is no text")
    if len(set(ids)) != len(ids):
        raise ValueError(f"{', '.join(sorted({name for name in ids if ids.count(name) > 1}))} is listed twice")
    return dict(zip(ids, items))


def parsed(text):
    """What a text says, or MISSING if it is empty, which is what git hands over where there is no common ancestor."""
    def looked_through(value):
        for each in value.values() if isinstance(value, dict) else value if isinstance(value, list) else []:
            looked_through(each)
        if are_items(value):
            by_id(value)
        return value
    return looked_through(json.loads(text, object_pairs_hook=no_key_twice)) if text.strip() else MISSING


def write(path, text):
    """All of it or none: whoever reads the file meanwhile, or finds it after this was stopped halfway, has the old one or the new."""
    data = text.encode("utf-8")
    with open(path + ".new", "wb") as handle:
        handle.write(data)
    os.replace(path + ".new", path)


def are_names(*lists):
    return all(isinstance(each, list) and all(isinstance(name, str) for name in each) for each in lists)


def are_items(*lists):
    return all(isinstance(each, list) and all(isinstance(item, dict) for item in each) for each in lists) and any(lists)


def below(path, key):
    return f"{path}.{key}" if path else key


def tidied(value, shape, path=""):
    """The same in the one way there is to write it. `path` says where in the file it is: features.*.tests"""
    if isinstance(value, dict):
        inside = {name: tidied(value[name], shape, below(path, name))
                  for name in sorted(value, key=lambda name: (shape.keys.index(name if name in shape.keys else "*"), name))}
        return {name: item for name, item in inside.items() if item != [] or below(path, name) not in shape.sets}
    if isinstance(value, list) and are_names(value) and path in shape.sets | shape.in_order:
        return sorted(set(value)) if path in shape.sets else list(dict.fromkeys(value))
    if isinstance(value, list):
        inside = [tidied(item, shape, below(path, "*")) for item in value]
        return sorted(inside, key=lambda item: str(item["id"])) if shape.by_id and are_items(value) else inside
    return value


def text_of(value, shape):
    # (1e400 can be read, as infinity, and infinity cannot be written in JSON.)
    return "" if value is MISSING else json.dumps(tidied(value, shape), indent=shape.indent, ensure_ascii=False, allow_nan=False) + "\n"


def a_line_each(value, like):
    """The shape collab/parity.json had, an item to a line, with the empty lines of the text `like`. Until the file has been rewritten on the
    trunk, two versions in that shape are merged into that shape: it is for one commit to change it, at a time somebody has chosen, and not
    for whichever merge comes first. After that nothing comes this way, and this can go."""
    if value is MISSING:
        return ""
    lines, after_a_gap = like.split("\n"), set()
    for index, line in enumerate(lines):
        if index and not lines[index - 1].strip() and line.strip().startswith('{"id"'):
            after_a_gap.add(json.loads(line.strip().rstrip(","))["id"])
    inside = []
    for key, each in value.items():
        if key == "features":
            items = ["\n" * (item["id"] in after_a_gap) + "    " + json.dumps(item, ensure_ascii=False) for item in each]
            inside.append('  "features": [\n' + ",\n".join(items) + "\n  ]")
        else:
            inside.append(f"  {json.dumps(key)}: {json.dumps(each, ensure_ascii=False)}")
    return "{\n" + ",\n".join(inside) + "\n}\n"


def in_order(was, ours, theirs):
    """The ids of both sides in one order, the same whichever of the two is called ours."""
    movers = [side for side in (ours, theirs) if [name for name in side if name in was] != [name for name in was if name in side]]
    # Where both moved something there is no telling who is right, and the order is only that of a page: the first by the alphabet.
    order = [name for name in (min(movers) if movers else was) if name in was]
    for index, name in enumerate(was):
        if name not in order:
            # Taken off by the side that moved: should it be in dispute, it stands after what it followed.
            before = next((earlier for earlier in reversed(was[:index]) if earlier in order), None)
            order.insert(0 if before is None else order.index(before) + 1, name)
    added = []
    for side in (ours, theirs):
        added.append({})
        after = None
        for name in side:
            if name in was:
                after = name
            else:
                added[-1].setdefault(after, []).append(name)
    result = []
    for name in [None] + order:
        result += [name] * (name is not None)
        # What each side added at one place stays together.
        for run in sorted(side[name] for side in added if name in side):
            result += [new for new in run if new not in result]
    return result


def words_of(item):
    return set(re.findall(r"\w+", json.dumps(dict(item, id=""), ensure_ascii=False)))


def most_like(item, others):
    """The one of `others`, each with its words, that is much like `item` but for its id, if there is one. By the words they share, which
    is rough and quick: a comparison letter by letter of every case with every other took minutes."""
    words, best, found = words_of(item), 0.6, None
    for each, its in others:
        if len(words & its) > best * len(words | its):
            best, found = len(words & its) / len(words | its), each
    return found


def merged_lines(base, ours, theirs, favouring):
    """What git's merge of lines makes of three lists of texts, with whatever it finds in dispute as one side has it."""
    with tempfile.TemporaryDirectory() as folder:
        paths = [os.path.join(folder, name) for name in ("ours", "base", "theirs")]
        for path, lines in zip(paths, (ours, base, theirs)):
            write(path, "".join(json.dumps(line) + "\n" for line in lines))
        done = subprocess.run(PLAIN_MERGE + ["-p", favouring] + paths, capture_output=True, text=True, check=True)
    return [json.loads(line) for line in done.stdout.split("\n") if line]


def merged(base, ours, theirs, shape):
    """(what both sides made of `base`, the conflicts). Where they cannot both have their way, a Conflict stands in the result."""
    conflicts = []

    def merge(base, ours, theirs, where, path=""):
        def said(side):
            # As it would be written: a list in another order has not been changed, no set is an empty set, and to Python 1 is true.
            return "" if side is MISSING or side == [] and path in shape.sets else json.dumps(tidied(side, shape, path), sort_keys=True)
        if said(ours) == said(theirs) or said(theirs) == said(base):
            return ours
        if said(ours) == said(base):
            return theirs
        there = [side for side in (base, ours, theirs) if side is not MISSING]
        if path in shape.sets | shape.in_order and are_names(*there):
            was, mine, yours = ([] if side is MISSING else list(dict.fromkeys(side)) for side in (base, ours, theirs))
            names = [name for name in in_order(was, mine, yours) if name in mine and name in yours or name not in was]
            # A list that need not be there is not there once nothing is left in it and one side has done without.
            return names if names or MISSING not in (ours, theirs) else MISSING
        if path in shape.prose and len(there) == 3 and are_names(*there):
            # What is left in dispute is a few lines, and not all that either side changed.
            ours, theirs = merged_lines(base, ours, theirs, "--ours"), merged_lines(base, ours, theirs, "--theirs")
            if ours == theirs:
                return ours
        if path in shape.later and all(isinstance(side, str) and re.fullmatch(r"\d{4}-\d\d-\d\d", side) for side in (ours, theirs)):
            return max(ours, theirs)
        if len(there) == 3 and are_items(*there):
            was, mine, yours = by_id(base), by_id(ours), by_id(theirs)
            items = {name: merge(was.get(name, MISSING), mine.get(name, MISSING), yours.get(name, MISSING), where + [name], below(path, "*"))
                     for name in in_order(list(was), list(mine), list(yours))}
            # To a merge, an item that one side gave another id is an item taken off and another added.
            new = [[(item, words_of(item)) for name, item in side.items() if name not in was and name not in other] for side, other in ((mine, yours), (yours, mine))]
            for gone in (item for item in items.values() if isinstance(item, Conflict) and MISSING in item.sides[1:]):
                like = most_like(gone.sides[BASE], new[gone.sides[OURS] is not MISSING])
                if like:
                    gone.hint = f" (renamed? The side that has it no more has added {like['id']}, which is much like it)"
            for name in (name for name in was if name not in mine and name not in yours):
                # Taken off by both, which is no dispute: but if each has added its like under an id of its own, there would be two of it.
                one, other = most_like(was[name], new[0]), most_like(was[name], new[1])
                if one and other and not isinstance(items[one["id"]], Conflict) and items[other["id"]] is not MISSING:
                    conflicts.append(Conflict(where + [" or ".join(sorted([one["id"], other["id"]]))], was[name], one, other))
                    conflicts[-1].hint = f" (both have renamed {name}?)"
                    items[one["id"]], items[other["id"]] = conflicts[-1], MISSING
            return [item for item in items.values() if item is not MISSING]
        # Key by key only if it was there before: of two new items that share an id, key by key would make one.
        if len(there) == 3 and all(isinstance(side, dict) for side in there):
            inside = {name: merge(base.get(name, MISSING), ours.get(name, MISSING), theirs.get(name, MISSING), where + [name], below(path, name))
                      for name in list(ours) + [name for name in theirs if name not in ours]}
            return {name: value for name, value in inside.items() if value is not MISSING}
        conflicts.append(Conflict(where, base, ours, theirs))
        return conflicts[-1]

    return merge(base, ours, theirs, []), conflicts


def as_seen_by(side, value):
    """The result with every conflict settled in favour of one side."""
    if isinstance(value, Conflict):
        return value.sides[side]
    if isinstance(value, dict):
        inside = {key: as_seen_by(side, item) for key, item in value.items()}
        return {key: item for key, item in inside.items() if item is not MISSING}
    if isinstance(value, list):
        return [item for item in (as_seen_by(side, each) for each in value) if item is not MISSING]
    return value


def with_markers(ours, theirs):
    """One text of two, with markers round whatever differs. Not by a merge of lines against the base, which takes the brackets of one item
    for those of its neighbour and puts together what is in dispute: this way each side can be had back whole."""
    # (Python's splitlines() knows a dozen ends of a line, git and editors one.)
    ours, theirs, blocks = re.findall(r"[^\n]*\n|[^\n]+", ours), re.findall(r"[^\n]*\n|[^\n]+", theirs), []
    for what, start, end, from_, to in difflib.SequenceMatcher(None, ours, theirs, autojunk=False).get_opcodes():
        if what != "equal" and len(blocks) > 1 and blocks[-1][0] and len(blocks[-1][1]) <= 3:
            # A bracket or two that both have between two differences: one pair of markers reads better than two.
            same = blocks.pop()[1]
            blocks[-1] = (False, blocks[-1][1] + same + ours[start:end], blocks[-1][2] + same + theirs[from_:to])
        else:
            blocks.append((what == "equal", ours[start:end], theirs[from_:to]))
    return "".join("".join(mine if same else ["<<<<<<< ours\n", *mine, "=======\n", *yours, ">>>>>>> theirs\n"]) for same, mine, yours in blocks)


def merge_files(base, ours, theirs, name):
    """What git asks of a merge driver: the result goes into the file `ours`, and the exit code is 0 if nothing is in dispute."""
    try:
        if name not in SHAPES:
            raise ValueError(f"nobody has said what {name} means")
        shape = SHAPES[name]
        texts = [text_in(path) for path in (base, ours, theirs)]
        sides = [parsed(text) for text in texts]
        result, conflicts = merged(*sides, shape)
        # It is for one commit to change a file's shape, at a time somebody has chosen, and not for whichever merge comes first.
        a_line = all("\n    {\"id\"" in texts[side] for side in (OURS, THEIRS))
        # In order is in order, whatever else a side may want tidying: else one blemish on a sorted trunk would bring the old order back.
        loose = shape._replace(by_id=False)
        if not any(text_of(sides[side], shape) == text_of(sides[side], loose) for side in (OURS, THEIRS)):
            shape = loose
        mine, yours = (a_line_each(seen, texts[OURS]) if a_line else text_of(seen, shape) for seen in (as_seen_by(OURS, result), as_seen_by(THEIRS, result)))
        write(ours, with_markers(mine, yours))
    except Exception as error:  # Whatever it is: a driver that falls over leaves our side in the file and not a marker, and theirs is lost.
        print(f"mergeable.py cannot merge {name} by what it means, and leaves it to git's merge of lines: {error or type(error).__name__}", file=sys.stderr)
        code = subprocess.run(PLAIN_MERGE + [ours, base, theirs], check=False).returncode
        try:
            return 1 if code or name in SHAPES and parsed(text_in(ours)) is MISSING else 0
        except Exception as still:
            print(f"which has merged them into something that has no meaning either: {still or type(still).__name__}", file=sys.stderr)
            return 1
    for conflict in conflicts:
        print(f"CONFLICT by meaning in {name}: {conflict}", file=sys.stderr)
    return 1 if conflicts else 0


def git(*arguments):
    """What git says, or None if it will not."""
    done = subprocess.run(["git", *arguments], capture_output=True, text=True, check=False)
    return done.stdout.strip() if done.returncode == 0 else None


def kept_copy():
    """(where this clone keeps its copy of this script, which version that is, its text: 0 and nothing if there is none), or None outside a clone."""
    common = git("rev-parse", "--git-common-dir")
    if common is None:
        return None
    path = os.path.join(os.path.abspath(common), "arbor-mergeable", "mergeable.py")
    try:
        text = text_in(path)
    except (OSError, ValueError):
        return path, 0, ""
    version = re.search(r"^VERSION = (\d+)$", text, re.MULTILINE)
    return path, int(version.group(1)) if version else 0, text


def install():
    """A copy, and the clone's own list of attributes besides the .gitattributes in the tree: a branch from before there was either is the
    very one whose rebase wants mending."""
    kept = kept_copy()
    if kept is None:
        print("mergeable.py --install: this is no clone of a repository")
        return 1
    path, version, text = kept
    if version > VERSION:
        # `make hooks` on an old branch puts no old merge back, nor the way an old merge was called.
        print(f"git goes on merging {', '.join(SHAPES)} with the newer scripts/mergeable.py that this clone has kept")
        return 0
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if text != text_in(__file__):
            write(path, text_in(__file__))
        attributes = os.path.join(os.path.dirname(os.path.dirname(path)), "info", "attributes")
        os.makedirs(os.path.dirname(attributes), exist_ok=True)
        with open(attributes, "a+", encoding="utf-8") as handle:
            handle.seek(0)
            text = handle.read()
            handle.write("\n" * (text != "" and not text.endswith("\n"))
                         + "".join(line + "\n" for line in ATTRIBUTES if line not in text.split("\n")))
    except OSError as error:
        print(f"mergeable.py --install: {error}")
        return 1
    if None in (git("config", "merge.by-meaning.driver", DRIVER), git("config", "merge.keep-ours.driver", KEEP_OURS)):
        print("mergeable.py --install: git would not take its configuration")
        return 1
    for driver in ("by-meaning", "keep-ours"):
        # Earlier versions gave them names. A driver that has a name and, once somebody takes it out, no command stops every merge of the file.
        git("config", "--unset", f"merge.{driver}.name")
    print(f"git now merges {', '.join(SHAPES)} by what it means in this clone, and leaves {' and '.join(GENERATED)} to be made again")
    return 0


def tidy(paths, check):
    wrong = 0
    for path, shape in paths.items():
        name = os.path.relpath(path, ROOT)
        try:
            text = text_in(path)
            wanted = text_of(parsed(text), shape)
        except (OSError, ValueError) as error:
            print(f"{name}: {error}")
            wrong += 1
            continue
        if text == wanted:
            continue
        if check:
            print(f"{name} is not in the shape that merges: run scripts/mergeable.py --tidy, which changes nothing of what it says")
            wrong += 1
        else:
            write(path, wanted)
            print(f"{name}: rewritten; it says what it said")
    return 1 if wrong else 0


def note_on_this_clone():
    """A word to whoever will rebase here, and no failure. Nobody merges in CI."""
    kept = None if os.environ.get("CI") else kept_copy()
    if kept and (kept[1] < VERSION or kept[1] == VERSION and (kept[2] != text_in(__file__) or git("config", "merge.by-meaning.driver") != DRIVER)):
        print(f"note: in this clone git does not yet merge {', '.join(SHAPES)} by what it means, or in an older way: run `make hooks`")


# The self-test.

rows = []
PARITY = "collab/parity.json"


def row(what, got, expected):
    rows.append((what, got, expected))


def item(name, **keys):
    return dict({"id": name, "status": "planned"}, **keys)


def file_of(*items, **keys):
    return dict({"about": "words", "features": list(items)}, **keys)


def shaped(data):
    return text_of(data, SHAPES[PARITY])


def lined(data):
    return a_line_each(data, "")


def merge_texts(base, ours, theirs, name=PARITY):
    """(exit code, what is in OURS afterwards, what was said) of --merge."""
    with tempfile.TemporaryDirectory() as folder:
        paths = [os.path.join(folder, each) for each in ("base", "ours", "theirs")]
        for path, text in zip(paths, (base, ours, theirs)):
            write(path, text)
        saved, sys.stderr = sys.stderr, open(os.path.join(folder, "said"), "w+", encoding="utf-8")
        try:
            code = merge_files(*paths, name)
            sys.stderr.seek(0)
            said = sys.stderr.read()
        finally:
            sys.stderr.close()
            sys.stderr = saved
        with open(paths[1], encoding="utf-8") as handle:
            return code, handle.read(), said


def both_ways(what, base, ours, theirs, expected, name=PARITY):
    """`expected` is the merged file, or where the conflicts are. Who is ours and who theirs depends on who rebases on whom, and must not
    change what comes out, to the letter: else the page made from it would depend on the order of landing."""
    views = []
    for words, mine, yours in ((what, ours, theirs), (what + ", the other way round", theirs, ours)):
        result, conflicts = merged(base, mine, yours, SHAPES[name])
        row(words, [" ".join(conflict.where) for conflict in conflicts] or text_of(result, SHAPES[name]),
            expected if isinstance(expected, list) else json.dumps(expected, indent=SHAPES[name].indent, ensure_ascii=False) + "\n" if name != PARITY else shaped(expected))
        views.append([text_of(as_seen_by(side, result), SHAPES[name]) for side in (OURS, THEIRS)])
    if isinstance(expected, list):
        row(what + ": and what each side would have is the same whichever is called ours", views[0], views[1][::-1])


def taking(side, text):
    """The text of whoever takes one side of every pair of markers."""
    kept, now = [], None
    for line in re.findall(r"[^\n]*\n|[^\n]+", text):
        if line in ("<<<<<<< ours\n", "=======\n", ">>>>>>> theirs\n"):
            now = {"<": OURS, "=": THEIRS, ">": None}[line[0]]
        elif now in (None, side):
            kept.append(line)
    return "".join(kept)


def check_sets():
    base = file_of(item("T01", tests=["b", "d"]), item("T02", tests=["x"]))
    both_ways("both add a test to one item: it has both, sorted",
              base, file_of(item("T01", tests=["b", "d", "a"]), item("T02", tests=["x"])),
              file_of(item("T01", tests=["b", "d", "c"]), item("T02", tests=["x"])),
              file_of(item("T01", tests=["a", "b", "c", "d"]), item("T02", tests=["x"])))
    both_ways("they add to neighbouring items",
              base, file_of(item("T01", tests=["b", "d", "a"]), item("T02", tests=["x"])),
              file_of(item("T01", tests=["b", "d"]), item("T02", tests=["x", "y"])),
              file_of(item("T01", tests=["a", "b", "d"]), item("T02", tests=["x", "y"])))
    both_ways("both add the same test: it is listed once",
              base, file_of(item("T01", tests=["b", "d", "a"]), item("T02", tests=["x"])),
              file_of(item("T01", tests=["a", "b", "d", "c"]), item("T02", tests=["x"])),
              file_of(item("T01", tests=["a", "b", "c", "d"]), item("T02", tests=["x"])))
    both_ways("one takes a test off, the other adds one: what was taken off does not come back",
              base, file_of(item("T01", tests=["d"]), item("T02", tests=["x"])),
              file_of(item("T01", tests=["b", "d", "e"]), item("T02", tests=["x"])),
              file_of(item("T01", tests=["d", "e"]), item("T02", tests=["x"])))
    both_ways("both take the same test off",
              base, file_of(item("T01", tests=["d"]), item("T02", tests=["x"])),
              file_of(item("T01", tests=["d", "e"]), item("T02", tests=["x"])),
              file_of(item("T01", tests=["d", "e"]), item("T02", tests=["x"])))
    both_ways("one renames a test, the other adds one",
              base, file_of(item("T01", tests=["b2", "d"]), item("T02", tests=["x"])),
              file_of(item("T01", tests=["b", "c", "d"]), item("T02", tests=["x"])),
              file_of(item("T01", tests=["b2", "c", "d"]), item("T02", tests=["x"])))
    both_ways("one moves a test to another item, the other deletes it: it stays listed where it was moved to, for `make parity` to miss",
              base, file_of(item("T01", tests=["d"]), item("T02", tests=["b", "x"])),
              file_of(item("T01", tests=["d"]), item("T02", tests=["x"])),
              file_of(item("T01", tests=["d"]), item("T02", tests=["b", "x"])))
    both_ways("an item without a list gets one from both",
              file_of(item("T01")), file_of(item("T01", e2e=["dock"])), file_of(item("T01", e2e=["zoom"], tests=["a"])),
              file_of(item("T01", tests=["a"], e2e=["dock", "zoom"])))
    both_ways("one takes the list off, the other adds to it: what it added is all that is left",
              base, file_of(item("T01"), item("T02", tests=["x"])), file_of(item("T01", tests=["b", "d", "e"]), item("T02", tests=["x"])),
              file_of(item("T01", tests=["e"]), item("T02", tests=["x"])))
    both_ways("between them they take off all there was: no list is left",
              base, file_of(item("T01", tests=["b"]), item("T02", tests=["x"])), file_of(item("T01", tests=["d"]), item("T02", tests=["x"])),
              file_of(item("T01"), item("T02", tests=["x"])))
    both_ways("one writes a list in another order and the other adds to it: nothing has been changed but by the other",
              base, file_of(item("T01", tests=["d", "b"]), item("T02", tests=["x"])), file_of(item("T01", tests=["b", "d", "c"]), item("T02", tests=["x"])),
              file_of(item("T01", tests=["b", "c", "d"]), item("T02", tests=["x"])))
    prose = file_of(item("T01", words=["b", "", "a", ""]))
    both_ways("a list nobody has called a set is one thing: changed by one side, it is as that side left it, in its order",
              prose, file_of(item("T01", words=["b", "", "c", "", "a", ""])), file_of(item("T01", words=["b", "", "a", ""], tests=["t"])),
              file_of(item("T01", words=["b", "", "c", "", "a", ""], tests=["t"])))
    both_ways("changed by both: a conflict, and no putting together",
              prose, file_of(item("T01", words=["b", "", "a", "", "c"])), file_of(item("T01", words=["d", "b", "", "a", ""])), ["features T01 words"])


def check_keys():
    base = file_of(item("T01", title="one", tests=["b"]), item("T02"))
    both_ways("one changes a key", base, file_of(item("T01", title="one", tests=["b"], status="shipped"), item("T02")), base,
              file_of(item("T01", title="one", tests=["b"], status="shipped"), item("T02")))
    both_ways("they change different keys of one item",
              base, file_of(item("T01", title="one", tests=["b"], status="shipped"), item("T02")),
              file_of(item("T01", title="uno", tests=["b"]), item("T02")),
              file_of(item("T01", title="uno", tests=["b"], status="shipped"), item("T02")))
    both_ways("both change a key, and to the same",
              base, file_of(item("T01", title="one", tests=["b"], status="shipped"), item("T02")),
              file_of(item("T01", title="one", tests=["b", "c"], status="shipped"), item("T02")),
              file_of(item("T01", title="one", tests=["b", "c"], status="shipped"), item("T02")))
    both_ways("both change a key, each in its own way: a conflict, in that key of that item",
              base, file_of(item("T01", title="one", tests=["b"], status="shipped"), item("T02")),
              file_of(item("T01", title="one", tests=["b"], status="partial"), item("T02")), ["features T01 status"])
    both_ways("one takes a key off, the other changes it: a conflict",
              base, file_of(item("T01", tests=["b"]), item("T02")), file_of(item("T01", title="uno", tests=["b"]), item("T02")),
              ["features T01 title"])
    both_ways("one takes a key off", base, file_of(item("T01", tests=["b"]), item("T02")), base, file_of(item("T01", tests=["b"]), item("T02")))
    both_ways("each adds a key of its own",
              base, file_of(item("T01", title="one", tests=["b"], branch="x"), item("T02")),
              file_of(item("T01", title="one", tests=["b"], spec="F01"), item("T02")),
              file_of(item("T01", title="one", tests=["b"], branch="x", spec="F01"), item("T02")))
    both_ways("both add one key, and not the same: a conflict",
              base, file_of(item("T01", title="one", tests=["b"], branch="x"), item("T02")),
              file_of(item("T01", title="one", tests=["b"], branch="y"), item("T02")), ["features T01 branch"])
    both_ways("null is something: null against a word is a conflict",
              base, file_of(item("T01", title=None, tests=["b"]), item("T02")), file_of(item("T01", title="uno", tests=["b"]), item("T02")),
              ["features T01 title"])
    both_ways("and null against a longer list",
              base, file_of(item("T01", title="one", tests=None), item("T02")), file_of(item("T01", title="one", tests=["b", "c"]), item("T02")),
              ["features T01 tests"])
    both_ways("a list on one side and a word on the other: a conflict, not a guess",
              base, file_of(item("T01", title="one", tests="b c"), item("T02")), file_of(item("T01", title="one", tests=["b", "c"]), item("T02")),
              ["features T01 tests"])
    both_ways("to Python 1 is true and 1.0: not here. One against the other is a change, and against a third a conflict",
              file_of(item("T01", priority=1)), file_of(item("T01", priority=True)), file_of(item("T01", priority=2)), ["features T01 priority"])
    both_ways("the same of a key both add", base, file_of(item("T01", title="one", tests=["b"], priority=1), item("T02")),
              file_of(item("T01", title="one", tests=["b"], priority=True), item("T02")), ["features T01 priority"])
    both_ways("an object below an item: key by key as well",
              file_of(item("T01", more={"a": 1, "b": 2})), file_of(item("T01", more={"a": 3, "b": 2})), file_of(item("T01", more={"a": 1, "b": 4, "c": 5})),
              file_of(item("T01", more={"a": 3, "b": 4, "c": 5})))
    both_ways("and a conflict in it", file_of(item("T01", more={"a": 1})), file_of(item("T01", more={"a": 2})), file_of(item("T01", more={"a": 3})), ["features T01 more a"])
    both_ways("keys of the file itself", base, dict(base, note="x"), dict(base, about="other words"), dict(base, note="x", about="other words"))
    both_ways("the same, in dispute", base, dict(base, about="these words"), dict(base, about="other words"), ["about"])
    both_ways("the day it was last changed, which every side sets to its own: the later",
              dict(base, updated="2026-10-14"), dict(base, updated="2026-10-15"), dict(base, updated="2026-11-02"), dict(base, updated="2026-11-02"))


    both_ways("a day that is not written as days are: a conflict", dict(base, updated="2026-10-14"), dict(base, updated="2026-10-9"), dict(base, updated="2026-10-15"), ["updated"])
    both_ways("the rules hold where they are meant, and a key of the same name elsewhere is a key like any other",
              file_of(item("T01", updated="a", more={"tests": ["x", "y"]})), file_of(item("T01", updated="2026-10-15", more={"tests": ["x", "y", "a"]})),
              file_of(item("T01", updated="2026-10-16", more={"tests": ["x", "y", "b"]})), ["features T01 updated", "features T01 more tests"])
    both_ways("a day against no day: a conflict", dict(base, updated="2026-10-14"), dict(base, updated="2026-10-15"), dict(base, updated=None), ["updated"])
    long = "Neighbours take the space, also for hidden apps, and have their exact sizes again "
    row("a conflict in long words is shown from where they part", str(Conflict(["T07", "arbor"], long + "at once", long + "when it is back", long + "in whatever order")),
        'T07, arbor: ours has …r exact sizes again when it is back", theirs has …r exact sizes again in whatever order", it was …r exact sizes again at once"')


def check_items():
    base = file_of(item("T01"), item("T02"), item("T03"))

    def order(what, ours, theirs, expected):
        both_ways(what, base, file_of(*map(item, ours.split())), file_of(*map(item, theirs.split())), file_of(*map(item, expected.split())))
    order("each adds an item, beside its kin: each follows what it followed", "T01 A1 T02 T03", "T01 T02 A2 T03", "T01 A1 T02 A2 T03")
    order("both add at the same place: what each added stays together", "T01 A2 A9 T02 T03", "T01 A3 A1 T02 T03", "T01 A2 A9 A3 A1 T02 T03")
    order("both add at the end", "T01 T02 T03 A2", "T01 T02 T03 A1", "T01 T02 T03 A1 A2")
    order("one adds at the very beginning", "T01 T02 T03 A1", "A2 T01 T02 T03", "A2 T01 T02 T03 A1")
    order("one adds after an item that the other took off: after the one before it", "T01 T03", "T01 T02 A2 T03", "T01 A2 T03")
    order("both add the same item, at different places: it is there once, at the first", "T01 A1 T02 T03", "T01 T02 A1 A2 T03", "T01 A1 T02 A2 T03")
    order("one takes an item off that the other left alone", "T01 T03", "T01 T02 T03", "T01 T03")
    order("one moves an item, the other adds one: the order of the one, and what the other added follows what it followed",
          "T03 T01 T02", "T01 A1 T02 T03", "T03 T01 A1 T02")
    order("both move items: the order of one of them, and the same one both ways", "T02 T01 T03", "T01 T03 T02", "T01 T03 T02")
    both_ways("one moves an item, the other adds a test to it: it is where it was moved to, with the test",
              base, file_of(item("T02"), item("T01"), item("T03")), file_of(item("T01"), item("T02", tests=["a"]), item("T03")),
              file_of(item("T02", tests=["a"]), item("T01"), item("T03")))
    both_ways("each adds an item to a list that had none", file_of(), file_of(item("A2")), file_of(item("A1")), file_of(item("A1"), item("A2")))
    both_ways("both add the same item, word for word: it is there once",
              base, file_of(*base["features"], item("A1", tests=["a"])), file_of(*base["features"], item("A1", tests=["a"])),
              file_of(*base["features"], item("A1", tests=["a"])))
    both_ways("two features claim one new id: a conflict in the item, and no blend of the two",
              base, file_of(*base["features"], item("A1", title="tabs", tests=["a"])), file_of(*base["features"], item("A1", title="presets", tests=["b"])),
              ["features A1"])
    both_ways("the same though only their tests differ",
              base, file_of(*base["features"], item("A1", tests=["a"])), file_of(*base["features"], item("A1", tests=["b"])), ["features A1"])
    both_ways("one takes an item off, the other added a test to it: a conflict",
              base, file_of(item("T01"), item("T03")), file_of(item("T01"), item("T02", tests=["a"]), item("T03")), ["features T02"])
    both_ways("one moves items and takes one off that the other changed: a conflict",
              base, file_of(item("T03"), item("T01")), file_of(item("T01"), item("T02", tests=["a"]), item("T03")), ["features T02"])
    result = merged(file_of(*base["features"], item("T04")), file_of(item("T04"), item("T01"), item("T03")),
                    file_of(item("T01"), item("T02", tests=["a"]), item("T03"), item("T04")), SHAPES[PARITY])[0]
    row("where the item in dispute stands after what it followed", [each["id"] for each in as_seen_by(THEIRS, result)["features"]], ["T04", "T01", "T02", "T03"])
    both_ways("both add the same item, the names of its tests in another order: it is there once",
              base, file_of(*base["features"], item("A1", tests=["a", "b"])), file_of(*base["features"], item("A1", tests=["b", "a"])),
              file_of(*base["features"], item("A1", tests=["a", "b"])))
    both_ways("one takes an item off, the other gives it an empty list, which says nothing: it is off",
              base, file_of(item("T01"), item("T03")), file_of(item("T01"), item("T02", e2e=[]), item("T03")), file_of(item("T01"), item("T03")))


def check_shape():
    untidy = {"features": [{"tests": ["b", "a", "b"], "zeta": ["z", "", "y", ""], "status": "shipped", "alpha": "▸ “é”", "e2e": [], "none": [], "id": "T01"}],
              "about": "w"}
    tidy_text = ('{\n  "about": "w",\n  "features": [\n    {\n      "id": "T01",\n      "status": "shipped",\n      "alpha": "▸ “é”",\n      "none": [],\n'
                 '      "zeta": [\n        "z",\n        "",\n        "y",\n        ""\n      ],\n      "tests": [\n        "a",\n        "b"\n      ]\n    }\n  ]\n}\n')
    row("the shape: a key to a line in one order, names sorted and once, no empty set; keys nobody knows, their lists and all letters as they are",
        shaped(untidy), tidy_text)
    row("tidied twice is tidied once", shaped(json.loads(tidy_text)), tidy_text)
    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, "x.json")

        def said_of(text, check):
            write(path, text)
            code = tidy({path: SHAPES[PARITY]}, check)
            with open(path, encoding="utf-8") as handle:
                return code, handle.read() == text
        quiet, sys.stdout = sys.stdout, open(os.devnull, "w", encoding="utf-8")
        try:
            row("--check: the shape passes", said_of(tidy_text, True), (0, True))
            row("--check: an item to a line does not, and is left as it is", said_of(json.dumps(untidy), True), (1, True))
            row("--check: nor one name out of order", said_of(tidy_text.replace('"a"', '"c"'), True), (1, True))
            row("--check: nor a missing last line end", said_of(tidy_text.rstrip("\n"), True), (1, True))
            row("--tidy rewrites", said_of(json.dumps(untidy), False), (0, False))
            row("--tidy leaves the shape alone", said_of(tidy_text, False), (0, True))
            twice = tidy_text.replace('      "tests": [', '      "tests": [\n        "lost"\n      ],\n      "tests": [')
            row("--check: a key twice in one object is refused", said_of(twice, True), (1, True))
            row("--tidy: and not tidied away, which would lose one of the two", said_of(twice, False), (1, True))
            row("--tidy: markers of a conflict are not JSON", said_of(tidy_text.replace('"a",', '<<<<<<< ours\n"a",'), False), (1, True))
            row("--check: an id listed twice is refused", said_of(shaped(file_of(item("T01"), item("T02"), item("T01"))), True), (1, True))
            row("--check: so is an item without one", said_of(shaped(file_of(item("T01"), {"status": "planned"})), True), (1, True))
            row("--check: and an id that is no text", said_of(shaped(file_of(item("T01"), item(["T02"]))), True), (1, True))
        finally:
            sys.stdout.close()
            sys.stdout = quiet
    for name, shape in SHAPES.items():
        now = parsed(text_in(os.path.join(ROOT, name)))

        def meaning(value, key=None):
            """Worked out apart from tidied()."""
            if isinstance(value, dict):
                return {name: meaning(each, name) for name, each in value.items() if each != [] or name not in shape.sets}
            if isinstance(value, list) and key in ("features", "entries"):
                return {each["id"]: meaning(each) for each in value}
            return sorted(set(value)) if key in shape.sets else value
        row(f"{name}: tidied it says what it says, item for item", meaning(json.loads(text_of(now, shape))) == meaning(now), True)
    now = parsed(text_in(os.path.join(ROOT, PARITY)))["features"]
    row(f"{PARITY}: and in the same order, which is the page's", [each["id"] for each in tidied(now, SHAPES[PARITY])], [each["id"] for each in now])
    with open(os.path.join(ROOT, ".gitattributes"), encoding="utf-8") as handle:
        row(".gitattributes says of the same files what --install tells the clone", [line for line in handle.read().split("\n") if line and line[0] != "#"], ATTRIBUTES)


def check_files():
    base = file_of(item("T01", title="one", tests=["b", "d"]), item("T02", tests=["x"]))
    ours = file_of(item("T01", title="one", tests=["a", "b", "d"]), item("T02", tests=["x"], status="shipped"))
    theirs = file_of(item("T01", title="one", tests=["b", "d", "c"]), item("T02", tests=["x"]), item("A1"))
    both = file_of(item("T01", title="one", tests=["a", "b", "c", "d"]), item("T02", tests=["x"], status="shipped"), item("A1"))
    row("--merge: the result goes into OURS, in the shape, and nothing is said", merge_texts(shaped(base), shaped(ours), shaped(theirs)), (0, shaped(both), ""))
    row("--merge: a pull request from before the shape, on a trunk that has it",
        merge_texts(lined(base), shaped(ours), lined(theirs)), (0, shaped(both), ""))
    gaps = lined(ours).replace('    {"id": "T02"', '\n    {"id": "T02"')
    row("--merge: all three from before the shape: it is not for a merge to change it. What nobody touched is as it was, to the letter",
        merge_texts(lined(base), gaps, lined(theirs)),
        (0, lined(file_of(item("T01", title="one", tests=["a", "b", "d", "c"]), *both["features"][1:])).replace('    {"id": "T02"', '\n    {"id": "T02"'), ""))
    code, text, said = merge_texts(lined(base), lined(ours), lined(file_of(base["features"][0], item("T02", tests=["x"], status="partial"))))
    row("--merge: and a conflict there is git's markers round the item's line", (code, text.count("<<<<<<<"), text.count("\n")), (1, 1, lined(ours).count("\n") + 4))
    row("--merge: the commit that does nothing but reshape, on a trunk that has moved: the trunk, reshaped",
        merge_texts(lined(base), lined(ours), shaped(base)), (0, shaped(ours), ""))

    def with_title(data, title):
        return dict(data, features=[dict(data["features"][0], title=title)] + data["features"][1:])
    code, text, said = merge_texts(lined(base), shaped(with_title(ours, "eins")), lined(with_title(theirs, "uno")))
    row("--merge: a conflict is git's markers round the key in dispute, and all the rest is merged", (code, text), (1, shaped(with_title(both, "eins")).replace(
        '      "title": "eins",\n', '<<<<<<< ours\n      "title": "eins",\n=======\n      "title": "uno",\n>>>>>>> theirs\n')))
    row("--merge: and it is named", said, f'CONFLICT by meaning in {PARITY}: features, T01, title: ours has "eins", theirs has "uno", it was "one"\n')
    code, text, said = merge_texts(shaped(base), shaped(file_of(base["features"][0])), shaped(file_of(base["features"][0], item("T02", tests=["x", "y"]))))
    row("--merge: an item taken off and changed: a conflict, with the item between the markers",
        (code, text.count("<<<<<<<"), '"y"' in text, "ours has nothing" in said), (1, 1, True, True))
    code, text, said = merge_texts(shaped(base), shaped(file_of(*base["features"], item("A1", title="tabs"))), shaped(file_of(*base["features"], item("A1", title="presets"))))
    row("--merge: two things under one new id: a conflict that says so", (code, text.count("<<<<<<<"), "one of them needs another" in said), (1, 1, True))
    code, text, said = merge_texts(" \n", shaped(ours), shaped(theirs))
    row("--merge: no common ancestor: a conflict", (code, "the whole file" in said, taking(OURS, text), taking(THEIRS, text)), (1, True, shaped(ours), shaped(theirs)))
    code, text, said = merge_texts(shaped(base), shaped(with_title(file_of(*ours["features"][:1], item("T02", tests=["x"], status="shipped")), "eins")),
                                   shaped(with_title(file_of(*theirs["features"][:1], item("T02", tests=["x"], status="partial")), "uno")))
    row("--merge: two conflicts in one file: each is named and has its markers", (code, text.count("<<<<<<<"), said.count("CONFLICT by meaning")), (1, 2, 2))
    neighbours = [file_of(item("T06"), item("T09", title="three", tests=["n13"])), file_of(item("T09", tests=["n13"])), file_of(item("T06", tests=["n6"]))]
    code, text, said = merge_texts(*map(shaped, neighbours))
    row("--merge: two items in dispute side by side: whoever takes one side of the markers has what that side would have, whole",
        (code, said.count("CONFLICT"), taking(OURS, text), taking(THEIRS, text)), (1, 2, shaped(neighbours[1]), shaped(neighbours[2])))
    row("--merge: and one pair of markers holds them, brackets and all", text.count("<<<<<<<"), 1)
    words = [file_of(item("T01", words=list(letters))) for letters in ("abcdef", "Xabcdef", "abcdefY")]
    code, text, said = merge_texts(*map(shaped, words))
    row("--merge: a thing of many lines in dispute is not put together line by line",
        (code, taking(OURS, text), taking(THEIRS, text)), (1, shaped(words[1]), shaped(words[2])))
    code, text, said = merge_texts(shaped(base), shaped(file_of(item("T01", tests=["b", "d"]), base["features"][1])), shaped(with_title(base, "uno")))
    row("--merge: a key taken off and changed", (code, taking(OURS, text), taking(THEIRS, text)),
        (1, shaped(file_of(item("T01", tests=["b", "d"]), base["features"][1])), shaped(with_title(base, "uno"))))

    unsorted = file_of(item("T01"), item("T02", title="▸ é", tests=["y", "x"]))
    row("--merge: the commit that reshapes, on a trunk that has taken an item off: sorting its names has not changed it",
        merge_texts(lined(unsorted), lined(file_of(item("T01"))), shaped(unsorted)), (0, shaped(file_of(item("T01"))), ""))
    row("--merge: a pull request from before the shape that takes an item off, on a trunk that has the shape",
        merge_texts(lined(unsorted), shaped(unsorted), lined(file_of(item("T01")))), (0, shaped(file_of(item("T01"))), ""))
    code, text, said = merge_texts(lined(unsorted), lined(file_of(item("T01", tests=["a"]), unsorted["features"][1])), lined(file_of(*unsorted["features"], item("T03"))))
    row("--merge: an item to a line keeps its letters as they are",
        (code, text == lined(file_of(item("T01", tests=["a"]), unsorted["features"][1], item("T03"))), '"title": "▸ é", "tests": ["y", "x"]}' in text), (0, True, True))
    row("--merge: two sides from before the shape: the same whichever is called ours",
        merge_texts(lined(base), lined(ours), lined(theirs))[1], merge_texts(lined(base), lined(theirs), lined(ours))[1])
    row("--merge: the shape does not go backwards: one side in it, or nearly, and the result is in it",
        merge_texts(shaped(base), lined(ours), shaped(theirs).replace('        "b",\n        "c",\n', '        "c",\n        "b",\n')), (0, shaped(both), ""))
    code, text, said = merge_texts(shaped(base), shaped(ours), shaped(theirs).replace('"status": "planned"', '"status": 1e400', 1))
    row("--merge: a number too great to be written again: left to git's merge of lines", (code, "merge of lines" in said, "Infinity" in text), (0, True, False))
    row("--merge: what shape the base is in does not count", merge_texts(shaped(base), lined(ours), lined(theirs))[1].count("\n"), lined(both).count("\n"))
    loose = [json.dumps(each, indent=2) + "\n" for each in (unsorted, file_of(item("T01", tests=["a"]), unsorted["features"][1]), file_of(*unsorted["features"], item("T03")))]
    row("--merge: sides that are in neither shape come out in the shape",
        merge_texts(*loose), (0, shaped(file_of(item("T01", tests=["a"]), unsorted["features"][1], item("T03"))), ""))

    broken = shaped(theirs).replace('"c",', '<<<<<<< ours\n        "c",')
    code, text, said = merge_texts(shaped(base), shaped(ours), broken)
    row("--merge: a side that is not JSON is left to git's merge of lines, and that is said", "merge of lines" in said, True)
    row("--merge: which merges them, and it is a conflict all the same: the file still has no meaning",
        (code, "<<<<<<< ours" in text, '"a",' in text, "no meaning either" in said), (1, True, True, True))
    code, text, said = merge_texts(shaped(base), shaped(ours), shaped(file_of(*theirs["features"], item("T02", tests=["z"]))))
    row("--merge: an id listed twice is not settled in silence", (code, "T02 is listed twice" in said, text.count('"id": "T02"')), (1, True, 2))
    for what, odd in (("an item without an id", {"status": "planned"}), ("an id that is a list", item(["x"])), ("an id that is null", item(None))):
        code, text, said = merge_texts(shaped(base), shaped(ours), shaped(file_of(*theirs["features"], odd)))
        row(f"--merge: {what}: the same", (code, "no id, or one that is no text" in said, '"a",' in text), (1, True, True))
    code, text, said = merge_texts(shaped(base), shaped(ours), shaped(theirs).replace('      "title": "one",\n', '      "title": "one",\n      "title": "two",\n'))
    row("--merge: a key twice in one object: the same", (code, "the key title twice" in said), (1, True))
    code, text, said = merge_texts(shaped(base), shaped(ours), "[" * 100000 + "]" * 100000 + "\n")
    row("--merge: brackets deeper than Python goes: it does not fall over", (code, "merge of lines" in said, "<<<<<<< ours" in text), (1, True, True))
    code, text, said = merge_texts(shaped(base), shaped(ours), shaped(theirs).replace('"one"', '"\\ud800"'))
    row("--merge: half a letter, which can be read and not written: our side is not lost over it", (code, '"a",' in text, "merge of lines" in said), (0, True, True))
    code, text, said = merge_texts(shaped(base), shaped(ours), shaped(theirs), "collab/other.json")
    row("--merge: a file nobody has described: the same", (code, "nobody has said what collab/other.json means" in said, text), (0, True, shaped(both)))
    done = subprocess.run([sys.executable, os.path.abspath(__file__), "--merge", "/nowhere/a", "/nowhere/b", "/nowhere/c", PARITY], capture_output=True, text=True, check=False)
    row("--merge: files that are not there: it fails, and does not fall over", (done.returncode, "Traceback" in done.stderr), (1, False))

    # What the shape is for: whoever merges lines, as GitHub does, manages too.
    def lines(base, ours, theirs):
        with tempfile.TemporaryDirectory() as folder:
            paths = [os.path.join(folder, name) for name in ("ours", "base", "theirs")]
            for path, text in zip(paths, (ours, base, theirs)):
                write(path, text)
            done = subprocess.run(PLAIN_MERGE + ["-p"] + paths, capture_output=True, text=True, check=False)
            return done.returncode, done.stdout
    row("git by itself, an item to a line: two tests for one item are a conflict", lines(lined(base), lined(ours), lined(theirs))[0] > 0, True)
    row("git by itself, in the shape: it comes to what the merge by meaning comes to", lines(shaped(base), shaped(ours), shaped(theirs)), (0, shaped(both)))


def check_ledger():
    """collab/reality.json. What is expected is written out as it must stand in the file, and not tidied first."""
    ledger = "collab/reality.json"

    def case(name, **keys):
        return dict({"id": name, "kind": "timing", "knobs": [], "guards": ["test: a", "e2e: b"]}, **keys)

    def file(*cases, preface=("# Reality", "", "One.", "", "Two.", "")):
        return {"preface": list(preface), "entries": list(cases)}

    def ways(what, base, ours, theirs, expected):
        both_ways("the ledger: " + what, base, ours, theirs, expected, ledger)
    base = file(case("b-case"), case("d-case"))
    row("the ledger's shape: cases by their ids, keys in one order, lists in the order they have, each name once, an empty list written",
        text_of({"entries": [{"guards": ["z", "a", "z"], "knobs": [], "new": 1, "kind": "timing", "id": "b"}, {"id": "a"}], "preface": ["x", "", "x", ""]}, SHAPES[ledger]),
        '{\n "preface": [\n  "x",\n  "",\n  "x",\n  ""\n ],\n "entries": [\n  {\n   "id": "a"\n  },\n  {\n   "id": "b",\n   "kind": "timing",\n   "knobs": [],\n'
        '   "guards": [\n    "z",\n    "a"\n   ],\n   "new": 1\n  }\n ]\n}\n')
    ways("each adds a case: both are there, where the alphabet puts them", base, file(case("b-case"), case("d-case"), case("c-case")),
         file(case("a-case"), case("b-case"), case("d-case")), file(case("a-case"), case("b-case"), case("c-case"), case("d-case")))
    ways("they change different keys of one case", base, file(case("b-case", kind="input"), case("d-case")), file(case("b-case", copes="open"), case("d-case")),
         file(case("b-case", kind="input", copes="open"), case("d-case")))
    ways("both reword one key of one case: a conflict", base, file(case("b-case", kind="input"), case("d-case")), file(case("b-case", kind="looks"), case("d-case")),
         ["entries b-case kind"])
    ways("both add a case of one id, in other words: a conflict", base, file(*base["entries"], case("e-case", kind="input")), file(*base["entries"], case("e-case")),
         ["entries e-case"])
    ways("each adds a guard: both are there, each after what it followed, and the rest in the order it had",
         base, file(case("b-case", guards=["test: a", "test: n", "e2e: b"]), case("d-case")), file(case("b-case", guards=["test: a", "e2e: b", "test: c"]), case("d-case")),
         file(case("b-case", guards=["test: a", "test: n", "e2e: b", "test: c"]), case("d-case")))
    ways("both add one at the end", base, file(case("b-case", guards=["test: a", "e2e: b", "test: z"]), case("d-case")),
         file(case("b-case", guards=["test: a", "e2e: b", "test: c"]), case("d-case")), file(case("b-case", guards=["test: a", "e2e: b", "test: c", "test: z"]), case("d-case")))
    ways("one takes a guard off, the other adds one: what was taken off does not come back", base, file(case("b-case", guards=["e2e: b"]), case("d-case")),
         file(case("b-case", guards=["test: a", "e2e: b", "test: c"]), case("d-case")), file(case("b-case", guards=["e2e: b", "test: c"]), case("d-case")))
    ways("between them they take off all: the list stays, empty, as the ledger's own check wants it", base, file(case("b-case", guards=["e2e: b"]), case("d-case")),
         file(case("b-case", guards=["test: a"]), case("d-case")), file(case("b-case", guards=[]), case("d-case")))
    ways("one puts a list in another order, the other adds to it", base, file(case("b-case", guards=["e2e: b", "test: a"]), case("d-case")),
         file(case("b-case", guards=["test: a", "test: c", "e2e: b"]), case("d-case")), file(case("b-case", guards=["e2e: b", "test: a", "test: c"]), case("d-case")))
    ways("prose: they change different lines; empty lines, of which there are many, stay where they are",
         base, file(*base["entries"], preface=("# Reality", "", "One, reworded.", "", "Two.", "")), file(*base["entries"], preface=("# Reality", "", "One.", "", "Two.", "", "Three.", "")),
         file(*base["entries"], preface=("# Reality", "", "One, reworded.", "", "Two.", "", "Three.", "")))
    ways("prose: both change one line: a conflict", base, file(*base["entries"], preface=("# Reality", "", "Uno.", "", "Two.", "")),
         file(*base["entries"], preface=("# Reality", "", "Eins.", "", "Two.", "")), ["preface"])

    for key in ("knobs", "guards", "sources", "backlog", "touches"):
        ways(f"{key} is such a list", file(case("b-case", **{key: ["z", "m"]})), file(case("b-case", **{key: ["z", "a", "m"]})), file(case("b-case", **{key: ["z", "m", "b"]})),
             file(case("b-case", **{key: ["z", "a", "m", "b"]})))
    ways("a name a side has twice is in it once", base, file(case("b-case", guards=["test: a", "e2e: b", "test: a", "test: c", "test: c"]), case("d-case")),
         file(case("b-case", guards=["test: a", "e2e: b", "test: z"]), case("d-case")), file(case("b-case", guards=["test: a", "e2e: b", "test: c", "test: z"]), case("d-case")))
    ways("both give a case a list it need not have", base, file(case("b-case", touches=["jolt"]), case("d-case")), file(case("b-case", touches=["lost"]), case("d-case")),
         file(case("b-case", touches=["jolt", "lost"]), case("d-case")))
    ways("a list a case need not have, taken off by one side and emptied by the other, is not there",
         file(case("b-case", touches=["jolt", "lost"])), file(case("b-case")), file(case("b-case", touches=["lost"])), file(case("b-case")))
    ways("capitals come before small letters, as everywhere where nobody asks what language it is", base, file(*base["entries"], case("C-case")), file(*base["entries"], case("a-case")),
         file(case("C-case"), case("a-case"), case("b-case"), case("d-case")))
    odd = ("# Reality", "", 'It said "no".', "a\\b", "two\nlines", "=======", "<<<<<<< ours", "\u2028", "")
    ways("prose: whatever a line holds", file(*base["entries"], preface=odd), file(*base["entries"], preface=("First.",) + odd), file(*base["entries"], preface=odd + ("Last.",)),
         file(*base["entries"], preface=("First.",) + odd + ("Last.",)))
    both = dict(base, afterword=["One.", "", "Two."])
    ways("prose: the afterword too", both, dict(both, afterword=["One!", "", "Two."]), dict(both, afterword=["One.", "", "Two!"]), dict(both, afterword=["One!", "", "Two!"]))
    ways("prose that was not there, from both sides and not the same: a conflict", base, dict(base, afterword=["One."]), dict(base, afterword=["Two."]), ["afterword"])
    ways("both give one case another id, each its own: that would make two of it. A conflict",
         base, file(case("b-case"), case("d-one")), file(case("b-case"), case("d-two")), ["entries d-one or d-two"])
    ways("both take a case off and each adds one that is nothing like it: no conflict", base,
         file(case("b-case"), case("x-case", kind="looks", guards=["tool: x"], copes="elsewhere, otherwise, by somebody else")),
         file(case("b-case"), case("y-case", kind="input", guards=[], copes="quite another matter, seen on another day")),
         file(case("b-case"), case("x-case", kind="looks", guards=["tool: x"], copes="elsewhere, otherwise, by somebody else"),
              case("y-case", kind="input", guards=[], copes="quite another matter, seen on another day")))

    def text(data, by_id=True):
        return text_of(data, SHAPES[ledger]._replace(by_id=by_id))
    code, merged_text, said = merge_texts(text(base), text(file(*base["entries"], preface=("# Reality", "", "Uno.", "", "Two.", "", "Three."))),
                                          text(file(case("b-case", kind="input"), case("d-case"), preface=("# Reality!", "", "Eins.", "", "Two.", ""))), ledger)
    row("the ledger: --merge: of prose in dispute only the lines in dispute stand between the markers, and all the rest is merged", (code, merged_text),
        (1, text(file(case("b-case", kind="input"), case("d-case"), preface=("# Reality!", "", "Uno.", "", "Two.", "", "Three."))).replace(
            '  "Uno.",\n', '<<<<<<< ours\n  "Uno.",\n=======\n  "Eins.",\n>>>>>>> theirs\n')))
    said = merge_texts(text(base), text(file(case("b-case"), case("a-new-name", kind="looks"), case("z-case", kind="looks", guards=["tool: x"]))),
                       text(file(case("b-case"), case("d-case", kind="input"))), ledger)[2]
    row("the ledger: --merge: a case that one side renamed and the other changed is a conflict, which says what may be behind it",
        said[said.index(" (renamed?"):], " (renamed? The side that has it no more has added a-new-name, which is much like it)\n")
    said = merge_texts(text(base), text(file(case("b-case"), case("z-case", kind="looks", guards=["tool: x"], found="elsewhere, otherwise, by somebody else"))),
                       text(file(case("b-case"), case("d-case", kind="input"))), ledger)[2]
    row("the ledger: --merge: and does not say so of a case that is not like it", ("ours has nothing" in said, "renamed" in said), (True, False))
    said = merge_texts(text(base), text(file(case("b-case"), case("a-new-name", kind="looks"), case("c-new-name"))), text(file(case("b-case"), case("d-case", kind="input"))), ledger)[2]
    row("the ledger: --merge: of two that are like it, it names the one that is more so", "has added c-new-name" in said, True)
    said = merge_texts(text(base), text(file(case("b-case"))), text(file(case("d-case", kind="input"))), ledger)[2]
    row("the ledger: --merge: a case that was there all along is no new name for another", ("ours has nothing" in said, "renamed" in said), (True, False))
    unsorted = file(case("d-case"), case("b-case"))
    row("the ledger: --merge: while neither side has its cases in order it is not for a merge to sort them",
        merge_texts(text(unsorted, False), text(file(*unsorted["entries"], case("c-case")), False), text(file(case("d-case"), case("b-case", kind="input")), False), ledger),
        (0, text(file(case("d-case"), case("b-case", kind="input"), case("c-case")), False), ""))
    row("the ledger: --merge: a pull request from before the sorting, on a trunk that is sorted",
        merge_texts(text(unsorted, False), text(unsorted), text(file(*unsorted["entries"], case("a-case")), False), ledger),
        (0, text(file(case("a-case"), case("b-case"), case("d-case"))), ""))
    row("the ledger: --merge: a trunk that is sorted and otherwise not quite in the shape stays sorted",
        merge_texts(text(unsorted, False), json.dumps(file(case("b-case", kind="é"), case("d-case")), indent=1) + "\n", text(file(*unsorted["entries"], case("a-case")), False), ledger),
        (0, text(file(case("a-case"), case("b-case", kind="é"), case("d-case"))), ""))
    code, merged_text, said = merge_texts(text(file(case("b-case", kind="a\u2028z"))), text(file(case("b-case", kind="a\u2028b"))), text(file(case("b-case", kind="a\u2028c"))), ledger)
    row("the ledger: --merge: a line is what ends in a line feed, whatever else Python takes for the end of one",
        (code, [line for line in merged_text.split("\n") if line[:7] in ("<<<<<<<", "=======", ">>>>>>>")], taking(THEIRS, merged_text)),
        (1, ["<<<<<<< ours", "=======", ">>>>>>> theirs"], text(file(case("b-case", kind="a\u2028c")))))
    many = [case(f"case-{number:03}", found=f"{number} words and more words " * 60) for number in range(300)]
    started = time.monotonic()
    code = merge_texts(text(file(*many)), text(file(*(dict(each, id="new-" + each["id"]) for each in many))), text(file(*(dict(each, kind="input") for each in many))), ledger)[0]
    row("the ledger: --merge: a side that renames everything costs seconds, not minutes", (code, time.monotonic() - started < 5), (1, True))
    row("the ledger: --merge: the commit that does nothing but sort, on a trunk that has moved: the trunk, sorted",
        merge_texts(text(unsorted, False), text(file(*unsorted["entries"], case("a-case")), False), text(unsorted), ledger),
        (0, text(file(case("a-case"), case("b-case"), case("d-case"))), ""))


class Repository:
    """A repository of its own, with nothing of git's from outside: inside a hook or a rebase GIT_DIR and its kin point at the real one."""

    def __init__(self, folder, environment=None):
        self.path = folder
        outside = {key: value for key, value in os.environ.items() if not key.startswith("GIT_") and key != "CI"}
        self.environment = environment or dict(outside, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")

    def run(self, *command):
        """(exit code, all it said)"""
        done = subprocess.run(command, cwd=self.path, env=self.environment, capture_output=True, text=True, check=False)
        return done.returncode, done.stdout + done.stderr

    def git(self, *arguments):
        return self.run("git", "-c", "user.name=someone", "-c", "user.email=someone@users.noreply.github.com", *arguments)

    def commit(self, **files):
        for name, text in files.items():
            path = os.path.join(self.path, {"parity": PARITY, "ledger": "collab/reality.json", "page": GENERATED[0]}[name])
            os.makedirs(os.path.dirname(path), exist_ok=True)
            write(path, text)
        self.git("add", "--all")
        self.git("commit", "--quiet", "--message", "something")

    def text(self, name=PARITY):
        with open(os.path.join(self.path, name), encoding="utf-8") as handle:
            return handle.read()


def check_git():
    """git itself, with what --install tells it. No commit here has a .gitattributes, like a branch from before there was one."""
    base = file_of(item("T01", title="one", tests=["b", "d"]), item("T02", tests=["x"]))
    first = file_of(item("T01", title="one", tests=["b", "d", "c"]), item("T02", tests=["x"]))
    second = file_of(item("T01", title="one", tests=["b", "d", "c", "e"]), item("T02", tests=["x"], status="partial"))
    trunk = file_of(item("T01", title="one", tests=["a", "b", "d"]), item("T02", tests=["x"]))
    both = file_of(item("T01", title="one", tests=["a", "b", "c", "d", "e"]), item("T02", tests=["x"], status="partial"))
    this = os.path.abspath(__file__)
    with tempfile.TemporaryDirectory() as folder:
        repository = Repository(os.path.join(folder, "a clone's $HOME"))
        os.makedirs(repository.path)
        row("--install: outside a clone it says so", repository.run(sys.executable, this, "--install"), (1, "mergeable.py --install: this is no clone of a repository\n"))
        repository.git("init", "--quiet", "--initial-branch=trunk")
        repository.commit(parity=lined(base), page="tests 2/2\n")
        repository.git("checkout", "--quiet", "-b", "feature")
        repository.commit(parity=lined(first), page="tests 3/3\n")
        repository.commit(parity=lined(second), page="tests 4/4\n")
        write(os.path.join(folder, "series.mbox"), repository.git("format-patch", "--stdout", "trunk..feature")[1])
        repository.git("branch", "as-it-was")
        repository.git("checkout", "--quiet", "trunk")
        repository.commit(parity=lined(trunk), page="tests 3/3, others\n")
        repository.commit(parity=shaped(trunk))
        repository.git("checkout", "--quiet", "feature")
        row("git by itself: a pull request from before the shape does not rebase", repository.git("rebase", "trunk")[0] != 0, True)
        row("--check: a word on a clone that has not been told, and no failure",
            [line[:5] for line in repository.run(sys.executable, this, "--check")[1].split("\n") if "make hooks" in line], ["note:"])

        write(os.path.join(repository.path, ".git", "info", "attributes"), "*.png binary")
        row("--install", repository.run(sys.executable, this, "--install")[0], 0)
        repository.run(sys.executable, this, "--install")
        row("--install: twice is once, and what the clone's list of attributes had stays",
            repository.text(".git/info/attributes").split("\n"), ["*.png binary"] + ATTRIBUTES + [""])
        row("--check: not a word any more", "make hooks" in repository.run(sys.executable, this, "--check")[1], False)
        repository.git("checkout", "-m", "--", PARITY)
        row("a conflict that is there already: `git checkout -m` merges the file again, by meaning",
            repository.text(), shaped(file_of(item("T01", title="one", tests=["a", "b", "c", "d"]), item("T02", tests=["x"]))))
        repository.git("rebase", "--abort")
        row("git, told: both commits of the pull request rebase by themselves", (repository.git("rebase", "trunk")[0], repository.text()), (0, shaped(both)))
        row("and the generated page, which both sides changed, is the trunk's, to be made again", repository.text(GENERATED[0]), "tests 3/3, others\n")
        repository.git("checkout", "--quiet", "--detach", "trunk")
        row("which is said", f"{GENERATED[0]} is made from other files" in repository.git("cherry-pick", "as-it-was~1")[1], True)
        repository.git("config", "merge.by-meaning.name", "a name from an earlier version")
        repository.run(sys.executable, this, "--install")
        row("--install: a driver has no name, so that whoever takes its command out has taken it out", repository.git("config", "--get-regexp", "^merge\\..*name")[1], "")
        repository.git("checkout", "--quiet", "-b", "landing", "trunk")
        row("`git am -3` of the same commits", (repository.git("am", "--quiet", "-3", os.path.join(folder, "series.mbox"))[0], repository.text()), (0, shaped(both)))
        repository.git("checkout", "--quiet", "-b", "other", "trunk")
        repository.commit(parity=shaped(file_of(item("T01", title="one", tests=["a", "b", "d"]), item("T02", tests=["x"], status="shipped"))))
        code, said = repository.git("merge", "feature")
        row("a real conflict stops git, which names it",
            (code != 0, 'features, T02, status: ours has "shipped", theirs has "partial"' in said, repository.text().count("<<<<<<<")), (True, True, 1))
        repository.git("merge", "--abort")
        row("`git merge-tree`, which asks whether two heads can be merged and touches nothing, goes by meaning too",
            repository.git("merge-tree", "--write-tree", "trunk", "as-it-was")[0], 0)
        repository.git("worktree", "add", "--quiet", "--detach", os.path.join(folder, "else where"), "trunk")
        elsewhere = Repository(os.path.join(folder, "else where"), repository.environment)
        row("so does a worktree of the clone", (elsewhere.git("cherry-pick", "as-it-was~1", "as-it-was")[0], elsewhere.text()), (0, shaped(both)))
        repository.git("worktree", "remove", "--force", elsewhere.path)
        os.rename(repository.path, os.path.join(folder, "moved"))
        moved = Repository(os.path.join(folder, "moved"), repository.environment)
        moved.git("checkout", "--quiet", "--detach", "trunk")
        row("and the clone after it has been moved", (moved.git("cherry-pick", "as-it-was~1", "as-it-was")[0], moved.text()), (0, shaped(both)))

        kept = os.path.join(moved.path, ".git", "arbor-mergeable", "mergeable.py")
        os.remove(kept)
        moved.git("checkout", "--quiet", "--detach", "trunk")
        row("the script cannot be run: git's merge of lines, with its markers, and not our side as if that were all",
            (moved.git("cherry-pick", "as-it-was~1")[0] != 0, "<<<<<<< ours" in moved.text(), '["b", "d", "c"]' in moved.text()), (True, True, True))
        moved.git("cherry-pick", "--abort")
        with open(this, encoding="utf-8") as handle:
            whole = handle.read()
        for what, copy in (("empty", ""), ("cut off", whole[:3000]), ("cut off at a line's end", "".join(whole.splitlines(True)[:300])), ("in want of a module", "import nosuchmodule\n"),
                           ("one that ends well and does nothing", "import sys\nsys.exit(0)\n"), ("one that says conflict and does nothing", "import sys\nsys.exit(1)\n"),
                           ("a folder", None)):
            if copy is None:
                os.remove(kept)
                os.mkdir(kept)
            else:
                write(kept, copy)
            moved.git("checkout", "--quiet", "--detach", "trunk")
            row(f"the kept copy is {what}: never a merge that ends well with theirs gone, nor a conflict without a marker",
                (moved.git("cherry-pick", "as-it-was~1")[0] != 0, "<<<<<<< ours" in moved.text(), '["b", "d", "c"]' in moved.text()), (True, True, True))
            moved.git("cherry-pick", "--abort")
            if copy is None:
                os.rmdir(kept)
        write(kept, f"VERSION = {VERSION}\n# an earlier one of the same number\n")
        with open(kept, encoding="utf-8") as reader:
            moved.run(sys.executable, this, "--install")
            row("--install: whoever is reading the kept copy meanwhile, a merge in another worktree say, reads all of the old one or all of the new",
                (reader.read(), moved.text(".git/arbor-mergeable/mergeable.py") == whole), (f"VERSION = {VERSION}\n# an earlier one of the same number\n", True))
        before = os.stat(kept).st_ino, os.stat(kept).st_mtime_ns
        row("--install: from the kept copy itself", (moved.run(sys.executable, kept, "--install")[0], moved.text(".git/arbor-mergeable/mergeable.py") == whole), (0, True))
        moved.run(sys.executable, this, "--install")
        row("--install: a copy that is the same already is not touched", (os.stat(kept).st_ino, os.stat(kept).st_mtime_ns), before)
        write(kept, f"VERSION = {VERSION + 1}\n")
        moved.git("config", "merge.by-meaning.driver", "as the newer one is called")
        moved.run(sys.executable, this, "--install")
        row("--install: `make hooks` on an old branch does not put an older merge back, nor the way it was called",
            (moved.text(".git/arbor-mergeable/mergeable.py"), moved.git("config", "merge.by-meaning.driver")[1]), (f"VERSION = {VERSION + 1}\n", "as the newer one is called\n"))
        row("--check: and has no word to say on it", "note:" in moved.run(sys.executable, this, "--check")[1], False)
        moved.git("config", "merge.by-meaning.driver", DRIVER)
        write(kept, f"VERSION = {VERSION - 1}\n")
        row("--check: a word on a clone whose copy is older", "note:" in moved.run(sys.executable, this, "--check")[1], True)
        write(kept, f"VERSION = {VERSION}\n")
        row("--check: and on one of the same number that is not the same", "note:" in moved.run(sys.executable, this, "--check")[1], True)
        moved.run(sys.executable, this, "--install")
        row("--check: not on the very same", "note:" in moved.run(sys.executable, this, "--check")[1], False)
        moved.git("config", "--unset", "merge.by-meaning.driver")
        row("--check: but on a clone that has the copy and does not call it", "note:" in moved.run(sys.executable, this, "--check")[1], True)
        row("--check: but not in CI, where nobody merges", "note:" in Repository(moved.path, dict(moved.environment, CI="true")).run(sys.executable, this, "--check")[1], False)
        moved.run(sys.executable, this, "--install")
        with open(this, encoding="utf-8") as handle:
            row("--install: one of the same age or newer replaces it", moved.text(".git/arbor-mergeable/mergeable.py") == handle.read(), True)


def check_git_and_the_ledger():
    """The same of the ledger: two commits from before the sorting, on a trunk that has gone on and been sorted."""
    shape = SHAPES["collab/reality.json"]

    def text(*names, by_id=False, **keys):
        return text_of({"preface": ["# Reality"], "entries": [dict({"id": name, "guards": ["test: a"]}, **keys.get(name[0], {})) for name in names]}, shape._replace(by_id=by_id))
    with tempfile.TemporaryDirectory() as folder:
        repository = Repository(folder)
        repository.git("init", "--quiet", "--initial-branch=trunk")
        repository.commit(ledger=text("m-case", "d-case"))
        repository.git("checkout", "--quiet", "-b", "feature")
        repository.commit(ledger=text("m-case", "d-case", "a-case"))
        repository.commit(ledger=text("m-case", "d-case", "a-case", "z-case", d={"guards": ["test: a", "test: c"]}))
        repository.git("checkout", "--quiet", "trunk")
        repository.commit(ledger=text("m-case", "d-case", "k-case", d={"guards": ["test: b", "test: a"]}))
        repository.git("branch", "unsorted")
        repository.commit(ledger=text("m-case", "d-case", "k-case", by_id=True, d={"guards": ["test: b", "test: a"]}))
        repository.git("checkout", "--quiet", "feature")
        repository.run(sys.executable, os.path.abspath(__file__), "--install")
        wanted = {"d": {"guards": ["test: b", "test: a", "test: c"]}}
        row("the ledger: git, told, does, and the cases are in order", (repository.git("rebase", "trunk")[0], repository.text("collab/reality.json")),
            (0, text("a-case", "d-case", "k-case", "m-case", "z-case", by_id=True, **wanted)))
        repository.git("checkout", "--quiet", "--detach", "unsorted")
        row("the ledger: on the trunk from before the sorting they stay as they were",
            (repository.git("cherry-pick", "ORIG_HEAD~1", "ORIG_HEAD")[0], repository.text("collab/reality.json")), (0, text("m-case", "d-case", "a-case", "k-case", "z-case", **wanted)))


def self_test():
    for check in (check_sets, check_keys, check_items, check_shape, check_files, check_ledger, check_git, check_git_and_the_ledger):
        check()
    wrong = 0
    for what, got, expected in rows:
        if got != expected:
            wrong += 1
            print(f"✘ {what}:\n    expected {repr(expected)[:1500]}\n    got      {repr(got)[:1500]}")
    print(f"{len(rows) - wrong} of {len(rows)} situations with a file that two sides changed came out as expected")
    return 1 if wrong else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    what = parser.add_mutually_exclusive_group(required=True)
    what.add_argument("--tidy", action="store_true", help="rewrite the file in the shape that merges")
    what.add_argument("--check", action="store_true", help="fail if it is not in that shape")
    what.add_argument("--merge", nargs=4, metavar=("BASE", "OURS", "THEIRS", "PATH"),
                      help="merge three versions of the file PATH by meaning; the result goes into OURS")
    what.add_argument("--driver", nargs=4, metavar=("BASE", "OURS", "THEIRS", "PATH"), help=f"the same for git: {MERGED} if merged, {IN_DISPUTE} if there is a conflict")
    what.add_argument("--install", action="store_true", help="have git merge so by itself in this clone")
    what.add_argument("--self-test", action="store_true", help="situations and what must come of them")
    args = parser.parse_args()
    if args.merge:
        return merge_files(*args.merge)
    if args.driver:
        return IN_DISPUTE if merge_files(*args.driver) else MERGED
    if args.install:
        return install()
    if args.self_test:
        return self_test()
    if args.check:
        note_on_this_clone()
    return tidy({os.path.join(ROOT, name): shape for name, shape in SHAPES.items()}, args.check)


if __name__ == "__main__":
    sys.exit(main())
