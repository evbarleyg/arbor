import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1080), isMain: false)

/// Where apps put their new windows in these tests.
private let opening = CGRect(x: 300, y: 200, width: 640, height: 420)

@MainActor private func harness(
  newWindows: String = "dock", rules: [AppRule] = [], displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay],
  saved: PersistedState? = nil, desktopColumn: Bool = false, configure: (inout Settings) -> Void = { _ in }
) -> Harness {
  var settings = desktopColumn ? Settings.withDesktopColumn : Settings()
  settings.newWindows = newWindows
  settings.rules = rules
  // With a column for the Desktop the first window takes half of the display, which makes for round numbers. "The Desktop's
  // share" has the default. Without, as Arbor ships, the first window fills the display and the second takes half of it.
  settings.arrangeDesktopWeight = 1
  // What automatic docking does when there is no room is seen best while nobody makes any. "With room made" has the default.
  settings.makeRoom = false
  configure(&settings)
  return Harness(displays: displays, settings: settings, saved: saved)
}

extension Harness {
  /// Opens a window the way macOS does: it appears, and it has the keyboard.
  @discardableResult
  fileprivate func open(
    _ app: String, bundleID: String? = nil, title: String? = nil, frame: CGRect = opening,
    minimumSize: CGSize = .zero, isResizable: Bool = true
  ) -> WindowID {
    let id = system.open(
      app: app, bundleID: bundleID, title: title, frame: frame, minimumSize: minimumSize, isResizable: isResizable)
    system.userFocus(id)
    return id
  }

  /// Opens a window that does not get the keyboard: its app is in the background, or macOS has not said yet.
  @discardableResult
  fileprivate func openQuietly(_ app: String, title: String? = nil, frame: CGRect = opening) -> WindowID {
    let echoes = system.echoes
    system.echoes.keyboard = false
    defer { system.echoes = echoes }
    return system.open(app: app, title: title, frame: frame)
  }

  fileprivate func isDocked(_ window: WindowID) -> Bool { controller.workspaces.values.contains { $0.isDocked(window) } }
  fileprivate func isFloating(_ window: WindowID) -> Bool {
    controller.workspaces.values.contains { $0.isFloating(window) }
  }
  fileprivate func slot(_ window: WindowID) -> CGRect? { layout?.windowFrames[window] }
  /// The slot of a window that is expected to have one.
  fileprivate func rect(_ window: WindowID, sourceLocation: SourceLocation = #_sourceLocation) -> CGRect {
    for layout in controller.layouts.values {
      if let frame = layout.windowFrames[window] { return frame }
    }
    Issue.record("\(window) is not docked and showing", sourceLocation: sourceLocation)
    return .zero
  }
  /// The split a docked window is a child of.
  fileprivate func group(of window: WindowID) -> NodeID? {
    for workspace in controller.workspaces.values {
      if let leaf = workspace.tree.leaf(containing: window) { return workspace.tree.parent(of: leaf) }
    }
    return nil
  }
  fileprivate func moved(_ window: WindowID) -> [CGRect] { system.frameLog.filter { $0.window == window }.map(\.frame) }

  /// Every docked window is where the layout says, nothing is a tile, and the tree is sound.
  fileprivate func expectAllInPlace(sourceLocation: SourceLocation = #_sourceLocation) {
    for (display, layout) in controller.layouts {
      #expect(layout.tiles.isEmpty, "tiles on \(display)", sourceLocation: sourceLocation)
      for (window, frame) in layout.windowFrames {
        // To the point: a slot that room was made for is a point larger than its window asked for.
        #expect(self.frame(window)?.approximatelyEquals(frame, tolerance: 1) == true, "\(window)", sourceLocation: sourceLocation)
      }
      #expect(controller.workspaces[display]?.tree.invariantViolations() == [], sourceLocation: sourceLocation)
    }
  }
}

/// Scenario tests for automatic docking (docs/features/F23-automatic-docking.md), by acceptance criterion.
@Suite @MainActor struct AutomaticDockingTests {
  // MARK: 1. Off by default

  @Test func byDefaultANewWindowFloatsWhereItsAppPutIt() {
    let h = Harness()
    h.start()
    let a = h.open("Safari")
    h.run("dock \(a.rawValue) left")
    h.system.clearFrameLog()
    let b = h.open("Notes")
    #expect(h.isFloating(b))
    #expect(h.frame(b) == opening)
    #expect(h.system.frameLog.isEmpty)
  }

  @Test func anUnknownValueMeansFloatAndTheReportSaysSo() {
    let h = harness(newWindows: "tile")
    h.start()
    #expect(h.isFloating(h.open("Safari")))
    #expect(h.run("rules").text?.contains("\"newWindows\" must be \"float\" or \"dock\"") == true)
  }

  // MARK: 2. Beside the focused window

  @Test func aNewWindowTakesTheLowerHalfOfATallFocusedWindow() throws {
    let h = harness(newWindows: "float")
    h.start()
    let (a, b) = (h.open("Safari"), h.open("Mail"))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("toggle-auto-dock")
    h.system.userFocus(a)
    let (slotA, slotB) = (h.rect(a), h.rect(b))
    h.system.clearFrameLog()

    let n = h.open("Notes")
    let (upper, lower) = (h.rect(a), h.rect(n))
    #expect(upper.minY == slotA.minY && lower.maxY == slotA.maxY)
    #expect(upper.minX == slotA.minX && upper.width == slotA.width && lower.minX == slotA.minX && lower.width == slotA.width)
    #expect(lower.minY - upper.maxY == 12)
    #expect(abs(upper.height - lower.height) <= 1)
    #expect(h.slot(b) == slotB)
    #expect(h.moved(b).isEmpty, "a window that gives up nothing is not touched")
    #expect(h.moved(n) == [lower], "one move takes it to its slot")
    #expect(h.workspace.camera == h.workspace.tree.root)
    h.expectAllInPlace()
  }

  @Test func aNewWindowTakesTheRightHalfOfAWideFocusedWindow() throws {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    h.open("Calendar")  // the right half of the display
    let b = h.open("Mail")  // below it
    let slotB = h.rect(b)
    #expect(slotB.width > slotB.height)
    let n = h.open("Notes")
    let (left, right) = (h.rect(b), h.rect(n))
    #expect(left.minX == slotB.minX && right.maxX == slotB.maxX && right.minX - left.maxX == 12)
    #expect(left.height == slotB.height && right.height == slotB.height)
    #expect(h.slot(a) != nil)
    h.expectAllInPlace()
  }

  @Test func theWindowThatHadTheKeyboardLastCountsAlthoughTheNewOneHasItAlready() throws {
    // macOS reports the new window as focused before it reports it as created, so by the time Arbor
    // hears of it `focusedWindow()` is the new window itself.
    let h = harness()
    h.start()
    let a = h.open("Safari")
    let b = h.open("Mail")
    h.system.userFocus(a)
    let n = WindowID(b.rawValue + 1)
    h.system.focused = n
    #expect(h.system.open(app: "Notes") == n)
    #expect(h.group(of: n) == h.group(of: a))
    #expect(h.rect(n).minY > h.rect(a).maxY)
  }

  @Test func aFloatingWindowWithTheKeyboardIsPassedOverForTheLastDockedOne() throws {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    let palette = h.open("Colours", frame: CGRect(x: 100, y: 300, width: 220, height: 300))
    #expect(h.isFloating(palette))
    let n = h.open("Notes")
    #expect(h.rect(n).minX > h.rect(a).maxX)
  }

