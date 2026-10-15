"""The few words a newcomer can say to the Mac, and what the rig takes them to mean (scripts/newcomer/README.md).

A message is what lies on the action branch: the number of the picture it answers on the first line, then at most six lines, each a
remark or an act, with at most one act, in the last place. Whoever can push to the repository can write one, and whatever it holds
is carried out with a real pointer and real keys. So nothing here is passed on as it came: a line is taken apart into a verb and
numbers, names from a list, or characters from a list, and put together again. What does not fit is nonsense, which costs the newcomer
a round and does nothing.

Written for Python 3.9, which is what a hosted Mac has.
"""

import re

MODIFIERS = ("ctrl", "opt", "shift", "cmd")
# The names scripts/mac-shell/pointer.swift knows, which are the ones settings.json uses.
KEYS = set("abcdefghijklmnopqrstuvwxyz0123456789") | set("[]-=,./;'`\\") | {
    "space", "return", "enter", "tab", "escape", "esc", "delete", "left", "right", "down", "up",
    "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12"}
# What a US keyboard types with ⇧ held, and on which key.
SHIFTED = dict(zip('~!@#$%^&*()_+{}|:"<>?', "`1234567890-=[]\\;',./"))

REMARKS = ("stuck", "surprised", "wrong", "lookup")
ENDS = ("done", "giveup")
LONGEST_MESSAGE = 1500
MOST_LINES = 6
LONGEST_REMARK = 200
LONGEST_TEXT = 120
# No slash, no at sign, no underscore: a path, a link, an address or the id of a working session cannot be spelled with these.
REMARK = re.compile(r"[A-Za-z0-9 .,:;'()?!+\"-]*\Z")
TEXT = re.compile(r"[ -~]*\Z")


class Nonsense(Exception):
    """A line, or a whole message, that is not in the language. Its text is for the newcomer to read."""


def number(word, what, least, most):
    if not re.match(r"-?[0-9]{1,5}\Z", word):
        raise Nonsense("%s is a whole number, not '%s'" % (what, plain(word)))
    value = int(word)
    if not least <= value <= most:
        raise Nonsense("%s is between %d and %d, not %d" % (what, least, most, value))
    return value


def plain(text, most=40):
    """What may be shown again of something that was not understood."""
    return re.sub(r"[^A-Za-z0-9 .,:;'()?!+-]", "?", text)[:most]


def modifiers(word):
    names = word.split("+")
    if not names or len(set(names)) != len(names) or any(name not in MODIFIERS for name in names):
        raise Nonsense("after 'holding' come ctrl, opt, shift, cmd, joined by +, not '%s'" % plain(word))
    return "+".join(name for name in MODIFIERS if name in names)


def chord(word):
    """`cmd+shift+a`: any of the four modifiers, then one key. The key + itself is written shift+=."""
    names = word.lower().split("+")
    held, key = names[:-1], names[-1]
    if key in MODIFIERS and not held:
        raise Nonsense("'%s' alone presses nothing: a chord ends in a key, as in cmd+tab" % key)
    if key not in KEYS:
        raise Nonsense("there is no key '%s': letters, digits, space return tab escape delete left right up down f1 to f12 and [ ] - = , . / ; ' ` \\" % plain(key))
    if len(set(held)) != len(held) or any(name not in MODIFIERS for name in held):
        raise Nonsense("before the key come ctrl, opt, shift, cmd, joined by +, not '%s'" % plain(word))
    return "+".join([name for name in MODIFIERS if name in held] + [key])


def chords_for(text):
    """The presses that type the text on a US keyboard."""
    presses = []
    for character in text:
        if character == " ":
            presses.append("space")
        elif character in SHIFTED:
            presses.append("shift+" + SHIFTED[character])
        elif character.isupper():
            presses.append("shift+" + character.lower())
        else:
            presses.append(character)
    return presses


