import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A floating window may hang over the edge of the screen only where its user's own hand left it. What an app says of its
/// window passes for that hand, and while the displays change it can be macOS's doing, heard before Arbor knows of the new
/// displays. Judged by the old ones, such a place can lie on the neighbour, and Arbor then kept the window hanging there.
@Suite @MainActor struct AReportAcrossABorderTests {
  static func display(_ id: String, _ frame: CGRect, top: CGFloat = 25, bottom: CGFloat = 0, isMain: Bool = false) -> DisplaySnapshot {
    DisplaySnapshot(
      id: DisplayID(id), frame: frame,
      visibleFrame: CGRect(x: frame.minX, y: frame.minY + top, width: frame.width, height: frame.height - top - bottom), isMain: isMain)
  }

  /// Whether all of `window` lies in the visible part of one display.
  func isWhollyInView(_ window: WindowID, _ h: Harness) -> Bool {
    guard let frame = h.frame(window) else { return false }
    return h.system.displays().contains { $0.visibleFrame.insetBy(dx: -1, dy: -1).contains(frame) }
  }

  /// `music` floats in full view on `before[1]`, untouched. The displays become `after`; macOS takes the window to `carried`.
  /// Then Finder is docked on the main display, which makes Arbor place the floating windows there.
  func story(
    before: [DisplaySnapshot], music: CGRect, after: [DisplaySnapshot], carried: CGRect, theAppSpeaksFirst: Bool
  ) -> (Harness, WindowID) {
    let h = Harness()
    h.system.displayList = before
    let finder = h.system.open(app: "Finder", pid: 41, frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    h.start()
    let window = h.system.open(app: "Music", pid: 42, frame: music)
    h.scheduler.advance(by: 60)
    if theAppSpeaksFirst {
      h.system.userMove(window, to: carried)
      h.system.setDisplays(after)
    } else {
      h.system.moveSilently(window, to: carried)
      h.system.setDisplays(after)
      h.system.report(window, userInitiated: false)
    }
    h.scheduler.advance(by: 5)
    h.system.cursor = CGPoint(x: 300, y: 300)
    h.system.userFocus(finder)
    #expect(h.run("dock \(finder.rawValue) left").ok)
    h.scheduler.advance(by: 2)
    #expect(h.run("home").ok)
    h.scheduler.advance(by: 2)
    return (h, window)
  }

  /// A display on the left of the laptop, standing lower, only gets a smaller resolution. A window low on it keeps its place
  /// within the display and so comes to lie across the border. A quarter of it showed at the laptop's bottom edge.
  @Test(arguments: [true, false]) func aDisplayOnTheLeftGetsASmallerResolution(theAppSpeaksFirst: Bool) {
    let laptop = Self.display("laptop", CGRect(x: 0, y: 0, width: 1440, height: 900), isMain: true)
    let (h, window) = story(
      before: [laptop, Self.display("desk", CGRect(x: -2560, y: 400, width: 2560, height: 1440))],
      music: CGRect(x: -860, y: 800, width: 700, height: 400),
      after: [laptop, Self.display("desk", CGRect(x: -1920, y: 400, width: 1920, height: 1080))],
      carried: theAppSpeaksFirst ? CGRect(x: -220, y: 800, width: 700, height: 400) : CGRect(x: -700, y: 800, width: 700, height: 400),
      theAppSpeaksFirst: theAppSpeaksFirst)
    #expect(isWhollyInView(window, h), "\(h.frame(window)!)")
  }

  /// The second display changes sides and shrinks at once. Less than half showed on the main display.
  @Test(arguments: [true, false]) func aDisplayChangesSidesAndShrinks(theAppSpeaksFirst: Bool) {
    let (h, window) = story(
      before: [
        Self.display("main", CGRect(x: 0, y: 0, width: 800, height: 600), top: 37, isMain: true),
        Self.display("side", CGRect(x: 800, y: -190, width: 1280, height: 800)),
      ],
      music: CGRect(x: 1366, y: 115, width: 411, height: 281),
      after: [
        Self.display("main", CGRect(x: 0, y: 0, width: 800, height: 600), bottom: 71, isMain: true),
        Self.display("side", CGRect(x: -800, y: 163, width: 800, height: 600), top: 37),
      ],
      carried: theAppSpeaksFirst ? CGRect(x: -234, y: 468, width: 411, height: 281) : CGRect(x: -411, y: 468, width: 411, height: 281),
      theAppSpeaksFirst: theAppSpeaksFirst)
    #expect(isWhollyInView(window, h), "\(h.frame(window)!)")
  }

  /// The hand itself is still believed, on the display where the window was and across the border alike: a drag has a drop,
  /// and the drop writes the note.
  @Test func whatAHandLeavesHangingStillHangs() {
    let laptop = Self.display("laptop", CGRect(x: 0, y: 0, width: 1440, height: 900), isMain: true)
    let desk = Self.display("desk", CGRect(x: 1440, y: 0, width: 1920, height: 1080))
    let h = Harness()
    h.system.displayList = [laptop, desk]
    let finder = h.system.open(app: "Finder", pid: 41, frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let window = h.system.open(app: "Music", pid: 42, frame: CGRect(x: 400, y: 300, width: 700, height: 400))
    h.start()
    h.scheduler.advance(by: 2)

    // On its own display, by a move Arbor does not follow.
    let low = CGRect(x: 400, y: 800, width: 700, height: 400)
    h.system.userMove(window, to: low)
    h.scheduler.advance(by: 2)
    #expect(h.run("home").ok)
    h.scheduler.advance(by: 2)
    #expect(h.frame(window) == low)

    // Across the border, by a drag with ⌘ held, which drops the window where it is let go.
    h.system.heldModifiers = [.command]
    h.system.drag(window, through: [CGPoint(x: 750, y: 810), CGPoint(x: 2400, y: 1000)])
    h.system.heldModifiers = []
    h.scheduler.advance(by: 2)
    let dropped = h.frame(window)!
    #expect(dropped.maxY > desk.frame.maxY, "the drop leaves it hanging below the display: \(dropped)")
    h.system.cursor = CGPoint(x: 300, y: 300)
    #expect(h.run("dock \(finder.rawValue) left").ok)
    h.scheduler.advance(by: 2)
    #expect(h.run("home").ok)
    h.scheduler.advance(by: 2)
    #expect(h.frame(window) == dropped)
  }
}
