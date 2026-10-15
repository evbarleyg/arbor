import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// The rules that compare what the controller believes with what the fakes saw: where windows
/// really are, what the overlays show, which timers are pending, what was saved. The rules about the
/// controller's own state are in `Controller.invariantViolations()`.
///
/// To add a rule: write `func <name>Violations(_ problems: inout [InvariantViolation])` in an extension of
/// `ChaosRunner` (this file or your feature's own) and call it in `check(after:)`. Give the rule a short name and
/// name the window, node or display in the message. The order of the problems does not matter: they are sorted.
extension ChaosRunner {
  /// Timers the controller may have pending, by prefix. A key that matches none has leaked.
  static let knownTimers = ["save", "undo-continuation", "enforce-", "space-", "resume", "focus", "rule-title-", "pending-slots", "peek", "raise-pins",
    "settings-file", "update-check", "summon-wait", "accessibility",
    "landed-", "drag-dwell", "sole-float-after-launch", "layout-open ", "release", "call-over",
    "events", "control-connection-",
    "heads-up", "minimap-",
    "displays-blinked", "menu-bar",
    "back-from-full-screen",
    "desktop-guard-zones",
    "left-to-macos",
    "rehearsal",
  ]

  /// How far a docked window may sit from its slot: 4 points of the app rounding its size
  /// (docs/ARCHITECTURE.md, "Echo suppression") on top of the 1 point `relayout` leaves alone.
  static let slotTolerance: CGFloat = 5

  func check(after action: ChaosAction) -> [InvariantViolation] {
    let timers = harness.scheduler.pendingKeys
    // A Space switch is laid out once all of its reports are in (Controller+Spaces.swift).
    let awaitingLayout = timers.isEmpty ? [] : Set(controller.displays.map(\.id).filter { timers.contains("space-" + $0.rawValue) })
    let awaitingPutBack = timers.isEmpty ? [] : Set(controller.displays.map(\.id).filter { timers.contains("enforce-" + $0.rawValue) })
    var inside = controller.invariantViolations(awaitingLayout: awaitingLayout, awaitingPutBack: awaitingPutBack)
    // A rule name of its own for a known failure (ChaosKnownFailures.swift), so that the rule still guards everything else.
    for index in inside.indices where inside[index].rule == "tree" && inside[index].message.contains(" has weight ") {
      inside[index].rule = "tree-weight"
    }
    // The same for a layout that a peek left behind.
    staleSinceAPeek = inside.contains { $0.rule == "stale-layout" } && (staleSinceAPeek || wasPeekingBefore)
    if staleSinceAPeek {
      for index in inside.indices where inside[index].rule == "stale-layout" { inside[index].rule = "stale-layout-after-peek" }
    }
    // It lasts until something lays the display out.
    staleSinceADrop = inside.contains { $0.rule == "stale-layout" } && (staleSinceADrop || action == .release)
    if staleSinceADrop {
      for index in inside.indices where inside[index].rule == "stale-layout" { inside[index].rule = "stale-layout-after-drop" }
    }
    // The app registers `activeBindings` and its taps follow `inputSettings` only when it is told that they changed
    // (`Change.input`, `.lifecycle`, `.hold`, settings applied). Whatever changes either has to say so.
    if isRunning || isPaused, let told = toldBindings {
      let now = controller.activeBindings
      if told != now {
        let gone = told.filter { !now.contains($0) }.map(\.command.text), new = now.filter { !told.contains($0) }.map(\.command.text)
        inside.append(.init("registered", "the app holds \(told.count) shortcuts, Arbor wants \(now.count): too many \(gone.prefix(4)), missing \(new.prefix(4))"))
      }
      if toldInput != controller.inputSettings { inside.append(.init("taps", "the taps follow settings that are out of date")) }
    }
    guard isRunning else {
      // Quitting and pausing move more windows at once than anything else, each of them once.
      var jolts: [InvariantViolation] = []
      onceViolations(after: action, &jolts)
      afterQuitViolations(after: action, &jolts)
      return inside + jolts + (harness.overlays.finder == nil ? [] : [.init("palette", "Go to… is open and Arbor is paused or not running")])
    }
    var problems: [InvariantViolation] = []
    mirrorViolations(&problems)
    paletteViolations(after: action, &problems)
    // With `reflowWhileDragging` the other windows and the overlays try out the drop while the window is in the air (F09).
    let isTryingOutADrop = controller.draggedWindow != nil && controller.settings.reflowWhileDragging
    // What a trial finds out about a window's sizes is forgotten with the trial; until then nobody sees the resting layout.
    if isTryingOutADrop { inside.removeAll { $0.rule == "stale-layout" } }
    if !isTryingOutADrop {
      frameViolations(settled: action == .settle, &problems)
      overlayViolations(&problems)
      backdropViolations(&problems)
    }
    focusRingViolations(&problems)
    // A trial that shows the Desktop brings floating windows into view. Called off, they go again.
    // What a start takes out of view has a rule of its own, also where the start is part of a way back.
    if !isTryingOutADrop, !wasTryingOutADrop, action != .wayBack(.startAgain) { vanishedViolations(&problems) }
    pinViolations(&problems)
    nameViolations(&problems)
    undoViolations(after: action, &problems)
    holdViolations(&problems)
    guardZoneViolations(&problems)
    reachViolations(&problems)
    wholeViolations(&problems)
    restingPlaceViolations(after: action, &problems)
    sevenRulesViolations(after: action, &problems)
    timerViolations(settled: action == .settle, &problems)
    untouchedViolations(&problems)
    // Encoding is slow next to everything else, so a random run checks it now and then. A replay checks it at every step:
    // the failure then shows where it begins, and does not depend on how many steps came before, so it can be shrunk.
    if action == .save || checksFilesAtEveryStep || script.count % 64 == 0 { codableViolations(&problems) }
    return inside + (problems.isEmpty ? problems : problems.sorted { ($0.rule, $0.message) < ($1.rule, $1.message) })
  }

  /// Whether a timer is going to lay `display` out again: to put back what something else moved
  /// (once the mouse is up), or after a Space switch.
  private func isDueForLayout(_ display: DisplayID) -> Bool {
    let timers = harness.scheduler.pendingKeys
    guard !timers.isEmpty else { return false }
    // A window on its way back (from the Dock, full screen, a hidden app) is judged once it has landed (#150).
    return timers.contains("enforce-" + display.rawValue) || timers.contains("space-" + display.rawValue)
      || timers.contains("landed-" + display.rawValue)
  }

