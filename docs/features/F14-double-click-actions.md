# F14: Double-click actions

Status: done; both double-clicks ship off. Each ships on once `scripts/mac-shell/check-F14.sh` has nothing against it on a hosted Mac (see "How it is proved")
Depends on: F01

## Summary

TrellisWM uses double-clicks as quick camera moves: double-click a window's
title bar to give it the whole screen, double-click the Desktop to focus on
it, and double-click again to step back. Arbor has keyboard commands for all
of these but no double-click equivalents, and it opens tiles on a single click.

## Behaviour

- **Title bar**: double-clicking a docked window's title bar frames that window
  (`zoom <id>`). Double-clicking it again while it is framed goes back. This
  replaces macOS's own title-bar double-click action (zoom or minimize, set in
  System Settings → Desktop & Dock) for docked windows only; floating windows
  keep the macOS behaviour.
- **Desktop**: double-clicking bare wallpaper inside the Desktop's area focuses
  the Desktop (`desktop`); double-clicking it again while the camera is on the
  Desktop goes back.
- **Tiles**: open on double-click instead of single click, matching TrellisWM;
  a single click selects (highlights) the tile. Setting `tileClick` with values
  `single` (today's behaviour) and `double` (default).
- Setting `titleBarDoubleClick` (default true) turns the title-bar action off.
- **macOS gets the first click on the wallpaper.** With "Click wallpaper to
  reveal desktop" set to Always (System Settings → Desktop & Dock; the
  default since macOS 14), one click on the Desktop's area sweeps every
  window to the screen edges, Arbor's docked windows included, and
  Accessibility reports nothing. The swarm saw this on macOS 26.6
  (`feat/review-ux`, F42). A Desktop double-click therefore starts by
  sweeping the windows aside. Before building the Desktop action, try on a
  Mac whether an event tap that swallows the first click stops the sweep. If
  it does not, ship the title-bar and tile parts and have the Desktop part
  wait for F42's setup check to ask for "Only in Stage Manager".

## Design notes

- Detection needs the global mouse monitor that `AXWindowSystem` already
  installs. Add `doubleClicked(at:)` to `WindowSystemEvents` (append at the end
  of the protocol) and a simulation helper on `FakeWindowSystem`.
- Deciding what was double-clicked is controller logic and testable: a point
  inside a docked window's frame within 28 points of its top edge is its title
  bar; a point inside `layout.desktopFrame` with no floating window under it
  is the Desktop. Put it in a new `Controller+DoubleClick.swift`.
- Stopping macOS's own title-bar action needs the event to be swallowed,
  which an `NSEvent` monitor cannot do. Use the `EventTap` helper from F03/F05
  (`Input/EventTap.swift`) once it has merged.

## Acceptance criteria

1. Double-click a docked window's title bar: the camera frames it; again: back.
2. Double-click the Desktop: the camera moves to the Desktop; again: back.
3. Double-clicks inside a window's content, or on a floating window, do nothing in Arbor.
4. Tiles open on double-click by default and on single click with `tileClick: "single"`.
5. Old settings files still load.
6. `make check` passes. On a hosted Mac (was a manual check; board, section 5): real double-clicks on real apps' title bars, with macOS's own
   title-bar action set to Zoom, Fill, Minimize and None: one of the two acts, never both (`fought`, `jolt`); a double-click that is not Arbor's reaches the app (`input-held`).

## Shipped

- **Off as Arbor comes**, each switch until the run on a hosted Mac has nothing against it ("How it is proved", below).
  `arborctl set titleBarDoubleClick true`, or "Double-click title bars" in the settings window, turns it on, under `pointerGestures`, the
  one switch above everything that needs an event tap. With both switches off
  **no tap of F14's is installed at all**, not an idle one, and the zones are empty (`bothDoubleClicksAreOffByDefault`;
  `check-F14.sh` asks the window server).
- **Title bars.** Double-clicking the top 28 points of a docked window frames it (`zoom <id>`). Double-clicking the
  title bar of the window that fills the view un-frames it by the rule ⌃⌥↩ pressed again follows, one shared function
  (`Controller.wayOut(of:on:)`): `back` if that leads to a wider view, otherwise `out`; with nothing wider nothing happens.
  Turning the switch on replaces macOS's own title-bar action (System Settings → Desktop & Dock → "Double-click a window's
  title bar to") **for docked windows only**: floating windows, and windows Arbor does not arrange, keep macOS's.
