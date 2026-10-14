import ArborCore
import CoreGraphics
import Foundation
import Testing

private let display = CGRect(x: 0, y: 25, width: 1440, height: 875)
private func w(_ raw: UInt32) -> WindowID { WindowID(raw) }

/// Where a new window goes when nobody said where (docs/features/F23-automatic-docking.md).
@Suite struct AutoDockPlanTests {
  /// A workspace with `windows` docked one after the other by `dock`, and 900 floating.
  func workspace(_ dock: (inout Workspace) -> Void) -> Workspace {
    var workspace = Workspace()
    dock(&workspace)
    workspace.floating[w(900)] = CGRect(x: 300, y: 200, width: 640, height: 420)
    return workspace
  }

  func plan(
    _ workspace: Workspace, recent: [WindowID], tabs: Bool = false, minimums: [WindowID: CGSize] = [:],
    absent: Set<WindowID> = [], on frame: CGRect = display, emptyDesktopWeight: Double? = nil,
    makingRoom terms: MakeRoom.Terms? = nil
  ) -> AutoDock.Plan {
    AutoDock.plan(
      for: w(900), in: workspace, recent: recent, frame: frame, options: LayoutOptions(), tabsEnabled: tabs,
      isPresent: { !absent.contains($0) }, minimumSize: { minimums[$0] }, emptyDesktopWeight: emptyDesktopWeight,
      makingRoom: terms)
  }

  func target(_ plan: AutoDock.Plan) -> DropTarget? {
    if case .dock(let placement) = plan { placement.target } else { nil }
  }

  func leaf(_ window: UInt32, _ workspace: Workspace) -> NodeID { workspace.tree.leaf(containing: w(window))! }

  @Test func withNothingDockedItGoesToTheRightEdgeOfTheView() {
    let empty = workspace { _ in }
    guard case .dock(let placement) = plan(empty, recent: []) else {
      Issue.record("not docked")
      return
    }
    #expect(placement.target == .cameraEdge(.right))
    #expect(placement.slot == CGRect(x: 726, y: 37, width: 702, height: 851))
    #expect(placement.covers == nil)
  }

