import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

/// What an independent review of `layout` (F54) found, and behaviour it pins where `layout` meets its neighbours.
@Suite @MainActor struct ReviewLayoutTests {
  func w(_ id: UInt32) -> WindowID { WindowID(id) }

  let safariFrame = CGRect(x: 120, y: 90, width: 700, height: 500)
  let mailFrame = CGRect(x: 400, y: 200, width: 520, height: 380)
  let notesFrame = CGRect(x: 820, y: 300, width: 400, height: 300)

  /// Safari (101), Mail (102) and Notes (103), floating, each at a size of its own.
  func harness(displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay]) -> Harness {
    let h = Harness(displays: displays)
    h.system.open(app: "Safari", frame: safariFrame)
    h.system.open(app: "Mail", frame: mailFrame)
    h.system.open(app: "Notes", frame: notesFrame)
    h.start()
    return h
  }

  // MARK: A window that leaves the arrangement gets its own size back (F48)

  @Test func windowsDockedByALineGoBackToWhereTheyWere() {
    let h = harness()
    #expect(h.run("layout Safari | Mail | Notes").ok)
    #expect(h.workspace.floating.isEmpty)
    #expect(h.run("float-all").ok)
    #expect(h.frame(w(101)) == safariFrame)
    #expect(h.frame(w(102)) == mailFrame)
    #expect(h.frame(w(103)) == notesFrame)
  }

  @Test func quittingAfterALinePutsEveryWindowBackWhereItWas() {
    let h = harness()
    #expect(h.run("layout Safari | (Mail / Notes)").ok)
    h.controller.shutdown()
    #expect(h.frame(w(101)) == safariFrame)
    #expect(h.frame(w(102)) == mailFrame)
    #expect(h.frame(w(103)) == notesFrame)
  }

  @Test func aWindowDockedByALineFloatsAtItsOwnSize() {
    let h = harness()
    #expect(h.run("layout Safari | Mail | Notes").ok)
    #expect(h.run("float 102").ok)
    #expect(h.frame(w(102))?.size == mailFrame.size)
  }

  @Test func aSecondLineStillRemembersWhatTheFirstDocked() {
    let h = harness()
    #expect(h.run("layout Safari | Mail | Notes").ok)
    #expect(h.run("layout Notes | (Safari / Mail)").ok)
    #expect(h.run("float-all").ok)
    #expect(h.frame(w(101)) == safariFrame)
    #expect(h.frame(w(102)) == mailFrame)
    #expect(h.frame(w(103)) == notesFrame)
  }

  @Test func aWindowALineLeavesOutFloatsAtItsOwnSize() {
    let h = harness()
    #expect(h.run("layout Safari | Mail | Notes").ok)
    #expect(h.run("layout Safari | Desktop:2").ok)
    #expect(h.frame(w(102))?.size == mailFrame.size)
    #expect(h.frame(w(103))?.size == notesFrame.size)
  }

  @Test func aWindowThatCameOverFromAnotherDisplayFloatsAtItsOwnSize() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    h.system.open(app: "Safari", frame: safariFrame)
    let onTheSide = CGRect(x: 1600, y: 120, width: 520, height: 380)
    h.system.open(app: "Mail", frame: onTheSide)
    h.start()
    #expect(h.run("layout @1 Safari | Mail").ok)
    #expect(h.workspace.isDocked(w(102)))
    #expect(h.run("float 102").ok)
    #expect(h.frame(w(102))?.size == onTheSide.size)
  }

  @Test func aLatecomerFloatsAtTheSizeItsAppGaveIt() {
    let h = harness()
    #expect(h.run("layout --open Safari | Slack").ok)
    let born = CGRect(x: 300, y: 200, width: 640, height: 420)
    let slack = h.system.open(app: "Slack", frame: born)
    #expect(h.workspace.isDocked(slack))
    #expect(h.run("float \(slack.rawValue)").ok)
    #expect(h.frame(slack)?.size == born.size)
  }

  // MARK: What is printed is read back

  /// Names people's apps really have, and names chosen to be taken for something else.
  static let awkwardNames = [
    "Desktop", "desktop", "DESKTOP", "412", "w412", "W1", "0", "1Password", "2048", "a|b", "a/b", "(x)", "[x]", "x)", "--open", "--ids", "-x", "@2", "a b",
    " a", "a ", "a\"b", "a'b", "a\"'b", "\"", "'", "\"\"", "“x”", "‘x’", "~x", "x~y", "x*", "*", "x:2", ":", "é", "e\u{301}", "שלום", "日本語", "👍🏽", "🇩🇪", "👩‍👩‍👧",
    "a\u{200F}b", "x\u{D4E}", "\u{301}x", "a\nb", "", "Code", "Visual Studio Code", "Studio Code", "Google Chrome", "Chrome", "layout", "a.b", "a_b", "a-b", "½", "٣",
    "com.example.n1", "Safari | Mail", "\"Safari | Mail\"", "'a|b'", String(repeating: "x", count: 200), String(repeating: "x", count: 201), "a%20b", "a\\b",
  ]

  /// Criterion 5, with awkward names: whatever is docked, however it got there, the line `layout` prints is read, and
  /// puts every window back into the same place. One window per app, so that names say which window is meant.
  @Test func theLinePrintedRecreatesAnyArrangementOfAwkwardlyNamedApps() throws {
    var state: UInt64 = 54
    func next(_ bound: Int) -> Int {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((state >> 33) % UInt64(bound))
    }
    for round in 0..<150 {
      let h = Harness()
      var names = Self.awkwardNames
      var ids: [WindowID] = []
      for index in 0..<(2 + next(7)) {
        ids.append(h.system.open(app: names.remove(at: next(names.count)), bundleID: next(5) == 0 ? "" : "com.example.n\(index)"))
      }
      h.start()
      for (index, id) in ids.enumerated() {
        switch (index == 0 ? 0 : next(4)) {
        case 0: h.run("dock \(id.rawValue) \(["left", "right", "top", "bottom"][next(4)])")
        case 1, 2: h.run("dock \(id.rawValue) beside \(ids[next(index)].rawValue) \(["left", "right", "top", "bottom"][next(4)])")
        default: break  // floats
        }
      }
      let exact = try #require(h.run("layout --ids").text)
      for option in ["", " --titles", " --ids"] {
        let line = try #require(h.run("layout" + option).text)
        h.run("float-all")
        let result = h.run("layout " + line)
        guard !h.workspace.tree.allWindows.isEmpty || exact != "Desktop" else { continue }
        #expect(result.ok, "round \(round): \(line.debugDescription): \(result.message)")
        #expect(h.run("layout --ids").text == exact, "round \(round): \(line.debugDescription)")
        #expect(h.run("layout" + option).text == line, "round \(round)")
      }
    }
  }

  // MARK: Opening apps

  /// `AXWindowSystem.launchApp` answers true as soon as `/usr/bin/open` has started, so for any name at all. This is what a
  /// slip of the keyboard then does. It is written down here as it is, not as it should be: see the review of #48.
  @Test func withOpenAMisspeltLineStillTakesTheArrangementApart() {
    let h = harness()
    #expect(h.run("layout Safari | Mail | Notes").ok)
    let result = h.run("layout --open Sfari | Mial")
    #expect(result.ok)
    #expect(result.message == "arranged 0 windows, floated 3; opening Sfari and Mial")
    #expect(h.workspace.tree.allWindows.isEmpty)
  }

  @Test func anAppThatNeverOpensAWindowLeavesNothingBehind() {
    let h = harness()
    #expect(h.run("layout --open Safari | Slack").ok)
    let tree = h.workspace.tree
    h.scheduler.advance(by: 61)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("layout-open") })
    #expect(h.workspace.tree == tree)
    let late = h.system.open(app: "Slack")
    #expect(h.workspace.isFloating(late))
  }

  @Test func aLatecomerAfterAnotherLineOnAnotherDisplayTookAWindowAwayFloats() {
    let h = harness(displays: [FakeWindowSystem.standardDisplay, side])
    #expect(h.run("layout @1 --open Safari | Mail | Slack").ok)
    #expect(h.run("layout @2 Mail").ok)
    let slack = h.system.open(app: "Slack")
    #expect(h.workspace.isFloating(slack))
    #expect(h.workspace.tree.allWindows == [w(101)])
  }

  @Test func aLatecomerWhoseDisplayCameBackStillFindsItsPlace() {
    let h = harness(displays: [FakeWindowSystem.standardDisplay, side])
    #expect(h.run("layout @2 --open Safari | Slack").ok)
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.system.setDisplays([FakeWindowSystem.standardDisplay, side])
    let slack = h.system.open(app: "Slack")
    var seen: [WindowID: Int] = [:]
    for workspace in h.controller.workspaces.values {
      #expect(workspace.tree.invariantViolations().isEmpty)
      for window in workspace.allWindows { seen[window, default: 0] += 1 }
    }
    #expect(seen[slack] == 1)
    #expect(seen.values.allSatisfy { $0 == 1 })
  }

  /// What macOS sends when an app restores two windows at launch, the second in the millisecond of the first.
  @Test func anAppThatOpensTwoWindowsAtOnceFillsOneSlot() {
    let h = harness()
    #expect(h.run("layout --open Safari | Slack").ok)
    let (first, second) = (h.system.open(app: "Slack"), h.system.open(app: "Slack"))
    #expect(h.workspace.isDocked(first))
    #expect(h.workspace.isFloating(second))
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("layout-open") })
  }

  @Test func aLatecomerThatIsMinimisedAtOnceKeepsItsPlace() {
    let h = harness()
    #expect(h.run("layout --open Safari | Slack").ok)
    let slack = h.system.open(app: "Slack")
    h.system.setMinimized(slack, true)
    #expect(h.workspace.isDocked(slack))
    h.system.setMinimized(slack, false)
    #expect(h.workspace.isDocked(slack))
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// With a pinned window and nothing else floating, the Desktop is as wide after a latecomer as `layout` made it.
  @Test func aLatecomerDoesNotWidenTheDesktopForAPinnedWindow() throws {
    let h = harness()
    h.system.open(app: "Zoom", frame: CGRect(x: 900, y: 500, width: 300, height: 200))
    #expect(h.run("pin 104").ok)
    #expect(h.run("layout --open Safari | Mail | Notes | Slack").ok)
    let before = h.workspace.tree[h.workspace.tree.desktop]?.weight
    let slack = h.system.open(app: "Slack")
    #expect(h.workspace.isDocked(slack))
    #expect(h.workspace.tree[h.workspace.tree.desktop]?.weight == before)
  }

  // MARK: Full screen (F30)

  @Test func aFullScreenWindowIsGivenItsPlaceAndNotMoved() {
    let h = harness()
    h.system.setFullScreen(w(102), true)
    let frame = h.frame(w(102))
    let moves = h.system.moveLog.count
    #expect(h.run("layout Safari | Mail | Notes").ok)
    #expect(h.workspace.isDocked(w(102)))
    #expect(h.frame(w(102)) == frame)
    #expect(!h.system.moveLog.dropFirst(moves).contains { $0.window == w(102) })
    h.system.setFullScreen(w(102), false)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aFullScreenWindowTheLineLeavesOutIsNotMoved() {
    let h = harness()
    #expect(h.run("layout Safari | Mail | Notes").ok)
    h.system.setFullScreen(w(102), true)
    let moves = h.system.moveLog.count
    #expect(h.run("layout Safari | Notes").ok)
    #expect(h.workspace.isFloating(w(102)))
    #expect(!h.system.moveLog.dropFirst(moves).contains { $0.window == w(102) })
  }

  // MARK: The Desktop too small to use

  @Test func windowsTheLineLeavesOutAreNotLeftInTheShapeOfTheirSlotsWhenTheDesktopIsATile() {
    let h = harness()
    #expect(h.run("layout Safari | Mail | Notes").ok)
    #expect(h.run("layout Safari | Desktop:0.01").ok)
    #expect(h.layout?.desktopFrame == nil)
    for (window, size) in [(w(102), mailFrame.size), (w(103), notesFrame.size)] where h.system.isVisible(window) {
      #expect(h.frame(window)?.size == size, "\(window)")
    }
  }

  /// From mutation testing. A window that will not shrink to the Desktop's width hangs over its edge, so only the note that it
  /// was Arbor that put it there tells later layouts that it is not there on purpose.
  @Test func aWindowThatALinePushedAsideGoesBackWhenThereIsRoomAgain() {
    let h = harness()
    let terminal = h.system.open(
      app: "Terminal", frame: CGRect(x: 300, y: 200, width: 900, height: 500), minimumSize: CGSize(width: 600, height: 300))
    let own = CGRect(x: 100, y: 150, width: 900, height: 500)
    h.system.userMove(terminal, to: own)
    #expect(h.run("layout Safari | Mail | Notes").ok)
    #expect(h.frame(terminal)?.width == 600)
    for window in [w(103), w(102), w(101)] { h.system.close(window) }
    #expect(h.frame(terminal) == own)
  }

  // MARK: What the user arranges is not for a rule to undo

  /// As for `arrange` and `float-all` (`aCommandAimedAtTheWindowEndsTheWait`). A script that opens an app and arranges at
  /// once gets here: the window has no title yet, and the rule for its title is still waiting.
  @Test(arguments: ["layout Safari | Mail", "layout Mail | Safari", "layout Safari", "layout Desktop"])
  func aRuleThatWaitsForATitleDoesNotUndoWhatALineArranged(line: String) {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.apple.mail", title: "Inbox", action: .dock(.left))]
    let h = Harness(settings: settings)
    h.system.open(app: "Safari")
    h.start()
    let mail = h.system.open(app: "Mail", bundleID: "com.apple.mail", title: "")
    #expect(h.scheduler.pendingKeys.contains("rule-title-\(mail.rawValue)"))
    #expect(h.run(line).ok)
    let arranged = h.workspace
    h.system.setTitle(mail, "Inbox")
    #expect(h.workspace == arranged)
    #expect(!h.scheduler.pendingKeys.contains("rule-title-\(mail.rawValue)"))
  }
}
