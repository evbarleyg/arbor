# F24: Events for scripts and status bars

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (an earlier state was compiled and partly driven on a Mac once)
Depends on: F01; F40 for `paused` and `resumed`
From: IDEAS I5. F50 (a command line people enjoy scripting) builds on it.

## Summary

`arborctl` can ask Arbor how things are, but a status bar that shows the space in view would have to ask several
times a second. `arborctl watch` turns it round: the connection stays open and Arbor sends one line of JSON whenever the
view, the layout, the focused window, the windows, the displays or the settings change. TrellisWM has nothing like it.

The guide for script authors, with every field and ready-made recipes, is `docs/SCRIPTING.md`. This spec says what
must hold.

## Behaviour

- `watch [events…] [--titles]`, over the control socket. `arborctl watch` prints each line as it arrives.
- Events: `hello`, `displays`, `window`, `layout`, `view`, `focus`, `settings`, `started`, `quitting`, `paused`, `resumed`, `hold`. One JSON
  object per line, `event` first, the other keys sorted, fields with nothing to say left out, rectangles as
  `{"x", "y", "width", "height"}`. The names are the glossary's, not the code's.
- The first line is `hello`: Arbor's version, the protocol number (1), and the whole state in the events' own words.
- Events report differences in state, not actions. Changes made in one turn of the main loop are reported together,
  once; a relayout that changed nothing sends nothing.
- `view` says where a display's view is: in words (`label`, as replies say it), as a `kind` (`everything`, `desktop`, `window`, `group`), how deep
  (`depth`), what is in it (`windows`, `apps`), how many windows are out of view, whether `back` and `forward` would do anything, and the saved view and name that lead there.
- `window` is one line per window and change: `opened`, `closed`, `adopted`, `released`, `docked`, `floated`, `state`, `title`. Every window has a `state`:
  `in-view`, `out-of-view`, `tile`, `minimized`, `hidden`, `full-screen`, `other-space`.
- `settings` names the keys that changed.
- `hold` says how the view is held (F58): `level` is `view` or `still`, left out when it is released; `reason` says why Arbor holds still by itself. An event of its own, never a `change` of a window, so that `released` keeps one meaning. A hold that ends because Arbor pauses or stops is taken back before `paused`.
- Event names after `watch` are a filter. `hello`, `paused`, `resumed` and `quitting` are always sent.
- Window titles are sent only to a client that asked with `--titles`. They are never logged.
- `name` in `view` is the name a person gave the space (F20); `label` stays Arbor's own words for it. The name goes to every client (it was typed to be shown, and the socket is its owner's alone) and is never logged.
- `quitting` is the last line when Arbor quits, after the windows are back in view. Nothing else sends it.
- A pause (F40) is `paused`, and the connection stays; after `resumed` the whole state follows, as after `started`.
- At most 16 clients watch at once; the next is refused like a failed command.
- Arbor never waits for a client. Writes do not block; a client that is 256 KB behind is hung up on.
- `arborctl watch` exits with 0 after `quitting` (or when its own reader leaves), 1 when refused, 2 when Arbor is not
  running, 3 when the events end without `quitting`.
- Field names are a promise: fields may be added, never renamed or removed, unless `protocol` goes up. New values of `state`, `change` and `kind` may appear without that.

## Design notes

- `ArborCore/ArborEvent.swift`: the events and their payloads; `Summary`, everything events report at one moment; and
  `changes(from:to:)`, the events between two summaries. Dropping duplicates and coalescing are then not special
  cases but what a difference is. `Summary.withoutTitles` is what a client without `--titles` may learn; the events for such
  clients are worked out from summaries that never held a title.
- `ArborKit/Controller/EventFeed.swift`: observes the controller (`Controller.observe`), schedules one flush per burst
  (`scheduler.schedule("events", after: 0)`, so tests decide when the main loop comes round), takes a summary
  (`Controller+EventSummary.swift`) and sends the difference to each subscriber through its filter. With no
  subscriber a change costs one function call. The summary reads only what the controller knows. Who has the keyboard is the one
  thing the system is asked: once per client, for `hello`, and after a `Change.focus` or `Change.keyboard`, at the flush and once more
  0.25 s later (`events-focus`), because a report can arrive before the system's answer has changed, or come from an app in the background.
