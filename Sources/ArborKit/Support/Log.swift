import ArborIPC
import Foundation

#if canImport(os)
  import os

  /// Only macOS has the unified log; elsewhere `arbor.log` is the only destination.
  private let unifiedLog = Logger(subsystem: "dev.arbor", category: "arbor")
#endif

/// Logs to the unified log (subsystem `dev.arbor`) and to `arbor.log` in
/// Arbor's home folder, which agents and the end-to-end runner read.
/// Window titles are never logged; use window ids and bundle ids.
public enum Log {
  private static let file = LogFile(url: ArborPaths.logFile)
  /// Read once: `environment` copies every variable each time it is asked.
  static let debugEnabled = !["", "0"].contains(ProcessInfo.processInfo.environment["ARBOR_DEBUG"] ?? "")

  public static func info(_ message: @autoclosure () -> String) {
    guard !file.isSilenced else { return }
    write(.info, message())
  }

  public static func error(_ message: @autoclosure () -> String) {
    guard !file.isSilenced else { return }
    write(.error, message())
  }

  public static func debug(_ message: @autoclosure () -> String) {
    guard debugEnabled, !file.isSilenced else { return }
    write(.debug, message())
  }

  /// Runs `body` without logging. The chaos test performs tens of thousands of commands, and stamping
  /// and writing a line for each takes longer than the commands do.
  public static func silenced<T>(_ body: () throws -> T) rethrows -> T {
    file.silence(1)
    defer { file.silence(-1) }
    return try body()
  }

  /// The raw value is the level's column in `arbor.log`.
  private enum Level: String {
    case info = "INFO "
    case error = "ERROR"
    case debug = "DEBUG"
  }

  private static func write(_ level: Level, _ message: String) {
    let text = sanitized(message)
    #if canImport(os)
      switch level {
      case .info: unifiedLog.info("\(text, privacy: .public)")
      case .error: unifiedLog.error("\(text, privacy: .public)")
      case .debug: unifiedLog.debug("\(text, privacy: .public)")
      }
    #endif
    file.append("\(level.rawValue) \(text)")
  }

  static let maximumLength = 1000

  /// One message is one line. Messages quote text from outside (URLs, command words, bundle ids,
  /// app names, settings), which could otherwise forge further lines, recolour or clear a terminal
  /// that shows the log, reverse the reading direction, or fill the disk.
  public static func sanitized(_ message: String) -> String {
    var result = String.UnicodeScalarView()
    var count = 0
    for scalar in message.unicodeScalars {
      guard count < maximumLength else {
        result.append(contentsOf: "… (\(message.unicodeScalars.count - count) more)".unicodeScalars)
        break
      }
      count += 1
      switch scalar.properties.generalCategory {
      case .control, .format, .lineSeparator, .paragraphSeparator, .surrogate, .privateUse, .unassigned:
        result.append(contentsOf: "\\u{\(String(scalar.value, radix: 16, uppercase: true))}".unicodeScalars)
      default:
        result.append(scalar)
      }
    }
    return String(result)
  }
}

/// A log file that cannot grow without bound and cannot bring the process down.
///
/// Arbor runs for weeks, so the size is checked as lines are written, not only at launch: at
/// `limit` bytes the file becomes `<name>.1` (replacing the previous one) and a new file is started, so
/// the two together stay under twice the limit and the recent past is always there to read.
///
/// It writes with `write(2)` and ignores failures. `FileHandle.write(_:)` raises an Objective-C
/// exception, which Swift cannot catch, when the disk is full; a window manager must not die, with
/// windows parked out of view, because a log line could not be written. The descriptor is opened for
/// appending, so a second process writing to the same file adds lines instead of overwriting them.
public final class LogFile: @unchecked Sendable {
  private let url: URL
  private let limit: Int
  private let lock = NSLock()
  private var descriptor: Int32 = -1
  private var size = 0
  /// When opening failed, so that a read-only or missing folder is not tried again for every line.
  private var retryAfter = Date.distantPast
  /// How many `Log.silenced` calls are in progress.
  private var silencers = 0
  private let formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  var isSilenced: Bool {
    lock.lock()
    defer { lock.unlock() }
    return silencers > 0
  }

  func silence(_ change: Int) {
    lock.lock()
    defer { lock.unlock() }
    silencers += change
  }

  public init(url: URL, limit: Int = 2 << 20) {
    self.url = url
    self.limit = limit
  }

  deinit {
    if descriptor >= 0 { close(descriptor) }
  }

  /// Where the previous file is kept.
  public var previousURL: URL { url.appendingPathExtension("1") }

  public func append(_ line: String) {
    lock.lock()
    defer { lock.unlock() }
    let now = Date()
    let bytes = Array("\(formatter.string(from: now)) \(line)\n".utf8)
    if descriptor >= 0, size + bytes.count > limit { rotate() }
    if descriptor < 0 {
      guard now >= retryAfter else { return }
      openFile()
      guard descriptor >= 0 else {
        retryAfter = now.addingTimeInterval(60)
        return
      }
      if size + bytes.count > limit {
        rotate()
        openFile()
        guard descriptor >= 0 else { return }
      }
    }
    // One call per line keeps lines from different processes whole. A short or failed write
    // (full disk, volume gone) loses the line and nothing else.
    let written = write(descriptor, bytes, bytes.count)
    if written > 0 { size += written }
  }

  private func openFile() {
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    // Not through a symbolic link somebody left at the path.
    descriptor = open(url.path, O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC | O_NOFOLLOW, 0o600)
    guard descriptor >= 0 else { return }
    size = Int(lseek(descriptor, 0, SEEK_END))
  }

  private func rotate() {
    if descriptor >= 0 { close(descriptor) }
    descriptor = -1
    size = 0
    // rename(2) replaces the old copy in one step. If it fails, start over rather than grow.
    if rename(url.path, previousURL.path) != 0 { unlink(url.path) }
  }
}
