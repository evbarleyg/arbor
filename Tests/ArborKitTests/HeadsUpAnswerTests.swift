import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Which lines answer a person (docs/features/F43-say-what-happened.md). In another app's full-screen Space Arbor keeps
/// to itself, with one exception: whoever pressed one of its keys there asked it a question, and a key that is silent is worse
/// than a line over a film. So the model says whether it answers somebody, and the panel shows there only if it does.
@Suite @MainActor struct HeadsUpAnswerTests {
  /// Safari and Mail, floating. Hints are out of the way unless a test asks for them.
  private func makeHarness(settings: Settings = Harness.settingsWhenNoneAreGiven, taught: Bool = true) -> (Harness, WindowID, WindowID) {
    var saved = PersistedState(workspaces: [:], hints: [:])
    if taught { for hint in HeadsUpHint.allCases { saved.hintsShown[hint.rawValue] = HeadsUpHint.timesShown } }
    let h = Harness(settings: settings, saved: saved)
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Mail")
    h.start()
    h.system.userFocus(a)
    return (h, a, b)
  }

  @Test func whatAKeyAGestureOrTheMenuIsToldIsAnAnswer() {
    for source in [CommandSource.shortcut, .gesture, .menu] {
      let (h, _, _) = makeHarness()
      #expect(!h.run("out", from: source).ok)
      #expect(h.overlays.messages.map(\.model.isAnswer) == [true], "\(source)")
    }
  }

  @Test func aKeyPressedOnAFullScreenWindowIsAnswered() {
    let (h, a, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.system.setFullScreen(a, true)
    h.system.userFocus(a)

    #expect(!h.run("dock right", from: .shortcut).ok)

    #expect(h.overlays.messages.last?.model.kind == .problem)
    #expect(h.overlays.messages.last?.model.isAnswer == true)
  }

  @Test func whatIsTaughtInAnswerToAKeyIsAnAnswerToo() {
    let (h, _, _) = makeHarness(taught: false)
    h.run("dock left", from: .shortcut)
    #expect(h.overlays.messages.map(\.model.kind) == [.hint])
    #expect(h.overlays.messages.map(\.model.isAnswer) == [true])
  }

  @Test func whatArborSaysByItselfIsNot() {
    // After a drop, which no command carried out. With macOS's own tiling off, so that the screen's edge is Arbor's.
    let (h, a, _) = makeHarness(taught: false)
    h.system.tiling = .off
    h.system.drag(a, through: [CGPoint(x: 600, y: 210), CGPoint(x: 300, y: 400), CGPoint(x: 2, y: 400)])
    #expect(h.overlays.messages.map(\.model.kind) == [.hint])
    #expect(h.overlays.messages.map(\.model.isAnswer) == [false])
  }

  @Test func norIsWhatFollowsACommandAMomentLater() {
    var settings = Settings()
    settings.passThroughApps = ["org.gnu.Emacs"]
    let (h, a, _) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    h.run("desktop", from: .shortcut)
    h.scheduler.advance(by: 0.2)  // macOS reports the app a moment later
    h.controller.applicationActivated(FrontmostApp(bundleID: "org.gnu.Emacs", name: "Emacs"))
    #expect(h.overlays.messages.count == 1)
    #expect(h.overlays.messages.last?.model.isAnswer == false)
  }

  @Test func theLineStaysAnAnswerWhenItMakesRoomForTheMinimap() {
    let (h, a, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("out", from: .shortcut)
    let before = h.overlays.headsUp[h.display]
    #expect(before?.isAnswer == true)

    h.run("minimap")  // a script's, so that nothing new is said

    let after = h.overlays.headsUp[h.display]
    #expect(after?.line == before?.line)
    #expect(after?.anchor != before?.anchor, "it moved up")
    #expect(after?.isAnswer == true)
  }
}
