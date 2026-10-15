import ArborCore
import CoreGraphics

/// The screen's answer is not the window's.
///
/// A call that sets a window's size makes it grow no further than to the bottom of the visible frame (less a point above a Dock) and the
/// right edge of its display, from where it stands at that moment; with its foot in the Dock's strip it does not grow at all. A call that
/// sets its position is not held back so (`ScreenLines`). So a window cannot grow into a frame that hangs over such a line once it stands
/// there, and what it answers is the room there was: 400×319 for a window of 400×600, let go low on the display. Written down as its own
/// size, that is what it got back from then on.
///
/// Into such a frame a window is sent with three calls, size, position, size (`FramePlan`), so one request will do wherever the size fits
/// where the window stands. Where it does not, the window is **sized where the size fits, and then only moved**.
///
/// The screen's answer can be the larger one as well. No size call puts a window's foot into the Dock's strip: one that hangs off the display, as a
/// window as high as its slot does when it is dragged out and let go low, comes in no further than the display's bottom, and once it has been
/// moved up, with its foot in the strip, it is held. 480×360 for a window of 480×348; written down, and 12 to 41 points more at every such drop.
extension Controller {
  /// What came of giving a window a frame.
  struct Given: Equatable {
    /// The frame it has.
    var frame: CGRect
    /// What to write down as its own: `frame`, but for a side that the screen kept short, which has the size that was asked for.
    var own: CGRect
  }

  /// Gives `window` the frame it is to have, which may hang over an edge of its display: what a hand left there, or its own size at the
  /// place where a hand let go of it. Nil if its app does not answer, and the window may then be anywhere on the way.
  ///
  /// For a frame that lies on the screen this is `setFrame`. A docked window's slot does, and `place` sees to its own.
  func give(_ frame: CGRect, to window: WindowID) -> Given? {
    let standing = windows[window]?.frame
    if let standing, whereItHasToBeSized(for: frame, from: standing) != nil || whereItCanShrink(to: frame, from: standing) != nil {
      lookAtTheDock(under: frame.origin)
      if let place = whereItHasToBeSized(for: frame, from: standing) { return size(window, at: place, for: frame, from: standing) }
      if let place = whereItCanShrink(to: frame, from: standing) { return shrink(window, at: place, to: frame, from: standing) }
    }
    guard let actual = system.setFrame(frame, of: window) else { return nil }
    windows[window]?.frame = actual
    guard actual.size != frame.size else { return Given(frame: actual, own: actual) }
    lookAtTheDock(under: actual.origin)
    // Judged where it was asked: there, and where it stood before, for an app may carry a move out late.
    let kept = sidesTheScreenKept(of: actual.size, shortOf: frame.size, at: [standing?.origin, actual.origin].compactMap { $0 })
    let given = Given(frame: actual, own: CGRect(origin: actual.origin, size: kept.own))
    // Cut after all: it did not stand where Arbor believed. Once more, from where it is now. Only if the answer ends on a line: held in the
    // Dock's strip a window has whatever size it came with, which may as well be all its app allows, and a hop would be for nothing.
    guard kept.endsOnALine else { return given }
    if let place = whereItHasToBeSized(for: frame, from: actual) { return size(window, at: place, for: frame, from: actual) }
    if let place = whereItCanShrink(to: frame, from: actual) { return shrink(window, at: place, to: frame, from: actual) }
    guard let again = system.setFrame(frame, of: window) else { return nil }
    windows[window]?.frame = again
    return Given(frame: again, own: CGRect(origin: again.origin, size: sidesTheScreenKept(of: again.size, shortOf: frame.size, at: [again.origin]).own))
  }

  private func size(_ window: WindowID, at place: CGPoint, for frame: CGRect, from standing: CGRect) -> Given? {
    guard let sized = system.setFrame(CGRect(origin: place, size: frame.size), of: window) else { return nil }
    windows[window]?.frame = sized
    // Judged here, where it was sized, and where it stood. Short of what was asked where there was room for it, that is its app's answer.
    let own = sidesTheScreenKept(of: sized.size, shortOf: frame.size, at: [standing.origin, sized.origin], longerToo: false).own
    // If its app has stopped answering half-way, it is not where it belongs, and whoever asked has to know. Where it is, is on record.
    guard let moved = system.setFrame(CGRect(origin: frame.origin, size: sized.size), of: window) else { return nil }
    windows[window]?.frame = moved
    return Given(frame: moved, own: CGRect(origin: moved.origin, size: moved.size == sized.size ? own : moved.size))
  }