  /// Whether the window's app does what it is asked, within its size limits.
  func cooperates(_ fake: FakeWindowSystem.FakeWindow) -> Bool {
    (fake.behaviour == .normal || fake.behaviour == .grid) && !fake.changedItsWays && !system.unresponsive.contains(fake.snapshot.pid)
  }

  // MARK: Rules

  /// The controller's picture of the windows and displays is the window system's.
  func mirrorViolations(_ problems: inout [InvariantViolation]) {
    let (known, filter) = (controller.windows, controller.filter)
    for (id, fake) in system.windows {
      guard let snapshot = known[id] else {
        problems.append(.init("mirror", "\(id) exists but Arbor does not know it"))
        continue
      }
      if snapshot != fake.snapshot, filter.manages(fake.snapshot) {
        problems.append(
          .init("mirror", "\(id) is at \(fake.snapshot.frame.brief), Arbor thinks \(snapshot.frame.brief) (or its state differs)"))
      }
    }
    if known.count != system.windows.count {
      for id in known.keys where system.windows[id] == nil {
        problems.append(.init("mirror", "Arbor still knows \(id), which is gone"))
      }
    }
    if controller.displays != system.displayList {
      problems.append(.init("mirror", "Arbor sees displays \(controller.displays.map(\.id)), there are \(system.displayList.map(\.id))"))
    }
  }

  /// Where the windows really are: docked ones in their slots, parked ones out of view, and
  /// nothing that should be in view lost beyond the edges of every display.
  func frameViolations(settled: Bool, _ problems: inout [InvariantViolation]) {
    let dragged = controller.draggedWindow
    for display in controller.displays {
      guard let layout = controller.layouts[display.id] else { continue }
      let bounds = display.visibleFrame.insetBy(dx: -Self.slotTolerance, dy: -Self.slotTolerance)
      var shown: [(window: WindowID?, frame: CGRect)] = layout.tiles.map { (nil, $0.frame) }
      var tooLarge = Set<WindowID>()
      for (window, slot) in layout.windowFrames {
        guard let fake = system.windows[window], cooperates(fake), window != dragged else { continue }
        let actual = fake.snapshot.frame
        // In its slot, or where it ended up when Arbor asked for its slot (apps have size limits).
        var inPlace = actual.approximatelyEquals(slot, tolerance: Self.slotTolerance)
        var exactly = actual.approximatelyEquals(slot, tolerance: 1)
        var refused = false
        // A window that cannot grow to its slot is asked to sit in the middle of it.
        if !inPlace, let request = fake.lastRequest, slot.insetBy(dx: -1, dy: -1).contains(request.asked.origin) {
          inPlace = actual.approximatelyEquals(request.took, tolerance: Self.slotTolerance)
          exactly = actual == request.took
          refused = request.took.width > slot.width || request.took.height > slot.height
        }
        guard inPlace else {
          if controller.windowsLeftToTheirApps.contains(window) {
            // Arbor stops putting back a window that something keeps moving. Not one that was moved once or twice.
            if fake.movesNotArbors < 3 {
              problems.append(
                .init("given-up", "Arbor has given up on \(window), which something other than Arbor moved \(fake.movesNotArbors) times"))
            }
          } else if settled || !isDueForLayout(display.id) {
            problems.append(
              .init("slot", "\(window) on \(display.id) is at \(actual.brief), its slot is \(slot.brief), and nothing is going to put it back"))
          }
          continue
        }
        // A window nudged within the tolerance may lean a few points over a narrow gap.
        if exactly { shown.append((window, actual)) }
        if refused { tooLarge.insert(window) }
        if !refused, !bounds.contains(actual) {
          problems.append(
            .init("outside", "\(window) at \(actual.brief) leaves the visible frame \(display.visibleFrame.brief) of \(display.id)"))
        }
      }
      // A window up to 2 points larger than its slot is left there rather than made a tile.
      for (index, a) in shown.enumerated() where settled || !isDueForLayout(display.id) {
        for b in shown[(index + 1)...] where a.frame.insetBy(dx: 1, dy: 1).overlaps(b.frame.insetBy(dx: 1, dy: 1)) {
          let pair = [a, b].map { ($0.window.map { "\($0)" } ?? "a tile") + " at " + $0.frame.brief }.sorted()
          // A window whose app keeps it larger than its slot should have been given room or made a tile.
          let refused = [a.window, b.window].contains { $0.map(tooLarge.contains) == true }
          problems.append(.init(refused ? "overlap-too-large" : "overlap", "\(pair[0]) and \(pair[1]) overlap on \(display.id)"))
        }
      }
    }

    let (displays, filter, parked) = (system.displayList, controller.filter, controller.parked)
    guard !displays.isEmpty else { return }
    for (id, fake) in system.windows {
      let snapshot = fake.snapshot
      guard snapshot.isPresent, id != dragged, cooperates(fake), filter.manages(snapshot) else { continue }
      // Parking leaves a sliver on screen, a point or two wide.
      let showing = displays.lazy.map { snapshot.frame.intersection($0.frame) }
        .first { !$0.isNull && $0.width > 2 && $0.height > 2 }
      if parked.contains(id) {
        guard let showing else { continue }
        let home = controller.workspaceID(containing: id)
        // Something else moved it into view: like a docked window, it is put back by a timer.
        if !settled, let home, isDueForLayout(home) { continue }
        // Hemmed in by other displays, it goes where least of it shows, which is not nothing.
        guard let home = displays.first(where: { $0.id == home }),
          Self.area(of: snapshot.frame, showingOn: displays)
            > leastThatMustShow(of: snapshot.frame.size, parkedAround: home, stoppedBy: system.whereMacOSPuts) + 1
        else { continue }
        var rule = "parked-in-view"
        if !fake.placeIsArborsDoing {
          // A nudge within the tolerance for docked windows is left alone here too.
          if showing.width <= 8 || showing.height <= 8 { continue }
          rule = "parked-not-put-back"
        } else if displays.contains(where: {
          $0.id != home.id
            && Self.area(of: snapshot.frame, showingOn: displays)
              <= leastThatMustShow(of: snapshot.frame.size, parkedAround: $0, stoppedBy: system.whereMacOSPuts) + 1
        }) {
          // It went out of view beside one display and has since been docked on another.
          rule = "parked-beside-another-display"
        } else if let asked = fake.lastRequest?.asked {
          // macOS stops a window before its title bar goes under the bottom of a display. `parkingOrigin` takes that to be
          // the window's own display, the fake the one nearest the window's corner. Arbor chose well by its own lights.
          func stop(_ frame: CGRect) -> CGRect {
            CGRect(x: frame.minX, y: min(frame.minY, home.visibleFrame.maxY - 32), width: frame.width, height: frame.height)
          }
          if Self.area(of: stop(asked), showingOn: displays) <= leastThatMustShow(of: asked.size, parkedAround: home, stoppedBy: stop) + 1 {
            rule = "parked-stopped-short"
          }
        }
        problems.append(.init(rule, "\(id) is parked at \(snapshot.frame.brief), and \(showing.brief) of it shows"))
      } else if showing == nil, fake.placeIsArborsDoing, snapshot.frame.width > 4, snapshot.frame.height > 4 {
        if !settled, let home = controller.workspaceID(containing: id), isDueForLayout(home) { continue }
        problems.append(.init("lost", "\(id) is not parked but is at \(snapshot.frame.brief), off every display"))
      }
    }
  }

