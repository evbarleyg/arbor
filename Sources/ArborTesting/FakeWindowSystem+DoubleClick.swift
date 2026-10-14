import ArborCore
import ArborKit
import CoreGraphics

/// Double-clicks, and what macOS makes of one on a title bar.
extension FakeWindowSystem {
  /// The user double-clicks at `point` (global coordinates). The first click goes to the window under the pointer; the
  /// second is `secondClick(at:)`, whose answer this returns.
  @discardableResult
  public func doubleClick(at point: CGPoint) -> Bool {
    cursor = point
    if let under = window(under: point) { userClick(under) }
    return secondClick(at: point)
  }

  /// The second click of a pair arrives at `point`: after `doubleClick(at:)`'s first, or after a click on something of Arbor's
  /// own (`FakeOverlays.clickTile`). Returns whether it was Arbor's (F14), which no app then hears of; with a modifier key
  /// held none is. One that is not Arbor's goes to the window that is under the pointer by now, and is reported as the
  /// Accessibility layer reports it. What macOS or the app then does with that window is for the test to play
  /// (`zoomAsMacOSDoes`, `userMove(_:to:)`, `setMinimized`).
  @discardableResult
  public func secondClick(at point: CGPoint) -> Bool {
    cursor = point
    if heldModifiers.isEmpty, events?.doubleClicked(at: point) == true {
      // The tap tells whoever listens for presses of the one it holds back.
      events?.pointerPressed()
      return true
    }
    guard let under = window(under: point) else { return false }
    userClick(under, release: false)
    windows[under]?.doubleClicks += 1
    events?.doubleClickReached(under)
    mouseDown = false
    return false
  }

  public func macTitleBarAction() -> MacTitleBarAction { titleBarAction }

  /// The user double-clicks the middle of `window`'s title bar, and macOS does what it is set to do (`titleBarAction`) with the
  /// window that got the clicks, which is the one in front there.
  public func doubleClickTitleBar(of window: WindowID) {
    guard let bar = windows[window]?.snapshot.frame else { return }
    let point = CGPoint(x: bar.midX, y: bar.minY + 12)
    // Where Arbor takes the second click, macOS has nothing to act on.
    if doubleClick(at: point) { return }
    // Whatever the first click set off, macOS acts on the window that got the second.
    guard let got = self.window(under: point) else { return }
    switch titleBarAction {
    case .fill, .zoom: zoomAsMacOSDoes(got)
    case .minimize: setMinimized(got, true)
    case .nothing: break
    }
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
    guard zoomed != current else { return }
    windows[window]!.zoom = (zoomed, current)
    userMove(window, to: zoomed)
  }

  private func window(under point: CGPoint) -> WindowID? {
    windowsFrontToBack().first { windows[$0]?.snapshot.isPresent == true && windows[$0]!.snapshot.frame.contains(point) }
  }
}