  @Test func theFirstWindowLeavesAnEmptyDesktopItsShare() {
    var empty = workspace { _ in }
    guard case .dock(let placement) = plan(empty, recent: [], emptyDesktopWeight: 0.5) else {
      Issue.record("not docked")
      return
    }
    #expect(placement.target == .cameraEdge(.right))
    #expect(placement.desktopWeight == 0.5)
    #expect(placement.slot == CGRect(x: 492, y: 37, width: 936, height: 851))
    placement.apply(to: &empty, docking: w(900))
    let tree = empty.tree
    #expect(abs(tree[tree.desktop]!.weight * 2 - tree[leaf(900, empty)]!.weight) < 1e-9)
    #expect(abs(tree[tree.desktop]!.weight + tree[leaf(900, empty)]!.weight - 2) < 1e-9)
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func onceSomethingIsDockedTheDesktopsShareIsLeftAlone() {
    let one = workspace { $0.dock(w(1), at: .cameraEdge(.right)) }
    for recent in [[w(1)], []] {
      guard case .dock(let placement) = plan(one, recent: recent, emptyDesktopWeight: 0.5) else {
        Issue.record("not docked")
        continue
      }
      #expect(placement.desktopWeight == nil)
    }
  }

  @Test func aPlacementOnTheLeadingSideSharesTheSameWay() {
    var empty = workspace { _ in }
    AutoDock.Placement(target: .cameraEdge(.left), desktopWeight: 0.25).apply(to: &empty, docking: w(900))
    let tree = empty.tree
    #expect(tree.children(of: tree.root) == [leaf(900, empty), tree.desktop])
    #expect(abs(tree[tree.desktop]!.weight * 4 - tree[leaf(900, empty)]!.weight) < 1e-9)
  }

  @Test func aTallSlotIsSplitBelowAndAWideOneToTheRight() {
    // Half the display: 702 x 851.
    let tall = workspace { $0.dock(w(1), at: .cameraEdge(.right)) }
    #expect(target(plan(tall, recent: [w(1)])) == .beside(leaf(1, tall), .bottom))
    // A quarter: 702 x 419 or so.
    let wide = workspace {
      $0.dock(w(1), at: .cameraEdge(.right))
      $0.dock(w(2), at: .beside($0.tree.leaf(containing: w(1))!, .bottom))
    }
    guard case .dock(let placement) = plan(wide, recent: [w(2), w(1)]) else {
      Issue.record("not docked")
      return
    }
    #expect(placement.target == .beside(leaf(2, wide), .right))
    #expect(placement.slot.width == 345)
    #expect(placement.slot.maxX == 1428)
  }

  @Test func aSquareSlotIsSplitToTheRight() {
    // Half of 1036 x 524, less the gaps: 500 x 500.
    let square = workspace { $0.dock(w(1), at: .cameraEdge(.right)) }
    let placed = plan(square, recent: [w(1)], on: CGRect(x: 0, y: 0, width: 1036, height: 524))
    #expect(target(placed) == .beside(leaf(1, square), .right))
  }

  @Test func theMostRecentWindowThatIsDockedAndShowingIsTheNeighbour() {
    var both = workspace {
      $0.dock(w(1), at: .cameraEdge(.left))
      $0.dock(w(2), at: .cameraEdge(.right))
    }
    // 7 floats, 8 is unknown, the new window itself already has the keyboard.
    both.floating[w(7)] = CGRect(x: 0, y: 100, width: 500, height: 400)
    #expect(target(plan(both, recent: [w(900), w(7), w(8), w(2), w(1)])) == .beside(leaf(2, both), .bottom))
    // 2 is minimized.
    #expect(target(plan(both, recent: [w(2), w(1)], absent: [w(2)])) == .beside(leaf(1, both), .bottom))
  }

  @Test func aNeighbourOutOfViewIsPassedOverAndTheViewStays() {
    var workspace = workspace {
      $0.dock(w(1), at: .cameraEdge(.left))
      $0.dock(w(2), at: .beside($0.tree.leaf(containing: w(1))!, .bottom))
      $0.dock(w(3), at: .cameraEdge(.right))
    }
    let group = workspace.tree.parent(of: leaf(1, workspace))!
    workspace.moveCamera(to: group)
    let placed = plan(workspace, recent: [w(3), w(2), w(1)])
    #expect(target(placed) == .beside(leaf(2, workspace), .right))
    var after = workspace
    after.dock(w(900), at: target(placed)!)
    #expect(after.camera == group)
  }

  @Test func atTheEdgeOfAViewTheWindowJoinsItAndNothingElseComesIntoView() {
    var workspace = workspace {
      $0.dock(w(1), at: .cameraEdge(.left))
      $0.dock(w(2), at: .beside($0.tree.leaf(containing: w(1))!, .bottom))
      $0.dock(w(3), at: .cameraEdge(.right))
    }
    let column = workspace.tree.parent(of: leaf(1, workspace))!
    workspace.moveCamera(to: column)
    // Nothing in view has had the keyboard.
    #expect(target(plan(workspace, recent: [w(3)])) == .cameraEdge(.right))
    workspace.dock(w(900), at: .cameraEdge(.right))
    #expect(Set(workspace.tree.windows(under: workspace.camera)) == [w(1), w(2), w(900)])
    #expect(!workspace.tree.subtree(workspace.camera, contains: workspace.tree.desktop))
  }

  @Test func aFramedWindowAndTheDesktopAloneAreLeftAsTheyAre() {
    var workspace = workspace {
      $0.dock(w(1), at: .cameraEdge(.left))
      $0.dock(w(2), at: .cameraEdge(.right))
    }
    workspace.moveCamera(to: leaf(1, workspace))
    #expect(plan(workspace, recent: [w(1)]) == .float(.framed))
    #expect(plan(workspace, recent: [w(1)], tabs: true) == .float(.framed))
    workspace.moveCamera(to: workspace.tree.desktop)
    #expect(plan(workspace, recent: [w(1)]) == .float(.onTheDesktop))
  }

  /// A quarter of the display cut in four: 345 x 203 or so, which halves to less than 240 x 160 both ways.
  func crowded() -> Workspace {
    workspace {
      $0.dock(w(1), at: .cameraEdge(.right))
      $0.dock(w(2), at: .beside($0.tree.leaf(containing: w(1))!, .bottom))
      $0.dock(w(3), at: .beside($0.tree.leaf(containing: w(2))!, .right))
      $0.dock(w(4), at: .beside($0.tree.leaf(containing: w(3))!, .bottom))
    }
  }

  @Test func whenTheNeighbourIsTooSmallToShareTheLargestWindowDoes() {
    let crowded = crowded()
    #expect(target(plan(crowded, recent: [w(4)])) == .beside(leaf(1, crowded), .right))
  }

  @Test func withTabsOnATabComesBeforeAPlaceFurtherAway() {
    let crowded = crowded()
    guard case .dock(let placement) = plan(crowded, recent: [w(4)], tabs: true) else {
      Issue.record("not docked")
      return
    }
    #expect(placement.target == .stack(leaf(4, crowded)))
    #expect(placement.covers == w(4))
  }

  @Test func withNoRoomAnywhereItFloats() {
    // Every window insists on the size it has.
    let crowded = crowded()
    var fixed = Dictionary(uniqueKeysWithValues: (2...4).map { (w($0), CGSize(width: 340, height: 200)) })
    fixed[w(1)] = CGSize(width: 700, height: 400)
    #expect(plan(crowded, recent: [w(4)], minimums: fixed) == .float(.noRoom))
  }

  @Test func aNeighbourKnownNotToShrinkThatFarIsSplitTheOtherWay() {
    // 1416 x 419 or so: wide, so to the right first. But 1 is Safari-like and will not go below 800.
    let rows = workspace {
      $0.dock(w(1), at: .cameraEdge(.top))
    }
    #expect(target(plan(rows, recent: [w(1)])) == .beside(leaf(1, rows), .right))
    #expect(
      target(plan(rows, recent: [w(1)], minimums: [w(1): CGSize(width: 800, height: 0)]))
        == .beside(leaf(1, rows), .bottom))
  }

