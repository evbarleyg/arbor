import ArborCore
import CoreGraphics
import Foundation

/// What Arbor learns about a window's size can be unlearned (docs/features/F45-learned-sizes-expire.md).
///
/// A window that ends up larger than its slot has that size recorded as its minimum (`minimumSizes`), and is a
/// tile in any smaller slot from then on. But a refusal is not always a property of the window: a sheet
/// was open, the app was busy, a sidebar was showing. There are three ways out of a wrong record:
/// - the window is seen smaller than the record (`lowerDisprovedMinimum`, Controller+Layout.swift);
/// - `relayout` forgets every record and tries in view (`forgetLearnedMinimums`);
/// - and, here, **the window is asked again where nobody can see**. A window that is a tile is out of view
///   anyway, so now and then a layout asks it, in its corner, to take the size of the slot that is waiting for
///   it. If it does, the record goes and it gets its slot. If not, it stays a tile. Nothing flickers either way.
///   A window that is still in view when a layout would make a tile of it is asked before it leaves, where it is.
extension Controller {
  /// A record in `minimumSizes`, and when the window last stood by it.
  struct ConfirmedSize {
    var size: CGSize
    var at: Date
  }

  /// Called by `relayout` once `layout` has been applied, so every window of a tile is in its corner. Asks the
  /// windows that are tiles in it because of a record older than `tileRetryMinutes`. Returns true if a record
  /// changed, so that the display should be laid out again.
  func askTilesAgain(_ layout: Layout, on displayID: DisplayID) -> Bool {
    // Nearly always: nothing was ever refused.
    guard !minimumSizes.isEmpty || !confirmedSizes.isEmpty else { return false }
    let now = self.now()
    // Several places write records. Whoever did, a record that is new or has changed held a moment ago.
    confirmedSizes = confirmedSizes.filter { minimumSizes[$0.key] != nil }
    for (window, size) in minimumSizes where confirmedSizes[window]?.size != size {
      confirmedSizes[window] = ConfirmedSize(size: size, at: now)
    }

    guard let display = display(displayID) else { return false }
    var changed = false
    for (window, slot) in tilesToAsk(in: layout, on: displayID) where parked.contains(window) {
      if ask(window, toTake: slot.size, on: display) { changed = true }
    }
    return changed
  }

  /// Called by `relayout` before `layout` is applied. A window that is in view and would be a tile in `layout` because of
  /// a record that old would go to its corner, be asked there, and, if the record was wrong, come straight back,
  /// all in one layout and for everyone to see. So it is asked first, where it is, to shrink to the size of the slot: that
  /// way it covers nothing that it does not cover already. Returns true if a record changed, so that
  /// `layout` no longer holds.
  ///
  /// The window being typed in is no tile in `layout` whatever its record says: its neighbours are, for its sake
  /// (F61). Before they pay with their places for a record that old, it is asked the same, for the slot it has in
  /// `before`, the workspace as this layout found it.
  func askBeforeTheyLeave(_ layout: Layout, on displayID: DisplayID, startingFrom before: Workspace? = nil) -> Bool {
    guard !confirmedSizes.isEmpty, let shown = layouts[displayID]?.windowFrames else { return false }
    var changed = false
    var toAsk = tilesToAsk(in: layout, on: displayID)
    if let before, let typedIn = keyboardFocus(), layout.windowFrames[typedIn] != nil, let display = display(displayID) {
      let (present, minimums) = (presentWindowIDs(), minimumSizes)
      let plain = LayoutEngine.layout(
        before.tree, camera: before.camera, in: display.visibleFrame, options: options(for: displayID).layoutOptions,
        isPresent: { present.contains($0) }, minimumSize: { minimums[$0] })
      if plain.windowFrames.keys.contains(where: { layout.windowFrames[$0] == nil }) {
        toAsk += tilesToAsk(in: plain, on: displayID).filter { $0.window == typedIn }
      }
    }
    for (window, slot) in toAsk
    where shown[window] != nil && !parked.contains(window) && !enforcement.givenUp.contains(window) {
      if askInView(window, toTake: slot.size) { changed = true }
    }
    return changed
  }

