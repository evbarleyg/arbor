# The permission probes: what each does and how to read it

Five Mac shell scripts and one helper, written on 2026-10-15 to answer one question with numbers: what happens to the Mac's input when Arbor loses the
Accessibility permission while its event taps are installed. They run on GitHub's hosted Macs only (`needs_throwaway_mac`): they write to the permission database.

```bash
MAC_SHELL_TAG=loss    scripts/mac-shell/run.sh --no-preflight "<why>" scripts/mac-shell/probe-permission-loss.sh     # 13 min
MAC_SHELL_TAG=traffic scripts/mac-shell/run.sh --no-preflight "<why>" scripts/mac-shell/probe-loss-under-traffic.sh  #  9 min
MAC_SHELL_TAG=grant   scripts/mac-shell/run.sh --no-preflight "<why>" scripts/mac-shell/probe-permission-grant.sh    #  5 min
MAC_SHELL_TAG=cost    scripts/mac-shell/run.sh --no-preflight "<why>" scripts/mac-shell/probe-what-the-taps-cost.sh  # 15 min, most of it the release build
```

None can be rehearsed: they stop at `swiftc` on Linux (the helper needs AppKit), and the fake Mac has no TCC and no `codesign`. What Linux can check: `bash -n`,
`scripts/lint-mac-shell.py`, `make typecheck-mac` (it reads `asker.swift` too, and has caught real compile errors in it), and the arithmetic, which is plain Python inside
each script: cut it out with `sed` and feed it a list from an earlier run, or a made-up one with a stall and losses in it, which must come out red.

## The pieces

| File | What it does |
|---|---|
| `asker.swift` | `stream`: posts a click, the key F19 and a wheel notch (or a small pinch) every 50 ms **by the clock**, each event with a number of its own in `eventSourceUserData`; `--ctrl-opt <from> <until>` holds ⌃⌥ meanwhile. `arrivals`: a listen-only tap at the tail of the session's taps that prints time, kind, number, lateness, modifiers. `ask`: writes `AXIsProcessTrusted()`, "can I make an active tap", "can I make a listening tap" twice a second. `announce` / `hear`: posts / prints the distributed notification `com.apple.accessibility.api`. `tap`: a bare tapper, one active tap that is never let go of. `now`: the time as all of these and `arbor.log` write it |
| `probe-permission-loss.sh` | The loss with traffic through the mouse-down tap (always on). Roads × variants, see below |
| `probe-loss-under-traffic.sh` | The loss with the taps that are on only at times: round a the scroll tap (⌃⌥ held), b the gesture tap (pinches), c the drag tap (the loss in mid ⌃⌥-drag: "nothing stuck") |
| `probe-permission-grant.sh` | What wakes the flag in a process that is already running, both ways; then Arbor itself through a first minute |
| `probe-what-the-taps-cost.sh` | The same stream in turns with no Arbor, Arbor without taps, Arbor with taps, on a release build |

**Arbor is a bundle of its own identity** in all but the last: the built binary wrapped in `~/Applications/ArborProbe….app`, ad-hoc signed under `com.evbarleyg.arbor.probe-…`, opened with `open -n`.
So it answers for its own permission, and the script's tools (children of the runner's shell) keep theirs. The grant is a row in TCC.db with the bundle's designated requirement (for an ad-hoc signature: its cdhash), written **before** launch.

## The roads the permission goes by

| Road | The deed | When a running process feels it |
|---|---|---|
| `by_tccutil` / `tccutil` | `tccutil reset Accessibility <bundle id>` | at once |
| `by_the_row_and_a_word` / `word` | the row deleted, the notification posted | within a second |
| `by_the_row` / `row` | the row deleted, tccd killed, nothing said | 4 to 16 s later, or not within 30 s |
| `by_the_row_announced` / `announced` | the same, and the notification | 2 to 6 s later |

The switch in System Settings is the road a person takes; `probe-the-switch.sh` tries whether a script can take it.

## Which lines of arbor.log the scripts go by

