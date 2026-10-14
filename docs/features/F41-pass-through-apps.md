# F41: Apps that keep their own ⌃⌥

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (`feat/F41-pass-through-apps`); builds and passes every test on a Mac; the proof with real keys (`scripts/mac-shell/check-F41.sh`) is still to be run
Depends on: F06, F40
Size: small to medium

## Summary

A global shortcut is taken from every app. ⌃⌥ is Emacs's C-M-, AltGr in a Windows remote desktop or virtual machine (⌃⌥Q types @ on a German layout), the
workspace switcher of a Linux guest, and a dozen JetBrains commands (`docs/KEYBOARD.md`, "Conflicts"). Removing shortcuts one by one in `bindings` loses them
everywhere. People need "not in this app". skhd and Karabiner-Elements both have such a list, and their users expect one.

## Behaviour

- Setting `passThroughApps` (bundle ids, default empty). While one of them is frontmost, Arbor holds **no** shortcuts and neither pointer tap; its windows stay
  arranged and everything else works (dragging, the menu bar, `arborctl`). Shortcuts return the moment another app is frontmost.
- Setting `pauseForApps` (bundle ids, default empty): while one of them is frontmost Arbor is paused as by `pause` (F40), and resumes when it is not. For
  games and anything that changes the display's resolution. A pause started by hand is never ended by this.
- Menu, next to Don't Arrange "App": **Shortcuts Off in "App"**, with a tick.
- Commands: `pass-through [bundle-id]` toggles the frontmost or named app; `bindings` says "off while <app> is frontmost" when that is the case.
- F42's check suggests the list when it sees a known app: Microsoft Remote Desktop / Windows App, VMware Fusion, Parallels Desktop, UTM, VirtualBox, Emacs,
  JetBrains IDEs. Suggest only; never add by default: someone who frames a virtual machine still wants ⌃⌥Space to get out.

## Design notes

- The controller must know the frontmost app: append `applicationActivated(bundleID: String?)` to `WindowSystemEvents`; `AXWindowSystem` already observes
  `NSWorkspace.didActivateApplicationNotification` (added with the product review); `FakeWindowSystem.activate(bundleID:)` for tests.
- One tested function decides what is registered: `Controller.activeBindings` = `KeyBindings.effective` → `whilePaused` if paused → empty if passing through.
  `ArborApp.registerHotKeys` registers exactly that. `Controller.inputSettings` already exists for the taps; extend it.
- Add a `Change.input` (or reuse `.settings`) so the app re-registers only when the answer changes, not on every app switch.

## Acceptance criteria

1. With Emacs on the list: activating it empties `activeBindings` and turns `inputSettings` off; activating Safari restores both.
2. Windows of a pass-through app are still docked, parked and revealed.
3. `pauseForApps`: activation pauses, deactivation resumes; a manual `pause` before or during is left alone.
4. The menu item and `pass-through` write `settings.json` and apply at once; old settings files load.
5. (was "Manual"; board, section 5) On a hosted Mac, `check-F41.sh`: an app that writes down the keys it gets receives ⌃⌥F and ⌃⌥Space; ⌘Tab away and ⌃⌥Space shows everything.

## Shipped / Not shipped

Shipped (`Controller+PassThrough.swift`, `AppLists.swift`, `App/FrontmostAppWatcher.swift`):

- `passThroughApps` and `pauseForApps`, both empty by default, matched by whole bundle id, ignoring case.
- `Controller.activeBindings` and `inputSettings` decide what is held; `Change.input` tells the app when the answer changes. An ordinary switch between
  two apps changes nothing and registers nothing. ✔ 1: `aListedAppInFrontTakesTheShortcutsAndGesturesAndGivesThemBack`, `theAppIsToldOnlyWhenTheAnswerChanges`
- Windows of a listed app are arranged like any others. ✔ 2: `itsWindowsAreStillDockedMovedOutOfViewAndRevealed`
- Pausing for an app. ✔ 3: `aListedAppInFrontPausesArborAndLeavingItResumes`, `aPauseStartedByHandBeforehandIsLeftAlone`, `aPauseAskedForByHandDuringTheAppsPauseOutlivesIt`, and nine
  more for the corners: resuming by hand inside the app holds until it comes to the front again; one listed app to another stays paused without a flicker; a timed pause that ends
  inside the app goes on as the app's; launching behind the app; the window switched to is in view after the pause ends (nobody reports its focus: Arbor was not looking).
