# Architecture

## The model

Each display has a **workspace**: a layout tree, a camera, history, saved views
and the floating windows on its Desktop.

```
root  split(horizontal)
├── split(vertical)            ← a "space" you can zoom into
│   ├── stack [Safari]         ← a docked window (a stack of one)
│   └── stack [Mail, Notes]    ← a tab group (Notes is the active tab)
├── desktop                    ← where floating windows live; always present
└── stack [Xcode]
```

- **Split**: lays children out along an axis, sized by relative weights. Never
  has fewer than two children; never nests a split on the same axis (removals
  flatten it). **Unless it is kept** (F62, `LayoutTree+Keeps.swift`): a split that the
  view or a saved view is on, that has a name or is a guest, is marked with the
  reason and left standing, so that what points at a group goes on meaning that
  group. Every change that can delete, collapse or merge a node goes through
  `Workspace.changeStructure`, which sees to the marks for views.
- **Stack**: one or more windows; only the active one is shown.
- **Desktop**: exactly one per tree. Floating windows are placed on it.
- **Camera**: a node. The layout makes that node fill the display, and every
  window outside it is *parked*: moved to a bottom corner, with one point left
  on screen, because macOS will not reliably move windows that are fully off-screen.
  Hemmed in by other displays, it goes where least of it shows. A managed window found beyond every display, at launch,
  after a display change or when its app is included again, counts as parked, which is what brings it back. The
  window being dragged is never parked, placed or put back; the drop lays its display out again.
  With `shrinkOutOfView` it is also shrunk (320 × 200 at most) until it returns
  (`Controller+Switches.swift`).
- **Presence**: minimized windows, windows of hidden apps, windows on other
  Spaces and windows in macOS's own full screen keep their place in the tree
  but take no space and are not moved, so they return to the same spot.