  // MARK: 3. Nothing docked

  @Test func withNothingDockedItDocksAtTheRightEdgeOfTheView() {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    let tree = h.workspace.tree
    #expect(tree.children(of: tree.root).map { tree.windows(under: $0) } == [[], [a]])
    #expect(h.frame(a) == CGRect(x: 12, y: 37, width: 1416, height: 851))
    #expect(h.layout?.desktopFrame == nil, "it leaves the Desktop what Arrange Windows would: nothing")
  }

  // MARK: The Desktop's share

  @Test func theFirstWindowLeavesAnEmptyDesktopWhatArrangeWindowsWould() {
    let h = harness(desktopColumn: true) { $0.arrangeDesktopWeight = Settings().arrangeDesktopWeight }
    h.start()
    let a = h.open("Safari")
    #expect(h.layout?.desktopFrame == CGRect(x: 12, y: 37, width: 468, height: 851))
    #expect(h.frame(a) == CGRect(x: 492, y: 37, width: 936, height: 851))
    // Four windows fill two thirds of the display, not half of it.
    let others = ["Terminal", "Mail", "Notes"].map { h.open($0) }
    #expect(h.layout?.desktopFrame?.width == 464)
    #expect(h.rect(a).width == 464 && h.rect(a).height == 851)
    #expect(h.rect(others[0]).minX > h.rect(a).maxX)
    h.expectAllInPlace()
  }

  @Test func aDesktopWithAWindowOnItKeepsHalf() {
    let h = harness(newWindows: "float") { $0.arrangeDesktopWeight = 0.5 }
    h.start()
    let note = h.open("Stickies", frame: CGRect(x: 60, y: 100, width: 300, height: 200))
    h.run("toggle-auto-dock")
    let a = h.open("Safari")
    #expect(h.frame(a) == CGRect(x: 726, y: 37, width: 702, height: 851))
    #expect(h.frame(note) == CGRect(x: 60, y: 100, width: 300, height: 200))
  }

  /// Nobody gives half of a slot while there is room that nobody has. What floats there goes on floating, over the docked windows.
  @Test func whatIsLeftOverGoesBeforeHalfOfAnybodysSlot() {
    let h = harness(newWindows: "float")
    h.start()
    let note = h.open("Stickies", frame: CGRect(x: 800, y: 100, width: 300, height: 200))
    let a = h.open("Safari")
    h.run("dock \(a.rawValue) left")
    h.run("toggle-auto-dock")
    let left = h.layout?.desktopFrame
    #expect(left == CGRect(x: 726, y: 37, width: 702, height: 851))
    h.system.clearFrameLog()
    let n = h.open("Notes")
    #expect(h.slot(n) == left)
    #expect(h.system.frameLog.map(\.window) == [n], "one move, and nobody else's")
    #expect(h.layout?.desktopFrame == nil)
    #expect(h.isFloating(note) && h.system.isVisible(note) && h.frame(note) == CGRect(x: 800, y: 100, width: 300, height: 200))
    h.expectAllInPlace()
  }

  @Test func windowsThatFloatOutOfSightDoNotCount() {
    let h = harness(newWindows: "float")
    h.start()
    let note = h.open("Stickies", frame: CGRect(x: 60, y: 100, width: 300, height: 200))
    h.system.setMinimized(note, true)
    h.run("toggle-auto-dock")
    // All of it, as on an empty Desktop. One with a window on it keeps half.
    #expect(h.rect(h.open("Safari")).width == 1416)
  }

  @Test func aWindowTooWideForTheRightEdgeTakesTheBottomAndTheDesktopAThirdOfTheHeight() {
    let h = harness(desktopColumn: true) { $0.arrangeDesktopWeight = 0.5 }
    h.start()
    let a = h.open("Numbers", frame: CGRect(x: 100, y: 60, width: 1200, height: 700), minimumSize: CGSize(width: 1000, height: 300))
    #expect(h.rect(a).width == 1416)
    #expect(h.layout?.desktopFrame?.maxY == h.rect(a).minY - 12)
    #expect(abs(h.rect(a).height - 2 * (h.layout?.desktopFrame?.height ?? 0)) <= 2)
  }

  @Test(arguments: [(0.0, 0.05), (1e300, 20.0), (-3.0, 0.05)]) func anAbsurdShareIsBoundedAsArrangeBoundsIt(
    weight: Double, bounded: Double
  ) {
    let h = harness(desktopColumn: true) { $0.arrangeDesktopWeight = weight }
    h.start()
    let a = h.open("Safari")
    // Too narrow a Desktop, or too narrow a window, would be a tile: then there is no room on that side.
    #expect(h.layout?.tiles.isEmpty == true)
    #expect(h.workspace.tree.invariantViolations() == [])
    if h.isDocked(a), let desktop = h.workspace.tree[h.workspace.tree.desktop]?.weight,
      let leaf = h.workspace.tree.leaf(containing: a), let window = h.workspace.tree[leaf]?.weight
    {
      #expect(abs(desktop / window - bounded) < 0.0001)
    }
  }

  @Test func aRuleThatNamesAnEdgeSharesAsItAlwaysDid() {
    let h = harness(newWindows: "float", rules: [AppRule(app: "com.example.safari", action: .dock(.right))]) {
      $0.arrangeDesktopWeight = 0.5
    }
    h.start()
    #expect(h.frame(h.open("Safari")) == CGRect(x: 726, y: 37, width: 702, height: 851))
  }

  // MARK: With room made before tiles (F61)

  @Test func aNewWindowThatNeedsMoreThanHalfGetsItFromItsNeighbour() {
    let h = harness { $0.makeRoom = true }
    h.start()
    let a = h.open("Safari")
    h.system.clearFrameLog()
    // Half of the slot is 702 points wide, and Notes stops at 709.
    let n = h.open("Notes", frame: CGRect(x: 100, y: 100, width: 900, height: 600), minimumSize: CGSize(width: 709, height: 100))
    #expect(h.rect(n).minX > h.rect(a).maxX, "to the right all the same")
    #expect(h.rect(n).width >= 709)
    #expect(h.moved(a).count == 1, "its neighbour moves once, when it is known how far")
    h.expectAllInPlace()
  }

  @Test func aNeighbourThatNeedsMoreThanHalfKeepsIt() {
    let h = harness { $0.makeRoom = true }
    h.start()
    let a = h.open("Safari", minimumSize: CGSize(width: 800, height: 100))
    let n = h.open("Notes")
    #expect(h.rect(n).minX > h.rect(a).maxX)
    #expect(h.rect(a).width >= 800)
    h.expectAllInPlace()
  }

  @Test func anEmptyDesktopGivesWayToWindowsThatNeedTheRoom() {
    let h = harness(desktopColumn: true) { $0.makeRoom = true }
    h.start()
    // Each stops at 574 points, as Safari does: two of them do not fit side by side in half the display.
    let a = h.open("Safari", minimumSize: CGSize(width: 574, height: 500))
    let b = h.open("Safari", minimumSize: CGSize(width: 574, height: 500))
    #expect(h.rect(b).minX > h.rect(a).maxX)
    #expect(h.rect(a).width >= 574 && h.rect(b).width >= 574)
    #expect(h.layout?.tiles.allSatisfy { $0.kind == .desktop } == true, "nothing but the empty Desktop may become a tile")
  }

