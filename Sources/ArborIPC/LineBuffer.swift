/// Bytes in, lines out. A socket delivers the control protocol's lines in pieces of any size; this
/// puts them back together. Both ends use it: the server for the request, `arborctl watch` for
/// the events.
public struct LineBuffer: Sendable {
  /// The longest line accepted, in bytes, so that a peer that never sends a newline cannot
  /// make the buffer grow for ever.
  public let limit: Int
  /// True once a line has grown past `limit`. What follows cannot be told apart from the rest of
  /// that line, so nothing more is returned; close the connection.
  public private(set) var overflowed = false
  private var partial: [UInt8] = []

  public init(limit: Int) {
    self.limit = limit
  }

  /// Takes the bytes that arrived and returns the lines they complete, oldest first, without
  /// their line endings (`\n` or `\r\n`). Bytes that are not UTF-8 are replaced, never refused.
  public mutating func append<Bytes: Sequence>(_ bytes: Bytes) -> [String] where Bytes.Element == UInt8 {
    var lines: [String] = []
    for byte in bytes {
      if overflowed { break }
      if byte == UInt8(ascii: "\n") {
        lines.append(takeLine())
      } else if partial.count < limit {
        partial.append(byte)
      } else {
        overflowed = true
        partial = []
      }
    }
    return lines
  }

  /// The stream ended: what arrived after the last newline, or nil if nothing did.
  public mutating func finish() -> String? {
    partial.isEmpty ? nil : takeLine()
  }

  private mutating func takeLine() -> String {
    if partial.last == UInt8(ascii: "\r") { partial.removeLast() }
    defer { partial.removeAll(keepingCapacity: true) }
    return String(decoding: partial, as: UTF8.self)
  }
}
