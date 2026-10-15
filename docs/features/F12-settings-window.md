# F12: Settings window

Status: done (built on a Mac; the window has not been looked at yet: `SettingsWindowPictureTests` draws it off screen, `scripts/mac-shell/shots-F12.sh` clicks through it)
Depends on: F06, F11

## Summary

A small native settings window for the options in `settings.json`: gap,
tile threshold, drop bands, tabs, excluded apps, rules, key bindings, launch at login.

## Behaviour

- Opened from the menu (Settings…) and with ⌃⌥, (Arbor is never the active app, so ⌘, cannot reach it; docs/KEYBOARD.md).
- Every change writes `settings.json` and applies immediately (`apply(settings:)`).
- Key bindings can be recorded by pressing them; conflicts are flagged.
- Rules: add/remove/reorder, app picker from running apps.
- Editing the file by hand still works; the window reloads when the file changes.

## Acceptance criteria

1. Changes round-trip through `settings.json` without losing unknown keys.
2. Invalid values are rejected in the UI with a reason.
3. (was "Manual"; board, section 5) On a hosted Mac, `shots-F12.sh`: every control of every pane is worked with real clicks and keys and the setting is read back; `axtool` finds a role, a label and a value on each. Pictures of every pane in light and dark are judged against `docs/POLISH.md`.
4. `make check` passes.

## Shipped

First half, everything the window will be a view of:

- `SettingsSchema` (ArborCore): one entry per key of `Settings` with its section, label, help, kind (switch, number
  with range, step and unit, choice, checked text, list) and type-erased access. A test fails for a key
  without an entry, and `docs/SETTINGS.md` is generated from the schema and kept current by a test.
- Commands: `set <key> <value…>`, `get <key>`, `settings` (`--markdown` prints the document), `reset <key>`, `reset all`
  (keeps shortcuts, rules and excluded apps), `reset everything`; `bind <shortcut> <command…>`, `unbind <shortcut>`;
  `rule add|change|remove|move`. Keys ignore case, the beginning of a key is not accepted, and a typo gets
  "did you mean". Everything is checked when the text is parsed, so a bad `set` inside `bindings` is reported too. A
  change applies at once and is saved; a refused one changes nothing (criterion 2). They work before
  Accessibility is granted.
- Hand-edited files: a value of the wrong type costs only its own key, a number outside its range moves to the
  nearest end, other unusable values go back to the default; one log line each, also shown by `settings`.
- Live reload: Arbor watches settings.json and its folder and applies an edit 0.3 s after the last save, if it says
  anything new (so its own writes are ignored). A file that is not a JSON object keeps the settings in use
  (`reload-settings` used to fall back to the defaults and say "settings reloaded"), is logged once, and
  nothing is saved over it until it is mended or `reset everything` replaces it.
- Saving (with B1, criterion 1): a command writes only what it changed into the text of settings.json. Unknown keys, the
  order and spacing, the spelling of numbers, and the values and entries Arbor could not use all stay; what is added is
  laid out like what is there. One rule for every command that changes settings, `exclude` and `include` too: **the
  settings in use are what the file says**. The command first takes the file in as it is now and is refused while it
  cannot be read (the reply has the line and column); then it saves, then it applies. A change that cannot be saved
  (a read-only file) is refused as a whole. `reset everything` on a file that cannot be read keeps it as
  settings.unreadable.json. `set` and `reset` of a key whose value in the file could not be used put the file right
  even if the value in use stays the same. A list or object Arbor could not read is not written over.
- A gap too large for its space no longer produces the null rectangle (`"gap": 5000` and `arborctl ascii` crashed Arbor).

Second half, the window and what the product owner asked of the commands:

- `settings-window [pane]`, ⌃⌥, and Settings… in the menu (also while Arbor is paused or waits for Accessibility) open a native window: a
  sidebar with a search field (it finds settings by label, help and key, advanced ones too, and shortcuts by command and keys), the schema's sections that have something to show, then Shortcuts and Rules.
- A section's pane is drawn from the schema: a switch, a slider with a field and the unit, a menu, a checked text field; label and help
  from the entry; `advanced` entries behind a disclosure (at once where a section has no others); `hidden` ones nowhere. Restore
  Defaults per section. A new setting needs an entry and no code in the window.
- Every change is a command (criterion 2: a refusal stands under the control it was made with, behind a red mark, and the control falls back to
  the real value). A slider changes the setting when it is let go of. `arborctl set`, hand edits of the file and the menu show in the
  open window at once.
- Shortcuts: every default in its usual order with what runs it now, then the user's own; click and press to record (Arbor lets go of
  its hot keys meanwhile, Escape cancels); keys another command has are flagged and taken only on request; remove, restore,
  Restore All; a box for a shortcut to any command; a word of caution on a shortcut that takes keys from every app.