  @Test func aDesktopWithAWindowOnItStaysUsable() {
    let h = harness(newWindows: "float", desktopColumn: true) { $0.makeRoom = true }
    h.start()
    let note = h.open("Stickies", frame: CGRect(x: 60, y: 100, width: 300, height: 200))
    h.run("toggle-auto-dock")
    let a = h.open("Safari", minimumSize: CGSize(width: 574, height: 500))
    let b = h.open("Safari", minimumSize: CGSize(width: 574, height: 500))
    #expect(h.isDocked(a))
    #expect((h.layout?.desktopFrame?.width ?? 0) >= 240)
    #expect(h.system.isVisible(note))
    #expect(h.layout?.tiles.isEmpty == true)
    // 1416 points less two gaps hold 240 and 574 twice: just.
    #expect(h.isDocked(b))
    let c = h.open("Safari", minimumSize: CGSize(width: 574, height: 500))
    #expect(h.isFloating(c), "and no more")
    #expect(h.layout?.tiles.isEmpty == true)
  }

  /// The Desktop became a tile while it was empty, and a window floats on it since. The next layout gives it a usable
  /// size back, at the price of a docked window's place. That is F61's to decide, and not to be set off by a window that opens.
  @Test func aDesktopThatIsOwedRoomIsNotPaidBecauseAWindowOpened() {
    let h = harness(desktopColumn: true) { $0.makeRoom = true }
    h.start()
    let b = h.open("Safari", frame: CGRect(x: 100, y: 100, width: 700, height: 500))
    let c = h.open("Mail", frame: CGRect(x: 100, y: 100, width: 740, height: 612))
    let d = h.open("Xcode", frame: CGRect(x: 100, y: 100, width: 1023, height: 569), minimumSize: CGSize(width: 956, height: 164))
    #expect(h.layout?.tiles.map(\.kind) == [.desktop])
    let panel = h.open("Colours", frame: CGRect(x: 60, y: 200, width: 345, height: 404), isResizable: false)
    #expect(h.isFloating(panel))
    let showing = h.layout?.windowFrames
    let n = h.open("Notes", frame: CGRect(x: 100, y: 100, width: 499, height: 606))
    #expect(Set(showing?.keys ?? [:].keys) == [b, c, d])
    #expect([b, c, d].allSatisfy { h.slot($0) != nil }, "whatever becomes of the new window, these go on showing")
    #expect(h.isFloating(n) || h.slot(n) != nil)
    #expect(h.layout?.tiles.allSatisfy { $0.kind == .desktop } == true)
  }

  @Test func takingADockingBackCostsNobodyTheirPlace() {
    let h = harness(newWindows: "float", desktopColumn: true) { $0.makeRoom = true }
    h.start()
    let a = h.open("Settings", frame: CGRect(x: 100, y: 60, width: 697, height: 760), isResizable: false)
    h.run("dock \(a.rawValue) left")
    let c = h.open("Xcode", frame: CGRect(x: 100, y: 100, width: 812, height: 720), minimumSize: CGSize(width: 538, height: 700))
    h.run("dock \(c.rawValue) right")
    #expect(h.layout?.tiles.map(\.kind) == [.desktop])
    let showing = h.layout?.windowFrames
    h.run("toggle-auto-dock")
    // Neither will share: Xcode says so when it is asked for half its height, Settings whatever it is asked for.
    let n = h.open("Notes")
    #expect(h.isFloating(n))
    #expect(h.frame(n) == opening)
    #expect(h.layout?.windowFrames == showing)
    #expect(h.frame(a)?.size == CGSize(width: 697, height: 760))
  }

  // MARK: 4. One mechanism

  @Test func aRuleForAnyAppDoesWhatTheSettingDoes() {
    let byRule = harness(newWindows: "float", rules: [AppRule(app: "*", action: .dockAuto)])
    let bySetting = harness()
    for h in [byRule, bySetting] {
      h.start()
      for app in ["Safari", "Mail", "Notes", "Terminal"] { h.open(app) }
      h.open("Calculator", frame: CGRect(x: 10, y: 40, width: 230, height: 408), isResizable: false)
    }
    #expect(byRule.workspace == bySetting.workspace)
    #expect(byRule.workspace.tree.allWindows.count == 4)
  }

  @Test func rulesComeBeforeTheSetting() throws {
    let h = harness(rules: [
      AppRule(app: "com.example.mail", action: .float),
      AppRule(app: "com.example.terminal", action: .dock(.left)),
      AppRule(app: "com.example.music", action: .ignore),
    ])
    h.start()
    let safari = h.open("Safari")
    let mail = h.open("Mail")
    #expect(h.isFloating(mail) && h.frame(mail) == opening)
    let (terminal, music) = (h.open("Terminal"), h.open("Music"))
    #expect(h.isDocked(safari))
    #expect(h.isFloating(mail))
    #expect(h.rect(terminal).minX == 12)
    #expect(h.controller.filter.ignoredWindowIDs == [music])
  }

  @Test func aStarAtTheEndCoversAFamilyOfApps() {
    let h = harness(newWindows: "float", rules: [AppRule(app: "com.jetbrains.*", action: .dockAuto)])
    h.start()
    #expect(h.isDocked(h.open("IDEA", bundleID: "com.jetbrains.intellij")))
    #expect(h.isDocked(h.open("PyCharm", bundleID: "com.jetbrains.pycharm")))
    #expect(h.isFloating(h.open("Xcode", bundleID: "com.apple.dt.Xcode")))
  }

  @Test func theReportShowsWhatTheSettingAddsToTheRules() throws {
    let h = harness(rules: [AppRule(app: "com.example.mail", action: .float)])
    h.start()
    let safari = h.open("Safari")
    let text = try #require(h.run("rules").text)
    #expect(text.contains("1. com.example.mail → float"))
    #expect(text.contains("Any other window docks beside the focused window"))
    #expect(text.contains("400 x 300 points"))
    #expect(text.contains("Focused window \(safari) (com.example.safari) matches no rule of its own"))
    let bare = harness()
    #expect(bare.run("rules").text?.hasPrefix("No rules. Add one with `rule add <bundle id> <action>`, or in settings.json.\nA new window docks beside") == true)
    h.run("toggle-auto-dock")
    let off = try #require(h.run("rules").text)
    #expect(!off.contains("Any other window"))
    #expect(!off.contains("newWindows"))
    #expect(off.contains("Focused window \(safari) (com.example.safari) matches no rule."))
  }

  @Test func aMinimumTooLargeForAnIntegerIsReportedAndDocksNothing() {
    let h = harness { $0.autoDockMinimumWidth = 1e300 }
    h.start()
    #expect(h.isFloating(h.open("Safari")))
    #expect(h.run("rules").text?.contains("1e+300 x 300 points") == true)
  }

  // MARK: 5. Windows that are not worth a place

  @Test(arguments: [
    CGSize(width: 399, height: 600), CGSize(width: 265, height: 520), CGSize(width: 800, height: 299),
  ]) func aWindowThatOpensSmallFloats(size: CGSize) {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    h.system.clearFrameLog()
    let frame = CGRect(origin: CGPoint(x: 200, y: 100), size: size)
    let info = h.open("Finder", frame: frame)
    #expect(h.isFloating(info))
    #expect(h.frame(info) == frame)
    #expect(h.system.frameLog.isEmpty)
    #expect(h.isDocked(a))
  }

