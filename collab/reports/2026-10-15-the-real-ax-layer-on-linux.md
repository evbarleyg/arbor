# Report: the real Accessibility layer, run on Linux on a model of a rude Mac

- Date: 2026-10-15
- Branch: test/the-real-ax-layer-on-linux, then test/mac-on-linux-round-2 and -round-3
- What: `make mac-on-linux` (scripts/mac-on-linux/README.md; docs/TESTING.md, section 9)

`Sources/ArborKit/AX` ran in no headless test. Now it is compiled as it is, linked with a model of a Mac and run on Linux: 1,051 stories (3,221 ✔, 334 ✘ known, at the end of round 3, with the short window's cure and the new order of the calls in; 181 stories at the end of round 1, 279 at the end of round 2; round 3 adds 126; some 640 are other hands', on late presses and the Desktop shown) and a random walk under four kinds of bad manners, at both storeys, five seconds to run. The run enters 92 % of the lines and 81 % of
the regions of `AXWindowSystem.swift` (`COVERAGE=1`, at the end of round 2). Thirty-five changes that take known cures out of a copy of the layer all turn their stories red (`make mac-on-linux-selftest`).

This report is what it found. Nothing in the layer was changed. Each finding says what a person would see, the lines concerned, and how sure the model is of the manners that bring it out: SEEN on a Mac, or GUESS. Every red check is listed in
`scripts/mac-on-linux/known-failures.txt`; whoever cures one deletes its lines. Line numbers are those of `Sources/ArborKit/AX/AXWindowSystem.swift` at f0d67cc, the trunk when the work began; two cures have landed in the file since (5726225, 37d0f05), and what comes after line 470 is some
forty lines further down now. **The findings of round 2 (N9 to N15, the additions to L1) give the lines of the file at 37d0f05**, which is how it stood on the trunk at dd0e8da; four commits have touched the file since (12d1835, a3c0281, 531885f, c0d13b9), and what comes after line 1140 is some forty lines further down.

| | What a person sees | Needs | How sure |
|---|---|---|---|
| R1 | (cured) a window opened in a running app is filed as open all along | focus reported before creation | seen; red again without the cure |
| R2 | (cured by 5726225 while this was written; red again without it; still red at 600 ms) ⌘Tab or a click to another app: the view does not follow | `frontmostApplication` lags the notice | seen |
| N1 | a docked window closes, its slot stays empty, whatever one does | "destroyed" never comes | seen that it can happen; how often unknown |
| N2 | the same for an app that ends without a word, until some layout moves its window | an end nobody reports | seen |
| N3 | two windows of one app in the same place on two Spaces become one | the focus report beats the Space notice | guess as to the order |
| N4 | Arbor pulls at a docked window on its way into full screen | `AXFullScreen` says yes late | lateness seen; what the pull does unknown |
| N5 | **an app that is busy as it is switched to never gets the view; each ⌘Tab to it costs a second** | **nothing: a polite Mac** | the layer's own logic |
| N6 | ⌘T in a docked window makes a second window of it; closing the front tab loses the group | the app's list 10 ms behind | lists lag: seen; at that moment: guess |
| N7 | an app opens a window and gets busy: Arbor is dead for four seconds | three notifications on their way | the layer's own logic |
| N8 | two rare races | | for the record |
| N9 | **Arbor starts or resumes while an app hangs: 4 to 9 s of standing still; after a hang of a minute the app's windows are never Arbor's** | nothing: a polite Mac | the layer's own logic |
| N10 | a window that its app had put away before Arbor started is filed as open all along when it is shown again | focus reported before creation | both halves seen, never together |
| N11 | an app moves its window and gets busy: Arbor goes on believing the old place | a hang within 2 to 15 ms of the move | the layer's own logic |
| N12 | **Arbor is quit while an app with windows out of view hangs: they stay out of view for good** | nothing: a polite Mac | seen on a hosted Mac |
| ~~N13~~ | ~~a window goes out of view seconds AFTER Arbor is gone~~ **STRUCK: the model's own fault, refuted by a hosted Mac** (below). What is left of it: at a PAUSE, and a guess | a hang in the middle of a move out of view, a quit meanwhile | WRONG |
| N14 | Arbor's request for the keyboard, held up by a slow app, takes the keyboard away from where the person has gone meanwhile | an app busy for less than the timeout | the layer's own logic |
| N15 | a command answers after 3.3 s because one app is slow | an app that takes 0.1 s over a call | the layer's own logic; slow answers seen |
| N16 | a floating window comes back from out of view moved and shrunk; Arbor's own moves count as the person's | an app that carries out a moment late what it says yes to | seen of Safari leaving full screen; in general a guess |
| N17 | **Arbor is paused while a park waits in the queue of an app that hangs: the window goes out of view when the app wakes, and stays there until `resume`** | a hang between the layer's question and its move; a pause during the hang | the controller's own logic; that a park is carried out on waking with Arbor alive is seen |
| N18 | `float-all`, `float` or `undo` while an app hangs: its windows keep the shape of their slots for good | a hang; a polite Mac | the controller's own logic |
| N19 | **one command for a floating window of the app in front, and the keyboard ends with another app's window** | nothing: a polite Mac | the controller's and the layer's own logic; that `frontmostApplication` names the old app right after `activate()` is seen |
| U1 | **a window dropped where there is no room for it goes out of view, as a tile, and what is typed goes into it** | nothing: a polite Mac, 1024 points, three windows | the controller's; the stand-ins show the same; no net asks |
| U2 | (cured since a floating window's frame is its person's) a window that opened over a docked one jumps, and shrinks, when something else happens | nothing: a polite Mac | the controller's; known to the chaos lab (`moved-unasked`, severity 2) |
| U3 | the view goes to an empty Desktop, and what is typed goes into a window out of view | nothing: `arrange`, `desktop` | the controller's; the stand-ins show the same; no net asks |
| U4 | ⌘Tab to a hidden app whose windows are on another Space: its window has the keyboard and stays out of view | the focus reported before the Space's notice | guess as to the order |
| L1 | **a drag of any length is not seen at all; nothing is logged** | the window server a moment late, the pointer more than 24 points away | found on a guess; **since SEEN on a hosted Mac**: three of four drags of 1,244 to 1,991 points in 30 steps never taken for drags, nothing logged. **CURED by a3c0281**, which was held against the stories twice before it was published: 61 listed lines deleted, 2 listed anew (what its author names as left), red again with the cure taken out |
| L2 | a flick is not seen | the gesture over before Arbor hears of the press | the layer's own logic |
| L3 | **(new with 37d0f05) a drag of a second is not seen** | the press heard half a second late | the layer's own logic; a regression. **531885f meant to cure it, did not, and lost two drags more (L4); its lines are out again** (L4) |
| L4 | **(came with 531885f, gone again the same night: its five lines were taken out) a drag of a second is not seen** | Arbor's main thread busy for 0.3 s from the press | the layer's own logic; a regression; shown by two changes, one at a time |

## Reproductions of what was already known

### R1. Fault (a), cured on the trunk: reproduces when the cure is taken out
Story "a window opens in a running app that reports the focus before the creation". Green on the trunk. With `hasOpenedSince` forced to false in the copy
(`make mac-on-linux-selftest`) the layer reports `found w102, focused w102` instead of `appeared w102, focused w102`: exactly the fault seen on the hosted Macs.

### R2. Fault (c): reproduced at both storeys while it was open; cured by 5726225; red again without the cure; still red at 600 ms
Stories "⌘Tab to another app, and NSWorkspace names the old app for 5 / 50 ms more", "a click on another window of another app, …", "⌘Tab to an app whose window is
out of view, …". With a fresh `frontmostApplication` all green. Stale: the layer reports only `keyboard moved, keyboard moved`, never `focused`; at storey two the
window with the keyboard stays parked at 1023,673 (the very place seen on the hosted Mac) for the three seconds the story waits.
- Lines: 937 (`guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }`), reached from 475 (`appCameForward`) and 1075.
- NEW DETAIL 1: it is red at a lag of 5 ms too, where the property HAS caught up by the time `AXApplicationActivated` arrives (8 ms after the notice): line 1078 only
  says `keyboardFocusMoved()`, and the controller, which then asks `focusedWindow()` and gets the right answer, does not move the view on that. So a cure cannot
  lean on the controller's handling of `keyboardFocusMoved`; `AXApplicationActivated` has to lead to `reportFocus`, or the notice's own pid has to be believed.
- NEW DETAIL 2: a CLICK on another window of the other app is lost as well, not only ⌘Tab: `AXFocusedWindowChanged` and `AXMainWindowChanged` arrive about 2 ms after the
  press, BEFORE didActivate, when even a well-behaved NSWorkspace still names the old app, so both are dropped at 937; with a fresh property didActivate makes up
  for it, with a stale one nothing does. (Order of the AX reports against didActivate: GUESS from the traces' delays; `drag-onto-window` has the focus report 0.4 ms
  before the mouse-down.)
- A cure that waits for the property should know that nobody has measured how long it lags; the stories hold it to 5 ms and to 50 ms.

## New findings

### N1. A window that closes without "destroyed" stays a ghost, and not even a failed move clears it
WHAT A PERSON SEES: a docked window is closed; its slot stays empty and its neighbour does not get the room. Going on working (click, `show-all`, `zoom`, `show-all`) does not
help. It lasts until the same app opens a window or changes its focused window, or the Space changes.
STORIES: "a window closes and the notification never comes", "the last window of an app closes and the notification never comes" (storey one), "a docked window closes and the
notification never comes" (storey two).
WHY:
- An app's list is read only in `handle` for created / focused / main changed / deminiaturized / shown (1035, 1044, 1066, 1074, 1091), `answersAgain` (531) and a Space switch (576, 585).
  The focus report of a closing window comes 12 ms BEFORE the window goes (trace `close`; a `setFrame` in between still succeeds), so the one rescan it causes still finds the window listed and valid.
