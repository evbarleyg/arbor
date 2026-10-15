import ArborCore
import CoreGraphics

/// A window moves once, to where it ends up, also when an app does not take the size it is offered.
///
/// An answer that is not the size of the slot changes the layout (room is made, or the window becomes a tile) or the
/// window's place in its slot (one that cannot grow sits in the middle), and whatever has been moved by then is moved again.
/// So it is a matter of order, and of using what is known (`SeenSizes`):
/// - **a window of which it is not known whether it can be as small as its slot is asked where it stands.** Only one that has to
///   become smaller than it has ever been seen can refuse to. It is asked to without going anywhere, and goes to where the
///   size it took belongs: never by way of a place that turns out wrong;
/// - **those are asked before anybody is moved** (`askingFirst`), because their answer decides where everybody goes;
/// - **nobody in view is asked to grow where it stands** (`question`): the answer would be the screen's, not the window's. It grows
///   in its slot, and one that turns out unable to goes on to the middle of it, once;
/// - **a size that is said not to change is known beforehand** (`noteFixedSizes`);
/// - **a window that could not grow is expected not to** (`request`): it goes straight to the middle of its slot.
extension Controller {
  /// `layout`, or what `again` makes of the display once everybody in it who may refuse to be as small as their slot has been asked.
  func askingFirst(_ layout: Layout, on displayID: DisplayID, again: () -> Layout?) -> Layout {
    var layout = layout
    // There is an end without counting: what a window took instead has then been seen, so each refuses here once at
    // most. An app that asks for more every time it is asked is `relayout`'s to deal with.
    for _ in 0...layout.windowFrames.count + layout.tiles.count {
      guard askThoseWhoMayRefuse(layout, on: displayID), let known = again() else { break }
      layout = known
    }
    return layout
  }

  /// Returns true if one of them will not be as small as its slot: `layout` no longer holds.
  private func askThoseWhoMayRefuse(_ layout: Layout, on displayID: DisplayID) -> Bool {
    let shown = layouts[displayID]?.windowFrames ?? [:]
    let unknown = layout.windowFrames.keys.sorted().filter { window in
      guard window != drag?.window, let current = windows[window], isStillToBePlaced(current, in: layout.windowFrames[window]!)
      else { return false }
      return seen(current).mayRefuseToShrink(to: layout.windowFrames[window]!.size)
    }
    // How far each has to shrink: whoever is squeezed most is the likeliest to refuse.
    func squeeze(_ window: WindowID) -> CGFloat {
      guard let now = windows[window]?.frame.size, let slot = layout.windowFrames[window]?.size else { return 1 }
      return min(slot.width / max(now.width, 1), slot.height / max(now.height, 1))
    }
    // One at a time, and no further than the first refusal: whoever has shrunk by then has shrunk for a layout that never
    // comes, and may have to grow again. So newcomers come first, who are what the others make room for.
    for group in [unknown.filter { shown[$0] == nil }, unknown.filter { shown[$0] != nil }] {
      for window in group.sorted(by: { (squeeze($0), $0.rawValue) < (squeeze($1), $1.rawValue) }) {
        guard let current = windows[window], let question = question(current, toTake: layout.windowFrames[window]!.size)
        else { continue }
        if ask(window, question, on: displayID) { return true }
      }
    }
    return false
  }

  /// Whether `place` would move the window at all. It would not if the window is in its slot; if it could not take this slot's
  /// size and is still where that attempt left it (asking again would walk it through the slot's corner and back on
  /// every layout); or if Arbor has given up on it.
  func isStillToBePlaced(_ window: WindowSnapshot, in slot: CGRect) -> Bool {
    if isInPlace(window, at: slot) || enforcement.givenUp.contains(window.id) { return false }
    if !parked.contains(window.id), let misfit = misfits[window.id], misfit.slot == slot,
      window.frame.approximatelyEquals(misfit.frame, tolerance: 1)
    {
      return false
    }
    return true
  }

