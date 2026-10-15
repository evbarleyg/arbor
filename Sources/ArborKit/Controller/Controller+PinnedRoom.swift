import ArborCore
import CoreGraphics
import Foundation

/// Keep in View makes room (docs/features/F49-pin.md; collab/QUESTIONS.md Q25; the rule itself is `PinnedRoom` in ArborCore).
///
/// Every layout of docked windows, real or tried, is made in `roomForViews(on:)` and not in the display's visible frame. What is
/// about floating windows, panels and the screen's own edges goes on asking for the visible frame: a strip is kept clear of
/// docked windows, and of nothing else.
///
/// The window kept in view is never moved for it. Docked windows move once: when the pin is set or taken off, when the window
/// comes or goes (⌘M, ⌘H, closed), when a hand that moved or sized it lets go, and when its own app has moved or sized it and
/// it has stood still for a moment.
extension Controller {
  /// The strips on `display` as things stand. `asLaidOut`: as they were when it was last laid out.
  func pinnedRoom(on display: DisplaySnapshot, asLaidOut: Bool = false) -> PinnedRoom {
    guard let workspace = workspaces[display.id], workspace.pinned != nil else { return PinnedRoom(room: display.visibleFrame) }
    // While the button is down a window may be in the hand, whether or not that has been recognised as a drag or a resize yet. The
    // others wait where they are until it is let go, whatever else lays out meanwhile (a window that opens, live reflow). One that is
    // pinned in the hand has had no room yet, and gets it then. (Not if the display itself is another by now.)
    if asLaidOut || system.isMouseButtonDown() || drag.map({ workspace.isPinned($0.window) }) == true,
      let last = pinnedRoomsLaidOut[display.id], last.visibleFrame == display.visibleFrame
    {
      return last.kept
    }
    let kept = workspace.pinnedWindows.compactMap { window -> (window: WindowID, frame: CGRect)? in
      guard let snapshot = windows[window], isManaged(window) else { return nil }
      if snapshot.isPresent { return (window, whereItCounts(snapshot, on: display)) }
      // In macOS's full screen it is on a Space of its own and comes back to where it was, which is what is remembered. Its room is kept:
      // there and back moves nobody.
      guard snapshot.isFullScreen || keptWindowsLeavingFullScreen[window].map({ $0 > now() }) == true else { return nil }
      return workspace.floating[window].map { (window, $0) }
    }
    return PinnedRoom.reserve(in: display.visibleFrame, for: kept)
  }

  /// Where a window kept in view is. On its way somewhere it is counted where it is going, so that nobody moves twice.
  private func whereItCounts(_ window: WindowSnapshot, on display: DisplaySnapshot) -> CGRect {
    keptWindowsGoTo[window.id] ?? frameBringingIntoView(window.id, on: display) ?? window.frame
  }

  /// What is left of `display` for views: its visible frame without the strips of the windows kept in view.
  func roomForViews(on display: DisplaySnapshot) -> CGRect { pinnedRoom(on: display).room }

  /// Part of `relayout`: what the docked windows have just been laid out beside.
  func noteTheRoomLaidOut(on id: DisplayID) {
    pinnedRoomsLaidOut[id] = display(id).map { ($0.visibleFrame, pinnedRoom(on: $0)) }
  }

  /// How long a window kept in view has to stand still before the docked windows follow a move that no hand made, in seconds. A
  /// call's window grows in steps when somebody shares a screen, and must not drag the arrangement along step by step.
  static let keptWindowRest = 0.33

  /// A window kept in view on `display` has been moved or sized and nothing says that it was let go: its app did it, or a hand
  /// whose grab was taken for neither a drag nor a resize. The docked windows follow once the button is up and it has stood still.
  ///
  /// `asked`: see `makeRoomWhereKeptWindowsAre`.
  func keptWindowMoved(on display: DisplayID, lookingAfter seconds: Double = Controller.keptWindowRest, asked: Bool = false) {
    guard isRunning, workspaces[display] != nil else { return }
    // What was asked for stays asked for, whoever moves the window once more meanwhile.
    let asked = asked || pinnedRoomIsAskedFor.contains(display)
    if asked { pinnedRoomIsAskedFor.insert(display) }
    scheduler.schedule("pinned-room-\(display.rawValue)", after: seconds) { [weak self] in
      guard let self else { return }
      if self.system.isMouseButtonDown() || self.drag != nil {
        self.keptWindowMoved(on: display, asked: asked)
      } else {
        self.makeRoomWhereKeptWindowsAre(on: [display], asked: asked)
      }
    }
  }

