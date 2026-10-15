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

/// Whether a floating window is on the Desktop: on the screen, and over no docked window or tile. On the sides where
/// nothing is docked beside the Desktop it may reach the edge of the screen.
@MainActor
func isOnDesktop(_ window: WindowID, _ h: Harness) -> Bool {
  guard let frame = h.frame(window), let layout = h.layout, layout.desktopFrame != nil else { return false }
  return h.visibleFrame.contains(frame) && !layout.windowFrames.values.contains { $0.overlaps(frame) }
    && !layout.tiles.contains { $0.frame.overlaps(frame) }
}
