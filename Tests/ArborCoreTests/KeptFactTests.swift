import ArborCore
import Testing

@Suite struct KeptFactTests {
  @Test func itIsReadOnceForAsLongAsTheKeyStays() {
    var fact = KeptFact<[Int], String>()
    var reads = 0
    func read() -> String {
      reads += 1
      return "answer \(reads)"
    }
    for _ in 0..<100 { #expect(fact.value(for: [1, 2, 3], read: read) == "answer 1") }
    #expect(reads == 1)
  }

  @Test func anotherKeyReadsItAgainAndSoDoesTheOldKeyComingBack() {
    var fact = KeptFact<[Int], Int>()
    var reads = 0
    func read() -> Int {
      reads += 1
      return reads
    }
    #expect(fact.value(for: [1], read: read) == 1)
    #expect(fact.value(for: [1, 2], read: read) == 2)
    // Only the last is kept: a process number can be given out again, to somebody else.
    #expect(fact.value(for: [1], read: read) == 3)
    #expect(fact.value(for: [1], read: read) == 3)
  }

  @Test func forgottenItIsReadAgain() {
    var fact = KeptFact<Int, Int>()
    var reads = 0
    func read() -> Int {
      reads += 1
      return reads
    }
    #expect(fact.value(for: 7, read: read) == 1)
    fact.forget()
    #expect(fact.value(for: 7, read: read) == 2)
  }

  /// "It cannot be read" is an answer like any other, and no reason to ask every time.
  @Test func anAnswerOfNothingIsKeptToo() {
    var fact = KeptFact<Int, Int?>()
    var reads = 0
    for _ in 0..<3 {
      let answer = fact.value(for: 1) {
        reads += 1
        return nil
      }
      #expect(answer == nil)
    }
    #expect(reads == 1)
  }
}
