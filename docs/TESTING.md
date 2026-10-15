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

**What green on Linux cannot tell your change:** `make unplayed` (`scripts/reality-ledger.py --for`), which `make gate` prints under its steps. It reads what the branch adds to the
trunk and lists the cases of that page which the stand-ins play partly, not at all or never can, and which the change leans on. Above the seam that is by name: a line
it adds to the code that ships calls a member of the platform protocols (`system.setFrame(`), or writes one, and the case names that member. Below the seam it is by file: it touches
macOS-only code, which no test on Linux runs, and the case cites that file. What is not played at all first, a dozen lines at most (`ALL=1` for the rest; `FOR=` a commit, a range or a diff file).
**If the list is not empty, that is the argument for a Mac run before landing.** It is advice and never a failure, it takes a fifth of a second and no network, and to a change of pages,
scenarios, tools, tests or stand-ins it says nothing at all.
Why it is there: on 2026-10-15 "a refused size costs nobody a second move" passed everything on Linux, landed, and left the first dock on a Mac short of its slot, while
`a-size-set-at-the-old-place-is-cut-to-what-fits-there` had stood in the ledger as not played, and nobody held the change against it. For that change the list had seven cases that day, that one the fifth.
How much it talks, measured that day: of the last thirty changes to the trunk that touch `Sources/` it has nothing to say to twenty, and ten cases at most; of the twenty newest
branches, nothing to sixteen, and two lists were cut (25 and 70 cases: they touch the panels and `AXWindowSystem.swift`). By every file a case cites the same thirty gave 32 cases in the middle and
172 at most, since everybody cites the backlog; by every Swift file that ships, 3 and 19, much of it by way of `Settings.swift` and `ArborApp.swift`.
A call that stood there before is told apart: where every hunk that adds a member takes it out as often, the line was only reworded, so the case comes last, marked "read there before", and a list of
nothing else does not speak of a Mac run; a call that leaves one hunk and arrives in another counts as new, because on 2026-10-15 moving the call was the fault. Of the ten lists for those thirty changes
two are wholly of that kind, and so was the first list a pull request ever got: six cases for one `if` that had gained a clause.
**The order** within each kind is by what the stand-ins play (not at all, never can, partly) and only then by hurt: the question is what green cannot tell, so what is not played at all is the first answer, whatever it hurts. By hurt first a case goes under among its like once they all name their member, and by now 141 of the 362 unplayed cases name theirs (37 did): whoever adds a `system.setFrame(` is shown nineteen, with ten printed. `make lint` holds the order to its purpose: the change of 2026-10-15 is kept, cut down, in `collab/evidence/changes`, and every run of the script holds it against the ledger as it is (`PROOF`). The three cases that say a size depends on where the window stands are taken as not played, which they were when they were written down (the stand-ins learnt the rule within hours), and stand 1st, 2nd and 4th of twenty; by hurt first they would be 5th, 6th and 13th. With the names the same thirty changes still get ten lists, seven cases in the middle and nineteen at most, three of them cut.
**Silence is no clean bill.** A change that leans on a report rather than a call (full screen, a display that goes, an app that hides) names no member of the seam, and a case that does not
name the call it is about is not found. So a case about a call does well to name it in backticks.
The cases about reports name them too (`windowChanged`, `windowAppeared`), and **that finds nothing yet**: a report is called below the seam and written once, in the controller, and what is decided on hearing it stands a function or two further down. To count a hunk inside `func windowChanged` as the member was tried and is noise (33 cases at most for the thirty where it is 19, 86 for the branches): whatever keeps a table per window adds a line to `windowDestroyed` and `windowReplaced`.

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

### Tests and the defaults

A plain `Harness()`, a plain `Settings()` and arbor-sim without further words are **Arbor as it ships**. Arbor ships doing less than it can
(`collab/QUESTIONS.md`, Q29), and what went off by default is still there as an option. `Sources/ArborTesting/ClassicSettings.swift` has a chaining property
for each such option, and `Settings.classic` for all of them.

- A test **about** an option names it: `Harness(settings: .withEveryKey)`, `settings.withEveryKey`.
- A test about something else whose **means** is yesterday's (it presses a key that is no longer bound) is rewritten to what ships, if that does not change what
  it proves. Otherwise it names the option.
- Everything else follows what ships.
- A scenario says `set shortcuts all` at its head, under a comment that says why.
- `ArborCoreTests` does not import `ArborTesting`: there the property is set by hand.

**What ships, and what shipped.** An option that went off by default stays in the app. `Sources/ArborTesting/ClassicSettings.swift` has one chaining property for each (`.withDesktopColumn`, `.withEveryKey`, `.withFloatsMakingWay`), and `Settings.classic` for all of them. A test that is about such an option names it. A test whose numbers depend on what ships says `Harness(settings: Settings())`. Every other test says `Harness()`, and runs twice: `make test` as Arbor ships, `make test-classic` (Linux; `ARBOR_TEST_CLASSIC=1`) arranged as the first build arranged (the column, floating windows making way). Whoever turns a default off adds a property and a line to `classic`, in alphabetical order, and for the suite on real windows the key to `ARBOR_EVERYTHING_ON` in `scripts/mac-shell/lib.sh`. A chaos script that needs an option begins with `settings {"desktopColumn":true}`; a scenario with `set desktopColumn true` under a line that says why.

