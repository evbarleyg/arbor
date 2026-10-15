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

  /// The user double-clicks the middle of `window`'s title bar, or `hand`, and macOS zooms the window that got the clicks, which is
  /// the one in front there.
  public func doubleClickTitleBar(of window: WindowID, at hand: CGPoint? = nil) {
    guard let bar = windows[window]?.snapshot.frame else { return }
    let point = hand ?? CGPoint(x: bar.midX, y: bar.minY + 12)
    guard let got = self.window(under: point) else { return }
    doubleClick(at: point)
    // Whatever the clicks set off, the window may be elsewhere by now.
    if windows[got]?.snapshot.frame.contains(point) == true { zoomAsMacOSDoes(got) }
  }

  /// What macOS does, as it comes, at a double-click on a title bar and at ⌥-click on the green button: the window fills the
  /// visible frame of its display as far as its app lets it grow and shrink. If it still has the frame the last zoom gave it, it
  /// returns to the one it had before.
  ///
  /// Not so where macOS is set to fill (`andBack: false`): seen on macOS 26, a filled window that is double-clicked again stays filled.
  public func zoomAsMacOSDoes(_ window: WindowID, andBack: Bool = true) {
    guard let fake = windows[window], fake.snapshot.isPresent, !fake.snapshot.isFullScreen else { return }
    let current = fake.snapshot.frame
    if let zoom = fake.zoom, zoom.to == current {
      guard andBack else { return }
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

  /// What a person can ask of macOS about a window without touching its title bar twice: ⌥-click on the green button, the Window menu, the keys
  /// macOS has for its own tiling.
  public enum AskOfMacOS: String, CaseIterable, Sendable {
    case fill, left, right, top, bottom, quarter, centre
    /// Window ▸ Move to the other display: as large as it is.
    case elsewhere
  }

  /// The person asks, with a click or a key, and macOS moves the window, which its app reports. In one step: whoever wants a Mac's ten
  /// plays them with `secondsSinceInput` and `userMove`. A window whose app does not let it take the size is moved as it is.
  public func askMacOS(for what: AskOfMacOS, about window: WindowID) {
    guard let fake = windows[window], fake.snapshot.isPresent, !fake.snapshot.isFullScreen,
      let visible = (displayList.first { $0.frame.contains(fake.snapshot.frame.center) } ?? displayList.first)?.visibleFrame
    else { return }
    let (w, h) = (visible.width, visible.height)
    var frame: CGRect =
      switch what {
      case .fill: visible
      case .left: CGRect(x: visible.minX, y: visible.minY, width: w / 2, height: h)
      case .right: CGRect(x: visible.midX, y: visible.minY, width: w / 2, height: h)
      case .top: CGRect(x: visible.minX, y: visible.minY, width: w, height: h / 2)
      case .bottom: CGRect(x: visible.minX, y: visible.midY, width: w, height: h / 2)
      case .quarter: CGRect(x: visible.midX, y: visible.minY, width: w / 2, height: h / 2)
      case .centre:
        CGRect(
          x: visible.midX - fake.snapshot.frame.width / 2, y: visible.midY - fake.snapshot.frame.height / 2,
          width: fake.snapshot.frame.width, height: fake.snapshot.frame.height)
      case .elsewhere:
        displayList.first { !$0.frame.contains(fake.snapshot.frame.center) }.map {
          CGRect(origin: CGPoint(x: $0.visibleFrame.minX + 100, y: $0.visibleFrame.minY + 60), size: fake.snapshot.frame.size)
        } ?? fake.snapshot.frame
      }
    if let most = fake.maximumSize { frame.size = CGSize(width: min(frame.width, most.width), height: min(frame.height, most.height)) }
    frame.size = CGSize(width: max(frame.width, fake.minimumSize.width), height: max(frame.height, fake.minimumSize.height))
    // macOS puts no title bar under the menu bar, however large the window.
    if what != .elsewhere { frame.origin.y = max(frame.origin.y, visible.minY) }
    guard frame != fake.snapshot.frame else { return }
    windows[window]!.asksOfMacOS += 1
    windows[window]!.zoom = nil
    let before = secondsSinceInput
    secondsSinceInput = 0.4
    defer { secondsSinceInput = before }
    userMove(window, to: frame)
  }

  private func window(under point: CGPoint) -> WindowID? {
    windowsFrontToBack().first { windows[$0]?.snapshot.isPresent == true && windows[$0]!.snapshot.frame.contains(point) }
  }
}
