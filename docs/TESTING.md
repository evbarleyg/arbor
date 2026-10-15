# Testing

Arbor is tested at five levels, numbered below. The first three need no
permissions and run anywhere, including CI, agents' sandboxes and Linux:
nothing above the platform protocols needs macOS (see "Executors without a
Mac" in `collab/README.md`). The last two need a Mac with Accessibility
permission, which GitHub's runners have. What each level can and cannot
prove, counted test by test, is in [CENSUS.md](CENSUS.md).

**What the stand-ins get wrong, and what to do when a Mac surprises you:** `docs/REALITY.md`. It lists every known case where real macOS
differed from the fakes or from what a test expected, with the switch that plays it by now and the test, trace or real-window step that
guards it. A green run at the first three levels proves Arbor right in the world the stand-ins make up, and that page says how far that
world is from a Mac. New cases go into `collab/reality.json`; `scripts/reality-ledger.py` looks every name up and writes the page, and
`make lint` fails when a name is gone or the page is stale. If that happens to you because you renamed a test or reworded a step, the line
under each ✘ says which field of which case to change, and to what.

## 1. Core unit tests (`Tests/ArborCoreTests`)

Pure functions over value types: tree operations (including a seeded random
test that checks the invariants after thousands of operations), layout
geometry, navigation, drop targets, workspace history, command parsing,
settings decoding, key chords, per-app rules, the pinch and rectangle state
machines, and the `CGRect` behaviour that macOS and Linux must share.

## 2. Scenario tests (`Tests/ArborKitTests`)

The real `Controller` wired to fakes through `Harness`:

```swift
@Test func zoomParksTheOthers() {
  let h = Harness()
  let a = h.system.open(app: "Safari")
  let b = h.system.open(app: "Notes")
  h.start()
  h.run("dock \(a.rawValue) left")
  h.run("dock \(b.rawValue) right")
  h.run("zoom \(a.rawValue)")
  #expect(h.frame(a) == h.visibleFrame.insetBy(dx: 12, dy: 12))
  #expect(!h.system.isVisible(b))
}
```

`FakeWindowSystem` behaves like macOS where it matters: windows refuse sizes
below their `minimumSize`, and the simulation helpers (`open`, `close`,
`setMinimized`, `setHidden`, `setOnActiveSpace`, `userMove`, `userFocus`, `drag`, `setDisplays`)
emit the same events the Accessibility layer does (`userSwitchesApp` and `userFocusesNothing` move the
keyboard the ways that send no `windowFocused`; `focus`, which the controller calls, reports the move as macOS does).
`grab`, `carry` and `letGo` drag in pieces; `setBehaviour` makes an app refuse to move, snap back or round its size; with
`holdsEchoes` on, echoes wait for `appsReact()` (`FakeWindowSystem+Chaos.swift`).
`ManualScheduler` holds debounced work (saves, enforcement) until
`runPending()`, which runs all of it, or `advance(by:)`, which moves the clock
(and `controller.now()`) and runs only what has fallen due. `FakeOverlays`
records tiles, seams and drop previews and can click tiles and drag seams. `namePrompt` is the field of ⌃⌥N if a display
shows it; `submitName(_:)` types into it and presses ↩ exactly as the panel does (nil: the text was refused and the field stays), `cancelName()` presses ⎋.

`expectWindowsMatchLayout(h)` (one helper, in `ScenarioHelpers.swift`; `on:` for one display) reports `Harness.layoutProblems()`: the arrangement is laid out **afresh**
(`Controller.freshLayout(of:)`) and compared with the controller's record of its last layout and with where the windows really are. Comparing the windows with
`controller.layouts` alone proves nothing about a command that forgets to lay out: they still match the layout from before it. `Harness.staleLayouts()` is the first half on its own, which holds
whatever apps do with the frames they are given; arbor-sim asks it after every line and fails with LAYOUT OUT OF DATE, so every scenario checks it.
**A window moves once** (`ArborTesting/Jolts.swift`): `h.beginStep()` before a step, then `h.movesInStep` (how often Arbor really moved each window) and `h.jolts` (the windows it moved twice where once would
have done: the app had done as it was asked, nobody else touched the window, and a person could see the place in between). arbor-sim asks after every line and fails with MOVED TWICE, so every scenario checks that too.
`PromisesTests` has an example for each of the seven rules of issue #3; a promise the trunk breaks stands there as a known issue that names its row on the board.

Echoes: macOS does a good deal without being asked, and the fake does the same, in
the order recorded on macOS 26 (`collab/evidence/ax-events.txt`). Arbor's own `focus(_:)`
and `setFrame` are reported back after the call has returned: `Harness.run` delivers
after every command, the scheduler after each piece of work, the helpers at their end
(after a bare `perform` or `clickTile`, call `deliverEchoes()` yourself). The keyboard goes
where macOS sends it: a new window is created, then focused; closing or minimizing the
focused window focuses the app's next window *before* the close or the minimize is
reported; a window leaving the Dock is focused before it is reported back; hiding
the app in front brings the app used before forward. Frames are cut to whole points,
and a window cannot be moved so low that its title bar leaves the visible frame. Each is a
switch in `system.echoes` (`focus`, `frames`, `keyboard`, `wholePoints`,
`titleBarStaysReachable`), all on; `system.echoes = .none` is the silent fake of old.
`backgroundFocus(_:)` is an app that is not frontmost changing its focused window. `setFullScreen(_:_:)` is the green button: the window covers its
display and refuses to be moved until it leaves.
Two files hold tests that need macOS. `CarbonKeyCodeTests.swift` is skipped
elsewhere; `EventTapThreadTests.swift` is compiled only there.

What a command costs: `h.measure { … }` returns a `Budget`: windows moved (and how many of those moves changed
nothing or moved a window twice), focuses, reads of the focus, overlay updates, saves. `BudgetTests` pins
them for the everyday commands in `BenchmarkCase.all` on desks of 4, 10 and 30 windows (`Workload`), because on a
Mac each is one or more round trips to another app. A change that makes `nothingIsDoneTwiceOrForNothing`
fail has made Arbor slower, whatever the clock says. `movesAlone` counts moves that were not announced with `moveTogether` (each
waits for its app on its own), `unclaimedMoves` those that were announced and never asked for (a wrong forecast: a bug). `setSizeStep` makes a window round its size like a
terminal, `quit(pid:)` closes an app's windows one after the other.
Go to…: `h.overlays.finder` is the palette while it is open, the same `FinderSession` the real one draws; `typeInFinder`, `moveFinderSelection(by:)`,
`chooseInFinder(row:)` and `dismissFinder()` are the user's keys and clicks, `finderBeeps` counts the beeps. With `h.system.restoresLate = true` a
window that is un-minimised or unhidden reports it only at `finishRestoring()`, as on macOS, where other reports can overtake that one.

Edge resizes: `userResize(_:to:release:)` drags a window's edges the way the
Accessibility layer reports it (`resizeBegan`, changes with the button down,
then on release the final frame and `resizeEnded`); `releaseMouse()` ends a
drag left open with `release: false`. `setMaximumSize` makes a window refuse
to grow, the counterpart of `minimumSize`.

What else real apps do: `stubbornFrames` with
`appsSettle()` (an app that moves its window back a moment after anyone moves it);
`setUnresponsive(pid:_:)` (`setFrame` returns nil until the app wakes up and reports its windows);
`openTab(in:)`, `selectTab(_:insteadOf:)`, `closeTab(_:revealing:)` (native tab groups);
`dragAndLoseTheRelease(_:to:)`. `RealWindowHardeningTests.swift` uses them all.

Drags: `drag(_:through:holding:)` rests at each point long enough for a drop
target to activate (time passes on the harness's scheduler); `holding: 0` is a
quick pass. To look at a drag half way, take it in steps: `beginDrag(_:at:)`,
`moveDrag(to:holding:)`, `holdDrag(for:)`, `holdModifierKeys(_:)`, `endDrag()` or
`loseTheReleaseOfTheDrag()`. `DragStormTests.swift` makes random arrangements and random drags by the hundred;
a failure names its seed.

Motion: `FakeOverlays.transitions` holds every `Transition` the controller asked for, oldest first
(`clearTransitions()` to look at one step's), `finishedAnimations` counts how often it dropped the stages,
and `onAnimate` runs as a transition arrives, for tests that care what has happened by then.
`transition[window]` is a window's item. The harness animates by default, so every scenario test also
proves that animation changes nothing but the picture. The fake window that gets the keyboard is raised
(`windowsFrontToBack()`), which is the order stand-ins are stacked in. `click()` is a press that starts no drag;
`drag`, `userResize` and `dragAndLoseTheRelease` press the button as well (`pointerPressed`).

**The documentation is tested.** In `docs/LAYOUTS.md` and `README.md`, every fenced block marked `console` is a transcript:
`DocTranscriptTests` runs each `$ arborctl …` and `$ open "arbor://…"` line against a `Harness` and compares what is printed, and
loads each `json` block that follows `<!-- settings -->`. Comments such as `<!-- windows: Safari, Mail "Inbox" -->` set the scene
(the header of `Tests/ArborKitTests/DocTranscripts.swift` lists them). After changing a reply, run the tests once with
`ARBOR_UPDATE_DOCS=1` to write the new output into the files, and read the diff.

## 3. arbor-sim

The same harness as a command-line tool, printing an ASCII drawing after each step:

```bash
make sim ARGS='"open Safari" "open Notes 640x420 min 900x600" "dock 101 left" "dock 102 right" "state"'
```

Docked windows are `+-|` boxes, tiles `#`, the Desktop `.`, floating windows `~`.
Besides every `arborctl` command it understands `open`, `close`, `minimize`,
`restore`, `focus`, `cursor`, `drag`, `move`, `seam`, `tile`, `flush`, `quiet` and `loud`.
`title <id> <text>` changes a window's title.
`settings-file <path>` uses a real settings.json the way the app uses its own: it is loaded
at once, `set`, `bind`, `rule`, `exclude` and the like save to it, and `reload-settings` reads it again.
`hide <App>` and `unhide <App>` hide and show an app (each app name is a process of its own),
`background-focus <id>` is an app in the background changing its focused window, and
`displays 2` / `displays 1` plug in or unplug a 1920×1080 display to the right of the main one.
`display-size 1512x982 33` makes the main display that large, with a menu bar that high (1440×900 and 25 to begin with).
`plug side left 1920x1080`, `unplug side`, `make-main side` (a lid closes or opens: every coordinate changes, and no window says so) and `move-display side 0 -1080` change the displays one step at
a time. With `quietly` before it macOS has the new displays and Arbor has not heard, as on a Mac, where it hears only once they have settled; `report-displays` tells it. What apps report in between
(`move`) is what it has to make sense of. `where <id>` prints a window's real frame and how much of it shows; `max <id> <WxH>` is `min`'s counterpart.
`min <id> <WxH>` changes the size a window refuses to go below, and `wait <seconds>` lets time pass.
`fullscreen <id> on` / `off` is the green button: the window gets a macOS Space to itself and comes back.
`display <match> <key> <value>` adds an entry to the per-display options (`display ">=1900" gap 30`), and `displays` without a
number is Arbor's own query: the displays and the options in effect on each.
`scene` lists what Arbor draws at rest on the main display: the backdrop's rectangles, each tile with its style and colour, the seams.
Without arguments it reads its lines from standard input; empty lines and
lines that start with `#` are skipped. It starts with one 1440×900 display, window
ids start at 101, and `open Terminal` has the bundle id `com.example.terminal` (for `rule add` and `exclude`).
`open Calculator 230x408 fixed` opens a window whose size cannot be changed.
It has no other commands for Spaces; those need a scenario test.

`drag <id> <x> <y>` holds the window at the point before letting go, so drop
targets activate; add `quick` to let go at once and `cmd` to hold ⌘.
**The simulated Mac comes as a real one does, with macOS's own tiling on**: the left, right and top edges of the screen are macOS's, and a window let go at their
last point is tiled by the stand-in as macOS was seen to do it. `mac-tiling off` makes every edge Arbor's (in a test: `h.system.tiling = .off`; in a chaos script the same words).
`find` prints the palette of Go to… as text; `finder-type [text]`, `finder-move <rows>`, `finder-choose [n]` and `finder-cancel` are the keys pressed in it.

`focus 101` is the user clicking a window; with anything but a window id (`focus left`, `focus next`) it is Arbor's own
command. With `focusIsSlow` the fake's `focus` takes effect only at `finishSlowFocus()`, as on a Mac, where the next key can
arrive first.

`pull <id> <edge> <points>` drags a window's edge with the mouse (positive
grows the window; give two edges for a corner): `pull 101 right 100 down 80`.

`arbor-sim bench [sizes…]` prints those budgets and the time each command takes, then times for the pure parts
(layout, navigation, drop targets, encoding the state) on nested trees of 10, 50 and 150 windows. Build it with
`swift build -c release --product arbor-sim` for times worth quoting.
`press <command>` runs a command as its shortcut would (`press dock left`), so that Arbor answers on screen as well; whatever it
says there, after this or any other step, is printed as `on screen: …`.

`expect <form>` checks the layout: `expect docked 101`, `expect left-of 101 102`,
`expect camera root`, `expect ring 101`, `expect focused 101`, `expect fail` (the forms are listed in `collab/README.md`,
"Scenarios"). One that does not hold prints `EXPECTATION FAILED: <why>` and
makes arbor-sim exit with code 1 at the end. `make scenarios` runs every
script in `collab/scenarios/` this way; it is part of `make check` and CI.

`transitions` starts (and stops) printing the motion each step is shown with, one line per window drawn,
back to front, so that motion can be read as text:

```
> zoom 101
transition on main, 0.46 s
  w104 (488,200 464x420) -> (1465,367 1416x851)
  w101 (12,37 464x420) -> (12,37 1416x851)
  w102 (964,37 464x851) -> (2917,37 1416x1724)
  w103 (12,469 464x419) -> (12,912 1416x849)
```

A line ends with `cover` for a window in a tile, `cover -> picture` for one that unfolds, and `fades in` or
`fades out`. Two transitions for one step mean that an app did not do as it was told and the motion was corrected.
`watch [events…] [--titles]` prints, from then on, the lines `arborctl watch` would send after each step:
`arbor-sim quiet "open Safari" watch "dock 101 left" "zoom 101"`.

### The control socket, without a Mac

The socket's server and client and `arborctl` need only POSIX and Dispatch, so they are tested like the rest, on both platforms:

- `Tests/ArborIPCTests`: the framing, as pure values (`LineBuffer`, `OutboundQueue`).
- `Tests/ArborKitTests/ControlSocketTests.swift`: the real `ControlServer` on a socket in the temporary folder. The server
  lives on the main queue, so these tests are `async` and wait with `eventually { … }`, which lets the main queue
  run. `HandClient` is a client the test drives by hand (it reads only when told to, which is how a stuck reader is played);
  the blocking calls `arborctl` makes run on a thread of their own. Time limits come from a `ManualScheduler`.
- `arbor-sim --serve <socket path>` puts the simulator behind a real socket until `quit`; with `ARBOR_SOCKET` set to the same
  path, `arborctl` talks to it, and also takes the simulator's own commands (`arborctl open Safari`).
- `scripts/cli-smoke.sh` (run after it) drives `arborctl` as a shell script would: options, exit codes, which output gets what,
  batches from standard input (also as a conversation through two pipes), a server that never answers, completions tried in bash.
- `scripts/watch-smoke.sh` (run by `scripts/sim-smoke.sh`, so part of `make check` and CI) drives the `arborctl` binary against
  it: lines arrive at once in files and pipes, the exit codes, and clients that leave early, say nothing or stop reading.
- `make attack` (`scripts/socket-attack.py`, half a minute, not part of `make check`): 24 clients that misbehave in ten ways, two processes that
  connect and hang up as fast as they can, and (on macOS; the script says why) more clients than the process has descriptors for. It checks what a person would
  notice: Arbor still runs and answers, a silent client is hung up on after its two seconds all the same (so the main thread was never
  held), no descriptor is lost, the processor is idle afterwards, the log was not filled. Run it after changing the socket.

## 4. End to end (`make e2e`)

`arbor-e2e` launches `ArborTestWindows` (three labelled windows), launches the
real `Arbor` limited to that process (`ARBOR_ONLY_PIDS`) with a temporary home
folder, drives it over the control socket, and after every step compares the
window server's own view of the windows (CGWindowList) with what Arbor says
it did. It docks one window on the left, one on the right and the third below
the first, zooms, goes back, floats (the window has its old size back), arranges, changes the gap with `set` and by
saving settings.json both ways editors do (replacing the file, writing into it), shows the Desktop, checks that commands
change only their own setting in a hand-edited settings.json and leave one with a typo alone, opens the settings window, and quits and
checks every window is back in view, where it was before Arbor touched it. Then come the accidents: clients that hang up
without reading their reply, a second copy of Arbor (it must leave with exit code 75 and
disturb nothing), `kill -9` with windows parked (the watchdog must bring Arbor back with the
same tree and camera), and two more kills (the third start must only bring the windows into
view, set `state.json` aside and quit). A watcher stays connected until the first quit (`watch`), and the
runner checks what it heard and that it was told Arbor quit. Your own windows are never touched.

Before that first quit come the steps of Go to… (`GoTo.swift`): a window is found by its title, the palette opens (AppKit and
Accessibility are asked who has the keyboard), closes on command and when another window takes the keyboard, a window comes back from the
Dock to its slot and another from ⌘H. No key is pressed: the runner posts no input, so that it can run on a Mac somebody is
using. While the palette is open, for a second or so each time, it has the keyboard.

Then it starts Arbor again, twice, in the same home folder (so each start restores what the last
one saved), and has the windows do what real apps and their users do; `ArborTestWindows` takes
commands on stdin for that (listed at the head of its `main.swift`). A docked window is minimized
and restored, moved by its app (and put back), moved back by its app again and again (until Arbor
gives up), covered by a new native tab, chosen again, left alone by closing the tab in front. The app hangs
for six seconds while the camera moves (Arbor must answer within three, and place the windows when
the app wakes up). A second app comes forward (the camera follows), and the first changes its focused
window in the background (the camera stays). A window that cannot shrink becomes a tile without the
camera moving. A window closes. Arbor quits zoomed in, with a parked window minimized; starts with that window
minimized (it keeps its slot); quits with the parked windows' app hidden (they must be on screen when
it shows again). `arbor-e2e --full-screen` (CI passes it) also sends a docked window into macOS's
full-screen mode and back, which takes over the screen for some seconds.

A last session (`NewWindows.swift`) has the app open windows while Arbor runs (F23): one floats by default; with `toggle-auto-dock` one docks in
half of the focused window's slot; a small one, one of a fixed size and one that insists on most of the display float where they
opened, with nobody moved; a native tab takes no slot of its own; closing the docked one gives its room back.

**`make e2e-drag`** (`scripts/mac-shell/e2e-drag.sh`) does with the real pointer what no command can
stand in for: a title-bar drag to the screen edge (preview while held, docked on release), a drag onto
another window's edge, a double-click on a docked window's title bar (no seam may move), a press and drag
inside a window (not a drag), a drag of a docked window's edge (the seam follows), a drag out onto the Desktop. Then macOS's own tiling, as the
Mac is set: a docked window let go at the very edge of the screen and a floating one let go in the menu bar are left to macOS (no preview of
Arbor's, the window ends in macOS's tile, stays there and floats); on GitHub's Macs, which come with macOS's defaults, the same places once more with the
tiling switched off, where Arbor docks. It
takes over the pointer for about half a minute, so it is a target of its own; CI runs it after `arbor-e2e`.

It needs Accessibility permission for the terminal you run it from (Arbor
inherits it as a child process): System Settings → Privacy & Security →
Accessibility → enable Terminal (or iTerm, Ghostty…). Exit 0 means every check passed,
1 means one failed (the tail of Arbor's log is printed, without what it says of the Mac's own setup). `make e2e` replaces
`collab/evidence/e2e-latest.txt` after exit 0 or 1 and leaves it alone otherwise.

**A run without a verdict says which kind** (`Sources/arbor-e2e/Ending.swift`), in a line that begins `arbor-e2e: no verdict (exit n):`, with what the Mac says of itself under it:

| Exit | | What to do |
|---|---|---|
| 2 | not ready: no Accessibility permission for the terminal, or a binary is not built | grant it, or `swift build` |
| 3 | somebody is at the Mac: input within 60 s before the start, or in the middle | nothing; it runs when they have gone |
| 4 | nobody could see it: set-up failed with the screen locked, the display asleep, or another user's session on the console | unlock it, keep the display awake |
| 5 | set-up failed on a Mac that looks ready: Arbor did not come up, or did not find the test windows | read the facts under the line |
| 6 | lost in mid-run: Arbor or a test window stopped answering | the log's tail; a finding about Arbor as likely as not |
| 7 | out of time, after 15 minutes | |
| 128 + n | stopped by signal n | |

The facts are yes, no and numbers: is the screen locked, the display asleep, how long since the last input, how many of the test windows the window server has on screen,
and what Accessibility answers when the runner itself asks for them. Every run prints the first of those lines at its start, so that a run that passes with the
screen locked is on record too.

At a terminal the run is printed as it goes; anywhere else that block comes first, then
the checks that failed, each under its step, and the whole run after them, because whoever quotes a report quotes its beginning.
Under a check that failed stands what Arbor logged since its step began (under a second one in the same step: since the first), each line after a `↳`, sixty at
most. `scripts/ci-step.py` publishes those lines with the failure, so they can be read in the check's annotations. No line under a step's first failure means that Arbor
logged nothing, which is a finding too.

**On a Mac that is somebody's** (`Sources/arbor-e2e/Manners.swift`). The test windows come to the front and take the keyboard. So a run that no person started
from a terminal (standard input is no terminal, as in a loop that builds one commit after another) starts only after 60 seconds without
input, and ends as soon as somebody touches the keyboard or the pointer: exit code 3, "nothing was started" or "somebody is using this Mac".
`ARBOR_BUSY_OK=1` runs it all the same. Everywhere, a run ends by itself after 15 minutes (7), and ⌃C, `kill` and a closed terminal (128 + the signal)
make it quit Arbor, close the test windows and remove its folder first; only `kill -9` and a crash of the runner still leave an Arbor behind.
Off GitHub's Macs its Arbor takes no pictures of windows (`ARBOR_NO_PICTURES=1`): they would be of every app's. Nor does it open an app (`ARBOR_NO_OPENING=1`).

CI runs it too: GitHub's macOS runners grant Accessibility to their own
processes, so the `macos` job ends with `scripts/e2e.sh --full-screen` and `e2e-drag.sh` (whenever the build
succeeded, even if a test failed) and keeps the fresh
`collab/evidence/e2e-latest.txt` as the artifact `e2e-evidence`
(`gh run download <run id> -n e2e-evidence`; where artifacts are out of reach,
`scripts/mac-shell/run.sh scripts/mac-shell/e2e.sh` brings the file back). `make parity`
reads the committed file, so commit the fresh evidence when a run should
count. The window server applies moves a moment after the Accessibility call
returns, so the runner's in-view and out-of-view checks wait up to three seconds.

arbor-e2e drives Arbor through commands only. What a person does with a mouse, a keyboard and the menu bar
is the real-window suite's (section 10).

## 5. Seeing the real app from anywhere (`scripts/mac-shell`)

Tests say whether frames are right. They do not say what Arbor looks like, or whether a real drag, click or
shortcut reaches it. For that, a small script launches the real app on test windows on one of GitHub's
Macs, drives it with commands and with real pointer and key events, takes screenshots, and everything comes back
through Git, so it works from any machine that can reach the repository.

**Write a script** next to the others, named after your feature, e.g. `scripts/mac-shell/shots-F09.sh`:

```bash
#!/bin/bash
source "$(dirname "$0")/lib.sh"
arbor_build                                   # swift build, and the pointer tool
arbor_settings '{"gap": 20}'                  # optional: settings.json for the session
arbor_start 3                                 # test windows $W1 $W2 $W3, then Arbor limited to them

ctl dock $W1 left                             # any arborctl command
shot 01-docked                                # mac-shell/01-docked.png

drag $(titlebar_of $W2) 3 400 --no-release    # a real drag; the button stays down
shot 02-preview
check "a drop preview shows" has_overlay 3   # ✔, or ✘ with the reason, a picture, the state and the log
release
check "the window docked" eventually is docked $W2
summary                                       # the state in a few lines

ctl zoom $W1 & film 03-zoom 5                 # five pictures, about 70 ms apart, while it happens
arbor_stop 04-after-quit                      # quits, checks that every window is back on screen
```

**Run it** from your worktree, after committing and pushing (the Mac runs what GitHub has):

```bash
scripts/mac-shell/run.sh scripts/mac-shell/shots-F09.sh      # about two minutes; give it a 10 minute timeout
```

It starts the "Mac shell" workflow for your branch, waits, fetches the output into
`.mac-shell/<script>-<run id>/` (ignored by Git), prints the end of `output.txt`, and exits with the script's
exit code: 0, or 1 when a `check` failed, or 2 when the build or the launch did (`run.sh`'s own: 97 could
not start, 98 timed out, 99 the run brought no output back). **Look at the pictures**
and say honestly what you see. `arbor-<script>.log` (debug level), `build.log`,
`output.txt` and `evidence/<script>.txt` (the claims and checks alone) are in the same folder.

**The Macs are shared.** GitHub lends the whole repository about five at a time, for every contributor's Mac shell runs, CI's
`macos` and `real-windows` jobs and the release build together. A run that finds none free waits, and that wait counts
towards `run.sh`'s time limit. So look at the queue before you start many runs, and start them a few at a time when there is one:

```bash
scripts/mac-queue.py                     # or --minutes 180; it only reads, and takes a few seconds
```

It lists what is running and waiting now, with branch, script and link, then the waits, run times and Mac minutes of the
last hour and who used them. The last line is made to grep for, `mean wait: 3 min 20 s over 14 jobs`; above
five minutes (`--alarm`) a line that starts with `ALARM:` follows and the exit code is 3. `--json` gives the same facts to a script.
**What a run starts with.** A hosted Mac knows nothing of the project, and used to spend its first three minutes installing the Swift
release Arbor is built with and building from nothing, in every run. Now a run, and CI's `macos` job too, begins with `.github/actions/mac-setup`,
which puts back what an earlier run installed and built.

- **A build is named after what goes into it**, not after a commit or a branch (`scripts/ci-build-key.sh`): the system, Xcode, the compiler, the
  manifest, and Git's hash of `Sources` and of the helper tools. So a branch that only adds a Mac shell script builds nothing, whoever built those
  sources first. With other sources the newest build of the day is built upon, and only what differs is compiled.
- **`run.sh` starts the workflow from one branch for everybody** (`swarm/trunk`, else `main`) and tells it which branch to check out, because a run can read only
  the caches of the branch its workflow is from. After changing `mac-shell.yml` or `.github/actions`, say `MAC_SHELL_WORKFLOW_REF=<your branch>`.
  The branch under test may be older than all this: the set-up comes with the workflow.
- **No cache can turn a red run green.** Only compiler output is kept; every script still runs. A checkout stamps every file with the
  present, which would make SwiftPM compile everything again, so `scripts/ci-mtimes.py` gives a file its earlier time stamp back if, and only if, its
  content is what was built, and stamps every other file later than anything in the cache (`scripts/test-tooling.py` holds it to that). The chain of
  builds upon builds is cut every day. And where work is integrated (pull requests into `main`, pushes to it, a release) nothing is built upon at all,
  and a pass that was built upon a cache does not count there (`scripts/ci-changes.py`).
- The annotation `build cache` on the job says what it found: nothing, a build of other sources, or a build of these very sources.

**Rehearse it first, for nothing**, on Linux (on a Mac it refuses: it tells scripts that the Mac is a throwaway one, and `rm`, `pkill` and the like stay real):

```bash
scripts/mac-shell/rehearse.sh scripts/mac-shell/shots-F09.sh         # a few seconds; `make rehearse SCRIPTS=…` does the same
```

It runs the script unchanged against stand-ins for Arbor, `arborctl`, the pointer tool, the test windows and the Mac's
own commands. Behind them is `arbor-fakemac` (`Sources/arbor-fakemac`): the real controller on the fakes of `ArborTesting`,
with a model of the screen around it (which window is in front, who has the keyboard, what a press lands on, drags
that stay held, shortcuts, the menu, pause, quit, signals, `kill -9` and the watchdog). It exits with the script's exit code. It catches typos, bash
mistakes, wrong geometry and wrong expectations of the controller; against the two runs we have from a real Mac
it prints the same frames and the same log.

- `ARBOR_REHEARSAL_BASH=/path/to/bash-3.2` runs the script with the bash macOS has.
- `ARBOR_REHEARSAL_DISPLAY="1440x900 24 70"` sets the display: width x height, menu bar, Dock. The default,
  `"1024x768 31 63"`, is GitHub's runner. Slots under 240 points become tiles, so geometry that works on one can fail on the other.
- `ARBOR_REHEARSAL_AS=person` rehearses the script as somebody's own Mac would run it: the gates stay shut, the nets look at every press and
  key, and a curtain hangs behind the test windows (to Arbor, an app's window where the Desktop was).
- The fake Mac's clock moves one second with everything that is done to it. `sleep` of a second or more moves it by
  that much and takes no real time; shorter sleeps do nothing.
- To debug: `.build/rehearsal/out/` has what the Mac would have sent back, and `.build/rehearsal/worlds/` one text
  file per session with everything that was done in it. `.build/debug/arbor-fakemac replay <file>` prints each line
  with its answer, then the layout and the list of windows; cut the file short to stop earlier.
- A script that uses a command, an option or a tool the stand-ins lack fails loudly: a message that names it, exit
  code 64. Teach it to `Sources/arbor-fakemac/World*.swift` (or `scripts/mac-shell/rehearse/mac-tools`) then. A script that compiles a tool
  of its own against AppKit, or plugs in a display (`vdisplay.m`), stops there with exit code 2.
- The fake Mac stops the pointer at the edge of the display, as a hand's is stopped. On a Mac a posted pointer goes on: `drag … -40 368` ends at x -40
  there and at x 0 here, which is macOS's point of the edge.
- **What it cannot prove**: anything about AppKit's and Accessibility's timing and order of events, animations,
  the Dock resizing, Spaces, full screen, what anything looks like
  (every picture is one black pixel), or whether a tap or a hot key gets its events. A ✔ proves the script, not Arbor.

The header of `scripts/mac-shell/lib.sh` lists every function; `shots-demo.sh` uses most of them, `check-displays.sh` the ones
for a second display, `check-desktop.sh` those for dark mode, wallpapers and Spaces. The ones to know:

| | |
|---|---|
| `arbor_start [count] [NAME=value…]` | Shortcuts, event taps and the menu bar item are off unless you pass `ARBOR_NO_HOTKEYS=0`, `ARBOR_NO_STATUS_ITEM=0`. `ARBOR_APPEARANCE=dark` draws Arbor's own windows and menus dark. `ARBOR_TEST_WINDOWS_ARGS="--min-size 3:700x500"` makes the third window refuse to shrink; `ARBOR_SECOND_APP=1` adds a second app's window `$V1`; `ARBOR_BUNDLED=1` runs Arbor from an app bundle. After `arbor_stop` a script can start another session. |
| `arbor_settings "{$ARBOR_GESTURES_ON}"` | With `lib-gestures.sh` sourced after `lib.sh`. Before `arbor_start`, in a script about the pinch, ⌃⌥ + scroll, the ⌃⌥ rectangle, ⇧-drag on the Desktop or the event taps themselves: it asks for all four and for the switch above them, whatever Arbor ships with. Every session has a home of its own, so every session asks again |
| `arbor_quit`, `arbor_kill [signal]`, `arbor_relaunch`, `reopen_test_windows <n>` | End Arbor alone and start it again on the same windows, settings and saved state; restart the test app |
| `ctl`, `summary`, `state` | `arborctl` on the session's socket; the state as readable lines; as JSON |
| `tw <request>`, `open_window <NAME> [options]`, `events_of <id> <kind>` | The test app does what apps do: `tw minimize $W1`, `restore`, `hide`, `activate`, `title`, `frame`, `min`, `fullscreen`; a new window with a title, size, minimum size or kind (`panel`, `sheet:<id>`); what its content received |
| `shot`, `shot_after <s>`, `film <name> <n>` | A picture once things have settled (0.7 s, `ARBOR_SETTLE`); after exactly that long; a burst |
| `drag`, `release`, `click`, `dblclick`, `rightclick`, `move`, `key`, `pinch` | Real events (`pointer.swift`): `drag x1 y1 x2 y2 [--steps n] [--duration s] [--hold s] [--no-release] [--mods shift+cmd]`, `key ctrl+opt+space`, `pinch x y 0.3 --mods opt`. A key can stay down: `key ctrl+opt+space --down`, later `--up`; `key ctrl+opt+left --held` presses only ← while ⌃⌥ are down; `--repeat n` sends auto-repeat |
| `drag_window <id> x y`, `click_window <id>`, `click_button <id> close`, `click_menu "Arrange Windows"` | The same aimed for you, at a point nothing covers |
| `frame_of`, `real_frame_of`, `titlebar_of`, `center_of`, `seam_right_of`, `seam_below`, `tile_of`, `edge_point <edge>`, `zone_of <id> <edge>`, `desktop_point`, `status_item`, `status_item_frame` | Where to point, in the coordinates `arborctl state` uses |
| `overlays`, `has_overlay <level>`, `overlay_frame <level>` | Arbor's own windows as the window server sees them |
| `claim "<title>"`, `check "<what>" <command…>`, `settled`, `step "<title>"` | A real-window step and its proof: what they print is evidence (section 10). `step` is a mere heading, and ends the claim |
| `eventually`, `stays`, `fails`, `pressed <chord> <command>`, `ran <command>`, `logged <text>` | Up to three seconds; for a whole second; not; the shortcut made Arbor run exactly that; Arbor ran it; the log says it |
| `is <what> <id>`, `in_view`, `out_of_view`, `at_edge`, `fills`, `in_slot`, `frame_is`, `left_of`, `above`, `same_column`, `same_row`, `desktop_between`, `camera_on`, `depth_is`, `count`, `no_overlaps`, `width_is`, `wider_than`… | Predicates for `check`; where a window is comes from the window server, not from Arbor |
| `display_add <w> <h> [side]`, `display_move <side> [offset]`, `display_remove` | A virtual second display to the `right`, `left`, `above` or `below`. `shot` then also writes `<name>-d2.png`, and `panorama <name>` takes both displays in one picture. `screen_of 2`, `display_frame_of 2`, `display_of <id>`, `inside "<rect>" "<rect>"` say where things are. `ARBOR_DISPLAY_ARGS=--hidpi` makes it a Retina display, `ARBOR_DISPLAY_SERIAL=2` another display. |
| `appearance dark\|light`, `wallpaper <file>\|#rrggbb\|gradient` | The system's appearance; the desktop picture of every display (`gradient` has a grid, 100 pixels a square) |
| `macos_reduce_motion off`, `macos_tiling off` | Before `arbor_start`: the runner comes with Reduce Motion on, which turns Arbor's motion off |
| `space_add`, `space_go left\|right`, `spaces` | One more Space; ⌃← and ⌃→ with real keys; how many there are and which one shows |

What the Mac is (macos-26 runner, October 2026): macOS 26.6 on arm64, Swift 6.3, one 1024×768 display at scale 1
(visible frame 0,31 1024×674: menu bar 31, Dock 63), black wallpaper, Finder in front, bash 3.2, python3.
Child processes have Accessibility and Screen Recording. Reduce Motion is on. A build takes about 15 s, a picture 70 ms.
macOS's own tiling is at its default, which is on (no key of `com.apple.WindowManager` is set). Where it acts was measured there by holding a window
with the pointer at one point after another and looking for WindowManager's preview in the window server's list: at x 0 and x 1023 (not 1, 2, 1021,
1022), from y 0 to y 30 (not 31), nowhere along the bottom, and anywhere with ⌥ held, whatever else is held. At the sides at once; in the menu bar only after a rest of 0.1 to 0.2 s. A window of a
fixed size is taken too, and moved into the tile as it is. There, and in the whole of its own band along those edges (Q23), Arbor stands aside (`MacTiling.swift`, which has the
numbers; `e2e-drag.sh` plays it). A posted pointer is not stopped at the edge of the display as a hand's is: `drag … -40 368` really goes to x -40,
where neither macOS nor Arbor does anything. `macos_tiling off` switches it off, and Arbor goes by the setting from the next drag on.
A double-click on a title bar fills the screen too (macOS's default for it), tiling or no tiling.

Things that bite:

- A window's title bar must not be covered when you press on it. The test windows open in a cascade with the
  last one in front; floating windows are pushed onto the Desktop's part of the layout. `drag_window`, `titlebar_of` and
  `click_window` look for a point that nothing covers.
- `check` runs its command in a subshell, and `$(…)` among its arguments is evaluated once, before `eventually`
  starts trying: write `eventually wider_than $W1 400`, not `eventually test $(width_of $W1) -gt 400`.
- Commands that act on the focused window, and shortcuts, need a real `click` on a test window first.
- There is no public way to make gesture events. `pinch` (and `witness pinch`, below) fills in the fields a trackpad's
  events carry, and Arbor's tap reads the result as it reads a trackpad's on macOS 26; a new macOS may change that.
- On macOS 26 a menu bar item's window belongs to Control Center; `status_item` asks Accessibility instead.
- bash 3.2: no associative arrays, no `${x,,}`, and an empty array is an error under `set -u`.
- Plugging the virtual display in switches the runner's main display from 1024×768 to 1920×1080, and macOS shuffles the
  windows; unplugging switches it back. Ask `screen_of 1` and `frame_of` again afterwards.
- Camera commands without a window (`back`, `show-all`, `desktop`) act on the display under the pointer if the pointer was used last (F56): `move` there first.
- The virtual display keeps its UUID when it is unplugged and plugged in again (same vendor, product and serial number),
  but only within a run: another Mac gives it another.
- `vdisplay.m` uses private API (CGVirtualDisplay, SkyLight). That is allowed because it is a test helper that no target in
  `Package.swift` contains; nothing of it may move into `Sources/`.
- A dragged window trails a posted pointer: macOS holds it back when one of its edges meets another window's, the Dock's or the
  screen's, and it does not catch up, so after a drag `titlebar_of` can be off screen (`grab_of` in `check-F09.sh`).

**Proof for the scoreboard.** A `claim "…"` heading with its checks under it is the form `scripts/parity.py` reads, and
`claim` and `check` record it in `evidence/<script>.txt` as they print it. A shipped feature's claims belong in the
real-window suite (section 10). `scripts/mac-shell/proof.sh` was the first such script; its evidence
(`collab/evidence/gestures-latest.txt`) counts until the suite, which makes all of its claims and more, has run on real windows.
`scripts/mac-shell/axfind.swift` finds a control in a window of Arbor's own by its accessibility identifier, title or value and prints where it is and what it shows (it only
reads), so that a script can click in a window SwiftUI laid out.

**The event taps.** `scripts/mac-shell/input-taps.sh` is the only thing that exercises `Sources/ArborKit/Input`: run it after any
change there. It does not ask Arbor what happened. `scripts/mac-shell/witness.swift` puts a listening tap at the far end
of the chain of taps, where only apps come after it, and prints every mouse and gesture event that gets that far,
with its modifiers, click count, whether Arbor re-posted it, and how long it took. So the script can check
that a ⌃⌥-drag reaches no app at all, that a ⌃⌥-click arrives once and in order, that a plain drag is
untouched, what a click costs with Arbor running, and what happens to input when Arbor is stopped or
killed in the middle of a gesture. `witness taps` lists every process's taps and whether each is switched on;
`witness pinch x y <magnification> [--opt] [--rotate]` posts a pinch; `witness scroll x y <dx> <dy> [--opt] [--ctrl] [--momentum n]` a two-finger
scroll; `witness wheel x y <notches> [--opt] [--ctrl]` turns a mouse wheel; `witness hold-space <n>` holds ⌃⌥Space down.
The script clicks at places it takes to be empty, so outside GitHub's Macs it refuses to run unless told to (see its header).

**Measuring.** `scripts/mac-shell/perf.sh` times camera moves over twelve real windows of one app and of four, using
`arborctl stats`; checks that overlay panels that were put away and handed out again still show and take a drag; then runs
1200 commands and prints `footprint`, `heap` and `leaks`, and `top`'s idle wakeups while nothing happens.

`scripts/mac-shell/first-dock.sh` measures the first act after a start against the next ones, with nine real apps open, in the debug and in the
release build, each with and without what Arbor gets ready ahead of the first motion (`ARBOR_NO_REHEARSAL=1` is the control). Its first session is the
one that counts: a hosted Mac has drawn none of the apps' icons yet, which is what cost the first dock of a day its seconds. Its tables come from
`first-dock.py`, which needs no Mac: `first-dock.py table <arbor.log> <trace.jsonl>…` says of any recorded session, for every command that moved a
window, how long it was until the first move, how much of that the stage took, when the last app had answered and when the stage was down.

**Only compiling.** `scripts/mac-shell/run.sh scripts/mac-shell/compile.sh` runs `swift build` on the Mac at your branch's
head and brings back `build.log`, with the errors and warnings at the end of the output: for macOS-only code, or for a
pull request whose macOS CI job is left out because it touches only code that Linux builds too (see "Executors
without a Mac" in `collab/README.md`).

**Three runs per feature should do.** A hosted Mac is slow to come and shared.
Rehearse the commands in arbor-sim first, put several questions into one script,
and read the whole output before running again. `bash -n script.sh` catches syntax errors for free.

**Several scripts: one run, not several.** They share one Mac, one checkout and one build, and wait for a Mac once:

```bash
scripts/mac-shell/run.sh scripts/mac-shell/shots-F10.sh scripts/mac-shell/shots-F12.sh scripts/mac-shell/shots-F43.sh
scripts/mac-shell/run.sh --macs 2 scripts/mac-shell/compat.sh            # one long script that shares its work out among two Macs
scripts/mac-shell/run.sh --on macos-15 scripts/mac-shell/e2e.sh          # another macOS: macos-15, macos-14, macos-15-intel
scripts/mac-shell/run.sh --bare scripts/mac-shell/desktop-facts.sh       # no toolchain, no build: it only asks the Mac something
```

They run one after the other. Each gets its turn and its own twenty minutes, whatever became of the one before, and starts with an empty
`mac-shell/`. What comes back is `.mac-shell/<first script>-x3-<run id>/` with a folder for each, `1-shots-F10/`, `2-shots-F12/`, …, holding what a
run of that script alone would have brought (`output.txt`, `exit-code.txt`, pictures, logs), and `summary.txt` with a line for each. `run.sh` exits with the
first exit code that is not 0. At most four to a Mac; more are shared out among as many Macs as that takes, or among `--macs N`, whose
output lies in `mac-1/`, `mac-2/`, …. A script that is given to several Macs by itself finds in `$MAC_SHELL_SHARE` which part is its own
(`2/3`: the second of three); `compat.sh` takes every Nth app. Every script finds in `$MAC_SHELL_PART` and `$MAC_SHELL_PARTS` which playing of the whole
dispatch it is and how many there are, over all its Macs, settled before the first begins: its place among `run.sh`'s arguments, so a playing that is lost shows as a gap. All kinds of Mac come out of the same five at a time.

**Whose turn it is.** GitHub hands its Macs out in no particular order: a job has been seen to wait eight minutes while later ones started. So
`run.sh` keeps the order itself, before it starts the run, where waiting takes nobody's place. `--priority 1` (or `ARBOR_MAC_PRIORITY=1`) starts at once: a
fault on real windows, a merge train, whatever others are blocked by. `2` holds back while three or more jobs are waiting for a Mac. `3`, the default, holds back
while any is: pictures, features, whatever can wait. Whatever the priority, a branch has at most two jobs running or waiting at a time (`3`: one).
It says what it is holding back for, and the wait counts towards `MAC_SHELL_TIMEOUT`.

**GitHub's API is shared too.** An account may make 5,000 REST calls an hour, for everything everybody does under it, and when they are used up nobody
under that account can start a run, open a pull request or read a check until the hour is over. It has happened: a dozen copies of `run.sh` asking every ten
seconds whether their run had ended, and every thirty what the queue looked like. So `run.sh` asks Git whatever Git can answer, which does not count (what GitHub has at
the branch; whether the run has ended, which is when its output branch appears), and a run costs about ten calls however long it waits. While it holds back it looks
at the queue every two minutes, for a handful of calls. **Do the same in your own loops:** `git ls-remote` instead of `gh api` where it will do, a minute or more
between two calls where it will not, and never a loop round `scripts/mac-queue.py`, whose full report costs twenty to forty; its last line but one says what is left of
the hour. Several checkouts, containers or people who share a folder can share one look at the queue, good for three minutes: `export ARBOR_MAC_QUEUE_CACHE=<a file there>`.

**Nothing takes a Mac that Linux can already refute.** A run that ends in a compiler's error, a typo in the script or a wait for something that never
comes has held a Mac for minutes to say what Linux says for nothing. So `run.sh` starts nothing that has not been through `scripts/mac-shell/preflight.sh`:

```bash
scripts/mac-shell/preflight.sh scripts/mac-shell/shots-F09.sh      # where Swift is, e.g. in the container; run.sh does it itself if it finds a swift
```

- **The code:** `make lint`, `swift build`, `make typecheck-mac` and `swift test`. None of it while `Package.swift`, `Sources`, `Tests`, the stand-ins and the helper
  tools are what the trunk has, as on a branch that only adds a script.
- **Each script:** `bash -n`, and a rehearsal (below) that gets to the script's end: exit code 0, or 1 for a check that came out ✘, which may be the very thing the Mac
  is asked about. On the way it may not have said what is a slip on any machine: a command bash does not know, a variable nobody set, a command Arbor does not
  know. `lib.sh` goes on after a step that fails, so the exit code alone does not tell. Not needed for a script that is, with `lib*.sh`, what the trunk has.
- **What has passed is noted** in `.mac-shell/preflight/`, under Git's hash of what was checked and not under a commit: nothing is checked twice, and the note made
  in a container is found by `run.sh` outside it. What is not committed does not count, and where Git does not work nothing does.
- **`--no-preflight "<why>"`** starts the run all the same, for a script that needs what the fake Mac lacks. The reason stands in the run's title, for everybody to read.

Where branches cannot be deleted, the output branch
`mac-shell-out/<ref>.<script>` stays on GitHub and the next run of the same script replaces its content.
The workflow `Housekeeping` deletes it once it is a day old, so fetch what you want to keep before then. The same workflow
deletes branches whose work has landed (`scripts/housekeeping.py` has the rules, and what never goes).

### On a person's own Mac

The scripts are written for GitHub's Macs, which are thrown away after the run. They also get run on people's own, and there a
`defaults write`, a `killall Safari` or an `rm -rf ~/Applications/Arbor.app` is damage. So is a line that means no harm: with a full disk
`dir=$(mktemp -d)` leaves `dir` empty, and the clean-up's `rm -rf "$dir/"*`, `cd "$dir"` (bash 3.2 takes `cd ""` for a success) or
`pkill -f "^$dir/"` then takes the root folder, the checkout, or every process of the account. **Which script may run on such a Mac, at which
commit, is for its owner to say**; nothing else may. **`scripts/mac-shell/run-list.sh`** is the one command for whoever sits at such a Mac: without a word it compiles the helper tools and
runs `check-harness.sh`, the first to run on a Mac that is new to this; with `--all` it goes on through the list in its header, each script with a clean environment, and stops when a script declines, is cut
off, or leaves the Mac different. What comes of it lies in `.mac-shell/list-<date>/`, and is sent nowhere.

**What a script must do**

- **`on_throwaway_mac`** (`$GITHUB_ACTIONS` is `true`, and on a Mac the account is GitHub's `runner`, or `lib.sh` takes the variable away; `$CI` is not enough, people set it) is asked before anything that changes the system
  beyond the run's own processes and temporary files: settings (`defaults write`), privacy permissions (`tccutil`), the wallpaper, the
  appearance, Spaces, displays, keyboard layouts, keychains, login items, what LaunchServices knows (`lsregister`, `open` on a bundle or a URL),
  apps the script did not start (opening, quitting, killing, arranging their windows), files outside `mac-shell/`, `.build/` and `/tmp/arbor-*`.
  Nobody ever sets `GITHUB_ACTIONS` by hand.
- **A runner of GitHub's on a person's own Mac sets `GITHUB_ACTIONS` as GitHub's Macs do.** So nothing may take the variable alone for "a Mac that nobody owns". `scripts/e2e.sh` takes it away where the account is not `runner`, as
  `lib.sh` does, so that `arbor-e2e` keeps its manners, `ARBOR_NO_PICTURES` and `ARBOR_NO_OPENING` there; `install.sh` and `make-signing-identity.sh` ask for the account as well. The account such a runner runs under must never be called `runner`.
- A script that is nothing without such changes says **`needs_throwaway_mac "<what it would do>"`** right after sourcing `lib.sh`: elsewhere it says
  so and ends with exit code 77, "skipped". A script with a few such steps puts `on_throwaway_mac &&` or `if on_throwaway_mac; then` around them.
  `lib.sh`'s own helpers (`macos_tiling`, `macos_click_wallpaper`, `macos_reduce_motion`, `display_*`, `appearance`, `wallpaper`, `space_*`) decline by themselves.
- **One way to make a folder**: `scratch_dir <name> [VARIABLE]` makes `/tmp/arbor-<name>.XXXXXX`, ends the script if it cannot, exports the path and sees to
  its removal. `scratch_remove <path…>` is `rm -rf` for such a folder and what is inside one, and refuses everything else. No `mktemp`.
- **One way to stop a process**: `started <pid>` puts a process the script started itself on record (one that ran before the run is refused), and
  `kill_started <pid…>` stops those and no others (with nothing named, nothing; `--all` is everything on record). Never `pkill`, `killall`, `kill $(pgrep …)` or a process group.
- **One way to clean up**: `at_exit '<command>'`. A `trap … EXIT` of the script's own replaces the one that stops Arbor and the test windows.
- **One way to wait**: `limit <seconds> <program…>` for anything that may raise a dialog or hang (`osascript`, `open`, `codesign`, `security`); it stops the program and
  what that started. `wait "$pid"`, never a bare `wait`; and for an Arbor that was only asked to quit `check "Arbor exits" ended "$ARBOR_PID"`, because `wait` waits for ever for one that
  does not. The whole script has `ARBOR_TIME_LIMIT` seconds (900; set it above `source lib.sh`).
- **Input only through `click`, `dblclick`, `drag`, `release`, `move`, `key` or `pointer …`**, never `"$ARBOR_POINTER" click …`, which goes past the nets. After
  `read -r x y w h <<< "$(frame_of …)"` an answer that never came makes 0 of every number: the nets decline the menu bar it points at, but say `[ -n "$h" ] || die …`.
- **An Arbor the script starts itself** (a relaunch) gets `ARBOR_ONLY_PIDS=<its own pids>` and `ARBOR_NO_WATCHDOG=1` on that line, and `started "$ARBOR_PID"` after it.
- **Nothing about the person.** What a run prints gets pasted into pull requests. No `whoami`, `hostname`, `$USER`, `lsappinfo`, `pgrep -l`; the window server's list only through `pointer windows`, which
  says `somebody` for every app that is neither the run's own nor macOS's furniture. Say "process 812", not the app's name. Never a window title.
- **Pictures only through `look`, `shot`, `shot_after`, `film`, `panorama`**, never `screencapture`. Where one window tells the story, `look <name> <window id>` is the picture that is taken everywhere.
- **Nothing leaves the Mac.** A script never pushes, uploads or posts what it wrote (`git push`, `curl`, `gh`, `scp`). On GitHub's Macs the workflow brings `mac-shell/` back; on a person's Mac the person
  decides what to send.
- **`make lint`** (`scripts/lint-mac-shell.py`) fails on a line that breaks one of these rules. `# safe anywhere: <why>` on the line or above it is the way to say that it only looks like one.
  It also fails on a line in which a variable that may be empty is removed, moved, copied over, changed into or matched against processes. Sure not to be empty: what `scratch_dir` made, `lib.sh`'s own folders, a literal,
  a `$(…)` with `|| die` on the line (not `local x=$(…) || die`: the status is `local`'s) or `[ -n "$x" ] || die` on the next, what is built from a sure one; or write `"${dir:?}"`, or test it on the line
  (`[ -n "$dir" ] && rm -rf "$dir"`). For these the waiver is `# never empty: <why>`, because `safe anywhere` is said about what a line does, not about what is in its variables. The keeper of the harness reads every waiver.

**What `lib.sh` does by itself** (`scripts/test-tooling.py` holds it to this, under bash 3.2 too: `ARBOR_TEST_BASH=<path>`)

- **Every script is supervised.** The process that sources `lib.sh` starts the script again as a child in a process group of its own and watches it. Whatever ends the script
  (its last line, `die`, ⌃C, the time limit, `kill -9`), the supervisor lets go of every mouse button and key (`pointer calm`), puts the pointer back where it was, stops
  what is still running of the run's (its process groups, the processes on record, whatever runs from the checkout's `.build/` or from the run's folders and began after the run),
  and removes the run's folders. If the supervisor is killed too, the next script finishes the job first; `scripts/mac-shell/sweep.sh` does only that.
- On a person's Mac **nothing starts** from a checkout the lint finds fault with, as root, with less than 2 GB free, or while another script runs.
- There `arbor_build` ends, and `arbor_start` begins, by asking whether the Mac is free: **not beside a running Arbor** (the lock that keeps two apart lies in `$ARBOR_HOME`, so a session's
  Arbor runs beside the person's, which would obey the same real keys and gestures with THEIR windows) or another window manager, **not within five minutes of anybody's input**, **not while an app
  keeps the display awake**, as a call does (`ARBOR_BUSY_OK=1` overrides the last two). Exit code 77.
- Then **the curtain** goes up (`curtain.swift`): a plain dark window over every display, in front of everything that was open, behind everything the script opens. It takes the presses that miss
  and never comes forward. It goes down with the run; a right-click takes it down, and ends the script.
- Before every session: not behind a locked screen, under the screen saver or with the display asleep. Nothing that opens there shows, Accessibility lists no window that does not show, and every check would fail in a way that looks like Arbor's fault.
- `arbor_start` ends by bringing the test windows' app forward, so that from the first line of a session no app of the person's has the keyboard or is named in Arbor's menu.
- **A press** is let through only between the menu bar and the Dock (and on the session's own menu bar item), and only where the first window to get it, Arbor's own panels aside, belongs to a process the
  run started. **Keys** go only to such a process, or to an open menu of Arbor's, and never if macOS itself takes the shortcut (⌘Tab, ⌘Space, ⌃←, ⌘⇧Q, ⌘⌥D, ⌘⇧4…; ⌃⌥Space where several input sources are on, because it
  switches the keyboard layout). `release` and `key … --up` are never declined. An `arbor_start` pointed at a process that ran before the run (`ARBOR_ONLY_PIDS`, `ARBOR_EXTRA_PIDS`) ends with 77.
- **Pictures.** `look` takes one window, which must be of a process the run started: the window server hands over that window's own picture, so nothing of anybody's can be in it. `shot`, `shot_after` and
  `film` take nothing unless the person asks (`ARBOR_SHOTS=1`), and then the main display between the menu bar and the Dock, only with Screen Recording already granted and while nothing but the
  run's own windows shows in front of the curtain; one into which a banner came is thrown away. **`ARBOR_SHOTS=1` never gets the whole screen.** `panorama`, and any picture without the curtain, are for
  GitHub's Macs; the one switch that allows them elsewhere is long and says what it takes: `ARBOR_SHOTS_WHOLE_SCREEN_I_HAVE_CLOSED_EVERYTHING=1`.
- **What the run says.** Everything it prints, on either output, and every `.txt`, `.log`, `.json` and `.jsonl` it leaves in `mac-shell/` says `<checkout>` for where the checkout is and `~` for the home folder (and for
  any `/Users/<name>`). The nets, the pictures and the look at the Mac name no app of the person's.
- **An Arbor started past `arbor_start`** finds `ARBOR_ONLY_PIDS=1`, `ARBOR_NO_WATCHDOG=1` and `ARBOR_NO_PROMPT=1` in its environment: it arranges nothing. (`open` hands on no environment: that is why it asks.)
  Every Arbor there finds `ARBOR_NO_OPENING=1` (`summon` opens no app: to an Arbor that knows only test windows every app of the person's is one that has to be opened) and `ARBOR_NO_PICTURES=1`: with Screen Recording it would photograph every app's windows and the Desktop with its files' names for the stage (F02), which would then be in the script's pictures.
- `mac-shell/` is emptied first (but for `output.txt`), so that the last run's logs and pictures do not pass for this one's.
- **The Mac is looked over before and after**: settings a script could touch, keyboard layouts, Spaces, keychains, the installed Arbor and its files (check sums), what LaunchServices and launchd know of
  Arbor, which apps run, leftovers under `/tmp`, the working tree, displays, wallpaper, windows on screen by owner. What differs is printed at the end; of the lines about the person's own things (apps,
  windows, wallpaper, keychains, keyboard layouts) only how many differ. Which ones is in `mac-shell/stays-on-this-mac.txt`, for the owner to read and for nobody to send.

Even so: hands off the mouse and the keyboard while a script runs.

**What each script does on a person's Mac.** Read line by line on 2026-10-14 as a person's Mac would run it: their apps open with unsaved work, their Arbor perhaps running, two displays, another
keyboard layout, a full disk, an interruption at any line. "Trunk" rows hold for the commit that brought this table. A branch's row
holds for the commit named (second reading, 10:45 UTC) and says what the script does once its branch has merged this harness: no script of a branch runs on a person's Mac before that.

| Script | Where | On a person's Mac | Pointer and keys | What it skips there, or why not |
|---|---|---|---|---|
| `compile.sh`, `compile-tools.sh` | trunk | safe | none | They compile and start nothing |
| `sweep.sh` | trunk | safe | lets go, puts the pointer back | Only what the record of a run that was cut off names |
| `check-harness.sh` | trunk | safe | 10 s | The harness itself: run it first |
| `run-list.sh` | trunk | safe | its scripts' | Runs what this table calls safe, in order, and stops at the first sign of trouble. Keeps the display awake for as long as it lives (`caffeinate -d -i -w`), which changes no setting; the scripts are told which process that is, so that they do not take it for a call |
| `e2e-drag.sh` | trunk | safe | 30 s | |
| `e2e.sh` | trunk | safe | 30 s | `make e2e` with full screen, then `e2e-drag.sh`; rewrites `collab/evidence/e2e-latest.txt` |
| `shots-F45.sh` | trunk | safe | none | |
| `shots-F48.sh` | trunk | safe | 5 s | |
| `shots-F02.sh` | trunk | safe, steps skip themselves | one click | Reduce Motion, the wallpaper, crash reports; the stage without pictures of windows. About 25 times a panel of Arbor's covers the main display for up to 2 s |
| `shots-demo.sh` | trunk | safe, steps skip themselves | 60 s | `macos_tiling off`; the lists of what else is on screen |
| `proof.sh` | trunk | safe, steps skip themselves | 3 min | The `arbor://` claim (it would replace `~/Applications/Arbor.app`), `macos_tiling off`. A test window goes full screen |
| `check-review-ux.sh` | trunk | safe, steps fail | 90 s | The wallpaper is behind the curtain, so the two clicks on it prove nothing; the session with ⌘Tab skips itself |
| `check-F44.sh` | trunk | safe, steps skip themselves | 60 s | Really selecting layouts |
| `check-F41.sh` | trunk | safe, steps skip themselves | 2 min | The two measurements that press past the nets; switching layouts, and which are switched on; ⌘Tab |
| `check-F49.sh` | trunk | safe, steps skip themselves | 2 min | The second display |
| `check-F51.sh` | trunk | safe, steps skip themselves | 90 s | Holds ⌃⌥Space down for seconds at a time. All of it is ⌃⌥Space: declined where several input sources are on |
| `check-switch.sh` | trunk | safe, steps skip themselves | 60 s | ⌘Tab: the app used before may be the person's own |
| `check-F56.sh` | trunk | safe, steps skip themselves | 60 s | The second display. Types "arbor" into a test window |
| `check-F09.sh` | trunk | safe, steps skip themselves | 3 min | Reduce Motion. The button is held for up to 6 s at a time, ⌘ for 2 s. macOS's own edge tiling stays on and may cost some checks at the screen edge |
| `check-F18.sh` | trunk | safe | 15 s | |
| `check-F20.sh` | trunk | safe | 60 s, mostly keys | Types "Pair" and "up" with its own test app in front, which for this script has an icon in the Dock. One step is ⌃⌥Space: declined where several input sources are on |
| `check-F54.sh` | trunk | safe, steps skip themselves | none | Part 2: Arbor over every window, TextEdit and Terminal killed and opened |
| `check-F53.sh` | trunk | safe, steps skip themselves | 2 min | Launching Calculator by name. A second test app under the name ArborScratch |
| `trace-demo.sh` | trunk | safe, steps skip themselves | 3 min | Every real app. The test app hides itself for two seconds: an app of the person's comes forward, after which presses on it are declined |
| `shots-focus-ring.sh` | trunk | safe, steps skip themselves | 90 s | Reduce Motion, click-wallpaper, the wallpaper, Mission Control |
| `shots-minimap.sh` | trunk | safe, steps skip themselves | 3 min | Reduce Motion, so with that setting on nothing fades. Presses ⌃⌥M, and holds it down for seconds at a time |
| `shots-F15.sh` | trunk | safe, steps skip themselves | 4 min | The wallpaper, dark mode, the click through the backdrop, `scenery` altogether. The backdrop lies behind the curtain, so pictures taken here do not show it |
| `shots-F43.sh` | trunk | safe, steps skip themselves | 2 min, mostly keys | The Mac's appearance, the wallpaper, Reduce Motion, the second display. Types one x with the panel of shortcuts up or a test window in front |
| `shots-F12.sh` (`axfind.swift`) | trunk | **not before the fix its owner has promised** | 2 min | Its pictures of the settings window go past `look`, without a look at the Screen Recording permission: macOS's dialog on the person's screen. A ⌘W it records as a shortcut should not outlive the step |
| `shots-review-controller.sh`, `events.sh` | trunk | safe, steps skip themselves | 30 s | `macos_tiling off`. A test window goes full screen: a Space of its own for a moment |
| `probe-keyboard.sh` | trunk | safe, steps skip themselves | none | ⌘W. Reads who would get a key and presses nothing; no pictures, no titles. Its test app is in the Dock and in front for some twenty seconds; the app that was in front is brought forward again |
| `watchdog-bundle.sh` | trunk | safe, but leaves a trace | none | `open`s a bundle of its own under an identifier of its own: LaunchServices keeps the entry for a while |
| `check-displays.sh`, `check-desktop.sh`, `compat-pictures.sh` | trunk | **never**: end with 77 | | Virtual displays, dark mode, wallpaper, a Space that stays, every window arranged |
| `check-sweep.sh` | trunk | **never**: ends with 77 | | Clicks on the wallpaper, which sweep aside whatever is open |
| `compat.sh`, `compat-extras.sh` (`lib-apps.sh`) | trunk | **never, unless the person says `ARBOR_APPS_HERE=1`**: end with 77 | | An app that was not running is still theirs: launched, it brings back last time's windows and unsaved documents, and `app_quit` answers "Don't Save" |
| `input-taps.sh` | trunk | **never, unless the person says `ARBOR_INPUT_TAPS_HERE=1`**: ends with 77 | | Pinches, scrolls and clicks at fixed places past the nets; stops Arbor while its taps hold everybody's input |
| `rehearse.sh` | trunk | **never on a Mac**: ends with 77 | | It tells scripts that the Mac is thrown away; only what has a stand-in is fake. For Linux |
| `run.sh` | trunk | safe for the Mac | none | Starts a run on GitHub |
| `check-F13.sh` (`lib-F13.sh`) | trunk | safe | none | 10 to 25 minutes and 2 GB. Everything in a sandbox under `/tmp`: a throwaway `HOME`, `ARBOR_HOME`, keychain and clone. A small window takes the keyboard twice for seconds. Three copies run with their watchdog, which after a crash would use `open` |
| `check-F12.sh` | trunk | safe | none | |
| `perf.sh` | trunk | safe, steps skip themselves | one drag | `footprint`, `heap`, `leaks` where developer mode is off (macOS would ask for a password) |
| `check-F13-system.sh` | trunk | **never**: ends with 77 | | TCC.db as root, `tccutil`, login items, `make install` as a person runs it |
| `check-F58.sh` (`share-probe.swift`) | trunk | safe, steps skip themselves | 2 min | ⌘Tab, the second display, the grey wallpaper; the pictures of single test windows only where Screen Recording is granted already. Two test apps have an icon in the Dock. A test window is put at and beyond the display's edges, so with two displays it shows on the other for a moment |
| `shots-finder.sh` | trunk | safe, steps skip themselves | 3 min, mostly keys | ⌘Tab, Mission Control, the swipe to another Space. Types digits and letters with the palette open or its own test app in front, which has an icon in the Dock |
| `watch.sh` | trunk | **not this copy**: #233's | 6 s; 10 min in all | On the trunk: `arborctl watch` without a limit, more than 900 s, and the end-to-end runner under a time limit. #233 `cea45a10`: safe |
| `shots-F10.sh` | trunk | safe, steps skip themselves | 5 min | The appearance, input sources, the Accessibility list, a stand-in for another window manager. No `shot` here whatever `ARBOR_SHOTS` says, and no picture of the welcome window: it shows what `doctor` found on the Mac. A bundle of its own under an identifier of its own is opened through Launch Services, which keeps the entry for a while. Arbor's item shows in the menu bar |
| `desktop-facts.sh` | #197 `e75d37f8` | safe | none | It reads the window list, four preferences and three answers of Finder's, and names only Apple's own processes |
| `check-resume.sh` | trunk | **never**: ends with 77 | | Calculator and TextEdit opened, brought forward in turn, and quit; `ARBOR_APPS_HERE=1` does not open it |
| `shots-F15-apps.sh` | trunk | **never**: ends with 77 | | Ten real apps opened for their icons, and killed |
| `first-dock.sh` (`first-dock.py`) | trunk | **never**: ends with 77 | | Nine real apps opened and quit, every window arranged, Reduce Motion, the display's size |
| `check-F52.sh`, `check-F63.sh` | #59, #66 | **never**: end with 77 | | Virtual displays, Accessibility taken from every app |
| `check-F59.sh` | #158 `6907ce87` | safe | 30 s | During a carry nobody's app gets arrows, ↩ or ⎋ |
| `shots-F04.sh`, `shots-F34.sh` | #79 `32612c35`, #187 `acf72c67` | safe | 3 min, 60 s | Test windows go to the Dock and come back; one is closed by its tab's button |
| `shots-F22.sh`, `shots-F19.sh` | trunk | safe | 90 s, 45 s | |
| `check-F14.sh` | #204 `62e1fae1` | safe, steps skip themselves | 3 min | The double-click on the wallpaper, Safari, the survey of stock apps. A witness that only listens writes down every press of the button meanwhile, with its place. macOS zooms a floating test window to the full display |
| `check-F21.sh` | #102 `9acaae38` | safe, parts skip themselves | two clicks, five keys | The virtual display; Arbor over every window; apps opened |
| `film-F16.sh` | #98 `a2e34e43` | safe, steps skip themselves | 3 min | Reduce Motion. Pinches and ⌃⌥-scrolls over a test window, each after the net was asked; the helper is on record |
| `perf.sh` | #45 `fbd7e3b5` | safe, steps skip themselves | one drag | By the second reading, not read again since |
| `input-taps.sh`, `witness.swift` | trunk and #193, #204 | **never without the switch**; with it, not before the fixes | | A witness that is killed leaves ⌃, ⌥ or Space down and a gesture unfinished; ⌃ with a wheel is macOS's zoom |
| `suite.sh`, `suite/*.sh` | trunk | safe, steps skip themselves | 16 min on a hosted Mac | One supervised run with one curtain. Docking at a screen edge where macOS tiles, `open arbor://…`, Launch at Login, ⌘Tab, and every press or pinch on the bare Desktop, which is behind the curtain |
| `suite-twice.sh` | trunk | **never**: ends with 77 | | An hour, against a curtain and a sweep that reckon with half of one |

### What an unattended build runs on a person's Mac

Somebody with a Mac may check out a branch they have not read, by hand or from a script, and run `swift build`, `swift test`, `scripts/sim-smoke.sh`,
`scripts/scenarios.sh` and `make e2e`. Nobody reads the branch first and nobody watches, so what these five run has to be harmless by construction:

- **Tests, arbor-sim and arbor-e2e are guests.** Without an `ARBOR_HOME` they use `arbor-guests-<uid>` in the temporary directory, never `~/Library/Application Support/Arbor` (`ArborPaths.home`): one
  `swift test` logs more than `arbor.log` and its predecessor hold. A test that reads the log asks `ArborPaths.logFile`.
- **A test touches nothing but temporary folders and processes it started**: no `UserDefaults`, pasteboard, `NSWorkspace…open`, login item, posted event, Accessibility call on another app, window, alert
  or network. A test that starts a shell gives it a `PATH` and a `HOME` of its own, so that an `arborctl` in a documented example is the stand-in and not the installed one.
- **The three scripts, and every script under `scripts/` that they name, are read by `scripts/lint-mac-shell.py`** like the Mac shell scripts. A step that runs on macOS only (`[ "$(uname)" = Darwin ]`) runs there
  for the first time on that Mac: the keeper of the harness reads it line by line before it merges.
- **`arbor-e2e`** keeps to a home and a socket in a temporary folder and to its own test windows (`ARBOR_ONLY_PIDS`), with shortcuts, menu bar item and prompts off; it posts no input and opens no app.
  It does bring its test windows to the front and gives them the keyboard. A new step may not open an app, a URL or a document, write outside that home, or leave a panel up when the run dies.
- `make <target>` succeeds without doing anything when the target is only left in `.PHONY`, which is how a merge once turned `make e2e` green; `scripts/test-tooling.py` holds every declared target to a rule.

## 6. Traces (`make trace`, `make replay`)

A trace is a recording of everything that passed between Arbor and macOS for a while, as JSON lines: window events, every
call Arbor made with its answer (the frame it asked for and the frame the app took), commands and their results, clicks on
tiles and seam drags, when scheduled work ran, and the raw Accessibility notifications and mouse events underneath.
Never window titles. **`docs/TRACES.md` is the manual**: the format, how recording and replaying work, and what is checked.

**When something odd happens on a real Mac**, make it a file:

```bash
arborctl trace on safari-drag        # a name that says what it shows
…do it again…
arborctl trace off                   # prints the path, under ~/Library/Application Support/Arbor/traces/
make trace-check FILE="<that path>"  # lists every app, command and remark in it; read it: nothing private?
cp "<that path>" collab/evidence/traces/safari-drag.jsonl
make replay FILE=collab/evidence/traces/safari-drag.jsonl     # what happened, as text and drawings
```

`make trace NAME=safari-drag` does the first five lines in one go (`FOR=15` records for 15 seconds instead of waiting
for return). A quick look without any tool: `grep -o '"title":"[^"]*"' <file> | sort -u` must show only `title[1]`, `title[2]`… (`title-1`… in traces recorded before 2026-10-14),
and `grep -o '"app":"[^"]*"' <file> | sort -u` shows whose windows were open. Add a line to
`collab/evidence/traces/README.md`, commit both, and name the file in the bug's issue.

**From then on it is a test.** `TraceCorpusTests` replays every file in `collab/evidence/traces/` against the real controller on
macOS and Linux, in free mode: Arbor may change what it does, but with those windows and those apps' answers nothing may
get lost, no tree may break, no fight with an app may go on for ever, and windows must end where Arbor put them. A
`<name>.expect` file adds expectations in arbor-sim's `expect` language. Strict mode (`STRICT=1`) demands the very calls
that were recorded; `make scenarios` uses it to record and replay each scenario, which proves that nothing crosses the
seams unrecorded.

**Without a Mac**: `scripts/mac-shell/trace-demo.sh` records traces on a cloud Mac with a real pointer, on test windows and on
TextEdit, Calculator, Finder, System Settings and Terminal, and brings them back (section 5). Copy its pattern for
a new question. In tests, `h.run("trace on x")` records into memory (`h.lastTrace`), and `TraceReplayer(try Trace(text: …))` replays
a trace written by hand: see `TraceReplayTests` for apps that refuse sizes, late timers and fights.

## 7. Real apps (`scripts/mac-shell/compat.sh`)

Test windows do what they are told. Real apps resist: minimum and fixed sizes, sizes rounded to character cells, toolbars
where the title bar was, native tabs, sheets, windows that reopen by themselves. The compatibility suite puts Arbor
in front of the stock apps on the same Macs, which nobody is using:

```bash
scripts/mac-shell/run.sh --macs 2 scripts/mac-shell/compat.sh   # 13 apps × 28 steps, every second app on the second Mac; what does not fit into 1000 s is reported as not run
scripts/mac-shell/run.sh scripts/mac-shell/compat-extras.sh     # tabs, sheets, full screen, a growing font: 4 minutes
ARBOR_APPS_HERE=1 scripts/mac-shell/compat.sh terminal safari   # on your own Mac, if you mean it (see lib-apps.sh): only these apps
```

Each app gets a fresh Arbor and the same drill beside two test windows, through `arborctl` and through a real pointer
and keyboard: dock, zoom, back, the Desktop, float, title-bar drags to the edge and onto a window, a seam, the
window's own edge, minimize, ⌘H, activate while out of view, close, reopen, a new window while zoomed in, quit
while framed, relaunch, quit Arbor. After every step `compat.py audit` compares what Arbor believes (`state`) with what the
window server shows: a frame Arbor has wrong, a window sticking out of its slot, docked windows overlapping, a parked
window in view, a window in view that is not on screen. What comes back in `.mac-shell/compat-<run>/`:

| | |
|---|---|
| `matrix.md`, `extras.md` | app × step: ✔, ✘, odd (it held, but look) or – (does not apply), then a line for every cell that is not ✔ |
| `<app>-<nn>-<step>.jpg` | the screen after the step (`-held`: while the button is down) |
| `<app>-story.log` | one timeline: what the script did (`SCRIPT`), every Accessibility and workspace notification macOS sent (`MACOS`), and `arbor.log` |
| `limits.tsv` | how each window resists: smallest and largest size, rounding, whether sizes apply late, where parking really puts it |
| `output.txt` | everything; a step that is not ✔ prints Arbor's state and its slice of the timeline |

On GitHub's Macs Arbor runs as a person runs it (every regular app, shortcuts and menu bar item on) on a display switched to
1600×900. On your own Mac it runs only with `ARBOR_APPS_HERE=1` (an app that was not running is still yours: launched, it may bring back last
time's windows and unsaved documents). Then it is limited to the app under test and the test windows, opens only throwaway documents from a
temporary folder, leaves out every app that is already running (its windows are yours), quits only what it started, and
skips the steps that need a changed system setting or a process it was not started with. It takes no pictures there
(they would be of the whole screen), keeps shortcuts and the menu bar item off, and does move your pointer for twenty minutes.

`lib-apps.sh` is the harness, for scripts of your own: `app_open`, `app_focus`, `app_quit`, `arbor_start_apps`, `audit`,
`watch_start`, `begin`/`want`/`odd`/`finish`; its header lists everything. `apptool.swift` is the view through Accessibility
(`windows`, `grab`: a point of a title bar that is free of controls, `button`, `limits`, `tree`, `press`, `watch`, `set-mode`).
**Run the suite after any change to
`AX/AXWindowSystem.swift` or to how the controller places windows**.

### An ordinary day (`make day`)

A release is decided by what a person would see on an ordinary Mac, macOS at its default settings: no jolts, no lost or stuck window, nothing
moved that they did not move. `scripts/mac-shell/day.sh` plays such a day on one of GitHub's Macs, and a program gives the verdict:

```bash
make day                # scripts/mac-shell/run.sh scripts/mac-shell/day.sh: what GitHub has of the current branch, ten minutes
make day CONTROL=1      # the same day without Arbor: what is found then is macOS's doing or an app's
make day OFF=1          # the same day with macOS's own window management switched off
make day STILL=1        # the same day with Reduce Motion on: no stage, so every move of every window shows
make day SABOTAGE=1     # the script commits the offences itself: does every detector report its own? Three minutes, Arbor is not even built
```

Finder, Safari, TextEdit, Terminal, Notes, Calendar, System Settings, Preview and Mail are open already when Arbor starts, as a person runs it.
macOS's own tiling and "click wallpaper to reveal desktop" stay as they come, which is on (and are seen to act before anything counts), and Reduce
Motion, which the runners come with, is switched off, as it is on a person's Mac. Then the day: windows are docked by key and by real drags, apps are switched
with ⌘Tab, the Dock and the Window menu, ⌘H, ⌘M, ⌘W, ⌘N, ⌘Q, full screen, the view goes in and out, gaps are dragged, a click lands on the wallpaper, pause, Float All,
Quit, a second launch. `run.sh` hands a script no arguments and no environment, so each way of playing the day is a script of three lines that sets a variable (`day-control.sh`, `day-off.sh`, `day-still.sh`;
`DAY_DISPLAY=desk` for 1920×1080 has none yet).

**The Mac only plays and records; the judging needs no Mac.** Everything below reads `samples.log`, so a day that was played once can be judged again, by a
better detector, on any machine: `python3 scripts/mac-shell/jolts.py report .mac-shell/day-<run>/samples.log`.

**The sampler.** A check asks where a window is once things have settled. A person also sees how it got there. `sampler.swift` asks the window
server, which is what the screen shows, for every window's frame and the order of the pile sixty times a second, and writes every change
down with its time. It only looks, never reads a title, and of the keyboard knows only that a key went down. One line per change, `<milliseconds since 1970> <kind> …`;
its header lists the kinds. **The grammar stays as it is**: other tools write files in it that are merged with this one by time, a new kind is a new capital letter, and
readers skip the kinds they do not know.

**A step is one thing a person does**, says what kind of thing it is, and what it may do (`lib-day.sh`):

```bash
act dock-key dock-left "presses ⌃⌥⌘←";  key ctrl+opt+cmd+left;  acted moves=docked front="$W_safari"
```

`acted` waits until nothing has moved and no key or button was pressed for a second, compares what Arbor believes with the screen (`compat.py audit`), and takes a picture. What the person does goes
through `must` (`must drag_window …`): an act that could not be performed is a finding of the script's own and is not judged, because it passes nothing.
While Arbor runs, each chapter is also a trace of its own (section 6), with every step as a remark in it.

**The jolt detector.** `jolts.py` holds every step to the product's rules. Each finding names its detector:

| Rule | Detector | What sets it off |
|---|---|---|
| 1: never fight macOS | `fought` | during a drag macOS's tiling preview (a window of WindowManager's) and Arbor's drop preview are up together; or, with macOS's tiling on, Arbor's is up while the pointer is within 12 points of the left, right or top edge of the screen, which are macOS's; or macOS answered the drag (its preview was up at the drop, or the window ends in one of its own tiles) and Arbor docked the window, or it was moved again afterwards |
| 2: nothing moves that the person did not move | `moved-unasked` | a window moved that `moves=`, `drags=`, `leaves=` and `comes=` do not name. A floating window's frame is its person's: no dock, no ⌘M and no ⌘H of another window is a reason to move or size it; after a way there and back (`returns=<step>`) a window is not where it was |
| 3: a window moves once, to where it ends up | `jolt` | its changes fall into two or more moves, a quarter of a second or more apart; it travelled more than six points beyond the straight road in x, y, width or height; it opened in one place and was moved to another |
| | `pulled` | while the button is down the dragged window moves, from one sample to the next, over 40 points further than the pointer did meanwhile; or, over the drag so far, it is over 40 points ahead of the pointer's travel or over 150 behind it |
| | `stuck` | after the drop it ends neither where it was let go, nor where Arbor's preview was, nor under the pointer by its title bar (its own size given back), nor where it was taken from (a drag called off) |
| | `flash` | out of view before and after, and more than its parking strip showed in between; or it left the screen and came back |
| | `slow` | after one of Arbor's own acts the last window came to rest more than 1,500 ms after the key or the button (odd from 700); after its first act since it started, 3,000 (odd from 1,500) |
| 4: the window you switch to comes to the front and into view | `behind` | at the end `front=<window>` is not the first of the pile |
| | `focus` | its app is not the one in front, or part of it is beyond the space between the menu bar and the Dock; or the app in front changes during an act that is no switch |
| 5: Quit, Float All and pause give sizes back | `size-lost` | `restores=`: a window's size differs from its own, which is the one it had when Arbor started or when it opened, or that the person gave it since (`own=`; `place=` after a mere move). With `places=1`, as after Float All and Quit, its place too |
| 6: what a person presses reaches the apps, at once | `input-held` | `witness.swift log` sits at the far end of the event taps and writes down how late each press, release and key got there (`witness.log`, in the sampler's grammar): a mouse-up over 100 ms late; or, in a round of input, half of the events of a kind over 10 ms later than in the round without Arbor beside it (100 ms for a press on a window of an app that is not in front) |
| what only the script can see | `crash`, `busy`, `left-behind`, `told` | Arbor's process ends unasked, or macOS writes a crash report of its; during `idle <seconds>` it uses over 1 % of a core or writes over 20 lines a minute; after Quit a process or a window of its is still there; the canary word that is in every document's name, and so in every title, turns up in anything the run brings back but the pictures |
| L: no window is lost | `lost` | a window left the screen and the step did not say so (`leaves=`); `everything=1` and less than half of one is on the display (after Show Everything a tile may stand in for it, `tiles=ok`, if a panel of Arbor's is seen where Arbor says the tile is; never for the window that has the keyboard); `comes=` and it is not there |

What a real Mac taught it, each with a situation in `jolts.py --self-test`:

- While the button is down a dragged window goes where the hand goes; what counts is what happens after the drop. macOS holds it back under the menu bar and where its edge meets another window's, and it does not catch up
  (49 points behind at the end of a drag of 130, with no Arbor running), so "how far from where the pointer carries it" says nothing; but it never runs ahead. macOS also gives a window it had tiled its size back under the hand.
- What an act sets off shows a moment later, and a click of 40 ms can fall between two samples. So clicks and keys are counted, not watched for, and `acted` never takes the screen for quiet sooner than 350 ms after it asked.
- Setting a size and then a place shows as two frames a few milliseconds apart, which is one move on a straight road. A sheet or a dialog follows its window at each of the two stages, so it does go out of its way: odd, not a failure, and explained by itself (`"explained": "follows its window"`).
- macOS's own animations change frames: a window grows from some 95 % as it opens, a sheet slides, the road into and out of the Dock is a curve. None of that is a jolt.
- Arbor's own panels are not windows, nor are WindowManager's. Arbor's focus ring is a window at the ordinary level right in front of the focused one.
- Arbor moves the real windows under its stage, a panel over the whole display that shows a picture of the desktop and a stand-in for each window. Nobody sees them there. So all that a window does while the stage is up counts as one
  change, seen when the stage comes down; what the stand-ins do meanwhile is on the film, not in the samples. What a window does once the stage is down counts in full.
- To bring a window into view that is out of view the view has to move, so a switch to such a window may move anything.
- What happens between a step's end and the next step's beginning counts for the step that ended.

What comes back in `.mac-shell/day-<run>/`:

| | |
|---|---|
| `day-report.md` | the rules, how many steps checked and broke each; every finding with its step, its window and the road the window took; then every step with what moved, how many times, through how many frames, in how many milliseconds |
| `<nnn>-<slug>.jpg`, `<nnn>-<slug>.story.log` | for every step with a finding: the screen at its end, and one timeline of what the screen showed (`SCREEN`), what macOS reported (`MACOS`), what the script did (`SCRIPT`) and what Arbor logged |
| `day-findings.json`, `run.json` | the findings for a program, each step with its kind (`act`) and whether it was `judged`; what the run was: commit, script, kind, tiling and whether it was seen to act, display, apps, seconds |
| `samples.log`, `traces/` | the samples, for `jolts.py report`, `trace <samples> <step> [window]` and `story`; Arbor's own traces, for `make replay` |
| `sabotage.md` | of the sabotage run: each step, the offence committed, what was reported |

**Three controls**, without which a silent detector means nothing. *Without Arbor*: apps move their own windows, and so does macOS, so read a finding against the control before
calling it Arbor's. *Sabotage*: `apptool set-frame`, `raise`, `activate` and `close` do to real windows what Arbor must never do, and a program that passes for Arbor (`impostor.swift`) does what only its own process can do wrong, one offence a step with honest steps between, and `jolts.py sabotage` fails
unless every offence is reported by its own detector, by no other, and nothing where nothing was done. *The self-test*, part of `make lint`: over a hundred situations, each with the finding it must or must not give.

**What it cannot see**: two changes within one sample (a step during which the sampler saw nothing for more than 250 ms does not count as judged, and the report says `blind for … ms`; what it did see stands, because a gap
can hide a move and cannot make one up), anything that is
drawn without a window moving, and whatever only a trackpad, a second display or a person's own apps bring out.

**The acts, and journeys written by a program.** `lib-walk.sh` has one word for each thing a person does to a window (its header is the list): `switch_dock safari`, `dock_key left`,
`drag_onto terminal safari right`, `view frame`, `minimize`, `restore`, `full_screen on`, `wallpaper_click`, `title_double_click finder`, `pause`, `quit_and_start`, `idle_act`, `display plug`… Each is a
step of `lib-day.sh`'s that looks at the state for itself: it knows its kind, what it may move and which window has to end in front. An act that does not apply is left out, with a line in the output
and no step; what a person would do first is done first, as an act of its own (a covered window is brought forward before it is dragged); an act that applies and cannot be performed is a finding. So
whoever writes a journey needs the words and nothing else. `day.sh` is written in them by hand. **A walk** is a file of them, one act a line, that bash can run as it stands:

```bash
python3 scripts/mac-shell/walk.py 4711 --acts 110 --display two --tiling off     # prints the walk from that seed: the same on every machine
python3 scripts/mac-shell/walk.py 4711 --control                                 # its control: the same file, played without Arbor
python3 scripts/mac-shell/walk.py 4711 --cast browsers --reduce-motion on        # another cast; no stage, so that every move of every window shows
```

`walk_begin <cast> <display> <tiling> [seed [commit]]` prepares the Mac, opens the cast, sees macOS tile (or not), starts Arbor and writes the manifest; `walk_end` brings back what is hidden or minimized,
quits Arbor, reaches every window, and reports. Setting the scene (`acted setup=1`) is in the report and is no act. `walk-sample.sh` is the walk from 4711 (`make lint` checks that it still is);
`day-sit.sh` makes an arrangement and leaves the Mac alone for six minutes; `survey-casts.sh` asks a Mac which other apps it has and how their windows resist (`survey-browsers.sh`: the browsers alone).
The casts are those of `docs/VIABLE.md`: `stock`; `browsers` (Safari, Chrome, Firefox and Edge with two windows each, Finder, TextEdit); `awkward` (a window of one size, two that are no narrower than
half a laptop's screen and greet with a sheet, two that cannot be minimized, tabs, an open panel, an app without a window). A member that opens no window is left out; six are needed.

**A whole gate** (`docs/VIABLE.md`). `gate.py plan` works its rows out of the numbers on that page: four journeys for each cell of macOS's tiling and the displays, the casts and Reduce Motion spread over
them, a control for each cell, the sabotage run, two sits: 33 parts, some 230 minutes of Macs. `gate.sh` is one script that plays whichever part it is told: `run.sh` says only which part of how many a
playing is (`$MAC_SHELL_PART`, `$MAC_SHELL_PARTS`), and how many there are says which dispatch it is.

```bash
python3 scripts/mac-shell/gate.py plan first          # the two user-hours a commit is given first; `rest`: the other 31 parts; `whole`: all 33
scripts/mac-shell/run.sh scripts/mac-shell/gate.sh scripts/mac-shell/gate.sh      # plays `first`: as many times gate.sh as the plan has rows
python3 scripts/mac-shell/gate.py row <commit> 4 33   # what part 4 of 33 is on that commit; `gate.py acts <seed> <display> <acts> <cast>`: its walk
python3 scripts/mac-shell/viable.py ledger <commit> <every directory with a run.json> -o ledger.json
python3 scripts/mac-shell/viable.py check ledger.json --runs jobs.txt             # VIABLE, NOT VIABLE or INVALID, with the reasons
```

A walk is seeded from the commit, so it cannot be a file in it: it is written on the Mac and comes back as `walk.txt`. The seed also holds the first number with which the walks of that commit, **as they
are written**, have enough of every kind of act and stay under the time a run may take, so that a gate does not turn out two resizes short after four hours of Macs; nothing a run brought back has a say
in it. `gate.py --self-test` (in `make lint`) holds the plan to the page: raise a number there and it fails until the plan has grown. `run.json` is written as a script begins (`"started": true`) and completed at
its end; whoever hands out the parts leaves a stub (`"started": false`) in each one's place first, and only a part that has nothing but a stub, or whose job GitHub gave no Mac, may be played again in a later attempt.

**What hosted Macs taught about the measuring itself.** Nearly all late samples fall while nine apps start cold, so the sampler's account runs from the first act that counts to the last, in one stretch,
and the whole run's figures stay beside it (`whole-…`). What is over within one sample (26 ms) shows to nobody: an offence planted for the sabotage run lasts a tenth of a second. A window that is wholly
transparent is not on the screen. The line Arbor draws round the focused window lets presses through, so `apptool top-at` and `grab` look through it. macOS's own tiling does not answer every drag, an app does not obey
every key: a journey checks that what it did took hold, and otherwise the act counts as not performed. A release has been seen to take 57 ms to reach the apps with no Arbor running: a single one has 100.
**A figure over all events says what a journey is made of as much as who held anything back**: a press on a window of an app that is not in front is held by macOS itself, which brings the app forward first (17 to 137 ms with no Arbor running), any other press takes 1 ms. And Macs
differ, and drift. So who holds input back is asked in **rounds of input** (`input_round` in `lib-walk.sh`): the same presses, releases, keys, scrolls and a drag inside a window, before Arbor starts, when it has started, before the last Quit and after it. `jolts.py` holds started to
before and last to after, by the median of each kind (`forward`, `down`, `up`, `key`, `dragged`, `scroll`); where before and after differ, the Mac moved and the journey says nothing of that kind. The rounds are instruments, not acts. An act that could not be performed
(`performed=no`) is not judged, and listed.
`probe-presses.sh` asks who holds such a press back, in rounds with different settings and one after Quit. Its answer: macOS. The round without Arbor was the slowest. Its first run had a baseline that
was none (after Quit one window covered the others, and every click fell on the app in front already): **a control has to do the same thing, not only run the same lines.**

For a script of your own, `lib-day.sh` is the harness below the acts (its header lists everything) and `jolts.py`'s header lists the marks and keys.

## 8. Type-checking macOS-only code on Linux (`make typecheck-mac`)

Half of Arbor builds only on macOS: `ArborKit/{AX,UI,Input,App,IPC}`, `Arbor`, `arborctl`, `arbor-e2e`, `ArborTestWindows`, the test files with `#if os(macOS)` in them, and the Mac shell's helper tools (`scripts/mac-shell/*.swift`), which only a script that is already running on a Mac compiles. `make typecheck-mac`
type-checks all of it on Linux against stand-ins for the parts of AppKit, QuartzCore, CoreGraphics, ApplicationServices, Carbon, `os`,
ServiceManagement, Combine and SwiftUI it uses (`scripts/typecheck-mac`, with a README): names, labels, types, optionals, overrides, required
initializers, access control, actor isolation and `Sendable`, under Swift 6 rules (the helpers under Swift 5's, as on the Mac), in half a minute. `REF=origin/some-branch` checks another
commit's sources. An error there is nearly always real; a pass is not proof, and nothing runs. Use it before every push that touches those folders, and
when resolving a merge conflict in them. The README lists what it cannot see: captures in C callbacks, availability, macros such as `#Preview`.

`make typecheck-mac-selftest` lays the files of `scripts/typecheck-mac/probes`, macOS-only code with right and wrong lines side by side, into a copy of the sources, at
least one into each folder, and expects every line marked wrong to be reported and no other. Run it after changing the tool. It is how we learnt that
`swift build` reports only the first failing stage, which is why the tool calls the compiler itself, and that `#if os(macOS)` was being skipped.

## 9. The real Accessibility layer on a model of a Mac (`make mac-on-linux`)

Everything above the protocol `WindowSystem` is tested against stand-ins for it. What is below, `Sources/ArborKit/AX`, 1,650 lines full of state, ran in no headless test, and two of the three faults of the first day on hosted Macs lay there: no stand-in
at the seam can be wrong the way macOS is below it. `make mac-on-linux` compiles the layer as it is, links it with the stand-ins of section 8, of which the part the layer uses has been given behaviour backed by one model of a Mac
(`scripts/typecheck-mac/stubs/FakeMacOS`: apps, windows, the window server, NSWorkspace and what it caches, screens, the mouse, a clock, and a queue of what is on its way to Arbor), and runs it on Linux: 180 stories and a random walk in five seconds, after a build of four
seconds to two minutes. `scripts/mac-on-linux/README.md` has all of it; in short:

- **Two storeys.** `AXWindowSystem` alone with a listener that writes down what it reports; and the real `Controller` on top, wired as in the app, where the checks look at the screen ("⌘Tab to an app whose window is out of view: the view moves to show it").
- **Polite first, then rude**, with the rudeness that was seen on a Mac and the numbers from the traces: reports in the other order, a `frontmostApplication` that lags, lists that are behind, apps that hang in the middle of a move and carry the calls out when they wake, ends nobody reports, releases that are swallowed,
  a window server that is ahead of the app, or late. What is a guess is marked "Guess" in the model.
- **Time is the model's**: `mac.pass(0.3)`, no waiting, no threads, no chance. A copy of the sources is rewritten in a few ways, line for line (`retime.py`), which fails the build if anything in ArborKit knows another clock.
- **`known-failures.txt`**: the run fails when a check that is not listed fails and when one that is listed passes; a rule of the walk is listed with the number of seeds that break it, and another number is news. **Whoever lands a cure in the layer deletes its lines.**
- **`make mac-on-linux-selftest`** takes twenty-three known cures out of the copy, one at a time, and expects the stories about them to go red.
- **The rude walk**: seeded, under four kinds of bad manners in general and once politely as a control; a breach prints the shortest script, which `--replay` plays. `ARGS="--only walk --seeds 1-500"` is a hunt.
- **`REF=origin/fix/some-cure make mac-on-linux`** holds another commit's layer against this checkout's stories: how a cure is tried before a Mac sees it, as the one for the app switch was. `COVERAGE=1` says which lines no story enters (92 % of `AXWindowSystem.swift`'s are entered).

Run it after every change under `Sources/ArborKit/AX`, and tell a story for every fault a Mac shows there. A green story proves the layer right about what we have seen or guessed, not about a Mac; a red one that rests on a guess is worth a run on a hosted Mac.

## 10. The real-window suite (`scripts/mac-shell/suite.sh`)

`make parity` calls a shipped feature *tested* when its unit and scenario tests pass, and *verified* when its
real-window steps passed too. The suite is where those steps live: every shipped feature exercised the way a person
does it (drags to screen edges and onto windows, seams and edges, title-bar buttons, every shortcut, the menu bar,
`open arbor://…`, settings.json, quitting, killing and restarting), and checked against the window server.

```bash
make suite                                                       # on a Mac: sixteen minutes on a hosted one (SECTIONS="30 60" for some)
ARBOR_KEEP_EVIDENCE=1 scripts/mac-shell/run.sh --macs 2 scripts/mac-shell/suite.sh   # all of it on two of GitHub's Macs, side by side, from anywhere
scripts/mac-shell/run.sh scripts/mac-shell/suite/30-seams.sh     # one section, about a minute
scripts/mac-shell/rehearse.sh                                    # all of it against stand-ins, on Linux, for nothing
scripts/mac-shell/rehearse.sh scripts/mac-shell/suite/30-seams.sh
```

**On a person's Mac** it is one supervised run with one curtain ("On a person's own Mac", in section 5, says what that means and what
`lib.sh` declines there). It needs Accessibility for the terminal, five quiet minutes before it starts (or `ARBOR_BUSY_OK=1`) and no Arbor or other window
manager running; it moves the pointer and presses keys, so hands off meanwhile; it uses only its own test windows, changes no setting and
registers nothing. ⌃C stops it, a right-click on the curtain too. What needs more than that skips itself: docking at a screen edge where macOS tiles there itself and Arbor stands aside (`screen_edges_dock`: only a throwaway Mac has that switched off),
`open arbor://…` (which app opens those links is a setting), Launch at Login, real ⌘Tab (`on_throwaway_mac`), and claims about a press or a pinch on
the bare Desktop, which is behind the curtain (`desktop_is_bare`). Nothing in it depends on the size of the screen. Rehearse that mode too:
`ARBOR_REHEARSAL_AS=person scripts/mac-shell/rehearse.sh` shows what a claim loses to the nets.

`suite.sh` builds, then runs `scripts/mac-shell/suite/[0-9]*.sh` in order, each as its own process with a time limit (150 s), so one
section's failure, crash or hang costs the others nothing. It ends with a table, every failed check again, and exit code 0 only if
everything passed or failed as it is `known` to. A section is an ordinary Mac shell script.

**Evidence.** `claim` and `check` print, and record in `mac-shell/evidence/<section>.txt`, what `arbor-e2e` prints:

```
▸ drag a window to the left screen edge: a preview shows where it will land, and it docks there
  ✔ a drop preview is on screen while the button is held
  ✘ it reaches the left edge of the screen — its left edge is at 170, not 12: 170 216 480 352
```

With `ARBOR_KEEP_EVIDENCE=1`, which `make suite` sets, `suite.sh` on your own Mac and `run.sh` after a run on GitHub's copy the sections' files to `collab/evidence/suite-<section>-latest.txt`, where
`scripts/parity.py` reads them with the other `*-latest.txt`. Commit them. A claim is borne out when it has a check and no
✘; one without checks, or the last one of a section that was cut off, counts as not run. The files carry no window ids
or times apart from the first line, so two runs that went the same way differ in nothing else:
`scripts/mac-shell/suite-twice.sh` runs the suite twice in one job and prints what differed, which is the flakiness test. A ✘
also takes a picture (`fail-<section>-<n>.png`) and prints the state and what `arbor.log` gained since the claim.

**Adding a feature: five lines.** Pick the section it belongs to (or start `suite/NN-<feature>.sh` from the three lines
every section begins with) and write a claim whose title says what the person does and what happens:

```bash
claim "double-click a docked window's title bar: the camera frames it"     # unique across the suite
proves T40                                                                # the items of collab/parity.json it is proof of
dblclick $(titlebar_of "$W1")                                             # real input, not `ctl`
check "the window fills the screen" eventually fills "$W1"                # what the window server says
check "the others are out of view" eventually out_of_view "$W2"
settled                                                                   # ✔ windows match Arbor's layout
```

Then rehearse it (`scripts/mac-shell/rehearse.sh scripts/mac-shell/suite/<section>.sh`, and again with `ARBOR_REHEARSAL_AS=person`) and run that section on a Mac. `make suite` ends by
running `scripts/mac-shell/suite-parity.py` (after `run.sh`, run it yourself): an item ALL of whose claims hold gets them in its `e2e` list
in `collab/parity.json`, which is what makes `make parity` call it verified; an item one of whose claims failed or has not
run gets none, and the script says which and why. Commit the evidence, `parity.json`, and `docs/FEATURES.md` after
`make parity`. Rules that keep the suite worth having:

- **The way a user does it.** `ctl` is for setting the stage and cleaning up. If only a command can reach the feature,
  say so in the title ("by command").
- **No window ids, times or counts that vary in titles and check names**: say "the first window".
- **Wait with `eventually`, never with `sleep`**, and prove absence with `stays` (`stays fails ran desktop`).
- **Leave the session as you found it**, or start your own (`arbor_stop`; `arbor_start 3`): a session costs three seconds.
- **A claim that fails because Arbor is wrong stays**, goes into a report, and gets `known "<what happens; who is on it>"` on the line
  after `proves`. Its ✘ are printed and recorded as ever, and `suite-parity.py` keeps it out of `parity.json` (where it would make
  the item *broken* and `make parity` fail for everyone), but it no longer fails the run: exit code 0 means that nothing NEW is
  broken. When it holds on real windows the run says so; take the mark off then. If the claim is what the reference
  describes, the item is `partial`, not `shipped`.
- **Nothing that changes the Mac** outside `if on_throwaway_mac`, no number that depends on the screen (`desktop_point`, `edge_point`,
  `zone_of`, `width_of` give you relative ones), `take "x y w h" real_frame_of $W1` rather than `read … <<< "$(…)"` (arithmetic makes a press at 0 0 of
  an answer that never came), and `key_to <window> cmd+w` rather than `key cmd+w` for keys that are meant for the app in front.
- **A flaky claim is worse than none**: run the section twice; fix or drop what differs.

## Pictures without a screen (`OffscreenPicture`)

What Arbor draws can be looked at, and checked, without a window, a permission, a script or anybody's screen. `Tests/ArborKitTests/OffscreenPicture.swift` (macOS only) is a bitmap in memory
that the real AppKit code draws into: an `NSView` with its subviews, a `CALayer` with its sublayers, or anything that draws into the current context, at scale 1 or 2, in light or dark mode said out loud
(the Mac's own setting plays no part). A test reads pixels back and saves the picture:

```swift
#if os(macOS)
  @testable import ArborKit   // panels and views are internal

  @Test @MainActor func theRingIsDrawnInBothModes() throws {
    try OffscreenPicture.each(size: CGSize(width: 300, height: 200), item: "F37", name: "ring") { picture in
      picture.draw(view)                                  // or picture.draw(layer), or picture.draw { context in … }
      #expect(picture.pixel(150, 2).alpha > 0.9, "the line along the top")
    }                                                     // .build/pictures/F37/ring-light@1x.png, …@2x, ring-dark@1x, …@2x
  }
#endif
```

Such tests run inside an ordinary `swift test`, and **leave their pictures in `.build/pictures/`**.
`OffscreenPictureTests` checks the tool itself: which way is up, how large a point is, which mode.

- **A whole display at rest**: `picture.draw(display: harness)` (`Tests/ArborKitTests/OffscreenScene.swift`) draws the `OverlayScene` the real controller made, back to front: a stand-in wallpaper, the backdrop, stand-in windows, the tiles.
  Windows opened under the names of Apple's apps get real icons and colours. `AppearancePictures` in `TileDrawingTests.swift` is the example. An overlay that is not drawn there yet is a few lines in `draw(_:windows:)`.
- **Draw only what the test made itself**, so that nothing of the person whose Mac it is can be in a picture: no running apps, their icons or their windows' titles, nothing read from the screen. The icons of Apple's own apps under
  `/System/Applications` (`NSWorkspace.shared.icon(forFile:)`, which launches nothing) are the same on every Mac.
- Save before checking, or use `each`, which saves even when a check throws: a picture of what went wrong is worth more than one of what went right.
- A type that is `private` in its file cannot be reached; make it internal, or better, move the drawing into a function that takes a model (`UI/TileDrawing.swift`).
- **What it cannot show** is what the window server adds: blur behind a window, window shadows, levels, which panel is in front, hover, clicks. Core Animation's `render(in:)` leaves out masks, filters and animations. Those still
  need real windows (section 5).
- On Linux the files are skipped (`#if os(macOS)`); nothing type-checks them there yet.

## The tests on every core (`make test-fast`, `make gate`)

`swift test` compiles the tests on every core and then runs them on one: nearly every test is bound to the main actor, so they
queue. On Linux `scripts/fast-tests.py run` (`make test-fast`) gives each test file a process of its own, as many at a time as there
are cores, the biggest files first, each with a temporary folder of its own: 100 seconds instead of 330 on four cores, and the same tests
with the same outcomes. A file that passes prints nothing (`--verbose` if it should); a file that fails prints what `swift test` would
have. Afterwards each file is held to its source: as many tests must have run as it declares for Linux, so a filter that matches
nothing, which `swift test` lets pass, fails here; and the sources are held to what was built. A compile-time condition in a test
file that it cannot answer for Linux is refused, with the file and the line: add the answer to `ON_LINUX`. **A test may not read the
sources of the tests** (`Tests/…`): where the tests are divided among machines it would see another text than in the checkout.

`make gate` (`scripts/gate.sh`; `make check-fast` is the same) is everything a change must pass on Linux, each thing once: lint, the build,
the tests as above, the smoke runs and the scenarios, then side by side the type-check of the macOS-only code, the tools' self-test and
parity, which reads what the tests left instead of running them again. One line for each step; all output in `.build/gate/`. It goes on
after a failure, so one round tells all. What `make check` runs besides lint, the build and the tests it reads from the Makefile, so a step
added there is a step of the gate.

The same script can divide the tests among several machines, the compiling too (`plan`, `cut`, `join`, `same`): its header says how.
`scripts/test-fast-tests.py`, part of `make lint`, holds it to a table of Swift it must read rightly or refuse.

## The tools test themselves (`scripts/test-tooling.py`)

`parity.py`, `ci-step.py`, `scenarios.sh` with arbor-sim, `lint-imports.py`, `lint-mac-shell.py`, `mutate.py` and `fuzz-launch.py` are what says "all is well", so each is given
situations that must come out as failures: a misspelt status, a renamed test or step, a record of the tests cut off by a
crash or with a torn line, a scenario whose commands do nothing, an `rm -rf` of a variable nobody checked. The safety nets of `scripts/mac-shell/lib.sh` are tried for real: small scripts
run against stand-ins for a Mac and are interrupted, timed out and killed, with a full disk, with somebody's window under the pointer, beside a running Arbor
(`ARBOR_TEST_BASH=<a bash 3.2>` tries them under macOS's own shell). `make check` runs it. When you teach one of these tools something, add
the situation that would have fooled it.

The two scripts that decide what CI's Mac does have tables of their own, which the job `linux-lint` runs: `scripts/test-ci-changes.py`
(whether a Mac is needed, which tests it runs, and whether it may build upon a cache) and `scripts/test-ci-tests.py` (which tests a Mac can say something about, the record of
a run, and the net that fails when a test ran nowhere). Most of their rows are situations in which the answer must be the careful one.

**Never judge by what `swift test` prints.** It passes the tests' output on in pieces of 4096 bytes and drops every piece that is not
valid UTF-8 by itself, that is, one that ends or begins inside a ✔, ◇, ➜ or ↳: two pieces at a time, some hundred lines, and the exit code
stays 0 (Swift 6.4.1; 60,000 lines with one ✔ each lose three to five thousand in every run, the same lines in ASCII none). For months that read as
"test … not found" about one gate in seven. `make test` therefore asks Swift Testing for its own record (`--event-stream-output-path`, one line of JSON per
test and per event; each test process writes a file, and `swift test` puts them together when the last has ended, also after a crash, but not
when it is killed itself; in CI `ci-tests.py run` asks for the same and leaves it at `<record>.events`), and `parity.py` and `ci-step.py` read that: `parity.read_reports`. A tool that wants to know what a test did reads it too;
the exit code says whether all went well; the output is for people. (`mutate.py` judges by the exit code and takes only the names it shows from the output.)

## Mutation testing (`scripts/mutate.py`)

The levels above say whether Arbor works. This says whether the first three would notice if it stopped:
which lines of the headless stack can break without a test, the smoke run or a scenario failing.

The script copies the checkout to a scratch folder next to it (`<checkout>-mutants`, or `--scratch DIR`) and
changes one thing at a time there: flips a comparison, swaps `min` and `max` or `left` and `right`, changes a
number, drops a statement. After each change it builds and runs what `make check` runs. **The checkout itself
is never changed**, so it can run beside your work. It needs `swift` on the path: on a Mac, or on Linux with
Swift, run it as it is; where Swift lives in a container, run it there.

```bash
scripts/mutate.py --list Sources/ArborCore/Drop.swift          # show the mutants, run nothing (needs no Swift)
scripts/mutate.py --per-file 0 Sources/ArborCore/Drop.swift    # every mutant of one file
scripts/mutate.py --out /tmp/mutants.tsv                       # a sample of every headless source file
```

One line per mutant: the outcome, `file:line`, what was changed, the line before and after, and what noticed.

| Outcome | Meaning |
|---|---|
| `killed` | A test (up to three are named), `sim-smoke.sh` or `scenarios.sh` failed, or the tests hung: the line is checked |
| `uncompilable` | The change did not build; it says nothing |
| `timed out` | The build did not end within 15 minutes; it says nothing either. Run it again on a quieter machine |
| `SURVIVED` | Everything still passed |

**Reading `SURVIVED`.** Either nothing checks that line, or the change makes no difference (a `<` that could as
well be `<=` because the values are never equal, a default that every caller overrides). The script cannot tell;
a person decides. For the first kind write the missing test: work out what a user would see go wrong when the
line is wrong, and assert that. For the second kind do nothing. Do not write a test whose only point is to kill a mutant.

**Time.** Each mutant costs an incremental build and the tests, ten to twenty seconds on four cores that have nothing else to do
(minutes next to other builds), after a full build of the copy. The tests of a mutant are ended, and the mutant counted as killed, after two
minutes or five times what they take with nothing changed, whichever is more. Without arguments it takes at most 12 mutants from each file of `ArborCore`, `ArborKit/Controller` and
`ArborKit/Platform` and from `Expectations.swift`: some hundreds, so an hour or two. Name the files you changed instead, or
use `--shuffle`, so that a run cut short has still looked everywhere. `--shard 0/3`, `1/3`, `2/3` split the work
between copies side by side; give each its own `--scratch`, because a run starts by emptying that folder.
`--seed N` picks another sample. `--again <an earlier --out file>` runs only what survived there: the way to see
whether the tests you wrote since do their job. It is not part of `make check` or CI.
## Installing, signing and releasing

`scripts/release-tools-test.sh`, part of `make check` and of CI, tests what needs no Mac in a temporary copy: `version.sh`,
`release-notes.sh`, and `publish-release.sh` against a stand-in for GitHub's API on the same machine (left out where
there is no curl, as in the Swift image for Linux).

`scripts/candidate-check.sh` builds a commit the way `make install` does (`make app`: `-c release`, bundled, stamped, signed, here ad hoc) and looks
at the result: the signature, the stamps, and what the two binaries say to `--version`. Every other build, CI's
included, is a debug build. It changes nothing outside the checkout and a temporary folder, reads no keychain, and installs and
starts nothing.

`scripts/mac-shell/check-F13.sh` proves the rest on a Mac: the signing identity, that two different builds share one
designated requirement, `make install` and `make uninstall`, the version everywhere, update checks against GitHub and
against a stand-in, the hardened runtime, and `make release`. It is **safe on your own Mac**
(`mkdir -p mac-shell && bash scripts/mac-shell/check-F13.sh 2>&1 | tee mac-shell/output.txt`): no sudo; a throwaway `HOME`,
`ARBOR_HOME` and keychain in `/tmp`; a clone of the checkout to build in; the account's keychain search list and default keychain
are only read, and compared before and after; the copies of Arbor it starts arrange nobody's windows; whatever has a time
limit is stopped with everything it started; what might put one of macOS's dialogs on the screen is tried once, for
twenty seconds, before anything depends on it. Its header says what you may notice, and names the one exception (three
copies run with their watchdog).

`scripts/mac-shell/check-F13-system.sh` is for GitHub's throwaway Macs only (`needs_throwaway_mac`): it writes a grant into the
permission database and shows that the next build inherits it and an ad-hoc build does not, tries launch at login,
runs `make install` the way a person does, and takes pictures of the menu and of a downloaded copy's first launch.

## Chaos (`ChaosTests`, `arbor-sim chaos`)

A window manager holds people's windows, so the worst it can do is crash or lose one. The chaos test
throws random commands and window events at the real `Controller` and checks every invariant after each
one. It is a function of its seed: no clock, no system randomness, no dictionary order.

**What it does.** `ChaosGenerator` looks at the state of the world and picks the next `ChaosAction`, mostly one
that makes sense there and sometimes one that does not: apps open, close, quit, hide, minimize, change Space, go full
screen, retitle and change their size limits; the user moves, resizes, focuses, clicks tiles, drags seams, types and chooses in Go to…, and drags
windows in pieces (`grab`, `carry`, `release`) so that anything can happen in mid-drag; every `Command` with valid
and invalid arguments, nonsense lines and `arbor://` URLs; displays added, removed, resized and rearranged, with macOS
reporting the windows before, after or never; timers fired early or late; settings.json edited sensibly and badly, and every setting in
`SettingsSchema` set to values it takes; commands from a shortcut, the menu or a gesture; keys held and let go (a peek); pinches in pieces; apps coming
to the front; native tabs opened, chosen and closed; drags whose release nobody sees; windows on Spaces that are not showing at launch;
apps that refuse to move, snap back, round their size or stop answering for a while; and Arbor itself pausing, quitting, crashing and being
launched again, with windows gone or renumbered, days gone by, or state.json damaged meanwhile.

**What it checks**, after every action: `Controller.invariantViolations()` (`Controller+Invariants.swift`: trees, camera, history
and saved views, membership, layouts not stale and on their display, parking, nothing remembered about closed
windows) and the rules in `ChaosInvariants.swift` that need the fakes' side (Arbor's picture of the windows is the window
system's; docked windows are in their slots or a timer is about to put them there; nothing overlaps; parked
windows are out of view; nothing Arbor placed is lost beyond the displays; overlays match the layout; no drop
preview without a drag; one focus ring, around the window that has the keyboard; a floating window in view goes out of view only
when the camera moves; a pinned window is always in view; Go to… is open only while Arbor runs, on a display that is there and with nothing being
dragged, and the window chosen in it has the keyboard and is in view; a saved slot that waits for its window is in a tree and has a timer that ends the
wait; Arbor gives up only on windows that something keeps moving; only known timers, and they run dry; windows Arbor does not arrange are never moved;
`state` and state.json survive JSON; after `quit` or `pause` everything is back in view; a restart keeps the shape of every tree).

**Running it**

```bash
swift test --filter Chaos                                              # 40 seeds × 200 actions, part of every `make check`
ARBOR_CHAOS_STRICT=1 swift test --filter randomActions                 # … and fail on a script nobody knows (see below)
ARBOR_CHAOS_SEEDS=5000 ARBOR_CHAOS_STEPS=400 swift test --filter randomActions   # a long hunt (ARBOR_CHAOS_FIRST=… starts elsewhere)
ARBOR_CHAOS_TRACE=1 swift test --filter randomActions                  # prints each action to stderr first: locates a crash
swift build -c release --product arbor-sim                             # four times faster, for thousands of seeds:
.build/release/arbor-sim hunt 1 2000 400                               #   seeds 1…2000, 400 actions each; failures shrunk, counted by rule
.build/release/arbor-sim hunt 1 200 400 --known=vanished-strip         #   hunts a known failure too (`--known`: all of them)
.build/debug/arbor-sim chaos 1304 400                                  # one seed, printing the script as it goes
.build/debug/arbor-sim replay < script.txt                             # a script, with a drawing after each step
.build/debug/arbor-sim shrink < script.txt                             # shrinks in child processes, so crashes shrink too
.build/debug/arbor-sim replay --frames < script.txt                    # … and after each step Arbor's own moves, then where every window is
.build/debug/arbor-sim ways-back < script.txt                          # which of Float All, crash and launch, quit returns every window
ARBOR_CHAOS_ALL_ON=1 .build/release/arbor-sim hunt 1 2000 300          # everything that ships switched off, switched on together
ARBOR_CHAOS_DESKS=1 .build/release/arbor-sim hunt 1 2000 300           # walks about displays: ten times the changes, in a Mac's orders, each display keeps its size
ARBOR_CHAOS_WINDOWS_FIRST=1 .build/release/arbor-sim hunt 1 2000 300   # mostly the order in which the windows speak before the displays; a window has spoken 1 to 40 s before
.build/release/arbor-sim hunt 1 2000 300 --pass=slot,undo-redo         # walks on past those rules too, counting them: for a hunt after one rule that others would end first
.build/debug/arbor-sim replay --frames --go-on < script.txt            # plays on past a broken rule: for steps added to see what fetches a window
```

**A cure is hunted with a control**: the same seeds, under the same generator and rules, on the tree with the cure and on the tree without. Compare the lists of failing seeds, not
only the counts: "no seed fails on the sum alone" is the finding. A seed that does is replayed on the control as a script, because a cure also leads walks elsewhere. The same
goes for blame: before a family is given to the owner of the newest merge, its scripts are replayed on the tree without that merge.

**A rate in walks is not a rate on desks.** A walk closes a lid as rarely as it does anything else; a person does it every day. Judge a finding by what a person has to do to get there.

**Where Arbor puts a window**, at the step in which it makes the move: `placed-out-of-reach` (fewer than 40 × 12 points of title bar on a display, and Arbor does not count the window as
out of view); `placed-partly-out` (a floating window hangs further over an edge than anybody but Arbor ever left it on this display at this size); `placed-mostly-out` (nobody ever left it across an edge, and
under half shows: with "⌃⌥0 does not fetch it" this is the product owner's measure of a blocker); `grown-while-hanging` (made larger where its user left it hanging; as much shows as before);
`docked-partly-out` (kept larger than its slot, it hangs out of the display); `left-its-place` and `moved-for-nothing` (a display only moved, or nothing changed at all, and a floating window was moved).
`replay` says `REFUSED:` for every command Arbor refuses and every line that is no command and no event: a script whose `hold` was refused says nothing about holds.

**The seven rules as nets** (`ChaosInvariants+SevenRules.swift`). They ask what the window system saw, never what the controller believes, and each has a control in `ChaosSevenRulesTests`: a fault
done to the world as if Arbor had done it, at which the net has to speak, beside the same story without the fault, at which it has to be silent. `ChaosRunner.detector(for:)` gives the detector of `docs/VIABLE.md`, section 5, that a rule stands for.

| Rule of the product | Rules of the walks | Detector |
|---|---|---|
| Nothing moves until the person docks something, and nothing that was not asked to | `moved-before-any-dock`, `fetched-before-any-dock`, `moved-at-launch`, `moved-at-resume`, `moved-unasked`, `there-and-back-moved`, `pause-and-resume-moved`, `dragged-gap-did-not-last` | `moved-unasked` |
| A start takes nothing out of view, but for what Show Everything itself has out of view; a quit leaves nothing there | `start-took-out-of-view`, `launch-keyboard-in-a-tile` (the keyboard is in such a window, and takes the view), `quit-left-out-of-reach` | `lost` |
| A window moves once, to where it ends up | `moved-twice` (in the step of the command or event), `moved-again` (later, with nobody touching anything); `-sizing` where its app refused a size, `-sizing-again` where it had refused in the same way before. A first meeting in which each coordinate goes one way only is no jolt | `jolt` |
| Out of view means out of view, and nothing goes on for ever | `flashed-into-view`, `flashed-out-of-view`; `moved-over-and-over` (more than three moves with nobody acting) | `flash`, `stuck` |
| The window you switch to comes to the front and into view | `switched-to-out-of-view`, `switched-to-partly-out`, `app-switch-out-of-view` (only the app was reported), `switched-to-behind` | `focus`, `behind` |
| Quitting, Float All and pause give windows their own sizes back | `size-not-given-back` | `size-lost` |
| After any way home no window shows less than its person left showing; after a change of displays none is mostly out of view | `home-not-whole`, `home-behind-the-dock`, `home-leaves-out`; `displays-left-mostly-out` | `lost` |

**Arbor raises nothing else** (`ChaosInvariants+Raises.swift`, QUESTIONS Q20 and Q25): `raised-unasked` speaks at any raise, which is a window brought to the front without the keyboard, of a window that is neither kept in view nor summoned, at the step in which it is made,
and at any raise at all by an Arbor that has paused or quit. `switched-to-behind` sees the harm only where the raised window happens to lie over the one just switched to. `asked: raised` counts how often a floating window that nothing keeps in view
came back into view, which is where Arbor used to raise. Its controls and its floor are in `RaisesNothingElseTests`.

The ways home (`way-back home`, `show-all`, `pause`, `float-all`, `start-again`, `quit`) are each taken at the end of every walk, the ones that leave the arrangement alone first.
A hunt ends with `asked: <net> <n> times`: **a net that never asks its question catches nothing**, and `ordinaryWalksReachEveryQuestion` holds each to a floor.

**Ordinary walks** (`ARBOR_CHAOS_ORDINARY=1`): the displays of a real desk, apps with the smallest sizes real apps have, windows that open wholly in view, keys that are bound, items that are in the menu, the mouse, and
a moment between one thing and the next. No settings edited by hand, no app that fights back, no crash, no nonsense. **What such a walk finds is likely on a real desk**; what only the wild walks find has to be looked at for how a person would get there.

```bash
ARBOR_CHAOS_ORDINARY=1 .build/release/arbor-sim hunt 1 2000 300                                # the seed chooses the desk
ARBOR_CHAOS_ORDINARY=1 ARBOR_CHAOS_DESK=laptop ARBOR_CHAOS_DOCK=left .build/release/arbor-sim hunt 1 2000 300   # laptop | desk | both; bottom | left | right | hidden
ARBOR_CHAOS_ORDINARY=1 .build/release/arbor-sim hunt 1 2000 300 --known                        # the known failures end a walk like any other
```

**The scoreboard** is the number of ordinary walks in 10,000 in which a rule broke, by rule: the `known:` lines of a hunt count the walks that passed a rule by, the summary line those that ended at one.

**Seeds mean something only on one generator.** A new `Command` case, weight or event sends every seed elsewhere: compare rates and scripts, never
seed numbers, between two commits. **A script means something only on a harness that knows its words**: a line that is no event is taken for
a command, and a command Arbor does not know does nothing, so a script with `via …` or `key down …` on a branch from before those events
replays to "every invariant held" and proves nothing. A command spelt like an event (`release`, `focus 101`, `save`) is written `do release`.

**Every walk ends in the three ways back** (`way-back float-all`, `way-back start-again`, `way-back quit`, each one step): after each, every window
that Arbor put where it is can be got hold of (rule `out-of-reach`). This is the release manager's test for a known problem: a script that
breaks a rule and has a way back is a known problem; one that has none holds the tag. Before believing "none", run `replay --frames` and see
whether the last move was Arbor's at all.

**In `make check` a script nobody knows is reported, not failed on** (a "known issue" in the test's output, with the script and "send this to the
chaos lab"), until hunts find fewer than one in 2000 seeds: any change to the controller leads the forty seeds down other paths, and whoever passes by should not have to
pay for a bug that was there. What does fail: `aKnownFailureStillFails`, the regression tests, the harness's own tests, and a crash or a hang. Hunts, and `ARBOR_CHAOS_STRICT=1`, fail on everything.

**When it fails** it prints the seed, the rule, the window or node, and the smallest script that still breaks the same rule
(found by deleting actions: delta debugging). Decide whether the controller or the rule is wrong (read the
specs first), paste the script into `ChaosRegressionTests` under a name that says what went wrong, and fix the cause:

```swift
@Test func parkedWindowsStayOutOfViewWhenTheResolutionGrows() {
  expectEveryInvariantHolds("""
    open 101 Safari pid 1000 at 100 100 600 400
    open 102 Notes pid 1001 at 300 200 600 400
    launch
    dock 101 left
    zoom 101
    displays main:0,0,2560,1440:25,0,0,0* windows-late
    """)
}
```

A script starts with one standard display, no windows and Arbor not running. The lines are listed in `ChaosAction`; any
other line is a command. What a user cannot do (carry a window off every display, grab one that is out of view) is
not done whatever the script says, so shrinking cannot arrive at an impossible story. A step that takes more than ten seconds ends
`arbor-sim` with `RULE hang` (exit code 4), so a loop that never ends is found, and shrunk, like a crash.

**Extending it**

- **A new command** does not compile until it is listed in `ChaosGenerator.kind(of:)`: add its name to `CommandKind` and
  `kind(of:)`, a line with random arguments to `command(_:in:)`, and a number to `weight(of:)`.
- **A new event** (something the user, an app or macOS does): a `ChaosAction` case, its words in `text` and `parse`, what it
  does in `ChaosRunner.perform`, and a weight in `ChaosGenerator.next`.
- **A new rule** about the controller's own state: `func <feature>Violations(_ problems: inout [InvariantViolation])` in
  `Controller+<Feature>.swift`, called at the end of `Controller.invariantViolations`. One that needs the fakes: the same in an
  extension of `ChaosRunner`, called in `check(after:)`.
- **A new timer**: add its key's prefix to `ChaosRunner.knownTimers`.
- **A new overlay**: tiles and seams are compared with the layout; anything else needs a rule of its own (`focusRingViolations` is the pattern),
  because putting a whole scene together can change state and looking must not.

**Known failures** (`Sources/ArborTesting/ChaosKnownFailures.swift`). A bug that is found but not fixed yet gets an entry: the rule it breaks, who
has it, what a person would see, and the shrunk script. Random runs carry on past those rules, so `make check` stays green and the rest of each run is not
lost. `ChaosKnownFailureTests` replays every script and **fails when it no longer breaks its rule: you fixed the bug, so delete the entry** in the same
pull request, and the rule guards your fix from then on. Because a whole rule is excused, a known bug should have a rule name of its own wherever the rule can tell it
apart (`vanished-strip` beside `vanished`, `leak-<list>` for each list, `parked-stopped-short` beside `parked-in-view`).

## The lid sweep (`arbor-sim sweep`, `LidSweep`)

The walks search a large space at random and judge by rules. The sweep searches one small space completely, and its yardstick is not a rule but **the same Mac without
Arbor**. A laptop stands beside a big display; the lid closes, opens and closes again, two minutes apart, with one floating window on the desk. That is played for a window in every place
along the big display and across its edges, every 40 points, 600 and 1400 wide, twice each: with Arbor and without. Whatever differs is Arbor's doing, and has to be one of the few things
Arbor means to do. So it can be strict where a rule has to be lenient: at a change of displays, when macOS itself moves windows about.

```bash
swift build --product arbor-sim
.build/debug/arbor-sim sweep                        # 48 columns, one line each, with an example of each kind; three minutes
.build/debug/arbor-sim sweep right --examples 5     # one side; also --stride <points>, and --strict
.build/debug/arbor-sim sweep story right 1728 300 untouched    # one window through the lid, in each order of reports, stage by stage
```

**A column** is a side for the big display (right, left, above), what Arbor is doing while the displays change (running, paused, quit, crashed), whether a hand put the window there with
Arbor looking on or it has been there since before Arbor started, how long before the lid first closes the hand let go (five minutes, or 0, 5, 15, 29 s: Arbor believes for half a minute a window that has
spoken of its place), and the order in which Arbor hears of windows and displays (`first`, `late`, `silent`, `never`, as in a walk's `displays` line). Nobody knows yet in which order a real lid
reports, so all are played.

**A place is looked at nine times**: after each of the three changes, and after ⌃⌥0 and `relayout` following it, because a window that is right until the next layout is not right. **Each change is
judged by itself**: both Macs go into it with the window in the same place, so that what differed after the last change, on purpose or not, is not counted again as an echo. One fault
counts three times at most, in every column alike.

| It counts | |
|---|---|
| `hidden` | in view without Arbor, out of view with it |
| `out of reach` | no hand can take hold of its title bar (the walks' own measure), where without Arbor one can |
| `jumped` | wholly on a display without Arbor, so macOS saw no reason to move it; elsewhere with Arbor |
| `fitted` | hangs over an edge without Arbor; elsewhere with Arbor, which may have fitted it onto a display |
| `home on the laptop` | began on the laptop and is on it again now that the lid is open: on purpose |
| `where the hand left it` | on the big display where the hand left it, seen from that display, where macOS alone has it elsewhere: on purpose |

After `jumped` and `fitted` stands at which change: `jumped 612 (0 + 468 + 144)` is none when the lid closes, 468 when it opens, 144 when it closes again. A line also says how many places were not
looked at because Arbor moved the window at its start, which is another story, or because no hand could have put a window there. The exit code is 1 if a window was hidden or out of reach
anywhere; with `--strict` also if one jumped; 2 if the lab refused a step (`REFUSED:`), so that the sweep was not the one it says it was.

**It is for comparing**: play the same columns before and after a change to what Arbor does at a change of displays, and the difference says what the change cured and what it cost. `story` then
tells one of the places: where the window is after each stage, which moves were Arbor's own, and on which display Arbor remembers it. Not every `jumped` is a fault; every one is a move of
Arbor's that somebody should be able to give the reason for.

`LidSweepTests`, part of every `make check`, holds the sweep to its controls (a Mac without Arbor differs from itself nowhere; a window taken out of view, put with its title bar above the screen, or shoved
aside in Arbor's place is seen, each as what it is; with the lid shut nothing is "home on the laptop"; a place no hand could reach is not passed off as played) and plays every column on a coarse
grid: nothing refused, no window hidden or out of reach.

**On the trunk that brought it** (right / left / above): hidden 0, out of reach 0 and nothing refused in all 48 columns.
- **With Arbor running and the windows heard of first, 468 / 594 / 591 jumps when the lid opens** (by hand; untouched 432 / 558 / 516), that is 156 / 198 / 197 of 246 places: a window of the big display is
  put onto the laptop's screen by a move of Arbor's own and remembered there (`sweep story right 1728 300 untouched`). The walks' rules are silent about it. With the displays heard of first (`late`), or windows that moved and
  never said so (`silent`): 0 / 0 / 3 there.
- When the lid closes again, 72 / 0 / 18 under `late` and `silent`: a window astride the border that went home to the laptop is put back where it stood when the lid was last shut, 40 points from where macOS leaves it.
- How long ago the hand let go changes nothing in these columns.
- With Arbor away across the change: jumped 0 / 0 / 3; fitted 240, 360 and about 200 (paused, quit, crashed).
- In the untouched columns 36 / 36 / 49 places are not looked at: windows hanging over an edge, which Arbor moves at its start.
- `never`, where windows keep their old coordinates, is what no Mac does; its columns are there because Arbor must cope.

**What it does not play:** more than one window; a docked one; displays whose tops or sides are not in line; a display that changes its size or its side; and what macOS really does with
windows when a lid closes, of which the lab has only its own idea. No hosted Mac has a lid.

## Launch fuzzing (`make fuzz`, `scripts/fuzz-launch.py`)

Arbor reads two files when it starts, and people edit both, keep them in their dotfiles, and carry them from one version to
another. Whatever they say, Arbor must start, work, and quit with every window in view; and what it cannot use of a saved
arrangement must still be on disk after it has saved its own. The chaos test damages state.json too, at random and
in passing. This goes through the files **place by place**, and starts **a fresh process on each**, so that a crash or a hang at
launch is one finding among thousands of starts rather than the end of the run.

**What it does.** `fuzz-launch.py` has `arbor-sim launch` (`Sources/arbor-sim/Launch.swift`) play two rich sessions and save them:
between them the two state files hold every field there is (it stops if one is missing). Then it damages a copy: each number becomes huge, tiny,
negative or another's (`numbers`); each value becomes null, text, a list, an object, is deleted or doubled (`shapes`); each text and each name
becomes empty, invisible, 200,000 characters long or another's (`strings`); or two to six of these at once (`several`). On each file it starts
`arbor-sim launch --state … --settings …`: the real `FileStateStore` and `SettingsFile`, the real controller, the fake window system.

| | The start | The script |
|---|---|---|
| `state` | with its seven windows and with none, on one display and on two | 68 lines, ten of them `health`: dock, drag, resize, views, names, summon, pin, minimize, close, displays plugged, unplugged and all gone, pause, exclude, arrange, float-all |
| `settings` | on a rich state.json, on one display and on two | 55 lines, nine of them `health`, among them `set`, `bind`, `rule add`, `exclude`, `reset all` and `reset everything` on that same file; at the end it must be JSON and say what was last set |
| `audit` | none | what was read is written again and compared with the file |
| `earlier` | as `state`, and the audit | nothing is damaged: the files in `collab/evidence/state-files`, which earlier versions wrote, must be read without a note and lose nothing |

**What it checks.** No crash, no hang (30 seconds), and every `health` line in the script says `HEALTH ok`: no rule of `Controller.invariantViolations()`
is broken (but for the chaos test's known failures), no frame is infinite or absurdly far, `state` can be written, and **what would be saved reads
back as it is, without a repair**: otherwise Arbor wrote damage, and the next start tells the person that their arrangement was damaged. No display is left
un-laid-out after a line, and after `quit-check` every window is in view. The audit asks of each damaged file: if it was refused, was it set aside byte for
byte? If a repair was noted, was the copy made? And if nothing was noted, is there anything in the file, beyond the damaged place, that would not be
in the next save? Nothing noted means no copy, so that would be gone for good.

**Running it**

```bash
make fuzz                                            # a sample of 300 of each kind on each file: a few minutes
scripts/fuzz-launch.py all                           # everything: some 90,000 starts, about an hour on four cores
scripts/fuzz-launch.py state numbers shapes          # one file, some kinds
scripts/fuzz-launch.py audit --keep /tmp/found       # keep the files that found something there
scripts/fuzz-launch.py all --timeout 90 --jobs 2     # on a busy machine, where a slow start would count as a hang
```

**When it finds something** it prints what (`CRASH`, `HANG`, `UNHEALTHY`, `STALE LAYOUT`, `LOST AT QUIT`, `CUT SHORT`, `FILE`; `REFUSED AND NOT KEPT`, `NOTED AND NOT KEPT`,
`SILENT LOSS`), the last line that ran, the damage, and the file, once for each distinct finding. To see it happen:

```bash
.build/debug/arbor-sim launch --state /tmp/found/stateA-numbers-1.json --windows 7 --displays 2 health "dock 107 left" health
.build/debug/arbor-sim launch --state /tmp/found/auditB-strings-2.json --audit
```

Fix the decoder (`Workspace.init(from:)`, `LayoutTree+Decoding.swift`, `SettingsSchema`) rather than the place that fell over: what loads must be safe to use.
What cannot be fixed at once gets an entry in `KNOWN` at the top of the script: the verdict, where the damage was, what the finding says, who has it and what a
person would see. It is counted apart and is no reason to fail. Keep an entry as narrow as can be, and delete it with the fix: a run of everything
names the entries that nothing met.

**At a release**, `scripts/fuzz-launch.py earlier --save-bases collab/evidence/state-files/<version>` adds what this version writes to the files later versions must read.

**Extending it.** A new field in state.json: make one of the two sessions in `BASE_SESSIONS` produce it and add it to `EXPECTED_KEYS`. A new command worth
running on damaged files: a line in `STATE_SCRIPT` or `SETTINGS_SCRIPT`. A new file Arbor reads at launch: an option in `Launch.swift` and a campaign beside the three.

## Manual checks (the parts no automation covers)

A Mac shell script (section 5) can now make most of these; the real-window suite (section 10) makes a dozen of them as claims whose
evidence counts, `shots-demo.sh` covers the edge drag, the seam, the window edge, the tile, shortcuts, the ⌃⌥ rectangle, the menu and
quitting, on test windows, and `input-taps.sh` the pinch and the rectangle. What is left for a person: other apps' windows, a real
trackpad, taking Accessibility away, and how it feels.

With `Arbor.app` running and permission granted:

- Drag a window by its title bar to the left screen edge: a translucent
  preview in the accent colour appears and the window docks on release.
- Drag a window onto the right third of a docked window and hold it there: after
  a moment the preview fades in, and on release it docks beside it. Move to
  another edge of that window: the preview fades out and, after the same
  moment, in again. Sweep across the window and let go without stopping: no
  preview, and the window stays where you let go; a docked one goes back to its slot.
- Let go of a docked window over the middle of another one: it goes back to its
  slot. Over the Desktop it floats.
- Along the screen edges the preview appears at once; round a corner of the
  screen it glides from one edge's place to the other's instead of jumping.
- Hold ⌘ while dragging: no preview anywhere, and the window floats on release,
  even a docked one let go over its own slot. Press ⌘ while a preview shows,
  without moving: it goes; release ⌘: it comes back after the hold.
- With "Reduce motion" on (Accessibility → Display) the preview appears and
  disappears without fading.
- Set `"reflowWhileDragging": true` and reload: drag a docked window out of its
  slot and its neighbours close up at once; hold over another window's edge and
  it makes room where the preview is; go back over the old slot and the gap
  opens again. The dragged window never jumps out of your hand, and letting go
  anywhere leaves everything as it does with the setting off.
- ⌃⌥↩ frames the focused window; ⌃⌥Space shows everything; ⌃⌥[ goes back.
- ⌃⌥N (`check-F20.sh` covers test windows): the field appears in the upper middle, over the space; typing goes into it and not into the app behind; the line under it changes
  as you type; ↩ names, ⎋ cancels, a click elsewhere, ⌘Tab and a swipe to another macOS Space close it; afterwards the app you were in has the keyboard without a click.
  Try an input method (compose, then ↩ twice) and dark mode.
- Drag the gap between two docked windows: both resize.
- Drag the edge of a docked window toward its neighbour: nothing else moves
  until you release, then the neighbour gives up the space. Drag an edge that
  is against the screen: it snaps back on release.
- Dock a window that refuses to shrink (e.g. System Settings) into a small
  slot: it becomes a tile with its icon; clicking the tile zooms onto it.
  (Known to fail when it is docked by a command or shortcut: the camera jumps
  onto the window, and ⌃⌥Space then shows the tile.)
- ⌘Tab to a window that is out of view: the camera moves to show it. (It failed in
  `proof.sh`, "switching to an app whose window is out of view…", before #15 made Arbor observe app activation.)
- Minimize a docked window and click it in the Dock: it returns to its slot and
  the camera stays. (Known to fail: the camera zooms onto it.)
- Press a docked window's green button and leave full screen again: it returns to
  its slot. (Known to fail: F30.)
- Dock a small window, then drag it out by its title bar and drop it on the Desktop: it shrinks to the size it
  had, with the pointer still on its title bar. ⌃⌥F on a docked window does the same where its slot was.
  Arrange Windows, then Float All Windows (or quit): every window is back exactly where it was.
- `arborctl layout --open "Safari | (Mail / Notes)"` with Mail and Notes not running: both open without
  taking the keyboard, and each window goes to its place as it appears. Try an app with a splash screen.
- ⌥ + spread two fingers over a window: the camera steps in to it; pinch on
  the wallpaper without ⌥: it steps out to everything; pinch over Safari
  without ⌥: the page zooms and Arbor does nothing.
- With a wheel mouse, ⌃⌥ held, over a docked window: one notch up steps in toward it, one notch down steps out. Without the keys, and
  with ⌃ or ⌥ alone, pages scroll as ever and no slower. On a Magic Mouse or trackpad a short stroke with ⌃⌥ is one step, and
  nothing follows when the fingers lift. Let go of the keys in mid-stroke: the page under the pointer still does not scroll.
  With ⌃⌥⌘, or ⌃⌥⇧ on a trackpad, the page scrolls and Arbor does nothing. Open Arbor's menu with ⌃⌥ held, let go of the keys, close it: the next ⌃⌥ + scroll works at the first attempt. Hold ⌃⌥, rest two fingers on
  a page, scroll, lift: its scrollers fade as usual.
- **First of all for F55**: in System Settings → Accessibility → Zoom switch on "Use scroll gesture with modifier keys to zoom", with ⌃. ⌃ + scroll zooms
  the screen. ⌃⌥ + scroll must step Arbor's view and leave the screen's zoom alone. If both happen, `docs/KEYBOARD.md`'s "⌃⌥ + scroll is nobody's" is wrong.
- ⌃⌥-drag a rectangle around a window: a translucent band follows the
  pointer, nothing under it is selected, and release frames the window.
  No contextual menu opens. A ⌃⌥-click without a drag still opens the app's contextual menu, and ⇧⌘-drag in a design
  tool and ⇧⌘-click on a link in Safari are the apps' own again. **Not seen on a Mac since the default became ⌃⌥.**
- Begin such a rectangle and let go of ⌃⌥ before the button: the band goes, the view stays, and the app under the pointer notices
  nothing (no selection, no menu, no drag left hanging). The same with ⇧ on the Desktop. **Not seen on a Mac.**
- Hold ⌃⌥Space until the outline shows and click a window carelessly, the pointer moving some ten points between press and release:
  the view goes to that window, as after a clean click. **Not seen on a Mac.**
- ⇧-drag from the wallpaper over a window: the same band, and release frames
  the window. ⇧-drag inside a document still extends the selection, and
  ⇧-click on an icon on the Desktop still adds it to the selection, and
  ⇧-drag that starts on an icon drags the icon.
- With "Click wallpaper to reveal desktop" at its default and something docked: a click on
  the wallpaper or in a gap moves nothing (`guardDesktopClicks` true; it is off by default). A drag there draws
  Finder's selection rectangle; an icon, a widget and a stack of icons still take clicks, double-clicks and drags.
  **Then each of these, closed by a click on the wallpaper:** an app's menu, the Apple menu, Finder's context menu on the
  Desktop, Arbor's own menu (and click one of its items where it hangs over the Desktop), a Dock stack, Control
  Centre, Notification Centre, Spotlight, a popover, the name of an icon being edited. In Mission Control, click a
  thumbnail that lies over what is really bare Desktop. ⌘⇧4 and drag from the wallpaper. Force-click an icon. Tap to
  click. With `ARBOR_DEBUG=1` the log names the level, pid and size of whatever made Arbor leave a press alone.
- Frame a window, then switch Arbor off in Accessibility while it runs: the mouse, trackpad and
  keyboard keep working, the log says the event taps were removed, within three seconds the menu bar icon is a warning
  sign and the welcome window asks for the permission back, counting the windows; the menu counts the windows out of view and its Quit says that they would stay there;
  ⌃⌥Space beeps and opens the settings; ⌃⌥↩ reaches the frontmost app. Switch it on: every window is in view within a second or
  two, and ⌃⌥[ returns to the framed window. Also with the − button instead of the switch. With nothing out of view: only the icon changes.
- Quit Arbor from the menu: every window is visible afterwards.
- Motion (`scripts/mac-shell/shots-F02.sh` films most of this). ⌃⌥↩ on one of several docked windows: it grows
  to fill the view while the others slide out past the screen edges, behind the Dock and the menu bar; ⌃⌥Space
  brings them back the same way. At the first and last moment nothing jumps, flashes or changes
  brightness: not the wallpaper, not desktop icons, not window shadows, not text. ⌃⌥Space and ⌃⌥↩ in quick
  succession: the motion turns round from where it is, and nothing is left on screen afterwards. Click in
  mid-motion: the real windows are there at once and the click lands on what is really under the pointer.
  Type into a window, press ⌃⌥↩ straight away: how old is the picture, and when does the new one come?
  Without Screen Recording permission: the same with app colours and icons. With a video playing, a
  picture-in-picture window, an open dialog or sheet: what happens to them for that half second?
  With "Reduce motion" on, or `"animationDuration": 0`: everything is applied at once.
- ⌃⌥⎋ while framed on a window: it goes back to where it was before it was docked, in its own size, and stays in front; so do the others, behind it, each in one move; tiles and gap handles go, the menu bar icon dims, and ⌃⌥F now
  reaches the frontmost app (try it in a terminal running Emacs or `cat -v`). Move, close and open windows:
  Arbor does nothing. ⌃⌥⎋ again: the arrangement and the view come back without the closed windows.
- In Terminal (running `cat -v`) or Emacs choose Shortcuts Off in “Terminal” from Arbor's menu: ⌃⌥F and ⌃⌥Space now reach the
  app, ⌃⌥-drag is its own, its windows stay docked, and the menu item has a tick. ⌃⌥⎋ still pauses. ⌘Tab away and
  ⌃⌥Space shows everything. `scripts/mac-shell/check-F41.sh` does this with an app that writes down the keys it gets.
- Add German in System Settings → Keyboard → Input Sources and select it in the menu bar: ⌃⌥ and the key labelled Z does what
  ⌃⌥Z is bound to (bind it first: `"ctrl+opt+z": "desktop"`), Arbor's menu shows Back as ⌃⌥Ü, and `arborctl bindings` names the layout.
  `scripts/mac-shell/check-F44.sh` does this for German, French, Dvorak and Russian.
- With that second input source still there: `arborctl bindings` ends with a sentence about ⌃⌥Space and "Select next source in Input menu". Press ⌃⌥Space: which of
  the two happens? (On macOS 26.6.2 Arbor got the key.) Untick the shortcut under Keyboard Shortcuts → Input Sources: the sentence is gone, without restarting Arbor.
- Put a game's bundle id into `pauseForApps`: bringing it to the front pauses Arbor (dimmed icon), leaving it resumes.
- With a window of another app out of view, ⌘Tab to that app (and click its Dock icon): the view moves to show it.
- The settings window (`SettingsWindowPictureTests`, part of `swift test` on a Mac, draws every pane off screen, in light and dark, into
  `.build/pictures/F12/`: look at them; `scripts/mac-shell/shots-F12.sh` makes these checks on test windows): ⌃⌥, opens it in front of
  docked windows, with the keyboard; every pane reads well in light and dark and no text is cut off; dragging Gap's slider moves
  the windows when it is let go of; 500 typed into Gap is refused under the field; recording ⌃⌥D for another command asks before taking
  it, and does not show the Desktop; ⌘W closes the window and the app from before has the keyboard. For a person: Open at
  Login in a bundled app, the menus of running apps in Rules and Apps, VoiceOver through a pane, the window on a second display.
- Frame a window, hold ⌃⌥Space: everything shows and, a moment later, an outline where you came from. Point at another window and let go:
  it is framed and has the keyboard; ⌃⌥[ returns. Hold again and let go at once after the outline shows: back where you were. Hold, ⎋: the
  same, and Arbor is not paused. Hold and press arrows: the outline walks. Hold and click a window of **another app**: it is framed, no contextual
  menu opens, and no app is hidden. Tap ⌃⌥Space with ⌃⌥ kept down for two seconds: the view stays on everything when they come up.
- Frame a window, choose Hold This View: the menu bar icon is a lock and the view commands in the menu are grey. ⌘Tab to an app that is out of view: the
  menu bar flickers to that app and back, nothing else changes, and typing goes on in the framed window. ⌃⌥Space beeps. Have a chat app
  mention you. Drag the framed window to a screen edge: no preview, and it goes back. ⌃⌥⇧F beeps. ⌘M on the framed window: the wallpaper and nothing
  else, and the menu says "The view is held: nothing is in it"; click it in the Dock: as before. Keep ⌃⌥⎋ down for three seconds: the lock goes, nothing
  moves, and Arbor is **not** paused; press it again: paused. `scripts/mac-shell/check-F58.sh` does the first half of this on test windows.
- **`holdStillWhileMicrophoneIsOn` ships false until both of these have been seen** with it set to true. (1) On an idle Mac with "Hey Siri" and dictation
  enabled, `arborctl status` does not say "holding still". (2) In a call with the camera off, in each of Zoom, Meet, Teams and Slack: mute, wait ten
  seconds, unmute. `arborctl status` says "holding still" throughout: muting must not end it in the middle of a call.
- **`holdStillWhileCameraIsOn` and `holdStillFor` ship off and empty until the next two have been seen.** `arborctl set holdStillWhileCameraIsOn true`, then
  open Photo Booth: at once the icon is filled in and the menu says "Holding still while the camera is on". ⌘Tab and Dock clicks still bring windows
  into view; an app that comes forward by itself does not. Quit it: the icon is back to normal within six seconds. Nothing else appears and nothing sounds, at either end. The same with Voice Memos recording ("the microphone"), with its switch on.
  Then the false alarms: is the icon filled in with "Hey Siri" or Voice Control on and nothing else? While music plays through AirPods, a USB headset, a display's speakers?
  No prompt for the camera or the microphone may ever appear, and no orange or green dot because of Arbor.
- Join a Zoom meeting and read its window's title off the Mac: the example "us.zoom.xos Zoom Meeting" was written from memory. With that entry in `holdStillFor` and the
  camera's and the microphone's switches off: "Holding still while zoom.us is open".
- Holding still, open an app with Spotlight or a launcher, run `open https://example.com` in a terminal, click a link in a chat: which are turned away? Each must be said on
  screen ("Safari is out of view: holding still · ⌘Tab or ⌃⌥G goes there"), once. Note how long after the key each report comes: what counts as asking is to grow from that.
- Holding still, ⌃⌥G to a window on another macOS Space: macOS slides over and stays there, and the window is in view. Are two seconds enough?
- Share the whole screen in Zoom, Meet or Teams with four windows out of view and look at the share on another device: what is there in the bottom corner? Open
  their window pickers: how do the windows that are out of view look? Share one of them.
- Dock two windows, left and right: the wallpaper behind them is a shade darker, with rounded corners, and the Desktop between them is not. Icons on the Desktop can
  still be clicked and dragged, also where it is darker. Zoom, go back, float, close: the shape follows with a short fade. Drag the gap beside the Desktop: the edge follows
  the pointer without smearing. `"blurBehindArranged": 1`, Reload Settings: the wallpaper is blurred there. Switch between light and dark mode: tiles change at once.
  `"tintBehindArranged": 0.3`: it takes on the accent colour, and follows when another accent is chosen in System Settings. `"desktopEdge": 0.5`: a thin line runs round the Desktop between
  the windows. Squeeze a window until it is a tile and widen it again: tile and window fade into each other.
  Mission Control: the shape goes with the windows. Pause and quit: nothing is left. `scripts/mac-shell/shots-F15.sh` takes pictures of most of this in both modes.
- Move a floating (or pinned) window across a gap and across a tile, then resize a docked window by command or go out and in again: the floating window stays in front of the tile, and every point of it
  takes clicks and drags; none of them resizes the docked windows.
- Point at the gap between two docked windows: a small white handle shows in its middle, in the accent colour while it is dragged. (The pointer stays an arrow: macOS takes
  a cursor only from the active app, which Arbor never is.)
- ⌃⌥↑ while everything is showing: "Already showing everything" in a line low on the display, which fades after a second and a half. ⌃⌥↩ twice: framed, then back where you were.
- The line and the panel of shortcuts drawn off screen: `swift test --filter HeadsUpPictureTests` on a Mac draws the real views into bitmaps in memory (no window, nothing on or from the screen), checks
  that the letters stand out and stay inside, and leaves PNGs in `.build/pictures/F43/`, light and dark, at scale 1 and 2. The translucent background is a plain plate in them: an effect view draws nothing off screen.
- The line (F43; `scripts/mac-shell/shots-F43.sh` takes the pictures): legible on a light and on a dark wallpaper and over windows, in light and in dark mode; typing goes on in the
  focused window while it shows; a click on it lands on what is under it; it does not show over another app's full-screen Space; with "Reduce motion" on it appears and
  disappears without fading. With `"messages": "off"` there is a beep instead.
- With a fresh `state.json`: the first dock, the first ⌃⌥↩ and the first tile are each explained, three times and not a fourth, also after quitting and starting Arbor again.
- ⌃⌥⇧/: the panel of shortcuts, with your own `bindings` in place of the defaults. Type a letter: the panel goes and the letter is **not** typed into the document behind. The next letter is.
  Also ended by a click on it, a click elsewhere, the same keys, any other Arbor shortcut (which does its job), ⌃⌥⎋.
- Dock Calculator or System Settings: it sits in the middle of its slot and does not twitch when a neighbour is resized.
- Quit Arbor, then `arborctl help` prints the commands and `arborctl status` says how to start Arbor.
- ⌘Tab between apps, ⌘` between an app's windows, click the desktop: the focus ring is around the
  window that takes your typing, and gone when none does. A picture-in-picture video or a popover that overlaps the
  window's edge covers the ring. ⇧⌘4 then Space over the focused window picks the window, not the ring.
- Dock two windows, drag the gap between them back and forth, release, press ⌃⌥Z once: the gap is back
  where it was before the drag. ⌃⌥A, then ⌃⌥Z: everything is back, floating windows included. The menu's Undo
  and Redo name the step ("Undo Arrange") and are greyed out when there is nothing to undo or redo
  (`scripts/mac-shell/shots-F19.sh` does all of this on a cloud Mac).
- Go to… (`scripts/mac-shell/shots-finder.sh` does the first four with real keys on test windows; `arbor-e2e` posts no input, so it only sees
  the palette come, have the keyboard and go). With real apps:
  - ⌃⌥G while typing in an app: the palette appears a quarter of the way down the display you are typing on and takes the keyboard; the app's
    window keeps looking active and its name stays in the menu bar. Escape: typing goes on in the app where it stopped.
  - Work in three apps for a while, then ⌃⌥G: the list starts with the window you were in before this one. Return goes there; ⌃⌥G Return comes back.
  - Type a few letters of a title: the row is on top, its matched letters set off; long titles end in "…" before the note at the right.
  - Click another window, a tile or a gap handle, ⌘Tab, swipe to another macOS Space, open Mission Control, lock the screen: the palette closes each
    time and never stays behind. In a password field (secure text entry) ⌃⌥G may not get the keyboard: the next key then closes it.
  - Choose a minimised window, a window of an app hidden with ⌘H, a tab behind another, a window on another display and one on another macOS Space:
    each ends in view, in its own place and not as a tile, with the keyboard. The pointer does not move.
  - After going to a window on the other display without touching the mouse, ⌃⌥↑ zooms that display, not the one under the pointer.
  - Frame a window, swipe to another macOS Space and back: it is still framed.
  - Type with an input method (Japanese, Korean, Pinyin): composing works, and Return confirms the composition before it chooses a row.
  - Light and dark appearance, a bright and a dark window behind the palette, "Reduce transparency" and "Increase contrast" on: everything stays readable.
  - Over an app in full screen: the palette shows there too.
- With three or four real apps docked, ⌃⌥M: the minimap fades in low on the display, the apps can be told apart by colour, and the accent frame is where
  you are. Click a window in it: that window is framed and takes your typing, and no other app came forward. Hold ⌃⌥M, point, let go: the same. Open
  Mission Control while it is up: it is not there. In another app's full screen: it does not show. ⌃⌥⇧1 while it is up: the line sits above it. Then
  `arborctl set minimapDuration 0.9` and zoom about: it comes and goes after every move, and a click where it is reaches the window below.
- Add `"bindings": {"ctrl+opt+cmd+h": "dock left", "ctrl+opt+d": null}` to
  settings.json and save it (no reload needed): ⌃⌥⌘H docks the focused window on
  the left, ⌃⌥D does nothing, and the menu shows ⌃⌥⌘H next to Dock Focused
  Window → Left and no shortcut next to Show the Desktop.
- `./scripts/make-signing-identity.sh` in Terminal, pressing Return at its question: macOS asks in a dialog of its own, once, and
  after Always Allow never again. Then
  `tccutil reset Accessibility com.evbarleyg.arbor`, `make install`, switch Arbor on under Accessibility: `arborctl status` says
  `running` a second later. Change a source file and `make install` again: it says `running` at once, and nothing asks.
- The same (after `--remove`) giving the login password instead of Return: no dialog appears.
- Menu → Help → Check for Updates…: a small window says "No update information" (while the repository is private); windows
  of other apps can still be docked while it is open. About Arbor shows the version.
- Settings… → General → Open at Login, log out and in: Arbor is running. `make uninstall`: Arbor is gone from System Settings →
  General → Login Items & Extensions.
- With windows docked, open settings.json in your own editor (TextEdit, VS Code, vim), change `gap` and save:
  the windows move within a second. Break the JSON and save: nothing moves, arbor.log says once why the file
  cannot be read, and `arborctl set gap 20` refuses and leaves the file as you left it. Mend it: it applies.

- Keyboard tiling, with windows of **different apps** docked left and right and one floating between them:
  ⌃⌥⇧→ walks from window to window (the menu bar shows each app in turn) and ⌃⌥⇧← walks back. Frame one window
  (⌃⌥↩): ⌃⌥⇧→ moves the camera to the next space and focuses what is there.
- ⌃⌥⌘= and ⌃⌥⌘- grow and shrink the focused window. Hold ⌃⌥⌘- on Safari or Xcode: it stops at the smallest size
  the app allows and never turns into a tile. ⌃⌥⌘0 balances the sizes; ⌃⌥R rotates, and again rotates back; ⌃⌥⇧R mirrors.
- With two displays: bind a key to `focus-display next` and press it: a window there has the keyboard, the pointer has not
  moved, and ⌃⌥↑ then acts on that display.
  `arborctl move-to-display next` sends the focused window across, docked or floating as it was. ⌃⌥⇧→ at the last
  window of the left display crosses to the right one.

Real apps, which the test windows cannot stand in for (F17):

- Drag-to-dock works in Safari, Finder, Terminal, an Electron app (VS Code or Slack) and System Settings.
- ⌘T in a docked Terminal or Finder window: the new tab is in the same slot, nothing else moves. Click the
  first tab, ⌘W the second, drag a tab out: the slot stays with the group, the torn-off tab floats.
- The green button on a docked window: the others share its space; leaving full screen gives it its slot
  back, as a window, not a tile.
- ⌘Tab between two apps with one of them out of view, with several Spaces, and with a window on another display.
- Stop an app (`kill -STOP <pid>`) that has docked windows and move the camera: Arbor reacts within about a
  second; `kill -CONT` and the windows go where they belong.
- Resize the Dock, or set it to hide, then `arborctl relayout`: the layout uses the new space.

With macOS's own window tiling on, as a Mac comes, the left, right and top edges of the screen are macOS's
(`MacTiling`), so try the edges both ways: System Settings → Desktop & Dock → Windows. Stage Manager rearranges windows on its own and cannot be used with Arbor.

How the menu bar item, the icon and the welcome window look can be seen without a screen: `Tests/ArborKitTests/MenuBarDrawingTests.swift` (macOS only, part
of `swift test`) draws them with the real AppKit and SwiftUI code into bitmaps in memory, checks pixels and sizes, and leaves pictures of every
state in `.build/pictures/F10/`, light and dark, at scale 1 and 2. No window is shown, nothing is captured and no input is sent, so nothing of
the Mac's owner can be in them. What it cannot show: the menu itself (read `arborctl menu`), `appearsDisabled` on a real status bar button, and where macOS puts the item.

The menu bar item and the welcome window. `scripts/mac-shell/shots-F10.sh` does the first five on GitHub's Mac (one
display at scale 1, macOS 26) with real clicks and keys; the rest need a person:

- With nothing docked the item is Arbor's mark, and a click opens the menu. Dock a window: the buttons appear.
- Save two views and move about: the button for where you are is filled in, back and forward grey out when there is
  nowhere to go, and a click on each button goes there. Hovering shows what each does. The last button (…) opens the menu.
- A right click, a ⌃-click and an ⌥-click anywhere on the item open the menu; shortcuts are right-aligned, the place you
  are at is ticked.
- `"menuBarControls": false` and Reload Settings: a single icon, and a plain click opens the menu.
- Take Accessibility away from Arbor and launch it: the welcome window opens by itself, Continue is grey, the
  menu bar shows a warning sign, the menu offers Check Setup… first. Grant it: within a second or two the window comes in front of System Settings. On a Mac
  as it comes it stays on its first page, headed "One thing is in the way" (the Desktop & Dock row), with Continue enabled; with nothing in the way it turns to
  "Three moves to try" and floats above other windows. Dock, frame, show everything: each is ticked as it happens.
- Close the window and open Arbor.app again from Finder: it comes back.
- Quit Arbor, delete `"welcomed"` from `state.json` (or the file) and launch it with the permission granted: the window opens by itself, on
  the three moves if nothing is in the way, at the right of the display. Quit and launch again: it does not. The arrangement survives both.
- **On a Retina display, and on light and dark wallpapers**: the glyphs are sharp and turn white on a dark menu bar.
- **With two displays**: click the item in the second display's menu bar. The click must land on the button under the pointer
  (`ARBOR_DEBUG=1` logs "menu bar click: x … by the event, … by the screen"), act on that display, and the item must then
  show that display's buttons.
- **On a notched MacBook with a full menu bar**: nine saved views make the item 320 points wide. Save views until macOS leaves it out: within
  two seconds Arbor's single icon must appear in its place, `arborctl menu-bar` says "macOS has no room in the menu bar for the buttons" and
  `arborctl doctor` "showing as a single icon". Quit a few menu bar apps and `arborctl reload-settings`: the buttons are back. With `ARBOR_DEBUG=1` nothing
  more is logged; `arborctl doctor` is the window into it. **If `doctor` says "not showing, as far as macOS says" while the item is plainly there**, the question
  Arbor asks (`occlusionState` of the button's window) means nothing on that macOS: nothing is taken away, and it wants reporting. If macOS hides even the
  single icon, opening Arbor again must still show the welcome window.
- With "Automatically hide and show the menu bar" on, and in a full screen Space: `doctor` says "Menu bar item: unknown here" and the buttons stay.
- Let the displays sleep and wake them, and switch to another user and back: the buttons are as they were. (A lock screen or a screen saver without
  display sleep sends neither notice: if a window event has the item drawn just then, the single icon stays until the settings or the displays change.)
- Help → About Arbor makes Arbor the active app. Close the panel: until a click or ⌘Tab "the focused window" is nobody's, and the rows under Focused
  Window are grey. Known, low; the way out is a panel of Arbor's own that is ordered front without activating, as the update window is.
- With the welcome window open, set "Click wallpaper to reveal desktop" to "Only in Stage Manager" and flip the three switches
  under Desktop & Dock → Windows: the row lists only what is still in the way, and gets its tick when nothing is. Switch
  Stage Manager on: it is listed. Start Rectangle, switch VoiceOver on: a row appears for each.
- In the bundled app, tick Open at Login on the second page: the box follows, and so do Login Items in System Settings
  and Open at Login in the settings window.
- Pause Arbor: the icon dims (as a single icon too), the menu begins with a line that says so and Resume with ⌃⌥⎋.
- Compare the open menu with `arborctl menu`, line by line, with a docked window focused, a floating one, and none.
- With the welcome window open on its second page, open Arbor.app again: the window comes forward as it is. Leave it open, switch to
  another of the macOS Spaces and choose Help → Welcome…: it comes over.
- Click Open Settings… in the Accessibility row on a Mac that has never run Arbor: macOS's own prompt appears once and
  Arbor is in the list, switched off.
- With VoiceOver, press the item (VO-Space): the menu opens.
- `make app`: Arbor.app has the green icon in Finder, in Login Items and in the Accessibility list.

`arborctl doctor` lists the settings under System Settings → Desktop & Dock that compete with Arbor as they stand ("Click
wallpaper to reveal desktop", the two "Drag windows to…" switches, "Hold ⌥ key while dragging windows to tile", Stage
Manager) and what to do about each.
