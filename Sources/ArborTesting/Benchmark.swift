import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// The things people do all day, each as something that can be counted (`Budget`) and timed on a
/// `Workload` of any size. `BudgetTests` and `arbor-sim bench` share this list, so the numbers in a
/// report are the numbers the tests pin.
@MainActor
public struct BenchmarkCase {
  public let name: String
  public var twoDisplays = false
  public var grid = false
  /// Brings a fresh workload to the state the action starts from. Not measured.
  public var prepare: (Workload) -> Void = { _ in }
  public let action: (Workload) -> Void

  public struct Result: Sendable {
    public var name: String
    public var windows: Int
    public var budget: Budget
    /// The fastest of the repetitions: the controller's own work, since the fakes answer at once.
    public var seconds: Double
  }

  public func run(windows: Int, repetitions: Int = 1) -> Result {
    var best = Double.infinity
    var budget = Budget()
    for _ in 0..<max(repetitions, 1) {
      let workload = Workload(windows: windows, twoDisplays: twoDisplays, grid: grid)
      prepare(workload)
      workload.harness.scheduler.runPending()
      let clock = ContinuousClock()
      var measured = Budget()
      let elapsed = clock.measure { measured = workload.harness.measure { action(workload) } }
      budget = measured
      best = min(best, elapsed.seconds)
    }
    return Result(name: name, windows: windows, budget: budget, seconds: best)
  }

  private static let zoomOnFirstGroup: (Workload) -> Void = {
    $0.harness.run("zoom-node \($0.node(ofGroup: 0).rawValue)")
  }

  private static let inFirstWindow: (Workload) -> Void = {
    zoomOnFirstGroup($0)
    $0.harness.system.userFocus($0.groups[0][0])
  }

  public static func named(_ name: String) -> BenchmarkCase { all.first { $0.name == name }! }