- `appCameForward` (469-476) reads the focused window, never the list: leaving the app and coming back changes nothing.
- `setFrame` (222-264): `perform` treats only `cannotComplete` and `apiDisabled` as special (271-275). A closed window answers `invalidUIElement` to both setters, `element.frame` is nil, `gaveUp` → `noteSilence`
  finds that no time passed and the process is alive (495-504) and returns. nil, for ever: "nothing is known", where in fact the app has said plainly that the window is gone.
HOW SURE: that a window can close without the notification is written down as seen (docs/ARCHITECTURE.md "has closed without a notification, and is dropped"; AXWindowSystem.swift 636-639); how often nobody knows. The 12 ms are from a trace.
What a closed window's element answers to a SET (`invalidUIElement`) is the documented behaviour, not measured here.
A CHEAP CURE TO CONSIDER: in `perform`, `invalidUIElement` → `drop(window)` (deferred, as 498 does); and a `rescan([pid])` in `appCameForward`.

### N2. The window of an app that ends without a word stays until some later layout happens to move it
WHAT A PERSON SEES: two docked windows; the process behind one (started from a shell) ends. The window vanishes from the screen, its slot stays empty, the other window keeps its half. Five seconds later: the same.
STORY: "an app with a docked window ends and nothing says so" (storey two). At storey one ("an app ends and nothing says so") the cure works as designed: the first call fails at once, `kill(pid, 0)` says ESRCH, the window is reported gone.
WHY: `noteSilence` (494-505) is reached only from a call, and after the end nothing calls: the app that comes forward instead is reported focused, which needs no layout. HOW SURE: the silence is written down as seen
(docs/ARCHITECTURE.md:837; ledger "an-app-can-end-without-a-word").
TO CONSIDER: when an app comes forward because another has gone, or at `didActivate` in general, `kill(pid, 0)` for the observed pids costs nothing and talks to nobody.

### N3. Two windows of one app that fill the same place on two Spaces are taken for native tabs, if the focus report beats the Space notice
WHAT A PERSON SEES: two browser windows, each filling the view on its own macOS Space (with Arbor that is the normal case: same slot, same frame). Switch Space: Arbor reports `replaced w102 by w101`. The controller hands the first
window's slot and everything it knows about it to the second and forgets the first. On the way back the same in reverse. Both windows now share one place in one tree; whatever differed between the two Spaces' arrangements is gone.
STORY: "two windows of one app fill the same place on two Spaces, and the Space is switched, the focus reported before the notice". With the notice first: green.
WHY: 1070-1075: "focused window changed" → `rescan([pid], afterSpaceSwitch: false)`; the comment at 595-598 knows the danger ("two that fill the same slot on different Spaces would be taken for tabs") and excludes it only for rescans that
KNOW they follow a switch. HOW SURE: GUESS as to the order. The backlog says it is not known in which order the reports of a switch arrive (M1096). The notice is known to come "in the middle of the transition", and an app's key window
changes when its Space comes up, so the focus report has every chance to be first. That the app already lists the new Space's window at that moment is the polite case; if it lists nothing, no harm is done.
TO CONSIDER: `isOnScreen` of the window that left the list does not help (it is off screen either way). The window server could: a background tab and a window on another Space differ in `kCGWindowWorkspace`-like facts only privately; cheaper is to
hold `windowReplaced` back for a moment when the successor was already `counted` (it existed before), and drop it if a Space notice arrives.
WORTH A RUN ON A HOSTED MAC: record a trace of a Space switch between two windows of one app (traces/README.md lists Spaces under "still to record").

