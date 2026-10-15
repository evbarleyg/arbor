# Arbor

A free, open-source window manager for macOS. **Arrange windows side by side once. Fill the screen with any one, and one key
brings the arrangement back. Your Mac's own tiling forgets an arrangement; Arbor keeps it.**

Your real windows dock into
nested splits, with the Desktop kept as a space between them, and a camera
zooms between those spaces: frame one window, step out to its group, step
out again to see everything.

Inspired by [TrellisWM](https://trelliswm.app) by Dan Fessler. Arbor is an
independent implementation and is not affiliated with it.

> Status: early. Docking, the camera, tiles, persistence and the command line
> work and are covered by tests; tab strips are on the
> [roadmap](docs/ROADMAP.md). Most of that proof is against a simulated window
> system. The runs on record on a real Mac arrange only Arbor's own test
> windows: by command in every macOS CI run (`make e2e`), and with a real pointer
> and keyboard for drags, seams, window edges, tiles, every default camera
> shortcut, the rectangle (with ⇧⌘, its keys until they became ⌃⌥), URLs, a restart and quitting
> ([evidence](collab/evidence/gestures-latest.txt); [docs/FEATURES.md](docs/FEATURES.md)
> says item by item what is proven how; [docs/RELEASE-NOTES.md](docs/RELEASE-NOTES.md) says it in words, with what is
> known to go wrong). Still untried on a Mac: other apps' windows, pinch, rules, your own shortcuts, a
> second display and Spaces.

**[Install it](docs/INSTALL.md)** from source in three commands.

## What it does

- **Dock**: drag a window to a screen edge to dock it beside everything you can
  see, or hold it over another window's edge for a moment to dock beside that
  window; a preview shows where it will land. Drop it on the Desktop to float it
  again, at the size it had before. Let go anywhere else, where no preview shows,
  and a docked window goes back to its place. Hold ⌘ while dragging and nothing
  docks: the window floats. The keyboard docks too: ⌃⌥← and ⌃⌥→.
- **The Desktop stays**: windows you have not docked float exactly as they always have. Arbor never
  moves or resizes one: it stays where you put it, over docked windows too, goes out of view when you
  zoom in on something else, and comes back to the same place. Show the Desktop in the menu shows all that floats.
- **Zoom**: ⌃⌥↩ fills the screen with the focused window (again to return): a docked one is framed, a floating one
  grows to the same size, stays floating and has its own frame back afterwards, and nothing else moves. ⌃⌥Space shows everything, ⌃⌥[ goes back. In the menu, Step Out
  goes out a level, Step In goes in toward the window you are typing in (or pointing at), and Forward goes where Back came from.
- **Peek**: hold ⌃⌥Space instead of tapping it. Everything shows while the keys are down; point at a window, or walk to it with
  the arrow keys, and let go: it is framed. One gesture from any window to any other, by where it is.
- **Motion that shows where things went**: every zoom, dock and close plays as one short motion.
  Zooming in enlarges the whole arrangement, so the other windows slide out past the screen edges;
  zooming out brings them back from there. A click ends it at once, a second shortcut carries on
  from where things are, and macOS's "Reduce motion" switches it off.
- **Nine keys, or all of them**: Arbor takes nine shortcuts, each ⌃⌥ and one key; the menu has the rest. One setting
  binds some fifty: `arborctl set shortcuts all`. See [Keyboard](#keyboard).
- **Stay on the keyboard**: with all of them bound, ⌃⌥⇧ + arrow moves focus to the nearest window that way, into tiles, on to the
  next space and the next display. ⌃⌥⌘= and ⌃⌥⌘- grow and shrink the focused window, ⌃⌥⌘0 balances the
  sizes, ⌃⌥R rotates a row into a column and back. See [Arranging from the keyboard](#arranging-from-the-keyboard).
- **Pinch and frame**: with ⌥ held, or over the Desktop, pinch on the trackpad
  to step out and spread two fingers to step in toward the pointer. Hold ⇧
  and drag a rectangle, starting on the Desktop, to frame what it covers; with
  ⌃⌥ held the drag can start anywhere. Off for now, with the next: `arborctl set pointerGestures true` switches them on.
- **Zoom with a mouse**: hold ⌃⌥ and scroll: up steps in toward the pointer, down steps out. One step per notch of a
  wheel.
- **Nothing gets lost**: windows outside the view are out of view, not closed: they wait past a
  screen corner and come back when you zoom out or switch to them (⌘Tab). Windows too
  small to use show as tiles with their app's colour and icon, a group as a miniature of its windows; click one to zoom in.
  An app that will not shrink to its place first gets room from the Desktop and its neighbours.
  Unplug a display and its windows float on the main one; plug it back in and
  they return to their places. Windows on other macOS Spaces and in full screen keep
  their places too, and so do minimized windows and hidden apps.
  Quit Arbor and start it again, and what was docked is back in its places with everything showing, whatever the view
  was; a window you never docked is not moved. The view you quit in is one step back.
  If Arbor ever crashes, it starts again within a second with the arrangement and the view as they were.
- **At home on macOS**: macOS's own window tabs (Finder, Terminal, Xcode) count as one
  window, whichever tab is in front. An app that hangs does not hold Arbor up, and one
  that insists on placing its own window is left in peace after three tries.
- **Keep a window in view**: pin a video call, a timer, a music player or a reference document (menu →
  Focused Window → Keep This Window in View, or `arborctl pin`) and it keeps its place on the display wherever
  you zoom. See [Pinned windows](#pinned-windows).
- **Summon an app**: a terminal, a scratch note, a calculator, a password manager: one shortcut brings its
  window over whatever you are looking at, with the keyboard in it; the same shortcut, or turning to another
  window, sends it out of view again. The view never moves. See [Summoning](#summoning).
- **Resize at the gaps**: drag the gap between two windows, or a docked
  window's own edge, to resize both sides. A small handle shows in the gap under the pointer.
- **One surface**: behind docked windows the wallpaper is a shade darker, with rounded corners, so that what is docked
  reads as one thing and the Desktop between it as another. It can be blurred as well, or left alone
  (see `dimBehindArranged` under [Settings](#settings)).
- **Saved views**: Saved Views in the menu saves where you are looking under a number, 1 to 9, and goes back there.
- **Named spaces**: Name This Space…, in the same submenu, gives the space you are looking at a name. `arborctl go writing`, `arbor://go/writing` or the
  menu take you there from anywhere, on any display. A named group stays itself while windows come and go.
- **Every open window in the menu**: Windows, the second row, lists them all by app and title in the order you used them, and says
  which are out of view, minimized or hidden. A click brings one to the front and into view.
- **Go to anything**: ⌃⌥G, a few letters, Return, and the view moves to that window and focuses it, whatever
  kept it out of view: another space, another tab, the Dock, ⌘H, another display. Saved views are in the same
  list. Return straight away goes to the window you were in before.
- **See where you type**: a line in your accent colour surrounds the focused window, in the
  gap, so it covers nothing. It flashes when a shortcut moved the focus.
- **Undo**: ⌃⌥Z takes back the last change to the arrangement, whether you made it with a shortcut, a drag or
  a command; Redo, in the menu, puts it back.
- **It says what happened**: a key that can do nothing where you are says why, in a line low on the display; so does
  anything that changes unseen (a saved view, a pause). Keyboard Shortcuts… in the menu shows every shortcut on screen.
- **See where you are**: Show Minimap, in the menu, shows a minimap of the whole arrangement low on the display, with the space in view marked. Click a
  window in it to frame that window; or give it a key, hold that, point and let go. It can also show by itself after each move of the view.
- **Scriptable**: every action is a command: `arborctl dock left`, or the URL
  `arbor://dock/left` from Raycast, Alfred, Shortcuts or a Stream Deck
  (see [URLs](#urls)). A whole arrangement is a line of text:
  `arborctl layout "Safari | Desktop | (Mail / Notes)"`. And every change is an event: `arborctl watch` tells a status
  bar or a script what you are looking at, as it changes. See [Scripting Arbor](docs/SCRIPTING.md).
- **New windows find their own place, if you like**: tick "Dock New Windows" and each window you open takes half of
  the window you were working in, as in yabai or bspwm. Small windows, windows of a fixed size and windows there
  is no room for float as always, and nothing turns into a tile because a window opened. Off by default.
- **Your Mac, your rules**: "Don't Arrange" leaves an app's windows alone; "Float All Windows" returns you
  to a normal Mac; quitting puts every window back in view.
- **No trace**: a window that leaves the arrangement gets its own size back. Float All Windows, quitting, pausing
  and Don't Arrange put windows back where they were before they were docked.
- **Out of the way when you need it**: ⌃⌥⎋ pauses Arbor for a game, a remote desktop or an app it
  gets in the way of: every window goes back to where it was, in its own size and in view, and windows, shortcuts and gestures are left
  alone until you press it again.
- **Apps that need ⌃⌥ keep it**: Emacs, an IDE, a remote desktop or a virtual machine. Choose Shortcuts Off
  in “App” from the menu, and in that app the keys are its own; its windows stay arranged.
- **Behaves in front of an audience**: choose **Hold This View** before you share your screen and the
  view stays exactly where it is: an app that pushes itself forward stays out of view, ⌘Tab and a slipped
  ⌃⌥Space do nothing, rules wait. For a call, choose **Hold Still**: the view moves when you
  ask, not on its own.

### If you get lost

1. **Show Everything**: ⌃⌥Space, or the menu bar icon, or `arborctl home` for every display at once.
2. **Float All Windows**, in the menu. Nothing is docked any more, and every window is back where
   it was before it was docked: a normal Mac.
3. **Quit Arbor**: every window comes back into view, where it was before it was docked.

If Arbor was killed or crashed with windows out of view, start it again: it brings them back.
If its Accessibility permission is taken away while windows are out of view, it cannot fetch them, and says so (a warning sign
in the menu bar); they come back the moment the permission does.

## Install and run

Requires macOS 14 or later. Building it needs Swift 6.2 or later: Xcode 26, or just its Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/evbarleyg/arbor && cd arbor
./scripts/make-signing-identity.sh
make install
```

The second is wanted once per Mac, so that permissions survive rebuilds; the third builds, installs
`~/Applications/Arbor.app` and `arborctl`, and starts it.

Arbor needs **Accessibility** permission to move other apps' windows (System
Settings → Privacy & Security → Accessibility). macOS ties
the permission to the code signature; the second command makes a certificate of
your own to sign with, so that you give it once and not after every build.
To update, `git pull && make install`; to remove it, `make uninstall`.

[docs/INSTALL.md](docs/INSTALL.md) has the rest: what the certificate is and is not, updates,
launch at login, downloaded builds and their first launch (they are not notarized,
so macOS blocks them until you choose Open Anyway in System Settings → Privacy &
Security; building from source avoids that), Homebrew (a cask is ready for when the
repository is public), and what to do when Arbor says it has no permission
although System Settings shows it switched on.

### First run

Arbor lives in the menu bar and has no Dock icon. The first time, and whenever the permission is missing, a **welcome window** opens. It
says what Arbor is for, in a small drawing and three sentences, names the keys, and asks for one thing: the Accessibility permission. **The first
minute asks for nothing else.** (If another window manager is running, or VoiceOver is on, it says so there too: they take the same keys.)

When the permission arrives the window comes forward and goes on by itself to **four moves to try** on your own windows, all of them keys, ticked
off as you make them: click a window and press ⌃⌥⌘←, click another and press ⌃⌥⌘→, ⌃⌥↩ to fill the screen with one, ⌃⌥↩ again to have the
arrangement back. The window words them from the shortcuts in effect. For the moves it is small, explains only the next one, and waits low over the
Desktop until you put it elsewhere. It names one way back: ⌃⌥⎋ pauses Arbor and every window is as it was; Quit does the same. After the moves the
same page has the box for Open at Login, which is also in the settings window, under General.

**Help → Check Setup…** is for whoever asks: everything on this Mac that matters to Arbor, with a live tick on what is in order and a button that
opens the right pane of System Settings:

- **Accessibility** (required): macOS lets an app move other apps' windows only with this permission (System Settings →
  Privacy & Security → Accessibility). If the switch is on there and Arbor still says it has no permission, the build's signature has
  changed: switch it off and on again ([docs/INSTALL.md](docs/INSTALL.md) has how to sign so that this does not happen).
- **macOS tiling** (recommended): macOS's own tiling, three settings under Desktop & Dock, reacts to the same drags as Arbor, and before it. **Switch Off macOS Tiling** in
  the row does it in one step (`arborctl fix-setup`): it changes those settings and nothing else, takes effect at once, and writes down how they
  were. They are off **only while Arbor runs**: a quit or a pause leaves the Mac as Arbor found it, and the next start switches them off again.
  **Put Them Back** in the same row (Help → Check Setup…, or `arborctl fix-setup undo`) and `make uninstall` end that for good. Nothing is changed unasked. By hand: under Windows,
  switch off "Drag windows to left or right edge of screen to tile", "Drag windows to menu bar to fill screen" and "Hold ⌥ key
  while dragging windows to tile" (macOS 15 and later). The row names the ones that are still on. Stage Manager itself moves
  windows too: use one or the other. "Click wallpaper to reveal desktop" (macOS 14 and later) is left alone, and is only a note in `arborctl doctor`:
  a click on the wallpaper, or in a gap between docked windows, sweeps every window aside, and the next click brings them back where they were.
  "Only in Stage Manager" switches that off.
- It also says so when Rectangle, Magnet, yabai or another window manager is running (they use the same ⌃⌥ shortcuts), when
  VoiceOver is on (⌃⌥ is its modifier), when there are several input sources, which macOS can switch with ⌃⌥Space, and when an
  app that uses ⌃⌥ itself is open (Emacs, a virtual machine, a JetBrains IDE).

To see the window again, choose Help → Check Setup… or Help → Welcome… (the four moves) in Arbor's menu, open
Arbor again (the way in when a crowded menu bar hides its item behind the notch), or run `arborctl check-setup` or
`arborctl welcome`.
`arborctl doctor` checks all of the above and more, one
line each, the worst first: permissions, macOS settings, competing apps, gestures, shortcuts macOS refused, the keyboard layout and
the shortcuts it moves, apps that use ⌃⌥ themselves, entries of `settings.json` that were skipped, displays and the version. It exits
with 1 when something is wrong, and what it calls a problem is also written to the log at every launch.

### The menu bar item

| Button | Click |
|---|---|
| ‹ › | Back and forward through where the view has been; grey when there is nowhere to go |
| The Desktop | Show the Desktop |
| Arbor's mark | Show Everything |
| 1–9 | One for each saved view; hover to see which apps it holds |
| … | The menu |

The button for where you are is filled in. The buttons belong to the display under the pointer, like the
commands they run. **Right-click** anywhere on the item (or click with ⌃ or ⌥) for the menu with every command and its shortcut.
While nothing is docked on that display there is nowhere to go, and the item is Arbor's mark alone: a click opens the menu.
Set `menuBarControls` to false to keep it that way, which also takes less of a crowded menu bar. macOS silently leaves out the items
a full menu bar has no room for, and a notch takes room too: when Arbor finds its buttons left out it falls back to the single icon by
itself, and `arborctl doctor` says so ("Menu bar item"). If even that is left out, open Arbor again: the welcome window comes.

The icon also says how Arbor is: dimmed while it is paused, a warning sign while it waits for Accessibility permission. The menu
then begins with a row that says so, and choosing it ends it ("Arbor is paused · Resume"). What cannot act at the moment is greyed out, in its usual
place; Show Everything, Float All Windows, Pause Arbor and Quit Arbor never are. `arborctl menu` prints the menu as it would open.

**Screen Recording** permission is not needed yet. While they move, windows show their app's colour and
icon. Showing their contents instead is built but not ready: the one time it ran on a Mac it crashed
Arbor, and the fix has not been tried since, so it is off (`windowPictures`) whatever macOS allows. When it is on:
nothing is recorded or stored; Arbor takes still pictures, keeps them in memory only, and lets go of them
when a window closes and when Arbor pauses or quits.

## Keyboard

Arbor takes nine keys, each ⌃⌥ and one key. Nothing else is bound: no third modifier, no digit, no other letter.

| Keys | Action | Command |
|---|---|---|
| ⌃⌥← / ⌃⌥→ | Dock the window in front at that side, or move it one place | `dock left` / `dock right` |
| ⌃⌥↩ | Fill the screen with the focused window, docked or floating; again to return | `zoom` |
| ⌃⌥Space | Show everything; held, peek (below) | `show-all` |
| ⌃⌥[ | Back to where the view was | `back` |
| ⌃⌥Z | Undo the last change to the arrangement | `undo` |
| ⌃⌥F | Float the focused window, or dock it again | `toggle-float` |
| ⌃⌥G | Go to…: find a window, a named space, a saved view or a command by typing | `find` |
| ⌃⌥⎋ | Pause / resume Arbor | `toggle-pause` |

The rest is in Arbor's menu, docking at the top and the bottom too (Dock Focused Window); ⌃⌥G finds it by name (`bal` ↓ ↩ balances
the sizes); and every command runs as `arborctl <command>`. Any of it can have a key, one at a time or all at once: see [More keys](#more-keys).

**Keys follow the keyboard, gestures follow the pointer.** With two displays, a shortcut changes the view of the display
you are typing on, wherever the pointer was left, and Step In goes toward the focused window. If you have moved
the pointer since you last typed or switched windows, you are pointing at something, and the shortcut means that display and
that window instead. A pinch always means what is under the pointer, and the menu the display whose menu bar you
clicked. `arborctl` and URLs choose as shortcuts do. To settle it one way for good, set `stepInToward` to
`"pointer"` or `"focus"` (see [Settings](#settings)).

**Peek: hold to look, let go to land.** Tapped, ⌃⌥Space shows everything and the view stays there. Held for longer than
0.3 s, it shows everything only while the keys are down, with an outline around the view you came from. Move the
pointer over a window, a tile or the Desktop, or press the arrow keys (⌃⌥ are down anyway), and the outline goes there. Let go, and what is
outlined is framed; ⌃⌥[ returns to where you were. Press ⎋ first, or let go without choosing after a good look (a second or more), and you are
back where you were as if nothing had happened. Let go sooner without choosing and it was a slow tap: everything stays. A click frames what is outlined at once. `"peek": false` in `settings.json` makes holding the same as tapping.

A shortcut, pinch or menu item that cannot do anything where you are says why in a line low on the display ("No space to
the left"), which fades after a moment and takes neither clicks nor the keyboard. The same line confirms what cannot be seen
(a saved view, a pause, an app no longer arranged), says so when a key worked but had nothing to change ("Showing everything"), and, three times each and never again, explains the moments that
puzzle newcomers: the first dock, the first time windows go out of view, the first tile. What you can see for yourself is not
announced. `"messages": "all"` in `settings.json` shows every reply, `"off"` none (a shortcut that cannot act then beeps).
If macOS uses ⌃⌥Space to switch keyboards (it does when several input sources are set up), only one of the two gets the keys. Show Everything is in the menu too, and `arborctl bind ctrl+opt+0 home` makes ⌃⌥0 a second key for it.
[docs/GUIDE.md](docs/GUIDE.md) is the user's guide: the idea on one page, the first ten minutes, recipes for a working day, and what to do when something is wrong.
[docs/KEYBOARD.md](docs/KEYBOARD.md) has the whole map, the reasoning, and the known clashes with macOS and other apps.

Letters, digits and signs mean the keys that type them on your keyboard layout, as in every ⌘-shortcut: ⌃⌥Z is the key
labelled Z on a French keyboard too. A sign your layout cannot type on its own (`[` and `]` on most European
keyboards) stays where a US keyboard has it, and the menu shows what is printed on that key: Back is ⌃⌥Ü in Germany.

A global shortcut is taken from every app. For an app that uses ⌃⌥ itself, bring it to the front and choose
**Shortcuts Off in “App”** from the menu (or run `arborctl pass-through <bundle id>`; again to undo, or say `on` or
`off` after it). In that app Arbor holds no shortcut and no gesture, and goes on arranging its windows; ⌘Tab or click
elsewhere and they are back. Only ⌃⌥⎋ keeps working there, so that one key answers wherever you are; to give that up as well, set
`"ctrl+opt+escape": null` in `bindings`. And a key of yours that summons the app (`summon Terminal`) goes on working while it is summoned, to send it away again.

### More keys

**One at a time.** Open Settings… → Shortcuts, click a shortcut and press the new keys; the box at the bottom gives a shortcut to
any command. Or run `arborctl bind ctrl+opt+d desktop` and `arborctl unbind ctrl+opt+g` (`⌃⌥D` is read too). The ones people
are likeliest to want:

| For | Run |
|---|---|
| Show the Desktop | `arborctl bind ctrl+opt+d desktop` |
| Step Out | `arborctl bind ctrl+opt+up out` |
| Step In | `arborctl bind ctrl+opt+down in` |
| Saved view 1: go there | `arborctl bind ctrl+opt+1 view 1` |
| Saved view 1: save it | `arborctl bind ctrl+opt+shift+1 save-view 1` |
| Show Minimap | `arborctl bind ctrl+opt+m minimap` |
| Redo | `arborctl bind ctrl+opt+shift+z redo` |
| Show everything on every display | `arborctl bind ctrl+opt+0 home` |

Or add a `bindings` object to `settings.json` that maps a shortcut to a command
(the same text `arborctl` takes); Arbor applies the file as soon as you save it. The same eight:

<!-- settings -->
```json
"bindings": {
  "ctrl+opt+d": "desktop",
  "ctrl+opt+up": "out",
  "ctrl+opt+down": "in",
  "ctrl+opt+1": "view 1",
  "ctrl+opt+shift+1": "save-view 1",
  "ctrl+opt+m": "minimap",
  "ctrl+opt+shift+z": "redo",
  "ctrl+opt+0": "home"
}
```

**All at once.** `arborctl set shortcuts all` (Settings… → General → Shortcuts: All of them) binds [the whole map](#the-whole-map-shortcuts-all) instead of the
nine; `arborctl set shortcuts core` (The nine) goes back. Your own `bindings` go on top of either. Earlier builds bound the whole
map: after one of those, Arbor has the nine from its next start, and this setting brings the rest back.

**What `bindings` takes:**

- A shortcut that Arbor binds itself gets your command instead (`"ctrl+opt+space": "arrange"`), `null` removes
  it (`"ctrl+opt+g": null`), and any other shortcut is added. Those you do not mention stay.
- A shortcut is modifiers and one key joined by `+`, in any order and case. What a menu shows
  can be pasted as it is: `⌃⌥Space`, `⌃⌥←`.
  Modifiers: `ctrl`, `opt`, `cmd`, `shift` (or `control`, `option`, `alt`,
  `command`, `⌃`, `⌥`, `⌘`, `⇧`). Keys: `a`–`z`, `0`–`9`, `f1`–`f12`, `space`,
  `return` (or `enter`), `tab`, `escape`, `delete`, `left`, `right`, `up`, `down`,
  and `[` `]` `-` `=` `,` `.` `/` `;` `'` `` ` `` `\`.
- Any other single character your keyboard layout types on its own names its key too: `ctrl+opt+ü`. That is also how to
  change or remove a default that the menu shows that way (Back is ⌃⌥Ü in Germany: `"ctrl+opt+ü": null`).
- A sign with `shift` means what ⇧ makes of it on a US keyboard, wherever your layout types that with ⇧: `ctrl+opt+shift+/` is
  ⌃⌥?, which is ⌃⌥⇧ß in Germany.
- `us:` before a letter, digit or sign means its place on a US keyboard, whatever your layout types there:
  `ctrl+opt+us:h` is the key right of G. To have that for every shortcut, set `shortcutsFollowLayout` to false.
- A shortcut needs `ctrl`, `opt` or `cmd`, except on `f1`–`f12`, so the key
  still types.
- Entries Arbor cannot use are skipped and listed, with the reason, by
  `arborctl bindings` and in the log.

`arborctl bindings` prints the shortcuts in effect, and says at the end of its line of each that is not Arbor's at that moment, and why; menu → Help → Keyboard Shortcuts… shows them on screen, by name. `bindings` also lists the ones that macOS uses itself as things stand
(⌃⌥Space switches keyboards on a Mac with several input sources): one of the two does nothing, and it says where to change either.

### The whole map (`shortcuts`: `all`)

Here ⌃⌥ + arrow looks and ⌃⌥⌘ + arrow docks. The other seven of the nine are the same keys in both.

| Keys | Action |
|---|---|
| ⌃⌥Space | Show everything; held, peek (above) |
| ⌃⌥0 | Show everything on every display |
| ⌃⌥↑ / ⌃⌥↓ | Step out / step in |
| ⌃⌥← / ⌃⌥→ | Neighbouring space |
| ⌃⌥⇧ + arrow | Focus the nearest window that way; with none in view, the neighbouring space |
| ⌃⌥↩ | Frame the focused window; again to return |
| ⌃⌥[ / ⌃⌥] | Back / forward |
| ⌃⌥D | Desktop |
| ⌃⌥G | Go to…: find a window, a named space or a saved view by typing |
| ⌃⌥M | Minimap: click a window in it to frame it; again to put it away. Held: let go over a window to frame it, ⎋ to give up |
| ⌃⌥⌘ + arrow | Dock the focused window at that edge, or move it one place |
| ⌃⌥F / ⌃⌥⇧F | Float or dock the focused window / float all windows |
| ⌃⌥⌘= / ⌃⌥⌘- | Grow / shrink the focused window |
| ⌃⌥⌘0 | Balance: equal sizes for everything in view |
| ⌃⌥R / ⌃⌥⇧R | Rotate the focused window's group (row ↔ column) / mirror it |
| ⌃⌥⇧1–9 / ⌃⌥1–9 | Save / recall a view |
| ⌃⌥N | Name the space in view (↩ names it, an empty field removes the name, ⎋ cancels) |
| ⌃⌥⎋ | Pause / resume Arbor |
| ⌃⌥Z / ⌃⌥⇧Z | Undo / redo the last change to the arrangement |
| ⌃⌥⇧/ | The shortcuts in effect, on screen; any key or click puts them away |
| ⌃⌥, | Settings… |

`arrange` has no key in either map: with a widely used chat app in front, ⌃⌥A archived the open conversation there. Arrange Windows
is in the menu.

### Arranging from the keyboard

For people who come from yabai, AeroSpace, Amethyst or i3. Directions are `left`, `right`, `up`, `down`. The keys in this table belong
to the whole map (`arborctl set shortcuts all`), or bind the ones you want singly ([More keys](#more-keys)). The menu has Grow,
Shrink, Balance Sizes, Rotate Group and Mirror Group either way, under Adjust.

| Command | Key in the whole map | What it does |
|---|---|---|
| `focus <direction>` | ⌃⌥⇧ + arrow | Focus the nearest window that way, docked or floating. A tile in the way is zoomed into. With no window that way in view, the view moves to the neighbouring space; past the last space, focus crosses to the next display |
| `focus next`, `focus previous` | | Cycle through the windows in view |
| `focus <window>` | | Focus a window by its id and bring it into view |
| `swap [window] <direction>` | | Trade places with the nearest docked window that way. The places keep their sizes (`dock <edge>` takes the size along) |
| `swap <window> <window>` | | Trade the places of any two docked windows, also across displays |
| `grow [points]`, `shrink [points]` | ⌃⌥⌘= , ⌃⌥⌘- | Make the focused window bigger or smaller by moving the gaps beside it (two opposite gaps share the amount); a floating window changes about its middle, within the Desktop if it is on it. It never shrinks so far that it becomes a tile. Without a number: `resizeStep` |
| `balance [all]` (or `equalize`) | ⌃⌥⌘0 | Equal sizes for everything in view, or on the whole display |
| `rotate` | ⌃⌥R | Turn the focused window's group from a row into a column; again, and it is as it was. Refused if a window would get too small to show |
| `mirror` | ⌃⌥⇧R | Reverse the order of that group |
| `move-to-display <next\|previous\|n> [window]` | | Send a window to another display, docked or floating as it was |
| `focus-display <next\|previous\|n>` | | Focus the window that display had in focus last; `next` and `previous` pass over a display with nothing in view |

Displays are counted from 1, left to right and then top to bottom. The pointer stays where you left it: shortcuts
follow the keyboard to the other display by themselves.
Saved views and Back follow a window through a `swap`, as they do when it is docked somewhere else.

The vi keys, and shortcuts for the commands that have none, are a few lines of `bindings`:

```json
"bindings": {
  "ctrl+opt+h": "focus left",        "ctrl+opt+shift+h": "swap left",
  "ctrl+opt+j": "focus down",        "ctrl+opt+shift+j": "swap down",
  "ctrl+opt+k": "focus up",          "ctrl+opt+shift+k": "swap up",
  "ctrl+opt+l": "focus right",       "ctrl+opt+shift+l": "swap right",
  "ctrl+opt+o": "focus-display next", "ctrl+opt+shift+o": "move-to-display next"
}
```

## Pinned windows

Floating windows live on the Desktop, so they go out of view when you zoom in on something else. That is
wrong for the few that accompany whatever you are doing. Pin those: focus the window and choose
**Keep This Window in View** from the menu (a tick shows that it is on), or run `arborctl pin`, `unpin` or `toggle-pin`.

- A pinned window floats and keeps its place on the display through every change of view. Docked windows
  neither avoid it nor push it: it overlaps them, which is the point.
- Arbor brings it to the front again when the view changes or a click on another window covers it. It never gives
  it the keyboard, and a command that moves the view takes the keyboard along to the window that arrives, also out of
  a pinned window you had clicked in: keys meant for your editor do not end up in a call.
- ⌃⌥↩ in a pinned window fills the screen with it, as with any floating window, and again takes it back. It stays pinned.
- Dragging moves it and never docks it. `dock` (⌃⌥← and ⌃⌥→) and ⌃⌥F dock it, which ends the pin, and the reply
  says so. Pinning a docked window floats it first.
- Arrange Windows leaves it out. Float All Windows, pausing and quitting leave it exactly where it is.
- Pins are saved with the arrangement. If the window's app restarted, the pin goes to its window with the
  same title. If its display is unplugged it comes to the main display, and goes back afterwards.
- A rule pins a window as it opens: `{ "app": "us.zoom.xos", "title": "Meeting", "action": "pin" }`.
- There is no default shortcut. To have one: `"bindings": { "ctrl+opt+shift+d": "toggle-pin" }`.

What it cannot do: macOS does not let one app change the level of another app's window. So a pinned window is
covered for a moment when you click the window under it, menus and other apps' always-on-top panels
stay above it, and it follows you neither into another app's full screen nor to another of the macOS Spaces
(for that, right-click the app in the Dock: Options → All Desktops).
## Go to…

⌃⌥G (or "Go to…" in the menu) opens a palette that lists every window Arbor arranges, on every display, the windows of
apps you told it not to arrange, every named space and every saved view. Type to narrow it down:

- Letters match in order but need not be together: `sfr` finds Safari, `gc` Google Chrome, `v3` View 3.
- Several words must all match, in any order, in the app's name or the window's title: `docs saf`.
- Capitals and accents do not matter.
- The name of a space typed in full always comes first.
- The best match is on top: beginnings of words, letters that follow each other and the app's name count for more. Between
  equals, the most recently used window comes first.

↑ ↓ or ⇥ ⇧⇥ move the selection, Return goes there, ⌘1–⌘9 or a click choose a row directly, Escape or ⌃⌥G again closes the palette. At the right
of each row is where the window is now: in view, out of view, tab, tile, floating, kept in view, summoned, out of view until summoned, minimised, hidden, full screen, on another macOS Space, not arranged, and on
which display if there are several.

**It finds commands too.** Type the beginning of what a thing is called in the menu, go down to it with ↓ and press Return: `bal` ↓ ↩ is Arrangement ▸ Balance Sizes, `dock left` Dock Focused Window ▸ Left, `float all` Float All Windows.
Return alone never runs a command: letters and Return go to a window, a space or a saved view, or beep. What matches of those comes first, then the commands. Every row of
the menu that runs a command is there, and the commands that have no row there (Space to the Left, Window Above). A command's row says `command` at the right, with its shortcut if it has one, or `not now` where
the menu would grey it out. It acts on the window you were in. Before you type, the list holds places only, and a piece of a window's name still finds the window first.

A shortcut can go straight to a window: `"ctrl+opt+cmd+f1": "find mail inbox"` in `bindings`. (`find` with text goes to places; it never runs a command.)

## Summoning

Some apps are visited for ten seconds, many times a day. Giving them a place wastes space; leaving them on the
Desktop means a trip there and back. Give each a shortcut in `settings.json` instead (there are no defaults):

```json
"bindings": { "ctrl+opt+`": "summon com.apple.Terminal", "ctrl+opt+'": "summon Notes" }
```

- `summon <app>` takes the app's name as the Dock shows it, or its bundle id. The window of that app you used last appears
  over the view on the display you are working on (where shortcuts act), with the keyboard in it: the first time in the middle at its own
  size, afterwards where you last left it on that display, also after a restart. The view does not move, and no other window does.
- The same command again sends it out of view and gives the keyboard back to the window that had it. Turning to another
  app's window sends it away too; `"summonStays": true` keeps it until you summon it away.
- Once summoned, a window no longer lives on the Desktop: sent away, it stays out of view in every view, Show
  Everything (⌃⌥Space) included, until you summon it again or switch to it (⌘Tab, its Dock icon), which summons it. `arborctl home`, the way back
  for a window you cannot find, puts it back on the Desktop as an ordinary window; so do docking it, pinning it and Float All Windows. Pausing
  and quitting bring it into view like every other window, and after a quit it stays there: the next launch has it as an ordinary window.
- If the app has no window, is hidden, or is not running, it is opened as a click on its Dock icon would, and its window is summoned if it
  appears within five seconds.
- A docked window has a place, and the place wins: `summon` moves the view to it, as ⌘Tab would, and `summon` again goes back where you were, view and keyboard. So one key does for an app wherever its window lives. Once you have moved the view or turned to another window there is no "back", and the next press goes to the window again. A pinned window just gets the keyboard.
- One window is summoned at a time on each display: summoning another app sends the first away.
- A window you are typing in, where you put it, is summoned where it is and does not jump; that is its place from then on.
- `float` makes a window that comes and goes with `summon` an ordinary floating window again. `zoom <window>` on one that was
  sent away summons it: it has no place the view could go to.
- While it is summoned, dragging moves it and never docks it, and Arrange Windows leaves it out. A command that moves the view
  takes the keyboard along to the window that arrives, which sends the summoned window away; ⌃⌥↩ un-frames what is beneath it.

## Command line

Copy the command, not the remark after `#`: at its prompt macOS's own shell, zsh, does not take `#` for a comment.

```bash
arborctl help                 # every command (works without Arbor running)
arborctl state                # JSON: displays, trees, windows
arborctl ascii                # the layout drawn as text
arborctl dock 412 beside 388 bottom
arborctl zoom                 # frame the focused window
arborctl bindings             # the keyboard shortcuts in effect
arborctl stats                # what commands cost on this Mac
arborctl displays             # the displays, and the options in effect on each
arborctl show-shortcuts       # the same by name, on screen and in the terminal
arborctl home                 # show everything on every display
arborctl name Writing Desk    # name the space in view; `unname` takes the name off
arborctl go wri               # go to the space of that name, or the only one that begins so
arborctl spaces               # the named spaces, what they hold and where they are
arborctl pause 45             # let go of windows, shortcuts and gestures for 45 minutes
arborctl resume
arborctl hold 60              # keep the view exactly where it is for an hour, whatever happens
arborctl hold still           # the view moves only when you ask; apps that come forward stay out of view
arborctl release
arborctl relayout             # lay everything out again; a window stuck as a tile gets another try
arborctl doctor               # what could keep Arbor from working, checked
arborctl pass-through org.gnu.Emacs on   # shortcuts and gestures off in Emacs; `off`, or without a word to toggle
arborctl toggle-pin           # keep the focused window in view wherever you zoom, or stop
arborctl version              # the running build, and what the last update check found
arborctl check-for-updates    # ask GitHub for a newer release; nothing is ever downloaded
arborctl launch-at-login on   # or off; without a word it answers on or off
arborctl set gap 16           # change a setting, at once; `arborctl settings` lists them all
arborctl find safari docs     # go to the window, space or saved view that matches best
arborctl reveal 412           # bring a window into view, un-minimised and unhidden, and focus it
arborctl trace on safari-drag # record what macOS and Arbor tell each other, until `trace off` (docs/TRACES.md)
arborctl summon Terminal      # Terminal's window over the view; again, and it is out of view
arborctl watch view focus     # one line of JSON whenever the view or the focused window changes
arborctl toggle-auto-dock     # new windows dock beside the focused window, or float as usual
```

It exits with 0 when the command worked, 1 when Arbor said no (the reason goes to standard error), 2 when Arbor is not
running, 4 when it did not answer in time. `arborctl - < file` runs a file of commands, `arborctl completions zsh` prints a
completion script, `arborctl --help` lists the options.
[Scripting Arbor](docs/SCRIPTING.md) has every event, `state`, URLs, exit codes, and
recipes for SketchyBar, shell loops and `jq`.

`arborctl <command> --json` prints the whole reply as JSON, refusals too; the exit code stays.
Every command but `help` is answered by a running Arbor.

`make install` links `arborctl` onto your `PATH`. `swift build` puts it in `.build/debug/`; `make app` puts it in
`Arbor.app/Contents/Helpers/`.

### Arrangements as a line of text

`|` side by side, `/` one above the other, `( )` a group, `[ ]` a tab group, `:2` twice the size, `Desktop` the Desktop. Names are app
names or bundle ids. On its own, `layout` prints the arrangement you have, in the same notation:

<!-- windows: Safari, Mail, Notes, Slack -->
```console
$ arborctl layout "Safari:2 | (Mail / Notes)"
arranged 3 windows
$ arborctl layout
Safari:2 | (Mail / Notes) | Desktop:0.75
$ arborctl layout "Safari | Mail / Notes"
layout, column 15: `|` and `/` are mixed here: put brackets around one of them
  Safari | Mail / Notes
                ^
```

Windows that are not mentioned float; apps without a window are skipped and reported, or opened with `--open`; `Safari*` takes all of
Safari's other windows as tabs; `@2` names another display. A line can be bound to a shortcut
(`"ctrl+opt+cmd+1": "layout Safari:2 | (Mail / Notes)"`), kept in dotfiles or sent as a URL. [docs/LAYOUTS.md](docs/LAYOUTS.md) has all of it.

## URLs

`arbor://` followed by a command's words, separated by slashes: `arbor://show-all`,
`arbor://dock/left`, `arbor://view/2`, `arbor://zoom/412`, `arbor://arrange`, `arbor://go/Writing/Desk`.

Any web page, document or message can ask macOS to open a URL, so URLs can only
move the view and arrange windows: `show-all`, `home`, `out`, `in`, `neighbor`, `back`,
`forward`, `zoom`, `zoom-node`, `desktop`, `save-view`, `view`, `go`, `frame-rect`, `dock`,
`float`, `toggle-float`, `arrange`, `resize`, `relayout`, `pin`, `unpin`, `toggle-pin`, `undo`, `redo`, `layout` (the line percent-encoded:
`arbor://layout/Safari%20%7C%20Mail`; not with `--open`, which can launch apps) and the commands under
[Arranging from the keyboard](#arranging-from-the-keyboard) except `focus <window>`, `swap <window> <direction>`, `focus-display` and
`move-to-display`, which pick where the keyboard types. Everything else (`quit`,
`exclude`, `include`, `pass-through`, `float-all`, `pause`, `resume`, `hold`, `release`, `reload-settings`, `toggle-auto-dock`, `name`, `unname`, `ask-name`, `find`, `reveal`, `summon`, which can launch any app, and the queries) is refused with a
beep and a line in the log. So are `arrange` and `layout` where they would cost you a saved view or the name of a space: they start the arrangement afresh, and
a link may arrange but not take away what you made. If you want those from your own launcher or Stream
Deck too, set `allowAllURLCommands` to true in `settings.json`; `arborctl`, the menu
and keyboard shortcuts are never restricted.

## Undo and redo

```bash
arborctl arrange              # oops
arborctl undo                 # "undid arrange": every window, size and saved view is back, and so is the view
arborctl redo                 # "redid arrange"
```

⌃⌥Z and Redo, in the menu, step through the last 50 changes to the arrangement of the display you are working on: docking,
moving, floating, Arrange Windows, Float All Windows, resizing (one drag of a gap or of a window's edge is one
step, and so are quick repeats of `resize` on one edge), dropping a dragged window, and windows docked by a rule.

- Moving the view is not a change to the arrangement: that is what Back (⌃⌥[) and Forward are for. Undo leaves the view
  where it is, unless the change itself moved it or the space it shows no longer exists. If nothing of the change
  would show in the view (one window is framed, the change was elsewhere), the view steps out just far
  enough to show it, and ⌃⌥[ goes back.
- Windows that closed in the meantime stay closed, windows that opened in the meantime stay floating, and a
  floating window you have moved since stays where you put it.
- What cannot be taken back is said once. After a docked window closed, the first ⌃⌥Z only says so, low on the
  display (`arborctl undo`:
  "cannot undo the closing of a window of Notes; undo again to take back dock w101 left"); the next one goes on.
- What changed several displays at once (Float All Windows, `arrange all`, a window dragged from one display to
  another) goes back with one undo on any of them.
- The history is kept per display until Arbor quits or the display is unplugged.

## Settings

**Settings…** in the menu (Arbor is never the app in front, so ⌘, cannot reach it) opens a window with the everyday
settings by section, the rarer ones behind Advanced, a search field, and editors for your shortcuts, your rules and the
lists of apps (the ones Arbor does not arrange, for one). A value Arbor cannot use is refused under its control, with the reason.
`arborctl settings-window shortcuts` opens it at a pane.

The window changes nothing that a command cannot: `arborctl set gap 16` does the same, and so does editing
`~/Library/Application Support/Arbor/settings.json` (menu → Help → Settings File…). Whichever way, it
applies at once and shows in the other two. `arborctl settings` lists every setting with its value, range and default, `arborctl get gap`
prints one, and `arborctl reset gap` goes back to the default. A value Arbor cannot use is refused by `set`, and
in the file it costs only its own key. The file holds only what differs from the defaults, so what you have not changed follows them when a later
version changes one. [docs/SETTINGS.md](docs/SETTINGS.md) is the complete reference; these are the main ones:

| Key | Default | Meaning |
|---|---|---|
| `gap` | 12 | Points between windows and around the edges |
| `minimumUsableWidth` / `minimumUsableHeight` | 240 / 160 | Smaller spaces become tiles |
| `screenEdgeBand` | 12 | How close to a screen edge a drag must come to dock there |
| `windowEdgeFraction` | 0.3 | The band along a window's edges that docks beside it |
| `tabsEnabled` | false | Dropping on a window's middle stacks them (no tab strip yet) |
| `excludedBundleIDs` | [] | Apps Arbor never arranges |
| `hotkeysEnabled` | true | Global shortcuts |
| `shortcuts` | "core" | Which shortcuts Arbor binds itself. "core": the nine, each ⌃⌥ and one key. "all": the whole map, some fifty, with ⇧ and ⌘ as well. `bindings` changes single keys on top of either (see [Keyboard](#keyboard)) |
| `arrangeDesktopWeight` | 0.5 | Width of the Desktop column made by Arrange, in window columns; also by `layout` when the line does not mention the Desktop |
| `bindings` | {} | Changes to the keyboard shortcuts (see [Keyboard](#keyboard)) |
| `rules` | [] | What happens to new windows of an app (below) |
| `gesturesEnabled` | true | Trackpad pinch with ⌥, or over the Desktop, steps the camera |
| `pinchThreshold` | 0.25 | How far a pinch must go for one step (smaller is more sensitive) |
| `frameRectangleModifier` | "ctrl+opt" | Keys to hold while dragging a rectangle to frame, starting anywhere; "none" turns it off |
| `summonStays` | false | A summoned window stays when you turn to another window, until summoned away (see [Summoning](#summoning)) |
| `allowAllURLCommands` | false | Accept every command from `arbor://` URLs, not only those that move the view and arrange windows (see [URLs](#urls)) |
| `focusRing` | true | A line around the focused window, once something is docked |
| `focusRingWidth` | 3 | Its thickness in points, 1 to 12 |
| `focusRingColour` | "accent" | "accent" (from System Settings), "#RRGGBB" or "#RRGGBBAA" |
| `focusRingRadius` | 0 | The radius of the window corners it follows; 0 picks 17 on macOS 26 and 10 before |
| `newWindowsWhileFramed` | "guest" | A window that opens over a view that does not show the Desktop (a framed window, a group) stays with that view: it goes out of view and comes back with it. "float": it belongs to the Desktop like any floating window |
| `shareRemovedSpace` | true | A window that leaves (closed, floated, dragged out, minimized, hidden with ⌘H) gives its space to everyone in its group; false gives it to the neighbour before it, and nothing else moves (except where `dock <edge>` has to take a little from everyone to keep a window usable) |
| `shrinkOutOfView` | false | Windows out of view are also made small, 320 × 200 at most, until they come back (some apps rearrange their contents when they are made small) |
| `ruleTitleWait` | 2 | Seconds (at most 60) a new window's title is checked against rules with a `title`; 0 checks only its first title |
| `frameRectangleOnDesktop` | true | While something is docked on a display, ⇧-drag that starts on the bare Desktop, in a gap or on a tile there also frames a rectangle |
| `guardDesktopClicks` | false | An experiment, not yet seen at work on a Mac. While something is docked on a display, a plain click on the bare Desktop or in a gap there is kept from macOS, which would sweep every window aside. Drags, icons and widgets are left alone, and so is every click while a menu, Spotlight or anything else of the kind is open |
| `scrollZoom` | true | Scrolling with ⌃⌥ held steps in (up) and out (down); off with `gesturesEnabled` too |
| `scrollZoomThreshold` | 40 | Points of travel for one step on a Magic Mouse or trackpad; a wheel steps once per notch |
| `scrollOnDesktopZooms` | false | Scrolling on the Desktop, in a gap or on a tile zooms without the keys. Every scroll on the Mac then passes through Arbor |
| `continuousZoom` | false | Not finished: the view will follow the fingers during a pinch, and slide with ⌃⌥ and two fingers sideways. For now a pinch steps as before |
| `tileRetryMinutes` | 10 | A window that is a tile because it refused the size of its space is asked again, out of view, this many minutes later; 0 never asks (`arborctl relayout` always does) |
| `stepInToward` | "auto" | Which display a shortcut acts on, and what Step In steps toward: "auto" (the focused window, or the pointer if it moved last), "pointer" or "focus" (see [Keyboard](#keyboard)) |
| `peek` | true | Holding the Show Everything shortcut peeks: let go to frame what is outlined (see [Keyboard](#keyboard)) |
| `passThroughApps` | [] | Apps (bundle ids) that keep their own ⌃⌥: no shortcuts but ⌃⌥⎋ and no gestures in them (see [Keyboard](#keyboard)) |
| `shortcutsFollowLayout` | true | A letter, digit or sign in a shortcut is the key that types it on the keyboard layout in use; false: its place on a US keyboard |
| `pauseForApps` | [] | Apps (bundle ids) Arbor pauses for while one is in front, as ⌃⌥⎋ does, and resumes after: games, anything that changes the display's resolution |
| `holdStillWhileCameraIsOn` / `holdStillWhileMicrophoneIsOn` | false / false | Hold still (below) by itself while any app has a camera or a microphone running |
| `holdStillFor` | [] | And while such a window is open. A bundle id, then optionally part of the title (without it any window of the app counts, minimized ones too), for example `"us.zoom.xos Zoom Meeting"` (written from memory: check the title on your Mac) |
| `animationDuration` | 0.46 | Seconds a zoom, dock or close takes to play, up to 2; 0 applies everything at once |
| `windowPictures` | false | Not ready, see [Install and run](#install-and-run): windows keep their contents while they move, with Screen Recording permission |
| `automaticUpdateChecks` | false | Ask GitHub for a newer release a minute after starting and weekly. No window opens: the menu item then reads Update Available… |
| `dropDwell` | 0.15 | Seconds to hold a dragged window over a window or tile before it can be dropped there (0 to 2); screen edges never wait |
| `previewDrags` | true | Show where a dragged window will land. Without it nothing has to be held either |
| `reflowWhileDragging` | false | While you drag, the other windows close up and make room, showing what letting go would do |
| `keepPushed` | true | With `reflowWhileDragging` and `floatingWindowsMakeWay`: floating windows pushed aside stay there until the drag ends |
| `menuBarControls` | true | Buttons in the menu bar item; false shows a single icon that opens the menu |
| `historyButtons` | true | Back and forward among those buttons |
| `menuBarFill` | 0.25 | How strongly the button for where you are is filled in, from 0 to 1 |
| `makeRoom` | true | Before a window becomes a tile because its app will not shrink that far, move the gaps around it and take the room from the Desktop and from neighbours that can spare it. For the window being typed in the neighbours give more: they become the tiles |
| `soleFloatTakesDesktop` | false | A window that floats alone beside docked windows takes the whole Desktop, and has its own size back as soon as a second one floats. Only with `floatingWindowsMakeWay` |
| `floatingWindowsMakeWay` | false | Docked windows push floating windows aside and squeeze them, so that they stay on the Desktop. Off, a floating window stays exactly where you put it |
| `resizeStep` | 40 | Points `grow` and `shrink` add or take when no amount is given |
| `displays` | [] | Other values of `gap`, `minimumUsableWidth`, `minimumUsableHeight` and `screenEdgeBand` for particular displays (below) |
| `messages` | "helpful" | What Arbor says on screen after a shortcut, a gesture or a menu item: "helpful" (problems, unseen changes, a few hints), "all" (every reply) or "off" |
| `dimBehindArranged` | 0.25 | Darken behind docked windows: how much darker the wallpaper is there, from 0 (not at all) to 1 (black) |
| `blurBehindArranged` | 0 | Blur behind docked windows: from 0 (sharp) to 1 (all the blur macOS has) |
| `appColours` | true | Tiles take on their app's colour; false: every tile is the same grey |
| `appColourAmount` | 0.25 | How much of the app's colour goes into its tile, from 0 to 1 |
| `gapHandles` | "shown" | The gaps between docked windows. "shown": drag one to resize both sides, and a handle shows in it under the pointer. "hidden": the same without the handle. "off": gaps cannot be dragged (window edges and `arborctl resize` still resize) |
| `tileStyle` | "icon" | What a tile shows on its colour: "icon", "name" (the icon and the app's name) or "plain" (nothing). A space you named shows its name either way |
| `tintBehindArranged` | 0 | Tint behind docked windows: how much of your accent colour is laid over the wallpaper there, from 0 to 1 |
| `desktopEdge` | 0.05 | How strong the hairline around the Desktop is where it lies between docked windows, from 0 (none) to 1 |
| `tileFade` | 0.2 | Seconds a tile takes to fade in and out, from 0 (at once) to 1 |
| `newWindows` | "float" | What a new window does when no rule matches it. "dock": it docks beside the focused window (below). The menu's "Dock New Windows" and `toggle-auto-dock` switch it |
| `autoDockMinimumWidth` / `autoDockMinimumHeight` | 400 / 300 | A window that opens smaller than this is never docked by `dock auto` or by a rule for `*` |
| `minimapDuration` | 0 | Seconds (at most 10) the minimap shows by itself after the view has moved; 0 is off, Show Minimap shows it either way |
| `pointerGestures` | false | The one switch above the pinch, ⌃⌥ + scroll, both ways to draw a rectangle and `guardDesktopClicks`. false: Arbor installs no event tap, so it holds back no click, scroll or pinch of the Mac, whatever their own settings say. Dragging windows, gaps and tiles works either way |

The file is yours. When a command changes a setting (`set`, `bind`, `rule add`, "Don't Arrange"…), Arbor
changes that setting in the file and leaves the rest as you wrote it: your order and spacing, keys
it does not know, and values and entries it could not use. It never writes to a file it cannot read.
After a typo, Arbor keeps the settings in use, `arborctl reload-settings` says where the typo is
(``line 3, column 3: expected `,` or `}` after the value of `gap`, found `"` ``), and commands that change
settings are refused until it is fixed; if Arbor starts with such a file, it uses the defaults meanwhile.
`arborctl reset everything` is the way out: it writes a new file and keeps the old one as `settings.unreadable.json`.
A change that cannot be saved (the file is read-only, say) is refused too, so what is in use is always what the file says.

Missing keys take their defaults and unknown keys are ignored.

### Rules for new windows

```json
"rules": [
  { "app": "com.apple.Terminal", "action": "dock right" },
  { "app": "com.apple.mail", "title": "Inbox", "action": "dock left" },
  { "app": "com.tinyspeck.slackmacgap", "action": "dock beside com.apple.mail bottom" },
  { "app": "com.apple.finder", "action": "ignore" },
  { "app": "us.zoom.xos", "title": "Meeting", "action": "pin" }
]
```

Rules are checked in order and the first match wins. `app` is a bundle id;
`title`, if given, must appear in the window's title (ignoring case) when the
window opens. Actions: `float` (what happens without a rule), `dock <edge>` (at
that edge of the view), `dock beside <bundle id> <edge>` (next to that app's most
recently focused docked window on the same display, or at that edge if it has
none), `ignore` (Arbor leaves the window alone) and `pin` (it floats and
[stays in view](#pinned-windows)). Rules apply only to windows
that open while Arbor is running, except `ignore`, which also applies to windows
that were already open, so an ignored window stays ignored when Arbor restarts.
Browsers and editors give a window its real title a moment after it opens, so a
rule with a `title` can still take over during the window's first two seconds
(`ruleTitleWait`), unless you have moved the window yourself by then. `arborctl rules` lists them,
shows any it could not read and why, and says which one the focused window matches.
`arborctl rule add com.apple.mail dock left title Inbox`, `rule change <n> …`, `rule remove <n>` and
`rule move <n> <place>` edit the list without opening the file.

### Options per display

A large display wants wider gaps and larger tiles than a laptop's:

```json
"displays": [
  { "match": "builtin", "gap": 8 },
  { "match": "Studio Display", "screenEdgeBand": 24 },
  { "match": ">=2500", "gap": 16, "minimumUsableWidth": 300, "minimumUsableHeight": 200 }
]
```

The first match wins, as for rules, but key by key: on a display, each of `gap`, `minimumUsableWidth`, `minimumUsableHeight` and
`screenEdgeBand` has the value of the first entry that matches the display and sets it, and the general value if none does. So a
particular entry goes before a general one and need not repeat it: the Studio Display above is 2560 points wide, takes its band from
its own entry and the rest from `>=2500`. `match` is `main` (the display with the menu bar), `builtin` (a laptop's or an iMac's
own), the display's width in points compared with a number (`>=2500`, `>`, `<=`, `<`), its UUID, or part of its name; not its number,
which changes with the arrangement of the displays. `arborctl displays` lists your displays with their names, sizes and UUIDs, each
value in effect and the entry it comes from, and any entry it could not read and why. `arborctl set gap 20` changes the general
value and says which displays keep their own.

A `*` at the end of `app` stands for the rest of the bundle id: `com.jetbrains.*` is every JetBrains app, `*` alone is
any app.

### New windows that dock by themselves

`"newWindows": "dock"` (menu → Arrangement → Dock New Windows) is short for one more rule at the end of the list:

```json
{ "app": "*", "action": "dock auto" }
```

so your own rules come first: a `float` rule keeps an app out of it. `dock auto` puts the window **beside the docked
window you were last working in** on that display, in half of its place: to its right if that place is wide, below it if it is tall.
If that window is too small to share, the largest window in view shares instead (with `tabsEnabled`, the new window first tries to join the one you
were in as a tab). With nothing docked it takes the right edge of the view, and leaves an empty Desktop the share "Arrange Windows" gives it
(`arrangeDesktopWeight`).

What it never does:

- **Dock windows that are not worth a place.** Windows that open smaller than 400 × 300 points (inspectors, palettes, Get Info) and
  windows whose size cannot be changed (Calculator, most settings windows) float. The same goes for any rule for a `*` app that
  docks. A rule that names an app in full is obeyed as written.
- **Make a tile.** If anything that is showing would become too small to show, the new window included, it floats where its app
  put it. Arbor asks the new window to take its place before it moves anybody else, so a window that refuses (Notes will not go
  below 709 points) disturbs nobody.
- **Move the view.** The window lands inside what you are looking at. Framed on one window, it floats over it and stays with that view
  (`newWindowsWhileFramed`); looking at the Desktop alone, it floats there.
- **Touch windows nobody just opened**: those that were open when Arbor started or resumed, or that it first sees when you switch to
  another macOS Space. "Arrange Windows" docks those.
- **Pull a window out of your hand**: nothing docks while the mouse button is down, so a tab you tear off a browser goes where
  you drop it.

### Calls, shared screens and recordings

| | Windows | The view moves by itself | Your keys and gestures |
|---|---|---|---|
| **Pause** (⌃⌥⎋) | all come into view, in their own sizes; Arbor lets go of them | | are handed back to the apps |
| **Hold Still** | stay as they are | no | work as ever |
| **Hold This View** | stay as they are | no | cannot move the view either, until you release it |

Both holds are in the menu, and so is **Release**, under a line that says what is going on. Neither has a shortcut to begin it (bind `toggle-hold`
in `bindings` if you want one). While either is on:

- a window that is out of view and takes the keyboard **stays out of view**, and the keyboard goes straight back to the window that
  had it. Holding still, Arbor lets through what you did yourself: a change of app within half a second of a click or of letting go
  of a modifier key (a Dock or notification click, ⌘Tab). Switching with Spotlight or a launcher counts as the app's own doing;
- new windows float where their app puts them, and rules that would dock them wait until the hold ends. Holding still, a window you
  opened yourself (within half a second of a click or a modifier key: ⌘N) is docked at once;
- **the end of a hold moves the view no more than the hold did**, because it can come by itself (the time is up, the call is over) with the
  screen still shared. A rule that waited is applied only if the view stays where it is and nothing else comes into view, and not to a
  window you have moved meanwhile. Otherwise the window goes on floating, and `release` says so: "released; Terminal was left floating".

**Hold This View** also refuses everything that moves the view ("the view is held"), switches pinch and ⌃⌥-drag off, and lets you
rearrange only the windows that are in view, and only in ways that bring nothing else in. The menu bar icon turns into a lock.
The keyboard goes on working among them: `focus <direction>` (⌃⌥⇧ + arrow in the whole map) goes from window to window and stops at the edge of the view, and `swap`, `grow`,
`shrink`, `balance`, `rotate` and `mirror` do what they always do; a tile is passed over, and nothing crosses to another display.

- **It never widens by itself.** If the only window in view is minimized, hidden or closed (⌘M, ⌘H and ⌘W are pressed without a thought), goes
  into full screen or is on another macOS Space, the display shows the wallpaper and the view stays held, until the window is back or
  you release. The menu says "The view is held: nothing is in it".
- **A slip on a key does not end it in front of everybody.** Pause and Float All Windows bring every window into view. From the menu
  and from `arborctl` they work and end the hold. On the keyboard, **⌃⌥⎋ releases the hold** and moves nothing (press it again to
  pause), and a key bound to Float All Windows is refused like every other key.
- It ends with **Release** in the menu, ⌃⌥⎋, `release`, Pause or Float All Windows from the menu, quitting, or `hold <minutes>` running out.

**Hold Still** is for calls: choose it from the menu when you share, or run `hold still`. Your own keys, gestures, ⌘Tab, Dock clicks and Go to… work as ever;
what pushes itself forward stays out of view and you go on typing where you were. Arbor cannot see who asked and goes by time, so a launcher, `open` in a
terminal or a link whose browser is slow can be turned away too. It is never done in silence: "Terminal is out of view: holding still · ⌘Tab or ⌃⌥G goes there",
once for each app and hold.

**Out of the box Arbor holds only when asked.** It can start Hold Still by itself during a call and end it with the call; the menu then says why ("Holding still
while the camera is on"). macOS does not tell apps whether the screen is being shared or recorded, but it does tell every app, without asking you, whether some
app has a camera or a microphone running: Arbor only reads that, and opens neither. `arborctl set holdStillWhileCameraIsOn true` makes a camera do it for you. All
three signs are off until they have been seen at work on a Mac: a camera that is on is not a screen that is shared.
A window listed in `holdStillFor` counts as a call too. Release during a call lasts until that call is over.
The microphone (`holdStillWhileMicrophoneIsOn`) is for calls without a camera: it is not yet known what else keeps a
microphone running on a Mac ("Hey Siri", dictation), nor whether muting ends it. Only devices that are microphones and nothing else count then, because a
headset that is one device for both directions is "running" while it plays music.

**What a share shows of windows that are out of view.** macOS does not let a window be moved wholly off the screen. Each waits at a bottom
corner of its own display with one point of its width on screen; because macOS also keeps title bars above the Dock, that is a line one point
wide, about 20 points tall with the Dock hidden and 85 with it showing, in the colours of the front one. Nothing can be read in it, but it can
be seen. To macOS, windows that are out of view are ordinary windows, so expect them in the window pickers of Zoom, Meet and Teams.
## If something goes wrong

- **Quit Arbor** (menu, or `arborctl quit`) puts every window back in view. So does logging out.
- **Force Quit and `kill -9` bring Arbor back**: a small second process, `Arbor --watchdog`,
  starts it again whenever it ends without quitting, because windows may be parked out of
  view. After three such endings within two minutes Arbor instead brings every window into
  view, sets its saved arrangement aside and stays away.
- `ARBOR_RESCUE=1 ~/Applications/Arbor.app/Contents/MacOS/Arbor` does that last part by hand.
- Only one Arbor runs at a time; a second copy says so and leaves.
- The log is `~/Library/Application Support/Arbor/arbor.log` (menu → Help → Show Log).

## Development

```bash
make check     # build, run all tests, the simulator smoke test and the user-journey scenarios
make sim ARGS='"open Safari" "open Notes" "dock 101 left" "dock 102 right" "zoom 101"'
make e2e       # real windows; needs Accessibility for your terminal
make trace NAME=safari-drag   # record something odd on real windows; it becomes a test that runs anywhere
make replay FILE=collab/evidence/traces/drag-to-edge.jsonl   # see what happened in a trace
```

`make check` and the tools in `scripts/` want a `python3`, 3.9 or later.
Building and installing Arbor needs none.

Arbor is built by agents in two roles, a documenter and executors, who
collaborate through this repository: see [collab/README.md](collab/README.md),
the [board](collab/BOARD.md), and the generated
[feature comparison with TrellisWM](docs/FEATURES.md). Also
[CLAUDE.md](CLAUDE.md) (for human contributors too),
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/TESTING.md](docs/TESTING.md),
[docs/ROADMAP.md](docs/ROADMAP.md), and for anyone writing text users see, [docs/GLOSSARY.md](docs/GLOSSARY.md) and [docs/MENU.md](docs/MENU.md).
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/TESTING.md](docs/TESTING.md), [docs/TRACES.md](docs/TRACES.md),
[docs/ROADMAP.md](docs/ROADMAP.md), and for anyone writing text users see, [docs/GLOSSARY.md](docs/GLOSSARY.md).

## License

MIT