  /// How much of a window of this size shows at the best of the places around its display: the bottom corners, below the
  /// bottom edge and beside both edges, each judged by where macOS would let the window stop.
  private func leastThatMustShow(
    of size: CGSize, parkedAround display: DisplaySnapshot, stoppedBy stop: (CGRect) -> CGRect
  ) -> CGFloat {
    let frame = display.frame
    var least = CGFloat.infinity
    for x in [frame.maxX - 1, frame.minX - size.width + 1, frame.minX] {
      for y in [frame.maxY - 1, frame.minY] {
        let stopped = stop(CGRect(x: x, y: y, width: size.width, height: size.height))
        least = min(least, Self.area(of: stopped, showingOn: system.displayList))
      }
    }
    return least
  }

  /// Displays do not overlap, so what they show adds up.
  static func area(of frame: CGRect, showingOn displays: [DisplaySnapshot]) -> CGFloat {
    displays.reduce(0) { $0 + frame.intersection($1.frame).area }
  }

  /// Whether some display shows more of `frame` than the sliver, a point or two wide, that parking leaves.
  func isInView(_ frame: CGRect) -> Bool {
    system.displayList.contains {
      let showing = frame.intersection($0.frame)
      return !showing.isNull && showing.width > 2 && showing.height > 2
    }
  }

  /// The overlays show the current layout, and the drop preview only during a drag.
  func overlayViolations(_ problems: inout [InvariantViolation]) {
    let scenes = harness.overlays.scenes
    for display in controller.displays {
      let expected = controller.expectedTilesAndSeams(on: display.id)
      if scenes[display.id]?.tiles != expected?.tiles || scenes[display.id]?.seams != expected?.seams {
        problems.append(.init("overlays", "the tiles and seams drawn on \(display.id) are not the ones its layout calls for"))
      }
    }
    if scenes.count != controller.displays.count {
      for (id, scene) in scenes where controller.display(id) == nil && scene != OverlayScene() {
        problems.append(.init("overlays", "something is still drawn on \(id), which is gone"))
      }
    }
    if controller.draggedWindow == nil, let preview = harness.overlays.preview {
      problems.append(.init("preview", "a drop preview is showing at \(preview.brief) and nothing is being dragged"))
    }
  }

  /// The surface behind docked windows (F15) is the one the layout calls for; it lies behind everything docked that is in
  /// view and behind every tile, keeps off the Desktop and inside the display, and its parts do not overlap. And
  /// whatever a tile is made of stays inside the tile.
  func backdropViolations(_ problems: inout [InvariantViolation]) {
    for display in controller.displays {
      guard let layout = controller.layouts[display.id] else { continue }
      let drawn = harness.overlays.scenes[display.id]
      if drawn?.backdrop != controller.expectedScene(on: display.id)?.backdrop {
        problems.append(.init("backdrop", "the surface drawn on \(display.id) is not the one its layout calls for"))
      }
      for tile in drawn?.tiles ?? [] {
        let bounds = CGRect(origin: .zero, size: tile.frame.size)
        for isDark in [false, true] {
          let art = TileArt(tile, isDark: isDark) { _ in RGBA(red: 0.2, green: 0.4, blue: 0.9) }
          let parts =
            art.cells.map(\.frame) + art.icons.map(\.frame) + [art.glyph?.frame, art.caption?.frame, art.badge?.frame].compactMap { $0 }
          for part in parts where !part.isFiniteRect || !bounds.insetBy(dx: -0.5, dy: -0.5).contains(part) {
            problems.append(.init("tile-art", "a part of the tile of \(tile.node) at \(part.brief) leaves the tile, \(bounds.brief)"))
          }
        }
      }
      guard let backdrop = drawn?.backdrop else { continue }
      let rects = backdrop.rects
      for (index, rect) in rects.enumerated() {
        if !rect.isFiniteRect || rect.isEmpty { problems.append(.init("backdrop", "a part of the surface on \(display.id) is \(rect)")) }
        if !layout.frame.insetBy(dx: -0.5, dy: -0.5).contains(rect) {
          problems.append(.init("backdrop", "the surface on \(display.id) leaves the display's visible frame at \(rect.brief)"))
        }
        if let desktop = layout.desktopFrame, rect.overlaps(desktop) {
          problems.append(.init("backdrop", "the surface on \(display.id) covers the Desktop at \(rect.brief)"))
        }
        for other in rects[(index + 1)...] where rect.overlaps(other) {
          problems.append(.init("backdrop", "two parts of the surface on \(display.id) overlap: \(rect.brief) and \(other.brief)"))
        }
      }
      for slot in Array(layout.windowFrames.values) + layout.tiles.map(\.frame) {
        var wanted = slot.intersection(layout.frame)
        guard !wanted.isNull, wanted.width >= 1, wanted.height >= 1 else { continue }
        // The Desktop comes first where a slot reaches into it.
        if let desktop = layout.desktopFrame, wanted.overlaps(desktop) { continue }
        wanted = wanted.insetBy(dx: 0.5, dy: 0.5)
        let covered = rects.map { $0.intersection(wanted) }.filter { !$0.isNull }.map { $0.width * $0.height }.reduce(0, +)
        if abs(covered - wanted.width * wanted.height) > 1 {
          problems.append(.init("backdrop", "the surface on \(display.id) has a hole behind \(slot.brief)"))
        }
      }
    }
  }

