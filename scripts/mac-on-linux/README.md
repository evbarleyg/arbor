# The real Accessibility layer, run on Linux

Thousands of headless tests run the controller against stand-ins for the protocol `WindowSystem`. The real implementation, `Sources/ArborKit/AX`, ran in none of them, and that is where two of the
three faults lay that the first day on hosted Macs showed: an app reported "the focus is on it" a millisecond before "it was created"; and `didActivateApplication` arrived while
`NSWorkspace.shared.frontmostApplication` still named the old app. No stand-in at the seam can catch that class. This folder compiles the layer **as it is**, links it with a model of a Mac, and runs it.

```bash
make mac-on-linux                                   # build what has changed, tell every story, walk a short walk. 5 s to run; see "How long"
make mac-on-linux ARGS="--only tab --verbose"       # the stories whose names contain "tab", with everything that happened on the Mac
make mac-on-linux ARGS="--only walk --seeds 1-500"  # a hunt
make mac-on-linux ARGS="--help"
make mac-on-linux-selftest                          # does the net hold? takes known cures out of the copy; the stories about them must go red. 2½ minutes
REF=origin/fix/some-cure make mac-on-linux          # that commit's Sources, with this checkout's stand-ins, scripts and stories
COVERAGE=1 make mac-on-linux                        # afterwards: how much of each file of the layer was entered, and which lines were not
```

On Linux only (in the container CI uses: `make linux` has the image). It works in `.build/mac-on-linux`, so nothing in the checkout changes.

## What runs

| | |
|---|---|
| Unchanged | `Sources/ArborKit/AX` (all of it), `Controller`, `Platform`, `Support`, `Trace`, `App/FrontmostAppWatcher.swift`, `App/ArborEnvironment.swift`; `ArborCore`, `ArborIPC`, `ArborTesting` |
| Rewritten in a copy, line for line | What `scripts/typecheck-mac/prepare.py` does for any Linux compiler (`@objc`, `#if os(macOS)`…), and three things by `retime.py`: `Task.sleep` → `FakeMac.sleep`, `ProcessInfo.processInfo.systemUptime` → `FakeMac.uptime`, `kill(` → `FakeMac.kill(` |
| In place of Apple's frameworks | The stand-ins of `scripts/typecheck-mac/stubs`. The functions the layer calls have bodies that ask the model, `stubs/FakeMacOS`; the rest still does nothing |
| Left out | `UI`, `Input`, the rest of `App`: their stand-ins do nothing, so running them would show nothing |

**Storey one** (`tests/StoreyOne.swift`): `AXWindowSystem` alone, with a listener that writes down the `WindowSystemEvents` it emits. **Storey two** (`tests/StoreyTwo.swift`): the real `Controller` on it, wired as `ArborApp` wires them, with the
app's own `MainQueueScheduler` and `FrontmostAppWatcher`; only what draws (`FakeOverlays`) and what writes to disk (`MemoryStateStore`) are fakes. Its checks look at the Mac's screen: where the windows are.

**Time** is the model's. A story says `mac.pass(0.3)` and whatever falls due is delivered in order, with no real waiting. A call to an app that hangs moves the clock by the whole messaging timeout, and what fell due meanwhile is
delivered afterwards, as to a busy main thread. After each delivery Arbor's tasks run until none is runnable (`stubs/FakeMacOS/Pump.swift`): jobs for the main actor are taken from libdispatch's main queue the way CoreFoundation's run loop takes them; jobs for the
global pool (`Task.detached`) are caught by the runtime's hook and run on the same thread, marked as being off the main one. Everything is a function of the story: no thread, no clock, no chance. The program checks at its start that the pump
works with this toolchain and refuses to go on if not. `retime.py` fails the build if the layer waits or tells the time in a way it does not know (`asyncAfter`, `Timer`, `Date()`…): such code would stand still while the model's time passes.

## What is modelled, and on what evidence

`stubs/FakeMacOS`, 1,850 lines. Every delay and every order of reports there says where it was seen; **"Guess" marks what nobody has measured** (`grep -n -i guess scripts/typecheck-mac/stubs/FakeMacOS`).

