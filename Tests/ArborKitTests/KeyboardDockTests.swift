import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Walking a docked window around with `dock <edge>` (⌃⌥⌘ + arrow).
@Suite @MainActor struct KeyboardDockTests {
  /// Four windows arranged as `[a / b | c / d | Desktop]`.
  func grid(settings: Settings = Settings()) -> (Harness, [WindowID]) {
    let h = Harness(settings: settings)
    let ids = ["A", "B", "C", "D"].enumerated().map { index, app in
      // Each a process of its own, so that one of them can be hidden.
      h.system.open(
        app: app, pid: Int32(1000 + index), frame: CGRect(x: 100 + 300 * (index / 2), y: 100 + 300 * (index % 2), width: 280, height: 280))
    }
    h.start()
    h.run("arrange")
    return (h, ids)
  }

  @Test func walkingAWindowAcrossTheGridNeverTurnsItIntoATileOrMovesTheCamera() {
    for edge in ["right", "left", "up", "down"] {
      for index in 0..<4 {
        let (h, ids) = grid()
        h.system.userFocus(ids[index])
        for step in 1...6 {
          let result = h.run("dock \(edge)")
          let note = "window \(index), \(edge), step \(step)\n\(h.ascii())"
          #expect(h.workspace.tree.invariantViolations().isEmpty, "\(note)")
          #expect(h.layout!.windowFrames[ids[index]] != nil, "\(note)")
          #expect(h.workspace.camera == h.workspace.tree.root, "\(note)")
          #expect(h.system.focused == ids[index], "\(note)")
          if !result.ok { break }
        }
      }
    }
  }

  @Test func walkingAWindowOutOfANestedLayoutKeepsItInViewAndTheTreeValid() {
    // `[a | b / (c | d) | Desktop]` on a wide display, each window walked in each direction until it stops.
    let wide = DisplaySnapshot(
      id: DisplayID("wide"), frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
      visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true)
    for edge in ["right", "left", "up", "down"] {
      for index in 0..<4 {
        let h = Harness(displays: [wide])
        let ids = ["A", "B", "C", "D"].map { h.system.open(app: $0) }
        h.start()
        h.system.cursor = CGPoint(x: 1000, y: 700)
        h.run("dock \(ids[0].rawValue) left")
        h.run("dock \(ids[1].rawValue) beside \(ids[0].rawValue) right")
        h.run("dock \(ids[2].rawValue) beside \(ids[1].rawValue) bottom")
        h.run("dock \(ids[3].rawValue) beside \(ids[2].rawValue) right")
        h.system.userFocus(ids[index])
        var steps = 0
        while h.run("dock \(edge)").ok, steps < 12 {
          steps += 1
          let note = "window \(index), \(edge), step \(steps)\n\(h.ascii())"
          #expect(h.workspace.tree.invariantViolations().isEmpty, "\(note)")
          #expect(h.workspace.tree.allWindows.count == 4, "\(note)")
          #expect(h.layout!.tiles.isEmpty, "\(note)")
          #expect(h.workspace.camera == h.workspace.tree.root, "\(note)")
          #expect(h.system.focused == ids[index], "\(note)")
        }
        #expect(steps < 12, "window \(index) never stops going \(edge)")
      }
    }
  }

  /// While floating windows make way, as until Q20 (`floatingWindowsMakeWay`), they need a Desktop to be on. As Arbor ships they
  /// keep their frames whatever its size, and a `dock` keeps no room for their sake.
  @Test func walkingAWindowDoesNotSqueezeADesktopThatHoldsWindowsIntoATile() {
    let (h, ids) = grid(settings: .makingWay)
    // A call window on the narrow Desktop column.
    let call = h.system.open(app: "Zoom", frame: CGRect(x: 1150, y: 200, width: 260, height: 300))
    h.system.userMove(call, to: CGRect(x: 1150, y: 200, width: 260, height: 300))
    h.system.userFocus(ids[0])
    for step in 1...6 {
      let result = h.run("dock right")
      let note = "step \(step)\n\(h.ascii())"
      #expect(h.layout!.desktopFrame != nil, "\(note)")
      #expect(h.system.isVisible(call), "\(note)")
      #expect(h.layout!.windowFrames[ids[0]] != nil, "\(note)")
      if !result.ok { break }
    }
  }

