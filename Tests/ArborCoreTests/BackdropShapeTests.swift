import ArborCore
import CoreGraphics
import Testing

private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)

private func area(_ rects: [CGRect]) -> CGFloat { rects.map(\.area).reduce(0, +) }

/// The area inside a loop by the shoelace formula: positive clockwise on screen, negative for a hole.
private func signedArea(_ loop: [BackdropShape.Corner]) -> CGFloat {
  var sum: CGFloat = 0
  for (index, corner) in loop.enumerated() {
    let next = loop[(index + 1) % loop.count].point
    sum += corner.point.x * next.y - next.x * corner.point.y
  }
  return sum / 2
}

@Suite struct BackdropShapeTests {
  func surface(_ slots: [CGRect], growth: CGFloat = 6, desktop: CGRect? = nil) -> [CGRect] {
    BackdropShape.surface(slots: slots, growth: growth, within: screen, avoiding: desktop)
  }

  @Test func growthIsHalfTheGapInWholePoints() {
    #expect(BackdropShape.growth(forGap: 12) == 6)
    #expect(BackdropShape.growth(forGap: 13) == 7)
    #expect(BackdropShape.growth(forGap: 12.6) == 7)
    #expect(BackdropShape.growth(forGap: 1) == 1)
    #expect(BackdropShape.growth(forGap: 0) == 0)
    #expect(BackdropShape.growth(forGap: -8) == 0)
    #expect(BackdropShape.growth(forGap: .nan) == 0)
    #expect(BackdropShape.growth(forGap: .infinity) == 0)
    #expect(BackdropShape.growth(forGap: 1e300).isFinite)
  }

  @Test func aSlotGrowsOnAllFourSides() {
    let slot = CGRect(x: 12, y: 37, width: 464, height: 851)
    #expect(surface([slot]) == [CGRect(x: 6, y: 31, width: 476, height: 863)])
    #expect(surface([slot], growth: 0) == [slot])
  }

  @Test func neighboursMeetInTheMiddleOfTheGapAndBecomeOneRectangle() {
    let left = CGRect(x: 12, y: 37, width: 300, height: 851)
    let right = CGRect(x: 324, y: 37, width: 400, height: 851)
    #expect(surface([left, right]) == [CGRect(x: 6, y: 31, width: 724, height: 863)])
    let above = CGRect(x: 12, y: 37, width: 300, height: 400)
    let below = CGRect(x: 12, y: 449, width: 300, height: 439)
    #expect(surface([above, below]) == [CGRect(x: 6, y: 31, width: 312, height: 863)])
  }

  @Test func theSurfaceDependsOnTheAreaNotOnHowTheSlotsDivideIt() {
    func columns(split: CGFloat) -> [CGRect] {
      [
        CGRect(x: 12, y: 37, width: split - 12, height: 851),
        CGRect(x: split + 12, y: 37, width: 700 - split, height: 851),
      ]
    }
    #expect(surface(columns(split: 200)) == surface(columns(split: 455)), "dragging a seam between two windows")
    #expect(surface(columns(split: 200)) == surface(columns(split: 200).reversed()), "the order of the slots")
  }

  @Test func slotsFurtherApartThanTheGapStaySeparate() {
    let left = CGRect(x: 12, y: 37, width: 300, height: 851)
    let right = CGRect(x: 1128, y: 37, width: 300, height: 851)
    #expect(surface([right, left]) == [left.insetBy(dx: -6, dy: -6), right.insetBy(dx: -6, dy: -6)])
    #expect(BackdropShape.contours(of: surface([left, right])).count == 2)
  }

  @Test func anLShapeIsTwoBandsWithOneInwardCorner() {
    let column = CGRect(x: 12, y: 37, width: 300, height: 851)
    let top = CGRect(x: 324, y: 37, width: 1104, height: 300)
    let rects = surface([column, top])
    #expect(rects == [CGRect(x: 6, y: 31, width: 1428, height: 312), CGRect(x: 6, y: 343, width: 312, height: 551)])
    let loops = BackdropShape.contours(of: rects)
    #expect(loops.count == 1)
    #expect(loops[0].count == 6)
    #expect(loops[0].filter { !$0.isConvex }.map(\.point) == [CGPoint(x: 318, y: 343)])
    #expect(signedArea(loops[0]) == area(rects))
  }

  @Test func windowsAllAroundTheDesktopLeaveAHole() {
    let desktop = CGRect(x: 324, y: 349, width: 792, height: 227)
    let slots = [
      CGRect(x: 12, y: 37, width: 300, height: 851), CGRect(x: 1128, y: 37, width: 300, height: 851),
      CGRect(x: 324, y: 37, width: 792, height: 300), CGRect(x: 324, y: 588, width: 792, height: 300),
    ]
    let rects = surface(slots, desktop: desktop)
    let hole = desktop.insetBy(dx: -6, dy: -6)
    #expect(area(rects) == screen.insetBy(dx: 6, dy: 6).area - hole.area)
    #expect(rects.allSatisfy { !$0.overlaps(hole) })

    let loops = BackdropShape.contours(of: rects)
    #expect(loops.count == 2)
    let outer = loops.first { signedArea($0) > 0 }
    let inner = loops.first { signedArea($0) < 0 }
    #expect(outer?.count == 4 && outer?.allSatisfy(\.isConvex) == true)
    #expect(inner?.count == 4 && inner?.allSatisfy { !$0.isConvex } == true)
    #expect(Set(inner?.map(\.point.x) ?? []) == [hole.minX, hole.maxX])
    #expect(Set(inner?.map(\.point.y) ?? []) == [hole.minY, hole.maxY])
  }

