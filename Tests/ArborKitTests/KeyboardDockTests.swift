import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Walking a docked window around with `dock <edge>` (⌃⌥⌘ + arrow).
@Suite @MainActor struct KeyboardDockTests {
  /// Four windows arranged as `[a / b | c / d | Desktop]`.
  func grid() -> (Harness, [WindowID]) {
    let h = Harness()
    let ids = ["A", "B", "C", "D"].enumerated().map { index, app in
      h.system.open(
        app: app, frame: CGRect(x: 100 + 300 * (index / 2), y: 100 + 300 * (index % 2), width: 280, height: 280))
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

  @Test func walkingAWindowDoesNotSqueezeADesktopThatHoldsWindowsIntoATile() {
    let (h, ids) = grid()
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
}
