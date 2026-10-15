import ArborCore
import CoreGraphics

/// Windows that come in steps. Terminal sizes its windows in whole character cells and takes the size
/// nearest to the one it is asked for, which half the time is the larger one: asked for 624 × 947 it took
/// 621 × 954. Seven points too tall is not a window that
/// refuses its slot, but it was read as one, so pressing ⌘+ in a docked Terminal turned it into a tile.
///
/// Nor is it to be seen every time. Offered the same slot again, Terminal grew a line past it again and was talked down again: at every
/// return of the view. So what the talking down shows is kept (`Cells`): the step the window came down by is its cell. From then on it is
/// asked for the whole cells that fit the slot, which it takes as they are. What is asked for is worked out from the slot each time,
/// never from the size the window happens to have. What is left of the slot, less than a cell, stays at the right and at the
/// bottom, where the app leaves it by itself: the window has its slot, and nobody is moved or asked on its account.
extension Controller {
  /// No step is larger than this: character cells at a very large font.
  private static let largestStep = Cells.largest

  /// The frame to ask of `window` so that it fills `slot` and does not reach out of it.
  func fitted(_ slot: CGRect, for window: WindowID) -> CGRect {
    CGRect(origin: slot.origin, size: seenSizes[window]?.cells.fitting(slot.size) ?? slot.size)
  }

  /// Offers `window` the `slot`, and talks it down if it takes a little more. Returns the frame it ended at, nil if its app does
  /// not answer.
  func offer(_ slot: CGRect, to window: WindowID) -> CGRect? {
    let request = fitted(slot, for: window)
    guard let took = system.setFrame(request, of: window) else { return nil }
    return askForLess(window, slot: slot, took: offeredAnew(window, slot, unlessItTook: request, took: took))
  }

  /// `window` was asked for the whole cells that fit `slot`, and `took` this. If that is something else, its cells are others by now
  /// (another font): they are forgotten, and it is offered the slot like a window of which nothing is known.
  func offeredAnew(_ window: WindowID, _ slot: CGRect, unlessItTook request: CGRect, took: CGRect) -> CGRect {
    guard seenSizes[window]?.cells.forgetUnless(asked: request.size, wasTakenAs: took.size) == true else { return took }
    return system.setFrame(slot, of: window) ?? took
  }

  /// Where a window that is `size` large when it has been offered `slot` belongs in it. One that cannot grow (Calculator, System
  /// Settings) sits in the middle, which looks meant. One that is short of its slot by less than a cell has filled it, and
  /// stays in the corner, where its app left it.
  func restingFrame(of window: WindowID, _ size: CGSize, in slot: CGRect) -> CGRect {
    let (cells, stoppedAt) = (seenSizes[window]?.cells ?? Cells(), seenSizes[window]?.stoppedAt ?? .zero)
    var frame = Self.centred(size, in: slot)
    // Not one that is known to grow no further: it would leap from the corner to the middle where its slot grows past a cell.
    if stoppedAt.width == 0 || size.width > stoppedAt.width + 2, cells.width.explains(short: slot.width - size.width) {
      frame.origin.x = slot.minX
    }
    if stoppedAt.height == 0 || size.height > stoppedAt.height + 2, cells.height.explains(short: slot.height - size.height) {
      frame.origin.y = slot.minY
    }
    return frame
  }

