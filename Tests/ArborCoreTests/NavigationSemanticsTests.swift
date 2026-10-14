import ArborCore
import CoreGraphics
import Testing

private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let d = WindowID(4)
private let dragged = WindowID(9)

/// root(h)[ column(v)[ a, row(h)[c, d] ], desktop, b ]
private struct Fixture {
  var tree = LayoutTree()
  let leafA: NodeID, leafB: NodeID, leafC: NodeID, leafD: NodeID
  var column: NodeID { tree.parent(of: leafA)! }
  var row: NodeID { tree.parent(of: leafC)! }

  init() {
    leafA = tree.dock(a, beside: tree.root, edge: .left)
    leafB = tree.dock(b, beside: tree.root, edge: .right)
    leafC = tree.dock(c, beside: leafA, edge: .bottom)
    leafD = tree.dock(d, beside: leafC, edge: .right)
  }

  func view(without absent: Set<WindowID> = []) -> TreeView { TreeView(tree: tree, isPresent: { !absent.contains($0) }) }

  func layout(camera: NodeID? = nil, without absent: Set<WindowID> = [], options: LayoutOptions = .init()) -> Layout {
    LayoutEngine.layout(tree, camera: camera ?? tree.root, in: screen, options: options, isPresent: { !absent.contains($0) })
  }
}

/// T07, T30 to T33: minimized and hidden windows keep their place in the tree but take no space, so
/// the camera moves as if the splits that now show a single child were not there.
@Suite struct NavigationThroughAbsentWindowsTests {
  @Test func steppingOutSkipsEveryLevelThatLooksTheSame() {
    let f = Fixture()
    // Only c is left of the column: c, the row and the column all fill the same rectangle.
    let view = f.view(without: [a, d])
    for camera in [f.leafC, f.row, f.column] {
      #expect(Navigation.stepOut(from: camera, in: view) == f.tree.root)
    }
    #expect(Navigation.stepOut(from: f.tree.root, in: view) == nil)
  }

  @Test func steppingOutOfAnAbsentWindowStartsFromWhatIsShownInstead() {
    let f = Fixture()
    // The camera was on d, which was then minimized: the row (showing c) is what fills the screen.
    let view = f.view(without: [d])
    #expect(view.effectiveAncestor(of: f.leafD) == f.row)
    #expect(Navigation.stepOut(from: f.leafD, in: view) == f.column)
  }

  @Test func steppingInPassesThroughLevelsThatLookTheSame() {
    let f = Fixture()
    // With a absent the column shows only the row, so stepping in from the column chooses between c and d.
    let absent: Set<WindowID> = [a]
    let layout = f.layout(camera: f.column, without: absent)
    let overD = layout.windowFrames[d]!.center
    #expect(Navigation.stepIn(from: f.column, toward: overD, focused: nil, in: f.view(without: absent), layout: layout) == f.leafD)
    #expect(Navigation.stepIn(from: f.column, toward: nil, focused: c, in: f.view(without: absent), layout: layout) == f.leafC)
  }

  @Test func thereIsNothingToStepIntoWhenOneWindowIsAllThereIs() {
    let f = Fixture()
    let absent: Set<WindowID> = [a, d]
    let layout = f.layout(camera: f.column, without: absent)
    for camera in [f.column, f.row, f.leafC] {
      #expect(Navigation.stepIn(from: camera, toward: nil, focused: c, in: f.view(without: absent), layout: layout) == nil)
    }
  }

  @Test func steppingInNeverChoosesAnAbsentWindow() {
    let f = Fixture()
    let absent: Set<WindowID> = [b]
    let layout = f.layout(without: absent)
    let view = f.view(without: absent)
    #expect(Navigation.stepIn(from: f.tree.root, toward: nil, focused: b, in: view, layout: layout) == f.column)
    // A pointer in a gap, or off the display, goes to the nearest space.
    #expect(Navigation.stepIn(from: f.tree.root, toward: CGPoint(x: 5_000, y: 400), focused: nil, in: view, layout: layout) == f.tree.desktop)
    #expect(Navigation.stepIn(from: f.tree.root, toward: CGPoint(x: -50, y: 400), focused: nil, in: view, layout: layout) == f.column)
  }

