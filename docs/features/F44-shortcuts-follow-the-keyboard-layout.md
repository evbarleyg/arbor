# F44: Shortcuts follow the keyboard layout

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (`feat/F44-layout-aware-shortcuts`); builds and passes every test on a Mac, where the sample tables were compared with macOS's own layouts; the proof with real keys (`scripts/mac-shell/check-F44.sh`) is still to be run
Depends on: F06
Size: medium (half of it macOS-only)

## Summary

`KeyChord.Key` names a **position** on a US keyboard. ⌃⌥Z (undo) is the key labelled Y on a German or Swiss keyboard, ⌃⌥A (arrange) is Q on a French one, ⌃⌥M is `,`, and on
Dvorak nothing is where its letter says. The menu nevertheless shows "⌃⌥Z". Every ⌘-shortcut on the Mac follows the layout, so people expect the letter.

## Behaviour

- Letters, digits and punctuation in a shortcut mean **the key that types that character** on the current layout. Arrows, Space, ↩, ⇥, ⎋, ⌫ and F-keys are positions anyway.
- A character the layout cannot type without modifiers (`[` and `]` are ⌥5 and ⌥6 on a German keyboard) falls back to its US position, and menus, `bindings` and F43's panel
  show what is printed on that key there (⌃⌥Ü, ⌃⌥+).
- With a non-Latin layout active (Russian, Greek, Japanese kana) the ASCII-capable layout macOS pairs with it is used, as ⌘-shortcuts do.
- Switching layouts re-registers at once.
- Setting `shortcutsFollowLayout` (default true); false restores positions, for people who switch layouts all day and want keys to stay put.

## Design notes

- Core: `KeyLayout` = two dictionaries, character → key code and key code → printed character, with `.us` built in. `KeyChord.code(in:)` and `label(in:)` take one. All decisions and
  fallbacks are unit-tested with hand-written QWERTZ, AZERTY and Dvorak tables.
- macOS: build the table by running `UCKeyTranslate` over key codes 0…127 with no modifiers on `TISCopyCurrentASCIICapableKeyboardLayoutInputSource()`'s
  `kTISPropertyUnicodeKeyLayoutData`; observe `kTISNotifySelectedKeyboardInputSourceChanged` through `DistributedNotificationCenter`.
- Two characters can land on one key after fallback; the later binding is skipped and reported like any duplicate.

## Acceptance criteria

1. QWERTZ: `ctrl+opt+z` registers key code 16 and is labelled ⌃⌥Z; `ctrl+opt+[` registers 33 and is labelled ⌃⌥Ü.
2. AZERTY: `ctrl+opt+a` registers 12; digits register their positions and are labelled 1–9.
3. A collision after fallback is reported by `bindings`, and the other shortcuts still work.
4. `shortcutsFollowLayout: false` gives today's codes and labels.
5. (was "Manual"; board, section 5) On a hosted Mac, `check-F44.sh`: with German, French, Dvorak and Russian selected by script, ⌃⌥ and the key labelled Z does what ⌃⌥Z is bound to.

## Shipped / Not shipped

Shipped (`ArborCore/KeyLayout.swift`, `Controller+KeyboardLayout.swift`, `Input/KeyboardLayout.swift`):

- `KeyLayout`: what each key types alone and with ⇧; `code(for:)`, `label(for:)`, `fallsBack(_:)`; `.us` built in. The whole range of key codes can be passed in as macOS reports it: the numeric keypad, keys that type
  nothing visible and keys that type several characters are left out. Of two keys that type one character the US one wins, otherwise the lower code.
- A `KeyBinding` carries the key code and the label of the layout it was made for, so the menu, `bindings`, the log and everything that shows `binding.label` are right without knowing about layouts, and a change of layout
  makes the lists differ, which is what makes the app register again. `KeyBindings.effective(settings:layout:)`; `Controller.effectiveBindings` passes the layout in use.
- ✔ 1 `qwertz`. ✔ 2 `azerty`. ✔ 3 `aCollisionAfterFallingBackIsReportedAndTheOthersStillWork`, `theUsersShortcutBeatsADefaultThatLandsOnTheSameKey`. ✔ 4 `withTheSettingOffShortcutsArePositionsWithTheirUSLabels`.
  Also: `dvorakTypesEverythingSoNothingFallsBack`, `everyDefaultShortcutWorksOnEveryLayoutAndNoTwoShareAKey`, `aLayoutWithoutLatinLettersFallsBackToUSPositions`.
- **Labels after falling back.** What is printed on the key: ⌃⌥Ü. If the key types the wanted character with ⇧, that character is printed on it as well and is what is shown: that is why French digits read 1–9 and not & é ".
- **`us:z`**: the position outright, in any shortcut: `"ctrl+opt+us:h": "neighbor left"` is the key right of G on every layout, and is shown as what is printed there (⌃⌥D on Dvorak). For keys that are positions anyway the prefix means nothing.
- `bindings` adds the printed key where it differs (`ctrl+opt+[ (⌃⌥Ü) → back`) and names the layout.
- `Controller.keyboardLayoutChanged(_:)` tells the app (`Change.input`) only if a shortcut moved or changed its label, so going between Russian and the Latin layout macOS pairs with it registers nothing.
- macOS: `KeyboardLayoutReader` (TIS and `UCKeyTranslate`, no decisions) and `KeyboardLayoutWatcher`. The notification is asked for with `.deliverImmediately`: AppKit holds distributed notifications back from an app that is
  not active, which Arbor never is.
