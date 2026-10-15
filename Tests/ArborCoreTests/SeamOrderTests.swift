import CoreGraphics
import Foundation
import Testing

@testable import ArborCore

/// Which window a gap's handle lies just below (`Seam.rearmostNeighbour`).
@Suite struct SeamOrderTests {
  let a = WindowID(1), b = WindowID(2), c = WindowID(3), float = WindowID(9)

  /// Two columns 12 points apart; the right one is one window, or two, one above the other.
  func seam(_ axis: Axis = .horizontal) -> Seam {
    Seam(
      split: NodeID(1), leading: NodeID(2), trailing: NodeID(3), axis: axis,
      frame: axis == .horizontal ? CGRect(x: 300, y: 40, width: 12, height: 600) : CGRect(x: 12, y: 300, width: 600, height: 12),
      pointsPerWeight: 100)
  }
  var columns: [WindowID: CGRect] { [a: CGRect(x: 12, y: 40, width: 288, height: 600), b: CGRect(x: 312, y: 40, width: 288, height: 600)] }

  @Test func itIsTheOneOfTheTwoThatLiesFurtherBack() {
    #expect(seam().rearmostNeighbour(among: columns, frontToBack: [a, b, float]) == b)
    #expect(seam().rearmostNeighbour(among: columns, frontToBack: [b, a, float]) == a)
  }

  @Test func whatLiesBetweenTheTwoOrInFrontOfThemChangesNothing() {
    #expect(seam().rearmostNeighbour(among: columns, frontToBack: [float, a, b]) == b)
    #expect(seam().rearmostNeighbour(among: columns, frontToBack: [a, float, b]) == b)
  }

  @Test func aGapBetweenRowsIsNoDifferent() {
    let rows = [a: CGRect(x: 12, y: 40, width: 600, height: 260), b: CGRect(x: 12, y: 312, width: 600, height: 260)]
    #expect(seam(.vertical).neighbours(among: rows).leading == [a])
    #expect(seam(.vertical).neighbours(among: rows).trailing == [b])
    #expect(seam(.vertical).rearmostNeighbour(among: rows, frontToBack: [b, float, a]) == a)
  }

  @Test func everyWindowOfAGroupThatReachesTheGapIsANeighbour() {
    var slots = columns
    slots[b] = CGRect(x: 312, y: 40, width: 288, height: 294)
    slots[c] = CGRect(x: 312, y: 346, width: 288, height: 294)
    #expect(seam().neighbours(among: slots).trailing == [b, c])
    #expect(seam().rearmostNeighbour(among: slots, frontToBack: [c, a, float, b]) == b)
    #expect(seam().rearmostNeighbour(among: slots, frontToBack: [b, a, c, float]) == c)
  }

  @Test func aWindowThatDoesNotReachTheGapIsNone() {
    var slots = columns
    slots[c] = CGRect(x: 612, y: 40, width: 288, height: 600)
    #expect(seam().neighbours(among: slots).trailing == [b])
    #expect(seam().rearmostNeighbour(among: slots, frontToBack: [a, b, c]) == b, "the third column lies behind both, and beside another gap")
  }

  /// A window over the Desktop, or over a tile, in the right column. What stands on the Desktop there stands in plain view, across the gap too.
  @Test func withAnythingButWindowsAlongASideTheHandleStaysBehindEverything() {
    var slots = columns
    slots[b] = CGRect(x: 312, y: 40, width: 288, height: 294)
    let below = CGRect(x: 312, y: 346, width: 288, height: 294)
    #expect(seam().rearmostNeighbour(among: slots, frontToBack: [a, b, float]) == b, "nobody has said what else lies there")
    #expect(seam().rearmostNeighbour(among: slots, besides: [below], frontToBack: [a, b, float]) == nil)
    let elsewhere = CGRect(x: 612, y: 40, width: 288, height: 600)
    #expect(seam().rearmostNeighbour(among: columns, besides: [elsewhere], frontToBack: [a, b, float]) == b)
  }

  @Test func aLayoutKnowsWhatInItIsNoWindow() {
    var layout = Layout(camera: NodeID(1), frame: CGRect(x: 0, y: 25, width: 1440, height: 875))
    layout.windowFrames = columns
    layout.windowFrames[b] = CGRect(x: 312, y: 40, width: 288, height: 294)
    #expect(layout.windowOverTheHandle(of: seam(), frontToBack: [a, b]) == b)
    layout.desktopFrame = CGRect(x: 312, y: 346, width: 288, height: 294)
    #expect(layout.windowOverTheHandle(of: seam(), frontToBack: [a, b]) == nil)
    layout.desktopFrame = nil
    layout.openPlaces[NodeID(7)] = CGRect(x: 312, y: 346, width: 288, height: 294)
    #expect(layout.windowOverTheHandle(of: seam(), frontToBack: [a, b]) == nil)
  }

  @Test func withNoWindowOnOneSideTheHandleStaysBehindEverything() {
    #expect(seam().rearmostNeighbour(among: [a: columns[a]!], frontToBack: [a, float]) == nil, "a tile, the Desktop, a waiting place")
    #expect(seam().rearmostNeighbour(among: [:], frontToBack: [float]) == nil)
  }

  @Test func whereTheOrderDoesNotTellOfANeighbourNobodyKnowsTheRearmost() {
    #expect(seam().rearmostNeighbour(among: columns, frontToBack: []) == nil)
    #expect(seam().rearmostNeighbour(among: columns, frontToBack: [a, float]) == nil)
  }

  @Test func aSeamFromAnOlderTraceLiesBelowNothing() throws {
    var seam = seam()
    seam.liesBelow = b
    let whole = try JSONEncoder().encode(seam)
    #expect(try JSONDecoder().decode(Seam.self, from: whole) == seam)
    var fields = try #require(try JSONSerialization.jsonObject(with: whole) as? [String: Any])
    fields["liesBelow"] = nil
    #expect(try JSONDecoder().decode(Seam.self, from: JSONSerialization.data(withJSONObject: fields)).liesBelow == nil)
  }
}
