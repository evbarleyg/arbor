import ArborCore
import ArborIPC
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A client the test drives by hand on the main actor. It never waits, so the test decides when,
/// and whether, anything is read.
@MainActor
private final class HandClient {
  private let fd: Int32
  private var buffer = LineBuffer(limit: 8 << 20)
  private(set) var lines: [String] = []
  /// The server has closed the connection, and everything it sent before has been read.
  private(set) var ended = false
  private var isOpen = true
  /// What the socket has not taken yet.
  private var unsent = Data()

  init(_ path: String) throws {
    fd = try UnixSocket.connected(to: path)
    UnixSocket.setNonBlocking(fd, true)
    // Darwin's sockets take 8 KB at a time and Linux's some 200. Small everywhere, so that both meet writes that do not fit.
    var size: Int32 = 8 * 1024
    setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &size, socklen_t(MemoryLayout<Int32>.size))
  }

  /// Writes what fits now; the rest follows with each `read`, as the server makes room.
  func write(_ text: String) {
    unsent.append(contentsOf: text.utf8)
    writeWhatFits()
  }

  private func writeWhatFits() {
    while !unsent.isEmpty {
      switch unsent.withUnsafeBytes({ UnixSocket.transmit(fd, $0) }) {
      case .moved(let count): unsent.removeFirst(count)
      case .wouldBlock: return
      case .ended, .failed: unsent.removeAll()
      }
    }
  }

  func finishWriting() { UnixSocket.finishWriting(fd) }

  /// Reads whatever has arrived.
  func read() {
    guard isOpen else { return }
    writeWhatFits()
    var bytes = [UInt8](repeating: 0, count: 64 * 1024)
    while true {
      switch UnixSocket.receive(fd, into: &bytes) {
      case .moved(let count): lines += buffer.append(bytes[..<count])
      case .wouldBlock: return
      case .ended, .failed:
        ended = true
        return
      }
    }
  }

  func close() {
    guard isOpen else { return }
    isOpen = false
    UnixSocket.release(fd)
  }
}

/// Waits, letting the main queue run (that is where the server lives), until `condition` holds. The patience is
/// counted in turns, not seconds: every `@MainActor` test shares the main thread, and a long one elsewhere must not
/// use up this one's time.
@MainActor
private func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
  for _ in 0..<5_000 {
    if condition() { return true }
    try? await Task.sleep(nanoseconds: 2_000_000)
  }
  return condition()
}

/// `arborctl <command>`: nil if it failed. With far more patience than `arborctl` has, because the server shares
/// the main thread with every other `@MainActor` test: more than the whole run takes on a slow machine. At 300 s two
/// tests here failed as soon as the run of 3,500 tests lasted longer than that (four cores, 2026-10-14).
private func arborctl(_ line: String, _ path: String) async -> String? {
  await onAnotherThread { try? ControlClient.send(line, socketPath: path, timeout: 1800) }
}

/// Runs the blocking client calls that `arborctl` makes on a thread of their own, as another process would.
private func onAnotherThread<Result: Sendable>(_ work: @escaping @Sendable () -> Result) async -> Result {
  await withCheckedContinuation { continuation in
    Thread.detachNewThread { continuation.resume(returning: work()) }
  }
}

private struct Watched: Sendable {
  var end: ControlClient.WatchEnd
  var lines: [String]
  var complaints: [String]
}

/// `arborctl watch …`, from connecting to its exit code. With the same patience as `arborctl` above, and for the same reason: the
/// time is for the first line only (`hello`, or a refusal), which the server sends from the main thread. With the product's
/// own 5 s the client gave up whenever another test held that thread for longer, and the watcher the test waited for never was.
/// After the first line there is no limit either way, and no test here expects this helper to run out of time.
private func arborctlWatch(_ request: String, _ path: String) async -> Watched {
  await onAnotherThread {
    var lines: [String] = []
    var complaints: [String] = []
    let end = ControlClient.watch(
      request, socketPath: path, timeout: 1800, print: { lines.append($0) }, complain: { complaints.append($0) })
    return Watched(end: end, lines: lines, complaints: complaints)
  }
}

@MainActor private var socketCount = 0