- **Framing replaces "make it big", and nothing else** (the product owner's decision). Arbor takes title bars only while macOS's own
  action there is Fill or Zoom, which is how macOS comes. Whoever chose Minimize or Do Nothing has said what they want: Arbor then
  leaves title bars alone whatever its switch says, with no zones and, unless the Desktop's switch is on, no taps
  (`MacTitleBarAction`, `WindowSystem.macTitleBarAction()`, `Controller.inputSettings`). The setting is read afresh at every layout
  while the switch is on. So that nobody wonders why the switch does nothing, `doctor` and the settings window's row say
  "macOS is set to minimize at a double-click, so Arbor leaves title bars alone". The Desktop's double-click is not touched by this.
- **It happens when the button comes up**, as macOS's own action does. A second press that moves more than 4 points before
  that is a drag: the app is given the mouse-down it missed and everything after it. So clicking a title bar and at once
  dragging it, and dragging with a double tap on a trackpad set up for that, still move a docked window elsewhere.
  The strip is where the window really rests, so a window that cannot grow to its slot and sits in the middle of it works too.
- **One double-click, one answer** (below): never both macOS's action and Arbor's, and what macOS makes of a docked window where
  the double-click is not Arbor's is not undone (K193).
- **The Desktop**, with `desktopDoubleClick`, which **ships off** as long as macOS's own wallpaper click sweeps the windows aside
  first. Double-clicking bare Desktop runs `desktop`; again un-frames, as above. With nothing docked, or on a macOS
  Space where nothing docked is showing, the double-click is not Arbor's at all.
- **Everything else is left alone**: window content, floating windows, windows Arbor does not arrange, tiles, the gaps, any
  double-click with ⌃, ⌥, ⇧ or ⌘ held.
- **Tiles: decided differently from this spec** (see QUESTIONS.md). One click
  opens a tile, as before, and the second click of a double-click on it is swallowed, so both habits work: without
  that, the second click lands inside the window just framed, or on its title bar, which would go straight back.
  There is no `tileClick` setting and no selecting a tile.
- **Settings**: `titleBarDoubleClick` (false), `desktopDoubleClick` (false), and, out of the README and *advanced* in the schema,
  `titleBarHeight` (28, kept between 10 and 80; out of range is reported when the file is read and the nearest limit
  used). Old files load. `set titleBarDoubleClick false` takes the taps away at once.
- **How.** `ArborCore/DoubleClick.swift` holds every decision as pure, tested functions: `DoubleClickZones` (what a
  point means, built from the layouts by `Controller.doubleClickZones()`), `PointerCover` (what a click would
  really land on, from the window server's list), `Hit.isBackground` (which Accessibility roles are scenery),
  `DoubleClickGesture` (which events to hide), `AppsDoubleClick` (what came of a double-click that was not Arbor's).
  `Controller.doubleClicked(at:)`, `FakeWindowSystem.doubleClick(at:)` and
  arbor-sim's `dblclick <x> <y>` drive them headlessly. `Input/DoubleClickTap.swift` is the macOS part: a tap on
  mouse-downs and, installed with it so that no other app's tap comes between them, a tap on the rest of a hidden click
  that is paused except from that mouse-down to its mouse-up. They are installed while either setting is on, go away
  during a pause (`Controller.inputSettings`, which the zones read too), with `ARBOR_NO_HOTKEYS` and when Accessibility
  permission does, and are switched back on with the other taps if macOS leaves them off.
- **What the tap checks before it takes a click**, only ever for the second click of a pair inside a zone:
  1. The window server's front-to-back list: the first thing under the pointer must be that very window (for the
     Desktop: nothing above the wallpaper and Finder's icons). Windows Arbor does not arrange, menus, floating
     panels and videos in a corner keep their clicks. Layers that cover a whole display (the Dock has one) and
     Arbor's own panels that ignore the mouse are looked through.
  2. The Accessibility element under the pointer, asked of the app that owns the window. Everybody's input waits meanwhile, so all
     the answers together get **50 ms and no more** (the product owner's number: the ceiling of the wait, not a mark to aim for), and the
     asking stops at the first answer that settles it: a control is known for one at once. In a title bar, it and up to three ancestors must be scenery (`AXWindow`, `AXToolbar`,
     `AXSplitGroup`, `AXGroup` in a toolbar or a split group, and `AXStaticText` right under the window or toolbar, which is
     the title): buttons, text fields, tabs, pop-ups and anything unknown keep their double-clicks, as does text inside a
     button or a group (Safari's address), and a group by itself, which is all Accessibility may know of a button
     that an app draws for itself (Electron). **No answer, or half an answer, is a no**: an app too busy to say what is under the
     pointer is busy with what the first click set off. On the Desktop, icons, names being edited and widgets' buttons
     keep theirs, and no answer is a yes (that click reaches Finder anyway).
     `scripts/mac-shell/ax-roles.swift` prints what an app has there; `check-F14.sh` ends with a survey of Finder, TextEdit,
     Terminal, Safari, System Settings and Notes.
  3. The window must have a close, minimize or zoom button. One without has its title bar hidden (a common
     terminal set-up) and its top 28 points are content.
- **The wallpaper click** (the note under Behaviour). Arbor lets both clicks of a Desktop double-click through, so with "Click
  wallpaper to reveal desktop" at its default the first sweeps the windows aside, the second brings them back, and the
  command runs meanwhile. Swallowing only the second click would leave everything swept aside. The guard of that click (F60) was to be the
  cure and is shelved, so whether this half can ship on as macOS comes is what the run on a hosted Mac says.
- Two double-clicks in quick succession work: macOS counts them as clicks 1 to 4, and every even one counts.

## One double-click, one answer

macOS acts on a title bar's double-click itself: as it comes it fills or zooms the window, and it can be set to minimize or to do
nothing (the global default `AppleActionOnDoubleClick`; absent means the default action). The app runs that action when it
has had **both halves of the second click**. Two things must therefore never happen: both reacting to one double-click, and a
docked window zoomed by macOS and then pulled back by Arbor. What the code does, path by path, with `titleBarDoubleClick` on:

| The second press | What the app gets of it | Who answers |
|---|---|---|
| on the scenery of a docked window's title bar | nothing: `DoubleClickGesture.mouseDown` says `.hold`, `DoubleClickTap.handleDown` swallows it and keeps a copy; the mouse-up is swallowed too (`.run(…, swallow: true)`) | Arbor, at the mouse-up |
| the same, framed with nothing wider to go to | nothing (`Hit(command: nil)`, `.hold`, then `.swallow`) | nobody |
| the same, the view held (F58) | nothing: the taps stay (`inputSettings`) | nobody: the command is refused |
| the same, then the pointer moves more than 4 points | the press it missed (`.replay`, marked `EventTap.replayMark` so that Arbor's taps let it pass), then everything else | the app: a drag. `press` is nil from then on, so the mouse-up runs nothing |
| held back when macOS switches a tap off, the taps go to rest, or a pause, a setting or a lost permission removes them | with the button still down the press is given back (`DoubleClickGesture.reset(buttonIsDown:)`); with it up it is dropped | macOS, or nobody. Never Arbor: the gesture is forgotten first |
| it cannot be copied, or the release tap cannot be switched on | all of it (`handleDown` returns false and stores nothing) | macOS |
| with ⌃, ⌥, ⇧ or ⌘; on a control, an unknown role, a bare group; the app does not answer in time; a window without buttons; another window, a menu or a panel in front | all of it (`.pass`) | the app, or macOS |
| while the taps are away: paused, an app that keeps its own keys in front (F41), no permission, `ARBOR_NO_HOTKEYS`, resting, or macOS set to Minimize or Do Nothing | all of it | macOS |
| on a floating window, or one Arbor does not arrange | all of it: no zone, and `Hit.lands(on:)` wants the very window | macOS |

`neverBothArborAndTheApp` walks every order of three of these events and finds no way in which the app sees the press and Arbor
runs a command.

**Where the answer is macOS's, Arbor stands aside.** That is every row but the first four, and every double-click as Arbor
comes. The Accessibility layer's mouse monitor, which only listens and hears only what apps get, reports a double-click that went
to a window (`WindowSystemEvents.doubleClickReached`), and what macOS then makes of a docked window stays until it is back in its
slot or the layout changes (`AppsDoubleClick`, Controller+AppsDoubleClick.swift; docs/ARCHITECTURE.md, "Echo suppression").
`scripts/mac-shell/check-macos-double-click.sh` asks a real Mac.

## Not shipped

- The Desktop's double-click by default (see above), `tileClick`, and selecting a tile with one click.
- The empty part of a browser's tab strip (`AXTabGroup`), and of a title bar an app draws for itself, is refused, so macOS's own
  action runs there with the switch on as well.
- The height of the title bar is one number for every app. Unified toolbars are about 52 points tall; only their top
  28 points count unless `titleBarHeight` says otherwise. Below that the double-click is macOS's.

## How it is proved

**What Linux proves.** Every decision is a pure function or controller logic with tests: what a point means (`DoubleClickZonesTests`), what a
click would land on (`PointerCoverTests`), which roles are scenery (`DoubleClickRoleTests`), which events are hidden and when the command
runs, with every order of three events walked (`DoubleClickGestureTests`, `neverBothArborAndTheApp`), the camera moves through the real
controller (`DoubleClickTests`, `TileClickTests`, `OneDoubleClickOneAnswerTests`, `MacTitleBarActionTests`), scenario 06, and the random walks, which
double-click title bars with every switch on and off. The macOS part is type-checked against stand-ins (`make typecheck-mac`), and
`check-F14.sh` is rehearsed against the fake Mac, which plays the taps, macOS's own action and its setting.

**What a Mac must run**: `scripts/mac-shell/run.sh scripts/mac-shell/check-F14.sh`, unattended, on a hosted Mac, in under ten minutes, with macOS's
tiling and wallpaper click as macOS comes and switched off, and with macOS's own title-bar action at its default, at Minimize and at Do
Nothing. Real double-clicks on the title bars of docked, framed and floating windows, in the gaps, in a window's content, on the
Desktop, on a tile, and in Safari's toolbar.

**What is judged afterwards**, from what the run brings back. Per step, the frames the window server reported (`frames-*.txt`): one road, never past
the gap, so no jolt and no second answer from macOS. The traces (`traces/`): how often Arbor set a frame, and that it set none where the
double-click was not its own; they replay on Linux from then on. The witness (`witness.txt`): which presses reached the apps, and how late:
what is not Arbor's arrives, under 10 ms later than without the taps. The pictures, by the polish rubric. The script ends with one
verdict per switch, and a switch ships on when its verdict is "nothing failed" and the detectors agree.

**Questions only a Mac can answer.** Does a press that is held back and swallowed keep macOS's own action from running? Does one that is given back
arrive whole, once, and start a drag? How long does the look at what is under the pointer hold a click that turns out not to be Arbor's?
Does a running Arbor see `AppleActionOnDoubleClick` change? Does macOS still sweep the windows aside at the first click of a Desktop double-click?

**What used to be a list for a person at a desk.** What only a person could check counts as not done, so each has a way to be checked by a script:

| Was to be tried by hand | How a script checks it |
|---|---|
| Docked Safari, Finder, Terminal, Mail: framed, nothing flashes larger first, again goes back | `check-F14.sh` does it for Safari. The others: the same four lines per app, with `ax-roles strip` finding an empty part of the title bar. **To do** |
| An Electron app, Chrome, a terminal with a compact title bar | Needs an app a hosted Mac can get free and without an account; the step is the same. **To do**, with the cast of awkward apps |
| A word in Safari's address field, its buttons clicked twice quickly | `check-F14.sh`, with the witness counting what Safari got |
| A browser tab, the traffic lights | `ax-roles strip` gives the places; the view must stay. The traffic lights act on one click, so the test window is opened again. **To do** |
| A floating window's title bar; a docked one with the switch off | `check-F14.sh`; `check-macos-double-click.sh` |
| A menu, a popover or a video in a corner over a docked title bar | A test window at a higher level over the title bar (`ArborTestWindows --extras` has a panel). **To do** |
| A terminal with its title bar hidden | A test window without buttons. **To do**: one more option of `ArborTestWindows` |
| A tile; pause and resume; click and at once drag; a triple click | `check-F14.sh` |
| A file on the Desktop still opens; bare Desktop beside it | The survey finds the icon's place; the double-click on it and the look for the window that opens are **to do** |
| "Use trackpad for dragging": double-tap, hold and drag | Arrives as a press with click count 2 that drags, which is what `drag … --clicks 2` posts |
