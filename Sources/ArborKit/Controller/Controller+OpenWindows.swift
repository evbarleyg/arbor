import ArborCore
import CoreGraphics
import Foundation

/// The menu lists every open window (docs/MENU.md, Windows). Whoever cannot find a window opens the one thing of Arbor's that is
/// always there, reads the list and clicks: the window comes to the front and into view, whatever kept it out of it.
///
/// Which windows, in which order and where each is, is said here; what a row reads is `OpenWindows` (ArborCore). A click runs
/// `reveal`, the road Go to… takes (Controller+Finder.swift).
///
/// Titles are shown, never logged: a row's command names its window by number.
extension Controller {
  /// Every open window, on every display, in the order of use: the one with the keyboard, then those that have had it, the latest first,
  /// then the rest as they are laid out. After them the windows Arbor leaves alone, of whose use it keeps no track, by app; but the one
  /// being typed in is the latest in use, whoever arranges it.
  func openWindows() -> OpenWindows {
    let keyboard = keyboardFocus()
    let listed = displays.flatMap { workspaces[$0.id]?.allWindows ?? [] }.filter(isManaged)
    let known = Set(listed)
    var seen = Set<WindowID>()
    let arranged = ([keyboard].compactMap { $0 } + focusHistory + listed).filter { known.contains($0) && seen.insert($0).inserted }
    let leftAlone = windows.values.filter(isLeftAlone).sorted { ($0.appName, $0.id) < ($1.appName, $1.id) }
    func row(_ window: WindowSnapshot, _ place: FinderPlace) -> OpenWindows.Row {
      OpenWindows.Row(
        window: window.id, app: window.appName, title: window.title, place: place, hasKeyboard: window.id == keyboard, pid: window.pid)
    }
    let rows =
      arranged.compactMap { id -> OpenWindows.Row? in
        guard let window = windows[id], let display = workspaceID(containing: id) else { return nil }
        let place = place(of: window, on: display)
        // In view as Arbor counts, and yet most of it is beyond the edges of all the displays together: a click fetches it (`fetchWhole`).
        let isBeyond = areaShowing(of: window.frame) * 2 < window.frame.area
        return row(window, [.floating, .keptInView, .summoned].contains(place) && isBeyond ? .floatingOutOfView : place)
      } + leftAlone.map { row($0, placeLeftAlone($0)) }
    return OpenWindows(rows.filter(\.hasKeyboard) + rows.filter { !$0.hasKeyboard })
  }

  /// Where its app or its person put it. What macOS can do to any window, it says of these too.
  private func placeLeftAlone(_ window: WindowSnapshot) -> FinderPlace {
    if window.isMinimized { return .minimized }
    if window.isHidden { return .hiddenApp }
    if window.isFullScreen { return .fullScreen }
    return window.isOnActiveSpace ? .notArranged : .otherSpace
  }

  /// The rows of Windows ▸. With nothing open it says so: the row that opens it keeps its place.
  func windowListItems() -> [MenuModel.Item] {
    let rows = openWindows().rows
    guard !rows.isEmpty else { return [MenuModel.Item.text("No Open Windows")] }
    return rows.map { row in
      // No shortcut: `reveal` bound to a key is about the focused window.
      var item = MenuModel.Item.command(row.label, .reveal(row.window)).withoutShortcut().ticked(row.hasKeyboard).note(row.mark)
        .icon(ofProcess: row.pid)
      item.help = row.help
      return item
    }
  }

  // MARK: Whole

  /// A floating window that is asked for by name comes wholly into view: moved the least that does it, once. **Moved, never sized**: a size is
  /// its person's (QUESTIONS Q20), so of one that is larger than its display the top left corner comes in, where its title bar is.
  /// Hanging over an edge is its person's business, until they ask where it is: of a window that shows a corner, "in view" is no answer.
  ///
  /// Whole is what the displays show all of between them: a window that lies across two of them is let be, as everywhere else
  /// (`areaShowing`). What is fetched comes onto the display it belongs to, so that it goes on coming and going with that display's view.
  ///
  /// Called by `reveal` before anything else happens, so that it is the one move. A window out of view comes back to where it is remembered,
  /// and that is changed; one in the Dock, or hidden with its app, is moved where nobody sees it, and comes back there.
  func fetchWhole(_ id: WindowID) {
    guard let home = workspaceID(containing: id), let workspace = workspaces[home], workspace.isFloating(id), !workspace.isStashed(id),
      let window = windows[id], window.isOnActiveSpace, !window.isFullScreen, let display = display(home)
    else { return }
    let isAway = parked.contains(id)
    let own = workspace.floating[id] ?? window.frame
    let frame = isAway ? own : window.frame
    guard displays.map({ frame.intersection($0.visibleFrame).area }).reduce(0, +) < frame.area - 1 else { return }
    func slid(_ frame: CGRect) -> CGRect { CGRect(origin: frame.fitted(into: display.visibleFrame).origin, size: frame.size) }
    let whole = slid(frame)
    guard whole != frame else { return }
    // What is remembered is the window's own frame, which is another while docked windows squeeze it: it goes the same way, and keeps
    // its size to come back to.
    workspaces[home]!.floating[id] = slid(own.offsetBy(dx: whole.minX - frame.minX, dy: whole.minY - frame.minY))
    // Its person asked it there, as good as put it there: a layout fits what nobody chose, and would make one that is larger than the
    // display smaller after all.
    noteWhereItsUserLeftIt(id)
    // Its person asked for it: where it comes to is its own place now, with nothing to go back to when the displays change again.
    fittedFrames[id] = nil
    if !isAway { putBack(id, at: whole, on: display) }
    scheduleSave()
    Log.debug("\(id) was asked for and hung over an edge: it is at \(whole.brief) now")
  }
}
