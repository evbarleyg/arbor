import ArborCore
import CoreGraphics
import Foundation

/// The minimap (docs/features/F26-minimap.md): after the view moves, a small picture of the display's whole arrangement
/// shows for a moment, with the space now in view marked. Asked for (`minimap`), it stays longer and takes clicks.
///
/// What it holds and where it sits are decided in ArborCore (Minimap.swift); this file decides when it comes and
/// goes, and the presenter only draws it. It is cosmetic: no window's frame depends on it.
extension Controller {
  struct MinimapState {
    /// What each display shows now. A display without a minimap has no entry.
    var showing: [DisplayID: MinimapModel] = [:]
    /// What filled each display's view at its last layout, to tell a move of the view by.
    var views: [DisplayID: View] = [:]

    struct View: Equatable {
      var space: NodeID
      /// The docked windows that are on another macOS Space or in full screen. When macOS changes what is there, what fills
      /// the view changes with it, but nobody has gone anywhere in the arrangement.
      var elsewhere: Set<WindowID>
    }

    /// The display on which the `minimap` command that is running has brought one up.
    var justAsked: DisplayID?
    /// The shortcut that brought a minimap up and has not come up since.
    var hold: Hold?

    struct Hold {
      enum Phase {
        /// Down too briefly to tell a tap from a hold.
        case pressed
        /// Held: the minimap stays for as long as the keys are down, and letting go lands.
        case held
        /// Decided (a click, or the minimap went some other way), but the keys are still down: their release does nothing.
        case spent
      }
      var chord: KeyChord
      var display: DisplayID
      var since: Double
      var phase = Phase.pressed
    }
  }

  /// How long `minimap` shows it: time to find a window and aim at it, and never left on screen for good.
  static let minimapOnDemandDuration = 5.0
  /// A hand-edited `minimapDuration` is kept below this: nothing can dismiss a panel that only passes by.
  static let minimapLongestDuration = 10.0

  private func minimapTimer(_ display: DisplayID) -> String { "minimap-\(display.rawValue)" }

  /// `minimapDuration` as a time a timer can take. Anything that is not a positive number counts as off.
  var minimapDuration: Double {
    settings.minimapDuration > 0 ? min(settings.minimapDuration, Self.minimapLongestDuration) : 0
  }

  /// Whether a move of the view brings the minimap up. The one gate for everything during which nothing of Arbor's
  /// may appear unasked: not during a hold (F58, `mayShowUnasked`).
  var minimapMayAppearUnasked: Bool { minimapDuration > 0 && mayShowUnasked }

  /// The frame of the minimap showing on `display`, in global coordinates, for whatever shares the bottom of the display
  /// with it: the heads-up line (F43) sits directly above.
  public func minimapFrame(on display: DisplayID) -> CGRect? { minimap.showing[display]?.frame }

  /// Whether a minimap that was asked for is up, on any display.
  var isMinimapAskedFor: Bool { minimap.showing.values.contains(where: \.takesClicks) }

  /// For the menu's row, which like its neighbours is about the display a command from the menu acts on: whether one that
  /// was asked for is up there (the tick: choosing the row again puts it away), and whether `minimap` would do anything.
  var minimapInMenu: (isUp: Bool, canToggle: Bool) {
    guard let display = menuDisplay?.0 else { return (false, false) }
    let isUp = minimap.showing[display]?.takesClicks == true
    return (isUp, isUp || minimapModel(for: display, askedFor: true) != nil)
  }

  /// Where a press on `display` is the minimap's, for the guard of the Desktop (F60). A change of it is announced as `.frames`.
  func minimapClickFrame(on display: DisplayID) -> CGRect? {
    minimap.showing[display].flatMap { $0.takesClicks ? $0.frame : nil }
  }

  // MARK: When

  /// Watches the controller's own changes. Called once, from `init`.
  func startMinimap() {
    observe { [weak self] change in
      guard let self else { return }
      switch change {
      case .layout(let display):
        self.minimapNoticedLayout(of: display)
      case .lifecycle where !self.isRunning:
        // Stopped or paused: `shutdown` has removed every overlay. The next start is a new beginning.
        for display in self.minimap.showing.keys { self.scheduler.cancel(self.minimapTimer(display)) }
        self.scheduler.cancel(Self.minimapTick)
        self.minimap = MinimapState()
      default:
        break
      }
    }
  }

