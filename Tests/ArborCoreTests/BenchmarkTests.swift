import ArborCore
import CoreGraphics
import Foundation
import Testing

private let screen = CGRect(x: 0, y: 25, width: 2560, height: 1415)
private func everyone(_: WindowID) -> Bool { true }

/// A hundred windows is more than anyone has open, and Arbor must not be felt even then: a drag lays
/// out a preview at every mouse move, and every command lays out a display.
///
/// `leaf(containing:)` is linear and is called in loops, `isEffective` walks a subtree at every
/// level, and each group tile runs a layout of its own, so several operations are quadratic on
/// paper. Measured on 2026-10-14 (debug build, Linux, four cores), each took under 4 ms at 100 windows
/// in every shape below. The limits are some fifty times that, to catch a change of order and nothing less.
///
/// On the main actor for its stack: the deep shape overflows the 512 KB macOS gives other threads.
@MainActor @Suite(.serialized) struct BenchmarkTests {
  static let count = 100

  /// Every window docked inside the one before: as deep as a hundred windows can go.
  static func deep() -> LayoutTree {
    var tree = LayoutTree()
    var target = tree.dock(WindowID(1), beside: tree.root, edge: .left)
    for id in 2...count { target = tree.dock(WindowID(UInt32(id)), beside: target, edge: id % 2 == 0 ? .bottom : .right) }
    return tree
  }

  static func wide() -> LayoutTree {
    var tree = LayoutTree()
    for id in 1...count { tree.dock(WindowID(UInt32(id)), beside: tree.root, edge: .left) }
    return tree
  }

  static func grid() -> LayoutTree { .grid(of: (1...count).map { WindowID(UInt32($0)) }) }

  enum Shape: String, CaseIterable, Sendable {
    case deep, wide, grid, random
  }

  private func expectQuick(
    _ what: String, within limit: Duration, at location: SourceLocation = #_sourceLocation, _ body: () throws -> Void
  ) rethrows {
    let taken = try ContinuousClock().measure(body)
    #expect(taken < limit, "\(what) took \(taken)", sourceLocation: location)
  }

  @Test(arguments: Shape.allCases) func aHundredWindowsAreNotFelt(shape: Shape) throws {
    let name = shape.rawValue
    var tree = LayoutTree()
    expectQuick("\(name): building", within: .seconds(1)) {
      switch shape {
      case .deep: tree = Self.deep()
      case .wide: tree = Self.wide()
      case .grid: tree = Self.grid()
      case .random: tree = .random(seed: 1, windows: Self.count)
      }
    }
    #expect(tree.allWindows.count == Self.count)
    let last = tree.allWindows.last!
    let leaf = tree.leaf(containing: last)!
    let untiled = LayoutOptions(minimumUsableSize: .zero)

    expectQuick("\(name): 20 layouts", within: .seconds(2)) {
      for _ in 0..<5 {
        _ = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: everyone)
        _ = LayoutEngine.layout(tree, camera: tree.root, in: screen, options: untiled, isPresent: everyone)
        _ = LayoutEngine.layout(tree, camera: tree.root, in: screen, options: untiled, isPresent: { $0.rawValue % 2 == 0 })
        // The worst case for `isEffective`: every level looks all the way down for the one window there is.
        _ = LayoutEngine.layout(tree, camera: tree.root, in: screen, options: untiled, isPresent: { $0 == last })
      }
    }

    let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, options: untiled, isPresent: everyone)
    let view = TreeView(tree: tree, isPresent: everyone)
    expectQuick("\(name): 20 rounds of navigation", within: .seconds(2)) {
      for _ in 0..<5 {
        for edge in Edge.allCases {
          _ = Navigation.adjacentLeaf(to: leaf, toward: edge, in: layout, tree: tree)
          _ = Navigation.neighbor(of: leaf, toward: edge, in: view)
        }
        _ = Navigation.bestFit(for: CGRect(x: 300, y: 300, width: 700, height: 500), in: layout, tree: tree)
        _ = Navigation.stepOut(from: leaf, in: view)
        _ = Navigation.stepIn(from: tree.root, toward: CGPoint(x: 400, y: 400), focused: last, in: view, layout: layout)
        _ = layout.leafOrTile(at: CGPoint(x: 400, y: 400), in: tree)
      }
    }

    // One second of dragging a window across the display at 60 events a second.
    let workspace = Workspace(tree: tree)
    expectQuick("\(name): a second of dragging", within: .seconds(5)) {
      for step in 0..<60 {
        let point = CGPoint(x: 40 + CGFloat(step) * 40, y: 200 + CGFloat(step) * 15)
        let target = DropResolver.resolve(
          point: point, window: WindowID(5_000), layout: layout, tree: tree, visibleFrame: screen)
        _ = workspace.previewFrame(for: WindowID(5_000), at: target, in: screen, options: LayoutOptions(), isPresent: everyone)
      }
    }

    expectQuick("\(name): moving every window", within: .seconds(2)) {
      var moving = workspace
      for window in tree.allWindows { moving.dock(window, at: .cameraEdge(.left)) }
      #expect(moving.tree.invariantViolations() == [])
    }

    try expectQuick("\(name): saving and reading back", within: .seconds(2)) {
      let data = try JSONEncoder().encode(workspace)
      #expect(try JSONDecoder().decode(Workspace.self, from: data) == workspace)
    }

    expectQuick("\(name): closing every window", within: .seconds(2)) {
      var closing = workspace
      for window in tree.allWindows { closing.forget(window) }
      #expect(closing.tree.root == closing.tree.desktop)
    }
  }

  /// Counted, not timed. Each group tile's miniature is a layout of its own, which used to end by
  /// going through every window of the whole tree for a list of hidden windows nobody read: a view of
  /// everything cost tiles × windows, 23 questions a window at 300 windows against 4 without tiles.
  @Test func theWorkPerWindowDoesNotGrowWithTheNumberOfTiles() {
    final class Counter: @unchecked Sendable { var asked = 0 }
    for count in [25, 50, 100, 150, 300] {
      let tree = LayoutTree.grid(of: (1...count).map { WindowID(UInt32($0)) })
      let counter = Counter()
      let layout = LayoutEngine.layout(
        tree, camera: tree.root, in: CGRect(x: 0, y: 0, width: 1440, height: 900),
        isPresent: { _ in
          counter.asked += 1
          return true
        })
      #expect(count < 50 || layout.tiles.contains { $0.kind == .group && $0.miniature.count > 1 })
      #expect(counter.asked <= 8 * count, "\(count) windows: asked \(counter.asked) times")
    }
  }
}
