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
            "with macOS's tiling on, a floating window is let go three points short of the left edge of the screen: Arbor stands aside: no preview",
            "with macOS's tiling on, a floating window is let go three points short of the right edge of the screen: let go, it is not docked",
            "with macOS's tiling on, a docked window is let go three points short of the right edge of the screen: Arbor stands aside: no preview",
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
        "old": "      } else if resizingWindow == nil {\n        lookAtPressedWindow()\n",
        "new": "      } else if resizingWindow == nil {\n        _ = 0\n",
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
        "red": ["an app hangs: after waiting a second at most, and not six"],
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
        "name": "every frame is taken to lie on a display",
        "old": "        FramePlan.room(onDisplay: ScreenGeometry.global(fromAppKit: $0.frame), visible: ScreenGeometry.global(fromAppKit: $0.visibleFrame))\n",
        "new": "        FramePlan.room(onDisplay: ScreenGeometry.global(fromAppKit: $0.frame), visible: ScreenGeometry.global(fromAppKit: $0.frame).insetBy(dx: -9000, dy: -9000))\n",
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
        # What a hosted Mac showed on 2026-10-15: a sheet is named by a number of its own, which nobody above the layer knows.
        "name": "a sheet's own number is passed on",
        "old": "    guard role == kAXSheetRole else {\n",
        "new": "    guard role == \"\" else {\n",
        "red": [
            "a sheet comes down over the window that has the keyboard, and is answered: asked where the keyboard is, the layer names the sheet's window",
            "a click on the sheet of another window: the sheet's window is reported focused",
            "a sheet, and a neighbour: its window goes out of view: it is in the window in view",
        ],
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
            "the resize is reported to begin and to end",
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
        "old": "        !isWhereAHandTakesHold(pressedAt, of: listed)\n",
        "new": "        !isNearEdge(pressedAt, of: listed)\n",
        "red": [
            "judge: J3 the window starts 400 ms late, the pointer 120 points along its title bar at its left edge by then, the press heard 300 ms late: "
            "the drag is reported to begin",
        ],
    },
    {
        "name": "a hand can take a window along by the middle of it",
        "file": "ArborCore/WindowGrab.swift",
        "old": "    if believed.insetBy(dx: -edgeMargin, dy: -edgeMargin).contains(pressedAt), isWhereAHandTakesHold(pressedAt, of: believed) {\n",
        "new": "    if believed.insetBy(dx: -edgeMargin, dy: -edgeMargin).contains(pressedAt) {\n",
        "red": [
            "judge: J2 a stubborn window goes back 60 points while text is selected in it the same way, Arbor busy for 500 ms, then byTime: "
            "no drag and no resize is made of it",
        ],
    },
    {
        "name": "a window a step ahead of its app is in the hand wherever on it the pointer is",
        "file": "ArborCore/WindowGrab.swift",
        "old": "    return ahead <= lag && isWhereAHandTakesHold(pointerNow, of: listed)\n",
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
        "old": "      if isNearEdge(pointerNow, of: listed), !isWhereAHandTakesHold(pressedAt, of: believed) {\n",
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
        # Two rules of the walk at storey two, each shown to be able to speak. Arbor ships without the ring, and a rule that reads what is not drawn says nothing for ever.
        "name": "who has the keyboard is not written down",
        "file": "ArborKit/Controller/Controller+Rules.swift",
        "old": "    focusHistory.insert(id, at: 0)\n",
        "new": "    _ = id\n",
        "red": ["the rude walk (upstairs, polite): the window with the keyboard is the one Arbor last saw it in"],
    },
    {
        "name": "the ring stays behind when the keyboard moves",
        "file": "ArborKit/Controller/Controller+FocusRing.swift",
        "old": "    guard settings.focusRing else { return }\n    refreshFocusRing(.focus, focused: focused)\n",
        "new": "    guard settings.focusRing, false else { return }\n    refreshFocusRing(.focus, focused: focused)\n",
        "red": ["the rude walk (upstairs, polite): the focus ring is around the window with the keyboard"],
    },
    {
        "name": "one jump of a window under a press below its top is a hand",
        "old": "      memory: WindowGrab.Memory(isBelowTheTop: hold.isBelowTheTop))\n",
        "new": "      memory: WindowGrab.Memory(isBelowTheTop: false))\n",
        "red": [
            "Arbor sends a stubborn tile 80 points, it goes back after 0.474 s, the list 150 ms behind; 20 ms after the call text is selected in it the way Arbor sent it: "
            "both are tiles still",
            "judge: J2 a stubborn window goes back 60 points while text is selected in it the same way, served on time: no drag and no resize is made of it",
        ],
    },
    {
        "name": "nothing can be taken along but by its top",
        "file": "ArborCore/WindowGrab.swift",
        "old": "    guard abs(frameNow.minX - first.minX) > tremble || abs(frameNow.minY - first.minY) > tremble else {\n",
        "new": "    guard abs(frameNow.minX - first.minX) > .infinity else {\n",
        "red": ["a window is dragged for a second by its background, served on time: the drag is reported to begin"],
    },
    {
        "name": "whether a press is below the top goes by the list alone",
        "file": "ArborCore/WindowGrab.swift",
        "old": "        isBelowTheTop: !(isAtTheTop(pressedAt, of: listed) && isAtTheTop(pressedAt, of: believed)))\n",
        "new": "        isBelowTheTop: !isAtTheTop(pressedAt, of: listed))\n",
        "red": [
            "Arbor sends a stubborn window up 80 points, the press 125 below its new top, 20 ms after the call, the list 150 ms behind, and the pointer goes the way it goes back: "
            "no drag and no resize is made of it",
        ],
    },
    {
        "name": "an edge takes a window along as its top does",
        "file": "ArborCore/WindowGrab.swift",
        "old": "        isBelowTheTop: !(isAtTheTop(pressedAt, of: listed) && isAtTheTop(pressedAt, of: believed)))\n",
        "new": "        isBelowTheTop: !(isAtTheTop(pressedAt, of: listed) && isAtTheTop(pressedAt, of: believed)) && !isNearEdge(pressedAt, of: listed))\n",
        "red": ["a stubborn window goes back 60 points while a scroll bar 6 points inside its right border is pulled down: no drag and no resize is made of it"],
    },
    {
        "name": "without a list every press is at the top",
        "old": "      let isBelowTheTop = !WindowGrab.isAtTheTop(press.point, of: previous)\n",
        "new": "      let isBelowTheTop = false\n",
        "red": ["the window server gives no list, and a stubborn window goes back 60 points while text is selected in it the same way: no drag and no resize is made of it"],
    },
    {
        "name": "the two signs of one jump are two places",
        "file": "ArborCore/WindowGrab.swift",
        "old": "    guard abs(frameNow.minX - first.minX) > tremble || abs(frameNow.minY - first.minY) > tremble else {\n",
        "new": "    guard abs(frameNow.minX - first.minX) >= 1 || abs(frameNow.minY - first.minY) >= 1 else {\n",
        "red": ["the list is 2 points off the app's word, and a stubborn window goes back 60 points while text is selected in it the same way: no drag and no resize is made of it"],
    },
    {
        "name": "a window that goes on may change its size as it goes",
        "file": "ArborCore/WindowGrab.swift",
        "old": "    guard let first = memory.followedTo, abs(frameNow.width - first.width) < 1, abs(frameNow.height - first.height) < 1 else {\n",
        "new": "    guard let first = memory.followedTo else {\n",
        "red": ["a window is made wider by its left edge, which trails the pointer by 30 points when the press is served, the press heard 300 ms late: no drag"],
    },
    {
        "name": "a press that found no window keeps to none",
        "old": "      self.press?.window = isBelowTheTop ? window : nil\n",
        "new": "      self.press?.window = nil\n",
        "red": ["the window server gives no list, and a window is dragged for a second by its background, served on time: the drag is reported to begin"],
    },
    {
        "name": "a press that found no window keeps for good to the first that speaks",
        "old": "    } else if press.window == nil || press.isAdopted, previous.insetBy(dx: -Self.reach, dy: -Self.reach).contains(press.point) {\n",
        "new": "    } else if press.window == nil, previous.insetBy(dx: -Self.reach, dy: -Self.reach).contains(press.point) {\n",
        "red": [
            "the window server gives no list; a window over another app's is dragged by its title bar; the one beneath moves first by itself, the pointer's way: "
            "the drag is reported to begin",
        ],
    },
    {
        "name": "a move of Arbor's own does not start the looks afresh",
        "old": "      self.press?.memory.startAfresh()\n",
        "new": "\n",
        "red": ["text is selected, the window jumps 30 points the pointer's way, Arbor puts it elsewhere, and it jumps 30 points from there: no drag and no resize is made of it"],
    },
    {
        "name": "a window that turns back is still being followed",
        "file": "ArborCore/WindowGrab.swift",
        "old": "    guard wentThePointersWay(from: frameAtPress, to: frameNow, pressedAt: pressedAt, pointerNow: pointerNow, give: lag) else {\n      memory.followedTo = nil\n",
        "new": "    guard wentThePointersWay(from: frameAtPress, to: frameNow, pressedAt: pressedAt, pointerNow: pointerNow, give: lag) else {\n\n",
        "red": ["text is selected, and the window jumps the pointer's way, back beyond where it was, and the pointer's way again: no drag and no resize is made of it"],
    },
    {
        "name": "after one jump the window server is asked with every movement",
        "file": "ArborCore/WindowGrab.swift",
        "old": "        if (x * x + y * y).squareRoot() > patience { memory.stoodStill = true }\n",
        "new": "\n",
        "red": ["a window jumps once early in a selection of 600 movements: in those five seconds the window server is asked some ten times a second from the fifth movement on"],
    },
    {
        "name": "a window that has not gone on at the second look is left alone at once",
        "file": "ArborCore/WindowGrab.swift",
        "old": "        if (x * x + y * y).squareRoot() > patience { memory.stoodStill = true }\n",
        "new": "        memory.stoodStill = true\n",
        "red": ["a window is dragged by its background at sixty movements a second, 1 point a movement: by the background 3 movements later at the most"],
    },
    {
        "name": "a window that jumped is looked at with every movement for as long as the pointer stays in a small spot",
        "file": "ArborCore/WindowGrab.swift",
        "old": "      if let time, let since = memory.stoodSince, time - since >= standing { memory.stoodStill = true }\n",
        "new": "\n",
        "red": [
            "a window jumps 30 ms after the press, and the pointer stays within 20 points of there for 600 movements: "
            "in those five seconds the window server is asked with every movement for half a second, then ten times a second",
        ],
    },
    {
        "name": "the release looks at nothing",
        "old": "      if draggingWindow == nil, resizingWindow == nil, press?.memory.isBelowTheTop == true {\n",
        "new": "      if false, draggingWindow == nil, resizingWindow == nil, press?.memory.isBelowTheTop == true {\n",
        "red": ["a window is taken by its background, the hand goes 6 points, trembles for 62 movements at sixty a second, flicks it away in 32 ms and lets go: the drag is reported to begin"],
    },
    {
        # As it was until 2026-10-15: a held shortcut was a tap in an Arbor that had been granted its permission while it waited.
        "name": "whether a shortcut is held is asked of the session's table",
        "file": "ArborKit/AX/AXWindowSystem+Input.swift",
        "old": "    guard CGEventSource.keyState(.hidSystemState, key: code) || CGEventSource.keyState(.combinedSessionState, key: code) else {\n",
        "new": "    guard CGEventSource.keyState(.combinedSessionState, key: code) else {\n",
        "red": [
            "⌃⌥Space is held, and the session's table hides the key from Arbor: at the first look it is held",
            "⌃⌥Space is held, and the session's table hides the key from Arbor: and a second later",
            "⌃⌥Space is held to look and let go, and the session's table hides the key from Arbor: the hold is seen as a hold",
            "⌃⌥Space is held to look and let go, and the session's table hides the key from Arbor: let go, the view is back where it was",
            "⌃⌥Space is held to look and ⌃⌥⎋ gives it up, and the session's table hides the key from Arbor: Arbor is not paused",
        ],
    },
    {
        # The other way round: a look that never says "up" leaves a peek standing after a release that macOS does not report.
        "name": "a key is never looked at, only the modifiers",
        "file": "ArborKit/AX/AXWindowSystem+Input.swift",
        "old": "    guard CGEventSource.keyState(.hidSystemState, key: code) || CGEventSource.keyState(.combinedSessionState, key: code) else {\n",
        "new": "    guard code < CGKeyCode.max else {\n",
        "red": [
            "⌃⌥Space is held, told truly: nor with ⌃⌥ alone",
            "⌃⌥Space is held, told truly: once the key is up it is not, with ⌃⌥ still down",
            "⌃⌥Space is held, and the session's table hides the key from Arbor: nor with ⌃⌥ alone",
            "⌃⌥Space is held, and the session's table hides the key from Arbor: once the key is up it is not, with ⌃⌥ still down",
        ],
    },
    {
        # What a program posts from a source of its own is, by a guess, in the session's table alone.
        "name": "whether a shortcut is held is asked of the keyboard's table alone",
        "file": "ArborKit/AX/AXWindowSystem+Input.swift",
        "old": "    guard CGEventSource.keyState(.hidSystemState, key: code) || CGEventSource.keyState(.combinedSessionState, key: code) else {\n",
        "new": "    guard CGEventSource.keyState(.hidSystemState, key: code) else {\n",
        "red": ["⌃⌥Space is held by a program that posts it: it is held"],
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
