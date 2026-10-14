# F43: Say what happened (a heads-up line and the shortcuts on screen)

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (feat/F43-heads-up); builds and passes on a Mac, not yet looked at
Depends on: F01, F06; sits well with F02
Size: medium

## Summary

Every command already answers in a sentence ("nothing is docked yet: drag a window to a screen edge", "saved view 2: Safari"), but only `arborctl` users ever read
it. Someone pressing keys gets silence, or since the product review a beep. The moments that decide whether a newcomer stays are exactly those: a key that
seems dead, windows that seem gone, a state that changed invisibly.

## Behaviour

**The line.** A small translucent capsule low on the display the command acted on, like the volume indicator: one line of text, fades after 1.5 s, never takes
focus or clicks, replaced at once by the next one. It shows the reply of a command that came from a **shortcut, a gesture or the menu** when:

- it **failed** (instead of the beep): "No space to the left", "Nothing to step into: Safari fills the view";
- it changed something **invisible**: saved a view, paused or resumed, switched auto-docking, excluded an app, undid or redid;
- it is a **teaching moment**, each at most three times ever (counted in `state.json`): the first times windows leave the view, "2 windows are out of view · ⌃⌥Space
  shows everything"; the first dock, "Docked. ⌃⌥↩ frames it"; the first time a tile appears, "Too small to show: click the tile to zoom in".

Setting `messages`: `"all"` (also every success), `"helpful"` (default: the three cases above), `"off"`. Commands from `arborctl` and URLs never show it. (The menu is answered on screen: decided by the product owner on #37. Reload Settings lives only in the menu, and the alternative is a bare beep.)

**The shortcuts on screen.** `show-shortcuts` (⌃⌥⇧/, that is ⌃⌥?) shows a panel with every shortcut in effect, grouped as in `docs/KEYBOARD.md` (Look, Arrange, Arbor
itself), with the user's own bindings in place of the defaults. Any key or click dismisses it. The menu has **Keyboard Shortcuts…**.

## Design notes

- `Command.title`: the human name of a command ("Show Everything", "Dock Left", "Save View 3") in ArborCore. The menu, this panel and the Go to… picker should all
  take their words from it, so that they cannot drift apart (`docs/GLOSSARY.md`).
- Replies are lower-case fragments for a terminal; capitalise the first letter and drop the `(n5)` for the capsule.
- `OverlayPresenter.showMessage(_ text: String, on: DisplayID)`, appended; `FakeOverlays.messages` records. Where a command came from is a parameter of a new
  `Controller.perform(_:from:)` (`.shortcut`, `.gesture`, `.menu`, `.script`), defaulting to `.script`.
- The counts for teaching moments belong with `PersistedState` (optional key, so old files load).
- Shortcut glyphs in messages come from `KeyBindings.label(for:in:)` on the bindings in effect, never hard-coded.

## Acceptance criteria

1. A failing command from a shortcut records its message on the right display; the same command from a script records none.
2. Each teaching message appears three times and never again, across restarts.
3. `messages: "off"` records nothing; `"all"` records every reply.
4. A rebound shortcut shows the user's keys in messages and in the panel; a removed one is left out of the sentence.
5. Window titles never appear.
6. Manual: the capsule is legible on light and dark wallpapers, does not steal focus, and does not appear in a full-screen Space of another app.

## Shipped / Not shipped

**Shipped** (2026-10-14): the line, the three levels of `messages`, the three teaching moments counted in `state.json`, `show-shortcuts` on
⌃⌥⇧/ and in the menu, `Command.title`, `Controller.perform(_:from:)`. Criteria 1 to 5 are covered by tests (`HeadsUpTests`, `CheatSheetTests`, `CommandTitleTests` in both test targets, and
`collab/scenarios/43-say-what-happened.sim`).

**Different from the text above**, each with its reason in `collab/QUESTIONS.md`:

- Teaching moments are read from what changed on the display, so a **drop**, a click on a tile and ⌘Tab teach as well as commands.
- The out-of-view hint uses the glossary's sentence ("Your other windows are out of view, not closed · ⌃⌥Space shows everything") and comes only when everything was in view before.
- The line stays 1.5 s **or longer**: 0.06 s a character, at most 6 s.
- The presenter method is `showHeadsUp(_ model: HeadsUpModel?, on:)`, which carries kind, text, hint, place and width, rather than `showMessage(_ text:on:)`.
- The panel's groups and order are read from `help`, which has the same three groups as `docs/KEYBOARD.md`.
- The panel has a fourth part, "Pointer and trackpad", for what is done without keys.
- `float-all` counts as an unseen change (no window moves); `undo` and `redo` will as soon as they are commands.

**Added after the product owner's review of #37**: a success that left the view, the arrangement, every window and the keyboard as they were is said, because it looks like a dead key; ⌃⌥↩ on a floating window says "Mail
floats · ⌃⌥⌘← docks it, then ⌃⌥↩ frames it"; apps are called by name, never by bundle id, and one that is excluded is "Arbor does not arrange Mail · Arrange Again in the menu"; landing by Arbor's own command in an app that keeps its own
⌃⌥ says "Shortcuts are off in Emacs · ⌘Tab leaves, ⌃⌥⎋ pauses", and the panel there lists everything under the heading "Off in Emacs, except ⌃⌥⎋"; which display a command chose is left to the line's place; "Resumed" shows where "Paused" did.

**Added once names, `summon` and `layout` were on the trunk**: `name` and `unname` are confirmed (nothing on the space shows a name); the name field and the welcome window are their own answer, as the panel of shortcuts is; a
window `summon` sent away is not what "out of view, not closed" is about; ⌃⌥N is "Name This Space" in the panel, and every command with a default shortcut must have a title somebody chose; the debug log gets the line without
the names of spaces, and no word of the reply to a command that changes settings.

**Added after bug bash 1**: Go to… is its own answer; one panel has the keyboard at a time; a hold takes away what was said before it, a held view's refusal is "The view is held · ⌃⌥⎋ releases it", and what holding still
turns away is said once per app and hold; a success that took something along ("…; 2 saved views are gone") is said at every level but `off`, before any hint, with "⌃⌥Z takes it back"; the end of a peek, an empty Desktop's tile and a
place that automatic docking tries and takes back teach nothing; the hint about tiles names ⌃⌥G; any change of displays puts the line and the panel away; titles are cut at 48 characters; names of spaces are said as written.

**Not shipped**: criterion 6 (how it looks, focus, full-screen Spaces) waits for a Mac: `scripts/mac-shell/shots-F43.sh`. The menu does not take its words from `Command.title` yet (F10 is rewriting it).
The line does not know the minimap yet (`HeadsUpModel.placed(in:above:)` is ready for its frame). `messages` needs a row in F12's settings window.
