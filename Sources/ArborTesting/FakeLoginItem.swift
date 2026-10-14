import ArborKit

/// macOS's login items, in memory.
@MainActor
public final class FakeLoginItem: LoginItem {
  public struct Refused: Error, CustomStringConvertible {
    public let description = "operation not permitted"
  }

  public var status: LoginItemStatus = .disabled
  /// Makes `setEnabled` fail, leaving the status as `statusAfterRefusal` says (or as it was).
  public var refuses = false
  public var statusAfterRefusal: LoginItemStatus?
  /// Every change asked for, in order.
  public private(set) var changes: [Bool] = []

  public init() {}

  public func setEnabled(_ enabled: Bool) throws {
    changes.append(enabled)
    if refuses {
      if let statusAfterRefusal { status = statusAfterRefusal }
      throw Refused()
    }
    status = enabled ? .enabled : .disabled
  }
}
