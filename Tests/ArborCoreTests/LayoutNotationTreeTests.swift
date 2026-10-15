import ArborCore
import CoreGraphics
import Foundation
import Testing

private func window(_ id: UInt32, _ app: String, title: String = "") -> WindowCandidate {
  WindowCandidate(id: WindowID(id), bundleID: "com.example.\(app.lowercased())", appName: app, title: title)
}

/// The tree spelled out by code that shares nothing with the notation: `h(101 D*0.5 v(102 103))`, with
/// each weight as a share of its group's smallest, and `!` after the tab that shows.
private func shape(_ tree: LayoutTree, _ id: NodeID? = nil) -> String {
  let id = id ?? tree.root
  switch tree[id]!.kind {
  case .desktop: return "D"
  case .stack(let windows, let active):
    guard windows.count > 1 else { return "\(windows[0].rawValue)" }
    return "[" + windows.enumerated().map { "\($1.rawValue)" + ($0 == active ? "!" : "") }.joined(separator: " ") + "]"
  case .split(let axis, let children):
    let smallest = children.map { tree[$0]!.weight }.min()!
    let parts = children.map { child -> String in
      let share = (tree[child]!.weight / smallest * 1000).rounded() / 1000
      return shape(tree, child) + (share == 1 ? "" : "*\(share)")
    }
    return (axis == .horizontal ? "h(" : "v(") + parts.joined(separator: " ") + ")"
  }
}

/// Parses, matches and builds in one go.
private func build(
  _ line: String, _ windows: [WindowCandidate], desktopSize: Double = 0.5
) throws -> (tree: LayoutTree, resolution: LayoutNotation.Resolution) {
  let spec = try LayoutNotation.parse(line)
  let resolution = spec.resolve(windows)
  let tree = spec.tree(filling: resolution.windows, recent: windows.map(\.id), desktopSize: desktopSize)
  #expect(tree.invariantViolations().isEmpty, "\(line): \(tree.invariantViolations())")
  return (tree, resolution)
}

private let everyone = [
  window(101, "Safari"), window(102, "Mail"), window(103, "Notes"), window(104, "Xcode"), window(105, "Simulator"),
  window(106, "Terminal"), window(107, "Chrome"), window(108, "Slack"), window(109, "Safari"), window(110, "Safari"),
]

/// From text to a tree of windows and back (F54's acceptance criteria 1, 3, 4 and 5).
@Suite struct LayoutNotationTreeTests {
  // MARK: Building

  @Test func theExamplesOfTheSpecBuildTheExpectedTrees() throws {
    #expect(try shape(build("Safari | Desktop | (Mail / Notes)", everyone).tree) == "h(101 D v(102 103))")
    // The Desktop is not mentioned: it is added at the right, half as wide as the average space.
    #expect(try shape(build("Xcode:2 | (Simulator / Terminal)", everyone).tree) == "h(104*2.667 v(105 106)*1.333 D)")
    #expect(try shape(build("[Safari Chrome] | Slack", everyone).tree) == "h([101! 107]*2.0 108*2.0 D)")
  }

  @Test func theDesktopIsAddedAtTheRight() throws {
    #expect(try shape(build("Safari", everyone).tree) == "h(101*2.0 D)")
    #expect(try shape(build("Safari | Mail", everyone).tree) == "h(101*2.0 102*2.0 D)")
    #expect(try shape(build("Safari / Mail", everyone).tree) == "h(v(101 102)*2.0 D)")
    #expect(try shape(build("Safari | Mail", everyone, desktopSize: 1).tree) == "h(101 102 D)")
    #expect(try shape(build("Safari / Mail", everyone, desktopSize: 2).tree) == "h(v(101 102) D*2.0)")
  }

  @Test func onlyRatiosOfSizesMatterToTheDesktopThatIsAdded() throws {
    #expect(try shape(build("Safari:2 | Mail:2", everyone).tree) == shape(build("Safari | Mail", everyone).tree))
    #expect(try shape(build("Safari:30 | Mail:10", everyone).tree) == shape(build("Safari:3 | Mail", everyone).tree))
  }

  @Test(arguments: [Double.nan, -1, 0, .infinity, -.infinity, 1e300, 1e-300])
  func anOddDesktopSizeFromTheSettingsIsBounded(size: Double) throws {
    let tree = try build("Safari | Mail", everyone, desktopSize: size).tree
    let weight = try #require(tree[tree.desktop]?.weight)
    #expect(weight >= 0.05 && weight <= 20)
  }

