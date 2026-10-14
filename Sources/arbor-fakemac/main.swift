import Foundation

// arbor-fakemac: a Mac made of fakes, for rehearsing Mac shell scripts (scripts/mac-shell) without a Mac.
//
// scripts/mac-shell/rehearse.sh runs such a script unchanged against stand-ins for Arbor, arborctl, the pointer
// tool, the test windows, `open`, `lsappinfo` and `sleep`. Every stand-in ends up here:
//
//   arbor-fakemac pointer drag 758 108 3 368 --no-release
//   arbor-fakemac arborctl dock 101 left
//   arbor-fakemac open arbor://show-all
//   arbor-fakemac lsappinfo front
//   arbor-fakemac sleep 4
//   arbor-fakemac app-start <pid> <bundle id> <name> --count 4 | app-request <pid> <line> | app-exit <pid>
//   arbor-fakemac arbor-start <pid> <bundled: 0 or 1> | arbor-term <pid> | arbor-watchdog <pid>
//   arbor-fakemac replay <world file>      for a person: every line of a world and what it answered
//
// There is no daemon. What has happened in a session so far is a text file, the world file, next to the
// session's ARBOR_HOME: one line per thing done, fields separated by tabs. The first line is the display
// (ARBOR_REHEARSAL_DISPLAY when the session began). An invocation that changes something takes a lock, replays
// the whole file from the start in this fresh process with its own line at the end, and appends that line; one
// that only asks replays the file and answers. Only the last line's output is printed. What a script has done
// since the line before to a file the world goes by (settings.json and state.json, which Arbor reads) follows
// the line as `note` lines that hold the new content, so that later replays see the same. See Driver.swift.
//
// What is real: `Controller` and everything under it (ArborCore, the layout, drops, the camera, rules, saved
// state, settings, key bindings, URLs, pausing, `RectangleGesture`, `GestureRouter`, `PointerSurface`,
// `RestartPolicy`) and the log lines they write. `FakeWindowSystem` decides what macOS does without being
// asked: where the keyboard goes, what is reported back, whole points, title bars that stay in reach.
// So are traces: the controller is wired through the recording decorators as in the app, and `arborctl trace on` leaves its file in
// ARBOR_HOME/traces, on the world's clock and without the `raw` lines, which only the real Accessibility layer writes.
//
// What is modelled (World*.swift), on `FakeWindowSystem` and `FakeOverlays`: one display, the test apps and
// their requests, which window is in front, who has the keyboard, what a press lands on (menu, tile, seam,
// window buttons, title bar, edges, content), title-bar drags and edge resizes that can be left held,
// shortcuts, pinches, the rectangle, the menu bar item's menu, the focus ring's panel, "click wallpaper to
// reveal desktop", a second copy of Arbor, quitting, signals, SIGKILL and the watchdog. A second passes after
// every line that changes something, so debounced work (saving, putting windows back) has always happened by
// the next line. The few decisions and log lines of ArborApp, StatusMenu, PointerInput, AXWindowSystem and
// arborctl that scripts can see are repeated here, each next to the name of what it repeats: when one of those
// changes, this has to follow.
//
// What it cannot say anything about: AppKit's and Accessibility's timing and order of notifications,
// animations, the finer points of which window is in front, macOS's own tiling, the Dock growing and shrinking,
// Spaces and full screen, what anything looks like, whether an event tap or a hot key really gets its events. A
// rehearsal proves the script, not Arbor.
//
// A command, request or option that is not modelled is refused with a message that names it and exit code 64.

MainActor.assumeIsolated {
  exit(Driver.run(Array(CommandLine.arguments.dropFirst())))
}
