import ArborCore
import Testing

/// See ParityProofTests in ArborKitTests.
@Suite struct ParityProofCoreTests {
  /// T71: the URL commands TrellisWM publishes are `arrange`, `back`, `zoom-out`, "forward, zoom and more". Someone who
  /// has them in Raycast or on a Stream Deck should only have to change the scheme.
  @Test func trellisURLVerbsAreAccepted() throws {
    #expect(try Command.parse(words: ["arrange"]) == .arrange)
    #expect(try Command.parse(words: ["back"]) == .back)
    #expect(try Command.parse(words: ["forward"]) == .forward)
    #expect(try Command.parse(words: ["zoom-out"]) == .stepOut)
    #expect(try Command.parse(words: ["zoom-in"]) == .stepIn)
    #expect(try Command.parse(words: ["zoom"]) == .zoom(nil))
    #expect(throws: Command.ParseError.self) { try Command.parse("zoom-out 3") }
  }
}