- `pass-through [bundle-id]`, the menu item with its tick, `bindings` and `status` saying "off in Emacs". ✔ 4: `theCommandTogglesTheFrontmostAppSavesAndAppliesAtOnce`, `oldSettingsFilesLoadWithEmptyLists`
- `bindings` suggests `pass-through` for apps known to use ⌃⌥ that have a window open (`ControlOptionApps`, `Controller.passThroughSuggestions`: ready for F42's check). Never added by itself.
- Scenario `41-apps-that-keep-their-keys.sim`, with a new form `expect shortcut <keys> on|off`.

Differs from the text above, on purpose:

- **Not quite "no shortcuts": `toggle-pause` (⌃⌥⎋) stays**, and so does any shortcut the user gives to `pass-through`. One key has to answer wherever you are, or a person who forgot the list has a dead
  keyboard and no clue; and a key that switched pass-through on must be there to switch it off. Whoever needs ⌃⌥⎋ in the app too removes it: `"ctrl+opt+escape": null`.
- The frontmost app is reported by its own small watcher, not by `AXWindowSystem`, which stops observing during a pause: the pause for an app ends when the app leaves the front, so somebody has to be looking.
- Hot key identifiers are never reused (`HotKeyCenter`). They used to be positions in the list, so a press still in the queue when the list changed would have run whichever command took over its number.

Not shipped:

- **Full screen** changes nothing by itself: what counts is the app in front, on whichever macOS Space. A listed app in full screen passes through; an unlisted one does not. Once windows know they are in
  full screen (F30) "shortcuts off in full screen" would be one more line in `activeBindings`, but ⌃⌥0 and ⌃⌥⎋ are still wanted there with a second display, so it should be asked for first.
- **Keys go by the frontmost app, pointer gestures by what is under the pointer** (found by the input review). A ⇧⌘-press on a window of a listed app while another app is frontmost reaches Arbor's tap before the listed app comes to the front, so the first
  ⇧⌘-drag into a listed app from elsewhere is still Arbor's. The fix, when wanted: at a press with the trigger held, pass if the window under the pointer belongs to a listed app (the taps' window list would need the owner's pid, and the pids published to the tap).
- No command for `pauseForApps`: it is edited in `settings.json` (and by F12's `set`).
- No wildcards (`com.jetbrains.*`): people use one or two IDEs, and the menu item lists the one in front.
- **Walking in with the keyboard is a one-way door.** ⌃⌥→ onto a space that holds only Emacs gives Emacs the keyboard, and the next ⌃⌥→ is Emacs's. ⌘Tab, a click, the menu or ⌃⌥⎋ lead out. Keeping
  the shortcuts until ⌃⌥ is released would soften it; not built.
- Still to do on a Mac (`scripts/mac-shell/check-F41.sh` does all of it and is safe on a person's Mac): criterion 5 with real keys; what registering
  forty-odd hot keys costs; how long after the switch Arbor has let go; whether passing a press on with `postToPid` could replace unregistering.

### After the product owner's review

- The menu's first line in a listed app is **Shortcuts are off in “Emacs”** (`Controller.passThroughNotice`): walking onto one with the keyboard switches the keys off, and nothing else said so. ✔ `theMenuSaysFirstThatTheShortcutsAreOffHere`
- **A resume always ends with the focused window in view**, whoever began the pause: ⌃⌥⎋, the one key left in a listed app, used to lead back to the view one was stuck in. ✔ `aResumeAlwaysEndsWithTheFocusedWindowInView`
- `pass-through [bundle-id] on|off`, for files that must say which; repeating it changes and saves nothing. ✔ `onAndOffSayWhichAndCanBeRepeated`
- People read "shortcuts are off **in** Emacs" and "paused **for** Game", not "while … is frontmost". "pass-through" is the command's name only.
- **The key that summoned the app stays** (the product owner's day on the trunk; F53): with `"ctrl+opt+t": "summon Terminal"` and shortcuts off in Terminal, the key brought the terminal and could not send it away. While an app's window is summoned,
  the `summon` shortcut of that app is held besides ⌃⌥⎋; no other, and not while the app is in front without being summoned. `Change.input` is sent when that changes, also when the summon begins after the app came to the front (⌘Tab) or
  ends while it is still there (docked, pinned, floated). ✔ `SummonKeyTests`
