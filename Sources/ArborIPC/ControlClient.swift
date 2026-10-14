import Foundation

/// The client's side of the control protocol. The client connects and writes a single line of
/// command text (see `Command.parse`). For every command but one the server replies with one line
/// of JSON (`CommandResult`) and closes the connection: `send`. For `watch` it keeps the connection open
/// and writes one line of JSON per event (`ArborEvent`) until either side goes away: `watch`.
public enum ControlClient {
  public struct Failure: Error, CustomStringConvertible {
    public let description: String
    /// Arbor is there but did not answer in time, as opposed to not being there.
    public let timedOut: Bool
    public init(description: String, timedOut: Bool = false) {
      self.description = description
      self.timedOut = timedOut
    }
  }

  /// Sends `line` to the Arbor control socket and returns the raw reply.
  public static func send(_ line: String, socketPath: String = ArborPaths.socketPath, timeout: TimeInterval = 5)
    throws -> String
  {
    let fd = try UnixSocket.connected(to: socketPath)
    defer { close(fd) }
    UnixSocket.setTimeout(fd, seconds: timeout)
    var writeFailure: Failure?
    do {
      try UnixSocket.writeAll(fd, Data((line.trimmingCharacters(in: .newlines) + "\n").utf8))
      UnixSocket.finishWriting(fd)
    } catch let failure as Failure {
      // Nobody is taking the request, so nobody has answered it either.
      if failure.timedOut { throw noAnswer(within: timeout) }
      // Arbor hung up in the middle of the request. It says why first (too long, too many connections).
      writeFailure = failure
    }
    let (reply, end) = UnixSocket.readAll(fd)
    // A whole line is Arbor's answer however the connection ended: a server that hangs up on a request it has not
    // read to the end leaves the client an error after the line.
    if reply.last == UInt8(ascii: "\n") {
      return String(decoding: reply, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let writeFailure { throw writeFailure }
    switch end {
    case .wouldBlock:
      // Also with part of a reply in hand: half a line of JSON is not an answer.
      throw noAnswer(within: timeout)
    case .failed(let code):
      throw Failure(description: "read failed: \(errnoText(code))")
    case .ended, .moved:
      break
    }
    guard !reply.isEmpty else { throw Failure(description: "Arbor closed the connection without replying") }
    return String(decoding: reply, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func noAnswer(within timeout: TimeInterval) -> Failure {
    Failure(
      description: "Arbor did not answer within \(seconds(timeout)); it may be waiting for an app that is busy",
      timedOut: true)
  }

  /// "5 s", "0.5 s".
  private static func seconds(_ value: TimeInterval) -> String {
    (value == value.rounded() && abs(value) < 1e6 ? String(Int(value)) : String(value)) + " s"
  }

  // MARK: Streams

  /// Why a stream ended.
  public enum StreamEnd: Sendable {
    /// The server closed the connection, or went away.
    case closedByServer
    /// `onLine` returned false.
    case stoppedByCaller
    /// Whoever was reading `output` went away.
    case outputAbandoned
  }

  /// Sends `line` and hands every line that comes back to `onLine`, as it arrives, for as long as
  /// the server keeps the connection open and `onLine` returns true. The first line has `timeout` seconds, like
  /// any reply (Arbor answers a request for events at once, with `hello` or a refusal); after it this waits
  /// as long as it takes. A last line cut short by the end of the connection is dropped: half an event is of
  /// no use to anyone.
  ///
  /// - Parameter output: the descriptor the lines are passed on to, if there is one. When its reader
  ///   goes away (`arborctl watch | head -n 1`) the stream ends at once, not at the next event.
  @discardableResult
  public static func stream(
    _ line: String, socketPath: String = ArborPaths.socketPath, timeout: TimeInterval = 5, output: Int32? = nil,
    onLine: (String) -> Bool
  ) throws -> StreamEnd {
    let fd = try UnixSocket.connected(to: socketPath)
    defer { close(fd) }
    UnixSocket.setTimeout(fd, seconds: timeout)
    // The writing side stays open: the server takes its closing to mean that the client has left.
    do {
      try UnixSocket.writeAll(fd, Data((line.trimmingCharacters(in: .newlines) + "\n").utf8))
    } catch let failure as Failure where failure.timedOut {
      throw noAnswer(within: timeout)
    }

    var lines = LineBuffer(limit: 8 << 20)
    var buffer = [UInt8](repeating: 0, count: 64 * 1024)
    let output = output.flatMap { UnixSocket.canBeAbandoned($0) ? $0 : nil }
    // Nil once the first line is in.
    var deadline: Date? = Date().addingTimeInterval(timeout)
    while true {
      if let output {
        switch UnixSocket.waitUntilReadable(fd, unlessAbandoned: output, within: deadline?.timeIntervalSinceNow) {
        case .readable: break
        case .abandoned: return .outputAbandoned
        case .timedOut: throw noAnswer(within: timeout)
        }
      }
      switch UnixSocket.receive(fd, into: &buffer) {
      case .moved(let count):
        for line in lines.append(buffer[..<count]) {
          if deadline != nil {
            deadline = nil
            // The next event may be hours away. Zero means no timeout.
            UnixSocket.setTimeout(fd, seconds: 0)
          }
          guard onLine(line) else { return .stoppedByCaller }
        }
        if lines.overflowed { throw Failure(description: "Arbor sent a line longer than \(lines.limit) bytes") }
        // A line that comes in drops is not an answer in time either.
        if let deadline, deadline.timeIntervalSinceNow <= 0 { throw noAnswer(within: timeout) }
      case .ended:
        return .closedByServer
      case .wouldBlock:
        if deadline != nil { throw noAnswer(within: timeout) }
        continue
      case .failed(let code):
        throw Failure(description: "read failed: \(errnoText(code))")
      }
    }
  }

  // MARK: watch

  /// How a `watch` ended.
  public enum WatchEnd: Sendable {
    /// Arbor said `quitting`: it quit in good order.
    case stopped
    /// Whoever was reading the events left. Nothing went wrong.
    case abandoned
    /// Arbor refused the request: an unknown event name, or too many watchers.
    case refused
    /// No event ever arrived: Arbor is not running.
    case unreachable
    /// The events stopped without `quitting`: Arbor crashed or was killed, or it gave up on this
    /// client because it had stopped reading.
    case lost
    /// Arbor is there but did not answer the request in time.
    case timedOut

    /// `arborctl watch`'s exit code.
    public var exitCode: Int32 {
      switch self {
      case .stopped, .abandoned: 0
      case .refused: 1
      case .unreachable: 2
      case .lost: 3
      case .timedOut: 4
      }
    }
  }

  /// What `arborctl watch` does: sends `request` (`watch view focus`), hands each event line to
  /// `print` as it arrives and anything that went wrong to `complain`, and returns when the events end.
  /// `output` is the descriptor `print` writes to, if someone may stop reading it.
  public static func watch(
    _ request: String, socketPath: String = ArborPaths.socketPath, timeout: TimeInterval = 5, output: Int32? = nil,
    print: (String) -> Void, complain: (String) -> Void
  ) -> WatchEnd {
    var end = WatchEnd.unreachable
    do {
      let streamEnd = try stream(request, socketPath: socketPath, timeout: timeout, output: output) { line in
        switch classify(line) {
        case .refusal(let message):
          complain(message)
          end = .refused
          return false
        case .event("quitting"):
          print(line)
          end = .stopped
          return false
        case .event, .other:
          print(line)
          end = .lost
          return true
        }
      }
      if streamEnd == .outputAbandoned { return .abandoned }
    } catch {
      complain("\(error)")
      return (error as? Failure)?.timedOut == true ? .timedOut : end
    }
    switch end {
    case .unreachable: complain("Arbor closed the connection without replying")
    case .lost: complain("Arbor went away without saying that it was quitting")
    case .stopped, .refused, .abandoned, .timedOut: break
    }
    return end
  }

  enum WatchLine: Equatable {
    /// An event, by name.
    case event(String)
    /// A failed `CommandResult` in place of events, with its message.
    case refusal(String)
    case other
  }

  static func classify(_ line: String) -> WatchLine {
    guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
      return .other
    }
    if let event = object["event"] as? String { return .event(event) }
    if object["ok"] as? Bool == false { return .refusal(object["message"] as? String ?? "Arbor refused") }
    return .other
  }
}
