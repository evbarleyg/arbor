import Foundation

/// Makes sure only one Arbor arranges windows from a given home folder.
///
/// Two copies at once (the installed app and `make run`, say) would each move the other's windows
/// back, overwrite each other's state, and the second would take over the control socket, leaving the
/// first unreachable. The lock is an advisory `flock` on a file in the home folder, held for the life
/// of the process. The kernel releases it however the process ends, so a crash or `kill -9` leaves
/// nothing stale behind; the file itself stays and is never deleted, because deleting it would let two
/// processes lock two different files of the same name.
public final class InstanceLock {
  public enum Outcome: Equatable, Sendable {
    case acquired
    /// Another process holds it. The pid is what that process wrote into the file, if it is readable.
    case held(by: Int32?)
    /// The lock could not be tried: a read-only folder, or a volume that does not support locks.
    /// Nothing says another Arbor is running, so the caller carries on without protection.
    case unavailable(reason: String)
  }

  public let path: String
  /// After `.held`: what the holder left in the file beside its pid (see `acquire(attempts:note:)`).
  public private(set) var holderNote: String?
  private var descriptor: Int32 = -1

  public init(path: String) {
    self.path = path
  }

  deinit {
    release()
  }

  /// Tries to take the lock, up to `attempts` times a tenth of a second apart: the process this one
  /// replaces (see `RestartPolicy`) may still be on its way out. `note` is a line for whoever finds the lock held.
  public func acquire(attempts: Int = 1, note: String = "") -> Outcome {
    guard descriptor < 0 else { return .acquired }
    // Close-on-exec: a child that inherited the descriptor would hold the lock after Arbor is gone.
    let fd = open(path, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, 0o600)
    guard fd >= 0 else { return .unavailable(reason: "cannot open \(path): \(String(cString: strerror(errno)))") }
    for attempt in 1...max(attempts, 1) {
      if flock(fd, LOCK_EX | LOCK_NB) == 0 {
        descriptor = fd
        let line = String(note.map { $0.isNewline ? " " : $0 }.prefix(900))
        let text = Array("\(getpid())\n\(line.isEmpty ? "" : line + "\n")".utf8)
        _ = ftruncate(fd, 0)
        _ = pwrite(fd, text, text.count, 0)
        return .acquired
      }
      let code = errno
      guard code == EWOULDBLOCK || code == EINTR else {
        close(fd)
        return .unavailable(reason: "cannot lock \(path): \(String(cString: strerror(code)))")
      }
      if attempt < attempts { usleep(100_000) }
    }
    var buffer = [UInt8](repeating: 0, count: 4096)
    let count = pread(fd, &buffer, buffer.count, 0)
    close(fd)
    let lines = String(decoding: buffer.prefix(max(count, 0)), as: UTF8.self).split(whereSeparator: \.isNewline)
    holderNote = lines.count > 1 ? String(lines[1]) : nil
    return .held(by: lines.first.flatMap { Int32($0.trimmingCharacters(in: .whitespaces)) })
  }

  public func release() {
    guard descriptor >= 0 else { return }
    close(descriptor)
    descriptor = -1
  }
}

/// Which locks an Arbor takes, and what it says when one is held.
public enum SingleInstance {
  /// One per home folder, so that no two share state, log and socket. And one per person, whatever `ARBOR_HOME` says: two
  /// Arbors with different home folders would still hold the same shortcuts and event taps and move the same windows.
  /// An Arbor confined to named processes (`ARBOR_ONLY_PIDS`: tests, the Mac shell) arranges nobody else's windows and
  /// may run beside the person's own.
  public static func lockFiles(home: String, usualHome: String, isConfined: Bool) -> [String] {
    [home + "/arbor.lock"] + (isConfined ? [] : [usualHome + "/arbor.user.lock"])
  }

  public struct Refusal: Equatable, Sendable {
    public var title: String
    public var text: String
    public var log: String
  }

  /// - Parameters:
  ///   - holderHome: the home folder of the Arbor that holds the lock, if it left word.
  ///   - usualHome: where Arbor keeps its files when nobody says otherwise.
  public static func refusal(pid: Int32?, holderHome: String?, ownHome: String, usualHome: String) -> Refusal {
    let who = pid.map { " (pid \($0))" } ?? ""
    // Where from, if that is known: not this one's own folder for want of a better.
    let whence = holderHome.map { " from \($0)" } ?? ""
    let log = "another Arbor\(who) already runs\(whence); this one (pid \(getpid())) is leaving"
    var text: String
    if let holderHome, holderHome != usualHome, holderHome != ownHome {
      // Started by a test or a script. It may have no icon, and `arborctl quit` would ask somebody else.
      text = "Another copy is arranging the windows of your Mac. A test or a script started it, with the home folder \(holderHome), "
        + "and it may have no icon in the menu bar."
      if let pid { text += " To end it: kill \(pid) (its windows come back into view)." }
    } else {
      // Whoever opens Arbor twice was most likely looking for the window it does not have.
      text = "It has no window of its own: it is the icon in the menu bar. To start it afresh, choose Quit Arbor "
        + "there (or run arborctl quit) and open it again."
      if ownHome != (holderHome ?? ownHome) {
        text += " A copy with a home folder of its own can run beside it only if ARBOR_ONLY_PIDS names the processes it may arrange."
      }
    }
    return Refusal(title: "Arbor is already running", text: text, log: log)
  }
}
