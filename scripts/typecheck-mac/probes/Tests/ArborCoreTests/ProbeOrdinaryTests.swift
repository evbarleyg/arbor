// selftest.py: lines that end in "wrong" must be reported, the others must not. Never shipped, never run.
// A test like any other, with nothing in it for the Mac alone. Linux compiles it and is content; the Mac is not, an hour later.
import CoreGraphics
import Testing

@Suite struct ProbeOrdinaryTests {
  @Test func framesAreDistinct() {
    let frames = [CGRect(x: 0, y: 0, width: 1, height: 1), CGRect(x: 1, y: 0, width: 1, height: 1)]
    #expect(Set(frames.map(\.minX)).count == 2)
    let expected = Set(frames.map { $0.offsetBy(dx: 1, dy: 0) })  // wrong
    #expect(Set(frames) != expected)  // wrong
  }
}
