import ArborCore
import CoreGraphics
import Foundation

/// Automatic docking (docs/features/F23-automatic-docking.md): the rule action `dock auto`, which the setting
/// `"newWindows": "dock"` applies to every window no other rule claims.
///
/// `AutoDock.plan` says where there is room as far as is known. What is not known is how small the apps involved
/// let their windows get, and the only way to find out is to ask. So the new window is offered its slot
/// before anyone makes room for it, and a docking that squeezed a neighbour into a tile is taken back.
extension Controller {
  /// The window docked this way last, where and when.
  struct AutoDockTrail {
    var window: WindowID
    var display: DisplayID
    var time: Date
  }

  /// How long a window docked automatically stands in for the focused window. An app that restores five windows
  /// opens them faster than macOS reports who has the keyboard. Each then docks beside the one before, as
  /// it would have if they had opened one by one, instead of all five halving the same slot.
  static let autoDockBurst: TimeInterval = 1
  /// Every round but the last learns a width or a height that an app insists on: of the new window, of the
  /// focused one, or of the largest one.
  private static let autoDockRounds = 7

  /// Docks `id`, a new window that floats on `display`, where there is room. Returns what happened, for the log.
  func dockAutomatically(_ id: WindowID, on display: DisplayID) -> String {
    guard let opening = windows[id], let visibleFrame = self.display(display)?.visibleFrame else { return "\(id) is gone" }
    guard opening.isPresent else { return "\(id) takes no room now, so it floats" }
    // Making room would pull windows out from under the pointer. And a window that opens with the button down is
    // in the user's hand: a tab torn off a browser. Where it is dropped decides, as for any dragged window.
    guard drag == nil, edgeResize == nil, !system.isMouseButtonDown() else {
      return "\(id) floats: the mouse button is down"
    }
    // Who asked for this window has the first word. `summon` opened its app to have the window come and go over the
    // view, which a docked window cannot. It is summoned as soon as anyone hears of it, before its rule.
    if workspaces[display]?.summoned?.window == id { return "\(id) floats: it was summoned" }
    // `layout --open` wrote the arrangement out, and gives up its wait when it finds another one in its place.
    guard pendingLayouts[display] == nil else { return "\(id) floats: an arrangement is waiting for its windows" }
    // A draft over the mail app in full screen. The arrangement is on a macOS Space that does not show.
    guard !showsAFullScreenWindow(display) else { return "\(id) floats: it opened over a window in full screen" }

    var recent = focusHistory
    if let trail = autoDockTrail, trail.display == display, now().timeIntervalSince(trail.time) < Self.autoDockBurst {
      recent.insert(trail.window, at: 0)
    }
    var refusal = AutoDock.Refusal.noRoom
    for _ in 0..<Self.autoDockRounds {
      guard let workspace = workspaces[display] else { break }
      let present = presentWindowIDs()
      // As the layout after the docking reckons, or a place would be tried and taken back round after round with nothing learned.
      let minimums = plannedSizes
      // The layout after the docking makes room before it makes a tile (F61), so the plan reckons with that.
      let terms = settings.makeRoom ? roomTerms(on: display, docking: id) : nil
      let plan = AutoDock.plan(
        for: id, in: workspace, recent: recent, frame: visibleFrame, options: options(for: display).layoutOptions,
        tabsEnabled: settings.tabsEnabled, isPresent: { present.contains($0) }, minimumSize: { minimums[$0] },
        emptyDesktopWeight: desktopIsEmpty(but: id, in: workspace) ? settings.arrangeDesktopWeight : nil,
        makingRoom: terms)
      guard case .dock(let placement) = plan else {
        if case .float(let reason) = plan { refusal = reason }
        break
      }
      guard let fits = takesSlot(id, placement.slot) else { return "\(id) floats: it is gone, or its app does not answer" }
      guard fits else { continue }
      // Worked out now: the last layout that was applied can be older than the last report about a window.
      let before = layout(of: display)
      dockNewWindow(id, at: placement.target, on: display, desktopWeight: placement.desktopWeight)
      if let before, let after = layouts[display],
        !AutoDock.keepsEverythingShowing(
          before: before, after: after, adding: id, covering: placement.covers,
          desktopMayGo: terms.map {
            AutoDock.desktopMayBecomeATile(on: $0, options: options(for: display).layoutOptions)
          } ?? false)
      {
        // A neighbour would not shrink to its share. What was learned about it stays.
        Log.info("docking \(id) left something too small to show; taking it back")
        workspaces[display] = workspace
        // A Desktop that gave its room away while it was empty takes it back once a window floats on it, and a docked
        // window pays with its place (F61). The new window floats for this moment only: that is not yet the time.
        workspaces[display]?.desktopIsOwedRoom = nil
        // At once, which also ends the motion the docking began: nobody is to watch it play forwards and backwards.
        relayout(display, reason: .structure, motion: .instant)
        if layouts[display]?.desktopFrame == nil { workspaces[display]?.desktopIsOwedRoom = workspace.desktopIsOwedRoom }
        continue
      }
      autoDockTrail = AutoDockTrail(window: id, display: display, time: now())
      return "docked \(id): \(Self.describe(placement))"
    }
    returnToWhereItOpened(id, opening.frame)
    switch refusal {
    case .framed: return "\(id) floats: one window fills the view"
    case .onTheDesktop: return "\(id) floats: the view is on the Desktop"
    case .noRoom: return "\(id) floats: there is no room for it in the view"
    }
  }

