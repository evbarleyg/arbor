import ArborCore
import CoreGraphics

/// What the behaviour switches of F33 need beyond a condition where the behaviour lives.
extension Controller {
  // MARK: shareRemovedSpace

  /// The least a moved seam leaves on either side, for `LayoutTree.moveBoundary`. When removed space
  /// is not shared, a child's weight covers its slot and one gap (`LayoutEngine`), so the gap is
  /// added for the slot's own minimum to be the same either way.
  func minimumPointsBesideSeam(on display: DisplayID) -> Double {
    LayoutTree.minimumPointsBesideBoundary + (settings.shareRemovedSpace ? 0 : max(options(for: display).gap, 0))
  }

  // MARK: shrinkOutOfView
  //
  // A window moved out of view is also shrunk, and gets its size back when it returns. A docked
  // window's size comes from the layout and a floating one's from `Workspace.floating`, neither of
  // which parking touches. The size remembered here is for the ways out of the corner that go by
  // the window's own size: `float` and `float-all` on a window out of view, excluding its app,
  // and its display going away.

  /// The most a window measures while it is parked with `shrinkOutOfView` on. Smaller windows keep their size.
  static let smallParkedSize = CGSize(width: 320, height: 200)
  /// What replaces `smallParkedSize` for a window found shrunk whose size nobody remembers.
  static let unrememberedSize = CGSize(width: 800, height: 600)

  struct ShrunkWindow {
    /// The size the window had when it went out of view.
    var inView: CGSize
    /// The size it took in the corner. While it still has it, `inView` is what it should return to.
    var parked: CGSize
  }

  /// The size to park `window` at, given the size it has now, which is remembered.
  func parkingSize(for window: WindowID, now size: CGSize) -> CGSize {
    // A window that is parked again before it got its size back (its display changed) is still
    // as small as the last parking left it, whatever the setting says now. Otherwise, with the
    // setting off nothing is remembered, so nothing here can change what Arbor did without it.
    if !isShrunk(window, now: size) {
      shrunk[window] = settings.shrinkOutOfView ? ShrunkWindow(inView: size, parked: size) : nil
    }
    guard settings.shrinkOutOfView else { return size }
    return CGSize(
      width: min(size.width, Self.smallParkedSize.width), height: min(size.height, Self.smallParkedSize.height))
  }

  /// Called by `park` with the frame the window `took` when `asked` to be small. An app that
  /// refuses to shrink that far leaves the window larger than the corner was chosen for, and in the
  /// bottom-left corner the extra width would show, so the corner is chosen again for the size it
  /// took. Nothing is learned about the app's minimum size: that is for windows in view.
  func settleParkedSmall(
    _ window: WindowID, took: CGRect, asked: CGRect, on display: DisplaySnapshot
  ) -> CGRect {
    var actual = took
    let origin = parkingOrigin(for: took.size, of: window, on: display)
    if took.size != asked.size, origin != asked.origin, let moved = system.setFrame(CGRect(origin: origin, size: took.size), of: window) {
      actual = moved
    }
    shrunk[window]?.parked = actual.size
    return actual
  }

  /// The size `window` has when it is in view: its size now, unless it is parked small.
  func sizeInView(of window: WindowID) -> CGSize? {
    guard let size = windows[window]?.frame.size else { return nil }
    return isShrunk(window, now: size) ? shrunk[window]?.inView : size
  }

  /// Whether the size remembered for `window` still applies. Entries are not removed when a window
  /// returns to view (that happens in many places); one is out of date once the window is
  /// neither parked nor the size it was parked at. The tolerance is `windowChanged`'s for apps
  /// that round their size.
  private func isShrunk(_ window: WindowID, now size: CGSize) -> Bool {
    guard let entry = shrunk[window] else { return false }
    return parked.contains(window)
      || (abs(entry.parked.width - size.width) <= 4 && abs(entry.parked.height - size.height) <= 4)
  }

  // MARK: After a run that did not quit cleanly

  /// `size` with each side that is exactly as long as parking small makes it replaced by a usable length.
  static func unshrunk(_ size: CGSize) -> CGSize {
    CGSize(
      width: abs(size.width - smallParkedSize.width) <= 1 ? unrememberedSize.width : size.width,
      height: abs(size.height - smallParkedSize.height) <= 1 ? unrememberedSize.height : size.height)
  }

  /// At launch: windows the saved arrangement knows that are found out of view were left in the
  /// corner by a run that did not quit cleanly, or by a pause while they were minimized or hidden
  /// (`shutdown` brings back the rest). They are parked, so they count as parked: whatever next
  /// brings one into view (its slot, the Desktop, `float`, `float-all`) then gives it a frame, where an
  /// unmarked floating window would be taken to be where the user put it. The size they are found
  /// at is not the size they have in view; after a pause that one is still remembered. Windows the
  /// saved arrangement does not know are rescued by `adopt`.
  func noteWindowsLeftParked() {
    shrunk = shrunk.filter { windows[$0.key] != nil }
    for workspace in workspaces.sorted(by: { $0.key < $1.key }).map(\.value) {
      for window in workspace.allWindows {
        guard let frame = windows[window]?.frame, isOutOfView(frame) else { continue }
        if !isShrunk(window, now: frame.size) {
          shrunk[window] = ShrunkWindow(
            inView: workspace.floating[window]?.size ?? Self.unshrunk(frame.size), parked: frame.size)
        }
        parked.insert(window)
        // Where that run put it, so that it is noticed if something brings it back (`hasLeftItsCorner`).
        settled[window] = frame
        Log.info("window \(window) was left out of view")
      }
    }
  }
}