- **Who gets freed space**: the whole row, in proportion to the weights. With
  `shareRemovedSpace` off, the neighbour before (after, for the first in the
  row): `LayoutTree.remove` adds the weight of a leaf that leaves to that neighbour,
  and the layout counts an absent child's weight for it. For nothing else to
  move by even a point, the layout then takes each weight to cover a slot
  *and the gap after it* (`LayoutEngine`'s `keptExtents`), so with unequal weights
  frames differ by a few points between the two settings.
  Either way a window that comes and goes gives its room back to the one it took
  it from (`LayoutTree+Room.swift`), and then nobody else gets it as well.
- **Tiles**: a node smaller than `minimumUsableWidth × minimumUsableHeight`,
  or a window whose app refused to shrink to its slot, is drawn as a tile (app
  colour and icon, or a miniature of a group) and its windows are parked.
  Clicking a tile zooms onto it.
- **Room before tiles** (F61): before a window becomes a tile for its minimum size, `MakeRoom`
  moves weight to its slot from the Desktop and from siblings in view that can spare it, once, as if
  the gaps had been dragged. The weights change, never the layout function: frames stay
  proportional to weights, which is what lets a gap follow the pointer. Not while the person's own
  hand is on a gap (`byHand`). A Desktop squeezed into a tile that way takes a usable size back
  once a window floats on it (`Workspace.desktopIsOwedRoom`).
- **There and back is nothing** (`Controller+ThereAndBack.swift`): a docked window that is hidden, minimized or on another
  Space and comes back, nothing else having changed, gets its place back and its neighbours their exact sizes. A plain
  layout does that by itself, because an absent window keeps its weight. Room before tiles moves weights, from where it
  finds them, so by itself it depends on the way there. So the controller keeps each display's gaps as they stood, with the docked
  windows that took space, when somebody last changed the arrangement (`standingGaps`), and the layout after a
  window has gone or come starts from those: the same windows give the same frames, in whatever order they went. If
  the windows, the view, the display and what is known of the windows' sizes are what they were, the layout that stood
  stands and no room is made. Any other change to the tree starts the memory afresh, which is found out by comparing the
  tree with what Arbor's own layouts last left. No gap moves for it under a hand, nor when a window is only put back
  in its place: the next layout does it. The window being typed in does not leave the view for it: then the gaps go on
  from where they are. Not saved.
- **Remap**: tree removals delete and merge nodes; `Remap` says where
  references (camera, history, saved views, drop targets) should point now.

Node ids are unique per tree, window ids are CGWindowIDs, display ids are
display UUID strings.

## Data flow

```
 hotkey ─┐
 menu ───┤
 socket ─┼─▶ Command ─▶ Controller.perform ─┐   (perform(_:from:) also answers people on screen: "Saying what happened")
 URL ────┤                                  │
 test ───┘                                  ▼
                                   Workspace / LayoutTree   (ArborCore, pure)
 AX events ─▶ WindowSystemEvents ─▶ Controller  │
 (moved, created, focused, drag…)               ▼
                                   LayoutEngine.layout(tree, camera, frame)
                                                │
                                                ▼  Layout: windowFrames, hidden, tiles, seams, desktopFrame
                                   Controller.relayout ─▶ OverlayPresenter.animate (the way there, first)
                                                     ├─▶ WindowSystem.setFrame (slots and parking)
                                                     └─▶ OverlayPresenter.update (tiles, seam handles)
```

`relayout(display, reason:)` is the one place frames are applied: `.camera`
after the camera moved, `.structure` after the tree or the set of present
windows changed, `.enforce` to put back docked windows that something else moved.
(The exceptions: rescuing a window found off screen, releasing an app that was
just excluded, `float-all`, quitting, and parking floating windows that arrive
from a display that went away.)

**A floating window's frame is its person's** (`Controller+OwnFrames.swift`; `collab/QUESTIONS.md`, Q20). Arbor sets it only to
take the window out of view and to put it back exactly where it was. Each floating window has the frame its person last gave it
(`Workspace.floating`), and while it is in view that is where it is: no layout places, shoves or squeezes it, whatever is docked,
closed, hidden or minimized around it, so floating and docked windows may overlap and macOS's order says which is in front. The
plan for floating windows (`floatingMoves`) asks `moveKeepingItsFrame`, which knows two moves. When the camera moves and the Desktop
is no longer part of the view, the window is parked, and where it is at that moment is noted as its frame
(`noteWhereItLeavesFrom`), whoever put it there. When the Desktop is part of the view again, as a tile too, it is put back there in
one move, and nothing is raised (`putBackWhereItWas`). The one exception is `whereItWas`: if the displays have changed meanwhile and
less than half of the window would show, or its title bar would be out of reach, it is fitted into its display; what is
remembered stays its own frame (`fittedFrames`), so that it goes back when the displays are as they were. A change of displays
also displaces windows that are in view; `countAsOutOfViewWhatTheDisplaysDisplaced` says which of them the layout then fetches.
For F61 the Desktop counts as not in use (`roomTerms`), and F18 is off (`soleFloatIsOn`). A command that is about a floating
window (`float`, `grow`, `move-to-display`, `undo`) may put it anywhere on the display (`roomToFloat`).

The rest of this section, and whatever below speaks of windows pushed aside or squeezed, is how it was until Q20 and still is
with **`floatingWindowsMakeWay`** on: floating windows live on the Desktop (`placeFloatingWindows`), and Arbor's own moves never
change the frame in `Workspace.floating`. While the Desktop is in view, a window that was on it (give or take two
gaps) sits as near to that frame as the Desktop allows, so docked windows push
it aside or shrink it and it goes back as they make room. On the sides where nothing
is docked beside the Desktop they may reach the edge of the screen. When the camera
moves and the Desktop is no longer part of the view its windows are parked; when it is
again they return. A Desktop too small to use, a tile, is part of the view like any other:
its windows are in view at their own frames, where the docked ones are too, so
that after "show everything" nothing is out of view. Nothing is pushed there, and nothing is raised: which lies in
front is macOS's order (QUESTIONS Q20, Q25), and ⌃⌥D or a click on the tile shows all that floats.
Only a camera move parks or returns: a change of the arrangement can turn the
Desktop into a tile and back, and must not make the window someone is typing in shrink
or vanish. A window the user moved over docked windows on purpose is left alone until
the camera next brings the Desktop into view; where its app opened it does not count.
A `dock` command keeps a Desktop that has windows on it wide and tall enough to use.
A window that opens over a view the Desktop is not part of is a **guest** of that space
(`Workspace.guests`, `Controller+Guests.swift`): it is also in view whenever its host is.

**Pinned windows** (`Workspace.pinned`, `Controller+Pin.swift`) are floating windows that none of this applies to:
the plan for floating windows (`floatingMoves`) asks `frameBringingIntoView`, which moves one only if it is out of view (it
was until it was pinned, or its display went away or changed shape) or smaller than its own size (a small Desktop had
squeezed it until it was pinned). Being in view is worth little behind another window, and macOS
has no way to keep another app's window above the rest, so `notify` tells `keepPinsInFront` of every change. After a
camera move, a layout, or another window taking the keyboard, Arbor asks the window server how windows are stacked
(`windowsFrontToBack`) and raises the pinned windows that another window covers (`WindowSystem.raise`: `kAXRaiseAction`
without activating the app): once the command or event under way is over, and twice more at intervals of 0.2 s,
because a clicked window comes to the front after it has taken the keyboard. A click in the window that has the keyboard
already changes nothing that is reported, so the window system also says when the button goes down (`pointerPressed`), and Arbor
goes on looking until it is up. A pin lives and dies with
`Workspace.floating[window]`: whatever removes that entry removes the pin, and code that moves a floating window
from one display's workspace to another takes the pin along.

**Summoned windows** (`Workspace.summoned`, `stashed`, `summonFrames`; `Controller+Summon.swift`) use the same mechanism. While it is
summoned a window is a pin that ends by itself (`Workspace.staysInView`): `notify` tells `summonNotices` of every change, and another
app's window really taking the keyboard ends it. Afterwards it is *stashed*: a floating window that `placeFloatingWindows` keeps
out of view whatever the camera shows, because a window that returned to the Desktop could not be sent away in a view that includes
the Desktop. `windowFocused` summons a stashed window instead of moving the camera, and `home` makes summoned and stashed windows ordinary again. Pinned, summoned and stashed are a floating
window's `FloatingRole`; it has at most one, loses it when it stops floating, and takes it along to another display's workspace (`setRole`).

If a window refuses its slot (the frame it ends up with is larger than asked),
its minimum size is learned and the display is laid out once more, so it
becomes a tile instead of overlapping its neighbours. What was learned can be
wrong (an app that resizes a moment late, a sheet that was open), so a window
later seen smaller than its learned minimum lowers it, and `relayout` forgets
every learned minimum and offers each window its slot again.

**A window moves once, to where it ends up** (`Controller+AskFirst.swift`, `SeenSizes`), so an answer has to be in before anybody acts
on it. As small and as large as a window has been seen it can be again; only a size beyond that is a question, and it is put **where
the window stands**: one `setFrame` with its own origin and the size of the slot. **In view each side is only asked to shrink there**
(`question`): macOS lets a window grow no further than to the bottom of the visible frame and the right edge of its display where
it stands, so that answer would be the screen's, not the window's, and meanwhile it would lie over its neighbours. Those who may refuse to shrink are asked before
anybody is moved (`askingFirst`; one at a time, newcomers first, then those who make room for them, the most squeezed first), because
room is made from their answers; at the first refusal the layout is worked out again, until nobody in it is unknown. Whether a window can grow decides only its own place, in the middle of
the slot. A window out of view is asked in its corner, while the others move (`apply`), and goes last; one in view grows in its slot, and
goes on to the middle of it if it turns out unable to, once. A size that cannot be changed is known
beforehand (`isResizable`, `noteFixedSizes`). A window that once stopped short of a slot is sent straight to the middle of the next, still asked for
the whole size, so it costs nothing to find out that it can grow again. To
the eye a question and the move after it are what one `setFrame` has always been (`FramePlan`: size, position, size); tests look at the
road a window takes (`FakeWindowSystem.detour`), and `Budget.questions` counts what it costs.

A window that gives no such sign is **asked again where nobody can see** (`Controller+LearnedSizes.swift`). A tile's
window is parked anyway. So when a display is laid out, and the record that makes a window a tile has stood for
`tileRetryMinutes` (10), `relayout` asks the window, between applying the layout and laying out again, to take the size of
the slot that is waiting for it, with one `setFrame` in its corner. If it does, the record is forgotten and the next pass
gives it the slot. If it refuses, the record stands with the size just seen, the ten minutes start again, and nothing on
screen has changed. No timer is involved: time alone moves nothing. Nobody is asked during a drag or an edge resize.
The corner to the left of a display depends on the window's width, so there the question is placed as if the window
kept the width on record, and a window that shrank only somewhat is parked again at its new size. `confirmedSizes` holds
when each record last held; it follows `minimumSizes`, whoever writes that.
## New windows

`windowAppeared` says that somebody just opened a window. It is checked against `Settings.newWindowRules`
(`Controller+Rules.swift`): the user's `rules` in order, then the one rule that `"newWindows": "dock"` stands for,
`{"app": "*", "action": "dock auto"}`. There is no second mechanism, so whatever holds for rules holds for automatic docking: the first
match wins, a late title can bring a better rule into play, and a window no rule docks floats where its app put it, as a
guest if one window is framed. A rule that docks windows nobody named (`AppRule.isCautious`: `dock auto`, or a `*` in `app`) passes over
windows that opened small or cannot be resized (`AutoDock.accepts`, `WindowSnapshot.isResizable`).

`dock auto` (`AutoDock.plan` in the core, `Controller+AutoDock.swift`) tries, on a copy of the workspace: either half of the slot of the docked
window in view that last had the keyboard, longer side first; a tab in it, with `tabsEnabled`; either half of the largest window in
view; or, when nothing in view has had the keyboard, the right and the bottom edge of the view. A placement counts only if everything that
was showing still shows and nothing else comes into view. How small apps let their windows get is only found out by asking, so
the new window is offered its slot before anyone makes room, and a docking that made a neighbour a tile after all is taken back; each
round learns a minimum size and plans again. New windows have the keyboard before Arbor hears of them, so "focused" is read from
the focus history, and for a second a window docked this way heads it, because in a burst focus reports lag.

`windowFound` says that a window was open all along and has only now come to notice (its macOS Space is showing for the first time). It is
adopted like a window found at launch: it floats, and of the rules only `ignore` applies.

## Focus

The window system reports the focused window of the app in front: when that app
comes forward, and when its focused or main window changes (see "What counts as a
window"). The report can come before the window is
reported as un-minimized or back on the active Space. The camera follows a
report only once `focusedWindow()` is that window and it is present, looking
again for up to a second (`Controller+Focus.swift`). Then a window out of view
is revealed. The level is kept: from a view on one window, tab group or the Desktop,
by framing the window (a floating one: the Desktop; a guest: its host). From a group or
everything, by zooming out just far enough, or onto it if it would be a tile.
When the window with the keyboard is closed, minimized or hidden, macOS hands the
keyboard on by itself. If it picks a window out of view, the view stays and a window in
view gets the keyboard; the view follows only if nothing is in view. macOS reports
the new focus before a close or a minimize, after a hide, and sometimes not at all.
Until the going is reported, a few milliseconds later, a close looks like ⌘`. So a report that takes the keyboard from
one window of an app to another that is out of view waits 50 ms (`Controller.timeForAGoing`): if the first window goes
meanwhile, all is as if its going had been reported first, and nothing has moved. Nothing else waits: another app's
window, a window that has only just opened, what Arbor itself asked for or found, what a hold turns away. A going that is
later still finds a view that has followed, which is taken back (`Workspace.retractLastMove`): on paper, before anything is laid out
for the going and before a closed window leaves the arrangement (`Controller.theViewGoesBack`), so that one layout shows both. A group
is kept whole only while the view is on it, and what the going leaves of the group that was in view would otherwise dissolve and
leave nothing to go back to.
Two moves that cancel out are no move to a person. A window can float over a view that is not the Desktop's, and
nothing in the model says that it does: the move back to such a view would park it. So the floating windows that
were in view before the first move are where they were after the second (`Reveal.floatingInView`).
When a camera move parks the window that has the keyboard, a visible window is
focused instead. Commands that arrange windows focus the window they moved only
if it shows, because focusing a tile would zoom onto it.

## Motion

Real windows cannot be animated through the Accessibility API: a move takes milliseconds to seconds and
blocks. So they are not animated. `relayout` moves them straight to their final frames, exactly as it
would without animation, and the motion is drawn on top (F02).

**The plane** (`Plane`, ArborCore). The layout only says where things inside the camera's node go. The
plane says where *everything* is, as seen with the camera on that node: an ancestor of the node is
laid out on the screen without tiles, and every rectangle in it goes through the map (`PlaneMap`, x and y
scaled independently) that carries the camera's node onto the content rectangle. Inside the camera's
node the real layout wins, because gaps do not scale. Two cameras seen through their common ancestor are
two views of one arrangement, so going from one to the other is one continuous zoom: windows leaving
the view slide and stretch out past the screen edges, windows entering arrive from there.

**The plan** (`TransitionPlanner`). A `Keyframe` is a display standing still: tree, layout, who is
present, and where every window that shows as itself really is, including windows Arbor leaves
alone. From two keyframes the planner makes a `Transition`: one item per window drawn, back to front,
with its frame, look (`picture`, or `cover` for a window in a tile) and opacity at both ends. A window is
taken from where it really is to where it goes. Out of view it is where the plane puts it, slid on
until it has also cleared the outer gap, the menu bar and the Dock. A floating window out of view rides
on the Desktop's rectangle. A window with nowhere to come from or go to fades. Closed and minimized windows
have no item; a window out of view at both ends has one only if the motion carries it across the display.

**The controller** (`Controller+Transitions.swift`) remembers each display's last keyframe. `relayout`
lays out, plans, hands the transition to `OverlayPresenter.animate` *before* it moves anything, moves
the windows, and then plans again from what really happened: if an app had other ideas (a window that
refused its slot and became a tile, a terminal that rounds its size), it sends the corrected
transition. A command that puts windows back itself (`float`, `float-all`) hands those moves to `relayout` as
`puttingBack`, so that they too happen behind the stage. Every `relayout` call is animated unless it says `motion: .instant`, which seam drags, Space
switches, native tab switches, display changes, settings and starting up do; `.enforce` never is, nor is anything while the
user holds a window. Nothing the controller decides depends on the presenter, so frames, parking and
focus are the same with any `animationDuration` (`windowsGoTheSameWayWithAndWithoutAnimation`).

**The stage** (`UI/Stage.swift`, `StageDirector.swift`). One reused, click-through panel per display, one
level above floating windows and below the Dock and the menu bar, covers the display with a picture of
the desktop and one stand-in per item. It is up, and flushed to the window server, when `animate` returns.
Core Animation then moves the stand-ins in the render server while the main thread waits on apps.
A second transition on a stage that is up starts from where the stand-ins are on screen. One that corrects the first, because an app
had the last word on its window's frame, gets what is left of the first one's time and at least 0.15 s (`Transition.timeLeft`): one act is one
motion, and the time the apps took to answer is not added to it. (The main thread waits on the apps until then, so no timer has lifted the stage.) The curve is
`Transition.curve`, an ease-out without overshoot. A stage must never stay up: a timer and the completion
block both end a motion, and a mouse button going down anywhere, sleep, wake, a Space switch, a
display change, `pause` and quitting take every stage down at once. The left button also comes by way of
the controller (`WindowSystemEvents.pointerPressed`), which is how tests reach it.

**Nothing is made while somebody waits** (`Controller+Rehearsal.swift`, `StageDirector.rehearse`). The real windows wait until the stage is
up, so what the stage needs is time between the key and the first move. All of it is kept once made, which left the first motion after
a start to pay for everything: two seconds with nine apps' windows on a hosted Mac, against five milliseconds for the second. So after every
layout, the one at the start among them, and when a window turns up, the controller notes which displays and which apps are new and hands
them to the presenter (`OverlayPresenter.rehearse`), one display or one app at a time with a pause between them (the timer `rehearsal`), so that a
key pressed meanwhile waits for one piece at most; a motion puts the rest off until it is over, and a stop ends it. The director makes the
display's stage and backdrop and skips what it has. The stage goes up once, clear through and through, and is down again before the call
returns. An app's colour and icon are made on a thread of their own (`UI/Wardrobe.swift`), because they were nearly all of the two seconds:
macOS draws an icon at a size the first time anybody asks, 4.7 s for eight apps on a Mac that had drawn none and 27 ms a minute later. **A
motion never waits for one**: a window whose app has no cover yet sets off as a plain grey card and is dressed on its way, when the cover
arrives. No window is asked anything. With `animationDuration` 0 nothing is handed out; with Reduce Motion on, or
where stand-ins are pictures of their windows, the director leaves out what would not be seen, and when either changes everything is said
again (`rehearseAfresh`). A stage stays while its display does: macOS reports a change of screen parameters at every minimize. What cannot be
helped: a window of an app nobody knew of that a rule docks as it opens sets off as a plain card. `FakeOverlays.madeInTheMotion` lists what a motion met that
nobody had got ready (`RehearsalTests`). Every stage that comes up logs what kept the windows waiting, as `INFO` from a tenth of a second.

**Pictures** (`UI/WindowPictures.swift`). With Screen Recording permission, stand-ins are still pictures
taken with ScreenCaptureKit, and the backdrop is a picture of everything below the windows (wallpaper,
icons, widgets). A motion cannot wait for a picture, so they are taken ahead of time (at launch, when the
focus moves on, after every motion) and kept in memory; the stage starts with what there is and swaps in
new ones as they arrive. Without permission stand-ins are the app's colour and icon, and the backdrop
is the wallpaper's file. Arbor never prompts for the permission from here (`WindowPictures.isAllowed` is
for onboarding to ask), and nothing is written to disk.

## What a command costs

Measured on a Mac with twelve real windows: Arbor's own
work for a command is tens of microseconds. A call to another app through the Accessibility API is a message
and a wait for the answer: 0.1 to 0.6 ms from an idle app, 2 to 5 ms for a resize that really changes
the size, and the whole timeout from an app that hangs. Making one of Arbor's own panels and showing it for the
first time takes about 3 ms, focusing a window about 9. So a command's latency is what it asks of other processes,
and nothing else is worth optimising.

- `BudgetTests` pins what the everyday commands in `BenchmarkCase.all` may ask (windows moved, moved for nothing
  or twice, focuses, overlay updates, saves); `arbor-sim bench` prints the same table.
- `arborctl stats` prints the count, total, mean and worst time of commands, layouts and overlay updates since
  `stats reset` (`Support/CallStats.swift`, safe from any thread, always on).
- `AppKitOverlays` leaves tiles and seams alone when the scene has the ones that are showing, leaves panels alone that show the same thing, and keeps panels
  that go out of use to hand them out again (`Support/ReusePool.swift`, tested without a screen). After a switch of macOS
  Spaces everything is shown again, because a panel belongs to the Space it was shown on.
- Before a layout moves anything it tells the window system which `setFrame` calls are about to follow
  (`WindowSystem.moveTogether`, `Controller+Together.swift`). A window system that can moves those windows at once, the apps side
  by side, waits only so long for all of them together, and answers the calls from what came of it. `apply` stays one
  window at a time. Only docked windows are foretold, and not when they are put back. The hint changes what the calls cost, never
  what they return: `MoveTogetherTests` walks two desks through everything, one taking the hint and one ignoring it, and compares them after every step.
  **Whoever gives `apply` or `park` a new reason to leave a docked window alone gives it to `movesInSight` as well**; the tests fail otherwise.

## Holding the view

`Controller+Hold.swift` (F58), for calls, shared screens and recordings. `holdLevel` is `.still` (Arbor moves the view
only when asked; also during a call) or `.view` (nothing moves it until `release`). A call is a window matching `holdStillFor`, or a camera or
microphone that some app has running, each only if switched on (all three ship off: out of the box Arbor holds only when asked): `App/CallSensor.swift` listens for that on a queue of its own and reports changes to
`callSignalsChanged`; whether they matter, for how long and in which words is decided in `refreshHoldCaller`.

**Before putting anything of Arbor's on screen, ask**: `mayShowUnasked` for what Arbor would show or sound by itself (hints, the minimap after a move, messages other than
why a key did nothing): false during either hold. `mayShowPanels` for what the person asked for (Go to…, the minimap on demand, the shortcuts, welcome and update
windows): false only on a held view. What is up already when a hold begins comes down (`holdChanged`): the minimap at either strength, the shortcuts' sheet and the heads-up line on a held view.
The menu greys out what `holdWouldRefuse` and, by `mayShowPanels`, the rows that open a window and are no commands.

**Anything new that moves the view or a window without being asked (a timer, a window event, a rule) checks `isHeld` first.**
New commands are refused by `hold` until `Command.isAllowedWhileHeld` lists them, as URLs refuse them until `isAllowedFromURL` does.

| Where | What |
|---|---|
| `perform` → `holdAnswers`, `shortcut` → `holdIgnores` | `.view`, from a shortcut only: the key that pauses releases instead, and does nothing more while it stays down; the key that floats everything is refused. Both bring every window into view, and a key can be a slip |
| `perform` → `refusalWhileHeld` | `.view`: commands not on the list, commands on windows that are out of view, and arranging that would widen the view fail with "the view is held" |
| `revealAndFocus` → `holdNotesRequest` | `.still`: a window asked for by name is let through for two seconds, whatever is reported in between, and nothing is sent away meanwhile |
| `windowFocused` → `holdNotesFocus` | remembers the window in view that has the keyboard, arranged by Arbor or not, and whether the report came within 0.5 s of a click or a modifier key (`WindowSystem.secondsSinceClickOrModifierKey`) |
| `bringIntoView` → `holdTurnsAway` | a window out of view that has taken the keyboard stays there and the keyboard goes back. `.still` lets through what the user asked for. One arrival, reported two or three times, counts once; when that fifth of a second is over Arbor looks where the keyboard is (`holdLooksAgain`), because an app can take it just after it was asked back and no report says so. An app sent back three times in five seconds keeps the keyboard, out of view, and the line is around no window then. `.still` says on screen what it turned away, once for each app and hold (`holdSaysThatItTurnedAway`): it goes by time and can be wrong about a launcher. `.view` says it only of what the person did themselves (a report within 0.5 s of a click or a modifier key, not longer ago than its second looks last), and only when the arrival is over and the window that had the keyboard is still there (`holdSaysWhatIsOwed`): ⌘W is a key too, and macOS names its choice before it says what went |
| `adoptNewWindow` → `holdPutsOff` | rules that dock wait. When the hold ends, which can happen by itself, they are applied in order to windows that still float where their app put them, each only if a rehearsal (`keepsTheView`) leaves the view where it is and showing what it shows. `.still` lets through a window that opens within 0.5 s of a click or a modifier key |
| `adopt(rescue:)` → `holdLeavesOutOfView` | a new window that opens mostly off screen while a window of its app is out of view, which is why it opened there, is not brought to the middle of the display (one that is merely too large, or remembers a display that is gone, is, as ever, if nobody could get hold of it; otherwise it stays where it opened): it floats, goes to its corner, and is kept out (`placeFloatingWindows` → `holdKeepsOut`), even off a Desktop that is in view, until its display's view next moves (`relayout` → `holdLetsInWhatWaited` when the layout follows a move of the view, reason `.camera`, and its view is not the last one's; not a command that announces a move and may make none, nor a new node alone, which arranging the windows in view makes too; never on a held view), which can be after the hold: its end brings nothing in. Its rule, if one waited, is not applied. It is nobody's guest. `.still` lets through one the user opened |
| `holdChanged` → `WindowSystem.leaveStrayDialogs` | at `.view` the Accessibility layer leaves dialogs that open out of view where they are (F47 would centre them), but for those of the app in use (`appInUse`: the app of the window in view that has the keyboard, not simply the one in front), which would look hung. It brings in those still open when told otherwise: just before the view next moves, or at a pause, `float-all` or quit |
| `applicationActivated` → `holdNotesActivation` | going to an app brings in that app's dialogs that waited (`bringInStrayDialogs(ofApp:)`): the keyboard goes to the dialog, which Arbor does not arrange, so no focus report would move the view. Not at `.view`; at `.still` only within 0.5 s of a click or a modifier key. `status` counts them (`strayDialogsWaiting`) |
| `relayout` → `holdFences` | see below. The fence is around what a layout **shows**, which is not where the view is while the window it is on is away: what is seen is what is held |
| `dropTarget` → `holdWouldLetSomethingIn` | a drop that would widen the view is no target: no preview, and the window goes back |
| `moveCamera`, `tileActivated` | do nothing at `.view` |
| `inputSettings` | pinch and rectangle taps are removed at `.view`, so no band is drawn |
| `shutdown` (quit, pause), `float-all` | from the menu or a script: end the hold; rules that were waiting are dropped |

**The fence.** The view can only be on a node, and the tree flattens splits of the same axis. So "what was in view plus the window docked at
its edge" and "what was in view minus the window that closed" are sometimes not nodes, and the view ends up on the whole row or column
around them. Normally that is a wider view; on a shared screen it is everything the hold was keeping out of sight. At the start of every layout
`holdFences` compares what the layout would show with what the view took in at the last one (`Hold.fences`): nothing else may come in but windows that
are on screen anyway. If something would, the view narrows to the largest part that holds only what was showing. The user's own drops and commands
are rehearsed on a copy of the workspace first and refused, so that they never "succeed" into a narrower view. If no part is left that takes up
room (the only window in view was minimized, hidden or closed, is in full screen or on another macOS Space), no window is moved and the display gets an
empty `Layout`, so that nothing goes on pointing at nodes that are gone (`holdShowsNothing`, `displaysHeldEmpty`): **a held view never widens by itself**. It is laid
out again when the window is back or the hold ends. All this is in `relayout` because every change ends there, whichever path it took.
`HoldFuzzTests` walks random commands, keys and events against the promise: nothing that was outside the held spaces shows while the hold lasts, nor when it
ends, unless a view had nothing left in it.
Since F62 a group the view is on keeps its identity, so docking at the edge of a held view, turning a held group the other way and a close inside it no longer widen the view, and the
rehearsal lets them through by itself; that goes for `dock A beside B` in a group of two as well. The fence and the rehearsal stay as the guarantee. Still refused: taking away
the only window showing.

## Echo suppression

Every `setFrame` produces AX moved/resized notifications a moment later.
`AXWindowSystem` remembers the frame it set (`EchoFilter` in ArborCore: any
report within 0.15 s, the expected frame for a second, on a clock that cannot
go backwards) and reports matching notifications
with `userInitiated: false`. A report within 0.15 s of another frame than the expected
one may be a stage of Arbor's move (position and size are set one after the other) or
the app's own answer to it, so the window is looked at again 0.3 s later and reported
as moved by its app if it is not where Arbor put it. The controller ignores those, and treats
user-initiated changes as: floating → remember the new frame; docked with the
mouse down → a drag or resize in progress; docked and resized by its edges →
move the seams it touched when the mouse is released (see Edge resizes);
docked otherwise → put it back after the mouse is released
(`scheduleEnforce`). Differences of up to 4 points are accepted as the app
rounding the size (terminals snap to character cells).

An app that answers every move with one of its own would make putting back a
loop without end. After three put-backs of a window within three seconds
(`EnforcementLimiter`) Arbor leaves it where its app wants it, says so once in
the log, and tries again when the layout next changes.

What macOS makes of a double-click is not put back either. macOS fills, zooms or minimizes a window whose title bar is
double-clicked, and the person asked for that. `AXWindowSystem`'s mouse monitor only listens and hears only what apps get, so
a press with an even click count has reached the window under the pointer: `doubleClickReached(_:)`. The controller
keeps a note for a docked window (`AppsDoubleClick`), and a new frame of that window within two seconds, with the button
up, stays (`standsAsideAfterADoubleClick`, from `windowChanged`): no frame is set and no timer started. The window is still docked
and its slot stays empty behind it; it is left alone like one Arbor has given up on (`EnforcementLimiter.leave`) until macOS's
second double-click returns it or the layout next changes, which takes it back in one move. The first three times a line on screen says so
(`HeadsUpHint.zoomedByMacOS`). A drag or an edge resize drops
the note. Not covered: ⌥-click on the green button and the tiles in its menu, which no press tells apart from an app's whim.

## Drag and drop

`AXWindowSystem` watches global mouse events. When the button goes down it
notes the point and the window under it (the first layer-0 window in the window
server's list that the point belongs to) with its frame. From then on two
signs are watched, and the first to show something wins: with every movement
of the pointer the window's frame is read from the window server, and the app's
own moved and resized notifications are looked at as they come. The window
server moves a dragged window itself and knows its place at once; the app
hears about a tenth of a second later and some apps post nothing until the
drag is over. `WindowGrab.classify` (ArborCore) turns the press, the frame then
and the frame now into a verdict: moved → a drag (`dragBegan/Moved/Ended`); size
changed after a press within 10 points of the border → an edge resize; size
changed after a press anywhere else → not a resize (macOS zooms a window whose
title bar is double-clicked, and gives a window it had tiled its old size back
when it is dragged away); the pointer 24 points away and the window where it was
→ the press is most likely about the window's content: look ten times a second
from here on, not with every movement. It is not the last word
(`WindowGrab.judge`): a window whose app was busy, or had to bring it forward first,
starts late, and one that then goes the pointer's way at its own size is in hand.
Moved farther than the pointer went, by more than 32 points → not in the hand, stop looking.

**macOS showing its desktop** (a click on the wallpaper, as macOS 14 and later come; F11; a
hot corner) is a picture and nothing more: the window server lists every window at the
side of its display, with the size it had, while Accessibility has it where it is and
reports no move. A frame set meanwhile is taken, shows nowhere, and is where the window
comes back to. So Arbor goes on as ever, by Accessibility, and what it lays out meanwhile
nobody sees move. What it must not do is believe the window server:

- A press on the strip of a window that still shows brings them all back with the button
  down, so the window under the pointer leaps across the display in the list. Taken for a drag,
  that is one at the edge of the display, where Arbor docks. So a press on a window that is listed
  elsewhere than Accessibility last had it takes hold of nothing (`WindowGrab.isListedElsewhere`,
  asked by `makePress`), and the last rule above catches a leap from whatever cause.
- A busy Mac serves a press late: the place of the press is of a while ago, and the window server's list
  is of now. A window that is in the hand by then is listed elsewhere than its app last said as well, or
  has left the place of the press, with another window showing there. `makePress` reads what shows at
  the press and what shows at the pointer, and `WindowGrab.hold` decides. A window that is ahead of
  its app's word, the way the pointer went and no farther, taken where a hand can take one (its top,
  an edge), is in the hand, and is judged from the press and its app's word. While the desktop
  is shown nothing is: that is told by the Dock's window as large as the display at level 18, or by
  the frames. An edge that has left the press behind is judged from where the pointer is.
- A layout is shown as motion from where the windows are to where they go. With the windows aside
  there is nothing on screen to lead from, and the stage would put stand-ins on a desktop that
  somebody wanted bare: `stageTransition` asks `SweptAside`, which compares what Arbor believes
  with the list it has just read, and moves the windows at once.

`collab/reports/2026-10-14-the-desktop-is-shown.md` has what a Mac answered;
`FakeWindowSystem+SweptAside.swift` and arbor-fakemac sweep as it did; `scripts/mac-shell/check-sweep.sh`
asks a Mac again.

`DropResolver` turns the pointer into a target, the
first of these that applies: on the window's own slot → snap back; within
`screenEdgeBand` of an edge of the display's visible frame → dock at the
camera's edge; within `windowEdgeFraction` of a window's edge → dock beside it;
the middle of a window → float (or tab, with `tabsEnabled`); the Desktop →
float. Either band at 0 is off: no edge of that kind is ever offered (`DropOptions.offersScreenEdges`,
`offersWindowEdges`). The controller narrows "float" for a docked window (`dropTarget(for:at:)`):
only the Desktop takes it out of the arrangement; over the middle of another
window or a gap, where nothing is previewed, it goes back to its slot
(`Hover.isNowhere`). The preview frame comes from trying the drop on a copy of
the workspace and laying it out, so the preview always matches the result.

A drag is one `DragSession` (`Controller+Drag.swift`). Every move goes through
`updateHover()`: `hover(of:)` says what the pointer is over, and a new target is
shown by `showHover(active:)` at once, or, for a window or a tile
(`DropTarget.needsDwell`), after the pointer has rested on it for `dropDwell`
seconds (the scheduler key `drag-dwell`; no wait without `previewDrags`, when
nothing would show that it is over). Moving to another target starts the
wait again and hides the preview. A release counts only on the target that
was held; before that a floating window stays where it is and a docked one goes
back to its slot (`cancelDrag()`). While ⌘ is down
(`WindowSystem.modifierKeysDown`, looked at on every move, when the wait ends and
on release) every target is "float", even the window's own slot. During a mouse
event `AXWindowSystem` answers with that event's own flags: people let go of key
and button together, and the key can be up by the time the mouse-up arrives.

**Where macOS tiles, Arbor stands aside.** macOS 15 and later tile a dragged window themselves, a Mac comes with that
switched on, and macOS asks nobody. `WindowSystem.macTiling()` says which of its three switches are on; it is asked
when a drag begins and kept in the session. `MacTiling.claim(onWindowLetGoAt:…)` (ArborCore, with the measurements) says
whether the pointer is where macOS acts, and why: the first and the last point of the display's width, the menu bar, anywhere
with ⌥ held. `hover(of:)` asks that before anything else and answers `.float` with `leftToMacOS` set: no preview, no
docking, and neither `drop(of:…)` nor `soleFloatDropped` gives the window a frame, so that a docked window leaves the
arrangement without the size Arbor would otherwise give it back. From then on it is a floating window that something else
moves, which `windowChanged` follows as always. Half a second later, if macOS has moved it, a hint says who took it
(`HeadsUpHint.leftToMacOS`); macOS does not always: thrown into the menu bar and let go at once, the window stays as it is.
A pointer travels, and on its way to macOS's point it crosses Arbor's own band along the screen's edge, where a preview would come up only to go
again as macOS's comes. So while the switch for an edge is on, the whole band is silent (`MacTiling.edges`, `DropOptions.silentEdges`;
`collab/QUESTIONS.md`, Q23): `DropResolver` answers `.float` there, in the corners too, before it looks at anything else that lies in the
band. Let go there, short of macOS's point, a floating window stays where it is and a docked one goes back to its slot, as wherever nothing
was promised. The bottom edge, docked windows' own edges further in and the keys stay Arbor's.
An edge is silent in the same way, at every setting, while the pointer has not left the band in which it took hold (`DragSession.edgesNeverLeft`): a window that
lies under the menu bar has its title bar in the top band, and slid sideways it has not been carried to the top.
A release that Arbor never saw ends the same way at an edge or in the menu bar (`dragCancelled`), because macOS saw it; a drag
that ends with the button still down (a pause, a quit) does not. Dragged off its tile, a window gets its earlier size
back from macOS, the one change of size `windowChanged` takes from a window in the hand. One point decides, so
`AXWindowSystem.cursorLocation()` answers with the event's own place while a press or a release is handled.
`FakeWindowSystem.tiling`, which is on as on a Mac that nobody has changed, makes the fake tile as a Mac was seen to: after
Arbor has heard of the release, step by step, whatever Arbor made of the window meanwhile. That is what turns a fight
into a failing test, in every test, random walk and scenario that lets go of a window there.

Every drag ends in `endDrag(on:)`, whether the mouse came up (`dragEnded`) or
the release will never come (`cancelDrag()`: the window closed, Arbor is
quitting or pausing, another drag began, the release was lost). `endDrag` cancels
the timer, hides the preview and calls `finishDrop(_:on:at:after:)`, which makes the
drop with `Drop.apply` (ArborCore), the only place a drop changes the
workspaces, and lays out what changed. `drop(of:on:display:at:)` builds the `Drop`, for it
and for live reflow's trials. Anything else that carries a window
somewhere and lets go of it ends in `finishDrop` too. While a drag lasts
`relayout` leaves the dragged window alone, and any `relayout` (a command, a
window closing, a display change) makes the drag forget its target, so it has
to be held again.

A release can be lost (another tool's event tap swallows it). While a window is
held, the button is checked twice a second; found up twice in a row, or going
down again, it ends the matter: a resize is finished with the frame the window
has, a drag is called off (`dragCancelled`, which is `cancelDrag()`: a docked window goes
back to its slot, a floating one stays), since where the pointer is by then says nothing.

**Live reflow** (`reflowWhileDragging`, `Controller+Reflow.swift`) shows, during a
drag, the arrangement that letting go would produce (while a target waits to
be held, and where nothing can be dropped: the arrangement without the window). `reflow()`
applies that drop to a copy of the workspaces with the same `Drop.apply`, lays
the copy out and moves every window but the dragged one there, with the tiles
and seam handles. The real workspaces and `layouts` do not change, so camera,
history and saved views cannot be disturbed by a drop that is never made.
Once a docked window has left its slot the pointer is matched against the
arrangement without it, which is what the user sees; its old slot still means
"back where it was"; and the gap the others open for it counts as the target
that opened it. Floating windows are placed by `placeFloatingWindows`, as for a
real layout, which is lent the trial workspace and the last trial's layout for the
call; the ones a trial moves aside stay there until the drag ends
(`keepPushed`), or follow each trial, and the ones a trial brought into view with
the Desktop leave with it. At the end `settle` lays the displays out
from their real trees and puts those windows where a drag without reflow
would have left them, so the setting never changes where anything ends up.

### Arbor's panels and the mouse

Drags must never block input (`collab/QUESTIONS.md`, Q17). While a mouse button is down that went down outside Arbor's own panels, Arbor puts no
panel that takes the mouse under the pointer and moves none there, and no panel that takes the mouse covers a whole display, except
the peek's outline while its keys are held. There is no drop layer: the preview is a panel that ignores the mouse.

This is the one table of them. `PanelsAndTheMouseTests` reads it and the sources, and fails for a panel that is not in it, for a level
that differs, and for a panel that is "no" here and ever says anything else in its source. It reads what stands in a panel's own braces, so
that is where all of it has to stand. It fails as well for a line anywhere else in the app that says whether a panel takes the mouse or sets a
window's level (an extension, another class, the code that shows a panel), for a second level in one panel, for a window class that is
not declared in the first column, and for a bare `NSWindow` or `NSPanel` made anywhere but for the settings window.

| Panel | Level | Takes the mouse | Why |
|---|---|---|---|
| the drop preview | floating | no | Only looked at. It lies under the pointer of every drag that is about to dock |
| `StagePanel` | floating + 1 | no | Covers a display while windows move |
| `BackdropPanel` | desktop icons + 1 | no | The surface behind the arrangement; can cover a display |
| `RubberBandPanel` | floating | no | The rectangle being drawn, under the pointer that draws it |
| `FocusRingPanel` | normal | no | Lies around a window, over its resize area |
| `HeadsUpPanel` | floating + 3 | no | A line that comes and goes by itself |
| `TilePanel` | normal | yes | A click zooms in. No larger than its space; behind every window; lets everything through once it begins to leave |
| `SeamPanel` | normal | yes | A drag moves the gap. As wide as the gap; behind every window |
| `PeekOutlinePanel` | floating | yes | A click chooses the space, and must not reach the app under it with ⌃⌥ held. Only while the peek's keys are held |
| `MinimapPanel` | floating + 2 | when asked | A click goes there while the model says that it takes clicks (`MinimapModel.takesClicks`); nothing once it begins to leave |
| `CheatSheetPanel` | floating + 2 | yes | Any click puts it away |
| `NamePanel` | modal panel | yes | A text field |
| `FinderPanel` | floating + 2 | yes | A text field and a list |

Three more are ordinary windows with a title bar, which a person opens and closes. They take the mouse as any window does, and none of them covers
a display. They float at times, and the test knows those lines word for word:

| Window | Level | Why |
|---|---|---|
| the welcome window | floating in its first steps, otherwise normal | The moves it teaches are made in other apps' windows, one of which then fills the display. For those steps it waits at the right of the screen |
| the settings window | floating while it has the keyboard, otherwise normal | Tiles and gap handles come to the front whenever the layout is drawn again, which every change made in it causes |
| the update window, an alert of macOS's | floating | Arbor has no Dock icon to find it by |

## Leaving the arrangement

Docking stretches a window to its slot. `Workspace.undockedFrames` remembers the frame it floated at (the one
in `floating`, which the user chose, not where docked windows have pushed it since): `Workspace.dock` and
`reset(tree:)` set it as the window stops floating, moving a docked window leaves it alone, `undock` and `forget`
drop it, and it is saved with the workspace. A window docked by a rule as it opens floats for an
instant first, so what is remembered is the frame its app gave it. `Controller+UndockedFrames.swift` uses it in two ways:

- **One window floats** (`float`, `toggle-float`, a drag out of its slot): the remembered size, where the person
  is looking. For the commands that is centred on its slot, then moved onto the Desktop if that is in view (not
  shrunk: beside a Desktop narrower than itself it hangs over the docked windows), otherwise onto the display; floating
  the framed window moves the view to one that shows the Desktop. A window dropped out of its slot takes its size
  under the pointer, which stays as far along its title bar as it was; if it grew, it slides back onto the display as far
  as the pointer stays on the title bar. Either way the layout that follows leaves it where it was put
  (`placedOnPurpose`), and with the Desktop out of view it becomes a guest of the view it floats over (`stayWithTheView`).
- **Arbor lets go** (`float-all`, quitting, excluding its app; pausing, for windows out of view): the remembered frame, position too, exactly,
  unless the display has changed so that it is no place for a window any more (`asItWas`), in which case it is fitted
  into the display. That includes windows that take no space just now (minimized, hidden, on another macOS Space),
  which would otherwise come back in the shape of a slot. Windows that floated all along go back to the frame in
  `floating` if docked windows pushed them aside or squeezed them.

A window with nothing remembered (an arrangement saved before this existed) keeps the size of its slot. A window
docked on another display than the one it floated on takes the frame along, as far from the new display's
corner as it was from the old one's (`transfer`). When a display goes away its docked windows float on the main display at
their own sizes.

## Edge resizes

A managed window whose size changes while the button is down, after a press on
its border (see Drag and drop), is being resized
by its edges: `AXWindowSystem` sends `resizeBegan`, and on mouse-up a
`windowChanged` with the final frame followed by `resizeEnded`. For a docked
window, `Controller+EdgeResize.swift` compares that frame with the window's
slot in the current layout. Each edge that moved more than 4 points (from the
slot, and from where the window sat before, so an app that sits inside its
slot does not count as moving an edge) moves the seam on that side: the
nearest split along the edge's axis where the window's branch has a neighbour
on that side, the same search the `resize` command uses. Seams nearer the root
move first, and each edge is measured again in a fresh layout, because moving
an outer seam rescales the splits inside it. Edges with no seam in view are put
back. While the resize lasts, enforcement on that display waits for
`resizeEnded`, plus one round after the button is up, because the mouse-up
event can arrive a moment after the button is physically released.

## A window that floats alone

With `soleFloatTakesDesktop` on, and `floatingWindowsMakeWay`, without which Arbor sizes no floating window (spec F18, `Controller+SoleFloat.swift`, `soleFloatIsOn`), `placeFloatingWindows` stretches the only floating window that takes
up room on a display over the Desktop instead of placing it at its own frame. That frame stays in `Workspace.floating`, so the ways back
need no code: as soon as the window has company, the setting goes off or no docked window is left, the next layout places it like any floating
window. A floating window arriving, or leaving for another display, causes no layout by itself, so those events ask for one while the
setting is on. A window its user has moved, resized or dropped while it was alone is "in hand" (`SoleFloats.inHand`) and keeps that frame until it has
had company or been docked. Whoever adds floating windows that do not live on the Desktop leaves them out in `windowAloneOnDesktop(of:)`.

## Focus ring

A line around the window that has the keyboard (`OverlayScene.focusRing`, `Controller+FocusRing.swift`,
`UI/FocusRingPanel.swift`; spec F37). Which window that is comes from `system.focusedWindow()` each time the ring is
worked out: an app in the background reports focus changes too, so events only say when to look again
(`windowFocused`, `windowAppeared`, `windowChanged` for the ring's own window, and `keyboardFocusMoved`, which
`AXWindowSystem` sends when another app comes to the front or the keyboard goes to something that is not a known window). A relayout
works the ring out with the rest of the display's scene; everything else sends a fresh scene to the displays whose
ring is out of date and moves no window. While the mouse drags or resizes something the ring is hidden, and the controller
looks every 0.1 s whether the button is up, because nothing reports the end of a seam drag. The model's `pulse` token
changes when the ring goes to another window within half a second of a command or a camera move, and the view
flashes. The panel sits at the normal level directly above the focused window, so whatever covers the window covers the
ring; the view restores that order on every mouse-up, because a clicked window comes to the front after it takes the keyboard.

## Named spaces

`Workspace.names` maps a name, as typed, to a node (spec F20; `SpaceName`, `Workspace+Names.swift`, `Controller+NamedSpaces.swift`). It changes only through
`setName` and `removeName`, which keep two rules (no two names alike, capitals aside; no node with two names) and mark exactly the named groups as kept for
`.name` (F62), so a named group neither dissolves into the group around it nor gives way to its last window. Names follow `Remap.survivor`: a node
that went with its last window takes its name along, because the parent `resolve` would answer with was never called that. Two moves are the workspace's own: a
window that is all its space holds carries the name to where it is docked next, and when a window docked at the edge of the view wraps a named space, the wrapper
takes the name over. A `state.json` cannot break the rules: entries that point nowhere, are not possible names or repeat are dropped with a note, and the table, not the
tree's marks, decides what is kept for a name.

`go` looks on the display commands act on first, then on the others: whole names before beginnings. Whoever shows names asks `namedSpaces()` or `spaceName(of:on:)`
and listens for `Change.names`. The field of ⌃⌥N is a model in the display's scene (`OverlayScene.namePrompt`, `NamePromptModel`): its frame, its words and what ↩
does with any text are decided there, and `UI/NamePanel.swift` only shows it and runs the commands through `OverlayActions.perform`. The controller remembers which space
the field is open for; a scene put together while the view is elsewhere drops it, which is how it closes when the view moves. A focus report for another window that
really has the keyboard closes it too.

Names are the user's own words and are not logged. Replies speak them, so `perform` takes every name that exists, existed before the command or is in the command out of the line it
logs (`withoutNames`, `Command.textWithoutNames`); whatever logs a space's words elsewhere asks `name(of:on:byName: false)`.

## Undo and redo

Trees are values, so an undo step is the display's `Workspace` as it was before a change
(`UndoStep`, `UndoHistory` in ArborCore; `Controller+Undo.swift`). **Recording** is done in one place:
`perform` takes a copy of the workspaces before every command and compares afterwards; a display whose tree
(leaving out which tabs show) or set of floating windows differs gets a step. Camera moves, saved views
and floating frames do not count. Entry points that are not commands wrap themselves in
`recordingUndo("label") { … }`: `finishDrop`, `seamDragged` (the moves of one mouse-down become one step),
`resizeEnded`, the rules' docking and `windowDestroyed`. Anything new that changes a workspace outside `perform` must
do the same. Scopes nest (the outermost records) and never stay open across events.

**A layout may change a tree by itself**: it moves gaps to make room for a window that would otherwise be a tile (F61). In the same breath as a
change somebody made, that is part of the step. By itself (the view moved, and from further out a column is too narrow) it is not
a step: `roomyLayout` calls `noteThatRoomIsMade(on:)` first, and `endUndoStep` passes over a display on which nothing else happened. Whatever
else teaches layouts to change a workspace does the same, as `startFromTheGapsThatStood(on:)` does.

A change is first tried out: if undoing it at once would change nothing (a window that closed stays closed, `exclude`
takes windows an undo could not bring back) it is no step. If it changed what is docked all the same, it is kept as a
step that is only there to be mentioned (`UndoStep.isIrreversible`): the next `undo` fails, says what cannot be
undone and what the press after it would take back. A step can also stay open for more of the same change
(`UndoContinuation`): until the mouse button is up (`whenTheButtonIsUp`: nothing reports a release over Arbor's own panels, so a
timer named `undo-continuation …` looks every 0.25 s), until a second has passed without another (`afterAPause`, for the
commands in `Command.mergesWithRepeats`), or until its owner calls `undoHistory.finishContinuation(key)` (`whenToldTo`).
Any other step on the display, and any `undo`, ends it.

**Restoring** fits the old workspace to the present (`restorations(from:)`): closed windows are forgotten with
the usual remap, windows docked on another display since stay there, windows the old workspace does
not know float, slots that wait for their window go on waiting. `Workspace.restored(over:since:)` then carries over
what happened since that is not arrangement (camera, history, saved views, moved floating windows, showing tabs,
guests, pins), by comparing the workspace right after the change with the current one. With nothing done since, the result
is the old workspace exactly. If the view would stay put and look the same, it steps out just far enough to show the
change (`steppingOutToShowTheChange`). A change to two displays is a step on each with a shared id, taken back
together while it is the newest on both. The history lives in memory only.

`install` then lays the displays out as for any change of structure. Layouts leave alone floating windows that are not on
the Desktop, and a window that was docked a moment ago is still in its slot, so `floatingPlan` first decides for each
floating window of the restored workspace whether it goes to the Desktop, back to where it was in view, or out of view.
It moves nothing. **The layout does the moving**, once its stage is up (`relayout(…, puttingBack:)`, `placedOnPurpose`,
`leavingView`): a window moved before the layout would vanish without a trace, one moved after it would jump when the stage
lifts (`UndoMotionTests`). **A feature that gives floating windows a new way to be in or out of view** (guests, pinned,
summoned and stashed windows) **gives `floatingPlan` a branch, as it does `floatingMoves`.**

**What a step is called** (`UndoStep.label`, from `Command.label(focused:)` or whoever opens the scope) is quoted in replies, which go to the
log, to traces and, after a shortcut, on screen, long after it was written. `perform` can only strike the names there are at that moment. So **no label
holds part of a window's title or the name of a space**: a space is called by what is in it (`name(of:on:byName: false)`), a `layout` line
goes without its titles, and a command made of such words (`Command.mayHoldPrivateWords`) is called by its first word.

**A window can change its number** while it stays the same window to the user: a waiting slot is taken by the window it
waited for, a native tab comes to the front, an app restarted during a pause. Whoever calls `replaceWindow` on a
tree also calls `undoHistory.renumber(old, as: new)`, or the steps go on meaning a window that no longer exists: the next
undo would drop its slot and float the window.

### A new field in `Workspace`

A step is a copy of the whole `Workspace`, so a new stored property is saved and put back with no code at all. That is
right straight after the change and wrong later, when putting back the old value throws away what happened to the
field since. `everyStoredPropertyOfAWorkspaceIsDealtWithWhenAnOldOneIsPutBack` fails until `restored(over:since:)` names the field.
Ask of it: **can it change while the tree and the set of floating windows stay the same?**

| The field | Examples | `hasSameArrangement` | `restored(over:since:)` |
|---|---|---|---|
| **is arrangement**: what is docked where and how large, and who floats. Changing it is what `undo` is for | `tree`, the keys of `floating` | compares it | the old value |
| **follows from the arrangement**: no, it changes only in the same breath as the tree or the set of floating windows | the frame a docked window floated at before (`undockedFrames`, F48); whether Arbor took the Desktop's room (`desktopIsOwedRoom`, F61) | leaves it out | the old value, and a comment that names the field and says so (and `undockedFrames` takes the frame of a floating window moved since) |
| **is about the arrangement**: yes. Changing it alone is not a step, like `save-view` | `camera`, `back`, `forward`, `savedViews`, the frames in `floating`, the showing tab, `guests`, `pinned`, `summoned`, `stashed`, `summonFrames`, `names` | leaves it out | carried over |

Carrying over, for a field keyed by window, node or slot: an entry that differs between `reference` (the workspace right after
the change) and `current` was made since, and wins, if it still makes sense in the restored workspace (`survives(node)` for
a node: an id alone says nothing, `arrange` numbers from 1 again; `result.isFloating(window)` for a floating window). An entry of
`reference` that `current` no longer has was removed since, and is removed from the result. Everything else keeps the old value, so
that with nothing done since the result is the old workspace exactly (`withNothingDoneSinceEverythingComesBack`).

Whatever its kind, the field also follows `Remap` in `Workspace.apply(_:)`, is cleared in `reset(tree:)`, loses a window in
`forget(_:)` (restoring calls it on the old copy for every window that has closed), moves with the window in
`renumber(_:as:)`, and is optional or has a default when decoded.

One field is none of the three: `lookingFrom` (F51) says that the view is only visiting, for as long as a key is held. Every command ends that, `undo`
included, so a step that was saved meanwhile comes back as the view it would have returned to. It is the one field that is not saved: whoever reads
`state.json` finds nobody peeking, so what `persistedState()` writes with the keys down is the stay the look would become (`withEveryLookOver`).
## Keyboard tiling tools

`focus`, `swap`, `grow`, `shrink`, `balance` (`equalize` in the code), `rotate`, `mirror`, `move-to-display` and `focus-display` (F22) live in
`Controller+KeyboardFocus.swift` and `Controller+Tiling.swift`.

**Which window lies that way** is a question about rectangles, answered by `DirectionalSearch.nearest` in ArborCore for
windows, tiles and displays alike: candidates whose centre is past the origin's edge; those beside it before
diagonal ones; then the nearest, the longest shared span, the most recently focused (`focusHistory`), the topmost.
Nearness comes before overlap because a tall window two columns away shares more of the origin's span than either
window of the column in between. Docked windows are measured by their slots (`Layout.nodeFrames`), not their frames, so
an app that rounds its size does not look nearer than its neighbour. Entering a space, a tile or a display is the same
search from the old frame slid to just outside the new view (`approaching`).

**Giving focus.** macOS makes a request for focus true, and reports it, a moment after `WindowSystem.focus` returns. So
`giveFocus(to:)` calls `windowFocused` itself: the history, the window's tab and the camera are right when the command
returns, and hearing the same change again from macOS changes nothing. And until macOS agrees (for half a second
at most) `keyboardFocus()`, which `target(nil)` and the tiling tools ask, answers with the window that was asked for, so
a second key pressed quickly goes on from there instead of starting again from the old window. A report of focus going
anywhere else than to that window, or to one asked for just before it, ends the request (`endFocusRequest(unlessFor:)`).

**Which display.** `focus`, `rotate` and `mirror` start from the focused window and act on its display (`keyboardDisplayID`, which is
`focusedPlace` of Controller+Lead.swift, and that asks `keyboardFocus()`). `balance` is about the view and asks `cameraDisplay()`.
None of them moves the pointer: shortcuts follow the keyboard to another display by themselves (F56).

**Trading places.** `LayoutTree.tradePlaces` moves the two leaves, not what they hold: each takes the other's parent, position and
weight and keeps its id. So the slots keep their sizes, and the camera, history, saved views and guests, which all refer to
nodes, follow the windows without being told. Between two trees ids cannot travel, and `swapLeaves(of:in:and:in:)` exchanges the contents.

**Turning a split.** Axes alternate down the tree. `LayoutTree.rotate` therefore turns every split inside the one it is given. A split
that is not the root then runs along its parent, where the tree would dissolve it; it is kept instead (`Keeps.turned`, F62), so
that no node comes or goes, the windows keep exactly their room, and turning it again gives back the same tree. The mark goes
when it no longer makes a difference (`Workspace.changeStructure` sees to that), the split when it is down to one child.
The controller tries the result first and refuses if a window that shows now would become a tile; and looks again after
the layout, because an app's smallest size is learned by asking, and turns the group back if one refused.

**Growing and shrinking** reuse the seam search of `resize` and the order of an edge resize (outer seams first, each edge
measured again in a fresh layout). `shrink` stops at the size below which the window would become a tile; if its
app refuses a slot Arbor thought was fine, the seams go back and the command runs once more with what it learned.

## Saying what happened

Every command replies in a sentence. `arborctl` prints it; someone who pressed keys, pinched or used the menu has nowhere to read it. So every
entry point says who it is, `Controller.perform(_:from:)`, and the replies that matter to a person go on screen as one line, low on the display
the command acted on (`executeAndSay` in `Controller+HeadsUp.swift`; spec F43). That is the display F56 chose for the command: the line asks `cameraDisplay()`.

- **What earns a line** is `HeadsUpPolicy` in ArborCore (`HeadsUp.swift`): a failure; a success of a command that `worksUnseen`, or that left everything a person can see as it was (the controller compares `Seen` before and after); with `messages: "all"` every
  reply; nothing for scripts and URLs, nothing with `"off"`. A new command whose success cannot be seen adds itself to `Command.worksUnseen`;
  one that opens a panel, a field or a window of Arbor's own, which is answer enough, to `Command.opensItsOwnAnswer`.
  A success whose reply says that something else went with it (`HeadsUpText.namesALoss`: "…; 2 saved views are gone") is said as well, before any hint, with the keys that undo.
- **The words** are the reply's, made fit for the screen by `HeadsUpText`: capitalised, `(n5)` dropped, `w412` replaced by the app's name (never the title, which it
  has no way to learn), a quoted command replaced by the keys in effect or, without keys, by `Command.title`, and advice that only makes sense at a terminal left out.
  Bundle ids become app names, and which display the command chose is dropped, because the line's place says it. So replies can go on being written for a terminal; `lineOfItsOwn` holds the two outcomes where the
  reply has nothing to offer someone at the keyboard (a floating window asked to be framed, an app Arbor does not arrange).
- **Teaching moments** (`HeadsUpHint`) are read from what changed on a display, not from commands: the controller keeps `HeadsUpFacts` (docked, out of view, tiles)
  per display and compares after each person's command and, when no command is running, after each layout, which is how a drop, a click on a tile or ⌘Tab teach
  too. What a script changes only moves the baseline, and so does the first layout after a launch, a pause or plugging in a display. Each hint is shown three
  times ever; the counts are `hintsShown` in `state.json`. Whatever lays a display out several times before it knows what it wants wraps itself in `summingUpForTheLine(on:)`, as automatic docking does. A window `summon` sent away does not count as out of view: whoever sent it knows, and showing everything does not bring it back.
- **Where and how long** are in the model (`HeadsUpModel.anchor`, `maximumWidth`, `duration`). `placed(in:above:)` takes the frame of another passing panel at the bottom of the
  display, for the minimap: the line sits directly above it.
- **Showing it**: `OverlayPresenter.showHeadsUp(_:on:)`, one line at a time; the controller takes it away through the scheduler (key `heads-up`). `shutdown()`, and so
  `pause`, removes it with every other overlay; a pause then says that it began, which is the one thing Arbor shows while paused, for a few seconds.
- **VoiceOver** is told each line (`HeadsUpModel.spoken`, an announcement from `AppKitOverlays.showHeadsUp`), since it would not come across a panel that never has the keyboard.
- **The log** (debug) gets each line, `said on <display>: …`, which is what the Mac script reads. A line that repeats a reply is made a second time for it, from the reply as `execute`
  logs it (`withoutNames`, `forTheLog`), because on screen a space is called by its name and in the log it is not. Of the reply to a command that changes settings, which can quote a
  rule's part of a window title, the log gets no word: "the reply to `rule`".
- **The shortcuts on screen** (`show-shortcuts`, `Controller+CheatSheet.swift`): `CheatSheetModel` lists `KeyBindings.effective` by `Command.title` (a command with a default shortcut must have a `listedTitle`, which a test sees to), in the groups and the order of
  `Command.helpText`, which it reads (`Command.group`, `helpOrder`), so a command added to the help is in the right place in the panel. Families (⌃⌥1–9, ⌃⌥⌘ + arrow) fold into
  one row while they are complete, and `pointerRows(settings:)` adds what the pointer and the trackpad do. `showCheatSheet(_:on:)` draws it; a key or a click comes back as `OverlayActions.cheatSheetDismissed()`, and any command but a query puts it away, as does any shortcut's key going down (`Controller.shortcut`), since a peek takes keys without running a command.
- **The panels** (`UI/HeadsUpPanel.swift`, `UI/CheatSheetPanel.swift`) share `PassingPanel`: on a `PanelGround` (below), two levels above `.floating` (the stage is one above),
  on every Space except other apps' full-screen ones, fading in 0.1 s and out in 0.25 s unless "Reduce motion" is on. The line ignores the mouse. The panel of shortcuts becomes the key
  window without activating Arbor, so the key that ends it is not typed into the document behind; it leaves at once, because a fading key window would swallow what is typed next.
- **What every panel stands on** (`UI/PanelGround.swift`; the line, the panel of shortcuts, the minimap, the field for a name, Go to…): one of macOS's materials cut to rounded corners, a veil
  over it, a hairline round it. The numbers are in `Platform/PanelLook.swift`, headless: one table of corners (20 for panels, a capsule for the line), the veil, and two inks, black or white at 85 % and 65 %.
  **The measure:** in the look that ships, over a saturated red, a saturated blue, white and black, on a picture: words a person must read to act at least 4.5 to 1, all others at least 3, nothing below.
  `PanelLookTests` reckon that anywhere from what the materials were measured to be on a hosted Mac. macOS's secondary and tertiary label colours are not used in what Arbor draws by hand: there they are greys
  that stay grey whatever the ground has become. With Increase Contrast macOS itself outlines every window that has a shadow, so Arbor draws no line then.

## What Arbor draws at rest

How things look is decided where tests reach it, and AppKit only draws the answers (spec F15). The chain: `Settings` keeps what the file says;
`Settings.appearanceOptions` (`ArborCore/Appearance.swift`) makes it safe to draw with wherever it came from (amounts within 0...1, choices Arbor knows; what settings.json says has been through
`SettingsSchema.sanitize` before, which reports what it changed); `Controller.applyAppearance` (`Controller+Appearance.swift`, called from `overlayScene(for:on:)`) writes it into the `OverlayScene`; the UI draws the scene.
Whatever is drawn is part of the scene, so an equal scene needs no redrawing. No option moves a window.

- **The backdrop** (`OverlayScene.backdrop`, a `BackdropModel`) is the surface behind docked windows. `BackdropShape` takes every slot in view (leaf
  rectangles, not window frames, and tiles), grows each by half the gap rounded up, so that neighbours meet in the middle of the gap, merges them, cuts the result off at the visible
  frame and takes the Desktop's rectangle out. The result is canonical: it depends on the area covered, not on how slots divide it, so trading two windows'
  places or dragging the gap between them changes nothing and redraws nothing. `outline(slotRadius:)` rounds it: outer corners concentric with
  the windows' corners, inward ones by no more than three times the growth, which keeps the rounding off the Desktop. `UI/BackdropPanel.swift` has one
  panel per display, one level above the Desktop's icons, mouse-transparent and `.transient`: a `BackdropLayer` (a shape layer; one shape cross-fades into the
  next, except during a drag) and, only while `blurBehindArranged` is above 0, an `NSVisualEffectView` masked with the same outline. The stage (F02) covers the panel while windows
  move, so it hosts a `BackdropLayer` of its own between its picture of the desktop, which is taken without Arbor's own windows, and the stand-ins: it goes up with `backdrops.model(on:)`, what the display shows at
  rest, and when `update` brings the scene the motion ends in, that shape fades in over the motion. Blur is not drawn on the stage. The fill is one colour, the accent at `tint` over black at `dim`
  (`BackdropModel.fill(accent:)`); the hairline around the Desktop (`desktop`, `desktopEdge`, `desktopOutline(width:radius:)`) is a sublayer, one pixel wide, there only while the Desktop is in view as itself beside something docked.
- **Tiles**: `TileArt` (`Platform/TileArt.swift`) turns a `TileModel` into plates, icons, a glyph, a caption and a badge, with frames, outlines and colours, in the tile's own
  coordinates with y down; `UI/TileDrawing.swift` draws the parts in order. `TilePalette` mixes `appColourAmount` of the app's colour into the grey of light or dark mode; text on
  it is black or white, whichever contrasts more (`RGBA.ink`). A fill of middling lightness gives way to its ink until that has `TilePalette.legibleContrast` on all of it. A space's name (`TileModel.name`, F20) is drawn in every style: as the caption, or in a group's capsule in place of the count. The app's colour is the most prominent vivid hue of its icon (`IconColour.dominant`), from 24×24 samples that
  `AppAppearance` reads once per app. A tile's panel fades in when it appears and out when it goes, over `OverlayScene.tileFade` seconds; one that is fading out takes no more clicks.
- **Shapes** are lists of `PathElement` from `RoundedPath` (macOS's continuous corner curve), bridged by `NSBezierPath.make` and `CGPath.make`. Tiles, the drop preview, the backdrop and the
  focus ring share one window radius, `ContinuousCorners.windowRadius`.
- **Stacking**: tiles and gap handles are panels at the normal level that stand where no docked window is, so they go on screen at the back of that level and are sent back there whenever they change
  (`OverlayPanel.orderInBehind`). Whatever else lies there, a floating or pinned window or one Arbor does not arrange, stays in front of them, in view and within reach of the mouse.
- **The handle in a gap**: `SeamHandle.pill`; `gapHandles` "hidden" clears `scene.showsSeamHandles`, "off" empties `scene.seams`, and without seams there is nothing to drag.

## Minimap

A small picture of a display's whole arrangement with the space in view marked (spec F26). `ArborCore/Minimap.swift` decides everything a
screen is not needed for: `Minimap` runs the real layout engine at the root into at most 220 × 140 points, so the map cannot
disagree with the arrangement, and `MinimapModel` puts it in a panel low on the display, in the panel's own coordinates, and turns a click
into a node (`space(at:)`). `Controller+Minimap.swift` decides when. It observes `.layout`, not `.camera`: the view has moved when
`layouts[display].camera` is another node than at the display's last layout, which also catches the moves nobody announces (the framed
window closed, a dock widened the view) and ignores announced ones that went nowhere. None passes by when the view goes to everything, nor when the set of docked
windows on another macOS Space or in full screen changed since the last layout; a display seen for the first time only sets the baseline, so launching, resuming
and plugging in show nothing. It ships off (`minimapDuration` 0). `minimapMayAppearUnasked` is the one gate for whatever forbids Arbor to show things unasked. It goes through
`OverlayPresenter.showMinimap(_:on:)` rather than `OverlayScene`, because it comes and goes by time (`minimap-<display>` in the scheduler), not with the
layout. Asked for (`minimap`), the model says `takesClicks`, and `OverlayActions.minimapClicked` goes the way a click on a tile goes. Its shortcut can be held like the peek's: presses and releases come through
`Controller.shortcut(_:_:run:)`, a timer (`minimap-tick`) outlines the space under the pointer (`hover`) and finds releases nobody reported, letting go is a click where the pointer is, and ⎋ gives up. Its time starts again for as long as the pointer is on the panel. Where it takes clicks its frame is among `desktopGuardZones().panels`, announced as `.frames`. `UI/MinimapPanel.swift` keeps
one panel per display and draws the model in one `draw`. `minimapFrame(on:)` is for the heads-up line (F43), which sits above it.

## Pointer input

Trackpad pinch (F03) and the rectangle drawn with ⇧⌘, or with ⇧ from the Desktop (F05), come from session event
taps (`Input/EventTap.swift`), which see events before apps do and can
swallow them. macOS holds back every event a tap watches until its callback
returns, so the callbacks only feed pure state machines in ArborCore
(`GestureRouter`, `RectangleGesture`) and decide whether to swallow;
commands and drawing run afterwards via `DispatchQueue.main.async`. The
rectangle ends as an ordinary `frame-rect` command, which is what the tests
exercise.

The taps run on their own thread with its own run loop (`EventTapThread`,
user-interactive priority), so a busy main thread (a relayout waiting on a
slow app's Accessibility calls) never holds up clicks, drags or trackpad
gestures. A callback reads its gesture state from a lock-protected box that
the main actor only reconfigures (`update()`) or resets (`stop()`). The
rectangle framer has a tap on mouse-downs and a second one on drags and
mouse-ups that is paused except while a modifier press is being followed, so
ordinary drags never pass through Arbor at all.

Whether a pinch without ⌥ is Arbor's depends on what is under the pointer.
`WindowList` reads the window server's list and the pure `PointerSurface`
decides: an ordinary window, a menu, the menu bar or a floating palette is an
app's; the wallpaper, a gap and Arbor's own tiles are not; Arbor's own panels
are looked through (the focus ring's lies over the whole focused window); a window above the
ordinary ones that covers a whole display is looked through, because the
Dock keeps one there at all times.

The rectangle's taps also keep a plain click on bare Desktop from macOS, which would sweep every window aside
(F60). "Bare Desktop" is one rule, for that click and for ⇧-drag: three questions, the cheapest first. The controller
publishes `DesktopGuardZones` after every change (an observer in `ArborApp`): the view of every display with something docked, less
where the windows Arbor knows to be in view really are, and for a plain press less its tiles and gap handles;
nearly every click on a Mac leaves there. Then the window list says whether the place is really bare, whether anything
else on screen may be waiting for the click, and whose the icons are there (`PointerSurface.under`). The press is held, as a modifier-press is, and the third question, whether an icon or
a widget is under the pointer, goes to that process through Accessibility, **not from the callback** but from
`DesktopProbe`'s own queue while the button is down. The answer is needed only when the button comes up: a click known to be on the
wallpaper is dropped; a drag and a click on an item are given back. With tap to click the button is up before Finder has answered: then
the mouse-up is held as well, and both halves are dropped or sent on when the answer comes, when another press does (which they
precede), or after 0.3 s. No callback waits for any of that. With ⇧, a drag
known to start on the wallpaper draws the rectangle and everything else is given back; its drags wait for the answer, which
always comes ("there is an item" if Finder does not say).

**A click that is kept from everybody must be one that nobody is waiting for, wherever they are.** People click the wallpaper to be rid
of a menu, Spotlight, Control Centre. So `PointerSurface.under` is a list of what is harmless, not of what is not: above the palettes
(level 3) it allows what a Mac at rest was seen to have (one window as large as each display at level 20, the Dock's; the
menu bar at 24 and its items at 25, no taller than a menu bar) and takes any other window, anywhere on screen, Arbor's own
menu included, to be waiting. Below the windows the frontmost thing at the point must be at the level of Finder's icons, or below it: where people hide the icons there is no
such window, it is the wallpaper, and nobody is asked. What
nobody has measured therefore gets its click. That part is for the plain click alone (`mayVanish`): a press with ⇧ is given back or
becomes a rectangle, takes nothing from anybody, is on by default, and must not stop working on every Mac that has something
unknown above its windows all day. What is under the pointer counts for both. `appWindowIsUnder`, which only says who gets a pinch, stays lenient: **do not use a rule
made for taking a gesture to decide that a click is destroyed.** A panel of Arbor's that closes at a click beside it must be
above the floating level, or have a title, or the guard will eat that click.

With `continuousZoom` a pinch and a ⌃⌥-scroll are not turned into commands but streamed (F16). The
callbacks add their deltas up in `GestureStream`, under the same lock, and ask the main actor to come by once
per burst; it collects a few `GestureUpdate`s and hands them to `Controller.gesture(_:)`. However long
the main thread was busy, it finds where the fingers are now, not every place they have been, and
every `began` is followed by exactly one `ended` or `cancelled`.

A scroll with exactly ⌃⌥ held (`GestureRouter.Keys`) is Arbor's: up and down it zooms (F55), sideways it slides the view (F16), and the way it first moves decides for all of it. A scroll with ⌥
alone never is. The scroll tap is therefore installed by default (`scrollZoom`), but paused: switched on, every scroll on
the Mac would pass through it, a hundred a second. `GestureRouter.scrollTapIsWanted` says when it has to be on (⌃⌥ down, a scroll of Arbor's or
its momentum, a pinch of Arbor's with `continuousZoom`); two monitors for modifier keys (a global one, and a local one for what goes to Arbor's own windows) and the handlers themselves
switch it. None of them remembers what the keys were: a key that goes up unheard (a menu, secure keyboard entry) would make the memory wrong and the next press would be ignored. While it
is on, `scrollNeedsALook` sends most scrolls on after reading the event's flags and one comparison under the lock. `ScrollZoom` counts notches and points of travel into steps; with `continuousZoom` the router streams the same scroll as the
magnification of a pinch that would have stepped as often.

Once a second `PointerInput` checks that Arbor still has Accessibility
permission and removes the taps if not, because an active tap left behind then
has been reported to stop all input; the same check switches a tap back on
that macOS switched off.

What macOS 26 does with a tap that does not answer, measured by stopping Arbor
(`scripts/mac-shell/input-taps.sh`): the event waits, and so does every event
behind it, including types the tap does not watch. Nothing happens until
the next event arrives; if the tap has then been silent for more than about a
second (0.6 s was tolerated, 1.8 s was not), macOS switches it off and
later events pass. The events that were waiting stay stuck until the process
answers or dies, and then arrive late and out of order. The callback hears of it
(`tapDisabledByTimeout`) only in place of the next event the tap would have had. So a slow
handler costs everyone a second of frozen input and a misplaced click each time the tap
goes back on, which is why after three switch-offs in ten seconds all the taps are
left off for thirty (`TapHealth`): Arbor gives up its gestures rather than freeze the Mac again. All of them, and counted
together, because they share a thread: the event that got past a tap that was switched off waits at the next one, and
with a count for each tap, two taps on mouse-downs would freeze the Mac six times before Arbor let go.
With a healthy tap a mouse-down takes about 0.2 ms longer to reach its app (0.23 ms without
Arbor, 0.41 ms with), and one that needs the window list about 3 ms.

### Writing an event tap

An active tap sits in the path of every event it watches, for every app. A bug
in one does not break Arbor, it breaks the Mac. A tap is an `EventTap` with
a handler; these are the rules for handlers, and `RectangleFramer` is the model.

1. **Watch as little as possible.** The mask names only the event types needed.
   A stream that matters only during a gesture (drags, mouse-ups) gets its own
   tap, started with `start(paused: true)`, resumed by the handler that sees
   the gesture begin and paused by the one that sees it end. A paused tap costs
   nothing. Install the taps of one gesture together, in `update()`: a tap
   created later goes in front of every other app's taps, and one of theirs
   caught between two of Arbor's sees half a gesture.
2. **Leave at once if the event is not yours**, before allocating anything: compare a field or
   the flags and return false. `NSEvent(cgEvent:)`, the window list and anything else that
   costs more than a few microseconds come after that test.
3. **Never wait without a bound.** No `sync` to the main actor, no semaphore, no file, no `Log`
   (use `TapLog`, which writes from the main queue). A question to another process is asked
   only for the one event that decides whose a gesture is: the window list (`WindowList`, about
   3 ms), or an Accessibility call on an element with its own short messaging timeout. Check the
   time left before every such call, and keep the worst case of all of them together under
   0.3 s: all input waits meanwhile, and somewhere between 0.6 s and 1.8 s macOS switches the tap off.
   Better still, do not ask from the callback at all: if the event is being held back anyway, ask from another
   queue and use the answer when the gesture ends (`DesktopProbe`).
4. **Share state through a lock, briefly.** State that both the handler and the main
   actor touch lives in an `OSAllocatedUnfairLock`. The main actor builds a new value
   outside the lock and takes the lock only to store it. What the handler needs from the
   controller is published this way as a `Sendable` value; the handler never asks.
5. **Decide in ArborCore.** The handler reads the event into plain values, feeds a pure state
   machine (`GestureRouter`, `RectangleGesture`, `PointerSurface`) and does what it
   answers, so every decision has unit tests although no tap can run in one.
6. **Decide whose a gesture is once, at its start, and keep to it until it ends.** An app
   that saw a gesture begin sees all of it; one that did not sees none of it, including
   momentum and whatever else trails after.
7. **Swallow in pairs.** Never swallow a mouse-up whose mouse-down an app saw: the app is left
   in a drag. An event held back to see what follows is either given back
   (`tapPostEvent`, which puts it ahead of the event the handler returns) or belongs to a
   gesture that is swallowed whole. Hold it back only if it can be given back.
8. **Mark what you post** with `EventTap.replayMark`, and let through, untouched, any event
   that carries the mark: it passes every tap behind the one that posted it, Arbor's included.
9. **Work goes to the main actor afterwards, coalesced.** `DispatchQueue.main.async`, after the
   decision. For a stream (a band that follows the pointer, a continuous zoom) keep the latest
   value or the running sum in the locked state, with a flag that says a block is already
   queued (`RectangleFramer.showBand`, `GestureStream`). One block per event would pile up behind a busy
   main thread and replay stale motion when it wakes.
10. **Distrust the numbers.** Other tools post events too. A delta can be NaN, infinite or
    1e300; the state machine cuts it to something a hand could do before counting with it.
11. **`onReset` forgets everything.** It means events were missed (macOS switched the tap off).
    Drop the gesture, drop the held event, hide what was drawn, pause the second tap.
12. **Do not remove a tap from inside its own callback** (`stopAfterCurrentEvent()` is for that).
    Pausing and resuming are fine there and take effect before the next event.

## Threading

Everything in ArborKit is `@MainActor`, except the event taps and the queue the state file is written on. AX observer
callbacks, Carbon hotkey events, NSEvent monitors and the control socket's
dispatch source all run on the main run loop and enter the main actor with
`MainActor.assumeIsolated`. Event tap callbacks run on `EventTapThread`
(above) and hop to the main actor with `DispatchQueue.main.async` only to run
a command or draw.

AX calls are synchronous, on the main thread, with a 1-second messaging timeout
set for the whole process and on every element that is kept. Moving one window
takes four to six calls, so a hung app with a few docked windows could stop
Arbor for many seconds at every layout. The first call that times out therefore
ends the conversation: `setFrame` returns nil, and nothing more is asked of that
app until it answers a call made off the main thread (tried twice a second) or
posts a notification. Its windows are then reported again, and the controller
places the ones it could not move (`unplaced`). A window that could not be parked
does not count as parked. A call that fails at once means that the process is gone;
if nothing reported its end (an accessory app, one started from a shell), it is
forgotten then.

## Traces

Each platform seam is wrapped in a decorator (`Sources/ArborKit/Trace/`): `RecordingWindowSystem`, `RecordingOverlays` and
`RecordingScheduler` forward every call and callback unchanged and, while `trace on` is in effect, hand each to a
shared `TraceRecorder`, which writes it as a line of JSON. `Controller.perform` records commands and their results, and
the controller writes the header: the world and what it knows of it, so that a trace is self-contained.
`AXWindowSystem` adds the raw notifications and mouse events it receives. While nothing is recorded a decorator costs one
test of a flag per call. `TraceReplayer` (ArborTesting) rebuilds the world from the header, delivers the recorded
stimuli to a real controller and answers its calls from the trace. The format is in `ArborCore/Trace.swift`; the
manual is `docs/TRACES.md`.

## Persistence

`~/Library/Application Support/Arbor/` (or `$ARBOR_HOME`). Only the app and arborctl find that folder by themselves:
every other program that links `ArborPaths` (the tests, arbor-sim, arbor-e2e) uses `arbor-guests-<uid>` in the temporary
directory unless it is given an `ARBOR_HOME`, so that a test run on a Mac where Arbor is in use leaves its log alone:

- `settings.json`: `Settings`, but only what differs from the defaults, and the mark `"format": 2` (`ArborCore/SettingsFileFormat.swift`, Q27): a written
  default cannot be told from a choice, and would keep a changed default from ever arriving. A file from before the mark is stripped once, at a launch, of
  what equals the defaults of its day (a frozen table), with a copy kept beside it;
  unknown keys are ignored, missing keys take defaults. See "Settings" below.
- `state.json`: `PersistedState`: every workspace (tree, camera, history,
  saved views, names, floating frames, the frames docked windows floated at) keyed by display UUID, plus `WindowHint`s
  (bundle id and title) for re-matching windows whose numbers changed, and the
  dormant workspaces of disconnected displays with the date each went away.
  Saved 0.5 s after any change and on quit, atomically, if it differs from what was saved last;
  encoded and written on a queue of its own, in order, and flushed on quit.
- `state.unreadable.json`: a `state.json` Arbor could not use, set aside instead of
  being overwritten (one is kept).
- `state.before-repair.json` (then `.2`, `.3`): a `state.json` Arbor could use only in part, as it was. The file
  itself stays in use and is saved over a moment later; what could not be read, a display's whole arrangement for
  one, is only in the copy. The first is never written over. Whichever of the two it was, `status` says so and names the file
  for the rest of the run, and so does `Controller.notices`, which is what the menu's state lines show.
- `arbor.log`, `arbor.log.1`: the log (`Log.info/error/debug`; set `ARBOR_DEBUG=1`
  for debug lines). At 2 MB the file becomes `arbor.log.1` and a new one is started.
  One message is one line: control characters in quoted text are escaped and
  messages are cut at 1000 characters. A line that cannot be written (full disk) is dropped.
- `arbor.sock`: the control socket.
- `arbor.lock`: locked (`flock`) by the running Arbor and holding its pid. Never deleted.
- `traces/`: what `trace on` recorded (docs/TRACES.md). No titles: tokens stand in for them.

**Privacy.** `state.json` holds window titles, which macOS otherwise shows only to apps
with Accessibility or Screen Recording permission. The folder is 0700, Arbor's umask is
077, and every file is 0600; a folder that belongs to another user is refused and
one open to others is closed (`ArborPaths.secure`). Titles are stored as they are, not
hashed: a hash would hide them from a glance but not from a guess, `arborctl state --titles` hands them
to the same user anyway, and only windows that are open (or remembered for a
disconnected display, for 30 days) are listed. Titles are never logged.

**What is loaded.** `PersistedState.read` checks `version` first: a file from a newer
Arbor is not loaded, because this version would misread it or drop what it does not know at the
next save. Nothing else in it is trusted either: trees and workspaces check and repair
themselves as they are decoded (`LayoutTree+Decoding.swift`, `Workspace.init(from:)`). A tree is rebuilt from
the child lists its root reaches, so links that form a loop, a window listed twice, node numbers that
would be reused and impossible weights are put right and the arrangement is kept; windows that lose
their place float. A camera, history, saved view or guest on a missing node and impossible floating
frames are dropped. Displays and hints are read one by one, and only one that cannot be repaired
(no root, absurdly large or deep) is left out. Every repair is logged. The rest of Arbor relies on the
tree's invariants without checking them, so a new way into a `LayoutTree` must enforce them too.

On start, `Controller.reconcile()` keeps saved windows that still exist and
belong to the same app, re-matches the rest by bundle id and title, and adopts
every other window as floating. A docked window it cannot find keeps its slot for a
while (`Controller+PendingSlots.swift`): for three minutes, to be claimed by a window of the same
app and title (or of the same app, if it has one slot and one window), because at login Arbor
starts long before the apps have restored their windows; or for as long as the window system says its number exists, because a window on
a Space that is not showing is not listed. **So a tree can hold a window number that has no
`WindowSnapshot`** (`controller.windows[id]` is nil, `pendingSlots` contains it), and whatever draws or lists a tree's windows must
skip it; `state` lists them under `waiting`, and `status` counts the ones whose window is not open yet. A slot whose window is on another
Space takes no space, like a minimized window. **After a restart of the Mac, one whose window does not exist yet keeps its room from the
start on** (`Controller+KeptRoom.swift`), so that whoever is restored early goes straight to its final place. `laidOut` is the one place where that
is decided, and whatever lays out an arrangement that is or may be the real one goes through it (`layout(of:)`, `roomyLayout`, a trial of
live reflow): it counts the slot as present and leaves its place open (`Layout.leavingOpen`), so no `Layout` ever names it. Room is kept while
the display's tree has the shape it had at the start (`hasSameShape`), which each layout asks afresh: whatever tries out or makes another
arrangement sees no hole. `treeView` and `presentWindowIDs()` go by who is there; what pairs a tree with a layout's seams asks the layout what it
placed (`seam(on:of:in:layout:)`). Which leaves kept their room is saved (`roomKept` in `state.json`), for a start in the same login.
A window that got a slot by its app alone holds it
provisionally until the wait is over (`provisionalSlots`): what an app shows first is often a welcome window, so a window
with the saved title takes the slot over, and if the holder closes the slot waits again. After `resume` only windows
that still exist keep a slot: what is missing was closed by the user, not by a reboot. Slots wait in the
remembered arrangements of disconnected displays too: the window floats where it appears and returns to its slot
with the display. Whatever is found with no more than a sliver showing (parked by a run
that did not quit cleanly) counts as parked, so the first layout brings back everything the
camera shows, and floating windows nobody remembers are moved to the middle of their display.
**What is found counts as left** (`adopt`, `isToBeFetched`): people park windows three quarters over an edge, so of the windows
of which under half shows, at a start and when one opens, only these are fetched, once: one that nobody could get hold of
(`titleBarIsWithinReach`: no 24 points of its title bar on any display), one in Arbor's own corner, which between two displays
shows a whole title bar next door, and one whose app has a window out of view by Arbor's doing, beside which apps
open the next. Every other stays, and gets the note a person's own hand leaves (`noteWhereItsUserLeftIt`), which is not saved: a
later start writes it again for a window it finds where it remembers it. A layout lets a noted window go on hanging by the same
measure (`reach`), so what stays when it is found is not fitted in later.
The size such a window is found at may be the small one of `shrinkOutOfView`, so it is not taken for the size it has in view
(`noteWindowsLeftParked`).

On quit, `shutdown()` brings every window back into view, including windows that were since minimized, hidden, or
left on another Space: a docked window where it floated before it was docked (see Leaving the arrangement), or, if that
is not known, in its slot with the display laid out at its root without tiles; a floating window where the user left
it, however little of it shows there (`whereItWasLeft`). It gives back what it took and touches nothing else: the sweep it ends with,
whatever `parked` says, is for everything that is still mostly off-screen, but for a window that is known to be where its person left
it or Arbor found it (`isWhereItWasLeft`), which one that was in the hand is too. What merely can be reached may be what a change of displays left.

**Starting Arbor takes no window out of view that is in view** (`collab/QUESTIONS.md`, Q16). A first start moves nothing. A **launch** (a
person starts Arbor, or logs in: `start()` reads the file itself) brings back what was docked, one move per window, and ends **showing
everything**, whatever the view was when Arbor stopped: `PersistedState.showingEverything()` puts every camera at its root, with the old
view one step back, and makes windows that `summon` had sent away ordinary floating windows, on the displays that are not connected
too. The arrangement, saved views, names and what Back led to stay. A window that was never docked is not moved.
**The watchdog's restart** goes on from a second ago: it keeps the view, and nothing moves, because what the view leaves out is still in its
corner. It has one net: `state.json` can be half a second behind, so on a display where the first layout would send away
a window that is in view now, everything shows instead (`showEverythingWhereTheViewWouldTakeAWindowOutOfView`).
What is out of view all the same: what Show Everything itself has out of view, a docked window too large for its place (a tile) and the tabs
behind the one in front. **If the keyboard is in such a tile's window when Arbor starts, and a person sees it, that window is let be where it stands**
(`Controller+LetBe.swift`): sent to the corner it would be typed into unseen, and a view that went to it would take all the others away. It stays docked, its tile
keeps its place, the keyboard stays in it, and nobody else moves for it. It gets no frame, unless nobody knew that it would not fit: apps say how
small they go only when asked, so it is offered its place like any docked window, and put back where it stood when it refuses. `apply`,
`movesInSight` and the stage pass it over; for `isOutOfView`, `bringIntoView`, `frameInView`, the choice of who gets the keyboard and the line round the focused window it is in view.
It ends when a person asks: any `moveCamera`, and a layout within a command, with a gap or an edge in the hand, or for a drop. Then it is a window like any
other, and if it goes into its tile with the keyboard in it, a window in view gets the keyboard, once, after the command has had its own say (`theKeyboardLeavesTheTile`).
Layouts nobody asked for leave it alone: a timer, a putting-back, another window coming or going, a report of the displays, a switch of Spaces. It ends with nothing
moved when it closes, is minimized, hidden, undocked (it floats where it stands) or excluded, and with one move when a layout has room for it after
all. Where its person puts it meanwhile is its own frame from then on. Every start goes by this rule, each for the view it brings up: otherwise a pause
and a resume would bring the old fault back. A window that a crash left in the corner is seen by nobody and is not let be: at a person's launch it
stays behind its tile and a window in view gets the keyboard (`keyboardAfterAStart`).
The end of a pause and the return of the permission are no launches: they run `start()` from `resumeState`, and bring back
the view they interrupted (the permission's return then shows everything if windows were stranded, F63).

**What a start finds counts as left there** (`Controller+FoundAtAStart.swift`; `collab/QUESTIONS.md`: Q16, Q20, Q21 and the product owner's note
of 2026-10-15 on F48): a frame a person gives a window while Arbor is paused, or not running, is its own from then on. For floating windows two rules
come of it.
**A display that is back fetches no floating window that is in view**, whoever ended the last run. Its arrangement used to fetch what had floated on
it; now such a window floats on the display it is on, with its role (kept in view, say), as a guest if the view that comes back there leaves the
Desktop out.
**A floating window that somebody has touched since Arbor let go of it has the frame it is found at for its own.** Where a window is found does not say
who put it there: it may be as Arbor had it, squeezed onto a narrow Desktop. So `shutdown()` writes down where it left each window
(`PersistedState.leftAt`), at a quit and at a pause, and the next start takes that out of the file before it takes the first window; no file written
while Arbor runs has it. Found where it was left, nobody has touched the window, and what is remembered stands, whatever became of the attempt to give it
back (its app did not answer, or did not obey). Found elsewhere, somebody has: a new size is its own; moved only, it keeps its own size to go
back to (`frameToRemember`), which is the one remembered when Arbor stopped, not what an earlier display remembers (`sizesOfFloatingWindows`).
With nothing written (the watchdog's start, the permission's return, a person's launch after a run that did not quit) nobody can tell, and what is
saved stands, as it always did. Only for a window found on another display than the one that remembers it, that display and the place are put
right; the size remembered stands there too, for the file can be half a second behind, and the window in the shape of a slot it knows nothing of.
Neither rule is for a window found in a corner or in full screen, or for one this start itself had to fetch.
What was **docked** is docked again, one move each, on a display that is back as well; what was docked on a display that is missing floats where
it is found, and goes back with that display.

## Ending, and starting again

Arbor parks windows out of view, so every way it can end has to account for them.

| How Arbor ends | What happens to parked windows |
|---|---|
| Quit in the menu, `arborctl quit`, SIGTERM, SIGINT, SIGHUP | `applicationWillTerminate` runs `shutdown()`: all back in view |
| Logout, restart, shutdown | `NSWorkspace.willPowerOffNotification` arrives before apps are asked to quit and save their windows' frames. Arbor pauses for two minutes (`Controller.sessionIsEnding`): all back in view at once. Its own request to quit follows; if some app cancels the logout, the pause ends and Arbor carries on |
| Crash, Swift trap, `kill -9`, Force Quit | Nothing in the process can act. The **watchdog** starts Arbor again within a second; the apps did not restart, so every window has its number and the arrangement and camera come back from `state.json`, and nothing moves. A pause that was on goes on, with its end (`PersistedState.pause`, followed only when the watchdog did the starting) |
| The same, three times within two minutes | The third start is a **rescue** (`ARBOR_RESCUE=1`): `state.json` is set aside, every window is brought into view, Arbor quits and says so |
| Both processes killed (`killall -9 Arbor`), power loss | Recovered at the next launch, which shows everything and so fetches what was left in the corners. After a reboot apps restore windows at the frames they saved, which may be the parked ones; those count as parked too |
| An update replaces the bundle while Arbor runs | The old process keeps running. Quit it first; the new copy refuses to start beside it |
| Accessibility permission revoked | Windows cannot be moved until it is granted again; the event taps are removed at once (`PointerInput`) |
| Sleep, display sleep, fast user switching | Arbor keeps running. Displays that disconnect are handled as below |

The watchdog (`App/Watchdog.swift`) is a second process from the same executable, `Arbor
--watchdog`, that only reads from a pipe. Arbor writes `q` to it as the last thing in a clean quit; if
the pipe closes without one, Arbor is gone, and `RestartPolicy` (headless, tested) decides between
restart, rescue and giving up. A bundled app is started through `open`, so that macOS attributes
the Accessibility permission to the app itself. Force Quit therefore brings Arbor back: use Quit.

`InstanceLock` keeps a second copy out (the installed app plus `make run`): they would move each
other's windows back, overwrite each other's state, and the second would take the socket away from
the first. The second copy explains itself (log, stderr, an alert) and exits with code 75. Copies with
different home folders are allowed; the end-to-end runner relies on that.

`ProcessGuards` also ignores SIGPIPE (the default is to die, when a socket client has hung up), and holds a
`ProcessInfo` activity so that App Nap does not delay Arbor's timers; the Mac can still sleep.

## Displays and Spaces

When a display goes away, its workspace is kept as **dormant** and its windows
float on the main display. When it comes back, the dormant workspace is
restored: windows that are still open and not docked anywhere else return to
their slots (floating ones to their frames), and the others are removed from
the restored tree with `Workspace.forget`, so the camera, history and saved
views move to the nodes that remain. Saved workspaces of displays missing at
launch become dormant too, dormant windows are re-matched like the others on
start, and dormant workspaces older than 30 days are dropped on start
(`Controller+Displays.swift`). Every display change also sends the parked
windows to a corner that is out of view with the displays as they are now.

The Accessibility API lists only the windows on the Spaces that are showing.
After a Space switch `AXWindowSystem` asks every app for its windows again and
marks the known windows it no longer lists as off the active Space
(`WindowSnapshot.isOnActiveSpace`, part of `isPresent`) instead of dropping
them: they keep their place in the tree, take no space, and come back to the
same place when they are listed again. Only a destroyed window or a quitting
app removes a window. A switch arrives as one `windowChanged` per window, so
the controller lays the display out once afterwards rather than after each
(`Controller+Spaces.swift`). Hiding and showing an app is reported the same way and
handled the same way. A focus report runs a layout that was put off first, so
that it is judged by what is really in view. The notification of a Space switch comes in the middle of the
transition, when apps have been seen to list neither the old windows nor the new
ones, so the lists are read at once and again a second later. A window that is off
its app's list and whose element is no longer valid has closed without a
notification, and is dropped.

macOS says that the screen parameters changed at every minimize (the Dock grows), and several times
when a display comes or goes. `DisplayChange.settleTime` decides: nothing changed, nothing is
reported; only visible frames, after 0.3 s; displays, their frames or the primary one, after 1.5 s, and
not at all if by then everything is as it was (a display that blinked on wake). macOS may have cleared the display
meanwhile. Those moves are not taken for the user's, and the controller remembers which windows they were: two seconds after
the last of them, if no report has come and the displays are the ones it knows, it puts back those that macOS has not.

Every frame Arbor remembers is global, and a display's corner moves: whenever another display becomes the main one (a lid
closes or opens) every coordinate changes, displays are rearranged in System Settings, and one that was unplugged comes back
somewhere else. macOS takes the windows along. So what a workspace remembers (`Workspace.shift(by:)`: floating, undocked and
summon frames) and what the controller remembers of its windows go with the display's corner: in `updateDisplays` for a
connected display, by `DormantWorkspace.origin` for one that returns, by `PersistedState.origins` at a launch or a resume.

After a change of displays the corners windows were parked in may be in plain
view, so everything out of view is parked again, and every window's frame is
read again first: when the primary display changes, so do all coordinates, and
apps post nothing. macOS says nothing either when the Dock or the menu bar changes
size or hides, so each layout starts by reading the display's visible frame.

## What counts as a window

Role `AXWindow`, subrole `AXStandardWindow` (`WindowKind` in ArborCore): no sheets,
dialogs, palettes, popovers, Quick Look panels, or the stand-ins macOS lists during a
full-screen transition. One exception: macOS reports every minimized window and
every window of a hidden app as `AXDialog`. Those are taken on unconfirmed (they take
no space anyway), so that they keep the place they were saved with when Arbor starts,
and are looked at again when they show.

A dialog is not arranged, but one that opens out of view because its app centred it over a window
that is out of view is moved to the middle of the display, once (`StrayDialog`, F47).

Only regular apps are observed. An app that becomes regular after launch gets no
launch notification, so an app is also taken on when it first comes forward; that is
the second chance, too, of one that was too slow for the retries (`RetrySchedule`).

**Focus.** Switching apps posts no "focused window changed": the app's focused window
is the one it was. So the focused window is reported when an app comes forward
(`NSWorkspace.didActivateApplicationNotification`), and when the frontmost app's focused or main
window changes. What an app in the background does to its focused window is not
reported: it would move the camera away from what the user is doing.

**Full screen.** Nothing is posted when a window enters or leaves macOS's full-screen mode,
but its size changes, so `AXFullScreen` is read with every resize, and with every reading of the
lists. A full-screen window
(`WindowSnapshot.isFullScreen`, part of `isPresent`) keeps its place in the tree, takes no space
and is never moved: macOS accepts a new size for it and does nothing, which read back as
"refuses to be smaller than the display". During the transition its app lists a stand-in instead of it.

**Native tabs** (Finder, Terminal, Xcode, "Merge All Windows"). Each tab is a window of its
own, but its app lists only the one in front; the others leave the list without a word
and stay alive. To a person the group is one window, so the window in front stands for
it: when a window leaves the list alive while another of the same app joins it in
the same place (`NativeTabs`: the same corner and width; Terminal's tabs differ in height by the tab bar), `windowReplaced` hands over its slot or floating frame and
everything known about it, and the controller forgets the old one. The list is read whenever
a window is created or the app's focused or main window changes; choosing a tab posts
only the last. This is not looked for after a Space switch.

A Space switch also brings an app forward, before or after that rescan. `reportFocus(of:)` leaves out a window it still takes to be on
another Space, and a rescan after a switch ends by reporting the front app's focused window, so the controller hears of the
focus once the window counts as present.

## Go to… (in the code: the finder)

`find` opens a palette that lists every arranged window, saved view and (with F20) named space; `find <text>` goes to the best match without it;
`reveal` brings one window into view (docs/features/F27-window-finder.md).

```
 Controller+Finder ── FinderModel (rows: destination, name, detail, place) ──▶ OverlayPresenter.showFinder
                                                                                 │ FinderPanel / FakeOverlays
        go(to:) ◀── OverlayActions.finderChose(destination) ◀── FinderSession ◀──┘ keys, clicks
```

Everything that decides anything is pure and in ArborCore, so the palette and the tests' stand-in cannot differ: `FinderQuery` (folding, matching,
ranking, the matched ranges), `FinderSelection` (clamping, going round, scrolling), `FinderSession` (the list, the text, the matches, the
selection, the message) and `FinderLayout` (where the palette and its parts go on any display). `FinderPanel` holds a session, draws it and
passes keys on. It is the one panel of Arbor's that takes the keyboard: non-activating, so Arbor never becomes the active app and there is
no focus to restore when it closes.

- The list is a snapshot. The controller checks a choice when it is made; what has gone meanwhile is answered with a fresh model carrying a `notice`.
- **Commands** are a second list of the model (`FinderModel.commands`, Controller+FinderCommands.swift), read from `menuModel()`, searched only once something is typed, and never by `find <text>`. A destination holds a command as
  its text form; `finderChose` reads the menu again, finds the row by that text, and runs its command through `perform(_:from: .shortcut)` unless the menu greys it out by now. Reading and running are about the palette's display
  (`on(_:_:)`, Controller+Lead.swift), not the pointer's. **A new row in the menu needs nothing here.**
- Order: `focusHistory`, with the focused window after the others, then layout order, then saved views. The query's ties keep that order.
- `reveal` asks the window system to unhide and un-minimise, calls `bringIntoView` (tab, camera) at once and focuses. It does not leave the camera to the focus
  report (Controller+Focus.swift), so it does what it says whether or not the window gets the keyboard. macOS confirms those requests late, so for
  this one caller (`onItsWayBack`) `reveal(_:leaf:on:)` picks the view as if the window were present already; the window takes its place when
  `windowChanged` says it is back, and the reports then find nothing left to do.
- The palette opens on the display commands act on (`commandDisplayID()`, F56). The pointer is never moved.
- **It always closes.** The panel closes itself when it loses the keyboard (`resignKey`), on a click or a key that goes to another app, on a click
  on one of Arbor's own panels, when an app comes forward, the Space changes, the screen sleeps. The controller closes it as well, headlessly, whenever it
  learns that the user is elsewhere: a window other than the one it opened over reports the keyboard, a drag begins, the displays change, something is
  gone to, `pause`, `shutdown`. Closing twice does nothing.
- `find` runs through `perform` like any command, so whatever is hooked in there reaches it, but logs for itself: its text is likely to be part of a
  title. `go(to:by:)` logs ids. Whoever else logs a command uses `Command.textForLog`.
Some settings differ from display to display (`displays` in settings.json, F25). `Controller.options(for: displayID)` returns
the settings in effect on a display: the general ones with what the entries that match it give it in their place (key by key, the first that sets a key)
(`Settings.applying(to:)`, matched against the display's name, UUID, size, `isMain` and `isBuiltIn`). **Whatever lays out, previews
or hit-tests a display reads `layoutOptions`, `dropOptions` or `gap` from there**, never from `settings` directly.

## Control protocol

One request per connection on the Unix socket: the client writes one line of
command text (`Command.parse`), the server replies with one line of JSON
(`CommandResult`: `ok`, `message`, optional `state`, optional `text`) and
closes. `arborctl` and `arbor-e2e` are the clients. `docs/SCRIPTING.md` is the guide for script authors.

`watch [events…] [--titles]` is the exception: the connection stays open and the
server writes one line of JSON per event (`ArborEvent`) until either side goes away.

```
 Controller.notify(change) ─▶ EventFeed ── once per turn of the main loop ──▶ Controller.eventSummary()
                                 │                                                   │
                                 │           ArborEvent.changes(from: last summary, to: this one)
                                 ▼                                                   │
        each subscriber's filter and titles ◀───────────── lines of JSON ◀───────────┘
                                 │
                                 ▼
        ControlConnection: OutboundQueue ─▶ non-blocking write ─▶ arborctl watch
```

Events are the difference between two summaries of the state, so duplicates drop out and bursts
coalesce by construction. Clients that did not ask for titles get events worked out from summaries without titles.

**The server never waits.** It runs on the main queue, where Arbor also moves windows, so every socket is
non-blocking from `accept` on (`IPC/ControlServer.swift`). A read source feeds a `LineBuffer` until the request line is
complete; replies and events go through an `OutboundQueue`, and a write source runs only while the socket has refused
bytes. A client is hung up on if it sends no request within 2 s or more than 64 KB, does not collect its reply within
5 s, or, as a watcher, falls 256 KB behind; at most 64 connections and 16 watchers are served at once. A watcher
that closes its end is noticed by the read source. No socket raises SIGPIPE, and the process ignores it.
On quit the feed sends `quitting`, after the windows are back in view, and the server hangs up on everyone.

The framing (`ArborIPC/LineBuffer.swift`, `OutboundQueue.swift`) is pure. The server, the client and `arborctl` need only POSIX
and Dispatch, so they build and are tested on Linux too; `ArborIPC/UnixSocket.swift` is the one file that tells
the platforms apart.

## URLs

`arbor://<words separated by slashes>` reaches the same parser, by a stricter
road, because the sender is unknown: any page or document can open a URL.
`Command.parse(url:)` (ArborCore, `CommandURL.swift`) splits the URL itself rather
than trusting Foundation's `URL`: one word per segment, `%` escapes decoded once, bad
escapes refused, no spaces, slashes, control or direction-changing characters inside
a word, 1024 bytes at most. `Command.isAllowedFromURL` lists the commands a URL may
run (camera and arrangement). **A command that is not listed is refused**, so a new
command is closed to URLs until its author adds it to the list.
`Controller.admit(url:)` applies the list unless the setting `allowAllURLCommands` is
on, and logs every refusal; `ArborApp` only forwards the Apple event and beeps.
Two commands on the list can delete what a person made, saved views and names, depending on the state: `arrange` and `layout`. `admit(url:)` does to copies of
the workspaces what they would do (`Controller+URLCost.swift`) and refuses them where something would be gone.

`layout` is the one command whose URL is not words: everything after `arbor://layout/` is the line, decoded once, and a `/`
in it is the notation's. Only `LayoutNotation` reads it, so a space cannot smuggle in another command.

## Arrangements as text

`layout Safari | Desktop | (Mail / Notes)` (docs/LAYOUTS.md). Four pure steps in ArborCore, then the controller:

1. `Command.parse` cuts the line off before it splits words, because spaces, slashes and quotes mean something in it.
   `LayoutNotation.parse` turns it into a `Spec`: a tree of **slots** (`WindowSlot`: an app's name or bundle id, perhaps part of a title,
   perhaps "all that remain") with sizes. Errors carry a column. The command holds the `Spec`, so a bad line is refused where
   it is written (a shortcut in settings.json, a URL), not when it is used. In JSON a `Spec` is its line.
2. `WindowSlot.assign` hands windows out to slots. It is the only place that decides what a name means (`AppName.rank`) and
   which window a slot gets: windows named by number, then titles, then one window each in the order the candidates come
   (the controller gives most recently focused first, those in view before minimised ones), then the stars. Presets and
   commands that name a window by app are meant to use it too.
3. `Spec.tree(filling:)` builds the `LayoutTree`, closing up slots that found nothing, so the invariants hold whatever was
   found. **Node ids depend only on the text**: each space has the number of its place in the line.
4. `Spec(_:slot:)` and `LayoutTree.notation(names:)` go the other way, for `layout` on its own.

`Controller+LayoutNotation.swift` picks the display (`@2`: the main one is 1, then left to right), takes windows from other displays and
floats what is not mentioned. Applying a line twice changes nothing: a window already under its slot's node id is preferred (`resolve(_:current:)`), and
`Workspace.reset(tree:carrying:)` keeps the saved views and history whose spaces still hold the same windows (`LayoutTree.counterparts(in:)`, by content, because
ids that exist in both trees mean nothing). It is a change of the arrangement, so no floating window goes out of view, and a Desktop the line did not mention is widened until it can be used while windows float on it. With `--open` it asks the `WindowSystem` to open the apps
that have no window and remembers the `Spec` and who got which slot (`pendingLayouts`) for a minute. `windowAppeared` offers each
new window to it before any rule; a window that fits a free slot joins by building the tree again, and because ids are stable
the camera, history and saved views stay valid, so nothing jumps. The wait ends when every slot is filled, when the display's tree is
no longer the one `layout` built (the user moved on), after a minute, and on pause or quit.

## Shortcuts

`KeyBindings.defaults` is the built-in table. The `bindings` object in
`settings.json` maps chord text (parsed by `KeyChord` in ArborCore) to command
text, and `KeyBindings.effective(settings:)` applies it over the defaults,
returning the entries it had to skip and why. `ArborApp` registers the result
with Carbon (`HotKeyCenter`) at start and again whenever
`Controller.apply(settings:)` runs (`onSettingsApplied`), which is how
`reload-settings` picks up edits. `ArborApp` tells the controller which ones
registered (`registeredBindings`); menus, tooltips, the welcome window and `doctor` go
by that, and the `bindings` query prints the effective table.

## The menu bar item, the welcome window and `doctor`

All three show state, so each is a headless model that the app only draws.

- **The item.** `Controller.menuBarModel()` lists the buttons for the display under the pointer (`MenuBarModel`:
  command, glyph, enabled, current, title, shortcut) and `MenuBarLayout` says where each sits in the item's one image
  and what a click at x does. `MenuBarWatcher` observes the controller, rebuilds the model once after each
  command (through the scheduler) and reports it only when it differs. `StatusMenu` draws the image
  (`ArborArtwork`, a template image) and hit-tests clicks against the layout it drew. The `menu-bar` query prints the same
  model, which is how scripts aim real clicks. Without buttons the item is `MenuBarModel.icon`: a glyph, whether it is dimmed, and
  what VoiceOver reads. A state that should show with the menu closed (paused, no permission) is a value of `Icon`, chosen in
  `menuBarModel()`.
  macOS leaves out of a full menu bar what does not fit, without a word. A second after every redraw `MenuBarWatcher` asks the app whether
  the item is showing and tells `MenuBarRoom` (ArborCore), which remembers the narrowest width that was left out; `menuBarModel()` then gives the
  single icon for anything as wide. The answer counts only once it has been "showing" on this Mac, is nil where the menu bar hides itself, and what
  was learnt is forgotten when the settings or the displays change, when the displays wake and when the session becomes active again.
- **The menu** has a section of its own, below.
- **What only macOS knows** reaches the controller as `SystemFacts` (permissions, the Desktop & Dock settings in Arbor's way,
  VoiceOver, input sources, competing apps, the login item, installed event taps), filled in by `ArborApp` each time
  `Controller.systemFacts` is called. Tests make them up.
- **The welcome window.** `OnboardingSession` holds one showing of it: `refresh()` reads the facts again (the window
  asks once a second), the controller's changes tick off `FirstSteps`, `OnboardingFlow` turns the page when the
  permission arrives (unless the welcome names something that would spoil the moves), and `OnboardingModel` words it all: three pages, the welcome, the four moves, and Check Setup…, which alone has every row. `OnboardingWindow` lays the model out in SwiftUI. It is a
  panel that never activates Arbor, so that "the focused window" stays the user's while they try the moves. It opens by itself when
  the permission is missing and once more in a lifetime: after the first start `ArborApp` asks `Controller.pageToWelcomeOn()`, which answers nil
  once `noteWelcomed()` has been called, now or at an earlier launch (`welcomed` in `state.json`). The flag is written only while Arbor runs: before
  `start()` the controller has not read what it saved, and would write an empty arrangement over it.
- **The one step.** `fix-setup` (`Controller+FixSetup.swift`) switches off the Desktop & Dock settings that are in the way, through the seam
  `MacSwitchboard` (`SystemMacSwitchboard`: the `com.apple.WindowManager` defaults, which macOS follows within a second with nothing restarted), after writing
  down how each was stored (`macos-settings-before.json` beside the settings, part of neither them nor the saved arrangement); `fix-setup undo` and
  `Arbor --fix-setup undo` (`make uninstall`) put them back for good. Only when asked, and only while Arbor runs: `shutdown()` (a quit, a pause, the permission
  gone) gives them back and marks the records `givenBack`, `start()` takes them again, each only where the switch still stands as Arbor left it; the order of
  writing is such that wherever Arbor ends, nothing is off that is not written down as owed. An Arbor limited to some processes (`ARBOR_ONLY_PIDS`) has no switchboard,
  so its window shows no such button, unless `ARBOR_MAC_SWITCHES=1`.
- **`doctor`** is `Controller.doctorReport()`: the same facts plus the settings, the shortcuts and the displays. It calls a shortcut
  refused only if macOS refused it when the app asked (`refusedBindings`), and misses a gesture's event tap only if `inputSettings` wants
  it, so a pause, or anything else that makes Arbor hold less than the settings describe, is not a problem.
- **The icon.** `ArborGlyph` (ArborCore) is the mark's geometry. `ArborArtwork` draws it for the menu bar and for Arbor's
  own windows; `scripts/make-icon.swift` repeats it to draw `Arbor.icns` when `scripts/bundle.sh` runs.

### The menu

`docs/MENU.md` decides what is in the menu, in which order and under which titles. `Controller.menuModel()`
(`Controller+Menu.swift`) writes that down as a `MenuModel` (ArborCore): sections of items, each a value with its title, what
choosing it does (a `Command`, one of the few things only the app can do, a submenu, or nothing: a line of words), whether it is greyed out or
ticked, its shortcut and its tooltip. `StatusMenu` turns each value into an `NSMenuItem` when the menu opens and decides nothing, so the
menu is tested on Linux in every state, and the `menu` query prints it (`arborctl menu`, or in arbor-sim).

**To add an item**: find its row in `docs/MENU.md` (ask the product owner for one if it has none), then

1. add one line in the same place in `Controller+Menu.swift`:
   `Item.command("Balance Sizes", .equalize(all: false))`. Chain what else is true of it: `.enabled(…)` when the command would
   fail now, `.ticked(…)` for a switch, `.help("…")` for a tooltip, `.withoutShortcut()`. `Item.text("…")` is a line of words,
   `Item.submenu("…") { … }` the same lines one level down, and `if` and `for` work inside a section;
2. add the line to `MenuTests.theWholeMenu`, which is the whole menu written out and fails until the two agree.

**Into a submenu: the top level is full.** `MenuModel.height` adds up what macOS gives a menu's rows, separators and headings (`MenuModel.Metrics`: what
`NSMenu` answers on macOS 26, which `MenuHeightAppKitTests` asks it on every Mac), as `StatusMenu.fill` puts them together, and `MenuHeightTests` holds it to `MenuModel.tallest`, 600 points, in every state the menu can
open in: a longer menu scrolls on a small display, and its last rows are Pause Arbor and Quit Arbor. `menu` says the height, and
`scripts/mac-shell/check-menu-height.sh` holds it against the window a real Mac makes and clicks each way out where the sizes say it is.

That is all: no AppKit, nothing to compile on a Mac. The shortcut is filled in from the ones registered. `MenuTests` holds every item, whoever
added it, to a few rules: what is not greyed out does not fail when chosen (in five states of the arrangement); rows are greyed out, not left
out; the ways back are never greyed out; titles use no word the glossary rules out; every command has a text form. **`MenuChaosTests`** asks the
first of these in states nobody wrote: on the chaos lab's random walks it chooses a row every third step, as the menu would run it, and fails if one that was
offered fails or one that was greyed out would have worked. When it names your row, let `.enabled(…)` ask what the command itself goes by. A rule about all
items at once (grey out what may not run while the view is held, say) is one `mapItems` at the end of `menuModel()`. Something only the
app can do is a new case of `MenuModel.AppAction` and a line in `ArborApp.carryOut(_:)`; prefer a command.

`HotKeyCenter` reports each shortcut's key going down **and** coming up, and decides nothing. Both go to
`Controller.shortcut(_:_:run:)`, which runs the binding's command on the press, unless a peek takes the key.

A letter, digit or sign in a chord means the key that types it. `KeyLayout` (ArborCore) holds what each key of a layout types
and answers with a key code and a label; a `KeyBinding` carries both for the layout it was made for, so whatever
shows `binding.label` is right. `KeyboardLayoutWatcher` reads the layout macOS has selected (the ASCII-capable one, as
⌘-shortcuts do) and reports it at launch and on every change (`Controller.keyboardLayoutChanged`). Ask the controller
(`effectiveBindings`, `activeBindings`), not `KeyBindings.effective(settings:)`, which without a layout assumes a US keyboard.

What is registered at a given moment is `Controller.activeBindings`: the effective table, cut down to the
shortcuts that end a pause while paused (`KeyBindings.whilePaused`), or to `toggle-pause` and `pass-through`
while an app on `passThroughApps` is frontmost (`whilePassingThrough`), and the `summon` of that app while its window is summoned. `Controller.inputSettings` does the
same for the pointer taps, and leaves them nothing for as long as `pointerGestures` is off: the taps, `doctor`, the panel of shortcuts and the zones of the Desktop all go by it, so that one switch takes every tap out. `FrontmostAppWatcher` reports every app that comes to the front
(`applicationActivated`), also during a pause, when `AXWindowSystem` is not observing; the controller
compares, and tells the app with `Change.input` only when the answer differs, so switching between two
ordinary apps registers nothing. A new tap or key source follows these two properties and that change, and needs no
knowledge of pauses or lists (`Controller+PassThrough.swift`).

macOS registers a shortcut that it uses itself without a word, and then one of the two does nothing. `SystemShortcutReader` reads macOS's own
(`CopySymbolicHotKeys`: key code, Carbon modifiers, ticked or not; and how many input sources there are) each time it is asked, `SystemShortcuts`
(ArborCore) decides which of them is a use of a given key and what it is called, and `Controller.systemShortcutClashes` holds that against `effectiveBindings`, by
key code, so on any layout. `bindings` lists them, asking anew each time; the log has them once, and asks again only when the shortcuts in effect change.

## Permission

Accessibility can be taken away while Arbor runs, and then nothing can be moved, not even back into view. From the first `start()` on the controller
asks `accessibilityProbe` (set by the app: `EventTap.isPermitted()`) through the scheduler every 2 s, before every command that is not a
query (within a second of a thorough yes only `AXIsProcessTrusted()`: commands can come tens to the second), when the taps' watchdog or a refused call (`accessibilityWasRefused()`) raises a doubt, and every second while the permission is missing. `PermissionWatch` (ArborCore) turns the
answers into "lost" and "returned". Lost is `shutdown(movingWindows: false)`: saved, stopped, nothing touched; `permissionLoss` says what was out of view. Returned is
`start()`, then `home` if anything was. `activeBindings`, `inputSettings` and `statusText` know about it, so the app only follows `.lifecycle`: for the taps while `isInBusiness`, for the shortcuts from before its menu bar item is made until it quits, since Arbor keeps its keys wherever nobody gave them away
(`Controller+Permission.swift`, `docs/features/F63-permission-taken-away.md`).

## Peek

Holding the shortcut bound to `show-all` peeks (docs/features/F51-peek.md). `Peek` (ArborCore) is the whole decision as a value:
tap or hold, what the pointer, the arrow keys, ⎋, a click, another command and a closing window do, and how it ends (`stay`,
`land`, `goBack`). `Controller+Peek.swift` feeds it and does what it answers.

- While the keys are down a timer (`scheduler`, 30 times a second) reads the pointer, the mouse button and `WindowSystem.isHolding(chord)`.
  So the pointer needs no event monitor, ⌃ or ⌥ going up first ends the hold, and a release that Carbon never reports cannot leave
  Show Everything springing back: when in doubt a peek ends as a tap.
- The clock starts after everything has been laid out, so a tap whose release waited in the queue behind slow windows is still a tap.
  A hold of under a second (`Peek.slowTap`) in which the pointer did not move and no arrow was pressed is a tap too.
- The move to everything is **not recorded**, and the workspace knows that the view is only visiting (`Workspace.beginLook`, `lookingFrom`): until it
  returns, Back and Forward are tidied against the place it came from, that place follows what closes meanwhile like any other, and its group is kept whole
  as the view's is. So a day ends the same with a peek and without one (`theSameDayWithAndWithoutALook`); only when nothing is left of the view that was left does the
  peek stay on everything. Whatever ends the peek puts the camera back (`returnFromALook`), without laying anything out, and then
  makes one ordinary move: one history entry, or none. A peek that nobody ends (a pause, a display unplugged, a crash or a quit with the keys down) becomes a stay (`stayAfterALook`). `moveCamera` calls `peekYields(on:)` first, so a camera moved by anything
  else (a clicked tile, a window that took the keyboard) counts as the landing. `perform(_:from:)` interrupts a peek before any command that is not a query.
- The arrow keys and ⎋ arrive with the held modifiers, as ⌃⌥← and so on, which are bound by default; a peek takes those chords by their keys,
  whatever they are bound to. Chords that are bound to nothing are registered for the length of the hold
  (`KeyBindings.whilePeeking`, `onTemporaryShortcuts`, `HotKeyCenter.setTemporary`) without touching the others: unregistering a shortcut whose key is down would lose its release.
- The outline is `OverlayScene.peekOutline`. Its panel takes the click meant for what it outlines and reports it (`OverlayActions.peekOutlineClicked`): with
  ⌃⌥ held, the app underneath would open a contextual menu and macOS would hide the app that had the keyboard. The timer watches the button
  too, for a click on a space the arrows have moved the outline away from.

## Where a command came from

A camera command names no display and `in` names no window. `ArborApp.handle(_:from:)` passes the command's
`CommandSource` (shortcut, menu, gesture, script, url) to `Controller.perform(_:from:)`, which keeps it for as long as the
command runs; plain `perform(_:)` counts as a script. `cameraDisplay()` is the one place that picks a
display. It asks `InputLead` (ArborCore, pure) whether the pointer or the keyboard leads:

- gestures and the menu: the pointer;
- shortcuts, scripts and URLs: the setting `stepInToward`, and with `auto` the pointer if it has been used since the last key
  was released and since the focus last changed, otherwise the keyboard. Commands that follow each other with nothing
  typed in between stay with the first one's answer, so ⌃⌥↓ ⌃⌥↓ does not change displays halfway.

Only a command's answer is remembered. Whoever shows which display a command would act on (a menu, a caption, a list of
rows, a query) asks `Controller.displayForCommands(from:)`. Code inside ArborKit may also call `commandDisplayID()` or
`cameraDisplay()` outside a command: the answer is the same and nothing changes, so the next shortcut follows what it
would have followed unasked, and a trace need not hold the question.

