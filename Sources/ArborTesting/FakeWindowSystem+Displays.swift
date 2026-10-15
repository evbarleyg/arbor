import ArborCore
import ArborKit
import CoreGraphics

// Displays that come, go, move and change places. Where macOS itself would put the windows of a display that went is not modelled:
// they stay where they were.

extension FakeWindowSystem {
  /// A change of displays in the order and at the times hosted Macs were recorded to make it: 37 changes in which a display came, went or was moved,
  /// in traces of six runs (macOS 26.6, every second display a virtual one), 21 of them in two runs with nine real apps.
  /// `setDisplays` tells Arbor in the same instant, which no Mac does: it is for tests that are about something else.
  ///
  /// - In 16 of the 21 with real apps, and in none of the others, ONE WINDOW SPEAKS FIRST: it reports that it moved, with the frame macOS has given
  ///   it, while `displays()` still answers the old list, 0.002 to 0.7 s before macOS speaks of its screens. It had the keyboard in 6
  ///   of the 16. Here it is the first of `moving`, if more than one app has something to say. Nearly all of a long lead is time in which Arbor's main thread is busy: in the report's
  ///   own handler, waiting for the app, and in its look at every app after macOS's word that the Space has changed. `ahead` is the
  ///   rest, in which its timers could run: at most 0.06 s in the ten leads that were taken apart, and no timer ran in any of the 16.
  /// - Then macOS has the new list, which `displays()` answers from there on, and nobody is told.
  /// - The apps report every window that macOS has moved or resized on that account, those on a display that stayed among them: as a
  ///   person's doing, with no button down. An app says of a window that it moved and then, if so, that its size changed, and goes on
  ///   to its next window; the apps speak side by side. So with an app to each window all say that they moved and then, in a second
  ///   round, that their size changed, the early speaker among the first (9 changes of 13; in the other four the rounds run into each
  ///   other), and the windows of one app come one after the other (every recording with one app). The last was heard up to a
  ///   second after macOS's first word; here it is sooner.
  /// - macOS says its word about the screens more than once where a display comes or goes: for an eighth of a second in the middle, and for up to
  ///   0.9 s (`repeating`). The Accessibility layer tells Arbor once nothing more has been said for as long as `DisplayChange` says, holding
  ///   what it finds then against what it told last: 1.54 to 2.63 s after macOS's first word, 1.77 in the middle; for a Dock that grew,
  ///   0.36. Past two seconds Arbor's own look-out for a display that blinked comes first. How many windows speak has no part in it.
  ///
  /// All that time passes here, and what Arbor has scheduled runs in it, on time: the stand-in has no main thread that is busy.
  ///
  /// Where macOS puts which window is the caller's to say (`moving`), and so is the order. Not played: a list in between (in 7 of 17 plug-ins the
  /// new display was first answered on the other side), and a frame that is reported and is not the last (2 of the 16 early speakers);
  /// the keyboard that macOS gave to another window before any report (3 of 4 moves of a display); Terminal's new title, which comes
  /// as a report that is nobody's doing; that what the layer answers of windows is as old as their last report. Never recorded:
  /// another display becoming the main one, and a display that is no virtual one.
  public func changeDisplaysAsAMacDoes(
    _ displays: [DisplaySnapshot], moving moves: [(window: WindowID, frame: CGRect)] = [], ahead: Double = 0.05, repeating: Double = 0.12
  ) {
    // However it ends: what the controller put off until all reports are in, and what the apps answer to the frames it set.
    defer {
      afterEvents?()
      deliverEchoes()
    }
    let moves = moves.filter { windows[$0.window] != nil }
    // Whoever has stopped listening has let go of every app, and hears nothing of their windows either.
    func say(_ window: WindowID) { if started { report(window, userInitiated: true) } }
    // What each app has to say, in the caller's order.
    var words: [(pid: Int32, windows: [WindowID])] = []
    for move in moves {
      let old = windows[move.window]!.snapshot
      let says = old.frame.size == move.frame.size ? [move.window] : [move.window, move.window]
      if let app = words.firstIndex(where: { $0.pid == old.pid }) { words[app].windows += says } else { words.append((old.pid, says)) }
    }
    var first: WindowID?
    if ahead > 0, words.count > 1, let move = moves.first {
      first = move.window
      moveSilently(move.window, to: move.frame)
      say(words[0].windows.removeFirst())
      passTime?(ahead)
    }
    displayList = displays
    // Not the first again: what macOS makes of a window that Arbor has set meanwhile nobody has recorded.
    for move in moves where move.window != first { moveSilently(move.window, to: move.frame) }
    var (pauses, passed) = ([0.03, 0.05][...], 0.0)
    while words.contains(where: { !$0.windows.isEmpty }) {
      if let pause = pauses.popFirst() {
        passTime?(pause)
        passed += pause
      }
      for app in words.indices where !words[app].windows.isEmpty { say(words[app].windows.removeFirst()) }
    }
    guard let quiet = DisplayChange.settleTime(from: displaysLastTold, to: displayList) else { return }
    // From macOS's last word, and the layer's timer is late.
    passTime?(max((quiet == DisplayChange.comingAndGoing ? repeating : 0) + quiet + 0.05 - passed, 0))
    // Like the layer: not if Arbor has stopped listening meanwhile, nor if the displays are by now as it was told. Then no place becomes
    // Arbor's to answer for either, as it does in `setDisplays`.
    guard started, DisplayChange.settleTime(from: displaysLastTold, to: displayList) != nil else { return }
    setDisplays(displayList)
  }