  @Test func neighboursSkipAbsentWindows() {
    let f = Fixture()
    #expect(Navigation.neighbor(of: f.leafC, toward: .right, in: f.view()) == f.leafD)
    #expect(Navigation.neighbor(of: f.leafC, toward: .right, in: f.view(without: [d])) == f.tree.desktop)
    #expect(Navigation.neighbor(of: f.leafB, toward: .left, in: f.view()) == f.tree.desktop)
    #expect(Navigation.neighbor(of: f.tree.desktop, toward: .right, in: f.view(without: [b])) == nil)
    #expect(Navigation.neighbor(of: f.tree.desktop, toward: .left, in: f.view(without: [a, c, d])) == nil)
    #expect(Navigation.neighbor(of: f.leafC, toward: .top, in: f.view(without: [a])) == nil)
    #expect(Navigation.neighbor(of: f.tree.root, toward: .left, in: f.view()) == nil)
  }

  @Test func staleCamerasAreTreatedAsTheRoot() {
    let f = Fixture()
    let ghost = NodeID(99)
    #expect(f.view().effectiveAncestor(of: ghost) == f.tree.root)
    #expect(Navigation.stepOut(from: ghost, in: f.view()) == nil)
    #expect(Navigation.neighbor(of: ghost, toward: .left, in: f.view()) == nil)
    #expect(Navigation.stepIn(from: ghost, toward: nil, focused: b, in: f.view(), layout: f.layout()) == f.leafB)
    #expect(f.layout(camera: ghost).camera == f.tree.root)
    #expect(Navigation.commonAncestor(ghost, f.leafA, in: f.tree) == f.tree.root)
    #expect(Navigation.commonAncestor(f.leafA, ghost, in: f.tree) == f.tree.root)
    #expect(Navigation.adjacentLeaf(to: ghost, toward: .left, in: f.layout(), tree: f.tree) == nil)
  }

  @Test func withEveryWindowAbsentTheDesktopIsAllThereIs() {
    let f = Fixture()
    let absent: Set<WindowID> = [a, b, c, d]
    for camera in f.tree.preorder() {
      let layout = f.layout(camera: camera, without: absent)
      #expect(layout.desktopFrame == screen.insetBy(dx: 12, dy: 12))
      #expect(layout.windowFrames.isEmpty && layout.hiddenWindows.isEmpty && layout.tiles.isEmpty && layout.seams.isEmpty)
      #expect(Navigation.stepOut(from: camera, in: f.view(without: absent)) == nil)
      #expect(Navigation.stepIn(from: camera, toward: nil, focused: nil, in: f.view(without: absent), layout: layout) == nil)
    }
  }

  /// T07: the window comes back to the same spot, at the same size.
  @Test func anAbsentWindowComesBackToExactlyWhereItWas() {
    let f = Fixture()
    let before = f.layout()
    for window in [a, b, c, d] {
      let without = f.layout(without: [window])
      #expect(without.windowFrames[window] == nil && !without.hiddenWindows.contains(window))
      #expect(f.layout() == before)
    }
  }

  /// T06: the space a window leaves is shared along its whole row, in proportion, not handed to one neighbour.
  @Test func theSpaceAWindowLeavesIsSharedWithTheWholeRow() {
    var tree = LayoutTree()
    let leaves = (1...4).map { tree.dock(WindowID($0), beside: tree.root, edge: .left) }
    func widths(_ tree: LayoutTree) -> [NodeID: CGFloat] {
      LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: { _ in true }).nodeFrames.mapValues(\.width)
    }
    let before = widths(tree)
    tree.remove(WindowID(2))
    let after = widths(tree)
    let survivors = leaves.filter(tree.contains) + [tree.desktop]
    #expect(survivors.count == 4)
    let gains = survivors.map { after[$0]! - before[$0]! }
    #expect(gains.allSatisfy { $0 > 0 })
    #expect(gains.max()! - gains.min()! <= 1, "equal windows gain equally: \(gains)")
  }
}