### N4. Arbor pulls a docked window back into its slot in the middle of its way into full screen, if `AXFullScreen` says yes late
WHAT A PERSON SEES (model): green button on a docked window; 0.25 s into the animation Arbor sets size, position, size on it (three calls), because the "resized" reports say a docked window has left its slot and `AXFullScreen` still says no.
In the model the transition then ends as it should. What a real transition does when it is pulled at nobody knows.
STORY: "a docked window enters full screen and leaves it, saying so late" (storey two). Saying so in time: green.
WHY: `geometryChanged` (969-992) reads `AXFullScreen` with every resize, gets "no", reports `windowChanged(userInitiated: true)`; the controller enforces the slot. HOW SURE: the lateness is written down as seen (663-664: "the resize reports can arrive
before the window says it is in full screen"). How late, and whether the window takes a frame meanwhile: GUESS.

### N5. An app that is busy as it is switched to is never reported focused, also after it wakes; and each ⌘Tab to it costs the main thread a second   (FOUND BY THE WALK, ON A POLITE MAC)
WHAT A PERSON SEES: ⌘Tab (or the app in front quits) to an app that beachballs for two seconds and whose window is out of view. The window stays at 1023,673 with the keyboard in it, for good. Meanwhile Arbor is deaf for a second; switch away and back three times: three seconds.
STORIES: "⌘Tab to an app that hangs, and wakes two seconds later", "⌘Tab three times to an app that hangs" (3.0 s), "⌘Tab to an app whose window is out of view and which hangs for two seconds" (storey two). Walk: 17 of 300 polite seeds; shortest `arborFocuses 96 4; hang 85 52; dies 24 10`.
WHY: `reportFocus(of:)` 938: `app.element.element(kAXFocusedWindowAttribute)` waits out the 1 s and gives nil like "no focused window" → `keyboardLeftTheKnownWindows()`. No `noteSilence`: the app is not marked, no task asks whether it is back, the next activation waits again.
If the app WAS marked (by an earlier call), `answers(pid)` is false at 938 and the report is dropped at once; `answersAgain` (527-532) refreshes windows and rescans and reports no focus; and `AXApplicationActivated`, which the app posts on waking, leads only to `keyboardFocusMoved()` (1078).
The variant "wakes, and is clicked within the half second (1.5 s on a Mac) before Arbor has asked again" is lost the same way (walk, polite seed 111).
HOW SURE: everything here is the layer's own logic on a polite Mac; the only assumption is that a hung app lets `AXFocusedWindow` time out, which is what hanging means. Not covered by the cure proposed for (c) (below): the same with and without it.
TO CONSIDER: read with `read(_:)`, `noteSilence` on `.cannotComplete`; end `answersAgain` with `reportFocus(of: pid)`.

### N6. Native tabs go wrong in two ways if the app's list of windows is behind by as little as 10 ms   (FOUND BY THE WALK, stale answers: 44 of 150 seeds)
WHAT A PERSON SEES: (1) ⌘T in a docked window: the new tab is announced as a NEW WINDOW (`appeared w102`): it floats, or is docked somewhere else; the old window keeps its slot as a window "on another Space", so the slot collapses. Arbor now has two windows for one. (2) The tab in front is closed:
the whole group is reported gone (`destroyed w102`), and the tab that now shows is unknown to Arbor until the app's focus next changes.
STORIES: "native tabs of an app whose list of windows is 10 / 50 ms behind", "the tab in front is closed, and the app's list of windows is 50 ms behind" (at 10 ms the second is green: "destroyed" comes 12 ms after "main window changed").
WHY: 1032-1036: "created" → `rescan` reads the list, which still has the old window and not the new → nothing to do → `addWindow(element…)` announces the newcomer. At the next rescan it is "a window the controller knows as a window of its own" and no candidate (690-691). 1038-1046: both rescans find the old list, `drop`.
Only a Space switch gets a second reading (`rescanSoon`).
HOW SURE: that lists lag is SEEN (640-644: "the app's list is behind, or in flux"; ledger "an-apps-window-list-lags-behind-the-screen"). That they lag at the moment a tab is made, and by how much: GUESS.
TO CONSIDER: before announcing a window that was reported created, ask the window server whether another known window of the app at the same frame has just gone off screen (`isOnScreen`): that is a tab whatever the list says. Or `rescanSoon` after every created / destroyed.

### N7. "Whoever posts a notification is awake" costs a second for each notification that was on its way when the app hung   (FOUND BY THE WALK, overtaking)
WHAT A PERSON SEES: an app opens a window and is at once busy loading what goes into it. Arbor's shortcuts, menu and socket are dead for FOUR seconds (three notifications on their way: created, focused, main changed).
STORY: "an app opens a window and is busy at once, loading what goes into it" (4.0 s).
WHY: 1019 `element.windowID` waits 1 s (GUESS: that `_AXUIElementGetWindow` waits for a hung app like any call), 1035 `rescan` waits 1 s and marks the app silent; then 1029 for the NEXT notification: `!answers(pid)` → `answersAgain` → `refresh` → `makeSnapshot` reads the title: 1 s, marked silent again (and one more detached task that asks every
half second); and so on for each. HOW SURE: the logic is the layer's own. That an app posts and then blocks within the 2 to 15 ms a notification takes is an everyday thing (a document window). Without the guess about `_AXUIElementGetWindow` it is 3 s.
TO CONSIDER: a notification proves that the app was awake when it POSTED. Believe it only if the app has been marked silent for longer than a notification can be under way (say 0.1 s), or let `answersAgain` make its first call off the main thread as the pinging task does.

### N8. Rare races, for the record (walk, 1 or 2 of 300 seeds each; listed as "sometimes")
- ⌘T a quarter of a second into a Space transition: the notice arrives after "created", `rescan(afterSpaceSwitch: true)` does not look for tabs, the new tab is announced as a window (`polite|191|space 19 16; space 9 52 +0.002; tab 31 58`).
- A window opens 2 ms before its app hangs; two Space switches later `countWindows` has counted it as there, and when the app wakes it is announced as found, not new (`overtaking|153|open 96 86 +0.002; hang 12 68; space 76 57; space 72 28`).

### N9. Arbor starts, or resumes, while an app hangs: seconds of standing still, and after a long hang the app's windows are never known   (FOUND BY THE WALK, once it went on past listed faults)
WHAT A PERSON SEES: log in, or end a pause, while some app beachballs. Arbor's shortcuts, menu and socket go dead for a second, again and again: four seconds in all if the app hangs for five, nine if it hangs for a minute. After the short hang its windows turn up within three seconds of its waking. After the long one they
never do: they cannot be docked, do not go out of view with the others, are in no list, until the person happens to switch to that app.
STORIES: "Arbor starts while an app hangs, which wakes 5 / 60 s later". Walk: 2 of 40 seeds (twice or never), 1 of 40 (all four), 1 to 5 of 400 under the other manners, the polite one among them.
WHY: `observe` 399: `AXObserverAddNotification` (414) waits out the second on the main thread → `retryObserve` 440 → `RetrySchedule`: 0.25, 0.5, 1, 2, 4, 8, 8, 8 s, each try another second of main thread. At the end 442: "gave up observing pid …; it gets another chance when it comes forward". The app is in neither `apps` nor `unresponsive`, so
the task that asks hung apps "are you back?" off the main thread (`noteSilence` 527) is never started for it.
HOW SURE: the layer's own logic. The one assumption is that `AXObserverAddNotification` waits for a hung app like any call: SEEN (a trace of a start with a hung app on a hosted Mac has 1.06 s for a call on the main thread).
TO CONSIDER: treat a timeout in `observe` as silence: hand the pid to the pinging task and observe when it answers, without a limit and without the main thread.

### N10. A window that its app had put away before Arbor started is announced as open all along when it is shown again   (FOUND BY THE WALK)
WHAT A PERSON SEES: Music's window was closed before Arbor was started (or during a pause). Open it: with "new windows are docked" it is not docked, and no rule for new windows applies: to Arbor it was there all along.
STORIES: "an app's one window was put away before Arbor started, and is shown again, the focus reported first" (red); the same with "created" first (green).
WHY: 784 `counted = existing.subtracting(putAway)`: whatever the window server lists counts as there. `putAway` (777) is filled only in `drop` (934), from having seen the window go; a start begins with it empty, and the window server still lists the closed window. 809 `hasOpenedSince = counted.insert(id).inserted` is then false, and whoever meets the
window first through a focus report files it as `found`. "Created" says new by itself.
HOW SURE: that such apps keep the number and the window server the window: SEEN (a cure that is on the trunk, for a window closed and opened again while Arbor runs, rests on it). That apps report the focus before the creation: SEEN (R1). Both together after a start: never looked for.
TO CONSIDER: at a start count only what the window server shows or an app lists (`kCGWindowIsOnscreen`, or minimized, or on another Space by its app's word); or let "created", when it follows within a moment, correct `found` into `appeared`.

### N11. A move that a hang swallows   (FOUND BY THE WALK, which shrank it to two steps: `overtaking|146|move 60 96 +0.002; hang 34 99`)
WHAT A PERSON SEES: an app resizes or moves its docked window and is busy at once (a document loads and the window fits itself to it). Arbor is dead for two seconds, and afterwards goes on believing the old frame: the neighbours are not laid out again, the focus ring is drawn where the window was, and the next layout starts from a wrong frame.
STORIES: "an app moves its window 1 ms before it hangs for 5 s" (red: Arbor has 100,100 400×300 for a window at 20,110 260×200, and no `changed` is ever said); "… 50 ms before …" (green: the control).
WHY: `geometryChanged` 1002: `guard … let frame = record.element.frame else { return }`: a read that times out is like a window that is gone: no `noteSilence`, nothing remembered. If the app is marked silent by another call, `answersAgain` (560) refreshes what it knows; here nothing marks it, so nothing is asked again when it wakes.
HOW SURE: the layer's own logic. That an app posts and then blocks within the 2 to 15 ms a notification is under way is the same everyday thing as in N7.
TO CONSIDER: read with the error in hand; on `.cannotComplete` `noteSilence`, which brings `answersAgain` and its refresh. (A layer with a lane for each app is said to replay such reports when the lane is free.)

### N12 to N15. Apps that hang or are slow while Arbor has something to ask of them (`tests/SlowApps.swift`, storey two)
Told by what is on the screen, so that they hold for a layer that asks on the main thread and for one that gives each app a lane of its own. On the trunk:

| story | the trunk |
|---|---|
| **N12** Arbor is quit 0, 0.3, 1 s after an app with windows out of view begins to hang | **the windows stay at 1023,673 for good** after the app wakes |
| ~~N13~~ an app hangs for 8 s at the first setting call of a move out of view; Arbor is quit meanwhile | ~~"AXPosition = 1023,767" is carried out when the app wakes, 7 s after Arbor is gone~~ **the park goes with Arbor's process: all in view.** Only if the app is in the middle of that very call is it taken to be carried out (a guess, a story of its own) |
| **N12 again** it hangs at the reading back: the park HAS been carried out | **the window is out of view, and Arbor can neither fetch it nor leave word** |
| … it hangs at the very beginning of that move | nothing was sent: all in view |
| Arbor is paused 0, 0.3, 1 s after such a hang | taken within 4 s; windows back within 10 s of the wake |
| **N14** ⌘Tab away while Arbor's request for the keyboard waits 0.8 s for a slow app | **the keyboard, and the ring, are taken from where the person went** |
| **N15** an app takes 0.7 s over every move, one window refusing its slot's width | **`arrange` answers after 3.3 s**; in the end no window lies over another, and Arbor has done with them |
| an app wakes after 0.7 s in the middle of a move; Arbor's main queue on time, or 20 ms late | right places, no further pulling |
| the app opens a window, resizes a docked one, gets a new tab 5 ms after it wakes | known, in view, right size, the tab in its place |
| a window is moved by hand while Arbor moves its slow app's sibling (storey one) | told apart |

WHAT A PERSON SEES, N12: quit Arbor while an app beachballs, and windows of that app are gone from the screen with nothing left running that could fetch them: the one thing a window manager must not do.
**N13 IS STRUCK (2026-10-15).** It said that a park which waits in the queue of an app that hangs is carried out after Arbor is gone. That was the model's own assumption ("what is sent is sent"), written down as seen when it had only been seen with Arbor alive. A hosted Mac has refuted it (macOS 26.6.2, `scripts/mac-shell/check-hang.sh`,
session 2, on a layer that leaves word at a quit): a place and a size sent to each of two windows, Arbor's process gone half a second later, the app awake 18 s after that, both windows where they had been, place and size; in session 3, after the same four calls at a pause, with Arbor alive, both were in view at the script's first look, 2.5 s after the wake, and the log lacks the line with which the controller says that IT fetched a window (the run on the trunk, which leaves no word, has that line). **macOS
drops what a process has asked once that process is dead.** So the advice below to leave word at `stop()` is void at a quit, and holds at a pause. With the model put right the quit stories have the same colours on the trunk and on both halves of the lanes.
WHY: N12: `setFrame` gives an app up at the first call that goes unanswered, and `stop()` leaves no word for it. N13: a call that timed out lies in the app's queue and is carried out on waking; nothing is sent after it to undo it. N14: `focus` 303: `setBool(kAXMainAttribute)` (307) waits for the app on the main thread; if the app
answers within the second, 316-318 go on to raise and activate without asking whether another app has come forward since `began`; `activations`, which 324 reads for the opposite purpose, would tell. N15: every call of every move is waited for on the main thread, one after the other.
HOW SURE: N12 SEEN on hosted Macs, twice: with a layer that sends nothing more at a quit, and with one that leaves word. That a park is carried out on waking as well as a fetch is seen WITH ARBOR ALIVE (while the view moves, at a pause). N14, N15: the layer's own logic; that big apps answer slowly is seen (100 to 190 ms of the layer's work for one focus report with Safari and Finder).
TO CONSIDER: N12: ~~at `stop()`, send the fetch to every window that is or may be out of view, with a short timeout and without waiting for an answer: what lies in the queue last wins~~ works at a pause only. At a quit somebody has to outlive Arbor until the app answers (a helper process, or Arbor's own process staying on without its menu), or
the quit has to wait. N14: after 307, `guard activations == before`. N15: the lanes.

### N16. Arbor's own move is reported as the person's, if the app carries it out a moment after saying yes   (FOUND BY THE WALK AT STOREY TWO, under all four; told without dice)
WHAT A PERSON SEES: an app answers "done" at once and moves its window 20, 50 or 200 ms later. Frame another window and come back: the app's FLOATING window is not where it was (624,218 400×300) but at 624,405, and 341 points wide. In the walk a floating window that had been sent out of view was taken for put in the corner by hand, and
stayed there (`upstairs, all four|243|dock 78 23; zoom 33 70 +0.3; close 95 56`). Docked windows come right.
STORIES: "an app carries out 20 / 50 / 200 ms late what it is asked, and Arbor gives its window a frame" (`changed … user` 0.3 s after the move); "…, one of its windows floats, and the view goes to another window and comes back"; "…, and the view goes to another window and comes back" (docked: green).
WHY: `setFrame` reads the frame back right after the calls and gets the old one; that is what the echo filter is told the window took. `lookAgain`, `EchoFilter.settleTime` later: `echoes.hasStrayed(window, now: frame)` holds the frame of now, which is the one Arbor asked for, against the stale read-back: "did not stay where it was put",
`windowChanged(…, userInitiated: true)`. To the controller a floating window's frame is its person's.
HOW SURE: the layer's own logic. The manners: SEEN of Safari on its way out of full screen ("answers success to all three calls, reads back the old frame", docs/REALITY.md) and "the window server applies moves a moment later"; in general, and for how long, a GUESS.
TO CONSIDER: `hasStrayed` against what was ASKED FOR as well as what was read back: a window that is where Arbor sent it has not strayed.
SINCE a floating window's frame is its person's (see U2) the floating window of the three stories is where it was: green. The report as the person's is still made.
COUNTED: "how often Arbor asks for a frame as the view goes away and comes back": of two windows of an app that is on time 4 times, of one that is 20, 50 or 200 ms late 6 times: each is sent out of view twice, the second time 0.3 s after the first. Then Arbor has done with them. In 1 of 400 seeds of the walk upstairs the late calls of
several moves land in one burst and two docked windows are left out of their places, over a third.

### N17. A pause while a park waits in the queue of an app that hangs   (told for a change under review; the trunk has it too)
WHAT A PERSON SEES: an app begins to beachball just as the view moves away from its windows; they stay on the screen, because the app does not carry the move out. Pause Arbor, which promises every window in view. Seconds later the app wakes, and one of its windows leaves the screen. Nothing fetches it until `resume`.
STORIES: "an app hangs between the question and the move as its windows are sent out of view, and Arbor is paused" (never, in 40 s). For a layer that remembers an app's answer for a second instead of asking before every move: "an app hangs 0.5 / 1.5 s after it last answered Arbor, its windows are sent out of view, and Arbor is paused", green on the
trunk, whose question times out so that nothing is sent. Both end with "and after `resume` they are in view": green.
WHY: `Controller+Hardening.swift`, `tryWhatCouldNotComeBack`: the look-out first asks the window server and strikes from its list whatever is in view ("somebody else has fetched it"). Until the app wakes that is where the window is. One second into the pause the list is empty, with the park still in the app's queue. The account shows it: after the
pause not one wait for the app, so no try ever got as far as asking it.
HOW SURE: the controller's own logic. That a park which timed out is carried out on waking while Arbor lives: SEEN on hosted Macs. The look-out itself is held to two logs of hosted Macs ("as on a hosted Mac: … and half a second later Arbor is paused"): three tries, each held up a second by the app, as there.
TO CONSIDER: strike a window off only once its app has answered something since the note was made; or leave word at a pause, after whatever may be in the queue (a change under review does, and both stories are green with it).

### N18. The ways out while an app hangs: the shape of the slot for good   (told for a change under review; the trunk has it)
WHAT A PERSON SEES: `float-all`, `float` or `undo` while an app beachballs: when it wakes its windows float, in view, in the shape of their slots (12,374 390×319 instead of 500,60 400×300), and nothing ever gives them their own frames back: no layout moves a floating window that is in view.
STORIES: "`float-all` while an app with two docked windows hangs for 6 s, and … meanwhile": nothing else happens; the view goes to my window and comes back, or stays there; one of them is docked again, moved by hand, closes; Arbor is paused, or paused and resumed; they are arranged again. The same with an app that takes 0.8 s over every move, which
the trunk waits out. Each ends with another hang, with the view away and back, which would show a debt that was neither paid nor forgotten.
SINCE a floating window's frame is its person's (see U2) two more of them are red: "the view goes to my window and stays there" and "one of them closes". A trip out of view and back used to give the windows their own frames; now it puts them back exactly where they were, in the shape of their slots.
FOR WHOEVER REMEMBERS THE DEBT: pay it once; not after a dock, a hand's move, a close; not into view while the Desktop is out of view; and mind that it dies at a pause.

### N19. One command, a polite Mac, and the keyboard ends with another app's window   (found when a story's staging fell apart under a change; told with a control)
WHAT A PERSON SEES: Busy is in front, the keyboard in its docked window. Busy has a floating window too, and so has Mine. `zoom` (or whatever asks for) Busy's floating window: the view goes to the Desktop, the window is in view, and the keyboard is in MINE's floating window.
STORIES: "apps are on time, and Arbor is asked for a floating window of an app in front whose docked window had its keyboard", and the same with apps 50 and 200 ms late. Red on the trunk before and after floating windows kept their frames.
WHY: `giveFocus` brings the window into view first. With that the docked window that has the keyboard goes out of view, and `ensureFocusIsVisible` hands the keyboard to a window in view: Mine's (`focus`: main, raise, `activate()`). The request for the window that was asked for follows in the same breath, as the comment there says it must; but
`AXWindowSystem.focus` returns before `activate()` when `NSWorkspace.shared.frontmostApplication` names the window's app, and it still names Busy. Mine's activation lands, and nobody takes it back. It is the fault others have read out of the code for two quick presses ("a request for the keyboard that is taken back"), with one command and no haste.
HOW SURE: both halves are Arbor's own logic. The manners: that `frontmostApplication` names the old app for a moment after another has been asked forward is SEEN (R2; 27 times in three runs); the model plays 2 ms on a polite Mac, and the two requests are microseconds apart.
TO CONSIDER: no hand-over on the way when a request for a window that will be in view is about to follow; or a layer that remembers the activation it has asked for.

### For whoever spares a call because the window is there already
"apps carry out 50 ms late what they are asked, and Arbor is asked for a floating window of an app in the background whose docked window had its keyboard": green on the trunk, which always sends the place. What is read back right after a move of such an app is the old frame; a fetch that is spared on that belief leaves the window where the park, still to be
carried out, takes it: at the corner, with the keyboard. Found by the walk upstairs under all four (7 of 600 seeds on a change under review, none on the trunk).

### For whoever keeps a request for the keyboard until an app answers again
Six stories: "an app in front begins to hang, Arbor is asked to give the keyboard to another of its windows, and … before it wakes": nothing else happens (the window gets it); the person goes to another app with ⌘Tab; the same, and the workspace's notice of it is lost (a GUESS that this happens); clicks in another app's window; Arbor is asked for another app's window; the person asks the app for a third window with ⌘`. All
green on the trunk, which keeps nothing: its request lies in the app's queue in its turn. Two are traps. The key lies in the queue too (a GUESS), is obeyed at the wake, and a request made afresh after that takes the keyboard back. And after an activation that Arbor never hears of, a kept request brings the app forward over the one the person went to.

## Short of its slot (round 3): since 98206418; CURED since ("a docked window fills its slot: nobody in view is asked to grow where it stands")
What follows is how it stood while it was open.
WHAT A PERSON SEES: dock a window that stands low on the screen: it ends 494×484 in the middle of a slot of 494×650. Found on a hosted Mac by others, who read the rule off the recordings: **a size call that makes a window grow stops a point above the Dock, and at the display's right edge, from where the window stands when the call
arrives.** The model did not play that: a window took any size anywhere. Now it does (`FakeMac.roomToGrow`, with its source, its circumstances, none of them varied, and what was not seen); "a window is asked to grow where it stands" holds it to seven frames of the recordings.
STORIES: "windows that stand low on the screen: dock 101 left" (w101 at 12,126 494×484: the Mac's frames to the point) and "…: arrange" (w103 at 414,86 391×564 in a slot of 391×650). The windows stand where the hosted Macs' scripts put them.
WHICH COMMIT: the same model and stories on three commits, each from nothing: 07b2bfc (the parent) 1,378 ✔, both stories green; **98206418 1,353 ✔, both red**; the trunk at f116af2 1,356 ✔, both red. With them 18 checks of older stories at storey two turn red, and the polite walk upstairs breaks "a docked window that Arbor has in view is in its place" in
10 of 10 seeds (parent: none). All were listed under one heading in `known-failures.txt`, and fell off it with the cure.
WHY: since 98206418 a window is asked for its slot's size where it stands (`Controller+AskFirst.swift`); the answer is the room below the window, not the app's limit; Arbor takes it for a refusal and lays the window out at that size in the middle of its slot. Before, the first size call was clipped as well, and the third, at the new place, made it good.
WITH AN APP THAT IS LATE ("a window that stands low on the screen is docked left, and its app …"): one that carries out everything 50 or 200 ms late, in order (`carriesOutAfter`), comes to rest at 12,79 494×591 after five rounds 0.6 s apart, each set off by N16: green on the parent. One that is sized at once and moved late (`appliesPlaceAfter`, a GUESS)
is clipped at the old place whatever the order of the calls, and rests at 494×648: red on the parent too. Both fill their slots after the next layout.
BETWEEN SIZE AND PLACE ("on its way to a slot a window …", six stories; the model keeps each window's road; CURED since, all six green): with size, position, size the window showed its new size, or as much of it as macOS allows there, at the old place: five of six red. With the new order (what shrinks is sized first, what grows last), landed since, all six are green, and the end is whole from
low on the screen, from the corner out of view and from hanging over the right edge. That change alone brings back none of the stories above: the controller still asks where the window stands.
THE CURE turns all of them green on the model, the walk's ten seeds too, seven more that were told later (a slot that ends at the Dock, a window docked just after another has landed in the Dock, displays that go and come back) and the two of an app that carries out late what it is asked. One check that was red before 98206418 is red again ("three docked windows of an app that hangs: the echoes of its move of the OTHER app's window count as echoes").
HOW SURE: the rule is SEEN (23 answers of 23 at 704; my own reading of the 182 calls found none against it), for AppKit's plain test windows on one display of 1024×768 with the Dock at the bottom.

## From a small display to a large one (round 3; `tests/TwoDisplays.swift`): OPEN
A probe without Arbor asked a hosted Mac 844 times how far a window grows or goes, call by call. Its rules are in the model where they are declared (`FakeMac.roomToGrow`, `display(holding:)`, `setPosition`), each with its counts, what was varied (the Dock at the bottom, at the left, hidden; one display and two, the small
one at three sides; a test window, ten of Apple's apps, one Java app) and what was not (the Mac, its macOS, scale 1, one Space). Two guesses of this model fell: an edge past its line is free only when it is OFF the display, and "less 1" belongs to the Dock at the bottom of that display alone. One story holds the model to the probe line for line.
THE RULE THAT COSTS A PERSON SOMETHING: **for a moment after a position call has taken a window to another display, the display it came from judges a size call** (10 calls of the 10 that can tell, 0.5 to 5.6 ms after; at 200 ms the new display judges, 4 of 4; the 100 ms played are a GUESS).
WHAT A PERSON SEES: a docked window sent from a display of 800×600 to one of 1920×1080 ends 624×557 in the middle of a place of 624×947 (788 wide of 1,896 with the small display below), and stays so for as long as nothing else happens; the next layout makes it good. The small display's answer is written down as where the app stops growing (`stoppedAt`).
WHY: whatever the order of the calls, the size call that is to make the window grow comes a millisecond after the position call. Nine checks at storey two, one at storey one (the layer alone). Red before and after the cure for the short window, and before and after the new order of the calls (what grows is moved first) alike.
A floating window sent the same way keeps its size and is green. Displays that go and come back were red only by "short of its slot", and are green since its cure. NOT PLAYED: macOS's own rescue of windows at an unplugging.
HOW SURE: the rule is SEEN, in all four orders of calls; how long the moment lasts is not known between 5.6 and 200 ms. If it is shorter than the layer's own pace on a Mac (a call takes 1 to 10 ms there) the fault may show less often than here. No Mac has played Arbor on two displays.

## The flight to the Dock (round 3; `tests/Flight.swift`)
A probe without Arbor measured it on a hosted Mac (`origin/mac-shell-out/probe.flight`; what was varied and what was not stands with `FakeMac.minimize`). The model had it wrong by omission: nothing waited during a flight, and `AXRaise` left a minimized window in the Dock. Now the window's whole app is deaf for the 0.55 s, the window
server has the genie's boxes, the three reports come at the end, `AXRaise` fetches a minimized window out and returns when it has landed, holding back what the app had still to post, and `AXMain` alone does nothing to it. One story holds the model to the probe, call for call.

| story | the trunk | each app on a lane of its own (f396381) |
|---|---|---|
| the window that fills the view is minimized by hand | stays in the Dock; the keyboard is in view | the same |
| **…, and the view is held** | **it is out again after 0.55 s, which Arbor's main thread waits out** (0.57 s) | the same (0.56 s) |
| a window goes to the Dock, and Arbor is asked to give it the keyboard as soon as its sibling is reported focused (storey one) | **out again; 0.55 s** | the same |
| … a second after it has landed | out, with the keyboard, as asked; **0.55 s of main thread** | the same |
| a window flies to the Dock, and Arbor moves its sibling in mid-flight (storey one) | the move waits out the rest of the flight on the main thread (0.45 s), is carried out, counts as Arbor's own; the app is not written off | the same |
| the view moves 0.1 / 0.4 s into the flight of a docked window | answered at the end of the flight; everything in its place | the same |
| the view moves 0.01 s into a flight of 0.66 s, the longest measured | 0.65 s | **the lane is late** (patience 0.5 s): answered after 0.5 s, everything in its place afterwards |

The held view's fault was found on a hosted Mac by others, who took the half second for a report that came early; the probe showed that it is Arbor's own raise. WHY: the keyboard goes to a sibling out of view; a held view sends it home; home is the window that has just landed; `focus` makes it main and raises it without asking whether it is minimized.
Arbor's own `minimize` and its undoing cost the main thread nothing: the call that sets `AXMinimized` returns at once (0.2 to 0.6 ms, 8 of 8, a later probe). The model had guessed, from `AXRaise`, that it returns at the end of the flight: wrong, and corrected within two hours.
The polite walk stayed clean with the flight in the model; under bad manners the counts moved by a seed or three, and no rule broke that had not broken before, but for one's twin "though an app has hung" (N1, 1 of 400 seeds upstairs).

## What the walk at storey two found (round 3)

The real `Controller` on the real layer on the model, with commands among the steps, a pause, a quit and a new start; the rules look at the model's SCREEN and hold it against what the controller says it has in view and out of view (`tests/WalkUpstairs.swift`). The polite control first: a rule that breaks there is news. 400 seeds × 40 steps,
polite and all four. N1 (a place kept for a window that closed without a word: 21 of 400 under all four, none on a polite Mac) and N9 (15 of 400; the main thread's waits in 96) show upstairs as expected. What is new is the controller's, not the layer's. For each: does `arbor-sim` show the same on the stand-ins, and which of the chaos lab's nets
should have had it.

### U1. A window dropped where there is no room for it is shown as a tile, out of view, and keeps the keyboard   (FOUND BY THE WALK ON A POLITE MAC; shortest `arrange; drag`)
WHAT A PERSON SEES: three windows arranged on a display of 1024 points. Take one by its title bar and drop it beside another. It vanishes: where it was dropped there is a tile with its name, and a line on screen says "Too small to show: click the tile to zoom in". The press gave it the keyboard, and it still has it, at 1023,673: what is typed next
goes into a window nobody can see. With five windows and a drop at the screen's edge EVERYTHING turns into tiles: six tiles, no window, the keyboard in one of the five.
STORIES: "three windows are arranged, and one is dropped beside another where there is no room for it"; "five windows are arranged on 1024 points, and one is dropped at the right edge of the screen, macOS's tiling off". Walk: 3 of 400 polite seeds, 3 of 400 under all four.
ON THE STAND-INS: THE SAME. `arbor-sim "display-size 1024x768 31" "open App1 420x320" "open App1 380x300" "open App2 460x300" arrange "focus 101" "drag 101 492 344" "wait 2" health type` → `HEALTH ok`, `typed into 101`, `2 out of view`. (`focus 101` stands for the press: the stand-in's `drag` gives the pressed window no keyboard, which a real
press does. Without it `type` goes into 103, which has become a tile as well.)
WHICH NET MISSES IT: the keyboard's nets (`switched-to-out-of-view`, `app-switch-out-of-view`) ask only in the step in which the person SWITCHED to a window (`seven.switchedTo`); a drop is no switch, the less so as the stand-in's drag reports no focus. `launch-keyboard-in-a-tile` is the same sight at a launch, and decided (Q16). Nothing asks the standing
question: once all has come to rest, is the window with the keyboard in view? `health` does not ask it either.
HOW SURE: the controller's own logic, on both sets of windows.
TO CONSIDER: the window in the hand is the one the person is looking at: after a drop that leaves it a tile, go to it (what a click on the tile does), or refuse the drop as the preview could have said. For the nets: a standing `keyboard-out-of-view`, asked at rest, with the held view and the peek excepted as in `switchedToViolations`; and let
`FakeWindowSystem`'s drag give the pressed window the keyboard.

### U2. A window that opened over a docked one is left there, and the next layout, whatever brings it about, pushes it onto the Desktop and shrinks it   (KNOWN; confirmed on the real layer; CURED)
CURED since "Arbor sets a floating window's frame only to take it out of view and to put it back exactly where it was": the story is green, and the walk's rule ("a floating window stays where it is while something else happens") breaks in none of 400 seeds, polite or under all four. As it stood:
WHAT A PERSON SEES: a window is docked at the top. Its app opens another window, which lies half over it, and stays there. Two steps later ANOTHER app quits: the new window jumps 124 points down. In another walk it was also shrunk, from 440 to 337 points, to fit the Desktop.
STORY: "a window opens over a docked one, and then another app quits". Walk: 9 of 400 polite seeds, 18 of 400 under all four.
ON THE STAND-INS: THE SAME, AND LISTED: `moved-unasked` in `Sources/ArborTesting/ChaosKnownFailures.swift`, severity 2, with two scripts, in nearly these words. No net misses it.
TO CONSIDER: either moment may be right, at the opening or never, but not "at the next thing that happens".

### U3. The view goes to a Desktop with nothing on it, and the keyboard stays with a window out of view   (FOUND BY THE WALK ON A POLITE MAC; shortest `arrange; desktop`)
WHAT A PERSON SEES: everything is docked. ⌃⌥D, or `back` to a Desktop whose one window has closed since: an empty Desktop, no window in view, and what is typed goes into the docked window that had the keyboard, now at 1023,673.
STORIES: "with nothing floating, the view goes to the Desktop (desktop)", "… (back)". Walk: 3 of 400 polite seeds.
ON THE STAND-INS: THE SAME. `arbor-sim "open App1" "open App2" arrange desktop "wait 2" health type` → `camera n0  hidden: w101 w102`, `HEALTH ok`, `typed into 102`. With a window on the Desktop the keyboard goes to it (`typed into 103`): a command that moves the view hands the keyboard to a window in view if there is one; with none it stays.
WHICH NET MISSES IT: the same as U1: nobody switched to anything, so nobody asks.
HOW SURE: the controller's own logic. Whether it is a fault is the product's to say: the person asked for that view.
TO CONSIDER: give the keyboard to nobody that can be typed into (Finder's desktop, as a click on the wallpaper does). The same standing net would ask.

### U4. ⌘Tab to a hidden app whose windows are on another Space   (walk, 1 of 400 polite seeds; for the record)
`upstairs, polite|308|dock 51 88; hide 68 21; dock 92 81; in 16 60; space 80 85; focus 8 68; activate 54 90`: macOS shows the app again and switches Space; the layer reports `focused` 0.34 s before the Space's notice; the controller does not act on it (the window is still "on another Space"), and nobody says it again afterwards: the window
has the keyboard at 1023,673, the view stays on another. HOW SURE: that the app comes forward before the notice is a GUESS (N3's probe would settle it).

### Also seen, and no fault
- Under late calls (apps that carry out up to 80 ms late what they are asked) `arrange` of five windows takes 2.06 s and 112 calls, in three rounds, to come to rest; then all is right. So the walk looks when Arbor has come to rest, and "within five seconds" is a rule of its own, which never broke.
- A window restored from the Dock gives the display two points back; `displaysChanged` is reported, and the docked windows are left a point off their new places. The rule allows two points.
- The model was wrong five times on the way, each time ruder or tidier than a Mac: calls to one app overtook each other under late calls; a restore "by hand" left the app in the background; the walk took hold of windows that lay under others, closed what did not show, and called lost what a hand had just put at the screen's edge.

## What held (no finding), under all four kinds of bad manners, 400 seeds × 40 steps × 6
every window is announced once; no window is reported gone that is still open; nothing is reported about a window that was not announced or is gone; what the layer has announced is what it lists; flags (minimized, hidden, full screen, Space) and frames right after two seconds;
the layer's last word on the keyboard in the lenient sense (keyboardFocusMoved + focusedWindow()); no drag or resize left open with the button up; a drag or resize begins once and ends once. Duplicated notifications, a second mouse-up, dropped `AXMoved`, swallowed releases and late calls found NOTHING.

## Drags that are lost on a loaded Mac

Two ways to lose a drag. The first loses a drag of ANY length and is the likely one on the loaded hosted Macs. "Lost": no `dragBegan` for the whole drag, so no preview and no drop. The window has moved in every case, and Arbor knows where it ends up.
Stories: `scripts/mac-on-linux/tests/LostDrags.swift`.

### L1. The 24 points of patience: the window server is a moment late, the pointer is not   (CURED by a3c0281; what follows is how it stood)
| the window server begins to move the window … after the press | pointer 10 points away by then | 24 points | 40 points |
|---|---|---|---|
| 0 ms | drag began 11 ms after the press | 11 ms | 11 ms |
| 100 ms | began at 121 ms | began at 121 ms | **LOST** |
| 400 ms | began at 421 ms | began at 421 ms | **LOST** |

(Each drag then goes on for 0.65 s and 200 points. The lost ones: 8 `AXMoved` arrive with the button down, each passed on as `windowChanged(userInitiated: true)`, none makes a drag.)
WHY: a `leftMouseDragged` arrives, `lookAtPressedWindow` (1220-1231) reads the window server's bounds, they are those of the press, `WindowGrab.classify` (WindowGrab.swift, last lines) finds "not moved, not resized, pointer more than `patience` = 24 away" → `.neither` →
`decide` sets `press.isSettled = true` (1248-1249). From then on BOTH signs are deaf until the button comes up: `lookAtPressedWindow` and `noteMoveWhilePressed` (1235) each begin with `guard … !press.isSettled`. One early look settles the whole press.
24 itself is safe (`> patience`). It is the DISTANCE at the first look that finds the window unmoved that counts, not the time: a slow hand survives 400 ms, a brisk one does not survive 100.
HOW IT FITS THE HOSTED MACS: the traces' synthetic pointer takes steps of about 18 points (drag-to-edge: 510 → 493 → 476), flick-to-edge of 56. Two steps, or one of a flick, before the window server has moved the window, and the drag is gone. On an idle Mac the window server moves the
window with the very event, so it never shows. That a loaded window server lags the pointer is a GUESS that fits; nobody has measured it. WORTH A RUN: log `serverBounds` against `cursorLocation()` at every leftMouseDragged on a loaded runner.

### L2. The whole gesture is over before Arbor hears of the press
| | a drag of a second (200 points) | a flick (0.27 s from press to release) |
|---|---|---|
| the monitor hears of the press 0 / 20 / 100 ms late | began at 151 ms (the hand rests 150 ms) | began at 151 ms |
| 500 ms late | began at 551 ms, 5 of 10 moves seen | **LOST** |
| Arbor's main thread busy 300 ms from the press; backlog served by time | began at 300 ms | **LOST** |
| … Accessibility's reports first | began at 311 ms | **LOST** |
| … the mouse's events first | began at 300 ms | **LOST** |

WHY: `makePress(at: cursorLocation())` (1139, 1169) and `lookAtPressedWindow` read the pointer and the window server NOW, not as they were when the event happened. Served late, mouse-down finds the pointer at its last place and the window already there; every queued `leftMouseDragged` compares that frame with
itself (`.undecided`); mouse-up ends nothing. The `AXMoved` in the backlog are no help in any order: before the mouse-down there is no `press` (1235 `guard let press`), after the release `isMouseButtonDown()` (990) is false.
A LATE PRESS ALONE LOSES NOTHING as long as the window still moves afterwards: it only delays `dragBegan`, in all three orders of the backlog. The order makes 11 ms of difference and no other.
So the leftMouseDown being late against the first AXMoved (0, 20, 100, 500 ms) is harmless by itself; it needs a gesture shorter than the lateness.

### L3. Since 37d0f05: the press's own place, held against the window list of the moment it is served
Found at the rebase onto the trunk that has the cure for macOS's tiling. The story "a window is dragged for a second, and the monitor hears of the press 500 ms late" was green (drag began at 551 ms, row above) and is RED: no drag at all, 6 reports that the window changed.
WHY: `handleMouse` now takes `event.cgEvent?.location` for mouse-down and mouse-up, and `cursorLocation()` answers with it while the event is handled. So `makePress(at:)` gets the point where the button went down, 300,112; but it looks for the window under that point in `CGWindowListCopyWindowInfo` as it is NOW, when the window
has been dragged to 200,175 and no longer lies under it. No window is found (or the one behind, which settles the press). The second sign fails as well: `noteMoveWhilePressed` falls back on "where the window was" by Arbor's belief, which two `AXMoved` have already brought up to date.
Before, both the point and the list were of the moment of serving, which agreed with each other, and the drag was picked up from there. At 0, 20 and 100 ms late, and with the main thread busy for 300 ms, it is still seen (there the belief is still the old one, and the second sign saves it).
TO CONSIDER: look for the pressed window with the point of the event among the frames Arbor believed BEFORE the first report that came with the button down; or, if no window lies under the event's point, try once more with the pointer's place now.

### L4. Since 531885f: the second look at a late press settles it
**Cured the same night by way (A) below: the five lines are out of the trunk again, and the four checks are green. Way (B), which cures L3 as well, is still to come.**
Found at the rebase onto the trunk that has 531885f. "A window is dragged for a second while Arbor's main thread is busy for 300 ms from the press", with what queued up served by time or the mouse first, was green (drag began at 300 ms) and is RED: no drag, 6 reports that the window changed. With Accessibility served first it is green, and
better than before (311 ms, was 412). L3 is as red as it was.
WHY: five new lines in `handleMouse`: if `makePress` at the event's own place finds no window and settles nothing, `makePress` once more at the pointer's place of now. That is the pair L3 asked for. But `makePress` has since 12d1835 a test for macOS showing its desktop: `WindowGrab.isListedElsewhere(bounds, than: record.snapshot.frame)`, more than
`lead` = 32 points between the window server and what Accessibility last said. Served late, that is just how a window in the hand looks: the window server has it where the hand has carried it (157,143 after 0.3 s), Arbor believes it where it was (100,100), 71 points apart. So the window is taken for the strip of one swept aside, and the press
is SETTLED. Before, it stayed open (`window == nil`, not settled), and the app's next "moved" made the drag through `noteMoveWhilePressed`'s second branch. With Accessibility served first the belief is up to date and the test passes.
SHOWN by two changes to a copy, one at a time, all 272 stories each: (A) without the second `makePress`: the four checks green as before (300, 412, 300 ms), L3 red. (B) with it, and not asking `isListedElsewhere` at that second look: the four green, **L3 green (551 ms)**, 311 ms with Accessibility first, and nothing else changes.
TO CONSIDER: (B). It cannot let a swept window through: a press on a strip finds the strip under the event's OWN place, at the first look, which settles it, and there is no second look.

### L1, round 2: coarse steps, one leap, the controls for a cure, and another cause with the same face
- **Coarse steps**, as `scripts/mac-shell/pointer.swift` makes them of a long drag (30 steps of 42 or 66 points, 0.1 s apart): window server on time: seen at 21 ms. 50 or 100 ms late to start, or 50 or 100 ms behind all the way: NO DRAG on the trunk, 27 or 28 reports that the window changed. This is the hosted Mac's picture.
- **The hand is quick and rests, the window comes after it in one leap** (120 points in 80 ms, the leap 300 ms after the press): lost on the trunk.
- **The controls**: a selection of 120 points during which the window changes by itself (the pointer's way by 40, 80 or 100 points, against it, across, aslant, resized) is never taken for a drag on the trunk. Whatever cures L1 has to keep as many of these as it can.
- **A system alert over the title bar** (SEEN late in a job on a hosted Mac: another process, the level of modal panels, 260 by 250): the alert gets the press, the window stays. The layer reports `pressed` and nothing else, and logs nothing. `makePress` 1207 skips whatever is not at level 0 (1217), so it takes the window UNDERNEATH for the one pressed: harmless while that
  window stands still. To a script this is L1's face from another cause: no drag, nothing logged. TO CONSIDER: a debug line in `makePress` when something of another process above level 0 lies over the point.

**The cure (a3c0281, on the trunk), held against these stories twice before it was published** (trunk | first form | mended form; ms after the press at which `dragBegan` comes; 42 and 66 points alike):

| | trunk | first form | mended |
|---|---|---|---|
| window server 50 or 100 ms late to start | LOST | 121 | 121 |
| … then a step AHEAD of the pointer, ending a step further, as was seen | LOST | 152, 202 (by the app's lagging report, not by the look at the window server) | the same |
| … ahead, and the app silent until the drag is over | LOST | LOST | **221** |
| 50 or 100 ms behind all the way | LOST | 121 | 221 (two looks: 100 ms later) |
| L1's first stories (100, 400 ms late, the pointer 40 away) | LOST | 201, 421 | 201, 421 |
| one leap with the hand at rest; the app reports as usual | LOST | 402 | 402 |
| … the app silent | LOST | LOST | LOST, but logged at the release |
| selection, the window jumps 40 the pointer's way | no drag | **FALSE DRAG** | no drag |
| selection, the window jumps to within 24 points of the pointer's own travel (80, 100) | no drag | FALSE DRAG | FALSE DRAG (its author names it as left) |
| selection: against, across, aslant, resized | no drag | no drag | no drag |
| L2, L3 | LOST | LOST | LOST: `press.window` is nil, so nobody is asked |

Red on the trunk and green with the mended form: 61 checks. Green on the trunk and red with it: 2. Walk, 300 seeds × 6: nothing new. The commit as published (d2bec74, `REF=origin/fix/a-window-that-starts-late-is-still-dragged`) gave the same against all 272 stories, and so did the trunk once it had landed: 61 lines of `known-failures.txt` deleted, 2 listed. A change that takes it out again turns its stories red. The first verdict (slack of 24 points is not enough for a window a step ahead; one jump cannot be told from a late start at one look, at two it can) is what the mended form was made from.

### Is anything logged? NO, at no level (as it was before a3c0281, which logs a late start, and at the release a window that moved and was taken for nothing)
arbor.log with ARBOR_DEBUG=1: a drag that is seen logs `DEBUG w101 is being dragged`. A lost one logs NOTHING: `.neither` (1248) and `.undecided` are silent, and so is a mouse-up with no grab (1150-1152). A trace would show the raw mouse lines and the `changed` events and no `dragBegan`.
CHEAP AND WORTH HAVING WHATEVER THE CURE: a debug line at 1249 ("the press on \(window) is settled as not about it: pointer N points away, window where it was"), and one at mouse-up when the pressed window's bounds differ from `press.frame` and no grab was open ("\(window) moved by dx, dy while the button was down and no drag was seen").

### What a person saw (storey two: the real controller on top; brisk hand, window server 100 ms late; macOS's tiling off, or the edge is macOS's since 531885f)
| story | on time | 100 ms late |
|---|---|---|
| a floating window is dragged to the left edge of the screen | preview, docked | **no preview; let go, it is NOT docked**: it lies half off screen at -207,350 |
| a docked window is dragged out onto the Desktop | floats where it was let go | **0.25 s after the release Arbor puts it back in its slot** (12,43 325×650): the drag-out is undone. While it is held Arbor does not pull at it |

### Towards a cure (not made here)
- `.neither` by patience need not be for good. Keep it as "not yet": if the pressed window's bounds later differ from `press.frame` by what the pointer has moved since the press (± a few points), it is a drag, however far the pointer had gone first. What patience is there for (text selected a long way, then Arbor or the app
  moves the window: the story "text is selected in a window…", and the ledger's "a false drag when swept windows fly back") does not move the window IN STEP with the pointer.
- For L2, at mouse-up: if no grab was open and `serverBounds(of: press.window)` ≠ `press.frame`… does not help as it stands, because `press.frame` was read late. The event's own location (`NSEvent.locationInWindow` of a global monitor's event is the screen location at the time of the event) would give `makePress` the true point;
  the frame at that time is lost either way, but `records[window].snapshot.frame`, Arbor's belief from before, is a good stand-in. With both, a flick served late could still be told as dragBegan + dragEnded.
- The self-test has a change for the other direction already ("a drag is known only by what the app reports").

### How sure
SEEN: the layer's code paths above run unmodified; `WindowGrab` is the real one. The traces' pointer steps and rests. That a loaded window server starts late was a GUESS when this was written and is SEEN since, with its number, about 0.1 s ("Has the model been right?", below); that it then catches up with the pointer in one jump (modelled so, and behind all the way as well) is still a GUESS; how the run loop orders a backlog (all three orders played; no difference).
The 15 red checks are listed in scripts/mac-on-linux/known-failures.txt, so whoever cures this deletes the lines.

## The cure for R2, held against the stories before it landed

The branch fix/an-app-switch-is-never-dropped at a698364, on the trunk since as 5726225 (it asks again every 10 ms, for half a second, until macOS names the app), with `REF=`: that commit's Sources, this branch's stand-ins and stories. 657 checks in 146 stories on each side at the time. "Trunk" below is the trunk before it.

VERDICT: it cures what it sets out to cure, at both storeys, up to its own limit of half a second, and NO check that is green on the trunk goes red.

### (i) ⌘Tab / Dock, the app's focused window unchanged and out of view

"lag" = how long NSWorkspace.frontmostApplication goes on naming the old app AFTER didActivateApplication was delivered.

| lag | storey one: the window is reported focused, once | storey two: the view moves to the window | trunk (both storeys) |
|---|---|---|---|
| 0 (fresh) | green | green | green |
| 5 ms | GREEN | GREEN | red |
| 8 ms | GREEN | GREEN | red |
| 20 ms | GREEN | GREEN | red |
| 50 ms | GREEN | GREEN | red |
| 200 ms | GREEN | GREEN | red |
| 600 ms | RED | RED (window stays at 1023,673) | red |

600 ms is past the cure's fifty looks (0.5 s): it gives up, logs at DEBUG only ("came forward and was never named as the app in front: nothing is reported"), and nothing ever reports the window. By design; whether a loaded Mac can lag
that long nobody has measured. The report comes at most 10 ms after the property catches up (seen: caught up at +36.6 ms, reported at +44.6 ms).

### (ii) the first new detail of R2 (lag 5 ms, caught up before AXApplicationActivated at 8 ms)
GREEN with the cure at both storeys. It does not lean on AXApplicationActivated or on the controller's `keyboardFocusMoved`: its own look 10 ms after the notice reports the window.

### (iii) the second new detail of R2 (a CLICK on ANOTHER window of the other app; AXFocusedWindowChanged / AXMainWindowChanged about 2 ms after the press, before didActivate)

| property | with the cure | trunk |
|---|---|---|
| fresh | green | green |
| stale 5, 8, 20, 50, 200 ms | GREEN: the clicked window is reported focused, no other window is | red |
| stale 600 ms | RED | red |

The two AX reports are still dropped at the `guard` in `reportFocus(of:)` (they come before even a well-behaved NSWorkspace names the app); the look after didActivate makes up for them, and reads the focused window THEN, so it reports the clicked one.

### Regressions: none found
- Green on the trunk and red with the cure: NONE of 657 checks.
- Reported twice: no. "once" is green at every lag.
- A→B→A within the half second, gaps of 30, 100, 300 ms × lags of 0, 50, 200 ms, both storeys (18 stories): all green with the cure. The last window reported focused is A's, no window is reported twice in a row, at storey two A's window ends in view.
  The look at B is cancelled when A comes forward (`lookAtAppThatCameForward?.cancel()`), and `Task.sleep` ends early on cancel, which the model honours. Three of these are RED ON THE TRUNK (100 ms/50 ms, 300 ms/50 ms, 300 ms/200 ms) and green with the cure.
- The rude walk, 300 seeds × 40 steps each: rule "a window whose app came forward while NSWorkspace still named another is reported focused":
  trunk 158 / 171 / 184 of 300 seeds broken (overtaking / stale answers / all four); WITH THE CURE 0 / 0 / 0. The same set of other rules is broken on both; the cure adds none.

### What the cure does NOT cover (N5 above)
An app that HANGS, or is still marked as silent, at the moment it comes forward is never reported focused, also after it wakes: `reportFocus(of:)` waits out the 1 s timeout on `kAXFocusedWindowAttribute`, says `keyboardFocusMoved`, does not call `noteSilence`
(so nobody asks whether the app is back, and every further ⌘Tab to it costs the main thread another second), and `answersAgain` refreshes windows but reports no focus. 8 of 150 polite seeds. Shortest script: `arborFocuses 96 4; hang 85 52; dies 24 10`
(the app in front quits, the app behind, which hangs, comes forward, then wakes). An app that is busy as it is switched to is an everyday thing. Same on trunk and cure.

### Small print
- The model's order and delays around a switch: didActivate 4 ms after the switch (GUESS), AXApplicationDeactivated +0.6 ms and AXApplicationActivated +8 ms after the notice (SEEN on hosted Macs). The lag itself is the knob.
- On trunk AND cure, a click on another app's window with a FRESH property can report that window focused twice within a millisecond (once for AXMainWindowChanged, once for didActivate, which resets `lastReportedFocus`). Harmless so far as the stories see; not new.
- When it landed, the run failed until 23 lines were deleted from scripts/mac-on-linux/known-failures.txt: that is the arrangement. The 600 ms stories stay listed, with a word that this is the cure's chosen limit. Two entries in `mutants.py` take it out again.

## Has the model been right?

What a model says is worth what has been checked against Macs. So far:

| | |
|---|---|
| **Right, before a Mac showed it** | **L1.** Found on a guess (the window server a moment late, the pointer more than 24 points away: no drag at all, nothing logged). **Since proven on a hosted Mac, with a control.** On the code before the cure, drags in steps of 71, 45 and 29 points were seen 1, 0 and 1 times of 6, in steps of 22, 14 and 7 points 6 of 6 each: the line lies exactly at the 24 points. In the trace the window's first move comes 108 ms after the first dragged event, a quarter of a second after the press. After the cure: 52 of 52. (The traces are to come into the repository.) How it was first seen: Hours later SEEN on a hosted Mac: three of four long drags in coarse steps were never taken for drags, nothing logged; at the first look the pointer was 27 points out and the window still in its place. The stories in coarse steps give the same picture, and the cure, which has landed (a3c0281), was shaped by two verdicts from them |
| **Right, without having been built for it** | **Safari's and Finder's order at a close.** Told only that these apps drop a closing window from their list at once, the real layer on the model says `destroyed` and then `focused` of the sibling, 15 to 20 ms apart: the order, and about the gap, of recordings of hosted Macs (4 to 13 ms, once 91) |
| **Right, afterwards** | **R2**: red at both storeys while it was open, green with 5726225, red again with the cure taken out. **A repeat from nothing** of the verdict on the mended cure by another hand gave the same 61 and 2 |
| **WRONG WHERE IT COUNTED, and corrected by a hosted Mac** | **"What is sent is sent", whether the sender lives or not.** Seen only with the sender alive, written down without that circumstance. Refuted on macOS 26.6.2 (above, under N13). It cost: a finding that was no fault of Arbor's (N13), a verdict on a change under review ("never the first half alone") that rested on it in part, and a cure (word left at a quit) that was green here and did nothing on the Mac. This table used to list N13 under "right, afterwards": the model gave back what had been put into it, which proves nothing |
| **Wrong, and corrected by a recording** | **The order at a minimize.** The model posted "miniaturized" and then the sibling's focus. A recording has the focus 6.6 ms BEFORE, at the end of the flight. Swapped; no story changed its verdict |
| **Wrong, and corrected by a review** | Six delays said more, or other, than the trace they cite (below) |
| **Wrong, and corrected by its own stories and the polite walk** | Always in the same way: ruder, or tidier, than a Mac. The list is in `scripts/mac-on-linux/README.md`; new in round 2: ⌘Tab to an app whose windows are all on another Space did not switch Space; the walk closed "by hand" windows that did not show |
| **Not known** | Everything in the list of probes at the end |

## Corrections from traces and recordings (round 2)

| the model said | the evidence says | now |
|---|---|---|
| echoes 2 to 15 ms after the call | 246 ms in `stubborn-slow`, past the echo filter's blanket of 0.15 s; 0.3 to 0.55 s for Finder and Terminal | a switch on the app; told at 246 and 550 ms, also after Arbor has moved the window on, also docked: all green |
| focus 1 to 4 ms before "deminiaturized" | 4.1 ms (`minimize-restore`), 8.3 ms (`app-minimize`), raw line to raw line | 4 ms |
| eight to ten "moved" a second | gaps of 0.113 to 0.201 s: five to nine, 6.6 on average | the comment; 0.11 s stays as the least gap |
| one kind of app switch | two, both in `app-switch-unreported`: an app brings itself forward (deactivated 0.6 ms, activated 7.8 ms, nothing more); Arbor asks for a window of an app in the background (deactivated 4.5, focused 8.5, main 26.6, focused 34.5, main 41.3, activated 44.3 ms) | both told; the second with NSWorkspace fresh, 5 and 50 ms behind: reported focused once, no other window |
| the screens' notice 15 to 20 ms after "miniaturized" | that is Arbor's own `displaysChanged` of the day: 13.6 to 24.4 ms; the notice is in no trace | the comment |
| windows that go back after 0.05 and 0.4 s | 0.11 s after the call (`stubborn-fast`), 0.474 and 0.196 s (`stubborn-slow`) | told at 0.05, 0.11, 0.2, 0.4, 0.47 s |
| "miniaturized", then the sibling's focus | the focus 6.6 ms before, "main" 5.4 ms after the focus (a recording, `origin/mac-shell-out/sweep.proof`) | swapped, with a check |
| the sibling's focus 12 ms before "destroyed", the closing window valid in between | true of plain AppKit windows (`close`); Safari and Finder drop it at once, the raw "destroyed" after everything | a switch on the app; told both ways |
| a call costs 0.3 ms | with Safari and Finder 100 to 190 ms of the layer's work for one focus report | a switch on the app |
| `frontmostApplication` lags, at ⌘Tab | measured by kind of activation: one a PROGRAM asks for 5 to 107 ms; through LaunchServices 0 of 12; a real click 1 in about 24 (17 ms); a real ⌘Tab 0 of 6 | the README says that the stories call ⌘Tab what a Mac has shown only for programs |
| MARKED AS GUESSES | what is posted when the LAST window with the keyboard is minimized; that a timeout of 0 means the default, and that the default is six seconds (the one measurement gave 1.55 s) | |

## The review of round 1, and what became of it

| finding | what became of it |
|---|---|
| `REF=` copied the checkout's work folder, whose notes name modules by their old place: stories compiled for other types could be linked | builds from nothing in a folder of its own (mended by the reviewer's side); `SOURCES=`, new, likewise |
| a self-test whose list cannot be read passed | fails |
| **`sometimes:` lines and listed rules of the walk excused real regressions, in the walk's own control too** (shown: the cure for native tabs taken out, exit 0) | `sometimes:` counts only with `--seeds`; a listed rule carries its number of seeds, and another number is news; the self-test wants a change to be red AND news. The reviewer's proof is one of its checks, with two more |
| known faults silently shortened the walk | first said (1,195, 1,298 and 969 of 1,600 steps), then cured: the layer is stopped and started at a listed fault and the walk goes on. 1,600 of 1,600 for all six; N9, N10 and N11 came of it |
| arguments that select nothing succeeded | exit code 2; eight checks in the self-test |
| the test's real pid was in the model, where it could meet an app's | `getpid()` → `FakeMac.getpid()`, a fixed number; the apps' pids go on from one Mac to the next |
| paths with spaces; two runs at once; messages naming the wrong folder; an unchecked copy | `-print0`; `flock`; the real folder; checked |
| `retime.py` strict for three folders only | for all of ArborKit, with three listed exceptions. It found one at once: `usleep` in `InstanceLock.swift` |
| one name for two checks in four stories | renamed; two checks of one name in a story are a failure now |
| "two seconds for one hang" tested the sum | per app and per hang; the model counts |
| public names in the stand-ins that Arbor's code could use and a Mac would refuse | `prepare.py` reports them in Sources, Tests and `scripts/mac-shell`; nine probe lines prove it |
| the model against its evidence | the table above |

## New in the tool (round 2)

- `collab/evidence/mac-on-linux/heard.jsonl`: every call of `WindowSystemEvents` the layer made, story by story, and for the walk which kind followed which; for whoever keeps stand-ins at the seam. The run rewrites it when it is out of date, and fails that once.
- Other threads than the main one on the model's clock (`stubs/FakeMacOS/Threads.swift`): real threads that pass one baton; queues, semaphores, groups, the main queue; `AXUIElementCopyMultipleAttributeValues`. For a layer with a lane for each app; the trunk's has none yet.
- Arbor can be gone while the Mac goes on; a message lies in a hung app's queue from the moment it is sent; things can happen at a set time whatever Arbor's main thread is doing.

## One short probe on a hosted Mac for each thing that is not known, ranked by what it costs a person if the model is right

Each is one script for `scripts/mac-shell/run.sh`, a minute or two of a hosted Mac, with a trace recorded. "The test app" is ArborTestWindows; "stopped" means `kill -STOP`, "goes on" `kill -CONT`. N12 needs none: it has been seen. N13 has been refuted.

| | finding | what is not known | the probe | what settles it |
|---|---|---|---|---|
| 1 | **N9** | nothing but the whole, end to end | stop the test app; start Arbor; wait 60 s, timing `arborctl status` once a second; the app goes on; wait 30 s; `arborctl windows` | answers that took over a second, and how many; whether the app's window is in the list |
| 2 | **N6** | whether an app's list is behind when "created" of a new tab arrives | dock a window of Finder, of Safari, of TextEdit; ⌘T ten times each, 2 s apart; then ⌘W ten times | in the trace: one `appeared` where `replaced` belongs, or one `destroyed` of the group, confirms |
| 3 | **N14** | nothing but the whole | the test app sleeps 0.8 s on its main thread; `arborctl focus` its window; 0.2 s later a third app is brought forward; wait 2 s | which app is in front |
| 4 | **N5** | the same | a window of the test app out of view; stop the app; bring it forward; it goes on after 2 s; wait 3 s | whether a `focused` line comes, and the window into view |
| 5 | **N11** | the same | the test app sets its window's frame and sleeps 5 s in the same turn of its run loop; wait 10 s | `arborctl state` against the window server's bounds |
| 6 | **N7** | whether `_AXUIElementGetWindow` waits for a hung app | get a window's element; stop the app; time one call | 1 s, or at once (four seconds dead, or three) |
| 7 | **L3, L4, L2** | how late a mouse-down reaches the monitor on a loaded Mac | `make e2e-drag` with every core busy, logging the event's own time stamp against the uptime in `handleMouse` | the distribution; L3 needs a quarter of a second, L4 as long as the hand takes to carry the window 32 points |
| 8 | **N4** | what a window on its way into full screen does with a frame it is given | the test app's window enters full screen; 100 ms later set its position and size | where it ends; whether it ends in full screen at all |
| 9 | **N3** | the order of "focused window changed" and `activeSpaceDidChange` | two windows of one app at the same frame on two Spaces; switch ten times | the order of the two raw lines |
| 10 | **N10** | both halves together | close Notes' window; start Arbor; show the window again from the Dock | `found` or `appeared` |
| 11 | **N16** | whether apps say yes and move later, which, and by how much | the test app and Safari, Finder, Terminal, TextEdit: set a position and a size, read the frame back at once and every 10 ms for half a second | the first reading that has the new frame |
| 11 | **N1** | how often "destroyed" never comes | no Mac: read the recordings there are for windows that left the window server's list without a raw "destroyed" within 5 s | a rate |
| 12 | L1 | why a dragged window can end a step further than the pointer travelled (seen once) | one drag in 30 coarse steps, logging the window server's bounds and the pointer at every `leftMouseDragged` | ahead at every look, or only at the end |
| 13 | the walk's one line that rests on a guess | whether `AXFocusedWindow` names a window on another Space | an app in front with its one window; switch to an empty Space; read the attribute | a window, or none |
| 14 | the model | what is posted when the LAST window with the keyboard is minimized | the test app in front with one window; minimize it | the raw lines of the next second |
| 15 | the model | the default timeout; what 0 means | in a process that has set no timeout: stop the app; time a read; set 0 on the element; time another | 6 s, 1.55 s, or something else |
