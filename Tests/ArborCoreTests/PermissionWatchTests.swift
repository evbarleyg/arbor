import ArborCore
import Testing

/// When a series of answers means that Accessibility permission is gone, or back
/// (docs/features/F63-permission-taken-away.md).
@Suite struct PermissionWatchTests {
  @Test func allIsWellWhileTheAnswerIsYes() {
    var watch = PermissionWatch()
    for _ in 0..<5 { #expect(watch.heard(true) == .none) }
    #expect(watch.isGranted)
    #expect(watch.secondsToNextQuestion == 2)
  }

  @Test func oneNoIsNotBelievedAndIsAskedAboutAgainSoon() {
    var watch = PermissionWatch()
    #expect(watch.heard(false) == .none)
    #expect(watch.isGranted)
    #expect(watch.secondsToNextQuestion == 0.5)
    #expect(watch.heard(true) == .none)
    #expect(watch.secondsToNextQuestion == 2)
    // The doubt is forgotten: the next lone "no" is the first again.
    #expect(watch.heard(false) == .none)
    #expect(watch.isGranted)
  }

  @Test func theSecondNoInARowIsBelieved() {
    var watch = PermissionWatch()
    _ = watch.heard(false)
    #expect(watch.heard(false) == .lost)
    #expect(!watch.isGranted)
    #expect(watch.secondsToNextQuestion == 1)
  }

  @Test func aNoThatSomethingElseBearsOutIsBelievedAtOnce() {
    var watch = PermissionWatch()
    #expect(watch.heard(false, beyondDoubt: true) == .lost)
    #expect(!watch.isGranted)
  }

  @Test func itIsLostOnceHoweverOftenTheAnswerIsNo() {
    var watch = PermissionWatch()
    _ = watch.heard(false, beyondDoubt: true)
    for _ in 0..<5 {
      #expect(watch.heard(false) == .none)
      #expect(watch.heard(false, beyondDoubt: true) == .none)
    }
  }

  @Test func oneYesBringsItBackAndTheNextLossNeedsTwoAgain() {
    var watch = PermissionWatch()
    _ = watch.heard(false, beyondDoubt: true)
    #expect(watch.heard(true) == .returned)
    #expect(watch.isGranted)
    #expect(watch.heard(true) == .none)
    #expect(watch.heard(false) == .none)
    #expect(watch.heard(false) == .lost)
  }

  @Test func aYesBeyondDoubtIsAYes() {
    var watch = PermissionWatch()
    #expect(watch.heard(true, beyondDoubt: true) == .none)
    #expect(watch.isGranted)
  }

  @Test func theWaysHomeAreTheCommandsThatBringWindowsBack() {
    for command in [Command.showAll, .home, .floatAll, .floatAllHere, .togglePause, .pause(minutes: nil), .pause(minutes: 5)] {
      #expect(command.bringsWindowsBack, "\(command.text)")
    }
    for command in [Command.zoom(nil), .back, .arrange, .desktop, .stepOut, .resume, .quit, .status, .dock(nil, .left)] {
      #expect(!command.bringsWindowsBack, "\(command.text)")
    }
  }
}
