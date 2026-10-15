import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// F62 through the real controller: commands, events and frames.
@MainActor @Suite struct GroupIdentityControllerTests {
  /// [ (Mail / (Notes | Safari)) | Desktop | Slack ], nothing small enough to be a tile.
  private func harness() -> (h: Harness, mail: WindowID, notes: WindowID, safari: WindowID, slack: WindowID) {
    var settings = Settings()
    settings.minimumUsableWidth = 40
    settings.minimumUsableHeight = 40
    let h = Harness(settings: settings)
    let mail = h.system.open(app: "Mail")
    let notes = h.system.open(app: "Notes")
    let safari = h.system.open(app: "Safari")
    let slack = h.system.open(app: "Slack")
    h.start()
    h.run("dock \(mail.rawValue) left")
    h.run("dock \(slack.rawValue) right")
    h.run("dock \(notes.rawValue) beside \(mail.rawValue) bottom")
    h.run("dock \(safari.rawValue) beside \(notes.rawValue) right")
    return (h, mail, notes, safari, slack)
  }

  private func inView(_ h: Harness) -> Set<WindowID> { Set(h.layout!.windowFrames.keys) }

  @Test func closingTheWindowBesideAFramedGroupLeavesTheViewOnTheGroup() {
    let (h, mail, notes, safari, _) = harness()
    let pair = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: notes)!)!
    h.run("zoom-node \(pair.rawValue)")
    #expect(inView(h) == [notes, safari])
    let before = [h.frame(notes), h.frame(safari)]
    h.system.close(mail)
    #expect(inView(h) == [notes, safari], "the view used to jump to everything")
    #expect([h.frame(notes), h.frame(safari)] == before, "and nothing in view moves")
  }

  /// A pair in a row on its own axis, framed. By command and by drag, one goes to the other side of the other.
  @Test func rearrangingAFramedPairBringsNothingElseIntoView() {
    let (h, mail, _, _, slack) = harness()
    h.run("zoom \(slack.rawValue)")
    h.run("dock \(mail.rawValue) left")  // mail | slack, a group of their own in the top row
    #expect(inView(h) == [mail, slack] && h.frame(mail)!.maxX <= h.frame(slack)!.minX)
    let pair = h.workspace.camera

    #expect(h.run("dock \(mail.rawValue) beside \(slack.rawValue) right").ok)
    #expect(inView(h) == [mail, slack], "the view used to widen to everything")
    #expect(h.workspace.camera == pair && h.frame(slack)!.maxX <= h.frame(mail)!.minX)

    let (grab, target) = (h.frame(mail)!, h.frame(slack)!)
    h.system.drag(mail, through: [
      CGPoint(x: grab.midX, y: grab.minY + 10), CGPoint(x: target.midX, y: target.midY),
      CGPoint(x: target.minX + 40, y: target.midY),
    ])
    #expect(inView(h) == [mail, slack] && h.workspace.camera == pair)
    #expect(h.frame(mail)!.maxX <= h.frame(slack)!.minX)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// A group the view has left lasts until the next change to the arrangement, and a window leaving the display is
  /// one, also a floating window. The group then dissolves into the row, which moves its windows by half a gap:
  /// on the display the window has left, where nothing used to be laid out unless the window had been docked.
  @Test func aFloatingWindowDraggedToAnotherDisplayLeavesTheOneItLeftLaidOut() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
    var settings = Settings()
    settings.minimumUsableWidth = 40
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side], settings: settings)
    let (mail, slack, notes) = (h.system.open(app: "Mail"), h.system.open(app: "Slack"), h.system.open(app: "Notes"))
    h.start()
    h.run("dock \(mail.rawValue) left")
    h.run("dock \(slack.rawValue) right")
    h.run("zoom \(slack.rawValue)")
    h.run("dock \(notes.rawValue) left")  // notes | slack, a group of their own in the top row
    let pair = h.workspace.camera
    let floating = h.system.open(app: "Floating", frame: CGRect(x: 400, y: 300, width: 400, height: 300))
    h.run("show-all")
    #expect(h.workspace.tree.contains(pair), "moving the view changes nothing in the arrangement")

    h.system.drag(floating, through: [CGPoint(x: 600, y: 310), CGPoint(x: 1300, y: 400), CGPoint(x: 2000, y: 400)])
    #expect(h.controller.workspaceID(containing: floating) == side.id)
    let (tree, layout) = (h.workspace.tree, h.layout!)
    #expect(!tree.contains(pair), "nothing keeps it now")
    #expect(layout.nodeFrames.keys.allSatisfy { tree.contains($0) }, "the layout is of a tree that is gone")
    #expect(tree.contains(layout.camera))
    let before = [mail, slack, notes].map { h.frame($0) }
    h.run("out")  // changes nothing, and lays out
    h.controller.displaysChanged()
    #expect([mail, slack, notes].map { h.frame($0) } == before, "nothing was waiting for the next layout")
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// `[ Mail | Desktop | (Notes | Slack) | Safari ]` in view, with a view saved on the pair, which keeps it a group.
  private func rowWithAKeptPair() -> (h: Harness, mail: WindowID, notes: WindowID, slack: WindowID, safari: WindowID) {
    var settings = Settings()
    settings.minimumUsableWidth = 40
    let h = Harness(settings: settings)
    let mail = h.system.open(app: "Mail"), notes = h.system.open(app: "Notes")
    let slack = h.system.open(app: "Slack"), safari = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(mail.rawValue) left")
    h.run("dock \(slack.rawValue) right")
    h.run("zoom \(slack.rawValue)")
    h.run("dock \(notes.rawValue) left")
    h.run("save-view 1")
    h.run("show-all")
    h.run("dock \(safari.rawValue) right")
    let tree = h.workspace.tree
    #expect(tree.children(of: tree.root).count == 4)
    #expect(tree.windows(under: h.workspace.savedView(slot: 1)!) == [notes, slack])
    return (h, mail, notes, slack, safari)
  }

  /// The three ways to move the boundary between Slack and Safari: the gap, the command, and either window's own edge.
  @Test(arguments: ["gap", "resize", "resize the other", "edge", "edge of the other"])
  func theBoundaryAfterAKeptGroupMovesOnlyTheTwoWindowsBesideIt(way: String) {
    let (h, mail, notes, slack, safari) = rowWithAKeptPair()
    let before = [mail, notes, slack, safari].map { h.frame($0)! }
    let desktop = h.layout!.desktopFrame
    switch way {
    case "gap":
      let gap = h.layout!.seams.first { $0.trailing == h.workspace.tree.leaf(containing: safari) }!
      h.overlays.dragSeam(gap, by: 50)
    case "resize": #expect(h.run("resize \(slack.rawValue) right 50").ok)
    case "resize the other": #expect(h.run("resize \(safari.rawValue) left -50").ok)
    case "edge":
      var frame = before[2]
      frame.size.width += 50
      h.system.userResize(slack, to: frame)
    default:
      var frame = before[3]
      frame.origin.x += 50
      frame.size.width -= 50
      h.system.userResize(safari, to: frame)
    }
    #expect(h.frame(mail) == before[0] && h.layout!.desktopFrame == desktop)
    #expect(h.frame(notes) == before[1], "the other window of the group used to grow as well")
    var (wider, narrower) = (before[2], before[3])
    wider.size.width += 50
    narrower.origin.x += 50
    narrower.size.width -= 50
    #expect(h.frame(slack) == wider && h.frame(safari) == narrower)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aSavedViewOfAGroupComesBackToThatGroup() {
    let (h, mail, notes, safari, slack) = harness()
    let pair = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: notes)!)!
    h.run("zoom-node \(pair.rawValue)")
    h.run("save-view 1")
    h.run("show-all")
    h.system.close(mail)
    #expect(inView(h) == [notes, safari, slack])
    #expect(h.run("view 1").ok)
    #expect(inView(h) == [notes, safari])
  }

  /// T01. [Mail… | Desktop | Slack] with the view on Slack: a window docked at the right edge of the
  /// view used to become one more in the row, and the view widened to everything.
  @Test func dockingAtTheEdgeOfTheViewShowsTheViewAndTheNewcomer() {
    let (h, _, _, _, slack) = harness()
    let terminal = h.system.open(app: "Terminal")
    h.run("zoom \(slack.rawValue)")
    #expect(inView(h) == [slack])
    #expect(h.run("dock \(terminal.rawValue) right").ok)
    #expect(inView(h) == [slack, terminal])
    #expect(h.frame(slack)!.maxX < h.frame(terminal)!.minX)
    #expect(h.frame(slack)!.minX == h.visibleFrame.minX + 12 && h.frame(terminal)!.maxX == h.visibleFrame.maxX - 12)
    // Stepping out shows the two where they would have been: side by side in Slack's old place.
    h.run("show-all")
    #expect(h.frame(slack)!.maxX < h.frame(terminal)!.minX)
    #expect(h.workspace.tree.invariantViolations() == [])
  }

  /// Seen from outside, the end of a kept group and the next place along the row are the same place.
  /// As with any group, the first press takes the window out of it, which shows in its size.
  @Test func everyKeyboardMoveAlongARowChangesSomethingToSee() {
    let (h, mail, notes, safari, slack) = harness()
    let pair = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: notes)!)!
    h.run("zoom-node \(pair.rawValue)")
    h.run("save-view 1")
    h.run("show-all")
    h.system.close(mail)
    #expect(h.workspace.tree.windows(under: pair) == [notes, safari])
    h.system.userFocus(safari)

    /// The row from left to right, the Desktop as nil.
    func row() -> [WindowID?] {
      var places: [(WindowID?, CGFloat)] = [notes, safari, slack].map { ($0, h.frame($0)!.minX) }
      places.append((nil, h.layout!.desktopFrame!.minX))
      return places.sorted { $0.1 < $1.1 }.map(\.0)
    }
    var rows: [[WindowID?]] = []
    while rows.count < 6 {
      let before = [notes, safari, slack].map { h.frame($0) }
      guard h.run("dock \(safari.rawValue) right").ok else { break }
      #expect([notes, safari, slack].map { h.frame($0) } != before, "a key that says it moved the window and moves nothing")
      #expect(h.workspace.tree.invariantViolations() == [])
      rows.append(row())
    }
    #expect(rows == [[notes, safari, nil, slack], [notes, nil, safari, slack], [notes, nil, slack, safari]])
    // The group is down to Notes, and the saved view with it.
    #expect(h.run("view 1").ok)
    #expect(inView(h) == [notes])
  }

  @Test func theArrangementWithAKeptGroupSurvivesARestart() {
    let (h, mail, notes, safari, _) = harness()
    let pair = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: notes)!)!
    h.run("zoom-node \(pair.rawValue)")
    h.system.close(mail)
    h.controller.saveNow()

    var settings = Settings()
    settings.minimumUsableWidth = 40
    settings.minimumUsableHeight = 40
    let again = Harness(settings: settings, saved: h.store.saved)
    for app in ["Mail", "Notes", "Safari", "Slack"] { again.system.open(app: app) }
    again.system.close(mail)
    again.start()
    #expect(again.workspace.tree == h.workspace.tree)
    // A launch shows everything; the view of last time is one step back.
    #expect(again.run("back").ok)
    #expect(inView(again) == [notes, safari])
  }
}
