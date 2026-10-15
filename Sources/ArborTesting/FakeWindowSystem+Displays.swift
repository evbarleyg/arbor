import ArborCore
import ArborKit
import CoreGraphics

// Displays that come, go, move and change places. Where macOS itself would put the windows of a display that went is not modelled:
// they stay where they were.

extension FakeWindowSystem {
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
