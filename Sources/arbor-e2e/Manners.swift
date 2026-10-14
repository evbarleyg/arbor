import Darwin
import Dispatch
import Foundation

// What arbor-e2e owes the Mac it runs on.
//
// It was written for GitHub's Macs and for a person who types `make e2e` and watches. It is also run by loops on a person's
// own Mac, for one commit after another, with nobody watching and the person's windows open. There it has to
//   - leave nothing behind when its caller runs out of patience: killed, it left an Arbor without a menu bar item or
//     shortcuts, that Arbor's watchdog, and a folder;
//   - end by itself: a test window that never answers was waited for for ever, with test windows across the screen;
//   - stay away while somebody is at the Mac: the test windows come to the front and take the keyboard, so what the
//     person is typing goes to them.

/// Seconds since anybody touched the keyboard or the pointer. Nil when macOS does not say.
func secondsSinceInput() -> Double? {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
  process.arguments = ["-c", "IOHIDSystem"]
  let output = Pipe()
  process.standardInput = FileHandle.nullDevice
  process.standardOutput = output
  process.standardError = FileHandle.nullDevice
  guard (try? process.run()) != nil else { return nil }
  let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
  process.waitUntilExit()
  // `    | |   "HIDIdleTime" = 1234567890`, in nanoseconds.
  guard let line = text.split(separator: "\n").first(where: { $0.contains("\"HIDIdleTime\"") }),
    let number = line.split(separator: " ").last, let nanoseconds = Double(number)
  else { return nil }
  return nanoseconds / 1_000_000_000
}

/// Unchecked: everything but `init` runs on `queue`. The runner is used from there only to clean up, after which the process ends.
final class Manners: @unchecked Sendable {
  /// A run takes three or four minutes.
  static let limit: TimeInterval = 900
  /// How long the Mac must have been left alone before a run starts.
  static let quiet: TimeInterval = 60

  private let runner: Runner
  private let queue = DispatchQueue(label: "arbor-e2e.manners")
  private var sources: [any DispatchSourceProtocol] = []

  /// Whether to look out for a person. Not on GitHub's Macs, where nobody sits; not when a person started the run from a
  /// terminal, who knows what is coming; not when told otherwise.
  let looksOutForSomebody: Bool = {
    let environment = ProcessInfo.processInfo.environment
    return environment["GITHUB_ACTIONS"] != "true" && environment["ARBOR_BUSY_OK"] != "1" && isatty(STDIN_FILENO) == 0
  }()

  init(_ runner: Runner) {
    self.runner = runner
  }

  /// Asked before the first window opens.
  func mayStart() -> Bool {
    guard looksOutForSomebody, let idle = secondsSinceInput(), idle < Self.quiet else { return true }
    announce(
      .somebodyIsHere, "somebody used this Mac's keyboard or pointer \(Int(idle)) s ago, so nothing was started",
      facts: [
        "The test windows would come up in front of their work and take the keyboard.",
        "After \(Int(Self.quiet)) quiet seconds it runs; ARBOR_BUSY_OK=1 runs it all the same.",
      ])
    return false
  }

  func watch() {
    // Handlers that do nothing, not SIG_IGN: what is ignored stays ignored in Arbor and the test windows, which are stopped with
    // SIGTERM. The sources below see the signals all the same. A write to a test window that has died fails instead of killing.
    for number in [SIGINT, SIGTERM, SIGHUP, SIGPIPE] { signal(number) { _ in } }
    for number in [SIGINT, SIGTERM, SIGHUP] {
      let source = DispatchSource.makeSignalSource(signal: number, queue: queue)
      source.setEventHandler { [self] in leave("stopped by signal \(number)", code: 128 + number) }
      source.resume()
      sources.append(source)
    }
    queue.asyncAfter(deadline: .now() + Self.limit) { [self] in
      leave("still running after \(Int(Self.limit)) s", code: Ending.outOfTime.rawValue)
    }
    guard looksOutForSomebody else { return }
    // Arbor moves windows through Accessibility and the runner posts no input, so whatever input there is is a person's.
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + 2, repeating: 2)
    timer.setEventHandler { [self] in
      if let idle = secondsSinceInput(), idle < 2 { leave("somebody is using this Mac", code: Ending.somebodyIsHere.rawValue) }
    }
    timer.resume()
    sources.append(timer)
  }

  /// Any exit code but 0 and 1 keeps scripts/e2e.sh from taking half a run for evidence.
  private func leave(_ why: String, code: Int32) {
    announce(code: code, "\(why). Quitting Arbor and closing the test windows", facts: [MacState.now.inWords])
    runner.cleanUp()
    exit(code)
  }
}
