import ArborCore
import ArborKit
import CoreGraphics

/// "At once, and in one piece" (collab/BOARD.md, 0.18), read off the fake's `moveLog`.
///
/// Without motion nothing hides the road: windows are asked one after another, size and place are two askings, and a display shows every state
/// in between for a frame or more. Filmed on a hosted Mac, that was a window at its new size in its old place, over the others, and holes in
/// the arrangement where windows had left before the one that fills the screen had grown. Two things must not be seen between the first
/// asking of an act and the last:
/// - **a stray**: a window that lies neither within the frame it had nor within the frame it ends with, so that it covers what neither covers;
/// - **a hole**: ground that windows cover before the act and after it, and that nothing covers once one window has its frame and the next has not
///   been asked.
///
/// Each asking is taken apart as the Accessibility layer takes it apart (`FramePlan`), so the states are the ones a Mac would show.
///
/// One asking is let off, by the predicate the layer itself goes by (`FramePlan.growsWhereItCannot`): a window that grows into a frame that lies
/// within no display, as a person's own floating window may. macOS cuts what grows at the display's edge, so it is sized first, at its old
/// place: a size lost for good is worse than a frame seen for a moment (the ruling's exception). What is let off are the states between the calls of
/// that one asking. Where it leaves the window is judged like any other: an asking that only makes a window grow where it stands gets nothing by it.
public enum NotInOnePiece: Equatable, Sendable, CustomStringConvertible {
  case stray(window: WindowID, from: CGRect, at: CGRect, to: CGRect)
  case hole(CGRect, afterAsking: WindowID)

  public var description: String {
    switch self {
    case .stray(let window, let from, let at, let to):
      "\(window) was at \(at.brief) on its way from \(from.brief) to \(to.brief), within neither"
    case .hole(let ground, let window): "\(ground.brief) was bare once \(window) had been asked, and is covered before and after"
    }
  }
}

extension FakeWindowSystem {
  /// What was to be seen that should not have been, among the moves Arbor has made since the move log was `mark` long.
  public func notInOnePiece(since mark: Int) -> [NotInOnePiece] {
    let moves = moveLog[min(mark, moveLog.count)...].filter { $0.before != $0.after }
    guard !moves.isEmpty else { return [] }
    // Where everything was when the act began: where it is now, with Arbor's moves undone.
    var frames: [WindowID: CGRect] = [:]
    for (id, fake) in windows where fake.snapshot.isPresent { frames[id] = fake.snapshot.frame }
    let after = frames
    for move in moves.reversed() where frames[move.window] != nil { frames[move.window] = move.before }
    let before = frames

    var found: [NotInOnePiece] = []
    func note(_ problem: NotInOnePiece) { if !found.contains(problem) { found.append(problem) } }
    let ground = Self.cells(of: Array(before.values) + Array(after.values) + moves.flatMap { [$0.before, $0.after] }, on: displayList)
      .filter { cell in before.values.contains { $0.contains(cell) } && after.values.contains { $0.contains(cell) } }

    let rooms = displayList.map { FramePlan.room(onDisplay: $0.frame, visible: $0.visibleFrame) }
    for (index, move) in moves.enumerated() where frames[move.window] != nil {
      let isLetOff = FramePlan.growsWhereItCannot(from: move.before, to: move.requested, rooms: rooms)
      for state in Self.states(of: move, rooms: rooms) {
        frames[move.window] = state
        guard let from = before[move.window], let to = after[move.window] else { continue }
        // What no display shows is seen by nobody.
        let shown = displayList.map { state.intersection($0.frame) }.filter { !$0.isNull && $0.width > 2 && $0.height > 2 }
        if !(isLetOff && state != move.after), !shown.allSatisfy({ from.insetBy(dx: -1, dy: -1).contains($0) || to.insetBy(dx: -1, dy: -1).contains($0) }) {
          note(.stray(window: move.window, from: from, at: state, to: to))
        }
        // Between the two askings of one window its own ground may be bare: one that grows is moved first, and has left where it was. It cannot both
        // lie within its frames and go on covering its old place, and lying over what neither frame covers is the worse of the two (the ruling).
        // So holes are looked for when a window has its frame. The last one's is the end of the act.
        guard state == move.after, index < moves.count - 1 else { continue }
        // One hole for a state, however many pieces it is in: the rectangle around all that is bare.
        let bare = ground.filter { cell in !frames.values.contains { $0.contains(cell) } }
        if let first = bare.first { note(.hole(bare.dropFirst().reduce(first) { $0.union($1) }, afterAsking: move.window)) }
      }
    }
    return found
  }

  /// The frames a window has, one after another, while the Accessibility layer gives it a frame: after each attribute it sets. The plan is made for
  /// the frame that was asked for, as the layer makes it. They are the states of a window that does as it is asked; the last is what it took.
  public static func states(of move: Move, rooms: [CGRect]) -> [CGRect] {
    var states: [CGRect] = []
    let plan = FramePlan.steps(from: move.before, to: move.requested, rooms: rooms)
    for state in FramePlan.states(from: move.before, after: plan).dropLast() where state != states.last ?? move.before { states.append(state) }
    return states + [move.after]
  }

  /// The displays cut along every edge of `frames`: within one cell everything is covered alike. Slivers, which are gaps and rounding, are left out.
  private static func cells(of frames: [CGRect], on displays: [DisplaySnapshot]) -> [CGRect] {
    var cells: [CGRect] = []
    for display in displays.map(\.frame) {
      let xs = Set(frames.flatMap { [$0.minX, $0.maxX] } + [display.minX, display.maxX]).filter { $0 >= display.minX && $0 <= display.maxX }.sorted()
      let ys = Set(frames.flatMap { [$0.minY, $0.maxY] } + [display.minY, display.maxY]).filter { $0 >= display.minY && $0 <= display.maxY }.sorted()
      for (left, right) in zip(xs, xs.dropFirst()) where right - left > 4 {
        for (top, bottom) in zip(ys, ys.dropFirst()) where bottom - top > 4 {
          cells.append(CGRect(x: left, y: top, width: right - left, height: bottom - top))
        }
      }
    }
    return cells
  }
}