  @Test func aWalkEndsAtTheEdgeAndSaysSo() {
    let ends = [("right", \CGRect.maxX), ("left", \CGRect.minX), ("up", \CGRect.minY), ("down", \CGRect.maxY)]
    for (edge, position) in ends {
      let (h, ids) = grid()
      var steps = 0
      while h.run("dock \(ids[0].rawValue) \(edge)").ok, steps < 12 { steps += 1 }
      #expect(steps < 12, "\(edge) never ends")
      let content = h.visibleFrame.insetBy(dx: 12, dy: 12)
      #expect(h.frame(ids[0])![keyPath: position] == content[keyPath: position], "\(edge)")
    }
  }

  @Test func steppingTowardsANarrowDesktopSharesTheRowInsteadOfHalvingTheDesktop() {
    let (h, ids) = grid()
    // c is at the top of the column next to the Desktop, which `arrange` keeps narrow.
    #expect(h.run("dock \(ids[2].rawValue) right").ok)
    #expect(h.layout!.windowFrames[ids[2]] != nil, "\(h.ascii())")
    #expect(h.frame(ids[2])!.width > 300, "\(h.ascii())")
    #expect(h.frame(ids[2])!.minX > h.frame(ids[3])!.maxX)
  }

  @Test func steppingBesideAWideNeighbourTakesHalfOfItAndMovesNothingElse() {
    let h = Harness()
    let a = h.system.open(app: "A")
    let c = h.system.open(app: "C")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let column = h.frame(a)!
    let desktop = h.layout!.desktopFrame!
    h.run("dock \(c.rawValue) right")
    // Give or take the extra gap.
    #expect(h.frame(a)!.minX == column.minX && abs(h.frame(a)!.maxX - column.maxX) <= 12)
    #expect(abs(h.frame(c)!.minX - desktop.minX) <= 12)
    #expect(h.layout!.desktopFrame!.maxX == desktop.maxX)
    #expect(abs(h.frame(c)!.width - h.layout!.desktopFrame!.width) <= 1)
  }

  // MARK: Beside windows that are away

  enum Away: String, CaseIterable {
    case minimized, hidden
  }