/// A fresh, short socket path (the system allows about a hundred bytes).
@MainActor
private func newSocketPath() -> String {
  socketCount += 1
  return NSTemporaryDirectory() + "arbor-test-\(getpid())-\(socketCount).sock"
}

/// The control socket itself: real sockets, the real server and the real client, in one process.
@Suite(.serialized) @MainActor struct ControlServerTests {
  /// A server that answers `echo …` with the same line, `big <n>` with n bytes, and streams on `stream`.
  @MainActor
  final class Fixture {
    let path = newSocketPath()
    let scheduler = ManualScheduler()
    var server: ControlServer!
    var requests: [String] = []
    var send: ((String) -> Void)?
    var streamsEnded = 0

    init() throws {
      server = ControlServer(path: path, scheduler: scheduler) { [unowned self] line in
        self.requests.append(line)
        if line == "stream" {
          return .stream { send in
            self.send = send
            send("first")
            return { self.streamsEnded += 1 }
          }
        }
        if line.hasPrefix("big "), let count = Int(line.dropFirst(4)) {
          return .reply(String(repeating: "x", count: count))
        }
        return .reply(line)
      }
      try server.start()
    }
  }

  @Test func oneRequestGetsOneReplyAndTheConnectionCloses() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let path = f.path
    let reply = await arborctl("echo hello", path)
    #expect(reply == "echo hello")
    #expect(f.requests == ["echo hello"])
    #expect(await eventually { f.server.connectionCount == 0 })
  }

  @Test func aRequestInPiecesOrWithoutItsNewlineIsStillARequest() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let slow = try HandClient(f.path)
    defer { slow.close() }
    slow.write("echo ")
    #expect(await eventually { f.server.connectionCount == 1 })
    #expect(f.requests.isEmpty)
    slow.write("in pieces\nand this is ignored\n")
    #expect(await eventually { slow.read(); return slow.ended })
    #expect(slow.lines == ["echo in pieces"])

    // printf 'echo bare' | nc -U arbor.sock
    let bare = try HandClient(f.path)
    defer { bare.close() }
    bare.write("echo bare")
    bare.finishWriting()
    #expect(await eventually { bare.read(); return bare.ended })
    #expect(bare.lines == ["echo bare"])
    #expect(f.requests == ["echo in pieces", "echo bare"])
  }

  @Test func aReplyFarLargerThanTheSocketsBufferArrivesWhole() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let path = f.path
    let reply = await arborctl("big 3000000", path)
    #expect(reply?.utf8.count == 3_000_000)
    #expect(await eventually { f.server.connectionCount == 0 })
  }

  @Test func manyClientsAtOnceAreAllAnswered() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let path = f.path
    let replies = await withTaskGroup(of: String?.self) { group in
      for number in 0..<24 {
        group.addTask { await arborctl("echo \(number)", path) }
      }
      var replies: [String?] = []
      for await reply in group { replies.append(reply) }
      return replies
    }
    #expect(Set(replies) == Set((0..<24).map { "echo \($0)" }))
  }

  @Test func aStreamStaysOpenAndCarriesLinesInOrder() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let client = try HandClient(f.path)
    defer { client.close() }
    client.write("stream\n")
    #expect(await eventually { client.read(); return client.lines == ["first"] })
    for number in 1...500 { f.send?("line \(number)") }
    #expect(await eventually { client.read(); return client.lines.count == 501 })
    #expect(client.lines.last == "line 500")
    #expect(client.lines.dropFirst().first == "line 1")
    #expect(!client.ended)
    // Long after a request would have timed out.
    f.scheduler.advance(by: 60)
    f.send?("still here")
    #expect(await eventually { client.read(); return client.lines.last == "still here" })
    #expect(f.streamsEnded == 0)
  }

  @Test func aWatcherThatLeavesIsNoticedWithoutAnythingBeingSent() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let client = try HandClient(f.path)
    client.write("stream\n")
    #expect(await eventually { f.send != nil })
    client.close()
    #expect(await eventually { f.streamsEnded == 1 })
    #expect(f.server.connectionCount == 0)
    f.send?("nobody is listening")  // must be harmless
    #expect(f.streamsEnded == 1)
  }

  @Test func aWatcherThatKeepsTalkingIsHungUpOn() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let client = try HandClient(f.path)
    defer { client.close() }
    client.write("stream\nand a little more, which does no harm\n")
    #expect(await eventually { client.read(); return client.lines == ["first"] })
    f.send?("second")
    #expect(await eventually { client.read(); return client.lines == ["first", "second"] })
    for _ in 0..<20 where f.streamsEnded == 0 {
      client.write(String(repeating: "blah ", count: 1_000))
      _ = await eventually { true }
      await Task.yield()
    }
    // Reading also writes what has not fitted into the socket yet.
    #expect(await eventually { client.read(); return f.streamsEnded == 1 })
    #expect(f.requests == ["stream"])
  }

  @Test func aCommandThatStopsTheServerDoesNoHarm() async throws {
    let path = newSocketPath()
    var server: ControlServer?
    server = ControlServer(path: path, scheduler: ManualScheduler()) { line in
      server?.stop()
      return line == "stream" ? .stream { _ in { Issue.record("the stream was never opened, so it cannot end") } } : .reply("too late")
    }
    for request in ["anything\n", "stream\n"] {
      try server?.start()
      let client = try HandClient(path)
      defer { client.close() }
      client.write(request)
      #expect(await eventually { client.read(); return client.ended })
      #expect(client.lines.isEmpty)
      #expect(server?.connectionCount == 0)
    }
  }

  @Test func aWatcherThatStopsReadingIsDroppedAndNeverWaitedFor() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let client = try HandClient(f.path)
    defer { client.close() }
    client.write("stream\n")
    #expect(await eventually { f.send != nil })

    let line = String(repeating: "y", count: 9_999)
    var sent = 0
    // Far more than the socket's own buffers and the queue hold together. Nothing here yields, so if
    // the server ever waited for the client, this loop would never end.
    while f.streamsEnded == 0, sent < 1_000 {
      f.send?(line)
      sent += 1
    }
    #expect(f.streamsEnded == 1, "dropped")
    #expect(sent < 1_000)
    #expect(sent * 10_000 > ControlServer.streamBacklogLimit, "but not before it was \(ControlServer.streamBacklogLimit) bytes behind")
    #expect(f.server.connectionCount == 0)

    // What the socket had already taken is still delivered, in order and unbroken, and then the end.
    #expect(await eventually { client.read(); return client.ended })
    #expect(client.lines.first == "first")
    #expect(client.lines.dropFirst().allSatisfy { $0 == line })
  }

  @Test func aSlowWatcherThatCatchesUpLosesNothing() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let client = try HandClient(f.path)
    defer { client.close() }
    client.write("stream\n")
    #expect(await eventually { f.send != nil })
    // Behind, but within the limit, several times over; each time the rest follows when it reads.
    for round in 0..<5 {
      for number in 0..<20 { f.send?("\(round)-\(number) " + String(repeating: "z", count: 9_000)) }
      let expected = 1 + (round + 1) * 20
      #expect(await eventually { client.read(); return client.lines.count == expected })
    }
    #expect(f.streamsEnded == 0)
    #expect(client.lines.last?.hasPrefix("4-19 ") == true)
  }

  @Test func aClientThatSaysNothingOrNeverCollectsItsReplyIsHungUpOn() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let silent = try HandClient(f.path)
    defer { silent.close() }
    let deaf = try HandClient(f.path)
    defer { deaf.close() }
    deaf.write("big 3000000\n")
    #expect(await eventually { f.server.connectionCount == 2 && f.requests.count == 1 })
    f.scheduler.advance(by: ControlServer.requestTimeout - 0.1)
    #expect(f.server.connectionCount == 2)
    f.scheduler.advance(by: 0.2)
    #expect(f.server.connectionCount == 1, "two seconds to say something")
    #expect(await eventually { silent.read(); return silent.ended })
    #expect(silent.lines.isEmpty)
    f.scheduler.advance(by: ControlServer.replyTimeout - ControlServer.requestTimeout - 0.2)
    #expect(f.server.connectionCount == 1)
    f.scheduler.advance(by: 0.2)
    #expect(f.server.connectionCount == 0, "five to take the answer")
  }

  @Test func aRequestThatNeverEndsIsHungUpOn() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let client = try HandClient(f.path)
    defer { client.close() }
    client.write(String(repeating: "a", count: ControlServer.requestLimit + 1))
    #expect(await eventually { client.read(); return client.ended })
    #expect(f.requests.isEmpty)
    #expect(f.server.connectionCount == 0)
    // Not without a word: silence reads as "Arbor is not running", which scripts answer by starting another.
    #expect(client.lines.count == 1)
    #expect(client.lines.first?.hasPrefix(#"{"message":"the request is longer than"#) == true, "\(client.lines)")
    #expect(client.lines.first?.contains(#""ok":false"#) == true)
  }

  @Test func arborctlHearsWhyARequestThatIsTooLongWasRefused() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let path = f.path
    // Long enough that the client is still writing when the server has had enough.
    for length in [ControlServer.requestLimit + 1, 3_000_000] {
      let reply = await arborctl(String(repeating: "a", count: length), path)
      #expect(reply?.contains("the request is longer than") == true, "\(length): \(reply ?? "nothing")")
    }
    #expect(f.requests.isEmpty)
    #expect(await eventually { f.server.connectionCount == 0 })
  }

  @Test func connectionsBeyondTheLimitAreTurnedAway() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    var clients: [HandClient] = []
    defer { clients.forEach { $0.close() } }
    for count in 1...ControlServer.maximumConnections {
      clients.append(try HandClient(f.path))
      #expect(await eventually { f.server.connectionCount == count })
    }
    let extra = try HandClient(f.path)
    defer { extra.close() }
    #expect(await eventually { extra.read(); return extra.ended })
    #expect(f.server.connectionCount == ControlServer.maximumConnections)
    #expect(extra.lines.first?.contains("too many connections") == true, "\(extra.lines)")
    // The real client has sent its request by the time it is turned away, and still hears why.
    let path = f.path
    let reply = await arborctl("echo one too many", path)
    #expect(reply?.contains("too many connections") == true, "\(reply ?? "nothing")")
    #expect(reply?.contains(#""ok":false"#) == true)
    // The others are still served.
    clients[0].write("echo still here\n")
    #expect(await eventually { clients[0].read(); return clients[0].lines == ["echo still here"] })
  }

  /// They are accepted a few at a time, so that nobody can keep the main thread accepting.
  @Test func manyClientsThatConnectAtOnceAreAllServed() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let clients = try (0..<50).map { _ in try HandClient(f.path) }
    defer { clients.forEach { $0.close() } }
    for (number, client) in clients.enumerated() { client.write("echo \(number)\n") }
    #expect(
      await eventually {
        clients.forEach { $0.read() }
        return clients.allSatisfy(\.ended)
      })
    #expect(clients.map(\.lines) == (0..<50).map { ["echo \($0)"] })
  }

  @Test func connectionsGiveTheirDescriptorsBack() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    func openDescriptors() -> Int { (try? FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count) ?? 0 }
    let before = openDescriptors()
    #expect(before > 0)
    for round in 0..<300 {
      let client = try HandClient(f.path)
      // In turn: served and closed by the server, a watcher that leaves, and a client that leaves without a word.
      client.write(["echo hello\n", "stream\n", ""][round % 3])
      if round % 3 == 0 { #expect(await eventually { client.read(); return client.ended }) }
      if round % 3 == 1 { #expect(await eventually { client.read(); return client.lines == ["first"] }) }
      client.close()
      #expect(await eventually { f.server.connectionCount == 0 })
    }
    // Other suites open sockets of their own meanwhile; three hundred leaked ones would stand out.
    #expect(await eventually { openDescriptors() < before + 50 })
  }

  @Test func stoppingHangsUpOnEveryoneAndRemovesTheSocket() async throws {
    let f = try Fixture()
    let watcher = try HandClient(f.path)
    defer { watcher.close() }
    let idle = try HandClient(f.path)
    defer { idle.close() }
    watcher.write("stream\n")
    #expect(await eventually { f.send != nil && f.server.connectionCount == 2 })
    f.send?("last words")
    f.server.stop()
    #expect(f.streamsEnded == 1)
    #expect(f.server.connectionCount == 0)
    #expect(!FileManager.default.fileExists(atPath: f.path))
    #expect(await eventually { watcher.read(); idle.read(); return watcher.ended && idle.ended })
    #expect(watcher.lines == ["first", "last words"], "what was sent before stopping still arrives")
    #expect(throws: (any Error).self) { _ = try HandClient(f.path) }
    f.server.stop()  // twice is harmless

    try f.server.start()
    defer { f.server.stop() }
    let path = f.path
    #expect(await arborctl("echo again", path) == "echo again")
  }

  // MARK: Without descriptors

  /// Whoever cannot be accepted goes on waiting, so a source left running would fire with every turn of the main loop.
  @Test func withoutADescriptorLeftTheServerRestsInsteadOfSpinning() async throws {
    let path = newSocketPath()
    let scheduler = ManualScheduler()
    var attempts = 0
    var starved = true
    let server = ControlServer(
      path: path, scheduler: scheduler,
      accept: { listener in
        attempts += 1
        return starved ? .noDescriptorLeft : UnixSocket.acceptance(from: listener)
      }
    ) { .reply($0) }
    try server.start()
    defer { server.stop() }
    let client = try HandClient(path)
    defer { client.close() }
    client.write("hello\n")
    #expect(await eventually { attempts == 1 })
    for _ in 0..<100 { try await Task.sleep(nanoseconds: 1_000_000) }
    #expect(attempts == 1, "it was left alone")

    scheduler.advance(by: ControlServer.restWithoutDescriptors)
    #expect(await eventually { attempts == 2 })
    for _ in 0..<100 { try await Task.sleep(nanoseconds: 1_000_000) }
    #expect(attempts == 2, "still none: another rest")

    starved = false
    scheduler.advance(by: ControlServer.restWithoutDescriptors)
    #expect(await eventually { client.read(); return client.lines == ["hello"] }, "the client was served in the end")
  }

  @Test func stoppingWhileItRestsDoesNoHarm() async throws {
    let path = newSocketPath()
    let scheduler = ManualScheduler()
    var attempts = 0
    let server = ControlServer(
      path: path, scheduler: scheduler,
      accept: { _ in
        attempts += 1
        return .noDescriptorLeft
      }
    ) { .reply($0) }
    try server.start()
    let client = try HandClient(path)
    defer { client.close() }
    #expect(await eventually { attempts == 1 })
    server.stop()
    scheduler.advance(by: 10)
    #expect(attempts == 1)
    #expect(!FileManager.default.fileExists(atPath: path))
    // And it can start again.
    try server.start()
    server.stop()
  }

  // MARK: Whose socket it is

  @Test func aSecondServerDoesNotTakeALiveSocket() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let path = f.path
    let second = ControlServer(path: path, scheduler: ManualScheduler()) { _ in .reply("the wrong one") }
    #expect(throws: ControlClient.Failure.self) { try second.start() }
    // Nor does giving up remove what it never made.
    second.stop()
    #expect(await arborctl("echo still mine", path) == "echo still mine")
  }

  @Test func aSocketLeftBehindIsReplaced() async throws {
    let path = newSocketPath()
    // As after `kill -9`: the file stays, and nobody is behind it.
    UnixSocket.release(try UnixSocket.listening(at: path))
    #expect(FileManager.default.fileExists(atPath: path))
    let server = ControlServer(path: path, scheduler: ManualScheduler()) { .reply($0) }
    try server.start()
    defer { server.stop() }
    #expect(await arborctl("hello", path) == "hello")
  }

  @Test func stoppingLeavesASocketThatSomebodyElseHasMadeSince() async throws {
    let f = try Fixture()
    let path = f.path
    unlink(path)
    let newcomer = ControlServer(path: path, scheduler: ManualScheduler()) { _ in .reply("the newcomer") }
    try newcomer.start()
    defer { newcomer.stop() }
    f.server.stop()
    #expect(await arborctl("who is there", path) == "the newcomer")
    newcomer.stop()
    #expect(!FileManager.default.fileExists(atPath: path), "its own it does remove")
  }

  @Test func aServerThatDoesNotAnswerIsReportedAsThat() async throws {
    // Somebody listens and never accepts: as when Arbor's main thread waits for an app that is busy.
    let path = newSocketPath()
    let listener = try UnixSocket.listening(at: path)
    defer {
      UnixSocket.release(listener)
      unlink(path)
    }
    let message = await onAnotherThread { () -> String in
      do { return try ControlClient.send("status", socketPath: path, timeout: 0.2) } catch { return "\(error)" }
    }
    #expect(message.hasPrefix("Arbor did not answer within 0.2 s"))
  }

  @Test func aServerThatDoesNotTakeTheRequestIsThereAllTheSame() async throws {
    let path = newSocketPath()
    let listener = try UnixSocket.listening(at: path)
    defer {
      UnixSocket.release(listener)
      unlink(path)
    }
    // More than any socket holds for a reader that never comes.
    let timedOut = await onAnotherThread { () -> Bool? in
      do {
        _ = try ControlClient.send(String(repeating: "a", count: 4_000_000), socketPath: path, timeout: 0.2)
        return nil
      } catch { return (error as? ControlClient.Failure)?.timedOut }
    }
    #expect(timedOut == true)
  }

  @Test func watchDoesNotWaitForEverForAnArborThatIsBusy() async throws {
    let path = newSocketPath()
    let listener = try UnixSocket.listening(at: path)
    defer {
      UnixSocket.release(listener)
      unlink(path)
    }
    var ends: [Int32] = [0, 0]
    #expect(pipe(&ends) == 0)
    defer { ends.forEach { UnixSocket.release($0) } }
    // Into a file or a terminal, and into a pipe, which waits in another place.
    for output in [nil, ends[1]] as [Int32?] {
      let watched = await onAnotherThread { () -> Watched in
        var complaints: [String] = []
        let end = ControlClient.watch(
          "watch", socketPath: path, timeout: 0.2, output: output, print: { _ in }, complain: { complaints.append($0) })
        return Watched(end: end, lines: [], complaints: complaints)
      }
      #expect(watched.end == .timedOut)
      #expect(watched.end.exitCode == 4)
      #expect(watched.complaints.first?.hasPrefix("Arbor did not answer within 0.2 s") == true, "\(watched.complaints)")
    }
  }

  @Test func afterTheFirstLineAWatchWaitsAsLongAsItTakes() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let path = f.path
    async let watched = onAnotherThread { () -> [String] in
      var lines: [String] = []
      _ = try? ControlClient.stream("stream", socketPath: path, timeout: 0.1) { line in
        lines.append(line)
        return lines.count < 2
      }
      return lines
    }
    #expect(await eventually { f.send != nil })
    try await Task.sleep(nanoseconds: 400_000_000)
    f.send?("much later")
    #expect(await watched == ["first", "much later"])
  }

  @Test func socketsAreNotHandedToProgramsThisProcessStarts() throws {
    let path = newSocketPath()
    let listener = try UnixSocket.listening(at: path)
    let client = try UnixSocket.connected(to: path)
    let accepted = try #require(UnixSocket.accepted(from: listener))
    defer {
      for fd in [listener, client, accepted] { UnixSocket.release(fd) }
      unlink(path)
    }
    for fd in [listener, client, accepted] {
      #expect(fcntl(fd, F_GETFD) & FD_CLOEXEC != 0)
    }
  }

  @Test func onlyAPipeOrASocketHasAReaderThatCanLeave() throws {
    var ends: [Int32] = [0, 0]
    #expect(pipe(&ends) == 0)
    let file = open("/dev/null", O_WRONLY)
    let path = newSocketPath()
    let listener = try UnixSocket.listening(at: path)
    defer {
      for fd in ends + [file, listener] { UnixSocket.release(fd) }
      unlink(path)
    }
    #expect(UnixSocket.canBeAbandoned(ends[1]))
    #expect(UnixSocket.canBeAbandoned(listener))
    #expect(!UnixSocket.canBeAbandoned(file))
    #expect(!UnixSocket.canBeAbandoned(-1))
  }

  /// `arborctl watch | head -n 1`, without the processes.
  @Test func waitingForEventsEndsWhenTheReaderOfTheOutputLeaves() async throws {
    var ends: [Int32] = [0, 0]
    #expect(pipe(&ends) == 0)
    let path = newSocketPath()
    let listener = try UnixSocket.listening(at: path)
    let quiet = try UnixSocket.connected(to: path)
    let server = try #require(UnixSocket.accepted(from: listener))
    let (reader, writer) = (ends[0], ends[1])
    defer {
      for fd in [writer, listener, quiet, server] { UnixSocket.release(fd) }
      unlink(path)
    }
    async let hasSomethingToRead = onAnotherThread { UnixSocket.waitUntilReadable(quiet, unlessAbandoned: writer) }
    try await Task.sleep(nanoseconds: 50_000_000)
    UnixSocket.release(reader)
    // Should the hang-up go unnoticed, an event ends the wait after a while, with the other answer.
    let rescue = Task {
      try await Task.sleep(nanoseconds: 5_000_000_000)
      try UnixSocket.writeAll(server, Data("late\n".utf8))
    }
    #expect(await hasSomethingToRead == .abandoned)
    rescue.cancel()
  }

  @Test func theSocketIsForItsOwnerOnly() throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let permissions = try FileManager.default.attributesOfItem(atPath: f.path)[.posixPermissions] as? Int
    #expect(permissions == 0o600)
  }
}

