import ArborIPC
import Foundation

/// Serves the control socket. A client sends one line of command text. Most commands get one line of
/// JSON back and the connection closes; `watch` keeps it open and streams lines until either side
/// goes away.
///
/// Everything runs on the main queue and nothing here ever waits for a client: sockets are
/// non-blocking, what a client will not take yet waits in an `OutboundQueue`, and a client that sends
/// no request, does not collect its reply, or stops reading its events is hung up on. Arbor's main
/// thread also moves people's windows and sees their clicks, so a stuck script must not be able to hold it up.
@MainActor
public final class ControlServer {
  /// What to do with a request.
  public enum Response {
    /// Send this line and close the connection.
    case reply(String)
    /// Keep the connection open. The closure is called once, with the function that sends a line to
    /// this client, and returns what to run when the connection ends, whoever ends it.
    case stream((_ send: @escaping (String) -> Void) -> () -> Void)
  }

  /// Connections beyond this many at once are turned away. Far more than real use needs (a watcher
  /// per status bar item, a moment for each `arborctl`), and it bounds the descriptors a runaway script can take.
  public static let maximumConnections = 64
  /// How long a client may take to send its request.
  public static let requestTimeout = 2.0
  /// How long it may then take to collect the reply.
  public static let replyTimeout = 5.0
  /// The longest request, in bytes.
  public static let requestLimit = 64 * 1024
  /// How far behind a watcher may fall before it is dropped.
  public static let streamBacklogLimit = 256 * 1024

  public let path: String
  private let handler: (String) -> Response
  private let scheduler: any Scheduler
  private let accept: (Int32) -> UnixSocket.Acceptance
  private var source: DispatchSourceRead?
  private var connections: [Int: ControlConnection] = [:]
  private var nextConnectionNumber = 1
  /// Connections turned away since the log last said so.
  private var turnedAway = 0
  /// The socket's file as this server made it.
  private var boundFile: UnixSocket.FileIdentity?
  /// The source is suspended: there was no descriptor left for whoever is waiting.
  private var isResting = false
  /// How long to leave the listener alone then.
  public static let restWithoutDescriptors = 1.0

  /// - Parameter accept: takes the next connection from the listener. The tests' way to a process without descriptors, which
  ///   cannot be had for real beside other tests.
  public init(
    path: String = ArborPaths.socketPath, scheduler: any Scheduler = MainQueueScheduler(),
    accept: @escaping (Int32) -> UnixSocket.Acceptance = UnixSocket.acceptance(from:),
    handler: @escaping (String) -> Response
  ) {
    self.path = path
    self.scheduler = scheduler
    self.accept = accept
    self.handler = handler
  }

  /// Open connections, of either kind.
  public var connectionCount: Int { connections.count }

