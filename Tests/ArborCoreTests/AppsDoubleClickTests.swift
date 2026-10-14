import ArborCore
import Foundation
import Testing

private let a = WindowID(101)
private let b = WindowID(102)

/// K193: what comes of a double-click that went to an app is left alone.
@Suite struct AppsDoubleClickTests {
  private let note = AppsDoubleClick(window: a, time: 100)

  @Test func everySecondClickInARowCompletesADoubleClick() {
    #expect([0, 1, 2, 3, 4, 5, 6].filter(AppsDoubleClick.isCompleted(byClick:)) == [2, 4, 6])
    #expect(!AppsDoubleClick.isCompleted(byClick: -2))
  }

  @Test func whatTheWindowDoesRightAfterwardsCameOfTheDoubleClick() {
    #expect(note.explains(aChangeOf: a, at: 100.1, buttonIsDown: false))
    #expect(note.explains(aChangeOf: a, at: 100 + AppsDoubleClick.patience, buttonIsDown: false))
  }

  @Test func laterItIsTheAppsOwnIdea() {
    #expect(!note.explains(aChangeOf: a, at: 100.1 + AppsDoubleClick.patience, buttonIsDown: false))
    #expect(!note.explains(aChangeOf: a, at: 5000, buttonIsDown: false))
  }

  @Test func itIsFreshForAsLongAsItExplainsAnything() {
    #expect(note.isFresh(at: 100) && note.isFresh(at: 100 + AppsDoubleClick.patience))
    #expect(!note.isFresh(at: 100.1 + AppsDoubleClick.patience))
    #expect(!note.isFresh(at: .nan))
  }

  @Test func anotherWindowsMoveHasNothingToDoWithIt() {
    #expect(!note.explains(aChangeOf: b, at: 100.1, buttonIsDown: false))
  }

  /// macOS acts when the button comes up. A window that changes under a button that is down is dragged or resized.
  @Test func nothingHasComeOfItWhileTheButtonIsDown() {
    #expect(!note.explains(aChangeOf: a, at: 100.1, buttonIsDown: true))
  }

  @Test func aClockSetBackDoesNotKeepTheNoteForHours() {
    #expect(note.explains(aChangeOf: a, at: 99.9, buttonIsDown: false), "a hair's breadth")
    #expect(!note.explains(aChangeOf: a, at: -3500, buttonIsDown: false))
    #expect(!note.explains(aChangeOf: a, at: .nan, buttonIsDown: false))
  }

  @Test func aWindowLeftAloneIsNotPutBackUntilTheLayoutChanges() {
    var limiter = EnforcementLimiter()
    limiter.leave(a)
    #expect(limiter.givenUp == [a])
    #expect(limiter.leftAlone == [a])
    let itself = limiter.allowsPuttingBack(a, at: 1)
    let neighbour = limiter.allowsPuttingBack(b, at: 1)
    #expect(!itself)
    #expect(neighbour)
    limiter.reset([a])
    #expect(limiter.givenUp.isEmpty)
    #expect(limiter.leftAlone.isEmpty)
    let afterwards = limiter.allowsPuttingBack(a, at: 2)
    #expect(afterwards)
  }

  @Test func aWindowArborGaveUpOnIsNotOneThatWasLeftAlone() {
    var limiter = EnforcementLimiter(limit: 1, span: 3)
    _ = limiter.allowsPuttingBack(a, at: 1)
    _ = limiter.allowsPuttingBack(a, at: 2)
    #expect(limiter.givenUp == [a])
    #expect(limiter.leftAlone.isEmpty)
  }
}