  /// The other way round for a window that is to shrink: it is moved as it is to where it can, and from there one request does it, which sizes what
  /// shrinks first, where it stands, and then moves it (`FramePlan`). Sent there with its new size it would be sized where it stands now, which
  /// is what does not work, and a window that only shrinks is not sized again after the move.
  private func shrink(_ window: WindowID, at place: CGPoint, to frame: CGRect, from standing: CGRect) -> Given? {
    guard let moved = system.setFrame(CGRect(origin: place, size: standing.size), of: window) else { return nil }
    windows[window]?.frame = moved
    guard let actual = system.setFrame(frame, of: window) else { return nil }
    windows[window]?.frame = actual
    // Judged where it was sized. Larger than was asked there, where the screen holds nothing, that is its app's answer.
    let own = sidesTheScreenKept(of: actual.size, shortOf: frame.size, at: [moved.origin]).own
    return Given(frame: actual, own: CGRect(origin: actual.origin, size: own))
  }

  /// macOS does not say when the Dock has grown or shrunk, so a layout looks before it reckons (`refreshVisibleFrame`). So does whoever
  /// reckons with the Dock's line between two layouts.
  private func lookAtTheDock(under origin: CGPoint) {
    if let display = stopper(of: origin) { refreshVisibleFrame(of: display.id) }
  }

  /// What to write down as the own frame of a window that was asked for `size` where it stands and has `actual`. Also for a size that is only
  /// remembered, so a side that is longer is believed: nobody may have asked for less, and its person may have made it so.
  func ownFrame(of actual: CGRect, askedFor size: CGSize) -> CGRect {
    CGRect(origin: actual.origin, size: sidesTheScreenKept(of: actual.size, shortOf: size, at: [actual.origin], longerToo: false).own)
  }

  /// Which sides of a window that `took` another size than it was `asked` for the screen may have kept so: with its corner at one of `origins`,
  /// macOS lets it be no larger than it is, or no smaller. Each side by itself, and by as little as the point that is missing above a Dock. `own`:
  /// what it took, but for those sides, which have what was asked. `endsOnALine`: one of them is short by more than a point or two and ends
  /// where growth stops, which is what a cut looks like; not merely somewhere in the Dock's strip, where a window keeps whatever height it
  /// has. Or it is longer by more than that, which in the strip is what being held looks like: no app answers a smaller size with a larger one there
  /// and takes it elsewhere.
  func sidesTheScreenKept(
    of took: CGSize, shortOf asked: CGSize, at origins: [CGPoint], longerToo: Bool = true
  ) -> (width: Bool, height: Bool, own: CGSize, endsOnALine: Bool) {
    var (width, height, endsOnALine) = (false, false, false)
    for origin in origins {
      guard let display = stopper(of: origin) else { continue }
      let allowed = display.lines.allows(asked, to: CGRect(origin: origin, size: took))
      let play = display.visibleFrame.maxX < display.frame.maxX ? Self.theDocksPlay : 1
      if took.width < asked.width, allowed.width < asked.width, allowed.width <= took.width + play {
        width = true
        if took.width < asked.width - 2, origin.x + took.width <= display.visibleFrame.maxX + play { endsOnALine = true }
      }
      if longerToo, took.width > asked.width, allowed.width > asked.width, allowed.width >= took.width - play {
        width = true
        if took.width > asked.width + 2 { endsOnALine = true }
      }
      if took.height < asked.height, allowed.height < asked.height, allowed.height <= took.height + Self.theDocksPlay {
        height = true
        if took.height < asked.height - 2, origin.y + took.height <= display.visibleFrame.maxY + Self.theDocksPlay { endsOnALine = true }
      }
      if longerToo, took.height > asked.height, allowed.height > asked.height, allowed.height >= took.height - Self.theDocksPlay {
        height = true
        if took.height > asked.height + 2 { endsOnALine = true }
      }
    }
    return (width, height, CGSize(width: width ? asked.width : took.width, height: height ? asked.height : took.height), endsOnALine)
  }