/// T01, T02 and F01's drop zones, at their edges.
@Suite struct DropZoneTests {
  private func resolve(_ point: CGPoint, _ f: Fixture, layout: Layout? = nil, window: WindowID = dragged, options: DropOptions = .init()) -> DropTarget {
    DropResolver.resolve(point: point, window: window, layout: layout ?? f.layout(), tree: f.tree, visibleFrame: screen, options: options)
  }

  @Test func aScreenCornerBelongsToTheNearerEdgeAndTiesGoLeftOrRight() {
    let f = Fixture()
    #expect(resolve(CGPoint(x: 2, y: 30), f) == .cameraEdge(.left))
    #expect(resolve(CGPoint(x: 8, y: 27), f) == .cameraEdge(.top))
    #expect(resolve(CGPoint(x: 4, y: 29), f) == .cameraEdge(.left), "equally near: left and right before top and bottom")
    #expect(resolve(CGPoint(x: 1436, y: 896), f) == .cameraEdge(.right))
    #expect(resolve(CGPoint(x: 1430, y: 898), f) == .cameraEdge(.bottom))
  }

  @Test func theBandEndsWhereItSays() {
    let f = Fixture()
    #expect(resolve(CGPoint(x: 11.9, y: 400), f) == .cameraEdge(.left))
    #expect(resolve(CGPoint(x: 12, y: 300), f) == .beside(f.leafA, .left), "the first point of the window itself")
  }

  /// The pointer can be over the menu bar or the Dock, outside the visible frame.
  @Test func beyondTheVisibleFrameIsStillItsEdge() {
    let f = Fixture()
    #expect(resolve(CGPoint(x: 700, y: 3), f) == .cameraEdge(.top))
    #expect(resolve(CGPoint(x: 700, y: 950), f) == .cameraEdge(.bottom))
    #expect(resolve(CGPoint(x: -30, y: 400), f) == .cameraEdge(.left))
  }

  @Test func aWindowCornerBelongsToTheEdgeThatIsNearerInProportion() {
    let f = Fixture()
    let frame = f.layout().windowFrames[b]!  // about 464 wide and 851 tall
    #expect(resolve(CGPoint(x: frame.minX + 40, y: frame.minY + 40), f) == .beside(f.leafB, .top))
    #expect(resolve(CGPoint(x: frame.minX + 10, y: frame.minY + 40), f) == .beside(f.leafB, .left))
    #expect(resolve(CGPoint(x: frame.midX, y: frame.maxY - 20), f) == .beside(f.leafB, .bottom))
  }

  @Test func gapsBetweenWindowsFloat() {
    let f = Fixture()
    let seam = f.layout().seams.first { $0.leading == f.leafC }!
    #expect(resolve(seam.frame.center, f) == .float)
  }

  @Test func aTinyWindowStillHasFourEdgesAndAMiddle() {
    var tree = LayoutTree()
    let leaf = tree.dock(a, beside: tree.root, edge: .left)
    var layout = Layout(camera: tree.root, frame: screen)
    let frame = CGRect(x: 100, y: 100, width: 10, height: 10)
    layout.nodeFrames[leaf] = frame
    layout.windowFrames[a] = frame
    func at(_ x: CGFloat, _ y: CGFloat) -> DropTarget {
      DropResolver.resolve(point: CGPoint(x: x, y: y), window: dragged, layout: layout, tree: tree, visibleFrame: screen)
    }
    #expect(at(101, 105) == .beside(leaf, .left))
    #expect(at(109, 105) == .beside(leaf, .right))
    #expect(at(105, 101) == .beside(leaf, .top))
    #expect(at(105, 109) == .beside(leaf, .bottom))
    #expect(at(105, 105) == .float)
  }

