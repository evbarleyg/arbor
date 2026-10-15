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
        "old": "      releaseWasLost()\n      // Whoever clicks says where the keyboard goes.\n",
        "new": "      _ = 0\n      // Whoever clicks says where the keyboard goes.\n",
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
        # What comes within the blanket time is not even read any more; the look afterwards is what finds the app's own answer out.
        "old": "      lookAgain(at: window)\n      // Whoever listens hears of it as ever, with the frame that is in the books.\n",
        "new": "      _ = 0\n      // Whoever listens hears of it as ever, with the frame that is in the books.\n",
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
        "old": "  private func answers(_ pid: pid_t) -> Bool { !unresponsive.contains(pid) && !lanes.isBusy(pid) }\n",
        "new": "  private func answers(_ pid: pid_t) -> Bool { true }\n",
        "red": [
            "an app hangs: from then on nothing is asked of the app, and nothing waits for it",
        ],
    },
    {
        "name": "the timeout is left at the system's six seconds",
        # A move is waited for on a lane, and by the main thread for its patience only. What is asked on the main thread still waits the timeout out.
        "file": "ArborKit/AX/AXCalls.swift",
        "old": "  static let timeout: Float = 1\n",
        "new": "  static let timeout: Float = 0\n",
        "red": ["⌘Tab three times to an app that hangs: Arbor's main thread has waited a second for it once, not each time"],
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
        "file": "ArborKit/AX/AXMover.swift",
        "old": "    if let result = reading.frame, let more = FramePlan.makingUp(for: steps, result: result, target: move.target) {\n",
        "new": "    if let result = reading.frame, false, let more = FramePlan.makingUp(for: steps, result: result, target: move.target) {\n",
        "red": ["the frame Arbor believes a window has is out of date: a move that was thought to need no resize gets one"],
    },
    {
        "name": "every frame is taken to lie on a display",
        "old": "      FramePlan.room(onDisplay: ScreenGeometry.global(fromAppKit: $0.frame), visible: ScreenGeometry.global(fromAppKit: $0.visibleFrame))\n",
        "new": "      FramePlan.room(onDisplay: ScreenGeometry.global(fromAppKit: $0.frame), visible: ScreenGeometry.global(fromAppKit: $0.frame).insetBy(dx: -9000, dy: -9000))\n",
        "red": ["an app hangs in the middle of a move into a frame that hangs over the display's edge: it is sized first, where it is"],
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
        "old": "    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }\n    guard let app = apps[pid], answers(pid) else {\n",
        "new": "    _ = 0\n    guard let app = apps[pid], answers(pid) else {\n",
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
    {
        "name": "a press on the strip of a window that was swept aside takes hold of it",
        "file": "ArborCore/WindowGrab.swift",
        "old": "    case .known(let window, let listed, let believed)? where !(desktopIsShown && isListedElsewhere(listed, than: believed)):\n",
        "new": "    case .known(let window, let listed, let believed)? where believed != .null:\n",
        "red": [
            "macOS shows its desktop, a window is given another frame meanwhile, and a click on its strip slips, heard 0 ms late: "
            "no drag, no resize, and no window moved by hand is reported",
            "macOS shows its desktop, a window is given another frame meanwhile, and a click on its strip slips, heard 20 ms late: "
            "no drag, no resize, and no window moved by hand is reported",
        ],
    },
    {
        "name": "a press is looked for at its own place only, however late it is served",
        "old": "      pressedAt: point, pointerNow: now, underPress: underPress, underPointer: topWindow(at: now, in: list),\n",
        "new": "      pressedAt: point, pointerNow: point, underPress: underPress, underPointer: underPress,\n",
        "red": [
            "a window is dragged for a second, and the monitor hears of the press 500 ms late: the drag is reported to begin",
            "a window that lies over another is dragged for a second, and the monitor hears of the press 500 ms late: the drag is reported to begin",
            "a window is made wider by its left edge for a second while Arbor's main thread is busy for 300 ms from the press, and what queued up comes byTime: "
            "it is not taken for a drag",
        ],
    },
    {
        "name": "whatever is under the pointer when a press is served late is in the hand",
        "file": "ArborCore/WindowGrab.swift",
        "old": "    where !desktopIsShown && isInTheHand(listed: listed, believed: believed, pressedAt: pressedAt, pointerNow: pointerNow) {\n",
        "new": "    where !desktopIsShown && pressedAt != pointerNow {\n",
        "red": [
            "the button goes down on the wallpaper while Arbor's main thread is busy for 300 ms, the pointer comes to a window, and its app moves it: "
            "no drag and no resize is made of it",
        ],
    },
    {
        "name": "a window can be in the hand while macOS shows its desktop",
        "old": "      desktopIsShown: desktopIsShown(by: list))\n",
        "new": "      desktopIsShown: list.isEmpty)\n",
        "red": [
            "judge: J1 macOS shows its desktop, a rubber band from x 595 is thrown to the right edge of the display and let go, the press heard 500 ms late: "
            "no drag and no resize is made of it",
            "judge: J1 macOS shows its desktop, a rubber band from x 605 is thrown to the right edge of the display and let go, Arbor busy for 500 ms, then byTime: "
            "no drag and no resize is made of it",
        ],
    },
    {
        "name": "a window held by its title bar is judged from a corner the pointer has got to",
        "file": "ArborCore/WindowGrab.swift",
        "old": "        pressedAt.y >= listed.minY + top\n",
        "new": "        pressedAt.y >= listed.minY\n",
        "red": [
            "judge: J3 the window starts 400 ms late, the pointer 120 points along its title bar at its left edge by then, the press heard 300 ms late: "
            "the drag is reported to begin",
        ],
    },
    {
        "name": "a hand can take a window along by the middle of it",
        "file": "ArborCore/WindowGrab.swift",
        "old": "      pressedAt.y < believed.minY + top || isNearEdge(pressedAt, of: believed)\n",
        "new": "      true\n",
        "red": [
            "judge: J2 a stubborn window goes back 60 points while text is selected in it the same way, Arbor busy for 500 ms, then byTime: "
            "no drag and no resize is made of it",
        ],
    },
    {
        "name": "a window a step ahead of its app is in the hand wherever on it the pointer is",
        "file": "ArborCore/WindowGrab.swift",
        "old": "    return ahead <= lag && (pointerNow.y < listed.minY + top || isNearEdge(pointerNow, of: listed))\n",
        "new": "    return ahead <= lag\n",
        "red": [
            "judge: J2b the button goes down on the wallpaper, the pointer comes to a window whose app has moved it 40 points the same way meanwhile, "
            "Arbor busy for 500 ms, then byTime: no drag and no resize is made of it",
        ],
    },
    {
        "name": "the Dock's sign of a sweep is not looked for",
        "old": "      if SweptAside.isTheDocksSign(level: level, frame: bounds, displays: displays) { return true }\n",
        "new": "      if level == .min { return true }\n",
        "red": [
            "judge2: K3 the desktop is shown, 1 window(s) open meanwhile, a rubber band from over a swept window's left edge is thrown to its strip, "
            "the press heard 500 ms late: no drag and no resize is made of it",
        ],
    },
    {
        "name": "a sweep is known by the Dock's sign alone",
        "old": "    return SweptAside.isSwept(believed: records.mapValues(\\.snapshot.frame), listed: listed, displays: displays)\n",
        "new": "    return listed.count > .max\n",
        "red": [
            "on a macOS without the Dock's sign of a sweep, a rubber band from over a swept tile's left edge is thrown to its strip, heard 500 ms late: "
            "no drag, no resize, and no window moved by hand is reported",
        ],
    },
    {
        "name": "a window that trails a hand going up is judged from its upper edge",
        "file": "ArborCore/WindowGrab.swift",
        "old": "      if isNearEdge(pointerNow, of: listed), !isNearEdge(pressedAt, of: believed), pressedAt.y >= believed.minY + top {\n",
        "new": "      if isNearEdge(pointerNow, of: listed), !isNearEdge(pressedAt, of: believed) {\n",
        "red": ["judge2: R 1746: it comes out right", "judge2: R 1048: it comes out right"],
    },
    {
        "name": "a window that is listed elsewhere than its app has it is a picture, whether or not the desktop is shown",
        "file": "ArborCore/WindowGrab.swift",
        "old": "    case .known(let window, let listed, let believed)? where !(desktopIsShown && isListedElsewhere(listed, than: believed)):\n",
        "new": "    case .known(let window, let listed, let believed)? where !isListedElsewhere(listed, than: believed):\n",
        "red": [
            "Arbor moves a window 80 points, 20 ms later the button goes down on its title bar and the pointer goes across, served on time: the drag is reported to begin",
        ],
    },
    {
        # The question before a move is also a guard: an app that hangs by then is sent nothing that it could carry out on waking.
        "name": "what an app said before a move is remembered for half a minute",
        "file": "ArborKit/AX/AXCalls.swift",
        "old": "    if let entry, CallStats.seconds(since: entry.asked) < 1 { return entry.isOn }\n",
        "new": "    if let entry, CallStats.seconds(since: entry.asked) < 30 { return entry.isOn }\n",
        "red": [
            "an app hangs for 8 s at the beginning of a move out of view, and Arbor is quit meanwhile: and it was never told to take one out of view: it hung before the move began",
        ],
    },
    {
        "name": "an app that answers again is not asked which of its windows has the keyboard",
        "old": "      // If it came forward while it was silent, nobody has heard which of its windows has the keyboard.\n      reportFocus(of: pid)\n",
        "new": "      // If it came forward while it was silent, nobody has heard which of its windows has the keyboard.\n      _ = 0\n",
        "red": ["⌘Tab to an app that hangs, and wakes two seconds later: once it wakes, its window, which has the keyboard, is reported focused"],
    },
    {
        # A move out of view that lies in a hung app's queue is carried out when it wakes, for as long as Arbor lives. The word left at the pause lies behind it.
        "name": "a pause leaves no word for an app that does not answer",
        "old": "    if leavesWord { leaveWordForAppsThatDoNotAnswer() }\n",
        "new": "    if leavesWord { _ = 0 }\n",
        "red": [
            "an app hangs for 8 s at the first call that sets something in a move out of view, and Arbor is paused meanwhile: and all its windows are in view, as a pause promises",
            "an app hangs for 8 s half a second after it last answered Arbor, its windows are sent out of view, and Arbor is paused meanwhile: and stay there for as long as the pause lasts",
        ],
    },
    {
        # Several places are tried for a window while Arbor lets go. The first is where it floated, in its own size; the last is "anywhere in view".
        "name": "the word left at a pause is the last place that was tried",
        "old": "    guard isLettingGo, undelivered[window] == nil, let known = records[window]?.snapshot.frame else { return }\n",
        "new": "    guard isLettingGo, undelivered[window] != .zero, let known = records[window]?.snapshot.frame else { return }\n",
        "red": [
            "an app hangs for 8 s at the first call that sets something in a move out of view, and Arbor is paused meanwhile: the one that was on its way out is where it floated, in its own size",
        ],
    },
    {
        # Where its person keeps it is the first place asked for, and the considered one, however little of it shows.
        "name": "word is left only for a place of which half is in view",
        "old": "    guard known.showsLessThanHalf(on: screens), frame.titleBarIsWithinReach(on: screens) else { return }\n",
        "new": "    guard known.showsLessThanHalf(on: screens), !frame.showsLessThanHalf(on: screens) else { return }\n",
        "red": [
            "a floating window is dragged most of the way over the right edge, goes out of view with the Desktop, its app hangs for 8 s, and Arbor is paused meanwhile: "
            "half a second after its app wakes it is exactly where its person keeps it",
        ],
    },
    {
        # A move that finds its app busy is turned away, and no layout has a place for a floating window that is in view.
        "name": "a frame that is owed to a floating window is never paid",
        "file": "ArborKit/Controller/Controller+Hardening.swift",
        "old": "    payTheFrameOwed(to: window, on: display)\n",
        "new": "    _ = 0\n",
        "red": [
            "`float-all` while an app with two docked windows takes 0.8 s over every move: every window has its own earlier frame back",
            "`undo` while an app with two docked windows takes 0.8 s over every move: every window has its own earlier frame back",
        ],
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