  public static let all: [BenchmarkCase] = [
    BenchmarkCase(name: "zoom") { $0.harness.run("zoom \($0.groups[0][0].rawValue)") },
    BenchmarkCase(
      name: "zoom again", prepare: { $0.harness.run("zoom \($0.groups[0][0].rawValue)") },
      action: { $0.harness.run("zoom \($0.groups[0][0].rawValue)") }),
    BenchmarkCase(
      name: "back", prepare: { $0.harness.run("zoom \($0.groups[0][0].rawValue)") },
      action: { $0.harness.run("back") }),
    BenchmarkCase(
      name: "show-all", prepare: { $0.harness.run("zoom \($0.groups[0][0].rawValue)") },
      action: { $0.harness.run("show-all") }),
    // The first one moves the focus: with thirty windows the focused one is in a tile at launch.
    BenchmarkCase(
      name: "show-all again", prepare: { $0.harness.run("show-all") }, action: { $0.harness.run("show-all") }),
    BenchmarkCase(name: "zoom group") { $0.harness.run("zoom-node \($0.node(ofGroup: 0).rawValue)") },
    BenchmarkCase(
      name: "neighbor", prepare: { $0.harness.run("zoom-node \($0.node(ofGroup: 0).rawValue)") },
      action: { $0.harness.run($0.groups.count > 1 ? "neighbor right" : "neighbor left") }),
    BenchmarkCase(name: "dock") { $0.harness.run("dock \(($0.floating.first ?? $0.docked.last!).rawValue) left") },
    BenchmarkCase(
      name: "dock focused", prepare: { $0.harness.system.userFocus($0.floating.first ?? $0.docked[0]) },
      action: { $0.harness.run("dock left") }),
    // The next few start with the camera on the first group, where its windows are big enough to show.
    BenchmarkCase(name: "float", prepare: zoomOnFirstGroup) { $0.harness.run("float \($0.groups[0][0].rawValue)") },
    BenchmarkCase(name: "close", prepare: zoomOnFirstGroup) { $0.harness.system.close($0.groups[0][0]) },
    // Not the window with the keyboard: macOS would hand that to the app's next window, and the camera would follow.
    BenchmarkCase(
      name: "minimize",
      prepare: {
        zoomOnFirstGroup($0)
        $0.harness.system.userFocus($0.groups[0].last!)
      }
    ) { $0.harness.system.setMinimized($0.groups[0][0], true) },
    BenchmarkCase(name: "seam step", prepare: zoomOnFirstGroup) { workload in
      let h = workload.harness
      if let seam = h.overlays.seams[h.display]?.first { h.overlays.dragSeam(seam, by: 10) }
    },
    BenchmarkCase(name: "resize", prepare: zoomOnFirstGroup) { $0.harness.run("resize \($0.groups[0][0].rawValue) down 20") },
    BenchmarkCase(name: "focus in view", prepare: zoomOnFirstGroup) { $0.harness.system.userFocus($0.groups[0].last!) },
    BenchmarkCase(name: "focus out of view", prepare: zoomOnFirstGroup) { $0.harness.system.userFocus($0.groups.last!.last!) },
    BenchmarkCase(name: "put back", prepare: zoomOnFirstGroup) { workload in
      workload.harness.system.userMove(workload.groups[0][0], to: CGRect(x: 333, y: 222, width: 500, height: 300))
    },
    // The keyboard tiling tools (F22), from the first window of the first group.
    BenchmarkCase(name: "focus down", prepare: inFirstWindow) { $0.harness.run("focus down") },
    BenchmarkCase(name: "focus next", prepare: inFirstWindow) { $0.harness.run("focus next") },
    BenchmarkCase(name: "swap down", prepare: inFirstWindow) { $0.harness.run("swap down") },
    BenchmarkCase(name: "grow", prepare: inFirstWindow) { $0.harness.run("grow") },
    BenchmarkCase(
      name: "balance",
      prepare: {
        inFirstWindow($0)
        $0.harness.run("grow")
      }, action: { $0.harness.run("balance") }),
    BenchmarkCase(name: "rotate", prepare: inFirstWindow) { $0.harness.run("rotate") },
    BenchmarkCase(name: "mirror", prepare: inFirstWindow) { $0.harness.run("mirror") },
    BenchmarkCase(name: "relayout") { $0.harness.run("relayout") },
    BenchmarkCase(name: "hide app") { $0.harness.system.setHidden(pid: $0.busiestApp.pid, true) },
    BenchmarkCase(name: "quit app") { $0.harness.system.quit(pid: $0.busiestApp.pid) },
    BenchmarkCase(name: "space switch") { workload in
      for (index, window) in workload.all.enumerated() where index % 2 == 0 {
        workload.harness.system.setOnActiveSpace(window, false)
      }
    },
    BenchmarkCase(name: "displays: no change", twoDisplays: true) { workload in
      workload.harness.system.setDisplays(workload.harness.system.displayList)
    },
    BenchmarkCase(name: "displays: Dock grows", twoDisplays: true) { workload in
      var displays = workload.harness.system.displayList
      displays[1].visibleFrame.size.height -= 70
      workload.harness.system.setDisplays(displays)
    },
    BenchmarkCase(name: "displays: one unplugged", twoDisplays: true) { workload in
      workload.harness.system.setDisplays([workload.harness.system.displayList[0]])
    },
    // Every window in view, so the camera has the most to do.
    BenchmarkCase(name: "grid: zoom", grid: true) { $0.harness.run("zoom \($0.docked[0].rawValue)") },
    BenchmarkCase(
      name: "grid: back", grid: true, prepare: { $0.harness.run("zoom \($0.docked[0].rawValue)") },
      action: { $0.harness.run("back") }),
    BenchmarkCase(name: "grid: close", grid: true) { $0.harness.system.close($0.docked[0]) },
    BenchmarkCase(name: "grid: seam step", grid: true) { workload in
      let h = workload.harness
      if let seam = h.overlays.seams[h.display]?.first { h.overlays.dragSeam(seam, by: 10) }
    },
    BenchmarkCase(
      name: "grid: terminals", grid: true,
      prepare: { workload in
        // Every window rounds its size, so none is ever exactly where Arbor asked.
        for window in workload.docked { workload.harness.system.setSizeStep(window, CGSize(width: 7, height: 15)) }
        workload.harness.run("zoom \(workload.docked[0].rawValue)")
        workload.harness.run("back")
      },
      action: { $0.harness.run("show-all") }),
    BenchmarkCase(name: "echoes", grid: true) { workload in
      // What follows a camera move on a Mac: each window reports its move and its two resizes.
      for window in workload.docked {
        let snapshot = workload.harness.system.windows[window]!.snapshot
        for _ in 0..<3 { workload.harness.controller.windowChanged(snapshot, userInitiated: false) }
      }
    },
    BenchmarkCase(name: "state") { $0.harness.run("state") },
    BenchmarkCase(name: "shutdown") { $0.harness.controller.shutdown() },
    BenchmarkCase(
      name: "shutdown zoomed", prepare: { $0.harness.run("zoom \($0.groups[0][0].rawValue)") },
      action: { $0.harness.controller.shutdown() }),
    BenchmarkCase(name: "restart") { workload in
      // A second controller finds the windows where the first one left them, as after a crash.
      let old = workload.harness
      old.controller.saveNow()
      old.overlays.removeAll()
      let controller = Controller(
        system: old.system, overlays: old.overlays, store: old.store, scheduler: old.scheduler,
        settings: old.controller.settings, filter: WindowFilter(ownPID: 1))
      controller.start()
    },
  ]
}

