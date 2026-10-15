import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

extension Settings {
  /// Every gesture that needs an event tap switched on, whatever Arbor ships with: the pinch, ⌃⌥ + scroll, the ⌃⌥ rectangle, ⇧-drag on
  /// the Desktop. For a test about one of them, or about whoever takes them away for a while (a pause, a hold, an app that keeps its
  /// keys, the permission gone): with nothing to take away it would prove nothing.
  static var withGestures: Settings {
    var settings = Settings()
    settings.pointerGestures = true
    settings.gesturesEnabled = true
    settings.scrollZoom = true
    settings.frameRectangleModifier = "ctrl+opt"
    settings.frameRectangleOnDesktop = true
    return settings
  }
}

/// The display (every display, if none is named) has been laid out since the arrangement or the view last changed, every
/// docked window that shows is in its place, and the others are out of view (`Harness.layoutProblems`).
@MainActor
func expectWindowsMatchLayout(
  _ h: Harness, on display: DisplayID? = nil, sourceLocation: SourceLocation = #_sourceLocation
) {
  for problem in h.layoutProblems(on: display) { Issue.record(Comment(rawValue: problem), sourceLocation: sourceLocation) }
}

/// How often Arbor moved `window` from entry `mark` of the move log on, not counting the questions put to it where it stood before it
/// went anywhere (Controller+AskFirst.swift). Nil if any of it was done twice or for nothing.
@MainActor
func movesWithoutWaste(_ h: Harness, of window: WindowID, since mark: Int = 0) -> Int? {
  let budget = Budget.tally(h.system.moveLog[min(mark, h.system.moveLog.count)...].filter { $0.window == window })
  return budget.waste == 0 ? budget.moves - budget.questions : nil
}

/// Whether a floating window is on the Desktop: on the screen, and over no docked window or tile. On the sides where
/// nothing is docked beside the Desktop it may reach the edge of the screen.
@MainActor
func isOnDesktop(_ window: WindowID, _ h: Harness) -> Bool {
  guard let frame = h.frame(window), let layout = h.layout, layout.desktopFrame != nil else { return false }
  return h.visibleFrame.contains(frame) && !layout.windowFrames.values.contains { $0.overlaps(frame) }
    && !layout.tiles.contains { $0.frame.overlaps(frame) }
}

extension Settings {
  /// The settings as they ship, but with `floatingWindowsMakeWay` on: floating windows are kept on the Desktop, where docked windows
  /// push them aside and squeeze them, as they did until Q20 (collab/QUESTIONS.md). For the tests of that behaviour, which
  /// the setting keeps alive. As Arbor ships, a floating window's frame is its person's (`FloatingFrameTests`).
  static var makingWay: Settings {
    var settings = Settings()
    settings.floatingWindowsMakeWay = true
    return settings
  }
}

/// For the tests of tiles, which the setting `windowsThatDoNotFit` keeps alive: every harness the test makes has it at `tile`
/// (`Harness.makesTiles`). At the head of a test or of a suite: `@Test(.withTiles)`, `@Suite(.withTiles)`.
struct WithTiles: TestTrait, SuiteTrait, TestScoping {
  var isRecursive: Bool { true }

  func provideScope(
    for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void
  ) async throws {
    try await TilesForTests.$areAskedFor.withValue(true) { try await function() }
  }
}

extension Trait where Self == WithTiles {
  static var withTiles: Self { Self() }
}

extension Harness {
  /// Whether floating windows leave the view with the Desktop and come back with it: only those that make way do (Q29, 4). For a test
  /// that chooses no settings, holds either way, and has one step at which the two worlds differ: it runs as Arbor ships, and the
  /// other way round in `make test-making-way`.
  var floatingWindowsLeaveWithTheDesktop: Bool { controller.settings.floatingWindowsMakeWay }
}