- Rules: add from the running apps; what it does, edge, neighbour and title on the line; reorder, remove.
- Apps: a section of the schema that holds the lists of apps (`.apps(…)`: Don't arrange, Apps that keep ⌃⌥, and behind Advanced Pause for). A list of apps is
  a kind of line like a switch or a slider: its label and help, the apps on it, and a menu of running apps to add from. `set <list> add <app>` and
  `set <list> remove <app>` are the commands behind it (the list by key or by label), so a new list of apps needs an entry and nothing else. Restore Defaults leaves lists alone, as `reset all`
  does. A list without an editor is a line that says how long it is, with Open the File.
- `set <key> toggle` flips a switch, for a shortcut that turns something on and off.
- What cannot be taken back with another click asks first (Restore All Shortcuts…, Replace It with the Defaults…), and a `reset` that empties a list or everything keeps
  a copy of the file, settings.before-reset.json, which the reply names.
- A settings.json that cannot be read is said in a banner above everything, with Open the File and Replace It with the Defaults (the old
  file is kept); values that could not be used are listed in a milder one. Arbor also beeps when the file breaks, and says so first
  in `settings` and at the end of `status`.
- Open at Login in General, in a copy of Arbor that can be opened at login: F13's `launch-at-login on|off` behind it, macOS asked for the state each time, and
  where to go in System Settings if it was switched off there. The foot of the sidebar has F13's version text.
- The table of shortcuts and the recorder follow the keyboard layout (F44): a pressed key is called what it types (`y` for the key left of X in Germany),
  labels are the layout's (⌃⌥Ü), and a clash is told by the key, not by its name. Arbor holds no shortcut while one is recorded.
- Commands: a third level `hidden`; `settings --json`; `bind ⌃⌥X …` is read; `bind` warns about ⌘Q and macOS's own chords; `unbind` says
  what still runs the command; `reset all` says what it kept; rules ignore the case of bundle ids and `rule add Safari …` takes the
  name of an app with a window open; "did you mean" also searches labels (`set shortcuts off`); a choice's values are explained
  where they are typed.

- 2026-10-15 (Q27): `settings.json` holds only what differs from the defaults, and `"format": 2` (`ArborCore/SettingsFileFormat.swift`). A first launch writes no default; `set` writes one key; `reset`, and `set` to the very default, take the key out. A file from before the mark is stripped once, at a launch, of what equals the defaults of its day (a frozen table), with a copy kept. `SettingsFileFormatTests`, `SettingsFileUpgradeTests`; on a Mac `check-F12.sh`.

Round 2, what reading, extremes, bad days and the first pictures from a hosted Mac found. Linux proves the model and type-checks the three SwiftUI files
against stand-ins (`make typecheck-mac`); `scripts/mac-shell/shots-F12.sh` clicks through the window on a hosted Mac, unattended, and brings back every
pane in both looks for somebody to look at:

- Nothing typed that can be used is lost. What is typed into a field is kept by the model (`drafts`), not by the view, and handed over on Return, when the field loses the
  keyboard, and before anything that takes the field away or acts on what it is about: another pane, a search, a rule's buttons and menus, the
  window closing, Advanced closing over it. A title typed for a rule is dropped if another rule has come to its place. The slider, Restore Defaults and
  replacing the file overtake what stands in a field. What cannot be used is refused under its field, or, if the field has gone with its pane, on the line on screen.
- A field follows its setting. On a hosted Mac a field that had the keyboard said 40 while its slider stood at 86, and went on saying so after `set gap 20`: it had
  reported what it was given to show, and that was taken for typing. What a field would show anyway is no typing now, and a change from outside drops
  what stood half typed in that setting's field, so closing the window cannot undo it.
- Rows stand in a chosen order, `SettingsSchema.order`: what is looked for first comes first, what belongs together stands together. Entries are
  still added at the end of their lists and never moved; a key the order does not name comes last. `settings` and docs/SETTINGS.md follow it.
- Help never explains a choice by its values, hidden settings included. The choices of Gaps between windows say what they do ("Cannot be dragged", not
  "Only gaps").
- Sliders land on multiples of the step (1, 10, 20, not 1, 11, 21). `shrinkOutOfView` is hidden.
- What is behind Advanced looks like the rows above it: lines between the rows, their room, and a list of apps at the left, where pictures showed it a
  hundred points to the right.
- Small ones: skipped entries of `displays` are told by `doctor` and the window's banner (never by the log: what an entry matches can be a person's name); an app a
  hand-edited list names twice shows once, an empty entry can be taken off; "did you mean" finds a label however it is spelt (`smallest-usable-width`).
