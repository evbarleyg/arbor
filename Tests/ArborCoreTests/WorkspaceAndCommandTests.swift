import ArborCore
import CoreGraphics
import Foundation
import Testing

private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)

@Suite struct WorkspaceTests {
  @Test func dockingTheFirstWindowKeepsItInView() {
    // Regression: the camera starts on the Desktop leaf (the root). The
    // first dock wraps it, and the camera must widen to the new root.
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    #expect(workspace.camera == workspace.tree.root)
    workspace.dock(b, at: .cameraEdge(.right))
    #expect(workspace.camera == workspace.tree.root)
    #expect(workspace.tree.children(of: workspace.tree.root).count == 3)
  }

  @Test func dockingRemovesTheWindowFromFloating() {
    var workspace = Workspace()
    workspace.floating[a] = CGRect(x: 0, y: 0, width: 100, height: 100)
    workspace.dock(a, at: .cameraEdge(.left))
    #expect(!workspace.isFloating(a))
    #expect(workspace.isDocked(a))
  }

  @Test func historyGoesBackAndForward() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    let root = workspace.tree.root
    let leaf = workspace.tree.leaf(containing: a)!
    workspace.moveCamera(to: leaf)
    let wentBack = workspace.goBack()
    #expect(wentBack)
    #expect(workspace.camera == root)
    let wentForward = workspace.goForward()
    #expect(wentForward)
    #expect(workspace.camera == leaf)
    let wentFurther = workspace.goForward()
    #expect(!wentFurther)
  }

  @Test func historySkipsNodesThatNoLongerExist() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    let leafA = workspace.tree.leaf(containing: a)!
    workspace.moveCamera(to: leafA)
    workspace.moveCamera(to: workspace.tree.root)
    workspace.forget(a)
    #expect(workspace.tree.contains(workspace.camera))
    while workspace.goBack() {
      #expect(workspace.tree.contains(workspace.camera))
    }
  }

  @Test func savedViewsFollowRemaps() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    let leaf = workspace.tree.leaf(containing: a)!
    workspace.dock(c, at: .beside(leaf, .bottom))
    let column = workspace.tree.parent(of: leaf)!
    workspace.moveCamera(to: column)
    workspace.saveView(slot: 2)
    workspace.forget(c)
    let saved = workspace.savedView(slot: 2)
    #expect(saved == workspace.tree.leaf(containing: a))
  }

  @Test func historyAndSavedViewsOfAWindowFollowItWhenItIsDockedElsewhere() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(c, at: .beside(workspace.tree.leaf(containing: a)!, .bottom))
    let root = workspace.tree.root
    workspace.moveCamera(to: workspace.tree.leaf(containing: c)!)
    workspace.saveView(slot: 1)
    workspace.moveCamera(to: root)
    workspace.dock(c, at: .cameraEdge(.right))
    let moved = workspace.tree.leaf(containing: c)!
    #expect(workspace.savedView(slot: 1) == moved)
    #expect(workspace.back.last == moved)
    #expect(workspace.camera == workspace.tree.root)
  }

  @Test func aRetractedMoveLeavesNothingToGoForwardTo() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    let root = workspace.tree.root
    let leaf = workspace.tree.leaf(containing: a)!
    workspace.moveCamera(to: leaf)
    workspace.moveCamera(to: workspace.tree.desktop)
    let first = workspace.retractLastMove()
    #expect(first)
    #expect(workspace.camera == leaf)
    #expect(workspace.back == [root])
    #expect(workspace.forward.isEmpty)
    let second = workspace.retractLastMove()
    let third = workspace.retractLastMove()
    #expect(second && !third)
    #expect(workspace.camera == root)
  }

  @Test func showingEverythingLeavesNothingOutOfViewAndLosesNothing() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    let (root, left, right) = (workspace.tree.root, workspace.tree.leaf(containing: a)!, workspace.tree.leaf(containing: b)!)
    workspace.floating[c] = CGRect(x: 10, y: 10, width: 300, height: 200)
    workspace.summon(c, app: "C", at: CGRect(x: 40, y: 40, width: 300, height: 200))
    workspace.dismissSummon()
    workspace.moveCamera(to: left)
    workspace.saveView(slot: 1)
    workspace.moveCamera(to: right)
    workspace.moveCamera(to: workspace.tree.desktop)
    _ = workspace.goBack()
    let before = workspace
    #expect(!before.forward.isEmpty)

    workspace.showEverything()
    #expect(workspace.camera == root)
    #expect(workspace.back == [root, left, right], "the view it had is one step back")
    #expect(workspace.forward.isEmpty, "as after any move of the view")
    #expect(workspace.role(of: c) == nil && workspace.floating[c] == before.floating[c])
    #expect(workspace.tree == before.tree && workspace.savedViews == before.savedViews)
    #expect(workspace.summonFrames == before.summonFrames, "where it was summoned is still known")

    // With everything showing already, and nothing sent away, it changes nothing.
    let shown = workspace
    workspace.showEverything()
    #expect(workspace == shown)
  }

  @Test func guestsFollowTheirHostAndLeaveWithIt() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(c, at: .beside(workspace.tree.leaf(containing: a)!, .bottom))
    let guest = WindowID(9)
    workspace.receive(guest, asGuestOf: workspace.tree.leaf(containing: c)!)
    #expect(workspace.guests == nil, "only a floating window can be a guest")
    workspace.floating[guest] = .zero
    workspace.receive(guest, asGuestOf: workspace.tree.leaf(containing: c)!)
    workspace.dock(c, at: .cameraEdge(.right))
    #expect(workspace.guests == [guest: workspace.tree.leaf(containing: c)!], "the host was docked elsewhere")
    workspace.forget(a)
    #expect(workspace.guests?[guest] != nil, "another window closing changes nothing")
    workspace.forget(c)
    #expect(workspace.guests == nil, "the host is gone")
    #expect(workspace.isFloating(guest))
  }

  @Test func aGroupLeftWithOneMemberHandsItItsGuests() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    workspace.dock(c, at: .beside(workspace.tree.leaf(containing: b)!, .bottom))
    let group = workspace.tree.parent(of: workspace.tree.leaf(containing: b)!)!
    let guest = WindowID(9)
    workspace.floating[guest] = .zero
    workspace.receive(guest, asGuestOf: group)
    workspace.saveView(slot: 2)
    workspace.forget(a)
    #expect(workspace.guests == [guest: group], "a window outside the group changes nothing")
    workspace.forget(c)
    #expect(!workspace.tree.contains(group))
    #expect(workspace.guests == [guest: workspace.tree.leaf(containing: b)!])
    workspace.forget(b)
    #expect(workspace.guests == nil)
  }

  @Test func anUnknownWayToTreatNewWindowsIsNamed() throws {
    let settings = try Settings.read(Data(#"{"newWindowsWhileFramed": "flaot"}"#.utf8))
    #expect(settings.newWindowsWhileFramed == "guest")
    #expect(settings.valueProblems.contains { $0.contains("flaot") })
  }

  @Test func aGuestThatStopsFloatingHereIsNoGuestFromThatMoment() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    let guest = WindowID(9)
    workspace.floating[guest] = .zero
    workspace.receive(guest, asGuestOf: workspace.tree.leaf(containing: a)!)
    // It was moved to another display, whose workspace has it now.
    workspace.floating[guest] = nil
    #expect(workspace.guests == nil, "what is saved now must not name a guest that is not here")
  }

  @Test func aVisitEndsWhenTheGuestIsDockedForgottenOrGone() {
    let guest = WindowID(9)
    func visiting() -> Workspace {
      var workspace = Workspace()
      workspace.dock(a, at: .cameraEdge(.left))
      workspace.floating[guest] = .zero
      workspace.receive(guest, asGuestOf: workspace.tree.leaf(containing: a)!)
      return workspace
    }
    var docked = visiting()
    docked.dock(guest, at: .cameraEdge(.right))
    #expect(docked.guests == nil)
    var forgotten = visiting()
    forgotten.forget(guest)
    #expect(forgotten.guests == nil)
    var moved = visiting()
    moved.floating[guest] = nil
    moved.dropGuestsThatLeft()
    #expect(moved.guests == nil)
    var reset = visiting()
    reset.reset(tree: LayoutTree())
    #expect(reset.guests == nil)
  }

  @Test func previewMatchesTheRealDrop() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    let options = LayoutOptions()
    let preview = workspace.previewFrame(
      for: b, at: .cameraEdge(.right), in: screen, options: options, isPresent: { _ in true })
    workspace.dock(b, at: .cameraEdge(.right))
    let layout = LayoutEngine.layout(
      workspace.tree, camera: workspace.camera, in: screen, options: options, isPresent: { _ in true })
    #expect(preview != nil, "two missing frames would be equal as well")
    #expect(preview == layout.windowFrames[b])
  }

  @Test func aWorkspaceSurvivesCoding() throws {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.floating[b] = CGRect(x: 10, y: 20, width: 300, height: 200)
    workspace.saveView(slot: 1)
    let data = try JSONEncoder().encode(workspace)
    #expect(try JSONDecoder().decode(Workspace.self, from: data) == workspace)
    // Window and node keys encode as JSON object keys, not arrays.
    let json = String(decoding: data, as: UTF8.self)
    #expect(json.contains("\"2\""))
  }
}

