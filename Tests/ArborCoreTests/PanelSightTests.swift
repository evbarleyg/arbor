import ArborCore
import Testing

/// A panel that takes the keyboard goes when it goes out of sight (board 4.19: Go to… outlived a look at Mission Control).
@Suite struct PanelSightTests {
  /// What is said of a panel from its opening on, and after each word whether it is to go.
  private func answers(_ said: [Bool]) -> [Bool] {
    var sight = PanelSight()
    return said.map { sight.isLost(shows: $0) }
  }

  @Test func aPanelThatShowedAndNoLongerDoesIsToGo() {
    #expect(answers([true, false]) == [false, true])
  }

  /// AppKit may say "does not show" of a panel that is on its way to the screen. Taken at its word, no panel would ever open.
  @Test func aPanelOnItsWayToTheScreenStays() {
    #expect(answers([false, false, true]) == [false, false, false])
    #expect(answers([false, true, false]) == [false, false, true], "once it has shown, it counts")
  }

  @Test func whileItShowsItStays() {
    #expect(answers([true, true, true]) == [false, false, false])
  }

  /// Each opening begins anew: what the last one saw says nothing of this one.
  @Test func theNextOpeningBeginsAnew() {
    var sight = PanelSight()
    _ = sight.isLost(shows: true)
    sight = PanelSight()
    let lost = sight.isLost(shows: false)
    #expect(!lost)
  }
}