  /// Whether `display` shows the macOS Space that a window in full screen has to itself.
  private func showsAFullScreenWindow(_ display: DisplayID) -> Bool {
    guard let frame = self.display(display)?.frame else { return false }
    return windows.values.contains {
      $0.isFullScreen && $0.isOnActiveSpace && !$0.isMinimized && !$0.isHidden
        && frame.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY))
    }
  }

  /// Whether nothing but `id` floats in sight in `workspace`.
  private func desktopIsEmpty(but id: WindowID, in workspace: Workspace) -> Bool {
    workspace.floating.keys.allSatisfy { $0 == id || parked.contains($0) || windows[$0]?.isPresent != true }
  }

  /// Offers a floating window the slot it would get, and says whether it fits. If its app keeps it larger, that size
  /// is remembered and no other window has been disturbed. Nil if the window cannot be moved at all.
  private func takesSlot(_ id: WindowID, _ slot: CGRect) -> Bool? {
    guard let first = system.setFrame(slot, of: id) else { return nil }
    // A terminal takes the whole character cells nearest to what it is asked for. A little too large is not a refusal.
    let actual = askForLess(id, slot: slot, took: first)
    windows[id]?.frame = actual
    let tooWide = actual.width > slot.width + 2
    let tooTall = actual.height > slot.height + 2
    guard tooWide || tooTall else { return true }
    var minimum = minimumSizes[id] ?? .zero
    if tooWide { minimum.width = max(minimum.width, actual.width) }
    if tooTall { minimum.height = max(minimum.height, actual.height) }
    minimumSizes[id] = minimum
    return false
  }

  /// Puts a window that was not docked after all back where its app opened it.
  private func returnToWhereItOpened(_ id: WindowID, _ frame: CGRect) {
    guard let current = windows[id], current.frame != frame, let actual = system.setFrame(frame, of: id) else { return }
    windows[id]?.frame = actual
  }

  private static func describe(_ placement: AutoDock.Placement) -> String {
    switch placement.target {
    case .cameraEdge(let edge): "at the \(edge.rawValue) edge of the view"
    case .beside(let node, let edge): "on the \(edge.rawValue) of \(node)"
    case .stack(let node): "as a tab of \(node)"
    case .float, .none: "nowhere"
    }
  }

  // MARK: Windows that were open all along

  /// Treated like a window found at launch: it floats where it is, and of the rules only `ignore` applies. Switching
  /// to a macOS Space for the first time must not rearrange what is on it. In everything else (a saved slot that
  /// waits for it, the focus ring) it is a window that appeared, and `adoptNewWindow` asks which of the two it is.
  public func windowFound(_ window: WindowSnapshot) {
    isTakingInAFoundWindow = true
    defer { isTakingInAFoundWindow = false }
    windowAppeared(window)
  }

  // MARK: The switch

  func toggleAutoDock() -> CommandResult {
    if let refusal = refusalToChangeSettings() { return refusal }
    var updated = settings
    updated.newWindows = settings.docksNewWindows ? "float" : "dock"
    let unsaved = change(settings: updated)
    return reply(
      updated.docksNewWindows ? "new windows dock beside the focused window" : "new windows float", unsaved: unsaved)
  }

  /// A number from settings.json, which can be too large for an `Int`.
  private static func points(_ value: Double) -> String { Int(exactly: value).map(String.init) ?? String(value) }

  /// What the `rules` report says about windows that match none of the user's rules.
  func newWindowsLines() -> [String] {
    if settings.docksNewWindows {
      return [
        "\(settings.rules.isEmpty ? "A new" : "Any other") window docks beside the focused window, if it opens at least "
          + "\(Self.points(settings.autoDockMinimumWidth)) x \(Self.points(settings.autoDockMinimumHeight)) points, can be resized, "
          + "and there is room (\"newWindows\" is \"dock\"; `toggle-auto-dock` switches it)."
      ]
    }
    guard settings.newWindows != "float" else { return [] }
    return ["\"newWindows\" must be \"float\" or \"dock\"; as it is neither, new windows float."]
  }
}