  /// Every move of the view ends in a layout, announced (`.camera`) or not: the framed window closing moves it too, and
  /// that is when "where am I?" is hardest to answer. So the view has moved when another space fills it than at the last
  /// layout. A display seen for the first time (at launch, after a pause, plugged in) only sets the baseline: what
  /// Arbor restores there is not a move. Nor is it one when macOS switches Spaces or a window goes into full screen.
  ///
  /// None passes by when the view goes to everything: it would be a small picture of what is on screen.
  private func minimapNoticedLayout(of display: DisplayID) {
    // No layout follows for a display that went away. Every display that shows a minimap has been laid out.
    for gone in minimap.views.keys.filter({ workspaces[$0] == nil }).sorted() {
      hideMinimap(on: gone)
      minimap.views[gone] = nil
    }
    guard let layout = layouts[display], let tree = workspaces[display]?.tree else { return }
    let view = MinimapState.View(
      space: layout.camera,
      elsewhere: Set(tree.allWindows.filter { windows[$0].map { !$0.isOnActiveSpace || $0.isFullScreen } ?? false }))
    let before = minimap.views.updateValue(view, forKey: display)
    let hasMoved = before.map { $0.space != view.space && $0.elsewhere == view.elsewhere } ?? false
    let wasAskedFor = minimap.showing[display]?.takesClicks == true

    if hasMoved, wasAskedFor || (minimapMayAppearUnasked && layout.camera != tree.root) {
      // One that was asked for stays as it is: ⌃⌥M and then the arrows is walking with the minimap open.
      presentMinimap(on: display, askedFor: wasAskedFor)
    } else if hasMoved {
      // What an earlier move brought up marks a place the view has left.
      hideMinimap(on: display)
    } else if minimap.showing[display] != nil {
      // It never shows an arrangement that is no longer there. Its time runs on.
      if let model = minimapModel(for: display, askedFor: wasAskedFor) {
        showMinimap(model)
      } else {
        hideMinimap(on: display)
      }
    }
  }

  // MARK: Showing and hiding

  /// Shows the minimap on a display, in place of the one that may be there, and starts its time. Returns false, showing
  /// nothing, if the display has nothing to show in one.
  @discardableResult
  func presentMinimap(on display: DisplayID, askedFor: Bool) -> Bool {
    guard isRunning, let model = minimapModel(for: display, askedFor: askedFor) else {
      hideMinimap(on: display)
      return false
    }
    showMinimap(model)
    startMinimapTime(on: display, askedFor: askedFor)
    if askedFor { scheduleMinimapTick() }
    return true
  }

  private func startMinimapTime(on display: DisplayID, askedFor: Bool) {
    scheduler.schedule(minimapTimer(display), after: askedFor ? Self.minimapOnDemandDuration : minimapDuration) {
      [weak self] in
      // Held up by its keys, it goes when they do.
      guard let self, self.minimap.hold.map({ $0.display == display && $0.phase == .held }) != true else { return }
      self.hideMinimap(on: display)
    }
  }

  private func showMinimap(_ model: MinimapModel) {
    guard minimap.showing[model.display] != model else { return }
    let clicks = minimapClickFrame(on: model.display)
    minimap.showing[model.display] = model
    overlays.showMinimap(model, on: model.display)
    placeHeadsUpAgain(on: model.display)
    if minimapClickFrame(on: model.display) != clicks { notify(.frames) }
  }

  func hideMinimap(on display: DisplayID) {
    scheduler.cancel(minimapTimer(display))
    guard let model = minimap.showing.removeValue(forKey: display) else { return }
    overlays.showMinimap(nil, on: display)
    placeHeadsUpAgain(on: display)
    if minimap.hold?.display == display { minimap.hold?.phase = .spent }
    if !minimapNeedsTicks { scheduler.cancel(Self.minimapTick) }
    if model.takesClicks { notify(.frames) }
  }

  /// For whatever begins that nothing of Arbor's may show during.
  func hideMinimaps() {
    for display in minimap.showing.keys.sorted() { hideMinimap(on: display) }
  }

  // MARK: On demand

  /// The `minimap` command: a look on demand, on the display under the pointer, also when moves of the view bring none
  /// up. Again puts it away.
  func toggleMinimap() -> CommandResult {
    minimap.justAsked = nil
    guard let (display, workspace) = cameraDisplay() else { return .failure("no display") }
    if minimap.showing[display]?.takesClicks == true {
      hideMinimap(on: display)
      return .success("put the minimap away")
    }
    guard presentMinimap(on: display, askedFor: true) else {
      guard !workspace.tree.allWindows.isEmpty else {
        return .failure(
          "nothing is docked yet\(onPointerDisplay): drag a window to a screen edge, or try `dock left`")
      }
      return .failure(
        "no docked window takes up room just now\(onPointerDisplay): they are minimized, hidden or on another macOS Space")
    }
    minimap.justAsked = display
    return .success("showing the minimap")
  }

  /// A click in the minimap, at `point` in the panel's coordinates.
  public func minimapClicked(display: DisplayID, at point: CGPoint) {
    guard isRunning, let model = minimap.showing[display], model.takesClicks else { return }
    minimap.hold?.phase = .spent
    guard let space = model.space(at: point) else {
      hideMinimap(on: display)
      return
    }
    // Its job is done. The move it causes is like any other: it brings up a minimap that marks the new place and goes, or none.
    var done = model
    done.takesClicks = false
    done.hover = nil
    showMinimap(done)
    let before = minimap.views[display]
    // The way a click on a tile goes, so that whatever stops one stops the other.
    tileActivated(display: display, node: space)
    // The view was there already, or may not move.
    if minimap.views[display] == before { hideMinimap(on: display) }
  }

