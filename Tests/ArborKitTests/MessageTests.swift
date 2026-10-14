import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// What commands say. A failure tells the user what to do next; a success says what happened.
@Suite @MainActor struct MessageTests {
  /// `[a / c | Desktop | b]` with `f` floating.
  func makeHarness(settings: Settings = Settings()) -> (Harness, a: WindowID, b: WindowID, c: WindowID, f: WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    let f = h.system.open(app: "Calculator", frame: CGRect(x: 560, y: 300, width: 320, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    return (h, a, b, c, f)
  }

  func failure(_ h: Harness, _ command: String, sourceLocation: SourceLocation = #_sourceLocation) -> String {
    let result = h.run(command)
    #expect(!result.ok, "`\(command)` should fail", sourceLocation: sourceLocation)
    return result.message
  }

  @Test func aWindowArborCannotActOnIsExplained() {
    let (h, _, _, _, _) = makeHarness()
    #expect(failure(h, "zoom 999").contains("no window w999"))
    h.system.focused = nil
    #expect(failure(h, "zoom").contains("click"))

    h.run("exclude com.example.notes")
    // The glossary's word for an app is "arrange" ("Don't Arrange Notes"); `exclude` is only the command's name.
    #expect(
      failure(h, "dock 102 left") == "Arbor does not arrange Notes; `include com.example.notes` arranges it again")

    var settings = h.controller.settings
    settings.rules = [AppRule(app: "com.example.finder", action: .ignore)]
    h.controller.apply(settings: settings)
    let ignored = h.system.open(app: "Finder")
    #expect(failure(h, "dock \(ignored.rawValue) left").contains("ignore"))
  }

  @Test func directionsAreWordsAPersonWouldUse() {
    let (h, a, _, c, _) = makeHarness()
    #expect(h.run("dock \(a.rawValue) down").message == "moved \(a) down")
    #expect(h.run("dock \(a.rawValue) up").message == "moved \(a) up")
    h.run("zoom \(a.rawValue)")
    #expect(failure(h, "neighbor up") == "no space above")
    #expect(failure(h, "neighbor left") == "no space to the left")
    h.run("zoom \(c.rawValue)")
    #expect(failure(h, "neighbor down") == "no space below")
  }

  @Test func anUnsavedViewSaysHowToSaveIt() {
    let (h, _, _, _, _) = makeHarness()
    #expect(failure(h, "view 3").contains("save-view 3"))
  }

  @Test func framingAFloatingWindowSaysWhatIsShown() {
    let (h, _, _, _, f) = makeHarness()
    let result = h.run("zoom \(f.rawValue)")
    #expect(result.ok)
    #expect(result.message.contains("Desktop"), "\(result.message)")
  }

  @Test func aResizeThatMovesNothingIsNotASuccess() {
    let (h, a, _, _, _) = makeHarness()
    #expect(h.run("resize \(a.rawValue) right -2000").ok, "it goes as far as it can")
    let stuck = failure(h, "resize \(a.rawValue) right -50")
    #expect(stuck.contains("80"), "\(stuck)")
  }

  @Test func dockingBesideAFloatingWindowSaysWhatToDo() {
    let (h, a, _, _, f) = makeHarness()
    let message = failure(h, "dock \(a.rawValue) beside \(f.rawValue) left")
    #expect(message.contains("dock \(f.rawValue)"), "\(message)")
  }

  @Test func aDockThatEndsAsATileSaysSo() {
    let (h, _, b, _, _) = makeHarness()
    let big = h.system.open(
      app: "Xcode", frame: CGRect(x: 400, y: 200, width: 700, height: 500),
      // More than its neighbours and the Desktop could spare between them (F61).
      minimumSize: CGSize(width: 1200, height: 600))
    let result = h.run("dock \(big.rawValue) beside \(b.rawValue) bottom")
    #expect(result.ok)
    #expect(result.message.contains("tile"), "\(result.message)")
  }

  /// `count` floating windows on a display with nothing docked.
  func floating(_ count: Int, settings: Settings = Settings()) -> (Harness, [WindowID]) {
    let h = Harness(settings: settings)
    let ids = (0..<count).map { h.system.open(app: "App\($0)", frame: CGRect(x: 200, y: 200, width: 500, height: 400)) }
    h.start()
    return (h, ids)
  }

  func tiled(_ h: Harness) -> Set<WindowID> { Set(h.layout!.tiles.flatMap(\.windows)) }

  @Test func aDockThatLeavesOthersTooSmallSaysHowMany() {
    let (h, w) = floating(5)
    #expect(h.run("dock \(w[0].rawValue) left") == .success("docked \(w[0]) at the left edge"))
    #expect(h.run("dock \(w[1].rawValue) beside \(w[0].rawValue) right") == .success("docked \(w[1]) right of \(w[0])"))
    #expect(h.run("dock \(w[2].rawValue) left") == .success("docked \(w[2]) at the left edge"))

    // The newcomer is shown; the two it pushed together are not any more.
    #expect(
      h.run("dock \(w[3].rawValue) left")
        == .success(
          "docked \(w[3]) at the left edge; that leaves too little room for 2 other windows, which are tiles now"))
    #expect(tiled(h) == [w[0], w[1]])

    // Everything is a tile now. Only the windows that this command put out of view are counted.
    #expect(
      h.run("dock \(w[4].rawValue) left")
        == .success(
          "docked \(w[4]) at the left edge; its space is too small to show it, so it is a tile, "
            + "and so are 2 other windows now"))
    #expect(tiled(h) == Set(w))
    #expect(h.layout!.windowFrames.isEmpty)
  }

  @Test func oneOtherWindowIsSpokenOfAsOne() {
    let (h, w) = floating(4)
    h.run("dock \(w[0].rawValue) left")
    h.run("resize \(w[0].rawValue) right -300")
    #expect(h.run("dock \(w[1].rawValue) right") == .success("docked \(w[1]) at the right edge"))
    #expect(
      h.run("dock \(w[2].rawValue) right")
        == .success("docked \(w[2]) at the right edge; that leaves too little room for 1 other window, which is a tile now"))
    #expect(tiled(h) == [w[0]])
    // It was a tile already: this dock did nothing to it.
    #expect(h.run("dock \(w[3].rawValue) right") == .success("docked \(w[3]) at the right edge"))
    #expect(tiled(h) == [w[0]])
  }

  @Test func dockingBesideAWindowCountsTheNeighbourItSqueezed() {
    let (h, w) = floating(3)
    h.run("dock \(w[0].rawValue) left")
    h.run("dock \(w[1].rawValue) beside \(w[0].rawValue) right")
    #expect(
      h.run("dock \(w[2].rawValue) beside \(w[1].rawValue) right")
        == .success(
          "docked \(w[2]) right of \(w[1]); its space is too small to show it, so it is a tile, "
            + "and so is 1 other window now"))
    #expect(tiled(h) == [w[1], w[2]])
  }

  @Test func movingADockedWindowCountsOnlyTheOthers() {
    let (h, w) = floating(6)
    h.run("arrange")
    h.run("dock \(w[0].rawValue) left")
    h.run("dock \(w[1].rawValue) left")
    let before = Set(h.layout!.windowFrames.keys)
    #expect(before.contains(w[2]), "it is shown, and about to become a tile itself")
    let result = h.run("dock \(w[2].rawValue) left")
    let lost = before.intersection(tiled(h))
    #expect(lost.count == 2 && lost.contains(w[2]), "\(lost)")
    #expect(
      result
        == .success("moved \(w[2]) left; its space is too small to show it, so it is a tile, and so is 1 other window now"))
  }

  @Test func tabsBehindTheFrontOneWereNotShownAndAreNotCounted() {
    var settings = Settings()
    settings.tabsEnabled = true
    let (h, w) = floating(4, settings: settings)
    h.run("dock \(w[0].rawValue) left")
    h.run("resize \(w[0].rawValue) right -300")
    let centre = CGPoint(x: h.frame(w[0])!.midX, y: h.frame(w[0])!.midY)
    h.system.drag(w[1], through: [CGPoint(x: h.frame(w[1])!.midX, y: h.frame(w[1])!.minY + 10), centre])
    #expect(h.workspace.tree.leaf(containing: w[0]) == h.workspace.tree.leaf(containing: w[1]))
    #expect(h.layout!.windowFrames.count == 1, "one tab is in front")
    h.run("dock \(w[2].rawValue) right")
    let result = h.run("dock \(w[3].rawValue) right")
    #expect(tiled(h) == [w[0], w[1]])
    #expect(result.message.hasSuffix("too little room for 1 other window, which is a tile now"), "\(result.message)")
  }

  @Test func excludingAndIncludingSayWhatChanged() {
    let (h, _, _, _, _) = makeHarness()
    // The app is called what people call it while one of its windows is open.
    #expect(h.run("exclude com.example.notes") == .success("no longer arranging Notes"))
    // Asking again changes nothing, which is a failure like "already floating" (product owner on #172): on screen it
    // shows as a problem, not as a change.
    #expect(h.run("exclude com.example.notes") == .failure("Arbor does not arrange Notes already"))
    #expect(h.run("include com.example.notes") == .success("arranging Notes again"))
    #expect(h.run("include com.example.notes") == .failure("Arbor arranges Notes already"))
  }

  @Test func anAppThatIsNotRunningIsCalledByItsBundleID() {
    let (h, _, _, _, _) = makeHarness()
    #expect(h.run("exclude com.example.absent") == .success("no longer arranging com.example.absent"))
    #expect(h.run("exclude com.example.absent") == .failure("Arbor does not arrange com.example.absent already"))
    #expect(h.run("include com.example.absent") == .success("arranging com.example.absent again"))
    #expect(h.run("include com.example.absent") == .failure("Arbor arranges com.example.absent already"))
  }

  @Test func aResizeThatLeavesANeighbourTooSmallSaysSo() {
    let (h, w) = floating(2)
    h.run("dock \(w[0].rawValue) left")
    h.run("dock \(w[1].rawValue) beside \(w[0].rawValue) right")
    #expect(h.run("resize \(w[0].rawValue) right 20") == .success("resized \(w[0])"))
    #expect(
      h.run("resize \(w[0].rawValue) right 150")
        == .success("resized \(w[0]); that leaves too little room for 1 other window, which is a tile now"))
    #expect(tiled(h) == [w[1]])
    // Made smaller than it can be shown, it is the resized window itself.
    #expect(
      h.run("resize \(w[0].rawValue) right -400")
        == .success("resized \(w[0]); its space is too small to show it, so it is a tile"))
    #expect(tiled(h) == [w[0]])
  }
}