**Shortcuts.** Nine ship (`KeyBindings.core`); `.withEveryKey` is the whole map (`KeyBindings.all`; `docs/KEYBOARD.md`). `h.key("ctrl+opt+d")` returns nil for keys that nobody
holds, as the app in front would get them: a test that goes on without looking at the reply then proves nothing, so look at it. `h.press("desktop")` and `h.run("desktop", from: .shortcut)`
go by the command and need no key. `NineKeysTests` and `collab/scenarios/22-nine-keys.sim` play the nine; `LessByDefaultTests` holds them to their budget.
One place starts on the whole map all the same, and says so where it does: the chaos lab (`ChaosRunner.settingsFile`: a walk presses the key of a command, and a command
without a key is a step in which nothing happens; `set shortcuts` is among a wild walk's steps). A Mac shell script is Arbor as it ships too, with no settings.json in its home,
unless it is a section of the suite (section 10) or says `ARBOR_SHORTCUTS=all` before it sources `lib.sh` (section 5). The day and the walks (`lib-walk.sh`) say nothing: they run each command by the key it has, or from the menu.

## 3. arbor-sim

The same harness as a command-line tool, printing an ASCII drawing after each step:

```bash
make sim ARGS='"open Safari" "open Notes 640x420 min 900x600" "dock 101 left" "dock 102 right" "state"'
```

Docked windows are `+-|` boxes, tiles `#`, the Desktop `.`, floating windows `~`, with `:` a docked window that is let be, where it stands: its slot or its tile shows
the place that is kept for it. Under the drawing: the windows out of view, those that are let be.
Besides every `arborctl` command it understands `open`, `close`, `minimize`,
`restore`, `focus`, `cursor`, `drag`, `move`, `seam`, `tile`, `flush`, `quiet` and `loud`.
`title <id> <text>` changes a window's title.
`settings-file <path>` uses a real settings.json the way the app uses its own: it is loaded
at once, `set`, `bind`, `rule`, `exclude` and the like save to it, and `reload-settings` reads it again.
`hide <App>` and `unhide <App>` hide and show an app (each app name is a process of its own),
`background-focus <id>` is an app in the background changing its focused window, and
`displays 2` / `displays 1` plug in or unplug a 1920×1080 display to the right of the main one (`displays 2 below`: below it).
`macos-moves <id> <x> <y>` is macOS moving a window, as it does when the window's display goes, and its app saying so (no hand did it): say it before `displays`.
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

**It leaves no Arbor behind, however it ends** (`Guardian.swift`). First thing, the runner starts a guardian: a few lines of Perl in a session of their own that wait at the
far end of a pipe for the runner to end (finished, interrupted, or killed by a caller's time limit with a signal nobody can catch). It goes by the lock that keeps a second
Arbor out of the run's folder, which the kernel keeps, and reads no list of processes: while somebody holds the lock, the number in the file is the holder's, who is asked to quit and,
five seconds later, killed. Then the guardian takes the lock itself and holds it for fifteen seconds, which is what the runner gives an Arbor that a watchdog starts: one that
is still on its way finds the lock held and leaves, having started nothing. Last it removes the run's folder, which is nobody else's to remove: an Arbor on its way would make it anew,
with a lock in it that nobody holds. The runner starts nothing before the guardian says that it is in its session, and does not run without it; and it prints line by line also into a file, so
that what a run had said when it was killed tells how far it got. `scripts/test-e2e-guardian.py`,
part of `make check`, reads the program out of the Swift file and holds it to a table of endings against stand-ins for Arbor and its watchdog, on Linux too: killed alone or with its
group, an Arbor deaf to SIGTERM, one killed a moment before, a next one that is slow to reach the lock, a file with somebody else's number in it, each kind beside a control that
comes out badly. `scripts/mac-shell/check-e2e-guardian.sh` ends the real runner on a Mac. What is still left behind: an Arbor that needs more than fifteen seconds to reach the lock.
The first session, the accidents and the start after the rescue run Arbor with its watchdog, as a person's has one, and the first checks that it stands by before the quit and has
left after it. The sessions that follow run without: an Arbor that ends in one of them stays away and is missed, where one started in its place might pass for it.

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
stand in for: a title-bar drag to the left screen edge, a drag onto another window's edge (let go with the pointer inside the preview), a double-click on a
docked window's title bar (no seam may move), a press and drag inside a window (not a drag), a drag of a docked window's edge (the seam follows), a drag
out onto the Desktop, a drag to the bottom edge, a window let go at the very edge of the screen, and one let go in the menu bar.

- **At both settings of macOS's own tiling.** On GitHub's Macs the whole journey is played with the tiling on, as a Mac comes, and once more with it switched
  off; on a person's Mac once, as it is set. The script switches it on first if a script before it on the same Mac left it off, and back on however it ends. On
  GitHub's Macs the setting is first **seen to act, or not to**, on a window that Arbor does not know, before Arbor starts: a switch that is written and not
  obeyed proves nothing. macOS does not answer every drag, so that it acts is said by one drag of three, and that it does not by two of two. With the tiling
  on, the left, right and top edges are macOS's: along them Arbor shows no preview, a window let go short of macOS's point floats where it is, and one let go
  at it ends in macOS's tile, stays there and floats. With it off, Arbor docks in all those places. At the end of the first round the tiling is switched off
  while Arbor runs, and the next drag into the menu bar docks.
- **After every drop** (`collab/QUESTIONS.md`, Q17: nothing of Arbor's takes the mouse-up): the login session has the button up within 100 ms of the posted
  release (`pointer release --timed`), and a click where the preview was, about half a second after the drop, arrives in the window (`events_of <id> down`; the check says how long it was). The
  release and the click come out of one call of the pointer tool (`release --timed --then-click x,y`): two calls, with what `lib.sh` does between them, lie 0.6 to
  0.8 s apart on GitHub's Macs, and the other questions take a second and more. Then: the window ends where the preview was, Arbor saw the release, and no preview is left behind.
- **With and without Arbor's event taps.** The first round plays Arbor as it ships, which is without one (`pointerGestures`). Nothing of Arbor's can hold a
  release back then, and the time says what the Mac is like. The second round has every gesture switched on, so that the taps lie in the way of every
  press and release. What a tap costs a press, to the millisecond, is `input-taps.sh`'s to say.
- **A round that does not get to its end** ends the run with exit code 2: an answer that never came makes bash give up on the command it is in, which
  would otherwise be the rest of the script, with no check made and exit code 0.
- **If the very first press takes hold of nothing** (the window server moves a dragged window, with no help from Arbor), the run says what the Mac looked like
  before its first input and now (`arbor_mac_facts`: how long it was left alone, locked, screen saver, what lies in front), takes a picture and ends with
  exit code 2: it says nothing about Arbor, and the steps after it would press wherever empty answers sent them. It happened once: an alert that an
  earlier step of the same job had left on screen lay over the title bars.

It takes over the pointer for a minute or two, so it is a target of its own; CI runs it after `arbor-e2e`.

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
make it quit Arbor, close the test windows and remove its folder first; after `kill -9` and a crash of the runner its guardian does (above).
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
it prints the same frames and the same log. `trace on` records there as in the app, on the fake clock, and `arbor-sim` is the real one, so a script that
records traces and replays or judges them is rehearsed to its end.

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
| `ARBOR_SHORTCUTS=all` | **Before** `source …/lib.sh`, in a script that is no section of the suite and presses keys of the whole map. A session is Arbor as it ships: nine keys, and a home without a settings.json. With this line every home starts with a file that asks for the whole map, and `arbor_settings` adds it to what it writes. A file the script writes by other means says `"shortcuts": "all"` for itself |
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
  last one in front, and floating windows stay where they are when something is docked, over it or behind it.
  `drag_window`, `titlebar_of` and `click_window` look for a point that nothing covers.
- `check` runs its command in a subshell, and `$(…)` among its arguments is evaluated once, before `eventually`
  starts trying: write `eventually wider_than $W1 400`, not `eventually test $(width_of $W1) -gt 400`. So does `eventually`, and
  `want`, which is a `check`. A variable the command sets is lost to the script: a function that starts Arbor anew or forgets its process
  runs on a line of its own, and the check asks how it ended. (Every Quit in a walk was once reported as a crash for that.)
- Commands that act on the focused window, and shortcuts, need a real `click` on a test window first.
- There is no public way to make gesture events. `pinch` (and `witness pinch`, below) fills in the fields a trackpad's
  events carry, and Arbor's tap reads the result as it reads a trackpad's on macOS 26; a new macOS may change that.
- On macOS 26 a menu bar item's window belongs to Control Center; `status_item` asks Accessibility instead.
- Arbor's menu bar item is a row of buttons, and the middle of it, which `status_item` gives, is Show the Desktop: `open_menu`, a right click, opens the menu wherever in the item
  it lands; `click` does not. Ask each time: paused, held or without the permission the item is one glyph, somewhere else. Ten scripts learned it at their first run.
- bash 3.2: no associative arrays, no `${x,,}`, and an empty array is an error under `set -u`.
- Plugging the virtual display in switches the runner's main display from 1024×768 to 1920×1080, and macOS shuffles the
  windows; unplugging switches it back. Ask `screen_of 1` and `frame_of` again afterwards.
- Camera commands without a window (`back`, `show-all`, `desktop`) act on the display under the pointer if the pointer was used last (F56): `move` there first.
- The virtual display keeps its UUID when it is unplugged and plugged in again (same vendor, product and serial number),
  but only within a run: another Mac gives it another.
- `vdisplay.m` uses private API (CGVirtualDisplay, SkyLight). That is allowed because it is a test helper that no target in
  `Package.swift` contains; nothing of it may move into `Sources/`.
- The window server's list lags behind Accessibility, and not in one piece: tens of milliseconds after a command has answered, `real_frame_of` may still give the old
  place, or the new size at the old place. A `check` waits (`eventually`); a place noted for later does not, so note it with `resting_frame_of`.
- A window takes presses some points beyond its frame, to be resized by. `click_window` and `drag_window` keep 8 points clear of whatever lies in front.
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
It leaves session 3, the guard of the Desktop, out; `input-taps-with-the-guard.sh` plays all of it.

**Measuring.** `scripts/mac-shell/perf.sh` times camera moves over twelve real windows of one app and of four, using
`arborctl stats`; checks that overlay panels that were put away and handed out again still show and take a drag; then runs
1200 commands and prints `footprint`, `heap` and `leaks`, and `top`'s idle wakeups while nothing happens.

`scripts/mac-shell/first-dock.sh` measures the first act after a start against the next ones, with nine real apps open, in the debug and in the
release build, each with and without what Arbor gets ready ahead of the first motion (`ARBOR_NO_REHEARSAL=1` is the control). Its first session is the
one that counts: a hosted Mac has drawn none of the apps' icons yet, which is what cost the first dock of a day its seconds. Its tables come from
`first-dock.py`, which needs no Mac: `first-dock.py table <arbor.log> <trace.jsonl>…` says of any recorded session, for every command that moved a
window, how long it was until the first move, how much of that the stage took, when the last app had answered and when the stage was down.

**How far a window grows.** `probe-how-far-a-window-grows.sh` (twelve minutes), `probe-a-size-call-in-the-hand.sh` (eight) and `probe-when-the-display-turns.sh` (not played yet) ask macOS itself, with Arbor not
running: `grow.swift` sets size and position through Accessibility one call at a time and writes down what came of each. They judge nothing: every line is an answer. `grow-table.py` and
`grow-hand.py` print the lines; what they answered is `collab/reports/2026-10-15-how-far-a-window-grows.md`, and the lines are kept in `collab/evidence/how-far-a-window-grows/`.

**Filming.** A burst of screenshots gets fourteen pictures a second, and a motion of Arbor's lasts half a second. `scripts/mac-shell/lib-film.sh` has a camera
(`camera.swift`: every frame ScreenCaptureKit delivers, lossless, with the moment the display showed it and the moment the key went down):
`scene zoom camera "presses ⌃⌥↩"; key ctrl+opt+return; scene_end` leaves `mac-shell/films/zoom/`. `scripts/mac-shell/films.sh` films everything of Arbor's that moves,
and `scripts/polish/judge.py` measures the films anywhere (how long, how eased, how many motions, what hopped, flickered or flashed), lays them out on sheets to look
at, and scores them against `docs/POLISH.md`. `make polish-selftest` tries the judge on films drawn wrong in known ways.

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
scripts/mac-shell/run.sh --release scripts/mac-shell/day.sh              # the release build: for whatever is measured
```

**What is measured is measured on the release build.** `arbor_build` builds and drives `debug`, as `swift build` and the tests do, unless `ARBOR_CONFIGURATION=release` says
otherwise; `run.sh --release` says it to the hosted Mac. How busy Arbor is, how long anything takes and how smoothly it moves belong to the program people get: without
the optimizer it is another program. The release build is made before the first script and kept for the next run under a name of its own, so neither kind is
ever taken for the other or built upon it. The line "built Arbor (release), …" in `output.txt` says which one a script drove. Whether something works at all is asked of
`debug`, which every test runs against and which is nearly always built already.

They run one after the other. Each gets its turn and its own twenty minutes, whatever became of the one before, and starts with an empty
`mac-shell/` **on the Mac as the first one found it**: after every script macOS's own tiling, the click on the wallpaper, Reduce Motion and light or dark are put
back, and `output.txt` says so. What cannot be put back (Accessibility gone after a `tccutil reset`, another number of Spaces or displays) ends the list: the scripts
that are left do not run, say why, and end with exit code 75. Give a script that does such a thing the last place, or a run of its own: `shots-finder.sh`, `check-desktop.sh` and `check-macos-double-click.sh` add a Space, and nothing takes a Space away; `input-taps.sh` and `input-taps-with-the-guard.sh` take the permission away and give it back. The desktop picture is not looked at. What comes back is `.mac-shell/<first script>-x3-<run id>/` with a folder for each, `1-shots-F10/`, `2-shots-F12/`, …, holding what a
run of that script alone would have brought (`output.txt`, `exit-code.txt`, pictures, logs), and `summary.txt` with a line for each. `run.sh` exits with the
first exit code that is not 0. At most four to a Mac; more are shared out, a block of the list each, among as many Macs as that takes, or among `--macs N`, whose
output lies in `mac-1/`, `mac-2/`, …; `--at-once 2` lets a long list hold two Macs at a time and leaves the others to everybody else. A script that is given to several Macs by itself finds in `$MAC_SHELL_SHARE` which part is its own
(`2/3`: the second of three); `compat.sh` takes every Nth app. Every script finds in `$MAC_SHELL_PART` and `$MAC_SHELL_PARTS` which playing of the whole
dispatch it is and how many there are, over all its Macs: its place among `run.sh`'s arguments. A Mac plays a block of the list, and the name of its job says which
(`shell (parts 5-8, …)`). All of it is settled before the first script begins, and each playing's folder holds a `run.json` from then on that says `"started": false`,
until the script leaves one of its own in `mac-shell/`: so a playing that never began shows as that, not as a gap. What has been gathered comes back also when the job is cut
off in the middle of the list. All kinds of Mac come out of the same five at a time.

**Every run is recorded**, without the script doing anything for it: `traces/<script>-<session>-<number>.jsonl` holds what macOS reported, what Arbor asked of it and what the apps answered (never a window title), a new trace from every `step`, with every heading and every check as a remark. `make replay FILE=…` tells one as a story, on any machine. **What the Mac showed you should never need a Mac again:** `scripts/trace-to-test.py <trace> <name> --shows "…"` makes a test for every platform of it, in one command (`docs/TRACES.md`, "Every run on a hosted Mac is recorded" and "From a run on a Mac to a test"). A script that measures time says `ARBOR_TRACE=0` above `source lib.sh`.

**A press says what it lands on**, if that is not what the script opened: under an alert, a permission dialog or a banner, which macOS floats above every app's windows, `click` and `drag` print `✘ NOT ARBOR: UserNotificationCenter's window (382 118 260 250, layer 8) lies over 510,152`, which counts as a check that failed and, like every ✘ on a hosted Mac, leaves a picture of the screen at that moment (`fail-<script>-<n>.png`). `e2e-drag.sh` was red for hours, and six theories about Arbor died, before somebody saw that such an alert lay over the title bars it pressed on. arbor-e2e leaves the moment of each failed check in `mac-shell/e2e/`: `failed-<n>.png`, and `failed-<n>.txt` with the windows on the screen from front to back.

**What comes back is kept small.** Everybody's `git fetch` brings every output branch along, so a branch holds at most 40 MB (`scripts/ci-keep-output.py`). Output, logs, traces and other text always stay; films, then pictures go, the largest first, and `dropped.txt` says which. A script that needs more writes the megabytes, 200 at most, into its output folder: `echo 150 > "$ARBOR_OUT/keep-mb.txt"`.

**Whose turn it is.** GitHub hands its Macs out in no particular order: a job has been seen to wait eight minutes while later ones started. So
`run.sh` keeps the order itself, before it starts the run, where waiting takes nobody's place. `--priority 1` (or `ARBOR_MAC_PRIORITY=1`) waits for nobody's ordinary run: a
fault on real windows, a merge train, whatever others are blocked by. `2` holds back while three or more jobs are waiting for a Mac. `3`, the default, holds back
while any is: pictures, features, whatever can wait. Whatever the priority, a branch has at most two jobs running or waiting at a time (`3`: one); the run that is being started again, under the same tag, does not count.
**A train goes first,** before every priority. While CI's macOS job for `train/…`, `swarm/trunk` or `main` is waiting for a Mac nothing else starts: everybody's landing
waits for that job. And it is seen coming: the job is not there until the one before it has had a Linux runner, for which a train has waited thirteen minutes while others
took the Macs. So from the moment its run is queued one of the five is kept free: nothing starts while four or more jobs are running or waiting. Priority 1 reads this
from what somebody else saw of late (`ARBOR_MAC_QUEUE_CACHE`), asks GitHub nothing, and goes if there is nothing to read.
It says what it is holding back for, and the wait counts towards `MAC_SHELL_TIMEOUT`.

**When what held everybody back is over** (a train, a declared hold), all who waited would let go in the same minute, in the order their timers fire: five runs of priority 2 have
taken all five Macs in the minute before three of priority 1 were started. So priority 1 goes at the look that says it is over, `2` a look later, `3` two looks later, and each asks
again then. A queue that was merely busy is nobody's signal, and nobody gives way after it.

**A lower priority is a delay, not never.** GitHub's own line is first come, first served, and whoever holds back here has no place in it. "Fewer than three waiting" once did not come
for a whole night: seven sessions held back for up to two hours and started nothing. So after eight looks at a busy queue (some twenty minutes) a run of priority `2` goes whatever
waits, one of priority `3` after sixteen (`MAC_SHELL_AGE`), and says so. Only a busy queue is outwaited: a train, a declared hold, changed rules and the branch's own runs hold as ever.
A run that holds back lives as long as the shell it was started from: `nohup scripts/mac-shell/run.sh … > run.log 2>&1 &` outlives it.

**The tag and the branch stand at the end of a run's title, and GitHub cuts a long one.** So `run.sh` sends a short one: one script by its path, several by their names, of more than four the first three "and 9 more". What runs is in the plan. Should a run not be found after GitHub took it (98, "did not appear"), it may stand in the line all the same: `run.sh` prints how to look. Look before sending it again.

A run that ends with 95 says how many looks it has held back: `MAC_SHELL_HELD=N` before the same command carries them over.

**Whoever has waited acts on what was true when the waiting began.** With `ARBOR_MAC_RULES` naming the files (colons between them) in which whoever coordinates writes what holds for
everybody, a run that has held back and finds one of them changed does not start: it prints what is new and ends with 95. That is for a reader to weigh, not for a timer. Read it,
then start the run again.

**The time limit never costs a Mac's minutes, nor a place in the line.** `MAC_SHELL_TIMEOUT` is `run.sh`'s patience and nothing else: for the wait for a Mac, and anew for the run once
it has one. No run is cancelled for it. At its end `run.sh` lets go, ends with 98, and prints how to see whether the run has ended, how to fetch what it brought and how to cancel it by hand.

**A look at the queue that hangs is left behind.** The look reads a file that several machines share, and a read that falls on the moment somebody else rewrites it has been seen to hang
for good, in a state in which no signal reaches it, though both who write that file write beside it and rename. So the look runs beside `run.sh`, is given a minute (`MAC_SHELL_LOOK`), and
then counts as a queue that cannot be read: priorities 2 and 3 look again, priority 1 goes.

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
- **Each script:** `bash -n`, `scripts/lint-mac-shell.py`, and, if it is built on `lib.sh`, itself or through a file it reads in, a rehearsal (below) that gets to the script's end: exit code 0, or 1 for a check that came out ✘, which may be the very thing the Mac
  is asked about. On the way it may not have said what is a slip on any machine: a command bash does not know, a variable nobody set, a command Arbor does not
  know. `lib.sh` goes on after a step that fails, so the exit code alone does not tell. Not needed for a script that is, with what it reads in and `lib*.sh`, what the trunk has.
- **What has passed is noted** in `.mac-shell/preflight/`, under Git's hash of what was checked and not under a commit: nothing is checked twice, and the note made
  in a container is found by `run.sh` outside it. What is not committed does not count, and where Git does not work nothing does.
- **`--no-preflight "<why>"`** starts the run all the same, for a script that needs what the fake Mac lacks. The reason stands in the run's title, for everybody to read.

Where branches cannot be deleted, the output branch
`mac-shell-out/<ref>.<script>` stays on GitHub and the next run of the same script replaces its content.
The workflow `Housekeeping` deletes it once it is a day old, so fetch what you want to keep before then. The same workflow
deletes branches whose work has landed (`scripts/housekeeping.py` has the rules, and what never goes).

### When real input "is not seen": first look at what is on the screen

A press with the real pointer goes to whatever lies at that place, and that need not be the window under test. For a night `e2e-drag.sh` failed 16 of
its 34 checks whenever it came late in CI's Mac job, and six explanations that blamed Arbor were tried and dropped. The seventh was a window nobody
had looked for: macOS asking *Allow "Python" to find devices on local networks?*, in the middle of the screen, over the very title bars the script presses.
A script that had run earlier on that Mac had left it there. Arbor saw no drag because there was none.

- **List what is on the screen before anything else:** `.build/mac-shell/pointer windows | grep " on "`. A line is id, process, layer, x, y, width, height, `on`
  or `off`, owner. A hosted Mac always lists Control Center, Window Server, Finder and the Dock, one of whose windows covers the whole screen. Anything else above
  layer 0 is foreign; the alert was `… 8 382 118 260 250 on UserNotificationCenter`. **And take a picture:** what an alert says is in no list.
- **Find the step by halves, in one dispatch:** give several Macs the steps in different orders (`run.sh --macs`), and have each step end by printing what it leaves
  behind. That named the script in two runs, after hours of theories.
- **An alert takes seconds to come up.** A probe that looks three seconds after each step puts it down to the step after. Have something watch and note the moment.
- **Where that one came from:** Python's `HTTPServer` asks the system for this machine's name when it binds (`socket.getfqdn`), also when it binds to 127.0.0.1, and
  nothing uses the answer. macOS can take the question for one about the local network: asked alone it took 35 s and raised the alert three seconds in, though not every time. A script that needs
  something to answer over HTTP uses `scripts/mac-shell/serve.py`, or binds as it does; `scripts/test-tooling.py` refuses the server as it is.
- **Real windows come first in CI's Mac job,** straight after the build, so that they meet a Mac on which nothing else has happened. Leave them there.

### When the display seems to stand still

A camera gets a frame when the display changed, so where nothing is meant to move, no frame says nothing. Put `pulse.swift`'s strip on top of everything: then a wait between two frames is a display that stood still. `framewatch.swift` writes down when the display changed and keeps no picture; `standstill.py table <run>` says for how long it stood still in each scene, with three witnesses that film nothing beside it (the display's beat, the window list, the key held); `story <run> <scene>` puts everything known about a scene on one clock. `check-standstill.sh` is the example.
- **Play it twice before believing it.** The first time a process shows a self-drawn panel again after seconds out of view, a hosted Mac stands still for most of a second, whoever the process is (`docs/REALITY.md`, `a-panel-shown-again-costs-a-hosted-mac-a-second`). A scene played once on a fresh Mac makes "the first time" look like "always". Print what the first play took all the same.
- **A control that is calm proves nothing until it does everything the suspect does.** `mover.swift` was calm through two runs, and stood still as soon as its panel stayed out of view as long as Arbor's.
- **Ask whether looking causes it:** play it filmed and unfilmed, from fresh starts, in turns.
- **The system log's clock drifts from the wall clock** on a hosted Mac (it was seen 0.4 s off). Take a line of Arbor's own from `log show` (subsystem `dev.arbor`) to tie them before believing an order of events.

### On a person's own Mac

**Nobody is asked to run anything on a Mac of their own, and no result from one goes into this repository** (issue #4, `docs/PUBLIC.md`): real Macs
are GitHub's hosted runners. This section is for the person who checks the repository out and runs a script all the same, which
nobody can prevent and which must therefore do no harm.

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
- **A runner of GitHub's on a person's own Mac sets `GITHUB_ACTIONS` as GitHub's Macs do.** So nothing takes the variable alone for "a Mac that nobody owns": `arbor-e2e` (its manners, `ARBOR_NO_PICTURES`,
  `ARBOR_NO_OPENING`), `e2e.sh`, which takes the variable away as `lib.sh` does, `install.sh`, `make-signing-identity.sh` and the tools `keys`, `pointer` and `vdisplay` ask for the account as well, as `lib.sh` does, and `make lint` names every line that reads the variable with no such question near it (a net, not a proof). The account such a runner
  runs under must never be called `runner`.
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
keyboard layout, a full disk, an interruption at any line. "Trunk" rows hold for the commit that brought this table. "Not landed" rows were read on a
copy from before the repository was public, and say what the script does once it has been brought over onto this harness: it is read again then, and runs on nobody's Mac before.

| Script | Where | On a person's Mac | Pointer and keys | What it skips there, or why not |
|---|---|---|---|---|
| `compile.sh`, `compile-tools.sh` | trunk | safe | none | They compile and start nothing |
| `sweep.sh` | trunk | safe | lets go, puts the pointer back | Only what the record of a run that was cut off names |
| `check-harness.sh` | trunk | safe | 10 s | The harness itself: run it first |
| `run-list.sh` | trunk | safe | its scripts' | Runs what this table calls safe, in order, and stops at the first sign of trouble. Keeps the display awake for as long as it lives (`caffeinate -d -i -w`), which changes no setting; the scripts are told which process that is, so that they do not take it for a call |
| `e2e-drag.sh` | trunk | safe, steps skip themselves | 1 min, on GitHub's Macs 3 | The second round, with macOS's tiling switched off |
| `reality.sh` | trunk | **never**: ends with 77 | | Ten minutes of pointer and keyboard, for observations that mean something only on the display a rehearsal has |
| `e2e.sh` | trunk | safe | 30 s | `make e2e` with full screen, then `e2e-drag.sh`; rewrites `collab/evidence/e2e-latest.txt` |
| `shots-F45.sh` | trunk | safe | none | |
| `shots-F48.sh` | trunk | safe | 5 s | |
| `shots-F02.sh` | trunk | safe, steps skip themselves | one click | Reduce Motion, the wallpaper, crash reports; the stage without pictures of windows. About 25 times a panel of Arbor's covers the main display for up to 2 s |
| `shots-demo.sh` | trunk | safe, steps skip themselves | 60 s | `macos_tiling off`; the lists of what else is on screen |
| `proof.sh` | trunk | safe, steps skip themselves | 3 min | The `arbor://` claim (it would replace `~/Applications/Arbor.app`), `macos_tiling off`. A test window goes full screen |
| `check-review-ux.sh` | trunk | safe, steps fail | 90 s | The wallpaper is behind the curtain, so the two clicks on it prove nothing; the session with ⌘Tab skips itself |
| `check-F44.sh` | trunk | safe, steps skip themselves | 60 s | Really selecting layouts |
| `check-F41.sh` | trunk | safe, steps skip themselves | 2 min | The two measurements that press past the nets; switching layouts, and which are switched on; ⌘Tab |
| `check-keyboard-returns.sh` | trunk | **never**: ends with 77 | | Plain letters typed after each of Arbor's panels has closed: with a fault in Arbor they land in whichever app has the keyboard |
| `check-F49.sh` | trunk | safe, steps skip themselves | 2 min | The second display |
| `check-F51.sh` | trunk | safe, steps skip themselves | 90 s | Holds ⌃⌥Space down for seconds at a time. All of it is ⌃⌥Space: declined where several input sources are on |
| `check-switch.sh` | trunk | safe, steps skip themselves | 60 s | ⌘Tab: the app used before may be the person's own |
| `check-F56.sh` | trunk | safe, steps skip themselves | 60 s | The second display. Types "arbor" into a test window |
| `check-F09.sh` | trunk | safe, steps skip themselves | 3 min | Reduce Motion. The button is held for up to 6 s at a time, ⌘ for 2 s. macOS's own edge tiling stays on and may cost some checks at the screen edge |
| `check-F18.sh` | trunk | safe | 15 s | |
| `check-drag-from-behind.sh` | trunk | safe | 30 s | A second test app |
| `check-F20.sh` | trunk | safe | 60 s, mostly keys | Types "Pair" and "up" with its own test app in front, which for this script has an icon in the Dock. One step is ⌃⌥Space: declined where several input sources are on |
| `check-F54.sh` | trunk | safe, steps skip themselves | none | Part 2: Arbor over every window, TextEdit and Terminal killed and opened |
| `check-F53.sh` | trunk | safe, steps skip themselves | 2 min | Launching Calculator by name. A second test app under the name ArborScratch |
| `trace-demo.sh` | trunk | safe, steps skip themselves | 3 min | Every real app. The test app hides itself for two seconds: an app of the person's comes forward, after which presses on it are declined |
| `shots-focus-ring.sh` | trunk | safe, steps skip themselves | 90 s | Reduce Motion, click-wallpaper, the wallpaper, Mission Control |
| `shots-minimap.sh` | trunk | safe, steps skip themselves | 3 min | Reduce Motion, so with that setting on nothing fades. Presses ⌃⌥M, and holds it down for seconds at a time |
| `shots-F15.sh` | trunk | safe, steps skip themselves | 4 min | The wallpaper, dark mode, the click through the backdrop, `scenery` altogether. The backdrop lies behind the curtain, so pictures taken here do not show it |
| `shots-F43.sh` | trunk | safe, steps skip themselves | 2 min, mostly keys | The Mac's appearance, the wallpaper, Reduce Motion, the second display. Types one x with the panel of shortcuts up or a test window in front |
| `shots-F12.sh` (`axfind.swift`) | trunk | **not before it has been read again**: it has run on hosted Macs only | 4 min | Clicks and types only in Arbor's settings window and on its test windows. The two faults of the first reading are mended: its pictures of the settings window are `look`'s, and the ⌘W it records as a shortcut is given back whatever ends the script |
| `shots-review-controller.sh`, `events.sh` | trunk | safe, steps skip themselves | 30 s | `macos_tiling off`. A test window goes full screen: a Space of its own for a moment |
| `probe-keyboard.sh` | trunk | safe, steps skip themselves | none | ⌘W. Reads who would get a key and presses nothing; no pictures, no titles. Its test app is in the Dock and in front for some twenty seconds; the app that was in front is brought forward again |
| `watchdog-bundle.sh` | trunk | safe, but leaves a trace | none | `open`s a bundle of its own under an identifier of its own: LaunchServices keeps the entry for a while |
| `check-displays.sh`, `check-desktop.sh`, `compat-pictures.sh` | trunk | **never**: end with 77 | | Virtual displays, dark mode, wallpaper, a Space that stays, every window arranged |
| `check-sweep.sh` | trunk | **never**: ends with 77 | | Clicks on the wallpaper, which sweep aside whatever is open |
| `compat.sh`, `compat-extras.sh` (`lib-apps.sh`) | trunk | **never, unless the person says `ARBOR_APPS_HERE=1`**: end with 77 | | An app that was not running is still theirs: launched, it brings back last time's windows and unsaved documents, and `app_quit` answers "Don't Save" |
| `input-taps.sh`, `input-taps-with-the-guard.sh` | trunk | **never, unless the person says `ARBOR_INPUT_TAPS_HERE=1`**: ends with 77 | | Pinches, scrolls and clicks at fixed places past the nets; stops Arbor while its taps hold everybody's input |
| `rehearse.sh` | trunk | **never on a Mac**: ends with 77 | | It tells scripts that the Mac is thrown away; only what has a stand-in is fake. For Linux |
| `run.sh` | trunk | safe for the Mac | none | Starts a run on GitHub |
| `check-F13.sh` (`lib-F13.sh`) | trunk | safe | none | 10 to 25 minutes and 2 GB. Everything in a sandbox under `/tmp`: a throwaway `HOME`, `ARBOR_HOME`, keychain and clone. A small window takes the keyboard twice for seconds. Three copies run with their watchdog, which after a crash would use `open` |
| `check-signing.sh` | trunk | **never**: ends with 77 | | Five minutes, `--bare`. Keychains of its own go on the account's search list and come off again; it answers macOS's dialogs about a key, and in the end replaces the account's login keychain by an empty one |
| `check-F12.sh` | trunk | safe | none | |
| `perf.sh` | trunk | safe, steps skip themselves | one drag | `footprint`, `heap`, `leaks` where developer mode is off (macOS would ask for a password) |
| `check-F13-system.sh` | trunk | **never**: ends with 77 | | TCC.db as root, `tccutil`, login items, `make install` as a person runs it |
| `check-e2e-guardian.sh` | trunk | **never**: ends with 77 | | Ends `arbor-e2e` four times in the middle of a run, three of them with `kill -9`, to see whether an Arbor is left: where one is, it stays on the Mac |
| `check-F58.sh` (`share-probe.swift`) | trunk | safe, steps skip themselves | 2 min | ⌘Tab, the second display, the grey wallpaper; the pictures of single test windows only where Screen Recording is granted already. Two test apps have an icon in the Dock. A test window is put at and beyond the display's edges, so with two displays it shows on the other for a moment |
| `shots-finder.sh` | trunk | safe, steps skip themselves | 3 min, mostly keys | ⌘Tab, Mission Control, the swipe to another Space. Types digits and letters with the palette open or its own test app in front, which has an icon in the Dock |
| `watch.sh` | trunk | **not this copy**: a later one, not landed | 6 s; 10 min in all | On the trunk: `arborctl watch` without a limit, more than 900 s, and the end-to-end runner under a time limit. The later copy: safe |
| `shots-F10.sh` | trunk | safe, steps skip themselves | 5 min | The appearance, input sources, the Accessibility list, a stand-in for another window manager. No `shot` here whatever `ARBOR_SHOTS` says, and no picture of the welcome window: it shows what `doctor` found on the Mac. A bundle of its own under an identifier of its own is opened through Launch Services, which keeps the entry for a while. Arbor's item shows in the menu bar |
| `desktop-facts.sh` | trunk | safe | none | It reads the window list, four preferences and three answers of Finder's, and names only Apple's own processes |
| `check-resume.sh` | trunk | **never**: ends with 77 | | Calculator and TextEdit opened, brought forward in turn, and quit; `ARBOR_APPS_HERE=1` does not open it |
| `shots-F15-apps.sh` | trunk | **never**: ends with 77 | | Ten real apps opened for their icons, and killed |
| `first-dock.sh` (`first-dock.py`) | trunk | **never**: ends with 77 | | Nine real apps opened and quit, every window arranged, Reduce Motion, the display's size |
| `check-F52.sh`, `check-F63.sh` | not landed, trunk | **never**: end with 77 | | Virtual displays, Accessibility taken from every app |
| `check-macos-double-click.sh` | trunk | safe, steps skip themselves | 40 s | macOS's other title-bar actions (it would change the setting), TextEdit and Terminal. A test window fills the display for some seconds |
| `check-claimed-keys.sh` | trunk | **never**: ends with 77 | | Writes an entry for Arbor's bundle into the privacy database; types into whatever has the keyboard |
| `check-menu-height.sh` | trunk | **never**: ends with 77 | | Clicks in the menu bar; pauses, holds and quits its Arbor from the menu |
| `check-window-list.sh` | trunk | **never**: ends with 77 | | Clicks in the menu bar and on rows of Windows ▸; hides and minimizes its own test windows |
| `check-comes-back.sh` | trunk | safe | | A docked window fetched out of the Dock or out of a hidden app while the view is elsewhere, on real windows, three rounds each: whether its neighbour ever shows on its way, whether what was on screen stays, whether it fills the screen at the end. In the rehearsal it cannot fail for the flight, which the fake Mac does not play |
| `probe-macos-own-moves.sh` | trunk | **never**: ends with 77 | | 10 min. macOS's own ways of moving a window, on a test window, TextEdit and Terminal, with Arbor paused and running: when the first and the last frame come, in how many steps, and what Arbor asked for meanwhile. A probe: it prints two tables and checks little |
| `probe-how-far-a-window-grows.sh`, `probe-a-size-call-in-the-hand.sh`, `probe-when-the-display-turns.sh` (`grow.swift`, `grow-table.py`, `grow-hand.py`) | trunk | **never**: end with 77 | | 12, 8 and 10 min, Arbor not running. The Dock moved and hidden, a virtual display plugged in, Reduce Motion changed, windows dragged with the real pointer, real apps opened and quit. Probes |
| `probe-an-app-that-is-ended.sh` | trunk | **never**: ends with 77 | | 3 min. TextEdit with a docked window is ended by SIGKILL, by SIGTERM, and asked to quit: how long the dead window keeps its slot, and what Arbor was told. A probe |
| `check-moves-of-the-view.sh` | trunk | **never**: ends with 77 | | Four minutes. After a key that moves the view, whose is the keyboard? A plain x is typed and counted where it lands: in an app Arbor does not look at, in a test window's sheet and panel. It also writes down what Accessibility names as the focused window meanwhile (`apptool names <pid>`; lines that begin with "names:"). A rehearsal plays it as far as the first tool the fake Mac lacks, and the fake Mac gives no sheet the keyboard |
| `check-a-key-in-the-wait.sh` | trunk | **never**: ends with 77 | | A virtual second display goes; Float All and Show Everything through `arborctl` at once, and ⌃⌥Space by a real key: refused, nothing moves, the line is on the display that is left; asked again every quarter of a second until it is carried out. Then a window goes to the Dock and the key half a second later is carried out. Three traces come back |
| `check-own-size-apps.sh` | trunk | **never**: ends with 77 | | Safari and TextEdit hung over the right edge and over the bottom by a real drag, docked, given back by Float All, a pause and Quit: whole, where they hung |
| `check-standstill.sh` (`pulse.swift`, `framewatch.swift`, `mover.swift`) | trunk | **never**: ends with 77 | | Watches the whole display for changes, changes Reduce Motion |
| `probe-mission-control.sh` | trunk | **never**: ends with 77 | | Mission Control and the app's windows opened, a window picked there by a click |
| `probe-whose-key.sh`, `probe-fn-bit.sh` (`lib-ears.sh`) | trunk | **never**: ends with 77 | | Some fifty shortcuts pressed a dozen times over into whatever is in front; event taps that listen; hot keys registered; secure input switched on and off; Arbor stopped, killed and installed as a bundle of its own under `~/Applications`; the display put to sleep; an entry in the permission database, as root |
| `census-menu-keys.sh` | trunk | **never**: ends with 77 | | Alone on its Mac. Opens and ends every app, installs apps and leaves them, lifts the browsers' quarantine mark, prints the titles of menu items |
| `check-F59.sh` | not landed | safe | 30 s | During a carry nobody's app gets arrows, ↩ or ⎋ |
| `shots-F04.sh`, `shots-F34.sh` | not landed | safe | 3 min, 60 s | Test windows go to the Dock and come back; one is closed by its tab's button |
| `shots-F22.sh`, `shots-F19.sh` | trunk | safe | 90 s, 45 s | |
| `check-F14.sh` | not landed | safe, steps skip themselves | 3 min | The double-click on the wallpaper, Safari, the survey of stock apps. A witness that only listens writes down every press of the button meanwhile, with its place. macOS zooms a floating test window to the full display |
| `check-F21.sh` | not landed | safe, parts skip themselves | two clicks, five keys | The virtual display; Arbor over every window; apps opened |
| `film-F16.sh` | not landed | safe, steps skip themselves | 3 min | Reduce Motion. Pinches and ⌃⌥-scrolls over a test window, each after the net was asked; the helper is on record |
| `input-taps.sh`, `witness.swift` | trunk, and later copies not landed | **never without the switch**; with it, not before the fixes | | A witness that is killed leaves ⌃, ⌥ or Space down and a gesture unfinished; ⌃ with a wheel is macOS's zoom |
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
  for the first time on that Mac: a reviewer reads it line by line before it lands.
- **`arbor-e2e`** keeps to a home and a socket in a temporary folder and to its own test windows (`ARBOR_ONLY_PIDS`), with shortcuts, menu bar item and prompts off; it posts no input and opens no app.
  It does bring its test windows to the front and gives them the keyboard. A new step may not open an app, a URL or a document, write outside that home, or leave a panel up when the run dies.
- `make <target>` succeeds without doing anything when the target is only left in `.PHONY`, which is how a merge once turned `make e2e` green; `scripts/test-tooling.py` holds every declared target to a rule.

## 6. Traces (`make trace`, `make replay`)

(For what a display **shows** over time, without a Mac: `make film`, `docs/FILM.md`. A script runs against the real controller and every sixtieth of a second is
written down: windows, overlays with their fades, the stage and its stand-ins, pointer and keys.)

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

### Walks for a hosted Mac (`arbor-sim walk`)

The gate wants half of its 2,400 acts from walks that nobody wrote by hand (`docs/VIABLE.md`, "Who writes the journey"). `arbor-sim walk` writes them, in `lib-walk.sh`'s words, and plays the same
file against the stand-ins. So **one seed is one journey in both places, judged by the same rules**, and every difference between the two playings is either a lie of the stand-ins
(`collab/reality.json`) or a fault that only a Mac shows (the board).

```bash
swift build -c release --product arbor-sim; B=.build/release/arbor-sim
$B walk f1240ac3.1 110 --for-a-mac stock laptop defaults <commit> > scripts/mac-shell/f1240ac3.1.sh   # a walk of about 110 acts: a file that bash runs on a hosted Mac as it stands
$B walk f1240ac3.1 110 --words stock laptop defaults                    # only its words, one a line
$B walk --rehearse --samples linux.log < scripts/mac-shell/f1240ac3.1.sh   # plays a walk, whoever wrote it: the story, what was left out, which rules broke
python3 scripts/mac-shell/jolts.py report linux.log                     # the detectors of the gate, over the playing on Linux
$B walk --rehearse --shrink --quiet < a-walk.sh                         # for each rule that broke and is no known failure: the shortest script that still breaks it
$B walk --rehearse --script < a-walk.sh | $B replay --frames --go-on    # its events are a script of the chaos lab's
$B walk --many 1 200 110 laptop off awkward                             # writes and plays 200 walks and adds up: acts by kind, left out, rules
```

**The seed** is any word without a space; the gate takes it from the commit's own hash, so that nobody can pick one that passes. The same seed, length and setting give the same walk on Linux
and on a Mac, **for one commit**: only acts that apply are written, so what Arbor does has a say, and a fix leads walks elsewhere. Compare walks of one commit only.

**It plays as it writes.** `lib-walk.sh` leaves out an act that does not apply, so a walk may be written blind; but then one act in seven is a Mac's time spent on nothing (15 of 116 in the first walk on a
hosted Mac). The writer plays each word on the stand-ins first and writes it only if it was played there: fewer than one act in a hundred is left out on Linux. What a Mac leaves out all the same is
no bad luck but a measured difference. The kinds come in the proportions of `acts_min`; what belongs together stays near each other (a pause is resumed, what is minimized is restored, an app that quit is
opened again, within a few acts); the last line of the file counts the acts by kind. A word at which an expectation of the script's own does not hold on the stand-ins (a window dropped where there is no
room floats, and "it is docked" is not so) is struck out and the walk written again from the same seed: on a Mac it would be a finding, and the gate allows none. `--many` counts them.

