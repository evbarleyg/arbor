/// The app in front: the one whose menus are in the menu bar and that key presses go to.
public struct FrontmostApp: Equatable, Sendable {
  /// Nil for a program that is not in a bundle.
  public var bundleID: String?
  public var name: String

  public init(bundleID: String?, name: String) {
    self.bundleID = bundleID
    self.name = name
  }
}

extension WindowSystemEvents {
  /// For listeners that only care about windows.
  public func applicationActivated(_ app: FrontmostApp?) {}
  public func accessibilityWasRefused() {}
}
