/// Lines in, bytes to write. Arbor never waits for a client: what the socket will not take now
/// is kept here until it will, and a client that has fallen more than `limit` bytes behind is given
/// up on. The queue decides; the server does the writing and the closing.
public struct OutboundQueue: Sendable {
  /// How many bytes may wait before the reader counts as having stopped reading.
  public let limit: Int
  private var storage: [UInt8] = []
  /// Where the bytes still to be written start in `storage`.
  private var head = 0

  public init(limit: Int) {
    self.limit = limit
  }

  /// Bytes waiting to be written.
  public var count: Int { storage.count - head }
  public var isEmpty: Bool { count == 0 }

  /// Queues `line` and its newline. Returns false, queueing nothing, if more than `limit` bytes would
  /// then be waiting. An empty queue takes a line of any length, so one long line (the state of
  /// a Mac with hundreds of windows) can always be sent to a client that keeps up.
  public mutating func enqueue(_ line: String) -> Bool {
    let bytes = line.utf8
    guard isEmpty || count + bytes.count + 1 <= limit else { return false }
    storage.reserveCapacity(storage.count + bytes.count + 1)
    // One line in is one line out, whatever it holds.
    for byte in bytes { storage.append(byte == UInt8(ascii: "\n") ? UInt8(ascii: " ") : byte) }
    storage.append(UInt8(ascii: "\n"))
    return true
  }

  /// Calls `body` with everything that is waiting, oldest first.
  public func withPendingBytes<Result>(_ body: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
    try storage.withUnsafeBytes { try body(UnsafeRawBufferPointer(rebasing: $0[head...])) }
  }

  /// Forgets the first `written` waiting bytes: the socket took them.
  public mutating func consume(_ written: Int) {
    head += min(max(written, 0), count)
    if head == storage.count {
      // Do not hold on to the memory of one long line.
      storage.removeAll(keepingCapacity: storage.count <= 16 * 1024)
      head = 0
    } else if head >= 64 * 1024 {
      storage.removeFirst(head)
      head = 0
    }
  }
}
