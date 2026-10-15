import CoreGraphics

/// In the JSON that scripts read, a rectangle is `{"x":0,"y":25,"width":720,"height":875}`, not Foundation's
/// `[[0,25],[720,875]]` (F50, part 3). In Swift the property stays a `CGRect`:
///
///     @JSONRect public var frame: CGRect
///     @JSONRect public var desktopFrame: CGRect?          // left out when nil
///     @JSONRect public var windowFrames: [WindowID: CGRect]
///
/// Reading accepts both forms. Files Arbor keeps for itself (`state.json`) are not touched by this.
@propertyWrapper
public struct JSONRect<Value: JSONRectValue>: Equatable, Sendable, Codable {
  public var wrappedValue: Value

  public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }

  public init(from decoder: any Decoder) throws { wrappedValue = try Value(jsonRectsFrom: decoder) }

  public func encode(to encoder: any Encoder) throws { try wrappedValue.encodeJSONRects(to: encoder) }
}

/// What `@JSONRect` can wrap.
public protocol JSONRectValue: Equatable, Sendable {
  init(jsonRectsFrom decoder: any Decoder) throws
  func encodeJSONRects(to encoder: any Encoder) throws
}

/// The object itself.
private struct RectObject: Codable {
  var rect: CGRect

  private enum CodingKeys: String, CodingKey { case x, y, width, height }

  init(_ rect: CGRect) { self.rect = rect }

  init(from decoder: any Decoder) throws {
    guard let c = try? decoder.container(keyedBy: CodingKeys.self) else {
      rect = try CGRect(from: decoder)
      return
    }
    rect = CGRect(
      x: try c.decode(Double.self, forKey: .x), y: try c.decode(Double.self, forKey: .y),
      width: try c.decode(Double.self, forKey: .width), height: try c.decode(Double.self, forKey: .height))
  }

  func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    // Not minX and width: a rectangle is written as it is stored.
    try c.encode(Double(rect.origin.x), forKey: .x)
    try c.encode(Double(rect.origin.y), forKey: .y)
    try c.encode(Double(rect.size.width), forKey: .width)
    try c.encode(Double(rect.size.height), forKey: .height)
  }
}

extension CGRect: JSONRectValue {
  public init(jsonRectsFrom decoder: any Decoder) throws { self = try RectObject(from: decoder).rect }
  public func encodeJSONRects(to encoder: any Encoder) throws { try RectObject(self).encode(to: encoder) }
}

extension Optional: JSONRectValue where Wrapped == CGRect {
  public init(jsonRectsFrom decoder: any Decoder) throws {
    self = try decoder.singleValueContainer().decodeNil() ? nil : RectObject(from: decoder).rect
  }

  public func encodeJSONRects(to encoder: any Encoder) throws {
    guard let rect = self else {
      var container = encoder.singleValueContainer()
      return try container.encodeNil()
    }
    try RectObject(rect).encode(to: encoder)
  }
}

extension Dictionary: JSONRectValue where Key == WindowID, Value == CGRect {
  public init(jsonRectsFrom decoder: any Decoder) throws {
    self = try [WindowID: RectObject](from: decoder).mapValues(\.rect)
  }

  public func encodeJSONRects(to encoder: any Encoder) throws { try mapValues(RectObject.init).encode(to: encoder) }
}

// The code the compiler writes for a struct calls these for an optional rectangle, being the closest match:
// a key that is missing reads as nil, and nil writes no key.
extension KeyedDecodingContainer {
  public func decode(_ type: JSONRect<CGRect?>.Type, forKey key: Key) throws -> JSONRect<CGRect?> {
    try decodeIfPresent(type, forKey: key) ?? JSONRect(wrappedValue: nil)
  }
}

extension KeyedEncodingContainer {
  public mutating func encode(_ value: JSONRect<CGRect?>, forKey key: Key) throws {
    guard value.wrappedValue != nil else { return }
    try encodeIfPresent(value, forKey: key)
  }
}
