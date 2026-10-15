import ArborCore
import CoreGraphics
import Foundation

/// What a person asks of macOS about a docked window stays (board 0.24).
///
/// A double-click on the title bar is one way of asking (Controller+AppsDoubleClick.swift). There are more, and no press tells them from an
/// app's whim: ⌥-click on the green button; Window ▸ Zoom, Fill, Move & Resize; the keys macOS has for its own tiling. But a menu is a click,
/// ⌥-click is a click, and the keys hold fn and ⌃. So a docked window whose frame changes, Arbor having asked nothing, within a second of
/// a click or a modifier key, is taken for its person's asking macOS.
///
/// Measured on macOS 26 with the real pointer, in milliseconds after the release: ⌥-click on the green button, the first new frame after 59 to
/// 110, in one step; Window ▸ Zoom after 399 to 408 (the menu blinks first), in one step; Move & Resize ▸ Left from 409 to 735, in ten to twelve
/// steps no more than 75 apart. Not measured: macOS's tiling keys. A posted fn is not obeyed on a hosted Mac. They run the same commands.
///
/// - The second is asked of the first frame only. What follows within a quarter of a second of the frame before it is the same act, and the
///   last frame counts. Arbor sets nothing meanwhile: the window is let be from the first frame on.
/// - One of macOS's tiles at the end (`MacTiling.isTile`), in another size than it stood at: the window leaves the arrangement and floats where
///   macOS put it, and its neighbours take the room, as at macOS's edge in a drag. Moved alone it is never out, wherever it lands: centred, a
///   window a third wide lies on the middle third.
/// - On another display than its own at the end: out as well. Nobody is let be on another display than its own: there would be a hole where it was,
///   and a key that names somebody else would fetch it back.
/// - A slot's size is never a window's own. Moved alone it still has the size of its slot, which is Arbor's: out, it gets its own, as a window
///   dragged out does; let be, it gets its own at a pause and at Quit, where it lies (`letGo`).
/// - Anything else, filled, zoomed, centred or whatever its app made of a click: let be. Docked, its place kept, nobody else moves. ⌘+ in a
///   terminal is a word to the app and none about the neighbours. Wrongly let be costs a key; wrongly out would cost an arrangement.
/// - Without a click or a modifier key in the second before: put back, as ever.
extension Controller {
  /// How an act under way began.
  enum ActOfMacOS {
    /// With a double-click on the title bar, which Arbor heard: macOS fills or zooms, and tiles nothing.
    case doubleClick
    case clickOrKey
  }

  static let askedOfMacOSWithin = 1.0
  /// How long after a layout a new frame passes for an app's answer to it. Shorter than the second: whoever tiles one window and then its
  /// neighbour, which has just taken the room, must not see the second one put back. Wrongly let be costs a key.
  static let appsAnswerWithin = 0.5
  static let actOfMacOSKey = "asked-of-macos"

  /// Whether a new frame of docked `window` begins an act of macOS's. Arbor's own commands come with a key too, and apps answer late and
  /// with sizes of their own; a hand's drag or pull is followed by reports that trail it. Neither is anybody asking macOS.
  private func somebodyHasJustAskedMacOS(about window: WindowSnapshot, on display: DisplayID) -> Bool {
    let time = now()
    func isWithin(_ seconds: Double, of then: Date?) -> Bool { then.map { time.timeIntervalSince($0) < seconds } ?? false }
    return drag == nil && edgeResize == nil && !isWithin(Self.appsAnswerWithin, of: laidOutAt[display])
      && !isWithin(Self.askedOfMacOSWithin, of: handWasOn[window.id])
      // On its way out of full screen, or back from somewhere, it lands where macOS or its app likes, and Arbor meets it there.
      && window.isPresent && !window.isFullScreen && metAhead[window.id] == nil && landsAt[window.id] == nil
      && !system.isMouseButtonDown() && system.secondsSinceClickOrModifierKey() <= Self.askedOfMacOSWithin
  }