  @Test func aWindowOfExactlyTheMinimumDocksAndTheMinimumIsASetting() {
    let h = harness()
    h.start()
    #expect(h.isDocked(h.open("Safari", frame: CGRect(x: 0, y: 40, width: 400, height: 300))))
    let strict = harness { $0.autoDockMinimumWidth = 700 }
    strict.start()
    #expect(strict.isFloating(strict.open("Safari")))
  }

  @Test func aWindowThatCannotBeResizedFloatsUnlessARuleNamesItsApp() {
    let frame = CGRect(x: 500, y: 100, width: 723, height: 470)
    let h = harness()
    h.start()
    let settings = h.open("Settings", frame: frame, isResizable: false)
    #expect(h.isFloating(settings))
    #expect(h.frame(settings) == frame)

    let named = harness(rules: [AppRule(app: "com.example.settings", action: .dock(.right))])
    named.start()
    #expect(named.isDocked(named.open("Settings", frame: frame, isResizable: false)))

    // Written for apps nobody listed, so as careful as `dock auto`.
    let wildcard = harness(newWindows: "float", rules: [AppRule(app: "*", action: .dock(.right))])
    wildcard.start()
    #expect(wildcard.isFloating(wildcard.open("Settings", frame: frame, isResizable: false)))
    #expect(wildcard.isDocked(wildcard.open("Safari")))
  }

  @Test func aWindowThatTakesNoRoomFloats() {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    let slot = h.rect(a)
    // An app restores a window straight into the Dock: by the time it is reported it is minimized.
    h.system.events = nil
    let id = h.system.open(app: "Mail")
    h.system.setMinimized(id, true)
    h.system.events = h.controller
    h.system.clearFrameLog()
    h.controller.windowAppeared(h.system.windows[id]!.snapshot)
    #expect(h.isFloating(id))
    #expect(h.system.frameLog.isEmpty)
    #expect(h.rect(a) == slot)
  }

  // MARK: 6. No room

  /// Five windows, each in half of what the one before had, the last two a sixteenth of the display each, and the first made to
  /// insist on its size, so that nobody has anything to give.
  func crowded(_ h: Harness) -> [WindowID] {
    h.start()
    let windows = ["Safari", "Mail", "Notes", "Terminal", "Calendar"].map { h.open($0) }
    h.system.setMinimumSize(windows[0], CGSize(width: 700, height: 500))
    h.system.setMinimumSize(windows[1], CGSize(width: 340, height: 400))
    return windows
  }

  @Test func withNoRoomItFloatsWhereItOpenedAndNothingBecomesATile() {
    let h = harness()
    let windows = crowded(h)
    let before = h.layout?.windowFrames
    let n = h.open("Music")
    #expect(h.isFloating(n))
    #expect(h.frame(n) == opening)
    #expect(h.workspace.floating[n] == opening)
    #expect(h.layout?.windowFrames == before)
    #expect(h.workspace.tree.allWindows == windows)
    h.expectAllInPlace()
  }

  @Test func withTabsOnItJoinsTheFocusedWindowAsTheSelectedTab() throws {
    let h = harness { $0.tabsEnabled = true }
    let windows = crowded(h)
    let slot = h.rect(windows[4])
    let n = h.open("Music")
    let tree = h.workspace.tree
    let leaf = try #require(tree.leaf(containing: n))
    #expect(tree.windows(under: leaf) == [windows[4], n])
    #expect(tree.activeWindow(of: leaf) == n)
    #expect(h.frame(n) == slot)
    #expect(!h.system.isVisible(windows[4]))
    #expect(h.layout?.tiles.isEmpty == true)
  }

  @Test func whenTheFocusedWindowIsTooSmallToShareTheLargestOneDoes() throws {
    let h = harness()
    h.start()
    let windows = ["Safari", "Mail", "Notes", "Terminal", "Calendar"].map { h.open($0) }
    let n = h.open("Music")
    #expect(h.rect(n).minY > h.rect(windows[0]).maxY)
    #expect(h.rect(n).minX == h.rect(windows[0]).minX)
    h.expectAllInPlace()
  }

  // MARK: 7. A new window that refuses its slot

  @Test func aNewWindowIsOfferedItsSlotBeforeAnyoneMakesRoom() throws {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    let wide = h.rect(a)
    h.system.clearFrameLog()

    // Notes will not go below 709 points, and half of the slot is 702.
    let n = h.open("Notes", frame: CGRect(x: 100, y: 100, width: 900, height: 600), minimumSize: CGSize(width: 709, height: 100))
    #expect(h.system.frameLog.first?.window == n, "the newcomer is asked first")
    #expect(h.moved(a).count == 1, "its neighbour moves once, for the attempt that works")
    #expect(h.rect(n).minY > h.rect(a).maxY)
    #expect(h.rect(n).width == wide.width)
    h.expectAllInPlace()
  }

  /// Apps round sizes (terminals to whole characters). Two points over is a fit, as it is for any docked window.
  @Test(arguments: [(704.0, true), (705.0, false)]) func twoPointsOverTheSlotStillFit(width: Double, fits: Bool) {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    // Half of the slot is 702 points wide.
    let n = h.open("Terminal", frame: CGRect(x: 100, y: 100, width: 900, height: 600), minimumSize: CGSize(width: width, height: 100))
    #expect((h.rect(n).minX > h.rect(a).maxX) == fits)
    #expect((h.rect(n).minY > h.rect(a).maxY) == !fits)
    #expect(h.layout?.tiles.isEmpty == true)
  }

  @Test(arguments: [(421.0, true), (422.0, false)]) func twoPointsOverTheSlotStillFitInHeight(height: Double, fits: Bool) {
    let h = harness()
    h.start()
    h.open("Safari")
    let a = h.open("Mail")
    // It has the right half of the display. The lower half of that is 419 points tall.
    let n = h.open("Terminal", frame: CGRect(x: 100, y: 100, width: 900, height: 600), minimumSize: CGSize(width: 100, height: height))
    #expect((h.rect(n).minY > h.rect(a).maxY) == fits)
    #expect((h.rect(n).minX > h.rect(a).maxX) == !fits)
    #expect(h.layout?.tiles.isEmpty == true)
  }

  /// Terminals size their windows in whole character cells and take the size nearest to the one asked for, which half the
  /// time is the larger one. That is not a refusal.
  @Test(arguments: [CGSize(width: 7, height: 15), CGSize(width: 8, height: 17), CGSize(width: 9, height: 19),
    CGSize(width: 11, height: 23), CGSize(width: 13, height: 27)], [8.0, 9, 10, 11, 12, 13])
  func aWindowThatComesInCharacterCellsDocksAllTheSame(cell: CGSize, gap: Double) {
    for makeRoom in [false, true] {
      let h = harness {
        $0.gap = gap
        $0.makeRoom = makeRoom
      }
      h.start()
      h.open("Mail")
      let a = h.open("Safari")  // the right half of the display
      // `open` announces the window at once, so it gets its cells the first time it is asked for a size.
      let n = WindowID(a.rawValue + 1)
      h.system.willSetFrame = { [system = h.system] window, _ in
        if window == n, system.windows[n]?.sizeStep == nil { system.setSizeStep(n, cell) }
      }
      #expect(h.open("Terminal") == n)
      #expect(h.isDocked(n), "cells of \(cell), a gap of \(gap), making room: \(makeRoom)")
      #expect(h.layout?.tiles.isEmpty == true)
      #expect(h.rect(n).minY > h.rect(a).maxY)
    }
  }