  /// What has been seen of a window's sizes, the one it has now included.
  private func seen(_ window: WindowSnapshot) -> SeenSizes {
    var seen = seenSizes[window.id] ?? SeenSizes(window.frame.size)
    seen.see(window.frame.size)
    return seen
  }

  /// What `apply` asks a window before it moves it into `slot`, if anything: whether it can grow that far. Out of view, where
  /// a question costs the eye nothing.
  func questionBeforePlacing(_ window: WindowSnapshot, in slot: CGRect, on displayID: DisplayID) -> CGRect? {
    guard parked.contains(window.id), seen(window).mayRefuseToGrow(to: slot.size, now: window.frame.size) else { return nil }
    return question(window, toTake: slot.size)
  }

  /// `size`, where the window stands, as far as it can be asked for there. Nil if nothing can, and the window is offered its slot like
  /// anybody.
  ///
  /// Where it stands, macOS lets a window grow no further than to the bottom of the visible frame and the right edge of its display
  /// (measured on macOS 26: at 170,220, asked to be 650 high above a Dock that begins at 705, a window became 484 high). That is
  /// the room there was, not what the window can do; taken for that, it left every window docked from lower down short of its
  /// slot. And a window that grows where it stands lies over its neighbours, in neither its old frame nor its new one. So each side is
  /// only asked to shrink. A window past both those lines, which is where Arbor parks them, was seen to grow as it is asked to.
  ///
  /// In the corner to the left of a display what shows of a window depends on its width, so it would grow into view or shrink
  /// out of reach. And a window its person has left lower than macOS lets anybody put one would not stay where it stands.
  private func question(_ window: WindowSnapshot, toTake size: CGSize) -> CGRect? {
    let has = window.frame
    let growsAsAsked =
      parked.contains(window.id) && stopper(of: has.origin).map { has.maxX > $0.frame.maxX && has.maxY > $0.visibleFrame.maxY } == true
    let question = CGRect(
      origin: has.origin,
      size: growsAsAsked ? size : CGSize(width: min(size.width, has.width), height: min(size.height, has.height)))
    guard abs(question.width - has.width) > 1 || abs(question.height - has.height) > 1 else { return nil }
    guard parked.contains(window.id) else {
      let staysThere = whereItStops(question.origin, titleBar: titleBars[window.id] ?? Self.guessedTitleBar) == question.origin
      return staysThere ? question : nil
    }
    return isOutOfView(question.union(has)) && displays.contains { question.overlaps($0.frame) } ? question : nil
  }

  /// Whether it may have been the screen that kept a window from growing to `asked` while it stood at `origin`: it `took` as much as ends
  /// on a line macOS lets no window grow across where it stands (`question`). Those lines are where they are at that moment,
  /// whatever Arbor has been told: the Dock's was seen to move by two points a third of a second before the news came.
  func mayHaveBeenStoppedByTheScreen(_ took: CGSize, shortOf asked: CGSize, at origin: CGPoint) -> Bool {
    guard let display = stopper(of: origin) else { return false }
    func ends(_ edge: CGFloat, on lines: CGFloat...) -> Bool { lines.contains { abs(edge - $0) <= 4 } }
    return took.height < asked.height - 2 && ends(origin.y + took.height, on: display.visibleFrame.maxY)
      || took.width < asked.width - 2 && ends(origin.x + took.width, on: display.frame.maxX, display.visibleFrame.maxX)
  }

  /// Puts a question. Returns true if the window refused to be that small (a new minimum size was learned).
  func ask(_ window: WindowID, _ question: CGRect, on displayID: DisplayID) -> Bool {
    // Its app does not answer: `place` finds that out as well, and sees to it.
    guard let was = windows[window]?.frame.size, var actual = system.setFrame(question, of: window) else { return false }
    actual = askForLess(window, slot: question, took: actual)
    windows[window]?.frame = actual
    settled[window] = actual
    justAnswered[window] = question.size
    // Only just back, it may not be ready to take a frame, and answers with the one it has (Controller+OnTheWayBack.swift). It goes
    // where the size it has belongs, and nothing is concluded. One that has changed its size has heard the question.
    if abs(actual.width - question.width) > 1 || abs(actual.height - question.height) > 1,
      abs(actual.width - was.width) <= 1, abs(actual.height - was.height) <= 1, postponesJudgement(of: window, on: displayID)
    {
      return false
    }
    return learn(from: window, was: was, took: actual.size, offered: question.size)
  }