  /// The Dock is as high as it is at that moment, whatever Arbor has been told: it was seen to change by two points as a window went into
  /// it, a third of a second before the news came. So a window is sized this far above it, and an answer that ends this near it is the screen's.
  static let theDocksPlay: CGFloat = 4

  /// Where a window that stands at `standing` has to go to be given the size of `frame`, before it is moved there. Nil if it need not go
  /// anywhere for that: one request will do, to a point. As near to where it is going as the size fits, so straight above it or beside it; if it
  /// fits nowhere, where most of it does.
  func whereItHasToBeSized(for frame: CGRect, from standing: CGRect) -> CGPoint? {
    let rooms = displays.map { FramePlan.room(onDisplay: $0.frame, visible: $0.visibleFrame) }
    let after = ScreenLines.sizeAfterOneRequest(for: frame, from: standing, rooms: rooms) { stopper(of: $0)?.lines }
    let (wide, high) = (after.width >= frame.width - 1, after.height >= frame.height - 1)
    guard !wide || !high, let display = stopper(of: frame.origin) else { return nil }
    let (visible, whole) = (display.visibleFrame, display.frame)
    let right = visible.maxX - (visible.maxX < whole.maxX ? Self.theDocksPlay : 0)
    let bottom = visible.maxY - (visible.maxY < whole.maxY ? Self.theDocksPlay : 0)
    let place = CGPoint(
      x: wide ? frame.minX : max(whole.minX, min(frame.minX, right - frame.width)),
      y: high ? frame.minY : max(visible.minY, min(frame.minY, bottom - frame.height)))
    // Nothing is to be had there that is not to be had where it is going.
    return place == frame.origin || stopper(of: place)?.id != display.id ? nil : place
  }
}

extension Controller {
  /// Where a window that stands at `standing` has to be moved, as it is, to be able to shrink to the size of `frame`. Nil if it need not be moved
  /// for that: one request leaves it no larger than asked, to a point. As near to where it is going as the size fits, straight above it or
  /// beside it: whether its edge is off the display there, in the strip or on the screen, asked to end on the screen it does.
  func whereItCanShrink(to frame: CGRect, from standing: CGRect) -> CGPoint? {
    let rooms = displays.map { FramePlan.room(onDisplay: $0.frame, visible: $0.visibleFrame) }
    func after(_ from: CGRect) -> CGSize {
      ScreenLines.sizeAfterOneRequest(for: frame, from: from, rooms: rooms) { stopper(of: $0)?.lines }
    }
    let last = after(standing)
    let (wide, high) = (last.width > frame.width + 1, last.height > frame.height + 1)
    guard wide || high, let display = stopper(of: frame.origin) else { return nil }
    let (visible, whole) = (display.visibleFrame, display.frame)
    let place = CGPoint(
      x: wide && frame.maxX > visible.maxX ? max(whole.minX, visible.maxX - Self.theDocksPlay - frame.width) : frame.minX,
      y: high && frame.maxY > visible.maxY ? max(visible.minY, visible.maxY - Self.theDocksPlay - frame.height) : frame.minY)
    // Where it is going its size fits: then it goes there as anybody does, too large by what the screen held, and is asked once more (`give`): on
    // the way it covers less so than at its old size. And nothing is to be had there that is not to be had where it stands.
    let there = after(CGRect(origin: place, size: standing.size))
    guard place != frame.origin, stopper(of: place)?.id == display.id, there.width <= frame.width + 1, there.height <= frame.height + 1 else { return nil }
    return place
  }
}

extension DisplaySnapshot {
  /// How far a window with its corner on this display can be made to grow.
  var lines: ScreenLines { ScreenLines(frame: frame, visibleFrame: visibleFrame) }
}
