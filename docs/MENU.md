# The menu

The one place where the order, the grouping and the titles of Arbor's menu are decided, as [KEYBOARD.md](KEYBOARD.md) is for shortcuts
and [GLOSSARY.md](GLOSSARY.md) for words. **If your feature adds a menu item, find its row here; if it has none, ask for one before you
build it.**

Written by the executor swarm, 2026-10-14 (product owner); for the documenter to review.

## What the menu is for

Arbor has no window and no Dock icon. The menu is the only part of it a newcomer can look at, so it has three jobs, in this order:

1. **The way back.** Someone whose windows have just left the view opens this menu. What they need is the first command in it.
2. **The vocabulary.** Read from the top, it teaches the model: show everything, frame, step out and in, dock, float. Each row shows its
   shortcut, so the menu is also where shortcuts are learned.
3. **What Arbor is doing that is out of the ordinary**, and the command that ends it: paused, holding, waiting for permission.

It is not the settings window, and not a list of everything Arbor can do: `arborctl help` and Keyboard Shortcuts… are those.

## Rules

1. **The ways back are always at the top level, always in the same place, never greyed out while Arbor runs**: Show Everything is the first
   command, Float All Windows is in Arrangement, Pause Arbor and Quit Arbor are the last two rows.
2. **A state line comes first, and the command that ends the state comes right under it.** At most two states are shown; the order of
   precedence is in [States](#states).
3. **The top level is full.** With everything below shipped it has 29 rows and four headings, which just fits a 13-inch display. A new
   feature goes into a submenu, or takes the place of a row it makes unnecessary. One top-level row per feature at the very most.
4. **Greyed out, not hidden.** A row that cannot act now keeps its place, so that hands and eyes find it where it was. Hidden only when
   the thing it is about does not exist: a second display, an app that is not arranged, an update, a feature switched off in settings.
5. **Titles**: a verb first, Title Case, words from the glossary. `…` only when a window or a panel opens and asks for more. An app's name
   in curly quotes, never a bundle id, never a window's title. A state that is on or off is a tick on one row, not two rows.
6. **Shortcuts shown are the ones in effect** (rebound, moved by the keyboard layout, off in this app), from the same list the hot keys
   are registered from. A row whose shortcut is off shows none.
7. **A command from the menu is answered as a shortcut is**: a line on screen when it failed or when nothing visible changed (F43).
8. Commands act where shortcuts act: on the focused window and its display (F56).

## While Arbor runs

`▸` opens a submenu, `✓` is a tick when on. "Shipped" means on `swarm/trunk` when this was written.

| # | Row | Shortcut | Command | From | Notes |
|---|---|---|---|---|---|
| | *state lines, if any* | | | | see [States](#states) |
| | **View** | | | | heading |
| 1 | Show Everything | ⌃⌥Space | `show-all` | shipped | ✓ when that is the view. With several displays, holding ⌥ turns it into **Show Everything on All Displays** (⌃⌥0, `home`) |
| 2 | Show the Desktop | ⌃⌥D | `desktop` | shipped | ✓ when that is the view. The same title in the shortcuts panel |
| 3 | Frame Focused Window | ⌃⌥↩ | `zoom` | shipped | ✓ when it is framed; choosing it again un-frames, as the key does |
| 4 | Step Out | ⌃⌥↑ | `out` | shipped | |
| 5 | Step In | ⌃⌥↓ | `in` | shipped | |
| 6 | Back | ⌃⌥[ | `back` | shipped | |
| 7 | Forward | ⌃⌥] | `forward` | shipped | |
| 8 | Go to… | ⌃⌥G | `find` | F27 | |
| 9 | Saved Views ▸ | | | shipped, F10 | see [Submenus](#submenus) |
| 10 | Show Minimap | ⌃⌥M | `minimap` | F26 | ✓ while one that was asked for is up; choosing it again puts it away, as the key does |
| | **Focused Window** | | | | heading. Every row is about the focused window or its app; all greyed out when there is none. Titles stay whole ("Float Focused Window"): a command has one title, in the menu, the shortcuts panel, the guide and read alone by VoiceOver |
| 11 | Dock Focused Window ▸ | | | shipped | |
| 12 | Float Focused Window | ⌃⌥F | `float` | shipped | greyed out when it floats already |
| 13 | Keep This Window in View | | `pin` | F49 | ✓. No app's name: it pins one window; the app is what a rule is for. (Decided 2026-10-14; until the menu follows it reads Keep “Zoom” in View) |
| 14 | Tab Group ▸ | | | F04 | hidden while `tabsEnabled` is off |
| 15 | Don’t Arrange “Zoom” | | `exclude` | shipped | |
| 16 | Shortcuts Off in “Zoom” | | `pass-through` | F41 | ✓ |
| | **Arrangement** | | | | heading |
| 17 | Undo Dock | ⌃⌥Z | `undo` | shipped | names the step it takes back; "Undo" greyed out when there is none |
| 18 | Redo Dock | ⌃⌥⇧Z | `redo` | shipped | |
| 19 | Arrange Windows | ⌃⌥A | `arrange` | shipped | |
| 20 | Float All Windows | ⌃⌥⇧F | `float-all` | shipped | |
| 21 | Adjust ▸ | | | F22, F29 | |
| 22 | Presets ▸ | | | F21, F54 | |
| 23 | Dock New Windows | | `toggle-auto-dock` | F23 | ✓ |
| 24 | Arrange Again ▸ | | `include` | shipped | hidden when every app is arranged. Lists apps by name |
| | **Arbor** | | | | heading |
| 25 | Hold This View | | `hold` | F58 | ✓ |
| 26 | Hold Still | | `hold still` | F58 | ✓, with the reason as a remark when Arbor began it by itself |
| 27 | Settings… | ⌃⌥, | `settings-window` | shipped | in every state, see below |
| 28 | Keyboard Shortcuts… | ⌃⌥⇧/ | `show-shortcuts` | F43 | |
| 29 | Help ▸ | | | F10, F13 | |
| | *separator* | | | | |
| 30 | Pause Arbor | ⌃⌥⎋ | `toggle-pause` | shipped | holding ⌥: **Pause for an Hour** (`pause 60`) |
| 31 | Quit Arbor | ⌘Q | | shipped | always last |

Rows 14 and 24 are hidden on day one, which is how 31 numbers make 29 rows.

## Submenus

**Saved Views ▸** (9)
- heading *Go To*, then one row per saved view, named in words: `View 1: Safari and Mail` ⌃⌥1 (✓ when that is the view). No heading and no
  rows when nothing is saved.
- heading *Save This View As*, then `View 1` … `View 9` ⌃⌥⇧1 …, a taken number reading `View 1 (replace)`.
- separator, `Name This Space…` ⌃⌥N (F20); named spaces are listed under *Go To*, after the numbers.

**Dock Focused Window ▸** (11): `Left` ⌃⌥⌘←, `Right` ⌃⌥⌘→, `Top` ⌃⌥⌘↑, `Bottom` ⌃⌥⌘↓; separator; `Carry…` ⌃⌥⌘Space (F59); with a second display,
separator and `Move to Next Display` (F22).

**Tab Group ▸** (14): `Next Tab` ⌃⌥⇥, `Previous Tab` ⌃⌥⇧⇥; separator; `Move Tab Left`, `Move Tab Right`; separator; `Make a Tab Group With ▸`
(`Left`, `Right`, `Top`, `Bottom`), `Take Window Out of Tab Group`.

**Adjust ▸** (21): `Grow` ⌃⌥⌘=, `Shrink` ⌃⌥⌘-, `Balance Sizes` ⌃⌥⌘0; separator; `Rotate Group` ⌃⌥R, `Mirror Group` ⌃⌥⇧R; separator; heading
*Arrange As* and the styles of F29, the one in use ticked; separator; `Lay Out Again` (`relayout`).

**Presets ▸** (22): one row per preset, by name; separator; `Save This Arrangement…`, `Copy Arrangement as Text` (F54).

**Help ▸** (29): `Welcome…`, `Check Setup…`; separator; `Settings File…`, `Reload Settings`, `Show Log`; separator; `Check for Updates…` (F13),
`About Arbor` (which shows the version, from `BuildInfo`; no version line in the menu). `Open at Login` ✓ (macOS's own words) lives in the settings window.

## States

A state is a line of plain words, greyed out as text is, followed by the command that ends it. Shown first in the menu, above **View**,
with a separator under them. When several hold, the first two in this order are shown.

| # | State | Line | Then | What else changes |
|---|---|---|---|---|
| 1 | No Accessibility permission (never given, or taken away: F63) | `Arbor needs Accessibility permission`, and if windows were out of view when it went, how many and that they come back with it | `Check Setup…` | nothing else but `Settings…`, **Help ▸** and `Quit Arbor` |
| 2 | Starting | `Arbor is starting…` | | as above |
| 3 | Paused | `Arbor is paused: it leaves windows and shortcuts alone`; begun for an app: `Arbor is paused for “Game”`; timed: `… until 14:30` | `Resume` ⌃⌥⎋ | nothing else but `Settings…`, **Help ▸** and `Quit Arbor` |
| 4 | The view is held (F58) | `The view is held: nothing moves it` | `Release` | rows that would move the view are greyed out |
| 5 | Holding still (F58) | `Holding still while the camera is on` (or the microphone, or “Keynote” is open) | `Release` when begun by hand | |
| 6 | Shortcuts off in this app (F41) | `Shortcuts are off in “Emacs”` | row 16 carries the tick | shortcuts are shown on no row but Pause Arbor |
| 7 | `settings.json` cannot be read | `Settings.json has a mistake: line 3` | `Settings File…` | |
| 8 | A place is kept, or an arrangement was set aside | one line, as in `status` | | |

An update is not a state: `Update Available…` takes the place of `Check for Updates…`, and **Help ▸** gets a dot. Nothing opens by itself.

The icon says the same with the menu closed: dimmed when paused, a lock when the view is held, filled in when holding still, an
exclamation mark when permission is missing.

## For whoever builds it

- The order above belongs in the headless menu model (F10), pinned by a test that lists the titles in this order: then a
  feature that appends a row in the wrong place fails on Linux.
- A feature contributes rows to the model; only `StatusMenu` turns them into `NSMenuItem`s.
- VoiceOver reads headings and ticks; a state line must make sense read alone.
