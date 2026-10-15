import ArborCore
import ArborKit
import CoreGraphics

// What the chaos test (docs/TESTING.md, "Chaos") needs of the fake beyond what scenario tests use: apps that do not
// do as they are asked, echoes that arrive when the script says so, drags in pieces, and what happens to
// windows while Arbor is not running.

// MARK: Misbehaving apps

extension FakeWindowSystem {
  /// How a window's app treats the frames Arbor asks for.
  public enum Behaviour: String, Sendable, CaseIterable {
    /// Takes any frame within its minimum and maximum size.
    case normal
    /// Ignores every request: the window stays exactly where it is.
    case frozen
    /// Takes the frame, then goes back to where it was at the next `appsReact()`.
    case snapsBack = "snaps-back"
    /// Rounds its size down to a grid of 20 points, like a terminal with very large characters.
    case grid
  }

  public func setBehaviour(_ window: WindowID, _ behaviour: Behaviour) {
    windows[window]?.behaviour = behaviour
    windows[window]?.home = nil
    windows[window]?.changedItsWays = true
  }

  /// The frame a window's app makes of `frame` when Arbor asks for it, before macOS has its say.
  static func accepted(_ frame: CGRect, by fake: FakeWindow) -> CGRect {
    if fake.behaviour == .frozen { return fake.snapshot.frame }
    var applied = frame
    if fake.behaviour == .grid {
      applied.size.width = max((frame.width / 20).rounded(.down), 1) * 20
      applied.size.height = max((frame.height / 20).rounded(.down), 1) * 20
    }
    applied.size.width = max(applied.width, fake.minimumSize.width)
    applied.size.height = max(applied.height, fake.minimumSize.height)
    if let maximum = fake.maximumSize {
      applied.size.width = min(applied.width, maximum.width)
      applied.size.height = min(applied.height, maximum.height)
    }
    if let step = fake.sizeStep { applied.size = rounded(applied.size, toStepsOf: step, margin: fake.sizeMargin) }
    return applied
  }

  /// Whether `appsReact()` has anything to deliver.
  public var hasHeldEchoes: Bool { !undelivered.isEmpty }
  /// Whether `window` has come out of the Dock because it was given the keyboard, and its app has still to say so.
  public func hasStillToReportThatItCameBack(_ window: WindowID) -> Bool { undelivered.contains(.cameBack(window)) }

  /// Delivers the echoes held back since the last call (`holdsEchoes`), in order; what Arbor's reactions queue
  /// meanwhile waits for the next call. A window that snaps back does so instead of echoing, which looks like a user's move.
  public func appsReact() {
    var (echoes, hadTheirTurn): ([Echo], Set<Int32>) = ([], [])
    while !undelivered.isEmpty { echoes.append(takeNextEcho(&hadTheirTurn)) }
    var snappedBack: Set<WindowID> = []
    for echo in echoes {
      switch echo {
      case .frame(let window):
        guard let fake = windows[window], !snappedBack.contains(window) else { continue }
        if fake.behaviour == .snapsBack, let home = fake.home, home != fake.snapshot.frame {
          snappedBack.insert(window)
          windows[window]!.snapshot.frame = home
          events?.windowChanged(windows[window]!.snapshot, userInitiated: true)
        } else {
          events?.windowChanged(fake.snapshot, userInitiated: false)
        }
      case .focus(let window):
        if windows[window] != nil { events?.windowFocused(window) }
      case .keyboardMoved: events?.keyboardFocusMoved()
      case .cameBack(let window):
        if let fake = windows[window] { events?.windowChanged(fake.snapshot, userInitiated: true) }
      }
    }
  }
}

// MARK: Drags in pieces, and what happens while Arbor is not running

extension FakeWindowSystem {
  /// Opens a window under a number of the caller's choice (nothing happens if it is taken), so that
  /// deleting steps from a script does not renumber the windows opened later.
  public func open(
    id: WindowID, app: String, bundleID: String?, title: String, pid: Int32, frame: CGRect,
    minimumSize: CGSize = .zero, maximumSize: CGSize? = nil, behaviour: Behaviour = .normal, cells: RealApp.Cells? = nil,
    idealSize: CGSize? = nil
  ) {
    guard !existingWindowIDs().contains(id) else { return }
    nextID = max(nextID, id.rawValue &+ 1)
    var frame = whereItOpens(frame)
    // It opens with whole steps, as it has them ever after.
    if let cells { frame.size = Self.rounded(frame.size, toStepsOf: cells.step, margin: cells.margin) }
    let snapshot = WindowSnapshot(id: id, pid: pid, bundleID: bundleID, appName: app, title: title, frame: frame)
    windows[id] = FakeWindow(
      snapshot: snapshot, minimumSize: minimumSize, maximumSize: maximumSize, behaviour: behaviour)
    if let cells { (windows[id]!.sizeStep, windows[id]!.sizeMargin) = (cells.step, cells.margin) }
    windows[id]!.idealSize = idealSize
    // As in `open(app:)`.
    if echoes.keyboard {
      focused = id
      bringToFront(id)
    }
    guard started else { return }
    events?.windowAppeared(snapshot)
    if echoes.keyboard { giveKeyboard(to: id) }
    deliverEchoes()
  }

  /// The app quits: its windows go one after the other, as `AXWindowSystem.forget(pid:)` reports it.
  public func quitApp(pid: Int32) {
    for id in windows.keys.sorted() where windows[id]!.snapshot.pid == pid { close(id) }
  }

  /// A click on its icon in the Dock, or ⌘Tab: all of an app's windows come to lie in front of the others', in the order they had among themselves. Which of them
  /// gets the keyboard is another matter, and is reported.
  public func bringForward(pid: Int32) {
    for id in windowsFrontToBack().filter({ windows[$0]?.snapshot.pid == pid }).reversed() { bringToFront(id) }
  }

