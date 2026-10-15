import CoreGraphics

/// What has been seen of the sizes one window can have. Nobody can ask an app how small or how large it lets a window be: it
/// is offered a size, and the size it took is read back. As small and as large as a window has been it can be again, so
/// only a size beyond that is a question. Width and height are kept apart: a settings window has one fixed side.
public struct SeenSizes: Equatable, Sendable {
  /// The least and the greatest width and height it has had, or has been offered and come within a step of: what a terminal
  /// makes of such an offer is known, though it never has quite that size.
  public var least: CGSize
  public var most: CGSize
  /// The width and the height it stopped at when it was offered more; 0 where it has always taken what it was offered.
  public var stoppedAt = CGSize.zero
  /// The last width and height it was offered and came within a step of without reaching it, and what it took; 0 where there
  /// is none. A terminal or a window that cannot grow: nobody can tell. Either takes the same again of anything between the two.
  public var closeOffer = CGSize.zero
  public var closeTook = CGSize.zero

  /// A difference that is no refusal: apps round.
  static let slack: CGFloat = 2
  /// No step is larger than this: character cells at a very large font. A terminal takes the whole cells nearest to what it is
  /// offered, so a window that comes this close has not stopped growing. Offered more, it takes more.
  public static let largestStep: CGFloat = 36

  public init(_ size: CGSize) {
    least = size
    most = size
  }

  public init(least: CGSize, most: CGSize, stoppedAt: CGSize, closeOffer: CGSize = .zero, closeTook: CGSize = .zero) {
    self.least = least
    self.most = most
    self.stoppedAt = stoppedAt
    self.closeOffer = closeOffer
    self.closeTook = closeTook
  }

  public mutating func see(_ size: CGSize) {
    least = CGSize(width: min(least.width, size.width), height: min(least.height, size.height))
    most = CGSize(width: max(most.width, size.width), height: max(most.height, size.height))
  }

  /// How small and how large it has been it has been. Whether it can grow further is what may have changed.
  public mutating func forgetWhereItStopped() {
    (stoppedAt, closeOffer, closeTook) = (.zero, .zero, .zero)
  }

  /// The window was offered a size, and this is the size it took.
  public mutating func note(took actual: CGSize, offered: CGSize) {
    see(actual)
    // A size it fills says nothing about a larger one: only having been seen larger ends what is on record.
    (stoppedAt.width, most.width, closeOffer.width, closeTook.width) = Self.note(
      took: actual.width, offered: offered.width, (stoppedAt.width, most.width, closeOffer.width, closeTook.width))
    (stoppedAt.height, most.height, closeOffer.height, closeTook.height) = Self.note(
      took: actual.height, offered: offered.height, (stoppedAt.height, most.height, closeOffer.height, closeTook.height))
  }

  /// One way, width or height.
  private static func note(
    took actual: CGFloat, offered: CGFloat, _ known: (stoppedAt: CGFloat, most: CGFloat, closeOffer: CGFloat, closeTook: CGFloat)
  ) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
    var known = known
    guard actual >= offered - largestStep else {
      known.stoppedAt = actual
      return known
    }
    if actual > known.stoppedAt { known.stoppedAt = 0 }
    if actual <= offered + slack { known.most = max(known.most, offered) }
    if actual < offered - slack {
      (known.closeOffer, known.closeTook) = (offered, actual)
    } else if actual > known.closeTook {
      (known.closeOffer, known.closeTook) = (0, 0)
    }
    return known
  }

  /// How wide and how high it is expected to become at most when it is `offered` a size, being `now` this large; nil where no
  /// limit is known. One that is larger now than where it stopped has outgrown whatever stopped it.
  public func limit(now: CGSize, offered: CGSize) -> (width: CGFloat?, height: CGFloat?) {
    func limit(_ now: CGFloat, _ offered: CGFloat, _ stoppedAt: CGFloat, _ closeOffer: CGFloat, _ closeTook: CGFloat) -> CGFloat? {
      if stoppedAt > 0, now <= stoppedAt + Self.slack { return stoppedAt }
      if closeTook > 0, now <= closeTook + Self.slack, offered >= closeTook, offered <= closeOffer + Self.slack { return closeTook }
      return nil
    }
    return (
      limit(now.width, offered.width, stoppedAt.width, closeOffer.width, closeTook.width),
      limit(now.height, offered.height, stoppedAt.height, closeOffer.height, closeTook.height)
    )
  }

  /// Whether `size` is narrower or lower than the window has ever been, so that its app may refuse it.
  public func mayRefuseToShrink(to size: CGSize) -> Bool {
    size.width < least.width - Self.slack || size.height < least.height - Self.slack
  }

  /// Whether `size` is wider or higher than the window has ever been, and nothing says yet that it will stop short of it.
  public func mayRefuseToGrow(to size: CGSize, now: CGSize) -> Bool {
    let limit = limit(now: now, offered: size)
    return (size.width > most.width + Self.slack && limit.width == nil)
      || (size.height > most.height + Self.slack && limit.height == nil)
  }
}