  /// Called by `windowChanged` for a docked window in view that something other than Arbor has given a new frame.
  func standsAsideForWhatWasAskedOfMacOS(_ window: WindowSnapshot, on display: DisplayID) -> Bool {
    guard somebodyHasJustAskedMacOS(about: window, on: display) else { return false }
    let (stood, slot) = (settled[window.id], layouts[display]?.windowFrames[window.id])
    settled[window.id] = window.frame
    enforcement.leave(window.id)
    if let stood = stood ?? slot { whereAZoomBegan[window.id] = (stood, slot) }
    actsOfMacOS[window.id] = .clickOrKey
    waitForTheActsOfMacOSToEnd()
    Log.info("\(window.id) has a new frame within a second of a click or a modifier key; Arbor waits for where it ends")
    return true
  }

  /// A window that is let be already has a new frame: the next step of an act, or the first of another (filled, and now tiled).
  func followsWhatIsAskedOfMacOS(_ window: WindowSnapshot, on display: DisplayID) {
    guard enforcement.leftAlone.contains(window.id) else { return actsOfMacOS[window.id] = nil }
    guard actsOfMacOS[window.id] != nil || somebodyHasJustAskedMacOS(about: window, on: display) else { return }
    actsOfMacOS[window.id] = actsOfMacOS[window.id] ?? .clickOrKey
    waitForTheActsOfMacOSToEnd()
  }

  /// Called by `standsAsideAfterADoubleClick`, at the first frame.
  func anActOfMacOSBeganWithADoubleClick(on window: WindowID) {
    actsOfMacOS[window] = .doubleClick
    waitForTheActsOfMacOSToEnd()
  }

  /// Every step puts it off. One timer for all: macOS arranges two windows side by side at one command.
  private func waitForTheActsOfMacOSToEnd() {
    scheduler.schedule(Self.actOfMacOSKey, after: 0.25) { [weak self] in
      guard let self else { return }
      if self.system.isMouseButtonDown() { return self.waitForTheActsOfMacOSToEnd() }
      let over = self.actsOfMacOS.sorted { $0.key < $1.key }
      self.actsOfMacOS = [:]
      self.theActsOfMacOSAreOver(over.map { ($0.key, $0.value) })
    }
  }

