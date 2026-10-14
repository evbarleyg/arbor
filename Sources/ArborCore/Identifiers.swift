/// A window, identified by its window-server number (CGWindowID). Stable for
/// the lifetime of the window, not across app restarts.
public struct WindowID: RawRepresentable, Hashable, Comparable, Codable, Sendable,
  CustomStringConvertible, CodingKeyRepresentable
{
  public let rawValue: UInt32

  public init(rawValue: UInt32) { self.rawValue = rawValue }
  public init(_ rawValue: UInt32) { self.rawValue = rawValue }

  /// Parses "123" or "w123".
  public init?(word: String) {
    let digits = word.hasPrefix("w") ? String(word.dropFirst()) : word
    guard let value = UInt32(digits) else { return nil }
    self.rawValue = value
  }

  public static func < (a: WindowID, b: WindowID) -> Bool { a.rawValue < b.rawValue }
  public var description: String { "w\(rawValue)" }

  public var codingKey: any CodingKey { StringKey(String(rawValue)) }
  public init?<T: CodingKey>(codingKey: T) {
    // Only the form `codingKey` writes: "+5" and "05" would be second names for "5" in the same object.
    guard let value = UInt32(codingKey.stringValue), String(value) == codingKey.stringValue else { return nil }
    self.rawValue = value
  }
}

/// A node in one display's layout tree. Unique within its tree only.
public struct NodeID: RawRepresentable, Hashable, Comparable, Codable, Sendable,
  CustomStringConvertible, CodingKeyRepresentable
{
  public let rawValue: Int

  public init(rawValue: Int) { self.rawValue = rawValue }
  public init(_ rawValue: Int) { self.rawValue = rawValue }

  /// Parses "3" or "n3".
  public init?(word: String) {
    let digits = word.hasPrefix("n") ? String(word.dropFirst()) : word
    guard let value = Int(digits) else { return nil }
    self.rawValue = value
  }

  public static func < (a: NodeID, b: NodeID) -> Bool { a.rawValue < b.rawValue }
  public var description: String { "n\(rawValue)" }

  public var codingKey: any CodingKey { StringKey(String(rawValue)) }
  public init?<T: CodingKey>(codingKey: T) {
    guard let value = Int(codingKey.stringValue), String(value) == codingKey.stringValue else { return nil }
    self.rawValue = value
  }
}

/// A display, identified by its persistent UUID string so layouts survive
/// reconnects and reboots.
public struct DisplayID: RawRepresentable, Hashable, Comparable, Codable, Sendable,
  CustomStringConvertible, CodingKeyRepresentable
{
  public let rawValue: String

  public init(rawValue: String) { self.rawValue = rawValue }
  public init(_ rawValue: String) { self.rawValue = rawValue }

  public static func < (a: DisplayID, b: DisplayID) -> Bool { a.rawValue < b.rawValue }
  public var description: String { rawValue }

  public var codingKey: any CodingKey { StringKey(rawValue) }
  public init?<T: CodingKey>(codingKey: T) { self.rawValue = codingKey.stringValue }
}

struct StringKey: CodingKey {
  var stringValue: String
  var intValue: Int? { nil }
  init(_ value: String) { stringValue = value }
  init?(stringValue: String) { self.stringValue = stringValue }
  init?(intValue: Int) { return nil }
}
