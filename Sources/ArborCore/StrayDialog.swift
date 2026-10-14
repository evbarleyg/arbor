import CoreGraphics

/// Dialogs that open out of view (F47).
///
/// Arbor arranges only ordinary windows, and keeps those outside the view just past a corner of the display. Apps place
/// alerts and panels relative to their main window, so a dialog of an app whose window is out of view can open out there
/// too. Nobody can find it, and the app looks hung.
public enum StrayDialog {
  /// Windows smaller than this on either side are off screen on purpose.
  public static let smallestSide: CGFloat = 40

  public struct Display: Equatable, Sendable {
    public var frame: CGRect
    public var visibleFrame: CGRect

    public init(frame: CGRect, visibleFrame: CGRect) {
      self.frame = frame
      self.visibleFrame = visibleFrame
    }
  }

  /// Where to move a dialog, without resizing it, or nil to leave it alone.
  ///
  /// - Parameters:
  ///   - frame: the dialog's frame.
  ///   - siblings: the frames of its app's ordinary windows. Only if one of them is out of view is the dialog's place
  ///     Arbor's doing; what apps that Arbor leaves alone do with their windows is their business.
  public static func home(for frame: CGRect, siblings: [CGRect], displays: [Display]) -> CGPoint? {
    func isOutOfView(_ rect: CGRect) -> Bool { displays.allSatisfy { rect.fractionInside($0.frame) < 0.5 } }
    guard frame.width >= smallestSide, frame.height >= smallestSide, isOutOfView(frame),
      siblings.contains(where: isOutOfView),
      // Windows out of view wait at a corner of their own display, so the nearest one is the app's.
      let display = displays.min(by: { $0.frame.distance(to: frame.center) < $1.frame.distance(to: frame.center) })
    else { return nil }
    let visible = display.visibleFrame
    let centred = CGRect(
      x: visible.midX - frame.width / 2, y: visible.midY - frame.height / 2, width: frame.width, height: frame.height)
    // A dialog larger than the display keeps its title bar in reach.
    return CGPoint(x: max(centred.minX, visible.minX).rounded(), y: max(centred.minY, visible.minY).rounded())
  }
}