**The first version** has `switch`, `open-close`, `dock-key`, `drag`, `drag-where-macos-tiles`, `view`, `resize`, `way-out`, `quit-and-start`, `idle` and `tile-click`, with each of the three casts (of `browsers` no Mac has been asked yet: its sizes are guesses that the first run corrects). Changes of
displays, hiding, native tabs and full screen come from the written days. The rehearsal plays those words too, so a walk of `walk.py`'s can be rehearsed; a click on the wallpaper it cannot play
("not rehearsed"): the stand-in's macOS does not sweep the windows aside.

**Somebody who does not know Arbor** (`--stranger`; `collab/IDEAS.md`, I25). Arbor runs, and nothing is asked of it: only what is macOS's or an app's is done. Plain drags, double-clicks on title bars,
full screen, ⌘Tab, ⌘M, ⌘H, ⌘N, ⌘W, ⌘Q, the edges where macOS tiles. The same file is played without Arbor, and **the right answer is that nothing differs**:

```bash
$B walk 3deb36a.1 100 --for-a-mac stock laptop defaults --stranger > stranger.sh
$B walk --rehearse --quiet --samples with.log < stranger.sh;  $B walk --rehearse --quiet --without-arbor --samples without.log < stranger.sh
python3 scripts/mac-shell/walk-diff.py --with with.log --without without.log [--all] [--json findings.json]
```

