# The menu

The one place where the order, the grouping and the titles of Arbor's menu are decided, as [KEYBOARD.md](KEYBOARD.md) is for shortcuts
and [GLOSSARY.md](GLOSSARY.md) for words. **If your feature adds a menu item, find its row here; if it has none, ask for one before you
build it.**

Written by the executor swarm, 2026-10-14 (product owner); for the documenter to review.

## What the menu is for

Arbor has no window and no Dock icon. The menu is the only part of it a newcomer can look at, so it has three jobs, in this order:

1. **The way back.** Someone whose windows have just left the view opens this menu. What they need is in its first three rows: whoever misses one
   window finds it under Windows, every open window by app and title, and Show Everything is right below. Above them stands Arrange Windows, whose key
   is never to be bound again (`collab/QUESTIONS.md`, Q29, point 2): it is run from here.
2. **The vocabulary.** Read from the top, it teaches the model: arrange, show everything, frame, dock, float; stepping out and in is
   under View. Each row shows its shortcut, in submenus too, so the menu is also where shortcuts are learned.
3. **What Arbor is doing that is out of the ordinary**, and the command that ends it: paused, holding, waiting for permission.

It is not the settings window, and not a list of everything Arbor can do: `arborctl help` and Keyboard Shortcuts… are those.

**Every row that runs a command is also found in Go to… by its title here** (F27, "It finds commands too"), a row of a submenu by its way there: "Arrangement ▸ Balance Sizes". The name of an app in a title stands between quotation marks, and says whom the row is about: typed alone it finds the app's windows and no row. So a title is also what somebody types:
two rows must not come out under one name, and a title that only makes sense under its heading ("Left") is fine in a submenu, whose title goes before it. **What is greyed out here cannot be run there either**: grey out whatever
would fail, and whatever would do something else than its title says.

## Rules

1. **The ways back are always at the top level, always in the same place, never greyed out while Arbor runs, and never below a fold**: Show
   Everything is the third row, Float All Windows is in the third group, Pause Arbor and Quit Arbor are the last two rows. (A held
   view is the one exception: nothing moves it, so Show Everything is greyed out, and the row that says so, which releases, takes its place.)