- arbor-sim: `keyboard us|german|french|dvorak|russian`; scenarios: `expect shortcut <keys> shows <label>`, `… key <code>`; `44-a-german-keyboard.sim`.
- The tables in `ArborTesting/SampleKeyLayouts.swift` were written by hand and agree with Unicode CLDR's record of Apple's layouts; on a Mac `theSampleLayoutsAreWhatMacOSHas` compares them, key by key, with the layouts macOS ships.
- `ARBOR_KEYBOARD_LAYOUT=com.apple.keylayout.German` (a launch option for tests) makes Arbor go by an installed layout that is not selected, so real keys can be pressed "on a German keyboard" without changing anybody's Mac.

Not shipped, and decisions:

- **The plain table decides, not the ⌘ one.** "Dvorak – QWERTY ⌘" types Dvorak and switches to QWERTY while ⌘ is held. Arbor's letter shortcuts hold ⌃⌥ without ⌘, so they follow what the keys type. People who chose that layout to keep
  shortcuts in place can set `shortcutsFollowLayout` to false.
- A sign typed only with ⇧ is **not** looked for on another key (`/` is ⇧7 in Germany): ⌃⌥ with that key is ⌃⌥7, which is taken. It falls back, as the spec says.
- A keyboard of another kind being plugged in (ISO for ANSI) swaps the keys left of 1 and beside the left ⇧ and sends no notification; the table is read again at the next change of layout. Only `` ` `` can be affected.
- Keys that are not in `KeyChord.Key` (the ISO key, the keypad, F13 and up) still cannot be bound; no `code:10`.
- F42's row "Keyboard layout: current layout is not US-like (until F44)" is no longer needed.
- Still to do on a Mac (`scripts/mac-shell/check-F44.sh`). The script's first part is safe on a person's Mac: real keys on German, French and Dvorak through
  `ARBOR_KEYBOARD_LAYOUT`, the setting, the menu's ⌃⌥Ü in a picture. Its second part runs only on GitHub's throwaway Macs: criterion 5 proper, with layouts selected by script while Arbor runs, Russian among them; whether the notification reaches
  Arbor in the background, and how soon.

### After the product owner's review

- **A sign with ⇧ is the key that types what ⇧ makes of it on a US keyboard** (rule 5 in `KeyLayout.swift`). Decided for ⌃⌥⇧/, "⌃⌥?", F43's shortcut: German and French registered key 44, German ⌃⌥? did nothing, and pressing the documented "/" literally was ⌃⌥⇧7, which overwrites a saved view.
  Built for every sign, not for digits (⌃⌥⇧2 is "save view 2", not ⌃⌥@, which is ⇧' in Britain). Where the layout does not type the character with ⇧, nothing changes. ✔ `aSignWithShiftIsTheKeyThatTypesWhatShiftMakesOfIt`, `digitsAndLettersWithShiftStayWhereTheyAreWithoutIt`, `theHelpShortcutCollidesWithNoDefault`
- **Any single character the layout types alone names its key** (rule 6): `ctrl+opt+ü`. It is read with the layout (`KeyChord(text:layout:)`) and becomes the position where it is printed, so `bindings` lists it as `ctrl+opt+us:[ (⌃⌥Ü)`. An entry that names a key by place or by print also stands in for the default that sits on that
  key, so `"ctrl+opt+ü": null` frees Back. On a layout that does not type the character the entry is skipped and reported. ✔ `anyCharacterTheLayoutTypesAloneCanNameItsKey`, `aGermanCanBindAndFreeTheirOwnKeys`
- Not possible: the key only European keyboards have (`^` in Germany). `+`, which also separates the parts, is written `ctrl+opt++` or `⌃⌥+`; to `bind` and `unbind`, `ctrl+opt+` is a shortcut nobody has finished typing.
- **`bind` and `unbind` read shortcuts as settings.json's are read**: on the layout in use, so `bind ctrl+opt+ö desktop` works on a German keyboard, is written into the file as `ctrl+opt+ö`, and what it "ran" before is what sat on
  that key, however it was written: the default shown as ⌃⌥Ü, `us:;`, a letter. The parser, which knows no layout, lets modifiers and one single character through, tidied (`⌃⌥Ü` and `ctrl+opt++` as menus show them too); the controller judges. ✔ `BindCommandTests`, "On another keyboard layout"
- **Both go by the key, and what they say is what has happened.** Everything the file says about the key goes first, under whichever of its names, entries that freed it included; so a key freed as `ü` can be bound again as `[`. A default that sits on the key is freed under **its own** name (`"ctrl+opt+[": null` for Back), which frees it whatever the key's own name is (`'` is where ⌃⌥4 falls back to on a French keyboard, and is a US key's name, not a place) and
  keeps it free when another layout is selected. `bind` does the same to a default whose key it gives away under another name (`bind ctrl+opt+ü arrange` writes `"ctrl+opt+[": null` beside the entry, which a US keyboard could not read); binding the default's command to the key again removes both. Only a place asked for outright (`us:z`) is written as it is, also where the default says the same today: it is to hold on every layout. Of two entries that mean one key, unbinding the one that `bindings` reports as skipped removes that one only. Afterwards the shortcuts in effect are looked at: a `bind` after which the key does not run the command, or an `unbind` after which Arbor would still hold the key, is refused and changes nothing. ✔ `BindCommandTests`, "What is said is what has happened"
- The layout is read before the control socket opens, so `bind` and `unbind` go by it also while Arbor still waits for the Accessibility permission. (macOS-only; type-checked, to be seen on a Mac.)