  @Test func aNewWindowThatFitsNowhereIsBackWhereItOpenedAndNobodyMoved() {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    h.system.clearFrameLog()
    let frame = CGRect(x: 100, y: 100, width: 900, height: 600)
    // Too far over half of the slot (702 points, or 419) to be a matter of character cells, so it is asked once.
    let n = h.open("Notes", frame: frame, minimumSize: CGSize(width: 760, height: 500))
    #expect(h.isFloating(n))
    #expect(h.frame(n) == frame)
    #expect(h.moved(a).isEmpty)
    #expect(h.moved(n).count == 3, "asked once for each half, which teaches its width and its height, and put back")
    #expect(h.workspace.floating[n] == frame)
    h.expectAllInPlace()
  }

  // MARK: 8. A neighbour that refuses its half

  @Test func aDockingThatSqueezesTheNeighbourIntoATileIsTakenBackAndTriedTheOtherWay() throws {
    let h = harness()
    h.start()
    // Nothing has asked Safari to be narrow yet, so Arbor does not know that it stops at 800.
    let a = h.open("Safari", minimumSize: CGSize(width: 800, height: 100))
    let n = h.open("Notes")
    #expect(h.rect(n).minY > h.rect(a).maxY)
    h.expectAllInPlace()
  }

  @Test func aDockingThatCannotWorkEitherWayLeavesEverythingAsItWas() throws {
    let h = harness()
    h.start()
    let a = h.open("Safari", minimumSize: CGSize(width: 800, height: 500))
    let (workspace, slot) = (h.workspace, h.rect(a))
    let n = h.open("Notes")
    #expect(h.isFloating(n))
    #expect(h.frame(n) == opening)
    #expect(h.frame(a) == slot)
    var expected = workspace
    expected.floating[n] = opening
    #expect(h.workspace == expected)
    #expect(h.controller.parked.isEmpty)
    h.expectAllInPlace()

    // What was learned spares the next window the attempt.
    h.system.clearFrameLog()
    let m = h.open("Mail")
    #expect(h.isFloating(m))
    #expect(h.system.frameLog.isEmpty)
  }

  // MARK: 9. The view stays

  @Test func withTheViewOnAGroupTheWindowDocksInsideItAndTheViewStays() throws {
    let h = harness(newWindows: "float")
    h.start()
    let (a, b, c) = (h.open("Safari"), h.open("Mail"), h.open("Notes"))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
    h.run("dock \(c.rawValue) right")
    h.run("toggle-auto-dock")
    let group = try #require(h.group(of: a))
    h.run("zoom-node \(group.rawValue)")
    h.system.userFocus(b)
    let n = h.open("Terminal")
    #expect(h.workspace.camera == group)
    #expect(h.workspace.tree.windows(under: group) == [a, b, n])
    #expect(!h.system.isVisible(c))
    h.expectAllInPlace()
  }

  @Test func aWindowOfAnAppThatIsOutOfViewDocksInTheViewAndDoesNotStealIt() throws {
    let h = harness(newWindows: "float")
    h.start()
    let (a, b, c) = (h.open("Safari"), h.open("Mail"), h.open("Notes"))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
    h.run("dock \(c.rawValue) right")
    h.run("toggle-auto-dock")
    // Notes had the keyboard last, and then the view went elsewhere.
    h.system.userFocus(c)
    let group = try #require(h.group(of: a))
    h.run("zoom-node \(group.rawValue)")
    let n = h.openQuietly("Notes")
    #expect(h.workspace.camera == group)
    #expect(h.workspace.tree.windows(under: group).contains(n))
    #expect(!h.system.isVisible(c))
  }

  @Test func withOneWindowFramedTheNewOneFloatsOverItAndTheViewStays() throws {
    let h = harness()
    h.start()
    let (a, b) = (h.open("Safari"), h.open("Mail"))
    h.run("zoom \(a.rawValue)")
    let camera = h.workspace.camera
    h.system.clearFrameLog()
    let n = h.open("Notes")
    #expect(h.isFloating(n))
    #expect(h.frame(n) == opening)
    #expect(h.workspace.camera == camera)
    #expect(h.system.frameLog.isEmpty)
    #expect(h.workspace.tree.allWindows == [a, b])
    // F57: it belongs to the view it opened over, and comes back with it.
    #expect(h.workspace.guests?[n] == camera)
    h.run("neighbor right")
    #expect(!h.system.isVisible(n))
    h.run("back")
    #expect(h.frame(n) == opening)
  }

  @Test func whoWantsNoGuestsGetsAnOrdinaryFloatingWindow() {
    let h = harness { $0.newWindowsWhileFramed = "float" }
    h.start()
    let a = h.open("Safari")
    h.open("Mail")
    h.run("zoom \(a.rawValue)")
    let n = h.open("Notes")
    #expect(h.isFloating(n))
    #expect(h.workspace.guests == nil)
  }

  @Test func withTheViewOnTheDesktopAloneTheNewWindowFloatsThere() {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    h.run("desktop")
    let n = h.open("Notes")
    #expect(h.isFloating(n))
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    #expect(!h.system.isVisible(a))
  }

  // MARK: 10. Two displays

  @Test func aWindowDocksOnTheDisplayItOpenedOnBesideThatDisplaysLastFocusedWindow() throws {
    let h = harness(displays: [FakeWindowSystem.standardDisplay, side])
    h.start()
    let there = CGRect(x: 1800, y: 200, width: 800, height: 600)
    let main1 = h.open("Safari")
    let side1 = h.open("Mail", frame: there)
    let side2 = h.open("Notes", frame: there)
    #expect(h.controller.workspaces[side.id]?.tree.allWindows == [side1, side2])
    h.system.userFocus(side1)
    h.system.userFocus(main1)
    let before = h.workspace

    // The keyboard is on the main display; the window opens on the other one.
    let n = h.open("Terminal", frame: there)
    #expect(h.workspace == before)
    #expect(h.group(of: n) == h.group(of: side1))
    #expect(side.frame.contains(try #require(h.frame(n))))
    h.expectAllInPlace()
  }

  @Test func theFirstWindowOnAnEmptyDisplayDocksAtItsRightEdge() throws {
    let h = harness(displays: [FakeWindowSystem.standardDisplay, side])
    h.start()
    h.open("Safari")
    let n = h.open("Mail", frame: CGRect(x: 1800, y: 200, width: 800, height: 600))
    #expect(h.controller.workspaces[side.id]?.tree.allWindows == [n])
    #expect(try #require(h.frame(n)).maxX == side.visibleFrame.maxX - 12)
  }

  // MARK: 11. A burst