  /// A floating window the user can see goes out of view only when the user looks elsewhere: the camera of its
  /// display moves. Docking, closing, minimizing or restoring some other window must not take it away,
  /// however small that leaves the Desktop.
  func vanishedViolations(_ problems: inout [InvariantViolation]) {
    // A window that comes back (from another Space, the Dock, a hidden app) while the Desktop is out of view is where it was when it
    // went, and follows the Desktop out of view with the next layout, whenever that is.
    for (id, fake) in system.windows where fake.snapshot.isPresent && !presentBefore.contains(id) { cameBack.insert(id) }
    if !cameBack.isEmpty {
      cameBack = cameBack.filter { window in
        guard system.windows[window] != nil, !controller.parked.contains(window) || !parkedBefore.contains(window),
          let display = controller.workspaceID(containing: window)
        else { return false }
        return controller.layouts[display]?.desktopFrame == nil
      }
    }
    guard wasRunningBefore, controller.parked.count > 0, controller.displays == displaysBefore else { return }
    for window in controller.parked.subtracting(parkedBefore) {
      guard let display = controller.workspaceID(containing: window), let now = controller.workspaces[display],
        let before = workspacesBefore[display], now.isFloating(window), before.isFloating(window),
        // A summoned window is sent away again, by the same command or by turning to another window (F53).
        !now.isStashed(window),
        // The camera can be on a window of a hidden app, so that more is shown; `find` brings the app back, and the view is on it again.
        Self.isStillLookingThere(before, now, showsTheSame: controller.layouts[display]?.camera == viewsBefore[display]),
        let fake = system.windows[window],
        fake.snapshot.isPresent, presentBefore.contains(window), cooperates(fake), !cameBack.contains(window),
        // Its app hung while the camera moved: it follows when the app answers again.
        !owedAMoveBefore.contains(window),
        // Really: it could be seen, and now it cannot.
        let frameBefore = framesBefore[window], isInView(frameBefore), !isInView(fake.snapshot.frame),
        // What was on screen was not waiting to catch up with a camera that had moved before.
        !timersBefore.contains("space-" + display.rawValue)
      else { continue }
      // `showsOnlyASliver` goes by the share of the window that shows, so a strip of a large window counts as nothing.
      let strip = Self.area(of: frameBefore, showingOn: system.displayList) < 0.02 * frameBefore.area
      problems.append(
        .init(
          strip ? "vanished-strip" : "vanished",
          "\(window) was floating in view on \(display) at \(frameBefore.brief) and went out of view, and the camera has not moved"))
    }
  }

  /// Whether the user looks where they looked before, as far as floating windows go. The camera is on the same space: its
  /// number alone does not say so, because `layout` and `arrange` start a tree that numbers from 1 again, and an undo
  /// brings the old one back. Or it has moved, or the tree is another, and the Desktop is part of the view as it
  /// was before: then its windows are in view as they were, be it as small as a tile.
  private static func isStillLookingThere(_ before: Workspace, _ now: Workspace, showsTheSame: Bool) -> Bool {
    if now.camera == before.camera, before.tree.isSameNode(before.camera, in: now.tree), showsTheSame { return true }
    return before.tree.subtree(before.camera, contains: before.tree.desktop)
      && now.tree.subtree(now.camera, contains: now.tree.desktop)
  }

  /// Where Arbor puts a window that is meant to be in view, a person can get hold of it: forty points of its title bar are on a display.
  /// At the step in which Arbor moved it, so that the script ends with the move. (`out-of-reach` asks the same after each way back.)
  func reachViolations(_ problems: inout [InvariantViolation]) {
    guard frameLogMark < system.frameLog.count else { return }
    let moved = Set(system.frameLog[frameLogMark...].map(\.window))
    for window in windowsOutOfReach() where moved.contains(window) && window != system.dragging && window != system.resizing {
      problems.append(
        .init("placed-out-of-reach", "Arbor put \(window) at \(system.windows[window]!.snapshot.frame.brief), where nobody can get hold of it, and does not count it as out of view"))
    }
  }

  /// No window that Arbor placed shows less than all of itself, unless its user put it there, on this display as it is (the
  /// product owner, 2026-10-14). Windows Arbor counts as out of view are another matter, and so is one that is larger than the display.
  func wholeViolations(_ problems: inout [InvariantViolation]) {
    guard frameLogMark < system.frameLog.count else { return }
    let rules = controller.settings.rules
    for window in Set(system.frameLog[frameLogMark...].map(\.window)).sorted() {
      guard let fake = system.windows[window], fake.snapshot.isPresent, !fake.snapshot.isFullScreen, cooperates(fake),
        controller.filter.manages(fake.snapshot), !controller.parked.contains(window),
        window != system.dragging, window != system.resizing,
        fake.lastRequest?.took == fake.snapshot.frame, !fake.groundHasShifted,
        AppRule.firstMatch(in: rules, bundleID: fake.snapshot.bundleID, title: fake.snapshot.title)?.action != .ignore
      else { continue }
      let frame = fake.snapshot.frame
      guard Self.area(of: frame, showingOn: system.displayList) < 0.995 * frame.area, !fake.changedItsWays,
        let display = Self.display(showingMostOf: frame, among: system.displayList),
        // It can be made to fit.
        fake.minimumSize.width <= display.visibleFrame.width, fake.minimumSize.height <= display.visibleFrame.height,
        // Left hanging over an edge, it may hang as far when Arbor makes room beside it or gives it another size.
        !(userPlaces[window] ?? []).contains(where: { $0.allows(frame, on: display) })
      else { continue }
      let share = Int((100 * Self.area(of: frame, showingOn: system.displayList) / frame.area).rounded())
      // A rule name of its own for a docked window that is kept larger than its slot and hangs out of the display on that account.
      let floats = controller.workspaces.values.contains { $0.isFloating(window) }
      // And for one that its user left hanging and that Arbor has made larger there: as much of it shows as its user left showing.
      let showsAsMuch = (userPlaces[window] ?? []).contains {
        $0.isOn(display) && Self.area(of: frame, showingOn: system.displayList) >= $0.showing - 1
      }
      // The product owner's blocker: its user had it wholly in view, never across an edge, and less than half of it shows now.
      // Or across the border of two displays, where all of it showed: that is no window left hanging.
      let showingNow = Self.area(of: frame, showingOn: system.displayList)
      let leastEverLeftShowing = (userPlaces[window] ?? []).map(\.showing).min()
      let neverLeftHanging = !leftAcrossAnEdge.contains(window) || (leastEverLeftShowing.map { $0 >= 0.995 * frame.area } ?? false)
      let mostlyOut = floats && neverLeftHanging && showingNow < 0.5 * frame.area
      problems.append(
        .init(!floats ? "docked-partly-out" : mostlyOut ? "placed-mostly-out" : showsAsMuch ? "grown-while-hanging" : "placed-partly-out", "Arbor put \(window) at \(frame.brief), \(share) % of it on a display, and nobody had left it there on \(display.id) as it is"))
    }
  }

