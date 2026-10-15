import ArborCore
import CoreGraphics
import Testing

/// A few windows into one group, in one step (`Workspace.dockSideBySide`; QUESTIONS Q29, 9).
@Suite struct WorkspaceSideBySideTests {
  private let a = WindowID(1), b = WindowID(2), c = WindowID(3), d = WindowID(4), e = WindowID(5)

  private func floating(_ windows: [WindowID]) -> Workspace {
    var workspace = Workspace()
    for (place, window) in windows.enumerated() {
      workspace.floating[window] = CGRect(x: 40 * CGFloat(place), y: 40, width: 640, height: 420)
    }
    return workspace
  }

  /// The children of a split, as the windows under each.
  private func row(_ node: NodeID, in workspace: Workspace) -> [[WindowID]] {
    guard case .split(.horizontal, let children) = workspace.tree[node]?.kind else { return [] }
    return children.map { workspace.tree.windows(under: $0) }
  }

  @Test func ofFiveFloatingWindowsThreeBecomeAGroupInTheOrderNamed() {
    var workspace = floating([a, b, c, d, e])
    #expect(workspace.dockSideBySide([c, a, d]) == .docked)
    #expect(row(workspace.camera, in: workspace) == [[c], [a], [d]])
    #expect(workspace.camera != workspace.tree.root && !workspace.tree.subtree(workspace.camera, contains: workspace.tree.desktop))
    #expect(workspace.floating.keys.sorted() == [b, e])
    #expect(workspace.tree.invariantViolations().isEmpty)
    // Each can have its own size back.
    for window in [c, a, d] { #expect(workspace.undockedFrame(of: window)?.size == CGSize(width: 640, height: 420)) }
  }

  @Test(arguments: 2...4) func theyAreEquallyWide(count: Int) {
    var workspace = floating([a, b, c, d, e])
    #expect(workspace.dockSideBySide(Array([e, d, c, b].prefix(count))) == .docked)
    guard case .split(_, let children) = workspace.tree[workspace.camera]?.kind else { return #expect(Bool(false)) }
    #expect(children.count == count && Set(children.map { workspace.tree[$0]!.weight }).count == 1)
  }

  @Test func whatWasDockedStaysDockedInItsOrderAndTheGroupStandsAtTheRightEnd() {
    var workspace = floating([a, b, c, d, e])
    for window in [a, b, c] { workspace.dock(window, at: .cameraEdge(.right)) }
    #expect(workspace.dockSideBySide([e, b]) == .docked)
    #expect(row(workspace.camera, in: workspace) == [[e], [b]])
    // The place b left has closed.
    #expect(row(workspace.tree.root, in: workspace) == [[], [a], [c], [e, b]])
    #expect(workspace.floating.keys.sorted() == [d])
    #expect(workspace.tree.invariantViolations().isEmpty)
  }

  @Test func allThatIsDockedCanBePicked() {
    var workspace = floating([a, b])
    for window in [a, b] { workspace.dock(window, at: .cameraEdge(.right)) }
    #expect(workspace.dockSideBySide([b, a]) == .docked)
    #expect(row(workspace.camera, in: workspace) == [[b], [a]])
    #expect(workspace.tree.allWindows.sorted() == [a, b] && workspace.tree.invariantViolations().isEmpty)
  }

  @Test func aTabLeavesItsGroupAndAColumnItsMember() {
    var workspace = floating([a, b, c, d, e])
    workspace.dock(a, at: .cameraEdge(.right))
    workspace.dock(b, at: .stack(workspace.tree.leaf(containing: a)!))
    workspace.dock(c, at: .cameraEdge(.right))
    workspace.dock(d, at: .beside(workspace.tree.leaf(containing: c)!, .bottom))
    #expect(workspace.dockSideBySide([b, d, e]) == .docked)
    #expect(row(workspace.camera, in: workspace) == [[b], [d], [e]])
    #expect(row(workspace.tree.root, in: workspace) == [[], [a], [c], [b, d, e]])
    #expect(workspace.tree.invariantViolations().isEmpty)
  }

  /// One move of the view, however many steps it takes inside.
  @Test func backLeadsToWhereTheViewWas() {
    var workspace = floating([a, b, c, d])
    for window in [a, b] { workspace.dock(window, at: .cameraEdge(.right)) }
    var framed = workspace
    framed.moveCamera(to: framed.tree.leaf(containing: a)!)
    for (origin, name) in [(workspace, "everything"), (framed, "one window")] {
      var start = origin
      let (from, steps) = (start.camera, start.back.count)
      #expect(start.dockSideBySide([c, d]) == .docked)
      #expect(start.back.count == steps + 1 && start.forward.isEmpty, "\(name)")
      let group = start.camera
      #expect(start.goBack() && start.camera == from, "\(name)")
      #expect(start.goForward() && start.camera == group, "\(name)")
    }
  }

  /// The group stands for as long as the view is on it or comes back to it.
  @Test func seenFromEverythingTheyAreStillSideBySide() {
    var workspace = floating([a, b, c, d])
    workspace.dock(a, at: .cameraEdge(.right))
    #expect(workspace.dockSideBySide([d, c]) == .docked)
    workspace.showEverything()
    #expect(workspace.tree.allWindows == [a, d, c])
    #expect(workspace.goBack() && workspace.tree.windows(under: workspace.camera) == [d, c])
  }

  @Test func oneWindowIsNoGroupAndARefusalChangesNothing() {
    var workspace = floating([a, b])
    let before = workspace
    #expect(workspace.dockSideBySide([a]) == .notADock && workspace.dockSideBySide([]) == .notADock)
    #expect(workspace == before)
  }

  @Test func anArrangementThatWouldNestTooDeepIsLeftAsItWas() {
    var workspace = floating([a, b, c])
    // Deeper and deeper: each new window beside the last, the other way round.
    var next: UInt32 = 100
    workspace.floating[WindowID(next)] = .zero
    workspace.dock(WindowID(next), at: .cameraEdge(.right))
    while workspace.tree.nesting < LayoutTree.maximumDepth {
      let last = workspace.tree.leaf(containing: WindowID(next))!
      next += 1
      workspace.floating[WindowID(next)] = .zero
      guard workspace.dock(WindowID(next), at: .beside(last, next % 2 == 0 ? .right : .bottom)) else { break }
    }
    var vertical = workspace
    // Everything turned into a column: the group's row cannot join it, and has to go one deeper than the root.
    let before = vertical
    let outcome = vertical.dockSideBySide([a, b, c])
    #expect(outcome == .docked || (outcome == .tooDeep && vertical == before))
    #expect(vertical.tree.nesting <= LayoutTree.maximumDepth)
  }
}
