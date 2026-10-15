import ArborCore
import ArborKit
import CoreGraphics

extension Harness {
  /// What does not fit together between the arrangement, the controller's record of its last layout, and where the windows
  /// really are; empty when all is well. On one display, or on all of them.
  ///
  /// The layout is worked out afresh. Comparing the windows with `controller.layouts` alone proves nothing about a command
  /// that forgets to lay out at all: the windows still match the layout from before it.
  public func layoutProblems(on only: DisplayID? = nil) -> [String] {
    var problems = staleLayouts(on: only)
    for display in system.displayList.map(\.id) where only == nil || only == display {
      guard let fresh = controller.freshLayout(of: display) else { continue }
      for (window, slot) in fresh.windowFrames.sorted(by: { $0.key < $1.key }) where frame(window) != slot {
        if isShortForNow(window, in: slot) { continue }
        problems.append("\(window) is at \(frame(window).map(Self.brief) ?? "nowhere"), and its place is \(Self.brief(slot))")
      }
      for window in fresh.hiddenWindows.sorted() where system.isVisible(window) && window != controller.windowLetBe {
        problems.append("\(window) should be out of view and is at \(frame(window).map(Self.brief) ?? "nowhere")")
      }
    }
    if let only, !system.displayList.contains(where: { $0.id == only }) { problems.append("there is no display \(only)") }
    return problems
  }

  /// Fresh from another display, a window is as large as that one let it be, and is asked again when macOS has caught up
  /// (Controller+AcrossDisplays.swift). Until it has been asked it may be short of its slot, at the slot's corner and nowhere else. For
  /// whoever compares windows with their slots in the very instant after a journey.
  public func isShortForNow(_ window: WindowID, in slot: CGRect) -> Bool {
    guard controller.windowsToBeAskedAgain.contains(window), let has = frame(window) else { return false }
    return has.origin == slot.origin && has.width <= slot.width && has.height <= slot.height
  }

  /// The displays whose last layout is not what a layout would give now. That is never right once a command or an event
  /// is over, whatever the apps do with the frames they are given, unless a layout is scheduled: a switch of macOS
  /// Spaces, or an app being hidden, is laid out once all of its reports are in. arbor-sim asks after every line.
  public func staleLayouts(on only: DisplayID? = nil) -> [String] {
    var problems: [String] = []
    for display in system.displayList.map(\.id) where only == nil || only == display {
      guard let fresh = controller.freshLayout(of: display) else {
        problems.append("\(display) has no arrangement")
        continue
      }
      guard let last = controller.layouts[display] else {
        problems.append("\(display) was never laid out")
        continue
      }
      if last != fresh { problems.append("\(display) was not laid out again: \(Self.difference(from: last, to: fresh))") }
    }
    return problems
  }

  /// The first thing that differs, in words short enough for a test's failure message.
  private static func difference(from last: Layout, to fresh: Layout) -> String {
    if last.camera != fresh.camera { return "the view was on \(last.camera) and is on \(fresh.camera)" }
    if last.frame != fresh.frame { return "the display was \(brief(last.frame)) and is \(brief(fresh.frame))" }
    let windows = Set(last.windowFrames.keys).union(fresh.windowFrames.keys).sorted()
    if let window = windows.first(where: { last.windowFrames[$0] != fresh.windowFrames[$0] }) {
      func place(_ layout: Layout) -> String { layout.windowFrames[window].map(brief) ?? "not shown" }
      return "the place of \(window) was \(place(last)) and is \(place(fresh))"
    }
    if last.hiddenWindows != fresh.hiddenWindows {
      return "out of view were \(last.hiddenWindows.sorted()) and are \(fresh.hiddenWindows.sorted())"
    }
    if last.tiles != fresh.tiles { return "the tiles were \(last.tiles.map(\.node)) and are \(fresh.tiles.map(\.node)), or have moved" }
    if last.desktopFrame != fresh.desktopFrame {
      return "the Desktop was \(last.desktopFrame.map(brief) ?? "not shown") and is \(fresh.desktopFrame.map(brief) ?? "not shown")"
    }
    return "gaps or spaces differ"
  }

  private static func brief(_ rect: CGRect) -> String {
    "(\(rect.minX),\(rect.minY) \(rect.width)×\(rect.height))"
  }
}