@Suite struct CommandTests {
  static let samples: [Command] = [
    .status, .state, .ascii, .showAll, .stepOut, .stepIn, .neighbor(.left), .neighbor(.bottom), .back,
    .forward, .zoom(nil), .zoom(WindowID(42)), .zoomNode(NodeID(3)), .desktop, .saveView(4), .goToView(9),
    .dock(nil, .right), .dock(WindowID(7), .top), .dockBeside(nil, target: WindowID(8), .left),
    .dockBeside(WindowID(7), target: WindowID(8), .bottom), .float(nil), .float(WindowID(5)),
    .toggleFloat(nil), .arrange, .floatAll, .resize(nil, .right, 40), .resize(WindowID(3), .left, -25.5),
    .exclude(bundleID: nil), .exclude(bundleID: "com.apple.Music"), .include(bundleID: "com.apple.Music"),
    .relayout, .reloadSettings, .quit, .trace(.on(name: nil)), .trace(.on(name: "safari-drag")), .trace(.off),
  ]

  @Test(arguments: samples) func textRoundTrips(command: Command) throws {
    #expect(try Command.parse(command.text) == command)
  }

  @Test func acceptsAliasesAndURLPaths() throws {
    #expect(try Command.parse("go up") == .neighbor(.top))
    #expect(try Command.parse("dock/left") == .dock(nil, .left))
    #expect(try Command.parse("zoom w412") == .zoom(WindowID(412)))
    #expect(try Command.parse("view/3") == .goToView(3))
    #expect(try Command.parse("Show-All") == .showAll)
  }