  @Test func theDesktopGoesWhereItIsMentioned() throws {
    #expect(try shape(build("Desktop | Safari", everyone).tree) == "h(D 101)")
    #expect(try shape(build("Safari / Desktop:0.25", everyone).tree) == "v(101*4.0 D)")
    #expect(try shape(build("Safari | (Mail / Desktop / Notes)", everyone).tree) == "h(101 v(102 D 103))")
    #expect(try shape(build("Desktop", everyone).tree) == "D")
  }

  /// A group that comes to lie in a group of its own direction because the place of an app that is not open closed up. (Until
  /// brackets that are written were kept, these were the same lines without `/ Gone` and `| Gone`.)
  @Test func groupsOfTheSameDirectionJoinKeepingTheirShare() throws {
    #expect(try shape(build("((Safari | Mail) / Gone) | Notes | Desktop", everyone).tree) == "h(101 102 103*2.0 D*2.0)")
    #expect(try shape(build("((Safari | Mail) / Gone):2 | Notes | Desktop", everyone).tree) == "h(101 102 103 D)")
    #expect(try shape(build("((Safari:3 | Mail) / Gone):4 | Notes | Desktop", everyone).tree) == "h(101*3.0 102 103 D)")
    #expect(
      try shape(build("Desktop / ((Safari / ((Mail / ((Notes / Xcode) | Gone)) | Gone)) | Gone)", everyone).tree)
        == "v(D*8.0 101*4.0 102*2.0 103 104)")
    #expect(
      try build("((Safari | Mail) / Gone) | Notes", everyone).tree.notation { "\($0.rawValue)" }
        == "\"101\" | \"102\" | \"103\":2 | Desktop:0.667")
  }

  /// Brackets somebody wrote are kept, whichever way they run: a group to frame and to name, in the room it would have had.
  @Test func bracketsWrittenInTheDirectionOfTheGroupAroundThemStay() throws {
    #expect(try shape(build("(Safari | Mail) | Notes | Desktop", everyone).tree) == "h(h(101 102) 103 D)")
    #expect(try shape(build("(Safari | Mail):2 | Notes | Desktop", everyone).tree) == "h(h(101 102)*2.0 103 D)")
    #expect(try shape(build("(Safari:3 | Mail):4 | Notes | Desktop", everyone).tree) == "h(h(101*3.0 102)*4.0 103 D)")
    #expect(try shape(build("Desktop / (Safari / (Mail / (Notes / Xcode)))", everyone).tree) == "v(D v(101 v(102 v(103 104))))")
    // The Desktop that is added is as wide as without the brackets: a seventh here, as beside `Safari | Mail | Notes:2`.
    let tree = try build("(Safari | Mail) | Notes", everyone).tree
    #expect(tree.notation { "App\($0.rawValue)" } == "(App101 | App102) | App103 | Desktop:0.333")
    #expect(try shape(build("Safari | (Mail | (Notes | Xcode))", everyone).tree) == "h(101*4.0 h(102 h(103 104))*4.0 D)")
    // Marked as a group that was turned is, and only where that makes a difference.
    #expect(tree.kept(for: .turned).map { tree.windows(under: $0) } == [[WindowID(101), WindowID(102)]])
    #expect(try build("(Safari / Mail) | Notes", everyone).tree.kept(for: .turned).isEmpty)
    // One whose other members are not open is that member, as any group is.
    #expect(try shape(build("(Safari | Gone) | Notes | Desktop", everyone).tree) == "h(101 103 D)")
    #expect(try shape(build("((Safari | Mail) | Gone) | Notes | Desktop", everyone).tree) == "h(h(101 102) 103 D)")
    // Those inside a group that joins rise with it, and are still brackets. So are those whose row closed up round them.
    #expect(try shape(build("((Safari | (Mail | Xcode)) / Gone) | Notes | Desktop", everyone).tree) == "h(101 h(102 104) 103*2.0 D*2.0)")
    #expect(try shape(build("(((Safari | Mail) | Gone) / Gone) | Notes | Desktop", everyone).tree) == "h(h(101 102) 103 D)")
    // Across the group they end up in, they stand by themselves and need no mark.
    #expect(try build("((Safari | Mail) | Gone) / Notes", everyone).tree.kept(for: .turned).isEmpty)
  }

  // MARK: Several windows of one app

  @Test func twoWindowsOfOneAppArePlacedInTheOrderGiven() throws {
    #expect(try shape(build("Safari | Desktop | Safari", everyone).tree) == "h(101 D 109)")
    let recent = [window(110, "Safari"), window(101, "Safari"), window(109, "Safari")]
    #expect(try shape(build("Safari | Desktop | Safari", recent).tree) == "h(110 D 101)")
  }

  @Test func aStarCollectsTheRestAsTabs() throws {
    #expect(try shape(build("Safari | Desktop | Safari*", everyone).tree) == "h(101 D [109! 110])")
    #expect(try shape(build("Safari* | Desktop", everyone).tree) == "h([101! 109 110] D)")
    #expect(try shape(build("[Mail Safari*] | Desktop", everyone).tree) == "h([102 101! 109 110] D)")
    #expect(try shape(build("Mail* | Desktop", everyone).tree) == "h(102 D)")
  }

  @Test func aTabGroupShowsItsMostRecentWindow() throws {
    let recent = [window(3, "C"), window(1, "A"), window(2, "B")]
    #expect(try shape(build("[A B C] | Desktop", recent).tree) == "h([1 2 3!] D)")
    let spec = try LayoutNotation.parse("[A B C] | Desktop")
    // Without knowing, the first.
    #expect(shape(spec.tree(filling: spec.resolve(recent).windows)) == "h([1! 2 3] D)")
  }

  @Test func windowsCanBeNamedByNumber() throws {
    #expect(try shape(build("110 | Desktop | [103 w101]", everyone).tree) == "h(110 D [103 101!])")
  }

  // MARK: What is missing

  @Test func missingAppsAreReportedAndTheirSlotsClosedUp() throws {
    let some = [window(1, "Safari"), window(2, "Notes")]
    var (tree, resolution) = try build("Safari | Desktop | (Mail / Notes)", some)
    #expect(shape(tree) == "h(1 D 2)")
    #expect(resolution.missing == [.app("Mail")])
    #expect(resolution.short.isEmpty)
    #expect(resolution.allWindows == [WindowID(1), WindowID(2)])

    (tree, resolution) = try build("(Mail / Slack) | Safari | Desktop | [Xcode Zed]", some)
    #expect(shape(tree) == "h(1 D)")
    #expect(resolution.missing == [.app("Mail"), .app("Slack"), .app("Xcode"), .app("Zed")])

    (tree, resolution) = try build("Mail | (Slack / (Xcode | Zed))", some)
    #expect(shape(tree) == "D")
    #expect(resolution.allWindows.isEmpty)
  }

  @Test func aGroupLeftWithOneMemberTakesTheGroupsSize() throws {
    let some = [window(1, "Safari"), window(2, "Notes")]
    #expect(try shape(build("Safari | (Mail / Notes:7):3 | Desktop", some).tree) == "h(1 2*3.0 D)")
  }

  @Test func closingUpCanBringGroupsOfOneDirectionTogether() throws {
    // Without Mail, the column is gone and the row inside it joins the row outside.
    let some = [window(1, "A"), window(2, "B"), window(3, "C")]
    #expect(try shape(build("A | (Mail / (B | C)) | Desktop", some).tree) == "h(1*2.0 2 3 D*2.0)")
  }

  @Test func anAppAskedForMoreWindowsThanItHasIsShort() throws {
    let some = [window(1, "Safari"), window(2, "Mail")]
    let (tree, resolution) = try build("Safari | safari | Mail | Desktop | SAFARI", some)
    #expect(shape(tree) == "h(1 2 D)")
    #expect(resolution.missing.isEmpty)
    #expect(resolution.short == [.init(app: "Safari", found: 1)])
  }

  @Test func aStarIsContentWithNothingIfTheAppHasAWindowSomewhere() throws {
    let some = [window(1, "Safari")]
    #expect(try build("Safari | Safari*", some).resolution.short.isEmpty)
    #expect(try build("Safari | Safari*", some).resolution.missing.isEmpty)
    #expect(try build("Mail*", some).resolution.missing == [.app("Mail")])
  }

  @Test func missingThingsAreReportedOnce() throws {
    // An app can be written as often as it has windows; a number only once, which the parser sees to.
    let resolution = try build("Mail | mail | [Mail MAIL*] | 7 | 8", []).resolution
    #expect(resolution.missing == [.app("Mail"), .window(WindowID(7)), .window(WindowID(8))])
    #expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parse("7 | 7") }
    // Nor is a number reported twice that reaches an arrangement twice by another road than the parser.
    let seven = LayoutNotation.Space(.windows([.window(WindowID(7))]))
    let twice = LayoutNotation.Spec(root: .init(.group(.horizontal, [.init(.windows([.app("Mail")])), seven, seven])))
    #expect(twice.resolve([]).missing == [.app("Mail"), .window(WindowID(7))])
  }

  /// "Every value can be written as text and read back as the same value": also one that was given a window twice.
  @Test func anArrangementGivenAWindowTwiceHoldsItOnce() throws {
    func window(_ id: UInt32) -> LayoutNotation.Space { .init(.windows([.window(WindowID(id))])) }
    let flat = LayoutNotation.Spec(root: .init(.group(.horizontal, [window(7), window(7)])))
    #expect(flat.text == "7")
    let tabs = LayoutNotation.Space(.windows([.window(WindowID(9)), .window(WindowID(8)), .window(WindowID(9))]))
    let deep = LayoutNotation.Spec(root: .init(.group(.horizontal, [window(7), .init(.group(.vertical, [window(8), window(7)])), tabs])))
    #expect(deep.text == "7 | 8 | 9")
    for spec in [flat, deep] {
      #expect(try LayoutNotation.parse(spec.text) == spec)
      #expect(try JSONDecoder().decode(LayoutNotation.Spec.self, from: JSONEncoder().encode(spec)) == spec)
    }
  }

  @Test func aCallerThatListsNonsenseStillGetsAValidTree() throws {
    let spec = try LayoutNotation.parse("A | (B / C) | [D E]")
    let w = (1...5).map { WindowID(UInt32($0)) }
    for windows: [[WindowID]] in [
      [], [[w[0]]], [[w[0]], [w[0]], [w[0]], [w[0]], [w[0]]], [[w[0], w[0], w[1]], [w[1]], [], [w[0]], [w[2]], [w[3]], [w[4]]],
      [[], [], [], [], [], [w[0]]],
    ] {
      let tree = spec.tree(filling: windows)
      #expect(tree.invariantViolations().isEmpty, "\(windows)")
    }
  }

  // MARK: Ids

  @Test func nodeIDsDependOnlyOnTheText() throws {
    let spec = try LayoutNotation.parse("Safari | (Mail / Notes) | [Xcode Slack]")
    let all = spec.tree(filling: spec.resolve(everyone).windows)
    // Any subset of the windows gives the nodes it has in common with the full tree the same ids.
    for mask in 0..<32 {
      let some = [101, 102, 103, 104, 108].enumerated().filter { mask >> $0.offset & 1 == 1 }.map { id in everyone.first { $0.id.rawValue == UInt32(id.element) }! }
      let tree = spec.tree(filling: spec.resolve(some).windows)
      #expect(tree.invariantViolations().isEmpty)
      #expect(tree.desktop == all.desktop)
      for window in some { #expect(tree.leaf(containing: window.id) == all.leaf(containing: window.id), "\(mask) \(window.id)") }
      for id in tree.preorder() where tree.isSplit(id) && all.contains(id) {
        guard case .split(let axis, _) = tree[id]!.kind, case .split(let fullAxis, _) = all[id]!.kind else {
          Issue.record("\(id) is a split in one tree only")
          continue
        }
        #expect(axis == fullAxis)
      }
    }
  }

  @Test func theNodeOfEachSlotIsWhereTheTreePutsItsWindow() throws {
    for line in ["Safari", "Safari | (Mail / Notes) | [Xcode Slack]", "Desktop | (Safari / (Mail | [Notes Xcode*])):2 | Slack", "(Safari | Mail) | Notes", "((Safari))"] {
      let spec = try LayoutNotation.parse(line)
      let windows = spec.resolve(everyone).windows
      let tree = spec.tree(filling: windows)
      #expect(spec.nodeOfEachSlot.count == spec.slots.count)
      for (node, got) in zip(spec.nodeOfEachSlot, windows) {
        for window in got { #expect(tree.leaf(containing: window) == node, "\(line) \(window)") }
      }
    }
  }

  @Test func appliedAgainWindowsStayWhereTheyAre() throws {
    let spec = try LayoutNotation.parse("Safari | Mail | [Safari Safari]")
    let first = spec.resolve(everyone)
    let tree = spec.tree(filling: first.windows)
    // Whichever was used since.
    for order in [everyone.reversed(), everyone.shuffled(), everyone] {
      #expect(spec.resolve(Array(order), current: tree) == first)
    }
    // Another line's tree says nothing about this one's places.
    let other = try LayoutNotation.parse("Mail | Safari").tree(filling: [[WindowID(102)], [WindowID(110)]])
    #expect(spec.resolve(everyone, current: other) == first)
  }

  @Test func anAppWhoseOnlyWindowWentToAnotherSlotIsShortNotMissing() throws {
    let some = [window(1, "Safari"), window(2, "Mail")]
    let resolution = try build("1 | Safari | Mail", some).resolution
    #expect(resolution.missing.isEmpty)
    #expect(resolution.short == [.init(app: "Safari", found: 1)])
    #expect(try build("1 | Safari*", some).resolution.short == [.init(app: "Safari", found: 1)])
  }

  // MARK: Counterparts

  @Test func spacesThatHoldTheSameWindowsStandForEachOther() throws {
    let old = try build("Safari | (Mail / Notes) | Desktop", everyone).tree
    let new = try build("(Mail / Notes):3 | Xcode | Safari:2", everyone).tree
    let map = old.counterparts(in: new)
    func leaf(_ id: UInt32, _ tree: LayoutTree) -> NodeID { tree.leaf(containing: WindowID(id))! }
    #expect(map[old.root] == new.root)
    #expect(map[old.desktop] == new.desktop)
    #expect(map[leaf(101, old)] == leaf(101, new))
    #expect(map[leaf(102, old)] == leaf(102, new))
    #expect(map[old.parent(of: leaf(102, old))!] == new.parent(of: leaf(102, new))!)
    #expect(map.count == old.nodes.count)
  }

  @Test func spacesWhoseWindowsAreNoLongerTogetherHaveNone() throws {
    let old = try build("Safari | (Mail / Notes) | [Xcode Slack]", everyone).tree
    let new = try build("Safari | Mail | Notes | Xcode", everyone).tree
    let map = old.counterparts(in: new)
    #expect(map[old.parent(of: old.leaf(containing: WindowID(102))!)!] == nil)
    #expect(map[old.leaf(containing: WindowID(104))!] == nil)
    #expect(map[old.leaf(containing: WindowID(101))!] == new.leaf(containing: WindowID(101)))
    // Ids that happen to exist in both trees mean nothing.
    for (from, to) in map where from != old.root {
      #expect(Set(old.windows(under: from)) == Set(new.windows(under: to)))
    }
    #expect(LayoutTree().counterparts(in: new) == [NodeID(0): new.root])
  }

  @Test func docksAfterwardsGetFreshIDs() throws {
    var tree = try build("Safari | (Mail / Notes)", Array(everyone.prefix(1))).tree
    let before = Set(tree.nodes.keys)
    let full = try build("Safari | (Mail / Notes)", everyone).tree
    let leaf = tree.dock(WindowID(900), beside: tree.root, edge: .top)
    #expect(!before.contains(leaf))
    #expect(!full.contains(leaf), "a later rebuild would take \(leaf) for another node")
    #expect(tree.invariantViolations().isEmpty)
  }

  // MARK: Reading a tree back

  @Test func aTreeIsWrittenWithTheNamesGiven() throws {
    var tree = LayoutTree()
    let safari = tree.dock(WindowID(1), beside: tree.desktop, edge: .left)
    let mail = tree.dock(WindowID(2), beside: tree.desktop, edge: .right)
    tree.dock(WindowID(3), beside: mail, edge: .bottom)
    tree.addToStack(WindowID(4), leaf: safari)
    let names: [UInt32: String] = [1: "Safari", 2: "Mail", 3: "Visual Studio Code", 4: "Chrome"]
    #expect(tree.notation { names[$0.rawValue]! } == "[Safari Chrome]:2 | Desktop | (Mail / \"Visual Studio Code\")")
    #expect(LayoutTree().notation { _ in "x" } == "Desktop")
  }

  @Test func sizesAreWrittenRelativeToTheSmallestWindowOrGroup() throws {
    func written(_ line: String) throws -> String {
      try build(line, everyone).tree.notation { id in everyone.first { $0.id == id }!.appName }
    }
    #expect(try written("Safari:2 | Mail | Desktop:0.5") == "Safari:2 | Mail | Desktop:0.5")
    #expect(try written("Safari:4 | Mail:2 | Desktop") == "Safari:2 | Mail | Desktop:0.5")
    #expect(try written("Safari:0.5 | Mail | Desktop:3") == "Safari | Mail:2 | Desktop:6")
    #expect(try written("Safari | Mail") == "Safari | Mail | Desktop:0.5")
    #expect(try written("Safari | (Mail:3 / Notes:2):1.5 | Desktop") == "Safari | (Mail:1.5 / Notes):1.5 | Desktop")
  }

  @Test func sharesTooLopsidedToWriteAreBounded() throws {
    var tree = LayoutTree()
    let a = tree.dock(WindowID(1), beside: tree.desktop, edge: .left)
    let b = tree.dock(WindowID(2), beside: a, edge: .right)
    tree.moveBoundary(leading: a, trailing: b, by: 1e9, pointsPerWeight: 1e6, minimumPoints: 1e-3)
    let line = tree.notation { "\($0)" }
    #expect(line == "\"w1\":1000 | \"w2\" | Desktop:1000")
    #expect(throws: Never.self) { try LayoutNotation.parse(line) }
  }

  // MARK: Round trips

  /// A tree grown the way people grow them: docking, tabbing, closing, dragging gaps.
  static func randomTree(_ random: inout NotationRandom) -> LayoutTree {
    var tree = LayoutTree()
    var next: UInt32 = 1
    for _ in 0..<Int.random(in: 0...24, using: &random) {
      let nodes = tree.preorder()
      let target = nodes.randomElement(using: &random)!
      switch Int.random(in: 0..<10, using: &random) {
      case 0...4:
        tree.dock(WindowID(next), beside: target, edge: Edge.allCases.randomElement(using: &random)!)
        next += 1
      case 5 where tree.isStack(target):
        tree.addToStack(WindowID(next), leaf: target)
        next += 1
      case 6:
        if let window = tree.allWindows.randomElement(using: &random) { tree.remove(window) }
      case 7:
        if let window = tree.allWindows.randomElement(using: &random) { tree.activate(window) }
      default:
        let children = tree.children(of: target)
        guard children.count > 1 else { continue }
        let index = Int.random(in: 0..<(children.count - 1), using: &random)
        tree.moveBoundary(
          leading: children[index], trailing: children[index + 1], by: Double.random(in: -300...300, using: &random),
          pointsPerWeight: 400, minimumPoints: 40)
      }
    }
    return tree
  }

  /// Frames of every window and of the Desktop on a large display, with no tiles.
  static func frames(_ tree: LayoutTree) -> [String: CGRect] {
    let layout = LayoutEngine.layout(
      tree, camera: tree.root, in: CGRect(x: 0, y: 0, width: 3000, height: 2000),
      options: LayoutOptions(gap: 10, minimumUsableSize: .zero), isPresent: { _ in true })
    var frames: [String: CGRect] = [:]
    for (window, frame) in layout.windowFrames { frames["\(window)"] = frame }
    frames["desktop"] = layout.desktopFrame
    return frames
  }

  @Test func anyTreeComesBackFromItsLine() throws {
    var random = NotationRandom(seed: 540)
    for round in 0..<1500 {
      let tree = Self.randomTree(&random)
      #expect(tree.invariantViolations().isEmpty)
      // A share a thousand times its neighbour's cannot be written (`sharesTooLopsidedToWriteAreBounded`).
      let lopsided = tree.preorder().contains { id in
        let weights = tree.children(of: id).map { tree[$0]!.weight }
        return !weights.isEmpty && weights.max()! / weights.min()! > 999
      }
      if lopsided { continue }
      // Each window is its own app, so the line says exactly which window goes where.
      let line = tree.notation { "App\($0.rawValue)" }
      let windows = tree.allWindows.shuffled(using: &random).map { window($0.rawValue, "App\($0.rawValue)") }
      let spec = try LayoutNotation.parse(line)
      let resolution = spec.resolve(windows)
      #expect(resolution.missing.isEmpty && resolution.short.isEmpty)
      // What each tab group shows is not written; it is whichever window was used last.
      let shown = tree.preorder().compactMap { tree.activeWindow(of: $0) }
      let back = spec.tree(filling: resolution.windows, recent: shown)
      #expect(back.invariantViolations().isEmpty, "round \(round): \(line)")

      // The same windows in the same order and groups, showing the same tabs…
      #expect(back.allWindows == tree.allWindows, "round \(round): \(line)")
      #expect(back.preorder().compactMap { back.activeWindow(of: $0) } == shown, "round \(round): \(line)")
      #expect(back.preorder().map { back.depth(of: $0) } == tree.preorder().map { tree.depth(of: $0) }, "round \(round): \(line)")
      // …in the same places, give or take the third decimal of a size…
      let (before, after) = (Self.frames(tree), Self.frames(back))
      #expect(before.keys == after.keys)
      for (name, frame) in before {
        #expect(after[name]?.approximatelyEquals(frame, tolerance: 4) == true, "round \(round) \(name): \(line)")
      }
      // …and from then on the line does not change any more.
      #expect(back.notation { "App\($0.rawValue)" } == line, "round \(round)")
    }
  }

  @Test func aLineBuiltAndWrittenAgainIsStable() throws {
    var random = NotationRandom(seed: 99)
    for round in 0..<1500 {
      var desktopAllowed = true
      let spec = LayoutNotation.Spec(root: LayoutNotationTests.randomSpace(&random, depth: 0, desktopAllowed: &desktopAllowed))
      // Some slots find windows, some do not.
      var next: UInt32 = 1000
      let windows = spec.slots.map { slot -> [WindowID] in
        let count = Int.random(in: 0...(slot.takesAll ? 3 : 1), using: &random)
        return (0..<count).map { _ in
          next += 1
          return WindowID(next)
        }
      }
      let tree = spec.tree(filling: windows, desktopSize: [0.5, 1, 0.05, 20].randomElement(using: &random)!)
      #expect(tree.invariantViolations().isEmpty, "round \(round): \(spec)")
      #expect(tree.allWindows == windows.flatMap { $0 }, "round \(round): \(spec)")
      let line = tree.notation { "App\($0.rawValue)" }
      let again = try LayoutNotation.parse(line)
      let rebuilt = again.tree(filling: again.resolve(tree.allWindows.map { window($0.rawValue, "App\($0.rawValue)") }).windows)
      #expect(rebuilt.invariantViolations().isEmpty)
      #expect(rebuilt.notation { "App\($0.rawValue)" } == line, "round \(round): \(spec)")
    }
  }

  @Test func theDeepestLineThatParsesBuilds() throws {
    var line = "X"
    for level in 0..<LayoutNotation.maximumDepth { line = "(\(line):0.001 \(level % 2 == 0 ? "|" : "/") L\(level):1000)" }
    let spec = try LayoutNotation.parse(line)
    let windows = spec.slots.enumerated().map { [WindowID(UInt32($0.offset + 1))] }
    #expect(spec.tree(filling: windows).invariantViolations().isEmpty)
    // The same direction all the way down: brackets in brackets, each of them kept.
    var flat = "X"
    for level in 0..<LayoutNotation.maximumDepth { flat = "(\(flat):0.001 | L\(level):1000)" }
    let written = try LayoutNotation.parse(flat)
    let nested = written.tree(filling: written.slots.enumerated().map { [WindowID(UInt32($0.offset + 1))] })
    #expect(nested.invariantViolations().isEmpty)
    #expect(nested.kept(for: .turned).count == LayoutNotation.maximumDepth - 1)
    // With a place that closes up at every other level, everything joins one group, and no share vanishes.
    let levels = LayoutNotation.maximumDepth / 2
    flat = "X"
    for level in 0..<levels { flat = "((\(flat):0.001 | L\(level):1000) / Gone)" }
    let joined = try LayoutNotation.parse(flat)
    var next: UInt32 = 0
    let tree = joined.tree(
      filling: joined.slots.map { slot in
        next += 1
        return slot == .app("Gone") ? [] : [WindowID(next)]
      })
    #expect(tree.invariantViolations().isEmpty)
    #expect(tree.children(of: tree.root).count == levels + 2)
    let weights = tree.children(of: tree.root).map { tree[$0]!.weight }
    #expect(weights.min()! / weights.max()! >= 1e-6 * 0.999)
  }
}
