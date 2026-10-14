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
  private var descriptor: Int32 = -1

  public init(path: String) {
    self.path = path
  }

  deinit {
    release()
  }

  /// Tries to take the lock, up to `attempts` times a tenth of a second apart: the process this one
  /// replaces (see `RestartPolicy`) may still be on its way out.
  public func acquire(attempts: Int = 1) -> Outcome {
    guard descriptor < 0 else { return .acquired }
    // Close-on-exec: a child that inherited the descriptor would hold the lock after Arbor is gone.
    let fd = open(path, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, 0o600)
    guard fd >= 0 else { return .unavailable(reason: "cannot open \(path): \(String(cString: strerror(errno)))") }
    for attempt in 1...max(attempts, 1) {
      if flock(fd, LOCK_EX | LOCK_NB) == 0 {
        descriptor = fd
        let text = Array("\(getpid())\n".utf8)
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
    var buffer = [UInt8](repeating: 0, count: 32)
    let count = pread(fd, &buffer, buffer.count, 0)
    close(fd)
    let text = String(decoding: buffer.prefix(max(count, 0)), as: UTF8.self)
    return .held(by: Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)))
  }

  public func release() {
    guard descriptor >= 0 else { return }
    close(descriptor)
    descriptor = -1
  }
}
