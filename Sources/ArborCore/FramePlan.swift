import CoreGraphics

/// Which Accessibility attributes to set, in which order, to give a window a frame.
public enum FramePlan {
  public enum Step: Equatable, Sendable {
    case size, position
  }

  /// Size, position, size: the first resize keeps a large window from being clamped when it moves to a
  /// smaller display, the second applies the size the destination allows.
  public static let full: [Step] = [.size, .position, .size]

  /// The steps from the frame the window is believed to have. A window that only changes place, as every
  /// window does when it is parked and most do when they come back, needs one call instead of three, and
  /// its app is spared two rounds of laying out its content for a size it already has. The belief can be
  /// out of date, so the caller reads the frame back and falls back on `full` if the size is not right.
  public static func steps(from known: CGRect?, to target: CGRect) -> [Step] {
    guard let known, abs(known.width - target.width) < 0.5, abs(known.height - target.height) < 0.5 else {
      return full
    }
    return [.position]
  }

  /// Whether a shortened plan has to be followed by the full one: the window turned out to have another size.
  public static func needsFullPlan(after steps: [Step], result: CGRect, target: CGRect) -> Bool {
    steps != full && (abs(result.width - target.width) > 1 || abs(result.height - target.height) > 1)
  }
}
