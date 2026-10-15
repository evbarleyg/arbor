# The real Accessibility layer, run on Linux

Thousands of headless tests run the controller against stand-ins for the protocol `WindowSystem`. The real implementation, `Sources/ArborKit/AX`, ran in none of them, and that is where two of the
three faults lay that the first day on hosted Macs showed: an app reported "the focus is on it" a millisecond before "it was created"; and `didActivateApplication` arrived while
`NSWorkspace.shared.frontmostApplication` still named the old app. No stand-in at the seam can catch that class. This folder compiles the layer **as it is**, links it with a model of a Mac, and runs it.

```bash
make mac-on-linux                                   # build what has changed, tell every story, walk a short walk. 5 s to run; see "How long"
make mac-on-linux ARGS="--only tab --verbose"       # the stories whose names contain "tab", with everything that happened on the Mac
make mac-on-linux ARGS="--only walk --seeds 1-500"  # a hunt
make mac-on-linux ARGS="--help"
make mac-on-linux-selftest                          # does the net hold? takes known cures out of the copy; the stories about them must go red. 3 minutes
REF=origin/fix/some-cure make mac-on-linux          # that commit's Sources, with this checkout's stand-ins, scripts and stories
COVERAGE=1 make mac-on-linux                        # afterwards: how much of each file of the layer was entered, and which lines were not
```

On Linux only (in the container CI uses: `make linux` has the image). It works in `.build/mac-on-linux`, so nothing in the checkout changes.

## What runs

| | |
|---|---|
| Unchanged | `Sources/ArborKit/AX` (all of it), `Controller`, `Platform`, `Support`, `Trace`, `App/FrontmostAppWatcher.swift`, `App/ArborEnvironment.swift`, `App/MacFacts.swift`; `ArborCore`, `ArborIPC`, `ArborTesting` |
| Rewritten in a copy, line for line | What `scripts/typecheck-mac/prepare.py` does for any Linux compiler (`@objc`, `#if os(macOS)`…), and by `retime.py`: `Task.sleep` → `FakeMac.sleep`, `ProcessInfo.processInfo.systemUptime` → `FakeMac.uptime`, `DispatchTime` → `FakeDispatchTime`, `….operatingSystemVersion` → `FakeMac.operatingSystemVersion` (macOS 26.6), `kill(` → `FakeMac.kill(`, `getpid()` → `FakeMac.getpid()` (a fixed number: the test's own could be one of the model's apps'), `UserDefaults(suiteName:` → `FakeMac.defaults(suiteName:` (what the person has set in System Settings: macOS's own tiling is on, as a Mac comes, unless a story switches it off); and in the layer, for threads of its own, `DispatchQueue(label:)`, `DispatchSemaphore`, `DispatchGroup` and `DispatchQueue.main.async` → the model's |
| In place of Apple's frameworks | The stand-ins of `scripts/typecheck-mac/stubs`. The functions the layer calls have bodies that ask the model, `stubs/FakeMacOS`; the rest still does nothing |
| Left out | `UI`, `Input`, the rest of `App`: their stand-ins do nothing, so running them would show nothing |

**Storey one** (`tests/StoreyOne.swift`): `AXWindowSystem` alone, with a listener that writes down the `WindowSystemEvents` it emits. **Storey two** (`tests/StoreyTwo.swift`): the real `Controller` on it, wired as `ArborApp` wires them, with the
app's own `MainQueueScheduler` and `FrontmostAppWatcher`; only what draws (`FakeOverlays`) and what writes to disk (`MemoryStateStore`) are fakes. Its checks look at the Mac's screen: where the windows are.

**Time** is the model's. A story says `mac.pass(0.3)` and whatever falls due is delivered in order, with no real waiting. A call to an app that hangs moves the clock by the whole messaging timeout, and what fell due meanwhile is
delivered afterwards, as to a busy main thread. After each delivery Arbor's tasks run until none is runnable (`stubs/FakeMacOS/Pump.swift`): jobs for the main actor are taken from libdispatch's main queue the way CoreFoundation's run loop takes them; jobs for the
global pool (`Task.detached`) are caught by the runtime's hook and run on the same thread, marked as being off the main one. Everything is a function of the story: no thread, no clock, no chance. The program checks at its start that the pump
works with this toolchain and refuses to go on if not. `retime.py` fails the build if anything in ArborKit waits or tells the time in a way it does not know (`asyncAfter`, `Timer`, `Date()`, `usleep`…): such code would stand still while the model's time passes. The three places that may are listed there, each with its reason.