  @Test(arguments: [true, false]) func fiveWindowsAtOnceSpiralInwardAndNothingBecomesATile(focusReports: Bool) throws {
    let h = harness()
    h.start()
    let windows = (1...5).map { number in
      focusReports ? h.open("Safari", title: "Tab \(number)") : h.openQuietly("Safari", title: "Tab \(number)")
    }
    #expect(h.workspace.tree.allWindows.count == 5)
    h.expectAllInPlace()
    // Each halved the slot of the one before.
    for (earlier, later) in zip(windows, windows.dropFirst()) {
      let (a, b) = (h.rect(earlier), h.rect(later))
      #expect(b.minX >= a.minX && b.minY >= a.minY && (b.minX > a.maxX || b.minY > a.maxY), "\(later) after \(earlier)")
    }
    // The fifth has nothing left to give, so a sixth goes to the largest.
    let sixth = focusReports ? h.open("Safari", title: "Tab 6") : h.openQuietly("Safari", title: "Tab 6")
    #expect(h.rect(sixth).minX == h.rect(windows[0]).minX && h.rect(sixth).minY > h.rect(windows[0]).maxY)
    h.expectAllInPlace()
  }

  @Test func aBurstLargerThanTheDisplayLeavesTheRestFloating() {
    let h = harness()
    h.start()
    let windows = (1...28).map { _ in h.openQuietly("Safari") }
    let docked = windows.filter(h.isDocked)
    // A sixteenth of the display, 345 by 203 points, is the smallest slot: half of it would be a tile.
    #expect(docked.count >= 16)
    #expect(docked.count < 28)
    for window in windows where !h.isDocked(window) { #expect(h.frame(window) == opening) }
    h.expectAllInPlace()
  }

  @Test func afterTheBurstTheFocusedWindowCountsAgain() throws {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    // Opened in the background: it never gets the keyboard.
    let b = h.openQuietly("Mail")
    h.scheduler.advance(by: 1)
    let n = h.openQuietly("Notes")
    #expect(h.rect(b).minX > h.rect(a).maxX)
    #expect(h.group(of: n) == h.group(of: a))
    #expect(h.rect(n).minY > h.rect(a).maxY)
  }

  // MARK: 12. Windows nobody just opened

  @Test func windowsFoundAtLaunchFloat() {
    let h = harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Mail", frame: CGRect(x: 40, y: 60, width: 800, height: 600))
    h.start()
    #expect(h.workspace.floating.keys.sorted() == [a, b])
    #expect(h.system.frameLog.isEmpty)
  }

  @Test func nothingHappensDuringAPauseAndWhatOpenedMeanwhileFloats() {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    h.run("pause")
    h.system.clearFrameLog()
    let b = h.open("Mail")
    #expect(h.system.frameLog.isEmpty)
    h.run("resume")
    #expect(h.isDocked(a))
    #expect(h.isFloating(b))
    #expect(h.frame(b) == opening)
    // And it works again.
    #expect(h.isDocked(h.open("Notes")))
  }

  @Test func windowsFoundOnAnotherMacOSSpaceFloat() {
    let h = harness(rules: [AppRule(app: "com.example.music", action: .ignore)])
    // Open since before Arbor started, on a Space that is not showing, where Accessibility does not list them.
    let found = ["Mail", "Notes", "Terminal"].map { h.system.open(app: $0) }
    let music = h.system.open(app: "Music")
    for window in found + [music] { h.system.setListed(window, false) }
    h.start()
    let a = h.open("Safari")
    h.system.setOnActiveSpace(a, false)
    h.system.clearFrameLog()
    for window in found + [music] { h.system.setListed(window, true) }
    h.scheduler.runPending()
    for window in found {
      #expect(h.isFloating(window))
      #expect(h.frame(window) == opening)
    }
    #expect(h.controller.filter.ignoredWindowIDs == [music], "`ignore` applies to windows Arbor did not see open")
    #expect(h.system.frameLog.isEmpty)
    #expect(h.workspace.tree.allWindows == [a])
  }

  @Test func rulesThatDockLeaveFoundWindowsAloneToo() {
    let h = harness(newWindows: "float", rules: [AppRule(app: "com.example.mail", action: .dock(.left))])
    let found = h.system.open(app: "Mail")
    h.system.setListed(found, false)
    h.start()
    h.system.setListed(found, true)
    #expect(h.isFloating(found))
    #expect(h.isDocked(h.open("Mail")))
  }

  @Test func aFoundWindowStillTakesTheSlotThatWasSavedForIt() {
    // Docked, then Arbor restarts while the window's Space is not showing.
    let first = harness()
    first.start()
    let (a, b) = (first.open("Safari"), first.open("Mail"))
    first.controller.saveNow()
    let h = harness(saved: first.store.saved)
    #expect(h.system.open(app: "Safari") == a)
    #expect(h.system.open(app: "Mail") == b)
    h.system.setListed(b, false)
    h.start()
    #expect(h.slot(b) == nil)
    h.system.setListed(b, true)
    #expect(h.workspace.tree.allWindows == [a, b])
    #expect(h.slot(b) == first.slot(b))
  }

  @Test func anAppThatIsIncludedAgainKeepsItsWindowsFloating() {
    let h = harness { $0.excludedBundleIDs = ["com.example.mail"] }
    h.start()
    let mail = h.open("Mail")
    #expect(h.controller.workspaceID(containing: mail) == nil)
    h.run("include com.example.mail")
    #expect(h.isFloating(mail))
  }

  // MARK: 13. A splash window

  @Test func theMainWindowEndsUpWhereTheSplashWasWhenTheSplashClosesFirst() throws {
    let h = harness()
    h.start()
    let (a, b) = (h.open("Safari"), h.open("Mail"))
    let before = h.layout?.windowFrames
    let splash = h.open("Editor", title: "Loading")
    let place = h.rect(splash)
    h.system.close(splash)
    #expect(h.layout?.windowFrames == before)
    let main = h.open("Editor", title: "Untitled", frame: CGRect(x: 100, y: 80, width: 1100, height: 700))
    #expect(h.slot(main) == place)
    #expect(h.workspace.tree.allWindows == [a, b, main])
    h.expectAllInPlace()
  }

  @Test func theMainWindowEndsUpWhereTheSplashWasWhenItOpensFirst() throws {
    let h = harness()
    h.start()
    let (a, b) = (h.open("Safari"), h.open("Mail"))
    let splash = h.open("Editor", title: "Loading")
    let place = h.rect(splash)
    let main = h.open("Editor", title: "Untitled", frame: CGRect(x: 100, y: 80, width: 1100, height: 700))
    h.system.close(splash)
    #expect(h.slot(main) == place)
    #expect(h.workspace.tree.allWindows == [a, b, main])
    h.expectAllInPlace()
  }

  @Test func aSmallSplashNeverTouchesTheArrangement() {
    let h = harness()
    h.start()
    h.open("Safari")
    h.system.clearFrameLog()
    let splash = h.open("Editor", frame: CGRect(x: 500, y: 300, width: 480, height: 280), isResizable: false)
    h.system.close(splash)
    #expect(h.system.frameLog.isEmpty)
  }

  @Test func aNativeTabTakesItsGroupsPlaceAndNoSlotOfItsOwn() throws {
    let h = harness()
    h.start()
    let (a, b) = (h.open("Safari"), h.open("Terminal"))
    let frames = (h.rect(a), h.rect(b))
    // ⌘T: to macOS a new window, at the same frame, while the old one stops being listed.
    let tab = try #require(h.system.openTab(in: b))
    #expect(h.workspace.tree.allWindows == [a, tab])
    #expect((h.rect(a), h.rect(tab)) == frames)
    h.expectAllInPlace()
  }

  // MARK: 14. Late titles

  @Test(arguments: [false, true]) func aLateTitleThatMatchesAFloatRuleTakesTheWindowBackOut(makingWay: Bool) throws {
    let h = harness(rules: [AppRule(app: "com.example.safari", title: "Picture in Picture", action: .float)], desktopColumn: true) {
      $0.floatingWindowsMakeWay = makingWay
    }
    h.start()
    let a = h.open("Mail")
    let slot = h.rect(a)
    let n = h.open("Safari", title: "")
    #expect(h.isDocked(n))
    h.scheduler.advance(by: 0.15)
    h.system.setTitle(n, "Picture in Picture")
    #expect(h.isFloating(n))
    // The Desktop is in view, so it sits as near to where it opened as the Desktop allows (F11's follow-up). As Arbor ships,
    // where it opened, whatever is docked there.
    #expect(h.workspace.floating[n] == opening)
    if makingWay {
      #expect(h.layout?.desktopFrame?.contains(h.frame(n) ?? .zero) == true)
    } else {
      #expect(h.frame(n) == opening)
    }
    #expect(h.slot(a) == slot)
    h.expectAllInPlace()
  }

  @Test func aLateTitleJudgesACautiousRuleByTheSizeTheWindowOpenedWith() {
    // The window opened small and floats. Its title arrives, and a rule for any app with that title would dock it.
    let h = harness(newWindows: "float", rules: [AppRule(app: "*", title: "Inbox", action: .dockAuto)])
    h.start()
    h.open("Safari", title: "Inbox")
    let small = h.open("Mail", title: "", frame: CGRect(x: 100, y: 100, width: 300, height: 200))
    h.system.userMove(small, to: CGRect(x: 100, y: 100, width: 900, height: 700))
    h.system.setTitle(small, "Inbox")
    #expect(h.isFloating(small))
    let large = h.open("Mail", title: "")
    #expect(h.isFloating(large))
    h.system.setTitle(large, "Inbox")
    #expect(h.isDocked(large))
  }

  // MARK: 15. The switch

  @Test func theSwitchFlipsTheSettingSavesThatKeyAndMovesNothing() {
    let h = Harness()
    var saved: [(old: Settings, new: Settings)] = []
    h.controller.saveSettings = { saved.append(($0, $1)) }
    var applied = 0
    h.controller.observe { if $0 == .settings { applied += 1 } }
    h.start()
    let a = h.open("Safari")
    h.run("dock \(a.rawValue) left")
    let b = h.open("Mail", frame: CGRect(x: 800, y: 200, width: 500, height: 400))
    h.system.clearFrameLog()

    let on = h.run("toggle-auto-dock")
    #expect(on.ok && on.message == "new windows dock beside the focused window")
    #expect(h.controller.settings.newWindows == "dock")
    #expect(h.isFloating(b), "windows that are open stay as they are")
    #expect(h.system.frameLog.isEmpty)
    #expect(applied == 1, "the menu's tick follows")

    let off = h.run("toggle-auto-dock")
    #expect(off.ok && off.message == "new windows float")
    #expect(h.controller.settings.newWindows == "float")
    #expect(h.isDocked(a))
    #expect(h.system.frameLog.isEmpty)

    #expect(saved.map(\.new.newWindows) == ["dock", "float"])
    for change in saved {
      var expected = change.old
      expected.newWindows = change.new.newWindows
      #expect(change.new == expected)
    }
  }

  @Test func aSwitchThatCannotBeSavedChangesNothingAndSaysSo() {
    struct ReadOnly: Error, CustomStringConvertible { var description = "the file is read-only" }
    let h = Harness()
    h.controller.saveSettings = { _, _ in throw ReadOnly() }
    h.start()
    let result = h.run("toggle-auto-dock")
    #expect(!result.ok)
    #expect(result.message.contains("nothing was changed"))
    #expect(result.message.contains("the file is read-only"))
    // What is in use is what the file says (F12).
    #expect(h.controller.settings.newWindows == "float")
    #expect(h.isFloating(h.open("Safari")))
  }

  @Test func theSettingAndTheRuleCanBeWrittenAsCommands() {
    let h = Harness()
    h.start()
    #expect(h.run("set newWindows dock").ok)
    #expect(h.isDocked(h.open("Safari")))
    #expect(!h.run("set newWindows tile").ok)
    #expect(h.run("set newWindows float").ok)
    #expect(h.run("rule add * dock auto").ok)
    #expect(h.run("rule add com.jetbrains.* float").ok)
    #expect(!h.run("rule add com.*.idea float").ok)
    #expect(h.controller.settings.rules == [
      AppRule(app: "*", action: .dockAuto), AppRule(app: "com.jetbrains.*", action: .float),
    ])
    #expect(h.isDocked(h.open("Mail")))
  }

  @Test func theSwitchHasNoShortcutByDefault() {
    #expect(!KeyBindings.effective(settings: Settings()).bindings.contains { $0.command == .toggleAutoDock })
  }

  // MARK: 16. Hands off while the mouse is arranging

  @Test func nothingDocksWhileAWindowIsBeingDragged() throws {
    let h = harness()
    h.start()
    let (a, b) = (h.open("Safari"), h.open("Mail"))
    let frames = h.layout?.windowFrames
    h.system.mouseDown = true
    h.system.heldModifiers = DragDocks.key
    h.controller.dragBegan(b, at: CGPoint(x: h.rect(b).midX, y: h.rect(b).minY + 10))
    h.system.clearFrameLog()
    let n = h.open("Notes")
    #expect(h.isFloating(n))
    #expect(h.system.frameLog.isEmpty)
    #expect(h.layout?.windowFrames == frames)
    #expect(h.isDocked(a))
  }

  @Test func aTabTornOffWithTheMouseStaysInTheHandThatHoldsIt() {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    h.system.clearFrameLog()
    // The browser makes the window under the pointer, with the button still down.
    h.system.mouseDown = true
    let torn = h.open("Safari", frame: CGRect(x: 500, y: 300, width: 900, height: 600))
    #expect(h.isFloating(torn))
    #expect(h.system.frameLog.isEmpty)
    // Dropped at the left edge of the screen, it docks there like any dragged window.
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(torn, through: [CGPoint(x: 950, y: 310), CGPoint(x: 400, y: 400), CGPoint(x: 2, y: 450)])
    #expect(h.isDocked(torn))
    #expect(h.rect(torn).minX < h.rect(a).minX)
  }

  // MARK: 17. Afterwards

  @Test func closingTheWindowGivesItsRoomBack() {
    let h = harness()
    h.start()
    h.open("Safari")
    h.open("Mail")
    let (workspace, frames) = (h.workspace, h.layout?.windowFrames)
    let n = h.open("Notes")
    #expect(h.layout?.windowFrames != frames)
    h.system.close(n)
    #expect(h.layout?.windowFrames == frames)
    #expect(h.workspace.tree.allWindows == workspace.tree.allWindows)
    h.expectAllInPlace()
  }

  @Test func arborDoesNotTakeTheKeyboardForTheNewWindow() {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    // Opened by an app in the background.
    let n = h.openQuietly("Mail")
    #expect(h.isDocked(n))
    #expect(h.system.focused == a)
  }

  @Test func theArrangementIsSaved() {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    h.scheduler.runPending()
    #expect(h.store.saved?.workspaces[h.display]?.tree.allWindows == [a])
  }

  // MARK: 18. Who asked for the window has the first word

  @Test func aWindowThatWasSummonedComesOverTheViewAndDoesNotDock() throws {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    let before = h.workspace.tree
    #expect(h.run("summon Terminal").message == "opening Terminal")
    let t = h.open("Terminal")
    #expect(h.isFloating(t))
    #expect(h.workspace.summoned?.window == t)
    #expect(h.workspace.tree == before)
    // Its second window was not asked for by `summon`: it is a new window like any other.
    let second = h.open("Terminal")
    #expect(h.isDocked(second))
    #expect(h.isDocked(a))
  }

  @Test func aRuleThatNamesTheAppStillDocksTheSummonedWindow() {
    let h = harness(rules: [AppRule(app: "com.example.terminal", action: .dock(.left))])
    h.start()
    h.open("Safari")
    h.run("summon Terminal")
    #expect(h.isDocked(h.open("Terminal")), "the person wrote where this app's windows go")
  }

  @Test func anArrangementThatWaitsForItsWindowsIsLeftAsItWasWritten() {
    let h = harness()
    h.start()
    let a = h.open("Safari")
    h.run("layout --open Safari | Mail | Notes")
    let m = h.open("Mail")
    let stranger = h.open("Terminal")
    #expect(h.isFloating(stranger), "docking it would be the end of the wait")
    let n = h.open("Notes")
    #expect(h.rect(a).maxX <= h.rect(m).minX && h.rect(m).maxX <= h.rect(n).minX)
    #expect(h.rect(a).height == h.rect(m).height && h.rect(m).height == h.rect(n).height)
    // Everyone has come.
    #expect(h.isDocked(h.open("Calendar")))
  }

  @Test func aWindowThatOpensOverAFullScreenWindowFloats() {
    let h = harness()
    h.start()
    let (a, b) = (h.open("Safari"), h.open("Mail"))
    h.system.setFullScreen(b, true)
    h.system.setOnActiveSpace(a, false)
    h.scheduler.advance(by: 2)
    let draft = h.open("Mail")
    #expect(h.isFloating(draft))
    #expect(h.frame(draft) == opening)
    h.system.close(draft)
    h.system.setFullScreen(b, false)
    h.system.setOnActiveSpace(a, true)
    h.scheduler.advance(by: 2)
    #expect(h.isDocked(h.open("Notes")))
  }

  // MARK: Tiles that are there already

  @Test func aFocusedWindowThatIsATileIsNotANeighbour() throws {
    let h = harness(newWindows: "float")
    h.start()
    let a = h.open("Safari")
    let b = h.open("Notes", minimumSize: CGSize(width: 900, height: 100))
    h.run("dock \(a.rawValue) right")
    h.run("dock \(b.rawValue) left")
    #expect(h.layout?.tiles.map(\.windows) == [[b]])
    h.run("toggle-auto-dock")
    h.controller.windowFocused(b)  // a report from the background: the keyboard stays with Safari
    let n = h.openQuietly("Mail")
    #expect(h.rect(n).minY > h.rect(a).maxY)
    #expect(h.layout?.tiles.map(\.windows) == [[b]], "the tile that was there is still the only one")
  }

  // MARK: Anything goes

  /// Opening a window never costs a window its place in view, whatever came before.
  /// The seeds after the twelfth found something once: a Desktop that was owed room (F61), paid when a window opened. That was
  /// with a column for the Desktop, so each sequence is played with and without.
  @Test(arguments: Array(1...12) + [164, 332, 385, 565], [false, true])
  func noSequenceOfEventsMakesAnOpeningWindowHideAnother(seed: UInt64, desktopColumn: Bool) {
    var state = seed &* 0x9E37_79B9_7F4A_7C15
    func random(_ bound: Int) -> Int {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((state >> 33) % UInt64(bound))
    }
    let h = harness(
      displays: seed % 2 == 0 ? [FakeWindowSystem.standardDisplay, side] : [FakeWindowSystem.standardDisplay],
      desktopColumn: desktopColumn
    ) {
      $0.tabsEnabled = seed % 3 == 0
      $0.makeRoom = seed % 4 < 2
    }
    h.start()
    var open: [WindowID] = []
    for step in 0..<120 {
      switch random(12) {
      case 0...4:
        let showing = h.controller.layouts.mapValues { Set($0.windowFrames.keys) }
        // An empty Desktop may become a tile where room is made (F61).
        let tiles = h.controller.layouts.mapValues { $0.tiles.filter { $0.kind != .desktop }.count }
        let desktops = h.controller.layouts.mapValues { $0.desktopFrame != nil }
        let cameras = h.controller.workspaces.mapValues(\.camera)
        let size = CGSize(width: 200 + random(900), height: 150 + random(600))
        let origin = CGPoint(x: random(h.system.displayList.count == 2 ? 2600 : 700), y: 40 + random(200))
        let minimum = random(3) == 0 ? CGSize(width: random(Int(size.width)), height: random(Int(size.height))) : .zero
        h.system.echoes.keyboard = random(4) != 0
        let id = h.system.open(
          app: "App\(random(4))", frame: CGRect(origin: origin, size: size), minimumSize: minimum,
          isResizable: random(6) != 0)
        h.system.echoes.keyboard = true
        open.append(id)
        for (display, layout) in h.controller.layouts {
          let tabbed = h.controller.settings.tabsEnabled ? 1 : 0
          let lost = (showing[display] ?? []).subtracting(layout.windowFrames.keys)
          #expect(lost.count <= tabbed, "step \(step): \(lost) went out of view when \(id) opened")
          #expect(
            layout.tiles.filter { $0.kind != .desktop }.count <= tiles[display] ?? 0,
            "step \(step): a tile appeared when \(id) opened")
          // Where the Desktop is only what is left over, the window may have taken all of it: then there is no tile for it either.
          if !h.controller.settings.makeRoom, desktops[display] == true,
            h.controller.workspaces[display]?.tree.desktopHasRoom == true
          {
            #expect(layout.desktopFrame != nil, "step \(step): the Desktop became a tile when \(id) opened")
          }
        }
        if !h.isDocked(id) { #expect(h.controller.workspaces.mapValues(\.camera) == cameras, "step \(step)") }
      case 5:
        if !open.isEmpty { h.system.close(open.remove(at: random(open.count))) }
      case 6:
        if !open.isEmpty { h.system.userFocus(open[random(open.count)]) }
      case 7:
        h.run(["out", "in", "show-all", "desktop", "zoom", "neighbor left", "neighbor right", "back"][random(8)])
      case 10, 11:
        if !open.isEmpty {
          let w = open[random(open.count)].rawValue
          h.run(
            [
              "pin \(w)", "unpin \(w)", "float \(w)", "dock \(w) left", "dock \(w) bottom", "arrange", "summon App\(random(4))",
              "resize \(w) right 120", "resize \(w) bottom -90", "name work", "go work", "float-all", "toggle-float \(w)",
              "save-view 1", "view 1",
            ][random(15)])
        }
      case 8:
        if !open.isEmpty { h.system.setMinimized(open[random(open.count)], random(2) == 0) }
      default:
        h.scheduler.advance(by: Double(random(20)) / 10)
      }
      for workspace in h.controller.workspaces.values {
        #expect(workspace.tree.invariantViolations() == [], "step \(step)")
      }
      let places = h.controller.workspaces.values.flatMap(\.allWindows)
      #expect(Set(places).count == places.count, "step \(step): a window is in two places")
    }
  }
}