  /// Called with every report about a window. macOS says that a window has left full screen when the way out begins, and the others of its
  /// Space can be reported back before it (Controller+OnTheWayBack.swift). Laid out without it they would take its room, in plain view, and
  /// give it back a moment later. If it does not come, they take it when the time is up.
  func noteIfAKeptWindowLeavesFullScreen(_ window: WindowSnapshot, was previous: WindowSnapshot?) {
    if window.isPresent || window.isFullScreen { keptWindowsLeavingFullScreen[window.id] = nil }
    guard previous?.isFullScreen == true, !window.isFullScreen, !window.isPresent, isPinned(window.id),
      let display = workspaceID(containing: window.id)
    else { return }
    keptWindowsLeavingFullScreen[window.id] = now().addingTimeInterval(Self.timeToLandFromFullScreen)
    // A timer of its own, which no further move of the window puts off. Once: whatever the clock says then it is no longer believed, or a
    // clock that stands still (a test's, a Mac that slept) would have Arbor look for ever.
    scheduler.schedule("pinned-room-\(display.rawValue)-back", after: Self.timeToLandFromFullScreen + 0.05) { [weak self] in
      guard let self else { return }
      for window in self.workspaces[display]?.pinnedWindows ?? [] { self.keptWindowsLeavingFullScreen[window] = nil }
      self.makeRoomWhereKeptWindowsAre(on: [display])
    }
  }

  /// Lays out those of `displays` whose windows kept in view are no longer where room was made for them: one move for each docked
  /// window. Says so if one of them has lost its room by it: dragged to the middle, or grown too large.
  ///
  /// `asked`: a person stands behind it: their hand has let go of the window, their key or their rule did it. Nothing else lays out while
  /// the view is held (Controller+Hold.swift): what its own app does to a call's window moves nothing in front of an audience. The docked
  /// windows follow when the hold ends, or with the next layout that something else brings about.
  func makeRoomWhereKeptWindowsAre(on displays: [DisplayID], asked: Bool = false) {
    guard isRunning else { return }
    // Not yet: whatever is in the hand is let go first.
    guard !system.isMouseButtonDown(), drag == nil else {
      for id in displays where workspaces[id]?.pinned != nil { keptWindowMoved(on: id, asked: asked) }
      return
    }
    for id in displays {
      scheduler.cancel("pinned-room-\(id.rawValue)")
      pinnedRoomIsAskedFor.remove(id)
    }
    guard asked || !isHeld else { return }
    sayingWhoLostItsRoom {
      for id in displays {
        guard let display = self.display(id), let laidOut = layouts[id] else { continue }
        if roomForViews(on: display) != laidOut.frame {
          relayout(id, reason: .structure)
          scheduleSave()
        } else {
          // Who has room can change where the room does not: one that lay in another's strip.
          noteTheRoomLaidOut(on: id)
        }
      }
    }
  }

  /// Runs `body`, which lays displays out after a window kept in view was moved.
  func sayingWhoLostItsRoom(_ body: () -> Void) {
    let before = windowsKeptInViewWithoutRoom(asLaidOut: true)
    body()
    sayWhoHasLostItsRoom(since: before)
  }

  func windowsKeptInViewWithoutRoom(asLaidOut: Bool = false) -> Set<WindowID> {
    guard workspaces.values.contains(where: { $0.pinned != nil }) else { return [] }
    return Set(displays.flatMap { pinnedRoom(on: $0, asLaidOut: asLaidOut).without })
  }

  func sayWhoHasLostItsRoom(since before: Set<WindowID>) {
    guard settings.messageLevel != .off, let loser = windowsKeptInViewWithoutRoom().subtracting(before).sorted().first,
      let home = workspaceID(containing: loser), let line = lineSayingItCanBeCovered(loser)
    else { return }
    // A command sums up once it is done (Controller+HeadsUp.swift), and would take down what is said before that. And a line that is up has not
    // been read yet. It is said when the next command has been answered.
    if headsUp.source != nil || headsUp.showing != nil { headsUp.lostItsRoom = loser } else { showHeadsUp(line, on: home) }
  }

  /// Whether docked windows keep clear of `window`, which is kept in view: it has a strip, or lies in another's.
  func hasRoomOfItsOwn(_ window: WindowID) -> Bool {
    guard let home = workspaceID(containing: window), let display = display(home) else { return false }
    return !pinnedRoom(on: display).without.contains(window)
  }

  /// What is so, then what to do.
  static let canBeCovered = (
    fact: "stays in view, but other windows can cover it here", advice: "Near a screen edge they make room for it",
    adviceIfLarge: "Smaller, and near a screen edge, they make room for it")

  /// Wherever it lay, a window of this size would take more than its share: no edge helps.
  func adviceForAWindowWithoutRoom(_ window: WindowID) -> String {
    guard let size = windows[window]?.frame.size, let visible = workspaceID(containing: window).flatMap({ display($0) })?.visibleFrame,
      size.width > PinnedRoom.largestShare * visible.width, size.height > PinnedRoom.largestShare * visible.height
    else { return Self.canBeCovered.advice }
    return Self.canBeCovered.adviceIfLarge
  }

  func lineSayingItCanBeCovered(_ window: WindowID) -> HeadsUpModel? {
    windows[window].map {
      HeadsUpModel(kind: .change, text: "\($0.appName) \(Self.canBeCovered.fact)", hint: adviceForAWindowWithoutRoom(window))
    }
  }

  /// Whether another window lies over part of `window`, which stays in view, so that `state` does not promise what the screen does
  /// not show. Over one that has room of its own only a floating window can lie.
  public func isKeptInViewButCovered(_ window: WindowID) -> Bool {
    guard isRunning, staysInView(window), windows[window]?.isPresent == true, !parked.contains(window) else { return false }
    return isCovered(window, by: system.windowsFrontToBack()) ?? false
  }
}