def parse_line(line, width, height):
    """One line as a dictionary: {"verb": …} and what the verb takes. `width` and `height` are the picture's."""
    if not TEXT.match(line):
        raise Nonsense("only plain ASCII characters can be sent")
    words = line.split()
    if not words:
        raise Nonsense("an empty line")
    verb, rest = words[0].lower(), words[1:]

    def point(index, what=""):
        if len(rest) < index + 2:
            raise Nonsense("%s takes x and y%s" % (verb, what))
        return number(rest[index], "x", 0, width - 1), number(rest[index + 1], "y", 0, height - 1)

    def options(index, allowed):
        found = {}
        while index < len(rest):
            word = rest[index].lower()
            if word == "holding" and "holding" in allowed and "holding" not in found and index + 1 < len(rest):
                found["holding"] = modifiers(rest[index + 1].lower())
                index += 2
            elif word == "keep" and "keep" in allowed and "keep" not in found:
                found["keep"] = True
                index += 1
            else:
                raise Nonsense("'%s' does not belong after %s" % (plain(rest[index]), verb))
        return found

    if verb in REMARKS or verb == "giveup":
        said = line.strip()[len(words[0]):].strip().strip('"').strip()
        if not said:
            raise Nonsense("%s takes a few words: what happened, what you expected" % verb)
        if len(said) > LONGEST_REMARK:
            raise Nonsense("%s takes at most %d characters" % (verb, LONGEST_REMARK))
        if not REMARK.match(said):
            raise Nonsense("a remark is letters, digits, spaces and . , : ; ' ( ) ? ! + - only")
        return {"verb": verb, "words": said}
    if verb in ("click", "double-click", "right-click"):
        x, y = point(0)
        return dict({"verb": verb, "x": x, "y": y}, **options(2, ("holding",)))
    if verb == "move":
        x, y = point(0)
        options(2, ())
        return {"verb": verb, "x": x, "y": y}
    if verb == "drag":
        x, y = point(0, ", then x and y of where to")
        to_x, to_y = point(2, ", then x and y of where to")
        return dict({"verb": verb, "x": x, "y": y, "to_x": to_x, "to_y": to_y}, **options(4, ("holding", "keep")))
    if verb == "release":
        if not rest:
            return {"verb": verb}
        x, y = point(0)
        options(2, ())
        return {"verb": verb, "x": x, "y": y}
    if verb == "scroll":
        x, y = point(0, ", then how many notches")
        if len(rest) != 3:
            raise Nonsense("scroll takes x, y and how many notches: positive is up")
        notches = number(rest[2], "the number of notches", -20, 20)
        if notches == 0:
            raise Nonsense("scroll by 0 does nothing")
        return {"verb": verb, "x": x, "y": y, "notches": notches}
    if verb == "key":
        if not 1 <= len(rest) <= 4:
            raise Nonsense("key takes one to four chords, as in: key cmd+tab")
        return {"verb": verb, "chords": [chord(word) for word in rest]}
    if verb == "type":
        text = line.strip()[len(words[0]):].strip()
        if len(text) >= 2 and text[0] == text[-1] == '"':
            text = text[1:-1]
        if not text:
            raise Nonsense("type takes the text to type")
        if len(text) > LONGEST_TEXT:
            raise Nonsense("type takes at most %d characters at a time" % LONGEST_TEXT)
        return {"verb": verb, "text": text}
    if verb == "wait":
        if len(rest) != 1:
            raise Nonsense("wait takes a number of seconds")
        return {"verb": verb, "seconds": number(rest[0], "the number of seconds", 1, 10)}
    if verb in ("ready", "done", "password"):
        if rest:
            raise Nonsense("%s stands alone" % verb)
        return {"verb": verb}
    raise Nonsense("'%s' is no word of this language" % plain(verb))


def say(action):
    """The line again, from what was understood of it: this, and never what came, goes into the record."""
    verb = action["verb"]
    parts = [verb]
    if "words" in action:
        parts.append(action["words"])
    if "x" in action:
        parts += [str(action["x"]), str(action["y"])]
    if "to_x" in action:
        parts += [str(action["to_x"]), str(action["to_y"])]
    if "notches" in action:
        parts.append(str(action["notches"]))
    if "chords" in action:
        parts += action["chords"]
    if "text" in action:
        parts.append('"%s"' % action["text"])
    if "seconds" in action:
        parts.append(str(action["seconds"]))
    if "holding" in action:
        parts += ["holding", action["holding"]]
    if action.get("keep"):
        parts.append("keep")
    return " ".join(parts)


def parse_message(data, width, height):
    """(round, remarks, act or None) of what lay on the action branch, as bytes."""
    if len(data) > LONGEST_MESSAGE:
        raise Nonsense("a message is at most %d bytes long" % LONGEST_MESSAGE)
    try:
        lines = data.decode("ascii").split("\n")
    except UnicodeDecodeError:
        raise Nonsense("only plain ASCII characters can be sent")
    lines = [line for line in lines if line.strip()]
    if not lines or not re.match(r"[0-9]{1,5}\Z", lines[0].strip()):
        raise Nonsense("a message begins with the number of the picture it answers")
    answered, lines = int(lines[0].strip()), lines[1:]
    if not lines:
        raise Nonsense("a message with nothing in it")
    if len(lines) > MOST_LINES:
        raise Nonsense("a message has at most %d lines" % MOST_LINES)
    remarks, act = [], None
    for line in lines:
        if act is not None:
            raise Nonsense("one act to a message, and in the last place")
        action = parse_line(line, width, height)
        if action["verb"] in REMARKS:
            remarks.append(action)
        else:
            act = action
    return answered, remarks, act