Each difference is counted once, at the act where it first shows, as one of three: `UNASKED` (a window the act does not name is elsewhere than without Arbor; and whatever differs once Arbor has started, or has
quit), `REVERSED` (the window the person dragged, double-clicked, put into full screen, switched to or brought back is not where the same act leaves it without Arbor), `IN FRONT` (another app or window ends in front, two
windows lie the other way round in the pile, or an act that any Mac has applied in one playing only). Each weighs as much as a lost window. Below them: acts, keys, presses, and seconds until the screen was at rest, either way, and how many of those seconds came after the last key
or press of an act, which a person spends waiting. The header of `walk-diff.py` says what is nobody's doing: the scene, and an act that could not be performed.

`--stranger --docked 2`: two windows are docked first, by the keys, and from then on nothing is asked. That is where a double-click on an arranged window's title bar is pulled back, which `jolts.py` finds, by what an act may
move (`docs/VIABLE.md`, section 6). A control cannot dock. Laid beside such a walk it says what the docking cost: the windows the act names, or says it may move, are where the person wanted them; every other window that moved with
them is `UNASKED`. **Of a window that Arbor placed it sees little after that**, only that it goes where it has not been: that it falls back, or that Quit leaves it where Arbor had it, is for `jolts.py`, rules 2 and 5.
What was asked of Arbor is in none of the costs.

