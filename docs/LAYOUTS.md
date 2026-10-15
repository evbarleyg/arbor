# Arrangements as a line of text

An arrangement is spaces inside spaces, and that can be written on one line. Type it, bind it to a shortcut, keep it in your
dotfiles, paste it into a chat:

<!-- windows: Safari, Mail, Notes -->
```console
$ arborctl layout "Safari | Desktop | (Mail / Notes)"
arranged 3 windows
$ arborctl ascii
display main
+----------------------+........................+----------------------+
|w101 Safari           |.desktop               .|w102 Mail             |
|                      |.                      .|                      |
|                      |.                      .|                      |
|                      |.                      .|                      |
|                      |.                      .|                      |
|                      |.                      .|                      |
|                      |.                      .|                      |
|                      |.                      .|                      |
|                      |.                      .|                      |
|                      |.                      .+----------------------+
|                      |.                      .+----------------------+
|                      |.                      .|w103 Notes            |
|                      |.                      .|                      |
|                      |.                      .|                      |
|                      |.                      .|                      |
|                      |.                      .|                      |
|                      |.                      .|                      |
|                      |.                      .|                      |
|                      |.                      .|                      |
|                      |.                      .|                      |
+----------------------+........................+----------------------+
camera n1
```

`arborctl layout` on its own prints the arrangement you are looking at in the same notation, so the quickest way to write a
line is to arrange the windows by hand and ask:

```console
$ arborctl layout
Safari | Desktop | (Mail / Notes)
```

Every example on this page is run by the tests (`DocTranscriptTests`), against the real controller, and prints what it says here.

## The notation

| Write | Meaning |
|---|---|
| `A \| B` | side by side |
| `A / B` | one above the other |
| `( … )` | a group: `A \| (B / C)` |
| `[A B]` | a tab group: the windows share one place |
| `A:2` | a relative size: twice as large as a neighbour without one. From 0.001 to 1000, on anything: `(B / C):0.5`, `[A B]:2`, `Desktop:0.25` |
| `Desktop` | the Desktop, where floating windows live |
| `Safari` | an app, by name or bundle id |
| `"Visual Studio Code"` | a name with spaces or punctuation goes in quotes, single or double |
| `Safari*` | all the windows of Safari that remain, as tabs |
| `Safari~Inbox` | the Safari window with "Inbox" in its title, if there is one |
| `412` | the window with that number (from `layout --ids` or `state`). A window has one place, so a number is written once; an app's name twice means two of its windows |

`|` and `/` cannot be mixed without brackets, because nobody should have to remember which binds tighter:

<!-- windows: Safari, Mail, Notes -->
```console
$ arborctl layout "Safari | Mail / Notes"
layout, column 15: `|` and `/` are mixed here: put brackets around one of them
  Safari | Mail / Notes
                ^
```

Spaces around the signs are up to you: `Safari|(Mail/Notes)` is the same line.

## Sizes

<!-- windows: Xcode, Simulator, Terminal -->
```console
$ arborctl layout "Xcode:2 | (Simulator / Terminal) | Desktop"
arranged 3 windows
$ arborctl ascii
display main
+----------------------------------++----------------+..................
|w101 Xcode                        ||w102 Simulator  |.desktop         .
|                                  ||                |.                .
|                                  ||                |.                .
|                                  ||                |.                .
|                                  ||                |.                .
|                                  ||                |.                .
|                                  ||                |.                .
|                                  ||                |.                .
|                                  ||                |.                .
|                                  |+----------------+.                .
|                                  |+----------------+.                .
|                                  ||w103 Terminal   |.                .
|                                  ||                |.                .
|                                  ||                |.                .
|                                  ||                |.                .
|                                  ||                |.                .
|                                  ||                |.                .
|                                  ||                |.                .
|                                  ||                |.                .
|                                  ||                |.                .
+----------------------------------++----------------+..................
camera n1
```

Only ratios between neighbours matter: `Xcode:2 | Terminal` and `Xcode:4 | Terminal:2` are the same arrangement. When Arbor prints a
line, the smallest window or group of each group is the one without a size, and a gap you dragged by hand shows up as
something like `:1.373`.

## The Desktop

Every display has one Desktop. If the line does not mention it, it is added at the right, `arrangeDesktopWeight` (0.5) times as
wide as the average place beside it, as `arrange` does:

<!-- windows: Safari, Mail -->
```console
$ arborctl layout "Safari | Mail"
arranged 2 windows
$ arborctl layout
Safari | Mail | Desktop:0.5
```

While windows float on it, a Desktop that was added is made wide enough to use (`minimumUsableWidth`), so that the windows the line does not mention, the
Terminal it was typed in among them, have somewhere to be:

<!-- windows: Safari, Mail, Notes, Terminal -->
<!-- focuses: 104 -->
```console
$ arborctl layout "Safari | Mail | Notes"
arranged 3 windows
$ arborctl layout
Safari | Mail | Notes | Desktop:0.638
```

A Desktop that is mentioned is as large as the line says. Either way `layout` never takes a floating window out of view; if some were out of view and there is still no usable
Desktop for them to come back to, the reply says how many.

`Desktop` alone undocks everything on the display. An app that is really called Desktop goes in quotes: `"Desktop"`.

## Names

A name is an app's name or its bundle id; capitals do not matter. The exact name always wins. If no app is called exactly that,
the last part of a bundle id will do (`Chrome` for com.google.Chrome), and then whole words of a name (`Code` for Visual
Studio Code, but not `Vis`).

<!-- windows: Visual Studio Code [com.microsoft.VSCode], Google Chrome [com.google.Chrome], Slack [com.tinyspeck.slackmacgap] -->
```console
$ arborctl layout "'Visual Studio Code' | [Chrome com.tinyspeck.slackmacgap]"
arranged 3 windows; 1 window is behind a tab: ⌘Tab or ⌘` brings one forward
$ arborctl layout
"Visual Studio Code" | ["Google Chrome" Slack] | Desktop:0.5
```

Plain names are letters, digits, `.`, `-` and `_`. Anything else needs quotes, and the error says so:

```console
$ arborctl layout "Visual Studio Code | Slack"
layout, column 8: expected `|` or `/` here; a name of several words needs quotes
  Visual Studio Code | Slack
         ^
```

Inside quotes, the same quote written twice stands for itself (`'it''s'`); or use the other kind (`"it's"`). The curly quotes that
chat apps make of straight ones are understood too.

## Several windows of one app

A name takes the app's most recently focused window. The second `Safari` takes the one before that, and `Safari*` takes all that
remain, as tabs:

<!-- windows: Safari, Safari, Safari, Mail -->
<!-- focuses: 101 -->
<!-- focuses: 103 -->
```console
$ arborctl layout "Safari | Mail | Safari"
arranged 3 windows
$ arborctl layout --ids
103 | 104 | 101 | Desktop:0.638
$ arborctl layout "Safari | Mail | Safari*"
arranged 4 windows; 1 window is behind a tab: ⌘Tab or ⌘` brings one forward
$ arborctl layout --ids
103 | 104 | [101 102] | Desktop:0.5
```