| | Seen (trace in `collab/evidence/traces`, or the place it is written down) | Guess |
|---|---|---|
| Opening | "focused" a millisecond before "created" in a running app; subrole a moment late; tooltips and helpers reported created; apps refuse observers while launching; one-window apps show the same number again | What the subrole is before it comes; that a refusal is `cannotComplete`, at once |
| Closing, quitting | focus of the next window 12 ms before "destroyed" (`close`); no "destroyed" at a quit (`app-quits`); an end nobody reports, calls then fail at once; a window that closes without a notice | What a closed window answers to a *set* |
| Coming forward | `didActivate`, "deactivated" 0.6 ms later, "activated" 8 ms later, nothing more; `frontmostApplication` still naming the old app | 4 ms from the switch to the notice; **how long the property lags** (a knob; stories play 5 to 600 ms) |
| Minimize, hide | 0.55 s; the screens' notice 15 to 20 ms later and 2 points of visible frame; focus 1 to 4 ms before "deminiaturized"; AXDialog for every minimized or hidden window; unhiding brings windows back (`minimize-restore`, `hide-unhide`) | Which windows count as nearly off screen |
| Spaces, full screen | The notice in mid-transition, apps listing neither old nor new windows; two AXUnknown helpers; "resized" before `AXFullScreen` says yes | The lengths; **in which order the focus report and the notice come** (both are played) |
| Native tabs | Only the front tab is listed; a new tab is a new window; choosing posts only "main window changed"; successor first; Terminal's 31 points | |
| Frames | Whole points, which way halves go; the title bar stays above the Dock; minimum sizes; size, position, size; echoes 2 to 15 ms later; windows that go back (`*-commands`, `stubborn-*`) | How "enhanced user interface" animates |
| Hanging | Every call waits the timeout; a timeout belongs to one element object, the system-wide one's to the process; 0 means six seconds; calls that timed out are carried out on waking | That `_AXUIElementGetWindow` waits like any call |
| The mouse | The window server moves a dragged window at once, the app hears 0.1 s later, eight to ten "moved" a second or none; mouse-up twice; monitors deaf to Arbor's own panels; releases that are swallowed (`drag-to-edge`, `flick-to-edge`, `click-title-bar`) | 1 ms to a monitor; that a loaded window server starts late and catches up in one jump |
| The window server | What a Mac at rest lists, at which levels, not sorted by level; `kCGWindowIsOnscreen` only for what shows; no list at all | |

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

`known-failures.txt` lists the checks that are red on the trunk, each with a word on it. **The run fails when a check that is not listed fails, and when one that is listed passes**, so whoever lands a cure deletes its lines in the same pull request; and when a line matches no check any more. `sometimes: ` marks what
only some seeds of the walk show.

## Does the net hold? (`make mac-on-linux-selftest`)

A story that stays green without the cure it is about proves nothing. `mutants.py` has nineteen small changes to the copy, each of which takes one cure out of the layer again (the count of windows that tells a new one from a found one, the watch for a lost release, the second reading of the lists after a Space switch, the
look at the window server during a drag…), and names the checks that must go red. Only the changed file is compiled again: eight seconds each. A change that no longer fits the sources is reported: write it anew, or delete it with its story.

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
that is open; nothing is reported about a stranger; the last word on the keyboard is right, and whoever got the keyboard was reported focused; no drag or resize is left open with the button up; the main thread waits at most two seconds for one hang. Each kind of manners is a story and each rule a check: it holds if no
seed breaks it. A breach prints how many seeds show it and the shortest script that deleting steps gives:

```
✘ a window whose app hung as it came forward is reported focused once the app wakes  (8 of 150 seeds; first seed 3: w103 has it; the last to be reported focused is w101
    --replay 'polite|3|arborFocuses 96 4; hang 85 52; dies 24 10')
```

`make mac-on-linux ARGS="--replay 'polite|3|…'"` plays that script with everything that happened. **A fault that is known gets a rule of its own wherever the model can tell it apart** (it knows when a notice outran the property, when "destroyed" was dropped, when an app hung in front), so that it hides nothing else. After a
breach that leaves the layer's picture of the Mac wrong, the walk ends: what breaks next may follow from it.

### What the walk has found

On 2026-10-15, besides the two faults it was built to reproduce: an app that is busy as it is switched to is never reported focused, on a polite Mac; "whoever posts a notification is awake" costs a second for each notification that was on its way; native tabs go wrong in two ways if the app's list is 10 ms behind. Each has stories of its own
now, and lines in `known-failures.txt` that say which lines of the layer are concerned. Duplicates, a second mouse-up, dropped "moved", swallowed releases and late calls found nothing in 400 seeds.

## How long

| | |
|---|---|
| Nothing changed | 4 s to find that out, 5 s to run |
| A story, or a file of the layer | 10 to 15 s |
| A stand-in or the model (everything is compiled again) | 45 to 80 s on four cores |
| From nothing | 2 minutes |
| The self-test | 2½ minutes |
| 400 seeds of the walk | 1 minute |

The stand-ins are compiled whole, with a stamp as in `check.sh`. Arbor's modules and the stories are compiled incrementally, as `swift build` does it: the copy is brought up to date file by file, touching only those whose text differs.

## When it breaks

- **"goes by the machine's clock"**: the layer waits in a new way. Teach `retime.py`.
- **An undefined symbol at the link, or a call that always fails**: the layer calls something of Apple's whose stand-in still does nothing. Give it a body that asks the model, and keep the declaration as it is: `make typecheck-mac` and `make typecheck-mac-selftest` use the same files.
- **"the pump does not work with this toolchain"**: the runtime queues jobs some other way than through `swift_task_enqueueGlobal_hook` and libdispatch's main queue. `Pump.swift` is 70 lines.
- **A new member of `WindowSystemEvents`**: `Listener` in `tests/StoreyOne.swift`, `Probe` in `tests/Dragging.swift`.
