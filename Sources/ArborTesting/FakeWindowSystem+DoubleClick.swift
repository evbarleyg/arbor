import ArborCore
import ArborKit
import CoreGraphics

/// Double-clicks, and what macOS makes of one on a title bar.
extension FakeWindowSystem {
  /// The user double-clicks at `point` (global coordinates) with no modifier keys held. Both clicks go to the window
  /// under the pointer, and the second is reported as the Accessibility layer reports it. What macOS or the app then
  /// does with the window is for the test to play (`zoomAsMacOSDoes`, `userMove(_:to:)`, `setMinimized`).
  public func doubleClick(at point: CGPoint) {
    cursor = point
    guard let under = window(under: point) else { return }
    userClick(under)
    userClick(under, release: false)
    windows[under]?.doubleClicks += 1
    events?.doubleClickReached(under)
    mouseDown = false
  }

  /// The user double-clicks the middle of `window`'s title bar, and macOS zooms the window that got the clicks, which is
  /// the one in front there.
  public func doubleClickTitleBar(of window: WindowID) {
    guard let bar = windows[window]?.snapshot.frame else { return }
    let point = CGPoint(x: bar.midX, y: bar.minY + 12)
    guard let got = self.window(under: point) else { return }
    doubleClick(at: point)
    // Whatever the clicks set off, the window may be elsewhere by now.
    if windows[got]?.snapshot.frame.contains(point) == true { zoomAsMacOSDoes(got) }
  }

  /// What macOS does, as it comes, at a double-click on a title bar and at ⌥-click on the green button: the window fills the
  /// visible frame of its display as far as its app lets it grow and shrink. If it still has the frame the last zoom gave it, it
  /// returns to the one it had before.
  public func zoomAsMacOSDoes(_ window: WindowID) {
    guard let fake = windows[window], fake.snapshot.isPresent, !fake.snapshot.isFullScreen else { return }
    let current = fake.snapshot.frame
    if let zoom = fake.zoom, zoom.to == current {
      windows[window]!.zoom = nil
      return userMove(window, to: zoom.from)
    }
    guard let display = displayList.first(where: { $0.frame.contains(current.center) }) ?? displayList.first else { return }
    var zoomed = display.visibleFrame
    if let maximum = fake.maximumSize {
      zoomed.size = CGSize(width: min(zoomed.width, maximum.width), height: min(zoomed.height, maximum.height))
    }
    zoomed.size = CGSize(width: max(zoomed.width, fake.minimumSize.width), height: max(zoomed.height, fake.minimumSize.height))
    zoomed = zoomedAsItsAppHasIt(zoomed, fake, within: display.visibleFrame)
    guard zoomed != current else { return }
    windows[window]!.zoom = (zoomed, current)
    userMove(window, to: zoomed)
  }

  private func window(under point: CGPoint) -> WindowID? {
    windowsFrontToBack().first { windows[$0]?.snapshot.isPresent == true && windows[$0]!.snapshot.frame.contains(point) }
  }
}