Until tab groups have their strips, nothing on screen shows the windows behind a tab, so the reply counts them. ⌘Tab, or ⌘` within an app, brings one forward.

A window that is already where the line would put a window of its app stays there, so the same line again changes nothing, whichever window you used in between.
Windows that are in view are preferred to minimised and hidden ones. A window that is minimised, hidden or on another macOS Space
can still get a place; it takes no room until it is back.

A title tells an app's windows apart. It is a preference, not a condition: titles change, and a place left empty helps nobody, so if
no window has the title, the place goes to another window of the app.

<!-- windows: Safari "Hacker News", Safari "Inbox (3) - Fastmail", Mail "Drafts" -->
```console
$ arborctl layout "Safari~inbox | Safari | Mail"
arranged 3 windows
$ arborctl layout --ids
102 | 101 | 103 | Desktop:0.5
```

The text is looked for anywhere in a title, and the whole of one title can be part of another's. So the closest wins: a window whose whole title it is, then one whose title
begins with it, then one that has it somewhere; and what one place names exactly is not taken by a vaguer one that is written before it.

<!-- windows: Mail "Re: Inbox", Mail "Inbox (2)", Mail "Inbox" -->
```console
$ arborctl layout "Mail~Inbox | Mail~'Inbox (2)' | Mail~Re"
arranged 3 windows
$ arborctl layout --ids
103 | 102 | 101 | Desktop:0.5
```

## What is missing, and what is not mentioned

Apps without a window are skipped, their places close up, and the reply says so:

<!-- windows: Safari, Notes, Slack -->
```console
$ arborctl layout "Safari | Desktop | (Mail / Notes)"
arranged 2 windows; no window of Mail
$ arborctl layout
Safari | Desktop | Notes
```

Slack was not mentioned, so it floats on the Desktop. If nothing in the line is found, the line was probably mistyped, and nothing happens:

```console
$ arborctl layout "Sfari | Mial"
no window of Sfari or Mial; nothing changed
```

With `--open`, apps that have no window are opened (in the background), and each takes its place when its window appears,
for up to a minute. The view stays where you are looking. Rearranging anything by hand meanwhile calls the wait off. `--open` needs
the app's full name or bundle id, as `open -a` does.

```console
$ arborctl layout --open "Safari | Desktop | (Mail / Notes)"
arranged 2 windows; opening Mail
```
<!-- opens: Mail -->
```console
$ arborctl layout
Safari | Desktop | (Mail / Notes)
```

## Displays

The line applies to the display other commands act on: the one under the pointer, or, from a shortcut pressed while typing, the one with the focused window. `@2` names another: `@1` is the main display, the others are counted from left
to right and top to bottom. A display's id from `arborctl state` works too. Windows come over from other displays if the line asks for them.

<!-- displays: 2 -->
<!-- windows: Safari, Mail, Notes -->
```console
$ arborctl layout @2 "Mail / Notes"
arranged 2 windows
$ arborctl layout @2
(Mail / Notes) | Desktop:0.5
$ arborctl layout @3 Safari
no display 3; there are 2 displays, counted from @1
```

## Printing

| Command | Each window is written as | For |
|---|---|---|
| `layout` | its app | dotfiles, shortcuts, other people |
| `layout --titles` | its app and the beginning of its title | telling an app's windows apart later |
| `layout --ids` | its number | putting things back exactly, while the windows live |

<!-- windows: Safari "Hacker News", Safari "Inbox (3)", Mail "Drafts" -->
```console
$ arborctl layout "102 | (101 / Mail)"
arranged 3 windows
$ arborctl layout
Safari | (Safari / Mail) | Desktop:0.5
$ arborctl layout --titles
Safari~"Inbox (3)" | (Safari~"Hacker News" / Mail~Drafts) | Desktop:0.5
$ arborctl layout --ids
102 | (101 / 103) | Desktop:0.5
```

Titles are never printed unless you ask, and never reach the log. Two apps with the same name are written by bundle id.
What is printed can always be read back. A line holds 4096 bytes, so with very many windows `--titles` shortens the titles, then leaves them out, and in the end writes numbers.
In a script, `saved=$(arborctl layout --ids)` and later `arborctl layout "$saved"` puts an arrangement back.

## Shortcuts

A line works wherever a command does. In `settings.json`, single quotes save escaping:

<!-- settings -->
```json
"bindings": {
  "ctrl+opt+cmd+1": "layout Safari:2 | (Mail / Notes)",
  "ctrl+opt+cmd+2": "layout --open 'Visual Studio Code':2 | (Terminal / Safari*)",
  "ctrl+opt+cmd+3": "layout @2 Slack | Mail"
}
```

## URLs

`arbor://layout/` and then the line, percent-encoded (`%20` space, `%7C` `|`, `%2F` `/`, `%22` `"`):

<!-- windows: Safari, Mail, Notes -->
```console
$ open "arbor://layout/Safari%20%7C%20(Mail%20%2F%20Notes)"
$ arborctl layout
Safari | (Mail / Notes) | Desktop:0.5
```

Any web page can ask macOS to open a URL, so from a URL `layout` only arranges: `--open`, printing, and a line that names no window (`layout Desktop` is
`float-all` by another name) are refused unless `allowAllURLCommands` is on (see the README). So is a line that would cost a saved view or the name of a space, because it takes
apart the space that has it: "`layout` would cost 1 saved view and 1 name, which a URL may not". A line that keeps the space, elsewhere or at another size, costs nothing of what follows it.

## What else to know

- The view shows the whole new arrangement, and `back` returns to where it was. Saved views, the names you gave to spaces and the view's history go on pointing at the
  spaces that still hold the same windows, wherever those are now. So the same line again, or the same windows elsewhere or at other sizes, loses nothing. A space that the line
  takes apart is gone, and what pointed at it with it. Nobody sees that go, so the reply says it: "arranged 3 windows; 1 saved view is gone; 1 name is gone".
