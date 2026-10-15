#if os(macOS)
  import AppKit
  import ArborCore
  import Testing

  @testable import ArborKit

  /// The answer to Check for Updates… is macOS's own alert (`UpdateWindow`). Nothing is put on screen here.
  @Suite @MainActor struct UpdateAlertTests {
    private let build = BuildInfo(version: "0.9.0", build: "0")

    @Test func aNewerReleaseOffersItsPageFirstAndLaterOnEscape() throws {
      let decision = UpdateCheck.decide(current: "0.9.0", lookup: .latest(tag: "v9.9.9"))
      #expect(decision.page != nil)
      let alert = UpdateWindow.alert(for: decision, current: build)
      #expect(alert.messageText == decision.message(current: build).headline)
      #expect(alert.informativeText == decision.message(current: build).detail)
      #expect(alert.buttons.map(\.title) == ["Open Release Page", "Later"])
      #expect(alert.buttons[0].keyEquivalent == "\r", "the first button is the one ↩ presses")
      #expect(alert.buttons[1].keyEquivalent == "\u{1b}")
    }

    @Test func withNothingToOfferThereIsOneButton() {
      let decision = UpdateCheck.decide(current: "9.9.9", lookup: .latest(tag: "v9.9.9"))
      #expect(decision.page == nil)
      #expect(UpdateWindow.alert(for: decision, current: build).buttons.map(\.title) == ["OK"])
    }

    /// Seen on a hosted Mac: in the window Arbor laid out itself the buttons touched the bottom edge.
    @Test func theButtonsStandClearOfTheEdges() throws {
      let alert = UpdateWindow.alert(for: UpdateCheck.decide(current: "0.9.0", lookup: .latest(tag: "v9.9.9")), current: build)
      alert.layout()
      let content = try #require(alert.window.contentView)
      content.layoutSubtreeIfNeeded()
      for button in alert.buttons {
        let frame = button.convert(button.bounds, to: content)
        #expect(content.bounds.insetBy(dx: 8, dy: 8).contains(frame), "\(button.title) at \(frame) in \(content.bounds)")
      }
    }
  }
#endif