  /// `[safari / terminal | chrome | Desktop]`, as `arrange` makes it of three, each app a process of its own, and `terminal` away:
  /// `safari` fills the column, and to the eye there is no group.
  func aColumnOfWhichOneIsAway(_ away: Away) -> (h: Harness, safari: WindowID, terminal: WindowID, chrome: WindowID) {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 900, height: 700))
    let terminal = h.system.open(app: "Terminal", pid: 12, frame: CGRect(x: 200, y: 150, width: 700, height: 500))
    let chrome = h.system.open(app: "Chrome", pid: 13, frame: CGRect(x: 300, y: 200, width: 1000, height: 700))
    h.start()
    h.run("arrange")
    #expect(h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: safari)!) == h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: terminal)!))
    switch away {
    case .minimized: h.system.setMinimized(terminal, true)
    case .hidden: h.system.setHidden(pid: 12, true)
    }
    h.scheduler.advance(by: 1)
    h.system.userFocus(safari)
    #expect(h.frame(safari)!.maxX < h.frame(chrome)!.minX)
    return (h, safari, terminal, chrome)
  }

  /// Where the windows in view are, whole or as tiles, and the Desktop (as window 0): a window that trades places with it has moved.
  func picture(_ h: Harness) -> [WindowID: CGRect] {
    var picture = h.layout!.windowFrames
    for tile in h.layout!.tiles { for window in tile.windows { picture[window] = tile.frame } }
    let tree = h.workspace.tree
    picture[WindowID(0)] = h.layout!.desktopFrame ?? h.layout!.tiles.first { tree.subtree($0.node, contains: tree.desktop) }?.frame
    return picture
  }

  /// With another window in the Dock a browser's window "would not dock on the right". It shared a column with the one that was away, so the
  /// key took it out of a group that nobody could see: the same picture, both windows narrower, and "moved" for an answer.
  @Test(arguments: Away.allCases) func theKeyMovesTheWindowPastItsNeighbourAtTheFirstPress(away: Away) {
    let (h, safari, _, chrome) = aColumnOfWhichOneIsAway(away)
    let (safariWas, chromeWas, desktopWas) = (h.frame(safari)!, h.frame(chrome)!, h.layout!.desktopFrame!)
    h.system.clearFrameLog()
    #expect(h.run("dock right").message == "moved \(safari) right")
    #expect(h.frame(chrome)!.maxX < h.frame(safari)!.minX, "\(h.ascii())")
    // They trade places, and that is all: sizes travel with the windows, the Desktop is as it was, each moves once.
    #expect(h.frame(safari)!.size == safariWas.size && h.frame(chrome)!.size == chromeWas.size, "\(h.ascii())")
    #expect(h.layout!.desktopFrame == desktopWas)
    #expect(h.system.frameLog.map(\.window).sorted() == [safari, chrome].sorted(), "\(h.system.frameLog)")
    #expect(h.system.focused == safari)
    expectWindowsMatchLayout(h)
  }

  /// What was a column of two is one again, whichever side it is on by now.
  @Test(arguments: Away.allCases) func theOneThatWasAwayComesBackToTheWindowItSharedAColumnWith(away: Away) {
    let (h, safari, terminal, chrome) = aColumnOfWhichOneIsAway(away)
    let chromeWidth = h.frame(chrome)!.width
    h.run("dock right")
    switch away {
    case .minimized: h.system.setMinimized(terminal, false)
    case .hidden: h.system.setHidden(pid: 12, false)
    }
    h.scheduler.advance(by: 1)
    #expect(h.frame(terminal)!.minX == h.frame(safari)!.minX && h.frame(safari)!.maxY < h.frame(terminal)!.minY, "\(h.ascii())")
    #expect(h.frame(chrome)!.width == chromeWidth, "nobody is squeezed for it")
    #expect(h.layout!.tiles.isEmpty)
    expectWindowsMatchLayout(h)
  }

  /// The rule, whatever the arrangement: a key that says "moved" has changed who lies left of whom or above whom, and one that cannot says
  /// why not and changes nothing, no size either.
  @Test(arguments: Away.allCases) func aKeyThatSaysMovedHasMovedSomethingThatShows(away: Away) {
    for gone in 0..<4 {
      for walker in 0..<4 where walker != gone {
        for edge in ["right", "left", "up", "down"] {
          let (h, ids) = grid()
          switch away {
          case .minimized: h.system.setMinimized(ids[gone], true)
          case .hidden: h.system.setHidden(pid: Int32(1000 + gone), true)
          }
          h.scheduler.advance(by: 1)
          h.system.userFocus(ids[walker])
          for step in 1...6 {
            let before = picture(h)
            let result = h.run("dock \(edge)")
            let note = "\(ids[gone]) away, \(ids[walker]) \(edge), step \(step): \(result.message)\n\(h.ascii())"
            #expect(h.workspace.tree.invariantViolations().isEmpty, "\(note)")
            if result.ok {
              #expect(order(picture(h), around: ids[walker]) != order(before, around: ids[walker]), "the same picture: \(note)")
            } else {
              #expect(picture(h) == before, "\(note)")
              break
            }
          }
        }
      }
    }
  }

  /// Who lies left of whom and above whom: what a person would call the arrangement, whatever the sizes. `around`: only what is said of that
  /// window, which is what its person is looking at. Sizes alone can part two bystanders that lay one above the other.
  func order(_ picture: [WindowID: CGRect], around walker: WindowID? = nil) -> [String] {
    var relations: [String] = []
    for (a, frameA) in picture.sorted(by: { $0.key < $1.key }) {
      for (b, frameB) in picture.sorted(by: { $0.key < $1.key }) where a != b && (walker == nil || a == walker || b == walker) {
        if frameA.maxX <= frameB.minX { relations.append("\(a) left of \(b)") }
        if frameA.maxY <= frameB.minY { relations.append("\(a) above \(b)") }
      }
    }
    return relations
  }

  /// At the edge, with only a window that is away beyond it or beside it: there is nowhere to go, and it says so.
  @Test(arguments: Away.allCases) func whereNothingLiesBeyondItSaysSoAndMovesNothing(away: Away) {
    let (h, safari, _, _) = aColumnOfWhichOneIsAway(away)
    let (tree, before) = (h.workspace.tree, picture(h))
    h.system.clearFrameLog()
    let result = h.run("dock left")
    #expect(!result.ok && result.message == "\(safari) is already at the left edge", "\(result.message)")
    #expect(h.workspace.tree == tree && picture(h) == before && h.system.frameLog.isEmpty)
  }

  /// A row looks the way it acts.
  @Test(arguments: Away.allCases) func theMenuGreysOutTheWayThatLeadsNowhere(away: Away) {
    let (h, _, _, _) = aColumnOfWhichOneIsAway(away)
    let rows = h.controller.menuModel().item("Dock Focused Window")?.sections.flatMap(\.items) ?? []
    #expect(rows.first { $0.title == "Left" }?.isEnabled == false)
    #expect(rows.first { $0.title == "Right" }?.isEnabled == true)
  }

  /// The group is whole afterwards: what it was called and the view saved of it are still its own.
  @Test(arguments: Away.allCases) func theGroupKeepsItsNameAndItsSavedView(away: Away) {
    let (h, safari, terminal, _) = aColumnOfWhichOneIsAway(away)
    let column = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: safari)!)!
    h.run("zoom-node \(column.rawValue)")
    h.run("name pair")
    h.run("save-view 1")
    h.run("show-all")
    h.system.userFocus(safari)
    #expect(h.run("dock right").ok)
    #expect(h.workspace.names["pair"] == column && h.workspace.tree.windows(under: column).sorted() == [safari, terminal].sorted())
    #expect(h.run("view 1").ok && h.workspace.camera == column, "\(h.ascii())")
  }

  /// Up and down as left and right: a row of which one is away, above another window.
  @Test(arguments: Away.allCases) func aRowOfWhichOneIsAwayGoesDownAsOne(away: Away) {
    let (h, safari, terminal, chrome) = aColumnOfWhichOneIsAway(away)
    #expect(h.run("layout (\(safari) | \(terminal)) / \(chrome) / Desktop").ok)
    h.scheduler.advance(by: 1)
    h.system.userFocus(safari)
    let (safariWas, chromeWas) = (h.frame(safari)!, h.frame(chrome)!)
    #expect(!h.run("dock up").ok)
    #expect(h.run("dock down").ok)
    #expect(h.frame(chrome)!.maxY < h.frame(safari)!.minY, "\(h.ascii())")
    // (Thirds of the display's height are whole points, so the first of three is a point off the second.)
    #expect(h.frame(safari)!.width == safariWas.width && abs(h.frame(safari)!.height - safariWas.height) <= 1, "\(h.ascii())")
    #expect(h.frame(chrome)!.width == chromeWas.width && abs(h.frame(chrome)!.height - chromeWas.height) <= 1, "\(h.ascii())")
    expectWindowsMatchLayout(h)
  }

  /// The view is on the column, of which the window is all that shows: it fills the view, whichever way the key points.
  @Test(arguments: Away.allCases) func inAViewOfWhichItIsAllThatShowsItFillsTheView(away: Away) {
    let (h, safari, _, _) = aColumnOfWhichOneIsAway(away)
    h.run("zoom-node \(h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: safari)!)!.rawValue)")
    h.system.userFocus(safari)
    let (tree, before) = (h.workspace.tree, picture(h))
    for edge in ["left", "right", "up", "down"] {
      let result = h.run("dock \(edge)")
      #expect(!result.ok && result.message.hasPrefix("\(safari) fills the view"), "\(edge): \(result.message)")
      #expect(h.workspace.tree == tree && picture(h) == before, "\(edge)")
    }
  }

  /// At the top of a column that is all that shows of the view: the top of the view, though the column is not the view.
  @Test(arguments: Away.allCases) func theEdgeOfAGroupThatIsAllThatShowsIsTheEdgeOfTheView(away: Away) {
    let (h, safari, terminal, chrome) = aColumnOfWhichOneIsAway(away)
    #expect(h.run("layout \(terminal) | (\(safari) / \(chrome) / Desktop)").ok)
    h.scheduler.advance(by: 1)
    h.system.userFocus(safari)
    let (tree, before) = (h.workspace.tree, picture(h))
    let result = h.run("dock up")
    #expect(!result.ok && result.message == "\(safari) is already at the top edge", "\(result.message)")
    #expect(h.workspace.tree == tree && picture(h) == before)
  }

  /// Nobody looks at a window that is itself away, and no key reaches it: named by its id, it goes as it always went.
  @Test(arguments: Away.allCases) func aWindowThatIsItselfAwayIsAtTheEdgeWhereItIs(away: Away) {
    let (h, safari, terminal, chrome) = aColumnOfWhichOneIsAway(away)
    #expect(h.run("layout \(terminal):2 | \(safari) | \(chrome) | Desktop:0.5").ok)
    h.scheduler.advance(by: 1)
    let tree = h.workspace.tree
    let result = h.run("dock \(terminal) left")
    #expect(!result.ok && result.message == "\(terminal) is already at the left edge", "\(result.message)")
    #expect(h.workspace.tree == tree)
  }

  /// Nor at one that is out of view: named by its id, it comes into the view, alone.
  @Test(arguments: Away.allCases) func aWindowOutOfViewComesIntoTheView(away: Away) {
    let (h, safari, _, chrome) = aColumnOfWhichOneIsAway(away)
    h.run("zoom \(chrome)")
    #expect(h.layout!.windowFrames[safari] == nil)
    #expect(h.run("dock \(safari) right").ok)
    let (chromeIs, safariIs) = (h.layout!.windowFrames[chrome] ?? .zero, h.layout!.windowFrames[safari] ?? .zero)
    #expect(!safariIs.isEmpty && !chromeIs.isEmpty && chromeIs.maxX < safariIs.minX, "\(h.ascii())")
  }

  /// `b | (c, away, over (d | a)) | Desktop`: to the eye `b | d | a | Desktop`, one row. `a` and `d` are a row that shows in a column that does not.
  func aRowThatShowsInAColumnThatDoesNot(_ away: Away, desktopBeyond: Bool) -> (h: Harness, a: WindowID, b: WindowID, c: WindowID, d: WindowID) {
    let (h, ids) = grid()
    let (a, b, c, d) = (ids[0], ids[1], ids[2], ids[3])
    switch away {
    case .minimized: h.system.setMinimized(c, true)
    case .hidden: h.system.setHidden(pid: 1002, true)
    }
    h.scheduler.advance(by: 1)
    #expect(h.run("layout \(desktopBeyond ? "" : "Desktop | ")\(b) | (\(c) / (\(d) | \(a))):2\(desktopBeyond ? " | Desktop" : "")").ok)
    h.scheduler.advance(by: 1)
    h.system.userFocus(a)
    return (h, a, b, c, d)
  }

  /// Taking it out of its row alone would leave the order as it is and resize all three under a "moved": no step. The press goes on until
  /// something shows: out of the row and past its neighbour.
  @Test(arguments: Away.allCases) func aPressGoesOnUntilSomethingShows(away: Away) {
    let (h, a, b, _, d) = aRowThatShowsInAColumnThatDoesNot(away, desktopBeyond: true)
    h.system.clearFrameLog()
    #expect(h.run("dock right").message.hasPrefix("moved \(a) right"))
    let desktop = picture(h)[WindowID(0)] ?? .zero
    #expect(h.frame(b)!.maxX < h.frame(d)!.minX && h.frame(d)!.maxX < desktop.minX && desktop.maxX < h.frame(a)!.minX, "\(h.ascii())")
    #expect(Dictionary(grouping: h.system.frameLog, by: \.window).allSatisfy { $0.value.count == 1 }, "each moves once: \(h.system.frameLog)")
    expectWindowsMatchLayout(h)
  }

  /// With nothing beyond it is at the end of what shows, and says so. Nothing is resized.
  @Test(arguments: Away.allCases) func orSaysThatItIsAtTheEdgeAndResizesNothing(away: Away) {
    let (h, a, _, _, _) = aRowThatShowsInAColumnThatDoesNot(away, desktopBeyond: false)
    let (tree, before) = (h.workspace.tree, picture(h))
    h.system.clearFrameLog()
    let result = h.run("dock right")
    #expect(!result.ok && result.message == "\(a) is already at the right edge", "\(result.message)")
    #expect(h.workspace.tree == tree && picture(h) == before && h.system.frameLog.isEmpty)
    let rows = h.controller.menuModel().item("Dock Focused Window")?.sections.flatMap(\.items) ?? []
    #expect(rows.first { $0.title == "Right" }?.isEnabled == false)
  }

  /// A tile is on screen too: a window that goes above two tiles it was beside has moved.
  @Test(arguments: Away.allCases) func pastTilesIsAStep(away: Away) {
    let (h, ids) = grid()
    let e = h.system.open(app: "E", pid: 1004)
    let (a, b, c, d) = (ids[0], ids[1], ids[2], ids[3])
    switch away {
    case .minimized: h.system.setMinimized(e, true)
    case .hidden: h.system.setHidden(pid: 1004, true)
    }
    h.scheduler.advance(by: 1)
    #expect(h.run("layout (\(e) | (\(d) / \(c)) | \(b)) / \(a) / Desktop").ok)
    h.scheduler.advance(by: 1)
    h.system.userFocus(b)
    #expect(h.layout!.tiles.flatMap(\.windows).sorted() == [c, d].sorted(), "\(h.ascii())")
    let before = order(picture(h))
    #expect(h.run("dock up").ok)
    #expect(order(picture(h)) != before && h.frame(b)!.width > h.visibleFrame.width - 30, "\(h.ascii())")
  }

  /// The Desktop in a group whose window is away, too narrow to use: a tile with nobody in it, and a place in the row all the same.
  @Test(arguments: Away.allCases) func aTileThatHoldsOnlyTheDesktopIsAPlace(away: Away) {
    let (h, ids) = grid()
    let (a, b, c) = (ids[0], ids[1], ids[2])
    h.system.close(ids[3])
    switch away {
    case .minimized: h.system.setMinimized(c, true)
    case .hidden: h.system.setHidden(pid: 1002, true)
    }
    h.scheduler.advance(by: 1)
    #expect(h.run("layout \(a) | (Desktop / \(c)):0.1 | \(b)").ok)
    h.scheduler.advance(by: 1)
    h.system.userFocus(a)
    #expect(h.layout!.desktopFrame == nil && picture(h)[WindowID(0)] != nil, "\(h.ascii())")
    // One place at a time: past the tile, past the window, and then there is nowhere to go.
    #expect(h.run("dock right").ok)
    #expect(picture(h)[WindowID(0)]!.maxX < h.frame(a)!.minX && h.frame(a)!.maxX < h.frame(b)!.minX, "\(h.ascii())")
    #expect(h.run("dock right").ok)
    #expect(h.frame(b)!.maxX < h.frame(a)!.minX, "\(h.ascii())")
    #expect(!h.run("dock right").ok)
    // And back past the window and the tile.
    #expect(h.run("dock left").ok && h.run("dock left").ok)
    #expect(h.frame(a)!.maxX < picture(h)[WindowID(0)]!.minX, "\(h.ascii())")
    #expect(h.run("dock left").message == "\(a) is already at the left edge")
  }

  /// Below the row lie two windows that have nothing to do with it. Other sizes in the row part one of them from the one that lay above it:
  /// nobody who walks a window along the row calls that a step.
  @Test(arguments: Away.allCases) func whatBecomesOfBystandersIsNoStep(away: Away) {
    let (h, ids) = grid()
    let (a, b, c, d) = (ids[0], ids[1], ids[2], ids[3])
    let (e, f) = (h.system.open(app: "E", pid: 1004), h.system.open(app: "F", pid: 1005))
    switch away {
    case .minimized: h.system.setMinimized(c, true)
    case .hidden: h.system.setHidden(pid: 1002, true)
    }
    h.scheduler.advance(by: 1)
    #expect(h.run("layout (\(b) | (\(c) / (\(d) | \(a))):2 | Desktop) / (\(e) | \(f))").ok)
    h.scheduler.advance(by: 1)
    h.system.userFocus(a)
    #expect(h.run("dock right").ok)
    let desktop = picture(h)[WindowID(0)] ?? .zero
    #expect(h.frame(d)!.maxX < desktop.minX && desktop.maxX < h.frame(a)!.minX, "\(h.ascii())")
    expectWindowsMatchLayout(h)
  }

  /// At the top to the eye. A step that only sends the others into tiles is none.
  @Test(arguments: Away.allCases) func atTheTopItDoesNotSendTheOthersIntoTiles(away: Away) {
    let (h, ids) = grid()
    let (a, b, c, d) = (ids[0], ids[1], ids[2], ids[3])
    let e = h.system.open(app: "E", pid: 1004)
    switch away {
    case .minimized: h.system.setMinimized(e, true)
    case .hidden: h.system.setHidden(pid: 1004, true)
    }
    h.scheduler.advance(by: 1)
    #expect(h.run("layout ((\(c) / Desktop) | \(e)):2 / \(d) / (\(b) | \(a))").ok)
    h.scheduler.advance(by: 1)
    h.system.userFocus(c)
    let (tree, before) = (h.workspace.tree, picture(h))
    let result = h.run("dock up")
    #expect(!result.ok && result.message == "\(c) is already at the top edge", "\(result.message)")
    #expect(h.workspace.tree == tree && picture(h) == before)
  }

  /// A group that shows is a group: the key takes the window out of it, as ever.
  @Test func outOfAColumnThatShowsTheWindowStillStepsFirst() {
    let (h, safari, terminal, chrome) = aColumnOfWhichOneIsAway(.minimized)
    h.system.setMinimized(terminal, false)
    h.scheduler.advance(by: 1)
    h.system.userFocus(safari)
    #expect(h.run("dock right").ok)
    #expect(h.frame(terminal)!.maxX < h.frame(safari)!.minX && h.frame(safari)!.maxX < h.frame(chrome)!.minX, "\(h.ascii())")
  }
}
