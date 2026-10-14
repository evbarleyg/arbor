import Foundation

/// Small POSIX helpers shared by the client and the server. This is the one file that tells
/// Darwin's sockets from Linux's, where the tests run the same client and server.
///
/// No socket made here ever raises SIGPIPE. Writing to a client that has gone away would otherwise
/// kill Arbor, with people's windows still parked out of view.
public enum UnixSocket {
  /// What came of one attempt to read or write.
  public enum Transfer: Equatable, Sendable {
    /// This many bytes moved; more than zero.
    case moved(Int)
    /// Nothing can move now. On a blocking socket: the timeout ran out.
    case wouldBlock
    /// The other side has closed its end (reads only).
    case ended
    /// The connection is broken; the value is `errno`.
    case failed(Int32)
  }

  // MARK: Opening

  /// A socket connected to the server at `path`, blocking.
  public static func connected(to path: String) throws -> Int32 {
    var address = try address(for: path)
    let fd = try newStream()
    let result = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    guard result == 0 else {
      close(fd)
      throw ControlClient.Failure(
        description: "Arbor is not running (no control socket at \(path)); start it with `open -a Arbor`")
    }
    return fd
  }

  /// A non-blocking socket listening at `path`, for its owner only, in place of whatever was left there. Throws if
  /// somebody is listening there now: taking the path away would leave that server running and out of reach.
  ///
  /// The backlog is how many clients may be waiting to be accepted, which is as long as a command takes. With it
  /// full, Darwin refuses the next one as if nobody were listening, and `arborctl` would say that Arbor is not running.
  public static func listening(at path: String, backlog: Int32 = 128) throws -> Int32 {
    var address = try address(for: path)
    if let other = try? connected(to: path) {
      close(other)
      throw ControlClient.Failure(description: "somebody is already listening at \(path)")
    }
    unlink(path)
    let fd = try newStream()
    let bound = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    guard bound == 0 else {
      let reason = errnoText()
      close(fd)
      throw ControlClient.Failure(description: "could not bind \(path): \(reason)")
    }
    chmod(path, 0o600)
    guard listen(fd, backlog) == 0 else {
      let reason = errnoText()
      close(fd)
      throw ControlClient.Failure(description: "could not listen at \(path): \(reason)")
    }
    setNonBlocking(fd, true)
    return fd
  }

  /// Which file is at a path: another one there later, under the same name, is told from it by this.
  public struct FileIdentity: Equatable, Sendable {
    var device: UInt64
    var number: UInt64
  }

  /// Nil if nothing is at `path`.
  public static func identity(ofFileAt path: String) -> FileIdentity? {
    var status = stat()
    guard lstat(path, &status) == 0 else { return nil }
    return FileIdentity(device: UInt64(truncatingIfNeeded: status.st_dev), number: UInt64(truncatingIfNeeded: status.st_ino))
  }

  /// What came of asking a listener for its next connection.
  public enum Acceptance: Equatable, Sendable {
    /// A connection, non-blocking.
    case connection(Int32)
    case nobodyWaiting
    /// Somebody is waiting, and the process (or the system) has no descriptor left to give them. They go on waiting,
    /// so a source on the listener fires again at once, and again.
    case noDescriptorLeft
  }

  public static func acceptance(from listener: Int32) -> Acceptance {
    while true {
      let fd = accept(listener, nil, nil)
      if fd < 0 {
        let code = errno
        if code == EINTR { continue }
        return code == EMFILE || code == ENFILE ? .noDescriptorLeft : .nobodyWaiting
      }
      // Darwin hands the listener's flags down to the connection and Linux does not; ask either way.
      setNonBlocking(fd, true)
      keepToThisProcess(fd)
      neverRaiseSIGPIPE(fd)
      return .connection(fd)
    }
  }

  /// The next connection waiting at `listener`, non-blocking, or nil if there is none to be had.
  public static func accepted(from listener: Int32) -> Int32? {
    if case .connection(let fd) = acceptance(from: listener) { fd } else { nil }
  }

  private static func newStream() throws -> Int32 {
    #if canImport(Darwin)
      let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    #else
      let fd = socket(AF_UNIX, Int32(SOCK_STREAM.rawValue), 0)
    #endif
    guard fd >= 0 else { throw ControlClient.Failure(description: "socket() failed: \(errnoText())") }
    keepToThisProcess(fd)
    neverRaiseSIGPIPE(fd)
    return fd
  }

  public static func address(for path: String) throws -> sockaddr_un {
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(path.utf8)
    let capacity = MemoryLayout.size(ofValue: address.sun_path)
    guard bytes.count < capacity else {
      throw ControlClient.Failure(
        description: "socket path is \(bytes.count) bytes; the system allows \(capacity - 1): \(path)")
    }
    withUnsafeMutableBytes(of: &address.sun_path) { raw in
      raw.copyBytes(from: bytes)
      raw[bytes.count] = 0
    }
    #if canImport(Darwin)
      address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    #endif
    return address
  }

  // MARK: Options

  public static func setNonBlocking(_ fd: Int32, _ nonBlocking: Bool) {
    let flags = fcntl(fd, F_GETFL)
    guard flags >= 0 else { return }
    _ = fcntl(fd, F_SETFL, nonBlocking ? flags | O_NONBLOCK : flags & ~O_NONBLOCK)
  }

  /// A program this process starts must not inherit the socket: it would hold the connection open after
  /// this process has closed it, and the other side would wait for an end that never comes.
  private static func keepToThisProcess(_ fd: Int32) {
    _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
  }

