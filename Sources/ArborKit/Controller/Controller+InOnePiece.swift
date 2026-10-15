import ArborCore
import CoreGraphics

/// At once, and in one piece (collab/BOARD.md, 0.18).
///
/// Windows are asked one after another, and without motion a display shows every state in between. So the order is chosen for what is to
/// be seen on the way: as little ground as an order can help is bare meanwhile that windows cover before and after. What arrives or grows
/// comes first, over what is still there; what crosses, lying within neither its slot nor around it, comes next; what shrinks comes after
/// that, and uncovers what has arrived; what leaves goes last, from behind what has grown. Within one window the same holds of size and
/// place (`FramePlan`). Where windows cross, each going to ground another has yet to leave, no order has been found that bares nothing.
///
/// `apply` asks in this order and `movesInSight` foretells in it. A window system that moves windows together lets apps work side by side and
/// keeps no order between them. So the one order that must hold between apps is kept by two forecasts: those who stay, and, when they
/// have their frames, those who leave (`leavesInSight`).
///
/// It is an order of askings, and no more. Those who leave were asked after the one that grows before this order was made, and were filmed
/// leaving first all the same: hence the wait (`waitForWhatGrew`).
extension Controller {
  /// After how long no further look is taken for what has grown: three frames of a display that shows sixty a second.
  public static let longestWaitForWhatGrew = 0.05

  /// A TRIAL, to be judged by a film. The windows that leave, though asked last, were seen to go first, and the desk showed through until the
  /// one that fills the screen had grown. A guess at the cause: a new place shows at once, a new size when the app has drawn itself in it, which
  /// is after it has answered. So before `apply` sends windows away Arbor stands still until the window server lists what has grown at the
  /// frame it answered with. If nothing has grown it does not. An arrival that keeps its size is a place alone, and is not waited for.
  /// Whether what is listed is what is shown nobody has measured either.
  ///
  /// `sizes`: those of the windows the layout shows, before it was applied.
  func waitForWhatGrew(in layout: Layout, since sizes: [WindowID: CGSize]) {
    let grown = layout.windowFrames.keys.sorted().compactMap { window -> (window: WindowID, frame: CGRect)? in
      guard let now = windows[window]?.frame, let before = sizes[window] else { return nil }
      return now.width > before.width + 1 || now.height > before.height + 1 ? (window, now) : nil
    }
    if !grown.isEmpty { system.waitUntilListed(grown, atMost: Self.longestWaitForWhatGrew) }
  }

  /// The docked windows a layout shows, with their slots, in the order in which they are asked.
  func inOnePiece(_ slots: [WindowID: CGRect]) -> [(window: WindowID, slot: CGRect)] {
    func turn(_ window: WindowID, _ slot: CGRect) -> Int {
      // Out of view, it arrives.
      guard let frame = windows[window]?.frame, !parked.contains(window) else { return 0 }
      if slot.insetBy(dx: -1, dy: -1).contains(frame) { return 0 }
      return frame.insetBy(dx: -1, dy: -1).contains(slot) ? 2 : 1
    }
    return slots.map { (window: $0.key, slot: $0.value, turn: turn($0.key, $0.value)) }
      .sorted { ($0.turn, $0.window) < ($1.turn, $1.window) }.map { ($0.window, $0.slot) }
  }
}