  /// The windows that are tiles in `layout` because of a record older than `tileRetryMinutes`, and the slots that wait for them.
  private func tilesToAsk(in layout: Layout, on displayID: DisplayID) -> [(window: WindowID, slot: CGRect)] {
    let interval = settings.tileRetryMinutes * 60
    // A tile that turns into a window would change the drop targets under the pointer. During a call or on a
    // shared screen it would put a window's contents where there was an icon, and nobody asked (Controller+Hold.swift).
    guard interval > 0, !isHeld, drag == nil, edgeResize == nil, let view = treeView(displayID) else { return [] }
    let now = self.now()
    let usable = options(for: displayID).layoutOptions.minimumUsableSize
    return layout.tiles.compactMap { tile in
      // A slot too small to use makes a tile of any window.
      guard tile.kind == .window, tile.frame.width >= usable.width - 0.5, tile.frame.height >= usable.height - 0.5,
        let window = view.visibleWindow(of: tile.node), let record = confirmedSizes[window],
        // A record that has changed since is as good as new.
        record.size == minimumSizes[window],
        // Either way, so that a clock that was set back does not silence the question.
        abs(now.timeIntervalSince(record.at)) >= interval
      else { return nil }
      return (window, tile.frame)
    }
  }

  /// Asks a window in view to shrink to `size` where it is. Returns true if its record changed.
  private func askInView(_ window: WindowID, toTake size: CGSize) -> Bool {
    guard let learned = minimumSizes[window], let current = windows[window]?.frame else { return false }
    let question = CGRect(
      origin: current.origin, size: CGSize(width: min(current.width, size.width), height: min(current.height, size.height)))
    guard var actual = system.setFrame(question, of: window) else { return false }
    actual = askForLess(window, slot: question, took: actual)
    windows[window]?.frame = actual
    settled[window] = actual
    return judge(window, took: actual, asked: size, learned: learned)
  }

  /// What a window's answer does to its record. Returns true if the record changed.
  private func judge(_ window: WindowID, took actual: CGRect, asked size: CGSize, learned: CGSize) -> Bool {
    let tooWide = actual.width > size.width + 2
    let tooTall = actual.height > size.height + 2
    guard tooWide || tooTall else {
      Log.debug("\(window) takes the size of its slot after all; forgetting that it refused")
      minimumSizes[window] = nil
      confirmedSizes[window] = nil
      misfits[window] = nil
      return true
    }
    // The record stands, with what was just seen: it may have come down, if not far enough for this slot.
    let seen = CGSize(width: tooWide ? actual.width : 0, height: tooTall ? actual.height : 0)
    minimumSizes[window] = seen
    confirmedSizes[window] = ConfirmedSize(size: seen, at: now())
    Log.debug("\(window) still refuses the size of its slot")
    return seen != learned
  }

  /// Asks a parked window to take `size` where it is parked. Returns true if its record changed.
  private func ask(_ window: WindowID, toTake size: CGSize, on display: DisplaySnapshot) -> Bool {
    guard let learned = minimumSizes[window] else { return false }
    // The corner to the left of a display depends on the window's width: one that stays wider than it
    // was asked to be would reach into view. So it is placed as if it kept the width on record.
    let atWorst = CGSize(width: max(size.width, learned.width), height: max(size.height, learned.height))
    let question = CGRect(origin: parkingOrigin(for: atWorst, of: window, on: display), size: size)
    guard var actual = system.setFrame(question, of: window) else { return false }
    // A character cell too large is not a refusal (Controller+SizeSteps.swift). What is asked next is smaller, in the same corner.
    actual = askForLess(window, slot: question, took: actual)
    if actual.width > size.width + 2 || actual.height > size.height + 2 {
      // It stays a tile, with one point on screen like every window out of view.
      let corner = parkingOrigin(for: actual.size, of: window, on: display)
      if abs(actual.minX - corner.x) > 1 {
        actual = system.setFrame(CGRect(origin: corner, size: actual.size), of: window) ?? actual
      }
    }
    windows[window]?.frame = actual
    settled[window] = actual
    return judge(window, took: actual, asked: size, learned: learned)
  }
}