**Other threads** than the main one (`stubs/FakeMacOS/Threads.swift`) are real threads that pass ONE BATON: a queue's thread runs only while it holds it, and gives it back when its block is done or when it waits for an app, which takes the model's time. So a call on a queue to an app that hangs takes a second during which the main thread, the other
queues and the Mac go on, and still every run is the same. While the main thread waits (on a semaphore, a group, or in a call of its own to an app that hangs) nothing is delivered to it; it is served afterwards. The trunk's layer has no such threads yet; the program proves at its start that they work.

## Has it been right?

A model is worth what it foretells. So far (2026-10-15):

- **The first fault** (focus reported before creation), cured before this existed: green, and with the cure taken out of the copy the layer reports `found w102, focused w102`, which is the fault as the hosted Macs showed it.
- **The second** (`frontmostApplication` lags the notice) was open when this was built, and came out red at both storeys, down to the place where the window lay on the hosted Mac: 1023,673. The cure (5726225) was held against the stories with `REF=` before it landed: green at lags of 5 to 200 ms, red at 600 (it looks for half a
  second), no check that was green went red, the walk's rule from 158, 171 and 184 of 300 seeds to none. When it landed, the run demanded that 23 lines be deleted from `known-failures.txt`.
- **A drag of any length that is never seen** (the window server a moment late, the pointer more than 24 points from the press, nothing logged) was found here on a guess about loaded Macs, and **has since been proven on a hosted Mac, with a control**. On the code before the cure, drags in steps of 71, 45 and 29 points were seen 1, 0 and 1 times of 6, in steps of 22, 14 and 7 points 6 of 6 each: the line lies exactly at the 24 points. In the trace the window's first move comes 108 ms after the first dragged event, a quarter of a second after the press. After the cure: 52 of 52. First it had been seen independently: three of four drags of 1,244 to 1,991 points in 30 steps were never taken for
  drags, and nothing was logged.
