import ArborCore
import CoreGraphics

/// Floating means on top, as far as Arbor can see to that. macOS keeps no levels for other apps' windows: whichever was
/// clicked last is in front. So a floating window that cannot be made small enough for the Desktop, and that a layout
/// leaves hanging over a docked window, could end up behind it, with part of it out of reach (backlog K087).
///
/// Arbor brings it to the front then, and only then: when the layout itself has just moved it there. The keyboard stays
/// where it is. And not over the window that has the keyboard, which is the one just clicked, docked or typed in:
/// covering part of that would be worse than being covered by it.
extension Controller {
  /// Called by `placeFloatingWindows` for a window it has just moved to `frame`.
  func raiseIfLeftHangingOverDockedWindows(_ window: WindowID, at frame: CGRect, in layout: Layout) {
    // The gap around a slot is nobody's; a point or two is rounding.
    let covered = layout.windowFrames.filter { $0.value.insetBy(dx: 2, dy: 2).overlaps(frame) }.map(\.key)
    guard !covered.isEmpty, system.focusedWindow().map({ !covered.contains($0) }) ?? true else { return }
    // Nothing changes places in front of an audience that nobody asked for (Controller+Hold.swift).
    guard mayShowUnasked else { return }
    // Raising asks its app, so not for nothing. If the order cannot be told, it is raised.
    let frontToBack = system.windowsFrontToBack()
    if let place = frontToBack.firstIndex(of: window),
      !covered.contains(where: { frontToBack.firstIndex(of: $0).map { $0 < place } ?? false })
    {
      return
    }
    system.raise(window)
    Log.debug("raised \(window), which was left hanging over docked windows")
  }
}