- **"noticed" and "taps gone"** are one moment: the first of `Accessibility permission is gone (…): removed the pinch and rectangle event taps` (`PointerInput.checkPermission`, a one-second timer on the main run loop) and
  `ERROR Accessibility permission was taken away with N window(s) out of view` (the controller). Either can come first. What stands in brackets says who said no: `AXIsProcessTrusted says no`, or `AXIsProcessTrusted says yes, but macOS refused a tap`.
- `stopped; no window was moved` follows within milliseconds. That the taps are really gone is asked of the window server's list (`witness taps`).
- A tap that macOS told "disabled": `the … event tap was off`, `switched it back on`, `too slow`, `of user input`. The scripts count these lines in each round.
- `pinch began` (debug) proves that the gesture tap had traffic.

## How to read a round

```
before the loss: 405 arrived of 405 posted, longest hole 118 ms, worst lateness 10.6 ms, more than 10 ms late: 2
FROM THE ROW'S DELETION UNTIL ARBOR NOTICED: 1505 arrived of 1600 posted, longest hole 997 ms, …
after the taps were gone: 1395 arrived of 1395 posted, longest hole 122 ms, …
  a hole of 997 ms from 01:37:08.956 (n=1910) to 01:37:09.953 (n=2006): 95 events lost in it
```

- Three stretches, cut at the deed and at "noticed". What is lost at a seam is charged to the stretch it ends.
- **Two kinds of hole.** Numbers **missing**: the events were posted and dropped, which is what the taps of a process without the permission do. Numbers **unbroken**, and the next event hardly late: nothing was
  posted, because `CGEventPost` blocked the poster. That happens with nobody running at all, seconds after tccd was killed, and is no fault of Arbor's.
- A plain beat shows as a hole of 50 to 130 ms on a hosted Mac. With nothing taken from anybody, events have been 85 ms late there. So lateness and holes are compared with the same Mac's stretch before the loss; "nothing lost" and "nothing stuck" are absolute.
- `INVALID` means the round proves nothing (could not post, nothing arrived before the loss, the tap in question was not on, Arbor began without the permission) and is a ✘. `FINDING` means Arbor never noticed within the stream.
- The variants: `arbor`, `arbor-without-taps` (ARBOR_NO_HOTKEYS=1), `nobody`, `bare-tapper`. The last is the floor: what macOS does to any tapper that does nothing.
- `sampled` rounds have `sample` looking at Arbor from the deed on (`sample-<n>.txt`); it halts Arbor at every look, so their figures do not count.

## What was found by 02:00 UTC on 2026-10-15 (macOS 26.6.2, debug build)

From the moment macOS withdraws the right until Arbor removes its taps, every event of every kind is dropped: 5 to 95 of them, 85 to 1046 ms, in nine rounds of ten with taps; none in four rounds with nobody and none with an Arbor without taps.
The length is the wait for the next tick of the one-second check. Before and after, nothing is lost. After a loss in mid ⌃⌥-drag nothing was stuck (one valid round).
The flag `AXIsProcessTrusted()` is remembered inside a process until `com.apple.accessibility.api` is posted; a write to TCC.db and a restart of tccd announce nothing.

## Traps, each of which cost a run

- **The bundle must not lie under /tmp.** `tccutil` finds it by its identifier in Launch Services' list and says "No such bundle identifier" (-10814) of one that does, registered or not.
- **`tccutil` without `sudo`.** Launch Services' list is kept per user.
- **`run.sh` cuts a script's name to 16 characters for the tag**, and a second dispatch under the same tag cancels the first: `probe-permission-loss` and `probe-permission-grant` are one tag. Set `MAC_SHELL_TAG`.
- **A job checks out the branch's head when it starts**, not when it was dispatched: a push while it waits changes what it runs.
- **A listener must end with its stream**, or be cut to it: one that lives on overhears the next stream, whose numbers begin at 1 again.
- **Two writers of one file must both append** (`>>`): the marks of round c were written over by the listener.
- **Keep the beat by the clock.** A pause after each beat adds the time posting takes, on a hosted Mac as long again.
- **After killing tccd wait six seconds** before anything is measured; and a process started while it restarts may be told "no" once.
- **"noticed" has two possible first lines**, see above.
- **`sudo tccutil reset Accessibility` without an identifier takes the permission from the script's own tools**, and from every script after it on that Mac (`input-taps.sh` ends so).