  @Test func aTallNeighbourKnownNotToGetThatShortIsSplitToTheRight() {
    let tall = workspace { $0.dock(w(1), at: .cameraEdge(.right)) }
    #expect(
      target(plan(tall, recent: [w(1)], minimums: [w(1): CGSize(width: 0, height: 500)]))
        == .beside(leaf(1, tall), .right))
  }

  @Test func whenTheNeighbourIsTheLargestAndCannotShareTheNextLargestDoes() {
    let halves = workspace {
      $0.dock(w(1), at: .cameraEdge(.right))
      $0.dock(w(2), at: .beside($0.tree.leaf(containing: w(1))!, .bottom))
    }
    #expect(
      target(plan(halves, recent: [w(1)], minimums: [w(1): CGSize(width: 700, height: 400)]))
        == .beside(leaf(2, halves), .right))
  }

  @Test func ofWindowsOfTheSameSizeTheFirstShares() {
    // 1, 5 and 2 are 345 x 419 or so; 3 and 4 half as tall, too small to share.
    var crowded = crowded()
    crowded.dock(w(5), at: .beside(leaf(1, crowded), .right))
    #expect(target(plan(crowded, recent: [w(4)])) == .beside(leaf(1, crowded), .bottom))
  }

  @Test func whereRoomWillBeMadeThePlanReckonsWithIt() {
    // 1416 x 419 or so. Half is 702, and the new window is known to stop at 800.
    let rows = workspace { $0.dock(w(1), at: .cameraEdge(.top)) }
    let minimums = [w(900): CGSize(width: 800, height: 0)]
    #expect(target(plan(rows, recent: [w(1)], minimums: minimums)) == .beside(leaf(1, rows), .bottom))
    guard
      case .dock(let placement) = plan(
        rows, recent: [w(1)], minimums: minimums, makingRoom: MakeRoom.Terms(desktopIsInUse: false))
    else {
      Issue.record("not docked")
      return
    }
    #expect(placement.target == .beside(leaf(1, rows), .right))
    #expect(placement.slot.width >= 800 && placement.slot.maxX == 1428)
  }

  @Test func onlyAnEmptyDesktopMayBecomeATile() {
    // Half the display each. Both windows stop at 640 points, so side by side they leave the Desktop 112.
    let half = workspace { $0.dock(w(1), at: .cameraEdge(.right)) }
    let minimums = [w(1): CGSize(width: 640, height: 600), w(900): CGSize(width: 640, height: 600)]
    let empty = MakeRoom.Terms(desktopIsInUse: false)
    let inUse = MakeRoom.Terms(desktopIsInUse: true)
    #expect(AutoDock.desktopMayBecomeATile(on: empty, options: LayoutOptions()))
    #expect(!AutoDock.desktopMayBecomeATile(on: inUse, options: LayoutOptions()))
    #expect(target(plan(half, recent: [w(1)], minimums: minimums, makingRoom: empty)) == .beside(leaf(1, half), .right))
    #expect(plan(half, recent: [w(1)], minimums: minimums, makingRoom: inUse) == .float(.noRoom))
    #expect(plan(half, recent: [w(1)], minimums: minimums) == .float(.noRoom))
  }

  @Test func theNewWindowsOwnMinimumCountsOnceItIsKnown() {
    let rows = workspace { $0.dock(w(1), at: .cameraEdge(.top)) }
    #expect(
      target(plan(rows, recent: [w(1)], minimums: [w(900): CGSize(width: 800, height: 0)]))
        == .beside(leaf(1, rows), .bottom))
    #expect(plan(rows, recent: [w(1)], minimums: [w(900): CGSize(width: 800, height: 300)]) == .float(.noRoom))
  }

  @Test func theDesktopIsNotSqueezedIntoATile() {
    // The Desktop is 300 points wide. A window at the right edge of the row would take a share of it.
    var narrow = workspace { $0.dock(w(1), at: .cameraEdge(.right)) }
    narrow.tree.moveBoundary(
      leading: narrow.tree.desktop, trailing: leaf(1, narrow), by: -402, pointsPerWeight: 702)
    #expect(target(plan(narrow, recent: [])) == .cameraEdge(.bottom))
  }

  @Test func tilesThatWereThereBeforeDoNotCount() {
    // 2 is a tile already, because its app insists on more than its slot.
    let workspace = workspace {
      $0.dock(w(1), at: .cameraEdge(.right))
      $0.dock(w(2), at: .cameraEdge(.left))
    }
    let minimums = [w(2): CGSize(width: 900, height: 0)]
    #expect(target(plan(workspace, recent: [w(2), w(1)], minimums: minimums)) == .beside(leaf(1, workspace), .bottom))
  }

  @Test func everyPlanLeavesAValidTree() {
    for recent in [[], [w(4)], [w(1)]] {
      var workspace = crowded()
      guard let target = target(plan(workspace, recent: recent)) else { continue }
      workspace.dock(w(900), at: target)
      #expect(workspace.tree.invariantViolations().isEmpty)
      #expect(!workspace.isFloating(w(900)))
    }
  }
}

