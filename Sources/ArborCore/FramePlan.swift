import CoreGraphics

/// Which Accessibility attributes to set, to what and in which order, to give a window a frame.
///
/// Size and place are two askings, and a display shows the state between them for a frame or more. So that state lies within the frame the
/// window had or within the one it is to have, and covers nothing that neither covers (collab/BOARD.md, 0.18): filmed, "the new size at the old
/// place" was a window over its neighbours, or hanging off the screen, at every dock.
public enum FramePlan {
  public enum Step: Equatable, Sendable {
    case size(CGSize)
    case position(CGPoint)
  }

  /// Which order of calls this is. macOS reports every call that changed something, so how many reports a recording holds depends on the
  /// order in force when it was made, and a trace's header says which that was. 1: size, position, size for every change of size.
  public static let version = 2

  /// For a window of which nothing is known. Size, position, size: the first resize keeps a large window from being clamped when it moves
  /// to a smaller display, the second applies the size the destination allows. Seen on a hosted Mac (macOS 26, a probe of four orders of
  /// calls, 466 journeys, Arbor not running): the position call itself cuts a window higher than the visible frame of the display it is sent
  /// to, and puts it at that frame's top: 12,43 1000×650 sent to -788,43 on a display 800×600 took -788,31 1000×569. Moved first and sized
  /// after, it then ended 812 wide for 776, or, with that display below, 12 points too high. Sized first it ended right.
  public static func full(to target: CGRect) -> [Step] { [.size(target.size), .position(target.origin), .size(target.size)] }

  /// The steps from the frame the window is believed to have.
  ///
  /// What shrinks is sized first, where the window is: that lies within the old frame. Then it is moved, no larger either way than it is
  /// to be: that lies within the new one. What grows is sized last. So a window that only shrinks or only grows needs two calls, one that gets
  /// wider and shorter three. It is never larger on the way than at either end, so no display clamps it, and it grows where it ends up,
  /// to what that display allows. In that probe this order ended as size, position, size did wherever both were tried: whole in 15 of 15
  /// journeys on one display, on the way to a smaller display, and up to their own limits on five real apps.
  ///
  /// A window that only changes place, as every window does when it is parked and most do when they come back, needs one call, and
  /// its app is spared laying out its content for a size it already has. The belief can be out of date, so the caller reads the frame
  /// back and goes by `makingUp`.
  ///
  /// One exception. macOS cuts what grows at the edge of the display the window is on, so a window cannot grow INTO a frame that hangs over
  /// that edge, as a person's own floating window may: moved first, 480×348 asked to be 495×400 at 530,43 on a display 1024 wide ended 494
  /// wide, and whole by size, position, size, which sizes it where there is room (a hosted Mac, macOS 26; the right edge was measured, the
  /// bottom follows from the same rule). No later call mends that. So a window that grows into a frame that lies in none of `rooms` gets
  /// the full plan (`growsWhereItCannot`), and shows its new size at its old place as every window used to: a size lost for good is worse
  /// than a frame seen for a moment. `rooms` is asked for only if the window grows. The full plan sizes it at the old place, where it is cut
  /// as well if there is no room there either; then no order of these calls gets it whole (collab/BOARD.md, 0.22).
  public static func steps(from known: CGRect?, to target: CGRect, rooms: @autoclosure () -> [CGRect]? = nil) -> [Step] {
    guard let known else { return full(to: target) }
    // Less than half a point is no difference: then it is the size asked for, so that a plan that sets a size ends at that very size.
    func lesser(_ had: CGFloat, _ wanted: CGFloat) -> CGFloat { abs(had - wanted) < 0.5 ? wanted : min(had, wanted) }
    let least = CGSize(width: lesser(known.width, target.width), height: lesser(known.height, target.height))
    let grows = differ(least, target.size)
    if grows, let rooms = rooms(), growsWhereItCannot(from: known, to: target, rooms: rooms) { return full(to: target) }
    var steps: [Step] = []
    if differ(least, known.size) { steps.append(.size(least)) }
    steps.append(.position(target.origin))
    if grows { steps.append(.size(target.size)) }
    return steps
  }

  /// The exception by itself, for whoever judges the road a window takes or wants to do better by such a window: it grows, and its new frame
  /// lies within no display's room.
  public static func growsWhereItCannot(from known: CGRect, to target: CGRect, rooms: [CGRect]) -> Bool {
    (target.width - known.width >= 0.5 || target.height - known.height >= 0.5)
      && !rooms.contains { $0.insetBy(dx: -0.5, dy: -0.5).contains(target) }
  }