2. **A state comes first, in one row: the sentence, and after " · " the command that ends the state, which choosing the row runs.** At most
   two states are shown; the order of precedence is in [States](#states).
3. **The menu is at most 600 points high, in every state, and the top level stays at 18 rows: a new feature goes into a submenu.** A
   display 768 points high shows 668 points of a menu, between the menu bar and the Dock; what is longer scrolls, and its last rows are the
   ways out. macOS 26 gives a row 24 points, a separator 11, a heading 24, and 5 above and below. So 18 rows and four separators are 486 points on
   an ordinary day, and with two states (two rows and a separator) 545. The room for two more rows is kept free (decided by the product owner, 2026-10-15). That is why the top level has no
   headings: **each group ends in a submenu that bears the group's name** and holds what is not wanted every day. There is no third
   level. **A list that a person makes longer** (open windows, saved views, named spaces, apps that are not arranged) **is never at the top level**; in its
   submenu it has no limit, and comes last where it can: no way out is in there. `MenuHeightTests` counts rows and separators in every state,
   on Linux, and fails at 601; `MenuHeightAppKitTests` asks `NSMenu` itself for those sizes wherever the tests run on a Mac, and
   `scripts/mac-shell/check-menu-height.sh` holds them against the open menu and clicks the ways out.
4. **Greyed out, not hidden.** A row that cannot act now keeps its place, so that hands and eyes find it where it was. Hidden only when
   the thing it is about does not exist: a second display, an app that is not arranged, an update, a feature switched off in settings.
5. **Titles**: a verb first, Title Case, words from the glossary (a state's row is a sentence, and its command after the " · " is a title). `…` only when a window or a panel opens and asks for more. An app's name
   in curly quotes, never a bundle id, never a window's title. **The one exception is Windows ▸**: a person looking for a window knows it by
   its title. A state that is on or off is a tick on one row, not two rows.
6. **Shortcuts shown are the ones in effect** (rebound, moved by the keyboard layout, off in this app), from the same list the hot keys
   are registered from. A row whose shortcut is off shows none.
7. **A command from the menu is answered as a shortcut is**: a line on screen when it failed or when nothing visible changed (F43).
8. Commands act where shortcuts act: on the focused window and its display (F56).

## While Arbor runs

`▸` opens a submenu, `✓` is a tick when on. "Shipped" means on `swarm/trunk` when this was written.

**The Shortcut column is the whole map's** (`shortcuts` set to `all`; `docs/KEYBOARD.md`). As Arbor ships nine keys are bound: ⌃⌥Space, ⌃⌥↩, ⌃⌥[, ⌃⌥G,
⌃⌥F, ⌃⌥Z and ⌃⌥⎋ stand at the rows they have below, and ⌃⌥← and ⌃⌥→ at `Left` and `Right` of Dock Focused Window. **A row whose command has no key
shows none.** The menu is then the way to everything else, so a command that loses its key must have a row. Three kinds have none, being nothing without
a key: `neighbor`, `focus <direction>` and `home` (`NineKeysTests.whatHasNoKeyIsInTheMenu` keeps the list).

| # | Row | Shortcut | Command | From | Notes |
|---|---|---|---|---|---|
| | *state lines, if any, and a separator* | | | | see [States](#states) |
| 1 | Arrange Windows | | `arrange` | shipped | the first command (Q29, point 2): it has no key in either map, ⌃⌥A is never bound again (`docs/KEYBOARD.md`), so it is run from here; and arranging is what a newcomer came for |
| 2 | Windows ▸ | | | shipped | every open window; a click brings it to the front and into view |
| 3 | Show Everything | ⌃⌥Space | `show-all` | shipped | ✓ when that is the view and no window fills it. |
| 4 | Frame Focused Window | ⌃⌥↩ | `zoom` | shipped | ✓ when it is framed, or floats and fills the view; choosing it again takes that back, as the key does |
| 5 | Go to… | ⌃⌥G | `find` | F27 | |
| 6 | Saved Views ▸ | | | shipped, F10 | |
| 7 | View ▸ | | | | the rest of what moves the view, and what holds it |
| | *separator* | | | | Every row of this group is about the focused window or its app; all greyed out when there is none. Titles stay whole ("Float Focused Window"): a command has one title, in the menu, the shortcuts panel, the guide and read alone by VoiceOver |
| 8 | Dock Focused Window ▸ | | | shipped | |
| 9 | Float Focused Window | ⌃⌥F | `float` | shipped | greyed out when it floats already |
| 10 | Focused Window ▸ | | | | |
| | *separator* | | | | |
| 11 | Undo Dock | ⌃⌥Z | `undo` | shipped | names the step it takes back; "Undo" greyed out when there is none |
| 12 | Redo Dock | ⌃⌥⇧Z | `redo` | shipped | |
| 13 | Float All Windows | ⌃⌥⇧F | `float-all` | shipped | |
| 14 | Arrangement ▸ | | | | |
| | *separator* | | | | |
| 15 | Settings… | ⌃⌥, | `settings-window` | shipped | in every state, see below |
| 16 | Help ▸ | | | F10, F13 | in every state |
| | *separator* | | | | |
| 17 | Pause Arbor | ⌃⌥⎋ | `toggle-pause` | shipped | holding ⌥: **Pause for an Hour** (`pause 60`) |
| 18 | Quit Arbor | ⌘Q | | shipped | always last |

## Submenus

A separator is written `|`. Rows show their shortcuts here as at the top level.

**Saved Views ▸** (6)
- heading *Go To*, then one row per saved view, named in words: `View 1: Safari and Mail` ⌃⌥1 (✓ when that is the view). No heading and no
  rows when nothing is saved.
- heading *Save This View As*, then `View 1` … `View 9` ⌃⌥⇧1 …, a taken number reading `View 1 (replace)`.
- separator, `Name This Space…` ⌃⌥N (F20); named spaces are listed under *Go To*, after the numbers.

**Windows ▸** (2): one row for every open window, on every display, whatever keeps it out of sight. Decided by the product owner, 2026-10-15
(`collab/QUESTIONS.md`, Q29, point 8).
- A row reads `Safari: Start Page`, after the app's icon: the app's name (cut at 30 characters), then the window's title, cut at 50 with `…`; more of
  a title that was cut is in the row's tooltip. The name alone where the window has no title.
- **In the order of use, not by app**: the window with the keyboard first, ticked, as in an app's own Window menu; then those that have had it,
  the latest first; then the rest as they are laid out. Windows of apps Arbor does not arrange come after the others, by app.
- **A mark in words at the right end, grey, for what cannot be seen just now**, and nothing for what can: `out of view` (docked outside the view, too
  small to show, behind the window its tab group shows, floating while the Desktop is out of view or with most of it beyond the edges of all displays, sent
  away by `summon`), and macOS's own words for what macOS did: `minimized`, `hidden`, `full screen`, `another Space`; not for the window being typed
  in, which is what is seen. No display's name.
- **A click** runs `reveal` for that window, the road Go to… takes: it ends in front, with the keyboard, and whole. A floating window that hangs over an edge of the
  screen is moved the least that brings all of it in, on the display it belongs to. Moved, never sized: of one larger than its display the corner with the
  title bar comes in. One that lies across two displays, which show all of it between them, is let be.
  (So it is for `reveal`, `find` and Go to… too.) One that Arbor does not arrange is shown where it is.
- No limit: thirty windows are 730 points, and macOS scrolls a submenu by itself. With nothing open: `No Open Windows`, grey.
- Only while Arbor runs. While the view is held every row is grey, as all that would move it.
- Titles are for the person at the Mac, here as in Go to…: they are in no log, no trace and not in `state`. `menu`, which a person asks for themselves,
  prints them as `find` does: whoever passes its output on passes titles on.

**View ▸** (7): `Show the Desktop` ⌃⌥D (✓ when that is the view; the same title in the shortcuts panel; the way to see everything that floats), `Step Out` ⌃⌥↑, `Step In` ⌃⌥↓, `Back` ⌃⌥[, `Forward` ⌃⌥] | `Show Minimap` ⌃⌥M (F26; ✓ while one that was asked for is up; choosing it
again puts it away, as the key does) | `Hold This View` ✓, `Hold Still` ✓ (F58; with the reason as a remark when Arbor began it by itself). Whoever is
about to share a screen looks under View; once the view is held, the line that says so and `Release` are the first two rows of the menu.

**Dock Focused Window ▸** (8): `Left` ⌃⌥⌘←, `Right` ⌃⌥⌘→, `Top` ⌃⌥⌘↑, `Bottom` ⌃⌥⌘↓ | `Carry…` ⌃⌥⌘Space (F59) | with a second display,
`Move to Next Display` (F22).

**Focused Window ▸** (10): `Keep This Window in View` ✓ (`pin`, F49. No app's name: it pins one window; the app is what a rule is for) |
`Don’t Arrange “Zoom”` (`exclude`), `Shortcuts Off in “Zoom”` ✓ (`pass-through`, F41) | heading *Tab Group* (F04; neither heading nor rows while
`tabsEnabled` is off): `Next Tab` ⌃⌥⇥, `Previous Tab` ⌃⌥⇧⇥, `Move Tab Left`, `Move Tab Right`, `Take Window Out of Tab Group`, and, where there was a
submenu of a submenu, up to four plain rows: `Make a Tab Group With the Window to the Left`, `… to the Right`, `… Above`, `… Below`, each shown only
where there is such a neighbour (decided by the product owner, 2026-10-15; built with the tabs).

**Arrangement ▸** (14): `Grow` ⌃⌥⌘=, `Shrink` ⌃⌥⌘-, `Balance Sizes` ⌃⌥⌘0 | `Rotate Group` ⌃⌥R, `Mirror Group` ⌃⌥⇧R | heading *Arrange As* and the styles
of F29, the one in use ticked | `Lay Out Again` (`relayout`) | `Dock New Windows` ✓ (`toggle-auto-dock`, F23) | heading *Presets* (F21, F54): one row
per preset, by name, then `Save This Arrangement…`, `Copy Arrangement as Text` | heading *Arrange Again* (`include`) and the apps that are not
arranged, by name; neither heading nor rows when every app is arranged. Last, because it grows.

**Help ▸** (16): `Keyboard Shortcuts…` ⌃⌥⇧/ (`show-shortcuts`, F43; where Mac apps have it; greyed out while Arbor is not running), `Welcome…`,
`Check Setup…` | `Settings File…`, `Reload Settings`, `Show Log` | `Check for Updates…` (F13), `About Arbor` (which shows the version, from `BuildInfo`; no
version line in the menu). `Open at Login` ✓ (macOS's own words) lives in the settings window.

## States

A state is **one row that can be chosen: a sentence in plain words, and after " · " the command that ends it**, in the manner of the
lines on screen. It is what a person opened the menu to find out, and macOS draws a line of text at a contrast of 1.86 to 1
(measured in a picture from a hosted Mac; decided by the product owner, 2026-10-15). Only news that no command ends is a line of text:
state 2, state 8, and what comes under the row of a permission that was taken away.

States are shown first in the menu, above Arrange Windows, with a separator under them. When several hold, the first two in this order
are shown: while Arbor runs that is two rows, which rule 3 counts on. **The topmost state's way out is never greyed out.** One below it may
wait for it: with the view held and a mistake in the file, Release is at full strength and the file's row, which would open a window over
what is being shown (F58), follows it, one choice away; with a mistake in the file and the shortcuts off in this app, the file's row is at
full strength, and Turn On, which would change a setting, follows once the file is mended.

The first row under the icon can thus be chosen. Whoever presses on the icon, lets the pointer drift down some twenty points with the button
held and lets go has chosen it, as in every menu of macOS whose first row can be chosen; a plain click does not do that. Known and
accepted: the one place where it could hurt is Release on a shared screen.

| # | State | Row | About it | What else changes |
|---|---|---|---|---|
| 1 | No Accessibility permission (never given, or taken away: F63) | `Arbor needs Accessibility permission · Check Setup…`, one row; taken away: `Arbor’s Accessibility permission was taken away · Check Setup…`, and under it, as text, how many windows were out of view and that they come back with it | It opens Check Setup, not System Settings: with a new build over an old grant the switch there looks on, and only Check Setup says to switch Arbor off and on again in the list | nothing else but `Settings…`, **Help ▸** and `Quit Arbor` |
| 2 | Starting | `Arbor is starting…` | | as above |
| 3 | Paused | `Arbor is paused · Resume` ⌃⌥⎋, one row; begun for an app: `Arbor is paused for “Game” · Resume`; timed: `… until 14:30 · Resume` | That it leaves windows and shortcuts alone is the row's tooltip; what the pause did is said by the line on screen at the pause | nothing else but `Settings…`, **Help ▸** and `Quit Arbor` |
| 4 | The view is held (F58) | `The view is held · Release`, with the key that releases; `The view is held: nothing is in it · Release` | That nothing moves the view is the tooltip | rows that would move the view are greyed out, and those that open a window over what is being shown (F58), state 6's among them |
| 5 | Holding still (F58) | `Holding still while the camera is on · Release` (or the microphone, or “Keynote” is open); begun by hand: `Holding still · Release` | That the view moves only when asked is the tooltip | |
| 6 | `settings.json` cannot be read | `Settings.json has a mistake: line 3, column 3 · Settings File…` | Before state 7, which only a change of settings ends | **every row that would change a setting is greyed out** (Don’t Arrange “App”, Shortcuts Off in “App”, Dock New Windows, Arrange Again’s apps, state 7’s row): Arbor does not write to a file it cannot read, and they would fail |
| 7 | Shortcuts off in this app (F41) | `Shortcuts are off in “Emacs” · Turn On` | It does what the ticked `Shortcuts Off in “Emacs”` in **Focused Window ▸** does: in this state no key helps | shortcuts are shown on no row but Pause Arbor |
| 8 | A place is kept, or an arrangement was set aside | one line, as in `status` | | |

macOS's own tiling being on is not a state either (Q23): nobody is reminded of it by the menu or the icon. **Help ▸** `Check Setup…` has the
offer whenever they want it.

An update is not a state: `Update Available…` takes the place of `Check for Updates…`, and **Help ▸** gets a dot. Nothing opens by itself.

The icon says the same with the menu closed: dimmed when paused, a lock when the view is held, filled in when holding still, an
exclamation mark when permission is missing.

## For whoever builds it

- The order above belongs in the headless menu model (F10), pinned by a test that lists the titles in this order: then a
  feature that appends a row in the wrong place fails on Linux.
- A row too many at the top level fails on Linux too (`MenuHeightTests`, rule 3). Do not raise the number: find the row's submenu.
- A feature contributes rows to the model; only `StatusMenu` turns them into `NSMenuItem`s.
- VoiceOver reads headings and ticks; a state line must make sense read alone.