  /// How long a blocking read or write may wait.
  public static func setTimeout(_ fd: Int32, seconds: TimeInterval) {
    var tv = timeval()
    tv.tv_sec = Int(seconds)
    tv.tv_usec = suseconds_t((seconds - Double(Int(seconds))) * 1_000_000)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
  }

  /// Darwin has a socket option for this; Linux has a flag on each `send` (see `transmit`).
  private static func neverRaiseSIGPIPE(_ fd: Int32) {
    #if canImport(Darwin)
      var on: Int32 = 1
      setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    #endif
  }

  // MARK: Reading and writing

  /// Reads once into `buffer`.
  public static func receive(_ fd: Int32, into buffer: inout [UInt8]) -> Transfer {
    while true {
      let count = read(fd, &buffer, buffer.count)
      if count > 0 { return .moved(count) }
      if count == 0 { return .ended }
      let code = errno
      if code == EINTR { continue }
      return code == EAGAIN || code == EWOULDBLOCK ? .wouldBlock : .failed(code)
    }
  }

  public enum Wait: Sendable {
    case readable, abandoned, timedOut
  }

  /// Waits until `fd` has something to read (or has ended, which a read then reports): `.readable`. Or until
  /// whoever was reading `output` has gone, which a process that is only waiting would otherwise not
  /// notice until it next had something to write: `.abandoned`. For `seconds`, or as long as it takes.
  ///
  /// Only for an `output` that `canBeAbandoned`.
  public static func waitUntilReadable(
    _ fd: Int32, unlessAbandoned output: Int32, within seconds: TimeInterval? = nil
  ) -> Wait {
    // Linux reports errors and hang-ups whether asked for or not. macOS looks at a descriptor only if it is asked about
    // something to read or write; GNU's `tail` and `tee` ask for this, which a pipe's writing end never has.
    var descriptors = [
      pollfd(fd: fd, events: Int16(POLLIN), revents: 0), pollfd(fd: output, events: Int16(POLLRDBAND), revents: 0),
    ]
    let deadline = seconds.map { Date().addingTimeInterval($0) }
    while true {
      // Rounded up, so that the last fraction of a millisecond is not spent going round.
      let patience = deadline.map { Int32(max(0, min(($0.timeIntervalSinceNow * 1000).rounded(.up), 3_600_000))) } ?? -1
      let ready = poll(&descriptors, nfds_t(descriptors.count), patience)
      if ready < 0, errno != EINTR { return .readable }
      if ready > 0, descriptors[1].revents & Int16(POLLERR | POLLHUP | POLLNVAL) != 0 { return .abandoned }
      if ready > 0, descriptors[0].revents != 0 { return .readable }
      if let deadline, deadline.timeIntervalSinceNow <= 0 { return .timedOut }
    }
  }

  /// Whether `output` has a reader that can leave: a pipe or a socket. A file has none, and a terminal would wake
  /// `waitUntilReadable` with every key typed.
  public static func canBeAbandoned(_ output: Int32) -> Bool {
    var status = stat()
    guard fstat(output, &status) == 0 else { return false }
    let kind = status.st_mode & S_IFMT
    return kind == S_IFIFO || kind == S_IFSOCK
  }

  /// Writes as much of `bytes`, which must not be empty, as the socket takes in one go.
  public static func transmit(_ fd: Int32, _ bytes: UnsafeRawBufferPointer) -> Transfer {
    while true {
      #if canImport(Darwin)
        let count = write(fd, bytes.baseAddress, bytes.count)
      #else
        let count = send(fd, bytes.baseAddress, bytes.count, Int32(MSG_NOSIGNAL))
      #endif
      if count > 0 { return .moved(count) }
      let code = count == 0 ? EIO : errno
      if code == EINTR { continue }
      return code == EAGAIN || code == EWOULDBLOCK ? .wouldBlock : .failed(code)
    }
  }

  /// Writes all of `data` to a blocking socket.
  public static func writeAll(_ fd: Int32, _ data: Data) throws {
    try data.withUnsafeBytes { raw in
      var offset = 0
      while offset < raw.count {
        switch transmit(fd, UnsafeRawBufferPointer(rebasing: raw[offset...])) {
        case .moved(let count): offset += count
        case .wouldBlock: throw ControlClient.Failure(description: "write timed out", timedOut: true)
        case .ended: throw ControlClient.Failure(description: "write failed")
        case .failed(let code): throw ControlClient.Failure(description: "write failed: \(errnoText(code))")
        }
      }
    }
  }

  /// Reads from a blocking socket until the other side closes it, or `limit` bytes. Returns what arrived and
  /// how the reading ended: `.ended`, `.wouldBlock` (the timeout ran out), `.failed`, or `.moved` at the limit.
  public static func readAll(_ fd: Int32, limit: Int = 8 << 20) -> (data: Data, end: Transfer) {
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 64 * 1024)
    while true {
      let transfer = receive(fd, into: &buffer)
      guard case .moved(let count) = transfer else { return (data, transfer) }
      data.append(buffer, count: count)
      if data.count >= limit { return (data, transfer) }
    }
  }

  // MARK: Closing

  /// Tells the other side that nothing more will be written. Reading still works.
  public static func finishWriting(_ fd: Int32) {
    shutdown(fd, Int32(SHUT_WR))
  }

  /// Ends the conversation in both directions at once: the other side reads what was already
  /// written, then the end of the stream. The descriptor stays valid until `release`.
  public static func hangUp(_ fd: Int32) {
    shutdown(fd, Int32(SHUT_RDWR))
  }

  /// `close`, for callers that have a `close` of their own.
  public static func release(_ fd: Int32) {
    close(fd)
  }
}

func errnoText(_ code: Int32 = errno) -> String { String(cString: strerror(code)) }