- `SettingsExtremesTests`: every setting at the ends of what the schema allows, alone, all at once and in the middle of a drag, a motion and a peek, by `set`, by a
  file and by the window's model, followed by an ordinary day; junk from beyond the ends gets in by no way. It knows no setting by name. `SettingsWindowOnABadDayTests`: every control
  during a pause, before the permission, over a file that cannot be read, where nothing can be saved, with no display.
- `SettingsWindowAmongWindowsTests`: looking around the window moves nothing and asks for nobody's keyboard; a slider that is let go of, a field handed over and every other
  control move a window once at most, to where it ends up; a floating window as wide as the Desktop follows it, once.
- `shots-F12.sh` takes its pictures first, in both looks: every pane from top to bottom, the Calls pane too, and again with Advanced open, which nobody had
  seen. Five of its checks were red through faults of its own on a display 1024 points wide, and are mended: with a wider gap every column became a tile
  (it asks for a smaller usable width now), it clicked where a window had been while it was a tile, and Accessibility names no app in front there.

Round 3, what two judges found too faint in round 2's pictures, with a ruler (`scripts/polish/stills.py`):

- What is wrong is said in the ink everything else is in, behind a mark in colour (`SettingsLook`, as on the panels: `PanelLook`). Warnings in macOS's orange came to
  2.0 to 1 in the light look, with two buttons that depended on reading them, refusals in its red to 3.1 and 3.9; 4.5 is asked. The marks are a triangle and a
  circle, for whoever cannot tell the colours apart, in colours of Arbor's that stand out from a card by 4.0 to 7.2 to 1 by reckoning.
- The two banners stand on the window's own ground, with a line under them, and are told apart by their marks: the circle for a file that cannot be read, the triangle for the milder one. macOS's buttons let through what they lie on: over Arbor's tint their words came to 3.8 to 1
  in the dark look, on the plain ground to 4.95.
- A field's label is no longer the faint word inside it: Search has a magnifying glass before it, a rule's title field the words "Only windows whose title contains".
- A setting that does nothing while a switch above it is off is dimmed and takes no clicks (`SettingsSchema.needs`, by key, and a switch may need another in its turn). Blue
  switches stood under "Trackpad and mouse gestures", off, and did nothing. So it is in Gestures, two levels deep (that switch, Pinch to zoom, Zoom with ⌃⌥ and scroll), and
  in Menu Bar. Behind Advanced and among what a search has found, where the switch may be out of sight, the row says which it waits for: of several the outermost.
  What stood typed in a field when its switch went off is handed over all the same.
- The card behind Advanced was nine points deeper at its foot than the one above it, which made General scroll for seven.
- `SettingsWindowPictureTests` measures on the real views, on CI's Mac: what is in colour is a mark and no line of words, it stands out by 3 to 1, the words after it by 4.5, the
  ground is not tinted; the rows under the switch lose their strong ink, in both looks; the two cards are as deep at the foot. Its ways of finding a mark and a card's foot were
  tried on round 2's 95 pictures: the first names the eight with words in colour and no other, the second says 13 and 20. Not measured: the glass, the rule's label, and
  where the sentence about the switch stands.

## Not shipped

- What else hangs on a switch, going by the help: the ring's width, colour and radius on Focus ring, the share of colour on Tiles in their app's color, and the like in Windows. Not in `needs` yet:
  each wants its proof that it does nothing meanwhile.
- The welcome window still says a failure in macOS's red (`UI/Onboarding.swift`).
- Round 3 has been seen by nobody yet: Linux type-checks it, CI's Mac measures it off screen. The next pictures from a hosted Mac are its proof.
- No picture of the window with Increase Contrast, at two pixels to the point, or on glass (hosted Macs come with Reduce Transparency on).
- Criterion 3 as far as pictures go: the panes have been looked at in light and dark, in pictures `shots-F12.sh` took on hosted Macs. Translucency cannot be
  judged there, and nobody has sat in front of the window.
- Modifier keys and a colour are typed as text ("ctrl+opt", "accent").
- The README's long table of settings repeats docs/SETTINGS.md by hand, and falls behind it. It should give way to a paragraph that points there.
- `doctor`'s row and the menu's state line for a broken file wait for F10.
- No editor for `displays`: a line with its length and Open the File.
- `arborctl --json` exits 0 after a refusal, and refusals go to stdout (with F50).
- `excludedBundleIDs` is read as a whole: one entry that is not text costs the list (and `exclude` then refuses to write
  over it). `rules` and `bindings` skip bad entries one by one; the list of apps could too.
