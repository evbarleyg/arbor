import Foundation

/// Any JSON. A query's reply carries its answer in this form (`CommandResult.json`) beside the text for people, and
/// `arborctl --json` prints it.
public enum JSONValue: Equatable, Sendable {
  case null
  case bool(Bool)
  case int(Int)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])

  /// What `value` encodes to. Nil if it cannot be encoded (a number that is not one).
  public init?(encoding value: some Encodable) {
    guard let data = try? JSONEncoder().encode(value), let decoded = try? JSONDecoder().decode(JSONValue.self, from: data)
    else { return nil }
    self = decoded
  }

  /// On one line, keys sorted, slashes as they are.
  public var text: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(self) else { return "null" }
    return String(decoding: data, as: UTF8.self)
  }

  public subscript(key: String) -> JSONValue? {
    if case .object(let members) = self { return members[key] }
    return nil
  }

  public subscript(index: Int) -> JSONValue? {
    if case .array(let items) = self, items.indices.contains(index) { return items[index] }
    return nil
  }
}

extension JSONValue: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int.self) {
      self = .int(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: JSONValue].self))
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null: try container.encodeNil()
    case .bool(let value): try container.encode(value)
    case .int(let value): try container.encode(value)
    case .number(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    case .array(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    }
  }
}