  private func theActsOfMacOSAreOver(_ acts: [(window: WindowID, act: ActOfMacOS)]) {
    var out: [(window: WindowID, home: DisplayID, destination: DisplayID)] = []
    var inTheSizeOfItsSlot: Set<WindowID> = []
    for (id, act) in acts {
      // Taken back by a command meanwhile, closed, gone to the Dock: nothing is left to decide. Nor by displays that are no more: a click takes one
      // away, macOS carries its windows over, and their reports come before its word about the displays, which ends it for them (`updateDisplays`).
      guard isRunning, knowsTheDisplays, enforcement.leftAlone.contains(id), let window = windows[id], window.isPresent, !window.isFullScreen,
        let home = workspaceID(containing: id), workspaces[home]!.isDocked(id)
      else { continue }
      // Home comes first: a slot of Arbor's, less its gap, cannot be told from a tile with margins. And it is asked here once more, of where
      // the window is now: the last few points of an eased way are too little for `windowChanged` to pass on.
      noteWhetherItIsBackInItsSlot(window, on: home)
      guard enforcement.leftAlone.contains(id) else { continue }
      // macOS's own way back, to where it stood, and its slot is another by now: a docked window that something has moved, as after the
      // second double-click.
      if let began = whereAZoomBegan[id], began.frame.approximatelyEquals(window.frame, tolerance: 4) {
        endLettingBe(id)
        scheduleEnforce(home)
        continue
      }
      let destination = displayID(at: window.frame.center) ?? home
      guard let visible = display(destination)?.visibleFrame else { continue }
      if act == .clickOrKey, destination != home || !hasTheSizeOfItsSlot(window) && MacTiling.isTile(window.frame, of: visible) {
        if hasTheSizeOfItsSlot(window, asFarAsItFits: visible.size) { inTheSizeOfItsSlot.insert(id) }
        out.append((id, home, destination))
      } else {
        // Once an act, when it is over, where the window is. Arbor knows who did it only where it heard the double-click and the window
        // grew, or the frame says so.
        let slot = layouts[home]?.windowFrames[id]
        let grew = slot.map { window.frame.width > $0.width + 4 || window.frame.height > $0.height + 4 } ?? false
        teach(act == .doubleClick && grew || MacTiling.fillsTheScreen(window.frame, of: visible) ? .zoomedByMacOS : .leftAsItIs, on: destination)
        scheduleSave()
      }
    }
    guard !out.isEmpty else { return }
    // macOS arranges two windows side by side at one command: one step to undo, and one layout, so that no neighbour is asked twice.
    recordingUndo("macOS tiled \(out.map { "\($0.window)" }.joined(separator: " and "))", title: "Float") {
      var changed: [DisplayID] = []
      for (id, _, destination) in out {
        endLettingBe(id)
        // Of a floating window that says "where Arbor put it", and Arbor feels free to move such a window out of the way.
        settled[id] = nil
        Log.info("\(id) is in one of macOS’s tiles, or on another display: it leaves the arrangement")
        // In a size macOS gave it nothing is set on it. In its slot's it gets its own, as if a hand had let go of the middle of its title bar.
        let hover = Hover(display: destination, target: .float, leftToMacOS: inTheSizeOfItsSlot.contains(id) ? nil : .side)
        for display in finishDrop(id, on: hover, at: windows[id].map(Self.middleOfTheTitleBar), settling: false, whole: true)
        where !changed.contains(display) { changed.append(display) }
      }
      placedOnPurpose = Set(out.map(\.window))
      defer { placedOnPurpose = [] }
      settle(Reflow(), layingOut: changed)
      for (id, home, _) in out { soleFloatDropped(id, from: home, leftToMacOS: true) }
    }
  }

  /// Whether a window that is let be is still as large as it stood in its slot: macOS, or its app, has moved it and given it no size.
  /// `asFarAsItFits`: on a smaller display macOS cuts what does not fit, which is no size anybody asked for either.
  func hasTheSizeOfItsSlot(_ window: WindowSnapshot, asFarAsItFits room: CGSize? = nil) -> Bool {
    guard var stood = whereAZoomBegan[window.id]?.frame.size ?? workspaceID(containing: window.id).flatMap({ layouts[$0]?.windowFrames[window.id]?.size })
    else { return false }
    if let room { stood = CGSize(width: min(stood.width, room.width), height: min(stood.height, room.height)) }
    return abs(window.frame.width - stood.width) <= 4 && abs(window.frame.height - stood.height) <= 4
  }

  /// A pause came before Arbor had looked where the act ended, and the resume has let the window be again. Nobody is let be on another display
  /// than its own: it is looked at now.
  func judgeWhatThePauseCutShort(_ window: WindowID) {
    guard let frame = windows[window]?.frame, let lies = displayID(at: frame.center), lies != workspaceID(containing: window) else { return }
    actsOfMacOS[window] = .clickOrKey
    waitForTheActsOfMacOSToEnd()
  }

  static func middleOfTheTitleBar(of window: WindowSnapshot) -> CGPoint { CGPoint(x: window.frame.midX, y: window.frame.minY + 12) }

  /// Called wherever a hand lets go of a window, or of its edge.
  func aHandWasOn(_ window: WindowID) {
    // A window that closes in the hand ends its drag too.
    if windows[window] != nil { handWasOn[window] = now() }
  }

  func forgetTheActsOfMacOS() {
    actsOfMacOS = [:]
    handWasOn = [:]
    laidOutAt = [:]
    scheduler.cancel(Self.actOfMacOSKey)
  }
}