/// `arborctl` against Arbor without its windows: the real client, socket, server, endpoint, feed and controller.
@Suite(.serialized) @MainActor struct ArborctlWatchTests {
  @MainActor
  final class Fixture {
    let h = Harness()
    let path = newSocketPath()
    let feed: EventFeed
    let server: ControlServer
    let a: WindowID
    let b: WindowID

    init() throws {
      a = h.system.open(app: "Safari", title: "Private browsing")
      b = h.system.open(app: "Notes")
      h.start()
      let controller = h.controller
      feed = EventFeed(controller: controller)
      let endpoint = ControlEndpoint(feed: feed) { controller.perform($0) }
      server = ControlServer(path: path, scheduler: h.scheduler) { endpoint.respond(to: $0) }
      try server.start()
    }

    /// Runs a command and lets the main loop come round.
    func run(_ command: String) {
      h.run(command)
      h.scheduler.advance(by: 0)
    }

    /// What `applicationWillTerminate` does.
    func quit() {
      h.controller.shutdown()
      feed.stop()
      server.stop()
    }
  }

  @Test func commandsStillGetTheirOneReply() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let path = f.path
    let a = f.a
    let docked = await arborctl("dock \(a.rawValue) left", path)
    #expect(try JSONDecoder().decode(CommandResult.self, from: Data((docked ?? "").utf8)).ok)
    #expect(f.h.workspace.isDocked(a))
    let state = await arborctl("state", path)
    #expect(try JSONDecoder().decode(CommandResult.self, from: Data((state ?? "").utf8)).state == f.h.controller.snapshot())
    let nonsense = await arborctl("frobnicate", path)
    let refusal = try JSONDecoder().decode(CommandResult.self, from: Data((nonsense ?? "").utf8))
    #expect(!refusal.ok && refusal.message.contains("frobnicate"))
  }

  @Test func watchPrintsEventsAsTheyHappenAndExitsWithZeroWhenArborQuits() async throws {
    let f = try Fixture()
    async let watching = arborctlWatch("watch window layout view", f.path)
    #expect(await eventually { f.feed.subscriberCount == 1 })
    f.run("dock \(f.a.rawValue) left")
    f.run("zoom \(f.a.rawValue)")
    f.quit()
    let watched = await watching
    #expect(watched.end == .stopped)
    #expect(watched.end.exitCode == 0)
    #expect(watched.complaints.isEmpty)
    let events = try watched.lines.map { try ArborEvent(line: $0) }
    // Docked; then framed, which takes the other window out of view.
    #expect(events.map(\.kind) == [.hello, .window, .layout, .view, .window, .layout, .view, .quitting])
    guard events.count > 6, case .view(let view) = events[6] else { return }
    #expect((view.kind, view.windows, view.label, view.outOfView) == (.window, [f.a], "Safari", 1))
    #expect(!watched.lines.contains { $0.contains("Private browsing") })
    #expect(f.feed.subscriberCount == 0)
  }

  @Test func aPauseDoesNotEndTheWatch() async throws {
    let f = try Fixture()
    async let watching = arborctlWatch("watch view", f.path)
    #expect(await eventually { f.feed.subscriberCount == 1 })
    f.run("dock \(f.a.rawValue) left")
    f.run("pause")
    f.run("resume")
    f.run("zoom \(f.a.rawValue)")
    f.quit()
    let watched = await watching
    #expect(watched.end == .stopped)
    #expect(try watched.lines.map { try ArborEvent(line: $0).kind } == [.hello, .view, .paused, .resumed, .view, .view, .quitting])
  }

  @Test func watchPassesItsFilterAndTitlesOn() async throws {
    let f = try Fixture()
    async let watching = arborctlWatch("watch focus --titles", f.path)
    #expect(await eventually { f.feed.subscriberCount == 1 })
    f.run("dock \(f.a.rawValue) left")
    f.h.system.userFocus(f.a)
    f.h.scheduler.advance(by: 0)
    f.quit()
    let watched = await watching
    let events = try watched.lines.map { try ArborEvent(line: $0) }
    #expect(events.map(\.kind) == [.hello, .focus, .quitting])
    guard events.count > 1, case .focus(let focus) = events[1] else { return }
    #expect(focus.title == "Private browsing")
  }

  @Test func aLostConnectionExitsWithThree() async throws {
    let f = try Fixture()
    async let watching = arborctlWatch("watch view", f.path)
    #expect(await eventually { f.feed.subscriberCount == 1 })
    // Arbor crashes or is killed: the sockets close and nobody says goodbye.
    f.server.stop()
    let watched = await watching
    #expect(watched.end == .lost)
    #expect(watched.end.exitCode == 3)
    #expect(watched.lines.count == 1, "hello")
    #expect(watched.complaints.count == 1)
    #expect(f.feed.subscriberCount == 0)
  }

  @Test func anUnknownEventExitsWithOneAndSaysWhy() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let watched = await arborctlWatch("watch views", f.path)
    #expect(watched.end == .refused)
    #expect(watched.end.exitCode == 1)
    #expect(watched.lines.isEmpty)
    #expect(watched.complaints.first?.contains("unknown event `views`") == true)
  }

  @Test func withoutArborWatchExitsWithTwo() async throws {
    let watched = await arborctlWatch("watch", newSocketPath())
    #expect(watched.end == .unreachable)
    #expect(watched.end.exitCode == 2)
    #expect(watched.complaints.first?.contains("not running") == true)
  }

  @Test func theSeventeenthWatcherIsRefusedAndAPlaceGivenUpCanBeTaken() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    var clients: [HandClient] = []
    defer { clients.forEach { $0.close() } }
    for count in 1...EventFeed.maximumSubscribers {
      let client = try HandClient(f.path)
      client.write("watch view\n")
      clients.append(client)
      #expect(await eventually { f.feed.subscriberCount == count })
    }
    let refused = await arborctlWatch("watch", f.path)
    #expect(refused.end == .refused)
    #expect(refused.complaints.first?.contains("16") == true)

    // Ordinary commands are not affected.
    let path = f.path
    #expect(await arborctl("status", path) != nil)

    clients[0].close()
    #expect(await eventually { f.feed.subscriberCount == EventFeed.maximumSubscribers - 1 })
    let late = try HandClient(f.path)
    defer { late.close() }
    late.write("watch\n")
    #expect(await eventually { late.read(); return late.lines.count == 1 })

    f.run("dock \(f.a.rawValue) left")
    #expect(await eventually { clients[1].read(); return clients[1].lines.count == 2 })
    #expect(await eventually { clients[15].read(); return clients[15].lines.count == 2 })
  }

  @Test func aWatcherThatStopsReadingLosesItsPlaceAndArborCarriesOn() async throws {
    let f = try Fixture()
    defer { f.server.stop() }
    let stuck = try HandClient(f.path)
    defer { stuck.close() }
    stuck.write("watch\n")
    let healthy = try HandClient(f.path)
    defer { healthy.close() }
    healthy.write("watch view\n")
    #expect(await eventually { f.feed.subscriberCount == 2 })
    f.run("dock \(f.a.rawValue) left")
    f.run("dock \(f.b.rawValue) right")

    var moves = 0
    while f.feed.subscriberCount == 2, moves < 20_000 {
      f.run(moves % 2 == 0 ? "zoom \(f.a.rawValue)" : "back")
      moves += 1
      // The healthy one keeps reading; the main queue gets a turn now and then to write to it.
      if moves % 50 == 0 {
        healthy.read()
        await Task.yield()
      }
    }
    #expect(f.feed.subscriberCount == 1, "the stuck watcher was dropped after \(moves) moves")
    #expect(await eventually { healthy.read(); return healthy.lines.count == 3 + moves })
    #expect(!healthy.ended)
  }
}