With the keyboard in the lead the display is the focused window's, also when Arbor does not arrange that window (a call in an
app set to Don't Arrange), and `in` steps toward that window if Arbor arranges it. With no focused window the pointer decides after all.

Arbor sees no typing and must not: `WindowSystem.inputActivity()` reads three figures that macOS keeps for every login
session and gives to any app (`CGEventSource.secondsSinceLastEventType` and `counterForEventType`): how long the pointer has
been still, how long since a key was **released**, and a count of key presses. While a shortcut's command runs its own key is
still down, so the last release is the last thing typed; the count tells "nothing but shortcuts since" from typing.

## Versions, updates and the login item

Nothing about the version is generated when Arbor compiles, so the headless build needs no Git.
`scripts/bundle.sh` stamps the bundle's Info.plist (`scripts/version.sh`: the `VERSION` file, the number of
commits, the commit), and `BuildInfo` (ArborCore) reads it back: the app from `Bundle.main` into
`Controller.buildInfo`, `arborctl --version` from the bundle it sits in. Outside a bundle the version is `dev`.

`check-for-updates` is the only thing in Arbor that uses the network. The asking sits behind the seam
`ReleaseFeed` (`GitHubReleaseFeed`: one GET to GitHub's releases API; `FakeReleaseFeed` in tests). Everything else is
pure and in the core: `ReleaseLookup` reads the answer (404 is "nothing published", not a failure),
`SemanticVersion` orders versions, `UpdateCheck.decide` turns both into an `UpdateDecision` with the words to show,
and builds the release page's address from the tag only after the tag has parsed as a version.
`Controller+Updates.swift` keeps one check in flight, gives up on a feed that does not answer, and runs the
automatic checks (`automaticUpdateChecks`) by the clock rather than by one long delay, which would stand still while
the Mac sleeps; a pause holds them. Only a check somebody asked for shows its answer: `UpdateWindow` says the decision
in macOS's own alert, shown and not run, because an alert's modal loop would keep Arbor from hearing about other apps' windows. What an
automatic check found changes the menu item's title (`updateMenuTitle`) and nothing else. Arbor never downloads or
installs anything.

`launch-at-login` goes through the seam `LoginItem` (`SystemLoginItem`: `SMAppService.mainApp`). The binary also takes
`--launch-at-login [on|off]` and `--version` from a shell, without becoming the app (`LaunchArguments`), which is
how `make uninstall` removes the login item whether or not Arbor is running.

How builds are signed, installed and released: `docs/INSTALL.md`.

## Settings

`SettingsSchema` (ArborCore) describes every key of `Settings` once: section, label, help, kind (switch, number
with range, step and unit, choice, checked text, or a list with commands of its own) and type-erased access.
Everything else is a view of it:

- **Commands** (`SettingsCommand`, `Controller+Settings.swift`): `set`, `get`, `settings`, `reset`, and for the lists
  `bind`, `unbind`, `rule …` (and the older `exclude`, `include`). Keys and values are checked when the text is parsed.
- **Changing** (`Controller+Settings.swift`, "Applying and saving"): the settings in use are what settings.json says,
  always. So every command that changes settings first asks `refusalToChangeSettings()`, which takes in the file as it
  is now and refuses while it cannot be read; works out the new settings; and returns
  `reply("…", unsaved: change(settings: updated))`, which saves, then applies. A change that cannot be saved (a
  read-only file) is refused as a whole.
- **Saving**: people edit the file by hand, so `saveSettings` → `SettingsFile.update` → `Settings.rewrite` is a three-way
  merge: what changed between the settings in use and the new ones is written into the file's text (`JSONText`), and
  every other byte stays, including unknown keys and the values and entries Arbor could not use. What is added is laid
  out like what is there. Arbor never writes to a file it cannot read; only `reset everything` replaces one
  (`SettingsFile.replace`), keeping the old one as settings.unreadable.json.
- **Decoding**: `Settings.init(from:)` keeps the default for a value of the wrong type and then runs
  `SettingsSchema.sanitize`, which moves numbers into their ranges. What it changed is in `valueProblems` (logged,
  and shown by `settings`), as `skippedRules` and `unreadableBindings` are for the lists. This is the only place
  values are checked, so code that uses a setting can trust its range.
- **The file**: `SettingsWatcher` (macOS only) reports that settings.json or its folder changed;
  `Controller.settingsFileMayHaveChanged()` waits for 0.3 s of quiet and `takeInSettingsFile()` reads the file and
  applies it only if it differs from the settings in use, which is also how Arbor's own writes are ignored. A
  file that is not a JSON object keeps the settings in use, is logged once with the line and column of the typo
  (`Settings.read`, in the same words on macOS and Linux), and blocks changes (`settingsFileProblem`) until it is
  mended or replaced. A file that is missing or blank for a moment, as some editors leave it, changes nothing.
- **docs/SETTINGS.md** is `SettingsSchema.markdown()`; a test keeps it so. Another fails for a key without an entry.
- **Levels**: an entry is `normal`, `advanced` (behind "Advanced" in the window) or `hidden` (not in the window). The level
  decides only that: every key works in `set`, `get`, `reset` and the file, and is listed by `settings` and the document.
- **The window** (`settings-window [pane]`, ⌃⌥,): `SettingsPanelModel` (Controller folder, headless, tested) decides
  everything: the panes (`SettingsPane`, in the core so that a pane's name is checked like any command), the rows of
  a section and their controls by the entry's kind, what a search finds, what Restore Defaults restores, the table of
  shortcuts, recording and clashes, the rules' lines. A list of apps (`.apps(…)`; `set <list> add` and `remove` change it) is a kind of row like the others. It changes nothing itself: each change is a command run through the closure the menu uses
  (`ArborApp.handle`), a refusal is kept by the place it was made at and shown there, and what is shown is read back from
  the controller's settings, which the model observes. So a new setting needs no code in the window.
  `UI/SettingsWindow.swift` opens the window and hands key presses to the model while it records (`isRecordingShortcut` empties
  `activeBindings` meanwhile); `SettingsViews.swift` and `SettingsListViews.swift` have one small SwiftUI view per kind of row.

## Launch options

| Variable | Effect |
|---|---|
| `ARBOR_HOME` | Folder for settings, state, log, traces and socket |
| `ARBOR_SOCKET` | Socket path (default `$ARBOR_HOME/arbor.sock`) |
| `ARBOR_ONLY_PIDS=1,2` | Arrange only these processes' windows (tests) |
| `ARBOR_NO_HOTKEYS=1` | Do not register global shortcuts or install the pinch and rectangle event taps |
| `ARBOR_NO_STATUS_ITEM=1` | No menu bar item |
| `ARBOR_NO_PROMPT=1` | Do not open the welcome window at launch when Accessibility permission is missing, and show no alert |
| `ARBOR_DEBUG=1` | Debug logging |
| `ARBOR_NO_WATCHDOG=1` | Do not start Arbor again when it ends without quitting (debuggers, scripts that kill it) |
| `ARBOR_RESCUE=1` | Set `state.json` aside, bring every window into view, and quit |
| `ARBOR_RESTARTS` | Set by the watchdog: when Arbor was started again, for `RestartPolicy` |
| `ARBOR_APPEARANCE=dark` | Draw Arbor's own windows, panels and menu dark (or `light`) whatever the system's appearance (pictures) |
| `ARBOR_KEYBOARD_LAYOUT=com.apple.keylayout.German` | Go by that installed keyboard layout instead of the one selected (tests) |
| `ARBOR_NO_PICTURES=1` | Take no pictures of windows, as without Screen Recording permission |
| `ARBOR_NO_OPENING=1` | Open no app: `summon` with no window to bring answers as if there were no such app |
| `ARBOR_NO_REHEARSAL=1` | Get nothing ready for the first motion ahead of time (`first-dock.sh` measures what that saves) |
| `ARBOR_RELEASES_URL=http://…` | Ask there instead of GitHub's releases API (tests of the real app) |
| `ARBOR_BUILD=abc1234` | Which commit this build is, for the header of traces |

The `ARBOR_NO_…` switches and `ARBOR_RESCUE` count an empty value, `0`, `false` and `no` as
off; `ARBOR_DEBUG` an empty value and `0`.

The scripts read a few variables of their own:

| Variable | Read by | Effect |
|---|---|---|
| `ARBOR_SIGN_IDENTITY`, `ARBOR_SIGN_KEYCHAIN` | `scripts/sign.sh` (`make app`) | Code-signing identity, and the keychain to look in; see its header and `docs/INSTALL.md` |
| `PREFIX`, `BINDIR`, `LAUNCH` | `scripts/install.sh` (`make install`, `make uninstall`) | Where Arbor.app and `arborctl` go, and whether to start Arbor |
| `ARBOR_UNATTENDED` | `scripts/install.sh`, `make run`, `scripts/make-signing-identity.sh` | `1`: go ahead although standard input is no terminal; otherwise they decline (77) |
| `ARBOR_VERSION` | `scripts/version.sh` | Replaces the `VERSION` file for one build |
| `ARBOR_CONFIGURATION` | `scripts/bundle.sh` (`make app`, `make install`) | `debug` compiles without the optimizer; `release` when unset |
| `ARBOR_CONFIGURATION` | `scripts/mac-shell/lib.sh` (`arbor_build`), `scripts/mac-shell/run.sh` | `release`: the script drives the release build (`run.sh --release`); `debug` when unset |
| `ARBOR_NOTARY_PROFILE` | `scripts/release.sh` (`make release`) | Notarize with this keychain profile |
| `ARBOR_DOCKER_ARGS` | `scripts/linux.sh` (`make linux`) | More arguments for `docker run`, e.g. `--network host` |
| `VERBOSE=1` | `scripts/scenarios.sh` (`make scenarios`) | Print arbor-sim's whole output |
| `ARBOR_SETTLE`, `ARBOR_TEST_WINDOWS_ARGS`, `ARBOR_EXTRA_PIDS` | `scripts/mac-shell/lib.sh` | See its header, and section 5 of `docs/TESTING.md` |
| `MAC_SHELL_TIMEOUT`, `MAC_SHELL_TAIL`, `MAC_SHELL_TAG` | `scripts/mac-shell/run.sh` | See its header |
