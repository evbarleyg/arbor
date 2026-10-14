import ArborCore
import Foundation

/// A trace as text: JSON lines, the header first (docs/TRACES.md).
extension Trace {
  public struct ParseError: Error, CustomStringConvertible, Equatable {
    /// The line of the file, counting from 1.
    public var line: Int
    public var reason: String

    public init(line: Int, reason: String) {
      self.line = line
      self.reason = reason
    }

    public var description: String { "line \(line): \(reason)" }
  }

  /// Reads a trace. Blank lines and lines starting with `#` are skipped, so a committed trace can carry
  /// remarks. A last line that is cut off (Arbor was killed while writing it) is dropped with a warning.
  public init(text: String) throws {
    let decoder = JSONDecoder()
    var header: TraceHeader?
    var entries: [TraceEntry] = []
    var warnings: [String] = []
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    let last = lines.lastIndex { !$0.allSatisfy(\.isWhitespace) }

    for (index, raw) in lines.enumerated() {
      let number = index + 1
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.isEmpty || line.hasPrefix("#") { continue }
      let data = Data(line.utf8)
      guard header != nil else {
        do {
          header = try decoder.decode(TraceHeader.self, from: data)
        } catch {
          throw ParseError(line: number, reason: "not a trace header: \(Self.reason(for: error))")
        }
        continue
      }
      do {
        var entry = try decoder.decode(TraceEntry.self, from: data)
        entry.number = number
        if case .unknown(let kind) = entry.line { warnings.append("line \(number): skipped unknown \(kind)") }
        entries.append(entry)
      } catch {
        guard index == last else { throw ParseError(line: number, reason: Self.reason(for: error)) }
        warnings.append("line \(number): the last line is cut off and was dropped")
      }
    }

    guard let header else { throw ParseError(line: 1, reason: "the file is empty") }
    guard header.trace <= TraceHeader.currentVersion else {
      throw ParseError(
        line: 1,
        reason: "format \(header.trace) is newer than this Arbor reads (\(TraceHeader.currentVersion))")
    }
    guard !header.displays.isEmpty else { throw ParseError(line: 1, reason: "the header lists no display") }
    self.init(header: header, entries: entries, warnings: warnings)
  }

  public init(contentsOf url: URL) throws {
    try self.init(text: String(decoding: try Data(contentsOf: url), as: UTF8.self))
  }

  /// The whole trace as text, ending with a newline.
  public func text() throws -> String {
    let writer = TraceWriter()
    return try ([writer.text(of: header)] + entries.map(writer.text(of:))).joined(separator: "\n") + "\n"
  }

  private static func reason(for error: any Error) -> String {
    guard let error = error as? DecodingError else { return "\(error)" }
    switch error {
    case .keyNotFound(let key, _): return "`\(key.stringValue)` is missing"
    case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
      let path = context.codingPath.map(\.stringValue).joined(separator: ".")
      return path.isEmpty ? context.debugDescription : "`\(path)`: \(context.debugDescription)"
    @unknown default: return "\(error)"
    }
  }
}

/// Turns headers and entries into lines of text.
public struct TraceWriter {
  private let encoder: JSONEncoder

  public init() {
    encoder = JSONEncoder()
    // Sorted, so that the same recording gives the same bytes on every platform and in every run.
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
  }

  public func text(of header: TraceHeader) throws -> String {
    String(decoding: try encoder.encode(header), as: UTF8.self)
  }

  /// The time comes first and always has four decimals, so that a file reads as a column of times
  /// followed by what happened.
  public func text(of entry: TraceEntry) throws -> String {
    let rest = String(decoding: try encoder.encode(entry.line), as: UTF8.self).dropFirst()
    let nested = entry.nested ? "\"nested\":true," : ""
    return "{\"t\":" + String(format: "%.4f", entry.t.isFinite ? entry.t : 0) + "," + nested + rest
  }
}

// MARK: Sinks

/// Where a recorder's lines go: a file in the app, memory in tests.
@MainActor
public protocol TraceSink: AnyObject {
  /// Where to find the trace, for messages.
  var location: String { get }
  /// Writes one line; the sink adds the newline.
  func write(_ line: String) throws
  func close()
}

/// Writes each line to the file as it comes, so that a trace survives Arbor crashing: those are the traces
/// most worth having.
@MainActor
public final class FileTraceSink: TraceSink {
  public let url: URL
  private var handle: FileHandle?

  public var location: String { url.path }

  public init(url: URL) throws {
    self.url = url
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
    else { throw CocoaError(.fileWriteUnknown) }
    handle = try FileHandle(forWritingTo: url)
  }

  public func write(_ line: String) throws {
    guard let handle else { throw CocoaError(.fileWriteUnknown) }
    try handle.write(contentsOf: Data((line + "\n").utf8))
  }

  public func close() {
    try? handle?.close()
    handle = nil
  }
}