  /// What a window made of the size it was offered, in its slot or where it stood. Returns true if a new minimum size was learned.
  func learn(from window: WindowID, was: CGSize, took actual: CGSize, offered: CGSize) -> Bool {
    var seen = seenSizes[window] ?? SeenSizes(was)
    seen.see(was)
    seen.note(took: actual, offered: offered)
    seenSizes[window] = seen

    let tooWide = actual.width > offered.width + 2
    let tooTall = actual.height > offered.height + 2
    guard tooWide || tooTall else { return false }
    var minimum = minimumSizes[window] ?? .zero
    if tooWide { minimum.width = max(minimum.width, actual.width) }
    if tooTall { minimum.height = max(minimum.height, actual.height) }
    guard minimumSizes[window] != minimum else { return false }
    minimumSizes[window] = minimum
    return true
  }

  /// Accessibility says of some windows that their size cannot be changed (Calculator, most settings windows). Written down before
  /// the first layout such a window is part of, as if it had refused both ways: room is made for it, or it is a tile, and it goes
  /// straight to the middle of its slot, without it or anybody else having gone anywhere to find out.
  ///
  /// Once, because it was said once, when the window was first seen, and a splash window can become a main window. From
  /// then on it is a record like any other: it ends when the window is seen to differ, and `relayout` forgets it.
  func noteFixedSizes(of docked: some Sequence<WindowID>) {
    for window in docked where !fixedSizesNoted.contains(window) {
      guard let snapshot = windows[window], !snapshot.isResizable else { continue }
      fixedSizesNoted.insert(window)
      if minimumSizes[window] == nil { minimumSizes[window] = snapshot.frame.size }
      var seen = seen(snapshot)
      seen.stoppedAt = snapshot.frame.size
      seenSizes[window] = seen
    }
  }

  /// Where a window that is to fill `slot` is expected to end up: in the slot, or in the middle of it at the size it is
  /// expected to stop at.
  func expectedFrame(of window: WindowSnapshot, in slot: CGRect) -> CGRect {
    let limit = seenSizes[window.id]?.limit(now: window.frame.size, offered: slot.size) ?? (width: nil, height: nil)
    let expected = CGSize(
      width: min(limit.width ?? slot.width, slot.width), height: min(limit.height ?? slot.height, slot.height))
    return expected.width < slot.width - 2 || expected.height < slot.height - 2 ? Self.centred(expected, in: slot) : slot
  }

  /// The frame to ask of a window that is to fill `slot`.
  func request(for window: WindowSnapshot, in slot: CGRect) -> CGRect {
    // It has just said what it makes of this size, so it is only moved. Offered the slot again, a terminal would round
    // up again and be talked down again.
    let answered = justAnswered[window.id]
    if answered == slot.size { return Self.centred(window.frame.size, in: slot) }
    // Where it is expected to end up, but the whole size: a sheet may have been open, that time. So finding out that it can
    // grow again costs nothing as long as it cannot. But for a side it has just answered for, where it stood.
    return CGRect(
      origin: expectedFrame(of: window, in: slot).origin,
      size: CGSize(
        width: answered?.width == slot.width ? window.frame.width : slot.width,
        height: answered?.height == slot.height ? window.frame.height : slot.height))
  }

  /// A window of `size` in the middle of `slot`. Where it is the larger of the two it begins where the slot does.
  static func centred(_ size: CGSize, in slot: CGRect) -> CGRect {
    CGRect(
      x: slot.midX - min(size.width, slot.width) / 2, y: slot.midY - min(size.height, slot.height) / 2,
      width: size.width, height: size.height)
  }
}
