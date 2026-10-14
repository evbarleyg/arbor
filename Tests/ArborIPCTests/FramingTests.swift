import Testing

@testable import ArborIPC

/// `#expect` cannot call mutating methods, so the tests hold the two value types in boxes.
private final class Buffer {
  var value: LineBuffer
  init(limit: Int) { value = LineBuffer(limit: limit) }
  var overflowed: Bool { value.overflowed }
  func append<Bytes: Sequence>(_ bytes: Bytes) -> [String] where Bytes.Element == UInt8 { value.append(bytes) }
  func append(_ text: String) -> [String] { value.append(Array(text.utf8)) }
  func finish() -> String? { value.finish() }
}

private final class Queue {
  var value: OutboundQueue
  init(limit: Int) { value = OutboundQueue(limit: limit) }
  var count: Int { value.count }
  var isEmpty: Bool { value.isEmpty }
  var pending: String { value.withPendingBytes { String(decoding: $0, as: UTF8.self) } }
  func enqueue(_ line: String) -> Bool { value.enqueue(line) }
  func consume(_ count: Int) { value.consume(count) }
}

/// The control protocol's framing: bytes in, lines out, and lines in, bytes to write.
@Suite struct LineBufferTests {
  @Test func linesComeOutWhateverPiecesTheBytesArriveIn() {
    let text = "{\"event\":\"hello\"}\n{\"event\":\"camera\",\"node\":3}\n{\"event\":\"quitting\"}\n"
    let expected = ["{\"event\":\"hello\"}", "{\"event\":\"camera\",\"node\":3}", "{\"event\":\"quitting\"}"]
    for size in [1, 2, 3, 7, 16, 1000] {
      let buffer = Buffer(limit: 100)
      var lines: [String] = []
      let bytes = Array(text.utf8)
      for start in stride(from: 0, to: bytes.count, by: size) {
        lines += buffer.append(bytes[start..<min(start + size, bytes.count)])
      }
      #expect(lines == expected, "in pieces of \(size)")
      #expect(buffer.finish() == nil)
    }
  }

  @Test func aCharacterSplitBetweenTwoReadsIsPutBackTogether() {
    let buffer = Buffer(limit: 100)
    let bytes = Array("Caffè ⌘\n".utf8)
    #expect(buffer.append(bytes[..<5]).isEmpty, "the è is cut in half")
    #expect(buffer.append(bytes[5...]) == ["Caffè ⌘"])
  }

  @Test func lineEndingsAndEmptyLines() {
    let buffer = Buffer(limit: 100)
    #expect(buffer.append("status\r\n\nstate\n") == ["status", "", "state"])
  }

  @Test func aRequestEndedByClosingInsteadOfANewlineIsStillALine() {
    let buffer = Buffer(limit: 100)
    #expect(buffer.append("status").isEmpty)
    #expect(buffer.finish() == "status")
    #expect(buffer.finish() == nil)
  }

  @Test func aLineThatNeverEndsStopsTheBufferInsteadOfFillingMemory() {
    let buffer = Buffer(limit: 8)
    #expect(buffer.append("ok\n12345678") == ["ok"], "exactly the limit is accepted")
    #expect(!buffer.overflowed)
    #expect(buffer.append("9").isEmpty)
    #expect(buffer.overflowed)
    #expect(buffer.append("\nstatus\n").isEmpty, "what follows cannot be trusted to start a line")
    #expect(buffer.finish() == nil)
  }

  @Test func bytesThatAreNotTextAreReplacedNotRefused() {
    let buffer = Buffer(limit: 100)
    #expect(buffer.append([0x61, 0xFF, 0x62, 0x0A]) == ["a\u{FFFD}b"])
  }
}

@Suite struct OutboundQueueTests {
  @Test func linesLeaveInOrderHoweverFewBytesTheSocketTakes() {
    let queue = Queue(limit: 1000)
    #expect(queue.isEmpty)
    #expect(queue.enqueue("one"))
    #expect(queue.enqueue("two"))
    #expect(queue.pending == "one\ntwo\n")
    var written = ""
    while !queue.isEmpty {
      written += queue.pending.prefix(3)
      queue.consume(3)
      if written.count == 3 { #expect(queue.enqueue("three"), "lines can join while others are leaving") }
    }
    #expect(written == "one\ntwo\nthree\n")
    #expect(queue.count == 0)
  }

  @Test func aReaderThatFallsTooFarBehindIsRefusedTheNextLine() {
    let queue = Queue(limit: 20)
    #expect(queue.enqueue("123456789"))  // 10 bytes with its newline
    #expect(queue.enqueue("123456789"))  // 20: exactly the limit
    #expect(!queue.enqueue(""), "one more byte is too many")
    #expect(queue.count == 20, "a refused line leaves the queue as it was")
    queue.consume(1)
    #expect(queue.enqueue(""), "a reader that catches up is served again")
  }

  @Test func anEmptyQueueTakesALineOfAnyLength() {
    let queue = Queue(limit: 20)
    let long = String(repeating: "x", count: 500)
    #expect(queue.enqueue(long), "or a long first line could never be sent at all")
    #expect(queue.count == 501)
    #expect(!queue.enqueue("y"))
    queue.consume(501)
    #expect(queue.isEmpty)
    #expect(queue.enqueue("y"))
    #expect(queue.pending == "y\n")
  }

  @Test func oneLineInIsOneLineOut() {
    let queue = Queue(limit: 100)
    #expect(queue.enqueue("a\nb"))
    #expect(queue.pending == "a b\n")
  }

  @Test func consumingMoreThanIsWaitingOrLessThanNothingIsHarmless() {
    let queue = Queue(limit: 100)
    #expect(queue.enqueue("abc"))
    queue.consume(-5)
    #expect(queue.pending == "abc\n")
    queue.consume(1000)
    #expect(queue.isEmpty)
    #expect(queue.pending == "")
  }

  @Test func aLongBacklogDrainsCompletelyAndInOrder() {
    let queue = Queue(limit: 1 << 20)
    var expected = ""
    for number in 0..<20_000 {
      #expect(queue.enqueue("line \(number)"))
      expected += "line \(number)\n"
    }
    var written: [UInt8] = []
    var step = 1
    while !queue.isEmpty {
      let count = min(step, queue.count)
      queue.value.withPendingBytes { written.append(contentsOf: $0.prefix(count)) }
      queue.consume(count)
      step = step * 2 % 70_001 + 1
    }
    #expect(String(decoding: written, as: UTF8.self) == expected)
  }
}

@Suite struct WatchLineTests {
  @Test func eventsRefusalsAndEverythingElseAreToldApart() {
    #expect(ControlClient.classify(#"{"event":"camera","node":3}"#) == .event("camera"))
    #expect(ControlClient.classify(#"{"event":"quitting"}"#) == .event("quitting"))
    #expect(ControlClient.classify(#"{"message":"unknown event `foo`","ok":false}"#) == .refusal("unknown event `foo`"))
    #expect(ControlClient.classify(#"{"message":"fine","ok":true}"#) == .other)
    #expect(ControlClient.classify("not JSON") == .other)
    #expect(ControlClient.classify("[1,2]") == .other)
  }

  @Test func aTitleCannotPassForAnotherEvent() {
    let line = #"{"event":"focus","title":"{\"event\":\"quitting\"}","window":7}"#
    #expect(ControlClient.classify(line) == .event("focus"))
  }
}
