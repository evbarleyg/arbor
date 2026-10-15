import ArborCore
import ArborKit
import CoreGraphics

/// A desk as people keep one, for counting and timing what commands cost: most windows docked in groups
/// of three (one window above two side by side), the groups in a row beside the Desktop, every fifth
/// window floating, and two windows for every three apps or so.
@MainActor
public struct Workload {
  public let harness: Harness
  /// The docked windows, group by group.
  public let groups: [[WindowID]]
  public let floating: [WindowID]

  public var docked: [WindowID] { groups.flatMap { $0 } }
  public var all: [WindowID] { (docked + floating).sorted() }

  public static let secondDisplay = DisplaySnapshot(
    id: DisplayID("second"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055), isMain: false)

  /// Large enough to show thirty windows at a usable size.
  public static let largeDisplay = DisplaySnapshot(
    id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 3840, height: 2160),
    visibleFrame: CGRect(x: 0, y: 25, width: 3840, height: 2135), isMain: true)

  /// - Parameters:
  ///   - twoDisplays: adds `secondDisplay` with one more group of three docked on it.
  ///   - grid: instead of groups, every window docked in a grid (`arrange`) on `largeDisplay`, all of
  ///     them in view: the most a camera move can have to do.
  public init(windows count: Int, twoDisplays: Bool = false, grid: Bool = false, settings: Settings = Settings()) {
    let main = grid ? Self.largeDisplay : FakeWindowSystem.standardDisplay
    // The fake numbers windows from 101 in the order they open.
    let ids = (0..<count).map { WindowID(UInt32(101 + $0)) }
    let far = twoDisplays ? (0..<3).map { WindowID(UInt32(101 + count + $0)) } : []

    // The arrangement is built as a saved state and restored, which lays each display out once;
    // docking the windows one command at a time would take seconds on a big desk.
    var groups: [[WindowID]] = []
    var floating: [WindowID] = []
    var workspace = Workspace()
    if grid {
      workspace.reset(tree: .grid(of: ids, desktopWeight: settings.desktopWeightWhenArranged))
      groups = ids.map { [$0] }
    } else {
      for (index, id) in ids.enumerated() {
        if index % 5 == 4 { floating.append(id) } else if groups.last.map({ $0.count < 3 }) == true {
          groups[groups.count - 1].append(id)
        } else {
          groups.append([id])
        }
      }
      for group in groups { Self.dock(group, in: &workspace) }
      // Known to the arrangement like the rest: a window it does not know opened while Arbor was not looking, and
      // stays in view whatever the view shows.
      for id in floating { workspace.floating[id] = Self.openingFrame(Int(id.rawValue) - 101) }
    }
    var saved = PersistedState(workspaces: [main.id: workspace], hints: [:])
    if twoDisplays {
      var second = Workspace()
      Self.dock(far, in: &second)
      saved.workspaces[Self.secondDisplay.id] = second
    }

    let h = Harness(displays: [main] + (twoDisplays ? [Self.secondDisplay] : []), settings: settings, saved: saved)
    let apps = max(count * 2 / 3, 1)
    for index in 0..<count {
      let app = index % apps
      h.system.open(app: "App\(app)", pid: Int32(2000 + app), frame: Self.openingFrame(index))
    }
    for index in far.indices {
      h.system.open(
        app: "Far\(index)", pid: Int32(3000 + index), frame: CGRect(x: 1700 + index * 60, y: 200, width: 640, height: 420))
    }
    h.start()
    // Pushes the floating windows onto the Desktop, as docking the others by hand would have.
    h.run("relayout")
    // As ⌘Tab does it, without the event a click would send: on a big desk this window is inside a tile, and the
    // camera would go to it.
    h.system.userSwitchesApp(to: groups[0][0])
    h.scheduler.runPending()
    harness = h
    self.groups = groups
    self.floating = floating
  }

  /// Where the window with this index is before Arbor starts.
  private static func openingFrame(_ index: Int) -> CGRect {
    CGRect(x: 200 + (index % 7) * 40, y: 120 + (index % 5) * 40, width: 640, height: 420)
  }

  /// Docks a group at the right of the view: the first window above the other two, side by side.
  private static func dock(_ group: [WindowID], in workspace: inout Workspace) {
    for (index, window) in group.enumerated() {
      switch index {
      case 0: workspace.dock(window, at: .cameraEdge(.right))
      case 1: workspace.dock(window, at: .beside(workspace.tree.leaf(containing: group[0])!, .bottom))
      default: workspace.dock(window, at: .beside(workspace.tree.leaf(containing: group[1])!, .right))
      }
    }
  }

  /// The split holding a group's windows (or the leaf, for a group of one).
  public func node(ofGroup index: Int) -> NodeID {
    let tree = harness.workspace.tree
    let leaves = groups[index].compactMap { tree.leaf(containing: $0) }
    return leaves.dropFirst().reduce(leaves[0]) { Navigation.commonAncestor($0, $1, in: tree) }
  }

  /// The windows of the app that has the most of them.
  public var busiestApp: (pid: Int32, windows: [WindowID]) {
    var byApp: [Int32: [WindowID]] = [:]
    for id in all { byApp[harness.system.windows[id]!.snapshot.pid, default: []].append(id) }
    let best = byApp.max { ($0.value.count, $1.key) < ($1.value.count, $0.key) }!
    return (best.key, best.value)
  }

  /// A nested tree of `count` windows for timing the core: every leaf is split in turn, alternating
  /// the axis, so the depth grows with the logarithm of the count as it does on a real desk.
  public static func nestedTree(windows count: Int) -> LayoutTree {
    var tree = LayoutTree()
    var leaves: [NodeID] = []
    for index in 0..<count {
      let window = WindowID(UInt32(101 + index))
      if leaves.isEmpty {
        leaves.append(tree.dock(window, beside: tree.root, edge: .left))
      } else {
        let target = leaves.removeFirst()
        let edge: Edge = tree.depth(of: target) % 2 == 0 ? .right : .bottom
        leaves.append(target)
        leaves.append(tree.dock(window, beside: target, edge: edge))
      }
    }
    return tree
  }
}