  @Test func rejectsBadInput() {
    #expect(throws: Command.ParseError.self) { try Command.parse("") }
    #expect(throws: Command.ParseError.self) { try Command.parse("dock sideways") }
    #expect(throws: Command.ParseError.self) { try Command.parse("view 0") }
    #expect(throws: Command.ParseError.self) { try Command.parse("teleport") }
    #expect(throws: Command.ParseError.self) { try Command.parse("show-all now") }
  }

  @Test func resizeAmountsAreBounded() throws {
    #expect(try Command.parse("resize right 1000000") == .resize(nil, .right, 1_000_000))
    #expect(try Command.parse("resize 7 left -1000000") == .resize(WindowID(7), .left, -1_000_000))
    #expect(try Command.parse("resize right 1e3") == .resize(nil, .right, 1000))
    for amount in ["1e300", "-1e300", "1000001", "-1000000.5", "inf", "-inf", "infinity", "nan", "wide", ""] {
      #expect(throws: Command.ParseError.self, "\(amount)") { try Command.parse("resize right \(amount)") }
      #expect(throws: Command.ParseError.self, "\(amount)") { try Command.parse("resize 7 right \(amount)") }
    }
  }

  /// `text` is logged for every command, so it must survive values `parse` would never produce.
  @Test func anyAmountHasATextForm() {
    #expect(Command.resize(nil, .right, 40).text == "resize right 40")
    #expect(Command.resize(nil, .right, -0.5).text == "resize right -0.5")
    #expect(Command.resize(nil, .right, 1e300).text == "resize right 1e+300")
    #expect(Command.resize(nil, .right, -1e19).text == "resize right -1e+19")
    #expect(Command.resize(nil, .right, .infinity).text == "resize right inf")
    #expect(Command.resize(nil, .right, .nan).text == "resize right nan")
    #expect(Command.frameRect(x: 1e300, y: -.infinity, width: .nan, height: 1).text == "frame-rect 1e+300 -inf nan 1")
  }

  @Test func bundleIDsKeepTheirCase() throws {
    #expect(try Command.parse("exclude com.Apple.Music") == .exclude(bundleID: "com.Apple.Music"))
  }
}

@Suite struct SettingsTests {
  @Test func missingKeysTakeDefaults() throws {
    let settings = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 20, "unknown": true}"#.utf8))
    #expect(settings.gap == 20)
    #expect(settings.minimumUsableWidth == Settings().minimumUsableWidth)
    #expect(settings.hotkeysEnabled)
  }

  @Test func roundTrips() throws {
    var settings = Settings()
    settings.excludedBundleIDs = ["com.apple.Music"]
    settings.tabsEnabled = true
    let data = try JSONEncoder().encode(settings)
    #expect(try JSONDecoder().decode(Settings.self, from: data) == settings)
  }
}