- `quitting` is not a difference between summaries: a controller that stops may be pausing. `EventFeed.stop()` sends it, and the app calls that when it quits.
- `Controller.Change.windows` is new: a window adopted as floating, a floating window changing display and a new title
  change no layout, so nothing announced them. So is `Change.keyboard`, sent from `keyboardFocusMoved()` (F37's).
- `hello.version` is `controller.buildInfo.version` (F13): "0.9.0", or "dev" outside a bundle.
- Transport: `ArborIPC/LineBuffer.swift` (bytes in, lines out) and `OutboundQueue.swift` (lines in, bytes to write,
  and the decision that a reader is too far behind) are pure. `ArborKit/IPC/ControlServer.swift` holds the sockets and dispatch
  sources: every connection is non-blocking from `accept` on, ordinary requests included. `ControlEndpoint.swift` is
  between lines and commands. `ArborIPC/UnixSocket.swift` is the one file that tells Darwin from Linux.
- All of it builds on Linux, so the server, the client and `arborctl` are tested there with real sockets.
  `arbor-sim --serve <path>` puts the simulator behind a real socket.

## Acceptance criteria

1. The first line is `hello`, with the version and the state; nothing else follows until something changes.
2. A move of the view sends one `view` event with the display, the node, its kind, its label in words, its depth, the docked
   windows in view and their apps, the number out of view, `canGoBack`, `canGoForward`, and the saved view's number if the node has one.
3. `layout` carries the display, the docked, floating and tile counts, and the frames in view; dragging a gap sends it.
4. `window` reports opened, closed, docked and floated with ids and bundle ids; a closed window still has its app. A window whose app is no longer
   arranged is `released`, not `closed`; one that was there before Arbor looked is `adopted`, not `opened`.
5. A window's `state` follows it out of view and back, into a tile, minimized, hidden, into macOS's full screen and onto another of macOS's Spaces.
6. A relayout, a `show-all` with everything in view or a `reload-settings` that changes nothing sends nothing.
7. Several commands in one turn of the main loop send one event of each kind, describing the end state; nothing is sent
   before the turn ends.
8. A filter lets through only the kinds named, plus `hello`, `paused`, `resumed` and `quitting`.
9. No line sent to a client without `--titles` holds a title; a client with it gets titles, and `"change":"title"`.
10. `focus` follows the keyboard: not a report from an app in the background, but a switch of apps that no window reports, and a click on the wallpaper.
11. A client connected before Arbor starts hears `started` and then the state.
12. `quitting` is sent by `stop()`, once, whatever the filter, also if Arbor never started or is paused; a controller that merely stops sends nothing.
    A pause sends `paused` at once; resuming sends `resumed` and the state; `arborctl watch` stays connected through both.
13. `settings` is sent only when a key changed, and names the keys.
14. The 17th watcher is refused; a place given up can be taken.
15. A watcher that stops reading is dropped once 256 KB are queued, and the server never blocks; the others are not
    disturbed. A watcher that leaves is noticed without anything being sent.
16. A client that sends nothing, or does not collect its reply, is hung up on without holding anyone up. No client can
    kill Arbor with SIGPIPE.
17. `arborctl watch` writes each line out at once, into a pipe too, and exits with 0, 1, 2 or 3 as above. For other commands, answers go
    to standard output and refusals to standard error.
18. Every sample line in `docs/SCRIPTING.md` is exactly what Arbor would send.
19. `make check` passes on macOS and Linux.

## Shipped

- Everything above. Tests: `ArborCoreTests/ArborEventTests.swift` (lines, round trips, differences, changed settings, the command),
  `ArborIPCTests/FramingTests.swift` (framing and queueing), `ArborKitTests/EventFeedTests.swift` (the real controller and
  feed), `ArborKitTests/ControlSocketTests.swift` (the real server, client and `arborctl`'s logic over real sockets),
  `scripts/watch-smoke.sh` (the `arborctl` binary against `arbor-sim --serve`: flushing, exit codes, a pause, clients that misbehave; part
  of `make check`), three steps in `arbor-e2e`, and `scripts/mac-shell/watch.sh` for the real app.
- Beyond the brief: `displays` events; `frames` in `layout`, so that a script that draws something around windows needs no second
  request; `arborctl watch | head -n 1` ends at once instead of at the next event; `watch` in arbor-sim.
- From the product owner's round, before the names froze: `view`, `everything`, `savedView`, `label`, `depth`, `outOfView`, `state`, `adopted`, `released`,
  `settings.changed`, `paused` and `resumed` always sent, the last line only from quitting. From its second: the event is `window` (it carries one), the state `minimized` (as `state` and Accessibility spell it), a display's UUID is `displayID` (`display` is its number in F50's queries and in commands), and `full-screen` is told from `other-space`. From its third: counts are called counts (`dockedCount`, `floatingCount`, `tileCount`), a new title is `"change":"title"`, `hello` carries a `snapshot` (`state` is a word in `window`), and the last line is `quitting`, which leaves `stopped` free for the day Arbor stops arranging without quitting or pausing (F63).
- The control socket's old faults went with the rewrite: a silent client held the main thread for two seconds, and a client
  that left before reading its reply killed Arbor with SIGPIPE.

## Not shipped

- Floating windows' frames are not reported; `arborctl state` has them.
- `state` still writes rectangles as pairs and says `camera` and `minimized`; F50 plans its schema 2.
