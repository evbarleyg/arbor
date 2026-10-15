# Report: the real Accessibility layer, run on Linux on a model of a rude Mac

- Date: 2026-10-15
- Branch: test/the-real-ax-layer-on-linux, then test/mac-on-linux-round-2
- What: `make mac-on-linux` (scripts/mac-on-linux/README.md; docs/TESTING.md, section 9)

`Sources/ArborKit/AX` ran in no headless test. Now it is compiled as it is, linked with a model of a Mac and run on Linux: 279 stories (1,083 ✔, 80 ✘ known, on the trunk at 4091c0f; 181 stories at the end of round 1) and a random walk under four kinds of bad manners, seven seconds to run. The run enters 92 % of the lines and 81 % of
the regions of `AXWindowSystem.swift` (`COVERAGE=1`). Twenty-three changes that take known cures out of a copy of the layer all turn their stories red (`make mac-on-linux-selftest`).

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
| N13 | **a window goes out of view seconds AFTER Arbor is gone** | a hang in the middle of a move out of view, a quit meanwhile | seen on a hosted Mac |
| N14 | Arbor's request for the keyboard, held up by a slow app, takes the keyboard away from where the person has gone meanwhile | an app busy for less than the timeout | the layer's own logic |
| N15 | a command answers after 3.3 s because one app is slow | an app that takes 0.1 s over a call | the layer's own logic; slow answers seen |
| L1 | **a drag of any length is not seen at all; nothing is logged** | the window server a moment late, the pointer more than 24 points away | found on a guess; **since SEEN on a hosted Mac**: three of four drags of 1,244 to 1,991 points in 30 steps never taken for drags, nothing logged. **CURED by a3c0281**, which was held against the stories twice before it was published: 61 listed lines deleted, 2 listed anew (what its author names as left), red again with the cure taken out |
| L2 | a flick is not seen | the gesture over before Arbor hears of the press | the layer's own logic |
| L3 | **(new with 37d0f05) a drag of a second is not seen** | the press heard half a second late | the layer's own logic; a regression. **531885f meant to cure it, does not, and loses two drags more** (L4) |
| L4 | **(new with 531885f) a drag of a second is not seen** | Arbor's main thread busy for 0.3 s from the press | the layer's own logic; a regression; shown by two changes, one at a time |

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
| **N13** an app hangs for 8 s at the first setting call, or at the reading back, of a move out of view; Arbor is quit meanwhile | **"AXPosition = 1023,767" is carried out when the app wakes, 7 s after Arbor is gone** |
| … it hangs at the very beginning of that move | nothing was sent: all in view |
| Arbor is paused 0, 0.3, 1 s after such a hang | taken within 4 s; windows back within 10 s of the wake |
| **N14** ⌘Tab away while Arbor's request for the keyboard waits 0.8 s for a slow app | **the keyboard, and the ring, are taken from where the person went** |
| **N15** an app takes 0.7 s over every move, one window refusing its slot's width | **`arrange` answers after 3.3 s**; in the end no window lies over another, and Arbor has done with them |
| an app wakes after 0.7 s in the middle of a move; Arbor's main queue on time, or 20 ms late | right places, no further pulling |
| the app opens a window, resizes a docked one, gets a new tab 5 ms after it wakes | known, in view, right size, the tab in its place |
| a window is moved by hand while Arbor moves its slow app's sibling (storey one) | told apart |

WHAT A PERSON SEES, N12 and N13: quit Arbor while an app beachballs, and windows of that app are gone from the screen with nothing left running that could fetch them: the one thing a window manager must not do. N13 is the meaner: everything is in view when Arbor quits.
WHY: N12: `setFrame` gives an app up at the first call that goes unanswered, and `stop()` leaves no word for it. N13: a call that timed out lies in the app's queue and is carried out on waking; nothing is sent after it to undo it. N14: `focus` 303: `setBool(kAXMainAttribute)` (307) waits for the app on the main thread; if the app
answers within the second, 316-318 go on to raise and activate without asking whether another app has come forward since `began`; `activations`, which 324 reads for the opposite purpose, would tell. N15: every call of every move is waited for on the main thread, one after the other.
HOW SURE: N12 and N13 SEEN on a hosted Mac (traces of a hang at a quit, at a pause, while the view moves: a park is carried out on waking as well as a fetch). N14, N15: the layer's own logic; that big apps answer slowly is seen (100 to 190 ms of the layer's work for one focus report with Safari and Finder).
TO CONSIDER: N12, N13: at `stop()`, send the fetch to every window that is or may be out of view, with a short timeout and without waiting for an answer: what lies in the queue last wins. N14: after 307, `guard activations == before`. N15: the lanes.

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
SEEN: the layer's code paths above run unmodified; `WindowGrab` is the real one. The traces' pointer steps and rests. GUESS: that a loaded window server starts late and then catches up with the pointer in one jump (modelled so); how the run loop orders a backlog (all three orders played; no difference).
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
| **Right, before a Mac showed it** | **L1.** Found on a guess (the window server a moment late, the pointer more than 24 points away: no drag at all, nothing logged). Hours later SEEN on a hosted Mac: three of four long drags in coarse steps were never taken for drags, nothing logged; at the first look the pointer was 27 points out and the window still in its place. The stories in coarse steps give the same picture, and the cure, which has landed (a3c0281), was shaped by two verdicts from them |
| **Right, without having been built for it** | **Safari's and Finder's order at a close.** Told only that these apps drop a closing window from their list at once, the real layer on the model says `destroyed` and then `focused` of the sibling, 15 to 20 ms apart: the order, and about the gap, of recordings of hosted Macs (4 to 13 ms, once 91) |
| **Right, afterwards** | **R2**: red at both storeys while it was open, green with 5726225, red again with the cure taken out. **N13**: the park carried out after Arbor is gone, measured on a hosted Mac, comes out of the model as told: "AXPosition = 1023,767", 7 s after the quit. **A repeat from nothing** of the verdict on the mended cure by another hand gave the same 61 and 2 |
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

Each is one script for `scripts/mac-shell/run.sh`, a minute or two of a hosted Mac, with a trace recorded. "The test app" is ArborTestWindows; "stopped" means `kill -STOP`, "goes on" `kill -CONT`. N12 and N13 need none: they have been seen.

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
| 11 | **N1** | how often "destroyed" never comes | no Mac: read the recordings there are for windows that left the window server's list without a raw "destroyed" within 5 s | a rate |
| 12 | L1 | why a dragged window can end a step further than the pointer travelled (seen once) | one drag in 30 coarse steps, logging the window server's bounds and the pointer at every `leftMouseDragged` | ahead at every look, or only at the end |
| 13 | the walk's one line that rests on a guess | whether `AXFocusedWindow` names a window on another Space | an app in front with its one window; switch to an empty Space; read the attribute | a window, or none |
| 14 | the model | what is posted when the LAST window with the keyboard is minimized | the test app in front with one window; minimize it | the raw lines of the next second |
| 15 | the model | the default timeout; what 0 means | in a process that has set no timeout: stop the app; time a read; set 0 on the element; time another | 6 s, 1.55 s, or something else |
