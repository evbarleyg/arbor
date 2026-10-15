import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private let notes = "com.example.notes"

@MainActor private func harness(_ rules: [AppRule], configure: (inout Settings) -> Void = { _ in }) -> Harness {
  var settings = Settings()
  settings.rules = rules
  configure(&settings)
  return Harness(settings: settings)
}

/// A rule docks a new window where it is too small to show, and the window has the keyboard, as new windows have. The view goes
/// to it. It went there in two layouts: the window became a tile and was sent to its corner, then it was fetched; and from a view
/// on one window everybody else came into view in between and left again. `make fuzz` found it, under the name of a crash.
@Suite @MainActor struct ANewWindowIsDockedInOneActTests {
  /// Safari, the Desktop and Mail, a third of the display each, at the sizes that ship. Half of Safari's third is too narrow to
  /// show a window.
  private func thirdsAndARuleThatHalvesOne(theOther: String = "Mail") -> (Harness, WindowID, WindowID) {
    let h = harness([AppRule(app: notes, action: .dockBeside(bundleID: "com.example.safari", .right))])
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: theOther)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    return (h, a, b)
  }

  @Test func itGoesStraightToWhereItEndsUp() throws {
    let (h, a, b) = thirdsAndARuleThatHalvesOne()
    h.beginStep()
    let new = h.system.open(app: "Notes")
    #expect(h.jolts.isEmpty, "\(h.jolts)")
    #expect(h.movesInStep == [new: 1, a: 1, b: 1], "it comes, they leave")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: new), "the view is on it, as it was before")
    #expect(try #require(h.layout).windowFrames[new] == h.frame(new))
    #expect(h.system.isVisible(new) && h.system.focused == new)
    expectWindowsMatchLayout(h)
  }

  /// The view is on Mail. What is out of view stays there: it came into view for the layout in between, and left again.
  @Test func fromAViewOnOneWindowNobodyElseComesAndGoes() throws {
    let (h, a, b) = thirdsAndARuleThatHalvesOne()
    let c = h.system.open(app: "Music")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    h.run("zoom \(b.rawValue)")
    let outOfView = [a: h.frame(a), c: h.frame(c)]
    h.beginStep()
    let new = h.system.open(app: "Notes")
    #expect(h.jolts.isEmpty, "\(h.jolts)")
    #expect(h.movesInStep == [new: 1, b: 1], "it comes, Mail leaves")
    for (window, frame) in outOfView { #expect(h.frame(window) == frame, "\(window) was out of view and is where it was") }
    #expect(h.system.isVisible(new) && h.system.focused == new)
    expectWindowsMatchLayout(h)
  }

  /// Found with the largest value the setting takes, where no window fits beside another.
  @Test func asTheFuzzerFoundIt() {
    let h = harness([AppRule(app: notes, action: .dock(.left))]) { $0.minimumUsableHeight = 1000 }
    let windows = ["Safari", "Mail"].map { h.system.open(app: $0) }
    h.start()
    h.run("dock \(windows[0].rawValue) left")
    h.run("dock \(windows[1].rawValue) right")
    h.beginStep()
    let new = h.system.open(app: "Notes")
    #expect(h.jolts.isEmpty, "\(h.jolts)")
    #expect(h.movesInStep[new] == 1 && h.system.isVisible(new))
    expectWindowsMatchLayout(h)
  }

  /// macOS says beforehand that its size cannot be changed, so nobody has to ask: larger than its slot and than what the
  /// neighbours can spare, it is not sent to a slot first.
  @Test func aWindowOfAFixedSizeThatFitsNowhereBesideTheOthersGoesStraightToo() {
    let (h, _, _) = thirdsAndARuleThatHalvesOne()
    h.beginStep()
    let new = h.system.open(app: "Notes", frame: CGRect(x: 100, y: 100, width: 1300, height: 600), isResizable: false)
    #expect(h.jolts.isEmpty, "\(h.jolts)")
    #expect(h.movesInStep[new] ?? 0 <= 1)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: new))
    #expect(h.system.isVisible(new) && h.frame(new)?.size == CGSize(width: 1300, height: 600))
  }

  // MARK: It ends as it did

  enum Before: String, CaseIterable {
    case nothing, aViewOnOneWindow, aWindowFloatsInView, theKeyboardsWindowHasJustGone, aDragIsUnderWay, holdingStillAndAskedFor
  }

  /// Whichever way the view got there, or did not: the same view, the same arrangement, the same windows in view, the same way
  /// back. The longer way is the one a window still goes whose keyboard comes after it.
  @Test(arguments: Before.allCases) func itEndsAsItDoesWhenTheKeyboardComesLater(before: Before) throws {
    func played(keyboardAtOnce: Bool) -> (Harness, WindowID) {
      let (h, a, b) = thirdsAndARuleThatHalvesOne()
      switch before {
      case .nothing: break
      case .aViewOnOneWindow: h.run("zoom \(b.rawValue)")
      case .aWindowFloatsInView: _ = h.system.open(app: "Books", frame: CGRect(x: 520, y: 200, width: 400, height: 300))
      case .theKeyboardsWindowHasJustGone:
        let gone = h.system.open(app: "Books", frame: CGRect(x: 520, y: 200, width: 400, height: 300))
        // Nobody inherits it: that is the loss nothing has answered yet.
        h.system.echoes.keyboard = false
        h.system.close(gone)
      case .aDragIsUnderWay:
        h.system.beginDrag(a)
        h.system.moveDrag(to: CGPoint(x: 700, y: 400))
      case .holdingStillAndAskedFor:
        h.run("hold still")
        h.system.secondsSinceInput = 0
      }
      h.system.echoes.keyboard = keyboardAtOnce
      let new = h.system.open(app: "Notes")
      if !keyboardAtOnce {
        h.system.echoes.keyboard = true
        h.system.focused = new
        h.system.backgroundFocus(new)
      }
      if before == .aDragIsUnderWay { h.system.endDrag() }
      return (h, new)
    }
    let (at, new) = played(keyboardAtOnce: true)
    let (later, _) = played(keyboardAtOnce: false)
    func same(_ what: String) {
      #expect(at.workspace.camera == later.workspace.camera, "\(what)")
      #expect(at.workspace.tree == later.workspace.tree, "\(what)")
      #expect(at.workspace.back == later.workspace.back, "\(what)")
      #expect(at.workspace.floating.keys.sorted() == later.workspace.floating.keys.sorted(), "\(what)")
      #expect(at.system.focused == later.system.focused, "\(what)")
      // What left has the size of the slot it left: by the longer way that was the slot of the layout in between.
      for window in at.workspace.allWindows {
        #expect(at.system.isVisible(window) == later.system.isVisible(window), "\(window) \(what)")
        #expect(at.frame(window)?.origin == later.frame(window)?.origin, "\(window) \(what)")
        if at.system.isVisible(window) { #expect(at.frame(window) == later.frame(window), "\(window) \(what)") }
      }
    }
    same("as it opened")
    #expect(at.workspace.isDocked(new))
    for h in [at, later] {
      h.scheduler.advance(by: 2)
      expectWindowsMatchLayout(h)
    }
    same("two seconds on")
    for h in [at, later] {
      h.run("back")
      expectWindowsMatchLayout(h)
    }
    same("after `back`")
  }

  /// The view followed the keyboard. If the window that had it goes in the same moment, macOS picked the new one and nobody asked
  /// to see it: the move is taken back, as after any report that moved the view (`keyboardLeft`). Both are one app's, which puts one
  /// window in the place of another: macOS hands the keyboard on within an app.
  @Test func theMoveIsTakenBackIfTheWindowThatHadTheKeyboardGoesInTheSameMoment() {
    let (h, a, b) = thirdsAndARuleThatHalvesOne(theOther: "Notes")
    h.system.userFocus(b)
    let view = h.workspace.camera
    let new = h.system.open(app: "Notes")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: new))
    // Its going is reported after the new window's focus. Nobody is given the keyboard for it: the new window has it.
    h.system.echoes.keyboard = false
    h.system.close(b)
    #expect(h.workspace.camera == view, "\(h.ascii())")
    #expect(h.system.isVisible(a))
    expectWindowsMatchLayout(h)
  }

  /// One undo takes the docking back, and the view with it.
  @Test func oneUndoTakesItBack() {
    let (h, a, b) = thirdsAndARuleThatHalvesOne()
    let before = h.workspace
    let new = h.system.open(app: "Notes")
    #expect(h.run("undo").ok)
    #expect(h.workspace.isFloating(new))
    #expect(h.workspace.tree == before.tree && h.workspace.camera == before.camera && h.workspace.back == before.back)
    #expect(h.system.isVisible(a) && h.system.isVisible(b))
    expectWindowsMatchLayout(h)
  }

  // MARK: Where the view stays

  @Test func whereItShowsTheViewStays() {
    let h = harness([AppRule(app: notes, action: .dock(.left))])
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(a.rawValue) right")
    h.beginStep()
    let new = h.system.open(app: "Notes")
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.jolts.isEmpty && h.movesInStep[new] == 1)
    #expect(h.system.isVisible(a) && h.system.isVisible(new))
    expectWindowsMatchLayout(h)
  }

  /// Wider than half of Safari's third by what the neighbours can spare (F61), and known to be: the layout makes room for it.
  /// Going by the slot alone the view would have gone to it, and Mail would have left.
  @Test func whereRoomWillBeMadeTheViewStays() {
    let (h, _, b) = thirdsAndARuleThatHalvesOne()
    let view = h.workspace.camera
    h.beginStep()
    let new = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 300, height: 400), isResizable: false)
    #expect(h.workspace.camera == view, "\(h.ascii())")
    #expect(h.layout?.windowFrames[new] != nil && h.system.isVisible(new) && h.system.isVisible(b))
    #expect(h.jolts.isEmpty && h.movesInStep[new] == 1, "\(h.jolts)")
  }

  /// A window that opens in the background has no keyboard, and pulls no view: a tile, as before.
  @Test func withoutTheKeyboardItIsATileAndTheViewStays() {
    let (h, _, b) = thirdsAndARuleThatHalvesOne()
    h.system.userFocus(b)
    let view = h.workspace.camera
    h.system.echoes.keyboard = false
    h.beginStep()
    let new = h.system.open(app: "Notes")
    #expect(h.workspace.isDocked(new) && h.layout?.windowFrames[new] == nil)
    #expect(h.workspace.camera == view)
    #expect(h.system.focused == b && h.system.isVisible(b))
    #expect(h.jolts.isEmpty)
    expectWindowsMatchLayout(h)
  }

  /// A rule that waited for the end of a hold docks a window that has had the keyboard for a while. The end of a hold moves the
  /// view no more than the hold did: it can come by itself, with the screen still shared (F58).
  @Test(arguments: ["hold", "hold still"]) func theEndOfAHoldStillMovesNoView(hold: String) {
    let (h, _, _) = thirdsAndARuleThatHalvesOne()
    h.run(hold)
    let view = h.workspace.camera
    let new = h.system.open(app: "Notes")
    #expect(h.workspace.isFloating(new) && h.system.focused == new)
    h.run("release")
    #expect(h.workspace.camera == view, "\(h.ascii())")
    expectWindowsMatchLayout(h)
  }

  /// Automatic docking docks only where everything goes on showing, and takes back what turns out otherwise. It never meant
  /// the view to go anywhere.
  @Test func automaticDockingPullsNoView() {
    let h = harness([]) { $0.newWindows = "dock" }
    let windows = ["Safari", "Mail", "Music", "Maps", "Photos"].map { h.system.open(app: $0) }
    h.start()
    h.run("arrange all")
    let view = h.workspace.camera
    for app in ["Notes", "Books", "Terminal", "Preview"] {
      h.beginStep()
      _ = h.system.open(app: app)
      #expect(h.workspace.camera == view, "\(app)\n\(h.ascii())")
      #expect(h.jolts.isEmpty, "\(app): \(h.jolts)")
    }
    for window in windows { #expect(h.system.isVisible(window)) }
    expectWindowsMatchLayout(h)
  }
}