  // MARK: The model

  /// What the minimap of a display shows now, or nil if no docked window takes up space there.
  func minimapModel(for displayID: DisplayID, askedFor: Bool) -> MinimapModel? {
    guard let workspace = workspaces[displayID], let display = display(displayID) else { return nil }
    let present = presentWindowIDs()
    guard
      let map = Minimap.make(
        workspace.tree, camera: workspace.camera, area: roomForViews(on: display).size, isPresent: { present.contains($0) })
    else { return nil }
    let model = MinimapModel(
      map, on: displayID, in: display.visibleFrame, caption: minimapCaption(for: map.view, in: workspace),
      takesClicks: askedFor, app: { [windows] in windows[$0].map { ($0.pid, $0.bundleID) } })
    return model.pointing(at: pointer(in: model))
  }

  /// The name of a space (F20), or the saved view that leads to it, the lowest if several do.
  func minimapCaption(for space: NodeID, in workspace: Workspace) -> String? {
    workspace.name(of: space)
      ?? workspace.savedViews.filter { $0.value == space }.keys.compactMap { Int($0) }.min().map { "View \($0)" }
  }

  // MARK: The pointer, and holding the keys

  /// One family with the peek (F51): hold to look, let go to land. A tap of the minimap's shortcut brings it up for its five
  /// seconds. Held, it stays for as long as the keys are down, and letting go frames the space the pointer is over, or
  /// puts the minimap away if it is over none.
  ///
  /// While a minimap that takes clicks is up, or its keys are down, a timer looks at the pointer and the keys thirty times
  /// a second, as the peek's does: the space under the pointer is outlined, and a release that nobody reports (⌃ or ⌥
  /// going up first) is found.
  static let minimapTick = "minimap-tick"

  private var minimapTime: Double { now().timeIntervalSinceReferenceDate }

  private var minimapNeedsTicks: Bool { minimap.hold != nil || isMinimapAskedFor }

  /// The pointer in the panel's coordinates.
  private func pointer(in model: MinimapModel) -> CGPoint {
    let pointer = system.cursorLocation()
    return CGPoint(x: pointer.x - model.frame.minX, y: pointer.y - model.frame.minY)
  }

  private func scheduleMinimapTick() {
    scheduler.schedule(Self.minimapTick, after: Self.peekInterval) { [weak self] in self?.minimapTicked() }
  }

  private func minimapTicked() {
    if let hold = minimap.hold {
      if !system.isHolding(hold.chord) {
        minimapKeyCameUp()
      } else if hold.phase == .pressed, minimapTime - hold.since >= Peek.holdThreshold {
        minimap.hold?.phase = .held
      }
    }
    for (display, model) in minimap.showing.sorted(by: { $0.key < $1.key }) where model.takesClicks {
      let point = pointer(in: model)
      // Its time does not run out under the pointer: the click that was on its way would land in the app below.
      if CGRect(origin: .zero, size: model.frame.size).contains(point) { startMinimapTime(on: display, askedFor: true) }
      showMinimap(model.pointing(at: point))
    }
    if minimapNeedsTicks { scheduleMinimapTick() }
  }

  /// Part of `shortcut(_:_:run:)`: whether the key is the business of a minimap being held up, and runs no command.
  func minimapTakes(_ binding: KeyBinding, _ phase: KeyPhase) -> Bool {
    guard let hold = minimap.hold else { return false }
    if binding.chord == hold.chord {
      // Pressed again while it is down is auto-repeat.
      if phase == .released { minimapKeyCameUp() }
      return true
    }
    // ⎋ gives up, as in a peek. With the modifiers down it is a shortcut of its own (⌃⌥⎋ pauses Arbor), which is not what is meant.
    guard phase == .pressed, hold.phase != .spent, binding.chord.key == .escape,
      binding.chord.modifiers == hold.chord.modifiers
    else { return false }
    hideMinimap(on: hold.display)
    return true
  }

  /// Part of `shortcut(_:_:run:)`, after the command of a press has run: the clock starts once the minimap is up, so that
  /// a release that waited in the queue meanwhile is a tap however late it is heard. With `peek` off, held is tapped.
  func minimapKeyWentDown(_ binding: KeyBinding) {
    guard binding.command == .minimap, settings.peek, let display = minimap.justAsked else { return }
    // The timer is running: the minimap that has just come up takes clicks.
    minimap.hold = MinimapState.Hold(chord: binding.chord, display: display, since: minimapTime)
  }

  private func minimapKeyCameUp() {
    guard let hold = minimap.hold else { return }
    minimap.hold = nil
    if hold.phase == .held, let model = minimap.showing[hold.display] {
      // What a click there does: frame the space, or put the minimap away.
      minimapClicked(display: hold.display, at: pointer(in: model))
    }
    if !minimapNeedsTicks { scheduler.cancel(Self.minimapTick) }
  }
}