  @Test func droppingOnATileDocksBesideWhatItStandsFor() {
    let f = Fixture()
    let layout = f.layout(options: LayoutOptions(minimumUsableSize: CGSize(width: 500, height: 300)))
    let group = layout.tiles.first { $0.node == f.column }!
    #expect(group.kind == .group)
    #expect(resolve(CGPoint(x: group.frame.maxX - 5, y: group.frame.midY), f, layout: layout) == .beside(f.column, .right))
    // The middle of a group is not a stack to join, with tabs on or off.
    #expect(resolve(group.frame.center, f, layout: layout, options: DropOptions(tabsEnabled: true)) == .float)
    let single = layout.tiles.first { $0.node == f.leafB }!
    #expect(resolve(CGPoint(x: single.frame.minX + 5, y: single.frame.midY), f, layout: layout) == .beside(f.leafB, .left))
    #expect(resolve(single.frame.center, f, layout: layout, options: DropOptions(tabsEnabled: true)) == .stack(f.leafB))
    // The Desktop as a tile is still the Desktop.
    let desktop = layout.tiles.first { $0.kind == .desktop }!
    #expect(resolve(desktop.frame.center, f, layout: layout) == .float)
  }

  /// A window inside a group tile has no slot of its own in view, so the tile is a target like any other.
  @Test func aWindowDraggedOutOfAGroupTileCanDockBesideTheGroup() {
    let f = Fixture()
    let layout = f.layout(options: LayoutOptions(minimumUsableSize: CGSize(width: 500, height: 300)))
    let group = layout.tiles.first { $0.node == f.column }!
    let target = resolve(CGPoint(x: group.frame.maxX - 5, y: group.frame.midY), f, layout: layout, window: a)
    #expect(target == .beside(f.column, .right))
    var workspace = Workspace(tree: f.tree)
    let docked = workspace.dock(a, at: target)
    #expect(docked && workspace.tree.invariantViolations() == [])
    // The column lost a and collapsed into the row, which merged into the root; a sits after it.
    #expect(workspace.tree.children(of: workspace.tree.root).prefix(3) == [f.leafC, f.leafD, workspace.tree.leaf(containing: a)!])
  }

  @Test(arguments: [0, -1, 0.5, 1, 7, CGFloat.nan, .infinity]) func anyEdgeFractionGivesAnAnswer(fraction: CGFloat) {
    let f = Fixture()
    let frame = f.layout().windowFrames[b]!
    for point in [frame.center, CGPoint(x: frame.minX, y: frame.minY), CGPoint(x: frame.maxX - 0.5, y: frame.midY)] {
      let target = resolve(point, f, options: DropOptions(windowEdgeFraction: fraction))
      switch target {
      case .beside(let node, _): #expect(node == f.leafB)
      case .float: break
      default: Issue.record("\(target)")
      }
    }
  }

  /// Every preview is where the drop really lands, for every target there is.
  @Test func previewsMatchDropsForEveryTarget() {
    let f = Fixture()
    var targets: [DropTarget] = Edge.allCases.map { .cameraEdge($0) }
    for node in f.tree.preorder() + [NodeID(99)] {
      targets += Edge.allCases.map { .beside(node, $0) } + [.stack(node)]
    }
    for window in [dragged, a, c] {
      for camera in [f.tree.root, f.column, f.leafB] {
        for target in targets {
          var workspace = Workspace(tree: f.tree)
          workspace.moveCamera(to: camera)
          let preview = workspace.previewFrame(for: window, at: target, in: screen, options: LayoutOptions(), isPresent: { _ in true })
          workspace.dock(window, at: target)
          let layout = LayoutEngine.layout(workspace.tree, camera: workspace.camera, in: screen, isPresent: { _ in true })
          let landed = layout.windowFrames[window] ?? layout.tiles.first { $0.windows.contains(window) }?.frame
          #expect(preview == landed && preview != nil, "\(window) at \(target), camera \(camera)")
          #expect(workspace.tree.invariantViolations() == [])
        }
      }
    }
  }
}