  public func start() throws {
    guard source == nil else { return }
    // Writing to a client that has left must be an error to handle, not the end of the process. The
    // sockets are told so one by one (`UnixSocket`), but Darwin refuses the option on a socket whose other
    // end is already gone, which is exactly the socket that matters.
    signal(SIGPIPE, SIG_IGN)
    try FileManager.default.createDirectory(
      at: URL(fileURLWithPath: path).deletingLastPathComponent(), withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    let listener = try UnixSocket.listening(at: path)
    boundFile = UnixSocket.identity(ofFileAt: path)
    let source = DispatchSource.makeReadSource(fileDescriptor: listener, queue: .main)
    source.setEventHandler { [weak self] in
      MainActor.assumeIsolated { self?.acceptPending(from: listener) }
    }
    // A descriptor may be closed only once its source has let go of it.
    source.setCancelHandler { UnixSocket.release(listener) }
    source.resume()
    self.source = source
    Log.info("control socket at \(path)")
  }

  /// Hangs up on every client and stops listening. Lines already sent still reach their clients.
  public func stop() {
    for number in connections.keys.sorted() { connections[number]?.hangUp() }
    connections.removeAll()
    scheduler.cancel("control-turned-away")
    turnedAway = 0
    scheduler.cancel("control-accept-again")
    guard let source else { return }
    // A source must be running when it is cancelled.
    if isResting { source.resume() }
    isResting = false
    source.cancel()
    self.source = nil
    // Only its own: somebody may have taken the path since (two homes with one ARBOR_SOCKET), and is listening there.
    if boundFile != nil, UnixSocket.identity(ofFileAt: path) == boundFile { unlink(path) }
    boundFile = nil
  }

  private func acceptPending(from listener: Int32) {
    guard source != nil else { return }
    // A few at a time, so that a script that connects in a loop cannot keep the main thread here; the source
    // fires again while more are waiting.
    for _ in 0..<16 {
      let fd: Int32
      switch accept(listener) {
      case .connection(let accepted): fd = accepted
      case .nobodyWaiting: return
      case .noDescriptorLeft: return rest()
      }
      guard connections.count < Self.maximumConnections else {
        // Not without a word: to a script, silence is "Arbor is not running", and its answer is to start another.
        // One attempt, whatever comes of it: this is no time to wait for anybody.
        let line = ControlEndpoint.line(for: .failure("too many connections (\(Self.maximumConnections)); try again")) + "\n"
        _ = Array(line.utf8).withUnsafeBytes { UnixSocket.transmit(fd, $0) }
        UnixSocket.release(fd)
        noteTurnedAway()
        continue
      }
      let number = nextConnectionNumber
      nextConnectionNumber += 1
      let connection = ControlConnection(
        fd: fd, number: number, scheduler: scheduler, handler: handler,
        onEnd: { [weak self] in self?.connections[number] = nil })
      connections[number] = connection
      connection.start()
    }
  }
}

extension ControlServer {
  /// Whoever is waiting goes on waiting, so the source would fire again at once, for as long as it takes something
  /// else in Arbor to give a descriptor back, and the main thread would do nothing else. Looks again in a while instead.
  private func rest() {
    guard let source, !isResting else { return }
    isResting = true
    source.suspend()
    Log.error("control socket: no file descriptor left for a new connection; looking again in \(Self.restWithoutDescriptors) s")
    scheduler.schedule("control-accept-again", after: Self.restWithoutDescriptors) { [weak self] in
      guard let self, self.isResting, let source = self.source else { return }
      self.isResting = false
      source.resume()
    }
  }

  /// Says so in the log at most once a second: such a loop must not push everything else out of it either.
  private func noteTurnedAway() {
    turnedAway += 1
    guard turnedAway == 1 else { return }
    scheduler.schedule("control-turned-away", after: 1) { [weak self] in
      guard let self else { return }
      Log.error("control socket: \(Self.maximumConnections) connections were open; turned \(self.turnedAway) away")
      self.turnedAway = 0
    }
  }
}

/// One client of the control socket, from `accept` to `close`.
@MainActor
final class ControlConnection {
  private enum Phase {
    /// Waiting for the request line.
    case request
    /// Sending the one reply; the connection closes when it has gone.
    case reply
    /// Sending lines until someone hangs up.
    case stream
    case ended
  }

  private let fd: Int32
  private let scheduler: any Scheduler
  private let timerKey: String
  private let handler: (String) -> ControlServer.Response
  private var onEnd: (() -> Void)?
  /// What the handler asked to have run when a stream ends.
  private var onStreamEnd: (() -> Void)?
  private var phase = Phase.request
  private var inbound = LineBuffer(limit: ControlServer.requestLimit)
  /// Bytes received after the request.
  private var unwantedBytes = 0
  private var outbound = OutboundQueue(limit: ControlServer.streamBacklogLimit)

  private let readSource: DispatchSourceRead
  /// Runs only while the socket has refused bytes that are still waiting; otherwise it would fire all the time.
  private let writeSource: DispatchSourceWrite
  private var writeSourceIsRunning = false
  private var readSourceIsCancelled = false
  /// Sources that have not let go of `fd` yet.
  private var sourcesHoldingDescriptor = 2

  init(
    fd: Int32, number: Int, scheduler: any Scheduler, handler: @escaping (String) -> ControlServer.Response,
    onEnd: @escaping () -> Void
  ) {
    self.fd = fd
    self.scheduler = scheduler
    timerKey = "control-connection-\(number)"
    self.handler = handler
    self.onEnd = onEnd
    readSource = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
    writeSource = DispatchSource.makeWriteSource(fileDescriptor: fd, queue: .main)
  }

  func start() {
    readSource.setEventHandler { [weak self] in
      MainActor.assumeIsolated { self?.readAvailable() }
    }
    writeSource.setEventHandler { [weak self] in
      MainActor.assumeIsolated { self?.writePending() }
    }
    // These hold on to the connection, so it lives until the descriptor is closed.
    readSource.setCancelHandler { MainActor.assumeIsolated { self.sourceLetGo() } }
    writeSource.setCancelHandler { MainActor.assumeIsolated { self.sourceLetGo() } }
    readSource.resume()
    hangUp(after: ControlServer.requestTimeout)
  }