**On a Mac the two playings go on two Macs**: `scripts/mac-shell/run.sh --macs 2 the-walk.sh its-control.sh`, the control being a wrapper that says `export WALK_WITHOUT_ARBOR=1` and runs the file. Fresh hosted Macs open the
cast at the same frames to the point; a second script on one Mac begins where the first left the windows. Two controls on two Macs, an hour apart, differed at none of 87 acts. **One playing to a Mac cannot tell
Arbor from the Mac**: what only one Mac of several shows is played again without Arbor, with it and without it on one Mac, before anybody calls it Arbor's.

**A walk is plain text and nothing else:** the shebang, comments, the one `source`, `walk_begin`, one word with its arguments a line, `walk_end`. `Walk(text:)` refuses the rest, so a walk cannot sleep, call
`arborctl`, set a variable or name anything but the cast. Never a title.

**The player on Linux is `lib-walk.sh` over again** (`WalkPlayer+Words.swift`, function by function: the same conditions, reasons, slugs and keys for `jolts.py`). `WalkTests` reads `lib-walk.sh`: a word that is added
there, a key that is no longer bound to the command played here, a reason that is worded otherwise, a number of `docs/VIABLE.md` that has changed, each turns a test red.

**After a run on a Mac**, lay the two side by side. An app remembers its frame from the script before, so no two runs begin alike: `--scene` begins the rehearsal where the run began (its display, its
windows' frames, its pile, which apps had been in front).

```bash
$B walk --rehearse --scene mac/samples.log --samples linux.log --quiet < the-walk.sh
python3 scripts/mac-shell/walk-diff.py mac/samples.log linux.log [--all] [--within 2]
```

It says which acts were played in one place alone, where windows, the pile or what is docked differ at the end of an act that both played, and **where the two part for the first time**: from there on one
difference breeds the next, so that act is the one to look at. The first comparison, of a walk a hosted Mac had already played, ended 29 acts in a row alike to the point and corrected five smallest sizes
of `RealApps.swift` and where a window lies that is dragged off a tile of macOS's, and showed that a second Tab posted too soon after ⌘Tab does not count.

- **One playing to a Mac cannot tell Arbor from the Mac.** A pair of Macs, with and without, detects; what one Mac of several shows is played without, with, without on ONE Mac before anybody calls it Arbor's: give `run.sh` the three scripts in that order (`who-comes-forward-1-without.sh`, `-2-with.sh`, `-3-without.sh` are the pattern). Then `walk-diff.py --with <2> --without <1>`, the same with `<3>`, and the two without Arbor as `walk-diff.py <1> <3>`.
- **Three playings on one Mac begin alike only if each leaves the Mac as it found it.** An app opens its next window at the frame its last one was closed at, Arbor's frame too, and that outlasts both Arbor and the app. A script that closes windows opens them again at its end and gives them the frame they had at its beginning (`put_back` in `who-comes-forward-docked.sh` is the pattern).
- `scripts/mac-shell/held.py <samples.log> [<beginning of a slug>]`: of every drag in a playing, the pointer's real speed, its way and the window's, and where the window stood. The speed a script asks of `drag` is not the speed it gets.

### A newcomer's eval (`make newcomer`, `scripts/newcomer`)

The day finds faults; it cannot find "I could not find it" or "it took five steps". For that, somebody who has never seen this repository gets what a stranger
gets (the top of the README, a build to install, a hosted Mac with the same real apps on it) and eight small tasks, sees nothing but pictures of the screen and acts only with real keys,
clicks and drags: an agent, through Git, one picture and one act a round, with no key and no call to GitHub's API. The same tasks are played with macOS alone, and the score
sets the two side by side, task by task: done or not (read from the window server's list), acts, wrong turns, stuck, surprised, looked up, windows that moved though the act did not touch them.

```bash
make newcomer RUN=n1                  # macOS alone; prints the two lines to give the newcomer when the first picture is up
make newcomer RUN=n2 BUILD=3deb36a    # with Arbor, built from that commit, lying zipped in Downloads, marked as a browser marks a download (UNMARKED=1: spared Gatekeeper)
scripts/newcomer/fetch.sh n1 n2 && scripts/newcomer/score.py .newcomer/n2 .newcomer/n1
```

**Whoever has read the repository is no newcomer, and whoever has played once is none either**: start a fresh one each time, without the source and without notes.
`scripts/newcomer/README.md` has the tasks, what counts as what, how a round goes, what can leak, hang or be sent as nonsense, and what the eval does not tell. All of it but the Mac is
tried on Linux by `scripts/newcomer/rehearse.py`, a row of `make lint`.

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
- **The walk upstairs**: the same with the real controller on top, commands, a pause, a quit and a new start among the steps, and rules that look at the model's screen.
- **`REF=origin/fix/some-cure make mac-on-linux`** holds another commit's layer against this checkout's stories: how a cure is tried before a Mac sees it, as the one for the app switch was. `COVERAGE=1` says which lines no story enters (92 % of `AXWindowSystem.swift`'s are entered).

Run it after every change under `Sources/ArborKit/AX`, and tell a story for every fault a Mac shows there. A green story proves the layer right about what we have seen or guessed, not about a Mac; a red one that rests on a guess is worth a run on a hosted Mac.

## 10. The real-window suite (`scripts/mac-shell/suite.sh`)

`make parity` calls a shipped feature *tested* when its unit and scenario tests pass, and *verified* when its
real-window steps passed too. The suite is where those steps live: every shipped feature exercised the way a person
does it (drags to screen edges and onto windows, seams and edges, title-bar buttons, every shortcut, the menu bar,
`open arbor://…`, settings.json, quitting, killing and restarting), and checked against the window server.

```bash
make suite                                                       # on a Mac: twenty-five minutes on a hosted one (SECTIONS="30 60" for some)
ARBOR_KEEP_EVIDENCE=1 scripts/mac-shell/run.sh --macs 2 scripts/mac-shell/suite.sh   # all of it on two of GitHub's Macs, side by side, from anywhere
scripts/mac-shell/run.sh scripts/mac-shell/suite/30-seams.sh     # one section, about a minute
scripts/mac-shell/rehearse.sh                                    # all of it against stand-ins, on Linux, for nothing
scripts/mac-shell/rehearse.sh --jobs 4                           # the same on four fake Macs side by side, in under half the time
scripts/mac-shell/rehearse.sh scripts/mac-shell/suite/30-seams.sh
scripts/rehearse-suite.sh                                        # what `make check`, `make gate` and CI say: all of it, if the change can make a claim untrue
```

**Every change is held against it, on Linux.** The suite runs on real windows when somebody takes two Macs for it, and in between the product moves on: in one night
twelve of its claims went out of date and nobody saw it. So `scripts/rehearse-suite.sh` is a step of `make check` (and so of `make gate`) and CI's
`linux / rehearsal-1` and `-2`: all the sections against the real controller on the fake Mac, on every core, five minutes on four. It first says
whether a rehearsal can say anything about the change, in a second and before anything is built: what the branch and the working tree add to the trunk has to touch `Package.swift`,
`Sources/` less the macOS-only folders, the sections, `suite.sh`, `lib.sh`, `state.py` or the rehearsal's own stand-ins. Where nobody can tell, and wherever
work is integrated, it rehearses. It prints every ✘ under its section and claim; all of it is in `.build/rehearsal-<n>/log.txt`. `ARBOR_NO_SUITE_REHEARSAL=1 make gate` leaves
it out, for a second gate after a mend of a line by whoever has seen it rehearsed on the change already; the row then says so in capitals, and at GitHub nobody hears it.
**A ✘ there is yours**: either the change has brought a fault, or it has made a claim untrue, and then the claim is reworded in the same pull request. A claim that is
reworded has not been on a Mac: run `scripts/mac-shell/suite-parity.py`, which takes its item off "verified" until it has. Where work is integrated
and at night the job `suite-as-a-person` rehearses it once more as somebody's own Mac would run it, on a wide display with a notch.

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
- **A claim is about what Arbor can do, whatever it ships with.** A section's sessions begin with what ships off switched on: `ARBOR_EVERYTHING_ON` in
  `lib.sh` goes under every settings.json of theirs (every other script gets Arbor as it ships). Whoever turns a default off adds the key that turns it on
  again there, a line, and no section changes. That Arbor as it ships does NOT do the thing is a claim of its own, in a session begun with
  `ARBOR_SWITCHES=shipped`. `ARBOR_SWITCHES=shipped make suite` runs all of it at the switches that ship: what is red then leans on a switch that is off.
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

## 11. Reality: the stand-ins against a real Mac (`make reality`)

Everything in sections 1 to 3, and every rehearsal, runs on stand-ins (`Sources/ArborTesting`, `Sources/arbor-fakemac`), and they are more polite than macOS: thousands of
tests pass on them while the serious faults are found on real Macs. `make reality` says how far the two are apart, as **one number to bring down to zero**:

```bash
make reality MAC=collab/evidence/reality-mac  # on Linux: rehearse reality.sh and compare with the last run on a Mac that was committed. A minute and a half, no Mac
make reality                                  # the same against a fresh run on a hosted Mac (push first): a quarter of an hour
make reality MAC=.mac-shell/reality-<run id>  # against an earlier run
make reality MAC="<run> <another run>"        # what not every one of the Macs' runs shows is counted apart, as unstable
make reality-trunk                            # after a batch has landed: the trunk's head on a Mac at once (priority 1), with the ratchet; the last line is the verdict
```

**`scripts/mac-shell/reality.sh`** runs unchanged in both worlds and expects nothing of a step (the only checks are `lib.sh`'s own at the end of a session, and in `edges` that the window came along with the pointer: a step that takes hold of nothing is the same in both worlds and says nothing). It plays five journeys, each in an Arbor session of its own: `commands` (what `arbor-e2e`'s first session does
over the socket), `apps` (windows minimize, hide, close and open; another app comes forward), `edges` (title-bar drags all the way to three screen edges, which with macOS's tiling on are macOS's: looked at while held and after), `pointer` (a drag to the bottom edge, which is Arbor's, `e2e-drag.sh`'s steps,
a seam and a tile) and `keys` (a click, then shortcuts). macOS stays as it comes, its own edge tiling included: that is where people live. After every step `observe` waits a second, looks until two looks
in a row agree (four seconds at most) and appends one line of JSON to `mac-shell/reality/<journey>.jsonl` (`scripts/mac-shell/reality.py` has the form):

| | |
|---|---|
| `belief` | what Arbor says (`arborctl state`): every window's status, frame and slot, the tree and the camera as a line of text, who it thinks has the keyboard, tiles, the Desktop, its own words |
| `truth` | what the window server says (`pointer windows`, `pointer keyboard`): every test window's frame, whether it is on screen, the order from the front, the app in front, the window keys go to, Arbor's own windows by level, macOS's own by owner (the outline of its tiling is WindowManager's) |
| `reports`, `replies` | what crossed the seam since the step before, from a trace that runs for the whole journey (a rehearsal records traces too): events as `changed:W1:user`, calls as `setFrame:W1 asked→took`, `focus:W1`, `raise:W1`, in order, nothing collapsed; and what Arbor answered to each command |

Windows are W1, W2… in the order they opened, and there are no process ids, node ids, titles or times, so two rehearsals give the same bytes. What the script's own questions set off is left out. The traces themselves
come back in `reality/traces/`.

**`scripts/reality-diff.py <mac> <linux>`** aligns the two by journey and step, compares field by field and prints one line per divergence: whether it is new, its class, its key
(`journey/step/field/window`, the same from run to run) and both values. Then a table by class and the number:

```
✘ new      answers         commands/zoom-W1/answers/W2/1023,767-325x650   mac: took 1023,677 325x650 | linux: took 1023,673 325x650
reality: 307 divergences in 66 steps of 5 journeys (new: 1, known: 306, gone: 0)
```

| Class | | Whose |
|---|---|---|
| `belief` | Arbor ends up believing something else: a status, a frame, the tree, the camera, a reply | follows from one of the others, as a rule: look at the step's reports first |
| `truth` | real windows end up elsewhere (by more than a point), or on screen where the stand-ins' are not | the stand-ins' |
| `belief-vs-truth` | **on the Mac alone**, what Arbor believes is not what the window server shows | Arbor's, or its Accessibility layer's, whatever the stand-ins do |
| `focus`, `stacking`, `overlays` | who has the keyboard and who Arbor thinks has it, which app is in front; the order from front to back; how many of Arbor's own windows show at a level, and of macOS's own | mostly `World.swift`'s and `Arbor.swift`'s in `arbor-fakemac` |
| `answers` | a window asked for the same frame took another, or Arbor asked it for another frame to begin with | `FakeWindowSystem.setFrame`; the second kind follows from something earlier |
| `reports-extra`, `reports-missing`, `reports-order` | the Mac reports what the stand-ins do not; the stand-ins what the Mac does not; the same in another order | `FakeWindowSystem` and `World*.swift` |
| `unplayed` | a journey or a step one world does not have | the script's, or a run that was cut off |
| `unstable` | any of these that not every run on a real Mac shows, or at a step that had not come to rest: counted apart, never dropped | timing |

What counts as one: a difference in belief or truth that stays the same from one step to the next, under the first step at which it can be relied on (a finding does not go on from something unstable, or it would hide behind it for as long as it
lasts); a frame that Arbor has right in both worlds (`truth` says it, that Arbor believes something else follows); a call to the same
window with another request or another answer. During a drag, a resize or a seam drag the number of moves is a matter of timing (a trace thins them by the clock), so a run of moves counts as one of each kind, written `~dragMoved:W3`.
Written down and not compared, which the report says every time: `settingsFileMayHaveChanged`, which is of another seam. (On a Mac every save of `state.json` wakes the watcher of `settings.json` twice, ninety times in a run.)

**The ratchet** is `collab/evidence/reality-known.txt`: every known key with the cause it is put down to, and at its top every cause with a reading: whose it is, which file would have to change, what a person would see. With
`--check` (`make reality MAC=… CHECK=1`, and CI) the tool fails for a key the list does not have *and* for a key of the list that is gone, so the list shrinks with every cure and never grows unseen. `~` before a key: not every run on a Mac
shows it, and such a key may hold `*` for anything, because what a fight with an animation leaves in a key is never the same twice. A key of a step that was not played, or had not come to rest, is neither known nor gone: it waits, and the report says so. `make reality MAC=… KNOWN=1` writes the keys anew and keeps whatever this comparison
does not refute: the remarks, the causes, the words, the `~` keys that did not show this time, the keys that wait. One lie shows at many steps: the first count, 2026-10-14, was some three hundred keys from some twenty causes, nearly half of them one constant, and the
report ends with the causes by how many keys each would take along (that constant and two more were cured a day later, and 186 keys went at a stroke). And one fault: the second recording, that same day, had 79 keys that said that docked windows no longer filled their slots on a real Mac
(`@clipped-at-the-dock`), half an hour after the change had landed with every test on Linux green.

**To bring the number down**: take a cause from the top of that table, read both lines of one of its steps (`.build/reality/report.md` has everything as tables; `collab/evidence/reality-mac/traces/` holds what macOS really sent, marked `reality: <step>` after every step), teach the stand-in to be as rude as
the Mac was, give the lesson a test of its own in `Tests/ArborKitTests`, run `make reality MAC=collab/evidence/reality-mac`, and take the keys it calls gone off the list. No Mac is needed for that: what the Mac did is on file. If it is Arbor that is
wrong, report it: the key stays until Arbor is cured, and then the Mac's side has to be played again.

**`collab/evidence/reality-mac/`** is that file: the observations of one run on a hosted Mac and its traces, as they came back. Play it again (`make reality`, then copy the run's `reality` folder there) after a change to `reality.sh` or `reality.py`, to Arbor's macOS-only code, or to
what the controller does in these journeys; a step the file does not have counts as `unplayed`. `commit.txt` in it says which commit was played. When `Sources/ArborCore` or `Sources/ArborKit` have changed since, the two sides may not play the same Arbor: the report
warns, and names the journeys with anything new as to be recorded again. `--check` fails on them all the same: a ratchet does not go soft.

**Three readers for what a run brings back:** `scripts/reality-slots.py <folder>` (at every step, does every docked window on screen fill its slot?), `scripts/reality-clip.py <folder>` (every `setFrame`: where the window stood, what was
asked, what it took; one display, the Dock at the bottom) and `scripts/reality-clip-any-display.py <folder>` (the same with the Dock anywhere and several displays). The recording that is committed is of one commit and goes stale
with every batch: `commit.txt` beside it says which.

**After every batch that lands**, the five journeys at the trunk's head, and no train leaves from a head whose run is red or missing:

```bash
git fetch origin swarm/trunk && git switch --detach origin/swarm/trunk   # any worktree: nothing is pushed, and no branch of anybody's is touched
make reality-trunk
# swarm/trunk at 1234567: green: 187 divergences in 70 steps of 5 journeys (new: 0, known: 187, gone: 0)
```

`run.sh` starts the Mac for the ref `swarm/trunk`, so the Mac plays what GitHub has there; the rehearsal plays what lies here, and the script refuses if the code, the scripts or the list here are not that head's.
**Play the head of a batch, not a commit in the middle of one**: a batch arrives commit by commit, over minutes, so the script first waits three minutes to see that the trunk stands still (`STILL=0` when whoever landed the batch has named the commit).
Then the Mac is started, and the rehearsal fits into the wait for it: some twenty-five minutes in all. **A run checks its branch out when the Mac starts, not when the run is asked for**, and a quarter of an hour can lie between the two: `commit.txt` in what comes back is the truth of what was played, the verdict names it, and
the tool warns when it is not the Arbor that was rehearsed. **RED** means a key the list does not have (`✘ new`, a line each, above the verdict), or one it has that is gone. For a new key look at both values, then
at the step in both traces, then at what the batch changed. A key that one run shows and the next does not is timing: `make reality-trunk MAC="<run> <another run>"` counts it apart, and a `~` before it in the list says so for good.
Gone keys are good news, and are taken off. When the fresh run is to be what everybody compares with from then on, copy its `reality` folder to `collab/evidence/reality-mac`.
Where Swift lives in a container and `gh` outside it, in two halves: outside, `scripts/mac-shell/run.sh --priority 1 scripts/mac-shell/reality.sh swarm/trunk`; inside, `make reality-trunk MAC=.mac-shell/reality-<run id>`.

**CI** does not run it yet. The step is written (the `real-windows` job plays the journeys, `linux` rehearses them, a small job compares the two with `--check` and gives the number as a check annotation) and comes
in a change of its own.

**Its limits**, plainly: five journeys of test windows on one small display. No real apps (section 7 has those), no second display, no app that hangs, no permission taken away, no timers, pinches, menus, Spaces or full
screen, and only what shows once things have come to rest. Green does not mean that Arbor works on a Mac: it means that in these seventy steps nothing differs that did not differ before. It caught the short windows because every dock met them;
a fault that needs a browser, a lid or a slow app walks straight past it.

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
after a failure, so one round tells all. Under the steps stands, if there is any, the reading list of `make unplayed` (above): it shuts nothing. What `make check` runs besides lint, the build and the tests it reads from the Makefile, so a step
added there is a step of the gate.

**One gate at a time on one machine** (one container counts as one, whatever the checkouts): two shut each other, and so do a gate and a
`scripts/test-tooling.py` beside it. The sign is a row of `lib.sh`'s that ends with 77 instead of 0, mostly "ARBOR_OUT from a stray environment is not
taken". That row takes `ARBOR_REHEARSAL` away on purpose, so there `lib.sh` is in earnest: it finds the other copy's run under `/tmp/arbor-run.*` and declines, as
it would on a Mac where two scripts would fight over the pointer. "On somebody's Mac a run that changed nothing says so" goes the same way, since the machine did
change. Neither says anything about the change under test: run the self-test again by itself. To wait for a machine to fall quiet, chain the steps in one
job: a loop round `pgrep -f <pattern>` finds the shell that carries the pattern, and never ends.

The same script can divide the tests among several machines, the compiling too (`plan`, `cut`, `join`, `same`): its header says how.
`scripts/test-fast-tests.py`, part of `make lint`, holds it to a table of Swift it must read rightly or refuse.

## The tools test themselves (`scripts/test-tooling.py`)

`parity.py`, `ci-step.py`, `scenarios.sh` with arbor-sim, `lint-imports.py`, `lint-mac-shell.py`, `mutate.py`, `fuzz-launch.py` and `reality-diff.py` are what says "all is well", so each is given
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
`release-notes.sh`, `sign.sh` and `make-signing-identity.sh` against stand-ins for `security`, `codesign` and `openssl` (`at-a-terminal.py` is the terminal), and
`publish-release.sh` against a stand-in for GitHub's API on the same machine (left out where there is no curl, as in the Swift image
for Linux).

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

`scripts/mac-shell/check-signing.sh` is the signing identity alone, in five minutes and with nothing compiled, so that it can be asked
of every macOS GitHub has (`run.sh --bare --on macos-14`): either openssl, a keychain off the search list, a throwaway `HOME`, somebody's
key and a certificate with a name like ours in the same keychain (every attribute and access list compared before and after),
`sign.sh`'s stamp against `codesign`, a terminal; then the account's own login keychain, where macOS asks and nobody knows the
password (no answer, Deny); and last the road a person takes, in a login keychain made anew: the dialog, the password, Always Allow,
and silence ever after. **A keychain that a test makes for itself proves nothing about the dialog**: its keys have no partition
list, so nothing is asked. What those Macs answered is what the stand-ins in `release-tools-test.sh` answer on Linux, with a run that
is cut short besides: ⌃C at the dialog, a signal, a reader that leaves.

`scripts/mac-shell/check-F13-system.sh` is for GitHub's throwaway Macs only (`needs_throwaway_mac`): it writes a grant into the
permission database and shows that the next build inherits it and an ad-hoc build does not, tries launch at login,
runs `make install` the way a person does, and takes pictures of the menu and of a downloaded copy's first launch.

## Chaos (`ChaosTests`, `arbor-sim chaos`)

A window manager holds people's windows, so the worst it can do is crash or lose one. The chaos test
throws random commands and window events at the real `Controller` and checks every invariant after each
one. It is a function of its seed: no clock, no system randomness, no dictionary order.

**What it does.** `ChaosGenerator` looks at the state of the world and picks the next `ChaosAction`, mostly one
that makes sense there and sometimes one that does not: apps open, close, quit, hide, minimize, change Space, go full
screen, retitle and change their size limits; the user moves, resizes, focuses, double-clicks title bars (and macOS zooms), asks macOS for another frame with its menu, its keys or ⌥-click on the green button (`ask-macos <window> fill|left|right|top|bottom|quarter|centre`), clicks tiles, drags seams, types and chooses in Go to…, and drags
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
wait; Arbor gives up only on windows that something keeps moving, and lets be only those that a double-click moved, through whatever nobody asked of it; only known timers, and they run dry; windows Arbor does not arrange are never moved;
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
| Nothing moves until the person docks something, and nothing that was not asked to | `moved-before-any-dock`, `fetched-before-any-dock`, `moved-at-launch`, `moved-at-launch-after-a-crash`, `moved-at-resume`, `moved-unasked`, `there-and-back-moved`, `pause-and-resume-moved`, `dragged-gap-did-not-last`, `same-windows-other-frames`, `displays-out-and-back-moved`, `taken-to-another-display`, `taken-out-of-view-with-another-display`, `taken-back-from-where-it-was-put`, `docked-at-a-start` | `moved-unasked` |
| A start takes nothing out of view, but for what Show Everything itself has out of view; a quit leaves nothing there | `start-took-out-of-view` (the window with the keyboard stays in view even if it is such a window), `quit-left-out-of-reach` | `lost` |
| A window moves once, to where it ends up | `moved-twice` (in the step of the command or event), `moved-again` (later, with nobody touching anything); `-sizing` where its app refused a size, `-sizing-again` where it had refused in the same way before; `sized-there-and-back` (never in a wrong place, but smaller or larger on the way than it ends up); all with `-floating` for a floating window; `sized-there-and-back-let-be` (the window that a start lets be, which is to be set no frame); `moved-twice-floating-windows-first` (with `soleFloatTakesDesktop`, where macOS reported the window before the displays); `set-right-by-less-than-a-cell` (a terminal in its slot). `flipped`: in view all the way, no app refused a size, and back where it began. Judged by the road, not by the number of requests (`FakeWindowSystem.detour`): a window Arbor does not know is asked to shrink where it stands, and then moved. It grows in its slot, and the first time it turns out unable to, the way on to the middle of the slot is left out of the road. So is the place where a window is sized on its way into a frame that hangs over the edge of the screen, where one request could not have given it that frame (`FakeWindowSystem.isSizedWhereItFits`) | `jolt` |
| Out of view means out of view, and nothing goes on for ever | `flashed-into-view`, `flashed-out-of-view` (an app refused a size in that step: a layout finding out), `flipped-into-view`, `flipped-out-of-view` (nobody refused: the view flew somewhere and was taken back); `moved-over-and-over` (more than three moves with nobody acting) | `flash`, `stuck` |
| Less by default (Q29): a floating window is its person's, and a plain drag is what it is without Arbor | `floating-taken-out-of-view` (never, by anything; only what was summoned may be sent away); from the moment a window is taken until somebody does something else: `plain-drag-showed-a-preview`, `plain-drag-docked`, `plain-drag-moved-it` (it floated, and Arbor set a frame on it), `plain-drag-moved-another` (it floated: nobody else moves; it was docked: only what is docked), `plain-drag-started-a-timer`; a docked window let go 24 points or more from where it was taken floats, at its own size: `plain-drag-left-it-docked`, `plain-drag-not-its-own-size` | `lost`, `moved-unasked` |
| The window you switch to comes to the front and into view | `switched-to-and-sent-away` (out of view with the keyboard in it), `switched-to-out-of-view`, `switched-to-mostly-out` (a floating window, where Arbor had put it), `switched-to-partly-out`, `app-switch-out-of-view` (only the app was reported), `switched-to-behind` | `focus`, `behind` |
| After a person's own act macOS decides who has the keyboard | `keyboard-handed-on-unasked` (nobody asks Arbor for anything, no window that it knows has the keyboard, and Arbor focuses one) | `focus` |
| Quitting, Float All and pause give windows their own sizes back | `size-not-given-back`; the size macOS gave a floating window at a change of displays is its own: Arbor may leave it and may set the earlier one back, and an Arbor that makes the window smaller itself is not let off | `size-lost` |
| After any way home no window shows less than its person left showing; after a change of displays none is mostly out of view | `home-not-whole`, `home-behind-the-dock`, `home-leaves-out`, but for the decided case: its own size, at the corner a hand gave, no less showing than was left showing; `displays-left-mostly-out`, `nothing-in-view-after-displays`, `nothing-in-view-held-after-displays` | `lost` |

**A person's ⌘M is never undone** (`ChaosInvariants+Undone.swift`): `minimize-undone` speaks when a window that has just been minimized is not. The stand-in plays what a Mac does to a minimized window that is given the keyboard or raised: it comes out of the Dock. `asked: undone` counts the minimizes a running Arbor saw. Its control is in `TheFlightToTheDockTests`, its floor in `ReviewFlightToTheDockTests.theWalksMinimize`.

**Arbor raises nothing else** (`ChaosInvariants+Raises.swift`, QUESTIONS Q20 and Q25): `raised-unasked` speaks at any raise, which is a window brought to the front without the keyboard, of a window that is neither kept in view nor summoned, at the step in which it is made,
and at any raise at all by an Arbor that has paused or quit. `switched-to-behind` sees the harm only where the raised window happens to lie over the one just switched to. `asked: raised` counts how often a floating window that nothing keeps in view
came back into view, which is where Arbor used to raise. Its controls and its floor are in `RaisesNothingElseTests`.

**A floating window's frame is its person's** (F64, `ChaosInvariants+OwnFrames.swift`). The runner keeps its own record of where each floating window was when it went out of view and of what a hand left where, and asks the
window system: `own-frame` (one in view was moved or resized, and nothing that happened was about it), `own-frame-back` (it came back somewhere else than it left from; `-after-undo` where an undo lies between),
`own-frame-jolt` (in more than one move), `own-frame-fit` (it came back where nobody is known to have left it, and less than half of it shows). Walks switch `floatingWindowsMakeWay` on now and then. From
there on the rules that placing, shoving and squeezing break (`rulesThatMakingWayBreaks`) are called `<rule>-making-way`, so **what is known of the old behaviour excuses nothing as Arbor ships**.
`make test-making-way` runs the whole suite with the setting on wherever a test does not choose its settings, which is how the suite ran until F64: a test of how Arbor ships says `Settings()`, one of the old
behaviour `Settings.makingWay`.

The ways home (`way-back home`, `show-all`, `pause`, `float-all`, `start-again`, `quit`) are each taken at the end of every walk, the ones that leave the arrangement alone first.
A hunt ends with `asked: <net> <n> times`: **a net that never asks its question catches nothing**, and `ordinaryWalksReachEveryQuestion` holds each to a floor.

**Ordinary walks** (`ARBOR_CHAOS_ORDINARY=1`): the displays of a real desk, apps with the smallest sizes real apps have, windows that open wholly in view, keys that are bound, items that are in the menu, the mouse, and
a moment between one thing and the next. No settings edited by hand, no app that fights back, no crash, no nonsense. **What such a walk finds is likely on a real desk**; what only the wild walks find has to be looked at for how a person would get there.

**Light walks** (`ARBOR_CHAOS_ORDINARY=light`) are the ordinary walks of a person who has read nothing (`collab/QUESTIONS.md`, Q29): a plain drag is the commonest thing they do, they know the nine keys,
the rest is in the menu, and no setting has been touched. Such a script begins with `settings {}`: **an empty object means that the file holds nothing, which is Arbor as it ships**, so these are the walks at the switches that
ship, on whatever commit they run, and a replay knows it from the script. Every other walk begins as walks always did (the gestures on, and whatever else went off by default since), so that recorded seeds and listed scripts keep their meaning.

**The Mac restarts in the walks.** After a restart of the Mac every window has a new number and comes back seconds after Arbor, one by one. Ordinary and light walks of seeds beyond the frozen versions restart the Mac now and then: Arbor quits; once it has let go of the windows, every window closes; 85 in 100 of them open again where they were, with the same app, limits and title and under a new number, in any order, a quarter of them before Arbor starts, the others one, two or five seconds apart after it (`ChaosGenerator.planTheLogin`). One in five says its title late: it opens under a title that says nothing and has its own a moment later. For that the windows of such walks have titles of one word. No frozen seed moves.

```bash
ARBOR_CHAOS_ORDINARY=light .build/release/arbor-sim hunt 1 2000 300                            # nine keys, the menu, the mouse; as Arbor ships
ARBOR_CHAOS_ORDINARY=1 .build/release/arbor-sim hunt 1 2000 300                                # the whole map of keys; the seed chooses the desk
ARBOR_CHAOS_ORDINARY=1 ARBOR_CHAOS_DESK=laptop ARBOR_CHAOS_DOCK=left .build/release/arbor-sim hunt 1 2000 300   # laptop | desk | both; bottom | left | right | hidden
ARBOR_CHAOS_ORDINARY=1 .build/release/arbor-sim hunt 1 2000 300 --known                        # the known failures end a walk like any other
```

**By the eye.** The cure for refused sizes came with a change to the net that judges it: by the road a window takes, `moved-twice-sizing` fell from 8,170 walks in 10,000 to 160; by a net that counts every change a person could see, `moved-twice` rose from 5,007 to 9,917, and a film from a hosted Mac agreed with the second. So both are on every board from now on. `eye-moved-twice`, `eye-moved-twice-sizing`, `eye-moved-again`, `eye-moved-again-sizing` count every change of a window that a person could see for one thing that happened. They are numbers: `step` keeps them apart (`runner.counted`), no walk, replay or test ends at them, a hunt counts them beside the known failures, and `replay --frames` prints them.

**Not yet gates**, counted in the same way until they read 0, because nearly every walk and many a strict test would break them today. Whoever brings one to 0 takes it out of `ChaosRunner.countedRules`, and it ends walks like any other rule. Each has a control.

| Rule | Asks |
|---|---|
| `floating-taken-out-of-view` | as above |
| `strayed-between` | whatever the number of requests: on its way a window covers nothing in view, over 400 square points, that neither its old nor its new frame covers. A window that comes into view counts from where it first shows. Not asked of one that grows into a frame that lies within no display, which is sized first |
| `dock-took-out-of-view` | a key that docks takes no docked window out of view that was in view: not the one it names, not one that becomes a tile for want of room |
| `displays-moved-the-untouched` | a floating window from which a change of displays took nothing, and which macOS carried nowhere, is not moved by Arbor either |
| `displays-fetched-what-was-in-reach` | at a change of displays Arbor fits only what the change took out of reach: a floating window that nobody named, whose title bar is within reach where macOS left it, is not set by Arbor at all, however little of it shows |
| `plain-drag-left-an-undo-step` | Undo after a plain drag of a floating window takes back what was asked of Arbor before, not the hand's drag |
| `keyboard-taken-unasked` | with nothing docked, kept in view or summoned, and nothing asked of it, Arbor sends the keyboard nowhere |
| `parked-before-any-dock` | with nothing docked, kept in view, summoned or sent away there is no view that could leave a window out, so none counts as out of view |
| `arrival-moved-a-neighbour` | after a restart of the Mac, while nothing but arrivals and time has happened since Arbor's start: a window that takes the place kept for it moves alone: its neighbours are where they will be |
| `arrival-took-a-neighbour-out-of-view` | and takes nobody out of view |

**A counted rule can be a gate for one run.** `ARBOR_CHAOS_GATES=rule,rule arbor-sim hunt …` takes those names out of the numbers for that run: they end walks and are shrunk. That is how to read what is behind a number, and how to see that it is 0 before taking its name out of `ChaosRunner.countedRules`.

**A word that is added changes no old walk.** A walk draws its commands and the settings it changes from lists, so one more entry sent every seed another way, and whoever added a command met, in their own pull request, faults of the trunk that had nothing to do with it. Now the lists are frozen, version by version (`ChaosGenerator+Vocabulary.swift`): seeds under 1,000,000 draw from the list as it stood on 2026-10-15; seeds beyond the last frozen version draw from everything there is, and are the seeds for hunting. The tests walk frozen seeds only. **Adding a command or a setting needs nothing there.** A new kind of act or a new weight gets its weight only where `drawsFromEverything` is true. The keeper of the lab freezes a new version now and then.

**Whose fault is a walk?** `scripts/blame-walk.sh script.txt` replays the shrunk script that a failure printed on this tree and on the commit where the branch left the trunk (built once for each commit in `.build/blame`), and says "THE TRUNK'S" or "ONLY WITH THIS CHANGE".

**The scoreboard** is the number of ordinary walks in 10,000 in which a rule broke, by rule: the `known:` lines of a hunt count the walks that passed a rule by, the summary line those that ended at one.

**Seeds under 1,000,000 are frozen for words, not for acts.** They draw their commands and the settings they change from lists as they stood on 2026-10-15 (`ChaosGenerator+Vocabulary.swift`), so a new `Command` case or a new setting changes none of them, and its author has nothing to do; the tests walk only such seeds. Seeds of 1,000,000 and up draw from everything there is: hunt with those. A new KIND OF ACT or a new WEIGHT in a generator still sends a seed elsewhere, so it gets its weight only where `drawsFromEverything` is true and 0 elsewhere. A change to the stand-ins or to the cast (the apps' sizes, a terminal's cells, macOS's tile) changes what the same acts lead to on every seed: across such a landing 'the same seeds' compares nothing; put the same lab on both sides and change only the product.
**A script means something only on a harness that knows its words**: a line that is no event is taken for
a command, and a command Arbor does not know does nothing, so a script with `via …` or `key down …` on a branch from before those events
replays to "every invariant held" and proves nothing. A command spelt like an event (`release`, `focus 101`, `save`) is written `do release`.

**Every walk ends in the three ways back** (`way-back float-all`, `way-back start-again`, `way-back quit`, each one step): after each, every window
that Arbor put where it is can be got hold of (rule `out-of-reach`). This is the test for a known problem before a release: a script that
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

**A drag and a key are shrunk whole or not at all.** Light walks are mostly drags, and the shrinker took them apart: 9 of 33 scripts shrunk from light walks on two displays had an act with a window still in the hand (a click on a tile between `grab` and `release`; a `grab` that is never let go while a display goes). Mended by hand they fell silent, and a real find was nearly written off as unreal. Now a candidate may hold no more half gestures than the walk itself had (`ChaosRunner.halfGestures(in:)`: something done with a window in the hand, a hand that moves or lets go of nothing, a key that goes down and never comes up, or comes up without having gone down; a gesture that the script's end cuts off is whole), and, since a gesture cannot go piece by piece, each is tried as a whole once single acts can go no further.

**The orders of reports.** `windows-recorded`: in the order and at the times hosted Macs were recorded (`FakeWindowSystem.changeDisplaysAsAMacDoes`); time passes in it; no generator says it yet.
`arbor-sim sweep story` and the lid sweep play every order of reports in which no time passes.

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
| `where the hand left it` | on the big display where the hand left it, **or where it was found**, seen from that display, where macOS alone has it elsewhere: on purpose |

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
- In the untouched columns 36 / 36 / 49 places are not looked at: windows hanging over an edge, which Arbor moves at its start. (None since what is found counts as left: all 246 are played, with the tallies of the columns by hand, hidden 0 and out of reach 0.)
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
un-laid-out after a line, no line moves a window twice where once would have done, and after `quit-check` every window is in view. The audit asks of each damaged file: if it was refused, was it set aside byte for
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

**When it finds something** it prints what (`CRASH`, `HANG`, `UNHEALTHY`, `STALE LAYOUT`, `LOST AT QUIT`, `CUT SHORT`, `MOVED TWICE`, `FILE`; `REFUSED AND NOT KEPT`, `NOTED AND NOT KEPT`,
`SILENT LOSS`), the last line that ran (of `MOVED TWICE`: the line that did it), the damage, and the file, once for each distinct finding. To see it happen:

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

## What only real windows can show, and which script shows it

This was a list of a hundred things for somebody to try by hand. Nobody is asked to any more: what could only be checked at a desk counts as not
done. Everything below runs unattended on one of GitHub's Macs (one display of 1024×768, no trackpad, test windows and Apple's stock
apps, input posted by `pointer.swift` and `witness.swift`). A ✔ comes from a `check`; a picture or a film comes back in `mac-shell/` and is
judged afterwards by whoever started the run, who writes what was seen into the report. Only claims of the suite (section 10) count for
`make parity`: a feature whose row names no `suite/` file is tested, not verified.

| What | Claims and checks | Pictures and films to judge |
|---|---|---|
| Dragging: edges, beside, middle, previews, the hold, ⌘, reflow | `suite/10-edges` `12-dwell` `20-beside`; `check-F09.sh` | `check-F09.sh` 10-fade-in, 12-fade-out; `shots-F15.sh` 02 |
| Gaps, a window's own edges, handles, floating windows over them | `suite/30-seams` `60-tiles`; `arbor-e2e` | `shots-F15.sh` 04–07 |
| Every shortcut, peek, whose lead, tiling keys | `suite/40-keys` `41-tiling-keys` `42-peek` `43-whose-lead`; `check-F51.sh` `shots-F22.sh` | `check-F51.sh` 01–03 |
| Undo | `suite/32-undo`; `shots-F19.sh` | `shots-F19.sh` 01, 11 |
| ⌃⌥N, Go to…, the minimap | `suite/44-name` `46-goto` `46-goto-places` `46-goto-closes`; `check-F20.sh` `shots-finder.sh` `shots-minimap.sh` | all of their shots, light and dark; off screen: Finder- and MinimapDrawingTests |
| Pause, apps that keep their keys, layouts, macOS's own shortcuts | `suite/45-pause` `47-whose-keys`; `check-F41.sh` `check-F44.sh` | `shots-F10.sh` 25, 26 |
| Hold the view, hold still, what a share shows | `suite/48-hold`; `check-F58.sh` | `check-F58.sh` share-*, held-* |
| Minimize, hide, close, tabs, hangs, full screen, ⌘Tab | `suite/50-lifecycle` `55-apps` `95-focus` `97-fullscreen` | |
| Tiles, sizes, pin, summon | `suite/60-tiles` `62-sizes` `65-pin` `66-summon` | `shots-F15.sh` 03, `shots-F48.sh` |
| arborctl, URLs, the menu, settings.json, settings by command | `suite/70-cli` `75-menu` `80-settings` `82-settings-commands`; `check-F12.sh` | |
| What Arbor says on screen | `suite/77-says`; `shots-F43.sh` | `shots-F43.sh` tours and films; HeadsUpPictureTests |
| Rectangle, pinch, scroll, the Desktop guard, what reaches apps | `suite/85-pointer`; `input-taps.sh` | `input-taps.sh` 01–06 |
| Restart, crash, damaged files | `suite/90-restart` | |
| Accessibility taken away | `check-F63.sh`; `input-taps.sh` session 4 | `check-F63.sh` 00–05 |
| Motion | `shots-F02.sh` (the stage comes down, a click ends it, off by setting and by Reduce Motion) | every film of `shots-F02.sh` |
| How it looks: backdrop, blur, tint, ring | `suite/35-ring`; `shots-F15.sh` `shots-focus-ring.sh` | both, light and dark; `check-desktop.sh` mission-control |
| The settings window | `shots-F12.sh` | every pane, light and dark; SettingsWindowPictureTests |
| The menu bar item, the welcome window, the first launch, `doctor` | `shots-F10.sh` `first-five-minutes.sh` | `shots-F10.sh` 05–74; MenuBarDrawingTests |
| Two displays, Spaces | `check-displays.sh` `check-F56.sh` `check-F49.sh` `check-desktop.sh` | their panoramas |
| Signing, installing, login item, updates | `check-F13.sh` `check-F13-system.sh`; `suite/75-menu` | 03, 05, 06 |
| Real apps (13 stock apps × 28 steps; tabs, sheets, full screen) | `compat.sh` `compat-extras.sh`; `check-F54.sh` for `--open` | `matrix.md`, `extras.md`, `compat-pictures.sh`, `shots-F15-apps.sh` |

**Still owed**, each with the script that will judge it:
- The screen's left, right and top edges with macOS's tiling as a Mac comes, where Arbor stands aside: the suite switches the tiling off on a
  hosted Mac (`screen_edges_dock`). Claims of their own in `suite/10-edges`.
- Round a corner of the screen the preview glides; with Reduce Motion it neither fades nor glides; with `reflowWhileDragging`, back over the old
  slot the gap opens again: films and a step in `check-F09.sh`, with `drag_on`.
- While ⌃⌥Space is held, a careless click that slips ten points, and a click on another app's window: `suite/42-peek`.
- The Dock hidden and `relayout`: `suite/50-lifecycle`.
- `focus-display`, `move-to-display` and the menu bar item on the second display: `check-displays.sh`.
- Without the permission, Quit says how many windows would stay out of view: `check-F63.sh`. One of macOS's shortcuts unticked while Arbor
  runs: `check-F44.sh`.
- A ⇧-click on a Desktop icon, Finder's menu on the Desktop, the menu of the app in front; ⌃⌥⌘ and ⌃⌥⇧ + scroll, and keys let go in
  mid-stroke, once `witness.swift` can post them: `input-taps.sh`.
- A click during the motion lands in the window that is really there; a window with a dialog in the motion: `shots-F02.sh`.
- The open menu against `arborctl menu`, row by row; `doctor` with the menu bar hidden and in a full-screen Space; the welcome window
  reopened on its second page and called to another Space; Open at Login ticked on its second page: `shots-F10.sh`.
- With the camera and microphone sensors on, an idle Mac is no call, and macOS asks nothing on Arbor's account: `check-F58.sh`.
- Go to… and the line Arbor says things on over another app's full screen; Go to… a window on another Space while holding still:
  `shots-finder.sh`, `shots-F43.sh`.
- The fades of the backdrop and of tile and window; light to dark while Arbor runs: films in `shots-F15.sh`.
- A tab torn off a docked Terminal window: `compat-extras.sh`.
- ⇧⌘4 then Space over the focused window picks the window, not the ring: `shots-focus-ring.sh`.

**Struck out**, and why:
1. A real trackpad, a Magic Mouse, force click, fading scrollers: the Macs have no such hardware; the same events are posted with the fields
   a trackpad's carry.
2. A camera, a microphone, Zoom, Meet, Teams, Slack, a share watched on a second device: not to be had there. So
   `holdStillWhileCameraIsOn` and `holdStillWhileMicrophoneIsOn` are not done and stay off; the example title in `holdStillFor` is unverified.
   What any picker is told is measured by `share-probe`.
3. Electron apps, Emacs, design tools, Rectangle, editors by name: not stock apps, and Arbor does not know one app from another.
4. Logging out and in, switching users, locking the screen, display sleep: they end the session the script runs in.
5. A notch, a built-in Retina panel: hardware. Scale 2 is drawn off screen and on a virtual display.
6. Input methods: `keys.swift` selects layouts; nothing has composed text on a hosted Mac.
7. VoiceOver: speech cannot be judged; what it would read is the Accessibility tree, which `shots-F12.sh` writes out and drives.
8. Beeps: they take ears, and Arbor does not log them.
9. A click on a Dock item: no tool finds one.
10. macOS's keychain dialog: it asks for its owner's password.
11. Questions ("how old is the picture?", "are two seconds enough?") and known defects (About Arbor takes the keyboard): they belong on
    the board.
12. The Accessibility switch clicked by a hand: macOS asks for a password, so no script can. What a script can take away it does
    (`check-F63.sh`, `input-taps.sh`). The one recipe that is kept, for the record:

- **The switch, measured.** For whoever has a Mac and likes to try; nobody is asked to, and nothing waits for it. No script can click that switch: macOS asks for a password (`scripts/mac-shell/README-permission-probes.md`). So in which order the word, the flag and the
  right to tap go for a person, and whether a click is lost meanwhile, has never been seen. No `sudo`, nothing written to the permission database: only Arbor as installed, with `"pointerGestures": true` in its settings so that it has its taps, the switch, and one tool built from the checkout:
  `swiftc -O -swift-version 5 scripts/mac-shell/asker.swift -o /tmp/asker` (the terminal needs Accessibility, to post the key).
  In three terminals: `/tmp/asker hear 60 > /tmp/heard.txt`, `/tmp/asker arrivals 60 > /tmp/arrivals.txt`, and, with the Accessibility pane open and the password already given, `/tmp/asker stream 45 20 0 0 --kinds key > /tmp/stream.txt`. Switch Arbor off; click twice on the
  pane's empty part, a second apart; switch it on again.
  `heard.txt` says when `com.apple.accessibility.api` was posted; a number missing from `arrivals.txt` is an event that was dropped, and the clicks are its lines with `other=`; Arbor's log has "Accessibility permission is gone (…)" with who said no. The three files hold times, kinds of events, numbers and
  modifiers: no window title, no app's name, and no key but F19, which the tool itself posts (other keys pressed meanwhile appear as `key-down other=0`, without saying which). Delete the files and `/tmp/asker` afterwards; nothing else was changed. A result goes into `collab/reality.json`.

With macOS's own window tiling on, as a Mac comes, the left, right and top edges of the screen are macOS's (`MacTiling`). Stage Manager
rearranges windows on its own and cannot be used with Arbor. `arborctl doctor` lists the settings under System Settings → Desktop & Dock that
compete with Arbor as they stand ("Click wallpaper to reveal desktop", the two "Drag windows to…" switches, "Hold ⌥ key while dragging
windows to tile", Stage Manager) and what to do about each.
