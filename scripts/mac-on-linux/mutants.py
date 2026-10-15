#!/usr/bin/env python3
"""Changes to a copy of Arbor's Accessibility layer that take a known cure out again (README.md next to this file, "Does the net hold?").

    mutants.py --list                      one line each: the name, a tab, and the checks ("story: check") that must go red, with tabs between them
    mutants.py --apply <name> <sources>    makes the change in the copy under <sources>. Exit code 1 if the text to change is not there exactly once

A story that stays green without the cure it is about proves nothing. `make mac-on-linux-selftest` makes each change, builds, and expects red.
When the layer is rewritten and a change no longer fits, that is reported: write the change anew, or delete it together with its story.
A change never adds or removes a line.
"""
import sys

LAYER = "ArborKit/AX/AXWindowSystem.swift"

MUTANTS = [
    {
        # The fault of 2026-10-14 on hosted Macs: every window opened in a running app was filed as "seen for the first time and did not just open".
        "name": "whoever sees a window first goes by what its app has said so far",
        "old": "    let hasOpenedSince = counted.insert(id).inserted\n",
        "new": "    let hasOpenedSince = false\n",
        "red": [
            "a window opens in a running app that reports the focus before the creation: it is not announced as one that was open all along",
            "with automatic docking, a window opens in a running app that reports the focus before the creation: it is docked beside the other",
            "the rude walk (polite): a window that has just opened is announced as new",
        ],
    },
    {
        # The other fault of that day, cured by 5726225: the notice that an app came forward outran `frontmostApplication`, and the report was dropped.
        "name": "an app that macOS does not name in front yet is dropped",
        "old": "    reportFocus(ofAppThatCameForward: pid, earlierLooks: 0)\n",
        "new": "    reportFocus(of: pid)\n",
        "red": [
            "⌘Tab to another app, and NSWorkspace names the old app for 5 ms more: the window that has the keyboard now is reported focused",
            "a click on another window of another app, and NSWorkspace names the old app for 20 ms more: the window that was clicked is reported focused",
            "⌘Tab to an app whose window is out of view, and NSWorkspace names the old app for 50 ms more: the view moves to show the window that has the keyboard now",
            "the rude walk (stale answers): a window whose app came forward while NSWorkspace still named another is reported focused",
        ],
    },
    {
        "name": "an app that has been overtaken is still looked at",
        "old": "    // Whoever came forward before has been overtaken.\n    lookAtAppThatCameForward?.cancel()\n",
        "new": "    // Whoever came forward before has been overtaken.\n    _ = 0\n",
        "red": ["⌘Tab to another app and back 30 ms later, and NSWorkspace lags by 50 ms: the last window to be reported focused is the one that has the keyboard"],
    },
    {
        "name": "a window that was put away still counts as there",
        "old": "    putAway.insert(window)\n",
        "new": "    _ = window\n",
        "red": [
            "an app closes its one window and opens it again under the same number, after a trip to another Space, the focus reported first: "
            "opened again, it is announced as a window that has just opened",
        ],
    },
    {
        "name": "nobody checks that the button is still down",
        "old": "        timesUp = self.isMouseButtonDown() ? 0 : timesUp + 1\n",
        "new": "        timesUp = 0\n",
        "red": [
            "a window is dragged and the release is never heard: then it is called off: nobody knows where the window was meant to go",
            "a window is resized by an edge and the release is never heard: the resize is finished all the same: the frame says how it ended",
            "a floating window is dragged to the edge and the release is never heard: the preview does not stay on screen for ever",
            "the rude walk (twice or never): no drag or resize is left open with the button up",
        ],
    },
    {
        # Cured by a3c0281, after three of four long drags on a hosted Mac were never taken for drags.
        "name": "a pointer that has gone far over a window that stands still settles the press",
        "old": "    case .undecided, .neither:\n      break\n    case .drag:\n      draggingWindow = window\n",
        "new": "    case .undecided, .neither:\n      if verdict == .neither { press?.isSettled = true }\n    case .drag:\n      draggingWindow = window\n",
        "red": [
            "the window server begins to move a dragged window 100 ms after the press, with the pointer 40 points away: the drag is reported to begin",
            "a window is dragged in 30 steps of 66 points, the window server 50 ms late to start: the drag is reported to begin",
            "with macOS's tiling off, a floating window is dragged briskly to the left edge of the screen, and the window server begins to move it 100 ms after the press, with the pointer 40 points away: let go, it is docked",
        ],
    },
    {
        # 531885f: with macOS's tiling on, the left, right and top edges of the screen are macOS's.
        "name": "Arbor offers its band along the edges that are macOS's",
        "file": "ArborKit/Controller/Controller+Drag.swift",
        "old": "    dropOptions.silentEdges = (drag?.macTiling.edges ?? []).union(drag?.edgesNeverLeft ?? [])\n",
        "new": "    dropOptions.silentEdges = (drag?.edgesNeverLeft ?? [])\n",
        "red": [
            "with macOS's tiling on, a floating window is dragged to the left edge of the screen: Arbor stands aside: no preview",
            "with macOS's tiling on, a floating window is dragged to the right edge of the screen: let go, it is not docked",
            "with macOS's tiling on, a docked window is dragged to the right edge of the screen: Arbor stands aside: no preview",
        ],
    },
    {
        "name": "a second press does not end what the first began",
        "old": "      releaseWasLost()\n      press = makePress(at: cursorLocation())\n",
        "new": "      _ = 0\n      press = makePress(at: cursorLocation())\n",
        "red": ["a window is dragged, the release is never heard, and the button goes down again at once: a button cannot go down twice: the drag is called off"],
    },
    {
        "name": "a call that fails at once says nothing about the process",
        "old": "      if kill(pid, 0) != 0, errno == ESRCH {\n",
        "new": "      if false {\n",
        "red": ["an app ends and nothing says so: and reports the window gone"],
    },
    {
        "name": "the lists are read once after a Space switch",
        "old": "    rescan(Array(apps.keys), afterSpaceSwitch: true)\n    rescanSoon()\n",
        "new": "    rescan(Array(apps.keys), afterSpaceSwitch: true)\n    _ = 0\n",
        "red": [
            "the Space is switched, and in the transition apps list no windows at all: back again, the first windows show",
            "a trip to another Space and back, and in the transitions apps list no windows at all: and Arbor goes on arranging them: one is framed, the other goes out of view",
        ],
    },
    {
        "name": "what comes right after a move is its echo, whatever it says",
        "old": "    if verdict == .early { lookAgain(at: window) }\n",
        "new": "    _ = verdict\n",
        "red": ["a window goes back to its old frame 0.05 s after every move: and has been told that this was not its own doing"],
    },
    {
        "name": "at the end of a drag the app is believed",
        "old": "      if let bounds = Self.serverBounds(of: window), var record = records[window] {\n",
        "new": "      if let bounds = records[window]?.snapshot.frame, var record = records[window] {\n",
        "red": ["a window is flicked and let go at once: Arbor goes by the window server"],
    },
    {
        "name": "a drag is known only by what the app reports",
        "old": "        lookAtPressedWindow()\n",
        "new": "        _ = 0\n",
        "red": [
            "a window is dragged by its title bar, and its app says nothing until it is over: the drag is reported to begin, once",
            "a window of an app that hangs is dragged: the window server moves it all the same, and the drag is reported",
        ],
    },
    {
        "name": "an app that let a call time out is asked again and again",
        "old": "  private func answers(_ pid: pid_t) -> Bool { !unresponsive.contains(pid) }\n",
        "new": "  private func answers(_ pid: pid_t) -> Bool { true }\n",
        "red": [
            "an app hangs: from then on nothing is asked of the app, and nothing waits for it",
            "three docked windows of an app that hangs: within three seconds",
        ],
    },
    {
        "name": "the timeout is left at the system's six seconds",
        "old": "  private static let messagingTimeout: Float = 1\n",
        "new": "  private static let messagingTimeout: Float = 0\n",
        "red": ["an app hangs: after waiting for one call, a second, and not for six"],
    },
    {
        "name": "a window that leaves the list has left, tab or no tab",
        "old": "      if !afterSpaceSwitch, let successor = tabInFront(insteadOf: record, among: listed) {\n",
        "new": "      if false, let successor = tabInFront(insteadOf: record, among: listed) {\n",
        "red": [
            "native tabs: a new tab takes the place of the window it was opened in",
            "a docked window gets a new tab: the tab is docked in its place",
            "the rude walk (polite): a tab is not announced as a window of its own",
        ],
    },
    {
        "name": "a shortened plan is never followed by the full one",
        "old": "    if let taken = result, let more = FramePlan.makingUp(for: steps, result: taken, target: frame) {\n",
        "new": "    if let taken = result, false, let more = FramePlan.makingUp(for: steps, result: taken, target: frame) {\n",
        "red": ["the frame Arbor believes a window has is out of date: a move that was thought to need no resize gets one"],
    },
    {
        "name": "what claims to be a dialog is one",
        "old": "    let mayBeOutOfSight = subrole == kAXDialogSubrole\n",
        "new": "    let mayBeOutOfSight = false\n",
        "red": ["windows are minimized and hidden when Arbor starts: the minimized window is known, as minimized"],
    },
    {
        "name": "a new element gets one look",
        "old": "      if attempt < Self.lastAttempt {\n",
        "new": "      if attempt < 0 {\n",
        "red": ["a new window gets its subrole 0.3 s after it is created: a moment later it is announced, once, as one that has just opened"],
    },
    {
        "name": "full screen is read only with a resize",
        "old": "      if (record.element.bool(\"AXFullScreen\") ?? record.snapshot.isFullScreen) != record.snapshot.isFullScreen {\n",
        "new": "      if false, (record.element.bool(\"AXFullScreen\") ?? record.snapshot.isFullScreen) != record.snapshot.isFullScreen {\n",
        "red": ["a window enters full screen, which it says only after the last report of its size: Arbor knows that it is in full screen"],
    },
    {
        "name": "an app in the background may report its focus",
        "old": "    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }\n    guard let app = apps[pid], answers(pid), let element",
        "new": "    _ = 0\n    guard let app = apps[pid], answers(pid), let element",
        "red": ["an app in the background changes its focused window: nothing is said about the keyboard, which is where it was"],
    },
    {
        "name": "the modifier keys are read when the event is handled",
        "old": "    let flags = eventModifiers ?? NSEvent.modifierFlags\n",
        "new": "    let flags = NSEvent.modifierFlags\n",
        "red": ["⌘ is held to the end of a drag and let go together with the button: when the end of the drag is reported, ⌘ counts as held"],
    },
    {
        "name": "every notice about the screens is passed on",
        "old": "    guard let delay = DisplayChange.settleTime(from: reportedDisplays, to: displays()) else { return }\n",
        "new": "    guard let delay = Optional(0.0) else { return }\n",
        "red": ["a second display is plugged in and unplugged: for a moment nothing is said: displays blink"],
    },
]


def main():
    if sys.argv[1:] == ["--list"]:
        for mutant in MUTANTS:
            print("\t".join([mutant["name"]] + mutant["red"]))
        return 0
    if len(sys.argv) == 4 and sys.argv[1] == "--apply":
        mutant = next((m for m in MUTANTS if m["name"] == sys.argv[2]), None)
        if mutant is None:
            print(f"no such change: {sys.argv[2]}")
            return 1
        path = f"{sys.argv[3]}/{mutant.get('file', LAYER)}"
        text = open(path, encoding="utf-8").read()
        # The copy has been rewritten by prepare.py and retime.py, line for line.
        old = mutant["old"].replace("kill(pid, 0)", "FakeMac.kill(pid, 0)")
        if text.count(old) != 1 or old.count("\n") != mutant["new"].count("\n"):
            return 1
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text.replace(old, mutant["new"]))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