  /// A floating window keeps its place relative to its display's corner across a change of displays in which that display stays as
  /// large as it was, unless somebody moved it meanwhile (K1811, the lid). Also later: a frame remembered in the old coordinates is
  /// applied by the next layout that places floating windows, so the rule looks on through time and through moves of the camera.
  func restingPlaceViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    guard !restingPlaces.isEmpty else { return }
    switch action {
    case .displays, .advance, .flush, .settle, .launch, .crash, .cursor,
      .command("home"), .command("relayout"), .command("desktop"), .command("show-all"), .command("back"), .command("forward"):
      break
    default:
      restingPlaces = [:]
      return
    }
    let timers = harness.scheduler.pendingKeys
    guard !timers.contains(where: { key in ["space-", "enforce-", "landed-", "displays-blinked"].contains { key.hasPrefix($0) } }) else { return }
    for (window, place) in restingPlaces.sorted(by: { $0.key < $1.key }) {
      guard let fake = system.windows[window], fake.movesNotArbors == place.moves, fake.snapshot.isPresent, !fake.snapshot.isFullScreen,
        cooperates(fake), controller.filter.manages(fake.snapshot),
        controller.workspaces.values.contains(where: { $0.isFloating(window) && !$0.isStashed(window) })
      else {
        restingPlaces[window] = nil
        continue
      }
      guard !controller.parked.contains(window) else { continue }
      let frame = fake.snapshot.frame
      if fake.placeIsArborsDoing, abs(frame.minX - place.frame.minX) > 1 || abs(frame.minY - place.frame.minY) > 1 {
        restingPlaces[window] = nil
        // Its own display had gone and has come back: Arbor takes it home (F52).
        if let display = system.displayList.first(where: { $0.frame.contains(frame.center) }), !displaysBeforeTheChange.contains(display.id) {
          continue
        }
        problems.append(
          .init(theChangeChangedNothing ? "moved-for-nothing" : "left-its-place", "\(window) floated at \(place.frame.brief) when its display had moved, nobody has touched it, and Arbor has put it at \(frame.brief)"))
        restingPlaces[window] = nil
      }
    }
  }

  /// `hold`: what shows stays what shows, on every display, until `release`: windows that are out of view stay there (F58).
  func holdViolations(_ problems: inout [InvariantViolation]) {
    guard holdBefore == .view, controller.holdLevel == .view, wasRunningBefore, controller.displays == displaysBefore,
      // A switch of Spaces from before the hold is still to be laid out.
      !timersBefore.contains(where: { $0.hasPrefix("space-") })
    else { return }
    // Not by node ids: windows in view may be docked, floated and resized among themselves, which makes new groups to be on.
    for window in parkedBefore.subtracting(controller.parked).sorted() {
      guard let fake = system.windows[window], fake.snapshot.isPresent, presentBefore.contains(window), cooperates(fake),
        window != controller.draggedWindow, controller.filter.manages(fake.snapshot), isInView(fake.snapshot.frame),
        fake.placeIsArborsDoing,
        // A tile, a tab behind another, a window on a Desktop that was squeezed: they are part of what the view is on.
        // What the display really showed counts: more than its camera while the space the camera is on had nothing to show.
        !workspacesBefore.contains(where: { display, before in
          let view = viewsBefore[display] ?? before.camera
          return before.tree.windows(under: before.camera).contains(window) || before.tree.windows(under: view).contains(window)
            || (before.isFloating(window)
              && (before.camera == before.tree.desktop || before.tree.ancestors(of: before.tree.desktop).contains(before.camera)))
        })
      else { continue }
      problems.append(.init("held-view", "the view is held and \(window), which was out of view, came in at \(fake.snapshot.frame.brief)"))
    }
  }

  /// Undo, then redo straight after, is the identity (F19). On a display whose view is where it was, the whole workspace, what is out
  /// of view and every slot are as before. Where the view would not have shown the windows that changed places, undo and redo step
  /// out until it does: then the arrangement is the same, the new view contains the old one, and Back leads to the old one.
  func undoViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    defer { if action != .command("undo") || !lastCommandSucceeded { beforeUndo = nil } }
    guard action == .command("redo"), let before = beforeUndo else { return }
    guard lastCommandSucceeded else {
      problems.append(.init("undo-redo", "`undo` succeeded and `redo` straight after it did not"))
      return
    }
    var viewsStayed = true
    for (display, workspace) in before.workspaces.sorted(by: { $0.key < $1.key }) {
      guard let now = controller.workspaces[display] else {
        problems.append(.init("undo-redo", "undo and redo lost \(display)"))
        continue
      }
      if now.camera != workspace.camera {
        viewsStayed = false
        if !now.hasSameArrangement(as: workspace) {
          problems.append(.init("undo-redo", "undo and redo changed the arrangement of \(display): \(Self.shape(of: workspace.tree, waiting: [])) became \(Self.shape(of: now.tree, waiting: []))"))
        } else if !now.tree.ancestors(of: workspace.camera).contains(now.camera) {
          problems.append(.init("undo-redo", "undo and redo moved the view of \(display) from \(workspace.camera) to \(now.camera), which does not contain it"))
        } else if now.back.last != workspace.camera {
          problems.append(.init("undo-redo", "undo and redo moved the view of \(display) from \(workspace.camera), and Back leads to \(now.back.last.map { "\($0)" } ?? "nothing")"))
        }
      } else if now != workspace {
        let what =
          now.tree != workspace.tree
          ? "the tree was \(Self.shape(of: workspace.tree, waiting: [])), is \(Self.shape(of: now.tree, waiting: [])) (or ids or weights differ)"
          : now.floating != workspace.floating
            ? "floating was \(workspace.floating.sorted { $0.key < $1.key }), is \(now.floating.sorted { $0.key < $1.key })"
            : "history, saved views, guests, pins or remembered frames differ"
        problems.append(.init("undo-redo", "undo and redo changed \(display): \(what)"))
      } else if controller.layouts[display]?.windowFrames != before.slots[display] {
        problems.append(.init("undo-redo", "undo and redo changed the slots on \(display)"))
      }
    }
    // On the way the Desktop may have been more than a tile, and no change of the arrangement takes a floating window out of view again.
    // A window that came back over a framed view follows the Desktop out of view with the next layout, whenever that is (`vanished`).
    let wentOut = controller.parked.subtracting(before.parked).subtracting(cameBack)
    let cameIn = before.parked.subtracting(controller.parked)
    let onlyFloatsCameIn = cameIn.allSatisfy { window in controller.workspaces.values.contains { $0.isFloating(window) } }
    if viewsStayed, !wentOut.isEmpty || !onlyFloatsCameIn {
      problems.append(.init("undo-redo", "undo and redo changed what is out of view: \(before.parked.sorted()) became \(controller.parked.sorted())"))
    }
  }

  /// Whatever changes where bare Desktop may be says so to observers (F60, F05): the tap decides from a copy. What goes with no
  /// layout is noticed once the command or event is over, which is what the timer is for.
  func guardZoneViolations(_ problems: inout [InvariantViolation]) {
    guard !harness.scheduler.pendingKeys.contains("desktop-guard-zones"), guardZonesCopy != controller.desktopGuardZones() else { return }
    problems.append(.init("guard-zones", "the copy of desktopGuardZones() kept by an observer is out of date, and nothing is due to mend it"))
  }

  /// A pinned window is always in view (F49), and so is the summoned one; a stashed window never is (F53).
  func pinViolations(_ problems: inout [InvariantViolation]) {
    // A window that comes back with its Space is placed once all the reports of the switch are in.
    for (display, workspace) in controller.workspaces where !isDueForLayout(display) {
      for window in workspace.stashedWindows where window != controller.draggedWindow {
        guard let fake = system.windows[window], fake.snapshot.isPresent, cooperates(fake), fake.placeIsArborsDoing else { continue }
        if !controller.parked.contains(window) {
          problems.append(.init("stashed", "\(window) was sent away on \(display) and does not count as out of view"))
        }
      }
      for window in workspace.pinnedWindows + [workspace.summoned?.window].compactMap({ $0 }) where window != controller.draggedWindow {
        guard let fake = system.windows[window], fake.snapshot.isPresent, cooperates(fake) else { continue }
        if controller.parked.contains(window) {
          problems.append(.init("pinned", "\(window) is pinned on \(display) and counts as out of view"))
        } else if !isInView(fake.snapshot.frame), fake.placeIsArborsDoing, !system.displayList.isEmpty,
          fake.snapshot.frame.width > 4, fake.snapshot.frame.height > 4
        {
          problems.append(.init("pinned", "\(window) is pinned on \(display) and is at \(fake.snapshot.frame.brief), out of view"))
        }
      }
    }
  }

  /// Go to… is open only where it can be used, and the window chosen in it is in view with the keyboard.
  func paletteViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    if let palette = harness.overlays.finder {
      if controller.display(palette.model.display) == nil {
        problems.append(.init("palette", "Go to… is open on \(palette.model.display), which is gone"))
      }
      if let dragged = controller.draggedWindow { problems.append(.init("palette", "Go to… is open while \(dragged) is dragged")) }
    }
    guard case .palette(.choose) = action, case .window(let window)? = chosenInThePalette, harness.overlays.finder == nil,
      let fake = system.windows[window], controller.windows[window] != nil
    else { return }
    if system.focused != window { problems.append(.init("palette", "\(window) was chosen in Go to… and \(system.focused.map(\.description) ?? "nothing") has the keyboard")) }
    // On its own Space macOS shows it; a window Arbor leaves alone stays where it is; and so does one whose app does not do as
    // it is asked, or does not answer at all: that one follows when its app answers again.
    guard fake.snapshot.isOnActiveSpace, !fake.snapshot.isFullScreen, controller.filter.manages(fake.snapshot), cooperates(fake)
    else { return }
    if fake.snapshot.isMinimized || fake.snapshot.isHidden {
      problems.append(.init("palette", "\(window) was chosen in Go to… and is still minimised or hidden"))
    } else if controller.parked.contains(window) {
      problems.append(.init("palette", "\(window) was chosen in Go to… and counts as out of view"))
    }
  }

  /// There is at most one focus ring, and once its timers have run it is around the window that has the
  /// keyboard, where that window really is; never around a window that is out of view or not Arbor's.
  func focusRingViolations(_ problems: inout [InvariantViolation]) {
    let rings = harness.overlays.scenes.values.compactMap(\.focusRing)
    guard !rings.isEmpty else { return }
    if rings.count > 1 { problems.append(.init("focus-ring", "there are \(rings.count) focus rings: \(rings.map(\.window).sorted())")) }
    // It looks again a moment after the keyboard moves, stays away while the mouse is busy, and is worked out
    // afresh by every layout, so it is judged once nothing of the kind is pending.
    guard harness.scheduler.pendingKeys.allSatisfy({ $0 == "save" }), !system.hasHeldEchoes else { return }
    for ring in rings {
      guard let fake = system.windows[ring.window] else {
        problems.append(.init("focus-ring", "the focus ring is around \(ring.window), which is gone"))
        continue
      }
      if system.focused != ring.window {
        problems.append(.init("focus-ring", "the focus ring is around \(ring.window), the keyboard is in \(system.focused.map { "\($0)" } ?? "no window")"))
      } else if !fake.snapshot.isPresent || controller.parked.contains(ring.window) || !controller.filter.manages(fake.snapshot) {
        problems.append(.init("focus-ring", "the focus ring is around \(ring.window), which is out of view or not Arbor's to arrange"))
      } else if ring.frame != fake.snapshot.frame {
        problems.append(.init("focus-ring", "the focus ring is at \(ring.frame.brief), \(ring.window) is at \(fake.snapshot.frame.brief)"))
      }
    }
  }

  /// Only known timers are pending, at most one of each kind per display, and they run dry.
  func timerViolations(settled: Bool, _ problems: inout [InvariantViolation]) {
    let keys = harness.scheduler.pendingKeys
    for key in keys where !Self.knownTimers.contains(where: { key.hasPrefix($0) }) {
      problems.append(.init("timers", "unknown timer `\(key)`; add its prefix to ChaosRunner.knownTimers"))
    }
    // One of each kind for each display, or for each window.
    if keys.count > Self.knownTimers.count * (displayIDsSeen.count + 1) + system.windows.count {
      problems.append(.init("timers", "\(keys.count) timers are pending: \(keys)"))
    }
    for key in keys where key.hasPrefix("rule-title-") && system.windows[WindowID(UInt32(key.dropFirst(11)) ?? 0)] == nil {
      problems.append(.init("timers", "`\(key)` waits for the title of a window that is gone"))
    }
    // The other way round does no harm: a timer left over finds nothing to do.
    if !controller.waitingSlotIDs.isEmpty, !keys.contains("pending-slots") {
      problems.append(.init("timers", "\(controller.waitingSlotIDs.count) slots are waiting, and no timer is going to end the wait"))
    }
    // A slot goes on waiting for as long as its window exists on a Space that is not showing, and updates are looked for every day.
    let restless = keys.filter { $0 != "pending-slots" && $0 != "update-check" && $0 != "accessibility" }
    if settled, !restless.isEmpty, system.windows.values.allSatisfy(cooperates) {
      // A rule name for each kind of timer, so that a known failure in one does not hide another.
      var kinds = Set(restless.map { key in Self.knownTimers.first { key.hasPrefix($0) } ?? key })
      // Every layout makes Arbor look after the pinned windows again, so a layout that keeps coming back is the cause.
      if kinds.contains("landed-") { kinds = ["landed-"] }
      for kind in kinds.sorted() {
        let name = kind.hasSuffix("-") ? String(kind.dropLast()) : kind
        problems.append(.init("restless-\(name)", "timers keep coming back with nobody touching anything: \(restless)"))
      }
    }
  }

  /// Arbor never moves a window it does not arrange (an excluded app's, one an `ignore` rule matched,
  /// its own). Letting go of a window may move it once, back into view. One that was in full screen then could not be
  /// moved, and that one move is still owed when it leaves full screen (Controller+LeftInFullScreen.swift).
  func untouchedViolations(_ problems: inout [InvariantViolation]) {
    guard system.frameLog.count > frameLogMark else { return }
    let filter = controller.filter
    for window in Set(system.frameLog[frameLogMark...].map(\.window)) {
      guard let snapshot = system.windows[window]?.snapshot else { continue }
      // What Arbor put out of view it brings back, also once it has let go of the window: an app that did not answer then is
      // asked again when it has something to report.
      if !filter.manages(snapshot), !filterBefore.manages(snapshot), !owedAPlaceBefore.contains(window),
        !owedTheWayBackBefore.contains(window)
      {
        problems.append(.init("untouched", "Arbor moved \(window), which it does not arrange"))
      }
    }
  }

  /// `state` and state.json survive JSON.
  func codableViolations(_ problems: inout [InvariantViolation]) {
    do {
      let snapshot = controller.snapshot()
      let decoded = try JSONDecoder().decode(StateSnapshot.self, from: JSONEncoder().encode(snapshot))
      if decoded != snapshot { problems.append(.init("codable", "`state` does not read back as it was written")) }
    } catch {
      problems.append(.init("codable", "`state` does not survive JSON: \(error)"))
    }
    // Not `saveNow()`: looking must not change what a crash would leave behind.
    let saved = controller.stateToSave
    do {
      let decoded = try JSONDecoder().decode(PersistedState.self, from: JSONEncoder().encode(saved))
      if let problem = Self.readBackViolation(written: saved, read: decoded) { problems.append(problem) }
    } catch {
      problems.append(.init("codable", "state.json does not survive JSON: \(error)"))
    }
  }

  /// What differs between what was written to state.json and what was read back, if anything.
  static func readBackViolation(written: PersistedState, read: PersistedState) -> InvariantViolation? {
    guard written != read else { return nil }
    var (historyOnly, guestsOnly): (String?, String?)
    func compare(_ name: String, _ a: Workspace?, _ b: Workspace?) -> String? {
      guard a != b else { return nil }
      guard let a, let b else { return "\(name) is \(a == nil ? "new" : "gone")" }
      if a.tree != b.tree { return "the tree of \(name): \(shape(of: a.tree, waiting: [])) became \(shape(of: b.tree, waiting: [])), or ids or weights differ" }
      if a.camera != b.camera { return "the camera of \(name): \(a.camera) became \(b.camera)" }
      if a.savedViews != b.savedViews { return "the saved views of \(name): \(a.savedViews) became \(b.savedViews)" }
      if a.floating != b.floating { return "the floating windows of \(name): \(a.floating) became \(b.floating)" }
      if a.guests != b.guests {
        guestsOnly = guestsOnly ?? "the guests of \(name): \(a.guests ?? [:]) became \(b.guests ?? [:])"
        return nil
      }
      if a.pinned != b.pinned { return "the pins of \(name): \(a.pinned ?? []) became \(b.pinned ?? [])" }
      if a.undockedFrames != b.undockedFrames {
        return "the undocked frames of \(name): \(a.undockedFrames ?? [:]) became \(b.undockedFrames ?? [:])"
      }
      if a.summoned != b.summoned { return "the summoned window of \(name): \(String(describing: a.summoned)) became \(String(describing: b.summoned))" }
      if a.stashed != b.stashed { return "the stash of \(name): \(a.stashed ?? []) became \(b.stashed ?? [])" }
      if a.summonFrames != b.summonFrames { return "the summon frames of \(name): \(a.summonFrames ?? [:]) became \(b.summonFrames ?? [:])" }
      if a.names != b.names { return "the names of \(name): \(a.names) became \(b.names)" }
      if a.desktopIsOwedRoom != b.desktopIsOwedRoom {
        return "the room owed to the Desktop of \(name): \(String(describing: a.desktopIsOwedRoom)) became \(String(describing: b.desktopIsOwedRoom))"
      }
      if a.back != b.back || a.forward != b.forward {
        historyOnly = historyOnly ?? "the history of \(name): \(a.back) \(a.forward) became \(b.back) \(b.forward)"
        return nil
      }
      return "something new about \(name) that ChaosRunner.readBackViolation does not know"
    }
    var difference: String?
    for id in Set(written.workspaces.keys).union(read.workspaces.keys).sorted() where difference == nil {
      difference = compare("\(id)", written.workspaces[id], read.workspaces[id])
    }
    for id in Set(written.dormant.keys).union(read.dormant.keys).sorted() where difference == nil {
      difference = compare("dormant \(id)", written.dormant[id]?.workspace, read.dormant[id]?.workspace)
    }
    if difference == nil, written.hints != read.hints { difference = "the hints" }
    if difference == nil, let guestsOnly {
      return .init("codable-guests", "state.json does not read back as it was written: \(guestsOnly)")
    }
    if difference == nil, let historyOnly {
      return .init("codable-history", "state.json does not read back as it was written: \(historyOnly)")
    }
    return .init("codable", "state.json does not read back as it was written: \(difference ?? "something else")")
  }

  // MARK: After quitting

  /// After `shutdown()`: every window Arbor had docked or parked is back in view, including the ones
  /// that are minimized, hidden or on another Space (their owner will want them later, when Arbor
  /// is not there to fetch them): more than half of it, and its title bar within reach; nothing is parked or drawn; and timers left over do nothing.
  /// Floating windows that were in view stay where the user left them, half off the screen or not.
  func shutdownViolations(placed: Set<WindowID>) -> [InvariantViolation] {
    var problems: [InvariantViolation] = []
    if !controller.parked.isEmpty { problems.append(.init("shutdown", "still parked: \(controller.parked.sorted())")) }
    if !harness.overlays.scenes.isEmpty || harness.overlays.preview != nil {
      problems.append(.init("shutdown", "overlays are still showing"))
    }
    if !isPaused {  // a pause may have a timer to end it
      let mark = system.frameLog.count
      harness.scheduler.runPending()
      harness.scheduler.runPending()
      if system.frameLog.count != mark {
        problems.append(.init("shutdown", "a timer moved \(system.frameLog[mark].window) after Arbor stopped"))
      }
    }
    guard !system.displayList.isEmpty else { return problems }
    // The window in the user's hand is theirs to put down.
    for id in placed.sorted() where id != system.dragging {
      // macOS does not let a window in full screen be moved.
      guard let fake = system.windows[id], cooperates(fake), fake.snapshot.frame.area > 0, !fake.snapshot.isFullScreen else {
        continue
      }
      let frame = fake.snapshot.frame
      // Displays do not overlap, so what they show adds up. A window larger than a display cannot
      // be 90% in view; it must show as much as fits.
      let total = system.displayList.reduce(0) { $0 + frame.intersection($1.frame).area } / frame.area
      let best = system.displayList.map { display -> CGFloat in
        let most = min(frame.width, display.visibleFrame.width) * min(frame.height, display.visibleFrame.height)
        return frame.intersection(display.frame).area / most
      }.reduce(total, max)
      // A window that leaves the arrangement goes back to the frame it had of its own, which may hang over an edge, but
      // not by more than half (F48, `asItWas`).
      let titleBarIsOnADisplay = system.displayList.contains { frame.overlaps($0.frame) && frame.minY >= $0.frame.minY }
      if best < 0.5 || !titleBarIsOnADisplay {
        problems.append(.init("shutdown", "\(id) was left at \(frame.brief), \(Int(best * 100))% in view"))
      }
    }
    return problems
  }

  // MARK: After launching

  /// A tree without its node ids and weights: `h[101 v[102 103+…] desktop]`, with `…` for a slot that waits for its window.
  static func shape(of tree: LayoutTree, waiting: Set<WindowID>, from node: NodeID? = nil) -> String {
    let node = node ?? tree.root
    switch tree[node]?.kind {
    case .split(let axis, let children):
      return (axis == .horizontal ? "h[" : "v[")
        + children.map { shape(of: tree, waiting: waiting, from: $0) }.joined(separator: " ") + "]"
    case .stack(let windows, _): return windows.map { waiting.contains($0) ? "…" : "\($0.rawValue)" }.joined(separator: "+")
    case .desktop: return "desktop"
    case nil: return "?"
    }
  }

  /// What each connected display's tree should look like after starting from `saved`: the saved
  /// tree, with slots waiting for the windows that are gone and renumbered windows under their new numbers.
  /// Displays where that is not clear-cut (two windows share an app and a title) are left out.
  func expectedShapes(from saved: PersistedState) -> [DisplayID: String] {
    var expected: [DisplayID: String] = [:]
    let (filter, rules) = (controller.filter, controller.settings.rules)
    // A window that an `ignore` rule matches at launch is let go, whatever was done with it before.
    let present = system.windows.mapValues(\.snapshot).filter {
      filter.manages($0.value) && AppRule.firstMatch(in: rules, bundleID: $0.value.bundleID, title: $0.value.title)?.action != .ignore
    }
    var identities: [String: Int] = [:]
    for snapshot in present.values { identities["\(snapshot.bundleID ?? "-")|\(snapshot.title)", default: 0] += 1 }
    var claimed = Set<WindowID>()

    for display in system.displayList.sorted(by: { $0.id < $1.id }) {
      guard var workspace = saved.workspaces[display.id] else { continue }
      var clear = true
      var waiting = Set<WindowID>()
      for window in workspace.tree.allWindows {
        let hint = saved.hints[window]
        if let snapshot = present[window], hint == nil || hint?.bundleID == snapshot.bundleID, !claimed.contains(window) {
          claimed.insert(window)
          continue
        }
        guard let hint else {
          workspace.forget(window)
          continue
        }
        let twins = identities["\(hint.bundleID ?? "-")|\(hint.title)"] ?? 0
        if let here = system.windows[window]?.snapshot, here.bundleID == hint.bundleID {
          // It is here and no longer arranged: nobody is going to restore it.
          workspace.forget(window)
        } else if twins == 0 {
          // Its slot waits for it, unless another window of the app is taken for it.
          if present.values.contains(where: { $0.bundleID == hint.bundleID }) { clear = false }
          waiting.insert(window)
        } else if twins == 1, let new = renumbered[window], let snapshot = present[new], snapshot.title == hint.title,
          snapshot.bundleID == hint.bundleID, !claimed.contains(new), !workspace.contains(new)
        {
          workspace.tree.replaceWindow(window, with: new)
          claimed.insert(new)
        } else {
          clear = false
        }
      }
      if clear { expected[display.id] = Self.shape(of: workspace.tree, waiting: waiting) }
    }
    return expected
  }

  func shapeViolations(expected: [DisplayID: String]) -> [InvariantViolation] {
    expected.sorted(by: { $0.key < $1.key }).compactMap { id, shape in
      guard let tree = controller.workspaces[id]?.tree else {
        return .init("restart", "\(id) has no workspace after a restart")
      }
      let actual = Self.shape(of: tree, waiting: controller.waitingSlotIDs)
      return actual == shape ? nil : .init("restart", "\(id) came back as \(actual), expected \(shape)")
    }
  }
}

extension CGRect {
  fileprivate var isFiniteRect: Bool { origin.x.isFinite && origin.y.isFinite && size.width.isFinite && size.height.isFinite }
}