  @Test func theDesktopIsNeverCoveredHoweverFarSlotsGrow() {
    let slot = CGRect(x: 12, y: 37, width: 300, height: 851)
    let desktop = CGRect(x: 324, y: 37, width: 1104, height: 851)
    let rects = surface([slot], growth: 40, desktop: desktop)
    #expect(rects.allSatisfy { !$0.overlaps(desktop) })
    // It still grows where the Desktop is not: up to the Desktop's edge, and above and below it.
    #expect(rects.contains { $0.contains(CGPoint(x: 323, y: 400)) })
    #expect(rects.contains { $0.contains(CGPoint(x: 340, y: 30)) })
  }

  @Test func theSurfaceStaysOnTheDisplay() {
    let slot = screen.insetBy(dx: 12, dy: 12)
    #expect(surface([slot], growth: 500) == [screen])
    #expect(surface([CGRect(x: 2000, y: 100, width: 300, height: 300)]).isEmpty, "a slot on another display")
    #expect(surface([CGRect(x: 1400, y: 800, width: 300, height: 300)]) == [CGRect(x: 1394, y: 794, width: 46, height: 106)])
  }

  @Test func areasThatTouchOnlyAtAPointKeepSeparateOutlines() {
    let rects = [CGRect(x: 0, y: 100, width: 100, height: 100), CGRect(x: 100, y: 200, width: 100, height: 100)]
    let loops = BackdropShape.contours(of: rects)
    #expect(loops.count == 2)
    #expect(loops.allSatisfy { $0.count == 4 && $0.allSatisfy(\.isConvex) && signedArea($0) == 10_000 })
    // The other diagonal as well.
    let mirrored = [CGRect(x: 100, y: 100, width: 100, height: 100), CGRect(x: 0, y: 200, width: 100, height: 100)]
    #expect(BackdropShape.contours(of: mirrored).allSatisfy { $0.count == 4 && signedArea($0) == 10_000 })
    #expect(BackdropShape.contours(of: mirrored).count == 2)
  }

  @Test func overlappingSlotsCountOnce() {
    let rects = surface(
      [CGRect(x: 100, y: 100, width: 200, height: 200), CGRect(x: 200, y: 200, width: 200, height: 200)], growth: 0)
    #expect(area(rects) == 70_000)
    for (index, rect) in rects.enumerated() {
      #expect(rects[(index + 1)...].allSatisfy { !$0.overlaps(rect) })
    }
    #expect(BackdropShape.contours(of: rects).map(\.count) == [8])
  }