/// Text that people type into settings.json. Whatever it holds, parsing gives a value or an error, and
/// what parses says what it is in a form that parses back to the same value.
@Suite struct SettingsTextFuzzTests {
  static let junk = [
    "", " ", "+", "++", "+a", "a+", "ctrl", "ctrl+", "+ctrl", "ctrl++a", "ctrl+opt+", "⌃", "⌃⌥", "⌃⌥a", "⌘+⇧+a", "CTRL+OPT+SPACE", "ctrl + opt + a",
    "ctrl+a+b", "ctrl+ctrl+a", "f0", "f13", "f1", "F12", "enter", "return", "esc", "escape", "plus", "ctrl+plus", "ctrl+=", "ctrl+\\", "ctrl+`", "ctrl+'",
    "ctrl+é", "ctrl+e\u{301}", "ctrl+İ", "ctrl+ß", "ctrl+🪟", "ctrl+\u{0}", "ctrl+\u{200B}a", "ctrl\u{00A0}+\u{2003}a", "ｃｔｒｌ+a", "ctrl+１", "none", "off", "NONE",
    "shift+cmd", "cmd+shift", "⇧⌘", "⇧ ⌘", "shift+", "shift+x", "hyper", "fn", "dock", "dock left", "dock  left", "DOCK LEFT", "dock sideways", "dock beside",
    "dock beside com.apple.mail", "dock beside com.apple.mail left", "dock beside com.apple.mail left now", "dock\tbeside\ncom.Apple.Mail\u{2003}UP", "float", "float now",
    "ignore", "IGNORE", " ignore ", "dock beside beside beside", "dock beside left left", String(repeating: "ctrl+", count: 50_000) + "a", String(repeating: "a", count: 100_000),
  ]

  @Test func keyChords() {
    for text in Self.junk {
      guard let chord = try? KeyChord(text: text) else { continue }
      #expect((try? KeyChord(text: chord.text)) == chord, "\(text.prefix(40))")
      #expect(!chord.label.isEmpty)
    }
    #expect(throws: KeyChord.ParseError.self) { try KeyChord(text: "ctrl+１") }
    #expect(throws: KeyChord.ParseError.self) { try KeyChord(text: "ctrl+é") }
  }

  @Test func everyChordThereIsRoundTrips() throws {
    for raw in 0..<16 as Range<UInt32> {
      for key in KeyChord.Key.allCases {
        let chord = KeyChord(KeyChord.Modifiers(rawValue: raw), key)
        #expect(try KeyChord(text: chord.text) == chord)
        #expect(try KeyChord(text: chord.text.uppercased()) == chord)
      }
    }
    #expect(Set(KeyChord.Key.allCases.map(\.code)).count == KeyChord.Key.allCases.count, "no two keys share a key code")
  }

  @Test func frameModifiers() {
    for text in Self.junk {
      guard let modifiers = RectangleGesture.Modifiers(text: text) else { continue }
      #expect(RectangleGesture.Modifiers(text: modifiers.text) == modifiers, "\(text.prefix(40))")
    }
  }

  @Test func ruleActions() {
    for text in Self.junk {
      guard let action = try? RuleAction(text: text) else { continue }
      #expect((try? RuleAction(text: action.text)) == action, "\(text.prefix(40))")
    }
    #expect((try? RuleAction(text: "dock\tbeside\ncom.Apple.Mail\u{2003}UP")) == .dockBeside(bundleID: "com.Apple.Mail", .top))
  }

  /// Title matching ignores case the same way on every platform, and compares whole characters.
  @Test func titleMatchingIsTheSameEverywhere() {
    func matches(_ pattern: String, _ title: String) -> Bool {
      AppRule(app: "x", title: pattern, action: .float).matches(bundleID: "x", title: title)
    }
    #expect(matches("inbox", "INBOX (3)"))
    #expect(matches("ÉTÉ", "l'été"))
    #expect(matches("straße", "STRASSE") == false, "no folding beyond case: ß is not ss")
    #expect(matches("e", "e\u{301}") == false, "é written as e and an accent is one character, not an e")
    #expect(matches("é", "e\u{301}"), "but it is the same character as é")
    #expect(matches("🪟", "a 🪟 b"))
    #expect(!matches("x", ""))
  }
}