/// Times for the pure parts, which no `Budget` shows.
@MainActor
public enum CoreBenchmark {
  public struct Result: Sendable {
    public var name: String
    public var windows: Int
    public var seconds: Double
  }

  public static func run(windows count: Int, repetitions: Int = 20) -> [Result] {
    let tree = Workload.nestedTree(windows: count)
    let frame = FakeWindowSystem.standardDisplay.visibleFrame
    // Nothing is tiled, so every node is laid out.
    let options = LayoutOptions(minimumUsableSize: .zero)
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: frame, options: options, isPresent: { _ in true })
    let view = TreeView(tree: tree, isPresent: { _ in true })
    let windows = tree.allWindows
    let leaves = windows.compactMap { tree.leaf(containing: $0) }
    var workspace = Workspace(tree: tree)
    for index in 0..<(count / 5) {
      workspace.floating[WindowID(UInt32(9000 + index))] = CGRect(x: index, y: index, width: 640, height: 420)
    }
    let state = PersistedState(
      workspaces: [DisplayID("main"): workspace],
      hints: Dictionary(
        uniqueKeysWithValues: workspace.allWindows.map {
          ($0, WindowHint(bundleID: "com.example.app\($0.rawValue % 10)", title: "Window \($0.rawValue): a document"))
        }))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    var results: [Result] = []
    func time(_ name: String, _ body: () -> Void) {
      var best = Double.infinity
      for _ in 0..<repetitions { best = min(best, ContinuousClock().measure(body).seconds) }
      results.append(Result(name: name, windows: count, seconds: best))
    }
    time("layout at the root") {
      _ = LayoutEngine.layout(tree, camera: tree.root, in: frame, options: options, isPresent: { _ in true })
    }
    time("layout with tiles") {
      _ = LayoutEngine.layout(tree, camera: tree.root, in: frame, isPresent: { _ in true })
    }
    time("layout at a leaf") {
      _ = LayoutEngine.layout(tree, camera: leaves[count / 2], in: frame, isPresent: { _ in true })
    }
    time("leaf(containing:) of every window") {
      for window in windows { _ = tree.leaf(containing: window) }
    }
    time("step out, neighbour and ancestor of every leaf") {
      for leaf in leaves {
        _ = Navigation.stepOut(from: leaf, in: view)
        _ = Navigation.neighbor(of: leaf, toward: .right, in: view)
        _ = Navigation.commonAncestor(leaf, leaves[0], in: tree)
      }
    }
    time("drop target at 100 points") {
      for step in 0..<100 {
        let point = CGPoint(x: frame.minX + frame.width * CGFloat(step) / 100, y: frame.minY + frame.height * CGFloat(step * 7 % 100) / 100)
        _ = DropResolver.resolve(
          point: point, window: windows[0], layout: layout, tree: tree, visibleFrame: frame, options: .init())
      }
    }
    time("drop preview") {
      _ = workspace.previewFrame(
        for: windows[0], at: .beside(leaves[count / 2], .left), in: frame, options: options, isPresent: { _ in true })
    }
    time("remove and dock a window") {
      var copy = workspace
      copy.dock(windows[0], at: .beside(leaves[count / 2], .left))
    }
    time("encode state.json") { _ = try? encoder.encode(state) }
    return results
  }
}

extension Duration {
  var seconds: Double {
    Double(components.seconds) + Double(components.attoseconds) / 1e18
  }
}
