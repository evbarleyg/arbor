import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// F02: what the controller asks the presenter to play, and that asking changes nothing else.
@Suite @MainActor struct TransitionTests {
  let screen = FakeWindowSystem.standardDisplay.frame
  let content = FakeWindowSystem.standardDisplay.visibleFrame.insetBy(dx: 12, dy: 12)

  /// [a | Desktop | b] with c floating on the Desktop. The transitions of the set-up are forgotten.
  func makeHarness(settings: Settings = Settings()) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", pid: 13, frame: CGRect(x: 520, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    // Docking pushed c about. Arbor returns a floating window to where the user last put it.
    h.system.userMove(c, to: CGRect(x: 520, y: 300, width: 400, height: 300))
    h.overlays.clearTransitions()
    return (h, a, b, c)
  }

  /// The only transition since the last `clearTransitions()`.
  func only(_ h: Harness, sourceLocation: SourceLocation = #_sourceLocation) -> Transition? {
    #expect(h.overlays.transitions.count == 1, sourceLocation: sourceLocation)
    return h.overlays.transitions.first
  }

  // MARK: Acceptance criterion 1: zoom, back, dock and close

  @Test func zoomingMovesEveryWindowThatIsDrawn() throws {
    let (h, a, b, c) = makeHarness()
    let (slotA, slotB, restC) = (h.frame(a)!, h.frame(b)!, h.frame(c)!)
    h.run("zoom \(a.rawValue)")
    let transition = try #require(only(h))
    #expect(transition.display == h.display && transition.frame == screen && transition.duration == 0.46)
    #expect(Set(transition.items.map(\.window)) == [a, b, c])

    #expect(transition[a]!.from == slotA && transition[a]!.to == content)
    #expect(transition[a]!.to == h.frame(a), "the stand-in ends where the real window is")
    // The others leave the way the plane goes: to the right, stretched as a is, not to the parking corner.
    #expect(transition[b]!.from == slotB && transition[c]!.from == restC)
    for window in [b, c] {
      let item = transition[window]!
      #expect(item.to.minX >= screen.maxX, "\(window)")
      #expect(abs(item.to.width - item.from.width * content.width / slotA.width) <= 1, "\(window)")
      #expect(item.to.minY == item.from.minY && item.to.height == item.from.height, "\(window)")
      #expect(h.controller.parked.contains(window))
    }
    #expect(transition[c]!.to.minX < transition[b]!.to.minX, "the Desktop is between a and b")
  }

  @Test func goingBackPlaysItInReverse() throws {
    let (h, a, b, c) = makeHarness()
    h.run("zoom \(a.rawValue)")
    let there = try #require(only(h))
    h.overlays.clearTransitions()
    h.run("back")
    let back = try #require(only(h))
    for window in [a, b, c] {
      #expect(back[window]!.from == there[window]!.to && back[window]!.to == there[window]!.from, "\(window)")
      #expect(back[window]!.to == h.frame(window))
    }
  }

  @Test func dockingTakesTheWindowToItsSlotWhileTheOthersMakeRoom() throws {
    let (h, a, b, c) = makeHarness()
    let before = [a: h.frame(a)!, b: h.frame(b)!, c: h.frame(c)!]
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let transition = try #require(only(h))
    for window in [a, b, c] {
      #expect(transition[window]!.from == before[window] && transition[window]!.to == h.frame(window), "\(window)")
    }
    #expect(transition[a]!.moves && transition[c]!.moves)
    #expect(!transition[b]!.moves, "b stays, but the stage covers it, so it is drawn")
  }

  @Test func closingAWindowLetsTheOthersGlideIntoItsSpace() throws {
    let (h, a, b, c) = makeHarness()
    let before = [a: h.frame(a)!, c: h.frame(c)!]
    h.system.close(b)
    let transition = try #require(only(h))
    #expect(transition[b] == nil)
    #expect(transition[a]!.from == before[a] && transition[a]!.to == h.frame(a))
    #expect(transition[a]!.to.width > transition[a]!.from.width)
    #expect(transition[c]!.from == before[c] && transition[c]!.to == h.frame(c))
  }

  @Test func closingTheFramedWindowBringsTheNextOneIn() throws {
    let (h, a, _, c) = makeHarness()
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("zoom \(c.rawValue)")
    h.overlays.clearTransitions()
    h.system.close(c)
    let transition = try #require(only(h))
    #expect(transition.items.map(\.window) == [a])
    #expect(transition[a]!.from.maxY <= screen.minY, "a was above c on the plane")
    #expect(transition[a]!.to == content && h.frame(a) == content)
  }

  // MARK: Acceptance criteria 2 and 3: off means off, and on changes nothing but the picture

  /// A journey through everything that moves windows. Returns every frame Arbor set, in order.
  func journey(_ settings: Settings) -> (Harness, [String]) {
    let (h, a, b, c) = makeHarness(settings: settings)
    let big = h.system.open(app: "Xcode", frame: CGRect(x: 400, y: 200, width: 700, height: 500))
    h.system.setMinimumSize(big, CGSize(width: 900, height: 600))
    h.run("zoom \(a.rawValue)")
    h.run("back")
    h.run("dock \(big.rawValue) beside \(b.rawValue) bottom")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("neighbor right")
    h.run("zoom \(c.rawValue)")
    h.run("neighbor up")
    h.run("out")
    h.run("desktop")
    h.run("show-all")
    h.overlays.clickTile(h.workspace.tree.leaf(containing: big)!)
    h.run("show-all")
    h.overlays.dragSeam(h.overlays.seams[h.display]![0], by: 40)
    h.run("resize \(a.rawValue) right 60")
    h.system.setMinimized(c, true)
    h.system.setMinimized(c, false)
    h.run("float \(c.rawValue)")
    let start = h.frame(c)!
    h.system.drag(c, through: [CGPoint(x: start.midX, y: start.minY + 10), CGPoint(x: 700, y: 400), CGPoint(x: 1437, y: 450)])
    h.system.userMove(a, to: CGRect(x: 500, y: 300, width: 300, height: 300))
    h.scheduler.runPending()
    h.run("zoom \(b.rawValue)")
    h.system.userFocus(a)
    h.system.close(b)
    h.run("arrange")
    h.run("zoom \(a.rawValue)")
    h.run("float-all")
    h.controller.shutdown()
    return (h, h.system.frameLog.map { "\($0.window) \($0.frame)" })
  }

  @Test func withADurationOfZeroNoTransitionIsProduced() {
    var settings = Settings()
    settings.animationDuration = 0
    let (h, _) = journey(settings)
    #expect(h.overlays.transitions.isEmpty)
  }

  @Test func windowsGoTheSameWayWithAndWithoutAnimation() {
    var off = Settings()
    off.animationDuration = 0
    let (animated, moves) = journey(Settings())
    let (instant, plainMoves) = journey(off)
    #expect(animated.overlays.transitions.count > 15)
    #expect(moves == plainMoves, "the same frames, set in the same order")
    #expect(animated.system.focused == instant.system.focused)
    #expect(animated.workspace == instant.workspace)
    #expect(animated.overlays.scenes == instant.overlays.scenes)
  }

  @Test func theStageIsAskedForBeforeAnyWindowMoves() {
    let (h, a, b, c) = makeHarness()
    let before = [a: h.frame(a)!, b: h.frame(b)!, c: h.frame(c)!]
    var checked = false
    h.overlays.onAnimate = { _ in
      checked = true
      for (window, frame) in before { #expect(h.frame(window) == frame, "\(window) has moved already") }
    }
    h.run("zoom \(a.rawValue)")
    #expect(checked)
    #expect(h.frame(a) != before[a])
  }

  // MARK: What is applied at once

  @Test func aWindowThatIsFloatedGlidesOutOfItsSlotToItsOwnSize() throws {
    let (h, a, b, _) = makeHarness()
    let (slot, moved) = (h.frame(a)!, h.system.frameLog.count)
    var movedByThen: Int?
    h.overlays.onAnimate = { _ in movedByThen = movedByThen ?? h.system.frameLog.count }
    #expect(h.run("float \(a.rawValue)").ok)
    #expect(movedByThen == moved, "the command puts it back itself (F48), but not before the stage is up")
    let transition = try #require(h.overlays.transitions.first)
    #expect(transition[a]?.from == slot && transition[a]?.to == h.frame(a))
    #expect(h.frame(a)?.size == CGSize(width: 600, height: 400), "the size it had before it was docked")
    #expect(transition[b]?.to == h.frame(b))
  }

  @Test func aPinnedWindowIsBroughtBackIntoViewOnStageLikeAnyOther() throws {
    let (h, a, _, c) = makeHarness()
    #expect(h.run("pin \(c.rawValue)").ok)
    // Pushed nearly off the display by hand: the next layout brings it back.
    let pushed = CGRect(x: 1400, y: 300, width: 400, height: 300)
    h.system.userMove(c, to: pushed)
    h.overlays.clearTransitions()
    let moved = h.system.frameLog.count
    var movedByThen: Int?
    h.overlays.onAnimate = { _ in movedByThen = movedByThen ?? h.system.frameLog.count }
    h.run("zoom \(a.rawValue)")
    #expect(movedByThen == moved, "making the plan moves nothing")
    let item = try #require(h.overlays.transitions.first?[c])
    #expect(item.from == pushed && item.to == h.frame(c))
    #expect(screen.contains(item.to) && !h.controller.parked.contains(c), "it stays in view")
    #expect(h.system.frameLog.dropFirst(moved).filter { $0.window == c }.count == 1, "and is moved once")
  }

  @Test func seamDragsFollowTheMouseWithoutAnimation() {
    let (h, a, _, _) = makeHarness()
    let width = h.frame(a)!.width
    for _ in 0..<5 { h.overlays.dragSeam(h.overlays.seams[h.display]![0], by: 20) }
    #expect(abs(h.frame(a)!.width - (width + 100)) <= 1)
    #expect(h.overlays.transitions.isEmpty)
  }

  @Test func puttingAWindowBackIsNotAnimated() {
    let (h, a, _, _) = makeHarness()
    let slot = h.frame(a)!
    let dropped = h.overlays.finishedAnimations
    h.system.userMove(a, to: CGRect(x: 500, y: 300, width: 300, height: 300))
    h.scheduler.runPending()
    #expect(h.frame(a) == slot)
    #expect(h.overlays.transitions.isEmpty)
    #expect(h.overlays.finishedAnimations == dropped, "nor does it cut short a motion that leads to the same place")
  }

  @Test func startingUpIsNotAnimated() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.controller.saveNow()
    let again = Harness(saved: h.store.saved)
    for window in h.system.allWindows() {
      // As a crash would leave them: nothing is where the saved arrangement wants it.
      again.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid,
        frame: CGRect(x: 200, y: 200, width: 500, height: 300))
    }
    again.start()
    #expect(!again.system.frameLog.isEmpty)
    #expect(again.overlays.transitions.isEmpty)
  }

  @Test func spaceSwitchesAreNotAnimatedAndEndAMotionUnderWay() {
    let (h, a, b, _) = makeHarness()
    let dropped = h.overlays.finishedAnimations
    h.system.setOnActiveSpace(b, false)
    h.scheduler.runPending()
    #expect(h.frame(a)!.width > 464)
    #expect(h.overlays.transitions.isEmpty)
    #expect(h.overlays.finishedAnimations > dropped)
  }

  @Test func displayChangesAreNotAnimatedAndEndAMotionUnderWay() {
    let (h, a, _, _) = makeHarness()
    let dropped = h.overlays.finishedAnimations
    var smaller = FakeWindowSystem.standardDisplay
    smaller.frame.size = CGSize(width: 1280, height: 800)
    smaller.visibleFrame.size = CGSize(width: 1280, height: 775)
    h.system.setDisplays([smaller])
    #expect(h.frame(a)!.height == 751)
    #expect(h.overlays.transitions.isEmpty)
    #expect(h.overlays.finishedAnimations > dropped)
    // The next change is animated again, on the display as it is now.
    h.run("zoom \(a.rawValue)")
    #expect(h.overlays.transitions.first?.frame == smaller.frame)
  }

  @Test func settingsAreAppliedAtOnce() {
    let (h, a, _, _) = makeHarness()
    var settings = h.controller.settings
    settings.gap = 30
    h.controller.apply(settings: settings)
    #expect(h.frame(a)!.minX == 30)
    #expect(h.overlays.transitions.isEmpty)
  }

  @Test func quittingDropsTheStageBeforeItPutsWindowsBack() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.overlays.clearTransitions()
    let dropped = h.overlays.finishedAnimations
    h.controller.shutdown()
    #expect(h.overlays.finishedAnimations > dropped)
    #expect(h.overlays.transitions.isEmpty)
  }

  @Test func pausingDropsTheStageAndResumingIsNotAnimated() {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.overlays.clearTransitions()
    let dropped = h.overlays.finishedAnimations
    #expect(h.run("pause").ok)
    #expect(h.overlays.finishedAnimations > dropped)
    #expect(h.system.isVisible(b))
    #expect(h.run("resume").ok)
    #expect(!h.system.isVisible(b), "the arrangement is back")
    #expect(h.overlays.transitions.isEmpty, "neither way is played")
    // From here on things move as before.
    h.run("back")
    #expect(h.overlays.transitions.count == 1)
  }

  // MARK: A click ends it (T42)

  @Test func aClickAnywhereEndsTheMotion() {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    let (dropped, frames) = (h.overlays.finishedAnimations, [h.frame(a), h.frame(b)])
    h.system.click()
    #expect(h.overlays.finishedAnimations == dropped + 1)
    #expect(h.overlays.transitions.count == 1, "nothing new is played")
    #expect([h.frame(a), h.frame(b)] == frames, "the windows were where they belong all along")
  }

  @Test func takingHoldOfAWindowEndsTheMotion() {
    let (h, a, _, c) = makeHarness()
    h.run("desktop")
    var dropped = h.overlays.finishedAnimations
    let grip = CGPoint(x: h.frame(c)!.midX, y: h.frame(c)!.minY + 10)
    h.system.drag(c, through: [grip, CGPoint(x: grip.x + 40, y: grip.y + 20)])
    #expect(h.overlays.finishedAnimations > dropped, "by its title bar")

    h.run("show-all")
    dropped = h.overlays.finishedAnimations
    var wider = h.frame(a)!
    wider.size.width += 50
    h.system.userResize(a, to: wider, release: false)
    #expect(h.overlays.finishedAnimations > dropped, "by its edge")
    dropped = h.overlays.finishedAnimations
    wider.size.width += 50
    h.system.userResize(a, to: wider, release: false)
    #expect(h.overlays.finishedAnimations == dropped, "the button went down once")
    h.system.releaseMouse()
  }

  @Test func aClickWhileArborIsPausedIsNobodysBusiness() {
    let (h, _, _, _) = makeHarness()
    #expect(h.run("pause").ok)
    let dropped = h.overlays.finishedAnimations
    h.system.click()
    #expect(h.overlays.finishedAnimations == dropped)
  }

  @Test func nothingIsPlayedWhenNothingMoves() {
    let (h, a, _, _) = makeHarness()
    #expect(h.run("show-all").ok)
    #expect(h.run("relayout").ok)
    #expect(h.run("save-view 1").ok)
    h.system.userFocus(a)
    #expect(h.overlays.transitions.isEmpty)
  }

  @Test func nothingIsPlayedWhileTheUserHoldsAWindow() {
    let (h, a, b, c) = makeHarness()
    // b closes while c is being dragged: a takes the space at once, under the window in the user's hand.
    h.system.mouseDown = true
    h.system.heldModifiers = DragDocks.key
    h.controller.dragBegan(c, at: h.frame(c)!.center)
    h.system.close(b)
    #expect(h.frame(a)!.width > 464)
    #expect(h.overlays.transitions.isEmpty)
    h.system.mouseDown = false
    h.controller.dragEnded(c, at: h.layout!.desktopFrame!.center)

    // The same while a docked window is being resized by its edge.
    var wider = h.frame(a)!
    wider.size.width += 50
    h.system.userResize(a, to: wider, release: false)
    h.system.setMinimized(c, true)
    h.system.setMinimized(c, false)
    #expect(h.overlays.transitions.isEmpty)
  }

  // MARK: Everything else that is deliberate

  @Test func aDroppedWindowGlidesFromWhereItWasDropped() throws {
    let (h, _, b, c) = makeHarness()
    let start = h.frame(c)!
    let target = h.frame(b)!
    h.system.drag(c, through: [CGPoint(x: start.midX, y: start.minY + 10), CGPoint(x: target.midX, y: target.maxY - 20)])
    let transition = try #require(only(h))
    #expect(h.workspace.isDocked(c))
    let dropped = start.offsetBy(dx: target.midX - start.midX, dy: target.maxY - 20 - (start.minY + 10))
    #expect(transition[c]!.from == dropped && transition[c]!.to == h.frame(c))
    #expect(transition[b]!.from == target && transition[b]!.to == h.frame(b))
  }

  @Test func aWindowDroppedOnItsOwnSlotGlidesBack() throws {
    let (h, a, _, _) = makeHarness()
    let slot = h.frame(a)!
    h.system.drag(a, through: [CGPoint(x: slot.midX, y: slot.minY + 10), CGPoint(x: slot.midX + 30, y: slot.midY)])
    let transition = try #require(only(h))
    #expect(transition[a]!.from == slot.offsetBy(dx: 30, dy: slot.midY - slot.minY - 10))
    #expect(transition[a]!.to == slot)
  }

  @Test func minimizingAndRestoringAreAnimated() throws {
    let (h, a, b, _) = makeHarness()
    let (slotA, slotB) = (h.frame(a)!, h.frame(b)!)
    h.system.setMinimized(b, true)
    let away = try #require(only(h))
    #expect(away[b] == nil, "macOS shows the window going into the Dock")
    #expect(away[a]!.from == slotA && away[a]!.to == h.frame(a) && away[a]!.moves)

    h.overlays.clearTransitions()
    h.system.setMinimized(b, false)
    let back = try #require(only(h))
    #expect(back[b]!.from == slotB && back[b]!.to == slotB, "it reappears where it was")
    #expect(back[a]!.to == slotA)
  }

  @Test func releasingAnEdgeLetsTheNeighbourGlide() throws {
    let (h, a, _, c) = makeHarness()
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.overlays.clearTransitions()
    var taller = h.frame(a)!
    let below = h.frame(c)!
    taller.size.height += 80
    h.system.userResize(a, to: taller)
    let transition = try #require(only(h))
    #expect(!transition[a]!.moves, "the window the user resized is where they left it")
    #expect(transition[c]!.from == below && transition[c]!.to == h.frame(c))
    #expect(transition[c]!.to.minY == below.minY + 80)
  }

  @Test func floatingEverythingBringsBackWhatWasOutOfView() throws {
    let (h, a, b, c) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.overlays.clearTransitions()
    h.run("float-all")
    let transition = try #require(only(h))
    for window in [b, c] {
      #expect(transition[window]!.from.minX >= screen.maxX, "\(window)")
      #expect(transition[window]!.to == h.frame(window) && h.system.isVisible(window), "\(window)")
    }
    #expect(h.controller.parked.isEmpty)
  }

  @Test func aRuleThatDocksANewWindowIsAnimated() throws {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.terminal", action: .dock(.right))]
    let (h, _, b, _) = makeHarness(settings: settings)
    let opened = CGRect(x: 600, y: 300, width: 500, height: 300)
    let fresh = h.system.open(app: "Terminal", frame: opened)
    let transition = try #require(only(h))
    #expect(transition[fresh]!.from == opened && transition[fresh]!.to == h.frame(fresh))
    #expect(transition[b]!.moves)
  }

  // MARK: Tiles

  @Test func aRefusedSlotRetargetsTheMotion() throws {
    let (h, _, b, _) = makeHarness()
    let opened = CGRect(x: 400, y: 200, width: 700, height: 500)
    let big = h.system.open(app: "Xcode", frame: opened)
    h.system.setMinimumSize(big, CGSize(width: 1250, height: 700))
    h.run("dock \(big.rawValue) beside \(b.rawValue) bottom")
    try #require(h.overlays.transitions.count == 2)
    let (hoped, corrected) = (h.overlays.transitions[0], h.overlays.transitions[1])
    let tile = try #require(h.layout?.tiles.first)

    // First the plan: into the slot as itself. Then what the app allowed: a tile in that slot.
    #expect(hoped[big] == Transition.Item(window: big, from: opened, to: tile.frame, pid: 1000, bundleID: "com.example.xcode"))
    #expect(corrected[big]!.from == opened && corrected[big]!.to == tile.frame)
    #expect(corrected[big]!.fromLook == .picture && corrected[big]!.toLook == .cover)
    #expect(corrected[b] == hoped[b])
    #expect(corrected[b]!.to == h.frame(b))

    // Now that its minimum is known, nothing needs correcting.
    h.overlays.clearTransitions()
    h.run("zoom \(b.rawValue)")
    h.run("back")
    try #require(h.overlays.transitions.count == 2)
    #expect(h.overlays.transitions[1][big]?.toLook == .cover)
  }

  @Test func aWindowThatRoundsItsSizeEndsWhereItReallyIs() throws {
    let (h, _, _, c) = makeHarness()
    // Like a terminal, or a window with a maximum size: it takes the position but not all of the slot.
    h.system.setMaximumSize(c, CGSize(width: 300, height: 2000))
    h.run("dock \(c.rawValue) right")
    try #require(h.overlays.transitions.count == 2)
    #expect(h.overlays.transitions[0][c]!.to == h.layout!.windowFrames[c])
    #expect(h.overlays.transitions[1][c]!.to == h.frame(c))
    #expect(h.frame(c)!.width == 300 && h.layout!.windowFrames[c]!.width > 300)
  }

  @Test func aWindowKnownNotToFitIsPlannedWhereItWillEnd() throws {
    let (h, a, _, c) = makeHarness()
    h.system.setMaximumSize(c, CGSize(width: 300, height: 2000))
    h.run("dock \(c.rawValue) right")
    let resting = h.frame(c)!
    // Away and back to the same slot: Arbor knows by now where the window ends up in it.
    h.overlays.clearTransitions()
    h.run("zoom \(a.rawValue)")
    h.run("back")
    try #require(h.overlays.transitions.count == 2, "nothing had to be corrected")
    #expect(h.overlays.transitions[0][c]!.from == resting)
    #expect(h.overlays.transitions[1][c]!.to == resting && h.frame(c) == resting)
    // And while it stays there, a change elsewhere does not move its stand-in.
    h.overlays.clearTransitions()
    h.run("resize \(a.rawValue) right 40")
    h.run("resize \(a.rawValue) right -40")
    #expect(h.overlays.transitions.count == 2)
  }

  @Test func clickingATileUnfoldsIt() throws {
    var settings = Settings()
    settings.minimumUsableWidth = 500
    let (h, a, b, c) = makeHarness(settings: settings)
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let group = try #require(h.layout?.tiles.first { $0.kind == .group })
    h.overlays.clearTransitions()
    h.overlays.clickTile(group.node)
    let transition = try #require(only(h))
    for window in [a, c] {
      let item = transition[window]!
      #expect(item.from == group.miniature[window] && item.fromLook == .cover, "\(window)")
      #expect(item.to == h.frame(window) && item.toLook == .picture, "\(window)")
    }
    #expect(transition[b]!.fromLook == .cover && transition[b]!.toLook == .cover)
    #expect(transition[b]!.to.minX >= screen.maxX)
  }

  // MARK: What the presenter needs besides frames

  @Test func itemsSayWhoseWindowTheyStandFor() throws {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    let transition = try #require(only(h))
    #expect(transition[a]!.pid == 11 && transition[a]!.bundleID == "com.example.safari")
    #expect(transition[b]!.pid == 12 && transition[b]!.bundleID == "com.example.notes")
  }

  @Test func standInsAreStackedLikeTheWindows() throws {
    let (h, a, b, c) = makeHarness()
    h.system.userFocus(c)
    h.system.userFocus(a)
    h.run("out")  // fails: nothing to step out to, so nothing is focused or moved
    h.run("desktop")
    #expect(try #require(only(h)).items.map(\.window) == [b, c, a], "back to front")
  }

  @Test func windowsArborDoesNotArrangeAreDrawnWhereTheyAre() throws {
    var settings = Settings()
    settings.excludedBundleIDs = ["com.example.player"]
    let (h, a, _, _) = makeHarness(settings: settings)
    let frame = CGRect(x: 900, y: 500, width: 400, height: 300)
    let player = h.system.open(app: "Player", frame: frame)
    let minimized = h.system.open(app: "Player", frame: frame)
    h.system.setMinimized(minimized, true)
    h.run("zoom \(a.rawValue)")
    let transition = try #require(only(h))
    #expect(transition[player]!.from == frame && transition[player]!.to == frame)
    #expect(transition[minimized] == nil)
    #expect(h.frame(player) == frame)
  }

  @Test func eachDisplayHasItsOwnTransition() throws {
    let second = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, second])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 1700, y: 200, width: 600, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 1800, y: 300)
    h.run("dock \(b.rawValue) left")
    h.run("dock \(c.rawValue) right")
    h.overlays.clearTransitions()
    h.run("zoom \(b.rawValue)")
    let transition = try #require(only(h))
    #expect(transition.display == second.id && transition.frame == second.frame)
    #expect(Set(transition.items.map(\.window)) == [b, c], "\(a) is on the other display")
    #expect(transition[c]!.to.minX >= second.frame.maxX)
  }

  @Test func theDurationComesFromTheSettings() throws {
    var settings = Settings()
    settings.animationDuration = 0.2
    let (h, a, _, _) = makeHarness(settings: settings)
    h.run("zoom \(a.rawValue)")
    #expect(try #require(only(h)).duration == 0.2)
    // Switched off while running: from the next change on there is nothing to play.
    settings.animationDuration = 0
    h.controller.apply(settings: settings)
    h.overlays.clearTransitions()
    h.run("back")
    #expect(h.overlays.transitions.isEmpty)
    settings.animationDuration = 5
    h.controller.apply(settings: settings)
    h.run("forward")
    #expect(try #require(only(h)).duration == 2, "two seconds at most")
  }
}