- **A regression** came to light at the rebase that brought another cure in: since 37d0f05 a press has the place where it happened, while the window under it is looked for in the window server's list of the moment it is served. Not seen on a Mac yet.
- **An order it was not built for.** Told only that Safari and Finder drop a closing window from their list at once, the real layer on the model says `destroyed` and then `focused`, 15 to 20 ms apart: the order, and about the gap, of the recordings (4 to 13 ms, once 91).
- A review held its delays against the traces it cites and found six that said more, or other, than the trace; a recording settled one guess the other way round (at a minimize the next window's focus comes BEFORE "miniaturized"). All corrected on 2026-10-15; no story changed its verdict.
- **WRONG ONCE WHERE IT COUNTED.** The model held that what Arbor has sent to an app that hangs is sent, whether Arbor lives or not. That was an inference, written down as seen: hosted Macs had shown calls that timed out carried out on waking, a park
  as well as a fetch, but always with Arbor alive. On 2026-10-15 a hosted Mac (macOS 26.6.2, `scripts/mac-shell/check-hang.sh`, session 2) refuted it: a place and a size left for each of two windows, Arbor's process gone half a second later, the app awake 18 s
  after that, both windows where they had been, place and size. **macOS drops what a process has asked once that process is dead.** Two things rested on the error and were the model's own, not Arbor's: finding N13 at a quit (a park that waits in the queue
  takes a window away after Arbor is gone), and a verdict on a change under review ("never the first half alone: it sends a park where the trunk sends nothing, and at a quit nobody fetches the window"). A cure was built on it too (word left at a quit),
  came out green here, and did nothing on the Mac. The lesson is in the table below: what is SEEN says under which circumstances it was seen, and a circumstance that was never varied (here: is the sender alive?) is a guess.
- It has been **wrong** as well, always in the same way: the model was ruder, or tidier, than a Mac, and a story or the polite walk said so. "Moved" reports whose last one was swallowed; tabs that kept their own size; a helper window that took the keyboard; ⌘T 50 ms after a drag. Hence the polite control, and the habit of reading the account of a
  green story once.

## What is modelled, and on what evidence

`stubs/FakeMacOS`, 1,850 lines. Every delay and every order of reports there says where it was seen; **"Guess" marks what nobody has measured** (`grep -n -i guess scripts/typecheck-mac/stubs/FakeMacOS`).

| | Seen (trace in `collab/evidence/traces`, or the place it is written down) | Guess |
|---|---|---|
| Opening | "focused" a millisecond before "created" in a running app; subrole a moment late; tooltips and helpers reported created; apps refuse observers while launching; one-window apps show the same number again | What the subrole is before it comes; that a refusal is `cannotComplete`, at once |
| Closing, quitting | Plain AppKit windows: focus of the next window 12 ms before "destroyed", the closing one still valid in between (`close`). Safari and Finder: off the list and invalid by the focus report, the raw "destroyed" after everything, so that the layer says `destroyed` before `focused` (recordings on `origin/mac-shell-out/*`; a switch on the app, both ways told); no "destroyed" at a quit (`app-quits`); an end nobody reports, calls then fail at once; a window that closes without a notice | What a closed window answers to a *set*; how long after "destroyed" comes in Safari (0.2 s here) |
| Coming forward | Two kinds, both in `app-switch-unreported`. An app brings itself forward, its focused window unchanged: `didActivate`, "deactivated" 0.6 ms later, "activated" 7.8 ms later, nothing more. Arbor asks for a window of an app in the background: "deactivated" 4.5 ms, "focused" 8.5, "main" 26.6, "focused" again 34.5, "main" again 41.3, "activated" 44.3 ms after the notice. `frontmostApplication` still naming the old app: **measured by kind of activation**: one a PROGRAM asks for 5 to 107 ms behind; through LaunchServices 0 of 12; a real click 1 in about 24 (17 ms); a real ⌘Tab 0 of 6 | 4 ms from the switch to the notice. The lag is a knob; stories play 5 to 600 ms, and call it ⌘Tab where a Mac has shown it only for programs |
| Minimize, hide | 0.55 s; at the end of the flight the next window's focus 6.6 ms BEFORE "miniaturized" (a recording, `origin/mac-shell-out/sweep.proof`); 2 points of visible frame, and Arbor's own `displaysChanged` of the day 13.6 to 24.4 ms after; focus 4.1 and 8.3 ms before "deminiaturized"; AXDialog for every minimized or hidden window; unhiding brings windows back (`minimize-restore`, `app-minimize`, `hide-unhide`) | When the screens' notice itself comes (in no trace); what is posted when the LAST window with the keyboard is minimized (nothing, here); which windows count as nearly off screen |
| Spaces, full screen | The notice in mid-transition, apps listing neither old nor new windows; two AXUnknown helpers; "resized" before `AXFullScreen` says yes | The lengths; **in which order the focus report and the notice come** (both are played) |
| Native tabs | Only the front tab is listed; a new tab is a new window; choosing posts only "main window changed"; successor first; Terminal's 31 points | |
| Frames | Whole points, which way halves go; the title bar stays above the Dock; minimum sizes; a report for each call that changed something (recorded under size, position, size); echoes 2 to 15 ms later as a rule, 246 ms in `stubborn-slow`, 0.3 to 0.55 s for Finder and Terminal (told at 246 and 550 ms); windows that go back, 0.11 s after the call in `stubborn-fast`, 0.474 and 0.196 s in `stubborn-slow` (told at 0.05 to 0.47 s) (`*-commands`, `stubborn-*`) | How "enhanced user interface" animates |
| Hanging | Every call waits the timeout (1.06 s on the main thread of a hosted Mac); the system-wide element's timeout covers every element, and a window's element does not go by its app's (`docs/features/F17`, H3); calls that timed out, after 1 s or after 0.1 s, are carried out on waking, a park as well as a fetch, WHILE ARBOR'S PROCESS LIVES; once it has ended they are dropped (0.1 s calls, `check-hang.sh` sessions 2 and 3 on macOS 26.6.2) | That `_AXUIElementGetWindow` waits like any call. That calls with the timeout of 1 s are dropped with their sender like those of 0.1 s. **That a call the app is in the middle of when its sender ends is carried out** (a switch). That a key waits in the queue of an app that hangs like a call. **That 0 means the default, and that the default is six seconds**: Apple's header; the one measurement, of window elements without a timeout of their own, gave 1.55 s |
| The mouse | The window server moves a dragged window at once, the app hears 0.1 s later, five to nine "moved" a second (0.113 to 0.201 s apart, 6.6 on average) or none; mouse-up twice; monitors deaf to Arbor's own panels; releases that are swallowed (`drag-to-edge`, `flick-to-edge`, `click-title-bar`); an event has the place where it happened, however late it is served | 1 ms to a monitor; that a window server that starts late (SEEN: about 0.1 s after the first dragged event on a hosted Mac) catches up in one jump |
| The desktop shown | The window server lists every window at the side of its display, with the size it had; Accessibility has it where it is, and no "moved" is posted; a frame set meanwhile is taken and shows nowhere; a press on a strip brings all back 27 ms after the button went down, and macOS keeps the click (`collab/reports/2026-10-14-the-desktop-is-shown.md`) | Where along the edge a window waits. Only the key and a press on a strip are played |
| The window server | What a Mac at rest lists, at which levels, not sorted by level; `kCGWindowIsOnscreen` only for what shows; no list at all; a system alert of another process, at the level of modal panels, over a title bar | |
| macOS's own tiling | The zones, one point deep: x 0 and x 1023 without waiting, the menu bar (y 0 to 30) after 0.2 s of rest and not after 0.1; the left half at -1,31 512×674, the whole screen at 0,31 1024×674; the first step 7 ms after the release, 17 to 19 steps 16 ms apart, easing out; from where the window was let go, whatever has become of it since; "resized" only while the size changes; the three switches (`Sources/ArborCore/MacTiling.swift`; `docs/REALITY.md`, the cases that begin with macos-til) | Where the quarters begin (60 and 740); 0.15 s of rest; the right half and the quarters by symmetry. NOT MODELLED: ⌥ held (seen both ways); the old size that comes back in the hand |
| How long Arbor's own work takes | 2 ms for a `setFrame` of six or seven calls (`took` in the traces); with Safari and Finder 100 to 190 ms for one focus report (a knob on the app) | |

**What is NOT modelled, plainly.** Event taps, hot keys, gestures, the menu bar, panels, drawing, Screen Recording: nothing of `Input` and `UI`. Sheets and drawers. Stage Manager, Mission Control, "Displays have separate Spaces", macOS's own tiling. Several Spaces showing at once on several displays. Apps that are
really odd (Electron, Java, X11). Sleep, lock, fast user switching. A call from another thread to an app that hangs fails at once instead of waiting (one clock cannot wait in two places), so Arbor's "are you back?" comes every 0.5 s here and every 1.5 s on a Mac. `launchApp` and
`openApplication` are not run. And the great caveat: **the model does what we have seen or guessed. A green story proves the layer right about that, not about a Mac.** A red one is worth a run on a hosted Mac if it rests on a guess; the findings say which do.

`COVERAGE=1` on 2026-10-15: the run enters 92 % of the lines and 81 % of the regions of `AXWindowSystem.swift`. Not entered: dialogs that wait while the view is held (F58), `raise`, the raw lines of a trace being recorded, a tab dragged out of its group, an observer that cannot be made or is given up
on, the permission lost between two steps of one move, `setFrameOnce`'s long way round.

## Stories

`tests/*.swift`, plain Swift with ✔ and ✘ as in `Sources/arbor-e2e`. Each is told politely first and then with the rudeness that was seen. Each check says what a person would see, or what Arbor must have understood for them to see it.

```swift
book.story("a window closes") { story in
  var first: FakeMac.Window!, second: FakeMac.Window!
  let one = StoreyOne(story) { mac in                 // the Mac as it is when Arbor starts
    let app = mac.launch("Notes")
    first = mac.open("first", in: app)
    second = mac.open("second", in: app)
  }
  one.mac.close(second)                               // what happens: Apps.swift, Windows.swift, Mouse.swift
  one.mac.pass(1)
  story.check("the app's next window is reported focused, then the window is reported gone",
    one.heard.outline == [.focused(first.number), .destroyed(second.number)], one.heard.texts)
}
```

**To add one:** put it in the file of its theme (or a new file, with its `tellOf…(book)` called in `main.swift`). Rudeness is a switch on the app, the window or the Mac (`app.reportsFocusBeforeCreated`, `app.listLagsBy`, `mac.frontmostLagsNoticeBy`, `mac.arborIsBusy(for:then:)`…); if the manners you need are not there, add a switch
to the model, off by default, with a comment that says where it was seen. A story that fails prints what happened on the Mac and what the layer made of it, with the times; `--verbose` prints that for the ones that pass. **Read it once even when the story is green**: several passed at first for the wrong reason.
Then take the cure the story is about out of the layer, see it go red, and keep that as an entry in `mutants.py`.

## Known failures

`known-failures.txt` lists the checks that are red on the trunk, each with a word on it. **The run fails when a check that is not listed fails, and when one that is listed passes**, so whoever lands a cure deletes its lines in the same pull request; and when a line matches no check any more, and when two checks of a story have
one name. The list excuses what it was written for and nothing else. A rule of the walk is listed with the number of the usual seeds that break it, `[8 of 40 seeds]`: another number is news. `sometimes: ` marks what only other seeds (`--seeds`) show; with the usual ones, where every run is the same, it excuses nothing.
Where a listed fault has spoilt the layer's picture of the Mac, whatever broke next might follow from it; there the walk stops and starts the layer, as a pause does, and goes on. (It used to end there, and known faults made the net smaller: 969 of 1,600 steps under all four.) The run says how many steps each kind of manners
took and how often it started afresh. Going on found three faults at once that no walk had reached: of a start while an app hangs, of a window put away before the start, and of a move that a hang swallows.

## The walk upstairs

The same walk at storey two (`tests/WalkUpstairs.swift`): the real controller on top, and among the steps what a person asks of Arbor (dock, float, arrange, zoom, out, in, back, show-all, focus, pause, resume) and a quit with a new start on the same Mac and the same saved state. The rules look at the model's SCREEN, as a person does, and hold it
against what the controller says it has in view and out of view: every window that shows is known, and where Arbor believes it; a docked window in view is in its place, and no two lie over each other; nothing is out of view that Arbor has in view, nor the other way round; with the Desktop in view so is every floating window; no place is kept
for a window that has closed; the window with the keyboard is in view, with the ring around it; a floating window stays where it is while something else happens and the arrangement stays as it is; paused or quit, everything is in view; Arbor comes to rest within five seconds. They are asked when Arbor has come to rest.

Two kinds of manners: the polite control and all four at once; which kind does what is for storey one to tell. What a hang does is known, and goes by names of its own (", though an app has hung"), so that it hides nothing else. Ten seeds by default; `--only upstairs --seeds 1-400` for a hunt, a minute. A replay (`--replay 'upstairs, polite|95|arrange 48 51;
drag 27 48'`) prints the controller's own drawing of the arrangement, and where the windows are on the screen, wherever a rule breaks. What it found on a polite Mac is told as stories in `tests/FoundUpstairs.swift`, each with the lines that show the same in `arbor-sim`.

To make a script short takes most of a run's time, so a rule that is listed and breaks in as many seeds as listed is not shrunk; news is, and everything with `--verbose`.

## What was heard

A run of everything writes down every call of `WindowSystemEvents` the layer made, story by story, and for the walk which kind followed which: `collab/evidence/mac-on-linux/heard.jsonl`, with a README. It is for those who keep stand-ins at the seam, and it shows in a diff what a change to the layer does to what the controller
hears. If the reports in the file are out of date the run rewrites it and fails that once: look at the difference and commit it. For other milliseconds, which every change to the controller's timing brings, and for other reports at storey two, which every change to what the controller asks for brings, it is left as it is, with a line that says so: whoever touches the layer refreshes it (delete it and run again).

## Does the net hold? (`make mac-on-linux-selftest`)

A story that stays green without the cure it is about proves nothing. `mutants.py` has thirty-four small changes to the copy, each of which takes one cure out of the layer again (the count of windows that tells a new one from a found one, the looks at an app macOS does not name in front yet, the watch for a lost release, the second reading of the lists after a Space switch, the
look at the window server during a drag…), and names the checks that must go red, **and be news: one that the list of known failures excuses does not count**. Only the changed file is compiled again: eight seconds each. Before that it holds the program to its own book-keeping: arguments that select nothing or cannot be read
(`--only zzzzz`, `--seeds 3-x`, `--steps 0`, a `--replay` with a step it does not know) are refused with exit code 2, and a listed line with another number of seeds, or with `sometimes: `, excuses nothing. A change that no longer fits the sources is reported: write it anew, or delete it with its story.

## The rude walk (`tests/Walk.swift`)

A seeded random walk (`ChaosRandom`) over what people and apps do: launch, quit, die, open, dialog, close, put away, reopen, click, ⌘Tab, minimize, restore, hide, move, rename, drag, lose the release, resize, hang, wake, switch Space, new tab, choose a tab; and what Arbor asks: a frame, the keyboard, the Dock. Two acts of
one pair of hands are a quarter of a second apart; what happens by itself may coincide with anything. It is walked under **four kinds of bad manners in general**, each alone and all together, and once politely:

| | |
|---|---|
| polite | **The control.** A rule that breaks here is a wrong rule, a wrong model, or a fault that needs no rudeness |
| overtaking | What is on its way from different sources (each app's observer, NSWorkspace, its cache, the monitors) is held up by up to 20 ms, so that they overtake each other. One source keeps its order |
| stale answers | A cached answer (`frontmostApplication`, an app's list of windows, `pressedMouseButtons`) lags a change by up to 60 ms, half the time; in a Space transition apps may list nothing |
| twice or never | Any notification may come twice; those macOS is known to drop ("destroyed", "moved" in a drag, mouse-up, the notice of an end) may be dropped |
| late calls | A call may be carried out up to 80 ms after it returned |

After each step two seconds pass in which Arbor's main thread was not held up, and the rules are checked (`Rule` in `Walk.swift`): Arbor knows every standard window that shows, and none that has closed, with the right flags and frames; every window is announced once, as new if it has just opened; none is reported gone
that is open; nothing is reported about a stranger; the last word on the keyboard is right, and whoever got the keyboard was reported focused; no drag or resize is left open with the button up; the main thread waits at most two seconds for one hang of one app. Each kind of manners is a story and each rule a check: it holds if no
seed breaks it. A breach prints how many seeds show it and the shortest script that deleting steps gives:

```
✘ a window whose app hung as it came forward is reported focused once the app wakes  (8 of 150 seeds; first seed 3: w103 has it; the last to be reported focused is w101
    --replay 'polite|3|arborFocuses 96 4; hang 85 52; dies 24 10')
```

`make mac-on-linux ARGS="--replay 'polite|3|…'"` plays that script with everything that happened. **A fault that is known gets a rule of its own wherever the model can tell it apart** (it knows when a notice outran the property, when "destroyed" was dropped, when an app hung in front), so that it hides nothing else. After a
breach that leaves the layer's picture of the Mac wrong, the walk ends: what breaks next may follow from it.

### What the walk has found

On 2026-10-15, besides the two faults it was built to reproduce (both cured since; each red again without its cure): an app that is busy as it is switched to is never reported focused, on a polite Mac; "whoever posts a notification is awake" costs a second for each notification that was on its way; native tabs go wrong in two ways if the app's list is 10 ms behind. Each has stories of its own
now, and lines in `known-failures.txt` that say which lines of the layer are concerned. Duplicates, a second mouse-up, dropped "moved", swallowed releases and late calls found nothing in 400 seeds.

## How long

| | |
|---|---|
| Nothing changed | 4 s to find that out, 5 s to run |
| A story, or a file of the layer | 10 to 15 s |
| A stand-in or the model (everything is compiled again) | 45 to 80 s on four cores |
| From nothing | 2 minutes |
| The self-test | 3 minutes |
| 400 seeds of the walk | 1 minute |

`REF=` and `SOURCES=` build in a work folder of their own, from nothing the first time (2 minutes). A second run in the same work folder waits for the first. The stand-ins are compiled whole, with a stamp as in `check.sh`. Arbor's modules and the stories are compiled incrementally, as `swift build` does it: the copy is brought up to date file by file, touching only those whose text differs.

## When it breaks

- **"goes by the machine's clock"**: the layer waits in a new way. Teach `retime.py`.
- **An undefined symbol at the link, or a call that always fails**: the layer calls something of Apple's whose stand-in still does nothing. Give it a body that asks the model, and keep the declaration as it is: `make typecheck-mac` and `make typecheck-mac-selftest` use the same files.
- **"the pump does not work with this toolchain"**: the runtime queues jobs some other way than through `swift_task_enqueueGlobal_hook` and libdispatch's main queue. `Pump.swift` is 70 lines.
- **A new member of `WindowSystemEvents`**: `Listener` in `tests/StoreyOne.swift`, `Probe` in `tests/Dragging.swift`.
