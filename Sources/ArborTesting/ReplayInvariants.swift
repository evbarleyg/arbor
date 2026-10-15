import ArborCore
import ArborKit
import CoreGraphics

/// What must hold however Arbor chooses to behave: nothing is lost, the trees are sound, and once things have
/// come to rest windows are where Arbor thinks it put them. Trace replays check these in both modes.
///
/// TODO: the chaos harness (branch `test/chaos`, `Sources/ArborTesting/Chaos.swift`) has an invariant checker of its own.
/// When it is on the trunk, keep one of the two.
@MainActor
public enum ReplayInvariants {
  /// True after every event and command, even in the middle of things.
  public static func always(_ h: Harness) -> [String] {
    let controller = h.controller
    guard controller.isRunning else { return [] }
    var problems: [String] = []

    var homes: [WindowID: Int] = [:]
    for (display, workspace) in controller.workspaces.sorted(by: { $0.key < $1.key }) {
      problems += workspace.tree.invariantViolations().map { "the tree of \(display) is broken: \($0)" }
      if !workspace.tree.contains(workspace.camera) {
        problems.append("the camera of \(display) is on \(workspace.camera), which is not in its tree")
      }
      if controller.display(display) == nil { problems.append("\(display) has a workspace but is not connected") }
      for window in workspace.tree.allWindows { homes[window, default: 0] += 1 }
      for window in workspace.floating.keys { homes[window, default: 0] += 1 }
    }
    // A place kept for a window that is expected back has a number in the tree and no window; `state` lists those.
    let waiting = controller.waitingSlotIDs
    for (window, count) in homes.sorted(by: { $0.key < $1.key }) {
      if count > 1 { problems.append("\(window) is in \(count) places at once") }
      if controller.windows[window] == nil, !waiting.contains(window) {
        problems.append("\(window) is arranged but no longer exists")
      }
    }

    // Nothing lost: Arbor knows every window there is, and every one it arranges has a place.
    for id in h.system.windows.keys.sorted() {
      guard let snapshot = controller.windows[id] else {
        problems.append("\(id) exists but Arbor does not know it")
        continue
      }
      if controller.filter.manages(snapshot), homes[id] == nil, !controller.displays.isEmpty {
        problems.append("\(id) is lost: Arbor arranges it, but it is neither docked nor floating anywhere")
      }
    }
    for id in controller.parked.sorted() where controller.windows[id] == nil {
      problems.append("\(id) is parked but no longer exists")
    }
    return problems
  }

  /// True once scheduled work has run and no drag or resize is going on. `placed` is the frame each window took
  /// the last time Arbor placed it: an app may round or refuse the size it was asked for, and Arbor accepts that.
  public static func atRest(_ h: Harness, placed: [WindowID: CGRect]) -> [String] {
    let controller = h.controller
    guard controller.isRunning else { return [] }
    var problems: [String] = []
    for (display, layout) in controller.layouts.sorted(by: { $0.key < $1.key }) {
      guard let workspace = controller.workspaces[display] else { continue }
      for (window, slot) in layout.windowFrames.sorted(by: { $0.key < $1.key })
      where !controller.windowsLeftToTheirApps.contains(window) {
        guard let frame = h.system.frame(of: window) else { continue }
        let settled = frame.approximatelyEquals(slot, tolerance: 4)
          || placed[window].map { frame.approximatelyEquals($0, tolerance: 4) } ?? false
        if !settled {
          problems.append(
            "\(window) is docked in the slot \(traceText(slot)) but ended up at \(traceText(frame)), where Arbor did not put it")
        }
      }
      for window in layout.hiddenWindows.sorted() where h.system.isVisible(window) {
        if controller.windows[window]?.isPresent == true {
          problems.append("\(window) should be out of view but is at \(traceText(h.system.frame(of: window) ?? .zero))")
        }
      }
      for window in workspace.floating.keys.sorted() where !controller.parked.contains(window) {
        guard let snapshot = controller.windows[window], snapshot.isPresent, controller.filter.manages(snapshot) else {
          continue
        }
        if !controller.displays.contains(where: { $0.frame.overlaps(snapshot.frame) }) {
          problems.append("\(window) floats at \(traceText(snapshot.frame)), which is on no display")
        }
      }
    }
    return problems
  }
}