@Suite struct AutoDockRuleTests {
  let minimum = CGSize(width: 400, height: 300)

  @Test func smallAndFixedWindowsAreNotWorthAPlace() {
    #expect(AutoDock.accepts(size: CGSize(width: 400, height: 300), isResizable: true, minimum: minimum))
    #expect(!AutoDock.accepts(size: CGSize(width: 399, height: 900), isResizable: true, minimum: minimum))
    #expect(!AutoDock.accepts(size: CGSize(width: 900, height: 299), isResizable: true, minimum: minimum))
    #expect(!AutoDock.accepts(size: CGSize(width: 900, height: 900), isResizable: false, minimum: minimum))
  }

  @Test func dockAutoIsAnActionLikeTheOthers() throws {
    #expect(try RuleAction(text: "dock auto") == .dockAuto)
    #expect(try RuleAction(text: " Dock  AUTO ") == .dockAuto)
    #expect(RuleAction.dockAuto.text == "dock auto")
    #expect(try RuleAction(text: "dock right") == .dock(.right))
    #expect(throws: RuleAction.ParseError.self) { try RuleAction(text: "dock auto left") }
    let rule = try JSONDecoder().decode(AppRule.self, from: Data(#"{"app": "*", "action": "dock auto"}"#.utf8))
    #expect(rule == .dockEveryNewWindow)
    #expect(rule.description == "any app → dock auto")
    #expect(try JSONDecoder().decode(AppRule.self, from: JSONEncoder().encode(rule)) == rule)
  }

  @Test func aStarStandsForTheRestOfTheBundleID() {
    let any = AppRule(app: "*", action: .float)
    #expect(any.covers(bundleID: "com.apple.Safari"))
    #expect(any.covers(bundleID: nil))
    let family = AppRule(app: "com.jetbrains.*", action: .float)
    #expect(family.covers(bundleID: "com.jetbrains.intellij"))
    #expect(!family.covers(bundleID: "com.jetbrains"))
    #expect(!family.covers(bundleID: "org.jetbrains.intellij"))
    #expect(!family.covers(bundleID: nil))
    let exact = AppRule(app: "com.apple.Safari", action: .float)
    #expect(exact.covers(bundleID: "com.apple.Safari"))
    #expect(!exact.covers(bundleID: "com.apple.SafariTechnologyPreview"))
    #expect(!exact.covers(bundleID: nil))
    #expect(AppRule(app: "*", title: "inbox", action: .float).matches(bundleID: "a.b", title: "Inbox (3)"))
    #expect(!AppRule(app: "*", title: "inbox", action: .float).matches(bundleID: "a.b", title: "Sent"))
  }

  @Test func onlyRulesThatDockWindowsNobodyNamedAreCautious() {
    #expect(AppRule(app: "*", action: .dockAuto).isCautious)
    #expect(AppRule(app: "com.apple.Safari", action: .dockAuto).isCautious)
    #expect(AppRule(app: "*", action: .dock(.right)).isCautious)
    #expect(AppRule(app: "com.apple.*", action: .dockBeside(bundleID: "a.b", .left)).isCautious)
    #expect(!AppRule(app: "com.apple.calculator", action: .dock(.right)).isCautious)
    #expect(!AppRule(app: "*", action: .float).isCautious)
    #expect(!AppRule(app: "*", action: .ignore).isCautious)
  }

  @Test func aCautiousRulePassesOverWindowsThatAreNotWorthAPlace() {
    func matches(_ rule: AppRule, _ size: CGSize, resizable: Bool = true) -> Bool {
      rule.matches(bundleID: "a.b", title: "", openingSize: size, isResizable: resizable, minimum: minimum)
    }
    let small = CGSize(width: 260, height: 500)
    let large = CGSize(width: 800, height: 600)
    #expect(matches(.dockEveryNewWindow, large))
    #expect(!matches(.dockEveryNewWindow, small))
    #expect(!matches(.dockEveryNewWindow, large, resizable: false))
    #expect(matches(AppRule(app: "a.b", action: .dock(.left)), small, resizable: false))
    #expect(matches(AppRule(app: "*", action: .ignore), small, resizable: false))
  }
}

@Suite struct AutoDockSettingsTests {
  func decode(_ json: String) throws -> Settings { try JSONDecoder().decode(Settings.self, from: Data(json.utf8)) }

  @Test func newWindowsFloatUnlessTheSettingSaysDock() throws {
    #expect(Settings().newWindows == "float")
    #expect(!Settings().docksNewWindows)
    #expect(Settings().newWindowRules.isEmpty)
    #expect(Settings().autoDockMinimumSize == CGSize(width: 400, height: 300))
    // A file from before the setting existed.
    #expect(try !decode(#"{"gap": 8}"#).docksNewWindows)
    #expect(try decode(#"{"newWindows": "dock"}"#).docksNewWindows)
    // A value Arbor does not know must not cost the rest of the file.
    let odd = try decode(#"{"newWindows": "tile", "gap": 8}"#)
    #expect(!odd.docksNewWindows)
    #expect(odd.gap == 8)
  }

  @Test func theSettingStandsForALastRule() throws {
    let settings = try decode(
      #"{"newWindows": "dock", "autoDockMinimumWidth": 500, "rules": [{"app": "a.b", "action": "float"}]}"#)
    #expect(settings.rules == [AppRule(app: "a.b", action: .float)])
    #expect(settings.newWindowRules == [AppRule(app: "a.b", action: .float), AppRule(app: "*", action: .dockAuto)])
    #expect(settings.autoDockMinimumSize == CGSize(width: 500, height: 300))
    #expect(try decode(String(decoding: JSONEncoder().encode(settings), as: UTF8.self)) == settings)
  }

  @Test func switchingItChangesOneKeyOfTheFile() throws {
    let text = """
      {
        "gap": 8
      }
      """
    var updated = try Settings.read(text)
    let old = updated
    updated.newWindows = "dock"
    let written = try Settings.rewrite(text, from: old, to: updated)
    #expect(try Settings.read(written).docksNewWindows)
    #expect(written.contains("\"gap\": 8"))
    #expect(!written.contains("autoDockMinimumWidth"))
    #expect(try Settings.rewrite(written, from: updated, to: old).contains("\"newWindows\": \"float\""))
  }

  @Test func theCommandHasATextFormAndIsNotForURLs() throws {
    #expect(try Command.parse("toggle-auto-dock") == .toggleAutoDock)
    #expect(Command.toggleAutoDock.text == "toggle-auto-dock")
    #expect(throws: Command.ParseError.self) { try Command.parse("toggle-auto-dock now") }
    #expect(!Command.toggleAutoDock.isAllowedFromURL)
    #expect(!Command.toggleAutoDock.isQuery)
    #expect(Command.helpText.contains("toggle-auto-dock"))
  }
}
