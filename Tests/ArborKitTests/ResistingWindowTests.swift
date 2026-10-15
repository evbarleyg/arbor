import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Windows that cannot take the size of their slot. Those that cannot shrink become tiles (A05);
/// these are the ones that cannot grow: Calculator, System Settings, most utility windows.
@Suite @MainActor struct ResistingWindowTests {
  /// [calculator | notes], with the Desktop between them where it has a column; the calculator cannot be larger than 300 × 400.
  func makeHarness() -> (Harness, WindowID, WindowID) {
    let h = Harness()
    let calculator = h.system.open(app: "Calculator", frame: CGRect(x: 500, y: 300, width: 300, height: 400))
    let notes = h.system.open(app: "Notes")
    h.system.setMaximumSize(calculator, CGSize(width: 300, height: 400))
    h.start()
    h.run("dock \(calculator.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    return (h, calculator, notes)
  }

  @Test func aWindowThatCannotGrowSitsInTheMiddleOfItsSlot() throws {
    let (h, calculator, _) = makeHarness()
    let slot = try #require(h.layout?.windowFrames[calculator])
    let frame = try #require(h.frame(calculator))
    #expect(frame.size == CGSize(width: 300, height: 400))
    #expect(abs(frame.midX - slot.midX) <= 1 && abs(frame.midY - slot.midY) <= 1, "\(frame) in \(slot)")
  }

  @Test func itIsNotMovedAgainWhenNothingAboutItsSlotChanged() {
    let (h, calculator, _) = makeHarness()
    // A gap that is not the calculator's: the one between Notes and a third window.
    let mail = h.system.open(app: "Mail")
    h.run("dock \(mail.rawValue) right")
    let moves = h.system.frameLog.filter { $0.window == calculator }.count
    #expect(h.run("resize \(mail.rawValue) left 40").ok)
    #expect(h.run("resize \(mail.rawValue) left -40").ok)
    #expect(h.system.frameLog.filter { $0.window == calculator }.count == moves, "no flicker through the corner")
  }

  @Test func relayoutByHandTriesAgain() throws {
    let (h, calculator, _) = makeHarness()
    h.system.setMaximumSize(calculator, nil)
    h.run("relayout")
    #expect(h.frame(calculator) == h.layout?.windowFrames[calculator], "it can grow now, and was asked again")
  }

  @Test func itFollowsItsSlot() throws {
    let (h, calculator, notes) = makeHarness()
    h.run("float \(notes.rawValue)")
    let slot = try #require(h.layout?.windowFrames[calculator])
    let frame = try #require(h.frame(calculator))
    #expect(abs(frame.midX - slot.midX) <= 1 && abs(frame.midY - slot.midY) <= 1, "\(frame) in \(slot)")
  }

  @Test func framedItIsCentredOnTheDisplayAndComesBack() throws {
    let (h, calculator, notes) = makeHarness()
    h.run("zoom \(calculator.rawValue)")
    var frame = try #require(h.frame(calculator))
    #expect(abs(frame.midX - h.visibleFrame.midX) <= 1 && abs(frame.midY - h.visibleFrame.midY) <= 1)
    h.run("zoom \(notes.rawValue)")
    #expect(!h.system.isVisible(calculator))
    h.run("home")
    frame = try #require(h.frame(calculator))
    let slot = try #require(h.layout?.windowFrames[calculator])
    #expect(abs(frame.midX - slot.midX) <= 1 && abs(frame.midY - slot.midY) <= 1)
  }

  @Test func movedByHandItIsPutBackInTheMiddle() throws {
    let (h, calculator, _) = makeHarness()
    let before = try #require(h.frame(calculator))
    h.system.userMove(calculator, to: before.offsetBy(dx: 200, dy: 100))
    h.scheduler.runPending()
    #expect(h.frame(calculator) == before)
  }

  @Test func itIsNotTakenForAWindowThatCannotShrink() {
    let (h, calculator, _) = makeHarness()
    #expect(h.layout?.tiles.contains { $0.windows.contains(calculator) } == false)
  }
}