- What `layout --ids` prints, read back, costs nothing: no group, no name, no saved view. (So does what `layout` prints, unless an app has two windows docked: a name takes
  the window you used last.) One thing a line cannot write: a named group that is down to one window. Brackets around one thing are that thing, so the name is then the name of that window's place.
- A window that was kept in view, or that comes and goes with a key of its own (`summon`), is an ordinary docked window once a line docks it. The reply says that too:
  "arranged 2 windows; w101 is no longer kept in view", "…; w101 no longer comes and goes with its key". From a shortcut or the menu the line on screen says it with the app's name, and ⌃⌥Z takes it back.
- Not carried: windows that were guests of a view, the way forward in the view's history, and (below) places kept for windows that are not back yet.
- A whole line in quotes is unwrapped, for places where no shell takes the quotes off: `"ctrl+opt+1": "layout \"Safari | Mail\""` works. (An app whose name holds `|`, `/`, `(` or
  `[`, alone on the line, therefore goes in brackets as well: `("a|b")`.)
- Brackets you write are kept, also in the direction of the group around them: `A | (B | C)` gives everybody the share of the room that `A:2 | B | C` gives (to a few points: the gap
  inside the brackets comes out of the group's own room), and B and C are a group that you can frame and name, like a group that you turned with `rotate`. Only a group that comes to
  run like the one around it because an app is not open, so that its place closed up, joins it: without Mail, `A | ((B | C) / Mail)` is `A:2 | B | C`.
- Brackets around one thing are that thing. The size of the whole line means nothing.
- Which tab of a tab group shows is not written: it is the window you used last.
- Apps Arbor does not arrange (`exclude`, `ignore` rules) have no windows as far as `layout` is concerned; the reply says "Arbor does not arrange Music", and `--open` leaves them alone.
- Places kept for windows that are not back yet after a login are printed by bundle id, and dropped when a line is applied, as with `arrange`.
- It is refused while a window is being dragged, and while Arbor is paused.
- A line is at most 4096 bytes (1024 as a URL), brackets go 50 deep, a name has at most 200 characters, and characters that cannot be
  seen (control characters, direction marks) are refused everywhere.

## Errors

Every error names the column, says what was expected there, and points at it:

<!-- windows: Safari -->
```console
$ arborctl layout "Safari | (Mail / Notes"
layout, column 10: this `(` is never closed
  Safari | (Mail / Notes
           ^
$ arborctl layout "Safari | | Mail"
layout, column 10: expected an app's name, a window number, `Desktop`, `(` or `[`
  Safari | | Mail
           ^
$ arborctl layout "[Safari | Mail]"
layout, column 9: a tab group holds only names: expected a name or `]`
  [Safari | Mail]
          ^
$ arborctl layout "Safari:0"
layout, column 8: expected a size from 0.001 to 1000 after `:`
  Safari:0
         ^
$ arborctl layout "Safari | Desktop | Desktop"
layout, column 20: the Desktop is already in this arrangement
  Safari | Desktop | Desktop
                     ^
$ arborctl layout "101 | Desktop | w101"
layout, column 17: window 101 is already in this arrangement
  101 | Desktop | w101
                  ^
$ arborctl layout --titles Safari
layout, column 1: `--titles` goes with `layout` on its own, which prints the arrangement
  --titles Safari
  ^
```

## Grammar

```
line   = space
space  = item { "|" item } | item { "/" item }
item   = ( slot | "Desktop" | "(" space ")" | "[" slot { slot } "]" ) [ ":" size ]
slot   = ( name | window ) [ "~" title ] [ "*" ]
name   = plain | quoted            title = plain | quoted
window = [ "w" ] digits            size  = digits [ "." digits ]
plain  = letters, digits, "." "-" "_", not beginning with "-"
quoted = "…" | '…' | “…” | ‘…’
```

In code: `LayoutNotation.parse` gives a `Spec`, `Spec.resolve` matches its slots to windows (`WindowSlot.assign`, which presets and
every command that names a window by app share), `Spec.tree` builds the `LayoutTree`, and `LayoutTree.notation(names:)` writes one back. All of it is in
`Sources/ArborCore`, pure, and fuzzed.
