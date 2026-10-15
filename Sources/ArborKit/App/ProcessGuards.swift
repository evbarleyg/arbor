import AppKit
import ArborIPC

/// What protects the Arbor process, and people's windows from its accidents: settings of the process
/// itself, the lock that keeps a second copy out, the watchdog, and staying awake and in time.
@MainActor
final class ProcessGuards {
  private var locks: [InstanceLock] = []
  private var watchdog: Watchdog?
  private var activity: (any NSObjectProtocol)?
  private var powerOffObserver: (any NSObjectProtocol)?

  /// First thing in the process, before any file or socket is made.
  static func prepareProcess() {
    // Writing to a pipe or socket whose reader has gone raises SIGPIPE, and the default is to die
    // on the spot, with windows parked. The write fails with an error instead.
    signal(SIGPIPE, SIG_IGN)
    // Everything Arbor creates (state.json has window titles; the socket takes commands) is for its
    // owner only, from the moment it exists.
    umask(0o077)
  }

  /// Ends the process, with an explanation, if another Arbor already runs from this home folder, or, unless this one
  /// is confined to named processes, anywhere in this person's session (`SingleInstance`).
  func claimSingleInstance(prompt: Bool, isConfined: Bool) {
    try? ArborPaths.ensureHome()
    if !isConfined { try? ArborPaths.secure(folder: ArborPaths.usualHome) }
    let (home, usualHome) = (ArborPaths.home.path, ArborPaths.usualHome.path)
    for path in SingleInstance.lockFiles(home: home, usualHome: usualHome, isConfined: isConfined) {
      let lock = InstanceLock(path: path)
      // arbor.lock holds the pid and nothing else: scripts read it. Whoever finds it held shares the holder's home folder.
      let isHomeLock = path == ArborPaths.lockFile.path
      switch lock.acquire(attempts: 10, note: isHomeLock ? "" : home) {
      case .acquired:
        locks.append(lock)
      case .unavailable(let reason):
        Log.error("running without a lock that keeps a second Arbor out: \(reason)")
      case .held(let pid):
        let refusal = SingleInstance.refusal(
          pid: pid, holderHome: isHomeLock ? home : lock.holderNote, ownHome: home, usualHome: usualHome)
        Log.error(refusal.log)
        try? FileHandle.standardError.write(contentsOf: Data("\(refusal.title). \(refusal.text)\n".utf8))
        if prompt {
          let alert = NSAlert()
          alert.messageText = refusal.title
          alert.informativeText = refusal.text
          NSApp.activate()
          alert.runModal()
        }
        // Not `terminate`: nothing was started, and nothing of the other copy's may be cleaned up.
        exit(Self.alreadyRunningExitCode)
      }
    }
  }

  /// EX_TEMPFAIL of sysexits.h: try again later.
  static let alreadyRunningExitCode: Int32 = 75

  func start(environment: ArborEnvironment, sessionIsEnding: @escaping @MainActor @Sendable () -> Void) {
    if !environment.noWatchdog { watchdog = Watchdog() }

    // An accessory app with no window on screen is a candidate for App Nap, which delays timers by
    // seconds and lowers priority. Arbor's timers put windows back a quarter of a second after a
    // drag and drive animations, and a hotkey must act at once. This costs nothing while idle, and the
    // Mac may still go to sleep.
    activity = ProcessInfo.processInfo.beginActivity(
      options: .userInitiatedAllowingIdleSystemSleep, reason: "Arranging windows as they open, move and close")

    // At logout and shutdown every app is asked to quit at about the same time, and apps save their
    // windows' frames as they go. This arrives first, so windows are back in view before that. Arbor's own
    // request to quit follows, unless some app cancels the logout (`Controller.sessionIsEnding`).
    powerOffObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main
    ) { _ in
      MainActor.assumeIsolated { sessionIsEnding() }
    }
  }

  /// Last thing in `applicationWillTerminate`: until the windows are back, an accident still counts.
  func standDown() {
    watchdog?.standDown()
    watchdog = nil
    if let activity { ProcessInfo.processInfo.endActivity(activity) }
    activity = nil
    for lock in locks { lock.release() }
    locks.removeAll()
  }
}
