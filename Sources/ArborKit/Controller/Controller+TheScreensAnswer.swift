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
  ///
  /// Called through `give`, which knows besides what a journey across displays does to the answer (Controller+AcrossDisplays.swift).
  func giveAtOnce(_ frame: CGRect, to window: WindowID) -> Given? {
    let standing = windows[window]?.frame
    if let standing, whereItHasToBeSized(for: frame, from: standing) != nil {
      lookAtTheDock(under: frame.origin)
      if let place = whereItHasToBeSized(for: frame, from: standing) { return size(window, at: place, for: frame, from: standing) }
    }
    guard let actual = system.setFrame(frame, of: window) else { return nil }
    windows[window]?.frame = actual
    guard actual.width < frame.width || actual.height < frame.height else { return Given(frame: actual, own: actual) }
    lookAtTheDock(under: actual.origin)
    // Judged where it was asked: there, and where it stood before, for an app may carry a move out late.
    let kept = sidesTheScreenKept(of: actual.size, shortOf: frame.size, at: [standing?.origin, actual.origin].compactMap { $0 })
    let given = Given(frame: actual, own: CGRect(origin: actual.origin, size: kept.own))
    // Cut after all: it did not stand where Arbor believed. Once more, from where it is now. Only if the answer ends on a line: held in the
    // Dock's strip a window has whatever size it came with, which may as well be all its app allows, and a hop would be for nothing.
    guard kept.endsOnALine else { return given }
    if let place = whereItHasToBeSized(for: frame, from: actual) { return size(window, at: place, for: frame, from: actual) }
    guard let again = system.setFrame(frame, of: window) else { return nil }
    windows[window]?.frame = again
    return Given(frame: again, own: ownFrame(of: again, askedFor: frame.size))
  }

  private func size(_ window: WindowID, at place: CGPoint, for frame: CGRect, from standing: CGRect) -> Given? {
    guard let sized = system.setFrame(CGRect(origin: place, size: frame.size), of: window) else { return nil }
    windows[window]?.frame = sized
    // Judged here, where it was sized, and where it stood. Short of what was asked where there was room for it, that is its app's answer.
    let own = sidesTheScreenKept(of: sized.size, shortOf: frame.size, at: [standing.origin, sized.origin]).own
    // If its app has stopped answering half-way, it is not where it belongs, and whoever asked has to know. Where it is, is on record.
    guard let moved = system.setFrame(CGRect(origin: frame.origin, size: sized.size), of: window) else { return nil }
    windows[window]?.frame = moved
    return Given(frame: moved, own: CGRect(origin: moved.origin, size: moved.size == sized.size ? own : moved.size))
  }

  /// macOS does not say when the Dock has grown or shrunk, so a layout looks before it reckons (`refreshVisibleFrame`). So does whoever
  /// reckons with the Dock's line between two layouts.
  private func lookAtTheDock(under origin: CGPoint) {
    if let display = stopper(of: origin) { refreshVisibleFrame(of: display.id) }
  }

  /// What to write down as the own frame of a window that was asked for `size` where it stands and has `actual`.
  func ownFrame(of actual: CGRect, askedFor size: CGSize) -> CGRect {
    CGRect(origin: actual.origin, size: sidesTheScreenKept(of: actual.size, shortOf: size, at: [actual.origin]).own)
  }

  /// Which sides of a window that `took` less than it was `asked` for the screen may have kept short: with its corner at one of `origins`, macOS
  /// lets it be no larger than it is. Each side by itself, and by as little as the point that is missing above a Dock. `own`: what it took, but
  /// for those sides, which have what was asked. `endsOnALine`: one of them is short by more than a point or two and ends where growth
  /// stops, which is what a cut looks like; not merely somewhere in the Dock's strip, where a window keeps whatever height it has.
  func sidesTheScreenKept(
    of took: CGSize, shortOf asked: CGSize, at origins: [CGPoint]
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
      if took.height < asked.height, allowed.height < asked.height, allowed.height <= took.height + Self.theDocksPlay {
        height = true
        if took.height < asked.height - 2, origin.y + took.height <= display.visibleFrame.maxY + Self.theDocksPlay { endsOnALine = true }
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

extension DisplaySnapshot {
  /// How far a window with its corner on this display can be made to grow.
  var lines: ScreenLines { ScreenLines(frame: frame, visibleFrame: visibleFrame) }
}