  // MARK: Reading

  private func readAvailable() {
    var buffer = [UInt8](repeating: 0, count: 4096)
    // A few rounds at a time, so a client that keeps writing cannot keep the main thread here;
    // the source fires again while there is more.
    for _ in 0..<16 where phase != .ended {
      switch UnixSocket.receive(fd, into: &buffer) {
      case .moved(let count):
        // One request per connection. Whatever follows it is read, to notice the end, and dropped;
        // a client that goes on and on is only keeping the main thread busy.
        guard phase == .request else {
          unwantedBytes += count
          if unwantedBytes > ControlServer.requestLimit { hangUp() }
          continue
        }
        let lines = inbound.append(buffer[..<count])
        if let request = lines.first {
          respond(to: request)
        } else if inbound.overflowed {
          // With a word, for the same reason as a connection too many.
          answer(ControlEndpoint.line(for: .failure("the request is longer than \(ControlServer.requestLimit) bytes")))
        }
      case .ended:
        inputEnded()
        return
      case .wouldBlock:
        return
      case .failed:
        hangUp()
      }
    }
  }

  private func inputEnded() {
    if phase == .request, let request = inbound.finish() {
      // `printf status | nc -U arbor.sock` ends its request by closing, without a newline.
      respond(to: request)
    }
    switch phase {
    case .reply:
      // `arborctl` closes its writing side after the request and is now reading the reply.
      stopReading()
    case .request, .stream:
      // Nothing was asked, or a watcher has left.
      hangUp()
    case .ended:
      break
    }
  }

  private func respond(to request: String) {
    let response = handler(request)
    // The command may have stopped the server, and this connection with it.
    guard phase == .request else { return }
    switch response {
    case .reply(let line):
      answer(line)
    case .stream(let open):
      phase = .stream
      scheduler.cancel(timerKey)
      let end = open { [weak self] line in self?.send(line) }
      // The first lines are sent from inside `open`, and sending can end the connection.
      if phase == .ended { end() } else { onStreamEnd = end }
    }
  }

  /// Sends the one reply; the connection closes when it has gone.
  private func answer(_ line: String) {
    phase = .reply
    _ = outbound.enqueue(line)
    writePending()
    if phase == .reply { hangUp(after: ControlServer.replyTimeout) }
  }

  /// Gives the client this long for what it is doing now, in place of any time limit set before.
  private func hangUp(after seconds: Double) {
    scheduler.schedule(timerKey, after: seconds) { [weak self] in
      guard let self, self.phase != .ended else { return }
      Log.debug("control socket: hung up on a client that took longer than \(seconds) s")
      self.hangUp()
    }
  }

  // MARK: Writing

  private func send(_ line: String) {
    guard phase == .stream else { return }
    guard outbound.enqueue(line) else {
      Log.info("control socket: dropped a watcher that stopped reading, \(outbound.count) bytes behind")
      hangUp()
      return
    }
    writePending()
  }

  private func writePending() {
    guard phase != .ended else { return }
    while !outbound.isEmpty {
      switch outbound.withPendingBytes({ UnixSocket.transmit(fd, $0) }) {
      case .moved(let count):
        outbound.consume(count)
      case .wouldBlock:
        setWriteSourceRunning(true)
        return
      case .ended, .failed:
        hangUp()
        return
      }
    }
    setWriteSourceRunning(false)
    if phase == .reply { hangUp() }
  }

  private func setWriteSourceRunning(_ running: Bool) {
    guard running != writeSourceIsRunning else { return }
    writeSourceIsRunning = running
    if running { writeSource.resume() } else { writeSource.suspend() }
  }

  // MARK: Ending

  /// Ends the connection now. What the socket has already taken still reaches the client; what
  /// is waiting in the queue does not.
  func hangUp() {
    guard phase != .ended else { return }
    phase = .ended
    scheduler.cancel(timerKey)
    UnixSocket.hangUp(fd)
    stopReading()
    // A source must be running when it is cancelled and released.
    setWriteSourceRunning(true)
    writeSource.cancel()
    let callbacks = [onStreamEnd, onEnd]
    onStreamEnd = nil
    onEnd = nil
    for callback in callbacks { callback?() }
  }

  private func stopReading() {
    guard !readSourceIsCancelled else { return }
    readSourceIsCancelled = true
    readSource.cancel()
  }

  private func sourceLetGo() {
    sourcesHoldingDescriptor -= 1
    if sourcesHoldingDescriptor == 0 { UnixSocket.release(fd) }
  }
}
