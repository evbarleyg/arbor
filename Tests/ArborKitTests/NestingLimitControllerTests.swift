import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

@MainActor @Suite struct NestingLimitControllerTests {
  /// A hundred windows, each docked inside the one before: the last two are one above the other, 100 levels down.
  private func deep(
    displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay]
  ) -> (h: Harness, windows: [WindowID]) {
    let h = Harness(displays: displays)
    let windows = (0..<100).map { h.system.open(app: "App\($0)") }
    h.start()
    h.run("dock \(windows[0].rawValue) left")
    for index in 1..<windows.count {
      let edge = index % 2 == 1 ? "bottom" : "right"
      h.run("dock \(windows[index].rawValue) beside \(windows[index - 1].rawValue) \(edge)")
    }
    return (h, windows)
  }

  @Test func theCommandSaysWhyAndTheWindowStaysWhereItWas() {
    let (h, windows) = deep()
    #expect(h.workspace.tree.nesting == 100)
    let extra = h.system.open(app: "Extra")
    let before = h.workspace
    let result = h.run("dock \(extra.rawValue) beside \(windows.last!.rawValue) bottom")
    let other = h.run("dock \(extra.rawValue) beside \(windows.last!.rawValue) right")
    #expect([result.ok, other.ok].filter { !$0 }.count == 1, "one of the two is across the last pair")
    let refusal = result.ok ? other : result
    #expect(refusal.message.contains("100"), "\(refusal.message)")
    #expect(h.workspace.tree.invariantViolations() == [] && h.workspace.tree.nesting == 100)
    #expect(before.isFloating(extra) && h.workspace.contains(extra))
  }

  private static let main = FakeWindowSystem.standardDisplay
  private static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1440, height: 900),
    visibleFrame: CGRect(x: 1440, y: 25, width: 1440, height: 875), isMain: false)

  /// Between displays a window leaves one arrangement and joins another, and must not end up in neither.
  @Test func aWindowRefusedOnAnotherDisplayStaysDockedOnItsOwn() {
    let (h, windows) = deep(displays: [Self.main, Self.side])
    let visitor = h.system.open(app: "Visitor", frame: CGRect(x: 1600, y: 200, width: 500, height: 400))
    h.run("dock \(visitor.rawValue) left")
    let before = h.controller.workspaces
    let slot = h.frame(visitor)

    let refused = h.run("dock \(visitor.rawValue) beside \(windows.last!.rawValue) right")
    #expect(!refused.ok && refused.message.contains("100"), "\(refused.message)")
    #expect(h.controller.workspaces == before)
    #expect(h.frame(visitor) == slot)

    let taken = h.run("dock \(visitor.rawValue) beside \(windows.last!.rawValue) bottom")
    #expect(taken.ok, "along the pair there is room")
    #expect(h.controller.workspaceID(containing: visitor) == Self.main.id)
    #expect(!h.controller.workspaces[Self.side.id]!.contains(visitor))
  }

  /// The deepest pair fills the main display; the drop is on the right edge of its lower half.
  private func dropOnTheDeepestWindow(docked: Bool) -> (h: Harness, visitor: WindowID, slot: CGRect?) {
    let (h, windows) = deep(displays: [Self.main, Self.side])
    let tree = h.workspace.tree
    h.run("zoom-node \(tree.parent(of: tree.leaf(containing: windows.last!)!)!.rawValue)")
    let visitor = h.system.open(app: "Visitor", frame: CGRect(x: 1600, y: 200, width: 500, height: 400))
    if docked { h.run("dock \(visitor.rawValue) left") }
    let slot = h.frame(visitor)
    let target = h.frame(windows.last!)!
    h.system.drag(visitor, through: [
      CGPoint(x: 1800, y: 210), CGPoint(x: target.midX, y: target.midY), CGPoint(x: target.maxX - 30, y: target.midY),
    ])
    return (h, visitor, slot)
  }

  @Test func aDockedWindowDroppedWhereItCannotGoReturnsToItsSlot() {
    let (h, visitor, slot) = dropOnTheDeepestWindow(docked: true)
    #expect(h.overlays.previewHistory.suffix(2) == [nil, nil], "nothing is promised while the pointer is there")
    #expect(h.controller.workspaces[Self.side.id]!.isDocked(visitor))
    #expect(!h.controller.workspaces[Self.main.id]!.contains(visitor))
    #expect(h.frame(visitor) == slot)
    #expect(h.workspace.tree.nesting == 100)
  }

  @Test func aFloatingWindowDroppedWhereItCannotGoFloatsThere() {
    let (h, visitor, _) = dropOnTheDeepestWindow(docked: false)
    #expect(h.controller.workspaces[Self.main.id]!.isFloating(visitor))
    #expect(!h.controller.workspaces[Self.side.id]!.contains(visitor))
    #expect(h.workspace.tree.nesting == 100)
  }

  /// ⌃⌥⌘→ on a window below the last but two: halving the slot of the deepest window beside it would be a
  /// level too many, so it becomes a space of its own between the two groups, which is the other way it has.
  @Test func steppingOutBesideTheDeepestWindowTakesTheWayThatFits() {
    let (h, windows) = deep()
    let extra = h.system.open(app: "Extra")
    #expect(h.run("dock \(extra.rawValue) beside \(windows[97].rawValue) bottom").ok)
    var tree = h.workspace.tree
    let row = tree.parent(of: tree.parent(of: tree.leaf(containing: extra)!)!)!
    #expect(tree.nesting == 100 && tree.subtree(row, contains: tree.leaf(containing: windows[99])!))
    h.run("zoom-node \(row.rawValue)")

    #expect(h.run("dock \(extra.rawValue) right").ok)
    tree = h.workspace.tree
    #expect(tree.nesting == 100 && tree.invariantViolations() == [])
    #expect(tree.parent(of: tree.leaf(containing: extra)!) == row)
    #expect(tree.children(of: row).first == tree.leaf(containing: windows[97]))
  }

  /// ⌃⌥⌘ and an arrow: out of its group and in beside the neighbour, which is a level deeper.
  @Test func movingAWindowWithTheKeyboardNeverNestsDeeperEither() {
    let (h, windows) = deep()
    for window in windows.suffix(4) + windows.prefix(2) {
      h.run("zoom-node \(h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: window)!)!.rawValue)")
      for edge in ["left", "right", "top", "bottom"] {
        let before = h.workspace
        let result = h.run("dock \(window.rawValue) \(edge)")
        #expect(h.workspace.tree.nesting <= 100 && h.workspace.tree.invariantViolations() == [])
        if !result.ok { #expect(h.workspace == before, "\(result.message)") }
      }
    }
  }
}
