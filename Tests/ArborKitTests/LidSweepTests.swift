import ArborTesting
import CoreGraphics
import Testing

/// The lid sweep itself (`arbor-sim sweep` plays all of it): that it sees what it is there to see, and, on a coarse grid, that no window is lost.
@MainActor @Suite struct LidSweepTests {
  private func coarse(_ column: LidSweep.Column) -> LidSweep {
    var sweep = LidSweep(column)
    sweep.stride = 400
    return sweep
  }

  @Test(arguments: LidSweep.Side.allCases) func aMacWithoutArborDiffersFromItselfNowhere(side: LidSweep.Side) {
    for order in ChaosAction.WindowsFollow.inAnInstant {
      var sweep = coarse(LidSweep.Column(side: side, order: order))
      sweep.withArbor = false
      let tally = sweep.run()
      #expect(tally.places > 10)
      #expect(tally.hidden.isEmpty && tally.outOfReach.isEmpty && tally.jumped.isEmpty && tally.fitted.isEmpty, "\(order)")
      #expect(tally.homeOnTheLaptop == 0 && tally.whereTheHandLeftIt == 0, "\(order)")
    }
  }

  @Test func aWindowTakenOutOfViewIsSeen() {
    var sweep = coarse(LidSweep.Column(side: .right))
    sweep.withArbor = false
    sweep.sabotage = { $0.system.moveSilently(LidSweep.window, to: CGRect(x: 9000, y: 9000, width: 600, height: 500)) }
    #expect(sweep.run().hidden.count > 10)
  }

  @Test func aWindowWhoseTitleBarIsAboveTheScreenIsSeen() {
    var sweep = coarse(LidSweep.Column(side: .right))
    sweep.withArbor = false
    // Four fifths of it show, so it is in view, and no hand can take hold of it.
    sweep.sabotage = { $0.system.moveSilently(LidSweep.window, to: CGRect(x: 300, y: -100, width: 600, height: 500)) }
    let tally = sweep.run()
    #expect(tally.outOfReach.count > 10)
    #expect(tally.hidden.isEmpty)
  }

  /// With the lid shut there is no laptop to go home to: a window that began on it and is shoved about then has jumped.
  @Test func homeOnTheLaptopIsSaidOnlyWhileTheLidIsOpen() {
    var sweep = coarse(LidSweep.Column(side: .right, byHand: false))
    sweep.withArbor = false
    sweep.stride = 100
    sweep.sabotage = { runner in
      guard runner.system.displayList.count == 1, let frame = runner.harness.frame(LidSweep.window) else { return }
      runner.system.moveSilently(LidSweep.window, to: frame.offsetBy(dx: 0, dy: 60))
    }
    let tally = sweep.run()
    #expect(tally.homeOnTheLaptop == 0)
    #expect(tally.jumped.count > 10)
  }

  @Test func aWindowShovedAsideIsSeen() {
    var sweep = coarse(LidSweep.Column(side: .right, byHand: false))
    sweep.withArbor = false
    sweep.sabotage = { runner in
      guard let frame = runner.harness.frame(LidSweep.window) else { return }
      runner.system.moveSilently(LidSweep.window, to: frame.offsetBy(dx: 0, dy: 60))
    }
    let tally = sweep.run()
    #expect(tally.jumped.count > 10)
    #expect(tally.hidden.isEmpty)
  }

  @Test(arguments: LidSweep.Side.allCases) func noWindowIsLost(side: LidSweep.Side) {
    for column in LidSweep.Column.all([side]) {
      let tally = coarse(column).run()
      #expect(tally.places > 10)
      #expect(tally.trouble.isEmpty, "\(column): \(tally.trouble.prefix(2))")
      #expect(tally.outOfAHandsReach == 0, "\(column)")
      #expect(tally.hidden.isEmpty, "\(column): \(tally.hidden.prefix(2))")
      #expect(tally.outOfReach.isEmpty, "\(column): \(tally.outOfReach.prefix(2))")
    }
  }

  @Test func theStoryHasFourStages() {
    let story = LidSweep(LidSweep.Column(side: .right, byHand: false)).story(x: 2400, y: 300)
    #expect(story.count == 4 && story[0].hasPrefix("at the start: at 2400,300"))
  }

  @Test func aPlaceNoHandCouldPutAWindowInIsNotPassedOffAsPlayed() {
    var sweep = coarse(LidSweep.Column(side: .left))
    // Ten points of title bar at the far edge of the big display, beyond which there is nothing.
    sweep.margin = 10
    #expect(sweep.run().outOfAHandsReach > 0)
  }
}
