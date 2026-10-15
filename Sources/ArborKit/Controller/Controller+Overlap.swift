import ArborCore
import CoreGraphics

/// A dock takes nobody out of view. Two apps whose smallest sizes do not fit side by side are the first thing many people
/// dock, and macOS alone would let them overlap and hide nothing. So as Arbor ships nothing in view becomes a tile: when room has
/// been made (F61) and is not enough, the window keeps its place in the arrangement, stands at its smallest size, flush with
/// the outer side of its place, and hangs over its neighbour. `windowsThatDoNotFit: tile` is how it was.
///
/// Where it stands is decided in `LayoutEngine` (`LayoutOptions.overlaps`, `Layout.overhangs`), who gets how much room in
/// `MakeRoom`; the tree, the shares and the ledger do not know of it. Which of two windows lies in front is macOS's business:
/// a click or ⌘Tab brings one forward as on any Mac, and moves and sizes nothing. Arbor brings forward only the window an act
/// names, by giving it the keyboard as every `dock` does (`focusIfShown`), and raises nobody else. It ends at a layout that
/// something else causes: a neighbour closes or floats, a larger display, the person's own hand.
extension Controller {
  /// How far a docked window in view hangs over its place, or nil if it is within it.
  func overhang(of window: WindowID) -> CGSize? {
    for layout in layouts.values { if let over = layout.overhangs[window] { return over } }
    return nil
  }

  /// The gaps that have a handle: those that can be reached (`Layout.seamsInReach`), and the one a hand is on. A gap dragged until a window stops
  /// following goes under that window, and the handle must not go from under the hand that holds it: it is what hears the mouse. Nobody tells
  /// Arbor that the button is up, so the handle goes two seconds after the gap last moved, or with the next layout that is not that hand's.
  func seamsWithAHandle(in layout: Layout, on display: DisplayID) -> [Seam] {
    let inReach = layout.seamsInReach
    guard let held = seamInHand, held.display == display else { return inReach }
    func isHeld(_ seam: Seam) -> Bool { seam.split == held.split && seam.leading == held.leading && seam.trailing == held.trailing }
    guard !inReach.contains(where: isHeld), let seam = layout.seams.first(where: isHeld) else { return inReach }
    return inReach + [seam]
  }

  func hold(_ seam: Seam, on display: DisplayID) {
    seamInHand = (display, seam.split, seam.leading, seam.trailing)
    scheduler.schedule("seam-in-hand", after: 2) { [weak self] in self?.letGoOfTheSeam() }
  }

  /// Shown at once: the layout that ends it may be another display's.
  func letGoOfTheSeam() {
    guard let held = seamInHand else { return }
    seamInHand = nil
    scheduler.cancel("seam-in-hand")
    if isRunning, let layout = layouts[held.display] {
      overlays.update(display: held.display, scene: overlayScene(for: layout, on: held.display))
      // A handle is a panel, and a press on it does not reach the wallpaper.
      desktopGuardZonesMayHaveChanged()
    }
  }

  /// Added to what `dock` says when the windows in view do not all fit.
  func overlapNote(on display: DisplayID) -> String {
    guard let over = layouts[display]?.overhangsOverWindows, !over.isEmpty else { return "" }
    return over.values.contains { $0.width > 0 }
      ? "; too wide to stand side by side, so they overlap" : "; too tall to stand one above the other, so they overlap"
  }
}
