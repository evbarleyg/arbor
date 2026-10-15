import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// F22 on a held view (F58): the keyboard goes on working among the windows an audience sees, and nothing else comes in.
@Suite @MainActor struct TilingWhileHeldTests {
  /// A | (B over C) framed as B over C, with A out of view.
  private func framedPair(settings: Settings = Settings()) -> (Harness, [WindowID]) {
    tilingScenario(
      ["A", "B", "C"], ["dock $0 left", "dock $1 right", "dock $2 beside $1 bottom", "zoom $1", "out", "focus $1", "hold"],
      settings: settings)
  }

  @Test func focusGoesFromWindowToWindowInView() {
    let (h, w) = framedPair()
    let camera = h.workspace.camera
    #expect(runOK(h, "focus down").message == "focused \(w[2])")
    #expect(runOK(h, "focus next").message == "focused \(w[1])")
    #expect(runOK(h, "focus $2", w).message == "focused \(w[2])")
    #expect(h.system.focused == w[2] && h.workspace.camera == camera)
    expectSound(h)
  }

  @Test func atTheEdgeOfTheViewFocusStaysAndSaysWhy() {
    let (h, w) = framedPair()
    let (camera, frames) = (h.workspace.camera, w.map { h.frame($0) })
    let result = h.run("focus left")
    #expect(!result.ok && result.message.hasPrefix("no window in view to the left, and the view is held; release it"))
    let other = h.run("focus \(w[0].rawValue)")
    #expect(!other.ok && other.message.hasPrefix("\(w[0]) is out of view, and the view is held"))
    #expect(h.system.focused == w[1] && h.workspace.camera == camera && w.map { h.frame($0) } == frames)
    expectSound(h)
  }

  @Test(.withTiles) func aTileIsNoStop() {
    var settings = noRoomMade
    settings.minimumUsableWidth = 500
    let (h, w) = tilingScenario(["A", "B", "C"], ["dock $0 left", "dock $1 right", "dock $2 beside $1 right"], settings: settings)
    #expect(h.layout?.tiles.isEmpty == false, "the test needs a tile")
    let shown = w.filter { h.layout?.windowFrames[$0] != nil }
    guard let first = shown.first else { return }
    h.system.userFocus(first)
    runOK(h, "hold")
    let camera = h.workspace.camera
    for direction in ["left", "right", "up", "down"] {
      let result = h.run("focus \(direction)")
      if result.ok { #expect(h.system.focused.map(shown.contains) == true, "\(direction)") }
      h.system.userFocus(first)
      let swap = h.run("swap \(direction)")
      #expect(!swap.ok, "\(direction): there are only tiles to trade with")
      #expect(h.workspace.camera == camera, "\(direction)")
      #expect(Set(w.filter { h.layout?.windowFrames[$0] != nil }) == Set(shown), "\(direction): what shows is what showed")
    }
    expectSound(h)
  }

  @Test func whatIsInViewCanBeRearranged() {
    let (h, w) = framedPair()
    let camera = h.workspace.camera
    let (b, c) = (h.frame(w[1])!, h.frame(w[2])!)
    runOK(h, "swap down")
    #expect(h.frame(w[1]) == c && h.frame(w[2]) == b)
    runOK(h, "rotate")
    #expect(h.frame(w[1])!.minY == h.frame(w[2])!.minY)
    runOK(h, "mirror")
    runOK(h, "grow")
    #expect(h.frame(w[1])!.width > h.frame(w[2])!.width)
    runOK(h, "shrink")
    runOK(h, "grow 80")
    runOK(h, "balance")
    #expect(abs(h.frame(w[1])!.width - h.frame(w[2])!.width) <= 1)
    #expect(h.workspace.camera == camera && h.controller.parked.contains(w[0]))
    expectSound(h)
  }

  @Test func nothingOutOfViewTradesPlacesWithWhatIsInIt() {
    let (h, w) = framedPair()
    let tree = h.workspace.tree
    let result = h.run("swap \(w[1].rawValue) \(w[0].rawValue)")
    #expect(!result.ok && result.message.hasPrefix("\(w[0]) is out of view, and the view is held"))
    #expect(h.workspace.tree == tree)
    expectSound(h)
  }

  @Test func nothingCrossesToAnotherDisplay() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, sideDisplay])
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let c = h.system.open(app: "C", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    h.start()
    for command in ["dock \(a.rawValue) left", "dock \(c.rawValue) left", "focus \(a.rawValue)", "hold"] { runOK(h, command) }
    let frames = [h.frame(a), h.frame(c)]
    let swap = h.run("swap \(a.rawValue) \(c.rawValue)")
    #expect(!swap.ok && swap.message.hasPrefix("\(a) and \(c) are on different displays, and the view is held"))
    #expect(!h.run("move-to-display next").ok)
    #expect([h.frame(a), h.frame(c)] == frames)
    // The keyboard may: both windows are in view.
    #expect(runOK(h, "focus right").message == "focused \(c)")
    #expect(runOK(h, "focus-display next").message == "focused \(a) on display 1")
    expectSound(h)
  }

  /// `hold still` refuses nothing a person asks for.
  @Test func holdingStillTheViewFollowsTheKeyboardAsEver() {
    let (h, w) = framedPair(settings: .withDesktopColumn)
    runOK(h, "release")
    runOK(h, "hold still")
    // The Desktop lies between them and is a stop, as for `neighbor`.
    #expect(runOK(h, "focus left").message == "moved to the Desktop; no window to focus there")
    #expect(runOK(h, "focus left").message == "focused \(w[0])")
    #expect(h.layout?.windowFrames[w[0]] != nil)
    expectSound(h)
  }
}