  @Test func nothingToCoverGivesNothing() {
    #expect(surface([]).isEmpty)
    #expect(surface([.zero, .null, CGRect(x: CGFloat.nan, y: 0, width: 5, height: 5)]).isEmpty)
    #expect(surface([CGRect(x: 10, y: 50, width: CGFloat.infinity, height: 10)]).isEmpty)
    #expect(BackdropShape.surface(slots: [screen], growth: 6, within: .zero).isEmpty)
    #expect(BackdropShape.surface(slots: [screen], growth: 6, within: .null).isEmpty)
    #expect(
      BackdropShape.surface(slots: [screen], growth: 6, within: CGRect(x: CGFloat.nan, y: 0, width: 900, height: 600))
        .isEmpty)
    #expect(surface([CGRect(x: 100, y: 100, width: 50, height: 50)], growth: .nan) == [CGRect(x: 100, y: 100, width: 50, height: 50)])
    #expect(BackdropShape.contours(of: []).isEmpty)
    #expect(BackdropShape.outline(of: [], cornerRadius: 18, innerRadius: 18).isEmpty)
  }

  @Test func theOutlineRoundsOuterAndInwardCornersByTheirOwnRadii() {
    let rects = [CGRect(x: 0, y: 100, width: 400, height: 100), CGRect(x: 0, y: 200, width: 100, height: 300)]
    let plain = BackdropShape.outline(of: rects, cornerRadius: 0, innerRadius: 0)
    #expect(plain.count == 7, "a move, five lines and the close")
    #expect(plain.points.contains(CGPoint(x: 100, y: 200)))
    let outerOnly = BackdropShape.outline(of: rects, cornerRadius: 18, innerRadius: 0)
    #expect(outerOnly.points.contains(CGPoint(x: 100, y: 200)))
    #expect(!outerOnly.points.contains(CGPoint(x: 0, y: 100)))
    let both = BackdropShape.outline(of: rects, cornerRadius: 18, innerRadius: 18)
    #expect(!both.points.contains(CGPoint(x: 100, y: 200)))
    #expect(both.filter { $0 == .close }.count == 1)
  }

  @Test func inwardCornersAreNotRoundedIntoTheDesktop() {
    #expect(BackdropShape.innerRadius(for: 22, growth: 6) == 18)
    #expect(BackdropShape.innerRadius(for: 26, growth: 10) == 26)
    #expect(BackdropShape.innerRadius(for: 14, growth: 2) == 6)
    #expect(BackdropShape.innerRadius(for: 12, growth: 0) == 0)
    // The Desktop's corner is `growth` inside the hole's. It stays clear of a fillet of radius r as long
    // as it is at least r away from the fillet's centre, which is r inside the hole's corner.
    for growth in stride(from: CGFloat(0), through: 20, by: 1) {
      let radius = BackdropShape.innerRadius(for: TileMetrics.cornerRadius + growth, growth: growth)
      let distance = (2 * (radius - growth) * (radius - growth)).squareRoot()
      #expect(radius <= growth || distance <= radius, "growth \(growth)")
    }
  }

  // MARK: From layouts

  @Test func slotsAreTheRectanglesOfVisibleLeavesAndTiles() {
    var tree = LayoutTree()
    let a = WindowID(1), b = WindowID(2), c = WindowID(3), tab = WindowID(4)
    let leafA = tree.dock(a, beside: tree.root, edge: .left)
    let leafB = tree.dock(b, beside: tree.root, edge: .right)
    let leafC = tree.dock(c, beside: leafB, edge: .bottom)
    tree.addToStack(tab, leaf: leafA)
    var layout = LayoutEngine.layout(
      tree, camera: tree.root, in: screen, isPresent: { _ in true },
      minimumSize: { $0 == c ? CGSize(width: 900, height: 600) : nil })
    #expect(layout.tiles.map(\.node) == [leafC])
    // In one order: the slots come in none, and rectangles can be hashed only since macOS 15.
    func sorted(_ rects: [CGRect]) -> [CGRect] { rects.sorted { ($0.minX, $0.minY) < ($1.minX, $1.minY) } }
    let expected = sorted([leafA, leafB, leafC].map { layout.nodeFrames[$0]! })
    #expect(sorted(BackdropShape.slots(of: layout, in: tree)) == expected)
    #expect(BackdropShape.slots(of: layout, in: tree).count == 3, "a stack of tabs is one slot")

    // A tab strip will take the top of the slot from the window; the slot stays whole.
    layout.windowFrames[tab]!.origin.y += 30
    layout.windowFrames[tab]!.size.height -= 30
    #expect(sorted(BackdropShape.slots(of: layout, in: tree)) == expected)
  }

  /// Whatever the tree, the camera and the gap: the surface covers every slot, keeps off the Desktop,
  /// stays on the display, counts nothing twice, and its outlines enclose exactly its area.
  @Test(arguments: Array<UInt64>(1...40)) func randomLayoutsAreCoveredExactly(seed: UInt64) {
    var random = SeededRandom(seed: seed)
    var tree = LayoutTree()
    for number in 1...UInt32(Int.random(in: 1...14, using: &random)) {
      let nodes = tree.preorder()
      let target = nodes[Int.random(in: 0..<nodes.count, using: &random)]
      tree.dock(WindowID(number), beside: target, edge: Edge.allCases[Int.random(in: 0..<4, using: &random)])
    }
    let absent = Set(tree.allWindows.filter { _ in Int.random(in: 0..<5, using: &random) == 0 })
    let gap = [0, 1, 5, 12, 12.6, 13, 30][Int.random(in: 0..<7, using: &random)] as CGFloat

    for camera in tree.preorder() {
      let layout = LayoutEngine.layout(
        tree, camera: camera, in: screen, options: LayoutOptions(gap: gap), isPresent: { !absent.contains($0) })
      let slots = BackdropShape.slots(of: layout, in: tree)
      let rects = BackdropShape.surface(
        slots: slots, growth: BackdropShape.growth(forGap: gap), within: layout.frame, avoiding: layout.desktopFrame)

      #expect(slots.count == layout.windowFrames.count + layout.tiles.count)
      #expect(rects.isEmpty == slots.allSatisfy { $0.area == 0 })
      for slot in slots {
        let covered = rects.map { $0.intersection(slot) }.filter { !$0.isNull }
        #expect(abs(area(covered) - slot.area) < 0.001, "slot \(slot) of camera \(camera)")
      }
      for (index, rect) in rects.enumerated() {
        #expect(screen.contains(rect))
        #expect(layout.desktopFrame.map { !rect.overlaps($0) } ?? true)
        #expect(rects[(index + 1)...].allSatisfy { !$0.overlaps(rect) })
      }
      let loops = BackdropShape.contours(of: rects)
      #expect(abs(loops.map(signedArea).reduce(0, +) - area(rects)) < 0.001)
      // Neighbours always meet: with every slot docked in one tree, only the Desktop can part them.
      if layout.desktopFrame == nil { #expect(loops.count <= 1, "camera \(camera): \(rects)") }
    }
  }
}