  /// Plugs a display in, or replaces the one with the same id.
  public func plug(_ display: DisplaySnapshot) {
    setDisplays(displayList.filter { $0.id != display.id } + [display])
  }

  /// Unplugs a display. If it was the main one the first of the others becomes main, as in `makeMain`.
  public func unplug(_ id: DisplayID) {
    let rest = displayList.filter { $0.id != id }
    if let next = rest.first, !rest.contains(where: \.isMain) {
      setDisplays(withTheMenuBar(on: next.id, among: rest))
    } else {
      setDisplays(rest)
    }
  }

  /// That display gets the menu bar, as when a lid closes or opens.
  public func makeMain(_ id: DisplayID) {
    guard displayList.contains(where: { $0.id == id }) else { return }
    setDisplays(withTheMenuBar(on: id, among: displayList))
  }

  /// A display is given another place among the others (System Settings). The windows whose middle is on it go along, silently.
  public func moveDisplay(_ id: DisplayID, to corner: CGPoint) {
    guard let index = displayList.firstIndex(where: { $0.id == id }) else { return }
    var list = displayList
    let old = list[index].frame
    let (dx, dy) = (corner.x - old.minX, corner.y - old.minY)
    for window in windows.values.map(\.snapshot) where old.contains(window.frame.center) {
      moveSilently(window.id, to: window.frame.offsetBy(dx: dx, dy: dy))
    }
    list[index].frame = old.offsetBy(dx: dx, dy: dy)
    list[index].visibleFrame = list[index].visibleFrame.offsetBy(dx: dx, dy: dy)
    setDisplays(list)
  }

  /// As on macOS, the main display's corner is the origin: every display, every window and the pointer has new coordinates,
  /// and no window reports it. The main display comes first in the list.
  private func withTheMenuBar(on id: DisplayID, among displays: [DisplaySnapshot]) -> [DisplaySnapshot] {
    guard let corner = displays.first(where: { $0.id == id })?.frame.origin else { return displays }
    var list = displays
    for index in list.indices {
      list[index].isMain = list[index].id == id
      list[index].frame = list[index].frame.offsetBy(dx: -corner.x, dy: -corner.y)
      list[index].visibleFrame = list[index].visibleFrame.offsetBy(dx: -corner.x, dy: -corner.y)
    }
    for window in windows.values.map(\.snapshot) { moveSilently(window.id, to: window.frame.offsetBy(dx: -corner.x, dy: -corner.y)) }
    cursor = CGPoint(x: cursor.x - corner.x, y: cursor.y - corner.y)
    return list.filter(\.isMain) + list.filter { !$0.isMain }
  }
}
