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
- Every change is a command (criterion 2: a refusal stands in red under the control it was made with, and the control falls back to
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

## Not shipped

- Criterion 3: nobody has seen the window. It compiles and its tests pass on a Mac; the script that clicks through it and takes its
  pictures in light and dark has not been run.
- `doctor`'s row and the menu's state line for a broken file wait for F10.
- The Shortcuts pane names commands by their text (`show-all`); F43's `Command.title` gives them words when it lands.
- No editor for `displays`: a line with its length and Open the File.
- `arborctl --json` exits 0 after a refusal, and refusals go to stdout (with F50).
- `excludedBundleIDs` is read as a whole: one entry that is not text costs the list (and `exclude` then refuses to write
  over it). `rules` and `bindings` skip bad entries one by one; the list of apps could too.