  /// Where on a display a window can grow whole: as far as the display's right edge, and down to the bottom of its visible frame. (With the
  /// Dock at the bottom it stops a point short of that, by every order of calls.)
  public static func room(onDisplay frame: CGRect, visible: CGRect) -> CGRect {
    CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: visible.maxY - frame.minY)
  }

  private static func differ(_ a: CGSize, _ b: CGSize) -> Bool { abs(a.width - b.width) >= 0.5 || abs(a.height - b.height) >= 0.5 }

  /// The frames a window that does as it is asked has after each of `steps`.
  public static func states(from known: CGRect, after steps: [Step]) -> [CGRect] {
    var frame = known
    return steps.map { step in
      switch step {
      case .size(let size): frame.size = size
      case .position(let origin): frame.origin = origin
      }
      return frame
    }
  }

  /// What has to follow a plan once the frame has been read back, if anything: the belief the plan was made from may have been wrong.
  ///
  /// It never asked for the size, which was thought to be right, and the window turned out to have another: the full plan.
  ///
  /// It asked for the size only before the move, of a window thought to shrink, and the window is smaller than asked: the size once more, where
  /// the window is now. It may have been smaller than thought, so that the call made it grow, at the old place, where macOS cuts what does
  /// not fit. Or its app rounds down, as a terminal does to whole cells, and will say the same again: that cannot be told apart, and costs
  /// the third call that every change of size used to cost. An app that refuses to shrink stays larger, and is not asked again. Nor is one
  /// that was asked for the size where it ends up.
  public static func makingUp(for steps: [Step], result: CGRect, target: CGRect) -> [Step]? {
    guard abs(result.width - target.width) > 1 || abs(result.height - target.height) > 1 else { return nil }
    let asked = steps.contains { if case .size(let size) = $0 { !differ(size, target.size) } else { false } }
    guard asked else { return full(to: target) }
    guard case .position = steps.last, result.width < target.width - 1 || result.height < target.height - 1 else { return nil }
    return [.size(target.size)]
  }
}

extension FramePlan {
  /// Whether an answer short of the size that was asked for says nothing about the app: macOS cut it, at the place where the window stood.
  ///
  /// A size call that makes a window grow stops where the window's bottom comes to the visible frame's bottom less 1, and its right edge to the
  /// display's; what decides is where the window is when the call arrives (measured on macOS 26). Less 1 with the Dock at the bottom: with
  /// the Dock at the left or hidden it is the display's bottom itself, which the point either way below allows for. What grows is moved first, which leans on the
  /// move having been carried out by then. An app that answers at once and acts a moment later is still at the old place, and its answer is
  /// the room there. Taken for a refusal it would be remembered, and the window be short for good.
  ///
  /// Nobody calls this yet. It is for whoever learns from answers: learn nothing from such an answer, and ask ONCE more where the window is by
  /// then. Once, because it cannot tell everything apart: an app's own limit within a point of the room looks like a cut, so does a fixed size
  /// on the line, and a refusal one way is covered by a cut the other way. Only what was asked to grow can have been cut. The second answer is taken for what it says. And a window caught
  /// half way, because its app animates, has the room of neither place: that is not seen here.
  ///
  /// `stoodAt` is the frame it had before, `visibleBottom` and `rightEdge` are those of the display it stood on.
  ///
  /// There is a second way to such an answer. For a moment after a position call has taken a window to another display, a size call is still
  /// judged by the display it came from, whatever the order of calls: back from a display 800×600 to 12,43 1000×650 it took 1000×557, or
  /// 788×650 with that display below. Asked with the place it was moved TO and the edges of the display it came FROM, this says so too.
  public static func wasCutWhereItStood(
    answer: CGSize, asked: CGSize, stoodAt old: CGRect, visibleBottom: CGFloat, rightEdge: CGFloat
  ) -> Bool {
    func cut(_ took: CGFloat, _ wanted: CGFloat, _ had: CGFloat, room: CGFloat) -> Bool {
      // Asked to grow, it took less than asked, and as much as there was room for. A point either way: the Dock's edge moves before anybody is told.
      wanted > had + 1 && took < wanted - 1 && abs(took - room) <= 1
    }
    return cut(answer.height, asked.height, old.height, room: visibleBottom - 1 - old.minY)
      || cut(answer.width, asked.width, old.width, room: rightEdge - old.minX)
  }
}
