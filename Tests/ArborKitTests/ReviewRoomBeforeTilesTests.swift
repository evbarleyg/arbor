import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// An independent review of F61 (room before tiles) as it stands on the trunk, beside pins, summons, guests and views.
@Suite @MainActor struct ReviewRoomBeforeTilesTests {
  /// Notes (709), Safari (574) and Mail (500) on 1440 points, floating, started.
  func makeHarness(
    settings: Settings = Harness.settingsWhenNoneAreGiven
  ) -> (Harness, notes: WindowID, safari: WindowID, mail: WindowID) {
    let h = Harness(settings: settings)
    let notes = h.system.open(
      app: "Notes", pid: 101, frame: CGRect(x: 200, y: 100, width: 1000, height: 660),
      minimumSize: CGSize(width: 709, height: 300))
    let safari = h.system.open(
      app: "Safari", pid: 102, frame: CGRect(x: 60, y: 60, width: 1324, height: 800),
      minimumSize: CGSize(width: 574, height: 240))
    let mail = h.system.open(
      app: "Mail", pid: 103, frame: CGRect(x: 100, y: 80, width: 900, height: 600),
      minimumSize: CGSize(width: 500, height: 300))
    h.start()
    return (h, notes, safari, mail)
  }

  func isInView(_ h: Harness, _ window: WindowID) -> Bool { h.layout?.windowFrames[window] != nil }
  func line(_ h: Harness) -> String {
    let reply = h.run("layout --ids")
    return reply.text ?? reply.message
  }

  // MARK: Whose hand

  /// Notes is a tile because three wide windows do not fit: Arbor's doing. Moving the gap between the other two is
  /// no wish to keep Notes small.
  @Test(.withTiles) func aGapMovedElsewhereLeavesATileThatWaitsForRoomWaiting() {
    let (h, notes, safari, mail) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("dock \(mail.rawValue) right")
    #expect(!isInView(h, notes) && isInView(h, safari) && isInView(h, mail))
    h.run("resize \(mail.rawValue) left 10")
    #expect(!isInView(h, notes))
    h.system.close(mail)
    #expect(isInView(h, notes), "\(line(h))")
    #expect(isInView(h, safari))
  }

  /// The same tile made narrower still by hand is as its user wants it.
  @Test(.withTiles) func aTileMadeNarrowerByHandStaysAsItWasLeft() {
    let (h, notes, safari, mail) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("dock \(mail.rawValue) right")
    #expect(!isInView(h, notes))
    h.run("resize \(notes.rawValue) right -100")
    h.system.close(mail)
    #expect(!isInView(h, notes), "\(line(h))")
    #expect(isInView(h, safari))
  }

  // MARK: Who lives on the Desktop

  /// A pinned window is in view wherever the view goes, a summoned one lies over the view, a stashed one is out of view. None
  /// of them needs the Desktop, so none of them costs a docked window its place.
  @Test(arguments: [["pin 103"], ["summon Mail"], ["summon Mail", "summon Mail"]])
  func aFloatingWindowThatDoesNotLiveOnTheDesktopCostsNobodyTheirPlace(_ steps: [String]) {
    let (h, notes, safari, _) = makeHarness()
    for step in steps { #expect(h.run(step).ok, "\(step)") }
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    #expect(isInView(h, notes) && isInView(h, safari), "\(line(h))")
    h.run("zoom \(safari.rawValue)")
    h.run("show-all")
    #expect(isInView(h, notes) && isInView(h, safari), "\(line(h))")
  }

  // MARK: What the Desktop is owed: only one with a column of its own ever is

  /// The spec tells people that an empty Desktop squeezed into a tile is one click away. The click must not cost it what it is owed.
  @Test(arguments: [["desktop", "show-all"], ["desktop", "back"], ["desktop", "home"]])
  func lookingAtTheDesktopDoesNotCancelWhatItIsOwed(_ visit: [String]) {
    let (h, notes, safari, mail) = makeHarness(settings: .withDesktopColumn)
    h.system.close(mail)
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    #expect(h.layout?.desktopFrame == nil && h.workspace.desktopIsOwedRoom == true)
    for step in visit { #expect(h.run(step).ok, "\(step)") }
    #expect(h.workspace.desktopIsOwedRoom == true)
    h.system.close(notes)
    #expect(h.layout?.desktopFrame != nil, "\(line(h))")
    #expect(h.workspace.desktopIsOwedRoom == nil)
  }

  /// Moving one of its own does, as before.
  @Test func movingTheDesktopsOwnGapStillDoes() {
    let (h, notes, safari, mail) = makeHarness(settings: .withDesktopColumn)
    h.system.close(mail)
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    #expect(h.workspace.desktopIsOwedRoom == true)
    #expect(h.run("resize \(safari.rawValue) left 10").ok)
    #expect(h.workspace.desktopIsOwedRoom == nil)
  }
}
