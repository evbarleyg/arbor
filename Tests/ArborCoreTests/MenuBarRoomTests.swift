import ArborCore
import CoreGraphics
import Testing

/// Falling back to the single icon when macOS leaves the item out (`MenuBarRoom`).
@Suite struct MenuBarRoomTests {
  let icon = ArborGlyph.iconSize.width

  @Test func atFirstEverythingFits() {
    let room = MenuBarRoom()
    #expect(room.fits(320) && room.fits(icon))
    #expect(room.isShowing == nil && !room.hasBeenSeen)
  }

  /// If macOS always says no, that says something about the question, not about the menu bar.
  @Test func untilTheItemHasBeenSeenANoTakesNothingAway() {
    var room = MenuBarRoom()
    room.observe(width: icon, isShowing: false)
    room.observe(width: 320, isShowing: false)
    #expect(room.fits(320))
    #expect(room.isShowing == false, "it is still what macOS said")
  }

  @Test func onceSeenAnItemThatIsLeftOutIsTooWideAndSoIsAnythingWider() {
    var room = MenuBarRoom()
    room.observe(width: icon, isShowing: true)
    room.observe(width: 166, isShowing: false)
    #expect(!room.fits(166) && !room.fits(320))
    #expect(room.fits(140) && room.fits(icon), "what is narrower is worth a try")
    room.observe(width: 140, isShowing: false)
    #expect(!room.fits(140))
    // A wider one that fails later teaches nothing new.
    room.observe(width: 320, isShowing: false)
    #expect(room.tooWide == 140)
  }

  @Test func thereIsNothingToFallBackToFromTheSingleIcon() {
    var room = MenuBarRoom()
    room.observe(width: icon, isShowing: true)
    room.observe(width: icon, isShowing: false)
    #expect(room.tooWide == nil && room.fits(icon))
  }

  @Test func whatCannotBeToldChangesNothing() {
    var room = MenuBarRoom()
    room.observe(width: icon, isShowing: true)
    room.observe(width: 166, isShowing: false)
    room.observe(width: 166, isShowing: nil)
    #expect(!room.fits(166) && room.isShowing == nil)
    var fresh = MenuBarRoom()
    fresh.observe(width: 320, isShowing: nil)
    #expect(fresh.fits(320) && !fresh.hasBeenSeen)
  }

  @Test func roomThatTurnsUpIsUsed() {
    var room = MenuBarRoom()
    room.observe(width: icon, isShowing: true)
    room.observe(width: 166, isShowing: false)
    room.observe(width: 166, isShowing: true)
    #expect(room.fits(166) && room.fits(320))
  }

  @Test func forgettingTriesEverythingAgainAndKeepsTheTrust() {
    var room = MenuBarRoom()
    room.observe(width: icon, isShowing: true)
    room.observe(width: 166, isShowing: false)
    room.forget()
    #expect(room.fits(320) && room.hasBeenSeen)
    room.observe(width: 320, isShowing: false)
    #expect(!room.fits(320), "no second calibration is needed")
  }
}
