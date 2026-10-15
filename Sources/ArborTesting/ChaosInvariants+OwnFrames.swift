import ArborCore
import ArborKit
import CoreGraphics

/// A floating window's frame is its person's (collab/QUESTIONS.md, Q20), as a rule of the walks: with `floatingWindowsMakeWay`
/// off, as it ships, **Arbor sets a floating window's frame only to take it out of view and to put it back exactly where
/// it was.** The runner keeps the record itself, from where the windows really were: what the controller remembers
/// is what is being tested.
extension ChaosRunner {
  /// Where a floating window was when it went out of view, by the window system's own account.
  struct Departure {
    var frame: CGRect
    /// No display has come, gone, moved or changed its size since.
    var displaysStayed = true
    /// A hand left it there while Arbor was looking, without carrying it to another display otherwise than by a drag. Only then does
    /// Arbor know that a frame of which little shows is a place somebody chose; where in doubt it brings the window in.
    var wasLeftByHand = false
    /// And its display was then where and as large as it was when the window left.
    var onTheDisplayAsItWas = false
  }

  /// Where a hand left a window, and the frame its display had.
  struct HandNote {
    var frame: CGRect
    var display: CGRect?
  }

  func ownFrameViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    departures = departures.filter { system.windows[$0.key] != nil }
    movedByUndo = movedByUndo.filter { system.windows[$0] != nil }
    noteWhatAHandLeft(after: action)
    // Once this step has been judged: a window that has just left is no longer where the hand left it.
    defer {
      leftByHand = leftByHand.filter { window, note in
        controller.parked.contains(window) || system.windows[window].map { isWhere(note.frame, $0.snapshot.frame, of: window) } == true
      }
    }
    // While they make way, and at the step that changes that, other rules are at work.
    guard wasRunningBefore, !madeWayBefore, !controller.settings.floatingWindowsMakeWay else { return departures.removeAll() }
    // The Dock and the menu bar too: what was fitted into the visible part of a display is fitted again.
    let displaysChanged = controller.displays != displaysBefore
    if displaysChanged {
      for window in departures.keys { departures[window]!.displaysStayed = false }
      // A display that only moves takes its windows and what a hand chose on it along.
      for (window, note) in leftByHand {
        guard let old = displaysBefore.first(where: { $0.frame == note.display }), let new = controller.display(old.id)?.frame,
          new.size == old.frame.size, new != old.frame
        else { continue }
        leftByHand[window] = HandNote(frame: note.frame.offsetBy(dx: new.minX - old.frame.minX, dy: new.minY - old.frame.minY), display: new)
      }
    }
    func floatsOrdinarily(_ window: WindowID, in workspaces: [DisplayID: Workspace]) -> Bool {
      workspaces.values.contains { $0.isFloating(window) && $0.role(of: window) == nil }
    }
    let moved = system.frameLog.count > frameLogMark ? system.frameLog[frameLogMark...].map(\.window) : []
    for (window, fake) in system.windows.sorted(by: { $0.key < $1.key }) {
      guard floatsOrdinarily(window, in: workspacesBefore), floatsOrdinarily(window, in: controller.workspaces) else {
        // Docked, pinned, summoned, let go of: whatever it comes back as, it is not what left.
        departures[window] = nil
        continue
      }
      guard let before = framesBefore[window], fake.snapshot.isPresent, presentBefore.contains(window), cooperates(fake),
        controller.filter.manages(fake.snapshot), filterBefore.manages(fake.snapshot), window != controller.draggedWindow,
        window != system.dragging, window != system.resizing, window != inHandBefore
      else { continue }
      let now = fake.snapshot.frame
      // A rule name of its own for a known failure (ChaosKnownFailures.swift): what an undo or a redo has moved or sent away.
      if isUndoOrRedo(action), now != before { movedByUndo.insert(window) }
      switch (parkedBefore.contains(window), controller.parked.contains(window)) {
      case (false, true):
        if isInView(before) {
          let note = leftByHand[window].flatMap { isWhere($0.frame, before, of: window) ? $0 : nil }
          // A hand's choice holds on the window's own display, for as long as that is where and as large as it was.
          departures[window] = Departure(
            frame: before, displaysStayed: !displaysChanged, wasLeftByHand: note != nil,
            onTheDisplayAsItWas: note != nil && note?.display == controller.workspaceID(containing: window).flatMap { controller.display($0)?.frame })
        }
      case (true, false):
        guard let left = departures.removeValue(forKey: window), !isAbout(window, action) else { continue }
        let requests = system.moveLog[seven.moveLogMark...].filter { $0.window == window }
        if left.displaysStayed, showsHalf(left.frame) || (left.onTheDisplayAsItWas && showsEnoughToGrab(left.frame)) {
          guard let first = requests.first else { continue }
          // There, or asked to be there: an app has the last word on its window's frame (whole cells, a minimum that has grown).
          let theAppWouldNot = isWhere(first.requested, left.frame, of: window) && first.after != whereMacOSPuts(first.requested, window)
          if !isWhere(now, left.frame, of: window), !theAppWouldNot {
            problems.append(.init(movedByUndo.contains(window) ? "own-frame-back-after-undo" : "own-frame-back", "\(window) floated at \(left.frame.brief), went out of view, was asked back to \(first.requested.brief) and is at \(now.brief)"))
          } else if requests.filter({ $0.after != $0.before }).count > 1, first.after == whereMacOSPuts(first.requested, window) {
            problems.append(.init("own-frame-jolt", "\(window) came back to \(now.brief) in \(requests.count) moves"))
          }
        } else if left.wasLeftByHand, now.size == left.frame.size, showsEnoughToGrab(now) {
          // Its display has only moved, and has taken the window and the hand's choice along; or is again as it was then.
        } else if left.displaysStayed, isWhere(now, left.frame, of: window) {
          // Where it was. Whether a hand once left it there Arbor may know better than this record, which an undo and a redo escape.
        } else if !system.displayList.isEmpty, !showsHalf(now), !showsAllThatCan(now) {
          problems.append(.init("own-frame-fit", "\(window) came back at \(now.brief), where nobody is known to have left it, and less than half of it shows"))
        }
      case (false, false):
        // The one exception: a change of displays that cut it off. One that was nowhere a window can be used, and that no hand is known
        // to have left there, is fetched whenever Arbor comes by. And a view can leave and come back within one step.
        if now != before, now != whereMacOSPuts(before, window), moved.contains(window), !displaysChanged, !isAbout(window, action),
          showsHalf(before) || (leftByHand[window].map { isWhere($0.frame, before, of: window) } == true && showsEnoughToGrab(before))
        {
          problems.append(.init("own-frame", "\(window) floated in view at \(before.brief), nobody touched it, and Arbor moved it to \(now.brief)"))
        }
      case (true, true): break
      }
    }
  }

  /// Half of it on some display, and enough of its title bar to get hold of on some display, below the menu bar.
  private func showsHalf(_ frame: CGRect) -> Bool {
    system.displayList.contains { frame.fractionInside($0.frame) >= 0.5 }
      && system.displayList.contains {
        let bar = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: min(frame.height, 28))
        let showing = bar.intersection(
          CGRect(x: $0.frame.minX, y: $0.visibleFrame.minY, width: $0.frame.width, height: $0.frame.maxY - $0.visibleFrame.minY))
        return !showing.isNull && showing.width >= min(frame.width / 2, 40) && showing.height >= bar.height
      }
  }

  /// As much of it as a display can show: a window larger than the display, which its app will not have smaller, in the display's corner.
  private func showsAllThatCan(_ frame: CGRect) -> Bool {
    system.displayList.contains {
      let showing = frame.intersection($0.visibleFrame)
      return !showing.isNull && showing.width >= min(frame.width, $0.visibleFrame.width) - 1
        && showing.height >= min(frame.height, $0.visibleFrame.height) - 1
    }
  }

  /// Keeps `leftByHand`: where a hand has left each floating window since Arbor started and the displays last changed.
  private func noteWhatAHandLeft(after action: ChaosAction) {
    // What Arbor knows of hands it forgets with its process, not with a pause.
    switch action {
    case .launch, .crash, .wayBack: return leftByHand.removeAll()
    default: break
    }
    guard isRunning, wasRunningBefore else { return }
    // (Only in a script does a hand get hold of a window that is out of view.)
    if case .move(let moved, _) = action, parkedBefore.contains(moved) { departures[moved] = nil }
    let (window, wasDragged): (WindowID?, Bool)
    switch action {
    // (An app that resizes its own window reports it as a hand would, and nobody can tell the two apart.)
    case .move(let moved, _), .edge(let moved, _, _), .limits(let moved, _, _): (window, wasDragged) = (moved, false)
    // (`settle` lets go of the mouse first.)
    case .release, .settle: (window, wasDragged) = (inHandBefore, true)
    default: (window, wasDragged) = (nil, false)
    }
    guard let window, let frame = system.windows[window]?.snapshot.frame, let home = controller.workspaceID(containing: window) else { return }
    movedByUndo.remove(window)
    // No hand takes a window across a border without a drag.
    if wasDragged || workspacesBefore[home]?.contains(window) == true {
      leftByHand[window] = HandNote(frame: frame, display: controller.display(home)?.frame)
    }
  }

  private func isUndoOrRedo(_ action: ChaosAction) -> Bool {
    switch action {
    case .command(let text), .via(_, let text), .key(let text, _), .url(let text): text.hasSuffix("undo") || text.hasSuffix("redo")
    default: false
    }
  }

  /// The same place, macOS putting windows on whole points whatever an app or a hand left behind.
  private func isWhere(_ a: CGRect, _ b: CGRect, of window: WindowID) -> Bool { whereMacOSPuts(a, window) == whereMacOSPuts(b, window) }

  private func whereMacOSPuts(_ frame: CGRect, _ window: WindowID) -> CGRect {
    system.whereMacOSPuts(frame, titleBar: system.windows[window]?.titleBar ?? FakeWindowSystem.usualTitleBar)
  }

  /// A strip about a title bar's height either way. Where less than that showed Arbor does not put a window back: it brings it in.
  private func showsEnoughToGrab(_ frame: CGRect) -> Bool {
    system.displayList.contains {
      let showing = frame.intersection($0.visibleFrame)
      return !showing.isNull && showing.width >= 24 && showing.height >= 24 && frame.minY >= $0.visibleFrame.minY
        && frame.minY <= $0.visibleFrame.maxY - 24
    }
  }

  /// The rules that placing, shoving and squeezing floating windows breaks, besides those that are about floating windows by their names
  /// (`-floating`). With `floatingWindowsMakeWay` on, as until F64, they break as they did, and have names of their own there, so that
  /// what is known of the way back excuses nothing as Arbor ships.
  static let rulesThatMakingWayBreaks: Set = [
    "moved-unasked", "moved-before-any-dock", "grown-while-hanging", "left-its-place", "parked-beside-another-display",
    "displays-left-mostly-out", "moved-at-launch-after-a-crash", "moved-twice-floating-windows-first",
  ]

  func nameWhatComesOfMakingWay(_ problems: inout [InvariantViolation]) {
    guard madeWayBefore || controller.settings.floatingWindowsMakeWay else { return }
    for index in problems.indices
    where Self.rulesThatMakingWayBreaks.contains(problems[index].rule) || problems[index].rule.hasSuffix("-floating") {
      problems[index].rule += "-making-way"
    }
  }

  /// Whether a person who does this means `window`. As the nets of the seven rules have it where they can tell. Where they cannot: a
  /// command that names it; one that is about whole arrangements; an undo or a redo that changes what is remembered of it.
  private func isAbout(_ window: WindowID, _ action: ChaosAction) -> Bool {
    if let concerned = seven.concerned { return concerned.contains(window) }
    if isUndoOrRedo(action) {
      func remembered(_ workspaces: [DisplayID: Workspace]) -> [CGRect] { workspaces.sorted { $0.key < $1.key }.compactMap { $0.value.floating[window] } }
      return remembered(workspacesBefore) != remembered(controller.workspaces)
    }
    let line: String
    switch action {
    case .command(let text), .via(_, let text), .key(let text, _), .url(let text): line = text
    // Everything a person tries when a window is gone, which is about every window.
    case .palette, .wayBack: return true
    default: return false
    }
    let words = line.split { !$0.isLetter && !$0.isNumber && $0 != "-" }.map(String.init)
    if words.contains("\(window.rawValue)") { return true }
    // By app, whichever of its windows that turns out to be.
    if words.contains("summon") || words.contains("layout") { return true }
    // "Back to a normal Mac": every window wholly within reach, as at a quit.
    return words.contains("float-all")
  }
}
