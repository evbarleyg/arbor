import CoreGraphics

/// What a docked window looked like before it was docked
/// (docs/features/F48-floating-restores-size.md). Docking stretches a window to its slot; when it
/// floats again, or Arbor lets go of it, it gets its own size back.
extension Workspace {
  /// The frame `window` floated at before it was docked. Nil for a window that is not docked, for
  /// one that has been docked for as long as Arbor has known it, and for a frame no window
  /// could take (only a damaged file holds one).
  public func undockedFrame(of window: WindowID) -> CGRect? {
    guard let frame = undockedFrames?[window], isDocked(window) else { return nil }
    let numbers = [frame.origin.x, frame.origin.y, frame.size.width, frame.size.height]
    guard numbers.allSatisfy(\.isFinite), frame.size.width >= 1, frame.size.height >= 1 else { return nil }
    return frame
  }

  mutating func setUndockedFrame(_ frame: CGRect?, of window: WindowID) {
    guard frame != nil || undockedFrames?[window] != nil else { return }
    var frames = undockedFrames ?? [:]
    frames[window] = frame
    undockedFrames = frames.isEmpty ? nil : frames
  }

  /// After the tree was replaced: floating windows that it docks stop floating and are
  /// remembered, and windows that it no longer docks are forgotten.
  mutating func stopFloatingDockedWindows() {
    let docked = tree.allWindows
    var frames: [WindowID: CGRect] = [:]
    for window in docked { frames[window] = floating.removeValue(forKey: window) ?? undockedFrames?[window] }
    undockedFrames = frames.isEmpty ? nil : frames
  }

  /// Puts `replacement` where `window` is docked: the same window under a new number, after its
  /// app restarted. What was remembered about it still holds.
  public mutating func replaceWindow(_ window: WindowID, with replacement: WindowID) {
    tree.replaceWindow(window, with: replacement)
    let frame = undockedFrames?[window]
    setUndockedFrame(nil, of: window)
    setUndockedFrame(frame, of: replacement)
  }

  /// After docked windows were traded with another display's tree (`swap`): those that left are forgotten here, and
  /// those that came are remembered at the frames they would float at here.
  public mutating func rememberUndockedFrames(ofArrivals arrivals: [WindowID: CGRect]) {
    var frames = (undockedFrames ?? [:]).filter { isDocked($0.key) }
    for (window, frame) in arrivals where isDocked(window) { frames[window] = frame }
    undockedFrames = frames.isEmpty ? nil : frames
  }
}