  /// What a window's app makes of macOS's zoom, which offers it `offered`, all the screen has within the window's own limits. So Calendar, Terminal, the Finder, Preview and System Settings
  /// were seen to on hosted Macs. An app that knows the right size for what it shows takes that, where the window stands: a Finder window shrinks to what it holds, and Preview's, which fits its picture
  /// already, does not change. One that comes in steps takes whole steps that fit. One that cannot be as large as the screen grows where it stands, as far as it goes and the screen has
  /// room; one of a single size has nothing to zoom to, and stays.
  func zoomedAsItsAppHasIt(_ offered: CGRect, _ fake: FakeWindow, within visible: CGRect) -> CGRect {
    let start = fake.snapshot.frame
    var size = offered.size
    if let ideal = fake.idealSize {
      size = CGSize(width: max(min(ideal.width, size.width), fake.minimumSize.width), height: max(min(ideal.height, size.height), fake.minimumSize.height))
    }
    if let step = fake.sizeStep {
      size = Self.rounded(size, toStepsOf: step, margin: fake.sizeMargin)
      // Not the nearest, which may reach under the Dock.
      if size.width > visible.width { size.width -= step.width }
      if size.height > visible.height { size.height -= step.height }
    }
    // One that fills the screen begins at its corner, whatever its steps leave over. Another is moved only as far as it takes to show all of it.
    guard fake.idealSize != nil || fake.maximumSize != nil else { return CGRect(origin: offered.origin, size: size) }
    return CGRect(
      x: max(min(start.minX, visible.maxX - size.width), visible.minX), y: max(min(start.minY, visible.maxY - size.height), visible.minY), width: size.width, height: size.height)
  }

  /// Gives a window a new number without telling anyone, as restarting its app (or the Mac) does
  /// between two runs of Arbor. Nothing happens if the new number is taken.
  public func renumber(_ window: WindowID, as new: WindowID) {
    guard !existingWindowIDs().contains(new), var fake = windows.removeValue(forKey: window) else { return }
    fake.snapshot.id = new
    windows[new] = fake
    nextID = max(nextID, new.rawValue &+ 1)
    if focused == window { focused = new }
  }

  /// `renumber(_:as:)` with the next number, which no window has had. Returns it.
  @discardableResult
  public func renumber(_ window: WindowID) -> WindowID? {
    guard windows[window] != nil else { return nil }
    let new = WindowID(nextID)
    renumber(window, as: new)
    return new
  }

  /// The window being dragged by its title bar.
  public var dragging: WindowID? { inHand?.window }

  /// `beginDrag`, if nothing else is being dragged or resized and the button is up.
  public func grab(_ window: WindowID) {
    guard windows[window] != nil, dragging == nil, resizing == nil, !mouseDown else { return }
    beginDrag(window)
  }

  /// Moves the pointer, and the window it holds, to `point`.
  public func carry(to point: CGPoint) {
    if dragging == nil { cursor = point } else { moveDrag(to: point) }
  }

  /// Releases the mouse button, ending the drag or the edge resize in progress.
  public func letGo() {
    if dragging == nil { releaseMouse() } else { endDrag() }
  }

  /// The button comes up and nobody sees it. The Accessibility layer notices a moment later and calls the drag off.
  public func loseTheRelease() {
    if dragging == nil { releaseMouse() } else { loseTheReleaseOfTheDrag() }
  }

  /// `openTab(in:)` under a number of the caller's choice (nothing happens if it is taken).
  public func openTab(id: WindowID, in window: WindowID) {
    guard !existingWindowIDs().contains(id), backgroundTabs[id] == nil, windows[window] != nil else { return }
    nextID = id.rawValue
    let front = windows[window]
    openTab(in: window)
    inherit(front, by: id)
  }

  /// The tabs of a group share their frame, so what is known about how the one in front got there holds for the next.
  func inherit(_ front: FakeWindow?, by tab: WindowID) {
    guard let front, windows[tab] != nil else { return }
    windows[tab]!.behaviour = front.behaviour
    windows[tab]!.lastRequest = front.lastRequest
    windows[tab]!.placeIsArborsDoing = front.placeIsArborsDoing
    windows[tab]!.changedItsWays = front.changedItsWays
    windows[tab]!.home = front.home
  }

  /// The frame `window` would end up with if its edges were dragged toward `requested`.
  public func frameAfterResizing(_ window: WindowID, toward requested: CGRect) -> CGRect? {
    windows[window].map { Self.appResized($0, toward: requested) }
  }

  /// macOS moves a window itself, as it does when the displays change. Nobody hears of it until `report`.
  public func moveSilently(_ window: WindowID, to frame: CGRect) {
    if let old = windows[window]?.snapshot.frame, old.size == frame.size, let request = windows[window]?.lastRequest {
      let (dx, dy) = (frame.minX - old.minX, frame.minY - old.minY)
      windows[window]?.lastRequest = (request.asked.offsetBy(dx: dx, dy: dy), request.took.offsetBy(dx: dx, dy: dy))
    }
    windows[window]?.snapshot.frame = frame
  }

  /// The late notification for a window that moved: it carries the frame the window has by now.
  public func report(_ window: WindowID, userInitiated: Bool) {
    guard let snapshot = windows[window]?.snapshot else { return }
    events?.windowChanged(snapshot, userInitiated: userInitiated)
  }

  /// Forgets the mouse and whatever was queued: Arbor's process ended, and its next run sees neither.
  public func forgetSession() {
    inHand = nil
    undelivered.removeAll()
    mouseDown = false
    resizing = nil
  }
}
