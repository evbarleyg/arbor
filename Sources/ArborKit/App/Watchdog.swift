import ArborIPC
import Foundation

/// Starts Arbor again if it ends without quitting.
///
/// Arbor hides windows by parking them in a screen corner. If it crashes, traps or is killed, nothing
/// in the process can put them back: a signal handler cannot safely talk to the Accessibility API, and
/// `kill -9` runs no handler at all. So Arbor starts a second, tiny process from its own executable
/// (`Arbor --watchdog`), which does nothing but wait at the far end of a pipe:
///
/// - Arbor writes `q` when it has quit in good order, windows back in view: the watchdog exits.
/// - The pipe closes with no `q`: the kernel closed it because Arbor is gone. The watchdog asks
///   `RestartPolicy` what to do, starts Arbor again (or a rescue), and exits. The new Arbor finds the
///   same windows under the same numbers and restores the arrangement from state.json.
///
/// `ARBOR_NO_WATCHDOG=1` turns it off, for debuggers and scripts that kill Arbor on purpose.
@MainActor
final class Watchdog {
  nonisolated static let argument = "--watchdog"

  /// The end of the pipe Arbor holds.
  private let line: FileHandle

  /// Starts the watchdog process. Nil, with a line in the log, if that fails; Arbor runs without.
  init?() {
    guard let executable = Bundle.main.executableURL else { return nil }
    let pipe = Pipe()
    let process = Process()
    process.executableURL = executable
    process.arguments = [Self.argument, String(getpid())]
    process.standardInput = pipe.fileHandleForReading
    do {
      try process.run()
    } catch {
      Log.error("could not start the watchdog: \(error)")
      return nil
    }
    // Only the child may hold this end.
    try? pipe.fileHandleForReading.close()
    line = pipe.fileHandleForWriting
    Log.info("watchdog started, pid \(process.processIdentifier)")
  }

  /// Arbor has quit in good order.
  func standDown() {
    try? line.write(contentsOf: Data("q".utf8))
    try? line.close()
  }

  // MARK: The watchdog process

  /// The whole life of `Arbor --watchdog <pid>`.
  nonisolated static func run(arguments: [String]) -> Never {
    signal(SIGPIPE, SIG_IGN)
    var byte: UInt8 = 0
    while true {
      let count = read(STDIN_FILENO, &byte, 1)
      if count < 0, errno == EINTR { continue }
      if count == 1, byte == UInt8(ascii: "q") { exit(0) }
      // Not the end of the pipe but a fault of this process's own; it says nothing about Arbor.
      if count < 0 { exit(1) }
      if count == 0 { break }
    }

    let parent = arguments.last ?? "?"
    var environment = ProcessInfo.processInfo.environment
    let now = Date().timeIntervalSince1970
    let history = RestartPolicy.recent(RestartPolicy.history(from: environment["ARBOR_RESTARTS"]), now: now)
    switch RestartPolicy.decide(history: history, now: now) {
    case .restart:
      Log.error("Arbor (pid \(parent)) ended without quitting; starting it again")
    case .rescue:
      Log.error("Arbor (pid \(parent)) ended without quitting, the third time in a row; bringing the windows back")
      environment["ARBOR_RESCUE"] = "1"
    case .giveUp:
      Log.error("Arbor (pid \(parent)) ended without quitting yet again; giving up. Starting Arbor recovers its windows")
      exit(1)
    }
    environment["ARBOR_RESTARTS"] = RestartPolicy.text(for: history + [now])
    // Let the kernel finish with the old process: its lock, its socket, its hotkeys.
    usleep(300_000)

    let process = Process()
    let bundle = Bundle.main.bundleURL
    if bundle.pathExtension == "app" {
      // Through Launch Services, as the user would, so that macOS sees the app itself asking for
      // Accessibility and not a child of a process that no longer exists. `open` hands on only
      // the variables it is told to.
      process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
      let variables = environment.filter { $0.key.hasPrefix("ARBOR_") }.sorted { $0.key < $1.key }
      process.arguments = ["-n"] + variables.flatMap { ["--env", "\($0.key)=\($0.value)"] } + [bundle.path]
    } else {
      process.executableURL = Bundle.main.executableURL
      process.environment = environment
    }
    process.standardInput = FileHandle.nullDevice
    do {
      try process.run()
    } catch {
      Log.error("could not start Arbor again: \(error)")
      exit(1)
    }
    exit(0)
  }
}
