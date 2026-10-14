# F06: Key bindings in settings.json

Status: done (verified headlessly; default shortcuts fired on a real Mac, 2026-10-14; shortcuts from `bindings` pending the manual check in docs/TESTING.md)
Depends on: F01

## Summary

Let users change, add and remove global shortcuts by editing `settings.json`,
using the same command text as `arborctl`.

## Behaviour

`settings.json` gains an optional `bindings` object mapping a chord to a command:

```json
"bindings": {
  "ctrl+opt+space": "show-all",
  "ctrl+opt+cmd+h": "dock left",
  "ctrl+opt+1": "view 1",
  "ctrl+opt+z": null
}
```

- Keys are chords: modifiers (`ctrl`/`control`/`⌃`, `opt`/`option`/`alt`/`⌥`,
  `cmd`/`command`/`⌘`, `shift`/`⇧`) and one key (letters, digits, `space`,
  `return`/`enter`, `left`, `right`, `up`, `down`, `[`, `]`, `-`, `=`, `,`, `.`,
  `/`, `;`, `'`, `` ` ``, `\`, `tab`, `escape`, `delete`, `f1`–`f12`),
  joined by `+`, case-insensitive.
- Values are command text (`Command.parse`). `null` removes a default binding.
- User bindings are merged over `KeyBindings.defaults`: same chord replaces,
  `null` removes, new chords add.
- Invalid chords or commands are skipped and logged with the reason; they do
  not stop the rest from loading.
- `reload-settings` re-registers shortcuts.
- `arborctl bindings` (a new query command) prints the effective table, one
  `chord → command` per line, sorted by command text.

## Design notes

- Put chord parsing and formatting in a new pure file
  `Sources/ArborCore/KeyChord.swift` (key names ↔ virtual key codes, modifier
  sets), so it can be unit-tested. `KeyBinding` (ArborKit) can build on it.
- Add `bindings: [String: String?]` at the end of `Settings` (decoding a
  missing key gives `[:]`).
- `KeyBindings.effective(settings:) -> (bindings: [KeyBinding], problems: [String])`.
- `ArborApp` registers the effective bindings, and re-registers them after
  `reload-settings` (`Controller.loadSettings`/`apply(settings:)` is the hook;
  an `onSettingsApplied` callback works).
- Menu labels (`KeyBindings.label(for:)`) should reflect the effective bindings.

## Acceptance criteria

1. Parsing round-trips every default binding: `KeyChord(text: chord.text) == chord`.
2. Aliases and ordering are accepted (`opt+ctrl+Space` == `ctrl+opt+space`).
3. Invalid input (`ctrl+`, `hyper+x`, `ctrl+opt+notakey`, unknown command) is reported, not fatal.
4. Merging: replace, remove (`null`) and add all work; defaults are unchanged when `bindings` is absent.
5. An old `settings.json` without `bindings` still loads with all defaults.
6. `bindings` query command works through `Harness` / `arborctl`.
7. `make check` passes.

## Out of scope

A UI for editing bindings (F12).

## Shipped

- `KeyChord` (ArborCore): parses and formats chords. Modifier aliases including
  the glyphs, any order, any case, spaces ignored; every key in the list above,
  with its virtual key code (a test checks them against Carbon's `kVK_*`). The
  canonical text puts modifiers in menu order (`ctrl+opt+shift+cmd+key`); the
  menu label is the glyph form (`⌃⌥⇧⌘` + key).
- `Settings.bindings: [String: String?]`, decoded entry by entry: a value that is
  neither text nor null (a number, `false`) is set aside in
  `unreadableBindings` and reported, instead of making the whole settings file
  invalid as a wrong type does elsewhere.
- `KeyBindings.effective(settings:)`: same chord replaces, `null` removes, new
  chords add. Skipped with a reason: chords that do not parse, commands that do
  not parse, a second spelling of a chord already set, query commands (`state`,
  `bindings`…, which have nowhere to show their answer), chords without ctrl,
  opt or cmd other than f1–f12 (they would take the key away from typing), and
  values of the wrong type. The user's bindings come first in the result, so a
  menu item shows the user's own shortcut for its command.
- `ArborApp` registers the effective table at start and again after every
  `apply(settings:)` (`reload-settings`, `exclude`, `include`) through
  `Controller.onSettingsApplied`, logging the skipped entries. It skips the work
  when nothing changed and retries shortcuts that failed to register. Menu
  labels come from the shortcuts that registered, so none show when hotkeys are
  off.
- `bindings` query (`arborctl bindings`, help text): the effective table, one
  `chord → command` per line sorted by command text, then the skipped entries.

## Not shipped

- A UI for editing bindings (F12).
- Keys outside the list above (keypad, Home/End, Page Up/Down, F13 and up).
- Checked only headlessly: shortcuts that come from `bindings`, re-registering
  on reload, the menu labels after a change, and `arborctl bindings` over the
  real socket. The Harness tests cover the same parse and perform path; the
  manual check is in docs/TESTING.md. Seen on a real Mac (2026-10-14):
  the defaults ⌃⌥F and ⌃⌥⌘←
  registered with Carbon run their commands, and the menu shows the labels.