  /// Called when `window` was offered `slot` and `took` another frame. If it came out a little larger than
  /// the slot, asks for less, and less again, until it takes the step below. Returns the frame it ended
  /// at. A window that stays too large has a real minimum, and the caller learns it as before.
  func askForLess(_ window: WindowID, slot: CGRect, took: CGRect) -> CGRect {
    var took = took
    var less = CGSize.zero
    // By how much it came down, each way, the last time it did; and all it has been asked for.
    var step = CGSize.zero
    var asked = [slot.size, fitted(slot, for: window).size]
    // Not the cells it was taken to have: another font.
    seenSizes[window]?.cells.see(took.size)
    // An app that takes the nearest step gives way once it is asked for half a step less, one that rounds up once
    // it is asked for a whole step less. The step is unknown, so what is held back doubles, up to the largest
    // step there is: a window that was asked for that much less and did not budge has a real minimum.
    for _ in 0..<4 {
      let over = CGSize(width: took.width - slot.width, height: took.height - slot.height)
      guard over.width > 2 || over.height > 2, max(over.width, over.height) <= Self.largestStep else { break }
      let before = less
      if over.width > 2 { less.width = min(max(less.width, over.width) * 2, Self.largestStep) }
      if over.height > 2 { less.height = min(max(less.height, over.height) * 2, Self.largestStep) }
      guard less != before else { break }
      // The way it is not too large it is asked for what it was asked for before. Offered the whole slot, it would be too large that way next.
      let whole = fitted(slot, for: window).size
      let request = CGRect(
        x: slot.minX, y: slot.minY, width: max(min(slot.width - less.width, whole.width), 1),
        height: max(min(slot.height - less.height, whole.height), 1))
      guard let next = system.setFrame(request, of: window) else { break }
      asked.append(request.size)
      if next.width < took.width - 0.5 { step.width = took.width - next.width }
      if next.height < took.height - 0.5 { step.height = took.height - next.height }
      took = next
    }
    if took.width > slot.width + 2 { step.width = 0 }
    if took.height > slot.height + 2 { step.height = 0 }
    return step == .zero ? took : afterTalkingDown(window, by: step, into: slot, took: took, asked: asked)
  }

  /// `window` took more than its slot and has been talked down `by` a step. A terminal, or a window that was busy or slow when it was
  /// first asked and takes any size? The second is now short of its slot for nothing.
  /// - What it has now is nothing it was `asked` for: no slowness explains that. It comes in cells, and the step is its cell.
  /// - It is what it was asked for earlier in this round: it is slow. It is offered its slot again.
  /// - It is what it was asked for last. Either could be. So it is asked for a point less than it has: a terminal does not budge, and
  ///   nobody sees the question; one that gives the point is offered its slot again. (A point less, not more: how far a window
  ///   can grow where it stands is also up to macOS, which stops it at the edges of the screen.)
  private func afterTalkingDown(_ window: WindowID, by step: CGSize, into slot: CGRect, took: CGRect, asked: [CGSize]) -> CGRect {
    enum Verdict { case untouched, cells, ordinary, open }
    func verdict(_ step: CGFloat, _ took: CGFloat, _ asked: [CGFloat]) -> Verdict {
      guard step > 0 else { return .untouched }
      if abs(asked[asked.count - 1] - took) <= 0.5 { return .open }
      return asked.contains { abs($0 - took) <= 0.5 } ? .ordinary : .cells
    }
    guard let now = windows[window]?.frame.size else { return took }
    var (width, height) = (verdict(step.width, took.width, asked.map(\.width)), verdict(step.height, took.height, asked.map(\.height)))
    var result = took
    if width == .open || height == .open {
      let question = CGRect(
        origin: took.origin, size: CGSize(width: took.width - (width == .open ? 1 : 0), height: took.height - (height == .open ? 1 : 0)))
      guard let answer = system.setFrame(question, of: window) else { return took }
      // The point and no more: it takes what it is asked for. Anything else is some app's own way, and nothing is concluded.
      func settle(_ verdict: Verdict, _ answer: CGFloat, _ took: CGFloat) -> Verdict {
        guard verdict == .open else { return verdict }
        return abs(answer - took) <= 0.5 ? .cells : abs(took - 1 - answer) <= 0.5 ? .ordinary : .untouched
      }
      (width, height) = (settle(width, answer.width, took.width), settle(height, answer.height, took.height))
      result = answer
    }
    var seen = seenSizes[window] ?? SeenSizes(now)
    if step.width > 0 { seen.cells.width = width == .cells ? Cells.Side(cell: step.width, on: took.width) : Cells.Side() }
    if step.height > 0 { seen.cells.height = height == .cells ? Cells.Side(cell: step.height, on: took.height) : Cells.Side() }
    seenSizes[window] = seen
    let wanted = CGSize(width: width == .ordinary ? slot.width : took.width, height: height == .ordinary ? slot.height : took.height)
    guard abs(result.width - wanted.width) > 0.5 || abs(result.height - wanted.height) > 0.5 else { return result }
    return system.setFrame(CGRect(origin: slot.origin, size: wanted), of: window) ?? result
  }
}
